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

# MONEY MANAGEMENT - RÈGLES STRICTES
MAX_LOSS_USD = 5.0  # Fermer si perte >= -5$
PROFIT_TARGET_USD = 10.0  # Fermer si profit >= +10$
REENTRY_DELAY_SECONDS = 3  # Délai avant ré-entrée après profit

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
        # Money management tracking
        self.last_profit_close_time = {}
        self.last_profit_close_symbol = {}
        self.last_profit_close_direction = {}
        # Suivi du trailing stop
        self.best_prices = {}  # Meilleur prix atteint par position
        
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
    
    def check_money_management(self):
        """Vérifie et ferme les positions selon les règles de money management"""
        try:
            positions = mt5.positions_get()
            if not positions:
                return
            
            for position in positions:
                # Calculer le profit total (inclut swap + commission)
                total_profit = position.profit + position.swap + position.commission
                
                # RÈGLE 1: FERMER SI PERTE >= -5$
                if total_profit <= -MAX_LOSS_USD:
                    logger.warning(f"🚨 PERTE MAX ATTEINTE: {position.symbol} - Perte: {total_profit:.2f}$ (limite: -{MAX_LOSS_USD}$)")
                    self.close_position(position.ticket, f"Max Loss -{MAX_LOSS_USD}$")
                    continue
                
                # RÈGLE 2: FERMER SI PROFIT >= +10$
                if total_profit >= PROFIT_TARGET_USD:
                    logger.info(f"💰 PROFIT CIBLE ATTEINT: {position.symbol} - Profit: {total_profit:.2f}$ (cible: +{PROFIT_TARGET_USD}$)")
                    
                    # Enregistrer pour ré-entrée rapide
                    direction = "BUY" if position.type == mt5.POSITION_TYPE_BUY else "SELL"
                    self.last_profit_close_time[position.symbol] = datetime.now()
                    self.last_profit_close_symbol[position.symbol] = position.symbol
                    self.last_profit_close_direction[position.symbol] = direction
                    
                    logger.info(f"🔄 Ré-entrée prévue dans {REENTRY_DELAY_SECONDS}s pour {position.symbol} direction={direction}")
                    
                    self.close_position(position.ticket, f"Profit Target +{PROFIT_TARGET_USD}$")
                    
        except Exception as e:
            logger.error(f"Erreur money management: {e}")
    
    def close_position(self, ticket, reason):
        """Ferme une position et enregistre la raison"""
        try:
            position = mt5.positions_get(ticket=ticket)
            if not position:
                logger.error(f"Position {ticket} non trouvée")
                return False
                
            position = position[0]
            
            # Préparer la requête de fermeture
            if position.type == mt5.POSITION_TYPE_BUY:
                request = {
                    "action": mt5.TRADE_ACTION_DEAL,
                    "symbol": position.symbol,
                    "volume": position.volume,
                    "type": mt5.ORDER_TYPE_SELL,
                    "position": ticket,
                    "price": mt5.symbol_info_tick(position.symbol).bid,
                    "deviation": 20,
                    "magic": 234000,
                    "comment": f"Close: {reason}",
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": mt5.ORDER_FILLING_FOK,
                }
            else:  # SELL
                request = {
                    "action": mt5.TRADE_ACTION_DEAL,
                    "symbol": position.symbol,
                    "volume": position.volume,
                    "type": mt5.ORDER_TYPE_BUY,
                    "position": ticket,
                    "price": mt5.symbol_info_tick(position.symbol).ask,
                    "deviation": 20,
                    "magic": 234000,
                    "comment": f"Close: {reason}",
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": mt5.ORDER_FILLING_FOK,
                }
            
            # Envoyer la requête de fermeture
            result = mt5.order_send(request)
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                profit = position.profit + position.swap + position.commission
                logger.info(f"✅ Position fermée: {ticket} - {position.symbol} - Profit: {profit:.2f}$ - Raison: {reason}")
                
                # Nettoyer le suivi des positions
                if position.symbol in self.positions:
                    del self.positions[position.symbol]
                
                return True
            else:
                logger.error(f"❌ Échec fermeture position {ticket}: {result.retcode} - {result.comment}")
                return False
                
        except Exception as e:
            logger.error(f"Erreur fermeture position {ticket}: {e}")
            return False
    
    def check_quick_reentry(self):
        """Vérifie et exécute les ré-entrées rapides après profit"""
        try:
            current_time = datetime.now()
            
            for symbol in list(self.last_profit_close_time.keys()):
                # Vérifier le délai
                close_time = self.last_profit_close_time[symbol]
                if (current_time - close_time).total_seconds() < REENTRY_DELAY_SECONDS:
                    continue
                
                # Vérifier qu'on n'a pas déjà de position sur ce symbole
                positions = mt5.positions_get(symbol=symbol)
                if positions:
                    # Annuler la ré-entrée si position existe
                    del self.last_profit_close_time[symbol]
                    if symbol in self.last_profit_close_symbol:
                        del self.last_profit_close_symbol[symbol]
                    if symbol in self.last_profit_close_direction:
                        del self.last_profit_close_direction[symbol]
                    continue
                
                # Exécuter la ré-entrée
                direction = self.last_profit_close_direction.get(symbol)
                if direction:
                    signal_data = {
                        'signal': direction,
                        'confidence': 90.0,  # Haute confiance pour ré-entrée
                        'source': 'quick_reentry'
                    }
                    
                    logger.info(f"🔄 RÉ-ENTREE RAPIDE: {symbol} direction={direction} après profit de +{PROFIT_TARGET_USD}$")
                    
                    if self.execute_trade(symbol, signal_data):
                        # Nettoyer après ré-entrée réussie
                        del self.last_profit_close_time[symbol]
                        del self.last_profit_close_symbol[symbol]
                        del self.last_profit_close_direction[symbol]
                    
        except Exception as e:
            logger.error(f"Erreur ré-entrée rapide: {e}")
    
    
    def calculate_sl_tp(self, symbol, price, signal):
        """Calcule les niveaux de SL et TP en fonction du signal et du prix"""
        point = mt5.symbol_info(symbol).point
        
        if signal == "BUY":
            sl = price - STOP_LOSS_POINTS * point
            tp = price + TAKE_PROFIT_POINTS * point
        else:  # SELL
            sl = price + STOP_LOSS_POINTS * point
            tp = price - TAKE_PROFIT_POINTS * point
            
        return sl, tp
    
    def execute_trade(self, symbol, signal_data):
        """Exécute un trade avec SL/TP et restrictions Boom/Crash"""
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
            
            # Calculer SL/TP
            entry_price = tick.ask if signal == "BUY" else tick.bid
            sl, tp = self.calculate_sl_tp(symbol, entry_price, signal)
            
            # Préparer la requête de trading
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": position_size,
                "type": mt5.ORDER_TYPE_BUY if signal == "BUY" else mt5.ORDER_TYPE_SELL,
                "price": entry_price,
                "sl": sl,
                "tp": tp,
                "deviation": 20,
                "magic": 234000,
                "comment": f"AI Signal {signal_data.get('source', 'unknown')}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_FOK,
            }
            
            logger.info(f"Tentative ordre {signal} {symbol}:")
            logger.info(f"  Price: {request['price']}")
            logger.info(f"  Volume: {position_size}")
            logger.info(f"  SL: {sl} ({(sl - entry_price) / point} points)")
            logger.info(f"  TP: {tp} ({(tp - entry_price) / point} points)")
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
                    "sl": sl,
                    "tp": tp,
                    "best_price": result.price  # Initialiser le meilleur prix
                }
                
                # Initialiser le meilleur prix pour le trailing stop
                self.best_prices[result.order] = result.price
                
                return True
            else:
                logger.error(f"Echec ordre {symbol}: {result.retcode} - {result.comment}")
                return False
            
        except Exception as e:
            logger.error(f"Erreur execution trade {symbol}: {e}")
            return False
    
    def manage_trailing_stop(self, position):
        """Gère le trailing stop pour une position ouverte"""
        if not USE_TRAILING_STOP or TRAILING_STOP_POINTS <= 0 or TRAILING_STEP <= 0:
            return False
            
        ticket = position.ticket
        symbol = position.symbol
        pos_type = position.type
        current_price = position.price_current
        current_sl = position.sl
        point = mt5.symbol_info(symbol).point
        
        # Initialiser ou mettre à jour le meilleur prix
        if ticket not in self.best_prices:
            self.best_prices[ticket] = current_price
            
        best_price = self.best_prices[ticket]
        
        # Mettre à jour le meilleur prix si nécessaire
        if (pos_type == mt5.POSITION_TYPE_BUY and current_price > best_price) or \
           (pos_type == mt5.POSITION_TYPE_SELL and current_price < best_price):
            self.best_prices[ticket] = current_price
            best_price = current_price
        
        # Calculer le nouveau stop loss
        if pos_type == mt5.POSITION_TYPE_BUY:
            new_sl = best_price - TRAILING_STOP_POINTS * point
            # Ne déplacer le SL que s'il est plus élevé que le précédent et que le prix a suffisamment évolué
            if new_sl > current_sl + TRAILING_STEP * point and new_sl > position.price_open:
                # Vérifier que le nouveau SL est valide (pas trop proche du prix)
                if new_sl < current_price - 10 * point:  # Au moins 10 points du prix actuel
                    request = {
                        "action": mt5.TRADE_ACTION_SLTP,
                        "symbol": symbol,
                        "sl": new_sl,
                        "tp": position.tp,  # Garder le TP inchangé
                        "position": ticket
                    }
                    result = mt5.order_send(request)
                    if result.retcode == mt5.TRADE_RETCODE_DONE:
                        logger.info(f"🔄 Trailing Stop mis à jour pour {symbol}: {current_sl} -> {new_sl}")
                        return True
        else:  # SELL
            new_sl = best_price + TRAILING_STOP_POINTS * point
            # Ne déplacer le SL que s'il est plus bas que le précédent et que le prix a suffisamment évolué
            if (current_sl == 0 and new_sl < current_price - TRAILING_STEP * point) or \
               (current_sl > 0 and new_sl < current_sl - TRAILING_STEP * point):
                # Vérifier que le nouveau SL est valide (pas trop proche du prix)
                if new_sl > current_price + 10 * point:  # Au moins 10 points du prix actuel
                    request = {
                        "action": mt5.TRADE_ACTION_SLTP,
                        "symbol": symbol,
                        "sl": new_sl,
                        "tp": position.tp,  # Garder le TP inchangé
                        "position": ticket
                    }
                    result = mt5.order_send(request)
                    if result.retcode == mt5.TRADE_RETCODE_DONE:
                        logger.info(f"🔄 Trailing Stop mis à jour pour {symbol}: {current_sl} -> {new_sl}")
                        return True
        
        return False
    
    def check_positions(self):
        """Vérifie les positions ouvertes et gère le trailing stop"""
        try:
            positions = mt5.positions_get()
            if not positions:
                self.positions.clear()
                self.best_prices.clear()
                return
            
            current_tickets = set()
            
            for position in positions:
                current_tickets.add(position.ticket)
                
                # Mettre à jour les informations de position
                if position.symbol in self.positions:
                    self.positions[position.symbol].update({
                        'ticket': position.ticket,
                        'sl': position.sl,
                        'tp': position.tp,
                        'price': position.price_open,
                        'current_price': position.price_current,
                        'profit': position.profit
                    })
                
                # Gérer le trailing stop si activé
                if USE_TRAILING_STOP:
                    self.manage_trailing_stop(position)
            
            # Nettoyer les positions fermées
            for symbol in list(self.positions.keys()):
                pos = self.positions[symbol]
                if 'ticket' in pos and pos['ticket'] not in current_tickets:
                    logger.info(f"Position {symbol} fermée (ticket: {pos['ticket']})")
                    if pos['ticket'] in self.best_prices:
                        del self.best_prices[pos['ticket']]
                    del self.positions[symbol]
            
        except Exception as e:
            logger.error(f"Erreur vérification positions: {e}")
            import traceback
            logger.error(traceback.format_exc())
    
    def run(self):
        """Boucle principale"""
        logger.info("Démarrage du client MT5 AI Simple avec SL/TP et Trailing Stop")
        logger.info(f"Configuration - SL: {STOP_LOSS_POINTS} points, TP: {TAKE_PROFIT_POINTS} points")
        logger.info(f"Trailing Stop: {'Activé' if USE_TRAILING_STOP else 'Désactivé'}")
        if USE_TRAILING_STOP:
            logger.info(f"  - Distance: {TRAILING_STOP_POINTS} points")
            logger.info(f"  - Pas: {TRAILING_STEP} points")
        
        if not self.connect_mt5():
            logger.error("Impossible de demarrer sans connexion MT5")
            return
        
        try:
            while True:
                try:
                    # PRIORITÉ ABSOLUE: Money management chaque boucle
                    self.check_money_management()
                    self.check_quick_reentry()
                    
                    self.check_positions()
                    
                    for symbol in SYMBOLS_TO_MONITOR:
                        if symbol not in self.positions:
                            signal_data = self.get_ai_signal(symbol)
                            
                            if signal_data:
                                self.execute_trade(symbol, signal_data)
                    
                    time.sleep(10)  # Vérifier toutes les 10 secondes (plus fréquent pour money management)
                    
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
