#!/usr/bin/env python3
"""
Script d'entraînement du modèle XGBoost pour Boom 1000 Index
Prédit la direction (hausse/baisse) sur la prochaine bougie M1
"""

import sys
import os
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

# Ajouter le chemin du projet pour les imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from mt5_connector import connect, get_ohlc, is_connected
    print("✅ Imports backend réussis")
except ImportError as e:
    print(f"❌ Erreur import backend: {e}")
    sys.exit(1)

# Imports pour le ML
try:
    import xgboost as xgb
    from sklearn.model_selection import train_test_split, cross_val_score
    from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
    from sklearn.preprocessing import StandardScaler
    import joblib
    print("✅ Imports ML réussis")
except ImportError as e:
    print(f"❌ Erreur import ML: {e}")
    print("💡 Installez les dépendances: pip install xgboost scikit-learn joblib")
    sys.exit(1)

def create_features(df):
    """
    Crée les features techniques pour la prédiction
    """
    print("🔧 Création des features techniques...")
    
    # Copie du DataFrame
    df_features = df.copy()
    
    # 1. RENDEMENTS (Returns)
    df_features['return'] = df_features['close'].pct_change()
    df_features['return_1'] = df_features['return'].shift(1)
    df_features['return_2'] = df_features['return'].shift(2)
    df_features['return_3'] = df_features['return'].shift(3)
    
    # 2. VOLATILITÉ
    df_features['volatility'] = df_features['return'].rolling(window=20).std()
    df_features['volatility_5'] = df_features['return'].rolling(window=5).std()
    df_features['volatility_10'] = df_features['return'].rolling(window=10).std()
    
    # 3. MOYENNES MOBILES
    df_features['ma_5'] = df_features['close'].rolling(window=5).mean()
    df_features['ma_10'] = df_features['close'].rolling(window=10).mean()
    df_features['ma_20'] = df_features['close'].rolling(window=20).mean()
    df_features['ma_50'] = df_features['close'].rolling(window=50).mean()
    
    # 4. RATIOS DE MOYENNES MOBILES
    df_features['ma_ratio_5_20'] = df_features['ma_5'] / df_features['ma_20']
    df_features['ma_ratio_10_50'] = df_features['ma_10'] / df_features['ma_50']
    
    # 5. RSI
    delta = df_features['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    df_features['rsi'] = 100 - (100 / (1 + rs))
    
    # 6. MACD
    ema_12 = df_features['close'].ewm(span=12).mean()
    ema_26 = df_features['close'].ewm(span=26).mean()
    df_features['macd'] = ema_12 - ema_26
    df_features['macd_signal'] = df_features['macd'].ewm(span=9).mean()
    df_features['macd_histogram'] = df_features['macd'] - df_features['macd_signal']
    
    # 7. BANDES DE BOLLINGER
    df_features['bb_middle'] = df_features['close'].rolling(window=20).mean()
    bb_std = df_features['close'].rolling(window=20).std()
    df_features['bb_upper'] = df_features['bb_middle'] + (bb_std * 2)
    df_features['bb_lower'] = df_features['bb_middle'] - (bb_std * 2)
    df_features['bb_position'] = (df_features['close'] - df_features['bb_lower']) / (df_features['bb_upper'] - df_features['bb_lower'])
    
    # 8. ATR (Average True Range)
    high_low = df_features['high'] - df_features['low']
    high_close = np.abs(df_features['high'] - df_features['close'].shift())
    low_close = np.abs(df_features['low'] - df_features['close'].shift())
    true_range = np.maximum(high_low, np.maximum(high_close, low_close))
    df_features['atr'] = true_range.rolling(window=14).mean()
    
    # 9. VOLUME (si disponible)
    if 'tick_volume' in df_features.columns:
        df_features['volume_ma'] = df_features['tick_volume'].rolling(window=20).mean()
        df_features['volume_ratio'] = df_features['tick_volume'] / df_features['volume_ma']
    else:
        df_features['volume_ma'] = 1000  # Valeur par défaut
        df_features['volume_ratio'] = 1.0
    
    # 10. FEATURES DE PRIX
    df_features['price_range'] = (df_features['high'] - df_features['low']) / df_features['close']
    df_features['body_size'] = abs(df_features['close'] - df_features['open']) / df_features['close']
    df_features['upper_shadow'] = (df_features['high'] - np.maximum(df_features['open'], df_features['close'])) / df_features['close']
    df_features['lower_shadow'] = (np.minimum(df_features['open'], df_features['close']) - df_features['low']) / df_features['close']
    
    # 11. FEATURES TEMPORELLES
    df_features['hour'] = df_features['timestamp'].dt.hour
    df_features['minute'] = df_features['timestamp'].dt.minute
    df_features['day_of_week'] = df_features['timestamp'].dt.dayofweek
    
    # 12. MOMENTUM
    df_features['momentum_5'] = df_features['close'] / df_features['close'].shift(5) - 1
    df_features['momentum_10'] = df_features['close'] / df_features['close'].shift(10) - 1
    df_features['momentum_20'] = df_features['close'] / df_features['close'].shift(20) - 1
    
    print(f"✅ {len(df_features.columns)} features créées")
    return df_features

def create_target(df):
    """
    Crée la variable cible : 1 si le prix monte à la prochaine bougie, 0 sinon
    """
    print("🎯 Création de la variable cible...")
    
    # Prédire la direction sur la prochaine bougie
    df['target'] = (df['close'].shift(-1) > df['close']).astype(int)
    
    # Supprimer la dernière ligne (pas de target disponible)
    df = df[:-1]
    
    print(f"✅ Target créée - Distribution: {df['target'].value_counts().to_dict()}")
    return df

def prepare_data(df):
    """
    Prépare les données pour l'entraînement
    """
    print("📊 Préparation des données...")
    
    # Features à utiliser pour l'entraînement
    feature_columns = [
        'return', 'return_1', 'return_2', 'return_3',
        'volatility', 'volatility_5', 'volatility_10',
        'ma_5', 'ma_10', 'ma_20', 'ma_50',
        'ma_ratio_5_20', 'ma_ratio_10_50',
        'rsi', 'macd', 'macd_signal', 'macd_histogram',
        'bb_position', 'atr', 'volume_ratio',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow',
        'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20'
    ]
    
    # Vérifier que toutes les features existent
    missing_features = [col for col in feature_columns if col not in df.columns]
    if missing_features:
        print(f"⚠️ Features manquantes: {missing_features}")
        # Supprimer les features manquantes
        feature_columns = [col for col in feature_columns if col in df.columns]
    
    # Sélectionner les features et la target
    X = df[feature_columns].copy()
    y = df['target'].copy()
    
    # Supprimer les lignes avec des valeurs manquantes
    mask = ~(X.isnull().any(axis=1) | y.isnull())
    X = X[mask]
    y = y[mask]
    
    print(f"✅ Données préparées: {X.shape[0]} échantillons, {X.shape[1]} features")
    print(f"📈 Distribution target: {y.value_counts().to_dict()}")
    
    return X, y

def train_xgboost_model(X, y):
    """
    Entraîne le modèle XGBoost
    """
    print("🤖 Entraînement du modèle XGBoost...")
    
    # Division train/test
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Standardisation des features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Paramètres XGBoost optimisés pour la classification binaire
    params = {
        'objective': 'binary:logistic',
        'eval_metric': 'logloss',
        'max_depth': 6,
        'learning_rate': 0.1,
        'n_estimators': 200,
        'subsample': 0.8,
        'colsample_bytree': 0.8,
        'random_state': 42,
        'n_jobs': -1
    }
    
    # Entraînement
    model = xgb.XGBClassifier(**params)
    model.fit(X_train_scaled, y_train)
    
    # Évaluation
    y_pred = model.predict(X_test_scaled)
    y_pred_proba = model.predict_proba(X_test_scaled)[:, 1]
    
    accuracy = accuracy_score(y_test, y_pred)
    
    print(f"✅ Modèle entraîné - Accuracy: {accuracy:.4f}")
    print("\n📊 Rapport de classification:")
    print(classification_report(y_test, y_pred))
    
    # Cross-validation
    cv_scores = cross_val_score(model, X_train_scaled, y_train, cv=5, scoring='accuracy')
    print(f"\n🔄 Cross-validation scores: {cv_scores}")
    print(f"📊 CV Mean: {cv_scores.mean():.4f} (+/- {cv_scores.std() * 2:.4f})")
    
    # Importance des features
    feature_importance = pd.DataFrame({
        'feature': X.columns,
        'importance': model.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print(f"\n🏆 Top 10 features importantes:")
    print(feature_importance.head(10))
    
    return model, scaler, feature_importance

def save_model(model, scaler, feature_importance, model_path):
    """
    Sauvegarde le modèle et les métadonnées
    """
    print(f"💾 Sauvegarde du modèle dans {model_path}...")
    
    # Créer le dossier si nécessaire
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    
    # Sauvegarder le modèle
    joblib.dump(model, model_path)
    
    # Sauvegarder le scaler
    scaler_path = model_path.replace('.pkl', '_scaler.pkl')
    joblib.dump(scaler, scaler_path)
    
    # Sauvegarder les métadonnées
    metadata = {
        'model_type': 'XGBoost',
        'target': 'direction_next_candle',
        'features': list(feature_importance['feature']),
        'feature_importance': feature_importance.to_dict('records'),
        'training_date': datetime.now().isoformat(),
        'model_path': model_path,
        'scaler_path': scaler_path
    }
    
    metadata_path = model_path.replace('.pkl', '_metadata.json')
    import json
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"✅ Modèle sauvegardé: {model_path}")
    print(f"✅ Scaler sauvegardé: {scaler_path}")
    print(f"✅ Métadonnées sauvegardées: {metadata_path}")

def main():
    """
    Fonction principale
    """
    print("🚀 Démarrage de l'entraînement du modèle Boom 1000 XGBoost")
    print("=" * 60)
    
    # 1. Connexion MT5
    print("\n🔌 Connexion à MT5...")
    try:
        if not is_connected():
            connect()
        if is_connected():
            print("✅ MT5 connecté")
        else:
            print("❌ Impossible de se connecter à MT5")
            return
    except Exception as e:
        print(f"❌ Erreur de connexion MT5: {e}")
        return
    
    # 2. Téléchargement des données
    print("\n📥 Téléchargement des données Boom 1000...")
    symbol = "Boom 1000 Index"
    timeframe = "1m"
    count = 10000  # 10 000 bougies M1
    
    try:
        df = get_ohlc(symbol, timeframe, count)
        if df is None or df.empty:
            print("❌ Aucune donnée récupérée")
            return
        
        print(f"✅ {len(df)} bougies récupérées pour {symbol}")
        print(f"📅 Période: {df['timestamp'].min()} à {df['timestamp'].max()}")
        
    except Exception as e:
        print(f"❌ Erreur lors du téléchargement: {e}")
        return
    
    # 3. Création des features
    print("\n🔧 Création des features...")
    try:
        df_features = create_features(df)
    except Exception as e:
        print(f"❌ Erreur lors de la création des features: {e}")
        return
    
    # 4. Création de la target
    print("\n🎯 Création de la target...")
    try:
        df_target = create_target(df_features)
    except Exception as e:
        print(f"❌ Erreur lors de la création de la target: {e}")
        return
    
    # 5. Préparation des données
    print("\n📊 Préparation des données...")
    try:
        X, y = prepare_data(df_target)
        if len(X) < 1000:
            print("⚠️ Peu de données disponibles pour l'entraînement")
            return
    except Exception as e:
        print(f"❌ Erreur lors de la préparation des données: {e}")
        return
    
    # 6. Entraînement du modèle
    print("\n🤖 Entraînement du modèle...")
    try:
        model, scaler, feature_importance = train_xgboost_model(X, y)
    except Exception as e:
        print(f"❌ Erreur lors de l'entraînement: {e}")
        return
    
    # 7. Sauvegarde du modèle
    print("\n💾 Sauvegarde du modèle...")
    model_path = os.path.join(os.path.dirname(__file__), 'boom1000_xgb_model.pkl')
    try:
        save_model(model, scaler, feature_importance, model_path)
    except Exception as e:
        print(f"❌ Erreur lors de la sauvegarde: {e}")
        return
    
    print("\n🎉 Entraînement terminé avec succès!")
    print("=" * 60)
    print(f"📁 Modèle sauvegardé: {model_path}")
    print("💡 Vous pouvez maintenant utiliser le modèle dans l'application Streamlit")

if __name__ == "__main__":
    main() 