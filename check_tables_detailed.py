import os
from dotenv import load_dotenv

#!/usr/bin/env python3
"""
Script pour vérifier en détail le contenu des tables Supabase
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

def check_table_details():
    """Vérifier le contenu détaillé des tables"""
    logger.info("🔍 Vérification détaillée des tables Supabase...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    
    # Tables à vérifier
    tables_to_check = [
        "trade_feedback",
        "predictions", 
        "symbol_calibration"
    ]
    
    for table in tables_to_check:
        try:
            logger.info(f"\n📊 Table: {table}")
            logger.info("-" * 40)
            
            # Compter les enregistrements
            url_count = f"{SUPABASE_URL}/rest/v1/{table}?select=count"
            response = requests.get(url_count, headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                count = len(data) if data else 0
                logger.info(f"Nombre d'enregistrements: {count}")
                
                # Obtenir tous les enregistrements
                url_all = f"{SUPABASE_URL}/rest/v1/{table}?select=*&order=created_at.desc&limit=10"
                response_all = requests.get(url_all, headers=headers, timeout=10)
                
                if response_all.status_code == 200:
                    all_data = response_all.json()
                    
                    if all_data:
                        logger.info(f"Derniers enregistrements ({len(all_data)}):")
                        for i, record in enumerate(all_data[:5]):
                            logger.info(f"  {i+1}. {json.dumps(record, indent=2, default=str)}")
                    else:
                        logger.info("⚠️ Aucun enregistrement trouvé")
                        logger.info("🔍 Vérification de la structure...")
                        
                        # Essayer de voir les colonnes
                        url_structure = f"{SUPABASE_URL}/rest/v1/{table}?select=*&limit=1"
                        response_structure = requests.get(url_structure, headers=headers, timeout=10)
                        
                        if response_structure.status_code == 200:
                            structure_data = response_structure.json()
                            if structure_data:
                                columns = list(structure_data[0].keys())
                                logger.info(f"Colonnes disponibles: {columns}")
                            else:
                                logger.info("⚠️ Impossible de déterminer la structure")
                        else:
                            logger.error(f"❌ Erreur structure: {response_structure.status_code}")
                else:
                    logger.error(f"❌ Erreur récupération données: {response_all.status_code}")
                    logger.error(f"Response: {response_all.text}")
            else:
                logger.error(f"❌ Erreur comptage: {response.status_code}")
                logger.error(f"Response: {response.text}")
                
        except Exception as e:
            logger.error(f"❌ Erreur table {table}: {e}")

def test_insert_data():
    """Tester l'insertion de données"""
    logger.info("\n🧪 Test d'insertion de données...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }
    
    # Test d'insertion dans predictions
    test_data = {
        "symbol": "EURUSD",
        "timeframe": "M1",
        "prediction": "buy",
        "confidence": 0.75,
        "reason": "Test d'insertion",
        "model_used": "test_script"
    }
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/predictions"
        response = requests.post(url, json=test_data, headers=headers, timeout=10)
        
        if response.status_code == 201:
            result = response.json()
            logger.info("✅ Insertion réussie!")
            logger.info(f"📝 Résultat: {result}")
            return True
        else:
            logger.error(f"❌ Erreur insertion: {response.status_code}")
            logger.error(f"Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur insertion: {e}")
        return False

def main():
    logger.info("🚀 VÉRIFICATION DÉTAILLÉE DES TABLES SUPABASE")
    logger.info("=" * 60)
    
    # Étape 1: Vérifier le contenu
    check_table_details()
    
    # Étape 2: Tester l'insertion
    test_insert_data()
    
    logger.info("\n🎉 Vérification terminée!")

if __name__ == "__main__":
    main()
