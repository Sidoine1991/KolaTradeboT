#!/usr/bin/env python3
"""
Script minimal pour synchroniser les données avec Render
Évite tous les problèmes de dépendances
"""

import os
import sys
import json
import time
import logging
import requests
import argparse
from datetime import datetime
from pathlib import Path

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'training_minimal_{datetime.now().strftime("%Y%m%d")}.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("train_models_minimal")

# Parser les arguments
parser = argparse.ArgumentParser(description='Synchronisation des données avec Render')
parser.add_argument('--sync-only', action='store_true', 
                   help='Synchroniser les données brutes uniquement')
parser.add_argument('--train-upload', action='store_true', 
                   help='Synchroniser les données (mode simple)')
args = parser.parse_args()

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
SYMBOLS_TO_SYNC = [
    ("Boom 300 Index", "M1"),
    ("Boom 600 Index", "M1"),
    ("Boom 900 Index", "M1"),
    ("Crash 1000 Index", "M1"),
    ("EURUSD", "M1"),
    ("GBPUSD", "M1"),
    ("USDJPY", "M1")
]

def sync_data_to_render(symbol, timeframe):
    """Envoie les données brutes à Render"""
    try:
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            logger.error(f"Impossible d'initialiser MT5 pour {symbol}")
            return False
        
        tf_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5
        }
        
        mt5_tf = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
        rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 1000)
        
        mt5.shutdown()
        
        if rates is None or len(rates) < 100:
            logger.warning(f"Pas assez de données pour {symbol}")
            return False
            
        # Convertir en JSON simple
        data_to_send = []
        for rate in rates:
            data_to_send.append({
                "time": int(rate["time"]),
                "open": float(rate["open"]),
                "high": float(rate["high"]),
                "low": float(rate["low"]),
                "close": float(rate["close"]),
                "tick_volume": int(rate["tick_volume"])
            })
        
        payload = {
            "symbol": symbol,
            "timeframe": timeframe,
            "data": data_to_send
        }
        
        logger.info(f"Envoi de {len(data_to_send)} bougies pour {symbol}...")
        
        response = requests.post(f"{RENDER_API_URL}/ml/train", json=payload, timeout=180)
        
        if response.status_code == 200:
            logger.info(f"Données synchronisées: {symbol} {timeframe}")
            return True
        else:
            logger.error(f"Erreur synchronisation {symbol}: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"Erreur synchronisation {symbol}: {e}")
        return False

def check_render_status():
    """Vérifie si le serveur Render est accessible"""
    try:
        response = requests.get(f"{RENDER_API_URL}/health", timeout=10)
        if response.status_code == 200:
            logger.info("Serveur Render accessible")
            return True
        else:
            logger.error(f"Serveur Render erreur: {response.status_code}")
            return False
    except Exception as e:
        logger.error(f"Impossible de contacter Render: {e}")
        return False

def main():
    """Fonction principale"""
    print("="*60)
    print("TRADBOT ML - SYNCHRONISATION MINIMALE")
    print("="*60)
    
    # Vérifier Render
    if not check_render_status():
        logger.error("Serveur Render inaccessible")
        return
    
    # Utiliser les symboles par défaut
    symbols_to_sync = SYMBOLS_TO_SYNC
    logger.info(f"Symboles à synchroniser: {[f'{s} {tf}' for s, tf in symbols_to_sync]}")
    
    success_count = 0
    
    for symbol, timeframe in symbols_to_sync:
        logger.info(f"\nSynchronisation de {symbol} {timeframe}")
        
        if sync_data_to_render(symbol, timeframe):
            success_count += 1
        
        time.sleep(2)  # Pause entre chaque symbole
    
    logger.info(f"\nRésultat: {success_count}/{len(symbols_to_sync)} succès")
    
    if success_count > 0:
        logger.info("SUCCES: Données envoyées à Render")
        logger.info("Le serveur Render va entraîner les modèles avec ces données")
    else:
        logger.warning("ERREUR: Aucune donnée n'a pu être synchronisée")

if __name__ == "__main__":
    main()
