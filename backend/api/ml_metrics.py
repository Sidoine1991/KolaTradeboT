#!/usr/bin/env python3
"""
API endpoint pour récupérer les vraies métriques ML depuis Supabase
Utilisé par MT5 pour afficher les métriques sur le graphique
"""

import os
import json
import httpx
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from fastapi import APIRouter, HTTPException
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv('.env.supabase')

router = APIRouter()

class MLMetricsAPI:
    """API pour les métriques ML en temps réel"""
    
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
        
        if not self.supabase_url or not self.supabase_key:
            print("❌ Configuration Supabase manquante pour ML Metrics API")
    
    async def get_latest_training_metrics(self, symbol: str, timeframe: str = "M1") -> Dict[str, Any]:
        """Récupère les dernières métriques d'entraînement pour un symbole"""
        if not self.supabase_url or not self.supabase_key:
            return {"error": "Configuration Supabase manquante"}
        
        try:
            async with httpx.AsyncClient() as client:
                # Récupérer le dernier training run
                training_url = f"{self.supabase_url}/rest/v1/training_runs"
                training_params = {
                    "symbol": f"eq.{symbol}",
                    "timeframe": f"eq.{timeframe}",
                    "order": "created_at.desc",
                    "limit": 1
                }
                
                training_resp = await client.get(
                    training_url,
                    params=training_params,
                    headers={
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                    },
                    timeout=10.0
                )
                
                if training_resp.status_code != 200:
                    return {"error": f"Training runs error: {training_resp.status_code}"}
                
                training_data = training_resp.json()
                if not training_data:
                    return {"error": "Aucune donnée d'entraînement trouvée"}
                
                latest_training = training_data[0]
                
                # Récupérer les features importance pour ce training
                feature_url = f"{self.supabase_url}/rest/v1/feature_importance"
                feature_params = {
                    "symbol": f"eq.{symbol}",
                    "timeframe": f"eq.{timeframe}",
                    "order": "importance.desc",
                    "limit": 5
                }
                
                feature_resp = await client.get(
                    feature_url,
                    params=feature_params,
                    headers={
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                    },
                    timeout=10.0
                )
                
                features_data = []
                if feature_resp.status_code == 200:
                    features_data = feature_resp.json()
                
                # Récupérer la calibration du symbole
                calibration_url = f"{self.supabase_url}/rest/v1/symbol_calibration"
                calibration_params = {
                    "symbol": f"eq.{symbol}",
                    "timeframe": f"eq.{timeframe}",
                    "order": "last_updated.desc",
                    "limit": 1
                }
                
                calibration_resp = await client.get(
                    calibration_url,
                    params=calibration_params,
                    headers={
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                    },
                    timeout=10.0
                )
                
                calibration_data = None
                if calibration_resp.status_code == 200:
                    cal_data = calibration_resp.json()
                    if cal_data:
                        calibration_data = cal_data[0]
                
                # Construire la réponse complète
                response = {
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "last_training": {
                        "status": latest_training.get("status", "unknown"),
                        "accuracy": latest_training.get("accuracy", 0),
                        "f1_score": latest_training.get("f1_score", 0),
                        "samples_used": latest_training.get("samples_used", 0),
                        "duration_sec": latest_training.get("duration_sec", 0),
                        "model_type": latest_training.get("metadata", {}).get("model_type", "unknown"),
                        "created_at": latest_training.get("created_at"),
                        "training_level": self._calculate_training_level(latest_training.get("samples_used", 0))
                    },
                    "top_features": [
                        {
                            "name": feat.get("feature_name", "unknown"),
                            "importance": feat.get("importance", 0),
                            "rank": feat.get("rank", i+1)
                        }
                        for i, feat in enumerate(features_data[:5])
                    ],
                    "calibration": {
                        "drift_factor": calibration_data.get("drift_factor", 0) if calibration_data else 0,
                        "wins": calibration_data.get("wins", 0) if calibration_data else 0,
                        "total": calibration_data.get("total", 0) if calibration_data else 0,
                        "win_rate": (calibration_data.get("wins", 0) / max(1, calibration_data.get("total", 1)) * 100) if calibration_data else 0,
                        "last_updated": calibration_data.get("last_updated") if calibration_data else None
                    } if calibration_data else None,
                    "ml_response": {
                        "confidence": self._get_latest_ml_confidence(symbol),
                        "prediction": self._get_latest_ml_prediction(symbol),
                        "timestamp": self._get_latest_ml_timestamp(symbol)
                    }
                }
                
                return response
                
        except Exception as e:
            return {"error": f"Exception: {str(e)}"}
    
    def _calculate_training_level(self, samples: int) -> str:
        """Calcule le niveau d'entraînement basé sur le nombre d'échantillons"""
        if samples < 100:
            return "🔴 DÉBUTANT"
        elif samples < 500:
            return "🟡 INTERMÉDIAIRE"
        elif samples < 1000:
            return "🟢 AVANCÉ"
        else:
            return "🔵 EXPERT"
    
    def _get_latest_ml_confidence(self, symbol: str) -> float:
        """Récupère la dernière confiance ML (simulation pour l'instant)"""
        # TODO: Implémenter avec vraies données depuis predictions table
        return 0.75  # Placeholder
    
    def _get_latest_ml_prediction(self, symbol: str) -> str:
        """Récupère la dernière prédiction ML (simulation pour l'instant)"""
        # TODO: Implémenter avec vraies données depuis predictions table
        return "BUY"  # Placeholder
    
    def _get_latest_ml_timestamp(self, symbol: str) -> str:
        """Récupère le timestamp de la dernière prédiction ML"""
        # TODO: Implémenter avec vraies données
        return datetime.now().isoformat()

# Instance globale
ml_metrics_api = MLMetricsAPI()

@router.get("/metrics/{symbol}")
async def get_ml_metrics(symbol: str, timeframe: str = "M1"):
    """Endpoint pour récupérer les métriques ML pour un symbole"""
    try:
        # Nettoyer le symbole (remplacer les espaces par des underscores)
        clean_symbol = symbol.replace(" ", "_")
        
        metrics = await ml_metrics_api.get_latest_training_metrics(clean_symbol, timeframe)
        
        if "error" in metrics:
            raise HTTPException(status_code=404, detail=metrics["error"])
        
        return metrics
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur: {str(e)}")

@router.get("/training-status/{symbol}")
async def get_training_status(symbol: str, timeframe: str = "M1"):
    """Endpoint simplifié pour le statut d'entraînement"""
    metrics = await ml_metrics_api.get_latest_training_metrics(symbol, timeframe)
    
    if "error" in metrics:
        return {"status": "no_data", "message": metrics["error"]}
    
    return {
        "status": "ok",
        "symbol": symbol,
        "training_level": metrics["last_training"]["training_level"],
        "accuracy": metrics["last_training"]["accuracy"],
        "model_type": metrics["last_training"]["model_type"],
        "last_updated": metrics["last_training"]["created_at"]
    }
