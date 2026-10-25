import ta
import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Any, cast
import logging # Ajout pour une meilleure gestion des logs

# Ajout des imports explicites pour les indicateurs ta
from ta.volatility import average_true_range, BollingerBands, KeltnerChannel
from ta.trend import sma_indicator, ema_indicator, MACD, ADXIndicator, IchimokuIndicator
from ta.momentum import rsi, StochRSIIndicator, StochasticOscillator
from ta.volume import volume_weighted_average_price, on_balance_volume, acc_dist_index, chaikin_money_flow

logger = logging.getLogger(__name__)

# --- Paramètres par défaut pour les indicateurs (peut être étendu) ---
# Ceci permettra de modifier facilement la stratégie sans toucher au code des fonctions
INDICATOR_PARAMS = {
    'sma': {'windows': [5, 15, 29, 50, 75, 80, 95, 90]},
    'ema': {'windows': [5, 15, 29, 50, 75, 80, 95, 90]},
    'rsi': {'windows': [14, 21]},
    'macd': {'window_fast': 12, 'window_slow': 26, 'window_sign': 9},
    'bollinger': {'window': 20, 'window_dev': 2},
    'stochastic': {'window': 14, 'smooth_window': 3, 'signal_window': 3},
    'atr': {'windows': [14, 21]},
    'adx': {'window': 14},
    'keltner': {'window': 20, 'window_atr': 10, 'multiplier': 2},
    'ichimoku': {'window_conv': 9, 'window_base': 26, 'window_lag': 52, 'window_disp': 26},
    'volume': {'sma_window': 20}
}
# --- Fonctions utilitaires ---

def _safe_apply_indicator(df: pd.DataFrame, indicator_func, *args, **kwargs) -> pd.DataFrame:
    """Applique une fonction d'indicateur TA de manière sécurisée en gérant les NaN. Retourne toujours un DataFrame."""
    try:
        temp_df = df.copy()
        result = indicator_func(*args, **kwargs)
        if isinstance(result, pd.Series):
            result = result.reindex(df.index)
            return pd.DataFrame({'value': result})
        elif isinstance(result, pd.DataFrame):
            for col in result.columns:
                result[col] = result[col].reindex(df.index)
            return result
        else:
            # Si le résultat n'est ni Series ni DataFrame, retourne un DataFrame de NaN
            return pd.DataFrame(np.nan, index=pd.Index(df.index), columns=pd.Index(['value']))
    except Exception as e:
        logger.warning(f"Erreur lors du calcul de l'indicateur {getattr(indicator_func, '__name__', str(indicator_func))}: {e}")
        # Retourne un DataFrame de NaN pour la colonne attendue
        if hasattr(indicator_func, '__name__') and indicator_func.__name__ == 'MACD':
            return pd.DataFrame(np.nan, index=pd.Index(df.index), columns=pd.Index(['macd', 'macd_signal', 'macd_histogram']))
        else:
            return pd.DataFrame(np.nan, index=pd.Index(df.index), columns=pd.Index(['value']))

def _is_bullish_candle(open_price, close_price) -> bool:
    """Vérifie si la bougie est haussière (corps vert)."""
    return close_price > open_price

def _is_bearish_candle(open_price, close_price) -> bool:
    """Vérifie si la bougie est baissière (corps rouge)."""
    return close_price < open_price

def _candle_body_range(open_price, close_price) -> float:
    """Retourne la taille du corps de la bougie."""
    return abs(close_price - open_price)

def _candle_total_range(high_price, low_price) -> float:
    """Retourne la taille totale de la bougie (High - Low)."""
    return high_price - low_price

# --- Fonctions pour la détection de Step Patterns (Boom/Crash) ---

def detect_step_pattern(df: pd.DataFrame, red_count: int = 3, green_amp_factor: float = 2.0) -> List[Any]:
    """
    Détecte les patterns 'escalier montant' (Boom) : 
    une série de petites bougies rouges/neutres suivies d'une grande bougie verte.
    Utilise la logique des indices synthétiques.

    Args:
        df: DataFrame OHLCV avec les colonnes 'open', 'high', 'low', 'close', 'volume', 'timestamp'.
        red_count: Nombre de bougies précédentes à examiner pour la consolidation.
        green_amp_factor: Facteur d'amplitude pour la grande bougie verte (par rapport à la bougie moyenne précédente).

    Returns:
        Liste des timestamps (ou index) où le pattern est détecté.
    """
    patterns = []
    # Assurez-vous que l'ATR est calculé pour une meilleure mesure de la volatilité
    if 'atr_14' not in df.columns:
        df = add_atr(df.copy(), windows=[14]) # Use a copy to avoid modifying original df passed from UI to other functions
    
    # Utilisez une fenêtre glissante pour l'ATR moyen afin de définir ce qui est "petit"
    avg_atr = pd.Series(df['atr_14'].rolling(window=10, min_periods=1).mean(), index=df.index)

    for i in range(red_count, len(df)): # Iterate up to len(df)-1 to allow checking current candle
        if pd.isna(avg_atr.iloc[i]): # Skip if ATR not available for this period
            continue

        # Récupérer les 'red_count' bougies précédentes + la bougie actuelle comme bougie de déclenchement
        prev_candles = df.iloc[i - red_count : i]
        trigger_candle = df.iloc[i]

        # Conditions de consolidation (faible volatilité)
        # Les bougies précédentes doivent être petites (corps et/ou range total) par rapport à l'ATR moyen ou à leur propre ATR.
        is_consolidation_low_vol = True
        for j in range(red_count):
            prev_candle = prev_candles.iloc[j]
            # Vérifier que le corps et/ou le range est "petit" par rapport à l'ATR local
            if _candle_body_range(prev_candle['open'], prev_candle['close']) > avg_atr.iloc[i-red_count+j] * 0.5 or \
               _candle_total_range(prev_candle['high'], prev_candle['low']) > avg_atr.iloc[i-red_count+j] * 1.5: # 1.5x ATR is still small
                is_consolidation_low_vol = False
                break
        
        # S'assurer que la consolidation n'est pas une forte tendance baissière
        # ie: pas toutes de très grandes bougies rouges
        if all(_is_bearish_candle(c['open'], c['close']) and 0 <= i-red_count+idx < len(avg_atr) and _candle_body_range(c['open'], c['close']) > avg_atr.iloc[i-red_count+idx] for idx, c in prev_candles.iterrows()):
            is_consolidation_low_vol = False

        if not is_consolidation_low_vol:
            continue

        # Condition de déclenchement (grande bougie haussière)
        is_trigger_candle_bullish = _is_bullish_candle(trigger_candle['open'], trigger_candle['close'])
        trigger_amplitude = _candle_body_range(trigger_candle['open'], trigger_candle['close'])
        
        # L'amplitude de la bougie de déclenchement > facteur * taille moyenne des bougies précédentes
        avg_prev_amplitude = prev_candles.apply(lambda x: _candle_body_range(x['open'], x['close']), axis=1).mean()
        
        # Pour les Boom indices, le spike est une bougie verte massive.
        # Le déclenchement doit être une bougie verte de grande amplitude
        if is_trigger_candle_bullish and trigger_amplitude > green_amp_factor * (avg_prev_amplitude if avg_prev_amplitude > 0 else avg_atr.iloc[i] * 0.5):
            patterns.append(trigger_candle.name if 'timestamp' not in df.columns else trigger_candle['timestamp'])
            
    return patterns


def predict_next_step_pattern(df: pd.DataFrame, consolidation_window: int = 20, atr_multiplier: float = 0.5) -> bool:
    """
    Prédit la probabilité d'apparition d'un step pattern montant (Boom) dans les prochaines bougies.
    Les conditions favorables sont une période de faible volatilité/consolidation récente
    avec une pression d'achat potentielle (e.g., RSI en zone neutre après survente, ou bougies haussières sporadiques).

    Args:
        df: DataFrame OHLCV avec les colonnes 'open', 'high', 'low', 'close', 'volume', 'timestamp'.
        consolidation_window: Nombre de bougies à examiner pour détecter une consolidation.
        atr_multiplier: Facteur pour définir ce qu'est une "faible volatilité" basée sur l'ATR.

    Returns:
        True si les conditions sont réunies, sinon False.
    """
    if len(df) < consolidation_window + INDICATOR_PARAMS['atr']['windows'][0]: # Need enough data for ATR
        return False
    
    # Assurez-vous que l'ATR est calculé
    if 'atr_14' not in df.columns:
        df = add_atr(df.copy(), windows=[14])

    recent_data = df.iloc[-consolidation_window:].copy()
    if recent_data.empty: return False

    # Mesure de la volatilité récente
    avg_atr_recent = recent_data['atr_14'].mean()
    global_avg_atr = df['atr_14'].mean() # Moyenne sur tout l'historique chargé

    # Condition 1: Faible volatilité récente (consolidation)
    is_low_volatility = avg_atr_recent < global_avg_atr * atr_multiplier # La volatilité actuelle est bien plus faible que la moyenne
    
    # Condition 2: Le prix n'est pas en chute libre (pour éviter les faux signaux après un crash)
    # Vérifier que les dernières bougies ne sont pas toutes de grosses baissières
    last_close = df['close'].iloc[-1] if df is not None and not df.empty else np.nan
    prev_close_n = df['close'].iloc[-consolidation_window] if df is not None and not df.empty else np.nan
    is_not_falling_sharply = (last_close - prev_close_n) / prev_close_n > -0.01 # Pas de chute de plus de 1% sur la fenêtre

    # Condition 3: Pression haussière potentielle (optionnel, plus complexe)
    # Ex: RSI n'est pas en zone de surachat, ou formation de dojis/marteaux
    if 'rsi_14' in df.columns:
        last_rsi = df['rsi_14'].iloc[-1] if df is not None and not df.empty else np.nan
        is_rsi_favorable = 30 < last_rsi < 70
    else:
        is_rsi_favorable = True # Assume favorable if RSI not available

    # Confluence pour un Boom imminent
    if is_low_volatility and is_not_falling_sharply and is_rsi_favorable:
        return True
    return False

def detect_step_pattern_crash(df: pd.DataFrame, green_count: int = 3, red_amp_factor: float = 2.0) -> List[Any]:
    """
    Détecte les patterns 'escalier descendant' (Crash) : 
    une série de petites bougies vertes/neutres suivies d'une grande bougie rouge.
    Utilise la logique des indices synthétiques.

    Args:
        df: DataFrame OHLCV avec les colonnes 'open', 'high', 'low', 'close', 'volume', 'timestamp'.
        green_count: Nombre de bougies précédentes à examiner pour la consolidation.
        red_amp_factor: Facteur d'amplitude pour la grande bougie rouge (par rapport à la bougie moyenne précédente).

    Returns:
        Liste des timestamps (ou index) où le pattern est détecté.
    """
    patterns = []
    if 'atr_14' not in df.columns:
        df = add_atr(df.copy(), windows=[14])
    
    avg_atr = pd.Series(df['atr_14'].rolling(window=10, min_periods=1).mean(), index=df.index)

    for i in range(green_count, len(df)):
        if pd.isna(avg_atr.iloc[i]):
            continue

        prev_candles = df.iloc[i - green_count : i]
        trigger_candle = df.iloc[i]

        is_consolidation_low_vol = True
        for j in range(green_count):
            prev_candle = prev_candles.iloc[j]
            if _candle_body_range(prev_candle['open'], prev_candle['close']) > avg_atr.iloc[i-green_count+j] * 0.5 or \
               _candle_total_range(prev_candle['high'], prev_candle['low']) > avg_atr.iloc[i-green_count+j] * 1.5:
                is_consolidation_low_vol = False
                break
        
        # S'assurer que la consolidation n'est pas une forte tendance haussière
        if all(
            0 <= i-green_count+idx < len(avg_atr) and
            _is_bullish_candle(c['open'], c['close']) and 
            _candle_body_range(c['open'], c['close']) > avg_atr.iloc[i-green_count+idx]
            for idx, c in prev_candles.iterrows()
        ):
            is_consolidation_low_vol = False
            
        if not is_consolidation_low_vol:
            continue

        is_trigger_candle_bearish = _is_bearish_candle(trigger_candle['open'], trigger_candle['close'])
        trigger_amplitude = _candle_body_range(trigger_candle['open'], trigger_candle['close'])
        
        avg_prev_amplitude = prev_candles.apply(lambda x: _candle_body_range(x['open'], x['close']), axis=1).mean()
        
        # Pour les Crash indices, le spike est une bougie rouge massive.
        if is_trigger_candle_bearish and trigger_amplitude > red_amp_factor * (avg_prev_amplitude if avg_prev_amplitude > 0 else avg_atr.iloc[i] * 0.5):
            patterns.append(trigger_candle.name if 'timestamp' not in df.columns else trigger_candle['timestamp'])
            
    return patterns

def predict_next_step_pattern_crash(df: pd.DataFrame, consolidation_window: int = 20, atr_multiplier: float = 0.5) -> bool:
    """
    Prédit la probabilité d'apparition d'un step pattern descendant (Crash) dans les prochaines bougies.
    Les conditions favorables sont une période de faible volatilité/consolidation récente
    avec une pression de vente potentielle (e.g., RSI en zone neutre après surachat, ou bougies baissières sporadiques).

    Args:
        df: DataFrame OHLCV avec les colonnes 'open', 'high', 'low', 'close', 'volume', 'timestamp'.
        consolidation_window: Nombre de bougies à examiner pour détecter une consolidation.
        atr_multiplier: Facteur pour définir ce qu'est une "faible volatilité" basée sur l'ATR.

    Returns:
        True si les conditions sont réunies, sinon False.
    """
    if len(df) < consolidation_window + INDICATOR_PARAMS['atr']['windows'][0]: 
        return False
    
    if 'atr_14' not in df.columns:
        df = add_atr(df.copy(), windows=[14])

    recent_data = df.iloc[-consolidation_window:].copy()
    if recent_data.empty: return False

    avg_atr_recent = recent_data['atr_14'].mean()
    global_avg_atr = df['atr_14'].mean()

    is_low_volatility = avg_atr_recent < global_avg_atr * atr_multiplier
    
    last_close = df['close'].iloc[-1] if df is not None and not df.empty else np.nan
    prev_close_n = df['close'].iloc[-consolidation_window] if df is not None and not df.empty else np.nan
    is_not_rising_sharply = (last_close - prev_close_n) / prev_close_n < 0.01 # Pas de hausse de plus de 1%

    if 'rsi_14' in df.columns:
        last_rsi = df['rsi_14'].iloc[-1] if df is not None and not df.empty else np.nan
        is_rsi_favorable = 30 < last_rsi < 70
    else:
        is_rsi_favorable = True

    if is_low_volatility and is_not_rising_sharply and is_rsi_favorable:
        return True
    return False


# --- Fonctions d'ajout d'indicateurs techniques principales ---

def add_technical_indicators(df: pd.DataFrame, indicators: Optional[List[str]] = None) -> pd.DataFrame:
    """
    Ajoute des indicateurs techniques au DataFrame.
    Gère les NaN résultant des calculs de fenêtres.
    
    Args:
        df: DataFrame avec colonnes 'open', 'high', 'low', 'close', 'volume'.
        indicators: Liste des indicateurs à calculer.

    Returns:
        DataFrame avec indicateurs ajoutés.
    """
    if df.empty:
        logger.warning("DataFrame vide passé à add_technical_indicators.")
        return df
    
    # Assurer que l'index est un DateTimeIndex si 'timestamp' est une colonne, pour ta.
    # Sinon, travailler avec l'index existant.
    original_index_name = df.index.name
    if 'timestamp' in df.columns and not isinstance(df.index, pd.DatetimeIndex):
        df_copy = df.set_index('timestamp').copy()
    else:
        df_copy = df.copy()

    # Assurer qu'il n'y a pas de -inf ou inf dans les données de prix.
    # Ceci peut poser problème pour certaines fonctions de 'ta'.
    price_cols = ['open', 'high', 'low', 'close']
    for col in price_cols:
        if col in df_copy.columns:
            df_copy[col] = df_copy[col].replace([np.inf, -np.inf], np.nan)
            df_copy[col] = df_copy[col].ffill().bfill() # Forward fill then backfill NaNs

    if indicators is None:
        indicators = ['sma', 'ema', 'rsi', 'macd', 'bollinger', 'atr', 'adx'] # Default set

    for ind in indicators:
        try:
            if ind == 'sma' or ind == 'ema':
                df_copy = add_moving_averages(df_copy, INDICATOR_PARAMS.get(ind, {}).get('windows'))
            elif ind == 'rsi':
                df_copy = add_rsi(df_copy, INDICATOR_PARAMS.get(ind, {}).get('windows'))
            elif ind == 'stochastic':
                df_copy = add_stochastic(df_copy, INDICATOR_PARAMS.get(ind, {}))
            elif ind == 'macd':
                df_copy = add_macd(df_copy, INDICATOR_PARAMS.get(ind, {}))
            elif ind == 'bollinger':
                df_copy = add_bollinger_bands(df_copy, INDICATOR_PARAMS.get(ind, {}))
            elif ind == 'keltner':
                df_copy = add_keltner_channels(df_copy, INDICATOR_PARAMS.get(ind, {}))
            elif ind == 'atr':
                df_copy = add_atr(df_copy, INDICATOR_PARAMS.get(ind, {}).get('windows'))
            elif ind == 'adx':
                df_copy = add_adx(df_copy, INDICATOR_PARAMS.get(ind, {}))
            elif ind == 'ichimoku':
                df_copy = add_ichimoku(df_copy, INDICATOR_PARAMS.get(ind, {}))
            elif ind == 'volume':
                df_copy = add_volume_indicators(df_copy, INDICATOR_PARAMS.get(ind, {}))
            elif ind == 'support_resistance': # Non TA-Lib, custom, to be added below
                df_copy = add_support_resistance(df_copy)
            # Ajoutez d'autres indicateurs au besoin
        except Exception as e:
            logger.error(f"Erreur lors de l'ajout de l'indicateur '{ind}': {e}", exc_info=True)
            # Ne pas crasher, mais continuer à ajouter les autres indicateurs

    # Réinitialiser l'index si 'timestamp' était la colonne et non l'index original
    if 'timestamp' in df.columns and not isinstance(df.index, pd.DatetimeIndex):
        df_copy = df_copy.reset_index(names='timestamp')
        if original_index_name: # Restore original index name if it existed
            df_copy.index.name = original_index_name
    
    return df_copy


# --- Implémentations détaillées des indicateurs ---

def add_moving_averages(df: pd.DataFrame, windows: Optional[List[int]] = None) -> pd.DataFrame:
    """Ajoute les moyennes mobiles (SMA, EMA)."""
    if windows is None:
        windows = INDICATOR_PARAMS['sma']['windows'] + [w for w in INDICATOR_PARAMS['ema']['windows'] if w not in INDICATOR_PARAMS['sma']['windows']]
    for window in windows if windows is not None else []:
        if 'close' in df.columns and isinstance(df['close'], pd.Series):
            df[f'sma_{window}'] = sma_indicator(df['close'], window=window)
            df[f'ema_{window}'] = ema_indicator(df['close'], window=window)
    return df

def add_rsi(df: pd.DataFrame, windows: Optional[List[int]] = None) -> pd.DataFrame:
    """Ajoute le RSI et ses variantes."""
    if windows is None:
        windows = INDICATOR_PARAMS['rsi']['windows']
    for window in windows if windows is not None else []:
        if 'close' in df.columns:
            close_col = df['close']
            if isinstance(close_col, pd.DataFrame):
                close_col = close_col.squeeze()
            if isinstance(close_col, pd.Series):
                df[f'rsi_{window}'] = rsi(close_col, window=window)
    
    # StochRSI
    if 'close' in df.columns:
        close_col = df['close']
        if isinstance(close_col, pd.DataFrame):
            close_col = close_col.squeeze()
        if isinstance(close_col, pd.Series):
            stoch_rsi = StochRSIIndicator(close_col, window=INDICATOR_PARAMS['rsi']['windows'][0])
            df['stoch_rsi'] = stoch_rsi.stochrsi()
            df['stoch_rsi_k'] = stoch_rsi.stochrsi_k()
            df['stoch_rsi_d'] = stoch_rsi.stochrsi_d()
    return df

def add_stochastic(df: pd.DataFrame, params: Dict) -> pd.DataFrame:
    """Ajoute le Stochastique."""
    if all(col in df.columns for col in ['high', 'low', 'close']):
        high_col = df['high']; low_col = df['low']; close_col = df['close']
        if isinstance(high_col, pd.DataFrame): high_col = high_col.squeeze()
        if isinstance(low_col, pd.DataFrame): low_col = low_col.squeeze()
        if isinstance(close_col, pd.DataFrame): close_col = close_col.squeeze()
        # Conversion explicite en Series float64 alignée sur l'index du DataFrame
        high_col = cast(pd.Series, pd.Series(np.asarray(high_col).astype('float64'), index=df.index).copy())
        low_col = cast(pd.Series, pd.Series(np.asarray(low_col).astype('float64'), index=df.index).copy())
        close_col = cast(pd.Series, pd.Series(np.asarray(close_col).astype('float64'), index=df.index).copy())
        if all(isinstance(col, pd.Series) for col in [high_col, low_col, close_col]):
            stoch = StochasticOscillator(
                high=high_col, low=low_col, close=close_col,
                window=params.get('window', 14),
                smooth_window=params.get('smooth_window', 3)
            )
            df['stoch_k'] = stoch.stoch()
            df['stoch_d'] = stoch.stoch_signal()
    return df

def add_macd(df: pd.DataFrame, params: Dict) -> pd.DataFrame:
    """Ajoute le MACD et ses composants."""
    if 'close' in df.columns:
        close_col = df['close']
        if isinstance(close_col, pd.DataFrame):
            close_col = close_col.squeeze()
        if isinstance(close_col, pd.Series):
            macd = MACD(
                close=close_col,
                window_fast=params.get('window_fast', 12),
                window_slow=params.get('window_slow', 26),
                window_sign=params.get('window_sign', 9)
            )
            df['macd'] = macd.macd()
            df['macd_signal'] = macd.macd_signal()
            df['macd_histogram'] = macd.macd_diff()
    return df

def add_bollinger_bands(df: pd.DataFrame, params: Dict) -> pd.DataFrame:
    """Ajoute les bandes de Bollinger."""
    if 'close' in df.columns:
        close_col = df['close']
        if isinstance(close_col, pd.DataFrame):
            close_col = close_col.squeeze()
        if isinstance(close_col, pd.Series):
            bb = BollingerBands(
                close=close_col,
                window=params.get('window', 20),
                window_dev=params.get('window_dev', 2)
            )
            df['bb_upper'] = bb.bollinger_hband()
            df['bb_middle'] = bb.bollinger_mavg()
            df['bb_lower'] = bb.bollinger_lband()
            df['bb_width'] = bb.bollinger_wband()
            df['bb_percent'] = bb.bollinger_pband()
    return df

def add_keltner_channels(df: pd.DataFrame, params: Dict) -> pd.DataFrame:
    """Ajoute les canaux de Keltner."""
    if all(col in df.columns for col in ['high', 'low', 'close']):
        high_col = df['high']; low_col = df['low']; close_col = df['close']
        if isinstance(high_col, pd.DataFrame): high_col = high_col.squeeze()
        if isinstance(low_col, pd.DataFrame): low_col = low_col.squeeze()
        if isinstance(close_col, pd.DataFrame): close_col = close_col.squeeze()
        # Conversion explicite en Series float64 alignée sur l'index du DataFrame
        high_col = cast(pd.Series, pd.Series(np.asarray(high_col).astype('float64'), index=df.index).copy())
        low_col = cast(pd.Series, pd.Series(np.asarray(low_col).astype('float64'), index=df.index).copy())
        close_col = cast(pd.Series, pd.Series(np.asarray(close_col).astype('float64'), index=df.index).copy())
        if all(isinstance(col, pd.Series) for col in [high_col, low_col, close_col]):
            kc = KeltnerChannel(
                high=high_col, low=low_col, close=close_col,
                window=params.get('window', 20),
                window_atr=params.get('window_atr', 10),
                multiplier=params.get('multiplier', 2)
            )
            df['kc_upper'] = kc.keltner_channel_hband()
            df['kc_middle'] = kc.keltner_channel_mband()
            df['kc_lower'] = kc.keltner_channel_lband()
    return df

def add_atr(df: pd.DataFrame, windows: Optional[List[int]] = None) -> pd.DataFrame:
    """Ajoute l'Average True Range."""
    if windows is None:
        windows = INDICATOR_PARAMS['atr']['windows']
    for window in windows if windows is not None else []:
        if all(col in df.columns for col in ['high', 'low', 'close']):
            # Si pas assez de bougies pour la fenêtre, remplir de NaN et continuer
            if len(df) < window:
                df[f'atr_{window}'] = pd.Series(np.nan, index=df.index)
                continue
            high_col = df['high']; low_col = df['low']; close_col = df['close']
            if isinstance(high_col, pd.DataFrame): high_col = high_col.squeeze()
            if isinstance(low_col, pd.DataFrame): low_col = low_col.squeeze()
            if isinstance(close_col, pd.DataFrame): close_col = close_col.squeeze()
            # Conversion explicite en Series
            high_col = pd.Series(high_col)
            low_col = pd.Series(low_col)
            close_col = pd.Series(close_col)
            if all(isinstance(col, pd.Series) for col in [high_col, low_col, close_col]):
                df[f'atr_{window}'] = average_true_range(high_col, low_col, close_col, window=window)
    return df

def add_adx(df: pd.DataFrame, params: Dict) -> pd.DataFrame:
    """Ajoute l'ADX (Average Directional Index)."""
    if all(col in df.columns for col in ['high', 'low', 'close']):
        high_col = df['high']; low_col = df['low']; close_col = df['close']
        if isinstance(high_col, pd.DataFrame): high_col = high_col.squeeze()
        if isinstance(low_col, pd.DataFrame): low_col = low_col.squeeze()
        if isinstance(close_col, pd.DataFrame): close_col = close_col.squeeze()
        # Conversion explicite en Series
        high_col = pd.Series(high_col)
        low_col = pd.Series(low_col)
        close_col = pd.Series(close_col)
        if all(isinstance(col, pd.Series) for col in [high_col, low_col, close_col]):
            window = params.get('window', 14)
            # Si pas assez de bougies pour la fenêtre, créer des colonnes NaN et sortir
            if len(df) < window:
                df['adx'] = pd.Series(np.nan, index=df.index)
                df['adx_pos'] = pd.Series(np.nan, index=df.index)
                df['adx_neg'] = pd.Series(np.nan, index=df.index)
                return df
            adx_ind = ADXIndicator(high=high_col, low=low_col, close=close_col, window=window)
            df['adx'] = adx_ind.adx()
            df['adx_pos'] = adx_ind.adx_pos()
            df['adx_neg'] = adx_ind.adx_neg()
    return df

def add_ichimoku(df: pd.DataFrame, params: Dict) -> pd.DataFrame:
    """Ajoute l'Ichimoku Cloud."""
    if all(col in df.columns for col in ['high', 'low']):
        high_col = df['high']; low_col = df['low']
        if isinstance(high_col, pd.DataFrame): high_col = high_col.squeeze()
        if isinstance(low_col, pd.DataFrame): low_col = low_col.squeeze()
        # Conversion explicite en Series
        high_col = pd.Series(high_col)
        low_col = pd.Series(low_col)
        if all(isinstance(col, pd.Series) for col in [high_col, low_col]):
            ichimoku = IchimokuIndicator(
                high=high_col, low=low_col,
                window1=params.get('window_conv', 9),
                window2=params.get('window_base', 26),
                window3=params.get('window_lag', 52)
            )
            df['ichimoku_a'] = ichimoku.ichimoku_a()
            df['ichimoku_b'] = ichimoku.ichimoku_b()
            df['ichimoku_base'] = ichimoku.ichimoku_base_line()
            df['ichimoku_conversion'] = ichimoku.ichimoku_conversion_line()
    return df

def add_volume_indicators(df: pd.DataFrame, params: Dict) -> pd.DataFrame:
    """Ajoute les indicateurs de volume."""
    if 'volume' not in df.columns:
        logger.warning("Colonne 'volume' manquante pour les indicateurs de volume.")
        return df
    
    # Volume moyen (SMA sur volume)
    df['volume_sma'] = df['volume'].rolling(window=params.get('sma_window', 20)).mean()
    
    # On Balance Volume (OBV)
    if 'close' in df.columns:
        close_col = df['close']
        if isinstance(close_col, pd.DataFrame): close_col = close_col.squeeze()
        if isinstance(close_col, pd.Series):
            df['obv'] = on_balance_volume(close_col, df['volume'])
    
    # VWAP (cumulatif)
    df['vwap'] = (df['close'] * df['volume']).cumsum() / df['volume'].cumsum()
    df['vwap'] = df['vwap'].replace([np.inf, -np.inf], np.nan).ffill().bfill()

    # Accumulation/Distribution Line
    if all(col in df.columns for col in ['high', 'low', 'close', 'volume']):
        high_col = df['high']; low_col = df['low']; close_col = df['close']; volume_col = df['volume']
        if isinstance(high_col, pd.DataFrame): high_col = high_col.squeeze()
        if isinstance(low_col, pd.DataFrame): low_col = low_col.squeeze()
        if isinstance(close_col, pd.DataFrame): close_col = close_col.squeeze()
        if isinstance(volume_col, pd.DataFrame): volume_col = volume_col.squeeze()
        # Conversion explicite en Series
        high_col = pd.Series(high_col)
        low_col = pd.Series(low_col)
        close_col = pd.Series(close_col)
        volume_col = pd.Series(volume_col)
        if all(isinstance(col, pd.Series) for col in [high_col, low_col, close_col, volume_col]):
            df['ad_line'] = acc_dist_index(high_col, low_col, close_col, volume_col)
    
    # Chaikin Money Flow
    if all(col in df.columns for col in ['high', 'low', 'close', 'volume']):
        high_col = df['high']; low_col = df['low']; close_col = df['close']; volume_col = df['volume']
        if isinstance(high_col, pd.DataFrame): high_col = high_col.squeeze()
        if isinstance(low_col, pd.DataFrame): low_col = low_col.squeeze()
        if isinstance(close_col, pd.DataFrame): close_col = close_col.squeeze()
        if isinstance(volume_col, pd.DataFrame): volume_col = volume_col.squeeze()
        # Conversion explicite en Series
        high_col = pd.Series(high_col)
        low_col = pd.Series(low_col)
        close_col = pd.Series(close_col)
        volume_col = pd.Series(volume_col)
        if all(isinstance(col, pd.Series) for col in [high_col, low_col, close_col, volume_col]):
            df['cmf'] = chaikin_money_flow(high_col, low_col, close_col, volume_col)
    
    return df

# --- Fonctions d'analyse plus générales (pour le contexte, moins pour le déclenchement direct du spike) ---

def add_support_resistance(df: pd.DataFrame) -> pd.DataFrame:
    """
    Ajoute des niveaux de support et résistance de base (basés sur Pivot Points).
    Pour le scalping, les swing highs/lows récents sont souvent plus pertinents.
    Les méthodes avancées de détection de SR devraient être dans `advanced_analysis.py`.
    """
    # Pivot Points sont généralement calculés sur des périodes plus longues (J/S/M)
    # Pour M1, cela peut être bruité, mais pour le principe :
    if not df.empty:
        # Penser à calculer le pivot pour la dernière journée entière si en M1/M5
        # Ici, calcul sur la dernière bougie, ce qui est très court-terme
        df['pivot'] = (df['high'] + df['low'] + df['close']) / 3
        df['r1'] = (2 * df['pivot']) - df['low']
        df['s1'] = (2 * df['pivot']) - df['high']
        df['r2'] = df['pivot'] + (df['high'] - df['low'])
        df['s2'] = df['pivot'] - (df['high'] - df['low'])
    else:
        df['pivot'] = np.nan
        df['r1'] = np.nan
        df['s1'] = np.nan
        df['r2'] = np.nan
        df['s2'] = np.nan
    return df

def get_support_resistance_zones(df, min_touches=2, tolerance=0.002):
    """
    Détecte les zones de support et de résistance dans un DataFrame OHLC.
    Version améliorée avec validation croisée et analyse de force.
    """
    try:
        # Import de la version avancée si disponible
        from backend.advanced_support_resistance import get_support_resistance_zones_advanced
        return get_support_resistance_zones_advanced(df)
    except ImportError:
        # Fallback vers l'ancienne méthode
        if df is None or df.empty:
            return []
        
        levels = []
        highs = df['high'].values
        lows = df['low'].values
        
        # 1. Détection des swing highs (résistances) et swing lows (supports)
        for i in range(2, len(df)-2):
            # Swing high
            if highs[i] > highs[i-1] and highs[i] > highs[i-2] and highs[i] > highs[i+1] and highs[i] > highs[i+2]:
                levels.append({'price': highs[i], 'type': 'resistance', 'method': 'swing_high'})
            # Swing low
            if lows[i] < lows[i-1] and lows[i] < lows[i-2] and lows[i] < lows[i+1] and lows[i] < lows[i+2]:
                levels.append({'price': lows[i], 'type': 'support', 'method': 'swing_low'})
        
        # 2. Regroupement des niveaux proches
        grouped = []
        for lvl in levels:
            found = False
            for g in grouped:
                if abs(lvl['price'] - g['price'])/g['price'] < tolerance and lvl['type'] == g['type']:
                    g['strength'] += 1
                    g['price'] = (g['price'] + lvl['price'])/2  # moyenne
                    g['methods'] = g.get('methods', [g.get('method', 'unknown')])
                    if lvl.get('method') not in g['methods']:
                        g['methods'].append(lvl.get('method', 'unknown'))
                    found = True
                    break
            if not found:
                grouped.append({
                    'price': lvl['price'], 
                    'type': lvl['type'], 
                    'strength': 1,
                    'methods': [lvl.get('method', 'unknown')]
                })
        
        # 3. Filtrer par nombre de touches
        zones = [g for g in grouped if g['strength'] >= min_touches]
        
        # 4. Tri par force et ajout d'informations
        for zone in zones:
            zone['confidence'] = min(zone['strength'] / 3, 1.0)  # Confiance basée sur la force
            zone['method'] = '+'.join(zone['methods'])
        
        zones.sort(key=lambda x: (-x['strength'], x['type']))
        return zones

def get_trend_analysis(df: pd.DataFrame) -> Dict:
    """
    Analyse la tendance et la force de la tendance basée sur des indicateurs clés.
    Plus utile pour le contexte général que pour les entrées scalping très courtes.
    """
    analysis = {}
    if df.empty or 'close' not in df.columns:
        return {'trend': 'UNKNOWN', 'trend_strength': 'UNKNOWN', 'momentum': 'UNKNOWN', 'volatility': 'UNKNOWN'}

    current_price = df['close'].iloc[-1] if df is not None and not df.empty else np.nan
    
    # Tendance basée sur les moyennes mobiles
    # Assurez-vous que les MAs nécessaires sont calculées.
    if 'sma_20' in df.columns and 'sma_50' in df.columns and len(df) >= 50:
        sma_20 = df['sma_20'].iloc[-1] if df is not None and not df.empty else np.nan
        sma_50 = df['sma_50'].iloc[-1] if df is not None and not df.empty else np.nan
        if pd.notna(sma_20) and pd.notna(sma_50):
            if current_price > sma_20 > sma_50:
                analysis['trend'] = 'BULLISH'
            elif current_price < sma_20 < sma_50:
                analysis['trend'] = 'BEARISH'
            elif abs(sma_20 - sma_50) < current_price * 0.001: # Check for close proximity
                analysis['trend'] = 'CONSOLIDATION'
            else:
                analysis['trend'] = 'NEUTRAL'
        else:
            analysis['trend'] = 'INSUFFICIENT_DATA'
    else:
        analysis['trend'] = 'MA_NOT_AVAILABLE'

    # Force de la tendance (ADX)
    if 'adx' in df.columns and len(df) >= INDICATOR_PARAMS['adx']['window']:
        adx = df['adx'].iloc[-1] if df is not None and not df.empty else np.nan
        if pd.notna(adx):
            if adx > 40:
                analysis['trend_strength'] = 'VERY_STRONG'
            elif adx > 25:
                analysis['trend_strength'] = 'STRONG'
            elif adx > 20:
                analysis['trend_strength'] = 'MODERATE'
            else:
                analysis['trend_strength'] = 'WEAK'
        else:
            analysis['trend_strength'] = 'INSUFFICIENT_DATA'
    else:
        analysis['trend_strength'] = 'ADX_NOT_AVAILABLE'

    # Momentum (RSI)
    if 'rsi_14' in df.columns and len(df) >= INDICATOR_PARAMS['rsi']['windows'][0]:
        rsi = df['rsi_14'].iloc[-1] if df is not None and not df.empty else np.nan
        if pd.notna(rsi):
            if rsi > 70:
                analysis['momentum'] = 'OVERBOUGHT'
            elif rsi < 30:
                analysis['momentum'] = 'OVERSOLD'
            else:
                analysis['momentum'] = 'NEUTRAL'
        else:
            analysis['momentum'] = 'INSUFFICIENT_DATA'
    else:
        analysis['momentum'] = 'RSI_NOT_AVAILABLE'
    
    # Volatilité (ATR)
    if 'atr_14' in df.columns and len(df) >= INDICATOR_PARAMS['atr']['windows'][0]:
        atr = df['atr_14'].iloc[-1] if df is not None and not df.empty else np.nan
        atr_history = df['atr_14'].dropna()
        if not atr_history.empty and pd.notna(atr):
            rolling_atr_mean = atr_history.tail(50).mean() # Compare to recent average ATR
            if rolling_atr_mean == 0: # Avoid division by zero
                analysis['volatility'] = 'STATIC'
            elif atr > rolling_atr_mean * 1.5:
                analysis['volatility'] = 'HIGH'
            elif atr < rolling_atr_mean * 0.5:
                analysis['volatility'] = 'LOW'
            else:
                analysis['volatility'] = 'NORMAL'
        else:
            analysis['volatility'] = 'INSUFFICIENT_DATA'
    else:
        analysis['volatility'] = 'ATR_NOT_AVAILABLE'

    return analysis


def generate_trading_signals(df: pd.DataFrame) -> List[Dict]:
    """
    Génère des signaux de trading basés sur l'analyse technique.
    Ces signaux sont des confirmations potentielles, le déclenchement principal des SPIKES
    devrait venir du `spike_detector.py`.
    """
    signals = []
    if df.empty:
      return signals

    # Get last valid index for current values quickly
    last_idx = df.index[-1]
    
    # Signal RSI (Rebond de zone de surachat/survente)
    if 'rsi_14' in df.columns and len(df) >= 2 and pd.notna(df['rsi_14'].iloc[-1]) and pd.notna(df['rsi_14'].iloc[-2]):
        rsi = df['rsi_14'].iloc[-1] if df is not None and not df.empty else np.nan
        rsi_prev = df['rsi_14'].iloc[-2] if df is not None and not df.empty else np.nan
        
        if rsi >= 30 and rsi_prev < 30: # Sortie de survente
            signals.append({'type': 'BUY', 'indicator': 'RSI', 'strength': 'STRONG', 'description': 'RSI sort de la zone de survente'})
        elif rsi <= 70 and rsi_prev > 70: # Sortie de surachat
            signals.append({'type': 'SELL', 'indicator': 'RSI', 'strength': 'STRONG', 'description': 'RSI sort de la zone de surachat'})
        elif rsi > 70: # RSI > 70 = VENTE (surachat)
            signals.append({'type': 'SELL', 'indicator': 'RSI', 'strength': 'STRONG', 'description': 'RSI en zone de surachat (>70)'})
        elif rsi < 30: # RSI < 30 = ACHAT (survente)
            signals.append({'type': 'BUY', 'indicator': 'RSI', 'strength': 'STRONG', 'description': 'RSI en zone de survente (<30)'})
    
    # Signal MACD (Croisement)
    if 'macd' in df.columns and 'macd_signal' in df.columns and len(df) >= 2 and \
       pd.notna(df['macd'].iloc[-1]) and pd.notna(df['macd_signal'].iloc[-1]) and \
       pd.notna(df['macd'].iloc[-2]) and pd.notna(df['macd_signal'].iloc[-2]):
        macd = df['macd'].iloc[-1] if df is not None and not df.empty else np.nan
        macd_signal = df['macd_signal'].iloc[-1] if df is not None and not df.empty else np.nan
        macd_prev = df['macd'].iloc[-2] if df is not None and not df.empty else np.nan
        macd_signal_prev = df['macd_signal'].iloc[-2] if df is not None and not df.empty else np.nan
        
        if macd > macd_signal and macd_prev <= macd_signal_prev:
            signals.append({'type': 'BUY', 'indicator': 'MACD', 'strength': 'MODERATE', 'description': 'MACD croise au-dessus du signal'})
        elif macd < macd_signal and macd_prev >= macd_signal_prev:
            signals.append({'type': 'SELL', 'indicator': 'MACD', 'strength': 'MODERATE', 'description': 'MACD croise en-dessous du signal'})
    
    # Signal Bollinger Bands (Touche les bandes)
    if 'bb_upper' in df.columns and 'bb_lower' in df.columns and len(df) >= 1 and \
       pd.notna(df['close'].iloc[-1]) and pd.notna(df['bb_upper'].iloc[-1]) and pd.notna(df['bb_lower'].iloc[-1]):
        close = df['close'].iloc[-1] if df is not None and not df.empty else np.nan
        bb_upper = df['bb_upper'].iloc[-1] if df is not None and not df.empty else np.nan
        bb_lower = df['bb_lower'].iloc[-1] if df is not None and not df.empty else np.nan
        
        if close < bb_lower: # Prix sous bande inférieure
            signals.append({'type': 'BUY', 'indicator': 'Bollinger', 'strength': 'STRONG', 'description': 'Prix sous la bande inférieure (potentiel rebond)'})
        elif close > bb_upper: # Prix au-dessus bande supérieure
            signals.append({'type': 'SELL', 'indicator': 'Bollinger', 'strength': 'STRONG', 'description': 'Prix au-dessus de la bande supérieure (potentiel retracement)'})
    
    return signals

# --- Backwards compatibility for older calls, ensuring they use the new structure ---
# This ensures that existing calls from app.py still work without major refactoring
# You might want to remove these wrappers once app.py is fully updated.
def get_support_resistance_levels(df: pd.DataFrame) -> Dict:
    """Wrapper avancé pour les niveaux de support et résistance."""
    try:
        # Utiliser la version avancée si disponible
        from backend.advanced_support_resistance import get_advanced_support_resistance
        advanced_levels = get_advanced_support_resistance(df)
        
        # Format de sortie enrichi
        levels = {
            'resistance': [],
            'support': [],
            'pivot_points': {},
            'advanced_analysis': advanced_levels
        }
        
        # Extraction des niveaux avancés
        if 'resistances' in advanced_levels:
            for res in advanced_levels['resistances']:
                levels['resistance'].append({
                    'price': res['price'],
                    'strength': res['strength'],
                    'method': res['method'],
                    'confidence': min(res['strength'] / 5, 1.0)
                })
        
        if 'supports' in advanced_levels:
            for sup in advanced_levels['supports']:
                levels['support'].append({
                    'price': sup['price'],
                    'strength': sup['strength'],
                    'method': sup['method'],
                    'confidence': min(sup['strength'] / 5, 1.0)
                })
        
        # Pivot Points classiques (fallback)
        if 'pivot' in df.columns and pd.notna(df['pivot'].iloc[-1]):
            levels['pivot_points'] = {
                'pivot': df['pivot'].iloc[-1],
                'r1': df['r1'].iloc[-1] if 'r1' in df.columns else np.nan,
                's1': df['s1'].iloc[-1] if 's1' in df.columns else np.nan,
                'r2': df['r2'].iloc[-1] if 'r2' in df.columns else np.nan,
                's2': df['s2'].iloc[-1] if 's2' in df.columns else np.nan
            }
        
        # Tri par force
        levels['resistance'].sort(key=lambda x: x['strength'], reverse=True)
        levels['support'].sort(key=lambda x: x['strength'], reverse=True)
        
        return levels
        
    except ImportError:
        # Fallback vers l'ancienne méthode
        levels = {}
        if df.empty: 
            return levels

        # Niveaux récents (swing highs/lows)
        window_for_extremes = min(len(df), 50)
        if window_for_extremes > 0:
            recent_highs = df['high'].iloc[-window_for_extremes:].nlargest(3)
            recent_lows = df['low'].iloc[-window_for_extremes:].nsmallest(3)
            
            levels['resistance'] = recent_highs.values.tolist()
            levels['support'] = recent_lows.values.tolist()

        # Pivot Points
        if 'pivot' in df.columns and pd.notna(df['pivot'].iloc[-1]):
            levels['pivot'] = df['pivot'].iloc[-1]
            if 'r1' in df.columns and pd.notna(df['r1'].iloc[-1]): 
                levels['r1'] = df['r1'].iloc[-1]
            if 's1' in df.columns and pd.notna(df['s1'].iloc[-1]): 
                levels['s1'] = df['s1'].iloc[-1]
            if 'r2' in df.columns and pd.notna(df['r2'].iloc[-1]): 
                levels['r2'] = df['r2'].iloc[-1]
            if 's2' in df.columns and pd.notna(df['s2'].iloc[-1]): 
                levels['s2'] = df['s2'].iloc[-1]

        return levels

def get_volatility_analysis(df: pd.DataFrame) -> Dict:
    """Wrapper for volatility analysis."""
    return get_trend_analysis(df).get('volatility_analysis', {}) # Get from combined analysis

def add_stair_pattern_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Ajoute des features pour détecter un pattern de consolidation en 'escalier'.
    Robuste aux NaN, types inattendus, et index non alignés.
    Features : ema_8, ema_21, ema_8_slope, normalized_atr, is_stair_step, stair_strength.
    """
    df_copy = df.copy()
    # Sécuriser les colonnes nécessaires
    for col in ['close', 'open', 'high', 'low']:
        if col not in df_copy.columns:
            df_copy[col] = np.nan
        if not isinstance(df_copy[col], pd.Series):
            df_copy[col] = pd.Series(df_copy[col], index=df_copy.index)
    # 1. EMA et pente
    df_copy['ema_8'] = pd.Series(df_copy['close']).ewm(span=8, adjust=False).mean()
    df_copy['ema_21'] = pd.Series(df_copy['close']).ewm(span=21, adjust=False).mean()
    df_copy['ema_8_slope'] = df_copy['ema_8'].diff()
    # 2. ATR normalisé (robuste)
    high_low = df_copy['high'] - df_copy['low']
    high_close = (df_copy['high'] - df_copy['close'].shift()).abs()
    low_close = (df_copy['low'] - df_copy['close'].shift()).abs()
    tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    df_copy['atr_14'] = tr.ewm(span=14, adjust=False).mean()
    with np.errstate(divide='ignore', invalid='ignore'):
        df_copy['normalized_atr'] = (df_copy['atr_14'] / df_copy['close']).replace([np.inf, -np.inf], np.nan) * 100
    # 3. Pattern escalier (robuste aux NaN)
    rolling_mean_atr = df_copy['normalized_atr'].rolling(50, min_periods=10).mean()
    is_stair_up_condition = (
        (df_copy['ema_8_slope'] > 0)
        & (df_copy['normalized_atr'] < rolling_mean_atr * 0.8)
        & (pd.Series(df_copy['close']) > pd.Series(df_copy['open'])).rolling(5, min_periods=3).sum() >= 3
    )
    tmp_stair = np.asarray(is_stair_up_condition).astype(int)
    if len(tmp_stair) != len(df_copy.index):
        raise ValueError("Taille incohérente entre tmp_stair et df_copy.index")
    df_copy['is_stair_step'] = pd.Series(tmp_stair, index=df_copy.index).fillna(0)
    # 4. Force du pattern (rolling robuste)
    df_copy['stair_strength'] = df_copy['is_stair_step'].rolling(window=10, min_periods=1).sum().fillna(0)
    # Nettoyage final
    for col in ['ema_8', 'ema_21', 'ema_8_slope', 'atr_14', 'normalized_atr', 'is_stair_step', 'stair_strength']:
        if col in df_copy.columns:
            df_copy[col] = df_copy[col].astype(float)
    return df_copy

def rsi(prices, window=14):
    import pandas as pd
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))