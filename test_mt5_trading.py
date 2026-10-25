#!/usr/bin/env python3
"""
Script de test pour vérifier les ordres MT5 avec les bonnes configurations
"""

import sys
import time
import logging
import MetaTrader5 as mt5
from datetime import datetime

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_mt5")

# Configuration des tailles de position
POSITION_SIZES = {
    "Boom 300 Index": 1.0,
    "Boom 600 Index": 1.0,
    "Boom 900 Index": 1.0,
    "Crash 1000 Index": 1.0,
    "EURUSD": 0.01,
    "GBPUSD": 0.01,
    "USDJPY": 0.01
}

def test_connection():
    """Test la connexion à MT5"""
    try:
        if not mt5.initialize():
            logger.error("Echec initialisation MT5")
            return False
        
        account_info = mt5.account_info()
        if account_info:
            logger.info(f"MT5 connecté - Compte: {account_info.login}")
            return True
        else:
            logger.error("Impossible de récupérer les infos du compte")
            return False
            
    except Exception as e:
        logger.error(f"Erreur connexion MT5: {e}")
        return False

def test_symbol_info(symbol):
    """Test les informations d'un symbole"""
    try:
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            logger.error(f"Symbole {symbol} non disponible")
            return None
        
        tick = mt5.symbol_info_tick(symbol)
        if not tick:
            logger.error(f"Pas de tick pour {symbol}")
            return None
        
        info = {
            'symbol': symbol,
            'bid': tick.bid,
            'ask': tick.ask,
            'point': symbol_info.point,
            'volume_min': symbol_info.volume_min,
            'volume_max': symbol_info.volume_max,
            'volume_step': symbol_info.volume_step,
            'trade_mode': symbol_info.trade_mode
        }
        
        logger.info(f"Info {symbol}: Bid={tick.bid}, Ask={tick.ask}, Point={symbol_info.point}")
        logger.info(f"Volume: min={symbol_info.volume_min}, max={symbol_info.volume_max}, step={symbol_info.volume_step}")
        
        return info
        
    except Exception as e:
        logger.error(f"Erreur info {symbol}: {e}")
        return None

def test_order_calculation(symbol, signal_type="BUY"):
    """Test le calcul d'un ordre sans l'exécuter"""
    try:
        symbol_info = mt5.symbol_info(symbol)
        tick = mt5.symbol_info_tick(symbol)
        
        if not symbol_info or not tick:
            return None
        
        position_size = POSITION_SIZES.get(symbol, 0.01)
        point = symbol_info.point
        
        if signal_type == "BUY":
            price = tick.ask
            if "Boom" in symbol or "Crash" in symbol:
                sl = price - 50 * point
                tp = price + 100 * point
            else:
                sl = price - 20 * point
                tp = price + 30 * point
        else:  # SELL
            price = tick.bid
            if "Boom" in symbol or "Crash" in symbol:
                sl = price + 50 * point
                tp = price - 100 * point
            else:
                sl = price + 20 * point
                tp = price - 30 * point
        
        order_info = {
            'symbol': symbol,
            'signal': signal_type,
            'volume': position_size,
            'price': price,
            'sl': sl,
            'tp': tp,
            'point_value': point,
            'sl_distance_points': abs(sl - price) / point,
            'tp_distance_points': abs(tp - price) / point
        }
        
        logger.info(f"Ordre calculé {signal_type} {symbol}:")
        logger.info(f"  Volume: {position_size}")
        logger.info(f"  Price: {price}")
        logger.info(f"  SL: {sl} (distance: {order_info['sl_distance_points']:.1f} points)")
        logger.info(f"  TP: {tp} (distance: {order_info['tp_distance_points']:.1f} points)")
        
        return order_info
        
    except Exception as e:
        logger.error(f"Erreur calcul ordre {symbol}: {e}")
        return None

def main():
    """Fonction principale de test"""
    print("="*60)
    print("TEST MT5 TRADING CONFIGURATION")
    print("="*60)
    
    # Test connexion
    if not test_connection():
        logger.error("Impossible de continuer sans connexion MT5")
        return
    
    # Symboles à tester
    symbols_to_test = [
        "Boom 300 Index",
        "Boom 600 Index", 
        "Boom 900 Index",
        "Crash 1000 Index",
        "EURUSD",
        "GBPUSD",
        "USDJPY"
    ]
    
    print(f"\n📊 Test des {len(symbols_to_test)} symboles...")
    
    for symbol in symbols_to_test:
        print(f"\n--- {symbol} ---")
        
        # Test infos symbole
        info = test_symbol_info(symbol)
        if not info:
            continue
        
        # Test calcul ordre BUY
        buy_order = test_order_calculation(symbol, "BUY")
        
        # Test calcul ordre SELL
        sell_order = test_order_calculation(symbol, "SELL")
        
        print("-" * 40)
    
    print(f"\n✅ Test terminé")
    print("Vérifiez que:")
    print("1. Les volumes sont valides pour chaque symbole")
    print("2. Les SL/TP sont calculés correctement")
    print("3. Les distances de SL/TP sont raisonnables")

if __name__ == "__main__":
    main()
    if mt5.initialize():
        mt5.shutdown()
