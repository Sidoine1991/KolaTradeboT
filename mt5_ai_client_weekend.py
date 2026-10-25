#!/usr/bin/env python3
"""
Client MT5 pour trading de weekend (Boom/Crash uniquement)
Ce script ne trade que les indices ouverts 24/7
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
# Seulement les indices Boom/Crash (ouverts 24/7)
SYMBOLS_TO_MONITOR = [
    "Boom 300 Index",
    "Boom 600 Index", 
    "Boom 900 Index",
    "Crash 1000 Index"
]
TIMEFRAMES = ["M1", "M5"]
CHECK_INTERVAL = 60  # Secondes entre chaque vérification
MIN_CONFIDENCE = 70.0  # Confiance minimale pour prendre un trade

# Tailles de position pour Boom/Crash
POSITION_SIZES = {
    "Boom 300 Index": 0.5,  # Volume minimum pour Boom 300
    "Boom 600 Index": 0.2,
    "Boom 900 Index": 0.2,
    "Crash 1000 Index": 0.2
}

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'mt5_ai_client_weekend_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mt5_ai_client_weekend")

class MT5AIClientWeekend:
    def __init__(self):
        self.connected = False
        self.positions = {}
        
    def connect_mt5(self):
        """Connexion à MT5"""
        try:
            if not mt5.initialize():
                logger.error("Echec initialisation MT5")
                return False
            
            # Récupérer les identifiants depuis les variables d'environnement
            login = os.getenv("MT5_LOGIN")
            password = os.getenv("MT5_PASSWORD")
            server = os.getenv("MT5_SERVER")
            
            if login and password and server:
                authorized = mt5.login(login=int(login), password=password, server=server)
                if authorized:
                    logger.info(f"MT5 connecte (login: {login})")
                    self.connected = True
                    return True
            
            # Si pas de variables d'environnement, utiliser la connexion existante
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
    
    def is_market_open(self, symbol):
        """Vérifie si le marché est ouvert pour un symbole"""
        try:
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                return False
            
            # Vérifier si le symbole est visible et négociable
            return (symbol_info.visible and 
                   symbol_info.trade_mode == mt5.SYMBOL_TRADE_MODE_FULL)
                   
        except Exception as e:
            logger.error(f"Erreur vérification marché {symbol}: {e}")
            return False

    def get_ai_signal(self, symbol, timeframe="M1"):
        """Demande un signal de trading à l'IA"""
        try:
            # Vérifier si le marché est ouvert
            if not self.is_market_open(symbol):
                logger.info(f"Marche ferme pour {symbol}")
                return None
            
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                logger.warning(f"Pas de tick pour {symbol}")
                return None
            
            # Utiliser l'endpoint /predict/{symbol} avec GET
            url = f"{RENDER_API_URL}/predict/{symbol}"
            
            # Envoyer la requête GET à Render
            response = requests.get(url, timeout=30)
            
            if response.status_code == 200:
                signal_data = response.json()
                logger.info(f"Signal recu pour {symbol}: {signal_data}")
                
                # Extraire et adapter le signal
                prediction = signal_data.get('prediction', {})
                direction = prediction.get('direction', 'HOLD')
                confidence = prediction.get('confidence', 0) * 100  # Convertir en pourcentage
                
                # Convertir en format attendu
                if direction.upper() == 'UP':
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
        """Exécute un trade basé sur le signal de l'IA"""
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
            position_size = POSITION_SIZES.get(symbol, 1.0)
            
            # Préparer l'ordre
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Info symbole non disponible pour {symbol}")
                return False
            
            point = symbol_info.point
            tick = mt5.symbol_info_tick(symbol)
            
            # Récupérer la distance minimale de stops requise
            stops_level = getattr(symbol_info, 'trade_stops_level', 0)
            
            # Utiliser la distance minimale + marge de sécurité
            if stops_level > 0:
                min_distance_points = stops_level + 50  # Ajouter 50 points de marge
            else:
                # Distance par défaut si stops_level = 0
                min_distance_points = 100
            
            logger.info(f"Distance minimale SL/TP pour {symbol}: {min_distance_points} points")
            
            # Calculer SL/TP avec distances respectées
            if signal == "BUY":
                price = tick.ask
                sl = price - (min_distance_points * point)
                tp = price + (min_distance_points * 2 * point)  # TP = 2x la distance SL
                request_type = mt5.ORDER_TYPE_BUY
            else:  # SELL
                price = tick.bid
                sl = price + (min_distance_points * point)
                tp = price - (min_distance_points * 2 * point)  # TP = 2x la distance SL
                request_type = mt5.ORDER_TYPE_SELL
            
            # Arrondir SL/TP correctement
            if "Boom" in symbol or "Crash" in symbol:
                # Pour Boom/Crash, arrondir à 3 décimales
                sl = round(sl, 3)
                tp = round(tp, 3)
            else:
                # Pour Forex, arrondir selon le point
                decimals = len(str(point).split('.')[-1]) if '.' in str(point) else 0
                sl = round(sl, decimals)
                tp = round(tp, decimals)
            
            # Créer la requête d'ordre
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": position_size,
                "type": request_type,
                "price": price,
                "sl": sl,
                "tp": tp,
                "deviation": 20,
                "magic": 234000,
                "comment": f"Weekend AI Signal {signal_data.get('source', 'unknown')}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_FOK,
            }
            
            # Logger les détails pour debug
            logger.info(f"Tentative ordre {signal} {symbol}:")
            logger.info(f"  Price: {price}")
            logger.info(f"  SL: {sl} (distance: {abs(sl - price) / point:.1f} points)")
            logger.info(f"  TP: {tp} (distance: {abs(tp - price) / point:.1f} points)")
            logger.info(f"  Volume: {position_size}")
            logger.info(f"  Stops level requis: {stops_level} points")
            
            # Envoyer l'ordre
            result = mt5.order_send(request)
            
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
                "open_time": datetime.now(),
                "signal_data": signal_data
            }
            
            logger.info(f"Ordre execute: {signal} {symbol} a {price} (SL: {sl}, TP: {tp})")
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur execution trade {symbol}: {e}")
            return False
    
    def check_positions(self):
        """Vérifie les positions ouvertes"""
        try:
            positions = mt5.positions_get()
            if not positions:
                self.positions.clear()
                return
            
            current_symbols = {pos.symbol for pos in positions}
            
            # Fermer les positions qui ne sont plus dans notre tracking
            for symbol in list(self.positions.keys()):
                if symbol not in current_symbols:
                    logger.info(f"Position {symbol} fermee (plus dans MT5)")
                    del self.positions[symbol]
            
            # Mettre à jour le tracking des positions
            self.positions.clear()
            for pos in positions:
                self.positions[pos.symbol] = {
                    "ticket": pos.ticket,
                    "symbol": pos.symbol,
                    "type": "BUY" if pos.type == mt5.POSITION_TYPE_BUY else "SELL",
                    "volume": pos.volume,
                    "price": pos.price_open,
                    "sl": pos.sl,
                    "tp": pos.tp,
                    "open_time": datetime.fromtimestamp(pos.time),
                    "profit": pos.profit
                }
                
        except Exception as e:
            logger.error(f"Erreur verification positions: {e}")
    
    def run(self):
        """Boucle principale du client weekend"""
        logger.info("Demarrage du client MT5 AI Weekend (Boom/Crash uniquement)")
        
        if not self.connect_mt5():
            logger.error("Impossible de demarrer sans connexion MT5")
            return
        
        try:
            while True:
                try:
                    # Vérifier les positions existantes
                    self.check_positions()
                    
                    # Demander des signaux pour chaque symbole (uniquement Boom/Crash)
                    for symbol in SYMBOLS_TO_MONITOR:
                        if symbol not in self.positions:  # Seulement si pas de position
                            signal_data = self.get_ai_signal(symbol)
                            
                            if signal_data:
                                self.execute_trade(symbol, signal_data)
                    
                    # Attendre avant la prochaine vérification
                    time.sleep(CHECK_INTERVAL)
                    
                except KeyboardInterrupt:
                    logger.info("Arret demande par l'utilisateur")
                    break
                except Exception as e:
                    logger.error(f"Erreur dans la boucle principale: {e}")
                    time.sleep(30)  # Attendre 30s avant de réessayer
                    
        finally:
            if self.connected:
                mt5.shutdown()
                logger.info("MT5 deconnecte")

if __name__ == "__main__":
    client = MT5AIClientWeekend()
    client.run()
