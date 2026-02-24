# Gestion des changements de prédiction IA

## Problème résolu
Le robot exécutait une position dans une direction, mais lorsque la prédiction IA changeait de sens, le trade en cours n'était pas fermé, causant des pertes évitables.

## Solution implémentée

### 1. Variable de suivi des directions
```mql5
// Variable pour suivre la dernière direction de prédiction utilisée
static string g_lastExecutedDirection = "";
```

### 2. Logique de détection de changement
Dans `CheckAndManagePositions()` :

```mql5
// NOUVELLE LOGIQUE: Fermer la position si la prédiction IA change de sens
ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)positionInfo.PositionType();
string currentDirection = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";

// Seulement vérifier le changement si on a une dernière direction enregistrée
if(g_lastExecutedDirection != "")
{
   if(posType == POSITION_TYPE_BUY && g_finalDecision.action == "SELL" && g_lastExecutedDirection == "BUY")
   {
      predictionChanged = true;
      reason = "Prédiction IA passée de BUY à SELL";
   }
   else if(posType == POSITION_TYPE_SELL && g_finalDecision.action == "BUY" && g_lastExecutedDirection == "SELL")
   {
      predictionChanged = true;
      reason = "Prédiction IA passée de SELL à BUY";
   }
}
```

### 3. Conditions de fermeture
- **Changement de direction** : BUY → SELL ou SELL → BUY
- **Confiance minimale** : 65% (évite les fermetures sur faux signaux)
- **Logging détaillé** : Affiche la raison, la confiance et le profit/perte

### 4. Enregistrement des directions
Dans toutes les fonctions d'exécution d'ordres :

**ExecuteMarketOrder() :**
```mql5
if(success)
{
   // Enregistrer la direction exécutée pour le suivi des changements
   g_lastExecutedDirection = (direction == "buy" || direction == "BUY") ? "BUY" : "SELL";
}
```

**ExecuteOrderLogic() (ordres limites Boom/Crash) :**
```mql5
if(trade.BuyLimit(...))
{
   g_lastExecutedDirection = "BUY";
}

if(trade.SellLimit(...))
{
   g_lastExecutedDirection = "SELL";
}
```

## Fonctionnement

### Scénario 1 : BUY → SELL
1. Robot exécute un ordre BUY
2. `g_lastExecutedDirection = "BUY"`
3. Prédiction IA change vers SELL avec 70% de confiance
4. Détection : Position BUY vs Prédiction SELL vs Direction exécutée BUY
5. Fermeture automatique de la position BUY
6. Attente d'une nouvelle entrée SELL

### Scénario 2 : SELL → BUY
1. Robot exécute un ordre SELL
2. `g_lastExecutedDirection = "SELL"`
3. Prédiction IA change vers BUY avec 70% de confiance
4. Détection : Position SELL vs Prédiction BUY vs Direction exécutée SELL
5. Fermeture automatique de la position SELL
6. Attente d'une nouvelle entrée BUY

## Avantages

### ✅ **Protection contre les pertes**
- Fermeture immédiate quand le signal s'inverse
- Évite de maintenir une position contre la tendance

### ✅ **Suivi intelligent**
- Enregistre la direction réellement exécutée
- Compare avec la nouvelle prédiction IA
- Évite les fausses détections

### ✅ **Seuil de confiance**
- Minimum 65% pour éviter les réactions excessives
- Protège contre le bruit de marché

### ✅ **Logging complet**
- Affiche la raison du changement
- Montre le profit/perte au moment de la fermeture
- Facilite le debugging

## Messages dans les logs

```
🔄 CHANGEMENT DE PRÉDICTION IA - FERMETURE POSITION:
   📍 Position actuelle: BUY
   🧠 Nouvelle prédiction: SELL
   📊 Confiance: 72.5%
   📝 Raison: Prédiction IA passée de BUY à SELL
   💰 Profit/Perte: -2.35$
✅ Position fermée suite au changement de prédiction IA
```

## Résultat attendu

Le robot va maintenant :
1. **Fermer automatiquement** les positions quand la prédiction IA s'inverse
2. **Attendre une nouvelle entrée** dans la nouvelle direction
3. **Éviter les pertes** dues au maintien de positions contre-tendance
4. **Maximiser les profits** en suivant les changements de direction IA
