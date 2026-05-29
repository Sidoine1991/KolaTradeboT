#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
📊 MONITOR EAs — Vérifier que les EAs tournent et signalent des trades
"""

import os
import subprocess
import time
import re
from datetime import datetime, timedelta
from pathlib import Path

LOG_DIR = r"D:\Dev\TradBOT"
WHATSAPP_LOG = os.path.join(LOG_DIR, "whatsapp_alerts.log")
EXPERT_LOG_PATTERN = r"[GOM-Auto]|[SpikeRider]"

def log(msg, level="INFO"):
    """Print formatted message"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    colors = {
        "INFO": "\033[94m",
        "OK": "\033[92m",
        "WARN": "\033[93m",
        "ERROR": "\033[91m",
        "TRADE": "\033[92m",
    }
    reset = "\033[0m"
    color = colors.get(level, "")
    symbol = {"INFO": "ℹ️ ", "OK": "✅", "WARN": "⚠️ ", "ERROR": "❌", "TRADE": "📈"}.get(level, "•")
    print(f"{color}[{timestamp}] {symbol} {msg}{reset}")

def check_mt5_running():
    """Check if MT5 terminal is running"""
    result = subprocess.run(['tasklist'], capture_output=True, text=True)
    return "terminal64.exe" in result.stdout

def read_expert_logs():
    """Read recent Expert Advisor logs from MT5"""
    try:
        # MT5 Expert logs are typically in:
        expert_log_path = os.path.expandvars(r"%APPDATA%\MetaQuotes\Terminal\Common\Logs\*.log")

        # Try to find the most recent terminal
        terminal_dirs = Path(os.path.expandvars(r"%APPDATA%\MetaQuotes\Terminal")).glob("*/Logs")

        recent_logs = []
        for log_dir in terminal_dirs:
            for log_file in log_dir.glob("*.log"):
                try:
                    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        if re.search(EXPERT_LOG_PATTERN, content):
                            recent_logs.append((log_file, content))
                except:
                    pass

        return recent_logs
    except Exception as e:
        log(f"Error reading logs: {e}", "WARN")
        return []

def check_recent_trades():
    """Check if there are recent trades in whatsapp_alerts.log"""
    if not os.path.exists(WHATSAPP_LOG):
        return []

    try:
        with open(WHATSAPP_LOG, 'r') as f:
            content = f.read()
            # Find recent collections (last 1 hour)
            collections = re.findall(r'\[2026-05-29 \d{2}:\d{2}:\d{2}\].*?Collection #(\d+)', content)
            return collections[-5:] if collections else []  # Last 5
    except:
        return []

def check_ea_parameters():
    """Verify that key parameters are correctly set"""
    log("Checking EA parameter modifications...", "INFO")

    params_to_check = {
        r"D:\Dev\TradBOT\TradeManager.mq5": [
            ("GOMBlockOnWait = false", "GOMBlockOnWait disabled"),
            ("GOMMinCoherence = 50", "GOMMinCoherence = 50%"),
        ],
        r"D:\Dev\TradBOT\SpikeRiderEA.mq5": [
            ("InpGOMBlockOnWait = false", "InpGOMBlockOnWait disabled"),
            ("InpSniperMinConfidence = 50", "InpSniperMinConfidence = 50%"),
        ],
    }

    for filepath, checks in params_to_check.items():
        if not os.path.exists(filepath):
            log(f"  ✗ File not found: {filepath}", "ERROR")
            continue

        with open(filepath, 'r') as f:
            content = f.read()

        filename = os.path.basename(filepath)
        for pattern, desc in checks:
            if pattern in content:
                log(f"  ✓ {filename}: {desc}", "OK")
            else:
                log(f"  ✗ {filename}: {desc} NOT FOUND", "ERROR")

def main():
    print("════════════════════════════════════════════════════════════════")
    print("  📊 EA MONITORING DASHBOARD")
    print("════════════════════════════════════════════════════════════════")
    print()

    # Check 1: MT5 Running
    log("Checking if MT5 is running...", "INFO")
    if check_mt5_running():
        log("MT5 terminal is ONLINE", "OK")
    else:
        log("MT5 terminal is OFFLINE - Start MT5 to begin trading", "WARN")
    print()

    # Check 2: Parameters
    log("Step 1: Parameter Verification", "INFO")
    check_ea_parameters()
    print()

    # Check 3: Recent logs
    log("Step 2: Reading Expert Advisor Logs", "INFO")
    logs = read_expert_logs()
    if logs:
        for log_file, content in logs:
            # Extract GOM-Auto and SpikeRider messages
            gom_messages = re.findall(r'\[GOM-Auto\].*', content)
            spike_messages = re.findall(r'\[SpikeRider\].*', content)

            if gom_messages:
                log(f"  Found {len(gom_messages)} TradeManager messages", "OK")
                for msg in gom_messages[-3:]:  # Last 3
                    print(f"    → {msg[:80]}")

            if spike_messages:
                log(f"  Found {len(spike_messages)} SpikeRiderEA messages", "OK")
                for msg in spike_messages[-3:]:
                    print(f"    → {msg[:80]}")
    else:
        log("  No recent Expert Advisor logs found", "WARN")
        log("  → Start MT5 and attach EAs to charts", "INFO")
    print()

    # Check 4: Recent trades
    log("Step 3: Recent Trade Activity", "INFO")
    trades = check_recent_trades()
    if trades:
        log(f"  Found {len(trades)} recent trade collections", "OK")
        log(f"  Latest collections: #{', #'.join(trades)}", "INFO")
    else:
        log("  No trade collections found in log", "WARN")
        log("  → Trades will appear here as they execute", "INFO")
    print()

    # Summary
    print("════════════════════════════════════════════════════════════════")
    print("  📋 NEXT STEPS")
    print("════════════════════════════════════════════════════════════════")
    print()
    print("If trades are not executing:")
    print("  1. Verify Terminal > Allow algorithmic trading = ON")
    print("  2. Attach EAs to charts (right-click chart > Expert Advisors)")
    print("  3. Check that parameters in EA Inputs match expected values")
    print("  4. Monitor logs (F2 in MT5) for [GOM-Auto] and [SpikeRider]")
    print()
    print("If compilation failed:")
    print("  1. Re-run: RUN_AUTO_COMPILE.bat")
    print("  2. Or compile manually in MetaEditor with F9")
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        log("Interrupted", "WARN")
    except Exception as e:
        log(f"Error: {e}", "ERROR")
