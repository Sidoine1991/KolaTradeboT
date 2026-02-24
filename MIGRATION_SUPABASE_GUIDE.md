# MIGRATION RENDER VERS SUPABASE - GUIDE COMPLET
# KolaTradeBoT - Base de données

## 🎯 OBJECTIF
Migrer la base de données de Render vers Supabase pour une meilleure performance et gestion.

## 📋 PRÉREQUIS

### 1. Informations Supabase (déjà configurées)
- **URL**: https://bpzqnooiisgadzicwupi.supabase.co
- **Project ID**: bpzqnooiisgadzicwupi
- **Project Name**: KolaTradeBoT
- **Publishable Key**: sb_publishable_2VWOLl6v_UU2zBp1i58lLw_CBue22fc

### 2. Variables d'environnement requises
```bash
# URL de la base de données Render (actuelle)
export RENDER_DATABASE_URL="votre_url_render_actuelle"

# Mot de passe Supabase (à récupérer depuis votre dashboard Supabase)
export SUPABASE_PASSWORD="votre_mot_de_passe_supabase"
```

## 🚀 ÉTAPES DE MIGRATION

### ÉTAPE 1: Préparation
```bash
# 1. Arrêter le serveur actuel
pkill -f ai_server.py

# 2. Créer une sauvegarde
python update_ai_server_supabase.py
```

### ÉTAPE 2: Configuration de l'environnement
```bash
# 1. Copier le fichier de configuration Supabase
cp .env.supabase .env

# 2. Éditer .env pour ajouter votre vrai mot de passe
# Remplacez VOTRE_MOT_DE_PASSE_ICI par votre mot de passe Supabase
```

### ÉTAPE 3: Migration des données
```bash
# Lancer la migration
python migrate_to_supabase.py
```

Le script va:
- ✅ Se connecter à Render (source)
- ✅ Se connecter à Supabase (destination)  
- ✅ Créer les tables dans Supabase
- ✅ Migrer les données:
  - `trade_feedback` (historique des trades)
  - `predictions` (prédictions IA)
  - `symbol_calibration` (calibration par symbole)
- ✅ Vérifier l'intégrité des données

### ÉTAPE 4: Mise à jour de la configuration
```bash
# Le script update_ai_server_supabase.py a déjà mis à jour ai_server.py
# Vérifiez que les modifications sont correctes
git diff ai_server.py
```

### ÉTAPE 5: Redémarrage avec Supabase
```bash
# Activer l'environnement virtuel et lancer
source .venv/bin/activate  # ou .venv\Scripts\activate sur Windows
python ai_server.py
```

## 📊 TABLES MIGRÉES

### 1. trade_feedback
```sql
CREATE TABLE trade_feedback (
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
```

### 2. predictions
```sql
CREATE TABLE predictions (
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
```

### 3. symbol_calibration
```sql
CREATE TABLE symbol_calibration (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT DEFAULT 'M1',
    wins INTEGER DEFAULT 0,
    total INTEGER DEFAULT 0,
    drift_factor DECIMAL(10,6) DEFAULT 1.0,
    last_updated TIMESTAMPTZ DEFAULT now(),
    metadata JSONB
);
```

## 🔧 AVANTAGES DE SUPABASE

### ✅ Avantages par rapport à Render
- **Performance**: Base de données dédiée
- **Scalabilité**: Montée en charge automatique
- **API REST**: API intégrée pour les requêtes
- **Real-time**: WebSocket en temps réel
- **Authentification**: Système d'auth intégré
- **Stockage**: 1GB inclus (vs limité sur Render)
- **Backup**: Sauvegardes automatiques

### 📈 Améliorations pour KolaTradeBoT
- **Accès plus rapide** aux données de feedback
- **Meilleure gestion** des prédictions historiques
- **API directe** pour dashboard web futur
- **Real-time updates** possibles

## 🛠️ DÉPANNAGE

### Erreur: "SUPABASE_PASSWORD non défini"
```bash
export SUPABASE_PASSWORD="votre_vrai_mot_de_passe"
```

### Erreur: "Connexion échouée"
- Vérifiez le mot de passe dans le dashboard Supabase
- Assurez-vous que l'URL est correcte
- Vérifiez la connexion internet

### Erreur: "Table n'existe pas"
- Le script de migration crée automatiquement les tables
- Vérifiez les permissions sur Supabase

### Pour vérifier la migration
```sql
-- Dans Supabase SQL Editor
SELECT COUNT(*) FROM trade_feedback;
SELECT COUNT(*) FROM predictions;
SELECT COUNT(*) FROM symbol_calibration;
```

## 📝 POST-MIGRATION

### 1. Validation
```bash
# Vérifier que le serveur fonctionne avec Supabase
curl http://localhost:8000/health
```

### 2. Monitoring
- Les logs indiqueront "Mode Supabase activé"
- Vérifiez la connexion à la base dans les logs

### 3. Backup
- Conservez le fichier `ai_server_render_backup.py`
- Gardez une copie de l'ancienne base Render

## 🎉 VALIDATION FINALE

Après migration, vous devriez voir:
```
✅ Connecté à la base de données Supabase
✅ Mode Supabase activé - Utilisation des dossiers temporaires
✅ Table trade_feedback créée/vérifiée
✅ Pool de connexions PostgreSQL créé
```

## 📞 SUPPORT

En cas de problème:
1. Vérifiez les logs du script de migration
2. Validez les variables d'environnement
3. Consultez le dashboard Supabase
4. Contactez le support si nécessaire

---
**Migration préparée pour KolaTradeBoT - 2026**
**Base de données: Render → Supabase**
