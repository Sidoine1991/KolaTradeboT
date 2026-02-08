#!/usr/bin/env python3
"""
Script de compilation automatique du robot GoldRush_basic.mq5
avec vérification des erreurs et application des corrections
"""

import os
import subprocess
import sys
import time

def find_metaeditor_path():
    """Chercher le chemin de MetaEditor"""
    possible_paths = [
        r"C:\Program Files\MetaTrader 5\metaeditor64.exe",
        r"C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe",
        r"C:\Program Files\MetaTrader 5\metaeditor.exe",
        r"C:\Program Files (x86)\MetaTrader 5\metaeditor.exe"
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    return None

def compile_robot():
    """Compiler le robot GoldRush_basic.mq5"""
    
    print("🔧 COMPILATION AUTOMATIQUE DU ROBOT")
    print("=" * 50)
    
    # Chemin du fichier MQ5
    mq5_file = r"d:\Dev\TradBOT\GoldRush_basic.mq5"
    
    if not os.path.exists(mq5_file):
        print(f"❌ Fichier introuvable: {mq5_file}")
        return False
    
    # Chercher MetaEditor
    metaeditor_path = find_metaeditor_path()
    if not metaeditor_path:
        print("❌ MetaEditor non trouvé. Installation MT5 requise.")
        return False
    
    print(f"✅ MetaEditor trouvé: {metaeditor_path}")
    print(f"📄 Fichier à compiler: {mq5_file}")
    print()
    
    # Commande de compilation
    cmd = [
        metaeditor_path,
        "/compile",
        mq5_file,
        "/close"
    ]
    
    print("🚀 Lancement de la compilation...")
    print("Commande:", " ".join(cmd))
    print()
    
    try:
        # Exécuter la compilation
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        print("📋 RÉSULTAT DE LA COMPILATION:")
        print("-" * 30)
        
        if result.stdout:
            print("SORTIE:")
            print(result.stdout)
        
        if result.stderr:
            print("ERREURS:")
            print(result.stderr)
        
        print(f"Code de retour: {result.returncode}")
        
        if result.returncode == 0:
            print("✅ COMPILATION RÉUSSIE!")
            print("🎯 Le robot est maintenant prêt à être utilisé")
        else:
            print("❌ ERREUR DE COMPILATION")
            print("🔍 Vérifiez les erreurs ci-dessus")
            
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("❌ TIMEOUT: La compilation a pris trop de temps")
        return False
    except Exception as e:
        print(f"❌ ERREUR: {e}")
        return False

def main():
    """Fonction principale"""
    print("🤖 GOLDRUSH ROBOT - COMPILATION AUTOMATIQUE")
    print("=" * 50)
    print()
    
    success = compile_robot()
    
    print()
    print("=" * 50)
    if success:
        print("🎉 SUCCÈS: Robot compilé avec les corrections!")
        print()
        print("📋 PROCHAINES ÉTAPES:")
        print("1. Attachez le robot aux graphiques MT5")
        print("2. Vérifiez que les erreurs SL ont disparu")
        print("3. Le robot devrait trader correctement")
    else:
        print("❌ ÉCHEC: Vérifiez les erreurs de compilation")
        print()
        print("🔧 SOLUTIONS POSSIBLES:")
        print("1. Vérifiez que MetaEditor est fermé")
        print("2. Vérifiez les permissions du fichier")
        print("3. Compilez manuellement avec F7 dans MetaEditor")
    
    print()
    input("Appuyez sur Entrée pour quitter...")

if __name__ == "__main__":
    main()
