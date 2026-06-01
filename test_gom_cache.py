#!/usr/bin/env python3
"""
Test du cache GOM KOLA - Vérifie que le cache fonctionne correctement
"""
import requests
import time

AI_SERVER = "http://localhost:8000"

def test_gom_cache():
    print("=== Test du cache GOM KOLA ===\n")

    # Test 1: Premier appel (cache miss)
    print("[TEST 1] Premier appel - devrait appeler le bridge")
    start = time.time()
    resp1 = requests.get(f"{AI_SERVER}/gom-kola-dashboard?symbol=XAUUSD", timeout=5)
    duration1 = time.time() - start
    print(f"  Status: {resp1.status_code}")
    print(f"  Duration: {duration1*1000:.0f}ms")
    if resp1.status_code == 200:
        data1 = resp1.json()
        print(f"  Verdict: {data1.get('verdict', 'N/A')}")
        print(f"  Price: {data1.get('price', 'N/A')}")
    print()

    # Test 2: Deuxième appel immédiat (cache hit)
    print("[TEST 2] Deuxième appel immédiat - devrait utiliser le cache")
    start = time.time()
    resp2 = requests.get(f"{AI_SERVER}/gom-kola-dashboard?symbol=XAUUSD", timeout=5)
    duration2 = time.time() - start
    print(f"  Status: {resp2.status_code}")
    print(f"  Duration: {duration2*1000:.0f}ms")
    if resp2.status_code == 200:
        data2 = resp2.json()
        print(f"  Verdict: {data2.get('verdict', 'N/A')}")
        print(f"  Price: {data2.get('price', 'N/A')}")
    print()

    # Vérifier que le 2e appel est beaucoup plus rapide
    if duration2 < duration1 * 0.5:
        print(f"✅ Cache fonctionne: {duration2*1000:.0f}ms < {duration1*1000:.0f}ms")
    else:
        print(f"⚠️ Cache possiblement inefficace: {duration2*1000:.0f}ms vs {duration1*1000:.0f}ms")
    print()

    # Test 3: Attendre expiration du cache (11s)
    print("[TEST 3] Attente expiration cache (11s)...")
    time.sleep(11)

    start = time.time()
    resp3 = requests.get(f"{AI_SERVER}/gom-kola-dashboard?symbol=XAUUSD", timeout=5)
    duration3 = time.time() - start
    print(f"  Status: {resp3.status_code}")
    print(f"  Duration: {duration3*1000:.0f}ms")
    if resp3.status_code == 200:
        data3 = resp3.json()
        print(f"  Verdict: {data3.get('verdict', 'N/A')}")
        print(f"  Price: {data3.get('price', 'N/A')}")
    print()

    if duration3 > duration2:
        print(f"✅ Expiration fonctionne: refresh après TTL")
    print()

    # Test 4: Appels successifs rapides (simule le master_gom_poller)
    print("[TEST 4] 5 appels successifs rapides (simule poller)")
    durations = []
    for i in range(5):
        start = time.time()
        resp = requests.get(f"{AI_SERVER}/gom-kola-dashboard?symbol=XAUUSD", timeout=5)
        duration = time.time() - start
        durations.append(duration)
        print(f"  Appel {i+1}: {duration*1000:.0f}ms - Status {resp.status_code}")
        time.sleep(0.5)

    avg_duration = sum(durations) / len(durations)
    print(f"\n  Durée moyenne: {avg_duration*1000:.0f}ms")
    if all(d < 1.0 for d in durations):
        print(f"✅ Tous les appels < 1s (pas de timeout)")
    else:
        print(f"⚠️ Certains appels > 1s")

    print("\n=== Test terminé ===")

if __name__ == "__main__":
    try:
        test_gom_cache()
    except requests.exceptions.ConnectionError:
        print("❌ AI server non accessible. Démarrer ai_server.py d'abord.")
    except Exception as e:
        print(f"❌ Erreur: {e}")
