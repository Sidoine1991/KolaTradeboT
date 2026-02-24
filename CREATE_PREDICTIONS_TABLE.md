# INSTRUCTIONS POUR CRÉER LA TABLE PREDICTIONS MANQUANTE

## ÉTAPE 1: Accéder au dashboard Supabase
1. Allez sur: https://supabase.com/dashboard
2. Connectez-vous avec votre compte
3. Sélectionnez le projet: KolaTradeBoT (bpzqnooiisgadzicwupi)

## ÉTAPE 2: Créer la table predictions manuellement
1. Cliquez sur "SQL Editor" dans le menu de gauche
2. Copiez et collez le SQL ci-dessous:

```sql
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
CREATE INDEX IF NOT EXISTS idx_predictions_timeframe ON predictions(timeframe);
```

3. Cliquez sur "Run" pour exécuter le SQL

## ÉTAPE 3: Vérifier la création
1. Dans le menu de gauche, cliquez sur "Table Editor"
2. Vous devriez voir la table "predictions" dans la liste
3. Cliquez sur "predictions" pour vérifier la structure

## ÉTAPE 4: Tester avec le robot
1. Redémarrez le robot MT5
2. Faites quelques requêtes de décision
3. Vérifiez que les données s'ajoutent bien dans la table predictions

## ÉTAPE 5: Vérification finale
Les 4 tables devraient maintenant être:
- ✅ trade_feedback (créée)
- ✅ predictions (à créer)
- ✅ symbol_calibration (créée)  
- ✅ ai_decisions (non nécessaire - les données sont dans predictions)

## URL de connexion:
- **Dashboard**: https://supabase.com/dashboard
- **Project**: KolaTradeBoT
- **Project ID**: bpzqnooiisgadzicwupi

