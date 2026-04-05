#!/usr/bin/env python3
"""
Script d'entraînement pour modèles XGBoost adaptatifs
Entraîne des modèles spécialisés pour différentes catégories de symboles MT5
"""

import sys
import os
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
    from backend.mt5_connector import connect, get_ohlc, get_all_symbols_simple, shutdown
except ImportError:
    print("❌ Erreur: Impossible d'importer backend.mt5_connector")
    sys.exit(1)

try:
    from backend.weltrade_symbols import is_weltrade_synth_index, normalize_broker_symbol
except ImportError:
    from weltrade_symbols import is_weltrade_synth_index, normalize_broker_symbol

def categorize_symbols(symbols_list):
    """Catégorise automatiquement les symboles MT5"""
    categories = {
        'SYNTHETIC_SPECIAL': [],    # Boom/Crash spécifiques
        'SYNTHETIC_GENERAL': [],    # Autres indices synthétiques
        'WELTRADE_SYNTH': [],       # Weltrade PAINX / GAIN / …
        'CRYPTO': [],
        'FOREX': [],
        'STOCKS': [],
        'UNIVERSAL': []             # Modèle universel
    }
    
    for symbol in symbols_list:
        symbol_upper = symbol.upper()
        
        # Boom/Crash spécifiques
        if "BOOM" in symbol_upper or "CRASH" in symbol_upper:
            categories['SYNTHETIC_SPECIAL'].append(symbol)
        elif is_weltrade_synth_index(symbol):
            categories['WELTRADE_SYNTH'].append(symbol)
        
        # Autres indices synthétiques
        elif any(keyword in symbol_upper for keyword in ['VOLATILITY', 'STEP', 'JUMP', 'RANGE BREAK', 'DEX', 'DRIFT', 'TREK', 'VOLSWITCH', 'SKEW', 'MULTI STEP']):
            categories['SYNTHETIC_GENERAL'].append(symbol)
        
        # Crypto
        elif any(crypto in symbol_upper for crypto in ['BTC', 'ETH', 'ADA', 'DOT', 'LNK', 'LTC', 'BCH', 'XRP', 'XLM', 'XMR', 'ZEC', 'XTZ', 'NEO', 'MKR', 'SOL', 'TRX', 'UNI', 'SHB', 'TON', 'FET', 'APT', 'COM', 'IMX', 'SAN', 'TRU', 'MLN', 'NER']):
            categories['CRYPTO'].append(symbol)
        
        # Forex (nom normalisé : EURUSD.pro → EURUSD)
        elif any(pair in normalize_broker_symbol(symbol) for pair in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD', 'SEK', 'NOK', 'PLN', 'ZAR', 'SGD', 'HKD', 'THB', 'MXN', 'CNH']):
            if 'INDEX' not in symbol_upper and 'BASKET' not in symbol_upper and 'DFX' not in symbol_upper:
                categories['FOREX'].append(symbol)
        
        # Actions
        elif any(stock in symbol_upper for stock in ['AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX', 'JPM', 'BAC', 'WMT', 'PG', 'JNJ', 'V', 'HD', 'MA', 'PYPL', 'DIS', 'CRM', 'NKE', 'PFE', 'KO', 'MCD', 'ABNB', 'UBER', 'ZM', 'AAL', 'DAL', 'GM', 'F', 'BA', 'IBM', 'INTC', 'CSCO', 'ORCL', 'ADBE', 'NFLX', 'AMD', 'BABA', 'AIG', 'GS', 'C', 'DBK', 'EBAY', 'FDX', 'FOX', 'HPQ', 'SONY', 'TEVA', 'AIR', 'AIRF', 'BAY', 'BMW', 'BIIB', 'CONG', 'ADS']):
            categories['STOCKS'].append(symbol)
        
        # Autres (pour modèle universel)
        else:
            categories['UNIVERSAL'].append(symbol)
    
    return categories

def create_adaptive_features(df, symbol_category):
    """Crée des features adaptatives selon la catégorie de symbole"""
    df_features = df.copy()
    
    # Features de base communes
    df_features['return'] = df_features['close'].pct_change()
    df_features['return_1'] = df_features['return'].shift(1)
    df_features['return_2'] = df_features['return'].shift(2)
    df_features['return_3'] = df_features['return'].shift(3)
    df_features['volatility'] = df_features['return'].rolling(window=20).std()
    df_features['volatility_5'] = df_features['return'].rolling(window=5).std()
    df_features['volatility_10'] = df_features['return'].rolling(window=10).std()
    
    # Moyennes mobiles
    df_features['ma_5'] = df_features['close'].rolling(window=5).mean()
    df_features['ma_10'] = df_features['close'].rolling(window=10).mean()
    df_features['ma_20'] = df_features['close'].rolling(window=20).mean()
    df_features['ma_50'] = df_features['close'].rolling(window=50).mean()
    df_features['ma_ratio_5_20'] = df_features['ma_5'] / df_features['ma_20']
    df_features['ma_ratio_10_50'] = df_features['ma_10'] / df_features['ma_50']
    
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
    
    # ATR
    high_low = df_features['high'] - df_features['low']
    high_close = np.abs(df_features['high'] - df_features['close'].shift())
    low_close = np.abs(df_features['low'] - df_features['close'].shift())
    true_range = np.maximum(high_low, np.maximum(high_close, low_close))
    df_features['atr'] = true_range.rolling(window=14).mean()
    
    # Volume (si disponible)
    if 'tick_volume' in df_features.columns:
        df_features['volume_ma'] = df_features['tick_volume'].rolling(window=20).mean()
        df_features['volume_ratio'] = df_features['tick_volume'] / df_features['volume_ma']
    else:
        df_features['volume_ma'] = 1000
        df_features['volume_ratio'] = 1.0
    
    # Features de prix
    df_features['price_range'] = (df_features['high'] - df_features['low']) / df_features['close']
    df_features['body_size'] = abs(df_features['close'] - df_features['open']) / df_features['close']
    df_features['upper_shadow'] = (df_features['high'] - np.maximum(df_features['open'], df_features['close'])) / df_features['close']
    df_features['lower_shadow'] = (np.minimum(df_features['open'], df_features['close']) - df_features['low']) / df_features['close']
    
    # Features temporelles
    df_features['hour'] = df_features['timestamp'].dt.hour
    df_features['minute'] = df_features['timestamp'].dt.minute
    df_features['day_of_week'] = df_features['timestamp'].dt.dayofweek
    
    # Momentum
    df_features['momentum_5'] = df_features['close'] / df_features['close'].shift(5) - 1
    df_features['momentum_10'] = df_features['close'] / df_features['close'].shift(10) - 1
    df_features['momentum_20'] = df_features['close'] / df_features['close'].shift(20) - 1
    
    # Features spécifiques par catégorie
    if symbol_category in ["SYNTHETIC_SPECIAL", "SYNTHETIC_GENERAL", "WELTRADE_SYNTH"]:
        # Features pour indices synthétiques
        df_features['spike_detection'] = (df_features['high'] - df_features['low']) / df_features['close'] > 0.05
        df_features['volatility_regime'] = df_features['volatility'].rolling(50).mean()
    elif symbol_category == "CRYPTO":
        # Features pour crypto
        df_features['crypto_volatility'] = df_features['volatility'] * 100  # Crypto plus volatile
        df_features['btc_correlation'] = 1.0  # Placeholder pour corrélation BTC
    elif symbol_category == "FOREX":
        # Features pour forex
        df_features['pip_movement'] = df_features['return'] * 10000  # Mouvement en pips
        df_features['spread_impact'] = 0.0001  # Placeholder pour impact du spread
    elif symbol_category == "STOCKS":
        # Features pour actions
        df_features['stock_volatility'] = df_features['volatility'] * 252  # Volatilité annualisée
        df_features['market_hours'] = ((df_features['hour'] >= 9) & (df_features['hour'] <= 16)).astype(int)
    
    return df_features

def prepare_training_data(symbols, category, timeframe='1m', candles_per_symbol=1000):
    """Prépare les données d'entraînement pour une catégorie"""
    print(f"📊 Préparation des données pour {category} ({len(symbols)} symboles)...")
    
    all_data = []
    
    for i, symbol in enumerate(symbols):
        try:
            print(f"  [{i+1}/{len(symbols)}] Récupération {symbol}...")
            
            # Récupérer les données OHLC
            df = get_ohlc(symbol, timeframe, candles_per_symbol)
            
            if df is not None and not df.empty and len(df) > 100:
                # Créer les features
                df_features = create_adaptive_features(df, category)
                
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
        print(f"❌ Aucune donnée valide pour {category}")
        return None, None
    
    # Combiner toutes les données
    combined_df = pd.concat(all_data, ignore_index=True)
    
    # Nettoyer les données
    combined_df = combined_df.dropna()
    
    if len(combined_df) < 1000:
        print(f"⚠️ Données insuffisantes pour {category}: {len(combined_df)} échantillons")
        return None, None
    
    print(f"✅ {len(combined_df)} échantillons préparés pour {category}")
    
    # Features communes
    common_features = [
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
    
    # Ajouter features spécifiques selon la catégorie
    if category in ["SYNTHETIC_SPECIAL", "SYNTHETIC_GENERAL", "WELTRADE_SYNTH"]:
        common_features.extend(['spike_detection', 'volatility_regime'])
    elif category == "CRYPTO":
        common_features.extend(['crypto_volatility', 'btc_correlation'])
    elif category == "FOREX":
        common_features.extend(['pip_movement', 'spread_impact'])
    elif category == "STOCKS":
        common_features.extend(['stock_volatility', 'market_hours'])
    
    # Filtrer les features disponibles
    available_features = [f for f in common_features if f in combined_df.columns]
    
    X = combined_df[available_features]
    y = combined_df['target']
    
    return X, y, available_features

def train_model(X, y, category, features_list):
    """Entraîne un modèle XGBoost pour une catégorie"""
    print(f"🤖 Entraînement du modèle pour {category}...")
    
    # Split train/test
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    # Standardisation
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Configuration XGBoost selon la catégorie
    if category in ["SYNTHETIC_SPECIAL", "SYNTHETIC_GENERAL", "WELTRADE_SYNTH"]:
        # Modèles pour indices synthétiques (plus de features de volatilité)
        params = {
            'n_estimators': 200,
            'max_depth': 6,
            'learning_rate': 0.1,
            'subsample': 0.8,
            'colsample_bytree': 0.8,
            'random_state': 42,
            'eval_metric': 'logloss'
        }
    elif category == "CRYPTO":
        # Modèles pour crypto (plus de features de volatilité)
        params = {
            'n_estimators': 300,
            'max_depth': 8,
            'learning_rate': 0.05,
            'subsample': 0.7,
            'colsample_bytree': 0.7,
            'random_state': 42,
            'eval_metric': 'logloss'
        }
    elif category == "FOREX":
        # Modèles pour forex (plus conservateurs)
        params = {
            'n_estimators': 150,
            'max_depth': 5,
            'learning_rate': 0.1,
            'subsample': 0.9,
            'colsample_bytree': 0.9,
            'random_state': 42,
            'eval_metric': 'logloss'
        }
    elif category == "STOCKS":
        # Modèles pour actions
        params = {
            'n_estimators': 200,
            'max_depth': 6,
            'learning_rate': 0.1,
            'subsample': 0.8,
            'colsample_bytree': 0.8,
            'random_state': 42,
            'eval_metric': 'logloss'
        }
    else:
        # Modèle universel
        params = {
            'n_estimators': 250,
            'max_depth': 7,
            'learning_rate': 0.1,
            'subsample': 0.8,
            'colsample_bytree': 0.8,
            'random_state': 42,
            'eval_metric': 'logloss'
        }
    
    # Entraînement
    params_fit = {**params, "early_stopping_rounds": 20}
    model = xgb.XGBClassifier(**params_fit)
    model.fit(
        X_train_scaled, y_train,
        eval_set=[(X_test_scaled, y_test)],
        verbose=False,
    )
    
    # Évaluation
    y_pred = model.predict(X_test_scaled)
    y_pred_proba = model.predict_proba(X_test_scaled)[:, 1]
    
    print(f"📊 Évaluation du modèle {category}:")
    print(classification_report(y_test, y_pred))
    
    # Métriques importantes
    accuracy = (y_pred == y_test).mean()
    print(f"✅ Précision: {accuracy:.3f}")
    
    # Sauvegarder le modèle
    model_filename = f"{category.lower()}_xgb_model.pkl"
    scaler_filename = f"{category.lower()}_xgb_model_scaler.pkl"
    
    model_path = os.path.join(os.path.dirname(__file__), model_filename)
    scaler_path = os.path.join(os.path.dirname(__file__), scaler_filename)
    
    joblib.dump(model, model_path)
    joblib.dump(scaler, scaler_path)
    
    print(f"💾 Modèle sauvegardé: {model_path}")
    print(f"💾 Scaler sauvegardé: {scaler_path}")
    
    return model, scaler, accuracy

def main():
    """Fonction principale"""
    print("🚀 Démarrage de l'entraînement des modèles adaptatifs...")
    
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
        
        # Catégoriser les symboles
        categories = categorize_symbols(all_symbols)
        
        print("\n📊 Répartition des symboles:")
        for category, symbols in categories.items():
            print(f"  {category}: {len(symbols)} symboles")
        
        # Entraîner les modèles pour chaque catégorie
        results = {}
        
        for category, symbols in categories.items():
            if len(symbols) < 5:  # Ignorer les catégories avec trop peu de symboles
                print(f"⚠️ Catégorie {category} ignorée (trop peu de symboles: {len(symbols)})")
                continue
            
            print(f"\n{'='*50}")
            print(f"🎯 ENTRAÎNEMENT {category}")
            print(f"{'='*50}")
            
            # Préparer les données
            X, y, features = prepare_training_data(symbols, category)
            
            if X is not None and y is not None:
                # Entraîner le modèle
                model, scaler, accuracy = train_model(X, y, category, features)
                results[category] = {
                    'accuracy': accuracy,
                    'n_samples': len(X),
                    'n_features': len(features),
                    'n_symbols': len(symbols)
                }
            else:
                print(f"❌ Impossible d'entraîner le modèle pour {category}")
        
        # Résumé final
        print(f"\n{'='*50}")
        print("📊 RÉSUMÉ DE L'ENTRAÎNEMENT")
        print(f"{'='*50}")
        
        for category, result in results.items():
            print(f"✅ {category}:")
            print(f"   Précision: {result['accuracy']:.3f}")
            print(f"   Échantillons: {result['n_samples']:,}")
            print(f"   Features: {result['n_features']}")
            print(f"   Symboles: {result['n_symbols']}")
            print()
        
        print("🎉 Entraînement terminé avec succès!")
        
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