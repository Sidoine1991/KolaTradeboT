"""
Agent 6 — Macro & News Filter
Fetches economic calendar events, computes impact scores, and filters
or adjusts confidence around high-impact events (NFP, CPI, FOMC, etc.).
Also tracks session schedule (London/New York/Tokyo) to prefer high-liquidity windows.
"""

import os
import time
import requests
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
from .agent_base import AgentBase

# Use Alpha Vantage for news sentiment (already in ai_server)
ALPHAVANTAGE_KEY = os.getenv("ALPHAVANTAGE_API_KEY", "")
NEWSAPI_KEY = os.getenv("NEWSAPI_KEY", "")

# Trading sessions in UTC
SESSIONS = {
    "Tokyo":    {"open": 0,  "close": 9},   # 00:00–09:00 UTC
    "London":   {"open": 8,  "close": 16},  # 08:00–16:00 UTC
    "New York": {"open": 13, "close": 21},  # 13:00–21:00 UTC
}

# High-impact events — if detected in news/calendar, apply penalty
HIGH_IMPACT_KEYWORDS = [
    "nonfarm", "nfp", "payroll", "cpi", "inflation", "fomc", "federal reserve",
    "rate decision", "gdp", "pce", "unemployment", "jobs report",
    "ecb", "boe", "boj", "rba", "central bank"
]

IMPACT_LEVELS = {
    "HIGH": {"confidence_modifier": -0.15, "lot_modifier": 0.50, "color": "#ef4444"},
    "MEDIUM": {"confidence_modifier": -0.07, "lot_modifier": 0.75, "color": "#f59e0b"},
    "LOW": {"confidence_modifier": 0.0, "lot_modifier": 1.0, "color": "#22c55e"},
    "NONE": {"confidence_modifier": 0.0, "lot_modifier": 1.0, "color": "#94a3b8"},
}


class MacroFilterAgent(AgentBase):
    agent_id = "news"
    agent_name = "Macro & News Filter"
    description = "Economic calendar awareness, news sentiment, session filter. Reduces risk around high-impact events."
    version = "1.0.0"
    interval_seconds = 600  # 10-minute cycle (API rate limits)

    def __init__(self):
        super().__init__()
        self._current_impact: str = "NONE"
        self._upcoming_events: List[Dict] = []
        self._news_sentiment: Dict[str, float] = {}
        self._last_fetch_ts: float = 0.0

    def analyze(self) -> Dict[str, Any]:
        now_utc = datetime.now(timezone.utc)
        session_info = self._session_status(now_utc)
        upcoming_events = self._fetch_calendar_events()
        self._upcoming_events = upcoming_events

        impact = self._compute_impact(upcoming_events, now_utc)
        self._current_impact = impact

        sentiment = self._fetch_news_sentiment()
        self._news_sentiment = sentiment

        modifiers = IMPACT_LEVELS.get(impact, IMPACT_LEVELS["NONE"])

        return {
            "current_impact": impact,
            "impact_info": modifiers,
            "upcoming_events": upcoming_events[:5],
            "session": session_info,
            "news_sentiment": sentiment,
            "trading_allowed": impact != "HIGH" or session_info["overlap_count"] >= 2,
            "global_confidence_modifier": modifiers["confidence_modifier"],
            "global_lot_modifier": modifiers["lot_modifier"],
            "next_high_impact": self._next_high_impact(upcoming_events, now_utc),
        }

    # ------------------------------------------------------------------
    # Calendar
    # ------------------------------------------------------------------

    def _fetch_calendar_events(self) -> List[Dict]:
        """
        Try Alpha Vantage economic calendar. Falls back to a static
        heuristic (known recurring events) if API unavailable.
        """
        # Use cache to avoid hammering the API
        if time.time() - self._last_fetch_ts < 300:
            return self._upcoming_events

        if ALPHAVANTAGE_KEY:
            try:
                url = (
                    f"https://www.alphavantage.co/query"
                    f"?function=EARNINGS_CALENDAR&horizon=3month&apikey={ALPHAVANTAGE_KEY}"
                )
                r = requests.get(url, timeout=8)
                if r.status_code == 200:
                    # Alpha Vantage earnings calendar (CSV format)
                    lines = r.text.strip().split("\n")
                    events = []
                    for line in lines[1:10]:  # first 10 rows
                        parts = line.split(",")
                        if len(parts) >= 3:
                            events.append({
                                "name": parts[0],
                                "date": parts[1] if len(parts) > 1 else "",
                                "impact": "MEDIUM",
                                "source": "alpha_vantage",
                            })
                    self._last_fetch_ts = time.time()
                    return events
            except Exception as e:
                self.logger.debug("Alpha Vantage calendar error: %s", e)

        # Fallback: synthetic weekly recurring events
        self._last_fetch_ts = time.time()
        return self._synthetic_calendar()

    def _synthetic_calendar(self) -> List[Dict]:
        """Returns known weekly/monthly recurring high-impact events."""
        now = datetime.now(timezone.utc)
        events = []

        # Friday 12:30 UTC — NFP (first Friday of month)
        if now.weekday() == 4:  # Friday
            nfp_time = now.replace(hour=12, minute=30, second=0, microsecond=0)
            events.append({
                "name": "Non-Farm Payrolls (if 1st Friday)",
                "date": nfp_time.isoformat(),
                "impact": "HIGH",
                "source": "synthetic",
            })

        # Wednesday 18:00 UTC — FOMC (bi-weekly approximation)
        if now.weekday() == 2:
            fomc_time = now.replace(hour=18, minute=0, second=0, microsecond=0)
            events.append({
                "name": "FOMC Minutes / Rate Decision",
                "date": fomc_time.isoformat(),
                "impact": "HIGH",
                "source": "synthetic",
            })

        return events

    def _compute_impact(self, events: List[Dict], now: datetime) -> str:
        """Return impact level of the nearest upcoming event."""
        window = timedelta(minutes=30)
        for event in events:
            evt_date_str = event.get("date", "")
            impact = event.get("impact", "LOW")
            try:
                evt_dt = datetime.fromisoformat(evt_date_str.replace("Z", "+00:00"))
                if evt_dt.tzinfo is None:
                    evt_dt = evt_dt.replace(tzinfo=timezone.utc)
                diff = abs((evt_dt - now).total_seconds())
                if diff <= window.total_seconds():
                    return impact
            except Exception:
                continue
        return "NONE"

    def _next_high_impact(self, events: List[Dict], now: datetime) -> Optional[Dict]:
        for event in sorted(events, key=lambda e: e.get("date", "")):
            if event.get("impact") == "HIGH":
                return event
        return None

    # ------------------------------------------------------------------
    # Sentiment
    # ------------------------------------------------------------------

    def _fetch_news_sentiment(self) -> Dict[str, float]:
        """Fetch sentiment scores per asset from Alpha Vantage news API."""
        sentiment: Dict[str, float] = {}
        if not ALPHAVANTAGE_KEY:
            return sentiment
        for ticker in ["GOLD", "EUR", "BTC"]:
            try:
                url = (
                    f"https://www.alphavantage.co/query"
                    f"?function=NEWS_SENTIMENT&tickers={ticker}&limit=5&apikey={ALPHAVANTAGE_KEY}"
                )
                r = requests.get(url, timeout=6)
                if r.status_code == 200:
                    data = r.json()
                    feed = data.get("feed", [])
                    if feed:
                        scores = [float(item.get("overall_sentiment_score", 0)) for item in feed[:5]]
                        sentiment[ticker] = round(sum(scores) / len(scores), 3)
            except Exception:
                pass
        return sentiment

    # ------------------------------------------------------------------
    # Session analysis
    # ------------------------------------------------------------------

    def _session_status(self, now: datetime) -> Dict:
        hour = now.hour
        active = []
        for name, sess in SESSIONS.items():
            if sess["open"] <= hour < sess["close"]:
                active.append(name)

        best = "low_liquidity"
        if "London" in active and "New York" in active:
            best = "peak_overlap"
        elif active:
            best = active[0]

        return {
            "hour_utc": hour,
            "active_sessions": active,
            "overlap_count": len(active),
            "quality": best,
            "recommended": best in ("peak_overlap", "London", "New York"),
        }
