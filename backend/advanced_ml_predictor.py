"""
Algorithme ML avancé pour prédire les mouvements de prix sur les indices synthétiques
Basé sur les stratégies de Vince Stanzione pour Boom/Crash et Volatility Indices
"""

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score
import joblib
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

class AdvancedMLPredictor:
    """
    Prédicteur ML avancé pour les indices synthétiques
    Combine plusieurs modèles et techniques de Vince Stanzione
    """
    
    def __init__(self):
        self.models = {}
        self.scalers = {}
        self.feature_importance = {}
        self.is_trained = False
        
    def create_advanced_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Créer des features avancées basées sur les stratégies de Vince Stanzione
        """
        df = df.copy()
        
        # S'assurer que l'index est un DatetimeIndex si possible
        if not hasattr(df.index, 'hour') and 'timestamp' in df.columns:
            try:
                df.index = pd.to_datetime(df['timestamp'])
            except:
                pass
        
        # 1. Features de volatilité (Volatility Indices)
        df['volatility_10'] = df['close'].rolling(10).std()
        df['volatility_20'] = df['close'].rolling(20).std()
        df['volatility_ratio'] = df['volatility_10'] / df['volatility_20']
        
        # 2. Features de momentum (RSI, MACD)
        if TALIB_AVAILABLE:
            df['rsi_14'] = talib.RSI(df['close'].values, timeperiod=14)
            df['rsi_21'] = talib.RSI(df['close'].values, timeperiod=21)
            df['macd'], df['macd_signal'], df['macd_hist'] = talib.MACD(df['close'].values)
        else:
            df['rsi_14'] = RSI(df['close'].values, 14)
            df['rsi_21'] = RSI(df['close'].values, 21)
            df['macd'], df['macd_signal'], df['macd_hist'] = MACD(df['close'].values)
        
        # 3. Features de tendance (Moving Averages - stratégie 21/6)
        if TALIB_AVAILABLE:
            df['sma_6'] = talib.SMA(df['close'].values, timeperiod=6)
            df['sma_21'] = talib.SMA(df['close'].values, timeperiod=21)
            df['ema_8'] = talib.EMA(df['close'].values, timeperiod=8)
        else:
            df['sma_6'] = SMA(df['close'].values, 6)
            df['sma_21'] = SMA(df['close'].values, 21)
            df['ema_8'] = EMA(df['close'].values, 8)
        df['ma_cross'] = (df['sma_6'] > df['sma_21']).astype(int)
        df['ma_distance'] = (df['sma_6'] - df['sma_21']) / df['sma_21']
        
        # 4. Features de breakout (Donchian Channels)
        df['donchian_high'] = df['high'].rolling(20).max()
        df['donchian_low'] = df['low'].rolling(20).min()
        df['donchian_mid'] = (df['donchian_high'] + df['donchian_low']) / 2
        df['donchian_position'] = (df['close'] - df['donchian_low']) / (df['donchian_high'] - df['donchian_low'])
        
        # 5. Features de Bollinger Bands
        if TALIB_AVAILABLE:
            df['bb_upper'], df['bb_middle'], df['bb_lower'] = talib.BBANDS(df['close'].values)
        else:
            df['bb_upper'], df['bb_middle'], df['bb_lower'] = BBANDS(df['close'].values)
        df['bb_width'] = (df['bb_upper'] - df['bb_lower']) / df['bb_middle']
        df['bb_position'] = (df['close'] - df['bb_lower']) / (df['bb_upper'] - df['bb_lower'])
        
        # 6. Features de Stochastic (pour scalping)
        if TALIB_AVAILABLE:
            df['stoch_k'], df['stoch_d'] = talib.STOCH(df['high'].values, df['low'].values, df['close'].values)
        else:
            # Fallback simple pour Stochastic
            lowest_low = df['low'].rolling(14).min()
            highest_high = df['high'].rolling(14).max()
            df['stoch_k'] = 100 * ((df['close'] - lowest_low) / (highest_high - lowest_low))
            df['stoch_d'] = df['stoch_k'].rolling(3).mean()
        df['stoch_oversold'] = (df['stoch_k'] < 20).astype(int)
        df['stoch_overbought'] = (df['stoch_k'] > 80).astype(int)
        
        # 7. Features de volume et prix
        df['price_change'] = df['close'].pct_change()
        df['price_change_abs'] = df['price_change'].abs()
        df['volume_ratio'] = df['volume'] / df['volume'].rolling(20).mean()
        
        # 8. Features de temps (pour les patterns)
        # Vérifier si l'index est un DatetimeIndex
        if hasattr(df.index, 'hour'):
            df['hour'] = df.index.hour
            df['minute'] = df.index.minute
            df['day_of_week'] = df.index.dayofweek
        else:
            # Si ce n'est pas un DatetimeIndex, utiliser des valeurs par défaut
            df['hour'] = 12  # Heure par défaut
            df['minute'] = 0  # Minute par défaut
            df['day_of_week'] = 1  # Jour par défaut
        
        # 9. Features de retour (pour les prédictions)
        df['return_1'] = df['close'].pct_change(1)
        df['return_2'] = df['close'].pct_change(2)
        df['return_3'] = df['close'].pct_change(3)
        df['return_5'] = df['close'].pct_change(5)
        
        # 10. Features de spike detection (Boom/Crash)
        df['spike_threshold'] = df['volatility_20'] * 2
        df['is_spike'] = (df['price_change_abs'] > df['spike_threshold']).astype(int)
        df['spike_direction'] = np.where(df['price_change'] > 0, 1, -1) * df['is_spike']
        
        # 11. Features de support/résistance
        df['resistance'] = df['high'].rolling(20).max()
        df['support'] = df['low'].rolling(20).min()
        df['near_resistance'] = (df['close'] > df['resistance'] * 0.98).astype(int)
        df['near_support'] = (df['close'] < df['support'] * 1.02).astype(int)
        
        # 12. Features de divergence
        df['price_momentum'] = df['close'].rolling(5).mean() - df['close'].rolling(20).mean()
        df['rsi_momentum'] = df['rsi_14'].rolling(5).mean() - df['rsi_14'].rolling(20).mean()
        df['divergence'] = np.where(
            (df['price_momentum'] > 0) & (df['rsi_momentum'] < 0), 1,
            np.where((df['price_momentum'] < 0) & (df['rsi_momentum'] > 0), -1, 0)
        )
        
        return df
    
    def create_targets(self, df: pd.DataFrame, lookforward: int = 5) -> pd.DataFrame:
        """
        Créer les targets pour la prédiction
        """
        df = df.copy()
        
        # Target 1: Direction du mouvement (1 = hausse, 0 = baisse)
        df['target_direction'] = (df['close'].shift(-lookforward) > df['close']).astype(int)
        
        # Target 2: Amplitude du mouvement (1 = mouvement significatif, 0 = mouvement faible)
        df['target_amplitude'] = (df['close'].shift(-lookforward).pct_change(lookforward).abs() > 0.01).astype(int)
        
        # Target 3: Spike (1 = spike, 0 = pas de spike)
        df['target_spike'] = (df['close'].shift(-lookforward).pct_change(lookforward).abs() > 0.02).astype(int)
        
        # Target 4: Breakout (1 = breakout, 0 = pas de breakout)
        df['target_breakout'] = (
            (df['close'].shift(-lookforward) > df['donchian_high']) |
            (df['close'].shift(-lookforward) < df['donchian_low'])
        ).astype(int)
        
        return df
    
    def get_feature_columns(self) -> List[str]:
        """
        Retourner la liste des colonnes de features
        """
        return [
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
    
    def train_models(self, df: pd.DataFrame):
        """
        Entraîner les modèles ML
        """
        # Créer les features et targets
        df_features = self.create_advanced_features(df)
        df_targets = self.create_targets(df_features)
        
        # Préparer les données
        feature_cols = self.get_feature_columns()
        X = df_targets[feature_cols].fillna(0)
        
        # Entraîner plusieurs modèles pour différents targets
        targets = ['target_direction', 'target_amplitude', 'target_spike', 'target_breakout']
        
        for target in targets:
            y = df_targets[target].fillna(0)
            
            # Vérifier qu'il y a au moins 2 classes dans y
            unique_classes = y.unique()
            if len(unique_classes) < 2:
                print(f"⚠️ Target '{target}' n'a qu'une seule classe: {unique_classes}. Passage au target suivant.")
                continue
            
            # Vérifier qu'il y a assez de données pour chaque classe
            class_counts = y.value_counts()
            min_class_count = class_counts.min()
            if min_class_count < 5:  # Au moins 5 exemples par classe
                print(f"⚠️ Target '{target}' a une classe avec seulement {min_class_count} exemples. Passage au target suivant.")
                continue
            
            # Diviser les données
            X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
            
            # Vérifier les classes dans les données d'entraînement
            train_classes = y_train.unique()
            if len(train_classes) < 2:
                print(f"⚠️ Target '{target}' n'a qu'une seule classe dans les données d'entraînement. Passage au target suivant.")
                continue
            
            # Normaliser les features
            scaler = StandardScaler()
            X_train_scaled = scaler.fit_transform(X_train)
            X_test_scaled = scaler.transform(X_test)
            
            # Entraîner Random Forest avec gestion des classes déséquilibrées
            rf_model = RandomForestClassifier(
                n_estimators=50,
                max_depth=8,
                random_state=42,
                n_jobs=-1,
                class_weight='balanced'  # Gère automatiquement les classes déséquilibrées
            )
            rf_model.fit(X_train_scaled, y_train)
            
            # Entraîner Gradient Boosting avec gestion des classes déséquilibrées
            gb_model = GradientBoostingClassifier(
                n_estimators=50,
                max_depth=4,
                random_state=42
            )
            gb_model.fit(X_train_scaled, y_train)
            
            # Évaluer les modèles
            rf_score = rf_model.score(X_test_scaled, y_test)
            gb_score = gb_model.score(X_test_scaled, y_test)
            
            # Choisir le meilleur modèle
            if rf_score > gb_score:
                best_model = rf_model
                model_name = f"RandomForest_{target}"
            else:
                best_model = gb_model
                model_name = f"GradientBoosting_{target}"
            
            # Sauvegarder le modèle et le scaler
            self.models[target] = best_model
            self.scalers[target] = scaler
            self.feature_importance[target] = dict(zip(feature_cols, best_model.feature_importances_))
            
            print(f"Modèle {model_name} entraîné - Score: {max(rf_score, gb_score):.3f}")
        
        self.is_trained = True
        
        # Sauvegarder les modèles
        self.save_models()
    
    def predict(self, df: pd.DataFrame) -> Dict[str, float]:
        """
        Faire des prédictions sur de nouvelles données
        """
        if not self.is_trained:
            raise ValueError("Les modèles doivent être entraînés avant de faire des prédictions")
        
        # Créer les features
        df_features = self.create_advanced_features(df)
        feature_cols = self.get_feature_columns()
        X = df_features[feature_cols].fillna(0)
        
        predictions = {}
        
        for target, model in self.models.items():
            # Normaliser les features
            X_scaled = self.scalers[target].transform(X)
            
            # Faire la prédiction
            pred_proba = model.predict_proba(X_scaled)[-1]  # Dernière ligne
            predictions[target] = pred_proba[1] if len(pred_proba) > 1 else pred_proba[0]
        
        return predictions
    
    def get_trading_signals(self, df: pd.DataFrame) -> Dict[str, any]:
        """
        Générer des signaux de trading basés sur les prédictions et l'analyse technique
        """
        predictions = self.predict(df)
        signals = {}
        
        # Signal 1: Direction (seuils plus sensibles pour Boom/Crash)
        direction_prob = predictions.get('target_direction', 0.5)
        if direction_prob > 0.55:  # Seuil réduit de 0.6 à 0.55
            signals['direction'] = 'BUY'
            signals['direction_strength'] = direction_prob
        elif direction_prob < 0.45:  # Seuil réduit de 0.4 à 0.45
            signals['direction'] = 'SELL'
            signals['direction_strength'] = 1 - direction_prob
        else:
            signals['direction'] = 'HOLD'
            signals['direction_strength'] = 0.5
        
        # Signal 2: Spike (seuils plus sensibles pour Boom/Crash)
        spike_prob = predictions.get('target_spike', 0.5)
        if spike_prob > 0.6:  # Seuil réduit de 0.7 à 0.6
            signals['spike'] = 'HIGH_SPIKE_RISK'
            signals['spike_strength'] = spike_prob
        elif spike_prob > 0.45:  # Seuil réduit de 0.5 à 0.45
            signals['spike'] = 'MEDIUM_SPIKE_RISK'
            signals['spike_strength'] = spike_prob
        else:
            signals['spike'] = 'LOW_SPIKE_RISK'
            signals['spike_strength'] = spike_prob
        
        # Signal 3: Breakout (seuils plus sensibles pour Boom/Crash)
        breakout_prob = predictions.get('target_breakout', 0.5)
        if breakout_prob > 0.55:  # Seuil réduit de 0.6 à 0.55
            signals['breakout'] = 'BREAKOUT_LIKELY'
            signals['breakout_strength'] = breakout_prob
        else:
            signals['breakout'] = 'NO_BREAKOUT'
            signals['breakout_strength'] = breakout_prob
        
        # Signal 4: Amplitude (seuils plus sensibles pour Boom/Crash)
        amplitude_prob = predictions.get('target_amplitude', 0.5)
        if amplitude_prob > 0.55:  # Seuil réduit de 0.6 à 0.55
            signals['amplitude'] = 'HIGH_VOLATILITY'
            signals['amplitude_strength'] = amplitude_prob
        else:
            signals['amplitude'] = 'LOW_VOLATILITY'
            signals['amplitude_strength'] = amplitude_prob
        
        # Signal composite
        signals['overall_signal'] = self._calculate_overall_signal(signals)
        
        return signals
    
    def _calculate_overall_signal(self, signals: Dict[str, any]) -> str:
        """
        Calculer un signal composite basé sur tous les signaux (optimisé pour Boom/Crash)
        """
        direction = signals.get('direction', 'HOLD')
        spike = signals.get('spike', 'LOW_SPIKE_RISK')
        breakout = signals.get('breakout', 'NO_BREAKOUT')
        amplitude = signals.get('amplitude', 'LOW_VOLATILITY')
        
        # Logique de signal composite optimisée pour Boom/Crash
        # Signal très fort : direction + amplitude + breakout
        if direction == 'BUY' and amplitude == 'HIGH_VOLATILITY' and breakout == 'BREAKOUT_LIKELY':
            return 'STRONG_BUY'
        elif direction == 'SELL' and amplitude == 'HIGH_VOLATILITY' and breakout == 'BREAKOUT_LIKELY':
            return 'STRONG_SELL'
        
        # Signal fort : direction + amplitude OU direction + breakout
        elif direction == 'BUY' and (amplitude == 'HIGH_VOLATILITY' or breakout == 'BREAKOUT_LIKELY'):
            return 'BUY'
        elif direction == 'SELL' and (amplitude == 'HIGH_VOLATILITY' or breakout == 'BREAKOUT_LIKELY'):
            return 'SELL'
        
        # Signal de spike (important pour Boom/Crash)
        elif spike == 'HIGH_SPIKE_RISK':
            return 'SPIKE_WARNING'
        elif spike == 'MEDIUM_SPIKE_RISK' and direction != 'HOLD':
            return 'SPIKE_WARNING'
        
        # Signal de direction seul (plus sensible)
        elif direction == 'BUY':
            return 'BUY'
        elif direction == 'SELL':
            return 'SELL'
        
        # Signal de breakout seul
        elif breakout == 'BREAKOUT_LIKELY':
            return 'BREAKOUT_LIKELY'
        
        else:
            return 'HOLD'
    
    def save_models(self, path: str = "models/"):
        """
        Sauvegarder les modèles entraînés
        """
        import os
        os.makedirs(path, exist_ok=True)
        
        for target, model in self.models.items():
            joblib.dump(model, f"{path}model_{target}.pkl")
        
        for target, scaler in self.scalers.items():
            joblib.dump(scaler, f"{path}scaler_{target}.pkl")
        
        joblib.dump(self.feature_importance, f"{path}feature_importance.pkl")
    
    def load_models(self, path: str = "models/"):
        """
        Charger les modèles sauvegardés
        """
        import os
        if not os.path.exists(path):
            return False
        
        try:
            for target in ['target_direction', 'target_amplitude', 'target_spike', 'target_breakout']:
                model_path = f"{path}model_{target}.pkl"
                scaler_path = f"{path}scaler_{target}.pkl"
                
                if os.path.exists(model_path) and os.path.exists(scaler_path):
                    self.models[target] = joblib.load(model_path)
                    self.scalers[target] = joblib.load(scaler_path)
            
            if os.path.exists(f"{path}feature_importance.pkl"):
                self.feature_importance = joblib.load(f"{path}feature_importance.pkl")
            
            self.is_trained = True
            return True
        except Exception as e:
            print(f"Erreur lors du chargement des modèles: {e}")
            return False
    
    def get_feature_importance(self, target: str = 'target_direction') -> Dict[str, float]:
        """
        Retourner l'importance des features pour un target donné
        """
        return self.feature_importance.get(target, {})
