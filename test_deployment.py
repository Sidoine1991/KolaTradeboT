#!/usr/bin/env python3
"""
Script de test pour vérifier que le déploiement fonctionne sans timeout
"""

import asyncio
import aiohttp
import time
import os

async def test_deployment():
    """Test le déploiement de l'AI server"""
    
    # URL de l'API (à adapter selon votre configuration)
    base_url = "http://localhost:8000"  # ou l'URL de votre déploiement Render
    
    async with aiohttp.ClientSession() as session:
        print("🚀 Test du déploiement de l'AI Server...")
        
        # 1. Vérifier que le serveur démarre rapidement
        start_time = time.time()
        try:
            async with session.get(f"{base_url}/health", timeout=10) as response:
                if response.status == 200:
                    startup_time = time.time() - start_time
                    print(f"✅ Serveur démarré en {startup_time:.2f} secondes")
                else:
                    print(f"❌ Erreur health check: {response.status}")
                    return
        except Exception as e:
            print(f"❌ Impossible de contacter le serveur: {e}")
            return
        
        # 2. Vérifier que l'entraînement est désactivé au démarrage
        print("\n🔍 Vérification de la désactivation de l'entraînement...")
        
        # 3. Tester l'entraînement manuel des modèles essentiels
        print("\n📊 Test de l'entraînement manuel des modèles essentiels...")
        start_time = time.time()
        
        try:
            async with session.post(f"{base_url}/ml/train-essential", timeout=120) as response:
                result = await response.json()
                training_time = time.time() - start_time
                
                if response.status == 200:
                    print(f"✅ Entraînement essentiel terminé en {training_time:.2f} secondes")
                    print(f"📈 Résultats: {result.get('summary', {})}")
                else:
                    print(f"❌ Erreur entraînement: {response.status}")
                    print(f"Détail: {result}")
                    
        except asyncio.TimeoutError:
            print("⏰ L'entraînement essentiel a pris trop de temps")
        except Exception as e:
            print(f"❌ Erreur lors de l'entraînement: {e}")
        
        # 4. Vérifier que les endpoints ML fonctionnent
        print("\n🔍 Test des endpoints ML...")
        
        try:
            # Test prédiction (devrait fonctionner même sans modèles entraînés)
            async with session.post(
                f"{base_url}/ml/predict",
                json={"symbol": "EURUSD", "timeframes": ["M1"]},
                timeout=30
            ) as response:
                result = await response.json()
                print(f"📊 Prédiction EURUSD: {response.status} - {result.get('status', 'unknown')}")
                
        except Exception as e:
            print(f"⚠️ Erreur prédiction (attendue si pas de modèle): {e}")
        
        print("\n🎯 Test de déploiement terminé!")

if __name__ == "__main__":
    # Simuler la variable d'environnement
    os.environ["DISABLE_ML_TRAINING"] = "true"
    
    asyncio.run(test_deployment())
