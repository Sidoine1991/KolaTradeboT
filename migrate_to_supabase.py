#!/usr/bin/env python3
"""
Script de migration de la base de données de Render vers Supabase
Pour KolaTradeBoT - Migration des données de trading et feedback
"""

import os
import asyncio
import psycopg2  # Utiliser psycopg2 au lieu d'asyncpg
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional
import json

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Render (source)
RENDER_DATABASE_URL = "postgresql://koladb_user:wYkUIyTb53vWEygkyia3YZiJNIdonmOt@dpg-d5nje68gjchc739d0dug-a.oregon-postgres.render.com/koladb_rurl"

# Configuration Supabase (destination)
SUPABASE_URL = "https://bpzqnooiisgadzicwupi.supabase.co"
SUPABASE_PASSWORD = "Socrate2025@1991"  # Mot de passe directement configuré
# URL de connexion Supabase - format standard sans le préfixe de projet
from urllib.parse import quote_plus
encoded_password = quote_plus(SUPABASE_PASSWORD)
SUPABASE_DB_URL = f"postgresql://postgres:{encoded_password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres"
SUPABASE_KEY = "sb_publishable_2VWOLl6v_UU2zBp1i58lLw_CBue22fc"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"

# Alternative: utiliser l'URL complète avec le mot de passe
def get_supabase_db_url():
    """Construit l'URL de connexion Supabase"""
    # Pour Supabase, il faut utiliser l'URL avec le mot de passe
    # Format: postgresql://postgres:[PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
    password = os.getenv("SUPABASE_PASSWORD", "")
    if not password:
        logger.error("❌ SUPABASE_PASSWORD non défini dans les variables d'environnement")
        return None
    
    return f"postgresql://postgres:{password}@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"

# Structure des tables à migrer
TABLES_TO_MIGRATE = {
    "trade_feedback": {
        "create_sql": """
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
        """,
        "columns": ["id", "symbol", "open_time", "close_time", "entry_price", "exit_price", 
                  "profit", "ai_confidence", "coherent_confidence", "decision", "is_win", 
                  "created_at", "timeframe", "side"]
    },
    "predictions": {
        "create_sql": """
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
        """,
        "columns": ["id", "symbol", "timeframe", "prediction", "confidence", "reason", 
                  "created_at", "model_used", "metadata"]
    },
    "symbol_calibration": {
        "create_sql": """
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
        """,
        "columns": ["id", "symbol", "timeframe", "wins", "total", "drift_factor", 
                  "last_updated", "metadata"]
    }
}

async def connect_to_render():
    """Connexion à la base de données Render"""
    try:
        # Utiliser psycopg2 pour Render aussi
        conn = psycopg2.connect(RENDER_DATABASE_URL)
        logger.info("✅ Connecté à la base de données Render")
        return conn
    except Exception as e:
        logger.error(f"❌ Erreur connexion Render: {e}")
        return None

async def connect_to_supabase():
    """Connexion à la base de données Supabase"""
    try:
        # Utiliser psycopg2 qui fonctionne
        conn = psycopg2.connect(SUPABASE_DB_URL)
        logger.info("✅ Connecté à la base de données Supabase")
        return conn
    except Exception as e:
        logger.error(f"❌ Erreur connexion Supabase: {e}")
        return None

async def create_tables_supabase(supabase_conn):
    """Créer les tables dans Supabase si elles n'existent pas"""
    logger.info("🔧 Création des tables dans Supabase...")
    
    for table_name, table_info in TABLES_TO_MIGRATE.items():
        try:
            cursor = supabase_conn.cursor()
            cursor.execute(table_info["create_sql"])
            supabase_conn.commit()
            logger.info(f"✅ Table {table_name} créée/vérifiée dans Supabase")
        except Exception as e:
            logger.error(f"❌ Erreur création table {table_name}: {e}")

async def migrate_table_data(render_conn, supabase_conn, table_name: str):
    """Migrer les données d'une table spécifique"""
    logger.info(f"📊 Migration de la table {table_name}...")
    
    if not render_conn:
        logger.info(f"ℹ️ Migration {table_name} ignorée (Render non connecté)")
        return
    
    try:
        # Récupérer les données depuis Render
        columns = TABLES_TO_MIGRATE[table_name]["columns"]
        columns_str = ", ".join(columns)
        
        cursor = render_conn.cursor()
        query = f"SELECT {columns_str} FROM {table_name} ORDER BY id"
        cursor.execute(query)
        data = cursor.fetchall()
        
        if not data:
            logger.info(f"ℹ️ Aucune donnée à migrer pour {table_name}")
            return
        
        logger.info(f"📋 {len(data)} enregistrements à migrer pour {table_name}")
        
        # Insérer dans Supabase
        migrated_count = 0
        supabase_cursor = supabase_conn.cursor()
        
        for row in data:
            try:
                # Préparer la requête d'insertion
                placeholders = ", ".join(["%s" for _ in range(len(columns))])
                insert_query = f"""
                INSERT INTO {table_name} ({columns_str}) 
                VALUES ({placeholders})
                """
                
                supabase_cursor.execute(insert_query, row)
                migrated_count += 1
                
                if migrated_count % 100 == 0:
                    logger.info(f"📈 {migrated_count}/{len(data)} enregistrements migrés...")
                    
            except Exception as e:
                logger.error(f"❌ Erreur migration enregistrement: {e}")
                continue
        
        # Commit les changements
        supabase_conn.commit()
        logger.info(f"✅ Table {table_name}: {migrated_count}/{len(data)} enregistrements migrés avec succès")
        
    except Exception as e:
        logger.error(f"❌ Erreur migration table {table_name}: {e}")

async def verify_migration(supabase_conn):
    """Vérifier que les données ont été correctement migrées"""
    logger.info("🔍 Vérification de la migration...")
    
    for table_name in TABLES_TO_MIGRATE.keys():
        try:
            cursor = supabase_conn.cursor()
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            logger.info(f"📊 {table_name}: {count} enregistrements dans Supabase")
        except Exception as e:
            logger.error(f"❌ Erreur vérification {table_name}: {e}")

async def main():
    """Fonction principale de migration"""
    logger.info("🚀 Démarrage de la migration Render → Supabase")
    logger.info(f"📅 Date de migration: {datetime.now().isoformat()}")
    
    # Connexions
    render_conn = await connect_to_render()
    supabase_conn = await connect_to_supabase()
    
    if not supabase_conn:
        logger.error("❌ Impossible d'établir la connexion Supabase")
        return
    
    try:
        # Étape 1: Créer les tables dans Supabase
        await create_tables_supabase(supabase_conn)
        
        # Étape 2: Migrer les données de chaque table (si Render disponible)
        if render_conn:
            for table_name in TABLES_TO_MIGRATE.keys():
                await migrate_table_data(render_conn, supabase_conn, table_name)
        else:
            logger.info("ℹ️ Migration des données ignorée (Render non configuré)")
            logger.info("📊 Tables créées dans Supabase avec structure vide")
        
        # Étape 3: Vérification
        await verify_migration(supabase_conn)
        
        logger.info("🎉 Migration terminée avec succès!")
        logger.info("📝 Prochaines étapes:")
        logger.info("   1. Mettre à jour DATABASE_URL dans .env avec l'URL Supabase")
        logger.info("   2. Redémarrer le serveur ai_server.py")
        logger.info("   3. Vérifier que tout fonctionne correctement")
        
    except Exception as e:
        logger.error(f"❌ Erreur durant la migration: {e}")
    finally:
        # Fermer les connexions
        if render_conn:
            render_conn.close()
        supabase_conn.close()
        logger.info("🔒 Connexions fermées")

if __name__ == "__main__":
    # Instructions pour l'utilisateur
    print("🔧 SCRIPT DE MIGRATION RENDER → SUPABASE")
    print("=" * 50)
    print("📋 Prérequis:")
    print("   1. Variable RENDER_DATABASE_URL définie")
    print("   2. Variable SUPABASE_PASSWORD définie")
    print("   3. Les deux bases de données accessibles")
    print()
    print("💡 Pour définir les variables:")
    print("   export RENDER_DATABASE_URL='votre_url_render'")
    print("   export SUPABASE_PASSWORD='votre_mot_de_passe_supabase'")
    print()
    print("🚀 Lancement de la migration...")
    print("=" * 50)
    
    # Lancer la migration
    asyncio.run(main())
