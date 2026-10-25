#!/usr/bin/env python3
"""
Configuration spécifique pour le Système Boom Rising Channel Predictor
"""

# Configuration du symbole Boom
BOOM_CONFIG = {
    'symbol': 'Boom 1000 Index',
    'timeframe': 'M1',
    'min_candles': 100,
    'max_candles': 500
}

# Configuration des EMAs pour Boom
BOOM_EMA_CONFIG = {
    'periods': [10, 30, 50],
    'proximity_threshold': 0.002,  # 0.2%
    'weights': {
        'EMA10': 0.9,   # Plus réactif
        'EMA30': 0.8,   # Moyen
        'EMA50': 0.7    # Plus stable
    }
}

# Configuration du canal haussier
RISING_CHANNEL_CONFIG = {
    'min_duration': 5,           # 5 minutes minimum
    'slope_threshold': 0.001,    # Pente minimale
    'strength_threshold': 0.7,   # Force minimale
    'max_channels': 5,           # Nombre max de canaux à garder
    'validation_points': 3       # Points minimum pour valider
}

# Configuration des prédictions
PREDICTION_CONFIG = {
    'spike_probability_threshold': 0.75,
    'confidence_threshold': 0.75,
    'max_time_to_spike': 300,    # 5 minutes max
    'prediction_cooldown': 30,   # 30 secondes entre prédictions
    'max_arrows_per_chart': 20
}

# Configuration du trading automatique
TRADING_CONFIG = {
    'enabled': True,
    'max_positions': 3,
    'position_size': 0.1,
    'stop_loss_pips': 20,
    'take_profit_pips': 50,
    'max_daily_loss': 100.0,     # USD
    'max_daily_trades': 20,
    'min_confidence': 0.75,
    'min_spike_probability': 0.8
}

# Configuration de sécurité
SAFETY_CONFIG = {
    'emergency_stop_enabled': True,
    'position_monitoring_interval': 5,  # secondes
    'daily_reset_time': '00:00',        # Heure de reset quotidien
    'max_consecutive_losses': 5,
    'risk_per_trade': 0.01              # 1% du capital
}

# Configuration de l'interface
UI_CONFIG = {
    'streamlit_port': 8501,
    'streamlit_host': 'localhost',
    'chart_height': 800,
    'max_display_candles': 200,
    'refresh_interval': 5,              # secondes
    'theme': 'light'
}

# Configuration des logs
LOGGING_CONFIG = {
    'level': 'INFO',
    'file': 'boom_trading.log',
    'max_size': 10485760,               # 10MB
    'backup_count': 5,
    'format': '%(asctime)s - %(levelname)s - %(message)s'
}

# Configuration des alertes
ALERT_CONFIG = {
    'enabled': True,
    'spike_threshold': 1.0,
    'price_alert_tolerance': 0.01,
    'notification_methods': ['console', 'file'],
    'alert_cooldown': 60               # secondes
}

# Configuration des tests
TEST_CONFIG = {
    'simulation_mode': True,
    'test_data_points': 100,
    'performance_threshold': 2.0,      # secondes
    'accuracy_threshold': 0.7
}

# Configuration des fichiers
FILE_CONFIG = {
    'trade_history': 'boom_trade_history.json',
    'chart_output': 'boom_chart.png',
    'config_backup': 'boom_config_backup.json',
    'performance_log': 'boom_performance.log'
}

# Configuration des timeframes
TIMEFRAME_CONFIG = {
    'primary': 'M1',
    'secondary': 'M5',
    'analysis': 'M15',
    'trend': 'H1'
}

# Configuration des niveaux de confiance
CONFIDENCE_LEVELS = {
    'ultra_high': 0.95,    # 95%+ - Trade immédiat
    'very_high': 0.90,    # 90%+ - Trade avec SL serré
    'high': 0.80,          # 80%+ - Trade normal
    'medium': 0.70,        # 70%+ - Trade avec confirmation
    'low': 0.60           # 60%+ - Surveillance uniquement
}

# Configuration des directions de spike
SPIKE_DIRECTIONS = {
    'BOOM': {
        'color': 'green',
        'marker': 'triangle-up',
        'probability_factor': 1.0
    },
    'CRASH': {
        'color': 'red',
        'marker': 'triangle-down',
        'probability_factor': 0.8
    },
    'NEUTRAL': {
        'color': 'gray',
        'marker': 'circle',
        'probability_factor': 0.5
    }
}

# Configuration des positions dans le canal
CHANNEL_POSITIONS = {
    'upper': {
        'breakout_probability': 0.9,
        'direction_bias': 'CRASH',
        'risk_level': 'HIGH'
    },
    'middle': {
        'breakout_probability': 0.6,
        'direction_bias': 'NEUTRAL',
        'risk_level': 'MEDIUM'
    },
    'lower': {
        'breakout_probability': 0.8,
        'direction_bias': 'BOOM',
        'risk_level': 'LOW'
    }
}

# Configuration des métriques de performance
PERFORMANCE_METRICS = {
    'win_rate_target': 0.7,
    'profit_factor_target': 1.5,
    'max_drawdown_limit': 0.1,
    'sharpe_ratio_target': 1.0,
    'calmar_ratio_target': 2.0
}

# Configuration des optimisations
OPTIMIZATION_CONFIG = {
    'enabled': True,
    'optimization_interval': 3600,     # 1 heure
    'parameter_ranges': {
        'ema_proximity_threshold': (0.001, 0.005),
        'spike_probability_threshold': (0.6, 0.9),
        'position_size': (0.05, 0.2)
    },
    'optimization_method': 'genetic_algorithm'
}

# Configuration des notifications
NOTIFICATION_CONFIG = {
    'enabled': True,
    'channels': {
        'console': True,
        'file': True,
        'email': False,
        'sms': False,
        'webhook': False
    },
    'events': {
        'new_prediction': True,
        'trade_executed': True,
        'position_closed': True,
        'daily_summary': True,
        'error_occurred': True
    }
}

# Configuration des sauvegardes
BACKUP_CONFIG = {
    'enabled': True,
    'interval': 3600,                  # 1 heure
    'retention_days': 30,
    'backup_files': [
        'boom_trade_history.json',
        'boom_trading.log',
        'boom_config_backup.json'
    ]
}

# Configuration des limites de ressources
RESOURCE_LIMITS = {
    'max_memory_usage': 512,           # MB
    'max_cpu_usage': 80,              # %
    'max_file_size': 104857600,       # 100MB
    'max_log_entries': 10000
}

# Configuration des tests de régression
REGRESSION_TEST_CONFIG = {
    'enabled': True,
    'test_interval': 86400,            # 24 heures
    'test_data_size': 1000,
    'accuracy_threshold': 0.65,
    'performance_threshold': 3.0
}

# Configuration des mises à jour
UPDATE_CONFIG = {
    'check_updates': True,
    'update_interval': 604800,         # 7 jours
    'auto_update': False,
    'backup_before_update': True
}

# Configuration des métriques en temps réel
REALTIME_METRICS_CONFIG = {
    'enabled': True,
    'update_interval': 1,              # seconde
    'metrics': [
        'current_price',
        'ema_values',
        'channel_strength',
        'prediction_confidence',
        'active_positions',
        'daily_pnl'
    ]
}

# Configuration des seuils d'alerte
ALERT_THRESHOLDS = {
    'high_loss': 50.0,                # USD
    'low_win_rate': 0.5,
    'high_drawdown': 0.05,
    'system_error': True,
    'connection_lost': True
}

# Configuration des paramètres de marché
MARKET_CONFIG = {
    'trading_hours': {
        'start': '00:00',
        'end': '23:59',
        'timezone': 'UTC'
    },
    'market_conditions': {
        'high_volatility_threshold': 0.02,
        'low_volatility_threshold': 0.005,
        'trend_strength_threshold': 0.7
    }
}

# Configuration des paramètres de backtest
BACKTEST_CONFIG = {
    'enabled': True,
    'start_date': '2024-01-01',
    'end_date': '2024-12-31',
    'initial_capital': 10000,
    'commission': 0.0001,
    'slippage': 0.0001
}

# Configuration des paramètres de machine learning
ML_CONFIG = {
    'enabled': False,
    'model_type': 'random_forest',
    'features': [
        'ema_proximity',
        'channel_position',
        'channel_strength',
        'volatility',
        'volume'
    ],
    'retrain_interval': 86400,         # 24 heures
    'prediction_horizon': 300          # 5 minutes
}

# Configuration des paramètres de réseau
NETWORK_CONFIG = {
    'timeout': 30,
    'retry_attempts': 3,
    'retry_delay': 5,
    'connection_pool_size': 10
}

# Configuration des paramètres de sécurité
SECURITY_CONFIG = {
    'encrypt_logs': False,
    'encrypt_trade_history': False,
    'require_authentication': False,
    'session_timeout': 3600            # 1 heure
}

# Configuration des paramètres de performance
PERFORMANCE_CONFIG = {
    'enable_profiling': False,
    'profile_interval': 300,           # 5 minutes
    'memory_profiling': False,
    'cpu_profiling': False
}

# Configuration des paramètres de développement
DEV_CONFIG = {
    'debug_mode': False,
    'verbose_logging': False,
    'simulation_mode': True,
    'test_data_enabled': True
}

# Configuration des paramètres de production
PRODUCTION_CONFIG = {
    'debug_mode': False,
    'verbose_logging': False,
    'simulation_mode': False,
    'test_data_enabled': False,
    'error_reporting': True,
    'performance_monitoring': True
}

# Configuration par défaut
DEFAULT_CONFIG = {
    'boom': BOOM_CONFIG,
    'ema': BOOM_EMA_CONFIG,
    'channel': RISING_CHANNEL_CONFIG,
    'prediction': PREDICTION_CONFIG,
    'trading': TRADING_CONFIG,
    'safety': SAFETY_CONFIG,
    'ui': UI_CONFIG,
    'logging': LOGGING_CONFIG,
    'alert': ALERT_CONFIG,
    'test': TEST_CONFIG,
    'file': FILE_CONFIG,
    'timeframe': TIMEFRAME_CONFIG,
    'confidence': CONFIDENCE_LEVELS,
    'spike_directions': SPIKE_DIRECTIONS,
    'channel_positions': CHANNEL_POSITIONS,
    'performance': PERFORMANCE_METRICS,
    'optimization': OPTIMIZATION_CONFIG,
    'notification': NOTIFICATION_CONFIG,
    'backup': BACKUP_CONFIG,
    'resource_limits': RESOURCE_LIMITS,
    'regression_test': REGRESSION_TEST_CONFIG,
    'update': UPDATE_CONFIG,
    'realtime_metrics': REALTIME_METRICS_CONFIG,
    'alert_thresholds': ALERT_THRESHOLDS,
    'market': MARKET_CONFIG,
    'backtest': BACKTEST_CONFIG,
    'ml': ML_CONFIG,
    'network': NETWORK_CONFIG,
    'security': SECURITY_CONFIG,
    'performance_monitoring': PERFORMANCE_CONFIG,
    'dev': DEV_CONFIG,
    'production': PRODUCTION_CONFIG
}

def get_config(section: str = None):
    """Récupère la configuration"""
    if section:
        return DEFAULT_CONFIG.get(section, {})
    return DEFAULT_CONFIG

def update_config(section: str, key: str, value):
    """Met à jour une valeur de configuration"""
    if section in DEFAULT_CONFIG and key in DEFAULT_CONFIG[section]:
        DEFAULT_CONFIG[section][key] = value
        return True
    return False

def save_config(filename: str = 'boom_config.json'):
    """Sauvegarde la configuration dans un fichier"""
    import json
    try:
        with open(filename, 'w') as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
        return True
    except Exception as e:
        print(f"Erreur lors de la sauvegarde: {e}")
        return False

def load_config(filename: str = 'boom_config.json'):
    """Charge la configuration depuis un fichier"""
    import json
    try:
        with open(filename, 'r') as f:
            loaded_config = json.load(f)
        DEFAULT_CONFIG.update(loaded_config)
        return True
    except FileNotFoundError:
        print(f"Fichier de configuration non trouvé: {filename}")
        return False
    except Exception as e:
        print(f"Erreur lors du chargement: {e}")
        return False

if __name__ == "__main__":
    # Test de la configuration
    print("🔧 Test de la Configuration Boom Rising Channel Predictor")
    print("=" * 60)
    
    # Afficher les sections disponibles
    print("📋 Sections disponibles:")
    for section in DEFAULT_CONFIG.keys():
        print(f"   - {section}")
    
    # Tester la récupération de configuration
    boom_config = get_config('boom')
    print(f"\n📊 Configuration Boom: {boom_config}")
    
    ema_config = get_config('ema')
    print(f"📈 Configuration EMA: {ema_config}")
    
    trading_config = get_config('trading')
    print(f"🤖 Configuration Trading: {trading_config}")
    
    # Tester la sauvegarde
    if save_config('test_boom_config.json'):
        print("\n✅ Configuration sauvegardée avec succès")
    
    # Tester le chargement
    if load_config('test_boom_config.json'):
        print("✅ Configuration chargée avec succès")
    
    print("\n🎉 Configuration testée avec succès!")
