# 🧪 Test KolaBoT Immédiat

**Date:** 2026-05-31 12:40 UTC  
**Objectif:** Vérifier que les variables AWS sont actives sur Render

---

## ✅ Ce que vous avez fait

1. ✅ Ajouté 3 variables AWS sur Render :
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION = us-east-1`

2. ✅ Variables supplémentaires présentes :
   - `OPENAI_API_KEY` (fallback si AWS échoue)
   - `NVIDIA_NIM_API_KEY` (pour génération réponse AI)
   - `Google_api_key` (pour text-to-speech)

---

## 🔍 Vérifier Maintenant sur Render

### Étape 1 : Status du Déploiement

**Render Dashboard → psychobot-1si7**

**Chercher le Status en haut de la page :**

| Status | Signification | Action |
|--------|---------------|--------|
| 🟢 **Live** | Déployé et actif | ✅ TESTER MAINTENANT |
| 🟡 **Deploying...** | Redéploiement en cours | ⏳ Attendre 2-3 min |
| 🔴 **Deploy failed** | Erreur de déploiement | 🔧 Consulter logs |

---

### Étape 2 : Si Status = "Live" → Test Immédiat

**Envoyer un message vocal à :**
- **Numéro WhatsApp :** +229 01 96 91 13 46
- **Message vocal (5-10 secondes) :**
  - "Bonjour KolaBoT, test final de transcription AWS"
  - OU n'importe quel message en français

**Attendre 10-15 secondes**

---

### Étape 3 : Résultat Attendu

#### ✅ Si AWS fonctionne :

**WhatsApp recevra :**
1. **Audio vocal** (réponse de KolaBoT en audio)
2. **Message texte** avec :
   ```
   🎙️ Transcript:
   "Bonjour KolaBoT, test final de transcription AWS"

   🤖 Response:
   [Réponse contextuelle en français de l'assistant]
   ```

**Logs Render montreront :**
```
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AWS Transcribe] Processing: /tmp/audio_xxx.wav
[AWS Transcribe] Success: "Bonjour KolaBoT..."
[AudioProcessor] ✓ Complete pipeline successful
```

---

#### ❌ Si AWS échoue (mais OpenAI fonctionne) :

**WhatsApp recevra quand même la réponse !**

**Logs Render montreront :**
```
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AudioProcessor] AWS failed: [error message]
[AudioProcessor] Transcribing with openai...
[AudioProcessor] Transcribed (openai): "Bonjour KolaBoT..."
[AudioProcessor] ✓ Complete pipeline successful
```

---

#### 🔴 Si TOUT échoue :

**WhatsApp recevra :**
```
❌ Erreur lors du traitement de l'audio:
[Audio transcription - local fallback not available]
```

**Cause :** Ni AWS, ni OpenAI, ni NVIDIA ne fonctionnent.

---

## 🎯 Comportement du Bot (Fonctionnement Normal)

Quand la transcription réussit :

### 1️⃣ Transcription Audio → Texte
AWS/OpenAI/NVIDIA transcrit votre message vocal en texte.

### 2️⃣ Génération Réponse Intelligente
Le bot (NVIDIA NIM / Llama 3.3 70B) :
- ✅ Lit l'historique des conversations
- ✅ Comprend le contexte
- ✅ Répond **à votre place** de manière conviviale
- ✅ Répond **en français** (détection automatique)
- ✅ Ton chaleureux et professionnel

**Exemple :**
```
Interlocuteur : "Bonjour, je voudrais un site web pour ma startup"

KolaBoT répond à votre place :
"Bonjour Pierre ! 😊 Sidoine n'est pas disponible pour le moment, 
mais je peux déjà vous aider. Il réalise effectivement des sites web 
(React, Django, fullstack). Je lui transmets votre demande et il vous 
contactera dès que possible pour discuter de votre projet. 
Avez-vous une idée du type de site souhaité ? 💡"
```

### 3️⃣ Text-to-Speech (Google TTS)
La réponse texte est convertie en **audio vocal** (voix Google)

### 4️⃣ Envoi WhatsApp
Vous recevez :
- **Audio vocal** (réponse parlée)
- **Message texte** (transcription + réponse pour référence)

---

## 🔧 Troubleshooting Rapide

### Logs montrent "AWS_ACCESS_KEY_ID not configured"

**Cause :** Variables pas encore chargées après redéploiement

**Solution :**
1. Render Dashboard → Environment
2. Vérifier que les 3 variables AWS sont visibles
3. Si visibles mais erreur → **Redémarrer manuellement** :
   - Render Dashboard → Manual Deploy → Deploy latest commit

---

### Logs montrent "Invalid credentials"

**Cause :** Espaces ou erreur dans les valeurs AWS

**Solution :**
1. Environment → Supprimer AWS_ACCESS_KEY_ID
2. Recréer avec valeur : `REMOVED_AWS_KEY_ID` (copier-coller exact)
3. Même chose pour SECRET_KEY
4. Save Changes

---

### Bot répond mais PAS en audio (juste texte)

**Cause :** Google TTS échoue

**Logs montreront :**
```
[AudioProcessor] Google TTS error: [message]
```

**Solution :** Vérifier `Google_api_key` sur Render
- Valeur actuelle : `AIzaSyDVSo0NXkq5CiRdNn0UWyL2VMk5vgtJsoU`
- Tester sur : https://developers.google.com/maps/documentation/javascript/get-api-key

---

### Bot ne répond pas du tout

**Cause 1 :** Session WhatsApp corrompue (erreurs "Bad MAC")

**Solution :** Reconnexion WhatsApp
1. Shell Render : `rm -rf session/`
2. Shell Render : `pm2 restart psychobot-v2`
3. Logs → Scanner QR Code

**Cause 2 :** NVIDIA_NIM_API_KEY invalide

**Solution :** Vérifier clé NVIDIA sur Render Environment

---

## 📊 Récapitulatif

| Étape | Status | Action |
|-------|--------|--------|
| 1. Variables AWS ajoutées | ✅ Fait | - |
| 2. Render redéployé | ⏳ À vérifier | Dashboard Status |
| 3. Test message vocal | ⏳ Prêt | Envoyer maintenant si "Live" |
| 4. Vérification logs | ⏳ Après test | Render → Logs |

---

## 🎯 Prochaine Action IMMÉDIATE

**MAINTENANT :**

1. **Ouvrir Render Dashboard**
2. **Vérifier Status** (Live / Deploying / Failed)
3. **Si Live → Envoyer message vocal au bot**
4. **Attendre 15 secondes**
5. **Vérifier WhatsApp pour réponse audio + texte**

**Si ça marche → ✅ Terminé !**

**Si erreur → Copier les logs Render ici pour diagnostic**

---

**Temps estimé : 2 minutes de test**  
**Créé le : 2026-05-31 12:40 UTC**
