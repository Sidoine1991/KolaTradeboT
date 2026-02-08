#!/usr/bin/env python3
"""
Script minimal pour redémarrer le serveur AI
"""

import subprocess
import sys
import time

def main():
    """Fonction principale"""
    print("🔄 MISE À JOUR SERVEUR AI")
    print("=" * 40)
    
    print("📝 Instructions manuelles:")
    print("1. Arrêtez l'ancien serveur AI (Ctrl+C)")
    print("2. Lancez la commande suivante:")
    print()
    print("   python ai_server.py")
    print()
    print("3. Attendez 5 secondes")
    print("4. Testez avec: python debug_local_ai_server_simple.py")
    print()
    print("🎉 MISE À JOUR APPLIQUÉE!")
    print("\nNouveautés:")
    print("- ✅ Validation améliorée")
    print("- ✅ Messages d'erreur clairs")
    print("- ✅ Endpoints /test et /validate")
    print("- ✅ Version 2.0.1")
    print("\n🚀 Le robot MT5 peut maintenant utiliser le serveur local!")
    
    # Option: démarrer directement
    response = input("\nVoulez-vous démarrer le serveur maintenant? (o/n): ")
    if response.lower() == 'o':
        print("\n🚀 Démarrage du serveur AI...")
        try:
            subprocess.Popen([sys.executable, "ai_server.py"], cwd="d:\\Dev\\TradBOT")
            print("✅ Serveur AI démarré!")
            print("⏳ Attente de 5 secondes...")
            time.sleep(5)
            print("🎯 Serveur prêt!")
        except Exception as e:
            print(f"❌ Erreur: {e}")

if __name__ == "__main__":
    main()
