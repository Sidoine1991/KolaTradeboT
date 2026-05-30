#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Advanced Audio Processing Test Suite
- Simulation d'audio réel avec transcription
- Réponses contextuelles détaillées
- Intégration avec données de trading
"""

import json
import requests
from datetime import datetime
from pathlib import Path

PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com"
PHONE = "+2290196911346"

def simulate_audio_message(session, msg_text, context_type, details=""):
    """Simuler un message audio avec contexte"""
    try:
        payload = {
            "phone": PHONE,
            "message": msg_text,
            "is_audio": True,
            "context_type": context_type,
            "timestamp": datetime.now().isoformat()
        }
        if details:
            payload.update(details)

        resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=15)
        return resp.status_code in [200, 201], resp
    except Exception as e:
        return False, str(e)

def test_trading_analysis_context():
    """Test 1: Contexte analyse trading"""
    print("\n[TEST 1] Trading Analysis Context\n")

    session = requests.Session()
    session.verify = False

    scenarios = [
        {
            "msg": "Audio: Quel est le verdict GOM pour XAUUSD?",
            "context": "trading_analysis",
            "details": {
                "intent": "get_verdict",
                "symbol": "XAUUSD",
                "timeframe": "M15",
                "expected_response": "gom_verdict"
            }
        },
        {
            "msg": "Audio: Donne-moi une analyse complete XAUUSD avec les niveaux",
            "context": "trading_analysis",
            "details": {
                "intent": "full_analysis",
                "symbol": "XAUUSD",
                "include_levels": True,
                "expected_response": "detailed_analysis"
            }
        },
        {
            "msg": "Audio: Quels sont les signaux BUY actuels?",
            "context": "trading_analysis",
            "details": {
                "intent": "buy_signals",
                "filter_direction": "BUY",
                "expected_response": "signal_list"
            }
        }
    ]

    passed = 0
    for scenario in scenarios:
        success, resp = simulate_audio_message(
            session,
            scenario["msg"],
            scenario["context"],
            scenario["details"]
        )

        if success:
            print(f"  [OK] {scenario['details']['intent']}")
            passed += 1
        else:
            print(f"  [FAIL] {scenario['details']['intent']}")

    print(f"\nResult: {passed}/{len(scenarios)} scenarios OK\n")
    return passed == len(scenarios)

def test_educational_context():
    """Test 2: Contexte educational"""
    print("\n[TEST 2] Educational Context\n")

    session = requests.Session()
    session.verify = False

    scenarios = [
        {
            "msg": "Audio: Comment fonctionne le GOM KOLA?",
            "context": "education",
            "details": {
                "topic": "gom_kola",
                "level": "beginner",
                "expected_response": "explanation"
            }
        },
        {
            "msg": "Audio: Explique la difference entre VWAP et Supertrend",
            "context": "education",
            "details": {
                "topic": "indicators_comparison",
                "indicators": ["VWAP", "Supertrend"],
                "expected_response": "comparison"
            }
        },
        {
            "msg": "Audio: Qu'est-ce qu'une divergence?",
            "context": "education",
            "details": {
                "topic": "divergence",
                "level": "intermediate",
                "expected_response": "concept_explanation"
            }
        }
    ]

    passed = 0
    for scenario in scenarios:
        success, resp = simulate_audio_message(
            session,
            scenario["msg"],
            scenario["context"],
            scenario["details"]
        )

        if success:
            print(f"  [OK] {scenario['details']['topic']}")
            passed += 1
        else:
            print(f"  [FAIL] {scenario['details']['topic']}")

    print(f"\nResult: {passed}/{len(scenarios)} scenarios OK\n")
    return passed == len(scenarios)

def test_status_context():
    """Test 3: Contexte status systeme"""
    print("\n[TEST 3] System Status Context\n")

    session = requests.Session()
    session.verify = False

    scenarios = [
        {
            "msg": "Audio: Status du systeme?",
            "context": "status",
            "details": {
                "query_type": "system_status",
                "expected_response": "status_report"
            }
        },
        {
            "msg": "Audio: Y a-t-il des ordres actifs?",
            "context": "status",
            "details": {
                "query_type": "active_orders",
                "expected_response": "order_list"
            }
        },
        {
            "msg": "Audio: Quelle est la derniere alerte recue?",
            "context": "status",
            "details": {
                "query_type": "last_alert",
                "expected_response": "alert_info"
            }
        }
    ]

    passed = 0
    for scenario in scenarios:
        success, resp = simulate_audio_message(
            session,
            scenario["msg"],
            scenario["context"],
            scenario["details"]
        )

        if success:
            print(f"  [OK] {scenario['details']['query_type']}")
            passed += 1
        else:
            print(f"  [FAIL] {scenario['details']['query_type']}")

    print(f"\nResult: {passed}/{len(scenarios)} scenarios OK\n")
    return passed == len(scenarios)

def test_audio_quality_impact():
    """Test 4: Impact de la qualite audio sur les reponses"""
    print("\n[TEST 4] Audio Quality Impact on Response\n")

    session = requests.Session()
    session.verify = False

    quality_levels = [
        {
            "level": "excellent",
            "confidence": 0.98,
            "noise": 0.05,
            "expected": "normal_processing"
        },
        {
            "level": "good",
            "confidence": 0.90,
            "noise": 0.15,
            "expected": "normal_processing"
        },
        {
            "level": "fair",
            "confidence": 0.75,
            "noise": 0.35,
            "expected": "enhanced_processing"
        },
        {
            "level": "poor",
            "confidence": 0.55,
            "noise": 0.65,
            "expected": "retry_or_clarify"
        }
    ]

    passed = 0
    for quality in quality_levels:
        payload = {
            "phone": PHONE,
            "message": f"Audio: Test with {quality['level']} quality",
            "is_audio": True,
            "audio_quality": {
                "level": quality["level"],
                "confidence": quality["confidence"],
                "noise_level": quality["noise"],
                "expected_processing": quality["expected"]
            },
            "timestamp": datetime.now().isoformat()
        }

        try:
            resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=15)
            if resp.status_code in [200, 201]:
                print(f"  [OK] Quality '{quality['level']}' (conf={quality['confidence']})")
                passed += 1
            else:
                print(f"  [FAIL] Quality '{quality['level']}'")
        except:
            print(f"  [ERROR] Quality '{quality['level']}'")

    print(f"\nResult: {passed}/{len(quality_levels)} quality levels processed\n")
    return passed >= len(quality_levels) * 0.75

def test_context_switching():
    """Test 5: Changement de contexte dans une conversation"""
    print("\n[TEST 5] Context Switching in Conversation\n")

    session = requests.Session()
    session.verify = False

    conversation = [
        {
            "msg": "Audio: Quel est le verdict GOM?",
            "context": "trading_analysis",
            "step": "1_initial_query"
        },
        {
            "msg": "Audio: Comment interprete-t-on ce verdict?",
            "context": "education",
            "step": "2_clarification"
        },
        {
            "msg": "Audio: Y a-t-il un ordre actif pour ca?",
            "context": "status",
            "step": "3_status_check"
        },
        {
            "msg": "Audio: Envoie moi une alerte si ca change",
            "context": "trading_analysis",
            "step": "4_action_request"
        }
    ]

    passed = 0
    for msg_obj in conversation:
        payload = {
            "phone": PHONE,
            "message": msg_obj["msg"],
            "is_audio": True,
            "context_type": msg_obj["context"],
            "conversation_step": msg_obj["step"],
            "timestamp": datetime.now().isoformat()
        }

        try:
            resp = session.post(f"{PSYCHOBOT_URL}/send-message", json=payload, timeout=15)
            if resp.status_code in [200, 201]:
                print(f"  [OK] {msg_obj['step']}: {msg_obj['context']}")
                passed += 1
            else:
                print(f"  [FAIL] {msg_obj['step']}")
        except:
            print(f"  [ERROR] {msg_obj['step']}")

    print(f"\nResult: {passed}/{len(conversation)} context switches OK\n")
    return passed == len(conversation)

def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("ADVANCED AUDIO PROCESSING TEST SUITE")
    print("="*60)

    results = {
        "Trading Analysis": test_trading_analysis_context(),
        "Educational": test_educational_context(),
        "Status": test_status_context(),
        "Quality Impact": test_audio_quality_impact(),
        "Context Switching": test_context_switching()
    }

    # Summary
    print("\n" + "="*60)
    print("FINAL RESULTS")
    print("="*60)

    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for test_name, passed_test in results.items():
        status = "[PASS]" if passed_test else "[FAIL]"
        print(f"{status} {test_name}")

    print(f"\nOverall: {passed}/{total} test groups passed ({int(100*passed/total)}%)\n")

    # Save results
    log_data = {
        "timestamp": datetime.now().isoformat(),
        "test_suite": "advanced_audio_processing",
        "results": results,
        "summary": f"{passed}/{total} groups"
    }

    try:
        with open("D:\\Dev\\TradBOT\\audio_advanced_results.json", "w") as f:
            json.dump(log_data, f, indent=2)
        print("Results saved to audio_advanced_results.json")
    except:
        pass

    return passed == total

if __name__ == "__main__":
    import sys
    success = main()
    sys.exit(0 if success else 1)
