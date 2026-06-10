#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Deriv REST API Candles Fetcher (fallback pour WebSocket)
Récupère les candles via API REST au lieu de WebSocket
"""

import sys
import json
import os
from typing import Dict, Any, Optional, List
import pandas as pd
import requests
from dotenv import load_dotenv

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

# Mapping des symboles Deriv
DERIV_SYMBOL_MAP = {
    'XAUUSD': '1100',
    'BTCUSD': '1D_BTC',
    'EURUSD': 'frxEURUSD',
    'GBPUSD': 'frxGBPUSD',
    'USDJPY': 'frxUSDJPY',
    'AUDUSD': 'frxAUDUSD',
    'NZDUSD': 'frxNZDUSD',
}

# Mapping des timeframes
TIMEFRAME_MAP = {
    '1': 60,
    '5': 300,
    '15': 900,
    '60': 3600,
    '240': 14400,
    'D': 86400,
}


class DerivCandlesRESTFetcher:
    """Récupère les candles Deriv via API REST"""

    def __init__(self):
        self.token = os.getenv("DERIV_API_TOKEN", "")
        self.app_id = os.getenv("DERIV_APP_ID", "1089")
        # Utilise l'API REST Deriv (accessible sans WebSocket)
        self.api_url = "https://api.deriv.com/api/v3"
        self.session = requests.Session()

    async def fetch_candles(
        self, symbol: str, timeframe: str = "15", bars: int = 100
    ) -> Optional[pd.DataFrame]:
        """Récupère les candles Deriv via REST"""
        deriv_symbol = DERIV_SYMBOL_MAP.get(symbol)
        if not deriv_symbol:
            print(f"Symbol {symbol} not mapped")
            return None

        interval = TIMEFRAME_MAP.get(timeframe)
        if not interval:
            print(f"Timeframe {timeframe} not mapped")
            return None

        try:
            # Appel REST au lieu de WebSocket
            url = f"{self.api_url}/ticks_history"
            params = {
                "ticks_history": deriv_symbol,
                "adjust_start_time": 1,
                "count": bars,
                "end": "latest",
                "granularity": interval,
                "style": "candles",
            }

            if self.token:
                params["authorize"] = self.token

            print(f"Fetching {bars} candles for {symbol} {timeframe}m from Deriv API...")
            response = self.session.get(url, params=params, timeout=10)
            response.raise_for_status()

            data = response.json()

            if "error" in data:
                print(f"Deriv error: {data['error']['message']}")
                return None

            candles_data = data.get("candles", [])
            if not candles_data:
                print(f"No candles in response")
                return None

            print(f"Got {len(candles_data)} candles")

            # Convertir en DataFrame
            df = pd.DataFrame(candles_data)
            df['time'] = pd.to_datetime(df['epoch'], unit='s')
            df.set_index('time', inplace=True)
            df = df[['open', 'high', 'low', 'close', 'volume']]

            return df

        except requests.exceptions.RequestException as e:
            print(f"REST API error: {e}")
            return None
        except Exception as e:
            print(f"Error: {e}")
            return None


async def get_deriv_candles_rest(
    symbol: str, timeframe: str = "15", bars: int = 100
) -> Optional[pd.DataFrame]:
    """Fonction convenience pour Deriv REST"""
    fetcher = DerivCandlesRESTFetcher()
    return await fetcher.fetch_candles(symbol, timeframe, bars)


if __name__ == "__main__":
    import asyncio

    async def test():
        df = await get_deriv_candles_rest("XAUUSD", "15", 10)
        if df is not None:
            print("\nSUCCESS! Deriv REST API works")
            print(df.tail(3))
        else:
            print("\nFAILED")

    asyncio.run(test())
