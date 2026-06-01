# PsychoBot Audio Transcription - Comparaison des Solutions

**Date:** 2026-05-31  
**Problème:** Audio transcription échoue (OPENAI_API_KEY manquant)  
**Options:** 2 solutions disponibles

---

## 🎯 Résumé Exécutif

| Critère | OpenAI Whisper | AWS Transcribe |
|---------|----------------|----------------|
| **Setup** | ⭐⭐⭐ Très simple | ⭐⭐ Moyen |
| **Coût (1ère année)** | ~$1.20/an | ✅ Gratuit |
| **Coût (long terme)** | ✅ $0.006/min | $0.024/min |
| **Fiabilité** | ⭐⭐⭐ Excellente | ⭐⭐⭐ Excellente |
| **Latence** | ⭐⭐⭐ 2-3s | ⭐⭐ 3-5s |
| **Qualité** | ⭐⭐⭐ Excellente | ⭐⭐⭐ Excellente |
| **Support FR** | ✅ Natif | ✅ Natif |
| **Recommandation** | ✅ Simple & rapide | ✅ Économique |

---

## 🔍 SOLUTION 1 : OpenAI Whisper (Recommandé pour démarrage rapide)

### ✅ Avantages
- **Setup ultra-simple** : 1 variable d'environnement
- **Temps de setup** : 5 minutes
- **Latence** : 2-3 secondes (rapide)
- **Qualité** : Excellente pour français
- **Fiabilité** : Service très stable
- **Modifications code** : Aucune (déjà intégré)

### ❌ Inconvénients
- Nécessite clé API OpenAI
- Coût après free tier (~$1/an pour usage léger)

### 💰 Coût Détaillé

**Usage typique (100 messages vocaux/mois de 10s) :**
```
Durée totale: 16.7 minutes/mois
Coût mensuel: $0.10
Coût annuel: $1.20
```

**Breakdown :**
- Prix : $0.006 per minute
- Message 10s : $0.001 (0.1 centime)
- Message 30s : $0.003 (0.3 centime)
- Message 60s : $0.006 (0.6 centime)

### 📋 Procédure d'Installation

**Temps total : 5-10 minutes**

1. **Obtenir la clé API** (2 min)
   ```
   https://platform.openai.com/api-keys
   → Create new secret key
   → Copy: sk-proj-xxx...
   ```

2. **Configurer Render** (3 min)
   ```
   https://dashboard.render.com
   → Service: psychobot-1si7
   → Environment tab
   → Add: OPENAI_API_KEY = sk-proj-xxx...
   → Save Changes
   ```

3. **Attendre redéploiement** (2-3 min)
   ```
   Render va automatiquement redéployer
   Status: "Deploying..." → "Live"
   ```

4. **Tester** (1 min)
   ```
   WhatsApp: +229 01 96 91 13 46
   Voice: "Bonjour PsychoBot, test"
   Receive: Voice reply + transcript
   ```

### 📊 Résultat Attendu

```
[AudioProcessor] Audio received: voice_123.ogg
[AudioProcessor] Converted to WAV: voice_123.wav
[OpenAI Whisper] Transcribing...
[OpenAI Whisper] Success: "Bonjour PsychoBot, test"
[NVIDIA NIM] Generating response...
[Google TTS] Creating voice reply...
[AudioProcessor] Voice reply sent ✓
Total time: 8 seconds
```

---

## 🔍 SOLUTION 2 : AWS Transcribe (Recommandé long terme)

### ✅ Avantages
- **Gratuit 12 mois** : 60 minutes/mois free tier
- **Credentials existants** : Utilise AWS Bedrock déjà configuré
- **Pas de nouvelle API** : Utilise vos credentials actuels
- **Économique** : Gratuit pendant 1 an

### ❌ Inconvénients
- Setup plus complexe (modifications code)
- Latence légèrement plus élevée (3-5s)
- Nécessite S3 bucket (pour batch mode)

### 💰 Coût Détaillé

**Première année (Free Tier) :**
```
60 minutes/mois gratuits
Usage typique: 16.7 min/mois
Coût: $0 (dans free tier)
```

**Après 12 mois :**
```
Prix: $0.024 per minute
100 messages/mois (16.7 min): $0.40/mois = $4.80/an
Versus OpenAI: $1.20/an

Note: Plus cher long terme, mais gratuit la 1ère année
```

### 📋 Procédure d'Installation

**Temps total : 15-25 minutes**

1. **Ajouter credentials AWS sur Render** (5 min)
   ```
   https://dashboard.render.com
   → Service: psychobot-1si7
   → Environment tab
   → Add 3 variables:
      AWS_ACCESS_KEY_ID = YOUR_AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY = YOUR_AWS_SECRET_ACCESS_KEY
      AWS_REGION = us-east-1
   → Save Changes
   ```

2. **Copier fichier AWS** (2 min)
   ```bash
   cp D:/Dev/TradBOT/psychobot_aws_transcribe_solution.js \
      D:/Dev/Depot\ Github/Psychobot/src/services/aws-transcribe.js
   ```

3. **Installer dépendances** (3 min)
   ```bash
   cd "D:/Dev/Depot Github/Psychobot"
   npm install @aws-sdk/client-transcribe-streaming
   npm install @aws-sdk/client-bedrock-runtime
   ```

4. **Modifier audioProcessor.js** (10 min)
   - Ajouter `require('./aws-transcribe')`
   - Créer fonction `transcribeAudio()` hybride
   - Remplacer appel OpenAI par appel AWS

5. **Commit & Push** (2 min)
   ```bash
   git add .
   git commit -m "feat: AWS Transcribe integration with OpenAI fallback"
   git push origin main
   ```

6. **Attendre redéploiement Render** (3-5 min)

7. **Tester** (1 min)
   ```
   WhatsApp: +229 01 96 91 13 46
   Voice: "Bonjour PsychoBot, test AWS"
   Check logs: "[AWS Transcribe] Success"
   ```

### 📊 Résultat Attendu

```
[AudioProcessor] Audio received: voice_123.ogg
[AudioProcessor] Converted to WAV: voice_123.wav
[Transcribe] Trying AWS Transcribe...
[AWS Transcribe] Processing: voice_123.wav
[AWS Transcribe] Language: fr-FR
[AWS Transcribe] Success: "Bonjour PsychoBot, test AWS"
[NVIDIA NIM] Generating response...
[Google TTS] Creating voice reply...
[AudioProcessor] Voice reply sent ✓
Total time: 10 seconds
```

**Si AWS échoue, fallback automatique :**
```
[Transcribe] AWS failed, trying OpenAI fallback...
[OpenAI Whisper] Success: "Bonjour PsychoBot, test AWS"
```

---

## 🎯 Recommandation Stratégique

### Option 1 : Démarrage Rapide (5-10 min)
```
1. Configurer OpenAI Whisper MAINTENANT
2. Tester et valider fonctionnement
3. Migration AWS Transcribe PLUS TARD (optionnel)
```

**Avantages :**
- ✅ Solution immédiate (5 min)
- ✅ Zéro modification code
- ✅ Très fiable
- ✅ Coût négligeable (~$1/an)

**Pour qui :**
- Besoin urgent de faire fonctionner audio
- Usage prévu < 1000 messages/mois
- Préférence simplicité vs. optimisation coût

---

### Option 2 : Approche Hybride (15-25 min)
```
1. Configurer OpenAI Whisper D'ABORD (fallback)
2. Implémenter AWS Transcribe
3. AWS essaie en premier, OpenAI en backup
```

**Avantages :**
- ✅ Gratuit 12 mois (AWS free tier)
- ✅ Fallback fiable (OpenAI)
- ✅ Pas d'interruption service
- ✅ Meilleure résilience

**Pour qui :**
- Temps disponible pour setup
- Veut optimiser coûts
- Préfère solution robuste

---

## 📊 Comparaison Coûts Long Terme

### Scénario : 500 messages vocaux/mois (10s moyenne)

**Année 1 :**
```
OpenAI Whisper:  $5.00
AWS Transcribe:  $0 (free tier)
Économie:        -$5.00 avec AWS
```

**Année 2-5 (après free tier) :**
```
OpenAI Whisper:  $5.00/an
AWS Transcribe:  $20.00/an
Économie:        +$15.00/an avec OpenAI
```

**Conclusion :**
- **Court terme (12 mois)** : AWS gagnant (gratuit)
- **Long terme (2-5 ans)** : OpenAI gagnant (4x moins cher)

---

## ✅ Décision Finale : Quelle Solution Choisir ?

### Choisir OpenAI Whisper SI :
- ✅ Vous voulez une solution **maintenant** (5 min setup)
- ✅ Vous préférez la **simplicité**
- ✅ Le coût de **$1-5/an** est acceptable
- ✅ Vous voulez **zéro modification code**
- ✅ Vous privilégiez **fiabilité** et **rapidité**

### Choisir AWS Transcribe SI :
- ✅ Vous avez **15-25 min** disponibles
- ✅ Vous voulez **0 coût la 1ère année**
- ✅ Vous êtes à l'aise avec **modifications code**
- ✅ Vous prévoyez **gros volume** (> 1000 msg/mois)
- ✅ Vous voulez une **solution hybride robuste**

---

## 🚀 Action Immédiate Recommandée

### Plan Rapide (Recommandé) :

**Phase 1 : OpenAI (Aujourd'hui - 5 min)**
```
✅ Configurer OpenAI Whisper
✅ Tester fonctionnement
✅ Valider avec utilisateurs
Duration: 5-10 minutes
```

**Phase 2 : AWS (Optionnel - Plus tard)**
```
⏳ Implémenter AWS Transcribe
⏳ Tester fallback hybride
⏳ Mesurer performance
Duration: 15-25 minutes
```

**Avantage :** Service opérationnel en 5 min, optimisation plus tard si nécessaire.

---

## 📁 Fichiers de Référence

**OpenAI Solution :**
- `PSYCHOBOT_FIX_INSTRUCTIONS.txt` — Guide OpenAI simple
- `PSYCHOBOT_AUDIO_ISSUE_DIAGNOSIS.md` — Diagnostic complet

**AWS Solution :**
- `PSYCHOBOT_AWS_MIGRATION_GUIDE.md` — Guide AWS détaillé
- `psychobot_aws_transcribe_solution.js` — Code AWS
- `deploy_psychobot_aws.sh` — Script déploiement

**Comparaison :**
- `PSYCHOBOT_SOLUTION_COMPARISON.md` — Ce document

---

## 🎯 TL;DR (Résumé Ultra-Court)

**Problème :** Audio transcription ne fonctionne pas  
**Cause :** Aucune clé API configurée  

**Solution Rapide :** OpenAI Whisper (5 min, $1/an)  
**Solution Économique :** AWS Transcribe (20 min, gratuit 1 an)  

**Recommandation :** Commencer avec OpenAI (simple), migrer vers AWS plus tard (optionnel).

---

**Prochaine action :**
1. Choisir une solution
2. Suivre le guide correspondant
3. Tester avec message vocal
4. Valider fonctionnement

---

*Document créé : 2026-05-31 11:40 UTC*  
*Décision recommandée : OpenAI Whisper (setup rapide)*  
*Migration AWS : Optionnelle (optimisation future)*
