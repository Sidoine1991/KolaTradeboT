#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Scoring Engine - COMPLET ET FIDÈLE
Calcule score_buy et score_sell selon la spec complète
"""

import pandas as pd
import numpy as np
from typing import Tuple, Dict, Any

class GOMScoringEngine:
    """Moteur de scoring GOM complet"""

    def score_indicators(self, df: pd.DataFrame, rsi: float, bb_up: float, bb_mid: float, bb_dn: float,
                        vwap: float, macd: float, macd_sig: float, st_dir: int, st_level: float) -> Tuple[float, float]:
        """
        Calcule score_buy et score_sell basés sur les indicateurs

        Chaque indicateur ajoute des points:
        - RSI > 60 → BUY +1.0, RSI < 40 → SELL +1.0
        - SuperTrend UP → BUY +1.0, DOWN → SELL +1.0
        - VWAP: prix vs VWAP → BUY +0.8 ou SELL +0.8
        - MACD: positif vs signal → BUY +0.8 ou SELL +0.8
        - Bollinger Bands: prix proche edges → BUY/SELL +0.6
        """
        score_buy = 0.0
        score_sell = 0.0

        close = df['close'].iloc[-1]

        # 1. RSI (0-100)
        if rsi > 60:
            score_buy += 1.0
        elif rsi < 40:
            score_sell += 1.0
        elif rsi > 55:
            score_buy += 0.5
        elif rsi < 45:
            score_sell += 0.5

        # 2. SuperTrend
        if st_dir > 0:  # Uptrend
            score_buy += 1.0
        else:  # Downtrend
            score_sell += 1.0

        # 3. VWAP (prix vs VWAP)
        vwap_diff = close - vwap
        if vwap_diff > 0:  # Prix > VWAP
            score_buy += 0.8
        else:  # Prix < VWAP
            score_sell += 0.8

        # 4. MACD
        macd_diff = macd - macd_sig
        if macd_diff > 0:  # MACD > Signal
            score_buy += 0.8
        else:  # MACD < Signal
            score_sell += 0.8

        # 5. Bollinger Bands
        bb_width = bb_up - bb_dn
        if bb_width > 0:
            position = (close - bb_dn) / bb_width
            if position < 0.3:  # Proche du bas
                score_buy += 0.6
            elif position > 0.7:  # Proche du haut
                score_sell += 0.6

        # 6. Volatilité (width of bands)
        if bb_width > 0:
            vol_score = min(bb_width / 10.0, 1.0)  # Normalisé
            if close > bb_mid:
                score_buy += vol_score * 0.4
            else:
                score_sell += vol_score * 0.4

        return round(score_buy, 2), round(score_sell, 2)

    def calculate_gap(self, score_buy: float, score_sell: float) -> float:
        """Calcule l'écart entre buy et sell"""
        return round(abs(score_buy - score_sell), 2)

    def calculate_coherence(self, tf_directions: Dict[str, str]) -> Tuple[bool, float]:
        """
        Vérifie la cohérence sur les timeframes

        Compte combien de TF vont dans la même direction
        coherence_ok si ratio >= 40%
        """
        if not tf_directions:
            return False, 0.0

        # Compte BULL vs BEAR
        bull_count = sum(1 for d in tf_directions.values() if d == "BULL")
        bear_count = sum(1 for d in tf_directions.values() if d == "BEAR")

        total = bull_count + bear_count
        if total == 0:
            return False, 0.0

        # Ratio du côté dominant — 57% = 4/7 TF minimum (professionnel M1)
        ratio = max(bull_count, bear_count) / total
        coherence_ok = ratio >= 0.57

        return coherence_ok, round(ratio * 100, 1)

    def calculate_verdict(self, score_buy: float, score_sell: float, gap: float,
                         coherence_ok: bool, entry_quality: float = 0.0) -> Tuple[str, int]:
        """
        Calcule le verdict final selon la hiérarchie complète

        Returns: (verdict_string, verdict_num)
        """

        # Si pas de cohérence ET gap faible → WAIT
        if not coherence_ok and gap < 3.0:
            return "WAIT", 0

        if score_buy > score_sell:
            # Direction BUY — PERFECT exige gap >= 5.0 (aligné gom_pine_calculator)
            if gap >= 5.0 and coherence_ok:
                return "PERFECT BUY", 3
            elif gap >= 2.5 and coherence_ok:
                return "GOOD BUY", 2
            elif gap >= 1.2 and coherence_ok:
                return "BUY", 1
            else:
                return "WAIT", 0
        elif score_sell > score_buy:
            # Direction SELL
            if gap >= 5.0 and coherence_ok:
                return "PERFECT SELL", -3
            elif gap >= 2.5 and coherence_ok:
                return "GOOD SELL", -2
            elif gap >= 1.2 and coherence_ok:
                return "SELL", -1
            else:
                return "WAIT", 0
        else:
            # Scores égaux
            return "WAIT", 0

    def score_record(self, record: Dict[str, Any]) -> Dict[str, Any]:
        """Enrichit un record avec les scores et verdict complets"""

        # Extraire les indicateurs
        rsi = record.get("rsi14", 50)
        bb_up = record.get("bb_up", 0)
        bb_mid = record.get("bb_mid", 0)
        bb_dn = record.get("bb_dn", 0)
        vwap = record.get("vwap", 0)
        macd = record.get("macd_line", 0)
        macd_sig = record.get("macd_sig", 0)
        st_dir = record.get("st_dir", 0)
        st_level = record.get("st_level", 0)

        # Créer un dataframe simple pour les calculs
        close = record.get("close", 0)
        df = pd.DataFrame({
            'close': [close],
            'high': [record.get("high", close)],
            'low': [record.get("low", close)],
            'open': [record.get("open", close)],
            'volume': [record.get("volume", 0)]
        })

        # Calculer les scores
        score_buy, score_sell = self.score_indicators(df, rsi, bb_up, bb_mid, bb_dn, vwap, macd, macd_sig, st_dir, st_level)

        # Calculer le gap
        gap = self.calculate_gap(score_buy, score_sell)

        # Vérifier cohérence
        tf_dirs = {
            "m1": record.get("tf_m1_dir", "NEUT"),
            "m5": record.get("tf_m5_dir", "NEUT"),
            "m15": record.get("tf_m15_dir", "NEUT"),
            "h1": record.get("tf_h1_dir", "NEUT"),
            "h4": record.get("tf_h4_dir", "NEUT"),
            "d1": record.get("tf_d1_dir", "NEUT"),
            "global": record.get("tf_global_dir", "NEUT"),
        }
        coherence_ok, coherence_pct = self.calculate_coherence(tf_dirs)

        # Calculer verdict
        verdict, verdict_num = self.calculate_verdict(score_buy, score_sell, gap, coherence_ok)

        # Enrichir le record
        record.update({
            "score_buy": score_buy,
            "score_sell": score_sell,
            "verdict_gap": gap,
            "coherence_ok": coherence_ok,
            "coherence_pct": coherence_pct,
            "verdict": verdict,
            "verdict_num": verdict_num,
            "entry_quality": round(gap / 7.0, 2),  # Normalized quality
        })

        return record
