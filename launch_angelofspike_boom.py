#!/usr/bin/env python3
"""
Lanceur AngelOfSpike avec Boom Rising Channel Display
Script pour démarrer le système complet intégré
"""

import subprocess
import sys
import time
import threading
import requests
from pathlib import Path
import json
import os

def check_dependencies():
    """Vérifie que toutes les dépendances sont installées"""
    required_packages = [
        'MetaTrader5',
        'requests',
        'threading'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        print(f"❌ Packages manquants: {', '.join(missing_packages)}")
        print("📦 Installation des packages manquants...")
        
        for package in missing_packages:
            try:
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
                print(f"✅ {package} installé")
            except subprocess.CalledProcessError:
                print(f"❌ Échec de l'installation de {package}")
                return False
    
    return True

def check_api_availability():
    """Vérifie que l'API Boom est accessible"""
    try:
        response = requests.get("http://localhost:8002/health", timeout=5)
        if response.status_code == 200:
            print("✅ API Boom Rising Channel Predictor accessible")
            return True
        else:
            print(f"❌ API non accessible: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur connexion API: {e}")
        return False

def check_mt5_connection():
    """Vérifie la connexion MT5"""
    try:
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            print("❌ MT5 non initialisé")
            return False
        
        if not mt5.terminal_info().connected:
            print("❌ Terminal MT5 non connecté")
            return False
        
        print("✅ MT5 connecté et initialisé")
        return True
        
    except Exception as e:
        print(f"❌ Erreur MT5: {e}")
        return False

def start_boom_api():
    """Démarre l'API Boom Rising Channel Predictor"""
    print("🚀 Démarrage de l'API Boom Rising Channel Predictor...")
    
    try:
        # Vérifier si l'API est déjà en cours d'exécution
        if check_api_availability():
            print("✅ API Boom déjà en cours d'exécution")
            return True
        
        # Démarrer l'API en arrière-plan
        api_process = subprocess.Popen([
            sys.executable, 'boom_api.py'
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Attendre que l'API démarre
        time.sleep(5)
        
        # Vérifier que l'API est accessible
        if check_api_availability():
            print("✅ API Boom démarrée avec succès")
            return True
        else:
            print("❌ Échec du démarrage de l'API Boom")
            return False
            
    except Exception as e:
        print(f"❌ Erreur démarrage API Boom: {e}")
        return False

def test_angelofspike_integration():
    """Teste l'intégration AngelOfSpike avec Boom Display"""
    print("🧪 Test de l'intégration AngelOfSpike avec Boom Display...")
    
    try:
        # Test de l'API Boom
        response = requests.get("http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ API Boom répond correctement")
            print(f"   Direction: {data.get('direction', 'N/A')}")
            print(f"   Confiance: {data.get('confidence', 0)}%")
            print(f"   Signal: {data.get('signal', 'N/A')}")
            return True
        else:
            print(f"❌ Erreur API Boom: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur test intégration: {e}")
        return False

def create_angelofspike_config():
    """Crée un fichier de configuration pour AngelOfSpike"""
    config = {
        "angel_config": {
            "enable_trading": True,
            "magic_number": 880011,
            "allowed_symbols": "Boom 1000 Index, Crash 1000 Index, Boom 500 Index, Crash 500 Index",
            "max_loss_per_trade_usd": 3.50,
            "target_profit_usd": 5.00,
            "max_concurrent_symbols": 1,
            "max_positions_per_symbol": 1
        },
        "detection": {
            "atr_period": 14,
            "spike_atr_mult": 1.0,
            "wick_body_min": 1.0,
            "lookback_bars": 5,
            "aggressive_mode": True,
            "aggressive_spike_relax": 0.6
        },
        "prediction_quality": {
            "min_spike_confidence": 15.0
        },
        "confluence_score": {
            "min_score": 80.0,
            "w_atr": 0.35,
            "w_wick": 0.25,
            "w_sr": 0.15,
            "w_obote": 0.15,
            "w_mtf": 0.10,
            "w_squeeze": 0.10
        },
        "boom_display": {
            "enable": True,
            "api_url": "http://localhost:8002/angelofspike/trend",
            "symbol": "Boom 1000 Index",
            "timeframe": "M1",
            "update_interval": 5,
            "position": {
                "x": 0.75,
                "y": 0.15,
                "width": 0.23,
                "height": 0.25
            },
            "colors": {
                "background": "C'30,30,30'",
                "text": "C'255,255,255'",
                "border_buy": "C'0,255,0'",
                "border_sell": "C'255,0,0'",
                "border_neutral": "C'255,255,0'"
            },
            "font": {
                "name": "Arial",
                "size": 8
            }
        }
    }
    
    config_file = "angelofspike_boom_config.json"
    try:
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Configuration AngelOfSpike créée: {config_file}")
        return True
        
    except Exception as e:
        print(f"❌ Erreur création configuration: {e}")
        return False

def show_usage():
    """Affiche l'utilisation du script"""
    print("""
🚀 Lanceur AngelOfSpike avec Boom Rising Channel Display
=========================================================

Utilisation:
    python launch_angelofspike_boom.py [options]

Options:
    --start-api       Démarrer l'API Boom Rising Channel Predictor
    --test            Tester l'intégration sans démarrer
    --config          Créer le fichier de configuration
    --help            Afficher cette aide

Exemples:
    python launch_angelofspike_boom.py                    # Démarrer le système complet
    python launch_angelofspike_boom.py --start-api        # Démarrer seulement l'API
    python launch_angelofspike_boom.py --test             # Tester seulement
    python launch_angelofspike_boom.py --config           # Créer la config

Prérequis:
    - MetaTrader 5 ouvert et connecté
    - Symbole "Boom 1000 Index" disponible
    - EA AngelOfSpike_WithBoomDisplay.mq5 compilé

Fonctionnalités:
    - Trading automatique AngelOfSpike
    - Affichage dynamique Boom Rising Channel
    - Intégration API temps réel
    - Gestion des risques avancée
    - Interface utilisateur complète
    """)

def main():
    """Fonction principale"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Lanceur AngelOfSpike avec Boom Rising Channel Display')
    parser.add_argument('--start-api', action='store_true', help='Démarrer l\'API Boom Rising Channel Predictor')
    parser.add_argument('--test', action='store_true', help='Tester l\'intégration sans démarrer')
    parser.add_argument('--config', action='store_true', help='Créer le fichier de configuration')
    parser.add_argument('--help', action='help', help='Afficher l\'aide')
    
    args = parser.parse_args()
    
    print("🚀 Lanceur AngelOfSpike avec Boom Rising Channel Display")
    print("=" * 70)
    
    # Créer la configuration si demandé
    if args.config:
        create_angelofspike_config()
        return
    
    # Vérifier les dépendances
    if not check_dependencies():
        print("❌ Impossible de continuer sans les dépendances")
        return
    
    # Vérifier MT5
    if not check_mt5_connection():
        print("❌ MetaTrader 5 n'est pas accessible")
        print("   Ouvrez MT5 et connectez-vous au broker")
        return
    
    # Démarrer l'API si demandé
    if args.start_api:
        if not start_boom_api():
            print("❌ Impossible de démarrer l'API Boom")
            return
        return
    
    # Vérifier l'API
    if not check_api_availability():
        print("❌ L'API Boom Rising Channel Predictor n'est pas accessible")
        print("   Démarrez d'abord l'API: python launch_angelofspike_boom.py --start-api")
        return
    
    # Test seulement
    if args.test:
        print("\n🧪 Test de l'intégration AngelOfSpike avec Boom Display...")
        if test_angelofspike_integration():
            print("✅ Test réussi - L'intégration est prête")
        else:
            print("❌ Test échoué - Vérifiez la configuration")
        return
    
    # Démarrage complet
    print("\n🚀 Démarrage du système complet AngelOfSpike avec Boom Display...")
    
    # Vérifier que l'EA est compilé
    ea_file = "AngelOfSpike_WithBoomDisplay.mq5"
    if not os.path.exists(ea_file):
        print(f"❌ Fichier EA non trouvé: {ea_file}")
        print("   Compilez d'abord l'EA dans MetaEditor")
        return
    
    print("✅ EA AngelOfSpike_WithBoomDisplay.mq5 trouvé")
    print("📊 API Boom Rising Channel Predictor accessible")
    print("🤖 MT5 connecté et prêt")
    
    print("\n🎯 Instructions pour utiliser le système:")
    print("1. Ouvrez MetaTrader 5")
    print("2. Ouvrez le graphique 'Boom 1000 Index'")
    print("3. Attachez l'EA 'AngelOfSpike_WithBoomDisplay'")
    print("4. Configurez les paramètres selon vos besoins")
    print("5. Activez le trading automatique")
    print("6. Le cadran d'analyse Boom apparaîtra en bas à droite")
    
    print("\n📊 Fonctionnalités disponibles:")
    print("✅ Trading automatique AngelOfSpike")
    print("✅ Affichage dynamique Boom Rising Channel")
    print("✅ Prédictions en temps réel")
    print("✅ Gestion des risques avancée")
    print("✅ Interface utilisateur complète")
    
    print("\n🔧 Configuration recommandée:")
    print("- Enable Trading: true")
    print("- Enable Boom Display: true")
    print("- Boom API URL: http://localhost:8002/angelofspike/trend")
    print("- Boom Symbol: Boom 1000 Index")
    print("- Boom Update Interval: 5 secondes")
    
    print("\n⏹️ Le système est prêt! Attachez l'EA au graphique pour commencer.")

if __name__ == "__main__":
    main()
