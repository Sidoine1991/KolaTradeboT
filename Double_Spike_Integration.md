// INSTRUCTIONS POUR INTÉGRER LA LOGIQUE DE DOUBLE SPIKE
// ==================================================================

// 1. AJOUTER L'APPEL DANS OnTick() APRÈS CheckRealTradingOpportunities():

void OnTick()
{
   // ... code existant ...

   // SCAN MULTI-SYMBOLES - Identifier la meilleure opportunité disponible
   ScanMultiSymbolOpportunities();

   // NOUVELLE FONCTION: Vérification des vraies opportunités de spike
   CheckRealTradingOpportunities();

   // NOUVELLE FONCTION: Gestion des trades de double spike
   CheckAndExecuteDoubleSpikeTrades();

   // ... reste du code OnTick ...
}

// ==================================================================

// LOGIQUE DE DOUBLE SPIKE IMPLÉMENTÉE:

// ✅ DÉTECTION DE TOUCHÉ DE CANAL:
// - Boom: surveille le canal inférieur (support)
// - Crash: surveille le canal supérieur (résistance)

// ✅ PREMIER SPIKE:
// - Détecte le premier spike significatif (>60% range, >100 points)
// - Attend la première petite bougie après le spike
// - Entre en position avec SL/TP basé sur ATR

// ✅ ATTENTE DU SECOND SPIKE:
// - Surveille pendant max 5 petites bougies
// - Si second spike arrive: maintient la position
// - Si pas de second spike: ferme immédiatement

// ✅ SORTIE NORMALE:
// - Après second spike confirmé
// - Sortie à niveau S/R proche:
//   - Boom: résistance proche au-dessus
//   - Crash: support proche en-dessous

// 📊 MESSAGES DE LOG:
// - "🚀 PREMIER SPIKE DÉTECTÉ sur [symbol] après touché canal"
// - "✅ POSITION DOUBLE SPIKE OUVERTE sur [symbol] - Attente second spike"
// - "🎯 SECOND SPIKE DÉTECTÉ sur [symbol] - Position maintenue"
// - "🔄 POSITION DOUBLE SPIKE FERMÉE sur [symbol]"

// 🎯 AVANTAGES:
// - Capture les mouvements de double spike puissants
// - Entre au bon moment (après confirmation premier spike)
// - Sort automatiquement si pas de continuation
// - Utilise les niveaux S/R pour optimiser les sorties

// ==================================================================
