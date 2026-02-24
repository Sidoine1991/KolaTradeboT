# Ordres limites en mode WAITING avec flèche DERIV

## Problème résolu
Le robot ne plaçait pas d'ordres limites quand la décision était "WAITING", même si une flèche DERIV était affichée sur le graphique.

## Solution implémentée

### 1. Détection de flèche DERIV en mode WAITING
Dans `ExecuteOrderLogic()` :

```mql5
// NOUVEAU: Permettre les ordres limites même en WAITING si flèche DERIV présente
if(g_finalDecision.action == "WAIT" || g_finalDecision.action == "HOLD")
{
   bool hasDerivArrow = IsDerivArrowPresent();
   
   if(hasDerivArrow)
   {
      Print("🔄 MODE WAITING MAIS FLÈCHE DERIV DÉTECTÉE - ORDRE LIMITE AUTORISÉ");
      Print("   📍 DÉCISION: ", g_finalDecision.action);
      Print("   🏹 Flèche DERIV présente: OUI");
      Print("   🧠 Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
      Print("   📊 Action IA: ", g_lastAIAction);
      
      // Exécuter un ordre limite basé sur la direction de la flèche DERIV
      ExecuteAutoLimitOrder();
      return; // Exécuter et sortir
   }
   else
   {
      if(DebugMode)
         Print("⏸️ Mode WAITING - Pas de flèche DERIV détectée, attente...");
   }
}
```

### 2. Adaptation de la direction en mode WAITING
Dans `ExecuteAutoLimitOrder()` :

```mql5
// DÉTERMINER LA DIRECTION À UTILISER
string directionToUse = g_finalDecision.action;

// Si on est en mode WAITING/HOLD, utiliser la direction de la flèche DERIV
if(g_finalDecision.action == "WAIT" || g_finalDecision.action == "HOLD")
{
   directionToUse = g_lastAIAction; // Utilise la direction de la flèche DERIV
   Print("🔄 Mode WAITING - Utilisation direction flèche DERIV: ", directionToUse);
}
```

### 3. Fonction de détection de flèche DERIV
```mql5
bool IsDerivArrowPresent()
{
   string arrowName = "DERIV_ARROW_" + _Symbol;
   
   // Vérifier si l'objet flèche existe sur le chart
   if(ObjectFind(0, arrowName) >= 0)
   {
      ENUM_OBJECT objectType = (ENUM_OBJECT)ObjectGetInteger(0, arrowName, OBJPROP_TYPE);
      if(objectType == OBJ_ARROW_UP || OBJ_ARROW_DOWN)
      {
         if(DebugMode)
            Print("✅ Flèche DERIV détectée sur le chart: ", arrowName);
         return true;
      }
   }
   
   if(DebugMode)
      Print("❌ Aucune flèche DERIV détectée sur le chart");
   return false;
}
```

## Fonctionnement

### Scénario normal (non-WAITING)
- **Décision BUY/SELL** : Utilise la logique standard
- **Confiance > 70%** : Ordre limite automatique

### Scénario WAITING avec flèche DERIV
1. **Décision WAITING** détectée
2. **Vérification** : Présence de flèche DERIV ?
3. **Si flèche présente** :
   - Récupère la direction de la flèche (`g_lastAIAction`)
   - Place un ordre limite dans cette direction
   - Utilise les supports/résistances M1
   - SL/TP adaptés au marché

### Scénario WAITING sans flèche DERIV
- **Pas de flèche** : Attente, aucun ordre placé
- **Debug mode** : Message "Mode WAITING - Pas de flèche DERIV détectée"

## Messages dans les logs

```
🔄 MODE WAITING MAIS FLÈCHE DERIV DÉTECTÉE - ORDRE LIMITE AUTORISÉ
   📍 DÉCISION: WAIT
   🏹 Flèche DERIV présente: OUI
   🧠 Confiance IA: 85.2%
   📊 Action IA: BUY
🔄 Mode WAITING - Utilisation direction flèche DERIV: BUY
✅ ORDRE LIMIT BUY AUTOMATIQUE PLACÉ:
   📍 Prix limite: 7835.8
   📊 Support M1: 7834.2
   💰 Prix actuel: 7836.1
   🧠 Confiance IA: 85.2%
```

## Avantages

### ✅ **Flexibilité accrue**
- Permet les entrées même en mode WAITING
- Utilise les signaux visuels DERIV comme confirmation

### ✅ **Logique intelligente**
- Détecte automatiquement la présence de flèches
- Adapte la direction selon la flèche (BUY/SELL)

### ✅ **Maintien de la sécurité**
- Uniquement si flèche DERIV présente
- Logging complet pour debugging
- Respect des conditions de support/résistance

### ✅ **Compatible avec tous les marchés**
- Fonctionne sur Boom, Crash, Volatility, Forex, etc.
- Adaptation automatique des SL/TP selon le type de marché

## Résultat attendu

Le robot peut maintenant :
1. **Détecter** les flèches DERIV même en mode WAITING
2. **Placer** des ordres limites basés sur la direction de la flèche
3. **Utiliser** les niveaux de support/résistance M1 pour un placement optimal
4. **Maintenir** la sécurité avec logging et conditions appropriées

Cela permet de ne pas manquer des opportunités quand le marché montre des signaux clairs (flèches DERIV) même si la décision globale est en attente.
