"""
Script pour créer des modèles ML pré-entraînés avec des données de démonstration
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os
import sys

# Ajouter le chemin du projet
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from backend.advanced_ml_predictor import AdvancedMLPredictor

def generate_demo_data(symbol="Boom 1000 Index", days=7, timeframe="1m"):
    """
    Générer des données de démonstration pour l'entraînement des modèles
    """
    print(f"Génération de données de démonstration pour {symbol}...")
    
    # Créer un index de temps (réduire à 7 jours pour un entraînement plus rapide)
    end_time = datetime.now()
    start_time = end_time - timedelta(days=days)
    
    # Générer des timestamps (5 minutes par bougie pour réduire le nombre)
    timestamps = pd.date_range(start=start_time, end=end_time, freq='5min')
    
    # Paramètres de base selon le type d'indice
    if "Boom" in symbol:
        base_price = 10000
        volatility = 0.02
        trend_strength = 0.001
    elif "Crash" in symbol:
        base_price = 10000
        volatility = 0.02
        trend_strength = -0.001
    else:  # Volatility
        base_price = 5000
        volatility = 0.015
        trend_strength = 0.0005
    
    # Générer les prix avec des patterns réalistes
    np.random.seed(42)  # Pour la reproductibilité
    
    # Générer des retours avec tendance et volatilité
    returns = np.random.normal(trend_strength, volatility, len(timestamps))
    
    # Ajouter des spikes occasionnels
    spike_indices = np.random.choice(len(timestamps), size=len(timestamps)//50, replace=False)
    for idx in spike_indices:
        if "Boom" in symbol:
            returns[idx] += np.random.uniform(0.05, 0.15)  # Spike haussier
        elif "Crash" in symbol:
            returns[idx] -= np.random.uniform(0.05, 0.15)  # Spike baissier
        else:
            returns[idx] += np.random.uniform(-0.1, 0.1)  # Spike bidirectionnel
    
    # Calculer les prix
    prices = base_price * np.exp(np.cumsum(returns))
    
    # Créer le DataFrame OHLC
    data = []
    for i, (timestamp, price) in enumerate(zip(timestamps, prices)):
        # Générer OHLC réaliste
        high = price * (1 + abs(np.random.normal(0, 0.005)))
        low = price * (1 - abs(np.random.normal(0, 0.005)))
        open_price = prices[i-1] if i > 0 else price
        close_price = price
        volume = np.random.uniform(1000, 10000)
        
        data.append({
            'timestamp': timestamp,
            'open': open_price,
            'high': high,
            'low': low,
            'close': close_price,
            'volume': volume
        })
    
    df = pd.DataFrame(data)
    df.set_index('timestamp', inplace=True)
    
    print(f"✅ Généré {len(df)} bougies de données de démonstration")
    return df

def create_demo_models():
    """
    Créer des modèles de démonstration pour différents types d'indices
    """
    print("🚀 Création des modèles ML de démonstration...")
    
    # Créer le dossier models s'il n'existe pas
    os.makedirs("models", exist_ok=True)
    
    # Types d'indices à entraîner
    indices = [
        "Boom 1000 Index",
        "Crash 1000 Index", 
        "Volatility 75 Index"
    ]
    
    for symbol in indices:
        print(f"\n📊 Entraînement pour {symbol}...")
        
        # Générer les données de démonstration
        demo_data = generate_demo_data(symbol, days=7)  # 7 jours de données
        
        # Créer et entraîner le prédicteur
        predictor = AdvancedMLPredictor()
        
        try:
            # Entraîner les modèles
            predictor.train_models(demo_data)
            
            # Sauvegarder les modèles
            model_path = f"models/demo_{symbol.replace(' ', '_').lower()}"
            os.makedirs(model_path, exist_ok=True)
            
            # Sauvegarder avec un nom spécifique
            for target, model in predictor.models.items():
                import joblib
                joblib.dump(model, f"{model_path}/model_{target}.pkl")
            
            for target, scaler in predictor.scalers.items():
                import joblib
                joblib.dump(scaler, f"{model_path}/scaler_{target}.pkl")
            
            import joblib
            joblib.dump(predictor.feature_importance, f"{model_path}/feature_importance.pkl")
            
            print(f"✅ Modèles sauvegardés dans {model_path}")
            
        except Exception as e:
            print(f"❌ Erreur lors de l'entraînement pour {symbol}: {e}")
    
    print("\n🎉 Création des modèles de démonstration terminée!")
    print("Les modèles sont maintenant disponibles dans le dossier 'models/'")

if __name__ == "__main__":
    create_demo_models()
