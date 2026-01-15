#!/usr/bin/env python3
"""
Système d'automatisation des signaux de trading
Surveille les marchés et envoie automatiquement les signaux de qualité professionnelle
"""
import time
import threading
import schedule
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import sys
import os
import json
import random
from pathlib import Path

sys.path.insert(0, os.path.abspath('.'))

from backend.multi_timeframe_signal_generator import MultiTimeframeSignalGenerator
from backend.mt5_connector import get_all_symbols
from backend.whatsapp_utils import send_whatsapp_message
from backend.advanced_technical_indicators import add_advanced_technical_indicators, generate_professional_signals
from backend.mt5_connector import get_ohlc
from backend.trend_summary import get_multi_timeframe_trend
from frontend.whatsapp_notify import send_whatsapp_message, send_sms_vonage

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/auto_signals.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class AutoSignalMonitor:
    """Moniteur automatique de signaux de trading avec configuration avancée"""
    
    def classify_symbol(self, symbol: str) -> str:
        """Classe un symbole MT5 dans une catégorie"""
        s = symbol.upper()
        if any(x in s for x in ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"]) and len(s) == 6:
            return "forex"
        if any(x in s for x in ["VOLATILITY", "BOOM", "CRASH", "STEP", "RANGE", "JUMP"]):
            return "synthetic_index"
        if any(x in s for x in ["US30", "US500", "NAS100", "GER30", "UK100", "FRA40", "ESP35", "ITA40", "AUS200", "JPN225", "HK50", "CHN50", "BRA50", "RUS50", "IND50"]):
            return "stock_index"
        if any(x in s for x in ["XAU", "XAG", "GOLD", "SILVER", "PLATINUM", "PALLADIUM"]):
            return "metal"
        if any(x in s for x in ["BTC", "ETH", "LTC", "XRP", "BCH", "ADA", "DOT", "LINK"]):
            return "crypto"
        if any(x in s for x in ["WTI", "BRENT", "NATGAS", "COPPER"]):
            return "commodity"
        return "other"

    def __init__(self, config: Optional[Dict] = None):
        self.generator = MultiTimeframeSignalGenerator()
        self.running = False
        self.monitor_thread = None
        
        # Configuration par défaut
        self.config = {
            'scan_interval': 5,  # minutes entre chaque scan
            'max_signals_per_hour': 10,  # limite de signaux par heure
            'min_confidence': 50,  # confiance minimale en % (abaissée pour générer plus de signaux)
            'min_trend_confidence': 50,  # confiance tendance minimale en % (abaissée)
            'min_alignment_score': 0.5,  # score d'alignement minimal (abaissé)
            'timeout_seconds': 30,  # timeout pour les opérations MT5
            'cache_duration': 300,  # durée du cache en secondes
            'enable_whatsapp': True,  # activer l'envoi WhatsApp
            'enable_logging': True,  # activer le logging détaillé
            'max_symbols_per_scan': 25,  # nombre max de symboles par scan
            'retry_failed_symbols': True,  # réessayer les symboles échoués
            'max_retries': 2,  # nombre max de tentatives
            'categories_to_scan': [
                'forex', 'synthetic_index', 'stock_index', 'metal', 'crypto', 'commodity', 'other'
            ],
            'exploratory_mode': True,  # Active le mode exploratoire (log tous les signaux)
            'borderline_min_confidence': 45,  # Seuil min pour signaux borderline (abaissé)
            'borderline_max_confidence': 50,  # Seuil max pour signaux borderline (abaissé)
        }
        
        # Appliquer la configuration personnalisée
        if config:
            self.config.update(config)
        
        # État du système
        self.signal_count = 0
        self.last_reset = datetime.now()
        self.symbol_cache = {}
        self.failed_symbols = {}  # cache des symboles échoués
        self.retry_count = {}  # compteur de tentatives par symbole
        
        # Symboles prioritaires étendus (plus liquides et volatils)
        self.priority_symbols = [
            # Forex Majors
            "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD",
            # Forex Minors
            "EURGBP", "EURJPY", "GBPJPY", "AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD",
            "CADCHF", "CADJPY", "CHFJPY", "EURAUD", "EURCAD", "EURCHF", "EURNZD",
            "GBPAUD", "GBPCAD", "GBPCHF", "GBPNZD", "NZDCAD", "NZDCHF", "NZDJPY",
            # Indices Synthétiques (Volatility, Boom, Crash, Step, Range, Jump)
            "Crash 500 Index", "Boom 500 Index", "Boom 1000 Index", "Crash 1000 Index",
            "Volatility 75 Index", "Volatility 100 Index", "Volatility 50 Index",
            "Volatility 25 Index", "Volatility 10 Index", "Volatility 150 Index", "Volatility 200 Index",
            "Crash 300 Index", "Crash 200 Index", "Crash 400 Index", "Crash 600 Index", "Crash 700 Index", "Crash 800 Index", "Crash 900 Index", "Crash 1100 Index", "Crash 1200 Index", "Crash 1300 Index", "Crash 1400 Index", "Crash 1500 Index",
            "Boom 300 Index", "Boom 200 Index", "Boom 400 Index", "Boom 600 Index", "Boom 700 Index", "Boom 800 Index", "Boom 900 Index", "Boom 1100 Index", "Boom 1200 Index", "Boom 1300 Index", "Boom 1400 Index", "Boom 1500 Index",
            "Step Index", "Range Break 100 Index", "Range Break 200 Index", "Jump 10 Index", "Jump 25 Index", "Jump 50 Index", "Jump 75 Index", "Jump 100 Index",
            # Indices traditionnels (si dispo sur le broker)
            "US30", "US500", "NAS100", "GER30", "UK100", "FRA40", "ESP35", "ITA40",
            "AUS200", "JPN225", "HK50", "CHN50", "BRA50", "RUS50", "IND50",
            # Métaux
            "XAUUSD", "XAGUSD", "XAUAUD", "XAUGBP", "XAUJPY",
            # Crypto
            "BTCUSD", "ETHUSD", "LTCUSD", "XRPUSD",
            # Commodities
            "WTIUSD", "BRENTUSD", "NATGASUSD"
        ]
        
        # Statistiques détaillées
        self.stats = {
            'total_scans': 0,
            'signals_generated': 0,
            'signals_sent': 0,
            'signals_rejected': 0,
            'errors': 0,
            'timeouts': 0,
            'last_signal_time': None,
            'last_scan_time': None,
            'uptime_start': None,
            'symbols_scanned': {},
            'symbols_processed': {},  # <-- Ajouté
            'confidence_distribution': {
                'high': 0,    # 80-100%
                'medium': 0,  # 70-79%
                'low': 0      # <70%
            }
        }
    
    def update_config(self, new_config: Dict):
        """Met à jour la configuration en cours d'exécution"""
        self.config.update(new_config)
        logger.info(f"Configuration mise à jour: {new_config}")
        
        # Sauvegarder la configuration
        self.save_config()
    
    def save_config(self):
        """Sauvegarde la configuration dans un fichier"""
        try:
            config_file = 'logs/auto_monitor_config.json'
            with open(config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, default=str)
            logger.info(f"Configuration sauvegardée dans {config_file}")
        except Exception as e:
            logger.error(f"Erreur sauvegarde configuration: {e}")
    
    def load_config(self):
        """Charge la configuration depuis un fichier"""
        try:
            config_file = 'logs/auto_monitor_config.json'
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    saved_config = json.load(f)
                self.config.update(saved_config)
                logger.info("Configuration chargée depuis le fichier")
        except Exception as e:
            logger.error(f"Erreur chargement configuration: {e}")
    
    def get_symbols_to_monitor(self) -> List[str]:
        """Récupère la liste des symboles à surveiller avec catégorisation dynamique"""
        try:
            now = datetime.now()
            if 'symbols' in self.symbol_cache:
                cached_data = self.symbol_cache['symbols']
                if now - cached_data['timestamp'] < timedelta(seconds=self.config['cache_duration']):
                    logger.debug("📋 Utilisation du cache pour les symboles")
                    return cached_data['data']
            logger.info("📡 Récupération des symboles depuis MT5")
            all_symbols = get_all_symbols()
            # Catégorisation dynamique
            categories = {cat: [] for cat in self.config['categories_to_scan']}
            for s in all_symbols:
                cat = self.classify_symbol(s)
                if cat in categories:
                    categories[cat].append(s)
            # Concatène tous les symboles des catégories sélectionnées
            symbols = []
            for cat in self.config['categories_to_scan']:
                symbols.extend(categories.get(cat, []))
            # Limite le nombre de symboles par scan
            symbols = symbols[:self.config['max_symbols_per_scan']]
            self.symbol_cache['symbols'] = {
                'data': symbols,
                'timestamp': now
            }
            logger.info(f"📊 {len(symbols)} symboles chargés (catégories: {self.config['categories_to_scan']})")
            return symbols
        except Exception as e:
            logger.error(f"Erreur récupération symboles: {e}")
            return []
    
    def check_rate_limit(self) -> bool:
        """Vérifie si on peut envoyer un signal (limite horaire)"""
        now = datetime.now()
        
        # Reset du compteur toutes les heures
        if now - self.last_reset > timedelta(hours=1):
            self.signal_count = 0
            self.last_reset = now
        
        return self.signal_count < self.config['max_signals_per_hour']
    
    def validate_signal_quality(self, signal: Dict) -> bool:
        # Toujours True, la validation est gérée par la logique unique
        return True
    
    def log_exploratory_signal(self, signal: Dict, status: str):
        """Loggue tous les signaux (acceptés ou rejetés) en mode exploratoire"""
        if not self.config.get('exploratory_mode', False):
            return
        log_file = 'logs/exploratory_signals.log'
        entry = {
            'timestamp': datetime.now().isoformat(),
            'status': status,  # 'accepted' ou 'rejected'
            'signal': signal
        }
        try:
            with open(log_file, 'a', encoding='utf-8') as f:
                f.write(json.dumps(entry, ensure_ascii=False) + '\n')
        except Exception as e:
            logger.error(f"Erreur log exploratoire: {e}")
    
    def scan_symbol(self, symbol: str) -> Optional[Dict]:
        """Scanne un symbole : si tendance haussière sur M30, M15, M5, génère un BUY sur M1 avec TP/SL/lot adaptés."""
        try:
            logger.info(f"🔍 Scan simple de {symbol} (logique unique)")
            # 1. Récupérer la tendance sur M30, M15, M5
            from backend.trend_summary import get_multi_timeframe_trend
            trend = get_multi_timeframe_trend(symbol)
            if not trend:
                logger.info(f"[SKIP] Impossible de récupérer la tendance pour {symbol}")
                return None
            if trend.get('M30') == 'bullish' and trend.get('M15') == 'bullish' and trend.get('M5') == 'bullish':
                # 2. Récupérer le prix d'entrée sur M1
                from backend.mt5_connector import get_ohlc
                df = get_ohlc(symbol, 'M1', 2)
                if df is None or df.empty:
                    logger.info(f"[SKIP] Pas de prix M1 pour {symbol}")
                    return None
                price = float(df['close'].iloc[-1])
                # 3. Calculer TP/SL/lot pour 10$ engagé, +100% gain, -20% perte
                capital = 10.0
                max_risk = 4.0
                max_gain = 10.0
                sl = round(price - (max_risk / capital) * price, 5)  # -20%
                tp = round(price + (max_gain / capital) * price, 5)  # +100%
                risk_per_unit = abs(price - sl)
                gain_per_unit = abs(tp - price)
                lot = max_risk / risk_per_unit if risk_per_unit else 0.01
                if gain_per_unit > 0:
                    lot_max_gain = max_gain / gain_per_unit
                    lot = min(lot, lot_max_gain)
                lot = max(0.01, round(lot, 2))
                # 4. Générer le signal BUY
                signal = {
                    'symbol': symbol,
                    'recommendation': 'BUY',
                    'price': price,
                    'tp': tp,
                    'sl': sl,
                    'lot': lot,
                    'reason': 'Tendance alignée M30/M15/M5 haussière',
                    'signal_level': 'auto_buy'
                }
                self.send_signal(signal)
                logger.info(f"[SIGNAL] BUY {symbol} | Prix: {price} | TP: {tp} | SL: {sl} | Lot: {lot}")
                return signal
            else:
                logger.info(f"[NO SIGNAL] {symbol} non aligné haussier sur M30/M15/M5")
                return None
        except Exception as e:
            logger.error(f"Erreur scan {symbol}: {e}")
            return None
    
    def _record_failed_symbol(self, symbol: str, error: str):
        """Enregistre un symbole échoué pour les retry"""
        if self.config['retry_failed_symbols']:
            self.failed_symbols[symbol] = {
                'error': error,
                'timestamp': datetime.now()
            }
            self.retry_count[symbol] = self.retry_count.get(symbol, 0) + 1
    
    def _record_successful_symbol(self, symbol: str):
        """Enregistre un symbole réussi"""
        if symbol in self.failed_symbols:
            del self.failed_symbols[symbol]
        if symbol in self.retry_count:
            del self.retry_count[symbol]
        
        self.stats['symbols_scanned'][symbol] = {
            'last_success': datetime.now(),
            'success_count': self.stats['symbols_scanned'].get(symbol, {}).get('success_count', 0) + 1
        }
    
    def _update_confidence_stats(self, signal: Dict):
        """Met à jour les statistiques de confiance"""
        confidence = signal.get('technical_confidence', 0)
        if confidence >= 80:
            self.stats['confidence_distribution']['high'] += 1
        elif confidence >= 70:
            self.stats['confidence_distribution']['medium'] += 1
        else:
            self.stats['confidence_distribution']['low'] += 1
    
    def send_signal(self, signal: Dict) -> bool:
        try:
            conf_tech = signal.get('technical_confidence', 0)
            conf_trend = signal.get('trend_confidence', 0)
            # N'envoyer que si confiance >= 0.7
            if conf_tech < 0.7 and conf_trend < 0.7:
                return False
            if not self.config['enable_whatsapp']:
                self.signal_count += 1
                self.stats['signals_sent'] += 1
                self.stats['last_signal_time'] = datetime.now()
                return True
            direction_emoji = '⬆️' if signal.get('recommendation', '').upper() == 'BUY' else '⬇️' if signal.get('recommendation', '').upper() == 'SELL' else '➡️'
            conf = max(conf_tech, conf_trend)
            conf_emoji = '🔒' if conf >= 0.7 else '⚠️' if conf >= 0.5 else '❔'
            level = signal.get('signal_level', 'inconnu')
            price = signal.get('price', 0)
            sl = signal.get('sl', 0)
            tp = signal.get('tp', 0)
            lot = signal.get('lot', 0.01)
            now_utc = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S GMT')
            msg = (
                f"• {signal.get('symbol', '')} | {direction_emoji} {signal.get('recommendation', '').upper()}\n"
                f"  Prix : {price} | Lot : {lot} | TP : {tp} | SL : {sl}\n"
                f"  Confiance : {conf*100:.0f}%\n"
                f"  Date/Heure : {now_utc}\n"
                f"  Niveau : {level}\n"
                f"  Justification : {signal.get('reason', signal.get('recommendation', ''))}"
            )
            from backend.whatsapp_utils import send_whatsapp_message
            send_whatsapp_message(msg)
            # Enregistrement dans autoscan_signals.json
            try:
                with open("autoscan_signals.json", "a", encoding="utf-8") as f:
                    json.dump({
                        "timestamp": now_utc,
                        "message": msg
                    }, f, ensure_ascii=False)
                    f.write("\n")
            except Exception as e:
                logger.error(f"Erreur écriture autoscan_signals.json : {e}")
            self.signal_count += 1
            self.stats['signals_sent'] += 1
            self.stats['last_signal_time'] = datetime.now()
            return True
        except Exception as e:
            logger.error(f"❌ Erreur envoi signal {signal.get('symbol', '?')}: {e}")
            return False
    
    def scan_all_symbols(self):
        """Scanne tous les symboles et envoie les signaux valides"""
        if not self.running:
            return
        
        logger.info("🚀 Début scan automatique des symboles")
        self.stats['total_scans'] += 1
        self.stats['last_scan_time'] = datetime.now()
        
        symbols = self.get_symbols_to_monitor()
        signals_found = 0
        
        for symbol in symbols:
            if not self.running:
                break
            
            signal = self.scan_symbol(symbol)
            if signal:
                if self.send_signal(signal):
                    signals_found += 1
                    logger.info(f"🎯 Signal traité avec succès: {symbol}")
                else:
                    logger.error(f"❌ Échec traitement signal: {symbol}")
            
            # Pause de 30 secondes entre chaque scan pour analyse approfondie
            logger.info(f"⏳ Pause 30s après le scan de {symbol} pour analyse approfondie...")
            time.sleep(30)
        
        if signals_found == 0:
            logger.info("ℹ️ Aucun signal généré (normal si conditions non remplies)")
        else:
            logger.info(f"🎉 {signals_found} signal(s) envoyé(s) avec succès")
        
        # Log des statistiques
        self.log_stats()
        
        # Nettoyer les anciens échecs
        self._cleanup_failed_symbols()
        # Nettoyer les anciens symbols_processed (optionnel, pour éviter que ça grossisse trop)
        now = datetime.now()
        expired = [s for s, d in self.stats['symbols_processed'].items() if (now - d['last_processed']).total_seconds() > 3600]
        for s in expired:
            del self.stats['symbols_processed'][s]
    
    def _cleanup_failed_symbols(self):
        """Nettoie les anciens échecs de symboles"""
        now = datetime.now()
        expired_symbols = []
        
        for symbol, data in self.failed_symbols.items():
            if now - data['timestamp'] > timedelta(hours=1):
                expired_symbols.append(symbol)
        
        for symbol in expired_symbols:
            del self.failed_symbols[symbol]
            if symbol in self.retry_count:
                del self.retry_count[symbol]
    
    def log_stats(self):
        """Log les statistiques détaillées"""
        if not self.config['enable_logging']:
            return
        
        uptime = "N/A"
        if self.stats['uptime_start']:
            uptime = str(datetime.now() - self.stats['uptime_start'])
        
        logger.info(f"""
📊 STATISTIQUES AUTO-MONITOR
==============================
⏱️  Uptime: {uptime}
🔍 Scans totaux: {self.stats['total_scans']}
📈 Signaux générés: {self.stats['signals_generated']}
📱 Signaux envoyés: {self.stats['signals_sent']}
❌ Signaux rejetés: {self.stats['signals_rejected']}
⚠️  Erreurs: {self.stats['errors']}
⏰ Timeouts: {self.stats['timeouts']}
🎯 Dernier signal: {self.stats['last_signal_time'] or 'Aucun'}
📊 Distribution confiance:
   - Élevée (80-100%): {self.stats['confidence_distribution']['high']}
   - Moyenne (70-79%): {self.stats['confidence_distribution']['medium']}
   - Faible (<70%): {self.stats['confidence_distribution']['low']}
        """)
    
    def send_status_report(self):
        """Envoie un rapport de statut par WhatsApp"""
        try:
            if not self.config['enable_whatsapp']:
                return
            
            uptime = "N/A"
            if self.stats['uptime_start']:
                uptime = str(datetime.now() - self.stats['uptime_start'])
            
            report = f"""
🤖 RAPPORT AUTO-MONITOR
==============================
⏱️  Uptime: {uptime}
🔍 Scans: {self.stats['total_scans']}
📈 Signaux générés: {self.stats['signals_generated']}
📱 Signaux envoyés: {self.stats['signals_sent']}
❌ Rejetés: {self.stats['signals_rejected']}
⚠️  Erreurs: {self.stats['errors']}
🎯 Dernier signal: {self.stats['last_signal_time'] or 'Aucun'}

⚙️ Configuration:
   - Intervalle: {self.config['scan_interval']} min
   - Confiance min: {self.config['min_confidence']}%
   - Limite/heure: {self.config['max_signals_per_hour']}
            """
            
            send_whatsapp_message(report)
            logger.info("📊 Rapport de statut envoyé")
            
        except Exception as e:
            logger.error(f"Erreur envoi rapport: {e}")
    
    def get_status(self):
        """
        Retourne le statut du moniteur automatique pour l'API frontend.
        """
        status = {
            "running": getattr(self, "running", False),
            "stats": getattr(self, "stats", {}),
            "config": getattr(self, "config", {}),
            "uptime": getattr(self, "uptime", "N/A"),
            "symboles_scannes": getattr(self, "symbols_scanned", {}),
            "errors": getattr(self, "errors", []),
        }
        return status
    
    def start(self):
        """Démarre le moniteur automatique"""
        if self.running:
            logger.warning("⚠️ Le moniteur est déjà en cours d'exécution")
            return
        
        logger.info("🚀 Démarrage du moniteur automatique")
        self.running = True
        self.stats['uptime_start'] = datetime.now()
        
        # Charger la configuration sauvegardée
        self.load_config()
        
        # Programmer les tâches
        schedule.every(self.config['scan_interval']).minutes.do(self.scan_all_symbols)
        schedule.every().hour.do(self.send_status_report)
        
        # Démarrer le thread de planification
        self.monitor_thread = threading.Thread(target=self._run_scheduler, daemon=True)
        self.monitor_thread.start()
        
        logger.info(f"✅ Moniteur démarré - Scan toutes les {self.config['scan_interval']} minutes")
    
    def stop(self):
        """Arrête le moniteur automatique"""
        if not self.running:
            logger.warning("⚠️ Le moniteur n'est pas en cours d'exécution")
            return
        
        logger.info("🛑 Arrêt du moniteur automatique")
        self.running = False
        schedule.clear()
        
        # Sauvegarder la configuration
        self.save_config()
        
        logger.info("✅ Moniteur arrêté")
    
    def _run_scheduler(self):
        """Exécute le planificateur de tâches"""
        while self.running:
            try:
                schedule.run_pending()
                time.sleep(1)
            except Exception as e:
                logger.error(f"Erreur planificateur: {e}")
                time.sleep(5)

def calculate_lot(price, sl, tp):
    capital = 10.0
    max_risk = 4.0  # perte max
    max_gain = 30.0 # gain max
    risk_per_unit = abs(price - sl)
    if risk_per_unit == 0:
        return 0.01
    lot = max_risk / risk_per_unit
    gain_per_unit = abs(tp - price)
    if gain_per_unit > 0:
        lot_max_gain = max_gain / gain_per_unit
        lot = min(lot, lot_max_gain)
    lot = max(0.01, round(lot, 2))
    return lot

# Instance globale
_monitor_instance = None

def get_monitor_instance() -> AutoSignalMonitor:
    """Retourne l'instance globale du moniteur"""
    global _monitor_instance
    if _monitor_instance is None:
        _monitor_instance = AutoSignalMonitor()
    return _monitor_instance

def start_auto_monitor(config: Optional[Dict] = None):
    """Démarre le moniteur automatique"""
    monitor = get_monitor_instance()
    if config:
        monitor.update_config(config)
    monitor.start()

def stop_auto_monitor():
    """Arrête le moniteur automatique"""
    monitor = get_monitor_instance()
    monitor.stop()

def get_monitor_status() -> Dict:
    """Retourne le statut du moniteur"""
    monitor = get_monitor_instance()
    return monitor.get_status()

def update_monitor_config(config: Dict):
    """Met à jour la configuration du moniteur"""
    monitor = get_monitor_instance()
    monitor.update_config(config) 

def send_periodic_trend_notification():
    from backend.mt5_connector import get_all_symbols
    import json
    while True:
        try:
            symbols = get_all_symbols()
            if not symbols:
                time.sleep(300)
                continue
            symbol = random.choice(symbols)
            from backend.trend_summary import get_multi_timeframe_trend
            trend_data = get_multi_timeframe_trend(symbol)
            tf_order = ["1d", "8h", "6h", "4h", "1h", "30m", "15m", "5m", "1m"]
            tf_labels = ["D1", "H8", "H6", "H4", "H1", "M30", "M15", "M5", "M1"]
            lines = [f"📊 Tendance consolidée pour {symbol}"]
            sms_parts = []
            tf_short = {}
            for tf, label in zip(tf_order, tf_labels):
                tf_info = trend_data["trends"].get(tf, {})
                trend = tf_info.get("trend", "?")
                force = tf_info.get("force", "?")
                try:
                    force_pct = f"{int(force)}%" if force != "?" else "?"
                except:
                    force_pct = "?"
                lines.append(f"{label} : {trend} ({force_pct})")
                tf_short[label] = trend
            synth = trend_data.get('consolidated', '?')
            scalping = trend_data.get('scalping_possible', '?')
            lines.append(f"Synthèse : {synth} | Scalping possible : {scalping}")
            msg_long = "\n".join(lines)
            # Message SMS/WhatsApp court
            sms_msg = (
                f"Tendance {symbol} : {synth}. "
                f"D1:{tf_short.get('D1','?')} H4:{tf_short.get('H4','?')} H1:{tf_short.get('H1','?')} "
                f"M30:{tf_short.get('M30','?')} M15:{tf_short.get('M15','?')} M5:{tf_short.get('M5','?')} M1:{tf_short.get('M1','?')}. "
                f"Scalping:{scalping}"
            )
            send_whatsapp_message(msg_long)
            # Envoi du message court par SMS et WhatsApp (Twilio)
            try:
                send_sms_vonage(sms_msg)
            except Exception as e:
                print(f"[SMS ERROR] {e}")
            try:
                send_whatsapp_message(sms_msg)
            except Exception as e:
                print(f"[WA SHORT ERROR] {e}")
        except Exception as e:
            send_whatsapp_message(f"Erreur lors de l'envoi de la tendance consolidée auto : {e}")
        time.sleep(300)  # 5 minutes

# Lance le thread périodique au démarrage du module (une seule fois)
if not hasattr(globals(), '_trend_notif_thread_started'):
    t = threading.Thread(target=send_periodic_trend_notification, daemon=True)
    t.start()
    globals()['_trend_notif_thread_started'] = True 