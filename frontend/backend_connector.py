"""
Connecteur entre le frontend Streamlit et le backend API
Intégration avec ai_server.py pour les fonctionnalités IA
"""

import requests
import json
import time
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime
import pandas as pd
import numpy as np

logger = logging.getLogger("backend_connector")

class BackendConnector:
    """Connecteur principal pour communiquer avec le backend et ai_server"""
    
    def __init__(self, backend_url: str = "http://localhost:8000", ai_server_url: str = "http://localhost:8000"):
        self.backend_url = backend_url
        self.ai_server_url = ai_server_url
        self.session = requests.Session()
        self.session.timeout = 10
        
    def _make_request(self, url: str, method: str = "GET", data: Dict = None, params: Dict = None) -> Dict:
        """Effectue une requête HTTP avec gestion d'erreurs"""
        try:
            if method == "GET":
                response = self.session.get(url, params=params)
            elif method == "POST":
                response = self.session.post(url, json=data)
            else:
                raise ValueError(f"Méthode {method} non supportée")
            
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.Timeout:
            logger.error(f"Timeout pour {url}")
            return {"status": "error", "detail": "Timeout"}
        except requests.exceptions.ConnectionError:
            logger.error(f"Erreur de connexion pour {url}")
            return {"status": "error", "detail": "Connexion refusée"}
        except requests.exceptions.RequestException as e:
            logger.error(f"Erreur requête {url}: {e}")
            return {"status": "error", "detail": str(e)}
        except json.JSONDecodeError as e:
            logger.error(f"Erreur JSON decode {url}: {e}")
            return {"status": "error", "detail": "Réponse JSON invalide"}
    
    # ==================== ENDPOINTS BACKEND API ====================
    
    def get_symbols(self) -> List[str]:
        """Récupère la liste des symboles disponibles"""
        result = self._make_request(f"{self.backend_url}/symbols")
        return result if isinstance(result, list) else []
    
    def get_timeframes(self) -> List[str]:
        """Récupère la liste des timeframes disponibles"""
        result = self._make_request(f"{self.backend_url}/timeframes")
        return result if isinstance(result, list) else []
    
    def get_trend_summary(self, symbol: str, nocache: int = 0) -> Dict:
        """Récupère la tendance multi-timeframe pour un symbole"""
        params = {"symbol": symbol}
        if nocache:
            params["nocache"] = nocache
        return self._make_request(f"{self.backend_url}/trend_summary", params=params)
    
    def get_real_time_price(self, symbol: str) -> Dict:
        """Récupère le prix actuel d'un symbole"""
        return self._make_request(f"{self.backend_url}/real_time_price", params={"symbol": symbol})
    
    def get_support_resistance_zones(self, symbol: str, timeframe: str = "5m", count: int = 200) -> List:
        """Récupère les zones de support/résistance"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count}
        return self._make_request(f"{self.backend_url}/support_resistance_zones", params=params)
    
    def send_signal_now(self, symbol: str) -> Dict:
        """Génère et envoie immédiatement un signal pour un symbole"""
        return self._make_request(f"{self.backend_url}/send_signal_now", params={"symbol": symbol})
    
    def send_mtf_signal(self, symbol: str) -> Dict:
        """Génère et envoie un signal multi-timeframe"""
        return self._make_request(f"{self.backend_url}/send_mtf_signal", params={"symbol": symbol})
    
    def analyze_signal_quality(self, symbol: str) -> Dict:
        """Analyse la qualité d'un signal sans l'envoyer"""
        return self._make_request(f"{self.backend_url}/analyze_signal_quality", params={"symbol": symbol})
    
    def get_detailed_signal(self, symbol: str) -> Dict:
        """Génère un signal détaillé avec SL/TP"""
        return self._make_request(f"{self.backend_url}/send_detailed_signal", params={"symbol": symbol})
    
    # ==================== ENDPOINTS INDICATEURS ====================
    
    def get_market_structure(self, symbol: str, timeframe: str = "5m", count: int = 200) -> Dict:
        """Récupère l'analyse de structure de marché"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count}
        return self._make_request(f"{self.backend_url}/indicators/market_structure", params=params)
    
    def get_smart_money(self, symbol: str, timeframe: str = "5m", count: int = 200) -> Dict:
        """Récupère l'analyse Smart Money"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count}
        return self._make_request(f"{self.backend_url}/indicators/smart_money", params=params)
    
    def get_vwap(self, symbol: str, timeframe: str = "5m", count: int = 200) -> Dict:
        """Récupère le VWAP"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count}
        return self._make_request(f"{self.backend_url}/indicators/vwap", params=params)
    
    def get_supertrend(self, symbol: str, timeframe: str = "5m", count: int = 200, period: int = 10, multiplier: float = 3.0) -> Dict:
        """Récupère le SuperTrend"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count, "period": period, "multiplier": multiplier}
        return self._make_request(f"{self.backend_url}/indicators/supertrend", params=params)
    
    def get_squeeze(self, symbol: str, timeframe: str = "5m", count: int = 200) -> Dict:
        """Récupère l'indicateur Squeeze"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count}
        return self._make_request(f"{self.backend_url}/indicators/squeeze", params=params)
    
    # ==================== ENDPOINTS ROBOT INTEGRATION ====================
    
    def get_robot_decision(self, decision_data: Dict) -> Dict:
        """Obtient une décision de trading pour le robot F_INX_robot4.mq5"""
        return self._make_request(f"{self.backend_url}/robot/decision", method="POST", data=decision_data)
    
    def get_robot_indicators(self, symbol: str, timeframe: str = "1m", count: int = 200) -> Dict:
        """Récupère les indicateurs techniques pour le robot"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count}
        return self._make_request(f"{self.backend_url}/robot/indicators/{symbol}", params=params)
    
    def get_spike_analysis(self, symbol: str, timeframe: str = "1m", count: int = 200) -> Dict:
        """Analyse spécialisée pour la détection de spikes"""
        params = {"symbol": symbol, "timeframe": timeframe, "count": count}
        return self._make_request(f"{self.backend_url}/robot/spike-analysis/{symbol}", params=params)
    
    def validate_signal(self, symbol: str, action: str, confidence: float, reason: str) -> Dict:
        """Valide et enregistre un signal généré par le robot"""
        data = {"symbol": symbol, "action": action, "confidence": confidence, "reason": reason}
        return self._make_request(f"{self.backend_url}/robot/signal/validate", method="POST", data=data)
    
    def get_robot_health(self) -> Dict:
        """Vérifie l'état des services pour le robot"""
        return self._make_request(f"{self.backend_url}/robot/health")
    
    def get_robot_config(self) -> Dict:
        """Récupère la configuration actuelle du robot"""
        return self._make_request(f"{self.backend_url}/robot/config")
    
    # ==================== ENDPOINTS AI SERVER ====================
    
    def get_ai_decision(self, decision_data: Dict) -> Dict:
        """Obtient une décision de l'IA via ai_server.py"""
        return self._make_request(f"{self.ai_server_url}/decision", method="POST", data=decision_data)
    
    def get_ai_health(self) -> Dict:
        """Vérifie l'état du serveur IA"""
        return self._make_request(f"{self.ai_server_url}/health")
    
    def get_ai_status(self) -> Dict:
        """Récupère le statut détaillé du serveur IA"""
        return self._make_request(f"{self.ai_server_url}/status")
    
    def get_fundamental_data(self, symbol: str) -> Dict:
        """Récupère les données fondamentales via Alpha Vantage"""
        return self._make_request(f"{self.ai_server_url}/fundamental/{symbol}")
    
    def get_market_news(self, symbol: str) -> Dict:
        """Récupère les actualités du marché"""
        return self._make_request(f"{self.ai_server_url}/news/{symbol}")
    
    def get_economic_calendar(self) -> Dict:
        """Récupère le calendrier économique"""
        return self._make_request(f"{self.ai_server_url}/economic-calendar")
    
    def get_market_data_with_fallback(self, symbol: str) -> Dict:
        """Récupère les données de marché avec fallback automatique"""
        return self._make_request(f"{self.ai_server_url}/market-data/{symbol}")
    
    def analyze_with_gemini(self, prompt: str) -> Dict:
        """Analyse avec Google Gemini AI"""
        return self._make_request(f"{self.ai_server_url}/analyze/gemini", method="POST", data={"prompt": prompt})
    
    # ==================== MÉTHODES UTILITAIRES ====================
    
    def get_comprehensive_analysis(self, symbol: str, timeframe: str = "5m") -> Dict:
        """Analyse complète combinant backend et AI server"""
        try:
            # Données de base
            trend_data = self.get_trend_summary(symbol)
            price_data = self.get_real_time_price(symbol)
            
            # Indicateurs avancés
            market_structure = self.get_market_structure(symbol, timeframe)
            smart_money = self.get_smart_money(symbol, timeframe)
            supertrend = self.get_supertrend(symbol, timeframe)
            vwap = self.get_vwap(symbol, timeframe)
            
            # Données fondamentales si disponibles
            fundamental_data = self.get_fundamental_data(symbol)
            news_data = self.get_market_news(symbol)
            
            # Analyse IA
            ai_decision = None
            try:
                # Préparer les données pour l'IA
                if price_data.get("price"):
                    decision_data = {
                        "symbol": symbol,
                        "bid": price_data.get("bid", price_data.get("price", 0)),
                        "ask": price_data.get("ask", price_data.get("price", 0)),
                        "rsi": 50,  # Valeur par défaut
                        "ema_fast_h1": 0,
                        "ema_slow_h1": 0,
                        "ema_fast_m1": 0,
                        "ema_slow_m1": 0,
                        "atr": 0.01,
                        "dir_rule": 1,
                        "is_spike_mode": "Boom" in symbol or "Crash" in symbol
                    }
                    ai_decision = self.get_ai_decision(decision_data)
            except Exception as e:
                logger.warning(f"Erreur décision IA: {e}")
            
            return {
                "symbol": symbol,
                "timeframe": timeframe,
                "timestamp": datetime.now().isoformat(),
                "price_data": price_data,
                "trend_analysis": trend_data,
                "technical_indicators": {
                    "market_structure": market_structure,
                    "smart_money": smart_money,
                    "supertrend": supertrend,
                    "vwap": vwap
                },
                "fundamental_data": fundamental_data,
                "news_sentiment": news_data,
                "ai_decision": ai_decision,
                "overall_signal": self._generate_overall_signal(trend_data, ai_decision)
            }
            
        except Exception as e:
            logger.error(f"Erreur analyse complète: {e}")
            return {"error": str(e), "symbol": symbol}
    
    def _generate_overall_signal(self, trend_data: Dict, ai_decision: Dict) -> Dict:
        """Génère un signal global combinant tendance et IA"""
        try:
            # Extraire la tendance dominante
            consolidated = trend_data.get("consolidated", {})
            trend = consolidated.get("trend", "NEUTRAL")
            confidence = consolidated.get("confidence", 0)
            
            # Extraire la décision IA
            ai_action = ai_decision.get("action", "hold") if ai_decision else "hold"
            ai_confidence = ai_decision.get("confidence", 0) if ai_decision else 0
            
            # Combiner les signaux
            if trend == "BULLISH" and ai_action == "buy":
                final_action = "BUY"
                final_confidence = (confidence + ai_confidence) / 2
                reason = "Tendance haussière confirmée par IA"
            elif trend == "BEARISH" and ai_action == "sell":
                final_action = "SELL"
                final_confidence = (confidence + ai_confidence) / 2
                reason = "Tendance baissière confirmée par IA"
            elif ai_action != "hold" and ai_confidence > 0.7:
                final_action = ai_action.upper()
                final_confidence = ai_confidence
                reason = "Signal IA prioritaire"
            elif trend != "NEUTRAL":
                final_action = "BUY" if trend == "BULLISH" else "SELL"
                final_confidence = confidence
                reason = f"Tendance {trend.lower()}"
            else:
                final_action = "HOLD"
                final_confidence = 0.5
                reason = "Aucun signal clair"
            
            return {
                "action": final_action,
                "confidence": final_confidence,
                "reason": reason,
                "components": {
                    "trend": trend,
                    "trend_confidence": confidence,
                    "ai_action": ai_action,
                    "ai_confidence": ai_confidence
                }
            }
            
        except Exception as e:
            logger.error(f"Erreur génération signal global: {e}")
            return {"action": "HOLD", "confidence": 0.5, "reason": "Erreur analyse"}
    
    def test_connections(self) -> Dict:
        """Teste la connexion à tous les services"""
        results = {}
        
        # Test backend API
        try:
            symbols = self.get_symbols()
            results["backend_api"] = {
                "status": "connected",
                "symbols_count": len(symbols) if isinstance(symbols, list) else 0
            }
        except Exception as e:
            results["backend_api"] = {"status": "error", "error": str(e)}
        
        # Test AI server
        try:
            health = self.get_ai_health()
            results["ai_server"] = {
                "status": "connected" if health.get("status") == "healthy" else "error",
                "details": health
            }
        except Exception as e:
            results["ai_server"] = {"status": "error", "error": str(e)}
        
        # Test robot integration
        try:
            robot_health = self.get_robot_health()
            results["robot_integration"] = {
                "status": "connected" if robot_health.get("status") == "healthy" else "error",
                "details": robot_health
            }
        except Exception as e:
            results["robot_integration"] = {"status": "error", "error": str(e)}
        
        return {
            "timestamp": datetime.now().isoformat(),
            "services": results,
            "overall_status": "connected" if all(s.get("status") == "connected" for s in results.values()) else "partial"
        }
