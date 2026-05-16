#!/usr/bin/env python3
"""Test du chargement des modèles ML après corrections"""

import os
os.environ["MODELS_DIR"] = "models"

print("=== TEST CHARGEMENT MODELES ML ===\n")

# Test 1: Vérifier integrated_ml_trainer
print("1. Import integrated_ml_trainer...")
try:
    from integrated_ml_trainer import ml_trainer
    print(f"   [OK] Module chargé")
except Exception as e:
    print(f"   [ERREUR] {e}")
    exit(1)

# Test 2: Vérifier que ml_trainer a bien chargé les modèles
print(f"\n2. Modèles chargés: {len(ml_trainer.models)}")
if ml_trainer.models:
    print("   Exemples:")
    for key in list(ml_trainer.models.keys())[:5]:
        model_info = ml_trainer.models[key]
        print(f"   - {key}: {model_info['symbol']} ({model_info['timeframe']}) - {model_info['model_type']}")
else:
    print("   [ATTENTION] Aucun modèle chargé!")

# Test 3: Test de prédiction
print("\n3. Test de prédiction...")
test_symbols = [
    ("Boom 300 Index", "M1"),
    ("Boom 600 Index", "M5"),
    ("Crash 300 Index", "M1")
]

for symbol, tf in test_symbols:
    market_data = {
        "rsi": 45.0,
        "atr": 0.001,
        "bid": 100.0,
        "ask": 100.05,
        "confidence": 0.7,
        "ema_fast_m1": 100.2,
        "ema_slow_m1": 100.0
    }
    result = ml_trainer.predict(symbol, tf, market_data)
    if result:
        print(f"   [OK] {symbol} {tf}: {result['action']} (conf: {result['confidence']:.2%})")
    else:
        print(f"   [SKIP] {symbol} {tf}: Pas de modèle")

print("\n=== TEST TERMINÉ ===")
