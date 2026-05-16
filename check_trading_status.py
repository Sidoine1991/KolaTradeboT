#!/usr/bin/env python3
"""
Script ultra-simple pour vérifier l'état du trading sans dépendances complexes
"""

import os
import json
from pathlib import Path

def check_basic_files():
    """Vérifie les fichiers de base"""
    print("🔍 Vérification fichiers de base:")
    
    files_to_check = [
        ".env",
        "ai_server.py", 
        "SMC_Universal.mq5",
        "mt5_ai_client.py"
    ]
    
    for file in files_to_check:
        if os.path.exists(file):
            size = os.path.getsize(file)
            print(f"   ✅ {file} ({size} bytes)")
        else:
            print(f"   ❌ {file} manquant")

def check_env_config():
    """Vérifie la configuration .env"""
    print("\n🔧 Configuration .env:")
    
    if not os.path.exists(".env"):
        print("   ❌ Fichier .env manquant")
        return False
    
    with open(".env", "r") as f:
        content = f.read()
    
    required_keys = [
        "MT5_LOGIN",
        "MT5_PASSWORD", 
        "MT5_SERVER",
        "SUPABASE_URL"
    ]
    
    config_ok = True
    for key in required_keys:
        if key in content and "=" in content.split(key)[1].split("\n")[0]:
            print(f"   ✅ {key}")
        else:
            print(f"   ❌ {key} manquant ou vide")
            config_ok = False
    
    return config_ok

def check_recent_activity():
    """Vérifie l'activité récente via les logs"""
    print("\n📋 Activité récente:")
    
    log_patterns = [
        "*.log",
        "*_*.log", 
        "ai_server.log"
    ]
    
    found_logs = False
    for pattern in log_patterns:
        for log_file in Path(".").glob(pattern):
            if log_file.is_file() and log_file.stat().st_size > 0:
                found_logs = True
                size = log_file.stat().st_size
                mtime = log_file.stat().st_mtime
                import time
                age_hours = (time.time() - mtime) / 3600
                print(f"   📄 {log_file.name} ({size} bytes, {age_hours:.1f}h)")
    
    if not found_logs:
        print("   ⚠️ Aucun log trouvé")

def check_mq5_compilation():
    """Vérifie si les fichiers MQ5 sont compilés"""
    print("\n🔧 Fichiers MQ5 compilés:")
    
    mq5_files = [
        "SMC_Universal.ex5",
        "F_INX_Scalper_double.ex5"
    ]
    
    for file in mq5_files:
        if os.path.exists(file):
            size = os.path.getsize(file)
            print(f"   ✅ {file} ({size} bytes)")
        else:
            print(f"   ❌ {file} manquant - besoin de compilation")

def main():
    print("🚀 DIAGNOSTIC RAPIDE TRADING BOT")
    print("=" * 40)
    
    # Tests sans dépendances externes
    check_basic_files()
    env_ok = check_env_config()
    check_recent_activity()
    check_mq5_compilation()
    
    print(f"\n📊 RÉSUMÉ:")
    print(f"   Configuration: {'✅' if env_ok else '❌'}")
    
    if env_ok:
        print(f"\n🎯 Prochaines étapes:")
        print(f"   1. Démarrer le serveur IA: python ai_server.py")
        print(f"   2. Attacher le robot MQ5 au graphique")
        print(f"   3. Activer AutoTrading dans MT5")
    else:
        print(f"\n⚠️ Configurer .env avant de continuer")

if __name__ == "__main__":
    main()
