"""
Moteur de stratégies pour l'application de trading
"""
from abc import ABC, abstractmethod
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional
import logging
from dataclasses import dataclass
from enum import Enum, auto

# Configuration du logger
logger = logging.getLogger(__name__)

class SignalType(Enum):
    """Types de signaux de trading"""
    BUY = auto()
    SELL = auto()
    CLOSE = auto()
    HOLD = auto()

@dataclass
class TradeSignal:
    """Représente un signal de trading"""
    signal_type: SignalType
    symbol: str
    price: float
    stop_loss: float
    take_profit: float
    confidence: float = 0.0
    timestamp: pd.Timestamp = None
    strategy: str = None
    metadata: dict = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = pd.Timestamp.now()
        if self.metadata is None:
            self.metadata = {}

class BaseStrategy(ABC):
    """Classe de base pour toutes les stratégies de trading"""
    
    def __init__(self, name: str, params: dict = None):
        """
        Initialise la stratégie
        
        Args:
            name: Nom de la stratégie
            params: Paramètres de la stratégie
        """
        self.name = name
        self.params = params or {}
        self.indicators = []
        self.initialized = False
    
    def initialize(self):
        """Initialise la stratégie"""
        self.initialized = True
        logger.info(f"Stratégie initialisée: {self.name}")
    
    @abstractmethod
    def generate_signals(self, data: pd.DataFrame) -> List[TradeSignal]:
        """
        Génère des signaux de trading à partir des données
        
        Args:
            data: DataFrame contenant les données de marché
            
        Returns:
            Liste de signaux de trading
        """
        pass
    
    def calculate_indicators(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Calcule les indicateurs techniques nécessaires à la stratégie
        
        Args:
            data: DataFrame contenant les données de marché
            
        Returns:
            DataFrame avec les indicateurs ajoutés
        """
        return data

class TrendFollowingStrategy(BaseStrategy):
    """Stratégie de suivi de tendance"""
    
    def __init__(self, params: dict = None):
        """
        Initialise la stratégie de suivi de tendance
        
        Args:
            params: Paramètres de la stratégie
        """
        default_params = {
            'ma_fast': 20,
            'ma_slow': 50,
            'rsi_period': 14,
            'rsi_overbought': 70,
            'rsi_oversold': 30,
            'atr_period': 14,
            'atr_multiplier': 2.0,
            'min_trend_strength': 0.5
        }
        
        # Fusion des paramètres par défaut avec ceux fournis
        params = {**default_params, **(params or {})}
        
        super().__init__("Trend Following", params)
        self.initialize()
    
    def calculate_indicators(self, data: pd.DataFrame) -> pd.DataFrame:
        """Calcule les indicateurs techniques pour la stratégie de tendance"""
        try:
            # Moyennes mobiles
            data['ma_fast'] = data['close'].rolling(window=self.params['ma_fast']).mean()
            data['ma_slow'] = data['close'].rolling(window=self.params['ma_slow']).mean()
            
            # RSI
            delta = data['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=self.params['rsi_period']).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=self.params['rsi_period']).mean()
            rs = gain / loss
            data['rsi'] = 100 - (100 / (1 + rs))
            
            # ATR pour le calcul du stop loss et take profit
            high_low = data['high'] - data['low']
            high_close = (data['high'] - data['close'].shift()).abs()
            low_close = (data['low'] - data['close'].shift()).abs()
            ranges = pd.concat([high_low, high_close, low_close], axis=1)
            true_range = ranges.max(axis=1)
            data['atr'] = true_range.rolling(window=self.params['atr_period']).mean()
            
            # Force de la tendance (0-1)
            data['trend_strength'] = self._calculate_trend_strength(data)
            
            return data
            
        except Exception as e:
            logger.error(f"Erreur lors du calcul des indicateurs: {e}")
            return data
    
    def _calculate_trend_strength(self, data: pd.DataFrame) -> pd.Series:
        """Calcule la force de la tendance"""
        # Différence entre les moyennes mobiles normalisées
        ma_diff = (data['ma_fast'] - data['ma_slow']) / data['close']
        
        # Force du RSI (0-1)
        rsi_strength = (data['rsi'] - 50).abs() / 50
        
        # Force de la tendance combinée (0-1)
        trend_strength = (ma_diff.rolling(5).mean() * 0.6) + (rsi_strength * 0.4)
        
        return trend_strength.clip(0, 1)
    
    def generate_signals(self, data: pd.DataFrame) -> List[TradeSignal]:
        """Génère des signaux de trading basés sur la tendance"""
        signals = []
        
        if len(data) < max(self.params['ma_slow'], self.params['rsi_period']):
            return signals
        
        try:
            # Calcul des indicateurs
            data = self.calculate_indicators(data)
            
            # Dernière bougie
            current = data.iloc[-1]
            prev = data.iloc[-2] if len(data) > 1 else current
            
            # Vérification des conditions pour un signal d'achat
            buy_conditions = [
                current['ma_fast'] > current['ma_slow'],
                current['close'] > current['ma_slow'],
                current['rsi'] > 50,
                current['trend_strength'] > self.params['min_trend_strength'],
                # Vérification de la confirmation de tendance sur les 5 dernières bougies
                all(data['ma_fast'].iloc[-5:] > data['ma_slow'].iloc[-5:]),
                all(data['close'].iloc[-5:] > data['open'].iloc[-5:]),  # 5 bougies vertes consécutives
                current['volume'] > data['volume'].rolling(20).mean().iloc[-1]  # Volume supérieur à la moyenne
            ]
            
            if all(buy_conditions):
                # Calcul des niveaux de sortie
                entry_price = current['close']
                atr = current.get('atr', entry_price * 0.01)  # 1% par défaut si ATR non disponible
                
                signal = TradeSignal(
                    signal_type=SignalType.BUY,
                    symbol='',  # À définir par l'appelant
                    price=entry_price,
                    stop_loss=entry_price - (atr * self.params['atr_multiplier']),
                    take_profit=entry_price + (atr * self.params['atr_multiplier'] * 2),  # Ratio risque/rendement 1:2
                    confidence=min(current['trend_strength'], 0.95),  # Confiance maximale de 95%
                    strategy=self.name,
                    metadata={
                        'ma_fast': current['ma_fast'],
                        'ma_slow': current['ma_slow'],
                        'rsi': current['rsi'],
                        'trend_strength': current['trend_strength']
                    }
                )
                signals.append(signal)
            
            return signals
            
        except Exception as e:
            logger.error(f"Erreur lors de la génération des signaux: {e}")
            return []

class StrategyEngine:
    """Moteur d'exécution des stratégies de trading"""
    
    def __init__(self):
        """Initialise le moteur de stratégies"""
        self.strategies = {}
        self.active_strategies = {}
        self.initialize_strategies()
    
    def initialize_strategies(self):
        """Initialise les stratégies disponibles"""
        # Enregistrement des stratégies disponibles
        self.strategies = {
            'trend_following': TrendFollowingStrategy,
            # Ajouter d'autres stratégies ici
        }
        logger.info(f"Stratégies initialisées: {list(self.strategies.keys())}")
    
    def add_strategy(self, strategy_id: str, strategy_class, params: dict = None):
        """
        Ajoute une stratégie personnalisée
        
        Args:
            strategy_id: Identifiant unique de la stratégie
            strategy_class: Classe de la stratégie
            params: Paramètres de la stratégie
        """
        self.strategies[strategy_id] = strategy_class(params or {})
        logger.info(f"Stratégie ajoutée: {strategy_id}")
    
    def activate_strategy(self, strategy_id: str, symbol: str, timeframe: str, params: dict = None):
        """
        Active une stratégie pour un symbole et un timeframe donnés
        
        Args:
            strategy_id: Identifiant de la stratégie
            symbol: Symbole (ex: 'EURUSD')
            timeframe: Période (ex: 'M5', 'H1')
            params: Paramètres de la stratégie
        """
        if strategy_id not in self.strategies:
            logger.error(f"Stratégie non trouvée: {strategy_id}")
            return False
        
        strategy_key = f"{strategy_id}_{symbol}_{timeframe}"
        
        if strategy_key in self.active_strategies:
            logger.warning(f"La stratégie est déjà active: {strategy_key}")
            return True
        
        try:
            strategy = self.strategies[strategy_id](params or {})
            strategy.initialize()
            self.active_strategies[strategy_key] = {
                'strategy': strategy,
                'symbol': symbol,
                'timeframe': timeframe,
                'params': params or {}
            }
            logger.info(f"Stratégie activée: {strategy_key}")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de l'activation de la stratégie {strategy_id}: {e}")
            return False
    
    def deactivate_strategy(self, strategy_key: str):
        """
        Désactive une stratégie
        
        Args:
            strategy_key: Clé de la stratégie à désactiver
        """
        if strategy_key in self.active_strategies:
            del self.active_strategies[strategy_key]
            logger.info(f"Stratégie désactivée: {strategy_key}")
            return True
        return False
    
    def process_data(self, symbol: str, timeframe: str, data: pd.DataFrame) -> List[TradeSignal]:
        """
        Traite les données avec les stratégies actives pour le symbole et le timeframe donnés
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            timeframe: Période (ex: 'M5', 'H1')
            data: Données de marché
            
        Returns:
            Liste des signaux générés
        """
        signals = []
        
        if data.empty:
            logger.warning("Aucune donnée à traiter")
            return signals
        
        # Filtrer les stratégies actives pour ce symbole et ce timeframe
        active_strategies = [
            s for k, s in self.active_strategies.items() 
            if s['symbol'] == symbol and s['timeframe'] == timeframe
        ]
        
        if not active_strategies:
            logger.debug(f"Aucune stratégie active pour {symbol} {timeframe}")
            return signals
        
        # Traiter les données avec chaque stratégie
        for strategy_info in active_strategies:
            try:
                strategy = strategy_info['strategy']
                strategy_signals = strategy.generate_signals(data)
                
                # Ajouter les métadonnées manquantes aux signaux
                for signal in strategy_signals:
                    if not signal.symbol:
                        signal.symbol = symbol
                    if not signal.strategy:
                        signal.strategy = strategy.name
                
                signals.extend(strategy_signals)
                
            except Exception as e:
                logger.error(f"Erreur lors du traitement avec la stratégie {strategy_info['strategy'].name}: {e}")
        
        return signals
    
    def get_active_strategies(self) -> List[dict]:
        """
        Retourne la liste des stratégies actives
        
        Returns:
            Liste des stratégies actives avec leurs paramètres
        """
        return [
            {
                'key': key,
                'name': info['strategy'].name,
                'symbol': info['symbol'],
                'timeframe': info['timeframe'],
                'params': info['params']
            }
            for key, info in self.active_strategies.items()
        ]
