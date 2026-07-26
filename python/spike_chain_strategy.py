#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SpikeChainStrategy — Trading des chaînes de spikes sur Boom/Crash & Painx/Gainx

Stratégie basée sur l'observation du comportement des indices synthétiques :

1. SUPPORT / RESISTANCE 20 BARRES
   On valide un niveau S/R sur les 20 dernières barres (H1 ou H4).
   Quand ce niveau est CONFIRMÉ, on observe une série de spikes que je nomme
   "chaîne de spikes" (spike chain) dans la modélisation.

2. OPPORTUNITÉ DE TRADER LES SPIKES
   Dès que le PREMIER spike est lancé, on observe une succession d'autres
   spikes après, généralement précédés d'un retracement de 2 à 3 candles
   (en moyenne) avant le spike suivant.

3. FORCE DE L'IMPULSION (validation)
   On attribue une FORCE à l'impulsion pour la valider :
     - En H1 ou H4 : les impulsions sont FORTES.
     - En M5, si on voit un REJET de spike (spike rejection), c'est que c'est
       parti pour 3 à 4 autres spikes en moyenne dans le bref temps, sans
       grand retracement.
   La chaîne continue point de départ par point de départ, jusqu'à la
   résistance en H1.

Conventions du projet : pandas DataFrame (open/high/low/close/volume),
symboles Deriv via DERIV_SYMBOL_MAP, style identique à spike_anticipation.py.
"""

import logging
import os
import sys
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime, timezone

import numpy as np
import pandas as pd

# Assurer que les répertoires du projet sont dans sys.path.
# symbol_mapper.py vit à la racine (comme ai_server.py l'importe),
# gom_symbols.py vit dans python/.
_root_dir = str(Path(__file__).resolve().parent.parent)
_python_dir = str(Path(__file__).resolve().parent)
for _p in (_root_dir, _python_dir):
    if _p not in sys.path:
        sys.path.insert(0, _p)

logger = logging.getLogger(__name__)

# ── Résolution des symboles sur les 3 brokers ───────────────────────
# On réutilise le mapping existant du projet (symbol_mapper + gom_symbols)
# qui couvre Deriv (Boom/Crash/Volatility), Weltrade (PainX/GainX/FX Vol)
# et StarTrader/Exness (forex, métaux, crypto).
try:
    from symbol_mapper import (
        is_boom_crash, is_boom, is_crash, is_weltrade_symbol,
        get_symbol_category, normalize_for_api,
    )
    _HAVE_MAPPER = True
except Exception as _e:  # pragma: no cover — fallback hors projet
    logger.warning(f"[SPIKE] symbol_mapper indisponible: {_e}")
    _HAVE_MAPPER = False

try:
    from gom_symbols import ALL_ACTIVE_SYMBOLS as _GOM_SYMBOLS
except Exception:
    try:
        from python.gom_symbols import ALL_ACTIVE_SYMBOLS as _GOM_SYMBOLS
    except Exception:
        _GOM_SYMBOLS = ()

AI_SERVER = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")

# Valeur d'un pip par défaut sur les indices synthétiques Deriv/Weltrade.
# 1 pip = 0.01 point d'index (ex: Boom 1000 à 1013.50 → +5 pips = 1014.00).
DEFAULT_SPIKE_PIP_VALUE = 0.01

# Pip values spécifiques (points de prix par pip)
_SPIKE_PIP_VALUES = {
    # Boom / Crash Deriv
    "Boom 50 Index": 0.01, "Boom 150 Index": 0.01, "Boom 200 Index": 0.01,
    "Boom 300 Index": 0.01, "Boom 500 Index": 0.01, "Boom 600 Index": 0.01,
    "Boom 900 Index": 0.01, "Boom 1000 Index": 0.01,
    "Crash 50 Index": 0.01, "Crash 150 Index": 0.01, "Crash 200 Index": 0.01,
    "Crash 300 Index": 0.01, "Crash 500 Index": 0.01, "Crash 600 Index": 0.01,
    "Crash 900 Index": 0.01, "Crash 1000 Index": 0.01,
    # Weltrade PainX / GainX (mêmes indices synthétiques)
    "PainX 600": 0.01, "PainX 1200": 0.01,
    "GainX 400": 0.01, "GainX 600": 0.01, "GainX 800": 0.01, "GainX 1200": 0.01,
    "PainX": 0.01, "GainX": 0.01,
    # Forex / métaux / crypto (référence)
    "XAUUSD": 0.01, "XAUEUR": 0.01, "XAGUSD": 0.01,
    "EURUSD": 0.0001, "GBPUSD": 0.0001, "USDJPY": 0.01,
}

# Broker d'origine de chaque famille de symboles
def _broker_of(symbol: str) -> str:
    if _HAVE_MAPPER and is_weltrade_symbol(symbol):
        return "weltrade"
    s = symbol.upper().replace(" ", "")
    if any(k in symbol for k in ("BOOM", "CRASH", "VOLATILITY")) and "INDEX" in symbol:
        return "deriv"
    if s in ("BTCUSD", "ETHUSD"):
        return "startrader"
    return "deriv"


def get_spike_pip_value(symbol: str) -> float:
    """Retourne la valeur d'un pip pour un symbole spike."""
    return _SPIKE_PIP_VALUES.get(symbol, DEFAULT_SPIKE_PIP_VALUE)


def list_all_spike_symbols(
    source: str = "gom",
    api_url: Optional[str] = None,
) -> List[str]:
    """
    Liste TOUS les symboles spike issus des 3 brokers
    (Deriv, XM Global/StarTrader, Weltrade) via l'API du serveur IA.

    Args:
        source:  "gom"  -> utilise gom_symbols.ALL_ACTIVE_SYMBOLS (canonique)
                 "api"  -> interroge GET {AI_SERVER}/symbols (MT5 market watch +
                           catalogue Deriv) et filtre les synthétiques
        api_url: override de l'URL du serveur IA

    Returns:
        Liste dédupliquée des symboles Boom/Crash/PainX/GainX/Volatility.
    """
    symbols: List[str] = []

    if source == "api" and _HAVE_MAPPER:
        base = api_url or AI_SERVER
        try:
            import requests
            r = requests.get(f"{base}/symbols", timeout=5)
            if r.status_code == 200:
                data = r.json()
                raw = data.get("symbols", [])
                symbols = [s for s in raw if is_boom_crash(s)]
        except Exception as e:
            logger.warning(f"[SPIKE] échec GET /symbols ({base}): {e}")

    # Toujours compléter avec la liste canonique GOM (ne dépend pas du réseau)
    if not symbols and _GOM_SYMBOLS:
        candidates = list(_GOM_SYMBOLS)
    elif _GOM_SYMBOLS:
        candidates = list(set(symbols) | set(_GOM_SYMBOLS))
    else:
        candidates = symbols

    # Filtrer : ne garder que les vrais symboles spike (synthétiques)
    if _HAVE_MAPPER:
        out = [s for s in candidates if is_boom_crash(s)]
    else:
        out = [s for s in candidates
               if any(k in s for k in ("Boom", "Crash", "PainX", "GainX"))]

    # Dédupliquer en conservant l'ordre
    seen, dedup = set(), []
    for s in out:
        k = s.strip().upper()
        if k and k not in seen:
            seen.add(k)
            dedup.append(s.strip())
    return dedup

# ── Briques SMC déjà présentes dans le projet (réutilisées) ──────────
# GOMLiveCalculator fournit BOS / CHOCH / Order Blocks (compute_bos,
# compute_order_blocks) ; ai_server fournit l'analyse de bougies et la
# structure de marché. On les branche pour renforcer la décision.
try:
    from gom_live_calculator import GOMLiveCalculator  # type: ignore
    _HAVE_GOM_CALC = True
except Exception:
    # Le projet expose parfois le calculateur sous un autre nom
    try:
        from gom_live_calculator import GOMSignalsLiveCalculator as GOMLiveCalculator
        _HAVE_GOM_CALC = True
    except Exception as _e:
        logger.warning(f"[SPIKE] gom_live_calculator indisponible: {_e}")
        _HAVE_GOM_CALC = False
        GOMLiveCalculator = None

# ai_server exécute argparse.parse_args() au niveau module :
# on neutralise sys.argv pour ne pas hériter de son parser CLI.
_saved_argv = list(sys.argv)
try:
    sys.argv = [_saved_argv[0]] if _saved_argv else ["spike_chain"]
    from ai_server import (
        analyze_candlestick_patterns as _ai_analyze_candles,
        analyze_market_structure as _ai_market_structure,
    )
    _HAVE_AI_STRUCT = True
except Exception as _e:
    logger.warning(f"[SPIKE] ai_server structures indisponibles: {_e}")
    _HAVE_AI_STRUCT = False
    _ai_analyze_candles = None
    _ai_market_structure = None
finally:
    sys.argv = _saved_argv


# ── Paramètres de la stratégie ────────────────────────────────────────
SR_LOOKBACK     = 20     # barres pour valider S/R (H1/H4)
M5_SPIKE_BODY   = 3.0    # un spike M5 = corps >= 3 pips vs corps moyen
M5_RETRACE_MIN  = 2      # retracement moyen avant spike suivant (candles)
M5_RETRACE_MAX  = 3
CHAIN_MIN_SPIKES = 3      # nb de spikes attendus pour valider la chaîne (3-4)
IMPULSE_STRONG_TF = ("60", "240")  # H1 / H4 = impulsion forte
REJECTION_BODY_RATIO = 2.5  # corps du rejet >= 2.5x le corps moyen M5


class SpikeChainStrategy:
    """
    Détecte et trade les chaînes de spikes.

    Flux :
      - Valider S/R 20 barres (H1/H4)
      - Dès le 1er spike M5 confirmé + rejet => ouvrir dans le sens de la chaîne
      - Laisser courir jusqu'à la résistance H1 (trailing / partial TP)
    """

    def __init__(
        self,
        sr_lookback: int = SR_LOOKBACK,
        m5_spike_body_pips: float = M5_SPIKE_BODY,
        chain_min_spikes: int = CHAIN_MIN_SPIKES,
        symbol: Optional[str] = None,
        pip_value: Optional[float] = None,
    ):
        self.sr_lookback = sr_lookback
        self.m5_spike_body_pips = m5_spike_body_pips
        self.chain_min_spikes = chain_min_spikes
        self.symbol = symbol
        # Valeur pip déduite du symbole si fourni, sinon défaut
        self.pip_value = (
            pip_value if pip_value is not None
            else (get_spike_pip_value(symbol) if symbol else DEFAULT_SPIKE_PIP_VALUE)
        )

    # ── Utilitaires ────────────────────────────────────────────────
    @staticmethod
    def _bodies(df: pd.DataFrame) -> pd.Series:
        return (df["close"] - df["open"]).abs()

    def _avg_body_pips(self, df: pd.DataFrame) -> float:
        return float(self._bodies(df).mean() / self.pip_value)

    # ── 1. SUPPORT / RESISTANCE 20 barres ────────────────────────
    def detect_sr(
        self,
        df_htf: pd.DataFrame,
        tolerance_pips: float = 2.0,
    ) -> Dict[str, Any]:
        """
        Valide un niveau S/R sur les `sr_lookback` dernières barres.

        Renvoie le niveau (support ou résistance), son prix, le nombre de
        touches, et son sens (BUY si support / SELL si résistance).
        """
        window = df_htf.iloc[-self.sr_lookback:]
        if len(window) < self.sr_lookback:
            return {"valid": False, "reason": "pas assez de barres H1/H4"}

        # On exclut la dernière bougie (celle qui CASSE le niveau) du
        # calcul du niveau S/R : la résistance = le max des bougies
        # *avant* la cassure, pas la mèche de cassure elle-même.
        body_window = window.iloc[:-1]
        highs = body_window["high"]
        lows = body_window["low"]
        last_close = float(df_htf["close"].iloc[-1])
        tol = tolerance_pips * self.pip_value

        # Touches de résistance = highs proches du max
        res_level = float(highs.max())
        res_touches = int((highs >= res_level - tol).sum())
        # Touches de support = lows proches du min
        sup_level = float(lows.min())
        sup_touches = int((lows <= sup_level + tol).sum())

        best_level, best_touches, level_type = (
            (res_level, res_touches, "RESISTANCE")
            if res_touches >= sup_touches
            else (sup_level, sup_touches, "SUPPORT")
        )

        # Validation : >= 2 touches + prix proche du niveau
        valid = best_touches >= 2
        # Sens de la chaîne : on casse vers l'extérieur du niveau
        if level_type == "RESISTANCE":
            direction = "BUY" if last_close >= best_level - tol else "HOLD"
        else:
            direction = "SELL" if last_close <= best_level + tol else "HOLD"

        return {
            "valid": valid,
            "level_type": level_type,
            "level": round(best_level, 5),
            "touches": best_touches,
            "direction": direction,
            "last_close": round(last_close, 5),
        }

    # ── 2. Force de l'impulsion (H1/H4) ─────────────────────────
    def impulse_strength(
        self,
        df_htf: pd.DataFrame,
        timeframe: str,
    ) -> Dict[str, Any]:
        """
        Attribue une FORCE à l'impulsion pour la valider.
        H1/H4 => impulsion FORTE par construction.
        """
        if timeframe not in IMPULSE_STRONG_TF:
            return {"strong": False, "reason": f"TF {timeframe} non H1/H4"}

        window = df_htf.iloc[-self.sr_lookback:]
        body = float((window["close"].iloc[-1] - window["open"].iloc[0]) / self.pip_value)
        atr = float(
            (window["high"] - window["low"]).mean() / self.pip_value
        )

        strong = atr > 0  # sur H1/H4 l'impulsion est structurellement forte
        return {
            "strong": strong,
            "timeframe": timeframe,
            "impulse_pips": round(body, 1),
            "atr_pips": round(atr, 1),
        }

    # ── 3. Détection du spike M5 / rejet ─────────────────────────
    def detect_m5_spike(
        self,
        df_m5: pd.DataFrame,
    ) -> Dict[str, Any]:
        """
        Sur M5 : détecte un spike (corps large) et un éventuel REJET.
        Un rejet = corps >= REJECTION_BODY_RATIO x corps moyen => annonce
        3-4 spikes supplémentaires sans grand retracement.
        """
        if len(df_m5) < 5:
            return {"spike": False, "rejection": False}

        last = df_m5.iloc[-1]
        avg_body = self._avg_body_pips(df_m5)
        last_body_pips = float(abs(last["close"] - last["open"]) / self.pip_value)

        is_spike = last_body_pips >= self.m5_spike_body_pips
        is_rejection = last_body_pips >= REJECTION_BODY_RATIO * max(avg_body, 1e-9)
        direction = "BUY" if last["close"] > last["open"] else "SELL"

        return {
            "spike": is_spike,
            "rejection": is_rejection,
            "direction": direction if is_spike else None,
            "body_pips": round(last_body_pips, 1),
            "avg_body_pips": round(avg_body, 1),
        }

    def count_recent_spikes(
        self,
        df_m5: pd.DataFrame,
        lookback: int = 20,
    ) -> int:
        """Compte les spikes sur les `lookback` dernières bougies M5."""
        if len(df_m5) < 2:
            return 0
        window = df_m5.iloc[-lookback:]
        avg = self._avg_body_pips(window)
        thr = max(self.m5_spike_body_pips, avg * 1.5)
        bodies = (window["close"] - window["open"]).abs() / self.pip_value
        return int((bodies >= thr).sum())

    # ── 4. Retracement 2-3 candles avant spike suivant ──────────
    def predict_next_spike_zone(
        self,
        df_m5: pd.DataFrame,
    ) -> Dict[str, Any]:
        """
        Le spike suivant vient après un retracement moyen de 2 à 3 candles.
        Renvoie la fenêtre de bougies où on attend le prochain spike.
        """
        n = len(df_m5)
        if n == 0:
            return {"zone": None}
        start = max(0, n - M5_RETRACE_MAX)
        end = n  # jusqu'à maintenant
        return {
            "zone": (start, end),
            "retrace_min": M5_RETRACE_MIN,
            "retrace_max": M5_RETRACE_MAX,
            "candles_since_last": int(n - 1 - (n - 1 - M5_RETRACE_MIN)),
        }

    # ── 5. Orchestration : signal de chaîne de spikes ────────────
    def evaluate_chain(
        self,
        df_htf: pd.DataFrame,
        df_m5: pd.DataFrame,
        timeframe_htf: str = "60",
    ) -> Dict[str, Any]:
        """
        Évalue l'opportunité de trader une chaîne de spikes.

        Returns:
            Dict avec 'signal' (True/False), 'action', 'force', 'sr', 'm5'...
        """
        sr = self.detect_sr(df_htf)
        impulse = self.impulse_strength(df_htf, timeframe_htf)
        m5 = self.detect_m5_spike(df_m5)
        n_spikes = self.count_recent_spikes(df_m5)
        zone = self.predict_next_spike_zone(df_m5)

        # Conditions de validation de la chaîne
        sr_ok = sr.get("valid") and sr.get("direction") in ("BUY", "SELL")
        impulse_ok = impulse.get("strong", False)
        spike_triggered = m5.get("spike", False)
        rejection_ok = m5.get("rejection", False)

        # Le rejet M5 confirme 3-4 spikes sans grand retracement
        chain_expected = (CHAIN_MIN_SPIKES + (1 if rejection_ok else 0))

        signal = bool(sr_ok and impulse_ok and spike_triggered)

        # Sens de la chaîne = sens S/R confirmé (cohérent avec le spike M5)
        action = "HOLD"
        if signal:
            action = sr["direction"]
            if m5.get("direction") and m5["direction"] != action:
                # Le spike M5 va à l'encontre de la chaîne => on attend le
                # retracement 2-3 candles puis le vrai spike dans le sens S/R
                action = "PREPARE_" + action

        force = "STRONG" if (impulse_ok and rejection_ok) else (
            "MODERATE" if (impulse_ok and spike_triggered) else "WEAK"
        )

        return {
            "signal": signal,
            "action": action,
            "force": force,
            "chain_expected_spikes": chain_expected,
            "sr": sr,
            "impulse": impulse,
            "m5": m5,
            "recent_spikes": n_spikes,
            "next_zone": zone,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    # ── 5b. Renfort de décision via les briques SMC existantes ──
    def evaluate_chain_with_structure(
        self,
        df_htf: pd.DataFrame,
        df_m5: pd.DataFrame,
        timeframe_htf: str = "60",
        df_struct: Optional[pd.DataFrame] = None,
    ) -> Dict[str, Any]:
        """
        Évalue la chaîne de spikes EN PLUS de la structure SMC déjà
        calculée par le projet, pour renforcer la prise de décision :

          • BOS / CHOCH (gom_live_calculator.compute_bos)
              -> le 1er spike M5 = cassure de structure (BOS) ;
                 les spikes suivants = continuation. Un CHOCH contre-sens
                 invalide la chaîne.
          • Order Blocks (compute_order_blocks)
              -> la zone de retracement 2-3 candles après chaque spike
                 coincide avec un OB : on s'y rebranche pour le spike suivant.
          • Bougies (ai_server.analyze_candlestick_patterns)
              -> un Hammer/Shooting Star/Engulfing sur le retracement confirme
                 le rebond (le "rejet" de la chaîne).
          • Market structure (ai_server.analyze_market_structure)
              -> la tendance HH/HL (Boom) ou LH/LL (Crash) doit être
                 alignée avec le sens de la chaîne.

        Renvoie l'évaluation de base enrichie de : structure_ok, bos,
        order_block, candle, et un score de confiance `confidence`.
        """
        base = self.evaluate_chain(df_htf, df_m5, timeframe_htf=timeframe_htf)

        struct_df = df_struct if df_struct is not None else df_m5
        bos = {"bos_bull": False, "bos_bear": False,
                "choch_bull": False, "choch_bear": False}
        ob = {"ob_bull_top": 0.0, "ob_bull_bot": 0.0,
               "ob_bear_top": 0.0, "ob_bear_bot": 0.0}
        candle = {"pattern_type": "NONE", "reversal_signal": False,
                  "bullish_pattern": False, "bearish_pattern": False}
        market = {"trend": "neutral", "strength": 0.0}

        if _HAVE_GOM_CALC and struct_df is not None and len(struct_df) >= 21:
            try:
                calc = GOMLiveCalculator()
                bos = calc.compute_bos(struct_df, struct_lb=8)
                ob = calc.compute_order_blocks(struct_df, lookback=10)
            except Exception as e:
                logger.debug(f"[SPIKE] compute_bos/ob échec: {e}")

        if _HAVE_AI_STRUCT and df_m5 is not None and len(df_m5) >= 12:
            try:
                candle = _ai_analyze_candles(df_m5, lookback=10)
                market = _ai_market_structure(df_htf, lookback=self.sr_lookback)
            except Exception as e:
                logger.debug(f"[SPIKE] analyze structures échec: {e}")

        action = base.get("action", "HOLD")
        # Sens effectif de la chaîne (on strip "PREPARE_")
        eff = action.replace("PREPARE_", "")
        bull = eff == "BUY"
        bear = eff == "SELL"

        # 1) BOS/CHOCH : le 1er spike doit casser la structure dans le
        #    sens de la chaîne. Un CHOCH inverse invalide.
        bos_bull = bool(bos.get("bos_bull"))
        bos_bear = bool(bos.get("bos_bear"))
        choch_bull = bool(bos.get("choch_bull"))
        choch_bear = bool(bos.get("choch_bear"))
        bos_align = (bull and bos_bull) or (bear and bos_bear)
        choch_conflict = (bull and choch_bear) or (bear and choch_bull)

        # 2) Order Block : la zone de retracement 2-3 candles touche un OB
        last = float(df_m5["close"].iloc[-1])
        ob_zone_hit = False
        if bull and ob.get("ob_bull_bot", 0) > 0:
            ob_zone_hit = ob["ob_bull_bot"] <= last <= ob["ob_bull_top"] + 5 * self.pip_value
        elif bear and ob.get("ob_bear_top", 0) > 0:
            ob_zone_hit = ob["ob_bear_top"] - 5 * self.pip_value <= last <= ob["ob_bear_bot"]

        # 3) Bougie de rebond sur le retracement (rejet de la chaîne)
        candle_reversal = bool(candle.get("reversal_signal"))
        candle_bull = bool(candle.get("bullish_pattern"))
        candle_bear = bool(candle.get("bearish_pattern"))
        candle_align = (
            (bull and (candle_bull or candle_reversal))
            or (bear and (candle_bear or candle_reversal))
            or (not bull and not bear)  # pas de sens encore => neutre
        )

        # 4) Market structure alignée (HH/HL pour BUY, LH/LL pour SELL)
        trend = str(market.get("trend", "neutral")).lower()
        struct_align = (
            (bull and trend == "uptrend")
            or (bear and trend == "downtrend")
            or trend == "neutral"
        )

        # ── Score de confiance (0..1) ──
        score = 0.0
        if base.get("signal"):
            score += 0.35   # S/R 20 barres + impulsion H1/H4 + spike M5
        if bos_align:
            score += 0.25   # cassure de structure confirmée
        if ob_zone_hit:
            score += 0.15   # retracement sur Order Block = point de départ idéal
        if candle_align:
            score += 0.15   # bougie de rebond / rejet
        if struct_align:
            score += 0.10   # tendance HH/HL ou LH/LL alignée
        if choch_conflict:
            score -= 0.40   # CHOCH inverse => on annule la chaîne
        score = max(0.0, min(1.0, score))

        # Le renfort peut ÉLEVER un signal faible en signal tradable
        reinforced = base.get("signal") and score >= 0.60 and not choch_conflict
        if base.get("signal") and not reinforced and score >= 0.50 and not choch_conflict:
            reinforced = True  # BOS + OB suffisent même sans bougie parfaite

        return {
            **base,
            "structure_ok": bool(bos_align and struct_align),
            "confidence": round(score, 2),
            "reinforced": bool(reinforced),
            "bos": {
                "bos_bull": bos_bull, "bos_bear": bos_bear,
                "choch_bull": choch_bull, "choch_bear": choch_bear,
                "aligned": bos_align, "conflict": choch_conflict,
            },
            "order_block": {
                "bull": {"top": ob.get("ob_bull_top"), "bot": ob.get("ob_bull_bot")},
                "bear": {"top": ob.get("ob_bear_top"), "bot": ob.get("ob_bear_bot")},
                "zone_hit": ob_zone_hit,
            },
            "candle": {
                "type": candle.get("pattern_type"),
                "reversal": candle_reversal,
                "aligned": candle_align,
            },
            "market_structure": {"trend": trend, "aligned": struct_align},
        }

    # ── 6. Calcul de l'ordre (entry / sl / tp jusqu'à la résistance H1)
    def build_order(
        self,
        evaluation: Dict[str, Any],
        symbol: str,
        sl_pips: float = 8.0,
        tp_extension_pips: float = 20.0,
    ) -> Optional[Dict[str, Any]]:
        """
        Construit l'ordre. Sur un Boom, la résistance H1 est la cible de
        cassure : on achète le breakout et le TP se situe AU-DESSUS du niveau.
        Sur un Crash, le support H1 est la cible : on vend et le TP est
        AU-DESSOUS du niveau. SL serré car la chaîne doit aller vite.
        """
        if not evaluation.get("signal"):
            return None

        action = evaluation["action"]
        if action.startswith("PREPARE_"):
            action = action.replace("PREPARE_", "")
        if action not in ("BUY", "SELL"):
            return None

        sr = evaluation["sr"]
        level = sr["level"]
        last = float(sr["last_close"])
        pip = self.pip_value

        if action == "BUY":
            entry = last
            tp = level + tp_extension_pips * pip  # cassure résistance H1
            sl = last - sl_pips * pip
        else:  # SELL
            entry = last
            tp = level - tp_extension_pips * pip  # cassure support H1
            sl = last + sl_pips * pip

        reward = abs(tp - entry) / pip

        return {
            "symbol": symbol,
            "action": action,
            "entry": round(entry, 5),
            "sl": round(sl, 5),
            "tp": round(tp, 5),
            "sr_level": round(level, 5),
            "force": evaluation["force"],
            "expected_spikes": evaluation["chain_expected_spikes"],
            "reward_pips": round(reward, 1),
            "source": "spike_chain_strategy",
        }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    # ── 0) Lister tous les symboles spike (Deriv + Weltrade + StarTrader)
    syms = list_all_spike_symbols(source="gom")
    print(f"Symboles spike détectés ({len(syms)}) sur 3 brokers:")
    print("  " + ", ".join(syms[:12]) + (" ..." if len(syms) > 12 else ""))

    # ── Test synthétique ─────────────────────────────────────────
    import numpy as np

    # 1) Construire un DataFrame H1 avec une résistance touchée 3x
    # Prix d'index ~ 1013.00 ; 1 pip = 0.01 point (pip_value par défaut)
    np.random.seed(42)
    n = 25
    htf = pd.DataFrame({
        "open":  np.linspace(1010.00, 1012.00, n) + np.random.randn(n) * 0.05,
        "high":  np.linspace(1011.00, 1013.00, n) + np.random.randn(n) * 0.05,
        "low":   np.linspace(1009.50, 1011.50, n) + np.random.randn(n) * 0.05,
        "close": np.linspace(1010.50, 1012.50, n) + np.random.randn(n) * 0.05,
        "volume": np.ones(n),
    })
    # Forcer une résistance à 1013.00 touchée plusieurs fois
    for i in (18, 21, 24):
        htf.loc[i, "high"] = 1013.00
    htf.loc[n - 1, "close"] = 1013.50  # clôture au-dessus de la résistance

    # 2) Construire M5 avec un gros spike de rejet (BUY)
    # corps moyen ~1 pip (0.01) ; dernier spike = 5 pips (0.05, rejet)
    m5 = pd.DataFrame({
        "open":  np.full(10, 1010.00),
        "high":  np.full(10, 1010.50),
        "low":   np.full(10, 1009.50),
        "close": np.full(10, 1010.00),
        "volume": np.ones(10),
    })
    m5.loc[9, "close"] = 1010.05   # spike de 5 pips
    m5.loc[9, "high"] = 1010.55

    strat = SpikeChainStrategy(symbol="Boom 1000 Index")
    ev = strat.evaluate_chain(htf, m5, timeframe_htf="60")
    print("\nEvaluation chaîne de spikes (Boom 1000 Index):")
    print(f"  signal        : {ev['signal']}")
    print(f"  action        : {ev['action']}")
    print(f"  force         : {ev['force']}")
    print(f"  sr            : {ev['sr']}")
    print(f"  m5            : {ev['m5']}")
    print(f"  expected spikes: {ev['chain_expected_spikes']}")

    order = strat.build_order(ev, "Boom 1000 Index")
    print("\nOrdre généré:")
    print(order if order else "  Aucun (signal non validé)")

    # ── Test renfort structurel (BOS/CHOCH + OB + bougies) ──
    print("\n[Renfort SMC] évaluation avec BOS/CHOCH + Order Blocks:")
    ev2 = strat.evaluate_chain_with_structure(htf, m5, timeframe_htf="60", df_struct=m5)
    print(f"  reinforced    : {ev2['reinforced']}")
    print(f"  confidence    : {ev2['confidence']}")
    print(f"  structure_ok : {ev2['structure_ok']}")
    print(f"  bos           : {ev2['bos']}")
    print(f"  order_block   : {ev2['order_block']['zone_hit']}")
    print(f"  candle        : {ev2['candle']}")
    print(f"  market_struct : {ev2['market_structure']}")
