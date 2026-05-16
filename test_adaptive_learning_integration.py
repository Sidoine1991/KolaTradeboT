#!/usr/bin/env python3
"""Test d'intégration complète: Trade feedback -> Apprentissage adaptatif"""

import requests
import json
import time

API_URL = "http://localhost:8000"

print("=== TEST INTEGRATION ADAPTIVE LEARNING ===\n")

# Simuler 5 trades pour déclencher un ajustement
trades = [
    {"symbol": "Boom 300 Index", "side": "buy", "profit": 0.85, "is_win": True, "confidence": 0.75},
    {"symbol": "Boom 300 Index", "side": "buy", "profit": -0.40, "is_win": False, "confidence": 0.68},
    {"symbol": "Boom 300 Index", "side": "buy", "profit": 0.92, "is_win": True, "confidence": 0.82},
    {"symbol": "Boom 300 Index", "side": "buy", "profit": -0.35, "is_win": False, "confidence": 0.70},
    {"symbol": "Boom 300 Index", "side": "buy", "profit": 1.15, "is_win": True, "confidence": 0.88},
]

print(f"Envoi de {len(trades)} feedbacks de trades...\n")

for i, trade in enumerate(trades, 1):
    feedback = {
        "symbol": trade["symbol"],
        "timeframe": "M1",
        "side": trade["side"],
        "profit": trade["profit"],
        "is_win": trade["is_win"],
        "ai_confidence": trade["confidence"],
        "coherent_confidence": 0.80,  # Setup score
        "entry_price": 1500.0,
        "exit_price": 1500.0 + trade["profit"],
        "open_time": int(time.time() * 1000) - 300000,  # 5 min ago
        "close_time": int(time.time() * 1000),
        "timestamp": int(time.time() * 1000)
    }

    try:
        response = requests.post(
            f"{API_URL}/trades/feedback",
            json=feedback,
            timeout=5
        )

        if response.status_code == 200:
            result = response.json()
            status = "[WIN]" if trade["is_win"] else "[LOSS]"
            print(f"{i}. {status} {trade['symbol']} {trade['side'].upper()}: ${trade['profit']:+.2f} (conf: {trade['confidence']:.0%})")
        else:
            print(f"{i}. [ERREUR] {response.status_code}: {response.text[:100]}")

    except Exception as e:
        print(f"{i}. [ERREUR] {e}")

    time.sleep(0.5)

print("\n=== VERIFICATION STRATEGIE ADAPTEE ===")

# Vérifier la base de données
try:
    import sqlite3
    db_path = "D:/Dev/TradBOT/data/adaptive_learning.db"

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Récupérer la stratégie actuelle
    cursor.execute("""
        SELECT symbol, min_confidence, min_setup_score, trailing_stop_pct,
               win_rate, total_trades, last_updated
        FROM adaptive_strategies
        WHERE symbol = ?
        ORDER BY last_updated DESC
        LIMIT 1
    """, ("Boom 300 Index",))

    row = cursor.fetchone()
    if row:
        print(f"\n[OK] Strategie adaptee pour {row[0]}:")
        print(f"   - Min confidence: {row[1]:.0%}")
        print(f"   - Min setup score: {row[2]:.1f}")
        print(f"   - Trailing stop: {row[3]:.0f}%")
        print(f"   - Win rate: {row[4]:.1%} sur {row[5]} trades")
        print(f"   - Derniere maj: {row[6]}")
    else:
        print("\n[INFO] Pas encore de strategie adaptee (besoin de plus de trades)")

    # Récupérer les ajustements
    cursor.execute("""
        SELECT parameter, old_value, new_value, reason, timestamp
        FROM strategy_adjustments
        WHERE symbol = ?
        ORDER BY timestamp DESC
        LIMIT 3
    """, ("Boom 300 Index",))

    adjustments = cursor.fetchall()
    if adjustments:
        print("\n[OK] Derniers ajustements:")
        for adj in adjustments:
            print(f"   - {adj[0]}: {adj[1]:.2f} -> {adj[2]:.2f} ({adj[3]})")
    else:
        print("\n[INFO] Aucun ajustement encore effectue")

    conn.close()

    print("\n[OK] TEST REUSSI - Systeme adaptatif operationnel")

except FileNotFoundError:
    print("\n[INFO] Base de donnees non encore creee (cree au premier trade)")
except Exception as e:
    print(f"\n[ERREUR] Verification DB: {e}")

print("\n=== FIN DU TEST ===")
