"""
Agent 1 — Symbol Correlation Matrix
Tracks pairwise price correlations across Boom/Crash/Forex/Metals.
Outputs a correlation score per symbol pair and a hedge/filter signal.
"""

import time
import math
import requests
from collections import defaultdict, deque
from typing import Dict, List, Any, Optional
from .agent_base import AgentBase

AI_SERVER = "http://127.0.0.1:8000"

# Symbol groups with known structural relationships
SYMBOL_GROUPS = {
    "boom_crash": ["Boom300Index", "Boom500Index", "Boom1000Index", "Crash300Index", "Crash500Index", "Crash1000Index"],
    "forex": ["XAUUSD", "EURUSD", "GBPUSD", "USDJPY"],
    "crypto": ["BTCUSD", "ETHUSD"],
    "volatility": ["R_10", "R_25", "R_50", "R_75", "R_100"],
}

WINDOW = 60  # rolling window for correlation calc


class SymbolCorrelationAgent(AgentBase):
    agent_id = "correlation"
    agent_name = "Symbol Correlation Matrix"
    description = "Tracks pairwise correlations. Detects when a symbol's move predicts another's direction."
    version = "1.0.0"
    interval_seconds = 120

    def __init__(self):
        super().__init__()
        # price buffers: {symbol: deque of (ts, price)}
        self._price_buf: Dict[str, deque] = defaultdict(lambda: deque(maxlen=WINDOW))
        # correlation cache: {(sym1, sym2): corr}
        self._corr_cache: Dict[tuple, float] = {}
        # directional agreement scores from gom verdicts
        self._gom_directions: Dict[str, str] = {}

    def analyze(self) -> Dict[str, Any]:
        gom_data = self._fetch_gom_dashboard()
        self._update_directions(gom_data)

        correlations = self._compute_direction_correlations()
        leaders = self._identify_leaders(correlations)
        hedge_pairs = self._find_hedge_opportunities(correlations)
        group_alignment = self._compute_group_alignment()

        return {
            "correlations": correlations,
            "leaders": leaders,
            "hedge_pairs": hedge_pairs,
            "group_alignment": group_alignment,
            "symbol_directions": self._gom_directions,
            "confidence_adjustments": self._build_confidence_adjustments(leaders),
        }

    # ------------------------------------------------------------------
    # Data fetchers
    # ------------------------------------------------------------------

    def _fetch_gom_dashboard(self) -> List[Dict]:
        try:
            r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
            if r.status_code == 200:
                return r.json().get("verdicts", [])
        except Exception:
            pass
        return []

    def _update_directions(self, verdicts: List[Dict]):
        ts = time.time()
        for v in verdicts:
            sym = v.get("symbol", "")
            verdict = v.get("verdict", "WAIT")
            score_buy = float(v.get("score_buy", 0))
            score_sell = float(v.get("score_sell", 0))
            direction = "neutral"
            if "BUY" in verdict:
                direction = "bullish"
            elif "SELL" in verdict:
                direction = "bearish"

            self._gom_directions[sym] = direction
            # Use score gap as proxy for "price momentum"
            momentum = score_buy - score_sell
            self._price_buf[sym].append((ts, momentum))

    # ------------------------------------------------------------------
    # Correlation logic
    # ------------------------------------------------------------------

    def _compute_direction_correlations(self) -> Dict[str, float]:
        """Pearson correlation on momentum values between pairs."""
        result = {}
        symbols = list(self._price_buf.keys())
        for i, s1 in enumerate(symbols):
            for s2 in symbols[i + 1:]:
                corr = self._pearson(self._price_buf[s1], self._price_buf[s2])
                if corr is not None:
                    key = f"{s1}|{s2}"
                    result[key] = round(corr, 3)
        self._corr_cache = {tuple(k.split("|")): v for k, v in result.items()}
        return result

    def _pearson(self, a: deque, b: deque) -> Optional[float]:
        a_vals = [x[1] for x in a]
        b_vals = [x[1] for x in b]
        n = min(len(a_vals), len(b_vals))
        if n < 5:
            return None
        a_vals, b_vals = a_vals[-n:], b_vals[-n:]
        mean_a = sum(a_vals) / n
        mean_b = sum(b_vals) / n
        cov = sum((a_vals[i] - mean_a) * (b_vals[i] - mean_b) for i in range(n))
        std_a = math.sqrt(sum((x - mean_a) ** 2 for x in a_vals) + 1e-9)
        std_b = math.sqrt(sum((x - mean_b) ** 2 for x in b_vals) + 1e-9)
        return cov / (std_a * std_b)

    def _identify_leaders(self, correlations: Dict[str, float]) -> List[Dict]:
        """
        A leader is a symbol that has high positive correlation with MANY others.
        When the leader moves, others tend to follow.
        """
        scores: Dict[str, float] = defaultdict(float)
        counts: Dict[str, int] = defaultdict(int)
        for pair_key, corr in correlations.items():
            s1, s2 = pair_key.split("|")
            if abs(corr) > 0.6:
                scores[s1] += abs(corr)
                scores[s2] += abs(corr)
                counts[s1] += 1
                counts[s2] += 1

        leaders = []
        for sym, total_corr in sorted(scores.items(), key=lambda x: -x[1]):
            leaders.append({
                "symbol": sym,
                "leader_score": round(total_corr / max(counts[sym], 1), 3),
                "correlated_with": counts[sym],
                "current_direction": self._gom_directions.get(sym, "neutral"),
            })
        return leaders[:5]

    def _find_hedge_opportunities(self, correlations: Dict[str, float]) -> List[Dict]:
        """Pairs with strong NEGATIVE correlation are natural hedges."""
        hedges = []
        for pair_key, corr in correlations.items():
            if corr < -0.65:
                s1, s2 = pair_key.split("|")
                hedges.append({
                    "pair": pair_key,
                    "correlation": corr,
                    "direction_a": self._gom_directions.get(s1, "neutral"),
                    "direction_b": self._gom_directions.get(s2, "neutral"),
                })
        return sorted(hedges, key=lambda x: x["correlation"])[:3]

    def _compute_group_alignment(self) -> Dict[str, Dict]:
        """How aligned is each symbol group internally?"""
        alignment = {}
        for group, symbols in SYMBOL_GROUPS.items():
            directions = [self._gom_directions.get(s, "neutral") for s in symbols if s in self._gom_directions]
            if not directions:
                alignment[group] = {"score": 0, "dominant": "neutral", "count": 0}
                continue
            bullish = directions.count("bullish")
            bearish = directions.count("bearish")
            total = len(directions)
            dominant = "bullish" if bullish > bearish else ("bearish" if bearish > bullish else "neutral")
            score = max(bullish, bearish) / total * 100
            alignment[group] = {
                "score": round(score, 1),
                "dominant": dominant,
                "bullish": bullish,
                "bearish": bearish,
                "neutral": total - bullish - bearish,
                "count": total,
            }
        return alignment

    def _build_confidence_adjustments(self, leaders: List[Dict]) -> Dict[str, float]:
        """
        Boost confidence when a symbol aligns with its group leader direction.
        Reduce confidence when it diverges from a strong leader.
        """
        adjustments: Dict[str, float] = {}
        if not leaders:
            return adjustments
        top_leader = leaders[0]
        leader_dir = top_leader.get("current_direction", "neutral")
        for sym, direction in self._gom_directions.items():
            if direction == leader_dir and leader_dir != "neutral":
                adjustments[sym] = 0.05  # +5% confidence boost
            elif direction != leader_dir and direction != "neutral" and leader_dir != "neutral":
                adjustments[sym] = -0.08  # -8% confidence penalty for divergence
        return adjustments
