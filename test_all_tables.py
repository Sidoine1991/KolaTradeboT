#!/usr/bin/env python3
"""
Script pour tester l'insertion dans toutes les tables après recréation manuelle
"""

import requests
import json
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase
SUPABASE_URL = "https://bpzqnooiisgadzicwupi.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"

def test_all_tables_insertion():
    """Tester l'insertion dans toutes les tables"""
    logger.info("🧪 Test d'insertion dans toutes les tables...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }
    
    # Tests d'insertion
    tests = [
        {
            "table": "trade_feedback",
            "data": {
                "symbol": "EURUSD",
                "open_time": "2026-02-20T15:44:00+00:00",
                "close_time": "2026-02-20T15:44:30+00:00",
                "entry_price": 1.1765,
                "exit_price": 1.1770,
                "profit": 0.0005,
                "ai_confidence": 0.75,
                "coherent_confidence": 0.80,
                "decision": "buy",
                "is_win": True,
                "timeframe": "M1",
                "side": "buy"
            }
        },
        {
            "table": "predictions",
            "data": {
                "symbol": "GBPUSD",
                "timeframe": "M5",
                "prediction": "sell",
                "confidence": 0.82,
                "reason": "Test post-recréation",
                "model_used": "test_script_v2"
            }
        },
        {
            "table": "symbol_calibration",
            "data": {
                "symbol": "EURUSD",
                "timeframe": "M1",
                "wins": 15,
                "total": 20,
                "drift_factor": 1.05,
                "metadata": {"test": True}
            }
        }
    ]
    
    results = {}
    
    for test in tests:
        table = test["table"]
        data = test["data"]
        
        try:
            logger.info(f"\n📊 Test table: {table}")
            logger.info(f"📝 Données: {json.dumps(data, indent=2)}")
            
            url = f"{SUPABASE_URL}/rest/v1/{table}"
            response = requests.post(url, json=data, headers=headers, timeout=10)
            
            if response.status_code == 201:
                result = response.json()
                logger.info(f"✅ Insertion réussie dans {table}!")
                logger.info(f"📝 Résultat: {result}")
                results[table] = "SUCCESS"
            else:
                logger.error(f"❌ Erreur insertion {table}: {response.status_code}")
                logger.error(f"Response: {response.text}")
                results[table] = f"ERROR: {response.status_code}"
                
        except Exception as e:
            logger.error(f"❌ Erreur insertion {table}: {e}")
            results[table] = f"EXCEPTION: {str(e)}"
    
    return results

def verify_all_tables():
    """Vérifier toutes les tables après insertion"""
    logger.info("\n🔍 Vérification finale des tables...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    
    tables = ["trade_feedback", "predictions", "symbol_calibration"]
    
    for table in tables:
        try:
            url = f"{SUPABASE_URL}/rest/v1/{table}?select=*&order=created_at.desc&limit=3"
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"\n📊 {table}: {len(data)} enregistrements")
                for i, record in enumerate(data[:2]):
                    logger.info(f"   {i+1}. {json.dumps(record, indent=2, default=str)}")
            else:
                logger.error(f"❌ Erreur vérification {table}: {response.status_code}")
                
        except Exception as e:
            logger.error(f"❌ Erreur vérification {table}: {e}")

def main():
    logger.info("🚀 TEST COMPLET DES TABLES SUPABASE APRÈS RECÉATION")
    logger.info("=" * 60)
    
    # Étape 1: Tester les insertions
    results = test_all_tables_insertion()
    
    # Étape 2: Vérifier les résultats
    verify_all_tables()
    
    # Étape 3: Résumé
    logger.info("\n📋 RÉSUMÉ DES TESTS:")
    logger.info("=" * 30)
    for table, result in results.items():
        status = "✅" if result == "SUCCESS" else "❌"
        logger.info(f"{status} {table}: {result}")
    
    success_count = sum(1 for r in results.values() if r == "SUCCESS")
    logger.info(f"\n🎯 Résultat: {success_count}/3 tables fonctionnelles")
    
    if success_count == 3:
        logger.info("🎉 MIGRATION SUPABASE 100% TERMINÉE!")
    else:
        logger.info("⚠️ Migration partielle - tables à corriger")

if __name__ == "__main__":
    main()
