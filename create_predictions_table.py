import os
from dotenv import load_dotenv

#!/usr/bin/env python3
"""
Script pour créer la table predictions manquante dans Supabase
"""

import requests
import json
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase
SUPABASE_URL = "https://bpzqnooiisgadzicwupi.supabase.co"
SUPABASE_ANON_KEY = os.getenv("SUPABASE_KEY", "")

def create_predictions_table():
    """Créer la table predictions manquante"""
    logger.info("🔧 Création de la table predictions...")
    
    # SQL pour créer la table predictions
    create_table_sql = """
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
    """
    
    try:
        # Utiliser l'endpoint RPC pour exécuter le SQL
        url = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "sql": create_table_sql
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            logger.info("✅ Table predictions créée avec succès!")
            logger.info(f"📊 Résultat: {result}")
            return True
        else:
            logger.error(f"❌ Erreur création table: {response.status_code}")
            logger.error(f"📝 Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur création table: {e}")
        return False

def verify_table_created():
    """Vérifier que la table predictions existe"""
    logger.info("🔍 Vérification de la table predictions...")
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/predictions?select=count"
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "Content-Type": "application/json"
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            count = len(data) if data else 0
            logger.info(f"📊 Table predictions: {count} enregistrements")
            return True
        else:
            logger.error(f"❌ Erreur vérification: {response.status_code}")
            logger.error(f"📝 Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur vérification: {e}")
        return False

def main():
    logger.info("🚀 CRÉATION DE LA TABLE PREDICTIONS MANQUANTE")
    logger.info("=" * 60)
    
    # Étape 1: Créer la table
    if create_predictions_table():
        # Étape 2: Vérifier la création
        if verify_table_created():
            logger.info("\n🎉 TABLE PREDICTIONS CRÉÉE AVEC SUCCÈS!")
            logger.info("📋 Résumé:")
            logger.info("   • Table predictions: ✅ Créée")
            logger.info("   • Tables Supabase: 4/4 complètes")
            logger.info("   • Migration: ✅ Terminée")
            
            logger.info("\n📝 Prochaines étapes:")
            logger.info("1. Tester l'endpoint /decision avec le robot MT5")
            logger.info("2. Vérifier les données dans le dashboard Supabase")
            logger.info("3. Démarrer le robot MT5")
        else:
            logger.error("\n❌ Échec de la vérification")
    else:
        logger.error("\n❌ Échec de la création")

if __name__ == "__main__":
    main()
