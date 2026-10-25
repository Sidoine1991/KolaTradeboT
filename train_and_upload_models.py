#!/usr/bin/env python3
"""
Script local pour entraîner les modèles ML et les uploader sur le serveur Render
Utilise MT5 local pour les données d'entraînement
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
from datetime import datetime
from pathlib import Path

# Parser les arguments AVANT d'importer ai_server pour éviter les conflits
import argparse
parser = argparse.ArgumentParser(description='Entraînement et upload de modèles ML')
parser.add_argument('--sync-only', action='store_true', 
                   help='Synchroniser les données brutes uniquement (comme trigger_ml_training.py)')
parser.add_argument('--train-upload', action='store_true', 
                   help='Entraîner localement et uploader les modèles (nouveau système)')
args = parser.parse_args()

# Ajouter le répertoire parent au path
sys.path.insert(0, str(Path(__file__).parent))

# Importer les fonctions du serveur local
try:
    from ai_server import (
        train_ml_models,
        collect_historical_data,
        ML_AVAILABLE,
        logger
    )
except ImportError as e:
    print(f"Erreur import ai_server: {e}")
    sys.exit(1)

def get_current_mt5_symbols():
    """Récupère les symboles actuellement ouverts dans MT5"""
    try:
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            logger.error("❌ Impossible d'initialiser MT5")
            return []
        
        # Récupérer tous les graphiques ouverts
        charts = mt5.charts_get()
        
        if not charts:
            logger.warning("⚠️ Aucun graphique ouvert dans MT5")
            # Alternative: récupérer les symboles récemment utilisés
            symbols = mt5.symbols_get()
            if symbols:
                # Prendre les 10 premiers symboles disponibles
                current_symbols = [sym.name for sym in symbols[:10]]
                logger.info(f"📊 Utilisation des 10 premiers symboles disponibles: {current_symbols}")
                return current_symbols
            return []
        
        # Extraire les symboles uniques des graphiques ouverts
        chart_symbols = []
        robots_detected = []
        
        for chart in charts:
            if hasattr(chart, 'symbol') and chart.symbol:
                chart_symbols.append(chart.symbol)
                
                # Vérifier si un robot est attaché à ce graphique
                try:
                    experts = mt5.experts_get(chart.chart_id)
                    if experts:
                        for expert in experts:
                            if hasattr(expert, 'name') and expert.name:
                                robots_detected.append({
                                    'symbol': chart.symbol,
                                    'expert': expert.name,
                                    'chart_id': chart.chart_id
                                })
                                logger.info(f"🤖 Robot détecté: {expert.name} sur {chart.symbol}")
                except:
                    pass  # Ignorer les erreurs de détection de robots
        
        # Supprimer les doublons et limiter à 10 symboles
        unique_symbols = list(set(chart_symbols))[:10]
        
        mt5.shutdown()
        
        if robots_detected:
            logger.info(f"🤖 {len(robots_detected)} robot(s) détecté(s):")
            for robot in robots_detected:
                logger.info(f"   - {robot['expert']} sur {robot['symbol']}")
        
        logger.info(f"📊 Symboles détectés sur les graphiques MT5: {unique_symbols}")
        return unique_symbols
        
    except Exception as e:
        logger.error(f"❌ Erreur récupération symboles MT5: {e}")
        return []

def get_symbols_to_train():
    """Détermine les symboles et timeframes à entraîner"""
    # D'abord essayer de récupérer les symboles actuels de MT5
    current_symbols = get_current_mt5_symbols()
    
    if current_symbols:
        # Pour chaque symbole, essayer de déterminer le timeframe utilisé
        symbols_with_timeframes = []
        
        for symbol in current_symbols:
            # Par défaut, utiliser M1, mais on pourrait détecter le timeframe du robot
            timeframe = "M1"
            symbols_with_timeframes.append((symbol, timeframe))
        
        logger.info(f"📊 Utilisation des symboles actuels avec leurs timeframes: {symbols_with_timeframes}")
        return symbols_with_timeframes
    else:
        # Fallback sur la liste par défaut
        logger.warning("⚠️ Utilisation de la liste par défaut des symboles")
        return [
            ("Boom 300 Index", "M1"),
            ("Boom 600 Index", "M1"),
            ("Boom 900 Index", "M1"),
            ("Crash 1000 Index", "M1"),
            ("EURUSD", "M1"),
            ("GBPUSD", "M1"),
            ("USDJPY", "M1")
        ]

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
# SYMBOLS_TO_TRAIN sera déterminé dynamiquement
SYMBOLS_TO_TRAIN = []  # Sera rempli par get_symbols_to_train()

def serialize_model(model):
    """Sérialise un modèle ML en base64"""
    try:
        # Utiliser pickle pour sérialiser
        model_bytes = pickle.dumps(model)
        # Encoder en base64 pour transmission JSON
        model_b64 = base64.b64encode(model_bytes).decode('utf-8')
        return model_b64
    except Exception as e:
        logger.error(f"Erreur sérialisation modèle: {e}")
        return None

def upload_model_to_render(symbol, timeframe, training_result):
    """Upload un modèle entraîné vers le serveur Render"""
    try:
        # Préparer les données du modèle
        model_data = {}
        
        # Sérialiser chaque modèle s'il existe
        if 'models' in training_result:
            for model_name, model in training_result['models'].items():
                serialized = serialize_model(model)
                if serialized:
                    model_data[model_name] = serialized
        
        # Préparer la requête
        upload_data = {
            "symbol": symbol,
            "timeframe": timeframe,
            "model_data": model_data,
            "metrics": training_result.get('metrics', {}),
            "training_samples": training_result.get('training_samples', 0),
            "test_samples": training_result.get('test_samples', 0),
            "best_model": training_result.get('best_model', 'unknown'),
            "timestamp": datetime.now().isoformat()
        }
        
        # Envoyer vers Render
        response = requests.post(
            f"{RENDER_API_URL}/ml/upload-model",
            json=upload_data,
            timeout=30
        )
        
        if response.status_code == 200:
            logger.info(f"✅ Modèle {symbol} {timeframe} uploadé avec succès")
            return response.json()
        else:
            logger.error(f"❌ Erreur upload {symbol} {timeframe}: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"Erreur upload modèle {symbol} {timeframe}: {e}")
        return None

def sync_data_to_render(symbol, timeframe):
    """Alternative: synchronise les données brutes avec Render (comme l'ancien script)"""
    try:
        logger.info(f"🔄 Synchronisation des données brutes avec Render pour {symbol} ({timeframe})...")
        
        # Récupérer les données historiques depuis MT5
        import MetaTrader5 as mt5
        
        if not mt5.initialize():
            logger.error("❌ Impossible d'initialiser MT5 pour la synchronisation")
            return False
        
        tf_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'M30': mt5.TIMEFRAME_M30,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1
        }
        
        mt5_tf = tf_map.get(timeframe, mt5.TIMEFRAME_M1)
        rates = mt5.copy_rates_from_pos(symbol, mt5_tf, 0, 2000)  # 2000 barres comme l'ancien script
        
        mt5.shutdown()
        
        if rates is None or len(rates) < 100:
            logger.warning(f"⚠️ Pas assez de données pour {symbol} ({timeframe}) - Skip synchronisation")
            return False
            
        # Convertir en DataFrame puis en dict pour JSON
        df = pd.DataFrame(rates)
        data_to_send = df.to_dict(orient='records')
        
        payload = {
            "symbol": symbol,
            "timeframe": timeframe,
            "data": data_to_send
        }
        
        # Envoyer à Render avec timeout long
        response = requests.post(f"{RENDER_API_URL}/ml/train", json=payload, timeout=180)
        
        if response.status_code == 200:
            result = response.json()
            logger.info(f"✅ Synchronisation Render réussie pour {symbol} ({timeframe})")
            if 'metrics' in result:
                for model_name, metric in result['metrics'].items():
                    logger.info(f"   📊 {model_name}: Accuracy={metric.get('accuracy', 0):.4f}")
            return True
        else:
            logger.error(f"❌ Échec synchronisation Render: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur synchronisation Render pour {symbol} ({timeframe}): {e}")
        return False

def train_and_upload_all(sync_data_only=False):
    """
    Entraîne et upload tous les modèles
    sync_data_only: si True, ne fait que synchroniser les données (comme l'ancien script)
    """
    logger.info(f"🚀 Début de l'entraînement et upload des modèles ML")
    if sync_data_only:
        logger.info("📡 Mode synchronisation données uniquement (comme l'ancien trigger_ml_training.py)")
    else:
        logger.info("🤖 Mode entraînement local + upload modèles")
    
    if not ML_AVAILABLE:
        logger.error("❌ ML non disponible - impossible d'entraîner les modèles")
        return False
    
    # Déterminer dynamiquement les symboles à entraîner
    symbols_to_train = get_symbols_to_train()
    
    if not symbols_to_train:
        logger.error("❌ Aucun symbole à entraîner trouvé")
        return False
    
    logger.info(f"📊 {len(symbols_to_train)} symbole(s) à traiter: {[f'{s} {tf}' for s, tf in symbols_to_train]}")
    
    results = []
    
    for symbol, timeframe in symbols_to_train:
        logger.info(f"\n📊 Traitement de {symbol} {timeframe}")
        
        try:
            if sync_data_only:
                # Mode synchronisation données (comme l'ancien script)
                logger.info(f"   🔄 Synchronisation des données brutes pour {symbol} {timeframe}...")
                sync_success = sync_data_to_render(symbol, timeframe)
                
                if sync_success:
                    results.append({
                        'symbol': symbol,
                        'timeframe': timeframe,
                        'status': 'sync_success',
                        'mode': 'data_sync'
                    })
                    logger.info(f"   ✅ Synchronisation réussie pour {symbol} {timeframe}")
                else:
                    results.append({
                        'symbol': symbol,
                        'timeframe': timeframe,
                        'status': 'sync_failed',
                        'mode': 'data_sync'
                    })
                    logger.error(f"   ❌ Synchronisation échouée pour {symbol} {timeframe}")
            else:
                # Mode entraînement local + upload (nouveau système)
                logger.info(f"   Entraînement du modèle pour {symbol} {timeframe}...")
                training_result = train_ml_models(symbol, timeframe)
                
                if training_result.get('status') == 'success':
                    logger.info(f"   ✅ Entraînement réussi pour {symbol} {timeframe}")
                    
                    # Uploader vers Render
                    upload_result = upload_model_to_render(symbol, timeframe, training_result)
                    
                    if upload_result:
                        results.append({
                            'symbol': symbol,
                            'timeframe': timeframe,
                            'status': 'success',
                            'training': training_result,
                            'upload': upload_result,
                            'mode': 'train_upload'
                        })
                        logger.info(f"   ✅ Upload réussi pour {symbol} {timeframe}")
                    else:
                        results.append({
                            'symbol': symbol,
                            'timeframe': timeframe,
                            'status': 'upload_failed',
                            'training': training_result,
                            'mode': 'train_upload'
                        })
                        logger.error(f"   ❌ Upload échoué pour {symbol} {timeframe}")
                else:
                    logger.error(f"   ❌ Entraînement échoué pour {symbol} {timeframe}: {training_result.get('message', 'Erreur inconnue')}")
                    results.append({
                        'symbol': symbol,
                        'timeframe': timeframe,
                        'status': 'training_failed',
                        'error': training_result.get('message'),
                        'mode': 'train_upload'
                    })
                
        except Exception as e:
            logger.error(f"   ❌ Erreur traitement {symbol} {timeframe}: {e}")
            results.append({
                'symbol': symbol,
                'timeframe': timeframe,
                'status': 'error',
                'error': str(e),
                'mode': 'sync_data_only' if sync_data_only else 'train_upload'
            })
        
        # Pause entre chaque traitement pour éviter la surcharge
        time.sleep(2)
    
    # Résumé
    logger.info("\n" + "="*60)
    logger.info("📋 RÉSUMÉ DE L'ENTRAÎNEMENT ET UPLOAD")
    logger.info("="*60)
    
    success_count = sum(1 for r in results if r['status'] == 'success')
    total_count = len(results)
    
    for result in results:
        status_emoji = "✅" if result['status'] == 'success' else "❌"
        logger.info(f"{status_emoji} {result['symbol']} {result['timeframe']}: {result['status']}")
    
    logger.info(f"\n🎯 Total: {success_count}/{total_count} modèles uploadés avec succès")
    
    # Sauvegarder le rapport
    report_file = f"training_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    logger.info(f"📄 Rapport sauvegardé: {report_file}")
    
    return success_count == total_count

def check_render_status():
    """Vérifie l'état du serveur Render"""
    try:
        response = requests.get(f"{RENDER_API_URL}/health", timeout=10)
        if response.status_code == 200:
            health = response.json()
            logger.info("✅ Serveur Render accessible")
            logger.info(f"   MT5 initialisé: {health.get('mt5_initialized', False)}")
            logger.info(f"   yfinance disponible: {health.get('yfinance_available', False)}")
            return True
        else:
            logger.error(f"❌ Serveur Render inaccessible: {response.status_code}")
            return False
    except Exception as e:
        logger.error(f"❌ Erreur connexion Render: {e}")
        return False

def main():
    """Fonction principale"""
    print("="*60)
    print("TRADBOT ML - TRAINING & UPLOAD SCRIPT")
    print("="*60)
    
    # Utiliser les arguments déjà parsés
    sync_data_only = args.sync_only
    if not sync_data_only and not args.train_upload:
        sync_data_only = False  # Mode par défaut: entraînement + upload
    
    # Vérifier la connexion à Render
    logger.info("Vérification de la connexion au serveur Render...")
    if not check_render_status():
        logger.error("Impossible de se connecter au serveur Render")
        return False
    
    # Lancer l'entraînement et l'upload
    success = train_and_upload_all(sync_data_only=sync_data_only)
    
    if success:
        if sync_data_only:
            logger.info("\nTOUTES LES DONNEES ONT ETE SYNCHRONISEES AVEC SUCCES!")
            logger.info("Le serveur Render a entraîné les modèles avec les données envoyées.")
        else:
            logger.info("\nTOUS LES MODELES ONT ETE ENTRAINEES ET UPLOADES AVEC SUCCES!")
            logger.info("Le serveur Render peut maintenant utiliser ces modèles pour les prédictions.")
    else:
        if sync_data_only:
            logger.error("\nCERTAINES SYNCHRONISATIONS N'ONT PAS PU ETRE EFFECTUEES")
        else:
            logger.error("\nCERTAINS MODELES N'ONT PAS PU ETRE TRAITES")
        logger.info("Vérifiez les logs ci-dessus pour plus de détails.")
    
    return success

if __name__ == "__main__":
    # Configurer le logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(f'training_upload_{datetime.now().strftime("%Y%m%d")}.log'),
            logging.StreamHandler()
        ]
    )
    
    # Exécuter le script
    main()
