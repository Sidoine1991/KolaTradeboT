#!/usr/bin/env python3
"""
Vérifier les serveurs MT5 disponibles pour Deriv
"""
import MetaTrader5 as mt5

def check_available_servers():
    print("=" * 60)
    print("VÉRIFICATION DES SERVEURS MT5 DISPONIBLES")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    # Obtenir les informations du terminal
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"📋 Terminal: {terminal_info.name}")
        print(f"   Version: {terminal_info.build}")
        print(f"   Connecté: {terminal_info.connected}")
        print(f"   Serveur actuel: {mt5.account_info().server if mt5.account_info() else 'N/A'}")
    
    # Liste des serveurs Deriv connus
    deriv_servers = [
        "Deriv-Demo",
        "Deriv-Demo2", 
        "Deriv-Demo3",
        "Deriv-Server",
        "Deriv-Server2",
        "Deriv-Live",
        "Deriv-Live2"
    ]
    
    print("\n🔍 TEST DE CONNEXION AUX SERVEURS DERIV:")
    print("(Note: MT5 ne permet pas de lister tous les serveurs disponibles)")
    print("Testons les serveurs Deriv connus:")
    
    current_account = mt5.account_info()
    if current_account:
        current_login = current_account.login
        print(f"\nLogin actuel: {current_login}")
        
        # Pour tester d'autres serveurs, il faudrait se déconnecter et se reconnecter
        # Ce qui n'est pas recommandé pendant que le bot tourne
        print("\n⚠️  Pour tester d'autres serveurs:")
        print("   1. Notez vos identifiants actuels")
        print("   2. Dans MT5: Fichier -> Connexion -> Configurer")
        print("   3. Essayez les serveurs suivants:")
        
        for server in deriv_servers:
            if server != current_account.server:
                print(f"      - {server}")
    
    # Vérifier l'état de la connexion
    print("\n📊 ÉTAT DE LA CONNEXION ACTUELLE:")
    if terminal_info and terminal_info.connected:
        print("   ✅ Terminal connecté")
        
        # Vérifier si les données arrivent
        symbols_to_test = ["Boom 300 Index", "EURUSD"]
        for symbol in symbols_to_test:
            tick = mt5.symbol_info_tick(symbol)
            if tick:
                from datetime import datetime
                tick_time = datetime.fromtimestamp(tick.time)
                print(f"   ✅ {symbol}: Dernier tick {tick_time}")
            else:
                print(f"   ❌ {symbol}: Pas de tick")
    else:
        print("   ❌ Terminal non connecté")
    
    # Informations sur le problème actuel
    print("\n🔍 ANALYSE DU PROBLÈME:")
    print("   Tous les symboles sont en mode 'Close-only'")
    print("   Causes possibles:")
    print("   1. Maintenance weekend Deriv")
    print("   2. Restrictions compte démo")
    print("   3. Problème serveur Deriv-Demo")
    
    print("\n💡 SOLUTIONS IMMÉDIATES:")
    print("   1. ⏰ Attendre Lundi matin (00:00 UTC)")
    print("   2. 📞 Contacter support Deriv")
    print("   3. 🔄 Essayer un autre compte (réel si disponible)")
    print("   4. 🌐 Vérifier le statut du broker Deriv")
    
    mt5.shutdown()
    print("\n✅ Vérification terminée")

if __name__ == "__main__":
    check_available_servers()
