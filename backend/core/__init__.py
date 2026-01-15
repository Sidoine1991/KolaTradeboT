"""
Package core - Contient les composants principaux de l'application de trading
"""

# Import des composants principaux
from .data_manager import DataManager
from .strategy_engine import StrategyEngine, BaseStrategy, TradeSignal, SignalType

# Version du package
__version__ = '0.1.0'
