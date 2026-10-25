#!/usr/bin/env python3
"""
Test Rapide du Système de Trading par Proximité
"""

import sys
import os

def test_imports():
    """Test des imports nécessaires"""
    print("🧪 Test des imports...")
    
    try:
        import MetaTrader5 as mt5
        print("   ✅ MetaTrader5 importé")
    except ImportError as e:
        print(f"   ❌ MetaTrader5 non disponible: {e}")
        return False
    
    try:
        import pandas as pd
        print("   ✅ Pandas importé")
    except ImportError as e:
        print(f"   ❌ Pandas non disponible: {e}")
        return False
    
    try:
        import numpy as np
        print("   ✅ Numpy importé")
    except ImportError as e:
        print(f"   ❌ Numpy non disponible: {e}")
        return False
    
    return True

def test_mt5_connection():
    """Test de la connexion MT5"""
    print("\n🔌 Test de la connexion MT5...")
    
    try:
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            print("   ❌ Impossible d'initialiser MT5")
            return False
        
        account_info = mt5.account_info()
        if account_info is None:
            print("   ❌ Impossible d'obtenir les informations du compte")
            return False
        
        print(f"   ✅ MT5 connecté - Compte: {account_info.login}")
        print(f"   ✅ Solde: {account_info.balance} {account_info.currency}")
        
        mt5.shutdown()
        return True
        
    except Exception as e:
        print(f"   ❌ Erreur de connexion MT5: {e}")
        return False

def test_system_creation():
    """Test de création du système"""
    print("\n🏗️ Test de création du système...")
    
    try:
        from proximity_trading_system import ProximityTradingSystem
        
        system = ProximityTradingSystem()
        print("   ✅ Système créé avec succès")
        
        # Test des paramètres
        print(f"   ✅ Positions max: {system.max_positions}")
        print(f"   ✅ Taille de lot: {system.lot_size}")
        print(f"   ✅ Seuil de proximité: {system.proximity_threshold * 100:.1f}%")
        
        return True
        
    except Exception as e:
        print(f"   ❌ Erreur de création du système: {e}")
        return False

def test_config_loading():
    """Test de chargement de la configuration"""
    print("\n⚙️ Test de chargement de la configuration...")
    
    try:
        import json
        
        if os.path.exists('proximity_trading_config.json'):
            with open('proximity_trading_config.json', 'r') as f:
                config = json.load(f)
            print("   ✅ Configuration chargée")
            print(f"   ✅ Symboles: {len(config.get('symbols', []))}")
            print(f"   ✅ Positions max: {config.get('trading', {}).get('max_positions', 'N/A')}")
        else:
            print("   ⚠️ Fichier de configuration non trouvé")
        
        return True
        
    except Exception as e:
        print(f"   ❌ Erreur de chargement de la configuration: {e}")
        return False

def test_symbol_availability():
    """Test de disponibilité des symboles"""
    print("\n📊 Test de disponibilité des symboles...")
    
    try:
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            print("   ❌ Impossible d'initialiser MT5")
            return False
        
        test_symbols = ["Boom 1000 Index", "Crash 1000 Index"]
        available_symbols = []
        
        for symbol in test_symbols:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is not None:
                available_symbols.append(symbol)
                print(f"   ✅ {symbol} disponible")
            else:
                print(f"   ⚠️ {symbol} non disponible")
        
        mt5.shutdown()
        
        if available_symbols:
            print(f"   ✅ {len(available_symbols)} symboles disponibles")
            return True
        else:
            print("   ❌ Aucun symbole disponible")
            return False
        
    except Exception as e:
        print(f"   ❌ Erreur de test des symboles: {e}")
        return False

def main():
    """Fonction principale de test rapide"""
    print("🚀 TEST RAPIDE DU SYSTÈME DE TRADING PAR PROXIMITÉ")
    print("=" * 60)
    
    tests = [
        ("Imports", test_imports),
        ("Connexion MT5", test_mt5_connection),
        ("Création du système", test_system_creation),
        ("Configuration", test_config_loading),
        ("Symboles", test_symbol_availability)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                print(f"   ❌ Test '{test_name}' échoué")
        except Exception as e:
            print(f"   ❌ Test '{test_name}' échoué avec erreur: {e}")
    
    print(f"\n📊 RÉSULTATS: {passed}/{total} tests réussis")
    
    if passed == total:
        print("🎉 Tous les tests sont passés! Le système est prêt.")
        print("\nPour lancer le système:")
        print("   python proximity_trading_system.py")
        print("\nPour la démonstration:")
        print("   python demo_proximity_trading.py")
        return 0
    else:
        print("❌ Certains tests ont échoué. Vérifiez la configuration.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
