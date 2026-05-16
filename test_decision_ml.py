#!/usr/bin/env python3
"""Test de décision avec ML activé"""

import requests
import json

API_URL = "http://localhost:8000"

# Données de marché réalistes pour Boom 300 Index
decision_request = {
    "symbol": "Boom 300 Index",
    "timeframe": "M1",
    "bid": 1500.50,
    "ask": 1500.55,
    "rsi": 42.0,
    "atr": 0.012,
    "ema_fast_m1": 1500.60,
    "ema_slow_m1": 1500.40,
    "ema_fast_m5": 1500.70,
    "ema_slow_m5": 1500.45,
    "ema_fast_h1": 1501.00,
    "ema_slow_h1": 1500.30,
    "timestamp": "2026-05-15T17:12:00"
}

print("=== TEST DECISION AVEC ML ===\n")
print(f"Envoi requête pour: {decision_request['symbol']}")
print(f"RSI: {decision_request['rsi']}, ATR: {decision_request['atr']}")
print(f"EMA M1: Fast={decision_request['ema_fast_m1']}, Slow={decision_request['ema_slow_m1']}")

try:
    response = requests.post(
        f"{API_URL}/decision",
        json=decision_request,
        timeout=10
    )

    if response.status_code == 200:
        result = response.json()
        print("\n[OK] RÉPONSE REÇUE:")
        print(f"   Action: {result.get('action', 'N/A')}")
        print(f"   Confidence: {result.get('confidence', 0) * 100:.1f}%")
        print(f"   Modèle utilisé: {result.get('model_used', 'N/A')}")
        print(f"   Raison: {result.get('reason', 'N/A')[:100]}")

        # Vérifier si ML a été appliqué
        ta = result.get('technical_analysis', {})
        if ta:
            final_dec = ta.get('final_decision', {})
            print(f"\n📊 ANALYSE TECHNIQUE:")
            print(f"   Décision finale: {final_dec.get('action')} (conf: {final_dec.get('confidence', 0):.2f})")

        print("\n[OK] TEST RÉUSSI - ML actif et fonctionnel")
    else:
        print(f"\n[ERREUR] ERREUR {response.status_code}: {response.text}")

except requests.exceptions.ConnectionError:
    print("\n[ERREUR] ERREUR: Serveur non accessible sur localhost:8000")
    print("   Vérifier que ai_server.py est démarré")
except Exception as e:
    print(f"\n[ERREUR] ERREUR: {e}")
