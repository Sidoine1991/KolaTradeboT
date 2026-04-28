-- Profil horaire par symbole (heures propices) - basé sur bougies M1 (source MT5)
-- Objectif: identifier les heures UTC statistiquement propices (volatilité/ATR/spike/biais)

CREATE TABLE IF NOT EXISTS symbol_hour_profile (
  symbol text NOT NULL,
  timeframe text NOT NULL DEFAULT 'M1',
  lookback_days integer NOT NULL,
  hour_utc integer NOT NULL CHECK (hour_utc >= 0 AND hour_utc <= 23),

  samples integer NOT NULL DEFAULT 0,
  atr_mean numeric(14, 6) NOT NULL DEFAULT 0,
  volatility_mean numeric(14, 8) NOT NULL DEFAULT 0,
  spike_rate numeric(8, 6) NOT NULL DEFAULT 0,
  trend_bias numeric(14, 8) NOT NULL DEFAULT 0,
  propice_score numeric(8, 6) NOT NULL DEFAULT 0,

  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT symbol_hour_profile_pkey PRIMARY KEY (symbol, timeframe, lookback_days, hour_utc)
);

CREATE INDEX IF NOT EXISTS idx_symbol_hour_profile_lookup
  ON symbol_hour_profile (symbol, timeframe, lookback_days, hour_utc);

CREATE TABLE IF NOT EXISTS symbol_hour_status (
  symbol text NOT NULL,
  timeframe text NOT NULL DEFAULT 'M1',

  now_hour_utc integer NOT NULL CHECK (now_hour_utc >= 0 AND now_hour_utc <= 23),
  propice_score numeric(8, 6) NOT NULL DEFAULT 0,
  penalty_factor numeric(8, 6) NOT NULL DEFAULT 1,
  reason text NOT NULL DEFAULT '',
  computed_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT symbol_hour_status_pkey PRIMARY KEY (symbol, timeframe)
);

CREATE INDEX IF NOT EXISTS idx_symbol_hour_status_symbol
  ON symbol_hour_status (symbol, timeframe, computed_at DESC);

-- RLS (service role)
ALTER TABLE symbol_hour_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE symbol_hour_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "symbol_hour_profile_service" ON symbol_hour_profile FOR ALL USING (true);
CREATE POLICY "symbol_hour_status_service" ON symbol_hour_status FOR ALL USING (true);

