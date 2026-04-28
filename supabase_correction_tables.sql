-- =============================================
-- SCRIPT SQL POUR CRÉER LES TABLES DE PRÉDICTION DES ZONES DE CORRECTION
-- À exécuter dans Supabase SQL Editor
-- =============================================

-- Table 1: Analyse des zones de correction passées
CREATE TABLE IF NOT EXISTS correction_zones_analysis (
    id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL,
    timeframe VARCHAR(20) NOT NULL,
    analysis_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Statistiques des corrections analysées
    total_corrections_analyzed INTEGER,
    uptrend_corrections INTEGER,
    downtrend_corrections INTEGER,
    
    -- Retracements moyens et maximums
    avg_retracement_uptrend DECIMAL(10,4),
    avg_retracement_downtrend DECIMAL(10,4),
    max_retracement_uptrend DECIMAL(10,4),
    max_retracement_downtrend DECIMAL(10,4),
    
    -- Patterns de correction
    gradual_retracement_patterns INTEGER,
    consolidation_patterns INTEGER,
    sharp_reversal_patterns INTEGER,
    
    -- Niveaux clés identifiés (JSON arrays)
    support_levels JSONB,
    resistance_levels JSONB,
    
    -- Métadonnées
    current_price DECIMAL(15,5),
    current_trend VARCHAR(10), -- UP, DOWN, SIDEWAYS
    volatility_level DECIMAL(10,4),
    
    -- Index pour performances
    INDEX idx_correction_symbol_date (symbol, analysis_date),
    INDEX idx_correction_trend (current_trend),
    INDEX idx_correction_analysis_date (analysis_date)
);

-- Table 2: Prédictions des futures zones de correction
CREATE TABLE IF NOT EXISTS correction_predictions (
    id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL,
    timeframe VARCHAR(20) NOT NULL,
    prediction_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Données de contexte
    current_price DECIMAL(15,5) NOT NULL,
    current_trend VARCHAR(10) NOT NULL, -- UP, DOWN, SIDEWAYS
    prediction_confidence DECIMAL(5,2), -- Pourcentage de confiance (0-100)
    
    -- Zones de correction prédites (3 niveaux)
    zone_1_level DECIMAL(15,5), -- 60% du retracement moyen
    zone_1_type VARCHAR(10), -- SUPPORT, RESISTANCE
    zone_1_probability DECIMAL(5,2), -- Probabilité d'atteinte
    
    zone_2_level DECIMAL(15,5), -- 100% du retracement moyen  
    zone_2_type VARCHAR(10),
    zone_2_probability DECIMAL(5,2),
    
    zone_3_level DECIMAL(15,5), -- 140% du retracement moyen
    zone_3_type VARCHAR(10),
    zone_3_probability DECIMAL(5,2),
    
    -- Facteurs d'ajustement
    trend_strength_factor DECIMAL(5,2), -- Ajustement selon force tendance
    volatility_adjustment DECIMAL(5,2), -- Ajustement selon volatilité
    historical_accuracy DECIMAL(5,2), -- Précision historique pour ce symbole
    
    -- Résultats réels (pour apprentissage continu)
    zone_1_reached BOOLEAN DEFAULT NULL,
    zone_2_reached BOOLEAN DEFAULT NULL,
    zone_3_reached BOOLEAN DEFAULT NULL,
    actual_retracement_level DECIMAL(15,5) DEFAULT NULL,
    prediction_accuracy DECIMAL(5,2) DEFAULT NULL, -- Calculé après réalisation
    
    -- Timestamps pour suivi
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    prediction_valid_until TIMESTAMP WITH TIME ZONE, -- Validité de la prédiction
    
    -- Index pour performances
    INDEX idx_prediction_symbol_date (symbol, prediction_date),
    INDEX idx_prediction_trend (current_trend),
    INDEX idx_prediction_confidence (prediction_confidence),
    INDEX idx_prediction_valid (prediction_valid_until),
    INDEX idx_prediction_created (created_at)
);

-- Table 3: Historique des performances du système de prédiction
CREATE TABLE IF NOT EXISTS prediction_performance (
    id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL,
    performance_date DATE NOT NULL,
    
    -- Statistiques de performance journalières
    total_predictions INTEGER,
    successful_predictions INTEGER,
    failed_predictions INTEGER,
    
    -- Précision par type de prédiction
    zone_1_accuracy DECIMAL(5,2),
    zone_2_accuracy DECIMAL(5,2),
    zone_3_accuracy DECIMAL(5,2),
    
    -- Précision globale
    overall_accuracy DECIMAL(5,2),
    avg_confidence DECIMAL(5,2),
    
    -- Métadonnées
    total_corrections_analyzed INTEGER,
    avg_retracement_used DECIMAL(10,4),
    market_volatility DECIMAL(10,4),
    
    -- Index
    INDEX idx_performance_symbol_date (symbol, performance_date),
    INDEX idx_performance_date (performance_date),
    INDEX idx_performance_accuracy (overall_accuracy)
);

-- Table 4: Patterns de correction par symbole (apprentissage)
CREATE TABLE IF NOT EXISTS symbol_correction_patterns (
    id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL,
    pattern_type VARCHAR(30) NOT NULL, -- GRADUAL, CONSOLIDATION, SHARP_REVERSAL
    
    -- Caractéristiques du pattern
    avg_retracement_percentage DECIMAL(10,4),
    typical_duration_bars INTEGER,
    success_rate DECIMAL(5,2), -- Taux de réussite historique
    
    -- Conditions favorables
    min_trend_strength DECIMAL(5,2),
    max_volatility_level DECIMAL(10,4),
    best_timeframes VARCHAR(100), -- M1,M5,H15 séparés par virgules
    
    -- Statistiques
    occurrences_count INTEGER,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Index
    INDEX idx_symbol_pattern (symbol, pattern_type),
    INDEX idx_pattern_success (success_rate),
    INDEX idx_pattern_occurrences (occurrences_count)
);

-- Créer les politiques RLS (Row Level Security) pour la sécurité
ALTER TABLE correction_zones_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE correction_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prediction_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE symbol_correction_patterns ENABLE ROW LEVEL SECURITY;

-- Politiques pour permettre l'accès à l'application
CREATE POLICY "Allow all operations on correction_zones_analysis" 
    ON correction_zones_analysis FOR ALL 
    USING (true);

CREATE POLICY "Allow all operations on correction_predictions" 
    ON correction_predictions FOR ALL 
    USING (true);

CREATE POLICY "Allow all operations on prediction_performance" 
    ON prediction_performance FOR ALL 
    USING (true);

CREATE POLICY "Allow all operations on symbol_correction_patterns" 
    ON symbol_correction_patterns FOR ALL 
    USING (true);

-- Créer des vues pour faciliter les requêtes
CREATE OR REPLACE VIEW correction_summary AS
SELECT 
    symbol,
    COUNT(*) as total_analyses,
    AVG(avg_retracement_uptrend) as avg_uptrend_retracement,
    AVG(avg_retracement_downtrend) as avg_downtrend_retracement,
    MAX(analysis_date) as last_analysis,
    AVG(volatility_level) as avg_volatility
FROM correction_zones_analysis 
GROUP BY symbol;

CREATE OR REPLACE VIEW prediction_accuracy_summary AS
SELECT 
    symbol,
    COUNT(*) as total_predictions,
    AVG(prediction_confidence) as avg_confidence,
    AVG(prediction_accuracy) as avg_accuracy,
    COUNT(CASE WHEN zone_1_reached = true THEN 1 END) as zone_1_success,
    COUNT(CASE WHEN zone_2_reached = true THEN 1 END) as zone_2_success,
    COUNT(CASE WHEN zone_3_reached = true THEN 1 END) as zone_3_success
FROM correction_predictions 
WHERE prediction_accuracy IS NOT NULL
GROUP BY symbol;

-- Créer des fonctions utilitaires pour l'apprentissage continu

-- Fonction pour mettre à jour la précision historique d'un symbole
CREATE OR REPLACE FUNCTION update_symbol_accuracy(p_symbol VARCHAR(50))
RETURNS DECIMAL(5,2) AS $$
DECLARE
    avg_accuracy DECIMAL(5,2);
BEGIN
    SELECT AVG(prediction_accuracy) 
    INTO avg_accuracy 
    FROM correction_predictions 
    WHERE symbol = p_symbol 
    AND prediction_accuracy IS NOT NULL
    AND prediction_date > CURRENT_DATE - INTERVAL '30 days';
    
    RETURN COALESCE(avg_accuracy, 0.0);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour nettoyer les anciennes prédictions (garder 90 jours)
CREATE OR REPLACE FUNCTION cleanup_old_predictions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM correction_predictions 
    WHERE created_at < CURRENT_DATE - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Créer un trigger pour mettre à jour automatiquement le champ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger aux tables pertinentes
CREATE TRIGGER update_correction_predictions_updated_at
    BEFORE UPDATE ON correction_predictions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Créer un index composite pour les requêtes fréquentes
CREATE INDEX idx_prediction_composite 
ON correction_predictions(symbol, current_trend, prediction_confidence, prediction_date);

-- Insérer des données de test (optionnel)
INSERT INTO correction_zones_analysis (
    symbol, timeframe, total_corrections_analyzed, uptrend_corrections, downtrend_corrections,
    avg_retracement_uptrend, avg_retracement_downtrend, max_retracement_uptrend, max_retracement_downtrend,
    gradual_retracement_patterns, consolidation_patterns, sharp_reversal_patterns,
    current_price, current_trend, volatility_level
) VALUES 
('Boom 500 Index', 'M1', 45, 23, 22, 2.3, 2.1, 5.8, 5.2, 15, 20, 10, 1850.250, 'UP', 0.023),
('Crash 500 Index', 'M1', 38, 18, 20, 2.1, 2.4, 5.2, 5.9, 12, 18, 8, 1840.750, 'DOWN', 0.025);

-- Afficher un résumé de la création
SELECT 
    'Tables created successfully' as status,
    table_name,
    column_names
FROM information_schema.columns 
WHERE table_name IN ('correction_zones_analysis', 'correction_predictions', 'prediction_performance', 'symbol_correction_patterns')
GROUP BY table_name, column_names
ORDER BY table_name;
