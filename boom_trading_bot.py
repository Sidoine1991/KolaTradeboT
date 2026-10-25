#!/usr/bin/env python3
"""
Intégration MT5 pour le Prédicteur Boom - Canal Haussier
Système de trading automatique basé sur les prédictions de canal haussier

⚠️ SYSTÈME DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 pour l'exécution automatique
"""

# ===================================================================
# SYSTÈME D'EXÉCUTION AUTOMATIQUE DÉSACTIVÉ
# Ce fichier est désactivé - Le système unique d'exécution est maintenant
# centralisé dans l'EA MQL5 AngelOfSpike.mq5 avec probabilité M1
# ===================================================================

DISABLED = False  # SYSTÈME RÉACTIVÉ - Trading automatique activé

if DISABLED:
    print("⚠️ BOOM TRADING BOT DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 pour l'exécution automatique")
    print("🎯 Système unifié: Probabilité M1 >= 85% pour exécution automatique")
    print("🚫 Interdiction totale des trades multiples")
    exit()

# Code original désactivé ci-dessous...

import MetaTrader5 as mt5
import time
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import threading
from dataclasses import dataclass
import logging

from boom_rising_channel_predictor import (
    BoomRisingChannelPredictor, 
    SpikeDirection, 
    get_boom_prediction,
    update_boom_data
)

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('boom_trading.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class TradingPosition:
    """Représente une position de trading"""
    ticket: int
    symbol: str
    type: str  # "BUY" ou "SELL"
    volume: float
    price: float
    sl: float
    tp: float
    timestamp: float
    prediction_confidence: float
    ema_proximity: str
    channel_position: str

class BoomTradingBot:
    """Bot de trading automatique pour Boom basé sur le canal haussier"""
    
    def __init__(self):
        self.symbol = "Boom 1000 Index"
        self.account_info = None
        self.active_positions = []
        self.trading_enabled = True
        self.max_positions = 3
        self.position_size = 0.1
        self.stop_loss_pips = 20
        self.take_profit_pips = 50
        
        # Configuration de sécurité
        self.max_daily_loss = 100.0  # USD
        self.max_daily_trades = 20
        self.daily_loss = 0.0
        self.daily_trades = 0
        self.last_reset_date = datetime.now().date()
        
        # Configuration des prédictions (paramètres assouplis)
        self.min_confidence = 0.60  # Réduit de 75% à 60%
        self.min_spike_probability = 0.65  # Réduit de 80% à 65%
        
        # Thread de monitoring
        self.monitoring_thread = None
        self.stop_monitoring = False
        
        # Initialiser MT5
        self._initialize_mt5()
    
    def _initialize_mt5(self):
        """Initialise la connexion MT5"""
        try:
            if not mt5.initialize():
                logger.error("Échec de l'initialisation MT5")
                return False
            
            # Obtenir les informations du compte
            self.account_info = mt5.account_info()
            if self.account_info is None:
                logger.error("Impossible d'obtenir les informations du compte")
                return False
            
            logger.info(f"MT5 initialisé - Compte: {self.account_info.login}")
            logger.info(f"Solde: {self.account_info.balance} {self.account_info.currency}")
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur d'initialisation MT5: {e}")
            return False
    
    def start_monitoring(self):
        """Démarre le monitoring en temps réel"""
        if not self.trading_enabled:
            logger.warning("Trading désactivé")
            return
        
        self.stop_monitoring = False
        self.monitoring_thread = threading.Thread(target=self._monitoring_loop)
        self.monitoring_thread.daemon = True
        self.monitoring_thread.start()
        
        logger.info("Monitoring Boom démarré")
    
    def stop_monitoring(self):
        """Arrête le monitoring"""
        self.stop_monitoring = True
        if self.monitoring_thread:
            self.monitoring_thread.join()
        logger.info("Monitoring Boom arrêté")
    
    def _monitoring_loop(self):
        """Boucle principale de monitoring"""
        while not self.stop_monitoring:
            try:
                # Vérifier la sécurité quotidienne
                self._check_daily_limits()
                
                # Obtenir les données de prix
                price_data = self._get_price_data()
                if price_data:
                    # Mettre à jour le prédicteur
                    update_boom_data(price_data)
                    
                    # Obtenir la prédiction
                    prediction = get_boom_prediction()
                    
                    # Analyser la prédiction
                    if prediction.get('action') != 'HOLD':
                        self._analyze_prediction(prediction)
                
                # Surveiller les positions actives
                self._monitor_positions()
                
                # Attendre avant la prochaine itération
                time.sleep(5)  # 5 secondes
                
            except Exception as e:
                logger.error(f"Erreur dans la boucle de monitoring: {e}")
                time.sleep(10)
    
    def _check_daily_limits(self):
        """Vérifie les limites quotidiennes"""
        current_date = datetime.now().date()
        
        # Réinitialiser les compteurs si nouveau jour
        if current_date != self.last_reset_date:
            self.daily_loss = 0.0
            self.daily_trades = 0
            self.last_reset_date = current_date
            logger.info("Limites quotidiennes réinitialisées")
        
        # Vérifier les limites
        if self.daily_loss >= self.max_daily_loss:
            logger.warning(f"Limite de perte quotidienne atteinte: {self.daily_loss}")
            self.trading_enabled = False
        
        if self.daily_trades >= self.max_daily_trades:
            logger.warning(f"Limite de trades quotidienne atteinte: {self.daily_trades}")
            self.trading_enabled = False
    
    def _get_price_data(self) -> Optional[List[Dict]]:
        """Obtient les données de prix depuis MT5"""
        try:
            # Obtenir les données historiques
            rates = mt5.copy_rates_from_pos(self.symbol, mt5.TIMEFRAME_M1, 0, 100)
            
            if rates is None:
                logger.error("Impossible d'obtenir les données de prix")
                return None
            
            # Convertir en format requis
            price_data = []
            for rate in rates:
                price_data.append({
                    'timestamp': rate['time'],
                    'open': rate['open'],
                    'high': rate['high'],
                    'low': rate['low'],
                    'close': rate['close'],
                    'volume': rate['tick_volume']
                })
            
            return price_data
            
        except Exception as e:
            logger.error(f"Erreur lors de l'obtention des données: {e}")
            return None
    
    def _analyze_prediction(self, prediction: Dict):
        """Analyse une prédiction et décide d'agir"""
        try:
            # Vérifier les conditions de trading
            if not self._should_trade(prediction):
                return
            
            # Vérifier le nombre de positions
            if len(self.active_positions) >= self.max_positions:
                logger.info("Nombre maximum de positions atteint")
                return
            
            # Exécuter le trade
            self._execute_trade(prediction)
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse de prédiction: {e}")
    
    def _should_trade(self, prediction: Dict) -> bool:
        """Détermine si on doit trader basé sur la prédiction"""
        # Vérifier la confiance
        confidence = prediction.get('confidence', 0)
        if confidence < self.min_confidence:
            logger.info(f"Confiance insuffisante: {confidence:.2f}")
            return False
        
        # Vérifier la probabilité de spike
        spike_probability = prediction.get('spike_probability', 0)
        if spike_probability < self.min_spike_probability:
            logger.info(f"Probabilité de spike insuffisante: {spike_probability:.2f}")
            return False
        
        # Vérifier le temps jusqu'au spike
        time_to_spike = prediction.get('time_to_spike', 0)
        if time_to_spike > 300:  # Plus de 5 minutes
            logger.info(f"Temps jusqu'au spike trop long: {time_to_spike}s")
            return False
        
        return True
    
    def _execute_trade(self, prediction: Dict):
        """Exécute un trade basé sur la prédiction"""
        try:
            # Préparer la requête de trade
            action = prediction['action']
            price = prediction['current_price']
            sl = prediction['stop_loss']
            tp = prediction['take_profit']
            
            # Déterminer le type d'ordre
            if action == 'BUY':
                order_type = mt5.ORDER_TYPE_BUY
                price_type = mt5.ORDER_TYPE_BUY
            else:
                order_type = mt5.ORDER_TYPE_SELL
                price_type = mt5.ORDER_TYPE_SELL
            
            # Obtenir le prix actuel du marché
            tick = mt5.symbol_info_tick(self.symbol)
            if tick is None:
                logger.error("Impossible d'obtenir le prix actuel")
                return
            
            # Préparer la requête
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": self.symbol,
                "volume": self.position_size,
                "type": order_type,
                "price": tick.ask if action == 'BUY' else tick.bid,
                "sl": sl,
                "tp": tp,
                "deviation": 20,
                "magic": 123456,
                "comment": f"Boom Canal Haussier - {prediction['ema_proximity']}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            # Envoyer l'ordre
            result = mt5.order_send(request)
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Échec de l'ordre: {result.retcode} - {result.comment}")
                return
            
            # Enregistrer la position
            position = TradingPosition(
                ticket=result.order,
                symbol=self.symbol,
                type=action,
                volume=self.position_size,
                price=result.price,
                sl=sl,
                tp=tp,
                timestamp=time.time(),
                prediction_confidence=prediction['confidence'],
                ema_proximity=prediction['ema_proximity'],
                channel_position=prediction['channel_position']
            )
            
            self.active_positions.append(position)
            self.daily_trades += 1
            
            logger.info(f"Trade exécuté: {action} {self.symbol} - Ticket: {result.order}")
            logger.info(f"Confiance: {prediction['confidence']:.2f} - EMA: {prediction['ema_proximity']}")
            
        except Exception as e:
            logger.error(f"Erreur lors de l'exécution du trade: {e}")
    
    def _monitor_positions(self):
        """Surveille les positions actives"""
        try:
            # Obtenir les positions depuis MT5
            positions = mt5.positions_get(symbol=self.symbol)
            
            if positions is None:
                return
            
            # Vérifier chaque position
            for position in positions:
                self._check_position_status(position)
                
        except Exception as e:
            logger.error(f"Erreur lors de la surveillance des positions: {e}")
    
    def _check_position_status(self, mt5_position):
        """Vérifie le statut d'une position"""
        try:
            # Trouver la position dans notre liste
            local_position = None
            for pos in self.active_positions:
                if pos.ticket == mt5_position.ticket:
                    local_position = pos
                    break
            
            if local_position is None:
                return
            
            # Vérifier si la position est fermée
            if mt5_position.profit is not None:
                # Position fermée
                self._handle_position_closed(local_position, mt5_position)
                
        except Exception as e:
            logger.error(f"Erreur lors de la vérification du statut: {e}")
    
    def _handle_position_closed(self, local_position: TradingPosition, mt5_position):
        """Gère une position fermée"""
        try:
            # Calculer le profit/perte
            profit = mt5_position.profit
            self.daily_loss += abs(profit) if profit < 0 else 0
            
            # Retirer de la liste active
            self.active_positions.remove(local_position)
            
            # Logger le résultat
            if profit > 0:
                logger.info(f"Position fermée avec profit: {profit:.2f} - Ticket: {local_position.ticket}")
            else:
                logger.warning(f"Position fermée avec perte: {profit:.2f} - Ticket: {local_position.ticket}")
            
            # Enregistrer les statistiques
            self._record_trade_result(local_position, profit)
            
        except Exception as e:
            logger.error(f"Erreur lors de la gestion de position fermée: {e}")
    
    def _record_trade_result(self, position: TradingPosition, profit: float):
        """Enregistre le résultat d'un trade"""
        try:
            trade_record = {
                'timestamp': datetime.now().isoformat(),
                'ticket': position.ticket,
                'symbol': position.symbol,
                'type': position.type,
                'volume': position.volume,
                'entry_price': position.price,
                'exit_price': position.price + (profit / position.volume),
                'profit': profit,
                'prediction_confidence': position.prediction_confidence,
                'ema_proximity': position.ema_proximity,
                'channel_position': position.channel_position,
                'duration': time.time() - position.timestamp
            }
            
            # Sauvegarder dans un fichier JSON
            with open('boom_trade_history.json', 'a') as f:
                f.write(json.dumps(trade_record) + '\n')
                
        except Exception as e:
            logger.error(f"Erreur lors de l'enregistrement du trade: {e}")
    
    def get_trading_status(self) -> Dict:
        """Retourne le statut du trading"""
        return {
            'trading_enabled': self.trading_enabled,
            'active_positions': len(self.active_positions),
            'daily_trades': self.daily_trades,
            'daily_loss': self.daily_loss,
            'max_daily_loss': self.max_daily_loss,
            'max_daily_trades': self.max_daily_trades,
            'account_balance': self.account_info.balance if self.account_info else 0,
            'account_currency': self.account_info.currency if self.account_info else 'USD'
        }
    
    def get_positions_summary(self) -> List[Dict]:
        """Retourne un résumé des positions actives"""
        positions_summary = []
        
        for position in self.active_positions:
            positions_summary.append({
                'ticket': position.ticket,
                'symbol': position.symbol,
                'type': position.type,
                'volume': position.volume,
                'entry_price': position.price,
                'confidence': position.prediction_confidence,
                'ema_proximity': position.ema_proximity,
                'channel_position': position.channel_position,
                'duration': int(time.time() - position.timestamp)
            })
        
        return positions_summary
    
    def close_all_positions(self):
        """Ferme toutes les positions actives"""
        try:
            for position in self.active_positions[:]:  # Copie pour éviter les modifications pendant l'itération
                self._close_position(position)
                
            logger.info("Toutes les positions ont été fermées")
            
        except Exception as e:
            logger.error(f"Erreur lors de la fermeture des positions: {e}")
    
    def _close_position(self, position: TradingPosition):
        """Ferme une position spécifique"""
        try:
            # Déterminer le type de fermeture
            if position.type == 'BUY':
                order_type = mt5.ORDER_TYPE_SELL
            else:
                order_type = mt5.ORDER_TYPE_BUY
            
            # Obtenir le prix actuel
            tick = mt5.symbol_info_tick(self.symbol)
            if tick is None:
                return
            
            # Préparer la requête de fermeture
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": self.symbol,
                "volume": position.volume,
                "type": order_type,
                "position": position.ticket,
                "price": tick.bid if position.type == 'BUY' else tick.ask,
                "deviation": 20,
                "magic": 123456,
                "comment": "Fermeture position Boom",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            # Envoyer l'ordre de fermeture
            result = mt5.order_send(request)
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"Position fermée: {position.ticket}")
            else:
                logger.error(f"Échec de fermeture: {result.retcode}")
                
        except Exception as e:
            logger.error(f"Erreur lors de la fermeture de position: {e}")
    
    def shutdown(self):
        """Arrête le bot proprement"""
        logger.info("Arrêt du bot Boom Trading...")
        
        # Arrêter le monitoring
        self.stop_monitoring()
        
        # Fermer toutes les positions si nécessaire
        # self.close_all_positions()  # Décommenter si nécessaire
        
        # Fermer MT5
        mt5.shutdown()
        
        logger.info("Bot Boom Trading arrêté")

# Instance globale du bot
boom_trading_bot = BoomTradingBot()

def start_boom_trading():
    """Démarre le trading automatique Boom"""
    boom_trading_bot.start_monitoring()

def stop_boom_trading():
    """Arrête le trading automatique Boom"""
    boom_trading_bot.stop_monitoring()

def get_boom_trading_status():
    """Obtient le statut du trading Boom"""
    return boom_trading_bot.get_trading_status()

def get_boom_positions():
    """Obtient les positions Boom actives"""
    return boom_trading_bot.get_positions_summary()

def emergency_stop():
    """Arrêt d'urgence - ferme toutes les positions"""
    boom_trading_bot.close_all_positions()
    boom_trading_bot.stop_monitoring()

if __name__ == "__main__":
    # Test du bot de trading Boom
    print("🤖 Test du Bot de Trading Boom - Canal Haussier")
    print("=" * 60)
    
    try:
        # Initialiser le bot
        if boom_trading_bot._initialize_mt5():
            print("✅ MT5 initialisé avec succès")
            
            # Afficher le statut
            status = get_boom_trading_status()
            print(f"\n📊 Statut du trading:")
            print(f"   Trading activé: {status['trading_enabled']}")
            print(f"   Solde: {status['account_balance']} {status['account_currency']}")
            print(f"   Positions actives: {status['active_positions']}")
            print(f"   Trades aujourd'hui: {status['daily_trades']}")
            
            # Démarrer le monitoring (simulation)
            print(f"\n🚀 Démarrage du monitoring...")
            boom_trading_bot.start_monitoring()
            
            # Attendre un peu
            time.sleep(10)
            
            # Afficher les positions
            positions = get_boom_positions()
            if positions:
                print(f"\n📈 Positions actives:")
                for pos in positions:
                    print(f"   Ticket: {pos['ticket']} - {pos['type']} - Confiance: {pos['confidence']:.2f}")
            else:
                print(f"\n📈 Aucune position active")
            
            # Arrêter le monitoring
            boom_trading_bot.stop_monitoring()
            print(f"\n⏹️ Monitoring arrêté")
            
        else:
            print("❌ Échec de l'initialisation MT5")
    
    except Exception as e:
        print(f"❌ Erreur: {e}")
    
    finally:
        # Nettoyage
        boom_trading_bot.shutdown()
        print("🔚 Bot arrêté")
