#!/usr/bin/env python3
"""
Script de démarrage simplifié pour le serveur IA
"""
import subprocess
import sys
import os
import time

def main():
    print("🚀 Démarrage du serveur IA TradBOT...")
    
    # Vérifier si on est dans le bon répertoire
    if not os.path.exists("ai_server.py"):
        print("❌ ai_server.py non trouvé. Veuillez exécuter ce script depuis le répertoire d:\Dev\TradBOT")
        return
    
    # Démarrer le serveur
    try:
        print("📡 Lancement du serveur sur le port 8000...")
        process = subprocess.Popen([
            sys.executable, "ai_server.py", "--port", "8000"
        ], cwd=os.getcwd())
        
        print(f"✅ Serveur démarré (PID: {process.pid})")
        print("🌐 Serveur accessible sur: http://127.0.0.1:8000")
        print("📊 Endpoint de décision: http://127.0.0.1:8000/decision")
        print("🔍 Vérification santé: http://127.0.0.1:8000/health")
        print("\n⚠️ Gardez cette fenêtre ouverte pour que le serveur fonctionne")
        print("   Appuyez sur Ctrl+C pour arrêter le serveur")
        
        # Attendre que le processus se termine
        process.wait()
        
    except KeyboardInterrupt:
        print("\n🛑 Arrêt du serveur demandé")
        if 'process' in locals():
            process.terminate()
    except Exception as e:
        print(f"❌ Erreur lors du démarrage: {e}")

if __name__ == "__main__":
    main()
