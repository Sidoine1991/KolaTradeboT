#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test Audio Processing & Context-Aware Responses (SIMPLE VERSION)
"""

import json
import requests
import sys
from datetime import datetime
from pathlib import Path

PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com"
PHONE = "+2290196911346"

def test_audio_processing():
    """Test du traitement audio et reponses contextuelles"""

    session = requests.Session()
    session.verify = False

    results = []

    print("\n[TEST SUITE] Audio Processing & Context-Aware Responses\n")

    # TEST 1: Send text message (baseline)
    print("[TEST 1] Text Message (Baseline)")
    try:
        payload = {
            "phone": PHONE,
            "message": "Test: Quel est le verdict GOM pour XAUUSD?"
        }
        resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=10)
        if resp.status_code in [200, 201]:
            print("[OK] Text message sent\n")
            results.append(("Text Message", True))
        else:
            print(f"[FAIL] Status {resp.status_code}\n")
            results.append(("Text Message", False))
    except Exception as e:
        print(f"[ERROR] {str(e)[:50]}\n")
        results.append(("Text Message", False))

    # TEST 2: Audio with context
    print("[TEST 2] Audio Message with Trading Context")
    try:
        payload = {
            "phone": PHONE,
            "message": "Audio: Analyse XAUUSD maintenant",
            "is_audio": True,
            "context": {
                "type": "trading_analysis",
                "symbols": ["XAUUSD"],
                "timeframes": ["M15", "H1"]
            }
        }
        resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=15)
        if resp.status_code in [200, 201]:
            print("[OK] Audio message with context sent\n")
            results.append(("Audio Context", True))
        else:
            print(f"[FAIL] Status {resp.status_code}\n")
            results.append(("Audio Context", False))
    except Exception as e:
        print(f"[ERROR] {str(e)[:50]}\n")
        results.append(("Audio Context", False))

    # TEST 3: Different audio contexts
    print("[TEST 3] Multi-Context Audio Processing")
    contexts = [
        {"intent": "trading", "msg": "Audio: Verdict trading pour XAUUSD"},
        {"intent": "education", "msg": "Audio: Explique le GOM KOLA"},
        {"intent": "status", "msg": "Audio: Status du systeme"},
    ]

    passed = 0
    for ctx in contexts:
        try:
            payload = {
                "phone": PHONE,
                "message": ctx["msg"],
                "is_audio": True,
                "intent": ctx["intent"]
            }
            resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=15)
            if resp.status_code in [200, 201]:
                passed += 1
                print(f"  [{ctx['intent']}] OK")
            else:
                print(f"  [{ctx['intent']}] FAIL")
        except:
            print(f"  [{ctx['intent']}] ERROR")

    print(f"[{passed}/{len(contexts)}] contexts processed\n")
    results.append(("Multi-Context", passed == len(contexts)))

    # TEST 4: Audio quality scenarios
    print("[TEST 4] Audio Quality Detection")
    qualities = [
        {"level": "good", "confidence": 0.95},
        {"level": "poor", "confidence": 0.45},
        {"level": "excellent", "confidence": 0.99},
    ]

    passed = 0
    for q in qualities:
        try:
            payload = {
                "phone": PHONE,
                "message": f"Audio quality test: {q['level']}",
                "audio_quality": q['level'],
                "confidence": q['confidence']
            }
            resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=10)
            if resp.status_code in [200, 201]:
                passed += 1
                print(f"  [{q['level']}] OK")
            else:
                print(f"  [{q['level']}] FAIL")
        except:
            print(f"  [{q['level']}] ERROR")

    print(f"[{passed}/{len(qualities)}] quality levels processed\n")
    results.append(("Quality Detection", passed == len(qualities)))

    # TEST 5: Audio + Trading Data
    print("[TEST 5] Audio + Trading Data Integration")
    try:
        payload = {
            "phone": PHONE,
            "message": "Audio: Donne moi analyse complete XAUUSD",
            "is_audio": True,
            "request_trading_data": True,
            "include_gom": True,
            "symbols": ["XAUUSD"]
        }
        resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=20)
        if resp.status_code in [200, 201]:
            print("[OK] Audio + Trading data sent\n")
            results.append(("Audio+Trading", True))
        else:
            print(f"[FAIL] Status {resp.status_code}\n")
            results.append(("Audio+Trading", False))
    except Exception as e:
        print(f"[ERROR] {str(e)[:50]}\n")
        results.append(("Audio+Trading", False))

    # SUMMARY
    print("="*50)
    print("[SUMMARY]")
    passed_total = sum(1 for _, p in results if p)
    total = len(results)
    print(f"Tests: {passed_total}/{total} passed ({int(100*passed_total/total)}%)\n")

    for test_name, passed in results:
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {test_name}")

    # Save results
    log_data = {
        "timestamp": datetime.now().isoformat(),
        "results": [{"test": name, "passed": p} for name, p in results],
        "summary": f"{passed_total}/{total}"
    }

    try:
        with open("D:\\Dev\\TradBOT\\audio_test_results.json", "w") as f:
            json.dump(log_data, f, indent=2)
        print(f"\nResults saved to audio_test_results.json")
    except:
        pass

    return passed_total == total

if __name__ == "__main__":
    success = test_audio_processing()
    sys.exit(0 if success else 1)
