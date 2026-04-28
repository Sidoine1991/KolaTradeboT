//+------------------------------------------------------------------+
//| EXEMPLE D'UTILISATION DE LA VRAIE LOGIQUE D'OPPORTUNITÉS          |
//+------------------------------------------------------------------+

// Cet exemple montre comment remplacer l'ancienne logique qui ne fonctionnait pas
// par la nouvelle logique basée sur les vrais spikes en cours

#include "Real_Spike_Opportunity.mqh"

// Fonction d'exemple pour remplacer l'ancienne logique "meilleure opportunité"
void SelectRealTradingOpportunity()
{
   // Liste des symboles à analyser (adaptez selon vos besoins)
   string symbols[6] = {
      "Boom 500 Index",
      "Boom 1000 Index",
      "Crash 500 Index",
      "Crash 1000 Index",
      "Volatility 25 Index",
      "Volatility 50 Index"
   };

   Print("🔍 ANALYSE DES VRAIES OPPORTUNITÉS DE SPIKE...");

   // Utiliser la NOUVELLE logique (remplace l'ancienne qui était incorrecte)
   SymbolSpikeData bestOpportunities[2];
   string bestSymbol = FindBestSpikeOpportunities(symbols, bestOpportunities, 2);

   if(bestSymbol != "") {
      Print("✅ OPPORTUNITÉ VALIDÉE - Prêt pour le trading:");
      Print("   🎯 Action recommandée: ", bestOpportunities[0].realDirection > 0 ? "ACHAT" : "VENTE");
      Print("   📊 Confiance: ", DoubleToString(bestOpportunities[0].spikeProbability, 1), "%");

      // Ici vous pouvez déclencher votre logique de trading
      // ExecuteTrade(selectedSymbol, bestOpportunities[0].realDirection, bestOpportunities[0].spikeProbability);

   } else {
      Print("⏸️ Aucune opportunité de spike favorable actuellement");
   }
}

// Fonction pour exécuter un trade basé sur l'analyse réelle
void ExecuteTrade(string symbol, double direction, double confidence)
{
   if(confidence < 60.0) {
      Print("⚠️ Confiance insuffisante (", DoubleToString(confidence, 1), "% < 60%) - Trade annulé");
      return;
   }

   // Ici votre logique d'exécution de trade
   // Vérifier les conditions habituelles (capital, positions ouvertes, etc.)

   Print("🚀 TRADE EXÉCUTÉ sur ", symbol, " - Direction: ", direction > 0 ? "BUY" : "SELL");
}

// Fonction appelée périodiquement pour analyser les opportunités
void OnOpportunityCheck()
{
   static datetime lastCheck = 0;
   datetime currentTime = TimeCurrent();

   // Vérifier toutes les 5 minutes
   if(currentTime - lastCheck >= 300) {
      lastCheck = currentTime;
      SelectRealTradingOpportunity();
   }
}
