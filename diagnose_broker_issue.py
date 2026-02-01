#!/usr/bin/env python3
"""
Diagnostic des problèmes de broker pour les indices Boom/Crash
"""
import MetaTrader5 as mt5
from datetime import datetime
import pytz

def diagnose_broker_issues():
    print("=" * 60)
    print("DIAGNOSTIC DES PROBLÈMES BROKER")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    # 1. Vérifier les informations du compte et broker
    print("📋 INFORMATIONS BROKER:")
    account_info = mt5.account_info()
    if account_info:
        print(f"   Broker: {account_info.company}")
        print(f"   Serveur: {account_info.server}")
        print(f"   Login: {account_info.login}")
        print(f"   Solde: {account_info.balance}")
        print(f"   Marge libre: {account_info.margin_free}")
        
        # Vérifier si c'est un compte démo
        if "Demo" in account_info.server or "demo" in account_info.server.lower():
            print("   ⚠️  Compte DEMO détecté")
        else:
            print("   ✅ Compte réel")
    
    # 2. Vérifier les symboles disponibles
    print("\n📊 VÉRIFICATION DES SYMBOLES:")
    
    # Symboles Boom/Crash
    boom_crash_symbols = [
        "Boom 300 Index", "Boom 500 Index", "Boom 1000 Index",
        "Crash 300 Index", "Crash 500 Index", "Crash 1000 Index"
    ]
    
    # Symboles Volatility
    volatility_symbols = [
        "Volatility 10 Index", "Volatility 25 Index", "Volatility 50 Index",
        "Volatility 75 Index", "Volatility 100 Index", "Volatility 200 Index"
    ]
    
    # Symboles Forex (pour comparaison)
    forex_symbols = ["EURUSD", "GBPUSD", "USDJPY", "AUDUSD"]
    
    all_symbols = {
        "Boom/Crash": boom_crash_symbols,
        "Volatility": volatility_symbols, 
        "Forex": forex_symbols
    }
    
    for category, symbols in all_symbols.items():
        print(f"\n   {category}:")
        available_count = 0
        tradable_count = 0
        
        for symbol in symbols:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info:
                available_count += 1
                status = "❌ Close-only" if symbol_info.trade_mode != 1 else "✅ Tradable"
                print(f"      {symbol}: {status}")
                if symbol_info.trade_mode == 1:
                    tradable_count += 1
            else:
                print(f"      {symbol}: ❌ Non disponible")
        
        print(f"      → {available_count}/{len(symbols)} disponibles, {tradable_count}/{len(symbols)} tradables")
    
    # 3. Vérifier l'heure du serveur
    print("\n🕐 HEURE SERVEUR:")
    terminal_info = mt5.terminal_info()
    if terminal_info:
        # Convertir l'heure locale en heure du serveur
        local_time = datetime.now()
        print(f"   Heure locale: {local_time}")
        
        # MT5 ne donne pas directement l'heure du serveur, mais on peut déduire
        # Vérifier les ticks récents pour voir l'activité
        for symbol in ["Boom 300 Index", "EURUSD"]:
            tick = mt5.symbol_info_tick(symbol)
            if tick:
                tick_time = datetime.fromtimestamp(tick.time)
                time_diff = (local_time - tick_time).total_seconds()
                print(f"   Dernier tick {symbol}: {tick_time} (il y a {time_diff:.0f}s)")
    
    # 4. Vérifier les restrictions possibles
    print("\n🔍 DIAGNOSTIC DES RESTRICTIONS:")
    
    # Vérifier si c'est un problème de maintenance
    print("   Possibilités de restriction:")
    print("   1. Maintenance broker (weekend)")
    print("   2. Restrictions compte démo")
    print("   3. Heures de trading spécifiques")
    print("   4. Problème de configuration broker")
    
    # 5. Solutions suggérées
    print("\n💡 SOLUTIONS SUGGÉRÉES:")
    
    # Si tous les symboles sont en close-only
    all_close_only = True
    for symbol in boom_crash_symbols + volatility_symbols:
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info and symbol_info.trade_mode == 1:
            all_close_only = False
            break
    
    if all_close_only:
        print("   1. ⏰ Attendre l'ouverture des marchés (Lundi 00:00 UTC)")
        print("   2. 📞 Contacter le support broker")
        print("   3. 🔄 Essayer un autre serveur si disponible")
        print("   4. 💻 Vérifier les mises à jour MT5")
        
        # Vérifier si c'est dimanche soir
        utc_now = datetime.now(pytz.UTC)
        if utc_now.weekday() == 6:  # Sunday
            print("   5. 📅 Dimanche soir: Les marchés rouvrent souvent à 21:00 UTC")
    else:
        print("   ✅ Certains symboles sont disponibles - vérifier lesquels")
    
    # 6. Test avec un ordre de démonstration
    print("\n🧪 TEST D'ORDRE (SIMULATION):")
    test_symbol = "Boom 300 Index"
    symbol_info = mt5.symbol_info(test_symbol)
    
    if symbol_info and symbol_info.trade_mode == 1:
        print(f"   ✅ {test_symbol} est disponible pour le trading")
    else:
        print(f"   ❌ {test_symbol} n'est pas disponible pour le trading")
        print(f"      Mode actuel: {symbol_info.trade_mode if symbol_info else 'N/A'}")
    
    mt5.shutdown()
    print("\n✅ Diagnostic terminé")

if __name__ == "__main__":
    diagnose_broker_issues()
