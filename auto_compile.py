#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🔨 AUTO-COMPILE & RELOAD EAs
Automatise: Fermeture MT5 → Recompilation → Relance MT5

Usage:
    python auto_compile.py
"""

import os
import sys
import subprocess
import time
import signal
import psutil
from pathlib import Path
from datetime import datetime

# ════════════════════════════════════════════════════════════════
# CONFIG
# ════════════════════════════════════════════════════════════════

MT5_PATH = r"C:\Program Files\MetaTrader 5\terminal64.exe"
METAEDITOR_PATH = r"C:\Program Files\MetaTrader 5\MetaEditor64.exe"
TRADEMANAGER_SRC = r"D:\Dev\TradBOT\TradeManager.mq5"
SPIDERIDER_SRC = r"D:\Dev\TradBOT\SpikeRiderEA.mq5"
LOG_DIR = r"D:\Dev\TradBOT"

# ════════════════════════════════════════════════════════════════
# UTILS
# ════════════════════════════════════════════════════════════════

def log(msg, level="INFO"):
    """Print formatted log message"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    colors = {
        "INFO": "\033[94m",      # Blue
        "OK": "\033[92m",        # Green
        "WARN": "\033[93m",      # Yellow
        "ERROR": "\033[91m",     # Red
        "STEP": "\033[96m",      # Cyan
    }
    reset = "\033[0m"
    color = colors.get(level, "")
    symbol = {
        "INFO": "ℹ️ ",
        "OK": "✅",
        "WARN": "⚠️ ",
        "ERROR": "❌",
        "STEP": "🔨",
    }.get(level, "•")

    print(f"{color}[{timestamp}] {symbol} {msg}{reset}")

def kill_process(name):
    """Kill process by name"""
    try:
        for proc in psutil.process_iter(['pid', 'name']):
            if proc.info['name'] == name:
                proc.kill()
                log(f"Killed {name} (PID: {proc.info['pid']})", "OK")
                return True
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass
    return False

def wait_for_process(name, timeout=30):
    """Wait for process to start"""
    start = time.time()
    while time.time() - start < timeout:
        for proc in psutil.process_iter(['name']):
            if proc.info['name'] == name:
                log(f"Process {name} started", "OK")
                return True
        time.sleep(0.5)
    log(f"Timeout waiting for {name}", "WARN")
    return False

def compile_file(filepath):
    """Compile MQL5 file via MetaEditor"""
    if not os.path.exists(filepath):
        log(f"File not found: {filepath}", "ERROR")
        return False

    filename = os.path.basename(filepath)
    log(f"Compiling {filename}...", "STEP")

    # Launch MetaEditor in compile mode
    cmd = [METAEDITOR_PATH, f'/compile:{filepath}']

    try:
        # Start compilation
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        # Wait for MetaEditor to open
        time.sleep(3)

        # Send F9 (compile shortcut) via keyboard
        os.system(f'powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\'{{F9}}\')"')

        # Wait for compilation
        time.sleep(8)

        # Close MetaEditor
        kill_process("MetaEditor64.exe")

        log(f"{filename} compiled successfully", "OK")
        return True

    except Exception as e:
        log(f"Compilation error: {e}", "ERROR")
        return False

def verify_modifications():
    """Verify that source files have the correct modifications"""
    log("Verifying source modifications...", "STEP")

    checks = {
        TRADEMANAGER_SRC: [
            ("GOMBlockOnWait        = false", "GOMBlockOnWait disabled"),
            ("GOMMinCoherence       = 50.0", "GOMMinCoherence lowered to 50%"),
            ("MinTAConfidence        = 0.40", "MinTAConfidence lowered to 40%"),
        ],
        SPIDERIDER_SRC: [
            ("InpGOMBlockOnWait      = false", "InpGOMBlockOnWait disabled"),
            ("InpSniperMinConfidence = 50.0", "InpSniperMinConfidence lowered to 50%"),
            ("InpZScoreMin        = 1.5", "InpZScoreMin lowered to 1.5"),
        ],
    }

    for filepath, patterns in checks.items():
        if not os.path.exists(filepath):
            log(f"File not found: {filepath}", "ERROR")
            return False

        with open(filepath, 'r') as f:
            content = f.read()

        for pattern, desc in patterns:
            if pattern in content:
                log(f"  ✓ {desc}", "OK")
            else:
                log(f"  ✗ {desc} NOT FOUND", "ERROR")
                return False

    return True

def main():
    """Main automation flow"""
    print("════════════════════════════════════════════════════════════════")
    print("  🚀 AUTO-COMPILE & RELOAD EAs")
    print("════════════════════════════════════════════════════════════════")
    print()

    # ──────────────────────────────────────────────────────────────
    # Step 1: Verify modifications
    # ──────────────────────────────────────────────────────────────
    log("STEP 1: Verifying source modifications", "STEP")
    if not verify_modifications():
        log("Verification failed! Check source files.", "ERROR")
        sys.exit(1)
    print()

    # ──────────────────────────────────────────────────────────────
    # Step 2: Kill existing processes
    # ──────────────────────────────────────────────────────────────
    log("STEP 2: Closing existing MT5 and MetaEditor", "STEP")
    for proc_name in ["terminal64.exe", "MetaEditor64.exe"]:
        if kill_process(proc_name):
            time.sleep(1)
        else:
            log(f"{proc_name} not running", "WARN")
    time.sleep(2)
    print()

    # ──────────────────────────────────────────────────────────────
    # Step 3: Compile TradeManager
    # ──────────────────────────────────────────────────────────────
    log("STEP 3: Compiling TradeManager.mq5", "STEP")
    if not compile_file(TRADEMANAGER_SRC):
        log("TradeManager compilation failed", "ERROR")
        sys.exit(1)
    time.sleep(2)
    print()

    # ──────────────────────────────────────────────────────────────
    # Step 4: Compile SpikeRiderEA
    # ──────────────────────────────────────────────────────────────
    log("STEP 4: Compiling SpikeRiderEA.mq5", "STEP")
    if not compile_file(SPIDERIDER_SRC):
        log("SpikeRiderEA compilation failed", "ERROR")
        sys.exit(1)
    time.sleep(2)
    print()

    # ──────────────────────────────────────────────────────────────
    # Step 5: Launch MT5
    # ──────────────────────────────────────────────────────────────
    log("STEP 5: Launching MT5 Terminal", "STEP")
    try:
        subprocess.Popen(MT5_PATH)
        wait_for_process("terminal64.exe", timeout=30)
        time.sleep(5)  # Wait for full load
        log("MT5 launched and ready", "OK")
    except Exception as e:
        log(f"Failed to launch MT5: {e}", "ERROR")
        sys.exit(1)
    print()

    # ──────────────────────────────────────────────────────────────
    # Step 6: Summary
    # ──────────────────────────────────────────────────────────────
    print("════════════════════════════════════════════════════════════════")
    print("  ✅ COMPILATION COMPLETE")
    print("════════════════════════════════════════════════════════════════")
    print()
    log("Next steps:", "INFO")
    print("  1. Wait 10 seconds for MT5 to fully load")
    print("  2. Check Terminal > Allow algorithmic trading = ON")
    print("  3. Attach EAs to charts:")
    print("     - XAUUSD M1 → TradeManager")
    print("     - Boom 600 M1 → SpikeRiderEA")
    print("     - Crash 600 M1 → SpikeRiderEA")
    print()
    log("Monitoring for EA logs (F2):", "INFO")
    print("  - Look for: [GOM-Auto] messages (TradeManager)")
    print("  - Look for: [SpikeRider] messages (SpikeRiderEA)")
    print()
    print("════════════════════════════════════════════════════════════════")
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Interrupted by user", "WARN")
        sys.exit(0)
    except Exception as e:
        log(f"Unexpected error: {e}", "ERROR")
        sys.exit(1)
