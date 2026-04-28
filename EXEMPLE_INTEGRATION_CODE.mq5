//+------------------------------------------------------------------+
//| EXEMPLE_INTEGRATION_CODE.mq5                                     |
//| Exemple concret d'intégration des améliorations OTE+Fibo        |
//| À copier/adapter dans SMC_Universal.mq5                         |
//+------------------------------------------------------------------+

// ═══════════════════════════════════════════════════════════════════
// ÉTAPE 1: AJOUTER L'INCLUDE EN HAUT DU FICHIER
// ═══════════════════════════════════════════════════════════════════

#property copyright "TradBOT Enhanced"
#property version   "2.00"
#property strict

// Autres includes existants...
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// ✅ NOUVEAU: Ajouter cette ligne (le fichier est dans Include/)
#include <SMC_Enhanced_OTE_Capital_Management.mqh>

// ═══════════════════════════════════════════════════════════════════
// ÉTAPE 2: MODIFIER OnInit() POUR INITIALISER LA GESTION CAPITAL
// ═══════════════════════════════════════════════════════════════════

int OnInit()
{
   // ... code existant d'initialisation ...

   Print("═══════════════════════════════════════");
   Print("   SMC UNIVERSAL - VERSION ENHANCED");
   Print("═══════════════════════════════════════");

   // ✅ NOUVEAU: Initialiser la gestion capital intelligente
   InitSmartCapitalManagement();

   // ... reste du code existant ...

   return(INIT_SUCCEEDED);
}

// ═══════════════════════════════════════════════════════════════════
// ÉTAPE 3: AJOUTER DANS OnTick() LES MISES À JOUR
// ═══════════════════════════════════════════════════════════════════

void OnTick()
{
   // ✅ NOUVEAU: Mise à jour état capital (en début de tick)
   UpdateSmartCapitalState();

   // ✅ NOUVEAU: Gestion Break-Even automatique
   ManageBreakEvenProtection();

   // ✅ NOUVEAU: Affichage dashboard capital (toutes les 5 secondes)
   static datetime lastDashUpdate = 0;
   if(TimeCurrent() - lastDashUpdate >= 5)
   {
      DisplayCapitalDashboard();
      lastDashUpdate = TimeCurrent();
   }

   // ... code existant OnTick() ...

   // Exemple: exécution stratégie OTE
   if(UseSMC_OTEStrategy)
   {
      ExecuteSMC_OTEStrategyEnhanced();  // Version améliorée
   }
}

// ═══════════════════════════════════════════════════════════════════
// ÉTAPE 4: CRÉER NOUVELLE VERSION DE LA FONCTION OTE
// ═══════════════════════════════════════════════════════════════════

// ANCIENNE VERSION (à conserver en commentaire pour référence)
/*
void ExecuteFutureOTETrade(string direction, double entryPrice, double swingLow, double swingHigh)
{
   // Validation basique
   if(!ShouldExecuteOTETrade(direction, g_lastAIAction, g_lastAIConfidence, GetCurrentTrendDirection()))
   {
      Print("❌ Trade OTE rejeté - conditions non remplies");
      return;
   }

   // Calcul SL/TP basique
   double stopLoss = (direction == "BUY") ? swingLow : swingHigh;
   double risk = MathAbs(entryPrice - stopLoss);
   double takeProfit = entryPrice + (direction == "BUY" ? risk * 3.0 : -risk * 3.0);

   // Lot fixe ou basique
   double lot = CalculateLotSize();

   // Exécution
   if(direction == "BUY")
      trade.Buy(lot, _Symbol, 0, stopLoss, takeProfit, "OTE_BUY");
   else
      trade.Sell(lot, _Symbol, 0, stopLoss, takeProfit, "OTE_SELL");
}
*/

// ✅ NOUVELLE VERSION AMÉLIORÉE
void ExecuteFutureOTETradeEnhanced(string direction, double entryPrice, double swingLow, double swingHigh, double fibLevel = 0.618)
{
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   Print("🔍 VALIDATION SETUP OTE ENHANCED - ", direction);
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

   // ═══ ÉTAPE 1: CRÉER LE SETUP OTE ═══
   EnhancedOTESetup setup;
   setup.direction = direction;
   setup.entryPrice = entryPrice;
   setup.fibLevel = fibLevel;
   setup.setupTime = TimeCurrent();
   setup.setupAgeBars = 0;

   // Calcul SL/TP
   double risk = MathAbs(entryPrice - (direction == "BUY" ? swingLow : swingHigh));
   setup.stopLoss = (direction == "BUY") ? swingLow : swingHigh;

   // TP avec ratio configurable (minimum 2:1)
   double rrRatio = MathMax(2.0, InpRiskReward);
   setup.takeProfit = entryPrice + (direction == "BUY" ? risk * rrRatio : -risk * rrRatio);

   Print("   📊 Entry: ", DoubleToString(setup.entryPrice, _Digits));
   Print("   🛡️ SL: ", DoubleToString(setup.stopLoss, _Digits), " (-", DoubleToString(risk * 10000, 0), " pts)");
   Print("   🎯 TP: ", DoubleToString(setup.takeProfit, _Digits), " (+", DoubleToString(risk * rrRatio * 10000, 0), " pts)");
   Print("   💎 R:R: 1:", DoubleToString(rrRatio, 1));

   // ═══ ÉTAPE 2: VALIDATION RENFORCÉE ═══
   if(!ValidateEnhancedOTESetup(setup))
   {
      Print("❌ SETUP REJETÉ: ", setup.rejectionReason);
      Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      return;
   }

   // ═══ ÉTAPE 3: CALCUL TAILLE POSITION INTELLIGENTE ═══
   double lot = CalculateSmartPositionSize(_Symbol, setup.entryPrice, setup.stopLoss, g_lastAIConfidence);

   if(lot <= 0.0)
   {
      Print("⏸️ POSITION BLOQUÉE - Trading en pause ou lot invalide");
      Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      return;
   }

   setup.positionSize = lot;

   // ═══ ÉTAPE 4: AFFICHAGE GRAPHIQUE OPTIMISÉ ═══
   DrawEnhancedOTESetup(setup);

   // ═══ ÉTAPE 5: EXÉCUTION DU TRADE ═══
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.sl = setup.stopLoss;
   request.tp = setup.takeProfit;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = "OTE_" + direction + "_" + DoubleToString(fibLevel * 100, 0);
   request.type_filling = ORDER_FILLING_IOC;

   if(!OrderSend(request, result))
   {
      Print("❌ ERREUR EXÉCUTION: ", result.retcode, " - ", result.comment);
      Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      return;
   }

   if(result.retcode == TRADE_RETCODE_DONE)
   {
      Print("✅ TRADE EXÉCUTÉ AVEC SUCCÈS");
      Print("   🎫 Ticket: ", result.order);
      Print("   📦 Lot: ", DoubleToString(lot, 2));
      Print("   💰 Risque: ", DoubleToString(risk * lot * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * SymbolInfoDouble(_Symbol, SYMBOL_POINT), 2), " USD");
      Print("   ⭐ Score qualité: ", DoubleToString(setup.confirmations.qualityScore, 1), "%");
      Print("   ✅ Confirmations: ", setup.confirmations.totalConfirmations, "/8");

      // Notification sonore
      if(EntryTradeSoundFile != "")
         PlaySound(EntryTradeSoundFile);

      // Mise à jour statistiques
      g_capitalState.dailyTradeCount++;
      g_capitalState.lastTradeTime = TimeCurrent();
   }
   else
   {
      Print("⚠️ TRADE PARTIEL OU ÉCHEC: ", result.retcode);
   }

   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
}

// ═══════════════════════════════════════════════════════════════════
// ÉTAPE 5: AMÉLIORER DrawOTESetup() EXISTANTE
// ═══════════════════════════════════════════════════════════════════

// VERSION ORIGINALE (garder en commentaire)
/*
void DrawOTESetup(double entryPrice, double stopLoss, double takeProfit, string direction)
{
   ObjectsDeleteAll(0, "OTE_SETUP_");

   datetime now = TimeCurrent();
   datetime endTime = now + PeriodSeconds(PERIOD_CURRENT) * 40;

   // Zone d'entrée OTE
   string entryZone = "OTE_SETUP_ENTRY_ZONE";
   ObjectCreate(0, entryZone, OBJ_RECTANGLE, 0, now, entryPrice, endTime, stopLoss);
   ObjectSetInteger(0, entryZone, OBJPROP_COLOR, (direction == "BUY") ? clrDodgerBlue : clrCrimson);
   ObjectSetInteger(0, entryZone, OBJPROP_BACK, true);

   // Labels avec GRANDE POLICE
   string entryLabel = "OTE_SETUP_ENTRY_LABEL";
   ObjectCreate(0, entryLabel, OBJ_TEXT, 0, now, entryPrice);
   ObjectSetString(0, entryLabel, OBJPROP_TEXT, "OTE Entry " + direction + " @" + DoubleToString(entryPrice, _Digits));
   ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 10);  // TROP GRAND

   string title = "OTE_SETUP_TITLE";
   ObjectCreate(0, title, OBJ_TEXT, 0, now, entryPrice);
   ObjectSetString(0, title, OBJPROP_TEXT, "⚡ OTE SETUP - " + direction + " ⚡");
   ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 12);  // TROP GRAND
}
*/

// ✅ VERSION OPTIMISÉE (polices réduites, affichage compact)
void DrawOTESetup(double entryPrice, double stopLoss, double takeProfit, string direction)
{
   // Supprimer anciens objets
   ObjectsDeleteAll(0, "OTE_SETUP_");

   datetime now = TimeCurrent();
   datetime endTime = now + PeriodSeconds(PERIOD_CURRENT) * 40;

   color setupColor = (direction == "BUY") ? Chart_OTE_BuyColor : Chart_OTE_SellColor;

   // ✅ Zone OTE avec TRANSPARENCE élevée
   string entryZone = "OTE_SETUP_ENTRY_ZONE";
   ObjectCreate(0, entryZone, OBJ_RECTANGLE, 0, now, entryPrice, endTime, entryPrice - MathAbs(entryPrice - stopLoss) * 0.2);
   ObjectSetInteger(0, entryZone, OBJPROP_COLOR, setupColor);
   ObjectSetInteger(0, entryZone, OBJPROP_FILL, true);
   ObjectSetInteger(0, entryZone, OBJPROP_BACK, true);
   ObjectSetInteger(0, entryZone, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, entryZone, OBJPROP_STYLE, STYLE_DOT);

   // ✅ Ligne entrée (fine)
   string entryLine = "OTE_SETUP_ENTRY_LINE";
   ObjectCreate(0, entryLine, OBJ_TREND, 0, now, entryPrice, endTime, entryPrice);
   ObjectSetInteger(0, entryLine, OBJPROP_COLOR, setupColor);
   ObjectSetInteger(0, entryLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, entryLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entryLine, OBJPROP_RAY_RIGHT, false);

   // ✅ Ligne SL (rouge, fine)
   string slLine = "OTE_SETUP_SL_LINE";
   ObjectCreate(0, slLine, OBJ_TREND, 0, now, stopLoss, endTime, stopLoss);
   ObjectSetInteger(0, slLine, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, slLine, OBJPROP_RAY_RIGHT, false);

   // ✅ Ligne TP (vert, fine)
   string tpLine = "OTE_SETUP_TP_LINE";
   ObjectCreate(0, tpLine, OBJ_TREND, 0, now, takeProfit, endTime, takeProfit);
   ObjectSetInteger(0, tpLine, OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(0, tpLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, tpLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, tpLine, OBJPROP_RAY_RIGHT, false);

   // ✅ Labels COMPACTS avec PETITES POLICES
   if(!UseMinimalLabels)
   {
      // Label entrée (7pt au lieu de 10pt)
      string entryLabel = "OTE_SETUP_ENTRY_LABEL";
      ObjectCreate(0, entryLabel, OBJ_TEXT, 0, now, entryPrice);

      string labelText = direction + " @" + DoubleToString(entryPrice, _Digits);
      if(Chart_UseCompactDisplay && StringLen(labelText) > Chart_MaxLabelLength)
         labelText = StringSubstr(labelText, 0, Chart_MaxLabelLength);

      ObjectSetString(0, entryLabel, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, entryLabel, OBJPROP_COLOR, setupColor);
      ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 7);  // ✅ RÉDUIT de 10 à 7
      ObjectSetString(0, entryLabel, OBJPROP_FONT, "Arial");

      // Label SL (7pt au lieu de 9pt)
      string slLabel = "OTE_SETUP_SL_LABEL";
      ObjectCreate(0, slLabel, OBJ_TEXT, 0, now, stopLoss);
      ObjectSetString(0, slLabel, OBJPROP_TEXT, "SL");
      ObjectSetInteger(0, slLabel, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, slLabel, OBJPROP_FONTSIZE, 7);  // ✅ RÉDUIT de 9 à 7

      // Label TP (7pt au lieu de 9pt)
      string tpLabel = "OTE_SETUP_TP_LABEL";
      ObjectCreate(0, tpLabel, OBJ_TEXT, 0, now, takeProfit);
      ObjectSetString(0, tpLabel, OBJPROP_TEXT, "TP");
      ObjectSetInteger(0, tpLabel, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(0, tpLabel, OBJPROP_FONTSIZE, 7);  // ✅ RÉDUIT de 9 à 7

      // Titre compact (8pt au lieu de 12pt)
      string title = "OTE_SETUP_TITLE";
      ObjectCreate(0, title, OBJ_TEXT, 0, now, entryPrice + MathAbs(entryPrice - stopLoss) * 0.3);
      ObjectSetString(0, title, OBJPROP_TEXT, "OTE " + direction);  // ✅ TEXTE RÉDUIT
      ObjectSetInteger(0, title, OBJPROP_COLOR, setupColor);
      ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 8);  // ✅ RÉDUIT de 12 à 8
   }

   ChartRedraw(0);

   Print("🎨 Graphique OTE optimisé affiché - ", direction);
}

// ═══════════════════════════════════════════════════════════════════
// ÉTAPE 6: FONCTION WRAPPER POUR COMPATIBILITÉ
// ═══════════════════════════════════════════════════════════════════

// Cette fonction peut être appelée depuis le code existant
void ExecuteSMC_OTEStrategyEnhanced()
{
   // Vérifier si stratégie OTE activée
   if(!UseSMC_OTEStrategy) return;

   // Analyse des swings pour détection zone OTE
   double swingHigh = 0.0, swingLow = 0.0;
   datetime swingHighTime = 0, swingLowTime = 0;

   // ... code existant pour détecter swings ...
   // (à adapter selon votre implémentation actuelle)

   // Détection direction et zone OTE
   string direction = "";
   double entryPrice = 0.0;
   double fibLevel = 0.618;

   // Exemple simplifié (adapter selon votre logique)
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Si prix dans zone OTE BUY
   if(currentPrice <= swingLow + (swingHigh - swingLow) * 0.786 &&
      currentPrice >= swingLow + (swingHigh - swingLow) * 0.618)
   {
      direction = "BUY";
      entryPrice = currentPrice;
      fibLevel = (currentPrice - swingLow) / (swingHigh - swingLow);
   }
   // Si prix dans zone OTE SELL
   else if(currentPrice >= swingHigh - (swingHigh - swingLow) * 0.786 &&
           currentPrice <= swingHigh - (swingHigh - swingLow) * 0.618)
   {
      direction = "SELL";
      entryPrice = currentPrice;
      fibLevel = (swingHigh - currentPrice) / (swingHigh - swingLow);
   }

   // Exécuter avec validation renforcée
   if(direction != "")
   {
      ExecuteFutureOTETradeEnhanced(direction, entryPrice, swingLow, swingHigh, fibLevel);
   }
}

// ═══════════════════════════════════════════════════════════════════
// ÉTAPE 7: EXEMPLE D'UTILISATION DANS LE CODE EXISTANT
// ═══════════════════════════════════════════════════════════════════

/*
// AVANT (dans votre code existant)
void OnTick()
{
   if(UseSMC_OTEStrategy)
   {
      // Ancienne logique
      AnalyzeFutureOTEZones(swingHigh, swingLow, swingHighTime, swingLowTime);

      if(HasActiveValidOTESetupForDirection("BUY"))
      {
         ExecuteFutureOTETrade("BUY", entryPrice, swingLow, swingHigh);
      }
   }
}

// APRÈS (nouvelle logique améliorée)
void OnTick()
{
   // Mise à jour capital
   UpdateSmartCapitalState();
   ManageBreakEvenProtection();
   DisplayCapitalDashboard();

   if(UseSMC_OTEStrategy)
   {
      // ✅ Nouvelle logique avec validations renforcées
      AnalyzeFutureOTEZones(swingHigh, swingLow, swingHighTime, swingLowTime);

      if(HasActiveValidOTESetupForDirection("BUY"))
      {
         // Utiliser la nouvelle fonction améliorée
         ExecuteFutureOTETradeEnhanced("BUY", entryPrice, swingLow, swingHigh, 0.618);
      }
   }
}
*/

// ═══════════════════════════════════════════════════════════════════
// NOTES D'INTÉGRATION
// ═══════════════════════════════════════════════════════════════════

/*
COMPATIBILITÉ:
✅ Compatible avec code existant SMC_Universal.mq5
✅ Peut fonctionner en parallèle avec ancienne version
✅ Pas besoin de supprimer l'ancien code

MIGRATION PROGRESSIVE:
1. Tester d'abord avec DrawEnhancedOTESetup() uniquement
2. Puis ajouter ValidateEnhancedOTESetup()
3. Enfin ajouter CalculateSmartPositionSize()
4. Une fois validé, remplacer complètement l'ancienne logique

LOGS À SURVEILLER:
- "✅ Smart Capital Management initialisé"
- "🔍 VALIDATION SETUP OTE ENHANCED"
- "✅ SETUP OTE VALIDÉ" ou "❌ SETUP REJETÉ"
- "✅ TRADE EXÉCUTÉ AVEC SUCCÈS"

ERREURS POSSIBLES:
- Si lot = 0: Capital en pause ou limites atteintes
- Si setup rejeté: Vérifier confirmations manquantes dans les logs
- Si graphique vide: Vérifier ShowOTEImbalanceOnChart = true

PERFORMANCE:
- Moins de trades (normal, c'est voulu)
- Meilleur taux de réussite attendu
- Protection capital activée
*/
