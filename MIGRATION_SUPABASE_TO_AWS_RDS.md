# MIGRATION SUPABASE → AWS RDS POSTGRESQL

## 📋 Vue d'ensemble

Ce guide détaille la migration complète de la base de données de **Supabase** vers **AWS RDS PostgreSQL** pour TradBOT.

---

## 🎯 Objectifs

1. ✅ Créer toutes les tables dans AWS RDS
2. ✅ Configurer les connexions dans `.env`
3. ✅ Remplacer les appels Supabase par des connexions PostgreSQL directes
4. ✅ Tester l'intégration complète

---

## 📊 Tables à migrer

### Tables principales

| Table | Description | Enregistrements typ. |
|-------|-------------|---------------------|
| `trade_feedback` | Résultats des trades exécutés | 1000+ |
| `predictions` | Prédictions IA | 5000+ |
| `correction_predictions` | Prédictions avec corrections | 3000+ |
| `symbol_calibration` | Calibration par symbole (win rate) | 50+ |
| `model_metrics` | Métriques ML (accuracy, f1) | 100+ |
| `trades` | Historique complet des trades | 2000+ |
| `stair_detections` | Détections patterns stair | 500+ |
| `adaptive_strategies` | Stratégies adaptatives (depuis SQLite) | 20+ |
| `strategy_adjustments` | Ajustements de stratégie | 200+ |

### Vues créées

- `recent_trades` - Trades des 30 derniers jours avec statistiques
- `model_performance` - Performance ML par symbole/timeframe

### Triggers

- `trigger_update_calibration` - Met à jour automatiquement `symbol_calibration` après insertion dans `trade_feedback`

---

## 🔧 Étape 1: Configuration initiale

### 1.1 Connexion AWS RDS testée

```bash
psql "host=trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com port=5432 dbname=trading_bot user=dbadmin sslmode=require"
```

✅ **Connexion réussie** - Base `trading_bot` créée

### 1.2 Configuration des fichiers

Trois scripts ont été créés:

1. **`configure_aws_rds.py`** - Configure `.env` et crée les helpers
2. **`migrate_to_aws_rds.py`** - Crée toutes les tables dans AWS RDS
3. **`test_aws_rds_connection.py`** - Teste la connexion et les opérations

---

## 🚀 Étape 2: Exécution de la migration

### 2.1 Configurer l'environnement

```bash
cd D:\Dev\TradBOT
python configure_aws_rds.py
```

**Résultat**:
- ✅ Backup de `.env` créé
- ✅ Variables AWS RDS ajoutées à `.env`
- ✅ Module `aws_rds_helper.py` créé
- ✅ Script de test `test_aws_rds_connection.py` créé

### 2.2 Mettre à jour le mot de passe

Éditez `.env` et remplacez `YOUR_PASSWORD_HERE` par votre vrai mot de passe:

```env
AWS_RDS_HOST=trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com
AWS_RDS_PORT=5432
AWS_RDS_DATABASE=trading_bot
AWS_RDS_USER=dbadmin
AWS_RDS_PASSWORD=VOTRE_MOT_DE_PASSE_ICI
AWS_RDS_SSLMODE=require
```

### 2.3 Créer les tables

```bash
python migrate_to_aws_rds.py
```

Le script va:
1. Demander le mot de passe de manière sécurisée
2. Tester la connexion
3. Créer toutes les tables, index, vues et triggers
4. Afficher un résumé des tables créées

**Sortie attendue**:
```
============================================================
MIGRATION SUPABASE → AWS RDS POSTGRESQL
============================================================

[ÉTAPE 1] Test de connexion...
✅ Connexion réussie! PostgreSQL version: PostgreSQL 18.3...

[ÉTAPE 2] Création des tables et structures...
✅ Toutes les tables créées avec succès!

📊 Tables créées (9):
   - adaptive_strategies: 0 enregistrements
   - correction_predictions: 0 enregistrements
   - model_metrics: 0 enregistrements
   - predictions: 0 enregistrements
   - stair_detections: 0 enregistrements
   - strategy_adjustments: 0 enregistrements
   - symbol_calibration: 0 enregistrements
   - trade_feedback: 0 enregistrements
   - trades: 0 enregistrements

👁️ Vues créées (2):
   - model_performance
   - recent_trades

============================================================
✅ MIGRATION TERMINÉE AVEC SUCCÈS!
============================================================
```

### 2.4 Tester la connexion

```bash
python test_aws_rds_connection.py
```

Le script va:
1. Vérifier les variables d'environnement
2. Tester la connexion AWS RDS
3. Lister toutes les tables
4. Faire un test d'insertion/suppression

---

## 🔌 Étape 3: Intégration dans ai_server.py

### 3.1 Module aws_rds_helper.py

Le module créé fournit une API compatible avec l'ancien code Supabase:

```python
from aws_rds_helper import aws_rds_client

# Insertion
result_id = aws_rds_client.insert("trade_feedback", {
    "symbol": "Boom 300 Index",
    "profit": 0.85,
    "is_win": True,
    ...
})

# Sélection
trades = aws_rds_client.select(
    "trade_feedback",
    filters={"symbol": "Boom 300 Index"},
    limit=50,
    order_by="created_at DESC"
)

# Requête personnalisée
results = aws_rds_client.execute_query("""
    SELECT symbol, AVG(profit) as avg_profit
    FROM trade_feedback
    WHERE is_win = true
    GROUP BY symbol
""")
```

### 3.2 Remplacer les appels Supabase

Dans `ai_server.py`, remplacez:

**AVANT (Supabase)**:
```python
# Connexion Supabase
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")

# Insertion via HTTP
response = requests.post(
    f"{supabase_url}/rest/v1/trade_feedback",
    headers={"apikey": supabase_key, ...},
    json=data
)
```

**APRÈS (AWS RDS)**:
```python
from aws_rds_helper import aws_rds_client

# Insertion directe PostgreSQL
result_id = aws_rds_client.insert("trade_feedback", data)
```

### 3.3 Points d'intégration clés

Cherchez et remplacez dans `ai_server.py`:

1. **`_push_feedback_to_supabase()`** → Utiliser `aws_rds_client.insert("trade_feedback", ...)`
2. **`_push_prediction_to_supabase()`** → Utiliser `aws_rds_client.insert("predictions", ...)`
3. **`fetch_training_data_simple()`** → Utiliser `aws_rds_client.select(...)`
4. **Toutes les requêtes HTTP Supabase** → Remplacer par appels `aws_rds_client`

---

## 📝 Étape 4: Migration des données existantes (Optionnel)

Si vous avez des données dans Supabase à migrer:

### 4.1 Export depuis Supabase

```python
import requests

supabase_url = "https://your-project.supabase.co"
supabase_key = "your-key"

headers = {
    "apikey": supabase_key,
    "Authorization": f"Bearer {supabase_key}"
}

# Exporter trade_feedback
response = requests.get(
    f"{supabase_url}/rest/v1/trade_feedback?limit=10000",
    headers=headers
)

trades_data = response.json()
```

### 4.2 Import vers AWS RDS

```python
from aws_rds_helper import aws_rds_client

for trade in trades_data:
    # Supprimer 'id' pour auto-increment
    trade.pop('id', None)
    aws_rds_client.insert("trade_feedback", trade)
```

---

## 🧪 Étape 5: Tests de validation

### 5.1 Test de connexion

```bash
python test_aws_rds_connection.py
```

### 5.2 Test d'intégration ai_server.py

```python
# Tester l'enregistrement d'un trade
from aws_rds_helper import aws_rds_client

test_trade = {
    "symbol": "Boom 300 Index",
    "timeframe": "M1",
    "side": "buy",
    "open_time": "2026-05-15 18:00:00",
    "entry_price": 1500.0,
    "profit": 0.85,
    "is_win": True
}

result_id = aws_rds_client.insert("trade_feedback", test_trade)
print(f"Trade enregistré avec ID: {result_id}")

# Vérifier
trades = aws_rds_client.select(
    "trade_feedback",
    filters={"symbol": "Boom 300 Index"},
    limit=1
)
print(f"Trade récupéré: {trades[0]}")
```

### 5.3 Test adaptive_learning_system.py

Le système adaptatif peut aussi être migré vers AWS RDS:

```python
# Au lieu de SQLite local
# db_path = "D:/Dev/TradBOT/data/adaptive_learning.db"

# Utiliser AWS RDS PostgreSQL
from aws_rds_helper import aws_rds_client

# Les tables adaptive_strategies et strategy_adjustments
# sont déjà créées dans AWS RDS
```

---

## 🔒 Sécurité

### Variables d'environnement sensibles

✅ **Bon**:
```env
AWS_RDS_PASSWORD=mon_mot_de_passe_sécurisé
```

❌ **Mauvais**:
```python
# NE JAMAIS hardcoder le mot de passe
password = "mon_mot_de_passe"
```

### SSL/TLS obligatoire

```env
AWS_RDS_SSLMODE=require
```

Toutes les connexions sont chiffrées via TLS 1.3.

---

## 📊 Schéma complet de la base

### Relations entre tables

```
trade_feedback
    ↓
symbol_calibration (via trigger)

predictions
    ← model_metrics (performance)

trades
    ← stair_detections (patterns)

adaptive_strategies
    ← strategy_adjustments (historique)
```

### Index pour performance

- **`trade_feedback`**: `(symbol)`, `(created_at DESC)`, `(symbol, created_at DESC)`
- **`predictions`**: `(symbol, timeframe, created_at DESC)`
- **`model_metrics`**: `(symbol, timeframe)`, `(training_date DESC)`

---

## 🚦 Statut de la migration

| Étape | Status | Détails |
|-------|--------|---------|
| Configuration `.env` | ✅ | Variables AWS RDS ajoutées |
| Création module helper | ✅ | `aws_rds_helper.py` opérationnel |
| Script de migration | ✅ | `migrate_to_aws_rds.py` prêt |
| Création tables AWS RDS | ⏳ | **À exécuter** |
| Intégration ai_server.py | ⏳ | **Prochaine étape** |
| Migration données | ⏳ | Optionnel si Supabase vide |
| Tests validation | ⏳ | Après intégration |

---

## 📝 Checklist finale

Avant de basculer en production:

- [ ] Tables créées dans AWS RDS
- [ ] Mot de passe configuré dans `.env`
- [ ] Test connexion réussi
- [ ] `ai_server.py` mis à jour
- [ ] Tests d'insertion/sélection OK
- [ ] Trigger `update_calibration` fonctionnel
- [ ] Vues accessibles
- [ ] Backup Supabase effectué (si données)
- [ ] Données migrées (si nécessaire)
- [ ] Monitoring activé

---

## 🆘 Troubleshooting

### Erreur: "password authentication failed"

Vérifiez:
1. Mot de passe correct dans `.env`
2. User = `dbadmin` (pas `postgres`)
3. Database = `trading_bot` (pas `postgres`)

### Erreur: "connection timeout"

Vérifiez:
1. Security Group AWS autorise votre IP sur port 5432
2. SSL activé: `sslmode=require`
3. Règles firewall locales

### Erreur: "table does not exist"

1. Exécutez `python migrate_to_aws_rds.py`
2. Vérifiez la database: `trading_bot` pas `postgres`

---

## 📚 Fichiers créés

| Fichier | Description |
|---------|-------------|
| `configure_aws_rds.py` | Configuration initiale |
| `migrate_to_aws_rds.py` | Création des tables |
| `test_aws_rds_connection.py` | Tests de validation |
| `aws_rds_helper.py` | Module helper PostgreSQL |
| `.env.backup_*` | Backup automatique |

---

## 🎉 Prochaines étapes

1. **Exécuter la migration**:
   ```bash
   python migrate_to_aws_rds.py
   ```

2. **Tester**:
   ```bash
   python test_aws_rds_connection.py
   ```

3. **Intégrer dans ai_server.py**:
   - Remplacer appels Supabase
   - Tester endpoints `/trades/feedback` et `/decision`

4. **Déployer**:
   - Redémarrer `ai_server.py`
   - Vérifier les logs
   - Monitorer les performances

---

**Date de création**: 2026-05-15  
**Version**: 1.0.0  
**Status**: ✅ Documentation complète - Prêt pour exécution
