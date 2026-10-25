"""
Configuration centralisée pour TradBOT
"""

# Configuration MT5
MT5_CONFIG = {
    'demo_account': True,
    'timeout': 30000,
    'max_retries': 3
}

# Configuration des indicateurs techniques
TECHNICAL_INDICATORS = {
    'sma_periods': [5, 15, 29, 50, 75, 80, 95, 90],
    'ema_periods': [5, 15, 29, 50, 75, 80, 95, 90],
    'rsi_period': 14,
    'rsi_oversold': 30,  # Niveau de survente
    'rsi_overbought': 70,  # Niveau de surachat
    'macd_fast': 12,
    'macd_slow': 26,
    'macd_signal': 9,
    'bb_period': 20,
    'bb_std': 2,
    'atr_period': 14,
    'adx_period': 14
}

# Configuration de détection de spikes
SPIKE_CONFIG = {
    'default_threshold': 1.0,
    'min_spike_duration': 1,
    'max_spike_duration': 10,
    'volume_threshold': 1.5
}

# Configuration de l'agent de trading
TRADING_CONFIG = {
    'max_position_size': 0.02,  # 2% du capital
    'max_daily_loss': 0.05,     # 5% de perte maximale
    'stop_loss_pct': 0.02,      # 2% de stop loss
    'take_profit_pct': 0.04,    # 4% de take profit
    'max_positions': 5,         # Maximum 5 positions
    'min_confidence': 0.6,      # Confiance minimale pour exécuter
    'risk_per_trade': 0.01      # 1% de risque par trade
}

# Configuration du cache
CACHE_CONFIG = {
    'mt5_data_ttl': 300,        # 5 minutes
    'indicators_ttl': 60,       # 1 minute
    'analysis_ttl': 120,        # 2 minutes
    'signals_ttl': 30           # 30 secondes
}

# Configuration des alertes
ALERT_CONFIG = {
    'max_alerts': 100,
    'spike_threshold': 1.0,
    'price_alert_tolerance': 0.01  # 1% de tolérance
}

# Configuration de l'analyse avancée
ADVANCED_ANALYSIS_CONFIG = {
    'fibonacci_levels': [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0],
    'swing_window': 5,
    'trendline_tolerance': 0.02,  # 2% de tolérance
    'liquidity_volume_threshold': 0.8  # 80e percentile
}

# Configuration de l'interface
UI_CONFIG = {
    'default_timeframe': 'M5',
    'default_candle_count': 200,
    'chart_height': 800,
    'max_symbols_display': 50
}

# Configuration des timeframes disponibles
TIMEFRAMES = {
    'M1': '1 minute',
    'M5': '5 minutes',
    'M15': '15 minutes',
    'M30': '30 minutes',
    'H1': '1 heure',
    'H4': '4 heures',
    'D1': '1 jour'
}

# Configuration des catégories d'instruments
INSTRUMENT_CATEGORIES = {
    'Synthetic Indices': ['BOOM', 'CRASH', 'SYNTH'],
    'Forex': ['EUR', 'USD', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD'],
    'Commodities': ['GOLD', 'SILVER', 'OIL', 'COPPER'],
    'Indices': ['US30', 'US500', 'NAS100', 'GER30', 'UK100'],
    'Crypto': ['BTC', 'ETH', 'LTC', 'XRP']
} 