import math
from typing import Dict, Any, List
import pandas as pd


def _ensure_df(df: pd.DataFrame) -> pd.DataFrame:
    if df is None:
        return pd.DataFrame()
    if not isinstance(df, pd.DataFrame):
        try:
            df = pd.DataFrame(df)
        except Exception:
            return pd.DataFrame()
    return df.copy()


def compute_market_structure(df: pd.DataFrame) -> Dict[str, Any]:
    df = _ensure_df(df)
    result = {"swings": [], "bos": [], "choch": [], "regime": "unknown"}
    if df.empty or not set(["high", "low", "close"]).issubset(df.columns):
        return result
    try:
        highs = df["high"].values
        lows = df["low"].values
        closes = df["close"].values
        idx = df.index
        # Swings naïfs: pivot si high>high±1 et low<low±1
        for i in range(1, len(df) - 1):
            if highs[i] > highs[i - 1] and highs[i] > highs[i + 1]:
                result["swings"].append({"type": "swing_high", "index": str(idx[i]), "price": float(highs[i])})
            if lows[i] < lows[i - 1] and lows[i] < lows[i + 1]:
                result["swings"].append({"type": "swing_low", "index": str(idx[i]), "price": float(lows[i])})
        # BOS/CHOCH naïfs: cassure du dernier swing opposé
        last_high = next((s for s in reversed(result["swings"]) if s["type"] == "swing_high"), None)
        last_low = next((s for s in reversed(result["swings"]) if s["type"] == "swing_low"), None)
        if last_high and closes[-1] > last_high["price"]:
            result["bos"].append({"direction": "up", "price": float(last_high["price"])})
        if last_low and closes[-1] < last_low["price"]:
            result["bos"].append({"direction": "down", "price": float(last_low["price"])})
        # Regime simple: slope EMA20
        ema = df["close"].ewm(span=20, adjust=False).mean()
        regime = "trending" if ema.diff().tail(5).mean() != 0 and abs(ema.diff().tail(5).mean()) > 1e-9 else "mean_revert"
        result["regime"] = regime
        return result
    except Exception:
        return result


def compute_smart_money(df: pd.DataFrame) -> Dict[str, Any]:
    df = _ensure_df(df)
    result = {"order_blocks": [], "fvg": [], "liquidity_pools": []}
    if df.empty or not set(["open", "high", "low", "close"]).issubset(df.columns):
        return result
    try:
        # FVG naïf: gap entre high[i-2] < low[i] (bullish) ou low[i-2] > high[i] (bearish)
        for i in range(2, len(df)):
            if df["high"].iloc[i - 2] < df["low"].iloc[i]:
                result["fvg"].append({"type": "bullish", "from": float(df["high"].iloc[i - 2]), "to": float(df["low"].iloc[i])})
            if df["low"].iloc[i - 2] > df["high"].iloc[i]:
                result["fvg"].append({"type": "bearish", "from": float(df["low"].iloc[i - 2]), "to": float(df["high"].iloc[i])})
        # Order block naïf: dernière bougie opposée avant un breakout (close out of prev range)
        if len(df) >= 3:
            prev_range = (df["high"].iloc[-3:-1].max(), df["low"].iloc[-3:-1].min())
            last = df.iloc[-1]
            if last["close"] > prev_range[0]:
                # bullish OB: dernière bougie rouge avant la cassure
                for j in range(len(df) - 2, -1, -1):
                    row = df.iloc[j]
                    if row["close"] < row["open"]:
                        result["order_blocks"].append({"type": "bullish", "low": float(row["low"]), "high": float(row["high"])})
                        break
            if last["close"] < prev_range[1]:
                for j in range(len(df) - 2, -1, -1):
                    row = df.iloc[j]
                    if row["close"] > row["open"]:
                        result["order_blocks"].append({"type": "bearish", "low": float(row["low"]), "high": float(row["high"])})
                        break
        # Liquidity naïf: égalités approximatives des sommets/creux récents
        tol = (df["high"] - df["low"]).tail(20).mean() * 0.1 if len(df) >= 20 else (df["close"].iloc[-1] * 0.0005 if len(df) else 0.0)
        for i in range(1, min(50, len(df))):
            if abs(df["high"].iloc[-i] - df["high"].iloc[-i - 1]) <= tol:
                result["liquidity_pools"].append({"type": "equal_highs", "level": float(df["high"].iloc[-i])})
            if abs(df["low"].iloc[-i] - df["low"].iloc[-i - 1]) <= tol:
                result["liquidity_pools"].append({"type": "equal_lows", "level": float(df["low"].iloc[-i])})
        return result
    except Exception:
        return result


def compute_vwap(df: pd.DataFrame) -> Dict[str, Any]:
    df = _ensure_df(df)
    result = {"vwap": [], "bands": []}
    if df.empty or not set(["high", "low", "close"]).issubset(df.columns):
        return result
    try:
        price = (df["high"] + df["low"] + df["close"]) / 3.0
        vol = df.get("tick_volume") or df.get("volume")
        if vol is None:
            vol = pd.Series(1.0, index=df.index)
        pv = (price * vol).cumsum()
        v = vol.cumsum()
        vwap = (pv / v).fillna(method="bfill").fillna(method="ffill")
        std = (price - vwap).rolling(50, min_periods=10).std().fillna(0)
        result["vwap"] = [{"index": str(i), "value": float(val)} for i, val in zip(df.index, vwap)]
        for k in [1, 2]:
            result["bands"].append({
                "k": k,
                "upper": [{"index": str(i), "value": float((vwap + k * std).iloc[ix])} for ix, i in enumerate(df.index)],
                "lower": [{"index": str(i), "value": float((vwap - k * std).iloc[ix])} for ix, i in enumerate(df.index)],
            })
        return result
    except Exception:
        return result


def compute_squeeze(df: pd.DataFrame) -> Dict[str, Any]:
    df = _ensure_df(df)
    result = {"squeeze_on": False, "bb_bw": 0.0, "keltner": {"upper": None, "lower": None}}
    if df.empty or not set(["high", "low", "close"]).issubset(df.columns):
        return result
    try:
        close = df["close"]
        ma20 = close.rolling(20, min_periods=10).mean()
        std = close.rolling(20, min_periods=10).std()
        bb_upper = ma20 + 2 * std
        bb_lower = ma20 - 2 * std
        tr = pd.concat([
            (df["high"] - df["low"]).abs(),
            (df["high"] - close.shift()).abs(),
            (df["low"] - close.shift()).abs(),
        ], axis=1).max(axis=1)
        atr = tr.rolling(20, min_periods=10).mean()
        ema20 = close.ewm(span=20, adjust=False).mean()
        k_upper = ema20 + 1.5 * atr
        k_lower = ema20 - 1.5 * atr
        squeeze_on = (bb_upper < k_upper) & (bb_lower > k_lower)
        bb_bw = ((bb_upper - bb_lower) / ma20).iloc[-1] if ma20.iloc[-1] else 0.0
        result["squeeze_on"] = bool(squeeze_on.iloc[-1])
        result["bb_bw"] = float(bb_bw) if not math.isnan(bb_bw) else 0.0
        result["keltner"] = {"upper": float(k_upper.iloc[-1]), "lower": float(k_lower.iloc[-1])}
        return result
    except Exception:
        return result


def compute_supertrend(df: pd.DataFrame, period: int = 10, multiplier: float = 3.0) -> Dict[str, Any]:
    df = _ensure_df(df)
    result = {"trend": [], "line": []}
    if df.empty or not set(["high", "low", "close"]).issubset(df.columns):
        return result
    try:
        high = df["high"]
        low = df["low"]
        close = df["close"]
        hl2 = (high + low) / 2
        tr = pd.concat([
            (high - low).abs(),
            (high - close.shift()).abs(),
            (low - close.shift()).abs(),
        ], axis=1).max(axis=1)
        atr = tr.rolling(period, min_periods=max(3, period // 2)).mean()
        upperband = hl2 + multiplier * atr
        lowerband = hl2 - multiplier * atr
        trend = [1]
        line = [float(lowerband.iloc[0] if not math.isnan(lowerband.iloc[0]) else close.iloc[0])]
        for i in range(1, len(df)):
            if close.iloc[i] > upperband.iloc[i - 1]:
                t = 1
            elif close.iloc[i] < lowerband.iloc[i - 1]:
                t = -1
            else:
                t = trend[-1]
                if t == 1:
                    upperband.iloc[i] = min(upperband.iloc[i], upperband.iloc[i - 1])
                else:
                    lowerband.iloc[i] = max(lowerband.iloc[i], lowerband.iloc[i - 1])
            trend.append(t)
            line.append(float(lowerband.iloc[i] if t == 1 else upperband.iloc[i]))
        result["trend"] = trend
        result["line"] = line
        return result
    except Exception:
        return result


def compute_pivots(df: pd.DataFrame, mode: str = "classic") -> Dict[str, Any]:
    df = _ensure_df(df)
    result = {"pp": None, "r": [], "s": []}
    if df.empty or not set(["high", "low", "close"]).issubset(df.columns):
        return result
    try:
        # Utiliser la dernière journée (ou dernière fenêtre) pour calculer
        last = df.iloc[-1]
        H = float(df["high"].iloc[-2]) if len(df) >= 2 else float(last["high"])  # fallback
        L = float(df["low"].iloc[-2]) if len(df) >= 2 else float(last["low"])   # fallback
        C = float(df["close"].iloc[-2]) if len(df) >= 2 else float(last["close"]) # fallback
        pp = (H + L + C) / 3.0
        r1 = 2 * pp - L
        s1 = 2 * pp - H
        r2 = pp + (H - L)
        s2 = pp - (H - L)
        result["pp"] = pp
        result["r"] = [r1, r2]
        result["s"] = [s1, s2]
        return result
    except Exception:
        return result


