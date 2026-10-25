"""
Système automatisé complet pour l'analyse exploratoire des données (EDA),
construction de pipeline et entraînement de modèles pour chaque devise.
Objectif : Prédire Strong Buy/Sell avec paramètres SL/TP optimaux.
"""

import os
import sys
import json
import logging
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

# ML imports
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.pipeline import Pipeline
import joblib

# Technical analysis
import ta
from ta.trend import SMAIndicator, EMAIndicator, MACD
from ta.momentum import RSIIndicator, StochasticOscillator
from ta.volatility import BollingerBands, AverageTrueRange
from ta.volume import VolumeWeightedAveragePrice

# Custom imports
from backend.mt5_connector import get_ohlc, get_all_symbols
from backend.technical_analysis import calculate_technical_indicators

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AutomatedMLPipeline:
    """
    Pipeline automatisé pour l'analyse ML de chaque devise.
    """
    
    def __init__(self, data_dir: str = "D:/Dev/TradBOT/data"):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(exist_ok=True)
        self.symbols = get_all_symbols()
        
        # Configuration des modèles
        self.models_config = {
            'random_forest': {
                'model': RandomForestClassifier(random_state=42),
                'params': {
                    'n_estimators': [100, 200, 300],
                    'max_depth': [10, 20, None],
                    'min_samples_split': [2, 5, 10]
                }
            },
            'gradient_boosting': {
                'model': GradientBoostingClassifier(random_state=42),
                'params': {
                    'n_estimators': [100, 200],
                    'learning_rate': [0.01, 0.1, 0.2],
                    'max_depth': [3, 5, 7]
                }
            },
            'logistic_regression': {
                'model': LogisticRegression(random_state=42, max_iter=1000),
                'params': {
                    'C': [0.1, 1, 10],
                    'penalty': ['l1', 'l2']
                }
            }
        }
        
        # Métriques de performance
        self.performance_metrics = {}
