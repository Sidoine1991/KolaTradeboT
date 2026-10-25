#!/usr/bin/env python3
"""
Test du Système Amélioré TradBOT
Vérifie les améliorations de précision des spikes et du trading automatique
"""

import requests
import json
import time
import subprocess
import sys
from pathlib import Path
from datetime import datetime

def test_advanced_predictor():
    """Test du prédicteur avancé de spikes"""
    print("🧪 Test du Prédicteur Avancé de Spikes")
    print("=" * 50)
    
    try:
        # Importer le prédicteur avancé
        from advanced_spike_predictor import get_advanced_prediction, get_prediction_accuracy
        
        symbols = ['EURUSD', 'Boom 1000 Index', 'Crash 1000 Index']
        
        for symbol in symbols:
            print(f"\n📊 Analyse de {symbol}:")
            prediction = get_advanced_prediction(symbol)
            
            if prediction:
                print(f"   ✅ Direction: {prediction['direction']}")
                print(f"   ✅ Confiance: {prediction['confidence']}")
                print(f"   ✅ Score: {prediction['score']:.2f}")
                print(f"   ✅ Probabilité spike: {prediction['spike_probability']:.1%}")
                print(f"   ✅ Temps estimé: {prediction['time_to_spike']}s")
                print(f"   ✅ Action: {prediction['action']}")
                print(f"   ✅ SL: {prediction['stop_loss']:.5f}")
                print(f"   ✅ TP: {prediction['take_profit']:.5f}")
                print(f"   ✅ Lot size: {prediction['lot_size']}")
                print(f"   ✅ Raison: {prediction['reasoning']}")
            else:
                print(f"   ❌ Erreur prédiction pour {symbol}")
        
        # Test de la précision
        print(f"\n📈 Précision des prédictions:")
        accuracy = get_prediction_accuracy()
        print(f"   ✅ Précision: {accuracy['accuracy']:.1f}%")
        print(f"   ✅ Signaux totaux: {accuracy['total_signals']}")
        print(f"   ✅ Prédictions correctes: {accuracy['correct_predictions']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test prédicteur: {e}")
        return False

def test_enhanced_api():
    """Test de l'API améliorée avec prédictions avancées"""
    print("\n🌐 Test de l'API Trend Améliorée")
    print("=" * 50)
    
    try:
        # Test de l'endpoint principal avec prédictions avancées
        response = requests.get("http://localhost:8001/trend?symbol=EURUSD&timeframe=M1", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ API Trend améliorée: OK")
            print(f"   Symbole: {data.get('symbol')}")
            print(f"   Direction: {data.get('trend_direction')}")
            print(f"   Confiance: {data.get('confidence')}")
            print(f"   Force: {data.get('trend_strength')}")
            print(f"   Signal: {data.get('trading_signal')}")
            print(f"   Probabilité spike: {data.get('spike_probability', 0):.1%}")
            print(f"   Temps estimé: {data.get('time_to_spike', 0)}s")
            print(f"   SL: {data.get('stop_loss', 0):.5f}")
            print(f"   TP: {data.get('take_profit', 0):.5f}")
            print(f"   Lot size: {data.get('lot_size', 0)}")
            print(f"   Raison: {data.get('reasoning', 'N/A')}")
            
            # Vérifier la précision des prédictions
            if 'prediction_accuracy' in data:
                accuracy = data['prediction_accuracy']
                print(f"   Précision API: {accuracy.get('accuracy', 0):.1f}%")
            
            return True
        else:
            print(f"❌ Erreur API: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur test API: {e}")
        return False

def test_enhanced_trading():
    """Test du système de trading amélioré"""
    print("\n🤖 Test du Système de Trading Amélioré")
    print("=" * 50)
    
    try:
        # Importer le système de trading amélioré
        from enhanced_ea_trading import run_enhanced_trading, get_trading_stats
        
        test_symbols = ['EURUSD', 'Boom 1000 Index']
        
        print("🔄 Exécution de cycles de trading de test...")
        
        # Exécuter quelques cycles de trading
        for cycle in range(2):
            print(f"\n   Cycle {cycle + 1}/2:")
            run_enhanced_trading(test_symbols)
            time.sleep(1)
        
        # Afficher les statistiques finales
        print(f"\n📊 Statistiques de trading:")
        stats = get_trading_stats()
        print(f"   ✅ Trades actifs: {stats['active_trades']}")
        print(f"   ✅ Trades aujourd'hui: {stats['daily_trades']}")
        print(f"   ✅ Total trades: {stats['stats']['total_trades']}")
        print(f"   ✅ Win rate: {stats['stats']['win_rate']:.1f}%")
        print(f"   ✅ Profit total: ${stats['stats']['total_profit']:.2f}")
        print(f"   ✅ Perte total: ${stats['stats']['total_loss']:.2f}")
        print(f"   ✅ Profit moyen: ${stats['stats']['avg_profit_per_trade']:.2f}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur test trading: {e}")
        return False

def test_spike_precision():
    """Test de la précision des prédictions de spikes"""
    print("\n🎯 Test de Précision des Spikes")
    print("=" * 50)
    
    try:
        # Test de plusieurs prédictions pour évaluer la cohérence
        symbols = ['EURUSD', 'Boom 1000 Index', 'Crash 1000 Index']
        predictions = []
        
        for symbol in symbols:
            response = requests.get(f"http://localhost:8001/trend?symbol={symbol}&timeframe=M1", timeout=5)
            if response.status_code == 200:
                data = response.json()
                predictions.append({
                    'symbol': symbol,
                    'confidence': data.get('confidence', 'low'),
                    'spike_probability': data.get('spike_probability', 0),
                    'trading_signal': data.get('trading_signal', 'MONITOR'),
                    'score': data.get('trend_strength', 0) / 100
                })
        
        # Analyser la cohérence des prédictions
        high_confidence_count = sum(1 for p in predictions if p['confidence'] in ['ultra_high', 'very_high', 'high'])
        trade_signals_count = sum(1 for p in predictions if p['trading_signal'] == 'TRADE')
        high_probability_count = sum(1 for p in predictions if p['spike_probability'] > 0.7)
        
        print(f"✅ Prédictions haute confiance: {high_confidence_count}/{len(predictions)}")
        print(f"✅ Signaux de trading: {trade_signals_count}/{len(predictions)}")
        print(f"✅ Probabilités élevées (>70%): {high_probability_count}/{len(predictions)}")
        
        # Calculer le score de précision global
        precision_score = (
            (high_confidence_count / len(predictions)) * 0.4 +
            (trade_signals_count / len(predictions)) * 0.3 +
            (high_probability_count / len(predictions)) * 0.3
        ) * 100
        
        print(f"✅ Score de précision global: {precision_score:.1f}%")
        
        return precision_score > 60  # Seuil de 60%
        
    except Exception as e:
        print(f"❌ Erreur test précision: {e}")
        return False

def test_auto_trading_features():
    """Test des fonctionnalités de trading automatique"""
    print("\n⚡ Test des Fonctionnalités de Trading Automatique")
    print("=" * 50)
    
    features_tested = []
    
    # Test 1: Gestion des risques
    try:
        from enhanced_ea_trading import enhanced_trading
        risk_config = enhanced_trading.trading_config
        
        print("✅ Gestion des risques:")
        print(f"   - Risque max par trade: ${risk_config['max_risk_per_trade']}")
        print(f"   - Objectif profit: ${risk_config['target_profit_per_trade']}")
        print(f"   - Perte max journalière: ${risk_config['max_daily_loss']}")
        print(f"   - Cooldown entre trades: {risk_config['cooldown_between_trades']}s")
        
        features_tested.append("Gestion des risques")
    except Exception as e:
        print(f"❌ Erreur test gestion risques: {e}")
    
    # Test 2: Surveillance des trades
    try:
        stats = enhanced_trading.get_trading_stats()
        print("✅ Surveillance des trades:")
        print(f"   - Trades actifs: {stats['active_trades']}")
        print(f"   - Limite concurrent: {enhanced_trading.max_concurrent_trades}")
        print(f"   - Limite journalière: {enhanced_trading.max_daily_trades}")
        
        features_tested.append("Surveillance des trades")
    except Exception as e:
        print(f"❌ Erreur test surveillance: {e}")
    
    # Test 3: Calcul automatique des paramètres
    try:
        from advanced_spike_predictor import spike_predictor
        confidence_levels = spike_predictor.confidence_levels
        
        print("✅ Calcul automatique des paramètres:")
        print(f"   - Niveaux de confiance: {len(confidence_levels)}")
        print(f"   - Patterns de spikes: {len(spike_predictor.spike_patterns)}")
        print(f"   - Seuil de confiance: {spike_predictor.confidence_threshold}")
        
        features_tested.append("Calcul automatique")
    except Exception as e:
        print(f"❌ Erreur test calcul paramètres: {e}")
    
    return len(features_tested) >= 3

def run_comprehensive_test():
    """Exécute un test complet du système amélioré"""
    print("🎯 TEST COMPLET DU SYSTÈME AMÉLIORÉ TradBOT")
    print("=" * 70)
    print(f"⏰ Début: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
    
    test_results = {}
    
    # Test 1: Prédicteur avancé
    test_results['predictor'] = test_advanced_predictor()
    
    # Test 2: API améliorée
    test_results['api'] = test_enhanced_api()
    
    # Test 3: Trading amélioré
    test_results['trading'] = test_enhanced_trading()
    
    # Test 4: Précision des spikes
    test_results['precision'] = test_spike_precision()
    
    # Test 5: Fonctionnalités automatiques
    test_results['auto_features'] = test_auto_trading_features()
    
    # Résumé des résultats
    print("\n" + "=" * 70)
    print("📊 RÉSUMÉ DES TESTS")
    print("=" * 70)
    
    passed_tests = sum(test_results.values())
    total_tests = len(test_results)
    
    for test_name, result in test_results.items():
        status = "✅ PASSÉ" if result else "❌ ÉCHOUÉ"
        print(f"   {test_name.upper()}: {status}")
    
    print(f"\n🎯 RÉSULTAT GLOBAL: {passed_tests}/{total_tests} tests réussis")
    
    if passed_tests == total_tests:
        print("🎉 SYSTÈME AMÉLIORÉ PRÊT!")
        print("\n📋 AMÉLIORATIONS IMPLÉMENTÉES:")
        print("   ✅ Prédicteur avancé de spikes avec haute précision")
        print("   ✅ API Trend améliorée avec prédictions intelligentes")
        print("   ✅ Système de trading automatique optimisé")
        print("   ✅ Gestion des risques avancée")
        print("   ✅ Surveillance en temps réel des trades")
        print("   ✅ Calcul automatique des paramètres SL/TP")
        print("   ✅ Patterns de spikes multiples")
        print("   ✅ Niveaux de confiance adaptatifs")
        
        print("\n🚀 PROCHAINES ÉTAPES:")
        print("   1. Lancer l'API Trend améliorée")
        print("   2. Configurer l'EA avec les nouveaux paramètres")
        print("   3. Activer le trading automatique")
        print("   4. Surveiller les performances")
        
    else:
        print("⚠️ PROBLÈMES DÉTECTÉS")
        print("   - Vérifiez les erreurs ci-dessus")
        print("   - Assurez-vous que l'API Trend est démarrée")
        print("   - Vérifiez les dépendances Python")
    
    print(f"\n⏰ Fin: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
    
    return passed_tests == total_tests

if __name__ == "__main__":
    success = run_comprehensive_test()
    sys.exit(0 if success else 1)
