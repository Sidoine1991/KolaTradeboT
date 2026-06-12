#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TradeManager Position Sync — Met à jour automatiquement les SL en temps réel
Intègre position_manager_advanced pour trailing stop + breakeven SL
"""

import json
import time
import os
import sys
import requests
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Configuration
AI_SERVER = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
LOGS_DIR = Path("D:/Dev/TradBOT/logs")
LOGS_DIR.mkdir(parents=True, exist_ok=True)
MONITOR_INTERVAL = 5  # Vérifier positions toutes les 5 secondes

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "trademanager_sync.log", encoding='utf-8', mode='a'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)


class TradeManagerPositionSync:
    """Synchronise les positions MT5 avec trailing stop + breakeven SL"""

    def __init__(self):
        self.tracked_positions: Dict[str, Dict] = {}

    def fetch_open_positions(self) -> List[Dict]:
        """Récupère les positions ouvertes depuis TradeManager"""
        try:
            response = requests.get(f"{AI_SERVER}/get-positions", timeout=5)
            if response.status_code == 200:
                positions = response.json().get("positions", [])
                log.info(f"📊 Fetch: {len(positions)} position(s) ouvertes")
                return positions
            else:
                log.warning(f"⚠️ HTTP {response.status_code}")
                return []
        except Exception as e:
            log.error(f"❌ Fetch positions error: {e}")
            return []

    def fetch_current_prices(self, symbols: List[str]) -> Dict[str, Tuple[float, float]]:
        """Récupère les prix courants (bid/ask) pour les symboles"""
        prices = {}
        for symbol in symbols:
            try:
                response = requests.get(
                    f"{AI_SERVER}/get-quote",
                    params={"symbol": symbol},
                    timeout=5
                )
                if response.status_code == 200:
                    quote = response.json()
                    bid = float(quote.get("bid", 0))
                    ask = float(quote.get("ask", 0))
                    prices[symbol] = (bid, ask)
            except Exception:
                pass
        return prices

    def calculate_updated_sl(self, position: Dict, current_bid: float, current_ask: float) -> Optional[float]:
        """Calcule le nouveau SL avec trailing stop et breakeven"""
        ticket = position.get("ticket")
        symbol = position.get("symbol", "")
        action = position.get("action", "").upper()
        entry = float(position.get("open_price", 0))
        current_sl = float(position.get("sl", 0))
        tp = float(position.get("tp", 0))
        lot = float(position.get("volume", 0.01))

        mid_price = (current_bid + current_ask) / 2

        # Calculer PnL
        if action == "BUY":
            pnl = (mid_price - entry) * lot * 100
        else:  # SELL
            pnl = (entry - mid_price) * lot * 100

        new_sl = current_sl

        # ────────────────────────────────────────────────────
        # 1. BREAKEVEN SL — Si profit >= $2, sécuriser au prix d'entrée
        # ────────────────────────────────────────────────────
        if pnl >= 2.0:
            if action == "BUY" and current_sl < entry:
                new_sl = entry
                log.info(f"🔒 BREAKEVEN {ticket} ({symbol}): PnL ${pnl:.2f} → SL @ Entry {entry:.5f}")

            elif action == "SELL" and current_sl > entry:
                new_sl = entry
                log.info(f"🔒 BREAKEVEN {ticket} ({symbol}): PnL ${pnl:.2f} → SL @ Entry {entry:.5f}")

        # ────────────────────────────────────────────────────
        # 2. TRAILING STOP — Suit le profit au-delà du breakeven
        # ────────────────────────────────────────────────────
        if pnl >= 2.0 and new_sl == entry:  # Si breakeven SL déjà actif
            trailing_distance = mid_price * 0.005  # 0.5% du prix courant

            if action == "BUY":
                # SL monte mais ne descend jamais
                trailing_sl = mid_price - trailing_distance
                if trailing_sl > new_sl:
                    new_sl = trailing_sl
                    log.info(f"📈 TRAILING {ticket} ({symbol}): ${mid_price:.5f} → SL ${new_sl:.5f} (+${pnl:.2f})")

            else:  # SELL
                # SL descend mais ne monte jamais
                trailing_sl = mid_price + trailing_distance
                if trailing_sl < new_sl:
                    new_sl = trailing_sl
                    log.info(f"📉 TRAILING {ticket} ({symbol}): ${mid_price:.5f} → SL ${new_sl:.5f} (+${pnl:.2f})")

        # Retourner le nouveau SL seulement s'il a changé
        if abs(new_sl - current_sl) > 0.0001:
            return round(new_sl, 5)

        return None

    def update_position_sl(self, ticket: int, new_sl: float) -> bool:
        """Met à jour le SL d'une position via l'API"""
        try:
            payload = {
                "ticket": ticket,
                "stop_loss": new_sl
            }
            response = requests.post(
                f"{AI_SERVER}/update-position-sl",
                json=payload,
                timeout=5
            )
            if response.status_code in [200, 201]:
                log.info(f"✅ SL Updated: Ticket {ticket} → {new_sl:.5f}")
                return True
            else:
                log.warning(f"⚠️ Update failed: HTTP {response.status_code}")
                return False
        except Exception as e:
            log.error(f"❌ Update error: {e}")
            return False

    def monitor_loop(self):
        """Boucle de monitoring — met à jour les SL toutes les 5 secondes"""
        log.info("=" * 80)
        log.info("🚀 TRADEMANAGER POSITION SYNC — DÉMARRÉ")
        log.info("=" * 80)
        log.info(f"📍 AI Server: {AI_SERVER}")
        log.info(f"⏰ Monitor interval: {MONITOR_INTERVAL}s")
        log.info("=" * 80)
        log.info("")

        iteration = 0

        try:
            while True:
                iteration += 1
                ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')

                # Récupérer positions ouvertes
                positions = self.fetch_open_positions()
                if not positions:
                    time.sleep(MONITOR_INTERVAL)
                    continue

                # Récupérer prix courants
                symbols = list(set(p.get("symbol", "") for p in positions))
                prices = self.fetch_current_prices(symbols)

                if not prices:
                    time.sleep(MONITOR_INTERVAL)
                    continue

                # Vérifier et mettre à jour les SL
                updated_count = 0
                for pos in positions:
                    symbol = pos.get("symbol", "")
                    ticket = pos.get("ticket")

                    if symbol not in prices:
                        continue

                    bid, ask = prices[symbol]

                    # Calculer nouveau SL
                    new_sl = self.calculate_updated_sl(pos, bid, ask)

                    # Mettre à jour si changé
                    if new_sl is not None:
                        if self.update_position_sl(ticket, new_sl):
                            updated_count += 1

                # Log itération
                if updated_count > 0:
                    log.info(f"[Itération {iteration}] {ts} — {len(positions)} pos, {updated_count} mise(s) à jour SL")

                time.sleep(MONITOR_INTERVAL)

        except KeyboardInterrupt:
            log.info("\n⏹️ Arrêt demandé (Ctrl+C)")
        except Exception as e:
            log.error(f"❌ Erreur boucle: {e}")


def run_once():
    """Mode unique — vérifier et mettre à jour une seule fois"""
    log.info("=" * 80)
    log.info("🔄 MODE UNIQUE — Vérification des positions")
    log.info("=" * 80)

    sync = TradeManagerPositionSync()
    positions = sync.fetch_open_positions()

    if not positions:
        log.info("ℹ️ Aucune position ouverte")
        return

    symbols = list(set(p.get("symbol", "") for p in positions))
    prices = sync.fetch_current_prices(symbols)

    updated_count = 0
    for pos in positions:
        symbol = pos.get("symbol", "")
        if symbol in prices:
            bid, ask = prices[symbol]
            new_sl = sync.calculate_updated_sl(pos, bid, ask)
            if new_sl is not None:
                if sync.update_position_sl(pos.get("ticket"), new_sl):
                    updated_count += 1

    log.info(f"\n✅ Vérification terminée: {updated_count} SL mises à jour")
    log.info("=" * 80)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="TradeManager Position Sync with Trailing Stop")
    parser.add_argument("--once", action="store_true", help="Vérifier une seule fois et quitter")
    args = parser.parse_args()

    if args.once:
        run_once()
    else:
        sync = TradeManagerPositionSync()
        sync.monitor_loop()
