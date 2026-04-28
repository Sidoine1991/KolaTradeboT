-- Prediction scoring schema for structured future-candle runs

create extension if not exists pgcrypto;

create table if not exists prediction_runs (
    id uuid primary key default gen_random_uuid(),
    symbol text not null,
    timeframe text not null,
    horizon integer not null check (horizon > 0),
    model_version text not null default 'structure_v1',
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists prediction_candles (
    run_id uuid not null references prediction_runs(id) on delete cascade,
    step integer not null check (step > 0),
    candle_time bigint not null,
    open double precision not null,
    high double precision not null,
    low double precision not null,
    close double precision not null,
    confidence double precision not null default 0.5,
    phase text,
    structure_tag text,
    level_ref double precision,
    created_at timestamptz not null default now(),
    primary key (run_id, step)
);

create table if not exists prediction_outcomes (
    run_id uuid not null references prediction_runs(id) on delete cascade,
    step integer not null check (step > 0),
    actual_open double precision,
    actual_high double precision,
    actual_low double precision,
    actual_close double precision,
    direction_hit boolean,
    mae double precision,
    mape double precision,
    score double precision,
    evaluated_at timestamptz not null default now(),
    primary key (run_id, step)
);

create table if not exists symbol_prediction_score_daily (
    symbol text not null,
    timeframe text not null,
    day date not null,
    samples integer not null default 0,
    direction_hit_rate double precision not null default 0,
    avg_mae double precision not null default 0,
    score double precision not null default 0,
    updated_at timestamptz not null default now(),
    primary key (symbol, timeframe, day)
);

create index if not exists idx_prediction_runs_symbol_tf_created
    on prediction_runs(symbol, timeframe, created_at desc);

create index if not exists idx_prediction_candles_time
    on prediction_candles(candle_time);

