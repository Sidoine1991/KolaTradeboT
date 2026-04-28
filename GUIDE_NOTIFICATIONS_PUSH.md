# 📲 Guide - Notifications Push Analyse Complète

## 📊 Vue d'ensemble

Système de **notifications push intelligentes** envoyées toutes les 10 minutes sur mobile/desktop avec:
- ✅ **Actualités économiques** filtrées par symbole
- ✅ **Analyse technique complète** (tendance, RSI, support/résistance)
- ✅ **Signaux de trading** (BUY/SELL/NEUTRAL)
- ✅ **Format compact** optimisé pour mobile

---

## 📱 Exemple de notification reçue

```
🟢 EURUSD | BUY
📈 BULLISH (78%)
💰 1.08550 | RSI 62.3
📍 S:1.08420 R:1.08680

📰 🔴 [HIGH] Fed Rate Decision 14:30 | EUR/USD climbs on ECB news
```

**Décodage:**
- 🟢 Signal BUY actif
- 📈 Tendance haussière forte (78%)
- 💰 Prix actuel + RSI
- 📍 Support et Résistance
- 📰 Actualités économiques importantes

---

## 🚀 Configuration requise

### 1. Activer les notifications dans MT5

**Sur Desktop:**
1. Outils → Options → Notifications
2. Cocher **"Activer les notifications Push"**
3. Noter votre **MetaQuotes ID**

**Sur Mobile:**
1. Installer l'application **MetaTrader 5** (iOS/Android)
2. Paramètres → Messages → **Activer les notifications push**
3. Scanner le QR Code depuis MT5 Desktop
4. Ou entrer manuellement le MetaQuotes ID

### 2. Vérifier la configuration

Dans MT5, tester avec:
```mql5
SendNotification("Test de notification push");
```

Vous devriez recevoir un message sur votre mobile/desktop.

---

## ⚙️ Paramètres disponibles

### Dans SMC_Universal.mq5

```mql5
input bool   EnablePushNotifications = true;      // Activer/désactiver
input int    PushNotificationInterval = 600;      // Intervalle (secondes)
input bool   PushIncludeEconomicNews = true;      // Inclure actualités
input bool   PushIncludeTechnicalAnalysis = true; // Inclure analyse technique
input bool   PushIncludeSignals = true;           // Inclure signaux
input bool   PushOnlyHighImpactNews = false;      // Seulement news HIGH
```

### Intervalles recommandés

| Intervalle | Secondes | Usage |
|------------|----------|-------|
| 5 minutes  | 300      | Trading actif (scalping) |
| **10 minutes** | **600** | **Par défaut (recommandé)** |
| 15 minutes | 900      | Swing trading |
| 30 minutes | 1800     | Position trading |
| 1 heure    | 3600     | Surveillance longue durée |

---

## 📊 Contenu des notifications

### 1. En-tête avec signal

```
🟢 EURUSD | BUY     → Signal achat actif
🔴 GBPUSD | SELL    → Signal vente actif
⚪ BTCUSD | NEUTRAL → Pas de signal clair
```

### 2. Analyse de tendance

```
📈 BULLISH (78%)    → Tendance haussière forte
📉 BEARISH (65%)    → Tendance baissière
➡️ SIDEWAYS (30%)   → Marché latéral
```

**Force de tendance:**
- 0-30%: Faible
- 30-60%: Modérée
- 60-80%: Forte
- 80-100%: Très forte

### 3. Prix et RSI

```
💰 1.08550 | RSI 62.3
```

**Interprétation RSI:**
- < 30: Survente (potentiel BUY)
- 30-50: Zone neutre/baissière
- 50-70: Zone neutre/haussière
- > 70: Surachat (potentiel SELL)

### 4. Support et Résistance

```
📍 S:1.08420 R:1.08680
```

- **S** (Support): Niveau bas probable
- **R** (Résistance): Niveau haut probable

### 5. Actualités économiques

```
📰 🔴 [HIGH] Fed Rate Decision 14:30
```

**Icônes d'impact:**
- 🔴 HIGH: Événements majeurs (Fed, ECB, NFP)
- 📰 MEDIUM: Actualités importantes
- ⚡ LOW: Alertes secondaires

---

## 🔧 Algorithme de génération

### 1. Analyse technique

```mql5
// Calcul des EMAs M15
EMA9 vs EMA21 → Déterminer tendance
Prix vs EMA9  → Confirmer direction

// Calcul de force
Gap = (EMA9 - EMA21) / EMA21
Strength = Min(100, Gap × 5)

// Signal
if BULLISH && RSI 50-70 → BUY
if BEARISH && RSI 30-50 → SELL
else → NEUTRAL
```

### 2. Support/Résistance

```mql5
// Sur 50 dernières bougies M15
Resistance = Highest(High, 20)
Support = Lowest(Low, 20)
```

### 3. Actualités économiques

```mql5
// API call
GET /economic/news/ticker?symbol=EURUSD

// Filtrage
if PushOnlyHighImpactNews:
   filter where impact == "HIGH"

// Tronquer à 200 caractères
```

---

## 📱 Exemples de notifications

### Cas 1: Signal BUY avec actualités HIGH

```
🟢 EURUSD | BUY
📈 BULLISH (82%)
💰 1.09250 | RSI 64.8
📍 S:1.09100 R:1.09420

📰 🔴 [HIGH] ECB Press Conference 13:00 | EUR strength continues
```

### Cas 2: Signal SELL sans actualités majeures

```
🔴 GBPUSD | SELL
📉 BEARISH (71%)
💰 1.26350 | RSI 38.2
📍 S:1.26100 R:1.26550

📰 📊 Market analysis | GBP under pressure
```

### Cas 3: Marché latéral

```
⚪ BTCUSD | NEUTRAL
➡️ SIDEWAYS (35%)
💰 68540.00 | RSI 52.1
📍 S:67800.00 R:69200.00

📰 ⚡ BTC consolidates near 68k | Crypto markets stable
```

### Cas 4: Seulement HIGH impact news

```
🟢 XAUUSD | BUY
📈 BULLISH (88%)
💰 2348.50 | RSI 67.9
📍 S:2338.00 R:2358.00

📰 🔴 [HIGH] Fed Rate Decision 14:30
```

---

## 🛠️ Dépannage

### Notifications non reçues

**Vérifier:**
1. ✅ MT5 Desktop: Outils > Options > Notifications > **coché**
2. ✅ MetaQuotes ID correctement lié
3. ✅ Application mobile installée et connectée
4. ✅ Paramètre `EnablePushNotifications = true`
5. ✅ Backend actif: `http://localhost:8000/economic/health`

**Test manuel:**
Dans l'onglet Expert du robot, chercher:
```
📲 Envoi notification push analyse...
✅ Notification push envoyée: BUY - BULLISH
```

Si erreur:
```
❌ Échec envoi notification push
💡 Vérifiez: Outils > Options > Notifications > activé
```

### Trop de notifications

```mql5
// Augmenter intervalle
PushNotificationInterval = 1800;  // 30 minutes
```

### Pas assez de notifications

```mql5
// Réduire intervalle
PushNotificationInterval = 300;   // 5 minutes
```

### Actualités toujours "indisponibles"

1. Vérifier backend: `python start_ai_server.py`
2. Tester API: `http://localhost:8000/economic/news/ticker?symbol=EURUSD`
3. Vérifier logs MT5 pour erreurs HTTP

### Message tronqué

Les notifications push MT5 sont limitées à ~256 caractères. Le système tronque automatiquement à 200 caractères pour être sûr.

---

## 📊 Statistiques et suivi

### Dans les logs MT5

```
📲 Système de notifications push activé
⏱️ Intervalle: 600 secondes (10 minutes)
💡 Assurez-vous d'avoir activé les notifications dans MT5

[10:00:00] 📲 Envoi notification push analyse...
[10:00:01] ✅ Notification push envoyée: BUY - BULLISH

[10:10:00] 📲 Envoi notification push analyse...
[10:10:01] ✅ Notification push envoyée: BUY - BULLISH

[10:20:00] 📲 Envoi notification push analyse...
[10:20:01] ✅ Notification push envoyée: NEUTRAL - SIDEWAYS
```

---

## 🔮 Améliorations futures

### Phase 1 (actuel)
- ✅ Notifications toutes les 10 minutes
- ✅ Analyse technique + actualités
- ✅ Signaux BUY/SELL/NEUTRAL
- ✅ Support/Résistance

### Phase 2 (à venir)
- 🔲 Notifications conditionnelles (seulement si changement signal)
- 🔲 Multi-symboles (notification groupée pour plusieurs paires)
- 🔲 Historique des notifications envoyées
- 🔲 Précision des signaux (% réussite)

### Phase 3 (avancé)
- 🔲 Notifications intelligentes (ML prédit meilleur moment)
- 🔲 Alertes de volatilité extrême
- 🔲 Alertes de corrélation multi-paires
- 🔲 Résumé quotidien/hebdomadaire

---

## 📝 Notes importantes

### Limites MT5

- **Maximum ~256 caractères** par notification
- **Pas de formatage** (gras, couleurs) dans notifications
- **Emojis supportés** mais peuvent varier selon plateforme
- **Pas d'images** ni pièces jointes

### Consommation réseau

- Chaque notification: **~5-10 KB** de données
- 10 minutes: **144 notifications/jour** = ~1.5 MB/jour
- Impact: **Négligeable** sur performances

### Confidentialité

- Les notifications transitent par **serveurs MetaQuotes**
- Ne jamais inclure **mots de passe** ou **clés API**
- Les signaux sont **indicatifs** uniquement

---

## ✅ Checklist installation

- [x] Fichier `Push_Notifications_Analysis.mqh` créé
- [x] Include ajouté dans `SMC_Universal.mq5`
- [x] `InitPushNotifications()` dans OnInit()
- [x] `SendPushAnalysisNotification()` dans OnTick()
- [x] Fichier copié dans terminal MT5
- [ ] Notifications activées dans MT5 (Outils > Options)
- [ ] MetaQuotes ID configuré
- [ ] Application mobile installée et liée
- [ ] Backend démarré (`python start_ai_server.py`)
- [ ] Test envoi notification réussi

---

**Status:** ✅ Prêt à utiliser  
**Version:** 1.0  
**Date:** 2026-04-28

**Prochaine étape:** Recompiler le robot et activer les notifications push dans MT5!
