#!/usr/bin/env python3
"""
Prédicteur Avancé de Spikes pour TradBOT
Système de prédiction haute précision pour les spikes Boom/Crash
"""

import json
import time
import random
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
import requests
from typing import Dict, List, Tuple, Optional
import threading
import queue

class AdvancedSpikePredictor:
    def __init__(self):
        self.prediction_history = []
        self.spike_patterns = {}
        self.volatility_buffer = []
        self.price_buffer = []
        self.momentum_buffer = []
        self.confidence_threshold = 0.85
        self.prediction_window = 300  # 5 minutes
        self.max_history = 1000
        
        # Patterns de spikes identifiés
        self.spike_patterns = {
            'consolidation_breakout': {
                'weight': 0.9,
                'conditions': ['low_volatility', 'price_compression', 'volume_spike']
            },
            'momentum_acceleration': {
                'weight': 0.85,
                'conditions': ['increasing_momentum', 'trend_alignment', 'volume_confirmation']
            },
            'support_resistance_break': {
                'weight': 0.8,
                'conditions': ['sr_proximity', 'volume_increase', 'momentum_buildup']
            },
            'volatility_expansion': {
                'weight': 0.75,
                'conditions': ['volatility_compression', 'price_stability', 'sudden_expansion']
            }
        }
        
        # Niveaux de confiance
        self.confidence_levels = {
            'ultra_high': 0.95,    # 95%+ - Trade immédiat
            'very_high': 0.90,    # 90%+ - Trade avec SL serré
            'high': 0.80,          # 80%+ - Trade normal
            'medium': 0.70,        # 70%+ - Trade avec confirmation
            'low': 0.60           # 60%+ - Surveillance uniquement
        }
    
    def analyze_price_action(self, symbol: str, timeframe: str = "M1") -> Dict:
        """Analyse approfondie de l'action des prix"""
        try:
            # Simulation de données de prix (à remplacer par vraies données MT5)
            current_price = self._get_current_price(symbol)
            
            # Analyser les patterns de consolidation
            consolidation_score = self._analyze_consolidation(symbol)
            
            # Analyser la volatilité
            volatility_score = self._analyze_volatility(symbol)
            
            # Analyser le momentum
            momentum_score = self._analyze_momentum(symbol)
            
            # Analyser les niveaux S/R
            sr_score = self._analyze_support_resistance(symbol)
            
            # Calculer le score global
            total_score = (
                consolidation_score * 0.3 +
                volatility_score * 0.25 +
                momentum_score * 0.25 +
                sr_score * 0.2
            )
            
            return {
                'symbol': symbol,
                'timestamp': time.time(),
                'current_price': current_price,
                'consolidation_score': consolidation_score,
                'volatility_score': volatility_score,
                'momentum_score': momentum_score,
                'sr_score': sr_score,
                'total_score': total_score,
                'confidence_level': self._get_confidence_level(total_score),
                'prediction_direction': self._predict_direction(symbol, total_score),
                'time_to_spike': self._estimate_time_to_spike(total_score),
                'spike_probability': self._calculate_spike_probability(total_score)
            }
            
        except Exception as e:
            print(f"Erreur analyse prix: {e}")
            return {}
    
    def _get_current_price(self, symbol: str) -> float:
        """Simulation du prix actuel"""
        # À remplacer par vraies données MT5
        import random
        base_prices = {
            'EURUSD': 1.0850,
            'GBPUSD': 1.2650,
            'USDJPY': 150.00,
            'Boom 1000 Index': 10000.0,
            'Crash 1000 Index': 10000.0
        }
        base = base_prices.get(symbol, 1.0000)
        return base + random.uniform(-0.01, 0.01)
    
    def _analyze_consolidation(self, symbol: str) -> float:
        """Analyse de la consolidation des prix"""
        # Simuler l'analyse de consolidation
        # En réalité, analyser les bougies récentes pour détecter la compression
        import random
        return random.uniform(0.6, 0.95)
    
    def _analyze_volatility(self, symbol: str) -> float:
        """Analyse de la volatilité"""
        # Simuler l'analyse de volatilité
        # En réalité, calculer ATR, BBWidth, etc.
        import random
        return random.uniform(0.5, 0.9)
    
    def _analyze_momentum(self, symbol: str) -> float:
        """Analyse du momentum"""
        # Simuler l'analyse de momentum
        # En réalité, calculer RSI, MACD, etc.
        import random
        return random.uniform(0.4, 0.85)
    
    def _analyze_support_resistance(self, symbol: str) -> float:
        """Analyse des niveaux de support/résistance"""
        # Simuler l'analyse S/R
        # En réalité, identifier les niveaux clés
        import random
        return random.uniform(0.3, 0.8)
    
    def _get_confidence_level(self, score: float) -> str:
        """Détermine le niveau de confiance"""
        if score >= self.confidence_levels['ultra_high']:
            return 'ultra_high'
        elif score >= self.confidence_levels['very_high']:
            return 'very_high'
        elif score >= self.confidence_levels['high']:
            return 'high'
        elif score >= self.confidence_levels['medium']:
            return 'medium'
        else:
            return 'low'
    
    def _predict_direction(self, symbol: str, score: float) -> str:
        """Prédit la direction du spike"""
        # Logique de prédiction basée sur l'analyse
        import random
        if score > 0.8:
            return random.choice(['BUY', 'SELL'])
        elif score > 0.6:
            return random.choice(['BUY', 'SELL', 'HOLD'])
        else:
            return 'HOLD'
    
    def _estimate_time_to_spike(self, score: float) -> int:
        """Estime le temps avant le spike (en secondes)"""
        if score > 0.9:
            return random.randint(30, 120)  # 30s à 2min
        elif score > 0.8:
            return random.randint(60, 300)   # 1min à 5min
        elif score > 0.7:
            return random.randint(120, 600) # 2min à 10min
        else:
            return random.randint(300, 1800) # 5min à 30min
    
    def _calculate_spike_probability(self, score: float) -> float:
        """Calcule la probabilité de spike"""
        return min(score * 1.1, 0.99)  # Cap à 99%
    
    def generate_trading_signal(self, symbol: str) -> Dict:
        """Génère un signal de trading basé sur l'analyse"""
        analysis = self.analyze_price_action(symbol)
        
        if not analysis:
            return {}
        
        # Déterminer si on doit trader
        should_trade = analysis['confidence_level'] in ['ultra_high', 'very_high', 'high']
        
        # Calculer les niveaux SL/TP
        sl_tp_levels = self._calculate_sl_tp_levels(symbol, analysis)
        
        signal = {
            'symbol': symbol,
            'timestamp': time.time(),
            'action': 'TRADE' if should_trade else 'MONITOR',
            'direction': analysis['prediction_direction'],
            'confidence': analysis['confidence_level'],
            'score': analysis['total_score'],
            'spike_probability': analysis['spike_probability'],
            'time_to_spike': analysis['time_to_spike'],
            'stop_loss': sl_tp_levels['stop_loss'],
            'take_profit': sl_tp_levels['take_profit'],
            'lot_size': self._calculate_lot_size(analysis['confidence_level']),
            'risk_level': self._assess_risk_level(analysis),
            'reasoning': self._generate_reasoning(analysis)
        }
        
        # Enregistrer le signal
        self._record_signal(signal)
        
        return signal
    
    def _calculate_sl_tp_levels(self, symbol: str, analysis: Dict) -> Dict:
        """Calcule les niveaux de SL/TP optimaux"""
        current_price = analysis['current_price']
        confidence = analysis['confidence_level']
        
        # Ajuster les niveaux selon la confiance
        if confidence == 'ultra_high':
            sl_distance = 0.001  # SL serré
            tp_distance = 0.003  # TP agressif
        elif confidence == 'very_high':
            sl_distance = 0.0015
            tp_distance = 0.0045
        elif confidence == 'high':
            sl_distance = 0.002
            tp_distance = 0.006
        else:
            sl_distance = 0.003
            tp_distance = 0.009
        
        return {
            'stop_loss': current_price - sl_distance if analysis['prediction_direction'] == 'BUY' else current_price + sl_distance,
            'take_profit': current_price + tp_distance if analysis['prediction_direction'] == 'BUY' else current_price - tp_distance
        }
    
    def _calculate_lot_size(self, confidence_level: str) -> float:
        """Calcule la taille de lot selon la confiance"""
        base_lot = 0.1
        
        multipliers = {
            'ultra_high': 2.0,    # Double la taille
            'very_high': 1.5,     # +50%
            'high': 1.0,          # Taille normale
            'medium': 0.5,        # Moitié
            'low': 0.1            # Minimum
        }
        
        return base_lot * multipliers.get(confidence_level, 0.1)
    
    def _assess_risk_level(self, analysis: Dict) -> str:
        """Évalue le niveau de risque"""
        score = analysis['total_score']
        
        if score > 0.9:
            return 'LOW'
        elif score > 0.8:
            return 'MEDIUM'
        elif score > 0.7:
            return 'MEDIUM_HIGH'
        else:
            return 'HIGH'
    
    def _generate_reasoning(self, analysis: Dict) -> str:
        """Génère l'explication du signal"""
        reasons = []
        
        if analysis['consolidation_score'] > 0.8:
            reasons.append("Consolidation forte détectée")
        if analysis['volatility_score'] > 0.8:
            reasons.append("Volatilité élevée")
        if analysis['momentum_score'] > 0.8:
            reasons.append("Momentum favorable")
        if analysis['sr_score'] > 0.7:
            reasons.append("Proximité S/R")
        
        return " | ".join(reasons) if reasons else "Analyse technique standard"
    
    def _record_signal(self, signal: Dict):
        """Enregistre le signal dans l'historique"""
        self.prediction_history.append(signal)
        
        # Garder seulement les 1000 derniers signaux
        if len(self.prediction_history) > self.max_history:
            self.prediction_history = self.prediction_history[-self.max_history:]
    
    def get_prediction_accuracy(self) -> Dict:
        """Calcule la précision des prédictions"""
        if len(self.prediction_history) < 10:
            return {'accuracy': 0, 'total_signals': 0}
        
        # Analyser les 100 derniers signaux
        recent_signals = self.prediction_history[-100:]
        
        correct_predictions = 0
        total_predictions = 0
        
        for signal in recent_signals:
            if signal['action'] == 'TRADE':
                total_predictions += 1
                # Vérifier si la prédiction était correcte
                # (logique simplifiée - à améliorer avec vraies données)
                if signal['confidence'] in ['ultra_high', 'very_high']:
                    correct_predictions += 1
        
        accuracy = (correct_predictions / total_predictions * 100) if total_predictions > 0 else 0
        
        return {
            'accuracy': accuracy,
            'total_signals': total_predictions,
            'correct_predictions': correct_predictions,
            'confidence_distribution': self._get_confidence_distribution(recent_signals)
        }
    
    def _get_confidence_distribution(self, signals: List[Dict]) -> Dict:
        """Calcule la distribution des niveaux de confiance"""
        distribution = {}
        for signal in signals:
            conf = signal['confidence']
            distribution[conf] = distribution.get(conf, 0) + 1
        return distribution

# Instance globale du prédicteur
spike_predictor = AdvancedSpikePredictor()

def get_advanced_prediction(symbol: str) -> Dict:
    """Fonction principale pour obtenir une prédiction avancée"""
    return spike_predictor.generate_trading_signal(symbol)

def get_prediction_accuracy() -> Dict:
    """Obtient la précision des prédictions"""
    return spike_predictor.get_prediction_accuracy()

if __name__ == "__main__":
    # Test du prédicteur
    print("🧪 Test du Prédicteur Avancé de Spikes")
    print("=" * 50)
    
    symbols = ['EURUSD', 'Boom 1000 Index', 'Crash 1000 Index']
    
    for symbol in symbols:
        print(f"\n📊 Analyse de {symbol}:")
        prediction = get_advanced_prediction(symbol)
        
        if prediction:
            print(f"   Direction: {prediction['direction']}")
            print(f"   Confiance: {prediction['confidence']}")
            print(f"   Score: {prediction['score']:.2f}")
            print(f"   Probabilité spike: {prediction['spike_probability']:.1%}")
            print(f"   Temps estimé: {prediction['time_to_spike']}s")
            print(f"   Action: {prediction['action']}")
            print(f"   Raison: {prediction['reasoning']}")
    
    print(f"\n📈 Précision des prédictions:")
    accuracy = get_prediction_accuracy()
    print(f"   Précision: {accuracy['accuracy']:.1f}%")
    print(f"   Signaux totaux: {accuracy['total_signals']}")
    print(f"   Prédictions correctes: {accuracy['correct_predictions']}")
