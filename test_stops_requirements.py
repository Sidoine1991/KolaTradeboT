#!/usr/bin/env python3
"""
Script pour vérifier les distances minimales de SL/TP requises par MT5
"""

import sys
import logging
import MetaTrader5 as mt5
from datetime import datetime

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_stops")

def check_symbol_stops_requirements(symbol):
    """Vérifie les exigences de SL/TP pour un symbole"""
    try:
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            logger.error(f"Symbole {symbol} non disponible")
            return None
        
        tick = mt5.symbol_info_tick(symbol)
        if not tick:
            logger.error(f"Pas de tick pour {symbol}")
            return None
        
        # Récupérer les distances minimales
        point = symbol_info.point
        volume_min = symbol_info.volume_min
        stops_level = symbol_info.stops_level  # Distance minimale en points
        
        logger.info(f"=== {symbol} ===")
        logger.info(f"Point: {point}")
        logger.info(f"Volume min: {volume_min}")
        logger.info(f"Stops level: {stops_level} points")
        logger.info(f"Trade mode: {symbol_info.trade_mode}")
        logger.info(f"Current price: Bid={tick.bid}, Ask={tick.ask}")
        
        # Calculer les distances minimales en prix
        if stops_level > 0:
            min_distance_price = stops_level * point
            logger.info(f"Distance minimale SL/TP: {min_distance_price} ({stops_level} points)")
        else:
            # Si stops_level = 0, utiliser une valeur par défaut sécuritaire
            min_distance_price = 50 * point
            logger.info(f"Stops level = 0, utilisation par défaut: {min_distance_price}")
        
        # Calculer SL/TP valides
        buy_sl = tick.ask - (min_distance_price * 2)  # 2x la distance minimale
        buy_tp = tick.ask + (min_distance_price * 3)  # 3x la distance minimale
        
        sell_sl = tick.bid + (min_distance_price * 2)
        sell_tp = tick.bid - (min_distance_price * 3)
        
        logger.info(f"BUY SL: {buy_sl} (distance: {abs(buy_sl - tick.ask) / point:.1f} points)")
        logger.info(f"BUY TP: {buy_tp} (distance: {abs(buy_tp - tick.ask) / point:.1f} points)")
        logger.info(f"SELL SL: {sell_sl} (distance: {abs(sell_sl - tick.bid) / point:.1f} points)")
        logger.info(f"SELL TP: {sell_tp} (distance: {abs(sell_tp - tick.bid) / point:.1f} points)")
        
        return {
            'symbol': symbol,
            'point': point,
            'stops_level': stops_level,
            'min_distance_price': min_distance_price,
            'buy_sl': buy_sl,
            'buy_tp': buy_tp,
            'sell_sl': sell_sl,
            'sell_tp': sell_tp
        }
        
    except Exception as e:
        logger.error(f"Erreur vérification {symbol}: {e}")
        return None

def main():
    """Fonction principale"""
    print("="*60)
    print("VÉRIFICATION DES EXIGENCES SL/TP MT5")
    print("="*60)
    
    # Connexion à MT5
    if not mt5.initialize():
        logger.error("Echec initialisation MT5")
        return
    
    try:
        # Symboles à vérifier
        symbols = [
            "Boom 300 Index",
            "Boom 600 Index", 
            "Boom 900 Index",
            "Crash 1000 Index",
            "EURUSD",
            "GBPUSD",
            "USDJPY"
        ]
        
        results = {}
        
        for symbol in symbols:
            result = check_symbol_stops_requirements(symbol)
            if result:
                results[symbol] = result
            print("-" * 50)
        
        # Résumé
        print(f"\n📊 RÉSUMÉ DES DISTANCES MINIMALES:")
        print("-" * 50)
        
        for symbol, data in results.items():
            print(f"{symbol}:")
            print(f"  Stops level: {data['stops_level']} points")
            print(f"  Distance min: {data['min_distance_price']:.6f}")
            print(f"  BUY SL distance: {abs(data['buy_sl'] - data['buy_sl']) / data['point']:.1f} points")
            print()
        
    finally:
        mt5.shutdown()

if __name__ == "__main__":
    main()
