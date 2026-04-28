# Guide d'utilisation - Stratégie Fibonacci/OTE (Optimal Trade Entry)

## 📋 Vue d'ensemble

Votre robot **SMC_Universal.mq5** contient déjà une implémentation complète de la stratégie Fibonacci/OTE basée sur les concepts Smart Money Concepts (ICT).

## 🎯 Qu'est-ce que la zone OTE ?

La zone **OTE (Optimal Trade Entry)** est la zone de retracement Fibonacci entre **0.618 et 0.786** d'un mouvement impulsif. C'est là que le prix a le plus de probabilité de retracer avant de reprendre la direction de la tendance initiale.

### Pourquoi ces niveaux ?
- **0.618 (61.8%)** : Niveau d'entrée préféré (réaction fréquente)
- **0.786 (78.6%)** : Limite supérieure de la zone OTE
- **0.886 (88.6%)** : Niveau profond (si le prix va plus bas)

## ⚙️ Activation de la stratégie OTE

### Étape 1 : Activer la stratégie principale

Dans MT5, ouvrez les paramètres du robot **SMC_Universal.mq5** et configurez :

```
=== SMC_OTE — MARCHÉS AUTORISÉS ===
UseSMC_OTEStrategy = true                    // ✅ ACTIVER
SMC_OTE_AllowForex = true                   // Autoriser Forex
SMC_OTE_AllowMetals = true                  // Autoriser Métaux (Or, Argent)
SMC_OTE_AllowCommodities = true             // Autoriser Commodités
SMC_OTE_AllowBoomCrash = true               // Autoriser Boom/Crash
```

### Étape 2 : Configurer le filtre tendance stricte

```
=== FILTRE TENDANCE STRICTE (EMA + OB + Fibo) ===
UseTrendAlignedEntryFilter = true           // ✅ ACTIVER
RequireOBForEntry = true                    // Exiger Order Block confirmé
RequireOTEFiboZone = true                   // ✅ Exiger zone OTE Fibonacci
BoomCrashRelaxTrendFilterForSpikes = true   // Boom/Crash: relaxer filtre pour spikes
```

### Étape 3 : Ajuster la flexibilité (optionnel)

```
=== Paramètres SMC_OTE flexible ===
OTE_UseFlexibleLogic = true                 // Logique flexible (plus de trades)
OTE_MinRiskPoints = 2.0                     // Risque minimum en points
OTE_ConfluenceTolerance = 0.3               // Tolérance confluence FVG-OTE (30%)
OTE_MaxPositionsPerSymbol = 2               // Max positions par symbole
```

## 📊 Fonctionnement de la stratégie

### Les 3 étapes de la stratégie OTE

1. **ÉTAPE 1 : Identifier la tendance**
   - Détection de la direction (BUY/SELL)
   - Confirmation par EMA multi-timeframe
   - Vérification Order Block dans la direction

2. **ÉTAPE 2 : Détecter les zones d'Imbalance (FVG)**
   - Fair Value Gap (FVG) détecté
   - Zone de déséquilibre prix identifiée

3. **ÉTAPE 3 : Calculer et vérifier la zone OTE**
   - Calcul Fibonacci 0.618-0.786
   - Vérification confluence 5 étoiles
   - Validation prix dans zone d'entrée

### Confluence 5 étoiles

Le robot valide les trades OTE uniquement si :
- ✅ Tendance alignée (EMA stack)
- ✅ Order Block confirmé
- ✅ Zone OTE Fibonacci valide
- ✅ Imbalance (FVG) présent
- ✅ Confiance IA suffisante

## 🎨 Affichage graphique

### Zones affichées sur le graphique

Activez l'affichage des zones Fibonacci :

```
=== Affichage Graphique ===
ShowOTEImbalanceOnChart = true             // ✅ Afficher setup OTE + Imbalance
DrawFibonacciOnChart()                     // Fonction automatique
OTEImbalanceProjectionBars = 120           // Projection visuelle (barres)
```

### Zones visuelles

- **Rectangle OTE** : Zone entre 0.618 et 0.786
- **Lignes horizontales** : Niveaux Fibonacci (0.5, 0.618, 0.786, 0.886)
- **Labels** : Identification des niveaux
- **Projection** : Extension vers la droite (120 barres par défaut)

## 🔧 Paramètres avancés

### Entrées sur niveaux techniques

```
OTE_UseTechnicalLevels = true               // Entrer sur niveaux techniques clés
OTE_SR20_ATR_Tolerance = 0.5               // Support/Résistance 20 barres
OTE_Pivot_ATR_Tolerance = 0.3              // Pivot Daily
OTE_ST_ATR_Tolerance = 0.4                 // Supertrend M5
OTE_TL_ATR_Tolerance = 0.6                 // Trendline
```

### Confiance IA minimum

```
OTE_MinConfidenceForex = 55.0               // Forex : 55% minimum
OTE_MinConfidenceOther = 60.0              // Autres : 60% minimum
```

### Ordres LIMIT vs MARKET

```
OTE_UseLimitOrders = true                  // Entrées OTE via limit (meilleure précision)
```

## 🛡️ Protection anti-spike

La fonction `HasEnoughM1CandlesAfterSpike` est déjà intégrée pour éviter les entrées en queue de mouvement :

```
BoomCrashSmallM1CandlesAfterSpike = 2     // Attendre 2 bougies M1 après spike
```

Cette vérification est appliquée à :
- ExecuteSMC_OTETrade
- ExecuteMarketOnOTEAppearance
- CheckAndExecuteMarketOnOTETouch
- CheckAndExecuteM5TouchEntryTrade

## 📈 Exemple de trade OTE

### Scénario BUY (Tendance haussière)

1. **Mouvement impulsif détecté** : Fort mouvement haussier
2. **Fibonacci étiré** : Du point bas au point haut de l'impulsion
3. **Zone OTE calculée** : Entre 0.618 et 0.786
4. **Ordre placé** : Sur le niveau 0.618 (préféré)
5. **Stop Loss** : Juste sous 0.786 ou sous l'Order Block
6. **Take Profit** : Sur les derniers plus hauts (RR >= 3:1)

### Scénario SELL (Tendance baissière)

1. **Mouvement impulsif détecté** : Fort mouvement baissier
2. **Fibonacci étiré** : Du point haut au point bas de l'impulsion
3. **Zone OTE calculée** : Entre 0.618 et 0.786 (inversé)
4. **Ordre placé** : Sur le niveau 0.618 (préféré)
5. **Stop Loss** : Juste au-dessus de 0.786 ou au-dessus de l'Order Block
6. **Take Profit** : Sur les derniers plus bas (RR >= 3:1)

## ⚠️ Restrictions et filtres

### Marchés autorisés

- ✅ Forex (EURUSD, GBPUSD, etc.)
- ✅ Métaux (XAUUSD, XAGUSD)
- ✅ Commodities (USOIL, etc.)
- ✅ Boom/Crash (avec filtre relaxé pour spikes)
- ❌ Symboles non configurés

### Conditions d'entrée

1. **Tendance identifiée** (EMA stack aligné)
2. **Order Block confirmé** dans la direction
3. **Zone OTE Fibonacci** valide (0.618-0.786)
4. **Imbalance (FVG)** détecté
5. **Confiance IA** >= seuil configuré
6. **Prix dans zone d'entrée**
7. **Anti-spike** : Pas d'entrée immédiate après spike (Boom/Crash)

### Limites de positions

- Maximum 2 positions par symbole (configurable)
- Cooldown entre entrées
- Filtre spread maximum

## 🔍 Dépannage

### Pas de trades OTE ouverts ?

Vérifiez :
1. `UseSMC_OTEStrategy = true`
2. `RequireOTEFiboZone = true`
3. Marché autorisé (`SMC_OTE_AllowXXX = true`)
4. Confiance IA suffisante
5. Tendance identifiée
6. Pas de position déjà ouverte (max 2)

### Zones Fibonacci ne s'affichent pas ?

Vérifiez :
1. `ShowOTEImbalanceOnChart = true`
2. `DrawICTChecklistGraphics = true`
3. Objets graphiques non supprimés manuellement

### Trades trop fréquents ?

Ajustez :
1. `OTE_UseFlexibleLogic = false` (mode strict)
2. `OTE_MaxPositionsPerSymbol = 1`
3. `OTE_MinConfidenceForex = 70.0` (augmenter seuil)
4. `EntryCooldownSeconds = 120` (augmenter cooldown)

## 📚 Références

### Concepts SMC implémentés

- **FVG** : Fair Value Gap (Imbalance)
- **OB** : Order Block
- **BOS** : Break Of Structure
- **OTE** : Optimal Trade Entry (Fibonacci 0.618-0.786)
- **LS** : Liquidity Sweep
- **EQH/EQL** : Equal Highs/Lows
- **P/D** : Premium/Discount

### Fichiers concernés

- `SMC_Universal.mq5` - Robot principal (34759 lignes)
- `Include/SMC_Concepts.mqh` - Bibliothèque SMC
- Fonctions clés : `ExecuteSMC_OTEStrategy()`, `CalculateOTEZone()`, `DrawFibonacciOnChart()`

## 🎯 Recommandations

### Pour débuter avec OTE

1. **Activer en mode test** : `UseSMC_OTEStrategy = true` sur compte démo
2. **Observer les zones** : `ShowOTEImbalanceOnChart = true`
3. **Mode flexible** : `OTE_UseFlexibleLogic = true`
4. **Confiance modérée** : `OTE_MinConfidenceForex = 55.0`
5. **1 position max** : `OTE_MaxPositionsPerSymbol = 1`

### Pour traders expérimentés

1. **Mode strict** : `OTE_UseFlexibleLogic = false`
2. **Filtre tendance** : `UseTrendAlignedEntryFilter = true`
3. **Ordres LIMIT** : `OTE_UseLimitOrders = true`
4. **Confluence 5 étoiles** : Exiger tous les filtres
5. **2 positions max** : `OTE_MaxPositionsPerSymbol = 2`

---

**Note** : La stratégie OTE est déjà pleinement intégrée dans votre robot. Ce guide vous aide à l'activer et à la configurer selon vos préférences.
