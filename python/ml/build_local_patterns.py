#!/usr/bin/env python3
"""
Build pattern library from local Boom/Crash CSV historical data.
Detects zigzags, spikes, trendlines → builds pattern library → generates verification charts.

Usage:
    python -m python.ml.build_local_patterns
"""

import os
import json
import math
from pathlib import Path
from datetime import datetime, timezone
from dataclasses import dataclass, asdict
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.patches import FancyArrowPatch
from matplotlib.lines import Line2D

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = Path(r"C:\Users\USER\Downloads\Boom & Crash\Bomm & Crash Deriv")
OUTPUT_DIR = ROOT / "data" / "pattern_charts"
PATTERN_LIB_PATH = ROOT / "data" / "pattern_library.json"

SYMBOLS = ["Boom 1000 Index", "Boom 500 Index", "Crash 1000 Index", "Crash 500 Index"]

SPIKE_THRESHOLD_ATR = 3.0
ZIGZAG_WINDOW = 5
PATTERN_WINDOW = 200
STRIDE = 50
HORIZON = 500
MAX_PATTERNS_PER_SYMBOL = 2000


# ──────────────────────────────────────────────────────────────────────
# Data loading
# ──────────────────────────────────────────────────────────────────────

def load_csv(symbol: str, timeframe: str = "M1", max_rows: int = 200000) -> Optional[pd.DataFrame]:
    """Load a local CSV file (last N rows only for speed)."""
    csv_path = DATA_DIR / symbol / f"{symbol}_{timeframe}.CSV"
    if not csv_path.exists():
        print(f"  [SKIP] {csv_path} not found")
        return None
    
    # Count total lines first to only read last max_rows
    total_lines = 0
    with open(csv_path, "r", encoding="utf-8") as f:
        for _ in f:
            total_lines += 1
    skip_rows = max(0, total_lines - max_rows - 1)
    
    df = pd.read_csv(csv_path, skiprows=range(1, skip_rows + 1) if skip_rows > 0 else None)
    df["time"] = pd.to_datetime(df["date"] + " " + df["hour"], format="%Y.%m.%d %H:%M")
    df = df.drop(columns=["date", "hour"])
    df = df.sort_values("time").reset_index(drop=True)
    print(f"  [OK] {symbol} {timeframe}: {len(df):,} bars ({df['time'].iloc[0]} -> {df['time'].iloc[-1]})")
    return df


# ──────────────────────────────────────────────────────────────────────
# Technical indicators
# ──────────────────────────────────────────────────────────────────────

def calc_rsi(closes: pd.Series, period: int = 14) -> float:
    """Calculate RSI value for the last `period` closes."""
    if len(closes) < period + 1:
        return 50.0
    deltas = closes.diff().dropna()
    gains = deltas.clip(lower=0)
    losses = -deltas.clip(upper=0)
    avg_gain = gains.rolling(period).mean().iloc[-1]
    avg_loss = losses.rolling(period).mean().iloc[-1]
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100.0 - (100.0 / (1.0 + rs))


def calc_atr(df: pd.DataFrame, period: int = 14) -> float:
    """Calculate Average True Range."""
    if len(df) < period + 1:
        return 0.01
    high = df["high"].astype(float)
    low = df["low"].astype(float)
    close = df["close"].astype(float)
    prev_close = close.shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low - prev_close).abs()
    ], axis=1).max(axis=1)
    atr = tr.rolling(period).mean().iloc[-1]
    return float(atr) if atr > 0 else 0.01


# ──────────────────────────────────────────────────────────────────────
# Zigzag detection
# ──────────────────────────────────────────────────────────────────────

@dataclass
class ZigzagPoint:
    index: int
    time: Any
    price: float
    direction: str  # "HIGH" or "LOW"


def detect_zigzag(df: pd.DataFrame, window: int = ZIGZAG_WINDOW, min_move_pct: float = 0.1) -> List[ZigzagPoint]:
    """
    Detect zigzag swing points (local highs and lows).
    Uses a rolling window to identify turning points.
    """
    closes = df["close"].astype(float).values
    highs = df["high"].astype(float).values
    lows = df["low"].astype(float).values
    times = df["time"].values
    n = len(closes)
    
    if n < window * 2 + 1:
        return []
    
    points = []
    last_direction = None
    last_extreme_idx = 0
    last_extreme_price = closes[0]
    
    for i in range(window, n - window):
        local_high = max(highs[i - window:i + window + 1])
        local_low = min(lows[i - window:i + window + 1])
        
        is_high = highs[i] == local_high
        is_low = lows[i] == local_low
        
        if is_high and (last_direction != "HIGH" or closes[i] > last_extreme_price * (1 + min_move_pct / 100)):
            if last_direction == "LOW" and last_extreme_idx > 0:
                move_pct = (closes[i] - last_extreme_price) / last_extreme_price * 100
                if move_pct >= min_move_pct:
                    points.append(ZigzagPoint(
                        index=i, time=times[i], price=closes[i], direction="HIGH"
                    ))
                    last_direction = "HIGH"
                    last_extreme_idx = i
                    last_extreme_price = closes[i]
            elif last_direction is None:
                points.append(ZigzagPoint(
                    index=i, time=times[i], price=closes[i], direction="HIGH"
                ))
                last_direction = "HIGH"
                last_extreme_idx = i
                last_extreme_price = closes[i]
        
        elif is_low and (last_direction != "LOW" or closes[i] < last_extreme_price * (1 - min_move_pct / 100)):
            if last_direction == "HIGH" and last_extreme_idx > 0:
                move_pct = (last_extreme_price - closes[i]) / last_extreme_price * 100
                if move_pct >= min_move_pct:
                    points.append(ZigzagPoint(
                        index=i, time=times[i], price=closes[i], direction="LOW"
                    ))
                    last_direction = "LOW"
                    last_extreme_idx = i
                    last_extreme_price = closes[i]
            elif last_direction is None:
                points.append(ZigzagPoint(
                    index=i, time=times[i], price=closes[i], direction="LOW"
                ))
                last_direction = "LOW"
                last_extreme_idx = i
                last_extreme_price = closes[i]
    
    return points


# ──────────────────────────────────────────────────────────────────────
# Spike detection
# ──────────────────────────────────────────────────────────────────────

@dataclass
class Spike:
    index: int
    time: Any
    direction: str  # "UP" or "DOWN"
    magnitude_atr: float
    bar_open: float
    bar_close: float
    bar_high: float
    bar_low: float


def detect_spikes(df: pd.DataFrame, atr: float, threshold_atr: float = SPIKE_THRESHOLD_ATR) -> List[Spike]:
    """Detect spikes (large single-candle moves) relative to ATR."""
    closes = df["close"].astype(float).values
    opens = df["open"].astype(float).values
    highs = df["high"].astype(float).values
    lows = df["low"].astype(float).values
    times = df["time"].values
    n = len(closes)
    
    spikes = []
    for i in range(1, n):
        body_up = (closes[i] - opens[i]) / atr
        body_dn = (opens[i] - closes[i]) / atr
        range_move = (highs[i] - lows[i]) / atr
        
        if body_up >= threshold_atr:
            spikes.append(Spike(
                index=i, time=times[i], direction="UP",
                magnitude_atr=body_up,
                bar_open=opens[i], bar_close=closes[i],
                bar_high=highs[i], bar_low=lows[i]
            ))
        elif body_dn >= threshold_atr:
            spikes.append(Spike(
                index=i, time=times[i], direction="DOWN",
                magnitude_atr=body_dn,
                bar_open=opens[i], bar_close=closes[i],
                bar_high=highs[i], bar_low=lows[i]
            ))
    
    return spikes


# ──────────────────────────────────────────────────────────────────────
# Trendline detection
# ──────────────────────────────────────────────────────────────────────

def detect_trendlines(zigzag: List[ZigzagPoint], lookback: int = 5) -> List[Dict]:
    """Detect trendlines from zigzag points."""
    trendlines = []
    if len(zigzag) < lookback:
        return trendlines
    
    # Find consecutive lows for uptrend, consecutive highs for downtrend
    for i in range(lookback, len(zigzag)):
        recent = zigzag[i - lookback:i + 1]
        
        lows = [p for p in recent if p.direction == "LOW"]
        highs = [p for p in recent if p.direction == "HIGH"]
        
        if len(lows) >= 3:
            prices = [p.price for p in lows]
            indices = [p.index for p in lows]
            slope = (prices[-1] - prices[0]) / max(indices[-1] - indices[0], 1)
            if slope > 0:
                trendlines.append({
                    "type": "uptrend",
                    "start_idx": lows[0].index,
                    "end_idx": lows[-1].index,
                    "start_price": lows[0].price,
                    "end_price": lows[-1].price,
                    "slope": slope,
                })
        
        if len(highs) >= 3:
            prices = [p.price for p in highs]
            indices = [p.index for p in highs]
            slope = (prices[-1] - prices[0]) / max(indices[-1] - indices[0], 1)
            if slope < 0:
                trendlines.append({
                    "type": "downtrend",
                    "start_idx": highs[0].index,
                    "end_idx": highs[-1].index,
                    "start_price": highs[0].price,
                    "end_price": highs[-1].price,
                    "slope": slope,
                })
    
    return trendlines


# ──────────────────────────────────────────────────────────────────────
# Pattern extraction
# ──────────────────────────────────────────────────────────────────────

def extract_patterns(
    symbol: str,
    df: pd.DataFrame,
    window: int = PATTERN_WINDOW,
    stride: int = STRIDE,
    horizon: int = HORIZON,
    max_patterns: int = MAX_PATTERNS_PER_SYMBOL,
) -> List[Dict]:
    """Extract pattern instances from price data."""
    df = df.sort_values("time").reset_index(drop=True)
    atr_val = calc_atr(df)
    zigzag = detect_zigzag(df)
    spikes = detect_spikes(df, atr_val)
    
    # Pre-compute RSI series for entire dataset (avoids O(n²) recalculation)
    closes_full = df["close"].astype(float)
    rsi_7_full = closes_full.rolling(7).apply(lambda x: calc_rsi(pd.Series(x), 7), raw=False)
    rsi_14_full = closes_full.rolling(14).apply(lambda x: calc_rsi(pd.Series(x), 14), raw=False)
    
    closes = closes_full.values
    highs_arr = df["high"].astype(float).values
    lows_arr = df["low"].astype(float).values
    n = len(closes)
    
    patterns = []
    
    for start in range(0, n - window - min(horizon, 200), stride):
        end = start + window
        if end >= n:
            break
        
        current_price = closes[end - 1]
        rsi_7 = float(rsi_7_full.iloc[end - 1]) if not np.isnan(rsi_7_full.iloc[end - 1]) else 50.0
        rsi_14 = float(rsi_14_full.iloc[end - 1]) if not np.isnan(rsi_14_full.iloc[end - 1]) else 50.0
        
        # Direction from future data
        future_end = min(end + horizon, n)
        if future_end > end + 20:
            future_return = (closes[future_end - 1] - current_price) / current_price
            if future_return > 0.002:
                direction = "BUY"
            elif future_return < -0.002:
                direction = "SELL"
            else:
                direction = "NEUTRAL"
        else:
            direction = "NEUTRAL"
        
        # Spike detection in future window
        spike_occurred = False
        spike_index = None
        spike_mag = 0.0
        
        for j in range(end, min(end + horizon, n)):
            move_up = (highs_arr[j] - current_price) / atr_val
            move_dn = (current_price - lows_arr[j]) / atr_val
            move = max(move_up, move_dn)
            if move > spike_mag:
                spike_mag = move
            if move >= SPIKE_THRESHOLD_ATR and not spike_occurred:
                spike_occurred = True
                spike_index = j - end
        
        # Future returns (normalized)
        fut_end = min(end + horizon, n)
        fut_returns = ((closes[end:fut_end] - current_price) / current_price).tolist()
        fut_closes_norm = fut_returns[:]
        fut_highs_norm = ((highs_arr[end:fut_end] - current_price) / current_price).tolist()
        fut_lows_norm = ((lows_arr[end:fut_end] - current_price) / current_price).tolist()
        
        # Pad
        while len(fut_returns) < horizon:
            fut_returns.append(fut_returns[-1] if fut_returns else 0.0)
        while len(fut_closes_norm) < horizon:
            fut_closes_norm.append(fut_closes_norm[-1] if fut_closes_norm else 0.0)
        while len(fut_highs_norm) < horizon:
            fut_highs_norm.append(fut_highs_norm[-1] if fut_highs_norm else 0.0)
        while len(fut_lows_norm) < horizon:
            fut_lows_norm.append(fut_lows_norm[-1] if fut_lows_norm else 0.0)
        
        # Pattern tags (zigzag pattern in window)
        window_zigzag = [z for z in zigzag if start <= z.index < end]
        tags = []
        if len(window_zigzag) >= 2:
            dirs = [z.direction for z in window_zigzag[-4:]]
            tags.append("_".join(dirs))
        
        pattern_id = f"{symbol.replace(' ', '_')}_{start}_{window}"
        
        pattern = {
            "pattern_id": pattern_id,
            "symbol": symbol,
            "timeframe": "M1",
            "start_time": str(df["time"].iloc[start]),
            "end_time": str(df["time"].iloc[end - 1]),
            "features_hash": pattern_id,
            "window_size": window,
            "direction": direction,
            "spike_occurred": spike_occurred,
            "spike_index": spike_index,
            "spike_magnitude": round(spike_mag, 4),
            "future_returns": [round(r, 8) for r in fut_returns],
            "future_highs": [round(r, 8) for r in fut_highs_norm],
            "future_lows": [round(r, 8) for r in fut_lows_norm],
            "future_closes": [round(r, 8) for r in fut_closes_norm],
            "metadata": {
                "rsi_7": round(rsi_7, 2),
                "rsi_14": round(rsi_14, 2),
                "atr": round(atr_val, 6),
                "zigzag_tags": tags,
                "zigzag_points_in_window": len(window_zigzag),
            },
        }
        patterns.append(pattern)
        
        if len(patterns) >= max_patterns:
            break
    
    return patterns


# ──────────────────────────────────────────────────────────────────────
# Chart generation
# ──────────────────────────────────────────────────────────────────────

def generate_verification_chart(
    symbol: str,
    df: pd.DataFrame,
    zigzag: List[ZigzagPoint],
    spikes: List[Spike],
    trendlines: List[Dict],
    patterns: List[Dict],
    atr: float,
    output_dir: Path,
    n_bars: int = 2000,
) -> Path:
    """Generate a comprehensive verification chart."""
    output_dir.mkdir(parents=True, exist_ok=True)
    safe_name = symbol.replace(" ", "_").replace("/", "_")
    
    # Use last N bars for readability
    df_plot = df.tail(n_bars).copy().reset_index(drop=True)
    start_idx = len(df) - n_bars
    
    fig, axes = plt.subplots(4, 1, figsize=(24, 18), sharex=True,
                              gridspec_kw={"height_ratios": [4, 1.2, 1, 1.5]})
    fig.suptitle(f"Pattern Recognition — {symbol}", fontsize=16, fontweight="bold", y=0.98)
    
    closes = df_plot["close"].astype(float).values
    highs = df_plot["high"].astype(float).values
    lows = df_plot["low"].astype(float).values
    times = df_plot["time"].values
    
    # ── Panel 1: Price + Zigzag + Trendlines ──
    ax1 = axes[0]
    ax1.plot(times, closes, color="#2196F3", linewidth=0.6, alpha=0.8, label="Close")
    ax1.fill_between(times, lows, highs, alpha=0.08, color="#2196F3")
    
    # Zigzag overlay
    zz_in_range = [z for z in zigzag if start_idx <= z.index < len(df)]
    highs_zz = [(z.time, z.price) for z in zz_in_range if z.direction == "HIGH"]
    lows_zz = [(z.time, z.price) for z in zz_in_range if z.direction == "LOW"]
    
    if highs_zz:
        h_times, h_prices = zip(*highs_zz)
        ax1.scatter(h_times, h_prices, color="#F44336", marker="v", s=60, zorder=5, label=f"Swing High ({len(highs_zz)})")
    if lows_zz:
        l_times, l_prices = zip(*lows_zz)
        ax1.scatter(l_times, l_prices, color="#4CAF50", marker="^", s=60, zorder=5, label=f"Swing Low ({len(lows_zz)})")
    
    # Connect zigzag points with lines
    if len(zz_in_range) >= 2:
        for i in range(len(zz_in_range) - 1):
            p1 = zz_in_range[i]
            p2 = zz_in_range[i + 1]
            if p1.direction != p2.direction:
                color = "#FF9800" if p1.direction == "LOW" else "#9C27B0"
                ax1.plot([p1.time, p2.time], [p1.price, p2.price],
                         color=color, linewidth=1.2, alpha=0.7, linestyle="--")
    
    # Trendlines
    for tl in trendlines:
        if tl["start_idx"] >= start_idx and tl["start_idx"] < len(df):
            tl_start_time = df["time"].iloc[tl["start_idx"]]
            tl_end_time = df["time"].iloc[min(tl["end_idx"], len(df) - 1)]
            color = "#4CAF50" if tl["type"] == "uptrend" else "#F44336"
            ax1.plot([tl_start_time, tl_end_time],
                     [tl["start_price"], tl["end_price"]],
                     color=color, linewidth=2, alpha=0.8, linestyle="-.")
    
    # Spike markers
    spikes_in_range = [s for s in spikes if start_idx <= s.index < len(df)]
    for sp in spikes_in_range:
        color = "#4CAF50" if sp.direction == "UP" else "#F44336"
        ax1.axvline(x=sp.time, color=color, alpha=0.3, linewidth=1)
        ax1.annotate(f"Spike\n{sp.magnitude_atr:.1f}x",
                     xy=(sp.time, sp.bar_close), fontsize=6,
                     color=color, ha="center", va="bottom",
                     bbox=dict(boxstyle="round,pad=0.2", facecolor="white", alpha=0.7))
    
    ax1.set_ylabel("Price", fontsize=11)
    ax1.legend(loc="upper left", fontsize=9, ncol=3)
    ax1.grid(True, alpha=0.3)
    ax1.set_title("Price + Zigzag Swing Points + Trendlines + Spikes", fontsize=12, pad=5)
    
    # ── Panel 2: Volume ──
    ax2 = axes[1]
    if "tick_volume" in df_plot.columns:
        vol = df_plot["tick_volume"].astype(float).values
        vol_colors = ["#4CAF50" if closes[i] >= closes[max(0, i-1)] else "#F44336" for i in range(len(closes))]
        ax2.bar(times, vol, color=vol_colors, alpha=0.6, width=0.001)
    ax2.set_ylabel("Volume", fontsize=10)
    ax2.grid(True, alpha=0.3)
    
    # ── Panel 3: RSI ──
    ax3 = axes[2]
    rsi_vals = []
    for i in range(len(closes)):
        rsi_vals.append(calc_rsi(pd.Series(closes[:i+1]), 14))
    ax3.plot(times, rsi_vals, color="#9C27B0", linewidth=0.8)
    ax3.axhline(y=70, color="#F44336", linewidth=0.8, linestyle="--", alpha=0.7)
    ax3.axhline(y=30, color="#4CAF50", linewidth=0.8, linestyle="--", alpha=0.7)
    ax3.fill_between(times, 70, 100, alpha=0.1, color="#F44336")
    ax3.fill_between(times, 0, 30, alpha=0.1, color="#4CAF50")
    ax3.set_ylabel("RSI 14", fontsize=10)
    ax3.set_ylim(0, 100)
    ax3.grid(True, alpha=0.3)
    
    # ── Panel 4: Spike probability per pattern window ──
    ax4 = axes[3]
    pattern_starts = [int(p["pattern_id"].split("_")[-1]) for p in patterns if p["spike_occurred"]]
    pattern_spikes = [p for p in patterns if p["spike_occurred"]]
    
    if pattern_spikes:
        p_times = []
        p_mags = []
        for p in pattern_spikes:
            try:
                idx = int(p["pattern_id"].split("_")[-1])
                if 0 <= idx < len(df):
                    p_times.append(df["time"].iloc[idx])
                    p_mags.append(p["spike_magnitude"])
            except (ValueError, IndexError):
                continue
        
        if p_times:
            colors = ["#F44336" if m > 5 else "#FF9800" if m > 3 else "#FFC107" for m in p_mags]
            ax4.scatter(p_times, p_mags, color=colors, s=15, alpha=0.6)
            ax4.axhline(y=SPIKE_THRESHOLD_ATR, color="#F44336", linewidth=1, linestyle="--",
                         label=f"Threshold ({SPIKE_THRESHOLD_ATR}x ATR)")
    
    ax4.set_ylabel("Spike Mag (ATR)", fontsize=10)
    ax4.set_xlabel("Time", fontsize=11)
    ax4.legend(loc="upper right", fontsize=9)
    ax4.grid(True, alpha=0.3)
    
    plt.tight_layout()
    chart_path = output_dir / f"{safe_name}_patterns.png"
    fig.savefig(chart_path, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  📊 Chart saved: {chart_path}")
    return chart_path


def generate_spike_detail_chart(
    symbol: str,
    df: pd.DataFrame,
    spikes: List[Spike],
    zigzag: List[ZigzagPoint],
    atr: float,
    output_dir: Path,
) -> Path:
    """Generate a zoomed-in chart on the top 10 biggest spikes with pattern context."""
    output_dir.mkdir(parents=True, exist_ok=True)
    safe_name = symbol.replace(" ", "_").replace("/", "_")
    
    # Top 10 spikes by magnitude
    top_spikes = sorted(spikes, key=lambda s: s.magnitude_atr, reverse=True)[:10]
    if not top_spikes:
        return output_dir / f"{safe_name}_spikes_empty.png"
    
    n_rows = min(5, len(top_spikes))
    n_cols = 2
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(20, n_rows * 4))
    fig.suptitle(f"Top Spikes — {symbol}", fontsize=14, fontweight="bold")
    
    if n_rows == 1:
        axes = [axes]
    
    for i, spike in enumerate(top_spikes[:n_rows * n_cols]):
        ax = axes[i // n_cols][i % n_cols] if n_rows > 1 else axes[i % n_cols]
        
        # Context: 100 bars before and 200 after spike
        ctx_before = 100
        ctx_after = 200
        start = max(0, spike.index - ctx_before)
        end = min(len(df), spike.index + ctx_after)
        
        ctx = df.iloc[start:end].copy().reset_index(drop=True)
        spike_local_idx = spike.index - start
        
        c = ctx["close"].astype(float).values
        h = ctx["high"].astype(float).values
        lo = ctx["low"].astype(float).values
        t = ctx["time"].values
        
        ax.plot(t, c, color="#2196F3", linewidth=0.8)
        ax.fill_between(t, lo, h, alpha=0.1, color="#2196F3")
        
        # Mark spike bar
        spike_color = "#4CAF50" if spike.direction == "UP" else "#F44336"
        ax.axvline(x=ctx["time"].iloc[spike_local_idx], color=spike_color,
                    linewidth=2, alpha=0.8, linestyle="--")
        ax.scatter([ctx["time"].iloc[spike_local_idx]], [spike.bar_close],
                    color=spike_color, s=100, zorder=5, marker="D")
        
        # Zigzag points in context
        zz_ctx = [z for z in zigzag if start <= z.index < end]
        for z in zz_ctx:
            local_i = z.index - start
            if 0 <= local_i < len(t):
                marker = "v" if z.direction == "HIGH" else "^"
                color = "#F44336" if z.direction == "HIGH" else "#4CAF50"
                ax.scatter([t[local_i]], [z.price], color=color, marker=marker, s=40, zorder=4)
        
        # ATR bands
        ax.axhline(y=spike.bar_close + atr, color="#FF9800", linewidth=0.6, linestyle=":", alpha=0.5)
        ax.axhline(y=spike.bar_close - atr, color="#FF9800", linewidth=0.6, linestyle=":", alpha=0.5)
        
        ax.set_title(f"Spike {i+1}: {spike.direction} {spike.magnitude_atr:.1f}x ATR | {spike.time}",
                     fontsize=10, fontweight="bold")
        ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    chart_path = output_dir / f"{safe_name}_spike_detail.png"
    fig.savefig(chart_path, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  📊 Spike detail chart: {chart_path}")
    return chart_path


def generate_pattern_forecast_chart(
    symbol: str,
    df: pd.DataFrame,
    patterns: List[Dict],
    atr: float,
    output_dir: Path,
) -> Path:
    """Generate a chart showing pattern matches and their projected paths."""
    output_dir.mkdir(parents=True, exist_ok=True)
    safe_name = symbol.replace(" ", "_").replace("/", "_")
    
    # Find the pattern with highest spike probability
    spike_patterns = [p for p in patterns if p["spike_occurred"]]
    buy_patterns = [p for p in patterns if p["direction"] == "BUY"]
    sell_patterns = [p for p in patterns if p["direction"] == "SELL"]
    
    # Show last 500 bars with pattern annotations
    n_bars = 500
    df_plot = df.tail(n_bars).copy().reset_index(drop=True)
    start_idx = len(df) - n_bars
    
    fig, axes = plt.subplots(2, 1, figsize=(20, 12), gridspec_kw={"height_ratios": [3, 1]})
    fig.suptitle(f"Pattern Forecast Summary — {symbol}", fontsize=14, fontweight="bold")
    
    closes = df_plot["close"].astype(float).values
    times = df_plot["time"].values
    
    # Panel 1: Price with pattern zones
    ax1 = axes[0]
    ax1.plot(times, closes, color="#2196F3", linewidth=0.8, label="Close")
    
    # Mark BUY patterns
    buy_indices = [int(p["pattern_id"].split("_")[-1]) - start_idx for p in buy_patterns
                   if start_idx <= int(p["pattern_id"].split("_")[-1]) < len(df)]
    buy_indices = [i for i in buy_indices if 0 <= i < len(times)]
    if buy_indices:
        ax1.scatter([times[i] for i in buy_indices],
                    [closes[i] for i in buy_indices],
                    color="#4CAF50", marker="^", s=30, alpha=0.5, label=f"BUY patterns ({len(buy_indices)})")
    
    sell_indices = [int(p["pattern_id"].split("_")[-1]) - start_idx for p in sell_patterns
                    if start_idx <= int(p["pattern_id"].split("_")[-1]) < len(df)]
    sell_indices = [i for i in sell_indices if 0 <= i < len(times)]
    if sell_indices:
        ax1.scatter([times[i] for i in sell_indices],
                    [closes[i] for i in sell_indices],
                    color="#F44336", marker="v", s=30, alpha=0.5, label=f"SELL patterns ({len(sell_indices)})")
    
    ax1.set_ylabel("Price")
    ax1.legend(fontsize=10, ncol=3)
    ax1.grid(True, alpha=0.3)
    ax1.set_title("Pattern Signals (BUY=green▲ / SELL=red▼)")
    
    # Panel 2: Spike probability heatmap
    ax2 = axes[1]
    if spike_patterns:
        sp_times = []
        sp_probs = []
        for p in spike_patterns:
            try:
                idx = int(p["pattern_id"].split("_")[-1]) - start_idx
                if 0 <= idx < len(times):
                    sp_times.append(times[idx])
                    sp_probs.append(p["spike_magnitude"])
            except (ValueError, IndexError):
                continue
        if sp_times:
            colors = ["#F44336" if m > 5 else "#FF9800" if m > 3 else "#FFC107" for m in sp_probs]
            ax2.bar(range(len(sp_times)), sp_probs, color=colors, alpha=0.7)
            ax2.set_ylabel("Spike Mag (ATR)")
            ax2.set_xlabel("Pattern Index (sorted by time)")
    
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    chart_path = output_dir / f"{safe_name}_forecast_summary.png"
    fig.savefig(chart_path, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  📊 Forecast summary chart: {chart_path}")
    return chart_path


# ──────────────────────────────────────────────────────────────────────
# Library persistence
# ──────────────────────────────────────────────────────────────────────

def save_library(library: Dict[str, Any], path: Path = PATTERN_LIB_PATH):
    path.parent.mkdir(parents=True, exist_ok=True)
    library["updated_at"] = datetime.now(timezone.utc).isoformat()
    path.write_text(json.dumps(library, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  💾 Library saved: {path}")


def load_library(path: Path = PATTERN_LIB_PATH) -> Dict[str, Any]:
    if not path.is_file():
        return {"symbols": {}, "updated_at": None}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {"symbols": {}, "updated_at": None}


# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 70)
    print("  BUILD PATTERN LIBRARY — Local CSV Historical Data")
    print(f"  Data dir: {DATA_DIR}")
    print(f"  Output:   {PATTERN_LIB_PATH}")
    print(f"  Charts:   {OUTPUT_DIR}")
    print("=" * 70)
    
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    library = load_library()
    
    all_stats = {}
    
    for symbol in SYMBOLS:
        print(f"\n{'─' * 60}")
        print(f"  Processing: {symbol}")
        print(f"{'─' * 60}")
        
        df = load_csv(symbol, "M1")
        if df is None or len(df) < PATTERN_WINDOW + HORIZON:
            print(f"  [SKIP] Insufficient data for {symbol}")
            continue
        
        atr = calc_atr(df)
        zigzag = detect_zigzag(df)
        spikes = detect_spikes(df, atr)
        trendlines = detect_trendlines(zigzag)
        
        print(f"  📈 ATR: {atr:.4f}")
        print(f"  📊 Zigzag points: {len(zigzag)}")
        print(f"  ⚡ Spikes: {len(spikes)} (>{SPIKE_THRESHOLD_ATR}x ATR)")
        print(f"  📐 Trendlines: {len(trendlines)}")
        
        # Extract patterns
        patterns = extract_patterns(symbol, df)
        print(f"  🎯 Patterns extracted: {len(patterns)}")
        
        # Stats
        buy_count = sum(1 for p in patterns if p["direction"] == "BUY")
        sell_count = sum(1 for p in patterns if p["direction"] == "SELL")
        neutral_count = sum(1 for p in patterns if p["direction"] == "NEUTRAL")
        spike_count = sum(1 for p in patterns if p["spike_occurred"])
        print(f"     BUY: {buy_count} | SELL: {sell_count} | NEUTRAL: {neutral_count}")
        print(f"     With spike: {spike_count}")
        
        all_stats[symbol] = {
            "bars": len(df),
            "atr": round(atr, 6),
            "zigzag_points": len(zigzag),
            "spikes": len(spikes),
            "trendlines": len(trendlines),
            "patterns": len(patterns),
            "buy": buy_count,
            "sell": sell_count,
            "neutral": neutral_count,
            "with_spike": spike_count,
        }
        
        # Save to library
        library["symbols"][symbol] = patterns[:MAX_PATTERNS_PER_SYMBOL]
        
        # Generate charts
        print(f"\n  📊 Generating charts...")
        generate_verification_chart(symbol, df, zigzag, spikes, trendlines, patterns, atr, OUTPUT_DIR)
        generate_spike_detail_chart(symbol, df, spikes, zigzag, atr, OUTPUT_DIR)
        generate_pattern_forecast_chart(symbol, df, patterns, atr, OUTPUT_DIR)
    
    # Save library
    print(f"\n{'─' * 60}")
    print(f"  Saving pattern library...")
    save_library(library)
    
    # Summary
    total = sum(s["patterns"] for s in all_stats.values())
    print(f"\n{'=' * 70}")
    print(f"  SUMMARY")
    print(f"{'=' * 70}")
    for sym, stats in all_stats.items():
        print(f"  {sym}: {stats['patterns']:,} patterns | {stats['spikes']} spikes | {stats['zigzag_points']} zigzags")
    print(f"  TOTAL: {total:,} patterns across {len(all_stats)} symbols")
    print(f"\n  Charts directory: {OUTPUT_DIR}")
    print(f"  Pattern library: {PATTERN_LIB_PATH}")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
