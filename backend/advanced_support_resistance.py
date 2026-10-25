"""
Module avancé pour la détection des supports et résistances.
Algorithme multi-méthodes avec validation croisée et analyse de force.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
import logging
from scipy.signal import argrelextrema
from sklearn.cluster import DBSCAN
from sklearn.preprocessing import StandardScaler
import warnings
warnings.filterwarnings('ignore')

logger = logging.getLogger(__name__)

class AdvancedSupportResistance:
    """
    Classe avancée pour la détection des supports et résistances.
    Utilise plusieurs méthodes et les valide croisées.
    """
    
    def __init__(self, config: Optional[Dict] = None):
        """Initialise le détecteur avec configuration."""
        self.config = config or self._get_default_config()
        self.levels_cache = {}
        
    def _get_default_config(self) -> Dict:
        """Configuration par défaut optimisée."""
        return {
            'swing_window': 5,           # Fenêtre pour swing highs/lows
            'min_touches': 2,            # Nombre minimum de touches
            'tolerance_pct': 0.001,      # Tolérance en pourcentage
            'volume_threshold': 0.7,     # Seuil de volume pour validation
            'price_threshold': 0.002,    # Seuil de prix pour validation
            'cluster_eps': 0.003,        # Paramètre DBSCAN
            'min_samples': 3,            # Échantillons minimum pour cluster
            'max_levels': 15,            # Nombre maximum de niveaux
            'time_decay': 0.95,          # Décroissance temporelle
            'market_structure_window': 20,  # Fenêtre pour structure de marché
            'psychological_levels': True,   # Détection des niveaux psychologiques
            'order_flow_analysis': True,    # Analyse du flux d'ordres
            'liquidity_zones': True,        # Détection des zones de liquidité
            'strength_weights': {        # Poids pour calcul de force
                'touches': 0.25,
                'volume': 0.15,
                'time': 0.15,
                'price_cluster': 0.15,
                'market_structure': 0.15,
                'psychological': 0.10,
                'order_flow': 0.05
            }
        }
    
    def detect_all_levels(self, df: pd.DataFrame, symbol: str = None) -> Dict:
        """
        Détecte tous les niveaux de support et résistance avec validation croisée.
        """
        if df is None or df.empty:
            return {'supports': [], 'resistances': [], 'pivot_points': {}}
        
        try:
            # 1. Méthode Swing Highs/Lows
            swing_levels = self._detect_swing_levels(df)
            
            # 2. Méthode Pivot Points
            pivot_levels = self._detect_pivot_points(df)
            
            # 3. Méthode Volume Profile
            volume_levels = self._detect_volume_levels(df)
            
            # 4. Méthode Fractal Levels
            fractal_levels = self._detect_fractal_levels(df)
            
            # 5. Méthode Fibonacci Retracements
            fib_levels = self._detect_fibonacci_levels(df)
            
            # 6. Méthode Structure de Marché (Higher Highs, Lower Lows)
            market_structure_levels = self._detect_market_structure_levels(df)
            
            # 7. Méthode Niveaux Psychologiques
            psychological_levels = self._detect_psychological_levels(df)
            
            # 8. Méthode Zones de Liquidité
            liquidity_levels = self._detect_liquidity_zones(df)
            
            # 9. Méthode Analyse du Flux d'Ordres
            order_flow_levels = self._detect_order_flow_levels(df)
            
            # 10. Fusion et validation croisée
            merged_levels = self._merge_and_validate_levels(
                df, [swing_levels, pivot_levels, volume_levels, fractal_levels, 
                     fib_levels, market_structure_levels, psychological_levels, 
                     liquidity_levels, order_flow_levels]
            )
            
            # 7. Calcul de la force et tri
            final_levels = self._calculate_strength_and_sort(df, merged_levels)
            
            # 8. Mise en cache
            if symbol:
                self.levels_cache[symbol] = {
                    'levels': final_levels,
                    'timestamp': pd.Timestamp.now(),
                    'data_shape': df.shape
                }
            
            return final_levels
            
        except Exception as e:
            logger.error(f"Erreur lors de la détection des niveaux : {e}")
            return {'supports': [], 'resistances': [], 'pivot_points': {}}
    
    def _detect_swing_levels(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux basés sur les swing highs et lows."""
        try:
            highs = df['high'].values
            lows = df['low'].values
            volumes = df['volume'].values if 'volume' in df.columns else np.ones(len(df))
            
            # Swing highs
            swing_high_idx = argrelextrema(highs, np.greater_equal, order=self.config['swing_window'])[0]
            swing_highs = []
            
            for idx in swing_high_idx:
                if idx >= 2 and idx < len(df) - 2:
                    # Validation du swing high
                    if (highs[idx] > highs[idx-1] and highs[idx] > highs[idx-2] and
                        highs[idx] > highs[idx+1] and highs[idx] > highs[idx+2]):
                        
                        # Calcul de la force basée sur le volume
                        volume_strength = volumes[idx] / np.mean(volumes) if np.mean(volumes) > 0 else 1
                        
                        swing_highs.append({
                            'price': highs[idx],
                            'index': idx,
                            'volume_strength': volume_strength,
                            'method': 'swing_high',
                            'timestamp': df.index[idx] if hasattr(df.index, 'iloc') else idx
                        })
            
            # Swing lows
            swing_low_idx = argrelextrema(lows, np.less_equal, order=self.config['swing_window'])[0]
            swing_lows = []
            
            for idx in swing_low_idx:
                if idx >= 2 and idx < len(df) - 2:
                    # Validation du swing low
                    if (lows[idx] < lows[idx-1] and lows[idx] < lows[idx-2] and
                        lows[idx] < lows[idx+1] and lows[idx] < lows[idx+2]):
                        
                        # Calcul de la force basée sur le volume
                        volume_strength = volumes[idx] / np.mean(volumes) if np.mean(volumes) > 0 else 1
                        
                        swing_lows.append({
                            'price': lows[idx],
                            'index': idx,
                            'volume_strength': volume_strength,
                            'method': 'swing_low',
                            'timestamp': df.index[idx] if hasattr(df.index, 'iloc') else idx
                        })
            
            return {
                'swing_highs': swing_highs,
                'swing_lows': swing_lows
            }
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_swing_levels : {e}")
            return {'swing_highs': [], 'swing_lows': []}
    
    def _detect_pivot_points(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux basés sur les pivot points classiques et Woodie."""
        try:
            if len(df) < 3:
                return {'pivot_points': []}
            
            # Pivot Points classiques
            pivot_points = []
            
            for i in range(2, len(df)):
                high = df['high'].iloc[i-1]
                low = df['low'].iloc[i-1]
                close = df['close'].iloc[i-1]
                
                # Pivot classique
                pivot = (high + low + close) / 3
                r1 = (2 * pivot) - low
                s1 = (2 * pivot) - high
                r2 = pivot + (high - low)
                s2 = pivot - (high - low)
                
                # Pivot Woodie
                woodie_pivot = (high + low + (2 * close)) / 4
                woodie_r1 = (2 * woodie_pivot) - low
                woodie_s1 = (2 * woodie_pivot) - high
                woodie_r2 = woodie_pivot + (high - low)
                woodie_s2 = woodie_pivot - (high - low)
                
                pivot_points.append({
                    'classic': {
                        'pivot': pivot, 'r1': r1, 's1': s1, 'r2': r2, 's2': s2
                    },
                    'woodie': {
                        'pivot': woodie_pivot, 'r1': woodie_r1, 's1': woodie_s1, 
                        'r2': woodie_r2, 's2': woodie_s2
                    },
                    'index': i,
                    'timestamp': df.index[i] if hasattr(df.index, 'iloc') else i
                })
            
            return {'pivot_points': pivot_points}
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_pivot_points : {e}")
            return {'pivot_points': []}
    
    def _detect_volume_levels(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux basés sur l'analyse du volume."""
        try:
            if 'volume' not in df.columns:
                return {'volume_levels': []}
            
            # Analyse du volume par niveau de prix
            price_volume = pd.DataFrame({
                'price': df['close'],
                'volume': df['volume']
            })
            
            # Regroupement par tranches de prix
            price_bins = pd.cut(price_volume['price'], bins=20)
            volume_profile = price_volume.groupby(price_bins)['volume'].sum()
            
            # Détection des pics de volume
            volume_mean = volume_profile.mean()
            volume_std = volume_profile.std()
            
            high_volume_levels = volume_profile[volume_profile > volume_mean + volume_std]
            
            volume_levels = []
            for price_bin, volume in high_volume_levels.items():
                # Extraction du prix moyen de la tranche
                price_level = price_bin.mid
                
                # Vérification de la proximité avec le prix actuel
                current_price = df['close'].iloc[-1]
                distance = abs(price_level - current_price) / current_price
                
                if distance < 0.1:  # Dans les 10% du prix actuel
                    volume_levels.append({
                        'price': price_level,
                        'volume_strength': volume / volume_mean,
                        'method': 'volume_profile',
                        'price_bin': str(price_bin)
                    })
            
            return {'volume_levels': volume_levels}
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_volume_levels : {e}")
            return {'volume_levels': []}
    
    def _detect_fractal_levels(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux basés sur les fractales de Bill Williams."""
        try:
            highs = df['high'].values
            lows = df['low'].values
            
            fractal_highs = []
            fractal_lows = []
            
            # Fractales haussières (5 bougies)
            for i in range(2, len(df) - 2):
                if (highs[i] > highs[i-1] and highs[i] > highs[i-2] and
                    highs[i] > highs[i+1] and highs[i] > highs[i+2]):
                    fractal_highs.append({
                        'price': highs[i],
                        'index': i,
                        'method': 'fractal_high',
                        'strength': 1
                    })
            
            # Fractales baissières (5 bougies)
            for i in range(2, len(df) - 2):
                if (lows[i] < lows[i-1] and lows[i] < lows[i-2] and
                    lows[i] < lows[i+1] and lows[i] < lows[i+2]):
                    fractal_lows.append({
                        'price': lows[i],
                        'index': i,
                        'method': 'fractal_low',
                        'strength': 1
                    })
            
            return {
                'fractal_highs': fractal_highs,
                'fractal_lows': fractal_lows
            }
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_fractal_levels : {e}")
            return {'fractal_highs': [], 'fractal_lows': []}
    
    def _detect_fibonacci_levels(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux basés sur les retracements de Fibonacci."""
        try:
            if len(df) < 20:
                return {'fibonacci_levels': []}
            
            # Trouver le swing high et low récents
            recent_high = df['high'].iloc[-20:].max()
            recent_low = df['low'].iloc[-20:].min()
            
            # Calcul des niveaux Fibonacci
            diff = recent_high - recent_low
            
            fib_levels = {
                '0.0': recent_low,
                '0.236': recent_low + 0.236 * diff,
                '0.382': recent_low + 0.382 * diff,
                '0.5': recent_low + 0.5 * diff,
                '0.618': recent_low + 0.618 * diff,
                '0.786': recent_low + 0.786 * diff,
                '1.0': recent_high
            }
            
            # Filtrer les niveaux proches du prix actuel
            current_price = df['close'].iloc[-1]
            relevant_levels = []
            
            for ratio, level in fib_levels.items():
                distance = abs(level - current_price) / current_price
                if distance < 0.05:  # Dans les 5% du prix actuel
                    relevant_levels.append({
                        'price': level,
                        'ratio': ratio,
                        'method': 'fibonacci',
                        'strength': 1 - float(ratio)  # Plus fort pour les ratios bas
                    })
            
            return {'fibonacci_levels': relevant_levels}
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_fibonacci_levels : {e}")
            return {'fibonacci_levels': []}
    
    def _merge_and_validate_levels(self, df: pd.DataFrame, all_levels: List[Dict]) -> Dict:
        """Fusionne et valide tous les niveaux détectés."""
        try:
            all_prices = []
            
            # Extraction de tous les prix
            for level_dict in all_levels:
                for key, levels in level_dict.items():
                    if isinstance(levels, list):
                        for level in levels:
                            if isinstance(level, dict) and 'price' in level:
                                all_prices.append({
                                    'price': level['price'],
                                    'method': level.get('method', 'unknown'),
                                    'strength': level.get('strength', 1),
                                    'volume_strength': level.get('volume_strength', 1),
                                    'original_data': level
                                })
            
            if not all_prices:
                return {'supports': [], 'resistances': []}
            
            # Clustering des prix proches
            prices_array = np.array([[price['price']] for price in all_prices])
            
            if len(prices_array) < self.config['min_samples']:
                # Pas assez de données pour le clustering
                return self._simple_grouping(all_prices)
            
            # Normalisation pour DBSCAN
            scaler = StandardScaler()
            prices_scaled = scaler.fit_transform(prices_array)
            
            # Clustering DBSCAN
            clustering = DBSCAN(
                eps=self.config['cluster_eps'],
                min_samples=self.config['min_samples']
            ).fit(prices_scaled)
            
            # Regroupement des niveaux par cluster
            clusters = {}
            for i, label in enumerate(clustering.labels_):
                if label not in clusters:
                    clusters[label] = []
                clusters[label].append(all_prices[i])
            
            # Fusion des niveaux par cluster
            merged_levels = []
            for cluster_id, cluster_levels in clusters.items():
                if cluster_id == -1:  # Points isolés
                    for level in cluster_levels:
                        merged_levels.append(level)
                else:
                    # Fusion des niveaux du cluster
                    avg_price = np.mean([level['price'] for level in cluster_levels])
                    total_strength = sum([level['strength'] for level in cluster_levels])
                    methods = list(set([level['method'] for level in cluster_levels]))
                    
                    merged_levels.append({
                        'price': avg_price,
                        'method': '+'.join(methods),
                        'strength': total_strength,
                        'volume_strength': np.mean([level.get('volume_strength', 1) for level in cluster_levels]),
                        'cluster_size': len(cluster_levels),
                        'original_data': cluster_levels
                    })
            
            return {'merged_levels': merged_levels}
            
        except Exception as e:
            logger.error(f"Erreur dans _merge_and_validate_levels : {e}")
            return {'merged_levels': []}
    
    def _simple_grouping(self, all_prices: List[Dict]) -> Dict:
        """Groupement simple quand le clustering n'est pas possible."""
        try:
            # Tri par prix
            sorted_prices = sorted(all_prices, key=lambda x: x['price'])
            
            # Groupement par proximité
            grouped = []
            current_group = [sorted_prices[0]]
            
            for price_data in sorted_prices[1:]:
                if abs(price_data['price'] - current_group[-1]['price']) / current_group[-1]['price'] < self.config['tolerance_pct']:
                    current_group.append(price_data)
                else:
                    # Nouveau groupe
                    if len(current_group) > 0:
                        grouped.append(self._merge_group(current_group))
                    current_group = [price_data]
            
            # Dernier groupe
            if len(current_group) > 0:
                grouped.append(self._merge_group(current_group))
            
            return {'merged_levels': grouped}
            
        except Exception as e:
            logger.error(f"Erreur dans _simple_grouping : {e}")
            return {'merged_levels': []}
    
    def _merge_group(self, group: List[Dict]) -> Dict:
        """Fusionne un groupe de niveaux."""
        try:
            avg_price = np.mean([level['price'] for level in group])
            total_strength = sum([level['strength'] for level in group])
            methods = list(set([level['method'] for level in group]))
            
            return {
                'price': avg_price,
                'method': '+'.join(methods),
                'strength': total_strength,
                'volume_strength': np.mean([level.get('volume_strength', 1) for level in group]),
                'cluster_size': len(group),
                'original_data': group
            }
        except Exception as e:
            logger.error(f"Erreur dans _merge_group : {e}")
            return {}
    
    def _calculate_strength_and_sort(self, df: pd.DataFrame, merged_data: Dict) -> Dict:
        """Calcule la force finale et trie les niveaux."""
        try:
            if 'merged_levels' not in merged_data:
                return {'supports': [], 'resistances': []}
            
            current_price = df['close'].iloc[-1]
            supports = []
            resistances = []
            
            for level in merged_data['merged_levels']:
                # Calcul de la force finale
                final_strength = self._calculate_final_strength(level, df)
                
                # Classification support/résistance
                if level['price'] < current_price:
                    supports.append({
                        **level,
                        'strength': final_strength,
                        'distance': (current_price - level['price']) / current_price
                    })
                else:
                    resistances.append({
                        **level,
                        'strength': final_strength,
                        'distance': (level['price'] - current_price) / current_price
                    })
            
            # Tri par force et distance
            supports.sort(key=lambda x: (-x['strength'], x['distance']))
            resistances.sort(key=lambda x: (-x['strength'], x['distance']))
            
            # Limitation du nombre de niveaux
            max_levels = self.config['max_levels'] // 2
            supports = supports[:max_levels]
            resistances = resistances[:max_levels]
            
            return {
                'supports': supports,
                'resistances': resistances,
                'current_price': current_price,
                'detection_time': pd.Timestamp.now()
            }
            
        except Exception as e:
            logger.error(f"Erreur dans _calculate_strength_and_sort : {e}")
            return {'supports': [], 'resistances': []}
    
    def _calculate_final_strength(self, level: Dict, df: pd.DataFrame) -> float:
        """Calcule la force finale d'un niveau avec les nouveaux facteurs."""
        try:
            weights = self.config['strength_weights']
            
            # Force de base
            base_strength = level.get('strength', 1)
            
            # Force du volume
            volume_strength = level.get('volume_strength', 1)
            
            # Force temporelle (décroissance)
            if 'timestamp' in level and hasattr(df.index, 'iloc'):
                time_diff = pd.Timestamp.now() - level['timestamp']
                time_factor = self.config['time_decay'] ** (time_diff.days)
            else:
                time_factor = 1.0
            
            # Force du clustering
            cluster_factor = min(level.get('cluster_size', 1) / 3, 2.0)
            
            # Force de la structure de marché
            market_structure_factor = 1.0
            if 'method' in level:
                if 'higher_high' in level['method'] or 'lower_low' in level['method']:
                    market_structure_factor = 2.0
                elif 'higher_low' in level['method'] or 'lower_high' in level['method']:
                    market_structure_factor = 1.5
            
            # Force psychologique
            psychological_factor = 1.0
            if 'psychological' in level.get('method', ''):
                psychological_factor = 1.5
            
            # Force du flux d'ordres
            order_flow_factor = 1.0
            if 'order_flow' in level.get('method', ''):
                order_flow_factor = 2.0
            
            # Calcul de la force finale
            final_strength = (
                weights['touches'] * base_strength +
                weights['volume'] * volume_strength +
                weights['time'] * time_factor +
                weights['price_cluster'] * cluster_factor +
                weights['market_structure'] * market_structure_factor +
                weights['psychological'] * psychological_factor +
                weights['order_flow'] * order_flow_factor
            )
            
            return min(final_strength, 10.0)  # Plafonner à 10
            
        except Exception as e:
            logger.error(f"Erreur dans _calculate_final_strength : {e}")
            return 1.0
    
    def get_levels_for_symbol(self, symbol: str) -> Optional[Dict]:
        """Récupère les niveaux en cache pour un symbole."""
        if symbol in self.levels_cache:
            cache_data = self.levels_cache[symbol]
            # Vérifier si le cache est encore valide (moins de 1 heure)
            if (pd.Timestamp.now() - cache_data['timestamp']).total_seconds() < 3600:
                return cache_data['levels']
        return None
    
    def clear_cache(self, symbol: str = None):
        """Efface le cache des niveaux."""
        if symbol:
            self.levels_cache.pop(symbol, None)
        else:
            self.levels_cache.clear()


    def _detect_market_structure_levels(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux basés sur la structure de marché (Higher Highs, Lower Lows)."""
        try:
            if len(df) < self.config['market_structure_window']:
                return {'market_structure_levels': []}
            
            highs = df['high'].values
            lows = df['low'].values
            window = self.config['market_structure_window']
            
            structure_levels = []
            
            # Détection des Higher Highs et Lower Highs
            for i in range(window, len(df) - window):
                current_high = highs[i]
                current_low = lows[i]
                
                # Vérifier si c'est un Higher High
                prev_highs = highs[i-window:i]
                if len(prev_highs) > 0 and current_high > np.max(prev_highs):
                    structure_levels.append({
                        'price': current_high,
                        'index': i,
                        'method': 'higher_high',
                        'strength': 2.0,
                        'type': 'resistance'
                    })
                
                # Vérifier si c'est un Lower Low
                prev_lows = lows[i-window:i]
                if len(prev_lows) > 0 and current_low < np.min(prev_lows):
                    structure_levels.append({
                        'price': current_low,
                        'index': i,
                        'method': 'lower_low',
                        'strength': 2.0,
                        'type': 'support'
                    })
                
                # Vérifier si c'est un Lower High (résistance potentielle)
                if len(prev_highs) > 0 and current_high < np.max(prev_highs):
                    structure_levels.append({
                        'price': current_high,
                        'index': i,
                        'method': 'lower_high',
                        'strength': 1.5,
                        'type': 'resistance'
                    })
                
                # Vérifier si c'est un Higher Low (support potentiel)
                if len(prev_lows) > 0 and current_low > np.min(prev_lows):
                    structure_levels.append({
                        'price': current_low,
                        'index': i,
                        'method': 'higher_low',
                        'strength': 1.5,
                        'type': 'support'
                    })
            
            return {'market_structure_levels': structure_levels}
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_market_structure_levels : {e}")
            return {'market_structure_levels': []}
    
    def _detect_psychological_levels(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux psychologiques (nombres ronds)."""
        try:
            if not self.config.get('psychological_levels', True):
                return {'psychological_levels': []}
            
            current_price = df['close'].iloc[-1]
            psychological_levels = []
            
            # Déterminer l'échelle des niveaux psychologiques
            if current_price > 1000:
                # Pour les indices et gros prix
                base_levels = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
                step = 1000
            elif current_price > 100:
                # Pour les prix moyens
                base_levels = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
                step = 100
            elif current_price > 10:
                # Pour les prix moyens-faibles
                base_levels = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
                step = 10
            elif current_price > 1:
                # Pour les prix faibles
                base_levels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                step = 1
            else:
                # Pour les très petits prix (crypto, etc.)
                base_levels = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
                step = 0.1
            
            # Générer les niveaux psychologiques autour du prix actuel
            min_price = current_price * 0.8
            max_price = current_price * 1.2
            
            for base in base_levels:
                # Niveaux multiples
                for multiplier in range(1, 20):
                    level = base * multiplier
                    if min_price <= level <= max_price:
                        # Calculer la force basée sur la proximité et la "rondeur"
                        distance = abs(level - current_price) / current_price
                        roundness_factor = 1.0 if level % step == 0 else 0.5
                        
                        psychological_levels.append({
                            'price': level,
                            'method': 'psychological',
                            'strength': roundness_factor * (1 - distance),
                            'type': 'support' if level < current_price else 'resistance'
                        })
            
            return {'psychological_levels': psychological_levels}
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_psychological_levels : {e}")
            return {'psychological_levels': []}
    
    def _detect_liquidity_zones(self, df: pd.DataFrame) -> Dict:
        """Détecte les zones de liquidité (zones où le prix a stagné)."""
        try:
            if not self.config.get('liquidity_zones', True) or len(df) < 50:
                return {'liquidity_zones': []}
            
            liquidity_zones = []
            window = 10  # Fenêtre pour détecter la stagnation
            
            # Analyser les zones de stagnation
            for i in range(window, len(df) - window):
                price_window = df['close'].iloc[i-window:i+window]
                high_window = df['high'].iloc[i-window:i+window]
                low_window = df['low'].iloc[i-window:i+window]
                
                # Calculer la volatilité de la fenêtre
                price_range = high_window.max() - low_window.min()
                avg_price = price_window.mean()
                volatility_ratio = price_range / avg_price if avg_price > 0 else 0
                
                # Si la volatilité est faible, c'est une zone de liquidité
                if volatility_ratio < 0.01:  # Moins de 1% de volatilité
                    liquidity_zones.append({
                        'price': avg_price,
                        'index': i,
                        'method': 'liquidity_zone',
                        'strength': 1.5,
                        'volatility': volatility_ratio,
                        'type': 'both'  # Peut être support ou résistance
                    })
            
            return {'liquidity_zones': liquidity_zones}
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_liquidity_zones : {e}")
            return {'liquidity_zones': []}
    
    def _detect_order_flow_levels(self, df: pd.DataFrame) -> Dict:
        """Détecte les niveaux basés sur l'analyse du flux d'ordres."""
        try:
            if not self.config.get('order_flow_analysis', True) or 'volume' not in df.columns:
                return {'order_flow_levels': []}
            
            order_flow_levels = []
            
            # Analyser les pics de volume avec rejet de prix
            for i in range(2, len(df) - 2):
                current_volume = df['volume'].iloc[i]
                avg_volume = df['volume'].iloc[i-10:i].mean() if i >= 10 else df['volume'].iloc[:i].mean()
                
                # Si le volume est élevé
                if current_volume > avg_volume * 1.5:
                    current_high = df['high'].iloc[i]
                    current_low = df['low'].iloc[i]
                    current_close = df['close'].iloc[i]
                    current_open = df['open'].iloc[i]
                    
                    # Détecter les rejets (long wicks)
                    body_size = abs(current_close - current_open)
                    upper_wick = current_high - max(current_open, current_close)
                    lower_wick = min(current_open, current_close) - current_low
                    
                    # Rejet haussier (long lower wick)
                    if lower_wick > body_size * 2:
                        order_flow_levels.append({
                            'price': current_low,
                            'index': i,
                            'method': 'order_flow_support',
                            'strength': 2.0,
                            'volume_ratio': current_volume / avg_volume,
                            'type': 'support'
                        })
                    
                    # Rejet baissier (long upper wick)
                    if upper_wick > body_size * 2:
                        order_flow_levels.append({
                            'price': current_high,
                            'index': i,
                            'method': 'order_flow_resistance',
                            'strength': 2.0,
                            'volume_ratio': current_volume / avg_volume,
                            'type': 'resistance'
                        })
            
            return {'order_flow_levels': order_flow_levels}
            
        except Exception as e:
            logger.error(f"Erreur dans _detect_order_flow_levels : {e}")
            return {'order_flow_levels': []}


# Fonctions utilitaires pour compatibilité
def get_advanced_support_resistance(df: pd.DataFrame, symbol: str = None) -> Dict:
    """Fonction utilitaire pour compatibilité avec l'ancien code."""
    detector = AdvancedSupportResistance()
    return detector.detect_all_levels(df, symbol)


def get_support_resistance_zones_advanced(df: pd.DataFrame, symbol: str = None) -> Dict:
    """Version avancée de get_support_resistance_zones."""
    return get_advanced_support_resistance(df, symbol)
