#!/usr/bin/env python3
"""
Script de Lancement - Boom Rising Channel Predictor
Lance le système complet de prédiction et trading automatique
"""

import subprocess
import sys
import time
import os
from pathlib import Path
import argparse
import signal
import threading

def check_dependencies():
    """Vérifie que toutes les dépendances sont installées"""
    required_packages = [
        'streamlit',
        'plotly',
        'pandas',
        'numpy',
        'matplotlib',
        'MetaTrader5'
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

def start_streamlit_app():
    """Démarre l'application Streamlit"""
    print("🚀 Démarrage de l'interface Streamlit...")
    
    try:
        # Démarrer Streamlit
        subprocess.Popen([
            sys.executable, '-m', 'streamlit', 'run', 'boom_streamlit_app.py',
            '--server.port', '8501',
            '--server.address', 'localhost',
            '--browser.gatherUsageStats', 'false'
        ])
        
        print("✅ Interface Streamlit démarrée sur http://localhost:8501")
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du démarrage de Streamlit: {e}")
        return False

def start_trading_bot():
    """Démarre le bot de trading"""
    print("🤖 Démarrage du bot de trading...")
    
    try:
        # Importer et démarrer le bot
        from boom_trading_bot import start_boom_trading
        
        # Démarrer dans un thread séparé
        bot_thread = threading.Thread(target=start_boom_trading)
        bot_thread.daemon = True
        bot_thread.start()
        
        print("✅ Bot de trading démarré")
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du démarrage du bot: {e}")
        return False

def create_batch_files():
    """Crée les fichiers batch pour Windows"""
    
    # Fichier batch pour lancer l'interface
    streamlit_bat = """@echo off
echo 🚀 Démarrage de l'Interface Boom Rising Channel Predictor
echo.
python boom_streamlit_app.py
pause
"""
    
    with open('lancer_interface_boom.bat', 'w', encoding='utf-8') as f:
        f.write(streamlit_bat)
    
    # Fichier batch pour lancer le trading
    trading_bat = """@echo off
echo 🤖 Démarrage du Bot de Trading Boom
echo.
python boom_trading_bot.py
pause
"""
    
    with open('lancer_trading_boom.bat', 'w', encoding='utf-8') as f:
        f.write(trading_bat)
    
    # Fichier batch pour lancer tout
    full_bat = """@echo off
echo 🚀 Démarrage du Système Complet Boom Rising Channel Predictor
echo.
echo Vérification des dépendances...
python -c "import streamlit, plotly, pandas, numpy, matplotlib, MetaTrader5; print('✅ Toutes les dépendances sont installées')"
if errorlevel 1 (
    echo ❌ Dépendances manquantes, installation...
    pip install streamlit plotly pandas numpy matplotlib MetaTrader5
)
echo.
echo Démarrage de l'interface...
start /B python boom_streamlit_app.py
timeout /t 3 /nobreak >nul
echo.
echo Démarrage du bot de trading...
start /B python boom_trading_bot.py
echo.
echo ✅ Système démarré!
echo Interface: http://localhost:8501
echo.
pause
"""
    
    with open('lancer_systeme_complet.bat', 'w', encoding='utf-8') as f:
        f.write(full_bat)
    
    print("✅ Fichiers batch créés:")
    print("   - lancer_interface_boom.bat")
    print("   - lancer_trading_boom.bat")
    print("   - lancer_systeme_complet.bat")

def create_requirements_file():
    """Crée le fichier requirements.txt"""
    requirements = """streamlit>=1.28.0
plotly>=5.17.0
pandas>=2.0.0
numpy>=1.24.0
matplotlib>=3.7.0
MetaTrader5>=5.0.0
"""
    
    with open('requirements_boom.txt', 'w') as f:
        f.write(requirements)
    
    print("✅ Fichier requirements_boom.txt créé")

def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(description='Boom Rising Channel Predictor - Lanceur')
    parser.add_argument('--mode', choices=['interface', 'trading', 'full', 'setup'], 
                       default='full', help='Mode de lancement')
    parser.add_argument('--no-deps', action='store_true', 
                       help='Ne pas vérifier les dépendances')
    
    args = parser.parse_args()
    
    print("🚀 Boom Rising Channel Predictor")
    print("=" * 50)
    
    # Vérifier les dépendances
    if not args.no_deps:
        if not check_dependencies():
            print("❌ Impossible de continuer sans les dépendances")
            return
    
    # Mode setup
    if args.mode == 'setup':
        print("🔧 Configuration du système...")
        create_batch_files()
        create_requirements_file()
        print("✅ Configuration terminée!")
        return
    
    # Mode interface uniquement
    if args.mode == 'interface':
        if start_streamlit_app():
            print("\n🌐 Interface disponible sur: http://localhost:8501")
            print("⏹️ Appuyez sur Ctrl+C pour arrêter")
            
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                print("\n⏹️ Arrêt de l'interface...")
    
    # Mode trading uniquement
    elif args.mode == 'trading':
        if start_trading_bot():
            print("\n🤖 Bot de trading actif")
            print("⏹️ Appuyez sur Ctrl+C pour arrêter")
            
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                print("\n⏹️ Arrêt du bot...")
                from boom_trading_bot import stop_boom_trading
                stop_boom_trading()
    
    # Mode complet
    elif args.mode == 'full':
        print("🚀 Démarrage du système complet...")
        
        # Démarrer l'interface
        if not start_streamlit_app():
            print("❌ Impossible de démarrer l'interface")
            return
        
        time.sleep(3)  # Attendre que Streamlit démarre
        
        # Démarrer le bot de trading
        if not start_trading_bot():
            print("❌ Impossible de démarrer le bot de trading")
            return
        
        print("\n✅ Système complet démarré!")
        print("🌐 Interface: http://localhost:8501")
        print("🤖 Bot de trading: Actif")
        print("⏹️ Appuyez sur Ctrl+C pour arrêter")
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n⏹️ Arrêt du système...")
            from boom_trading_bot import stop_boom_trading
            stop_boom_trading()
            print("✅ Système arrêté")

if __name__ == "__main__":
    main()
