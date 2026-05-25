# Guide Surveillance XAUUSD avec Alertes WhatsApp

## 🎯 Objectif

Surveillance automatique du trade SELL XAUUSD avec **alertes WhatsApp instantanées** via votre PsychoBot API.

---

## 📦 Fichiers créés

1. **`Python/xauusd_whatsapp_monitor.py`** — Script de surveillance
2. **`start_xauusd_monitor.bat`** — Lanceur Windows
3. **`WHATSAPP_MONITOR_GUIDE.md`** — Ce guide

---

## 🚀 Installation

### Étape 1 : Dépendances Python

```bash
pip install requests websockets
```

### Étape 2 : Configuration API PsychoBot

Votre API : `https://psychobot-1si7.onrender.com`

**⚠️ IMPORTANT** : Vérifiez l'endpoint exact pour envoyer des messages.

Ouvrez `Python/xauusd_whatsapp_monitor.py` et modifiez la ligne ~48 :

```python
# Option 1 : Si l'endpoint est /send-message
response = requests.post(
    f"{WHATSAPP_API_URL}/send-message",
    json={"phone": phone, "message": full_message},
    timeout=10
)

# Option 2 : Si l'endpoint est /send ou /api/send
response = requests.post(
    f"{WHATSAPP_API_URL}/send",
    json={"to": phone, "body": full_message},
    timeout=10
)

# Option 3 : Si format query params
response = requests.post(
    f"{WHATSAPP_API_URL}/send?phone={phone}&message={full_message}",
    timeout=10
)
```

**Consultez la doc de votre PsychoBot pour connaître le format exact.**

---

## ⚙️ Configuration

### 1. Modifier le fichier batch

Ouvrez `start_xauusd_monitor.bat` et changez :

```batch
REM Votre numéro WhatsApp (format international)
SET PHONE_NUMBER=+33612345678

REM Intervalle entre checks (en secondes)
SET INTERVAL=600
```

**Format numéro** :
- France : `+33612345678` (sans espaces)
- Belgique : `+32470123456`
- Suisse : `+41791234567`

---

## 🎬 Lancement

### Option 1 : Double-clic

1. Double-cliquer sur `start_xauusd_monitor.bat`
2. Une fenêtre CMD s'ouvre
3. Le script tourne en background
4. **Laissez la fenêtre ouverte**

### Option 2 : Ligne de commande

```bash
cd D:\Dev\TradBOT
python Python\xauusd_whatsapp_monitor.py --phone "+33612345678" --interval 600
```

**Paramètres** :
- `--phone` : Votre numéro WhatsApp (obligatoire)
- `--interval` : Secondes entre checks (défaut: 600 = 10min)

---

## 📲 Alertes WhatsApp

### 1. **Setup SELL valide** ✅

```
🚨 TradBOT ALERT [18:05 UTC]

✅ SETUP SELL VALIDE — Entrer maintenant !

Prix: $4,540.50
Zone Entry: $4535-$4545
SL: $4565
TP1: $4505
TP2: $4475

Biais: SELL 50%
Expire dans: 6.2h
```

**Condition** : Prix entre $4,535-4,545 + Biais SELL valide

---

### 2. **Biais change** 🔴

```
🚨 TradBOT ALERT [18:15 UTC]

🔴 ALERTE CRITIQUE : Biais changé !

Avant: SELL
Maintenant: BUY

❌ ANNULER SETUP SELL
Ne pas entrer !
```

**Condition** : Direction passe de SELL à BUY ou NEUTRAL

---

### 3. **Biais expire** ⏰

```
🚨 TradBOT ALERT [00:20 UTC]

⏰ ALERTE EXPIRATION

Biais XAUUSD expiré (valid=false)
Setup SELL annulé

Attendre nouvelle session demain
```

**Condition** : `valid=false` dans la réponse API

---

### 4. **Prix au-dessus SL** ⚠️

```
🚨 TradBOT ALERT [18:00 UTC]

⚠️ Prix au-dessus du SL

Prix: $4,570.12
SL: $4565
Écart: +$5.12

❌ Pas d'entrée SELL
Attendre pullback sous $4545
```

**Condition** : Prix > $4,565

---

### 5. **TP1 atteint** 🎯

```
🚨 TradBOT ALERT [19:30 UTC]

🎯 TP1 ATTEINT !

Prix: $4,505.00
TP1: $4505

Gain potentiel: +$10
Prochain objectif TP2: $4475
```

**Condition** : Prix descend et touche $4,505

---

### 6. **TP2 atteint** 🎯🎯

```
🚨 TradBOT ALERT [20:15 UTC]

🎯🎯 TP2 ATTEINT !

Prix: $4,475.00
TP2: $4475

Gain total: +$15
✅ Objectif final atteint !
```

**Condition** : Prix descend et touche $4,475

---

## 📊 Logs

Les logs sont sauvegardés dans `xauusd_monitor.log` :

```
2026-05-25 18:00:15 [INFO] 🚀 Démarrage surveillance XAUUSD → WhatsApp +33612345678
2026-05-25 18:00:16 [INFO] ✅ WhatsApp envoyé: Surveillance XAUUSD démarrée
2026-05-25 18:00:17 [INFO] --- Check #1 @ 18:00:17 UTC ---
2026-05-25 18:00:18 [INFO] 📊 Biais: SELL 50% | Prix: $4570.12 | Valid: True
2026-05-25 18:10:18 [INFO] --- Check #2 @ 18:10:18 UTC ---
```

---

## 🛠️ Troubleshooting

### Problème 1 : "ModuleNotFoundError: No module named 'websockets'"

**Solution** :
```bash
pip install websockets
```

---

### Problème 2 : WhatsApp non envoyé

**Causes possibles** :
1. API PsychoBot down/slow (Render free tier dort après 15min inactivité)
2. Format endpoint incorrect
3. Numéro WhatsApp invalide

**Debug** :
1. Ouvrir `xauusd_monitor.log`
2. Chercher `❌ WhatsApp échec`
3. Vérifier le code HTTP retourné

**Test API manuel** :
```bash
curl -X POST https://psychobot-1si7.onrender.com/send-message \
  -H "Content-Type: application/json" \
  -d '{"phone":"+33612345678","message":"Test TradBOT"}'
```

---

### Problème 3 : "Biais non disponible"

**Solution** :
```bash
# Vérifier que le serveur AI tourne
curl http://127.0.0.1:8000/session-bias?symbol=XAUUSD

# Si erreur, lancer le serveur
cd D:\Dev\TradBOT
python ai_server.py
```

---

### Problème 4 : Script s'arrête après quelques minutes

**Cause** : Exception non catchée

**Solution** :
1. Ouvrir `xauusd_monitor.log`
2. Chercher la dernière ligne `[ERROR]`
3. Partager l'erreur pour debug

---

## 🔄 Arrêt / Redémarrage

### Arrêter la surveillance

**Méthode 1** : Fermer la fenêtre CMD

**Méthode 2** : Dans la fenêtre CMD, appuyer sur `Ctrl+C`

Un message WhatsApp de confirmation est envoyé :
```
⏹️ Surveillance XAUUSD arrêtée
```

---

### Redémarrer

Double-cliquer à nouveau sur `start_xauusd_monitor.bat`

---

## 📈 Mode Expert : Surveillance multi-symboles

Pour surveiller plusieurs symboles (XAUUSD, BTCUSD, EURUSD...) :

```bash
# Terminal 1
python Python/xauusd_whatsapp_monitor.py --phone "+33612345678" --interval 600

# Terminal 2 (adapter le script pour BTCUSD)
python Python/btcusd_whatsapp_monitor.py --phone "+33612345678" --interval 600
```

---

## 🆘 Support

En cas de problème :

1. **Consulter les logs** : `xauusd_monitor.log`
2. **Tester l'API manuellement** : `curl https://psychobot-1si7.onrender.com/`
3. **Vérifier le serveur AI** : `curl http://127.0.0.1:8000/session-bias?symbol=XAUUSD`

---

## ✅ Checklist de démarrage

Avant de lancer la surveillance :

- [ ] Python installé (`python --version`)
- [ ] Dépendances installées (`pip install requests websockets`)
- [ ] Serveur AI en marche (`http://127.0.0.1:8000/`)
- [ ] API PsychoBot testée (curl ou Postman)
- [ ] Numéro WhatsApp configuré dans `start_xauusd_monitor.bat`
- [ ] Endpoint API correct dans `xauusd_whatsapp_monitor.py`

---

**Version** : 1.0.0  
**Dernière mise à jour** : 2026-05-25  
**Auteur** : TradBOT Dev Team
