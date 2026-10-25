#!/usr/bin/env python3
"""
Lanceur Affichage Dynamique Boom Rising Channel
Script pour démarrer l'affichage en temps réel sur le graphique MT5
"""

import subprocess
import sys
import time
import threading
import requests
from pathlib import Path
import json

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

def test_display_functionality():
    """Teste la fonctionnalité d'affichage"""
    try:
        from boom_display_mt5 import boom_display
        
        # Tester la récupération d'analyse
        analysis = boom_display.get_boom_analysis()
        if analysis:
            print("✅ Récupération d'analyse fonctionnelle")
            print(f"   Direction: {analysis.get('direction', 'N/A')}")
            print(f"   Confiance: {analysis.get('confidence', 0)}%")
            return True
        else:
            print("❌ Impossible de récupérer l'analyse")
            return False
            
    except Exception as e:
        print(f"❌ Erreur test affichage: {e}")
        return False

def start_display():
    """Démarre l'affichage dynamique"""
    print("🚀 Démarrage de l'affichage dynamique Boom...")
    
    try:
        from boom_display_mt5 import start_boom_display
        
        # Démarrer l'affichage
        start_boom_display()
        
        print("✅ Affichage dynamique démarré")
        print("📊 Le cadran d'analyse apparaîtra en bas à droite du graphique MT5")
        print("🔄 Mise à jour automatique toutes les 5 secondes")
        print("⏹️ Appuyez sur Ctrl+C pour arrêter")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur démarrage affichage: {e}")
        return False

def monitor_display():
    """Surveille l'affichage en cours d'exécution"""
    try:
        while True:
            # Vérifier le statut de l'affichage
            from boom_display_mt5 import get_boom_display_status
            
            status = get_boom_display_status()
            
            if status['running']:
                print(f"✅ Affichage actif - Symbole: {status['symbol']} - Dernière mise à jour: {status.get('last_analysis', {}).get('timestamp', 'N/A')}")
            else:
                print("⚠️ Affichage arrêté")
                break
            
            time.sleep(30)  # Vérification toutes les 30 secondes
            
    except KeyboardInterrupt:
        print("\n⏹️ Arrêt de la surveillance...")
    except Exception as e:
        print(f"❌ Erreur surveillance: {e}")

def create_display_config():
    """Crée un fichier de configuration pour l'affichage"""
    config = {
        "api_url": "http://localhost:8002/angelofspike/trend",
        "symbol": "Boom 1000 Index",
        "timeframe": "M1",
        "update_interval": 5,
        "display_position": {
            "x": 0.75,
            "y": 0.15,
            "width": 0.23,
            "height": 0.25
        },
        "colors": {
            "background": "0x1E1E1E",
            "text": "0xFFFFFF",
            "border_buy": "0x00FF00",
            "border_sell": "0xFF0000",
            "border_neutral": "0xFFFF00"
        },
        "font": {
            "name": "Arial",
            "size": 8
        }
    }
    
    config_file = "boom_display_config.json"
    try:
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Configuration d'affichage créée: {config_file}")
        return True
        
    except Exception as e:
        print(f"❌ Erreur création configuration: {e}")
        return False

def show_usage():
    """Affiche l'utilisation du script"""
    print("""
🚀 Lanceur Affichage Dynamique Boom Rising Channel
==================================================

Utilisation:
    python launch_boom_display.py [options]

Options:
    --test          Tester la fonctionnalité sans démarrer
    --config        Créer le fichier de configuration
    --help          Afficher cette aide

Exemples:
    python launch_boom_display.py              # Démarrer l'affichage
    python launch_boom_display.py --test       # Tester seulement
    python launch_boom_display.py --config     # Créer la config

Prérequis:
    - MT5 ouvert et connecté
    - API Boom Rising Channel Predictor démarrée (port 8002)
    - Symbole "Boom 1000 Index" disponible

Fonctionnalités:
    - Affichage en temps réel des prédictions Boom
    - Cadran en bas à droite du graphique MT5
    - Mise à jour automatique toutes les 5 secondes
    - Couleurs dynamiques selon la direction
    - Informations détaillées sur l'analyse
    """)

def main():
    """Fonction principale"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Lanceur Affichage Dynamique Boom Rising Channel')
    parser.add_argument('--test', action='store_true', help='Tester la fonctionnalité sans démarrer')
    parser.add_argument('--config', action='store_true', help='Créer le fichier de configuration')
    parser.add_argument('--help', action='help', help='Afficher l\'aide')
    
    args = parser.parse_args()
    
    print("🚀 Lanceur Affichage Dynamique Boom Rising Channel")
    print("=" * 60)
    
    # Créer la configuration si demandé
    if args.config:
        create_display_config()
        return
    
    # Vérifier les dépendances
    if not check_dependencies():
        print("❌ Impossible de continuer sans les dépendances")
        return
    
    # Vérifier l'API
    if not check_api_availability():
        print("❌ L'API Boom Rising Channel Predictor n'est pas accessible")
        print("   Démarrez d'abord l'API: python boom_api.py")
        return
    
    # Test seulement
    if args.test:
        print("\n🧪 Test de la fonctionnalité d'affichage...")
        if test_display_functionality():
            print("✅ Test réussi - L'affichage est prêt")
        else:
            print("❌ Test échoué - Vérifiez la configuration")
        return
    
    # Démarrer l'affichage
    if start_display():
        try:
            # Surveiller l'affichage
            monitor_display()
        except KeyboardInterrupt:
            print("\n⏹️ Arrêt de l'affichage...")
            from boom_display_mt5 import stop_boom_display
            stop_boom_display()
            print("✅ Affichage arrêté")
    else:
        print("❌ Impossible de démarrer l'affichage")

if __name__ == "__main__":
    main()
