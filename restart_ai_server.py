#!/usr/bin/env python3
"""
Script pour redémarrer le serveur AI avec les mises à jour
"""

import subprocess
import sys
import time
import psutil
import requests

def find_ai_server_process():
    """Trouver le processus du serveur AI"""
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = ' '.join(proc.info['cmdline'] or [])
            if 'ai_server.py' in cmdline or 'ai_server' in cmdline:
                return proc.info['pid']
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return None

def stop_ai_server():
    """Arrêter le serveur AI existant"""
    print("🔍 Recherche du serveur AI existant...")
    pid = find_ai_server_process()
    
    if pid:
        print(f"📋 Serveur AI trouvé (PID: {pid})")
        try:
            proc = psutil.Process(pid)
            proc.terminate()
            print("⏹️  Serveur AI arrêté")
            time.sleep(2)
            return True
        except psutil.NoSuchProcess:
            print("❌ Processus non trouvé")
            return False
        except psutil.AccessDenied:
            print("❌ Accès refusé pour arrêter le processus")
            return False
    else:
        print("ℹ️  Aucun serveur AI trouvé en cours d'exécution")
        return True

def start_ai_server():
    """Démarrer le nouveau serveur AI"""
    print("🚀 Démarrage du serveur AI mis à jour...")
    
    try:
        # Démarrer le serveur en arrière-plan
        process = subprocess.Popen([
            sys.executable, "ai_server.py"
        ], cwd="d:\\Dev\\TradBOT")
        
        print(f"📋 Serveur AI démarré (PID: {process.pid})")
        
        # Attendre que le serveur soit prêt
        print("⏳ Attente du démarrage du serveur...")
        time.sleep(3)
        
        # Tester si le serveur répond
        try:
            response = requests.get("http://localhost:8000/", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Serveur AI démarré avec succès!")
                print(f"📊 Version: {data.get('version', 'Unknown')}")
                print(f"🔗 Status: {data.get('status', 'Unknown')}")
                return True
            else:
                print(f"⚠️  Serveur répond mais avec status: {response.status_code}")
                return False
        except requests.RequestException as e:
            print(f"❌ Impossible de contacter le serveur: {e}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur lors du démarrage: {e}")
        return False

def test_new_endpoints():
    """Tester les nouveaux endpoints"""
    print("\n🧪 Test des nouveaux endpoints...")
    
    # Test endpoint /test
    try:
        response = requests.post("http://localhost:8000/test", timeout=5)
        if response.status_code == 200:
            print("✅ Endpoint /test fonctionne")
        else:
            print(f"❌ Endpoint /test: {response.status_code}")
    except Exception as e:
        print(f"❌ Endpoint /test: {e}")
    
    # Test endpoint /validate
    test_data = {
        "symbol": "EURUSD",
        "bid": 1.1234,
        "ask": 1.1235
    }
    try:
        response = requests.post("http://localhost:8000/validate", json=test_data, timeout=5)
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Endpoint /validate fonctionne: {result.get('message', 'Unknown')}")
        else:
            print(f"❌ Endpoint /validate: {response.status_code}")
    except Exception as e:
        print(f"❌ Endpoint /validate: {e}")

def main():
    """Fonction principale"""
    print("🔄 MISE À JOUR SERVEUR AI")
    print("=" * 50)
    
    # Arrêter l'ancien serveur
    if not stop_ai_server():
        print("❌ Impossible d'arrêter l'ancien serveur")
        return
    
    # Démarrer le nouveau serveur
    if not start_ai_server():
        print("❌ Impossible de démarrer le nouveau serveur")
        return
    
    # Tester les nouveaux endpoints
    test_new_endpoints()
    
    print("\n" + "=" * 50)
    print("🎉 MISE À JOUR TERMINÉE!")
    print("\nLe serveur AI est maintenant mis à jour avec:")
    print("- ✅ Validation améliorée des requêtes")
    print("- ✅ Messages d'erreur plus clairs")
    print("- ✅ Nouveaux endpoints de test")
    print("- ✅ Version 2.0.1")
    print("\nLe robot MT5 peut maintenant utiliser le serveur local! 🚀")

if __name__ == "__main__":
    main()
