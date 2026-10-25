#!/usr/bin/env python3
"""
Script de configuration Supabase avec authentification par token
Utilise l'API REST Supabase au lieu de la connexion directe
"""

import os
import requests
import logging
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase depuis .env.supabase
SUPABASE_URL = "https://bpzqnooiisgadzicwupi.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"

def create_tables_via_api():
    """Créer les tables via l'API REST Supabase"""
    logger.info("🔧 Création des tables via API Supabase...")
    
    # SQL pour créer les tables
    create_tables_sql = """
    -- Table trade_feedback
    CREATE TABLE IF NOT EXISTS trade_feedback (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        open_time TIMESTAMPTZ NOT NULL,
        close_time TIMESTAMPTZ,
        entry_price DECIMAL(15,5),
        exit_price DECIMAL(15,5),
        profit DECIMAL(15,5),
        ai_confidence DECIMAL(5,4),
        coherent_confidence DECIMAL(5,4),
        decision TEXT,
        is_win BOOLEAN,
        created_at TIMESTAMPTZ DEFAULT now(),
        timeframe TEXT DEFAULT 'M1',
        side TEXT
    );
    
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol ON trade_feedback(symbol);
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_created_at ON trade_feedback(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_timeframe ON trade_feedback(timeframe);
    
    -- Table predictions
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        prediction TEXT NOT NULL,
        confidence DECIMAL(5,4),
        reason TEXT,
        created_at TIMESTAMPTZ DEFAULT now(),
        model_used TEXT,
        metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS idx_predictions_symbol ON predictions(symbol);
    CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_predictions_timeframe ON predictions(timeframe);
    
    -- Table symbol_calibration
    CREATE TABLE IF NOT EXISTS symbol_calibration (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        timeframe TEXT DEFAULT 'M1',
        wins INTEGER DEFAULT 0,
        total INTEGER DEFAULT 0,
        drift_factor DECIMAL(10,6) DEFAULT 1.0,
        last_updated TIMESTAMPTZ DEFAULT now(),
        metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS idx_symbol_calibration_symbol ON symbol_calibration(symbol);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_symbol_calibration_unique ON symbol_calibration(symbol, timeframe);
    
    -- Table ai_decisions
    CREATE TABLE IF NOT EXISTS ai_decisions (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        action TEXT NOT NULL,
        confidence DECIMAL(5,4),
        reason TEXT,
        created_at TIMESTAMPTZ DEFAULT now(),
        model_used TEXT,
        metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS idx_ai_decisions_symbol ON ai_decisions(symbol);
    CREATE INDEX IF NOT EXISTS idx_ai_decisions_created_at ON ai_decisions(created_at DESC);
    """
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    
    try:
        # Utiliser l'endpoint RPC de Supabase
        url = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"
        
        payload = {
            "sql": create_tables_sql
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            logger.info("✅ Tables créées avec succès via API!")
            logger.info(f"📊 Résultat: {result}")
            return True
        else:
            logger.error(f"❌ Erreur création tables: {response.status_code}")
            logger.error(f"📝 Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur lors de la création des tables: {e}")
        return False

def test_supabase_connection():
    """Tester la connexion à Supabase via API"""
    logger.info("🔍 Test de connexion API Supabase...")
    
    try:
        # Test simple query
        url = f"{SUPABASE_URL}/rest/v1/rpc/get_version"
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Content-Type": "application/json"
        }
        
        response = requests.post(url, json={}, headers=headers, timeout=10)
        
        if response.status_code == 200:
            logger.info("✅ Connexion API Supabase réussie!")
            return True
        else:
            logger.error(f"❌ Erreur connexion API: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur test connexion: {e}")
        return False

def create_env_file():
    """Créer le fichier .env pour utiliser Supabase"""
    logger.info("📝 Création du fichier .env pour Supabase...")
    
    env_content = f"""# Configuration KolaTradeBoT avec Supabase
# Généré le {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

# Configuration Supabase
SUPABASE_URL={SUPABASE_URL}
SUPABASE_ANON_KEY={SUPABASE_ANON_KEY}
SUPABASE_PROJECT_ID=bpzqnooiisgadzicwupi
SUPABASE_PROJECT_NAME=KolaTradeBoT

# Mode Supabase activé
SUPABASE_MODE=enabled

# Pour le serveur AI (utilise l'API REST au lieu de connexion directe)
SUPABASE_USE_API=true
"""
    
    with open(".env.supabase_api", "w", encoding="utf-8") as f:
        f.write(env_content)
    
    logger.info("✅ Fichier .env.supabase_api créé!")
    return ".env.supabase_api"

def update_ai_server_for_api():
    """Mettre à jour ai_server.py pour utiliser l'API Supabase"""
    logger.info("📝 Préparation de ai_server.py pour l'API Supabase...")
    
    try:
        with open("ai_server.py", "r", encoding="utf-8") as f:
            content = f.read()
        
        # Créer une version modifiée pour utiliser l'API
        api_integration_code = '''
# Configuration Supabase API
import requests
import json

# Variables globales Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")
SUPABASE_USE_API = os.getenv("SUPABASE_USE_API", "false").lower() == "true"

def execute_supabase_query(query, params=None):
    """Exécuter une requête SQL via l'API Supabase"""
    if not SUPABASE_USE_API:
        return None
        
    try:
        url = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {"sql": query}
        if params:
            payload["params"] = params
            
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        if response.status_code == 200:
            return response.json()
        else:
            logger.error(f"Erreur SQL API: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"Erreur requête SQL API: {e}")
        return None

# Remplacer les fonctions de base de données par des appels API
async def get_db_pool():
    """Utiliser l'API Supabase au lieu du pool de connexion"""
    if SUPABASE_USE_API:
        logger.info("📊 Utilisation de l'API Supabase (mode sans connexion directe)")
        return None
    return await original_get_db_pool()

# Sauvegarder la fonction originale
original_get_db_pool = None
if "get_db_pool" in globals():
    original_get_db_pool = globals()["get_db_pool"]
'''
        
        # Insérer le code d'intégration API au début du fichier
        updated_content = api_integration_code + "\n" + content
        
        # Sauvegarder la nouvelle version
        with open("ai_server_supabase_api.py", "w", encoding="utf-8") as f:
            f.write(updated_content)
        
        logger.info("✅ ai_server_supabase_api.py créé!")
        return True
        
    except Exception as e:
        logger.error(f"❌ Erreur mise à jour ai_server.py: {e}")
        return False

def main():
    """Fonction principale"""
    logger.info("🚀 CONFIGURATION SUPABASE API POUR KOLATRADEBOT")
    logger.info("=" * 60)
    
    # Étape 1: Tester la connexion API
    if not test_supabase_connection():
        logger.error("❌ Impossible de se connecter à l'API Supabase")
        return
    
    try:
        # Étape 2: Créer les tables via API
        if create_tables_via_api():
            logger.info("✅ Tables créées avec succès!")
            
            # Étape 3: Créer le fichier .env
            env_file = create_env_file()
            
            # Étape 4: Mettre à jour ai_server.py
            if update_ai_server_for_api():
                logger.info("✅ Serveur mis à jour pour l'API!")
                
                logger.info("🎉 CONFIGURATION SUPABASE API TERMINÉE!")
                logger.info("📋 Résumé:")
                logger.info("   • Tables créées via API REST")
                logger.info(f"   • Fichier config: {env_file}")
                logger.info("   • Serveur mis à jour: ai_server_supabase_api.py")
                
                logger.info("📝 Prochaines étapes:")
                logger.info("1. Copier .env.supabase_api vers .env:")
                logger.info("   cp .env.supabase_api .env")
                logger.info("")
                logger.info("2. Démarrer le serveur avec l'API:")
                logger.info("   python ai_server_supabase_api.py")
                logger.info("")
                logger.info("3. Vérifier le démarrage:")
                logger.info("   curl http://localhost:8000/health")
        
    except Exception as e:
        logger.error(f"❌ Erreur durant la configuration: {e}")

if __name__ == "__main__":
    main()
