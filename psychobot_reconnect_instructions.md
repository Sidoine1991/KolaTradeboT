# 🔧 KolaBoT - Instructions de Reconnexion WhatsApp

**Date:** 2026-05-31  
**Problème:** Session WhatsApp corrompue (Bad MAC, PreKeyError)  
**Solution:** Reconnexion propre en supprimant les anciennes sessions

---

## 📋 Symptômes Observés

```
Bad MAC Error: Bad MAC
PreKeyError: Invalid PreKey ID
SessionError: No matching sessions found for message
```

**Cause:** Les clés de chiffrement WhatsApp ne correspondent plus entre le bot et WhatsApp.

---

## ✅ Solution : Reconnexion Propre

### Étape 1 : Supprimer les Sessions Corrompues sur Render

#### Option A : Via Shell Render (Recommandé)

1. **Allez sur Render Dashboard:**  
   https://dashboard.render.com → psychobot-1si7

2. **Ouvrez le Shell:**  
   Cliquez sur "Shell" (icône terminal en haut à droite)

3. **Commandes dans le Shell:**
   ```bash
   # Arrêter PM2 (si actif)
   pm2 stop psychobot-v2
   
   # Supprimer les sessions corrompues
   rm -rf session/
   
   # Redémarrer le bot
   pm2 restart psychobot-v2
   ```

#### Option B : Via Variables d'Environnement (Alternative)

1. Dashboard Render → psychobot-1si7 → Environment
2. Ajouter une variable temporaire :
   ```
   FORCE_REAUTH = true
   ```
3. Save Changes → Attendre redéploiement
4. Après reconnexion, **supprimer cette variable**

---

### Étape 2 : Scanner le QR Code

Après suppression du dossier `session/` :

1. **Ouvrir les logs Render :**  
   Dashboard → psychobot-1si7 → Logs

2. **Chercher le QR Code ASCII :**  
   Vous verrez un QR code dessiné en ASCII art dans les logs :
   ```
   ▄▄▄▄▄▄▄ ▄▄▄ ▄▄▄▄▄▄▄
   █ ▄▄▄ █ ███ █ ▄▄▄ █
   █ ███ █ ▄▄▄ █ ███ █
   ```

3. **Scanner avec WhatsApp :**
   - Ouvrir WhatsApp sur le téléphone de Sidoine (+237696814391)
   - Menu ⋮ → Appareils connectés → Connecter un appareil
   - Scanner le QR code affiché dans les logs Render

---

### Étape 3 : Vérifier la Connexion

#### Dans les logs Render :
```
✓ Connection successful
✓ Bot ready: 22996911346
✓ Listening for messages
```

#### Test message :
Envoyer un message texte simple au bot :
```
Test connexion
```

Le bot devrait répondre maintenant !

---

## 🎙️ Test Audio Après Reconnexion

Une fois la session stable :

1. **Envoyer un message vocal court (5-10 secondes)**
2. **Attendre 10-15 secondes**
3. **Recevoir :**
   - Transcription du message
   - Réponse AI en audio

---

## 🔍 Vérifier le Bon Fonctionnement

### Logs à surveiller :

**✅ Connexion réussie :**
```
[AudioProcessor] Downloading audio...
[AudioProcessor] Audio downloaded: /tmp/audio_xxx.ogg
[AudioProcessor] Converted to WAV: /tmp/audio_xxx.wav
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AWS Transcribe] Success: "Bonjour KolaBoT..."
[AudioProcessor] ✓ Complete pipeline successful
```

**❌ Erreurs de session (nécessite reconnexion) :**
```
Bad MAC Error: Bad MAC
PreKeyError: Invalid PreKey ID
SessionError: No matching sessions found
```

---

## 🛠️ Troubleshooting

### Si le QR Code n'apparaît pas dans les logs

**Cause :** Le dossier `session/` existe encore

**Solution :**
1. Shell Render → `rm -rf session/`
2. Shell Render → `pm2 restart psychobot-v2`
3. Attendre 30 secondes
4. Rafraîchir les logs

---

### Si les messages audio ne sont toujours pas traités

**Vérifier les 3 variables AWS sur Render :**

```
AWS_ACCESS_KEY_ID = REMOVED_AWS_KEY_ID
AWS_SECRET_ACCESS_KEY = REMOVED_AWS_SECRET
AWS_REGION = us-east-1
```

**Sans ces variables :**
- AWS Transcribe ne fonctionnera pas
- Le bot utilisera OpenAI (si clé valide) ou NVIDIA en fallback

**Logs sans AWS :**
```
[AudioProcessor] Trying AWS Transcribe (free tier)...
[AudioProcessor] AWS failed: AWS_ACCESS_KEY_ID not configured
[AudioProcessor] Transcribing with openai...
```

---

## 📊 Récapitulatif

| Étape | Action | Durée |
|-------|--------|-------|
| 1 | Shell Render → `rm -rf session/` | 1 min |
| 2 | Scanner QR code depuis logs | 2 min |
| 3 | Tester message texte | 30 sec |
| 4 | Configurer AWS (optionnel) | 3 min |
| 5 | Tester message vocal | 1 min |

**Temps total : ~7 minutes**

---

## 🎯 Résultat Attendu

Après reconnexion :

✅ Messages texte traités  
✅ Messages vocaux transcrits (AWS/OpenAI/NVIDIA)  
✅ Réponses vocales générées  
✅ Signature "KolaBoT" dans les messages  
✅ Plus d'erreurs "Bad MAC" ou "PreKeyError"

---

## 📱 Contacts

**Bot WhatsApp :** +229 01 96 91 13 46  
**Propriétaire :** +237696814391 (Sidoine)  
**Render Dashboard :** https://dashboard.render.com

---

**Créé le :** 2026-05-31 11:15 UTC  
**Auteur :** Claude Code (TradBOT)
