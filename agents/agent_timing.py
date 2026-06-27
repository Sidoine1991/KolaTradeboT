"""
Agent 4 — Entry Micro-Timing Optimizer
Scores entry quality (0-100) for every actionable GOM signal using rich
per-symbol live data from /gom/live-status.

Data sources:
  - /gom-verdicts                      → bulk verdict list (fast)
  - /gom/live-status?symbol=<sym>      → full TF + indicator data per symbol

Scoring dimensions (100 pts total):
  coherence (25) + GOM gap (20) + supertrend (15) + OTE (10) +
  KOLA state (15) + RSI context (10) + entry_quality (5)
  Correction penalty: -15 pts

Boom/Crash law: hard block on wrong-direction verdicts (score = 0).
"""

import requests
from typing import Any, Dict, List

from .agent_base import AgentBase

AI_SERVER = "http://127.0.0.1:8000"

# Minimum coherence to bother fetching live data
_COH_THRESHOLD = 50.0


def _normalize_verdict(verdict: str) -> str:
    """Map GOM verdict string to 'BUY' | 'SELL' | 'HOLD'."""
    v = str(verdict).strip().upper()
    if v in ("BUY", "STRONG_BUY", "BUY_LIMIT", "BUY_STOP"):
        return "BUY"
    if v in ("SELL", "STRONG_SELL", "SELL_LIMIT", "SELL_STOP"):
        return "SELL"
    return "HOLD"


class EntryTimingAgent(AgentBase):
    agent_id = "timing"
    agent_name = "Entry Micro-Timing Optimizer"
    description = (
        "Scores entry quality 0-100 per symbol using GOM + live indicator data. "
        "Enforces Boom/Crash law. Returns best_entries top-5 and blocked list."
    )
    version = "2.0.0"
    interval_seconds = 30

    def __init__(self) -> None:
        super().__init__()
        self._timing_scores: Dict[str, Dict] = {}

    # ------------------------------------------------------------------
    # Main entry point
    # ------------------------------------------------------------------

    def analyze(self) -> Dict[str, Any]:
        verdicts = self._fetch_verdicts()

        # --- Peer intelligence: read regime, risk, news and trading_agents outputs ---
        regime_out = self.get_peer("regime")
        risk_out   = self.get_peer("risk")
        news_out   = self.get_peer("news")
        ta_out     = self.get_peer("trading_agents")

        # Global regime modifier: RANGING/VOLATILE → raise entry threshold
        global_regime = regime_out.get("global_regime", {}).get("regime", "UNKNOWN")
        symbol_regimes = regime_out.get("symbol_regimes", {})
        coh_boost = 10.0 if global_regime in ("RANGING", "VOLATILE") else 0.0

        # News: if high-impact active, add 10-pt penalty to all scores
        news_penalty = 10.0 if news_out.get("current_impact") == "HIGH" else 0.0

        # Risk: if budget < 30% → only accept IMMEDIATE entries
        daily_budget = risk_out.get("daily_budget_remaining", 999)
        risk_lvl = risk_out.get("risk_level", "NORMAL")
        strict_mode = risk_lvl in ("HIGH", "CRITICAL")

        # TradingAgents Agent 7: confidence boost for the deep-analysed symbol
        ta_symbol    = ta_out.get("symbol", "")
        ta_direction = ta_out.get("direction", "HOLD")
        ta_boost     = float(ta_out.get("ta_confidence_boost", 0.0))

        scored_entries: Dict[str, Dict] = {}
        blocked_entries: List[str] = []
        correction_warnings: List[str] = []

        for v in verdicts:
            sym = v.get("symbol", "")
            verdict = v.get("verdict", "WAIT")
            coherence = float(v.get("coherence_pct", 0))

            if not sym:
                continue
            # Skip WAIT verdicts and low-coherence signals (not worth live fetch)
            effective_threshold = _COH_THRESHOLD + coh_boost
            if verdict == "WAIT" or coherence < effective_threshold:
                continue

            live = self._fetch_live_status(sym)

            # Per-symbol regime context passed to scorer
            sym_regime = symbol_regimes.get(sym, {}).get("regime", global_regime)
            result = self._score_entry(v, live, sym_regime=sym_regime, news_penalty=news_penalty)

            # Strict mode: demote anything below IMMEDIATE when risk is HIGH/CRITICAL
            if strict_mode and result.get("recommendation") not in ("IMMEDIATE", "BLOCKED"):
                result["recommendation"] = "WAIT_RETEST"
                result["breakdown"].append(f"risk_{risk_lvl}_demoted")

            # Agent 7 boost: TradingAgents deep-analysed this symbol in same direction
            if (ta_boost > 0 and sym == ta_symbol
                    and ta_direction == _normalize_verdict(result.get("verdict", ""))):
                boosted = min(100.0, round(result["entry_score"] + ta_boost, 1))
                result = dict(result)
                result["entry_score"] = boosted
                result["breakdown"] = list(result.get("breakdown", [])) + [
                    f"TA7_boost={ta_direction}+{ta_boost:.0f}pts"
                ]
                if boosted >= 75 and result.get("recommendation") not in ("IMMEDIATE", "BLOCKED"):
                    result["recommendation"] = "IMMEDIATE"
                elif boosted >= 60 and result.get("recommendation") == "WAIT_RETEST":
                    result["recommendation"] = "ENTER_NOW"

            scored_entries[sym] = result
            self._timing_scores[sym] = result

            if result.get("blocked"):
                blocked_entries.append(sym)
            if result.get("is_correcting"):
                correction_warnings.append(sym)

        best_entries = self._rank_best(scored_entries)

        return {
            "scored_entries": scored_entries,
            "best_entries": best_entries,
            "blocked_entries": blocked_entries,
            "entry_count": len(scored_entries),
            "correction_warnings": correction_warnings,
            "peer_context": {
                "global_regime": global_regime,
                "coh_threshold_used": _COH_THRESHOLD + coh_boost,
                "news_penalty": news_penalty,
                "risk_strict_mode": strict_mode,
                "ta7_symbol": ta_symbol,
                "ta7_boost": ta_boost,
                "ta7_direction": ta_direction,
            },
        }

    # ------------------------------------------------------------------
    # Entry scoring
    # ------------------------------------------------------------------

    def _score_entry(self, v: Dict, live: Dict, sym_regime: str = "UNKNOWN", news_penalty: float = 0.0) -> Dict:
        symbol = v.get("symbol", "")
        verdict = v.get("verdict", "WAIT")
        score_buy = float(v.get("score_buy", 0))
        score_sell = float(v.get("score_sell", 0))
        coherence = float(v.get("coherence_pct", 0))
        gap = float(v.get("verdict_gap", 0))

        # Live data fields (fall back gracefully when live fetch failed)
        kola = live.get("kola_state", v.get("kola_state", ""))
        in_ote = bool(live.get("in_ote", False))
        st_dir = int(live.get("st_dir", 0))          # 1=bull, -1=bear
        spike_tradable = bool(live.get("spike_tradable", False))
        rsi = float(live.get("rsi14", live.get("rsi", 50)))
        tf_global = live.get("tf_global_dir", v.get("tf_global_dir", "NEUTRAL"))
        tf_strength = int(live.get("tf_global_strength", v.get("tf_global_strength", 0)))
        m1_dir = live.get("tf_m1_dir", v.get("tf_m1_dir", "NEUTRAL"))
        m5_dir = live.get("tf_m5_dir", v.get("tf_m5_dir", "NEUTRAL"))
        entry_quality = float(live.get("entry_quality", v.get("entry_quality", 0)))

        # Resolve entry/SL/TP: prefer live, fall back to verdict
        entry_price = float(live.get("entry", 0) or v.get("entry", 0) or 0)
        sl = float(v.get("sl", 0))
        tp = float(v.get("tp", 0))

        is_boom = "BOOM" in symbol.upper() or "PAINX" in symbol.upper()
        is_crash = "CRASH" in symbol.upper() or "GAINX" in symbol.upper()

        # ---- Hard block: Boom/Crash law ----
        if is_boom and "SELL" in verdict:
            return {
                "symbol": symbol,
                "entry_score": 0,
                "recommendation": "BLOCKED",
                "reason": "Boom=BUY_ONLY",
                "blocked": True,
                "breakdown": [],
                "entry_price": entry_price,
                "sl": sl,
                "tp": tp,
                "kola_state": kola,
                "in_ote": in_ote,
                "is_correcting": False,
                "coherence": coherence,
                "verdict": verdict,
            }
        if is_crash and "BUY" in verdict:
            return {
                "symbol": symbol,
                "entry_score": 0,
                "recommendation": "BLOCKED",
                "reason": "Crash=SELL_ONLY",
                "blocked": True,
                "breakdown": [],
                "entry_price": entry_price,
                "sl": sl,
                "tp": tp,
                "kola_state": kola,
                "in_ote": in_ote,
                "is_correcting": False,
                "coherence": coherence,
                "verdict": verdict,
            }

        pts = 0.0
        breakdown: List[str] = []
        is_buy_signal = "BUY" in verdict

        # 1. Coherence (0–25 pts)
        coh_pts = min(25.0, coherence * 0.25)
        pts += coh_pts
        breakdown.append(f"coherence={coherence:.0f}% +{coh_pts:.0f}pts")

        # 2. GOM gap (0–20 pts)
        gap_pts = min(20.0, gap * 5.0)
        pts += gap_pts
        breakdown.append(f"gap={gap:.1f} +{gap_pts:.0f}pts")

        # 3. Supertrend alignment (0–15 pts)
        st_aligned = (is_buy_signal and st_dir == 1) or (not is_buy_signal and st_dir == -1)
        if st_aligned:
            pts += 15.0
            breakdown.append("supertrend=aligned +15pts")
        elif st_dir != 0:
            breakdown.append(f"supertrend=opposing ({st_dir}) +0pts")

        # 4. OTE zone (0–10 pts)
        if in_ote:
            pts += 10.0
            breakdown.append("in_OTE_zone +10pts")

        # 5. KOLA state (0–15 pts)
        kola_pts = {"FORMING": 5, "ENTRY": 12, "CONFIRMED": 15, "RETEST": 13}.get(kola, 0)
        pts += float(kola_pts)
        if kola_pts > 0:
            breakdown.append(f"kola={kola} +{kola_pts}pts")

        # 6. RSI context (0–10 pts)
        if is_buy_signal:
            if rsi < 35:
                pts += 10.0
                breakdown.append(f"rsi={rsi:.0f}(oversold) +10pts")
            elif rsi < 45:
                pts += 5.0
                breakdown.append(f"rsi={rsi:.0f}(low) +5pts")
        else:
            if rsi > 65:
                pts += 10.0
                breakdown.append(f"rsi={rsi:.0f}(overbought) +10pts")
            elif rsi > 55:
                pts += 5.0
                breakdown.append(f"rsi={rsi:.0f}(high) +5pts")

        # 7. Correction penalty: short TFs contradicting the signal direction
        is_correcting = (
            (is_buy_signal and m1_dir == "BEAR" and m5_dir == "BEAR")
            or (not is_buy_signal and m1_dir == "BULL" and m5_dir == "BULL")
        )
        if is_correcting:
            pts = max(0.0, pts - 15.0)
            breakdown.append("correction_detected -15pts")

        # 8. Entry quality from GOM (0–5 pts)
        eq_pts = min(5.0, entry_quality * 0.05)
        pts += eq_pts
        if eq_pts > 0:
            breakdown.append(f"entry_quality={entry_quality:.0f} +{eq_pts:.1f}pts")

        # 9. Peer regime bonus/malus
        if sym_regime in ("TRENDING_UP", "TRENDING_DOWN"):
            pts += 5.0
            breakdown.append(f"regime={sym_regime} +5pts")
        elif sym_regime == "BREAKOUT":
            pts += 8.0
            breakdown.append(f"regime=BREAKOUT +8pts")
        elif sym_regime == "RANGING":
            pts = max(0.0, pts - 8.0)
            breakdown.append("regime=RANGING -8pts")
        elif sym_regime == "VOLATILE":
            pts = max(0.0, pts - 5.0)
            breakdown.append("regime=VOLATILE -5pts")

        # 10. News high-impact penalty
        if news_penalty > 0:
            pts = max(0.0, pts - news_penalty)
            breakdown.append(f"news_HIGH -{news_penalty:.0f}pts")

        pts = min(100.0, round(pts, 1))

        # Recommendation thresholds
        if pts >= 75:
            rec = "IMMEDIATE"
        elif pts >= 60:
            rec = "ENTER_NOW"
        elif pts >= 45:
            rec = "WAIT_RETEST"
        else:
            rec = "SKIP"

        return {
            "symbol": symbol,
            "verdict": verdict,
            "entry_score": pts,
            "recommendation": rec,
            "breakdown": breakdown,
            "entry_price": entry_price,
            "sl": sl,
            "tp": tp,
            "kola_state": kola,
            "in_ote": in_ote,
            "is_correcting": is_correcting,
            "coherence": coherence,
            "blocked": False,
        }

    # ------------------------------------------------------------------
    # Ranking
    # ------------------------------------------------------------------

    def _rank_best(self, scored: Dict[str, Dict]) -> List[Dict]:
        """Top-5 entries excluding BLOCKED and SKIP."""
        eligible = [
            v for v in scored.values()
            if not v.get("blocked") and v.get("recommendation") != "SKIP"
        ]
        eligible.sort(key=lambda x: -x["entry_score"])
        return [
            {
                "rank": i + 1,
                "symbol": s["symbol"],
                "verdict": s.get("verdict", ""),
                "entry_score": s["entry_score"],
                "recommendation": s["recommendation"],
                "entry_price": s["entry_price"],
                "sl": s["sl"],
                "tp": s["tp"],
                "kola_state": s.get("kola_state", ""),
                "in_ote": s.get("in_ote", False),
                "is_correcting": s.get("is_correcting", False),
                "coherence": s.get("coherence", 0),
            }
            for i, s in enumerate(eligible[:5])
        ]

    # ------------------------------------------------------------------
    # HTTP fetchers
    # ------------------------------------------------------------------

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
        return self._fetch_verdicts_individually()

    def _fetch_verdicts_individually(self) -> List[Dict]:
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

    def _fetch_live_status(self, symbol: str) -> Dict:
        """Fetch rich live data for one symbol. Returns {} on any failure."""
        try:
            r = requests.get(
                f"{AI_SERVER}/gom/live-status",
                params={"symbol": symbol},
                timeout=4,
            )
            if r.status_code == 200:
                return r.json()
        except Exception:
            pass
        return {}
