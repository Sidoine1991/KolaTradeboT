//+------------------------------------------------------------------+
//|                     GoldRush_new.mq5                             |
//|   Version 3.05 – Max 100 trades/jour – Filtres assouplis – Perte max -20$/jour |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2026, Sidoine"
#property link      "https://www.mql5.com"
#property version   "3.05"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

// Constantes manquantes
#ifndef FW_BOLD
#define FW_BOLD 700
#endif
#ifndef ANCHOR_LEFT_UPPER
#define ANCHOR_LEFT_UPPER 0
#endif

// ==================== INPUTS ====================
input group "Lots & Risque"
input double InpLots = 0.01;
input double InpRiskPercentPerTrade = 0.8;     // 0.8% max par trade
input int InpStopLoss = 50;                    // SL de base (sera forcé min 150-200 pts)
input int InpTakeProfit = 100;
input int InpMagicNum = 123456;

input group "Trailing & Breakeven"
input bool   InpUseTrailing = true;
input int    InpTrailDist = 20;
input double BreakevenTriggerPips = 12.0;      // Assoupli
input double BreakevenBufferPips = 2.0;
input double BoomCrashTrailDistPips = 35.0;
input double BoomCrashTrailStartPips = 18.0;

input group "Limites Journalières"
input int    InpMaxDailyTrades = 100;          // MAX 100 trades par jour comme demandé
input double MaxDailyLossUSD = 20.0;           // Stop si perte >= -20$

input group "IA"
input double AI_MinConfidence = 0.50;          // Réduit à 50% pour plus d'opportunités

// ==================== VARIABLES GLOBALES ====================
CTrade trade;
datetime lastTickTime = 0;
datetime lastLogTime = 0;  // Pour éviter le spam de logs
int tradesTodayCount = 0;
int lastDailyReset = -1;                       // Jour du mois
double g_lastAIConfidence = 0.0;
string g_lastAIAction = "";
datetime lastDashboardUpdate = 0;

// Handles
int emaFast_M1 = INVALID_HANDLE;
int emaSlow_M1 = INVALID_HANDLE;
int rsi_H1 = INVALID_HANDLE;
int atr_M1 = INVALID_HANDLE;

// ==================== FONCTIONS ====================

double CalculateDailyNetProfit() {
   double net = 0.0;
   datetime start = iTime(_Symbol, PERIOD_D1, 0);
   if(HistorySelect(start, TimeCurrent())) {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNum) {
            net += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                   HistoryDealGetDouble(ticket, DEAL_SWAP) +
                   HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         }
      }
   }
   return net;
}

double CalculateRiskBasedLotSize(double riskPercent, double stopLossPoints) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 0.0;
   
   double riskAmount = balance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue == 0.0 || tickSize == 0.0 || point == 0.0) return InpLots;
   
   // SL minimum de sécurité
   double slPoints = MathMax(stopLossPoints, 150.0);
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0) {
      slPoints = MathMax(slPoints, 200.0);
   }
   
   double moneyPerLot = (slPoints * point * tickValue) / tickSize;
   double lots = NormalizeDouble(riskAmount / moneyPerLot, 2);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   PrintFormat("CalculateRiskBasedLotSize → Balance=%.2f$ | Risque=%.1f%% | SL forcé=%.0f pts → Lot=%.2f",
               balance, riskPercent, slPoints, lots);
   
   return lots;
}

bool IsLocalFilterValid(string aiDirection, string &outReason) {
   outReason = "";
   
   double rsi[2], emaFast[2], emaSlow[2], atr[2];
   
   if(CopyBuffer(rsi_H1, 0, 0, 2, rsi) < 2 ||
      CopyBuffer(emaFast_M1, 0, 0, 2, emaFast) < 2 ||
      CopyBuffer(emaSlow_M1, 0, 0, 2, emaSlow) < 2 ||
      CopyBuffer(atr_M1, 0, 0, 2, atr) < 2) {
      outReason = "Erreur copie buffers";
      return false;
   }
   
   bool isBuyDirection = (StringFind(StringToUpper(aiDirection), "BUY") >= 0);
   bool isSellDirection = (StringFind(StringToUpper(aiDirection), "SELL") >= 0);
   
   // Assoupli : buy si RSI <75, sell si >25 (plus permissif)
   if(isBuyDirection && rsi[0] >= 75.0) {
      outReason = "BUY refusé : RSI trop haut (>75)";
      return false;
   }
   if(isSellDirection && rsi[0] <= 25.0) {
      outReason = "SELL refusé : RSI trop bas (<25)";
      return false;
   }
   
   // Assoupli : permet les trades même si EMA n'est pas parfaitement aligné
   if(isBuyDirection && emaFast[0] < emaSlow[0] * 0.999) {
      outReason = "BUY refusé : EMA9 significativement sous EMA21";
      return false;
   }
   if(isSellDirection && emaFast[0] > emaSlow[0] * 1.001) {
      outReason = "SELL refusé : EMA9 significativement au-dessus de EMA21";
      return false;
   }
   
   // ATR check très assoupli (2.5 au lieu de 1.8)
   if(atr[0] > 2.5 * atr[1]) {
      outReason = "ATR trop élevé (risque spike extrême)";
      return false;
   }
   
   outReason = "Filtre local OK";
   return true;
}

void ManageTrailingAndBreakeven() {
   if(!InpUseTrailing) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double profitPoints = (posType == POSITION_TYPE_BUY) ? (currentPrice - openPrice) / point : (openPrice - currentPrice) / point;
      
      // Breakeven
      if(profitPoints >= BreakevenTriggerPips) {
         double newSL = (posType == POSITION_TYPE_BUY) ? openPrice + BreakevenBufferPips * point : openPrice - BreakevenBufferPips * point;
         newSL = NormalizeDouble(newSL, _Digits);
         if(trade.PositionModify(ticket, newSL, currentTP)) Print("Breakeven activé");
      }
      
      // Trailing
      double trailDist = InpTrailDist * point;
      if(profitPoints > BoomCrashTrailStartPips) trailDist = BoomCrashTrailDistPips * point;
      
      double newSL = (posType == POSITION_TYPE_BUY) ? currentPrice - trailDist : currentPrice + trailDist;
      newSL = NormalizeDouble(newSL, _Digits);
      if((posType == POSITION_TYPE_BUY && newSL > currentSL) || (posType == POSITION_TYPE_SELL && newSL < currentSL)) {
         if(trade.PositionModify(ticket, newSL, currentTP)) Print("Trailing mis à jour");
      }
   }
}

void UpdateLeftDashboard() {
   double dailyNet = CalculateDailyNetProfit();
   string profitTxt = StringFormat("Profit Net Jour: %.2f $", dailyNet);
   color profitClr = (dailyNet >= 0) ? clrGreen : clrRed;
   
   CreateDashboardLabel("Profit", profitTxt, 10, 20, profitClr);
   CreateDashboardLabel("Trades", StringFormat("Trades Jour: %d / 100", tradesTodayCount), 10, 40, clrWhite);
   CreateDashboardLabel("ConfIA", StringFormat("Conf IA: %.0f %%", g_lastAIConfidence * 100), 10, 60, clrYellow);
   string reason = "";
   string filterTxt = IsLocalFilterValid(g_lastAIAction, reason) ? "Filtre Local: OK" : "Filtre Local: BLOQUE";
   color filterClr = IsLocalFilterValid(g_lastAIAction, reason) ? clrGreen : clrRed;
   CreateDashboardLabel("Filter", filterTxt, 10, 80, filterClr);
}

void CreateDashboardLabel(string name, string text, int x, int y, color clr) {
   string objName = "DASH_" + name;
   if(ObjectFind(0, objName) >= 0) ObjectDelete(0, objName);
   
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
}

// ==================== INIT / DEINIT / TICK ====================

int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNum);
   
   rsi_H1 = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
   emaFast_M1 = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M1 = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   atr_M1 = iATR(_Symbol, PERIOD_M1, 14);
   
   if(rsi_H1 == INVALID_HANDLE || emaFast_M1 == INVALID_HANDLE || emaSlow_M1 == INVALID_HANDLE || atr_M1 == INVALID_HANDLE) {
      Print("Erreur création indicateurs");
      return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "DASH_");
   IndicatorRelease(rsi_H1);
   IndicatorRelease(emaFast_M1);
   IndicatorRelease(emaSlow_M1);
   IndicatorRelease(atr_M1);
}

void OnTick() {
   if(TimeCurrent() - lastTickTime < 5) return;
   lastTickTime = TimeCurrent();
   
   bool shouldLog = (TimeCurrent() - lastLogTime >= 30);  // Log toutes les 30 secondes
   if(shouldLog) lastLogTime = TimeCurrent();
   
   // Reset compteur journalier
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.day != lastDailyReset) {
      tradesTodayCount = 0;
      lastDailyReset = tm.day;
   }
   
   // Stop profit/perte journalier
   double dailyNet = CalculateDailyNetProfit();
   if(shouldLog) Print("📈 Profit Net Jour: ", dailyNet, "$ | Limite: 10$ profit / -", MaxDailyLossUSD, "$ perte");
   if(dailyNet >= 10.0) {
      if(shouldLog) Print("🛑 ARRÊT : Objectif profit journalier atteint");
      return;
   }
   if(dailyNet <= -MaxDailyLossUSD) {
      if(shouldLog) Print("🛑 ARRÊT : Limite perte journalière atteinte");
      return;
   }
   
   // Limite 100 trades/jour
   if(shouldLog) Print("📊 Trades aujourd'hui: ", tradesTodayCount, "/", InpMaxDailyTrades);
   if(tradesTodayCount >= InpMaxDailyTrades) {
      if(shouldLog) Print("🛑 ARRÊT : Limite trades journalière atteinte");
      return;
   }
   
   // Appel API IA pour récupérer les signaux
   string aiServerURL = "http://127.0.0.1:8000/decision";
   string fallbackURL = "https://kolatradebot.onrender.com/decision";
   
   // Préparer les données pour l'API
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double rsi[1], emaFast[1], emaSlow[1], atr[1];
   
   // Récupérer les indicateurs
   if(CopyBuffer(rsi_H1, 0, 0, 1, rsi) <= 0 ||
      CopyBuffer(emaFast_M1, 0, 0, 1, emaFast) <= 0 ||
      CopyBuffer(emaSlow_M1, 0, 0, 1, emaSlow) <= 0 ||
      CopyBuffer(atr_M1, 0, 0, 1, atr) <= 0) {
      Print("Erreur récupération indicateurs");
      return;
   }
   
   // Construire le JSON pour l'API
   string jsonData = StringFormat("{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"rsi\":%.2f,\"atr\":%.5f,\"ema_fast\":%.5f,\"ema_slow\":%.5f}",
                              _Symbol, bid, ask, rsi[0], atr[0], emaFast[0], emaSlow[0]);
   
   Print("📤 Envoi API IA: ", jsonData);
   
   // Appeler l'API locale d'abord
   uchar result[];
   string result_headers;
   uchar data[];
   StringToCharArray(jsonData, data);
   
   int res = WebRequest("POST", aiServerURL, "Content-Type: application/json\r\nUser-Agent: MT5-TradBOT/3.0\r\n", 10000, data, result, result_headers);
   
   if(res == 200) {
      string response = CharArrayToString(result, 0, -1, CP_UTF8);
      Print("📥 Réponse API IA brute: ", response);
      // Parser la réponse JSON (simplifié)
      g_lastAIAction = "hold";
      g_lastAIConfidence = 0.68;
      
      // Extraire l'action et la confiance de la réponse
      if(StringFind(response, "\"action\":\"buy\"") >= 0) g_lastAIAction = "BUY";
      else if(StringFind(response, "\"action\":\"sell\"") >= 0) g_lastAIAction = "SELL";
      
      // Extraire la confiance
      int confPos = StringFind(response, "\"confidence\":");
      if(confPos >= 0) {
         string confStr = StringSubstr(response, confPos + 13, 4);
         StringReplace(confStr, ",", "");
         g_lastAIConfidence = StringToDouble(confStr);
      }
      
      Print("✅ Réponse IA: ", g_lastAIAction, " (confiance: ", g_lastAIConfidence * 100, "%)");
   } else {
      Print("❌ Erreur API locale, tentative fallback...");
      // Essayer le serveur distant en fallback
      uchar fallbackData[];
      StringToCharArray(jsonData, fallbackData);
      res = WebRequest("POST", fallbackURL, "Content-Type: application/json\r\nUser-Agent: MT5-TradBOT/3.0\r\n", 15000, fallbackData, result, result_headers);
      if(res == 200) {
         string response = CharArrayToString(result, 0, -1, CP_UTF8);
         Print("📥 Réponse API fallback brute: ", response);
         // Parser la réponse (même logique)
         g_lastAIAction = "hold";
         g_lastAIConfidence = 0.68;
         
         if(StringFind(response, "\"action\":\"buy\"") >= 0) g_lastAIAction = "BUY";
         else if(StringFind(response, "\"action\":\"sell\"") >= 0) g_lastAIAction = "SELL";
         
         int confPos = StringFind(response, "\"confidence\":");
         if(confPos >= 0) {
            string confStr = StringSubstr(response, confPos + 13, 4);
            StringReplace(confStr, ",", "");
            g_lastAIConfidence = StringToDouble(confStr);
         }
         
         Print("✅ Réponse IA (distant): ", g_lastAIAction, " (confiance: ", g_lastAIConfidence * 100, "%)");
      } else {
         Print("❌ Erreur API distante aussi: ", res);
         g_lastAIAction = "hold";
         g_lastAIConfidence = 0.0;
      }
   }

   // Afficher les valeurs des indicateurs pour le débogage
   double rsi[1], emaFast[1], emaSlow[1], atr[1];
   if(CopyBuffer(rsi_H1, 0, 0, 1, rsi) > 0 && 
      CopyBuffer(emaFast_M1, 0, 0, 1, emaFast) > 0 &&
      CopyBuffer(emaSlow_M1, 0, 0, 1, emaSlow) > 0 &&
      CopyBuffer(atr_M1, 0, 0, 1, atr) > 0) {
      
      Print("📊 VALEURS INDICATEURS - RSI: ", DoubleToString(rsi[0], 2), 
            " | EMA Fast: ", DoubleToString(emaFast[0], 5), 
            " | EMA Slow: ", DoubleToString(emaSlow[0], 5),
            " | ATR: ", DoubleToString(atr[0], 5));
      
      // Afficher la tendance EMA
      if(emaFast[0] > emaSlow[0]) {
         Print("  ↳ Tendance: HAUSSIÈRE (EMA Fast > EMA Slow)");
      } else {
         Print("  ↳ Tendance: BAISSIÈRE (EMA Fast < EMA Slow)");
      }
      
      // Afficher la zone RSI
      if(rsi[0] > 70) Print("  ↳ RSI en zone de SURACHAT");
      else if(rsi[0] < 30) Print("  ↳ RSI en zone de SURVENTE");
      else Print("  ↳ RSI en zone neutre");
   } else {
      Print("❌ Impossible de récupérer les valeurs des indicateurs");
   }
   
   // Filtre local assoupli
   string reason = "";
   bool filterValid = IsLocalFilterValid(g_lastAIAction, reason);
   
   // Logger seulement si l'action change ou toutes les 30 secondes
   static string lastLoggedAction = "";
   static double lastLoggedConfidence = -1;
   bool actionChanged = (g_lastAIAction != lastLoggedAction || g_lastAIConfidence != lastLoggedConfidence);
   
   if(shouldLog || actionChanged) {
      Print("🤖 IA Action: ", g_lastAIAction, " | Confiance: ", g_lastAIConfidence * 100, "%");
      Print("🔍 Filtre Local: ", filterValid ? "✅ VALIDÉ" : "❌ BLOQUÉ", " | Raison: ", reason);
      Print("📊 Seuil confiance: ", AI_MinConfidence * 100, "% | Test: ", (g_lastAIConfidence >= AI_MinConfidence) ? "✅ PASS" : "❌ FAIL");
      lastLoggedAction = g_lastAIAction;
      lastLoggedConfidence = g_lastAIConfidence;
   }
   
   if(filterValid) {
      if(g_lastAIConfidence >= AI_MinConfidence) {
         double lot = CalculateRiskBasedLotSize(InpRiskPercentPerTrade, InpStopLoss);
         if(shouldLog) Print("💰 Lot calculé: ", DoubleToString(lot, 2), " | Min lot: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2));
         if(lot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(StringFind(StringToUpper(g_lastAIAction), "BUY") >= 0) {
               double sl = ask - InpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               double tp = ask + InpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               Print("🟢 TENTATIVE BUY | Lot: ", DoubleToString(lot, 2), " | Ask: ", DoubleToString(ask, 5), " | SL: ", DoubleToString(sl, 5), " | TP: ", DoubleToString(tp, 5));
               trade.Buy(lot, _Symbol, ask, sl, tp, "AI BUY");
               if(trade.ResultRetcode() == 10009) {
                  tradesTodayCount++;
                  Print("✅ BUY EXECUTÉ | Ticket: ", trade.ResultOrder());
               } else {
                  Print("❌ BUY ÉCHOUÉ | Erreur: ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
               }
            } else if(StringFind(StringToUpper(g_lastAIAction), "SELL") >= 0) {
               double sl = bid + InpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               double tp = bid - InpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               Print("🔴 TENTATIVE SELL | Lot: ", DoubleToString(lot, 2), " | Bid: ", DoubleToString(bid, 5), " | SL: ", DoubleToString(sl, 5), " | TP: ", DoubleToString(tp, 5));
               trade.Sell(lot, _Symbol, bid, sl, tp, "AI SELL");
               if(trade.ResultRetcode() == 10009) {
                  tradesTodayCount++;
                  Print("✅ SELL EXECUTÉ | Ticket: ", trade.ResultOrder());
               } else {
                  Print("❌ SELL ÉCHOUÉ | Erreur: ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
               }
            }
         } else {
            if(shouldLog) Print("❌ Lot trop petit: ", DoubleToString(lot, 2), " < ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2));
         }
      } else {
         if(shouldLog) Print("❌ Confiance IA insuffisante: ", g_lastAIConfidence * 100, "% < ", AI_MinConfidence * 100, "%");
      }
   }

   ManageTrailingAndBreakeven();
}
