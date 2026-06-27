"""Base class for all TradBOT intelligence agents."""

import time
import logging
import threading
from abc import ABC, abstractmethod
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Optional
from enum import Enum


class AgentStatus(str, Enum):
    IDLE = "idle"
    RUNNING = "running"
    ERROR = "error"
    DISABLED = "disabled"


@dataclass
class AgentMetrics:
    calls_total: int = 0
    calls_success: int = 0
    calls_error: int = 0
    avg_latency_ms: float = 0.0
    last_result: Optional[Dict] = None
    last_run_ts: float = 0.0
    last_error: str = ""

    @property
    def success_rate(self) -> float:
        if self.calls_total == 0:
            return 0.0
        return round(self.calls_success / self.calls_total * 100, 1)

    def to_dict(self) -> Dict:
        d = asdict(self)
        d["success_rate"] = self.success_rate
        return d


class AgentBase(ABC):
    """Common interface for all intelligence agents."""

    agent_id: str = "base"
    agent_name: str = "Base Agent"
    description: str = ""
    version: str = "1.0.0"
    interval_seconds: int = 60

    def __init__(self):
        self.logger = logging.getLogger(f"agent.{self.agent_id}")
        self.metrics = AgentMetrics()
        self.status = AgentStatus.IDLE
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._last_output: Dict = {}
        self._peers: Dict[str, "AgentBase"] = {}

    def register_peers(self, peers: Dict[str, "AgentBase"]) -> None:
        """Called by the orchestrator to wire peer agent references."""
        self._peers = {k: v for k, v in peers.items() if k != self.agent_id}

    def get_peer(self, agent_id: str) -> Dict:
        """Return the last output of a peer agent, or {} if unavailable."""
        peer = self._peers.get(agent_id)
        if peer is None:
            return {}
        return peer.get_last_output()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def start_background(self):
        """Launch the agent loop in a daemon thread."""
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._loop, daemon=True, name=self.agent_id)
        self._thread.start()
        self.logger.info("Agent %s started (interval=%ss)", self.agent_name, self.interval_seconds)

    def stop(self):
        self._stop_event.set()

    def run_once(self) -> Dict:
        """Execute one analysis cycle synchronously and return result dict."""
        t0 = time.time()
        self.status = AgentStatus.RUNNING
        try:
            result = self.analyze()
            self.metrics.calls_total += 1
            self.metrics.calls_success += 1
            self.metrics.last_run_ts = time.time()
            latency = (time.time() - t0) * 1000
            # Rolling average latency
            n = self.metrics.calls_success
            self.metrics.avg_latency_ms = (self.metrics.avg_latency_ms * (n - 1) + latency) / n
            result["_agent_id"] = self.agent_id
            result["_ts"] = self.metrics.last_run_ts
            result["_latency_ms"] = round(latency, 1)
            self._last_output = result
            self.metrics.last_result = {k: v for k, v in result.items() if not k.startswith("_")}
            self.status = AgentStatus.IDLE
            return result
        except Exception as exc:
            self.metrics.calls_total += 1
            self.metrics.calls_error += 1
            self.metrics.last_error = str(exc)
            self.status = AgentStatus.ERROR
            self.logger.error("Agent %s error: %s", self.agent_name, exc, exc_info=True)
            return {"_agent_id": self.agent_id, "error": str(exc), "_ts": time.time()}

    def get_last_output(self) -> Dict:
        return self._last_output

    def get_status_dict(self) -> Dict:
        return {
            "agent_id": self.agent_id,
            "agent_name": self.agent_name,
            "description": self.description,
            "version": self.version,
            "status": self.status.value,
            "interval_seconds": self.interval_seconds,
            "metrics": self.metrics.to_dict(),
            "last_output": self._last_output,
        }

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _loop(self):
        while not self._stop_event.is_set():
            self.run_once()
            self._stop_event.wait(timeout=self.interval_seconds)

    @abstractmethod
    def analyze(self) -> Dict[str, Any]:
        """Override in each agent. Return a plain dict with results."""
        ...
