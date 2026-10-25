#!/usr/bin/env python3
"""
Script pour lister tous les symboles disponibles sur MT5
"""

import sys
import os
sys.path.append('backend')

try:
    from mt5_connector import connect, get_all_symbols, get_symbols_by_category, shutdown
    import MetaTrader5 as mt5
except ImportError as e:
    print(f"❌ Erreur d'import: {e}")
    sys.exit(1)

def list_all_symbols():
    """Lister tous les symboles disponibles"""
    print("🔍 Connexion à MT5...")
    
    try:
        # Connexion
        connect()
        print("✅ Connecté à MT5")
        
        # Récupérer tous les symboles
        print("\n📊 Récupération de tous les symboles...")
        all_symbols = get_all_symbols()
        
        if not all_symbols:
            print("❌ Aucun symbole trouvé")
            return
        
        print(f"✅ {len(all_symbols)} symboles trouvés")
        
        # Catégoriser les symboles
        print("\n📋 Catégorisation des symboles...")
        categorized = get_symbols_by_category()
        
        for category, symbols in categorized.items():
            if symbols:
                print(f"\n🔸 {category} ({len(symbols)} symboles):")
                for symbol in symbols[:10]:  # Afficher les 10 premiers
                    print(f"   - {symbol}")
                if len(symbols) > 10:
                    print(f"   ... et {len(symbols) - 10} autres")
        
        # Chercher spécifiquement les indices synthétiques
        print("\n🎯 Recherche d'indices synthétiques...")
        synthetic_symbols = [s for s in all_symbols if any(keyword in s.upper() for keyword in ['BOOM', 'CRASH', 'STEP', 'JUMP', 'RANGE']) and 'INDEX' in s.upper()]
        
        if synthetic_symbols:
            print(f"✅ {len(synthetic_symbols)} indices synthétiques trouvés:")
            for symbol in synthetic_symbols:
                print(f"   - {symbol}")
        else:
            print("❌ Aucun indice synthétique trouvé")
            # Chercher tous les symboles contenant "Index"
            index_symbols = [s for s in all_symbols if 'INDEX' in s.upper()]
            if index_symbols:
                print(f"📋 Symboles avec 'Index' trouvés ({len(index_symbols)}):")
                for symbol in index_symbols:
                    print(f"   - {symbol}")
        
        # Chercher les paires Forex
        print("\n💱 Recherche de paires Forex...")
        forex_symbols = [s for s in all_symbols if len(s) == 6 and s[:3] in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD'] and s[3:6] in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD']]
        
        if forex_symbols:
            print(f"✅ {len(forex_symbols)} paires Forex trouvées:")
            for symbol in forex_symbols[:10]:
                print(f"   - {symbol}")
            if len(forex_symbols) > 10:
                print(f"   ... et {len(forex_symbols) - 10} autres")
        else:
            print("❌ Aucune paire Forex trouvée")
        
        # Test de récupération de données pour quelques symboles
        print("\n🧪 Test de récupération de données...")
        test_symbols = ['EURUSD', 'GBPUSD', 'USDJPY']
        
        for symbol in test_symbols:
            if symbol in all_symbols:
                print(f"\n🔍 Test de {symbol}...")
                try:
                    # Vérifier si le symbole est visible
                    symbol_info = mt5.symbol_info(symbol)
                    if symbol_info and not symbol_info.visible:
                        print(f"   ⚠️ {symbol} non visible, tentative d'ajout...")
                        if mt5.symbol_select(symbol, True):
                            print(f"   ✅ {symbol} ajouté avec succès")
                        else:
                            print(f"   ❌ Impossible d'ajouter {symbol}")
                            continue
                    
                    # Tenter de récupérer des données
                    rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_H1, 0, 10)
                    if rates is not None and len(rates) > 0:
                        print(f"   ✅ Données disponibles: {len(rates)} bougies")
                        print(f"   📊 Dernier prix: {rates[-1]['close']:.5f}")
                    else:
                        print(f"   ❌ Aucune donnée pour {symbol}")
                        
                except Exception as e:
                    print(f"   ❌ Erreur pour {symbol}: {e}")
            else:
                print(f"❌ {symbol} non trouvé dans la liste")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
    
    finally:
        # Déconnexion
        try:
            shutdown()
            print("\n🔌 Déconnecté de MT5")
        except:
            pass

if __name__ == "__main__":
    print("🚀 Liste des symboles MT5 disponibles")
    print("=" * 50)
    list_all_symbols() 