"""
Détecteur de setups de trading basé sur les stratégies de Vince Stanzione
Détecte automatiquement les patterns et signaux sur les graphiques
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

try:
    import talib
    TALIB_AVAILABLE = True
except ImportError:
    TALIB_AVAILABLE = False
    # Fallback functions si talib n'est pas disponible
    def RSI(close, timeperiod=14):
        delta = pd.Series(close).diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=timeperiod).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=timeperiod).mean()
        rs = gain / loss
        return 100 - (100 / (1 + rs))
    
    def MACD(close, fastperiod=12, slowperiod=26, signalperiod=9):
        ema_fast = pd.Series(close).ewm(span=fastperiod).mean()
        ema_slow = pd.Series(close).ewm(span=slowperiod).mean()
        macd = ema_fast - ema_slow
        signal = macd.ewm(span=signalperiod).mean()
        histogram = macd - signal
        return macd, signal, histogram
    
    def SMA(close, timeperiod):
        return pd.Series(close).rolling(window=timeperiod).mean()
    
    def EMA(close, timeperiod):
        return pd.Series(close).ewm(span=timeperiod).mean()
    
    def BBANDS(close, timeperiod=20, nbdevup=2, nbdevdn=2):
        sma = SMA(close, timeperiod)
        std = pd.Series(close).rolling(window=timeperiod).std()
        upper = sma + (std * nbdevup)
        lower = sma - (std * nbdevdn)
        return upper, sma, lower
    
    def STOCH(high, low, close, fastk_period=5, slowk_period=3, slowd_period=3):
        lowest_low = pd.Series(low).rolling(window=fastk_period).min()
        highest_high = pd.Series(high).rolling(window=fastk_period).max()
        k_percent = 100 * ((pd.Series(close) - lowest_low) / (highest_high - lowest_low))
        k_percent = k_percent.rolling(window=slowk_period).mean()
        d_percent = k_percent.rolling(window=slowd_period).mean()
        return k_percent, d_percent

class SetupDetector:
    """
    Détecteur de setups de trading pour les indices synthétiques
    Basé sur les stratégies de Vince Stanzione
    """
    
    def __init__(self):
        self.setups = {}
        self.signals = {}
        
    def detect_moving_average_crossover(self, df: pd.DataFrame, fast: int = 6, slow: int = 21) -> Dict:
        """
        Détecter les croisements de moyennes mobiles (stratégie 21/6 de Vince Stanzione)
        """
        df = df.copy()
        
        # Calculer les moyennes mobiles
        if TALIB_AVAILABLE:
            df['sma_fast'] = talib.SMA(df['close'].values, timeperiod=fast)
            df['sma_slow'] = talib.SMA(df['close'].values, timeperiod=slow)
        else:
            df['sma_fast'] = SMA(df['close'].values, fast)
            df['sma_slow'] = SMA(df['close'].values, slow)
        
        # Détecter les croisements
        df['crossover'] = 0
        df.loc[df['sma_fast'] > df['sma_slow'], 'crossover'] = 1  # Bullish
        df.loc[df['sma_fast'] < df['sma_slow'], 'crossover'] = -1  # Bearish
        
        # Détecter les changements de signal
        df['signal_change'] = df['crossover'].diff()
        
        # Identifier les signaux
        bullish_signals = df[df['signal_change'] == 2].index.tolist()
        bearish_signals = df[df['signal_change'] == -2].index.tolist()
        
        return {
            'type': 'moving_average_crossover',
            'bullish_signals': bullish_signals,
            'bearish_signals': bearish_signals,
            'current_trend': df['crossover'].iloc[-1],
            'strength': abs(df['sma_fast'].iloc[-1] - df['sma_slow'].iloc[-1]) / df['sma_slow'].iloc[-1]
        }
    
    def detect_rsi_signals(self, df: pd.DataFrame, period: int = 14) -> Dict:
        """
        Détecter les signaux RSI (survente/surachat)
        """
        df = df.copy()
        
        # Calculer RSI
        if TALIB_AVAILABLE:
            df['rsi'] = talib.RSI(df['close'].values, timeperiod=period)
        else:
            df['rsi'] = RSI(df['close'].values, period)
        
        # Détecter les signaux
        oversold_signals = df[df['rsi'] < 30].index.tolist()
        overbought_signals = df[df['rsi'] > 70].index.tolist()
        
        # Détecter les divergences
        df['price_high'] = df['close'].rolling(5).max()
        df['price_low'] = df['close'].rolling(5).min()
        df['rsi_high'] = df['rsi'].rolling(5).max()
        df['rsi_low'] = df['rsi'].rolling(5).min()
        
        # Divergence haussière (prix fait des plus bas, RSI fait des plus hauts)
        bullish_divergence = df[
            (df['price_low'] < df['price_low'].shift(10)) & 
            (df['rsi_low'] > df['rsi_low'].shift(10))
        ].index.tolist()
        
        # Divergence baissière (prix fait des plus hauts, RSI fait des plus bas)
        bearish_divergence = df[
            (df['price_high'] > df['price_high'].shift(10)) & 
            (df['rsi_high'] < df['rsi_high'].shift(10))
        ].index.tolist()
        
        return {
            'type': 'rsi_signals',
            'oversold_signals': oversold_signals,
            'overbought_signals': overbought_signals,
            'bullish_divergence': bullish_divergence,
            'bearish_divergence': bearish_divergence,
            'current_rsi': df['rsi'].iloc[-1],
            'signal': 'BUY' if df['rsi'].iloc[-1] < 30 else 'SELL' if df['rsi'].iloc[-1] > 70 else 'HOLD'
        }
    
    def detect_macd_signals(self, df: pd.DataFrame) -> Dict:
        """
        Détecter les signaux MACD
        """
        df = df.copy()
        
        # Calculer MACD
        if TALIB_AVAILABLE:
            df['macd'], df['macd_signal'], df['macd_hist'] = talib.MACD(df['close'].values)
        else:
            df['macd'], df['macd_signal'], df['macd_hist'] = MACD(df['close'].values)
        
        # Détecter les croisements
        df['macd_cross'] = 0
        df.loc[df['macd'] > df['macd_signal'], 'macd_cross'] = 1  # Bullish
        df.loc[df['macd'] < df['macd_signal'], 'macd_cross'] = -1  # Bearish
        
        # Détecter les changements de signal
        df['macd_signal_change'] = df['macd_cross'].diff()
        
        # Identifier les signaux
        bullish_signals = df[df['macd_signal_change'] == 2].index.tolist()
        bearish_signals = df[df['macd_signal_change'] == -2].index.tolist()
        
        # Détecter les divergences
        df['price_high'] = df['close'].rolling(5).max()
        df['price_low'] = df['close'].rolling(5).min()
        df['macd_high'] = df['macd'].rolling(5).max()
        df['macd_low'] = df['macd'].rolling(5).min()
        
        # Divergence haussière
        bullish_divergence = df[
            (df['price_low'] < df['price_low'].shift(10)) & 
            (df['macd_low'] > df['macd_low'].shift(10))
        ].index.tolist()
        
        # Divergence baissière
        bearish_divergence = df[
            (df['price_high'] > df['price_high'].shift(10)) & 
            (df['macd_high'] < df['macd_high'].shift(10))
        ].index.tolist()
        
        return {
            'type': 'macd_signals',
            'bullish_signals': bullish_signals,
            'bearish_signals': bearish_signals,
            'bullish_divergence': bullish_divergence,
            'bearish_divergence': bearish_divergence,
            'current_macd': df['macd'].iloc[-1],
            'current_signal': df['macd_signal'].iloc[-1],
            'current_hist': df['macd_hist'].iloc[-1],
            'signal': 'BUY' if df['macd'].iloc[-1] > df['macd_signal'].iloc[-1] else 'SELL'
        }
    
    def detect_bollinger_bands_signals(self, df: pd.DataFrame, period: int = 20, std: float = 2) -> Dict:
        """
        Détecter les signaux des bandes de Bollinger
        """
        df = df.copy()
        
        # Calculer les bandes de Bollinger
        if TALIB_AVAILABLE:
            df['bb_upper'], df['bb_middle'], df['bb_lower'] = talib.BBANDS(
                df['close'].values, timeperiod=period, nbdevup=std, nbdevdn=std
            )
        else:
            df['bb_upper'], df['bb_middle'], df['bb_lower'] = BBANDS(
                df['close'].values, timeperiod=period, nbdevup=std, nbdevdn=std
            )
        
        # Détecter les signaux
        squeeze_signals = df[df['bb_upper'] - df['bb_lower'] < df['bb_middle'] * 0.1].index.tolist()
        expansion_signals = df[df['bb_upper'] - df['bb_lower'] > df['bb_middle'] * 0.2].index.tolist()
        
        # Détecter les touches des bandes
        upper_touches = df[df['close'] >= df['bb_upper']].index.tolist()
        lower_touches = df[df['close'] <= df['bb_lower']].index.tolist()
        
        # Détecter les breakouts
        df['bb_breakout'] = 0
        df.loc[df['close'] > df['bb_upper'], 'bb_breakout'] = 1  # Bullish breakout
        df.loc[df['close'] < df['bb_lower'], 'bb_breakout'] = -1  # Bearish breakout
        
        # Détecter les changements de signal
        df['bb_signal_change'] = df['bb_breakout'].diff()
        
        # Identifier les signaux
        bullish_breakouts = df[df['bb_signal_change'] == 1].index.tolist()
        bearish_breakouts = df[df['bb_signal_change'] == -1].index.tolist()
        
        return {
            'type': 'bollinger_bands_signals',
            'squeeze_signals': squeeze_signals,
            'expansion_signals': expansion_signals,
            'upper_touches': upper_touches,
            'lower_touches': lower_touches,
            'bullish_breakouts': bullish_breakouts,
            'bearish_breakouts': bearish_breakouts,
            'current_bb_position': (df['close'].iloc[-1] - df['bb_lower'].iloc[-1]) / (df['bb_upper'].iloc[-1] - df['bb_lower'].iloc[-1]),
            'bb_width': (df['bb_upper'].iloc[-1] - df['bb_lower'].iloc[-1]) / df['bb_middle'].iloc[-1],
            'signal': 'BUY' if df['close'].iloc[-1] <= df['bb_lower'].iloc[-1] else 'SELL' if df['close'].iloc[-1] >= df['bb_upper'].iloc[-1] else 'HOLD'
        }
    
    def detect_donchian_channels_signals(self, df: pd.DataFrame, period: int = 20) -> Dict:
        """
        Détecter les signaux des canaux de Donchian (stratégie 4-week rule)
        """
        df = df.copy()
        
        # Calculer les canaux de Donchian
        df['donchian_high'] = df['high'].rolling(period).max()
        df['donchian_low'] = df['low'].rolling(period).min()
        df['donchian_mid'] = (df['donchian_high'] + df['donchian_low']) / 2
        
        # Détecter les breakouts
        df['donchian_breakout'] = 0
        df.loc[df['close'] > df['donchian_high'], 'donchian_breakout'] = 1  # Bullish breakout
        df.loc[df['close'] < df['donchian_low'], 'donchian_breakout'] = -1  # Bearish breakout
        
        # Détecter les changements de signal
        df['donchian_signal_change'] = df['donchian_breakout'].diff()
        
        # Identifier les signaux
        bullish_breakouts = df[df['donchian_signal_change'] == 1].index.tolist()
        bearish_breakouts = df[df['donchian_signal_change'] == -1].index.tolist()
        
        # Détecter les retours vers le milieu
        df['donchian_reversion'] = 0
        df.loc[df['close'] < df['donchian_mid'], 'donchian_reversion'] = -1  # Bearish
        df.loc[df['close'] > df['donchian_mid'], 'donchian_reversion'] = 1  # Bullish
        
        return {
            'type': 'donchian_channels_signals',
            'bullish_breakouts': bullish_breakouts,
            'bearish_breakouts': bearish_breakouts,
            'current_position': (df['close'].iloc[-1] - df['donchian_low'].iloc[-1]) / (df['donchian_high'].iloc[-1] - df['donchian_low'].iloc[-1]),
            'channel_width': df['donchian_high'].iloc[-1] - df['donchian_low'].iloc[-1],
            'signal': 'BUY' if df['close'].iloc[-1] > df['donchian_high'].iloc[-1] else 'SELL' if df['close'].iloc[-1] < df['donchian_low'].iloc[-1] else 'HOLD'
        }
    
    def detect_stochastic_signals(self, df: pd.DataFrame, k_period: int = 5, d_period: int = 3) -> Dict:
        """
        Détecter les signaux Stochastic (pour le scalping)
        """
        df = df.copy()
        
        # Calculer Stochastic
        if TALIB_AVAILABLE:
            df['stoch_k'], df['stoch_d'] = talib.STOCH(
                df['high'].values, df['low'].values, df['close'].values,
                fastk_period=k_period, slowk_period=d_period, slowd_period=d_period
            )
        else:
            df['stoch_k'], df['stoch_d'] = STOCH(
                df['high'].values, df['low'].values, df['close'].values,
                fastk_period=k_period, slowk_period=d_period, slowd_period=d_period
            )
        
        # Détecter les signaux
        oversold_signals = df[df['stoch_k'] < 20].index.tolist()
        overbought_signals = df[df['stoch_k'] > 80].index.tolist()
        
        # Détecter les croisements
        df['stoch_cross'] = 0
        df.loc[df['stoch_k'] > df['stoch_d'], 'stoch_cross'] = 1  # Bullish
        df.loc[df['stoch_k'] < df['stoch_d'], 'stoch_cross'] = -1  # Bearish
        
        # Détecter les changements de signal
        df['stoch_signal_change'] = df['stoch_cross'].diff()
        
        # Identifier les signaux
        bullish_signals = df[df['stoch_signal_change'] == 2].index.tolist()
        bearish_signals = df[df['stoch_signal_change'] == -2].index.tolist()
        
        return {
            'type': 'stochastic_signals',
            'oversold_signals': oversold_signals,
            'overbought_signals': overbought_signals,
            'bullish_signals': bullish_signals,
            'bearish_signals': bearish_signals,
            'current_k': df['stoch_k'].iloc[-1],
            'current_d': df['stoch_d'].iloc[-1],
            'signal': 'BUY' if df['stoch_k'].iloc[-1] < 20 and df['stoch_k'].iloc[-1] > df['stoch_d'].iloc[-1] else 'SELL' if df['stoch_k'].iloc[-1] > 80 and df['stoch_k'].iloc[-1] < df['stoch_d'].iloc[-1] else 'HOLD'
        }
    
    def detect_support_resistance_zones(self, df: pd.DataFrame, window: int = 50) -> Dict:
        """
        Détecter les zones de support et résistance confirmées avec validation avancée
        """
        df = df.copy()
        
        if len(df) < window:
            return {
                'type': 'support_resistance_zones',
                'resistance_zones': [],
                'support_zones': [],
                'nearest_resistance_zone': None,
                'nearest_support_zone': None,
                'confidence': 'low'
            }
        
        # Calculer les pivots avec une fenêtre plus large
        df['pivot_high'] = df['high'].rolling(window, center=True).max()
        df['pivot_low'] = df['low'].rolling(window, center=True).min()
        
        # Identifier les niveaux de support et résistance potentiels
        resistance_candidates = df[df['high'] == df['pivot_high']]['high'].tolist()
        support_candidates = df[df['low'] == df['pivot_low']]['low'].tolist()
        
        # Validation des niveaux : compter les touches
        current_price = df['close'].iloc[-1]
        tolerance = current_price * 0.0002  # 0.02% de tolérance (très strict pour précision)
        min_touches = 3  # Minimum 3 touches pour confirmation
        
        # Largeur de zone très serrée : maximum 4 pips (0.0004 pour la plupart des paires)
        # Pour les indices synthétiques, on utilise un pourcentage très petit
        if 'Index' in str(df.get('symbol', '')) or 'BOOM' in str(df.get('symbol', '')) or 'CRASH' in str(df.get('symbol', '')):
            zone_width = current_price * 0.0001  # 0.01% pour les indices synthétiques (≈ 2-4 pips)
        else:
            zone_width = current_price * 0.0004  # 0.04% pour le forex (≈ 4 pips)
        
        def validate_levels(levels, price_type='high'):
            validated_zones = []
            for level in levels:
                touches = 0
                # Compter les touches dans les 20 dernières périodes
                recent_data = df.tail(20)
                for idx, row in recent_data.iterrows():
                    if price_type == 'high':
                        if abs(row['high'] - level) / level <= tolerance:
                            touches += 1
                        if abs(row['low'] - level) / level <= tolerance:
                            touches += 1
                    else:  # support
                        if abs(row['high'] - level) / level <= tolerance:
                            touches += 1
                        if abs(row['low'] - level) / level <= tolerance:
                            touches += 1
                
                if touches >= min_touches:
                    # Créer une zone autour du niveau
                    strength = min(touches / 5.0, 1.0)  # Force de 0 à 1
                    confidence = min(touches / 10.0, 1.0)  # Confiance basée sur les touches
                    
                    zone = {
                        'level': level,
                        'upper': level + zone_width,
                        'lower': level - zone_width,
                        'touches': touches,
                        'strength': strength,
                        'confidence': confidence,
                        'is_high_confidence': confidence >= 0.9  # Plus de 90% de confiance
                    }
                    validated_zones.append(zone)
            
            return validated_zones
        
        # Valider les niveaux et créer les zones
        resistance_zones = validate_levels(resistance_candidates, 'high')
        support_zones = validate_levels(support_candidates, 'low')
        
        # Filtrer les zones trop proches du prix actuel (distance minimale plus petite)
        resistance_zones = [z for z in resistance_zones if z['level'] > current_price * 1.0005]  # Au moins 0.05% au-dessus
        support_zones = [z for z in support_zones if z['level'] < current_price * 0.9995]  # Au moins 0.05% en-dessous
        
        # Trier par confiance puis par force (nombre de touches)
        resistance_zones.sort(key=lambda x: (x['confidence'], x['touches']), reverse=True)
        support_zones.sort(key=lambda x: (x['confidence'], x['touches']), reverse=True)
        
        # Trouver les zones les plus proches
        nearest_resistance_zone = min(resistance_zones, key=lambda x: x['level'], default=None)
        nearest_support_zone = max(support_zones, key=lambda x: x['level'], default=None)
        
        # Calculer la confiance
        confidence = 'high' if len(resistance_zones) > 0 or len(support_zones) > 0 else 'low'
        
        # Détecter les breakouts
        resistance_breakouts = df[df['close'] > df['pivot_high']].index.tolist()
        support_breakouts = df[df['close'] < df['pivot_low']].index.tolist()
        
        return {
            'type': 'support_resistance_zones',
            'resistance_zones': resistance_zones,
            'support_zones': support_zones,
            'nearest_resistance_zone': nearest_resistance_zone,
            'nearest_support_zone': nearest_support_zone,
            'resistance_breakouts': resistance_breakouts,
            'support_breakouts': support_breakouts,
            'current_price': current_price,
            'distance_to_resistance': (nearest_resistance_zone['level'] - current_price) / current_price if nearest_resistance_zone else None,
            'distance_to_support': (current_price - nearest_support_zone['level']) / current_price if nearest_support_zone else None,
            'confidence': confidence,
            'touches_count': {
                'resistance': len(resistance_zones),
                'support': len(support_zones)
            }
        }
    
    def detect_candlestick_patterns(self, df: pd.DataFrame) -> Dict:
        """
        Détecter les patterns de chandeliers japonais
        """
        df = df.copy()
        
        # Détecter les patterns de retournement
        hammer_signals = []
        doji_signals = []
        engulfing_signals = []
        
        for i in range(1, len(df)):
            # Hammer
            if (df['close'].iloc[i] > df['open'].iloc[i] and  # Bougie haussière
                df['low'].iloc[i] < min(df['open'].iloc[i], df['close'].iloc[i]) - 2 * (df['close'].iloc[i] - df['open'].iloc[i]) and  # Longue mèche basse
                df['high'].iloc[i] - max(df['open'].iloc[i], df['close'].iloc[i]) < (df['close'].iloc[i] - df['open'].iloc[i]) / 2):  # Petite mèche haute
                hammer_signals.append(df.index[i])
            
            # Doji
            if abs(df['close'].iloc[i] - df['open'].iloc[i]) < (df['high'].iloc[i] - df['low'].iloc[i]) * 0.1:
                doji_signals.append(df.index[i])
            
            # Engulfing
            if (df['close'].iloc[i] > df['open'].iloc[i] and  # Bougie haussière
                df['close'].iloc[i-1] < df['open'].iloc[i-1] and  # Bougie baissière précédente
                df['open'].iloc[i] < df['close'].iloc[i-1] and  # Ouverture en dessous de la clôture précédente
                df['close'].iloc[i] > df['open'].iloc[i-1]):  # Clôture au-dessus de l'ouverture précédente
                engulfing_signals.append(df.index[i])
        
        return {
            'type': 'candlestick_patterns',
            'hammer_signals': hammer_signals,
            'doji_signals': doji_signals,
            'engulfing_signals': engulfing_signals,
            'recent_patterns': {
                'hammer': len([s for s in hammer_signals if s >= df.index[-10]]),
                'doji': len([s for s in doji_signals if s >= df.index[-10]]),
                'engulfing': len([s for s in engulfing_signals if s >= df.index[-10]])
            }
        }
    
    def detect_boom_crash_momentum(self, df: pd.DataFrame) -> Dict:
        """
        Détecter les mouvements rapides spécifiques aux indices Boom/Crash
        """
        df = df.copy()
        
        # Calculer les variations de prix rapides
        df['price_change_1'] = df['close'].pct_change(1)  # 1 période
        df['price_change_3'] = df['close'].pct_change(3)  # 3 périodes
        df['price_change_5'] = df['close'].pct_change(5)  # 5 périodes
        
        # Calculer la volatilité rapide
        df['volatility_3'] = df['close'].rolling(3).std()
        df['volatility_5'] = df['close'].rolling(5).std()
        
        # Détecter les spikes (mouvements rapides)
        spike_threshold = 0.01  # 1% de variation
        df['is_spike_up'] = df['price_change_1'] > spike_threshold
        df['is_spike_down'] = df['price_change_1'] < -spike_threshold
        
        # Détecter les tendances rapides
        df['trend_3'] = df['price_change_3'].rolling(3).mean()
        df['trend_5'] = df['price_change_5'].rolling(5).mean()
        
        # Signaux de momentum
        current_price_change = df['price_change_1'].iloc[-1]
        current_trend_3 = df['trend_3'].iloc[-1]
        current_trend_5 = df['trend_5'].iloc[-1]
        current_volatility = df['volatility_3'].iloc[-1]
        
        # Déterminer le signal
        signal = 'HOLD'
        strength = 0.5
        
        if current_price_change > spike_threshold and current_trend_3 > 0:
            signal = 'BUY'
            strength = min(0.9, 0.5 + abs(current_price_change) * 10)
        elif current_price_change < -spike_threshold and current_trend_3 < 0:
            signal = 'SELL'
            strength = min(0.9, 0.5 + abs(current_price_change) * 10)
        elif current_trend_3 > 0.005:  # Tendance haussière
            signal = 'BUY'
            strength = 0.6
        elif current_trend_3 < -0.005:  # Tendance baissière
            signal = 'SELL'
            strength = 0.6
        
        return {
            'type': 'boom_crash_momentum',
            'current_price_change': current_price_change,
            'current_trend_3': current_trend_3,
            'current_trend_5': current_trend_5,
            'current_volatility': current_volatility,
            'signal': signal,
            'strength': strength,
            'is_spike': df['is_spike_up'].iloc[-1] or df['is_spike_down'].iloc[-1],
            'spike_direction': 'UP' if df['is_spike_up'].iloc[-1] else 'DOWN' if df['is_spike_down'].iloc[-1] else 'NONE'
        }
    
    def detect_all_setups(self, df: pd.DataFrame) -> Dict:
        """
        Détecter tous les setups de trading
        """
        setups = {}
        
        # Détecter tous les types de setups
        setups['moving_average'] = self.detect_moving_average_crossover(df)
        setups['rsi'] = self.detect_rsi_signals(df)
        setups['macd'] = self.detect_macd_signals(df)
        setups['bollinger_bands'] = self.detect_bollinger_bands_signals(df)
        setups['donchian_channels'] = self.detect_donchian_channels_signals(df)
        setups['stochastic'] = self.detect_stochastic_signals(df)
        setups['support_resistance_zones'] = self.detect_support_resistance_zones(df)
        setups['candlestick_patterns'] = self.detect_candlestick_patterns(df)
        
        # Détection spécialisée pour Boom/Crash
        setups['boom_crash_momentum'] = self.detect_boom_crash_momentum(df)
        
        # Calculer un score composite
        setups['composite_score'] = self._calculate_composite_score(setups)
        
        return setups
    
    def _calculate_composite_score(self, setups: Dict) -> Dict:
        """
        Calculer un score composite basé sur tous les setups
        """
        score = 0
        signals = []
        
        # Analyser chaque setup
        for setup_type, setup_data in setups.items():
            if setup_type == 'composite_score':
                continue
                
            if 'signal' in setup_data:
                signal = setup_data['signal']
                if signal == 'BUY':
                    score += 1
                    signals.append(f"{setup_type}: BUY")
                elif signal == 'SELL':
                    score -= 1
                    signals.append(f"{setup_type}: SELL")
        
        # Déterminer le signal composite
        if score > 2:
            composite_signal = 'STRONG_BUY'
        elif score > 0:
            composite_signal = 'BUY'
        elif score < -2:
            composite_signal = 'STRONG_SELL'
        elif score < 0:
            composite_signal = 'SELL'
        else:
            composite_signal = 'HOLD'
        
        return {
            'score': score,
            'signal': composite_signal,
            'signals': signals,
            'confidence': min(abs(score) / 5, 1.0)  # Confiance entre 0 et 1
        }
    
    def get_trading_recommendations(self, df: pd.DataFrame) -> Dict:
        """
        Obtenir des recommandations de trading basées sur tous les setups
        """
        setups = self.detect_all_setups(df)
        composite = setups['composite_score']
        
        recommendations = {
            'action': composite['signal'],
            'confidence': composite['confidence'],
            'score': composite['score'],
            'signals': composite['signals'],
            'details': setups
        }
        
        # Ajouter des recommandations spécifiques
        if composite['signal'] in ['BUY', 'STRONG_BUY']:
            recommendations['entry_strategy'] = 'Look for pullback to moving average or support level'
            recommendations['stop_loss'] = 'Below recent swing low or support level'
            recommendations['take_profit'] = 'At resistance level or 2:1 risk/reward ratio'
        elif composite['signal'] in ['SELL', 'STRONG_SELL']:
            recommendations['entry_strategy'] = 'Look for pullback to moving average or resistance level'
            recommendations['stop_loss'] = 'Above recent swing high or resistance level'
            recommendations['take_profit'] = 'At support level or 2:1 risk/reward ratio'
        else:
            recommendations['entry_strategy'] = 'Wait for clearer signal or trade range-bound'
            recommendations['stop_loss'] = 'N/A'
            recommendations['take_profit'] = 'N/A'
        
        return recommendations
