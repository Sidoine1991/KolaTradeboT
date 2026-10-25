"""
Configuration pour le pipeline ML automatisé.
Paramètres d'entraînement, features et modèles.
"""

# Configuration des modèles
MODELS_CONFIG = {
    'random_forest': {
        'name': 'Random Forest',
        'description': 'Ensemble d\'arbres de décision avec bagging',
        'params_grid': {
            'n_estimators': [100, 200, 300, 500],
            'max_depth': [10, 20, 30, None],
            'min_samples_split': [2, 5, 10],
            'min_samples_leaf': [1, 2, 4],
            'max_features': ['sqrt', 'log2', None]
        },
        'default_params': {
            'n_estimators': 200,
            'max_depth': 20,
            'min_samples_split': 5,
            'min_samples_leaf': 2,
            'max_features': 'sqrt',
            'random_state': 42
        }
    },
    
    'gradient_boosting': {
        'name': 'Gradient Boosting',
        'description': 'Boosting séquentiel avec descente de gradient',
        'params_grid': {
            'n_estimators': [100, 200, 300],
            'learning_rate': [0.01, 0.05, 0.1, 0.2],
            'max_depth': [3, 5, 7, 9],
            'subsample': [0.8, 0.9, 1.0],
            'min_samples_split': [2, 5, 10]
        },
        'default_params': {
            'n_estimators': 200,
            'learning_rate': 0.1,
            'max_depth': 5,
            'subsample': 0.9,
            'min_samples_split': 5,
            'random_state': 42
        }
    },
    
    'xgboost': {
        'name': 'XGBoost',
        'description': 'Gradient boosting optimisé avec régularisation',
        'params_grid': {
            'n_estimators': [100, 200, 300],
            'max_depth': [3, 5, 7, 9],
            'learning_rate': [0.01, 0.05, 0.1, 0.2],
            'subsample': [0.8, 0.9, 1.0],
            'colsample_bytree': [0.8, 0.9, 1.0],
            'reg_alpha': [0, 0.1, 1.0],
            'reg_lambda': [0, 0.1, 1.0]
        },
        'default_params': {
            'n_estimators': 200,
            'max_depth': 6,
            'learning_rate': 0.1,
            'subsample': 0.9,
            'colsample_bytree': 0.9,
            'reg_alpha': 0.1,
            'reg_lambda': 1.0,
            'random_state': 42
        }
    },
    
    'logistic_regression': {
        'name': 'Logistic Regression',
        'description': 'Régression logistique avec régularisation',
        'params_grid': {
            'C': [0.001, 0.01, 0.1, 1, 10, 100],
            'penalty': ['l1', 'l2', 'elasticnet'],
            'solver': ['liblinear', 'saga'],
            'max_iter': [1000, 2000]
        },
        'default_params': {
            'C': 1.0,
            'penalty': 'l2',
            'solver': 'liblinear',
            'max_iter': 1000,
            'random_state': 42
        }
    },
    
    'svm': {
        'name': 'Support Vector Machine',
        'description': 'Machine à vecteurs de support avec noyau RBF',
        'params_grid': {
            'C': [0.1, 1, 10, 100],
            'gamma': ['scale', 'auto', 0.001, 0.01, 0.1],
            'kernel': ['rbf', 'poly', 'linear']
        },
        'default_params': {
            'C': 1.0,
            'gamma': 'scale',
            'kernel': 'rbf',
            'random_state': 42
        }
    }
}

# Configuration des features techniques
TECHNICAL_FEATURES_CONFIG = {
    'trend_indicators': {
        'sma': [5, 10, 20, 50, 100, 200],
        'ema': [5, 10, 12, 20, 26, 50],
        'macd': {
            'fast': 12,
            'slow': 26,
            'signal': 9
        }
    },
    
    'momentum_indicators': {
        'rsi': [7, 14, 21],
        'stochastic': {
            'k_period': 14,
            'd_period': 3
        },
        'williams_r': 14,
        'cci': 20
    },
    
    'volatility_indicators': {
        'bollinger_bands': {
            'period': 20,
            'std_dev': 2
        },
        'atr': [7, 14, 21],
        'keltner_channels': {
            'period': 20,
            'multiplier': 2
        }
    },
    
    'volume_indicators': {
        'volume_sma': [10, 20, 50],
        'vwap': 20,
        'obv': True,
        'money_flow_index': 14
    }
}

# Configuration des features de prix
PRICE_FEATURES_CONFIG = {
    'returns': [1, 2, 3, 5, 10, 20],
    'price_ratios': {
        'high_low': True,
        'open_close': True,
        'body_size': True,
        'upper_lower_shadow': True
    },
    'price_vs_ma': [20, 50, 100, 200],
    'price_vs_vwap': True
}

# Configuration des features de volatilité
VOLATILITY_FEATURES_CONFIG = {
    'rolling_volatility': [5, 10, 20, 50],
    'true_range': True,
    'atr_ratio': True,
    'volatility_ratio': True
}

# Configuration des features de momentum
MOMENTUM_FEATURES_CONFIG = {
    'momentum': [5, 10, 20, 50],
    'roc': [5, 10, 20, 50],
    'momentum_ratio': True,
    'acceleration': True
}

# Configuration de la target
TARGET_CONFIG = {
    'classification': {
        'strong_buy': {
            'short_term_threshold': 0.02,  # 2% sur 5 périodes
            'long_term_threshold': 0.05,   # 5% sur 20 périodes
            'short_term_periods': 5,
            'long_term_periods': 20
        },
        'strong_sell': {
            'short_term_threshold': -0.02,  # -2% sur 5 périodes
            'long_term_threshold': -0.05,   # -5% sur 20 périodes
            'short_term_periods': 5,
            'long_term_periods': 20
        },
        'neutral': {
            'threshold': 0.01,  # 1% pour neutral
            'periods': 10
        }
    },
    
    'regression': {
        'target_column': 'future_returns_20',
        'periods': 20
    }
}

# Configuration de l'entraînement
TRAINING_CONFIG = {
    'data_split': {
        'test_size': 0.2,
        'validation_size': 0.1,
        'random_state': 42,
        'stratify': True
    },
    
    'cross_validation': {
        'cv_folds': 5,
        'scoring': ['accuracy', 'precision', 'recall', 'f1'],
        'n_jobs': -1
    },
    
    'hyperparameter_tuning': {
        'method': 'grid_search',  # 'grid_search', 'random_search', 'bayesian'
        'n_iter': 100,  # Pour random_search et bayesian
        'cv_folds': 3,
        'scoring': 'accuracy'
    },
    
    'feature_selection': {
        'method': 'mutual_info',  # 'mutual_info', 'chi2', 'f_classif', 'recursive'
        'k_best': 50,
        'threshold': 0.01
    }
}

# Configuration des paramètres de trading
TRADING_PARAMS_CONFIG = {
    'default_parameters': {
        'Strong Buy': {
            'stop_loss_pct': -2.0,
            'take_profit_pct': 5.0,
            'signal_duration_hours': 24,
            'confidence_threshold': 0.7,
            'position_size_pct': 5.0
        },
        'Strong Sell': {
            'stop_loss_pct': 2.0,
            'take_profit_pct': -5.0,
            'signal_duration_hours': 24,
            'confidence_threshold': 0.7,
            'position_size_pct': 5.0
        },
        'Neutral': {
            'stop_loss_pct': 1.5,
            'take_profit_pct': 3.0,
            'signal_duration_hours': 12,
            'confidence_threshold': 0.6,
            'position_size_pct': 2.0
        }
    },
    
    'dynamic_adjustment': {
        'enabled': True,
        'factors': {
            'model_accuracy': 0.3,
            'market_volatility': 0.2,
            'trend_strength': 0.2,
            'volume_confirmation': 0.1,
            'time_of_day': 0.1,
            'day_of_week': 0.1
        }
    },
    
    'risk_management': {
        'max_position_size_pct': 10.0,
        'max_daily_loss_pct': 5.0,
        'max_open_positions': 5,
        'correlation_threshold': 0.7
    }
}

# Configuration de l'EDA
EDA_CONFIG = {
    'missing_values': {
        'threshold_warning': 0.05,  # 5%
        'threshold_critical': 0.20,  # 20%
        'imputation_method': 'forward_backward'  # 'forward_backward', 'interpolate', 'mean'
    },
    
    'outliers': {
        'detection_method': 'iqr',  # 'iqr', 'zscore', 'isolation_forest'
        'iqr_multiplier': 1.5,
        'zscore_threshold': 3.0,
        'treatment': 'cap'  # 'cap', 'remove', 'transform'
    },
    
    'correlations': {
        'high_correlation_threshold': 0.8,
        'critical_correlation_threshold': 0.95,
        'correlation_method': 'pearson'  # 'pearson', 'spearman', 'kendall'
    },
    
    'distributions': {
        'normality_test': 'shapiro',  # 'shapiro', 'anderson', 'ks'
        'skewness_threshold': 2.0,
        'kurtosis_threshold': 7.0
    }
}

# Configuration du pipeline
PIPELINE_CONFIG = {
    'data_processing': {
        'min_data_points': 1000,
        'max_data_points': 10000,
        'timeframe': '1h',
        'clean_data': True,
        'remove_duplicates': True
    },
    
    'feature_engineering': {
        'create_lags': True,
        'max_lags': 10,
        'create_rolling_features': True,
        'rolling_windows': [5, 10, 20, 50],
        'create_interaction_features': True,
        'polynomial_features': False,
        'degree': 2
    },
    
    'model_evaluation': {
        'metrics': ['accuracy', 'precision', 'recall', 'f1', 'auc'],
        'confusion_matrix': True,
        'classification_report': True,
        'feature_importance': True,
        'roc_curve': True,
        'precision_recall_curve': True
    },
    
    'persistence': {
        'save_models': True,
        'save_transformations': True,
        'save_predictions': True,
        'save_eda_results': True,
        'compression': 'gzip'
    }
}

# Configuration des logs
LOGGING_CONFIG = {
    'level': 'INFO',
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    'file': {
        'enabled': True,
        'path': 'logs/ml_pipeline.log',
        'max_size': '10MB',
        'backup_count': 5
    },
    'console': {
        'enabled': True,
        'level': 'INFO'
    }
}

# Configuration des notifications
NOTIFICATION_CONFIG = {
    'email': {
        'enabled': False,
        'smtp_server': 'smtp.gmail.com',
        'smtp_port': 587,
        'sender_email': '',
        'sender_password': '',
        'recipients': []
    },
    'telegram': {
        'enabled': False,
        'bot_token': '',
        'chat_id': ''
    },
    'whatsapp': {
        'enabled': True,
        'webhook_url': ''
    }
}

# Configuration des performances
PERFORMANCE_CONFIG = {
    'memory_optimization': {
        'enabled': True,
        'max_memory_usage': '2GB',
        'chunk_size': 1000
    },
    
    'parallel_processing': {
        'enabled': True,
        'n_jobs': -1,
        'backend': 'multiprocessing'
    },
    
    'caching': {
        'enabled': True,
        'cache_dir': 'cache',
        'max_cache_size': '1GB',
        'ttl_hours': 24
    }
}
