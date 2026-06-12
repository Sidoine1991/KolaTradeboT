# -*- coding: utf-8 -*-
"""
signal_refiner.py — Boucle de rétroaction TV → Signal de qualité

Flux :
  TradingAgents (TA) + TradingView MCP (TV indicators) + Scorecard interne
      ↓
  refine_signal()
      ↓
  Signal enrichi : entry/SL/TP ajustés, lot modulé, qualité scorée,
                   REJECT si confluence insuffisante

Données TV exploitées :
  - RSI (zone, divergence)
  - EMA stack (alignement multi-TF)
  - Structure H1 / M15 (trend, BOS)
  - Order Blocks (support/résistance dynamique)
  - FVG (Fair Value Gaps)
  - Candle patterns (engulfing, hammer, doji)
  - Spike Z-score (Boom/Crash)
  - Bias score + raisons
  - Pine levels (niveaux custom SMC_Universal)
"""
from __future__ import annotations

import logging
import math
from typing import Any, Dict, List, Optional, Tuple

log = logging.getLogger("signal_refiner")

# ---------------------------------------------------------------------------
# Seuils de qualité — MODE HAUTE PRECISION (qualité > quantité)
# ---------------------------------------------------------------------------
MIN_QUALITY_SCORE  = 75   # Seuil MINIMUM = 75% confiance avant trade
MIN_QUALITY_AUTO   = 80   # Sous ce score en mode AUTO → lot réduit de 50%
HIGH_QUALITY_SCORE = 90   # Au-dessus → lot au risque 2% au lieu de 1%

# Compte cible pour recommended_lot (petit compte)
ACCOUNT_TARGET_USD = 50.0

# SL/TP par catégorie de symbole — stratégie GoldSMC (OB+CHOCH + EMA multi-TF)
# Or/Forex/Crypto : SL=2.0×ATR, RR=1.5 (paramètres optimisés GoldSMC v2)
# Boom/Crash      : SL=2.0×ATR, RR=2.0 (indices synthétiques — SL élargi pour éviter fermetures prématurées)
SL_ATR_MULT_GOLD   = 2.0   # XAUUSD H1 strategy GoldSMC : SL=2.0×ATR
TP_RR_GOLD         = 1.5   # XAUUSD H1 strategy GoldSMC : TP=SL×1.5
SL_MAX_ATR_MULT    = 2.0   # Boom/Crash synthétiques : 2×ATR

# Stop minimum absolu pour indices synthétiques Boom/Crash (en points de prix)
SYNTH_MIN_STOP_PTS = 20    # empêche SL à 2-3 pts qui se font toucher immédiatement

# Symboles Or/Forex/Crypto — stratégie GoldSMC
_GOLD_FOREX_PREFIXES = ("XAU", "EUR", "GBP", "USD", "JPY", "AUD", "NZD", "CAD", "CHF",
                         "BTC", "ETH", "NAS", "US30", "US500", "DAX")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _pip_value(price: float) -> float:
    if price > 1000:   return 1.0
    if price > 10:     return 0.0001
    return 0.01


def _safe_float(v, default: float = 0.0) -> float:
    try:
        return float(v) if v is not None else default
    except (TypeError, ValueError):
        return default


def _lot_for_risk(entry: float, sl: float, account_usd: float, risk_pct: float) -> float:
    """Calcule le lot optimal pour ne pas dépasser risk_pct% du compte."""
    sl_dist = abs(entry - sl)
    if sl_dist <= 0:
        return 0.01
    pip   = _pip_value(entry)
    pips  = sl_dist / pip
    pplt  = 1.0 if entry > 1000 else (0.1 if entry > 10 else 1.0)
    risk_usd = account_usd * risk_pct
    lot = risk_usd / (pips * pplt)
    return max(0.01, round(lot, 2))


# ---------------------------------------------------------------------------
# Analyse de la donnée TV
# ---------------------------------------------------------------------------

def _score_tv_data(tv_raw: Dict, direction: str) -> Tuple[int, List[str], List[str]]:
    """
    Retourne (score 0-100, raisons_positives, raisons_négatives)
    à partir des données brutes TV MCP.
    """
    score = 0
    pos: List[str] = []
    neg: List[str] = []
    is_buy = direction.upper() == "BUY"

    smc    = tv_raw.get("smc") or {}
    bias   = smc.get("bias") or {}
    struct_m15 = smc.get("structure_m15") or {}
    struct_h1  = smc.get("structure_h1")  or {}
    obs    = smc.get("order_blocks") or []
    fvgs   = smc.get("fvg") or []
    candle = smc.get("candle_pattern") or ""
    ema    = smc.get("ema_stack") or {}
    rsi_d  = smc.get("rsi") or {}
    pine   = smc.get("pine_levels") or []
    spike  = tv_raw.get("spike") or {}

    # ── 1. Biais directionnel (20 pts) ───────────────────────────────────────
    bias_dir = (bias.get("direction") or "NEUTRAL").upper()
    bias_sc  = _safe_float(bias.get("score"))
    if (is_buy and bias_dir == "BUY") or (not is_buy and bias_dir == "SELL"):
        pts = min(20, int(bias_sc / 10 * 20))
        score += pts
        pos.append(f"Biais TV aligné {bias_dir} (score {bias_sc:.1f}/10 → +{pts}pts)")
    elif bias_dir == "NEUTRAL":
        score += 5
        pos.append("Biais TV neutre (+5pts prudence)")
    else:
        score -= 10
        neg.append(f"Biais TV OPPOSÉ {bias_dir} vs signal {direction} (-10pts)")

    # ── 2. Structure M15 (15 pts) ─────────────────────────────────────────────
    trend_m15 = (struct_m15.get("trend") or "unknown").lower()
    if (is_buy and "bullish" in trend_m15) or (not is_buy and "bearish" in trend_m15):
        score += 15
        pos.append(f"Structure M15 alignée ({trend_m15} +15pts)")
    elif "unknown" in trend_m15 or not trend_m15:
        pass  # neutre
    else:
        score -= 8
        neg.append(f"Structure M15 contre-tendance ({trend_m15} -8pts)")

    # ── 3. Structure H1 (10 pts) ──────────────────────────────────────────────
    trend_h1 = (struct_h1.get("trend") or "unknown").lower()
    if (is_buy and "bullish" in trend_h1) or (not is_buy and "bearish" in trend_h1):
        score += 10
        pos.append(f"Structure H1 alignée ({trend_h1} +10pts)")
    elif "bullish" in trend_h1 or "bearish" in trend_h1:
        score -= 5
        neg.append(f"Structure H1 contre-tendance ({trend_h1} -5pts)")

    # ── 4. RSI (15 pts) ───────────────────────────────────────────────────────
    rsi_val  = _safe_float(rsi_d.get("value"), 50)
    rsi_zone = (rsi_d.get("zone") or "neutral").lower()
    if is_buy:
        if rsi_val < 30:
            score += 15; pos.append(f"RSI oversold {rsi_val:.1f} → entrée BUY privilégiée (+15pts)")
        elif rsi_val < 45:
            score += 10; pos.append(f"RSI zone baissière {rsi_val:.1f} → pullback favorable BUY (+10pts)")
        elif rsi_val > 70:
            score -= 12; neg.append(f"RSI overbought {rsi_val:.1f} → BUY risqué (-12pts)")
        elif rsi_val > 60:
            score += 3;  pos.append(f"RSI momentum haussier {rsi_val:.1f} (+3pts)")
    else:
        if rsi_val > 70:
            score += 15; pos.append(f"RSI overbought {rsi_val:.1f} → entrée SELL privilégiée (+15pts)")
        elif rsi_val > 55:
            score += 10; pos.append(f"RSI zone haussière {rsi_val:.1f} → rebond favorable SELL (+10pts)")
        elif rsi_val < 30:
            score -= 12; neg.append(f"RSI oversold {rsi_val:.1f} → SELL risqué (-12pts)")
        elif rsi_val < 40:
            score += 3;  pos.append(f"RSI momentum baissier {rsi_val:.1f} (+3pts)")

    # ── 5. EMA Stack (10 pts) ─────────────────────────────────────────────────
    ema8  = _safe_float(ema.get("ema8"))
    ema21 = _safe_float(ema.get("ema21"))
    ema50 = _safe_float(ema.get("ema50"))
    if ema8 > 0 and ema21 > 0 and ema50 > 0:
        bullish_stack = ema8 > ema21 > ema50
        bearish_stack = ema8 < ema21 < ema50
        if (is_buy and bullish_stack) or (not is_buy and bearish_stack):
            score += 10; pos.append(f"EMA stack aligné (8>{21}>{50} {'haussier' if is_buy else 'baissier'} +10pts)")
        elif (is_buy and bearish_stack) or (not is_buy and bullish_stack):
            score -= 7;  neg.append(f"EMA stack inversé (-7pts)")

    # ── 6. Order Blocks (10 pts) ──────────────────────────────────────────────
    ob_types = [o.get("type", "") for o in obs]
    if is_buy and any("bullish_ob" in t for t in ob_types):
        score += 10; pos.append(f"Order Block haussier actif (+10pts)")
    elif not is_buy and any("bearish_ob" in t for t in ob_types):
        score += 10; pos.append(f"Order Block baissier actif (+10pts)")

    # ── 7. FVG (5 pts) ────────────────────────────────────────────────────────
    fvg_types = [f.get("type", "") for f in fvgs]
    if is_buy and any("bullish_fvg" in t for t in fvg_types):
        score += 5; pos.append(f"FVG haussier non comblé (+5pts)")
    elif not is_buy and any("bearish_fvg" in t for t in fvg_types):
        score += 5; pos.append(f"FVG baissier non comblé (+5pts)")

    # ── 8. Candle pattern (8 pts) ─────────────────────────────────────────────
    bullish_patterns = ("hammer_bullish", "bullish_engulfing", "strong_bullish")
    bearish_patterns = ("shooting_star_bearish", "bearish_engulfing", "strong_bearish")
    if is_buy and any(p in candle for p in bullish_patterns):
        score += 8; pos.append(f"Pattern bougie haussier ({candle} +8pts)")
    elif not is_buy and any(p in candle for p in bearish_patterns):
        score += 8; pos.append(f"Pattern bougie baissier ({candle} +8pts)")
    elif "doji" in candle:
        score -= 3; neg.append(f"Doji → indécision (-3pts)")

    # ── 9. Spike Boom/Crash (bonus 5 pts) ────────────────────────────────────
    if spike.get("spike_detected"):
        z = _safe_float(spike.get("z_score"))
        if z >= 2.0:
            score += 5; pos.append(f"Spike fort Z={z:.1f} (+5pts — timing précis)")

    # ── 10. GOM KOLA SIDO — score_buy/sell (12 pts) ───────────────────────────
    gom_buy  = _safe_float(smc.get("gom_score_buy"))
    gom_sell = _safe_float(smc.get("gom_score_sell"))
    gom_num  = int(smc.get("gom_verdict_num") or 0)
    if gom_buy > 0 or gom_sell > 0:
        if is_buy and gom_num > 0 and gom_buy > gom_sell:
            gap = gom_buy - gom_sell
            pts = min(12, int(gap * 1.5))
            score += pts; pos.append(f"GOM BUY ({gom_buy:.1f} vs {gom_sell:.1f}, gap={gap:.1f} +{pts}pts)")
        elif not is_buy and gom_num < 0 and gom_sell > gom_buy:
            gap = gom_sell - gom_buy
            pts = min(12, int(gap * 1.5))
            score += pts; pos.append(f"GOM SELL ({gom_sell:.1f} vs {gom_buy:.1f}, gap={gap:.1f} +{pts}pts)")
        elif (is_buy and gom_sell > gom_buy) or (not is_buy and gom_buy > gom_sell):
            score -= 8; neg.append(f"GOM contre-signal: buy={gom_buy:.1f} sell={gom_sell:.1f} (-8pts)")

    # ── 11. Entry quality GOM (8 pts) ─────────────────────────────────────────
    eq = _safe_float(smc.get("entry_quality"))
    if eq >= 60:
        pts = min(8, int((eq - 60) / 5))
        score += pts; pos.append(f"Qualité entrée GOM={eq:.0f}% (+{pts}pts)")
    elif eq > 0 and eq < 30:
        score -= 5; neg.append(f"Qualité entrée GOM faible={eq:.0f}% (-5pts)")

    # ── 12. Cohérence multi-TF GOM (5 pts) ────────────────────────────────────
    coh = _safe_float(smc.get("coherence_pct"))
    if coh >= 70:
        score += 5; pos.append(f"Cohérence multi-TF={coh:.0f}% (+5pts)")
    elif coh > 0 and coh < 40:
        score -= 3; neg.append(f"Cohérence multi-TF faible={coh:.0f}% (-3pts)")

    # ── 13. Supertrend direction (5 pts) ──────────────────────────────────────
    st_dir = smc.get("st_dir")
    if st_dir is not None:
        if (is_buy and int(st_dir) > 0) or (not is_buy and int(st_dir) < 0):
            score += 5; pos.append(f"Supertrend aligné {'+1' if is_buy else '-1'} (+5pts)")
        elif int(st_dir) != 0:
            score -= 3; neg.append(f"Supertrend contre-tendance (-3pts)")

    # ── 14. BB / VWAP position (5 pts) ────────────────────────────────────────
    cp_est = _safe_float(smc.get("current_price"))
    bb_up  = _safe_float(smc.get("bb_upper"))
    bb_dn  = _safe_float(smc.get("bb_lower"))
    vwap_v = _safe_float(smc.get("vwap"))
    if cp_est > 0 and bb_up > 0 and bb_dn > 0:
        bb_range = bb_up - bb_dn
        if bb_range > 0:
            pos_in_bb = (cp_est - bb_dn) / bb_range  # 0=bas, 1=haut
            if is_buy and pos_in_bb < 0.35:
                score += 5; pos.append(f"Prix bas de BB ({pos_in_bb:.0%}) → BUY opportun (+5pts)")
            elif not is_buy and pos_in_bb > 0.65:
                score += 5; pos.append(f"Prix haut de BB ({pos_in_bb:.0%}) → SELL opportun (+5pts)")
    if cp_est > 0 and vwap_v > 0:
        if (is_buy and cp_est > vwap_v) or (not is_buy and cp_est < vwap_v):
            score += 2; pos.append(f"Prix {'au-dessus' if is_buy else 'en-dessous'} du VWAP (+2pts)")

    # Borner entre 0 et 100
    score = max(0, min(100, score))
    return score, pos, neg


def _adjust_levels_from_tv(
    entry: float, sl: float, tp: float,
    tv_raw: Dict, direction: str,
    atr: float,
) -> Tuple[float, float, float, List[str]]:
    """
    Ajuste entry/SL/TP en exploitant :
    - Order Blocks comme niveaux SL/TP
    - Pine levels (niveaux custom TradingView)
    - FVG comme cible TP
    - RSI pour décaler l'entry (éviter les entrées overbought/oversold)
    """
    adjustments: List[str] = []
    is_buy = direction.upper() == "BUY"
    smc = tv_raw.get("smc") or {}

    # ── Entry : si RSI overbought sur BUY → reculer de 0.3×ATR ──────────────
    rsi_d = smc.get("rsi") or {}
    rsi_v = _safe_float(rsi_d.get("value"), 50)
    if is_buy and rsi_v > 65 and atr > 0:
        new_entry = round(entry - atr * 0.3, 5)
        adjustments.append(f"Entry BUY reculé {entry:.5f}→{new_entry:.5f} (RSI={rsi_v:.1f}>65, attente pullback 0.3×ATR)")
        entry = new_entry
    elif not is_buy and rsi_v < 35 and atr > 0:
        new_entry = round(entry + atr * 0.3, 5)
        adjustments.append(f"Entry SELL reculé {entry:.5f}→{new_entry:.5f} (RSI={rsi_v:.1f}<35, attente rebond 0.3×ATR)")
        entry = new_entry

    # ── SL : utiliser le bas/haut du meilleur Order Block ────────────────────
    obs = smc.get("order_blocks") or []
    if obs and entry > 0:
        if is_buy:
            # SL sous le bullish OB le plus proche en-dessous de l'entry
            bullish_obs = [o for o in obs if "bullish" in o.get("type","") and o.get("low",0) < entry]
            if bullish_obs:
                best_ob = max(bullish_obs, key=lambda o: o.get("low", 0))
                ob_sl = round(best_ob["low"] - atr * 0.2, 5)
                if ob_sl < entry:
                    adjustments.append(f"SL ancré sous OB haussier {ob_sl:.5f} (était {sl:.5f})")
                    sl = ob_sl
        else:
            # SL au-dessus du bearish OB le plus proche au-dessus de l'entry
            bearish_obs = [o for o in obs if "bearish" in o.get("type","") and o.get("high",0) > entry]
            if bearish_obs:
                best_ob = min(bearish_obs, key=lambda o: o.get("high", 0))
                ob_sl = round(best_ob["high"] + atr * 0.2, 5)
                if ob_sl > entry:
                    adjustments.append(f"SL ancré sur OB baissier {ob_sl:.5f} (était {sl:.5f})")
                    sl = ob_sl

    # ── TP : utiliser le FVG le plus proche comme cible ──────────────────────
    fvgs = smc.get("fvg") or []
    if fvgs and entry > 0:
        if is_buy:
            # TP au bas du premier FVG baissier au-dessus de l'entry
            above_fvgs = [f for f in fvgs if "bearish" in f.get("type","") and f.get("bottom",0) > entry]
            if above_fvgs:
                best_fvg = min(above_fvgs, key=lambda f: f.get("bottom", 9e9))
                fvg_tp = round(best_fvg["bottom"], 5)
                if fvg_tp > entry and fvg_tp > tp:
                    adjustments.append(f"TP étendu jusqu'au FVG baissier {fvg_tp:.5f} (était {tp:.5f})")
                    tp = fvg_tp
        else:
            # TP au haut du premier FVG haussier en-dessous de l'entry
            below_fvgs = [f for f in fvgs if "bullish" in f.get("type","") and f.get("top",0) < entry]
            if below_fvgs:
                best_fvg = max(below_fvgs, key=lambda f: f.get("top", 0))
                fvg_tp = round(best_fvg["top"], 5)
                if fvg_tp < entry and fvg_tp < tp:
                    adjustments.append(f"TP étendu jusqu'au FVG haussier {fvg_tp:.5f} (était {tp:.5f})")
                    tp = fvg_tp

    # ── Pine levels : niveaux clés custom (SL/TP fins) ───────────────────────
    pine = smc.get("pine_levels") or []
    if pine and entry > 0 and atr > 0:
        if is_buy:
            # Support le plus proche en-dessous → SL potentiel
            supports = [p["price"] for p in pine if p.get("price", 0) < entry - atr * 0.1]
            if supports:
                best_sup = max(supports)
                pine_sl  = round(best_sup - atr * 0.1, 5)
                if pine_sl < entry and abs(pine_sl - sl) / entry < 0.02:
                    adjustments.append(f"SL affiné sur niveau Pine {pine_sl:.5f}")
                    sl = pine_sl
        else:
            # Résistance la plus proche au-dessus → SL potentiel
            resistances = [p["price"] for p in pine if p.get("price", 0) > entry + atr * 0.1]
            if resistances:
                best_res = min(resistances)
                pine_sl  = round(best_res + atr * 0.1, 5)
                if pine_sl > entry and abs(pine_sl - sl) / entry < 0.02:
                    adjustments.append(f"SL affiné sur niveau Pine {pine_sl:.5f}")
                    sl = pine_sl

    # Vérifier cohérence finale
    if is_buy:
        if sl >= entry:
            sl = round(entry - atr * SL_MAX_ATR_MULT, 5)
            adjustments.append(f"SL corrigé (était ≥ entry) → {sl:.5f}")
        if tp <= entry:
            tp = round(entry + atr * 2.0, 5)
            adjustments.append(f"TP corrigé (était ≤ entry) → {tp:.5f}")
    else:
        if sl <= entry:
            sl = round(entry + atr * SL_MAX_ATR_MULT, 5)
            adjustments.append(f"SL corrigé (était ≤ entry) → {sl:.5f}")
        if tp >= entry:
            tp = round(entry - atr * 2.0, 5)
            adjustments.append(f"TP corrigé (était ≥ entry) → {tp:.5f}")

    # Cap le SL à SL_MAX_ATR_MULT × ATR
    if atr > 0:
        sl_dist = abs(entry - sl)
        max_sl_dist = atr * SL_MAX_ATR_MULT
        if sl_dist > max_sl_dist:
            sl = round(entry - max_sl_dist if is_buy else entry + max_sl_dist, 5)
            adjustments.append(f"SL cappé à {SL_MAX_ATR_MULT}×ATR → {sl:.5f} ({max_sl_dist:.2f} pts max)")
            # Recaler TP pour garder RR ≥ 1.5
            sl_new_dist = abs(entry - sl)
            tp_min = round(entry + sl_new_dist * 1.5 if is_buy else entry - sl_new_dist * 1.5, 5)
            if (is_buy and tp < tp_min) or (not is_buy and tp > tp_min):
                tp = tp_min
                adjustments.append(f"TP ajusté RR 1.5 → {tp:.5f}")

    # Floor minimum absolu pour indices synthétiques Boom/Crash
    symbol_upper = tv_raw.get("symbol", "").upper()
    if any(p in symbol_upper for p in ("BOOM", "CRASH")):
        sl_dist = abs(entry - sl)
        if sl_dist < SYNTH_MIN_STOP_PTS:
            sl = round(entry - SYNTH_MIN_STOP_PTS if is_buy else entry + SYNTH_MIN_STOP_PTS, 5)
            adjustments.append(f"SL floor Boom/Crash {SYNTH_MIN_STOP_PTS}pts → {sl:.5f}")

    return entry, sl, tp, adjustments


def _compute_lot_from_quality(
    quality_score: int,
    entry: float,
    sl: float,
    account_sizes: List[float] = None,
) -> Dict[str, Dict]:
    """
    Module le lot selon la qualité du signal :
    - Score >= HIGH_QUALITY_SCORE  → risque 2%
    - Score >= MIN_QUALITY_AUTO    → risque 1%
    - Score < MIN_QUALITY_AUTO     → risque 0.5% (prudence)
    """
    if account_sizes is None:
        account_sizes = [10.0, 20.0, 50.0]

    if quality_score >= HIGH_QUALITY_SCORE:
        risk_pct = 0.02
        risk_label = "2% (signal fort)"
    elif quality_score >= MIN_QUALITY_AUTO:
        risk_pct = 0.01
        risk_label = "1% (signal standard)"
    else:
        risk_pct = 0.005
        risk_label = "0.5% (signal faible — lot réduit)"

    result = {"_risk_pct": risk_pct, "_risk_label": risk_label}
    for acc in account_sizes:
        lot = _lot_for_risk(entry, sl, acc, risk_pct)
        risk_usd_calc = round(abs(entry - sl) / _pip_value(entry) * lot *
                              (1.0 if entry > 1000 else (0.1 if entry > 10 else 1.0)), 3)
        result[f"${acc:.0f}"] = {"lot": lot, "risk_usd": risk_usd_calc, "risk_pct": risk_pct * 100}
    return result


# ---------------------------------------------------------------------------
# Point d'entrée principal
# ---------------------------------------------------------------------------

def refine_signal(
    ta_result: Dict[str, Any],
    tv_raw:    Dict[str, Any],
    direction: str,
    symbol:    str,
    accounts:  List[float] = None,
) -> Dict[str, Any]:
    """
    Fusionne TradingAgents + TradingView pour produire un signal de qualité.

    Paramètres :
      ta_result  : dict retourné par run_trading_agents() du pipeline
      tv_raw     : dict brut retourné par fetch_tradingview_analysis()
                   (contient smc, spike, etc.)
      direction  : "BUY" ou "SELL"
      symbol     : symbole MT5 propre (ex: "XAUUSD")
      accounts   : tailles de compte cibles (défaut [10, 20, 50])

    Retourne :
      {
        "quality_score"  : int 0-100,
        "quality_label"  : str,
        "accept"         : bool,
        "reject_reason"  : str|None,
        "direction"      : str,
        "entry"          : float,
        "sl"             : float,
        "tp"             : float,
        "rr"             : float,
        "lots"           : dict,
        "recommended_lot": float,   # lot pour $20 avec risque adapté
        "execution_type" : str,
        "tv_score"       : int,
        "tv_reasons_pos" : list,
        "tv_reasons_neg" : list,
        "adjustments"    : list,
        "summary"        : str,     # résumé 3 lignes pour WhatsApp/rapport
      }
    """
    if accounts is None:
        accounts = [10.0, 20.0, 50.0, 100.0]

    entry = _safe_float(ta_result.get("entry"))
    sl    = _safe_float(ta_result.get("sl"))
    tp    = _safe_float(ta_result.get("tp"))
    atr   = _safe_float(ta_result.get("atr"))
    price = _safe_float(ta_result.get("current")) or entry

    # Déterminer la stratégie SL/TP selon le type de symbole
    # GoldSMC v2 : XAUUSD + Forex + Crypto → SL=2.0×ATR, RR=1.5
    # Synthétiques Boom/Crash → SL=1.5×ATR, RR=2.0
    _sym_up = symbol.upper()
    _is_gold_forex = any(_sym_up.startswith(p) or p in _sym_up for p in _GOLD_FOREX_PREFIXES)
    _sl_atr_mult = SL_ATR_MULT_GOLD if _is_gold_forex else SL_MAX_ATR_MULT
    _tp_rr       = TP_RR_GOLD if _is_gold_forex else 2.0

    # ── 1. Score TV ───────────────────────────────────────────────────────────
    tv_score, tv_pos, tv_neg = _score_tv_data(tv_raw, direction)

    # ── 2. Score TA (confiance TradingAgents) ────────────────────────────────
    ta_conf = _safe_float(ta_result.get("confidence", 0.70))
    ta_score = int(ta_conf * 100)

    # ── 3. Score combiné (60% TV, 40% TA) ────────────────────────────────────
    quality_score = int(tv_score * 0.60 + ta_score * 0.40)
    quality_score = max(0, min(100, quality_score))

    # Label
    if quality_score >= HIGH_QUALITY_SCORE:
        quality_label = "FORT"
    elif quality_score >= MIN_QUALITY_AUTO:
        quality_label = "STANDARD"
    elif quality_score >= MIN_QUALITY_SCORE:
        quality_label = "FAIBLE"
    else:
        quality_label = "INSUFFISANT"

    # ── 4. Filtre qualité + validation Entry ──────────────────────────────────
    reject_reason = None

    # Reject si entry manquante
    if entry <= 0:
        reject_reason = f"Entry manquante ou zéro (entry={entry}). Sources: TV={tv_raw.get('entry', 'N/A')}, TA={ta_result.get('entry', 'N/A')}"

    # GATE IA STATUS : cohérence multi-TF (GOM statut IA) doit être >= 70%
    # Condition ABSOLUE — même si toutes les autres conditions sont réunies
    # smc non encore défini ici — on lit depuis ta_result / tv_raw directement
    _smc_early = tv_raw.get("smc") or {}
    _ia_status = _safe_float(
        _smc_early.get("coherence_pct") or
        ta_result.get("coherence_pct") or
        tv_raw.get("coherence_pct")
    )
    if not reject_reason and _ia_status > 0 and _ia_status < 70.0:
        reject_reason = (
            f"IA status trop bas ({_ia_status:.0f}% < 70% requis) — "
            f"cohérence multi-TF insuffisante pour valider le signal"
        )

    # Reject si qualité insuffisante
    if not reject_reason and quality_score < MIN_QUALITY_SCORE:
        reject_reason = (
            f"Qualité insuffisante ({quality_score}/100 < seuil {MIN_QUALITY_SCORE}). "
            f"Raisons: {'; '.join(tv_neg[:3]) or 'confluence TV/TA faible'}"
        )

    # Même si rejeté, on produit les niveaux pour le rapport
    # ── 5. Ajustement entry/SL/TP depuis TV ───────────────────────────────────
    adjustments: List[str] = []
    if entry > 0 and sl > 0 and atr > 0:
        entry, sl, tp, adjustments = _adjust_levels_from_tv(
            entry, sl, tp, tv_raw, direction, atr
        )
    elif entry > 0 and atr > 0:
        # Recalculer SL/TP avec la stratégie du symbole
        # GoldSMC v2 : SL=2.0×ATR, RR=1.5 | Boom/Crash : SL=1.5×ATR, RR=2.0
        is_buy = direction.upper() == "BUY"
        if sl <= 0:
            sl = round(entry - atr * _sl_atr_mult, 5) if is_buy else round(entry + atr * _sl_atr_mult, 5)
        if tp <= 0:
            sl_dist = abs(entry - sl)
            tp = round(entry + sl_dist * _tp_rr, 5) if is_buy else round(entry - sl_dist * _tp_rr, 5)
        strat_name = "GoldSMC (SL=2×ATR RR=1.5)" if _is_gold_forex else "Synthétique (SL=2×ATR RR=2.0)"
        adjustments.append(f"SL/TP {strat_name}")

    # ── 6. Ratio R:R ──────────────────────────────────────────────────────────
    rr = 0.0
    if entry > 0 and sl > 0 and tp > 0:
        risk   = abs(entry - sl)
        reward = abs(tp - entry)
        rr = round(reward / risk, 2) if risk > 0 else 0.0

    # ── 7. Lot sizing modulé par qualité ─────────────────────────────────────
    lots = {}
    recommended_lot = 0.01
    if entry > 0 and sl > 0:
        lots = _compute_lot_from_quality(quality_score, entry, sl, accounts)
        acc_key = f"${ACCOUNT_TARGET_USD:.0f}"
        recommended_lot = lots.get(acc_key, {}).get("lot") or lots.get("$20", {}).get("lot", 0.01)

    # ── 8. execution_type : ajuster selon écart prix/entry ───────────────────
    exec_type = ta_result.get("execution_type", "market")
    if price > 0 and entry > 0:
        is_buy = direction.upper() == "BUY"
        ecart  = (entry - price) / price
        if is_buy and ecart > 0.002:
            exec_type = "stop"   # entry au-dessus du marché → BUY STOP
        elif is_buy and ecart < -0.002:
            exec_type = "limit"  # entry en-dessous du marché → BUY LIMIT
        elif not is_buy and ecart < -0.002:
            exec_type = "stop"   # entry en-dessous du marché → SELL STOP
        elif not is_buy and ecart > 0.002:
            exec_type = "limit"  # entry au-dessus du marché → SELL LIMIT
        else:
            exec_type = "market"

    # ── 9. Résumé WhatsApp/rapport ────────────────────────────────────────────
    risk_label = lots.get("_risk_label", "")
    summary_lines = [
        f"Score qualité : {quality_score}/100 ({quality_label})",
        f"TV: {tv_score}pts | TA: {ta_score}pts | RR 1:{rr}",
        f"Entry {entry:.4f} → SL {sl:.4f} → TP {tp:.4f}",
        f"Lot ${ACCOUNT_TARGET_USD:.0f}: {recommended_lot} ({risk_label})",
    ]
    if tv_pos:
        summary_lines.append("✅ " + " | ".join(tv_pos[:3]))
    if tv_neg:
        summary_lines.append("⚠️ " + " | ".join(tv_neg[:2]))
    if adjustments:
        summary_lines.append("📐 " + " | ".join(adjustments[:2]))
    if reject_reason:
        summary_lines.append(f"🚫 REJETÉ: {reject_reason[:120]}")

    return {
        "quality_score":   quality_score,
        "quality_label":   quality_label,
        "accept":          reject_reason is None,
        "reject_reason":   reject_reason,
        "direction":       direction.upper(),
        "entry":           entry,
        "sl":              sl,
        "tp":              tp,
        "rr":              rr,
        "lots":            lots,
        "recommended_lot": recommended_lot,
        "execution_type":  exec_type,
        "tv_score":        tv_score,
        "ta_score":        ta_score,
        "tv_reasons_pos":  tv_pos,
        "tv_reasons_neg":  tv_neg,
        "adjustments":     adjustments,
        "summary":         "\n".join(summary_lines),
        # Données brutes pour le rapport Word
        "rsi_value":       _safe_float((tv_raw.get("smc") or {}).get("rsi", {}).get("value")),
        "ema_stack":       (tv_raw.get("smc") or {}).get("ema_stack") or {},
        "candle_pattern":  (tv_raw.get("smc") or {}).get("candle_pattern") or "",
        "obs_count":       len((tv_raw.get("smc") or {}).get("order_blocks") or []),
        "fvg_count":       len((tv_raw.get("smc") or {}).get("fvg") or []),
        "spike_z":         _safe_float((tv_raw.get("spike") or {}).get("z_score")),
        "spike_detected":  bool((tv_raw.get("spike") or {}).get("spike_detected")),
    }
