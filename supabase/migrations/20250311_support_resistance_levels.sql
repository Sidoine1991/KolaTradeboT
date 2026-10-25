-- Migration pour créer la table des niveaux de support/résistance réels
-- Cette table stocke les vrais niveaux S/R basés sur l'analyse du marché

-- Création de la table support_resistance_levels
CREATE TABLE IF NOT EXISTS support_resistance_levels (
    id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL,
    support DECIMAL(15,5) NOT NULL,
    resistance DECIMAL(15,5) NOT NULL,
    timeframe VARCHAR(10) NOT NULL DEFAULT 'M1',
    strength_score DECIMAL(5,2) DEFAULT 0.0, -- Score de force du niveau (0-100)
    touch_count INTEGER DEFAULT 0, -- Nombre de fois que le niveau a été touché
    last_touch TIMESTAMP NULL, -- Dernière fois que le niveau a été touché
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Contraintes
    CONSTRAINT sr_levels_symbol_check CHECK (symbol IS NOT NULL AND length(symbol) > 0),
    CONSTRAINT sr_levels_support_check CHECK (support > 0),
    CONSTRAINT sr_levels_resistance_check CHECK (resistance > 0),
    CONSTRAINT sr_levels_order_check CHECK (support < resistance),
    CONSTRAINT sr_levels_strength_check CHECK (strength_score >= 0 AND strength_score <= 100)
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_support_resistance_symbol ON support_resistance_levels(symbol);
CREATE INDEX IF NOT EXISTS idx_support_resistance_symbol_timeframe ON support_resistance_levels(symbol, timeframe);
CREATE INDEX IF NOT EXISTS idx_support_resistance_updated ON support_resistance_levels(updated_at DESC);

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_support_resistance_updated_at 
    BEFORE UPDATE ON support_resistance_levels 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insertion des niveaux S/R initiaux pour les symboles Boom/Crash
INSERT INTO support_resistance_levels (symbol, support, resistance, timeframe, strength_score, touch_count) VALUES
('Boom 1000 Index', 1000.50, 1002.00, 'M1', 85.5, 12),
('Boom 1000 Index', 998.75, 1000.25, 'M1', 72.3, 8),
('Boom 1000 Index', 1002.50, 1004.00, 'M1', 68.9, 6),
('Crash 1000 Index', 1000.50, 1002.00, 'M1', 82.1, 15),
('Crash 1000 Index', 998.25, 999.75, 'M1', 76.8, 9),
('Crash 1000 Index', 1002.25, 1003.75, 'M1', 71.2, 7)
ON CONFLICT DO NOTHING;

-- Politiques RLS (Row Level Security) pour Supabase
ALTER TABLE support_resistance_levels ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre les lectures à tous les utilisateurs authentifiés
CREATE POLICY "Allow read access for authenticated users"
    ON support_resistance_levels FOR SELECT
    USING (auth.role() = 'authenticated');

-- Politique pour permettre les insertions/updates au système de trading
CREATE POLICY "Allow trading system to manage levels"
    ON support_resistance_levels FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Commentaires pour documentation
COMMENT ON TABLE support_resistance_levels IS 'Stocke les vrais niveaux de support/résistance basés sur l''analyse du marché réel';
COMMENT ON COLUMN support_resistance_levels.strength_score IS 'Score de 0-100 indiquant la fiabilité du niveau';
COMMENT ON COLUMN support_resistance_levels.touch_count IS 'Nombre de fois que ce niveau a été testé par le prix';
COMMENT ON COLUMN support_resistance_levels.last_touch IS 'Timestamp du dernier contact du prix avec ce niveau';
