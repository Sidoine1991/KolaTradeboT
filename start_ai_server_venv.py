#!/usr/bin/env python3
"""
Script de démarrage du serveur IA avec environnement virtuel venv
"""
import sys
import os
import subprocess

# Chemin vers l'environnement virtuel
VENV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "venv")

def main():
    print("🚀 Démarrage du serveur IA avec environnement virtuel...")
    
    # Vérifier si l'environnement virtuel existe
    if not os.path.exists(VENV_PATH):
        print("❌ Environnement virtuel venv non trouvé dans:", VENV_PATH)
        print("💡 Créez-le avec: python -m venv venv")
        print("💡 Puis activez-le: venv\\Scripts\\activate")
        print("💡 Et installez les dépendances: pip install fastapi uvicorn pandas numpy requests joblib")
        return False
    
    # Déterminer le chemin de l'interpréteur Python du venv
    if sys.platform == "win32":
        python_exe = os.path.join(VENV_PATH, "Scripts", "python.exe")
    else:
        python_exe = os.path.join(VENV_PATH, "bin", "python")
    
    if not os.path.exists(python_exe):
        print("❌ Interpréteur Python non trouvé:", python_exe)
        return False
    
    print("✅ Utilisation de l'environnement virtuel:", python_exe)
    
    # Vérifier les dépendances principales
    try:
        result = subprocess.run([python_exe, "-c", "import fastapi, uvicorn, pandas, numpy, requests, joblib; print('✅ Toutes les dépendances sont installées')"], 
                              capture_output=True, text=True)
        if result.returncode != 0:
            print("❌ Dépendances manquantes:")
            print(result.stderr)
            print("💡 Installez-les avec: venv\\Scripts\\activate && pip install fastapi uvicorn pandas numpy requests joblib")
            return False
        print(result.stdout.strip())
    except Exception as e:
        print("❌ Erreur vérification dépendances:", e)
        return False
    
    # Démarrer le serveur IA
    print("🌐 Démarrage du serveur IA sur http://localhost:8000...")
    print("📊 Dashboard disponible sur http://localhost:8000/dashboard")
    print("🔄 Appuyez sur Ctrl+C pour arrêter le serveur")
    print("-" * 50)
    
    try:
        # Lancer ai_server.py avec l'environnement virtuel
        subprocess.run([python_exe, "ai_server.py"], cwd=os.path.dirname(os.path.abspath(__file__)))
    except KeyboardInterrupt:
        print("\n🛑 Serveur IA arrêté")
    except Exception as e:
        print("❌ Erreur démarrage serveur:", e)
        return False
    
    return True

if __name__ == "__main__":
    main()
