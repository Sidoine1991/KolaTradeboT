#!/usr/bin/env python3
"""
Script to fix trading mode issues and provide guidance on when to trade
"""
import MetaTrader5 as mt5
from datetime import datetime
import pytz

def check_and_fix_trading_mode():
    print("=" * 60)
    print("ANALYSE ET SOLUTION POUR LE MODE DE TRADING")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    symbols = ["Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"]
    
    print("📊 Analyse des modes de trading actuels:")
    print("-" * 60)
    
    all_close_only = True
    tradable_symbols = []
    
    for symbol in symbols:
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            print(f"❌ {symbol}: Non trouvé")
            continue
        
        trade_mode = symbol_info.trade_mode
        mode_names = {
            0: "Désactivé",
            1: "✅ Complet (Full)",
            2: "Long seulement",
            3: "Short seulement", 
            4: "❌ Close seulement",
            5: "Session longue seulement"
        }
        
        mode_name = mode_names.get(trade_mode, f"Inconnu ({trade_mode})")
        print(f"{symbol}: {mode_name}")
        
        if trade_mode == 1:  # Full trading mode
            tradable_symbols.append(symbol)
            all_close_only = False
    
    print("\n" + "=" * 60)
    print("DIAGNOSTIC ET RECOMMANDATIONS")
    print("=" * 60)
    
    if all_close_only:
        print("🔍 DIAGNOSTIC:")
        print("   Tous les indices Boom/Crash sont en mode 'Close seulement'")
        print("   C'est normal pendant certaines heures de trading")
        
        print("\n⏰ HEURES DE TRADING TYPIQUES:")
        print("   Les indices Boom/Crash sont généralement disponibles:")
        print("   - Lundi-Vendredi: 08:00-20:00 UTC (approx)")
        print("   - Weekends: Limité ou fermé")
        
        print("\n🌍 HEURE ACTUELLE:")
        utc_now = datetime.now(pytz.UTC)
        print(f"   UTC: {utc_now.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Check if it's weekend
        if utc_now.weekday() >= 5:  # Saturday=5, Sunday=6
            print("   ⚠️  C'est le weekend - Les marchés sont fermés!")
        elif utc_now.hour < 8 or utc_now.hour >= 20:
            print("   ⚠️  Hors des heures de trading principales")
        else:
            print("   ✅ Heures de trading normales - Devrait être disponible")
        
        print("\n🔧 SOLUTIONS:")
        print("   1. Attendre les heures de trading appropriées")
        print("   2. Vérifier si le broker a des restrictions spéciales")
        print("   3. Tester avec d'autres symboles (Forex, indices)")
        
        # Test with other symbols
        print("\n📈 TEST AVEC AUTRES SYMBOLES:")
        test_symbols = ["EURUSD", "GBPUSD", "US30", "NAS100"]
        
        for symbol in test_symbols:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                continue
            
            if symbol_info.trade_mode == 1:
                print(f"   ✅ {symbol}: Disponible pour trading")
                tradable_symbols.append(symbol)
            else:
                print(f"   ❌ {symbol}: Mode {symbol_info.trade_mode}")
    
    else:
        print("✅ BONNE NOUVELLE:")
        print("   Certains symboles sont disponibles pour le trading!")
        print(f"   Symboles tradables: {tradable_symbols}")
    
    print("\n" + "=" * 60)
    print("MODIFICATIONS RECOMMANDÉES POUR VOTRE CODE")
    print("=" * 60)
    
    print("📝 Ajoutez cette vérification avant de placer des ordres:")
    print("""
def can_place_order(symbol):
    \"\"\"Vérifie si on peut placer un ordre sur ce symbole\"\"\"
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        return False, "Symbole non trouvé"
    
    if symbol_info.trade_mode != 1:  # 1 = Full trading
        return False, f"Mode trading: {symbol_info.trade_mode} (Close only)"
    
    if not symbol_info.visible:
        return False, "Symbole non visible"
    
    return True, "OK"

# Utilisation avant de placer un ordre:
can_trade, reason = can_place_order(symbol)
if not can_trade:
    print(f"❌ Impossible de trader {symbol}: {reason}")
    continue  # Skip this symbol
""")
    
    print("\n🔄 POUR VOTRE SYSTÈME ACTUEL:")
    print("   1. Ajoutez la vérification ci-dessus dans votre code")
    print("   2. Logguez quand les symboles ne sont pas disponibles")
    print("   3. Essayez de trader pendant les heures de volume élevé")
    
    mt5.shutdown()

if __name__ == "__main__":
    check_and_fix_trading_mode()
