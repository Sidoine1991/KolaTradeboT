#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Local Verdict Calculator — Calcule score_buy, score_sell, verdict_num localement
Basé sur : RSI, Bollinger Bands, KOLA, tendances multi-TF
"""
import json
import sys
from pathlib import Path
from typing import Dict, Any, Tuple

# Fix encoding for Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

class GOMLocalCalculator:
    """Calcule les verdicts GOM sans dépendre de TradingView."""

    def __init__(self):
        self.gom_file = Path("data/gom_signal.json")

    def calculate_scores(self, record: Dict[str, Any]) -> Tuple[float, float]:
        """
        Calcule score_buy et score_sell basés sur :
        - RSI multi-TF (M1, M5, M15, H1, H4, D1)
        - Position vs Bollinger Bands
        - Direction tendance multi-TF
        - KOLA levels (buy/sell)
        """
        score_buy = 0.0
        score_sell = 0.0

        # === COMPOSANT 1: RSI multi-TF (max 30 points) ===
        rsi_components = []
        for tf in ["m1", "m5", "m15", "h1", "h4", "d1"]:
            rsi_key = f"tf_{tf}_rsi"
            rsi_val = record.get(rsi_key, 50)

            if isinstance(rsi_val, str):
                try:
                    rsi_val = int(rsi_val)
                except (ValueError, TypeError):
                    rsi_val = 50

            # RSI < 30 = oversold (BUY signal)
            if rsi_val < 30:
                score_buy += 5
            elif rsi_val < 40:
                score_buy += 3

            # RSI > 70 = overbought (SELL signal)
            if rsi_val > 70:
                score_sell += 5
            elif rsi_val > 60:
                score_sell += 3

        # === COMPOSANT 2: Position vs Bollinger Bands (max 20 points) ===
        bb_up = record.get("bb_up", 0.0)
        bb_mid = record.get("bb_mid", 0.0)
        bb_dn = record.get("bb_dn", 0.0)
        entry = record.get("entry", bb_mid or 0.0)
        current_price = entry if entry > 0 else bb_mid

        if bb_dn > 0 and bb_up > bb_dn:
            bb_range = bb_up - bb_dn
            bb_pos = (current_price - bb_dn) / bb_range if bb_range > 0 else 0.5

            # Proche de BB_DOWN (0.0-0.2) → BUY signal
            if bb_pos < 0.2:
                score_buy += 8
            elif bb_pos < 0.35:
                score_buy += 4

            # Proche de BB_UP (0.8-1.0) → SELL signal
            if bb_pos > 0.8:
                score_sell += 8
            elif bb_pos > 0.65:
                score_sell += 4

        # === COMPOSANT 3: Tendances multi-TF (max 15 points) ===
        bull_count = 0
        bear_count = 0
        for tf in ["m1", "m5", "m15", "h1", "h4", "d1"]:
            tf_dir = record.get(f"tf_{tf}_dir", "NEUT")
            if isinstance(tf_dir, str):
                tf_dir = tf_dir.upper()
                if tf_dir == "BULL":
                    bull_count += 1
                    score_buy += 2.5
                elif tf_dir == "BEAR":
                    bear_count += 1
                    score_sell += 2.5

        # Bonus pour alignement global
        global_dir = record.get("tf_global_dir", "NEUT")
        if isinstance(global_dir, str):
            global_dir = global_dir.upper()
            if global_dir == "BULL":
                score_buy += 3
            elif global_dir == "BEAR":
                score_sell += 3

        # === COMPOSANT 4: KOLA levels (max 15 points) ===
        kola_buy = record.get("kola_buy", 0.0)
        kola_sell = record.get("kola_sell", 0.0)

        if kola_buy > 0 and current_price > 0:
            # Si price est proche de KOLA_BUY → signal BUY
            distance_to_buy = abs(current_price - kola_buy) / current_price
            if distance_to_buy < 0.001:  # Très proche
                score_buy += 8
            elif distance_to_buy < 0.005:
                score_buy += 5

        if kola_sell > 0 and current_price > 0:
            # Si price est proche de KOLA_SELL → signal SELL
            distance_to_sell = abs(current_price - kola_sell) / current_price
            if distance_to_sell < 0.001:  # Très proche
                score_sell += 8
            elif distance_to_sell < 0.005:
                score_sell += 5

        # === COMPOSANT 5: Coherence (confluence multi-TF) ===
        # Si >=5 TF alignés → bonus
        if bull_count >= 5:
            score_buy += 5
        if bear_count >= 5:
            score_sell += 5

        # Normaliser les scores (0-100)
        score_buy = min(100.0, score_buy)
        score_sell = min(100.0, score_sell)

        return score_buy, score_sell

    def calculate_verdict_num(self, score_buy: float, score_sell: float) -> int:
        """
        Calcule verdict_num selon la méthode Pine Script HARMONISÉE :
        - vn = 2 si score_buy - score_sell > 5 (GOOD BUY)
        - vn = 1 si score_buy > score_sell mais gap <= 5 (BUY)
        - vn = -2 si score_sell - score_buy > 5 (GOOD SELL)
        - vn = -1 si score_sell > score_buy mais gap <= 5 (SELL)
        - vn = 0 si égal (WAIT)
        """
        gap = score_buy - score_sell

        if gap > 5:
            return 2  # GOOD BUY
        elif gap > 0:
            return 1  # BUY
        elif gap < -5:
            return -2  # GOOD SELL
        elif gap < 0:
            return -1  # SELL
        else:
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
        """Enrichit un record avec scores et verdict calculés."""
        # Calculer les scores
        score_buy, score_sell = self.calculate_scores(record)

        # Calculer verdict_num
        verdict_num = self.calculate_verdict_num(score_buy, score_sell)

        # Calculer texte verdict
        verdict_text = self.calculate_verdict_text(verdict_num)

        # Enrichir le record
        record["score_buy"] = round(score_buy, 2)
        record["score_sell"] = round(score_sell, 2)
        record["verdict_num"] = verdict_num
        record["verdict"] = verdict_text

        return record

    def process_all_symbols(self):
        """Traite tous les symboles dans gom_signal.json."""
        if not self.gom_file.exists():
            print(f"❌ Fichier non trouvé: {self.gom_file}")
            return

        # Charger
        data = json.loads(self.gom_file.read_text(encoding="utf-8"))

        # Enrichir chaque symbole
        for symbol in data:
            record = data[symbol]
            enriched = self.enrich_record(record)
            data[symbol] = enriched

        # Sauvegarder
        self.gom_file.write_text(json.dumps(data, indent=2, ensure_ascii=False))

        # Log résumé
        print("\n" + "="*70)
        print("✅ GOM Local Verdict Calculator — Résultats")
        print("="*70)
        for symbol in sorted(data.keys()):
            rec = data[symbol]
            vn = rec.get("verdict_num", 0)
            verdict = rec.get("verdict", "WAIT")
            score_buy = rec.get("score_buy", 0)
            score_sell = rec.get("score_sell", 0)
            gap = score_buy - score_sell
            print(f"  {symbol:25s} | vn={vn:2d} | {verdict:12s} | Buy:{score_buy:5.1f} Sell:{score_sell:5.1f} Gap:{gap:6.1f}")
        print("="*70)


if __name__ == "__main__":
    calc = GOMLocalCalculator()
    calc.process_all_symbols()
