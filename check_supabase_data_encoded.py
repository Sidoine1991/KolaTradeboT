#!/usr/bin/env python3
"""
Script pour vérifier les données dans les tables Supabase avec URL encodée
"""

import os
import psycopg2
import logging
import urllib.parse

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_supabase_data():
    """Vérifier les données dans les tables Supabase"""
    logger.info("🔍 Vérification des données Supabase...")
    
    # Configuration de la base de données avec URL encodée
    password = "Socrate2025@1991"
    encoded_password = urllib.parse.quote_plus(password)
    
    database_url = f"postgresql://postgres:{encoded_password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require"
    
    logger.info(f"🔗 URL de connexion: {database_url.split('@')[0]}@***...")
    
    try:
        # Connexion à Supabase
        conn = psycopg2.connect(database_url)
        cursor = conn.cursor()
        
        logger.info("✅ Connexion Supabase réussie!")
        
        # Vérifier les tables
        tables_to_check = [
            "trade_feedback",
            "predictions", 
            "symbol_calibration",
            "ai_decisions"
        ]
        
        for table in tables_to_check:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                logger.info(f"📊 {table}: {count} enregistrements")
                
                # Afficher les derniers enregistrements si disponibles
                if count > 0:
                    cursor.execute(f"SELECT * FROM {table} ORDER BY created_at DESC LIMIT 3")
                    recent_records = cursor.fetchall()
                    logger.info(f"   Derniers enregistrements dans {table}:")
                    for i, record in enumerate(recent_records[:3]):
                        logger.info(f"     {i+1}. {record}")
                else:
                    logger.info(f"   ⚠️ Aucune donnée dans {table}")
                    
            except Exception as e:
                logger.error(f"❌ Erreur vérification table {table}: {e}")
        
        # Vérifier les dernières décisions IA
        try:
            cursor.execute("""
                SELECT symbol, action, confidence, reason, created_at 
                FROM ai_decisions 
                ORDER BY created_at DESC 
                LIMIT 5
            """)
            recent_decisions = cursor.fetchall()
            
            if recent_decisions:
                logger.info("🎯 Dernières décisions IA:")
                for decision in recent_decisions:
                    logger.info(f"   • {decision[0]}: {decision[1]} ({decision[2]:.2f}) - {decision[3][:50]}...")
            else:
                logger.info("   ⚠️ Aucune décision IA enregistrée")
                
        except Exception as e:
            logger.error(f"❌ Erreur vérification décisions IA: {e}")
        
        conn.close()
        logger.info("✅ Vérification terminée")
        return True
        
    except Exception as e:
        logger.error(f"❌ Erreur connexion Supabase: {e}")
        return False

def main():
    logger.info("🚀 VÉRIFICATION DES DONNÉES SUPABASE")
    logger.info("=" * 60)
    
    if check_supabase_data():
        logger.info("\n🎉 Vérification réussie!")
        logger.info("📋 Les tables sont accessibles et les données peuvent être consultées")
    else:
        logger.error("\n❌ Échec de la vérification")

if __name__ == "__main__":
    main()
