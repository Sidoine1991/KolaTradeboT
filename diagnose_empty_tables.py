#!/usr/bin/env python3
"""
Script de diagnostic pour vérifier l'état des tables Supabase
et pourquoi model_performance et trade_feedback sont vides.
"""

import os
import sys
import requests
from datetime import datetime
import json

# Configuration Supabase
SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://your-project.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY', 'your-anon-key')

def check_supabase_tables():
    """Vérifie l'état des tables Supabase"""
    print("🔍 DIAGNOSTIC TABLES SUPABASE")
    print("=" * 50)

    # Vérifier la connectivité
    try:
        response = requests.get(f"{SUPABASE_URL}/rest/v1/", headers={
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}'
        })
        print(f"✅ Connectivité Supabase: HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ Erreur connectivité Supabase: {e}")
        return

    # Vérifier les tables
    tables_to_check = ['model_performance', 'trade_feedback', 'predictions']

    for table in tables_to_check:
        try:
            # Compter les enregistrements
            response = requests.get(
                f"{SUPABASE_URL}/rest/v1/{table}?select=id",
                headers={
                    'apikey': SUPABASE_KEY,
                    'Authorization': f'Bearer {SUPABASE_KEY}',
                    'Prefer': 'count=exact'
                }
            )

            if response.status_code == 200:
                total_count = len(response.json()) if response.text else 0
                print(f"📊 Table {table}: {total_count} enregistrements")

                # Derniers enregistrements si disponibles
                if total_count > 0:
                    response_recent = requests.get(
                        f"{SUPABASE_URL}/rest/v1/{table}?select=*&order=created_at.desc&limit=3",
                        headers={
                            'apikey': SUPABASE_KEY,
                            'Authorization': f'Bearer {SUPABASE_KEY}'
                        }
                    )
                    if response_recent.status_code == 200:
                        data = response_recent.json()
                        print(f"   📅 Derniers enregistrements:")
                        for i, record in enumerate(data):
                            created_at = record.get('created_at', 'N/A')
                            print(f"      {i+1}. {created_at}")
                    else:
                        print(f"   ⚠️ Impossible de récupérer les données récentes")
            else:
                print(f"❌ Erreur table {table}: HTTP {response.status_code}")

        except Exception as e:
            print(f"❌ Erreur vérification table {table}: {e}")

def check_server_status():
    """Vérifie si le serveur IA est accessible"""
    print("\n🔍 DIAGNOSTIC SERVEUR IA")
    print("=" * 30)

    urls_to_check = [
        "http://localhost:8000/health",
        "http://localhost:8000/ml/feedback/status",
        "http://localhost:8000/status"
    ]

    for url in urls_to_check:
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                print(f"✅ {url}: HTTP {response.status_code}")
                # Afficher les données si disponibles
                try:
                    data = response.json()
                    if 'total_trades' in data:
                        print(f"   📊 Trades dans feedback: {data['total_trades']}")
                except:
                    pass
            else:
                print(f"⚠️ {url}: HTTP {response.status_code}")
        except Exception as e:
            print(f"❌ {url}: {str(e)}")

def check_robot_logs():
    """Vérifie si le robot MT5 envoie des données"""
    print("\n🔍 DIAGNOSTIC ROBOT MT5")
    print("=" * 25)

    print("🔍 Vérifiez les logs du robot MT5 pour ces messages:")
    print("   - '📤 ENVOI FEEDBACK IA' (envoi des données)")
    print("   - '✅ FEEDBACK IA ENVOYÉ' (succès)")
    print("   - '❌ ÉCHEC ENVOI FEEDBACK IA' (échec)")

    print("\n📋 Actions à vérifier:")
    print("   1. Le serveur IA est-il démarré ?")
    print("   2. Le robot MT5 ferme-t-il des positions ?")
    print("   3. Les URLs du serveur sont-elles correctes ?")
    print("   4. Y a-t-il des erreurs réseau ?")

if __name__ == "__main__":
    print("🚀 DIAGNOSTIC COMPLET - Tables vides dans Supabase")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    check_supabase_tables()
    check_server_status()
    check_robot_logs()

    print("\n" + "=" * 60)
    print("💡 RECOMMANDATIONS:")
    print("1. Démarrer le serveur IA: python ai_server_supabase.py")
    print("2. Vérifier que le robot MT5 ferme des positions")
    print("3. Vérifier les logs du robot MT5 pour 'FEEDBACK IA'")
    print("4. Tester l'endpoint: curl http://localhost:8000/ml/feedback/status")
    print("=" * 60)
