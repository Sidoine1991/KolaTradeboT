//+------------------------------------------------------------------+
//| GUIDE DE DIAGNOSTIC - ROBOT SE DÉTACHE LUI-MÊME               |
//+------------------------------------------------------------------+

/*
PROBLÈME : Le robot ferme automatiquement toutes les positions et se détache

CAUSES POSSIBLES IDENTIFIÉES :

1. 🎯 OBJECTIF DE PROFIT ATTEINT (TotalProfitTarget = 5.0$)
   - Le robot ferme toutes les positions quand le profit total atteint 5$
   - SOLUTION : Désactiver "AutoCloseOnTarget = false"

2. 🔄 TRAILING STOP AGRESSIF
   - Le trailing stop peut fermer les positions si le profit diminue
   - Vérifier les paramètres : InpTrailDist = 300 points

3. 📊 GESTION DES PROFITS AVANCÉE
   - Duplication de positions peut causer des fermetures inattendues
   - Vérifier : UseProfitDuplication = true

4. 🚨 VALIDATION DES STOPS
   - La fonction ValidateStopLevels() peut empêcher certaines modifications
   - Peut causer des fermetures si stops invalides

PARAMÈTRES À VÉRIFIER DANS MT5 :

┌─────────────────────────────────────┐
│ GESTION PROFITS                      │
├─────────────────────────────────────┤
│ UseProfitDuplication = true         │
│ ProfitThresholdForDuplicate = 1.0$   │
│ DuplicationLotSize = 0.4            │
│ TotalProfitTarget = 5.0$            │
│ AutoCloseOnTarget = false ✅         │
│ UseTrailingForProfit = true         │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ TRAILING STOP                       │
├─────────────────────────────────────┤
│ InpUseTrailing = true                │
│ InpTrailDist = 300                   │
└─────────────────────────────────────┘

LOGS À SURVEILLER :

📊 DIAGNOSTIC PROFITS - Total: X.XX$ - Positions: X - AutoClose: OUI/NON
   Position #123456 - Profit: X.XX$
🎯 Objectif de profit atteint: X.XX$ - Fermeture automatique désactivée
🚨 FERMETURE AUTOMATIQUE - Profit: X.XX$ >= Target: 5.0$
✅ Position fermée - Ticket: #123456 - Raison: Profit target reached

SOLUTIONS IMMÉDIATES :

1. ✅ DÉSACTIVER LA FERMETURE AUTOMATIQUE
   - Mettre AutoCloseOnTarget = false
   - Augmenter TotalProfitTarget à 10.0$ ou plus

2. ✅ RÉDUIRE LA FRÉQUENCE DE VÉRIFICATION
   - Augmenter AI_UpdateInterval de 10 à 30 secondes
   - Réduire la fréquence de ManageAdvancedProfits()

3. ✅ AJOUTER DES LOGS DÉTAILLÉS
   - Le code modifié inclut maintenant des logs toutes les 30 secondes
   - Surveiller les logs "DIAGNOSTIC PROFITS"

4. ✅ VÉRIFIER LES STOPS INVALIDES
   - La fonction ValidateStopLevels() empêche les modifications invalides
   - Peut causer des fermetures si les stops sont trop proches

*/

//+------------------------------------------------------------------+
//| FONCTION DE DIAGNOSTIC IMMÉDIAT                               |
//+------------------------------------------------------------------+
void DiagnosticRobotDetachment()
{
   Print("=== DIAGNOSTIC IMMÉDIAT ROBOT ===");
   Print("Positions totales: ", PositionsTotal());
   Print("AutoCloseOnTarget: ", AutoCloseOnTarget ? "OUI" : "NON");
   Print("TotalProfitTarget: ", TotalProfitTarget, "$");
   Print("UseProfitDuplication: ", UseProfitDuplication ? "OUI" : "NON");
   Print("InpUseTrailing: ", InpUseTrailing ? "OUI" : "NON");
   
   double totalProfit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            totalProfit += profit;
            Print("Position #", ticket, " - Profit: ", DoubleToString(profit, 2), "$");
         }
      }
   }
   
   Print("Profit total du robot: ", DoubleToString(totalProfit, 2), "$");
   
   if(AutoCloseOnTarget && totalProfit >= TotalProfitTarget)
   {
      Print("🚨 ALERTE : Le robot va fermer automatiquement toutes les positions !");
      Print("   Solution : Mettre AutoCloseOnTarget = false");
   }
   else
   {
      Print("✅ Pas de fermeture automatique prévue");
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   DiagnosticRobotDetachment();
   return INIT_SUCCEEDED;
}
