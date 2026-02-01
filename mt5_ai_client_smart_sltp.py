#!/usr/bin/env python3
"""
Client MT5 avec SL/TP intelligents proportionnels au prix
SL = 20% du prix | TP = 80% du prix
"""

import os
import sys
import time
import json
import logging
import requests
import MetaTrader5 as mt5
from datetime import datetime, timedelta
from pathlib import Path

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
SYMBOLS_TO_MONITOR = [
    "Boom 300 Index",
    "Boom 600 Index", 
    "Boom 900 Index",
    "Crash 1000 Index"
]
TIMEFRAMES = ["M1", "M5"]
CHECK_INTERVAL = 60  # Secondes entre chaque vérification
MIN_CONFIDENCE = 70.0  # Confiance minimale pour prendre un trade

# SL/TP proportionnels au prix
SL_PERCENTAGE = 0.20  # 20% du prix pour SL
TP_PERCENTAGE = 0.80  # 80% du prix pour TP

# Tailles de position pour Boom/Crash
POSITION_SIZES = {
    "Boom 300 Index": 0.5,
    "Boom 600 Index": 0.2,
    "Boom 900 Index": 0.2,
    "Crash 1000 Index": 0.2
}

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'mt5_ai_client_smart_sltp_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mt5_ai_client_smart_sltp")

class MT5AIClientSmartSLTP:
    def __init__(self):
        self.connected = False
        self.positions = {}
        
    def connect_mt5(self):
        """Connexion à MT5"""
        try:
            if not mt5.initialize():
                logger.error("Echec initialisation MT5")
                return False
            
            account_info = mt5.account_info()
            if account_info:
                logger.info(f"MT5 connecte (compte: {account_info.login})")
                self.connected = True
                return True
                
            logger.error("Impossible de se connecter a MT5")
            return False
            
        except Exception as e:
            logger.error(f"Erreur connexion MT5: {e}")
            return False
    
    def calculate_smart_sltp(self, symbol, entry_price, order_type):
        """
        Calcule SL/TP proportionnels au prix
        SL = 20% du prix | TP = 80% du prix
        """
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            return None, None
        
        point = symbol_info.point
        digits = symbol_info.digits
        
        # Calculer les distances en points selon le pourcentage du prix
        sl_distance_price = entry_price * SL_PERCENTAGE
        tp_distance_price = entry_price * TP_PERCENTAGE
        
        # Convertir en points
        sl_distance_points = sl_distance_price / point
        tp_distance_points = tp_distance_price / point
        
        if order_type == mt5.ORDER_TYPE_BUY:
            # BUY: SL en dessous, TP au dessus
            sl = entry_price - sl_distance_price
            tp = entry_price + tp_distance_price
        else:  # SELL
            # SELL: SL au dessus, TP en dessous
            sl = entry_price + sl_distance_price
            tp = entry_price - tp_distance_price
        
        # Arrondir correctement selon le nombre de décimales
        sl = round(sl, digits)
        tp = round(tp, digits)
        
        logger.info(f"📏 SL/TP calculés pour {symbol}:")
        logger.info(f"   Entry: {entry_price}")
        logger.info(f"   SL: {sl} (distance: {sl_distance_points:.0f} points = {SL_PERCENTAGE*100:.0f}% du prix)")
        logger.info(f"   TP: {tp} (distance: {tp_distance_points:.0f} points = {TP_PERCENTAGE*100:.0f}% du prix)")
        
        return sl, tp
    
    def get_ai_signal(self, symbol, timeframe="M1"):
        """Demande un signal de trading à l'IA"""
        try:
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                logger.warning(f"Pas de tick pour {symbol}")
                return None
            
            # Utiliser l'endpoint /predict/{symbol} avec GET
            url = f"{RENDER_API_URL}/predict/{symbol}"
            
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                direction = data.get('direction', '').upper()
                confidence = data.get('confidence', 0)
                
                if direction == 'UP':
                    return {
                        'signal': 'BUY',
                        'confidence': confidence,
                        'stop_loss': None,  # Sera calculé localement
                        'take_profit': None,  # Sera calculé localement
                        'source': 'render_api'
                    }
                elif direction.upper() == 'DOWN':
                    return {
                        'signal': 'SELL',
                        'confidence': confidence,
                        'stop_loss': None,  # Sera calculé localement
                        'take_profit': None,  # Sera calculé localement
                        'source': 'render_api'
                    }
                else:
                    logger.info(f"Pas de signal trade pour {symbol}: {direction}")
                    return None
            else:
                logger.error(f"Erreur signal {symbol}: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Erreur signal {symbol}: {e}")
            return None
    
    def execute_trade(self, symbol, signal_data):
        """Exécute un trade basé sur le signal de l'IA avec SL/TP intelligents"""
        try:
            signal = signal_data.get('signal')
            confidence = signal_data.get('confidence', 0)
            
            if confidence < MIN_CONFIDENCE:
                logger.info(f"Confiance trop faible pour {symbol}: {confidence}% < {MIN_CONFIDENCE}%")
                return False
            
            if signal not in ["BUY", "SELL"]:
                logger.info(f"Pas de signal trade pour {symbol}: {signal}")
                return False
            
            # Vérifier si nous avons déjà une position sur ce symbole
            if symbol in self.positions:
                logger.info(f"Position existante pour {symbol}, ignore")
                return False
            
            # Récupérer la taille de position appropriée
            position_size = POSITION_SIZES.get(symbol, 0.2)
            
            # Préparer l'ordre
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Info symbole non disponible pour {symbol}")
                return False
            
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                logger.error(f"Pas de tick pour {symbol}")
                return False
            
            # Déterminer le prix d'entrée et le type d'ordre
            if signal == "BUY":
                entry_price = tick.ask
                request_type = mt5.ORDER_TYPE_BUY
            else:  # SELL
                entry_price = tick.bid
                request_type = mt5.ORDER_TYPE_SELL
            
            # Calculer SL/TP proportionnels
            sl, tp = self.calculate_smart_sltp(symbol, entry_price, request_type)
            
            if sl is None or tp is None:
                logger.error(f"Impossible de calculer SL/TP pour {symbol}")
                return False
            
            # Créer la requête d'ordre avec SL/TP intelligents
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": position_size,
                "type": request_type,
                "price": entry_price,
                "sl": sl,
                "tp": tp,
                "deviation": 20,
                "magic": 234000,
                "comment": f"Smart SLTP AI Signal {signal_data.get('source', 'unknown')}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_FOK,
            }
            
            # Logger les détails pour debug
            logger.info(f"🎯 Ordre Smart SL/TP {signal} {symbol}:")
            logger.info(f"   Entry: {entry_price}")
            logger.info(f"   SL: {sl} ({SL_PERCENTAGE*100:.0f}% du prix)")
            logger.info(f"   TP: {tp} ({TP_PERCENTAGE*100:.0f}% du prix)")
            logger.info(f"   Volume: {position_size}")
            logger.info(f"   Risk/Reward: 1:{TP_PERCENTAGE/SL_PERCENTAGE:.1f}")
            
            # Envoyer l'ordre
            result = mt5.order_send(request)
            
            # Vérifier si result est None
            if result is None:
                logger.error(f"Echec ordre {symbol}: mt5.order_send() a retourné None")
                logger.error(f"Requête: {request}")
                return False
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Echec ordre {symbol}: {result.retcode} - {result.comment}")
                return False
            
            # Enregistrer la position
            self.positions[symbol] = {
                "ticket": result.order,
                "symbol": symbol,
                "type": signal,
                "volume": position_size,
                "price": result.price,
                "sl": sl,
                "tp": tp,
                "entry_price": entry_price,
                "open_time": datetime.now(),
                "signal_data": signal_data,
                "sl_percentage": SL_PERCENTAGE,
                "tp_percentage": TP_PERCENTAGE
            }
            
            logger.info(f"✅ Ordre Smart SL/TP réussi: {result.order}")
            logger.info(f"   📊 Risk: ${abs(entry_price - sl) * position_size:.2f}")
            logger.info(f"   🎯 Reward: ${abs(tp - entry_price) * position_size:.2f}")
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur execute_trade {symbol}: {e}")
            return False
    
    def check_positions(self):
        """Vérifie l'état des positions ouvertes avec SL/TP tracking"""
        try:
            positions_to_remove = []
            
            for symbol, pos_info in self.positions.items():
                ticket = pos_info["ticket"]
                
                # Vérifier si la position existe encore dans MT5
                position = mt5.positions_get(ticket=ticket)
                
                if not position:
                    # La position n'existe plus, la supprimer de notre suivi
                    logger.info(f"Position {symbol} fermee (plus dans MT5)")
                    positions_to_remove.append(symbol)
                else:
                    # Position encore ouverte, vérifier le profit et distance SL/TP
                    current_pos = position[0]
                    current_profit = current_pos.profit
                    current_price = current_pos.price_current
                    
                    entry_price = pos_info["entry_price"]
                    sl = pos_info["sl"]
                    tp = pos_info["tp"]
                    
                    # Calculer les distances
                    if current_pos.type == mt5.POSITION_TYPE_BUY:
                        distance_to_sl = (current_price - sl) / sl if sl > 0 else 0
                        distance_to_tp = (tp - current_price) / tp if tp > 0 else 0
                    else:  # SELL
                        distance_to_sl = (sl - current_price) / sl if sl > 0 else 0
                        distance_to_tp = (current_price - tp) / tp if tp > 0 else 0
                    
                    logger.debug(f"Position {symbol} (ticket={ticket}):")
                    logger.debug(f"   Profit: {current_profit:.2f}")
                    logger.debug(f"   Distance SL: {distance_to_sl*100:.1f}%")
                    logger.debug(f"   Distance TP: {distance_to_tp*100:.1f}%")
            
            # Supprimer les positions fermées
            for symbol in positions_to_remove:
                del self.positions[symbol]
                
        except Exception as e:
            logger.error(f"Erreur check_positions: {e}")
    
    def run(self):
        """Boucle principale du client"""
        logger.info("🚀 Demarrage du client MT5 AI Smart SL/TP")
        logger.info(f"📏 Configuration: SL={SL_PERCENTAGE*100:.0f}% du prix | TP={TP_PERCENTAGE*100:.0f}% du prix")
        
        if not self.connect_mt5():
            return
        
        try:
            while True:
                try:
                    # Vérifier les positions existantes
                    self.check_positions()
                    
                    # Pour chaque symbole, vérifier les signaux
                    for symbol in SYMBOLS_TO_MONITOR:
                        try:
                            # Obtenir un signal de l'IA
                            signal_data = self.get_ai_signal(symbol)
                            
                            if signal_data:
                                # Exécuter le trade avec SL/TP intelligents
                                self.execute_trade(symbol, signal_data)
                            
                        except Exception as e:
                            logger.error(f"Erreur traitement {symbol}: {e}")
                            continue
                    
                    # Attendre avant la prochaine vérification
                    time.sleep(CHECK_INTERVAL)
                    
                except KeyboardInterrupt:
                    logger.info("Arret demande par l'utilisateur")
                    break
                    
        except Exception as e:
            logger.error(f"Erreur dans la boucle principale: {e}")
        
        finally:
            # Nettoyage
            if self.connected:
                mt5.shutdown()
                logger.info("MT5 deconnecte")

if __name__ == "__main__":
    client = MT5AIClientSmartSLTP()
    client.run()
