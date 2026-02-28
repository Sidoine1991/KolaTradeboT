-- Tables supplémentaires pour l'entraînement continu ML
-- Exécuter dans l'éditeur SQL Supabase

-- 1. training_runs : historique des cycles d'entraînement
CREATE TABLE IF NOT EXISTS training_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol text NOT NULL,
    timeframe text NOT NULL DEFAULT 'M1',
    started_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    status text NOT NULL DEFAULT 'running', -- running, completed, failed
    samples_used int NOT NULL DEFAULT 0,
    accuracy real,
    f1_score real,
    duration_sec int,
    error_message text,
    metadata jsonb
);

CREATE INDEX IF NOT EXISTS idx_training_runs_symbol_timeframe ON training_runs(symbol, timeframe);
CREATE INDEX IF NOT EXISTS idx_training_runs_started_at ON training_runs(started_at DESC);

-- 2. feature_importance : importance des features par modèle/symbole
CREATE TABLE IF NOT EXISTS feature_importance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol text NOT NULL,
    timeframe text NOT NULL DEFAULT 'M1',
    model_type text NOT NULL DEFAULT 'random_forest',
    training_run_id uuid REFERENCES training_runs(id) ON DELETE SET NULL,
    feature_name text NOT NULL,
    importance real NOT NULL,
    rank int,
    recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feature_importance_symbol ON feature_importance(symbol, timeframe);

-- 3. model_performance_log : évolution des performances (déjà peut-être existant, vérifier)
CREATE TABLE IF NOT EXISTS model_performance_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol text NOT NULL,
    timeframe text NOT NULL DEFAULT 'M1',
    model_type text NOT NULL,
    accuracy real NOT NULL,
    f1_score real,
    precision_val real,
    recall_val real,
    samples_count int,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb
);

CREATE INDEX IF NOT EXISTS idx_model_performance_symbol ON model_performance_log(symbol, timeframe);
CREATE INDEX IF NOT EXISTS idx_model_performance_recorded ON model_performance_log(recorded_at DESC);

-- 4. RLS : permettre l'accès avec la clé service
ALTER TABLE training_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_importance ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_performance_log ENABLE ROW LEVEL SECURITY;

-- Policies (exécuter une par une si erreur "already exists")
CREATE POLICY "training_runs_service" ON training_runs FOR ALL USING (true);
CREATE POLICY "feature_importance_service" ON feature_importance FOR ALL USING (true);
CREATE POLICY "model_performance_log_service" ON model_performance_log FOR ALL USING (true);
