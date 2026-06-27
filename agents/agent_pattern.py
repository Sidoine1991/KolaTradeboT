"""
Agent 5 — Pattern Evolution Engine
Learns from trade history which patterns + conditions produce winners.
Evolves GOM thresholds, identifies regime-specific winning setups,
and detects algorithmic footprints (whale entries, sweep patterns).
"""

import json
import os
import sqlite3
import time
import requests
from collections import defaultdict
from typing import Dict, Any, List, Optional, Tuple
from .agent_base import AgentBase

AI_SERVER = "http://127.0.0.1:8000"
DB_PATHS = [
    "D:/Dev/TradBOT/python/data/trades.db",
    "D:/Dev/TradBOT/data/trades.db",
    "D:/Dev/TradBOT/trades.db",
]
PATTERN_CACHE = "D:/Dev/TradBOT/agents/pattern_cache.json"


class PatternEvolutionAgent(AgentBase):
    agent_id = "pattern"
    agent_name = "Pattern Evolution Engine"
    description = "Learns winning patterns from trade history. Evolves thresholds. Detects algo footprints."
    version = "1.0.0"
    interval_seconds = 300  # 5-minute cycle (heavy analysis)

    def __init__(self):
        super().__init__()
        self._db_path = self._find_db()
        self._evolved_thresholds: Dict[str, Dict] = {}
        self._pattern_library: Dict[str, Dict] = {}
        self._load_cache()

    def analyze(self) -> Dict[str, Any]:
        trade_stats = self._load_trade_history()
        evolved = self._evolve_thresholds(trade_stats)
        self._evolved_thresholds = evolved

        winners = self._top_winning_patterns(trade_stats)
        anomalies = self._detect_anomalies(trade_stats)
        footprints = self._detect_algo_footprints()

        result = {
            "evolved_thresholds": evolved,
            "top_patterns": winners,
            "anomalies": anomalies,
            "algo_footprints": footprints,
            "total_trades_analyzed": sum(s.get("total", 0) for s in trade_stats.values()),
            "symbols_tracked": len(trade_stats),
        }
        self._save_cache(result)
        return result

    # ------------------------------------------------------------------
    # Threshold evolution
    # ------------------------------------------------------------------

    def _evolve_thresholds(self, stats: Dict[str, Dict]) -> Dict[str, Dict]:
        """
        For each symbol, find the minimum coherence/gap that correlates
        with a win rate above 55%. Use that as the evolved threshold.
        """
        evolved: Dict[str, Dict] = {}
        for sym, data in stats.items():
            buckets = data.get("buckets", {})
            best_coh = 50.0
            best_gap = 1.2
            best_wr = 0.0

            for bucket_key, bucket in buckets.items():
                if bucket.get("total", 0) < 3:
                    continue
                wr = bucket.get("win_rate", 0)
                if wr > best_wr:
                    best_wr = wr
                    parts = bucket_key.split("|")
                    if len(parts) >= 2:
                        try:
                            best_coh = float(parts[0])
                            best_gap = float(parts[1])
                        except ValueError:
                            pass

            evolved[sym] = {
                "min_coherence": round(best_coh, 1),
                "min_gap": round(best_gap, 2),
                "expected_wr": round(best_wr * 100, 1),
                "sample_size": data.get("total", 0),
                "status": "evolved" if data.get("total", 0) >= 10 else "insufficient_data",
            }
        return evolved

    def _top_winning_patterns(self, stats: Dict[str, Dict]) -> List[Dict]:
        """Extract the top 5 symbol+condition combos with best win rates."""
        patterns = []
        for sym, data in stats.items():
            for bucket_key, bucket in data.get("buckets", {}).items():
                if bucket.get("total", 0) < 5:
                    continue
                wr = bucket.get("win_rate", 0)
                if wr >= 0.60:
                    parts = bucket_key.split("|")
                    patterns.append({
                        "symbol": sym,
                        "min_coherence": float(parts[0]) if parts else 50,
                        "min_gap": float(parts[1]) if len(parts) > 1 else 1.2,
                        "win_rate": round(wr * 100, 1),
                        "trades": bucket.get("total", 0),
                        "avg_profit": round(bucket.get("avg_profit", 0), 2),
                    })

        return sorted(patterns, key=lambda x: -x["win_rate"])[:5]

    def _detect_anomalies(self, stats: Dict[str, Dict]) -> List[Dict]:
        """
        Detect symbols where recent performance dropped significantly
        from historical baseline (possible strategy decay).
        """
        anomalies = []
        for sym, data in stats.items():
            hist_wr = data.get("historical_wr", 0)
            recent_wr = data.get("recent_wr", 0)
            total = data.get("total", 0)
            if total < 5:
                continue
            drop = hist_wr - recent_wr
            if drop > 0.15:  # 15% drop
                anomalies.append({
                    "symbol": sym,
                    "historical_wr": round(hist_wr * 100, 1),
                    "recent_wr": round(recent_wr * 100, 1),
                    "drop": round(drop * 100, 1),
                    "severity": "HIGH" if drop > 0.25 else "MEDIUM",
                })
        return sorted(anomalies, key=lambda x: -x["drop"])

    def _detect_algo_footprints(self) -> List[Dict]:
        """
        Fetches GOM verdicts and detects algorithmic footprints from
        high-score signals (score_buy > 6 or score_sell > 6 with coherence >= 80).
        """
        footprints = []
        try:
            r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
            if r.status_code == 200:
                verdicts = r.json().get("verdicts", [])
                for v in verdicts:
                    score_buy = float(v.get("score_buy", 0))
                    score_sell = float(v.get("score_sell", 0))
                    coherence_pct = float(v.get("coherence_pct", 0))
                    sym = v.get("symbol", "")
                    if not sym:
                        continue
                    if coherence_pct < 80:
                        continue
                    if score_buy > 6:
                        ml_score = round(score_buy * 10, 1)
                        footprints.append({
                            "symbol": sym,
                            "action": "buy",
                            "ml_score": ml_score,
                            "signal_type": "ALGO_DETECTED" if ml_score >= 85 else "STRONG_SIGNAL",
                        })
                    elif score_sell > 6:
                        ml_score = round(score_sell * 10, 1)
                        footprints.append({
                            "symbol": sym,
                            "action": "sell",
                            "ml_score": ml_score,
                            "signal_type": "ALGO_DETECTED" if ml_score >= 85 else "STRONG_SIGNAL",
                        })
        except Exception as e:
            self.logger.debug("Algo footprint fetch failed: %s", e)
        return footprints

    # ------------------------------------------------------------------
    # Data loading
    # ------------------------------------------------------------------

    def _load_trade_history(self) -> Dict[str, Dict]:
        stats: Dict[str, Dict] = {}
        if not self._db_path:
            return stats
        try:
            conn = sqlite3.connect(self._db_path, timeout=3)
            cur = conn.cursor()
            # Full history stats
            cur.execute("""
                SELECT symbol,
                       COUNT(*) as total,
                       AVG(CASE WHEN profit > 0 THEN 1.0 ELSE 0.0 END) as wr,
                       AVG(profit) as avg_profit
                FROM trades
                GROUP BY symbol
            """)
            for row in cur.fetchall():
                sym, total, wr, avg_profit = row
                stats[sym] = {
                    "total": total,
                    "historical_wr": float(wr or 0),
                    "avg_profit": float(avg_profit or 0),
                    "buckets": {},
                }

            # Recent (7-day) stats
            cur.execute("""
                SELECT symbol,
                       AVG(CASE WHEN profit > 0 THEN 1.0 ELSE 0.0 END) as recent_wr
                FROM trades
                WHERE date(close_time) >= date('now', '-7 days')
                GROUP BY symbol
            """)
            for row in cur.fetchall():
                sym, recent_wr = row
                if sym in stats:
                    stats[sym]["recent_wr"] = float(recent_wr or 0)

            conn.close()
        except Exception as e:
            self.logger.warning("History load error: %s", e)
        return stats

    # ------------------------------------------------------------------
    # Cache persistence
    # ------------------------------------------------------------------

    def _load_cache(self):
        try:
            if os.path.exists(PATTERN_CACHE):
                with open(PATTERN_CACHE) as f:
                    cached = json.load(f)
                    self._evolved_thresholds = cached.get("evolved_thresholds", {})
                    self._pattern_library = cached.get("top_patterns", {})
        except Exception:
            pass

    def _save_cache(self, result: Dict):
        try:
            with open(PATTERN_CACHE, "w") as f:
                json.dump(result, f, indent=2)
        except Exception as e:
            self.logger.debug("Cache save failed: %s", e)

    def _find_db(self) -> Optional[str]:
        for p in DB_PATHS:
            if os.path.exists(p):
                return p
        return None
