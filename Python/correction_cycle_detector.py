#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correction Cycle Detector — détecte l'épuisement d'une correction et
le moment optimal de re-entrée dans la tendance.

Méthode Constance Brown adaptée :
- En uptrend, RSI oscille entre 40-80. Correction = dip vers 40-50, reprise = rebond.
- En downtrend, RSI oscille entre 20-60. Correction = pump vers 50-60, reprise = rejet.

Retourne un score correction_exhaustion_pct (0-100) :
  0-30  = correction en cours, NE PAS ENTRER
  30-60 = correction potentiellement terminée, risqué
  60-80 = bonne probabilité de reprise
  80-100 = re-entrée safe, momentum reprend

Intégration :
  - Appelé par ai_server.py dans _enrich_ia_status ou comme gate indépendant
  - L'EA lit le champ "correction_exhaustion_pct" depuis /gom-kola-dashboard
"""

import numpy as np
import pandas as pd
from typing import Dict, Any, Optional, Tuple


def rsi_series(close: pd.Series, period: int = 14) -> pd.Series:
    """RSI de Wilder sur toute la série (retourne pd.Series)."""
    delta = close.diff()
    gain = delta.clip(lower=0)
    loss = (-delta).clip(lower=0)
    avg_gain = gain.ewm(alpha=1.0 / period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1.0 / period, min_periods=period, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100.0 - (100.0 / (1.0 + rs))


def rsi_slope(rsi: pd.Series, lookback: int = 3) -> float:
    """Pente du RSI sur les N dernières bougies (positif = momentum croissant)."""
    if len(rsi) < lookback + 1:
        return 0.0
    recent = rsi.iloc[-lookback:]
    if recent.isna().any():
        return 0.0
    return float(recent.iloc[-1] - recent.iloc[0]) / lookback


def detect_rsi_divergence(close: pd.Series, rsi: pd.Series, direction: int, lookback: int = 20) -> float:
    """
    Détecte une divergence prix vs RSI (force cachée pour la reprise).
    direction: 1=uptrend (cherche bullish div), -1=downtrend (cherche bearish div)
    Retourne un score 0-1 (1 = forte divergence bullish/bearish).
    """
    if len(close) < lookback + 5 or len(rsi) < lookback + 5:
        return 0.0

    recent_close = close.iloc[-lookback:]
    recent_rsi = rsi.iloc[-lookback:]

    if direction == 1:
        # Bullish divergence : prix fait lower low, RSI fait higher low
        price_lows = recent_close.rolling(5).min()
        rsi_lows = recent_rsi.rolling(5).min()
        if price_lows.isna().all() or rsi_lows.isna().all():
            return 0.0
        # Comparer les deux derniers creux
        price_low_idx = price_lows.dropna()
        rsi_low_idx = rsi_lows.dropna()
        if len(price_low_idx) < 10 or len(rsi_low_idx) < 10:
            return 0.0
        p1 = float(price_low_idx.iloc[-8])
        p2 = float(price_low_idx.iloc[-1])
        r1 = float(rsi_low_idx.iloc[-8])
        r2 = float(rsi_low_idx.iloc[-1])
        if p2 < p1 and r2 > r1:
            # Prix lower low + RSI higher low = bullish divergence
            strength = min(1.0, (r2 - r1) / 10.0)
            return strength
    else:
        # Bearish divergence : prix fait higher high, RSI fait lower high
        price_highs = recent_close.rolling(5).max()
        rsi_highs = recent_rsi.rolling(5).max()
        if price_highs.isna().all() or rsi_highs.isna().all():
            return 0.0
        price_high_idx = price_highs.dropna()
        rsi_high_idx = rsi_highs.dropna()
        if len(price_high_idx) < 10 or len(rsi_high_idx) < 10:
            return 0.0
        p1 = float(price_high_idx.iloc[-8])
        p2 = float(price_high_idx.iloc[-1])
        r1 = float(rsi_high_idx.iloc[-8])
        r2 = float(rsi_high_idx.iloc[-1])
        if p2 > p1 and r2 < r1:
            strength = min(1.0, (r1 - r2) / 10.0)
            return strength

    return 0.0


def compute_volume_ratio(df: pd.DataFrame, lookback_correction: int = 5, lookback_trend: int = 20) -> float:
    """
    Ratio volume récent vs volume moyen.
    Correction = volume faible (<0.8), reprise = volume croissant (>1.0).
    Retourne un score 0-1 (1 = volume reprend fortement).
    """
    if "volume" not in df.columns or len(df) < lookback_trend + 5:
        return 0.5  # neutre si pas de volume

    vol = df["volume"].astype(float)
    avg_trend = vol.iloc[-lookback_trend:-lookback_correction].mean()
    avg_recent = vol.iloc[-lookback_correction:].mean()

    if avg_trend <= 0:
        return 0.5

    ratio = avg_recent / avg_trend
    # Normalize : <0.6 = 0 (volume trop faible), >1.2 = 1 (reprise forte)
    return float(np.clip((ratio - 0.6) / 0.6, 0.0, 1.0))


def detect_trend_regime(rsi_h4: float, rsi_h1: float, rsi_d1: float = 50.0) -> int:
    """
    Détermine le régime de tendance depuis les RSI des TF supérieurs.
    +1 = uptrend, -1 = downtrend, 0 = ranging/indécis.
    """
    bull_count = sum([
        1 if rsi_h4 > 50 else 0,
        1 if rsi_h1 > 50 else 0,
        1 if rsi_d1 > 55 else 0,
    ])
    bear_count = sum([
        1 if rsi_h4 < 50 else 0,
        1 if rsi_h1 < 50 else 0,
        1 if rsi_d1 < 45 else 0,
    ])

    if bull_count >= 2:
        return 1
    if bear_count >= 2:
        return -1
    return 0


def compute_correction_exhaustion(
    df_m5: Optional[pd.DataFrame],
    df_m15: Optional[pd.DataFrame],
    rsi_h4: float = 50.0,
    rsi_h1: float = 50.0,
    rsi_d1: float = 50.0,
    direction_hint: int = 0,
) -> Dict[str, Any]:
    """
    Calcule le score d'épuisement de correction.

    Params:
        df_m5: DataFrame M5 (close, volume) — 50+ bougies
        df_m15: DataFrame M15 (close, volume) — 50+ bougies
        rsi_h4: RSI H4 courant
        rsi_h1: RSI H1 courant
        rsi_d1: RSI D1 courant
        direction_hint: +1 BUY bias, -1 SELL bias, 0 auto-detect

    Returns:
        {
            "correction_exhaustion_pct": float 0-100,
            "trend_regime": int (+1/-1/0),
            "phase": str ("trending"|"correcting"|"exhausted"|"resuming"),
            "rsi_m5_slope": float,
            "rsi_m15_current": float,
            "divergence_score": float 0-1,
            "volume_score": float 0-1,
            "entry_safe": bool
        }
    """
    result = {
        "correction_exhaustion_pct": 0.0,
        "trend_regime": 0,
        "phase": "unknown",
        "rsi_m5_slope": 0.0,
        "rsi_m15_current": 50.0,
        "divergence_score": 0.0,
        "volume_score": 0.5,
        "entry_safe": False,
    }

    # Déterminer le régime de tendance
    regime = direction_hint if direction_hint != 0 else detect_trend_regime(rsi_h4, rsi_h1, rsi_d1)
    result["trend_regime"] = regime

    if regime == 0:
        result["phase"] = "ranging"
        result["correction_exhaustion_pct"] = 30.0
        return result

    # Calculer RSI M15 series
    if df_m15 is not None and len(df_m15) >= 30 and "close" in df_m15.columns:
        close_m15 = df_m15["close"].astype(float)
        rsi_m15 = rsi_series(close_m15, 14)
        rsi_m15_current = float(rsi_m15.iloc[-1]) if not rsi_m15.iloc[-1] != rsi_m15.iloc[-1] else 50.0
        rsi_m15_slope = rsi_slope(rsi_m15, 3)
        result["rsi_m15_current"] = round(rsi_m15_current, 1)
    else:
        rsi_m15_current = 50.0
        rsi_m15_slope = 0.0
        rsi_m15 = pd.Series(dtype=float)
        close_m15 = pd.Series(dtype=float)

    # Calculer RSI M5 series
    if df_m5 is not None and len(df_m5) >= 30 and "close" in df_m5.columns:
        close_m5 = df_m5["close"].astype(float)
        rsi_m5 = rsi_series(close_m5, 14)
        rsi_m5_current = float(rsi_m5.iloc[-1]) if not rsi_m5.iloc[-1] != rsi_m5.iloc[-1] else 50.0
        rsi_m5_slope_val = rsi_slope(rsi_m5, 3)
        result["rsi_m5_slope"] = round(rsi_m5_slope_val, 2)
    else:
        rsi_m5_current = 50.0
        rsi_m5_slope_val = 0.0
        rsi_m5 = pd.Series(dtype=float)
        close_m5 = pd.Series(dtype=float)

    # ── SCORING ──────────────────────────────────────────────────────────────

    score = 0.0

    # === Composante 1 : Position RSI dans la zone de correction (0-30 pts) ===
    # Méthode Constance Brown : en uptrend RSI 40-50 = zone de rebond
    if regime == 1:  # Uptrend
        if rsi_m15_current < 35:
            # Trop bas — tendance potentiellement cassée
            rsi_zone_score = 5.0
        elif 40 <= rsi_m15_current <= 52:
            # Zone de rebond idéale en uptrend
            rsi_zone_score = 30.0
        elif 52 < rsi_m15_current <= 60:
            # Correction pas encore assez profonde ou déjà en reprise
            rsi_zone_score = 20.0
        elif rsi_m15_current > 70:
            # Déjà en tendance forte — pas une correction
            rsi_zone_score = 25.0
        else:
            rsi_zone_score = 10.0
    else:  # Downtrend
        if rsi_m15_current > 65:
            rsi_zone_score = 5.0
        elif 48 <= rsi_m15_current <= 60:
            rsi_zone_score = 30.0
        elif 40 <= rsi_m15_current < 48:
            rsi_zone_score = 20.0
        elif rsi_m15_current < 30:
            rsi_zone_score = 25.0
        else:
            rsi_zone_score = 10.0

    score += rsi_zone_score

    # === Composante 2 : Pente RSI M5 (0-25 pts) ===
    # Positif en uptrend = momentum reprend, négatif en downtrend = momentum reprend
    expected_slope = rsi_m5_slope_val * regime  # devrait être positif si reprise
    if expected_slope > 2.0:
        slope_score = 25.0
    elif expected_slope > 1.0:
        slope_score = 18.0
    elif expected_slope > 0.3:
        slope_score = 12.0
    elif expected_slope > 0:
        slope_score = 6.0
    else:
        slope_score = 0.0  # Pente contraire = correction pas finie

    score += slope_score

    # === Composante 3 : Divergence (0-20 pts) ===
    div_score = 0.0
    if len(close_m15) >= 25 and len(rsi_m15) >= 25:
        div_score = detect_rsi_divergence(close_m15, rsi_m15, regime, lookback=20) * 20.0
    result["divergence_score"] = round(div_score / 20.0, 2)
    score += div_score

    # === Composante 4 : Volume (0-15 pts) ===
    vol_score_raw = 0.5
    if df_m5 is not None and len(df_m5) >= 25:
        vol_score_raw = compute_volume_ratio(df_m5, lookback_correction=5, lookback_trend=20)
    result["volume_score"] = round(vol_score_raw, 2)
    score += vol_score_raw * 15.0

    # === Composante 5 : Confirmation TF supérieurs (0-10 pts) ===
    # H4 et H1 toujours dans la tendance = structure intacte
    if regime == 1:
        htf_confirms = (rsi_h4 > 48 and rsi_h1 > 45)
    else:
        htf_confirms = (rsi_h4 < 52 and rsi_h1 < 55)

    if htf_confirms:
        score += 10.0

    # ── Clamp et arrondi ─────────────────────────────────────────────────────
    score = float(np.clip(score, 0.0, 100.0))
    result["correction_exhaustion_pct"] = round(score, 1)

    # ── Déterminer la phase ──────────────────────────────────────────────────
    if score >= 70:
        result["phase"] = "resuming"
        result["entry_safe"] = True
    elif score >= 45:
        result["phase"] = "exhausted"
        result["entry_safe"] = False
    elif slope_score <= 6 and rsi_zone_score >= 20:
        result["phase"] = "correcting"
        result["entry_safe"] = False
    else:
        result["phase"] = "trending"
        result["entry_safe"] = score >= 65

    return result
