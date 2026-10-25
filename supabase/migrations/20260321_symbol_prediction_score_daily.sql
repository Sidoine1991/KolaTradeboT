create table if not exists public.symbol_prediction_score_daily (
  symbol text not null,
  timeframe text not null,
  day date not null,
  samples integer not null default 0,
  direction_hit_rate double precision not null default 0,
  avg_mae double precision not null default 0,
  score double precision not null default 0,
  updated_at timestamp with time zone not null default now(),
  constraint symbol_prediction_score_daily_pkey primary key (symbol, timeframe, day)
) TABLESPACE pg_default;

create index if not exists idx_symbol_prediction_score_daily_day
  on public.symbol_prediction_score_daily using btree (day desc);

create index if not exists idx_symbol_prediction_score_daily_symbol_tf
  on public.symbol_prediction_score_daily using btree (symbol, timeframe, day desc);
