-- Créer la table des métriques de modèles
CREATE TABLE IF NOT EXISTS model_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol VARCHAR(50) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    model_type VARCHAR(50) NOT NULL DEFAULT 'random_forest',
    accuracy DECIMAL(10,6) NOT NULL,
    f1_score DECIMAL(10,6) NOT NULL,
    training_samples INTEGER NOT NULL,
    training_date TIMESTAMP WITH TIME ZONE NOT NULL,
    feature_importance JSONB,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_model_metrics_symbol_timeframe ON model_metrics(symbol, timeframe);
CREATE INDEX IF NOT EXISTS idx_model_metrics_training_date ON model_metrics(training_date DESC);

-- Table pour le suivi des performances en temps réel
CREATE TABLE IF NOT EXISTS model_performance_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_key VARCHAR(100) NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    prediction_count INTEGER DEFAULT 0,
    correct_predictions INTEGER DEFAULT 0,
    accuracy REAL DEFAULT 0.0,
    profit_loss DECIMAL(15,6) DEFAULT 0.0,
    log_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour les logs de performance
CREATE INDEX IF NOT EXISTS idx_model_performance_log_model_key ON model_performance_log(model_key);
CREATE INDEX IF NOT EXISTS idx_model_performance_log_date ON model_performance_log(log_date DESC);
