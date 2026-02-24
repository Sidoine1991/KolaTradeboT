#!/usr/bin/env python3
"""
Système d'entraînement continu avec métriques en temps réel
Utilise les modèles existants et les améliore avec les données Supabase
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
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ContinuousMLTrainer:
    """Système d'entraînement continu avec métriques en temps réel"""
    
    def __init__(self):
        self.models_dir = "models"
        self.supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
        self.supabase_key = os.getenv("SUPABASE_ANON_KEY")
        self.training_interval = 300  # 5 minutes
        self.min_samples_for_retraining = 100  # Échantillons minimums
        
        # Métriques en temps réel
        self.current_metrics = {}
        self.training_history = []
        
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
    
    async def fetch_training_data(self, symbol: str, timeframe: str = "M1", limit: int = 10000) -> Optional[pd.DataFrame]:
        """Récupère les données d'entraînement depuis Supabase"""
        headers = {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                # Récupérer les prédictions récentes
                predictions_url = f"{self.supabase_url}/rest/v1/predictions"
                predictions_params = {
                    "symbol": f"eq.{symbol}",
                    "timeframe": timeframe,
                    "order": "created_at.desc",
                    "limit": limit
                }
                
                pred_resp = await client.get(predictions_url, params=predictions_params, headers=headers)
                if pred_resp.status_code != 200:
                    logger.error(f"❌ Erreur récupération prédictions: {pred_resp.status_code}")
                    return None
                
                predictions_data = pred_resp.json()
                
                # Récupérer le feedback de trading
                feedback_url = f"{self.supabase_url}/rest/v1/trade_feedback"
                feedback_params = {
                    "symbol": f"eq.{symbol}",
                    "order": "created_at.desc",
                    "limit": limit
                }
                
                feedback_resp = await client.get(feedback_url, params=feedback_params, headers=headers)
                feedback_data = feedback_resp.json() if feedback_resp.status_code == 200 else []
                
                # Combiner les données
                df = self.prepare_training_data(predictions_data, feedback_data)
                logger.info(f"📊 {len(df)} échantillons récupérés pour {symbol} {timeframe}")
                return df
                
        except Exception as e:
            logger.error(f"❌ Erreur récupération données {symbol}: {e}")
            return None
    
    def prepare_training_data(self, predictions: List[Dict], feedback: List[Dict]) -> pd.DataFrame:
        """Prépare les données d'entraînement"""
        training_data = []
        
        # Créer un dictionnaire des feedback pour recherche rapide
        feedback_dict = {f.get('prediction_id', ''): f for f in feedback}
        
        for pred in predictions:
            # Créer les features techniques
            try:
                metadata = pred.get('metadata', {})
                request_data = metadata.get('request_data', {})
                
                features = {
                    'price_vs_sma20': request_data.get('price_vs_sma20', 0),
                    'price_vs_sma50': request_data.get('price_vs_sma50', 0),
                    'rsi': request_data.get('rsi', 50),
                    'rsi_normalized': request_data.get('rsi', 50) / 100,
                    'macd': request_data.get('macd', 0),
                    'macd_signal': request_data.get('macd_signal', 0),
                    'macd_histogram': request_data.get('macd_histogram', 0),
                    'atr': request_data.get('atr', 0.001),
                    'atr_normalized': request_data.get('atr', 0.001) * 1000,
                    'atr_ma_ratio': request_data.get('atr_ma_ratio', 1.0),
                    'bb_width': request_data.get('bb_width', 0.02),
                    'bb_position': request_data.get('bb_position', 0.5),
                    'volume_ratio': request_data.get('volume_ratio', 1.0),
                    'volume_trend': request_data.get('volume_trend', 0),
                    'high_low_range': request_data.get('high_low_range', 0.001),
                    'open_close_range': request_data.get('open_close_range', 0.0005),
                    'body_size': request_data.get('body_size', 0.0005),
                    'momentum_5': request_data.get('momentum_5', 0),
                    'momentum_10': request_data.get('momentum_10', 0),
                    'momentum_20': request_data.get('momentum_20', 0),
                    'distance_to_high': request_data.get('distance_to_high', 0),
                    'distance_to_low': request_data.get('distance_to_low', 0)
                }
                
                # Déterminer le label à partir du feedback
                pred_id = pred.get('id', '')
                feedback_entry = feedback_dict.get(pred_id)
                
                if feedback_entry:
                    # Utiliser le résultat réel du trade
                    is_profitable = feedback_entry.get('is_profitable', False)
                    label = 1 if is_profitable else 0
                else:
                    # Si pas de feedback, utiliser la prédiction comme label approximatif
                    prediction = pred.get('prediction', 'hold')
                    if prediction == 'buy':
                        label = 1
                    elif prediction == 'sell':
                        label = 0
                    else:
                        label = 2  # hold
                
                features['target'] = label
                features['prediction_id'] = pred_id
                features['timestamp'] = pred.get('created_at', datetime.now().isoformat())
                
                training_data.append(features)
                
            except Exception as e:
                logger.warning(f"⚠️ Erreur préparation feature: {e}")
                continue
        
        return pd.DataFrame(training_data)
    
    def train_model(self, df: pd.DataFrame, symbol: str, timeframe: str) -> Dict[str, Any]:
        """Entraîne un modèle avec les nouvelles données"""
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
        
        # Entraîner Random Forest
        rf_model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            min_samples_split=5,
            min_samples_leaf=2,
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
        """Sauvegarde les métriques dans Supabase"""
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
                    logger.error(f"❌ Erreur sauvegarde métriques: {resp.status_code} - {resp.text}")
                    
        except Exception as e:
            logger.error(f"❌ Erreur sauvegarde métriques Supabase: {e}")
    
    def display_metrics_dashboard(self):
        """Affiche le dashboard des métriques en temps réel"""
        print("\n" + "="*80)
        print("🤖 DASHBOARD MÉTRIQUES MODÈLES ML")
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
            
            # Top 5 features
            feature_importance = rf_metrics.get('feature_importance', {})
            if feature_importance:
                top_features = sorted(feature_importance.items(), key=lambda x: x[1], reverse=True)[:5]
                print(f"   Top Features: {', '.join([f'{feat}({imp:.3f})' for feat, imp in top_features])}")
        
        print("\n" + "="*80)
        print(f"🔄 Prochain entraînement dans: {self.training_interval//60} minutes")
        print("="*80 + "\n")
    
    async def continuous_training_loop(self):
        """Boucle d'entraînement continu"""
        logger.info("🚀 Démarrage du système d'entraînement continu")
        
        # Charger les modèles existants
        models = self.load_existing_models()
        logger.info(f"📦 {len(models)} modèles chargés")
        
        while True:
            try:
                logger.info(f"🔄 Début cycle d'entraînement - {datetime.now()}")
                
                # Pour chaque modèle, récupérer les nouvelles données et réentraîner
                for model_key, model_info in models.items():
                    symbol = model_info['symbol']
                    timeframe = model_info['timeframe']
                    
                    # Récupérer les données
                    df = await self.fetch_training_data(symbol, timeframe)
                    if df is not None and len(df) >= self.min_samples_for_retraining:
                        # Entraîner le modèle
                        new_metrics = self.train_model(df, symbol, timeframe)
                        if new_metrics:
                            self.current_metrics[model_key] = new_metrics
                            
                            # Sauvegarder les métriques dans Supabase
                            await self.save_metrics_to_supabase(new_metrics)
                            
                            # Mettre à jour le modèle en mémoire
                            models[model_key].update(new_metrics)
                
                # Afficher le dashboard
                self.display_metrics_dashboard()
                
                # Attendre le prochain cycle
                logger.info(f"😴 Attente {self.training_interval//60} minutes avant prochain entraînement...")
                await asyncio.sleep(self.training_interval)
                
            except KeyboardInterrupt:
                logger.info("🛑 Arrêt du système d'entraînement")
                break
            except Exception as e:
                logger.error(f"❌ Erreur dans le cycle d'entraînement: {e}")
                await asyncio.sleep(60)  # Attendre 1 minute en cas d'erreur

async def main():
    """Point d'entrée principal"""
    trainer = ContinuousMLTrainer()
    await trainer.continuous_training_loop()

if __name__ == "__main__":
    asyncio.run(main())
