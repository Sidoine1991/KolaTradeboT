# 🔍 KolaBoT - Vérification Configuration AWS sur Render

**Date:** 2026-05-31 12:30 UTC  
**Problème:** Transcription audio échoue → fallback "[Audio transcription - local fallback not available]"

---

## 🔴 Diagnostic

Le bot a reçu l'audio mais **TOUS les services de transcription ont échoué** :

```
1. AWS Transcribe → ❌ ÉCHEC (probablement pas configuré)
2. OpenAI Whisper → ❌ ÉCHEC (clé invalide ou pas de crédits)
3. NVIDIA Canary → ❌ ÉCHEC (ou pas testé)
4. Fallback local → Message d'erreur "[Audio transcription - local fallback not available]"
```

---

## ✅ Solution : Configurer AWS sur Render (2 minutes)

### Étape 1 : Vérifier si AWS est Configuré

1. **Render Dashboard:**  
   https://dashboard.render.com

2. **Service:**  
   psychobot-1si7

3. **Onglet Environment** (menu gauche)

4. **Chercher ces 3 variables :**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`

**Si elles sont ABSENTES → C'est le problème !**

---

### Étape 2 : Ajouter les Variables AWS

Dans **Environment** → **Add Environment Variable** :

```
Key: AWS_ACCESS_KEY_ID
Value: YOUR_AWS_ACCESS_KEY_ID
```

Cliquer **Add** → Ajouter la deuxième :

```
Key: AWS_SECRET_ACCESS_KEY
Value: YOUR_AWS_SECRET_ACCESS_KEY
```

Cliquer **Add** → Ajouter la troisième :

```
Key: AWS_REGION
Value: us-east-1
```

Cliquer **Save Changes** (en bas)

---

### Étape 3 : Attendre le Redéploiement

Render va **automatiquement** redéployer le service (~2-3 minutes).

**Dashboard Status :**
```
Deploying... → Live
```

Attendre que **"Live"** apparaisse.

---

### Étape 4 : Vérifier dans les Logs

Une fois **"Live"**, ouvrir **Logs** (onglet) et envoyer un nouveau message vocal.

**Logs attendus avec AWS configuré :**
```
[AudioProcessor] Downloading audio...
[AudioProcessor] Audio downloaded: /tmp/audio_xxx.ogg (xxxxx bytes)
[AudioProcessor] Converted to WAV: /tmp/audio_xxx.wav
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AWS Transcribe] Processing: /tmp/audio_xxx.wav
[AWS Transcribe] Language: fr-FR
[AWS Transcribe] Success: "Bonjour KolaBoT, test de transcription"
[AudioProcessor] ✓ Complete pipeline successful
```

**Si AWS échoue (mais configuré) :**
```
[AudioProcessor] AWS Transcribe error: [message d'erreur]
[AudioProcessor] Transcribing with openai...
```

---

## 🔍 Si AWS Échoue Encore (après configuration)

### Erreur possible : "Credentials invalid"

**Cause :** Espaces avant/après les valeurs dans Render

**Solution :**
1. Dashboard → Environment
2. Supprimer les 3 variables AWS
3. Les recréer **sans espaces** avant/après les valeurs
4. Save Changes

---

### Erreur possible : "Service not enabled"

**Cause :** AWS Transcribe pas activé sur le compte AWS

**Solution :**
1. Console AWS : https://console.aws.amazon.com/transcribe
2. Vérifier que le service est disponible dans **us-east-1**
3. Essayer de changer la région : `AWS_REGION = eu-west-1`

---

### Erreur possible : "InvalidMediaFormat"

**Cause :** Format audio non supporté par AWS

**Vérifier les logs :**
```
[AWS Transcribe] Processing: /tmp/audio_xxx.wav
[AudioProcessor] Converted to WAV: /tmp/audio_xxx.wav
```

Si la conversion WAV échoue → Problème FFmpeg (rare sur Render).

---

## 🔄 Alternative : Utiliser OpenAI Whisper

Si AWS ne fonctionne vraiment pas, utiliser OpenAI :

### Vérifier la Clé OpenAI sur Render

**Render Dashboard → Environment → OPENAI_API_KEY**

**Clé actuelle (si présente) :**
```
YOUR_OPENAI_API_KEY
```

**Problème possible :** Clé invalide ou pas de crédits.

**Vérifier la clé :**
1. https://platform.openai.com/api-keys
2. Vérifier que la clé existe et est active
3. https://platform.openai.com/account/billing/overview
4. Vérifier les crédits : **$5 minimum recommandé**

**Si pas de crédits :**
- Ajouter des crédits sur platform.openai.com
- OU utiliser AWS Transcribe (gratuit 60 min/mois)

---

## 📊 Comparaison Services

| Service | Coût (100 msg/mois) | Configuration |
|---------|---------------------|---------------|
| **AWS Transcribe** | $0 (free tier 12 mois) | 3 variables Render |
| OpenAI Whisper | $1.00/mois | 1 variable + crédits |
| NVIDIA Canary | $0 (si free tier) | 1 variable |

**Recommandation :** AWS Transcribe (gratuit et fiable)

---

## 🎯 Checklist de Résolution

**Sur Render Dashboard :**
- [ ] AWS_ACCESS_KEY_ID ajouté
- [ ] AWS_SECRET_ACCESS_KEY ajouté
- [ ] AWS_REGION = us-east-1 ajouté
- [ ] Save Changes cliqué
- [ ] Status = "Live" (redéploiement terminé)

**Test :**
- [ ] Envoyer message vocal au bot
- [ ] Attendre 10-15 secondes
- [ ] Logs montrent "[AWS Transcribe] Success: ..."
- [ ] Recevoir transcription + réponse vocale sur WhatsApp

**Si échec AWS :**
- [ ] Vérifier logs pour erreur exacte
- [ ] Vérifier crédits OpenAI (alternative)
- [ ] Tester avec autre région AWS (eu-west-1)

---

## 🆘 Besoin d'Aide ?

**Envoyer les logs Render exactement ici :**

Chercher ces lignes dans **Logs** après avoir envoyé un audio :

```
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AWS Transcribe] Processing: ...
[AWS Transcribe] Error: ... <-- CETTE LIGNE EST IMPORTANTE
```

OU

```
[AudioProcessor] AWS failed: ... <-- CETTE LIGNE
[AudioProcessor] Transcribing with openai...
[AudioProcessor] openai failed: ... <-- CETTE LIGNE
```

Ces messages permettront de diagnostiquer le problème exact.

---

## 📝 Résumé

**Action immédiate :**
1. Render Dashboard → psychobot-1si7 → Environment
2. Ajouter 3 variables AWS (voir ci-dessus)
3. Save Changes
4. Attendre "Live" (2-3 min)
5. Envoyer nouveau message vocal
6. Vérifier logs pour "[AWS Transcribe] Success"

**Temps total : 5 minutes**

---

**Créé le :** 2026-05-31 12:30 UTC  
**Priorité :** HAUTE (bot non fonctionnel pour audio)
