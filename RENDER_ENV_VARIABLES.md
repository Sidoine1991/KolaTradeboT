# VARIABLES D'ENVIRONNEMENT RENDER POUR AI_SERVER.PY

## 📋 Vue d'ensemble

Ce guide liste **toutes** les variables d'environnement nécessaires pour déployer `ai_server.py` sur Render avec connexion à AWS RDS PostgreSQL.

---

## 🔑 Variables AWS RDS (OBLIGATOIRES)

Ces variables permettent à Render de se connecter à votre base de données AWS RDS PostgreSQL.

```bash
AWS_RDS_HOST=trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com
AWS_RDS_PORT=5432
AWS_RDS_DATABASE=trading_bot
AWS_RDS_USER=dbadmin
AWS_RDS_PASSWORD=REMOVED_DB_PASSWORD
AWS_RDS_SSLMODE=require
```

### URL de connexion complète (alternative)

Si votre code utilise `DATABASE_URL`, vous pouvez aussi définir:

```bash
DATABASE_URL=postgresql://dbadmin:REMOVED_DB_PASSWORD@trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com:5432/trading_bot?sslmode=require
```

---

## ⚙️ Variables de configuration serveur (OBLIGATOIRES)

```bash
# Mode production
ENVIRONMENT=production

# Désactiver Supabase (on utilise AWS RDS)
USE_SUPABASE=false
SUPABASE_ENABLED=false

# Render détecte automatiquement qu'il est sur Render
RENDER=true

# Port (Render le définit automatiquement, mais vous pouvez le forcer)
PORT=8000
```

---

## 🤖 Variables IA et ML (OBLIGATOIRES)

### Ollama (LLM local)

```bash
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=qwen2.5:0.5b
```

**Note**: Si Ollama n'est pas disponible sur Render, le système utilisera le mode dégradé automatiquement.

### Dossier des modèles ML

```bash
MODELS_DIR=/tmp/models
DATA_DIR=/tmp/data
```

**Important**: Sur Render, utilisez `/tmp` car c'est le seul dossier accessible en écriture.

---

## 🔐 Variables API externes (OPTIONNELLES)

### OpenAI (si vous utilisez GPT pour l'analyse)

```bash
OPENAI_API_KEY=sk-your-openai-api-key-here
```

### Anthropic Claude (si vous utilisez Claude)

```bash
ANTHROPIC_API_KEY=your-anthropic-api-key-here
```

### Groq (LLM rapide)

```bash
GROQ_API_KEY=your-groq-api-key-here
```

---

## 📊 Variables de base de données (OPTIONNELLES)

### Supabase (ancien système, garder pour fallback)

```bash
SUPABASE_URL=https://bpzqnooiisgadzicwupi.supabase.co
SUPABASE_SERVICE_KEY=your-supabase-service-key
SUPABASE_ANON_KEY=your-supabase-anon-key
```

**Note**: Ces variables ne sont plus nécessaires si vous utilisez uniquement AWS RDS, mais elles servent de fallback en cas de problème.

---

## 🎯 Variables trading (OPTIONNELLES)

### Système d'apprentissage adaptatif

```bash
ADAPTIVE_LEARNING_ENABLED=true
ADAPTIVE_DB_PATH=/tmp/data/adaptive_learning.db
```

### Proxy model_metrics

```bash
AI_ENABLE_MODEL_METRICS_PROXY_FROM_PREDICTIONS=false
```

**Note**: Désactivé par défaut pour éviter d'écraser les vraies métriques ML.

---

## 🚀 Comment configurer sur Render

### Étape 1: Accéder aux variables d'environnement

1. Connectez-vous à [Render Dashboard](https://dashboard.render.com)
2. Sélectionnez votre service `ai-server` (ou `tradbot-ai`)
3. Cliquez sur **Environment** dans le menu de gauche

### Étape 2: Ajouter les variables

Pour chaque variable ci-dessus:

1. Cliquez sur **Add Environment Variable**
2. Entrez la **Key** (nom de la variable)
3. Entrez la **Value** (valeur de la variable)
4. Cliquez sur **Save Changes**

### Étape 3: Sauvegarder et redémarrer

1. Après avoir ajouté toutes les variables, cliquez sur **Save Changes** en haut de la page
2. Render redémarrera automatiquement votre service pour appliquer les nouvelles variables

---

## 📋 Liste des variables par priorité

### ⚠️ CRITIQUES (Sans elles, le serveur ne démarre pas)

```bash
AWS_RDS_HOST
AWS_RDS_PORT
AWS_RDS_DATABASE
AWS_RDS_USER
AWS_RDS_PASSWORD
AWS_RDS_SSLMODE
USE_SUPABASE=false
ENVIRONMENT=production
MODELS_DIR=/tmp/models
DATA_DIR=/tmp/data
```

### ✅ IMPORTANTES (Fonctionnalités principales)

```bash
OLLAMA_HOST
OLLAMA_MODEL
ADAPTIVE_LEARNING_ENABLED
RENDER=true
```

### 🔧 OPTIONNELLES (Améliorations)

```bash
OPENAI_API_KEY
ANTHROPIC_API_KEY
GROQ_API_KEY
SUPABASE_URL
SUPABASE_SERVICE_KEY
SUPABASE_ANON_KEY
AI_ENABLE_MODEL_METRICS_PROXY_FROM_PREDICTIONS
```

---

## 🔍 Vérification des variables

Après avoir configuré les variables, vous pouvez vérifier qu'elles sont bien définies:

### Méthode 1: Logs Render

1. Allez dans l'onglet **Logs** de votre service
2. Cherchez les lignes au démarrage:

```
✅ AWS RDS PostgreSQL helper chargé
✅ Connexion AWS RDS testée avec succès
✅ Système apprentissage adaptatif initialisé: /tmp/data/adaptive_learning.db
```

### Méthode 2: Endpoint de santé

Appelez l'endpoint `/health` de votre serveur:

```bash
curl https://your-render-url.onrender.com/health
```

Réponse attendue:

```json
{
  "status": "healthy",
  "database": "aws_rds",
  "models_loaded": 36,
  "adaptive_learning": true
}
```

---

## ⚠️ Sécurité

### Variables sensibles

Ces variables contiennent des secrets et **NE DOIVENT JAMAIS** être commitées dans Git:

- `AWS_RDS_PASSWORD`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GROQ_API_KEY`
- `SUPABASE_SERVICE_KEY`
- `SUPABASE_ANON_KEY`

### Bonnes pratiques

1. ✅ **Utiliser Render Environment Variables** - Sécurisées et chiffrées
2. ✅ **Activer SSL/TLS** - `AWS_RDS_SSLMODE=require`
3. ✅ **Mots de passe forts** - Minimum 16 caractères, alphanumériques + symboles
4. ✅ **Rotation régulière** - Changer les mots de passe tous les 3-6 mois
5. ❌ **Jamais dans le code** - Ne jamais hardcoder les secrets

---

## 🐛 Troubleshooting

### Erreur: "connection refused"

**Cause**: Render ne peut pas se connecter à AWS RDS

**Solution**:
1. Vérifiez le Security Group AWS RDS
2. Autorisez les IPs de Render (ou `0.0.0.0/0` pour tout le trafic)
3. Port 5432 doit être ouvert

### Erreur: "password authentication failed"

**Cause**: Mot de passe incorrect

**Solution**:
1. Vérifiez `AWS_RDS_PASSWORD` dans Render
2. Vérifiez que le mot de passe correspond à celui dans AWS RDS
3. Pas d'espaces au début/fin du mot de passe

### Erreur: "database does not exist"

**Cause**: Base `trading_bot` n'existe pas

**Solution**:
```bash
psql "host=trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com port=5432 user=dbadmin dbname=postgres"
CREATE DATABASE trading_bot;
```

### Erreur: "ModuleNotFoundError: No module named 'aws_rds_helper'"

**Cause**: Fichier `aws_rds_helper.py` manquant

**Solution**:
1. Assurez-vous que `aws_rds_helper.py` est dans le dépôt Git
2. Redéployez sur Render

---

## 📚 Ressources

- [Render Docs - Environment Variables](https://render.com/docs/environment-variables)
- [AWS RDS Security](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.html)
- [PostgreSQL Connection Strings](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING)

---

**Date de création**: 2026-05-15  
**Version**: 1.0.0  
**Status**: ✅ Documentation complète
