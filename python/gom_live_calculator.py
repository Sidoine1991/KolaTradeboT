#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Live Calculator — indicateurs + scoring Pine, 100% local (candles MT5)
"""

import sys
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

try:
    from deriv_candles_ws import DerivCandlesWSFetcher
    DERIV_AVAILABLE = True
except ImportError:
    DERIV_AVAILABLE = False

try:
    from gom_pine_calculator import GOMLPineCalculator
    _PINE_CALC = GOMLPineCalculator()
except ImportError:
    _PINE_CALC = None

# Canonical Pine TF keys → MT5 upload labels / Deriv keys
TF_CANONICAL = {
    "1": ["1", "M1", "m1"],
    "5": ["5", "M5", "m5"],
    "15": ["15", "M15", "m15"],
    "60": ["60", "H1", "h1"],
    "240": ["240", "H4", "h4"],
    "D": ["D", "D1", "d1"],
    "W": ["W", "W1", "w1"],
}

try:
    from mt5_candles_fetcher import fetch_mt5_candles, mt5_python_available
    MT5_FETCHER_AVAILABLE = True
except ImportError:
    MT5_FETCHER_AVAILABLE = False
    fetch_mt5_candles = None  # type: ignore

MTF_TFS = ["1", "5", "15", "60", "240", "D", "W"]
GOM_CANDLE_CACHE_TTL_SEC = float(os.getenv("GOM_CANDLE_CACHE_TTL_SEC", "8"))
GOM_ALLOW_CSV_FALLBACK = os.getenv("GOM_ALLOW_CSV_FALLBACK", "").lower() in ("1", "true", "yes")


def normalize_tf_key(tf: str) -> str:
    t = str(tf or "").upper().strip()
    aliases = {
        "M1": "1", "M3": "3", "M5": "5", "M15": "15", "M30": "30",
        "H1": "60", "H2": "120", "H4": "240", "D1": "D", "W1": "W", "MN": "M",
    }
    return aliases.get(t, t)


def tf_aliases(tf: str) -> List[str]:
    key = normalize_tf_key(tf)
    return TF_CANONICAL.get(key, [key, tf])


class GOMSignalsLiveCalculator:
    """Calcule GOM en temps réel depuis candles MT5 (priorité) ou fallbacks."""

    def __init__(self):
        self.data_dir = Path(__file__).parent.parent / "data"
        self.mt5_candles_cache: Dict[str, Dict[str, pd.DataFrame]] = {}
        self._candles_mem_cache: Dict[str, pd.DataFrame] = {}
        self._candles_mem_cache_ts: Dict[str, float] = {}
        self._candles_mem_source: Dict[str, str] = {}
        self.pine = _PINE_CALC or GOMLPineCalculator()
        # Tracking bougies sans spike confirmé par symbole (incrément par nouvelle bougie M1)
        self._bars_without_spike: Dict[str, int] = {}
        self._last_spike_time: Dict[str, float] = {}
        self._last_m1_bar_time: Dict[str, int] = {}

    def _cache_lookup(self, symbol: str, tf: str) -> Optional[pd.DataFrame]:
        for sym_key in self._symbol_lookup_keys(symbol):
            sym_cache = self.mt5_candles_cache.get(sym_key) or {}
            for alias in tf_aliases(tf):
                df = sym_cache.get(alias)
                if df is not None and len(df) > 0:
                    return df
        return None

    def _symbol_lookup_keys(self, symbol: str) -> List[str]:
        keys: List[str] = []
        for k in (symbol,):
            if k and k not in keys:
                keys.append(k)
        try:
            from symbol_mapper import resolve_mt5_symbol
            canon = resolve_mt5_symbol(symbol)
            if canon and canon not in keys:
                keys.append(canon)
        except ImportError:
            pass
        compact = str(symbol or "").upper().replace(" ", "")
        if compact and compact not in keys:
            keys.append(compact)
        return keys

    def get_candles_from_csv(
        self, symbol: str, timeframe: str, bars: int = 200
    ) -> Optional[pd.DataFrame]:
        tf_label = {"1": "M1", "5": "M5", "15": "M15", "60": "H1", "240": "H4", "D": "D1", "W": "W1"}.get(
            normalize_tf_key(timeframe), ""
        )
        candidates: List[Path] = []
        if tf_label:
            candidates.extend([
                self.data_dir / f"{symbol}_{tf_label}.csv",
                self.data_dir / "candles" / f"{symbol}_{tf_label}.csv",
                self.data_dir / "mt5" / f"{symbol}_{tf_label}.csv",
            ])
            candidates.extend(sorted(self.data_dir.glob(f"{symbol}_{tf_label}*.csv")))
        candidates.append(self.data_dir / f"{symbol}.csv")

        for csv_path in candidates:
            if not csv_path.is_file():
                continue
            try:
                df = pd.read_csv(csv_path)
                if "time" in df.columns:
                    df["time"] = pd.to_datetime(df["time"])
                    df.set_index("time", inplace=True)
                if "tick_volume" in df.columns and "volume" not in df.columns:
                    df["volume"] = df["tick_volume"]
                req = ["open", "high", "low", "close", "volume"]
                if all(c in df.columns for c in req):
                    return df.tail(bars).copy()
            except Exception:
                continue
        return None

    def _is_deriv_synthetic(self, symbol: str) -> bool:
        sym = str(symbol or "").upper().replace(" ", "")
        return any(
            x in sym
            for x in (
                "BOOM", "CRASH", "PAINX", "GAINX", "TRENDX", "BREAKX",
                "VOL", "FXVOL", "SFVVOL", "SFXVOL", "STEP",
            )
        )

    def get_candles(
        self, symbol: str, timeframe: str = "15", bars: int = 200, allow_deriv: bool = False, broker: Optional[str] = None
    ) -> pd.DataFrame:
        cache_key = f"{symbol}:{normalize_tf_key(timeframe)}"
        now = time.time()
        if cache_key in self._candles_mem_cache:
            age = now - self._candles_mem_cache_ts.get(cache_key, 0)
            src = self._candles_mem_source.get(cache_key, "mem")
            ttl = GOM_CANDLE_CACHE_TTL_SEC if src in ("mt5_direct", "mt5_upload") else 3600.0
            if age < ttl:
                return self._candles_mem_cache[cache_key].tail(bars).copy()

        df = self._cache_lookup(symbol, timeframe)
        if df is not None:
            self._store_mem_cache(cache_key, df, "mt5_upload")
            return df.tail(bars).copy()

        if MT5_FETCHER_AVAILABLE and fetch_mt5_candles is not None:
            try:
                from symbol_mapper import resolve_mt5_symbol
                mt5_sym = resolve_mt5_symbol(symbol)
            except ImportError:
                mt5_sym = symbol
            df_mt5 = fetch_mt5_candles(mt5_sym, timeframe, bars, broker=broker)
            if df_mt5 is not None and len(df_mt5) >= 30:
                self._store_mem_cache(cache_key, df_mt5, "mt5_direct")
                return df_mt5.tail(bars).copy()

        if GOM_ALLOW_CSV_FALLBACK:
            df = self.get_candles_from_csv(symbol, timeframe, bars)
            if df is not None and len(df) > 0:
                self._store_mem_cache(cache_key, df, "csv_local")
                return df

        use_deriv = allow_deriv or self._is_deriv_synthetic(symbol)
        if use_deriv and DERIV_AVAILABLE:
            import asyncio
            import threading

            tf_key = normalize_tf_key(timeframe)
            if tf_key in ("W", "M"):
                return pd.DataFrame()
            result: list = [None]

            def _fetch():
                try:
                    result[0] = asyncio.run(
                        DerivCandlesWSFetcher().fetch_candles(symbol, tf_key, bars)
                    )
                except Exception as exc:
                    print(f"[GOM-CALC] Deriv error: {exc}")

            t = threading.Thread(target=_fetch, daemon=True)
            t.start()
            t.join(timeout=2.0)
            if result[0] is not None and len(result[0]) > 0:
                return result[0]

        return pd.DataFrame()

    def _store_mem_cache(self, cache_key: str, df: pd.DataFrame, source: str) -> None:
        self._candles_mem_cache[cache_key] = df
        self._candles_mem_cache_ts[cache_key] = time.time()
        self._candles_mem_source[cache_key] = source

    def _candle_source_for(self, symbol: str, timeframe: str) -> str:
        cache_key = f"{symbol}:{normalize_tf_key(timeframe)}"
        if self._cache_lookup(symbol, timeframe) is not None:
            return "mt5_upload"
        return self._candles_mem_source.get(cache_key, "unknown")

    @staticmethod
    def ema_series(values: pd.Series, period: int) -> pd.Series:
        return values.ewm(span=period, adjust=False).mean()

    @staticmethod
    def rsi_wilder(df: pd.DataFrame, period: int = 14) -> float:
        if len(df) < period + 1:
            return 50.0
        delta = df["close"].diff()
        gain = delta.clip(lower=0)
        loss = (-delta).clip(lower=0)
        avg_gain = gain.ewm(alpha=1 / period, adjust=False).mean()
        avg_loss = loss.ewm(alpha=1 / period, adjust=False).mean()
        rs = avg_gain.iloc[-1] / max(avg_loss.iloc[-1], 1e-10)
        return float(100 - (100 / (1 + rs)))

    @staticmethod
    def atr_series(df: pd.DataFrame, period: int = 14) -> pd.Series:
        high, low, close = df["high"], df["low"], df["close"]
        prev_close = close.shift(1)
        tr = pd.concat(
            [(high - low), (high - prev_close).abs(), (low - prev_close).abs()],
            axis=1,
        ).max(axis=1)
        return tr.ewm(alpha=1 / period, adjust=False).mean()

    def bollinger(
        self, df: pd.DataFrame, period: int = 20, std_dev: float = 2.0
    ) -> Tuple[float, float, float, float, bool, float]:
        if len(df) < period:
            c = float(df["close"].iloc[-1])
            return c, c, c, 0.0, False, 0.5
        close = df["close"]
        mid = close.rolling(period).mean()
        std = close.rolling(period).std()
        bb_mid = float(mid.iloc[-1])
        bb_up = float(mid.iloc[-1] + std_dev * std.iloc[-1])
        bb_dn = float(mid.iloc[-1] - std_dev * std.iloc[-1])
        bb_width = bb_up - bb_dn
        width_series = (mid + std_dev * std) - (mid - std_dev * std)
        bb_width_ma = float(width_series.rolling(20).mean().iloc[-1] or bb_width)
        bb_squeeze = bb_width < bb_width_ma * 0.85 if bb_width_ma > 0 else False
        bb_pctb = (float(close.iloc[-1]) - bb_dn) / bb_width if bb_width > 0 else 0.5
        return bb_up, bb_mid, bb_dn, bb_width, bb_squeeze, float(bb_pctb)

    def session_vwap(self, df: pd.DataFrame) -> float:
        if len(df) == 0:
            return 0.0
        tmp = df.copy()
        if isinstance(tmp.index, pd.DatetimeIndex):
            tmp["_day"] = tmp.index.date
        else:
            tmp["_day"] = 0
        last_day = tmp["_day"].iloc[-1]
        day = tmp[tmp["_day"] == last_day]
        typical = (day["high"] + day["low"] + day["close"]) / 3.0
        vol = day["volume"].replace(0, np.nan).fillna(1.0)
        return float((typical * vol).sum() / vol.sum())

    def macd(self, df: pd.DataFrame) -> Tuple[float, float]:
        if len(df) < 26:
            return 0.0, 0.0
        close = df["close"]
        ema12 = self.ema_series(close, 12)
        ema26 = self.ema_series(close, 26)
        macd_line = ema12 - ema26
        macd_sig = self.ema_series(macd_line, 9)
        return float(macd_line.iloc[-1]), float(macd_sig.iloc[-1])

    def supertrend(
        self, df: pd.DataFrame, atr_period: int = 10, mult: float = 3.0
    ) -> Tuple[int, float]:
        if len(df) < atr_period + 2:
            c = float(df["close"].iloc[-1])
            return 1, c
        high, low, close = df["high"], df["low"], df["close"]
        hl2 = (high + low) / 2.0
        atr = self.atr_series(df, atr_period)
        up_band = hl2 - mult * atr
        dn_band = hl2 + mult * atr

        st_up = np.zeros(len(df))
        st_dn = np.zeros(len(df))
        st_dir = np.ones(len(df), dtype=int)

        st_up[0] = up_band.iloc[0]
        st_dn[0] = dn_band.iloc[0]
        for i in range(1, len(df)):
            st_up[i] = max(up_band.iloc[i], st_up[i - 1] if st_dir[i - 1] == 1 else up_band.iloc[i])
            st_dn[i] = min(dn_band.iloc[i], st_dn[i - 1] if st_dir[i - 1] == -1 else dn_band.iloc[i])
            if close.iloc[i] > st_dn[i - 1]:
                st_dir[i] = 1
            elif close.iloc[i] < st_up[i - 1]:
                st_dir[i] = -1
            else:
                st_dir[i] = st_dir[i - 1]

        direction = int(st_dir[-1])
        level = float(st_up[-1] if direction == 1 else st_dn[-1])
        return direction, level

    def keltner_position(self, df: pd.DataFrame, ema_per: int = 20, mult: float = 1.5) -> float:
        if len(df) < ema_per + 2:
            return 0.0
        kc_mid = self.ema_series(df["close"], ema_per)
        kc_atr = self.atr_series(df, ema_per)
        upper = kc_mid.iloc[-1] + mult * kc_atr.iloc[-1]
        lower = kc_mid.iloc[-1] - mult * kc_atr.iloc[-1]
        if upper <= lower:
            return 0.0
        return float(((df["close"].iloc[-1] - lower) / (upper - lower)) * 2.0 - 1.0)

    def donchian_signal(self, df: pd.DataFrame, period: int = 20, atr_period: int = 10) -> float:
        if len(df) < period + 1:
            return 0.0
        dc_high = float(df["high"].rolling(period).max().iloc[-1])
        dc_low = float(df["low"].rolling(period).min().iloc[-1])
        atr = float(self.atr_series(df, atr_period).iloc[-1])
        close = float(df["close"].iloc[-1])
        if close > dc_high - atr * 0.05:
            return 1.0
        if close < dc_low + atr * 0.05:
            return -1.0
        return 0.0

    def ema_above_count(self, df: pd.DataFrame) -> int:
        if len(df) < 50:
            return 0
        close = float(df["close"].iloc[-1])
        emas = [self.ema_series(df["close"], p).iloc[-1] for p in (9, 13, 21, 50)]
        return sum(1 for e in emas if close > e)

    def mtf_direction(self, df: pd.DataFrame) -> Tuple[int, int]:
        """Pine get_dir() — BULL=1 BEAR=-1 NEUT=0 + RSI."""
        if len(df) < 55:
            return 0, int(self.rsi_wilder(df))
        ef = float(self.ema_series(df["close"], 9).iloc[-1])
        es = float(self.ema_series(df["close"], 21).iloc[-1])
        eh = float(self.ema_series(df["close"], 50).iloc[-1])
        c = float(df["close"].iloc[-1])
        rsi = self.rsi_wilder(df, 14)
        atr = float(self.atr_series(df, 10).iloc[-1])
        hl2 = float((df["high"].iloc[-1] + df["low"].iloc[-1]) / 2.0)
        st_bull = c > (hl2 + 3.0 * atr)
        bull = int(ef > es) + int(c > eh) + int(rsi > 52) + int(st_bull)
        bear = int(ef < es) + int(c < eh) + int(rsi < 48) + int(not st_bull)
        direction = 1 if bull >= 3 else (-1 if bear >= 3 else 0)
        return direction, int(round(rsi))

    def compute_kola_levels(
        self, df: pd.DataFrame, lb: int = 3, max_bars: int = 120
    ) -> Tuple[float, float]:
        if len(df) < lb * 2 + 5:
            close = float(df["close"].iloc[-1])
            return close * 0.998, close * 1.002
        work = df.tail(max_bars).reset_index(drop=True)
        close = float(work["close"].iloc[-1])
        best_buy, best_sell = 0.0, 0.0

        for i in range(lb, len(work) - lb):
            low_i = float(work["low"].iloc[i])
            if all(low_i < float(work["low"].iloc[i - k]) for k in range(1, lb + 1)) and all(
                low_i <= float(work["low"].iloc[i + k]) for k in range(1, lb + 1) if i + k < len(work)
            ):
                if low_i < close and (best_buy == 0 or low_i > best_buy):
                    best_buy = low_i

            high_i = float(work["high"].iloc[i])
            if all(high_i > float(work["high"].iloc[i - k]) for k in range(1, lb + 1)) and all(
                high_i >= float(work["high"].iloc[i + k]) for k in range(1, lb + 1) if i + k < len(work)
            ):
                if high_i > close and (best_sell == 0 or high_i < best_sell):
                    best_sell = high_i

        if best_buy <= 0:
            best_buy = close * 0.998
        if best_sell <= 0:
            best_sell = close * 1.002
        return best_buy, best_sell

    def compute_order_blocks(self, df: pd.DataFrame, lookback: int = 10) -> Dict[str, float]:
        out = {"ob_bull_top": 0.0, "ob_bull_bot": 0.0, "ob_bear_top": 0.0, "ob_bear_bot": 0.0}
        if len(df) < lookback * 2 + 3:
            return out
        high, low, open_, close = df["high"], df["low"], df["open"], df["close"]
        n = len(df)

        for i in range(lookback, n - lookback):
            if all(high.iloc[i] >= high.iloc[i - k] for k in range(1, lookback + 1)) and all(
                high.iloc[i] >= high.iloc[i + k] for k in range(1, lookback + 1)
            ):
                j = i - lookback - 1
                if j >= 0:
                    out["ob_bear_top"] = float(high.iloc[j])
                    out["ob_bear_bot"] = float(min(open_.iloc[j], close.iloc[j]))
            if all(low.iloc[i] <= low.iloc[i - k] for k in range(1, lookback + 1)) and all(
                low.iloc[i] <= low.iloc[i + k] for k in range(1, lookback + 1)
            ):
                j = i - lookback - 1
                if j >= 0:
                    out["ob_bull_top"] = float(max(open_.iloc[j], close.iloc[j]))
                    out["ob_bull_bot"] = float(low.iloc[j])
        return out

    def compute_bos(self, df: pd.DataFrame, struct_lb: int = 8) -> Dict[str, bool]:
        out = {"bos_bull": False, "bos_bear": False}
        if len(df) < struct_lb * 2 + 5:
            return out
        high, low, close = df["high"], df["low"], df["close"]
        last_ph = prev_ph = last_pl = prev_pl = None
        n = len(df)
        for i in range(struct_lb, n - struct_lb):
            if all(high.iloc[i] >= high.iloc[i - k] for k in range(1, struct_lb + 1)) and all(
                high.iloc[i] >= high.iloc[i + k] for k in range(1, struct_lb + 1)
            ):
                prev_ph, last_ph = last_ph, float(high.iloc[i])
            if all(low.iloc[i] <= low.iloc[i - k] for k in range(1, struct_lb + 1)) and all(
                low.iloc[i] <= low.iloc[i + k] for k in range(1, struct_lb + 1)
            ):
                prev_pl, last_pl = last_pl, float(low.iloc[i])
        c = float(close.iloc[-1])
        choch_bear = last_ph is not None and prev_ph is not None and prev_pl is not None and c < prev_pl and last_ph < prev_ph
        choch_bull = last_pl is not None and prev_pl is not None and prev_ph is not None and c > prev_ph and last_pl > prev_pl
        out["bos_bear"] = last_pl is not None and c < last_pl and not choch_bear
        out["bos_bull"] = last_ph is not None and c > last_ph and not choch_bull
        return out

    def compute_spike(self, df: pd.DataFrame, st_dir: int, vwap: float, spike_lb: int = 25) -> Dict[str, Any]:
        if len(df) < spike_lb + 5:
            return {
                "spike_prob": 0.0,
                "spike_pct": 0.0,
                "spike_bull": False,
                "spike_bear": False,
                "spike_level_num": 0,
                "spike_tradable": False,
                "spike_pred_prob": 0.0,
            }
        close = df["close"]
        open_ = df["open"]
        high, low, volume = df["high"], df["low"], df["volume"]
        atr14 = self.atr_series(df, 14)
        atr_comp_ratio = float(atr14.iloc[-1] / max(atr14.iloc[-2], 1e-10))
        atr_compression = min(max((1.0 - atr_comp_ratio) / 0.6, 0.0), 1.0) if atr_comp_ratio < 1.0 else 0.0
        change1 = (close.iloc[-1] - close.iloc[-2]) / max(close.iloc[-2], 1e-10)
        change2 = (close.iloc[-2] - close.iloc[-4]) / max(close.iloc[-4], 1e-10) if len(close) >= 4 else 0.0
        accel = min(abs(change1 - change2) / 0.003, 1.0)
        avg_vol = float(volume.tail(spike_lb).mean()) or 1.0
        vol_surge = min(max((float(volume.iloc[-1]) / avg_vol - 1.0) / 1.5, 0.0), 1.0) if avg_vol > 0 else 0.0
        spike_prob_mql = 0.40 * atr_compression + 0.35 * accel + 0.25 * vol_surge
        spike_prob_mql = min(max(spike_prob_mql, 0.0), 1.0)

        candle_body = abs(float(close.iloc[-1] - open_.iloc[-1]))
        candle_range = float(high.iloc[-1] - low.iloc[-1]) or 1e-10
        body_ratio = candle_body / candle_range
        avg_range = float((high - low).tail(spike_lb).mean()) or 1e-10
        momentum = abs(float(close.iloc[-1] - close.iloc[-spike_lb])) / (avg_range * spike_lb + 1e-10)
        body_score = 0.4 if body_ratio > 0.65 else (0.2 if body_ratio > 0.45 else 0.0)
        bb_up, bb_mid, bb_dn, bb_width, bb_squeeze, _ = self.bollinger(df)
        bb_sq_score = 0.3 if bb_squeeze else 0.0
        _, st_level = self.supertrend(df)
        st_score = 0.3 if (
            (float(close.iloc[-1]) > st_level and st_dir == 1)
            or (float(close.iloc[-1]) < st_level and st_dir == -1)
        ) else -0.1
        spike_raw = (
            momentum * 0.25
            + spike_prob_mql * 0.40
            + body_score * 0.15
            + bb_sq_score * 0.10
            + st_score * 0.10
        )
        spike_prob = min(max(spike_raw, 0.0), 1.0)
        c = float(close.iloc[-1])
        o = float(open_.iloc[-1])
        spike_bull = c > o and c > vwap and st_dir == 1
        spike_bear = c < o and c < vwap and st_dir == -1
        return {
            "spike_prob": spike_prob,
            "spike_pct": round(spike_prob * 100.0, 1),
            "spike_bull": spike_bull,
            "spike_bear": spike_bear,
            "spike_level_num": 2 if spike_prob >= 0.62 else (1 if spike_prob >= 0.52 else 0),
            "spike_tradable": spike_prob >= 0.55,
            "spike_pred_prob": round(spike_prob * 100.0),
        }

    def analyze_chart(self, df: pd.DataFrame, symbol: str = "") -> Dict[str, Any]:
        """Indicateurs chart TF principal (M15 par défaut)."""
        if df is None or len(df) < 30:
            return {}
        close = float(df["close"].iloc[-1])
        bb_up, bb_mid, bb_dn, bb_width, bb_squeeze, bb_pctb = self.bollinger(df)
        vwap = self.session_vwap(df)
        rsi14 = self.rsi_wilder(df, 14)
        macd_line, macd_sig = self.macd(df)
        st_dir, st_level = self.supertrend(df)
        kola_buy, kola_sell = self.compute_kola_levels(df)
        atr14 = float(self.atr_series(df, 14).iloc[-1])
        kola_near_buy = abs(close - kola_buy) <= atr14 * 1.5
        kola_near_sell = abs(close - kola_sell) <= atr14 * 1.5
        vwap_dist_pct = (close - vwap) / vwap if vwap > 0 else 0.0
        vwap_mag = min(1.0, abs(vwap_dist_pct) / 0.0025)

        record: Dict[str, Any] = {
            "symbol": symbol,
            "close": round(close, 5),
            "entry": round(close, 5),
            "open": round(float(df["open"].iloc[-1]), 5),
            "high": round(float(df["high"].iloc[-1]), 5),
            "low": round(float(df["low"].iloc[-1]), 5),
            "volume": float(df["volume"].iloc[-1]),
            "rsi14": int(round(rsi14)),
            "bb_up": round(bb_up, 5),
            "bb_mid": round(bb_mid, 5),
            "bb_dn": round(bb_dn, 5),
            "bb_width": round(bb_width, 5),
            "bb_pctb": round(bb_pctb, 4),
            "bb_squeeze": bb_squeeze,
            "bb_width_ma": round(bb_width, 5),
            "vwap": round(vwap, 5),
            "vwap_dist_pct": round(vwap_dist_pct, 6),
            "vwap_mag": round(vwap_mag, 4),
            "macd_line": round(macd_line, 5),
            "macd_sig": round(macd_sig, 5),
            "st_dir": st_dir,
            "st_level": round(st_level, 5),
            "kc_pos": round(self.keltner_position(df), 4),
            "dc_sig": self.donchian_signal(df),
            "ema_above_count": self.ema_above_count(df),
            "kola_buy": round(kola_buy, 5),
            "kola_sell": round(kola_sell, 5),
            "kola_near_buy": kola_near_buy,
            "kola_near_sell": kola_near_sell,
            "atr14": round(atr14, 5),
        }
        record.update(self.compute_order_blocks(df))
        record.update(self.compute_bos(df))
        record.update(self.compute_spike(df, st_dir, vwap))
        record.update(self.compute_ote_zone(df, symbol))
        sym_lc = symbol.lower().replace(" ", "")
        sym_up = symbol.upper().replace(" ", "")
        record["spike_bc_en"] = (
            "boom" in sym_lc or "crash" in sym_lc
            or sym_up.startswith("PAINX") or sym_up.startswith("GAINX")
            or "FXVOL" in sym_up or "SFVVOL" in sym_up or "SFXVOL" in sym_up
            or "TRENDX" in sym_up or "BREAKX" in sym_up
            or "vol" in sym_lc
        )
        return record

    def compute_ote_zone(self, df: pd.DataFrame, symbol: str = "", lookback: int = 50) -> Dict[str, Any]:
        """Zone OTE (Optimal Trade Entry) — Fibonacci 61.8%–78.6% du dernier swing HH/LL.
        Compatible avec la logique de deriveapro.mq5 (SR_BuildSMCSetup).
        """
        empty = {
            "ote_top": 0.0, "ote_bot": 0.0,
            "ote_fib618": 0.0, "ote_fib786": 0.0,
            "in_ote": False, "ote_dir": 0,
            "ote_swing_hi": 0.0, "ote_swing_lo": 0.0,
        }
        if df is None or len(df) < lookback:
            return empty
        try:
            tail = df.tail(lookback)
            hi = float(tail["high"].max())
            lo = float(tail["low"].min())
            close = float(df["close"].iloc[-1])
            swing = hi - lo
            if swing <= 0:
                return empty

            # Direction dominante sur le swing : prix sous midpoint → BUY setup, au-dessus → SELL setup
            mid = (hi + lo) / 2.0
            sym_lc = symbol.lower()
            is_boom = "boom" in sym_lc
            is_crash = "crash" in sym_lc

            if is_boom:
                ote_dir = 1   # Boom = BUY only
            elif is_crash:
                ote_dir = -1  # Crash = SELL only
            else:
                ote_dir = 1 if close < mid else -1

            # Fibonacci depuis l'extrême (logique deriveapro.mq5)
            if ote_dir == 1:  # BUY : retracement depuis HH vers LL
                fib618 = hi - swing * 0.618
                fib786 = hi - swing * 0.786
                ote_top = fib618  # niveau haut de la zone (61.8%)
                ote_bot = fib786  # niveau bas de la zone (78.6%)
            else:              # SELL : retracement depuis LL vers HH
                fib618 = lo + swing * 0.618
                fib786 = lo + swing * 0.786
                ote_bot = fib618
                ote_top = fib786

            in_ote = (ote_bot <= close <= ote_top)

            return {
                "ote_top":      round(ote_top, 5),
                "ote_bot":      round(ote_bot, 5),
                "ote_fib618":   round(fib618, 5),
                "ote_fib786":   round(fib786, 5),
                "in_ote":       in_ote,
                "ote_dir":      ote_dir,
                "ote_swing_hi": round(hi, 5),
                "ote_swing_lo": round(lo, 5),
            }
        except Exception:
            return empty

    def compute_mtf(self, symbol: str, broker: Optional[str] = None) -> Dict[str, Any]:
        """Directions + RSI par TF (Pine MTF table)."""
        tf_keys = {
            "m1": "1",
            "m5": "5",
            "m15": "15",
            "m30": "30",
            "h1": "60",
            "h4": "240",
            "d1": "D",
            "w1": "W",
        }
        dirs: Dict[str, int] = {}
        rsis: Dict[str, int] = {}
        for name, tf in tf_keys.items():
            df = self.get_candles(symbol, tf, 200, allow_deriv=self._is_deriv_synthetic(symbol), broker=broker)
            if len(df) < 55:
                dirs[name] = 0
                rsis[name] = 50
            else:
                d, r = self.mtf_direction(df)
                dirs[name] = d
                rsis[name] = r

        tb = sum(1 for d in dirs.values() if d == 1)
        ts = sum(1 for d in dirs.values() if d == -1)
        if tb >= 5:
            gd = 1
        elif ts >= 5:
            gd = -1
        elif tb > ts:
            gd = 1
        elif ts > tb:
            gd = -1
        else:
            gd = 0

        def _dir_txt(d: int) -> str:
            return "BULL" if d == 1 else ("BEAR" if d == -1 else "NEUT")

        out: Dict[str, Any] = {
            "tf_global_dir": _dir_txt(gd),
            "tf_global_strength": max(tb, ts),
            "tf_bull_count": tb,
            "tf_bear_count": ts,
        }
        for name in tf_keys:
            out[f"tf_{name}_dir"] = _dir_txt(dirs[name])
            out[f"tf_{name}_rsi"] = rsis[name]
        return out

    def clear_symbol_cache(self, symbol: str) -> None:
        """Invalide le cache mémoire après upload MT5."""
        prefix = f"{symbol}:"
        for key in list(self._candles_mem_cache.keys()):
            if key.startswith(prefix):
                del self._candles_mem_cache[key]
                self._candles_mem_cache_ts.pop(key, None)
                self._candles_mem_source.pop(key, None)

    def _has_upload_mtf(self, symbol: str) -> bool:
        for tf in ("1", "5", "15", "60", "240", "D"):
            if self._cache_lookup(symbol, tf) is None:
                return False
        return True

    def prefetch_mtf(self, symbol: str, bars: int = 200, broker: Optional[str] = None) -> None:
        """Précharge tous les TF — saute si l'EA a déjà uploadé les bougies."""
        if self._has_upload_mtf(symbol):
            return
        for tf in ("1", "5", "15", "60", "240", "D"):
            self.get_candles(symbol, tf, bars, allow_deriv=False, broker=broker)

    def calculate_record_live(self, symbol: str, timeframe: str = "15", broker: Optional[str] = None) -> Dict[str, Any]:
        primary_tf = normalize_tf_key(timeframe)
        self.prefetch_mtf(symbol, 200, broker=broker)
        df = self.get_candles(symbol, primary_tf, 200, allow_deriv=self._is_deriv_synthetic(symbol), broker=broker)
        used_tf = primary_tf
        if df is None or len(df) < 30:
            hint = "Ouvrez MT5 (Deriv) + pip install MetaTrader5"
            if MT5_FETCHER_AVAILABLE:
                hint = "MT5 ouvert ? Vérifiez le symbole sur le graphique EA"
            return {
                "symbol": symbol,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "error": f"No candles for {symbol} TF {primary_tf} — {hint}",
                "source": "live_calculation_failed",
                "ok": False,
                "chart_tf": primary_tf,
                "verdict": "WAIT",
                "verdict_num": 0,
            }

        record = self.analyze_chart(df, symbol)
        record["chart_tf"] = used_tf
        record.update(self.compute_mtf(symbol, broker=broker))
        record["timestamp"] = datetime.now(timezone.utc).isoformat()
        record["source"] = "live_calculation"
        record["data_source"] = self._candle_source_for(symbol, used_tf)

        # FIX-DISCORDANCE-01 : renseigne le contexte M1 (price_direction_5b,
        # bars_since_spike, m1_last_bar_time — indépendants de la direction du
        # trade) AVANT le calcul du verdict. Sans ça, apply_price_reality_gate()
        # exécuté à l'intérieur de enrich_record() tournait sur des valeurs par
        # défaut (bars=-1, direction=0) et ne pouvait jamais rien corriger sur
        # cette première passe — le garde-fou anti-"PERFECT figé contre la
        # réalité M1" était inopérant précisément quand il servait le plus.
        self._enrich_m1_price_context(symbol, record, broker=broker)

        if self.pine:
            record = self.pine.enrich_record(record)
            # m1_opp_bars (bougies M1 adverses) dépend du SENS du trade, connu
            # seulement maintenant que verdict_num existe. On rafraîchit le
            # contexte M1 (recalcule m1_opp_bars avec la bonne direction) puis
            # on ré-applique le même gate canonique — dégrade uniquement,
            # jamais d'upgrade — pour attraper les cas micro_stairs/m1_against
            # qui nécessitent cette donnée.
            self._enrich_m1_price_context(symbol, record, broker=broker)
            try:
                from gom_pine_calculator import apply_price_reality_gate, verdict_text_from_num
                vn = int(record.get("verdict_num", 0) or 0)
                if vn != 0:
                    new_vn, reason = apply_price_reality_gate(record, vn)
                    if new_vn != vn:
                        record["verdict_num"] = new_vn
                        record["verdict"] = verdict_text_from_num(new_vn)
                    if reason:
                        record["price_reality_reason"] = reason
            except Exception as exc:
                print(f"[GOM-M1-REGATE] {symbol}: {exc}")
        else:
            self._enrich_m1_price_context(symbol, record, broker=broker)

        record["ok"] = True
        return record

    def _enrich_m1_price_context(
        self, symbol: str, record: Dict[str, Any], broker: Optional[str] = None
    ) -> None:
        """Métriques M1 canoniques (gom_pine_calculator.enrich_m1_metrics)."""
        from gom_pine_calculator import enrich_m1_metrics

        allow_deriv = self._is_deriv_synthetic(symbol)
        df = self.get_candles(symbol, "1", 80, allow_deriv=allow_deriv, broker=broker)
        if df is None or len(df) < 6:
            return

        closes = df["close"].astype(float).tolist()
        opens = df["open"].astype(float).tolist()
        highs = df["high"].astype(float).tolist()
        lows = df["low"].astype(float).tolist()
        record["symbol"] = record.get("symbol") or symbol
        enrich_m1_metrics(record, closes, opens, highs, lows)

        try:
            if isinstance(df.index, pd.DatetimeIndex) and len(df.index) > 0:
                record["m1_last_bar_time"] = int(df.index[-1].timestamp())
            elif "time" in df.columns:
                t = df["time"].iloc[-1]
                if hasattr(t, "timestamp"):
                    record["m1_last_bar_time"] = int(t.timestamp())
        except Exception:
            pass

    def _apply_correction_detection(self, symbol: str, verdict_num: int, record: Dict[str, Any]) -> int:
        """Rétrograde si trop de bougies M1 sans spike (compteur bougie, pas poll)."""
        spike_prob = float(record.get("spike_prob", 0) or 0)
        spike_tradable = bool(record.get("spike_tradable", False))
        spike_confirmed = spike_tradable and spike_prob >= 0.55

        sym_key = str(symbol).upper()
        bar_t = int(record.get("m1_last_bar_time", 0) or 0)

        if record.get("bars_since_spike") is not None:
            bars_no_spike = int(record.get("bars_since_spike", 0) or 0)
        else:
            if bar_t > 0 and bar_t != self._last_m1_bar_time.get(sym_key, 0):
                self._last_m1_bar_time[sym_key] = bar_t
                if spike_confirmed:
                    if self._bars_without_spike.get(sym_key, 0) > 0:
                        print(
                            f"[GOM-SPIKE-CONFIRMED] {symbol}: spike confirmé | "
                            f"bougies sans spike={self._bars_without_spike.get(sym_key, 0)}"
                        )
                    self._bars_without_spike[sym_key] = 0
                    self._last_spike_time[sym_key] = time.time()
                else:
                    self._bars_without_spike[sym_key] = self._bars_without_spike.get(sym_key, 0) + 1
            bars_no_spike = self._bars_without_spike.get(sym_key, 0)
        
        # ── RÉTROGRADATION AUTOMATIQUE SANS SPIKE (assouplie FIX 2026-08-09) ──
        # Seuils relevés pour éviter un WAIT permanent hors micro-spikes.
        # Forçage WAIT désactivé par défaut (GOM_FORCE_WAIT_NO_SPIKE=1 pour réactiver).
        _retro_after = int(os.getenv("GOM_RETROGRADE_BARS", "25"))
        _simple_after = int(os.getenv("GOM_SIMPLE_BARS", "35"))
        _force_wait_after = int(os.getenv("GOM_FORCE_WAIT_BARS", "60"))
        _force_wait_enabled = os.getenv("GOM_FORCE_WAIT_NO_SPIKE", "").lower() in ("1", "true", "yes", "on")

        if bars_no_spike > _retro_after and abs(verdict_num) >= 2:
            prev_vn = verdict_num
            # PERFECT → GOOD
            if abs(verdict_num) >= 3:
                verdict_num = 2 if verdict_num > 0 else -2
                print(f"[GOM-RETROGRADE] {symbol}: PERFECT → GOOD (plus de {bars_no_spike} bougies sans spike) | vn={prev_vn} → {verdict_num}")
            # GOOD → SIMPLE
            elif bars_no_spike > _simple_after:
                verdict_num = 1 if verdict_num > 0 else -1
                print(f"[GOM-RETROGRADE] {symbol}: GOOD → SIMPLE (plus de {bars_no_spike} bougies sans spike) | vn={prev_vn} → {verdict_num}")

        # ── FORÇAGE WAIT (opt-in uniquement) ──
        if _force_wait_enabled and bars_no_spike > _force_wait_after and verdict_num != 0:
            prev_verd = self.pine.verdict_text(verdict_num)
            verdict_num = 0
            print(
                f"[GOM-FORCE-WAIT] {symbol}: WAIT après {bars_no_spike} bougies M1 sans spike | "
                f"{prev_verd} → WAIT"
            )

        return verdict_num

    def build_api_response(self, symbol: str, chart_tf: str = "15", broker: Optional[str] = None) -> Dict[str, Any]:
        """Payload compatible SMC_GOM_Pipeline.mqh / gom-kola-dashboard."""
        record = self.calculate_record_live(symbol, chart_tf, broker=broker)
        if record.get("error"):
            return {
                "ok": False,
                "symbol": symbol,
                "timestamp": record.get("timestamp"),
                "error": record.get("error"),
                "source": record.get("source"),
            }

        # Gate réalité prix déjà appliqué dans calculate_record_live / enrich_record
        verdict_num = int(record.get("verdict_num", 0) or 0)
        record["verdict_num"] = verdict_num
        record["verdict"] = self.pine.verdict_text(verdict_num)

        price = record.get("entry", record.get("close", 0.0))
        bars_raw = record.get("bars_since_spike")
        bars_out = int(bars_raw) if bars_raw is not None and int(bars_raw) >= 0 else 0
        resp: Dict[str, Any] = {
            "ok": True,
            "symbol": symbol,
            "timestamp": record.get("timestamp"),
            "verdict": record.get("verdict", "WAIT"),
            "verdict_num": record.get("verdict_num", 0),
            "score_buy": round(float(record.get("score_buy", 0)), 2),
            "score_sell": round(float(record.get("score_sell", 0)), 2),
            "verdict_gap": round(float(record.get("verdict_gap", 0)), 2),
            "kola_buy": round(float(record.get("kola_buy", 0)), 5),
            "kola_sell": round(float(record.get("kola_sell", 0)), 5),
            "entry": round(float(record.get("entry", 0)), 5),
            "close": round(float(record.get("close", 0)), 5),
            "price": round(float(price), 5),
            "vwap": round(float(record.get("vwap", 0)), 5),
            "rsi": int(record.get("rsi14", 50)),
            "rsi14": int(record.get("rsi14", 50)),
            "macd_line": round(float(record.get("macd_line", 0)), 5),
            "macd_sig": round(float(record.get("macd_sig", 0)), 5),
            "tf_global_dir": record.get("tf_global_dir", "NEUT"),
            "tf_global_strength": int(record.get("tf_global_strength", 0)),
            "tf_m1_dir": record.get("tf_m1_dir", "NEUT"),
            "tf_m1_rsi": int(record.get("tf_m1_rsi", 50)),
            "tf_m5_dir": record.get("tf_m5_dir", "NEUT"),
            "tf_m5_rsi": int(record.get("tf_m5_rsi", 50)),
            "tf_m15_dir": record.get("tf_m15_dir", "NEUT"),
            "tf_m15_rsi": int(record.get("tf_m15_rsi", 50)),
            "tf_h1_dir": record.get("tf_h1_dir", "NEUT"),
            "tf_h1_rsi": int(record.get("tf_h1_rsi", 50)),
            "tf_h4_dir": record.get("tf_h4_dir", "NEUT"),
            "tf_h4_rsi": int(record.get("tf_h4_rsi", 50)),
            "tf_d1_dir": record.get("tf_d1_dir", "NEUT"),
            "tf_d1_rsi": int(record.get("tf_d1_rsi", 50)),
            "coherence_ok": record.get("coherence_ok", False),
            "coherence_pct": round(float(record.get("coherence_pct", 0)), 1),
            "filter_ratio": round(float(record.get("filter_ratio", 0)), 2),
            "bb_up": round(float(record.get("bb_up", 0)), 5),
            "bb_mid": round(float(record.get("bb_mid", 0)), 5),
            "bb_dn": round(float(record.get("bb_dn", 0)), 5),
            "bb_width": round(float(record.get("bb_width", 0)), 5),
            "st_dir": int(record.get("st_dir", 0)),
            "st_level": round(float(record.get("st_level", 0)), 5),
            "ob_bull_top": round(float(record.get("ob_bull_top", 0)), 5),
            "ob_bull_bot": round(float(record.get("ob_bull_bot", 0)), 5),
            "ob_bear_top": round(float(record.get("ob_bear_top", 0)), 5),
            "ob_bear_bot": round(float(record.get("ob_bear_bot", 0)), 5),
            "spike_pct": round(float(record.get("spike_pct", 0)), 1),
            "spike_level": int(record.get("spike_level_num", record.get("spike_level", 0))),
            "imminence_pct": round(float(record.get("spike_imminence", record.get("imminence_pct", 0))), 1),
            "spike_tradable": bool(record.get("spike_tradable", False)),
            "bars_since_spike": bars_out,
            "m1_opp_bars": int(record.get("m1_opp_bars", 0) or 0),
            "price_direction_1b": float(record.get("price_direction_1b", 0) or 0),
            "price_direction_3b": float(record.get("price_direction_3b", 0) or 0),
            "price_direction_5b": float(record.get("price_direction_5b", 0) or 0),
            "m1_momentum": float(record.get("m1_momentum", 0) or 0),
            "tf_m1_dir_live": record.get("tf_m1_dir_live", record.get("tf_m1_dir", "NEUT")),
            "price_reality_reason": record.get("price_reality_reason", ""),
            "verdict_zero_hint": record.get("verdict_zero_hint", ""),
            "harmonized_m1": True,
            "verdict_mode": "reactive_pine",
            "m1_last_bar_time": int(record.get("m1_last_bar_time", 0) or 0),
            "spike_progress_pct": round(float(record.get("spike_progress_pct", 0)), 1),
            "atr": round(float(record.get("atr14", 0)), 5),
            "atr14": round(float(record.get("atr14", 0)), 5),
            "entry_quality": round(float(record.get("entry_quality", 0)) * 100, 1),
            "kola_state": "NB" if record.get("kola_near_buy") else ("NS" if record.get("kola_near_sell") else "---"),
            # OTE zone (Optimal Trade Entry — Fibonacci 61.8%–78.6% du swing HH/LL)
            "ote_top":      round(float(record.get("ote_top", 0)), 5),
            "ote_bot":      round(float(record.get("ote_bot", 0)), 5),
            "ote_fib618":   round(float(record.get("ote_fib618", 0)), 5),
            "ote_fib786":   round(float(record.get("ote_fib786", 0)), 5),
            "in_ote":       bool(record.get("in_ote", False)),
            "ote_dir":      int(record.get("ote_dir", 0)),
            "ote_swing_hi": round(float(record.get("ote_swing_hi", 0)), 5),
            "ote_swing_lo": round(float(record.get("ote_swing_lo", 0)), 5),
            "pred_path": "",
            "data_source": record.get("data_source", "live_calculation"),
            "chart_tf": record.get("chart_tf", normalize_tf_key(chart_tf)),
            "source": record.get("data_source", "live_calculation"),
            "candle_source": record.get("data_source", "live_calculation"),
            "asset_category": record.get("asset_category", "other"),
        }
        _attach_correction_cycle(resp, symbol, self)
        return resp


def _attach_correction_cycle(payload: Dict[str, Any], symbol: str, calc: "GOMSignalsLiveCalculator") -> None:
    """Cycle correction (debut/milieu/fin) — disponible dès le poll MT5."""
    try:
        from correction_cycle_detector import compute_correction_exhaustion

        allow_deriv = calc._is_deriv_synthetic(symbol)  # noqa: SLF001
        df_m1 = calc.get_candles(symbol, "1", 200, allow_deriv=allow_deriv)
        df_m5 = calc.get_candles(symbol, "5", 200, allow_deriv=allow_deriv)
        df_m15 = calc.get_candles(symbol, "15", 200, allow_deriv=allow_deriv)

        vn = int(payload.get("verdict_num", 0) or 0)
        result = compute_correction_exhaustion(
            df_m5=df_m5 if len(df_m5) >= 25 else None,
            df_m15=df_m15 if len(df_m15) >= 25 else None,
            df_m1=df_m1 if len(df_m1) >= 25 else None,
            rsi_h4=float(payload.get("tf_h4_rsi", 50) or 50),
            rsi_h1=float(payload.get("tf_h1_rsi", 50) or 50),
            rsi_d1=float(payload.get("tf_d1_rsi", 50) or 50),
            direction_hint=vn,
            rsi_m1=float(payload.get("tf_m1_rsi", 50) or 50),
            rsi_m5=float(payload.get("tf_m5_rsi", 50) or 50),
            rsi_m15=float(payload.get("tf_m15_rsi", 50) or 50),
        )
        payload.update(result)
        payload["correction_pullback_depth_pct"] = result.get("pullback_depth_pct", 0)
        # Alias MT5 (SMC_GOM_Pipeline parse pa_*)
        payload["pa_trend"] = result.get("price_action_trend", "UNKNOWN")
        payload["pa_in_correction"] = bool(result.get("price_action_in_correction"))
        payload["pa_consolidation"] = bool(result.get("price_action_consolidation"))
        if result.get("price_action_ma50"):
            payload["pa_ma50"] = result["price_action_ma50"]
        if result.get("price_action_ma200"):
            payload["pa_ma200"] = result["price_action_ma200"]
        if result.get("price_action_rsi") is not None:
            payload["pa_rsi"] = result["price_action_rsi"]
        if result.get("price_action_zone_support"):
            payload["pa_zone_support"] = result["price_action_zone_support"]
        if result.get("price_action_zone_resistance"):
            payload["pa_zone_resistance"] = result["price_action_zone_resistance"]
        payload["pa_corr_depth_pct"] = result.get("price_action_correction_depth_pct", 0)

        # ── M1 price-pullback gate: override GOOD/PERFECT → WAIT ─────────────
        # Seuil ADAPTATIF par classe d'actif (FIX 2026-08-09) :
        # - Synthétiques Boom/Crash/PainX/GainX/Vol : OFF par défaut (points ≠ $)
        #   → ancien seuil fixe 2.0 forçait WAIT partout (bug PainX 1200).
        # - Métaux (XAU/XAG) : 5.0 $
        # - Forex : OFF (échelle prix trop différente)
        # Override global possible via GOM_M1_WAIT_DOLLARS (>0 force partout, 0=off).
        def _m1_wait_threshold(sym: str) -> float:
            env = os.getenv("GOM_M1_WAIT_DOLLARS")
            if env is not None and str(env).strip() != "":
                try:
                    return float(env)
                except (TypeError, ValueError):
                    pass
            s = str(sym or "").upper().replace(" ", "")
            if any(x in s for x in (
                "BOOM", "CRASH", "PAINX", "GAINX", "TRENDX", "BREAKX",
                "VOL", "STEP", "JUMP", "FXVOL", "SFVVOL", "SFXVOL",
            )):
                return float(os.getenv("GOM_M1_WAIT_SYNTH", "0"))
            if any(x in s for x in ("XAU", "GOLD", "XAG", "SILVER")):
                return float(os.getenv("GOM_M1_WAIT_METALS", "5.0"))
            # Forex / autres : désactivé par défaut (2.0 était absurde en pips)
            return float(os.getenv("GOM_M1_WAIT_FOREX", "0"))

        _GOM_M1_WAIT_DOLLARS = _m1_wait_threshold(symbol)
        _vn_before = int(payload.get("verdict_num", 0) or 0)
        if (
            _GOM_M1_WAIT_DOLLARS > 0
            and _vn_before != 0
            and abs(_vn_before) >= 2
            and df_m1 is not None
            and len(df_m1) >= 5
        ):
            close_prices = df_m1["close"].astype(float)
            highs = df_m1["high"].astype(float)
            lows = df_m1["low"].astype(float)
            current_price = float(close_prices.iloc[-1])
            lookback = min(20, len(df_m1))
            recent_high = float(highs.iloc[-lookback:].max())
            recent_low = float(lows.iloc[-lookback:].min())
            range_dollars = recent_high - recent_low
            if _vn_before > 0:
                pullback_adverse = recent_high - current_price
            else:
                pullback_adverse = current_price - recent_low
            payload["m1_max_range_dollars"] = round(range_dollars, 5)
            payload["m1_adverse_excursion"] = round(pullback_adverse, 5)
            payload["m1_wait_threshold"] = _GOM_M1_WAIT_DOLLARS
            if pullback_adverse > _GOM_M1_WAIT_DOLLARS:
                old_verdict = payload.get("verdict", "")
                payload["verdict_num"] = 0
                payload["verdict"] = "WAIT"
                payload["action"] = "WAIT"
                payload["gate"] = "m1_correction"
                print(
                    f"[GOM-M1GATE] {symbol}: vn={_vn_before}→0 WAIT | "
                    f"adverse={pullback_adverse:.2f} range={range_dollars:.2f} "
                    f"threshold={_GOM_M1_WAIT_DOLLARS} | was '{old_verdict}'"
                )
        elif _vn_before != 0 and df_m1 is not None and len(df_m1) >= 5:
            # Diagnostic only (gate disabled for this symbol class)
            try:
                highs = df_m1["high"].astype(float)
                lows = df_m1["low"].astype(float)
                close_prices = df_m1["close"].astype(float)
                lookback = min(20, len(df_m1))
                recent_high = float(highs.iloc[-lookback:].max())
                recent_low = float(lows.iloc[-lookback:].min())
                current_price = float(close_prices.iloc[-1])
                if _vn_before > 0:
                    pullback_adverse = recent_high - current_price
                else:
                    pullback_adverse = current_price - recent_low
                payload["m1_max_range_dollars"] = round(recent_high - recent_low, 5)
                payload["m1_adverse_excursion"] = round(pullback_adverse, 5)
                payload["m1_wait_threshold"] = 0.0
            except Exception:
                pass
    except Exception:
        payload.setdefault("correction_stage", "unknown")
        payload.setdefault("correction_entry_safe", True)


def test_live_calculator():
    calc = GOMSignalsLiveCalculator()
    for symbol in ["XAUUSD"]:
        resp = calc.build_api_response(symbol)
        print(json.dumps({k: resp[k] for k in ("ok", "verdict", "verdict_num", "score_buy", "score_sell", "data_source")}, indent=2))


if __name__ == "__main__":
    test_live_calculator()
