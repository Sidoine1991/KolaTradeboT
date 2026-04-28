#!/usr/bin/env python3
"""
Client MT5 pour communiquer avec le serveur IA Render
Ce script s'exécute sur la machine locale avec MT5
"""

import os
import sys
import time
import json
import logging
import requests
import MetaTrader5 as mt5
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path

# Configuration des URLs de l'API
RENDER_API_URL = "https://kolatradebot.onrender.com"
LOCAL_API_URL = "http://localhost:8000"  # Utilisation du port 8000
TIMEFRAMES = ["M5"]  # Horizon M5 comme demandé
CHECK_INTERVAL = 60  # Secondes entre chaque vérification
MIN_CONFIDENCE = 0.65  # Confiance minimale pour prendre un trade (65% - plus réaliste)

# SL/TP par défaut (Boom/Crash, Volatility, Metals) - Risk/Reward 1:2
SL_PERCENTAGE_DEFAULT = 0.015  # 1.5% (réduit)
TP_PERCENTAGE_DEFAULT = 0.03   # 3% (ratio 1:2)

# SL/TP spécifiques Forex (pips plus larges) - Risk/Reward 1:2
SL_PERCENTAGE_FOREX = 0.008   # 0.8% (réduit)
TP_PERCENTAGE_FOREX = 0.016   # 1.6% (ratio 1:2)

# Tailles de position par type de symbole (réduites pour meilleur money management)
POSITION_SIZES = {
    "Boom 300 Index": 0.01,    # Réduit de 0.2 à 0.01
    "Boom 600 Index": 0.01,    # Réduit de 0.2 à 0.01
    "Boom 900 Index": 0.01,    # Réduit de 0.2 à 0.01
    "Crash 1000 Index": 0.01,  # Réduit de 0.2 à 0.01
    "EURUSD": 0.01,
    "GBPUSD": 0.01,
    "USDJPY": 0.01
}

# Configuration logging améliorée avec rotation et niveaux détaillés
def setup_logging():
    """Configure le logging avec rotation et niveaux détaillés"""
    # Créer le répertoire de logs s'il n'existe pas
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    # Formatter détaillé
    detailed_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - [%(funcName)s:%(lineno)d] - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Formatter simple pour la console
    console_formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%H:%M:%S'
    )
    
    # Handlers
    handlers = []
    
    # Fichier de log principal avec rotation quotidienne
    main_log_file = log_dir / f'mt5_ai_client_{datetime.now().strftime("%Y%m%d")}.log'
    file_handler = logging.FileHandler(main_log_file, encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(detailed_formatter)
    handlers.append(file_handler)
    
    # Fichier de log pour les erreurs uniquement
    error_log_file = log_dir / f'mt5_ai_client_errors_{datetime.now().strftime("%Y%m%d")}.log'
    error_handler = logging.FileHandler(error_log_file, encoding='utf-8')
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(detailed_formatter)
    handlers.append(error_handler)
    
    # Fichier de log pour les trades
    trade_log_file = log_dir / f'mt5_trades_{datetime.now().strftime("%Y%m%d")}.log'
    trade_handler = logging.FileHandler(trade_log_file, encoding='utf-8')
    trade_handler.setLevel(logging.INFO)
    
    # Formatter spécial pour les trades
    trade_formatter = logging.Formatter(
        '%(asctime)s - TRADE - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    trade_handler.setFormatter(trade_formatter)
    handlers.append(trade_handler)
    
    # Console avec niveau INFO
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(console_formatter)
    handlers.append(console_handler)
    
    # Configuration du logger principal
    logging.basicConfig(
        level=logging.DEBUG,
        handlers=handlers,
        force=True  # Forcer la reconfiguration
    )
    
    # Créer un logger spécial pour les trades
    trade_logger = logging.getLogger("mt5_trades")
    trade_logger.setLevel(logging.INFO)
    trade_logger.addHandler(trade_handler)
    trade_logger.propagate = False  # Éviter la duplication dans le logger principal
    
    return trade_logger

# Initialiser le logging
trade_logger = setup_logging()
logger = logging.getLogger("mt5_ai_client")

# Logger spécialisé pour les filling modes
filling_mode_logger = logging.getLogger("filling_mode")
filling_mode_logger.setLevel(logging.DEBUG)

class TradeLogger:
    """Logger spécialisé pour les trades et erreurs de filling mode"""
    
    def __init__(self):
        self.trade_logger = logging.getLogger("mt5_trades")
        self.filling_logger = logging.getLogger("filling_mode")
        
    def get_filling_mode_name(self, mode_value):
        """Convertit la valeur numérique du filling mode en nom lisible"""
        filling_modes = {
            0: "ORDER_FILLING_FOK",
            1: "ORDER_FILLING_FOK", 
            2: "ORDER_FILLING_IOC",
            3: "ORDER_FILLING_IOC",
            4: "ORDER_FILLING_RETURN"
        }
        return filling_modes.get(mode_value, f"UNKNOWN({mode_value})")
        
    def log_trade_attempt(self, symbol, order_type, lot, price, sl, tp, filling_mode):
        """Log une tentative de trade"""
        self.trade_logger.info(
            f"TRADE_ATTEMPT | Symbol: {symbol} | Type: {order_type} | "
            f"Lot: {lot} | Price: {price} | SL: {sl} | TP: {tp} | "
            f"Filling: {filling_mode}"
        )
        
    def log_trade_success(self, symbol, order_type, ticket, profit=0):
        """Log un trade réussi"""
        self.trade_logger.info(
            f"TRADE_SUCCESS | Symbol: {symbol} | Type: {order_type} | "
            f"Ticket: {ticket} | Profit: ${profit:.2f}"
        )
        
    def log_trade_error(self, symbol, order_type, error_code, error_msg, filling_mode):
        """Log une erreur de trade"""
        self.trade_logger.error(
            f"TRADE_ERROR | Symbol: {symbol} | Type: {order_type} | "
            f"Code: {error_code} | Msg: {error_msg} | Filling: {filling_mode}"
        )
        
    def log_filling_mode_error(self, symbol, error_code, error_msg, attempted_mode, fallback_mode=None):
        """Log spécifique pour les erreurs de filling mode"""
        log_msg = (
            f"FILLING_MODE_ERROR | Symbol: {symbol} | "
            f"Attempted: {attempted_mode} | Code: {error_code} | Msg: {error_msg}"
        )
        
        if fallback_mode:
            log_msg += f" | Fallback: {fallback_mode}"
            
        self.filling_logger.error(log_msg)
        
        # Aussi logger dans le fichier d'erreurs principal
        logger.error(f"Erreur filling mode {symbol}: {error_msg} (Code: {error_code})")
        
    def log_filling_mode_success(self, symbol, successful_mode, was_fallback=False):
        """Log quand un filling mode fonctionne"""
        prefix = "FALLBACK_SUCCESS" if was_fallback else "FILLING_MODE_SUCCESS"
        self.filling_logger.info(
            f"{prefix} | Symbol: {symbol} | Mode: {successful_mode}"
        )
        
    def log_api_response(self, endpoint, status_code, response_time, data_size=0):
        """Log les réponses API"""
        logger.debug(
            f"API_RESPONSE | Endpoint: {endpoint} | Status: {status_code} | "
            f"Time: {response_time:.3f}s | Size: {data_size} bytes"
        )
        
    def log_position_update(self, symbol, ticket, action, new_sl=None, new_tp=None, profit=0):
        """Log les mises à jour de positions"""
        update_info = f"POSITION_UPDATE | Symbol: {symbol} | Ticket: {ticket} | Action: {action}"
        if new_sl:
            update_info += f" | New SL: {new_sl}"
        if new_tp:
            update_info += f" | New TP: {new_tp}"
        if profit != 0:
            update_info += f" | Profit: ${profit:.2f}"
            
        self.trade_logger.info(update_info)

# Instance globale du logger de trades
trade_logger_instance = TradeLogger()

class FillingModeAnalyzer:
    """Analyseur des erreurs de filling mode pour identifier les patterns"""
    
    def __init__(self):
        self.error_counts = {}
        self.success_counts = {}
        self.symbol_errors = {}
        
    def analyze_filling_mode_logs(self, log_file_path, hours=24):
        """Analyse les logs de filling mode des dernières N heures"""
        try:
            if not os.path.exists(log_file_path):
                logger.warning(f"Fichier de log non trouvé: {log_file_path}")
                return None
                
            cutoff_time = datetime.now() - timedelta(hours=hours)
            analysis = {
                'period_hours': hours,
                'total_errors': 0,
                'total_successes': 0,
                'symbols_with_errors': {},
                'filling_mode_stats': {},
                'recommendations': []
            }
            
            with open(log_file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    try:
                        # Parser la ligne de log
                        if 'FILLING_MODE_ERROR' in line:
                            self._parse_error_line(line, analysis, cutoff_time)
                        elif 'FILLING_MODE_SUCCESS' in line or 'FALLBACK_SUCCESS' in line:
                            self._parse_success_line(line, analysis, cutoff_time)
                    except Exception as e:
                        logger.debug(f"Erreur parsing ligne log: {e}")
                        
            # Générer des recommandations
            analysis['recommendations'] = self._generate_recommendations(analysis)
            
            return analysis
            
        except Exception as e:
            logger.error(f"Erreur analyse logs filling mode: {e}")
            return None
            
    def _parse_error_line(self, line, analysis, cutoff_time):
        """Parse une ligne d'erreur de filling mode"""
        try:
            # Extraire la date et l'heure
            timestamp_str = line.split(' - ')[0]
            log_time = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
            
            if log_time < cutoff_time:
                return
                
            analysis['total_errors'] += 1
            
            # Extraire le symbole
            if 'Symbol:' in line:
                symbol = line.split('Symbol: ')[1].split(' |')[0]
                if symbol not in analysis['symbols_with_errors']:
                    analysis['symbols_with_errors'][symbol] = 0
                analysis['symbols_with_errors'][symbol] += 1
                
            # Extraire le mode tenté
            if 'Attempted:' in line:
                attempted_mode = line.split('Attempted: ')[1].split(' |')[0]
                if attempted_mode not in analysis['filling_mode_stats']:
                    analysis['filling_mode_stats'][attempted_mode] = {'errors': 0, 'successes': 0}
                analysis['filling_mode_stats'][attempted_mode]['errors'] += 1
                
        except Exception as e:
            logger.debug(f"Erreur parsing ligne erreur: {e}")
            
    def _parse_success_line(self, line, analysis, cutoff_time):
        """Parse une ligne de succès de filling mode"""
        try:
            # Extraire la date et l'heure
            timestamp_str = line.split(' - ')[0]
            log_time = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
            
            if log_time < cutoff_time:
                return
                
            analysis['total_successes'] += 1
            
            # Extraire le mode utilisé
            if 'Mode:' in line:
                mode = line.split('Mode: ')[1].strip()
                if mode not in analysis['filling_mode_stats']:
                    analysis['filling_mode_stats'][mode] = {'errors': 0, 'successes': 0}
                analysis['filling_mode_stats'][mode]['successes'] += 1
                
        except Exception as e:
            logger.debug(f"Erreur parsing ligne succès: {e}")
            
    def _generate_recommendations(self, analysis):
        """Génère des recommandations basées sur l'analyse"""
        recommendations = []
        
        # Recommandation 1: Symboles avec beaucoup d'erreurs
        if analysis['symbols_with_errors']:
            worst_symbol = max(analysis['symbols_with_errors'].items(), key=lambda x: x[1])
            if worst_symbol[1] > 5:  # Plus de 5 erreurs
                recommendations.append(
                    f"Le symbole {worst_symbol[0]} a {worst_symbol[1]} erreurs de filling mode. "
                    f"Considérez utiliser uniquement ORDER_FILLING_RETURN pour ce symbole."
                )
                
        # Recommandation 2: Taux d'erreur élevé
        total_operations = analysis['total_errors'] + analysis['total_successes']
        if total_operations > 0:
            error_rate = analysis['total_errors'] / total_operations
            if error_rate > 0.3:  # Plus de 30% d'erreurs
                recommendations.append(
                    f"Taux d'erreur de filling mode élevé: {error_rate:.1%}. "
                    f"Vérifiez la configuration des modes de remplissage par symbole."
                )
                
        # Recommandation 3: Modes problématiques
        for mode, stats in analysis['filling_mode_stats'].items():
            if stats['errors'] > 0 and stats['successes'] == 0:
                recommendations.append(
                    f"Le mode {mode} n'a jamais réussi. "
                    f"Considérez le retirer des modes tentés ou le mettre en dernier fallback."
                )
                
        if not recommendations:
            recommendations.append("Aucune recommandation - Les filling modes fonctionnent correctement.")
            
        return recommendations

# Instance globale de l'analyseur
filling_analyzer = FillingModeAnalyzer()

class DashboardLogger:
    """Affichage dashboard structuré dans les logs"""
    def __init__(self):
        self.last_update = 0
        
    def display_dashboard(self, positions, signals_data):
        """Affiche un dashboard structuré toutes les 60 secondes"""
        current_time = time.time()
        if current_time - self.last_update < 60:  # Afficher toutes les 60 secondes
            return
            
        self.last_update = current_time
        
        print("\n" + "="*80)
        print("🤖 TRADING BOT DASHBOARD")
        print("="*80)
        
        # Section Positions
        print(f"\n📊 POSITIONS OUVERTES ({len(positions)}):")
        if positions:
            for symbol, pos_info in positions.items():
                profit = self.get_position_profit(pos_info["ticket"])
                profit_color = "🟢" if profit >= 0 else "🔴"
                print(f"   {profit_color} {symbol}: {pos_info['type']} | Ticket: {pos_info['ticket']} | P&L: ${profit:.2f}")
        else:
            print("   ✅ Aucune position ouverte")
        
        # Section Signaux récents
        print(f"\n📡 SIGNAUX RÉCENTS:")
        for symbol, signal in signals_data.items():
            if signal:
                confidence = signal.get('confidence', 0)
                direction = signal.get('signal', 'N/A')
                color = "🟢" if confidence >= 80 else "🟡" if confidence >= 70 else "🔴"
                print(f"   {color} {symbol}: {direction} | Confiance: {confidence:.1f}%")
            else:
                print(f"   ⚪ {symbol}: Pas de signal")
        
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
            total_profit += self.get_position_profit(pos_info["ticket"])
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

class SymbolDetector:
    """Détecte automatiquement les symboles par catégories"""
    
    def __init__(self):
        self.boom_crash_symbols = []
        self.volatility_symbols = []
        self.forex_symbols = []
        self.metals_symbols = []
        self.all_symbols = []
        
    def detect_symbols(self):
        """Détecte tous les symboles disponibles et les classe par catégories"""
        logger.info("🔍 Détection automatique des symboles...")
        
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
                elif symbol.visible and symbol.trade_mode in [1, 4] and not any(m in symbol_name for m in ["XAU", "XAG", "XPT", "XPD"]):
                    forex_pairs = ["EUR", "GBP", "USD", "JPY", "AUD", "CAD", "CHF", "NZD"]
                    if any(pair in symbol_name for pair in forex_pairs):
                        self.forex_symbols.append(symbol_name)
                        logger.info(f"   💱 Forex: {symbol_name}")
                
                # Catégorie 4: Metals (précieux)
                elif symbol.visible and symbol.trade_mode in [1, 4]:
                    metals = ["XAU", "XAG", "XPT", "XPD"]  # Or, Argent, Platine, Palladium
                    if any(metal in symbol_name for metal in metals):
                        self.metals_symbols.append(symbol_name)
                        logger.info(f"   🥇 Metals: {symbol_name}")
            
            # Combiner toutes les catégories par ordre de priorité
            self.all_symbols = self.boom_crash_symbols + self.volatility_symbols + self.metals_symbols + self.forex_symbols
            
            logger.info(f"✅ Détection terminée:")
            logger.info(f"   🚀 Boom/Crash: {len(self.boom_crash_symbols)} symboles")
            logger.info(f"   📈 Volatility: {len(self.volatility_symbols)} symboles")
            logger.info(f"   🥇 Metals: {len(self.metals_symbols)} symboles")
            logger.info(f"   💱 Forex: {len(self.forex_symbols)} symboles")
            logger.info(f"   📊 Total: {len(self.all_symbols)} symboles")
            
            return len(self.all_symbols) > 0
            
        except Exception as e:
            logger.error(f"❌ Erreur détection symboles: {e}")
            return False
    
    def get_symbols_by_priority(self):
        """Retourne les symboles par ordre de priorité"""
        return self.all_symbols  # Ordre: Boom/Crash → Volatility → Metals → Forex
    
    def get_category(self, symbol):
        """Retourne la catégorie d'un symbole"""
        if symbol in self.boom_crash_symbols:
            return "Boom/Crash"
        elif symbol in self.volatility_symbols:
            return "Volatility"
        elif symbol in self.metals_symbols:
            return "Metals"
        elif symbol in self.forex_symbols:
            return "Forex"
        else:
            return "Unknown"
    
    def get_position_size(self, symbol):
        """Retourne la taille de position appropriée selon la catégorie"""
        category = self.get_category(symbol)
        
        if category == "Boom/Crash":
            return 0.2  # Taille plus grande pour indices synthétiques
        elif category == "Volatility":
            return 0.1  # Taille moyenne pour volatilité
        elif category == "Metals":
            return 0.05  # Taille modérée pour métaux
        else:  # Forex
            return 0.01  # Taille standard pour forex

class GARCHVolatilityAnalyzer:
    """Analyse de volatilité avec modèle GARCH simplifié"""
    
    def __init__(self):
        self.volatility_cache = {}
        
    def calculate_garch_volatility(self, returns, p=1, q=1):
        """Calcule la volatilité GARCH(1,1) simplifiée"""
        try:
            if len(returns) < 50:
                return None
            
            returns = np.array(returns)
            
            # Initialisation
            omega = 0.00001  # Constante
            alpha = 0.1      # ARCH coefficient
            beta = 0.85      # GARCH coefficient
            
            # Calculer la variance conditionnelle
            variances = np.zeros(len(returns))
            variances[0] = np.var(returns[:20])  # Initial variance
            
            for t in range(1, len(returns)):
                variances[t] = (omega + 
                               alpha * returns[t-1]**2 + 
                               beta * variances[t-1])
            
            # Retourner la volatilité prévue
            forecast_volatility = np.sqrt(variances[-1])
            
            return {
                'volatility': forecast_volatility,
                'annualized_volatility': forecast_volatility * np.sqrt(252 * 24 * 12),  # Annualized for M5
                'variance_series': variances[-10:],  # Last 10 values
                'model_params': {'omega': omega, 'alpha': alpha, 'beta': beta}
            }
            
        except Exception as e:
            logger.error(f"Erreur GARCH: {e}")
            return None
    
    def get_volatility_signal(self, symbol):
        """Génère des signaux basés sur la volatilité"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 200)
            if rates is None or len(rates) < 50:
                return None
            
            closes = [rate['close'] for rate in rates]
            
            # Calculer les rendements
            returns = np.diff(np.log(closes))
            
            # Calculer GARCH
            garch_result = self.calculate_garch_volatility(returns)
            if not garch_result:
                return None
            
            volatility = garch_result['volatility']
            
            # Signaux basés sur la volatilité
            current_volatility = np.std(returns[-20:])  # Volatilité récente
            avg_volatility = np.std(returns)  # Volatilité moyenne
            
            signal = "HOLD"
            confidence = 0.0
            
            if volatility > avg_volatility * 1.5:
                # Haute volatilité - opportunité de trading
                signal = "HIGH_VOL"
                confidence = 0.7
            elif volatility < avg_volatility * 0.5:
                # Basse volatilité - éviter le trading
                signal = "LOW_VOL"
                confidence = 0.6
            else:
                signal = "NORMAL_VOL"
                confidence = 0.5
            
            return {
                'signal': signal,
                'confidence': confidence,
                'volatility': volatility,
                'current_volatility': current_volatility,
                'avg_volatility': avg_volatility,
                'volatility_ratio': volatility / avg_volatility,
                'analysis_type': 'GARCH_Volatility'
            }
            
        except Exception as e:
            logger.error(f"Erreur volatilité {symbol}: {e}")
            return None

class DERIVArrowDetector:
    """Détecte les patterns DERIV ARROW sur les graphiques MT5"""
    
    def __init__(self):
        self.last_check_time = 0
        self.check_interval = 2  # Vérifier toutes les 2 secondes
        
    def is_deriv_arrow_present(self, symbol):
        """Vérifie si un DERIV ARROW est présent sur le graphique"""
        try:
            current_time = time.time()
            if current_time - self.last_check_time < self.check_interval:
                return False
                
            self.last_check_time = current_time
            
            # Récupérer tous les objets du graphique
            objects = mt5.chart_objects_get(symbol)
            if not objects:
                return False
                
            for obj in objects:
                obj_name = obj.name.lower()
                
                # Vérifier si le nom contient des motifs typiques de flèches DERIV
                if any(keyword in obj_name for keyword in ["arrow", "deriv", "derivation"]):
                    # Vérifier si l'objet est de type flèche ou triangle
                    if obj.type in [mt5.OBJECT_ARROW_UP, mt5.OBJECT_ARROW_DOWN, mt5.OBJECT_TRIANGLE]:
                        logger.info(f"✅ Flèche DERIV ARROW détectée: {obj.name}")
                        return True
                        
            return False
            
        except Exception as e:
            logger.error(f"Erreur détection DERIV ARROW {symbol}: {e}")
            return False
    
    def get_deriv_arrow_signal_type(self, symbol):
        """Détermine le type de signal de la flèche DERIV ARROW"""
        try:
            objects = mt5.chart_objects_get(symbol)
            if not objects:
                return None
                
            for obj in objects:
                obj_name = obj.name.lower()
                
                if any(keyword in obj_name for keyword in ["arrow", "deriv", "derivation"]):
                    if obj.type == mt5.OBJECT_ARROW_UP:
                        logger.info(f"🔺 Flèche HAUT (BUY) DERIV ARROW détectée: {obj.name}")
                        return "BUY"
                    elif obj.type == mt5.OBJECT_ARROW_DOWN:
                        logger.info(f"🔻 Flèche BAS (SELL) DERIV ARROW détectée: {obj.name}")
                        return "SELL"
                    elif obj.type == mt5.OBJECT_TRIANGLE:
                        # Pour les triangles, déterminer la direction par la couleur
                        color = obj.color
                        if color in [0x00FF00, 0x00FF00, 0x7FFF00]:  # Vert/Lime
                            logger.info(f"🔺 Triangle VERT (BUY) DERIV ARROW détecté: {obj.name}")
                            return "BUY"
                        elif color in [0xFF0000, 0x800000]:  # Red/Maroon
                            logger.info(f"🔻 Triangle ROUGE (SELL) DERIV ARROW détecté: {obj.name}")
                            return "SELL"
                            
            return None
            
        except Exception as e:
            logger.error(f"Erreur type signal DERIV ARROW {symbol}: {e}")
            return None

class MaxLossManager:
    """Gestionnaire des pertes maximales avec conservation des positions existantes"""
    
    def __init__(self):
        self.max_total_loss = 5.0  # $5 perte totale maximale
        self.max_symbol_loss = 5.0  # $5 perte par symbole maximale
        
    def get_total_loss(self):
        """Calcule la perte totale de toutes les positions actives"""
        try:
            total_loss = 0.0
            positions = mt5.positions_get()
            
            if positions:
                for position in positions:
                    profit = position.profit
                    if profit < 0:  # Seulement les pertes
                        total_loss += abs(profit)
                        
            return total_loss
            
        except Exception as e:
            logger.error(f"Erreur calcul perte totale: {e}")
            return 0.0
    
    def get_symbol_loss(self, symbol):
        """Calcule la perte pour un symbole spécifique"""
        try:
            symbol_loss = 0.0
            positions = mt5.positions_get()
            
            if positions:
                for position in positions:
                    if position.symbol == symbol:
                        profit = position.profit
                        if profit < 0:  # Seulement les pertes
                            symbol_loss += abs(profit)
                            
            return symbol_loss
            
        except Exception as e:
            logger.error(f"Erreur calcul perte symbole {symbol}: {e}")
            return 0.0
    
    def can_open_new_trades(self, symbol=None):
        """Vérifie si de nouveaux trades peuvent être ouverts"""
        total_loss = self.get_total_loss()
        
        if total_loss >= self.max_total_loss:
            logger.warning(f"🚫 PERTE TOTALE MAX ATTEINTE: ${total_loss:.2f} >= ${self.max_total_loss:.2f} - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)")
            return False
            
        if symbol:
            symbol_loss = self.get_symbol_loss(symbol)
            if symbol_loss >= self.max_symbol_loss:
                logger.warning(f"🚫 SYMBOLE BLOQUÉ: {symbol} - Perte maximale atteinte (${symbol_loss:.2f} >= ${self.max_symbol_loss:.2f}) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)")
                return False
                
        return True

class BoomCrashManager:
    """Gestionnaire spécialisé pour Boom/Crash avec règles "aller au bout" """
    
    def __init__(self):
        pass
    
    def is_boom_crash_symbol(self, symbol):
        """Vérifie si c'est un symbole Boom/Crash"""
        return "Boom" in symbol or "Crash" in symbol
    
    def is_direction_allowed(self, symbol, signal_type):
        """Vérifie si la direction est autorisée pour Boom/Crash"""
        if not self.is_boom_crash_symbol(symbol):
            return True  # Pas de restriction pour les autres symboles
            
        is_boom = "Boom" in symbol
        is_crash = "Crash" in symbol
        
        if is_boom and signal_type == "SELL":
            logger.warning(f"🚫 SELL interdit sur {symbol} (Boom = BUY uniquement)")
            return False
            
        if is_crash and signal_type == "BUY":
            logger.warning(f"🚫 BUY interdit sur {symbol} (Crash = SELL uniquement)")
            return False
            
        return True
    
    def should_close_automatically(self, symbol, profit):
        """Détermine si une position doit être fermée automatiquement"""
        # Pour Boom/Crash: ne jamais fermer automatiquement, laisser aller au bout
        if self.is_boom_crash_symbol(symbol):
            return False
            
        # Pour les autres symboles (Volatility/Step Index): fermer à $4 de perte
        return profit <= -4.0

# Instances globales
deriv_arrow_detector = DERIVArrowDetector()
max_loss_manager = MaxLossManager()
boom_crash_manager = BoomCrashManager()

class AdvancedFeatureExtractor:
    """Extraction de features avancées pour le trading"""
    
    def __init__(self):
        # Pas besoin de scaler pour l'instant
        pass
        
    def calculate_rsi_divergence(self, prices, period=14):
        """Calcule la divergence RSI"""
        try:
            if len(prices) < period * 2:
                return None
            
            prices = np.array(prices)
            
            # Calculer RSI
            deltas = np.diff(prices)
            gains = np.where(deltas > 0, deltas, 0)
            losses = np.where(deltas < 0, -deltas, 0)
            
            avg_gain = np.mean(gains[-period:])
            avg_loss = np.mean(losses[-period:])
            
            if avg_loss == 0:
                return 100
            
            rs = avg_gain / avg_loss
            rsi = 100 - (100 / (1 + rs))
            
            # Détecter divergence
            price_highs = prices[-10:]
            rsi_values = []
            
            for i in range(period, len(prices)):
                if i >= period:
                    delta_prices = prices[i-period:i]
                    delta_gains = np.where(np.diff(delta_prices) > 0, np.diff(delta_prices), 0)
                    delta_losses = np.where(np.diff(delta_prices) < 0, -np.diff(delta_prices), 0)
                    
                    if len(delta_losses) > 0 and np.mean(delta_losses) > 0:
                        delta_rs = np.mean(delta_gains) / np.mean(delta_losses)
                        rsi_values.append(100 - (100 / (1 + delta_rs)))
            
            if len(rsi_values) < 10:
                return rsi
            
            # Divergence haussière: prix baisse mais RSI monte
            price_trend = np.polyfit(range(len(price_highs)), price_highs, 1)[0]
            rsi_trend = np.polyfit(range(len(rsi_values[-10:])), rsi_values[-10:], 1)[0]
            
            if price_trend < 0 and rsi_trend > 0:
                return rsi + 10  # Signal haussier fort
            elif price_trend > 0 and rsi_trend < 0:
                return rsi - 10  # Signal baissier fort
            
            return rsi
            
        except Exception as e:
            logger.error(f"Erreur RSI divergence: {e}")
            return None
    
    def calculate_volume_profile(self, symbol):
        """Calcule le profil de volume"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 100)
            if rates is None:
                return None
            
            volumes = [rate['tick_volume'] for rate in rates]
            closes = [rate['close'] for rate in rates]
            
            # Analyse du volume
            avg_volume = np.mean(volumes)
            current_volume = volumes[-1]
            volume_ratio = current_volume / avg_volume
            
            # Poids du volume par niveau de prix
            price_volume = {}
            for i, (price, volume) in enumerate(zip(closes, volumes)):
                price_key = round(price, 2)
                if price_key not in price_volume:
                    price_volume[price_key] = 0
                price_volume[price_key] += volume
            
            # Niveaux de haut volume
            high_volume_levels = sorted(price_volume.items(), key=lambda x: x[1], reverse=True)[:5]
            
            return {
                'volume_ratio': volume_ratio,
                'avg_volume': avg_volume,
                'current_volume': current_volume,
                'high_volume_levels': high_volume_levels,
                'volume_trend': 'increasing' if volume_ratio > 1.2 else 'decreasing' if volume_ratio < 0.8 else 'normal'
            }
            
        except Exception as e:
            logger.error(f"Erreur volume profile: {e}")
            return None
    
    def detect_seasonal_patterns(self, symbol):
        """Détecte les patterns saisonniers"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 500)
            if rates is None or len(rates) < 100:
                return None
            
            # Convertir en arrays numpy sans pandas
            times = [datetime.fromtimestamp(rate['time']) for rate in rates]
            closes = [rate['close'] for rate in rates]
            volumes = [rate['tick_volume'] for rate in rates]
            
            # Extraire heures et jours
            hours = [t.hour for t in times]
            current_hour = datetime.now().hour
            
            # Calculer les moyennes par heure
            hourly_prices = {}
            hourly_volumes = {}
            
            for i, hour in enumerate(hours):
                if hour not in hourly_prices:
                    hourly_prices[hour] = []
                    hourly_volumes[hour] = []
                hourly_prices[hour].append(closes[i])
                hourly_volumes[hour].append(volumes[i])
            
            # Moyennes par heure
            hourly_avg = {h: np.mean(prices) for h, prices in hourly_prices.items()}
            hourly_vol = {h: np.mean(vols) for h, vols in hourly_volumes.items()}
            
            expected_price = hourly_avg.get(current_hour, np.mean(closes))
            expected_volume = hourly_vol.get(current_hour, np.mean(volumes))
            
            current_price = closes[-1]
            current_volume = volumes[-1]
            
            price_deviation = (current_price - expected_price) / expected_price
            volume_deviation = (current_volume - expected_volume) / expected_volume
            
            return {
                'hourly_pattern': {
                    'current_hour': current_hour,
                    'expected_price': expected_price,
                    'price_deviation': price_deviation,
                    'expected_volume': expected_volume,
                    'volume_deviation': volume_deviation
                },
                'seasonal_strength': abs(price_deviation) + abs(volume_deviation)
            }
            
        except Exception as e:
            logger.error(f"Erreur seasonal patterns: {e}")
            return None
    
    def extract_all_features(self, symbol):
        """Extrait toutes les features avancées"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 200)
            if rates is None:
                return None
            
            closes = [rate['close'] for rate in rates]
            
            features = {
                'rsi_divergence': self.calculate_rsi_divergence(closes),
                'volume_profile': self.calculate_volume_profile(symbol),
                'seasonal_patterns': self.detect_seasonal_patterns(symbol),
                'price_momentum': self.calculate_price_momentum(closes),
                'market_regime': self.detect_market_regime(closes)
            }
            
            return features
            
        except Exception as e:
            logger.error(f"Erreur extraction features: {e}")
            return None
    
    def calculate_price_momentum(self, prices):
        """Calcule le momentum du prix"""
        if len(prices) < 20:
            return None
        
        prices = np.array(prices)
        
        # Momentum sur différentes périodes
        momentum_5 = (prices[-1] - prices[-5]) / prices[-5] if len(prices) > 5 else 0
        momentum_10 = (prices[-1] - prices[-10]) / prices[-10] if len(prices) > 10 else 0
        momentum_20 = (prices[-1] - prices[-20]) / prices[-20] if len(prices) > 20 else 0
        
        # Tendance du momentum
        momentum_trend = momentum_5 + momentum_10 + momentum_20
        
        return {
            'momentum_5': momentum_5,
            'momentum_10': momentum_10,
            'momentum_20': momentum_20,
            'momentum_trend': momentum_trend,
            'strength': abs(momentum_trend)
        }
    
    def detect_market_regime(self, prices):
        """Détecte le régime du marché (trending/ranging)"""
        if len(prices) < 50:
            return None
        
        prices = np.array(prices)
        
        # Calculer la tendance avec numpy.polyfit (alternative à scipy.stats.linregress)
        x = np.arange(len(prices))
        coeffs = np.polyfit(x, prices, 1)
        slope = coeffs[0]
        intercept = coeffs[1]
        
        # Calculer R² manuellement
        y_pred = slope * x + intercept
        ss_res = np.sum((prices - y_pred) ** 2)
        ss_tot = np.sum((prices - np.mean(prices)) ** 2)
        r_value = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0
        
        # Volatilité
        volatility = np.std(prices[-20:])
        avg_price = np.mean(prices)
        volatility_ratio = volatility / avg_price
        
        # Classification du régime
        if abs(r_value) > 0.7:
            regime = "trending"
            direction = "bullish" if slope > 0 else "bearish"
        elif volatility_ratio > 0.02:
            regime = "volatile"
            direction = "neutral"
        else:
            regime = "ranging"
            direction = "neutral"
        
        return {
            'regime': regime,
            'direction': direction,
            'trend_strength': abs(r_value),
            'volatility_ratio': volatility_ratio,
            'slope': slope
        }

class AdvancedTechnicalAnalyzer:
    """Analyse technique avancée avec EMA, Support/Résistance, Trendlines"""
    
    def __init__(self):
        self.ema_periods = [9, 21, 50, 200]  # EMA courtes et longues
        
    def calculate_ema(self, prices, period):
        """Calcule l'EMA (Exponential Moving Average)"""
        if len(prices) < period:
            return None
        
        prices = np.array(prices, dtype=float)
        ema = np.zeros_like(prices)
        alpha = 2 / (period + 1)
        
        # Initial EMA (SMA)
        ema[period-1] = np.mean(prices[:period])
        
        # Calcul EMA
        for i in range(period, len(prices)):
            ema[i] = alpha * prices[i] + (1 - alpha) * ema[i-1]
        
        return ema[-1]  # Retourner la dernière valeur
    
    def find_support_resistance(self, prices, window=20):
        """Identifie les niveaux de support et résistance les plus proches"""
        if len(prices) < window * 2:
            return None, None
        
        prices = np.array(prices)
        current_price = prices[-1]
        
        # Trouver les minima locaux (supports)
        supports = []
        for i in range(window, len(prices) - window):
            if prices[i] == min(prices[i-window:i+window+1]):
                supports.append(prices[i])
        
        # Trouver les maxima locaux (résistances)
        resistances = []
        for i in range(window, len(prices) - window):
            if prices[i] == max(prices[i-window:i+window+1]):
                resistances.append(prices[i])
        
        # Support le plus proche en dessous du prix actuel
        nearest_support = None
        if supports:
            supports_below = [s for s in supports if s < current_price]
            if supports_below:
                nearest_support = max(supports_below)
        
        # Résistance la plus proche au dessus du prix actuel
        nearest_resistance = None
        if resistances:
            resistances_above = [r for r in resistances if r > current_price]
            if resistances_above:
                nearest_resistance = min(resistances_above)
        
        return nearest_support, nearest_resistance
    
    def identify_trendlines(self, prices, min_points=3):
        """Identifie les trendlines significatives"""
        if len(prices) < min_points * 2:
            return None, None
        
        prices = np.array(prices)
        indices = np.arange(len(prices))
        
        # Trendline haussière (support)
        bullish_points = []
        for i in range(1, len(prices)-1):
            if prices[i] < prices[i-1] and prices[i] < prices[i+1]:
                # Point bas local
                bullish_points.append((i, prices[i]))
        
        # Trendline baissière (résistance)
        bearish_points = []
        for i in range(1, len(prices)-1):
            if prices[i] > prices[i-1] and prices[i] > prices[i+1]:
                # Point haut local
                bearish_points.append((i, prices[i]))
        
        # Calculer les trendlines (simplifié)
        bullish_trendline = None
        bearish_trendline = None
        
        if len(bullish_points) >= min_points:
            # Régression linéaire pour trendline haussière
            x = np.array([p[0] for p in bullish_points[-min_points:]])
            y = np.array([p[1] for p in bullish_points[-min_points:]])
            if len(x) > 1:
                coeffs = np.polyfit(x, y, 1)
                bullish_trendline = coeffs[0] * indices[-1] + coeffs[1]
        
        if len(bearish_points) >= min_points:
            # Régression linéaire pour trendline baissière
            x = np.array([p[0] for p in bearish_points[-min_points:]])
            y = np.array([p[1] for p in bearish_points[-min_points:]])
            if len(x) > 1:
                coeffs = np.polyfit(x, y, 1)
                bearish_trendline = coeffs[0] * indices[-1] + coeffs[1]
        
        return bullish_trendline, bearish_trendline
    
    def get_ema_signals(self, symbol):
        """Génère des signaux basés sur les EMA"""
        try:
            # Récupérer les données historiques
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 200)
            if rates is None or len(rates) < 50:
                return None
            
            closes = [rate['close'] for rate in rates]
            
            # Calculer les EMAs
            ema_signals = {}
            for period in self.ema_periods:
                ema_value = self.calculate_ema(closes, period)
                if ema_value:
                    ema_signals[f'EMA_{period}'] = ema_value
            
            current_price = closes[-1]
            
            # Signaux EMA
            ema_signal = "HOLD"
            confidence = 0.0
            
            if 'EMA_9' in ema_signals and 'EMA_21' in ema_signals:
                if current_price > ema_signals['EMA_9'] > ema_signals['EMA_21']:
                    ema_signal = "BUY"
                    confidence = 0.7
                elif current_price < ema_signals['EMA_9'] < ema_signals['EMA_21']:
                    ema_signal = "SELL"
                    confidence = 0.7
            
            # Croisement EMA 50/200 pour tendance long terme
            if 'EMA_50' in ema_signals and 'EMA_200' in ema_signals:
                if ema_signals['EMA_50'] > ema_signals['EMA_200']:
                    if ema_signal == "BUY":
                        confidence += 0.2  # Confirmation tendance haussière
                else:
                    if ema_signal == "SELL":
                        confidence += 0.2  # Confirmation tendance baissière
            
            return {
                'signal': ema_signal,
                'confidence': min(confidence, 1.0),
                'current_price': current_price,
                'ema_values': ema_signals,
                'analysis_type': 'EMA'
            }
            
        except Exception as e:
            logger.error(f"Erreur analyse EMA {symbol}: {e}")
            return None
    
    def get_support_resistance_signals(self, symbol):
        """Génère des signaux basés sur Support/Résistance"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 100)
            if rates is None or len(rates) < 40:
                return None
            
            closes = [rate['close'] for rate in rates]
            current_price = closes[-1]
            
            support, resistance = self.find_support_resistance(closes)
            
            if support is None or resistance is None:
                return None
            
            # Signaux basés sur la proximité avec S/R
            distance_to_support = abs(current_price - support) / current_price
            distance_to_resistance = abs(resistance - current_price) / current_price
            
            signal = "HOLD"
            confidence = 0.0
            
            if distance_to_support < 0.01:  # < 1% du support
                signal = "BUY"
                confidence = 0.8
            elif distance_to_resistance < 0.01:  # < 1% de la résistance
                signal = "SELL"
                confidence = 0.8
            elif current_price > support and current_price < resistance:
                # Dans la zone neutre
                mid_point = (support + resistance) / 2
                if current_price > mid_point:
                    signal = "SELL"
                    confidence = 0.4
                else:
                    signal = "BUY"
                    confidence = 0.4
            
            return {
                'signal': signal,
                'confidence': confidence,
                'current_price': current_price,
                'support': support,
                'resistance': resistance,
                'analysis_type': 'Support/Resistance'
            }
            
        except Exception as e:
            logger.error(f"Erreur analyse S/R {symbol}: {e}")
            return None
    
    def get_trendline_signals(self, symbol):
        """Génère des signaux basés sur les trendlines"""
        try:
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 100)
            if rates is None or len(rates) < 50:
                return None
            
            closes = [rate['close'] for rate in rates]
            current_price = closes[-1]
            
            bullish_trendline, bearish_trendline = self.identify_trendlines(closes)
            
            if bullish_trendline is None and bearish_trendline is None:
                return None
            
            signal = "HOLD"
            confidence = 0.0
            
            # Analyse par rapport aux trendlines
            if bullish_trendline and bearish_trendline:
                if current_price > bullish_trendline and current_price < bearish_trendline:
                    # Dans le canal
                    mid_trendline = (bullish_trendline + bearish_trendline) / 2
                    if current_price > mid_trendline:
                        signal = "SELL"
                        confidence = 0.6
                    else:
                        signal = "BUY"
                        confidence = 0.6
                elif current_price > bearish_trendline:
                    signal = "SELL"
                    confidence = 0.7
                elif current_price < bullish_trendline:
                    signal = "BUY"
                    confidence = 0.7
            
            return {
                'signal': signal,
                'confidence': confidence,
                'current_price': current_price,
                'bullish_trendline': bullish_trendline,
                'bearish_trendline': bearish_trendline,
                'analysis_type': 'Trendlines'
            }
            
        except Exception as e:
            logger.error(f"Erreur analyse trendlines {symbol}: {e}")
            return None
    
    def get_advanced_signal(self, symbol):
        """Combine toutes les analyses techniques avancées"""
        signals = []
        
        # Récupérer les différents signaux
        ema_signal = self.get_ema_signals(symbol)
        if ema_signal:
            signals.append(ema_signal)
        
        sr_signal = self.get_support_resistance_signals(symbol)
        if sr_signal:
            signals.append(sr_signal)
        
        trend_signal = self.get_trendline_signals(symbol)
        if trend_signal:
            signals.append(trend_signal)
        
        if not signals:
            return None
        
        # Combiner les signaux avec pondération
        buy_votes = sum(s['confidence'] for s in signals if s['signal'] == 'BUY')
        sell_votes = sum(s['confidence'] for s in signals if s['signal'] == 'SELL')
        
        total_confidence = buy_votes + sell_votes
        
        if total_confidence == 0:
            return None
        
        # Décider du signal final
        # Réduire la marge nécessaire à 10% pour plus de réactivité
        if buy_votes > sell_votes * 1.1:  # Réduit de 1.2 à 1.1 (10% de marge)
            final_signal = 'BUY'
            final_confidence = buy_votes / len(signals)
        elif sell_votes > buy_votes * 1.1:  # Réduit de 1.2 à 1.1 (10% de marge)
            final_signal = 'SELL'
            final_confidence = sell_votes / len(signals)
        else:
            final_signal = 'HOLD'
            final_confidence = 0.5
        
        return {
            'signal': final_signal,
            'confidence': final_confidence,
            'source': 'advanced_technical',
            'individual_signals': signals,
            'current_price': signals[0]['current_price']
        }


class HistoryLearningAdapter:
    """
    Analyse l'historique des trades et le confronte aux prédictions pour réajuster
    la décision IA. Prédiction + historique agissent sur la confiance et la qualité des entrées.
    """
    def __init__(self, last_n_trades=80, min_trades_for_adjustment=10):
        self.last_n_trades = last_n_trades
        self.min_trades_for_adjustment = min_trades_for_adjustment
        self._cache = {}
        self._cache_ts = 0
        self._cache_ttl = 300  # 5 min

    def _get_recent_deals(self, symbol=None):
        """Récupère les derniers deals MT5 (entrées + sorties) pour statistiques."""
        try:
            if not mt5.terminal_info():
                return []
            from_date = datetime.now() - timedelta(days=30)
            deals = mt5.history_deals_get(from_date, datetime.now())
            if not deals:
                return []
            # Grouper par position_id pour avoir entrée + sortie
            by_pos = {}
            for d in deals:
                key = d.position_id
                if key not in by_pos:
                    by_pos[key] = []
                by_pos[key].append(d)
            # Garder seulement les positions complètes (entrée + sortie)
            trades = []
            for pos_id, pos_deals in by_pos.items():
                entry = [d for d in pos_deals if d.entry == 1]
                exit_deals = [d for d in pos_deals if d.entry == 0]
                if not entry or not exit_deals:
                    continue
                sym = entry[0].symbol
                if symbol and sym != symbol:
                    continue
                deal_type = "BUY" if entry[0].type == mt5.DEAL_TYPE_BUY else "SELL"
                profit = sum(d.profit + d.commission + d.swap for d in pos_deals)
                close_time = max(d.time for d in pos_deals)
                trades.append({
                    "symbol": sym,
                    "type": deal_type,
                    "profit": profit,
                    "is_win": profit > 0,
                    "close_time": close_time,
                })
            trades.sort(key=lambda t: t["close_time"])
            return trades[-self.last_n_trades:] if len(trades) > self.last_n_trades else trades
        except Exception as e:
            logger.debug(f"HistoryLearningAdapter: _get_recent_deals {e}")
            return []

    def get_symbol_stats(self, symbol):
        """Statistiques par symbole: win rate BUY, win rate SELL, nombre de trades."""
        now = time.time()
        if now - self._cache_ts > self._cache_ttl:
            self._cache = {}
            self._cache_ts = now
        if symbol in self._cache:
            return self._cache[symbol]
        trades = self._get_recent_deals(symbol)
        buy_trades = [t for t in trades if t["type"] == "BUY"]
        sell_trades = [t for t in trades if t["type"] == "SELL"]
        buy_wins = sum(1 for t in buy_trades if t["is_win"])
        sell_wins = sum(1 for t in sell_trades if t["is_win"])
        buy_total = len(buy_trades)
        sell_total = len(sell_trades)
        buy_wr = (buy_wins / buy_total) if buy_total else 0.5
        sell_wr = (sell_wins / sell_total) if sell_total else 0.5
        total = buy_total + sell_total
        out = {
            "buy_win_rate": buy_wr,
            "sell_win_rate": sell_wr,
            "buy_trades": buy_total,
            "sell_trades": sell_total,
            "total_trades": total,
        }
        self._cache[symbol] = out
        return out

    def adjust_confidence_from_history(self, symbol, signal, confidence):
        """
        Réajuste la confiance selon l'historique: si les BUY récents perdent souvent,
        on baisse la confiance pour un signal BUY (et idem pour SELL).
        Si l'historique valide la direction, on peut légèrement augmenter la confiance.
        """
        stats = self.get_symbol_stats(symbol)
        if stats["total_trades"] < self.min_trades_for_adjustment:
            return confidence
        if signal == "BUY":
            wr = stats["buy_win_rate"]
            if wr < 0.35:
                confidence *= 0.75
            elif wr < 0.45:
                confidence *= 0.9
            elif wr >= 0.6:
                confidence = min(1.0, confidence * 1.05)
        elif signal == "SELL":
            wr = stats["sell_win_rate"]
            if wr < 0.35:
                confidence *= 0.75
            elif wr < 0.45:
                confidence *= 0.9
            elif wr >= 0.6:
                confidence = min(1.0, confidence * 1.05)
        return round(confidence, 4)


class AggressiveTradingStrategy:
    """
    Stratégie de trading agressif avec duplication de positions
    - Ouvre jusqu'à 4 positions avec des lots croissants
    - Gestion des profits/pertes agressive
    - SL/TP serrés
    """
    
    def __init__(self):
        self.active_strategies = {}  # symbol -> strategy_data
        self.max_positions = 4       # Nombre maximum de positions par stratégie
        self.lot_multiplier = 1.5    # Multiplicateur de lot pour chaque position
        self.profit_target = 10.0    # Objectif de profit en $
        self.loss_limit = 10.0       # Limite de perte en $
        self.entry_delay = 5         # Délai entre les entrées en secondes
        self.position_sizes = {}     # Taille des positions par symbole
        
        # Configuration SL/TP agressifs (en pips)
        self.sl_pips = 20
        self.tp_pips = 30
        
        # NOUVEAU: Sécurisation dynamique dès 1$ de profit
        self.dynamic_secure_profit = 1.0    # Seuil de déclenchement de la sécurisation
        self.dynamic_secure_ratio = 0.5     # Sécuriser 50% du profit au-dessus de 1$
        
        # NOUVEAU: Gestion des pertes individuelles
        self.individual_loss_threshold = -1.0  # Seuil de perte individuelle (-1$) avant fermeture manuelle
        self.avoid_closing_duplicated_losses = True  # Éviter de fermer les positions dupliquées en perte
    
    def should_activate(self, symbol, signal_data):
        """Vérifie si la stratégie doit s'activer pour ce signal"""
        if symbol in self.active_strategies:
            return False  # Stratégie déjà active
        
        confidence = signal_data.get('confidence', 0)
        confidence_percent = confidence * 100 if confidence <= 1.0 else confidence
        
        # ===== SÉCURITÉ MAXIMALE: VALIDATION 80% CONFIANCE =====
        # RÈGLE STRICTE: Aucune stratégie agressive sans 80% de confiance minimum
        if confidence_percent < 80.0:
            logger.error(f"🛑 SÉCURITÉ AGGRESSIVE: CONFIANCE INSUFFISANTE pour {symbol}: {confidence_percent:.1f}% < 80% REQUIS - STRATÉGIE BLOQUÉE")
            return False
            
        # Vérifier les conditions d'activation
        if signal_data.get('decision') not in ['ACHAT FORT', 'VENTE FORTE']:
            logger.error(f"🛑 SÉCURITÉ AGGRESSIVE: PAS DE DÉCISION FORTE pour {symbol}: {signal_data.get('decision')} - REQUIS ACHAT FORT/VENTE FORTE")
            return False
            
        # Double vérification de la confiance (sécurité) - aligné avec MIN_CONFIDENCE
        if signal_data.get('confidence', 0) < 0.65:  # 65% de confiance minimale (réduit)
            logger.error(f"🛑 SÉCURITÉ AGGRESSIVE: CONFIANCE < 0.8 pour {symbol}: {signal_data.get('confidence', 0)}")
            return False
            
        # Ne pas activer sur les symboles Boom/Crash (trop risqué)
        if 'Boom' in symbol or 'Crash' in symbol:
            logger.info(f"🚫 Stratégie agressive non autorisée sur {symbol} (Boom/Crash)")
            return False
        
        logger.info(f"✅ SÉCURITÉ AGGRESSIVE VALIDÉE pour {symbol}: {signal_data.get('decision')} | Confiance: {confidence_percent:.1f}% (≥80%)")
        return True
    
    def check_active_strategies(self):
        """Vérifie et met à jour les stratégies actives"""
        current_time = time.time()
        
        for symbol in list(self.active_strategies.keys()):
            strategy = self.active_strategies[symbol]
            
            # Vérifier si la stratégie est terminée
            if strategy.get('completed', False):
                del self.active_strategies[symbol]
                logger.info(f"🔚 Stratégie agressive terminée pour {symbol}")
                continue
                
            # Calculer le profit total
            total_profit = self.calculate_strategy_profit(strategy)
            
            # ===== NOUVEAU: SÉCURISATION DYNAMIQUE DÈS 1$ DE PROFIT =====
            if total_profit >= self.dynamic_secure_profit:
                self.apply_dynamic_secure(symbol, strategy, total_profit)
            
            # Vérifier les conditions de sortie
            if total_profit >= self.profit_target:
                self.close_strategy(symbol, f"Objectif de profit atteint: ${total_profit:.2f}")
            elif total_profit <= -self.loss_limit:
                self.close_strategy(symbol, f"Limite de perte atteinte: ${abs(total_profit):.2f}")
            else:
                # Essayer d'ajouter une nouvelle position si nécessaire
                self.try_add_position(strategy, current_time)
    
    def calculate_strategy_profit(self, strategy):
        """Calcule le profit total d'une stratégie"""
        total_profit = 0.0
        for ticket in strategy.get('positions', []):
            if mt5.positions_get(ticket=ticket):
                pos = mt5.positions_get(ticket=ticket)[0]
                total_profit += pos.profit
        return total_profit
    
    def try_add_position(self, strategy, current_time):
        """Tente d'ajouter une nouvelle position à la stratégie"""
        symbol = strategy['symbol']
        
        # Vérifier le nombre maximum de positions
        if len(strategy.get('positions', [])) >= self.max_positions:
            return False
            
        # Vérifier le délai depuis la dernière entrée
        last_entry = strategy.get('last_entry_time', 0)
        if current_time - last_entry < self.entry_delay:
            return False
            
        # Calculer le lot pour cette position
        position_count = len(strategy.get('positions', []))
        base_lot = self.position_sizes.get(symbol, 0.01)
        position_lot = round(base_lot * (self.lot_multiplier ** position_count), 2)
        
        # Exécuter le trade
        order_type = mt5.ORDER_TYPE_BUY if strategy['signal_type'] == 'ACHAT FORT' else mt5.ORDER_TYPE_SELL
        
        # Obtenir le prix actuel
        symbol_info = mt5.symbol_info_tick(symbol)
        if symbol_info is None:
            logger.error(f"Impossible d'obtenir les infos du symbole {symbol}")
            return False
            
        price = symbol_info.ask if order_type == mt5.ORDER_TYPE_BUY else symbol_info.bid
        
        # Calculer SL/TP
        point = mt5.symbol_info(symbol).point
        if order_type == mt5.ORDER_TYPE_BUY:
            sl = price - self.sl_pips * 10 * point
            tp = price + self.tp_pips * 10 * point
        else:
            sl = price + self.sl_pips * 10 * point
            tp = price - self.tp_pips * 10 * point
            
        # Exécuter l'ordre
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": position_lot,
            "type": order_type,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": 10,
            "magic": 234567,
            "comment": f"AGGRESSIVE-{position_count+1}",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_FOK,
        }
        
        result = mt5.order_send(request)
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            logger.info(f"🔥 Position agressive #{position_count+1} ouverte sur {symbol} - Lot: {position_lot}")
            strategy['positions'].append(result.order)
            strategy['last_entry_time'] = current_time
            return True
        else:
            logger.error(f"Erreur ouverture position agressive: {result.comment}")
            return False
    
    def close_strategy(self, symbol, reason):
        """Ferme toutes les positions d'une stratégie"""
        if symbol not in self.active_strategies:
            return
            
        strategy = self.active_strategies[symbol]
        logger.info(f"🔒 Fermeture stratégie agressive {symbol}: {reason}")
        
        # Fermer toutes les positions ouvertes
        for ticket in strategy.get('positions', []):
            if mt5.positions_get(ticket=ticket):
                pos = mt5.positions_get(ticket=ticket)[0]
                mt5.Close(symbol, ticket=ticket)
                
        strategy['completed'] = True
    
    def activate_strategy(self, symbol, signal_data):
        """Active une nouvelle stratégie agressive"""
        if symbol in self.active_strategies:
            return False
            
        self.active_strategies[symbol] = {
            'symbol': symbol,
            'signal_type': signal_data['decision'],
            'positions': [],
            'start_time': time.time(),
            'last_entry_time': 0,
            'completed': False
        }
        
        # Définir la taille de position par défaut si non définie
        if symbol not in self.position_sizes:
            self.position_sizes[symbol] = 0.01  # Taille par défaut
            
        logger.info(f"🚀 STRATÉGIE AGRESSIVE ACTIVÉE: {symbol} - {signal_data['decision']}")
        return True

    def apply_dynamic_secure(self, symbol, strategy, current_profit):
        """Applique la sécurisation dynamique dès 1$ de profit et gère les pertes individuelles"""
        # Ne sécuriser que si le profit est au-dessus du seuil
        if current_profit <= self.dynamic_secure_profit:
            return
            
        # Calculer le profit à sécuriser (50% du profit au-dessus de 1$)
        excess_profit = current_profit - self.dynamic_secure_profit
        secure_amount = self.dynamic_secure_profit + (excess_profit * self.dynamic_secure_ratio)
        
        # Séparer les positions en profit et en perte
        profitable_positions = []
        losing_positions = []
        positions_to_close = []
        remaining_profit = 0.0
        secured_profit = 0.0
        
        for ticket in strategy.get('positions', []):
            if mt5.positions_get(ticket=ticket):
                pos = mt5.positions_get(ticket=ticket)[0]
                
                if pos.profit > 0:
                    profitable_positions.append(pos)
                elif pos.profit <= self.individual_loss_threshold and not self.avoid_closing_duplicated_losses:
                    # Fermer immédiatement les positions qui ont perdu >= 1$ SEULEMENT si l'option est désactivée
                    positions_to_close.append(ticket)
                    logger.warning(f"🛑 Position en perte critique fermée: {pos.symbol} Ticket {ticket} - Perte: ${pos.profit:.2f}")
                else:
                    # Positions en perte : laisser le SL normal gérer (surtout pour les positions dupliquées)
                    losing_positions.append(pos)
        
        # Fermer les positions en perte critique d'abord
        for ticket in positions_to_close:
            try:
                if mt5.positions_get(ticket=ticket):
                    pos = mt5.positions_get(ticket=ticket)[0]
                    result = mt5.Close(pos.symbol, ticket=ticket)
                    if result.retcode == mt5.TRADE_RETCODE_DONE:
                        # Retirer de la liste des positions actives
                        if ticket in strategy['positions']:
                            strategy['positions'].remove(ticket)
                    else:
                        logger.error(f"Erreur fermeture position perte critique: {result.comment}")
            except Exception as e:
                logger.error(f"Erreur fermeture position perte critique {ticket}: {e}")
        
        # Maintenant sécuriser le profit avec les positions rentables
        for pos in profitable_positions:
            if secured_profit < secure_amount:
                # Fermer cette position pour sécuriser
                positions_to_close.append(pos.ticket)
                secured_profit += pos.profit
            else:
                remaining_profit += pos.profit
        
        # Fermer les positions rentables sélectionnées pour sécurisation
        for ticket in positions_to_close:
            try:
                if mt5.positions_get(ticket=ticket):
                    pos = mt5.positions_get(ticket=ticket)[0]
                    result = mt5.Close(pos.symbol, ticket=ticket)
                    if result.retcode == mt5.TRADE_RETCODE_DONE:
                        logger.info(f"🔒 Position sécurisée: {pos.symbol} Ticket {ticket} - Profit: ${pos.profit:.2f}")
                        
                        # Retirer de la liste des positions actives
                        if ticket in strategy['positions']:
                            strategy['positions'].remove(ticket)
                    else:
                        logger.error(f"Erreur fermeture position sécurisée: {result.comment}")
            except Exception as e:
                logger.error(f"Erreur sécurisation position {ticket}: {e}")
        
        # Logger la sécurisation
        if secured_profit > 0:
            logger.info(f"💰 SÉCURISATION DYNAMIQUE {symbol}: ${secured_profit:.2f} sécurisés | Restant: ${remaining_profit:.2f} | Total: ${current_profit:.2f}")
            
            # Envoyer notification
            notification = f"💰 Sécurisation {symbol}: ${secured_profit:.2f} sécurisés (${current_profit:.2f} total)"
            try:
                # Utiliser le système de notification MT5 si disponible
                mt5.terminal_notify(notification)
            except:
                pass
        
        # Logger les positions en perte laissées au SL
        if losing_positions:
            total_loss = sum(pos.profit for pos in losing_positions)
            if self.avoid_closing_duplicated_losses:
                logger.info(f"⏳ Positions dupliquées en perte laissées au SL normal: {len(losing_positions)} positions | Perte totale: ${total_loss:.2f}")
            else:
                logger.info(f"⏳ Positions en perte laissées au SL normal: {len(losing_positions)} positions | Perte totale: ${total_loss:.2f}")
            
            for pos in losing_positions:
                logger.debug(f"   Position {pos.ticket}: ${pos.profit:.2f} (SL: {pos.sl})")
        elif self.avoid_closing_duplicated_losses:
            logger.info("🛡️ Protection des positions dupliquées: aucune fermeture manuelle en perte (SL normal uniquement)")

class EMAScalpingStrategy:
    """
    Stratégie de scalping automatique sur l'EMA fast M1
    - S'active quand décision IA est 100%
    - Cherche des entrées à chaque toucher de l'EMA fast en M1
    - Scalping rapide avec SL/TP serrés
    """
    
    def __init__(self):
        self.active_scalping_strategies = {}  # symbol -> strategy_data
        self.ema_fast_period = 9              # EMA rapide pour M1
        self.ema_slow_period = 21              # EMA lente pour confirmation
        self.scalping_sl_pips = 15             # SL très serré pour scalping
        self.scalping_tp_pips = 25             # TP rapide pour scalping
        self.max_scalping_positions = 3        # Maximum 3 positions de scalping
        self.scalping_lot_size = 0.01          # Taille fixe pour scalping
        self.check_interval = 2                # Vérifier toutes les 2 secondes
        
    def activate_ema_scalping(self, symbol, direction):
        """Active le scalping automatique sur l'EMA fast M1"""
        if symbol in self.active_scalping_strategies:
            logger.info(f"🔄 Scalping déjà actif pour {symbol}")
            return False
            
        self.active_scalping_strategies[symbol] = {
            'symbol': symbol,
            'direction': direction,  # 'BUY' ou 'SELL'
            'positions': [],
            'start_time': time.time(),
            'last_check_time': 0,
            'last_ema_touch_time': 0,
            'completed': False,
            'total_profit': 0.0
        }
        
        logger.info(f"🚀 SCALPING EMA ACTIVÉ: {symbol} - Direction: {direction}")
        return True
    
    def check_ema_scalping_opportunities(self):
        """Vérifie les opportunités de scalping sur l'EMA fast M1"""
        current_time = time.time()
        
        for symbol in list(self.active_scalping_strategies.keys()):
            strategy = self.active_scalping_strategies[symbol]
            
            # Vérifier si la stratégie est terminée
            if strategy.get('completed', False):
                del self.active_scalping_strategies[symbol]
                logger.info(f"🔚 Scalping terminé pour {symbol}")
                continue
                
            # Vérifier l'intervalle de temps
            if current_time - strategy['last_check_time'] < self.check_interval:
                continue
                
            strategy['last_check_time'] = current_time
            
            # Calculer les EMAs M1
            ema_fast = self.calculate_ema(symbol, self.ema_fast_period, mt5.TIMEFRAME_M1)
            ema_slow = self.calculate_ema(symbol, self.ema_slow_period, mt5.TIMEFRAME_M1)
            
            if ema_fast is None or ema_slow is None:
                continue
                
            # Obtenir le prix actuel
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                continue
                
            current_price = tick.bid if strategy['direction'] == 'SELL' else tick.ask
            
            # Vérifier si le prix touche l'EMA fast
            is_touching_ema = self.is_price_touching_ema(current_price, ema_fast)
            
            if is_touching_ema:
                logger.info(f"🎯 EMA TOUCH détecté: {symbol} - Prix: {current_price} - EMA: {ema_fast}")
                
                # Vérifier la tendance avec l'EMA slow
                trend_confirmed = self.confirm_trend_with_slow_ema(current_price, ema_fast, ema_slow, strategy['direction'])
                
                if trend_confirmed:
                    # Exécuter le trade de scalping
                    self.execute_scalping_trade(symbol, strategy, current_price, ema_fast)
                    
            # Calculer le profit total et vérifier les conditions de sortie
            self.update_scalping_profit(strategy)
            
            # Sortie si profit cible atteint ou perte limite
            if strategy['total_profit'] >= 5.0:  # 5$ profit cible
                self.close_scalping_strategy(symbol, f"Profit cible atteint: ${strategy['total_profit']:.2f}")
            elif strategy['total_profit'] <= -3.0:  # 3$ perte limite
                self.close_scalping_strategy(symbol, f"Perte limite atteinte: ${abs(strategy['total_profit']):.2f}")
    
    def calculate_ema(self, symbol, period, timeframe):
        """Calcule l'EMA pour une période et timeframe donnés"""
        try:
            # Récupérer les prix de clôture
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, period + 10)
            if rates is None or len(rates) < period:
                return None
                
            closes = [rate['close'] for rate in rates]
            
            # Calculer l'EMA
            ema = self.technical_analyzer.calculate_ema(closes, period)
            return ema[-1] if ema else None
            
        except Exception as e:
            logger.error(f"Erreur calcul EMA {symbol} period {period}: {e}")
            return None
    
    def is_price_touching_ema(self, price, ema, tolerance_pips=5):
        """Vérifie si le prix touche l'EMA (avec tolérance)"""
        symbol_info = mt5.symbol_info("EURUSD")  # Utiliser EURUSD comme référence pour les pips
        if symbol_info:
            point = symbol_info.point
            tolerance = tolerance_pips * point * 10
            return abs(price - ema) <= tolerance
        return abs(price - ema) <= 0.0005  # Tolérance par défaut
    
    def confirm_trend_with_slow_ema(self, price, ema_fast, ema_slow, direction):
        """Confirme la tendance avec l'EMA slow"""
        if direction == 'SELL':
            # Pour VENTE: EMA fast doit être sous EMA slow
            return ema_fast < ema_slow
        else:  # BUY
            # Pour ACHAT: EMA fast doit être au-dessus de EMA slow
            return ema_fast > ema_slow
    
    def execute_scalping_trade(self, symbol, strategy, entry_price, ema_value):
        """Exécute un trade de scalping"""
        # Vérifier le nombre maximum de positions
        if len(strategy['positions']) >= self.max_scalping_positions:
            logger.info(f"📊 Maximum positions scalping atteint pour {symbol}")
            return False
            
        # Déterminer le type d'ordre
        order_type = mt5.ORDER_TYPE_SELL if strategy['direction'] == 'SELL' else mt5.ORDER_TYPE_BUY
        
        # Calculer SL/TP serrés
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            return False
            
        point = symbol_info.point
        
        if order_type == mt5.ORDER_TYPE_BUY:
            sl = entry_price - (self.scalping_sl_pips * 10 * point)
            tp = entry_price + (self.scalping_tp_pips * 10 * point)
        else:  # SELL
            sl = entry_price + (self.scalping_sl_pips * 10 * point)
            tp = entry_price - (self.scalping_tp_pips * 10 * point)
        
        # Créer la requête d'ordre
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": self.scalping_lot_size,
            "type": order_type,
            "price": entry_price,
            "sl": sl,
            "tp": tp,
            "deviation": 10,
            "magic": 345678,  # Magic number différent pour scalping
            "comment": f"SCALPING-EMA-{strategy['direction']}",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_FOK,
        }
        
        result = mt5.order_send(request)
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            logger.info(f"⚡ Trade scalping exécuté: {symbol} {strategy['direction']} | Entry: {entry_price} | SL: {sl} | TP: {tp}")
            strategy['positions'].append(result.order)
            strategy['last_ema_touch_time'] = time.time()
            return True
        else:
            logger.error(f"Erreur trade scalping: {result.comment}")
            return False
    
    def update_scalping_profit(self, strategy):
        """Met à jour le profit total de la stratégie de scalping"""
        total_profit = 0.0
        active_positions = []
        
        for ticket in strategy.get('positions', []):
            if mt5.positions_get(ticket=ticket):
                pos = mt5.positions_get(ticket=ticket)[0]
                total_profit += pos.profit
                active_positions.append(ticket)
        
        strategy['positions'] = active_positions  # Garder seulement les positions actives
        strategy['total_profit'] = total_profit
    
    def close_scalping_strategy(self, symbol, reason):
        """Ferme toutes les positions de scalping"""
        if symbol not in self.active_scalping_strategies:
            return
            
        strategy = self.active_scalping_strategies[symbol]
        logger.info(f"🔒 Fermeture scalping {symbol}: {reason}")
        
        # Fermer toutes les positions ouvertes
        for ticket in strategy.get('positions', []):
            if mt5.positions_get(ticket=ticket):
                pos = mt5.positions_get(ticket=ticket)[0]
                mt5.Close(symbol, ticket=ticket)
                
        strategy['completed'] = True

class MT5AIClient:
    def __init__(self):
        self.connected = False
        self.positions = {}
        self.symbol_detector = SymbolDetector()
        self.technical_analyzer = AdvancedTechnicalAnalyzer()
        self.garch_analyzer = GARCHVolatilityAnalyzer()
        self.feature_extractor = AdvancedFeatureExtractor()
        self.model_performance_cache = {}  # Cache pour performance des modèles
        self.history_learning = HistoryLearningAdapter(last_n_trades=80, min_trades_for_adjustment=10)
        self.aggressive_strategy = AggressiveTradingStrategy()  # NOUVEAU: Stratégie agressive
        self.ema_scalping_strategy = EMAScalpingStrategy()  # NOUVEAU: Stratégie de scalping EMA

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
            
            # Récupérer les identifiants depuis les variables d'environnement
            login = os.getenv("MT5_LOGIN")
            password = os.getenv("MT5_PASSWORD")
            server = os.getenv("MT5_SERVER")
            account_info = mt5.account_info()
            if account_info:
                logger.info(f"MT5 connecte (compte: {account_info.login})")
                self.connected = True
                
                # Détecter automatiquement les symboles par catégories
                logger.info("🔍 Détection automatique des symboles...")
                self.symbol_detector.detect_symbols()
                logger.info(f"📊 {len(self.symbol_detector.all_symbols)} symboles trouvés")
                
                # Stocker les informations de connexion pour la reconnexion
                self.mt5_login = account_info.login
                self.mt5_password = password
                self.mt5_server = server
                
                return True
            else:
                logger.error("Impossible de récupérer les infos du compte")
                return False
                
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
    
    def get_historical_data(self, symbol, timeframe, count=100):
        """Récupère les données historiques avec gestion des colonnes manquantes"""
        try:
            # Récupérer les données depuis MT5
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, count)
            
            if rates is None:
                logger.error(f"Impossible de récupérer les données pour {symbol}")
                return None
                
            # Convertir en DataFrame
            df = pd.DataFrame(rates)
            
            # Vérifier et ajouter les colonnes manquantes
            required_columns = ['time', 'open', 'high', 'low', 'close', 'tick_volume', 'spread', 'real_volume']
            for col in required_columns:
                if col not in df.columns:
                    if col == 'tick_volume':
                        # Si tick_volume manque, utiliser le volume réel ou une valeur par défaut
                        df['tick_volume'] = df['real_volume'] if 'real_volume' in df.columns else 1
                    elif col == 'spread':
                        # Si spread manque, utiliser une valeur par défaut
                        df['spread'] = 10  # Valeur par défaut
                    elif col == 'real_volume':
                        # Si real_volume manque, utiliser tick_volume ou une valeur par défaut
                        df['real_volume'] = df['tick_volume'] if 'tick_volume' in df.columns else 1
            
            return df
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des données pour {symbol}: {str(e)}")
            return None
    
    def prepare_candle_data(self, df):
        """Prépare les données de bougies avec gestion des colonnes manquantes"""
        try:
            # Vérifier les colonnes requises
            required_columns = ['time', 'open', 'high', 'low', 'close', 'tick_volume']
            
            # Créer un nouveau DataFrame avec les colonnes requises
            result = pd.DataFrame()
            
            # Copier les colonnes existantes
            for col in required_columns:
                if col in df.columns:
                    result[col] = df[col]
                else:
                    # Valeurs par défaut pour les colonnes manquantes
                    if col == 'time':
                        result[col] = pd.date_range(start='2020-01-01', periods=len(df), freq='T')
                    elif col == 'tick_volume':
                        result[col] = 1
                    else:
                        result[col] = df['close']  # Utiliser 'close' comme valeur par défaut
            
            # Assurer que les types de données sont corrects
            result['time'] = pd.to_datetime(result['time'], unit='s')
            numeric_cols = ['open', 'high', 'low', 'close', 'tick_volume']
            result[numeric_cols] = result[numeric_cols].apply(pd.to_numeric, errors='coerce')
            
            # Remplir les valeurs manquantes
            result = result.ffill().bfill()
            
            return result
            
        except Exception as e:
            logger.error(f"Erreur dans prepare_candle_data: {str(e)}")
            return None
    
    def get_market_state(self, symbol, timeframe):
        """Récupère l'état du marché avec gestion des modèles manquants"""
        try:
            # Vérifier d'abord si on a un modèle pour ce symbole et ce timeframe
            model_key = f"{symbol}_{timeframe}"
            
            if not hasattr(self, 'ml_models') or model_key not in self.ml_models:
                logger.warning(f"Pas de modèle ML pour {model_key}, utilisation de l'analyse de tendance de base")
                return self.get_basic_trend(symbol, timeframe)
                
            # Utiliser le modèle ML si disponible
            return self.predict_with_ml_model(symbol, timeframe)
            
        except Exception as e:
            logger.error(f"Erreur dans get_market_state pour {symbol}: {str(e)}")
            return "NEUTRE", 50.0  # Retourner une valeur neutre en cas d'erreur
    
    def get_basic_trend(self, symbol, timeframe):
        """Analyse de tendance de base en cas d'absence de modèle ML"""
        try:
            # Récupérer les données historiques
            df = self.get_historical_data(symbol, timeframe, count=50)
            if df is None or df.empty:
                return "NEUTRE", 50.0
                
            # Calculer des indicateurs de base
            df['sma_20'] = df['close'].rolling(window=20).mean()
            df['sma_50'] = df['close'].rolling(window=50).mean()
            
            # Dernière valeur des indicateurs
            last_close = df['close'].iloc[-1]
            sma_20 = df['sma_20'].iloc[-1]
            sma_50 = df['sma_50'].iloc[-1]
            
            # Logique de tendance simple
            if last_close > sma_20 > sma_50:
                return "ACHAT", 70.0
            elif last_close < sma_20 < sma_50:
                return "VENTE", 70.0
            else:
                return "NEUTRE", 50.0
                
        except Exception as e:
            logger.error(f"Erreur dans get_basic_trend pour {symbol}: {str(e)}")
            return "NEUTRE", 50.0

    def get_ai_signal(self, symbol, timeframe="M5"):
        """Signal de trading ultra-optimisé avec tous les analyseurs"""
        try:
            # 1. Signaux ML existants (XGBoost, Random Forest, LSTM, ARIMA)
            ml_signal = self.get_ml_signal(symbol, timeframe)
            
            # 2. Analyse technique avancée (EMA, S/R, Trendlines)
            technical_signal = self.technical_analyzer.get_advanced_signal(symbol)
            
            # 3. Analyse GARCH volatilité (spécialement pour Forex)
            volatility_signal = self.garch_analyzer.get_volatility_signal(symbol)
            
            # 4. Features avancées (RSI divergence, volume, saisonnalité)
            advanced_features = self.feature_extractor.extract_all_features(symbol)
            
            # 5. Combiner tous les signaux avec pondération intelligente
            final_signal = self.combine_ultra_signals(symbol, ml_signal, technical_signal, 
                                                    volatility_signal, advanced_features)
            
            # 6. Réajuster avec l'historique des trades: prédiction + historique → décision IA plus intelligente
            if final_signal:
                conf_before = final_signal.get('confidence', 0)
                conf_after = self.history_learning.adjust_confidence_from_history(
                    symbol, final_signal['signal'], conf_before
                )
                final_signal['confidence'] = conf_after
                if conf_before != conf_after:
                    logger.info(f"IA+Historique {symbol}: confiance {conf_before*100:.1f}% → {conf_after*100:.1f}%")
            
            if final_signal:
                logger.info(f"Signal {symbol} [{final_signal['source']}]: {final_signal['signal']} ({final_signal['confidence']*100:.1f}%)")
                # Ajouter des logs détaillés pour le débogage
                logger.debug(f"Détails du signal {symbol}:")
                logger.debug(f"- ML Signal: {ml_signal}")
                logger.debug(f"- Technical Signal: {technical_signal}")
                logger.debug(f"- Volatility Signal: {volatility_signal}")
                logger.debug(f"- Advanced Features: {advanced_features}")
                return final_signal
            else:
                logger.info(f"Pas de signal valide pour {symbol} (Confiance insuffisante)")
                # Log détaillé pour comprendre pourquoi aucun signal n'est généré
                logger.debug(f"Détails pour {symbol}:")
                logger.debug(f"- ML: {ml_signal}")
                logger.debug(f"- Technique: {technical_signal}")
                logger.debug(f"- Volatilité: {volatility_signal}")
                logger.debug(f"- Features: {advanced_features}")
                return None
                
        except Exception as e:
            logger.error(f"Erreur signal {symbol}: {e}")
            return None
    
    def get_ml_signal(self, symbol, timeframe):
        """Récupère le signal depuis les modèles ML (XGBoost, Random Forest, Time Series)"""
        try:
            # Utiliser l'endpoint avec spécification du modèle et timeframe M5
            url = f"{RENDER_API_URL}/predict/{symbol}"
            params = {
                "model_type": "ensemble",  # Utiliser le meilleur modèle disponible
                "timeframe": timeframe,
                "models": ["xgboost", "random_forest", "lstm", "arima"],  # Time Series models
                "horizon": "M5"  # Horizon 5 minutes
            }
            
            response = requests.get(url, params=params, timeout=30)
            
            if response.status_code == 200:
                data = response.json()
                
                # Extraire et adapter le signal ML
                prediction = data.get('prediction', {})
                direction = prediction.get('direction', 'HOLD')
                confidence = prediction.get('confidence', 0)
                
                # Ajouter les métadonnées des modèles
                model_info = data.get('model_info', {})
                best_model = model_info.get('best_model', 'Unknown')
                model_accuracy = model_info.get('accuracy', 0)
                
                if direction.upper() in ['UP', 'DOWN']:
                    return {
                        'signal': 'BUY' if direction.upper() == 'UP' else 'SELL',
                        'confidence': confidence,
                        'stop_loss': prediction.get('stop_loss'),
                        'take_profit': prediction.get('take_profit'),
                        'source': f'ML_{best_model}',
                        'model_accuracy': model_accuracy,
                        'timeframe': timeframe,
                        'horizon': 'M5',
                        'analysis': data.get('analysis', {})
                    }
                else:
                    return None
            else:
                logger.warning(f"Erreur ML {symbol}: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Erreur ML signal {symbol}: {e}")
            return None

    def combine_ultra_signals(self, symbol, ml_signal, technical_signal, volatility_signal, advanced_features):
        """Combine tous les signaux avec pondération optimisée pour plus de réactivité"""

        # Pondération de base selon type d'instrument
        if "Boom" in symbol or "Crash" in symbol:
            # Pour les indices synthétiques, augmenter le poids des signaux techniques
            weights = {'ml': 0.5, 'technical': 0.6, 'volatility': 0.05, 'features': 0.05}
        elif any(fx in symbol for fx in ["EUR", "GBP", "USD", "JPY"]):
            # Forex: plus de poids aux signaux techniques
            weights = {'ml': 0.45, 'technical': 0.55, 'volatility': 0.1, 'features': 0.1}
        else:
            # Autres: plus de poids aux signaux techniques
            weights = {'ml': 0.4, 'technical': 0.6, 'volatility': 0.1, 'features': 0.1}

        # Ajuster les poids selon la performance des modèles
        if ml_signal and 'model_accuracy' in ml_signal:
            accuracy = ml_signal['model_accuracy']
            if accuracy > 0.8:  # Seuil abaissé de 0.85 à 0.8
                weights['ml'] = min(weights['ml'] + 0.15, 0.6)  # Augmentation plus forte
            elif accuracy < 0.65:  # Seuil augmenté de 0.6 à 0.65
                weights['ml'] = max(weights['ml'] - 0.05, 0.2)  # Réduction plus faible
                weights['technical'] += 0.05  # Donner plus de poids à l'analyse technique

        # Calculer les votes pondérés
        votes = {'BUY': 0, 'SELL': 0, 'HOLD': 0}
        total_confidence = 0

        # Signal ML - Meilleure gestion des signaux neutres
        if ml_signal and ml_signal.get('signal') != 'HOLD':
            vote = ml_signal['signal']
            confidence = ml_signal['confidence'] * weights['ml']
            votes[vote] += confidence
            total_confidence += confidence

        # Signal technique - Augmentation du poids
        if technical_signal:
            vote = technical_signal['signal']
            confidence = technical_signal['confidence'] * weights['technical'] * 1.2  # +20% de poids
            votes[vote] += confidence
            total_confidence += confidence

        # Signal volatilité - Impact réduit
        if volatility_signal:
            vol_signal = volatility_signal['signal']
            vol_conf = volatility_signal['confidence'] * weights['volatility'] * 0.8  # -20% d'impact

            # Moins de prudence en haute volatilité
            if vol_signal == "HIGH_VOL":
                if technical_signal:
                    votes[technical_signal['signal']] += vol_conf * 0.8  # Moins de réduction
            elif vol_signal == "LOW_VOL":
                votes['HOLD'] += vol_conf * 0.5  # Réduction de l'effet HOLD

            total_confidence += vol_conf  # Pas de division par 2

        # Features avancées - Meilleure intégration
        if advanced_features:
            feature_confidence = weights['features']

            # RSI Divergence - Seuils ajustés
            rsi_div = advanced_features.get('rsi_divergence')
            if rsi_div:
                if rsi_div > 75:  # Seuil relevé de 70 à 75
                    votes['SELL'] += feature_confidence * 0.4  # Poids augmenté
                elif rsi_div < 25:  # Seuil abaissé de 30 à 25
                    votes['BUY'] += feature_confidence * 0.4  # Poids augmenté

            # Momentum - Seuil réduit
            momentum = advanced_features.get('price_momentum')
            if momentum and momentum.get('strength', 0) > 0.005:  # Seuil réduit de 0.01 à 0.005
                if momentum['momentum_trend'] > 0:
                    votes['BUY'] += feature_confidence * 0.3
                else:
                    votes['SELL'] += feature_confidence * 0.3

            # Market Regime - Moins de HOLD en range
            regime = advanced_features.get('market_regime')
            if regime:
                if regime['regime'] == 'trending':
                    if regime['direction'] == 'bullish':
                        votes['BUY'] += feature_confidence * 0.4  # Poids augmenté
                    else:
                        votes['SELL'] += feature_confidence * 0.4  # Poids augmenté
                elif regime['regime'] == 'ranging':
                    votes['HOLD'] += feature_confidence * 0.1  # Poids réduit

            # Volume Profile - Impact accru
            volume = advanced_features.get('volume_profile')
            if volume and volume.get('volume_ratio', 1) > 1.3:  # Seuil réduit de 1.5 à 1.3
                if votes['BUY'] > votes['SELL']:
                    votes['BUY'] += feature_confidence * 0.3  # Poids augmenté
                elif votes['SELL'] > votes['BUY']:
                    votes['SELL'] += feature_confidence * 0.3  # Poids augmenté

            total_confidence += feature_confidence

        # Décision finale avec seuil réduit
        if total_confidence > 0:
            # Normaliser les votes
            for vote in votes:
                votes[vote] = votes[vote] / total_confidence

            # Trouver le meilleur signal
            best_signal = max(votes, key=votes.get)
            best_confidence = votes[best_signal]

            # Seuil de confiance réduit et aligné avec MIN_CONFIDENCE
            if best_confidence >= 0.65 and best_signal != 'HOLD':  # Aligné avec MIN_CONFIDENCE
                # Créer le signal final avec plus d'informations
                signal_data = {
                    'signal': best_signal,
                    'confidence': best_confidence,
                    'source': 'AI_Ultra_Optimized',
                    'votes': votes,
                    'weights': weights  # Ajout des poids pour le débogage
                }

                # Ajouter SL/TP si disponible avec une marge plus serrée
                if ml_signal and 'stop_loss' in ml_signal and 'take_profit' in ml_signal:
                    signal_data['stop_loss'] = ml_signal['stop_loss']
                    signal_data['take_profit'] = ml_signal['take_profit']

                # Meilleure journalisation pour le débogage
                logger.info(f"Signal combiné pour {symbol}: {best_signal} ({best_confidence*100:.1f}%)")
                logger.debug(f"Détails des votes: {votes}")

                return signal_data

        logger.info(f"Aucun signal fort pour {symbol}. Meilleur signal: {best_signal} ({best_confidence*100:.1f}%)")
        return None

        return final_signal
    
    # pylint: disable=no-member
    def sync_to_web_dashboard(self):
        """Synchronise les données avec le web dashboard"""
        try:
            # Préparer les données à synchroniser dans le nouveau format
            signals_data = {}
            monitored_symbols = set()
            
            # Récupérer les symboles depuis le détecteur
            detector = self.symbol_detector
            has_symbols = (hasattr(detector, 'all_symbols') and
                         detector.all_symbols)
            if has_symbols:
                monitored_symbols = set(self.symbol_detector.all_symbols)
            else:
                # Fallback: utiliser les symboles avec positions
                monitored_symbols = set(self.positions.keys())
            
            # Récupérer les signaux pour chaque symbole
            for symbol in monitored_symbols:
                try:
                    signal = self.get_ai_signal(symbol)
                    if signal:
                        signals_data[symbol] = {
                            'signal': signal.get('signal', 'WAIT'),
                            'confidence': signal.get('confidence', 0) * 100 if signal.get('confidence', 0) <= 1.0 else signal.get('confidence', 0),
                            'source': signal.get('source', 'Unknown'),
                            'timestamp': datetime.now().isoformat()
                        }
                    else:
                        signals_data[symbol] = {
                            'signal': 'WAIT',
                            'confidence': 0.0,
                            'source': 'None',
                            'timestamp': datetime.now().isoformat()
                        }
                except Exception as e:
                    logger.debug(f"Erreur récupération signal {symbol}: {e}")
                    signals_data[symbol] = {
                        'signal': 'ERROR',
                        'confidence': 0.0,
                        'source': 'Error',
                        'timestamp': datetime.now().isoformat()
                    }
            
            # Préparer les positions avec profit actuel
            positions_data = {}
            total_profit = 0.0
            
            # Récupérer les statistiques de trading depuis l'historique MT5
            trading_stats = {}
            try:
                if not self.connected:
                    trading_stats = {
                        'total_trades': 0,
                        'winning_trades': 0,
                        'losing_trades': 0,
                        'win_rate': 0.0,
                        'total_profit': 0.0,
                        'total_loss': 0.0,
                        'profit_factor': 0.0
                    }
                else:
                    # Récupérer l'historique des trades
                    trade_history = []
                    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                    deals = mt5.history_deals_get(today, datetime.now())
                    if deals:
                        for deal in deals:
                            if deal.entry == 1:  # Entrée de position
                                trade_history.append({
                                    'ticket': deal.ticket,
                                    'symbol': deal.symbol,
                                    'type': 'BUY' if deal.type == mt5.DEAL_TYPE_BUY else 'SELL',
                                    'price_open': deal.price,
                                    'price_close': deal.price,  # Sera mis à jour à la sortie
                                    'profit': 0.0,  # Sera mis à jour à la sortie
                                    'volume': deal.volume,
                                    'open_time': datetime.fromtimestamp(deal.time).strftime('%Y-%m-%d %H:%M:%S'),
                                    'close_time': '',
                                    'reason': 'TP/SL' if deal.comment and 'TP/SL' in deal.comment else 'Manual'
                                })
                            elif deal.entry == 0:  # Sortie de position
                                # Trouver l'entrée correspondante
                                for trade in trade_history:
                                    if trade['ticket'] == deal.position_id and trade['close_time'] == '':
                                        trade['price_close'] = deal.price
                                        trade['profit'] = deal.profit
                                        trade['close_time'] = datetime.fromtimestamp(deal.time).strftime('%Y-%m-%d %H:%M:%S')
                                        break
                    
                    # Calculer les statistiques
                    winning_trades = sum(1 for t in trade_history if t.get('profit', 0) > 0)
                    losing_trades = sum(1 for t in trade_history if t.get('profit', 0) < 0)
                    total_trades = len(trade_history)
                    total_profit = sum(t.get('profit', 0) for t in trade_history if t.get('profit', 0) > 0)
                    total_loss = abs(sum(t.get('profit', 0) for t in trade_history if t.get('profit', 0) < 0))
                    
                    trading_stats = {
                        'total_trades': total_trades,
                        'winning_trades': winning_trades,
                        'losing_trades': losing_trades,
                        'win_rate': (winning_trades / total_trades * 100) if total_trades > 0 else 0.0,
                        'total_profit': total_profit,
                        'total_loss': total_loss,
                        'profit_factor': (total_profit / total_loss) if total_loss > 0 else (float('inf') if total_profit > 0 else 0.0)
                    }
            except Exception as e:
                logger.error(f"Erreur lors de la récupération des statistiques: {e}")
                trading_stats = {
                    'total_trades': 0,
                    'winning_trades': 0,
                    'losing_trades': 0,
                    'win_rate': 0.0,
                    'total_profit': 0.0,
                    'total_loss': 0.0,
                    'profit_factor': 0.0
                }
            
            # Préparer les données à synchroniser dans le nouveau format
            sync_data = {
                'positions': positions_data,
                'signals': signals_data,
                'trading_stats': trading_stats,
                'timestamp': datetime.now().isoformat()
            }
            
            # Récupérer les deals du jour
            today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            deals = mt5.history_deals_get(today, datetime.now())
            
            if not deals:
                return {
                    'total_trades': 0,
                    'winning_trades': 0,
                    'losing_trades': 0,
                    'win_rate': 0.0,
                    'total_profit': 0.0,
                    'total_loss': 0.0,
                    'profit_factor': 0.0
                }
            
            # Calculer les statistiques
            winning_trades = 0
            losing_trades = 0
            total_profit = 0.0
            total_loss = 0.0
            
            # Grouper les deals par position (ticket)
            deals_by_ticket = {}
            for deal in deals:
                ticket = deal.position_id
                if ticket not in deals_by_ticket:
                    deals_by_ticket[ticket] = []
                deals_by_ticket[ticket].append(deal)
            
            # Calculer le profit par position
            for ticket, ticket_deals in deals_by_ticket.items():
                position_profit = sum(deal.profit for deal in ticket_deals)
                if position_profit > 0:
                    winning_trades += 1
                    total_profit += position_profit
                elif position_profit < 0:
                    losing_trades += 1
                    total_loss += abs(position_profit)
            
            total_trades = winning_trades + losing_trades
            win_rate = (winning_trades / total_trades * 100) if total_trades > 0 else 0.0
            profit_factor = (total_profit / total_loss) if total_loss > 0 else (float('inf') if total_profit > 0 else 0.0)
            
            return {
                'total_trades': total_trades,
                'winning_trades': winning_trades,
                'losing_trades': losing_trades,
                'win_rate': win_rate,
                'total_profit': total_profit,
                'total_loss': total_loss,
                'profit_factor': profit_factor
            }
            
        except Exception as e:
            logger.debug(f"Erreur calcul statistiques trading: {e}")
            return {
                'total_trades': 0,
                'winning_trades': 0,
                'losing_trades': 0,
                'win_rate': 0.0,
                'total_profit': 0.0,
                'total_loss': 0.0,
                'profit_factor': 0.0
            }
    
    def calculate_smart_sltp(self, symbol, entry_price, order_type):
        """
        Calcule des niveaux de SL/TP plus serrés et dynamiques
        SL = 1% du prix | TP = 2% du prix
        """
        try:
            # Récupérer les informations du symbole
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Impossible de récupérer les infos pour {symbol}")
                return None, None
                
            point = symbol_info.point
            digits = symbol_info.digits
            
            # Définir les pourcentages initiaux plus serrés
            sl_percent = 0.01  # 1% de SL initial
            tp_percent = 0.02  # 2% de TP initial
            
            # Calculer les niveaux SL/TP en fonction du type d'ordre
            if order_type == mt5.ORDER_TYPE_BUY:
                sl = entry_price * (1 - sl_percent)
                tp = entry_price * (1 + tp_percent)
            else:  # SELL
                sl = entry_price * (1 + sl_percent)
                tp = entry_price * (1 - tp_percent)
            
            # Arrondir selon la précision du symbole
            sl = round(sl, digits)
            tp = round(tp, digits)
            
            # Vérifier que les niveaux sont valides
            if sl <= 0 or tp <= 0 or (order_type == mt5.ORDER_TYPE_BUY and sl >= entry_price) or \
               (order_type == mt5.ORDER_TYPE_SELL and sl <= entry_price):
                logger.error(f"Niveaux SL/TP invalides pour {symbol}: SL={sl}, TP={tp}")
                return None, None
                
            return sl, tp
            
        except Exception as e:
            logger.error(f"Erreur calcul SL/TP pour {symbol}: {e}")
            return None, None
    
    def update_trailing_stop(self, position):
        """Met à jour le stop suiveur pour une position"""
        try:
            symbol = position.symbol
            ticket = position.ticket
            position_type = position.type
            current_price = position.price_current
            open_price = position.price_open
            current_sl = position.sl
            current_tp = position.tp
            
            # Récupérer les informations du symbole
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Impossible de récupérer les infos pour {symbol}")
                return False
                
            point = symbol_info.point
            digits = symbol_info.digits
            
            # Paramètres du trailing stop (en pourcentage)
            activation_profit = 0.005  # 0.5% de profit pour activer le trailing
            trailing_distance = 0.003  # 0.3% de distance de suivi
            
            # Calculer le profit actuel
            if position_type == mt5.ORDER_TYPE_BUY:
                profit_pct = (current_price - open_price) / open_price
                new_sl = current_price * (1 - trailing_distance)
                
                # Vérifier si le profit est suffisant pour activer le trailing
                if profit_pct >= activation_profit:
                    # Vérifier si le nouveau SL est plus élevé que l'ancien
                    if new_sl > current_sl + (point * 10):  # Éviter les mises à jour trop fréquentes
                        # Mettre à jour le SL
                        request = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "symbol": symbol,
                            "position": ticket,
                            "sl": new_sl,
                            "tp": current_tp,
                            "type_time": mt5.ORDER_TIME_GTC
                        }
                        
                        result = mt5.order_send(request)
                        if result.retcode == mt5.TRADE_RETCODE_DONE:
                            logger.info(f"Trailing stop mis à jour pour {symbol}: SL={new_sl}")
                            return True
                        else:
                            logger.error(f"Erreur mise à jour trailing stop {symbol}: {result.comment}")
                            return False
                            
            elif position_type == mt5.ORDER_TYPE_SELL:
                profit_pct = (open_price - current_price) / open_price
                new_sl = current_price * (1 + trailing_distance)
                
                # Vérifier si le profit est suffisant pour activer le trailing
                if profit_pct >= activation_profit:
                    # Vérifier si le nouveau SL est plus bas que l'ancien
                    if new_sl < current_sl - (point * 10) or current_sl == 0:  # Éviter les mises à jour trop fréquentes
                        # Mettre à jour le SL
                        request = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "symbol": symbol,
                            "position": ticket,
                            "sl": new_sl,
                            "tp": current_tp,
                            "type_time": mt5.ORDER_TIME_GTC
                        }
                        
                        result = mt5.order_send(request)
                        if result.retcode == mt5.TRADE_RETCODE_DONE:
                            logger.info(f"Trailing stop mis à jour pour {symbol}: SL={new_sl}")
                            return True
                        else:
                            logger.error(f"Erreur mise à jour trailing stop {symbol}: {result.comment}")
                            return False
            
            return False
            
        except Exception as e:
            logger.error(f"Erreur dans update_trailing_stop pour {symbol}: {e}")
            return False
    
    def calculate_total_profit(self):
        """Calcule le profit total de toutes les positions"""
        total_profit = 0.0
        for pos_info in self.positions.values():
            profit = self.get_position_profit(pos_info["ticket"])
            total_profit += profit
        return total_profit
    
    def calculate_smart_sltp(self, symbol, entry_price, order_type):
        """
        Calcule SL/TP proportionnels au prix avec validation stricte
        SL = 1.5% du prix | TP = 3% du prix (ratio 1:2)
        """
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            return None, None
        
        point = symbol_info.point
        digits = symbol_info.digits
        
        # Choisir les pourcentages selon la catégorie
        category = self.symbol_detector.get_category(symbol)
        if category == "Forex":
            sl_pct = SL_PERCENTAGE_FOREX  # 0.8%
            tp_pct = TP_PERCENTAGE_FOREX  # 1.6%
        else:
            sl_pct = SL_PERCENTAGE_DEFAULT  # 1.5%
            tp_pct = TP_PERCENTAGE_DEFAULT  # 3%

        # Calculer les distances en prix selon le pourcentage sélectionné
        sl_distance_price = entry_price * sl_pct
        tp_distance_price = entry_price * tp_pct
        
        # Validation initiale : éviter les valeurs aberrantes
        if sl_distance_price <= 0 or tp_distance_price <= 0:
            logger.error(f"❌ Distances SL/TP invalides pour {symbol}: SL={sl_distance_price}, TP={tp_distance_price}")
            return None, None
        
        # Calcul des SL/TP avec logique CORRIGÉE
        if order_type == mt5.ORDER_TYPE_BUY:
            # BUY: SL en dessous du prix d'entrée, TP au dessus
            sl = entry_price - sl_distance_price
            tp = entry_price + tp_distance_price
        else:  # SELL
            # SELL: SL au dessus du prix d'entrée, TP en dessous (CORRIGÉ)
            sl = entry_price + sl_distance_price
            tp = entry_price - tp_distance_price
        
        # Validation stricte : éviter les valeurs aberrantes
        if sl <= 0 or tp <= 0:
            logger.error(f"❌ SL/TP négatifs pour {symbol}: SL={sl}, TP={tp}")
            return None, None
            
        # Validation spécifique pour SELL
        if order_type == mt5.ORDER_TYPE_SELL:
            if sl <= entry_price:  # SL doit être au-dessus pour SELL
                logger.error(f"❌ SL SELL invalide {symbol}: SL={sl} <= Prix={entry_price}")
                return None, None
            if tp >= entry_price:  # TP doit être en dessous pour SELL
                logger.error(f"❌ TP SELL invalide {symbol}: TP={tp} >= Prix={entry_price}")
                return None, None
        
        # Validation spécifique pour BUY
        if order_type == mt5.ORDER_TYPE_BUY:
            if sl >= entry_price:  # SL doit être en dessous pour BUY
                logger.error(f"❌ SL BUY invalide {symbol}: SL={sl} >= Prix={entry_price}")
                return None, None
            if tp <= entry_price:  # TP doit être au dessus pour BUY
                logger.error(f"❌ TP BUY invalide {symbol}: TP={tp} <= Prix={entry_price}")
                return None, None
        
        # Validation: respecter trade_stops_level (éviter "Invalid stops")
        stops_level = getattr(symbol_info, "trade_stops_level", 0) or getattr(symbol_info, "stops_level", 0) or 0
        min_dist_points = max(stops_level, 20) if symbol_info.digits >= 4 else max(stops_level, 5)
        min_dist_price = min_dist_points * point

        sl_dist = abs(entry_price - sl)
        tp_dist = abs(tp - entry_price)
        
        # Ajustement si distance minimale non respectée
        if sl_dist < min_dist_price:
            if order_type == mt5.ORDER_TYPE_BUY:
                sl = entry_price - min_dist_price - (2 * point)
            else:
                sl = entry_price + min_dist_price + (2 * point)
            sl = round(sl, digits)
            
        if tp_dist < min_dist_price:
            if order_type == mt5.ORDER_TYPE_BUY:
                tp = entry_price + min_dist_price + (2 * point)
            else:
                tp = entry_price - min_dist_price - (2 * point)
            tp = round(tp, digits)

        # Arrondir correctement selon le nombre de décimales
        sl = round(sl, digits)
        tp = round(tp, digits)

        # Validation finale stricte
        if sl <= 0 or tp <= 0:
            logger.error(f"❌ SL/TP finaux invalides pour {symbol}: SL={sl}, TP={tp}")
            return None, None

        logger.info(
            f"✅ SL/TP validés pour {symbol}: Entry={entry_price}, SL={sl} ({sl_pct*100:.1f}%), TP={tp} ({tp_pct*100:.1f}%)"
        )
        
        return sl, tp
    
    def detect_correction_phase(self, symbol, signal):
        """Détecte si le prix est en phase de correction contraire au signal"""
        try:
            # Récupérer les dernières bougies M1 pour analyse rapide
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 20)
            if not rates or len(rates) < 10:
                return False, 0.0
                
            closes = [rate['close'] for rate in rates]
            if len(closes) < 10:
                return False, 0.0
            
            # Calculer le momentum récent (5 dernières bougies)
            recent_closes = closes[-5:]
            if len(recent_closes) < 3:
                return False, 0.0
                
            # Momentum simple
            momentum = (recent_closes[-1] - recent_closes[0]) / recent_closes[0]
            
            # Tendance courte (10 bougies)
            short_trend = (closes[-1] - closes[-10]) / closes[-10] if len(closes) >= 10 else 0
            
            # Détection de correction
            is_correction = False
            correction_strength = 0.0
            
            if signal == "SELL":
                # Pour SELL: correction = momentum haussier contraire
                if momentum > 0.001:  # 0.1% de hausse
                    is_correction = True
                    correction_strength = abs(momentum)
                # Vérifier si la tendance courte est haussière (contre signal SELL)
                elif short_trend > 0.0005:  # 0.05% de tendance haussière
                    is_correction = True
                    correction_strength = abs(short_trend)
                    
            elif signal == "BUY":
                # Pour BUY: correction = momentum baissier contraire
                if momentum < -0.001:  # -0.1% de baisse
                    is_correction = True
                    correction_strength = abs(momentum)
                # Vérifier si la tendance courte est baissière (contre signal BUY)
                elif short_trend < -0.0005:  # -0.05% de tendance baissière
                    is_correction = True
                    correction_strength = abs(short_trend)
            
            return is_correction, correction_strength
            
        except Exception as e:
            logger.error(f"Erreur détection correction {symbol}: {e}")
            return False, 0.0

    def choose_entry_strategy(self, symbol, signal):
        """Choisit une stratégie d'entrée M5 basée sur S/R et trendlines.
        - Forex/Metals: tenter un pending à proximité du support (BUY) ou résistance (SELL)
        - Boom/Crash: toujours marché
        Retourne un dict: {use_pending: bool, type: mt5.ORDER_TYPE_*, price: float}
        """
        try:
            category = self.symbol_detector.get_category(symbol)
            if category not in ("Forex", "Metals"):
                return {"use_pending": False}

            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                return {"use_pending": False}

            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                return {"use_pending": False}

            current_price = tick.ask if signal == "BUY" else tick.bid

            # Récupérer niveaux S/R et trendlines en M5
            sr = self.technical_analyzer.get_support_resistance_signals(symbol)
            tl = self.technical_analyzer.get_trendline_signals(symbol)

            candidates = []
            if signal == "BUY":
                if sr and sr.get("support"):
                    candidates.append(sr["support"])
                if tl and tl.get("bullish_trendline"):
                    candidates.append(tl["bullish_trendline"])
                order_type = mt5.ORDER_TYPE_BUY_LIMIT
                # Filtrer niveaux sous le prix actuel
                candidates = [p for p in candidates if p and p < current_price]
                # Choisir le plus proche sous le prix
                target = max(candidates) if candidates else None
            else:
                if sr and sr.get("resistance"):
                    candidates.append(sr["resistance"])
                if tl and tl.get("bearish_trendline"):
                    candidates.append(tl["bearish_trendline"])
                order_type = mt5.ORDER_TYPE_SELL_LIMIT
                # Filtrer niveaux au-dessus du prix
                candidates = [p for p in candidates if p and p > current_price]
                # Choisir le plus proche au-dessus du prix
                target = min(candidates) if candidates else None

            if target is None:
                return {"use_pending": False}

            # Seuil de distance max (plus strict sur Forex)
            max_pct = 0.005 if category == "Forex" else 0.01
            distance_pct = abs(target - current_price) / current_price
            if distance_pct > max_pct:
                return {"use_pending": False}

            # Respect du stops_level minimal
            point = symbol_info.point
            stops_level = getattr(symbol_info, "trade_stops_level", 0) or getattr(symbol_info, "stops_level", 0) or 0
            distance_points = abs(target - current_price) / point
            if distance_points < stops_level:
                return {"use_pending": False}

            return {"use_pending": True, "type": order_type, "price": round(target, symbol_info.digits)}
        except Exception as e:
            logger.debug(f"Entry strategy fallback (market) for {symbol}: {e}")
            return {"use_pending": False}
    
    def get_filling_mode_name(self, mode_value):
        """Convertit la valeur numérique du filling mode en nom lisible.
        
        Args:
            mode_value (int): Valeur numérique du mode de remplissage
            
        Returns:
            str: Nom lisible du mode de remplissage
        """
        filling_modes = {
            mt5.ORDER_FILLING_FOK: "FOK (Fill or Kill)",
            mt5.ORDER_FILLING_IOC: "IOC (Immediate or Cancel)",
            mt5.ORDER_FILLING_RETURN: "RETURN (Return)",
            0: "DEFAULT",
            1: "FOK (Fill or Kill)",
            2: "IOC (Immediate or Cancel)",
            3: "IOC (Immediate or Cancel)",
            4: "RETURN (Return)"
        }
        return filling_modes.get(mode_value, f"INVALID({mode_value})")

    def get_symbol_filling_mode(self, symbol):
        """Get the appropriate filling mode for a symbol.
        On Deriv: DFX indices, crypto pairs, and synthetic symbols (Boom/Crash) require ORDER_FILLING_FOK."""
        try:
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Could not get symbol info for {symbol}")
                return mt5.ORDER_FILLING_FOK  # Deriv fallback

            symbol_upper = symbol.upper()

            # === DERIV-SPECIFIC: DFX indices (EURUSD DFX 10 Index, etc.) require FOK ===
            if "DFX" in symbol_upper:
                logger.debug(f"DFX index detected: {symbol} -> ORDER_FILLING_FOK")
                return mt5.ORDER_FILLING_FOK

            # === DERIV-SPECIFIC: Crypto pairs require FOK ===
            crypto_suffixes = ("NERUSD", "APTUSD", "IMXUSD", "SANUSD", "TRUUSD", "MLNUSD",
                              "BTCUSD", "ETHUSD", "LTCUSD", "XRPUSD", "ADAUSD", "DOTUSD",
                              "SOLUSD", "AVAUSD", "LINKUSD", "UNIUSD", "XLMUSD", "MATICUSD",
                              "ATOMUSD", "ALGOUSD", "DOGEUSD", "SHIBUSD", "EOSUSD", "TRXUSD",
                              "XTZUSD", "FILUSD", "AAVEUSD", "MKRUSD", "COMPUSD", "SNXUSD",
                              "YFIUSD", "BATUSD", "ZRXUSD", "ENJUSD", "MANAUSD", "SANDUSD", "AXSUSD")
            if any(suffix in symbol_upper for suffix in crypto_suffixes):
                logger.debug(f"Crypto detected: {symbol} -> ORDER_FILLING_FOK")
                return mt5.ORDER_FILLING_FOK

            # === DERIV-SPECIFIC: Boom/Crash/Volatility use FOK (not RETURN) ===
            if any(x in symbol for x in ["Boom", "Crash", "Volatility", "Vol Over", "Step Index", "Range Break", "Jump"]):
                logger.debug(f"Synthetic Deriv symbol: {symbol} -> ORDER_FILLING_FOK")
                return mt5.ORDER_FILLING_FOK

            # === Check symbol filling_mode bitmask ===
            filling_mode = getattr(symbol_info, 'filling_mode', 0)

            # When filling_mode=0 (broker manages), prefer FOK for Deriv
            if filling_mode == 0:
                logger.debug(f"Filling=0 (broker manages): {symbol} -> ORDER_FILLING_FOK")
                return mt5.ORDER_FILLING_FOK

            if filling_mode:
                if filling_mode & 1:  # FOK
                    return mt5.ORDER_FILLING_FOK
                if filling_mode & 2:  # IOC
                    return mt5.ORDER_FILLING_IOC
                if filling_mode & 4:  # RETURN
                    return mt5.ORDER_FILLING_RETURN

            # Fallback: Deriv and most brokers use FOK for Market Execution
            logger.warning(f"Could not determine filling mode for {symbol}, defaulting to FOK")
            return mt5.ORDER_FILLING_FOK

        except Exception as e:
            logger.error(f"Error getting filling mode for {symbol}: {e}")
            return mt5.ORDER_FILLING_FOK

    def execute_trade(self, symbol, signal_data):
        """Exécute un trade basé sur le signal de l'IA avec décision finale claire requise"""
        try:
            signal = signal_data.get('signal')
            confidence = signal_data.get('confidence', 0)
            decision = signal_data.get('decision', '')  # Décision finale (ACHAT FORT, VENTE FORTE, etc.)
            
            # La confiance est en décimal (0-1), convertir en pourcentage pour comparaison
            confidence_percent = confidence * 100 if confidence <= 1.0 else confidence
            
            # ===== SÉCURITÉ MAXIMALE: VALIDATION 80% CONFIANCE =====
            # RÈGLE STRICTE: Aucune position sans 80% de confiance minimum
            if confidence_percent < 80.0:
                return False  # Pas de log pour éviter de ramer
            
            # ===== NOUVEAU: VÉRIFICATION LISTE NOIRE (SYMBOLES NEUTRES) =====
            if self.is_symbol_blacklisted(symbol):
                return False  # Pas de log pour éviter de ramer
            
            # ===== OPTIMISATION: UTILISER LE SIGNAL DIRECTEMENT SI DÉCISION VIDE =====
            # Si la décision finale est vide, utiliser le signal comme décision
            if not decision or decision.strip() == '':
                if signal in ['BUY', 'SELL']:
                    decision = 'ACHAT FORT' if signal == 'BUY' else 'VENTE FORTE'
                else:
                    return False  # Pas de signal clair, pas de trade
            
            # Vérifier si nous avons une décision finale claire
            if decision not in ['ACHAT FORT', 'VENTE FORTE', 'ACHAT', 'VENTE']:
                return False  # Pas de log pour éviter de ramer
            
            # Convertir la décision finale en signal
            if decision in ['ACHAT FORT', 'ACHAT']:
                signal = 'BUY'
            elif decision in ['VENTE FORTE', 'VENTE']:
                signal = 'SELL'
            else:
                return False  # Pas de log pour éviter de ramer
            
            logger.info(f"✅ SÉCURITÉ VALIDÉE pour {symbol}: {decision} | Confiance: {confidence_percent:.1f}% (≥80%)")
            
            if signal not in ["BUY", "SELL"]:
                logger.info(f"Pas de signal trade pour {symbol}: {signal}")
                return False
            
            # ===== NOUVEAU: STRATÉGIE AGGRESSIVE =====
            # Vérifier si la stratégie agressive doit s'activer
            if self.aggressive_strategy.should_activate(symbol, signal_data):
                logger.info(f"🔥 CONDITIONS AGRESSIVES RÉUNIES pour {symbol}")
                if self.aggressive_strategy.activate_strategy(symbol, signal_data):
                    logger.info(f"🚀 Stratégie agressive activée pour {symbol}")
                    return True
                else:
                    logger.error(f"❌ Erreur activation stratégie agressive pour {symbol}")
            
            # Vérifier si une stratégie agressive est déjà active
            if symbol in self.aggressive_strategy.active_strategies:
                logger.info(f"🔄 Stratégie agressive déjà active pour {symbol}, pas de nouveau trade normal")
                return False
            
            # ===== NOUVEAU: DÉTECTION DÉCISION 100% + SCALPING AUTOMATIQUE =====
            # Si la décision est 100% VENTE, exécuter immédiatement et activer le scalping
            if confidence_percent >= 100.0 and signal == "SELL":
                logger.info(f"🔥 DÉCISION 100% VENTE DÉTECTÉE pour {symbol} - Exécution immédiate + scalping automatique")
                
                # Exécuter le trade initial immédiatement
                if self.execute_immediate_trade(symbol, signal_data):
                    # Activer le scalping automatique sur l'EMA fast M1
                    self.activate_ema_scalping(symbol, signal)
                    return True
                else:
                    logger.error(f"❌ Erreur exécution trade 100% VENTE pour {symbol}")
            
            # Si la décision est 100% ACHAT, exécuter immédiatement et activer le scalping
            elif confidence_percent >= 100.0 and signal == "BUY":
                logger.info(f"🔥 DÉCISION 100% ACHAT DÉTECTÉE pour {symbol} - Exécution immédiate + scalping automatique")
                
                # Exécuter le trade initial immédiatement
                if self.execute_immediate_trade(symbol, signal_data):
                    # Activer le scalping automatique sur l'EMA fast M1
                    self.activate_ema_scalping(symbol, signal)
                    return True
                else:
                    logger.error(f"❌ Erreur exécution trade 100% ACHAT pour {symbol}")
            
            # PROTECTION Boom/Crash: pas de SELL sur Boom, pas de BUY sur Crash
            # Weltrade: pas de SELL sur GainX, pas de BUY sur PainX (même principe)
            is_boom = "Boom" in symbol
            is_crash = "Crash" in symbol
            if is_boom and signal == "SELL":
                logger.info(f"Ordre bloqué: pas de SELL sur Boom ({symbol} = BUY uniquement)")
                return False
            if is_crash and signal == "BUY":
                logger.info(f"Ordre bloqué: pas de BUY sur Crash ({symbol} = SELL uniquement)")
                return False
            try:
                from backend.weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
            except ImportError:
                try:
                    from weltrade_symbols import is_weltrade_pain_synth, is_weltrade_gain_synth
                except ImportError:
                    is_weltrade_pain_synth = is_weltrade_gain_synth = lambda _s: False
            if is_weltrade_gain_synth(symbol) and signal == "SELL":
                logger.info(f"Ordre bloqué: pas de SELL sur GainX ({symbol} = BUY uniquement)")
                return False
            if is_weltrade_pain_synth(symbol) and signal == "BUY":
                logger.info(f"Ordre bloqué: pas de BUY sur PainX ({symbol} = SELL uniquement)")
                return False
            
            # Vérifier si nous avons déjà une position sur ce symbole
            if symbol in self.positions:
                logger.info(f"Position existante pour {symbol}, ignore")
                return False
                
            # Vérifier le nombre maximal de positions (3)
            max_positions = 3
            if len(self.positions) >= max_positions:
                logger.info(f"Nombre maximum de positions atteint ({max_positions}), nouvelle position en attente pour {symbol}")
                return False
            
            # Récupérer la taille de position appropriée selon la catégorie détectée
            position_size = self.symbol_detector.get_position_size(symbol)
            category = self.symbol_detector.get_category(symbol)
            
            # Préparer l'ordre
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Info symbole non disponible pour {symbol}")
                return False
            
            point = symbol_info.point
            tick = mt5.symbol_info_tick(symbol)
            
            # Ajouter un délai de confirmation après signal fort (éviter les entrées précoces)
            if confidence >= 0.70:  # Signaux très forts
                logger.info(f"⏳ SIGNAL FORT {symbol}: {signal} avec {confidence*100:.1f}% - Attente confirmation de 30s")
                time.sleep(30)  # Attendre 30 secondes pour confirmation
                # Revérifier si le signal est toujours valide
                current_tick = mt5.symbol_info_tick(symbol)
                if not current_tick:
                    logger.error(f"Impossible de revérifier {symbol} après attente")
                    return False
                    
                current_price = current_tick.bid if signal == "SELL" else current_tick.ask
                is_still_correction, _ = self.detect_correction_phase(symbol, signal)
                
                if is_still_correction:
                    logger.warning(f"🚫 {symbol}: Toujours en correction après attente - Entrée annulée")
                    return False
                    
                logger.info(f"✅ {symbol}: Signal confirmé après attente - Entrée autorisée")
            
            # Vérifier si le prix est en phase de correction (NOUVEAU)
            is_correction, correction_strength = self.detect_correction_phase(symbol, signal)
            if is_correction:
                logger.warning(f"🚫 CORRECTION DÉTECTÉE pour {symbol}: {signal} - Momentum contraire de {correction_strength*100:.2f}%")
                logger.info(f"⏸️ ATTENTE: Entrée {signal} reportée jusqu'à fin de correction")
                return False  # Ne pas entrer pendant correction
            
            # Stratégie d'entrée (pending ou marché)
            action_type = mt5.TRADE_ACTION_DEAL
            if signal == "BUY":
                market_price = tick.ask
                request_type = mt5.ORDER_TYPE_BUY
            else:  # SELL
                market_price = tick.bid
                request_type = mt5.ORDER_TYPE_SELL

            plan = self.choose_entry_strategy(symbol, signal)
            if plan.get("use_pending"):
                # Vérifier les conditions du marché avant de placer un ordre limite
                entry_price = plan["price"]
                current_price = market_price
                
                # Vérifier si le prix actuel est toujours favorable pour l'ordre limite
                if (signal == "BUY" and current_price <= entry_price) or \
                   (signal == "SELL" and current_price >= entry_price):
                    # Les conditions sont toujours favorables, passer un ordre au marché
                    logger.info(f"Conditions favorables pour l'ordre {signal} sur {symbol} au prix actuel {current_price}")
                    action_type = mt5.TRADE_ACTION_DEAL
                    entry_price = current_price
                else:
                    # Les conditions ne sont plus favorables, annuler l'ordre
                    logger.info(f"Conditions de marché défavorables pour l'ordre {signal} sur {symbol}. Prix actuel: {current_price}, Prix limite: {entry_price}")
                    return False
            else:
                # Ordre au marché
                entry_price = market_price
            
            # Calculer SL/TP proportionnels
            sl, tp = self.calculate_smart_sltp(symbol, entry_price, request_type)
            
            if sl is None or tp is None:
                logger.error(f"Impossible de calculer SL/TP pour {symbol}")
                return False
            
            # Créer la requête d'ordre avec SL/TP intelligents
            # get_symbol_filling_mode gère DFX, crypto, Boom/Crash -> FOK pour Deriv
            filling_mode = self.get_symbol_filling_mode(symbol)
            logger.info(f"Mode de remplissage pour {symbol}: {self.get_filling_mode_name(filling_mode)}")
                
            request = {
                "action": action_type,
                "symbol": symbol,
                "volume": position_size,
                "type": request_type,
                "price": entry_price,
                "sl": sl,
                "tp": tp,
                "deviation": 20,
                "magic": 234000,
                "comment": f"AI-{signal}-{category}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": filling_mode,
            }
            
            # Logger les détails pour debug
            logger.info(f"Tentative ordre {signal} {symbol} [{category}]:")
            logger.info(f"  Entry: {entry_price}")
            if action_type == mt5.TRADE_ACTION_PENDING:
                lim_kind = "BUY_LIMIT" if request_type == mt5.ORDER_TYPE_BUY_LIMIT else "SELL_LIMIT"
                logger.info(f"  Entry strategy: Pending {lim_kind} basé sur S/R/Trendline")
            else:
                logger.info("  Entry strategy: Market")
            perc_sl = abs((entry_price - sl) / entry_price) * 100
            logger.info(f"  SL: {sl} ({perc_sl:.1f}% du prix)")
            perc_tp = abs((tp - entry_price) / entry_price) * 100
            logger.info(f"  TP: {tp} ({perc_tp:.1f}% du prix)")
            logger.info(f"  Volume: {position_size}")
            rr = perc_tp / perc_sl if perc_sl != 0 else 0
            logger.info(f"  Risk/Reward: 1:{rr:.1f}")
            
            # Envoyer l'ordre
            max_retries = 2
            retry_count = 0
            result = None
            
            while retry_count < max_retries:
                try:
                    # Logger la tentative de trade
                    filling_mode_name = self.get_filling_mode_name(request.get("type_filling", 0))
                    trade_logger_instance.log_trade_attempt(
                        symbol, request.get("type", "UNKNOWN"), 
                        request.get("volume", 0), request.get("price", 0),
                        request.get("sl", 0), request.get("tp", 0),
                        filling_mode_name
                    )
                    
                    result = mt5.order_send(request)
                    
                    # Si succès, logger et sortir de la boucle
                    if result and result.retcode == mt5.TRADE_RETCODE_DONE:
                        trade_logger_instance.log_trade_success(
                            symbol, request.get("type", "UNKNOWN"), 
                            result.order if result else 0
                        )
                        break
                        
                    # Si erreur de mode de remplissage, essayer tous les modes: FOK, IOC, RETURN
                    if result and (result.retcode == 10030 or "filling" in (result.comment or "").lower() or "unsupported" in (result.comment or "").lower()):
                        attempted_mode = self.get_filling_mode_name(request.get("type_filling", 0))
                        fallback_modes = [mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_IOC, mt5.ORDER_FILLING_RETURN]
                        tried = request.get("type_filling")
                        success = False
                        for mode in fallback_modes:
                            if mode == tried:
                                continue
                            fallback_mode = self.get_filling_mode_name(mode)
                            trade_logger_instance.log_filling_mode_error(
                                symbol, result.retcode, result.comment or "Invalid fill",
                                attempted_mode, fallback_mode
                            )
                            logger.warning(f"Unsupported filling mode - Essai avec {fallback_mode} pour {symbol}")
                            request["type_filling"] = mode
                            result = mt5.order_send(request)
                            if result and result.retcode == mt5.TRADE_RETCODE_DONE:
                                trade_logger_instance.log_filling_mode_success(symbol, fallback_mode, was_fallback=True)
                                trade_logger_instance.log_trade_success(symbol, request.get("type", "UNKNOWN"), result.order if result else 0)
                                logger.info(f"Ordre réussi avec {fallback_mode} pour {symbol}")
                                success = True
                                break
                        if success:
                            break
                        retry_count = max_retries  # sortir de la boucle
                        continue
                        
                    # Autre erreur, logger et sortir de la boucle
                    error_msg = result.comment if result else "Unknown error"
                    trade_logger_instance.log_trade_error(
                        symbol, request.get("type", "UNKNOWN"),
                        result.retcode if result else -1, error_msg,
                        filling_mode_name
                    )
                    break
                    
                except Exception as e:
                    logger.error(f"Erreur lors de l'envoi de l'ordre pour {symbol}: {e}")
                    retry_count += 1
                    if retry_count < max_retries:
                        logger.info(f"Nouvelle tentative {retry_count}/{max_retries}...")
                        time.sleep(1)  # Attendre 1 seconde avant de réessayer
            
            # Vérifier si result est None
            if result is None:
                last_error = mt5.last_error()
                logger.error(f"Echec ordre {symbol}: mt5.order_send() a retourné None - {last_error}")
                logger.error(f"Requête: {request}")
                return False
            
            # Vérifier le code de retour
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Echec ordre {symbol}: {result.retcode} - {result.comment}")
                # Les fallbacks FOK/IOC/RETURN ont déjà été essayés dans la boucle ci-dessus
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
            
            # Envoyer le feedback au serveur
            self.send_trade_feedback(symbol, signal_data, "opened")
            
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
    
    def close_position(self, pos):
        try:
            symbol = pos.symbol
            volume = pos.volume
            position_ticket = pos.ticket
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                return False
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                return False
            if pos.type == mt5.POSITION_TYPE_BUY:
                price = tick.bid
                order_type = mt5.ORDER_TYPE_SELL
            else:
                price = tick.ask
                order_type = mt5.ORDER_TYPE_BUY
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": volume,
                "type": order_type,
                "position": position_ticket,
                "price": price,
                "deviation": 20,
                "magic": 234000,
                "comment": "AI-Autoclose-1",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_RETURN,
            }
            result = mt5.order_send(request)
            if result and result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"Position fermee {symbol} ticket={position_ticket} profit=${pos.profit:.2f}")
                return True
            else:
                logger.error(f"Echec fermeture {symbol} ticket={position_ticket}: {result.retcode if result else 'None'}")
                return False
        except Exception as e:
            logger.error(f"Erreur fermeture position {pos.symbol}: {e}")
            return False
    
    def auto_close_winners(self, profit_target=1.0):
        try:
            positions = mt5.positions_get()
            if not positions:
                return
            for pos in positions:
                if pos.profit is not None and pos.profit >= profit_target:
                    self.close_position(pos)
        except Exception as e:
            logger.error(f"Erreur auto close: {e}")
    
    def _trigger_continuous_learning(self):
        """Déclenche le ré-entraînement IA sur le serveur (historique + prédictions → modèles)."""
        try:
            url = f"{RENDER_API_URL}/ml/retraining/trigger"
            response = requests.post(url, json={}, timeout=120)
            if response.status_code == 200:
                data = response.json()
                logger.info("🔄 Ré-entraînement IA déclenché (historique + prédictions)")
                if isinstance(data, dict):
                    results = data.get("results") or ({"result": data.get("result")} if data.get("category") else {})
                    if not results and data.get("category"):
                        res = data.get("result", {})
                        results = {data["category"]: res}
                    for cat, res in (results or {}).items():
                        if res and isinstance(res, dict) and res.get("status") == "success":
                            acc = res.get("new_accuracy", res.get("accuracy"))
                            logger.info(f"   ✅ {cat}: accuracy={acc}" if acc is not None else f"   ✅ {cat}: OK")
            else:
                logger.debug(f"Trigger ré-entraînement: {response.status_code} (serveur peut être indisponible)")
        except requests.exceptions.RequestException as e:
            logger.debug(f"Trigger ré-entraînement: {e}")
        except Exception as e:
            logger.debug(f"Trigger ré-entraînement: {e}")
    
    def send_training_data(self):
        """Envoie les données récentes pour l'entraînement avec symboles détectés"""
        try:
            logger.info("Envoi des donnees d'entraînement...")
            
            # Utiliser les symboles détectés automatiquement
            symbols_to_monitor = self.symbol_detector.get_symbols_by_priority()
            
            # Envoyer les données pour chaque catégorie
            categories = [
                ("Boom/Crash", self.symbol_detector.boom_crash_symbols),
                ("Volatility", self.symbol_detector.volatility_symbols),
                ("Metals", self.symbol_detector.metals_symbols),
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
    
    def send_trade_feedback(self, symbol, signal_data, status):
        """Envoie le feedback sur un trade"""
        try:
            feedback = {
                "symbol": symbol,
                "signal": signal_data.get('signal', 'UNKNOWN'),
                "confidence": signal_data.get('confidence', 0),
                "status": status,
                "timestamp": datetime.now().isoformat(),
                "source": signal_data.get('source', 'unknown')
            }
            
            response = requests.post(
                f"{RENDER_API_URL}/trades/feedback",
                json=feedback,
                timeout=10
            )
            
            if response.status_code == 200:
                logger.debug(f"Feedback envoye pour {symbol}")
                return True
            return False
            
        except Exception as e:
            logger.warning(f"Erreur feedback {symbol}: {e}")
            return False
            
            positions_data = []
            signals_data = []
            trade_history = []
            trading_stats = {}
            total_profit = 0
            
            for pos in self.positions.values():
                positions_data.append({
                    "symbol": pos["symbol"],
                    "type": pos["type"],
                    "volume": pos["volume"],
                    "price": pos["price"],
                    "sl": pos["sl"],
                    "tp": pos["tp"],
                    "open_time": pos["open_time"].isoformat(),
                    "profit": pos["profit"] if "profit" in pos else 0,
                    "signal_data": pos["signal_data"],
                    "category": pos["category"]
                })
                
                total_profit += pos["profit"] if "profit" in pos else 0
                
                if pos["symbol"] not in trading_stats:
                    trading_stats[pos["symbol"]] = {
                        "win": 0,
                        "loss": 0,
                        "total": 0,
                        "win_rate": 0
                    }
                
                if pos["profit"] > 0:
                    trading_stats[pos["symbol"]]["win"] += 1
                    trading_stats[pos["symbol"]]["profit"] += pos["profit"]
                else:
                    trading_stats[pos["symbol"]]["loss"] += 1
                
                trading_stats[pos["symbol"]]["total"] += 1
            
            # Ajouter les données de trading pour les stats
            for symbol, stats in trading_stats.items():
                trading_stats[symbol]["win_rate"] = stats["win"] / stats["total"] if stats["total"] > 0 else 0
            
            # Préparer les données à synchroniser dans le nouveau format
            sync_data = {
                'positions': positions_data,
                'signals': signals_data,
                'trade_history': trade_history,
                'trading_stats': trading_stats,
                'total_profit': total_profit,
                'last_updated': datetime.now().isoformat(),
                'source': 'MT5_Client',
                'version': '1.0.0'  # Ajout d'un numéro de version pour le suivi
            }
            
            # Liste des URLs à essayer (d'abord local, puis Render)
            api_urls = [LOCAL_API_URL, RENDER_API_URL]
            success = False
            last_error = None
            
            for api_url in api_urls:
                try:
                    logger.info(f"🔁 Tentative de synchronisation avec {api_url}")
                    
                    # Envoyer au web dashboard
                    response = requests.post(
                        f"{api_url}/api/sync",
                        json=sync_data,
                        timeout=5
                    )
                    
                    if response.status_code == 200:
                        logger.info(f"✅ Données synchronisées avec succès sur {api_url}")
                        success = True
                        break  # Sortir de la boucle si la synchronisation réussit
                    else:
                        error_msg = f"⚠️ Erreur synchronisation avec {api_url}: {response.status_code}"
                        if hasattr(response, 'text'):
                            error_msg += f" - {response.text}"
                        logger.warning(error_msg)
                        last_error = error_msg
                        
                except requests.exceptions.RequestException as e:
                    error_msg = f"⚠️ Impossible de se connecter à {api_url}: {str(e)}"
                    logger.warning(error_msg)
                    last_error = error_msg
                except Exception as e:
                    error_msg = f"❌ Erreur inattendue avec {api_url}: {str(e)}"
                    logger.error(error_msg)
                    last_error = error_msg
            
            if not success and last_error:
                logger.error(f"❌ Échec de la synchronisation avec tous les serveurs. Dernière erreur: {last_error}")
                
            return success
                
        except Exception as e:
            error_msg = f"❌ Erreur lors de la préparation des données pour le dashboard: {str(e)}"
            logger.error(error_msg)
            import traceback
            logger.error(f"Détails de l'erreur: {traceback.format_exc()}")

    def check_positions(self):
        """Vérifie les positions actives et met à jour les stops suiveurs"""
        try:
            # Récupérer toutes les positions ouvertes
            positions = mt5.positions_get()
            if not positions:
                return
                
            for position in positions:
                # Mettre à jour le trailing stop pour cette position
                self.update_trailing_stop(position)
                
                # Vérifier si la position a atteint son TP ou SL
                if position.profit != 0:  # Si le profit est différent de 0, la position a un TP/SL
                    continue
                    
                # Vérifier si le prix actuel est proche du TP pour ajuster le SL
                current_price = position.price_current
                entry_price = position.price_open
                sl = position.sl
                tp = position.tp
                
                # Si le prix est à mi-chemin entre l'entrée et le TP, on peut sécuriser les gains
                if position.type == mt5.ORDER_TYPE_BUY and current_price > entry_price:
                    # Calculer la distance en pourcentage entre l'entrée et le TP
                    distance_to_tp = tp - entry_price
                    current_profit = current_price - entry_price
                    
                    # Si on a atteint 50% du TP, on peut déplacer le SL au point d'entrée
                    if current_profit >= (distance_to_tp * 0.5) and sl < entry_price:
                        # Mettre à jour le SL au point d'entrée
                        request = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "symbol": position.symbol,
                            "position": position.ticket,
                            "sl": entry_price,
                            "tp": tp,
                            "type_time": mt5.ORDER_TIME_GTC
                        }
                        
                        result = mt5.order_send(request)
                        if result.retcode == mt5.TRADE_RETCODE_DONE:
                            logger.info(f"SL déplacé au point d'entrée pour {position.symbol} (Ticket: {position.ticket})")
                        else:
                            logger.error(f"Erreur déplacement SL pour {position.symbol}: {result.comment}")
                            
                elif position.type == mt5.ORDER_TYPE_SELL and current_price < entry_price:
                    # Même logique pour les positions de vente
                    distance_to_tp = entry_price - tp
                    current_profit = entry_price - current_price
                    
                    if current_profit >= (distance_to_tp * 0.5) and (sl > entry_price or sl == 0):
                        # Mettre à jour le SL au point d'entrée
                        request = {
                            "action": mt5.TRADE_ACTION_SLTP,
                            "symbol": position.symbol,
                            "position": position.ticket,
                            "sl": entry_price,
                            "tp": tp,
                            "type_time": mt5.ORDER_TIME_GTC
                        }
                        
                        result = mt5.order_send(request)
                        if result.retcode == mt5.TRADE_RETCODE_DONE:
                            logger.info(f"SL déplacé au point d'entrée pour {position.symbol} (Ticket: {position.ticket})")
                        else:
                            logger.error(f"Erreur déplacement SL pour {position.symbol}: {result.comment}")
                            
        except Exception as e:
            logger.error(f"Erreur vérification positions: {e}")
    
    def execute_immediate_trade(self, symbol, signal_data):
        """Exécute un trade immédiat pour décision 100%"""
        try:
            signal = signal_data.get('signal')
            confidence = signal_data.get('confidence', 0)
            
            logger.info(f"⚡ EXÉCUTION IMMÉDIATE 100%: {symbol} {signal} (Confiance: {confidence}%)")
            
            # Récupérer la taille de position appropriée
            position_size = self.symbol_detector.get_position_size(symbol)
            
            # Obtenir les informations du symbole
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.error(f"Info symbole non disponible pour {symbol}")
                return False
                
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                logger.error(f"Tick non disponible pour {symbol}")
                return False
            
            # Déterminer le prix et le type d'ordre
            if signal == "BUY":
                price = tick.ask
                order_type = mt5.ORDER_TYPE_BUY
            else:  # SELL
                price = tick.bid
                order_type = mt5.ORDER_TYPE_SELL
            
            # Calculer SL/TP pour trade immédiat (plus serrés)
            sl, tp = self.calculate_smart_sltp(symbol, price, order_type)
            
            if sl is None or tp is None:
                logger.error(f"Impossible de calculer SL/TP pour {symbol}")
                return False
            
            # Créer la requête d'ordre
            filling_mode = self.get_symbol_filling_mode(symbol)
            
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": position_size,
                "type": order_type,
                "price": price,
                "sl": sl,
                "tp": tp,
                "deviation": 10,
                "magic": 456789,  # Magic number pour trades 100%
                "comment": f"100%-IMMEDIATE-{signal}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": filling_mode,
            }
            
            result = mt5.order_send(request)
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                logger.info(f"✅ Trade 100% exécuté: {symbol} {signal} | Ticket: {result.order} | Lot: {position_size}")
                return True
            else:
                logger.error(f"❌ Erreur trade 100%: {result.comment}")
                return False
                
        except Exception as e:
            logger.error(f"Erreur exécution trade immédiat {symbol}: {e}")
            return False
    
    def activate_ema_scalping(self, symbol, direction):
        """Active le scalping automatique sur l'EMA fast M1"""
        try:
            success = self.ema_scalping_strategy.activate_ema_scalping(symbol, direction)
            if success:
                logger.info(f"🚀 Scalping EMA activé pour {symbol} - Direction: {direction}")
                
                # Envoyer notification
                notification = f"🚀 Scalping EMA activé: {symbol} {direction}"
                try:
                    mt5.terminal_notify(notification)
                except:
                    pass
            return success
        except Exception as e:
            logger.error(f"Erreur activation scalping EMA {symbol}: {e}")
            return False
    
    def check_ema_scalping_opportunities(self):
        """Vérifie les opportunités de scalping EMA (appelé dans la boucle principale)"""
        try:
            self.ema_scalping_strategy.check_ema_scalping_opportunities()
        except Exception as e:
            logger.error(f"Erreur vérification scalping EMA: {e}")
    
    def check_neutral_decision_closure_optimized(self, symbol, decision):
        """Version optimisée sans logs pour éviter de ramer"""
        try:
            # Vérification rapide des décisions neutres
            neutral_decisions = ['NEUTRE', 'NEUTRAL', 'HOLD', 'WAIT', 'ATTENTE', '', 'UNCERTAIN', 'INCERTAIN', 'SIDEWAYS', 'RANGE', 'CONSO', 'CONSOLIDATION', 'FLAT', 'STABLE', 'NO_SIGNAL', 'NO SIGNAL', 'NONE', 'NULL']
            
            decision_upper = str(decision).upper().strip()
            is_neutral = any(neutral in decision_upper or decision_upper in neutral for neutral in neutral_decisions)
            
            if not is_neutral:
                return False
            
            # Récupérer les positions
            positions = mt5.positions_get(symbol=symbol)
            if not positions:
                return False
            
            # Log uniquement si fermeture effective
            logger.warning(f"🚨 DÉCISION NEUTRE DÉTECTÉE pour {symbol}: '{decision}' - FERMETURE IMMÉDIATE de {len(positions)} position(s)")
            
            positions_closed = 0
            total_profit = 0.0
            
            for position in positions:
                # Fermer avec mode adaptatif
                symbol_info = mt5.symbol_info(position.symbol)
                filling_mode = symbol_info.filling_mode if symbol_info else mt5.ORDER_FILLING_IOC
                
                close_request = {
                    "action": mt5.TRADE_ACTION_DEAL,
                    "symbol": position.symbol,
                    "volume": position.volume,
                    "type": mt5.ORDER_TYPE_BUY if position.type == mt5.POSITION_TYPE_SELL else mt5.ORDER_TYPE_SELL,
                    "position": position.ticket,
                    "price": mt5.symbol_info_tick(position.symbol).bid if position.type == mt5.POSITION_TYPE_BUY else mt5.symbol_info_tick(position.symbol).ask,
                    "deviation": 20,
                    "magic": position.magic,
                    "comment": f"NEUTRAL-DECISION-CLOSE",
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": filling_mode,
                }
                
                result = mt5.order_send(close_request)
                if result.retcode == mt5.TRADE_RETCODE_DONE:
                    positions_closed += 1
                    total_profit += position.profit
                    logger.info(f"✅ Position fermée (décision neutre): {symbol} Ticket {position.ticket} | Profit: {position.profit:.2f}$")
                else:
                    logger.error(f"❌ Erreur fermeture position {position.ticket}: {result.comment}")
            
            if positions_closed > 0:
                logger.warning(f"🔒 FERMETURE COMPLÈTE pour {symbol}: {positions_closed} position(s) fermée(s) | Profit total: {total_profit:.2f}$")
                
                # Notification
                notification = f"🚨 FERMETURE NEUTRE: {symbol} | {positions_closed} positions | Profit: {total_profit:.2f}$"
                try:
                    mt5.terminal_notify(notification)
                except:
                    pass
                
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Erreur fermeture décision neutre {symbol}: {e}")
            return False
    def check_neutral_decision_closure(self, symbol, decision):
        """Ferme immédiatement toutes les positions si la décision devient NEUTRE"""
        try:
            # Vérifier si la décision est NEUTRE ou équivalent (liste étendue)
            neutral_decisions = [
                'NEUTRE', 'NEUTRAL', 'HOLD', 'WAIT', 'ATTENTE', '',
                'UNCERTAIN', 'INCERTAIN', 'SIDEWAYS', 'RANGE', 
                'CONSO', 'CONSOLIDATION', 'FLAT', 'STABLE',
                'NO_SIGNAL', 'NO SIGNAL', 'NONE', 'NULL'
            ]
            
            decision_upper = str(decision).upper().strip()
            is_neutral = any(neutral in decision_upper or decision_upper in neutral for neutral in neutral_decisions)
            
            # DEBUG: Loguer la détection
            logger.info(f"🔍 Analyse décision {symbol}: '{decision}' -> NEUTRE: {is_neutral}")
            
            if not is_neutral:
                return False  # Pas une décision neutre, pas de fermeture
            
            # Récupérer toutes les positions pour ce symbole
            positions = mt5.positions_get(symbol=symbol)
            if not positions:
                logger.info(f"📊 Aucune position à fermer pour {symbol}")
                return False  # Pas de positions à fermer
            
            logger.warning(f"🚨 DÉCISION NEUTRE DÉTECTÉE pour {symbol}: '{decision}' - FERMETURE IMMÉDIATE de {len(positions)} position(s)")
            
            positions_closed = 0
            total_profit = 0.0
            
            for position in positions:
                # Fermer la position avec mode de remplissage adaptatif
                symbol_info = mt5.symbol_info(position.symbol)
                filling_mode = symbol_info.filling_mode if symbol_info else mt5.ORDER_FILLING_IOC
                
                close_request = {
                    "action": mt5.TRADE_ACTION_DEAL,
                    "symbol": position.symbol,
                    "volume": position.volume,
                    "type": mt5.ORDER_TYPE_BUY if position.type == mt5.POSITION_TYPE_SELL else mt5.ORDER_TYPE_SELL,
                    "position": position.ticket,
                    "price": mt5.symbol_info_tick(position.symbol).bid if position.type == mt5.POSITION_TYPE_BUY else mt5.symbol_info_tick(position.symbol).ask,
                    "deviation": 20,
                    "magic": position.magic,
                    "comment": f"NEUTRAL-DECISION-CLOSE",
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": filling_mode,
                }
                
                result = mt5.order_send(close_request)
                if result.retcode == mt5.TRADE_RETCODE_DONE:
                    positions_closed += 1
                    total_profit += position.profit
                    logger.info(f"✅ Position fermée (décision neutre): {symbol} Ticket {position.ticket} | Profit: {position.profit:.2f}$")
                else:
                    logger.error(f"❌ Erreur fermeture position {position.ticket}: {result.comment}")
            
            # Log de résumé
            if positions_closed > 0:
                logger.warning(f"🔒 FERMETURE COMPLÈTE pour {symbol}: {positions_closed} position(s) fermée(s) | Profit total: {total_profit:.2f}$")
                
                # Envoyer notification
                notification = f"🚨 FERMETURE NEUTRE: {symbol} | {positions_closed} positions | Profit: {total_profit:.2f}$"
                try:
                    mt5.terminal_notify(notification)
                except:
                    pass
                
                # Fermer également les stratégies actives pour ce symbole
                if hasattr(self, 'aggressive_strategy') and symbol in self.aggressive_strategy.active_strategies:
                    self.aggressive_strategy.close_strategy(symbol, "DÉCISION NEUTRE")
                
                if hasattr(self, 'ema_scalping_strategy') and symbol in self.ema_scalping_strategy.active_scalping_strategies:
                    self.ema_scalping_strategy.close_scalping_strategy(symbol, "DÉCISION NEUTRE")
                
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Erreur vérification fermeture décision neutre {symbol}: {e}")
            return False
    
    def add_symbol_to_blacklist(self, symbol, reason):
        """Ajoute un symbole à la liste noire temporaire pour éviter nouveaux trades"""
        try:
            if not hasattr(self, 'symbol_blacklist'):
                self.symbol_blacklist = {}
            
            self.symbol_blacklist[symbol] = {
                'reason': reason,
                'timestamp': time.time(),
                'duration': 300  # 5 minutes de blocage
            }
            
            logger.warning(f"🚫 SYMBOLE BLOQUÉ: {symbol} | Raison: {reason} | Durée: 5 minutes")
            
        except Exception as e:
            logger.error(f"Erreur ajout blacklist {symbol}: {e}")
    
    def is_symbol_blacklisted(self, symbol):
        """Vérifie si un symbole est dans la liste noire"""
        try:
            if not hasattr(self, 'symbol_blacklist'):
                return False
            
            if symbol not in self.symbol_blacklist:
                return False
            
            # Vérifier si le blocage est encore valide
            blacklist_entry = self.symbol_blacklist[symbol]
            current_time = time.time()
            
            if current_time - blacklist_entry['timestamp'] > blacklist_entry['duration']:
                # Le blocage a expiré, supprimer de la liste
                del self.symbol_blacklist[symbol]
                logger.info(f"✅ SYMBOLE DÉBLOQUÉ: {symbol} (blocage expiré)")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Erreur vérification blacklist {symbol}: {e}")
            return False
    
    def test_api_format(self):
        """Teste différents formats de requête pour trouver celui qui fonctionne"""
        test_symbol = "EURUSD"
        
        # Formats basés sur les logs Render observés
        formats_to_test = [
            ("POST simple", lambda url: requests.post(url, json={})),
            ("POST avec symbol", lambda url: requests.post(url, json={'symbol': test_symbol})),
            ("POST vide", lambda url: requests.post(url)),
            ("POST data vide", lambda url: requests.post(url, data={})),
        ]
        
        for api_url in [LOCAL_API_URL, RENDER_API_URL]:
            logger.info(f"Test des formats pour {api_url}/decision")
            for format_name, request_func in formats_to_test:
                try:
                    response = request_func(f"{api_url}/decision")
                    logger.info(f"  {format_name}: HTTP {response.status_code}")
                    if response.status_code == 200:
                        logger.info(f"  ✓ Format {format_name} fonctionne!")
                        return format_name
                    elif response.status_code == 422:
                        # Essayer de lire l'erreur pour comprendre ce qui manque
                        try:
                            error_detail = response.json()
                            logger.error(f"  ✗ Erreur 422 détail: {error_detail}")
                        except:
                            pass
                except Exception as e:
                    logger.error(f"  ✗ {format_name}: {str(e)}")
        return None

    def get_latest_signal(self, symbol):
        """Récupère le dernier signal pour un symbole depuis l'API
        
        Args:
            symbol (str): Le symbole pour lequel récupérer le signal
            
        Returns:
            dict or None: Les données du signal ou None en cas d'erreur
        """
        if not symbol:
            logger.warning("⚠️ Aucun symbole fourni pour la récupération du signal")
            return None
            
        try:
            # Vérifier d'abord si le symbole est disponible
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                logger.warning(f"⚠️ Symbole non trouvé: {symbol}")
                return None
                
            # Vérifier si le marché est ouvert pour ce symbole
            if not self.is_market_open(symbol):
                logger.info(f"🔒 Marché fermé pour {symbol}, pas de signal récupéré")
                return None
                
            # Liste des URLs à essayer (local puis distant)
            api_urls = [LOCAL_API_URL, RENDER_API_URL]
            
            for api_url in api_urls:
                try:
                    url = f"{api_url}/decision"
                    
                    # Obtenir les prix actuels pour le symbole
                    symbol_info = mt5.symbol_info(symbol)
                    if symbol_info is None:
                        logger.warning(f"⚠️ Impossible d'obtenir les infos pour {symbol}")
                        continue
                    
                    bid = symbol_info.bid
                    ask = symbol_info.ask
                    
                    if bid <= 0 or ask <= 0:
                        logger.warning(f"⚠️ Prix invalides pour {symbol}: bid={bid}, ask={ask}")
                        continue
                    
                    # Préparer les données complètes comme attendu par le serveur
                    decision_data = {
                        "symbol": symbol,
                        "bid": float(bid),
                        "ask": float(ask),
                        "rsi": 50.0,  # Valeur neutre par défaut
                        "atr": 0.001,  # Valeur par défaut
                        "ema_fast_h1": float(bid),  # Corrigé: ema_fast -> ema_fast_h1
                        "ema_slow_h1": float(ask),  # Corrigé: ema_slow -> ema_slow_h1
                        "ema_fast_m1": float(bid),  # Ajouté: ema_fast_m1
                        "ema_slow_m1": float(ask),  # Ajouté: ema_slow_m1
                        "is_spike_mode": False,
                        "dir_rule": 0,
                        "supertrend_trend": 0,
                        "volatility_regime": 0,
                        "volatility_ratio": 1.0,
                        "timestamp": datetime.now().isoformat()  # Ajouté: timestamp requis
                    }
                    
                    # Envoyer les données complètes
                    response = requests.post(url, json=decision_data, timeout=5)
                    
                    if response.status_code == 200:
                        data = response.json()
                        if data and isinstance(data, dict):
                            logger.info(f"✅ Signal reçu depuis {api_url} pour {symbol}: {data.get('action', 'unknown')}")
                            return data
                        else:
                            logger.warning(f"⚠️ Format de réponse invalide depuis {api_url}")
                    elif response.status_code == 422:
                        logger.error(f"❌ Erreur 422 détail: {response.text}")
                    else:
                        logger.warning(f"⚠️ Erreur API {api_url} pour {symbol}: HTTP {response.status_code}")
                        
                except requests.exceptions.Timeout:
                    logger.warning(f"⌛ Timeout de la requête pour {symbol} sur {api_url}")
                    continue
                    
                except requests.exceptions.RequestException as e:
                    logger.warning(f"⚠️ Erreur de connexion à {api_url}: {str(e)}")
                    continue
                    
                except Exception as e:
                    logger.error(f"❌ Erreur inattendue avec {api_url} pour {symbol}: {str(e)}")
                    continue
            
            # Si on arrive ici, toutes les tentatives ont échoué
            logger.error(f"❌ Impossible de récupérer le signal pour {symbol} après plusieurs tentatives")
            return None
            
        except Exception as e:
            logger.error(f"❌ Erreur critique dans get_latest_signal pour {symbol}: {str(e)}")
            return None
            
    def update_dynamic_stop_loss(self, position):
        """Déplace dynamiquement le Stop Loss pour sécuriser les gains à chaque trade"""
        try:
            symbol = position.symbol
            ticket = position.ticket
            position_type = position.type
            entry_price = position.price_open
            current_price = position.price_current
            current_sl = position.sl
            current_tp = position.tp
            current_profit = position.profit
            
            # Obtenir les informations du symbole pour calculer les points
            symbol_info = mt5.symbol_info(symbol)
            if not symbol_info:
                return False
            
            point = symbol_info.point
            pip_value = point * 10  # 1 pip = 10 points pour la plupart des paires
            
            # Configuration du trailing stop dynamique
            trail_start_pips = 15  # Commencer le trailing après 15 pips de profit
            trail_distance_pips = 10  # Distance du trailing stop (10 pips derrière le prix)
            secure_profit_pips = 20  # Sécuriser le profit après 20 pips
            
            # Calculer le profit en pips
            if position_type == mt5.POSITION_TYPE_BUY:
                profit_pips = (current_price - entry_price) / pip_value
            else:  # SELL
                profit_pips = (entry_price - current_price) / pip_value
            
            # ===== STRATÉGIE 1: TRAILING STOP DYNAMIQUE =====
            if profit_pips >= trail_start_pips:
                new_sl = self.calculate_trailing_stop(position, current_price, trail_distance_pips, point)
                if new_sl and self.should_update_sl(current_sl, new_sl, position_type):
                    success = self.update_position_sl(ticket, symbol, new_sl, current_tp, "DYNAMIC_TRAIL")
                    if success:
                        logger.info(f"🔄 SL trailing dynamique: {symbol} | Nouveau SL: {new_sl} | Profit: {profit_pips:.1f} pips")
                        return True
            
            # ===== STRATÉGIE 2: SÉCURISATION PROFIT PARTIEL =====
            if profit_pips >= secure_profit_pips:
                new_sl = self.calculate_secure_sl(position, entry_price, current_price, point)
                if new_sl and self.should_update_sl(current_sl, new_sl, position_type):
                    success = self.update_position_sl(ticket, symbol, new_sl, current_tp, "PROFIT_SECURE")
                    if success:
                        logger.info(f"🔒 SL sécurisé: {symbol} | Nouveau SL: {new_sl} | Profit sécurisé: {profit_pips:.1f} pips")
                        return True
            
            # ===== STRATÉGIE 3: DÉPLACEMENT AU POINT D'ENTRÉE =====
            if profit_pips >= 10:  # Après 10 pips de profit
                if position_type == mt5.POSITION_TYPE_BUY and current_sl < entry_price:
                    success = self.update_position_sl(ticket, symbol, entry_price, current_tp, "BREAK_EVEN")
                    if success:
                        logger.info(f"⚖️ SL au point d'entrée: {symbol} | SL: {entry_price} | Profit: {profit_pips:.1f} pips")
                        return True
                elif position_type == mt5.POSITION_TYPE_SELL and (current_sl > entry_price or current_sl == 0):
                    success = self.update_position_sl(ticket, symbol, entry_price, current_tp, "BREAK_EVEN")
                    if success:
                        logger.info(f"⚖️ SL au point d'entrée: {symbol} | SL: {entry_price} | Profit: {profit_pips:.1f} pips")
                        return True
            
            return False
            
        except Exception as e:
            logger.error(f"Erreur mise à jour SL dynamique {position.symbol}: {e}")
            return False
    
    def calculate_trailing_stop(self, position, current_price, trail_distance_pips, point):
        """Calcule le nouveau niveau de trailing stop"""
        try:
            if position.type == mt5.POSITION_TYPE_BUY:
                # Pour BUY: SL suit le prix vers le haut
                new_sl = current_price - (trail_distance_pips * point * 10)
                return new_sl
            else:  # SELL
                # Pour SELL: SL suit le prix vers le bas
                new_sl = current_price + (trail_distance_pips * point * 10)
                return new_sl
        except Exception as e:
            logger.error(f"Erreur calcul trailing stop: {e}")
            return None
    
    def calculate_secure_sl(self, position, entry_price, current_price, point):
        """Calcule un SL sécurisé pour protéger une partie du profit"""
        try:
            if position.type == mt5.POSITION_TYPE_BUY:
                # Pour BUY: Sécuriser 50% du profit actuel
                profit = current_price - entry_price
                secure_amount = profit * 0.5
                new_sl = entry_price + secure_amount
                return new_sl
            else:  # SELL
                # Pour SELL: Sécuriser 50% du profit actuel
                profit = entry_price - current_price
                secure_amount = profit * 0.5
                new_sl = entry_price - secure_amount
                return new_sl
        except Exception as e:
            logger.error(f"Erreur calcul SL sécurisé: {e}")
            return None
    
    def should_update_sl(self, current_sl, new_sl, position_type):
        """Détermine si le SL doit être mis à jour"""
        try:
            if current_sl == 0:
                return True
            
            if position_type == mt5.POSITION_TYPE_BUY:
                # Pour BUY: le nouveau SL doit être plus élevé (meilleur protection)
                return new_sl > current_sl
            else:  # SELL
                # Pour SELL: le nouveau SL doit être plus bas (meilleur protection)
                return new_sl < current_sl or (current_sl == 0 and new_sl > 0)
        except Exception as e:
            logger.error(f"Erreur vérification mise à jour SL: {e}")
            return False
    
    def update_position_sl(self, ticket, symbol, new_sl, tp, reason):
        """Met à jour le Stop Loss d'une position"""
        try:
            request = {
                "action": mt5.TRADE_ACTION_SLTP,
                "symbol": symbol,
                "position": ticket,
                "sl": new_sl,
                "tp": tp,
                "type_time": mt5.ORDER_TIME_GTC,
                "comment": f"DYNAMIC_SL_{reason}"
            }
            
            result = mt5.order_send(request)
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                return True
            else:
                logger.error(f"❌ Erreur mise à jour SL {ticket}: {result.comment}")
                return False
                
        except Exception as e:
            logger.error(f"Erreur mise à jour SL: {e}")
            return False
    
    def monitor_dynamic_sl_all_positions(self):
        """Surveille et met à jour le SL dynamique pour toutes les positions (OPTIMISÉ)"""
        try:
            positions = mt5.positions_get()
            if not positions:
                return
            
            # Limiter à 5 positions maximum pour éviter de ramer
            max_positions_check = min(len(positions), 5)
            
            for i in range(max_positions_check):
                position = positions[i]
                # Uniquement les positions du robot (magic number)
                if position.magic == 123456:  # Magic number du robot
                    self.update_dynamic_stop_loss(position)
                    
        except Exception as e:
            logger.error(f"Erreur surveillance SL dynamique: {e}")
            
    def check_mt5_connection(self):
        """Vérifie et rétablit la connexion MT5 si nécessaire"""
        try:
            # Vérifier si la connexion est active
            if not mt5.initialize():
                logger.warning("🔌 Tentative de reconnexion à MT5...")
                
                # Essayer de se reconnecter avec les paramètres actuels
                if hasattr(self, 'mt5_login') and hasattr(self, 'mt5_password') and hasattr(self, 'mt5_server'):
                    connected = mt5.login(
                        login=self.mt5_login,
                        password=self.mt5_password,
                        server=self.mt5_server
                    )
                    
                    if connected:
                        logger.info("✅ Reconnexion à MT5 réussie")
                        return True
                    else:
                        logger.error(f"❌ Échec de la reconnexion à MT5: {mt5.last_error()}")
                        return False
                else:
                    logger.error("❌ Impossible de se reconnecter: informations de connexion manquantes")
                    return False
            return True
        except Exception as e:
            logger.error(f"❌ Erreur lors de la vérification de la connexion MT5: {str(e)}")
            return False
    
    def run(self):
        """Boucle principale ultra-optimisée pour trading réactif"""
        logger.info("🚀 Démarrage du client MT5 AI Ultra-Rapide")
        
        # Initialisation de la connexion MT5
        if not self.connect_mt5():
            logger.error("❌ Impossible de démarrer sans connexion MT5")
            return False
        
        # Tester le format de l'API pour éviter les erreurs 422
        logger.info("🔍 Test du format de requête API...")
        api_format = self.test_api_format()
        if api_format:
            logger.info(f"✅ Format API détecté: {api_format}")
        else:
            logger.warning("⚠️ Aucun format API fonctionnel détecté")
        
        # Initialisation des variables de timing
        last_aggressive_check = time.time()
        last_neutral_check = time.time()
        last_sl_check = time.time()
        last_connection_check = time.time()
        last_training_time = 0
        last_retrain_trigger_time = 0
        connection_retry_count = 0
        MAX_RETRIES = 3  # Nombre maximum de tentatives de reconnexion
        
        # ===== SYMBOLES PRIORITAIRES SEULEMENT =====
        priority_symbols = [
            'EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD',
            'EURGBP', 'EURJPY', 'GBPJPY', 'XAUUSD', 'XAGUSD',
            'BTCUSD', 'ETHUSD', 'Boom 500 Index', 'Crash 500 Index'
        ]
        
        self.symbols = []
        for symbol in priority_symbols:
            if mt5.symbol_info(symbol):
                self.symbols.append(symbol)
        
        logger.info(f"📊 {len(self.symbols)} symboles prioritaires chargés")
        
        last_training_time = 0
        last_retrain_trigger_time = 0
        
        try:
            while True:
                try:
                    current_time = time.time()
                    
                    # ===== VÉRIFICATIONS ESSENTIELLES SEULEMENT =====
                    self.check_positions()
                    self.auto_close_winners(1.0)
                    
                    # ===== TRADING ULTRA-RAPIDE =====
                    # Vérifier chaque symbole sans délai
                    for symbol in self.symbols:
                        try:
                            # Vérifier rapidement si on peut trader
                            if symbol not in self.positions:
                                signal_data = self.get_latest_signal(symbol)
                                if signal_data:
                                    # Trade immédiat si signal valide
                                    if self.execute_trade(symbol, signal_data):
                                        logger.info(f"⚡ Trade exécuté: {symbol}")
                        except Exception as e:
                            logger.debug(f"Erreur traitement {symbol}: {e}")
                    
                    # ===== SURVEILLANCE LÉGÈRE (toutes les 60 secondes) =====
                    if current_time - last_aggressive_check >= 60:
                        self.aggressive_strategy.check_active_strategies()
                        last_aggressive_check = current_time
                    
                    if current_time - last_neutral_check >= 60:
                        logger.info("📊 Surveillance des décisions neutres - désactivée")
                        last_neutral_check = current_time
                    
                    if current_time - last_sl_check >= 60:
                        self.monitor_dynamic_sl_all_positions()
                        last_sl_check = current_time
                    
                    # ===== ENVOI DONNÉES (toutes les heures) =====
                    if current_time - last_training_time > 3600:
                        self.send_training_data()
                        last_training_time = current_time
                    
                    if current_time - last_retrain_trigger_time > 6 * 3600:
                        self._trigger_continuous_learning()
                        last_retrain_trigger_time = current_time
                    
                    # Pause très courte pour réactivité
                    time.sleep(0.5)  # 500ms seulement
                    
                except KeyboardInterrupt:
                    logger.info("🛑 Arrêt demandé par l'utilisateur")
                    break
                except Exception as e:
                    logger.error(f"Erreur dans la boucle principale: {e}")
                    time.sleep(5)  # Pause en cas d'erreur
                    
        except KeyboardInterrupt:
            logger.info("🛑 Arrêt demandé par l'utilisateur")
        finally:
            # logger.info("👋 Client MT5 AI arrêté")
            logger.info("👋 Client MT5 AI arrêté")

if __name__ == "__main__":
    client = MT5AIClient()
    client.run()
