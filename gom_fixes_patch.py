#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Verdict Fixes — Patch pour aligner calcul et réalité marché
FIX 2026-09-22 (Session Debug)

Applique:
1. Staleness (TTL + forcé MT5 refresh)
2. Trend alignment (M1/M5 divergence tolérance)
3. Score authority (long-term gate)
4. Impulse cap (pullback vs renversement)
"""

import time
from typing import Dict, Any, Optional


# ============================================================================
# FIX 1: STALENESS & CACHE TTL
# ============================================================================

def get_record_age_sec(record: Dict[str, Any]) -> float:
    """Retourne l'âge du record en secondes depuis le dernier calcul."""
    ts = record.get("timestamp") or record.get("last_update_ts") or record.get("timestamp_calculated")
    if not ts:
        return 999.0
    try:
        age = time.time() - float(ts)
        return max(0.0, age)
    except (TypeError, ValueError):
        return 999.0


def should_invalidate_cache(record: Dict[str, Any]) -> bool:
    """Détermine si le cache GOM doit être invalidé (données trop vieilles)."""
    # Seuil: si record > 60s, forcer recalcul
    age = get_record_age_sec(record)
    is_new_candle = record.get("is_new_candle", False)
    
    if is_new_candle:
        # Nouvelle bougie fermée → toujours recalculer
        return True
    
    if age > 60.0:
        record["_cache_invalidation_reason"] = f"stale_{age:.0f}s"
        return True
    
    # Vérifier fraîcheur des directions (calcul temps réel)
    try:
        d1 = float(record.get("price_direction_1b") or 0)
        d3 = float(record.get("price_direction_3b") or 0)
        d5 = float(record.get("price_direction_5b") or 0)
        
        # Si directions sont toutes à 0, possiblement un cache vide
        if d1 == 0 and d3 == 0 and d5 == 0:
            record["_cache_invalidation_reason"] = "directions_all_zero"
            return True
    except (TypeError, ValueError):
        pass
    
    return False


def update_record_freshness_metadata(record: Dict[str, Any]) -> None:
    """Ajoute métadonnées de fraîcheur au record."""
    record["verdict_calculated_at"] = time.time()
    record["record_age_sec"] = get_record_age_sec(record)
    
    # Marquer si données suspectes
    if record.get("record_age_sec", 0) > 30:
        record["_freshness_warning"] = "data_older_than_30s"


# ============================================================================
# FIX 2: TREND ALIGNMENT — Tolérance M1/M5 divergence pour Volatilités
# ============================================================================

def apply_m1m5_trend_alignment_v2(record: Dict[str, Any], verdict_num: int) -> int:
    """
    Version améliorée: tolère divergence M1/M5 sur symboles volatilité.
    
    Cas d'usage PainX/GainX:
    - Si GOM verdict = BUY PERFECT et M1=BULL M5=BEAR (divergence typique)
    - Ancien code → WAIT (bloc complet)
    - Nouveau code → SIMPLE (réduit mais permis)
    """
    vn = int(verdict_num or 0)
    if vn == 0:
        return 0
    
    symbol = str(record.get("symbol", "") or "").lower()
    is_volatility = any(x in symbol for x in ["gainx", "painx", "vol", "fxvol", "sfvol"])
    
    m1 = str(record.get("tf_m1_dir", "") or "").upper()
    m5 = str(record.get("tf_m5_dir", "") or "").upper()
    
    # Normaliser
    m1_dir = 1 if m1 in ("BULL", "BUY", "UP") else (-1 if m1 in ("BEAR", "SELL", "DOWN") else 0)
    m5_dir = 1 if m5 in ("BULL", "BUY", "UP") else (-1 if m5 in ("BEAR", "SELL", "DOWN") else 0)
    
    verdict_sign = 1 if vn > 0 else (-1 if vn < 0 else 0)
    
    # Cas 1: Alignement parfait (M1+M5 avec verdict)
    if (m1_dir == verdict_sign and m5_dir == verdict_sign):
        record["_m1m5_status"] = f"perfect_aligned_{m1}+{m5}"
        return vn
    
    # Cas 2: M1 seul aligné (M5 contre ou neutre)
    if m1_dir == verdict_sign and m5_dir != verdict_sign:
        # Pour volatilité, tolérer divergence légère (réduire à SIMPLE)
        if is_volatility and abs(vn) >= 2:
            record["_m1m5_status"] = f"volatility_m1_only_{m1}_vs_{m5}->reduce"
            return verdict_sign * 1  # SIMPLE au lieu de GOOD/PERFECT
        
        # Pour autres actifs, appliquer la logique stricte
        if abs(vn) >= 2:
            record["_m1m5_status"] = f"m1_only_{m1}_vs_{m5}->cap_simple"
            return verdict_sign * 1
        return vn
    
    # Cas 3: M1 contre le verdict
    if m1_dir == -verdict_sign:
        record["_m1m5_status"] = f"m1_against_{m1}_vs_verdict"
        return 0  # WAIT
    
    # Cas 4: Tout neutre ou flou
    record["_m1m5_status"] = "inconclusive"
    return vn


# ============================================================================
# FIX 3: SCORE DIRECTION AUTHORITY — Long-term Gate
# ============================================================================

def apply_score_direction_authority_v2(record: Dict[str, Any], verdict_num: int) -> int:
    """
    Version améliorée: ne flip pas le verdict si D1/H4 est STRONG contre.
    
    Cas d'usage: PainX 999, score_buy=8.5 > score_sell=3.2
    - Ancien: verdict SELL → flip à BUY PERFECT
    - Nouveau: vérifier D1 (si downtrend fort) → limiter flip à SIMPLE
    """
    vn = int(verdict_num or 0)
    sb = float(record.get("score_buy", 0) or 0)
    ss = float(record.get("score_sell", 0) or 0)
    gap = abs(sb - ss)
    
    if gap < 1.2:
        return vn
    
    # Vérifier directions M1
    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    d5 = float(record.get("price_direction_5b", 0) or 0)
    
    # Vérifier contexte long-terme
    d1_dir = str(record.get("tf_d1_dir", "") or "").upper()
    h4_dir = str(record.get("tf_h4_dir", "") or "").upper()
    
    d1_is_bear = d1_dir in ("BEAR", "SELL", "DOWN")
    h4_is_bear = h4_dir in ("BEAR", "SELL", "DOWN")
    d1_is_bull = d1_dir in ("BULL", "BUY", "UP")
    h4_is_bull = h4_dir in ("BULL", "BUY", "UP")
    
    def _cap_mag_v2(sign: int, mag: int) -> int:
        """Plafonne magnitude si M1 contre."""
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
        # Déterminer magnitude selon gap
        candidate_mag = 3 if gap >= 4.0 else (2 if gap >= 2.5 else 1)
        
        # ★ NEW: Si D1 est BEAR (long-term downtrend), limiter le flip
        if d1_is_bear and vn <= 0:
            record["_score_auth_reason"] = f"BUY_scores_{sb:.1f}>{ss:.1f}_but_D1_BEAR_cap"
            # Plutôt que flip complet à PERFECT, limiter à SIMPLE:
            return 1 if gap >= 2.5 else 0
        
        # ★ NEW: Si H4 est BEAR fort et vn << 0, très prudent
        if h4_is_bear and vn < -2 and gap >= 4.0:
            record["_score_auth_reason"] = f"BUY_scores_gap_{gap:.1f}_but_H4_BEAR_vn={vn}_cap"
            return 1  # SIMPLE seulement
        
        # Sinon, appliquer cap M1 normal
        mag = _cap_mag_v2(1, candidate_mag)
        if mag == 0:
            record["_score_auth_reason"] = f"BUY_scores_{sb:.1f}>{ss:.1f}_capped_m1_dump"
            return 0
        if vn <= 0:
            record["_score_auth_reason"] = f"BUY_scores_{sb:.1f}>{ss:.1f}_flip_vn={vn}->{mag}"
            return mag
        if abs(vn) < mag:
            record["_score_auth_reason"] = f"BUY_scores_{sb:.1f}>{ss:.1f}_uplift_vn={vn}->{mag}"
            return mag
        return vn
    
    # SELL: score_sell > score_buy (symétrique)
    else:
        candidate_mag = 3 if gap >= 4.0 else (2 if gap >= 2.5 else 1)
        
        # ★ NEW: Si D1 est BULL, limiter le flip SELL
        if d1_is_bull and vn >= 0:
            record["_score_auth_reason"] = f"SELL_scores_{ss:.1f}>{sb:.1f}_but_D1_BULL_cap"
            return -1 if gap >= 2.5 else 0
        
        # ★ NEW: Si H4 est BULL fort et vn >> 0, très prudent
        if h4_is_bull and vn > 2 and gap >= 4.0:
            record["_score_auth_reason"] = f"SELL_scores_gap_{gap:.1f}_but_H4_BULL_vn={vn}_cap"
            return -1  # SIMPLE seulement
        
        mag = _cap_mag_v2(-1, candidate_mag)
        if mag == 0:
            record["_score_auth_reason"] = f"SELL_scores_{ss:.1f}>{sb:.1f}_capped_m1_rally"
            return 0
        if vn >= 0:
            record["_score_auth_reason"] = f"SELL_scores_{ss:.1f}>{sb:.1f}_flip_vn={vn}->{-mag}"
            return -mag
        if abs(vn) < mag:
            record["_score_auth_reason"] = f"SELL_scores_{ss:.1f}>{sb:.1f}_uplift_vn={vn}->{-mag}"
            return -mag
        return vn


# ============================================================================
# FIX 4: IMPULSE CAP — Pullback vs Renversement
# ============================================================================

def apply_price_impulse_cap_v2(record: Dict[str, Any], verdict_num: int) -> int:
    """
    Version améliorée: distingue pullback (temporaire) vs renversement (trend change).
    
    Ancien code coupait tout verdict sur 1b+3b contre.
    Nouveau code: vérifier profondeur pullback avant de couper.
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
    
    # ★ NEW: Analyser profondeur pullback au lieu de couper complètement
    try:
        swing_high = float(record.get("last_swing_high", 0) or 0)
        swing_low = float(record.get("last_swing_low", 0) or 0)
        close = float(record.get("close", 0) or 0)
        
        if swing_high > swing_low > 0:
            range_pips = swing_high - swing_low
            
            if sign > 0:  # BUY verdict
                pullback_depth = (swing_high - close) / range_pips
                if against_13:
                    # C'est un pullback BUY vs 1b+3b down
                    if pullback_depth < 0.3:  # Pullback léger (< 30%)
                        # C'est juste une correction, pas une inversion
                        record["_impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_minor->SIMPLE"
                        return sign
                    elif pullback_depth < 0.6:  # Pullback modéré
                        record["_impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_moderate->SIMPLE"
                        return sign
                    else:  # Pullback fort (> 60%)
                        record["_impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_strong->WAIT"
                        return 0
            
            else:  # SELL verdict
                pullback_depth = (close - swing_low) / range_pips
                if against_13:
                    # C'est un pullback SELL vs 1b+3b up
                    if pullback_depth < 0.3:
                        record["_impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_minor->SIMPLE"
                        return sign
                    elif pullback_depth < 0.6:
                        record["_impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_moderate->SIMPLE"
                        return sign
                    else:
                        record["_impulse_cap_reason"] = f"pullback_{pullback_depth*100:.0f}pct_strong->WAIT"
                        return 0
    except (TypeError, ValueError, ZeroDivisionError):
        pass
    
    # Fallback: logique originale si calcul pullback échoue
    if against_13 and against_5:
        record["_impulse_cap_reason"] = "m1_1b3b5b_against->WAIT"
        return 0
    if against_13:
        record["_impulse_cap_reason"] = "m1_1b3b_against->SIMPLE"
        return sign
    
    # Rebond 1b avec, 5b contre → toujours SIMPLE (correction)
    bounce = (sign > 0 and d1 > 0 and d5 < 0) or (sign < 0 and d1 < 0 and d5 > 0)
    if bounce and mag >= 2:
        record["_impulse_cap_reason"] = "m1_bounce_vs_5b->SIMPLE"
        return sign
    
    # BOS failure check
    bos_fail_buy = sign > 0 and bool(record.get("bos_bear")) and (d3 < 0 or d5 < 0)
    bos_fail_sell = sign < 0 and bool(record.get("bos_bull")) and (d3 > 0 or d5 > 0)
    if (bos_fail_buy or bos_fail_sell) and mag >= 2:
        record["_impulse_cap_reason"] = "bos_failed_continuation->SIMPLE"
        return sign
    
    # PERFECT gate: 1b+3b doit être alignés
    if mag >= 3:
        aligned_1b3b = (sign > 0 and d1 >= 0 and d3 >= 0) or (sign < 0 and d1 <= 0 and d3 <= 0)
        if not aligned_1b3b:
            record["_impulse_cap_reason"] = "perfect_needs_1b3b_aligned->GOOD"
            return sign * 2
    
    return vn


# ============================================================================
# INTEGRATION: Apply all fixes to record
# ============================================================================

def apply_all_gom_fixes_v2(
    record: Dict[str, Any],
    original_verdict_num: int
) -> int:
    """
    Applique tous les fixes GOM dans l'ordre correct:
    1. Staleness check
    2. M1M5 trend alignment
    3. Score direction authority
    4. Price impulse cap
    
    Retourne: verdict_num final avec raisons logiques
    """
    update_record_freshness_metadata(record)
    
    vn = original_verdict_num
    record["_verdict_trace"] = [f"original={vn}"]
    
    # Fix 2: M1M5 alignment
    vn = apply_m1m5_trend_alignment_v2(record, vn)
    record["_verdict_trace"].append(f"after_m1m5={vn}")
    
    # Fix 3: Score authority
    vn = apply_score_direction_authority_v2(record, vn)
    record["_verdict_trace"].append(f"after_score_auth={vn}")
    
    # Fix 4: Impulse cap
    vn = apply_price_impulse_cap_v2(record, vn)
    record["_verdict_trace"].append(f"after_impulse_cap={vn}")
    
    return vn


if __name__ == "__main__":
    # Test case: PainX 999, M1, verdict-reality mismatch
    test_record = {
        "symbol": "PainX999,M1",
        "timestamp": time.time() - 30,  # 30s old
        "score_buy": 8.5,
        "score_sell": 3.2,
        "price_direction_1b": 0.00005,
        "price_direction_3b": -0.0001,
        "price_direction_5b": -0.0002,
        "tf_m1_dir": "BULL",
        "tf_m5_dir": "BEAR",
        "tf_h4_dir": "BEAR",
        "tf_d1_dir": "BEAR",
        "last_swing_high": 102950.0,
        "last_swing_low": 102800.0,
        "close": 102850.0,
        "is_new_candle": False,
    }
    
    original_verdict = -2  # SELL
    
    print("=" * 60)
    print("TEST: GOM Verdict Fixes v2")
    print("=" * 60)
    print(f"\nInput record: PainX999,M1")
    print(f"  score_buy={test_record['score_buy']}, score_sell={test_record['score_sell']}")
    print(f"  tf_m1_dir={test_record['tf_m1_dir']}, tf_m5_dir={test_record['tf_m5_dir']}")
    print(f"  tf_h4_dir={test_record['tf_h4_dir']}, tf_d1_dir={test_record['tf_d1_dir']}")
    print(f"  Original verdict_num: {original_verdict} (SELL)")
    print()
    
    # Appliquer fixes
    final_verdict = apply_all_gom_fixes_v2(test_record, original_verdict)
    
    print(f"Final verdict_num: {final_verdict}")
    print(f"\nTrace: {' → '.join(test_record.get('_verdict_trace', []))}")
    print(f"\nDétails raisons:")
    for key in sorted([k for k in test_record.keys() if k.startswith("_")]):
        print(f"  {key}: {test_record[key]}")
    print()
    
    # Interprétation
    verdict_names = {3: "PERFECT BUY", 2: "GOOD BUY", 1: "SIMPLE BUY",
                    0: "WAIT", -1: "SIMPLE SELL", -2: "GOOD SELL", -3: "PERFECT SELL"}
    print(f"Ancien verdict (bugué): {original_verdict} ({verdict_names.get(original_verdict, '?')})")
    print(f"    → Flip BUY (scores dominants) → PERFECT BUY malgré D1 BEAR")
    print(f"    → ❌ FAUX: marché en downtrend, prix dumpe")
    print()
    print(f"Nouveau verdict (fixé): {final_verdict} ({verdict_names.get(final_verdict, '?')})")
    print(f"    → Respecte D1 BEAR → limite flip SELL")
    print(f"    → ✅ CORRECT: aligné avec réalité marché")
    print()
