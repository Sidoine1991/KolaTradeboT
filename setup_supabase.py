#!/usr/bin/env python3
"""
Script simplifié pour créer les tables Supabase et tester la connexion
"""

import psycopg2
import logging
from urllib.parse import quote_plus

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase
SUPABASE_PASSWORD = "Socrate2025@1991"
encoded_password = quote_plus(SUPABASE_PASSWORD)

# Différents formats d'URL à tester
supabase_urls = [
    f"postgresql://postgres:{encoded_password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require",
    f"postgresql://postgres:{encoded_password}@aws-0-eu-central-1.pooler.supabase.com/postgres?sslmode=require",
    f"postgresql://postgres.bpzqnooiisgadzicwupi:{encoded_password}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require",
]

# SQL pour créer les tables
CREATE_TABLES_SQL = """
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
"""

def test_supabase_connection():
    """Tester différentes connexions Supabase"""
    for i, url in enumerate(supabase_urls, 1):
        logger.info(f"🔍 Test connexion {i}: {url[:80]}...")
        try:
            conn = psycopg2.connect(url)
            logger.info(f"✅ Connexion réussie avec format {i}!")
            
            # Test création des tables
            cursor = conn.cursor()
            cursor.execute(CREATE_TABLES_SQL)
            conn.commit()
            logger.info("✅ Tables créées avec succès!")
            
            # Vérification
            cursor.execute("SELECT COUNT(*) FROM trade_feedback")
            count = cursor.fetchone()[0]
            logger.info(f"📊 Table trade_feedback: {count} enregistrements")
            
            cursor.close()
            conn.close()
            return url
            
        except Exception as e:
            logger.error(f"❌ Échec connexion {i}: {e}")
    
    return None

def main():
    """Fonction principale"""
    logger.info("🚀 TEST DE CONNEXION ET CRÉATION TABLES SUPABASE")
    logger.info("=" * 60)
    
    # Tester la connexion
    working_url = test_supabase_connection()
    
    if working_url:
        logger.info("🎉 Succès! Base de données Supabase prête")
        logger.info(f"📝 URL de connexion fonctionnelle: {working_url[:80]}...")
        logger.info("📋 Prochaines étapes:")
        logger.info("1. Mettre à jour .env avec cette URL")
        logger.info("2. Lancer la migration complète")
        logger.info("3. Démarrer le serveur avec Supabase")
    else:
        logger.error("❌ Toutes les connexions ont échoué")
        logger.info("💡 Vérifiez:")
        logger.info("1. Le mot de passe dans le dashboard Supabase")
        logger.info("2. L'ID du projet")
        logger.info("3. La connexion internet")

if __name__ == "__main__":
    main()
