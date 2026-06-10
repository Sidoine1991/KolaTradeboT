#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Pine Script Calculator — Réplique EXACTE de la formule Pine Script
Basée sur GOM_KOLA_script.pine (lignes 876-973)

Formule:
- score_buy / score_sell = somme de 40+ facteurs (ST, VWAP, BB, RSI, MACD, OB, Spike, SIDO, BOS, EMA, Keltner, Donchian)
- verdict_gap = abs(score_buy - score_sell)
- verdict_num = basé sur gap + coherence_ok
"""
import json
import sys
from pathlib import Path
from typing import Dict, Any, Tuple

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

class GOMLPineCalculator:
    """Calcule verdicts exactement comme le Pine Script."""

    def __init__(self):
        self.gom_file = Path("data/gom_signal.json")
        # Paramètres configurables
        self.verdict_coherence = True  # Si True → filter_ratio >= 0.40 pour coherence_ok
        self.verdict_gap_th = 0.45  # Seuil de gap

    def calculate_scores(self, record: Dict[str, Any]) -> Tuple[float, float]:
        """
        Calcule score_buy et score_sell selon Pine Script.

        Facteurs:
        1. Supertrend (ST) — ±1.5
        2. VWAP — ±1.0
        3. Bollinger Bands — ±0.5
        4. RSI(14) — ±1.0
        5. MACD — ±0.8
        6. Order Blocks (OB) — ±1.5
        7. Spike detection — ±2.0 / ±2.5 (Boom/Crash)
        8. SIDO patterns — ±1.2
        9. BOS/CHoCH — ±1.38 / -0.58
        10. EMA stack — ±0.15 à ±0.25
        11. Keltner Channel — ±0.22
        12. Donchian Channel — ±0.24
        """
        score_buy = 0.0
        score_sell = 0.0

        # === 1. SUPERTREND (±1.5) ===
        st_dir = record.get("st_dir", 0)  # 1 = UP, -1 = DOWN
        score_buy += 1.5 if st_dir == 1 else 0.0
        score_sell += 1.5 if st_dir == -1 else 0.0

        # === 2. VWAP (±1.0) ===
        close = record.get("entry", record.get("bb_mid", 0))
        vwap_val = record.get("vwap", close)
        score_buy += 1.0 if close > vwap_val else 0.0
        score_sell += 1.0 if close < vwap_val else 0.0

        # === 3. BOLLINGER BANDS (±0.5) ===
        bb_mid = record.get("bb_mid", 0)
        score_buy += 0.5 if close > bb_mid else 0.0
        score_sell += 0.5 if close < bb_mid else 0.0

        # === 4. RSI(14) (±1.0 ou ±0.5) ===
        rsi14 = record.get("tf_m1_rsi", 50)
        if rsi14 > 50 and rsi14 < 70:
            score_buy += 1.0
        elif rsi14 <= 35:
            score_buy += 0.5

        if rsi14 < 50 and rsi14 > 30:
            score_sell += 1.0
        elif rsi14 >= 65:
            score_sell += 0.5

        # === 5. MACD (±0.8) ===
        macd_line = record.get("macd_line", 0)
        macd_sig = record.get("macd_sig", 0)
        score_buy += 0.8 if macd_line > macd_sig else 0.0
        score_sell += 0.8 if macd_line < macd_sig else 0.0

        # === 6. ORDER BLOCKS (±1.5) ===
        ob_bull_bot = record.get("ob_bull_bot", 0)
        ob_bull_top = record.get("ob_bull_top", 0)
        ob_bear_bot = record.get("ob_bear_bot", 0)
        ob_bear_top = record.get("ob_bear_top", 0)

        if ob_bull_bot > 0 and ob_bull_top > 0:
            if close >= ob_bull_bot and close <= ob_bull_top * 1.003:
                score_buy += 1.5

        if ob_bear_bot > 0 and ob_bear_top > 0:
            if close <= ob_bear_top and close >= ob_bear_bot * 0.997:
                score_sell += 1.5

        # === 7. SPIKE (±2.0 / ±2.5 pour Boom/Crash) ===
        spike_prob = record.get("spike_prob", 0)
        spike_min = 0.62
        spike_bull = record.get("spike_bull", False)
        spike_bear = record.get("spike_bear", False)

        if spike_prob >= spike_min and spike_bull:
            score_buy += 2.0
        if spike_prob >= spike_min and spike_bear:
            score_sell += 2.0

        # Spike Boom/Crash bonus
        spike_bc_en = record.get("spike_bc_en", True)
        is_boom = "boom" in str(record.get("symbol", "")).lower()
        is_crash = "crash" in str(record.get("symbol", "")).lower()
        spike_tradable = record.get("spike_tradable", False)

        if spike_bc_en and is_boom and spike_tradable:
            score_buy += 2.5
        if spike_bc_en and is_crash and spike_tradable:
            score_sell += 2.5

        # === 8. SIDO PATTERNS (±1.2) ===
        sido_dt_level = record.get("sido_dt_level", None)
        sido_db_level = record.get("sido_db_level", None)

        if sido_dt_level and close >= sido_dt_level * 0.998:
            score_sell += 1.2
        if sido_db_level and close <= sido_db_level * 1.002:
            score_buy += 1.2

        # === 9. BOS/CHoCH (±1.38 / -0.58) ===
        bos_bull = record.get("bos_bull", False)
        bos_bear = record.get("bos_bear", False)

        score_buy += 1.38 if bos_bull else 0.0
        score_sell += 1.38 if bos_bear else 0.0
        score_buy -= 0.58 if bos_bear else 0.0
        score_sell -= 0.58 if bos_bull else 0.0

        # === 10. EMA STACK (±0.15 à ±0.25) ===
        ema_above_count = record.get("ema_above_count", 2)
        score_buy += ema_above_count * 0.15
        score_sell += (4 - ema_above_count) * 0.15
        score_buy += 0.25 if ema_above_count >= 4 else 0.0
        score_sell += 0.25 if ema_above_count <= 0 else 0.0

        # === 11. KOLA LEVELS (±1.5) ===
        kola_near_buy = record.get("kola_near_buy", False)
        kola_near_sell = record.get("kola_near_sell", False)
        score_buy += 1.5 if kola_near_buy else 0.0
        score_sell += 1.5 if kola_near_sell else 0.0

        # === 12. VWAP DISTANCE (±0.24) ===
        vwap_dist_pct = record.get("vwap_dist_pct", 0.0)
        vwap_mag = record.get("vwap_mag", 1.0)
        verdict_bb_vwap_weight = record.get("verdict_bb_vwap_weight", 1.0)

        if vwap_dist_pct > 0.00025:
            score_buy += 0.24 * verdict_bb_vwap_weight * vwap_mag
        if vwap_dist_pct < -0.00025:
            score_sell += 0.24 * verdict_bb_vwap_weight * vwap_mag

        # === 13. BOLLINGER SQUEEZE (±0.06) ===
        bb_width = record.get("bb_width", 0)
        bb_width_ma = record.get("bb_width_ma", 1)
        bb_squeeze = bb_width < bb_width_ma * 0.85

        score_buy += 0.06 * verdict_bb_vwap_weight if bb_squeeze else 0.0
        score_sell += 0.06 * verdict_bb_vwap_weight if bb_squeeze else 0.0

        # === 14. KELTNER CHANNEL (±0.22) ===
        kc_pos = record.get("kc_pos", 0.0)
        verdict_adv_weight = record.get("verdict_adv_weight", 1.0)

        if kc_pos > 0.10:
            score_buy += 0.22 * verdict_adv_weight * min(1.0, abs(kc_pos))
        if kc_pos < -0.10:
            score_sell += 0.22 * verdict_adv_weight * min(1.0, abs(kc_pos))

        # === 15. DONCHIAN CHANNEL (±0.24) ===
        dc_sig = record.get("dc_sig", 0)
        if dc_sig > 0:
            score_buy += 0.24 * verdict_adv_weight
        if dc_sig < 0:
            score_sell += 0.24 * verdict_adv_weight

        return round(score_buy, 2), round(score_sell, 2)

    def calculate_verdict_num(self, score_buy: float, score_sell: float, filter_ratio: float = 0.5) -> int:
        """
        Calcule verdict_num selon la formule Pine Script:

        verdict_gap = abs(score_buy - score_sell)
        coherence_ok = not verdict_coherence or filter_ratio >= 0.40 or verdict_gap >= (verdict_gap_th + 0.24)

        is_perfect_sell = score_sell > score_buy and verdict_gap >= 4.0 and coherence_ok → vn = -3
        is_good_sell    = score_sell > score_buy and verdict_gap >= 2.5 and coherence_ok → vn = -2
        is_sell         = score_sell > score_buy and verdict_gap >= 1.2 and coherence_ok → vn = -1
        is_perfect_buy  = score_buy > score_sell and verdict_gap >= 4.0 and coherence_ok → vn = +3
        is_good_buy     = score_buy > score_sell and verdict_gap >= 2.5 and coherence_ok → vn = +2
        is_buy          = score_buy > score_sell and verdict_gap >= 1.2 and coherence_ok → vn = +1
        else → vn = 0 (WAIT)
        """
        verdict_gap = abs(score_buy - score_sell)

        # Coherence check
        coherence_ok = (
            not self.verdict_coherence or
            filter_ratio >= 0.40 or
            verdict_gap >= (self.verdict_gap_th + 0.24)
        )

        if not coherence_ok:
            return 0  # WAIT si coherence échoue

        # Déterminer verdict_num selon gap et direction
        if score_sell > score_buy:
            if verdict_gap >= 4.0:
                return -3  # PERFECT SELL
            elif verdict_gap >= 2.5:
                return -2  # GOOD SELL
            elif verdict_gap >= 1.2:
                return -1  # SELL
            else:
                return 0  # WAIT
        elif score_buy > score_sell:
            if verdict_gap >= 4.0:
                return 3  # PERFECT BUY
            elif verdict_gap >= 2.5:
                return 2  # GOOD BUY
            elif verdict_gap >= 1.2:
                return 1  # BUY
            else:
                return 0  # WAIT
        else:
            return 0  # WAIT

    def verdict_text(self, verdict_num: int) -> str:
        """Retourne le texte du verdict."""
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
        """Enrichit un record avec scores et verdict calculés Pine-exact."""
        score_buy, score_sell = self.calculate_scores(record)
        verdict_gap = abs(score_buy - score_sell)

        # Calculer coherence (estimation simple: toujours ok si coherence_gate désactivée)
        filter_ratio = record.get("filter_ratio", 0.5)
        verdict_num = self.calculate_verdict_num(score_buy, score_sell, filter_ratio)
        verdict_text = self.verdict_text(verdict_num)

        record["score_buy"] = score_buy
        record["score_sell"] = score_sell
        record["verdict_gap"] = verdict_gap
        record["verdict_num"] = verdict_num
        record["verdict"] = verdict_text

        return record

    def process_all_symbols(self):
        """Traite tous les symboles dans gom_signal.json."""
        if not self.gom_file.exists():
            print(f"❌ Fichier non trouvé: {self.gom_file}")
            return

        data = json.loads(self.gom_file.read_text(encoding="utf-8"))

        for symbol in data:
            record = data[symbol]
            enriched = self.enrich_record(record)
            data[symbol] = enriched

        self.gom_file.write_text(json.dumps(data, indent=2, ensure_ascii=False))

        # Log résumé
        print("\n" + "="*80)
        print("✅ GOM Pine Script Calculator — Résultats")
        print("="*80)
        for symbol in sorted(data.keys()):
            rec = data[symbol]
            vn = rec.get("verdict_num", 0)
            verdict = rec.get("verdict", "WAIT")
            score_buy = rec.get("score_buy", 0)
            score_sell = rec.get("score_sell", 0)
            gap = rec.get("verdict_gap", 0)
            print(f"  {symbol:25s} | vn={vn:2d} | {verdict:12s} | Buy:{score_buy:6.2f} Sell:{score_sell:6.2f} Gap:{gap:6.2f}")
        print("="*80)


if __name__ == "__main__":
    calc = GOMLPineCalculator()
    calc.process_all_symbols()
