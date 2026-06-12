#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test de la nouvelle IA Status v2 — Validation multi-TF avec M5 prioritaire
"""
import json
import sys
from typing import Dict, Any

# Force UTF-8 on Windows
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Simuler la structure DecisionRequest
class MockRequest:
    def __init__(self, symbol, ema_fast_m1, ema_slow_m1, ema_fast_m5, ema_slow_m5,
                 ema_fast_h1, ema_slow_h1):
        self.symbol = symbol
        self.ema_fast_m1 = ema_fast_m1
        self.ema_slow_m1 = ema_slow_m1
        self.ema_fast_m5 = ema_fast_m5
        self.ema_slow_m5 = ema_slow_m5
        self.ema_fast_h1 = ema_fast_h1
        self.ema_slow_h1 = ema_slow_h1

def _ema_dir(fast: float, slow: float) -> int:
    """Retourne 1 (BUY), -1 (SELL), ou 0 (NEUTRAL)"""
    if not fast or not slow:
        return 0
    if fast > slow:
        return 1
    elif fast < slow:
        return -1
    return 0

def compute_ia_status_v2(request) -> Dict[str, Any]:
    """IA Status v2 AMÉLIORÉ avec M5 prioritaire"""

    tf_dirs: Dict[str, int] = {
        "W1": 0,  # Non dispo dans ce test
        "D1": 0,
        "H4": 0,
        "H1": _ema_dir(request.ema_fast_h1, request.ema_slow_h1),
        "M30": 0,
        "M15": 0,
        "M5": _ema_dir(request.ema_fast_m5, request.ema_slow_m5),
        "M1": _ema_dir(request.ema_fast_m1, request.ema_slow_m1),
    }

    tf_weights: Dict[str, float] = {
        "M5": 0.30,
        "M15": 0.25,
        "M1": 0.20,
        "H1": 0.15,
        "M30": 0.05,
        "H4": 0.03,
        "D1": 0.02,
        "W1": 0.00,
    }

    score_buy = 0.0
    score_sell = 0.0
    total_weight = 0.0
    count_buy = 0
    count_sell = 0
    count_neutral = 0

    for tf, direction in tf_dirs.items():
        weight = tf_weights.get(tf, 0.0)
        if direction > 0:
            score_buy += direction * weight
            count_buy += 1
        elif direction < 0:
            score_sell += abs(direction) * weight
            count_sell += 1
        else:
            count_neutral += 1
        total_weight += weight

    if total_weight > 0:
        score_buy /= total_weight
        score_sell /= total_weight

    m5_dir = tf_dirs.get("M5", 0)
    action = "hold"
    confidence = 0.5

    if m5_dir > 0:  # M5 dit BUY
        if score_buy > score_sell:
            action = "buy"
            confidence = min(0.95, 0.60 + (count_buy / 8.0) * 0.35)
        else:
            action = "hold"
            confidence = 0.45
    elif m5_dir < 0:  # M5 dit SELL
        if score_sell > score_buy:
            action = "sell"
            confidence = min(0.95, 0.60 + (count_sell / 8.0) * 0.35)
        else:
            action = "hold"
            confidence = 0.45
    else:  # M5 NEUTRAL
        if score_buy > 0.55:
            action = "buy"
            confidence = min(0.75, 0.50 + (count_buy / 8.0) * 0.25)
        elif score_sell > 0.55:
            action = "sell"
            confidence = min(0.75, 0.50 + (count_sell / 8.0) * 0.25)
        else:
            action = "hold"
            confidence = 0.40 + (count_neutral / 8.0) * 0.10

    aligned_count = 0
    if action == "buy":
        aligned_count = count_buy
    elif action == "sell":
        aligned_count = count_sell
    else:
        aligned_count = count_neutral

    alignment_score = min(1.0, aligned_count / 8.0) * 100.0
    confidence = max(0.0, min(1.0, confidence))

    return {
        "action": action,
        "confidence": confidence,
        "confidence_percent": round(confidence * 100.0, 1),
        "alignment_score": round(alignment_score, 1),
        "m5_direction": m5_dir,
        "score_buy": round(score_buy, 3),
        "score_sell": round(score_sell, 3),
        "timeframe_dirs": tf_dirs,
        "counts": {"buy": count_buy, "sell": count_sell, "neutral": count_neutral},
    }

# ===== TESTS =====

print("=" * 70)
print("TEST IA STATUS V2 - Multi-TF avec M5 Prioritaire")
print("=" * 70)

# Test 1: Tous les TF haussiers (M5 prioritaire)
print("\n[TEST 1] Tous TF haussiers")
req = MockRequest(
    "XAUUSD",
    ema_fast_m1=1.1, ema_slow_m1=1.0,  # M1 BUY
    ema_fast_m5=1.15, ema_slow_m5=1.0,  # M5 BUY (prioritaire)
    ema_fast_h1=1.2, ema_slow_h1=1.0,  # H1 BUY
)
result = compute_ia_status_v2(req)
print(f"  Action: {result['action'].upper()}")
print(f"  Confidence: {result['confidence_percent']}%")
print(f"  Alignment: {result['alignment_score']}%")
print(f"  M5 Dir: {result['m5_direction']} (1=BUY)")
print(f"  Buy votes: {result['counts']['buy']}/8")
print(f"  Sell votes: {result['counts']['sell']}/8")

# Test 2: M5 haussier, H1 baissier (M5 prioritaire, mais confiance réduite)
print("\n[TEST 2] M5 BUY, H1 SELL (conflit TF)")
req = MockRequest(
    "XAUUSD",
    ema_fast_m1=1.1, ema_slow_m1=1.0,  # M1 BUY
    ema_fast_m5=1.15, ema_slow_m5=1.0,  # M5 BUY (prioritaire!)
    ema_fast_h1=0.99, ema_slow_h1=1.0,  # H1 SELL (conflit)
)
result = compute_ia_status_v2(req)
print(f"  Action: {result['action'].upper()}")
print(f"  Confidence: {result['confidence_percent']}%")
print(f"  Alignment: {result['alignment_score']}%")
print(f"  M5 Dir: {result['m5_direction']} (1=BUY)")
print(f"  Buy votes: {result['counts']['buy']}/8")
print(f"  Sell votes: {result['counts']['sell']}/8")

# Test 3: M5 neutre, autres haussiers
print("\n[TEST 3] M5 NEUTRAL, M1+H1 BUY")
req = MockRequest(
    "XAUUSD",
    ema_fast_m1=1.1, ema_slow_m1=1.0,  # M1 BUY
    ema_fast_m5=1.0, ema_slow_m5=1.0,  # M5 NEUTRAL
    ema_fast_h1=1.2, ema_slow_h1=1.0,  # H1 BUY
)
result = compute_ia_status_v2(req)
print(f"  Action: {result['action'].upper()}")
print(f"  Confidence: {result['confidence_percent']}%")
print(f"  Alignment: {result['alignment_score']}%")
print(f"  M5 Dir: {result['m5_direction']} (0=NEUTRAL)")
print(f"  Buy votes: {result['counts']['buy']}/8")
print(f"  Score Buy: {result['score_buy']}")

# Test 4: Tous baissiers
print("\n[TEST 4] Tous TF baissiers (M5 SELL)")
req = MockRequest(
    "XAUUSD",
    ema_fast_m1=0.99, ema_slow_m1=1.0,  # M1 SELL
    ema_fast_m5=0.95, ema_slow_m5=1.0,  # M5 SELL (prioritaire)
    ema_fast_h1=0.90, ema_slow_h1=1.0,  # H1 SELL
)
result = compute_ia_status_v2(req)
print(f"  Action: {result['action'].upper()}")
print(f"  Confidence: {result['confidence_percent']}%")
print(f"  Alignment: {result['alignment_score']}%")
print(f"  M5 Dir: {result['m5_direction']} (-1=SELL)")
print(f"  Sell votes: {result['counts']['sell']}/8")

print("\n" + "=" * 70)
print("OK - Tous les tests completes!")
print("=" * 70)
