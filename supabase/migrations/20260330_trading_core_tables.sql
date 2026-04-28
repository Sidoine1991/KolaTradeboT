-- Core trading tables for SMC_Universal / AI server integration
-- - trades: journal détaillé des trades et signaux MT5
-- - daily_symbol_stats: agrégats journaliers par symbole (complément à symbol_trade_stats)
-- - symbol_config: paramètres adaptatifs par symbole / catégorie

create table if not exists trades (
  id uuid primary key default gen_random_uuid(),
  mt5_ticket bigint,
  symbol text not null,
  category text not null default 'boomcrash',
  strategy text not null,                      -- ex: OTE, OTE_IMBALANCE, PRE_OTE, SPIKE, RECOVERY
  direction text not null check (direction in ('BUY','SELL')),

  volume double precision not null,
  entry_price double precision not null,
  stop_loss double precision,
  take_profit double precision,
  close_price double precision,

  result_usd numeric(14,2),
  result_points double precision,
  risk_reward double precision,

  opened_at timestamptz not null,
  closed_at timestamptz,

  session_tag text,                            -- ex: LO, NYO, ASIA
  timeframe text default 'M1',

  ai_action text,
  ai_confidence double precision,
  ml_score double precision,

  execution_slippage_points double precision,

  context jsonb default '{}'::jsonb,

  created_at timestamptz not null default now()
);

create index if not exists idx_trades_symbol_time
  on trades(symbol, opened_at desc);

create index if not exists idx_trades_strategy
  on trades(strategy, symbol, opened_at desc);

alter table trades enable row level security;
create policy "trades_service" on trades for all using (true);

-- Daily per-symbol stats (complementary to symbol_trade_stats)
create table if not exists daily_symbol_stats (
  symbol text not null,
  trade_date date not null,
  category text not null default 'boomcrash',

  trade_count integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  net_profit numeric(14,2) not null default 0,

  max_drawdown numeric(14,2),
  max_consecutive_losses integer,

  updated_at timestamptz not null default now(),

  primary key (symbol, trade_date)
);

create index if not exists idx_daily_symbol_stats_date
  on daily_symbol_stats(trade_date desc, symbol);

alter table daily_symbol_stats enable row level security;
create policy "daily_symbol_stats_service" on daily_symbol_stats for all using (true);

-- Adaptive configuration per symbol (read by AI server / EA)
create table if not exists symbol_config (
  symbol text primary key,

  enabled boolean not null default true,
  max_open_positions integer default 1,

  min_expectancy double precision default 0.0,
  min_ai_confidence double precision default 0.55,

  max_daily_loss_usd numeric(14,2),
  max_symbol_loss_usd numeric(14,2),
  max_consecutive_losses integer,

  risk_profile text default 'balanced',

  overrides jsonb default '{}'::jsonb,

  updated_at timestamptz not null default now()
);

alter table symbol_config enable row level security;
create policy "symbol_config_service" on symbol_config for all using (true);

