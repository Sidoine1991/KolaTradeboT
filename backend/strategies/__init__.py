"""
Module de stratégies de trading pour TradBOT

Ce module contient les différentes stratégies de trading implémentées pour le bot.
"""

# Exporter les classes et fonctions principales pour un accès plus facile
from .ml_supertrend import MLSuperTrendStrategy, MLSuperTrendConfig

__all__ = [
    'MLSuperTrendStrategy',
    'MLSuperTrendConfig'
]
