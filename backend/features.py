import pandas as pd
import numpy as np
from backend import technical_analysis

# Liste exacte des features attendues par le scaler ML
EXPECTED_FEATURES = [
    'return', 'return_1', 'return_2', 'return_3', 'volatility', 'volatility_5', 'volatility_10', 'ma_5', 'ma_10', 'ma_20', 'ma_50',
    'ma_ratio_5_20', 'ma_ratio_10_50', 'rsi', 'macd', 'macd_signal', 'bb_position', 'atr', 'volume_ratio', 'price_range', 'body_size',
    'upper_shadow', 'hour', 'minute', 'day_of_week', 'momentum_5', 'momentum_10', 'momentum_20', 'spike_detection', 'volatility_regime',
    'price_trend', 'relative_strength', 'abs_return', 'volatility_20', 'since_last_spike', 'seq_return_3', 'seq_return_5', 'rsi_14', 
    'bb_upper', 'bb_lower', 'bb_width'
]

def compute_features(df: pd.DataFrame) -> pd.DataFrame:
    df = pd.DataFrame(df)
    # Forcer toutes les colonnes utilisées à être des Series (sans condition)
    for col in ['close', 'open', 'high', 'low']:
        if col in df.columns:
            df[col] = pd.Series(df[col], index=df.index)
    features = pd.DataFrame(index=df.index)
    # === FEATURES DE RETOUR (4 caractéristiques) ===
    close = df['close']
    if not isinstance(close, pd.Series):
        close = pd.Series(close, index=df.index)
    # Ajout explicite : s'assurer que close est une Series
    close = pd.Series(close, index=df.index)
    assert isinstance(close, pd.Series), f"close is not a Series but {type(close)}"
    features['return'] = close.pct_change().fillna(0)
    features['return_1'] = close.pct_change().shift(1).fillna(0)
    features['return_2'] = close.pct_change().shift(2).fillna(0)
    features['return_3'] = close.pct_change().shift(3).fillna(0)
    # === NOUVEAU : abs_return ===
    features['abs_return'] = close.pct_change().abs().fillna(0)
    # === FEATURES DE VOLATILITÉ (3 caractéristiques) ===
    features['volatility'] = pd.Series(close.rolling(window=10, min_periods=1).std().to_numpy(dtype=float), index=df.index).fillna(0)
    features['volatility_5'] = pd.Series(close.rolling(window=5, min_periods=1).std().to_numpy(dtype=float), index=df.index).fillna(0)
    features['volatility_10'] = pd.Series(close.rolling(window=10, min_periods=1).std().to_numpy(dtype=float), index=df.index).fillna(0)
    features['volatility_20'] = pd.Series(close.rolling(window=20, min_periods=1).std().to_numpy(dtype=float), index=df.index).fillna(0)
    # === MOYENNES MOBILES (4 caractéristiques) ===
    features['ma_5'] = close.rolling(window=5, min_periods=1).mean().fillna(0)
    features['ma_10'] = close.rolling(window=10, min_periods=1).mean().fillna(0)
    features['ma_20'] = close.rolling(window=20, min_periods=1).mean().fillna(0)
    features['ma_50'] = close.rolling(window=50, min_periods=1).mean().fillna(0)
    # === RATIOS DE MOYENNES MOBILES (2 caractéristiques) ===
    features['ma_ratio_5_20'] = features['ma_5'] / (features['ma_20'] + 1e-8)
    features['ma_ratio_10_50'] = features['ma_10'] / (features['ma_50'] + 1e-8)
    # === INDICATEURS TECHNIQUES (8 caractéristiques) ===
    df_ta = df.copy()
    # RSI
    df_ta = technical_analysis.add_rsi(df_ta)
    if 'rsi_14' in df_ta.columns:
        features['rsi'] = df_ta['rsi_14'].fillna(50)
        features['rsi_14'] = df_ta['rsi_14'].fillna(50)
    else:
        features['rsi'] = 50
        features['rsi_14'] = 50
    # MACD
    df_ta = technical_analysis.add_macd(df_ta, technical_analysis.INDICATOR_PARAMS['macd'])
    if 'macd' in df_ta.columns:
        features['macd'] = df_ta['macd'].fillna(0)
        features['macd_signal'] = df_ta['macd_signal'].fillna(0)
    else:
        features['macd'] = 0
        features['macd_signal'] = 0
    # Bollinger Bands
    df_ta = technical_analysis.add_bollinger_bands(df_ta, technical_analysis.INDICATOR_PARAMS['bollinger'])
    if 'bb_percent' in df_ta.columns:
        features['bb_position'] = df_ta['bb_percent'].fillna(0.5)
    else:
        features['bb_position'] = 0.5
    # Ajout bb_upper, bb_lower, bb_width
    if 'bb_upper' in df_ta.columns:
        features['bb_upper'] = df_ta['bb_upper'].fillna(0)
    else:
        features['bb_upper'] = 0
    if 'bb_lower' in df_ta.columns:
        features['bb_lower'] = df_ta['bb_lower'].fillna(0)
    else:
        features['bb_lower'] = 0
    if 'bb_upper' in df_ta.columns and 'bb_lower' in df_ta.columns:
        features['bb_width'] = (df_ta['bb_upper'] - df_ta['bb_lower']).fillna(0)
    else:
        features['bb_width'] = 0
    # ATR
    df_ta = technical_analysis.add_atr(df_ta, [14])
    if 'atr_14' in df_ta.columns:
        features['atr'] = df_ta['atr_14'].fillna(0)
    else:
        features['atr'] = 0
    # Volume - utiliser tick_volume si disponible, sinon volume
    volume_col = 'tick_volume' if 'tick_volume' in df.columns else 'volume' if 'volume' in df.columns else None
    if volume_col:
        features['volume_ratio'] = df[volume_col] / (df[volume_col].rolling(window=10, min_periods=1).mean() + 1e-8)
    else:
        features['volume_ratio'] = 1
    # === FEATURES DE PRICE ACTION (3 caractéristiques) ===
    features['price_range'] = (df['high'] - df['low']) / (close + 1e-8)
    features['body_size'] = abs(close - df['open']) / (df['high'] - df['low'] + 1e-8)
    features['upper_shadow'] = (df['high'] - np.maximum(df['open'], close)) / (df['high'] - df['low'] + 1e-8)
    # === FEATURES TEMPORELLES (3 caractéristiques) ===
    if 'timestamp' in df.columns:
        dt = pd.to_datetime(df['timestamp'])
        features['hour'] = dt.dt.hour
        features['minute'] = dt.dt.minute
        features['day_of_week'] = dt.dt.dayofweek
    else:
        features['hour'] = 12
        features['minute'] = 0
        features['day_of_week'] = 0
    # === FEATURES DE MOMENTUM (3 caractéristiques) ===
    features['momentum_5'] = (close - close.shift(5)) / (close.shift(5) + 1e-8)
    features['momentum_10'] = (close - close.shift(10)) / (close.shift(10) + 1e-8)
    features['momentum_20'] = (close - close.shift(20)) / (close.shift(20) + 1e-8)
    # === FEATURES DE SPIKE (1 caractéristique) ===
    spike_threshold = features['volatility'].rolling(window=20, min_periods=1).mean() * 2
    features['spike_detection'] = pd.Series(np.where(features['volatility'] > spike_threshold, 1, 0), index=features.index)
    # === FEATURES DE RÉGIME (1 caractéristique) ===
    features['volatility_regime'] = pd.Series(np.where(features['volatility'] > features['volatility'].rolling(window=50, min_periods=1).mean(), 1, 0), index=features.index)
    # === FEATURES SUPPLÉMENTAIRES (2 caractéristiques) ===
    # Ajout/écrasement explicite des deux features manquantes
    features['price_trend'] = pd.Series(np.where(close > features['ma_20'], 1, 0), index=features.index)
    features['relative_strength'] = (close - close.rolling(window=14, min_periods=1).min()) / (close.rolling(window=14, min_periods=1).max() - close.rolling(window=14, min_periods=1).min() + 1e-8)
    # === FEATURES DE SEQUENCE (seq_return_3, seq_return_5) ===
    features['seq_return_3'] = close.pct_change(periods=3).fillna(0)
    features['seq_return_5'] = close.pct_change(periods=5).fillna(0)
    # === FEATURE since_last_spike ===
    if 'spike_detection' in features.columns:
        # On veut le nombre de périodes depuis le dernier spike (1 si spike à la bougie précédente, 2 sinon, etc.)
        since_last = []
        last_idx = -1
        for i, val in enumerate(features['spike_detection']):
            if val == 1:
                last_idx = i
                since_last.append(0)
            elif last_idx == -1:
                since_last.append(i+1)
            else:
                since_last.append(i - last_idx)
        features['since_last_spike'] = pd.Series(since_last, index=features.index)
    else:
        features['since_last_spike'] = 0
    # Nettoyage et ordre final
    features = features.replace([np.inf, -np.inf], 0)
    features = features.fillna(0)
    for col in EXPECTED_FEATURES:
        if col not in features.columns:
            features[col] = 0
    features = features[EXPECTED_FEATURES]
    print('Features retournées:', features.columns.tolist())
    return pd.DataFrame(features) 