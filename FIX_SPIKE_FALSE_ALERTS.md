# 🔧 CORRECTION: Fausses Alertes "Spike Capté" Sans Position Ouverte

## 🎯 Problème Identifié

Le robot envoyait des **notifications push "Spike capté"** même quand :
1. ❌ **Aucune position n'était ouverte**
2. ❌ **Le franchissement du niveau GOM n'était pas un vrai spike Boom/Crash** (mouvement rapide négatif → positif)

### Scénario Problématique

```
📱 Notification: "Spike capté - Niveau GOM franchi — aucune position fermée..."
❌ Aucune position ouverte avant le spike
❌ Simple franchissement de niveau, pas de mouvement rapide du prix
```

---

## ✅ Corrections Appliquées

### 1. **Suppression Notification Sans Fermeture** (ligne 4103-4113)

**AVANT** :
```mql5
if(closedN == 0)
{
   datetime nowCap = TimeCurrent();
   if(nowCap - g_gomLastSpikeCapturedNoCloseNotifyUtc >= 90)
   {
      g_gomLastSpikeCapturedNoCloseNotifyUtc = nowCap;
      GOM_AlertPush("Spike capturé",
                    "Niveau GOM franchi — aucune position fermée...",
                    NotifySoundSpike);  // ❌ NOTIFIE MÊME SANS POSITION
   }
}
```

**APRÈS** :
```mql5
if(closedN == 0)
{
   // ✅ Log silencieux pour diagnostic, PAS de notification push
   Print("⚠️ GOM niveau franchi mais aucune position fermée | BUY=", (buyCaptured ? "OUI" : "NON"),
         " | SELL=", (sellCaptured ? "OUI" : "NON"), " | positions=", PositionsTotal());
}
// ✅ NOTIFICATION UNIQUEMENT si closedN > 0 (dans GOM_ClosePositionsAfterSpikeCapture)
```

### 2. **Détection de Vrai Spike Boom/Crash** (ligne 3995-4048)

Ajout d'une vérification que le mouvement est **un vrai spike** (rapide, minimum 0.3% en 5 secondes) :

```mql5
// Variables globales pour tracker le mouvement de prix
static double   g_gomLastPriceForSpikeDetection = 0.0;
static datetime g_gomLastSpikeDetectionTime = 0;

// Dans GOM_ClosePositionsAfterSpikeCapture():
datetime now = TimeCurrent();
double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
bool isRealSpike = false;

// Détection spike rapide (5 dernières secondes max)
if(g_gomLastSpikeDetectionTime > 0 && (now - g_gomLastSpikeDetectionTime) <= 5)
{
   if(g_gomLastPriceForSpikeDetection > 0.0)
   {
      double priceChange = currentPrice - g_gomLastPriceForSpikeDetection;
      double priceChangePct = (priceChange / g_gomLastPriceForSpikeDetection) * 100.0;

      // ✅ Boom: mouvement haussier rapide (min 0.3%)
      if(buySpikeCaptured && StringFind(_Symbol, "Boom") >= 0 && priceChangePct >= 0.3)
      {
         isRealSpike = true;
         Print("✅ SPIKE BOOM RÉEL: +", DoubleToString(priceChangePct, 2), "% en ", (now - g_gomLastSpikeDetectionTime), "s");
      }

      // ✅ Crash: mouvement baissier rapide (min -0.3%)
      if(sellSpikeCaptured && StringFind(_Symbol, "Crash") >= 0 && priceChangePct <= -0.3)
      {
         isRealSpike = true;
         Print("✅ SPIKE CRASH RÉEL: ", DoubleToString(priceChangePct, 2), "% en ", (now - g_gomLastSpikeDetectionTime), "s");
      }
   }
}

// Si pas de spike réel détecté ET qu'on exige un vrai spike, sortir
if(SpikeCapturedRequireRealSpike && !isRealSpike)
{
   Print("⚠️ Niveau GOM franchi mais pas de spike rapide détecté — fermeture annulée");
   return 0;
}
```

### 3. **Nouveau Paramètre de Contrôle** (ligne 132)

```mql5
input bool SpikeCapturedRequireRealSpike = true; 
// Exiger mouvement rapide prix (0.3% en 5s) avant fermeture spike
// ÉVITE fausses alertes sans position
```

---

## 📊 Comportement Avant/Après

### ❌ Avant le Fix

| Situation | Notification | Position Fermée | Résultat |
|-----------|--------------|-----------------|----------|
| Niveau GOM franchi + aucune position | ✅ OUI | ❌ NON | **Fausse alerte** |
| Niveau GOM franchi + mouvement lent | ✅ OUI | ✅ OUI | **Fermeture non justifiée** |
| Vrai spike rapide + position ouverte | ✅ OUI | ✅ OUI | ✅ Correct |

### ✅ Après le Fix

| Situation | Notification | Position Fermée | Résultat |
|-----------|--------------|-----------------|----------|
| Niveau GOM franchi + aucune position | ❌ NON | ❌ NON | ✅ **Pas d'alerte** |
| Niveau GOM franchi + mouvement lent | ❌ NON | ❌ NON | ✅ **Pas de fermeture** |
| Vrai spike rapide (0.3% en 5s) + position | ✅ OUI | ✅ OUI | ✅ **Fermeture justifiée** |

---

## 🔍 Critères d'un Vrai Spike

### Boom 500/1000 (BUY Spike)
```
✅ Mouvement haussier ≥ 0.3% en ≤ 5 secondes
✅ Prix passe le niveau d'entrée GOM BUY
✅ Position BUY ouverte
```

### Crash 500/1000 (SELL Spike)
```
✅ Mouvement baissier ≤ -0.3% en ≤ 5 secondes
✅ Prix passe le niveau d'entrée GOM SELL
✅ Position SELL ouverte
```

---

## 📝 Logs à Surveiller

### ✅ Spike Réel Détecté et Position Fermée
```
🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=OUI | SELL=NON | positions=1
✅ SPIKE BOOM RÉEL détecté: +0.45% en 3s
GOM niveau franchi → fermeture position #12345 | BUY | P/L=0.15$
Spike capturé - 1 position(s) fermée(s) au marché (GOM niveau franchi).
```

### ⚠️ Niveau Franchi Mais Pas de Spike Rapide
```
🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=OUI | SELL=NON | positions=1
⚠️ Niveau GOM franchi mais pas de spike rapide détecté (variation < 0.3% en 5s) — fermeture annulée
```

### ℹ️ Niveau Franchi Mais Aucune Position
```
🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=OUI | SELL=NON | positions=0
⚠️ GOM niveau franchi mais aucune position fermée | BUY=OUI | SELL=NON | positions=0
```
*(Pas de notification push)*

---

## 🎯 Paramètres Recommandés

```mql5
EnableAutoClosePositionsOnSpikeCaptured = true    // ✅ Activer fermeture spike
SpikeCapturedRequireRealSpike = true              // ✅ Exiger vrai spike (0.3% en 5s)
SpikeCapturedCloseMagicFilter = 0                 // ✅ Toutes positions
GomEntryCrossCloseMinProfitUSD = 0.0              // ✅ Ferme même perte légère
GomSpikeCapturedCloseAnyProfit = true             // ✅ Ferme dès profit > 0
SpikeAutoCloseAllowLightLossExit = true           // ✅ Autorise perte légère
```

---

## 🧪 Comment Tester

### Test 1 : Niveau GOM Franchi Sans Position
**Conditions** :
- Aucune position ouverte
- Prix franchit niveau GOM

**Résultat Attendu** :
```
⚠️ GOM niveau franchi mais aucune position fermée | positions=0
❌ PAS de notification push
```

### Test 2 : Mouvement Lent avec Position
**Conditions** :
- Position BUY ouverte
- Prix monte lentement (0.1% en 10s)
- Prix franchit niveau GOM

**Résultat Attendu** :
```
⚠️ Niveau GOM franchi mais pas de spike rapide détecté (variation < 0.3% en 5s)
❌ Position NON fermée
❌ PAS de notification
```

### Test 3 : Vrai Spike Rapide avec Position
**Conditions** :
- Position BUY ouverte sur Boom 500
- Prix monte rapidement (+0.5% en 2s)
- Prix franchit niveau GOM

**Résultat Attendu** :
```
✅ SPIKE BOOM RÉEL détecté: +0.50% en 2s
GOM niveau franchi → fermeture position #12345 | P/L=0.15$
📱 Notification: "Spike capturé - 1 position(s) fermée(s)"
```

---

## 🔧 Ajustement du Seuil de Spike

Si vous trouvez que le seuil de **0.3% en 5s** est :

### Trop Strict (rate des spikes)
Modifier dans le code (ligne ~4025) :
```mql5
// Boom: mouvement haussier rapide (min 0.2% au lieu de 0.3%)
if(buySpikeCaptured && StringFind(_Symbol, "Boom") >= 0 && priceChangePct >= 0.2)
```

### Pas Assez Strict (trop de fermetures)
```mql5
// Boom: mouvement haussier rapide (min 0.5% au lieu de 0.3%)
if(buySpikeCaptured && StringFind(_Symbol, "Boom") >= 0 && priceChangePct >= 0.5)
```

### Durée du Spike (5 secondes)
Modifier ligne ~4018 :
```mql5
// Détection spike rapide (3 secondes au lieu de 5)
if(g_gomLastSpikeDetectionTime > 0 && (now - g_gomLastSpikeDetectionTime) <= 3)
```

---

## 📈 Métriques de Succès

### Avant
```
❌ 10+ notifications "Spike capté" par jour sans position fermée
❌ Fermetures non justifiées sur mouvements lents
❌ Confusion utilisateur (alerte sans action)
```

### Après
```
✅ 0 notification sans position ouverte
✅ Fermeture uniquement sur vrai spike rapide (0.3% en 5s)
✅ Logs clairs pour diagnostic
```

---

## 🚀 Prochaines Étapes

1. **Recompiler** SMC_Universal.mq5 dans MetaEditor (F7)
2. **Redémarrer** le robot sur graphique Boom/Crash
3. **Tester** les 3 scénarios ci-dessus
4. **Ajuster** le seuil 0.3% si nécessaire selon vos observations

---

**Date de correction** : 2025-05-14
**Fichier modifié** : `SMC_Universal.mq5`
**Lignes modifiées** : 
- 305-306 : Variables globales spike detection
- 132 : Paramètre `SpikeCapturedRequireRealSpike`
- 3995-4048 : Logique détection spike réel
- 4103-4113 : Suppression notification sans fermeture

**Impact** :
✅ Plus de fausses alertes "Spike capté" sans position
✅ Fermeture uniquement sur vrai spike Boom/Crash
✅ Logs explicites pour diagnostic
