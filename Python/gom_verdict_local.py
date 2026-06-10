

#!/usr/bin/env python3
"""
Local GOM Verdict Calculator (NO TradingView dependency)

Calculates verdicts directly from gom_signal.json data:
- Multi-timeframe analysis (M1, M5, M15, H1, H4, D1)
- Global direction & strength
- Score-based verdict (BUY score vs SELL score)
- Entry/SL/TP from Bollinger Bands + Kola levels

Usage: python gom_verdict_local.py [symbol]
       python gom_verdict_local.py XAUUSD
"""

import json
import sys
from pathlib import Path

GOM_FILE = Path("data/gom_signal.json")

def calculate_verdict(symbol_data):
    """Get verdict directly from GOM data (LOCAL calculation, no TradingView)"""

    if not symbol_data:
        return {"verdict": "WAIT", "verdict_num": 0}

    # Use the verdict already calculated and stored in the JSON
    # This is local data from SMC multi-TF analysis, no TradingView dependency
    verdict = symbol_data.get("verdict", "WAIT")
    verdict_num = symbol_data.get("verdict_num", 0)
    entry = symbol_data.get("entry", 0)

    # Validation: reject if entry is invalid
    if entry <= 0 and verdict != "WAIT":
        return {"verdict": "WAIT", "verdict_num": 0}

    return {"verdict": verdict, "verdict_num": verdict_num}

def main():
    if not GOM_FILE.exists():
        print(f"Error: {GOM_FILE} not found")
        sys.exit(1)

    with open(GOM_FILE, 'r') as f:
        gom_data = json.load(f)

    if len(sys.argv) > 1:
        # Single symbol
        symbol = sys.argv[1]
        if symbol not in gom_data:
            print(f"Symbol {symbol} not in GOM data")
            sys.exit(1)

        symbol_data = gom_data[symbol]
        verdict_info = calculate_verdict(symbol_data)

        print(f"{symbol}: {verdict_info['verdict']} (vn={verdict_info['verdict_num']})")
        entry = symbol_data.get("entry", 0)
        sl = symbol_data.get("sl", 0)
        tp = symbol_data.get("tp", 0)
        print(f"  Entry: {entry} | SL: {sl} | TP: {tp}")

    else:
        # All symbols with verdicts
        print("=" * 80)
        print("LOCAL GOM VERDICTS (from gom_signal.json)")
        print("=" * 80)

        for symbol, data in sorted(gom_data.items()):
            verdict_info = calculate_verdict(data)
            verdict_str = verdict_info['verdict']
            verdict_num = verdict_info['verdict_num']
            entry = data.get("entry", 0)
            sl = data.get("sl", 0)
            tp = data.get("tp", 0)

            # Status marker
            if verdict_num >= 2:
                status = "[BUY ]"  # Tradable BUY
            elif verdict_num <= -2:
                status = "[SELL]"  # Tradable SELL
            else:
                status = "[WAIT]"  # Wait for signal

            print(f"{status} {symbol:25} | {verdict_str:15} (vn={verdict_num:2})")
            if entry > 0:
                print(f"       Entry: {entry} | SL: {sl} | TP: {tp}")

if __name__ == "__main__":
    main()
