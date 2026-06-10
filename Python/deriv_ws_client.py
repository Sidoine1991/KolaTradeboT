#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Deriv WebSocket Client — Récupère prix/OHLC pour Boom/Crash en temps réel
API: wss://ws.derivws.com/websockets/v3
"""
import json
import asyncio
import websockets
import logging
from datetime import datetime
from typing import Dict, Any, Optional

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)

DERIV_WS_URL = "wss://ws.derivws.com/websockets/v3"

# Mapping symboles Deriv
DERIV_SYMBOLS = {
    "Boom 300 Index": "BOOM300N",
    "Boom 500 Index": "BOOM500N",
    "Boom 1000 Index": "BOOM1000N",
    "Crash 300 Index": "CRASH300N",
    "Crash 500 Index": "CRASH500N",
    "Crash 1000 Index": "CRASH1000N",
}

class DerivWSClient:
    """Client WebSocket pour Deriv API."""

    def __init__(self):
        self.ws = None
        self.data_cache: Dict[str, Dict[str, Any]] = {}
        self.request_id = 1

    async def connect(self):
        """Connecte au WebSocket Deriv."""
        try:
            self.ws = await websockets.connect(DERIV_WS_URL)
            log.info("✅ Connecté à Deriv WebSocket")
        except Exception as e:
            log.error(f"❌ Erreur connexion Deriv: {e}")
            raise

    async def disconnect(self):
        """Ferme la connexion."""
        if self.ws:
            await self.ws.close()
            log.info("🔌 Déconnecté de Deriv")

    async def request_ticks(self, symbol: str, count: int = 100) -> Optional[Dict]:
        """Demande les ticks (bougies) pour un symbole."""
        if symbol not in DERIV_SYMBOLS:
            log.warning(f"⚠️  Symbole non supporté: {symbol}")
            return None

        deriv_symbol = DERIV_SYMBOLS[symbol]
        req_id = self.request_id
        self.request_id += 1

        # Requête pour obtenir les ticks
        payload = {
            "ticks_history": deriv_symbol,
            "adjust_start_time": 1,
            "count": count,
            "end": "latest",
            "start": 1,
            "style": "candles",
            "granularity": 60,  # 1 minute
            "req_id": req_id
        }

        try:
            await self.ws.send(json.dumps(payload))
            log.info(f"📤 Requête ticks envoyée: {symbol}")

            # Attendre réponse
            response = await asyncio.wait_for(self.ws.recv(), timeout=5.0)
            data = json.loads(response)

            if "error" in data:
                log.error(f"❌ Erreur Deriv: {data['error']}")
                return None

            return data
        except asyncio.TimeoutError:
            log.error(f"⏱️  Timeout requête {symbol}")
            return None
        except Exception as e:
            log.error(f"❌ Erreur requête {symbol}: {e}")
            return None

    async def fetch_ohlc(self, symbol: str, count: int = 100) -> Dict[str, Any]:
        """Extrait OHLC depuis les ticks Deriv."""
        data = await self.request_ticks(symbol, count)

        if not data or "candles" not in data:
            return {}

        candles = data["candles"]
        if not candles:
            return {}

        # Dernier candle
        latest = candles[-1]

        return {
            "symbol": symbol,
            "timestamp": datetime.utcnow().isoformat(),
            "open": float(latest.get("open", 0)),
            "high": float(latest.get("high", 0)),
            "low": float(latest.get("low", 0)),
            "close": float(latest.get("close", 0)),
            "volume": int(latest.get("tick_count", 0)),
            "candles": candles  # Tous les candles pour calculs d'indicateurs
        }

    async def calculate_rsi(self, symbol: str, period: int = 14) -> Optional[float]:
        """Calcule RSI pour un symbole."""
        ohlc = await self.fetch_ohlc(symbol, count=period + 20)

        if not ohlc or not ohlc.get("candles"):
            return None

        closes = [float(c.get("close", 0)) for c in ohlc["candles"]]

        if len(closes) < period + 1:
            return None

        # RSI simple
        deltas = [closes[i] - closes[i-1] for i in range(1, len(closes))]
        gains = sum(d for d in deltas if d > 0) / period
        losses = sum(-d for d in deltas if d < 0) / period

        if losses == 0:
            return 100.0 if gains > 0 else 0.0

        rs = gains / losses
        rsi = 100 - (100 / (1 + rs))

        return round(rsi, 2)

    async def calculate_bollinger_bands(self, symbol: str, period: int = 20, dev: float = 2.0) -> Dict[str, float]:
        """Calcule Bollinger Bands."""
        ohlc = await self.fetch_ohlc(symbol, count=period + 20)

        if not ohlc or not ohlc.get("candles"):
            return {}

        closes = [float(c.get("close", 0)) for c in ohlc["candles"][-period:]]

        if len(closes) < period:
            return {}

        sma = sum(closes) / len(closes)
        variance = sum((c - sma) ** 2 for c in closes) / len(closes)
        std_dev = variance ** 0.5

        return {
            "bb_mid": round(sma, 2),
            "bb_up": round(sma + dev * std_dev, 2),
            "bb_dn": round(sma - dev * std_dev, 2)
        }

    async def get_full_snapshot(self, symbol: str) -> Dict[str, Any]:
        """Récupère snapshot complet: OHLC + RSI + BB."""
        try:
            ohlc = await self.fetch_ohlc(symbol, count=100)
            rsi = await self.calculate_rsi(symbol)
            bb = await self.calculate_bollinger_bands(symbol)

            return {
                "symbol": symbol,
                "timestamp": datetime.utcnow().isoformat(),
                **ohlc,
                "rsi": rsi,
                **bb
            }
        except Exception as e:
            log.error(f"❌ Erreur snapshot {symbol}: {e}")
            return {"symbol": symbol, "error": str(e)}


async def main():
    """Test du client Deriv."""
    client = DerivWSClient()

    try:
        await client.connect()

        # Tester Boom 500
        snapshot = await client.get_full_snapshot("Boom 500 Index")
        print("\n📊 Boom 500 Index")
        print(f"  Close: {snapshot.get('close')}")
        print(f"  RSI: {snapshot.get('rsi')}")
        print(f"  BB Mid: {snapshot.get('bb_mid')}")

    finally:
        await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
