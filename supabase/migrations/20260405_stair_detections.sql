-- Détections d'escalier M1 (Boom/Crash, GainX/PainX) + suivi qualité / apprentissage
-- Alimentée par l'EA (HTTP) ou le serveur IA ; outcomes mis à jour à la clôture trade.

create table if not exists stair_detections (
  id uuid primary key default gen_random_uuid(),
  client_event_id text unique,
  symbol text not null,
  category text not null default 'boomcrash',
  direction text not null check (direction in ('BUY','SELL')),
  timeframe text not null default 'M1',
  detected_at timestamptz not null default now(),

  pattern_kinds text,
  quality_score double precision,
  empirical_win_rate_at_detect double precision,

  features jsonb not null default '{}'::jsonb,

  ai_action text,
  ai_confidence double precision,

  mt5_ticket bigint,
  trade_id uuid,

  outcome text check (outcome is null or outcome in ('open','win','loss','breakeven','expired')),
  result_usd numeric(14,2),
  closed_at timestamptz,

  source text not null default 'ea',
  learning_notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_stair_detections_symbol_time
  on stair_detections (symbol, detected_at desc);

create index if not exists idx_stair_detections_symbol_dir_outcome
  on stair_detections (symbol, direction, outcome);

create index if not exists idx_stair_detections_client_event
  on stair_detections (client_event_id)
  where client_event_id is not null;

comment on table stair_detections is 'Historique des setups escalier synthétiques + résultat trade pour calibrage IA/EA';
comment on column stair_detections.pattern_kinds is 'ex: classic | early | forming | classic,forming';
comment on column stair_detections.quality_score is 'Score 0..1 (heuristique serveur ou EA)';
comment on column stair_detections.empirical_win_rate_at_detect is 'Win rate agrégé au moment de la détection (snapshot)';

-- Agrégats pour lecture rapide (PostgREST / dashboard)
create or replace view stair_quality_summary as
select
  symbol,
  direction,
  coalesce(nullif(trim(pattern_kinds), ''), 'any') as pattern_kinds,
  count(*)::bigint as closed_trades,
  count(*) filter (where outcome = 'win')::bigint as wins,
  count(*) filter (where outcome = 'loss')::bigint as losses,
  case
    when count(*) filter (where outcome in ('win','loss')) > 0 then
      round(
        (count(*) filter (where outcome = 'win'))::numeric
        / nullif(count(*) filter (where outcome in ('win','loss')), 0),
        5
      )::double precision
    else null::double precision
  end as win_rate
from stair_detections
where outcome in ('win','loss')
group by symbol, direction, coalesce(nullif(trim(pattern_kinds), ''), 'any');

alter table stair_detections enable row level security;
create policy "stair_detections_service" on stair_detections for all using (true);
