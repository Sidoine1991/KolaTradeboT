#!/usr/bin/env python3
"""
Test de prédiction des prix futurs sur 200 bougies
"""
import requests
import json

def test_prediction():
    """Test l'endpoint de prédiction"""
    
    # Récupérer le prix actuel depuis l'API
    try:
        symbol_response = requests.get(
            "https://kolatradebot.onrender.com/predict/Boom 300 Index",
            timeout=10
        )
        
        current_price = None
        if symbol_response.status_code == 200:
            symbol_data = symbol_response.json()
            prediction = symbol_data.get('prediction', {})
            current_price = prediction.get('price_target')  # Prix cible actuel
            
        if not current_price:
            current_price = 1980.0  # Valeur par défaut
        
    except:
        current_price = 1980.0  # Valeur par défaut
    
    # Test pour Boom 300 Index
    payload = {
        "symbol": "Boom 300 Index",
        "timeframe": "M1", 
        "periods": 200,
        "current_price": current_price
    }
    
    print("🔮 Test de prédiction des prix futurs")
    print("=" * 50)
    print(f"Symbole: {payload['symbol']}")
    print(f"Timeframe: {payload['timeframe']}")
    print(f"Périodes: {payload['periods']} bougies")
    print("=" * 50)
    
    try:
        response = requests.post(
            "https://kolatradebot.onrender.com/prediction",
            json=payload,
            timeout=30
        )
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Prédiction réussie!")
            print(f"Modèle utilisé: {data.get('model', 'Unknown')}")
            print(f"Confiance: {data.get('confidence', 0):.2f}")
            print(f"Prix actuel: {data.get('current_price', 'N/A')}")
            print(f"Prix prédit (200 bougies): {data.get('predicted_price', 'N/A')}")
            print(f"Tendance: {data.get('trend', 'N/A')}")
            
            # Afficher quelques prédictions si disponibles
            if 'predictions' in data and data['predictions']:
                print("\n📈 Prédictions détaillées:")
                predictions = data['predictions'][:10]  # Premiers 10 points
                for i, pred in enumerate(predictions):
                    print(f"  Bougie {i+1}: {pred}")
                
                if len(data['predictions']) > 10:
                    print(f"  ... et {len(data['predictions']) - 10} autres prédictions")
            
        else:
            print(f"❌ Erreur: {response.status_code}")
            print(f"Détail: {response.text}")
            
    except Exception as e:
        print(f"❌ Erreur de connexion: {e}")

if __name__ == "__main__":
    test_prediction()
