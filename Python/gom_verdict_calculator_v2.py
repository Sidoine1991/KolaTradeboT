#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Verdict Calculator v2 — Implémentation CORRECTE de la logique des verdicts

import sys
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

Respecte strictement la spec:
- score_buy vs score_sell → gap
- verdict_gap = |score_buy - score_sell|
- filter_ratio = pass_count / 6 (vérification cohérence)
- Classification: PERFECT (gap >= 4.0) → GOOD (gap >= 2.5) → BUY/SELL (gap >= 1.2) → WAIT

Contrôles supplémentaires pour Boom/Crash:
- Alignement MTF (5+ TF sur 7 dans le même sens)
- Entry Quality Score (> 60%)
- Spike probability (> 70%)
"""

import sys
from typing import Dict, Any, Tuple
import math

# Fix Windows encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')


class GOMVerdictCalculatorV2:
    """Calcule les verdicts selon la hiérarchie CORRECTE des seuils."""

    # Seuils critiques (spec utilisateur)
    THRESHOLD_BUY_SELL = 1.2      # BUY/SELL
    THRESHOLD_GOOD = 2.5          # GOOD BUY/SELL
    THRESHOLD_PERFECT = 4.0       # PERFECT BUY/SELL

    # Seuils cohérence
    COHERENCE_RATIO_MIN = 0.40    # 40% minimum filters passing

    # Seuils contrôles supplémentaires (Boom/Crash)
    MTF_ALIGNMENT_MIN = 5         # 5+ TF sur 7 dans le même sens
    ENTRY_QUALITY_MIN = 60        # Entry Quality Score > 60%
    SPIKE_PROBABILITY_MIN = 70    # Spike probability > 70%

    def calculate_verdict_gap(self, score_buy: float, score_sell: float) -> float:
        """Calcule l'écart entre les deux scores: gap = |score_buy - score_sell|"""
        return abs(score_buy - score_sell)

    def check_coherence(self, record: Dict[str, Any]) -> Tuple[bool, float]:
        """
        Vérifie la cohérence: combien de filtres passent?
        Filtres: SuperTrend, VWAP, MACD, RSI, Keltner, Donchian

        Retourne: (coherence_ok, filter_ratio)
        """
        pass_count = 0
        total_filters = 6

        # SuperTrend direction
        st_dir = record.get("st_dir", 0)
        if st_dir == 1:
            pass_count += 1

        # VWAP position (1 if price > VWAP, 0 otherwise)
        vwap_mag = record.get("vwap_mag", 0.0)
        if vwap_mag > 0.5:
            pass_count += 1

        # MACD positive
        macd_line = record.get("macd_line", 0.0)
        if macd_line > 0:
            pass_count += 1

        # RSI (< 30 = oversold/BUY, > 70 = overbought/SELL)
        rsi = record.get("rsi14", 50)
        if rsi < 30 or rsi > 70:
            pass_count += 1

        # Keltner (similaire à Bollinger)
        kc_pos = record.get("kc_pos", 0.5)
        if kc_pos < 0.3 or kc_pos > 0.7:
            pass_count += 1

        # Donchian (DC signal)
        dc_sig = record.get("dc_sig", 0)
        if dc_sig != 0:
            pass_count += 1

        filter_ratio = pass_count / total_filters
        coherence_ok = filter_ratio >= self.COHERENCE_RATIO_MIN

        return coherence_ok, filter_ratio

    def check_mtf_alignment(self, record: Dict[str, Any], direction: str) -> bool:
        """
        Vérifie l'alignement multi-TF (5+ TF sur 7 dans le même sens).
        direction: "BULL" ou "BEAR"
        """
        bull_count = 0
        bear_count = 0

        for tf in ["m1", "m5", "m15", "h1", "h4", "d1", "w1"]:
            tf_dir = record.get(f"tf_{tf}_dir", "NEUT")
            if isinstance(tf_dir, str):
                tf_dir = tf_dir.upper()
                if tf_dir == "BULL":
                    bull_count += 1
                elif tf_dir == "BEAR":
                    bear_count += 1

        if direction == "BULL":
            return bull_count >= self.MTF_ALIGNMENT_MIN
        elif direction == "BEAR":
            return bear_count >= self.MTF_ALIGNMENT_MIN

        return False

    def check_entry_quality(self, record: Dict[str, Any]) -> bool:
        """Vérifie que Entry Quality Score > 60%"""
        entry_quality = record.get("entry_quality", 0)
        return entry_quality > self.ENTRY_QUALITY_MIN

    def check_spike_probability(self, record: Dict[str, Any]) -> bool:
        """Vérifie que Spike probability > 70%"""
        spike_prob = record.get("spike_prob", 0.0)
        return spike_prob > (self.SPIKE_PROBABILITY_MIN / 100.0)

    def calculate_verdict_num(
        self,
        score_buy: float,
        score_sell: float,
        coherence_ok: bool,
        gap: float,
        record: Dict[str, Any] = None
    ) -> int:
        """
        Calcule verdict_num selon la hiérarchie CORRECTE:

        BUY side (score_buy > score_sell):
            - PERFECT BUY (vn=3): gap >= 4.0 ET coherence_ok
            - GOOD BUY (vn=2): gap >= 2.5 ET gap < 4.0 ET coherence_ok
            - BUY (vn=1): gap >= 1.2 ET gap < 2.5 ET coherence_ok

        SELL side (score_sell > score_buy):
            - PERFECT SELL (vn=-3): gap >= 4.0 ET coherence_ok
            - GOOD SELL (vn=-2): gap >= 2.5 ET gap < 4.0 ET coherence_ok
            - SELL (vn=-1): gap >= 1.2 ET gap < 2.5 ET coherence_ok

        WAIT (vn=0): tous les autres cas
        """
        if record is None:
            record = {}

        # Si cohérence insuffisante ET gap insuffisant → WAIT
        if not coherence_ok and gap < self.THRESHOLD_PERFECT:
            return 0  # WAIT

        # ─── BUY SIDE ───
        if score_buy > score_sell:
            # PERFECT BUY: gap >= 4.0 ET coherence_ok
            if gap >= self.THRESHOLD_PERFECT and coherence_ok:
                return 3  # PERFECT BUY

            # GOOD BUY: gap >= 2.5 ET gap < 4.0 ET coherence_ok
            elif gap >= self.THRESHOLD_GOOD and gap < self.THRESHOLD_PERFECT and coherence_ok:
                return 2  # GOOD BUY

            # BUY: gap >= 1.2 ET gap < 2.5 ET coherence_ok
            elif gap >= self.THRESHOLD_BUY_SELL and gap < self.THRESHOLD_GOOD and coherence_ok:
                return 1  # BUY

        # ─── SELL SIDE ───
        elif score_sell > score_buy:
            # PERFECT SELL: gap >= 4.0 ET coherence_ok
            if gap >= self.THRESHOLD_PERFECT and coherence_ok:
                return -3  # PERFECT SELL

            # GOOD SELL: gap >= 2.5 ET gap < 4.0 ET coherence_ok
            elif gap >= self.THRESHOLD_GOOD and gap < self.THRESHOLD_PERFECT and coherence_ok:
                return -2  # GOOD SELL

            # SELL: gap >= 1.2 ET gap < 2.5 ET coherence_ok
            elif gap >= self.THRESHOLD_BUY_SELL and gap < self.THRESHOLD_GOOD and coherence_ok:
                return -1  # SELL

        # ─── DEFAULT ───
        return 0  # WAIT

    def calculate_verdict_text(self, verdict_num: int) -> str:
        """Retourne le texte du verdict selon verdict_num."""
        mapping = {
            3: "PERFECT BUY",
            2: "GOOD BUY",
            1: "BUY",
            0: "WAIT",
            -1: "SELL",
            -2: "GOOD SELL",
            -3: "PERFECT SELL"
        }
        return mapping.get(verdict_num, "WAIT")

    def enrich_record(self, record: Dict[str, Any]) -> Dict[str, Any]:
        """
        Enrichit un record avec scores, verdict et métadonnées de qualité.
        """
        # Récupérer les scores (supposés déjà calculés dans gom_local_calculator.py)
        score_buy = record.get("score_buy", 0.0)
        score_sell = record.get("score_sell", 0.0)

        # Calculer le gap
        gap = self.calculate_verdict_gap(score_buy, score_sell)

        # Vérifier la cohérence
        coherence_ok, filter_ratio = self.check_coherence(record)

        # Calculer verdict_num
        verdict_num = self.calculate_verdict_num(
            score_buy, score_sell, coherence_ok, gap, record
        )

        # Calculer texte verdict
        verdict_text = self.calculate_verdict_text(verdict_num)

        # Enrichir le record avec les nouvelles données
        record["verdict_gap"] = round(gap, 2)
        record["verdict_num"] = verdict_num
        record["verdict"] = verdict_text
        record["coherence_ok"] = coherence_ok
        record["filter_ratio"] = round(filter_ratio, 2)
        record["coherence_pct"] = round(filter_ratio * 100.0, 1)

        return record

    def validate_verdict_for_trading(
        self,
        record: Dict[str, Any],
        symbol: str = ""
    ) -> Tuple[bool, str]:
        """
        Validation supplémentaire AVANT le trading.

        Pour les verdicts GOOD ou PERFECT:
        - Vérifier alignement MTF (5+ TF)
        - Vérifier Entry Quality (> 60%)
        - Vérifier Spike probability (> 70%)

        Retourne: (is_valid, reason)
        """
        verdict_num = record.get("verdict_num", 0)

        # WAIT → toujours OK
        if verdict_num == 0:
            return True, "WAIT - No signal"

        # Pour BUY (vn=1) → OK directement
        if verdict_num == 1:
            return True, "BUY - Standard signal"

        # Pour SELL (vn=-1) → OK directement
        if verdict_num == -1:
            return True, "SELL - Standard signal"

        # Pour GOOD BUY/SELL (vn=±2) → Vérifications supplémentaires
        if verdict_num == 2:  # GOOD BUY
            if not self.check_mtf_alignment(record, "BULL"):
                return False, "GOOD BUY rejected: MTF alignment < 5/7"
            if not self.check_entry_quality(record):
                return False, "GOOD BUY rejected: Entry Quality < 60%"
            return True, "GOOD BUY - Validated"

        if verdict_num == -2:  # GOOD SELL
            if not self.check_mtf_alignment(record, "BEAR"):
                return False, "GOOD SELL rejected: MTF alignment < 5/7"
            if not self.check_entry_quality(record):
                return False, "GOOD SELL rejected: Entry Quality < 60%"
            return True, "GOOD SELL - Validated"

        # Pour PERFECT BUY/SELL (vn=±3) → Vérifications strictes
        if verdict_num == 3:  # PERFECT BUY
            if not self.check_mtf_alignment(record, "BULL"):
                return False, "PERFECT BUY rejected: MTF alignment < 5/7"
            if not self.check_entry_quality(record):
                return False, "PERFECT BUY rejected: Entry Quality < 60%"
            if not self.check_spike_probability(record):
                return False, "PERFECT BUY rejected: Spike probability < 70%"
            return True, "PERFECT BUY - Validated"

        if verdict_num == -3:  # PERFECT SELL
            if not self.check_mtf_alignment(record, "BEAR"):
                return False, "PERFECT SELL rejected: MTF alignment < 5/7"
            if not self.check_entry_quality(record):
                return False, "PERFECT SELL rejected: Entry Quality < 60%"
            if not self.check_spike_probability(record):
                return False, "PERFECT SELL rejected: Spike probability < 70%"
            return True, "PERFECT SELL - Validated"

        return False, f"Unknown verdict_num: {verdict_num}"


def test_verdict_calculator():
    """Test la logique des verdicts."""
    calc = GOMVerdictCalculatorV2()

    # Test cases
    test_records = [
        # PERFECT BUY
        {
            "name": "PERFECT BUY (gap=4.5, coherence=70%)",
            "score_buy": 12.3,
            "score_sell": 7.8,
            "st_dir": 1,
            "vwap_mag": 0.8,
            "macd_line": 0.5,
            "rsi14": 25,  # oversold
            "kc_pos": 0.2,
            "dc_sig": 1,
        },
        # GOOD BUY
        {
            "name": "GOOD BUY (gap=3.1, coherence=70%)",
            "score_buy": 10.2,
            "score_sell": 7.1,
            "st_dir": 1,
            "vwap_mag": 0.8,
            "macd_line": 0.5,
            "rsi14": 40,
            "kc_pos": 0.3,
            "dc_sig": 1,
        },
        # BUY
        {
            "name": "BUY (gap=1.5, coherence=70%)",
            "score_buy": 8.5,
            "score_sell": 7.0,
            "st_dir": 1,
            "vwap_mag": 0.8,
            "macd_line": 0.5,
            "rsi14": 45,
            "kc_pos": 0.4,
            "dc_sig": 1,
        },
        # WAIT (insufficient gap)
        {
            "name": "WAIT (gap=0.5, insufficient)",
            "score_buy": 8.0,
            "score_sell": 7.5,
            "st_dir": 0,
            "vwap_mag": 0.2,
            "macd_line": -0.1,
            "rsi14": 50,
            "kc_pos": 0.5,
            "dc_sig": 0,
        },
        # WAIT (good gap but bad coherence)
        {
            "name": "WAIT (gap=3.0 but coherence=30%)",
            "score_buy": 10,
            "score_sell": 7,
            "st_dir": -1,  # wrong direction
            "vwap_mag": 0.1,  # wrong
            "macd_line": -0.2,  # wrong
            "rsi14": 50,  # neutral
            "kc_pos": 0.5,  # neutral
            "dc_sig": 0,  # neutral
        },
    ]

    print("\n" + "="*80)
    print("TEST: GOM Verdict Calculator v2")
    print("="*80 + "\n")

    for test in test_records:
        record = {k: v for k, v in test.items() if k != "name"}

        gap = calc.calculate_verdict_gap(record.get("score_buy", 0), record.get("score_sell", 0))
        coherence_ok, filter_ratio = calc.check_coherence(record)
        verdict_num = calc.calculate_verdict_num(
            record.get("score_buy", 0),
            record.get("score_sell", 0),
            coherence_ok,
            gap,
            record
        )
        verdict_text = calc.calculate_verdict_text(verdict_num)

        print(f"Test: {test['name']}")
        print(f"  Gap: {gap:.1f}, Filter Ratio: {filter_ratio*100:.0f}%, Coherence OK: {coherence_ok}")
        print(f"  => Verdict: {verdict_text} (vn={verdict_num})")
        print()

    print("="*80)
    print("✅ All tests completed")
    print("="*80 + "\n")


if __name__ == "__main__":
    test_verdict_calculator()
