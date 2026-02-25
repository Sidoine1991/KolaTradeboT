#!/usr/bin/env python3
"""
Système d'entraînement continu intégré à ai_server.py
Démarrage automatique avec l'API principale
"""

import os
import json
import time
import asyncio
import logging
import joblib
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import httpx
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, f1_score, classification_report
from dotenv import load_dotenv
import warnings
warnings.filterwarnings('ignore')

# Charger les variables d'environnement
load_dotenv('.env.supabase')

# Configuration
logger = logging.getLogger("tradbot_ml_trainer")

class IntegratedMLTrainer:
    """Système d'entraînement continu intégré à l'API"""
    
    def __init__(self):
        self.models_dir = os.getenv("MODELS_DIR", "models")
        os.makedirs(self.models_dir, exist_ok=True)
        self.supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
        self.supabase_key = os.getenv("SUPABASE_ANON_KEY")
        self.training_interval = 300  # 5 minutes
        self.min_samples_for_retraining = 50  # Réduit pour les tests
        self.is_running = False
        self.training_task = None
        
        # Métriques en temps réel
        self.current_metrics = {}
        self.training_history = []
        self.last_training_time = {}
        
        # Cache pour éviter les requêtes trop fréquentes
        self.data_cache = {}
        self.cache_timestamps = {}
        self.cache_duration = 60  # 1 minute de cache
        
    def load_existing_models(self) -> Dict[str, Any]:
        """Charge tous les modèles existants"""
        models = {}
        
        if not os.path.exists(self.models_dir):
            logger.warning(f"Répertoire {self.models_dir} non trouvé")
            return models
            
        for file in os.listdir(self.models_dir):
            if file.endswith('_rf.joblib'):
                # Extraire symbole et timeframe
                parts = file.replace('_rf.joblib', '').split('_')
                if len(parts) >= 2:
                    symbol = '_'.join(parts[:-1])
                    timeframe = parts[-1]
                    key = f"{symbol}_{timeframe}"
                    
                    try:
                        model_path = os.path.join(self.models_dir, file)
                        scaler_path = os.path.join(self.models_dir, file.replace('_rf.joblib', '_scaler.joblib'))
                        metrics_path = os.path.join(self.models_dir, file.replace('_rf.joblib', '_metrics.json'))
                        
                        models[key] = {
                            'model': joblib.load(model_path),
                            'scaler': joblib.load(scaler_path) if os.path.exists(scaler_path) else None,
                            'metrics': json.load(open(metrics_path)) if os.path.exists(metrics_path) else {},
                            'symbol': symbol,
                            'timeframe': timeframe,
                            'last_training': datetime.now()
                        }
                        logger.info(f"✅ Modèle chargé: {key}")
                    except Exception as e:
                        logger.error(f"❌ Erreur chargement modèle {file}: {e}")
                        
        return models
    
    async def fetch_training_data_simple(self, symbol: str, timeframe: str = "M1", limit: int = 1000) -> Optional[pd.DataFrame]:
        """Récupère les données d'entraînement depuis Supabase (version simplifiée)"""
        # Vérifier le cache
        cache_key = f"{symbol}_{timeframe}"
        current_time = time.time()
        
        if cache_key in self.data_cache:
            cache_age = current_time - self.cache_timestamps.get(cache_key, 0)
            if cache_age < self.cache_duration:
                logger.debug(f"✅ Cache utilisé pour {cache_key}")
                return self.data_cache[cache_key]
        
        headers = {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                # Récupérer les prédictions récentes avec une requête plus simple
                predictions_url = f"{self.supabase_url}/rest/v1/predictions"
                
                # Utiliser une requête plus simple
                simple_query = f"symbol=eq.{symbol.replace(' ', '+')}&limit={limit}&order=created_at.desc"
                
                pred_resp = await client.get(
                    predictions_url, 
                    params=simple_query,
                    headers=headers
                )
                
                if pred_resp.status_code != 200:
                    logger.debug(f"⚠️ Pas de données pour {symbol} (status: {pred_resp.status_code})")
                    return None
                
                predictions_data = pred_resp.json()
                
                # Créer un DataFrame simple avec les données disponibles
                df = self.prepare_simple_training_data(predictions_data)
                
                if df is not None and len(df) > 0:
                    # Mettre en cache
                    self.data_cache[cache_key] = df
                    self.cache_timestamps[cache_key] = current_time
                    logger.info(f"📊 {len(df)} échantillons récupérés pour {symbol} {timeframe}")
                
                return df
                
        except Exception as e:
            logger.error(f"❌ Erreur récupération données {symbol}: {e}")
            return None
    
    def prepare_simple_training_data(self, predictions: List[Dict]) -> pd.DataFrame:
        """Prépare les données d'entraînement (version simplifiée)"""
        training_data = []
        
        for pred in predictions:
            try:
                # Extraire les données de base
                metadata = pred.get('metadata', {})
                request_data = metadata.get('request_data', {})
                
                # Features de base toujours disponibles
                features = {
                    'rsi': float(request_data.get('rsi', 50)),
                    'atr': float(request_data.get('atr', 0.001)),
                    'bid': float(pred.get('bid', 1.0)),
                    'ask': float(pred.get('ask', 1.0)),
                    'confidence': float(pred.get('confidence', 0.5))
                }
                
                # Features techniques si disponibles
                if 'ema_fast_m1' in request_data:
                    features['ema_fast_m1'] = float(request_data['ema_fast_m1'])
                    features['ema_slow_m1'] = float(request_data.get('ema_slow_m1', 1.0))
                    features['ema_diff_m1'] = features['ema_fast_m1'] - features['ema_slow_m1']
                
                if 'ema_fast_h1' in request_data:
                    features['ema_fast_h1'] = float(request_data['ema_fast_h1'])
                    features['ema_slow_h1'] = float(request_data.get('ema_slow_h1', 1.0))
                    features['ema_diff_h1'] = features['ema_fast_h1'] - features['ema_slow_h1']
                
                # Déterminer le label
                prediction = pred.get('prediction', 'hold')
                if prediction == 'buy':
                    label = 1
                elif prediction == 'sell':
                    label = 0
                else:
                    label = 2  # hold
                
                features['target'] = label
                features['prediction_id'] = pred.get('id', '')
                features['timestamp'] = pred.get('created_at', datetime.now().isoformat())
                
                training_data.append(features)
                
            except Exception as e:
                logger.warning(f"⚠️ Erreur préparation feature: {e}")
                continue
        
        if not training_data:
            return None
            
        return pd.DataFrame(training_data)
    
    def train_model_simple(self, df: pd.DataFrame, symbol: str, timeframe: str) -> Dict[str, Any]:
        """Entraîne un modèle avec les nouvelles données (version simplifiée)"""
        if len(df) < self.min_samples_for_retraining:
            logger.warning(f"⚠️ Pas assez de données pour {symbol} {timeframe}: {len(df)} < {self.min_samples_for_retraining}")
            return None
        
        # Préparer les features
        feature_columns = [col for col in df.columns if col not in ['target', 'prediction_id', 'timestamp']]
        X = df[feature_columns].fillna(0)
        y = df['target']
        
        # Normaliser
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        # Entraîner Random Forest (plus simple)
        rf_model = RandomForestClassifier(
            n_estimators=50,  # Réduit pour la vitesse
            max_depth=8,
            min_samples_split=5,
            random_state=42
        )
        
        rf_model.fit(X_scaled, y)
        
        # Calculer les métriques
        y_pred = rf_model.predict(X_scaled)
        accuracy = accuracy_score(y, y_pred)
        f1 = f1_score(y, y_pred, average='weighted')
        
        # Importance des features
        feature_importance = dict(zip(feature_columns, rf_model.feature_importances_))
        
        # Sauvegarder le modèle
        model_key = f"{symbol}_{timeframe}"
        model_path = os.path.join(self.models_dir, f"{model_key}_rf.joblib")
        scaler_path = os.path.join(self.models_dir, f"{model_key}_scaler.joblib")
        
        joblib.dump(rf_model, model_path)
        joblib.dump(scaler, scaler_path)
        
        # Métriques
        metrics = {
            "symbol": symbol,
            "timeframe": timeframe,
            "training_date": datetime.now().isoformat(),
            "metrics": {
                "random_forest": {
                    "accuracy": float(accuracy),
                    "f1_score": float(f1),
                    "feature_importance": feature_importance
                }
            },
            "best_model": "random_forest",
            "features_used": feature_columns,
            "training_samples": len(df),
            "test_samples": int(len(df) * 0.2)
        }
        
        # Sauvegarder les métriques
        metrics_path = os.path.join(self.models_dir, f"{model_key}_metrics.json")
        with open(metrics_path, 'w') as f:
            json.dump(metrics, f, indent=2)
        
        logger.info(f"✅ Modèle entraîné: {model_key} | Accuracy: {accuracy:.4f} | F1: {f1:.4f}")
        
        return metrics
    
    async def save_metrics_to_supabase(self, metrics: Dict[str, Any]):
        """Sauvegarde les métriques dans Supabase (si table existe)"""
        headers = {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }
        
        try:
            metric_data = {
                "symbol": metrics["symbol"],
                "timeframe": metrics["timeframe"],
                "model_type": "random_forest",
                "accuracy": metrics["metrics"]["random_forest"]["accuracy"],
                "f1_score": metrics["metrics"]["random_forest"]["f1_score"],
                "training_samples": metrics["training_samples"],
                "training_date": metrics["training_date"],
                "feature_importance": json.dumps(metrics["metrics"]["random_forest"]["feature_importance"]),
                "metadata": json.dumps(metrics)
            }
            
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.supabase_url}/rest/v1/model_metrics",
                    json=metric_data,
                    headers=headers,
                    timeout=10.0
                )
                
                if resp.status_code == 201:
                    logger.info(f"✅ Métriques sauvegardées pour {metrics['symbol']} {metrics['timeframe']}")
                else:
                    # Si la table n'existe pas, on ignore silencieusement
                    logger.debug(f"⚠️ Table model_metrics non disponible: {resp.status_code}")
                    
        except Exception as e:
            logger.debug(f"⚠️ Erreur sauvegarde métriques Supabase: {e}")
    
    def log_metrics_to_console(self):
        """Affiche les métriques dans la console"""
        if not self.current_metrics:
            return
            
        print("\n" + "="*80)
        print("🤖 MÉTRIQUES MODÈLES ML - ENTRAÎNEMENT CONTINU")
        print("="*80)
        
        for model_key, metrics in self.current_metrics.items():
            symbol = metrics.get('symbol', 'Unknown')
            timeframe = metrics.get('timeframe', 'M1')
            rf_metrics = metrics.get('metrics', {}).get('random_forest', {})
            
            accuracy = rf_metrics.get('accuracy', 0)
            f1_score = rf_metrics.get('f1_score', 0)
            training_samples = metrics.get('training_samples', 0)
            training_date = metrics.get('training_date', 'Unknown')
            
            print(f"\n📊 {symbol} [{timeframe}]")
            print(f"   Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")
            print(f"   F1 Score: {f1_score:.4f}")
            print(f"   Samples: {training_samples}")
            print(f"   Last Training: {training_date[:19] if len(training_date) > 19 else training_date}")
        
        print(f"\n🔄 Prochain entraînement dans: {self.training_interval//60} minutes")
        print("="*80 + "\n")
    
    def _get_symbols_to_train(self) -> List[tuple]:
        """Symboles/timeframes à entraîner: modèles existants ou liste par défaut depuis Supabase"""
        models = self.load_existing_models()
        if models:
            return [(m['symbol'], m['timeframe']) for m in models.values()]
        symbols_str = os.getenv("ML_SYMBOLS", "Boom 300 Index,Boom 600 Index,EURUSD,GBPUSD")
        symbols = [s.strip() for s in symbols_str.split(",") if s.strip()]
        return [(sym, "M1") for sym in symbols]
    
    async def continuous_training_loop(self):
        """Boucle d'entraînement continu - récupère données Supabase, stocke métriques Supabase"""
        logger.info("🚀 Entraînement continu démarré (Supabase: fetch predictions → train → save model_metrics)")
        if not self.supabase_key:
            logger.warning("⚠️ SUPABASE_ANON_KEY non configuré - entraînement Supabase désactivé")
            return
        
        while self.is_running:
            try:
                pairs = self._get_symbols_to_train()
                logger.info(f"🔄 Cycle entraînement - {len(pairs)} symboles | {datetime.now()}")
                trained_count = 0
                
                for symbol, timeframe in pairs:
                    model_key = f"{symbol}_{timeframe}"
                    last_training = self.last_training_time.get(model_key, 0)
                    if time.time() - last_training < self.training_interval:
                        continue
                    
                    # Récupérer les données depuis Supabase (predictions)
                    df = await self.fetch_training_data_simple(symbol, timeframe)
                    if df is not None and len(df) >= self.min_samples_for_retraining:
                        # Entraîner le modèle
                        new_metrics = self.train_model_simple(df, symbol, timeframe)
                        if new_metrics:
                            self.current_metrics[model_key] = new_metrics
                            self.last_training_time[model_key] = time.time()
                            trained_count += 1
                            
                            # Sauvegarder les métriques dans Supabase
                            await self.save_metrics_to_supabase(new_metrics)
                
                if trained_count > 0:
                    # Afficher les métriques
                    self.log_metrics_to_console()
                else:
                    logger.info("ℹ️ Aucun modèle réentraîné ce cycle")
                
                # Attendre le prochain cycle
                logger.info(f"😴 Attente {self.training_interval//60} minutes avant prochain entraînement...")
                await asyncio.sleep(self.training_interval)
                
            except Exception as e:
                logger.error(f"❌ Erreur dans le cycle d'entraînement: {e}")
                await asyncio.sleep(60)  # Attendre 1 minute en cas d'erreur
    
    async def start(self):
        """Démarre le système d'entraînement"""
        if not self.is_running:
            self.is_running = True
            self.training_task = asyncio.create_task(self.continuous_training_loop())
            logger.info("✅ Système d'entraînement continu démarré")
    
    async def stop(self):
        """Arrête le système d'entraînement"""
        if self.is_running:
            self.is_running = False
            if self.training_task:
                self.training_task.cancel()
                try:
                    await self.training_task
                except asyncio.CancelledError:
                    pass
            logger.info("🛑 Système d'entraînement continu arrêté")
    
    def get_current_metrics(self) -> Dict[str, Any]:
        """Retourne les métriques actuelles pour l'API"""
        return {
            "status": "running" if self.is_running else "stopped",
            "models_count": len(self.current_metrics),
            "last_update": datetime.now().isoformat(),
            "metrics": self.current_metrics
        }

# Instance globale pour l'intégration
ml_trainer = IntegratedMLTrainer()
