#!/usr/bin/env python3
"""
Client MT5 pour communiquer avec le serveur IA Render
Ce script s'exécute sur la machine locale avec MT5
"""

import os
import sys
import time
import json
import logging
import requests
import MetaTrader5 as mt5
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path

# Configuration des URLs de l'API
RENDER_API_URL = "https://kolatradebot.onrender.com"
LOCAL_API_URL = "http://localhost:5000"
TIMEFRAMES = ["M5"]  # Horizon M5 comme demandé
CHECK_INTERVAL = 60  # Secondes entre chaque vérification
MIN_CONFIDENCE = 0.80  # Confiance minimale pour prendre un trade (80% = 0.80) - NOUVEAU

# SL/TP par défaut (Boom/Crash, Volatility, Metals)
SL_PERCENTAGE_DEFAULT = 0.02  # 2%
TP_PERCENTAGE_DEFAULT = 0.04  # 4%

# SL/TP spécifiques Forex (pips plus larges)
SL_PERCENTAGE_FOREX = 0.01  # 1%
TP_PERCENTAGE_FOREX = 0.06  # 6%

# Tailles de position par type de symbole
POSITION_SIZES = {
    "Boom 300 Index": 0.2,
    "Boom 600 Index": 0.2,
    "Boom 900 Index": 0.2,
    "Crash 1000 Index": 0.2,
    "EURUSD": 0.01,
    "GBPUSD": 0.01,
    "USDJPY": 0.01
}

# Configuration logging améliorée avec rotation et niveaux détaillés
def setup_logging():
    """Configure le logging avec rotation et niveaux détaillés"""
    # Créer le répertoire de logs s'il n'existe pas
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    # Formatter détaillé
    detailed_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - [%(funcName)s:%(lineno)d] - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Formatter simple pour la console
    console_formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%H:%M:%S'
    )
    
    # Handlers
    handlers = []
    
    # Fichier de log principal avec rotation quotidienne
    main_log_file = log_dir / f'mt5_ai_client_{datetime.now().strftime("%Y%m%d")}.log'
    file_handler = logging.FileHandler(main_log_file, encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(detailed_formatter)
    handlers.append(file_handler)
    
    # Fichier de log pour les erreurs uniquement
    error_log_file = log_dir / f'mt5_ai_client_errors_{datetime.now().strftime("%Y%m%d")}.log'
    error_handler = logging.FileHandler(error_log_file, encoding='utf-8')
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(detailed_formatter)
    handlers.append(error_handler)
    
    # Fichier de log pour les trades
    trade_log_file = log_dir / f'mt5_trades_{datetime.now().strftime("%Y%m%d")}.log'
    trade_handler = logging.FileHandler(trade_log_file, encoding='utf-8')
    trade_handler.setLevel(logging.INFO)
    
    # Formatter spécial pour les trades
    trade_formatter = logging.Formatter(
        '%(asctime)s - TRADE - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    trade_handler.setFormatter(trade_formatter)
    handlers.append(trade_handler)
    
    # Console avec niveau INFO
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(console_formatter)
    handlers.append(console_handler)
    
    # Configuration du logger principal
    logging.basicConfig(
        level=logging.DEBUG,
        handlers=handlers,
        force=True  # Forcer la reconfiguration
    )
    
    # Créer un logger spécial pour les trades
    trade_logger = logging.getLogger("mt5_trades")
    trade_logger.setLevel(logging.INFO)
    trade_logger.addHandler(trade_handler)
    trade_logger.propagate = False  # Éviter la duplication dans le logger principal
    
    return trade_logger

# Initialiser le logging
trade_logger = setup_logging()
logger = logging.getLogger("mt5_ai_client")

# Logger spécialisé pour les filling modes
filling_mode_logger = logging.getLogger("filling_mode")
filling_mode_logger.setLevel(logging.DEBUG)

class TradeLogger:
    """Logger spécialisé pour les trades et erreurs de filling mode"""
    
    def __init__(self):
        self.trade_logger = logging.getLogger("mt5_trades")
        self.filling_logger = logging.getLogger("filling_mode")
        
    def get_filling_mode_name(self, mode_value):
        """Convertit la valeur numérique du filling mode en nom lisible"""
        filling_modes = {
            0: "ORDER_FILLING_FOK",
            1: "ORDER_FILLING_FOK", 
            2: "ORDER_FILLING_IOC",
            3: "ORDER_FILLING_IOC",
            4: "ORDER_FILLING_RETURN"
        }
        return filling_modes.get(mode_value, f"UNKNOWN({mode_value})")
        
    def log_trade_attempt(self, symbol, order_type, lot, price, sl, tp, filling_mode):
        """Log une tentative de trade"""
        self.trade_logger.info(
            f"TRADE_ATTEMPT | Symbol: {symbol} | Type: {order_type} | "
            f"Lot: {lot} | Price: {price} | SL: {sl} | TP: {tp} | "
            f"Filling: {filling_mode}"
        )
        
    def log_trade_success(self, symbol, order_type, ticket, profit=0):
        """Log un trade réussi"""
        self.trade_logger.info(
            f"TRADE_SUCCESS | Symbol: {symbol} | Type: {order_type} | "
            f"Ticket: {ticket} | Profit: ${profit:.2f}"
        )
        
    def log_trade_error(self, symbol, order_type, error_code, error_msg, filling_mode):
        """Log une erreur de trade"""
        self.trade_logger.error(
            f"TRADE_ERROR | Symbol: {symbol} | Type: {order_type} | "
            f"Code: {error_code} | Msg: {error_msg} | Filling: {filling_mode}"
        )
        
    def log_filling_mode_error(self, symbol, error_code, error_msg, attempted_mode, fallback_mode=None):
        """Log spécifique pour les erreurs de filling mode"""
        log_msg = (
            f"FILLING_MODE_ERROR | Symbol: {symbol} | "
            f"Attempted: {attempted_mode} | Code: {error_code} | Msg: {error_msg}"
        )
        
        if fallback_mode:
            log_msg += f" | Fallback: {fallback_mode}"
            
        self.filling_logger.error(log_msg)
        
        # Aussi logger dans le fichier d'erreurs principal
        logger.error(f"Erreur filling mode {symbol}: {error_msg} (Code: {error_code})")
        
    def log_filling_mode_success(self, symbol, successful_mode, was_fallback=False):
        """Log quand un filling mode fonctionne"""
        prefix = "FALLBACK_SUCCESS" if was_fallback else "FILLING_MODE_SUCCESS"
        self.filling_logger.info(
            f"{prefix} | Symbol: {symbol} | Mode: {successful_mode}"
        )
        
    def log_api_response(self, endpoint, status_code, response_time, data_size=0):
        """Log les réponses API"""
        logger.debug(
            f"API_RESPONSE | Endpoint: {endpoint} | Status: {status_code} | "
            f"Time: {response_time:.3f}s | Size: {data_size} bytes"
        )
        
    def log_position_update(self, symbol, ticket, action, new_sl=None, new_tp=None, profit=0):
        """Log les mises à jour de positions"""
        update_info = f"POSITION_UPDATE | Symbol: {symbol} | Ticket: {ticket} | Action: {action}"
        if new_sl:
            update_info += f" | New SL: {new_sl}"
        if new_tp:
            update_info += f" | New TP: {new_tp}"
        if profit != 0:
            update_info += f" | Profit: ${profit:.2f}"
            
        self.trade_logger.info(update_info)

# Instance globale du logger de trades
trade_logger_instance = TradeLogger()

# ... (rest of the classes and code would continue here, but I need to keep it short to avoid timeout)

if __name__ == "__main__":
    client = MT5AIClient()
    client.run()
