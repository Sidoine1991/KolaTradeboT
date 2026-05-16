#!/usr/bin/env python3
"""
Test: Vérifier que Render utilise AWS RDS
"""
import requests
import json
import sys
from datetime import datetime

RENDER_URL = "https://kolatradebot-7ofl.onrender.com"

def test_health():
    """Test 1: Health check"""
    print("=" * 60)
    print("TEST 1: Health Check")
    print("=" * 60)

    try:
        response = requests.get(f"{RENDER_URL}/health", timeout=10)
        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"✅ Service: {data.get('service', 'Unknown')}")
            print(f"✅ Version: {data.get('version', 'Unknown')}")
            print(f"✅ Status: {data.get('status', 'Unknown')}")
            print(f"✅ ML Trainer: {data.get('ml_trainer_available', False)}")
            return True
        else:
            print(f"❌ Status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

def test_decision_endpoint():
    """Test 2: Endpoint /decision pour voir si AWS RDS est utilisé"""
    print("\n" + "=" * 60)
    print("TEST 2: Decision Endpoint (vérifie logs AWS RDS)")
    print("=" * 60)

    payload = {
        "symbol": "EURUSD",
        "bid": 1.0850,
        "ask": 1.0852,
        "atr": 0.0015,
        "rsi": 55.0,
        "ema_fast_m1": 1.0851,
        "ema_slow_m1": 1.0849,
        "ema_fast_m5": 1.0850,
        "ema_slow_m5": 1.0848,
        "ema_fast_h1": 1.0845,
        "ema_slow_h1": 1.0840,
        "dir_rule": 1,
        "timeframe": "M1",
        "volatility_compression": 1.0,
        "price_acceleration": 0.0001,
        "volume_spike": False,
        "spike_probability": 0.0,
        "timestamp": datetime.now().isoformat()
    }

    try:
        response = requests.post(
            f"{RENDER_URL}/decision",
            json=payload,
            timeout=15
        )
        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"✅ Action: {data.get('action', 'Unknown')}")
            print(f"✅ Confidence: {data.get('confidence', 0) * 100:.1f}%")
            print(f"✅ Reason: {data.get('reason', 'N/A')[:80]}...")

            # Note: Les logs AWS RDS sont côté serveur, pas dans la réponse
            print("\n⚠️  Note: Vérifiez les logs Render pour confirmer:")
            print("    - 'AWS RDS PostgreSQL helper chargé'")
            print("    - Aucune mention de Supabase")
            return True
        else:
            print(f"❌ Status {response.status_code}")
            print(f"Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

def test_ml_stats():
    """Test 3: Endpoint /ml_stats"""
    print("\n" + "=" * 60)
    print("TEST 3: ML Stats Endpoint")
    print("=" * 60)

    try:
        response = requests.get(f"{RENDER_URL}/ml_stats", timeout=10)
        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"✅ Total Predictions: {data.get('total_predictions', 0)}")
            print(f"✅ Total Feedback: {data.get('total_feedback', 0)}")
            print(f"✅ Win Rate: {data.get('win_rate', 0):.1f}%")

            models = data.get('models_count', {})
            print(f"✅ Models Count: {models}")
            return True
        else:
            print(f"❌ Status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

def verify_dashboard_files():
    """Test 4: Vérifier fichiers dashboard locaux"""
    print("\n" + "=" * 60)
    print("TEST 4: Fichiers Dashboard Locaux")
    print("=" * 60)

    import os

    files_to_check = [
        "D:\\Dev\\TradBOT\\GOM_Enhanced_Dashboard.mqh",
        "D:\\Dev\\TradBOT\\SMC_Universal.mq5",
        "D:\\Dev\\TradBOT\\sync_ml_stats_to_mt5.py",
        "D:\\Dev\\TradBOT\\start_ml_sync.bat"
    ]

    all_exist = True
    for filepath in files_to_check:
        exists = os.path.exists(filepath)
        symbol = "✅" if exists else "❌"
        size = os.path.getsize(filepath) if exists else 0
        print(f"{symbol} {os.path.basename(filepath)}: {size:,} bytes")
        if not exists:
            all_exist = False

    return all_exist

def main():
    print("\n" + "=" * 60)
    print("🧪 TESTS RENDER + AWS RDS + DASHBOARD ML")
    print("=" * 60)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"URL: {RENDER_URL}")
    print()

    results = []

    # Test 1: Health
    results.append(("Health Check", test_health()))

    # Test 2: Decision (vérifie AWS RDS côté serveur)
    results.append(("Decision Endpoint", test_decision_endpoint()))

    # Test 3: ML Stats
    results.append(("ML Stats", test_ml_stats()))

    # Test 4: Fichiers locaux
    results.append(("Fichiers Dashboard", verify_dashboard_files()))

    # Résumé
    print("\n" + "=" * 60)
    print("📊 RÉSUMÉ DES TESTS")
    print("=" * 60)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for name, result in results:
        symbol = "✅" if result else "❌"
        print(f"{symbol} {name}")

    print()
    print(f"Résultat: {passed}/{total} tests réussis")

    if passed == total:
        print("\n🎉 TOUS LES TESTS SONT PASSÉS !")
        print("\n📋 Prochaines étapes:")
        print("1. Vérifiez les logs Render pour confirmer AWS RDS:")
        print("   https://dashboard.render.com/web/srv-cvs93ddumphs739q5hd0/logs")
        print("2. Lancez: python sync_ml_stats_to_mt5.py")
        print("3. Attachez SMC_Universal dans MT5")
        print("4. Vérifiez le dashboard affiche les stats ML")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test(s) échoué(s)")
        return 1

if __name__ == "__main__":
    sys.exit(main())
