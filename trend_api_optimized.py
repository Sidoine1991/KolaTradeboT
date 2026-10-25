#!/usr/bin/env python3
"""
API Trend Optimisée pour TradBOT - Port 8001
Version optimisée pour réduire l'impact sur MetaTrader 5
"""

import json
import http.server
import socketserver
import threading
import time
import requests
from datetime import datetime, timedelta
from pathlib import Path
import pandas as pd
import numpy as np

# Importer l'optimiseur de performance
try:
    from optimize_ea_performance import performance_optimizer, optimize_for_mt5
    PERFORMANCE_OPTIMIZER_AVAILABLE = True
except ImportError:
    PERFORMANCE_OPTIMIZER_AVAILABLE = False
    print("⚠️ Optimiseur de performance non disponible")

# Importer le prédicteur avancé
try:
    from advanced_spike_predictor import get_advanced_prediction, get_prediction_accuracy
    ADVANCED_PREDICTOR_AVAILABLE = True
except ImportError:
    ADVANCED_PREDICTOR_AVAILABLE = False
    print("⚠️ Prédicteur avancé non disponible")

# Configuration optimisée
API_PORT = 8001
TREND_CACHE_DURATION = 60  # Cache plus long pour MT5
TREND_DATA_FILE = Path("trend_data.json")

# Cache global pour réduire les calculs
global_cache = {}
cache_timestamps = {}

class OptimizedTrendHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        """Gestion optimisée des requêtes GET"""
        try:
            # Optimisation: réponse rapide pour les requêtes fréquentes
            if self.path == "/":
                response = {
                    "message": "TradBOT Trend API Optimisée", 
                    "endpoints": ["/trend", "/health", "/status", "/performance"],
                    "status": "running",
                    "port": API_PORT,
                    "optimized": True
                }
            elif self.path == "/health":
                response = {
                    "status": "ok", 
                    "timestamp": time.time(),
                    "cache_duration": TREND_CACHE_DURATION,
                    "optimized": True
                }
            elif self.path.startswith("/trend"):
                # Endpoint principal optimisé pour l'EA
                symbol = self.get_query_param("symbol", "EURUSD")
                timeframe = self.get_query_param("timeframe", "M1")
                
                # Utiliser le cache optimisé
                response = self.get_optimized_trend_data(symbol, timeframe)
            elif self.path == "/status":
                response = self.get_api_status()
            elif self.path == "/performance":
                response = self.get_performance_info()
            else:
                self.send_response(404)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"detail": "Not Found"}).encode())
                return
            
            # Envoi de la réponse optimisée
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Cache-Control', 'max-age=30')  # Cache navigateur
            self.end_headers()
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        except Exception as e:
            self.send_error_response(f"Erreur API optimisée: {str(e)}")
    
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
                            return value
        except Exception as e:
            print(f"Erreur parsing query: {e}")
        return default_value
    
    def get_optimized_trend_data(self, symbol, timeframe):
        """Génère les données de tendance optimisées"""
        try:
            # Vérifier le cache global d'abord
            cache_key = f"{symbol}_{timeframe}"
            if self._is_cache_valid(cache_key):
                cached_data = global_cache[cache_key]
                print(f"📦 Cache hit pour {symbol}")
                return cached_data
            
            # Utiliser l'optimiseur de performance si disponible
            if PERFORMANCE_OPTIMIZER_AVAILABLE:
                optimized_data = performance_optimizer.optimize_api_calls(symbol)
                if optimized_data:
                    # Enrichir avec les données avancées si disponible
                    if ADVANCED_PREDICTOR_AVAILABLE:
                        advanced_data = get_advanced_prediction(symbol)
                        if advanced_data:
                            optimized_data.update({
                                "spike_probability": advanced_data.get('spike_probability', 0.5),
                                "time_to_spike": advanced_data.get('time_to_spike', 300),
                                "stop_loss": advanced_data.get('stop_loss', 0),
                                "take_profit": advanced_data.get('take_profit', 0),
                                "lot_size": advanced_data.get('lot_size', 0.1),
                                "reasoning": advanced_data.get('reasoning', 'Analyse optimisée')
                            })
                    
                    # Mettre en cache
                    self._store_in_cache(cache_key, optimized_data)
                    return optimized_data
            
            # Fallback vers la méthode de base optimisée
            trend_data = self._get_basic_trend_data_optimized(symbol, timeframe)
            
            # Mettre en cache
            self._store_in_cache(cache_key, trend_data)
            
            return trend_data
            
        except Exception as e:
            print(f"Erreur génération tendance optimisée: {e}")
            return self._get_fallback_data(symbol, timeframe)
    
    def _is_cache_valid(self, cache_key):
        """Vérifie si le cache est valide"""
        if cache_key in global_cache and cache_key in cache_timestamps:
            age = time.time() - cache_timestamps[cache_key]
            return age < TREND_CACHE_DURATION
        return False
    
    def _store_in_cache(self, cache_key, data):
        """Stocke les données dans le cache global"""
        global_cache[cache_key] = data
        cache_timestamps[cache_key] = time.time()
        
        # Limiter la taille du cache
        if len(global_cache) > 20:
            # Supprimer les entrées les plus anciennes
            oldest_key = min(cache_timestamps.keys(), 
                           key=lambda k: cache_timestamps[k])
            del global_cache[oldest_key]
            del cache_timestamps[oldest_key]
    
    def _get_basic_trend_data_optimized(self, symbol, timeframe):
        """Méthode de base optimisée pour les données de tendance"""
        # Calculs simplifiés pour réduire la charge CPU
        hour = datetime.now().hour
        
        # Simulation optimisée
        trend_direction = "BUY" if hour % 2 == 0 else "SELL"
        trend_strength = 60 + (hour % 40)  # 60-100
        confidence = "high" if trend_strength > 80 else "medium"
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "trend_direction": trend_direction,
            "trend_strength": trend_strength,
            "confidence": confidence,
            "support_levels": [1.0800, 1.0750, 1.0700],
            "resistance_levels": [1.0900, 1.0950, 1.1000],
            "volatility": 1.2,
            "spike_probability": 0.7,
            "trading_signal": "TRADE" if trend_strength > 75 else "MONITOR",
            "risk_level": "MEDIUM",
            "time_to_spike": 180,
            "stop_loss": 0,
            "take_profit": 0,
            "lot_size": 0.1,
            "reasoning": "Analyse optimisée pour MT5"
        }
    
    def _get_fallback_data(self, symbol, timeframe):
        """Données de fallback en cas d'erreur"""
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": time.time(),
            "trend_direction": "HOLD",
            "trend_strength": 50,
            "confidence": "medium",
            "trading_signal": "MONITOR",
            "spike_probability": 0.5,
            "risk_level": "MEDIUM",
            "reasoning": "Mode fallback - données par défaut"
        }
    
    def get_api_status(self):
        """Retourne le statut de l'API optimisée"""
        return {
            "status": "running",
            "port": API_PORT,
            "uptime": time.time(),
            "optimized": True,
            "cache_size": len(global_cache),
            "cache_duration": TREND_CACHE_DURATION,
            "performance_optimizer": PERFORMANCE_OPTIMIZER_AVAILABLE,
            "advanced_predictor": ADVANCED_PREDICTOR_AVAILABLE,
            "endpoints": {
                "/trend": "Données de tendance optimisées pour l'EA",
                "/health": "Vérification santé API",
                "/status": "Statut détaillé",
                "/performance": "Informations de performance"
            }
        }
    
    def get_performance_info(self):
        """Retourne les informations de performance"""
        if PERFORMANCE_OPTIMIZER_AVAILABLE:
            return performance_optimizer.get_performance_stats()
        else:
            return {
                "status": "optimizer_not_available",
                "cache_size": len(global_cache),
                "cache_duration": TREND_CACHE_DURATION
            }
    
    def send_error_response(self, error_message):
        """Envoie une réponse d'erreur optimisée"""
        self.send_response(500)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({"error": error_message}).encode())
    
    def log_message(self, format, *args):
        """Supprime les logs par défaut pour réduire le bruit"""
        pass

def cleanup_cache():
    """Nettoie le cache global périodiquement"""
    while True:
        time.sleep(300)  # Nettoyer toutes les 5 minutes
        current_time = time.time()
        
        expired_keys = []
        for key, timestamp in cache_timestamps.items():
            if current_time - timestamp > TREND_CACHE_DURATION * 2:
                expired_keys.append(key)
        
        for key in expired_keys:
            if key in global_cache:
                del global_cache[key]
            if key in cache_timestamps:
                del cache_timestamps[key]
        
        if expired_keys:
            print(f"🧹 Cache nettoyé: {len(expired_keys)} entrées supprimées")

def start_optimized_trend_api():
    """Démarre le serveur API Trend optimisé"""
    try:
        print(f"🚀 Démarrage de l'API Trend Optimisée TradBOT sur le port {API_PORT}...")
        
        # Configurer l'optimiseur pour MT5
        if PERFORMANCE_OPTIMIZER_AVAILABLE:
            optimize_for_mt5()
            print("✅ Optimiseur de performance configuré pour MT5")
        
        # Démarrer le nettoyage du cache en arrière-plan
        cleanup_thread = threading.Thread(target=cleanup_cache, daemon=True)
        cleanup_thread.start()
        
        # Créer le fichier de données s'il n'existe pas
        if not TREND_DATA_FILE.exists():
            initial_data = {
                "symbol": "EURUSD",
                "timeframe": "M1",
                "timestamp": time.time(),
                "trend_direction": "neutral",
                "trend_strength": 50,
                "confidence": "medium",
                "optimized": True
            }
            with open(TREND_DATA_FILE, 'w', encoding='utf-8') as f:
                json.dump(initial_data, f, indent=2)
            print(f"✅ Fichier {TREND_DATA_FILE} créé")
        
        # Démarrer le serveur
        with socketserver.TCPServer(("", API_PORT), OptimizedTrendHandler) as httpd:
            print(f"✅ API Trend Optimisée démarrée avec succès sur http://localhost:{API_PORT}")
            print(f"📊 Endpoints disponibles:")
            print(f"   - http://localhost:{API_PORT}/trend?symbol=EURUSD&timeframe=M1")
            print(f"   - http://localhost:{API_PORT}/health")
            print(f"   - http://localhost:{API_PORT}/status")
            print(f"   - http://localhost:{API_PORT}/performance")
            print(f"📁 Fichier de données: {TREND_DATA_FILE.absolute()}")
            print(f"⚡ Optimisations MT5: Activées")
            print(f"📦 Cache: {TREND_CACHE_DURATION}s")
            print(f"🔄 Appuyez sur Ctrl+C pour arrêter")
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print(f"\n🛑 Arrêt de l'API Trend Optimisée...")
    except Exception as e:
        print(f"❌ Erreur démarrage API Trend Optimisée: {e}")

if __name__ == "__main__":
    start_optimized_trend_api()
