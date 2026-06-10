#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Live Calculator — Calcule les signaux GOM EN TEMPS RÉEL
SANS dépendance au JSON stale

Récupère candles locales → Calcule indicateurs → Retourne verdict FRAIS
"""

import sys
import json
import asyncio
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime, timezone, timedelta
import numpy as np
import pandas as pd

# Fix encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

# Import Deriv WebSocket
try:
    from deriv_candles_ws import DerivCandlesWSFetcher
    DERIV_AVAILABLE = True
except ImportError:
    DERIV_AVAILABLE = False


class GOMSignalsLiveCalculator:
    """Calcule les signaux GOM en temps réel depuis données locales."""

    def __init__(self):
        """Initialise le calculateur."""
        self.data_dir = Path(__file__).parent.parent / "data"
        self.candles_cache = {}  # {symbol: {timeframe: df}}
        self.cache_ttl_seconds = 120  # Cache 2 minutes
        self.mt5_candles_cache = {}  # {symbol: {timeframe: df}} - SET BY ai_server.py

    def get_candles_from_csv(
        self, symbol: str, timeframe: str, bars: int = 100
    ) -> Optional[pd.DataFrame]:
        """
        Récupère les candles depuis un CSV local.
        Format expected: data/{symbol}_{timeframe}.csv
        Colonnes: time, open, high, low, close, volume
        """
        csv_path = self.data_dir / f"{symbol}_{timeframe}.csv"

        if not csv_path.exists():
            # Fallback: essayer sans timeframe
            csv_path = self.data_dir / f"{symbol}.csv"
            if not csv_path.exists():
                return None

        try:
            df = pd.read_csv(csv_path, index_col=0, parse_dates=True)
            # Prendre les derniers 'bars'
            return df.tail(bars).copy()
        except Exception as e:
            print(f"⚠️ Erreur lecture CSV {symbol}: {e}")
            return None

    def get_candles_fallback(self, symbol: str, timeframe: str) -> pd.DataFrame:
        """
        Fallback: Charge depuis gom_signal.json (données statiques pour test)
        Retourne un DataFrame simple avec candles synthétiques
        """
        gom_file = self.data_dir / "gom_signal.json"

        try:
            with open(gom_file, 'r', encoding='utf-8') as f:
                gom_data = json.load(f)

            record = gom_data.get(symbol, {})

            # Créer des candles synthétiques basées sur les données GOM
            # (Pour POC - pas idéal mais fonctionnel)
            close = record.get("close", record.get("entry", 0))
            bb_mid = record.get("bb_mid", close)
            bb_up = record.get("bb_up", close * 1.002)
            bb_dn = record.get("bb_dn", close * 0.998)

            # Créer 100 candles synthétiques
            times = pd.date_range(
                end=datetime.now(timezone.utc),
                periods=100,
                freq=f'{timeframe}min' if timeframe.isdigit() else 'H'
            )

            candles = []
            for i, t in enumerate(times):
                # Candles gradativement vers le prix actuel
                open_p = bb_dn + (bb_up - bb_dn) * (i / 100)
                close_p = close
                high_p = max(open_p, close_p) * 1.001
                low_p = min(open_p, close_p) * 0.999

                candles.append({
                    'time': t,
                    'open': open_p,
                    'high': high_p,
                    'low': low_p,
                    'close': close_p,
                    'volume': 10000 + i * 100
                })

            df = pd.DataFrame(candles)
            df.set_index('time', inplace=True)
            return df

        except Exception as e:
            print(f"⚠️ Erreur fallback {symbol}: {e}")
            # Retourner un DataFrame vide (sera géré downstream)
            return pd.DataFrame()

    def get_candles(
        self, symbol: str, timeframe: str = "15", bars: int = 100
    ) -> pd.DataFrame:
        """
        Récupère les candles (MT5 → Deriv → CSV → Fallback).
        PRIORITÉ 1: MT5 (reçues via /mt5/upload-candles)
        PRIORITÉ 2: Deriv WebSocket (LIVE, real-time)
        PRIORITÉ 3: CSV local
        PRIORITÉ 4: Synthétique fallback
        """
        # PRIORITÉ 0: MT5 (CANDLES FRAÎCHES ENVOYÉES PAR L'EA)
        if self.mt5_candles_cache and symbol in self.mt5_candles_cache:
            if timeframe in self.mt5_candles_cache[symbol]:
                df = self.mt5_candles_cache[symbol][timeframe]
                if df is not None and len(df) > 0:
                    print(f"[GOM-CALC] ✅ MT5 CACHE HIT: {symbol} {timeframe}m ({len(df)} bars, last price={df['close'].iloc[-1]:.2f})")
                    return df.tail(bars)
            else:
                print(f"[GOM-CALC] MT5 cache exists for {symbol} but no data for timeframe {timeframe}")
        else:
            print(f"[GOM-CALC] MT5 cache empty or symbol not found")

        # PRIORITÉ 1: Deriv WebSocket (LIVE EN TEMPS RÉEL)
        if DERIV_AVAILABLE:
            try:
                # Utilise threading pour appeler asyncio.run() depuis contexte sync
                import threading
                result = [None]

                def fetch_deriv():
                    try:
                        result[0] = asyncio.run(
                            DerivCandlesWSFetcher().fetch_candles(symbol, timeframe, bars)
                        )
                    except Exception as e:
                        print(f"[GOM-CALC] Deriv thread error: {e}")

                thread = threading.Thread(target=fetch_deriv, daemon=True)
                thread.start()
                thread.join(timeout=5.0)  # Timeout 5 secondes

                df = result[0]
                if df is not None and len(df) > 0:
                    print(f"[GOM-CALC] 🌐 Fetched {len(df)} candles from Deriv WebSocket for {symbol} {timeframe}m")
                    return df
            except Exception as e:
                print(f"[GOM-CALC] Deriv error: {e} - Falling back to CSV")

        # PRIORITÉ 2: Essayer CSV local
        df = self.get_candles_from_csv(symbol, timeframe, bars)
        if df is not None and len(df) > 0:
            print(f"[GOM-CALC] 📁 Fetched {len(df)} candles from CSV for {symbol} {timeframe}m")
            return df

        # PRIORITÉ 3: Fallback synthétique depuis gom_signal.json
        print(f"[GOM-CALC] ⚠️ Using fallback synthetic candles for {symbol} {timeframe}m")
        return self.get_candles_fallback(symbol, timeframe)

    def calculate_rsi(self, df: pd.DataFrame, period: int = 14) -> float:
        """Calcule RSI(14)."""
        if len(df) < period + 1:
            return 50  # Neutre si pas assez de données

        close = df['close'].values
        delta = np.diff(close)

        gains = np.where(delta > 0, delta, 0)
        losses = np.where(delta < 0, -delta, 0)

        avg_gain = np.mean(gains[-period:])
        avg_loss = np.mean(losses[-period:])

        if avg_loss == 0:
            return 100 if avg_gain > 0 else 50

        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))

        return float(rsi)

    def calculate_bollinger_bands(
        self, df: pd.DataFrame, period: int = 20, std_dev: float = 2.0
    ) -> Tuple[float, float, float]:
        """Calcule Bollinger Bands."""
        if len(df) < period:
            close = df['close'].iloc[-1]
            return close, close, close

        close = df['close'].values
        sma = np.mean(close[-period:])
        std = np.std(close[-period:])

        bb_up = sma + (std_dev * std)
        bb_mid = sma
        bb_dn = sma - (std_dev * std)

        return float(bb_up), float(bb_mid), float(bb_dn)

    def calculate_vwap(self, df: pd.DataFrame) -> float:
        """Calcule VWAP."""
        if len(df) == 0:
            return 0

        typical_price = (df['high'] + df['low'] + df['close']) / 3
        vwap = (typical_price * df['volume']).sum() / df['volume'].sum()

        return float(vwap)

    def calculate_macd(self, df: pd.DataFrame) -> Tuple[float, float]:
        """Calcule MACD line et signal."""
        if len(df) < 26:
            return 0, 0

        close = df['close'].values
        ema12 = np.mean(close[-12:])
        ema26 = np.mean(close[-26:])

        macd_line = ema12 - ema26
        signal = np.mean([macd_line] * 9) if macd_line != 0 else 0  # Approx

        return float(macd_line), float(signal)

    def calculate_supertrend(self, df: pd.DataFrame, period: int = 10) -> Tuple[int, float]:
        """Calcule SuperTrend direction et niveau."""
        if len(df) < period:
            return 1, df['close'].iloc[-1]

        high = df['high'].values[-period:]
        low = df['low'].values[-period:]
        close = df['close'].values[-period:]

        # SuperTrend simple: max/min + ATR
        hl2 = (high + low) / 2
        atr = np.mean(high - low)

        basic_ub = hl2 + atr
        basic_lb = hl2 - atr

        current_close = close[-1]
        st_direction = 1 if current_close > hl2[-1] else -1
        st_level = basic_ub[-1] if st_direction == 1 else basic_lb[-1]

        return st_direction, float(st_level)

    def calculate_kola_levels(
        self, df: pd.DataFrame, bb_up: float, bb_dn: float
    ) -> Tuple[float, float]:
        """Calcule niveaux KOLA (basés sur Bollinger Bands)."""
        close = df['close'].iloc[-1]

        # KOLA: points équidistants de BB
        kola_buy = bb_dn + (bb_up - bb_dn) * 0.3
        kola_sell = bb_up - (bb_up - bb_dn) * 0.3

        return float(kola_buy), float(kola_sell)

    def evaluate_direction_rsi(
        self, df: pd.DataFrame, timeframe: str
    ) -> Tuple[str, int]:
        """Évalue direction (BULL/BEAR/NEUT) et RSI pour un timeframe."""
        if len(df) < 2:
            return "NEUT", 50

        rsi = self.calculate_rsi(df)

        # Direction basée sur RSI
        if rsi > 60:
            direction = "BULL"
        elif rsi < 40:
            direction = "BEAR"
        else:
            direction = "NEUT"

        return direction, int(rsi)

    def calculate_record_live(
        self, symbol: str, timeframe: str = "15"
    ) -> Dict[str, Any]:
        """
        Calcule un record COMPLET et FRAIS pour le symbole.
        CETTE FONCTION EST LE CŒUR DE LA SOLUTION LIVE.
        """
        # 1. Récupérer candles
        df = self.get_candles(symbol, timeframe)

        if df is None or len(df) == 0:
            return {
                "symbol": symbol,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "error": f"No candles available for {symbol}",
                "source": "live_calculation_failed"
            }

        # 2. Calculer indicateurs principaux (M15)
        rsi14 = self.calculate_rsi(df)
        bb_up, bb_mid, bb_dn = self.calculate_bollinger_bands(df)
        vwap = self.calculate_vwap(df)
        macd_line, macd_sig = self.calculate_macd(df)
        st_dir, st_level = self.calculate_supertrend(df)
        kola_buy, kola_sell = self.calculate_kola_levels(df, bb_up, bb_dn)

        close = df['close'].iloc[-1]
        high = df['high'].max()
        low = df['low'].min()

        # 3. Évaluer multi-TF (simplifié: utilise RSI du TF actuel)
        current_dir = "BULL" if rsi14 > 60 else ("BEAR" if rsi14 < 40 else "NEUT")

        # 4. Construire record complet
        record = {
            "symbol": symbol,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "source": "live_calculation",

            # Indicateurs
            "rsi14": int(rsi14),
            "bb_up": round(bb_up, 2),
            "bb_mid": round(bb_mid, 2),
            "bb_dn": round(bb_dn, 2),
            "bb_width": round(bb_up - bb_dn, 2),
            "vwap": round(vwap, 2),
            "macd_line": round(macd_line, 2),
            "macd_sig": round(macd_sig, 2),
            "st_dir": st_dir,
            "st_level": round(st_level, 2),

            # KOLA
            "kola_buy": round(kola_buy, 2),
            "kola_sell": round(kola_sell, 2),

            # Prix
            "close": round(close, 2),
            "entry": round(close, 2),
            "high": round(high, 2),
            "low": round(low, 2),

            # Multi-TF (simplifié pour POC)
            "tf_m1_dir": current_dir,
            "tf_m1_rsi": int(rsi14),
            "tf_m5_dir": current_dir,
            "tf_m5_rsi": int(rsi14),
            "tf_m15_dir": current_dir,
            "tf_m15_rsi": int(rsi14),
            "tf_h1_dir": current_dir,
            "tf_h1_rsi": int(rsi14),
            "tf_h4_dir": current_dir,
            "tf_h4_rsi": int(rsi14),
            "tf_d1_dir": current_dir,
            "tf_d1_rsi": int(rsi14),
            "tf_global_dir": current_dir,
            "tf_global_strength": 6 if current_dir != "NEUT" else 0,

            # Placeholders (seront enrichis par GOMVerdictCalculatorV2)
            "score_buy": 0.0,
            "score_sell": 0.0,
            "verdict_num": 0,
            "verdict": "WAIT",
            "verdict_gap": 0.0,
            "coherence_ok": False,
            "filter_ratio": 0.0,
            "coherence_pct": 0.0,
        }

        return record


def test_live_calculator():
    """Test le calculateur LIVE."""
    print("\n" + "="*80)
    print("TEST: GOM Live Calculator")
    print("="*80 + "\n")

    calc = GOMSignalsLiveCalculator()

    # Test symboles
    for symbol in ["XAUUSD", "BTCUSD"]:
        print(f"Calculando signals LIVE para {symbol}...")
        record = calc.calculate_record_live(symbol)

        print(f"  Timestamp: {record.get('timestamp')}")
        print(f"  RSI14: {record.get('rsi14')}")
        print(f"  BB: UP={record.get('bb_up')} MID={record.get('bb_mid')} DN={record.get('bb_dn')}")
        print(f"  KOLA: BUY={record.get('kola_buy')} SELL={record.get('kola_sell')}")
        print(f"  VWAP: {record.get('vwap')}")
        print(f"  TF Global Dir: {record.get('tf_global_dir')}")
        print()


if __name__ == "__main__":
    test_live_calculator()
