"""
Pure Momentum Analyzer — 4+1 pillars + cyclical bounce anticipation.

Pillars of confluence:
  1. EMA Alignment (EMA9 vs EMA21)
  2. RSI Extreme (overbought/oversold per symbol type)
  3. Stochastic Extreme (%K, %D in zone + cross)
  4. HTF M5 candle confirmation (> 50 points body)
  5. Minimal retracement (≤ 50% against direction)

Cyclical bounce anticipation:
  - Detects price proximity to dynamic EMA support/resistance
  - Identifies rejection candles (wick > body) at EMA touch
  - Computes bounce score for limit order placement
"""

from __future__ import annotations

import pandas as pd
import numpy as np
from typing import Any, Dict, Optional, Tuple

# ── Symbol classification ─────────────────────────────────────────────
_BOOM_CRASH = ("BOOM", "CRASH")
_PAINX_GAINX = ("PAINX", "GAINX")
_ALL_PM_SYMBOLS = _BOOM_CRASH + _PAINX_GAINX


def is_pure_momentum_symbol(symbol: str) -> bool:
    """Check if symbol is a synthetic index (Boom/Crash/Painx/Gainx)."""
    s = str(symbol).upper().replace(" ", "")
    return any(tag in s for tag in _ALL_PM_SYMBOLS)


def _symbol_direction(symbol: str) -> str:
    """Determine default direction for symbol type."""
    s = str(symbol).upper().replace(" ", "")
    if any(t in s for t in ("CRASH", "PAINX")):
        return "SELL"
    return "BUY"


# ── Indicator calculations ────────────────────────────────────────────
def calculate_ema(data, window):
    if isinstance(data, pd.DataFrame):
        return data["Close"].ewm(span=window, adjust=False).mean()
    return pd.Series(data).ewm(span=window, adjust=False).mean()


def calculate_rsi(data, window=14):
    if isinstance(data, pd.DataFrame):
        close = data["Close"]
    else:
        close = pd.Series(data)
    delta = close.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))


def calculate_stochastic(data, k_period=14, d_period=3, slowing_period=3):
    if isinstance(data, pd.DataFrame):
        low = data["Low"]
        high = data["High"]
        close = data["Close"]
    else:
        close = pd.Series(data)
        low = close
        high = close
    low_min = low.rolling(window=k_period).min()
    high_max = high.rolling(window=k_period).max()
    k_line = 100 * ((close - low_min) / (high_max - low_min))
    d_line = k_line.rolling(window=d_period).mean()
    return k_line.rolling(window=slowing_period).mean(), d_line


# ── Pure Momentum 4+1 pillars (original) ─────────────────────────────
def identify_pure_momentum(df,
                           ema_fast_period=9,
                           ema_slow_period=21,
                           rsi_period=14,
                           stoch_k_period=5,
                           stoch_d_period=3,
                           stoch_slowing=3,
                           rsi_overbought=70,
                           rsi_oversold=30,
                           stoch_overbought=80,
                           stoch_oversold=20,
                           max_retracement_candles=5):

    if "EMA_Fast" not in df.columns:
        df["EMA_Fast"] = calculate_ema(df, ema_fast_period)
    if "EMA_Slow" not in df.columns:
        df["EMA_Slow"] = calculate_ema(df, ema_slow_period)
    if "RSI" not in df.columns:
        df["RSI"] = calculate_rsi(df, rsi_period)
    if "Stoch_K" not in df.columns or "Stoch_D" not in df.columns:
        df["Stoch_K"], df["Stoch_D"] = calculate_stochastic(df, stoch_k_period, stoch_d_period, stoch_slowing)

    df["Pure_Momentum_Buy_Signal"] = False
    df["Pure_Momentum_Sell_Signal"] = False

    for i in range(len(df)):
        if i < max(ema_slow_period, rsi_period, stoch_k_period, stoch_d_period, stoch_slowing) + max_retracement_candles:
            continue

        ema_condition_buy = (df["Close"].iloc[i] > df["EMA_Fast"].iloc[i]) and \
                            (df["EMA_Fast"].iloc[i] > df["EMA_Slow"].iloc[i])
        rsi_condition_buy = df["RSI"].iloc[i] > rsi_overbought
        stoch_condition_buy = (df["Stoch_K"].iloc[i] > stoch_overbought) and \
                              (df["Stoch_D"].iloc[i] > stoch_overbought) and \
                              (df["Stoch_K"].iloc[i] > df["Stoch_D"].iloc[i])
        retracement_condition_buy = True
        bearish_count = 0
        for j in range(1, max_retracement_candles + 1):
            if df["Close"].iloc[i-j] < df["Open"].iloc[i-j]:
                bearish_count += 1
        if bearish_count > max_retracement_candles / 2:
            retracement_condition_buy = False

        if ema_condition_buy and rsi_condition_buy and stoch_condition_buy and retracement_condition_buy:
            df.loc[df.index[i], "Pure_Momentum_Buy_Signal"] = True

        ema_condition_sell = (df["Close"].iloc[i] < df["EMA_Fast"].iloc[i]) and \
                             (df["EMA_Fast"].iloc[i] < df["EMA_Slow"].iloc[i])
        rsi_condition_sell = df["RSI"].iloc[i] < rsi_oversold
        stoch_condition_sell = (df["Stoch_K"].iloc[i] < stoch_oversold) and \
                               (df["Stoch_D"].iloc[i] < stoch_oversold) and \
                               (df["Stoch_K"].iloc[i] < df["Stoch_D"].iloc[i])
        retracement_condition_sell = True
        bullish_count = 0
        for j in range(1, max_retracement_candles + 1):
            if df["Close"].iloc[i-j] > df["Open"].iloc[i-j]:
                bullish_count += 1
        if bullish_count > max_retracement_candles / 2:
            retracement_condition_sell = False

        if ema_condition_sell and rsi_condition_sell and stoch_condition_sell and retracement_condition_sell:
            df.loc[df.index[i], "Pure_Momentum_Sell_Signal"] = True

    return df


# ── API-compatible analyze function (used by ai_server.py) ───────────
def analyze_pure_momentum(
    symbol: str,
    direction: str = "",
    rsi: Optional[float] = None,
    stoch_k: Optional[float] = None,
    stoch_d: Optional[float] = None,
    ema_fast: Optional[float] = None,
    ema_slow: Optional[float] = None,
    htf_bullish: Optional[bool] = None,
    htf_bearish: Optional[bool] = None,
    htf_body_points: Optional[float] = None,
    max_retrace_pct: float = 50.0,
    # Bounce parameters
    price: Optional[float] = None,
    atr: Optional[float] = None,
    ema50: Optional[float] = None,
    ema100: Optional[float] = None,
    ema200: Optional[float] = None,
    prev_candle: Optional[Dict[str, float]] = None,
    recent_candles: Optional[list] = None,
) -> Dict[str, Any]:
    """
    Evaluate Pure Momentum confluence + cyclical bounce.

    Returns:
        {
            "allowed": bool,       # True if score >= 4
            "score": int,          # 0-5 pillars + bounce bonus
            "max_score": int,      # Always 5
            "pillars": {...},
            "bounce": {
                "detected": bool,
                "bounce_score": float (0-1),
                "ema_level": float,
                "bounce_type": str,
                "limit_order": dict or None,
            }
        }
    """
    s = str(symbol).upper().replace(" ", "")
    if not any(tag in s for tag in _ALL_PM_SYMBOLS):
        return {"allowed": True, "score": 5, "max_score": 5, "pillars": {}, "bounce": {}}

    d = direction.upper() if direction else _symbol_direction(symbol)
    is_buy = d == "BUY"

    # Thresholds per direction
    rsi_ob = 70.0 if is_buy else 30.0
    rsi_os = 30.0 if is_buy else 70.0
    stoch_ob = 80.0 if is_buy else 20.0
    stoch_os = 20.0 if is_buy else 80.0

    pillars = {}
    score = 0

    # Pillar 1: EMA Alignment
    if ema_fast is not None and ema_slow is not None:
        aligned = (ema_fast > ema_slow) if is_buy else (ema_fast < ema_slow)
        pillars["ema_alignment"] = {"pass": aligned, "fast": ema_fast, "slow": ema_slow}
        if aligned:
            score += 1

    # Pillar 2: RSI Extreme
    if rsi is not None:
        if is_buy:
            extreme = rsi >= rsi_ob
        else:
            extreme = rsi <= rsi_os
        pillars["rsi_extreme"] = {"pass": extreme, "value": rsi, "threshold": rsi_ob if is_buy else rsi_os}
        if extreme:
            score += 1

    # Pillar 3: Stochastic Extreme
    if stoch_k is not None and stoch_d is not None:
        if is_buy:
            extreme = (stoch_k >= stoch_ob) and (stoch_k > stoch_d)
        else:
            extreme = (stoch_k <= stoch_os) and (stoch_k < stoch_d)
        pillars["stoch_extreme"] = {"pass": extreme, "k": stoch_k, "d": stoch_d}
        if extreme:
            score += 1

    # Pillar 4: HTF M5 candle confirmation
    if htf_bullish is not None and htf_bearish is not None:
        if is_buy:
            htf_ok = htf_bullish and (htf_body_points is not None and htf_body_points > 50)
        else:
            htf_ok = htf_bearish and (htf_body_points is not None and htf_body_points > 50)
        pillars["htf_m5"] = {"pass": htf_ok, "bullish": htf_bullish, "bearish": htf_bearish, "body_pts": htf_body_points}
        if htf_ok:
            score += 1

    # Pillar 5: Minimal retracement
    if recent_candles is not None and len(recent_candles) >= 5:
        total_move = 0
        max_retrace = 0
        for i in range(1, 6):
            delta = recent_candles[i-1].get("close", 0) - recent_candles[i].get("close", 0)
            total_move += delta
        for i in range(1, 6):
            delta = recent_candles[i-1].get("close", 0) - recent_candles[i].get("close", 0)
            is_retrace = (delta < 0) if is_buy else (delta > 0)
            if is_retrace:
                retrace_amt = abs(delta)
                if retrace_amt > max_retrace:
                    max_retrace = retrace_amt
        max_allowed = abs(total_move) * max_retrace_pct / 100.0
        ret_ok = (max_retrace <= max_allowed) if max_allowed > 0 else True
        pillars["retracement"] = {"pass": ret_ok, "max_retrace": max_retrace, "max_allowed": max_allowed}
        if ret_ok:
            score += 1

    # ── Cyclical Bounce Detection ─────────────────────────────────────
    bounce = _detect_cyclical_bounce(
        symbol=symbol, direction=d, price=price, atr=atr,
        ema_fast=ema_fast, ema_slow=ema_slow,
        ema50=ema50, ema100=ema100, ema200=ema200,
        prev_candle=prev_candle, recent_candles=recent_candles,
    )

    # Bounce bonus: +1 to score if bounce detected (max becomes 6 but cap at 5)
    if bounce.get("detected") and bounce.get("bounce_score", 0) >= 0.6:
        score = min(score + 1, 5)
        pillars["bounce"] = {"pass": True, **bounce}
    else:
        pillars["bounce"] = {"pass": False, **bounce}

    allowed = score >= 4

    return {
        "allowed": allowed,
        "score": score,
        "max_score": 5,
        "pillars": pillars,
        "bounce": bounce,
    }


# ── Cyclical Bounce Detection ─────────────────────────────────────────
def _detect_cyclical_bounce(
    symbol: str,
    direction: str,
    price: Optional[float],
    atr: Optional[float],
    ema_fast: Optional[float],
    ema_slow: Optional[float],
    ema50: Optional[float],
    ema100: Optional[float],
    ema200: Optional[float],
    prev_candle: Optional[Dict[str, float]],
    recent_candles: Optional[list],
) -> Dict[str, Any]:
    """
    Detect cyclical bounce off EMA support/resistance.

    Logic:
    1. Price is within ATR*0.3 of a key EMA (9, 21, 50, 100, 200)
    2. Previous candle shows rejection (wick > 2*body) at that EMA
    3. EMA is acting as dynamic support (uptrend) or resistance (downtrend)
    4. Recent price action confirms bounce (higher low / lower high)

    Returns bounce score 0-1 and limit order suggestion.
    """
    result = {
        "detected": False,
        "bounce_score": 0.0,
        "ema_level": 0.0,
        "ema_period": 0,
        "bounce_type": "none",
        "rejection_candle": False,
        "proximity_pct": 0.0,
        "limit_order": None,
    }

    if price is None or atr is None or atr <= 0:
        return result

    is_buy = direction == "BUY"
    tolerance = atr * 0.3  # 30% of ATR = proximity zone

    # Check proximity to each key EMA
    emas = {}
    if ema_fast is not None and ema_fast > 0:
        emas[9] = ema_fast
    if ema_slow is not None and ema_slow > 0:
        emas[21] = ema_slow
    if ema50 is not None and ema50 > 0:
        emas[50] = ema50
    if ema100 is not None and ema100 > 0:
        emas[100] = ema100
    if ema200 is not None and ema200 > 0:
        emas[200] = ema200

    best_bounce_score = 0.0
    best_ema_level = 0.0
    best_ema_period = 0

    for period, ema_val in emas.items():
        dist = abs(price - ema_val)
        if dist > tolerance:
            continue

        proximity_pct = 1.0 - (dist / tolerance)  # 1 = on the EMA, 0 = at edge

        # Check if EMA acts as support/resistance in trend
        ema_trend_ok = False
        if is_buy and ema_val > price:
            # BUY: price pulled back TO the EMA from above → EMA is support
            ema_trend_ok = True
        elif not is_buy and ema_val < price:
            # SELL: price pulled back TO the EMA from below → EMA is resistance
            ema_trend_ok = True

        if not ema_trend_ok:
            continue

        # Check rejection candle
        rejection = False
        if prev_candle is not None:
            o = prev_candle.get("open", 0)
            h = prev_candle.get("high", 0)
            lo = prev_candle.get("low", 0)
            c = prev_candle.get("close", 0)
            body = abs(c - o)
            if body > 0:
                if is_buy:
                    # Bullish rejection: long lower wick at support
                    lower_wick = min(o, c) - lo
                    rejection = lower_wick > 2.0 * body
                else:
                    # Bearish rejection: long upper wick at resistance
                    upper_wick = h - max(o, c)
                    rejection = upper_wick > 2.0 * body

        # Check recent price action (higher low for buy, lower high for sell)
        price_action_ok = True
        if recent_candles is not None and len(recent_candles) >= 3:
            closes = [rc.get("close", 0) for rc in recent_candles[:3]]
            if is_buy:
                # Higher low = bullish bounce confirmation
                price_action_ok = closes[0] >= closes[1] or closes[1] >= closes[2]
            else:
                # Lower high = bearish bounce confirmation
                price_action_ok = closes[0] <= closes[1] or closes[1] <= closes[2]

        # Compute bounce score
        bounce_score = proximity_pct * 0.4
        if ema_trend_ok:
            bounce_score += 0.3
        if rejection:
            bounce_score += 0.3

        if bounce_score > best_bounce_score:
            best_bounce_score = bounce_score
            best_ema_level = ema_val
            best_ema_period = period

    if best_bounce_score >= 0.5:
        # Determine limit order placement
        limit_order = None
        if best_bounce_score >= 0.7:
            # Strong bounce → place limit order AT the EMA level
            if is_buy:
                limit_order = {
                    "type": "BUY_LIMIT",
                    "price": best_ema_level,
                    "sl_offset": atr * 1.5,
                    "tp_offset": atr * 3.0,
                    "reason": f"BUY LIMIT at EMA{best_ema_period} bounce ({best_bounce_score:.0%})",
                }
            else:
                limit_order = {
                    "type": "SELL_LIMIT",
                    "price": best_ema_level,
                    "sl_offset": atr * 1.5,
                    "tp_offset": atr * 3.0,
                    "reason": f"SELL LIMIT at EMA{best_ema_period} bounce ({best_bounce_score:.0%})",
                }
        elif best_bounce_score >= 0.5:
            # Moderate bounce → market order with EMA as reference
            if is_buy:
                limit_order = {
                    "type": "BUY_MARKET",
                    "reference_ema": best_ema_level,
                    "sl_offset": atr * 1.5,
                    "tp_offset": atr * 2.5,
                    "reason": f"BUY MARKET at EMA{best_ema_period} proximity ({best_bounce_score:.0%})",
                }
            else:
                limit_order = {
                    "type": "SELL_MARKET",
                    "reference_ema": best_ema_level,
                    "sl_offset": atr * 1.5,
                    "tp_offset": atr * 2.5,
                    "reason": f"SELL MARKET at EMA{best_ema_period} proximity ({best_bounce_score:.0%})",
                }

        result.update({
            "detected": True,
            "bounce_score": best_bounce_score,
            "ema_level": best_ema_level,
            "ema_period": best_ema_period,
            "bounce_type": "ema_bounce",
            "rejection_candle": rejection if best_ema_period > 0 else False,
            "proximity_pct": proximity_pct if best_ema_period > 0 else 0.0,
            "limit_order": limit_order,
        })

    return result


if __name__ == "__main__":
    data = {
        "Open": np.random.rand(100) * 100 + 1000,
        "High": np.random.rand(100) * 100 + 1050,
        "Low": np.random.rand(100) * 100 + 950,
        "Close": np.random.rand(100) * 100 + 1000,
        "Volume": np.random.randint(100, 1000, 100)
    }
    df = pd.DataFrame(data)
    df.loc[50:70, "Close"] = np.linspace(1050, 1200, 21)
    df.loc[50:70, "Open"] = np.linspace(1040, 1190, 21)
    df.loc[50:70, "High"] = np.linspace(1060, 1210, 21)
    df.loc[50:70, "Low"] = np.linspace(1030, 1180, 21)
    df.loc[75:95, "Close"] = np.linspace(1150, 1000, 21)
    df.loc[75:95, "Open"] = np.linspace(1160, 1010, 21)
    df.loc[75:95, "High"] = np.linspace(1170, 1020, 21)
    df.loc[75:95, "Low"] = np.linspace(1140, 990, 21)

    df_signals = identify_pure_momentum(df.copy())
    print("\nBuy Signals:", df_signals["Pure_Momentum_Buy_Signal"].sum())
    print("Sell Signals:", df_signals["Pure_Momentum_Sell_Signal"].sum())

    # Test analyze_pure_momentum API
    result = analyze_pure_momentum(
        symbol="Boom 1000",
        direction="BUY",
        rsi=72.5,
        stoch_k=85.0, stoch_d=78.0,
        ema_fast=1025.0, ema_slow=1018.0,
        htf_bullish=True, htf_body_points=65.0,
        price=1020.0, atr=8.0,
        ema50=1019.0, ema100=1015.0,
    )
    print(f"\nScore: {result['score']}/{result['max_score']}, Allowed: {result['allowed']}")
    print(f"Bounce: {result['bounce']}")
