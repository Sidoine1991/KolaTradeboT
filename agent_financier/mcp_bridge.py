#!/usr/bin/env python3
"""mcp_bridge.py – Interface MCP TradingView."""
import json
import logging
import subprocess
from pathlib import Path
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

MCP_BASE = Path("D:/Dev/Depot Github/tradingview-mcp_kola")
ANALYZER = MCP_BASE / "scripts" / "tv_smc_analyzer.mjs"


@dataclass
class TradingViewSetup:
    symbol: str
    direction: str
    entry: float
    stop_loss: float
    take_profit: float
    rr: float
    strength: str
    confidence_score: int
    reason: str
    timeframes: Dict[str, Any]


class MCPBridge:
    def __init__(self, mcp_path: Optional[Path] = None):
        self.mcp_path = mcp_path or MCP_BASE
        self.analyzer = mcp_path or ANALYZER

    def analyze_symbol(self, symbol: str, exchange: str = "OANDA") -> Optional[TradingViewSetup]:
        tv_ticker = f"{exchange}:{symbol}"
        try:
            result = subprocess.run(
                ["node", str(self.analyzer), tv_ticker],
                capture_output=True, text=True, timeout=120, cwd=str(self.mcp_path)
            )
            if result.returncode != 0:
                logger.error("MCP error: %s", result.stderr)
                return None
            data = json.loads(result.stdout.strip())
            return self._parse(data, symbol)
        except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception) as e:
            logger.error("Erreur analyse %s: %s", symbol, e)
            return None

    def _parse(self, data: Dict, symbol: str) -> Optional[TradingViewSetup]:
        if not data.get("success"):
            return None
        entry_setup = data.get("entry_setup")
        confluence = data.get("confluence", {})
        if not entry_setup or confluence.get("score", 0) < 3:
            return None
        return TradingViewSetup(
            symbol=symbol,
            direction=entry_setup["direction"],
            entry=entry_setup["entry"],
            stop_loss=entry_setup["stop_loss"],
            take_profit=entry_setup["take_profit"],
            rr=entry_setup["rr"],
            strength=entry_setup["strength"],
            confidence_score=confluence["score"],
            reason=entry_setup["reason"],
            timeframes=data.get("timeframes", {})
        )

    def batch_analyze(self, symbols: List[Dict]) -> List[TradingViewSetup]:
        results = []
        for item in symbols:
            setup = self.analyze_symbol(item["symbol"], item.get("exchange", "OANDA"))
            if setup:
                results.append(setup)
                logger.info("Setup %s %s @ %.5f", setup.direction, item["symbol"], setup.entry)
        return results
