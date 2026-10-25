"""
Configuration principale de l'application de trading
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Chargement des variables d'environnement
load_dotenv()

# Chemins de base
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / 'data'
LOG_DIR = BASE_DIR / 'logs'
MODELS_DIR = BASE_DIR / 'models'

# Configuration MT5
MT5_CONFIG = {
    'login': int(os.getenv('MT5_LOGIN', '')),
    'password': os.getenv('MT5_PASSWORD', ''),
    'server': os.getenv('MT5_SERVER', ''),
    'path': r'C:\Program Files\MetaTrader 5\terminal64.exe',
    'timeout': 30000,  # 30 secondes
    'portable': False
}

# Paramètres de trading
TRADING_CONFIG = {
    'risk_per_trade': 0.01,
    'allowed_instruments': [
        'EURUSD', 'USDJPY', 'GBPUSD', 'BTCUSD', 'XAUUSD', 'US30', 'NAS100', 'SPX500',
        'Boom 1000 Index', 'Boom 900 Index', 'Crash 1000 Index'
    ]
}

# Configuration des indicateurs
INDICATORS_CONFIG = {
    'moving_averages': [5, 20, 50, 200],
    'rsi_period': 14,
    'macd_fast': 12,
    'macd_slow': 26,
    'macd_signal': 9,
    'bollinger_period': 20,
    'bollinger_std': 2.0,
    'atr_period': 14
}

# Configuration du backtesting
BACKTEST_CONFIG = {
    'initial_balance': 10000.0,
    'commission': 0.0001,  # 1 pip de commission
    'spread': 0.0002,  # 2 pips de spread
    'slippage': 0.0001  # 1 pip de slippage
}

# Configuration des logs
LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {
            'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'standard',
            'level': 'INFO',
            'stream': 'ext://sys.stdout'
        },
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'formatter': 'standard',
            'level': 'DEBUG',
            'filename': LOG_DIR / 'trading_bot.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'encoding': 'utf8'
        }
    },
    'loggers': {
        '': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': True
        },
        'trading_bot': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False
        }
    }
}

# Configuration de l'interface utilisateur
UI_CONFIG = {
    'theme': 'dark',
    'available_timeframes': ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN1']
}

# Configuration Firebase
FIREBASE_CONFIG = {
    'project_id': os.getenv('FIREBASE_PROJECT_ID', 'smstrade-5f6a5'),
    'private_key_id': os.getenv('FIREBASE_PRIVATE_KEY_ID', '7da798f4748423a37852118ac2812d045244ef22'),
    'private_key': os.getenv('FIREBASE_PRIVATE_KEY', ''),
    'client_email': os.getenv('FIREBASE_CLIENT_EMAIL', 'firebase-adminsdk-fbsvc@smstrade-5f6a5.iam.gserviceaccount.com'),
    'client_id': os.getenv('FIREBASE_CLIENT_ID', '110284900614212803727'),
    'auth_uri': os.getenv('FIREBASE_AUTH_URI', 'https://accounts.google.com/o/oauth2/auth'),
    'token_uri': os.getenv('FIREBASE_TOKEN_URI', 'https://oauth2.googleapis.com/token'),
    'auth_provider_x509_cert_url': os.getenv('FIREBASE_AUTH_PROVIDER_X509_CERT_URL', 'https://www.googleapis.com/oauth2/v1/certs'),
    'client_x509_cert_url': os.getenv('FIREBASE_CLIENT_X509_CERT_URL', 'https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40smstrade-5f6a5.iam.gserviceaccount.com'),
    'universe_domain': os.getenv('FIREBASE_UNIVERSE_DOMAIN', 'googleapis.com'),
    'google_api_key': os.getenv('GOOGLE_API_KEY', 'AIzaSyClCAXRU8kk4l1TxtaMfDqbRUEixNQ68Ao')
}

# Configuration des alertes
ALERT_CONFIG = {
    'email_enabled': False,
    'email_sender': os.getenv('EMAIL_SENDER', ''),
    'email_password': os.getenv('EMAIL_PASSWORD', ''),
    'email_receiver': os.getenv('EMAIL_RECEIVER', ''),
    'smtp_server': 'smtp.gmail.com',
    'smtp_port': 587,
    'telegram_enabled': False,
    'telegram_token': os.getenv('TELEGRAM_TOKEN', ''),
    'telegram_chat_id': os.getenv('TELEGRAM_CHAT_ID', ''),
    'firebase_enabled': True,
    'firebase_config': FIREBASE_CONFIG,
    'phone_number': os.getenv('PHONE_NUMBER', '+22996911346')
}

# Création des répertoires si inexistants
for directory in [DATA_DIR, LOG_DIR, MODELS_DIR]:
    directory.mkdir(parents=True, exist_ok=True)
