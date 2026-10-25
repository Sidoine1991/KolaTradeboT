#!/usr/bin/env python3
"""
Lanceur API Boom Rising Channel Predictor
Script pour démarrer l'API spécialisée pour AngelOfSpike
"""

import subprocess
import sys
import time
import threading
import requests
from pathlib import Path

def check_dependencies():
    """Vérifie que toutes les dépendances sont installées"""
    required_packages = [
        'fastapi',
        'uvicorn',
        'pandas',
        'numpy',
        'matplotlib',
        'plotly'
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

def test_api_connection():
    """Teste la connexion à l'API"""
    try:
        response = requests.get("http://localhost:8002/health", timeout=5)
        if response.status_code == 200:
            print("✅ API Boom accessible")
            return True
        else:
            print(f"❌ API Boom non accessible: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur connexion API: {e}")
        return False

def test_angelofspike_endpoint():
    """Teste l'endpoint AngelOfSpike"""
    try:
        response = requests.get("http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Endpoint AngelOfSpike fonctionnel")
            print(f"   Direction: {data.get('direction', 'N/A')}")
            print(f"   Force: {data.get('strength', 0)}")
            print(f"   Confiance: {data.get('confidence', 0)}")
            return True
        else:
            print(f"❌ Endpoint AngelOfSpike non accessible: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur endpoint AngelOfSpike: {e}")
        return False

def start_boom_api():
    """Démarre l'API Boom Rising Channel Predictor"""
    print("🚀 Démarrage de l'API Boom Rising Channel Predictor...")
    
    try:
        # Démarrer l'API en arrière-plan
        process = subprocess.Popen([
            sys.executable, 'boom_api.py'
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Attendre que l'API démarre
        print("⏳ Attente du démarrage de l'API...")
        time.sleep(5)
        
        # Tester la connexion
        if test_api_connection():
            print("✅ API Boom Rising Channel Predictor démarrée avec succès")
            print("🌐 URL: http://localhost:8002")
            print("🤖 Endpoint AngelOfSpike: http://localhost:8002/angelofspike/trend")
            print("📚 Documentation: http://localhost:8002/docs")
            
            # Tester l'endpoint AngelOfSpike
            if test_angelofspike_endpoint():
                print("✅ Intégration AngelOfSpike fonctionnelle")
            else:
                print("⚠️ Problème avec l'endpoint AngelOfSpike")
            
            return process
        else:
            print("❌ Échec du démarrage de l'API")
            process.terminate()
            return None
            
    except Exception as e:
        print(f"❌ Erreur démarrage API: {e}")
        return None

def monitor_api(process):
    """Surveille l'API en cours d'exécution"""
    try:
        while True:
            # Vérifier si le processus est toujours actif
            if process.poll() is not None:
                print("❌ L'API s'est arrêtée de manière inattendue")
                break
            
            # Tester la connexion toutes les 30 secondes
            if test_api_connection():
                print("✅ API Boom opérationnelle")
            else:
                print("⚠️ Problème de connexion API")
            
            time.sleep(30)
            
    except KeyboardInterrupt:
        print("\n⏹️ Arrêt de la surveillance...")
    except Exception as e:
        print(f"❌ Erreur surveillance: {e}")

def main():
    """Fonction principale"""
    print("🚀 Lanceur API Boom Rising Channel Predictor")
    print("=" * 60)
    
    # Vérifier les dépendances
    if not check_dependencies():
        print("❌ Impossible de continuer sans les dépendances")
        return
    
    # Démarrer l'API
    api_process = start_boom_api()
    
    if api_process:
        print("\n📊 L'API est maintenant accessible pour AngelOfSpike")
        print("🔄 Surveillance en cours... (Ctrl+C pour arrêter)")
        
        try:
            # Surveiller l'API
            monitor_api(api_process)
        except KeyboardInterrupt:
            print("\n⏹️ Arrêt demandé par l'utilisateur")
        finally:
            # Arrêter l'API
            print("🛑 Arrêt de l'API...")
            api_process.terminate()
            api_process.wait()
            print("✅ API arrêtée")
    else:
        print("❌ Impossible de démarrer l'API")

if __name__ == "__main__":
    main()
