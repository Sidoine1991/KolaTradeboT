#!/usr/bin/env python3
"""
Script simple pour diagnostiquer pourquoi le robot n'exécute pas d'ordres
"""

import os
import sys
import json
import time
import requests
from pathlib import Path

def check_ai_server():
    """Vérifie si le serveur IA fonctionne"""
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        if response.status_code == 200:
            print("✅ Serveur IA actif")
            return True
        else:
            print(f"❌ Serveur IA erreur: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Serveur IA inaccessible: {e}")
        return False

def check_mt5_connection():
    """Vérifie la connexion MT5"""
    try:
        import MetaTrader5 as mt5
        if mt5.initialize():
            print("✅ MT5 connecté")
            account_info = mt5.account_info()
            print(f"   Compte: {account_info.login}")
            print(f"   Broker: {account_info.server}")
            print(f"   Solde: {account_info.balance}")
            mt5.shutdown()
            return True
        else:
            print("❌ MT5 non connecté")
            return False
    except ImportError:
        print("❌ MetaTrader5 non installé")
        return False
    except Exception as e:
        print(f"❌ Erreur MT5: {e}")
        return False

def check_recent_logs():
    """Vérifie les logs récents pour erreurs"""
    log_files = [
        "mt5_ai_client_20260508.log",
        "ai_server.log", 
        "trading_bot.log"
    ]
    
    for log_file in log_files:
        if os.path.exists(log_file):
            print(f"\n📋 {log_file}:")
            try:
                with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()[-10:]  # Dernières 10 lignes
                    for line in lines:
                        if any(keyword in line.lower() for keyword in ['error', 'failed', 'exception', 'order', 'trade']):
                            print(f"   {line.strip()}")
            except Exception as e:
                print(f"   Erreur lecture: {e}")

def test_ai_analysis():
    """Test une analyse IA simple"""
    try:
        test_data = {
            "symbol": "EURUSD",
            "timeframe": "M1",
            "price_data": {
                "current_price": 1.0850,
                "rsi": 65,
                "macd": 0.002,
                "volume": 1000
            },
            "context": "Test ordre"
        }
        
        response = requests.post(
            "http://localhost:8000/analyze/basic",
            json=test_data,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Analyse IA réussie")
            print(f"   Action: {result.get('recommendation', 'N/A')}")
            print(f"   Confiance: {result.get('confidence', 0):.2f}")
            return True
        else:
            print(f"❌ Analyse IA échouée: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Erreur test IA: {e}")
        return False

def check_environment():
    """Vérifie les variables d'environnement"""
    print("\n🔧 Variables d'environnement:")
    
    required_vars = [
        'MT5_LOGIN',
        'MT5_PASSWORD', 
        'MT5_SERVER',
        'SUPABASE_URL',
        'OLLAMA_URL'
    ]
    
    for var in required_vars:
        value = os.getenv(var)
        if value:
            masked = value[:4] + "..." + value[-4:] if len(value) > 8 else "***"
            print(f"   {var}: {'✅ ' + masked}")
        else:
            print(f"   {var}: ❌ manquant")

def main():
    print("🔍 DIAGNOSTIC ROBOT TRADING")
    print("=" * 40)
    
    # Tests de base
    print("\n1. 🌐 Serveur IA:")
    ai_ok = check_ai_server()
    
    print("\n2. 📈 Connexion MT5:")
    mt5_ok = check_mt5_connection()
    
    print("\n3. 🤖 Test Analyse IA:")
    if ai_ok:
        analysis_ok = test_ai_analysis()
    else:
        analysis_ok = False
    
    print("\n4. 📋 Logs récents:")
    check_recent_logs()
    
    print("\n5. 🔧 Configuration:")
    check_environment()
    
    # Résumé
    print(f"\n📊 RÉSUMÉ:")
    print(f"   Serveur IA: {'✅' if ai_ok else '❌'}")
    print(f"   Connexion MT5: {'✅' if mt5_ok else '❌'}")
    print(f"   Analyse IA: {'✅' if analysis_ok else '❌'}")
    
    if ai_ok and mt5_ok and analysis_ok:
        print(f"\n🎉 Tout est OK! Le problème vient probablement du robot MQ5")
        print(f"   → Vérifiez que le robot est bien attaché au graphique")
        print(f"   → Vérifiez que 'AutoTrading' est activé dans MT5")
    else:
        print(f"\n⚠️ Problèmes détectés - Corrigez les erreurs ci-dessus")

if __name__ == "__main__":
    main()
