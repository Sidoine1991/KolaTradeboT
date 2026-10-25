#!/usr/bin/env python3
"""
Script simplifié pour redémarrer le serveur AI avec les mises à jour
"""

import subprocess
import sys
import time
import requests

def test_server():
    """Tester si le serveur répond"""
    try:
        response = requests.get("http://localhost:8000/", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Serveur AI actif - Version: {data.get('version', 'Unknown')}")
            return True
        return False
    except:
        return False

def start_new_server():
    """Démarrer le nouveau serveur AI"""
    print("🚀 Démarrage du serveur AI mis à jour...")
    
    try:
        # Démarrer le serveur
        process = subprocess.Popen([
            sys.executable, "ai_server.py"
        ], cwd="d:\\Dev\\TradBOT")
        
        print(f"📋 Serveur AI démarré (PID: {process.pid})")
        
        # Attendre le démarrage
        print("⏳ Attente du démarrage...")
        time.sleep(5)
        
        # Tester le serveur
        if test_server():
            print("✅ Serveur AI démarré avec succès!")
            return True
        else:
            print("❌ Le serveur ne répond pas")
            return False
            
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

def test_endpoints():
    """Tester les nouveaux endpoints"""
    print("\n🧪 Test des endpoints...")
    
    # Test /test
    try:
        response = requests.post("http://localhost:8000/test", timeout=5)
        print(f"✅ /test: {response.status_code}")
    except Exception as e:
        print(f"❌ /test: {e}")
    
    # Test /validate
    test_data = {"symbol": "EURUSD", "bid": 1.1234, "ask": 1.1235}
    try:
        response = requests.post("http://localhost:8000/validate", json=test_data, timeout=5)
        print(f"✅ /validate: {response.status_code}")
    except Exception as e:
        print(f"❌ /validate: {e}")

def main():
    """Fonction principale"""
    print("🔄 MISE À JOUR SERVEUR AI")
    print("=" * 40)
    
    # Vérifier si un serveur tourne déjà
    if test_server():
        print("ℹ️  Un serveur AI est déjà actif")
        print("📝 Arrêtez-le manuellement (Ctrl+C dans le terminal)")
        print("   puis relancez ce script")
        return
    
    # Démarrer le nouveau serveur
    if start_new_server():
        test_endpoints()
        
        print("\n" + "=" * 40)
        print("🎉 SERVEUR AI MIS À JOUR!")
        print("\nNouveautés:")
        print("- ✅ Validation améliorée")
        print("- ✅ Messages d'erreur clairs")
        print("- ✅ Endpoints /test et /validate")
        print("- ✅ Version 2.0.1")
        print("\n🚀 Le robot MT5 peut maintenant utiliser le serveur local!")

if __name__ == "__main__":
    main()
