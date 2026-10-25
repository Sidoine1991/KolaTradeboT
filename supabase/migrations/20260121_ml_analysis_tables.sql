-- Tables ML et analyse de symboles - Migration 2026-01-21
-- Tables pour calibration, patterns de correction et importance des features

-- Table pour l'importance des features (version corrigée)
CREATE TABLE IF NOT EXISTS feature_importance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  symbol text NOT NULL,
  timeframe text NOT NULL DEFAULT 'M1'::text,
  model_type text NOT NULL DEFAULT 'random_forest'::text,
  training_run_id uuid NULL,
  feature_name text NOT NULL,
  importance real NOT NULL,
  rank integer NULL,
  recorded_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT feature_importance_pkey PRIMARY KEY (id),
  CONSTRAINT feature_importance_training_run_id_fkey FOREIGN KEY (training_run_id) REFERENCES training_runs (id) ON DELETE SET NULL
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_feature_importance_symbol ON feature_importance USING btree (symbol, timeframe) TABLESPACE pg_default;

-- Table pour la calibration des symboles
CREATE TABLE IF NOT EXISTS symbol_calibration (
  id serial NOT NULL,
  symbol text NOT NULL,
  timeframe text NULL DEFAULT 'M1'::text,
  wins integer NULL DEFAULT 0,
  total integer NULL DEFAULT 0,
  drift_factor numeric(10, 6) NULL DEFAULT 1.0,
  last_updated timestamp with time zone NULL DEFAULT now(),
  metadata jsonb NULL,
  CONSTRAINT symbol_calibration_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Table pour les patterns de correction
CREATE TABLE IF NOT EXISTS symbol_correction_patterns (
  id bigserial NOT NULL,
  symbol character varying(50) NOT NULL,
  pattern_type character varying(30) NOT NULL,
  avg_retracement_percentage numeric(10, 4) NULL,
  typical_duration_bars integer NULL,
  success_rate numeric(5, 2) NULL,
  min_trend_strength numeric(5, 2) NULL,
  max_volatility_level numeric(10, 4) NULL,
  best_timeframes character varying(100) NULL,
  occurrences_count integer NULL,
  last_updated timestamp with time zone NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT symbol_correction_patterns_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_symbol_pattern ON symbol_correction_patterns USING btree (symbol, pattern_type) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_pattern_success ON symbol_correction_patterns USING btree (success_rate) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_pattern_occurrences ON symbol_correction_patterns USING btree (occurrences_count) TABLESPACE pg_default;

-- Table pour les résumés de corrections (ajoutée)
CREATE TABLE IF NOT EXISTS correction_summary_stats (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  symbol text NOT NULL,
  timeframe text NOT NULL DEFAULT 'M1'::text,
  period_start timestamptz NOT NULL,
  period_end timestamptz NOT NULL,
  total_corrections integer NULL DEFAULT 0,
  successful_predictions integer NULL DEFAULT 0,
  avg_retracement_pct numeric(10, 4) NULL,
  avg_duration_bars numeric(10, 2) NULL,
  success_rate numeric(5, 4) NULL,
  dominant_pattern text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NULL,
  CONSTRAINT correction_summary_stats_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_correction_summary_symbol ON correction_summary_stats USING btree (symbol, timeframe) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_correction_summary_period ON correction_summary_stats USING btree (period_start, period_end) TABLESPACE pg_default;

-- Activer RLS sur les nouvelles tables
ALTER TABLE symbol_calibration ENABLE ROW LEVEL SECURITY;
ALTER TABLE symbol_correction_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE correction_summary_stats ENABLE ROW LEVEL SECURITY;

-- Policies pour accès service
CREATE POLICY "symbol_calibration_service" ON symbol_calibration FOR ALL USING (true);
CREATE POLICY "symbol_correction_patterns_service" ON symbol_correction_patterns FOR ALL USING (true);
CREATE POLICY "correction_summary_service" ON correction_summary_stats FOR ALL USING (true);
