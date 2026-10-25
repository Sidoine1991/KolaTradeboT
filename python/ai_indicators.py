import pandas as pd
import numpy as np
from scipy.stats import linregress, percentileofscore
import joblib
from datetime import datetime, timedelta
import json
import os
from typing import Dict, Tuple, List, Optional, Union

class AdvancedIndicators:
    def __init__(self, symbol: str, timeframe: str):
        self.symbol = symbol
        self.timeframe = timeframe
        self.model_path = os.path.join(os.path.dirname(__file__), 'models', f'{symbol}_{timeframe}_model.pkl')
        self.scaler_path = os.path.join(os.path.dirname(__file__), 'models', f'{symbol}_{timeframe}_scaler.pkl')
        
        # Charger le modèle et le scaler s'ils existent
        self.model = self._load_model()
        self.scaler = self._load_scaler()
    
    def _load_model(self):
        if os.path.exists(self.model_path):
            return joblib.load(self.model_path)
        return None
    
    def _load_scaler(self):
        if os.path.exists(self.scaler_path):
            return joblib.load(self.scaler_path)
        return None
    
    def calculate_volume_profile(self, df: pd.DataFrame, num_bins: int = 20) -> Dict:
        """
        Calcule le profil de volume pour la période donnée.
        Retourne les zones de prix avec le volume le plus élevé.
        """
        if df.empty or 'volume' not in df.columns or 'close' not in df.columns:
            return {}
            
        # Créer des bins de prix
        min_price = df['low'].min()
        max_price = df['high'].max()
        price_range = max_price - min_price
        bin_size = price_range / num_bins
        
        if bin_size == 0:
            return {}
        
        # Assigner chaque trade à un bin de prix
        df['price_bin'] = ((df['close'] - min_price) / bin_size).astype(int)
        df['price_bin'] = df['price_bin'].clip(0, num_bins - 1)
        
        # Calculer le volume total par bin
        volume_profile = df.groupby('price_bin')['volume'].sum().sort_values(ascending=False)
        
        # Convertir en pourcentage du volume total
        total_volume = volume_profile.sum()
        if total_volume > 0:
            volume_profile = (volume_profile / total_volume) * 100
        
        # Préparer le résultat
        result = {
            'min_price': float(min_price),
            'max_price': float(max_price),
            'bin_size': float(bin_size),
            'profile': {}
        }
        
        for bin_idx, volume in volume_profile.items():
            price_level = min_price + (bin_idx * bin_size) + (bin_size / 2)
            result['profile'][f"{price_level:.5f}"] = float(volume)
        
        return result
    
    def calculate_order_book_imbalance(self, order_book: Dict) -> Dict:
        """
        Calcule le déséquilibre du carnet d'ordres.
        Prend en entrée un dictionnaire avec les clés 'bids' et 'asks'.
        """
        if not order_book or 'bids' not in order_book or 'asks' not in order_book:
            return {}
        
        bids = order_book.get('bids', [])
        asks = order_book.get('asks', [])
        
        if not bids or not asks:
            return {}
        
        # Calculer le volume total des 5 premiers niveaux
        bid_volume = sum(float(bid[1]) for bid in bids[:5])
        ask_volume = sum(float(ask[1]) for ask in asks[:5])
        
        # Calculer le déséquilibre
        total_volume = bid_volume + ask_volume
        imbalance = 0.0
        
        if total_volume > 0:
            imbalance = (bid_volume - ask_volume) / total_volume
        
        # Détecter les murs d'ordres
        bid_wall = max((float(bid[1]) for bid in bids[:10]), default=0)
        ask_wall = max((float(ask[1]) for ask in asks[:10]), default=0)
        
        return {
            'imbalance': float(imbalance),
            'bid_volume': float(bid_volume),
            'ask_volume': float(ask_volume),
            'bid_wall': float(bid_wall),
            'ask_wall': float(ask_wall),
            'spread': float(float(asks[0][0]) - float(bids[0][0])) if bids and asks else 0.0
        }
    
    def calculate_market_sentiment(self, df: pd.DataFrame) -> Dict:
        """
        Calcule le sentiment du marché basé sur plusieurs indicateurs techniques.
        """
        if df.empty or len(df) < 20:  # Besoin d'assez de données
            return {}
        
        # S'assurer que toutes les colonnes nécessaires existent
        if 'volume' not in df.columns:
            df['volume'] = 1000  # Volume par défaut si non disponible
        
        # RSI (Relative Strength Index) - Wilder's Smoothing
        period = 14
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0))
        loss = (-delta.where(delta < 0, 0))
        
        # Wilder's Smoothing is equivalent to EMA with alpha = 1/period
        avg_gain = gain.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
        avg_loss = loss.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
        
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs)).iloc[-1]
        
        # MACD (Moving Average Convergence Divergence)
        exp1 = df['close'].ewm(span=12, adjust=False).mean()
        exp2 = df['close'].ewm(span=26, adjust=False).mean()
        macd = exp1 - exp2
        signal = macd.ewm(span=9, adjust=False).mean()
        macd_hist = macd - signal
        
        # Dérnière valeur du MACD
        macd_value = macd.iloc[-1]
        macd_signal = signal.iloc[-1]
        macd_hist_value = macd_hist.iloc[-1]
        
        # Volume moyen sur 20 périodes
        volume_ma = df['volume'].rolling(window=20).mean().iloc[-1]
        current_volume = df['volume'].iloc[-1]
        volume_ratio = current_volume / volume_ma if volume_ma > 0 else 1.0
        
        # Calcul du sentiment global (de -1 à 1)
        sentiment = 0.0
        
        # Pondération RSI (30%)
        rsi_weight = 0.3
        if rsi > 70:
            sentiment += rsi_weight * -1.0  # Suralimenté (bearish)
        elif rsi < 30:
            sentiment += rsi_weight * 1.0   # Sursollicité (bullish)
        else:
            # Normalisation entre -1 et 1
            sentiment += rsi_weight * ((rsi - 50) / 20)
        
        # Pondération MACD (30%)
        macd_weight = 0.3
        if macd_hist_value > 0 and macd_value > macd_signal:
            sentiment += macd_weight * 1.0  # Tendance haussière
        elif macd_hist_value < 0 and macd_value < macd_signal:
            sentiment += macd_weight * -1.0  # Tendance baissière
        
        # Pondération Volume (20%)
        volume_weight = 0.2
        price_change = (df['close'].iloc[-1] - df['close'].iloc[-2]) / df['close'].iloc[-2] * 100
        if current_volume > volume_ma * 1.5:  # Volume anormalement élevé
            sentiment += volume_weight * (1.0 if price_change > 0 else -1.0)
        
        # Pondération Volatilité (20%)
        volatility_weight = 0.2
        atr = (df['high'] - df['low']).rolling(window=14).mean().iloc[-1]
        avg_atr = (df['high'] - df['low']).mean()
        if atr > avg_atr * 1.5:  # Volatilité élevée
            sentiment = sentiment * 1.5  # Amplifier le signal en cas de forte volatilité
        
        # Normalisation entre -1 et 1
        sentiment = max(min(sentiment, 1.0), -1.0)
        
        return {
            'rsi': float(rsi),
            'macd': float(macd_value),
            'macd_signal': float(macd_signal),
            'macd_hist': float(macd_hist_value),
            'volume_ratio': float(volume_ratio),
            'sentiment': float(sentiment),
            'trend': 'bullish' if sentiment > 0.2 else 'bearish' if sentiment < -0.2 else 'neutral',
            'volatility': 'high' if atr > avg_atr * 1.5 else 'medium' if atr > avg_atr * 0.8 else 'low'
        }
    
    def predict_with_ml(self, features: Dict) -> Dict:
        """
        Utilise le modèle ML pour faire une prédiction basée sur les caractéristiques fournies.
        """
        if not self.model or not self.scaler:
            return {"error": "Modèle ou scaler non chargé"}
        
        try:
            # Convertir les caractéristiques en tableau numpy
            feature_names = [
                'rsi', 'macd', 'macd_signal', 'macd_hist', 
                'volume_ratio', 'sentiment', 'imbalance',
                'bid_volume', 'ask_volume', 'spread'
            ]
            
            # Créer un tableau avec les valeurs par défaut
            X = np.zeros((1, len(feature_names)))
            
            # Remplir avec les valeurs fournies
            for i, name in enumerate(feature_names):
                if name in features:
                    X[0, i] = features[name]
            
            # Normaliser les caractéristiques
            X_scaled = self.scaler.transform(X)
            
            # Faire la prédiction
            prediction = self.model.predict_proba(X_scaled)
            
            # Si c'est un classifieur binaire
            if prediction.shape[1] == 2:
                prob_up = prediction[0][1]  # Probabilité de hausse
                prob_down = prediction[0][0]  # Probabilité de baisse
            else:
                # Pour les classifieurs multi-classes, on prend la classe avec la plus haute probabilité
                prob_up = np.max(prediction)
                prob_down = 1.0 - prob_up
            
            return {
                'prediction': 'up' if prob_up > prob_down else 'down',
                'probability_up': float(prob_up),
                'probability_down': float(prob_down),
                'confidence': float(abs(prob_up - 0.5) * 2)  # Normalisé entre 0 et 1
            }
            
        except Exception as e:
            return {"error": str(e)}
    
    def calculate_ichimoku(self, df: pd.DataFrame) -> Dict:
        """
        Calcule les composantes de l'indicateur Ichimoku Kinko Hyo.
        
        Args:
            df: DataFrame contenant les données OHLCV
            
        Returns:
            Dictionnaire avec les composantes Ichimoku
        """
        if df.empty or len(df) < 52:  # Besoin d'assez de données pour les calculs
            return {}
            
        high = df['high']
        low = df['low']
        close = df['close']
        
        # Conversion Line (Tenkan-sen)
        period9_high = high.rolling(window=9).max()
        period9_low = low.rolling(window=9).min()
        tenkan_sen = (period9_high + period9_low) / 2
        
        # Base Line (Kijun-sen)
        period26_high = high.rolling(window=26).max()
        period26_low = low.rolling(window=26).min()
        kijun_sen = (period26_high + period26_low) / 2
        
        # Leading Span A (Senkou Span A)
        senkou_span_a = ((tenkan_sen + kijun_sen) / 2).shift(26)
        
        # Leading Span B (Senkou Span B)
        period52_high = high.rolling(window=52).max()
        period52_low = low.rolling(window=52).min()
        senkou_span_b = ((period52_high + period52_low) / 2).shift(26)
        
        # Lagging Span (Chikou Span)
        chikou_span = close.shift(-26)
        
        # Nuage (Kumo)
        kumo = senkou_span_a - senkou_span_b
        
        # Dernières valeurs
        last = {
            'tenkan_sen': float(tenkan_sen.iloc[-1]) if pd.notna(tenkan_sen.iloc[-1]) else None,
            'kijun_sen': float(kijun_sen.iloc[-1]) if pd.notna(kijun_sen.iloc[-1]) else None,
            'senkou_span_a': float(senkou_span_a.iloc[-1]) if pd.notna(senkou_span_a.iloc[-1]) else None,
            'senkou_span_b': float(senkou_span_b.iloc[-1]) if pd.notna(senkou_span_b.iloc[-1]) else None,
            'chikou_span': float(chikou_span.iloc[-1]) if pd.notna(chikou_span.iloc[-1]) else None,
            'kumo': float(kumo.iloc[-1]) if pd.notna(kumo.iloc[-1]) else None,
            'price_above_kumo': close.iloc[-1] > max(senkou_span_a.iloc[-1], senkou_span_b.iloc[-1]) 
                              if all(pd.notna([senkou_span_a.iloc[-1], senkou_span_b.iloc[-1]])) else None,
            'price_below_kumo': close.iloc[-1] < min(senkou_span_a.iloc[-1], senkou_span_b.iloc[-1]) 
                              if all(pd.notna([senkou_span_a.iloc[-1], senkou_span_b.iloc[-1]])) else None,
            'tenkan_above_kijun': tenkan_sen.iloc[-1] > kijun_sen.iloc[-1] 
                                if all(pd.notna([tenkan_sen.iloc[-1], kijun_sen.iloc[-1]])) else None,
            'cloud_green': senkou_span_a.iloc[-1] > senkou_span_b.iloc[-1] 
                         if all(pd.notna([senkou_span_a.iloc[-1], senkou_span_b.iloc[-1]])) else None
        }
        
        # Suppression des valeurs None
        return {k: v for k, v in last.items() if v is not None}
        
    def calculate_fibonacci(self, df: pd.DataFrame, lookback: int = 100) -> Dict:
        """
        Calcule les niveaux de retracement et d'extension de Fibonacci.
        
        Args:
            df: DataFrame contenant les données OHLCV
            lookback: Nombre de périodes à considérer pour trouver les extrêmes
            
        Returns:
            Dictionnaire avec les niveaux de Fibonacci
        """
        if df.empty or len(df) < lookback:
            return {}
            
        high = df['high']
        low = df['low']
        
        # Trouver les plus hauts et plus bas sur la période
        max_high = high.rolling(window=lookback).max().iloc[-1]
        min_low = low.rolling(window=lookback).min().iloc[-1]
        
        # Calculer les différences
        diff = max_high - min_low
        
        # Niveaux de retracement de Fibonacci
        fib_levels = {
            'high': float(max_high),
            'low': float(min_low),
            'retracement': {
                '0.0': float(max_high),
                '0.236': float(max_high - 0.236 * diff),
                '0.382': float(max_high - 0.382 * diff),
                '0.5': float(max_high - 0.5 * diff),
                '0.618': float(max_high - 0.618 * diff),
                '0.786': float(max_high - 0.786 * diff),
                '1.0': float(min_low)
            },
            'extension': {
                '1.272': float(max_high + 0.272 * diff),
                '1.414': float(max_high + 0.414 * diff),
                '1.618': float(max_high + 0.618 * diff),
                '2.0': float(max_high + diff),
                '2.618': float(max_high + 1.618 * diff)
            }
        }
        
        # Ajouter le prix actuel et sa position par rapport aux niveaux
        current_price = df['close'].iloc[-1]
        fib_levels['current_price'] = float(current_price)
        fib_levels['price_position'] = (current_price - min_low) / diff if diff > 0 else 0.5
        
        return fib_levels
        
    def detect_order_blocks(self, df: pd.DataFrame, lookback: int = 50) -> List[Dict]:
        """
        Détecte les blocs d'ordre (Order Blocks) dans les données de prix.
        
        Args:
            df: DataFrame contenant les données OHLCV
            lookback: Nombre de périodes à analyser
            
        Returns:
            Liste des blocs d'ordre détectés
        """
        if df.empty or len(df) < lookback + 1:
            return []
            
        # Sélectionner la fenêtre d'analyse
        df_slice = df.iloc[-(lookback+1):-1].copy()
        
        # Détecter les chandeliers d'impulsion (gros corps, faible mèche)
        df_slice['body'] = (df_slice['close'] - df_slice['open']).abs()
        df_slice['upper_wick'] = df_slice['high'] - df_slice[['open', 'close']].max(axis=1)
        df_slice['lower_wick'] = df_slice[['open', 'close']].min(axis=1) - df_slice['low']
        df_slice['is_bullish'] = df_slice['close'] > df_slice['open']
        
        # Seuil pour un chandelier significatif (corps > 70% de la taille totale)
        df_slice['total_range'] = df_slice['high'] - df_slice['low']
        significant = (df_slice['body'] / df_slice['total_range']) > 0.7
        
        # Filtrer les chandeliers significatifs
        impulse_candles = df_slice[significant].copy()
        
        # Trier par volume (si disponible) ou par taille du corps
        if 'volume' in df_slice.columns:
            impulse_candles = impulse_candles.sort_values('volume', ascending=False)
        else:
            impulse_candles = impulse_candles.sort_values('body', ascending=False)
        
        # Limiter le nombre de blocs à retourner
        max_blocks = 5
        order_blocks = []
        
        for idx, candle in impulse_candles.head(max_blocks).iterrows():
            block = {
                'time': idx.isoformat(),
                'type': 'bullish' if candle['is_bullish'] else 'bearish',
                'open': float(candle['open']),
                'high': float(candle['high']),
                'low': float(candle['low']),
                'close': float(candle['close']),
                'volume': float(candle.get('volume', 0)),
                'significance': float(candle['body'] / candle['total_range'])
            }
            
            # Définir la zone de bloc d'ordre
            if candle['is_bullish']:
                block['zone'] = {
                    'top': float(candle['close']),
                    'bottom': float(candle['open']),
                    'mid': float((candle['open'] + candle['close']) / 2)
                }
            else:
                block['zone'] = {
                    'top': float(candle['open']),
                    'bottom': float(candle['close']),
                    'mid': float((candle['open'] + candle['close']) / 2)
                }
                
            order_blocks.append(block)
            
        return order_blocks
        
    def identify_liquidity_zones(self, df: pd.DataFrame, num_zones: int = 5, 
                               volume_filter: bool = True) -> List[Dict]:
        """
        Identifie les zones de liquidité basées sur le volume et le profil de prix.
        
        Args:
            df: DataFrame contenant les données OHLCV
            num_zones: Nombre de zones de liquidité à identifier
            volume_filter: Si True, utilise le volume pour pondérer les zones
            
        Returns:
            Liste des zones de liquidité identifiées
        """
        if df.empty or len(df) < 20:  # Minimum 20 bougies pour une analyse significative
            return []
            
        # Calculer le point de contrôle (POC) et les niveaux de valeur (VA)
        price_bins = 20
        min_price = df['low'].min()
        max_price = df['high'].max()
        price_range = max_price - min_price
        
        if price_range == 0:
            return []
            
        bin_size = price_range / price_bins
        
        # Créer des bins de prix
        bins = [min_price + i * bin_size for i in range(price_bins + 1)]
        df['price_bin'] = pd.cut(df['close'], bins=bins, labels=bins[:-1], include_lowest=True)
        
        # Calculer le volume par bin de prix
        if volume_filter and 'volume' in df.columns:
            volume_profile = df.groupby('price_bin')['volume'].sum().sort_values(ascending=False)
        else:
            # Si pas de volume, compter simplement le nombre de bougies
            volume_profile = df['price_bin'].value_counts()
            
        # Sélectionner les zones les plus importantes
        top_zones = volume_profile.head(num_zones)
        
        # Préparer le résultat
        zones = []
        for price_bin, volume in top_zones.items():
            bin_idx = bins.index(price_bin)
            zone = {
                'price_level': float(price_bin),
                'volume': float(volume),
                'zone_low': float(bins[bin_idx]),
                'zone_high': float(bins[bin_idx + 1] if bin_idx + 1 < len(bins) else bins[-1]),
                'zone_mid': float((bins[bin_idx] + (bins[bin_idx + 1] if bin_idx + 1 < len(bins) else bins[-1])) / 2),
                'volume_percent': float(volume / volume_profile.sum() * 100) if volume_profile.sum() > 0 else 0
            }
            zones.append(zone)
            
        # Trier par niveau de prix (du plus bas au plus haut)
        zones = sorted(zones, key=lambda x: x['price_level'])
        
        return zones
        
    def calculate_market_profile(self, df: pd.DataFrame, period: str = 'D', 
                               value_area_percent: float = 0.7) -> Dict:
        """
        Calcule le profil de marché (Market Profile) avec POC, VAL, VAH, etc.
        
        Args:
            df: DataFrame contenant les données OHLCV
            period: Période pour l'agrégation ('D' pour journalier, 'W' pour hebdomadaire, etc.)
            value_area_percent: Pourcentage de volume à inclure dans la zone de valeur (0.7 = 70%)
            
        Returns:
            Dictionnaire contenant les informations du profil de marché
        """
        if df.empty or 'volume' not in df.columns:
            return {}
            
        # Créer une copie pour éviter les avertissements
        df = df.copy()
        
        # Vérifier si l'index est un DatetimeIndex
        if not isinstance(df.index, pd.DatetimeIndex):
            if 'time' in df.columns:
                df['time'] = pd.to_datetime(df['time'])
                df.set_index('time', inplace=True)
            else:
                return {"error": "L'index doit être un DatetimeIndex ou une colonne 'time' doit être présente"}
        
        # Grouper par période
        df_resampled = df.resample(period).agg({
            'open': 'first',
            'high': 'max',
            'low': 'min',
            'close': 'last',
            'volume': 'sum'
        })
        
        # Créer un profil de prix pour chaque période
        profiles = []
        
        for idx, row in df_resampled.iterrows():
            # Créer des bins de prix pour cette période
            price_bins = 30  # Nombre de bins de prix
            price_range = row['high'] - row['low']
            bin_size = price_range / price_bins if price_range > 0 else 0.0001
            
            if bin_size == 0:
                continue
                
            bins = [row['low'] + i * bin_size for i in range(price_bins + 1)]
            
            # Filtrer les données pour cette période
            period_mask = (df.index >= idx) & (df.index < (idx + pd.Timedelta(days=1)))
            period_df = df[period_mask].copy()
            
            if period_df.empty:
                continue
                
            # Assigner chaque trade à un bin de prix
            period_df['price_bin'] = pd.cut(
                period_df['close'], 
                bins=bins, 
                labels=[f"{bins[i]:.5f}-{bins[i+1]:.5f}" for i in range(len(bins)-1)],
                include_lowest=True
            )
            
            # Calculer le volume par bin de prix
            volume_profile = period_df.groupby('price_bin')['volume'].sum()
            
            if volume_profile.empty:
                continue
                
            # Trouver le Point of Control (POC) - niveau de prix avec le plus de volume
            poc_level = volume_profile.idxmax()
            poc_volume = volume_profile.max()
            
            # Calculer la zone de valeur (Value Area)
            sorted_profile = volume_profile.sort_values(ascending=False)
            total_volume = sorted_profile.sum()
            target_volume = total_volume * value_area_percent
            
            cumulative_volume = 0
            value_area_levels = []
            
            for price_level, volume in sorted_profile.items():
                if cumulative_volume < target_volume:
                    value_area_levels.append(price_level)
                    cumulative_volume += volume
                else:
                    break
            
            # Extraire les prix min et max de la zone de valeur
            if value_area_levels:
                # Convertir les chaînes de plages en valeurs numériques
                def parse_price_range(price_range_str):
                    try:
                        low, high = map(float, price_range_str.split('-'))
                        return low, high
                    except:
                        return float('inf'), float('-inf')
                
                all_lows, all_highs = zip(*[parse_price_range(p) for p in value_area_levels])
                val = min(all_lows)
                vah = max(all_highs)
            else:
                val = vah = float('nan')
            
            # Extraire les prix min et max du POC
            try:
                poc_low, poc_high = map(float, poc_level.split('-'))
            except:
                poc_low = poc_high = float('nan')
            
            # Ajouter au profil
            profile = {
                'date': idx.isoformat(),
                'poc': {
                    'level': poc_level,
                    'price': (poc_low + poc_high) / 2,
                    'volume': float(poc_volume),
                    'low': poc_low,
                    'high': poc_high
                },
                'value_area': {
                    'low': float(val),
                    'high': float(vah),
                    'width': float(vah - val) if not (pd.isna(val) or pd.isna(vah)) else 0.0,
                    'volume_percent': float(cumulative_volume / total_volume * 100) if total_volume > 0 else 0.0
                },
                'total_volume': float(total_volume)
            }
            
            profiles.append(profile)
        
        # Si aucun profil n'a pu être calculé
        if not profiles:
            return {}
        
        # Calculer les statistiques globales
        latest_profile = profiles[-1]
        
        # Tendance basée sur la position du prix par rapport au POC et à la zone de valeur
        current_price = df['close'].iloc[-1]
        poc_price = latest_profile['poc']['price']
        val = latest_profile['value_area']['low']
        vah = latest_profile['value_area']['high']
        
        trend = "neutral"
        if current_price > vah:
            trend = "strong_bullish"
        elif current_price > poc_price:
            trend = "bullish"
        elif current_price < val:
            trend = "strong_bearish"
        elif current_price < poc_price:
            trend = "bearish"
            
        # Préparer le résultat final
        result = {
            'timeframe': period,
            'current_price': float(current_price),
            'trend': trend,
            'latest_profile': latest_profile,
            'profiles': profiles,
            'profile_stats': {
                'total_profiles': len(profiles),
                'avg_poc_volume': float(np.mean([p['poc']['volume'] for p in profiles])),
                'avg_value_area_width': float(np.mean([p['value_area']['width'] for p in profiles if not pd.isna(p['value_area']['width'])] or [0])),
                'avg_value_area_percent': float(np.mean([p['value_area']['volume_percent'] for p in profiles]))
            }
        }
        
        return result
        
    def process_market_data(self, market_data: Dict) -> Dict:
        """
        Traite les données de marché et calcule tous les indicateurs.
        """
        if not market_data or 'candles' not in market_data:
            return {"error": "Données de marché invalides"}
        
        try:
            # Convertir les bougies en DataFrame
            df = pd.DataFrame(market_data['candles'])
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            
            # Calculer les indicateurs de base
            volume_profile = self.calculate_volume_profile(df)
            market_sentiment = self.calculate_market_sentiment(df)
            
            # Récupérer le carnet d'ordres s'il est fourni
            order_book = market_data.get('order_book', {})
            order_book_imbalance = self.calculate_order_book_imbalance(order_book)
            
            # Calculer les indicateurs avancés
            ichimoku = self.calculate_ichimoku(df)
            fibonacci = self.calculate_fibonacci(df)
            order_blocks = self.detect_order_blocks(df)
            liquidity_zones = self.identify_liquidity_zones(df)
            market_profile = self.calculate_market_profile(df)
            
            # Combiner toutes les fonctionnalités pour la prédiction ML
            features = {}
            features.update(market_sentiment)
            features.update(order_book_imbalance)
            
            # Ajouter les indicateurs avancés aux features
            if ichimoku:
                features.update({
                    'ichimoku_tenkan': ichimoku.get('tenkan_sen', 0),
                    'ichimoku_kijun': ichimoku.get('kijun_sen', 0),
                    'ichimoku_senkou_a': ichimoku.get('senkou_span_a', 0),
                    'ichimoku_senkou_b': ichimoku.get('senkou_span_b', 0),
                    'ichimoku_chikou': ichimoku.get('chikou_span', 0)
                })
            
            # Faire une prédiction avec le modèle ML si disponible
            ml_prediction = {}
            if self.model is not None and self.scaler is not None:
                ml_prediction = self.predict_with_ml(features)
            
            # Préparer le résultat final
            result = {
                'timestamp': datetime.utcnow().isoformat(),
                'symbol': self.symbol,
                'timeframe': self.timeframe,
                'price': {
                    'open': float(df['open'].iloc[-1]),
                    'high': float(df['high'].iloc[-1]),
                    'low': float(df['low'].iloc[-1]),
                    'close': float(df['close'].iloc[-1]),
                    'volume': float(df['volume'].iloc[-1])
                },
                'indicators': {
                    'volume_profile': volume_profile,
                    'market_sentiment': market_sentiment,
                    'order_book_imbalance': order_book_imbalance,
                    'ichimoku': ichimoku,
                    'fibonacci': fibonacci,
                    'order_blocks': order_blocks,
                    'liquidity_zones': liquidity_zones,
                    'market_profile': market_profile
                },
                'ml_prediction': ml_prediction
            }
            
            return result
            
        except Exception as e:
            return {"error": f"Erreur lors du traitement des données: {str(e)}"}

# Fonction d'aide pour exécuter l'analyse depuis l'extérieur
def analyze_market_data(symbol: str, timeframe: str, market_data: Dict) -> str:
    """
    Fonction principale appelée par le script MQL5.
    Prend les données de marché en entrée et retourne une chaîne JSON avec les indicateurs.
    """
    try:
        analyzer = AdvancedIndicators(symbol, timeframe)
        result = analyzer.process_market_data(market_data)
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"error": f"Erreur dans l'analyse: {str(e)}"})

# Exemple d'utilisation
if __name__ == "__main__":
    # Exemple de données de marché (à remplacer par les données réelles)
    sample_data = {
        "candles": [
            {"time": 1610000000, "open": 1.2000, "high": 1.2010, "low": 1.1990, "close": 1.2005, "volume": 1000},
            # Ajoutez plus de bougies ici...
        ],
        "order_book": {
            "bids": [[1.1995, 100], [1.1990, 150]],
            "asks": [[1.2005, 120], [1.2010, 200]]
        }
    }
    
    # Exécuter l'analyse
    result = analyze_market_data("EURUSD", "M5", sample_data)
    print(result)
