-- ============================================================================
-- TradBOT SMC Universal — AWS RDS PostgreSQL Optimization Migration
-- Target: PostgreSQL 14+ on AWS RDS (sslmode=require)
-- Generated: 2026-05-19
--
-- This file is idempotent (safe to re-run on an existing database).
-- It consolidates and optimises every table used by:
--   - ai_server.py (FastAPI / psycopg2 / asyncpg)
--   - aws_rds_helper.py
--   - SMC_Universal EA (via HTTP endpoints)
--
-- Sections:
--   1.  Extensions
--   2.  Shared utility function (updated_at trigger)
--   3.  Core trade tables       : trade_feedback, trades, symbol_trade_stats,
--                                  daily_symbol_stats, symbol_config
--   4.  ML / prediction tables  : predictions, model_metrics, model_performance,
--                                  model_performance_log, training_runs,
--                                  feature_importance, market_data_snapshots,
--                                  ml_predictions, collection_stats
--   5.  Pattern / signal tables : stair_detections, spike_influence_events,
--                                  prediction_runs, prediction_candles,
--                                  prediction_outcomes, symbol_prediction_score_daily
--   6.  Hourly propensity        : symbol_hour_profile, symbol_hour_status
--   7.  Correction / zone tables : correction_zones, correction_zone_history,
--                                  correction_zones_analysis, correction_predictions,
--                                  prediction_performance, correction_summary_stats,
--                                  symbol_correction_patterns,
--                                  support_resistance_levels
--   8.  Calibration              : symbol_calibration
--   9.  NEW — Symbol setup scores (persisted GlobalVariable rankings)
--  10.  NEW — Spike detection events (ATR-based spike captures)
--  11.  NEW — Verdict entry quality (GOOD/PERFECT verdict outcomes)
--  12.  NEW — AI decisions log (full decision audit trail)
-- ============================================================================

-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;      -- gen_random_uuid() on older PG
-- pg_stat_statements is usually pre-installed on RDS; enable via parameter group
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements;


-- ============================================================================
-- 2. SHARED UTILITY: updated_at auto-trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION _set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Helper macro: attach _set_updated_at to any table that has an updated_at column.
-- Call after CREATE TABLE.  DO-block guards against duplicate triggers.
CREATE OR REPLACE FUNCTION _attach_updated_at_trigger(tbl text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_' || tbl || '_updated_at'
    ) THEN
        EXECUTE format(
            'CREATE TRIGGER trg_%I_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION _set_updated_at()',
            tbl, tbl
        );
    END IF;
END;
$$;


-- ============================================================================
-- 3. CORE TRADE TABLES
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 3a. trade_feedback
--     Primary source of truth for win/loss outcomes sent from MT5.
--     The Python layer inserts via aws_rds_client.insert("trade_feedback", ...).
--     Columns: symbol, open_time, close_time, entry_price, exit_price, profit,
--              ai_confidence, coherent_confidence, decision, is_win, side,
--              mt5_deal_id (idempotent upsert key), position_id, magic,
--              timeframe.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS trade_feedback (
    id                  bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Identifiers
    symbol              text            NOT NULL,
    timeframe           text            NOT NULL DEFAULT 'M1',
    -- MT5 deal identifiers (used for idempotent upsert)
    mt5_deal_id         bigint,
    position_id         bigint,
    magic               bigint,
    -- Trade prices
    entry_price         double precision NOT NULL DEFAULT 0,
    exit_price          double precision NOT NULL DEFAULT 0,
    -- Times (stored as timestamptz — always include tz offset from Python)
    open_time           timestamptz     NOT NULL,
    close_time          timestamptz     NOT NULL,
    -- Outcome
    profit              double precision NOT NULL DEFAULT 0,
    is_win              boolean         NOT NULL,
    -- AI metadata
    decision            text            NOT NULL DEFAULT 'HOLD',
    side                text            NOT NULL DEFAULT '',       -- 'buy' | 'sell' | ''
    ai_confidence       double precision,                          -- 0..1 decimal
    coherent_confidence double precision,                          -- 0..1 decimal
    -- Timestamps
    created_at          timestamptz     NOT NULL DEFAULT now()
);

-- Unique constraint for idempotent upsert from MT5 deal upload
CREATE UNIQUE INDEX IF NOT EXISTS ux_trade_feedback_mt5_deal_id
    ON trade_feedback (mt5_deal_id)
    WHERE mt5_deal_id IS NOT NULL;

-- Core query indexes
CREATE INDEX IF NOT EXISTS idx_tf_symbol
    ON trade_feedback (symbol, close_time DESC);

CREATE INDEX IF NOT EXISTS idx_tf_symbol_timeframe
    ON trade_feedback (symbol, timeframe, close_time DESC);

-- Aggregate query support (win rate per direction)
CREATE INDEX IF NOT EXISTS idx_tf_symbol_side_win
    ON trade_feedback (symbol, side, is_win, close_time DESC);

CREATE INDEX IF NOT EXISTS idx_tf_created_at
    ON trade_feedback (created_at DESC);

-- Partial index for recent profitable trades (common aggregate query)
CREATE INDEX IF NOT EXISTS idx_tf_recent_wins
    ON trade_feedback (symbol, close_time DESC)
    WHERE is_win = true;

COMMENT ON TABLE trade_feedback IS
    'Win/loss results sent from MT5 EA. Primary ML training feed and win-rate source.';
COMMENT ON COLUMN trade_feedback.ai_confidence IS
    'Normalised 0..1 decimal (divided by 100 before insert from Python).';
COMMENT ON COLUMN trade_feedback.mt5_deal_id IS
    'MT5 deal ticket — used as unique key for idempotent batch upload from /mt5/deals-upload.';


-- ---------------------------------------------------------------------------
-- 3b. trades
--     Detailed trade journal with SMC strategy tags, written via asyncpg pool.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS trades (
    id                          uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    mt5_ticket                  bigint,
    symbol                      text            NOT NULL,
    category                    text            NOT NULL DEFAULT 'boomcrash',
    strategy                    text            NOT NULL,   -- OTE, OTE_IMBALANCE, SPIKE, RECOVERY…
    direction                   text            NOT NULL
                                    CHECK (direction IN ('BUY', 'SELL')),
    volume                      double precision NOT NULL,
    entry_price                 double precision NOT NULL,
    stop_loss                   double precision,
    take_profit                 double precision,
    close_price                 double precision,
    result_usd                  numeric(14, 2),
    result_points               double precision,
    risk_reward                 double precision,
    opened_at                   timestamptz     NOT NULL,
    closed_at                   timestamptz,
    session_tag                 text,           -- LO, NYO, ASIA
    timeframe                   text            NOT NULL DEFAULT 'M1',
    ai_action                   text,
    ai_confidence               double precision,
    ml_score                    double precision,
    execution_slippage_points   double precision,
    context                     jsonb           NOT NULL DEFAULT '{}'::jsonb,
    created_at                  timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trades_symbol_time
    ON trades (symbol, opened_at DESC);

CREATE INDEX IF NOT EXISTS idx_trades_strategy
    ON trades (strategy, symbol, opened_at DESC);

CREATE INDEX IF NOT EXISTS idx_trades_direction
    ON trades (symbol, direction, opened_at DESC);

CREATE INDEX IF NOT EXISTS idx_trades_mt5_ticket
    ON trades (mt5_ticket)
    WHERE mt5_ticket IS NOT NULL;

COMMENT ON TABLE trades IS
    'Detailed trade journal including SMC strategy, slippage, AI scores. Written by asyncpg pool.';


-- ---------------------------------------------------------------------------
-- 3c. symbol_trade_stats
--     Aggregated daily/monthly stats per symbol, computed from trade_feedback.
--     Primary key: (symbol, period_type, period_start, timeframe).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS symbol_trade_stats (
    symbol          text        NOT NULL,
    period_type     text        NOT NULL CHECK (period_type IN ('day', 'month')),
    period_start    date        NOT NULL,
    timeframe       text        NOT NULL DEFAULT 'M1',
    trade_count     integer     NOT NULL DEFAULT 0,
    wins            integer     NOT NULL DEFAULT 0,
    losses          integer     NOT NULL DEFAULT 0,
    net_profit      numeric(14, 2) NOT NULL DEFAULT 0,
    gross_profit    numeric(14, 2) NOT NULL DEFAULT 0,
    gross_loss      numeric(14, 2) NOT NULL DEFAULT 0,
    last_trade_at   timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT symbol_trade_stats_pkey
        PRIMARY KEY (symbol, period_type, period_start, timeframe)
);

CREATE INDEX IF NOT EXISTS idx_sts_period
    ON symbol_trade_stats (period_type, period_start DESC, symbol);

SELECT _attach_updated_at_trigger('symbol_trade_stats');

COMMENT ON TABLE symbol_trade_stats IS
    'Rolled-up daily and monthly stats per symbol. UPSERTed by _refresh_symbol_trade_stats().';


-- ---------------------------------------------------------------------------
-- 3d. daily_symbol_stats
--     Alternative daily aggregation (written via asyncpg pool by trades endpoint).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS daily_symbol_stats (
    symbol                  text        NOT NULL,
    trade_date              date        NOT NULL,
    category                text        NOT NULL DEFAULT 'boomcrash',
    trade_count             integer     NOT NULL DEFAULT 0,
    wins                    integer     NOT NULL DEFAULT 0,
    losses                  integer     NOT NULL DEFAULT 0,
    net_profit              numeric(14, 2) NOT NULL DEFAULT 0,
    max_drawdown            numeric(14, 2),
    max_consecutive_losses  integer,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (symbol, trade_date)
);

CREATE INDEX IF NOT EXISTS idx_dss_date
    ON daily_symbol_stats (trade_date DESC, symbol);

SELECT _attach_updated_at_trigger('daily_symbol_stats');

COMMENT ON TABLE daily_symbol_stats IS
    'Lightweight daily aggregation complementary to symbol_trade_stats, written by /trades endpoint.';


-- ---------------------------------------------------------------------------
-- 3e. symbol_config
--     Adaptive per-symbol configuration read by both AI server and EA.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS symbol_config (
    symbol                  text        PRIMARY KEY,
    enabled                 boolean     NOT NULL DEFAULT true,
    max_open_positions      integer     DEFAULT 1,
    min_expectancy          double precision DEFAULT 0.0,
    min_ai_confidence       double precision DEFAULT 0.55,
    max_daily_loss_usd      numeric(14, 2),
    max_symbol_loss_usd     numeric(14, 2),
    max_consecutive_losses  integer,
    risk_profile            text        DEFAULT 'balanced',
    overrides               jsonb       NOT NULL DEFAULT '{}'::jsonb,
    updated_at              timestamptz NOT NULL DEFAULT now()
);

SELECT _attach_updated_at_trigger('symbol_config');

COMMENT ON TABLE symbol_config IS
    'Per-symbol adaptive configuration. Read by /symbol-config endpoint and EA via HTTP.';


-- ============================================================================
-- 4. ML / PREDICTION TABLES
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 4a. predictions
--     One row per AI decision emitted. Written by _push_prediction_to_supabase().
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS predictions (
    id              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol          text        NOT NULL,
    timeframe       text        NOT NULL DEFAULT 'M1',
    prediction      text        NOT NULL,       -- BUY | SELL | HOLD
    confidence      double precision NOT NULL,  -- 0..1
    reason          text,
    model_used      text,
    metadata        jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pred_symbol_time
    ON predictions (symbol, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_pred_model
    ON predictions (model_used, created_at DESC);

COMMENT ON TABLE predictions IS
    'Full log of AI BUY/SELL/HOLD decisions. One row per /decide call that reaches persistence.';


-- ---------------------------------------------------------------------------
-- 4b. model_metrics
--     Training metrics per (symbol, timeframe, model_type).
--     Written by integrated_ml_trainer and by the proxy in save_decision_to_supabase().
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS model_metrics (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol              text            NOT NULL,
    timeframe           text            NOT NULL DEFAULT 'M1',
    model_type          text            NOT NULL DEFAULT 'random_forest',
    accuracy            numeric(10, 6)  NOT NULL,
    f1_score            numeric(10, 6)  NOT NULL,
    training_samples    integer         NOT NULL,
    training_date       timestamptz     NOT NULL,
    feature_importance  jsonb,
    metadata            jsonb,
    created_at          timestamptz     NOT NULL DEFAULT now(),
    updated_at          timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mm_symbol_timeframe
    ON model_metrics (symbol, timeframe, training_date DESC);

CREATE INDEX IF NOT EXISTS idx_mm_training_date
    ON model_metrics (training_date DESC);

-- Fast lookup of latest model per symbol (covering index)
CREATE INDEX IF NOT EXISTS idx_mm_latest_per_symbol
    ON model_metrics (symbol, timeframe, training_date DESC)
    INCLUDE (accuracy, f1_score, model_type);

SELECT _attach_updated_at_trigger('model_metrics');

COMMENT ON TABLE model_metrics IS
    'ML model accuracy snapshots written after each training cycle.';


-- ---------------------------------------------------------------------------
-- 4c. model_performance
--     Rolling aggregate performance per (model_name, asset_category, symbol).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS model_performance (
    id                  bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name          text        NOT NULL,
    asset_category      text        NOT NULL,
    symbol              text        NOT NULL,
    total_predictions   integer     NOT NULL DEFAULT 0,
    correct_predictions integer     NOT NULL DEFAULT 0,
    accuracy            double precision NOT NULL DEFAULT 0,
    win_rate            double precision NOT NULL DEFAULT 0,
    avg_profit          double precision NOT NULL DEFAULT 0,
    sharpe_ratio        double precision NOT NULL DEFAULT 0,
    last_updated        timestamptz NOT NULL DEFAULT now(),
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_model_perf_key
    ON model_performance (model_name, asset_category, symbol);

CREATE INDEX IF NOT EXISTS idx_mp_symbol
    ON model_performance (symbol, model_name);

CREATE INDEX IF NOT EXISTS idx_mp_asset
    ON model_performance (asset_category);

COMMENT ON TABLE model_performance IS
    'Aggregate model accuracy per symbol/asset tracked by ml_predictions evaluator.';


-- ---------------------------------------------------------------------------
-- 4d. model_performance_log
--     Time-series accuracy snapshots per training run (duplicated definition
--     in two migrations — consolidated here).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS model_performance_log (
    id              uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol          text            NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    model_type      text            NOT NULL,
    -- Legacy key from create_model_metrics_table.sql
    model_key       text,
    accuracy        real            NOT NULL,
    f1_score        real,
    precision_val   real,
    recall_val      real,
    -- Legacy fields from create_model_metrics_table.sql
    prediction_count    integer     DEFAULT 0,
    correct_predictions integer     DEFAULT 0,
    profit_loss         numeric(15, 6) DEFAULT 0,
    samples_count   integer,
    recorded_at     timestamptz     NOT NULL DEFAULT now(),
    log_date        timestamptz     NOT NULL DEFAULT now(),
    created_at      timestamptz     NOT NULL DEFAULT now(),
    metadata        jsonb
);

CREATE INDEX IF NOT EXISTS idx_mpl_symbol_timeframe
    ON model_performance_log (symbol, timeframe, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_mpl_recorded_at
    ON model_performance_log (recorded_at DESC);

COMMENT ON TABLE model_performance_log IS
    'Time-series log of model accuracy snapshots per training cycle.';


-- ---------------------------------------------------------------------------
-- 4e. training_runs
--     One row per complete ML training cycle.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS training_runs (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol          text        NOT NULL,
    timeframe       text        NOT NULL DEFAULT 'M1',
    started_at      timestamptz NOT NULL DEFAULT now(),
    completed_at    timestamptz,
    status          text        NOT NULL DEFAULT 'running'
                        CHECK (status IN ('running', 'completed', 'failed')),
    samples_used    integer     NOT NULL DEFAULT 0,
    accuracy        real,
    f1_score        real,
    duration_sec    integer,
    error_message   text,
    metadata        jsonb
);

CREATE INDEX IF NOT EXISTS idx_tr_symbol_timeframe
    ON training_runs (symbol, timeframe, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_tr_started_at
    ON training_runs (started_at DESC);

COMMENT ON TABLE training_runs IS
    'Audit log for ML training cycles. Referenced by feature_importance.training_run_id.';


-- ---------------------------------------------------------------------------
-- 4f. feature_importance
--     Per-feature importance scores linked to training_runs.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS feature_importance (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol          text        NOT NULL,
    timeframe       text        NOT NULL DEFAULT 'M1',
    model_type      text        NOT NULL DEFAULT 'random_forest',
    training_run_id uuid        REFERENCES training_runs (id) ON DELETE SET NULL,
    feature_name    text        NOT NULL,
    importance      real        NOT NULL,
    rank            integer,
    recorded_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fi_symbol
    ON feature_importance (symbol, timeframe, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_fi_run
    ON feature_importance (training_run_id)
    WHERE training_run_id IS NOT NULL;

COMMENT ON TABLE feature_importance IS
    'Feature importance scores per training run, used to explain model decisions.';


-- ---------------------------------------------------------------------------
-- 4g. market_data_snapshots
--     50+ indicator columns collected every ~5 minutes per symbol.
--     Large table — use bigint PK, partition by month in future if > 50M rows.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS market_data_snapshots (
    id                  bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol              text        NOT NULL,
    timestamp           timestamptz NOT NULL,
    timeframe           text        NOT NULL DEFAULT 'M1',
    -- Price data
    bid                 double precision,
    ask                 double precision,
    spread_pips         double precision,
    -- Momentum
    rsi_m1              double precision,
    rsi_m5              double precision,
    rsi_m15             double precision,
    rsi_h1              double precision,
    -- Volatility
    atr_m1              double precision,
    atr_m5              double precision,
    atr_m15             double precision,
    atr_h1              double precision,
    atr_ratio           double precision,   -- current / 50-bar average
    -- EMA (9/21) per timeframe
    ema_fast_m1         double precision,
    ema_slow_m1         double precision,
    ema_fast_m5         double precision,
    ema_slow_m5         double precision,
    ema_fast_m15        double precision,
    ema_slow_m15        double precision,
    ema_fast_h1         double precision,
    ema_slow_h1         double precision,
    -- SMC structures
    fvg_detected        boolean         DEFAULT false,
    fvg_direction       integer         DEFAULT 0,      -- -1 Bearish, 0 None, 1 Bullish
    bos_detected        boolean         DEFAULT false,
    bos_direction       integer         DEFAULT 0,
    ob_proximity_atr    double precision,
    sweep_detected      boolean         DEFAULT false,
    sweep_type          text            DEFAULT '',
    -- KOLA levels
    m5_buy_level        double precision,
    m5_sell_level       double precision,
    m5_buy_touches      integer         DEFAULT 0,
    m5_sell_touches     integer         DEFAULT 0,
    m15_buy_level       double precision,
    m15_sell_level      double precision,
    m15_buy_touches     integer         DEFAULT 0,
    m15_sell_touches    integer         DEFAULT 0,
    h1_buy_level        double precision,
    h1_sell_level       double precision,
    h1_buy_touches      integer         DEFAULT 0,
    h1_sell_touches     integer         DEFAULT 0,
    -- Composite scores
    tech_buy_score      double precision DEFAULT 0,
    tech_sell_score     double precision DEFAULT 0,
    entry_quality       integer         DEFAULT 0,
    spike_probability   double precision DEFAULT 0,
    -- Bollinger / VWAP
    bb_squeeze          boolean         DEFAULT false,
    vwap_distance_pct   double precision,
    bb_pctb             double precision,
    bb_width_pct        double precision,
    -- Volume
    volume_current      bigint,
    volume_ratio        double precision,
    -- SIDO patterns
    sido_double_top     boolean         DEFAULT false,
    sido_double_bottom  boolean         DEFAULT false,
    -- Classification
    asset_category      text,
    coherence_score     double precision DEFAULT 0,
    -- Signal at collection time
    signal_action       text            DEFAULT 'HOLD',
    signal_confidence   double precision DEFAULT 0,
    -- ML labels (filled post-hoc)
    price_5min_later    double precision,
    price_15min_later   double precision,
    direction_5min      integer         DEFAULT 0,   -- -1 Down, 0 Neutral, 1 Up
    profit_5min         double precision,
    created_at          timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mds_symbol_time
    ON market_data_snapshots (symbol, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_mds_created_at
    ON market_data_snapshots (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mds_asset_symbol
    ON market_data_snapshots (asset_category, symbol, timestamp DESC);

-- Partial index: unlabelled rows waiting for outcome backfill
CREATE INDEX IF NOT EXISTS idx_mds_unlabelled
    ON market_data_snapshots (symbol, created_at DESC)
    WHERE direction_5min = 0 AND price_5min_later IS NULL;

COMMENT ON TABLE market_data_snapshots IS
    'Snapshot of 50+ technical indicators per symbol, ~every 5 min. Labels filled post-hoc for ML.';


-- ---------------------------------------------------------------------------
-- 4h. ml_predictions
--     Model output rows linked to market_data_snapshots.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ml_predictions (
    id                  bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    snapshot_id         bigint      REFERENCES market_data_snapshots (id) ON DELETE CASCADE,
    model_name          text        NOT NULL,
    model_version       text,
    symbol              text        NOT NULL,
    asset_category      text,
    predicted_direction integer     DEFAULT 0,   -- -1 Down, 0 Neutral, 1 Up
    predicted_profit    double precision,
    confidence          double precision,
    actual_direction    integer,
    actual_profit       double precision,
    prediction_accuracy boolean,
    created_at          timestamptz NOT NULL DEFAULT now(),
    evaluated_at        timestamptz
);

CREATE INDEX IF NOT EXISTS idx_mlp_snapshot
    ON ml_predictions (snapshot_id);

CREATE INDEX IF NOT EXISTS idx_mlp_symbol_model
    ON ml_predictions (symbol, model_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mlp_asset
    ON ml_predictions (asset_category, created_at DESC);

-- Partial index for rows awaiting evaluation
CREATE INDEX IF NOT EXISTS idx_mlp_unevaluated
    ON ml_predictions (symbol, created_at DESC)
    WHERE evaluated_at IS NULL;

COMMENT ON TABLE ml_predictions IS
    'Model prediction rows linked to snapshots. Evaluated 5-15 min post-creation.';


-- ---------------------------------------------------------------------------
-- 4i. collection_stats
--     Scanner execution metrics (monitoring).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS collection_stats (
    id                      bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scan_time               timestamptz NOT NULL,
    symbols_scanned         integer,
    snapshots_stored        integer,
    success_count           integer,
    failed_count            integer,
    scan_duration_seconds   integer,
    created_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cstats_time
    ON collection_stats (scan_time DESC);

COMMENT ON TABLE collection_stats IS
    'Data-collection scanner execution stats for monitoring and debugging.';


-- ============================================================================
-- 5. PATTERN / SIGNAL TABLES
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 5a. stair_detections
--     M1 staircase pattern detections (Boom/Crash, GainX/PainX).
--     Written by /stair/detect, updated by /stair/outcome.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS stair_detections (
    id                          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    client_event_id             text        UNIQUE,
    symbol                      text        NOT NULL,
    category                    text        NOT NULL DEFAULT 'boomcrash',
    direction                   text        NOT NULL
                                    CHECK (direction IN ('BUY', 'SELL')),
    timeframe                   text        NOT NULL DEFAULT 'M1',
    detected_at                 timestamptz NOT NULL DEFAULT now(),
    pattern_kinds               text,
    quality_score               double precision,
    empirical_win_rate_at_detect double precision,
    features                    jsonb       NOT NULL DEFAULT '{}'::jsonb,
    ai_action                   text,
    ai_confidence               double precision,
    mt5_ticket                  bigint,
    trade_id                    uuid,
    outcome                     text
                                    CHECK (outcome IS NULL OR outcome IN
                                        ('open', 'win', 'loss', 'breakeven', 'expired')),
    result_usd                  numeric(14, 2),
    closed_at                   timestamptz,
    source                      text        NOT NULL DEFAULT 'ea',
    learning_notes              text,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sd_symbol_time
    ON stair_detections (symbol, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_sd_symbol_dir_outcome
    ON stair_detections (symbol, direction, outcome);

CREATE INDEX IF NOT EXISTS idx_sd_client_event
    ON stair_detections (client_event_id)
    WHERE client_event_id IS NOT NULL;

-- Partial index for win-rate aggregate queries (closed trades only)
CREATE INDEX IF NOT EXISTS idx_sd_closed_trades
    ON stair_detections (symbol, direction, pattern_kinds, outcome)
    WHERE outcome IN ('win', 'loss');

SELECT _attach_updated_at_trigger('stair_detections');

COMMENT ON TABLE stair_detections IS
    'Staircase setup log (Boom/Crash). Outcome updated at trade close for win-rate calibration.';


-- ---------------------------------------------------------------------------
-- 5b. spike_influence_events
--     Zones emitted by MT5 before a potential spike; spike_hit updated post-hoc.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS spike_influence_events (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol              text        NOT NULL,
    timeframe           text        NOT NULL DEFAULT 'M1',
    hour_utc            integer     NOT NULL CHECK (hour_utc BETWEEN 0 AND 23),
    event_time_utc      timestamptz NOT NULL DEFAULT now(),
    local_probability   numeric(10, 6) NOT NULL DEFAULT 0,
    combined_score      numeric(10, 6) NOT NULL DEFAULT 0,
    mass_level          integer     NOT NULL DEFAULT 0 CHECK (mass_level BETWEEN 0 AND 3),
    prior_server        numeric(10, 6) NOT NULL DEFAULT 0.5,
    window_seconds      integer     NOT NULL DEFAULT 0,
    price_band_low      numeric(20, 8) NOT NULL DEFAULT 0,
    price_band_high     numeric(20, 8) NOT NULL DEFAULT 0,
    features            jsonb       NOT NULL DEFAULT '{}'::jsonb,
    source              text        NOT NULL DEFAULT 'mt5',
    spike_hit           boolean,
    spike_hit_at        timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sie_symbol_time
    ON spike_influence_events (symbol, event_time_utc DESC);

CREATE INDEX IF NOT EXISTS idx_sie_hour
    ON spike_influence_events (symbol, hour_utc, event_time_utc DESC);

-- Partial index to find unresolved events quickly
CREATE INDEX IF NOT EXISTS idx_sie_pending
    ON spike_influence_events (symbol, event_time_utc DESC)
    WHERE spike_hit IS NULL;

COMMENT ON TABLE spike_influence_events IS
    'Pre-spike influence zones sent by EA. spike_hit backfilled when outcome known.';


-- ---------------------------------------------------------------------------
-- 5c. prediction_runs / prediction_candles / prediction_outcomes
--     Structured future-candle prediction runs.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS prediction_runs (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol          text        NOT NULL,
    timeframe       text        NOT NULL,
    horizon         integer     NOT NULL CHECK (horizon > 0),
    model_version   text        NOT NULL DEFAULT 'structure_v1',
    metadata        jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pr_symbol_tf_created
    ON prediction_runs (symbol, timeframe, created_at DESC);

CREATE TABLE IF NOT EXISTS prediction_candles (
    run_id          uuid        NOT NULL REFERENCES prediction_runs (id) ON DELETE CASCADE,
    step            integer     NOT NULL CHECK (step > 0),
    candle_time     bigint      NOT NULL,
    open            double precision NOT NULL,
    high            double precision NOT NULL,
    low             double precision NOT NULL,
    close           double precision NOT NULL,
    confidence      double precision NOT NULL DEFAULT 0.5,
    phase           text,
    structure_tag   text,
    level_ref       double precision,
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (run_id, step)
);

CREATE INDEX IF NOT EXISTS idx_pc_candle_time
    ON prediction_candles (candle_time);

CREATE TABLE IF NOT EXISTS prediction_outcomes (
    run_id          uuid        NOT NULL REFERENCES prediction_runs (id) ON DELETE CASCADE,
    step            integer     NOT NULL CHECK (step > 0),
    actual_open     double precision,
    actual_high     double precision,
    actual_low      double precision,
    actual_close    double precision,
    direction_hit   boolean,
    mae             double precision,
    mape            double precision,
    score           double precision,
    evaluated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (run_id, step)
);

COMMENT ON TABLE prediction_runs IS
    'Container for multi-step candle prediction runs (horizon N bars ahead).';

COMMENT ON TABLE prediction_candles IS
    'Predicted OHLC per step, linked to prediction_runs.';

COMMENT ON TABLE prediction_outcomes IS
    'Actual OHLC outcomes vs predictions for MAE/accuracy tracking.';


-- ---------------------------------------------------------------------------
-- 5d. symbol_prediction_score_daily
--     Daily hit-rate aggregate per (symbol, timeframe).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS symbol_prediction_score_daily (
    symbol              text            NOT NULL,
    timeframe           text            NOT NULL,
    day                 date            NOT NULL,
    samples             integer         NOT NULL DEFAULT 0,
    direction_hit_rate  double precision NOT NULL DEFAULT 0,
    avg_mae             double precision NOT NULL DEFAULT 0,
    score               double precision NOT NULL DEFAULT 0,
    updated_at          timestamptz     NOT NULL DEFAULT now(),
    PRIMARY KEY (symbol, timeframe, day)
);

CREATE INDEX IF NOT EXISTS idx_spsd_day
    ON symbol_prediction_score_daily (day DESC);

CREATE INDEX IF NOT EXISTS idx_spsd_symbol_tf
    ON symbol_prediction_score_daily (symbol, timeframe, day DESC);

SELECT _attach_updated_at_trigger('symbol_prediction_score_daily');

COMMENT ON TABLE symbol_prediction_score_daily IS
    'Daily direction-hit rate per symbol — feeds the "propice" score dashboard.';


-- ============================================================================
-- 6. HOURLY PROPENSITY TABLES
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 6a. symbol_hour_profile
--     ATR / volatility / spike stats per symbol per hour of day.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS symbol_hour_profile (
    symbol          text            NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    lookback_days   integer         NOT NULL,
    hour_utc        integer         NOT NULL CHECK (hour_utc BETWEEN 0 AND 23),
    samples         integer         NOT NULL DEFAULT 0,
    atr_mean        numeric(14, 6)  NOT NULL DEFAULT 0,
    volatility_mean numeric(14, 8)  NOT NULL DEFAULT 0,
    spike_rate      numeric(8, 6)   NOT NULL DEFAULT 0,
    trend_bias      numeric(14, 8)  NOT NULL DEFAULT 0,
    propice_score   numeric(8, 6)   NOT NULL DEFAULT 0,
    updated_at      timestamptz     NOT NULL DEFAULT now(),
    CONSTRAINT symbol_hour_profile_pkey
        PRIMARY KEY (symbol, timeframe, lookback_days, hour_utc)
);

CREATE INDEX IF NOT EXISTS idx_shp_lookup
    ON symbol_hour_profile (symbol, timeframe, lookback_days, hour_utc);

SELECT _attach_updated_at_trigger('symbol_hour_profile');


-- ---------------------------------------------------------------------------
-- 6b. symbol_hour_status
--     Current-hour propensity status cache (one row per symbol+timeframe).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS symbol_hour_status (
    symbol          text            NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    now_hour_utc    integer         NOT NULL CHECK (now_hour_utc BETWEEN 0 AND 23),
    propice_score   numeric(8, 6)   NOT NULL DEFAULT 0,
    penalty_factor  numeric(8, 6)   NOT NULL DEFAULT 1,
    reason          text            NOT NULL DEFAULT '',
    computed_at     timestamptz     NOT NULL DEFAULT now(),
    CONSTRAINT symbol_hour_status_pkey PRIMARY KEY (symbol, timeframe)
);

CREATE INDEX IF NOT EXISTS idx_shs_symbol
    ON symbol_hour_status (symbol, timeframe, computed_at DESC);

COMMENT ON TABLE symbol_hour_profile IS
    'Per-hour ATR/volatility/spike stats for a given symbol and lookback window.';
COMMENT ON TABLE symbol_hour_status IS
    'Latest propensity score for symbol+timeframe at the current UTC hour.';


-- ============================================================================
-- 7. CORRECTION / ZONE TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS correction_zones (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol      text        NOT NULL,
    timeframe   text        NOT NULL DEFAULT 'M1',
    zone_type   text        NOT NULL,       -- support, resistance, premium, discount
    price_level real        NOT NULL,
    strength    real        NOT NULL DEFAULT 1.0,
    confidence  real        NOT NULL DEFAULT 0.5,
    is_active   boolean     NOT NULL DEFAULT true,
    expires_at  timestamptz,
    source      text        NOT NULL DEFAULT 'ai',
    metadata    jsonb,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cz_symbol
    ON correction_zones (symbol, timeframe, is_active, expires_at);

CREATE INDEX IF NOT EXISTS idx_cz_type
    ON correction_zones (zone_type, symbol);

SELECT _attach_updated_at_trigger('correction_zones');


CREATE TABLE IF NOT EXISTS correction_zone_history (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id         uuid        REFERENCES correction_zones (id) ON DELETE SET NULL,
    symbol          text        NOT NULL,
    zone_type       text        NOT NULL,
    price_level     real        NOT NULL,
    touched_at      timestamptz NOT NULL DEFAULT now(),
    touch_price     real        NOT NULL,
    was_breakout    boolean     NOT NULL DEFAULT false,
    trade_executed  boolean     NOT NULL DEFAULT false,
    trade_result    real,
    metadata        jsonb
);

CREATE INDEX IF NOT EXISTS idx_czh_symbol
    ON correction_zone_history (symbol, touched_at DESC);

CREATE INDEX IF NOT EXISTS idx_czh_zone
    ON correction_zone_history (zone_id)
    WHERE zone_id IS NOT NULL;


CREATE TABLE IF NOT EXISTS correction_zones_analysis (
    id                          bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol                      text            NOT NULL,
    timeframe                   text            NOT NULL DEFAULT 'M1',
    analysis_date               timestamptz     NOT NULL DEFAULT now(),
    total_corrections_analyzed  integer,
    uptrend_corrections         integer,
    downtrend_corrections       integer,
    avg_retracement_uptrend     numeric(10, 4),
    avg_retracement_downtrend   numeric(10, 4),
    max_retracement_uptrend     numeric(10, 4),
    max_retracement_downtrend   numeric(10, 4),
    gradual_retracement_patterns integer,
    consolidation_patterns      integer,
    sharp_reversal_patterns     integer,
    support_levels              jsonb,
    resistance_levels           jsonb,
    current_price               numeric(15, 5),
    current_trend               text            CHECK (current_trend IN ('UP', 'DOWN', 'SIDEWAYS')),
    volatility_level            numeric(10, 4)
);

CREATE INDEX IF NOT EXISTS idx_cza_symbol_date
    ON correction_zones_analysis (symbol, analysis_date DESC);


CREATE TABLE IF NOT EXISTS correction_predictions (
    id                      bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol                  text            NOT NULL,
    timeframe               text            NOT NULL DEFAULT 'M1',
    prediction_date         timestamptz     NOT NULL DEFAULT now(),
    current_price           numeric(15, 5)  NOT NULL,
    current_trend           text            NOT NULL CHECK (current_trend IN ('UP', 'DOWN', 'SIDEWAYS')),
    prediction_confidence   numeric(5, 2),
    zone_1_level            numeric(15, 5),
    zone_1_type             text,
    zone_1_probability      numeric(5, 2),
    zone_2_level            numeric(15, 5),
    zone_2_type             text,
    zone_2_probability      numeric(5, 2),
    zone_3_level            numeric(15, 5),
    zone_3_type             text,
    zone_3_probability      numeric(5, 2),
    trend_strength_factor   numeric(5, 2),
    volatility_adjustment   numeric(5, 2),
    historical_accuracy     numeric(5, 2),
    zone_1_reached          boolean,
    zone_2_reached          boolean,
    zone_3_reached          boolean,
    actual_retracement_level numeric(15, 5),
    prediction_accuracy     numeric(5, 2),
    prediction_valid_until  timestamptz,
    created_at              timestamptz     NOT NULL DEFAULT now(),
    updated_at              timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cp_symbol_date
    ON correction_predictions (symbol, prediction_date DESC);

CREATE INDEX IF NOT EXISTS idx_cp_composite
    ON correction_predictions (symbol, current_trend, prediction_confidence, prediction_date);

SELECT _attach_updated_at_trigger('correction_predictions');


CREATE TABLE IF NOT EXISTS prediction_performance (
    id                      bigint  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol                  text    NOT NULL,
    performance_date        date    NOT NULL,
    total_predictions       integer,
    successful_predictions  integer,
    failed_predictions      integer,
    zone_1_accuracy         numeric(5, 2),
    zone_2_accuracy         numeric(5, 2),
    zone_3_accuracy         numeric(5, 2),
    overall_accuracy        numeric(5, 2),
    avg_confidence          numeric(5, 2),
    total_corrections_analyzed integer,
    avg_retracement_used    numeric(10, 4),
    market_volatility       numeric(10, 4)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_pp_symbol_date
    ON prediction_performance (symbol, performance_date);

CREATE INDEX IF NOT EXISTS idx_pp_date
    ON prediction_performance (performance_date DESC);


CREATE TABLE IF NOT EXISTS correction_summary_stats (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol                  text        NOT NULL,
    timeframe               text        NOT NULL DEFAULT 'M1',
    period_start            timestamptz NOT NULL,
    period_end              timestamptz NOT NULL,
    total_corrections       integer     DEFAULT 0,
    successful_predictions  integer     DEFAULT 0,
    avg_retracement_pct     numeric(10, 4),
    avg_duration_bars       numeric(10, 2),
    success_rate            numeric(5, 4),
    dominant_pattern        text,
    metadata                jsonb,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_css_symbol
    ON correction_summary_stats (symbol, timeframe, period_start DESC);

SELECT _attach_updated_at_trigger('correction_summary_stats');


CREATE TABLE IF NOT EXISTS symbol_correction_patterns (
    id                          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol                      text        NOT NULL,
    pattern_type                text        NOT NULL,   -- GRADUAL, CONSOLIDATION, SHARP_REVERSAL
    avg_retracement_percentage  numeric(10, 4),
    typical_duration_bars       integer,
    success_rate                numeric(5, 2),
    min_trend_strength          numeric(5, 2),
    max_volatility_level        numeric(10, 4),
    best_timeframes             text,   -- 'M1,M5,M15'
    occurrences_count           integer,
    last_updated                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scp_symbol_pattern
    ON symbol_correction_patterns (symbol, pattern_type);

CREATE INDEX IF NOT EXISTS idx_scp_success
    ON symbol_correction_patterns (success_rate DESC);


CREATE TABLE IF NOT EXISTS support_resistance_levels (
    id              bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol          text            NOT NULL,
    support         numeric(15, 5)  NOT NULL,
    resistance      numeric(15, 5)  NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    strength_score  numeric(5, 2)   NOT NULL DEFAULT 0
                        CHECK (strength_score BETWEEN 0 AND 100),
    touch_count     integer         NOT NULL DEFAULT 0,
    last_touch      timestamptz,
    created_at      timestamptz     NOT NULL DEFAULT now(),
    updated_at      timestamptz     NOT NULL DEFAULT now(),
    CONSTRAINT sr_support_positive   CHECK (support > 0),
    CONSTRAINT sr_resistance_positive CHECK (resistance > 0),
    CONSTRAINT sr_order              CHECK (support < resistance)
);

CREATE INDEX IF NOT EXISTS idx_sr_symbol_tf
    ON support_resistance_levels (symbol, timeframe, strength_score DESC);

SELECT _attach_updated_at_trigger('support_resistance_levels');


-- ============================================================================
-- 8. CALIBRATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS symbol_calibration (
    id              bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol          text            NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    wins            integer         NOT NULL DEFAULT 0,
    total           integer         NOT NULL DEFAULT 0,
    drift_factor    numeric(10, 6)  NOT NULL DEFAULT 1.0,
    last_updated    timestamptz     NOT NULL DEFAULT now(),
    metadata        jsonb
);

-- Unique per (symbol, timeframe) so calibration can be safely upserted
CREATE UNIQUE INDEX IF NOT EXISTS ux_sc_symbol_tf
    ON symbol_calibration (symbol, timeframe);

SELECT _attach_updated_at_trigger('symbol_calibration');

COMMENT ON TABLE symbol_calibration IS
    'Per-symbol confidence drift calibration factor. Updated by continuous learning loop.';


-- ============================================================================
-- 9. NEW — symbol_setup_scores
--     Persists the Top-3 setup probability scores computed in MQL5 via
--     GlobalVariables (which are lost on EA restart / terminal close).
--     One row per (symbol, computed_at) — latest row = current score.
--
--     This replaces volatile GlobalVariable_SetupScore_<symbol> storage
--     and gives a cross-session history usable for backtest and monitoring.
-- ============================================================================

CREATE TABLE IF NOT EXISTS symbol_setup_scores (
    id              bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol          text            NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    -- Composite score 0..100 used for Top-3 ranking
    setup_score     numeric(7, 4)   NOT NULL,
    -- Component sub-scores
    win_rate        numeric(7, 4),          -- historical win rate 0..1
    expectancy      numeric(10, 4),         -- avg profit per trade USD
    propice_score   numeric(8, 6),          -- hourly propensity score
    trade_count     integer,                -- sample count used
    direction       text
                        CHECK (direction IS NULL OR direction IN ('BUY', 'SELL', 'BOTH')),
    -- Context snapshot at computation time
    hour_utc        integer         CHECK (hour_utc IS NULL OR hour_utc BETWEEN 0 AND 23),
    atr_value       double precision,
    -- Ranking position among all active symbols (1 = best)
    rank_position   integer,
    in_top3         boolean         NOT NULL DEFAULT false,
    -- Metadata
    source          text            NOT NULL DEFAULT 'ea',  -- 'ea' | 'server'
    computed_at     timestamptz     NOT NULL DEFAULT now()
);

-- Fast lookup: latest score for a symbol
CREATE INDEX IF NOT EXISTS idx_sss_symbol_time
    ON symbol_setup_scores (symbol, computed_at DESC);

-- Dashboard: all top-3 symbols at a given time
CREATE INDEX IF NOT EXISTS idx_sss_top3_time
    ON symbol_setup_scores (computed_at DESC, rank_position)
    WHERE in_top3 = true;

-- Aggregate analysis by direction
CREATE INDEX IF NOT EXISTS idx_sss_direction
    ON symbol_setup_scores (symbol, direction, computed_at DESC);

COMMENT ON TABLE symbol_setup_scores IS
    'Persists MT5 GlobalVariable setup-probability scores (0-100) per symbol. '
    'Provides cross-session history and drives the propice-top dashboard. '
    'Top-3 ranking is the primary source for auto-entry selection in the EA.';

COMMENT ON COLUMN symbol_setup_scores.setup_score IS
    'Composite score 0-100 computed from win_rate × expectancy × propice_score.';
COMMENT ON COLUMN symbol_setup_scores.in_top3 IS
    'True if this symbol was in the Top-3 ranking at computation time.';


-- ============================================================================
-- 10. NEW — spike_detection_events
--      Records each detected spike (Boom/Crash ATR-based) with the ATR
--      multiplier reached and the profit captured.
--      Purpose: train the spike probability model and track spike quality
--      per symbol / hour.
-- ============================================================================

CREATE TABLE IF NOT EXISTS spike_detection_events (
    id                  bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Event identity
    symbol              text            NOT NULL,
    timeframe           text            NOT NULL DEFAULT 'M1',
    direction           text            NOT NULL CHECK (direction IN ('BOOM', 'CRASH', 'BUY', 'SELL')),
    -- Spike magnitude
    atr_multiplier      numeric(8, 4)   NOT NULL,   -- e.g. 3.5 = spike was 3.5× ATR
    atr_value           double precision NOT NULL,   -- ATR at spike time (in price units)
    spike_points        double precision,            -- raw point move
    -- Entry / outcome
    entry_price         double precision,
    exit_price          double precision,
    profit_usd          numeric(14, 4),
    profit_captured     boolean         NOT NULL DEFAULT false,  -- True if EA closed in profit
    -- Spike timing
    spike_started_at    timestamptz     NOT NULL DEFAULT now(),
    spike_closed_at     timestamptz,
    duration_seconds    integer,
    -- Context
    hour_utc            integer         CHECK (hour_utc IS NULL OR hour_utc BETWEEN 0 AND 23),
    session_tag         text,           -- LO, NYO, ASIA
    prior_setup_score   numeric(7, 4),  -- setup score at spike time (from symbol_setup_scores)
    prior_spike_prob    numeric(8, 6),  -- server-side spike probability at that moment
    features            jsonb           NOT NULL DEFAULT '{}'::jsonb,
    mt5_ticket          bigint,
    source              text            NOT NULL DEFAULT 'ea',
    created_at          timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sde_symbol_time
    ON spike_detection_events (symbol, spike_started_at DESC);

CREATE INDEX IF NOT EXISTS idx_sde_symbol_direction
    ON spike_detection_events (symbol, direction, spike_started_at DESC);

-- Spike quality analysis by hour
CREATE INDEX IF NOT EXISTS idx_sde_hour_symbol
    ON spike_detection_events (symbol, hour_utc, spike_started_at DESC);

-- Find unclosed spikes quickly
CREATE INDEX IF NOT EXISTS idx_sde_open
    ON spike_detection_events (symbol, spike_started_at DESC)
    WHERE spike_closed_at IS NULL;

COMMENT ON TABLE spike_detection_events IS
    'Each detected ATR-based spike event (Boom/Crash). Captures magnitude, profit and '
    'contextual indicators for training the spike_probability ML model. '
    'Replaces the ephemeral spike_influence_events pattern-match with full outcome tracking.';

COMMENT ON COLUMN spike_detection_events.atr_multiplier IS
    'Spike size expressed as a multiple of ATR14 at detection time. '
    'Boom spikes typically range 2.5x–6x ATR.';

COMMENT ON COLUMN spike_detection_events.profit_captured IS
    'True when the EA successfully entered and closed the spike trade in profit.';


-- ============================================================================
-- 11. NEW — verdict_entry_quality
--      Records each entry that was triggered by a GOOD/PERFECT BUY/SELL
--      verdict (multi-timeframe EMA alignment), with the subsequent outcome.
--      Used to calibrate verdict confidence thresholds and measure how much
--      each verdict label predicts actual trade success.
-- ============================================================================

CREATE TABLE IF NOT EXISTS verdict_entry_quality (
    id              bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Identifiers
    symbol          text            NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    mt5_ticket      bigint,
    -- Verdict context
    verdict_label   text            NOT NULL
                        CHECK (verdict_label IN ('GOOD_BUY', 'PERFECT_BUY', 'GOOD_SELL', 'PERFECT_SELL')),
    verdict_num     numeric(6, 3)   NOT NULL,    -- raw verdict_num value (e.g. 2.7 = PERFECT BUY)
    -- AI / prediction context
    ia_direction    text            NOT NULL CHECK (ia_direction IN ('BUY', 'SELL', 'HOLD')),
    ia_confidence   numeric(6, 4),               -- 0..1 decimal
    prediction_direction text       CHECK (prediction_direction IS NULL OR prediction_direction IN ('BUY', 'SELL', 'HOLD')),
    -- Market trend at entry time
    trend_direction text            CHECK (trend_direction IS NULL OR trend_direction IN ('BUY', 'SELL', 'SIDEWAYS')),
    ema9_m1         double precision,
    ema21_m1        double precision,
    ema9_m5         double precision,
    ema21_m5        double precision,
    -- Entry details
    entry_price     double precision NOT NULL,
    stop_loss       double precision,
    take_profit     double precision,
    session_tag     text,
    hour_utc        integer         CHECK (hour_utc IS NULL OR hour_utc BETWEEN 0 AND 23),
    -- Outcome
    result          text            CHECK (result IS NULL OR result IN ('WIN', 'LOSS', 'BREAKEVEN', 'OPEN')),
    exit_price      double precision,
    profit_usd      numeric(14, 4),
    pips            numeric(10, 4),              -- profit / loss expressed in pips
    duration_min    integer,                     -- trade duration in minutes
    risk_reward     double precision,
    -- ML scores at entry
    ml_score        double precision,
    spike_prob      double precision,
    setup_score     numeric(7, 4),
    -- Timestamps
    entered_at      timestamptz     NOT NULL DEFAULT now(),
    closed_at       timestamptz,
    created_at      timestamptz     NOT NULL DEFAULT now(),
    updated_at      timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_veq_symbol_time
    ON verdict_entry_quality (symbol, entered_at DESC);

CREATE INDEX IF NOT EXISTS idx_veq_verdict_symbol
    ON verdict_entry_quality (verdict_label, symbol, entered_at DESC);

-- Calibration query: win rate per verdict label per symbol
CREATE INDEX IF NOT EXISTS idx_veq_verdict_result
    ON verdict_entry_quality (symbol, verdict_label, result)
    WHERE result IN ('WIN', 'LOSS');

-- Direction coherence analysis
CREATE INDEX IF NOT EXISTS idx_veq_direction_coherence
    ON verdict_entry_quality (symbol, ia_direction, verdict_label, result);

-- Open positions (awaiting close callback)
CREATE INDEX IF NOT EXISTS idx_veq_open
    ON verdict_entry_quality (symbol, entered_at DESC)
    WHERE result = 'OPEN' OR result IS NULL;

SELECT _attach_updated_at_trigger('verdict_entry_quality');

COMMENT ON TABLE verdict_entry_quality IS
    'Records every entry triggered by a GOOD/PERFECT BUY/SELL verdict with the actual '
    'trade outcome. Enables calibration of verdict confidence thresholds and '
    'measures alignment between IA direction, prediction direction and actual result.';

COMMENT ON COLUMN verdict_entry_quality.verdict_label IS
    'GOOD_BUY / PERFECT_BUY / GOOD_SELL / PERFECT_SELL — derived from verdict_num: '
    '>=2.5 = PERFECT BUY, >=1.5 = GOOD BUY, <=-2.5 = PERFECT SELL, <=-1.5 = GOOD SELL.';

COMMENT ON COLUMN verdict_entry_quality.verdict_num IS
    'Raw numeric verdict value from the EA multi-timeframe EMA alignment algorithm. '
    'Positive = bullish bias, negative = bearish bias. Magnitude = alignment strength.';

COMMENT ON COLUMN verdict_entry_quality.pips IS
    'Trade result in pips (positive = profit). Normalised for cross-symbol comparison.';


-- ============================================================================
-- 12. NEW — ai_decisions_log
--      Full audit trail of every decision emitted by /decide or /gom/interpret.
--      Provides a richer, queryable alternative to the current `predictions`
--      table — includes all inputs, all scores, full verdict context.
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_decisions_log (
    id              bigint          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Request context
    symbol          text            NOT NULL,
    timeframe       text            NOT NULL DEFAULT 'M1',
    session_id      text,                       -- optional request grouping key
    -- Decision output
    action          text            NOT NULL CHECK (action IN ('BUY', 'SELL', 'HOLD')),
    confidence      numeric(6, 4)   NOT NULL,   -- 0..1 decimal
    reason          text,
    model_used      text,
    -- Input scores that drove the decision
    verdict_num     numeric(6, 3),
    spike_prob      numeric(8, 6),
    setup_score     numeric(7, 4),
    ml_score        numeric(8, 6),
    coherence_score numeric(8, 6),
    -- Market snapshot at decision time
    bid             double precision,
    atr_m15         double precision,
    rsi_m1          double precision,
    ema9_m1         double precision,
    ema21_m1        double precision,
    -- Linked tables
    prediction_id   bigint          REFERENCES predictions (id) ON DELETE SET NULL,
    trade_feedback_id bigint        REFERENCES trade_feedback (id) ON DELETE SET NULL,
    -- Full request/response blob for debugging
    request_json    jsonb           NOT NULL DEFAULT '{}'::jsonb,
    response_json   jsonb           NOT NULL DEFAULT '{}'::jsonb,
    -- Outcome (backfilled when trade closes)
    outcome_result  text            CHECK (outcome_result IS NULL OR outcome_result IN ('WIN', 'LOSS', 'BREAKEVEN', 'NO_TRADE')),
    outcome_profit  numeric(14, 4),
    -- Timestamps
    decided_at      timestamptz     NOT NULL DEFAULT now(),
    created_at      timestamptz     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_adl_symbol_time
    ON ai_decisions_log (symbol, decided_at DESC);

CREATE INDEX IF NOT EXISTS idx_adl_action
    ON ai_decisions_log (symbol, action, decided_at DESC);

-- Performance analysis: confidence calibration
CREATE INDEX IF NOT EXISTS idx_adl_confidence_outcome
    ON ai_decisions_log (symbol, confidence, outcome_result)
    WHERE outcome_result IS NOT NULL;

-- Partial index for unanswered decisions
CREATE INDEX IF NOT EXISTS idx_adl_no_outcome
    ON ai_decisions_log (symbol, decided_at DESC)
    WHERE outcome_result IS NULL;

COMMENT ON TABLE ai_decisions_log IS
    'Full audit trail of every BUY/SELL/HOLD decision. Captures all input scores '
    'and the full request/response JSON. Outcome backfilled when the linked trade closes. '
    'Use for confidence calibration, model A/B comparison and post-trade analysis.';


-- ============================================================================
-- VIEWS (non-materialized — fast enough for dashboards with proper indexes)
-- ============================================================================

-- View: Latest setup score per symbol (replaces GlobalVariable polling)
CREATE OR REPLACE VIEW v_latest_setup_scores AS
SELECT DISTINCT ON (symbol)
    symbol,
    setup_score,
    win_rate,
    expectancy,
    propice_score,
    rank_position,
    in_top3,
    direction,
    computed_at
FROM symbol_setup_scores
ORDER BY symbol, computed_at DESC;

COMMENT ON VIEW v_latest_setup_scores IS
    'Latest setup score per symbol. Use for EA Top-3 selection and dashboard.';


-- View: Win rate per verdict label per symbol (calibration dashboard)
CREATE OR REPLACE VIEW v_verdict_win_rate AS
SELECT
    symbol,
    verdict_label,
    ia_direction,
    count(*) FILTER (WHERE result IN ('WIN', 'LOSS'))   AS closed_trades,
    count(*) FILTER (WHERE result = 'WIN')              AS wins,
    count(*) FILTER (WHERE result = 'LOSS')             AS losses,
    round(
        count(*) FILTER (WHERE result = 'WIN')::numeric
        / nullif(count(*) FILTER (WHERE result IN ('WIN', 'LOSS')), 0),
        4
    )                                                   AS win_rate,
    avg(pips) FILTER (WHERE result IN ('WIN', 'LOSS'))  AS avg_pips,
    avg(duration_min) FILTER (WHERE result IN ('WIN', 'LOSS')) AS avg_duration_min
FROM verdict_entry_quality
GROUP BY symbol, verdict_label, ia_direction;

COMMENT ON VIEW v_verdict_win_rate IS
    'Win rate per verdict label per symbol. Drives threshold calibration for GOOD/PERFECT entries.';


-- View: Spike quality per symbol per hour
CREATE OR REPLACE VIEW v_spike_quality_by_hour AS
SELECT
    symbol,
    direction,
    hour_utc,
    count(*)                                        AS total_spikes,
    count(*) FILTER (WHERE profit_captured = true)  AS profitable_spikes,
    round(
        count(*) FILTER (WHERE profit_captured = true)::numeric
        / nullif(count(*), 0),
        4
    )                                               AS capture_rate,
    avg(atr_multiplier)                             AS avg_atr_multiplier,
    avg(profit_usd)                                 AS avg_profit_usd
FROM spike_detection_events
WHERE spike_closed_at IS NOT NULL
GROUP BY symbol, direction, hour_utc;

COMMENT ON VIEW v_spike_quality_by_hour IS
    'Spike capture rate and average profit by symbol/direction/hour. '
    'Feed for spike_probability model feature engineering.';


-- View: Staircase win rate (mirrors existing stair_quality_summary but more detailed)
CREATE OR REPLACE VIEW v_stair_win_rate AS
SELECT
    symbol,
    direction,
    coalesce(nullif(trim(pattern_kinds), ''), 'any') AS pattern_kinds,
    count(*) FILTER (WHERE outcome IN ('win', 'loss')) AS closed_trades,
    count(*) FILTER (WHERE outcome = 'win')            AS wins,
    count(*) FILTER (WHERE outcome = 'loss')           AS losses,
    round(
        count(*) FILTER (WHERE outcome = 'win')::numeric
        / nullif(count(*) FILTER (WHERE outcome IN ('win', 'loss')), 0),
        4
    )                                                  AS win_rate,
    avg(result_usd) FILTER (WHERE outcome IN ('win', 'loss')) AS avg_result_usd
FROM stair_detections
WHERE outcome IN ('win', 'loss')
GROUP BY symbol, direction, coalesce(nullif(trim(pattern_kinds), ''), 'any');

COMMENT ON VIEW v_stair_win_rate IS
    'Staircase pattern win rates including avg_result_usd. Supersedes stair_quality_summary.';


-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
