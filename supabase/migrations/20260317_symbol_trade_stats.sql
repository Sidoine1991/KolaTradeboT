-- Stockage des stats de trades par symbole (jour + mois)
-- Source: agrégation backend sur trade_feedback (données issues MT5)

CREATE TABLE IF NOT EXISTS symbol_trade_stats (
  symbol text NOT NULL,
  period_type text NOT NULL CHECK (period_type IN ('day','month')),
  period_start date NOT NULL,
  timeframe text NOT NULL DEFAULT 'M1',

  trade_count integer NOT NULL DEFAULT 0,
  wins integer NOT NULL DEFAULT 0,
  losses integer NOT NULL DEFAULT 0,
  net_profit numeric(14, 2) NOT NULL DEFAULT 0,
  gross_profit numeric(14, 2) NOT NULL DEFAULT 0,
  gross_loss numeric(14, 2) NOT NULL DEFAULT 0,

  last_trade_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT symbol_trade_stats_pkey PRIMARY KEY (symbol, period_type, period_start, timeframe)
);

CREATE INDEX IF NOT EXISTS idx_symbol_trade_stats_period
  ON symbol_trade_stats (period_type, period_start DESC, symbol);

-- RLS (service role)
ALTER TABLE symbol_trade_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "symbol_trade_stats_service" ON symbol_trade_stats FOR ALL USING (true);

