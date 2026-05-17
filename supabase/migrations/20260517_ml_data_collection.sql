-- ============================================================================
-- ML Data Collection Schema - AWS RDS PostgreSQL
-- Phase 2: Store market data snapshots and ML predictions for training
-- ============================================================================

-- Create market_data_snapshots table (50+ indicator columns)
CREATE TABLE IF NOT EXISTS market_data_snapshots (
    id BIGSERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    timeframe TEXT NOT NULL DEFAULT 'M1',

    -- Price data
    bid DOUBLE PRECISION,
    ask DOUBLE PRECISION,
    spread_pips DOUBLE PRECISION,

    -- Momentum indicators (M1, M5, M15, H1)
    rsi_m1 DOUBLE PRECISION,
    rsi_m5 DOUBLE PRECISION,
    rsi_m15 DOUBLE PRECISION,
    rsi_h1 DOUBLE PRECISION,

    -- Volatility indicators
    atr_m1 DOUBLE PRECISION,
    atr_m5 DOUBLE PRECISION,
    atr_m15 DOUBLE PRECISION,
    atr_h1 DOUBLE PRECISION,
    atr_ratio DOUBLE PRECISION,  -- current / 50-bar average

    -- Trend indicators (EMA 9/21)
    ema_fast_m1 DOUBLE PRECISION,
    ema_slow_m1 DOUBLE PRECISION,
    ema_fast_m5 DOUBLE PRECISION,
    ema_slow_m5 DOUBLE PRECISION,
    ema_fast_m15 DOUBLE PRECISION,
    ema_slow_m15 DOUBLE PRECISION,
    ema_fast_h1 DOUBLE PRECISION,
    ema_slow_h1 DOUBLE PRECISION,

    -- SMC structures
    fvg_detected BOOLEAN DEFAULT FALSE,
    fvg_direction INT DEFAULT 0,  -- -1=Bearish, 0=None, 1=Bullish
    bos_detected BOOLEAN DEFAULT FALSE,
    bos_direction INT DEFAULT 0,
    ob_proximity_atr DOUBLE PRECISION,
    sweep_detected BOOLEAN DEFAULT FALSE,
    sweep_type TEXT DEFAULT '',

    -- KOLA levels (M5, M15, H1)
    m5_buy_level DOUBLE PRECISION,
    m5_sell_level DOUBLE PRECISION,
    m5_buy_touches INT DEFAULT 0,
    m5_sell_touches INT DEFAULT 0,
    m15_buy_level DOUBLE PRECISION,
    m15_sell_level DOUBLE PRECISION,
    m15_buy_touches INT DEFAULT 0,
    m15_sell_touches INT DEFAULT 0,
    h1_buy_level DOUBLE PRECISION,
    h1_sell_level DOUBLE PRECISION,
    h1_buy_touches INT DEFAULT 0,
    h1_sell_touches INT DEFAULT 0,

    -- Confluence and quality scores
    tech_buy_score DOUBLE PRECISION DEFAULT 0,
    tech_sell_score DOUBLE PRECISION DEFAULT 0,
    entry_quality INT DEFAULT 0,
    spike_probability DOUBLE PRECISION DEFAULT 0,

    -- Bollinger Bands + VWAP
    bb_squeeze BOOLEAN DEFAULT FALSE,
    vwap_distance_pct DOUBLE PRECISION,
    bb_pctb DOUBLE PRECISION,
    bb_width_pct DOUBLE PRECISION,

    -- Volume analysis
    volume_current BIGINT,
    volume_ratio DOUBLE PRECISION,

    -- SIDO patterns
    sido_double_top BOOLEAN DEFAULT FALSE,
    sido_double_bottom BOOLEAN DEFAULT FALSE,

    -- Asset classification
    asset_category TEXT,

    -- Multi-timeframe alignment
    coherence_score DOUBLE PRECISION DEFAULT 0,

    -- EA signal at collection time
    signal_action TEXT DEFAULT 'HOLD',
    signal_confidence DOUBLE PRECISION DEFAULT 0,

    -- Labels for ML (filled in after outcomes known)
    price_5min_later DOUBLE PRECISION,
    price_15min_later DOUBLE PRECISION,
    direction_5min INT DEFAULT 0,  -- -1=Down, 0=Neutral, 1=Up
    profit_5min DOUBLE PRECISION,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_mds_symbol_time
    ON market_data_snapshots(symbol, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_mds_created_at
    ON market_data_snapshots(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mds_asset_category
    ON market_data_snapshots(asset_category);

CREATE INDEX IF NOT EXISTS idx_mds_symbol_asset
    ON market_data_snapshots(symbol, asset_category);

CREATE INDEX IF NOT EXISTS idx_mds_timestamp
    ON market_data_snapshots(timestamp DESC);

-- Create ml_predictions table for model outputs
CREATE TABLE IF NOT EXISTS ml_predictions (
    id BIGSERIAL PRIMARY KEY,
    snapshot_id BIGINT REFERENCES market_data_snapshots(id) ON DELETE CASCADE,
    model_name TEXT NOT NULL,
    model_version TEXT,

    -- Model prediction
    predicted_direction INT DEFAULT 0,  -- -1=Down, 0=Neutral, 1=Up
    predicted_profit DOUBLE PRECISION,
    confidence DOUBLE PRECISION,

    -- Actual result (filled in after 5-15 minutes)
    actual_direction INT,
    actual_profit DOUBLE PRECISION,
    prediction_accuracy BOOLEAN,

    -- Metadata
    asset_category TEXT,
    symbol TEXT NOT NULL,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    evaluated_at TIMESTAMPTZ
);

-- Create indexes for ML table
CREATE INDEX IF NOT EXISTS idx_mlp_snapshot
    ON ml_predictions(snapshot_id);

CREATE INDEX IF NOT EXISTS idx_mlp_model
    ON ml_predictions(model_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mlp_symbol
    ON ml_predictions(symbol, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mlp_symbol_model
    ON ml_predictions(symbol, model_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mlp_asset
    ON ml_predictions(asset_category);

-- Create model_performance table for tracking accuracy
CREATE TABLE IF NOT EXISTS model_performance (
    id BIGSERIAL PRIMARY KEY,
    model_name TEXT NOT NULL,
    asset_category TEXT NOT NULL,
    symbol TEXT NOT NULL,

    total_predictions INT DEFAULT 0,
    correct_predictions INT DEFAULT 0,
    accuracy DOUBLE PRECISION DEFAULT 0,

    win_rate DOUBLE PRECISION DEFAULT 0,
    avg_profit DOUBLE PRECISION DEFAULT 0,
    sharpe_ratio DOUBLE PRECISION DEFAULT 0,

    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance tracking
CREATE INDEX IF NOT EXISTS idx_model_perf_symbol
    ON model_performance(symbol, model_name);

CREATE INDEX IF NOT EXISTS idx_model_perf_asset
    ON model_performance(asset_category);

CREATE INDEX IF NOT EXISTS idx_model_perf_model
    ON model_performance(model_name);

-- Create collection_stats table for monitoring
CREATE TABLE IF NOT EXISTS collection_stats (
    id BIGSERIAL PRIMARY KEY,
    scan_time TIMESTAMPTZ NOT NULL,
    symbols_scanned INT,
    snapshots_stored INT,
    success_count INT,
    failed_count INT,
    scan_duration_seconds INT,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for stats
CREATE INDEX IF NOT EXISTS idx_cstats_time
    ON collection_stats(scan_time DESC);

-- Add comment for documentation
COMMENT ON TABLE market_data_snapshots IS 'ML training data: 50+ indicators per symbol collected every 5 minutes';
COMMENT ON TABLE ml_predictions IS 'Model predictions with eventual outcomes for backtesting and accuracy';
COMMENT ON TABLE model_performance IS 'Aggregate performance metrics per model-symbol-asset combination';
COMMENT ON TABLE collection_stats IS 'Scanner execution statistics for monitoring and debugging';

