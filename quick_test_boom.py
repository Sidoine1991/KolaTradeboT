#!/usr/bin/env python3
"""
Test Rapide du Système Boom Rising Channel Predictor
Vérification rapide des fonctionnalités principales
"""

import sys
import time
import numpy as np

def quick_test():
    """Test rapide des fonctionnalités principales"""
    print("🚀 Test Rapide - Boom Rising Channel Predictor")
    print("=" * 50)
    
    # Test 1: Imports
    print("1️⃣ Test des imports...")
    try:
        from boom_rising_channel_predictor import get_boom_prediction, update_boom_data
        from boom_trading_bot import get_boom_trading_status
        print("   ✅ Imports réussis")
    except ImportError as e:
        print(f"   ❌ Erreur import: {e}")
        return False
    
    # Test 2: Création de données de test
    print("2️⃣ Création de données de test...")
    try:
        test_data = []
        base_price = 10000.0
        
        for i in range(50):
            trend_factor = i * 0.1
            noise = np.random.normal(0, 0.5)
            price = base_price + trend_factor + noise
            
            test_data.append({
                'timestamp': time.time() - (50-i) * 60,
                'open': price,
                'high': price + abs(np.random.normal(0, 0.3)),
                'low': price - abs(np.random.normal(0, 0.3)),
                'close': price,
                'volume': np.random.randint(1000, 5000)
            })
        
        print(f"   ✅ {len(test_data)} bougies créées")
    except Exception as e:
        print(f"   ❌ Erreur données: {e}")
        return False
    
    # Test 3: Mise à jour des données
    print("3️⃣ Mise à jour des données...")
    try:
        update_boom_data(test_data)
        print("   ✅ Données mises à jour")
    except Exception as e:
        print(f"   ❌ Erreur mise à jour: {e}")
        return False
    
    # Test 4: Génération de prédiction
    print("4️⃣ Génération de prédiction...")
    try:
        prediction = get_boom_prediction()
        print(f"   ✅ Prédiction: {prediction.get('action', 'N/A')}")
        
        if prediction.get('action') != 'HOLD':
            print(f"      Direction: {prediction.get('direction', 'N/A')}")
            print(f"      Confiance: {prediction.get('confidence', 0):.2f}")
    except Exception as e:
        print(f"   ❌ Erreur prédiction: {e}")
        return False
    
    # Test 5: Statut du trading
    print("5️⃣ Statut du trading...")
    try:
        status = get_boom_trading_status()
        print(f"   ✅ Trading activé: {status.get('trading_enabled', False)}")
        print(f"      Positions: {status.get('active_positions', 0)}")
    except Exception as e:
        print(f"   ❌ Erreur statut: {e}")
        return False
    
    # Test 6: Configuration
    print("6️⃣ Test de la configuration...")
    try:
        from boom_config import get_config
        boom_config = get_config('boom')
        ema_config = get_config('ema')
        trading_config = get_config('trading')
        
        print(f"   ✅ Symbole: {boom_config.get('symbol', 'N/A')}")
        print(f"      EMAs: {ema_config.get('periods', [])}")
        print(f"      Max positions: {trading_config.get('max_positions', 0)}")
    except Exception as e:
        print(f"   ❌ Erreur configuration: {e}")
        return False
    
    print("\n🎉 Tous les tests rapides sont passés!")
    print("✅ Le système est prêt à être utilisé")
    return True

if __name__ == "__main__":
    success = quick_test()
    if success:
        print("\n🚀 Pour démarrer le système complet:")
        print("   python launch_boom_system.py --mode full")
        print("\n🌐 Pour l'interface web uniquement:")
        print("   python launch_boom_system.py --mode interface")
        print("\n🤖 Pour le trading uniquement:")
        print("   python launch_boom_system.py --mode trading")
    else:
        print("\n❌ Des erreurs ont été détectées")
        print("   Vérifiez les messages ci-dessus")
    
    sys.exit(0 if success else 1)
