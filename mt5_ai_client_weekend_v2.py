#!/usr/bin/env python3
"""
Client MT5 pour trading de weekend (Boom/Crash uniquement)
Version avec distances SL/TP très grandes pour éviter "Invalid stops"
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
        logging.FileHandler(f'mt5_ai_client_weekend_v2_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mt5_ai_client_weekend_v2")

class MT5AIClientWeekendV2:
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
                return False, "Symbole non trouvé"
            
            # Vérifier si le symbole est visible
            if not symbol_info.visible:
                return False, "Symbole non visible"
            
            # Vérifier le mode de trading (1 = Full, 4 = Close only)
            if symbol_info.trade_mode != 1:
                mode_names = {
                    0: "Désactivé",
                    1: "Complet",
                    2: "Long seulement", 
                    3: "Short seulement",
                    4: "Close seulement",
                    5: "Session longue seulement"
                }
                mode_name = mode_names.get(symbol_info.trade_mode, f"Inconnu ({symbol_info.trade_mode})")
                
                # Ajouter des informations utiles si c'est "Close seulement"
                if symbol_info.trade_mode == 4:
                    extra_info = " (Weekend/Marché fermé - Normal)"
                else:
                    extra_info = ""
                
                return False, f"Mode trading: {mode_name}{extra_info}"
            
            return True, "Marché ouvert"
                   
        except Exception as e:
            logger.error(f"Erreur vérification marché {symbol}: {e}")
            return False, f"Erreur: {str(e)}"

    def get_ai_signal(self, symbol, timeframe="M1"):
        """Demande un signal de trading à l'IA"""
        try:
            # Vérifier si le marché est ouvert
            market_open, market_status = self.is_market_open(symbol)
            if not market_open:
                logger.info(f"Marché fermé pour {symbol}: {market_status}")
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
            # NOTE: On contourne la vérification du mode car les ordres fonctionnent même en mode "Close only"
            # Le problème était le type_filling, pas le mode de trading
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
            
            point = symbol_info.point
            tick = mt5.symbol_info_tick(symbol)
            
            # Utiliser des distances TRÈS grandes pour éviter "Invalid stops"
            # Basé sur les stops level réels observés
            if "Boom 300 Index" in symbol:
                sl_distance_points = 2000  # Beaucoup plus grand que 1668
                tp_distance_points = 4000  # 2x SL
            elif "Boom 600 Index" in symbol:
                sl_distance_points = 1800  # Beaucoup plus grand que 1530
                tp_distance_points = 3600  # 2x SL
            elif "Boom 900 Index" in symbol:
                sl_distance_points = 1500  # Beaucoup plus grand que 1287
                tp_distance_points = 3000  # 2x SL
            elif "Crash 1000 Index" in symbol:
                sl_distance_points = 8000  # Beaucoup plus grand que 7620
                tp_distance_points = 16000  # 2x SL
            else:
                sl_distance_points = 1000
                tp_distance_points = 2000
            
            # Calculer SL/TP avec distances très grandes
            if signal == "BUY":
                price = tick.ask
                sl = price - (sl_distance_points * point)
                tp = price + (tp_distance_points * point)
                request_type = mt5.ORDER_TYPE_BUY
            else:  # SELL
                price = tick.bid
                sl = price + (sl_distance_points * point)
                tp = price - (tp_distance_points * point)
                request_type = mt5.ORDER_TYPE_SELL
            
            # Arrondir SL/TP correctement
            if "Boom" in symbol or "Crash" in symbol:
                # Pour Boom/Crash, arrondir à 3 décimales
                sl = round(sl, 3)
                tp = round(tp, 3)
            
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
                "comment": f"Weekend AI Signal v2 {signal_data.get('source', 'unknown')}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_FOK,  # CORRIGÉ: FOK au lieu de FOK
            }
            
            # Logger les détails pour debug
            logger.info(f"Tentative ordre {signal} {symbol}:")
            logger.info(f"  Price: {price}")
            logger.info(f"  SL: {sl} (distance: {abs(sl - price) / point:.1f} points)")
            logger.info(f"  TP: {tp} (distance: {abs(tp - price) / point:.1f} points)")
            logger.info(f"  Volume: {position_size}")
            logger.info(f"  Distances utilisées: SL={sl_distance_points}, TP={tp_distance_points} points")
            
            # Envoyer l'ordre
            result = mt5.order_send(request)
            
            # Vérifier si result est None
            if result is None:
                logger.error(f"Echec ordre {symbol}: mt5.order_send() a retourné None")
                logger.error(f"Requête: {request}")
                return False
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Echec ordre {symbol}: {result.retcode} - {result.comment}")
                
                # Si échec avec SL/TP, essayer sans SL/TP
                if "Invalid stops" in result.comment:
                    logger.info(f"Tentative sans SL/TP pour {symbol}...")
                    request_no_stops = request.copy()
                    request_no_stops['sl'] = 0.0
                    request_no_stops['tp'] = 0.0
                    request_no_stops['comment'] = f"Weekend AI Signal v2 NO STOPS {signal_data.get('source', 'unknown')}"
                    request_no_stops['type_filling'] = mt5.ORDER_FILLING_FOK  # CORRIGÉ: FOK au lieu de FOK
                    
                    result_no_stops = mt5.order_send(request_no_stops)
                    
                    # Vérifier si result_no_stops est None
                    if result_no_stops is None:
                        logger.error(f"Echec ordre sans SL/TP {symbol}: mt5.order_send() a retourné None")
                        return False
                    
                    if result_no_stops.retcode == mt5.TRADE_RETCODE_DONE:
                        logger.info(f"✅ Ordre réussi sans SL/TP: {result_no_stops.order}")
                        
                        # Enregistrer la position
                        self.positions[symbol] = {
                            "ticket": result_no_stops.order,
                            "symbol": symbol,
                            "type": signal,
                            "volume": position_size,
                            "price": result_no_stops.price,
                            "sl": 0.0,
                            "tp": 0.0,
                            "open_time": datetime.now(),
                            "signal_data": signal_data,
                            "no_stops": True
                        }
                        
                        return True
                    else:
                        logger.error(f"Echec ordre sans SL/TP {symbol}: {result_no_stops.retcode} - {result_no_stops.comment}")
                
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
                "signal_data": signal_data,
                "no_stops": False
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
        """Boucle principale du client weekend v2"""
        logger.info("Demarrage du client MT5 AI Weekend v2 (Boom/Crash uniquement)")
        
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
    client = MT5AIClientWeekendV2()
    client.run()
