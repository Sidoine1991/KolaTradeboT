-- Événements « zone d'influence spike » envoyés par MT5 (features + labels pour futur modèle)
-- Sert de journal d'apprentissage : probas locales, prior serveur, bande prix, fenêtre countdown.

CREATE TABLE IF NOT EXISTS spike_influence_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol text NOT NULL,
  timeframe text NOT NULL DEFAULT 'M1',
  hour_utc integer NOT NULL CHECK (hour_utc >= 0 AND hour_utc <= 23),
  event_time_utc timestamptz NOT NULL DEFAULT now(),

  local_probability numeric(10, 6) NOT NULL DEFAULT 0,
  combined_score numeric(10, 6) NOT NULL DEFAULT 0,
  mass_level integer NOT NULL DEFAULT 0 CHECK (mass_level >= 0 AND mass_level <= 3),
  prior_server numeric(10, 6) NOT NULL DEFAULT 0.5,

  window_seconds integer NOT NULL DEFAULT 0,
  price_band_low numeric(20, 8) NOT NULL DEFAULT 0,
  price_band_high numeric(20, 8) NOT NULL DEFAULT 0,

  features jsonb NOT NULL DEFAULT '{}'::jsonb,
  source text NOT NULL DEFAULT 'mt5',

  spike_hit boolean,
  spike_hit_at timestamptz,

  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_spike_influence_symbol_time
  ON spike_influence_events (symbol, event_time_utc DESC);

CREATE INDEX IF NOT EXISTS idx_spike_influence_hour
  ON spike_influence_events (symbol, hour_utc, event_time_utc DESC);

ALTER TABLE spike_influence_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "spike_influence_events_service" ON spike_influence_events FOR ALL USING (true);
