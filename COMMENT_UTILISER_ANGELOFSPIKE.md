# COMMENT UTILISER LE ROBOT ANGELOFSPIKE ORDER BLOCK

## 🚀 DÉMARRAGE RAPIDE

### Étape 1 : Compilation
1. **Ouvrez MetaTrader 5**
2. **Navigator** → **Expert Advisors** → **AngelOfSpike**
3. **Clic droit** → **Modifier**
4. **Compilez** (F7) ✅

### Étape 2 : Attachement
1. **Ouvrez un graphique** Boom 300 Index ou Crash 300 Index
2. **Glissez-déposez** AngelOfSpike sur le graphique
3. **Configurez les paramètres** (voir ci-dessous)

### Étape 3 : Configuration OBLIGATOIRE
```
✅ InpEnableOrderBlocks = true
✅ InpShowOrderBlocks = true
✅ InpEnableTrading = true
✅ InpDebug = true
```

## 📊 CE QUE VOUS VERREZ

### Sur le Graphique :
- **Rectangles VERT** = Order Blocks Bullish (zones d'achat)
- **Rectangles ROUGE** = Order Blocks Bearish (zones de vente)
- **Labels "OB+"** = Zone d'achat
- **Labels "OB-"** = Zone de vente
- **Flèches clignotantes** = Signaux de trading

### Dans les Logs (Onglet Experts) :
```
🚀 ANGELOFSPIKE REQUEST FAILED FIX - INITIALISATION
💓 HEARTBEAT #1 - Positions: 0/0 (EA/Total)
🔍 [ORDER BLOCK] Scan terminé pour Boom 300 Index - 3 Order Blocks détectés
✅ [ORDER BLOCK] Ajouté: Boom 300 Index - BULLISH - Bar: 15 - Volume: 2.34
🎯 SIGNAL STRICT DETECTE: Boom 300 Index - Direction: BUY - Probabilité: 75%
✅ TRADE STRICT EXECUTE: Boom 300 Index - BUY - Lot: 0.20
```

## ⚙️ PARAMÈTRES RECOMMANDÉS

### Order Block (OBLIGATOIRE)
```
InpEnableOrderBlocks = true      // Active la stratégie
InpShowOrderBlocks = true        // Affiche les zones
InpOrderBlockLookback = 50       // Bougies à analyser
InpOrderBlockMinVolume = 1.5     // Volume minimum
InpOrderBlockMaxAge = 100        // Âge maximum
```

### Trading
```
InpEnableTrading = true          // Active le trading
InpBoomCrashLot = 0.2            // Lot pour Boom/Crash
InpMinSpikeM1Probability = 30.0  // Seuil de probabilité
InpTradeOnSpikeImmediately = true // Trade immédiat
```

### Debug
```
InpDebug = true                  // Logs détaillés
InpShowHeartbeat = true          // Heartbeat régulier
InpSendNotifications = true      // Notifications
```

## 🎯 COMMENT ÇA MARCHE

### 1. Détection Automatique
Le robot scanne les bougies et détecte :
- **Volume élevé** (configurable)
- **Corps de bougie ≥ 60%** de la range
- **Cassure confirmée** dans les 3 bougies suivantes

### 2. Calcul de Probabilité
- **Base** : 30% par Order Block proche
- **Bonus confluence** : +15% si Order Blocks des deux côtés
- **Facteur proximité** : Plus le prix est proche, plus la probabilité est élevée

### 3. Déclenchement des Trades
Un trade est déclenché quand :
- Order Block valide détecté ✅
- Prix proche de la zone ✅
- Probabilité > seuil (30%) ✅
- Aucune position existante ✅
- Cooldown respecté ✅

## 📈 SYMBOLES RECOMMANDÉS

### Volatilité Modérée
- **Boom 300 Index** - Idéal pour débuter
- **Crash 300 Index** - Idéal pour débuter

### Volatilité Élevée
- **Boom 500 Index** - Plus de signaux
- **Crash 500 Index** - Plus de signaux

### Volatilité Très Élevée
- **Boom 1000 Index** - Signaux fréquents
- **Crash 1000 Index** - Signaux fréquents

## 🔍 MONITORING

### Logs Importants à Surveiller
```
💓 HEARTBEAT #X          // Robot actif
🔍 [ORDER BLOCK] Scan    // Analyse en cours
✅ [ORDER BLOCK] Ajouté  // Zone détectée
🎯 SIGNAL STRICT DETECTE // Signal généré
✅ TRADE STRICT EXECUTE  // Trade exécuté
```

### Indicateurs de Bon Fonctionnement
- **Heartbeat régulier** = Robot actif
- **Order Blocks détectés** = Analyse fonctionne
- **Signaux générés** = Probabilité calculée
- **Trades exécutés** = Robot fonctionne parfaitement

## ⚠️ DÉPANNAGE

### Robot Ne Trade Pas
1. Vérifiez `InpEnableTrading = true`
2. Vérifiez `InpEnableOrderBlocks = true`
3. Vérifiez les logs pour les Order Blocks
4. Vérifiez que le symbole est autorisé

### Pas d'Affichage Graphique
1. Vérifiez `InpShowOrderBlocks = true`
2. Vérifiez `InpShowSpikeArrows = true`
3. Redémarrez le robot

### Erreurs de Compilation
1. Vérifiez la syntaxe MQL5
2. Consultez les logs d'erreur dans MetaEditor

## 🎉 RÉSULTATS ATTENDUS

Avec la configuration recommandée, vous devriez voir :
- **Order Blocks détectés** toutes les 5-10 secondes
- **Signaux générés** quand le prix s'approche des zones
- **Trades exécutés** selon l'analyse technique
- **Performance** basée sur la vraie analyse du marché

Le robot AngelOfSpike est maintenant équipé d'une **vraie stratégie Order Block** qui remplace l'ancienne logique aléatoire par une analyse technique réelle !

---

**💡 CONSEIL** : Commencez avec `InpDebug = true` pour voir tous les logs et comprendre le fonctionnement du robot.
