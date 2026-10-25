import pandas as pd
import numpy as np
from typing import Dict, List, Tuple
import warnings
warnings.filterwarnings('ignore')

class AdvancedSpikePredictor:
    """
    Prédicteur avancé de spikes basé sur la confluence des EMA et indicateurs
    """
    
    def __init__(self):
        self.ema_periods = [5, 15, 29, 50, 75, 80, 95, 90]
        self.spike_thresholds = {
            'high': 0.02,      # 2% pour spike haut
            'medium': 0.01,    # 1% pour spike moyen
            'low': 0.005       # 0.5% pour spike bas
        }
        self.confluence_weights = {
            'ema_alignment': 0.3,
            'momentum': 0.25,
            'volatility': 0.2,
            'volume': 0.15,
            'bollinger_position': 0.1
        }
    
    def calculate_ema_confluence(self, df: pd.DataFrame) -> Dict:
        """
        Calculer la confluence des EMA pour détecter les setups de spike
        """
        # Calculer toutes les EMA
        emas = {}
        for period in self.ema_periods:
            emas[f'ema_{period}'] = df['close'].ewm(span=period).mean()
        
        # Position actuelle du prix par rapport aux EMA
        current_price = df['close'].iloc[-1]
        ema_positions = {}
        
        for period in self.ema_periods:
            ema_value = emas[f'ema_{period}'].iloc[-1]
            ema_positions[f'ema_{period}'] = {
                'value': ema_value,
                'above': current_price > ema_value,
                'distance': (current_price - ema_value) / ema_value * 100
            }
        
        # Détecter l'alignement des EMA (tendance forte)
        ema_values = [emas[f'ema_{period}'].iloc[-1] for period in self.ema_periods]
        
        # Alignement haussier (EMA courtes > EMA longues)
        bullish_alignment = all(ema_values[i] > ema_values[i+1] for i in range(len(ema_values)-1))
        
        # Alignement baissier (EMA courtes < EMA longues)
        bearish_alignment = all(ema_values[i] < ema_values[i+1] for i in range(len(ema_values)-1))
        
        # Détecter les croisements récents
        recent_crosses = self._detect_ema_crosses(df, emas)
        
        # Calculer la force de confluence
        confluence_strength = self._calculate_confluence_strength(ema_positions, recent_crosses)
        
        return {
            'ema_positions': ema_positions,
            'bullish_alignment': bullish_alignment,
            'bearish_alignment': bearish_alignment,
            'recent_crosses': recent_crosses,
            'confluence_strength': confluence_strength,
            'trend_direction': 'BULLISH' if bullish_alignment else 'BEARISH' if bearish_alignment else 'NEUTRAL'
        }
    
    def _detect_ema_crosses(self, df: pd.DataFrame, emas: Dict) -> List[Dict]:
        """
        Détecter les croisements d'EMA récents
        """
        crosses = []
        
        # Croisements entre EMA 8 et 21 (signaux rapides)
        if 'ema_8' in emas and 'ema_21' in emas:
            ema_8 = emas['ema_8']
            ema_21 = emas['ema_21']
            
            # Croisement haussier (EMA 8 > EMA 21)
            if len(ema_8) > 1 and len(ema_21) > 1:
                if ema_8.iloc[-1] > ema_21.iloc[-1] and ema_8.iloc[-2] <= ema_21.iloc[-2]:
                    crosses.append({
                        'type': 'BULLISH_CROSS',
                        'fast': 'EMA 8',
                        'slow': 'EMA 21',
                        'strength': 'HIGH'
                    })
                
                # Croisement baissier (EMA 8 < EMA 21)
                elif ema_8.iloc[-1] < ema_21.iloc[-1] and ema_8.iloc[-2] >= ema_21.iloc[-2]:
                    crosses.append({
                        'type': 'BEARISH_CROSS',
                        'fast': 'EMA 8',
                        'slow': 'EMA 21',
                        'strength': 'HIGH'
                    })
        
        # Croisements entre EMA 21 et 55 (signaux moyens)
        if 'ema_21' in emas and 'ema_55' in emas:
            ema_21 = emas['ema_21']
            ema_55 = emas['ema_55']
            
            if len(ema_21) > 1 and len(ema_55) > 1:
                if ema_21.iloc[-1] > ema_55.iloc[-1] and ema_21.iloc[-2] <= ema_55.iloc[-2]:
                    crosses.append({
                        'type': 'BULLISH_CROSS',
                        'fast': 'EMA 21',
                        'slow': 'EMA 55',
                        'strength': 'MEDIUM'
                    })
                elif ema_21.iloc[-1] < ema_55.iloc[-1] and ema_21.iloc[-2] >= ema_55.iloc[-2]:
                    crosses.append({
                        'type': 'BEARISH_CROSS',
                        'fast': 'EMA 21',
                        'slow': 'EMA 55',
                        'strength': 'MEDIUM'
                    })
        
        return crosses
    
    def _calculate_confluence_strength(self, ema_positions: Dict, recent_crosses: List[Dict]) -> float:
        """
        Calculer la force de confluence des EMA
        """
        strength = 0.0
        
        # Points pour l'alignement
        above_count = sum(1 for pos in ema_positions.values() if pos['above'])
        total_count = len(ema_positions)
        
        if above_count == total_count:  # Toutes les EMA en dessous (haussier)
            strength += 0.4
        elif above_count == 0:  # Toutes les EMA au-dessus (baissier)
            strength += 0.4
        elif above_count > total_count / 2:  # Majorité haussière
            strength += 0.2
        else:  # Majorité baissière
            strength += 0.2
        
        # Points pour les croisements récents
        for cross in recent_crosses:
            if cross['strength'] == 'HIGH':
                strength += 0.3
            elif cross['strength'] == 'MEDIUM':
                strength += 0.2
        
        return min(strength, 1.0)
    
    def calculate_momentum_signals(self, df: pd.DataFrame) -> Dict:
        """
        Calculer les signaux de momentum pour prédire les spikes
        """
        # RSI pour momentum
        rsi = self._calculate_rsi(df['close'], 14)
        
        # MACD pour momentum
        macd_line, macd_signal, macd_histogram = self._calculate_macd(df['close'])
        
        # Momentum sur différentes périodes
        momentum_5 = df['close'].pct_change(5).iloc[-1]
        momentum_10 = df['close'].pct_change(10).iloc[-1]
        momentum_20 = df['close'].pct_change(20).iloc[-1]
        
        # Détecter les divergences
        price_highs = df['high'].rolling(5).max()
        price_lows = df['low'].rolling(5).min()
        rsi_highs = rsi.rolling(5).max()
        rsi_lows = rsi.rolling(5).min()
        
        # Divergence haussière (prix fait des plus bas, RSI fait des plus hauts)
        bullish_divergence = (price_lows.iloc[-1] < price_lows.iloc[-10] and 
                             rsi_lows.iloc[-1] > rsi_lows.iloc[-10])
        
        # Divergence baissière (prix fait des plus hauts, RSI fait des plus bas)
        bearish_divergence = (price_highs.iloc[-1] > price_highs.iloc[-10] and 
                             rsi_highs.iloc[-1] < rsi_highs.iloc[-10])
        
        # Force du momentum
        momentum_strength = abs(momentum_5) + abs(momentum_10) * 0.5 + abs(momentum_20) * 0.25
        
        return {
            'rsi': rsi.iloc[-1],
            'macd_line': macd_line.iloc[-1],
            'macd_signal': macd_signal.iloc[-1],
            'macd_histogram': macd_histogram.iloc[-1],
            'momentum_5': momentum_5,
            'momentum_10': momentum_10,
            'momentum_20': momentum_20,
            'momentum_strength': momentum_strength,
            'bullish_divergence': bullish_divergence,
            'bearish_divergence': bearish_divergence,
            'rsi_oversold': rsi.iloc[-1] < 30,
            'rsi_overbought': rsi.iloc[-1] > 70
        }
    
    def calculate_volatility_signals(self, df: pd.DataFrame) -> Dict:
        """
        Calculer les signaux de volatilité pour prédire les spikes
        """
        # Bollinger Bands
        sma_20 = df['close'].rolling(20).mean()
        std_20 = df['close'].rolling(20).std()
        bb_upper = sma_20 + (std_20 * 2)
        bb_lower = sma_20 - (std_20 * 2)
        bb_width = (bb_upper - bb_lower) / sma_20
        
        # ATR pour volatilité
        atr = self._calculate_atr(df, 14)
        
        # Volatilité récente
        recent_volatility = df['close'].pct_change().rolling(20).std().iloc[-1]
        historical_volatility = df['close'].pct_change().rolling(50).std().iloc[-1]
        
        # Position dans les Bollinger Bands
        current_price = df['close'].iloc[-1]
        bb_position = (current_price - bb_lower.iloc[-1]) / (bb_upper.iloc[-1] - bb_lower.iloc[-1])
        
        # Détecter la compression (squeeze)
        bb_squeeze = bb_width.iloc[-1] < bb_width.rolling(50).mean().iloc[-1] * 0.8
        
        # Détecter l'expansion
        bb_expansion = bb_width.iloc[-1] > bb_width.rolling(50).mean().iloc[-1] * 1.2
        
        return {
            'bb_upper': bb_upper.iloc[-1],
            'bb_lower': bb_lower.iloc[-1],
            'bb_middle': sma_20.iloc[-1],
            'bb_width': bb_width.iloc[-1],
            'bb_position': bb_position,
            'atr': atr.iloc[-1],
            'recent_volatility': recent_volatility,
            'historical_volatility': historical_volatility,
            'volatility_ratio': recent_volatility / historical_volatility if historical_volatility > 0 else 1,
            'bb_squeeze': bb_squeeze,
            'bb_expansion': bb_expansion,
            'near_bb_upper': bb_position > 0.8,
            'near_bb_lower': bb_position < 0.2
        }
    
    def calculate_volume_signals(self, df: pd.DataFrame) -> Dict:
        """
        Calculer les signaux de volume pour confirmer les spikes
        """
        if 'volume' not in df.columns:
            return {'volume_available': False}
        
        # Volume moyen
        volume_ma_20 = df['volume'].rolling(20).mean()
        volume_ma_50 = df['volume'].rolling(50).mean()
        
        # Volume actuel vs moyennes
        current_volume = df['volume'].iloc[-1]
        volume_ratio_20 = current_volume / volume_ma_20.iloc[-1] if volume_ma_20.iloc[-1] > 0 else 1
        volume_ratio_50 = current_volume / volume_ma_50.iloc[-1] if volume_ma_50.iloc[-1] > 0 else 1
        
        # Détecter les pics de volume
        volume_spike = volume_ratio_20 > 2.0  # Volume 2x la moyenne
        volume_surge = volume_ratio_20 > 1.5  # Volume 1.5x la moyenne
        
        # Volume en tendance
        volume_trend = df['volume'].rolling(10).mean().iloc[-1] / df['volume'].rolling(10).mean().iloc[-10]
        
        return {
            'volume_available': True,
            'current_volume': current_volume,
            'volume_ma_20': volume_ma_20.iloc[-1],
            'volume_ma_50': volume_ma_50.iloc[-1],
            'volume_ratio_20': volume_ratio_20,
            'volume_ratio_50': volume_ratio_50,
            'volume_spike': volume_spike,
            'volume_surge': volume_surge,
            'volume_trend': volume_trend,
            'high_volume': volume_ratio_20 > 1.2
        }
    
    def predict_spike(self, df: pd.DataFrame) -> Dict:
        """
        Prédire les spikes avec haute précision basé sur la confluence des indicateurs
        """
        if len(df) < 200:
            return {'spike_prediction': 'INSUFFICIENT_DATA', 'confidence': 0.0}
        
        # Calculer tous les signaux
        ema_confluence = self.calculate_ema_confluence(df)
        momentum_signals = self.calculate_momentum_signals(df)
        volatility_signals = self.calculate_volatility_signals(df)
        volume_signals = self.calculate_volume_signals(df)
        
        # Score de confluence
        confluence_score = 0.0
        
        # 1. Confluence des EMA (30%)
        ema_score = ema_confluence['confluence_strength']
        confluence_score += ema_score * self.confluence_weights['ema_alignment']
        
        # 2. Momentum (25%)
        momentum_score = 0.0
        if momentum_signals['rsi_oversold'] and momentum_signals['bullish_divergence']:
            momentum_score += 0.5
        elif momentum_signals['rsi_overbought'] and momentum_signals['bearish_divergence']:
            momentum_score += 0.5
        
        if momentum_signals['momentum_strength'] > 0.02:  # Momentum fort
            momentum_score += 0.3
        
        if momentum_signals['macd_histogram'] > 0 and momentum_signals['macd_line'] > momentum_signals['macd_signal']:
            momentum_score += 0.2  # MACD haussier
        
        confluence_score += momentum_score * self.confluence_weights['momentum']
        
        # 3. Volatilité (20%)
        volatility_score = 0.0
        if volatility_signals['bb_squeeze']:  # Compression = explosion imminente
            volatility_score += 0.4
        elif volatility_signals['bb_expansion']:  # Déjà en expansion
            volatility_score += 0.2
        
        if volatility_signals['near_bb_upper'] or volatility_signals['near_bb_lower']:  # Proche des bandes
            volatility_score += 0.3
        
        if volatility_signals['volatility_ratio'] > 1.5:  # Volatilité élevée
            volatility_score += 0.3
        
        confluence_score += volatility_score * self.confluence_weights['volatility']
        
        # 4. Volume (15%)
        volume_score = 0.0
        if volume_signals.get('volume_available', False):
            if volume_signals['volume_spike']:
                volume_score += 0.5
            elif volume_signals['volume_surge']:
                volume_score += 0.3
            elif volume_signals['high_volume']:
                volume_score += 0.2
        
        confluence_score += volume_score * self.confluence_weights['volume']
        
        # 5. Position Bollinger (10%)
        bb_score = 0.0
        if volatility_signals['bb_position'] > 0.8:  # Proche de la bande supérieure
            bb_score += 0.3
        elif volatility_signals['bb_position'] < 0.2:  # Proche de la bande inférieure
            bb_score += 0.3
        
        confluence_score += bb_score * self.confluence_weights['bollinger_position']
        
        # Déterminer la direction du spike
        spike_direction = 'NEUTRAL'
        if ema_confluence['trend_direction'] == 'BULLISH' and momentum_signals['momentum_strength'] > 0:
            spike_direction = 'UP'
        elif ema_confluence['trend_direction'] == 'BEARISH' and momentum_signals['momentum_strength'] < 0:
            spike_direction = 'DOWN'
        
        # Niveau de confiance
        confidence = min(confluence_score, 1.0)
        
        # Classification du spike
        if confidence > 0.8:
            spike_level = 'HIGH_PROBABILITY'
        elif confidence > 0.6:
            spike_level = 'MEDIUM_PROBABILITY'
        elif confidence > 0.4:
            spike_level = 'LOW_PROBABILITY'
        else:
            spike_level = 'NO_SPIKE'
        
        return {
            'spike_prediction': spike_level,
            'spike_direction': spike_direction,
            'confidence': confidence,
            'confluence_score': confluence_score,
            'ema_confluence': ema_confluence,
            'momentum_signals': momentum_signals,
            'volatility_signals': volatility_signals,
            'volume_signals': volume_signals,
            'recommendation': self._get_recommendation(spike_level, spike_direction, confidence)
        }
    
    def _get_recommendation(self, spike_level: str, spike_direction: str, confidence: float) -> str:
        """
        Générer une recommandation basée sur la prédiction
        """
        if spike_level == 'HIGH_PROBABILITY':
            if spike_direction == 'UP':
                return f"🚀 SPIKE HAUSSIER IMMINENT! Confiance: {confidence:.1%}"
            elif spike_direction == 'DOWN':
                return f"💥 SPIKE BAISSIER IMMINENT! Confiance: {confidence:.1%}"
        elif spike_level == 'MEDIUM_PROBABILITY':
            if spike_direction == 'UP':
                return f"📈 Spike haussier probable. Confiance: {confidence:.1%}"
            elif spike_direction == 'DOWN':
                return f"📉 Spike baissier probable. Confiance: {confidence:.1%}"
        elif spike_level == 'LOW_PROBABILITY':
            return f"⚠️ Spike possible mais incertain. Confiance: {confidence:.1%}"
        else:
            return "😴 Aucun spike détecté. Marché stable."
    
    def _calculate_rsi(self, prices: pd.Series, period: int = 14) -> pd.Series:
        """Calculer le RSI"""
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return rsi
    
    def _calculate_macd(self, prices: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> Tuple[pd.Series, pd.Series, pd.Series]:
        """Calculer le MACD"""
        ema_fast = prices.ewm(span=fast).mean()
        ema_slow = prices.ewm(span=slow).mean()
        macd_line = ema_fast - ema_slow
        macd_signal = macd_line.ewm(span=signal).mean()
        macd_histogram = macd_line - macd_signal
        return macd_line, macd_signal, macd_histogram
    
    def _calculate_atr(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        """Calculer l'ATR"""
        high_low = df['high'] - df['low']
        high_close = np.abs(df['high'] - df['close'].shift())
        low_close = np.abs(df['low'] - df['close'].shift())
        ranges = pd.concat([high_low, high_close, low_close], axis=1)
        true_range = ranges.max(axis=1)
        atr = true_range.rolling(period).mean()
        return atr
