-- Table pour les zones de correction depuis Supabase
-- Créer le 2025-03-11 pour l'intégration des zones de correction

-- 1. correction_zones : zones de correction par symbole et timeframe
CREATE TABLE IF NOT EXISTS correction_zones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol text NOT NULL,
    timeframe text NOT NULL DEFAULT 'M1',
    zone_type text NOT NULL, -- 'support', 'resistance', 'premium', 'discount'
    price_level real NOT NULL,
    strength real NOT NULL DEFAULT 1.0, -- force de la zone (0.1 à 1.0)
    confidence real NOT NULL DEFAULT 0.5, -- confiance de la zone (0.0 à 1.0)
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz, -- expiration de la zone
    is_active boolean NOT NULL DEFAULT true,
    source text NOT NULL DEFAULT 'ai', -- 'ai', 'smc', 'supertrend', 'manual'
    metadata jsonb
);

CREATE INDEX IF NOT EXISTS idx_correction_zones_symbol ON correction_zones(symbol);
CREATE INDEX IF NOT EXISTS idx_correction_zones_timeframe ON correction_zones(timeframe);
CREATE INDEX IF NOT EXISTS idx_correction_zones_active ON correction_zones(is_active, expires_at);
CREATE INDEX IF NOT EXISTS idx_correction_zones_type ON correction_zones(zone_type);

-- 2. correction_zone_history : historique des zones de correction utilisées
CREATE TABLE IF NOT EXISTS correction_zone_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id uuid REFERENCES correction_zones(id) ON DELETE SET NULL,
    symbol text NOT NULL,
    zone_type text NOT NULL,
    price_level real NOT NULL,
    touched_at timestamptz NOT NULL DEFAULT now(),
    touch_price real NOT NULL,
    was_breakout boolean NOT NULL DEFAULT false,
    trade_executed boolean NOT NULL DEFAULT false,
    trade_result real, -- résultat du trade si exécuté
    metadata jsonb
);

CREATE INDEX IF NOT EXISTS idx_correction_history_symbol ON correction_zone_history(symbol);
CREATE INDEX IF NOT EXISTS idx_correction_history_touched ON correction_zone_history(touched_at DESC);

-- 3. RLS : permettre l'accès avec la clé service
ALTER TABLE correction_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE correction_zone_history ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "correction_zones_service" ON correction_zones FOR ALL USING (true);
CREATE POLICY "correction_zone_history_service" ON correction_zone_history FOR ALL USING (true);

-- Trigger pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_correction_zones_updated_at 
    BEFORE UPDATE ON correction_zones 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
