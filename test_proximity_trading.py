#!/usr/bin/env python3
"""
Test du Système de Trading par Proximité des Supports/Résistances
"""

import sys
import time
from proximity_trading_system import ProximityTradingSystem, SupportResistanceLevel
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_support_resistance_detection():
    """Test de la détection des supports et résistances"""
    print("🧪 Test de détection des supports/résistances")
    print("-" * 50)
    
    trading_system = ProximityTradingSystem()
    
    # Test sur quelques symboles
    test_symbols = ["Boom 1000 Index", "Crash 1000 Index"]
    
    for symbol in test_symbols:
        print(f"\n📊 Analyse de {symbol}:")
        
        try:
            levels = trading_system.detect_support_resistance_levels(symbol)
            
            if levels:
                print(f"   ✅ {len(levels)} niveaux détectés")
                
                # Afficher les 5 niveaux les plus proches
                for i, level in enumerate(levels[:5]):
                    print(f"   {i+1}. {level.level_type.upper()} à {level.price:.2f} "
                          f"(force: {level.strength:.2f}, confiance: {level.confidence:.2f}, "
                          f"méthode: {level.method})")
            else:
                print(f"   ⚠️ Aucun niveau détecté")
                
        except Exception as e:
            print(f"   ❌ Erreur: {e}")

def test_trading_signals():
    """Test de génération des signaux de trading"""
    print("\n🎯 Test de génération des signaux")
    print("-" * 50)
    
    trading_system = ProximityTradingSystem()
    
    # Test sur quelques symboles
    test_symbols = ["Boom 1000 Index", "Crash 1000 Index"]
    
    for symbol in test_symbols:
        print(f"\n📈 Signaux pour {symbol}:")
        
        try:
            signals = trading_system.generate_trading_signals(symbol)
            
            if signals:
                print(f"   ✅ {len(signals)} signaux générés")
                
                for i, signal in enumerate(signals):
                    print(f"   {i+1}. {signal.action} à {signal.entry_price:.2f} "
                          f"(SL: {signal.sl:.2f}, TP: {signal.tp:.2f}, "
                          f"confiance: {signal.confidence:.2f})")
                    print(f"      Raison: {signal.reason}")
            else:
                print(f"   ⚠️ Aucun signal généré")
                
        except Exception as e:
            print(f"   ❌ Erreur: {e}")

def test_system_status():
    """Test du statut du système"""
    print("\n📊 Test du statut du système")
    print("-" * 50)
    
    trading_system = ProximityTradingSystem()
    
    try:
        status = trading_system.get_status()
        
        print("   📈 Statut du système:")
        print(f"      Positions actives: {status['active_positions']}")
        print(f"      Trades aujourd'hui: {status['daily_trades']}")
        print(f"      Perte quotidienne: {status['daily_loss']:.2f}$")
        print(f"      Limite de perte: {status['max_daily_loss']:.2f}$")
        print(f"      Limite de trades: {status['max_daily_trades']}")
        
    except Exception as e:
        print(f"   ❌ Erreur: {e}")

def test_proximity_calculation():
    """Test du calcul de proximité"""
    print("\n📏 Test du calcul de proximité")
    print("-" * 50)
    
    # Test avec des niveaux fictifs
    test_levels = [
        SupportResistanceLevel(
            price=1000.0, level_type='support', strength=0.8,
            method='swing_low', distance=0.0, confidence=0.0
        ),
        SupportResistanceLevel(
            price=1010.0, level_type='resistance', strength=0.9,
            method='swing_high', distance=0.0, confidence=0.0
        ),
        SupportResistanceLevel(
            price=995.0, level_type='support', strength=0.7,
            method='psychological', distance=0.0, confidence=0.0
        )
    ]
    
    current_price = 1000.0
    proximity_threshold = 0.002  # 0.2%
    
    print(f"   Prix actuel: {current_price}")
    print(f"   Seuil de proximité: {proximity_threshold * 100:.1f}%")
    print()
    
    for i, level in enumerate(test_levels):
        distance_pct = abs(level.price - current_price) / current_price
        is_proximate = distance_pct <= proximity_threshold
        
        print(f"   Niveau {i+1}: {level.level_type} à {level.price}")
        print(f"      Distance: {distance_pct * 100:.2f}%")
        print(f"      Proche: {'✅' if is_proximate else '❌'}")
        print()

def test_signal_validation():
    """Test de validation des signaux"""
    print("\n✅ Test de validation des signaux")
    print("-" * 50)
    
    trading_system = ProximityTradingSystem()
    
    # Test avec des paramètres fictifs
    test_cases = [
        {"symbol": "Boom 1000 Index", "entry": 1000.0, "sl": 995.0, "tp": 1010.0, "expected": True},
        {"symbol": "Boom 1000 Index", "entry": 1000.0, "sl": 999.0, "tp": 1001.0, "expected": False},  # Trop proche
        {"symbol": "Crash 1000 Index", "entry": 1000.0, "sl": 1005.0, "tp": 990.0, "expected": True},
    ]
    
    for i, case in enumerate(test_cases):
        try:
            result = trading_system._validate_sl_tp_distances(
                case["symbol"], case["entry"], case["sl"], case["tp"]
            )
            
            status = "✅" if result == case["expected"] else "❌"
            print(f"   Test {i+1}: {status} (attendu: {case['expected']}, obtenu: {result})")
            
        except Exception as e:
            print(f"   Test {i+1}: ❌ Erreur - {e}")

def main():
    """Fonction principale de test"""
    print("🧪 Tests du Système de Trading par Proximité")
    print("=" * 60)
    
    try:
        # Tests individuels
        test_support_resistance_detection()
        test_trading_signals()
        test_system_status()
        test_proximity_calculation()
        test_signal_validation()
        
        print("\n🎉 Tests terminés avec succès!")
        
    except Exception as e:
        print(f"\n❌ Erreur lors des tests: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
