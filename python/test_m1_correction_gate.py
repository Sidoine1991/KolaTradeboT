#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tests unitaires pour le gate M1 correction — empêche les entrées
pendant les micro-corrections sur Boom/Crash M1.

Couvre :
  1. _phase_from_scalp() — flip momentum requis pour exhausted/resuming
  2. is_m1_correction_active() — gate de blocage
  3. compute_correction_exhaustion() — intégration complète
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
import pandas as pd
from correction_cycle_detector import (
    _phase_from_scalp,
    is_m1_correction_active,
    compute_correction_exhaustion,
)


# ============================================================================
# Tests _phase_from_scalp
# ============================================================================

class TestPhaseFromScalp:
    """Vérifie que les phases exigent le bon momentum."""

    def test_trend_run_always_trending(self):
        phase, safe = _phase_from_scalp("trend_run", 70.0, 0.1, 2.0, 1)
        assert phase == "trending"
        assert safe is True

    def test_counter_move_always_correcting(self):
        phase, safe = _phase_from_scalp("counter_move", 80.0, 0.2, -1.0, 1)
        assert phase == "correcting"
        assert safe is False

    def test_range_always_ranging(self):
        phase, safe = _phase_from_scalp("range", 50.0, 0.3, 0.0, 0)
        assert phase == "ranging"

    def test_micro_pullback_correcting_when_slope_negative(self):
        """Micro-pullback avec slope négatif = correcting (pas exhausted)."""
        phase, safe = _phase_from_scalp("micro_pullback", 65.0, 0.2, -1.5, 1)
        assert phase == "correcting"

    def test_micro_pullback_correcting_when_slope_zero(self):
        """Micro-pullback avec slope nul = correcting."""
        phase, safe = _phase_from_scalp("micro_pullback", 65.0, 0.2, 0.0, 1)
        assert phase == "correcting"

    def test_micro_pullback_exhausted_when_slope_weakly_positive(self):
        """Micro-pullback avec slope faiblement positif (0.2) = exhausted (pas resuming)."""
        phase, safe = _phase_from_scalp("micro_pullback", 60.0, 0.15, 0.3, 1)
        assert phase == "exhausted"
        assert safe is True

    def test_micro_pullback_resuming_when_slope_strong(self):
        """Micro-pullback avec slope fort (>0.5) + confiance >= 60 + depth < 25% = resuming."""
        phase, safe = _phase_from_scalp("micro_pullback", 65.0, 0.15, 1.0, 1)
        assert phase == "resuming"
        assert safe is True

    def test_micro_pullback_resuming_requires_high_confidence(self):
        """Resuming nécessite confiance >= 60."""
        phase, safe = _phase_from_scalp("micro_pullback", 50.0, 0.15, 1.0, 1)
        assert phase != "resuming"

    def test_micro_pullback_resuming_requires_depth_below_25(self):
        """Resuming nécessite exec_depth < 0.25."""
        phase, safe = _phase_from_scalp("micro_pullback", 65.0, 0.35, 1.0, 1)
        assert phase != "resuming"

    def test_m5_pullback_correcting_when_slope_negative(self):
        """m5_pullback avec slope négatif = correcting."""
        phase, safe = _phase_from_scalp("m5_pullback", 70.0, 0.4, -1.0, 1)
        assert phase == "correcting"

    def test_m5_pullback_exhausted_when_slope_weakly_positive(self):
        """m5_pullback avec slope faiblement positif + confiance >= 58 = exhausted."""
        phase, safe = _phase_from_scalp("m5_pullback", 62.0, 0.3, 0.3, 1)
        assert phase == "exhausted"

    def test_m5_pullback_resuming_requires_strong_slope(self):
        """m5_pullback resuming nécessite slope > 0.5 + confiance >= 65."""
        phase, safe = _phase_from_scalp("m5_pullback", 70.0, 0.3, 1.0, 1)
        assert phase == "resuming"

    def test_m15_pullback_correcting_when_slope_negative(self):
        """m15_pullback avec slope négatif = correcting."""
        phase, safe = _phase_from_scalp("m15_pullback", 75.0, 0.5, -1.0, 1)
        assert phase == "correcting"

    def test_m15_pullback_resuming_requires_strong_slope(self):
        """m15_pullback resuming nécessite slope > 0.5 + confiance >= 70."""
        phase, safe = _phase_from_scalp("m15_pullback", 75.0, 0.4, 1.0, 1)
        assert phase == "resuming"


# ============================================================================
# Tests is_m1_correction_active
# ============================================================================

class TestM1CorrectionActiveGate:
    """Vérifie le gate de blocage M1."""

    def test_block_when_phase_correcting(self):
        result = is_m1_correction_active("micro_pullback", "correcting", 0.2, -1.0, 1, 60.0)
        assert result["blocked"] is True
        assert "correcting" in result["reason"].lower()

    def test_block_when_phase_ranging(self):
        result = is_m1_correction_active("range", "ranging", 0.3, 0.0, 0, 40.0)
        assert result["blocked"] is True
        assert "ranging" in result["reason"].lower()

    def test_block_micro_pullback_without_flip(self):
        """Micro-pullback sans flip momentum (< 0.5) = block."""
        result = is_m1_correction_active("micro_pullback", "exhausted", 0.15, 0.3, 1, 60.0)
        assert result["blocked"] is True
        assert "flip" in result["reason"].lower() or "slope" in result["reason"].lower()

    def test_block_deep_pullback_with_negative_slope(self):
        """Pullback profond (> 30%) avec slope négatif = block."""
        result = is_m1_correction_active("micro_pullback", "exhausted", 0.4, -0.5, 1, 60.0)
        assert result["blocked"] is True

    def test_block_counter_move(self):
        result = is_m1_correction_active("counter_move", "correcting", 0.2, -2.0, 1, 50.0)
        assert result["blocked"] is True
        # Le reason peut être "correcting" (phase check) ou "contre-tendance" (type check)
        assert result["blocked"] is True

    def test_block_m5_pullback_without_momentum(self):
        """m5_pullback sans momentum = block."""
        result = is_m1_correction_active("m5_pullback", "correcting", 0.35, -0.5, 1, 60.0)
        assert result["blocked"] is True

    def test_allow_trending(self):
        result = is_m1_correction_active("trend_run", "trending", 0.1, 1.5, 1, 70.0)
        assert result["blocked"] is False
        assert "OK" in result["reason"]

    def test_allow_resuming(self):
        result = is_m1_correction_active("micro_pullback", "resuming", 0.15, 1.0, 1, 65.0)
        assert result["blocked"] is False

    def test_allow_exhausted_with_strong_flip(self):
        """Exhausted avec flip momentum fort (> 0.5) = autoriser."""
        result = is_m1_correction_active("micro_pullback", "exhausted", 0.2, 0.8, 1, 60.0)
        assert result["blocked"] is False


# ============================================================================
# Tests compute_correction_exhaustion intégration
# ============================================================================

class TestCorrectionExhaustionIntegration:
    """Tests d'intégration avec compute_correction_exhaustion."""

    def _make_df(self, closes, opens=None):
        """Crée un DataFrame OHLCV minimal."""
        if opens is None:
            opens = closes
        n = len(closes)
        return pd.DataFrame({
            "open": opens,
            "high": [max(o, c) + 0.1 for o, c in zip(opens, closes)],
            "low": [min(o, c) - 0.1 for o, c in zip(opens, closes)],
            "close": closes,
            "tick_volume": np.random.randint(1000, 5000, n),
        })

    def test_trending_bullish_no_block(self):
        """Tendance haussière claire = pas de blocage."""
        closes = list(np.linspace(100, 105, 50))
        df = self._make_df(closes)
        result = compute_correction_exhaustion(
            df_m1=df, df_m5=df,
            rsi_h4=55, rsi_h1=52, rsi_d1=53,
            rsi_m1=55, rsi_m5=53, rsi_m15=52,
            direction_hint=1,
        )
        assert result["m1_entry_blocked"] is False
        assert result["correction_phase"] in ("trending", "resuming")

    def test_micro_pullback_slope_negative_blocks(self):
        """Micro-pullback avec slope négatif = bloqué."""
        # Simuler un pullback : prix baisse puis remonte un peu
        closes = list(np.linspace(105, 103, 30)) + list(np.linspace(103, 103.5, 20))
        df = self._make_df(closes)
        result = compute_correction_exhaustion(
            df_m1=df, df_m5=df,
            rsi_h4=55, rsi_h1=52, rsi_d1=53,
            rsi_m1=42, rsi_m5=45, rsi_m15=48,
            direction_hint=1,
        )
        # Si le type est micro_pullback, le gate devrait bloquer
        if result["correction_type"] == "micro_pullback":
            assert result["m1_entry_blocked"] is True or result["correction_phase"] == "correcting"

    def test_execution_ready_respects_gate(self):
        """execution_ready doit être False si le gate bloque."""
        closes = list(np.linspace(100, 105, 50))
        df = self._make_df(closes)
        result = compute_correction_exhaustion(
            df_m1=df, df_m5=df,
            rsi_h4=55, rsi_h1=52, rsi_d1=53,
            rsi_m1=55, rsi_m5=53, rsi_m15=52,
            direction_hint=1,
        )
        # Si le gate bloque, execution_ready doit être False
        if result.get("m1_entry_blocked"):
            assert result["execution_ready"] is False

    def test_entry_safe_respects_gate(self):
        """entry_safe doit être False si le gate bloque."""
        closes = list(np.linspace(100, 105, 50))
        df = self._make_df(closes)
        result = compute_correction_exhaustion(
            df_m1=df, df_m5=df,
            rsi_h4=55, rsi_h1=52, rsi_d1=53,
            rsi_m1=55, rsi_m5=53, rsi_m15=52,
            direction_hint=1,
        )
        if result.get("m1_entry_blocked"):
            assert result["entry_safe"] is False


# ============================================================================
# Runner
# ============================================================================

def run_all_tests():
    """Lance tous les tests et affiche le résumé."""
    test_classes = [
        TestPhaseFromScalp,
        TestM1CorrectionActiveGate,
        TestCorrectionExhaustionIntegration,
    ]

    total = 0
    passed = 0
    failed = 0
    errors = []

    for cls in test_classes:
        instance = cls()
        methods = [m for m in dir(instance) if m.startswith("test_")]
        for method_name in methods:
            total += 1
            test_label = f"{cls.__name__}.{method_name}"
            try:
                getattr(instance, method_name)()
                passed += 1
                print(f"  [OK] {test_label}")
            except AssertionError as e:
                failed += 1
                errors.append((test_label, str(e)))
                print(f"  [FAIL] {test_label}: {e}")
            except Exception as e:
                failed += 1
                errors.append((test_label, f"Exception: {e}"))
                print(f"  [ERROR] {test_label}: {e}")

    print(f"\n{'='*70}")
    print(f"RÉSULTAT: {passed}/{total} tests passés, {failed} échoués")
    print(f"{'='*70}")

    if errors:
        print("\nÉCHECS:")
        for name, err in errors:
            print(f"  - {name}: {err}")

    return failed == 0


if __name__ == "__main__":
    print("="*70)
    print("TESTS M1 CORRECTION GATE — Boom/Crash")
    print("="*70)
    success = run_all_tests()
    sys.exit(0 if success else 1)
