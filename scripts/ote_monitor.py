#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OTE Zone Monitor — Détection automatique et signaling à TradeManager
- Actualise la zone OTE en temps réel depuis TradingView
- Détecte quand le prix entre dans la zone
- Envoie un signal à l'AI server /pending-order
"""

import os
import sys
import json
import time
import logging
import asyncio
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional, Tuple
from dataclasses import dataclass
from dotenv import load_dotenv

import requests
import httpx

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [OTE Monitor] - %(levelname)s - %(message)s'
)
logger = logging.getLogger("ote_monitor")

# Load env
_root_dir = Path(__file__).resolve().parent.parent
load_dotenv(_root_dir / ".env")

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://localhost:8000")
PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")


@dataclass
class OTEZone:
    """Représente la zone OTE actuelle"""
    symbol: str
    price_high: float
    price_low: float
    timestamp: int  # unix timestamp
    is_active: bool = True

    def contains_price(self, price: float) -> bool:
        """Vérifie si le prix est dans la zone OTE"""
        return self.price_low <= price <= self.price_high

    def distance_to_entry(self, price: float) -> float:
        """Distance du prix à la zone OTE (négatif = déjà dedans)"""
        if self.contains_price(price):
            return 0.0
        elif price < self.price_low:
            return self.price_low - price
        else:
            return price - self.price_high


class OTEMonitor:
    """Moniteur de zone OTE avec détection d'entrée automatique"""

    def __init__(self, symbol: str = "OANDA:XAUUSD"):
        self.symbol = symbol
        self.ote_zone: Optional[OTEZone] = None
        self.price_in_zone = False
        self.last_update_time = 0
        self.update_interval = 60  # seconds

    async def fetch_price_data(self) -> Tuple[float, int]:
        """Récupère le prix actuel et timestamp via TradingView MCP"""
        try:
            # NOTE: En production, utiliser l'API Deriv ou TradingView MCP directement
            # Pour test, on retourne le prix actuel du chart XAUUSD
            async with httpx.AsyncClient() as client:
                # Appel à notre endpoint AI server pour récupérer le prix
                resp = await client.get(
                    f"{AI_SERVER_URL}/quote",
                    params={"symbol": self.symbol},
                    timeout=5.0
                )
                if resp.status_code == 200:
                    data = resp.json()
                    return float(data.get("price", 0)), int(time.time())
        except Exception as e:
            logger.error(f"Erreur récupération prix: {e}")
        return 0.0, 0

    async def calculate_ote_zone(self, price: float, timestamp: int) -> OTEZone:
        """
        Calcule la zone OTE basée sur le prix actuel et l'ATR
        OTE = Order Taker Entry — typiquement ±0.5 ATR du prix actuel
        """
        # ATR approximatif basé sur volatilité (à affiner avec indicateur)
        atr = 15.0  # XAUUSD M1 ATR typique

        ote_low = price - (atr * 0.3)  # 30% ATR below
        ote_high = price + (atr * 0.3)  # 30% ATR above

        return OTEZone(
            symbol=self.symbol,
            price_high=ote_high,
            price_low=ote_low,
            timestamp=timestamp,
            is_active=True
        )

    async def send_ote_signal(self, direction: str, entry_price: float, ote_zone: OTEZone) -> bool:
        """Envoie un signal OTE à TradeManager via /pending-order"""
        try:
            payload = {
                "symbol": self.symbol,
                "action": direction.upper(),  # BUY or SELL
                "entry_price": entry_price,
                "reason": f"OTE Zone Entry — {direction}",
                "confidence": 0.75,
                "stop_loss": ote_zone.price_low if direction == "BUY" else ote_zone.price_high,
                "take_profit": ote_zone.price_high if direction == "BUY" else ote_zone.price_low,
                "execution_type": "market"
            }

            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{AI_SERVER_URL}/pending-order",
                    json=payload,
                    timeout=10.0
                )

                if resp.status_code in [200, 201, 202]:
                    logger.info(f"✅ Signal OTE envoyé: {direction} @ {entry_price} → TradeManager")
                    return True
                else:
                    logger.error(f"❌ Erreur signal OTE: {resp.status_code} - {resp.text}")
                    return False

        except Exception as e:
            logger.error(f"❌ Exception signal OTE: {e}")
            return False

    async def send_notification(self, message: str):
        """Envoie une notification via PsychoBot"""
        try:
            payload = {
                "message": message,
                "type": "info"
            }
            async with httpx.AsyncClient() as client:
                await client.post(
                    f"{PSYCHOBOT_URL}/send-message",
                    json=payload,
                    timeout=5.0
                )
        except Exception as e:
            logger.warning(f"Notification failed: {e}")

    async def monitor_loop(self):
        """Boucle de monitoring OTE"""
        logger.info(f"🔄 Démarrage monitoring OTE pour {self.symbol}")

        while True:
            try:
                current_time = time.time()

                # Mise à jour toutes les N secondes
                if current_time - self.last_update_time >= self.update_interval:
                    # Récupérer le prix actuel
                    price, timestamp = await self.fetch_price_data()

                    if price == 0:
                        logger.warning("Prix nul reçu, skip")
                        await asyncio.sleep(5)
                        continue

                    # Calculer la zone OTE
                    self.ote_zone = await self.calculate_ote_zone(price, timestamp)

                    logger.info(
                        f"📊 OTE Update: {self.symbol} @ {price:.2f} | "
                        f"Zone: {self.ote_zone.price_low:.2f}–{self.ote_zone.price_high:.2f}"
                    )

                    # Vérifier si le prix est dans la zone
                    was_in_zone = self.price_in_zone
                    self.price_in_zone = self.ote_zone.contains_price(price)

                    if self.price_in_zone and not was_in_zone:
                        # Entrée dans la zone — décider direction
                        logger.info(f"🎯 Prix entré dans zone OTE @ {price}")

                        # Logique simple: si en hausse = BUY, si en baisse = SELL
                        # À adapter selon votre logique SMC
                        direction = "BUY" if price >= self.ote_zone.price_low else "SELL"

                        # Envoyer le signal
                        success = await self.send_ote_signal(direction, price, self.ote_zone)

                        if success:
                            msg = f"🚀 OTE Signal: {direction} @ {price:.2f} ({self.symbol})"
                            await self.send_notification(msg)

                    self.last_update_time = current_time

                await asyncio.sleep(5)  # Check toutes les 5 sec

            except Exception as e:
                logger.error(f"Erreur monitor loop: {e}", exc_info=True)
                await asyncio.sleep(10)


async def main():
    """Point d'entrée principal"""
    monitor = OTEMonitor(symbol="OANDA:XAUUSD")
    await monitor.monitor_loop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Arrêt du monitoring OTE")
        sys.exit(0)
