#!/usr/bin/env python3
"""
Comparer les capacités de trading mobile vs MT5
"""
import MetaTrader5 as mt5
from datetime import datetime

def check_mobile_vs_mt5():
    print("=" * 60)
    print("COMPARAISON MOBILE VS MT5")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    account_info = mt5.account_info()
    print(f"📋 Compte MT5: {account_info.login} @ {account_info.server}")
    print(f"   Broker: {account_info.company}")
    print(f"   Type: {'Demo' if 'Demo' in account_info.server else 'Real'}")
    
    # Vérifier les permissions du compte
    print(f"\n🔍 PERMISSIONS DU COMPTE:")
    print(f"   Trading autorisé: {account_info.trade_allowed}")
    print(f"   Solde: {account_info.balance}")
    print(f"   Marge libre: {account_info.margin_free}")
    
    # Vérifier si c'est un compte démo avec restrictions
    if "Demo" in account_info.server:
        print(f"   ⚠️  Compte DEMO - Peut avoir des restrictions")
    
    # Vérifier les symboles en détail
    symbols = ["Boom 300 Index", "Boom 600 Index"]
    
    print(f"\n📊 ANALYSE DÉTAILLÉE DES SYMBOLES:")
    
    for symbol in symbols:
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            print(f"❌ {symbol}: Non trouvé")
            continue
        
        print(f"\n🔍 {symbol}:")
        print(f"   Trade mode: {symbol_info.trade_mode} ({get_trade_mode_name(symbol_info.trade_mode)})")
        print(f"   Visible: {symbol_info.visible}")
        print(f"   Volume min/max: {symbol_info.volume_min} / {symbol_info.volume_max}")
        print(f"   Point: {symbol_info.point}")
        print(f"   Digits: {symbol_info.digits}")
        print(f"   Spread: {symbol_info.spread}")
        
        # Vérifier les permissions de trading pour ce symbole
        print(f"   Permissions:")
        print(f"     Trade mode: {symbol_info.trade_mode_description if hasattr(symbol_info, 'trade_mode_description') else 'N/A'}")
        
        # Vérifier si le symbole peut être sélectionné
        selected = mt5.symbol_select(symbol, True)
        print(f"     Sélectionné: {selected}")
        
        # Vérifier les ticks
        tick = mt5.symbol_info_tick(symbol)
        if tick:
            print(f"     Dernier tick: {tick.bid}/{tick.ask} @ {datetime.fromtimestamp(tick.time)}")
        else:
            print(f"     ❌ Pas de tick")
    
    # Test de permissions de trading
    print(f"\n🧪 TEST DE PERMISSIONS:")
    
    # Vérifier si le trading est autorisé globalement
    if not account_info.trade_allowed:
        print("❌ Trading non autorisé sur ce compte!")
        print("   Solutions:")
        print("   1. Vérifier les paramètres du compte dans MT5")
        print("   2. Contacter le broker")
        return
    
    print("✅ Trading autorisé sur le compte")
    
    # Vérifier si AutoTrading est activé dans MT5 (nécessite vérification manuelle)
    print("   ⚠️  Vérifier que 'AutoTrading' est activé dans MT5 (bouton vert)")
    
    # Vérifier les informations du terminal
    terminal_info = mt5.terminal_info()
    if terminal_info:
        print(f"\n💻 ÉTAT DU TERMINAL MT5:")
        print(f"   Connecté: {terminal_info.connected}")
        print(f"   Nom: {terminal_info.name}")
        print(f"   Version: {terminal_info.build}")
        
        # Vérifier si le trading automatique est activé dans le terminal
        if hasattr(terminal_info, 'trade_allowed'):
            print(f"   Trading terminal autorisé: {terminal_info.trade_allowed}")
    
    # Diagnostic spécifique pour le problème mobile vs MT5
    print(f"\n🎯 DIAGNOSTIC MOBILE VS MT5:")
    print("   Si vous pouvez trader sur mobile mais pas MT5:")
    print("   1. ✅ Le broker autorise le trading sur ces symboles")
    print("   2. ✅ Le compte a les permissions de trading")
    print("   3. ❌ Problème spécifique à MT5 ou au serveur MT5")
    
    print(f"\n🔧 SOLUTIONS SPÉCIFIQUES MT5:")
    print("   1. Vérifier 'AutoTrading' est activé (bouton vert dans MT5)")
    print("   2. Outils -> Options -> Expert Advisors:")
    print("      ☑️ Autoriser le trading automatique")
    print("      ☑️ Autoriser les DLL")
    print("      ☑️ Autoriser les imports DLL")
    print("   3. Essayer de placer un ordre manuellement dans MT5")
    print("   4. Redémarrer MT5")
    print("   5. Essayer un autre serveur MT5 du même broker")
    
    mt5.shutdown()

def get_trade_mode_name(mode):
    modes = {
        0: "Désactivé",
        1: "Complet",
        2: "Long seulement",
        3: "Short seulement",
        4: "Close seulement",
        5: "Session longue seulement"
    }
    return modes.get(mode, f"Inconnu ({mode})")

if __name__ == "__main__":
    check_mobile_vs_mt5()
