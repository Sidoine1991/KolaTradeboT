# INSTRUCTIONS MANUELLES POUR CONFIGURATION SUPABASE
# KolaTradeBoT - 2026-02-20 12:44:19

## ÉTAPE 1: Accéder au dashboard Supabase
1. Allez sur: https://supabase.com/dashboard
2. Connectez-vous avec votre compte
3. Sélectionnez le projet: KolaTradeBoT (bpzqnooiisgadzicwupi)

## ÉTAPE 2: Créer les tables manuellement
1. Cliquez sur "SQL Editor" dans le menu de gauche
2. Copiez et collez le SQL ci-dessous:

```sql
-- Table trade_feedback
CREATE TABLE IF NOT EXISTS trade_feedback (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    open_time TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ,
    entry_price DECIMAL(15,5),
    exit_price DECIMAL(15,5),
    profit DECIMAL(15,5),
    ai_confidence DECIMAL(5,4),
    coherent_confidence DECIMAL(5,4),
    decision TEXT,
    is_win BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT now(),
    timeframe TEXT DEFAULT 'M1',
    side TEXT
);

CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol ON trade_feedback(symbol);
CREATE INDEX IF NOT EXISTS idx_trade_feedback_created_at ON trade_feedback(created_at DESC);

-- Table predictions
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    prediction TEXT NOT NULL,
    confidence DECIMAL(5,4),
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    model_used TEXT,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_predictions_symbol ON predictions(symbol);
CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions(created_at DESC);

-- Table symbol_calibration
CREATE TABLE IF NOT EXISTS symbol_calibration (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT DEFAULT 'M1',
    wins INTEGER DEFAULT 0,
    total INTEGER DEFAULT 0,
    drift_factor DECIMAL(10,6) DEFAULT 1.0,
    last_updated TIMESTAMPTZ DEFAULT now(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_symbol_calibration_symbol ON symbol_calibration(symbol);
CREATE UNIQUE INDEX IF NOT EXISTS idx_symbol_calibration_unique ON symbol_calibration(symbol, timeframe);
```

3. Cliquez sur "Run" pour exécuter le SQL

## ÉTAPE 3: Configurer l'environnement
1. Copiez .env.supabase vers .env:
   ```
   cp .env.supabase .env
   ```

2. Modifiez .env pour utiliser votre configuration

## ÉTAPE 4: Mettre à jour le serveur
1. Lancez la mise à jour:
   ```
   python update_ai_server_supabase.py
   ```

2. Démarrez le serveur:
   ```
   python ai_server.py
   ```

## ÉTAPE 5: Vérification
1. Testez le serveur:
   ```
   curl http://localhost:8000/health
   ```

## URL de connexion à utiliser:
- **URL**: https://bpzqnooiisgadzicwupi.supabase.co
- **Project ID**: bpzqnooiisgadzicwupi
- **Password**: Socrate2025@1991
- **Database**: postgres
- **Port**: 5432
- **Host**: aws-0-eu-central-1.pooler.supabase.com

## Format DATABASE_URL final:
```
postgresql://postgres:Socrate2025@1991@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require
```
