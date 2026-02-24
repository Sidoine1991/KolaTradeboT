"""
Module pour le suivi des performances des indicateurs techniques
et le calcul des poids dynamiques.
"""
import json
import os
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import numpy as np
from pydantic import BaseModel

# Configuration des chemins
PERFORMANCE_DIR = Path("performance_data")
PERFORMANCE_DIR.mkdir(exist_ok=True)

class IndicatorPerformance(BaseModel):
    """Modèle pour suivre les performances d'un indicateur."""
    indicator_name: str
    symbol: str
    timeframe: str
    total_signals: int = 0
    winning_signals: int = 0
    total_pnl: float = 0.0
    last_updated: datetime = datetime.utcnow()
    
    @property
    def win_rate(self) -> float:
        """Calcule le taux de réussite de l'indicateur."""
        if self.total_signals == 0:
            return 0.0
        return self.winning_signals / self.total_signals
    
    @property
    def avg_pnl(self) -> float:
        """Calcule le profit moyen par signal."""
        if self.total_signals == 0:
            return 0.0
        return self.total_pnl / self.total_signals
    
    def update(self, is_win: bool, pnl: float):
        """Met à jour les statistiques de performance."""
        self.total_signals += 1
        if is_win:
            self.winning_signals += 1
        self.total_pnl += pnl
        self.last_updated = datetime.utcnow()

class PerformanceTracker:
    """Classe pour gérer le suivi des performances des indicateurs."""
    
    def __init__(self, symbol: str, timeframe: str = "M1"):
        self.symbol = symbol
        self.timeframe = timeframe
        self.performance_data: Dict[str, IndicatorPerformance] = {}
        self.load_performance_data()
    
    def get_performance_file(self) -> Path:
        """Retourne le chemin du fichier de performance pour le symbole et le timeframe."""
        safe_symbol = "".join(c if c.isalnum() else "_" for c in self.symbol)
        return PERFORMANCE_DIR / f"{safe_symbol}_{self.timeframe}.json"
    
    def load_performance_data(self):
        """Charge les données de performance depuis le fichier."""
        perf_file = self.get_performance_file()
        if not perf_file.exists():
            return
            
        try:
            with open(perf_file, 'r') as f:
                data = json.load(f)
                
            for indicator_name, perf_data in data.items():
                # Convertir la chaîne de date en objet datetime
                if 'last_updated' in perf_data and isinstance(perf_data['last_updated'], str):
                    perf_data['last_updated'] = datetime.fromisoformat(perf_data['last_updated'])
                self.performance_data[indicator_name] = IndicatorPerformance(
                    indicator_name=indicator_name,
                    symbol=self.symbol,
                    timeframe=self.timeframe,
                    **perf_data
                )
        except Exception as e:
            print(f"Erreur lors du chargement des performances: {e}")
    
    def save_performance_data(self):
        """Sauvegarde les données de performance dans le fichier."""
        perf_file = self.get_performance_file()
        data = {
            name: perf.dict() for name, perf in self.performance_data.items()
        }
        
        try:
            with open(perf_file, 'w') as f:
                json.dump(data, f, default=str, indent=2)
        except Exception as e:
            print(f"Erreur lors de la sauvegarde des performances: {e}")
    
    def update_indicator_performance(self, indicator_name: str, is_win: bool, pnl: float):
        """Met à jour les performances d'un indicateur."""
        if indicator_name not in self.performance_data:
            self.performance_data[indicator_name] = IndicatorPerformance(
                indicator_name=indicator_name,
                symbol=self.symbol,
                timeframe=self.timeframe
            )
        
        self.performance_data[indicator_name].update(is_win, pnl)
        self.save_performance_data()
    
    def get_indicator_weight(self, indicator_name: str, default_weight: float = 0.5) -> float:
        """
        Calcule le poids dynamique d'un indicateur basé sur ses performances.
        
        Args:
            indicator_name: Nom de l'indicateur
            default_weight: Poids par défaut si l'indicateur n'a pas assez d'historique
            
        Returns:
            float: Poids entre 0 et 1
        """
        if indicator_name not in self.performance_data:
            return default_weight
            
        perf = self.performance_data[indicator_name]
        
        # Si pas assez de données, retourner le poids par défaut
        if perf.total_signals < 10:
            return default_weight
            
        # Calculer un score basé sur le win rate et le PnL moyen
        win_rate = perf.win_rate
        avg_pnl = perf.avg_pnl
        
        # Normaliser le PnL (supposant que le PnL est en pourcentage)
        norm_pnl = max(0, min(1, (avg_pnl + 0.1) / 0.2))  # -10% à +10% → 0-1
        
        # Combiner win rate et PnL avec pondération
        score = (win_rate * 0.7) + (norm_pnl * 0.3)
        
        # S'assurer que le score est dans une plage raisonnable
        return max(0.1, min(1.0, score))
    
    def get_all_weights(self) -> Dict[str, float]:
        """Retourne les poids de tous les indicateurs suivis."""
        return {
            name: self.get_indicator_weight(name)
            for name in self.performance_data
        }

def detect_market_uncertainty(
    symbol: str,
    indicators: Dict[str, float],
    timeframe: str = "M1"
) -> float:
    """
    Détecte le niveau d'incertitude du marché basé sur les indicateurs.
    
    Args:
        symbol: Symbole du marché
        indicators: Dictionnaire des valeurs d'indicateurs
        timeframe: Période de temps
        
    Returns:
        float: Score d'incertitude entre 0 (certain) et 1 (très incertain)
    """
    uncertainty_score = 0.0
    
    # 1. Vérifier la volatilité (ATR ou écart-type des prix récents)
    if 'atr' in indicators:
        atr = indicators['atr']
        # Normaliser l'ATR (à ajuster selon l'échelle des prix)
        atr_ratio = min(1.0, atr / 0.01)  # Exemple: 1% = incertitude maximale
        uncertainty_score += 0.4 * atr_ratio
    
    # 2. Vérifier la divergence des indicateurs
    if 'rsi' in indicators and 'macd' in indicators and 'stoch' in indicators:
        rsi = indicators['rsi']
        macd = indicators['macd']
        stoch = indicators['stoch']
        
        # Compter les signaux contradictoires
        conflicting_signals = 0
        
        # RSI > 70 (surachat) mais MACD haussier
        if rsi > 70 and macd > 0:
            conflicting_signals += 1
        # RSI < 30 (sous-vente) mais MACD baissier
        elif rsi < 30 and macd < 0:
            conflicting_signals += 1
            
        # Stochastique en désaccord avec RSI
        if (rsi > 70 and stoch < 20) or (rsi < 30 and stoch > 80):
            conflicting_signals += 1
            
        uncertainty_score += 0.3 * (conflicting_signals / 2)  # Normaliser à 0-0.3
    
    # 3. Vérifier le volume (si disponible)
    if 'volume' in indicators and 'volume_ma' in indicators:
        volume_ratio = indicators['volume'] / indicators['volume_ma'] if indicators['volume_ma'] > 0 else 1.0
        # Faible volume = plus d'incertitude
        if volume_ratio < 0.5:
            uncertainty_score += 0.2 * (1 - volume_ratio)
    
    # 4. Vérifier la tendance (si disponible)
    if 'adx' in indicators:
        adx = indicators['adx']
        # ADX bas = tendance faible = plus d'incertitude
        if adx < 20:  # Seuil ADX pour tendance faible
            uncertainty_score += 0.2 * (1 - adx / 20)
    
    # S'assurer que le score est entre 0 et 1
    return max(0.0, min(1.0, uncertainty_score))
