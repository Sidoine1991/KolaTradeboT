#!/usr/bin/env python3
"""
Script simple pour entraîner les modèles ML et les uploader sur Render
Évite les conflits avec ai_server
"""

import os
import sys
import json
import time
import logging
import requests
import joblib
import pickle
import base64
import argparse
from datetime import datetime
from pathlib import Path

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'training_upload_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("train_models_simple")

# Parser les arguments
parser = argparse.ArgumentParser(description='Entraînement et upload de modèles ML')
parser.add_argument('--sync-only', action='store_true', 
                   help='Synchroniser les données brutes uniquement')
parser.add_argument('--train-upload', action='store_true', 
                   help='Entraîner localement et uploader les modèles')
args = parser.parse_args()

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
SYMBOLS_TO_TRAIN = [
    ("Boom 300 Index", "M1"),
    ("Boom 600 Index", "M1"),
    ("Boom 900 Index", "M1"),
    ("Crash 1000 Index", "M1"),
    ("EURUSD", "M1"),
    ("GBPUSD", "M1"),
    ("USDJPY", "M1")
]

def get_current_mt5_symbols():
    """Récupère les symboles actuellement disponibles dans MT5"""
    try:
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            logger.error("Impossible d'initialiser MT5")
            return []
        
        # Utiliser symbols_get au lieu de charts_get
        symbols = mt5.symbols_get()
        mt5.shutdown()
        
        if symbols:
            # Prendre les 10 premiers symboles disponibles
            current_symbols = [sym.name for sym in symbols[:10]]
            logger.info(f"Symboles disponibles: {current_symbols}")
            return current_symbols
        else:
            logger.warning("Aucun symbole disponible, utilisation des symboles par défaut")
            return [s[0] for s in SYMBOLS_TO_TRAIN]
        
    except Exception as e:
        logger.error(f"Erreur récupération symboles MT5: {e}")
        return [s[0] for s in SYMBOLS_TO_TRAIN]

def serialize_model(model):
    """Sérialise un modèle ML en base64"""
    try:
        model_bytes = pickle.dumps(model)
        model_b64 = base64.b64encode(model_bytes).decode('utf-8')
        return model_b64
    except Exception as e:
        logger.error(f"Erreur sérialisation modèle: {e}")
        return None

def upload_model_to_render(symbol, timeframe, model_data, metrics):
    """Upload un modèle entraîné vers Render"""
    try:
        payload = {
            "symbol": symbol,
            "timeframe": timeframe,
            "model_data": model_data,
            "metrics": metrics,
            "training_samples": metrics.get('training_samples', 0),
            "test_samples": metrics.get('test_samples', 0),
            "best_model": metrics.get('best_model', 'unknown'),
            "timestamp": datetime.now().isoformat()
        }
        
        response = requests.post(
            f"{RENDER_API_URL}/ml/upload-model",
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            logger.info(f"Modèle uploadé: {symbol} {timeframe}")
            return response.json()
        else:
            logger.error(f"Erreur upload {symbol}: {response.status_code}")
            return None
            
    except Exception as e:
        logger.error(f"Erreur upload modèle {symbol}: {e}")
        return None

def sync_data_to_render(symbol, timeframe):
    """Envoie les données brutes à Render"""
    try:
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            logger.error("Impossible d'initialiser MT5")
            return False
        
        tf_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5
        }
        
        mt5_tf = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
        rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 2000)
        
        mt5.shutdown()
        
        if rates is None or len(rates) < 100:
            logger.warning(f"Pas assez de données pour {symbol}")
            return False
            
        # Convertir en JSON
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
            "data": data_to_send
        }
        
        response = requests.post(f"{RENDER_API_URL}/ml/train", json=payload, timeout=180)
        
        if response.status_code == 200:
            logger.info(f"Données synchronisées: {symbol} {timeframe}")
            return True
        else:
            logger.error(f"Erreur synchronisation {symbol}: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"Erreur synchronisation {symbol}: {e}")
        return False

def train_model_locally(symbol, timeframe):
    """Entraîne un modèle localement (version ultra-simplifiée)"""
    try:
        import MetaTrader5 as mt5
        import pandas as pd
        import numpy as np
        from sklearn.ensemble import RandomForestClassifier
        from sklearn.model_selection import train_test_split
        
        if not mt5.initialize():
            logger.error("Impossible d'initialiser MT5")
            return None
        
        tf_map = {'M1': mt5.TIMEFRAME_M1, 'M5': mt5.TIMEFRAME_M5}
        mt5_tf = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
        
        rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 2000)  # Réduit à 2000
        mt5.shutdown()
        
        if rates is None or len(rates) < 500:
            logger.error(f"Pas assez de données pour entraîner {symbol}")
            return None
        
        # Convertir en DataFrame avec types simples
        df = pd.DataFrame({
            'close': [float(r['close']) for r in rates],
            'volume': [int(r['tick_volume']) for r in rates]
        })
        
        # Features ultra-simples pour éviter les erreurs
        df['sma_10'] = df['close'].rolling(10).mean()
        df['sma_20'] = df['close'].rolling(20).mean()
        df['price_change'] = df['close'].pct_change()
        
        # Labels simples
        df['future_return'] = df['close'].shift(-3) / df['close'] - 1
        df['label'] = np.where(df['future_return'] > 0.005, 1,  # 0.5%
                              np.where(df['future_return'] < -0.005, -1, 0))  # -0.5%
        
        # Nettoyer
        df = df.dropna()
        
        if len(df) < 200:
            logger.error(f"Pas assez de données nettoyées pour {symbol}")
            return None
        
        # Préparer les données
        features = ['sma_10', 'sma_20', 'price_change', 'volume']
        X = df[features].values
        y = df['label'].values
        
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        # Entraîner avec paramètres simples
        model = RandomForestClassifier(n_estimators=50, random_state=42, max_depth=10)
        model.fit(X_train, y_train)
        
        # Évaluer
        train_score = model.score(X_train, y_train)
        test_score = model.score(X_test, y_test)
        
        logger.info(f"Modèle entraîné pour {symbol}: train={train_score:.3f}, test={test_score:.3f}")
        
        # Sérialiser
        model_data = {
            'RandomForest': serialize_model(model)
        }
        
        metrics = {
            'RandomForest': {
                'train_accuracy': float(train_score),
                'test_accuracy': float(test_score)
            },
            'training_samples': int(len(X_train)),
            'test_samples': int(len(X_test)),
            'best_model': 'RandomForest'
        }
        
        return {
            'status': 'success',
            'model_data': model_data,
            'metrics': metrics
        }
        
    except Exception as e:
        logger.error(f"Erreur entraînement {symbol}: {e}")
        return None

def main():
    """Fonction principale"""
    print("="*60)
    print("TRADBOT ML - TRAINING SCRIPT (SIMPLE)")
    print("="*60)
    
    sync_data_only = args.sync_only
    if not sync_data_only and not args.train_upload:
        sync_data_only = False  # Mode par défaut
    
    # Obtenir les symboles
    current_symbols = get_current_mt5_symbols()
    if not current_symbols:
        current_symbols = [s[0] for s in SYMBOLS_TO_TRAIN]
    
    symbols_to_train = [(s, "M1") for s in current_symbols]
    
    logger.info(f"Symboles à traiter: {[f'{s} {tf}' for s, tf in symbols_to_train]}")
    
    success_count = 0
    
    for symbol, timeframe in symbols_to_train:
        logger.info(f"\nTraitement de {symbol} {timeframe}")
        
        try:
            if sync_data_only:
                # Mode synchronisation
                if sync_data_to_render(symbol, timeframe):
                    success_count += 1
            else:
                # Mode entraînement + upload
                result = train_model_locally(symbol, timeframe)
                
                if result and result['status'] == 'success':
                    if upload_model_to_render(symbol, timeframe, result['model_data'], result['metrics']):
                        success_count += 1
                        
        except Exception as e:
            logger.error(f"Erreur traitement {symbol}: {e}")
        
        time.sleep(1)
    
    logger.info(f"\nRésultat: {success_count}/{len(symbols_to_train)} succès")
    
    if success_count == len(symbols_to_train):
        logger.info("SUCCES: Tous les modèles traités")
    else:
        logger.warning("ERREUR: Certains modèles n'ont pas pu être traités")

if __name__ == "__main__":
    main()
