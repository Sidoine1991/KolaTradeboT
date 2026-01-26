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
from datetime import datetime, timedelta
from pathlib import Path

# Configuration des URLs de l'API
RENDER_API_URL = "https://kolatradebot.onrender.com"
LOCAL_API_URL = "http://localhost:5000"
TIMEFRAMES = ["M5"]  # Horizon M5 comme demandé
CHECK_INTERVAL = 60  # Secondes entre chaque vérification
MIN_CONFIDENCE = 0.70  # Confiance minimale pour prendre un trade (70% = 0.70)

# SL/TP par défaut (Boom/Crash, Volatility, Metals)
SL_PERCENTAGE_DEFAULT = 0.02  # 2%
TP_PERCENTAGE_DEFAULT = 0.04  # 4%

# SL/TP spécifiques Forex (pips plus larges)
SL_PERCENTAGE_FOREX = 0.01  # 1%
TP_PERCENTAGE_FOREX = 0.06  # 6%

# Tailles de position par type de symbole
POSITION_SIZES = {
    "Boom 300 Index": 0.2,
    "Boom 600 Index": 0.2,
    "Boom 900 Index": 0.2,
    "Crash 1000 Index": 0.2,
    "EURUSD": 0.01,
    "GBPUSD": 0.01,
    "USDJPY": 0.01
}

# Configuration logging - éviter les emojis pour PowerShell
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'mt5_ai_client_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mt5_ai_client")

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
        if buy_votes > sell_votes * 1.2:  # 20% de marge
            final_signal = 'BUY'
            final_confidence = buy_votes / len(signals)
        elif sell_votes > buy_votes * 1.2:
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

class MT5AIClient:
    def __init__(self):
        self.connected = False
        self.positions = {}
        self.symbol_detector = SymbolDetector()
        self.technical_analyzer = AdvancedTechnicalAnalyzer()
        self.garch_analyzer = GARCHVolatilityAnalyzer()
        self.feature_extractor = AdvancedFeatureExtractor()
        self.model_performance_cache = {}  # Cache pour performance des modèles

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
                if not self.symbol_detector.detect_symbols():
                    logger.error("Aucun symbole détecté")
                    return False
                
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
            
            if final_signal:
                logger.info(f"Signal {symbol} [{final_signal['source']}]: {final_signal['signal']} ({final_signal['confidence']*100:.1f}%)")
                return final_signal
            else:
                logger.info(f"Pas de signal valide pour {symbol}")
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
            # Pour les indices synthétiques, privilégier les signaux techniques
            weights = {'ml': 0.4, 'technical': 0.5, 'volatility': 0.05, 'features': 0.05}
        elif any(fx in symbol for fx in ["EUR", "GBP", "USD", "JPY"]):
            # Forex: équilibre entre technique et ML
            weights = {'ml': 0.4, 'technical': 0.4, 'volatility': 0.1, 'features': 0.1}
        else:
            # Autres: équilibré avec plus de poids sur la technique
            weights = {'ml': 0.35, 'technical': 0.45, 'volatility': 0.1, 'features': 0.1}

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

            # Seuil de confiance réduit à 45% (au lieu de 55%)
            if best_confidence >= 0.45 and best_signal != 'HOLD':  # Éviter HOLD comme meilleur signal
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
    
    def calculate_total_profit(self):
        """Calcule le profit total de toutes les positions"""
        total_profit = 0.0
        for pos_info in self.positions.values():
            profit = self.get_position_profit(pos_info["ticket"])
            total_profit += profit
        return total_profit
    
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
        
        # Choisir les pourcentages selon la catégorie
        category = self.symbol_detector.get_category(symbol)
        if category == "Forex":
            sl_pct = SL_PERCENTAGE_FOREX
            tp_pct = TP_PERCENTAGE_FOREX
        else:
            sl_pct = SL_PERCENTAGE_DEFAULT
            tp_pct = TP_PERCENTAGE_DEFAULT

        # Calculer les distances en prix selon le pourcentage sélectionné
        sl_distance_price = entry_price * sl_pct
        tp_distance_price = entry_price * tp_pct
        
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
        
        logger.info(
            f"SL/TP calculés pour {symbol}: Entry={entry_price}, SL={sl} ({sl_pct*100:.0f}%), TP={tp} ({tp_pct*100:.0f}%)"
        )
        
        return sl, tp
    
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
    
    def get_symbol_filling_mode(self, symbol):
        """Get the appropriate filling mode for a symbol"""
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            logger.error(f"Could not get symbol info for {symbol}")
            return None
            
        # Check available filling modes
        if hasattr(symbol_info, 'filling_mode'):
            if symbol_info.filling_mode & mt5.ORDER_FILLING_FOK:
                return mt5.ORDER_FILLING_FOK
            elif symbol_info.filling_mode & mt5.ORDER_FILLING_IOC:
                return mt5.ORDER_FILLING_IOC
            elif symbol_info.filling_mode & mt5.ORDER_FILLING_RETURN:
                return mt5.ORDER_FILLING_RETURN
        
        # Default to FOK if we can't determine the mode
        logger.warning(f"Could not determine filling mode for {symbol}, defaulting to FOK")
        return mt5.ORDER_FILLING_FOK

    def execute_trade(self, symbol, signal_data):
        """Exécute un trade basé sur le signal de l'IA avec détection automatique"""
        try:
            signal = signal_data.get('signal')
            confidence = signal_data.get('confidence', 0)
            
            # La confiance est en décimal (0-1), convertir en pourcentage pour comparaison
            confidence_percent = confidence * 100 if confidence <= 1.0 else confidence
            min_confidence_percent = MIN_CONFIDENCE * 100 if MIN_CONFIDENCE <= 1.0 else MIN_CONFIDENCE
            
            if confidence_percent < min_confidence_percent:
                logger.info(f"Confiance trop faible pour {symbol}: {confidence_percent:.1f}% < {min_confidence_percent:.1f}%")
                return False
            
            if signal not in ["BUY", "SELL"]:
                logger.info(f"Pas de signal trade pour {symbol}: {signal}")
                return False
            
            # Vérifier si nous avons déjà une position sur ce symbole
            if symbol in self.positions:
                logger.info(f"Position existante pour {symbol}, ignore")
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
                entry_price = plan["price"]
                request_type = plan["type"]
                action_type = mt5.TRADE_ACTION_PENDING
            else:
                entry_price = market_price
            
            # Calculer SL/TP proportionnels
            sl, tp = self.calculate_smart_sltp(symbol, entry_price, request_type)
            
            if sl is None or tp is None:
                logger.error(f"Impossible de calculer SL/TP pour {symbol}")
                return False
            
            # Get the appropriate filling mode for this symbol
            filling_mode = self.get_symbol_filling_mode(symbol)
            if filling_mode is None:
                logger.error(f"Impossible de déterminer le mode de remplissage pour {symbol}")
                return False
                
            # Créer la requête d'ordre avec SL/TP intelligents
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
            result = mt5.order_send(request)
            
            # Vérifier si result est None
            if result is None:
                last_error = mt5.last_error()
                logger.error(f"Echec ordre {symbol}: mt5.order_send() a retourné None - {last_error}")
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

    def run(self):
        """Boucle principale du client avec détection automatique des symboles"""
        logger.info("🚀 Demarrage du client MT5 AI Ultra-Optimisé")
        
        if not self.connect_mt5():
            logger.error("Impossible de demarrer sans connexion MT5")
            return
        
        last_training_time = 0
        
        try:
            while True:
                try:
                    # Vérifier les positions existantes
                    self.check_positions()
                    self.auto_close_winners(1.0)
                    
                    # Envoyer les données d'entraînement toutes les heures
                    current_time = time.time()
                    if current_time - last_training_time > 3600:  # 1 heure
                        self.send_training_data()
                        last_training_time = current_time
                    
                    # Demander des signaux pour chaque symbole détecté automatiquement
                    signals_data = {}
                    symbols_to_monitor = self.symbol_detector.get_symbols_by_priority()
                    
                    for symbol in symbols_to_monitor:
                        if symbol not in self.positions:  # Seulement si pas de position
                            signal_data = self.get_ai_signal(symbol)
                            signals_data[symbol] = signal_data
                            
                            if signal_data:
                                self.execute_trade(symbol, signal_data)
                    
                    # Afficher le dashboard avec catégories
                    dashboard.display_dashboard(self.positions, signals_data)
                    
                    # Synchroniser avec le web dashboard
                    self.sync_to_web_dashboard()
                    
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
    client = MT5AIClient()
    client.run()
