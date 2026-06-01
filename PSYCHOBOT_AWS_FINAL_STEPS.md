# PsychoBot AWS Transcribe - Étapes Finales

**Date:** 2026-05-31  
**Solution:** AWS Transcribe (GRATUIT - utilise vos credentials existants)

---

## ✅ Ce qui a été fait localement

1. ✅ Fichier AWS copié → `src/services/aws-transcribe.js`
2. ✅ Dependencies installées → `@aws-sdk/client-transcribe-streaming`
3. ✅ Code modifié → `audioProcessor.js` (AWS prioritaire, OpenAI fallback)

---

## 🎯 Ce qu'il faut faire SUR RENDER (5 minutes)

### Étape 1 : Ajouter les Credentials AWS (2 min)

1. **Allez sur :** https://dashboard.render.com
2. **Service :** psychobot-1si7
3. **Cliquez :** Environment (menu gauche)
4. **Ajoutez ces 3 variables :**

```
Key: AWS_ACCESS_KEY_ID
Value: YOUR_AWS_ACCESS_KEY_ID

Key: AWS_SECRET_ACCESS_KEY  
Value: YOUR_AWS_SECRET_ACCESS_KEY

Key: AWS_REGION
Value: us-east-1
```

5. **Cliquez :** Save Changes (en bas)

---

### Étape 2 : Commit & Push le Code (3 min)

Dans le dossier PsychoBot :

```bash
cd "D:/Dev/Depot Github/Psychobot"

git add .

git commit -m "feat: AWS Transcribe integration with free tier (Bedrock credentials)"

git push origin main
```

Ou via VS Code / autre :
- Stage all changes
- Commit avec message : "feat: AWS Transcribe integration"
- Push to main

---

### Étape 3 : Attendre le Déploiement (2-3 min)

Render va **automatiquement** détecter le push et redéployer.

Sur le dashboard :
- Status : "Deploying..." → "Live"
- Attendez que "Live" apparaisse

---

### Étape 4 : Tester (1 min)

1. **WhatsApp :** +229 01 96 91 13 46
2. **Envoyer message vocal :** "Bonjour PsychoBot, test AWS"
3. **Attendre 5-15 secondes**
4. **Recevoir :** 🔊 Voice reply + transcript

---

## 🔍 Vérifier les Logs Render

Pour confirmer qu AWS fonctionne :

1. Dashboard Render → psychobot-1si7
2. Onglet "Logs"
3. **Cherchez ces lignes :**

```
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AWS Transcribe] Processing: /tmp/voice_xxx.wav
[AWS Transcribe] Success: "Bonjour PsychoBot, test AWS"
```

**Si AWS échoue, fallback automatique :**
```
[AudioProcessor] AWS failed: [error]
[AudioProcessor] Transcribing with openai...
```

---

## 💰 Coût AWS Transcribe

### Free Tier (12 mois)
```
60 minutes/mois GRATUIT
Usage typique (100 messages/mois): ~16 minutes
Coût: $0 (dans free tier)
```

### Après Free Tier
```
$0.024 per minute
100 messages/mois: $0.40/mois
1000 messages/mois: $4.00/mois
```

---

## 🎯 Logique de Fallback

Le code essaie les services dans cet ordre :

```
1. AWS Transcribe (gratuit 12 mois)
   ↓ (si échec)
2. OpenAI Whisper (si clé configurée)
   ↓ (si échec)
3. NVIDIA Canary (si clé configurée)
   ↓ (si échec)
4. Erreur + message fallback
```

**Avantage :** Résilience maximale !

---

## ✅ Checklist Finale

**Sur Render Dashboard :**
- [ ] AWS_ACCESS_KEY_ID ajouté
- [ ] AWS_SECRET_ACCESS_KEY ajouté
- [ ] AWS_REGION = us-east-1 ajouté
- [ ] Save Changes cliqué

**Dans Git :**
- [ ] Code committed
- [ ] Code pushed to main

**Déploiement :**
- [ ] Status Render = "Live"
- [ ] Logs montrent "AWS Transcribe" actif

**Test :**
- [ ] Message vocal envoyé
- [ ] Voice reply reçue
- [ ] Transcript visible

---

## 🆘 Troubleshooting

### Si AWS Transcribe échoue

**Logs montrent :**
```
[AudioProcessor] AWS Transcribe error: [message]
```

**Solutions possibles :**

1. **Credentials incorrects**
   - Vérifier AWS_ACCESS_KEY_ID sur Render
   - Vérifier AWS_SECRET_ACCESS_KEY sur Render
   - Pas d'espaces avant/après les valeurs

2. **Région incorrecte**
   - Vérifier AWS_REGION = us-east-1
   - Essayer aussi : eu-west-1, ap-southeast-1

3. **Service pas activé**
   - Vérifier que AWS Transcribe est activé sur votre compte
   - Console AWS : https://console.aws.amazon.com/transcribe

4. **Fallback fonctionne quand même**
   - Si AWS échoue mais OpenAI fonctionne → OK !
   - Vous pouvez investiguer AWS plus tard
   - Service opérationnel avec OpenAI en attendant

---

## 📊 Résumé

**Avant :**
```
❌ Transcription échouait (pas de clé OpenAI valide)
❌ Utilisateurs recevaient message d'erreur
```

**Après :**
```
✅ AWS Transcribe gratuit (12 mois free tier)
✅ Utilise credentials Bedrock existants
✅ Fallback OpenAI si AWS échoue
✅ Utilisateurs reçoivent voice replies
```

**Coût :**
```
Année 1: $0 (AWS free tier)
Année 2+: $4.80/an (ou $1.20/an si OpenAI)
```

---

## 🚀 Actions Immédiates

**MAINTENANT (5 min) :**

1. Ouvrir Render Dashboard
2. Ajouter 3 variables AWS
3. Commit + Push code
4. Attendre déploiement
5. Tester message vocal

**Temps total : 5-10 minutes**

---

## 📁 Fichiers Modifiés

```
D:/Dev/Depot Github/Psychobot/
├── src/services/
│   ├── audioProcessor.js       (✏️ Modifié - AWS prioritaire)
│   └── aws-transcribe.js       (✨ Nouveau - Code AWS)
└── package.json                (✏️ Modifié - AWS SDK ajouté)
```

---

**Prochaine étape :** Configurer les 3 variables AWS sur Render ! 🚀

---

*Guide créé : 2026-05-31 12:00 UTC*  
*Solution : AWS Transcribe avec fallback OpenAI/NVIDIA*  
*Coût : GRATUIT première année (60 min/mois free tier)*
