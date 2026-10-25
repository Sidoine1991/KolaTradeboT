# Instructions pour créer les tables de métriques dans Supabase

## Étape 1: Accéder au Dashboard Supabase

1. Allez sur https://supabase.com/dashboard
2. Connectez-vous avec vos identifiants
3. Sélectionnez le projet "KolaTradeBoT"

## Étape 2: Ouvrir l'éditeur SQL

1. Dans le menu de gauche, cliquez sur "SQL Editor"
2. Cliquez sur "New query" pour créer une nouvelle requête

## Étape 3: Copier-coller le SQL suivant

```sql
-- Créer la table des métriques de modèles
CREATE TABLE IF NOT EXISTS model_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol VARCHAR(50) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    model_type VARCHAR(50) NOT NULL DEFAULT 'random_forest',
    accuracy DECIMAL(10,6) NOT NULL,
    f1_score DECIMAL(10,6) NOT NULL,
    training_samples INTEGER NOT NULL,
    training_date TIMESTAMP WITH TIME ZONE NOT NULL,
    feature_importance JSONB,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_model_metrics_symbol_timeframe ON model_metrics(symbol, timeframe);
CREATE INDEX IF NOT EXISTS idx_model_metrics_training_date ON model_metrics(training_date DESC);

-- Table pour le suivi des performances en temps réel
CREATE TABLE IF NOT EXISTS model_performance_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_key VARCHAR(100) NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    prediction_count INTEGER DEFAULT 0,
    correct_predictions INTEGER DEFAULT 0,
    accuracy REAL DEFAULT 0.0,
    profit_loss DECIMAL(15,6) DEFAULT 0.0,
    log_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour les logs de performance
CREATE INDEX IF NOT EXISTS idx_model_performance_log_model_key ON model_performance_log(model_key);
CREATE INDEX IF NOT EXISTS idx_model_performance_log_date ON model_performance_log(log_date DESC);
```

## Étape 4: Exécuter la requête

1. Cliquez sur le bouton "Run" (ou appuyez sur Ctrl+Entrée)
2. Attendez la confirmation que les tables ont été créées

## Étape 5: Vérifier les tables

1. Dans le menu de gauche, cliquez sur "Table Editor"
2. Vous devriez voir les nouvelles tables:
   - `model_metrics`
   - `model_performance_log`

## Étape 6: Lancer le système d'entraînement continu

Une fois les tables créées, lancez:

```bash
cd d:\Dev\TradBOT
.venv\Scripts\activate
python continuous_ml_trainer.py
```

Le système va:
- Charger tous les modèles existants du répertoire `models/`
- Récupérer les données de trading depuis Supabase
- Réentraîner les modèles toutes les 5 minutes
- Afficher un dashboard avec les métriques en temps réel
- Sauvegarder les métriques dans Supabase

## Fonctionnalités

### 🤖 Modèles supportés
- EURUSD, GBPUSD, USDJPY (Forex)
- Boom 300/600/900 (Indices synthétiques)
- Crash 300/1000 (Indices synthétiques)
- Step Index, Volatility 75/100

### 📊 Métriques suivies
- Accuracy et F1 Score
- Importance des features
- Nombre d'échantillons d'entraînement
- Date de dernier entraînement
- Performance en temps réel

### 🔄 Entraînement continu
- Intervalles de 5 minutes (configurable)
- Minimum 100 échantillons pour réentraînement
- Sauvegarde automatique des modèles
- Dashboard en temps réel
