#!/usr/bin/env python3
"""
Migration complète de Supabase vers AWS RDS PostgreSQL
Crée toutes les tables nécessaires pour TradBOT
"""

import psycopg2
import logging
import sys
from urllib.parse import quote_plus

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration AWS RDS
AWS_RDS_CONFIG = {
    'host': 'trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com',
    'port': 5432,
    'database': 'trading_bot',
    'user': 'dbadmin',
    'password': None,  # Sera demandé de manière sécurisée
    'sslmode': 'require'
}

# SQL pour créer toutes les tables
CREATE_ALL_TABLES_SQL = """
-- =====================================================
-- TABLE 1: trade_feedback
-- Stocke les retours sur les trades exécutés
-- =====================================================
CREATE TABLE IF NOT EXISTS trade_feedback (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT DEFAULT 'M1',
    side TEXT,  -- 'buy' ou 'sell'
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

-- =====================================================
-- TABLE 2: predictions
-- Stocke toutes les prédictions IA
-- =====================================================
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    prediction TEXT NOT NULL,  -- 'buy', 'sell', 'hold'
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

-- =====================================================
-- TABLE 3: correction_predictions
-- Prédictions avec système de correction
-- =====================================================
CREATE TABLE IF NOT EXISTS correction_predictions (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    action TEXT NOT NULL,  -- 'BUY', 'SELL', 'HOLD'
    confidence DECIMAL(5,4),
    reason TEXT,
    model_used TEXT,
    timestamp TIMESTAMPTZ DEFAULT now(),
    technical_analysis JSONB,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_correction_predictions_symbol ON correction_predictions(symbol);
CREATE INDEX IF NOT EXISTS idx_correction_predictions_timestamp ON correction_predictions(timestamp DESC);

-- =====================================================
-- TABLE 4: symbol_calibration
-- Calibration par symbole (win rate, drift factor)
-- =====================================================
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

-- =====================================================
-- TABLE 5: model_metrics
-- Métriques de performance des modèles ML
-- =====================================================
CREATE TABLE IF NOT EXISTS model_metrics (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    model_type TEXT NOT NULL,  -- 'random_forest', 'xgboost', etc.
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

-- =====================================================
-- TABLE 6: trades (Core)
-- Historique complet des trades
-- =====================================================
CREATE TABLE IF NOT EXISTS trades (
    id SERIAL PRIMARY KEY,
    ticket BIGINT UNIQUE,
    symbol TEXT NOT NULL,
    direction TEXT NOT NULL,  -- 'BUY', 'SELL'
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

-- =====================================================
-- TABLE 7: stair_detections
-- Détections de patterns stair (Boom/Crash)
-- =====================================================
CREATE TABLE IF NOT EXISTS stair_detections (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    pattern_type TEXT,  -- 'stair_up', 'stair_down'
    confidence DECIMAL(5,4),
    detected_at TIMESTAMPTZ DEFAULT now(),
    outcome TEXT,  -- 'win', 'loss', 'breakeven', 'pending'
    result_usd DECIMAL(15,5),
    closed_at TIMESTAMPTZ,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_stair_detections_symbol ON stair_detections(symbol);
CREATE INDEX IF NOT EXISTS idx_stair_detections_detected_at ON stair_detections(detected_at DESC);

-- =====================================================
-- TABLE 8: adaptive_strategies (Migration depuis SQLite)
-- Stratégies adaptatives par symbole
-- =====================================================
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

-- =====================================================
-- TABLE 9: strategy_adjustments (Migration depuis SQLite)
-- Historique des ajustements de stratégie
-- =====================================================
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

-- =====================================================
-- VUE: recent_trades
-- Vue pour accès rapide aux trades récents
-- =====================================================
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

-- =====================================================
-- VUE: model_performance
-- Performance des modèles ML par symbole
-- =====================================================
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

-- =====================================================
-- FUNCTION: update_symbol_calibration()
-- Fonction trigger pour mettre à jour la calibration
-- =====================================================
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

-- =====================================================
-- FIN DE LA CRÉATION DES TABLES
-- =====================================================
"""

def get_password():
    """Demander le mot de passe de manière sécurisée"""
    import getpass
    return getpass.getpass("Mot de passe AWS RDS (dbadmin): ")

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
        logger.info(f"✅ Connexion réussie! PostgreSQL version: {version[:50]}...")

        cursor.close()
        conn.close()
        return True

    except Exception as e:
        logger.error(f"❌ Erreur de connexion: {e}")
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

        logger.info("✅ Toutes les tables créées avec succès!")

        # Vérifier les tables créées
        cursor.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_type = 'BASE TABLE'
            ORDER BY table_name;
        """)

        tables = cursor.fetchall()
        logger.info(f"\n📊 Tables créées ({len(tables)}):")
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
            logger.info(f"\n👁️  Vues créées ({len(views)}):")
            for view in views:
                logger.info(f"   - {view[0]}")

        cursor.close()
        conn.close()
        return True

    except Exception as e:
        logger.error(f"❌ Erreur lors de la création des tables: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Fonction principale de migration"""
    logger.info("="*60)
    logger.info("MIGRATION SUPABASE → AWS RDS POSTGRESQL")
    logger.info("="*60)

    # Demander le mot de passe
    AWS_RDS_CONFIG['password'] = get_password()

    # Test de connexion
    logger.info("\n[ÉTAPE 1] Test de connexion...")
    if not test_connection(AWS_RDS_CONFIG):
        logger.error("❌ Impossible de se connecter. Vérifiez vos identifiants.")
        sys.exit(1)

    # Créer les tables
    logger.info("\n[ÉTAPE 2] Création des tables et structures...")
    if not create_tables(AWS_RDS_CONFIG):
        logger.error("❌ Échec de la création des tables.")
        sys.exit(1)

    logger.info("\n" + "="*60)
    logger.info("✅ MIGRATION TERMINÉE AVEC SUCCÈS!")
    logger.info("="*60)
    logger.info("\nProchaines étapes:")
    logger.info("1. Mettre à jour les variables d'environnement (.env)")
    logger.info("2. Configurer ai_server.py pour utiliser AWS RDS")
    logger.info("3. Tester avec test_aws_rds_connection.py")
    logger.info("4. Migrer les données existantes si nécessaire")

if __name__ == "__main__":
    main()
