#!/usr/bin/env python3
"""
Test du Système Boom Rising Channel Predictor
Script de test pour vérifier le bon fonctionnement du système
"""

import sys
import time
import numpy as np
from datetime import datetime, timedelta
import json

def test_imports():
    """Test des imports"""
    print("🧪 Test des imports...")
    
    try:
        from boom_rising_channel_predictor import (
            BoomRisingChannelPredictor,
            SpikeDirection,
            PredictionArrow,
            RisingChannel,
            get_boom_prediction,
            update_boom_data
        )
        print("✅ boom_rising_channel_predictor importé avec succès")
    except ImportError as e:
        print(f"❌ Erreur import boom_rising_channel_predictor: {e}")
        return False
    
    try:
        from boom_trading_bot import (
            BoomTradingBot,
            TradingPosition,
            get_boom_trading_status
        )
        print("✅ boom_trading_bot importé avec succès")
    except ImportError as e:
        print(f"❌ Erreur import boom_trading_bot: {e}")
        return False
    
    try:
        import streamlit
        import plotly
        import pandas
        import matplotlib
        print("✅ Dépendances externes importées avec succès")
    except ImportError as e:
        print(f"❌ Erreur import dépendances: {e}")
        return False
    
    return True

def test_predictor():
    """Test du prédicteur"""
    print("\n🧪 Test du prédicteur...")
    
    try:
        from boom_rising_channel_predictor import BoomRisingChannelPredictor
        
        # Créer une instance
        predictor = BoomRisingChannelPredictor()
        print("✅ Prédicteur créé avec succès")
        
        # Créer des données de test
        test_data = []
        base_price = 10000.0
        
        for i in range(100):
            trend_factor = i * 0.1
            noise = np.random.normal(0, 0.5)
            price = base_price + trend_factor + noise
            
            test_data.append({
                'timestamp': time.time() - (100-i) * 60,
                'open': price,
                'high': price + abs(np.random.normal(0, 0.3)),
                'low': price - abs(np.random.normal(0, 0.3)),
                'close': price,
                'volume': np.random.randint(1000, 5000)
            })
        
        # Mettre à jour les données
        predictor.update_price_data(test_data)
        print("✅ Données mises à jour avec succès")
        
        # Tester la génération de prédiction
        prediction = predictor.get_trading_signal()
        print(f"✅ Prédiction générée: {prediction.get('action', 'N/A')}")
        
        # Tester le résumé
        summary = predictor.get_prediction_summary()
        print(f"✅ Résumé généré: {summary.get('status', 'N/A')}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test prédicteur: {e}")
        return False

def test_trading_bot():
    """Test du bot de trading"""
    print("\n🧪 Test du bot de trading...")
    
    try:
        from boom_trading_bot import BoomTradingBot
        
        # Créer une instance (sans initialiser MT5)
        bot = BoomTradingBot()
        print("✅ Bot de trading créé avec succès")
        
        # Tester les méthodes de base
        status = bot.get_trading_status()
        print(f"✅ Statut obtenu: {status['trading_enabled']}")
        
        positions = bot.get_positions_summary()
        print(f"✅ Positions obtenues: {len(positions)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test bot trading: {e}")
        return False

def test_data_flow():
    """Test du flux de données"""
    print("\n🧪 Test du flux de données...")
    
    try:
        from boom_rising_channel_predictor import update_boom_data, get_boom_prediction
        
        # Créer des données de test
        test_data = []
        base_price = 10000.0
        
        for i in range(50):
            trend_factor = i * 0.2
            noise = np.random.normal(0, 1.0)
            price = base_price + trend_factor + noise
            
            test_data.append({
                'timestamp': time.time() - (50-i) * 60,
                'open': price,
                'high': price + abs(np.random.normal(0, 0.5)),
                'low': price - abs(np.random.normal(0, 0.5)),
                'close': price,
                'volume': np.random.randint(1000, 5000)
            })
        
        # Mettre à jour les données
        update_boom_data(test_data)
        print("✅ Données mises à jour dans le système global")
        
        # Obtenir une prédiction
        prediction = get_boom_prediction()
        print(f"✅ Prédiction obtenue: {prediction.get('action', 'N/A')}")
        
        if prediction.get('action') != 'HOLD':
            print(f"   Direction: {prediction.get('direction', 'N/A')}")
            print(f"   Confiance: {prediction.get('confidence', 0):.2f}")
            print(f"   Probabilité: {prediction.get('spike_probability', 0):.2f}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test flux données: {e}")
        return False

def test_chart_generation():
    """Test de génération de graphique"""
    print("\n🧪 Test de génération de graphique...")
    
    try:
        from boom_rising_channel_predictor import create_boom_chart, update_boom_data
        
        # Créer des données de test
        test_data = []
        base_price = 10000.0
        
        for i in range(100):
            trend_factor = i * 0.1
            noise = np.random.normal(0, 0.5)
            price = base_price + trend_factor + noise
            
            test_data.append({
                'timestamp': time.time() - (100-i) * 60,
                'open': price,
                'high': price + abs(np.random.normal(0, 0.3)),
                'low': price - abs(np.random.normal(0, 0.3)),
                'close': price,
                'volume': np.random.randint(1000, 5000)
            })
        
        # Mettre à jour les données
        update_boom_data(test_data)
        
        # Générer le graphique
        chart_path = "test_boom_chart.png"
        result = create_boom_chart(chart_path)
        
        if "sauvegardé" in result:
            print(f"✅ Graphique généré: {chart_path}")
        else:
            print(f"✅ Graphique généré: {result}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test graphique: {e}")
        return False

def test_configuration():
    """Test de la configuration"""
    print("\n🧪 Test de la configuration...")
    
    try:
        # Tester la configuration des EMAs
        from boom_rising_channel_predictor import boom_predictor
        
        print(f"✅ Périodes EMA: {boom_predictor.ema_periods}")
        print(f"✅ Seuil proximité: {boom_predictor.ema_proximity_threshold}")
        print(f"✅ Seuil probabilité: {boom_predictor.spike_probability_threshold}")
        
        # Tester la configuration du bot
        from boom_trading_bot import boom_trading_bot
        
        print(f"✅ Symbole: {boom_trading_bot.symbol}")
        print(f"✅ Taille position: {boom_trading_bot.position_size}")
        print(f"✅ Max positions: {boom_trading_bot.max_positions}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test configuration: {e}")
        return False

def test_performance():
    """Test de performance"""
    print("\n🧪 Test de performance...")
    
    try:
        from boom_rising_channel_predictor import update_boom_data, get_boom_prediction
        
        # Mesurer le temps de traitement
        start_time = time.time()
        
        # Créer des données de test
        test_data = []
        base_price = 10000.0
        
        for i in range(200):
            trend_factor = i * 0.05
            noise = np.random.normal(0, 0.3)
            price = base_price + trend_factor + noise
            
            test_data.append({
                'timestamp': time.time() - (200-i) * 60,
                'open': price,
                'high': price + abs(np.random.normal(0, 0.2)),
                'low': price - abs(np.random.normal(0, 0.2)),
                'close': price,
                'volume': np.random.randint(1000, 5000)
            })
        
        # Mettre à jour les données
        update_boom_data(test_data)
        
        # Obtenir une prédiction
        prediction = get_boom_prediction()
        
        end_time = time.time()
        processing_time = end_time - start_time
        
        print(f"✅ Temps de traitement: {processing_time:.3f}s")
        print(f"✅ Données traitées: {len(test_data)} bougies")
        print(f"✅ Prédiction générée: {prediction.get('action', 'N/A')}")
        
        if processing_time < 1.0:
            print("✅ Performance excellente")
        elif processing_time < 2.0:
            print("✅ Performance bonne")
        else:
            print("⚠️ Performance à améliorer")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test performance: {e}")
        return False

def run_all_tests():
    """Exécute tous les tests"""
    print("🚀 Test du Système Boom Rising Channel Predictor")
    print("=" * 60)
    
    tests = [
        ("Imports", test_imports),
        ("Prédicteur", test_predictor),
        ("Bot Trading", test_trading_bot),
        ("Flux Données", test_data_flow),
        ("Génération Graphique", test_chart_generation),
        ("Configuration", test_configuration),
        ("Performance", test_performance)
    ]
    
    results = []
    
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ Erreur critique dans {test_name}: {e}")
            results.append((test_name, False))
    
    # Résumé des résultats
    print("\n📊 Résumé des Tests")
    print("=" * 30)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:20} {status}")
        if result:
            passed += 1
    
    print(f"\nRésultat: {passed}/{total} tests réussis")
    
    if passed == total:
        print("🎉 Tous les tests sont passés! Le système est prêt.")
        return True
    else:
        print("⚠️ Certains tests ont échoué. Vérifiez les erreurs ci-dessus.")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
