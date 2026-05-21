-- Table pour le feedback loop des prédictions M15
-- Chaque bougie M15 : prédiction enregistrée + résultat (hit/miss) après clôture
-- Ces données servent à réentraîner GetPriceDirection() dans l'EA

CREATE TABLE IF NOT EXISTS m15_prediction_log (
    id              BIGSERIAL PRIMARY KEY,
    pred_id         TEXT NOT NULL UNIQUE,        -- symbole + timestamp bougie
    symbol          TEXT NOT NULL,
    direction       TEXT NOT NULL,               -- UP | DOWN | CONSOLIDATE
    target_price    DOUBLE PRECISION,            -- prix cible prédit
    probability     DOUBLE PRECISION,            -- confiance 0-100%
    price_at_prediction DOUBLE PRECISION,        -- prix au moment de la prédiction
    bar_open_time   TIMESTAMPTZ,                 -- ouverture de la bougie M15
    reasoning       TEXT,                        -- indicateurs ayant conduit à la prédiction
    outcome         TEXT,                        -- 'hit' | 'miss' | NULL (en attente)
    price_at_close  DOUBLE PRECISION,            -- prix à la clôture de la bougie
    hit             BOOLEAN,                     -- true si le prix a atteint la cible
    direction_ok    BOOLEAN,                     -- true si la direction était correcte
    ts              DOUBLE PRECISION,            -- unix timestamp création
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_m15_pred_symbol    ON m15_prediction_log(symbol);
CREATE INDEX IF NOT EXISTS idx_m15_pred_direction ON m15_prediction_log(direction);
CREATE INDEX IF NOT EXISTS idx_m15_pred_hit       ON m15_prediction_log(hit);
CREATE INDEX IF NOT EXISTS idx_m15_pred_created   ON m15_prediction_log(created_at DESC);

-- Vue pour les statistiques de précision par symbole
CREATE OR REPLACE VIEW m15_prediction_accuracy AS
SELECT
    symbol,
    COUNT(*)                                          AS total,
    COUNT(*) FILTER (WHERE hit = true)                AS hits,
    COUNT(*) FILTER (WHERE direction_ok = true)       AS direction_correct,
    ROUND(AVG(CASE WHEN hit = true THEN 1.0 ELSE 0.0 END) * 100, 1)
                                                      AS hit_rate_pct,
    ROUND(AVG(CASE WHEN direction_ok = true THEN 1.0 ELSE 0.0 END) * 100, 1)
                                                      AS direction_rate_pct,
    AVG(probability)                                  AS avg_confidence,
    MAX(created_at)                                   AS last_prediction
FROM m15_prediction_log
WHERE outcome IS NOT NULL
GROUP BY symbol
ORDER BY total DESC;
