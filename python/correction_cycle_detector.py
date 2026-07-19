#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correction Cycle Detector — version SCALP (M1/M5 exécution).

Architecture multi-TF :
  • Contexte  (D1, H4, H1)  — biais tendance, ne bloque pas un scalp si M1/M5 reprennent
  • Structure (M15, M30)      — profondeur du pullback intermédiaire
  • Exécution (M1, M5)        — 45 % du score : là où le robot entre réellement

Types concrets (correction_type) :
  trend_run        — pas de correction, alignement M1→H4
  micro_pullback   — petit retracement M1/M5 dans tendance HTF (cas scalp typique)
  m5_pullback      — correction visible M5, M1 pas encore relancé
  m15_pullback     — pullback M15, scalp contre-tendance local risqué
  counter_move     — M1/M5/M15 contre le biais HTF → éviter
  range            — HTF indécis

L'EA consomme correction_exhaustion_pct + correction_phase (compatibilité gates MT5).
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from typing import Any, Dict, Optional, Tuple

# Poids du score confiance (total = 100)
_W_EXEC = 45.0   # M1 + M5
_W_STRUCT = 20.0  # M15 (+ M30)
_W_CTX = 20.0    # H1 + H4 + D1
_W_RECOVERY = 15.0  # divergence M5, volume M1, flip momentum M1

# Seuils blocage EA (alignés inputs SMC_Universal)
_PHASE_THRESHOLDS = {
    "trending": 35.0,
    "correcting": 45.0,
    "exhausted": 40.0,
    "resuming": 30.0,
    "ranging": 38.0,
}


def rsi_series(close: pd.Series, period: int = 14) -> pd.Series:
    delta = close.diff()
    gain = delta.clip(lower=0)
    loss = (-delta).clip(lower=0)
    avg_gain = gain.ewm(alpha=1.0 / period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1.0 / period, min_periods=period, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100.0 - (100.0 / (1.0 + rs))


def rsi_slope(rsi: pd.Series, lookback: int = 3) -> float:
    if len(rsi) < lookback + 1:
        return 0.0
    recent = rsi.iloc[-lookback:]
    if recent.isna().any():
        return 0.0
    return float(recent.iloc[-1] - recent.iloc[0]) / lookback


def _safe_rsi(val: float, fallback: float = 50.0) -> float:
    try:
        v = float(val)
        if np.isnan(v) or v <= 0:
            return fallback
        return v
    except (TypeError, ValueError):
        return fallback


def _rsi_from_df(df: Optional[pd.DataFrame]) -> Tuple[float, float, pd.Series, pd.Series]:
    """Retourne (rsi_current, rsi_slope, rsi_series, close_series)."""
    empty = pd.Series(dtype=float)
    if df is None or len(df) < 20 or "close" not in df.columns:
        return 50.0, 0.0, empty, empty
    close = df["close"].astype(float)
    rsi = rsi_series(close, 14)
    cur = float(rsi.iloc[-1]) if not np.isnan(rsi.iloc[-1]) else 50.0
    return cur, rsi_slope(rsi, 3), rsi, close


def detect_rsi_divergence(
    close: pd.Series, rsi: pd.Series, direction: int, lookback: int = 15
) -> float:
    if len(close) < lookback + 5 or len(rsi) < lookback + 5:
        return 0.0
    if direction == 1:
        price_lows = close.iloc[-lookback:].rolling(4).min()
        rsi_lows = rsi.iloc[-lookback:].rolling(4).min()
        pl, rl = price_lows.dropna(), rsi_lows.dropna()
        if len(pl) < 8 or len(rl) < 8:
            return 0.0
        p1, p2 = float(pl.iloc[-6]), float(pl.iloc[-1])
        r1, r2 = float(rl.iloc[-6]), float(rl.iloc[-1])
        if p2 < p1 and r2 > r1:
            return min(1.0, (r2 - r1) / 8.0)
    else:
        price_highs = close.iloc[-lookback:].rolling(4).max()
        rsi_highs = rsi.iloc[-lookback:].rolling(4).max()
        ph, rh = price_highs.dropna(), rsi_highs.dropna()
        if len(ph) < 8 or len(rh) < 8:
            return 0.0
        p1, p2 = float(ph.iloc[-6]), float(ph.iloc[-1])
        r1, r2 = float(rh.iloc[-6]), float(rh.iloc[-1])
        if p2 > p1 and r2 < r1:
            return min(1.0, (r1 - r2) / 8.0)
    return 0.0


def compute_volume_ratio(
    df: pd.DataFrame, lookback_recent: int = 5, lookback_base: int = 20
) -> float:
    if "volume" not in df.columns or len(df) < lookback_base + 5:
        return 0.5
    vol = df["volume"].astype(float)
    base = vol.iloc[-lookback_base:-lookback_recent].mean()
    recent = vol.iloc[-lookback_recent:].mean()
    if base <= 0:
        return 0.5
    ratio = recent / base
    return float(np.clip((ratio - 0.55) / 0.65, 0.0, 1.0))


def detect_trend_regime(
    rsi_h4: float, rsi_h1: float, rsi_d1: float = 50.0, rsi_m15: float = 50.0
) -> int:
    """Biais HTF + M15. +1 uptrend, -1 downtrend, 0 range."""
    bull = sum([
        1 if rsi_d1 > 52 else 0,
        1 if rsi_h4 > 50 else 0,
        1 if rsi_h1 > 48 else 0,
        1 if rsi_m15 > 50 else 0,
    ])
    bear = sum([
        1 if rsi_d1 < 48 else 0,
        1 if rsi_h4 < 50 else 0,
        1 if rsi_h1 < 52 else 0,
        1 if rsi_m15 < 50 else 0,
    ])
    if bull >= 3:
        return 1
    if bear >= 3:
        return -1
    if bull >= 2 and bear == 0:
        return 1
    if bear >= 2 and bull == 0:
        return -1
    return 0


def _tf_dir_from_rsi(rsi: float, regime: int) -> int:
    """+1 avec la tendance, -1 contre, 0 neutre."""
    if regime == 1:
        if rsi >= 55:
            return 1
        if rsi <= 42:
            return -1
    elif regime == -1:
        if rsi <= 45:
            return 1
        if rsi >= 58:
            return -1
    return 0


def _execution_pullback_depth(regime: int, rsi_m1: float, rsi_m5: float) -> float:
    """0 = aligné tendance, 1 = pullback profond sur TF exécution."""
    if regime == 1:
        m1 = max(0.0, (48.0 - rsi_m1) / 18.0)
        m5 = max(0.0, (50.0 - rsi_m5) / 20.0)
    elif regime == -1:
        m1 = max(0.0, (rsi_m1 - 52.0) / 18.0)
        m5 = max(0.0, (rsi_m5 - 50.0) / 20.0)
    else:
        return 0.3
    return float(np.clip(max(m1, m5 * 0.7), 0.0, 1.0))


def _classify_correction_type(
    regime: int,
    rsi_m1: float,
    rsi_m5: float,
    rsi_m15: float,
    slope_m1: float,
    slope_m5: float,
    exec_depth: float,
    ctx_dirs: Dict[str, int],
    exec_dirs: Dict[str, int],
) -> str:
    if regime == 0:
        return "range"

    exec_against = sum(1 for k in ("M1", "M5") if exec_dirs.get(k, 0) == -1)
    struct_against = exec_dirs.get("M15", 0) == -1
    ctx_against = sum(1 for k in ("H1", "H4", "D1") if ctx_dirs.get(k, 0) == -1)

    # Contre-tendance nette sur exécution + structure
    if exec_against >= 2 and struct_against and ctx_against >= 1:
        return "counter_move"
    if exec_against >= 2 and ctx_against >= 2:
        return "counter_move"

    # Pas de pullback significatif
    if exec_depth < 0.15 and exec_against == 0:
        return "trend_run"

    # Pullback M15 dominant
    if struct_against and exec_depth > 0.45:
        return "m15_pullback"

    # Pullback M5, M1 pas relancé
    if exec_depth > 0.25 and slope_m1 * regime <= 0 and slope_m5 * regime <= 0.2:
        return "m5_pullback"

    # Micro pullback scalp (cas le plus fréquent)
    if exec_depth >= 0.08:
        return "micro_pullback"

    return "trend_run"


def _score_execution_layer(
    regime: int,
    rsi_m1: float,
    rsi_m5: float,
    slope_m1: float,
    slope_m5: float,
    exec_depth: float,
    corr_type: str,
) -> float:
    """0–45 pts : momentum M1/M5 pour entrer."""
    if corr_type == "counter_move":
        return 8.0
    if corr_type == "range":
        return 22.0

    mom_m1 = slope_m1 * regime
    mom_m5 = slope_m5 * regime

    score = 18.0  # base neutre

    # Momentum M1 (priorité scalp)
    if mom_m1 > 1.5:
        score += 14.0
    elif mom_m1 > 0.5:
        score += 10.0
    elif mom_m1 > 0:
        score += 5.0
    elif mom_m1 < -1.0:
        score -= 8.0

    # Momentum M5 confirmation
    if mom_m5 > 1.0:
        score += 8.0
    elif mom_m5 > 0.2:
        score += 4.0
    elif mom_m5 < -0.8:
        score -= 5.0

    # Zone RSI exécution : micro pullback en fin de cycle = bon pour scalp
    if regime == 1:
        if 38 <= rsi_m1 <= 50 and mom_m1 > 0:
            score += 8.0
        elif rsi_m1 > 58 and mom_m1 > 0:
            score += 6.0  # continuation
        elif rsi_m1 < 32:
            score -= 6.0
    else:
        if 50 <= rsi_m1 <= 62 and mom_m1 < 0:
            score += 8.0
        elif rsi_m1 < 42 and mom_m1 < 0:
            score += 6.0
        elif rsi_m1 > 68:
            score -= 6.0

    # Pénalité légère si pullback profond non résolu
    if exec_depth > 0.5 and mom_m1 <= 0:
        score -= 10.0

    return float(np.clip(score, 0.0, _W_EXEC))


def _score_structure_layer(
    regime: int, rsi_m15: float, rsi_m30: float, corr_type: str
) -> float:
    if corr_type in ("counter_move", "range"):
        return 8.0 if corr_type == "range" else 4.0

    score = 12.0
    if regime == 1:
        if rsi_m15 >= 52:
            score += 6.0
        elif 42 <= rsi_m15 < 50:
            score += 4.0  # fin pullback M15
        elif rsi_m15 < 38:
            score -= 4.0
    else:
        if rsi_m15 <= 48:
            score += 6.0
        elif 50 < rsi_m15 <= 58:
            score += 4.0
        elif rsi_m15 > 62:
            score -= 4.0

    if regime == 1 and rsi_m30 > 48:
        score += 2.0
    elif regime == -1 and rsi_m30 < 52:
        score += 2.0

    return float(np.clip(score, 0.0, _W_STRUCT))


def _score_context_layer(
    regime: int,
    rsi_h1: float,
    rsi_h4: float,
    rsi_d1: float,
    ctx_dirs: Dict[str, int],
) -> float:
    if regime == 0:
        return 10.0

    aligned = sum(1 for k in ("H1", "H4", "D1") if ctx_dirs.get(k, 0) == 1)
    opposed = sum(1 for k in ("H1", "H4", "D1") if ctx_dirs.get(k, 0) == -1)

    score = 8.0 + aligned * 4.0 - opposed * 3.0

    if regime == 1 and rsi_h4 > 48 and rsi_h1 > 45:
        score += 4.0
    elif regime == -1 and rsi_h4 < 52 and rsi_h1 < 55:
        score += 4.0

    if regime == 1 and rsi_d1 > 50:
        score += 2.0
    elif regime == -1 and rsi_d1 < 50:
        score += 2.0

    return float(np.clip(score, 0.0, _W_CTX))


def _score_recovery_layer(
    regime: int,
    slope_m1: float,
    div_m5: float,
    vol_m1: float,
    corr_type: str,
) -> float:
    if corr_type == "counter_move":
        return 2.0

    score = 5.0
    score += div_m5 * 6.0
    score += vol_m1 * 4.0

    if slope_m1 * regime > 0.8:
        score += 4.0  # flip momentum M1

    if corr_type == "trend_run":
        score += 2.0

    return float(np.clip(score, 0.0, _W_RECOVERY))


def _phase_from_scalp(
    corr_type: str, confidence: float, exec_depth: float, slope_m1: float, regime: int
) -> Tuple[str, bool]:
    """Map type + confiance → phase EA (trending|correcting|exhausted|resuming|ranging).

    RÈGLE STRICTE M1 (Boom/Crash) :
      - On ne passe JAMAIS en "exhausted" ou "resuming" sans flip momentum confirmé
        (slope_m1 * regime > 0 signifie que M1 a repris la direction de la tendance).
      - micro_pullback nécessite slope_m1 * regime > 0.5 pour "resuming"
        (pas juste > 0.3) — évite d'entrer pendant la micro-correction.
      - m5/m15_pullback nécessitent un momentum encore plus fort.
    """
    if corr_type == "range":
        return "ranging", confidence >= 38

    if corr_type == "counter_move":
        return "correcting", False

    if corr_type == "trend_run":
        return "trending", confidence >= 35

    # Flip momentum : M1 doit être retourné dans la direction de la tendance
    mom_strong = slope_m1 * regime > 0.5   # flip confirmé (pas juste > 0)
    mom_weak   = slope_m1 * regime > 0.0   # momentum neutre ou retourné

    if corr_type == "micro_pullback":
        # RESUMING : correction finie + flip momentum fort + confiance haute
        if confidence >= 60 and mom_strong and exec_depth < 0.25:
            return "resuming", True
        # EXHAUSTED : correction presque finie + momentum au moins neutre
        # NE PAS autoriser exhausted si slope est encore négatif (= correction en cours)
        if confidence >= 55 and mom_weak:
            return "exhausted", confidence >= 50
        # Sinon = correcting (trop tôt)
        return "correcting", confidence >= 55

    if corr_type == "m5_pullback":
        if confidence >= 65 and mom_strong:
            return "resuming", True
        if confidence >= 58 and mom_weak:
            return "exhausted", True
        return "correcting", confidence >= 55

    if corr_type == "m15_pullback":
        if confidence >= 70 and mom_strong:
            return "resuming", True
        if confidence >= 62 and mom_weak:
            return "exhausted", confidence >= 58
        return "correcting", confidence >= 58

    return "trending", confidence >= 35


def is_m1_correction_active(
    corr_type: str,
    phase: str,
    exec_depth: float,
    slope_m1: float,
    regime: int,
    confidence: float,
) -> Dict[str, Any]:
    """
    Gate strict M1 pour Boom/Crash : retourne True si une micro-correction
    est EN COURS et qu'il ne faut PAS entrer.

    Logique :
      - Si phase == "correcting" ou "ranging" → BLOCK (correction en cours)
      - Si corr_type == "micro_pullback" ET slope_m1 * regime < 0.5 → BLOCK
        (M1 n'a pas encore flip dans la bonne direction)
      - Si exec_depth > 0.3 ET mom弱 → BLOCK (pullback trop profond)
      - Sinon → OK (entrer)

    Retourne :
      {
        "blocked": bool,          # True = NE PAS entrer
        "reason": str,            # Raison du blocage (ou "OK")
        "correction_active": bool # True si micro-correction détectée
      }
    """
    mom_strong = slope_m1 * regime > 0.5
    mom_weak   = slope_m1 * regime > 0.0

    # 1. Phase correcting = toujours bloquer
    if phase == "correcting":
        return {
            "blocked": True,
            "reason": f"Phase '{phase}' — correction en cours (type={corr_type})",
            "correction_active": True,
        }

    # 2. Phase ranging = toujours bloquer
    if phase == "ranging":
        return {
            "blocked": True,
            "reason": "Phase 'ranging' — marché indécis, pas de direction claire",
            "correction_active": True,
        }

    # 3. micro_pullback sans flip momentum = bloquer
    if corr_type == "micro_pullback" and not mom_strong:
        return {
            "blocked": True,
            "reason": (
                f"Micro-pullback en cours (depth={exec_depth:.0%}, "
                f"slope_m1×regime={slope_m1 * regime:.2f} < 0.5) — "
                f"attendre flip momentum M1"
            ),
            "correction_active": True,
        }

    # 4. Pullback profond non résolu = bloquer
    if exec_depth > 0.3 and not mom_weak:
        return {
            "blocked": True,
            "reason": (
                f"Pullback profond (depth={exec_depth:.0%}) avec "
                f"slope négatif ({slope_m1 * regime:.2f}) — "
                f"correction pas terminée"
            ),
            "correction_active": True,
        }

    # 5. m5/m15 pullback sans flip = bloquer
    if corr_type in ("m5_pullback", "m15_pullback") and not mom_weak:
        return {
            "blocked": True,
            "reason": (
                f"{corr_type} en cours (slope_m1×regime={slope_m1 * regime:.2f}) — "
                f"momentum pas encore retourné"
            ),
            "correction_active": True,
        }

    # 6. counter_move = toujours bloquer
    if corr_type == "counter_move":
        return {
            "blocked": True,
            "reason": "Contre-tendance détectée — éviter ce trade",
            "correction_active": True,
        }

    # 7. Tous les checks passés → autoriser l'entrée
    return {
        "blocked": False,
        "reason": "OK" if phase in ("trending", "resuming") else f"Phase '{phase}' — momentum confirmé",
        "correction_active": corr_type in ("micro_pullback", "m5_pullback", "m15_pullback"),
    }


_STAGE_LABELS = {
    "none": "TENDANCE",
    "start": "DEBUT",
    "middle": "MILIEU",
    "end": "FIN",
}


def compute_correction_stage(
    corr_type: str,
    phase: str,
    exec_depth: float,
    entry_safe: bool,
    m1_blocked: bool,
    active_correction: bool,
    confidence: float = 50.0,
) -> Dict[str, Any]:
    """
    Phase lisible pour l'EA et le graphique :
      none   — pas de correction active (tendance)
      start  — correction qui démarre (entrées interdites)
      middle — correction en cours (entrées interdites)
      end    — correction terminée / reprise (entrées autorisées si entry_safe)
    """
    depth = float(exec_depth)
    if depth <= 1.0:
        depth *= 100.0
    phase_l = (phase or "").lower()
    ctype = corr_type or "unknown"

    stage = "none"
    blocks_entry = False

    if ctype == "counter_move":
        stage, blocks_entry = "middle", True
    elif ctype == "range" or phase_l == "ranging":
        stage, blocks_entry = "middle", True
    elif phase_l == "resuming" or (
        phase_l == "exhausted" and entry_safe and not m1_blocked
    ):
        stage, blocks_entry = "end", False
    elif not active_correction and ctype == "trend_run" and phase_l in ("trending", ""):
        stage, blocks_entry = "none", False
    elif m1_blocked or phase_l == "correcting" or active_correction:
        if depth < 22.0:
            stage, blocks_entry = "start", True
        elif depth < 58.0:
            stage, blocks_entry = "middle", True
        elif entry_safe or confidence >= 58.0:
            stage, blocks_entry = "end", False
        else:
            stage, blocks_entry = "middle", True
    elif phase_l == "exhausted":
        stage = "end" if entry_safe else "middle"
        blocks_entry = not entry_safe
    elif phase_l == "trending" and depth < 15.0:
        stage, blocks_entry = "none", False

    if stage in ("start", "middle"):
        blocks_entry = True

    return {
        "correction_stage": stage,
        "correction_stage_label": _STAGE_LABELS.get(stage, stage.upper()),
        "correction_stage_blocks_entry": blocks_entry,
    }


def _strength_label(confidence: float, corr_type: str) -> str:
    if corr_type == "counter_move":
        return "weak"
    if confidence >= 70:
        return "strong"
    if confidence >= 48:
        return "moderate"
    return "weak"


def compute_price_action_zones(
    df: Optional[pd.DataFrame],
    ma_fast: int = 50,
    ma_slow: int = 200,
    consolidation_gap_pct: float = 0.08,
) -> Dict[str, Any]:
    """
    Zones correction / consolidation via price action (MA50/MA200 + RSI + corps M1).
    Complète le scoring RSI multi-TF pour l'EA et le dashboard.
    """
    empty: Dict[str, Any] = {
        "price_action_trend": "UNKNOWN",
        "price_action_in_correction": False,
        "price_action_consolidation": False,
        "price_action_ma50": None,
        "price_action_ma200": None,
        "price_action_rsi": None,
        "price_action_zone_support": None,
        "price_action_zone_resistance": None,
        "price_action_correction_depth_pct": 0.0,
    }
    if df is None or len(df) < ma_slow + 5 or "close" not in df.columns:
        return empty

    close = df["close"].astype(float)
    ma50 = close.rolling(ma_fast).mean()
    ma200 = close.rolling(ma_slow).mean()
    if np.isnan(ma50.iloc[-1]) or np.isnan(ma200.iloc[-1]):
        return empty

    rsi = rsi_series(close, 14)
    last_close = float(close.iloc[-1])
    last_ma50 = float(ma50.iloc[-1])
    last_ma200 = float(ma200.iloc[-1])
    last_rsi = float(rsi.iloc[-1]) if not np.isnan(rsi.iloc[-1]) else 50.0

    uptrend = last_ma50 > last_ma200
    trend = "UP" if uptrend else "DOWN"
    ma_gap_pct = abs(last_ma50 - last_ma200) / max(last_close, 1e-9) * 100.0

    in_correction = (uptrend and last_close < last_ma50) or (
        not uptrend and last_close > last_ma50
    )

    small_body_ratio = 0.5
    if "open" in df.columns and "high" in df.columns and "low" in df.columns:
        bodies = (df["close"] - df["open"]).abs().iloc[-8:]
        ranges = (df["high"] - df["low"]).astype(float).replace(0, np.nan).iloc[-8:]
        valid = ranges.dropna()
        if len(valid) >= 3:
            small_body_ratio = float((bodies.iloc[-len(valid) :] / valid).mean())

    is_consolidation = ma_gap_pct < consolidation_gap_pct or (
        small_body_ratio < 0.42 and ma_gap_pct < consolidation_gap_pct * 2.5
    )

    return {
        "price_action_trend": trend,
        "price_action_in_correction": bool(in_correction),
        "price_action_consolidation": bool(is_consolidation),
        "price_action_ma50": round(last_ma50, 5),
        "price_action_ma200": round(last_ma200, 5),
        "price_action_rsi": round(last_rsi, 1),
        "price_action_zone_support": round(min(last_ma50, last_ma200), 5),
        "price_action_zone_resistance": round(max(last_ma50, last_ma200), 5),
        "price_action_correction_depth_pct": round(
            abs(last_close - last_ma50) / max(last_close, 1e-9) * 100.0, 3
        ),
        "price_action_ma_gap_pct": round(ma_gap_pct, 4),
        "price_action_small_body_ratio": round(small_body_ratio, 3),
    }


def compute_correction_exhaustion(
    df_m5: Optional[pd.DataFrame] = None,
    df_m15: Optional[pd.DataFrame] = None,
    rsi_h4: float = 50.0,
    rsi_h1: float = 50.0,
    rsi_d1: float = 50.0,
    direction_hint: int = 0,
    df_m1: Optional[pd.DataFrame] = None,
    rsi_m1: float = 50.0,
    rsi_m5: float = 50.0,
    rsi_m15: float = 50.0,
    rsi_m30: float = 50.0,
) -> Dict[str, Any]:
    """
    Score confiance correction orienté SCALP M1/M5.

    Tous les TF sont lus ; le score est dominé par M1/M5 (45 %).
    """
    rsi_m1 = _safe_rsi(rsi_m1)
    rsi_m5 = _safe_rsi(rsi_m5)
    rsi_m15 = _safe_rsi(rsi_m15)
    rsi_m30 = _safe_rsi(rsi_m30)
    rsi_h1 = _safe_rsi(rsi_h1)
    rsi_h4 = _safe_rsi(rsi_h4)
    rsi_d1 = _safe_rsi(rsi_d1)

    # Séries bougies (priorité données réelles M1/M5)
    rsi_m1_c, slope_m1, rsi_m1_s, close_m1 = _rsi_from_df(df_m1)
    rsi_m5_c, slope_m5, rsi_m5_s, close_m5 = _rsi_from_df(df_m5)
    _, _, rsi_m15_s, close_m15 = _rsi_from_df(df_m15)

    if len(rsi_m1_s) >= 5:
        rsi_m1 = rsi_m1_c
    if len(rsi_m5_s) >= 5:
        rsi_m5 = rsi_m5_c

    regime = direction_hint if direction_hint != 0 else detect_trend_regime(
        rsi_h4, rsi_h1, rsi_d1, rsi_m15
    )

    ctx_dirs = {
        "D1": _tf_dir_from_rsi(rsi_d1, regime),
        "H4": _tf_dir_from_rsi(rsi_h4, regime),
        "H1": _tf_dir_from_rsi(rsi_h1, regime),
    }
    exec_dirs = {
        "M15": _tf_dir_from_rsi(rsi_m15, regime),
        "M5": _tf_dir_from_rsi(rsi_m5, regime),
        "M1": _tf_dir_from_rsi(rsi_m1, regime),
    }

    exec_depth = _execution_pullback_depth(regime, rsi_m1, rsi_m5)
    corr_type = _classify_correction_type(
        regime, rsi_m1, rsi_m5, rsi_m15, slope_m1, slope_m5,
        exec_depth, ctx_dirs, exec_dirs,
    )

    div_m5 = 0.0
    if len(close_m5) >= 20 and len(rsi_m5_s) >= 20 and regime != 0:
        div_m5 = detect_rsi_divergence(close_m5, rsi_m5_s, regime, lookback=15)
    elif len(close_m15) >= 20 and len(rsi_m15_s) >= 20 and regime != 0:
        div_m5 = detect_rsi_divergence(close_m15, rsi_m15_s, regime, lookback=15) * 0.7

    vol_m1 = 0.5
    src_vol = df_m1 if df_m1 is not None and len(df_m1) >= 25 else df_m5
    if src_vol is not None and len(src_vol) >= 25:
        vol_m1 = compute_volume_ratio(src_vol, lookback_recent=5, lookback_base=20)

    s_exec = _score_execution_layer(
        regime, rsi_m1, rsi_m5, slope_m1, slope_m5, exec_depth, corr_type
    )
    s_struct = _score_structure_layer(regime, rsi_m15, rsi_m30, corr_type)
    s_ctx = _score_context_layer(regime, rsi_h1, rsi_h4, rsi_d1, ctx_dirs)
    s_rec = _score_recovery_layer(regime, slope_m1, div_m5, vol_m1, corr_type)

    confidence = float(np.clip(s_exec + s_struct + s_ctx + s_rec, 0.0, 100.0))

    # Planchers scalp : tendance claire + exécution alignée
    if corr_type == "trend_run" and regime != 0:
        confidence = max(confidence, 62.0)
    if corr_type == "micro_pullback" and slope_m1 * regime > 0.5:
        confidence = max(confidence, 48.0)

    phase, entry_safe = _phase_from_scalp(
        corr_type, confidence, exec_depth, slope_m1, regime
    )

    tf_aligned = sum(
        1 for d in list(ctx_dirs.values()) + list(exec_dirs.values()) if d == 1
    )
    tf_total = len(ctx_dirs) + len(exec_dirs)
    tf_alignment_pct = round(100.0 * tf_aligned / max(tf_total, 1), 0)

    execution_ready = (
        corr_type not in ("counter_move", "range")
        and confidence >= _PHASE_THRESHOLDS.get(phase, 45.0)
        and (slope_m1 * regime > 0 or corr_type == "trend_run")
    )

    price_action = compute_price_action_zones(df_m5 if df_m5 is not None else df_m1)
    if price_action.get("price_action_consolidation"):
        corr_type = "range" if corr_type == "trend_run" else corr_type
        phase = "ranging" if price_action["price_action_consolidation"] else phase
    if price_action.get("price_action_in_correction") and corr_type == "trend_run":
        corr_type = "micro_pullback"

    # ── Gate strict M1 : bloque l'entrée si micro-correction en cours ───────
    m1_gate = is_m1_correction_active(
        corr_type=corr_type,
        phase=phase,
        exec_depth=exec_depth,
        slope_m1=slope_m1,
        regime=regime,
        confidence=confidence,
    )

    # Si le gate bloque, on force execution_ready = False
    if m1_gate["blocked"]:
        execution_ready = False
        entry_safe = False

    stage_info = compute_correction_stage(
        corr_type=corr_type,
        phase=phase,
        exec_depth=exec_depth,
        entry_safe=entry_safe,
        m1_blocked=m1_gate["blocked"],
        active_correction=corr_type
        in ("micro_pullback", "m5_pullback", "m15_pullback", "counter_move"),
        confidence=confidence,
    )
    if stage_info["correction_stage_blocks_entry"]:
        execution_ready = False
        entry_safe = False

    return {
        "correction_exhaustion_pct": round(confidence, 1),
        "correction_type": corr_type,
        "correction_strength": _strength_label(confidence, corr_type),
        "correction_phase": phase,
        "phase": phase,  # alias legacy
        "trend_regime": regime,
        "entry_safe": entry_safe,
        "execution_ready": execution_ready,
        "tf_alignment_pct": tf_alignment_pct,
        "pullback_depth_pct": round(exec_depth * 100.0, 0),
        "correction_block_threshold": _PHASE_THRESHOLDS.get(phase, 45.0),
        "active_correction": corr_type in ("micro_pullback", "m5_pullback", "m15_pullback", "counter_move"),
        "rsi_m1": round(rsi_m1, 1),
        "rsi_m5": round(rsi_m5, 1),
        "rsi_m15_current": round(rsi_m15, 1),
        "rsi_m5_slope": round(slope_m5, 2),
        "rsi_m1_slope": round(slope_m1, 2),
        "divergence_score": round(div_m5, 2),
        "volume_score": round(vol_m1, 2),
        "tf_summary": (
            f"M1={rsi_m1:.0f} M5={rsi_m5:.0f} M15={rsi_m15:.0f} "
            f"H1={rsi_h1:.0f} type={corr_type}"
        ),
        "m1_entry_blocked": m1_gate["blocked"],
        "m1_entry_reason": m1_gate["reason"],
        **stage_info,
        **price_action,
    }
