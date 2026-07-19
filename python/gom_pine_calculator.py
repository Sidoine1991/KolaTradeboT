#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Pine Script Calculator — Réplique de GOM_KOLA_script.pine (scoring + verdict)
"""

import sys
from typing import Dict, Any, Tuple

if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")


class GOMLPineCalculator:
    """Calcule scores et verdict comme le Pine Script GOM KOLA."""

    def __init__(self):
        self.verdict_coherence = True
        self.verdict_gap_th = 0.45
        self.verdict_bb_vwap_weight = 1.0
        self.verdict_adv_weight = 0.8
        self.spike_min = 0.62
        # Min confirmateurs (sur 6) pour valider la cohérence — 0.55 = 3.3/6
        self.filter_ratio_min = 0.55
        # Gap minimum pour PERFECT — augmenté à 5.0 (vs 4.0 précédent)
        self.gap_perfect = 5.0
        # Gap pour GOOD — inchangé
        self.gap_good = 2.5

    def calculate_filter_ratio(
        self, record: Dict[str, Any], score_buy: float, score_sell: float
    ) -> float:
        """Pine lines 947-955 — coherence gate filters."""
        st_dir = int(record.get("st_dir", 0) or 0)
        close = float(record.get("close", record.get("entry", 0)) or 0)
        vwap_val = float(record.get("vwap", close) or close)
        macd_line = float(record.get("macd_line", 0) or 0)
        macd_sig = float(record.get("macd_sig", 0) or 0)
        rsi14 = float(record.get("rsi14", 50) or 50)
        kc_pos = float(record.get("kc_pos", 0) or 0)
        dc_sig = float(record.get("dc_sig", 0) or 0)

        pc1 = 1.0 if (
            (st_dir == 1 and score_buy > score_sell)
            or (st_dir == -1 and score_sell > score_buy)
        ) else 0.0
        pc2 = 1.0 if (
            (close > vwap_val and score_buy > score_sell)
            or (close < vwap_val and score_sell > score_buy)
        ) else 0.0
        pc3 = 1.0 if (
            (macd_line > macd_sig and score_buy > score_sell)
            or (macd_line < macd_sig and score_sell > score_buy)
        ) else 0.0
        pc4 = 1.0 if (
            (rsi14 > 50 and score_buy > score_sell)
            or (rsi14 < 50 and score_sell > score_buy)
        ) else 0.0
        pc5 = 1.0 if (
            (kc_pos > 0 and score_buy > score_sell)
            or (kc_pos < 0 and score_sell > score_buy)
        ) else 0.0
        pc6 = 1.0 if (
            (dc_sig > 0 and score_buy > score_sell)
            or (dc_sig < 0 and score_sell > score_buy)
        ) else 0.0

        return (pc1 + pc2 + pc3 + pc4 + pc5 + pc6) / 6.0

    def calculate_scores(self, record: Dict[str, Any]) -> Tuple[float, float]:
        """Pine lines 876-941."""
        score_buy = 0.0
        score_sell = 0.0

        st_dir = int(record.get("st_dir", 0) or 0)
        close = float(record.get("close", record.get("entry", 0)) or 0)
        vwap_val = float(record.get("vwap", close) or close)
        bb_mid = float(record.get("bb_mid", 0) or 0)
        rsi14 = float(record.get("rsi14", record.get("tf_m15_rsi", 50)) or 50)
        macd_line = float(record.get("macd_line", 0) or 0)
        macd_sig = float(record.get("macd_sig", 0) or 0)

        score_buy += 1.5 if st_dir == 1 else 0.0
        score_sell += 1.5 if st_dir == -1 else 0.0
        score_buy += 1.0 if close > vwap_val else 0.0
        score_sell += 1.0 if close < vwap_val else 0.0
        score_buy += 0.5 if close > bb_mid else 0.0
        score_sell += 0.5 if close < bb_mid else 0.0

        if rsi14 > 50 and rsi14 < 70:
            score_buy += 1.0
        elif rsi14 <= 35:
            score_buy += 0.5
        if rsi14 < 50 and rsi14 > 30:
            score_sell += 1.0
        elif rsi14 >= 65:
            score_sell += 0.5

        score_buy += 0.8 if macd_line > macd_sig else 0.0
        score_sell += 0.8 if macd_line < macd_sig else 0.0

        ob_bull_bot = float(record.get("ob_bull_bot", 0) or 0)
        ob_bull_top = float(record.get("ob_bull_top", 0) or 0)
        ob_bear_bot = float(record.get("ob_bear_bot", 0) or 0)
        ob_bear_top = float(record.get("ob_bear_top", 0) or 0)

        if ob_bull_bot > 0 and ob_bull_top > 0:
            if close >= ob_bull_bot and close <= ob_bull_top * 1.003:
                score_buy += 1.5
        if ob_bear_bot > 0 and ob_bear_top > 0:
            if close <= ob_bear_top and close >= ob_bear_bot * 0.997:
                score_sell += 1.5

        if record.get("spike_prob") is not None:
            spike_prob = float(record.get("spike_prob") or 0)
        elif record.get("spike_pct"):
            spike_prob = float(record.get("spike_pct") or 0) / 100.0
        else:
            spike_prob = 0.0
        spike_bull = bool(record.get("spike_bull", False))
        spike_bear = bool(record.get("spike_bear", False))
        if spike_prob >= self.spike_min and spike_bull:
            score_buy += 2.0
        if spike_prob >= self.spike_min and spike_bear:
            score_sell += 2.0

        symbol = str(record.get("symbol", "")).lower()
        is_boom = "boom" in symbol
        is_crash = "crash" in symbol
        spike_bc_en = bool(record.get("spike_bc_en", is_boom or is_crash))
        spike_level_num = int(record.get("spike_level_num", 0) or 0)
        spike_pred_prob = float(record.get("spike_pred_prob", 0) or 0)
        spike_tradable = bool(record.get("spike_tradable", False))

        if spike_bc_en and is_boom and spike_level_num >= 2 and spike_pred_prob >= 50:
            score_buy += 1.5
        if spike_bc_en and is_crash and spike_level_num >= 2 and spike_pred_prob >= 50:
            score_sell += 1.5
        # spike_tradable limité à +1.5 sans confirmation MTF (anti faux positifs)
        tb = int(record.get("tf_bull_count") or 0)
        ts = int(record.get("tf_bear_count") or 0)
        spike_mtf_confirmed_bull = tb >= 3
        spike_mtf_confirmed_bear = ts >= 3
        spike_boost_buy = 2.5 if spike_mtf_confirmed_bull else 1.5
        spike_boost_sell = 2.5 if spike_mtf_confirmed_bear else 1.5
        if spike_bc_en and is_boom and spike_tradable:
            score_buy += spike_boost_buy
        if spike_bc_en and is_crash and spike_tradable:
            score_sell += spike_boost_sell

        vwap_dist_pct = float(record.get("vwap_dist_pct", 0) or 0)
        vwap_mag = float(record.get("vwap_mag", 0) or 0)
        w = self.verdict_bb_vwap_weight
        if vwap_dist_pct > 0.00025:
            score_buy += 0.24 * w * vwap_mag
        if vwap_dist_pct < -0.00025:
            score_sell += 0.24 * w * vwap_mag

        bb_pctb = float(record.get("bb_pctb", 0.5) or 0.5)
        if bb_pctb < 0.22:
            score_buy += 0.16 * w
        if bb_pctb > 0.78:
            score_sell += 0.16 * w
        if record.get("bb_squeeze"):
            score_buy += 0.06 * w
            score_sell += 0.06 * w

        adv = self.verdict_adv_weight
        if st_dir == 1:
            score_buy += 0.20 * adv
        if st_dir == -1:
            score_sell += 0.20 * adv

        kc_pos = float(record.get("kc_pos", 0) or 0)
        if kc_pos > 0.10:
            score_buy += 0.22 * adv * min(1.0, abs(kc_pos))
        if kc_pos < -0.10:
            score_sell += 0.22 * adv * min(1.0, abs(kc_pos))

        dc_sig = float(record.get("dc_sig", 0) or 0)
        if dc_sig > 0:
            score_buy += 0.24 * adv
        if dc_sig < 0:
            score_sell += 0.24 * adv

        # Défaut = 2 (neutre) quand la valeur n'est pas renseignée par les candles
        _ema_raw = record.get("ema_above_count")
        ema_above_count = int(_ema_raw) if _ema_raw is not None else 2
        score_buy += ema_above_count * 0.15
        score_sell += (4 - ema_above_count) * 0.15
        if ema_above_count >= 4:
            score_buy += 0.25
        if ema_above_count <= 0:
            score_sell += 0.25

        if record.get("kola_near_buy"):
            score_buy += 1.5
        if record.get("kola_near_sell"):
            score_sell += 1.5

        sido_dt = record.get("sido_dt_level")
        sido_db = record.get("sido_db_level")
        if sido_dt and close >= float(sido_dt) * 0.998:
            score_sell += 1.2
        if sido_db and close <= float(sido_db) * 1.002:
            score_buy += 1.2

        bos_bull = bool(record.get("bos_bull", False))
        bos_bear = bool(record.get("bos_bear", False))
        score_buy += 1.38 if bos_bull else 0.0
        score_sell += 1.38 if bos_bear else 0.0
        score_buy -= 0.58 if bos_bear else 0.0
        score_sell -= 0.58 if bos_bull else 0.0

        return round(score_buy, 2), round(score_sell, 2)

    def calculate_verdict_num(
        self, score_buy: float, score_sell: float, filter_ratio: float = 0.5
    ) -> int:
        verdict_gap = abs(score_buy - score_sell)
        coherence_ok = (
            not self.verdict_coherence
            or filter_ratio >= self.filter_ratio_min
            or verdict_gap >= (self.verdict_gap_th + 0.24)
        )
        if not coherence_ok:
            return 0

        # PERFECT requiert gap >= 5.0 ET filtre >= 0.67 (4/6 confirmateurs)
        perfect_ok = filter_ratio >= 0.67 and verdict_gap >= self.gap_perfect

        if score_sell > score_buy:
            if perfect_ok:
                return -3
            if verdict_gap >= self.gap_good:
                return -2
            if verdict_gap >= 1.2:
                return -1
            return 0
        if score_buy > score_sell:
            if perfect_ok:
                return 3
            if verdict_gap >= self.gap_good:
                return 2
            if verdict_gap >= 1.2:
                return 1
            return 0
        return 0

    def verdict_text(self, verdict_num: int) -> str:
        return {
            3: "PERFECT BUY",
            2: "GOOD BUY",
            1: "BUY",
            0: "WAIT",
            -1: "SELL",
            -2: "GOOD SELL",
            -3: "PERFECT SELL",
        }.get(verdict_num, "WAIT")

    def apply_mtf_verdict_gate(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Downgrade si le MTF contredit le verdict.

        Pondération : H4=3, H1=2, D1=2, M15=1, M5=1, M1=1, W1=1 (max=11).
        PERFECT BUY exige tb_w >= 7 (63%), GOOD exige tb_w > ts_w.
        """
        if verdict_num == 0:
            return 0

        # Poids par TF (structure > scalp)
        tf_w = {
            "tf_h4_dir": 3,
            "tf_h1_dir": 2,
            "tf_d1_dir": 2,
            "tf_m15_dir": 1,
            "tf_m5_dir": 1,
            "tf_m1_dir": 1,
            "tf_w1_dir": 1,
        }
        tb_w = sum(w for k, w in tf_w.items() if record.get(k, "NEUT") == "BULL")
        ts_w = sum(w for k, w in tf_w.items() if record.get(k, "NEUT") == "BEAR")
        total_w = tb_w + ts_w if (tb_w + ts_w) > 0 else 1

        # Fallback legacy counts si les directions granulaires ne sont pas disponibles
        if tb_w == 0 and ts_w == 0:
            tb_w = int(record.get("tf_bull_count") or 0)
            ts_w = int(record.get("tf_bear_count") or 0)
            total_w = max(tb_w + ts_w, 1)

        h4_dir = record.get("tf_h4_dir", "NEUT")
        h1_dir = record.get("tf_h1_dir", "NEUT")

        if verdict_num > 0:
            # H4 BEAR + H1 BEAR = structure bearish confirmée → WAIT sur BUY
            if h4_dir == "BEAR" and h1_dir == "BEAR":
                return 0
            # H4 BEAR seul = maximum BUY (jamais GOOD/PERFECT)
            if h4_dir == "BEAR" and verdict_num >= 2:
                verdict_num = 1
            # Contrediction forte : majorité pondérée BEAR → WAIT
            if ts_w > tb_w * 1.5:
                return 0
            # PERFECT BUY : tb_w doit couvrir ≥ 63% du poids total
            if verdict_num >= 3 and tb_w / total_w < 0.63:
                verdict_num = 2 if tb_w > ts_w else (1 if tb_w >= ts_w * 0.8 else 0)
            elif verdict_num >= 2 and tb_w <= ts_w:
                verdict_num = 1 if tb_w >= ts_w * 0.8 else 0
            elif verdict_num >= 1 and tb_w < ts_w:
                return 0
        elif verdict_num < 0:
            # H4 BULL + H1 BULL = structure bullish confirmée → WAIT sur SELL
            if h4_dir == "BULL" and h1_dir == "BULL":
                return 0
            # H4 BULL seul = maximum SELL (jamais GOOD/PERFECT)
            if h4_dir == "BULL" and verdict_num <= -2:
                verdict_num = -1
            if tb_w > ts_w * 1.5:
                return 0
            if verdict_num <= -3 and ts_w / total_w < 0.63:
                verdict_num = -2 if ts_w > tb_w else (-1 if ts_w >= tb_w * 0.8 else 0)
            elif verdict_num <= -2 and ts_w <= tb_w:
                verdict_num = -1 if ts_w >= tb_w * 0.8 else 0
            elif verdict_num <= -1 and ts_w < tb_w:
                return 0

        return verdict_num

    def apply_bc_verdict_guard(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Boom/Crash: inversion uniquement si spike imminent confirmé (spike_tradable=True).

        La logique "drift = pré-spike" n'est valide que quand spike_tradable est True
        (spike detector a confirmé le setup). Sans confirmation, on respecte la tendance
        réelle indiquée par les scores — sinon on génère des BUY contre-tendance sur Boom
        en plein marché baissier.

        Règles absolues (inchangées) :
        - SELL interdit sur Boom → si vn < 0 et pas de spike imminent → 0 (WAIT)
        - BUY interdit sur Crash → si vn > 0 et pas de spike imminent → 0 (WAIT)
        """
        sym = str(record.get("symbol", "")).lower()
        is_crash = "crash" in sym
        is_boom = "boom" in sym

        if not is_crash and not is_boom:
            return verdict_num

        spike_tradable = bool(record.get("spike_tradable", False))

        if is_crash:
            if verdict_num > 0:
                # Score dit BUY : inverser seulement si spike baissier imminent confirmé
                return -verdict_num if spike_tradable else 0
            return verdict_num  # SELL ou WAIT : respecter

        if is_boom:
            if verdict_num < 0:
                # Score dit SELL : inverser seulement si spike haussier imminent confirmé
                return -verdict_num if spike_tradable else 0
            return verdict_num  # BUY ou WAIT : respecter

        return verdict_num

    def enrich_record(self, record: Dict[str, Any]) -> Dict[str, Any]:
        score_buy, score_sell = self.calculate_scores(record)
        verdict_gap = abs(score_buy - score_sell)
        filter_ratio = self.calculate_filter_ratio(record, score_buy, score_sell)
        coherence_ok = (
            not self.verdict_coherence
            or filter_ratio >= self.filter_ratio_min
            or verdict_gap >= (self.verdict_gap_th + 0.24)
        )
        verdict_num = self.calculate_verdict_num(score_buy, score_sell, filter_ratio)
        verdict_num = self.apply_mtf_verdict_gate(record, verdict_num)
        verdict_num = self.apply_bc_verdict_guard(record, verdict_num)

        record["score_buy"] = score_buy
        record["score_sell"] = score_sell
        record["verdict_gap"] = round(verdict_gap, 2)
        record["verdict_num"] = verdict_num
        record["verdict"] = self.verdict_text(verdict_num)
        record["filter_ratio"] = round(filter_ratio, 2)
        record["coherence_ok"] = coherence_ok
        record["coherence_pct"] = round(filter_ratio * 100.0, 1)
        record["entry_quality"] = round(
            min(1.0, max(0.0, (verdict_gap - self.verdict_gap_th) / (self.verdict_gap_th * 2.5)))
            if verdict_gap > self.verdict_gap_th
            else 0.0,
            2,
        )
        return record
