#!/usr/bin/env python3
"""
Client MT5 avec détection dynamique des symboles par catégories
Catégories: Boom/Crash → Volatility → Forex
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
TIMEFRAMES = ["M1", "M5"]
CHECK_INTERVAL = 60  # Secondes entre chaque vérification
MIN_CONFIDENCE = 70.0  # Confiance minimale pour prendre un trade

# SL/TP proportionnels au prix (plus réalistes)
SL_PERCENTAGE = 0.02  # 2% du prix pour SL
TP_PERCENTAGE = 0.04  # 4% du prix pour TP

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'mt5_ai_client_dynamic_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mt5_ai_client_dynamic")

class SymbolDetector:
    """Détecte et classe les symboles par catégories"""
    
    def __init__(self):
        self.boom_crash_symbols = []
        self.volatility_symbols = []
        self.forex_symbols = []
        self.all_symbols = []
        
    def detect_symbols(self):
        """Détecte tous les symboles disponibles et les classe par catégories"""
        logger.info("🔍 Détection des symboles disponibles...")
        
        try:
            # Obtenir tous les symboles disponibles
            all_symbols = mt5.symbols_get()
            if not all_symbols:
                logger.error("❌ Impossible d'obtenir la liste des symboles")
                return False
            
            logger.info(f"📊 {len(all_symbols)} symboles trouvés")
            
            for symbol in all_symbols:
                symbol_name = symbol.name
                
                # Catégorie 1: Boom/Crash
                if "Boom" in symbol_name or "Crash" in symbol_name:
                    if symbol.visible and symbol.trade_mode in [1, 4]:  # Full ou Close-only
                        self.boom_crash_symbols.append(symbol_name)
                        logger.info(f"   🚀 Boom/Crash: {symbol_name}")
                
                # Catégorie 2: Volatility
                elif "Volatility" in symbol_name:
                    if symbol.visible and symbol.trade_mode in [1, 4]:
                        self.volatility_symbols.append(symbol_name)
                        logger.info(f"   📈 Volatility: {symbol_name}")
                
                # Catégorie 3: Forex (paires majeures)
                elif symbol.visible and symbol.trade_mode in [1, 4]:
                    # Détecter les paires forex majeures
                    forex_pairs = ["EUR", "GBP", "USD", "JPY", "AUD", "CAD", "CHF", "NZD"]
                    if any(pair in symbol_name for pair in forex_pairs):
                        self.forex_symbols.append(symbol_name)
                        logger.info(f"   💱 Forex: {symbol_name}")
            
            # Combiner toutes les catégories
            self.all_symbols = self.boom_crash_symbols + self.volatility_symbols + self.forex_symbols
            
            logger.info(f"✅ Détection terminée:")
            logger.info(f"   🚀 Boom/Crash: {len(self.boom_crash_symbols)} symboles")
            logger.info(f"   📈 Volatility: {len(self.volatility_symbols)} symboles")
            logger.info(f"   💱 Forex: {len(self.forex_symbols)} symboles")
            logger.info(f"   📊 Total: {len(self.all_symbols)} symboles")
            
            return len(self.all_symbols) > 0
            
        except Exception as e:
            logger.error(f"❌ Erreur détection symboles: {e}")
            return False
    
    def get_symbols_by_priority(self):
        """Retourne les symboles par ordre de priorité"""
        return self.all_symbols  # Déjà dans l'ordre: Boom/Crash → Volatility → Forex
    
    def get_category(self, symbol):
        """Retourne la catégorie d'un symbole"""
        if symbol in self.boom_crash_symbols:
            return "Boom/Crash"
        elif symbol in self.volatility_symbols:
            return "Volatility"
        elif symbol in self.forex_symbols:
            return "Forex"
        else:
            return "Unknown"

class DashboardLogger:
    """Affichage dashboard structuré dans les logs"""
    def __init__(self):
        self.last_update = 0
        
    def display_dashboard(self, positions, signals_data, symbol_detector):
        """Affiche un dashboard structuré toutes les 60 secondes"""
        current_time = time.time()
        if current_time - self.last_update < 60:  # Afficher toutes les 60 secondes
            return
            
        self.last_update = current_time
        
        print("\n" + "="*80)
        print("🤖 TRADING BOT DASHBOARD (DYNAMIC SYMBOLS)")
        print("="*80)
        
        # Section Positions
        print(f"\n📊 POSITIONS OUVERTES ({len(positions)}):")
        if positions:
            for symbol, pos_info in positions.items():
                profit = self.get_position_profit(pos_info["ticket"])
                profit_color = "🟢" if profit >= 0 else "🔴"
                category = symbol_detector.get_category(symbol)
                print(f"   {profit_color} {symbol} [{category}]: {pos_info['type']} | Ticket: {pos_info['ticket']} | P&L: ${profit:.2f}")
        else:
            print("   ✅ Aucune position ouverte")
        
        # Section Signaux récents par catégorie
        print(f"\n📡 SIGNAUX RÉCENTS PAR CATÉGORIE:")
        
        # Boom/Crash
        boom_signals = {k: v for k, v in signals_data.items() if k in symbol_detector.boom_crash_symbols and v}
        if boom_signals:
            print(f"   🚀 Boom/Crash:")
            for symbol, signal in boom_signals.items():
                if signal:
                    confidence = signal.get('confidence', 0)
                    direction = signal.get('signal', 'N/A')
                    color = "🟢" if confidence >= 80 else "🟡" if confidence >= 70 else "🔴"
                    print(f"      {color} {symbol}: {direction} | Confiance: {confidence:.1f}%")
                else:
                    print(f"      ⚪ {symbol}: Pas de signal")
        
        # Volatility
        vol_signals = {k: v for k, v in signals_data.items() if k in symbol_detector.volatility_symbols and v}
        if vol_signals:
            print(f"   📈 Volatility:")
            for symbol, signal in vol_signals.items():
                if signal:
                    confidence = signal.get('confidence', 0)
                    direction = signal.get('signal', 'N/A')
                    color = "🟢" if confidence >= 80 else "🟡" if confidence >= 70 else "🔴"
                    print(f"      {color} {symbol}: {direction} | Confiance: {confidence:.1f}%")
                else:
                    print(f"      ⚪ {symbol}: Pas de signal")
        
        # Forex
        forex_signals = {k: v for k, v in signals_data.items() if k in symbol_detector.forex_symbols and v}
        if forex_signals:
            print(f"   💱 Forex:")
            for symbol, signal in forex_signals.items():
                if signal:
                    confidence = signal.get('confidence', 0)
                    direction = signal.get('signal', 'N/A')
                    color = "🟢" if confidence >= 80 else "🟡" if confidence >= 70 else "🔴"
                    print(f"      {color} {symbol}: {direction} | Confiance: {confidence:.1f}%")
                else:
                    print(f"      ⚪ {symbol}: Pas de signal")
        
        # Section Compte
        account_info = mt5.account_info()
        if account_info:
            print(f"\n💰 COMPTE:")
            print(f"   Solde: ${account_info.balance:.2f}")
            print(f"   Equity: ${account_info.equity:.2f}")
            print(f"   Marge libre: ${account_info.margin_free:.2f}")
        
        # Section Performance du jour
        print(f"\n📈 PERFORMANCE:")
        today_profit = self.calculate_today_profit(positions)
        profit_color = "🟢" if today_profit >= 0 else "🔴"
        print(f"   {profit_color} Profit du jour: ${today_profit:.2f}")
        
        # Section Métriques ML
        print(f"\n🤖 MÉTRIQUES ML:")
        ml_metrics = self.get_ml_metrics()
        if ml_metrics:
            accuracy = ml_metrics.get('accuracy', 0)
            model_name = ml_metrics.get('modelName', 'Unknown')
            last_update = ml_metrics.get('lastUpdate', 0)
            accuracy_color = "🟢" if accuracy >= 0.8 else "🟡" if accuracy >= 0.7 else "🔴"
            print(f"   {accuracy_color} Précision: {accuracy*100:.1f}%")
            print(f"   📦 Modèle: {model_name}")
            if last_update > 0:
                time_diff = time.time() - last_update
                if time_diff < 300:
                    print(f"   ✅ Dernière MAJ: Il y a {int(time_diff)}s")
                else:
                    print(f"   ⚠️  Dernière MAJ: Il y a {int(time_diff/60)}min")
        else:
            print(f"   ❌ Métriques non disponibles")
        
        # Section Catégories
        print(f"\n📋 CATÉGORIES ACTIVES:")
        print(f"   🚀 Boom/Crash: {len(symbol_detector.boom_crash_symbols)} symboles")
        print(f"   📈 Volatility: {len(symbol_detector.volatility_symbols)} symboles")
        print(f"   💱 Forex: {len(symbol_detector.forex_symbols)} symboles")
        
        print("="*80)
    
    def get_position_profit(self, ticket):
        """Récupère le profit actuel d'une position"""
        position = mt5.positions_get(ticket=ticket)
        if position:
            return position[0].profit
        return 0.0
    
    def calculate_today_profit(self, positions):
        """Calcule le profit total des positions du jour"""
        total_profit = 0.0
        for pos_info in positions.values():
            profit = self.get_position_profit(pos_info["ticket"])
            total_profit += profit
        return total_profit
    
    def get_ml_metrics(self):
        """Récupère les métriques ML depuis l'API"""
        try:
            url = f"{RENDER_API_URL}/ml/metrics"
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                return response.json()
            else:
                return None
        except Exception as e:
            return None

# Instance globale du dashboard
dashboard = DashboardLogger()

class MT5AIClientDynamic:
    def __init__(self):
        self.connected = False
        self.positions = {}
        self.symbol_detector = SymbolDetector()
        
    def get_position_profit(self, ticket):
        """Récupère le profit actuel d'une position"""
        position = mt5.positions_get(ticket=ticket)
        if position:
            return position[0].profit
        return 0.0
    
    def get_ml_metrics(self):
        """Récupère les métriques ML depuis l'API"""
        try:
            url = f"{RENDER_API_URL}/ml/metrics"
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                return response.json()
            else:
                return None
        except Exception as e:
            return None
        
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
                
                # Détecter les symboles disponibles
                if not self.symbol_detector.detect_symbols():
                    logger.error("Aucun symbole détecté")
                    return False
                
                return True
                
            logger.error("Impossible de se connecter a MT5")
            return False
            
        except Exception as e:
            logger.error(f"Erreur connexion MT5: {e}")
            return False
    
    def get_ai_signal(self, symbol, timeframe="M1"):
        """Demande un signal de trading à l'IA"""
        try:
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                logger.warning(f"Pas de tick pour {symbol}")
                return None
            
            # Utiliser l'endpoint /predict/{symbol} avec GET
            url = f"{RENDER_API_URL}/predict/{symbol}"
            
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
    
    def calculate_smart_sltp(self, symbol, entry_price, order_type):
        """
        Calcule SL/TP proportionnels au prix
        SL = 2% du prix | TP = 4% du prix
        """
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            return None, None
        
        point = symbol_info.point
        digits = symbol_info.digits
        
        # Calculer les distances en prix selon le pourcentage
        sl_distance_price = entry_price * SL_PERCENTAGE
        tp_distance_price = entry_price * TP_PERCENTAGE
        
        # Convertir en points pour information
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
        
        logger.info(f"SL/TP calculés pour {symbol}: Entry={entry_price}, SL={sl} ({SL_PERCENTAGE*100:.0f}%), TP={tp} ({TP_PERCENTAGE*100:.0f}%)")
        
        return sl, tp
    
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
            
            # Récupérer la taille de position appropriée selon la catégorie
            category = self.symbol_detector.get_category(symbol)
            if category == "Boom/Crash":
                position_size = 0.2
            elif category == "Volatility":
                position_size = 0.1
            else:  # Forex
                position_size = 0.01
            
            # Préparer l'ordre
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Info symbole non disponible pour {symbol}")
                return False
            
            point = symbol_info.point
            tick = mt5.symbol_info_tick(symbol)
            
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
                "comment": f"Dynamic AI Signal {signal_data.get('source', 'unknown')} [{category}]",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_FOK,
            }
            
            # Logger les détails pour debug
            logger.info(f"Tentative ordre {signal} {symbol} [{category}]:")
            logger.info(f"  Entry: {entry_price}")
            logger.info(f"  SL: {sl} ({SL_PERCENTAGE*100:.0f}% du prix)")
            logger.info(f"  TP: {tp} ({TP_PERCENTAGE*100:.0f}% du prix)")
            logger.info(f"  Volume: {position_size}")
            logger.info(f"  Risk/Reward: 1:{TP_PERCENTAGE/SL_PERCENTAGE:.1f}")
            logger.info(f"  Type filling: {request['type_filling']} (FOK={mt5.ORDER_FILLING_FOK})")
            
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
                "open_time": datetime.now(),
                "signal_data": signal_data,
                "category": category
            }
            
            logger.info(f"✅ Ordre réussi: {signal} {symbol} [{category}] - Ticket: {result.order}")
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur execution trade {symbol}: {e}")
            return False
    
    def check_positions(self):
        """Vérifie les positions ouvertes et les ferme si nécessaire"""
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
                category = self.symbol_detector.get_category(pos.symbol)
                self.positions[pos.symbol] = {
                    "ticket": pos.ticket,
                    "symbol": pos.symbol,
                    "type": "BUY" if pos.type == mt5.POSITION_TYPE_BUY else "SELL",
                    "volume": pos.volume,
                    "price": pos.price_open,
                    "sl": pos.sl,
                    "tp": pos.tp,
                    "open_time": datetime.fromtimestamp(pos.time),
                    "profit": pos.profit,
                    "category": category
                }
                
        except Exception as e:
            logger.error(f"Erreur verification positions: {e}")
    
    def send_training_data(self):
        """Envoie les données récentes pour l'entraînement"""
        try:
            logger.info("Envoi des donnees d'entraînement...")
            
            # Envoyer les données pour chaque catégorie
            categories = [
                ("Boom/Crash", self.symbol_detector.boom_crash_symbols),
                ("Volatility", self.symbol_detector.volatility_symbols),
                ("Forex", self.symbol_detector.forex_symbols)
            ]
            
            for category_name, symbols in categories:
                if not symbols:
                    logger.info(f"   {category_name}: Aucun symbole")
                    continue
                
                logger.info(f"   📦 {category_name}: {len(symbols)} symboles")
                
                for symbol in symbols:
                    for timeframe in TIMEFRAMES:
                        # Récupérer les données récentes
                        tf_map = {
                            'M1': mt5.TIMEFRAME_M1,
                            'M5': mt5.TIMEFRAME_M5
                        }
                        
                        rates = mt5.copy_rates_from_pos(symbol, tf_map[timeframe], 0, 1000)
                        
                        # Corriger le problème avec les arrays NumPy
                        if rates is not None and len(rates) > 100:
                            # Convertir en format JSON
                            data_to_send = [
                                {
                                    "time": int(rate["time"]),
                                    "open": float(rate["open"]),
                                    "high": float(rate["high"]),
                                    "low": float(rate["low"]),
                                    "close": float(rate["close"]),
                                    "tick_volume": int(rate["tick_volume"])
                                }
                                for rate in rates
                            ]
                            
                            payload = {
                                "symbol": symbol,
                                "timeframe": timeframe,
                                "category": category_name,
                                "data": data_to_send
                            }
                            
                            # Envoyer à Render
                            response = requests.post(
                                f"{RENDER_API_URL}/mt5/history-upload",
                                json=payload,
                                timeout=60
                            )
                            
                            if response.status_code == 200:
                                logger.info(f"      ✅ {symbol} {timeframe}")
                            else:
                                logger.warning(f"      ❌ Erreur {symbol} {timeframe}: {response.status_code}")
            
            logger.info("Envoi des donnees termine")
            
        except Exception as e:
            logger.error(f"Erreur envoi donnees: {e}")
    
    def run(self):
        """Boucle principale du client"""
        logger.info("🚀 Demarrage du client MT5 AI Dynamic Symbols")
        
        if not self.connect_mt5():
            return
        
        last_training_time = 0
        
        try:
            while True:
                try:
                    # Vérifier les positions existantes
                    self.check_positions()
                    
                    # Envoyer les données d'entraînement toutes les heures
                    current_time = time.time()
                    if current_time - last_training_time > 3600:  # 1 heure
                        self.send_training_data()
                        last_training_time = current_time
                    
                    # Demander des signaux pour chaque symbole détecté
                    signals_data = {}
                    symbols_to_monitor = self.symbol_detector.get_symbols_by_priority()
                    
                    for symbol in symbols_to_monitor:
                        if symbol not in self.positions:  # Seulement si pas de position
                            signal_data = self.get_ai_signal(symbol)
                            signals_data[symbol] = signal_data
                            
                            if signal_data:
                                self.execute_trade(symbol, signal_data)
                    
                    # Afficher le dashboard
                    dashboard.display_dashboard(self.positions, signals_data, self.symbol_detector)
                    
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
    client = MT5AIClientDynamic()
    client.run()
