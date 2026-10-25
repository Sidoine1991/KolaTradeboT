# GUIDE D'UTILISATION ANGELOFSPIKE ORDER BLOCK

## ETAPES D'INSTALLATION ET CONFIGURATION

### 1. COMPILATION DU ROBOT
1. Ouvrez MetaTrader 5
2. Allez dans **Navigator** → **Expert Advisors**
3. Clic droit sur **AngelOfSpike** → **Modifier**
4. Le fichier `AngelOfSpike.mq5` s'ouvre dans MetaEditor
5. Cliquez sur **Compile** (F7) ou bouton ▶️
6. Vérifiez qu'il n'y a pas d'erreurs de compilation

### 2. ATTACHEMENT SUR LE GRAPHIQUE
1. Ouvrez un graphique **Boom 300 Index** ou **Crash 300 Index**
2. Dans le **Navigator**, glissez-déposez **AngelOfSpike** sur le graphique
3. La fenêtre de paramètres s'ouvre

### 3. CONFIGURATION DES PARAMETRES

#### PARAMETRES ORDER BLOCK (OBLIGATOIRES)
```
✅ InpEnableOrderBlocks = true
✅ InpShowOrderBlocks = true
✅ InpOrderBlockLookback = 50
✅ InpOrderBlockMinVolume = 1.5
✅ InpOrderBlockMaxAge = 100
```

#### PARAMETRES GENERAUX
```
✅ InpEnableTrading = true
✅ InpMagicNumber = 880011
✅ InpAllowedSymbols = "Boom 300 Index,Crash 300 Index,Boom 500 Index,Crash 500 Index"
```

#### PARAMETRES DE RISQUE
```
✅ InpMaxGlobalPositions = 1
✅ InpMaxPositionsPerSymbol = 1
✅ InpBoomCrashLot = 0.2
✅ InpMaxLotSize = 0.5
```

#### PARAMETRES SL/TP
```
✅ InpMinSLDistance = 10.0
✅ InpMaxSLDistance = 50.0
✅ InpMinTPDistance = 20.0
✅ InpMaxTPDistance = 100.0
✅ InpRiskRewardRatio = 2.0
```

#### PARAMETRES SIGNAL
```
✅ InpTradeOnSpikeImmediately = true
✅ InpShowSpikeArrows = true
✅ InpMinSpikeM1Probability = 30.0
✅ InpArrowBlinkSeconds = 5
```

#### PARAMETRES DEBUG
```
✅ InpDebug = true
✅ InpShowHeartbeat = true
✅ InpSendNotifications = true
```

### 4. DEMARRAGE DU ROBOT
1. Cliquez sur **OK** dans la fenêtre des paramètres
2. Le robot se lance et apparaît dans l'onglet **Experts**
3. Vérifiez les logs dans l'onglet **Experts**

## COMMENT LE ROBOT FONCTIONNE

### ANALYSE AUTOMATIQUE
Le robot analyse automatiquement les bougies pour détecter :
- **Order Blocks Bullish** (zones d'achat)
- **Order Blocks Bearish** (zones de vente)
- **Volume élevé** et **corps de bougie important**
- **Cassures confirmées** dans les bougies suivantes

### AFFICHAGE GRAPHIQUE
Sur le graphique, vous verrez :
- **Rectangles verts** = Order Blocks Bullish (zones d'achat)
- **Rectangles rouges** = Order Blocks Bearish (zones de vente)
- **Labels "OB+"** = Order Block Bullish
- **Labels "OB-"** = Order Block Bearish
- **Flèches clignotantes** = Signaux de trading

### DECLENCHEMENT DES TRADES
Le robot déclenche un trade quand :
1. Un Order Block valide est détecté
2. Le prix s'approche de la zone Order Block
3. La probabilité calculée dépasse le seuil (30%)
4. Aucune position n'existe déjà sur ce symbole
5. Le cooldown entre ordres est respecté

## MONITORING ET LOGS

### LOGS IMPORTANTS À SURVEILLER
```
🚀 ANGELOFSPIKE REQUEST FAILED FIX - INITIALISATION
💓 HEARTBEAT #X - Positions: 0/0 (EA/Total)
🔍 [ORDER BLOCK] Scan terminé pour Boom 300 Index - X Order Blocks détectés
✅ [ORDER BLOCK] Ajouté: Boom 300 Index - BULLISH - Bar: X - Volume: X.XX
🎯 SIGNAL STRICT DETECTE: Boom 300 Index - Direction: BUY - Probabilité: XX%
✅ TRADE STRICT EXECUTE: Boom 300 Index - BUY - Lot: 0.20 - Prix: XXXX - SL: XXXX - TP: XXXX
```

### INDICATEURS DE FONCTIONNEMENT
- **Heartbeat régulier** = Robot actif
- **Order Blocks détectés** = Analyse en cours
- **Signaux générés** = Probabilité calculée
- **Trades exécutés** = Robot fonctionne correctement

## PARAMETRES AVANCES

### OPTIMISATION DES ORDER BLOCKS
```
InpOrderBlockLookback = 50    // Plus élevé = plus de bougies analysées
InpOrderBlockMinVolume = 1.5   // Plus élevé = Order Blocks plus sélectifs
InpOrderBlockMaxAge = 100      // Plus élevé = Order Blocks valides plus longtemps
```

### OPTIMISATION DES SIGNALS
```
InpMinSpikeM1Probability = 30.0  // Plus élevé = signaux plus sélectifs
InpArrowBlinkSeconds = 5          // Durée d'affichage des flèches
```

### GESTION DES RISQUES
```
InpMaxGlobalPositions = 1         // Limite globale des positions
InpMaxPositionsPerSymbol = 1      // Limite par symbole
InpMinSecondsBetweenOrders = 5    // Cooldown entre ordres
```

## DEPANNAGE

### ROBOT NE DECLENCHE PAS DE TRADES
1. Vérifiez que `InpEnableTrading = true`
2. Vérifiez que `InpEnableOrderBlocks = true`
3. Vérifiez les logs pour les Order Blocks détectés
4. Vérifiez que le symbole est dans `InpAllowedSymbols`

### PAS D'AFFICHAGE GRAPHIQUE
1. Vérifiez que `InpShowOrderBlocks = true`
2. Vérifiez que `InpShowSpikeArrows = true`
3. Redémarrez le robot si nécessaire

### ERREURS DE COMPILATION
1. Vérifiez que tous les fichiers sont présents
2. Vérifiez la syntaxe MQL5
3. Consultez les logs d'erreur dans MetaEditor

## CONSEILS D'UTILISATION

### POUR DEBUTER
1. Commencez avec `InpDebug = true` pour voir tous les logs
2. Utilisez des lots petits (`InpBoomCrashLot = 0.1`)
3. Surveillez les logs pendant les premières heures

### POUR OPTIMISER
1. Ajustez `InpOrderBlockMinVolume` selon la volatilité
2. Modifiez `InpMinSpikeM1Probability` selon vos préférences
3. Surveillez les performances sur plusieurs sessions

### POUR LA PRODUCTION
1. Désactivez `InpDebug = false` pour réduire les logs
2. Augmentez les lots progressivement
3. Activez les notifications `InpSendNotifications = true`

## SYMBOLES RECOMMANDES
- **Boom 300 Index** - Volatilité modérée
- **Crash 300 Index** - Volatilité modérée  
- **Boom 500 Index** - Volatilité élevée
- **Crash 500 Index** - Volatilité élevée
- **Boom 1000 Index** - Volatilité très élevée
- **Crash 1000 Index** - Volatilité très élevée

Le robot AngelOfSpike est maintenant prêt à trader avec une vraie stratégie Order Block !
