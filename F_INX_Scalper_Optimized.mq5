//+------------------------------------------------------------------+
//|                                    F_INX_Scalper_Optimized.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Paramètres d'entrée optimisés                                     |
//+------------------------------------------------------------------+
input group "--- CONFIGURATION OPTIMISÉE ---"
input int    InpMagicNumber     = 888888;
input double MinConfidence      = 70.0;
input double InitialLotSize     = 0.01;
input double MaxLotSize          = 1.0;
input double TakeProfitUSD       = 30.0;
input double StopLossUSD         = 10.0;
input bool   UseAI_Agent        = true;
input string AI_ServerURL       = "http://localhost:8000/channel/predictive";

//+------------------------------------------------------------------+
//| Variables globales optimisées                                    |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;
datetime g_lastTickTime = 0;
datetime g_lastAIUpdate = 0;
datetime g_lastProtectionCheck = 0;
datetime g_lastChartUpdate = 0;
string g_lastSignal = "";
double g_lastConfidence = 0;

// Intervalles optimisés (plus longs pour moins de charge)
#define AI_UPDATE_INTERVAL 30          // 30 secondes au lieu de 1
#define PROTECTION_CHECK_INTERVAL 5    // 5 secondes au lieu de chaque tick
#define CHART_UPDATE_INTERVAL 10      // 10 secondes pour les mises à jour graphiques

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   Print("F_INX_Scalper_Optimized initialisé - Mode haute performance activé");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("F_INX_Scalper_Optimized arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick function - OPTIMISÉ                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentTime = TimeCurrent();
   
   // Éviter les exécutions multiples dans la même seconde
   if(currentTime == g_lastTickTime)
      return;
   g_lastTickTime = currentTime;
   
   // === PRIORITÉS AVEC FRÉQUENCE RÉDUITE ===
   
   // 1. Protection contre pertes (toutes les 5 secondes seulement)
   if(currentTime - g_lastProtectionCheck >= PROTECTION_CHECK_INTERVAL)
   {
      CheckGlobalLossProtection();
      ProtectGainsWhenTargetReached();
      CheckAndUpdatePositions();
      g_lastProtectionCheck = currentTime;
   }
   
   // 2. Mise à jour IA (toutes les 30 secondes seulement)
   if(UseAI_Agent && currentTime - g_lastAIUpdate >= AI_UPDATE_INTERVAL)
   {
      UpdateAIDecisionOptimized();
      g_lastAIUpdate = currentTime;
   }
   
   // 3. Mises à jour graphiques (toutes les 10 secondes seulement)
   if(currentTime - g_lastChartUpdate >= CHART_UPDATE_INTERVAL)
   {
      UpdateChartDisplay();
      g_lastChartUpdate = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Mise à jour IA optimisée                                          |
//+------------------------------------------------------------------+
void UpdateAIDecisionOptimized()
{
   string url = AI_ServerURL + "?symbol=" + _Symbol;
   string response;
   string headers;
   char data[];
   int timeout = 5000; // 5 secondes timeout
   
   // Requête HTTP simple et rapide
   int res = WebRequest("GET", url, "", "", timeout, data, data, headers, response);
   
   if(res == 200)
   {
      // Parser simple de la réponse JSON
      ParseAIResponse(response);
   }
   else
   {
      Print("Erreur IA: ", res);
   }
}

//+------------------------------------------------------------------+
//| Parser JSON simple et rapide                                     |
//+------------------------------------------------------------------+
void ParseAIResponse(string json)
{
   // Extraction simple avec StringFind pour éviter les parsers lourds
   int signalPos = StringFind(json, "\"signal\":");
   int confidencePos = StringFind(json, "\"confidence\":");
   
   if(signalPos > 0 && confidencePos > 0)
   {
      // Extraire le signal
      int start = StringFind(json, "\"", signalPos + 9) + 1;
      int end = StringFind(json, "\"", start);
      string signal = StringSubstr(json, start, end - start);
      
      // Extraire la confiance
      start = StringFind(json, ":", confidencePos) + 1;
      end = StringFind(json, ",", start);
      if(end == -1) end = StringFind(json, "}", start);
      string confStr = StringSubstr(json, start, end - start);
      double confidence = StringToDouble(confStr);
      
      // Mettre à jour les variables globales
      g_lastSignal = signal;
      g_lastConfidence = confidence;
      
      // Exécuter le trading si conditions remplies
      if(confidence >= MinConfidence)
      {
         ExecuteTrade(signal, confidence);
      }
   }
}

//+------------------------------------------------------------------+
//| Exécution de trade optimisée                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(string signal, double confidence)
{
   // Vérifier si on a déjà une position
   if(position.SelectBySymbol(_Symbol))
   {
      // Fermer si signal opposé avec haute confiance
      if((position.PositionType() == POSITION_TYPE_BUY && signal == "SELL") ||
         (position.PositionType() == POSITION_TYPE_SELL && signal == "BUY"))
      {
         if(confidence > 80.0) // Seulement si confiance très élevée
         {
            trade.PositionClose(position.Ticket());
         }
      }
   }
   else
   {
      // Ouvrir nouvelle position
      double lot = InitialLotSize;
      double stopLoss = StopLossUSD;
      double takeProfit = TakeProfitUSD;
      
      if(signal == "BUY")
      {
         trade.Buy(lot, _Symbol, 0, 0, takeProfit, "AI BUY Signal");
      }
      else if(signal == "SELL")
      {
         trade.Sell(lot, _Symbol, 0, 0, takeProfit, "AI SELL Signal");
      }
   }
}

//+------------------------------------------------------------------+
//| Protection contre pertes globales                                 |
//+------------------------------------------------------------------+
void CheckGlobalLossProtection()
{
   double totalProfit = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         totalProfit += position.Profit();
      }
   }
   
   // Fermer tout si perte > 50$
   if(totalProfit < -50.0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(position.SelectByIndex(i))
         {
            trade.PositionClose(position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Protection des gains                                              |
//+------------------------------------------------------------------+
void ProtectGainsWhenTargetReached()
{
   double totalProfit = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         totalProfit += position.Profit();
      }
   }
   
   // Fermer tout si gain > 100$
   if(totalProfit > 100.0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(position.SelectByIndex(i))
         {
            trade.PositionClose(position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Mise à jour des positions                                        |
//+------------------------------------------------------------------+
void CheckAndUpdatePositions()
{
   // Simple vérification sans calculs complexes
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         // Fermer les positions perdantes > 30$
         if(position.Profit() < -30.0)
         {
            trade.PositionClose(position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Mise à jour graphique optimisée                                  |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   // Affichage simple du dernier signal
   string displayText = "Signal: " + g_lastSignal + " | Confiance: " + DoubleToString(g_lastConfidence, 1) + "%";
   
   Comment(displayText);
}

//+------------------------------------------------------------------+
//| ChartEvent function - OPTIMISÉE                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Gérer seulement les événements clavier essentiels
   if(id == CHARTEVENT_KEYDOWN)
   {
      // Espace pour activer/désactiver l'IA
      if(lparam == 32)
      {
         UseAI_Agent = !UseAI_Agent;
         Print("IA Agent: ", UseAI_Agent ? "ACTIVÉ" : "DÉSACTIVÉ");
      }
      // T pour activer/désactiver le trading
      else if(lparam == 84)
      {
         // Toggle trading (simple)
         Print("Trading toggle - À implémenter");
      }
   }
}
