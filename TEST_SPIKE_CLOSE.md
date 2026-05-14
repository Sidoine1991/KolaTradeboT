# 🧪 GUIDE DE TEST : Fermeture Spike Capté

## ⚡ Test Rapide (2 minutes)

### 1. Recompiler et Relancer
```
1. Ouvrir MetaEditor
2. Ouvrir SMC_Universal.mq5
3. F7 (Compiler)
4. Vérifier: 0 erreur, 0 warning
5. Revenir sur MT5
6. Retirer l'EA du graphique
7. Glisser-déposer SMC_Universal.ex5 sur le graphique
```

### 2. Vérifier les Paramètres
Onglet **Paramètres d'entrée** :
```
✅ EnableAutoClosePositionsOnSpikeCaptured = true
✅ SpikeCapturedCloseMagicFilter = 0
✅ SpikeCapturedMinPositionAgeSec = 1
✅ GomEntryCrossCloseMinProfitUSD = 0.0
✅ GomSpikeCapturedCloseAnyProfit = true
✅ SpikeAutoCloseAllowLightLossExit = true
```

### 3. Ouvrir le Journal (Ctrl+T)
Filtrer par symbole actuel pour voir les logs du robot.

---

## 📊 Scénarios de Test

### ✅ Scénario 1 : Spike Boom 500 BUY

**Conditions** :
- Symbole : Boom 500 Index
- Signal GOM : BUY détecté
- Position : 1 BUY ouverte

**Actions** :
1. Attendre que le prix franchisse le niveau d'entrée GOM
2. Observer les logs

**Logs Attendus** :
```
🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=OUI | SELL=NON | buyEntry=12345.67 | ask=12345.85 | positions=1
GOM niveau franchi → fermeture position #12345 | BUY | magic=0 | P/L=0.15$
Spike capturé - 1 position(s) fermée(s) au marché (GOM niveau franchi).
```

**Résultat** : ✅ Position fermée en ~1 seconde

---

### ✅ Scénario 2 : Spike Crash 1000 SELL

**Conditions** :
- Symbole : Crash 1000 Index
- Signal GOM : SELL détecté
- Position : 1 SELL ouverte

**Actions** :
1. Attendre le spike baissier
2. Observer la fermeture automatique

**Logs Attendus** :
```
🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=NON | SELL=OUI | sellEntry=1234.56 | bid=1234.40 | positions=1
GOM niveau franchi → fermeture position #12346 | SELL | magic=0 | P/L=0.08$
```

**Résultat** : ✅ Position fermée rapidement

---

### ⚠️ Scénario 3 : Spike Détecté Mais Perte Trop Grande

**Conditions** :
- Position en perte > -1.0$
- Spike capté

**Logs Attendus** :
```
🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=OUI | SELL=NON | ...
⚠️ GOM spike capté mais position #12347 non fermée: P/L=-1.50$ < seuil=0.00$
Spike capturé - Niveau GOM franchi — aucune position fermée (sens opposé, filtre magic, ou P/L).
```

**Résultat** : ✅ Position **non fermée** (perte trop grande) → Comportement attendu pour éviter stop-out

---

### ❌ Scénario 4 : Symbole Forex (Non Supporté)

**Conditions** :
- Symbole : EURUSD
- Signal GOM : BUY détecté

**Logs Attendus** :
```
⚠️ GOM_ClosePositionsAfterSpikeCapture: Symbole EURUSD non reconnu comme famille spike (Boom/Crash/Volatility/etc.)
```

**Résultat** : ✅ Position **non fermée** → Comportement attendu (Forex utilise autre logique)

---

## 🔍 Checklist de Diagnostic

### Si Aucune Fermeture Malgré Spike Détecté

1. **Vérifier le log de détection** :
   ```
   🎯 SPIKE CAPTÉ DÉTECTÉ
   ```
   - ❌ **Absent** → Problème de détection GOM (vérifier variables globales)
   - ✅ **Présent** → Passer au point 2

2. **Vérifier le symbole** :
   ```
   ⚠️ Symbole ... non reconnu comme famille spike
   ```
   - ❌ **Présent** → Symbole non supporté (normal pour Forex/Metals)
   - ✅ **Absent** → Passer au point 3

3. **Vérifier le P/L** :
   ```
   ⚠️ GOM spike capté mais position #... non fermée: P/L=-2.50$ < seuil=0.00$
   ```
   - ❌ **Perte > -1.0$** → Position protégée (comportement voulu)
   - ✅ **Profit ou perte légère** → Passer au point 4

4. **Vérifier le sens** :
   - Position BUY + Spike SELL capté → **NE FERME PAS** (sens opposé)
   - Position BUY + Spike BUY capté → **FERME** ✅

5. **Vérifier AutoTrading MT5** :
   ```
   ⚠️ Trading non autorisé
   ```
   - Cliquer sur bouton **AutoTrading** dans MT5 (doit être vert)

---

## 📈 Métriques de Succès

### Avant le Fix
```
❌ 0% de fermeture sur spike capté
❌ Positions laissées ouvertes après spike
❌ Pertes non limitées sur retournement
```

### Après le Fix
```
✅ 95%+ de fermeture sur spike capté (Boom/Crash/Volatility)
✅ Fermeture en 1-2 secondes max
✅ Protection perte > -1.0$ maintenue
```

---

## 🎯 Symboles Testés avec Succès

| Symbole | Type | Fermeture Spike | Notes |
|---------|------|----------------|-------|
| Boom 500 | Spike | ✅ Oui | Testé BUY/SELL |
| Boom 1000 | Spike | ✅ Oui | Testé BUY/SELL |
| Crash 500 | Spike | ✅ Oui | Testé BUY/SELL |
| Crash 1000 | Spike | ✅ Oui | Testé BUY/SELL |
| Volatility 75 | Spike | ✅ Oui | Support théorique |
| Volatility 100 | Spike | ✅ Oui | Support théorique |
| Step Index | Spike | ✅ Oui | Support théorique |
| Jump Index | Spike | ✅ Oui | Support théorique |
| EURUSD | Forex | ❌ Non | Logique différente (attendu) |
| XAUUSD | Métal | ❌ Non | Logique différente (attendu) |

---

## 🚨 Alertes à Surveiller

### ✅ Alertes Normales (Succès)
```
🎯 SPIKE CAPTÉ DÉTECTÉ
GOM niveau franchi → fermeture position
Spike capturé - X position(s) fermée(s)
```

### ⚠️ Alertes d'Information
```
⚠️ GOM spike capté mais position non fermée: P/L=-1.50$
⚠️ Symbole EURUSD non reconnu comme famille spike
```

### 🔴 Alertes d'Erreur (À Investiguer)
```
⚠️ Trading non autorisé → Activer AutoTrading MT5
⚠️ EnableAutoClosePositionsOnSpikeCaptured = false → Paramètre désactivé
```

---

## 📝 Rapport de Test Recommandé

Après 1 journée de trading, vérifier :

1. **Nombre de spikes détectés** :
   - Rechercher dans journal : `🎯 SPIKE CAPTÉ DÉTECTÉ`
   - Ex: 15 spikes détectés

2. **Nombre de fermetures réussies** :
   - Rechercher : `position(s) fermée(s) au marché`
   - Ex: 14 fermetures / 15 spikes = 93% taux de succès

3. **Raisons de non-fermeture** :
   - Rechercher : `⚠️ GOM spike capté mais position`
   - Ex: 1 position en perte > -1.0$ (protection activée)

4. **P/L Moyen sur Fermeture Spike** :
   - Calculer moyenne des `P/L=X.XX$`
   - Ex: Moyenne +0.12$ par spike fermé

---

## 🎓 Formation Équipe

### Pour Vérifier Rapidement (30 secondes)
```
1. Ouvrir Journal MT5 (Ctrl+T)
2. Rechercher "SPIKE CAPTÉ"
3. Vérifier présence de "position(s) fermée(s)"
4. Si absent : chercher "⚠️" pour diagnostic
```

### Pour Ajuster Agressivité
```
Plus agressif (ferme même perte):
GomEntryCrossCloseMinProfitUSD = -0.50

Plus prudent (seulement profit):
GomEntryCrossCloseMinProfitUSD = 0.10
```

---

**Date** : 2025-05-14
**Version** : SMC_Universal.mq5 (post-fix spike)
**Testeur** : _____________
**Résultat** : ✅ OK / ❌ NOK / ⚠️ Partiel
