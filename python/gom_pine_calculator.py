#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Pine Script Calculator — Réplique de GOM_KOLA_script.pine (scoring + verdict)
"""

import sys
from typing import Dict, Any, Tuple

if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")


# Seuils par catégorie d'actif (Deriv / Weltrade / Forex / Metal / Crypto / Indices)
ASSET_VERDICT_PROFILES: Dict[str, Dict[str, float]] = {
    "forex": {
        "gap_min": 1.2, "gap_good": 2.5, "gap_perfect": 4.0,
        "filter_ratio_min": 0.50, "min_entry_quality": 0.48, "mtf_perfect_pct": 0.60,
    },
    "metal": {
        "gap_min": 1.2, "gap_good": 2.5, "gap_perfect": 4.0,
        "filter_ratio_min": 0.45, "min_entry_quality": 0.52, "mtf_perfect_pct": 0.63,
    },
    "crypto": {
        "gap_min": 1.4, "gap_good": 2.8, "gap_perfect": 4.2,
        "filter_ratio_min": 0.45, "min_entry_quality": 0.50, "mtf_perfect_pct": 0.60,
    },
    "index": {
        "gap_min": 1.3, "gap_good": 2.6, "gap_perfect": 4.0,
        "filter_ratio_min": 0.45, "min_entry_quality": 0.48, "mtf_perfect_pct": 0.58,
    },
    "volatility": {
        "gap_min": 1.0, "gap_good": 2.0, "gap_perfect": 3.5,
        "filter_ratio_min": 0.40, "min_entry_quality": 0.40, "mtf_perfect_pct": 0.50,
    },
    "boom_crash": {
        "gap_min": 1.0, "gap_good": 2.0, "gap_perfect": 3.5,
        "filter_ratio_min": 0.40, "min_entry_quality": 0.38, "mtf_perfect_pct": 0.45,
    },
    "other": {
        "gap_min": 1.2, "gap_good": 2.5, "gap_perfect": 4.0,
        "filter_ratio_min": 0.45, "min_entry_quality": 0.45, "mtf_perfect_pct": 0.58,
    },
}


class GOMLPineCalculator:
    """Calcule scores et verdict comme le Pine Script GOM KOLA."""

    def __init__(self):
        self.verdict_coherence = True
        self.verdict_gap_th = 0.45  # Pine input verdict_gap_th
        self.verdict_bb_vwap_weight = 1.0
        self.verdict_adv_weight = 0.8
        self.spike_min = 0.62
        self.filter_ratio_min = 0.40  # Pine coherence_ok: filter_ratio >= 0.40
        self.gap_perfect = 4.0  # Pine is_perfect_* : verdict_gap >= 4.0
        self.gap_good = 2.5
        self.gap_min = 1.2  # Pine is_buy / is_sell
        self.min_entry_quality = 0.45
        self.mtf_perfect_pct = 0.63
        self._asset_category = "other"

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
        if spike_bc_en and is_boom and spike_tradable:
            score_buy += 2.5
        if spike_bc_en and is_crash and spike_tradable:
            score_sell += 2.5

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

        _ema_raw = record.get("ema_above_count")
        ema_above_count = int(_ema_raw) if _ema_raw is not None else 0
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
        """Pine lines 958-966 — hiérarchie PERFECT > GOOD > BUY/SELL."""
        verdict_gap = abs(score_buy - score_sell)
        coherence_ok = (
            not self.verdict_coherence
            or filter_ratio >= self.filter_ratio_min
            or verdict_gap >= (self.verdict_gap_th + 0.24)
        )
        if not coherence_ok:
            return 0

        if score_sell > score_buy:
            is_perfect = verdict_gap >= self.gap_perfect
            is_good = verdict_gap >= self.gap_good and not is_perfect
            is_sell = verdict_gap >= self.gap_min and not is_good and not is_perfect
            if is_perfect:
                return -3
            if is_good:
                return -2
            if is_sell:
                return -1
            return 0

        if score_buy > score_sell:
            is_perfect = verdict_gap >= self.gap_perfect
            is_good = verdict_gap >= self.gap_good and not is_perfect
            is_buy = verdict_gap >= self.gap_min and not is_good and not is_perfect
            if is_perfect:
                return 3
            if is_good:
                return 2
            if is_buy:
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

    @staticmethod
    def symbol_asset_category(symbol: str) -> str:
        """Catégorie actif Deriv/Weltrade — alignée SMC_Universal.mq5."""
        sym = str(symbol or "").upper().replace(" ", "")
        if any(x in sym for x in ("BOOM", "CRASH", "PAINX", "GAINX", "TRENDX", "BREAKX")):
            return "boom_crash"
        if any(x in sym for x in ("VOL", "FXVOL", "SFVVOL", "SFXVOL", "STEP")):
            return "volatility"
        if any(x in sym for x in ("XAU", "GOLD", "XAG", "SILVER")):
            return "metal"
        if any(x in sym for x in ("BTC", "ETH", "LTC", "CRYPTO")):
            return "crypto"
        if len(sym) <= 7 and sym.isalpha():
            return "forex"
        if any(x in sym for x in ("US30", "US500", "NAS", "GER", "DAX", "FTSE", "INDEX", "DJ30", "SPX")):
            return "index"
        if sym.endswith("USD") and len(sym) >= 6:
            return "forex"
        return "other"

    def _apply_asset_profile(self, record: Dict[str, Any]) -> str:
        """Applique les seuils verdict selon la catégorie d'actif."""
        cat = self.symbol_asset_category(str(record.get("symbol", "")))
        profile = ASSET_VERDICT_PROFILES.get(cat, ASSET_VERDICT_PROFILES["other"])
        self._asset_category = cat
        self.gap_min = float(profile["gap_min"])
        self.gap_good = float(profile["gap_good"])
        self.gap_perfect = float(profile["gap_perfect"])
        self.filter_ratio_min = float(profile["filter_ratio_min"])
        self.min_entry_quality = float(profile["min_entry_quality"])
        self.mtf_perfect_pct = float(profile["mtf_perfect_pct"])
        record["asset_category"] = cat
        return cat

    @staticmethod
    def _is_weltrade_synthetic(record: Dict[str, Any]) -> bool:
        sym = str(record.get("symbol", "")).upper().replace(" ", "")
        return (
            "FXVOL" in sym
            or "SFVVOL" in sym
            or "SFXVOL" in sym
            or sym.startswith("PAINX")
            or sym.startswith("GAINX")
            or "TRENDX" in sym
            or "BREAKX" in sym
        )

    def _normalize_spike_flags(self, record: Dict[str, Any]) -> None:
        """Active la logique spike Boom/Crash pour tous les synthétiques équivalents."""
        sym = str(record.get("symbol", "")).lower().replace(" ", "")
        cat = self.symbol_asset_category(sym)
        if cat in ("boom_crash", "volatility"):
            record["spike_bc_en"] = True
        elif "spike_bc_en" not in record:
            record["spike_bc_en"] = "boom" in sym or "crash" in sym

    def apply_mtf_verdict_gate(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Downgrade si le MTF contredit le verdict.

        Pondération : H4=3, H1=2, D1=2, M15=1, M5=1, M1=1, W1=1 (max=11).
        PERFECT BUY exige tb_w >= 7 (63%), GOOD exige tb_w > ts_w.
        """
        if verdict_num == 0:
            return 0

        h4_dir = str(record.get("tf_h4_dir", "NEUT") or "NEUT").upper()
        h1_dir = str(record.get("tf_h1_dir", "NEUT") or "NEUT").upper()

        cat = self.symbol_asset_category(str(record.get("symbol", "")))
        is_bc_synth = cat in ("boom_crash", "volatility")

        # Boom/Crash / Vol / PainX / GainX : gate MTF allégé (direction contrainte par actif)
        if is_bc_synth:
            if verdict_num > 0 and h4_dir == "BEAR" and h1_dir == "BEAR" and verdict_num >= 2:
                return 1
            if verdict_num < 0 and h4_dir == "BULL" and h1_dir == "BULL" and verdict_num <= -2:
                return -1
            return verdict_num

        # Poids par TF (structure > scalp)
        tf_w = {
            "tf_h4_dir": 3,
            "tf_h1_dir": 2,
            "tf_d1_dir": 2,
            "tf_m30_dir": 1,
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

        if verdict_num > 0:
            h1h4_override = False
            # H4 BEAR + H1 BEAR : limiter BUY si score fort, sinon WAIT
            if h4_dir == "BEAR" and h1_dir == "BEAR":
                score_buy = record.get("score_buy", 0) or 0
                if score_buy >= 9:
                    verdict_num = 2  # GOOD BUY max
                    h1h4_override = True
                elif score_buy >= 7:
                    verdict_num = 1  # BUY max
                    h1h4_override = True
                elif score_buy >= 5:
                    verdict_num = 1  # BUY min (signal fort mais H4+H1 contredisent)
                    h1h4_override = True
                else:
                    return 0
            # H4 BEAR seul = maximum BUY (jamais GOOD/PERFECT)
            if h4_dir == "BEAR" and verdict_num >= 2:
                verdict_num = 1
            # Contrediction forte : majorité pondérée BEAR → WAIT
            # Sauf si H4+H1 gate a autorisé le signal avec score fort
            if not h1h4_override and ts_w > tb_w * 1.5:
                return 0
            # PERFECT BUY : tb_w doit couvrir ≥ mtf_perfect_pct du poids total
            if verdict_num >= 3 and tb_w / total_w < self.mtf_perfect_pct:
                verdict_num = 2 if tb_w > ts_w else (1 if tb_w >= ts_w * 0.8 else 0)
            elif verdict_num >= 2 and tb_w <= ts_w:
                verdict_num = 1 if tb_w >= ts_w * 0.8 else 0
            elif verdict_num >= 1 and tb_w < ts_w and not h1h4_override:
                return 0
        elif verdict_num < 0:
            h1h4_override = False
            # H4 BULL + H1 BULL : limiter SELL si score fort, sinon WAIT
            if h4_dir == "BULL" and h1_dir == "BULL":
                score_sell = record.get("score_sell", 0) or 0
                if score_sell >= 9:
                    verdict_num = -2  # GOOD SELL max
                    h1h4_override = True
                elif score_sell >= 7:
                    verdict_num = -1  # SELL max
                    h1h4_override = True
                elif score_sell >= 5:
                    verdict_num = -1  # SELL min (signal fort mais H4+H1 contredisent)
                    h1h4_override = True
                else:
                    return 0
            # H4 BULL seul = maximum SELL (jamais GOOD/PERFECT)
            if h4_dir == "BULL" and verdict_num <= -2:
                verdict_num = -1
            if not h1h4_override and tb_w > ts_w * 1.5:
                return 0
            if verdict_num <= -3 and ts_w / total_w < self.mtf_perfect_pct:
                verdict_num = -2 if ts_w > tb_w else (-1 if ts_w >= tb_w * 0.8 else 0)
            elif verdict_num <= -2 and ts_w <= tb_w:
                verdict_num = -1 if ts_w >= tb_w * 0.8 else 0
            elif verdict_num <= -1 and ts_w < tb_w:
                return 0

        return verdict_num

    def apply_mtf_verdict_uplift(
        self, record: Dict[str, Any], score_buy: float, score_sell: float
    ) -> int:
        """Si coherence/gap bloque (WAIT) mais M1+M5+M15 alignés → minimum BUY/SELL."""
        m1 = record.get("tf_m1_dir", "NEUT")
        m5 = record.get("tf_m5_dir", "NEUT")
        m15 = record.get("tf_m15_dir", "NEUT")
        gap = abs(score_buy - score_sell)
        gd = record.get("tf_global_dir", "NEUT")

        if gap < 0.45:
            return 0

        cat = self.symbol_asset_category(str(record.get("symbol", "")))
        h1 = str(record.get("tf_h1_dir", "NEUT") or "NEUT").upper()
        if cat not in ("boom_crash", "volatility"):
            if score_buy >= score_sell and h1 == "BEAR":
                return 0
            if score_sell > score_buy and h1 == "BULL":
                return 0

        if m1 == m5 == m15 == "BULL" and score_buy >= score_sell:
            if gap >= self.gap_good:
                return 2
            return 1

        if m1 == m5 == m15 == "BEAR" and score_sell >= score_buy:
            if gap >= self.gap_good:
                return -2
            return -1

        bulls = sum(1 for d in (m1, m5, m15) if d == "BULL")
        bears = sum(1 for d in (m1, m5, m15) if d == "BEAR")

        if bulls >= 2 and gd == "BULL" and score_buy > score_sell and gap >= 0.45:
            return 2 if gap >= self.gap_good else 1
        if bears >= 2 and gd == "BEAR" and score_sell > score_buy and gap >= 0.45:
            return -2 if gap >= self.gap_good else -1

        return 0

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

    def apply_entry_quality_gate(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Downgrade si entry_quality insuffisante pour GOOD/PERFECT."""
        if verdict_num == 0:
            return 0
        eq = float(record.get("entry_quality", 0) or 0)
        if eq >= self.min_entry_quality:
            return verdict_num
        if abs(verdict_num) >= 3:
            return 2 if verdict_num > 0 else -2
        if abs(verdict_num) >= 2:
            return 1 if verdict_num > 0 else -1
        return 0

    def apply_smc_structure_gate(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Forex/Metal/Crypto/Index : exiger zone SMC (OTE, KOLA, OB ou BOS)."""
        if verdict_num == 0:
            return 0
        cat = self._asset_category or self.symbol_asset_category(str(record.get("symbol", "")))
        if cat in ("boom_crash", "volatility"):
            return verdict_num

        close = float(record.get("close", record.get("entry", 0)) or 0)
        in_ote = bool(record.get("in_ote", False))
        kola_ok = bool(
            (verdict_num > 0 and record.get("kola_near_buy"))
            or (verdict_num < 0 and record.get("kola_near_sell"))
        )
        bos_ok = bool(
            (verdict_num > 0 and record.get("bos_bull"))
            or (verdict_num < 0 and record.get("bos_bear"))
        )
        ob_ok = False
        if verdict_num > 0:
            bot = float(record.get("ob_bull_bot", 0) or 0)
            top = float(record.get("ob_bull_top", 0) or 0)
            if bot > 0 and top > 0 and close >= bot * 0.998 and close <= top * 1.005:
                ob_ok = True
        elif verdict_num < 0:
            bot = float(record.get("ob_bear_bot", 0) or 0)
            top = float(record.get("ob_bear_top", 0) or 0)
            if bot > 0 and top > 0 and close <= top * 1.002 and close >= bot * 0.995:
                ob_ok = True

        if in_ote or kola_ok or bos_ok or ob_ok:
            return verdict_num

        if abs(verdict_num) >= 3:
            return 2 if verdict_num > 0 else -2
        if abs(verdict_num) >= 2:
            return 1 if verdict_num > 0 else -1
        return 0

    def calculate_entry_quality(
        self, record: Dict[str, Any], score_buy: float, score_sell: float,
        verdict_gap: float, filter_ratio: float,
    ) -> float:
        """Pine lines 987-1012 — composite entry quality score."""
        if score_buy > score_sell:
            dir_for_eq = "BUY"
        elif score_sell > score_buy:
            dir_for_eq = "SELL"
        else:
            return 0.0

        gap_n = 0.0
        if verdict_gap > self.verdict_gap_th:
            gap_n = min(
                1.0,
                (verdict_gap - self.verdict_gap_th) / (self.verdict_gap_th * 2.5),
            )

        spike_bull = bool(record.get("spike_bull", False))
        spike_bear = bool(record.get("spike_bear", False))
        if record.get("spike_prob") is not None:
            spike_prob = float(record.get("spike_prob") or 0)
        elif record.get("spike_pct"):
            spike_prob = float(record.get("spike_pct") or 0) / 100.0
        else:
            spike_prob = 0.0

        spike_aligned = (
            (dir_for_eq == "BUY" and spike_bull)
            or (dir_for_eq == "SELL" and spike_bear)
        )
        if spike_aligned:
            sp_n = min(1.0, spike_prob / 0.72)
        elif spike_prob > 0:
            sp_n = 0.14 * min(1.0, spike_prob / 0.55)
        else:
            sp_n = 0.0

        lc_n = 0.0
        if dir_for_eq == "BUY" and record.get("kola_near_buy"):
            lc_n = 0.8
        if dir_for_eq == "SELL" and record.get("kola_near_sell"):
            lc_n = 0.8

        fq_n = filter_ratio
        eq = (
            0.20 * gap_n
            + 0.30 * sp_n
            + 0.24 * lc_n
            + 0.16 * fq_n
            + 0.10 * filter_ratio
        )
        return round(min(1.0, max(0.0, eq)), 2)

    def enrich_record(self, record: Dict[str, Any]) -> Dict[str, Any]:
        self._apply_asset_profile(record)
        self._normalize_spike_flags(record)
        score_buy, score_sell = self.calculate_scores(record)
        verdict_gap = abs(score_buy - score_sell)
        filter_ratio = self.calculate_filter_ratio(record, score_buy, score_sell)
        coherence_ok = (
            not self.verdict_coherence
            or filter_ratio >= self.filter_ratio_min
            or verdict_gap >= (self.verdict_gap_th + 0.24)
        )
        record["score_buy"] = score_buy
        record["score_sell"] = score_sell
        verdict_num = self.calculate_verdict_num(score_buy, score_sell, filter_ratio)
        if verdict_num == 0:
            verdict_num = self.apply_mtf_verdict_uplift(record, score_buy, score_sell)
        verdict_num = self.apply_mtf_verdict_gate(record, verdict_num)
        verdict_num = self.apply_bc_verdict_guard(record, verdict_num)
        record["entry_quality"] = self.calculate_entry_quality(
            record, score_buy, score_sell, verdict_gap, filter_ratio
        )
        verdict_num = self.apply_entry_quality_gate(record, verdict_num)
        verdict_num = self.apply_smc_structure_gate(record, verdict_num)

        record["verdict_gap"] = round(verdict_gap, 2)
        record["verdict_num"] = verdict_num
        record["verdict"] = self.verdict_text(verdict_num)
        record["filter_ratio"] = round(filter_ratio, 2)
        record["coherence_ok"] = coherence_ok
        record["coherence_pct"] = round(filter_ratio * 100.0, 1)
        return record


def verdict_text_from_num(verdict_num: int) -> str:
    return GOMLPineCalculator().verdict_text(verdict_num)


def forecast_to_verdict_num(
    direction_5m: str,
    direction_15m: str = "NEUTRAL",
    strength: float = 0.0,
    confidence: float = 0.0,
    agreement: float = 0.0,
) -> int:
    """
    Verdict prédictif sur les 5 prochaines bougies M1 (cognition).
    Basé uniquement sur bougies fermées — pas de repaint intrabar.
    """
    d5 = str(direction_5m or "NEUTRAL").upper()
    d15 = str(direction_15m or "NEUTRAL").upper()
    if d5 == "NEUTRAL":
        return 0
    if confidence < 0.40 or strength < 0.12:
        return 0

    sign = 1 if d5 == "BUY" else -1
    vn = sign
    if strength >= 0.30 and confidence >= 0.50:
        vn = sign * 2
    if (
        strength >= 0.48
        and confidence >= 0.62
        and agreement >= 0.28
        and (d15 == d5 or d15 == "NEUTRAL")
    ):
        vn = sign * 3
    return int(vn)


def blend_reactive_forecast_verdict(
    reactive_vn: int,
    forecast_vn: int,
    forecast_confidence: float = 0.0,
    forecast_agreement: float = 0.0,
) -> Tuple[int, str]:
    """
    Fusion situation réelle (réactif) + prévision 5 bougies (forecast).
    Déterministe sur données bougie fermée — pas de repaint.
    """
    reactive_vn = int(reactive_vn or 0)
    forecast_vn = int(forecast_vn or 0)

    if reactive_vn == 0 and forecast_vn == 0:
        return 0, "WAIT"

    r_sign = 1 if reactive_vn > 0 else (-1 if reactive_vn < 0 else 0)
    f_sign = 1 if forecast_vn > 0 else (-1 if forecast_vn < 0 else 0)

    if r_sign != 0 and f_sign != 0 and r_sign == f_sign:
        mag = min(3, max(abs(reactive_vn), abs(forecast_vn)) + 1)
        vn = r_sign * mag
        return vn, verdict_text_from_num(vn)

    if forecast_vn == 0 or f_sign == 0:
        return reactive_vn, verdict_text_from_num(reactive_vn)

    if reactive_vn == 0 and forecast_confidence >= 0.48:
        return forecast_vn, verdict_text_from_num(forecast_vn)

    if r_sign != 0 and f_sign != 0 and r_sign != f_sign:
        if abs(reactive_vn) >= 2 and forecast_confidence < 0.58:
            return reactive_vn, verdict_text_from_num(reactive_vn)
        if forecast_confidence >= 0.62 and forecast_agreement >= 0.30:
            return forecast_vn, verdict_text_from_num(forecast_vn)
        return 0, "WAIT"

    return reactive_vn, verdict_text_from_num(reactive_vn)
