#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Deriv WebSocket Candles Fetcher
Récupère les candles EN TEMPS RÉEL depuis Deriv API WebSocket
"""

import sys
import json
import asyncio
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
import pandas as pd
import websockets

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

logger = logging.getLogger('deriv_candles')

# Mapping des symboles Deriv
DERIV_SYMBOL_MAP = {
    'XAUUSD': '1100',      # Gold
    'BTCUSD': '1D_BTC',    # Bitcoin
    'EURUSD': 'frxEURUSD', # EUR/USD
    'GBPUSD': 'frxGBPUSD', # GBP/USD
    'USDJPY': 'frxUSDJPY', # USD/JPY
    'AUDUSD': 'frxAUDUSD', # AUD/USD
    'NZDUSD': 'frxNZDUSD', # NZD/USD
    'Boom 500 Index': 'R_50',     # Boom 500
    'Crash 500 Index': 'R_50',    # Crash 500
    'Boom 1000 Index': 'R_100',   # Boom 1000
    'Crash 1000 Index': 'R_100',  # Crash 1000
}

# Mapping des timeframes
TIMEFRAME_MAP = {
    '1': 60,      # 1 minute
    '5': 300,     # 5 minutes
    '15': 900,    # 15 minutes
    '60': 3600,   # 1 hour
    '240': 14400, # 4 hours
    'D': 86400,   # 1 day
}


class DerivCandlesWSFetcher:
    """Récupère les candles Deriv via WebSocket"""

    def __init__(self, app_id: str = "1089"):
        """
        Initialise le fetcher Deriv.

        Args:
            app_id: Deriv app ID (default: 1089 pour demo)
        """
        self.app_id = app_id
        self.ws_url = "wss://ws.derivws.com/websockets/v3"
        self.cache = {}  # {symbol: {timeframe: df}}

    async def fetch_candles(
        self, symbol: str, timeframe: str = "15", bars: int = 100
    ) -> Optional[pd.DataFrame]:
        """
        Récupère les candles Deriv pour un symbole et timeframe.

        Args:
            symbol: Symbole (ex: "XAUUSD", "BTCUSD")
            timeframe: Timeframe en minutes (ex: "1", "5", "15", "60")
            bars: Nombre de candles à récupérer (max 100)

        Returns:
            DataFrame avec colonnes: time, open, high, low, close, volume
        """
        deriv_symbol = DERIV_SYMBOL_MAP.get(symbol)
        if not deriv_symbol:
            logger.warning(f"Symbol {symbol} not mapped to Deriv")
            return None

        interval = TIMEFRAME_MAP.get(timeframe)
        if not interval:
            logger.warning(f"Timeframe {timeframe} not mapped")
            return None

        try:
            candles = await self._ws_ticks_history(
                deriv_symbol, interval, bars
            )
            if not candles:
                return None

            # Convertir en DataFrame
            df = pd.DataFrame(candles)
            df['time'] = pd.to_datetime(df['epoch'], unit='s')
            df.set_index('time', inplace=True)
            df = df[['open', 'high', 'low', 'close', 'volume']]

            return df

        except Exception as e:
            logger.error(f"Error fetching candles for {symbol}: {e}")
            return None

    async def _ws_ticks_history(
        self, symbol: str, interval: int, bars: int
    ) -> Optional[List[Dict[str, Any]]]:
        """
        Récupère l'historique des ticks via WebSocket Deriv.

        Args:
            symbol: Deriv symbol ID
            interval: Interval en secondes
            bars: Nombre de candles

        Returns:
            Liste de candles avec {epoch, open, high, low, close}
        """
        request = {
            "ticks_history": symbol,
            "adjust_start_time": 1,
            "count": bars,
            "end": "latest",
            "granularity": interval,
            "style": "candles",
            "app_id": self.app_id,
        }

        try:
            # Utilise le WebSocket public de Deriv (pas d'auth requise pour les données publiques)
            ws_url = "wss://ws.deriv.com/websockets/v3"

            async with websockets.connect(ws_url, max_size=None) as websocket:
                # Envoyer la requête
                await websocket.send(json.dumps(request))

                # Recevoir la réponse
                response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                data = json.loads(response)

                if data.get("error"):
                    logger.error(f"Deriv error: {data['error']['message']}")
                    return None

                candles = data.get("candles", [])
                if not candles:
                    logger.warning(f"No candles returned for {symbol}")
                    return None

                logger.info(f"Got {len(candles)} candles from Deriv for {symbol}")
                return candles

        except asyncio.TimeoutError:
            logger.error(f"WebSocket timeout fetching {symbol}")
            return None
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
            return None


async def get_deriv_candles(
    symbol: str, timeframe: str = "15", bars: int = 100
) -> Optional[pd.DataFrame]:
    """
    Fonction convenience pour récupérer candles Deriv.

    Args:
        symbol: Symbole (ex: "XAUUSD")
        timeframe: Timeframe en minutes
        bars: Nombre de candles

    Returns:
        DataFrame avec candles
    """
    fetcher = DerivCandlesWSFetcher()
    return await fetcher.fetch_candles(symbol, timeframe, bars)


if __name__ == "__main__":
    # Test
    async def test():
        df = await get_deriv_candles("XAUUSD", "15", 10)
        if df is not None:
            print("Deriv Candles XAUUSD M15:")
            print(df.head())
        else:
            print("Failed to fetch candles")

    asyncio.run(test())
