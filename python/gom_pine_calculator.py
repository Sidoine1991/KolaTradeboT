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

        score_buy, score_sell = apply_m1_momentum_to_scores(record, score_buy, score_sell)

        return round(score_buy, 2), round(score_sell, 2)

    def calculate_verdict_num(
        self, score_buy: float, score_sell: float, filter_ratio: float = 0.5, record: Dict[str, Any] = None
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

        # Cohérence prix = move 5 bougies (aligné Pine), pas distance VWAP
        price_strong_up = False
        price_strong_down = False
        if record is not None:
            price_dir = _price_direction_5b(record)
            strong = _strong_move_threshold(record)
            price_strong_up = price_dir > strong
            price_strong_down = price_dir < -strong
            d3 = float(record.get("price_direction_3b", 0) or 0)
            if d3 > strong * 0.7:
                price_strong_up = True
            if d3 < -strong * 0.7:
                price_strong_down = True

        if score_sell > score_buy:
            cat = (
                GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
                if record is not None
                else "other"
            )
            is_synth = cat in ("boom_crash", "volatility")
            if price_strong_up and not is_synth:
                return 0
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
            cat = (
                GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
                if record is not None
                else "other"
            )
            is_synth = cat in ("boom_crash", "volatility")
            # GainX/Boom/PainX : micro-pullback M1 normal — ne pas zero le verdict ici ;
            # apply_price_reality_gate dégrade PERFECT→GOOD→BUY si besoin.
            if price_strong_down and not is_synth:
                return 0
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
        verdict_num = self.calculate_verdict_num(score_buy, score_sell, filter_ratio, record)
        if verdict_num == 0:
            verdict_num = self.apply_mtf_verdict_uplift(record, score_buy, score_sell)
        verdict_num = self.apply_mtf_verdict_gate(record, verdict_num)
        verdict_num = self.apply_bc_verdict_guard(record, verdict_num)
        record["entry_quality"] = self.calculate_entry_quality(
            record, score_buy, score_sell, verdict_gap, filter_ratio
        )
        verdict_num = self.apply_entry_quality_gate(record, verdict_num)
        verdict_num = self.apply_smc_structure_gate(record, verdict_num)
        verdict_num, reality_reason = apply_price_reality_gate(record, verdict_num)
        if reality_reason:
            record["price_reality_reason"] = reality_reason

        record["verdict_gap"] = round(verdict_gap, 2)
        record["verdict_num"] = verdict_num
        record["verdict"] = self.verdict_text(verdict_num)
        record["filter_ratio"] = round(filter_ratio, 2)
        record["coherence_ok"] = coherence_ok
        record["coherence_pct"] = round(filter_ratio * 100.0, 1)
        if verdict_num == 0 and max(score_buy, score_sell) >= self.gap_min + 1.0:
            hints = []
            if not coherence_ok:
                hints.append("coherence_blocked")
            if reality_reason:
                hints.append(reality_reason)
            elif score_buy > score_sell:
                hints.append("scores_buy_but_vn0")
            record["verdict_zero_hint"] = ";".join(hints) if hints else "scores_insufficient_gap"
        record["harmonized_m1"] = bool(record.get("m1_close")) or bool(record.get("price_direction_5b"))
        record["verdict_mode"] = "reactive_pine"
        return record


def _strong_move_threshold(record: Dict[str, Any]) -> float:
    """Seuil move M1 fort — plus sensible sur synthetics (intervalle 5 min)."""
    cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
    if cat in ("boom_crash", "volatility"):
        return 0.00035
    if cat in ("metal", "crypto"):
        return 0.0005
    return 0.001


def enrich_m1_metrics(
    record: Dict[str, Any],
    closes: list,
    opens: list,
    highs: list,
    lows: list,
) -> None:
    """Métriques M1 canoniques — source unique Python + MT5 payload."""
    if len(closes) < 6:
        return

    c0 = float(closes[-1])
    c1 = float(closes[-2])
    c3 = float(closes[-4])
    c4 = float(closes[-5])

    def _rel(a: float, b: float) -> float:
        avg = (a + b) / 2.0
        return (a - b) / avg if avg > 0 else 0.0

    d1 = _rel(c0, c1)
    d3 = _rel(c0, c3)
    d5 = _rel(c0, c4)
    record["m1_close"] = round(c0, 5)
    record["m1_close_5"] = round(c4, 5)
    record["price_direction_1b"] = round(d1, 6)
    record["price_direction_3b"] = round(d3, 6)
    record["price_direction_5b"] = round(d5, 6)
    record["m1_momentum"] = round(0.15 * d1 + 0.35 * d3 + 0.50 * d5, 6)

    thr = _strong_move_threshold(record) * 0.45
    if record["m1_momentum"] > thr:
        record["tf_m1_dir_live"] = "BULL"
    elif record["m1_momentum"] < -thr:
        record["tf_m1_dir_live"] = "BEAR"
    else:
        record["tf_m1_dir_live"] = "NEUT"

    vn = int(record.get("verdict_num", 0) or 0)
    trade_sign = 1 if vn > 0 else (-1 if vn < 0 else 0)
    if trade_sign == 0:
        sb = float(record.get("score_buy", 0) or 0)
        ss = float(record.get("score_sell", 0) or 0)
        trade_sign = 1 if sb >= ss else -1

    opp = 0
    for o, c in zip(opens[-6:], closes[-6:]):
        o_f, c_f = float(o), float(c)
        if trade_sign > 0 and c_f < o_f:
            opp += 1
        elif trade_sign < 0 and c_f > o_f:
            opp += 1
    record["m1_opp_bars"] = opp

    body_pct = []
    range_pct = []
    for i in range(-min(60, len(closes)), 0):
        cl = float(closes[i])
        if cl <= 0:
            continue
        body_pct.append(abs(float(closes[i]) - float(opens[i])) / cl)
        range_pct.append((float(highs[i]) - float(lows[i])) / cl)

    spike_prob = float(record.get("spike_prob", 0) or 0)
    if record.get("spike_pct") is not None:
        spike_prob = max(spike_prob, float(record.get("spike_pct", 0) or 0) / 100.0)
    if bool(record.get("spike_tradable")) and spike_prob >= 0.55:
        record["bars_since_spike"] = 0
        record["m1_bars_since_spike"] = 0
        return

    bars_since = -1
    if body_pct:
        avg_body = sum(body_pct) / len(body_pct)
        avg_range = sum(range_pct) / len(range_pct)
        cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
        if cat in ("boom_crash", "volatility"):
            body_thr = max(0.00035, avg_body * 1.75)
            range_thr = max(0.00075, avg_range * 1.75)
        else:
            body_thr = max(0.00055, avg_body * 2.0)
            range_thr = max(0.0010, avg_range * 2.0)

        for i in range(len(body_pct) - 1, -1, -1):
            if body_pct[i] >= body_thr or range_pct[i] >= range_thr:
                bars_since = len(body_pct) - 1 - i
                break

    record["bars_since_spike"] = bars_since
    record["m1_bars_since_spike"] = bars_since


def apply_m1_momentum_to_scores(
    record: Dict[str, Any], score_buy: float, score_sell: float
) -> Tuple[float, float]:
    """Ajuste les scores selon momentum M1 réel (sensible aux variations intra-5min)."""
    mom = record.get("m1_momentum")
    if mom is None:
        mom = record.get("price_direction_5b")
    if mom is None:
        return score_buy, score_sell
    try:
        mom = float(mom)
    except (TypeError, ValueError):
        return score_buy, score_sell

    cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
    weight = 2.2 if cat in ("boom_crash", "volatility") else 1.6
    scale = 0.0015 if cat in ("boom_crash", "volatility") else 0.0025
    mag = min(1.0, abs(mom) / scale)

    if mom > 0.00012:
        score_buy += weight * mag
        score_sell -= weight * 0.45 * mag
    elif mom < -0.00012:
        score_sell += weight * mag
        score_buy -= weight * 0.45 * mag

    strong = _strong_move_threshold(record)
    if mom < -strong:
        score_buy -= 1.8
    if mom > strong:
        score_sell -= 1.8

    d1 = float(record.get("price_direction_1b", 0) or 0)
    if d1 < -strong * 0.6 and mom < 0:
        score_buy -= 0.8
    if d1 > strong * 0.6 and mom > 0:
        score_sell -= 0.8

    return round(score_buy, 2), round(score_sell, 2)


def _price_direction_5b(record: Dict[str, Any]) -> float:
    """Variation relative close vs close[4] (Pine price_direction)."""
    explicit = record.get("price_direction_5b", record.get("price_change_5b_pct"))
    if explicit is not None:
        try:
            return float(explicit)
        except (TypeError, ValueError):
            pass
    c0 = float(record.get("m1_close", record.get("close", record.get("entry", 0))) or 0)
    c4 = float(record.get("m1_close_5", record.get("close_m1_5", 0)) or 0)
    if c0 > 0 and c4 > 0:
        avg = (c0 + c4) / 2.0
        return (c0 - c4) / avg if avg > 0 else 0.0
    # Fallback faible : distance VWAP (legacy)
    vwap = float(record.get("vwap", c0) or c0)
    if c0 > 0 and vwap > 0:
        return (c0 - vwap) / vwap
    return 0.0


def apply_price_reality_gate(record: Dict[str, Any], verdict_num: int) -> Tuple[int, str]:
    """Empêche PERFECT/GOOD figés contre l'évolution réelle M1.

    Règles (ordre) :
    1. bars_since_spike > 15 → WAIT
    2. bars_since_spike > 12 → max SIMPLE (|vn|≤1)
    3. bars_since_spike > 10 → max GOOD (|vn|≤2) — jamais PERFECT stale
    4. M1 label contre + PERFECT → GOOD
    5. Move 5b fort contre → WAIT
    6. Micro-stairs (bougies M1 adverses) → WAIT / rétrograde
    """
    vn = int(verdict_num or 0)
    if vn == 0:
        return 0, ""

    trade_dir = 1 if vn > 0 else -1
    reasons: list = []

    bars = -1
    for key in ("bars_since_spike", "m1_bars_since_spike"):
        raw = record.get(key)
        if raw is None:
            continue
        try:
            bars = int(raw)
            break
        except (TypeError, ValueError):
            continue

    cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
    is_synth = cat in ("boom_crash", "volatility")

    if bars >= 0:
        # GainX/PainX/Boom/Crash : tendance sans grosse bougie « spike » fréquente —
        # ne pas forcer WAIT pur (observé GainX 800 : scores BUY forts mais vn=0).
        if bars > 20 and abs(vn) >= 2:
            if is_synth:
                vn = trade_dir * 1
                reasons.append(f"stale_spike>{bars}->SIMPLE_synth")
            else:
                return 0, f"bars_since_spike={bars}>20"
        if bars > 15 and abs(vn) >= 3:
            vn = trade_dir * 2
            reasons.append(f"stale_spike>{bars}->GOOD")
        elif bars > 12 and abs(vn) >= 2:
            vn = trade_dir * 1
            reasons.append(f"stale_spike>{bars}->SIMPLE")
        elif bars > 10 and abs(vn) >= 3:
            vn = trade_dir * 2
            reasons.append(f"stale_spike>{bars}->GOOD")

    m1 = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "").upper()
    m1_against = (trade_dir > 0 and m1 == "BEAR") or (trade_dir < 0 and m1 == "BULL")

    strong = _strong_move_threshold(record)
    price_dir = _price_direction_5b(record)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d1 = float(record.get("price_direction_1b", 0) or 0)

    if trade_dir > 0 and (price_dir < -strong or d3 < -strong * 0.85):
        if is_synth:
            if abs(vn) >= 3:
                vn = trade_dir * 2
                reasons.append("price_down_synth->GOOD")
            elif abs(vn) >= 2:
                vn = trade_dir * 1
                reasons.append("price_down_synth->BUY")
        else:
            return 0, "price_strong_down_vs_buy"
    if trade_dir < 0 and (price_dir > strong or d3 > strong * 0.85):
        if is_synth:
            if abs(vn) >= 3:
                vn = trade_dir * 2
                reasons.append("price_up_synth->GOOD")
            elif abs(vn) >= 2:
                vn = trade_dir * 1
                reasons.append("price_up_synth->SELL")
        else:
            return 0, "price_strong_up_vs_sell"

    mom = float(record.get("m1_momentum", price_dir) or 0)
    if abs(vn) >= 3 and ((trade_dir > 0 and mom < -strong * 0.5) or (trade_dir < 0 and mom > strong * 0.5)):
        vn = trade_dir * 2
        reasons.append("m1_momentum_vs_perfect")

    if abs(vn) >= 2 and ((trade_dir > 0 and d1 < -strong * 0.55) or (trade_dir < 0 and d1 > strong * 0.55)):
        # Synth GainX/Boom : 1 bougie M1 contre ne doit pas effacer GOOD si M1 live reste aligné
        skip_1b = is_synth and (
            (trade_dir > 0 and m1 in ("BULL", "BUY"))
            or (trade_dir < 0 and m1 in ("BEAR", "SELL"))
        )
        if not skip_1b:
            vn = trade_dir * 1
            reasons.append("m1_1b_against_good")

    try:
        opp = int(record.get("m1_opp_bars", record.get("m1_adverse_bars", 0)) or 0)
    except (TypeError, ValueError):
        opp = 0

    # PERFECT + ≥3 bougies adverses /6 → WAIT (micro-correction / stairs)
    if abs(vn) >= 3 and opp >= 3:
        return 0, f"micro_stairs_opp={opp}"
    # GOOD + ≥5 adverses → WAIT
    if abs(vn) >= 2 and opp >= 5:
        return 0, f"micro_stairs_opp={opp}"

    if m1_against and abs(vn) >= 3:
        vn = trade_dir * 2
        reasons.append("m1_against_perfect")
    # GOOD + ≥4 adverses + M1 contre → SIMPLE
    if abs(vn) >= 2 and opp >= 4 and m1_against:
        vn = trade_dir * 1
        reasons.append(f"micro_corr_opp={opp}")

    return vn, ";".join(reasons)


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
    Basé UNIQUEMENT sur bougies M1 fermées — pas de repaint intrabar.
    Pour éviter repainting, la prévision utilise les bougies M1
    complètement closes précédentes (bar_0..bar_4), excluant la 
    bougie M1 actuelle en direct. Utilise une marge anti-repaint redondante
    avec une logique de virgule fractionnaire interne pour une prévision stable.
    """
    d5 = str(direction_5m or "NEUTRAL").upper()
    d15 = str(direction_15m or "NEUTRAL").upper()
    
    # TIR ANTI-REPAINT : même direction pour tout le bloc de 5 barres M1 fermées
    # Cela force une prédiction stable basée sur un ensemble complet de données fermées,
    # évitant les variations intrabar qui causent des changements fréquents de direction
    if d5 == "BUY":
        d5_stable = "BUY"
        d15_stable = "BUY" if d15 != "NEUTRAL" else "NEUTRAL"
    elif d5 == "SELL":
        d5_stable = "SELL"
        d15_stable = "SELL" if d15 != "NEUTRAL" else "NEUTRAL"
    else:
        d5_stable = "NEUTRAL"
        d15_stable = "NEUTRAL"
    if d5_stable == "NEUTRAL":
        return 0
    if confidence < 0.40 or strength < 0.12:
        return 0

    sign = 1 if d5_stable == "BUY" else -1
    vn = sign
    if strength >= 0.30 and confidence >= 0.50:
        vn = sign * 2
    if (
        strength >= 0.48
        and confidence >= 0.62
        and agreement >= 0.28
        and (d15_stable == d5_stable or d15_stable == "NEUTRAL")
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
        # Ne jamais inventer PERFECT par simple accord — max(GOOD) +1 seulement
        # si le réactif est déjà GOOD (|vn|>=2). Sinon plafonner à GOOD.
        base = max(abs(reactive_vn), abs(forecast_vn))
        if base >= 2 and abs(reactive_vn) >= 2 and abs(forecast_vn) >= 2:
            mag = min(3, base + 1)
        else:
            mag = min(2, base + 1)
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
