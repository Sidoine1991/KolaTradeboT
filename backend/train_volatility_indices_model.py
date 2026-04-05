#!/usr/bin/env python3
"""
Script d'entraînement spécialisé pour les indices de volatilité
Entraîne un modèle XGBoost sur tous les indices de volatilité disponibles
"""

import os
import sys
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, confusion_matrix
import xgboost as xgb
import warnings
warnings.filterwarnings('ignore')

# Ajouter le chemin du projet
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from mt5_connector import connect, get_ohlc, get_all_symbols_simple, shutdown
except ImportError:
    print("❌ Erreur: Impossible d'importer mt5_connector")
    sys.exit(1)

def get_volatility_indices(symbols_list):
    """Récupère tous les indices de volatilité"""
    volatility_indices = []
    
    for symbol in symbols_list:
        symbol_upper = symbol.upper()
        
        # Détecter les indices de volatilité
        if any(keyword in symbol_upper for keyword in [
            'VOLATILITY', 'VOL', 'V75', 'V100', 'V150', 'V200', 'V250', 'V300',
            'STEP', 'JUMP', 'RANGE BREAK', 'DEX', 'DRIFT', 'TREK', 'VOLSWITCH', 
            'SKEW', 'MULTI STEP', 'BOOM', 'CRASH'
        ]):
            # Exclure les symboles qui ne sont pas des indices de volatilité
            if not any(exclude in symbol_upper for exclude in ['USD', 'EUR', 'GBP', 'JPY', 'BTC', 'ETH']):
                volatility_indices.append(symbol)
    
    return volatility_indices

def create_volatility_features(df):
    """Crée des features spécialisées pour les indices de volatilité"""
    df_features = df.copy()
    
    # Features de base
    df_features['return'] = df_features['close'].pct_change()
    df_features['return_1'] = df_features['return'].shift(1)
    df_features['return_2'] = df_features['return'].shift(2)
    df_features['return_3'] = df_features['return'].shift(3)
    df_features['return_5'] = df_features['return'].shift(5)
    df_features['return_10'] = df_features['return'].shift(10)
    
    # Volatilité à différentes échelles
    df_features['volatility'] = df_features['return'].rolling(window=20).std()
    df_features['volatility_5'] = df_features['return'].rolling(window=5).std()
    df_features['volatility_10'] = df_features['return'].rolling(window=10).std()
    df_features['volatility_30'] = df_features['return'].rolling(window=30).std()
    df_features['volatility_50'] = df_features['return'].rolling(window=50).std()
    
    # Régime de volatilité
    df_features['volatility_regime'] = df_features['volatility'].rolling(50).mean()
    df_features['volatility_spike'] = df_features['volatility'] > df_features['volatility'].rolling(20).quantile(0.8)
    
    # Moyennes mobiles
    df_features['ma_5'] = df_features['close'].rolling(window=5).mean()
    df_features['ma_10'] = df_features['close'].rolling(window=10).mean()
    df_features['ma_20'] = df_features['close'].rolling(window=20).mean()
    df_features['ma_50'] = df_features['close'].rolling(window=50).mean()
    df_features['ma_100'] = df_features['close'].rolling(window=100).mean()
    
    # Ratios de moyennes mobiles
    df_features['ma_ratio_5_20'] = df_features['ma_5'] / df_features['ma_20']
    df_features['ma_ratio_10_50'] = df_features['ma_10'] / df_features['ma_50']
    df_features['ma_ratio_20_100'] = df_features['ma_20'] / df_features['ma_100']
    
    # RSI
    delta = df_features['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    df_features['rsi'] = 100 - (100 / (1 + rs))
    
    # MACD
    ema_12 = df_features['close'].ewm(span=12).mean()
    ema_26 = df_features['close'].ewm(span=26).mean()
    df_features['macd'] = ema_12 - ema_26
    df_features['macd_signal'] = df_features['macd'].ewm(span=9).mean()
    df_features['macd_histogram'] = df_features['macd'] - df_features['macd_signal']
    
    # Bollinger Bands
    df_features['bb_middle'] = df_features['close'].rolling(window=20).mean()
    bb_std = df_features['close'].rolling(window=20).std()
    df_features['bb_upper'] = df_features['bb_middle'] + (bb_std * 2)
    df_features['bb_lower'] = df_features['bb_middle'] - (bb_std * 2)
    df_features['bb_position'] = (df_features['close'] - df_features['bb_lower']) / (df_features['bb_upper'] - df_features['bb_lower'])
    df_features['bb_width'] = (df_features['bb_upper'] - df_features['bb_lower']) / df_features['bb_middle']
    
    # ATR
    high_low = df_features['high'] - df_features['low']
    high_close = np.abs(df_features['high'] - df_features['close'].shift())
    low_close = np.abs(df_features['low'] - df_features['close'].shift())
    true_range = np.maximum(high_low, np.maximum(high_close, low_close))
    df_features['atr'] = true_range.rolling(window=14).mean()
    df_features['atr_ratio'] = df_features['atr'] / df_features['close']
    
    # Volume (si disponible)
    if 'tick_volume' in df_features.columns:
        df_features['volume_ma'] = df_features['tick_volume'].rolling(window=20).mean()
        df_features['volume_ratio'] = df_features['tick_volume'] / df_features['volume_ma']
        df_features['volume_spike'] = df_features['tick_volume'] > df_features['tick_volume'].rolling(20).quantile(0.8)
    else:
        df_features['volume_ma'] = 1000
        df_features['volume_ratio'] = 1.0
        df_features['volume_spike'] = False
    
    # Features de prix spécifiques aux indices de volatilité
    df_features['price_range'] = (df_features['high'] - df_features['low']) / df_features['close']
    df_features['body_size'] = abs(df_features['close'] - df_features['open']) / df_features['close']
    df_features['upper_shadow'] = (df_features['high'] - np.maximum(df_features['open'], df_features['close'])) / df_features['close']
    df_features['lower_shadow'] = (np.minimum(df_features['open'], df_features['close']) - df_features['low']) / df_features['close']
    
    # Détection de spikes (crucial pour les indices de volatilité)
    df_features['spike_detection'] = (df_features['high'] - df_features['low']) / df_features['close'] > 0.05
    df_features['spike_intensity'] = (df_features['high'] - df_features['low']) / df_features['close']
    df_features['spike_frequency'] = df_features['spike_detection'].rolling(20).sum()
    
    # Features temporelles
    df_features['hour'] = df_features['timestamp'].dt.hour
    df_features['minute'] = df_features['timestamp'].dt.minute
    df_features['day_of_week'] = df_features['timestamp'].dt.dayofweek
    
    # Momentum
    df_features['momentum_5'] = df_features['close'] / df_features['close'].shift(5) - 1
    df_features['momentum_10'] = df_features['close'] / df_features['close'].shift(10) - 1
    df_features['momentum_20'] = df_features['close'] / df_features['close'].shift(20) - 1
    
    # Features de tendance
    df_features['trend_5'] = (df_features['close'] > df_features['close'].shift(5)).astype(int)
    df_features['trend_10'] = (df_features['close'] > df_features['close'].shift(10)).astype(int)
    df_features['trend_20'] = (df_features['close'] > df_features['close'].shift(20)).astype(int)
    
    # Features de volatilité avancées
    df_features['volatility_change'] = df_features['volatility'].pct_change()
    df_features['volatility_acceleration'] = df_features['volatility_change'].pct_change()
    df_features['high_volatility_period'] = df_features['volatility'] > df_features['volatility'].rolling(100).quantile(0.7)
    
    # Features de prix relatives
    df_features['price_vs_ma5'] = df_features['close'] / df_features['ma_5'] - 1
    df_features['price_vs_ma20'] = df_features['close'] / df_features['ma_20'] - 1
    df_features['price_vs_ma50'] = df_features['close'] / df_features['ma_50'] - 1
    
    return df_features

def prepare_volatility_training_data(symbols, timeframe='1m', candles_per_symbol=2000):
    """Prépare les données d'entraînement pour les indices de volatilité"""
    print(f"📊 Préparation des données pour {len(symbols)} indices de volatilité...")
    
    all_data = []
    
    for i, symbol in enumerate(symbols):
        try:
            print(f"  [{i+1}/{len(symbols)}] Récupération {symbol}...")
            
            # Récupérer les données OHLC
            df = get_ohlc(symbol, timeframe, candles_per_symbol)
            
            if df is not None and not df.empty and len(df) > 200:
                # Créer les features
                df_features = create_volatility_features(df)
                
                # Créer la target (direction du prochain mouvement)
                df_features['target'] = (df_features['close'].shift(-1) > df_features['close']).astype(int)
                
                # Ajouter l'identifiant du symbole
                df_features['symbol'] = symbol
                
                all_data.append(df_features)
                print(f"    ✅ {len(df_features)} bougies récupérées")
            else:
                print(f"    ⚠️ Données insuffisantes pour {symbol}")
                
        except Exception as e:
            print(f"    ❌ Erreur pour {symbol}: {e}")
            continue
    
    if not all_data:
        print("❌ Aucune donnée valide pour les indices de volatilité")
        return None, None, None
    
    # Combiner toutes les données
    combined_df = pd.concat(all_data, ignore_index=True)
    
    # Nettoyer les données
    combined_df = combined_df.dropna()
    
    if len(combined_df) < 5000:
        print(f"⚠️ Données insuffisantes: {len(combined_df)} échantillons")
        return None, None, None
    
    print(f"✅ {len(combined_df)} échantillons préparés")
    
    # Features pour indices de volatilité
    features = [
        'return', 'return_1', 'return_2', 'return_3', 'return_5', 'return_10',
        'volatility', 'volatility_5', 'volatility_10', 'volatility_30', 'volatility_50',
        'volatility_regime', 'volatility_spike', 'volatility_change', 'volatility_acceleration',
        'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_100',
        'ma_ratio_5_20', 'ma_ratio_10_50', 'ma_ratio_20_100',
        'rsi', 'macd', 'macd_signal', 'macd_histogram',
        'bb_position', 'bb_width', 'atr', 'atr_ratio',
        'volume_ratio', 'volume_spike',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow',
        'spike_detection', 'spike_intensity', 'spike_frequency',
        'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20',
        'trend_5', 'trend_10', 'trend_20',
        'high_volatility_period',
        'price_vs_ma5', 'price_vs_ma20', 'price_vs_ma50'
    ]
    
    # Filtrer les features disponibles
    available_features = [f for f in features if f in combined_df.columns]
    
    X = combined_df[available_features]
    y = combined_df['target']
    
    return X, y, available_features

def train_volatility_model(X, y, features_list):
    """Entraîne un modèle XGBoost spécialisé pour les indices de volatilité"""
    print("🤖 Entraînement du modèle pour indices de volatilité...")
    
    # Split train/test
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    # Standardisation
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Configuration XGBoost optimisée pour les indices de volatilité
    params = {
        'n_estimators': 300,
        'max_depth': 8,
        'learning_rate': 0.05,
        'subsample': 0.7,
        'colsample_bytree': 0.7,
        'random_state': 42,
        'eval_metric': 'logloss',
        'reg_alpha': 0.1,
        'reg_lambda': 1.0,
        'early_stopping_rounds': 30,
    }
    
    # Entraînement
    model = xgb.XGBClassifier(**params)
    model.fit(
        X_train_scaled, y_train,
        eval_set=[(X_test_scaled, y_test)],
        verbose=False,
    )
    
    # Évaluation
    y_pred = model.predict(X_test_scaled)
    y_pred_proba = model.predict_proba(X_test_scaled)[:, 1]
    
    print("📊 Évaluation du modèle indices de volatilité:")
    print(classification_report(y_test, y_pred))
    
    # Métriques importantes
    accuracy = (y_pred == y_test).mean()
    print(f"✅ Précision: {accuracy:.3f}")
    
    # Importance des features
    feature_importance = pd.DataFrame({
        'feature': features_list,
        'importance': model.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print("\n🔝 Top 10 features les plus importantes:")
    print(feature_importance.head(10))
    
    # Sauvegarder le modèle
    model_filename = "synthetic_indices_xgb_model.pkl"
    scaler_filename = "synthetic_indices_xgb_model_scaler.pkl"
    
    model_path = os.path.join(os.path.dirname(__file__), model_filename)
    scaler_path = os.path.join(os.path.dirname(__file__), scaler_filename)
    
    joblib.dump(model, model_path)
    joblib.dump(scaler, scaler_path)
    
    print(f"💾 Modèle sauvegardé: {model_path}")
    print(f"💾 Scaler sauvegardé: {scaler_path}")
    
    return model, scaler, accuracy, feature_importance

def main():
    """Fonction principale"""
    print("🚀 Démarrage de l'entraînement du modèle indices de volatilité...")
    
    # Connexion MT5
    try:
        connect()
        print("✅ Connexion MT5 établie")
    except Exception as e:
        print(f"❌ Erreur de connexion MT5: {e}")
        return
    
    try:
        # Récupérer tous les symboles
        print("📋 Récupération des symboles MT5...")
        all_symbols = get_all_symbols_simple()
        
        if not all_symbols:
            print("❌ Aucun symbole récupéré")
            return
        
        print(f"✅ {len(all_symbols)} symboles récupérés")
        
        # Filtrer les indices de volatilité
        volatility_indices = get_volatility_indices(all_symbols)
        
        if not volatility_indices:
            print("❌ Aucun indice de volatilité trouvé")
            return
        
        print(f"📈 {len(volatility_indices)} indices de volatilité trouvés:")
        for idx, symbol in enumerate(volatility_indices):
            print(f"  {idx+1}. {symbol}")
        
        # Préparer les données
        X, y, features = prepare_volatility_training_data(volatility_indices)
        
        if X is not None and y is not None:
            # Entraîner le modèle
            model, scaler, accuracy, feature_importance = train_volatility_model(X, y, features)
            
            print(f"\n{'='*50}")
            print("📊 RÉSUMÉ DE L'ENTRAÎNEMENT")
            print(f"{'='*50}")
            print(f"✅ Précision: {accuracy:.3f}")
            print(f"✅ Échantillons: {len(X):,}")
            print(f"✅ Features: {len(features)}")
            print(f"✅ Indices de volatilité: {len(volatility_indices)}")
            print(f"✅ Modèle sauvegardé: synthetic_indices_xgb_model.pkl")
            
            print("\n🎉 Entraînement terminé avec succès!")
            print("💡 Le modèle est maintenant prêt à être utilisé dans l'application Streamlit")
            
        else:
            print("❌ Impossible d'entraîner le modèle")
        
    except Exception as e:
        print(f"❌ Erreur lors de l'entraînement: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # Fermer la connexion MT5
        shutdown()
        print("🔌 Connexion MT5 fermée")

if __name__ == "__main__":
    main() 