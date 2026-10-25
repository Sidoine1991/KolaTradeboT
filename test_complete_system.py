#!/usr/bin/env python3
"""
Test complet du système TradBOT
Vérifie l'API trend et la configuration EA
"""

import requests
import json
import time
import subprocess
import sys
from pathlib import Path

def test_api_trend():
    """Test de l'API Trend"""
    print("🧪 Test de l'API Trend...")
    
    try:
        response = requests.get("http://localhost:8001/trend?symbol=EURUSD&timeframe=M1", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ API Trend: OK")
            print(f"   Symbole: {data.get('symbol')}")
            print(f"   Direction: {data.get('trend_direction')}")
            print(f"   Signal: {data.get('trading_signal')}")
            return True
        else:
            print(f"❌ API Trend: Erreur {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ API Trend: {e}")
        return False

def test_ea_file():
    """Test de l'existence du fichier EA"""
    print("\n🔍 Vérification du fichier EA...")
    
    ea_file = Path("D:/Dev/TradBOT/mt5/SpikeHunter_Simple_EA.mq5")
    if ea_file.exists():
        print("✅ Fichier EA: Trouvé")
        print(f"   Chemin: {ea_file}")
        print(f"   Taille: {ea_file.stat().st_size} bytes")
        return True
    else:
        print("❌ Fichier EA: Non trouvé")
        return False

def test_config_files():
    """Test des fichiers de configuration"""
    print("\n📁 Vérification des fichiers de configuration...")
    
    files_to_check = [
        "trend_api.py",
        "lancer_trend_api.bat",
        "test_trend_api.py",
        "EA_AUTO_TRADING_CONFIG.md"
    ]
    
    all_found = True
    for file_name in files_to_check:
        file_path = Path(file_name)
        if file_path.exists():
            print(f"✅ {file_name}: OK")
        else:
            print(f"❌ {file_name}: Non trouvé")
            all_found = False
    
    return all_found

def start_api_if_needed():
    """Démarre l'API si elle n'est pas en cours d'exécution"""
    print("\n🚀 Vérification de l'API Trend...")
    
    try:
        response = requests.get("http://localhost:8001/health", timeout=2)
        if response.status_code == 200:
            print("✅ API Trend: Déjà en cours d'exécution")
            return True
    except:
        pass
    
    print("⚠️ API Trend: Non démarrée, tentative de démarrage...")
    try:
        # Démarrer l'API en arrière-plan
        subprocess.Popen([sys.executable, "trend_api.py"], 
                        stdout=subprocess.DEVNULL, 
                        stderr=subprocess.DEVNULL)
        
        # Attendre que l'API démarre
        for i in range(10):
            time.sleep(1)
            try:
                response = requests.get("http://localhost:8001/health", timeout=2)
                if response.status_code == 200:
                    print("✅ API Trend: Démarrée avec succès")
                    return True
            except:
                continue
        
        print("❌ API Trend: Impossible de démarrer")
        return False
    except Exception as e:
        print(f"❌ API Trend: Erreur de démarrage - {e}")
        return False

def test_complete_system():
    """Test complet du système"""
    print("🎯 Test Complet du Système TradBOT")
    print("=" * 60)
    
    # Test 1: Fichiers de configuration
    config_ok = test_config_files()
    
    # Test 2: Fichier EA
    ea_ok = test_ea_file()
    
    # Test 3: API Trend
    api_ok = start_api_if_needed()
    if api_ok:
        api_ok = test_api_trend()
    
    # Résumé
    print("\n" + "=" * 60)
    print("📊 RÉSUMÉ DES TESTS")
    print("=" * 60)
    
    if config_ok:
        print("✅ Fichiers de configuration: OK")
    else:
        print("❌ Fichiers de configuration: Problèmes détectés")
    
    if ea_ok:
        print("✅ Fichier EA: OK")
    else:
        print("❌ Fichier EA: Problèmes détectés")
    
    if api_ok:
        print("✅ API Trend: OK")
    else:
        print("❌ API Trend: Problèmes détectés")
    
    # Recommandations
    print("\n🎯 RECOMMANDATIONS")
    print("=" * 60)
    
    if config_ok and ea_ok and api_ok:
        print("🎉 SYSTÈME PRÊT!")
        print("   - L'API Trend est active sur http://localhost:8001")
        print("   - L'EA SpikeHunter est configuré pour le trading automatique")
        print("   - Vous pouvez maintenant démarrer l'EA dans MT5")
        print("\n📋 PROCHAINES ÉTAPES:")
        print("   1. Ouvrir MetaTrader 5")
        print("   2. Charger SpikeHunter_Simple_EA.mq5")
        print("   3. Configurer les paramètres selon EA_AUTO_TRADING_CONFIG.md")
        print("   4. Activer le trading automatique")
        print("   5. Démarrer l'EA")
    else:
        print("⚠️ PROBLÈMES DÉTECTÉS")
        print("   - Vérifiez les erreurs ci-dessus")
        print("   - Assurez-vous que tous les fichiers sont présents")
        print("   - Redémarrez l'API Trend si nécessaire")
    
    print("\n" + "=" * 60)

if __name__ == "__main__":
    test_complete_system()
