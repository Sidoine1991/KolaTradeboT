#!/usr/bin/env python3
"""
Démonstration du Système Boom Rising Channel Predictor
Script de démonstration des fonctionnalités principales
"""

import time
import numpy as np
from datetime import datetime, timedelta
import json

def create_demo_data():
    """Crée des données de démonstration"""
    print("📊 Création de données de démonstration...")
    
    # Simulation d'un canal haussier sur Boom
    test_data = []
    base_price = 10000.0
    
    # Phase 1: Consolidation (20 bougies)
    for i in range(20):
        noise = np.random.normal(0, 0.3)
        price = base_price + noise
        test_data.append({
            'timestamp': time.time() - (100-i) * 60,
            'open': price,
            'high': price + abs(np.random.normal(0, 0.2)),
            'low': price - abs(np.random.normal(0, 0.2)),
            'close': price,
            'volume': np.random.randint(1000, 3000)
        })
    
    # Phase 2: Canal haussier (60 bougies)
    for i in range(20, 80):
        trend_factor = (i - 20) * 0.15  # Tendance haussière
        noise = np.random.normal(0, 0.4)
        price = base_price + trend_factor + noise
        
        test_data.append({
            'timestamp': time.time() - (100-i) * 60,
            'open': price,
            'high': price + abs(np.random.normal(0, 0.3)),
            'low': price - abs(np.random.normal(0, 0.3)),
            'close': price,
            'volume': np.random.randint(2000, 5000)
        })
    
    # Phase 3: Approche des EMAs (20 bougies)
    for i in range(80, 100):
        trend_factor = (i - 20) * 0.15
        noise = np.random.normal(0, 0.2)  # Moins de bruit
        price = base_price + trend_factor + noise
        
        test_data.append({
            'timestamp': time.time() - (100-i) * 60,
            'open': price,
            'high': price + abs(np.random.normal(0, 0.2)),
            'low': price - abs(np.random.normal(0, 0.2)),
            'close': price,
            'volume': np.random.randint(3000, 6000)
        })
    
    return test_data

def demo_prediction_system():
    """Démonstration du système de prédiction"""
    print("\n🎯 Démonstration du Système de Prédiction")
    print("=" * 50)
    
    try:
        from boom_rising_channel_predictor import (
            update_boom_data, 
            get_boom_prediction, 
            get_boom_summary,
            create_boom_chart
        )
        
        # Créer les données de démonstration
        demo_data = create_demo_data()
        print(f"✅ {len(demo_data)} bougies de démonstration créées")
        
        # Mettre à jour le système
        update_boom_data(demo_data)
        print("✅ Données mises à jour dans le système")
        
        # Obtenir une prédiction
        prediction = get_boom_prediction()
        print(f"\n📊 Prédiction générée:")
        print(f"   Action: {prediction.get('action', 'N/A')}")
        print(f"   Direction: {prediction.get('direction', 'N/A')}")
        print(f"   Confiance: {prediction.get('confidence', 0):.1%}")
        print(f"   Probabilité Spike: {prediction.get('spike_probability', 0):.1%}")
        print(f"   Temps Estimé: {prediction.get('time_to_spike', 0)}s")
        
        if prediction.get('action') != 'HOLD':
            print(f"   Prix Actuel: {prediction.get('current_price', 0):.2f}")
            print(f"   Stop Loss: {prediction.get('stop_loss', 0):.2f}")
            print(f"   Take Profit: {prediction.get('take_profit', 0):.2f}")
            print(f"   Proximité EMA: {prediction.get('ema_proximity', 'N/A')}")
            print(f"   Position Canal: {prediction.get('channel_position', 'N/A')}")
            print(f"   Raison: {prediction.get('reasoning', 'N/A')}")
        
        # Obtenir le résumé
        summary = get_boom_summary()
        print(f"\n📋 Résumé du système:")
        print(f"   Statut: {summary.get('status', 'N/A')}")
        print(f"   Prédictions totales: {summary.get('total_predictions', 0)}")
        print(f"   Canaux actifs: {summary.get('active_channels', 0)}")
        
        # Générer un graphique de démonstration
        print(f"\n📈 Génération du graphique de démonstration...")
        chart_path = "demo_boom_chart.png"
        result = create_boom_chart(chart_path)
        print(f"   {result}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la démonstration: {e}")
        return False

def demo_trading_system():
    """Démonstration du système de trading"""
    print("\n🤖 Démonstration du Système de Trading")
    print("=" * 50)
    
    try:
        from boom_trading_bot import get_boom_trading_status, get_boom_positions
        
        # Obtenir le statut du trading
        status = get_boom_trading_status()
        print(f"📊 Statut du trading:")
        print(f"   Trading activé: {status.get('trading_enabled', False)}")
        print(f"   Positions actives: {status.get('active_positions', 0)}")
        print(f"   Trades aujourd'hui: {status.get('daily_trades', 0)}")
        print(f"   Perte quotidienne: {status.get('daily_loss', 0):.2f}")
        print(f"   Solde compte: {status.get('account_balance', 0):.2f}")
        
        # Obtenir les positions
        positions = get_boom_positions()
        if positions:
            print(f"\n📋 Positions actives:")
            for i, pos in enumerate(positions, 1):
                print(f"   Position {i}:")
                print(f"      Ticket: {pos.get('ticket', 'N/A')}")
                print(f"      Type: {pos.get('type', 'N/A')}")
                print(f"      Volume: {pos.get('volume', 0):.2f}")
                print(f"      Prix entrée: {pos.get('entry_price', 0):.2f}")
                print(f"      Confiance: {pos.get('confidence', 0):.2f}")
                print(f"      EMA: {pos.get('ema_proximity', 'N/A')}")
                print(f"      Canal: {pos.get('channel_position', 'N/A')}")
        else:
            print(f"\n📭 Aucune position active")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la démonstration trading: {e}")
        return False

def demo_configuration():
    """Démonstration de la configuration"""
    print("\n🔧 Démonstration de la Configuration")
    print("=" * 50)
    
    try:
        from boom_config import get_config, save_config, load_config
        
        # Afficher les configurations principales
        boom_config = get_config('boom')
        print(f"📊 Configuration Boom:")
        print(f"   Symbole: {boom_config.get('symbol', 'N/A')}")
        print(f"   Timeframe: {boom_config.get('timeframe', 'N/A')}")
        print(f"   Bougies min: {boom_config.get('min_candles', 0)}")
        
        ema_config = get_config('ema')
        print(f"\n📈 Configuration EMA:")
        print(f"   Périodes: {ema_config.get('periods', [])}")
        print(f"   Seuil proximité: {ema_config.get('proximity_threshold', 0):.3f}")
        
        trading_config = get_config('trading')
        print(f"\n🤖 Configuration Trading:")
        print(f"   Max positions: {trading_config.get('max_positions', 0)}")
        print(f"   Taille position: {trading_config.get('position_size', 0):.2f}")
        print(f"   Confiance min: {trading_config.get('min_confidence', 0):.2f}")
        
        # Tester la sauvegarde/chargement
        print(f"\n💾 Test de sauvegarde/chargement...")
        if save_config('demo_config.json'):
            print("   ✅ Configuration sauvegardée")
        
        if load_config('demo_config.json'):
            print("   ✅ Configuration chargée")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la démonstration configuration: {e}")
        return False

def demo_performance():
    """Démonstration des performances"""
    print("\n⚡ Démonstration des Performances")
    print("=" * 50)
    
    try:
        from boom_rising_channel_predictor import update_boom_data, get_boom_prediction
        
        # Test de performance avec différentes tailles de données
        sizes = [50, 100, 200, 500]
        
        for size in sizes:
            print(f"\n📊 Test avec {size} bougies:")
            
            # Créer des données de test
            test_data = []
            base_price = 10000.0
            
            for i in range(size):
                trend_factor = i * 0.1
                noise = np.random.normal(0, 0.5)
                price = base_price + trend_factor + noise
                
                test_data.append({
                    'timestamp': time.time() - (size-i) * 60,
                    'open': price,
                    'high': price + abs(np.random.normal(0, 0.3)),
                    'low': price - abs(np.random.normal(0, 0.3)),
                    'close': price,
                    'volume': np.random.randint(1000, 5000)
                })
            
            # Mesurer le temps de traitement
            start_time = time.time()
            update_boom_data(test_data)
            prediction = get_boom_prediction()
            end_time = time.time()
            
            processing_time = end_time - start_time
            print(f"   Temps de traitement: {processing_time:.3f}s")
            print(f"   Prédiction: {prediction.get('action', 'N/A')}")
            
            if processing_time < 0.5:
                print("   ✅ Performance excellente")
            elif processing_time < 1.0:
                print("   ✅ Performance bonne")
            else:
                print("   ⚠️ Performance à améliorer")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de la démonstration performance: {e}")
        return False

def main():
    """Fonction principale de démonstration"""
    print("🚀 Démonstration du Système Boom Rising Channel Predictor")
    print("=" * 70)
    print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Exécuter les démonstrations
    demos = [
        ("Système de Prédiction", demo_prediction_system),
        ("Système de Trading", demo_trading_system),
        ("Configuration", demo_configuration),
        ("Performances", demo_performance)
    ]
    
    results = []
    
    for demo_name, demo_func in demos:
        try:
            result = demo_func()
            results.append((demo_name, result))
        except Exception as e:
            print(f"❌ Erreur critique dans {demo_name}: {e}")
            results.append((demo_name, False))
    
    # Résumé des démonstrations
    print("\n📊 Résumé des Démonstrations")
    print("=" * 40)
    
    passed = 0
    total = len(results)
    
    for demo_name, result in results:
        status = "✅ RÉUSSI" if result else "❌ ÉCHOUÉ"
        print(f"{demo_name:25} {status}")
        if result:
            passed += 1
    
    print(f"\nRésultat: {passed}/{total} démonstrations réussies")
    
    if passed == total:
        print("\n🎉 Toutes les démonstrations sont réussies!")
        print("✅ Le système est prêt pour la production")
        
        print("\n🚀 Prochaines étapes:")
        print("   1. Lancer le système complet: python launch_boom_system.py --mode full")
        print("   2. Ouvrir l'interface web: http://localhost:8501")
        print("   3. Configurer les paramètres selon vos besoins")
        print("   4. Surveiller les performances en temps réel")
        
    else:
        print("\n⚠️ Certaines démonstrations ont échoué")
        print("   Vérifiez les erreurs ci-dessus avant de continuer")
    
    print(f"\n📚 Documentation complète: README_BOOM_RISING_CHANNEL.md")
    print(f"🧪 Tests complets: python test_boom_system.py")
    print(f"⚡ Test rapide: python quick_test_boom.py")

if __name__ == "__main__":
    main()
