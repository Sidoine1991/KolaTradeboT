#!/usr/bin/env python3
"""
Script pour vérifier les données via l'API REST Supabase
"""

import os
import requests
import json
import logging
from dotenv import load_dotenv

load_dotenv()

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase (from environment variables)
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_KEY", "")

def check_supabase_api_data():
    """Vérifier les données via l'API REST Supabase"""
    logger.info("🔍 Vérification des données via API Supabase...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    
    # Tables à vérifier
    tables_to_check = [
        "trade_feedback",
        "predictions", 
        "symbol_calibration",
        "ai_decisions"
    ]
    
    for table in tables_to_check:
        try:
            # Compter les enregistrements
            url = f"{SUPABASE_URL}/rest/v1/{table}?select=count"
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                count = len(data) if data else 0
                logger.info(f"📊 {table}: {count} enregistrements")
                
                # Obtenir les derniers enregistrements
                if count > 0:
                    url_recent = f"{SUPABASE_URL}/rest/v1/{table}?select=*&order=created_at.desc&limit=3"
                    response_recent = requests.get(url_recent, headers=headers, timeout=10)
                    
                    if response_recent.status_code == 200:
                        recent_data = response_recent.json()
                        logger.info(f"   Derniers enregistrements dans {table}:")
                        for i, record in enumerate(recent_data[:3]):
                            logger.info(f"     {i+1}. {record}")
                    else:
                        logger.warning(f"   ⚠️ Impossible d'obtenir les détails: {response_recent.status_code}")
                else:
                    logger.info(f"   ⚠️ Aucune donnée dans {table}")
            else:
                logger.error(f"❌ Erreur table {table}: {response.status_code} - {response.text}")
                
        except Exception as e:
            logger.error(f"❌ Erreur vérification table {table}: {e}")
    
    return True

def test_api_connection():
    """Tester la connexion API Supabase"""
    logger.info("🔗 Test de connexion API Supabase...")
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/"
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}"
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            logger.info("✅ Connexion API Supabase réussie!")
            return True
        else:
            logger.error(f"❌ Erreur connexion: {response.status_code}")
            logger.error(f"Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur connexion API: {e}")
        return False

def main():
    logger.info("🚀 VÉRIFICATION DES DONNÉES SUPABASE VIA API")
    logger.info("=" * 60)
    
    # Étape 1: Tester la connexion
    if test_api_connection():
        # Étape 2: Vérifier les données
        if check_supabase_api_data():
            logger.info("\n🎉 Vérification terminée!")
            logger.info("📋 Les données ont été vérifiées via l'API Supabase")
        else:
            logger.error("\n❌ Échec de la vérification des données")
    else:
        logger.error("\n❌ Impossible de se connecter à Supabase")

if __name__ == "__main__":
    main()
