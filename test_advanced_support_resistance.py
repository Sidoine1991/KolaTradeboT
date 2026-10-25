"""
Test de la logique avancée de supports et résistances.
"""

import sys
import os
sys.path.append(os.path.abspath('.'))

import pandas as pd
import numpy as np
from datetime import datetime, timedelta

def create_test_data():
    """Crée des données de test avec des niveaux de support/résistance connus."""
    # Génération de données OHLCV simulées
    np.random.seed(42)
    dates = pd.date_range(start='2025-01-01', periods=1000, freq='1H')
    
    # Prix de base avec tendance
    base_price = 100.0
    trend = np.linspace(0, 20, 1000)  # Tendance haussière
    noise = np.random.normal(0, 2, 1000)
    
    # Création de niveaux de support/résistance connus
    support_levels = [95, 98, 102, 105, 108]
    resistance_levels = [110, 113, 116, 119, 122]
    
    prices = base_price + trend + noise
    
    # Ajout de rebonds sur les niveaux
    for i in range(len(prices)):
        # Support
        for support in support_levels:
            if prices[i] <= support:
                prices[i] = support + np.random.uniform(0, 1)
        
        # Résistance
        for resistance in resistance_levels:
            if prices[i] >= resistance:
                prices[i] = resistance - np.random.uniform(0, 1)
    
    # Génération OHLCV
    df = pd.DataFrame({
        'timestamp': dates,
        'open': prices + np.random.normal(0, 0.5, 1000),
        'high': prices + np.abs(np.random.normal(0, 1, 1000)),
        'low': prices - np.abs(np.random.normal(0, 1, 1000)),
        'close': prices,
        'volume': np.random.randint(1000, 10000, 1000)
    })
    
    # Assurer la cohérence OHLC
    df['high'] = df[['open', 'close', 'high']].max(axis=1)
    df['low'] = df[['open', 'close', 'low']].min(axis=1)
    
    df.set_index('timestamp', inplace=True)
    return df

def test_basic_functionality():
    """Test de la fonctionnalité de base."""
    print("🧪 Test de la fonctionnalité de base...")
    
    try:
        from backend.advanced_support_resistance import AdvancedSupportResistance
        
        # Création du détecteur
        detector = AdvancedSupportResistance()
        print("✅ Détecteur créé avec succès")
        
        # Test de configuration
        config = detector.config
        print(f"✅ Configuration chargée : {len(config)} paramètres")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur dans le test de base : {e}")
        return False

def test_level_detection():
    """Test de la détection des niveaux."""
    print("\n🔍 Test de la détection des niveaux...")
    
    try:
        from backend.advanced_support_resistance import AdvancedSupportResistance
        
        # Création des données de test
        df = create_test_data()
        print(f"✅ Données de test créées : {df.shape}")
        
        # Détection des niveaux
        detector = AdvancedSupportResistance()
        levels = detector.detect_all_levels(df, "TEST_SYMBOL")
        
        print(f"✅ Niveaux détectés :")
        print(f"   - Supports : {len(levels.get('supports', []))}")
        print(f"   - Résistances : {len(levels.get('resistances', []))}")
        
        # Affichage des détails
        if levels.get('supports'):
            print("\n🔸 Supports détectés :")
            for i, support in enumerate(levels['supports'][:3]):
                print(f"   {i+1}. Prix: {support['price']:.2f}, Force: {support['strength']:.2f}, Méthode: {support['method']}")
        
        if levels.get('resistances'):
            print("\n🔸 Résistances détectées :")
            for i, resistance in enumerate(levels['resistances'][:3]):
                print(f"   {i+1}. Prix: {resistance['price']:.2f}, Force: {resistance['strength']:.2f}, Méthode: {resistance['method']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur dans la détection des niveaux : {e}")
        return False

def test_integration():
    """Test de l'intégration avec technical_analysis.py."""
    print("\n🔗 Test de l'intégration...")
    
    try:
        from backend.technical_analysis import get_support_resistance_levels
        
        # Création des données de test
        df = create_test_data()
        
        # Test de la fonction intégrée
        levels = get_support_resistance_levels(df)
        
        print(f"✅ Intégration réussie :")
        print(f"   - Supports : {len(levels.get('support', []))}")
        print(f"   - Résistances : {len(levels.get('resistance', []))}")
        
        # Test de la fonction avancée
        if 'advanced_analysis' in levels:
            print(f"   - Analyse avancée disponible")
            adv = levels['advanced_analysis']
            print(f"   - Supports avancés : {len(adv.get('supports', []))}")
            print(f"   - Résistances avancées : {len(adv.get('resistances', []))}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur dans l'intégration : {e}")
        return False

def test_performance():
    """Test de performance."""
    print("\n⚡ Test de performance...")
    
    try:
        from backend.advanced_support_resistance import AdvancedSupportResistance
        import time
        
        # Création de données plus volumineuses
        df = create_test_data()
        df_large = pd.concat([df] * 5, ignore_index=False)  # 5000 bougies
        print(f"✅ Données volumineuses créées : {df_large.shape}")
        
        # Test de performance
        detector = AdvancedSupportResistance()
        
        start_time = time.time()
        levels = detector.detect_all_levels(df_large, "PERF_TEST")
        end_time = time.time()
        
        duration = end_time - start_time
        print(f"✅ Détection terminée en {duration:.3f} secondes")
        print(f"   - Taux : {df_large.shape[0] / duration:.0f} bougies/seconde")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur dans le test de performance : {e}")
        return False

def main():
    """Fonction principale de test."""
    print("🚀 Test de la logique avancée de supports et résistances")
    print("=" * 60)
    
    tests = [
        ("Fonctionnalité de base", test_basic_functionality),
        ("Détection des niveaux", test_level_detection),
        ("Intégration", test_integration),
        ("Performance", test_performance)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ Erreur critique dans {test_name} : {e}")
            results.append((test_name, False))
    
    # Résumé des tests
    print("\n📊 Résumé des tests :")
    print("=" * 60)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            passed += 1
    
    print(f"\n🎯 Résultat final : {passed}/{total} tests réussis")
    
    if passed == total:
        print("🎉 Tous les tests sont passés avec succès !")
    else:
        print("⚠️ Certains tests ont échoué. Vérifiez les erreurs ci-dessus.")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
