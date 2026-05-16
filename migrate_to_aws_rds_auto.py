#!/usr/bin/env python3
"""
Migration complète de Supabase vers AWS RDS PostgreSQL
Version automatique qui lit le mot de passe depuis .env
"""

import os
import sys
import psycopg2
import logging
from dotenv import load_dotenv

# Charger .env
load_dotenv()

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration AWS RDS depuis .env
AWS_RDS_CONFIG = {
    'host': os.getenv('AWS_RDS_HOST'),
    'port': int(os.getenv('AWS_RDS_PORT', 5432)),
    'database': os.getenv('AWS_RDS_DATABASE'),
    'user': os.getenv('AWS_RDS_USER'),
    'password': os.getenv('AWS_RDS_PASSWORD'),
    'sslmode': os.getenv('AWS_RDS_SSLMODE', 'require')
}

# SQL pour créer toutes les tables (même que migrate_to_aws_rds.py)
CREATE_ALL_TABLES_SQL = """
-- Table trade_feedback
CREATE TABLE IF NOT EXISTS trade_feedback (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT DEFAULT 'M1',
    side TEXT,
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
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol ON trade_feedback(symbol);
CREATE INDEX IF NOT EXISTS idx_trade_feedback_created_at ON trade_feedback(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol_time ON trade_feedback(symbol, created_at DESC);

-- Table predictions
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    prediction TEXT NOT NULL,
    confidence DECIMAL(5,4),
    reason TEXT,
    spike_prediction BOOLEAN DEFAULT false,
    spike_zone_price DECIMAL(15,5),
    model_used TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_predictions_symbol ON predictions(symbol);
CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_predictions_symbol_tf ON predictions(symbol, timeframe, created_at DESC);

-- Table correction_predictions
CREATE TABLE IF NOT EXISTS correction_predictions (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    action TEXT NOT NULL,
    confidence DECIMAL(5,4),
    reason TEXT,
    model_used TEXT,
    timestamp TIMESTAMPTZ DEFAULT now(),
    technical_analysis JSONB,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_correction_predictions_symbol ON correction_predictions(symbol);
CREATE INDEX IF NOT EXISTS idx_correction_predictions_timestamp ON correction_predictions(timestamp DESC);

-- Table symbol_calibration
CREATE TABLE IF NOT EXISTS symbol_calibration (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT DEFAULT 'M1',
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    total INTEGER DEFAULT 0,
    win_rate DECIMAL(5,4),
    drift_factor DECIMAL(10,6) DEFAULT 1.0,
    last_updated TIMESTAMPTZ DEFAULT now(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_symbol_calibration_symbol ON symbol_calibration(symbol);
CREATE UNIQUE INDEX IF NOT EXISTS idx_symbol_calibration_unique ON symbol_calibration(symbol, timeframe);

-- Table model_metrics
CREATE TABLE IF NOT EXISTS model_metrics (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    model_type TEXT NOT NULL,
    accuracy DECIMAL(5,4),
    precision_metric DECIMAL(5,4),
    recall DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    training_date TIMESTAMPTZ DEFAULT now(),
    features_used JSONB,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_model_metrics_symbol ON model_metrics(symbol, timeframe);
CREATE INDEX IF NOT EXISTS idx_model_metrics_date ON model_metrics(training_date DESC);

-- Table trades (Core)
CREATE TABLE IF NOT EXISTS trades (
    id SERIAL PRIMARY KEY,
    ticket BIGINT UNIQUE,
    symbol TEXT NOT NULL,
    direction TEXT NOT NULL,
    open_time TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ,
    open_price DECIMAL(15,5),
    close_price DECIMAL(15,5),
    volume DECIMAL(10,2),
    profit DECIMAL(15,5),
    swap DECIMAL(15,5),
    commission DECIMAL(15,5),
    magic_number INTEGER,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);
CREATE INDEX IF NOT EXISTS idx_trades_open_time ON trades(open_time DESC);
CREATE INDEX IF NOT EXISTS idx_trades_ticket ON trades(ticket);

-- Table stair_detections
CREATE TABLE IF NOT EXISTS stair_detections (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    pattern_type TEXT,
    confidence DECIMAL(5,4),
    detected_at TIMESTAMPTZ DEFAULT now(),
    outcome TEXT,
    result_usd DECIMAL(15,5),
    closed_at TIMESTAMPTZ,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_stair_detections_symbol ON stair_detections(symbol);
CREATE INDEX IF NOT EXISTS idx_stair_detections_detected_at ON stair_detections(detected_at DESC);

-- Table adaptive_strategies
CREATE TABLE IF NOT EXISTS adaptive_strategies (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL UNIQUE,
    min_confidence DECIMAL(5,4) DEFAULT 0.75,
    min_setup_score DECIMAL(5,2) DEFAULT 80.0,
    min_gom_score DECIMAL(5,4) DEFAULT 0.45,
    trailing_stop_pct DECIMAL(5,2) DEFAULT 20.0,
    win_rate DECIMAL(5,4),
    total_trades INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT now(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_adaptive_strategies_symbol ON adaptive_strategies(symbol);

-- Table strategy_adjustments
CREATE TABLE IF NOT EXISTS strategy_adjustments (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    parameter TEXT NOT NULL,
    old_value DECIMAL(10,6) NOT NULL,
    new_value DECIMAL(10,6) NOT NULL,
    reason TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_strategy_adjustments_symbol ON strategy_adjustments(symbol);
CREATE INDEX IF NOT EXISTS idx_strategy_adjustments_timestamp ON strategy_adjustments(timestamp DESC);

-- VUE: recent_trades
CREATE OR REPLACE VIEW recent_trades AS
SELECT
    symbol,
    COUNT(*) as total_trades,
    SUM(CASE WHEN is_win THEN 1 ELSE 0 END) as wins,
    SUM(CASE WHEN NOT is_win THEN 1 ELSE 0 END) as losses,
    ROUND(AVG(CASE WHEN is_win THEN 1.0 ELSE 0.0 END) * 100, 2) as win_rate_pct,
    SUM(profit) as total_profit,
    AVG(profit) as avg_profit,
    MIN(created_at) as first_trade,
    MAX(created_at) as last_trade
FROM trade_feedback
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY symbol
ORDER BY total_trades DESC;

-- VUE: model_performance
CREATE OR REPLACE VIEW model_performance AS
SELECT
    symbol,
    timeframe,
    model_type,
    accuracy,
    f1_score,
    training_date,
    ROW_NUMBER() OVER (PARTITION BY symbol, timeframe ORDER BY training_date DESC) as rank
FROM model_metrics
ORDER BY symbol, timeframe, training_date DESC;

-- FUNCTION: update_symbol_calibration()
CREATE OR REPLACE FUNCTION update_symbol_calibration()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO symbol_calibration (symbol, timeframe, wins, losses, total, win_rate, last_updated)
    VALUES (
        NEW.symbol,
        COALESCE(NEW.timeframe, 'M1'),
        CASE WHEN NEW.is_win THEN 1 ELSE 0 END,
        CASE WHEN NEW.is_win THEN 0 ELSE 1 END,
        1,
        CASE WHEN NEW.is_win THEN 1.0 ELSE 0.0 END,
        NOW()
    )
    ON CONFLICT (symbol, timeframe) DO UPDATE SET
        wins = symbol_calibration.wins + CASE WHEN NEW.is_win THEN 1 ELSE 0 END,
        losses = symbol_calibration.losses + CASE WHEN NEW.is_win THEN 0 ELSE 1 END,
        total = symbol_calibration.total + 1,
        win_rate = (symbol_calibration.wins + CASE WHEN NEW.is_win THEN 1 ELSE 0 END)::DECIMAL /
                   (symbol_calibration.total + 1),
        last_updated = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger
DROP TRIGGER IF EXISTS trigger_update_calibration ON trade_feedback;
CREATE TRIGGER trigger_update_calibration
    AFTER INSERT ON trade_feedback
    FOR EACH ROW
    EXECUTE FUNCTION update_symbol_calibration();
"""

def test_connection(config):
    """Tester la connexion à AWS RDS"""
    try:
        logger.info(f"Test de connexion à {config['host']}...")
        conn = psycopg2.connect(
            host=config['host'],
            port=config['port'],
            database=config['database'],
            user=config['user'],
            password=config['password'],
            sslmode=config['sslmode']
        )

        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()[0]
        logger.info(f"[OK] Connexion réussie! PostgreSQL version: {version[:50]}...")

        cursor.close()
        conn.close()
        return True

    except Exception as e:
        logger.error(f"[ERREUR] Erreur de connexion: {e}")
        return False

def create_tables(config):
    """Créer toutes les tables dans AWS RDS"""
    try:
        logger.info("Création des tables...")
        conn = psycopg2.connect(
            host=config['host'],
            port=config['port'],
            database=config['database'],
            user=config['user'],
            password=config['password'],
            sslmode=config['sslmode']
        )

        cursor = conn.cursor()
        cursor.execute(CREATE_ALL_TABLES_SQL)
        conn.commit()

        logger.info("[OK] Toutes les tables créées avec succès!")

        # Vérifier les tables créées
        cursor.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_type = 'BASE TABLE'
            ORDER BY table_name;
        """)

        tables = cursor.fetchall()
        logger.info(f"\n[INFO] Tables créées ({len(tables)}):")
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table[0]}")
            count = cursor.fetchone()[0]
            logger.info(f"   - {table[0]}: {count} enregistrements")

        # Vérifier les vues
        cursor.execute("""
            SELECT table_name
            FROM information_schema.views
            WHERE table_schema = 'public'
            ORDER BY table_name;
        """)

        views = cursor.fetchall()
        if views:
            logger.info(f"\n[VUES] Vues créées ({len(views)}):")
            for view in views:
                logger.info(f"   - {view[0]}")

        cursor.close()
        conn.close()
        return True

    except Exception as e:
        logger.error(f"[ERREUR] Erreur lors de la création des tables: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Fonction principale de migration"""
    logger.info("="*60)
    logger.info("MIGRATION SUPABASE -> AWS RDS POSTGRESQL")
    logger.info("="*60)

    # Vérifier les variables d'environnement
    if not all(AWS_RDS_CONFIG.values()):
        logger.error("[ERREUR] Variables manquantes dans .env")
        logger.error("Vérifiez: AWS_RDS_HOST, AWS_RDS_DATABASE, AWS_RDS_USER, AWS_RDS_PASSWORD")
        sys.exit(1)

    logger.info(f"\nConfiguration:")
    logger.info(f"   Host: {AWS_RDS_CONFIG['host']}")
    logger.info(f"   Database: {AWS_RDS_CONFIG['database']}")
    logger.info(f"   User: {AWS_RDS_CONFIG['user']}")

    # Test de connexion
    logger.info("\n[ÉTAPE 1] Test de connexion...")
    if not test_connection(AWS_RDS_CONFIG):
        logger.error("[ERREUR] Impossible de se connecter. Vérifiez vos identifiants.")
        sys.exit(1)

    # Créer les tables
    logger.info("\n[ÉTAPE 2] Création des tables et structures...")
    if not create_tables(AWS_RDS_CONFIG):
        logger.error("[ERREUR] Échec de la création des tables.")
        sys.exit(1)

    logger.info("\n" + "="*60)
    logger.info("[OK] MIGRATION TERMINÉE AVEC SUCCÈS!")
    logger.info("="*60)
    logger.info("\nProchaines étapes:")
    logger.info("1. Tester avec: python test_aws_rds_connection.py")
    logger.info("2. Intégrer dans ai_server.py")
    logger.info("3. Migrer les données existantes si nécessaire")

if __name__ == "__main__":
    main()
