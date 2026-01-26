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

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
TIMEFRAMES = ["M5"]  # Horizon M5 comme demandé
CHECK_INTERVAL = 60  # Secondes entre chaque vérification
MIN_CONFIDENCE = 0.70  # Confiance minimale pour prendre un trade (70% = 0.70)

# SL/TP proportionnels au prix (plus réalistes)
SL_PERCENTAGE = 0.02  # 2% du prix pour SL
TP_PERCENTAGE = 0.04  # 4% du prix pour TP

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
    
    def get_position_profit(self, ticket):
        """Récupère le profit actuel d'une position"""
        position = mt5.positions_get(ticket=ticket)
        if position:
            return position[0].profit
        return 0.0

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
        """Combine tous les signaux avec pondération ultra-optimisée"""
        
        # Pondération de base selon type d'instrument
        if "Boom" in symbol or "Crash" in symbol:
            # Indices synthétiques: patterns artificiels → ML plus important
            weights = {'ml': 0.5, 'technical': 0.3, 'volatility': 0.1, 'features': 0.1}
        elif any(fx in symbol for fx in ["EUR", "GBP", "USD", "JPY"]):
            # Forex: volatilité et saisonnalité importantes
            weights = {'ml': 0.3, 'technical': 0.3, 'volatility': 0.25, 'features': 0.15}
        else:
            # Autres: équilibré
            weights = {'ml': 0.4, 'technical': 0.3, 'volatility': 0.15, 'features': 0.15}
        
        # Ajuster les poids selon la performance des modèles
        if ml_signal and 'model_accuracy' in ml_signal:
            accuracy = ml_signal['model_accuracy']
            if accuracy > 0.85:
                weights['ml'] = min(weights['ml'] + 0.1, 0.6)
            elif accuracy < 0.6:
                weights['ml'] = max(weights['ml'] - 0.1, 0.2)
                # Répartir le poids retiré
                weights['technical'] += 0.05
                weights['volatility'] += 0.05
        
        # Calculer les votes pondérés
        votes = {'BUY': 0, 'SELL': 0, 'HOLD': 0}
        total_confidence = 0
        
        # Signal ML
        if ml_signal:
            vote = ml_signal['signal']
            confidence = ml_signal['confidence'] * weights['ml']
            votes[vote] += confidence
            total_confidence += confidence
        
        # Signal technique
        if technical_signal:
            vote = technical_signal['signal']
            confidence = technical_signal['confidence'] * weights['technical']
            votes[vote] += confidence
            total_confidence += confidence
        
        # Signal volatilité
        if volatility_signal:
            vol_signal = volatility_signal['signal']
            vol_conf = volatility_signal['confidence'] * weights['volatility']
            
            # Convertir les signaux de volatilité en signaux de trading
            if vol_signal == "HIGH_VOL":
                # Haute volatilité: utiliser le signal technique comme base
                if technical_signal:
                    votes[technical_signal['signal']] += vol_conf * 0.5
                else:
                    votes['HOLD'] += vol_conf  # Prudence en haute vol
            elif vol_signal == "LOW_VOL":
                votes['HOLD'] += vol_conf  # Éviter le trading en basse vol
            
            total_confidence += vol_conf * 0.5
        
        # Features avancées
        if advanced_features:
            feature_confidence = weights['features']
            
            # RSI Divergence
            rsi_div = advanced_features.get('rsi_divergence')
            if rsi_div:
                if rsi_div > 70:
                    votes['SELL'] += feature_confidence * 0.3
                elif rsi_div < 30:
                    votes['BUY'] += feature_confidence * 0.3
            
            # Momentum
            momentum = advanced_features.get('price_momentum')
            if momentum and momentum.get('strength', 0) > 0.01:
                if momentum['momentum_trend'] > 0:
                    votes['BUY'] += feature_confidence * 0.2
                else:
                    votes['SELL'] += feature_confidence * 0.2
            
            # Market Regime
            regime = advanced_features.get('market_regime')
            if regime:
                if regime['regime'] == 'trending':
                    if regime['direction'] == 'bullish':
                        votes['BUY'] += feature_confidence * 0.3
                    elif regime['direction'] == 'bearish':
                        votes['SELL'] += feature_confidence * 0.3
                elif regime['regime'] == 'ranging':
                    votes['HOLD'] += feature_confidence * 0.2
            
            total_confidence += feature_confidence
        
        # Décider du signal final
        if total_confidence == 0:
            return None
        
        # Trouver le signal avec le plus de votes
        best_signal = max(votes, key=votes.get)
        best_confidence = votes[best_signal] / total_confidence
        
        # Seuil minimum de confiance (abaissé à 55 %)
        if best_confidence < 0.55:
            return None
        
        # Si HOLD gagne, vérifier s'il domine réellement
        if best_signal == 'HOLD' and votes['HOLD'] > max(votes['BUY'], votes['SELL']):
            return None
        
        # Créer le signal final
        final_signal = {
            'signal': best_signal,
            'confidence': best_confidence,
            'stop_loss': ml_signal.get('stop_loss') if ml_signal else None,
            'take_profit': ml_signal.get('take_profit') if ml_signal else None,
            'source': f'Ultra_Ensemble_ML{weights["ml"]:.1f}_Tech{weights["technical"]:.1f}_Vol{weights["volatility"]:.1f}_Feat{weights["features"]:.1f}',
            'timeframe': 'M5',
            'horizon': 'M5',
            'weights': weights,
            'votes': votes,
            'components': {
                'ml_signal': ml_signal,
                'technical_signal': technical_signal,
                'volatility_signal': volatility_signal,
                'advanced_features': advanced_features
            }
        }
        
        return final_signal
    
    def sync_to_web_dashboard(self):
        """Synchronise les données avec le web dashboard"""
        try:
            # Récupérer les signaux récents pour tous les symboles surveillés
            signals_data = {}
            monitored_symbols = set()
            
            # Récupérer les symboles depuis le détecteur
            if hasattr(self.symbol_detector, 'all_symbols') and self.symbol_detector.all_symbols:
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
            for symbol, pos_info in self.positions.items():
                profit = self.get_position_profit(pos_info["ticket"])
                total_profit += profit
                positions_data[symbol] = {
                    'type': pos_info.get('type', 'NONE'),
                    'price': pos_info.get('price', 0.0),
                    'profit': profit,
                    'ticket': pos_info.get('ticket', 0),
                    'volume': pos_info.get('volume', 0.0),
                    'open_time': pos_info.get('open_time', datetime.now()).isoformat() if isinstance(pos_info.get('open_time'), datetime) else str(pos_info.get('open_time', ''))
                }
            
            # Récupérer les statistiques de trading depuis l'historique MT5
            trading_stats = self.get_trading_statistics()
            
            # Récupérer les métriques ML
            ml_metrics_data = self.get_ml_metrics()
            if ml_metrics_data:
                # Normaliser les métriques ML
                ml_metrics_normalized = {
                    'accuracy': ml_metrics_data.get('accuracy', 0.0),
                    'model_name': ml_metrics_data.get('modelName', 'Unknown'),
                    'last_update': ml_metrics_data.get('lastUpdate', int(time.time())),
                    'status': 'Available'
                }
            else:
                ml_metrics_normalized = {
                    'accuracy': 0.0,
                    'model_name': 'Unknown',
                    'last_update': int(time.time()),
                    'status': 'Not Available'
                }
            
            # Préparer les données à synchroniser
            sync_data = {
                'positions': positions_data,
                'signals': signals_data,
                'performance': {
                    'total_profit': total_profit,
                    'active_positions': len(self.positions),
                    'active_signals': len([s for s in signals_data.values() if s.get('signal') not in ['WAIT', 'ERROR']]),
                    'last_update': datetime.now().strftime('%H:%M:%S')
                },
                'trading_stats': trading_stats,
                'ml_metrics': ml_metrics_normalized
            }
            
            # Envoyer au web dashboard
            response = requests.post(
                "http://localhost:5000/api/sync",
                json=sync_data,
                timeout=5
            )
            
            if response.status_code == 200:
                logger.debug("✅ Données synchronisées avec le web dashboard")
            else:
                logger.warning(f"⚠️ Erreur synchronisation web dashboard: {response.status_code}")
                
        except Exception as e:
            logger.warning(f"⚠️ Erreur synchronisation web dashboard: {e}")
    
    def get_trading_statistics(self):
        """Récupère les statistiques de trading depuis l'historique MT5"""
        try:
            if not self.connected:
                return {
                    'total_trades': 0,
                    'winning_trades': 0,
                    'losing_trades': 0,
                    'win_rate': 0.0,
                    'total_profit': 0.0,
                    'total_loss': 0.0,
                    'profit_factor': 0.0
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
                "comment": f"AI-{signal}-{category}",  # shorter comment to comply with MT5 limits
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_RETURN,  # Changed to RETURN for broader compatibility
            }
            
            # Logger les détails pour debug
            logger.info(f"Tentative ordre {signal} {symbol} [{category}]:")
            logger.info(f"  Entry: {entry_price}")
            logger.info(f"  SL: {sl} ({SL_PERCENTAGE*100:.0f}% du prix)")
            logger.info(f"  TP: {tp} ({TP_PERCENTAGE*100:.0f}% du prix)")
            logger.info(f"  Volume: {position_size}")
            logger.info(f"  Risk/Reward: 1:{TP_PERCENTAGE/SL_PERCENTAGE:.1f}")
            
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
                "signal": signal_data.get('signal'),
                "confidence": signal_data.get('confidence'),
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
            
        except Exception as e:
            logger.warning(f"Erreur feedback {symbol}: {e}")
    
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
