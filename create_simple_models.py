"""
Script simple pour créer des modèles ML de base
"""

import os
import sys
import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler

# Ajouter le chemin du projet
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def create_simple_models():
    """
    Créer des modèles ML simples pré-entraînés
    """
    print("🚀 Création de modèles ML simples...")
    
    # Créer le dossier models s'il n'existe pas
    os.makedirs("models", exist_ok=True)
    
    # Créer des modèles simples pour chaque target
    targets = ['target_direction', 'target_amplitude', 'target_spike', 'target_breakout']
    
    for target in targets:
        print(f"📊 Création du modèle pour {target}...")
        
        # Créer un modèle simple
        model = RandomForestClassifier(
            n_estimators=10,  # Très simple
            max_depth=3,
            random_state=42
        )
        
        # Créer un scaler simple
        scaler = StandardScaler()
        
        # Créer des données factices pour l'entraînement
        X_dummy = np.random.randn(100, 47)  # 47 features
        y_dummy = np.random.randint(0, 2, 100)  # Classes binaires
        
        # Entraîner rapidement
        scaler.fit(X_dummy)
        X_scaled = scaler.transform(X_dummy)
        model.fit(X_scaled, y_dummy)
        
        # Sauvegarder
        joblib.dump(model, f"models/model_{target}.pkl")
        joblib.dump(scaler, f"models/scaler_{target}.pkl")
        
        print(f"✅ Modèle {target} créé et sauvegardé")
    
    # Créer un fichier de feature importance factice
    feature_names = [
        'volatility_10', 'volatility_20', 'volatility_ratio',
        'rsi_14', 'rsi_21', 'macd', 'macd_signal', 'macd_hist',
        'sma_6', 'sma_21', 'ema_8', 'ma_cross', 'ma_distance',
        'donchian_high', 'donchian_low', 'donchian_mid', 'donchian_position',
        'bb_upper', 'bb_middle', 'bb_lower', 'bb_width', 'bb_position',
        'stoch_k', 'stoch_d', 'stoch_oversold', 'stoch_overbought',
        'price_change', 'price_change_abs', 'volume_ratio',
        'hour', 'minute', 'day_of_week',
        'return_1', 'return_2', 'return_3', 'return_5',
        'spike_threshold', 'is_spike', 'spike_direction',
        'resistance', 'support', 'near_resistance', 'near_support',
        'price_momentum', 'rsi_momentum', 'divergence'
    ]
    
    feature_importance = {}
    for target in targets:
        feature_importance[target] = dict(zip(feature_names, np.random.rand(len(feature_names))))
    
    joblib.dump(feature_importance, "models/feature_importance.pkl")
    
    print("\n🎉 Modèles ML simples créés avec succès!")
    print("Les modèles sont maintenant disponibles dans le dossier 'models/'")

if __name__ == "__main__":
    create_simple_models()
