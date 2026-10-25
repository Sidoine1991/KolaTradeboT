#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Pine Script Calculator — Réplique de GOM_KOLA_script.pine (scoring + verdict)
"""

import os
import sys
import math
from datetime import datetime, timezone
from typing import Dict, Any, Optional, Tuple

if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

# FIX 2026-09-19 (Sidoine) : GOMVerdictCalculatorV2 = autorité de classification
# (seuils purs 1.2 / 2.5 / 4.0 + cohérence). Import toléré : si le module v2
# manque, on retombe sur l'ancienne classification Pine (non autoritaire).
try:
    from gom_verdict_calculator_v2 import GOMVerdictCalculatorV2
except Exception:
    GOMVerdictCalculatorV2 = None


def _m1_spike_thresholds(
    cat: str, avg_body: float, avg_range: float
) -> Tuple[float, float]:
    """Seuils bougie-spike M1 (corps/range) par catégorie d'actif."""
    if cat in ("boom_crash", "volatility"):
        return max(0.00035, avg_body * 1.75), max(0.00075, avg_range * 1.75)
    return max(0.00055, avg_body * 2.0), max(0.0010, avg_range * 2.0)


# Seuils par catégorie d'actif (Deriv / Weltrade / Forex / Metal / Crypto / Indices)
# FIX 2026-08-25 : réduction seuils pour plus de réactivité en temps réel
ASSET_VERDICT_PROFILES: Dict[str, Dict[str, float]] = {
    "forex": {
        "gap_min": 0.8, "gap_good": 1.5, "gap_perfect": 2.5,
        "filter_ratio_min": 0.35, "min_entry_quality": 0.45, "mtf_perfect_pct": 0.55,
    },
    "metal": {
        "gap_min": 0.8, "gap_good": 1.5, "gap_perfect": 2.5,
        "filter_ratio_min": 0.35, "min_entry_quality": 0.48, "mtf_perfect_pct": 0.58,
    },
    "crypto": {
        "gap_min": 0.9, "gap_good": 1.8, "gap_perfect": 2.8,
        "filter_ratio_min": 0.35, "min_entry_quality": 0.45, "mtf_perfect_pct": 0.55,
    },
    "index": {
        "gap_min": 0.85, "gap_good": 1.6, "gap_perfect": 2.5,
        "filter_ratio_min": 0.35, "min_entry_quality": 0.45, "mtf_perfect_pct": 0.55,
    },
    "volatility": {
        "gap_min": 0.6, "gap_good": 1.2, "gap_perfect": 2.0,
        "filter_ratio_min": 0.30, "min_entry_quality": 0.35, "mtf_perfect_pct": 0.45,
    },
    "boom_crash": {
        "gap_min": 0.6, "gap_good": 1.2, "gap_perfect": 2.0,
        "filter_ratio_min": 0.30, "min_entry_quality": 0.35, "mtf_perfect_pct": 0.45,
    },
    "other": {
        "gap_min": 0.8, "gap_good": 1.5, "gap_perfect": 2.5,
        "filter_ratio_min": 0.35, "min_entry_quality": 0.45, "mtf_perfect_pct": 0.55,
    },
}



# Contrat d'exécution partagé avec l'EA : une nouvelle entrée n'est permise
# qu'à partir de GOOD (|verdict_num| >= 2). BUY/SELL simples restent valides
# pour l'affichage et l'analyse, mais ne sont pas des autorisations d'entrée.
GOM_MIN_ENTRY_VERDICT_ABS = 2

# Contrat public du verdict GOM. L'échelle numérique reste symétrique :
# -3 PERFECT SELL, -2 GOOD SELL, -1 SELL SIMPLE, 0 WAIT,
# +1 BUY SIMPLE, +2 GOOD BUY, +3 PERFECT BUY.
# Le suffixe SIMPLE est volontaire : BUY/SELL seuls étaient ambigus pour les
# consommateurs (ils pouvaient être confondus avec une autorisation d'entrée).
GOM_VERDICT_LABELS = {
    3: "PERFECT BUY",
    2: "GOOD BUY",
    1: "BUY SIMPLE",
    0: "WAIT",
    -1: "SELL SIMPLE",
    -2: "GOOD SELL",
    -3: "PERFECT SELL",
}
GOM_VALID_VERDICTS = frozenset(GOM_VERDICT_LABELS.values())


def normalize_direction(value: Any) -> str:
    """Normalise toutes les représentations directionnelles vers BULL/BEAR/NEUT."""
    d = str(value or "").upper().strip()
    if d in ("BULL", "BUY", "UP", "LONG", "1"):
        return "BULL"
    if d in ("BEAR", "SELL", "DOWN", "SHORT", "-1"):
        return "BEAR"
    return "NEUT"


def m1_scalp_structure_confirmed(record: Dict[str, Any], direction: int) -> bool:
    """Require a live M1 direction plus aligned short-term price movement."""
    if direction == 0:
        return False

    m1_dir = normalize_direction(
        record.get("tf_m1_dir_live") or record.get("tf_m1_dir")
    )
    expected = "BULL" if direction > 0 else "BEAR"
    if m1_dir != expected:
        return False

    try:
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
    except (TypeError, ValueError, OverflowError):
        return False
    return d1 * direction > 0 and d3 * direction > 0


def htf_structure_sign(record: Dict[str, Any]) -> Tuple[int, int, int]:
    """Structure HTF (M5→D1, hors M1) : (sign, bulls, bears).

    FIX 2026-09-26 : la structure multi-TF ne doit PAS être invalidée par une
    micro-correction M1 seule. On compte M5/M15/H1/H4/D1 uniquement.
    """
    htf = (
        normalize_direction(record.get("tf_m5_dir")),
        normalize_direction(record.get("tf_m15_dir")),
        normalize_direction(record.get("tf_h1_dir")),
        normalize_direction(record.get("tf_h4_dir")),
        normalize_direction(record.get("tf_d1_dir")),
    )
    bulls = sum(1 for d in htf if d == "BULL")
    bears = sum(1 for d in htf if d == "BEAR")
    if bears >= 3 and bears > bulls:
        return -1, bulls, bears
    if bulls >= 3 and bulls > bears:
        return 1, bulls, bears
    return 0, bulls, bears


def is_m1_microcorrection_against(record: Dict[str, Any], structure_sign: int) -> bool:
    """True si le flux M1 court (1b/3b) va CONTRE la structure HTF, sans inversion M5."""
    if structure_sign == 0:
        return False
    try:
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
    except (TypeError, ValueError):
        d1 = d3 = 0.0
    m5 = normalize_direction(record.get("tf_m5_dir"))
    m5_with_struct = (
        (structure_sign < 0 and m5 in ("BEAR", "NEUT", ""))
        or (structure_sign > 0 and m5 in ("BULL", "NEUT", ""))
    )
    if not m5_with_struct:
        return False
    if structure_sign < 0:
        return d1 > 0 and d3 > 0
    return d1 < 0 and d3 < 0


def _strong_counter_move(record: Dict[str, Any], direction: int) -> bool:
    """Retourne True si le prix M1 contredit sérieusement le verdict avec un contre-mouvement réel.

    C'est la réalité du marché, pas un simple pullback de micro-correction.
    """
    if direction == 0:
        return False
    try:
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
    except (TypeError, ValueError):
        return False
    if direction > 0:
        return (d1 < 0 and d3 < 0 and abs(d1) >= 0.0008 and abs(d3) >= 0.0010 and (abs(d1) + abs(d3)) >= 0.0020)
    return (d1 > 0 and d3 > 0 and abs(d1) >= 0.0008 and abs(d3) >= 0.0010 and (abs(d1) + abs(d3)) >= 0.0020)


def m1_m5_trend_sign(record: Dict[str, Any]) -> int:
    """Tendance exécutable M1+M5 : +1 BULL, -1 BEAR, 0 non aligné.

    FIX 2026-09-26 : structure HTF (M5+) claire + micro-corr M1 → signe HTF.
    """
    try:
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
        d5 = float(record.get("price_direction_5b", 0) or 0)
    except (TypeError, ValueError):
        d1 = d3 = d5 = 0.0

    htf_sign, htf_bulls, htf_bears = htf_structure_sign(record)
    if htf_sign != 0 and is_m1_microcorrection_against(record, htf_sign):
        return htf_sign

    if d1 < 0 and d3 < 0:
        if htf_sign > 0 and htf_bulls >= 4:
            return 1
        return -1
    if d1 > 0 and d3 > 0:
        if htf_sign < 0 and htf_bears >= 4:
            return -1
        return 1
    m1 = normalize_direction(record.get("tf_m1_dir_live") or record.get("tf_m1_dir"))
    m5 = normalize_direction(record.get("tf_m5_dir"))
    if m1 == "BULL" and m5 == "BULL":
        return 1
    if m1 == "BEAR" and m5 == "BEAR":
        return -1
    if m5 == "BULL" and d3 > 0 and (d1 > 0 or d5 > 0 or m1 in ("BULL", "NEUT", "")):
        return 1
    if m5 == "BEAR" and d3 < 0 and (d1 < 0 or d5 < 0 or m1 in ("BEAR", "NEUT", "")):
        return -1
    if m1 in ("NEUT", "") and m5 == "BULL" and d1 > 0 and d3 > 0:
        return 1
    if m1 in ("NEUT", "") and m5 == "BEAR" and d1 < 0 and d3 < 0:
        return -1
    if htf_bulls >= 4:
        return 1
    if htf_bears >= 4:
        return -1
    return 0


# Poids des signaux dans l'autorité de flux. Le M1 et le M5 pèsent autant que
# la direction du prix court ; la 5b est la plus faible car la plus lente.
_M1M5_FLOW_WEIGHTS = (
    ("m1", 1.0),
    ("m5", 1.0),
    ("d1", 1.25),
    ("d3", 1.25),
    ("d5", 0.75),
)
_M1M5_FLOW_TOTAL = sum(w for _, w in _M1M5_FLOW_WEIGHTS)  # 5.25
_M1M5_FLOW_CLEAR = 1.75  # delta minimum pour retenir une direction de flux
_M1M5_FLOW_STRONG = 3.00  # delta au-delà duquel le flux est un mouvement franc


def _m1m5_flow_votes(record: Dict[str, Any]) -> Dict[str, int]:
    """Signaux de flux M1/M5 + prix 1b/3b/5b, chacun valant -1/0/+1."""
    try:
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
        d5 = float(record.get("price_direction_5b", 0) or 0)
    except (TypeError, ValueError):
        d1 = d3 = d5 = 0.0
    m1 = normalize_direction(record.get("tf_m1_dir_live") or record.get("tf_m1_dir"))
    m5 = normalize_direction(record.get("tf_m5_dir"))
    m1_v = 1 if m1 == "BULL" else (-1 if m1 == "BEAR" else 0)
    m5_v = 1 if m5 == "BULL" else (-1 if m5 == "BEAR" else 0)
    # EMA M1/M5 lagguée : le flux 1b+3b réel gagne.
    if d1 < 0 and d3 < 0:
        m1_v = -1
    elif d1 > 0 and d3 > 0:
        m1_v = 1
    return {
        "m1": m1_v,
        "m5": m5_v,
        "d1": 1 if d1 > 0 else (-1 if d1 < 0 else 0),
        "d3": 1 if d3 > 0 else (-1 if d3 < 0 else 0),
        "d5": 1 if d5 > 0 else (-1 if d5 < 0 else 0),
    }


def apply_m1m5_flow_authority(record: Dict[str, Any], verdict_num: int) -> int:
    """Autorité finale du verdict : M1 + M5 et le flux de prix décident.

    Appelée en DERNIER, après tous les autres gates. Aucun gate ne peut
    contredire le sens Decide ici.

    Règle (Sidoine 2026-09-25 soir) :
    - Flux NATIF (PainX dump / GainX rally) : WAIT absurde → GOOD/PERFECT.
    - Flux CONTRE famille (PainX bounce BUY, GainX dump SELL) = CORRECTION
      → WAIT, jamais d'entrée. Les 3 Soldiers M1 ne doivent plus ouvrir un
      GOOD BUY sur PainX en dump.

    Champs ecrits : m1m5_authority_reason, m1m5_flow_dir, m1m5_flow_delta,
    m1m5_flow_unanimous, m1m5_flow_decisive, contra_family_flow.
    """
    vn = int(verdict_num or 0)
    votes = _m1m5_flow_votes(record)
    buy_w = sum(w for name, w in _M1M5_FLOW_WEIGHTS if votes[name] > 0)
    sell_w = sum(w for name, w in _M1M5_FLOW_WEIGHTS if votes[name] < 0)
    delta = buy_w - sell_w
    # "decisive" = aucun signal neutre (M1 et M5 tranché + flux priced).
    # "unanimous" = ET tous ces signaux vont dans le MEME sens. Les deux
    # sont distincts : 4 haussiers + 1 baissier très court est decisive mais
    # PAS unanimous, et ne doit donc pas valoir un PERFECT.
    decisive = abs(buy_w + sell_w - _M1M5_FLOW_TOTAL) < 1e-9
    unanimous = decisive and (abs(buy_w) < 1e-9 or abs(sell_w) < 1e-9)

    record["m1m5_flow_delta"] = round(delta, 3)
    record["m1m5_flow_unanimous"] = bool(unanimous)
    record["m1m5_flow_decisive"] = bool(decisive)
    record["contra_family_flow"] = False

    if delta >= _M1M5_FLOW_CLEAR:
        flow_dir = 1
    elif delta <= -_M1M5_FLOW_CLEAR:
        flow_dir = -1
    else:
        flow_dir = 0

    record["m1m5_flow_dir"] = flow_dir

    # FIX 2026-09-26 : micro-correction M1 contre structure HTF forte
    # → le flux court ne doit PAS retourner le verdict structurel.
    htf_sign, htf_bulls, htf_bears = htf_structure_sign(record)
    micro = (
        htf_sign != 0
        and is_m1_microcorrection_against(record, htf_sign)
        and flow_dir != 0
        and flow_dir != htf_sign
    )
    if micro and (htf_bears >= 3 or htf_bulls >= 3):
        sb = float(record.get("score_buy", 0) or 0)
        ss = float(record.get("score_sell", 0) or 0)
        gap = abs(sb - ss)
        if htf_sign < 0:
            mag = 3 if (htf_bears >= 4 and (gap >= 2.5 or ss >= sb + 1.5)) else (
                2 if (htf_bears >= 3 or gap >= 1.2 or ss >= sb) else 1
            )
            target = -mag
        else:
            mag = 3 if (htf_bulls >= 4 and (gap >= 2.5 or sb >= ss + 1.5)) else (
                2 if (htf_bulls >= 3 or gap >= 1.2 or sb >= ss) else 1
            )
            target = mag
        if vn != 0 and (vn > 0) == (target > 0) and abs(vn) >= abs(target):
            target = vn
        record["m1m5_authority_reason"] = (
            f"htf_struct_{htf_sign:+d}_micro_m1_ignored "
            f"(htf_b={htf_bulls}/be={htf_bears}) keep/set_{target:+d}"
        )
        record["m1m5_flow_dir"] = htf_sign
        _settle_authority(record, target)
        return target

    if flow_dir == 0:
        # Aucun sens de marche : on ne touche a rien, y compris un WAIT.
        record["m1m5_authority_reason"] = f"flow_unclear(d={delta:+.2f})->keep_{vn}"
        return vn

    strong = unanimous or (decisive and abs(delta) >= _M1M5_FLOW_STRONG)
    sym = str(record.get("symbol", "") or "")
    native = 0
    if GOMLPineCalculator.is_boom_like_symbol(sym):
        native = 1
    elif GOMLPineCalculator.is_crash_like_symbol(sym):
        native = -1
    contra = bool(native) and flow_dir != native
    record["contra_family_flow"] = contra

    # Bounce / dump contre la famille = CORRECTION. Jamais de BUY PainX ni
    # de SELL GainX : WAIT (pas d'entrée). Le 2026-09-25 "flux gagne" ouvrait
    # GOOD BUY sur PainX pendant 3 Soldiers d'un dump (PainX 1200).
    if contra and native != 0:
        record["m1m5_authority_reason"] = (
            f"flow_{flow_dir:+d}_contra_family->WAIT (correction, pas d'entrée)"
        )
        _settle_authority(record, 0)
        return 0

    # Intensite : le flux fixe le sens, la famille plafonne la magnitude.
    # Un signal encore neutre (flux 1b plat) interdit le PERFECT : on ne monte
    # jamais en GOOD/PERFECT sur un mouvement non tranche jusqu'au bout.
    if not decisive:
        mag = 1
    elif strong:
        mag = 3
    else:
        mag = 2

    if vn == 0:
        if not strong:
            # Flux seulement partiel : on montre le sens en SIMPLE, la famille
            # (ou l'absence de decisivite) empechant toute entree. On ecrit
            # dans TOUS les cas : le gate est autorite, pas seulement quand
            # il releve un WAIT.
            target = flow_dir * (1 if (contra or not decisive) else mag)
            record["m1m5_authority_reason"] = (
                f"flow_{flow_dir:+d}_weak(d={delta:+.2f})"
                f"{'_contra_family' if contra else ''}->WAIT_lift_{target:+d}"
            )
            _settle_authority(record, target)
            return target
        target = flow_dir * mag
        record["m1m5_authority_reason"] = (
            f"flow_{flow_dir:+d}{'_unanimous' if unanimous else f'_d{delta:+.2f}'}"
            f"{'_contra_family' if contra else ''}->WAIT_lift_{target:+d}"
        )
        _settle_authority(record, target)
        return target

    if (vn > 0) == (flow_dir > 0):
        # meme sens : la famille peut plafonner, jamais retourner le sens
        if abs(vn) > mag:
            record["m1m5_authority_reason"] = (
                f"flow_{flow_dir:+d}_family_cap vn={vn:+d}->{flow_dir * mag:+d}"
            )
            _settle_authority(record, flow_dir * mag)
            return flow_dir * mag
        if abs(vn) < mag and unanimous:
            record["m1m5_authority_reason"] = (
                f"flow_{flow_dir:+d}_unanimous_upgrade vn={vn:+d}->{flow_dir * mag:+d}"
            )
            _settle_authority(record, flow_dir * mag)
            return flow_dir * mag
        # Gate d'accord avec le verdict existant : on documente quand meme la
        # decision, sinon le champ d'audit est absent du payload.
        record["m1m5_authority_reason"] = (
            f"flow_{flow_dir:+d}_confirm(d={delta:+.2f}"
            f"{'_unanimous' if unanimous else ''}"
            f"{'_contra_family' if contra else ''})_keep_{vn:+d}"
        )
        return vn

    # Sens opposes : on retourne le verdict, sauf si le flux est faible.
    if not strong:
        target = flow_dir * 1
        record["m1m5_authority_reason"] = (
            f"flow_{flow_dir:+d}_weak_flip vn={vn:+d}->{target:+d}(d={delta:+.2f})"
        )
        _settle_authority(record, target)
        return target

    target = flow_dir * mag
    record["m1m5_authority_reason"] = (
        f"flow_{flow_dir:+d}{'_unanimous' if unanimous else f'_d{delta:+.2f}'}"
        f"{'_contra_family' if contra else ''}_flip vn={vn:+d}->{target:+d}"
    )
    _settle_authority(record, target)
    return target


def _settle_authority(record: Dict[str, Any], new_vn: int) -> None:
    """Ecrit le verdict autorite ET purge les raisons de gates devenues fausses.

    Ecrit verdict_num ici (et pas seulement dans l'appelant) pour qu'un oubli
    de report ne puisse pas laisser un GOOD avec un entry_allowed=false
    incoherent.
    """
    for key in (
        "impulse_cap_reason",
        "price_reality_reason",
        "trend_align_reason",
        "m1_exec_reason",
        "correction_gate_reason",
        "entry_block_reason",
    ):
        record.pop(key, None)
    record["verdict_num"] = int(new_vn)
    record["verdict"] = verdict_text_from_num(int(new_vn))
    record["action"] = record["verdict"]
    record["entry_allowed"] = None


def apply_trend_alignment_verdict(record: Dict[str, Any], verdict_num: int) -> int:
    """Aligne le verdict GOM sur M1+M5. Interdit GOOD/PERFECT contre-tendance.

    FIX 2026-09-20 (Sidoine) : renforcement ABSOLU - si MTF est clairement uptrend
    (M1+M5+M15+H1 BULL) ou downtrend (M1+M5+M15+H1 BEAR), le verdict DOIT suivre.
    Les scores techniques ne peuvent pas surcharger la tendance structurelle.
    """
    vn = int(verdict_num or 0)
    trend = m1_m5_trend_sign(record)
    if trend == 0:
        return vn

    # Vérifier la tendance multi-timeframe complète
    m1 = normalize_direction(record.get("tf_m1_dir_live") or record.get("tf_m1_dir"))
    m5 = normalize_direction(record.get("tf_m5_dir"))
    m15 = normalize_direction(record.get("tf_m15_dir"))
    h1 = normalize_direction(record.get("tf_h1_dir"))

    live = "BULL" if trend > 0 else "BEAR"
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)
    live_dump = d1 < 0 and d3 < 0
    live_rally = d1 > 0 and d3 > 0
    if live_dump:
        record["tf_m1_dir_live"] = "BEAR"
        record["tf_m1_dir"] = "BEAR"
        record["tf_m1_dir_live_src"] = "m1m5_trend_align_dump"
    elif live_rally:
        if normalize_direction(record.get("tf_m1_dir_live")) != live:
            record["tf_m1_dir_live"] = live
            record["tf_m1_dir_live_src"] = "m1m5_trend_align"
    elif not ((trend > 0 and live_dump) or (trend < 0 and live_rally)):
        if normalize_direction(record.get("tf_m1_dir_live")) != live:
            record["tf_m1_dir_live"] = live
            record["tf_m1_dir_live_src"] = "m1m5_trend_align"

    bull_count = sum(1 for d in (m1, m5, m15, h1) if d == "BULL")
    bear_count = sum(1 for d in (m1, m5, m15, h1) if d == "BEAR")

    if bull_count >= 3:
        micro = is_m1_microcorrection_against(record, 1)
        strong_counter = _strong_counter_move(record, 1)
        if live_dump and not micro and m5 == "BEAR":
            record["trend_align_reason"] = f"MTF_BULL_{bull_count}/4_real_m5_inversion"
            if d5 < 0:
                record["tf_m5_dir"] = "BEAR"
            if vn > 0:
                return 0
            return vn
        if live_dump and micro:
            if strong_counter:
                record["trend_align_reason"] = f"MTF_BULL_{bull_count}/4_strong_dump_caps_vn={vn}"
                return 1 if vn > 0 else 0
            record["trend_align_reason"] = f"MTF_BULL_{bull_count}/4_micro_dump_keeps_vn={vn}"
            if vn > 0 and abs(vn) >= 2:
                return vn
            sb = float(record.get("score_buy", 0) or 0)
            ss = float(record.get("score_sell", 0) or 0)
            mag = 3 if sb >= ss + 2.0 else 2
            if vn <= 0 or abs(vn) < mag:
                return mag
            return vn
        if vn <= 0:
            sb = float(record.get("score_buy", 0) or 0)
            ss = float(record.get("score_sell", 0) or 0)
            mag = 3 if sb >= ss + 2.0 and live_rally and d5 >= 0 else 2
            if not live_rally and not micro:
                mag = 1
            record["trend_align_reason"] = f"MTF_BULL_{bull_count}/4_forces_SELL->BUY_{mag}"
            return mag
        if abs(vn) < 2:
            mag = 2 if (live_rally or micro) else 1
            record["trend_align_reason"] = f"MTF_BULL_{bull_count}/4_confirms_BUY_{mag}"
            return mag
        return vn

    if bear_count >= 3:
        # FIX 2026-09-26 : micro-rally M1 ne bloque plus PERFECT/GOOD SELL
        micro = is_m1_microcorrection_against(record, -1)
        strong_counter = _strong_counter_move(record, -1)
        if live_rally and not micro and m5 == "BULL":
            record["trend_align_reason"] = f"MTF_BEAR_{bear_count}/4_real_m5_inversion"
            if vn < 0:
                return -1 if abs(vn) >= 1 else 0
            return 0
        if live_rally and micro:
            if strong_counter:
                record["trend_align_reason"] = f"MTF_BEAR_{bear_count}/4_strong_rally_caps_vn={vn}"
                return -1 if vn < 0 else 0
            record["trend_align_reason"] = f"MTF_BEAR_{bear_count}/4_micro_rally_keeps_vn={vn}"
            if vn < 0 and abs(vn) >= 2:
                return vn  # keep GOOD/PERFECT
            # uplift to at least GOOD if scores support
            sb = float(record.get("score_buy", 0) or 0)
            ss = float(record.get("score_sell", 0) or 0)
            mag = 3 if ss >= sb + 2.0 else 2
            if vn >= 0 or abs(vn) < mag:
                return -mag
            return vn
        if vn >= 0:
            sb = float(record.get("score_buy", 0) or 0)
            ss = float(record.get("score_sell", 0) or 0)
            mag = 3 if ss >= sb + 2.0 and live_dump and d5 <= 0 else 2
            if not live_dump and not micro:
                mag = 1
            record["trend_align_reason"] = f"MTF_BEAR_{bear_count}/4_forces_BUY->SELL_{mag}"
            return -mag
        if abs(vn) < 2:
            mag = 2 if (live_dump or micro) else 1
            record["trend_align_reason"] = f"MTF_BEAR_{bear_count}/4_confirms_SELL_{mag}"
            return -mag
        return vn

    # Si MTF moins clair (2/2 ou 3/1), utiliser l'ancienne logique
    if vn != 0 and (vn * trend) > 0:
        return vn

    sb = float(record.get("score_buy", 0) or 0)
    ss = float(record.get("score_sell", 0) or 0)
    dow = resolve_dow_direction(record)
    score_with_trend = (trend > 0 and sb >= ss - 0.5) or (trend < 0 and ss >= sb - 0.5)
    dow_with_trend = (trend > 0 and dow == "BULL") or (trend < 0 and dow == "BEAR")

    if vn == 0 or (vn * trend) < 0:
        live_against = (trend > 0 and d1 < 0 and d3 < 0) or (trend < 0 and d1 > 0 and d3 > 0)
        if live_against:
            record["trend_align_reason"] = (
                f"m1m5_{'BULL' if trend > 0 else 'BEAR'}_blocked_m1_against_vn={vn}"
            )
            return 0
        if score_with_trend or dow_with_trend:
            mag = 2 if (abs(vn) >= 2 or score_with_trend) else 1
            if abs(sb - ss) >= 4.0 and score_with_trend:
                mag = max(mag, 3)
            record["trend_align_reason"] = (
                f"m1m5_{'BULL' if trend > 0 else 'BEAR'}_flips_vn={vn}->{trend * mag}"
            )
            return trend * mag
        record["trend_align_reason"] = (
            f"m1m5_{'BULL' if trend > 0 else 'BEAR'}_blocks_counter_vn={vn}"
        )
        return 0
    return vn


def _is_strong_downtrend_context(record: Dict[str, Any]) -> bool:
    """Vérifie si contexte long-term est un downtrend fort (D1+H4 BEAR)."""
    d1_dir = str(record.get("tf_d1_dir", "") or "").upper()
    h4_dir = str(record.get("tf_h4_dir", "") or "").upper()
    is_d1_bear = d1_dir in ("BEAR", "SELL", "DOWN")
    is_h4_bear = h4_dir in ("BEAR", "SELL", "DOWN")
    return is_d1_bear and is_h4_bear


def _is_strong_uptrend_context(record: Dict[str, Any]) -> bool:
    """Vérifie si contexte long-term est un uptrend fort (D1+H4 BULL)."""
    d1_dir = str(record.get("tf_d1_dir", "") or "").upper()
    h4_dir = str(record.get("tf_h4_dir", "") or "").upper()
    is_d1_bull = d1_dir in ("BULL", "BUY", "UP")
    is_h4_bull = h4_dir in ("BULL", "BUY", "UP")
    return is_d1_bull and is_h4_bull


def apply_score_direction_authority(record: Dict[str, Any], verdict_num: int) -> int:
    """Le score dominant décide le SENS, avec gate long-term D1/H4.

    FIX 2026-09-21 : le score ne peut plus forcer GOOD/PERFECT contre le
    flux M1 1b+3b (figures 3 Soldiers / RSI lag après un dump PainX).

    FIX 2026-09-22 (Session Debug): Ne pas flipper contre D1/H4 downtrend
    ou uptrend fort. Cas PainX 999: score_buy=8.5 > score_sell=3.2 ne doit
    plus forcer PERFECT BUY si D1=BEAR (marché en downtrend).
    """
    vn = int(verdict_num or 0)
    sb = float(record.get("score_buy", 0) or 0)
    ss = float(record.get("score_sell", 0) or 0)
    _sym_sc = str(record.get("symbol", "") or "")
    if GOMLPineCalculator.is_boom_like_symbol(_sym_sc) and ss > sb:
        record["score_dir_reason"] = "GainX/Boom — scores SELL ignorés (famille BUY)"
        return 0 if vn < 0 else vn
    if GOMLPineCalculator.is_crash_like_symbol(_sym_sc) and sb > ss:
        record["score_dir_reason"] = "PainX/Crash — scores BUY ignorés (famille SELL)"
        return 0 if vn > 0 else vn
    gap = abs(sb - ss)
    if gap < 1.2:
        return vn
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)

    d1_dir = str(record.get("tf_d1_dir", "") or "").upper()
    h4_dir = str(record.get("tf_h4_dir", "") or "").upper()
    d1_is_bear = d1_dir in ("BEAR", "SELL", "DOWN")
    h4_is_bear = h4_dir in ("BEAR", "SELL", "DOWN")
    d1_is_bull = d1_dir in ("BULL", "BUY", "UP")
    h4_is_bull = h4_dir in ("BULL", "BUY", "UP")
    is_strong_downtrend = _is_strong_downtrend_context(record)
    is_strong_uptrend = _is_strong_uptrend_context(record)

    def _cap_mag(sign: int, mag: int) -> int:
        if sign > 0 and d1 < 0 and d3 < 0:
            return 0 if d5 < 0 else 1
        if sign < 0 and d1 > 0 and d3 > 0:
            return 0 if d5 > 0 else 1
        if sign > 0 and d5 < 0 and d1 > 0:
            return min(mag, 1)
        if sign < 0 and d5 > 0 and d1 < 0:
            return min(mag, 1)
        return mag

    # BUY: score_buy > score_sell
    if sb > ss:
        if _strong_counter_move(record, 1):
            record["score_dir_reason"] = f"strong_counter_move_buy_{sb:.1f}>{ss:.1f}_caps_to_SIMPLE"
            return 1
        # ★ FIX 2026-09-22: Si D1 BEAR (long-term downtrend), limiter le flip
        if d1_is_bear and vn <= 0:
            record["score_dir_reason"] = f"scores_BUY_{sb:.1f}>{ss:.1f}_but_D1_BEAR_cap"
            return 1 if gap >= 2.5 else 0
        # ★ FIX: Si H4 BEAR fort et vn << 0, très prudent
        if h4_is_bear and vn < -2 and gap >= 4.0:
            record["score_dir_reason"] = f"scores_BUY_gap_{gap:.1f}_but_H4_BEAR_vn={vn}_cap"
            return 1
        if is_strong_downtrend and vn <= 0:
            record["score_dir_reason"] = f"scores_BUY_{sb:.1f}>{ss:.1f}_but_D1H4_BEAR_cap"
            return 1 if gap >= 2.5 else 0

        candidate_mag = 3 if gap >= 4.0 else (2 if gap >= 2.5 else 1)
        mag = _cap_mag(1, candidate_mag)
        if mag == 0:
            record["score_dir_reason"] = f"scores_BUY_{sb:.1f}>{ss:.1f}_capped_m1_dump->WAIT"
            return 0
        if vn <= 0:
            record["score_dir_reason"] = f"scores_BUY_{sb:.1f}>{ss:.1f}_vn={vn}->{mag}"
            return mag
        if abs(vn) < mag:
            record["score_dir_reason"] = f"scores_BUY_uplift_{sb:.1f}>{ss:.1f}_vn={vn}->{mag}"
            return mag
        return vn

    # SELL: score_sell > score_buy (symétrique)
    else:
        if _strong_counter_move(record, -1):
            record["score_dir_reason"] = f"strong_counter_move_sell_{ss:.1f}>{sb:.1f}_caps_to_SIMPLE"
            return -1
        # ★ FIX 2026-09-22: Si D1 BULL, limiter le flip SELL
        if d1_is_bull and vn >= 0:
            record["score_dir_reason"] = f"scores_SELL_{ss:.1f}>{sb:.1f}_but_D1_BULL_cap"
            return -1 if gap >= 2.5 else 0
        if h4_is_bull and vn > 2 and gap >= 4.0:
            record["score_dir_reason"] = f"scores_SELL_gap_{gap:.1f}_but_H4_BULL_vn={vn}_cap"
            return -1
        if is_strong_uptrend and vn >= 0:
            record["score_dir_reason"] = f"scores_SELL_{ss:.1f}>{sb:.1f}_but_D1H4_BULL_cap"
            return -1 if gap >= 2.5 else 0

        candidate_mag = 3 if gap >= 4.0 else (2 if gap >= 2.5 else 1)
        mag = _cap_mag(-1, candidate_mag)
        if mag == 0:
            record["score_dir_reason"] = f"scores_SELL_{ss:.1f}>{sb:.1f}_capped_m1_rally->WAIT"
            return 0
        if vn >= 0:
            record["score_dir_reason"] = f"scores_SELL_{ss:.1f}>{sb:.1f}_vn={vn}->{-mag}"
            return -mag
        if abs(vn) < mag:
            record["score_dir_reason"] = f"scores_SELL_uplift_{ss:.1f}>{sb:.1f}_vn={vn}->{-mag}"
            return -mag
        return vn


def apply_price_impulse_cap(record: Dict[str, Any], verdict_num: int) -> int:
    """Plafonne GOOD/PERFECT si le flux M1 n'est pas un mouvement franc.

    FIX 2026-09-21 (PainX 1200 live) : après BOS / dump, un rebond 3 Soldiers
    + scores laggués produisait PERFECT BUY alors que l'IA était déjà HOLD.

    FIX 2026-09-22 (Session Debug): Distingue pullback temporaire vs vrai
    renversement via profondeur du pullback (swing high/low). Un pullback
    < 30% ne coupe plus le verdict en WAIT — reste SIMPLE.
    """
    vn = int(verdict_num or 0)
    if vn == 0:
        return 0
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)
    sign = 1 if vn > 0 else -1
    mag = abs(vn)

    against_13 = (sign > 0 and d1 < 0 and d3 < 0) or (sign < 0 and d1 > 0 and d3 > 0)
    against_5 = (sign > 0 and d5 < 0) or (sign < 0 and d5 > 0)
    bounce = (sign > 0 and d1 > 0 and d5 < 0) or (sign < 0 and d1 < 0 and d5 > 0)
    bos_fail_buy = sign > 0 and bool(record.get("bos_bear")) and (d3 < 0 or d5 < 0)
    bos_fail_sell = sign < 0 and bool(record.get("bos_bull")) and (d3 > 0 or d5 > 0)

    # ★ FIX 2026-09-22: Analyser profondeur pullback avant de couper
    try:
        swing_high = float(record.get("last_swing_high", 0) or 0)
        swing_low = float(record.get("last_swing_low", 0) or 0)
        close = float(record.get("close", 0) or 0)

        if swing_high > swing_low > 0 and close > 0:
            range_pips = swing_high - swing_low

            if sign > 0:  # BUY verdict
                pullback_depth = (swing_high - close) / range_pips
                if against_13:
                    if pullback_depth < 0.3:
                        record["impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_minor->SIMPLE"
                        return sign
                    elif pullback_depth < 0.6:
                        record["impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_moderate->SIMPLE"
                        return sign
                    else:
                        record["impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_strong->WAIT"
                        return 0
            else:  # SELL verdict
                pullback_depth = (close - swing_low) / range_pips
                if against_13:
                    if pullback_depth < 0.3:
                        record["impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_minor->SIMPLE"
                        return sign
                    elif pullback_depth < 0.6:
                        record["impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_moderate->SIMPLE"
                        return sign
                    else:
                        record["impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_strong->WAIT"
                        return 0
    except (TypeError, ValueError, ZeroDivisionError):
        pass

    # FIX 2026-09-26 : structure HTF alignée → micro-corr M1 conserve le verdict
    # MAIS : si la contre-impulsion M1 est suffisamment profonde, c'est la réalité du marché,
    # pas un simple pullback. On coupe le verdict au WAIT même si HTF reste aligné sur le sens.
    htf_s, hb, hbe = htf_structure_sign(record)
    htf_supports = (sign < 0 and htf_s < 0 and hbe >= 3) or (sign > 0 and htf_s > 0 and hb >= 3)
    micro = is_m1_microcorrection_against(record, sign)
    strong_counter_move = (
        against_13
        and abs(d1) >= 0.0008
        and abs(d3) >= 0.0010
        and (abs(d1) + abs(d3)) >= 0.0020
    )

    if htf_supports and micro and not strong_counter_move:
        record["impulse_cap_reason"] = f"htf_struct_{htf_s:+d}_micro_m1_keeps_vn={vn:+d}"
        return vn
    if strong_counter_move:
        record["impulse_cap_reason"] = (
            f"strong_m1_counter_{abs(d1):.4f}/{abs(d3):.4f}->{'BUY' if sign > 0 else 'SELL'}->WAIT"
        )
        return 0

    # Fallback: logique originale si calcul pullback échoue
    if against_13 and against_5:
        if htf_supports:
            record["impulse_cap_reason"] = "m1_1b3b5b_against_but_htf->keep"
            return vn if mag <= 2 else sign * 2
        record["impulse_cap_reason"] = "m1_1b3b5b_against->WAIT"
        return 0
    if against_13:
        if htf_supports:
            record["impulse_cap_reason"] = "m1_1b3b_against_but_htf_keeps"
            return vn
        record["impulse_cap_reason"] = "m1_1b3b_against->SIMPLE"
        return sign
    if bounce and mag >= 2:
        # Pullback M1 : garder GOOD/PERFECT (verdict 5m), ne plus rétrograder.
        record["impulse_cap_reason"] = "m1_bounce_vs_5b->keep"
        return vn
    if (bos_fail_buy or bos_fail_sell) and mag >= 2:
        record["impulse_cap_reason"] = "bos_failed_continuation->SIMPLE"
        return sign
    if mag >= 3 and not ((sign > 0 and d1 >= 0 and d3 >= 0) or (sign < 0 and d1 <= 0 and d3 <= 0)):
        if htf_supports and micro:
            record["impulse_cap_reason"] = "perfect_htf_micro_keeps_PERFECT"
            return vn
        record["impulse_cap_reason"] = "perfect_needs_1b3b_aligned->GOOD"
        return sign * 2
    return vn


def apply_execution_quality_contract(record: Dict[str, Any]) -> None:
    """Contrat d'exécution : GOOD/PERFECT n'autorise l'entrée que si le flux M1
    est franc. Le verdict affiché peut rester GOOD ; entry_allowed=false bloque l'EA.

    FIX 2026-09-21 : PERFECT BUY pendant dump/rebond PainX 1200 (IA HOLD) était
    encore exécutable via le bypass PERFECT de SMCGP_GOMAllowsDirectionEx.
    """
    vn = int(record.get("verdict_num", 0) or 0)
    min_abs = int(record.get("min_entry_verdict_abs", GOM_MIN_ENTRY_VERDICT_ABS) or 2)
    reasons: list = []
    simple_scalp_confirmed = (
        abs(vn) == 1 and m1_scalp_structure_confirmed(record, vn)
    )
    record["m1_scalp_simple_allowed"] = simple_scalp_confirmed
    allowed = abs(vn) >= min_abs or simple_scalp_confirmed

    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)
    sign = 1 if vn > 0 else (-1 if vn < 0 else 0)
    against_13 = sign != 0 and (
        (sign > 0 and d1 < 0 and d3 < 0) or (sign < 0 and d1 > 0 and d3 > 0)
    )
    bounce = sign != 0 and (
        (sign > 0 and d1 > 0 and d5 < 0) or (sign < 0 and d1 < 0 and d5 > 0)
    )
    cap = str(record.get("impulse_cap_reason") or "")
    if against_13:
        allowed = False
        reasons.append("m1_1b3b_against")
    if bounce:
        allowed = False
        reasons.append("m1_bounce_vs_5b")
    if cap and ("WAIT" in cap or "SIMPLE" in cap or "bounce" in cap or "against" in cap):
        allowed = False
        reasons.append(cap)
    stage = str(record.get("correction_stage") or "").lower()
    corr_done = stage in ("ending", "finished") or bool(record.get("correction_entry_safe", True)) and stage in ("none", "")
    if bool(record.get("pa_in_correction")) and abs(vn) < 3 and not corr_done:
        allowed = False
        reasons.append("pa_in_correction")
    if (bool(record.get("range_wait_forced")) or bool(record.get("correction_blocked"))) and not corr_done:
        allowed = False
        reasons.append("range_or_correction")
    # Fin micro-corr + |vn|>=2 → entry autorisée, mais jamais si un gate d'impulsion
    # a déjà réduit le verdict à SIMPLE / WAIT.
    impulse_block = bool(cap and ("WAIT" in cap or "SIMPLE" in cap or "bounce" in cap or "against" in cap))
    if corr_done and abs(vn) >= 2:
        allowed = True
        reasons = [r for r in reasons if r not in ("pa_in_correction", "range_or_correction", "m1_1b3b_against", "m1_bounce_vs_5b")]
        record["entry_block_reason"] = ""
        if impulse_block:
            allowed = False
            reasons.append(cap)
    if abs(vn) < min_abs and not simple_scalp_confirmed:
        allowed = False
        reasons.append(f"|vn|={abs(vn)}<{min_abs}")

    record["entry_allowed"] = bool(allowed)
    if allowed:
        record.pop("entry_block_reason", None)
    else:
        record["entry_block_reason"] = ";".join(reasons) if reasons else "entry_quality"


def resolve_dow_direction(record: Dict[str, Any]) -> str:
    """Direction de la trendline Dow : BULL / BEAR / NEUT.

    Priorité : champ explicite EA/live (dow_direction, pente, is_bearish),
    puis structure (BOS + prix M1). Sans ça le GOM ignore la ligne Dow
    visible sur le graphique et conserve un BUY historique.
    """
    for key in ("dow_direction", "dow_trend", "dow_dir"):
        raw = record.get(key)
        if raw is not None and str(raw).strip() != "":
            d = normalize_direction(raw)
            if d != "NEUT":
                return d
    if record.get("dow_is_bearish") is True or record.get("dow_bearish") is True:
        return "BEAR"
    if record.get("dow_is_bullish") is True or record.get("dow_bullish") is True:
        return "BULL"
    try:
        slope = float(record.get("dow_slope", 0) or 0)
    except (TypeError, ValueError):
        slope = 0.0
    if slope < 0:
        return "BEAR"
    if slope > 0:
        return "BULL"

    bos_bear = bool(record.get("bos_bear"))
    bos_bull = bool(record.get("bos_bull"))
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)
    st = int(record.get("st_dir", 0) or 0)
    if bos_bear and (d3 < 0 or d5 < 0 or st < 0):
        return "BEAR"
    if bos_bull and (d3 > 0 or d5 > 0 or st > 0):
        return "BULL"
    try:
        sell_bars = int(record.get("m1_consec_sell_bars", 0) or 0)
        buy_bars = int(record.get("m1_consec_buy_bars", 0) or 0)
    except (TypeError, ValueError):
        sell_bars = buy_bars = 0
    if sell_bars >= 3 and d3 < 0 and d5 < 0:
        return "BEAR"
    if buy_bars >= 3 and d3 > 0 and d5 > 0:
        return "BULL"
    return "NEUT"


def apply_dow_gate(record: Dict[str, Any], verdict_num: int) -> int:
    """Empêche GOOD BUY / GOOD SELL contre la ligne Dow et le flux prix.

    FIX 2026-09-18 : le GOM conservait un BUY 100% héritant RSI/EMA/VWAP
    alors que la trendline Dow et la structure étaient déjà SELL.

    FIX 2026-09-20 (Sidoine) : renforcement ABSOLU - même si prix en correction,
    si Dow est haussière → interdiction SELL GOOD/PERFECT. Si Dow est baissière
    → interdiction BUY GOOD/PERFECT. Le Dow est la vérité structurelle.
    """
    vn = int(verdict_num or 0)
    dow = resolve_dow_direction(record)
    m1 = normalize_direction(record.get("tf_m1_dir_live") or record.get("tf_m1_dir"))
    h1 = normalize_direction(record.get("tf_h1_dir"))
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)
    price_sell = d1 < 0 and d3 < 0 and d5 <= 0
    price_buy = d1 > 0 and d3 > 0 and d5 >= 0
    m1_sell = m1 == "BEAR" or price_sell
    m1_buy = m1 == "BULL" or price_buy
    h1_sell = h1 == "BEAR" or (bool(record.get("bos_bear")) and price_sell)
    h1_buy = h1 == "BULL" or (bool(record.get("bos_bull")) and price_buy)

    # RÈGLE ABSOLUE: Dow BULL interdit SELL GOOD/PERFECT (même correction buy)
    if dow == "BULL":
        if vn <= -2:  # GOOD SELL ou PERFECT SELL
            record["dow_gate_reason"] = "dow_BULL_ABSOLUTE_blocks_GOOD_SELL_perfect"
            return 0
        if vn < 0:  # SELL simple
            record["dow_gate_reason"] = "dow_BULL_flips_SELL_simple"
            return 1
        # Si M1 et H1 alignés BUY → confirmer BUY
        if m1_buy and h1_buy and (vn == 0 or vn > 0):
            if abs(vn) < 2:
                record["dow_gate_reason"] = "dow_BULL_m1h1_confirms_BUY"
                return 2 if abs(vn) >= 2 or vn == 0 else 1
        return vn

    # RÈGLE ABSOLUE: Dow BEAR interdit BUY GOOD/PERFECT (même correction sell)
    if dow == "BEAR":
        if vn >= 2:  # GOOD BUY ou PERFECT BUY
            record["dow_gate_reason"] = "dow_BEAR_ABSOLUTE_blocks_GOOD_BUY_perfect"
            return 0
        if vn > 0:  # BUY simple
            record["dow_gate_reason"] = "dow_BEAR_flips_BUY_simple"
            return -1
        # Si M1 et H1 alignés SELL → confirmer SELL
        if m1_sell and h1_sell and (vn == 0 or vn < 0):
            if abs(vn) < 2:
                record["dow_gate_reason"] = "dow_BEAR_m1h1_confirms_SELL"
                return -2 if abs(vn) >= 2 or vn == 0 else -1
        return vn

    # Dow NEUT: pas de blocage structurel
    return vn


def apply_m1_execution_gate(record: Dict[str, Any], verdict_num: int) -> int:
    """Autorise un verdict exécutable uniquement si le M1 ne contredit pas le sens.

    FIX 2026-09-04: M1 NEUT (sign=0) ne force plus WAIT. Seule une opposition
    active (M1 BEAR vs BUY, ou M1 BULL vs SELL) bloque l'exécution.
    Sur Boom/GainX (natif BUY) et Crash/PainX (natif SELL), un momentum M1
    neutre pendant une consolidation courte ne doit pas effacer GOOD/PERFECT.
    """
    vn = int(verdict_num or 0)
    if vn == 0:
        return 0

    m1_value = record.get("tf_m1_dir_live") or record.get("tf_m1_dir")
    m1_dir = normalize_direction(m1_value)
    m1_sign = 1 if m1_dir == "BULL" else (-1 if m1_dir == "BEAR" else 0)
    verdict_sign = 1 if vn > 0 else -1
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    native_with_verdict = (verdict_sign < 0 and d1 < 0 and d3 < 0) or (
        verdict_sign > 0 and d1 > 0 and d3 > 0
    )
    # Opposition active uniquement (NEUT = laisser passer).
    # Label M1 figé (ex. BULL pendant dump PainX) ne doit pas tuer le flux 1b+3b.
    if m1_sign != 0 and m1_sign != verdict_sign and not native_with_verdict:
        return 0

    momentum = record.get("m1_momentum")
    if momentum is not None:
        try:
            mom = float(momentum)
        except (TypeError, ValueError):
            mom = 0.0
        # Seuil mort: micro-bruit autour de 0 n'est pas une opposition
        if abs(mom) >= 0.00015:
            momentum_sign = 1 if mom > 0 else -1
            if momentum_sign != verdict_sign and not native_with_verdict:
                return 0

    # FIX 2026-09-07: GOOD/PERFECT exigent une impulsion réelle M1. Sur prix
    # plat (M1 NEUT + momentum nul + pas de spike récent), rétrograder vers
    # SIMPLE (sens conservé) — jamais WAIT, jamais GOOD/PERFECT figé.
    #
    # FIX 2026-09-15 : ce garde-fou "prix plat" est réservé aux synthétiques
    # Boom/Crash/PainX/GainX/Vol où il protège d'un spike figé. Pour les actifs
    # non synthétiques (forex/métaux/indices/crypto, y compris les paires .C du
    # compte CENT Weltrade), un M1 neutre n'est qu'une consolidation : il ne doit
    # PAS rétrograder GOOD/PERFECT → SIMPLE. Sans cette exception, aucune paire
    # .C n'atteint jamais |vn| >= 2, donc `entry_allowed` reste toujours False et
    # le compte CENT n'exécute jamais le moindre ordre.
    _cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
    if _cat not in ("boom_crash", "volatility") and m1_sign == 0 and abs(vn) >= 2:
        return vn
    if m1_sign == 0 and abs(vn) >= 2:
        try:
            _strong = _strong_move_threshold(record)
        except Exception:
            _strong = 0.00035
        _bars = int(record.get("bars_since_spike", record.get("m1_bars_since_spike", -1)) or -1)
        _spike = (
            (0 <= _bars <= 8)
            or bool(record.get("spike_tradable"))
            or float(record.get("spike_prob", 0) or 0) >= 0.55
        )
        _mom = float(record.get("m1_momentum", 0) or 0)
        _flat = abs(_mom) < _strong * 0.45
        if _flat and not _spike:
            return verdict_sign

    # FIX 2026-09-18 / 2026-09-22 : GOOD/PERFECT (et tout vn exécutable)
    # ne survit pas à 1b+3b déjà dans l'autre sens.
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    # FIX 2026-09-26f : fin de micro-corr → ne pas WAIT
    stage = str(record.get("correction_stage") or "").lower()
    if stage in ("ending", "finished"):
        record["m1_exec_reason"] = f"stage={stage}_keep_vn"
        return vn
    if vn > 0 and d1 < 0 and d3 < 0:
        # dump encore actif : SIMPLE, pas WAIT
        record["m1_exec_reason"] = "m1_1b+3b_dump_vs_BUY->SIMPLE"
        return 1
    if vn < 0 and d1 > 0 and d3 > 0:
        record["m1_exec_reason"] = "m1_1b+3b_rally_vs_SELL->SIMPLE"
        return -1
    return vn


def apply_correction_gate(record: Dict[str, Any], verdict_num: int) -> int:
    """Détecte les corrections et abaisse GOOD/PERFECT vers SIMPLE.

    FIX 2026-09-20 (Sidoine) : En pleine correction, le verdict GOM ne peut
    pas rester GOOD. Le prix qui recule contre la tendance structurelle doit
    abaisser le verdict pour éviter les entrées en correction.

    FIX 2026-09-26 : utilise correction_stage (started/mid/ending/finished)
    — started/mid → downgrade ; ending/finished/none → conserve GOOD/PERFECT.
    """
    vn = int(verdict_num or 0)
    if abs(vn) < 2:  # Pas GOOD/PERFECT, rien à faire
        return vn

    stage = str(record.get("correction_stage") or record.get("tf_corr_stage") or "").lower()
    entry_safe = bool(record.get("correction_entry_safe", record.get("corr_entry_safe", True)))
    # FIX 2026-09-26f : fin de micro-correction → conserver GOOD/PERFECT, JAMAIS WAIT
    if stage in ("ending", "finished") or (entry_safe and stage in ("none", "")):
        record["correction_gate_reason"] = f"stage={stage or 'none'}_keep_vn={vn:+d}"
        return vn
    if stage in ("started", "mid"):
        verdict_sign = 1 if vn > 0 else -1
        depth = float(record.get("correction_depth_pct", 0) or 0)
        # mid : SIMPLE seulement (pas WAIT) — l'entrée Unified gère le timing
        if stage == "mid" and depth >= 60:
            record["correction_gate_reason"] = f"stage=mid_depth={depth:.0f}->SIMPLE"
            return verdict_sign
        record["correction_gate_reason"] = f"stage={stage}_depth={depth:.0f}->SIMPLE"
        return verdict_sign

    verdict_sign = 1 if vn > 0 else -1
    
    # M1 vs M5 opposés : SIMPLE seulement si encore en correction active
    m1 = normalize_direction(record.get("tf_m1_dir_live") or record.get("tf_m1_dir"))
    m5 = normalize_direction(record.get("tf_m5_dir"))
    
    m1_sign = 1 if m1 == "BULL" else (-1 if m1 == "BEAR" else 0)
    m5_sign = 1 if m5 == "BULL" else (-1 if m5 == "BEAR" else 0)
    
    if m1_sign != 0 and m5_sign != 0 and m1_sign != m5_sign:
        # Si HTF structure = sens du verdict → micro-corr, garder |vn|>=2
        from_htf = False
        try:
            hs, hb, hbe = htf_structure_sign(record)
            if (vn > 0 and hs > 0) or (vn < 0 and hs < 0):
                from_htf = True
        except Exception:
            pass
        if from_htf:
            record["correction_gate_reason"] = f"M1={m1} M5={m5}_but_htf_keeps_GOOD"
            return verdict_sign * max(2, min(abs(vn), 3))
        record["correction_gate_reason"] = f"M1={m1} M5={m5} opposite_direction_correction"
        return verdict_sign  # SIMPLE
    
    # Vérifier le momentum M1 contre la tendance
    momentum = record.get("m1_momentum")
    if momentum is not None:
        try:
            mom = float(momentum)
        except (TypeError, ValueError):
            mom = 0.0
        
        # Si momentum significatif contre le verdict → correction
        if abs(mom) >= 0.0002:
            momentum_sign = 1 if mom > 0 else -1
            if momentum_sign != verdict_sign:
                # Vérifier si c'est une vraie correction (pas juste bruit)
                # en regardant les directions 1b, 3b, 5b
                d1 = float(record.get("price_direction_1b", 0) or 0)
                d3 = float(record.get("price_direction_3b", 0) or 0)
                d5 = float(record.get("price_direction_5b", 0) or 0)
                
                # Dump/rally contre verdict : SIMPLE, pas WAIT si HTF aligné
                # (fin de micro-corr déjà gérée plus haut par stage finished)
                if verdict_sign > 0 and d1 < 0 and d3 < 0:
                    record["correction_gate_reason"] = "dump_vs_BUY->SIMPLE"
                    return 1
                if verdict_sign < 0 and d1 > 0 and d3 > 0:
                    record["correction_gate_reason"] = "rally_vs_SELL->SIMPLE"
                    return -1
    
    # Vérifier si le prix est en pullback après un mouvement fort
    # (détecté par un écart entre prix actuel et dernier swing)
    try:
        last_swing_high = float(record.get("last_swing_high", 0) or 0)
        last_swing_low = float(record.get("last_swing_low", 0) or 0)
        current_price = float(record.get("close", 0) or 0)
        
        if last_swing_high > 0 and last_swing_low > 0 and current_price > 0:
            # Pour BUY : si prix proche de last_swing_low après avoir touché last_swing_high
            if verdict_sign > 0:
                pullback_depth = (last_swing_high - current_price) / (last_swing_high - last_swing_low)
                if pullback_depth > 0.5:  # Pullback > 50% du range
                    record["correction_gate_reason"] = "pullback_correction"
                    return verdict_sign  # SIMPLE
            # Pour SELL : si prix proche de last_swing_high après avoir touché last_swing_low
            elif verdict_sign < 0:
                pullback_depth = (current_price - last_swing_low) / (last_swing_high - last_swing_low)
                if pullback_depth > 0.5:  # Pullback > 50% du range
                    record["correction_gate_reason"] = "pullback_correction"
                    return verdict_sign  # SIMPLE
    except (TypeError, ValueError):
        pass
    
    return vn


def predict_spike_setup(record: Dict[str, Any]) -> Dict[str, Any]:
    """Estime la probabilité d'un spike imminent sur un synthétique.

    Ce n'est pas une promesse de prédiction parfaite : le score est une
    confluence déterministe, anti-repaint, fondée uniquement sur les données
    présentes dans ``record``. Il combine direction native, MTF, momentum M1,
    compression, indicateurs techniques, figure/structure, verdict GOM et
    signaux de spike déjà observés. La décision d'exécution reste séparée via
    ``spike_prediction_ready`` et le gate GOOD/PERFECT.
    """
    symbol = str(record.get("symbol", "") or "")
    sym = symbol.lower().replace(" ", "")

    def direction(key: str) -> int:
        val = str(record.get(key, "") or "").upper()
        if val in ("BULL", "BUY", "UP", "LONG", "1"):
            return 1
        if val in ("BEAR", "SELL", "DOWN", "SHORT", "-1"):
            return -1
        return 0

    def number(key: str, default: float = 0.0) -> float:
        try:
            return float(record.get(key, default) or default)
        except (TypeError, ValueError):
            return default

    is_boom = GOMLPineCalculator.is_boom_like_symbol(sym)
    is_crash = GOMLPineCalculator.is_crash_like_symbol(sym)
    is_volatility = any(x in sym for x in (
        "fxvol", "sfvvol", "sfxvol", "flipx", "switchx", "plusx",
        "fibox", "quadx", "volatility", "vol", "step", "rangex",
    ))
    if not (is_boom or is_crash or is_volatility):
        return {
            "spike_prediction_direction": "NEUTRAL",
            "spike_prediction_confidence": 0.0,
            "spike_prediction_pct": 0.0,
            "spike_prediction_ready": False,
            "spike_prediction_horizon_bars": 0,
            "spike_prediction_reasons": "non_synthetic",
        }

    if is_boom:
        native = 1
    elif is_crash:
        native = -1
    else:
        # Volatilités bidirectionnelles : la direction candidate vient du
        # verdict GOM, puis des scores/du M1 si le verdict est neutre.
        try:
            native = 1 if int(record.get("verdict_num", 0) or 0) > 0 else (
                -1 if int(record.get("verdict_num", 0) or 0) < 0 else 0
            )
        except (TypeError, ValueError):
            native = 0
        if native == 0:
            delta = number("score_buy") - number("score_sell")
            native = 1 if delta > 0.15 else (-1 if delta < -0.15 else 0)
        if native == 0:
            native = direction("tf_m1_dir_live") or direction("tf_m1_dir")
        if native == 0:
            return {
                "spike_prediction_direction": "NEUTRAL",
                "spike_prediction_confidence": 0.0,
                "spike_prediction_pct": 0.0,
                "spike_prediction_ready": False,
                "spike_prediction_horizon_bars": 0,
                "spike_prediction_reasons": "volatility_direction_unclear",
            }
    reasons = []
    score = 0.0

    # 1. Direction multi-timeframe : contexte + déclencheur (30 points).
    tf_weights = {
        "tf_m1_dir": 6.0, "tf_m5_dir": 8.0, "tf_m15_dir": 7.0,
        "tf_h1_dir": 4.0, "tf_h4_dir": 3.0, "tf_d1_dir": 1.0,
        "tf_global_dir": 1.0,
    }
    aligned = 0
    opposed = 0
    for key, weight in tf_weights.items():
        d = direction(key)
        if d == native:
            score += weight
            aligned += 1
        elif d == -native:
            opposed += 1
    if aligned >= 5:
        reasons.append(f"MTF_{aligned}/{len(tf_weights)}")
    elif aligned >= 3:
        reasons.append(f"MTF_partiel_{aligned}/{len(tf_weights)}")

    # 2. Momentum M1 réel, sans utiliser la bougie en formation (18 points).
    mom = number("m1_momentum", number("price_direction_5b", 0.0))
    d3 = number("price_direction_3b", 0.0)
    momentum_sign = 1 if (mom > 0.00012 or d3 > 0.00010) else (-1 if (mom < -0.00012 or d3 < -0.00010) else 0)
    if momentum_sign == native:
        score += 12.0
        reasons.append("momentum_M1_aligne")
        if abs(mom) > 0.00035 or abs(d3) > 0.00030:
            score += 6.0
            reasons.append("acceleration_M1")
    elif momentum_sign == -native:
        score -= 10.0
        reasons.append("momentum_M1_oppose")

    # 3. Compression/volatilité : compression + direction = énergie potentielle.
    compression = bool(record.get("bb_squeeze")) or number("volatility_compression", 1.0) < 0.70
    if compression:
        score += 8.0
        reasons.append("compression")
    if bool(record.get("volume_spike")) or number("volume_ratio", 0.0) >= 1.35:
        score += 4.0
        reasons.append("volume_confirmation")

    # 4. Indicateurs techniques concordants (18 points).
    tech_votes = 0
    if direction("tf_m1_dir_live") == native:
        tech_votes += 1
    if (number("st_dir") > 0) == (native > 0) and number("st_dir") != 0:
        tech_votes += 1
    if number("macd_line") != number("macd_sig") and ((number("macd_line") > number("macd_sig")) == (native > 0)):
        tech_votes += 1
    vwap_dist = number("vwap_dist_pct")
    if vwap_dist != 0 and ((vwap_dist > 0) == (native > 0)):
        tech_votes += 1
    rsi = number("rsi14", number("tf_m1_rsi", 50.0))
    rsi_ok = (native > 0 and 50.0 <= rsi <= 75.0) or (native < 0 and 25.0 <= rsi <= 50.0)
    if rsi_ok:
        tech_votes += 1
    score += tech_votes * 3.6
    if tech_votes >= 4:
        reasons.append(f"tech_{tech_votes}/5")

    # 5. Structure/figure chartiste : BOS, KOLA, FVG, pattern directionnel.
    structure_votes = 0
    if native > 0 and bool(record.get("bos_bull")):
        structure_votes += 1
    if native < 0 and bool(record.get("bos_bear")):
        structure_votes += 1
    if native > 0 and bool(record.get("kola_near_buy")):
        structure_votes += 1
    if native < 0 and bool(record.get("kola_near_sell")):
        structure_votes += 1
    pattern_dir = direction("pattern_direction") or direction("chart_pattern_direction")
    if pattern_dir == native:
        structure_votes += 1
    if bool(record.get("fvg_bull")) and native > 0:
        structure_votes += 1
    if bool(record.get("fvg_bear")) and native < 0:
        structure_votes += 1
    score += min(18.0, structure_votes * 4.5)
    if structure_votes:
        reasons.append(f"structure_{structure_votes}")

    # 6. Verdict GOM et preuve de spike existante (16 points).
    try:
        verdict_num = int(record.get("verdict_num", 0) or 0)
    except (TypeError, ValueError):
        verdict_num = 0
    if verdict_num * native > 0:
        score += 7.0 if abs(verdict_num) >= 2 else 4.0
        reasons.append(f"GOM_{abs(verdict_num)}")
    spike_prob = max(number("spike_pred_prob"), number("spike_prob"), number("spike_pct") / 100.0)
    if spike_prob >= 0.70:
        score += 9.0
        reasons.append("spike_detector_fort")
    elif spike_prob >= 0.50:
        score += 5.0
        reasons.append("spike_detector")
    if bool(record.get("spike_tradable")):
        score += 4.0
        reasons.append("spike_confirme")

    # 7. Pénalités anti-faux-signaux : contradiction micro et sur-extension.
    if direction("tf_m1_dir") == -native or direction("tf_m5_dir") == -native:
        score -= 18.0
        reasons.append("contre_tendance_M1_M5")
    if opposed >= 4:
        score -= 10.0
        reasons.append("MTF_trop_divergent")
    if (native > 0 and rsi > 82.0) or (native < 0 and rsi < 18.0):
        score -= 8.0
        reasons.append("RSI_extreme")

    confidence_pct = max(0.0, min(100.0, score))
    confidence = round(confidence_pct / 100.0, 3)
    # READY est volontairement plus strict que « direction probable ».
    ready = (
        confidence_pct >= 78.0
        and aligned >= 4
        and direction("tf_m1_dir") == native
        and direction("tf_m5_dir") == native
        and opposed <= 2
    )
    return {
        "spike_prediction_direction": "BUY" if native > 0 else "SELL",
        "spike_prediction_confidence": confidence,
        "spike_prediction_pct": round(confidence_pct, 1),
        "spike_prediction_ready": ready,
        "spike_prediction_horizon_bars": 1 if ready else (3 if confidence_pct >= 60.0 else 0),
        "spike_prediction_reasons": "|".join(reasons) if reasons else "insufficient_confluence",
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
        # FIX 2026-09-25 : seuil de stabilite Boom/Crash.
        # Sur ces symboles le score est recourse au regime M1/M5, dont le signe
        # peut basculer d'un tick. En dessous de ce gap on ne publie pas de
        # verdict directionnel : le bruit de regime est plus grand que le
        # signal. Au-dessus, le regime ne peut plus retourner le verdict a lui
        # seul. 3.0 = un cran au-dessus du seuil GOOD historique (2.5), donc
        # seuls les veritables WAIT d'indecision fine sont concernes.
        self.bc_stability_gap = 3.0
        # Nombre de TF alignes requis pour que la penalite inverse du bloc
        # Boom/Crash soit acceptee (0 = desactivee).
        self.BC_TREND_CONSENSUS_MIN = 4
        self.min_entry_quality = 0.45
        self.mtf_perfect_pct = 0.63
        self._asset_category = "other"
        self.use_m1_scalp_uplift = True  # 2026-08: filet de sauvetage scalping M1 (voir apply_m1_scalp_uplift)

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
        is_boom = GOMLPineCalculator.is_boom_like_symbol(symbol)
        is_crash = GOMLPineCalculator.is_crash_like_symbol(symbol)
        spike_bc_en = bool(record.get("spike_bc_en", is_boom or is_crash))
        spike_level_num = int(record.get("spike_level_num", 0) or 0)
        spike_pred_prob = float(record.get("spike_pred_prob", 0) or 0)
        spike_tradable = bool(record.get("spike_tradable", False))
        spike_pct = float(record.get("spike_pct", 0) or 0)
        if spike_pct <= 0 and record.get("spike_prob") is not None:
            spike_pct = float(record.get("spike_prob") or 0) * 100.0

        if spike_bc_en and is_boom and spike_level_num >= 2 and spike_pred_prob >= 50:
            score_buy += 1.5
        if spike_bc_en and is_crash and spike_level_num >= 2 and spike_pred_prob >= 50:
            score_sell += 1.5
        if spike_bc_en and is_boom and spike_tradable:
            score_buy += 2.5
        if spike_bc_en and is_crash and spike_tradable:
            score_sell += 2.5

        # FIX 2026-09-25 : anti-thrashing Boom/Crash.
        # Le bloc ci-dessous retournait le score de 6.0 points d'un coup quand
        # `m1_m5_trend_sign` basculait (score_buy +2.0 -> -1.0, donc -3.0, et
        # symetrique cote sell) : sur un gap faible comme celui de GainX 400
        # (2.57) cela suffisait a passer de GOOD BUY a GOOD SELL en quelques
        # minutes. Le bonus directionnel (+2.0) reste inconditionnel — c'est
        # l'information de regime — mais la penalite inverse, elle, n'a de
        # sens que si les higher TF confirment. Sans ce verrou, un simple tick
        # M1 suffisait a declarer le side adverse faux.
        _bc_consensus = float(record.get("tf_global_strength", 0) or 0)
        _bc_penalty = 1.0 if _bc_consensus >= self.BC_TREND_CONSENSUS_MIN else 0.0

        if is_crash:
            m5 = str(record.get("tf_m5_dir", "NEUT") or "NEUT").upper()
            m1 = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "NEUT").upper()
            st = int(record.get("st_dir", 0) or 0)
            trend = m1_m5_trend_sign(record)
            if trend > 0:
                score_buy += 2.0
                score_sell -= 1.0 * _bc_penalty
            elif m5 == "BEAR" or m1 == "BEAR" or st == -1:
                score_sell += 2.0
                score_buy -= 1.0 * _bc_penalty
            bear_spike = bool(spike_bear) or trend < 0
            if bear_spike and (spike_pct >= 25.0 or spike_level_num >= 1):
                score_sell += 1.5
            if bear_spike and (spike_pct >= 45.0 or spike_tradable):
                score_sell += 2.0
            if trend > 0 and (spike_bull or spike_pct >= 25.0):
                score_buy += 1.5
        if is_boom:
            m5 = str(record.get("tf_m5_dir", "NEUT") or "NEUT").upper()
            m1 = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "NEUT").upper()
            st = int(record.get("st_dir", 0) or 0)
            trend = m1_m5_trend_sign(record)
            if trend < 0:
                score_sell += 2.0
                score_buy -= 1.0 * _bc_penalty
            elif m5 == "BULL" or m1 == "BULL" or st == 1:
                score_buy += 2.0
                score_sell -= 1.0 * _bc_penalty
            bull_spike = bool(spike_bull) or trend > 0
            if bull_spike and (spike_pct >= 25.0 or spike_level_num >= 1):
                score_buy += 1.5
            if bull_spike and (spike_pct >= 45.0 or spike_tradable):
                score_buy += 2.0
            if trend < 0 and (spike_bear or spike_pct >= 25.0):
                score_sell += 1.5

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
        score_buy += 4.0 if bos_bull else 0.0
        score_sell += 4.0 if bos_bear else 0.0
        score_buy -= 2.0 if bos_bear else 0.0
        score_sell -= 2.0 if bos_bull else 0.0

        dow = resolve_dow_direction(record)
        if dow == "BEAR":
            score_buy -= 5.0
            score_sell += 5.0
        elif dow == "BULL":
            score_buy += 5.0
            score_sell -= 5.0

        score_buy, score_sell = apply_m1_momentum_to_scores(record, score_buy, score_sell)

        # FIX 2026-09-17c (Claude, demande Sidoine) : les figures chartistes
        # (chandeliers + structure) détectées côté serveur (voir
        # gom_live_calculator._apply_pattern_confluence, en miroir des mêmes
        # patterns que SMC_PatternSignals.mqh côté EA) influencent désormais
        # directement le verdict — jusqu'ici elles ne servaient qu'à filtrer
        # l'entrée APRÈS coup, sans jamais peser sur le calcul du verdict
        # lui-même, ce qui pouvait rendre le verdict affiché peu fiable en
        # présence d'un pattern fort contredisant les indicateurs classiques.
        score_buy += float(record.get("pattern_score_buy", 0) or 0)
        score_sell += float(record.get("pattern_score_sell", 0) or 0)

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
        if not coherence_ok and record is not None:
            cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
            if cat in ("boom_crash", "volatility") and verdict_gap >= self.gap_min:
                coherence_ok = True
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
            # FIX 2026-09-23: GainX/Boom + impulse haussière → ne pas émettre SELL
            if record is not None and GOMLPineCalculator.is_boom_like_symbol(str(record.get("symbol", ""))):
                if price_strong_up:
                    # scores disent SELL mais le prix spike déjà en BUY → neutraliser ici
                    # (family impulse gate finalisera GOOD BUY)
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
            # FIX 2026-09-23: PainX/Crash + impulse baissière → ne pas émettre BUY
            if record is not None and GOMLPineCalculator.is_crash_like_symbol(str(record.get("symbol", ""))):
                if price_strong_down:
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
        """Return the only labels allowed by the public GOM contract."""
        try:
            verdict_num = int(verdict_num)
        except (TypeError, ValueError):
            verdict_num = 0
        return GOM_VERDICT_LABELS.get(verdict_num, "WAIT")

    @staticmethod
    def symbol_asset_category(symbol: str) -> str:
        """Catégorie actif Deriv/Weltrade — alignée SMC_Universal.mq5."""
        sym = str(symbol or "").upper().replace(" ", "")
        # FIX 2026-09-15 : les symboles du compte CENT Weltrade portent un suffixe
        # ".C" (ex: EURUSD.C, XAUUSD.C, DJIUSD.C). Sans retirer ce suffixe,
        # "EURUSD.C" échouait à tous les tests ci-dessous et tombait dans "other"
        # → il n'héritait ni des seuils forex ni de la logique associée, ce qui
        # bloquait ses verdicts en SIMPLE (jamais GOOD/PERFECT → aucune entrée).
        if sym.endswith(".C") and len(sym) > 3:
            sym = sym[:-2]
        if any(x in sym for x in ("BOOM", "CRASH", "PAINX", "GAINX", "TRENDX", "BREAKX")):
            return "boom_crash"
        if any(x in sym for x in (
            "VOL", "FXVOL", "SFVVOL", "SFXVOL", "STEP", "FLIPX", "SWITCHX",
            "PLUSX", "FIBOX", "QUADX", "RANGEX",
        )):
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


    @staticmethod
    def is_crash_like_symbol(symbol: str) -> bool:
        """Crash Deriv + PainX Weltrade (SELL-only spikes)."""
        s = str(symbol or "").lower().replace(" ", "")
        return "crash" in s or "painx" in s

    @staticmethod
    def is_boom_like_symbol(symbol: str) -> bool:
        """Boom Deriv + GainX Weltrade (BUY-only spikes)."""
        s = str(symbol or "").lower().replace(" ", "")
        return "boom" in s or "gainx" in s

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
            or any(x in sym for x in ("FLIPX", "SWITCHX", "PLUSX", "FIBOX", "QUADX", "RANGEX"))
        )

    def _normalize_spike_flags(self, record: Dict[str, Any]) -> None:
        """Active la logique spike Boom/Crash pour tous les synthétiques équivalents."""
        sym = str(record.get("symbol", "")).lower().replace(" ", "")
        cat = self.symbol_asset_category(sym)
        if cat in ("boom_crash", "volatility"):
            record["spike_bc_en"] = True
        elif "spike_bc_en" not in record:
            record["spike_bc_en"] = (
                GOMLPineCalculator.is_boom_like_symbol(sym)
                or GOMLPineCalculator.is_crash_like_symbol(sym)
            )

    def apply_mtf_verdict_gate(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Downgrade si le MTF contredit le verdict.

        Pondération : H4=3, H1=2, D1=2, M15=1, M5=1, M1=1, W1=1 (max=11).
        PERFECT BUY exige tb_w >= 7 (63%), GOOD exige tb_w > ts_w.
        """
        if verdict_num == 0:
            return 0

        h4_dir = normalize_direction(record.get("tf_h4_dir", "NEUT"))
        h1_dir = normalize_direction(record.get("tf_h1_dir", "NEUT"))

        cat = self.symbol_asset_category(str(record.get("symbol", "")))
        is_bc_synth = cat in ("boom_crash", "volatility")

        # Boom/Crash / Vol / PainX / GainX : M5 aligné → ne pas dégrader à cause de H1/H4
        if is_bc_synth:
            m5_dir = normalize_direction(record.get("tf_m5_dir", "NEUT"))
            if verdict_num > 0 and h4_dir == "BEAR" and h1_dir == "BEAR" and verdict_num >= 2:
                if m5_dir == "BULL":
                    return verdict_num
                return 1
            if verdict_num < 0 and h4_dir == "BULL" and h1_dir == "BULL" and verdict_num <= -2:
                if m5_dir == "BEAR":
                    return verdict_num
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
        tb_w = sum(w for k, w in tf_w.items() if normalize_direction(record.get(k, "NEUT")) == "BULL")
        ts_w = sum(w for k, w in tf_w.items() if normalize_direction(record.get(k, "NEUT")) == "BEAR")
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
            # FIX 2026-09-19 (équilibre WAIT excessif, demande Sidoine) : un
            # conflit pondéré modéré (1.5x-2.0x) tuait le verdict de façon
            # purement binaire (WAIT), sans palier intermédiaire, alors que
            # le panneau TF pouvait quand même montrer un alignement clair.
            # Désormais : conflit fort (>2.0x) = WAIT comme avant ; conflit
            # modéré (1.5x-2.0x) = repli en SIMPLE plutôt qu'annulation totale.
            if not h1h4_override:
                if ts_w > tb_w * 2.0:
                    record["gom_wait_reason"] = "mtf_gate_bull_weighted_conflict_strong"
                    return 0
                if ts_w > tb_w * 1.5:
                    verdict_num = 1
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
            # FIX 2026-09-19 (équilibre WAIT excessif, symétrique au bloc BUY
            # ci-dessus) : conflit modéré → SIMPLE au lieu de WAIT total.
            if not h1h4_override:
                if tb_w > ts_w * 2.0:
                    record["gom_wait_reason"] = "mtf_gate_bear_weighted_conflict_strong"
                    return 0
                if tb_w > ts_w * 1.5:
                    verdict_num = -1
            if verdict_num <= -3 and ts_w / total_w < self.mtf_perfect_pct:
                verdict_num = -2 if ts_w > tb_w else (-1 if ts_w >= tb_w * 0.8 else 0)
            elif verdict_num <= -2 and ts_w <= tb_w:
                verdict_num = -1 if ts_w >= tb_w * 0.8 else 0
            elif verdict_num <= -1 and ts_w < tb_w:
                return 0

        return verdict_num

    def _count_tf_dirs(self, record: Dict[str, Any]):
        """Compte BULL/BEAR sur les 7 TF (M1 live inclus)."""
        m1_live = normalize_direction(record.get("tf_m1_dir_live"))
        m1 = m1_live if m1_live != "NEUT" else normalize_direction(record.get("tf_m1_dir", "NEUT"))
        dirs = [
            m1,
            normalize_direction(record.get("tf_m5_dir", "NEUT")),
            normalize_direction(record.get("tf_m15_dir", "NEUT")),
            normalize_direction(record.get("tf_h1_dir", "NEUT")),
            normalize_direction(record.get("tf_h4_dir", "NEUT")),
            normalize_direction(record.get("tf_d1_dir", "NEUT")),
            normalize_direction(record.get("tf_global_dir", "NEUT")),
        ]
        bulls = sum(1 for d in dirs if d in ("BULL", "BUY", "UP"))
        bears = sum(1 for d in dirs if d in ("BEAR", "SELL", "DOWN"))
        return bulls, bears, dirs

    def apply_mtf_verdict_uplift(
        self, record: Dict[str, Any], score_buy: float, score_sell: float
    ) -> int:
        """≥5/7 TF alignés → au moins SIMPLE; ≥6 → GOOD. Synth: gap non veto."""
        bulls, bears, dirs = self._count_tf_dirs(record)
        gap = abs(score_buy - score_sell)
        cat = self.symbol_asset_category(str(record.get("symbol", "")))
        is_synth = cat in ("boom_crash", "volatility")
        record["tf_bull_count7"] = bulls
        record["tf_bear_count7"] = bears
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
        d5 = float(record.get("price_direction_5b", 0) or 0)
        dow = resolve_dow_direction(record)
        price_sell = d1 < 0 and d3 < 0 and d5 <= 0
        price_buy = d1 > 0 and d3 > 0 and d5 >= 0

        # v1.37: synth — majorité dès 4/7
        # FIX 2026-09-20 : ne plus interdire BUY sur PainX/Crash (ni SELL sur
        # GainX/Boom) quand la majorité TF est réellement dans ce sens.
        _maj = 4 if is_synth else 5
        _trend = m1_m5_trend_sign(record)
        if bears >= _maj and (is_synth or score_sell >= score_buy * 0.85):
            boom_vs_uptrend = (
                is_synth
                and GOMLPineCalculator.is_boom_like_symbol(str(record.get("symbol", "")))
                and _trend > 0
            )
            if not boom_vs_uptrend and not (dow == "BULL" and price_buy):
                vn = -2 if bears >= 5 or gap >= self.gap_good else -1
                record["mtf_majority_reason"] = f"bears={bears}/7->vn={vn}"
                return vn
        if bulls >= _maj and (is_synth or score_buy >= score_sell * 0.85):
            crash_vs_downtrend = (
                is_synth
                and GOMLPineCalculator.is_crash_like_symbol(str(record.get("symbol", "")))
                and _trend < 0
            )
            if crash_vs_downtrend:
                record["mtf_majority_reason"] = f"bulls={bulls}/7_blocked_painx_m1m5_BEAR"
            elif dow == "BEAR" or price_sell:
                record["mtf_majority_reason"] = f"bulls={bulls}/7_blocked_dow_or_price_sell"
            else:
                vn = 2 if bulls >= 5 or gap >= self.gap_good else 1
                record["mtf_majority_reason"] = f"bulls={bulls}/7->vn={vn}"
                return vn

        m1, m5, m15, h1 = dirs[0], dirs[1], dirs[2], dirs[3]
        min_gap = 0.25 if is_synth else 0.45
        if gap < min_gap:
            record["gom_wait_reason"] = f"mtf_uplift_gap_too_small({gap:.2f}<{min_gap})"
            return 0
        if not is_synth:
            if score_buy >= score_sell and h1 == "BEAR":
                return 0
            if score_sell > score_buy and h1 == "BULL":
                return 0
        # FIX 2026-09-19 (équilibre WAIT excessif, demande Sidoine) : avant,
        # un alignement M1=M5=M15 unanime côté BULL était annulé (WAIT) par
        # UN SEUL signal contraire (Dow OU prix M1), alors que côté BEAR il
        # fallait les DEUX (Dow ET prix M1) — asymétrie non voulue qui
        # pénalisait davantage les BUY. Désormais symétrique : les deux
        # signaux contraires ensemble = WAIT ; un seul = repli en SIMPLE
        # au lieu d'annulation totale.
        if m1 == m5 == m15 == "BULL" and score_buy >= score_sell:
            if dow == "BEAR" and price_sell:
                record["gom_wait_reason"] = "mtf_uplift_bull_dow_and_price_against"
                return 0
            if dow == "BEAR" or price_sell:
                return 1
            return 2 if gap >= self.gap_good else 1
        if m1 == m5 == m15 == "BEAR" and score_sell >= score_buy:
            if dow == "BULL" and price_buy:
                record["gom_wait_reason"] = "mtf_uplift_bear_dow_and_price_against"
                return 0
            if dow == "BULL" or price_buy:
                return -1
            return -2 if gap >= self.gap_good else -1
        bulls3 = sum(1 for d in (m1, m5, m15) if d == "BULL")
        bears3 = sum(1 for d in (m1, m5, m15) if d == "BEAR")
        gd = dirs[6]
        if bulls3 >= 2 and gd in ("BULL", "BUY") and score_buy > score_sell:
            return 2 if gap >= self.gap_good else 1
        if bears3 >= 2 and gd in ("BEAR", "SELL") and score_sell > score_buy:
            return -2 if gap >= self.gap_good else -1
        return 0


    def apply_m1_scalping_uplift(
        self, record: Dict[str, Any], score_buy: float, score_sell: float
    ) -> int:
        """Filet scalping M1 : sort du WAIT si momentum M1 franc (plafond |vn|=1)."""
        gap = abs(score_buy - score_sell)
        if gap < 0.35:
            return 0
        m1_live = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "NEUT").upper()
        if m1_live not in ("BULL", "BEAR"):
            return 0
        mom = float(record.get("m1_momentum", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
        d5 = float(record.get("price_direction_5b", 0) or 0)
        strong = _strong_move_threshold(record)
        thr = strong * 0.55
        cat = self.symbol_asset_category(str(record.get("symbol", "")))
        is_synth = cat in ("boom_crash", "volatility")
        h1 = str(record.get("tf_h1_dir", "NEUT") or "NEUT").upper()
        bullish_m1 = (
            m1_live == "BULL"
            and (mom > thr or d3 > thr * 0.7 or d5 > thr)
            and score_buy >= score_sell
        )
        bearish_m1 = (
            m1_live == "BEAR"
            and (mom < -thr or d3 < -thr * 0.7 or d5 < -thr)
            and score_sell >= score_buy
        )
        if bullish_m1:
            if not is_synth and h1 == "BEAR":
                return 0
            record["m1_scalping_uplift"] = "BUY"
            return 1
        if bearish_m1:
            if not is_synth and h1 == "BULL":
                return 0
            record["m1_scalping_uplift"] = "SELL"
            return -1
        return 0

    def apply_bc_verdict_guard(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Boom/Crash: respecter M1+M5. Biais natif seulement si la tendance locale
        n'est PAS clairement opposée (PainX uptrend = BUY autorisé).
        """
        sym = str(record.get("symbol", "")).lower()
        is_crash = GOMLPineCalculator.is_crash_like_symbol(sym)
        is_boom = GOMLPineCalculator.is_boom_like_symbol(sym)

        if not is_crash and not is_boom:
            return verdict_num

        spike_tradable = bool(record.get("spike_tradable", False))
        trend = m1_m5_trend_sign(record)

        if is_crash:
            d1 = float(record.get("price_direction_1b", 0) or 0)
            d3 = float(record.get("price_direction_3b", 0) or 0)
            if d1 < 0 and d3 < 0 and verdict_num > 0:
                record["bc_guard_reason"] = "painx_m1_dump_blocks_BUY"
                return 0
            if trend > 0:
                if verdict_num < 0:
                    record["bc_guard_reason"] = "painx_m1m5_BULL_blocks_SELL"
                    return 0
                return verdict_num
            if verdict_num > 0:
                sb = float(record.get("score_buy", 0) or 0)
                ss = float(record.get("score_sell", 0) or 0)
                if sb >= ss:
                    record["bc_guard_reason"] = "painx_keep_BUY_from_scores"
                    return verdict_num
                return -verdict_num if spike_tradable and trend < 0 else 0
            return verdict_num

        if is_boom:
            if trend < 0:
                if verdict_num > 0:
                    record["bc_guard_reason"] = "gainx_m1m5_BEAR_blocks_BUY"
                    return 0
                return verdict_num
            if verdict_num < 0:
                sb = float(record.get("score_buy", 0) or 0)
                ss = float(record.get("score_sell", 0) or 0)
                if ss >= sb:
                    record["bc_guard_reason"] = "gainx_keep_SELL_from_scores"
                    return verdict_num
                return -verdict_num if spike_tradable and trend > 0 else 0
            return verdict_num

        return verdict_num

    def apply_spike_chain_uplift(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Chaîne de spikes M1 consécutifs → verdict GOOD immédiat (FIX 2026-08-23).

        Dès 2 bougies M1 « spike » (ou 3 corps directionnels) dans le sens natif :
        - Crash/PainX : → GOOD SELL (-2)
        - Boom/GainX  : → GOOD BUY (+2)
        Même depuis WAIT (vn=0). PERFECT même sens conservé.
        Seuil : GOM_SPIKE_CHAIN_BARS (defaut 1). Soft : GOM_SOFT_CHAIN_BARS (defaut 2).
        """
        vn = int(verdict_num or 0)
        try:
            chain_min = int(os.getenv("GOM_SPIKE_CHAIN_BARS", "1"))
        except ValueError:
            chain_min = 2
        try:
            soft_min = int(os.getenv("GOM_SOFT_CHAIN_BARS", "2"))
        except ValueError:
            soft_min = 3
        if chain_min <= 0:
            return vn

        sym = str(record.get("symbol", "")).lower().replace(" ", "")
        symbol_disp = str(record.get("symbol", ""))

        m1_live = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "").upper()
        mom = float(record.get("m1_momentum", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)

        if GOMLPineCalculator.is_crash_like_symbol(sym):
            trend = m1_m5_trend_sign(record)
            # Uptrend M1+M5 : ne jamais forcer SELL (ni SIMPLE natif, ni chaîne).
            if trend > 0:
                if vn < 0:
                    record["spike_chain_blocked"] = "m1m5_BULL_blocks_SELL_chain"
                    return 0
                if vn == 0:
                    sb = float(record.get("score_buy", 0) or 0)
                    ss = float(record.get("score_sell", 0) or 0)
                    if sb >= ss:
                        record["spike_chain_reason"] = "painx_m1m5_BULL->SIMPLE_BUY"
                        return 1
                return vn
            strong_bull = (m1_live in ("BULL", "BUY") and mom > 0.00045 and d3 > 0.0004)
            chain = int(record.get("m1_consec_sell_spikes", 0) or 0)
            soft = int(record.get("m1_consec_sell_bars", 0) or 0)
            m5u = str(record.get("tf_m5_dir") or "").upper()
            mtf_sell = m1_live in ("BEAR", "SELL") and m5u in ("BEAR", "SELL")
            spike_ok = bool(record.get("spike_tradable")) or float(record.get("spike_prob", 0) or 0) >= 0.50
            hit = (
                chain >= chain_min
                or (soft >= soft_min and chain >= 1)
                or (soft >= max(2, soft_min - 1) and mtf_sell)
                or (mtf_sell and spike_ok and soft >= 1)
            )
            if strong_bull:
                record["spike_chain_blocked"] = "m1_strong_bull_vs_sell"
                if vn <= -2:
                    print(f"[GOM-SPIKE-CHAIN] {symbol_disp}: strong M1 BULL vs SELL → WAIT (vn={vn}→0)")
                    return 0
                if vn == -1:
                    return 0
                if hit:
                    return vn if vn <= 0 else 0
            if strong_bull and hit:
                record["spike_chain_blocked"] = "m1_strong_bull_vs_sell_chain"
                return vn if vn <= 0 else 0
            if hit and vn > -2:
                sb = float(record.get("score_buy", 0) or 0)
                ss = float(record.get("score_sell", 0) or 0)
                if sb > ss:
                    record["spike_chain_blocked"] = "scores_BUY_block_SELL_chain"
                    return vn if vn >= 0 else 0
                record["spike_chain_reason"] = f"sell_chain_x{chain}_soft{soft}_mtf{int(mtf_sell)}->GOOD_SELL"
                print(
                    f"[GOM-SPIKE-CHAIN] {symbol_disp}: spikesSELL={chain} softBars={soft} "
                    f"→ GOOD SELL immédiat (vn={vn} → -2)"
                )
                return -2
            if vn == 0 and not strong_bull:
                ss = float(record.get("score_sell", 0) or 0)
                sb = float(record.get("score_buy", 0) or 0)
                if sb > ss:
                    return 0
                if ss >= sb + 0.3 or soft >= 2:
                    record["spike_chain_reason"] = "painx_native_sell_bias->SIMPLE_SELL"
                    return -1
            return vn

        if GOMLPineCalculator.is_boom_like_symbol(sym):
            trend = m1_m5_trend_sign(record)
            if trend < 0:
                if vn > 0:
                    record["spike_chain_blocked"] = "m1m5_BEAR_blocks_BUY_chain"
                    return 0
                if vn == 0:
                    sb = float(record.get("score_buy", 0) or 0)
                    ss = float(record.get("score_sell", 0) or 0)
                    if ss >= sb:
                        record["spike_chain_reason"] = "gainx_m1m5_BEAR->SIMPLE_SELL"
                        return -1
                return vn
            strong_bear = (m1_live in ("BEAR", "SELL") and mom < -0.00045 and d3 < -0.0004)
            chain = int(record.get("m1_consec_buy_spikes", 0) or 0)
            soft = int(record.get("m1_consec_buy_bars", 0) or 0)
            m5u = str(record.get("tf_m5_dir") or "").upper()
            mtf_buy = m1_live in ("BULL", "BUY") and m5u in ("BULL", "BUY")
            spike_ok = bool(record.get("spike_tradable")) or float(record.get("spike_prob", 0) or 0) >= 0.50
            hit = (
                chain >= chain_min
                or (soft >= soft_min and chain >= 1)
                or (soft >= max(2, soft_min - 1) and mtf_buy)
                or (mtf_buy and spike_ok and soft >= 1)
            )
            if strong_bear and hit:
                record["spike_chain_blocked"] = "m1_strong_bear_vs_buy_chain"
                return vn if vn >= 0 else 0
            if hit and vn < 2:
                record["spike_chain_reason"] = f"buy_chain_x{chain}_soft{soft}_mtf{int(mtf_buy)}->GOOD_BUY"
                print(
                    f"[GOM-SPIKE-CHAIN] {symbol_disp}: spikesBUY={chain} softBars={soft} "
                    f"→ GOOD BUY immédiat (vn={vn} → 2)"
                )
                return 2
            if vn == 0 and not strong_bear:
                sb = float(record.get("score_buy", 0) or 0)
                ss = float(record.get("score_sell", 0) or 0)
                if sb >= ss + 0.3 or soft >= 2:
                    record["spike_chain_reason"] = "gainx_native_buy_bias->SIMPLE_BUY"
                    return 1
            return vn

        return vn

    def apply_entry_quality_gate(self, record: Dict[str, Any], verdict_num: int) -> int:
        """Downgrade si entry_quality insuffisante pour GOOD/PERFECT."""
        if verdict_num == 0:
            return 0
        eq = float(record.get("entry_quality", 0) or 0)
        cat = self._asset_category or self.symbol_asset_category(str(record.get("symbol", "")))
        _min_eq = self.min_entry_quality
        if cat not in ("boom_crash", "volatility"):
            _min_eq = min(_min_eq, 0.30)
        if eq >= _min_eq:
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
        # FIX 2026-09-19 (diagnostic, demande Sidoine) : reset à chaque poll
        # pour ne pas garder une raison de WAIT périmée d'un cycle précédent.
        record["gom_wait_reason"] = None
        self._apply_asset_profile(record)
        self._normalize_spike_flags(record)

        # FIX 2026-09-20 (Sidoine) : vérifier la tendance structurelle AVANT calcul scores
        # pour éviter GOOD BUY en plein downtrend avec spikes émergents
        trend_sign = m1_m5_trend_sign(record)
        dow_dir = resolve_dow_direction(record)

        # Pénalité forte si contre-tendance structurelle
        if trend_sign == -1 and dow_dir == "BEAR":
            # Downtrend confirmé: pénaliser BUY fortement
            record["structure_trend_penalty"] = "strong_downtrend"
        elif trend_sign == 1 and dow_dir == "BULL":
            # Uptrend confirmé: pénaliser SELL fortement
            record["structure_trend_penalty"] = "strong_uptrend"

        score_buy, score_sell = self.calculate_scores(record)

        # Appliquer pénalités de tendance structurelle
        if record.get("structure_trend_penalty") == "strong_downtrend":
            score_buy -= 8.0  # Pénalité majeure BUY en downtrend
            score_sell += 3.0  # Bonus modéré SELL en downtrend
        elif record.get("structure_trend_penalty") == "strong_uptrend":
            score_sell -= 8.0  # Pénalité majeure SELL en uptrend
            score_buy += 3.0   # Bonus modéré BUY en uptrend

        # FIX 2026-09-25 : un score ne peut pas etre negatif, et le clamp doit
        # preceder le gap car c'est le gap qui pilote toute la hierarchie.
        # Plusieurs modulateurs sont soustractifs et rien ne les bornait :
        # structure_trend_penalty (-8.0), DOW (-5.0), BOS (-2.0), bloc
        # Boom/Crash (-1.0) et apply_m1_momentum_to_scores (jusqu'a ~3.0).
        # On a observe score_buy = -4.43 alors que le score demarre a 0 et
        # n'accumule que des "+=". Consequence : le gap est gonfle
        # artificiellement (19.19 au lieu de 14.76), ce qui suffit a tipped un
        # GOOD BUY en PERFECT, et un score negatif n'a aucun sens metrique.
        # C'etait la source des verdicts "GOOD SELL" improvises sur GainX 400.
        score_buy = max(0.0, score_buy)
        score_sell = max(0.0, score_sell)

        verdict_gap = abs(score_buy - score_sell)

        # FIX 2026-09-19 (Sidoine) : autorité de classification = GOMVerdictCalculatorV2.
        # L'ancien flux appliquait après les scores des gates MTF/pondérés
        # (apply_mtf_verdict_uplift, apply_m1_scalping_uplift, apply_mtf_verdict_gate)
        # et des seuils réduits par catégorie d'actif (ASSET_VERDICT_PROFILES) qui
        # pouvaient : 1) INVERTIR la direction du verdict par rapport aux scores
        # (ex: BUY alors que score_sell > score_buy), 2) reclassifier GOOD/PERFECT
        # avec des gaps bien en-dessous de la spec (ex: PERFECT à gap>=2.5 forex
        # au lieu de 4.0). V2 décide seul désormais : direction = score dominant,
        # classification = seuils purs 1.2/2.5/4.0, gate = cohérence (filter_ratio).
        if GOMVerdictCalculatorV2 is None:
            filter_ratio = self.calculate_filter_ratio(record, score_buy, score_sell)
            coherence_ok = (
                not self.verdict_coherence
                or filter_ratio >= self.filter_ratio_min
                or verdict_gap >= (self.verdict_gap_th + 0.24)
            )
            verdict_num = self.calculate_verdict_num(score_buy, score_sell, filter_ratio, record)
        else:
            _verdict_calc = GOMVerdictCalculatorV2()
            # FIX 2026-09-25 : la coherence se mesure DANS le sens du verdict.
            # Sans direction explicite, un downtrend net etait juge avec des
            # seuils acheteurs et ressortait toujours "incoherent".
            _coh_dir = 1 if score_buy > score_sell else (-1 if score_sell > score_buy else 0)
            coherence_ok, filter_ratio = _verdict_calc.check_coherence(record, _coh_dir)
            # Le plancher de stabilite ne concerne que les familles Boom/Crash,
            # dont le score est recourse au regime M1/M5 : c'est la ou le gap
            # peut retourner sous l'effet d'un simple tick. Les autres familles
            # gardent le seuil historique de 1.2.
            _sym = str(record.get("symbol", "") or "")
            _is_bc = (
                GOMLPineCalculator.is_boom_like_symbol(_sym)
                or GOMLPineCalculator.is_crash_like_symbol(_sym)
            )
            _min_gap = self.bc_stability_gap if _is_bc else 0.0
            verdict_num = _verdict_calc.calculate_verdict_num(
                score_buy, score_sell, coherence_ok, verdict_gap, record, _min_gap
            )
            record["bc_stability_applied"] = _min_gap
        # Sous-gates natifs/sécurité conservés ; les gates MTF qui pouvaient
        # inverser la direction ou forcer une classification contre les scores
        # ont été retirés du flux. Seuls les gates de sécurité stricte (downgrade
        # uniquement) restent actifs plus bas.
        verdict_num = self.apply_bc_verdict_guard(record, verdict_num)
        # FIX 2026-09-19 (diagnostic, demande Sidoine) : si le verdict est
        # WAIT mais qu'aucun des gates ci-dessus n'a posé de raison, c'est
        # que le calcul V2 lui-même (score brut, avant tout gate) a rendu 0.
        if verdict_num == 0 and not record.get("gom_wait_reason"):
            record["gom_wait_reason"] = "base_score_undecided"

        record["score_buy"] = score_buy
        record["score_sell"] = score_sell
        record.update(predict_spike_setup(record))

        # Prédiction cross-signaux : elle peut confirmer un signal faible ou
        # sauver un WAIT uniquement quand le score prédictif est très élevé,
        # M1/M5 sont alignés dans le sens natif et aucune divergence forte MTF
        # n'est présente. Elle ne crée jamais de SELL sur Boom ni de BUY sur
        # Crash, et reste soumise au contrat entry_allowed final.
        pred_dir = str(record.get("spike_prediction_direction", "NEUTRAL")).upper()
        pred_ready = bool(record.get("spike_prediction_ready", False))
        pred_pct = float(record.get("spike_prediction_pct", 0) or 0)
        is_native_dir = (
            (self.is_boom_like_symbol(str(record.get("symbol", ""))) and pred_dir == "BUY")
            or (self.is_crash_like_symbol(str(record.get("symbol", ""))) and pred_dir == "SELL")
            or (self.symbol_asset_category(str(record.get("symbol", ""))) == "volatility"
                and pred_dir in ("BUY", "SELL"))
        )
        if pred_ready and pred_pct >= 78.0 and is_native_dir:
            target_vn = 2 if pred_dir == "BUY" else -2
            if verdict_num == 0 or (verdict_num > 0 and target_vn > 0) or (verdict_num < 0 and target_vn < 0):
                if abs(verdict_num) < abs(target_vn):
                    verdict_num = target_vn
                    record["spike_prediction_uplift"] = "GOOD"

        record["entry_quality"] = self.calculate_entry_quality(
            record, score_buy, score_sell, verdict_gap, filter_ratio
        )
        verdict_num = self.apply_entry_quality_gate(record, verdict_num)
        verdict_num = self.apply_smc_structure_gate(record, verdict_num)
        verdict_num, reality_reason = apply_price_reality_gate(record, verdict_num)
        if reality_reason:
            record["price_reality_reason"] = reality_reason

        record["verdict_gap"] = round(verdict_gap, 2)
        record["filter_ratio"] = round(filter_ratio, 2)
        record["coherence_ok"] = coherence_ok
        # FIX 2026-09-23: sens natif famille + impulse M1 (GainX=BUY, PainX=SELL)
        # AVANT d'écrire verdict_num/verdict dans le record
        verdict_num = apply_family_native_impulse(record, verdict_num)
        record["verdict_num"] = verdict_num
        record["verdict"] = self.verdict_text(verdict_num)
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
        # FIX 2026-09-06 : bool(x) est faux quand x vaut legitimement 0.0
        # (prix plat sur 5 bougies M1) -> harmonized_m1 retombait a False a
        # tort et reactivait les gardes locales EA (SMC_GOM_Pipeline.mqh),
        # ce qui pouvait ecraser un GOOD/PERFECT reel en WAIT cote EA.
        # On teste desormais la presence des champs, pas leur veracite.
        record["harmonized_m1"] = ("m1_close" in record) or ("price_direction_5b" in record)
        record["verdict_mode"] = "reactive_pine"

        # FIX 2026-09-19 (Sidoine) : downgrade cohérence synthétique SUPPRIMÉ du
        # flux. La cohérence est appliquée UNE SEULE fois, par V2, au moment du
        # calcul du verdict (filter_ratio >= 0.40 dans check_coherence). L'ancien
        # bloc reclassifiait GOOD/PERFECT → BUY/SELL en-dessous de 65% de
        # cohérence pour Boom/Crash/Volatility, ce qui contredisait les seuils
        # purs V2 (l'autorité de classification) et produisait les ecarts de
        # classification constatés.

        # FIX 2026-08-22 : uplift chaîne de spikes — 3 spikes M1 consécutifs dans le
        # sens natif (SELL sur Crash/PainX, BUY sur Boom/GainX) ⇒ verdict GOOD
        # immédiat, sans attendre que verdict_gap franchisse gap_good (~6 spikes).
        # Placé en DERNIER gate : ni le downgrade cohérence ni les gates amont
        # ne peuvent annuler un signal confirmé par la réalité des bougies.
        final_vn = self.apply_spike_chain_uplift(record, int(record.get("verdict_num", 0) or 0))
        if final_vn != int(record.get("verdict_num", 0) or 0):
            record["verdict_num"] = final_vn
            record["verdict"] = self.verdict_text(final_vn)

        # FIX 2026-09-04: PainX/Crash en zone discount + M1/M5 BEAR + spike
        # → au minimum GOOD SELL (pas rester bloqué en SELL simple).
        # Symétrique Boom/GainX en premium + M1/M5 BULL → GOOD BUY.
        _vn = int(record.get("verdict_num", 0) or 0)
        _sym = str(record.get("symbol", "")).lower().replace(" ", "")
        _m1 = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "").upper()
        _m5 = str(record.get("tf_m5_dir") or "").upper()
        _spike = bool(record.get("spike_tradable")) or float(record.get("spike_prob", 0) or 0) >= 0.50
        _zone = str(record.get("zone") or record.get("premium_discount") or record.get("gom_zone") or "").upper()
        if GOMLPineCalculator.is_crash_like_symbol(_sym):
            _d1s = float(record.get("price_direction_1b", 0) or 0)
            _d3s = float(record.get("price_direction_3b", 0) or 0)
            _d5s = float(record.get("price_direction_5b", 0) or 0)
            _dump = _d1s < 0 and _d3s < 0
            _bounce = _d1s > 0 and _d5s < 0
            if _dump:
                record["tf_m1_dir_live"] = "BEAR"
                record["tf_m1_dir"] = "BEAR"
                if _d5s < 0:
                    record["tf_m5_dir"] = "BEAR"
                if _vn > 0:
                    record["verdict_num"] = 0
                    record["verdict"] = "WAIT"
                    record["structure_uplift"] = "crash_m1_dump_vs_ema_BULL->WAIT"
                    print(f"[GOM-STRUCT] {record.get('symbol')}: dump M1 vs EMA BULL → WAIT")
                    _vn = 0
                if _vn > -2:
                    _mag = -3 if _d5s <= 0 else -2
                    record["verdict_num"] = _mag
                    record["verdict"] = self.verdict_text(_mag)
                    record["structure_uplift"] = f"crash_m1_dump->SELL_{_mag}"
                    print(f"[GOM-STRUCT] {record.get('symbol')}: dump M1 → {record['verdict']}")
            elif _m1 in ("BULL", "BUY") and _m5 in ("BULL", "BUY") and _vn < 2:
                if _bounce:
                    if _vn <= 0:
                        record["verdict_num"] = 1
                        record["verdict"] = self.verdict_text(1)
                        record["structure_uplift"] = "crash_M1M5_BULL_bounce->SIMPLE_BUY"
                else:
                    record["verdict_num"] = 2
                    record["verdict"] = "GOOD BUY"
                    record["structure_uplift"] = "crash_M1M5_BULL->GOOD_BUY"
                    print(f"[GOM-STRUCT] {record.get('symbol')}: M1+M5 BULL → GOOD BUY")
            elif _m1 in ("BEAR", "SELL") and _m5 in ("BEAR", "SELL") and _vn > -2:
                if _spike or "DISCOUNT" in _zone or _vn == -1:
                    record["verdict_num"] = -2
                    record["verdict"] = "GOOD SELL"
                    record["structure_uplift"] = "crash_M1M5_BEAR_spike_or_discount->GOOD_SELL"
                    print(f"[GOM-STRUCT] {record.get('symbol')}: M1+M5 BEAR → GOOD SELL")
        elif GOMLPineCalculator.is_boom_like_symbol(_sym):
            _dow = resolve_dow_direction(record)
            _d1 = float(record.get("price_direction_1b", 0) or 0)
            _d3 = float(record.get("price_direction_3b", 0) or 0)
            if _dow == "BEAR" or (_d1 < 0 and _d3 < 0):
                if _vn > 0:
                    record["verdict_num"] = 0
                    record["verdict"] = "WAIT"
                    record["structure_uplift"] = f"boom_dow_BEAR_or_dump_blocks_BUY (dow={_dow})"
                    print(f"[GOM-STRUCT] {record.get('symbol')}: DOW BEAR/dump → WAIT (pas de BUY)")
            elif _m1 in ("BULL", "BUY") and _m5 in ("BULL", "BUY") and _vn < 2:
                if _spike or "PREMIUM" in _zone or _vn == 1:
                    record["verdict_num"] = 2
                    record["verdict"] = "GOOD BUY"
                    record["structure_uplift"] = "boom_M1M5_BULL_spike_or_premium->GOOD_BUY"
                    print(f"[GOM-STRUCT] {record.get('symbol')}: M1+M5 BULL → GOOD BUY")

        # FIX 2026-09-20 (Sidoine) : gate de correction - abaisse GOOD/PERFECT vers SIMPLE
        # si le prix est en correction (M1/M5 opposés, momentum contre tendance, pullback)
        # IMPORTANT: Appliqué AVANT apply_trend_alignment_verdict pour éviter que
        # l'alignement MTF ne force un GOOD/PERFECT en plein correction
        final_before_correction = int(record.get("verdict_num", 0) or 0)
        apply_correction_state_to_record(record)

        final_after_correction = apply_correction_gate(record, final_before_correction)
        if final_after_correction != final_before_correction:
            record["correction_blocked"] = True
            record["correction_block_reason"] = record.get("correction_gate_reason", "price_correction")
            record["verdict_num"] = final_after_correction
            record["verdict"] = self.verdict_text(final_after_correction)

        aligned_vn = apply_trend_alignment_verdict(
            record, int(record.get("verdict_num", 0) or 0)
        )
        if aligned_vn != int(record.get("verdict_num", 0) or 0):
            record["verdict_num"] = aligned_vn
            record["verdict"] = self.verdict_text(aligned_vn)

        # Dernier verrou d'exécution: aucun uplift précédent ne peut autoriser
        # GOOD/PERFECT si le M1 est neutre, absent ou opposé.
        final_before_m1 = int(record.get("verdict_num", 0) or 0)
        final_after_m1 = apply_m1_execution_gate(record, final_before_m1)
        if final_after_m1 != final_before_m1:
            record["m1_execution_blocked"] = True
            record["m1_execution_block_reason"] = "M1 absent, neutre ou opposé au verdict final"
            record["verdict_num"] = final_after_m1
            record["verdict"] = self.verdict_text(final_after_m1)

        # FIX 2026-09-20 : le score dominant a le dernier mot sur le SENS
        # (évite PainX SELL alors que buy >> sell).
        scored = apply_score_direction_authority(
            record, int(record.get("verdict_num", 0) or 0)
        )
        if scored != int(record.get("verdict_num", 0) or 0):
            record["verdict_num"] = scored
            record["verdict"] = self.verdict_text(scored)

        # FIX 2026-09-21 : le flux M1 réel plafonne GOOD/PERFECT après les
        # uplifts scores/MTF (évite PERFECT BUY sur rebond post-dump).
        impulse_vn = apply_price_impulse_cap(
            record, int(record.get("verdict_num", 0) or 0)
        )
        if impulse_vn != int(record.get("verdict_num", 0) or 0):
            record["verdict_num"] = impulse_vn
            record["verdict"] = self.verdict_text(impulse_vn)

        # FIX 2026-09-20 (Sidoine) : gate Dow ABSOLU en DERNIER
        # Le gate Dow doit avoir le dernier mot sur la direction finale.
        # Même si les scores dominants veulent un PERFECT SELL, si la ligne Dow
        # est haussière et le prix en correction buy → WAIT obligatoire.
        # Le gate Dow ne peut pas être contourné par les scores.
        final_before_dow = int(record.get("verdict_num", 0) or 0)
        final_after_dow = apply_dow_gate(record, final_before_dow)
        if final_after_dow != final_before_dow:
            record["verdict_num"] = final_after_dow
            record["verdict"] = self.verdict_text(final_after_dow)
            record["dow_gate_final"] = True  # Marqueur pour diagnostic

        # Séparer explicitement le verdict analytique de l'autorisation
        # d'entrée. Un BUY/SELL simple ne peut donc pas être interprété par
        # un consommateur comme un signal d'exécution.
        final_vn = int(record.get("verdict_num", 0) or 0)
        min_entry_abs = max(
            GOM_MIN_ENTRY_VERDICT_ABS,
            int(record.get("min_entry_verdict_abs", GOM_MIN_ENTRY_VERDICT_ABS) or 0),
        )
        record["min_entry_verdict_abs"] = min_entry_abs
        apply_execution_quality_contract(record)

        # Dump M1 live : jamais de BUY PainX/Crash même si Dow/scores restent BULL.
        _fvn = int(record.get("verdict_num", 0) or 0)
        _fd1 = float(record.get("price_direction_1b", 0) or 0)
        _fd3 = float(record.get("price_direction_3b", 0) or 0)
        _fsym = str(record.get("symbol", ""))
        if GOMLPineCalculator.is_crash_like_symbol(_fsym) and _fd1 < 0 and _fd3 < 0:
            record["tf_m1_dir_live"] = "BEAR"
            record["tf_m1_dir"] = "BEAR"
            _fd5 = float(record.get("price_direction_5b", 0) or 0)
            if _fd5 < 0:
                record["tf_m5_dir"] = "BEAR"
            if _fvn > 0:
                record["verdict_num"] = 0
                record["verdict"] = "WAIT"
                record["structure_uplift"] = "crash_final_dump_blocks_BUY"
                _fvn = 0
            if _fvn > -2:
                _mag = -3 if _fd5 <= 0 else -2
                record["verdict_num"] = _mag
                record["verdict"] = self.verdict_text(_mag)
                record["structure_uplift"] = f"crash_final_dump->SELL_{_mag}"
                apply_execution_quality_contract(record)
        elif GOMLPineCalculator.is_boom_like_symbol(_fsym):
            _fdow = resolve_dow_direction(record)
            if _fd1 < 0 and _fd3 < 0:
                record["tf_m1_dir_live"] = "BEAR"
                record["tf_m1_dir"] = "BEAR"
            if (_fd1 < 0 and _fd3 < 0) or _fdow == "BEAR":
                if _fvn > 0:
                    record["verdict_num"] = 0
                    record["verdict"] = "WAIT"
                    record["structure_uplift"] = "boom_final_dump_or_dow_BEAR_blocks_BUY"
                    apply_execution_quality_contract(record)
            elif _fd1 > 0 and _fd3 > 0 and _fvn < 0:
                record["tf_m1_dir_live"] = "BULL"
                record["tf_m1_dir"] = "BULL"
                record["verdict_num"] = 0
                record["verdict"] = "WAIT"
                record["structure_uplift"] = "boom_final_rally_blocks_SELL"
                apply_execution_quality_contract(record)
        
        # FIX 2026-09-23: re-applique famille après tous les gates (anti WAIT/SELL fantôme)
        _vn_final = int(record.get("verdict_num", 0) or 0)
        _vn_fam = apply_family_native_impulse(record, _vn_final)
        if _vn_fam != _vn_final:
            record["verdict_num"] = _vn_fam
            record["verdict"] = self.verdict_text(_vn_fam)
            print(f"[FAMILY-IMPULSE-FINAL] {record.get('symbol')}: {_vn_final} → {_vn_fam}")
        # Dow après famille : un bounce 1 bougie ne doit pas recréer un GOOD BUY
        # contre une ligne Dow BEAR / dump M1.
        _vn_post = int(record.get("verdict_num", 0) or 0)
        _vn_dow = apply_dow_gate(record, _vn_post)
        if _vn_dow != _vn_post:
            record["verdict_num"] = _vn_dow
            record["verdict"] = self.verdict_text(_vn_dow)
            record["dow_gate_after_family"] = True
            apply_execution_quality_contract(record)

        # Regime + prevision 5 / 100 bougies M1 réelles.
        apply_regime_forecast_to_record(record)

        # AUTORITE M1/M5 (dernier mot) : le flux reel tranche le sens, la
        # famille plafonne l'intensite. Doit rester en DERNIER, sinon les
        # gates de famille/MTF/Dow reappliquent leur contradiction.
        _vn_auth = int(record.get("verdict_num", 0) or 0)
        _vn_auth2 = apply_m1m5_flow_authority(record, _vn_auth)
        if _vn_auth2 != _vn_auth:
            record["verdict_num"] = _vn_auth2
            record["verdict"] = verdict_text_from_num(_vn_auth2)
            record["action"] = record["verdict"]
        # Toujours recalculer, meme sans changement : entry_allowed a pu etre
        # pose par un gate antérieur sur un verdict qui a ensuite evolue.
        # Normalisation finale : certaines branches historiques écrivent le
        # texte avant de modifier verdict_num. Le nombre est l'autorité ; on
        # régénère donc toujours les deux champs depuis la table publique pour
        # garantir exclusivement WAIT/GOOD/PERFECT/SIMPLE.
        _final_num = int(record.get("verdict_num", 0) or 0)
        record["verdict"] = self.verdict_text(_final_num)
        record["action"] = record["verdict"]
        apply_execution_quality_contract(record)
        return record


def apply_regime_forecast_to_record(record: Dict[str, Any]) -> Dict[str, Any]:
    """Ancre le verdict sur régime + pente des bougies M1 closes (5 et 100)."""
    try:
        from gom_regime_forecast import apply_regime_forecast_gate
    except Exception:
        try:
            from python.gom_regime_forecast import apply_regime_forecast_gate
        except Exception:
            return record
    vn = int(record.get("verdict_num", 0) or 0)
    new_vn = apply_regime_forecast_gate(record, vn)
    if new_vn != vn:
        record["verdict_num"] = new_vn
        record["verdict"] = verdict_text_from_num(new_vn)
        apply_execution_quality_contract(record)
    fam = apply_family_native_impulse(record, int(record.get("verdict_num", 0) or 0))
    if fam != int(record.get("verdict_num", 0) or 0):
        record["verdict_num"] = fam
        record["verdict"] = verdict_text_from_num(fam)
        apply_execution_quality_contract(record)
    # AUTORITE M1/M5 : tranche le sens, plafonne par la famille.
    _vn = int(record.get("verdict_num", 0) or 0)
    _vn_auth = apply_m1m5_flow_authority(record, _vn)
    if _vn_auth != _vn:
        record["verdict_num"] = _vn_auth
        record["verdict"] = verdict_text_from_num(_vn_auth)
    apply_execution_quality_contract(record)
    return record


def _strong_move_threshold(record: Dict[str, Any]) -> float:
    """Seuil move M1 fort — plus sensible sur synthetics (intervalle 5 min)."""
    cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
    if cat in ("boom_crash", "volatility"):
        return 0.00035
    if cat in ("metal", "crypto"):
        return 0.0005
    return 0.001



def compute_correction_state(record: Dict[str, Any]) -> Dict[str, Any]:
    """État de correction fiable pour affichage GOM + gates EA.

    Stages (contre la structure HTF M5+) :
      none      — pas de correction (prix suit la structure)
      started   — correction vient de démarrer (2+ barres adverses, depth ≥15%)
      mid       — correction en cours (depth 30–70%)
      ending    — fin probable (depth ≥55% + 1–2 barres dans le sens structure,
                  ou momentum adverse qui s'essouffle)
      finished  — correction terminée (reprise structure claire après pullback)

    Exposé dans le payload :
      correction_stage, correction_label, correction_depth_pct,
      correction_against, correction_entry_safe, pa_in_correction,
      m1_consec_against, m1_consec_with
    """
    out: Dict[str, Any] = {
        "correction_stage": "none",
        "correction_label": "NO CORR",
        "correction_depth_pct": 0.0,
        "correction_against": "NEUT",
        "correction_entry_safe": True,
        "pa_in_correction": False,
        "m1_consec_against": 0,
        "m1_consec_with": 0,
        "correction_exhaust_pct": 0.0,
    }

    closes = record.get("_m1_closes") or []
    opens = record.get("_m1_opens") or []
    highs = record.get("_m1_highs") or []
    lows = record.get("_m1_lows") or []
    if len(closes) < 8:
        # fallback depuis price_direction
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
        htf_s, hb, hbe = htf_structure_sign(record)
        if htf_s == 0:
            return out
        against = (htf_s > 0 and d1 < 0 and d3 < 0) or (htf_s < 0 and d1 > 0 and d3 > 0)
        if against:
            out["correction_stage"] = "started"
            out["correction_label"] = "CORR START"
            out["pa_in_correction"] = True
            out["correction_entry_safe"] = False
            out["correction_against"] = "BEAR" if htf_s > 0 else "BULL"
        return out

    htf_s, hb, hbe = htf_structure_sign(record)
    # Structure locale M5 si HTF neutre
    m5 = normalize_direction(record.get("tf_m5_dir"))
    if htf_s == 0:
        if m5 == "BULL":
            htf_s = 1
        elif m5 == "BEAR":
            htf_s = -1
    if htf_s == 0:
        # dernier recours : verdict
        vn = int(record.get("verdict_num", 0) or 0)
        if vn > 0:
            htf_s = 1
        elif vn < 0:
            htf_s = -1
    if htf_s == 0:
        return out

    out["correction_against"] = "BEAR" if htf_s > 0 else "BULL"  # sens de la correction

    n = len(closes)
    look = min(40, n)
    c = [float(x) for x in closes[-look:]]
    o = [float(x) for x in opens[-look:]] if opens else c[:]
    h = [float(x) for x in highs[-look:]] if highs else c[:]
    l = [float(x) for x in lows[-look:]] if lows else c[:]

    # Barres consécutives contre / avec la structure
    consec_against = 0
    consec_with = 0
    for i in range(len(c) - 1, -1, -1):
        body_up = c[i] > o[i]
        body_dn = c[i] < o[i]
        if htf_s > 0:  # structure BUY → correction = barres rouges
            if body_dn:
                if consec_with:
                    break
                consec_against += 1
            elif body_up:
                if consec_against:
                    break
                consec_with += 1
            else:
                break
        else:  # structure SELL → correction = barres vertes
            if body_up:
                if consec_with:
                    break
                consec_against += 1
            elif body_dn:
                if consec_against:
                    break
                consec_with += 1
            else:
                break
    out["m1_consec_against"] = consec_against
    out["m1_consec_with"] = consec_with

    # Impulse range récent + profondeur de pullback
    swing_hi = max(h)
    swing_lo = min(l)
    rng = swing_hi - swing_lo
    if rng <= 0:
        return out
    px = c[-1]
    if htf_s > 0:
        # pullback depuis le haut
        depth = (swing_hi - px) / rng
        # reprise = prix remonte depuis un creux local récent
        local_lo = min(l[-min(8, len(l)):])
        recovery = (px - local_lo) / rng if rng else 0.0
    else:
        depth = (px - swing_lo) / rng
        local_hi = max(h[-min(8, len(h)):])
        recovery = (local_hi - px) / rng if rng else 0.0

    depth_pct = max(0.0, min(100.0, depth * 100.0))
    out["correction_depth_pct"] = round(depth_pct, 1)

    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    flow_against = (htf_s > 0 and d1 < 0) or (htf_s < 0 and d1 > 0)
    flow_with = (htf_s > 0 and d1 > 0) or (htf_s < 0 and d1 < 0)

    stage = "none"
    label = "NO CORR"
    in_corr = False
    entry_safe = True
    exhaust = 0.0

    # finished: reprise structure après pullback (1-2 barres avec suffit pour micro-corr)
    if consec_with >= 1 and depth_pct >= 10.0 and flow_with and recovery >= 0.08:
        stage = "finished"
        label = f"CORR DONE {depth_pct:.0f}%"
        in_corr = False
        entry_safe = True
        exhaust = min(100.0, 70.0 + recovery * 100.0)
    elif consec_against >= 2 and depth_pct >= 15.0:
        in_corr = True
        if depth_pct < 30.0:
            stage = "started"
            label = f"CORR START {depth_pct:.0f}%"
            entry_safe = False
            exhaust = depth_pct * 0.5
        elif depth_pct < 55.0:
            stage = "mid"
            label = f"CORR MID {depth_pct:.0f}%"
            entry_safe = False
            exhaust = 30.0 + (depth_pct - 30.0)
        else:
            # profonde : fin si momentum adverse s'essouffle ou 1 barre with
            if consec_with >= 1 or (flow_with and abs(d1) > 0):
                stage = "ending"
                label = f"CORR END {depth_pct:.0f}%"
                entry_safe = True  # entrée possible en fin de correction
                exhaust = min(95.0, 55.0 + depth_pct * 0.4)
            else:
                stage = "mid"
                label = f"CORR DEEP {depth_pct:.0f}%"
                entry_safe = False
                exhaust = min(80.0, depth_pct)
    elif consec_against >= 1 and flow_against and depth_pct >= 8.0:
        stage = "started"
        label = f"CORR START {depth_pct:.0f}%"
        in_corr = True
        entry_safe = False
        exhaust = depth_pct * 0.4
    elif depth_pct < 8.0 and consec_with >= 1:
        stage = "none"
        label = "NO CORR"
        in_corr = False
        entry_safe = True
        exhaust = 0.0

    out["correction_stage"] = stage
    out["correction_label"] = label
    out["pa_in_correction"] = in_corr
    out["correction_entry_safe"] = entry_safe
    out["correction_exhaust_pct"] = round(exhaust, 1)
    # Aliases EA
    out["correction_phase"] = stage
    out["corr_entry_safe"] = entry_safe
    out["corr_exhaust_pct"] = round(exhaust, 1)
    return out


def apply_correction_state_to_record(record: Dict[str, Any]) -> None:
    """Injecte l'état de correction dans le record GOM (source unique)."""
    st = compute_correction_state(record)
    record.update(st)
    # Affichage TF compact
    record["tf_corr_label"] = st.get("correction_label", "NO CORR")
    record["tf_corr_stage"] = st.get("correction_stage", "none")


def enrich_m1_metrics(
    record: Dict[str, Any],
    closes: list,
    opens: list,
    highs: list,
    lows: list,
    current_price: Optional[float] = None,
    live_tick: bool = False,
) -> None:
    """Métriques M1 canoniques — source unique Python + MT5 payload."""
    if len(closes) < 6:
        return

    closes = [float(value) for value in closes]
    highs = [float(value) for value in highs]
    lows = [float(value) for value in lows]
    if live_tick and current_price is not None:
        try:
            live_price = float(current_price)
            if math.isfinite(live_price) and live_price > 0:
                closes[-1] = live_price
                highs[-1] = max(highs[-1], live_price)
                lows[-1] = min(lows[-1], live_price)
            else:
                live_tick = False
        except (TypeError, ValueError, OverflowError):
            live_tick = False

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
    record["_m1_closes"] = [float(x) for x in closes[-120:]]
    record["_m1_opens"] = [float(x) for x in opens[-120:]] if opens else []
    record["_m1_highs"] = [float(x) for x in highs[-120:]] if highs else []
    record["_m1_lows"] = [float(x) for x in lows[-120:]] if lows else []

    thr = _strong_move_threshold(record) * 0.45
    # Compte barres consécutives adverses (corps) pour détecter correction
    consec_bear = 0
    consec_bull = 0
    for i in range(1, min(6, len(closes) + 1)):
        o_f = float(opens[-i])
        c_f = float(closes[-i])
        if c_f < o_f:
            if consec_bull:
                break
            consec_bear += 1
        elif c_f > o_f:
            if consec_bear:
                break
            consec_bull += 1
        else:
            break
    record["m1_consec_sell_bars"] = consec_bear
    record["m1_consec_buy_bars"] = consec_bull

    live_bar_body = _rel(c0, float(opens[-1])) if opens else 0.0
    live_threshold = max(_strong_move_threshold(record) * 0.35, 0.00004)
    live_tick_direction = (
        1
        if live_tick
        and abs(d1) >= live_threshold
        and abs(live_bar_body) >= live_threshold
        and d1 * live_bar_body > 0
        else 0
    )
    if live_tick_direction:
        live_m1_dir = "BULL" if live_tick_direction > 0 else "BEAR"
        record["tf_m1_dir_live"] = live_m1_dir
        record["tf_m1_dir"] = live_m1_dir
        record["tf_m1_dir_live_src"] = "m1_live_tick_preclose"
        record["m1_live_impulse"] = True
    elif d1 < 0 and d3 < 0:
        record["tf_m1_dir_live"] = "BEAR"
        record["tf_m1_dir"] = "BEAR"
        record["tf_m1_dir_live_src"] = "m1_1b3b_dump"
        if d5 < 0:
            record["tf_m5_dir"] = "BEAR"
            record["tf_m5_dir_src"] = "m1_1b5b_dump"
    elif d1 > 0 and d3 > 0:
        record["tf_m1_dir_live"] = "BULL"
        record["tf_m1_dir"] = "BULL"
        record["tf_m1_dir_live_src"] = "m1_1b3b_rally"
    # FIX 2026-09-26 : correction après impulse — 2+ barres rouges + d1<0
    # → M1 = BEAR (ou NEUT si ambigu), JAMAIS BULL EMA laggué.
    elif consec_bear >= 2 and d1 < 0:
        record["tf_m1_dir_live"] = "BEAR"
        record["tf_m1_dir"] = "BEAR"
        record["tf_m1_dir_live_src"] = "m1_correction_bear_bars"
    elif consec_bull >= 2 and d1 > 0:
        record["tf_m1_dir_live"] = "BULL"
        record["tf_m1_dir"] = "BULL"
        record["tf_m1_dir_live_src"] = "m1_correction_bull_bars"
    elif record["m1_momentum"] > thr:
        record["tf_m1_dir_live"] = "BULL"
        # Ne pas écraser tf_m1_dir structurel si déjà set par MTF sauf si NEUT
        if normalize_direction(record.get("tf_m1_dir")) == "NEUT":
            record["tf_m1_dir"] = "BULL"
    elif record["m1_momentum"] < -thr:
        record["tf_m1_dir_live"] = "BEAR"
        if normalize_direction(record.get("tf_m1_dir")) == "NEUT":
            record["tf_m1_dir"] = "BEAR"
    else:
        record["tf_m1_dir_live"] = "NEUT"
        # Correction ambiguë : si EMA disait BULL mais flux plat/contre → NEUT
        prev = normalize_direction(record.get("tf_m1_dir"))
        if prev == "BULL" and (d1 < 0 or consec_bear >= 1):
            record["tf_m1_dir"] = "NEUT"
            record["tf_m1_dir_live_src"] = "m1_ema_bull_but_flat_corr"
        elif prev == "BEAR" and (d1 > 0 or consec_bull >= 1):
            record["tf_m1_dir"] = "NEUT"
            record["tf_m1_dir_live_src"] = "m1_ema_bear_but_flat_corr"

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
    bar_bull = []
    bar_bear = []
    for i in range(-min(60, len(closes)), 0):
        cl = float(closes[i])
        if cl <= 0:
            continue
        o_f = float(opens[i])
        body_pct.append(abs(float(closes[i]) - o_f) / cl)
        range_pct.append((float(highs[i]) - float(lows[i])) / cl)
        bar_bull.append(float(closes[i]) > o_f)
        bar_bear.append(float(closes[i]) < o_f)

    # FIX 2026-08-22 — chaîne de spikes M1 consécutifs (comptée même quand
    # spike_tradable=True, avant le early-return). Sert à l'uplift GOOD immédiat :
    # PainX/Crash = spikes baissiers natifs, Boom/GainX = spikes haussiers natifs.
    consec_sell = 0
    consec_buy = 0
    if body_pct:
        avg_body0 = sum(body_pct) / len(body_pct)
        avg_range0 = sum(range_pct) / len(range_pct)
        cat0 = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
        body_thr0, range_thr0 = _m1_spike_thresholds(cat0, avg_body0, avg_range0)

        def _is_spike_bar(j: int) -> bool:
            return body_pct[j] >= body_thr0 or range_pct[j] >= range_thr0

        j = len(body_pct) - 1
        while j >= 0 and _is_spike_bar(j) and bar_bear[j]:
            consec_sell += 1
            j -= 1
        j = len(body_pct) - 1
        while j >= 0 and _is_spike_bar(j) and bar_bull[j]:
            consec_buy += 1
            j -= 1
    record["m1_consec_sell_spikes"] = consec_sell
    record["m1_consec_buy_spikes"] = consec_buy

    # Soft chain: bougies directionnelles consécutives (même corps moyen) — pour uplift court
    soft_sell = 0
    soft_buy = 0
    if bar_bear:
        j = len(bar_bear) - 1
        while j >= 0 and bar_bear[j]:
            soft_sell += 1
            j -= 1
    if bar_bull:
        j = len(bar_bull) - 1
        while j >= 0 and bar_bull[j]:
            soft_buy += 1
            j -= 1
    record["m1_consec_sell_bars"] = soft_sell
    record["m1_consec_buy_bars"] = soft_buy

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
        body_thr, range_thr = _m1_spike_thresholds(cat, avg_body, avg_range)

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


def _soft_step_down(vn: int, trade_dir: int, steps: int = 1) -> int:
    """Rétrograde progressif : PERFECT→GOOD→SIMPLE, jamais de saut direct à WAIT."""
    if vn == 0:
        return 0
    mag = abs(int(vn))
    mag = max(1, mag - max(1, int(steps)))  # floor SIMPLE (|vn|=1), pas 0
    return trade_dir * mag


def _soft_step_up(vn: int, trade_dir: int, steps: int = 1) -> int:
    """Progression graduelle : SIMPLE->GOOD->PERFECT, plafonné à |vn|=3."""
    if vn == 0:
        return trade_dir * min(3, max(1, int(steps)))
    mag = abs(int(vn))
    mag = min(3, mag + max(1, int(steps)))
    return trade_dir * mag


def apply_chartist_confluence(record: Dict[str, Any], verdict_num: int) -> Tuple[int, str]:
    """Renforce/atténue (jamais n'inverse) le verdict GOM avec la confluence
    des figures chartistes calculée par chartist_patterns.compute_chartist_verdict()
    (SMC_OTE en tête, cf chartist_patterns.py v2 - 2026-09).

    Champs attendus dans `record` (à renseigner côté ai_server, juste après
    l'appel à chartist_patterns.analyze_symbol_candles(), AVANT ce gate) :
      - chartist_verdict_num          : int, -3..+3 (même échelle que verdict_num)
      - chartist_ote_confirmed_buy    : bool
      - chartist_ote_confirmed_sell   : bool

    Le score/MTF du GOM principal reste maître du sens : ce gate ne renverse
    jamais le signe de verdict_num, il ne fait que :
      - renforcer d'un cran (plafonné à PERFECT) si le chartiste est dans le
        même sens ET qu'une figure SMC_OTE confirmée soutient ce sens ;
      - affaiblir d'un cran (jamais de saut direct à WAIT) si le chartiste
        est GOOD/PERFECT dans le sens opposé et que le GOM principal est
        déjà au moins GOOD dans son propre sens (désaccord réel, pas juste
        du bruit) ;
      - laisser inchangé sinon (chartiste WAIT, absent, ou désaccord faible).
    """
    vn = int(verdict_num or 0)
    if vn == 0:
        return 0, ""
    if "chartist_verdict_num" not in record:
        return vn, ""
    try:
        cvn = int(record.get("chartist_verdict_num", 0) or 0)
    except (TypeError, ValueError):
        return vn, ""
    if cvn == 0:
        return vn, ""

    trade_dir = 1 if vn > 0 else -1
    c_dir = 1 if cvn > 0 else -1
    ote_confirmed_this_dir = bool(
        record.get("chartist_ote_confirmed_buy") if trade_dir > 0
        else record.get("chartist_ote_confirmed_sell")
    )

    if c_dir == trade_dir:
        if ote_confirmed_this_dir and abs(vn) < 3:
            new_vn = _soft_step_up(vn, trade_dir, 1)
            return new_vn, f"chartist_OTE_confirmed->{abs(new_vn)}"
        return vn, "chartist_aligned"

    # Désaccord de sens : on n'affaiblit que si les deux côtés sont
    # significatifs (évite de casser un signal GOM solide sur du bruit chartiste)
    if abs(cvn) >= 2 and abs(vn) >= 2:
        new_vn = _soft_step_down(vn, trade_dir, 1)
        return new_vn, f"chartist_opposed({cvn})->step_down"
    return vn, "chartist_opposed_weak_ignored"



def apply_family_native_impulse(record: Dict[str, Any], verdict_num: int) -> int:
    """FIX 2026-09-23: GainX/Boom = spikes haussiers, PainX/Crash = baissiers.

    Si le prix M1 montre déjà une impulsion dans le sens NATIF de la famille
    (ex: GainX + bougies vertes / chain UP), on ne doit PAS rester en WAIT
    ni en SELL. On force au minimum GOOD dans le sens natif.

    Cas chart GainX 800: spikes BUY déjà en cours, GOM affichait WAIT vn=-3.
    """
    vn = int(verdict_num or 0)
    sym = str(record.get("symbol", "") or "")
    is_buy_family = GOMLPineCalculator.is_boom_like_symbol(sym)  # GainX / Boom
    is_sell_family = GOMLPineCalculator.is_crash_like_symbol(sym)  # PainX / Crash
    if not is_buy_family and not is_sell_family:
        return vn

    d1 = float(record.get("price_direction_1b", 0) or 0)
    last_up = d1 > 0
    last_dn = d1 < 0

    # Loi famille ABSOLUE : GainX/Boom n'est JAMAIS SELL. PainX/Crash JAMAIS BUY.
    # Dump GainX → WAIT (pas PERFECT SELL, et PAS de BUY en correction).
    if is_buy_family:
        d3 = float(record.get("price_direction_3b", 0) or 0)
        d5 = float(record.get("price_direction_5b", 0) or 0)
        dow = resolve_dow_direction(record)
        dump = last_dn and d3 < 0
        rally = last_up and d3 > 0
        if vn < 0:
            record["family_impulse_reason"] = f"GainX/Boom block SELL vn={vn}→0"
            print(f"[FAMILY-IMPULSE] {sym}: {record['family_impulse_reason']}")
            vn = 0
        if dump or dow == "BEAR":
            if vn > 0:
                record["family_impulse_reason"] = (
                    f"GainX/Boom dump/DOW BEAR blocks BUY vn={vn}→WAIT "
                    f"(d1={d1:.5f} d3={d3:.5f} dow={dow})"
                )
                print(f"[FAMILY-IMPULSE] {sym}: {record['family_impulse_reason']}")
                return 0
            return 0
        if rally and dow != "BEAR" and d5 >= 0:
            if vn < 2:
                record["family_impulse_reason"] = f"GainX/Boom native UP → vn {vn}→2 (d1={d1:.5f})"
                print(f"[FAMILY-IMPULSE] {sym}: {record['family_impulse_reason']}")
                return 2
            return vn
        return vn

    if is_sell_family:
        d3 = float(record.get("price_direction_3b", 0) or 0)
        d5 = float(record.get("price_direction_5b", 0) or 0)
        m1 = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "").upper()
        real_dump = last_dn and d3 < 0
        bounce = last_up and d3 > 0
        if vn > 0:
            record["family_impulse_reason"] = f"PainX/Crash block BUY vn={vn}→0"
            print(f"[FAMILY-IMPULSE] {sym}: {record['family_impulse_reason']}")
            return 0
        if real_dump:
            record["tf_m1_dir_live"] = "BEAR"
            record["tf_m1_dir"] = "BEAR"
            mag = 2
            bos = bool(record.get("bos_bear"))
            ss = float(record.get("score_sell", 0) or 0)
            sb = float(record.get("score_buy", 0) or 0)
            if d5 <= 0 and (bos or ss >= sb or m1 in ("BEAR", "SELL", "DOWN")):
                mag = 3
            if vn > -mag:
                record["family_impulse_reason"] = (
                    f"PainX/Crash native DOWN → vn {vn}→{-mag} "
                    f"(d1={d1:.5f} d3={d3:.5f} d5={d5:.5f})"
                )
                print(f"[FAMILY-IMPULSE] {sym}: {record['family_impulse_reason']}")
                return -mag
            return vn
        if bounce or (m1 in ("BULL", "BUY", "UP") and not last_dn):
            if vn < 0:
                record["family_impulse_reason"] = f"PainX/Crash M1 haussier (3 Soldiers) — SELL {vn}→WAIT"
                print(f"[FAMILY-IMPULSE] {sym}: {record['family_impulse_reason']}")
                return 0
            return vn
        ss = float(record.get("score_sell", 0) or 0)
        sb = float(record.get("score_buy", 0) or 0)
        dow = resolve_dow_direction(record)
        struct_sell = bool(record.get("bos_bear")) or dow == "BEAR" or ss >= sb + 1.2
        if struct_sell and vn > -2:
            record["family_impulse_reason"] = (
                f"PainX/Crash structure SELL (bos/dow/scores) vn {vn}→-2"
            )
            print(f"[FAMILY-IMPULSE] {sym}: {record['family_impulse_reason']}")
            return -2
        return vn

    return vn



def apply_mtf_structure_floor(record: Dict[str, Any], verdict_num: int) -> int:
    """Plancher structurel MTF — interdit WAIT absurde sur tendance claire.

    FIX 2026-09-24 (Sidoine) : si ≥4 TF (M1..D1) sont alignés dans le même
    sens ET le flux M1 3b n'est PAS contre, on ne reste JAMAIS en WAIT.
    - ≥5 TF ou gap scores confortable → plancher GOOD (±2)
    - sinon → plancher SIMPLE (±1)
    RSI extrême / micro-range ne peuvent plus annuler une tendance structurelle.
    Contre-impulsion réelle (1b+3b contre) : pas de plancher (WAIT OK).
    """
    vn = int(verdict_num or 0)

    def _dir(v: Any) -> str:
        return normalize_direction(v)

    dirs = [
        _dir(record.get("tf_m1_dir_live") or record.get("tf_m1_dir")),
        _dir(record.get("tf_m5_dir")),
        _dir(record.get("tf_m15_dir")),
        _dir(record.get("tf_h1_dir")),
        _dir(record.get("tf_h4_dir")),
        _dir(record.get("tf_d1_dir")),
    ]
    bulls = sum(1 for d in dirs if d == "BULL")
    bears = sum(1 for d in dirs if d == "BEAR")

    try:
        d1 = float(record.get("price_direction_1b", 0) or 0)
        d3 = float(record.get("price_direction_3b", 0) or 0)
        d5 = float(record.get("price_direction_5b", 0) or 0)
    except (TypeError, ValueError):
        d1 = d3 = d5 = 0.0

    sb = float(record.get("score_buy", 0) or 0)
    ss = float(record.get("score_sell", 0) or 0)
    gap = abs(sb - ss)
    _sym = str(record.get("symbol", "") or "")

    # Dump PainX/Crash live : labels MTF BULL laggués ne justifient pas WAIT.
    if GOMLPineCalculator.is_crash_like_symbol(_sym) and d1 < 0 and d3 < 0:
        mag = 3 if d5 <= 0 else 2
        record["mtf_floor_reason"] = f"crash_live_dump_floor_{mag}"
        if vn > 0:
            return 0
        if vn > -mag:
            return -mag
        return vn
    if GOMLPineCalculator.is_boom_like_symbol(_sym):
        _hs, _hb, _hbe = htf_structure_sign(record)
        if d1 < 0 and d3 < 0:
            if _hs > 0 and _hb >= 3:
                mag = 3 if (_hb >= 4 and gap >= 2.5) else 2
                record["mtf_floor_reason"] = f"boom_micro_dump_htf_BUY_floor_{mag}"
                if vn < 0:
                    return 0
                if vn < mag:
                    return mag
                return vn
            record["mtf_floor_reason"] = "boom_live_dump_no_BUY_floor"
            return 0 if vn > 0 else vn
        dow_fl = resolve_dow_direction(record)
        if dow_fl == "BEAR" and not (_hs > 0 and _hb >= 3):
            record["mtf_floor_reason"] = "boom_dow_BEAR_no_BUY_floor"
            return 0 if vn > 0 else vn
        if d1 > 0 and d3 > 0:
            mag = 3 if d5 >= 0 else 2
            record["mtf_floor_reason"] = f"boom_live_rally_floor_{mag}"
            if vn < 0:
                return 0
            if vn < mag:
                return mag
            return vn

    # Uptrend structurel
    # FIX 2026-09-26 : micro-corr M1 (dump) ne bloque plus le plancher BUY.
    if bulls >= 4 and bears <= 1:
        m5 = normalize_direction(record.get("tf_m5_dir"))
        micro = is_m1_microcorrection_against(record, 1)
        real_inversion = (m5 == "BEAR" and d1 < 0 and d3 < 0 and not micro)
        if real_inversion:
            record["mtf_floor_reason"] = f"MTF_BULL_{bulls}/6_real_m5_inversion"
            if vn > 0:
                return min(vn, 1)
            return 0 if vn < 0 else vn
        dow = resolve_dow_direction(record)
        if dow == "BEAR" and bulls < 5:
            mag = 1
            record["mtf_floor_reason"] = f"MTF_BULL_{bulls}/6_dow_BEAR->SIMPLE"
        else:
            if bulls >= 5 and (gap >= 2.5 or sb >= ss + 1.5):
                mag = 3
            elif bulls >= 5 or gap >= 1.2 or sb >= ss:
                mag = 2
            else:
                mag = 1
            tag = "micro_kept" if micro else "floor"
            record["mtf_floor_reason"] = f"MTF_BULL_{bulls}/6_{tag}_{mag}"
        if vn <= 0 or abs(vn) < mag:
            return mag
        return vn

    # Downtrend structurel
    # FIX 2026-09-26 : micro-corr M1 (rallye) ne bloque plus le plancher SELL.
    # Seule une inversion M5 réelle rétrograde.
    htf_sign, htf_bulls, htf_bears = htf_structure_sign(record)
    structural_bear = (bears >= 4 and bulls <= 1) or (htf_sign < 0 and htf_bears >= 3)
    if structural_bear:
        m5 = normalize_direction(record.get("tf_m5_dir"))
        micro = is_m1_microcorrection_against(record, -1)
        real_inversion = (m5 == "BULL" and d1 > 0 and d3 > 0 and not micro)
        if real_inversion:
            record["mtf_floor_reason"] = f"MTF_BEAR_{bears}/6_real_m5_inversion"
            if vn < 0:
                return max(vn, -1)
            return 0 if vn > 0 else vn
        dow = resolve_dow_direction(record)
        if dow == "BULL" and bears < 5 and htf_bears < 4:
            mag = 1
            record["mtf_floor_reason"] = f"MTF_BEAR_{bears}/6_dow_BULL->SIMPLE"
        else:
            if (bears >= 5 or htf_bears >= 4) and (gap >= 2.5 or ss >= sb + 1.5):
                mag = 3
            elif bears >= 5 or htf_bears >= 4 or gap >= 1.2 or ss >= sb:
                mag = 2
            else:
                mag = 1
            tag = "micro_kept" if micro else "floor"
            record["mtf_floor_reason"] = f"MTF_BEAR_{bears}/6_{tag}_{mag}"
        if vn >= 0 or abs(vn) < mag:
            return -mag
        return vn

    # Uptrend structurel avec micro-corr (symétrique)
    structural_bull = (bulls >= 4 and bears <= 1) or (htf_sign > 0 and htf_bulls >= 3)
    if structural_bull and not (bulls >= 4 and bears <= 1):
        # déjà traité ci-dessus si bulls>=4 ; ici HTF-only
        m5 = normalize_direction(record.get("tf_m5_dir"))
        micro = is_m1_microcorrection_against(record, 1)
        real_inversion = (m5 == "BEAR" and d1 < 0 and d3 < 0 and not micro)
        if real_inversion:
            record["mtf_floor_reason"] = f"MTF_BULL_htf_real_m5_inversion"
            if vn > 0:
                return min(vn, 1)
            return 0 if vn < 0 else vn
        if (htf_bulls >= 4) and (gap >= 2.5 or sb >= ss + 1.5):
            mag = 3
        elif htf_bulls >= 3 or gap >= 1.2 or sb >= ss:
            mag = 2
        else:
            mag = 1
        tag = "micro_kept" if micro else "floor"
        record["mtf_floor_reason"] = f"MTF_BULL_htf_{tag}_{mag}"
        if vn <= 0 or abs(vn) < mag:
            return mag
        return vn

    return vn


def apply_price_reality_gate(record: Dict[str, Any], verdict_num: int) -> Tuple[int, str]:
    """Empêche PERFECT/GOOD figés contre l'évolution réelle M1.

    FIX 2026-08-28 (v1.25j) — micro-corrections :
    - Ne passent PLUS en WAIT directement.
    - Rétrograde d'un cran : PERFECT→GOOD→SIMPLE (sens conservé).
    - WAIT uniquement si inversion structurelle forte (score + multi-TF + move).
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

    sb = float(record.get("score_buy", 0) or 0)
    ss = float(record.get("score_sell", 0) or 0)
    score_supports = (trade_dir > 0 and sb >= ss) or (trade_dir < 0 and ss >= sb)
    score_strong = (trade_dir > 0 and sb >= ss + 1.5) or (trade_dir < 0 and ss >= sb + 1.5)

    if bars >= 0:
        if is_synth:
            if bars > 12 and abs(vn) >= 3:
                vn = _soft_step_down(vn, trade_dir, 1)
                reasons.append(f"stale_spike>{bars}->step")
            if bars > 20 and abs(vn) >= 2:
                vn = _soft_step_down(vn, trade_dir, 1)
                reasons.append(f"stale_spike>{bars}->SIMPLE")
            if bars > 40 and abs(vn) >= 1 and not score_supports:
                return 0, f"bars_since_spike={bars}>40_no_score_WAIT"
        else:
            if bars > 30 and abs(vn) >= 2 and not score_supports:
                return 0, f"bars_since_spike={bars}>30"
            if bars > 22 and abs(vn) >= 3:
                vn = _soft_step_down(vn, trade_dir, 1)
                reasons.append(f"stale_spike>{bars}->GOOD")
            elif bars > 18 and abs(vn) >= 2:
                vn = _soft_step_down(vn, trade_dir, 1)
                reasons.append(f"stale_spike>{bars}->SIMPLE")
            elif bars > 14 and abs(vn) >= 3:
                vn = _soft_step_down(vn, trade_dir, 1)
                reasons.append(f"stale_spike>{bars}->GOOD")

    m1 = str(record.get("tf_m1_dir_live") or record.get("tf_m1_dir") or "").upper()
    m1_against = (trade_dir > 0 and m1 in ("BEAR", "SELL")) or (trade_dir < 0 and m1 in ("BULL", "BUY"))
    m1_aligned = (trade_dir > 0 and m1 in ("BULL", "BUY")) or (trade_dir < 0 and m1 in ("BEAR", "SELL"))

    strong = _strong_move_threshold(record)
    price_dir = _price_direction_5b(record)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d1 = float(record.get("price_direction_1b", 0) or 0)
    mom = float(record.get("m1_momentum", price_dir) or 0)
    dow = resolve_dow_direction(record)

    # Invalidation instantanée : BUY figé contre dump M1 + Dow SELL.
    # FIX 2026-09-26 : ne PAS invalider si structure HTF soutient encore le trade.
    _htf_inv, _hb_inv, _hbe_inv = htf_structure_sign(record)
    htf_ok_for_buy = _htf_inv > 0 and _hb_inv >= 3
    htf_ok_for_sell = _htf_inv < 0 and _hbe_inv >= 3
    _early_htf_keep = (
        (trade_dir < 0 and htf_ok_for_sell) or (trade_dir > 0 and htf_ok_for_buy)
    ) and is_m1_microcorrection_against(record, trade_dir)

    if (
        trade_dir > 0
        and (m1 in ("BEAR", "SELL") or dow == "BEAR")
        and d1 < -strong
        and d3 < -strong
        and not htf_ok_for_buy
    ):
        return 0, "dow_sell_reality"
    if (
        trade_dir < 0
        and (m1 in ("BULL", "BUY") or dow == "BULL")
        and d1 > strong
        and d3 > strong
        and not htf_ok_for_sell
    ):
        return 0, "dow_buy_reality"

    # FIX 2026-09-05: sur synth (PainX PRE-SPIKE haussier / GainX baissier),
    # un move fort contre le sens natif est NORMAL avant le spike — ne pas
    # écraser PERFECT/GOOD en WAIT. Step-down max, floor GOOD si scores OK.
    if trade_dir > 0 and (price_dir < -strong or d3 < -strong * 0.85):
        if abs(price_dir) > strong * 1.8 and not score_supports and not is_synth:
            return 0, "price_strong_down_vs_buy_no_score"
        if not _early_htf_keep:
            vn = _soft_step_down(vn, trade_dir, 1)
            live_dump = d1 < 0 and d3 < 0
            if is_synth and score_supports and abs(vn) < 2 and not live_dump:
                if dow != "BEAR" and m1_m5_trend_sign(record) >= 0:
                    vn = trade_dir * 2
            reasons.append("price_down->step")
        else:
            reasons.append("price_down_htf_kept")
    if trade_dir < 0 and (price_dir > strong or d3 > strong * 0.85):
        if abs(price_dir) > strong * 1.8 and not score_supports and not is_synth:
            return 0, "price_strong_up_vs_sell_no_score"
        if not _early_htf_keep:
            vn = _soft_step_down(vn, trade_dir, 1)
            live_rally = d1 > 0 and d3 > 0
            if is_synth and score_supports and abs(vn) < 2 and not live_rally:
                if dow != "BULL" and m1_m5_trend_sign(record) <= 0:
                    vn = trade_dir * 2
            reasons.append("price_up->step")
        else:
            reasons.append("price_up_htf_kept")

    if abs(vn) >= 3 and ((trade_dir > 0 and mom < -strong * 0.5) or (trade_dir < 0 and mom > strong * 0.5)):
        if not _early_htf_keep:
            vn = _soft_step_down(vn, trade_dir, 1)
            reasons.append("m1_momentum_vs_perfect")
        else:
            reasons.append("m1_momentum_htf_kept")

    if abs(vn) >= 2 and ((trade_dir > 0 and d1 < -strong * 0.55) or (trade_dir < 0 and d1 > strong * 0.55)):
        if not (is_synth and m1_aligned) and not _early_htf_keep:
            vn = _soft_step_down(vn, trade_dir, 1)
            reasons.append("m1_1b_against->step")
        elif _early_htf_keep:
            reasons.append("m1_1b_against_htf_kept")

    try:
        opp = int(record.get("m1_opp_bars", record.get("m1_adverse_bars", 0)) or 0)
    except (TypeError, ValueError):
        opp = 0

    # FIX: synth spike (GainX/PainX/Boom/Crash) — barres adverses entre spikes = comportement normal.
    # Ne plus rétrograder GOOD/PERFECT vers SIMPLE pour opp ≤ 6 ; si score supporte le sens,
    # maintenir un plancher GOOD (cohérent avec le "floor_GOOD_score_alive" existant).
    #
    # FIX 2026-09-15 : seuils alignés pour non-synthétiques (forex/métaux/.C).
    # Avant, opp_thr=2 rétrogradait immédiatement GOOD→SIMPLE dès 3 barres M1
    # adverses — bruit micro-structure normal en forex — donc aucune paire .C
    # du compte CENT n'atteignait jamais |vn|>=2 et entry_allowed restait False.
    opp_thr_synth = 6 if is_synth else 6
    opp_floor_synth = 9 if is_synth else 9
    if opp >= opp_thr_synth:
        vn = _soft_step_down(vn, trade_dir, 1)
        reasons.append(f"micro_stairs_opp={opp}->step(thr={opp_thr_synth})")
    if opp >= opp_floor_synth and m1_against and not score_strong:
        vn = _soft_step_down(vn, trade_dir, 1)
        reasons.append(f"micro_stairs_opp={opp}->SIMPLE_floor(thr={opp_floor_synth})")
    if is_synth and score_supports and abs(vn) < 2 and (vn * trade_dir) > 0:
        live_against = (trade_dir > 0 and d1 < 0 and d3 < 0) or (
            trade_dir < 0 and d1 > 0 and d3 > 0
        )
        if live_against:
            reasons.append("no_synth_floor_GOOD_live_against")
        elif not ((dow == "BEAR" and trade_dir > 0) or (dow == "BULL" and trade_dir < 0)):
            vn = trade_dir * 2  # floor GOOD synth
            reasons.append(f"micro_stairs_opp={opp}->synth_floor_GOOD")
    if opp >= 8 and not score_supports and m1_against and not is_synth:
        return 0, f"micro_stairs_opp={opp}_score_dead_WAIT"
    if opp >= 8 and is_synth and score_supports:
        if not ((dow == "BEAR" and trade_dir > 0) or (dow == "BULL" and trade_dir < 0)):
            vn = trade_dir * max(1, min(abs(vn), 2))
            reasons.append(f"micro_stairs_opp={opp}->synth_floor")

    soft_thr = strong * 0.50
    soft_buy = int(record.get("m1_consec_buy_bars", 0) or 0)
    soft_sell = int(record.get("m1_consec_sell_bars", 0) or 0)

    mild_against = False
    if trade_dir < 0 and (m1 in ("BULL", "BUY") or d3 > soft_thr or soft_buy >= 2):
        mild_against = True
    if trade_dir > 0 and (m1 in ("BEAR", "SELL") or d3 < -soft_thr or soft_sell >= 2):
        mild_against = True

    # FIX 2026-09-26 : micro-corr M1 + HTF aligné → ne pas rétrograder
    if mild_against and not _early_htf_keep:
        vn = _soft_step_down(vn, trade_dir, 1)
        reasons.append("m1_micro_corr->step")
    elif mild_against and _early_htf_keep:
        reasons.append("m1_micro_corr_htf_kept")

    m5 = str(record.get("tf_m5_dir") or "").upper()
    m5_against = (trade_dir > 0 and m5 in ("BEAR", "SELL")) or (trade_dir < 0 and m5 in ("BULL", "BUY"))
    if mild_against and m5_against and not score_supports and (soft_buy >= 4 or soft_sell >= 4 or opp >= 6):
        if is_synth and score_supports:
            vn = trade_dir * 2
            reasons.append("structure_reverse_but_synth_score_floor_GOOD")
        else:
            return 0, "structure_reverse_M1M5_score_dead_WAIT"

    # FIX 2026-09-07: GOOD/PERFECT exigent une impulsion réelle M1. Si le
    # M1 est plat (dir NEUT + momentum nul + pas de spike récent), rétrograder
    # vers SIMPLE (sens conservé) — jamais WAIT, jamais GOOD/PERFECT figé.
    #
    # FIX 2026-09-15 : réservé aux synthétiques Boom/Crash/PainX/GainX/Vol.
    # Pour les actifs non synthétiques (forex/métaux/indices/crypto, y compris
    # les paires .C du compte CENT Weltrade), un M1 neutre est une consolidation
    # normale : ne pas rétrograder GOOD/PERFECT → SIMPLE, sinon aucune paire .C
    # n'atteint jamais |vn| >= 2 et entry_allowed reste toujours False.
    cat = GOMLPineCalculator.symbol_asset_category(str(record.get("symbol", "")))
    if not (cat in ("boom_crash", "volatility")):
        pass
    else:
        m1_live = str(record.get("tf_m1_dir_live") or "").upper()
        spike_recent = (
            (0 <= bars <= 8)
            or bool(record.get("spike_tradable"))
            or float(record.get("spike_prob", 0) or 0) >= 0.55
        )
        if (
            "tf_m1_dir_live" in record
            and m1_live in ("NEUT", "NEUTRAL")
            and abs(mom) < strong * 0.45
            and abs(price_dir) < strong
            and not spike_recent
            and abs(vn) >= 2
        ):
            vn = trade_dir * 1
            reasons.append("flat_m1_no_impulse->SIMPLE")

    # FIX 2026-09-17d (Sidoine): PainX/Crash — interdire PERFECT/GOOD SELL
    # contre une impulsion M1 haussière claire (pre-spike = montée).
    if is_synth and trade_dir < 0:
        strong_bull_impulse = (
            m1 in ("BULL", "BUY")
            and (mom > strong * 0.55 or d3 > strong * 0.50 or price_dir > strong * 0.45)
        )
        if strong_bull_impulse and abs(vn) >= 1:
            if _early_htf_keep or htf_ok_for_sell:
                reasons.append("painx_bull_impulse_htf_kept")
            else:
                vn = 0
                reasons.append("painx_strong_bull_impulse->WAIT")

    # FIX 2026-09-17d: GainX/Boom — miroir
    if is_synth and trade_dir > 0:
        strong_bear_impulse = (
            (m1 in ("BEAR", "SELL") or dow == "BEAR")
            and (mom < -strong * 0.55 or d3 < -strong * 0.50 or price_dir < -strong * 0.45)
        )
        if strong_bear_impulse and abs(vn) >= 1:
            if _early_htf_keep or htf_ok_for_buy:
                reasons.append("gainx_bear_impulse_htf_kept")
            else:
                vn = 0
                reasons.append("gainx_strong_bear_impulse->WAIT")

    dow_blocks_buy_floor = dow == "BEAR" and trade_dir > 0
    dow_blocks_sell_floor = dow == "BULL" and trade_dir < 0
    _trend = m1_m5_trend_sign(record)
    trend_blocks_sell_floor = _trend > 0 and trade_dir < 0
    trend_blocks_buy_floor = _trend < 0 and trade_dir > 0
    impulse_wait = (
        "painx_strong_bull_impulse->WAIT" in reasons
        or "gainx_strong_bear_impulse->WAIT" in reasons
    )
    block_restore = (
        impulse_wait or dow_blocks_buy_floor or dow_blocks_sell_floor
        or trend_blocks_sell_floor or trend_blocks_buy_floor
    )

    if vn == 0 and score_supports:
        if block_restore:
            pass
        else:
            vn = trade_dir * (2 if is_synth else 1)
            reasons.append("floor_GOOD_score_alive" if is_synth else "floor_SIMPLE_score_alive")

    if is_synth and vn == 0 and score_supports:
        if block_restore:
            pass
        else:
            vn = trade_dir * 2
            reasons.append("synth_anti_wait_floor_GOOD")

    aligned = apply_trend_alignment_verdict(record, vn)
    if aligned != vn:
        a_sign = 1 if aligned > 0 else (-1 if aligned < 0 else 0)
        m1_blocks_align = (
            (a_sign > 0 and d1 < 0 and d3 < 0)
            or (a_sign < 0 and d1 > 0 and d3 > 0)
        )
        if m1_blocks_align:
            reasons.append("trend_align_skipped_m1_against")
        else:
            reasons.append(str(record.get("trend_align_reason") or "m1m5_trend_align"))
            vn = aligned

    vn = apply_price_impulse_cap(record, vn)
    if record.get("impulse_cap_reason"):
        reasons.append(str(record.get("impulse_cap_reason")))

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
    Convertit la sortie du forecast heuristique M1 en niveau de confirmation 5m.
    Cette valeur est un filtre de confirmation, pas une probabilité calibrée.
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


def forecast_display_signal_num(
    execution_verdict_num: Any,
    forecast_verdict_num: Any,
    *,
    market_price_fresh: bool,
    forecast_ready: bool,
    horizon_minutes: Any,
) -> int:
    """Expose a fresh 5m forecast as SIMPLE for display only when GOM is WAIT."""
    try:
        execution_vn = int(execution_verdict_num or 0)
        forecast_vn = int(forecast_verdict_num or 0)
        horizon = int(horizon_minutes or 0)
    except (TypeError, ValueError, OverflowError):
        return 0
    if execution_vn != 0 or not market_price_fresh or not forecast_ready or horizon != 5:
        return 0
    return 1 if forecast_vn > 0 else -1 if forecast_vn < 0 else 0


def apply_current_market_forecast_gate(
    record: Dict[str, Any],
    verdict_num: int,
    max_price_age_sec: float = 90.0,
) -> Tuple[int, str]:
    """Use fresh M1 structure as the scalp authority; strong 5m opposition vetoes.

    The forecast may cap or veto a reactive verdict, but it never creates or
    strengthens one. Missing 5m data does not by itself block a live M1 signal.
    """
    vn = max(-3, min(3, int(verdict_num or 0)))
    record["m1_scalp_simple_allowed"] = False
    record["m1_scalp_structure_confirmed"] = m1_scalp_structure_confirmed(
        record, 1 if vn > 0 else -1 if vn < 0 else 0
    )
    try:
        price = float(record.get("market_price", record.get("current_price", 0)) or 0)
    except (TypeError, ValueError):
        price = 0.0
    fresh_flag = record.get("market_price_fresh") is True or str(
        record.get("market_price_fresh", "")
    ).strip().lower() in ("1", "true", "yes")
    raw_time = record.get("market_price_time")
    timestamp = None
    try:
        if isinstance(raw_time, (int, float)):
            stamp = float(raw_time)
            if stamp > 1e17:
                stamp /= 1e9
            elif stamp > 1e14:
                stamp /= 1e6
            elif stamp > 1e11:
                stamp /= 1e3
            timestamp = datetime.fromtimestamp(stamp, tz=timezone.utc)
        elif raw_time:
            timestamp = datetime.fromisoformat(str(raw_time).replace("Z", "+00:00"))
            if timestamp.tzinfo is None:
                timestamp = timestamp.replace(tzinfo=timezone.utc)
            else:
                timestamp = timestamp.astimezone(timezone.utc)
    except (OverflowError, OSError, TypeError, ValueError):
        timestamp = None

    age_sec = (
        (datetime.now(timezone.utc) - timestamp).total_seconds()
        if timestamp is not None else None
    )
    source = str(record.get("market_price_source") or "")
    unnormalized_live = "unnormalized" in source
    if unnormalized_live and math.isfinite(price) and price > 0:
        if age_sec is None or not (-5.0 <= age_sec <= max_price_age_sec):
            age_sec = 0.0
        price_is_fresh = True
    else:
        price_is_fresh = (
            fresh_flag
            and math.isfinite(price)
            and price > 0
            and age_sec is not None
            and -5.0 <= age_sec <= max_price_age_sec
        )
    record["market_price_fresh"] = price_is_fresh
    if age_sec is not None:
        record["market_price_age_sec"] = round(age_sec, 2)
    if not price_is_fresh:
        record["market_timing_status"] = "WAIT_PRICE_STALE"
        return 0, "m1_market_price_missing_or_stale"

    if vn == 0:
        record["market_timing_status"] = "WAIT_REACTIVE_VERDICT"
        return 0, ""

    try:
        horizon = int(record.get("forecast_horizon_minutes", 0) or 0)
        forecast_vn = max(-3, min(3, int(record.get("forecast_verdict_num", 0) or 0)))
    except (TypeError, ValueError):
        horizon, forecast_vn = 0, 0
    forecast_ready = horizon == 5 and record.get("cog_forecast_ready") is True
    if not forecast_ready or forecast_vn == 0:
        record["market_timing_status"] = "M1_SCALP_NO_5M_CONFIRMATION"
        if abs(vn) >= 2:
            return vn, "5m_forecast_unavailable_keep_gom"
        if abs(vn) == 1:
            confirmed = m1_scalp_structure_confirmed(record, vn)
            record["m1_scalp_simple_allowed"] = confirmed
            return vn, "5m_forecast_unavailable"
        return vn, "5m_forecast_unavailable" if not forecast_ready else "5m_forecast_unconfirmed"
    if (vn > 0) != (forecast_vn > 0):
        if abs(forecast_vn) >= 2:
            if abs(vn) >= 2:
                record["market_timing_status"] = "KEEP_GOM_5M_OPPOSES"
                return vn, "5m_forecast_opposes_keep_gom"
            record["market_timing_status"] = "WAIT_5M_FORECAST_OPPOSES"
            return 0, "5m_forecast_opposes_reactive_verdict"
        if m1_scalp_structure_confirmed(record, vn):
            record["m1_scalp_simple_allowed"] = True
            record["market_timing_status"] = "M1_SCALP_WEAK_5M_OPPOSITION"
            return (1 if vn > 0 else -1), "weak_opposing_5m_m1_structure"
        if _weak_opposing_forecast_has_native_spike_htf_confirmation(
            record, vn, forecast_vn
        ):
            record["spike_htf_simple_allowed"] = True
            record["market_timing_status"] = "WEAK_OPPOSING_5M_SPIKE_HTF_SIMPLE"
            return (1 if vn > 0 else -1), "weak_opposing_5m_with_native_spike_htf"
        record["market_timing_status"] = "WAIT_5M_FORECAST_OPPOSES"
        return 0, "5m_forecast_opposes_reactive_verdict"

    if abs(vn) >= 2:
        gated_vn = vn
    else:
        gated_vn = (1 if vn > 0 else -1) * min(abs(vn), abs(forecast_vn))
    if abs(gated_vn) == 1:
        confirmed = m1_scalp_structure_confirmed(record, gated_vn)
        record["m1_scalp_simple_allowed"] = confirmed
        if not confirmed:
            record["market_timing_status"] = "WAIT_M1_STRUCTURE_UNCONFIRMED"
            return 0, "m1_scalp_structure_unconfirmed"
    record["market_timing_status"] = (
        "CONFIRMED_5M" if gated_vn == vn else "CAPPED_BY_5M_FORECAST"
    )
    return gated_vn, (
        "5m_forecast_confirms" if gated_vn == vn else "5m_forecast_magnitude_cap"
    )


def _weak_opposing_forecast_has_native_spike_htf_confirmation(
    record: Dict[str, Any],
    verdict_num: int,
    forecast_num: int,
) -> bool:
    """Allow only SIMPLE for weak forecast conflict with native HTF spike proof."""
    if abs(forecast_num) != 1 or verdict_num == 0:
        return False

    symbol = str(record.get("symbol", "") or "")
    if GOMLPineCalculator.is_boom_like_symbol(symbol):
        native_dir, native_tf = 1, "BULL"
    elif GOMLPineCalculator.is_crash_like_symbol(symbol):
        native_dir, native_tf = -1, "BEAR"
    else:
        return False
    if (verdict_num > 0) != (native_dir > 0):
        return False
    if (
        normalize_direction(record.get("tf_d1_dir")) != native_tf
        or normalize_direction(record.get("tf_h4_dir")) != native_tf
    ):
        return False

    chain_dir = normalize_direction(
        record.get("spike_chain_direction") or record.get("chain_direction")
    )
    chain_active = bool(
        record.get("spike_chain_active")
        or record.get("chain_active")
    ) and chain_dir == native_tf
    try:
        strong_bars = int(record.get("spike_chain_strong_bars", 0) or 0)
    except (TypeError, ValueError):
        strong_bars = 0
    chain_confirmed = chain_active and strong_bars >= 2
    spike_confirmed = (
        record.get("spike_tradable") is True
        or str(record.get("spike_tradable", "")).strip().lower() in ("1", "true", "yes")
    )
    return chain_confirmed or spike_confirmed


def blend_reactive_forecast_verdict(
    reactive_vn: int,
    forecast_vn: int,
    forecast_confidence: float = 0.0,
    forecast_agreement: float = 0.0,
    record: Optional[Dict[str, Any]] = None,
) -> Tuple[int, str]:
    """
    Confirmation seulement : le forecast ne promeut jamais le verdict réactif.
    """
    reactive_vn = int(reactive_vn or 0)
    forecast_vn = int(forecast_vn or 0)

    if reactive_vn == 0:
        return 0, "WAIT"

    r_sign = 1 if reactive_vn > 0 else (-1 if reactive_vn < 0 else 0)
    f_sign = 1 if forecast_vn > 0 else (-1 if forecast_vn < 0 else 0)
    if forecast_vn == 0 or f_sign == 0:
        return reactive_vn, verdict_text_from_num(reactive_vn)
    if r_sign != f_sign:
        if (
            abs(forecast_vn) == 1
            and record is not None
            and m1_scalp_structure_confirmed(record, reactive_vn)
        ):
            record["m1_scalp_simple_allowed"] = True
            simple_vn = 1 if reactive_vn > 0 else -1
            return simple_vn, verdict_text_from_num(simple_vn)
        if record is not None and _weak_opposing_forecast_has_native_spike_htf_confirmation(
            record, reactive_vn, forecast_vn
        ):
            record["spike_htf_simple_allowed"] = True
            simple_vn = 1 if reactive_vn > 0 else -1
            return simple_vn, verdict_text_from_num(simple_vn)
        return 0, "WAIT"
    return reactive_vn, verdict_text_from_num(reactive_vn)
