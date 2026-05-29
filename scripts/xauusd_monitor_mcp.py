#!/usr/bin/env python3
"""
XAUUSD Monitor MCP wrapper - calls Claude Code to fetch TradingView data via MCP.
Integrates with xauusd_whatsapp_monitor.py pipeline.
"""

import subprocess
import json
import sys
from pathlib import Path
from datetime import datetime, timezone

UTC = timezone.utc


def call_claude_mcp(mcp_calls: list) -> dict:
    """
    Call Claude Code to execute MCP functions.
    Returns dict with results keyed by MCP function name.
    """
    # Generate Claude Code commands as a single prompt
    prompt = f"""Execute these MCP calls in parallel and return JSON results:

{json.dumps(mcp_calls, indent=2)}

Format response as JSON only, one line per result:
{{"quote": <result1>, "indicators": <result2>, "gom_tables": <result3>}}
"""

    try:
        result = subprocess.run(
            ["claude", "code", "--no-edit"],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            print(f"[Claude Error] {result.stderr}", file=sys.stderr)
            return {}

        # Parse JSON response
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            print(f"[Parse Error] Invalid JSON response", file=sys.stderr)
            return {}

    except subprocess.TimeoutExpired:
        print("[Error] Claude MCP call timeout", file=sys.stderr)
        return {}
    except Exception as e:
        print(f"[Error] Claude call failed: {e}", file=sys.stderr)
        return {}


def fetch_tradingview_data() -> dict:
    """
    Fetch all TradingView data via Claude MCP in parallel.
    Returns dict with quote, indicators, and gom_verdict.
    """
    mcp_calls = [
        {
            "function": "mcp__tradingview-kola__quote_get",
            "params": {"symbol": "OANDA:XAUUSD"},
            "key": "quote",
        },
        {
            "function": "mcp__tradingview-kola__data_get_study_values",
            "params": {},
            "key": "indicators",
        },
        {
            "function": "mcp__tradingview-kola__data_get_pine_tables",
            "params": {"study_filter": "GOM KOLA"},
            "key": "gom_tables",
        },
    ]

    print("[TradingView] Fetching data via MCP...")
    results = call_claude_mcp(mcp_calls)

    # Parse GOM verdict from tables
    gom_verdict = {"verdict": "WAIT", "score_buy": 0, "score_sell": 0, "spike_pct": 0}

    if "gom_tables" in results:
        try:
            tables = results["gom_tables"]
            # Extract verdict line (first row usually has verdict)
            # This is a simplified parser — adjust based on actual GOM table format
            if tables and len(tables) > 0:
                first_table = tables[0]
                if "SELL" in str(first_table).upper():
                    gom_verdict["verdict"] = "SELL"
                elif "BUY" in str(first_table).upper():
                    gom_verdict["verdict"] = "BUY"
        except Exception as e:
            print(f"[GOM Parse Error] {e}", file=sys.stderr)

    return {
        "quote": results.get("quote", {}),
        "indicators": results.get("indicators", {}),
        "gom_verdict": gom_verdict,
    }


if __name__ == "__main__":
    data = fetch_tradingview_data()
    print(json.dumps(data, indent=2))
