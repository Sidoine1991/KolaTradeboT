#!/usr/bin/env python3
"""
Script pour vérifier le statut de trading du weekend
"""
import MetaTrader5 as mt5
from datetime import datetime
import pytz

def check_weekend_trading_status():
    print("=" * 60)
    print("STATUT DE TRADING DU WEEKEND")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    # Current time info
    utc_now = datetime.now(pytz.UTC)
    print(f"🕐 Heure actuelle UTC: {utc_now.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📅 Jour de la semaine: {utc_now.strftime('%A')}")
    
    # Check if it's weekend
    is_weekend = utc_now.weekday() >= 5  # Saturday=5, Sunday=6
    if is_weekend:
        print("🎉 C'est le WEEKEND!")
        print("   Les marchés sont généralement fermés ou en mode 'Close only'")
    else:
        print("📊 C'est un jour de semaine")
        print("   Les marchés devraient être ouverts normalement")
    
    # Check Boom/Crash symbols
    symbols = ["Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"]
    
    print("\n" + "=" * 60)
    print("STATUT DES SYMBOLES BOOM/CRASH")
    print("=" * 60)
    
    all_close_only = True
    for symbol in symbols:
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            print(f"❌ {symbol}: Non trouvé")
            continue
        
        trade_mode = symbol_info.trade_mode
        mode_names = {
            0: "❌ Désactivé",
            1: "✅ Complet (Trading normal)",
            2: "⚠️  Long seulement",
            3: "⚠️  Short seulement",
            4: "❌ Close seulement (Weekend)",
            5: "⚠️  Session longue seulement"
        }
        
        mode_name = mode_names.get(trade_mode, f"❓ Inconnu ({trade_mode})")
        print(f"{symbol}: {mode_name}")
        
        if trade_mode == 1:
            all_close_only = False
    
    print("\n" + "=" * 60)
    print("RÉSUMÉ ET RECOMMANDATIONS")
    print("=" * 60)
    
    if all_close_only and is_weekend:
        print("✅ DIAGNOSTIC: Normal pour un weekend")
        print("   • Tous les indices Boom/Crash sont en mode 'Close only'")
        print("   • C'est le comportement attendu pendant le weekend")
        print("   • Les données de prix sont toujours disponibles")
        print("   • MAIS aucune nouvelle position ne peut être ouverte")
        
        print("\n📅 QUAND TRADER:")
        print("   • Lundi-Vendredi: Généralement 08:00-20:00 UTC")
        print("   • Éviter le weekend pour les nouvelles positions")
        
        print("\n🔧 CE QUI FONCTIONNE:")
        print("   ✅ Analyse de marché et prédictions IA")
        print("   ✅ Surveillance des prix")
        print("   ✅ Fermeture de positions existantes")
        print("   ❌ Ouverture de nouvelles positions (weekend)")
        
        print("\n💡 CONSEIL:")
        print("   Utilisez le weekend pour:")
        print("   • Analyser les performances")
        print("   • Optimiser les stratégies")
        print("   • Préparer les setups pour la semaine")
        
    elif all_close_only and not is_weekend:
        print("⚠️  ATTENTION: Mode 'Close only' en semaine!")
        print("   • Vérifiez s'il y a une maintenance broker")
        print("   • Vérifiez les heures de trading spécifiques")
        print("   • Contactez le support si nécessaire")
        
    else:
        print("🎉 BONNE NOUVELLE!")
        print("   • Certains symboles sont disponibles pour le trading")
        print("   • Vous pouvez placer de nouvelles positions")
    
    mt5.shutdown()
    print("\n✅ Vérification terminée")

if __name__ == "__main__":
    check_weekend_trading_status()
