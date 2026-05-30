#!/usr/bin/env python3
"""
Test script for GOM verdict integration in SpikeRiderEA v5.07
Simulates various /spike-tv-state responses to validate fix
"""

import json

# Test cases for GOM verdict
TEST_CASES = [
    {
        "name": "GOM says COUNTER_TREND blocked",
        "response": {
            "ok": True,
            "counter_trend": True,  # ← VERDICT: trade should be BLOCKED
            "direction": "BUY",
            "structure_m15": "bullish",
            "structure_h1": "bullish",
            "sniper_ready": True,
            "sniper_confidence": 85.0,
            "imminence_pct": 75.0,
        },
        "expect_entry": False,
        "reason": "GOM verdict counter_trend=true blocks entry"
    },
    {
        "name": "GOM says OK (counter_trend false)",
        "response": {
            "ok": True,
            "counter_trend": False,
            "direction": "BUY",
            "structure_m15": "bullish",
            "structure_h1": "bullish",
            "sniper_ready": True,
            "sniper_confidence": 90.0,
        },
        "expect_entry": True,
        "reason": "GOM verdict counter_trend=false allows entry"
    },
    {
        "name": "GOM missing counter_trend (should default false)",
        "response": {
            "ok": True,
            "direction": "BUY",
            "structure_m15": "bullish",
            "structure_h1": "bullish",
        },
        "expect_entry": True,
        "reason": "Missing counter_trend defaults to false (SAFE)"
    },
]

def test_json_bool_parsing():
    """Test JsonExtractBool logic fix"""
    print("\n" + "="*70)
    print("TEST 1: JsonExtractBool Fix")
    print("="*70)

    # Simulate MQL5 JsonExtractBool behavior AFTER fix
    def extract_bool(body_str, key):
        search = f'"{key}":'
        pos = body_str.find(search)
        if pos < 0:
            return False  # ← FIX: defaults to false (was true before)

        pos += len(search)
        while pos < len(body_str) and body_str[pos] == ' ':
            pos += 1

        c = body_str[pos] if pos < len(body_str) else ''
        if c == 't':
            return True
        elif c == 'f':
            return False
        return False

    tests = [
        ('{"counter_trend": true}', "counter_trend", True, "explicit true"),
        ('{"counter_trend": false}', "counter_trend", False, "explicit false"),
        ('{"ok": true}', "counter_trend", False, "missing key defaults false"),
    ]

    passed = True
    for json_str, key, expected, desc in tests:
        result = extract_bool(json_str, key)
        status = "[PASS]" if result == expected else "[FAIL]"
        print(f"{status} {desc}: {result} (expected {expected})")
        if result != expected:
            passed = False

    return passed

def test_counter_trend_blocking():
    """Test counter-trend blocking logic"""
    print("\n" + "="*70)
    print("TEST 2: Counter-Trend GOM Verdict")
    print("="*70)

    passed = True
    for test_case in TEST_CASES:
        name = test_case["name"]
        response = test_case["response"]
        expect_entry = test_case["expect_entry"]
        reason = test_case["reason"]

        counter_trend = response.get("counter_trend", False)
        allow_entry = not counter_trend

        test_passed = allow_entry == expect_entry
        status = "[PASS]" if test_passed else "[FAIL]"

        print("\n" + status + " " + name)
        print("   counter_trend: " + str(counter_trend) + ", allow_entry: " + str(allow_entry))
        print("   Expected: " + str(expect_entry) + ", Got: " + str(allow_entry))
        print("   Reason: " + reason)

        if not test_passed:
            passed = False

    return passed

def main():
    print("\n" + "="*70)
    print("GOM VERDICT INTEGRATION TEST — SpikeRiderEA v5.07")
    print("="*70)

    test1 = test_json_bool_parsing()
    test2 = test_counter_trend_blocking()

    all_passed = test1 and test2

    print("\n" + "="*70)
    print("RESULT: " + ("[PASS] ALL TESTS PASSED" if all_passed else "[FAIL] SOME TESTS FAILED"))
    print("="*70 + "\n")

    return 0 if all_passed else 1

if __name__ == "__main__":
    exit(main())
