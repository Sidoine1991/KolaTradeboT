"""
Script de test pour le pipeline automatisé ML.
Teste le téléchargement, l'EDA et l'entraînement sur quelques symboles.
"""

import sys
import os
sys.path.append(os.path.abspath('.'))

from backend.automated_ml_pipeline import AutomatedMLPipeline
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def test_pipeline():
    """Test du pipeline automatisé."""
    print("🚀 Test du pipeline automatisé ML")
    print("=" * 50)
    
    try:
        # Initialisation du pipeline
        pipeline = AutomatedMLPipeline()
        print(f"✅ Pipeline initialisé avec {len(pipeline.symbols)} symboles disponibles")
        
        # Test sur quelques symboles
        test_symbols = ['EURUSD', 'GBPUSD', 'USDJPY']
        print(f"🎯 Test sur {len(test_symbols)} symboles: {test_symbols}")
        
        # Exécution du pipeline
        results = pipeline.run_pipeline_for_all_symbols(test_symbols)
        
        # Affichage des résultats
        print("\n📊 Résultats du pipeline:")
        print(f"   Total: {results['total_symbols']}")
        print(f"   Succès: {results['successful']}")
        print(f"   Échecs: {results['failed']}")
        print(f"   Taux de succès: {results['success_rate']:.1f}%")
        
        # Détails par symbole
        for symbol, result in results['results'].items():
            print(f"\n🔍 {symbol}:")
            if result.get('status') == 'success':
                print(f"   ✅ Succès")
                print(f"   📈 Modèle: {result['training_results']['best_model_info']['best_model_name']}")
                print(f"   🎯 Précision: {result['training_results']['best_model_info']['best_performance']['accuracy']:.3f}")
            else:
                print(f"   ❌ Échec: {result.get('error', 'Erreur inconnue')}")
        
        return results
        
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        return None

def test_prediction_parameters():
    """Test de récupération des paramètres de prédiction."""
    print("\n🎯 Test des paramètres de prédiction")
    print("=" * 50)
    
    try:
        pipeline = AutomatedMLPipeline()
        
        for symbol in ['EURUSD', 'GBPUSD']:
            print(f"\n📊 Paramètres pour {symbol}:")
            params = pipeline.get_prediction_parameters(symbol)
            
            if 'error' in params:
                print(f"   ❌ {params['error']}")
            else:
                print(f"   ✅ Modèle chargé: {params['model_name']}")
                print(f"   📈 Précision: {params['accuracy']:.3f}")
                print(f"   ⚙️ Paramètres SL/TP:")
                for signal_type, signal_params in params['parameters'].items():
                    print(f"      {signal_type}:")
                    print(f"        SL: {signal_params['stop_loss_pct']:.1f}%")
                    print(f"        TP: {signal_params['take_profit_pct']:.1f}%")
                    print(f"        Durée: {signal_params['signal_duration_hours']}h")
                    print(f"        Confiance: {signal_params['confidence_threshold']:.1f}")
        
    except Exception as e:
        print(f"❌ Erreur lors du test des paramètres: {e}")

if __name__ == "__main__":
    print("🧪 Tests du pipeline automatisé ML")
    print("=" * 60)
    
    # Test principal
    results = test_pipeline()
    
    if results and results['successful'] > 0:
        # Test des paramètres de prédiction
        test_prediction_parameters()
    
    print("\n�� Tests terminés!")
