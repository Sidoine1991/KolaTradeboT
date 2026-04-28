#!/usr/bin/env python3
"""
Script d'entraînement pour modèles adaptatifs XGBoost - Version limitée à 5 symboles
Entraîne des modèles spécialisés par catégorie avec un nombre limité de symboles
"""

import os
import sys
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

# Ajouter le répertoire parent au path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from backend.mt5_connector import connect, get_ohlc, get_all_symbols_simple, get_symbol_info
    from backend.advanced_technical_indicators import add_advanced_technical_indicators
except ImportError as e:
    print(f"Erreur d'import: {e}")
    sys.exit(1)

try:
    from backend.weltrade_symbols import is_weltrade_synth_index, normalize_broker_symbol
except ImportError:
    from weltrade_symbols import is_weltrade_synth_index, normalize_broker_symbol

import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import xgboost as xgb

def categorize_symbols(symbols_list):
    """Catégorise automatiquement les symboles MT5"""
    categories = {
        'SYNTHETIC_SPECIAL': [],  # Boom/Crash spécifiques
        'SYNTHETIC_GENERAL': [],  # Autres indices synthétiques
        'WELTRADE_SYNTH': [],
        'CRYPTO': [],
        'FOREX': [],
        'STOCKS': [],
        'UNIVERSAL': []
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
        
        # Forex
        elif any(pair in normalize_broker_symbol(symbol) for pair in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD', 'SEK', 'NOK', 'PLN', 'ZAR', 'SGD', 'HKD', 'THB', 'MXN', 'CNH']):
            if 'INDEX' not in symbol_upper and 'BASKET' not in symbol_upper:
                categories['FOREX'].append(symbol)
        
        # Actions
        elif any(stock in symbol_upper for stock in ['AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX', 'JPM', 'BAC', 'WMT', 'PG', 'JNJ', 'V', 'HD', 'MA', 'PYPL', 'DIS', 'CRM', 'NKE', 'PFE', 'KO', 'MCD', 'ABNB', 'UBER', 'ZM', 'AAL', 'DAL', 'GM', 'F', 'BA', 'IBM', 'INTC', 'CSCO', 'ORCL', 'ADBE', 'NFLX', 'AMD', 'BABA', 'AIG', 'GS', 'C', 'DBK', 'EBAY', 'FDX', 'FOX', 'HPQ', 'SONY', 'TEVA', 'AIR', 'AIRF', 'BAY', 'BMW', 'BIIB', 'CONG', 'ADS']):
            categories['STOCKS'].append(symbol)
        
        # Autres
        else:
            categories['UNIVERSAL'].append(symbol)
    
    return categories

def create_features(df, symbol_category):
    """Crée les features adaptatives selon la catégorie de symbole"""
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
        df_features['crypto_volatility'] = df_features['volatility'] * 100
        df_features['btc_correlation'] = 1.0  # Placeholder
    elif symbol_category == "FOREX":
        # Features pour forex
        df_features['pip_movement'] = df_features['return'] * 10000
        df_features['spread_impact'] = 0.0001  # Placeholder
    elif symbol_category == "STOCKS":
        # Features pour actions
        df_features['stock_volatility'] = df_features['volatility'] * 252
        df_features['market_hours'] = ((df_features['hour'] >= 9) & (df_features['hour'] <= 16)).astype(int)
    
    return df_features

def prepare_target(df, lookforward=5):
    """Prépare la variable cible (1 si hausse, 0 si baisse)"""
    future_returns = df['close'].shift(-lookforward) / df['close'] - 1
    target = (future_returns > 0).astype(int)
    return target

def train_model_for_category(category_name, symbols, category_type, max_symbols=5):
    """Entraîne un modèle pour une catégorie spécifique"""
    print(f"\n{'='*60}")
    print(f"🎯 ENTRAÎNEMENT MODÈLE: {category_name}")
    print(f"📊 Type: {category_type}")
    print(f"🔢 Symboles limités à: {max_symbols}")
    print(f"{'='*60}")
    
    # Limiter le nombre de symboles
    symbols = symbols[:max_symbols]
    print(f"📋 Symboles sélectionnés: {symbols}")
    
    all_data = []
    successful_symbols = []
    
    # Récupérer les données pour chaque symbole
    for i, symbol in enumerate(symbols, 1):
        print(f"\n📈 [{i}/{len(symbols)}] Récupération données pour {symbol}...")
        try:
            # Récupérer les données OHLC
            df = get_ohlc(symbol, "1m", 1000)  # 1000 bougies 1-minute
            
            if df is not None and not df.empty and len(df) > 100:
                # Ajouter les indicateurs techniques avancés
                try:
                    df = add_advanced_technical_indicators(df, ['sma', 'rsi', 'macd', 'bollinger', 'atr'])
                except Exception as e:
                    print(f"⚠️ Erreur indicateurs avancés pour {symbol}: {e}")
                
                # Créer les features
                df_features = create_features(df, category_type)
                
                # Préparer la cible
                target = prepare_target(df_features)
                
                # Combiner features et cible
                df_features['target'] = target
                
                # Supprimer les lignes avec NaN
                df_features = df_features.dropna()
                
                if len(df_features) > 50:  # Au moins 50 échantillons valides
                    all_data.append(df_features)
                    successful_symbols.append(symbol)
                    print(f"✅ {symbol}: {len(df_features)} échantillons valides")
                else:
                    print(f"❌ {symbol}: Données insuffisantes ({len(df_features)} échantillons)")
            else:
                print(f"❌ {symbol}: Aucune donnée ou données insuffisantes")
                
        except Exception as e:
            print(f"❌ Erreur pour {symbol}: {e}")
    
    if not all_data:
        print(f"❌ Aucune donnée valide pour la catégorie {category_name}")
        return None, None, None
    
    # Combiner toutes les données
    combined_df = pd.concat(all_data, ignore_index=True)
    print(f"\n📊 Données combinées: {len(combined_df)} échantillons")
    print(f"📈 Symboles réussis: {successful_symbols}")
    
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
    if category_type in ["SYNTHETIC_SPECIAL", "SYNTHETIC_GENERAL", "WELTRADE_SYNTH"]:
        common_features.extend(['spike_detection', 'volatility_regime'])
    elif category_type == "CRYPTO":
        common_features.extend(['crypto_volatility', 'btc_correlation'])
    elif category_type == "FOREX":
        common_features.extend(['pip_movement', 'spread_impact'])
    elif category_type == "STOCKS":
        common_features.extend(['stock_volatility', 'market_hours'])
    
    # Filtrer les features disponibles
    available_features = [f for f in common_features if f in combined_df.columns]
    print(f"🔧 Features utilisées: {len(available_features)}")
    
    if len(available_features) < 10:
        print(f"❌ Features insuffisantes: {len(available_features)}")
        return None, None, None
    
    # Préparer X et y
    X = combined_df[available_features]
    y = combined_df['target']
    
    # Supprimer les lignes avec NaN dans X ou y
    mask = ~(X.isna().any(axis=1) | y.isna())
    X = X[mask]
    y = y[mask]
    
    if len(X) < 100:
        print(f"❌ Échantillons insuffisants après nettoyage: {len(X)}")
        return None, None, None
    
    print(f"✅ Données finales: {len(X)} échantillons, {len(available_features)} features")
    
    # Split train/test
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    # Scaling
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Configuration XGBoost
    xgb_params = {
        'objective': 'binary:logistic',
        'eval_metric': 'logloss',
        'max_depth': 6,
        'learning_rate': 0.1,
        'n_estimators': 100,
        'subsample': 0.8,
        'colsample_bytree': 0.8,
        'random_state': 42,
        'n_jobs': -1
    }
    
    # Entraînement
    print(f"\n🤖 Entraînement XGBoost...")
    model = xgb.XGBClassifier(**xgb_params)
    model.fit(X_train_scaled, y_train)
    
    # Évaluation
    y_pred = model.predict(X_test_scaled)
    y_pred_proba = model.predict_proba(X_test_scaled)[:, 1]
    
    accuracy = accuracy_score(y_test, y_pred)
    print(f"\n📊 RÉSULTATS:")
    print(f"Accuracy: {accuracy:.4f}")
    print(f"Échantillons d'entraînement: {len(X_train)}")
    print(f"Échantillons de test: {len(X_test)}")
    
    # Rapport de classification
    print(f"\n📈 RAPPORT DE CLASSIFICATION:")
    print(classification_report(y_test, y_pred))
    
    # Importance des features
    feature_importance = pd.DataFrame({
        'feature': available_features,
        'importance': model.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print(f"\n🏆 TOP 10 FEATURES IMPORTANTES:")
    print(feature_importance.head(10))
    
    return model, scaler, available_features

def main():
    """Fonction principale"""
    print("🚀 DÉMARRAGE ENTRAÎNEMENT MODÈLES ADAPTATIFS - VERSION LIMITÉE")
    print("="*70)
    
    # Connexion MT5
    try:
        print("🔌 Connexion à MT5...")
        connect()
        print("✅ MT5 connecté")
    except Exception as e:
        print(f"❌ Erreur connexion MT5: {e}")
        return
    
    # Récupération des symboles
    try:
        print("\n📋 Récupération des symboles MT5...")
        all_symbols = get_all_symbols_simple()
        if not all_symbols:
            print("❌ Aucun symbole récupéré")
            return
        
        print(f"✅ {len(all_symbols)} symboles récupérés")
        
        # Catégorisation
        categories = categorize_symbols(all_symbols)
        
        print(f"\n📊 CATÉGORIES DÉTECTÉES:")
        for cat, symbols in categories.items():
            print(f"{cat}: {len(symbols)} symboles")
        
        # Entraînement des modèles par catégorie
        models_info = {}
        
        for category_name, symbols in categories.items():
            if not symbols:
                print(f"\n⚠️ Aucun symbole pour {category_name}, ignoré")
                continue
            
            # Déterminer le type de catégorie
            if category_name == "SYNTHETIC_SPECIAL":
                category_type = "SYNTHETIC_SPECIAL"
            elif category_name == "SYNTHETIC_GENERAL":
                category_type = "SYNTHETIC_GENERAL"
            elif category_name == "WELTRADE_SYNTH":
                category_type = "WELTRADE_SYNTH"
            elif category_name == "CRYPTO":
                category_type = "CRYPTO"
            elif category_name == "FOREX":
                category_type = "FOREX"
            elif category_name == "STOCKS":
                category_type = "STOCKS"
            else:
                category_type = "UNIVERSAL"
            
            # Entraîner le modèle
            model, scaler, features = train_model_for_category(
                category_name, symbols, category_type, max_symbols=5
            )
            
            if model is not None and scaler is not None:
                # Sauvegarder le modèle
                model_filename = f"{category_name.lower()}_xgb_model.pkl"
                scaler_filename = f"{category_name.lower()}_xgb_model_scaler.pkl"
                
                model_path = os.path.join(os.path.dirname(__file__), model_filename)
                scaler_path = os.path.join(os.path.dirname(__file__), scaler_filename)
                
                try:
                    joblib.dump(model, model_path)
                    joblib.dump(scaler, scaler_path)
                    
                    models_info[category_name] = {
                        'model_path': model_path,
                        'scaler_path': scaler_path,
                        'features': features,
                        'symbols_used': symbols[:5]
                    }
                    
                    print(f"💾 Modèle sauvegardé: {model_path}")
                    print(f"💾 Scaler sauvegardé: {scaler_path}")
                    
                except Exception as e:
                    print(f"❌ Erreur sauvegarde pour {category_name}: {e}")
            else:
                print(f"❌ Échec entraînement pour {category_name}")
        
        # Résumé final
        print(f"\n{'='*70}")
        print(f"🎉 ENTRAÎNEMENT TERMINÉ")
        print(f"{'='*70}")
        print(f"📊 Modèles entraînés: {len(models_info)}")
        
        for cat, info in models_info.items():
            print(f"✅ {cat}: {len(info['features'])} features, {len(info['symbols_used'])} symboles")
        
        # Créer un fichier de résumé
        summary_path = os.path.join(os.path.dirname(__file__), "training_summary.txt")
        with open(summary_path, 'w', encoding='utf-8') as f:
            f.write("RÉSUMÉ ENTRAÎNEMENT MODÈLES ADAPTATIFS\n")
            f.write("="*50 + "\n")
            f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Modèles entraînés: {len(models_info)}\n\n")
            
            for cat, info in models_info.items():
                f.write(f"📊 {cat}:\n")
                f.write(f"  - Features: {len(info['features'])}\n")
                f.write(f"  - Symboles: {', '.join(info['symbols_used'])}\n")
                f.write(f"  - Modèle: {info['model_path']}\n")
                f.write(f"  - Scaler: {info['scaler_path']}\n\n")
        
        print(f"📄 Résumé sauvegardé: {summary_path}")
        
    except Exception as e:
        print(f"❌ Erreur générale: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # Déconnexion MT5
        try:
            from backend.mt5_connector import shutdown
            shutdown()
            print("\n🔌 MT5 déconnecté")
        except:
            pass

if __name__ == "__main__":
    main() 