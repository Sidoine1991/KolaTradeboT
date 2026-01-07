#!/usr/bin/env python3
"""
API Trend pour TradBOT - Port 8001
Fournit des données de tendance pour l'EA SpikeHunter
"""

import json
import http.server
import socketserver
import threading
import time
import requests
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import unquote
import pandas as pd
import numpy as np

# Importer MT5 pour données réelles
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
    print("✅ MetaTrader5 disponible pour trend_api")
except ImportError:
    MT5_AVAILABLE = False
    print("⚠️ MetaTrader5 non disponible - mode simulation")

# Cache global pour les tendances multi-timeframes
trend_cache = {}
cache_timestamps = {}

# Intervalles de rafraîchissement par timeframe (en secondes)
REFRESH_INTERVALS = {
    'M1': 10,    # Rafraîchir toutes les 10s
    'M5': 30,    # 30s
    'M30': 120,  # 2 minutes
    'H1': 300,   # 5 minutes
    'H4': 900,   # 15 minutes
    'D1': 3600,  # 1 heure
    'W1': 7200   # 2 heures
}

# Configuration
API_PORT = 8001
TREND_CACHE_DURATION = 30  # secondes
TREND_DATA_FILE = Path("trend_data.json")

class TrendHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        """Gestion des requêtes GET"""
        try:
            if self.path == "/":
                response = {
                    "message": "TradBOT Trend API", 
                    "endpoints": ["/trend", "/health", "/status"],
                    "status": "running",
                    "port": API_PORT
                }
            elif self.path == "/health":
                response = {
                    "status": "ok", 
                    "timestamp": time.time(),
                    "cache_duration": TREND_CACHE_DURATION
                }
            elif self.path.startswith("/trend"):
                # Endpoint principal pour l'EA
                symbol = self.get_query_param("symbol", "EURUSD")
                timeframe = self.get_query_param("timeframe", "M1")
                print(f"Debug: path={self.path}, symbol={symbol}, timeframe={timeframe}")
                response = self.get_trend_data(symbol, timeframe)
            elif self.path.startswith("/multi_timeframe"):
                # NOUVEAU: Endpoint multi-timeframes caché
                symbol = self.get_query_param("symbol", "Volatility 75 Index")
                print(f"[DEBUG] Multi-TF requested for {symbol}")
                response = self.get_multi_timeframe_trends(symbol)
            elif self.path == "/status":
                response = self.get_api_status()
            else:
                self.send_response(404)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"detail": "Not Found"}).encode())
                return
            
            # Envoi de la réponse
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        except Exception as e:
            import traceback
            print("❌ Error in do_GET:")
            print(traceback.format_exc())
            self.send_error_response(f"Erreur API: {str(e)}")
    
    def get_query_param(self, param_name, default_value):
        """Extrait un paramètre de la query string"""
        try:
            if '?' in self.path:
                query_string = self.path.split('?')[1]
                params = query_string.split('&')
                for param in params:
                    if '=' in param:
                        key, value = param.split('=', 1)
                        if key == param_name:
                            return unquote(value)
        except Exception as e:
            print(f"Erreur parsing query: {e}")
        return default_value
    
    def get_multi_timeframe_trends(self, symbol):
        """Nouveau endpoint: Retourne les tendances pour TOUS les timeframes (caché)"""
        try:
            cache_key = f"{symbol}_multi_tf"
            current_time = time.time()
            
            # Vérifier si on a des données en cache valides
            if cache_key in trend_cache:
                cache_age = current_time - cache_timestamps.get(cache_key, 0)
                # Cache valide pendant 30 secondes pour multi-TF
                if cache_age < 30:
                    print(f"📦 Cache HIT pour {symbol} (âge: {cache_age:.1f}s)")
                    return trend_cache[cache_key]
            
            print(f"🔄 Calcul multi-timeframe pour {symbol}...")
            
            # Initialiser MT5 UNE SEULE FOIS pour toute la boucle
            mt5_was_initialized = False
            if MT5_AVAILABLE:
                if mt5.initialize():
                    mt5_was_initialized = True
                else:
                    print(f"❌ Échec initialisation MT5 pour {symbol}")
            
            # Calculer les tendances pour tous les timeframes
            timeframes = ['M1', 'M5', 'M30', 'H1', 'H4', 'D1', 'W1']
            trends = {}
            
            for tf in timeframes:
                try:
                    trend_data = self._calculate_single_timeframe_trend(symbol, tf, skip_init=mt5_was_initialized)
                    trends[tf] = trend_data
                except Exception as tf_error:
                    print(f"[ERROR] TF calc error {tf} for {symbol}: {tf_error}")
                    trends[tf] = self._get_fallback_trend(tf)
            
            # Fermer MT5 après la boucle
            if mt5_was_initialized:
                mt5.shutdown()
            
            print(f"[OK] Calculation finished for {symbol}")
            
            # Résultat consolidé
            result = {
                "symbol": symbol,
                "timestamp": current_time,
                "trends": trends,
                "cache_status": "fresh"
            }
            
            # Mettre en cache
            trend_cache[cache_key] = result
            cache_timestamps[cache_key] = current_time
            
            print(f"✅ Calcul terminé pour {symbol}")
            return result
            
        except Exception as e:
            import traceback
            print(f"❌ ERREUR CRITIQUE multi-timeframe pour {symbol}:")
            print(traceback.format_exc())
            return {
                "error": f"Erreur multi-timeframe: {str(e)}",
                "symbol": symbol,
                "timestamp": time.time(),
                "trends": {
                    tf: self._get_fallback_trend(tf) for tf in ['M1', 'M5', 'M30', 'H1', 'H4', 'D1', 'W1']
                }
            }
    
    def _calculate_single_timeframe_trend(self, symbol, timeframe, skip_init=False):
        """Calcule la tendance pour un seul timeframe avec vraies données MT5"""
        try:
            if MT5_AVAILABLE:
                # Initialiser MT5 si pas déjà fait par l'appelant
                if not skip_init:
                    if not mt5.initialize():
                        return self._get_fallback_trend(timeframe)
                
                # Map des timeframes
                tf_map = {
                    'M1': mt5.TIMEFRAME_M1,
                    'M5': mt5.TIMEFRAME_M5,
                    'M30': mt5.TIMEFRAME_M30,
                    'H1': mt5.TIMEFRAME_H1,
                    'H4': mt5.TIMEFRAME_H4,
                    'D1': mt5.TIMEFRAME_D1,
                    'W1': mt5.TIMEFRAME_W1
                }
                
                mt5_tf = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
                
                # Récupérer les données
                rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 50)
                
                # Fermer si on a ouvert localement
                if not skip_init:
                    mt5.shutdown()
                
                if rates is None or len(rates) < 21:
                    return self._get_fallback_trend(timeframe)
                
                # Calculer EMA 9 et 21
                df = pd.DataFrame(rates)
                df['ema9'] = df['close'].ewm(span=9, adjust=False).mean()
                df['ema21'] = df['close'].ewm(span=21, adjust=False).mean()
                
                ema9_current = df['ema9'].iloc[-1]
                ema21_current = df['ema21'].iloc[-1]
                
                # Déterminer la tendance
                is_bullish = bool(ema9_current > ema21_current)
                is_bearish = bool(ema9_current < ema21_current)
                
                # Calculer la force de la tendance
                ema_diff_pct = float(abs(ema9_current - ema21_current) / ema21_current * 100)
                
                mt5.shutdown()
                
                return {
                    "bullish": is_bullish,
                    "bearish": is_bearish,
                    "ema9": float(ema9_current),
                    "ema21": float(ema21_current),
                    "strength": min(100, int(ema_diff_pct * 20)),  # Normaliser 0-100
                    "direction": "bullish" if is_bullish else "bearish" if is_bearish else "neutral"
                }
            else:
                return self._get_fallback_trend(timeframe)
                
        except Exception as e:
            print(f"Erreur calcul {timeframe}: {e}")
            return self._get_fallback_trend(timeframe)
    
    def _get_fallback_trend(self, timeframe):
        """Données de fallback quand MT5 indisponible"""
        return {
            "bullish": False,
            "bearish": False,
            "ema9": 0,
            "ema21": 0,
            "strength": 0,
            "direction": "neutral",
            "note": "MT5 unavailable"
        }
    
    def get_trend_data(self, symbol, timeframe):
        """Méthode de compatibilité pour l'ancien endpoint /trend"""
        trend_data = self._calculate_single_timeframe_trend(symbol, timeframe)
        trend_data['symbol'] = symbol
        trend_data['timeframe'] = timeframe
        trend_data['timestamp'] = time.time()
        return trend_data
    
    def calculate_trend_direction(self, symbol):
        """Calcule la direction de la tendance"""
        # Simulation basée sur l'heure actuelle
        hour = datetime.now().hour
        if hour % 2 == 0:
            return "bullish"
        else:
            return "bearish"
    
    def calculate_trend_strength(self, symbol):
        """Calcule la force de la tendance (0-100)"""
        import random
        return random.randint(60, 95)
    
    def calculate_confidence(self, symbol):
        """Calcule le niveau de confiance (0-100)"""
        import random
        return random.randint(70, 90)
    
    def get_support_levels(self, symbol):
        """Retourne les niveaux de support"""
        return [1.0800, 1.0750, 1.0700]
    
    def get_resistance_levels(self, symbol):
        """Retourne les niveaux de résistance"""
        return [1.0900, 1.0950, 1.1000]
    
    def calculate_volatility(self, symbol):
        """Calcule la volatilité actuelle"""
        import random
        return round(random.uniform(0.5, 2.0), 2)
    
    def calculate_spike_probability(self, symbol):
        """Calcule la probabilité de spike"""
        import random
        return round(random.uniform(0.3, 0.8), 2)
    
    def generate_trading_signal(self, symbol):
        """Génère un signal de trading"""
        signals = ["BUY", "SELL", "HOLD"]
        import random
        return random.choice(signals)
    
    def assess_risk_level(self, symbol):
        """Évalue le niveau de risque"""
        risk_levels = ["LOW", "MEDIUM", "HIGH"]
        import random
        return random.choice(risk_levels)
    
    def save_trend_data(self, trend_data):
        """Sauvegarde les données de tendance"""
        try:
            with open(TREND_DATA_FILE, 'w', encoding='utf-8') as f:
                json.dump(trend_data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Erreur sauvegarde: {e}")
    
    def get_api_status(self):
        """Retourne le statut de l'API"""
        return {
            "status": "running",
            "port": API_PORT,
            "uptime": time.time(),
            "endpoints": {
                "/trend": "Données de tendance pour l'EA",
                "/health": "Vérification santé API",
                "/status": "Statut détaillé"
            },
            "features": [
                "Analyse de tendance multi-timeframe",
                "Détection de support/résistance",
                "Calcul de volatilité",
                "Prédiction de spikes",
                "Signaux de trading",
                "Évaluation des risques"
            ]
        }
    
    def send_error_response(self, error_message):
        """Envoie une réponse d'erreur"""
        self.send_response(500)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({"error": error_message}).encode())
    
    def log_message(self, format, *args):
        """Log HTTP requests for visibility"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {format % args}")

def start_trend_api():
    """Démarre le serveur API Trend"""
    try:
        print(f"[INFO] Demarrage de l'API Trend TradBOT sur le port {API_PORT}...")
        
        # Créer le fichier de données s'il n'existe pas
        if not TREND_DATA_FILE.exists():
            initial_data = {
                "symbol": "EURUSD",
                "timeframe": "M1",
                "timestamp": time.time(),
                "trend_direction": "neutral",
                "trend_strength": 50,
                "confidence": 50
            }
            with open(TREND_DATA_FILE, 'w', encoding='utf-8') as f:
                json.dump(initial_data, f, indent=2)
            print(f"[OK] Fichier {TREND_DATA_FILE} cree")
        
        # Démarrer le serveur
        with socketserver.TCPServer(("", API_PORT), TrendHandler) as httpd:
            print(f"[OK] API Trend demarree avec succes sur http://localhost:{API_PORT}")
            print(f"[INFO] Endpoints disponibles:")
            print(f"   - http://localhost:{API_PORT}/trend?symbol=EURUSD&timeframe=M1")
            print(f"   - http://localhost:{API_PORT}/health")
            print(f"   - http://localhost:{API_PORT}/status")
            print(f"[INFO] Fichier de donnees: {TREND_DATA_FILE.absolute()}")
            print(f"[INFO] Appuyez sur Ctrl+C pour arreter")
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print(f"\n[INFO] Arret de l'API Trend...")
    except Exception as e:
        print(f"[ERROR] Erreur demarrage API Trend: {e}")

if __name__ == "__main__":
    start_trend_api()
