//+------------------------------------------------------------------+
//|                     GoldRush_basic.mq5                           |
//|        Version 3.03 LIGHT – Optimisée Anti-Lag MT5                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, User"
#property link      "https://www.mql5.com"
#property version   "3.03"
#property strict

// Inclusions nécessaires
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

//==================== PARAMÈTRES ====================
input double InpLots        = 0.01;
input int    InpStopLoss    = 500;
input int    InpTakeProfit  = 1000;
input int    InpMagicNum    = 123456;
input bool   InpUseTrailing = true;
input int    InpTrailDist   = 300;

//==================== VOLUMES SPÉCIAUX ====================
input double BoomCrashMinLot = 0.2;  // Volume minimum pour Boom/Crash

//==================== GESTION AVANCÉE DES PROFITS ====================
input group "--- GESTION PROFITS ---"
input bool   UseProfitDuplication = true;     // Activer duplication de positions
input double ProfitThresholdForDuplicate = 1.0; // Seuil de profit pour duplication (USD)
input double DuplicationLotSize = 0.4;        // Taille de lot pour duplication
input double TotalProfitTarget = 5.0;         // Objectif de profit total pour fermeture (USD)
input bool   AutoCloseOnTarget = false;          // Fermer automatiquement les positions quand l'objectif est atteint
input bool   UseTrailingForProfit = true;    // Utiliser trailing stop pour sécuriser les profits

//==================== PARAMÈTRES IA ====================
input group "--- INTÉGRATION IA ---"
input bool   UseAI_Agent        = true;
input string AI_ServerURL       = "https://kolatradebot.onrender.com/decision";
input string AI_LocalServerURL  = "http://localhost:8000/decision";
input bool   UseLocalFirst      = true;  // Essayer local d'abord, puis Render en fallback
input double AI_MinConfidence    = 0.70;
input int    AI_Timeout_ms       = 10000;
input int    AI_UpdateInterval   = 10;

//==================== ENDPOINTS RENDER COMPLETS ====================
input group "--- ENDPOINTS RENDER ---"
input string AI_AnalysisURL     = "https://kolatradebot.onrender.com/analysis";
input string TrendAPIURL         = "https://kolatradebot.onrender.com/trend";
input string AI_PredictSymbolURL = "https://kolatradebot.onrender.com/predict";
input string AI_CoherentAnalysisURL = "https://kolatradebot.onrender.com/coherent-analysis";
input string AI_MLPredictURL     = "https://kolatradebot.onrender.com/ml/predict";
input bool   UseAllEndpoints     = true;
input double MinEndpointsConfidence = 0.70;

//==================== PARAMÈTRES TECHNIQUES AVANCÉS ====================
input group "--- ANALYSE TECHNIQUE ---"
input bool   UseMultiTimeframeEMA = true;
input bool   UseSupertrendIndicator = true;
input bool   UseSupportResistance = true;
input int    EMA_Fast_Period      = 12;
input int    EMA_Slow_Period      = 26;
input int    Supertrend_Period    = 10;
input double Supertrend_Multiplier = 3.0;
input int    SR_LookbackBars     = 50;

//==================== PARAMÈTRES AVANCÉS ====================
input group "--- FONCTIONNALITÉS AVANCÉES ---"
input bool   UseDerivArrowDetection = true;
input bool   UseStrongSignalValidation = true;
input bool   UseDynamicSLTP = true;
input bool   UseAdvancedDashboard = true;
input double MinSignalStrength = 0.70;
input int    DashboardRefresh = 5;

//==================== OBJETS ====================
CTrade trade;

//==================== HANDLES (MULTI-TIMEFRAMES) ====================
int emaFast_H1, emaSlow_H1;
int emaFast_M15, emaSlow_M15;
int emaFast_M5, emaSlow_M5;
int emaFast_M1, emaSlow_M1;
int supertrend_H1, supertrend_M15, supertrend_M5, supertrend_M1;
int maFast_M5, maSlow_M5;
int maFast_H1, maSlow_H1;
int rsi_H1, adx_H1, atr_H1;

//==================== CONTRÔLES ====================
datetime lastBarTime = 0;
datetime lastDrawTime = 0;
datetime lastAIUpdate = 0;
string   lastDashText = "";
string   g_lastAIAction = "";
double   g_lastAIConfidence = 0.0;
bool     g_hasPosition = false;
datetime lastDerivArrowCheck = 0;
bool     derivArrowPresent = false;
int      derivArrowType = 0;
datetime lastProfitCheck = 0;
bool     hasDuplicated = false;
double   totalSymbolProfit = 0.0;
ulong    duplicatedPositionTicket = 0;
double   emaFast_H1_val, emaSlow_H1_val;
double   emaFast_M15_val, emaSlow_M15_val;
double   emaFast_M5_val, emaSlow_M5_val;
double   emaFast_M1_val, emaSlow_M1_val;
double   supertrend_H1_val, supertrend_H1_dir;
double   supertrend_M15_val, supertrend_M15_dir;
double   supertrend_M5_val, supertrend_M5_dir;
double   supertrend_M1_val, supertrend_M1_dir;
double   H1_Support, H1_Resistance;
double   M5_Support, M5_Resistance;
string   lastAnalysisData = "";
string   lastTrendData = "";
string   lastPredictionData = "";
string   lastCoherentData = "";
double   endpointsAlignment = 0.0;
datetime lastEndpointUpdate = 0;

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNum);

   emaFast_H1 = iMA(_Symbol, PERIOD_H1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_H1 = iMA(_Symbol, PERIOD_H1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M15 = iMA(_Symbol, PERIOD_M15, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M15 = iMA(_Symbol, PERIOD_M15, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M5 = iMA(_Symbol, PERIOD_M5, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M5 = iMA(_Symbol, PERIOD_M5, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M1 = iMA(_Symbol, PERIOD_M1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M1 = iMA(_Symbol, PERIOD_M1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);

   supertrend_H1 = iCustom(_Symbol, PERIOD_H1, "Supertrend", Supertrend_Period, Supertrend_Multiplier);
   supertrend_M15 = iCustom(_Symbol, PERIOD_M15, "Supertrend", Supertrend_Period, Supertrend_Multiplier);
   supertrend_M5 = iCustom(_Symbol, PERIOD_M5, "Supertrend", Supertrend_Period, Supertrend_Multiplier);
   supertrend_M1 = iCustom(_Symbol, PERIOD_M1, "Supertrend", Supertrend_Period, Supertrend_Multiplier);

   maFast_M5 = iMA(_Symbol, PERIOD_M5, 12, 0, MODE_EMA, PRICE_CLOSE);
   maSlow_M5 = iMA(_Symbol, PERIOD_M5, 26, 0, MODE_EMA, PRICE_CLOSE);
   maFast_H1 = iMA(_Symbol, PERIOD_H1, 12, 0, MODE_EMA, PRICE_CLOSE);
   maSlow_H1 = iMA(_Symbol, PERIOD_H1, 26, 0, MODE_EMA, PRICE_CLOSE);
   rsi_H1 = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
   adx_H1 = iADX(_Symbol, PERIOD_H1, 14);
   atr_H1 = iATR(_Symbol, PERIOD_H1, 14);

   // Vérification des handles (plus critique - ne force plus le détachement)
   bool hasIndicatorErrors = false;
   if(emaFast_H1 == INVALID_HANDLE || emaSlow_H1 == INVALID_HANDLE ||
      emaFast_M15 == INVALID_HANDLE || emaSlow_M15 == INVALID_HANDLE ||
      emaFast_M5 == INVALID_HANDLE || emaSlow_M5 == INVALID_HANDLE ||
      emaFast_M1 == INVALID_HANDLE || emaSlow_M1 == INVALID_HANDLE ||
      supertrend_H1 == INVALID_HANDLE || supertrend_M15 == INVALID_HANDLE ||
      supertrend_M5 == INVALID_HANDLE || supertrend_M1 == INVALID_HANDLE)
   {
      Print("⚠️ Certains indicateurs multi-timeframes n'ont pas pu être créés");
      Print("   Le robot continuera de fonctionner avec les indicateurs disponibles");
      hasIndicatorErrors = true;
   }
   
   if(!hasIndicatorErrors)
   {
      Print("✅ Tous les indicateurs multi-timeframes créés avec succès");
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Diagnostic du détachement
   string reasonText = "";
   switch(reason)
   {
      case REASON_PROGRAM:      reasonText = "Program stopped"; break;
      case REASON_REMOVE:        reasonText = "Program removed from chart"; break;
      case REASON_RECOMPILE:     reasonText = "Program recompiled"; break;
      case REASON_CHARTCHANGE:   reasonText = "Symbol or timeframe changed"; break;
      case REASON_CHARTCLOSE:    reasonText = "Chart closed"; break;
      case REASON_PARAMETERS:    reasonText = "Input parameters changed"; break;
      case REASON_ACCOUNT:       reasonText = "Account changed"; break;
      default:                  reasonText = "Unknown reason"; break;
   }
   
   Print("🚨 DÉTACHEMENT DU ROBOT - Raison: ", reasonText, " (Code: ", reason, ")");
   
   // Empêcher le détachement automatique pour certaines raisons
   if(reason == REASON_PROGRAM || reason == REASON_REMOVE)
   {
      Print("⚠️ Tentative de détachement manuel - Arrêt normal");
   }
   else if(reason == REASON_RECOMPILE)
   {
      Print("🔄 Recompilation du programme - Redémarrage automatique prévu");
   }
   else if(reason == REASON_CHARTCHANGE)
   {
      Print("📊 Changement de symbole/timeframe - Vérification nécessaire");
   }
   else if(reason == REASON_ACCOUNT)
   {
      Print("💰 Changement de compte - Arrêt de sécurité");
   }
   else
   {
      Print("❌ Détachement inattendu - Investigation requise");
   }

   // Libérer les ressources indicateurs
   IndicatorRelease(emaFast_H1);
   IndicatorRelease(emaSlow_H1);
   IndicatorRelease(emaFast_M15);
   IndicatorRelease(emaSlow_M15);
   IndicatorRelease(emaFast_M5);
   IndicatorRelease(emaSlow_M5);
   IndicatorRelease(emaFast_M1);
   IndicatorRelease(emaSlow_M1);
   IndicatorRelease(supertrend_H1);
   IndicatorRelease(supertrend_M15);
   IndicatorRelease(supertrend_M5);
   IndicatorRelease(supertrend_M1);
   IndicatorRelease(maFast_M5);
   IndicatorRelease(maSlow_M5);
   IndicatorRelease(maFast_H1);
   IndicatorRelease(maSlow_H1);
   IndicatorRelease(rsi_H1);
   IndicatorRelease(adx_H1);
   IndicatorRelease(atr_H1);

   // Nettoyer les objets graphiques
   ObjectsDeleteAll(0,"Prediction_");
   ObjectsDeleteAll(0,"MTF_");
   ObjectDelete(0,"Dashboard");
   
   Print("🧹 Nettoyage des ressources terminé");
}

//+------------------------------------------------------------------+
//| SURVEILLANCE DE SANTÉ DU ROBOT                                |
//+------------------------------------------------------------------+
void CheckRobotHealth()
{
   static int errorCount = 0;
   static datetime lastErrorTime = 0;
   
   // Vérifier la connexion au serveur
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Print("❌ Perte de connexion au serveur détectée");
      errorCount++;
      lastErrorTime = TimeCurrent();
   }
   
   // Vérifier si le trading est autorisé
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("❌ Trading non autorisé - Vérifier les paramètres MT5");
      errorCount++;
      lastErrorTime = TimeCurrent();
   }
   
   // Vérifier si le robot peut trader
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("❌ Robot non autorisé à trader - Vérifier les paramètres");
      errorCount++;
      lastErrorTime = TimeCurrent();
   }
   
   // Afficher le rapport de santé
   if(errorCount == 0)
   {
      Print("✅ Robot en bonne santé - Connexion: OK - Trading: OK");
   }
   else
   {
      Print("⚠️ Robot avec ", errorCount, " erreurs - Dernière erreur: ", TimeToString(lastErrorTime));
      
      // Si trop d'erreurs, alerter
      if(errorCount >= 5)
      {
         Print("🚨 NOMBRE D'ERREURS ÉLEVÉ - Risque de détachement!");
      }
   }
   
   // Réinitialiser le compteur d'erreurs après 5 minutes sans erreur
   if(TimeCurrent() - lastErrorTime > 300)
   {
      errorCount = 0;
   }
}

//+------------------------------------------------------------------+
//| ON TICK                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   // Surveillance de santé du robot (toutes les 60 secondes)
   static datetime lastHealthCheck = 0;
   if(TimeCurrent() - lastHealthCheck >= 60)
   {
      lastHealthCheck = TimeCurrent();
      CheckRobotHealth();
   }

   if(InpUseTrailing)
      ManageTrailingStop();

   if(UseProfitDuplication)
      ManageAdvancedProfits();

   if(UseAllEndpoints)
      UpdateAllEndpoints();

   if(UseAI_Agent && TimeCurrent() - lastAIUpdate >= AI_UpdateInterval)
   {
      UpdateAISignal();
      lastAIUpdate = TimeCurrent();
   }

   datetime barTime = iTime(_Symbol, PERIOD_M5, 0);
   if(barTime == lastBarTime)
      return;

   lastBarTime = barTime;

   if(PositionsTotal() > 0)
   {
      g_hasPosition = true;
      return;
   }
   else
   {
      g_hasPosition = false;
      hasDuplicated = false;
      duplicatedPositionTicket = 0;
   }

   if(UseMultiTimeframeEMA || UseSupertrendIndicator)
      UpdateMultiTimeframeData();

   if(UseDerivArrowDetection)
      UpdateDerivArrowDetection();

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   // Vérifier si le symbole est autorisé pour le trading
   if(!IsSymbolAllowedForTrading())
   {
      Print("❌ Trading non autorisé sur ce symbole: ", _Symbol);
      return;
   }

   bool shouldTrade = false;
   ENUM_ORDER_TYPE tradeType = WRONG_VALUE;

   if(UseAllEndpoints && endpointsAlignment >= MinEndpointsConfidence)
   {
      if(endpointsAlignment > 0.6)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("🎯 Signal endpoints Render: ACHAT (alignement: ", DoubleToString(endpointsAlignment*100, 1), "%)");
      }
      else if(endpointsAlignment < 0.4)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("🎯 Signal endpoints Render: VENTE (alignement: ", DoubleToString(endpointsAlignment*100, 1), "%)");
      }
   }
   else if(UseAI_Agent && HasStrongSignal())
   {
      if(StringFind(g_lastAIAction, "buy") >= 0)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
      }
      else if(StringFind(g_lastAIAction, "sell") >= 0)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
      }
   }
   else if(UseMultiTimeframeEMA || UseSupertrendIndicator)
   {
      if(CheckAdvancedTechnicalSignal())
      {
         shouldTrade = true;
         tradeType = GetAdvancedSignalDirection();
      }
   }
   else if(UseDerivArrowDetection && derivArrowPresent)
   {
      if(derivArrowType == 1)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
      }
      else if(derivArrowType == 2)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
      }
   }

   if(shouldTrade && ValidateAdvancedEntry(tradeType))
   {
      // Restrictions spécifiques pour Boom/Crash (sécurité)
      if(StringFind(_Symbol, "Boom") >= 0 && tradeType == ORDER_TYPE_SELL)
      {
         Print("🚨 SÉCURITÉ - Positions SELL interdites sur Boom: ", _Symbol);
         return;
      }
      
      if(StringFind(_Symbol, "Crash") >= 0 && tradeType == ORDER_TYPE_BUY)
      {
         Print("🚨 SÉCURITÉ - Positions BUY interdites sur Crash: ", _Symbol);
         return;
      }
      
      ExecuteAdvancedTrade(tradeType, ask, bid);
   }

   DrawMultiTimeframeIndicators();

   double rsi[], adx[], atr[];
   ArraySetAsSeries(rsi,true);
   ArraySetAsSeries(adx,true);
   ArraySetAsSeries(atr,true);
   if(CopyBuffer(rsi_H1,0,0,1,rsi)>0 && CopyBuffer(adx_H1,0,0,1,adx)>0 && CopyBuffer(atr_H1,0,0,1,atr)>0)
      DrawAdvancedDashboard(rsi[0], adx[0], atr[0]);
}

//+------------------------------------------------------------------+
//| VALIDATION DES STOPS SPÉCIFIQUE BOOM/CRASH                      |
//+------------------------------------------------------------------+
bool ValidateStopLevels(double price, double sl, double tp, bool isBuy)
{
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   
   // Pour Boom/Crash, utiliser une distance minimum plus grande
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      minDistance = MathMax(minDistance, 50 * _Point); // Minimum 50 points pour Boom/Crash
   }
   
   if(isBuy)
   {
      // BUY: SL doit être < prix, TP doit être > prix
      if(sl >= price || tp <= price)
      {
         Print("❌ Stops invalides pour BUY - SL: ", sl, " >= Prix: ", price, " ou TP: ", tp, " <= Prix: ", price);
         return false;
      }
      
      // Vérifier distance minimum
      if(price - sl < minDistance)
      {
         Print("❌ SL trop proche du prix pour BUY - Distance: ", price - sl, " < Minimum: ", minDistance);
         return false;
      }
   }
   else // SELL
   {
      // SELL: SL doit être > prix, TP doit être < prix  
      if(sl <= price || tp >= price)
      {
         Print("❌ Stops invalides pour SELL - SL: ", sl, " <= Prix: ", price, " ou TP: ", tp, " >= Prix: ", price);
         return false;
      }
      
      // Vérifier distance minimum
      if(sl - price < minDistance)
      {
         Print("❌ SL trop proche du prix pour SELL - Distance: ", sl - price, " < Minimum: ", minDistance);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| TRAILING STOP AMÉLIORÉ AVEC VALIDATION                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNum) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long type   = PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);
      string symbol = PositionGetString(POSITION_SYMBOL);

      double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
      
      // Paramètres de trailing adaptés par type de symbole
      double minProfitForTrailing = 0.5;  // Par défaut
      double trailDistance = InpTrailDist * _Point;
      
      // Adaptation pour Step Index, Boom & Crash
      if(StringFind(symbol, "Step") >= 0 || StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
      {
         minProfitForTrailing = 1.0;  // Profit minimum plus élevé
         trailDistance = MathMax(InpTrailDist * _Point, 20 * _Point);  // Distance minimum
         Print("🔧 Trailing adapté pour ", symbol, " - MinProfit: ", minProfitForTrailing, " - TrailDist: ", trailDistance/_Point, " points");
      }

      // Trailing actif si profit suffisant OU si UseTrailingForProfit est désactivé
      if(!UseTrailingForProfit || profit > minProfitForTrailing)
      {
         
         if(type==POSITION_TYPE_BUY)
         {
            double newSL = bid - trailDistance;
            if(profit > 1.0)
               newSL = bid - (trailDistance * 0.5);
            
            // Validation des stops avant modification
            if(ValidateStopLevels(bid, newSL, tp, true) && newSL > sl && newSL > open)
            {
               if(!trade.PositionModify(ticket,newSL,tp))
                  Print("❌ Échec modification SL BUY - Erreur: ", trade.ResultRetcode());
               else
                  Print("✅ SL BUY modifié - Nouveau SL: ", newSL);
            }
         }
         else if(type==POSITION_TYPE_SELL)
         {
            double newSL = ask + trailDistance;
            if(profit > 1.0)
               newSL = ask + (trailDistance * 0.5);
            
            // Validation des stops avant modification
            if(ValidateStopLevels(ask, newSL, tp, false) && (sl == 0 || newSL < sl) && newSL < open)
            {
               if(!trade.PositionModify(ticket,newSL,tp))
                  Print("❌ Échec modification SL SELL - Erreur: ", trade.ResultRetcode());
               else
                  Print("✅ SL SELL modifié - Nouveau SL: ", newSL);
            }
         }
      }
      else
      {
         if(type==POSITION_TYPE_BUY && bid-open>InpTrailDist*_Point)
         {
            double newSL = bid - InpTrailDist*_Point;
            
            // Validation des stops avant modification
            if(ValidateStopLevels(bid, newSL, tp, true) && newSL>sl)
            {
               if(!trade.PositionModify(ticket,newSL,tp))
                  Print("❌ Échec modification SL BUY (normal) - Erreur: ", trade.ResultRetcode());
            }
         }

         if(type==POSITION_TYPE_SELL && open-ask>InpTrailDist*_Point)
         {
            double newSL = ask + InpTrailDist*_Point;
            
            // Validation des stops avant modification
            if(ValidateStopLevels(ask, newSL, tp, false) && (sl==0 || newSL<sl))
            {
               if(!trade.PositionModify(ticket,newSL,tp))
                  Print("❌ Échec modification SL SELL (normal) - Erreur: ", trade.ResultRetcode());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| GESTION AVANCÉE DES PROFITS                                   |
//+------------------------------------------------------------------+
void ManageAdvancedProfits()
{
   if(TimeCurrent() - lastProfitCheck < 1)
      return;

   lastProfitCheck = TimeCurrent();
   
   // Diagnostic détaillé
   static datetime lastDiagnostic = 0;
   if(TimeCurrent() - lastDiagnostic > 30) // Toutes les 30 secondes
   {
      lastDiagnostic = TimeCurrent();
      Print("📊 DIAGNOSTIC PROFITS - Total: ", DoubleToString(totalSymbolProfit, 2), "$ - Positions: ", PositionsTotal(), " - AutoClose: ", AutoCloseOnTarget ? "OUI" : "NON");
   }

   totalSymbolProfit = 0.0;
   double maxPositionProfit = 0.0;
   ulong mostProfitableTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      totalSymbolProfit += profit;
      
      // Log individuel des positions
      if(TimeCurrent() - lastDiagnostic > 30)
      {
         Print("   Position #", ticket, " - Profit: ", DoubleToString(profit, 2), "$");
      }

      if(profit > maxPositionProfit)
      {
         maxPositionProfit = profit;
         mostProfitableTicket = ticket;
      }
   }

   if(AutoCloseOnTarget && totalSymbolProfit >= TotalProfitTarget)
   {
      Print("🚨 FERMETURE AUTOMATIQUE - Profit: ", DoubleToString(totalSymbolProfit, 2), "$ >= Target: ", TotalProfitTarget, "$");
      CloseAllPositionsForSymbol(_Symbol, "Profit target reached: " + DoubleToString(totalSymbolProfit, 2) + "$");
      return;
   }
   else if(totalSymbolProfit >= TotalProfitTarget)
   {
      Print("🎯 Objectif de profit atteint: ", DoubleToString(totalSymbolProfit, 2), "$ - Fermeture automatique désactivée");
   }

   if(!hasDuplicated && maxPositionProfit >= ProfitThresholdForDuplicate)
   {
      if(PositionSelectByTicket(mostProfitableTicket))
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(type == POSITION_TYPE_BUY)
         {
            double sl = bid - InpStopLoss * _Point;
            double tp = bid + InpTakeProfit * _Point;

            if(trade.Buy(GetCorrectLotSize(), _Symbol, ask, sl, tp, "GoldRush Duplication"))
            {
               hasDuplicated = true;
               duplicatedPositionTicket = trade.ResultOrder();
               Print("🚀 Position dupliquée - Lot: ", GetCorrectLotSize(), " - Ticket: ", duplicatedPositionTicket);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double sl = ask + InpStopLoss * _Point;
            double tp = ask - InpTakeProfit * _Point;

            if(trade.Sell(GetCorrectLotSize(), _Symbol, bid, sl, tp, "GoldRush Duplication"))
            {
               hasDuplicated = true;
               duplicatedPositionTicket = trade.ResultOrder();
               Print("🚀 Position dupliquée - Lot: ", GetCorrectLotSize(), " - Ticket: ", duplicatedPositionTicket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FERMER TOUTES LES POSITIONS POUR UN SYMBOLE                |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(string symbol, string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;

      if(trade.PositionClose(ticket))
         Print("✅ Position fermée - Ticket: ", ticket, " - Raison: ", reason);
   }

   hasDuplicated = false;
   duplicatedPositionTicket = 0;
   totalSymbolProfit = 0.0;
}

//+------------------------------------------------------------------+
//| OBTENIR LE VOLUME CORRECT POUR LE SYMBOLE                  |
//+------------------------------------------------------------------+
double GetCorrectLotSize()
{
   string symbol = _Symbol;
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Pour Or, Forex, Boom et Crash : utiliser uniquement le lot minimum du broker
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "Gold") >= 0 ||  // Or
      StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "Silver") >= 0 ||  // Argent
      StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 ||  // Boom/Crash
      StringFind(symbol, "Volatility") >= 0)  // Volatility Indices
   {
      Print("📊 Symbole à risque détecté: ", symbol);
      Print("   Lot minimum broker: ", minLot);
      Print("   Lot maximum broker: ", maxLot);
      Print("   Step lot: ", stepLot);
      Print("   ⚠️ Utilisation du lot minimum pour sécurité");
      
      // Arrondir au step le plus proche
      double adjustedLot = MathRound(minLot / stepLot) * stepLot;
      adjustedLot = MathMax(adjustedLot, minLot);
      
      Print("   ✅ Lot ajusté: ", adjustedLot);
      return adjustedLot;
   }
   
   // Pour les autres symboles (Forex standard), utiliser la logique normale
   if(StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 || 
      StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
      StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "CAD") >= 0 ||
      StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "NZD") >= 0)
   {
      // Pour Forex standard, utiliser aussi le lot minimum pour plus de sécurité
      Print("📊 Symbole Forex détecté: ", symbol);
      Print("   Lot minimum broker: ", minLot);
      Print("   ⚠️ Utilisation du lot minimum pour sécurité");
      
      double adjustedLot = MathRound(minLot / stepLot) * stepLot;
      adjustedLot = MathMax(adjustedLot, minLot);
      
      Print("   ✅ Lot ajusté: ", adjustedLot);
      return adjustedLot;
   }

   // Pour tous les autres symboles, utiliser InpLots avec validation
   double finalLot = MathMax(InpLots, minLot);
   finalLot = MathRound(finalLot / stepLot) * stepLot;
   finalLot = MathMin(finalLot, maxLot);
   
   Print("📊 Symbole standard: ", symbol);
   Print("   Lot configuré: ", finalLot);
   
   return finalLot;
}

//+------------------------------------------------------------------+
//| MISE À JOUR SIGNAL IA                                      |
//+------------------------------------------------------------------+
void UpdateAISignal()
{
   if(!UseAI_Agent) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Récupérer les valeurs des indicateurs si disponibles
   double rsiValue = 50.0; // Valeur par défaut
   double atrValue = 0.0;  // Valeur par défaut
   
   if(rsi_H1 != INVALID_HANDLE)
   {
      double rsiBuffer[1];
      if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuffer) > 0)
         rsiValue = rsiBuffer[0];
   }
   
   if(atr_H1 != INVALID_HANDLE)
   {
      double atrBuffer[1];
      if(CopyBuffer(atr_H1, 0, 0, 1, atrBuffer) > 0)
         atrValue = atrBuffer[0];
   }
   
   // Créer le JSON complet correspondant au modèle DecisionRequest
   string data = "{" +
                  "\"symbol\":\"" + _Symbol + "\"," +
                  "\"bid\":" + DoubleToString(bid, 5) + "," +
                  "\"ask\":" + DoubleToString(ask, 5) + "," +
                  "\"rsi\":" + DoubleToString(rsiValue, 2) + "," +
                  "\"atr\":" + DoubleToString(atrValue, 5) + "," +
                  "\"is_spike_mode\":false," +
                  "\"dir_rule\":0," +
                  "\"supertrend_trend\":0," +
                  "\"volatility_regime\":0," +
                  "\"volatility_ratio\":1.0" +
                  "}";

   // LOG TRÈS VISIBLE - Afficher le JSON exact envoyé
   Print("📦 DONNÉES JSON COMPLÈTES: ", data);
   Print("🆕 FORMAT MIS À JOUR - Compatible avec modèle DecisionRequest");
   Print("📏 Taille JSON: ", StringLen(data), " caractères");

   uchar post_uchar[];
   StringToCharArray(data, post_uchar);

   uchar result[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n";
   
   int res = -1;
   string usedURL = "";
   bool useLocal = UseLocalFirst;
   
   // Stratégie de fallback
   if(useLocal)
   {
      // 1. Essayer le serveur local en premier
      Print("🌐 Tentative serveur LOCAL: ", AI_LocalServerURL);
      usedURL = AI_LocalServerURL;
      res = WebRequest("POST", usedURL, headers, 5000, post_uchar, result, result_headers);
      
      if(res == 200)
      {
         Print("✅ Serveur LOCAL répond - Signal obtenu");
      }
      else
      {
         Print("❌ Serveur LOCAL indisponible (Code: ", res, ") - Fallback vers Render");
         // 2. Fallback vers Render
         usedURL = AI_ServerURL;
         res = WebRequest("POST", usedURL, headers, AI_Timeout_ms, post_uchar, result, result_headers);
         
         if(res == 200)
         {
            Print("✅ Fallback Render réussi - Signal obtenu");
         }
         else
         {
            Print("❌ Échec complet - Local (", AI_LocalServerURL, ") et Render (", AI_ServerURL, ") indisponibles");
         }
      }
   }
   else
   {
      // Utiliser directement Render
      usedURL = AI_ServerURL;
      res = WebRequest("POST", usedURL, headers, AI_Timeout_ms, post_uchar, result, result_headers);
      Print("🌐 Utilisation directe Render: ", usedURL);
   }

   // Log de la requête pour diagnostic
   Print("   📦 Données envoyées: ", data);
   Print("   📍 URL utilisée: ", usedURL);
   Print("   📊 Résultat: ", res, " (", res == 200 ? "Succès" : "Échec", ")");

   if(res == 200)
   {
      string json = CharArrayToString(result);
      if(StringFind(json, "buy") >= 0)
      {
         g_lastAIAction = "buy";
         int conf_pos = StringFind(json, "confidence");
         if(conf_pos > 0)
         {
            string conf_str = StringSubstr(json, conf_pos + 12, 4);
            g_lastAIConfidence = StringToDouble(conf_str);
         }
      }
      else if(StringFind(json, "sell") >= 0)
      {
         g_lastAIAction = "sell";
         int conf_pos = StringFind(json, "confidence");
         if(conf_pos > 0)
         {
            string conf_str = StringSubstr(json, conf_pos + 12, 4);
            g_lastAIConfidence = StringToDouble(conf_str);
         }
      }
      
      string serverType = (usedURL == AI_LocalServerURL) ? "LOCAL" : "RENDER";
      Print("✅ IA Signal [", serverType, "]: ", g_lastAIAction, " (confiance: ", g_lastAIConfidence, ")");
   }
   else
   {
      Print("❌ Erreur IA: Code ", res, " - URL: ", usedURL);
      if(res == 422)
      {
         Print("   ❌ Erreur 422 - Format JSON invalide");
         Print("    Vérifier le format DecisionRequest");
         Print("   📍 Symbol: ", _Symbol, " - Bid: ", bid, " - Ask: ", ask);
         Print("   📊 RSI: ", rsiValue, " - ATR: ", atrValue);
      }
      else if(res == 0)
      {
         Print("   ❌ Erreur connexion - Serveur inaccessible");
      }
      else
      {
         Print("   📄 Réponse serveur: ", CharArrayToString(result));
      }
      
      // En cas d'échec total, essayer de générer un signal de secours
      GenerateFallbackSignal();
   }
}

//+------------------------------------------------------------------+
//| GÉNÉRER SIGNAL DE SECOURS (FALLBACK)                     |
//+------------------------------------------------------------------+
void GenerateFallbackSignal()
{
   // Générer un signal basé sur l'analyse technique simple
   double rsiValue = 50.0;
   double atrValue = 0.0;
   
   if(rsi_H1 != INVALID_HANDLE)
   {
      double rsiBuffer[1];
      if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuffer) > 0)
         rsiValue = rsiBuffer[0];
   }
   
   if(atr_H1 != INVALID_HANDLE)
   {
      double atrBuffer[1];
      if(CopyBuffer(atr_H1, 0, 0, 1, atrBuffer) > 0)
         atrValue = atrBuffer[0];
   }
   
   // Logique simple de fallback basée sur RSI
   if(rsiValue < 30)
   {
      g_lastAIAction = "buy";
      g_lastAIConfidence = 0.65; // Confiance modérée pour fallback
      Print("🔄 Signal de secours [FALLBACK]: BUY (RSI: ", DoubleToString(rsiValue, 2), " < 30)");
   }
   else if(rsiValue > 70)
   {
      g_lastAIAction = "sell";
      g_lastAIConfidence = 0.65; // Confiance modérée pour fallback
      Print("🔄 Signal de secours [FALLBACK]: SELL (RSI: ", DoubleToString(rsiValue, 2), " > 70)");
   }
   else
   {
      g_lastAIAction = "hold";
      g_lastAIConfidence = 0.50; // Faible confiance en zone neutre
      Print("🔄 Signal de secours [FALLBACK]: HOLD (RSI: ", DoubleToString(rsiValue, 2), " neutre)");
   }
   
   Print("   ⚠️ ModeFallback activé - Confiance réduite à ", g_lastAIConfidence);
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI LE SYMBOLE EST AUTORISÉ POUR LE TRADING       |
//+------------------------------------------------------------------+
bool IsSymbolAllowedForTrading()
{
   string symbol = _Symbol;
   
   // Symboles explicitement autorisés
   bool isAllowed = (
      StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "USD") >= 0 ||  // Forex
      StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
      StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "CAD") >= 0 ||
      StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "NZD") >= 0 ||
      StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "Gold") >= 0 ||  // Or
      StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "Silver") >= 0 ||  // Argent
      StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 ||  // Boom/Crash
      StringFind(symbol, "Step") >= 0 || StringFind(symbol, "Index") >= 0 ||  // Step Index
      StringFind(symbol, "Volatility") >= 0  // Volatility Indices
   );
   
   if(isAllowed)
   {
      Print("✅ Symbole autorisé pour trading: ", symbol);
   }
   else
   {
      Print("❌ Symbole non autorisé pour trading: ", symbol);
   }
   
   return isAllowed;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI SIGNAL FORT PRÉSENT                             |
//+------------------------------------------------------------------+
bool HasStrongSignal()
{
   // Vérifier si le symbole est autorisé pour le trading
   if(!IsSymbolAllowedForTrading())
   {
      Print("❌ Trading non autorisé sur ce symbole: ", _Symbol);
      return false;
   }

   return (g_lastAIConfidence >= AI_MinConfidence &&
           (StringFind(g_lastAIAction, "buy") >= 0 || StringFind(g_lastAIAction, "sell") >= 0));
}

//+------------------------------------------------------------------+
//| MISE À JOUR DÉTECTION DERIV ARROW                          |
//+------------------------------------------------------------------+
void UpdateDerivArrowDetection()
{
   if(TimeCurrent() - lastDerivArrowCheck < 5)
      return;

   lastDerivArrowCheck = TimeCurrent();

   derivArrowPresent = false;
   derivArrowType = 0;

   for(int i = 0; i < ObjectsTotal(0); i++)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "DERIV") >= 0 || StringFind(objName, "ARROW") >= 0)
      {
         long arrowCode = ObjectGetInteger(0, objName, OBJPROP_ARROWCODE);
         if(arrowCode == 241)
         {
            derivArrowPresent = true;
            derivArrowType = 1;
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
         }
         else if(arrowCode == 242)
         {
            derivArrowPresent = true;
            derivArrowType = 2;
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MISE À JOUR DES DONNÉES MULTI-TIMEFRAMES                    |
//+------------------------------------------------------------------+
void UpdateMultiTimeframeData()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 10)
      return;

   lastUpdate = TimeCurrent();

   if(UseMultiTimeframeEMA)
   {
      double fastBuffer[1], slowBuffer[1];

      // Protection : vérifier les handles avant CopyBuffer
      if(emaFast_H1 != INVALID_HANDLE && emaSlow_H1 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_H1, 0, 0, 1, fastBuffer) > 0)
            emaFast_H1_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_H1, 0, 0, 1, slowBuffer) > 0)
            emaSlow_H1_val = slowBuffer[0];
      }
      
      if(emaFast_M15 != INVALID_HANDLE && emaSlow_M15 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_M15, 0, 0, 1, fastBuffer) > 0)
            emaFast_M15_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_M15, 0, 0, 1, slowBuffer) > 0)
            emaSlow_M15_val = slowBuffer[0];
      }
      
      if(emaFast_M5 != INVALID_HANDLE && emaSlow_M5 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_M5, 0, 0, 1, fastBuffer) > 0)
            emaFast_M5_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_M5, 0, 0, 1, slowBuffer) > 0)
            emaSlow_M5_val = slowBuffer[0];
      }
      
      if(emaFast_M1 != INVALID_HANDLE && emaSlow_M1 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_M1, 0, 0, 1, fastBuffer) > 0)
            emaFast_M1_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_M1, 0, 0, 1, slowBuffer) > 0)
            emaSlow_M1_val = slowBuffer[0];
      }
   }

   if(UseSupertrendIndicator)
   {
      double valueBuffer[1], dirBuffer[1];

      // Protection : vérifier les handles avant CopyBuffer
      if(supertrend_H1 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_H1, 0, 0, 1, valueBuffer) > 0)
            supertrend_H1_val = valueBuffer[0];
         if(CopyBuffer(supertrend_H1, 1, 0, 1, dirBuffer) > 0)
            supertrend_H1_dir = dirBuffer[0];
      }

      if(supertrend_M15 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_M15, 0, 0, 1, valueBuffer) > 0)
            supertrend_M15_val = valueBuffer[0];
         if(CopyBuffer(supertrend_M15, 1, 0, 1, dirBuffer) > 0)
            supertrend_M15_dir = dirBuffer[0];
      }

      if(supertrend_M5 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_M5, 0, 0, 1, valueBuffer) > 0)
            supertrend_M5_val = valueBuffer[0];
         if(CopyBuffer(supertrend_M5, 1, 0, 1, dirBuffer) > 0)
            supertrend_M5_dir = dirBuffer[0];
      }

      if(supertrend_M1 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_M1, 0, 0, 1, valueBuffer) > 0)
            supertrend_M1_val = valueBuffer[0];
         if(CopyBuffer(supertrend_M1, 1, 0, 1, dirBuffer) > 0)
            supertrend_M1_dir = dirBuffer[0];
      }
   }

   if(UseSupportResistance)
      CalculateSupportResistance();
}

//+------------------------------------------------------------------+
//| CALCULER SUPPORT ET RÉSISTANCE                              |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
   double high_H1[], low_H1[];
   ArraySetAsSeries(high_H1, true);
   ArraySetAsSeries(low_H1, true);

   if(CopyHigh(_Symbol, PERIOD_H1, 0, SR_LookbackBars, high_H1) > 0 &&
      CopyLow(_Symbol, PERIOD_H1, 0, SR_LookbackBars, low_H1) > 0)
   {
      H1_Resistance = high_H1[ArrayMaximum(high_H1, 0, SR_LookbackBars)];
      H1_Support = low_H1[ArrayMinimum(low_H1, 0, SR_LookbackBars)];
   }

   double high_M5[], low_M5[];
   ArraySetAsSeries(high_M5, true);
   ArraySetAsSeries(low_M5, true);

   if(CopyHigh(_Symbol, PERIOD_M5, 0, SR_LookbackBars, high_M5) > 0 &&
      CopyLow(_Symbol, PERIOD_M5, 0, SR_LookbackBars, low_M5) > 0)
   {
      M5_Resistance = high_M5[ArrayMaximum(high_M5, 0, SR_LookbackBars)];
      M5_Support = low_M5[ArrayMinimum(low_M5, 0, SR_LookbackBars)];
   }
}

//+------------------------------------------------------------------+
//| EXÉCUTION AVANCÉE DES TRADES                              |
//+------------------------------------------------------------------+
void ExecuteAdvancedTrade(ENUM_ORDER_TYPE orderType, double ask, double bid)
{
   double sl, tp;
   double correctLotSize = GetCorrectLotSize();

   // Diagnostic des prix
   Print("🔍 DIAGNOSTIC TRADE - Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
   Print("   Ask: ", ask, " - Bid: ", bid);
   Print("   InpStopLoss: ", InpStopLoss, " - InpTakeProfit: ", InpTakeProfit);
   Print("   _Point: ", _Point);

   if(UseDynamicSLTP)
   {
      double atrValue[1];
      if(CopyBuffer(atr_H1, 0, 0, 1, atrValue) > 0)
      {
         double atrMultiplier = 2.0;
         if(orderType == ORDER_TYPE_BUY)
         {
            sl = bid - atrValue[0] * atrMultiplier;
            tp = bid + atrValue[0] * atrMultiplier * 1.5;
         }
         else
         {
            sl = ask + atrValue[0] * atrMultiplier;
            tp = ask - atrValue[0] * atrMultiplier * 1.5;
         }
         Print("📊 Stops dynamiques ATR - SL: ", sl, " - TP: ", tp);
      }
      else
      {
         if(orderType == ORDER_TYPE_BUY)
         {
            sl = bid - InpStopLoss * _Point;
            tp = bid + InpTakeProfit * _Point;
         }
         else
         {
            sl = ask + InpStopLoss * _Point;
            tp = ask - InpTakeProfit * _Point;
         }
         Print("📊 Stops fixes - SL: ", sl, " - TP: ", tp);
      }
   }
   else
   {
      if(orderType == ORDER_TYPE_BUY)
      {
         sl = bid - InpStopLoss * _Point;
         tp = bid + InpTakeProfit * _Point;
      }
      else
      {
         sl = ask + InpStopLoss * _Point;
         tp = ask - InpTakeProfit * _Point;
      }
      Print("📊 Stops par défaut - SL: ", sl, " - TP: ", tp);
   }
   
   // Validation des stops avant l'exécution
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   Print("🔍 Validation - Prix: ", currentPrice, " - SL: ", sl, " - TP: ", tp);
   
   if(!ValidateStopLevels(currentPrice, sl, tp, orderType == ORDER_TYPE_BUY))
   {
      Print("❌ Stops invalides - Trade annulé");
      return;
   }

   if(orderType == ORDER_TYPE_BUY)
   {
      if(trade.Buy(correctLotSize, _Symbol, ask, sl, tp, "GoldRush AI Buy"))
         Print("✅ Trade ACHAT exécuté - Lot: ", correctLotSize, " - SL: ", sl, " TP: ", tp);
      else
         Print("❌ Échec ACHAT - Erreur: ", trade.ResultRetcode());
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(trade.Sell(correctLotSize, _Symbol, bid, sl, tp, "GoldRush AI Sell"))
         Print("✅ Trade VENTE exécuté - Lot: ", correctLotSize, " - SL: ", sl, " TP: ", tp);
      else
         Print("❌ Échec VENTE - Erreur: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD AVANCÉ                                           |
//+------------------------------------------------------------------+
void DrawAdvancedDashboard(double rsi, double adx, double atr)
{
   if(!UseAdvancedDashboard) return;
   if(TimeCurrent() - lastDrawTime < DashboardRefresh) return;

   lastDrawTime = TimeCurrent();

   string text = "GOLDRUSH ADVANCED\n";
   text += "═════════════════════\n";
   text += "RSI H1: " + DoubleToString(rsi, 1) + "\n";
   text += "ADX H1: " + DoubleToString(adx, 1) + "\n";
   text += "ATR H1: " + DoubleToString(atr, 1) + "\n";
   text += "═════════════════════\n";

   double currentLot = GetCorrectLotSize();
   text += "Lot Size: " + DoubleToString(currentLot, 2) + "\n";

   if(UseAI_Agent)
   {
      text += "IA Signal: " + g_lastAIAction + "\n";
      text += "IA Confiance: " + DoubleToString(g_lastAIConfidence * 100, 1) + "%\n";
   }

   if(UseDerivArrowDetection)
   {
      text += "DERIV Arrow: " + (derivArrowPresent ? "OUI" : "NON") + "\n";
      if(derivArrowPresent)
         text += "Arrow Type: " + (derivArrowType == 1 ? "BUY" : "SELL") + "\n";
   }

   text += "═════════════════════\n";
   text += "Position: " + (g_hasPosition ? "OUVERTE" : "AUCUNE") + "\n";

   if(UseProfitDuplication && g_hasPosition)
   {
      text += "Profit Total: " + DoubleToString(totalSymbolProfit, 2) + "$\n";
      text += "Dupliqué: " + (hasDuplicated ? "OUI" : "NON") + "\n";
      if(hasDuplicated)
         text += "Ticket Dup: " + IntegerToString(duplicatedPositionTicket) + "\n";
   }

   if(text == lastDashText) return;
   lastDashText = text;

   if(ObjectFind(0,"Dashboard")==-1)
      ObjectCreate(0,"Dashboard",OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,"Dashboard",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,"Dashboard",OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,"Dashboard",OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,"Dashboard",OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,"Dashboard",OBJPROP_COLOR,clrWhite);
   ObjectSetString(0,"Dashboard",OBJPROP_TEXT,text);
}

//+------------------------------------------------------------------+
//| VÉRIFIER LES SIGNAUX TECHNIQUES AVANCÉS                     |
//+------------------------------------------------------------------+
bool CheckAdvancedTechnicalSignal()
{
   bool emaSignal = false;
   bool supertrendSignal = false;
   bool srSignal = false;

   if(UseMultiTimeframeEMA)
   {
      bool h1Bullish = emaFast_H1_val > emaSlow_H1_val;
      bool h1Bearish = emaFast_H1_val < emaSlow_H1_val;
      bool m5Bullish = emaFast_M5_val > emaSlow_M5_val;
      bool m5Bearish = emaFast_M5_val < emaSlow_M5_val;
      bool m1Bullish = emaFast_M1_val > emaSlow_M1_val;
      bool m1Bearish = emaFast_M1_val < emaSlow_M1_val;

      if(h1Bullish && m5Bullish && m1Bullish)
      {
         emaSignal = true;
         Print("📈 EMA Signal: HAUSSIER (H1+M5+M1 alignés)");
      }
      else if(h1Bearish && m5Bearish && m1Bearish)
      {
         emaSignal = true;
         Print("📉 EMA Signal: BAISSIER (H1+M5+M1 alignés)");
      }
   }

   if(UseSupertrendIndicator)
   {
      bool h1STBullish = supertrend_H1_dir > 0;
      bool h1STBearish = supertrend_H1_dir < 0;
      bool m5STBullish = supertrend_M5_dir > 0;
      bool m5STBearish = supertrend_M5_dir < 0;

      if(h1STBullish && m5STBullish)
      {
         supertrendSignal = true;
         Print("📈 Supertrend Signal: HAUSSIER");
      }
      else if(h1STBearish && m5STBearish)
      {
         supertrendSignal = true;
         Print("📉 Supertrend Signal: BAISSIER");
      }
   }

   if(UseSupportResistance)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(currentPrice >= H1_Resistance * 0.998 && currentPrice <= H1_Resistance * 1.002)
      {
         srSignal = true;
         Print("🎯 Support/Résistance: PROCHE RÉSISTANCE H1");
      }
      else if(currentPrice >= H1_Support * 0.998 && currentPrice <= H1_Support * 1.002)
      {
         srSignal = true;
         Print("🎯 Support/Résistance: PROCHE SUPPORT H1");
      }
   }

   return (emaSignal || supertrendSignal || srSignal);
}

//+------------------------------------------------------------------+
//| OBTENIR LA DIRECTION DU SIGNAL AVANCÉ                       |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetAdvancedSignalDirection()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(UseMultiTimeframeEMA)
   {
      if(emaFast_H1_val > emaSlow_H1_val &&
         emaFast_M5_val > emaSlow_M5_val &&
         emaFast_M1_val > emaSlow_M1_val)
         return ORDER_TYPE_BUY;
      else if(emaFast_H1_val < emaSlow_H1_val &&
              emaFast_M5_val < emaSlow_M5_val &&
              emaFast_M1_val < emaSlow_M1_val)
         return ORDER_TYPE_SELL;
   }

   if(UseSupertrendIndicator)
   {
      if(supertrend_H1_dir > 0 && supertrend_M5_dir > 0)
         return ORDER_TYPE_BUY;
      else if(supertrend_H1_dir < 0 && supertrend_M5_dir < 0)
         return ORDER_TYPE_SELL;
   }

   if(UseSupportResistance)
   {
      if(currentPrice >= H1_Support * 0.998 && currentPrice <= H1_Support * 1.002)
         return ORDER_TYPE_BUY;
      else if(currentPrice >= H1_Resistance * 0.998 && currentPrice <= H1_Resistance * 1.002)
         return ORDER_TYPE_SELL;
   }

   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| VALIDER L'ENTRÉE AVANCÉE                                   |
//+------------------------------------------------------------------+
bool ValidateAdvancedEntry(ENUM_ORDER_TYPE orderType)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(UseSupportResistance)
   {
      if(orderType == ORDER_TYPE_BUY && currentPrice > H1_Resistance * 0.995)
      {
         Print("❌ Entrée ACHAT rejetée: trop près de la résistance H1");
         return false;
      }
      if(orderType == ORDER_TYPE_SELL && currentPrice < H1_Support * 1.005)
      {
         Print("❌ Entrée VENTE rejetée: trop près du support H1");
         return false;
      }
   }

   if(UseSupertrendIndicator)
   {
      if(orderType == ORDER_TYPE_BUY && supertrend_H1_dir < 0)
      {
         Print("❌ Entrée ACHAT rejetée: Supertrend H1 baissier");
         return false;
      }
      if(orderType == ORDER_TYPE_SELL && supertrend_H1_dir > 0)
      {
         Print("❌ Entrée VENTE rejetée: Supertrend H1 haussier");
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| DESSINER LES INDICATEURS MULTI-TIMEFRAMES                   |
//+------------------------------------------------------------------+
void DrawMultiTimeframeIndicators()
{
   ObjectsDeleteAll(0, "MTF_");

   if(UseMultiTimeframeEMA)
   {
      ObjectCreate(0, "MTF_EMA_H1_FAST", OBJ_HLINE, 0, 0, emaFast_H1_val);
      ObjectSetInteger(0, "MTF_EMA_H1_FAST", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, "MTF_EMA_H1_FAST", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "MTF_EMA_H1_FAST", OBJPROP_WIDTH, 2);

      ObjectCreate(0, "MTF_EMA_H1_SLOW", OBJ_HLINE, 0, 0, emaSlow_H1_val);
      ObjectSetInteger(0, "MTF_EMA_H1_SLOW", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "MTF_EMA_H1_SLOW", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "MTF_EMA_H1_SLOW", OBJPROP_WIDTH, 2);

      ObjectCreate(0, "MTF_EMA_M5_FAST", OBJ_HLINE, 0, 0, emaFast_M5_val);
      ObjectSetInteger(0, "MTF_EMA_M5_FAST", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "MTF_EMA_M5_FAST", OBJPROP_STYLE, STYLE_DASH);

      ObjectCreate(0, "MTF_EMA_M5_SLOW", OBJ_HLINE, 0, 0, emaSlow_M5_val);
      ObjectSetInteger(0, "MTF_EMA_M5_SLOW", OBJPROP_COLOR, clrIndianRed);
      ObjectSetInteger(0, "MTF_EMA_M5_SLOW", OBJPROP_STYLE, STYLE_DASH);
   }

   if(UseSupertrendIndicator)
   {
      ObjectCreate(0, "MTF_SUPERTREND_H1", OBJ_HLINE, 0, 0, supertrend_H1_val);
      ObjectSetInteger(0, "MTF_SUPERTREND_H1", OBJPROP_COLOR, supertrend_H1_dir > 0 ? clrLime : clrOrangeRed);
      ObjectSetInteger(0, "MTF_SUPERTREND_H1", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "MTF_SUPERTREND_H1", OBJPROP_WIDTH, 3);
   }

   if(UseSupportResistance)
   {
      ObjectCreate(0, "MTF_H1_RESISTANCE", OBJ_HLINE, 0, 0, H1_Resistance);
      ObjectSetInteger(0, "MTF_H1_RESISTANCE", OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, "MTF_H1_RESISTANCE", OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, "MTF_H1_RESISTANCE", OBJPROP_WIDTH, 2);

      ObjectCreate(0, "MTF_H1_SUPPORT", OBJ_HLINE, 0, 0, H1_Support);
      ObjectSetInteger(0, "MTF_H1_SUPPORT", OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, "MTF_H1_SUPPORT", OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, "MTF_H1_SUPPORT", OBJPROP_WIDTH, 2);
   }
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE TOUS LES ENDPOINTS RENDER                        |
//+------------------------------------------------------------------+
void UpdateAllEndpoints()
{
   if(!UseAllEndpoints) return;

   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 60)
      return;

   lastUpdate = TimeCurrent();

   string analysis = UpdateAnalysisEndpoint();
   if(analysis != "")
      lastAnalysisData = analysis;

   string trend = UpdateTrendEndpoint();
   if(trend != "")
      lastTrendData = trend;

   string prediction = UpdatePredictionEndpoint();
   if(prediction != "")
      lastPredictionData = prediction;

   string coherent = UpdateCoherentEndpoint();
   if(coherent != "")
      lastCoherentData = coherent;

   Print("Tous les endpoints ont été mis à jour");
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT D'ANALYSE                             |
//+------------------------------------------------------------------+
string UpdateAnalysisEndpoint()
{
   string url = AI_AnalysisURL;
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Analysis endpoint mis à jour: ", result);
   }
   else if(responseCode == 422)
   {
      string data = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(data, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Analysis endpoint mis à jour (POST): ", result);
      }
      else
         Print("❌ Erreur Analysis endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour de l'analysis endpoint - Code:", responseCode);

   return result;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT DE TENDANCE                           |
//+------------------------------------------------------------------+
string UpdateTrendEndpoint()
{
   string url = TrendAPIURL;
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Trend endpoint mis à jour: ", result);
   }
   else if(responseCode == 422)
   {
      string data = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(data, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Trend endpoint mis à jour (POST): ", result);
      }
      else
         Print("❌ Erreur Trend endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour du trend endpoint - Code:", responseCode);

   return result;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT DE PRÉDICTION                         |
//+------------------------------------------------------------------+
string UpdatePredictionEndpoint()
{
   string url = AI_PredictSymbolURL + "/" + _Symbol;
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Prediction endpoint mis à jour: ", result);
   }
   else if(responseCode == 422 || responseCode == 404)
   {
      string postData = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(postData, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Prediction endpoint mis à jour (POST): ", result);
      }
      else
         Print("❌ Erreur Prediction endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour du prediction endpoint - Code:", responseCode);

   return result;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT D'ANALYSE COHÉRENTE                   |
//+------------------------------------------------------------------+
string UpdateCoherentEndpoint()
{
   string url = AI_CoherentAnalysisURL;
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Coherent endpoint mis à jour: ", result);
   }
   else if(responseCode == 422)
   {
      string data = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(data, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Coherent endpoint mis à jour (POST): ", result);
      }
      else
         Print("❌ Erreur Coherent endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour du coherent endpoint - Code:", responseCode);

   return result;
}
