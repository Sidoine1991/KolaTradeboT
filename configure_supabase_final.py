#!/usr/bin/env python3
"""
Script final de configuration Supabase pour KolaTradeBoT
Utilise les variables déjà configurées dans .env.supabase
"""

import os
import psycopg2
import logging
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def load_supabase_config():
    """Charger la configuration depuis .env.supabase"""
    config = {}
    try:
        with open(".env.supabase", "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    config[key.strip()] = value.strip()
        logger.info("✅ Configuration .env.supabase chargée")
        return config
    except Exception as e:
        logger.error(f"❌ Erreur lecture .env.supabase: {e}")
        return None

def test_supabase_connection(config):
    """Tester la connexion Supabase avec la configuration"""
    if not config:
        return None
    
    database_url = config.get("DATABASE_URL")
    if not database_url:
        logger.error("❌ DATABASE_URL non trouvé dans .env.supabase")
        return None
    
    logger.info(f"🔍 Test de connexion avec: {database_url[:50]}...")
    
    try:
        conn = psycopg2.connect(database_url)
        logger.info("✅ Connexion Supabase réussie!")
        
        # Test simple query
        cursor = conn.cursor()
        cursor.execute("SELECT version()")
        version = cursor.fetchone()[0]
        logger.info(f"📊 PostgreSQL: {version[:50]}...")
        
        return conn
        
    except Exception as e:
        logger.error(f"❌ Erreur connexion Supabase: {e}")
        return None

def create_supabase_tables(conn):
    """Créer les tables nécessaires dans Supabase"""
    logger.info("🔧 Création des tables Supabase...")
    
    tables_sql = {
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
    
    cursor = conn.cursor()
    created_tables = []
    
    for table_name, sql in tables_sql.items():
        try:
            cursor.execute(sql)
            created_tables.append(table_name)
            logger.info(f"✅ Table {table_name} créée avec succès")
        except Exception as e:
            logger.error(f"❌ Erreur création table {table_name}: {e}")
    
    conn.commit()
    logger.info(f"🎉 Tables créées: {', '.join(created_tables)}")
    return created_tables

def verify_tables(conn, table_names):
    """Vérifier les tables créées"""
    logger.info("🔍 Vérification des tables...")
    
    cursor = conn.cursor()
    for table_name in table_names:
        try:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            logger.info(f"📊 {table_name}: {count} enregistrements")
        except Exception as e:
            logger.error(f"❌ Erreur vérification {table_name}: {e}")

def create_final_env_file(config):
    """Créer le fichier .env final pour le serveur"""
    logger.info("📝 Création du fichier .env final...")
    
    env_content = f"""# Configuration finale pour KolaTradeBoT avec Supabase
# Généré le {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

# URL de la base de données Supabase
DATABASE_URL={config.get('DATABASE_URL', '')}

# Configuration Supabase
SUPABASE_URL={config.get('SUPABASE_URL', '')}
SUPABASE_KEY={config.get('SUPABASE_KEY', '')}
SUPABASE_PROJECT_ID={config.get('SUPABASE_PROJECT_ID', '')}
SUPABASE_PROJECT_NAME={config.get('SUPABASE_PROJECT_NAME', '')}

# Clé API anon
SUPABASE_ANON_KEY={config.get('SUPABASE_ANON_KEY', '')}

# Mode Supabase activé
SUPABASE_MODE=enabled

# Configuration SSL
SUPABASE_SSL_MODE=require
"""
    
    with open(".env.final", "w", encoding="utf-8") as f:
        f.write(env_content)
    
    logger.info("✅ Fichier .env.final créé!")
    return ".env.final"

def main():
    """Fonction principale"""
    logger.info("🚀 CONFIGURATION FINALE SUPABASE POUR KOLATRADEBOT")
    logger.info("=" * 60)
    
    # Étape 1: Charger la configuration
    config = load_supabase_config()
    if not config:
        logger.error("❌ Impossible de charger la configuration")
        return
    
    # Étape 2: Tester la connexion
    conn = test_supabase_connection(config)
    if not conn:
        logger.error("❌ Impossible de se connecter à Supabase")
        return
    
    try:
        # Étape 3: Créer les tables
        created_tables = create_supabase_tables(conn)
        
        # Étape 4: Vérifier les tables
        verify_tables(conn, created_tables)
        
        # Étape 5: Créer le fichier .env final
        env_file = create_final_env_file(config)
        
        # Résumé final
        logger.info("🎉 CONFIGURATION SUPABASE TERMINÉE!")
        logger.info("📋 Résumé:")
        logger.info(f"   • Tables créées: {len(created_tables)}")
        logger.info(f"   • Fichier config: {env_file}")
        logger.info(f"   • Connexion: ✅")
        
        logger.info("📝 Prochaines étapes:")
        logger.info("1. Copier .env.final vers .env:")
        logger.info("   cp .env.final .env")
        logger.info("")
        logger.info("2. Mettre à jour ai_server.py pour Supabase:")
        logger.info("   python update_ai_server_supabase.py")
        logger.info("")
        logger.info("3. Démarrer le serveur avec Supabase:")
        logger.info("   python ai_server.py")
        logger.info("")
        logger.info("4. Vérifier le démarrage:")
        logger.info("   curl http://localhost:8000/health")
        
    except Exception as e:
        logger.error(f"❌ Erreur durant la configuration: {e}")
    finally:
        if conn:
            conn.close()
            logger.info("🔒 Connexion Supabase fermée")

if __name__ == "__main__":
    main()
