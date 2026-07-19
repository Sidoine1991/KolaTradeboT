#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Market Data Client — yfinance + Alpha Vantage fallback
Récupère OHLC, RSI, Bollinger Bands pour tous les symboles
"""
import sys
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

import yfinance as yf
import requests
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger(__name__)

ALPHA_VANTAGE_KEY = "demo"  # À remplacer par vraie clé si besoin
ALPHA_VANTAGE_URL = "https://www.alphavantage.co/query"

# Symboles yfinance
YFINANCE_SYMBOLS = {
    "XAUUSD": "GC=F",          # Gold Futures
    "BTCUSD": "BTC-USD",       # Bitcoin
    "ETHUSD": "ETH-USD",       # Ethereum
    "EURUSD": "EURUSD=X",      # EUR/USD
    "GBPUSD": "GBPUSD=X",      # GBP/USD
    "USDJPY": "USDJPY=X",      # USD/JPY
    "AUDUSD": "AUDUSD=X",      # AUD/USD
    "USDCAD": "USDCAD=X",      # USD/CAD
    "USDCHF": "USDCHF=X",      # USD/CHF
    "NZDUSD": "NZDUSD=X",      # NZD/USD
    "NAS100": "^GSPC",         # S&P 500
    "US30": "^DJI",            # Dow Jones
}

class YFinanceClient:
    """Client yfinance pour récupérer OHLC."""

    @staticmethod
    def fetch_ohlc(symbol: str, period: int = 100) -> Dict[str, Any]:
        """Récupère OHLC depuis yfinance."""
        try:
            if symbol not in YFINANCE_SYMBOLS:
                log.warning(f"⚠️  Symbole yfinance non supporté: {symbol}")
                return {}

            yf_symbol = YFINANCE_SYMBOLS[symbol]
            ticker = yf.Ticker(yf_symbol)

            # Récupérer données 1m
            hist = ticker.history(period="1d", interval="1m")

            if hist.empty:
                log.warning(f"⚠️  Aucune donnée yfinance pour {symbol}")
                return {}

            # Dernier candle
            latest = hist.iloc[-1]

            return {
                "symbol": symbol,
                "timestamp": datetime.utcnow().isoformat(),
                "open": float(latest["Open"]),
                "high": float(latest["High"]),
                "low": float(latest["Low"]),
                "close": float(latest["Close"]),
                "volume": int(latest["Volume"]),
                "hist": hist  # Historique pour calculs
            }

        except Exception as e:
            log.error(f"❌ Erreur yfinance {symbol}: {e}")
            return {}

    @staticmethod
    def calculate_rsi(symbol: str, period: int = 14) -> Optional[float]:
        """Calcule RSI."""
        ohlc = YFinanceClient.fetch_ohlc(symbol)

        if not ohlc or ohlc.get("hist") is None or ohlc["hist"].empty:
            return None

        closes = ohlc["hist"]["Close"].tail(period + 20).values

        if len(closes) < period + 1:
            return None

        deltas = [closes[i] - closes[i-1] for i in range(1, len(closes))]
        gains = sum(d for d in deltas if d > 0) / period
        losses = sum(-d for d in deltas if d < 0) / period

        if losses == 0:
            return 100.0 if gains > 0 else 0.0

        rs = gains / losses
        rsi = 100 - (100 / (1 + rs))

        return round(rsi, 2)

    @staticmethod
    def calculate_bollinger_bands(symbol: str, period: int = 20, dev: float = 2.0) -> Dict[str, float]:
        """Calcule Bollinger Bands."""
        ohlc = YFinanceClient.fetch_ohlc(symbol)

        if not ohlc or ohlc.get("hist") is None or ohlc["hist"].empty:
            return {}

        closes = ohlc["hist"]["Close"].tail(period).values

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

    @staticmethod
    def get_full_snapshot(symbol: str) -> Dict[str, Any]:
        """Snapshot complet: OHLC + RSI + BB."""
        try:
            ohlc = YFinanceClient.fetch_ohlc(symbol)
            if not ohlc:
                return {"symbol": symbol, "error": "Pas de données yfinance"}

            rsi = YFinanceClient.calculate_rsi(symbol)
            bb = YFinanceClient.calculate_bollinger_bands(symbol)

            return {
                **ohlc,
                "rsi": rsi,
                **bb
            }
        except Exception as e:
            log.error(f"❌ Erreur snapshot {symbol}: {e}")
            return {"symbol": symbol, "error": str(e)}


class AlphaVantageClient:
    """Client Alpha Vantage (fallback indicateurs techniques)."""

    @staticmethod
    def fetch_rsi(symbol: str, period: int = 14) -> Optional[float]:
        """Récupère RSI via Alpha Vantage."""
        try:
            params = {
                "function": "RSI",
                "symbol": symbol,
                "interval": "1min",
                "time_period": period,
                "apikey": ALPHA_VANTAGE_KEY
            }

            resp = requests.get(ALPHA_VANTAGE_URL, params=params, timeout=5)
            data = resp.json()

            if "error message" in data or "Technical Analysis: RSI" not in data:
                return None

            rsi_data = data["Technical Analysis: RSI"]
            latest_key = list(rsi_data.keys())[0]
            rsi_val = float(rsi_data[latest_key]["RSI"])

            return round(rsi_val, 2)

        except Exception as e:
            log.warning(f"⚠️  Alpha Vantage RSI fallback: {e}")
            return None

    @staticmethod
    def fetch_bbands(symbol: str, period: int = 20, dev: float = 2) -> Dict[str, float]:
        """Récupère Bollinger Bands via Alpha Vantage."""
        try:
            params = {
                "function": "BBANDS",
                "symbol": symbol,
                "interval": "1min",
                "time_period": period,
                "nbdevup": dev,
                "nbdevdn": dev,
                "apikey": ALPHA_VANTAGE_KEY
            }

            resp = requests.get(ALPHA_VANTAGE_URL, params=params, timeout=5)
            data = resp.json()

            if "error message" in data or "Technical Analysis: BBANDS" not in data:
                return {}

            bb_data = data["Technical Analysis: BBANDS"]
            latest_key = list(bb_data.keys())[0]
            latest = bb_data[latest_key]

            return {
                "bb_up": float(latest.get("Real Upper Band", 0)),
                "bb_mid": float(latest.get("Real Middle Band", 0)),
                "bb_dn": float(latest.get("Real Lower Band", 0))
            }

        except Exception as e:
            log.warning(f"⚠️  Alpha Vantage BBANDS fallback: {e}")
            return {}


class MarketDataClient:
    """Client unifié: Deriv WebSocket → yfinance → Alpha Vantage."""

    @staticmethod
    def get_snapshot(symbol: str, use_alpha_vantage: bool = False) -> Dict[str, Any]:
        """Récupère snapshot avec fallback."""

        # Essayer yfinance d'abord
        snapshot = YFinanceClient.get_full_snapshot(symbol)

        if snapshot and "error" not in snapshot:
            return snapshot

        # Si Alpha Vantage demandé
        if use_alpha_vantage:
            log.info(f"📡 Fallback Alpha Vantage pour {symbol}")
            rsi = AlphaVantageClient.fetch_rsi(symbol)
            bb = AlphaVantageClient.fetch_bbands(symbol)

            return {
                "symbol": symbol,
                "timestamp": datetime.utcnow().isoformat(),
                "rsi": rsi,
                **bb
            }

        return snapshot


def main():
    """Test."""
    print("✅ yfinance + Alpha Vantage Client")
    print("\n📊 XAUUSD (yfinance)")
    snapshot = YFinanceClient.get_full_snapshot("XAUUSD")
    print(f"  Close: {snapshot.get('close')}")
    print(f"  RSI: {snapshot.get('rsi')}")
    print(f"  BB Mid: {snapshot.get('bb_mid')}")


if __name__ == "__main__":
    main()
