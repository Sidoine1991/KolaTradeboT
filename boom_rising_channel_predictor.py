#!/usr/bin/env python3
"""
Prédicteur de Spikes Boom - Pattern Ciseau Montant (Canal Haussier)
Système spécialisé pour détecter les patterns de canal haussier sur Boom
et prédire les spikes avec flèches dynamiques
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from datetime import datetime, timedelta
import time
import json
from typing import Dict, List, Tuple, Optional
import threading
from dataclasses import dataclass
from enum import Enum

class SpikeDirection(Enum):
    BOOM = "BOOM"
    CRASH = "CRASH"
    NEUTRAL = "NEUTRAL"

@dataclass
class PredictionArrow:
    """Représente une flèche de prédiction sur le graphique"""
    timestamp: float
    price: float
    direction: SpikeDirection
    confidence: float
    ema_proximity: str  # "EMA10", "EMA30", "EMA50"
    channel_position: str  # "upper", "middle", "lower"
    spike_probability: float
    time_to_spike: int  # en secondes

@dataclass
class RisingChannel:
    """Représente un canal haussier détecté"""
    upper_line: List[Tuple[float, float]]  # [(timestamp, price), ...]
    lower_line: List[Tuple[float, float]]
    slope: float
    strength: float  # 0-1
    duration: int  # en minutes
    breakout_probability: float

class BoomRisingChannelPredictor:
    """Prédicteur spécialisé pour les patterns de canal haussier sur Boom"""
    
    def __init__(self):
        self.symbol = "Boom 1000 Index"
        self.timeframe = "M1"
        self.price_history = []
        self.ema_values = {}
        self.rising_channels = []
        self.prediction_arrows = []
        self.last_prediction_time = 0
        self.prediction_cooldown = 30  # 30 secondes entre prédictions
        
        # Configuration EMA
        self.ema_periods = [10, 30, 50]
        self.ema_proximity_threshold = 0.002  # 0.2% de proximité
        
        # Configuration canal haussier
        self.channel_min_duration = 5  # 5 minutes minimum
        self.channel_slope_threshold = 0.001  # Pente minimale
        self.channel_strength_threshold = 0.7  # Force minimale
        
        # Configuration prédiction
        self.spike_probability_threshold = 0.75
        self.max_arrows_per_chart = 20
        
        # Historique des prédictions
        self.prediction_history = []
        self.success_rate = 0.0
        
    def update_price_data(self, price_data: List[Dict]):
        """Met à jour les données de prix"""
        self.price_history = price_data
        
        # Calculer les EMAs
        self._calculate_emas()
        
        # Détecter les canaux haussiers
        self._detect_rising_channels()
        
        # Générer les prédictions
        self._generate_predictions()
    
    def _calculate_emas(self):
        """Calcule les moyennes mobiles exponentielles"""
        if len(self.price_history) < max(self.ema_periods):
            return
            
        prices = [float(candle['close']) for candle in self.price_history]
        
        for period in self.ema_periods:
            if len(prices) >= period:
                ema_values = self._calculate_ema(prices, period)
                self.ema_values[f'EMA{period}'] = ema_values
    
    def _calculate_ema(self, prices: List[float], period: int) -> List[float]:
        """Calcule l'EMA pour une période donnée"""
        if len(prices) < period:
            return []
            
        multiplier = 2 / (period + 1)
        ema_values = [prices[0]]  # Premier EMA = premier prix
        
        for i in range(1, len(prices)):
            ema = (prices[i] * multiplier) + (ema_values[-1] * (1 - multiplier))
            ema_values.append(ema)
            
        return ema_values
    
    def _detect_rising_channels(self):
        """Détecte les patterns de canal haussier"""
        if len(self.price_history) < 20:
            return
            
        # Analyser les dernières 50 bougies pour détecter le canal
        recent_candles = self.price_history[-50:]
        highs = [float(candle['high']) for candle in recent_candles]
        lows = [float(candle['low']) for candle in recent_candles]
        timestamps = [candle['timestamp'] for candle in recent_candles]
        
        # Détecter les lignes de tendance haussières
        upper_trendline = self._find_trendline(timestamps, highs, "upper")
        lower_trendline = self._find_trendline(timestamps, lows, "lower")
        
        if upper_trendline and lower_trendline:
            # Vérifier si c'est un canal haussier valide
            channel = self._validate_rising_channel(upper_trendline, lower_trendline)
            if channel:
                self.rising_channels.append(channel)
                # Garder seulement les 5 derniers canaux
                if len(self.rising_channels) > 5:
                    self.rising_channels = self.rising_channels[-5:]
    
    def _find_trendline(self, timestamps: List, prices: List[float], line_type: str) -> Optional[List[Tuple[float, float]]]:
        """Trouve une ligne de tendance dans les données"""
        if len(prices) < 10:
            return None
            
        # Utiliser les points pivots pour créer la ligne de tendance
        pivot_points = self._find_pivot_points(prices, line_type)
        
        if len(pivot_points) < 2:
            return None
            
        # Calculer la ligne de tendance avec régression linéaire
        trendline_points = []
        for i, pivot_idx in enumerate(pivot_points):
            if i < len(timestamps):
                trendline_points.append((timestamps[pivot_idx], prices[pivot_idx]))
        
        # Calculer la pente et l'ordonnée à l'origine
        if len(trendline_points) >= 2:
            slope, intercept = self._linear_regression(trendline_points)
            
            # Créer la ligne complète
            full_trendline = []
            for i, timestamp in enumerate(timestamps):
                if i < len(prices):
                    trend_price = slope * i + intercept
                    full_trendline.append((timestamp, trend_price))
            
            return full_trendline
        
        return None
    
    def _find_pivot_points(self, prices: List[float], line_type: str) -> List[int]:
        """Trouve les points pivots dans les prix"""
        pivot_points = []
        window = 3
        
        for i in range(window, len(prices) - window):
            if line_type == "upper":
                # Point pivot haut
                if all(prices[i] >= prices[i-j] for j in range(1, window+1)) and \
                   all(prices[i] >= prices[i+j] for j in range(1, window+1)):
                    pivot_points.append(i)
            else:
                # Point pivot bas
                if all(prices[i] <= prices[i-j] for j in range(1, window+1)) and \
                   all(prices[i] <= prices[i+j] for j in range(1, window+1)):
                    pivot_points.append(i)
        
        return pivot_points
    
    def _linear_regression(self, points: List[Tuple[float, float]]) -> Tuple[float, float]:
        """Calcule la régression linéaire pour les points donnés"""
        if len(points) < 2:
            return 0, 0
            
        x_values = [i for i in range(len(points))]
        y_values = [point[1] for point in points]
        
        n = len(points)
        sum_x = sum(x_values)
        sum_y = sum(y_values)
        sum_xy = sum(x * y for x, y in zip(x_values, y_values))
        sum_x2 = sum(x * x for x in x_values)
        
        slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
        intercept = (sum_y - slope * sum_x) / n
        
        return slope, intercept
    
    def _validate_rising_channel(self, upper_line: List[Tuple[float, float]], 
                               lower_line: List[Tuple[float, float]]) -> Optional[RisingChannel]:
        """Valide si les lignes forment un canal haussier valide"""
        if len(upper_line) < 2 or len(lower_line) < 2:
            return None
            
        # Calculer les pentes
        upper_slope = (upper_line[-1][1] - upper_line[0][1]) / (len(upper_line) - 1)
        lower_slope = (lower_line[-1][1] - lower_line[0][1]) / (len(lower_line) - 1)
        
        # Vérifier que les deux lignes sont haussières
        if upper_slope < self.channel_slope_threshold or lower_slope < self.channel_slope_threshold:
            return None
            
        # Calculer la force du canal
        strength = self._calculate_channel_strength(upper_line, lower_line)
        
        if strength < self.channel_strength_threshold:
            return None
            
        # Calculer la probabilité de breakout
        breakout_prob = self._calculate_breakout_probability(upper_line, lower_line)
        
        return RisingChannel(
            upper_line=upper_line,
            lower_line=lower_line,
            slope=(upper_slope + lower_slope) / 2,
            strength=strength,
            duration=len(upper_line),
            breakout_probability=breakout_prob
        )
    
    def _calculate_channel_strength(self, upper_line: List[Tuple[float, float]], 
                                  lower_line: List[Tuple[float, float]]) -> float:
        """Calcule la force du canal (0-1)"""
        if len(upper_line) != len(lower_line):
            return 0.0
            
        # Calculer la cohérence des lignes
        upper_consistency = self._calculate_line_consistency(upper_line)
        lower_consistency = self._calculate_line_consistency(lower_line)
        
        # Calculer la distance moyenne entre les lignes
        distances = []
        for i in range(len(upper_line)):
            distance = abs(upper_line[i][1] - lower_line[i][1])
            distances.append(distance)
        
        avg_distance = np.mean(distances)
        distance_consistency = 1.0 - (np.std(distances) / avg_distance) if avg_distance > 0 else 0.0
        
        # Force globale
        strength = (upper_consistency + lower_consistency + distance_consistency) / 3
        return min(strength, 1.0)
    
    def _calculate_line_consistency(self, line: List[Tuple[float, float]]) -> float:
        """Calcule la cohérence d'une ligne de tendance"""
        if len(line) < 3:
            return 0.0
            
        # Calculer les écarts par rapport à la ligne de régression
        prices = [point[1] for point in line]
        slope, intercept = self._linear_regression(line)
        
        predicted_prices = [slope * i + intercept for i in range(len(prices))]
        errors = [abs(actual - predicted) for actual, predicted in zip(prices, predicted_prices)]
        
        # Cohérence = 1 - (écart moyen / prix moyen)
        avg_error = np.mean(errors)
        avg_price = np.mean(prices)
        consistency = 1.0 - (avg_error / avg_price) if avg_price > 0 else 0.0
        
        return max(consistency, 0.0)
    
    def _calculate_breakout_probability(self, upper_line: List[Tuple[float, float]], 
                                      lower_line: List[Tuple[float, float]]) -> float:
        """Calcule la probabilité de breakout du canal"""
        if not self.price_history:
            return 0.0
            
        current_price = float(self.price_history[-1]['close'])
        
        # Distance par rapport aux lignes du canal
        upper_distance = abs(current_price - upper_line[-1][1])
        lower_distance = abs(current_price - lower_line[-1][1])
        
        # Plus le prix est proche d'une ligne, plus la probabilité de breakout est élevée
        min_distance = min(upper_distance, lower_distance)
        max_distance = max(upper_distance, lower_distance)
        
        # Probabilité basée sur la proximité
        proximity_factor = 1.0 - (min_distance / max_distance) if max_distance > 0 else 0.0
        
        # Facteur de volatilité récente
        volatility_factor = self._calculate_recent_volatility()
        
        # Probabilité combinée
        breakout_prob = (proximity_factor * 0.6 + volatility_factor * 0.4)
        return min(breakout_prob, 1.0)
    
    def _calculate_recent_volatility(self) -> float:
        """Calcule la volatilité récente"""
        if len(self.price_history) < 10:
            return 0.0
            
        recent_prices = [float(candle['close']) for candle in self.price_history[-10:]]
        returns = [abs(recent_prices[i] - recent_prices[i-1]) / recent_prices[i-1] 
                  for i in range(1, len(recent_prices))]
        
        volatility = np.mean(returns)
        # Normaliser entre 0 et 1
        return min(volatility * 100, 1.0)
    
    def _generate_predictions(self):
        """Génère les prédictions de spikes"""
        current_time = time.time()
        
        # Vérifier le cooldown
        if current_time - self.last_prediction_time < self.prediction_cooldown:
            return
            
        if not self.price_history or not self.rising_channels:
            return
            
        current_price = float(self.price_history[-1]['close'])
        
        # Vérifier la proximité avec les EMAs
        ema_proximity = self._check_ema_proximity(current_price)
        
        if ema_proximity:
            # Vérifier la position dans le canal
            channel_position = self._get_channel_position(current_price)
            
            if channel_position:
                # Calculer la probabilité de spike
                spike_probability = self._calculate_spike_probability(
                    ema_proximity, channel_position
                )
                
                if spike_probability >= self.spike_probability_threshold:
                    # Créer la flèche de prédiction
                    arrow = self._create_prediction_arrow(
                        current_price, ema_proximity, channel_position, spike_probability
                    )
                    
                    if arrow:
                        self.prediction_arrows.append(arrow)
                        self.last_prediction_time = current_time
                        
                        # Garder seulement les dernières flèches
                        if len(self.prediction_arrows) > self.max_arrows_per_chart:
                            self.prediction_arrows = self.prediction_arrows[-self.max_arrows_per_chart:]
    
    def _check_ema_proximity(self, current_price: float) -> Optional[str]:
        """Vérifie la proximité avec les EMAs"""
        for ema_name, ema_values in self.ema_values.items():
            if ema_values:
                latest_ema = ema_values[-1]
                distance = abs(current_price - latest_ema) / current_price
                
                if distance <= self.ema_proximity_threshold:
                    return ema_name
                    
        return None
    
    def _get_channel_position(self, current_price: float) -> Optional[str]:
        """Détermine la position du prix dans le canal"""
        if not self.rising_channels:
            return None
            
        latest_channel = self.rising_channels[-1]
        upper_price = latest_channel.upper_line[-1][1]
        lower_price = latest_channel.lower_line[-1][1]
        
        channel_height = upper_price - lower_price
        if channel_height <= 0:
            return None
            
        # Position relative dans le canal (0 = bas, 1 = haut)
        relative_position = (current_price - lower_price) / channel_height
        
        if relative_position < 0.3:
            return "lower"
        elif relative_position > 0.7:
            return "upper"
        else:
            return "middle"
    
    def _calculate_spike_probability(self, ema_proximity: str, channel_position: str) -> float:
        """Calcule la probabilité de spike basée sur les conditions"""
        base_probability = 0.5
        
        # Facteurs EMA
        ema_factors = {
            "EMA10": 0.9,   # Plus réactif
            "EMA30": 0.8,   # Moyen
            "EMA50": 0.7    # Plus stable
        }
        
        # Facteurs position canal
        position_factors = {
            "lower": 0.8,   # Support du canal
            "middle": 0.6,  # Zone neutre
            "upper": 0.9    # Résistance du canal
        }
        
        ema_factor = ema_factors.get(ema_proximity, 0.5)
        position_factor = position_factors.get(channel_position, 0.5)
        
        # Probabilité combinée
        spike_probability = base_probability * ema_factor * position_factor
        
        # Ajouter le facteur de force du canal
        if self.rising_channels:
            channel_strength = self.rising_channels[-1].strength
            spike_probability *= (0.5 + channel_strength * 0.5)
        
        return min(spike_probability, 0.95)
    
    def _create_prediction_arrow(self, price: float, ema_proximity: str, 
                               channel_position: str, spike_probability: float) -> Optional[PredictionArrow]:
        """Crée une flèche de prédiction"""
        # Déterminer la direction du spike
        direction = self._predict_spike_direction(channel_position, spike_probability)
        
        # Estimer le temps jusqu'au spike
        time_to_spike = self._estimate_time_to_spike(spike_probability)
        
        # Calculer la confiance
        confidence = spike_probability * 0.9  # Légèrement plus conservateur
        
        return PredictionArrow(
            timestamp=time.time(),
            price=price,
            direction=direction,
            confidence=confidence,
            ema_proximity=ema_proximity,
            channel_position=channel_position,
            spike_probability=spike_probability,
            time_to_spike=time_to_spike
        )
    
    def _predict_spike_direction(self, channel_position: str, spike_probability: float) -> SpikeDirection:
        """Prédit la direction du spike"""
        # Dans un canal haussier, les spikes sont généralement haussiers
        # Mais on peut avoir des corrections
        
        if channel_position == "lower":
            # Proche du support -> spike haussier probable
            return SpikeDirection.BOOM
        elif channel_position == "upper":
            # Proche de la résistance -> possible correction
            return SpikeDirection.CRASH if spike_probability > 0.8 else SpikeDirection.BOOM
        else:
            # Position moyenne -> direction selon la probabilité
            return SpikeDirection.BOOM if spike_probability > 0.7 else SpikeDirection.NEUTRAL
    
    def _estimate_time_to_spike(self, spike_probability: float) -> int:
        """Estime le temps jusqu'au spike"""
        if spike_probability > 0.9:
            return 30  # 30 secondes
        elif spike_probability > 0.8:
            return 60  # 1 minute
        elif spike_probability > 0.75:
            return 120  # 2 minutes
        else:
            return 300  # 5 minutes
    
    def get_trading_signal(self) -> Dict:
        """Génère un signal de trading basé sur les prédictions"""
        if not self.prediction_arrows:
            return {"action": "HOLD", "reason": "Aucune prédiction active"}
        
        # Prendre la dernière prédiction
        latest_arrow = self.prediction_arrows[-1]
        
        # Vérifier si la prédiction est encore valide
        time_since_prediction = time.time() - latest_arrow.timestamp
        if time_since_prediction > latest_arrow.time_to_spike:
            return {"action": "HOLD", "reason": "Prédiction expirée"}
        
        # Générer le signal
        signal = {
            "symbol": self.symbol,
            "timestamp": time.time(),
            "action": "BUY" if latest_arrow.direction == SpikeDirection.BOOM else "SELL",
            "direction": latest_arrow.direction.value,
            "confidence": latest_arrow.confidence,
            "spike_probability": latest_arrow.spike_probability,
            "time_to_spike": latest_arrow.time_to_spike - int(time_since_prediction),
            "ema_proximity": latest_arrow.ema_proximity,
            "channel_position": latest_arrow.channel_position,
            "current_price": latest_arrow.price,
            "stop_loss": self._calculate_stop_loss(latest_arrow),
            "take_profit": self._calculate_take_profit(latest_arrow),
            "lot_size": self._calculate_lot_size(latest_arrow.confidence),
            "reasoning": f"Pattern canal haussier détecté - Proximité {latest_arrow.ema_proximity} - Position {latest_arrow.channel_position}"
        }
        
        return signal
    
    def _calculate_stop_loss(self, arrow: PredictionArrow) -> float:
        """Calcule le stop loss"""
        if arrow.direction == SpikeDirection.BOOM:
            return arrow.price * 0.998  # -0.2%
        else:
            return arrow.price * 1.002  # +0.2%
    
    def _calculate_take_profit(self, arrow: PredictionArrow) -> float:
        """Calcule le take profit"""
        if arrow.direction == SpikeDirection.BOOM:
            return arrow.price * 1.005  # +0.5%
        else:
            return arrow.price * 0.995  # -0.5%
    
    def _calculate_lot_size(self, confidence: float) -> float:
        """Calcule la taille de lot selon la confiance"""
        base_lot = 0.1
        multiplier = confidence * 2  # 0.1 à 0.2 selon la confiance
        return base_lot * multiplier
    
    def create_chart_with_arrows(self, save_path: str = None) -> str:
        """Crée un graphique avec les flèches de prédiction"""
        if not self.price_history:
            return "Aucune donnée disponible"
        
        # Préparer les données
        timestamps = [candle['timestamp'] for candle in self.price_history[-100:]]
        prices = [float(candle['close']) for candle in self.price_history[-100:]]
        
        # Créer le graphique
        fig, ax = plt.subplots(figsize=(15, 8))
        
        # Tracer les prix
        ax.plot(timestamps, prices, 'b-', linewidth=1, label='Prix Boom')
        
        # Tracer les EMAs
        colors = {'EMA10': 'red', 'EMA30': 'orange', 'EMA50': 'green'}
        for ema_name, ema_values in self.ema_values.items():
            if ema_values and len(ema_values) >= len(timestamps):
                recent_ema = ema_values[-len(timestamps):]
                ax.plot(timestamps, recent_ema, color=colors.get(ema_name, 'gray'), 
                       linewidth=1, label=ema_name, alpha=0.7)
        
        # Tracer les canaux haussiers
        for i, channel in enumerate(self.rising_channels[-2:]):  # 2 derniers canaux
            if len(channel.upper_line) >= len(timestamps):
                upper_prices = [point[1] for point in channel.upper_line[-len(timestamps):]]
                lower_prices = [point[1] for point in channel.lower_line[-len(timestamps):]]
                
                ax.plot(timestamps, upper_prices, 'g--', alpha=0.6, linewidth=2)
                ax.plot(timestamps, lower_prices, 'g--', alpha=0.6, linewidth=2)
                
                # Remplir le canal
                ax.fill_between(timestamps, upper_prices, lower_prices, 
                               alpha=0.1, color='green', label=f'Canal Haussier {i+1}')
        
        # Ajouter les flèches de prédiction
        for arrow in self.prediction_arrows[-10:]:  # 10 dernières flèches
            arrow_time = arrow.timestamp
            arrow_price = arrow.price
            
            # Couleur selon la direction
            color = 'green' if arrow.direction == SpikeDirection.BOOM else 'red'
            marker = '^' if arrow.direction == SpikeDirection.BOOM else 'v'
            
            ax.scatter(arrow_time, arrow_price, color=color, marker=marker, 
                      s=100, alpha=0.8, edgecolors='black', linewidth=1)
            
            # Ajouter le texte de confiance
            ax.annotate(f'{arrow.confidence:.1%}', 
                       xy=(arrow_time, arrow_price),
                       xytext=(5, 5), textcoords='offset points',
                       fontsize=8, color=color, weight='bold')
        
        # Configuration du graphique
        ax.set_title(f'Boom Rising Channel Predictor - {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}', 
                    fontsize=14, fontweight='bold')
        ax.set_xlabel('Temps')
        ax.set_ylabel('Prix')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Rotation des labels x
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        # Sauvegarder ou afficher
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            plt.close()
            return f"Graphique sauvegardé: {save_path}"
        else:
            plt.show()
            return "Graphique affiché"
    
    def get_prediction_summary(self) -> Dict:
        """Retourne un résumé des prédictions"""
        if not self.prediction_arrows:
            return {"status": "Aucune prédiction active"}
        
        latest_arrow = self.prediction_arrows[-1]
        
        return {
            "status": "Prédiction active",
            "latest_prediction": {
                "direction": latest_arrow.direction.value,
                "confidence": f"{latest_arrow.confidence:.1%}",
                "spike_probability": f"{latest_arrow.spike_probability:.1%}",
                "time_to_spike": f"{latest_arrow.time_to_spike}s",
                "ema_proximity": latest_arrow.ema_proximity,
                "channel_position": latest_arrow.channel_position
            },
            "total_predictions": len(self.prediction_arrows),
            "active_channels": len(self.rising_channels),
            "success_rate": f"{self.success_rate:.1%}"
        }

# Instance globale du prédicteur
boom_predictor = BoomRisingChannelPredictor()

def get_boom_prediction() -> Dict:
    """Fonction principale pour obtenir une prédiction Boom"""
    return boom_predictor.get_trading_signal()

def update_boom_data(price_data: List[Dict]):
    """Met à jour les données Boom"""
    boom_predictor.update_price_data(price_data)

def create_boom_chart(save_path: str = None) -> str:
    """Crée le graphique Boom avec prédictions"""
    return boom_predictor.create_chart_with_arrows(save_path)

def get_boom_summary() -> Dict:
    """Obtient le résumé des prédictions Boom"""
    return boom_predictor.get_prediction_summary()

if __name__ == "__main__":
    # Test du prédicteur Boom
    print("🚀 Test du Prédicteur Boom - Canal Haussier")
    print("=" * 50)
    
    # Simulation de données de prix
    test_data = []
    base_price = 10000.0
    
    for i in range(100):
        # Simulation d'un canal haussier
        trend_factor = i * 0.1  # Tendance haussière
        noise = np.random.normal(0, 0.5)
        price = base_price + trend_factor + noise
        
        test_data.append({
            'timestamp': time.time() - (100-i) * 60,  # 1 minute par bougie
            'open': price,
            'high': price + abs(np.random.normal(0, 0.3)),
            'low': price - abs(np.random.normal(0, 0.3)),
            'close': price,
            'volume': np.random.randint(1000, 5000)
        })
    
    # Mettre à jour les données
    update_boom_data(test_data)
    
    # Obtenir la prédiction
    prediction = get_boom_prediction()
    print(f"\n📊 Prédiction actuelle:")
    print(f"   Action: {prediction.get('action', 'N/A')}")
    print(f"   Direction: {prediction.get('direction', 'N/A')}")
    print(f"   Confiance: {prediction.get('confidence', 0):.1%}")
    print(f"   Probabilité spike: {prediction.get('spike_probability', 0):.1%}")
    print(f"   Temps estimé: {prediction.get('time_to_spike', 0)}s")
    print(f"   Raison: {prediction.get('reasoning', 'N/A')}")
    
    # Créer le graphique
    chart_path = "boom_rising_channel_chart.png"
    result = create_boom_chart(chart_path)
    print(f"\n📈 {result}")
    
    # Résumé
    summary = get_boom_summary()
    print(f"\n📋 Résumé:")
    print(f"   Statut: {summary.get('status', 'N/A')}")
    print(f"   Prédictions totales: {summary.get('total_predictions', 0)}")
    print(f"   Canaux actifs: {summary.get('active_channels', 0)}")
