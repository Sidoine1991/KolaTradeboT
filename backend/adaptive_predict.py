import os
import joblib
import numpy as np
import pandas as pd

# Import xgboost pour que joblib puisse charger les modèles XGBoost sauvegardés
try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError as e:
    XGBOOST_AVAILABLE = False
    import warnings
    warnings.warn(f"xgboost n'est pas installé. Les modèles XGBoost ne pourront pas être chargés: {e}")

# Import conditionnel pour éviter la dépendance à MetaTrader5
try:
    from backend.train_adaptive_models import create_adaptive_features
except ImportError:
    # Fallback: créer la fonction localement si l'import échoue
    def create_adaptive_features(df, symbol_category):
        """Crée des features adaptatives selon la catégorie de symbole (version standalone)"""
        df_features = df.copy()
        
        # S'assurer que timestamp existe
        if 'timestamp' not in df_features.columns and 'time' in df_features.columns:
            df_features['timestamp'] = pd.to_datetime(df_features['time'])
        elif 'timestamp' not in df_features.columns:
            df_features['timestamp'] = pd.date_range(start='2024-01-01', periods=len(df_features), freq='1min')
        
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
        df_features['ma_ratio_5_20'] = df_features['ma_5'] / (df_features['ma_20'] + 1e-8)
        df_features['ma_ratio_10_50'] = df_features['ma_10'] / (df_features['ma_50'] + 1e-8)
        
        # RSI
        delta = df_features['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / (loss + 1e-8)
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
        df_features['bb_position'] = (df_features['close'] - df_features['bb_lower']) / (df_features['bb_upper'] - df_features['bb_lower'] + 1e-8)
        
        # ATR
        high_low = df_features['high'] - df_features['low']
        high_close = np.abs(df_features['high'] - df_features['close'].shift())
        low_close = np.abs(df_features['low'] - df_features['close'].shift())
        true_range = np.maximum(high_low, np.maximum(high_close, low_close))
        df_features['atr'] = true_range.rolling(window=14).mean()
        
        # Volume (si disponible)
        if 'tick_volume' in df_features.columns:
            df_features['volume_ma'] = df_features['tick_volume'].rolling(window=20).mean()
            df_features['volume_ratio'] = df_features['tick_volume'] / (df_features['volume_ma'] + 1e-8)
        else:
            df_features['volume_ratio'] = 1.0
        
        # Features de prix
        df_features['price_range'] = (df_features['high'] - df_features['low']) / (df_features['close'] + 1e-8)
        df_features['body_size'] = abs(df_features['close'] - df_features['open']) / (df_features['close'] + 1e-8)
        df_features['upper_shadow'] = (df_features['high'] - np.maximum(df_features['open'], df_features['close'])) / (df_features['close'] + 1e-8)
        df_features['lower_shadow'] = (np.minimum(df_features['open'], df_features['close']) - df_features['low']) / (df_features['close'] + 1e-8)
        
        # Features temporelles
        if 'timestamp' in df_features.columns:
            df_features['hour'] = pd.to_datetime(df_features['timestamp']).dt.hour
            df_features['minute'] = pd.to_datetime(df_features['timestamp']).dt.minute
            df_features['day_of_week'] = pd.to_datetime(df_features['timestamp']).dt.dayofweek
        else:
            df_features['hour'] = 12
            df_features['minute'] = 0
            df_features['day_of_week'] = 0
        
        # Momentum
        df_features['momentum_5'] = df_features['close'] / (df_features['close'].shift(5) + 1e-8) - 1
        df_features['momentum_10'] = df_features['close'] / (df_features['close'].shift(10) + 1e-8) - 1
        df_features['momentum_20'] = df_features['close'] / (df_features['close'].shift(20) + 1e-8) - 1
        
        # Features spécifiques par catégorie
        if symbol_category in ["SYNTHETIC_SPECIAL", "SYNTHETIC_GENERAL"]:
            df_features['spike_detection'] = ((df_features['high'] - df_features['low']) / (df_features['close'] + 1e-8) > 0.05).astype(int)
            df_features['volatility_regime'] = df_features['volatility'].rolling(50).mean()
        else:
            df_features['spike_detection'] = 0
            df_features['volatility_regime'] = df_features['volatility'].rolling(50).mean()
        
        # Nettoyage
        df_features = df_features.fillna(0)
        df_features = df_features.replace([np.inf, -np.inf], 0)
        
        return df_features

def get_symbol_category(symbol):
    symbol_upper = symbol.upper()
    if "BOOM" in symbol_upper or "CRASH" in symbol_upper:
        return "SYNTHETIC_SPECIAL"
    elif any(keyword in symbol_upper for keyword in ['VOLATILITY', 'STEP', 'JUMP', 'RANGE BREAK', 'DEX', 'DRIFT', 'TREK', 'VOLSWITCH', 'SKEW', 'MULTI STEP']):
        return "SYNTHETIC_GENERAL"
    elif any(crypto in symbol_upper for crypto in ['BTC', 'ETH', 'ADA', 'DOT', 'LNK', 'LTC', 'BCH', 'XRP', 'XLM', 'XMR', 'ZEC', 'XTZ', 'NEO', 'MKR', 'SOL', 'TRX', 'UNI', 'SHB', 'TON', 'FET', 'APT', 'COM', 'IMX', 'SAN', 'TRU', 'MLN', 'NER']):
        return "CRYPTO"
    elif any(pair in symbol_upper for pair in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD', 'SEK', 'NOK', 'PLN', 'ZAR', 'SGD', 'HKD', 'THB', 'MXN', 'CNH']):
        return "FOREX"
    elif any(stock in symbol_upper for stock in ['AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX', 'JPM', 'BAC', 'WMT', 'PG', 'JNJ', 'V', 'HD', 'MA', 'PYPL', 'DIS', 'CRM', 'NKE', 'PFE', 'KO', 'MCD', 'ABNB', 'UBER', 'ZM', 'AAL', 'DAL', 'GM', 'F', 'BA', 'IBM', 'INTC', 'CSCO', 'ORCL', 'ADBE', 'NFLX', 'AMD', 'BABA', 'AIG', 'GS', 'C', 'DBK', 'EBAY', 'FDX', 'FOX', 'HPQ', 'SONY', 'TEVA', 'AIR', 'AIRF', 'BAY', 'BMW', 'BIIB', 'CONG', 'ADS']):
        return "STOCKS"
    else:
        return "UNIVERSAL"

MODEL_CONFIGS = {
    'SYNTHETIC_SPECIAL': {
        'model_path': 'backend/synthetic_special_xgb_model.pkl',
        'scaler_path': 'backend/synthetic_special_xgb_model_scaler.pkl',
        'name': 'XGBoost Boom/Crash Spécialisé'
    },
    'SYNTHETIC_GENERAL': {
        'model_path': 'backend/synthetic_general_xgb_model.pkl',
        'scaler_path': 'backend/synthetic_general_xgb_model_scaler.pkl',
        'name': 'XGBoost Indices Synthétiques'
    },
    'CRYPTO': {
        'model_path': 'backend/crypto_xgb_model.pkl',
        'scaler_path': 'backend/crypto_xgb_model_scaler.pkl',
        'name': 'XGBoost Crypto'
    },
    'FOREX': {
        'model_path': 'backend/forex_xgb_model.pkl',
        'scaler_path': 'backend/forex_xgb_model_scaler.pkl',
        'name': 'XGBoost Forex'
    },
    'STOCKS': {
        'model_path': 'backend/stocks_xgb_model.pkl',
        'scaler_path': 'backend/stocks_xgb_model_scaler.pkl',
        'name': 'XGBoost Actions'
    },
    'UNIVERSAL': {
        'model_path': 'backend/universal_xgb_model.pkl',
        'scaler_path': 'backend/universal_xgb_model_scaler.pkl',
        'name': 'XGBoost Universel'
    }
}

# Ajoute ce dictionnaire globalement (ou importe-le d'un module features.py si tu préfères)
MODEL_FEATURES = {
    "SYNTHETIC_SPECIAL": [
        'return', 'return_1', 'return_2', 'return_3', 'volatility', 'volatility_5', 'volatility_10',
        'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_ratio_5_20', 'ma_ratio_10_50',
        'rsi', 'macd', 'macd_signal', 'macd_histogram', 'bb_position', 'atr', 'volume_ratio',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow', 'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20',
        'spike_detection', 'volatility_regime'
    ],
    "SYNTHETIC_GENERAL": [
        'return', 'return_1', 'return_2', 'return_3', 'volatility', 'volatility_5', 'volatility_10',
        'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_ratio_5_20', 'ma_ratio_10_50',
        'rsi', 'macd', 'macd_signal', 'macd_histogram', 'bb_position', 'atr', 'volume_ratio',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow', 'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20',
        'spike_detection', 'volatility_regime'
    ],
    "CRYPTO": [
        'return', 'return_1', 'return_2', 'return_3', 'volatility', 'volatility_5', 'volatility_10',
        'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_ratio_5_20', 'ma_ratio_10_50',
        'rsi', 'macd', 'macd_signal', 'macd_histogram', 'bb_position', 'atr', 'volume_ratio',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow', 'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20',
        'spike_detection', 'volatility_regime'
    ],
    "FOREX": [
        'return', 'return_1', 'return_2', 'return_3', 'volatility', 'volatility_5', 'volatility_10',
        'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_ratio_5_20', 'ma_ratio_10_50',
        'rsi', 'macd', 'macd_signal', 'macd_histogram', 'bb_position', 'atr', 'volume_ratio',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow', 'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20',
        'spike_detection', 'volatility_regime'
    ],
    "STOCKS": [
        'return', 'return_1', 'return_2', 'return_3', 'volatility', 'volatility_5', 'volatility_10',
        'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_ratio_5_20', 'ma_ratio_10_50',
        'rsi', 'macd', 'macd_signal', 'macd_histogram', 'bb_position', 'atr', 'volume_ratio',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow', 'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20',
        'spike_detection', 'volatility_regime'
    ],
    "UNIVERSAL": [
        'return', 'return_1', 'return_2', 'return_3', 'volatility', 'volatility_5', 'volatility_10',
        'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_ratio_5_20', 'ma_ratio_10_50',
        'rsi', 'macd', 'macd_signal', 'macd_histogram', 'bb_position', 'atr', 'volume_ratio',
        'price_range', 'body_size', 'upper_shadow', 'lower_shadow', 'hour', 'minute', 'day_of_week',
        'momentum_5', 'momentum_10', 'momentum_20',
        'spike_detection', 'volatility_regime'
    ]
}

def predict_adaptive(symbol, df_ohlc):
    # Vérifier que xgboost est disponible avant de charger le modèle
    if not XGBOOST_AVAILABLE:
        return {'error': 'xgboost n\'est pas installé. Installez-le avec: pip install xgboost', 'category': 'UNKNOWN', 'model_name': 'N/A'}
    
    category = get_symbol_category(symbol)
    config = MODEL_CONFIGS.get(category, MODEL_CONFIGS['UNIVERSAL'])
    model_path = config['model_path']
    scaler_path = config['scaler_path']
    model_name = config['name']
    if not (os.path.exists(model_path) and os.path.exists(scaler_path)):
        return {'error': f"Modèle ou scaler non trouvé pour la catégorie {category}", 'category': category, 'model_name': model_name}
    features_df = create_adaptive_features(df_ohlc, category)
    features_df = features_df.fillna(0)
    features = MODEL_FEATURES.get(category, MODEL_FEATURES['UNIVERSAL'])
    X_pred = features_df[features].iloc[-1:].fillna(0)
    import joblib
    model = joblib.load(model_path)
    scaler = joblib.load(scaler_path)
    if hasattr(scaler, 'n_features_in_') and scaler.n_features_in_ != X_pred.shape[1]:
        return {'error': f"Scaler attend {scaler.n_features_in_} features, {X_pred.shape[1]} fournis.", 'category': category, 'model_name': model_name}
    X_pred_scaled = scaler.transform(X_pred)
    proba = model.predict_proba(X_pred_scaled)[0][1]
    pred = model.predict(X_pred_scaled)[0]
    return {
        'prediction': int(pred),
        'probability': float(proba),
        'model_name': model_name,
        'category': category,
        'features_used': features,
        'input_row': X_pred.iloc[0].to_dict()
    }

def predict_multi_horizon(symbol, df_ohlc, horizon_label):
    """
    Prédit la proba de hausse pour un horizon donné (ex: '4h', '1d', '1w') en chargeant le modèle XGBoost correspondant.
    """
    # Vérifier que xgboost est disponible avant de charger le modèle
    if not XGBOOST_AVAILABLE:
        return {'error': 'xgboost n\'est pas installé. Installez-le avec: pip install xgboost', 'horizon': horizon_label}
    
    model_path = f"backend/xgb_model_{horizon_label}.pkl"
    if not os.path.exists(model_path):
        return {'error': f"Modèle pour l'horizon {horizon_label} non trouvé."}
    model = joblib.load(model_path)
    # Features simples (doivent être cohérentes avec l'entraînement)
    feats = pd.DataFrame(index=df_ohlc.index)
    feats['return_1'] = df_ohlc['close'].pct_change(1)
    feats['return_3'] = df_ohlc['close'].pct_change(3)
    feats['ma_5'] = df_ohlc['close'].rolling(5).mean()
    feats['ma_10'] = df_ohlc['close'].rolling(10).mean()
    feats['vol_5'] = df_ohlc['close'].rolling(5).std()
    feats['vol_10'] = df_ohlc['close'].rolling(10).std()
    feats = feats.dropna()
    if feats.empty:
        return {'error': 'Pas assez de données pour la prédiction'}
    X = feats.values
    proba = model.predict_proba(X)[-1, 1]
    pred = model.predict(X)[-1]
    return {
        'prediction': int(pred),
        'probability': float(proba),
        'model_name': f"XGBoost multi-horizon ({horizon_label})",
        'horizon': horizon_label,
        'input_row': feats.iloc[-1].to_dict()
    } 

# Logique scientifique maison pour la prédiction de spike
import numpy as np
import pandas as pd

def predict_spike_scientifique(df, window=20, z_threshold=2.5):
    returns = df['close'].pct_change()
    mean_ret = returns.rolling(window=window).mean()
    std_ret = returns.rolling(window=window).std()
    zscore = (returns - mean_ret) / std_ret
    last_z = zscore.iloc[-1]
    ma = df['close'].rolling(window=window).mean()
    std = df['close'].rolling(window=window).std()
    upper = ma + 2*std
    lower = ma - 2*std
    band_width = (upper - lower) / ma
    recent_bandwidth = band_width.iloc[-window:].mean()
    spike_proba = 0.0
    if abs(last_z) > z_threshold:
        spike_proba += 0.5
    if recent_bandwidth < 0.05:
        spike_proba += 0.3
    if 'volume' in df.columns and df['volume'].iloc[-1] > df['volume'].rolling(window=window).mean().iloc[-1] * 1.5:
        spike_proba += 0.2
    return min(spike_proba, 1.0) 