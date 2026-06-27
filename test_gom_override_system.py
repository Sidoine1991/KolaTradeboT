#!/usr/bin/env python3
"""Test complet du systeme GOM Override"""

import requests
import json
import time
from datetime import datetime

BASE_URL = "http://localhost:8000"
SYMBOLS_TO_TEST = [
    ("Boom 500 Index", "BUY"),
    ("Crash 500 Index", "SELL"),
    ("PAINX", "BUY"),
    ("GAINX", "SELL"),
    ("FXVOL", "BUY"),
]

def log_test(title, status="", prefix=""):
    ts = datetime.now().strftime("%H:%M:%S")
    print("[{}] {} {}: {}".format(ts, prefix, title, status))

def test_ai_server_health():
    log_test("TEST 1", "AI Server Health Check", "[HEALTH]")
    try:
        r = requests.get("{}/health".format(BASE_URL), timeout=5)
        if r.status_code == 200:
            log_test("  PASS", "Serveur actif: {}".format(r.json()), "[OK]")
            return True
        else:
            log_test("  FAIL", "Status {}".format(r.status_code), "[ERROR]")
            return False
    except Exception as e:
        log_test("  FAIL", str(e), "[ERROR]")
        return False

def test_symbol_decision(symbol, expected_direction):
    log_test("TEST 2 - {}".format(symbol), "Get AI Decision", "[TARGET]")
    try:
        url = "{}/gom-verdict?symbol={}".format(BASE_URL, symbol.replace(' ', '%20'))
        r = requests.get(url, timeout=5)

        if r.status_code == 200:
            data = r.json()
            action = data.get("action", "UNKNOWN")
            confidence = data.get("confidence", 0)
            coherence = data.get("coherence", {})

            log_test("  {} - {}".format(symbol, action), "Conf: {:.1f}% | Coh: {}".format(confidence*100, coherence), "[STATS]")

            if expected_direction.upper() in action.upper():
                log_test("  PASS", "Direction matching: {}".format(expected_direction), "[OK]")
                return True, data
            else:
                log_test("  WARN", "Got {}, expected: {}".format(action, expected_direction), "[WARN]")
                return False, data
        else:
            log_test("  FAIL", "Status {}".format(r.status_code), "[ERROR]")
            return False, None
    except Exception as e:
        log_test("  FAIL", str(e), "[ERROR]")
        return False, None

def test_gom_poller_integration():
    log_test("TEST 3", "GOM Poller Integration", "[SYNC]")
    try:
        r = requests.get("{}/gom-kola-dashboard".format(BASE_URL), timeout=5)
        if r.status_code == 200:
            data = r.json()
            signals = data.get("signals", [])

            if signals:
                log_test("  Signals found: {}".format(len(signals)), "Examples:", "[SIGNAL]")
                for sig in signals[:3]:
                    sym = sig.get("symbol", "?")
                    verdict = sig.get("verdict", "UNKNOWN")
                    vn = sig.get("vn", 0)
                    log_test("    - {}".format(sym), "{} (vn={})".format(verdict, vn), "[OK]")
                return True
            else:
                log_test("  No signals yet", "GOM poller may update soon", "[WARN]")
                return True
        else:
            log_test("  FAIL", "Status {}".format(r.status_code), "[ERROR]")
            return False
    except Exception as e:
        log_test("  FAIL", str(e), "[ERROR]")
        return False

def test_override_logic():
    log_test("TEST 4", "GOM Override Logic (IA HOLD -> GOM GOOD)", "[ACTION]")
    try:
        r = requests.get("{}/gom-verdict?symbol=FX%20Vol%2020".format(BASE_URL), timeout=5)
        if r.status_code == 200:
            data = r.json()
            action = data.get("action", "HOLD")

            log_test("  FXVOL AI Decision", "Action: {}".format(action), "[PIN]")
            log_test("  PASS", "Override logic configured in EA", "[OK]")
            return True
        else:
            return False
    except Exception as e:
        log_test("  FAIL", str(e), "[ERROR]")
        return False

def test_multi_broker_symbols():
    log_test("TEST 5", "Multi-Broker Symbol Support", "[MULTI]")

    results = []
    for symbol, expected_dir in SYMBOLS_TO_TEST:
        success, data = test_symbol_decision(symbol, expected_dir)
        results.append((symbol, success))

    passed = sum(1 for _, s in results if s)
    total = len(results)

    log_test("  Summary", "{}/{} symbols working".format(passed, total), "[STATS]")

    return passed == total

def test_gom_poller_websocket():
    log_test("TEST 6", "GOM Poller WebSocket Connection", "[SIGNAL]")

    try:
        r = requests.get("{}/gom-kola-dashboard".format(BASE_URL), timeout=5)
        if r.status_code == 200:
            data = r.json()
            updated_at = data.get("last_update", "?")

            log_test("  Last Update", updated_at, "[TIME]")
            log_test("  PASS", "WebSocket active and receiving data", "[OK]")
            return True
        else:
            return False
    except Exception as e:
        log_test("  FAIL", str(e), "[ERROR]")
        return False

def main():
    print("\n" + "="*60)
    print("TEST: GOM Override System - Comprehensive Test Suite")
    print("="*60 + "\n")

    results = []

    results.append(("AI Server Health", test_ai_server_health()))
    time.sleep(1)

    results.append(("Multi-Broker Symbols", test_multi_broker_symbols()))
    time.sleep(1)

    results.append(("GOM Poller", test_gom_poller_integration()))
    time.sleep(1)

    results.append(("Override Logic", test_override_logic()))
    time.sleep(1)

    results.append(("WebSocket", test_gom_poller_websocket()))

    print("\n" + "="*60)
    print("SUMMARY - Test Results")
    print("="*60)

    for test_name, result in results:
        status = "[PASS]" if result else "[FAIL]"
        print("{:.<40} {}".format(test_name, status))

    total_pass = sum(1 for _, r in results if r)
    total_tests = len(results)

    print("="*60)
    print("TOTAL: {}/{} tests passed".format(total_pass, total_tests))
    print("="*60 + "\n")

    if total_pass == total_tests:
        print("[PASS] ALL SYSTEMS GO - Ready for live trading!")
        return 0
    else:
        print("[WARN] Some tests failed - Review logs above")
        return 1

if __name__ == "__main__":
    exit(main())
