# 🚀 KolaBoT - Configuration Finale (3 Actions)

**Date:** 2026-05-31 13:10 UTC  
**Statut:** Fixes AWS déployés, 3 actions restantes

---

## ✅ Ce qui est Fait

1. ✅ **Code pushé** (commit `cad6bdf`)
   - AWS Transcribe chunk size : 32KB → 8KB
   - NVIDIA transcription fallback supprimé

2. ✅ **Variables AWS configurées** sur Render
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION = us-east-1`

3. ✅ **Script reset session créé**
   - `D:/Dev/TradBOT/reset_kolabot_session.py`

---

## 🎯 3 Actions à Faire MAINTENANT

### Action 1 : Mettre à Jour Clé NVIDIA (2 min) 🔴 PRIORITAIRE

**Render Dashboard → psychobot-1si7 → Environment**

1. Chercher variable : **`NVIDIA_NIM_API_KEY`**
2. Cliquer **Edit** (icône crayon)
3. Remplacer par :
   ```
   REMOVED_NVIDIA_KEY_2
   ```
4. **Save Changes**
5. Attendre redéploiement (~3 min)

**Pourquoi :** Génération réponses AI (actuellement 403 Forbidden)

---

### Action 2 : Reset Session WhatsApp (5 min) 🔴 PRIORITAIRE

**Option A : Via Script Python (Recommandé)**

```bash
cd D:/Dev/TradBOT
python reset_kolabot_session.py
```

Le script va :
1. Appeler `/new-qr` pour supprimer session corrompue
2. Afficher instructions pour scanner QR code

**Option B : Via Endpoint Direct**

1. Ouvrir navigateur : https://psychobot-1si7.onrender.com/new-qr
2. Attendre confirmation JSON
3. Ouvrir : https://psychobot-1si7.onrender.com/qr
4. Scanner QR code avec WhatsApp (+237696814391)

**Option C : Via Manual Deploy**

1. Render Dashboard → psychobot-1si7
2. **Manual Deploy** (bouton en haut à droite)
3. **Deploy latest commit**
4. Logs → Scanner QR code après démarrage

**Pourquoi :** Messages WhatsApp corrompus (Bad MAC Error)

---

### Action 3 : Ajouter Crédits OpenAI (3 min) 🟡 OPTIONNEL

**Si vous voulez un fallback en cas d'échec AWS**

1. https://platform.openai.com/account/billing/overview
2. **Add payment method**
3. **Add credits** → $5 minimum recommandé

**Pourquoi :** Fallback transcription si AWS échoue

**Alternative gratuite :** Compter uniquement sur AWS (60 min/mois gratuit)

---

## 📊 État des Services

| Service | Status | Action Requise |
|---------|--------|----------------|
| **AWS Transcribe** | 🟡 Fix déployé | Tester après redéploiement |
| **NVIDIA NIM** | 🔴 Clé invalide | **Action 1 : Mettre à jour clé** |
| **Session WhatsApp** | 🔴 Corrompue | **Action 2 : Reset session** |
| **OpenAI Whisper** | 🟡 Pas de crédits | Action 3 : Ajouter crédits (optionnel) |
| **Google TTS** | ✅ OK | Rien à faire |

---

## 🧪 Test Complet Après Config

### Étape 1 : Vérifier Status Render

**Dashboard → psychobot-1si7**

| Status | Action |
|--------|--------|
| 🟢 **Live** | Passer à l'étape 2 |
| 🟡 **Deploying** | Attendre 2-3 min |
| 🔴 **Deploy failed** | Consulter logs |

---

### Étape 2 : Tester Message Texte

**WhatsApp → +229 01 96 91 13 46**

Message :
```
Test connexion KolaBoT
```

**Résultat attendu :**
- Réponse en français, conviviale
- Signature "Assistant de Sidoine"

**Si échec :** Session encore corrompue → Refaire Action 2

---

### Étape 3 : Tester Message Vocal

**Après test texte réussi :**

Message vocal (5-10 sec) :
```
Bonjour KolaBoT, test final de transcription
```

**Résultat attendu (~15 secondes) :**

1. **Audio vocal** (réponse parlée par le bot)
2. **Message texte** :
   ```
   🎙️ Transcript:
   "Bonjour KolaBoT, test final de transcription"

   🤖 Response:
   [Réponse contextuelle en français]
   ```

---

### Étape 4 : Vérifier Logs Render

**Dashboard → Logs**

**Logs de succès AWS :**
```
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AWS Transcribe] Processing: /tmp/audio_xxx.wav
[AWS Transcribe] Success: "Bonjour KolaBoT..."
[AudioProcessor] ✓ Complete pipeline successful
```

**Logs de fallback OpenAI :**
```
[AudioProcessor] AWS failed: [error]
[AudioProcessor] Transcribing with openai...
[AudioProcessor] Transcribed (openai): "Bonjour KolaBoT..."
[AudioProcessor] ✓ Complete pipeline successful
```

---

## 🎯 Ordre d'Exécution Recommandé

### Scénario 1 : Tout Faire (15 min)

```
1. Action 1 : NVIDIA clé (2 min)
   └─ Render Environment → Edit NVIDIA_NIM_API_KEY → Save

2. Action 2 : Reset session (5 min)
   └─ python reset_kolabot_session.py → Scanner QR

3. Attendre redéploiement (3 min)
   └─ Status = "Live"

4. Test message texte (1 min)
   └─ Vérifier réponse

5. Test message vocal (2 min)
   └─ Vérifier transcription + audio

6. Action 3 : OpenAI crédits (optionnel, 3 min)
   └─ Si vous voulez fallback
```

---

### Scénario 2 : Minimum Vital (7 min)

```
1. Action 1 : NVIDIA clé (2 min)
2. Action 2 : Reset session (5 min)
3. Test → Devrait marcher avec AWS
```

---

## 🔍 Troubleshooting

### AWS Transcribe échoue encore

**Logs montrent :**
```
[AWS Transcribe] Error: Your stream is too big
```

**Cause :** Fix pas encore déployé

**Solution :**
1. Vérifier commit `cad6bdf` présent sur GitHub
2. Render → Manual Deploy → Deploy latest commit
3. Attendre "Live"

---

### NVIDIA API échoue encore (403)

**Logs montrent :**
```
NVIDIA API 403: Authorization failed
```

**Cause :** Clé pas encore mise à jour sur Render

**Solution :**
1. Render Environment → Vérifier `NVIDIA_NIM_API_KEY`
2. Si ancienne valeur → Edit → Nouvelle clé → Save
3. Attendre redéploiement

---

### Session WhatsApp refait "Bad MAC"

**Cause :** Session pas supprimée correctement

**Solution A :**
```bash
python reset_kolabot_session.py
```

**Solution B :**
1. Render Dashboard → Manual Deploy
2. Clear build cache + Deploy
3. Scanner nouveau QR code dans logs

---

### Bot ne répond toujours pas aux audios

**Vérifier dans l'ordre :**

1. **Status Render = "Live" ?**
   - Si non → Attendre

2. **Session WhatsApp connectée ?**
   - Logs : "✓ Connection successful"
   - Si non → Action 2

3. **NVIDIA clé valide ?**
   - Logs : pas de "403 Forbidden"
   - Si 403 → Action 1

4. **AWS ou OpenAI fonctionne ?**
   - Logs : "[AWS Transcribe] Success" OU "[AudioProcessor] Transcribed (openai)"
   - Si non → Ajouter crédits OpenAI (Action 3)

---

## 📱 Contacts & Liens

| Ressource | URL/Info |
|-----------|----------|
| **Bot WhatsApp** | +229 01 96 91 13 46 |
| **Propriétaire** | +237696814391 (Sidoine) |
| **Render Dashboard** | https://dashboard.render.com |
| **Endpoint /new-qr** | https://psychobot-1si7.onrender.com/new-qr |
| **Endpoint /qr** | https://psychobot-1si7.onrender.com/qr |
| **OpenAI Billing** | https://platform.openai.com/account/billing/overview |
| **NVIDIA API Keys** | https://build.nvidia.com/ |

---

## 📄 Scripts Disponibles

| Script | Description |
|--------|-------------|
| `reset_kolabot_session.py` | Reset session WhatsApp sans Shell |
| `test_kolabot_complete.py` | Test transcription + AI local |
| `send_test_message.py` | Envoyer message via API |

---

## ✅ Checklist Finale

**Configuration Render :**
- [ ] AWS_ACCESS_KEY_ID configuré
- [ ] AWS_SECRET_ACCESS_KEY configuré
- [ ] AWS_REGION = us-east-1 configuré
- [ ] NVIDIA_NIM_API_KEY mis à jour (nouvelle clé)
- [ ] OPENAI_API_KEY configuré (optionnel si AWS suffit)
- [ ] Google_api_key configuré (déjà fait)

**Actions Effectuées :**
- [ ] Action 1 : NVIDIA clé mise à jour
- [ ] Action 2 : Session WhatsApp reset + QR scanné
- [ ] Action 3 : Crédits OpenAI ajoutés (optionnel)

**Tests :**
- [ ] Status Render = "Live"
- [ ] Message texte → Réponse reçue
- [ ] Message vocal → Transcription + réponse audio reçues
- [ ] Logs montrent succès AWS ou OpenAI

---

## 🎉 Résultat Final Attendu

Après les 3 actions :

✅ **KolaBoT répond aux messages vocaux**  
✅ **Transcription automatique (AWS ou OpenAI)**  
✅ **Réponses en français, conviviales, contextuelles**  
✅ **Audio vocal généré (Google TTS)**  
✅ **Historique des conversations utilisé**  
✅ **Signature "KolaBoT" dans tous les messages**

---

**Créé le :** 2026-05-31 13:10 UTC  
**Priorité :** Actions 1 et 2 = HAUTE | Action 3 = Optionnel  
**Temps total :** 7 min (minimum) à 15 min (complet)
