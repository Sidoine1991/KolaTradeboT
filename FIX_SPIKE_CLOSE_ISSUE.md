# 🔧 CORRECTION: Fermeture Automatique des Positions sur Spike Capté

## 🎯 Problème Identifié

Le robot **ne fermait pas les positions** lorsqu'un spike était détecté, même si la fonction `GOM_CheckCaptureSpikeAndCleanup()` était appelée correctement.

### Causes Principales

1. **Filtre Magic Number trop restrictif** : `SpikeCapturedCloseMagicFilter = 202502` alors que le robot utilise possiblement un magic différent
2. **Seuil de profit trop élevé** : `GomEntryCrossCloseMinProfitUSD = 0.06$` empêchait la fermeture des positions avec profit inférieur
3. **Perte légère non autorisée** : `SpikeAutoCloseAllowLightLossExit = false` empêchait la fermeture en cas de légère perte
4. **Manque de logs de débogage** : Difficile de diagnostiquer pourquoi les positions ne se fermaient pas

---

## ✅ Corrections Appliquées

### 1. **Paramètres d'Entrée Optimisés** (lignes 123-131)

```mql5
// AVANT
input long   SpikeCapturedCloseMagicFilter = 202502;  // ❌ Magic spécifique uniquement
input int    SpikeCapturedMinPositionAgeSec = 2;     // ⏱️ 2 secondes (peut manquer le spike)
input double GomEntryCrossCloseMinProfitUSD = 0.06;  // 💰 0.06$ minimum (trop élevé)
input bool   SpikeAutoCloseAllowLightLossExit = false; // ❌ Refuse perte légère

// APRÈS
input long   SpikeCapturedCloseMagicFilter = 0;      // ✅ 0 = TOUTES les positions du symbole
input int    SpikeCapturedMinPositionAgeSec = 1;     // ⚡ 1 seconde (réactivité maximale)
input double GomEntryCrossCloseMinProfitUSD = 0.0;   // ✅ 0 = ferme même en perte légère
input bool   SpikeAutoCloseAllowLightLossExit = true; // ✅ Autorise fermeture sur perte légère
```

### 2. **Logique de Vérification du P/L Améliorée** (lignes 4008-4026)

```mql5
// NOUVELLE LOGIQUE
if(GomEntryCrossCloseMinProfitUSD <= 0.0)
{
   // Ferme toute position alignée avec le spike, même en perte légère (max -1.0$)
   profitOk = (net >= -1.0);
}
else
{
   // Si seuil > 0, utilise la logique existante
   if(GomSpikeCapturedCloseAnyProfit && net > 1e-8)
      profitOk = true;
   else
      profitOk = (net + 1e-9 >= GomEntryCrossCloseMinProfitUSD);
}

if(!profitOk)
{
   Print("⚠️ GOM spike capté mais position #", ticket, " non fermée: P/L=", DoubleToString(net, 2),
         "$ < seuil=", DoubleToString(GomEntryCrossCloseMinProfitUSD, 2), "$");
   continue;
}
```

### 3. **Logs de Débogage Ajoutés**

#### a) Dans `GOM_CheckCaptureSpikeAndCleanup()` (lignes 4056-4071)

```mql5
// LOG DEBUG: Afficher l'état de la détection de spike
static datetime lastSpikeDebugLog = 0;
datetime nowDebug = TimeCurrent();
if(captured || (nowDebug - lastSpikeDebugLog >= 120))
{
   if(captured)
   {
      Print("🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=", (buyCaptured ? "OUI" : "NON"),
            " | SELL=", (sellCaptured ? "OUI" : "NON"),
            " | buyEntry=", DoubleToString(buyE, _Digits),
            " | sellEntry=", DoubleToString(sellE, _Digits),
            " | ask=", DoubleToString(ask, _Digits),
            " | bid=", DoubleToString(bid, _Digits),
            " | positions=", PositionsTotal());
   }
   lastSpikeDebugLog = nowDebug;
}
```

#### b) Dans `GOM_ClosePositionsAfterSpikeCapture()` (lignes 3967-3987)

```mql5
if(!EnableAutoClosePositionsOnSpikeCaptured)
{
   Print("⚠️ GOM_ClosePositionsAfterSpikeCapture: EnableAutoClosePositionsOnSpikeCaptured = false");
   return 0;
}

if(!GOM_IsSymSpikeStyleFamilyForGomAutoClose())
{
   Print("⚠️ GOM_ClosePositionsAfterSpikeCapture: Symbole ", _Symbol, " non reconnu comme famille spike");
   return 0;
}

if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
{
   Print("⚠️ GOM_ClosePositionsAfterSpikeCapture: Trading non autorisé");
   return 0;
}
```

---

## 📊 Comment Vérifier que Ça Fonctionne

### 1. **Logs à Surveiller dans le Journal MT5**

Lors de la détection d'un spike :
```
🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=OUI | SELL=NON | buyEntry=1234.56 | ask=1234.70 | positions=1
GOM niveau franchi → fermeture position #12345 | BUY | magic=0 | P/L=0.12$
Spike capturé - 1 position(s) fermée(s) au marché (GOM niveau franchi).
```

### 2. **Logs d'Avertissement si Aucune Fermeture**

Si le spike est détecté mais aucune position fermée :
```
⚠️ GOM spike capté mais position #12345 non fermée: P/L=-0.50$ < seuil=0.00$
```
ou
```
⚠️ GOM_ClosePositionsAfterSpikeCapture: Symbole EURUSD non reconnu comme famille spike
```

### 3. **Notifications MT5**

Si `UseNotifications = true`, vous recevrez :
```
📱 Spike capturé - 1 position(s) fermée(s) au marché (GOM niveau franchi).
```

---

## 🔍 Diagnostic si le Problème Persiste

### Étape 1 : Vérifier que le Spike est Détecté

Recherchez dans les logs :
```
🎯 SPIKE CAPTÉ DÉTECTÉ
```

- **Si absent** → Le spike n'est pas détecté par GOM (vérifier les variables globales `GOM_SCRIPT_*_BUY_ENTRY` / `SELL_ENTRY`)
- **Si présent** → Passez à l'étape 2

### Étape 2 : Vérifier que la Fonction de Fermeture est Appelée

Recherchez :
```
⚠️ GOM_ClosePositionsAfterSpikeCapture: ...
```

- **Si "EnableAutoClosePositionsOnSpikeCaptured = false"** → Activer le paramètre dans les inputs
- **Si "Symbole non reconnu"** → Vérifier `GOM_IsSymSpikeStyleFamilyForGomAutoClose()` pour votre symbole
- **Si "Trading non autorisé"** → Vérifier AutoTrading dans MT5

### Étape 3 : Vérifier le Filtre P/L

Recherchez :
```
⚠️ GOM spike capté mais position #... non fermée: P/L=...$ < seuil=...$
```

- Si présent → Réduire `GomEntryCrossCloseMinProfitUSD` à 0.0 (déjà fait dans ce fix)

---

## 🎯 Symboles Supportés pour la Fermeture Spike

La fermeture automatique fonctionne pour :

✅ **Boom/Crash** (ex: Boom 500, Crash 1000)
✅ **Gainx/Painx** (ex: Gain 500x, Pain 1000x)
✅ **Volatility** (ex: Volatility 75, Volatility 100)
✅ **Step/Jump** indices
✅ **Pinch/Gas** indices
✅ **Range Break** indices

❌ **PAS pour Forex, Métaux, Commodités** (logique différente)

---

## 📝 Paramètres Recommandés

```mql5
EnableAutoClosePositionsOnSpikeCaptured = true      // ✅ Activer
SpikeCapturedCloseMagicFilter = 0                   // ✅ Toutes positions
SpikeCapturedMinPositionAgeSec = 1                  // ✅ 1 seconde
GomEntryCrossCloseMinProfitUSD = 0.0                // ✅ Ferme même en perte légère
GomSpikeCapturedCloseAnyProfit = true               // ✅ Ferme dès profit > 0
SpikeAutoCloseAllowLightLossExit = true             // ✅ Autorise perte légère
```

---

## 🚀 Prochaines Étapes

1. **Recompiler** `SMC_Universal.mq5` dans MetaEditor
2. **Redémarrer** le robot sur le graphique
3. **Surveiller** les logs lors du prochain spike
4. **Ajuster** `GomEntryCrossCloseMinProfitUSD` si nécessaire (0.0 = le plus agressif)

---

**Date de correction** : 2025-05-14
**Fichier modifié** : `SMC_Universal.mq5`
**Lignes modifiées** : 123-131, 3967-4026, 4056-4071
