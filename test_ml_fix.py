#!/usr/bin/env python3
"""
Script de test pour vérifier que la correction du "Samples: 0" fonctionne
"""

import asyncio
import sys
import os
from datetime import datetime

# Ajouter le répertoire courant au path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

async def test_ml_trainer_fix():
    """Test le système ML avec données factices"""
    print("🧪 TEST DU SYSTÈME ML - CORRECTION 'SAMPLES: 0'")
    print("=" * 60)
    
    try:
        # Importer le trainer
        from integrated_ml_trainer import ml_trainer
        
        # Test 1: Récupération de données pour EURUSD
        print("\n📊 Test 1: Récupération données EURUSD...")
        df = await ml_trainer.fetch_training_data_simple("EURUSD", "M1", 100)
        
        if df is not None and len(df) > 0:
            print(f"✅ Succès: {len(df)} échantillons récupérés")
            print(f"📋 Colonnes: {list(df.columns)}")
            print(f"🎯 Target distribution: {df['target'].value_counts().to_dict()}")
        else:
            print("❌ Échec: Pas de données récupérées")
            return False
        
        # Test 2: Entraînement d'un modèle
        print("\n🧪 Test 2: Entraînement modèle...")
        result = ml_trainer.train_model_simple(df, "EURUSD", "M1")
        
        if result:
            print(f"✅ Modèle entraîné avec succès")
            print(f"📊 Métriques: {result.get('metrics', {})}")
            print(f"🎯 Accuracy: {result.get('metrics', {}).get('accuracy', 'N/A')}")
            print(f"📈 Samples: {result.get('training_samples', 'N/A')}")
        else:
            print("❌ Échec entraînement modèle")
            return False
        
        # Test 3: Vérification des métriques actuelles
        print("\n📊 Test 3: Métriques actuelles...")
        metrics = ml_trainer.get_current_metrics()
        print(f"✅ Status: {metrics.get('status')}")
        print(f"📈 Models count: {metrics.get('models_count')}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur pendant le test: {e}")
        import traceback
        traceback.print_exc()
        return False

async def test_ai_server_metrics():
    """Test l'endpoint /ml/metrics"""
    print("\n🌐 TEST ENDPOINT /ML/METRICS")
    print("=" * 40)
    
    try:
        import httpx
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "http://localhost:8000/ml/metrics?symbol=EURUSD&timeframe=M1",
                timeout=10.0
            )
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Response status: {response.status_code}")
                print(f"📊 Total samples: {data.get('total_samples', 'N/A')}")
                print(f"🎯 Accuracy: {data.get('accuracy', 'N/A')}")
                print(f"🤖 Model: {data.get('model_name', 'N/A')}")
                print(f"📈 Status: {data.get('status', 'N/A')}")
                
                # Vérifier qu'on n'a plus "Samples: 0"
                samples = int(data.get('total_samples', 0))
                if samples > 0:
                    print(f"✅ CORRECTION RÉUSSIE: Plus de 'Samples: 0' ({samples} échantillons)")
                    return True
                else:
                    print(f"❌ ÉCHEC: Encore 'Samples: 0'")
                    return False
            else:
                print(f"❌ Erreur HTTP: {response.status_code}")
                return False
                
    except Exception as e:
        print(f"❌ Erreur test endpoint: {e}")
        return False

async def main():
    """Fonction principale de test"""
    print("🚀 DÉMARRAGE DES TESTS DE CORRECTION")
    print(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    
    # Test 1: ML Trainer
    test1_success = await test_ml_trainer_fix()
    
    # Test 2: AI Server Metrics
    test2_success = await test_ai_server_metrics()
    
    # Résultats
    print("\n" + "=" * 60)
    print("📋 RÉSULTATS DES TESTS")
    print("=" * 60)
    print(f"ML Trainer: {'✅ SUCCÈS' if test1_success else '❌ ÉCHEC'}")
    print(f"AI Server: {'✅ SUCCÈS' if test2_success else '❌ ÉCHEC'}")
    
    if test1_success and test2_success:
        print("\n🎉 CORRECTION 'SAMPLES: 0' RÉUSSIE!")
        print("Le système ML affiche maintenant des échantillons > 0")
    else:
        print("\n⚠️ La correction nécessite encore des ajustements")
    
    return test1_success and test2_success

if __name__ == "__main__":
    asyncio.run(main())
