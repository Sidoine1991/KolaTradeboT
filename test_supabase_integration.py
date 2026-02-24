#!/usr/bin/env python3
"""
Script pour tester l'endpoint /decision ET vérifier
que les écritures Supabase (model_metrics, symbol_calibration,
trade_feedback) fonctionnent réellement.
"""

import os
import time
import json
import requests
from pathlib import Path

# Charger les variables d'environnement comme dans ai_server.py
try:
    from dotenv import load_dotenv
    base_dir = Path(__file__).parent
    env_path = base_dir / ".env"
    supabase_env_path = base_dir / ".env.supabase"
    if env_path.exists():
        load_dotenv(env_path)
    elif supabase_env_path.exists():
        load_dotenv(supabase_env_path)
    else:
        load_dotenv()
except Exception:
    # Pas bloquant pour le test; on continuera avec les variables du système
    pass


def test_decision_endpoint(symbol: str = "EURUSD") -> bool:
    """Tester l'endpoint /decision (génère une prédiction côté serveur)."""
    url = "http://localhost:8000/decision"
    headers = {"Content-Type": "application/json"}

    data = {
        "symbol": symbol,
        "bid": 1.1765,
        "ask": 1.1766,
        "rsi": 50.0,
        "ema_fast_m1": 1.1750,
        "ema_slow_m1": 1.1745,
        "ema_fast_h1": 1.1740,
        "ema_slow_h1": 1.1735,
        "ema_fast_m5": 1.1760,
        "ema_slow_m5": 1.1755,
    }

    try:
        resp = requests.post(url, json=data, headers=headers, timeout=15)
        if resp.status_code == 200:
            result = resp.json()
            print("/decision OK")
            print(f"  Action:     {result.get('action')}")
            print(f"  Confiance:  {result.get('confidence')}")
            print(f"  Raison:     {result.get('reason')}")
            return True
        else:
            print(f"/decision HTTP {resp.status_code}")
            print(resp.text)
            return False
    except Exception as e:
        print(f"Erreur appel /decision: {e}")
        return False


def check_server_health() -> bool:
    """Vérifier que le serveur FastAPI est bien en ligne."""
    print("\nVerification du serveur IA...")
    try:
        resp = requests.get("http://localhost:8000/health", timeout=5)
        if resp.status_code == 200:
            health = resp.json()
            print("Serveur IA accessible")
            print(f"  Status:       {health.get('status', 'N/A')}")
            print(f"  MT5 dispo:    {health.get('mt5_available', 'N/A')}")
            return True
        print(f"/health HTTP {resp.status_code}")
        print(resp.text)
        return False
    except Exception as e:
        print(f"Erreur connexion /health: {e}")
        return False


def check_supabase_model_metrics(symbol: str = "EURUSD", timeframe: str = "M1") -> None:
    """Lire directement la table model_metrics via l'API REST Supabase."""
    print("\nVerification table Supabase: model_metrics")

    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not supabase_key:
        print("SUPABASE_URL / SUPABASE_*_KEY non definis - impossible de tester model_metrics.")
        return

    base = supabase_url.rstrip("/")
    params = {
        "symbol": f"eq.{symbol}",
        "timeframe": f"eq.{timeframe}",
        "order": "training_date.desc",
        "limit": "3",
    }
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
    }

    try:
        resp = requests.get(f"{base}/rest/v1/model_metrics", params=params, headers=headers, timeout=10)
        if resp.status_code != 200:
            print(f"HTTP {resp.status_code} sur model_metrics")
            print(resp.text)
            return

        rows = resp.json()
        print(f"model_metrics renvoie {len(rows)} ligne(s) pour {symbol}/{timeframe}")
        if rows:
            latest = rows[0]
            print("  Dernière métrique:")
            print("   - accuracy      :", latest.get("accuracy"))
            print("   - training_date :", latest.get("training_date"))
            meta = latest.get("metadata")
            if meta:
                print("   - metadata.keys :", list(meta.keys()))
    except Exception as e:
        print(f"Erreur lecture model_metrics: {e}")


def check_supabase_feedback(symbol: str = "EURUSD", timeframe: str = "M1") -> None:
    """Lire un échantillon de trade_feedback pour vérifier l'écriture."""
    print("\nVerification table Supabase: trade_feedback")

    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    if not supabase_url or not supabase_key:
        print("SUPABASE_URL / SUPABASE_*_KEY non definis - impossible de tester trade_feedback.")
        return

    base = supabase_url.rstrip("/")
    params = {
        "symbol": f"eq.{symbol}",
        "timeframe": f"eq.{timeframe}",
        "order": "created_at.desc",
        "limit": "3",
    }
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
    }

    try:
        resp = requests.get(f"{base}/rest/v1/trade_feedback", params=params, headers=headers, timeout=10)
        if resp.status_code != 200:
            print(f"HTTP {resp.status_code} sur trade_feedback")
            print(resp.text)
            return

        rows = resp.json()
        print(f"trade_feedback renvoie {len(rows)} ligne(s) pour {symbol}/{timeframe}")
        if rows:
            latest = rows[0]
            print("  Dernier feedback:")
            print("   - profit    :", latest.get("profit"))
            print("   - is_win    :", latest.get("is_win"))
            print("   - decision  :", latest.get("decision"))
            print("   - created_at:", latest.get("created_at"))
    except Exception as e:
        print(f"Erreur lecture trade_feedback: {e}")


def main():
    print("TEST COMPLET AI_SERVER + SUPABASE (decision + model_metrics + trade_feedback)")
    print("=" * 80)

    symbol = "EURUSD"

    # Étape 1: vérifier que le serveur répond
    if not check_server_health():
        print("\nServeur IA indisponible, arret du test.")
        return

    # Étape 2: générer quelques décisions (ce qui alimente Supabase côté serveur)
    print("\nGeneration de 3 decisions pour alimenter Supabase...")
    ok_any = False
    for i in range(3):
        if test_decision_endpoint(symbol):
            ok_any = True
        time.sleep(1)

    if not ok_any:
        print("\n❌ Aucune décision valide, inutile de tester Supabase.")
        return

    # Laisser le temps au serveur d'écrire dans Supabase
    print("\nPause 3s pour laisser Supabase recevoir les ecritures...")
    time.sleep(3)

    # Étape 3: vérifier les tables Supabase
    check_supabase_model_metrics(symbol)
    check_supabase_feedback(symbol)


if __name__ == "__main__":
    main()
