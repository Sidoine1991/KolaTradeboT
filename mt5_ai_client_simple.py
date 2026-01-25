#!/usr/bin/env python3
"""
Client MT5 simplifié - utilise la configuration exacte du test qui fonctionne
"""

import os
import time
import logging
import requests
import MetaTrader5 as mt5
from datetime import datetime

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
SYMBOLS_TO_MONITOR = [
    "Boom 300 Index",
    "Boom 600 Index", 
    "Boom 900 Index",
    "Crash 1000 Index"
]
MIN_CONFIDENCE = 70.0

# Tailles de position
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
        logging.FileHandler(f'mt5_ai_client_simple_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mt5_ai_client_simple")

class MT5AIClientSimple:
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

    def get_ai_signal(self, symbol):
        """Demande un signal de trading à l'IA"""
        try:
            url = f"{RENDER_API_URL}/predict/{symbol}"
            response = requests.get(url, timeout=30)
            
            if response.status_code == 200:
                signal_data = response.json()
                logger.info(f"Signal recu pour {symbol}: {signal_data}")
                
                prediction = signal_data.get('prediction', {})
                direction = prediction.get('direction', 'HOLD')
                confidence = prediction.get('confidence', 0) * 100
                
                if direction.upper() == 'UP':
                    return {
                        'signal': 'BUY',
                        'confidence': confidence,
                        'source': 'render_api'
                    }
                elif direction.upper() == 'DOWN':
                    return {
                        'signal': 'SELL',
                        'confidence': confidence,
                        'source': 'render_api'
                    }
                else:
                    return None
            else:
                logger.error(f"Erreur signal {symbol}: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Erreur signal {symbol}: {e}")
            return None
    
    def execute_trade(self, symbol, signal_data):
        """Exécute un trade SANS SL/TP avec restrictions Boom/Crash"""
        try:
            signal = signal_data.get('signal')
            confidence = signal_data.get('confidence', 0)
            
            if confidence < MIN_CONFIDENCE:
                logger.info(f"Confiance trop faible pour {symbol}: {confidence}%")
                return False
            
            if symbol in self.positions:
                logger.info(f"Position existante pour {symbol}")
                return False
            
            # Règles importantes pour Boom/Crash
            if "Boom" in symbol and signal == "SELL":
                # ✅ SELL autorisé sur Boom
                pass
            elif "Boom" in symbol and signal == "BUY":
                logger.info(f"🚫 Trade bloqué: {symbol} - BUY non autorisé sur Boom")
                return False
            elif "Crash" in symbol and signal == "BUY":
                # ✅ BUY autorisé sur Crash
                pass
            elif "Crash" in symbol and signal == "SELL":
                logger.info(f"🚫 Trade bloqué: {symbol} - SELL non autorisé sur Crash")
                return False
            
            position_size = POSITION_SIZES.get(symbol, 0.2)
            tick = mt5.symbol_info_tick(symbol)
            
            if not tick:
                logger.error(f"Pas de tick pour {symbol}")
                return False
            
            # Utiliser exactement la même configuration que le test qui fonctionne
            if signal == "BUY":
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
                    "comment": f"AI Signal {signal_data.get('source', 'unknown')}",
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": mt5.ORDER_FILLING_FOK,
                }
            else:  # SELL
                request = {
                    "action": mt5.TRADE_ACTION_DEAL,
                    "symbol": symbol,
                    "volume": position_size,
                    "type": mt5.ORDER_TYPE_SELL,
                    "price": tick.bid,
                    "sl": 0.0,  # Pas de SL
                    "tp": 0.0,  # Pas de TP
                    "deviation": 20,
                    "magic": 234000,
                    "comment": f"AI Signal {signal_data.get('source', 'unknown')}",
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": mt5.ORDER_FILLING_FOK,
                }
            
            logger.info(f"Tentative ordre {signal} {symbol}:")
            logger.info(f"  Price: {request['price']}")
            logger.info(f"  Volume: {position_size}")
            logger.info(f"  Sans SL/TP")
            logger.info(f"  ✅ Direction valide pour {symbol}")
            
            # Envoyer l'ordre
            result = mt5.order_send(request)
            
            if result is None:
                logger.error(f"Echec ordre {symbol}: mt5.order_send() a retourné None")
                logger.error(f"Requête: {request}")
                return False
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"✅ Ordre réussi: {result.order}")
                
                # Enregistrer la position
                self.positions[symbol] = {
                    "ticket": result.order,
                    "symbol": symbol,
                    "type": signal,
                    "volume": position_size,
                    "price": result.price,
                    "open_time": datetime.now(),
                    "signal_data": signal_data,
                    "no_stops": True
                }
                
                return True
            else:
                logger.error(f"Echec ordre {symbol}: {result.retcode} - {result.comment}")
                return False
            
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
            
            for symbol in list(self.positions.keys()):
                if symbol not in current_symbols:
                    logger.info(f"Position {symbol} fermee")
                    del self.positions[symbol]
            
        except Exception as e:
            logger.error(f"Erreur verification positions: {e}")
    
    def run(self):
        """Boucle principale"""
        logger.info("Demarrage du client MT5 AI Simple (sans SL/TP)")
        
        if not self.connect_mt5():
            logger.error("Impossible de demarrer sans connexion MT5")
            return
        
        try:
            while True:
                try:
                    self.check_positions()
                    
                    for symbol in SYMBOLS_TO_MONITOR:
                        if symbol not in self.positions:
                            signal_data = self.get_ai_signal(symbol)
                            
                            if signal_data:
                                self.execute_trade(symbol, signal_data)
                    
                    time.sleep(60)  # Vérifier toutes les minutes
                    
                except KeyboardInterrupt:
                    logger.info("Arret demande par l'utilisateur")
                    break
                except Exception as e:
                    logger.error(f"Erreur dans la boucle principale: {e}")
                    time.sleep(30)
                    
        finally:
            if self.connected:
                mt5.shutdown()
                logger.info("MT5 deconnecte")

if __name__ == "__main__":
    client = MT5AIClientSimple()
    client.run()
