#!/usr/bin/env python3
"""Live trade monitor - watch orders execute in real-time"""

import time
import json
from pathlib import Path
from datetime import datetime

# Logs MT5
MT5_DERIV_LOG = Path("C:/Users/USER/AppData/Roaming/MetaQuotes/Terminal/D0E8209F52F57601B1E8F35F5DF18F14/Logs")
MT5_WELTRADE_LOG = Path("C:/Users/USER/AppData/Roaming/MetaQuotes/Terminal/F016FF5B93786543B564E81A925D7066/Logs")

def read_latest_log(log_dir):
    """Get the most recent EA log"""
    if not log_dir.exists():
        return None
    logs = sorted(log_dir.glob("*.log"), key=lambda f: f.stat().st_mtime, reverse=True)
    return logs[0] if logs else None

def tail_log(file_path, lines=20):
    """Read last N lines from log file"""
    try:
        with open(file_path, 'r', errors='ignore') as f:
            all_lines = f.readlines()
            return all_lines[-lines:]
    except:
        return []

def extract_trade_events(log_lines):
    """Extract trade-relevant events from logs"""
    events = []
    for line in log_lines:
        line = line.strip()
        if not line:
            continue

        # Look for key patterns
        if any(x in line for x in ["TRADE", "ORDRE", "BUY", "SELL", "PERFECT", "GOOD", "HOLD", "override", "bloque", "autorise"]):
            # Extract timestamp
            if "[" in line and "]" in line:
                ts = line.split("]")[0] + "]"
            else:
                ts = datetime.now().strftime("%H:%M:%S")

            events.append({
                "time": ts,
                "message": line,
                "is_important": any(x in line.upper() for x in ["PERFECT", "OVERRIDE", "TRADE", "AUTORISE"])
            })

    return events

def main():
    print("\n" + "="*80)
    print("LIVE TRADE MONITOR - GOM Override System")
    print("="*80)

    deriv_log = read_latest_log(MT5_DERIV_LOG)
    weltrade_log = read_latest_log(MT5_WELTRADE_LOG)

    if not deriv_log and not weltrade_log:
        print("[ERROR] Cannot find MT5 logs!")
        print("  Deriv:    ", MT5_DERIV_LOG)
        print("  Weltrade: ", MT5_WELTRADE_LOG)
        return

    print("\n[INFO] Deriv log:    ", deriv_log.name if deriv_log else "Not found")
    print("[INFO] Weltrade log: ", weltrade_log.name if weltrade_log else "Not found")
    print("\n[*] Monitoring for trade events (Ctrl+C to stop)...\n")

    last_pos = {"deriv": 0, "weltrade": 0}

    try:
        while True:
            # Read Deriv logs
            if deriv_log:
                print("[DERIV] Latest events:")
                lines = tail_log(deriv_log, lines=10)
                events = extract_trade_events(lines)
                for evt in events:
                    marker = "***" if evt["is_important"] else "   "
                    print(f"  {marker} {evt['time']} {evt['message'][:100]}")

            print()

            # Read Weltrade logs
            if weltrade_log:
                print("[WELTRADE] Latest events:")
                lines = tail_log(weltrade_log, lines=10)
                events = extract_trade_events(lines)
                for evt in events:
                    marker = "***" if evt["is_important"] else "   "
                    print(f"  {marker} {evt['time']} {evt['message'][:100]}")

            print("\n" + "-"*80)
            print(f"Last update: {datetime.now().strftime('%H:%M:%S')}")
            print("Waiting 5 seconds before refresh...\n")

            time.sleep(5)

    except KeyboardInterrupt:
        print("\n\n[*] Monitor stopped")

if __name__ == "__main__":
    main()
