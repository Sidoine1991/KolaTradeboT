#!/usr/bin/env python3
"""
Module d'exécution automatique des signaux pour MetaTrader 5
Ce module surveille l'API de signaux et exécute automatiquement les ordres sur MT5

⚠️ SYSTÈME DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 pour l'exécution automatique
"""

# ===================================================================
# SYSTÈME D'EXÉCUTION AUTOMATIQUE DÉSACTIVÉ
# Ce fichier est désactivé - Le système unique d'exécution est maintenant
# centralisé dans l'EA MQL5 AngelOfSpike.mq5 avec probabilité M1
# ===================================================================

DISABLED = True  # SYSTÈME DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 uniquement

if DISABLED:
    print("⚠️ SYSTÈME PYTHON DÉSACTIVÉ - Utiliser AngelOfSpike.mq5 pour l'exécution automatique")
    print("🎯 Système unifié: Probabilité M1 >= 85% pour exécution automatique")
    print("🚫 Interdiction totale des trades multiples")
    exit()

# Code original désactivé ci-dessous...

import json
import time
import threading
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import logging
import os
import sys

# Ajouter le répertoire racine au PYTHONPATH
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

try:
    from backend.mt5_connector import connect, is_connected, send_order_to_mt5, get_current_price
    from backend.mt5_order_utils import place_order_mt5
    from backend.risk_manager import RiskManager
    MT5_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ MT5 non disponible: {e}")
    MT5_AVAILABLE = False

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AutoSignalExecutor:
    """Exécuteur automatique de signaux pour MT5"""
    
    def __init__(self, 
                 signal_api_url: str = "http://localhost:8001",
                 check_interval: int = 5,
                 max_risk_per_trade: float = 0.02,  # 2% du capital par trade
                 min_confidence: float = 0.7,      # Confiance minimale requise
                 max_daily_trades: int = 10,       # Nombre max de trades par jour
                 enabled: bool = True,
                 account_balance: float = 1000.0,
                 max_abs_risk_usd: float = None,
                 cooldown_seconds: int = 180,
                 spike_tp_rr: float = 1.0):
        
        self.signal_api_url = signal_api_url
        self.check_interval = check_interval
        self.max_risk_per_trade = max_risk_per_trade
        self.min_confidence = min_confidence
        self.max_daily_trades = max_daily_trades
        self.enabled = enabled
        # Contrainte de risque absolu (USD). Si non précisé, dérivé de max_risk_per_trade et du solde.
        self.account_balance = account_balance
        self.max_abs_risk_usd = (
            max_abs_risk_usd if max_abs_risk_usd is not None else max(1.0, self.account_balance * self.max_risk_per_trade)
        )
        # Sécurité opérationnelle
        self.cooldown_seconds = cooldown_seconds
        self.spike_tp_rr = spike_tp_rr
        
        # État de l'exécuteur
        self.running = False
        self.executed_signals = set()  # IDs des signaux déjà exécutés
        self.daily_trades = 0
        self.last_reset_date = datetime.now().date()
        self.last_trade_time_by_symbol: Dict[str, datetime] = {}
        
        # Gestionnaire de risque
        self.risk_manager = RiskManager(account_balance=self.account_balance) if MT5_AVAILABLE else None
        
        # Configuration de trading
        self.trading_config = {
            'default_lot_size': 0.01,
            'max_lot_size': 1.0,
            'min_lot_size': 0.01,
            'slippage_tolerance': 3,  # pips
            'max_spread': 5,  # pips
        }
        
        logger.info(f"🤖 AutoSignalExecutor initialisé - API: {signal_api_url}")
        logger.info(f"📊 Configuration: Risk={max_risk_per_trade*100}%, MinConf={min_confidence*100}%, MaxTrades={max_daily_trades}")
        logger.info(f"💵 Solde: {self.account_balance} USD, Perte max/trade: {self.max_abs_risk_usd} USD")
        logger.info(f"🧊 Cooldown: {self.cooldown_seconds}s, Spike TP: {self.spike_tp_rr}R")
    
    def start(self):
        """Démarrer l'exécuteur automatique"""
        if not MT5_AVAILABLE:
            logger.error("❌ MT5 non disponible - impossible de démarrer l'exécuteur")
            return False
        
        if not self.enabled:
            logger.warning("⚠️ Exécuteur désactivé")
            return False
        
        if not self._connect_mt5():
            logger.error("❌ Impossible de se connecter à MT5")
            return False
        
        self.running = True
        self._reset_daily_counters()
        
        # Démarrer le thread de surveillance
        self.monitor_thread = threading.Thread(target=self._monitor_signals, daemon=True)
        self.monitor_thread.start()
        
        logger.info("🚀 Exécuteur automatique démarré")
        return True
    
    def stop(self):
        """Arrêter l'exécuteur automatique"""
        self.running = False
        logger.info("🛑 Exécuteur automatique arrêté")
    
    def _connect_mt5(self) -> bool:
        """Se connecter à MT5"""
        try:
            if not is_connected():
                result = connect()
                if not result:
                    logger.error("❌ Échec de connexion à MT5")
                    return False
            
            logger.info("✅ Connecté à MT5")
            return True
        except Exception as e:
            logger.error(f"❌ Erreur connexion MT5: {e}")
            return False
    
    def _reset_daily_counters(self):
        """Réinitialiser les compteurs quotidiens"""
        today = datetime.now().date()
        if today != self.last_reset_date:
            self.daily_trades = 0
            self.last_reset_date = today
            logger.info("📅 Compteurs quotidiens réinitialisés")
    
    def _monitor_signals(self):
        """Thread principal de surveillance des signaux"""
        logger.info("👁️ Surveillance des signaux démarrée")
        
        while self.running:
            try:
                self._reset_daily_counters()
                
                # Vérifier si on peut encore trader aujourd'hui
                if self.daily_trades >= self.max_daily_trades:
                    logger.info(f"📊 Limite quotidienne atteinte ({self.max_daily_trades} trades)")
                    time.sleep(60)  # Attendre 1 minute avant de revérifier
                    continue
                
                # Récupérer les nouveaux signaux
                signals = self._fetch_signals()
                if signals:
                    self._process_signals(signals)
                
                time.sleep(self.check_interval)
                
            except Exception as e:
                logger.error(f"❌ Erreur dans la surveillance: {e}")
                time.sleep(10)  # Attendre avant de réessayer
    
    def _fetch_signals(self) -> List[Dict]:
        """Récupérer les signaux depuis l'API"""
        try:
            response = requests.get(f"{self.signal_api_url}/signals", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data.get('signals', [])
            else:
                logger.warning(f"⚠️ API signaux indisponible: {response.status_code}")
                return []
        except Exception as e:
            logger.error(f"❌ Erreur récupération signaux: {e}")
            return []
    
    def _process_signals(self, signals: List[Dict]):
        """Traiter les signaux reçus"""
        for signal in signals:
            try:
                # Vérifier si le signal est déjà exécuté
                signal_id = self._get_signal_id(signal)
                if signal_id in self.executed_signals:
                    continue
                
                # Valider le signal
                if not self._validate_signal(signal):
                    continue
                
                # Filtrer: ne trader que BOOM/CRASH
                symu = signal.get('symbol', '').upper()
                if not ('BOOM' in symu or 'CRASH' in symu):
                    logger.debug(f"⏭️ Symbole ignoré (non BOOM/CRASH): {symu}")
                    continue

                # Cooldown par symbole
                now = datetime.now()
                last_t = self.last_trade_time_by_symbol.get(symu)
                if last_t and (now - last_t).total_seconds() < self.cooldown_seconds:
                    logger.debug(f"🧊 Cooldown actif pour {symu}, on saute ce signal")
                    continue

                # Exécuter l'ordre
                success = self._execute_signal(signal)
                if success:
                    self.executed_signals.add(signal_id)
                    self.daily_trades += 1
                    self.last_trade_time_by_symbol[symu] = datetime.now()
                    logger.info(f"✅ Signal exécuté: {signal['symbol']} {signal['side']}")
                
            except Exception as e:
                logger.error(f"❌ Erreur traitement signal: {e}")
    
    def _get_signal_id(self, signal: Dict) -> str:
        """Générer un ID unique pour le signal"""
        return f"{signal['symbol']}_{signal['side']}_{signal['ts']}_{signal['price']}"
    
    def _validate_signal(self, signal: Dict) -> bool:
        """Valider un signal avant exécution"""
        try:
            # Vérifier la confiance
            if signal.get('confidence', 0) < self.min_confidence:
                logger.debug(f"⚠️ Signal rejeté - confiance trop faible: {signal.get('confidence', 0)}")
                return False
            
            # Vérifier la validité temporelle
            valid_from = datetime.fromisoformat(signal.get('valid_from', ''))
            valid_to = datetime.fromisoformat(signal.get('valid_to', ''))
            now = datetime.now()
            
            if now < valid_from or now > valid_to:
                logger.debug(f"⚠️ Signal expiré: {signal['symbol']}")
                return False
            
            # Vérifier le symbole
            symbol = signal.get('symbol', '')
            if not symbol:
                logger.debug("⚠️ Signal sans symbole")
                return False
            symbol_upper = symbol.upper()
            
            # Vérifier la direction
            side = signal.get('side', '').upper()
            if side not in ['BUY', 'SELL']:
                logger.debug(f"⚠️ Direction invalide: {side}")
                return False

            # Bloquer SELL sur Boom et BUY sur Crash
            if ('BOOM' in symbol_upper and side == 'SELL') or ('CRASH' in symbol_upper and side == 'BUY'):
                logger.info(f"🚫 Signal contre-tendance bloqué: {symbol} {side}")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Erreur validation signal: {e}")
            return False
    
    def _execute_signal(self, signal: Dict) -> bool:
        """Exécuter un signal sur MT5"""
        try:
            symbol = signal['symbol']
            orig_side = signal['side'].upper()
            side = orig_side
            # Forcer sens: BOOM => BUY, CRASH => SELL
            su = symbol.upper()
            if 'BOOM' in su:
                side = 'BUY'
            elif 'CRASH' in su:
                side = 'SELL'
            entry_price = float(signal['price'])
            sl_price = float(signal.get('sl', 0) or 0)
            tp_price = float(signal.get('tp', 0) or 0)
            confidence = float(signal.get('confidence', 0))
            
            # Déterminer SL/TP défauts si absents, puis calculer lot pour risque max absolu
            sl_price, tp_price, lot_size = self._prepare_order_with_risk_controls(
                symbol=symbol,
                side=side,
                entry_price=entry_price,
                sl_price=sl_price,
                tp_price=tp_price,
                confidence=confidence,
                max_abs_loss_usd=self.max_abs_risk_usd
            )
            if lot_size <= 0:
                logger.warning(f"⚠️ Taille de position invalide: {lot_size}")
                return False
            
            # Vérifier le spread
            if not self._check_spread(symbol):
                logger.warning(f"⚠️ Spread trop élevé pour {symbol}")
                return False
            
            # Exécuter l'ordre
            success, message = place_order_mt5(
                symbol=symbol,
                order_type=side,
                lot=lot_size,
                price=entry_price,
                sl=sl_price if sl_price > 0 else None,
                tp=tp_price if tp_price > 0 else None
            )
            
            if success:
                logger.info(f"🎯 Ordre exécuté: {symbol} {side} {lot_size} lots @ {entry_price}")
                if sl_price > 0:
                    logger.info(f"🛡️ Stop Loss: {sl_price}")
                if tp_price > 0:
                    logger.info(f"🎯 Take Profit: {tp_price}")
                return True
            else:
                logger.error(f"❌ Échec ordre: {message}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Erreur exécution signal: {e}")
            return False

    def _prepare_order_with_risk_controls(
        self,
        symbol: str,
        side: str,
        entry_price: float,
        sl_price: float,
        tp_price: float,
        confidence: float,
        max_abs_loss_usd: float,
    ) -> Tuple[float, float, float]:
        """
        - Définit SL/TP par défaut si manquants
        - Calcule la taille de lot pour respecter la perte max absolue (USD)
        - Si lot < min_lot, élargit SL pour respecter la contrainte tout en utilisant min_lot
        Retourne: (sl_price, tp_price, lot)
        """
        try:
            import MetaTrader5 as mt5  # type: ignore
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                # Fallback: garder SL/TP donnés et lot par défaut
                return self._fallback_sl_tp_lot(side, entry_price, sl_price, tp_price, confidence)

            point = symbol_info.point
            min_lot = symbol_info.volume_min
            max_lot = symbol_info.volume_max
            lot_step = symbol_info.volume_step
            tick_value = (
                symbol_info.trade_tick_value if hasattr(symbol_info, 'trade_tick_value') and symbol_info.trade_tick_value > 0
                else point
            )

            # 1) SL défaut si absent: 100 points
            if sl_price <= 0:
                sl_distance_points = max(100.0, 100.0)  # 100 points
                if side == 'BUY':
                    sl_price = entry_price - sl_distance_points * point
                else:
                    sl_price = entry_price + sl_distance_points * point

            # 2) TP défaut si absent: spike_tp_rr R
            if tp_price <= 0 and sl_price > 0:
                dist = abs(entry_price - sl_price)
                rr = max(0.5, float(self.spike_tp_rr))
                if side == 'BUY':
                    tp_price = entry_price + rr * dist
                else:
                    tp_price = entry_price - rr * dist

            # 3) Calcul lot pour respecter max_abs_loss_usd
            sl_distance_points = abs(entry_price - sl_price) / point if point > 0 else 0
            if sl_distance_points <= 0 or tick_value <= 0:
                return self._fallback_sl_tp_lot(side, entry_price, sl_price, tp_price, confidence)

            lot = max_abs_loss_usd / (sl_distance_points * tick_value)
            # Ajuster par la confiance (limite x2)
            confidence_multiplier = min(2.0, max(0.5, confidence / 0.5))
            lot = lot * confidence_multiplier

            # Appliquer bornes et pas de lot
            def round_to_step(value: float, step: float) -> float:
                if step <= 0:
                    return value
                return round(value / step) * step

            lot = round_to_step(lot, lot_step)
            if lot < min_lot:
                # Utiliser min_lot et ajuster SL pour respecter la perte max USD
                lot = min_lot
                needed_points = max_abs_loss_usd / (tick_value * lot) if tick_value > 0 else sl_distance_points
                # Ajuster sl_price selon le sens
                if side == 'BUY':
                    sl_price = entry_price - needed_points * point
                else:
                    sl_price = entry_price + needed_points * point
                # Recalculer TP en 1.5R
                dist = abs(entry_price - sl_price)
                rr = max(0.5, float(self.spike_tp_rr))
                if side == 'BUY':
                    tp_price = entry_price + rr * dist
                else:
                    tp_price = entry_price - rr * dist

            if lot > max_lot:
                lot = max_lot

            # Clamp et arrondi final
            lot = max(min_lot, min(max_lot, lot))
            lot = round(lot, 2)
            return sl_price, tp_price, lot
        except Exception:
            return self._fallback_sl_tp_lot(side, entry_price, sl_price, tp_price, confidence)

    def _fallback_sl_tp_lot(
        self,
        side: str,
        entry_price: float,
        sl_price: float,
        tp_price: float,
        confidence: float,
    ) -> Tuple[float, float, float]:
        # SL défaut si absent
        if sl_price <= 0:
            # 1% du prix comme SL approx si pas d'info broker
            dist = entry_price * 0.01
            sl_price = entry_price - dist if side == 'BUY' else entry_price + dist
        # TP défaut si absent
        if tp_price <= 0 and sl_price > 0:
            dist = abs(entry_price - sl_price)
            rr = max(0.5, float(self.spike_tp_rr))
            tp_price = entry_price + rr * dist if side == 'BUY' else entry_price - rr * dist
        # Lot par confiance sur base 0.01
        base_lot = self.trading_config['default_lot_size']
        mult = min(2.0, max(0.5, confidence / 0.5))
        return sl_price, tp_price, round(base_lot * mult, 2)
    
    def _calculate_position_size(self, symbol: str, entry_price: float, sl_price: float, confidence: float) -> float:
        """Calculer la taille de position basée sur le risque"""
        try:
            # Taille de base
            base_lot = self.trading_config['default_lot_size']
            
            # Ajustement basé sur la confiance
            confidence_multiplier = min(2.0, confidence / 0.5)  # Max 2x pour confiance > 0.5
            
            # Calcul du risque
            if sl_price > 0:
                risk_pips = abs(entry_price - sl_price) * 10000  # Convertir en pips
                if risk_pips > 0:
                    # Ajuster la taille selon le risque
                    risk_multiplier = min(1.0, 50 / risk_pips)  # Réduire si risque > 50 pips
                    lot_size = base_lot * confidence_multiplier * risk_multiplier
                else:
                    lot_size = base_lot * confidence_multiplier
            else:
                lot_size = base_lot * confidence_multiplier
            
            # Appliquer les limites
            lot_size = max(self.trading_config['min_lot_size'], 
                          min(self.trading_config['max_lot_size'], lot_size))
            
            # Arrondir à 2 décimales
            return round(lot_size, 2)
            
        except Exception as e:
            logger.error(f"❌ Erreur calcul taille position: {e}")
            return self.trading_config['default_lot_size']
    
    def _check_spread(self, symbol: str) -> bool:
        """Vérifier si le spread est acceptable"""
        try:
            # Récupérer les informations du symbole
            import MetaTrader5 as mt5
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                return False
            
            spread = symbol_info.spread
            return spread <= self.trading_config['max_spread']
            
        except Exception as e:
            logger.error(f"❌ Erreur vérification spread: {e}")
            return True  # Accepter par défaut
    
    def get_status(self) -> Dict:
        """Obtenir le statut de l'exécuteur"""
        return {
            'running': self.running,
            'enabled': self.enabled,
            'daily_trades': self.daily_trades,
            'max_daily_trades': self.max_daily_trades,
            'executed_signals_count': len(self.executed_signals),
            'mt5_connected': is_connected() if MT5_AVAILABLE else False,
            'last_reset_date': self.last_reset_date.isoformat()
        }
    
    def update_config(self, **kwargs):
        """Mettre à jour la configuration"""
        for key, value in kwargs.items():
            if hasattr(self, key):
                setattr(self, key, value)
                logger.info(f"📝 Configuration mise à jour: {key} = {value}")


def main():
    """Fonction principale pour tester l'exécuteur"""
    print("🤖 Test de l'exécuteur automatique de signaux")
    print("=" * 50)
    
    # Créer l'exécuteur
    executor = AutoSignalExecutor(
        signal_api_url="http://localhost:8001",
        check_interval=10,  # Vérifier toutes les 10 secondes
        max_risk_per_trade=0.01,  # 1% de risque par trade
        min_confidence=0.8,  # 80% de confiance minimum
        max_daily_trades=5,  # Max 5 trades par jour
        enabled=True
    )
    
    try:
        # Démarrer l'exécuteur
        if executor.start():
            print("✅ Exécuteur démarré avec succès")
            print("📊 Statut:", executor.get_status())
            
            # Attendre indéfiniment
            while True:
                time.sleep(60)
                status = executor.get_status()
                print(f"📈 Statut: {status['daily_trades']}/{status['max_daily_trades']} trades aujourd'hui")
        else:
            print("❌ Impossible de démarrer l'exécuteur")
    
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")
        executor.stop()
    except Exception as e:
        print(f"❌ Erreur: {e}")
        executor.stop()


if __name__ == "__main__":
    main()
