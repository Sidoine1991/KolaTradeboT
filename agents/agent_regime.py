"""
Agent 2 — Market Regime Classifier
Detects the current market regime per symbol: TRENDING_UP, TRENDING_DOWN,
RANGING, VOLATILE, or BREAKOUT.

Data sources:
  - /gom-verdicts         → all symbols with per-TF data (fast, bulk)
  - /cognition/forecast-200 → cog_direction, cog_regime, cog_confidence per symbol

Boom/Crash law: Boom = TRENDING_UP only, Crash = TRENDING_DOWN only.
Correction detection: short-TF against long-TF ≠ reversal.
Coherence gate: <40% → RANGING; <60% → confidence halved.
"""

import requests
from collections import Counter
from typing import Any, Dict, List, Tuple

from .agent_base import AgentBase

AI_SERVER = "http://127.0.0.1:8000"

REGIMES: Dict[str, Dict] = {
    "TRENDING_UP": {
        "description": "Strong bullish directional bias across TFs",
        "color": "#22c55e",
        "strategy": "Trend Following — BUY setups only, wider TP",
        "gate_modifier": +0.05,
    },
    "TRENDING_DOWN": {
        "description": "Strong bearish directional bias across TFs",
        "color": "#ef4444",
        "strategy": "Trend Following — SELL setups only, wider TP",
        "gate_modifier": +0.05,
    },
    "RANGING": {
        "description": "No clear trend — price oscillating between support/resistance",
        "color": "#f59e0b",
        "strategy": "Range Trading — fade extremes, tight TP",
        "gate_modifier": -0.10,
    },
    "VOLATILE": {
        "description": "High volatility — erratic price action, spike risk",
        "color": "#8b5cf6",
        "strategy": "Spike Riding — use SpikeAnticipator, small lots",
        "gate_modifier": -0.05,
    },
    "BREAKOUT": {
        "description": "Price breaking key structure — momentum acceleration",
        "color": "#06b6d4",
        "strategy": "Breakout — enter after retest, momentum trailing SL",
        "gate_modifier": +0.08,
    },
}


class MarketRegimeAgent(AgentBase):
    agent_id = "regime"
    agent_name = "Market Regime Classifier"
    description = (
        "Classifies current market regime per symbol using GOM verdicts + "
        "cognition forecast. Enforces Boom/Crash law and detects corrections."
    )
    version = "2.0.0"
    interval_seconds = 90

    def __init__(self) -> None:
        super().__init__()
        self._regime_history: Dict[str, List[str]] = {}

    # ------------------------------------------------------------------
    # Main entry point
    # ------------------------------------------------------------------

    def analyze(self) -> Dict[str, Any]:
        verdicts = self._fetch_verdicts()

        symbol_regimes: Dict[str, Dict] = {}
        correction_warnings: List[str] = []

        for v in verdicts:
            sym = v.get("symbol", "")
            if not sym:
                continue

            cog = self._fetch_cognition(sym)
            regime, confidence = self._classify_regime(v, cog)

            # Track correction warnings for caller awareness
            correction_detected = self._is_correcting(v)
            if correction_detected:
                correction_warnings.append(sym)

            # Maintain rolling regime history (last 20 ticks)
            history = self._regime_history.setdefault(sym, [])
            history.append(regime)
            if len(history) > 20:
                history.pop(0)

            cog_dir = cog.get("cog_direction", "HOLD")
            cog_regime = cog.get("cog_regime", "")
            tf_global = v.get("tf_global_dir", "NEUTRAL")

            symbol_regimes[sym] = {
                "regime": regime,
                "confidence": confidence,
                "info": REGIMES.get(regime, {}),
                "history": history[-5:],
                "gate_modifier": REGIMES.get(regime, {}).get("gate_modifier", 0.0),
                "strategy_hint": REGIMES.get(regime, {}).get("strategy", ""),
                "correction_detected": correction_detected,
                "tf_global_dir": tf_global,
                "cog_regime": cog_regime,
                "cog_direction": cog_dir,
            }

        global_regime = self._global_regime(symbol_regimes)

        return {
            "global_regime": global_regime,
            "symbol_regimes": symbol_regimes,
            "regime_distribution": self._distribution(symbol_regimes),
            "correction_warnings": correction_warnings,
        }

    # ------------------------------------------------------------------
    # Classification logic
    # ------------------------------------------------------------------

    def _classify_regime(self, v: Dict, cog: Dict) -> Tuple[str, float]:
        score_buy = float(v.get("score_buy", 0))
        score_sell = float(v.get("score_sell", 0))
        coherence = float(v.get("coherence_pct", 0))
        gap = abs(score_buy - score_sell)
        tf_global = v.get("tf_global_dir", "NEUTRAL")
        tf_strength = int(v.get("tf_global_strength", 0))
        m1_dir = v.get("tf_m1_dir", "NEUTRAL")
        m5_dir = v.get("tf_m5_dir", "NEUTRAL")
        symbol = v.get("symbol", "")

        cog_dir = cog.get("cog_direction", "HOLD")
        cog_regime = cog.get("cog_regime", "")
        cog_conf = float(cog.get("cog_confidence", 0.5))

        # 1. Boom/Crash law: force regime direction
        is_boom = "BOOM" in symbol.upper() or "PAINX" in symbol.upper()
        is_crash = "CRASH" in symbol.upper() or "GAINX" in symbol.upper()

        # 2. Coherence gate: weak signal → RANGING
        if coherence < 40:
            return "RANGING", 0.40

        # 3. Detect short-TF correction against global direction
        is_correcting = self._is_correcting(v)

        # 4. VOLATILE: cognition reports spike/volatile regime
        if cog_regime in ("VOLATILE", "SPIKE_FORMING"):
            # Boom/Crash can still be volatile but retain directional bias
            if is_boom:
                return "TRENDING_UP", round(min(0.75, cog_conf), 2)
            if is_crash:
                return "TRENDING_DOWN", round(min(0.75, cog_conf), 2)
            return "VOLATILE", round(min(0.85, cog_conf), 2)

        # 5. Strong trend: large gap or strong TF alignment
        if gap >= 3.5 or (tf_strength >= 5 and coherence >= 60):
            # Determine direction
            if is_boom:
                regime = "TRENDING_UP"
            elif is_crash:
                regime = "TRENDING_DOWN"
            elif tf_global == "BULL" or score_buy > score_sell:
                regime = "TRENDING_UP"
            else:
                regime = "TRENDING_DOWN"

            conf = min(0.92, 0.65 + gap * 0.04 + coherence * 0.002)

            # Correction slightly reduces conviction, trend is still dominant
            if is_correcting:
                conf = round(conf * 0.85, 2)

            # Coherence below 60 halves the bonus above base
            if coherence < 60:
                conf = round(max(0.40, conf * 0.80), 2)

            # Cognition alignment adjustment
            expected_cog = "BUY" if regime == "TRENDING_UP" else "SELL"
            if cog_dir == expected_cog:
                conf = min(0.95, conf + 0.10)
            elif cog_dir not in ("HOLD", ""):
                conf = max(0.40, conf - 0.15)

            return regime, round(conf, 2)

        # 6. BREAKOUT: kola state CONFIRMED/ENTRY with decent gap
        kola = v.get("kola_state", "")
        if kola in ("ENTRY", "CONFIRMED") and gap >= 2.5:
            # Boom/Crash breakouts still respect directional law
            if is_boom:
                return "TRENDING_UP", 0.72
            if is_crash:
                return "TRENDING_DOWN", 0.72
            return "BREAKOUT", 0.72

        # 7. Moderate trend (gap 2.5–3.5) without strong TF strength
        if gap >= 2.5 and coherence >= 55:
            if is_boom:
                regime = "TRENDING_UP"
            elif is_crash:
                regime = "TRENDING_DOWN"
            elif tf_global == "BULL" or score_buy > score_sell:
                regime = "TRENDING_UP"
            else:
                regime = "TRENDING_DOWN"

            conf = min(0.75, 0.55 + gap * 0.04)
            if coherence < 60:
                conf = round(conf * 0.80, 2)
            if is_correcting:
                conf = round(conf * 0.85, 2)

            expected_cog = "BUY" if regime == "TRENDING_UP" else "SELL"
            if cog_dir == expected_cog:
                conf = min(0.85, conf + 0.10)
            elif cog_dir not in ("HOLD", ""):
                conf = max(0.40, conf - 0.15)

            return regime, round(conf, 2)

        # 8. Default: RANGING
        conf = max(0.40, 0.60 - gap * 0.06 - (coherence - 50) * 0.002)
        return "RANGING", round(conf, 2)

    def _is_correcting(self, v: Dict) -> bool:
        """Return True when short TFs contradict the global direction."""
        tf_global = v.get("tf_global_dir", "NEUTRAL")
        m1_dir = v.get("tf_m1_dir", "NEUTRAL")
        m5_dir = v.get("tf_m5_dir", "NEUTRAL")
        if tf_global == "BEAR" and m1_dir == "BULL" and m5_dir == "BULL":
            return True
        if tf_global == "BULL" and m1_dir == "BEAR" and m5_dir == "BEAR":
            return True
        return False

    # ------------------------------------------------------------------
    # Aggregation helpers
    # ------------------------------------------------------------------

    def _global_regime(self, symbol_regimes: Dict[str, Dict]) -> Dict:
        if not symbol_regimes:
            return {"regime": "UNKNOWN", "confidence": 0.0, "count": 0, "total_symbols": 0}

        counts: Counter = Counter(v["regime"] for v in symbol_regimes.values())
        dominant, dom_count = counts.most_common(1)[0]

        avg_conf = round(
            sum(v["confidence"] for v in symbol_regimes.values() if v["regime"] == dominant)
            / max(dom_count, 1),
            2,
        )

        return {
            "regime": dominant,
            "confidence": avg_conf,
            "count": dom_count,
            "total_symbols": len(symbol_regimes),
            "info": REGIMES.get(dominant, {}),
        }

    def _distribution(self, symbol_regimes: Dict[str, Dict]) -> Dict[str, int]:
        dist: Dict[str, int] = {r: 0 for r in REGIMES}
        for v in symbol_regimes.values():
            dist[v["regime"]] = dist.get(v["regime"], 0) + 1
        return dist

    # ------------------------------------------------------------------
    # HTTP fetchers
    # ------------------------------------------------------------------

    # Symboles à interroger en fallback individuel quand /gom-verdicts est vide
    _FALLBACK_SYMBOLS = [
        "XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "BTCUSD", "ETHUSD",
        "Boom 500 Index", "Boom 300 Index", "Boom 1000 Index",
        "Crash 500 Index", "Crash 300 Index", "Crash 1000 Index",
    ]

    def _fetch_verdicts(self) -> List[Dict]:
        try:
            r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=6)
            if r.status_code == 200:
                verdicts = r.json().get("verdicts", [])
                if verdicts:
                    return verdicts
        except Exception:
            pass
        # Fallback : appels individuels pour les symboles connus
        return self._fetch_verdicts_individually()

    def _fetch_verdicts_individually(self) -> List[Dict]:
        """Appels /gom-verdict un par un quand le bulk endpoint est vide."""
        results = []
        for sym in self._FALLBACK_SYMBOLS:
            try:
                r = requests.get(
                    f"{AI_SERVER}/gom-verdict",
                    params={"symbol": sym},
                    timeout=4,
                )
                if r.status_code == 200:
                    data = r.json()
                    if data.get("ok"):
                        results.append(data)
            except Exception:
                pass
        return results

    def _fetch_cognition(self, symbol: str) -> Dict:
        """Fetch cognition forecast for a single symbol. Returns {} on any failure."""
        try:
            r = requests.get(
                f"{AI_SERVER}/cognition/forecast-200",
                params={"symbol": symbol, "timeframe": "M5"},
                timeout=4,
            )
            if r.status_code == 200:
                return r.json()
        except Exception:
            pass
        return {}
