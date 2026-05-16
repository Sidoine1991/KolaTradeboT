import os
from dotenv import load_dotenv

#!/usr/bin/env python3
"""
Système d'apprentissage automatique pour le robot de trading
Intégration ML avec feedback loop pour améliorer les décisions
"""

import os
import json
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import requests
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase
SUPABASE_URL = "https://bpzqnooiisgadzicwupi.supabase.co"
SUPABASE_ANON_KEY = os.getenv("SUPABASE_KEY", "")

class MLTradingSystem:
    """Système de trading avec apprentissage automatique"""
    
    def __init__(self):
        self.model_performance = {}
        self.symbol_models = {}
        self.decision_history = []
        self.learning_rate = 0.01
        self.min_samples = 10
        
    def collect_training_data(self, symbol: str, limit: int = 100) -> pd.DataFrame:
        """Collecter les données d'entraînement depuis Supabase"""
        logger.info(f"📊 Collecte des données pour {symbol}...")
        
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Content-Type": "application/json"
        }
        
        try:
            # Récupérer les feedback de trades
            url_feedback = f"{SUPABASE_URL}/rest/v1/trade_feedback?symbol=eq.{symbol}&order=created_at.desc&limit={limit}"
            response = requests.get(url_feedback, headers=headers, timeout=10)
            
            if response.status_code == 200:
                feedback_data = response.json()
                df = pd.DataFrame(feedback_data)
                
                if not df.empty:
                    logger.info(f"✅ {len(df)} trades récupérés pour {symbol}")
                    return self._prepare_features(df)
                else:
                    logger.warning(f"⚠️ Aucune donnée pour {symbol}")
                    return pd.DataFrame()
            else:
                logger.error(f"❌ Erreur récupération données: {response.status_code}")
                return pd.DataFrame()
                
        except Exception as e:
            logger.error(f"❌ Erreur collecte données: {e}")
            return pd.DataFrame()
    
    def _prepare_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Préparer les features pour le ML"""
        if df.empty:
            return df
        
        # Features techniques
        df['profit_ratio'] = df['profit'] / df['entry_price']
        df['confidence_diff'] = df['ai_confidence'] - df['coherent_confidence']
        df['high_confidence'] = (df['ai_confidence'] > 0.7).astype(int)
        df['decision_encoded'] = df['decision'].map({'buy': 1, 'sell': -1, 'hold': 0})
        df['success'] = df['is_win'].astype(int)
        
        # Features temporelles
        if 'created_at' in df.columns:
            df['hour'] = pd.to_datetime(df['created_at']).dt.hour
            df['day_of_week'] = pd.to_datetime(df['created_at']).dt.dayofweek
        
        return df
    
    def train_symbol_model(self, symbol: str) -> Dict:
        """Entraîner un modèle pour un symbole spécifique"""
        logger.info(f"🧪 Entraînement du modèle pour {symbol}...")
        
        df = self.collect_training_data(symbol)
        
        if df.empty or len(df) < self.min_samples:
            logger.warning(f"⚠️ Données insuffisantes pour {symbol}")
            return {"status": "insufficient_data", "samples": len(df)}
        
        try:
            # Calculer les métriques de performance
            win_rate = df['success'].mean()
            avg_profit = df[df['success'] == True]['profit'].mean() if df[df['success'] == True]['profit'].any() else 0
            avg_loss = df[df['success'] == False]['profit'].mean() if df[df['success'] == False]['profit'].any() else 0
            
            # Analyser les patterns par confiance
            high_conf_trades = df[df['ai_confidence'] > 0.7]
            high_conf_win_rate = high_conf_trades['success'].mean() if not high_conf_trades.empty else 0
            
            # Analyser par décision
            buy_trades = df[df['decision'] == 'buy']
            sell_trades = df[df['decision'] == 'sell']
            
            buy_win_rate = buy_trades['success'].mean() if not buy_trades.empty else 0
            sell_win_rate = sell_trades['success'].mean() if not sell_trades.empty else 0
            
            # Créer le modèle simple
            model = {
                "symbol": symbol,
                "win_rate": win_rate,
                "avg_profit": avg_profit,
                "avg_loss": avg_loss,
                "high_confidence_win_rate": high_conf_win_rate,
                "buy_win_rate": buy_win_rate,
                "sell_win_rate": sell_win_rate,
                "total_trades": len(df),
                "last_updated": datetime.now().isoformat(),
                "confidence_threshold": self._calculate_optimal_threshold(df),
                "decision_weights": self._calculate_decision_weights(df),
                "time_patterns": self._analyze_time_patterns(df)
            }
            
            # Sauvegarder le modèle
            self.symbol_models[symbol] = model
            self._save_model(symbol, model)
            
            logger.info(f"✅ Modèle entraîné pour {symbol}")
            logger.info(f"   Win rate: {win_rate:.2%}")
            logger.info(f"   Seuil confiance optimal: {model['confidence_threshold']:.2f}")
            
            return {"status": "success", "model": model}
            
        except Exception as e:
            logger.error(f"❌ Erreur entraînement modèle {symbol}: {e}")
            return {"status": "error", "message": str(e)}
    
    def _calculate_optimal_threshold(self, df: pd.DataFrame) -> float:
        """Calculer le seuil de confiance optimal"""
        if df.empty:
            return 0.5
        
        thresholds = np.arange(0.5, 0.95, 0.05)
        best_threshold = 0.7
        best_score = 0
        
        for threshold in thresholds:
            trades = df[df['ai_confidence'] >= threshold]
            if len(trades) > 0:
                win_rate = trades['success'].mean()
                score = win_rate * len(trades) / len(df)  # Pondéré par le nombre de trades
                
                if score > best_score:
                    best_score = score
                    best_threshold = threshold
        
        return float(best_threshold)
    
    def _calculate_decision_weights(self, df: pd.DataFrame) -> Dict:
        """Calculer les poids de décision optimaux"""
        weights = {"buy": 1.0, "sell": 1.0, "hold": 1.0}
        
        if not df.empty:
            for decision in ['buy', 'sell']:
                decision_trades = df[df['decision'] == decision]
                if not decision_trades.empty:
                    win_rate = decision_trades['success'].mean()
                    weights[decision] = max(0.5, min(2.0, win_rate * 2))
        
        return weights
    
    def _analyze_time_patterns(self, df: pd.DataFrame) -> Dict:
        """Analyser les patterns temporels"""
        patterns = {"best_hours": [], "worst_hours": []}
        
        if 'hour' in df.columns and not df.empty:
            hourly_performance = df.groupby('hour')['success'].agg(['mean', 'count'])
            
            # Meilleures heures (min 5 trades)
            best_hours = hourly_performance[hourly_performance['count'] >= 5]
            if not best_hours.empty:
                patterns["best_hours"] = best_hours.nlargest(3, 'mean').index.tolist()
            
            # Pires heures
            worst_hours = hourly_performance[hourly_performance['count'] >= 5]
            if not worst_hours.empty:
                patterns["worst_hours"] = worst_hours.nsmallest(3, 'mean').index.tolist()
        
        return patterns
    
    def _save_model(self, symbol: str, model: Dict):
        """Sauvegarder le modèle dans Supabase"""
        try:
            headers = {
                "apikey": SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
                "Content-Type": "application/json",
                "Prefer": "return=representation"
            }
            
            # Sauvegarder dans symbol_calibration
            calibration_data = {
                "symbol": symbol,
                "timeframe": "ML",
                "wins": int(model['win_rate'] * model['total_trades']),
                "total": model['total_trades'],
                "drift_factor": model['confidence_threshold'],
                "metadata": {
                    "model_type": "adaptive_ml",
                    "win_rate": model['win_rate'],
                    "confidence_threshold": model['confidence_threshold'],
                    "decision_weights": model['decision_weights'],
                    "time_patterns": model['time_patterns'],
                    "last_trained": model['last_updated']
                }
            }
            
            url = f"{SUPABASE_URL}/rest/v1/symbol_calibration"
            response = requests.post(url, json=calibration_data, headers=headers, timeout=10)
            
            if response.status_code == 201:
                logger.info(f"✅ Modèle sauvegardé pour {symbol}")
            else:
                logger.error(f"❌ Erreur sauvegarde modèle: {response.status_code}")
                
        except Exception as e:
            logger.error(f"❌ Erreur sauvegarde modèle {symbol}: {e}")
    
    def get_ml_decision(self, symbol: str, base_decision: str, confidence: float, 
                     market_data: Dict = None) -> Tuple[str, float, str]:
        """Obtenir une décision influencée par le ML"""
        
        if symbol not in self.symbol_models:
            logger.warning(f"⚠️ Pas de modèle ML pour {symbol}")
            return base_decision, confidence, "no_model"
        
        model = self.symbol_models[symbol]
        
        # Ajuster la confiance selon le seuil optimal
        adjusted_confidence = confidence
        if confidence < model['confidence_threshold']:
            adjusted_confidence *= 0.8  # Réduire la confiance si sous le seuil
        
        # Ajuster selon les poids de décision
        decision_weights = model['decision_weights']
        weight_factor = decision_weights.get(base_decision, 1.0)
        adjusted_confidence *= weight_factor
        
        # Ajuster selon les patterns temporels
        current_hour = datetime.now().hour
        time_patterns = model.get('time_patterns', {})
        
        if current_hour in time_patterns.get('best_hours', []):
            adjusted_confidence *= 1.1  # Booster si bonne heure
        elif current_hour in time_patterns.get('worst_hours', []):
            adjusted_confidence *= 0.9  # Réduire si mauvaise heure
        
        # Limiter la confiance
        adjusted_confidence = max(0.1, min(1.0, adjusted_confidence))
        
        # Décision finale
        if adjusted_confidence < 0.3:
            final_decision = "hold"
            reason = "ml_confidence_too_low"
        elif adjusted_confidence < model['confidence_threshold']:
            final_decision = "hold"
            reason = "ml_below_threshold"
        else:
            final_decision = base_decision
            reason = "ml_enhanced"
        
        logger.info(f"🧠 ML Decision pour {symbol}: {base_decision} → {final_decision} ({confidence:.2f} → {adjusted_confidence:.2f})")
        
        return final_decision, adjusted_confidence, reason
    
    def update_model_feedback(self, symbol: str, decision: str, confidence: float, 
                           result: bool, profit: float):
        """Mettre à jour le modèle avec le feedback"""
        
        if symbol not in self.symbol_models:
            return
        
        model = self.symbol_models[symbol]
        
        # Mettre à jour les métriques
        total_trades = model.get('total_trades', 0) + 1
        wins = model.get('wins', 0) + (1 if result else 0)
        new_win_rate = wins / total_trades
        
        # Ajuster le seuil de confiance
        if result and confidence > 0.7:
            model['confidence_threshold'] *= (1 - self.learning_rate * 0.1)
        elif not result and confidence > 0.7:
            model['confidence_threshold'] *= (1 + self.learning_rate * 0.1)
        
        # Mettre à jour le modèle
        model['total_trades'] = total_trades
        model['wins'] = wins
        model['win_rate'] = new_win_rate
        model['last_updated'] = datetime.now().isoformat()
        
        # Sauvegarder périodiquement
        if total_trades % 10 == 0:
            self._save_model(symbol, model)
        
        logger.info(f"📈 Modèle {symbol} mis à jour: {new_win_rate:.2%} win rate")

class MLDecisionEnhancer:
    """Enhanceur de décisions avec ML pour l'API"""
    
    def __init__(self):
        self.ml_system = MLTradingSystem()
        self.initialized = False
    
    def initialize(self):
        """Initialiser le système ML"""
        logger.info("🚀 Initialisation du système ML...")
        
        # Charger les modèles existants
        try:
            headers = {
                "apikey": SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
                "Content-Type": "application/json"
            }
            
            url = f"{SUPABASE_URL}/rest/v1/symbol_calibration?metadata->>model_type.eq.adaptive_ml"
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                models_data = response.json()
                for model_data in models_data:
                    symbol = model_data['symbol']
                    metadata = model_data.get('metadata', {})
                    
                    if metadata:
                        self.ml_system.symbol_models[symbol] = {
                            'symbol': symbol,
                            'win_rate': metadata.get('win_rate', 0.5),
                            'confidence_threshold': metadata.get('confidence_threshold', 0.7),
                            'decision_weights': metadata.get('decision_weights', {}),
                            'time_patterns': metadata.get('time_patterns', {}),
                            'total_trades': model_data.get('total', 0),
                            'wins': model_data.get('wins', 0)
                        }
                        
                        logger.info(f"✅ Modèle ML chargé pour {symbol}")
            
            self.initialized = True
            logger.info("🎯 Système ML initialisé")
            
        except Exception as e:
            logger.error(f"❌ Erreur initialisation ML: {e}")
    
    def enhance_decision(self, symbol: str, decision: str, confidence: float, 
                     market_data: Dict = None) -> Dict:
        """Améliorer une décision avec le ML"""
        
        if not self.initialized:
            self.initialize()
        
        try:
            enhanced_decision, enhanced_confidence, reason = self.ml_system.get_ml_decision(
                symbol, decision, confidence, market_data
            )
            
            return {
                "original_decision": decision,
                "original_confidence": confidence,
                "enhanced_decision": enhanced_decision,
                "enhanced_confidence": enhanced_confidence,
                "ml_reason": reason,
                "ml_applied": True
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur enhancement décision: {e}")
            return {
                "original_decision": decision,
                "original_confidence": confidence,
                "enhanced_decision": decision,
                "enhanced_confidence": confidence,
                "ml_reason": "error",
                "ml_applied": False
            }
    
    def train_all_symbols(self, symbols: List[str] = None):
        """Entraîner les modèles pour tous les symboles"""
        if symbols is None:
            symbols = ["EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD"]
        
        logger.info(f"🧪 Entraînement des modèles pour {len(symbols)} symboles...")
        
        results = {}
        for symbol in symbols:
            result = self.ml_system.train_symbol_model(symbol)
            results[symbol] = result
        
        return results

# Instance globale pour l'API
ml_enhancer = MLDecisionEnhancer()

def main():
    """Point d'entrée principal"""
    logger.info("🚀 SYSTÈME D'APPRENTISSAGE AUTOMATIQUE POUR TRADING")
    logger.info("=" * 60)
    
    # Initialiser le système
    ml_enhancer.initialize()
    
    # Entraîner les modèles
    results = ml_enhancer.train_all_symbols()
    
    logger.info("\n📋 RÉSULTATS D'ENTRAÎNEMENT:")
    for symbol, result in results.items():
        status = "✅" if result.get('status') == 'success' else "❌"
        logger.info(f"{status} {symbol}: {result.get('status', 'unknown')}")
    
    logger.info("\n🎯 Système ML prêt à influencer les décisions de trading!")

if __name__ == "__main__":
    main()
