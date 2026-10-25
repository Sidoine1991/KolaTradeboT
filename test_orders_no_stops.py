#!/usr/bin/env python3
"""
Script de test pour vérifier si les ordres passent sans SL/TP
"""

import os
import time
import logging
import MetaTrader5 as mt5
from datetime import datetime

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_orders")

# Configuration
POSITION_SIZES = {
    "Boom 300 Index": 0.5,
    "Boom 600 Index": 0.2,
    "Boom 900 Index": 0.2,
    "Crash 1000 Index": 0.2
}

def test_order_without_stops(symbol):
    """Test un ordre sans SL/TP"""
    try:
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            logger.error(f"Symbole {symbol} non disponible")
            return False
        
        tick = mt5.symbol_info_tick(symbol)
        if not tick:
            logger.error(f"Pas de tick pour {symbol}")
            return False
        
        position_size = POSITION_SIZES.get(symbol, 0.2)
        
        # Ordre BUY sans SL/TP
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": position_size,
            "type": mt5.ORDER_TYPE_BUY,
            "price": tick.ask,
            "sl": 0.0,  # Pas de SL
            "tp": 0.0,  # Pas de TP
            "deviation": 20,
            "magic": 234000,
            "comment": "Test order without stops",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_FOK,
        }
        
        logger.info(f"Test ordre BUY {symbol} sans SL/TP:")
        logger.info(f"  Price: {tick.ask}")
        logger.info(f"  Volume: {position_size}")
        
        result = mt5.order_send(request)
        
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            logger.info(f"✅ Ordre réussi: {result.order}")
            
            # Fermer immédiatement la position
            close_request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": position_size,
                "type": mt5.ORDER_TYPE_SELL,
                "position": result.order,
                "price": tick.bid,
                "deviation": 20,
                "magic": 234000,
                "comment": "Close test order",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_FOK,
            }
            
            close_result = mt5.order_send(close_request)
            if close_result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"✅ Position fermée")
            else:
                logger.error(f"❌ Erreur fermeture: {close_result.retcode}")
            
            return True
        else:
            logger.error(f"❌ Echec ordre {symbol}: {result.retcode} - {result.comment}")
            return False
            
    except Exception as e:
        logger.error(f"Erreur test {symbol}: {e}")
        return False

def main():
    """Fonction principale"""
    print("="*60)
    print("TEST ORDRES SANS SL/TP")
    print("="*60)
    
    if not mt5.initialize():
        logger.error("Echec initialisation MT5")
        return
    
    try:
        symbols = ["Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"]
        
        for symbol in symbols:
            logger.info(f"\n--- Test {symbol} ---")
            success = test_order_without_stops(symbol)
            time.sleep(2)  # Pause entre les tests
        
    finally:
        mt5.shutdown()

if __name__ == "__main__":
    main()
