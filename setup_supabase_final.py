#!/usr/bin/env python3
"""
Script final pour configurer Supabase pour KolaTradeBoT
Création des tables et configuration du serveur
"""

import os
import psycopg2
import logging
from datetime import datetime
from urllib.parse import quote_plus

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase
SUPABASE_PASSWORD = "Socrate2025@1991"
encoded_password = quote_plus(SUPABASE_PASSWORD)

# URL Supabase la plus simple qui fonctionne
SUPABASE_URL = "postgresql://postgres:postgres@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require"

# Tables à créer dans Supabase
TABLES_SQL = {
    "trade_feedback": """
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
    
    "predictions": """
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
    
    "symbol_calibration": """
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
    
    "ai_decisions": """
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
}

def connect_to_supabase():
    """Connexion à Supabase"""
    try:
        conn = psycopg2.connect(SUPABASE_URL)
        logger.info("✅ Connecté à Supabase avec succès!")
        return conn
    except Exception as e:
        logger.error(f"❌ Erreur connexion Supabase: {e}")
        return None

def create_tables(conn):
    """Créer toutes les tables"""
    logger.info("🔧 Création des tables dans Supabase...")
    
    cursor = conn.cursor()
    created_tables = []
    
    for table_name, sql in TABLES_SQL.items():
        try:
            cursor.execute(sql)
            created_tables.append(table_name)
            logger.info(f"✅ Table {table_name} créée avec succès")
        except Exception as e:
            logger.error(f"❌ Erreur création table {table_name}: {e}")
    
    conn.commit()
    logger.info(f"🎉 Tables créées: {', '.join(created_tables)}")
    return created_tables

def verify_tables(conn):
    """Vérifier les tables créées"""
    logger.info("🔍 Vérification des tables...")
    
    cursor = conn.cursor()
    for table_name in TABLES_SQL.keys():
        try:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            logger.info(f"📊 {table_name}: {count} enregistrements")
        except Exception as e:
            logger.error(f"❌ Erreur vérification {table_name}: {e}")

def create_env_file():
    """Créer le fichier .env pour Supabase"""
    logger.info("📝 Création du fichier .env pour Supabase...")
    
    env_content = f"""# Configuration Supabase pour KolaTradeBoT
# Généré le {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

# URL de la base de données
DATABASE_URL={SUPABASE_URL}

# Configuration Supabase
SUPABASE_URL=https://bpzqnooiisgadzicwupi.supabase.co
SUPABASE_KEY=sb_publishable_2VWOLl6v_UU2zBp1i58lLw_CBue22fc
SUPABASE_PROJECT_ID=bpzqnooiisgadzicwupi
SUPABASE_PROJECT_NAME=KolaTradeBoT

# Clé API anon
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4

# Mode Supabase activé
SUPABASE_MODE=enabled
"""
    
    with open(".env.supabase.final", "w", encoding='utf-8') as f:
        f.write(env_content)
    
    logger.info("✅ Fichier .env.supabase.final créé!")
    return ".env.supabase.final"

def update_ai_server():
    """Mettre à jour ai_server.py pour Supabase"""
    logger.info("📝 Mise à jour de ai_server.py...")
    
    try:
        with open("ai_server.py", "r", encoding='utf-8') as f:
            content = f.read()
        
        # Remplacements pour Supabase
        replacements = [
            ("RUNNING_ON_RENDER = bool(os.getenv(\"RENDER\") or os.getenv(\"RENDER_SERVICE_ID\"))",
             "RUNNING_ON_SUPABASE = bool(os.getenv(\"SUPABASE_URL\") or os.getenv(\"SUPABASE_PROJECT_ID\"))"),
            ("RUNNING_ON_RENDER", "RUNNING_ON_SUPABASE"),
            ("Mode Render activé", "Mode Supabase activé"),
            ("pour Render PostgreSQL", "pour Supabase PostgreSQL"),
            ("render.com", "supabase.co"),
            ("📝 Ajout de sslmode=require pour Render PostgreSQL",
             "📝 Ajout de sslmode=require pour Supabase PostgreSQL"),
        ]
        
        updated_content = content
        for old, new in replacements:
            updated_content = updated_content.replace(old, new)
        
        # Sauvegarder la version mise à jour
        with open("ai_server_supabase.py", "w", encoding='utf-8') as f:
            f.write(updated_content)
        
        logger.info("✅ ai_server_supabase.py créé!")
        return True
        
    except Exception as e:
        logger.error(f"❌ Erreur mise à jour ai_server.py: {e}")
        return False

def main():
    """Fonction principale"""
    logger.info("🚀 CONFIGURATION SUPABASE POUR KOLATRADEBOT")
    logger.info("=" * 60)
    
    # Étape 1: Connexion à Supabase
    conn = connect_to_supabase()
    if not conn:
        logger.error("❌ Impossible de se connecter à Supabase")
        return
    
    try:
        # Étape 2: Création des tables
        created_tables = create_tables(conn)
        
        # Étape 3: Vérification
        verify_tables(conn)
        
        # Étape 4: Création fichier .env
        env_file = create_env_file()
        
        # Étape 5: Mise à jour du serveur
        server_updated = update_ai_server()
        
        # Résumé
        logger.info("🎉 CONFIGURATION SUPABASE TERMINÉE!")
        logger.info("📋 Résumé:")
        logger.info(f"   • Tables créées: {len(created_tables)}")
        logger.info(f"   • Fichier config: {env_file}")
        logger.info(f"   • Serveur mis à jour: {server_updated}")
        
        logger.info("📝 Prochaines étapes:")
        logger.info("1. Copier .env.supabase.final vers .env:")
        logger.info("   cp .env.supabase.final .env")
        logger.info("")
        logger.info("2. Utiliser le serveur mis à jour:")
        logger.info("   python ai_server_supabase.py")
        logger.info("")
        logger.info("3. Vérifier le démarrage:")
        logger.info("   curl http://localhost:8000/health")
        
    except Exception as e:
        logger.error(f"❌ Erreur durant la configuration: {e}")
    finally:
        if conn:
            conn.close()
            logger.info("🔒 Connexion Supabase fermée")

if __name__ == "__main__":
    main()
