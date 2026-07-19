#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test integration complète Pullback Entry System
MT5 -> AI Server -> PsychoBot WhatsApp
"""
import sys
import requests
import json
from datetime import datetime
import time

AI_SERVER_URL = "http://localhost:8000"
PSYCHOBOT_URL = "http://localhost:10000"

def test_ai_server_health():
    """Verifie que l'AI Server repond"""
    print("[TEST 1] AI Server Health Check...")
    try:
        response = requests.get(f"{AI_SERVER_URL}/health", timeout=5)
        data = response.json()
        print(f"  [OK] AI Server UP: {data.get('status')}")
        print(f"       Version: {data.get('version')}")
        print(f"       MT5 Available: {data.get('mt5_available')}")
        return True
    except Exception as e:
        print(f"  [FAIL] AI Server FAILED: {e}")
        return False

def test_psychobot_webhook():
    """Verifie que le webhook PsychoBot repond"""
    print("\n[TEST 2] PsychoBot Webhook Health Check...")
    try:
        response = requests.get(f"{PSYCHOBOT_URL}/pullback-webhook/test", timeout=5)
        data = response.json()
        print(f"  [OK] PsychoBot Webhook UP")
        print(f"       Response: {data}")
        return True
    except Exception as e:
        print(f"  [FAIL] PsychoBot Webhook FAILED: {e}")
        return False

def test_pullback_alert_simulation():
    """Simule une alerte Pullback Entry depuis MT5"""
    print("\n[TEST 3] Simulating Pullback Entry Alert...")

    alert_event = {
        "phase": "pullback_start",
        "symbol": "Boom 150 Index",
        "direction": "BUY",
        "breakout_price": 1456.23,
        "pullback_price": 1452.11,
        "entry_price": 1453.45,
        "sl": 1451.95,
        "tp": 1455.20,
        "lot": 0.01,
        "ticket": 12345,
        "risk_usd": 0.48,
        "reward_usd": 0.53,
        "gom_level": "PERFECT BUY",
        "gom_confidence": 0.85,
        "gom_coherence": 75.0,
        "message_preview": "[TARGET] PULLBACK ENTRY INITIATED\n\n[GREEN] Boom 150 Index - BUY\nEntry Level: 1453.45 (after pullback)\n\n[STATS] GOM Context:\nLevel: PERFECT BUY\nConfidence: 85%\nCoherence: 75%\n\n[MONEY] Risk/Reward:\nSL: 1451.95 (Risk: $0.48)\nTP: 1455.20 (Reward: $0.53)"
    }

    print(f"  [SEND] Sending to AI Server (/pullback-alert)...")
    try:
        response = requests.post(
            f"{AI_SERVER_URL}/pullback-alert",
            json=alert_event,
            timeout=10
        )
        data = response.json()
        print(f"         Status: {response.status_code}")
        print(f"         Response: {data}")

        if data.get("success"):
            print(f"  [OK] Alert RECEIVED by AI Server")
            return True
        else:
            print(f"  [WARN] Alert received but processing failed: {data.get('error')}")
            return False

    except Exception as e:
        print(f"  [FAIL] Failed to send alert: {e}")
        return False

def test_webhook_direct():
    """Teste le webhook directement avec un message formate"""
    print("\n[TEST 4] Direct Webhook Test (bypassing AI Server)...")

    payload = {
        "phase": "pullback_start",
        "symbol": "Boom 150 Index",
        "direction": "BUY",
        "gom_level": "PERFECT BUY",
        "gom_confidence": 0.85,
        "gom_coherence": 75.0,
        "message_preview": "[TARGET] PULLBACK ENTRY INITIATED\n\n[GREEN] Boom 150 Index - BUY\n\n[STATS] GOM Context:\nLevel: PERFECT BUY\nConfidence: 85%\nCoherence: 75%\n\n[SUCCESS] Ready to execute on WhatsApp [SUCCESS]"
    }

    print(f"  [SEND] Sending directly to PsychoBot webhook...")
    try:
        response = requests.post(
            f"{PSYCHOBOT_URL}/pullback-webhook",
            json=payload,
            timeout=5
        )
        data = response.json()
        print(f"         Status: {response.status_code}")
        print(f"         Response: {data}")

        if data.get("success"):
            print(f"  [OK] Webhook SUCCESS - Bot connected to WhatsApp!")
            return True
        else:
            error = data.get("error", "Unknown error")
            print(f"  [WARN] Webhook received but bot not connected: {error}")
            print(f"         (This is expected if bot hasn't scanned WhatsApp QR)")
            return False

    except Exception as e:
        print(f"  [FAIL] Webhook request failed: {e}")
        return False

def print_summary(results):
    """Resume des tests"""
    print("\n" + "="*70)
    print("TEST SUMMARY")
    print("="*70)

    tests = [
        ("AI Server Health", results[0]),
        ("PsychoBot Webhook Health", results[1]),
        ("Pullback Alert Simulation", results[2]),
        ("Direct Webhook Test", results[3])
    ]

    for name, success in tests:
        status = "[PASS]" if success else "[FAIL]"
        print(f"  {status}: {name}")

    all_passed = all(results)
    print("\n" + "="*70)
    if all_passed:
        print("[SUCCESS] ALL TESTS PASSED!")
        print("\nNext steps:")
        print("1. Connect PsychoBot to WhatsApp (scan QR code if needed)")
        print("2. Trigger Pullback Entry signals in MT5")
        print("3. Alerts will flow: MT5 -> AI Server -> PsychoBot -> WhatsApp")
    else:
        print("[WARNING] Some tests failed - see details above")
    print("="*70 + "\n")

if __name__ == "__main__":
    print("\n[PULLBACK ENTRY SYSTEM - INTEGRATION TEST]\n")
    print(f"  AI Server: {AI_SERVER_URL}")
    print(f"  PsychoBot: {PSYCHOBOT_URL}")
    print(f"  Timestamp: {datetime.now().isoformat()}\n")

    results = [
        test_ai_server_health(),
        test_psychobot_webhook(),
        test_pullback_alert_simulation(),
        test_webhook_direct()
    ]

    print_summary(results)
