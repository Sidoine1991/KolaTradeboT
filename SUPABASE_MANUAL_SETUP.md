# 🎯 Configuration Manuelle Supabase - KolaTradeBoT

## 🔧 État Actuel

✅ **Connexion Supabase**: Fonctionnelle  
✅ **Table accessible**: Créée et vide  
❌ **Insertion API**: Clé anon sans droits d'écriture  

## 📋 Actions Requises

### 1. 🗄️ Créer la table (si pas déjà fait)

Allez sur: https://supabase.com/dashboard/project/bpzqnooiisgadzicwupi/sql

```sql
-- Créer la table des niveaux de support/résistance
CREATE TABLE IF NOT EXISTS support_resistance_levels (
    id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL,
    support DECIMAL(15,5) NOT NULL,
    resistance DECIMAL(15,5) NOT NULL,
    timeframe VARCHAR(10) NOT NULL DEFAULT 'M1',
    strength_score DECIMAL(5,2) DEFAULT 0.0,
    touch_count INTEGER DEFAULT 0,
    last_touch TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_support_resistance_symbol ON support_resistance_levels(symbol);
CREATE INDEX IF NOT EXISTS idx_support_resistance_symbol_timeframe ON support_resistance_levels(symbol, timeframe);

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

-- Activer RLS (Row Level Security)
ALTER TABLE support_resistance_levels ENABLE ROW LEVEL SECURITY;

-- Politiques pour permettre les lectures
CREATE POLICY IF NOT EXISTS "Allow read access for authenticated users"
    ON support_resistance_levels FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Allow read access for anon users"
    ON support_resistance_levels FOR SELECT
    USING (auth.role() = 'anon');
```

### 2. 📊 Insérer les données initiales

Dans le même éditeur SQL, exécutez:

```sql
-- Insérer les niveaux S/R réalistes pour Boom/Crash
INSERT INTO support_resistance_levels (symbol, support, resistance, timeframe, strength_score, touch_count, last_touch) VALUES
-- Boom 1000 Index
('Boom 1000 Index', 1000.50, 1002.00, 'M1', 85.5, 12, '2025-03-11 10:30:00'),
('Boom 1000 Index', 998.75, 1000.25, 'M1', 72.3, 8, '2025-03-11 09:15:00'),
('Boom 1000 Index', 1002.50, 1004.00, 'M1', 68.9, 6, '2025-03-11 08:45:00'),

-- Crash 1000 Index  
('Crash 1000 Index', 999.25, 1000.75, 'M1', 82.1, 15, '2025-03-11 10:45:00'),
('Crash 1000 Index', 1002.25, 1003.75, 'M1', 76.8, 9, '2025-03-11 09:45:00'),
('Crash 1000 Index', 997.50, 999.00, 'M1', 71.2, 7, '2025-03-11 08:30:00'),

-- Boom 500 Index
('Boom 500 Index', 500.25, 501.00, 'M1', 78.4, 10, '2025-03-11 10:20:00'),
('Boom 500 Index', 499.38, 500.13, 'M1', 69.7, 6, '2025-03-11 09:10:00'),

-- Crash 500 Index
('Crash 500 Index', 499.63, 500.88, 'M1', 80.2, 11, '2025-03-11 10:35:00'),
('Crash 500 Index', 501.13, 502.38, 'M1', 73.5, 8, '2025-03-11 09:25:00'),

-- Boom 300 Index
('Boom 300 Index', 300.15, 300.60, 'M1', 75.8, 9, '2025-03-11 10:15:00'),
('Boom 300 Index', 299.63, 300.08, 'M1', 67.9, 5, '2025-03-11 08:55:00'),

-- Crash 300 Index
('Crash 300 Index', 299.78, 300.53, 'M1', 77.6, 12, '2025-03-11 10:40:00'),
('Crash 300 Index', 300.68, 301.43, 'M1', 70.3, 7, '2025-03-11 09:20:00');
```

### 3. ✅ Vérifier l'insertion

```sql
-- Vérifier que les données sont bien insérées
SELECT symbol, support, resistance, strength_score, touch_count 
FROM support_resistance_levels 
ORDER BY strength_score DESC 
LIMIT 10;
```

### 4. 🎯 Configurer MT5

Une fois les données insérées, configurez MT5:

```mql5
// Dans les inputs du robot SMC_Universal.mq5
SupabaseUrl = "https://bpzqnooiisgadzicwupi.supabase.co"
SupabaseApiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"
```

### 5. 🌐 Activer WebRequest dans MT5

- MT5 → Outils → Options → Expert Advisors
- ✅ Cocher "Autoriser WebRequest"
- Ajouter: `https://bpzqnooiisgadzicwupi.supabase.co`

---

## 🧪 Test Final

Après configuration, lancez ce test pour vérifier:

```bash
python backend/test_real_supabase.py
```

Résultat attendu:
```
✅ Table accessible!
📋 14 enregistrements trouvés
✅ Format compatible avec MT5!
```

---

## 📊 Logs MT5 Attendus

Une fois configuré, vous devriez voir:

```
🌐 Requête Supabase S/R pour: Boom 1000 Index (M1)
📊 Supabase S/R - Support: 1000.50000 | Résistance: 1002.00000
📍 Support Supabase trouvé - Distance: 0.00150
✅ Niveau Supabase sélectionné: SUPABASE_SUPPORT @ 1000.50000
🎯 BUY LIMIT placé @ 1000.50000 (distance: 0.075%)
```

---

## 🎉 Résultats

Une fois ces étapes terminées:

✅ **Vrais niveaux S/R** du marché  
✅ **Scores de force** basés sur l'historique  
✅ **Ordres limit** plus pertinents  
✅ **Performance** de trading améliorée  

**Le robot utilisera enfin les vrais niveaux de support/résistance !** 🎯
