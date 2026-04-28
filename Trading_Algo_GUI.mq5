//+------------------------------------------------------------------+
//|                                    Trading_Algo_GUI.mq5          |
//|                     Interface Trading Algo - Charles Robot       |
//|                   Input manuel avec calcul automatique lot size  |
//+------------------------------------------------------------------+
#property copyright "TradBOT - Charles Robot Interface"
#property link      "https://github.com/Sidoine1991/KolaTradeboT"
#property version   "1.00"
#property strict
#property description "Interface graphique pour exécuter les trades selon les signaux Charles"

#include <Trade\Trade.mqh>

//--- Paramètres d'entrée
input group "=== CONFIGURATION ==="
input int    InpPanelX = 20;                    // Position X du panneau
input int    InpPanelY = 20;                    // Position Y du panneau
input int    InpPanelWidth = 280;               // Largeur du panneau
input color  InpPanelBgColor = clrNavy;         // Couleur fond panneau
input color  InpPanelTextColor = clrWhite;      // Couleur texte
input color  InpBuyColor = clrLime;             // Couleur BUY
input color  InpSellColor = clrRed;             // Couleur SELL
input int    InpFontSize = 9;                   // Taille police
input string InpFontName = "Arial";            // Police

input group "=== RISQUE PAR DÉFAUT ==="
input double InpDefaultRiskPercent = 0.5;       // Risque % par défaut
input double InpDefaultTP1 = 50.0;              // TP1 points par défaut
input double InpDefaultTP2 = 100.0;             // TP2 points par défaut
input double InpDefaultSL = 30.0;               // SL points par défaut

input group "=== SERVEUR IA ==="
input bool   UseAIServer = true;               // Utiliser le serveur IA pour l'analyse
input string AI_ServerURL = "http://localhost:8000";  // URL du serveur IA
input int    AI_Timeout_ms = 5000;             // Timeout WebRequest (ms)

input group "=== PARAMÈTRES ANALYSE TECHNIQUE ==="
input double InpRSI = 50.0;                    // RSI (optionnel, auto-calculé si vide)
input double InpEMA_Fast_H1 = 0;               // EMA Fast H1 (0 = auto)
input double InpEMA_Slow_H1 = 0;               // EMA Slow H1 (0 = auto)
input double InpEMA_Fast_M1 = 0;               // EMA Fast M1 (0 = auto)
input double InpEMA_Slow_M1 = 0;               // EMA Slow M1 (0 = auto)
input double InpEMA_Fast_M5 = 0;               // EMA Fast M5 (0 = auto)
input double InpEMA_Slow_M5 = 0;               // EMA Slow M5 (0 = auto)
input double InpATR = 0;                       // ATR (0 = auto)
input int    InpDirRule = 0;                   // Direction rule (0=neutre, 1=buy, -1=sell)
input bool   InpIsSpikeMode = false;           // Mode spike
input double InpVWAP = 0;                      // VWAP (0 = auto)
input double InpVWAPDistance = 0;              // Distance VWAP (0 = auto)
input bool   InpAboveVWAP = false;             // Au-dessus VWAP
input int    InpSuperTrendTrend = 0;           // SuperTrend trend (0=neutre, 1=up, -1=down)
input double InpSuperTrendLine = 0;            // SuperTrend line (0 = auto)
input int    InpVolatilityRegime = 0;          // Volatility regime (0=neutre)
input double InpVolatilityRatio = 1.0;         // Volatility ratio

//--- Variables globales
CTrade trade;

//--- Variables de l'interface
string g_panelName = "TRADING_ALGO_PANEL";
bool g_panelVisible = true;

//--- Variables de trading
string g_signal = "WAIT";           // BUY, SELL, WAIT
double g_riskPercent = 0.5;         // Risque en %
double g_lotSize = 0.01;           // Lot size calculé
double g_entryPrice = 0;            // Prix d'entrée
double g_tp1 = 0;                  // TP1
double g_tp2 = 0;                  // TP2
double g_sl = 0;                   // Stop Loss
double g_riskUSD = 0;              // Risque en USD
double g_rewardUSD = 0;             // Reward en USD
double g_rrRatio = 0;               // Risk/Reward ratio

//--- Variables de l'analyse IA
string g_aiAction = "HOLD";        // Action IA: BUY, SELL, HOLD
double g_aiConfidence = 0.0;       // Confiance IA (0-1)
string g_aiReason = "";            // Raison de la décision IA
double g_aiStopLoss = 0;           // SL proposé par IA
double g_aiTakeProfit = 0;         // TP proposé par IA
bool g_aiAnalysisReady = false;    // Analyse IA prête
string g_aiModelUsed = "";         // Modèle IA utilisé

//--- Variables techniques calculées
double g_techRSI = 50.0;
double g_techEMA_Fast_H1 = 0;
double g_techEMA_Slow_H1 = 0;
double g_techEMA_Fast_M1 = 0;
double g_techEMA_Slow_M1 = 0;
double g_techEMA_Fast_M5 = 0;
double g_techEMA_Slow_M5 = 0;
double g_techATR = 0;
double g_techVWAP = 0;
double g_techVWAPDistance = 0;
bool g_techAboveVWAP = false;
int g_techSuperTrendTrend = 0;
double g_techSuperTrendLine = 0;
int g_techVolatilityRegime = 0;
double g_techVolatilityRatio = 1.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(888888);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   Print("🤖 Trading Algo GUI initialisé sur ", _Symbol);
   
   // Créer le panneau
   CreateTradingPanel();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CleanupPanel();
   Print("🔄 Trading Algo GUI désinitialisé");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Mettre à jour le prix d'entrée actuel
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick))
   {
      g_entryPrice = (g_signal == "BUY") ? tick.ask : tick.bid;
      
      // Recalculer les TP/SL si le signal est actif
      if(g_signal != "WAIT")
      {
         CalculateTPSL();
         CalculateLotSize();
         UpdateDisplay();
      }
   }
   
   // Mettre à jour les données de marché en temps réel
   UpdateMarketData();
   
   // Vérifier les événements de l'interface
   CheckPanelEvents();
}

//+------------------------------------------------------------------+
//| Chart event function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      HandleButtonClick(sparam);
   }
   else if(id == CHARTEVENT_KEYDOWN)
   {
      HandleKeyPress(lparam);
   }
}

//+------------------------------------------------------------------+
//| Créer le panneau de trading                                       |
//+------------------------------------------------------------------+
void CreateTradingPanel()
{
   int x = InpPanelX;
   int y = InpPanelY;
   int w = InpPanelWidth;
   int h = 480;
   
   // Fond du panneau
   CreateRectangle("PANEL_BG", x, y, w, h, InpPanelBgColor);
   
   // Titre compact
   CreateLabel("TITLE", x + 10, y + 8, "🤖 CHARLES BOT", InpFontSize + 2, clrYellow);
   
   // Section COMPTE (nouveau)
   CreateLabel("ACCOUNT_TITLE", x + 150, y + 8, "💼 COMPTE", InpFontSize, clrCyan);
   CreateLabel("BALANCE", x + 10, y + 30, "Bal: ---", InpFontSize - 1, clrWhite);
   CreateLabel("EQUITY", x + 90, y + 30, "Eq: ---", InpFontSize - 1, clrWhite);
   CreateLabel("PROFIT", x + 160, y + 30, "P/L: ---", InpFontSize - 1, clrLime);
   
   // Séparateur
   CreateHLine("SEP0", x + 10, y + 48, w - 20, clrWhite);
   
   // Symbole + Signal (compact)
   CreateLabel("SYMBOL", x + 10, y + 55, _Symbol, InpFontSize + 1, clrOrange);
   CreateLabel("SIGNAL_VALUE", x + 100, y + 55, "⏳ WAIT", InpFontSize + 1, clrGray);
   
   // Boutons BUY/SELL compact
   CreateButton("BTN_BUY", x + 10, y + 75, 85, 25, "📈 BUY", clrWhite, clrGreen);
   CreateButton("BTN_SELL", x + 100, y + 75, 85, 25, "📉 SELL", clrWhite, clrRed);
   CreateButton("BTN_WAIT", x + 190, y + 75, 70, 25, "⏳", clrWhite, clrGray);
   
   // Séparateur
   CreateHLine("SEP1", x + 10, y + 108, w - 20, clrWhite);
   
   // Section MARKET (nouveau)
   CreateLabel("MARKET_TITLE", x + 10, y + 115, "📊 MARKET", InpFontSize, clrCyan);
   CreateLabel("SPREAD", x + 10, y + 135, "Spread: ---", InpFontSize - 1, clrWhite);
   CreateLabel("ATR", x + 90, y + 135, "ATR: ---", InpFontSize - 1, clrWhite);
   CreateLabel("RSI", x + 160, y + 135, "RSI: ---", InpFontSize - 1, clrWhite);
   
   // Indicateurs techniques (compact)
   CreateLabel("EMA_TREND", x + 10, y + 152, "EMA: ---", InpFontSize - 1, clrWhite);
   CreateLabel("POSITIONS", x + 90, y + 152, "Pos: 0", InpFontSize - 1, clrWhite);
   CreateLabel("TIME", x + 160, y + 152, "--:--", InpFontSize - 1, clrWhite);
   
   // Séparateur
   CreateHLine("SEP2", x + 10, y + 167, w - 20, clrWhite);
   
   // Section TRADE (compact)
   CreateLabel("TRADE_TITLE", x + 10, y + 175, "⚙️ TRADE SETUP", InpFontSize, clrCyan);
   
   // Risque %
   CreateLabel("RISK_LABEL", x + 10, y + 195, "Risk %:", InpFontSize - 1, InpPanelTextColor);
   CreateEdit("RISK_INPUT", x + 60, y + 193, 40, 18, DoubleToString(InpDefaultRiskPercent, 2), InpFontSize - 1);
   
   // Lot size
   CreateLabel("LOT_LABEL", x + 110, y + 195, "Lot:", InpFontSize - 1, InpPanelTextColor);
   CreateLabel("LOT_VALUE", x + 140, y + 195, "0.01", InpFontSize, clrYellow);
   
   // TP1 et TP2 (côte à côte)
   CreateLabel("TP1_LABEL", x + 10, y + 218, "TP1:", InpFontSize - 1, InpPanelTextColor);
   CreateEdit("TP1_INPUT", x + 40, y + 216, 35, 18, DoubleToString(InpDefaultTP1, 1), InpFontSize - 1);
   CreateLabel("TP1_PRICE", x + 80, y + 218, "---", InpFontSize - 1, clrLime);
   
   CreateLabel("TP2_LABEL", x + 130, y + 218, "TP2:", InpFontSize - 1, InpPanelTextColor);
   CreateEdit("TP2_INPUT", x + 160, y + 216, 35, 18, DoubleToString(InpDefaultTP2, 1), InpFontSize - 1);
   CreateLabel("TP2_PRICE", x + 200, y + 218, "---", InpFontSize - 1, clrLime);
   
   // SL
   CreateLabel("SL_LABEL", x + 10, y + 241, "SL:", InpFontSize - 1, InpPanelTextColor);
   CreateEdit("SL_INPUT", x + 40, y + 239, 35, 18, DoubleToString(InpDefaultSL, 1), InpFontSize - 1);
   CreateLabel("SL_PRICE", x + 80, y + 241, "---", InpFontSize - 1, clrRed);
   
   // R/R ratio
   CreateLabel("RR_LABEL", x + 130, y + 241, "R/R:", InpFontSize - 1, InpPanelTextColor);
   CreateLabel("RR_VALUE", x + 160, y + 241, "---", InpFontSize - 1, clrCyan);
   
   // Séparateur
   CreateHLine("SEP3", x + 10, y + 264, w - 20, clrWhite);
   
   // Section IA (compact)
   CreateLabel("AI_TITLE", x + 10, y + 272, "🤖 IA", InpFontSize, clrCyan);
   CreateLabel("AI_ACTION_VALUE", x + 50, y + 272, "⏳ WAIT", InpFontSize, clrGray);
   CreateLabel("AI_CONFIDENCE_VALUE", x + 130, y + 272, "---", InpFontSize - 1, clrCyan);
   
   // Bouton Analyse IA compact
   CreateButton("BTN_AI_ANALYZE", x + 10, y + 292, w - 20, 25, "📊 ANALYSER", clrWhite, clrMagenta);
   
   // Raison IA (compact)
   CreateLabel("AI_REASON_VALUE", x + 10, y + 322, "---", InpFontSize - 2, clrWhite);
   
   // Séparateur final
   CreateHLine("SEP4", x + 10, y + 337, w - 20, clrWhite);
   
   // Bouton EXECUTE
   CreateButton("BTN_EXECUTE", x + 10, y + 345, w - 20, 30, "🚀 EXECUTE TRADE", clrWhite, clrBlue);
   
   // Initialiser les valeurs
   g_riskPercent = InpDefaultRiskPercent;
   g_tp1 = InpDefaultTP1;
   g_tp2 = InpDefaultTP2;
   g_sl = InpDefaultSL;
   
   Print("✅ Panneau Trading Algo créé");
}

//+------------------------------------------------------------------+
//| Calculer les TP/SL                                                |
//+------------------------------------------------------------------+
void CalculateTPSL()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   if(g_signal == "BUY")
   {
      g_sl = g_entryPrice - (StringToDouble(ObjectGetString(0, "SL_INPUT", OBJPROP_TEXT)) * point);
      g_tp1 = g_entryPrice + (StringToDouble(ObjectGetString(0, "TP1_INPUT", OBJPROP_TEXT)) * point);
      g_tp2 = g_entryPrice + (StringToDouble(ObjectGetString(0, "TP2_INPUT", OBJPROP_TEXT)) * point);
   }
   else if(g_signal == "SELL")
   {
      g_sl = g_entryPrice + (StringToDouble(ObjectGetString(0, "SL_INPUT", OBJPROP_TEXT)) * point);
      g_tp1 = g_entryPrice - (StringToDouble(ObjectGetString(0, "TP1_INPUT", OBJPROP_TEXT)) * point);
      g_tp2 = g_entryPrice - (StringToDouble(ObjectGetString(0, "TP2_INPUT", OBJPROP_TEXT)) * point);
   }
}

//+------------------------------------------------------------------+
//| Calculer le lot size selon le risque                              |
//+------------------------------------------------------------------+
void CalculateLotSize()
{
   g_riskPercent = StringToDouble(ObjectGetString(0, "RISK_INPUT", OBJPROP_TEXT));
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (g_riskPercent / 100.0);
   
   double slDistance = MathAbs(g_entryPrice - g_sl);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(slDistance > 0 && tickSize > 0)
   {
      double lots = riskAmount / (slDistance / tickSize * tickValue);
      g_lotSize = NormalizeLotSize(lots);
      
      // Calculer les statistiques
      g_riskUSD = riskAmount;
      g_rewardUSD = (MathAbs(g_tp1 - g_entryPrice) / slDistance) * riskAmount;
      g_rrRatio = g_rewardUSD / g_riskUSD;
   }
   else
   {
      g_lotSize = 0.01;
      g_riskUSD = 0;
      g_rewardUSD = 0;
      g_rrRatio = 0;
   }
}

//+------------------------------------------------------------------+
//| Normaliser le lot size                                            |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(stepLot > 0)
      lots = MathFloor(lots / stepLot) * stepLot;
   
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage                                         |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // Mettre à jour les prix TP/SL
   ObjectSetString(0, "TP1_PRICE", OBJPROP_TEXT, DoubleToString(g_tp1, digits));
   ObjectSetString(0, "TP2_PRICE", OBJPROP_TEXT, DoubleToString(g_tp2, digits));
   ObjectSetString(0, "SL_PRICE", OBJPROP_TEXT, DoubleToString(g_sl, digits));
   
   // Mettre à jour le lot size
   ObjectSetString(0, "LOT_VALUE", OBJPROP_TEXT, DoubleToString(g_lotSize, 2));
   
   // Mettre à jour le R/R ratio
   ObjectSetString(0, "RR_VALUE", OBJPROP_TEXT, StringFormat("%.2f", g_rrRatio));
   
   // Mettre à jour les données de compte
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   ObjectSetString(0, "BALANCE", OBJPROP_TEXT, StringFormat("Bal: %.0f", balance));
   ObjectSetString(0, "EQUITY", OBJPROP_TEXT, StringFormat("Eq: %.0f", equity));
   
   color profitColor = (profit >= 0) ? clrLime : clrRed;
   ObjectSetString(0, "PROFIT", OBJPROP_TEXT, StringFormat("P/L: %.0f", profit));
   ObjectSetInteger(0, "PROFIT", OBJPROP_COLOR, profitColor);
}

//+------------------------------------------------------------------+
//| Mettre à jour les données de marché en temps réel                   |
//+------------------------------------------------------------------+
void UpdateMarketData()
{
   static datetime lastUpdate = 0;
   datetime currentTime = TimeCurrent();
   
   // Mettre à jour toutes les secondes
   if(currentTime - lastUpdate < 1) return;
   lastUpdate = currentTime;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   // Spread
   double spread = (tick.ask - tick.bid) / _Point;
   ObjectSetString(0, "SPREAD", OBJPROP_TEXT, StringFormat("Spr: %.0f", spread));
   
   // ATR
   int hAtr = iATR(_Symbol, PERIOD_M1, 14);
   if(hAtr != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(hAtr, 0, 0, 1, atrBuf) >= 1)
      {
         ObjectSetString(0, "ATR", OBJPROP_TEXT, StringFormat("ATR: %.1f", atrBuf[0]));
      }
      IndicatorRelease(hAtr);
   }
   
   // RSI
   int hRsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   if(hRsi != INVALID_HANDLE)
   {
      double rsiBuf[];
      ArraySetAsSeries(rsiBuf, true);
      if(CopyBuffer(hRsi, 0, 0, 1, rsiBuf) >= 1)
      {
         color rsiColor = clrWhite;
         if(rsiBuf[0] > 70) rsiColor = clrRed;
         else if(rsiBuf[0] < 30) rsiColor = clrLime;
         
         ObjectSetString(0, "RSI", OBJPROP_TEXT, StringFormat("RSI: %.0f", rsiBuf[0]));
         ObjectSetInteger(0, "RSI", OBJPROP_COLOR, rsiColor);
      }
      IndicatorRelease(hRsi);
   }
   
   // EMA Trend
   int hEmaFast = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   int hEmaSlow = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
   {
      double bufFast[], bufSlow[];
      ArraySetAsSeries(bufFast, true);
      ArraySetAsSeries(bufSlow, true);
      if(CopyBuffer(hEmaFast, 0, 0, 1, bufFast) >= 1 && CopyBuffer(hEmaSlow, 0, 0, 1, bufSlow) >= 1)
      {
         string trendText = "➡️";
         color trendColor = clrWhite;
         
         if(bufFast[0] > bufSlow[0])
         {
            trendText = "📈";
            trendColor = clrLime;
         }
         else if(bufFast[0] < bufSlow[0])
         {
            trendText = "📉";
            trendColor = clrRed;
         }
         
         ObjectSetString(0, "EMA_TREND", OBJPROP_TEXT, trendText);
         ObjectSetInteger(0, "EMA_TREND", OBJPROP_COLOR, trendColor);
      }
      IndicatorRelease(hEmaFast);
      IndicatorRelease(hEmaSlow);
   }
   
   // Positions ouvertes
   int totalPositions = PositionsTotal();
   ObjectSetString(0, "POSITIONS", OBJPROP_TEXT, StringFormat("Pos: %d", totalPositions));
   
   // Heure
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   ObjectSetString(0, "TIME", OBJPROP_TEXT, StringFormat("%02d:%02d", timeStruct.hour, timeStruct.min));
}

//+------------------------------------------------------------------+
//| Gérer les clics sur les boutons                                   |
//+------------------------------------------------------------------+
void HandleButtonClick(string objectName)
{
   if(objectName == "BTN_BUY")
   {
      g_signal = "BUY";
      ObjectSetString(0, "SIGNAL_VALUE", OBJPROP_TEXT, "📈 BUY");
      ObjectSetInteger(0, "SIGNAL_VALUE", OBJPROP_COLOR, InpBuyColor);
      CalculateTPSL();
      CalculateLotSize();
      UpdateDisplay();
      Print("📈 Signal BUY sélectionné");
   }
   else if(objectName == "BTN_SELL")
   {
      g_signal = "SELL";
      ObjectSetString(0, "SIGNAL_VALUE", OBJPROP_TEXT, "📉 SELL");
      ObjectSetInteger(0, "SIGNAL_VALUE", OBJPROP_COLOR, InpSellColor);
      CalculateTPSL();
      CalculateLotSize();
      UpdateDisplay();
      Print("📉 Signal SELL sélectionné");
   }
   else if(objectName == "BTN_WAIT")
   {
      g_signal = "WAIT";
      ObjectSetString(0, "SIGNAL_VALUE", OBJPROP_TEXT, "⏳ WAIT");
      ObjectSetInteger(0, "SIGNAL_VALUE", OBJPROP_COLOR, clrGray);
      Print("⏳ Signal WAIT sélectionné");
   }
   else if(objectName == "BTN_AI_ANALYZE")
   {
      ExecuteAIAnalysis();
   }
   else if(objectName == "BTN_EXECUTE")
   {
      ExecuteTrade();
   }
   
   // Réinitialiser l'état du bouton
   ObjectSetInteger(0, objectName, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| Gérer les touches clavier                                         |
//+------------------------------------------------------------------+
void HandleKeyPress(long key)
{
   if(key == 66) // B = BUY
   {
      HandleButtonClick("BTN_BUY");
   }
   else if(key == 83) // S = SELL
   {
      HandleButtonClick("BTN_SELL");
   }
   else if(key == 87) // W = WAIT
   {
      HandleButtonClick("BTN_WAIT");
   }
   else if(key == 13) // ENTER = EXECUTE
   {
      HandleButtonClick("BTN_EXECUTE");
   }
}

//+------------------------------------------------------------------+
//| Vérifier les événements du panneau                                |
//+------------------------------------------------------------------+
void CheckPanelEvents()
{
   // Vérifier les changements dans les champs d'édition
   string riskValue = ObjectGetString(0, "RISK_INPUT", OBJPROP_TEXT);
   if(riskValue != "" && StringToDouble(riskValue) != g_riskPercent)
   {
      CalculateLotSize();
      UpdateDisplay();
   }
}

//+------------------------------------------------------------------+
//| Exécuter le trade                                                 |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   if(g_signal == "WAIT")
   {
      Alert("⚠️ Veuillez sélectionner BUY ou SELL avant d'exécuter le trade");
      return;
   }
   
   if(g_lotSize <= 0)
   {
      Alert("⚠️ Lot size invalide");
      return;
   }
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      Alert("⚠️ Impossible d'obtenir les prix");
      return;
   }
   
   bool result = false;
   string comment = "Trading Algo - Charles Robot";
   
   if(g_signal == "BUY")
   {
      result = trade.Buy(g_lotSize, _Symbol, tick.ask, g_sl, g_tp1, comment);
      if(result)
         Print("✅ BUY exécuté: Lot=", g_lotSize, " Entry=", tick.ask, " SL=", g_sl, " TP1=", g_tp1);
      else
         Print("❌ BUY échoué: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
   else if(g_signal == "SELL")
   {
      result = trade.Sell(g_lotSize, _Symbol, tick.bid, g_sl, g_tp1, comment);
      if(result)
         Print("✅ SELL exécuté: Lot=", g_lotSize, " Entry=", tick.bid, " SL=", g_sl, " TP1=", g_tp1);
      else
         Print("❌ SELL échoué: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
   
   if(result)
   {
      Alert("🚀 Trade exécuté avec succès! Signal: ", g_signal, " Lot: ", g_lotSize);
      // Réinitialiser le signal
      g_signal = "WAIT";
      ObjectSetString(0, "SIGNAL_VALUE", OBJPROP_TEXT, "⏳ WAIT");
      ObjectSetInteger(0, "SIGNAL_VALUE", OBJPROP_COLOR, clrGray);
   }
}

//+------------------------------------------------------------------+
//| Créer un rectangle                                                |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x, int y, int width, int height, color col)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, col);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Créer un label                                                    |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, int size, color col)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   }
}

//+------------------------------------------------------------------+
//| Créer un champ d'édition                                          |
//+------------------------------------------------------------------+
void CreateEdit(string name, int x, int y, int width, int height, string text, int size)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   }
}

//+------------------------------------------------------------------+
//| Créer un bouton                                                   |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, int width, int height, string text, color textCol, color bgCol)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textCol);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgCol);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Créer une ligne horizontale                                       |
//+------------------------------------------------------------------+
void CreateHLine(string name, int x, int y, int width, color col)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 1);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, col);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Nettoyer le panneau                                               |
//+------------------------------------------------------------------+
void CleanupPanel()
{
   string objects[] = {
      "PANEL_BG", "TITLE", "ACCOUNT_TITLE", "BALANCE", "EQUITY", "PROFIT",
      "SEP0", "SYMBOL", "SIGNAL_VALUE",
      "BTN_BUY", "BTN_SELL", "BTN_WAIT", "SEP1",
      "MARKET_TITLE", "SPREAD", "ATR", "RSI", "EMA_TREND", "POSITIONS", "TIME",
      "SEP2", "TRADE_TITLE", "RISK_LABEL", "RISK_INPUT", "LOT_LABEL", "LOT_VALUE",
      "TP1_LABEL", "TP1_INPUT", "TP1_PRICE", "TP2_LABEL", "TP2_INPUT", "TP2_PRICE",
      "SL_LABEL", "SL_INPUT", "SL_PRICE", "RR_LABEL", "RR_VALUE",
      "SEP3", "AI_TITLE", "AI_ACTION_VALUE", "AI_CONFIDENCE_VALUE",
      "BTN_AI_ANALYZE", "AI_REASON_VALUE", "SEP4", "BTN_EXECUTE"
   };
   
   for(int i = 0; i < ArraySize(objects); i++)
   {
      ObjectDelete(0, objects[i]);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculer les indicateurs techniques automatiquement                 |
//+------------------------------------------------------------------+
void CalculateTechnicalIndicators()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double bid = tick.bid;
   double ask = tick.ask;
   
   // RSI M1
   if(InpRSI == 0)
   {
      int hRsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
      if(hRsi != INVALID_HANDLE)
      {
         double rsiBuf[];
         ArraySetAsSeries(rsiBuf, true);
         if(CopyBuffer(hRsi, 0, 0, 1, rsiBuf) >= 1)
            g_techRSI = rsiBuf[0];
         else
            g_techRSI = 50.0;
         IndicatorRelease(hRsi);
      }
      else
         g_techRSI = 50.0;
   }
   else
      g_techRSI = InpRSI;
   
   // EMA H1
   if(InpEMA_Fast_H1 == 0 || InpEMA_Slow_H1 == 0)
   {
      int hEmaFast = iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
      int hEmaSlow = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
      if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
      {
         double bufFast[], bufSlow[];
         ArraySetAsSeries(bufFast, true);
         ArraySetAsSeries(bufSlow, true);
         if(CopyBuffer(hEmaFast, 0, 0, 1, bufFast) >= 1)
            g_techEMA_Fast_H1 = bufFast[0];
         if(CopyBuffer(hEmaSlow, 0, 0, 1, bufSlow) >= 1)
            g_techEMA_Slow_H1 = bufSlow[0];
         IndicatorRelease(hEmaFast);
         IndicatorRelease(hEmaSlow);
      }
   }
   else
   {
      g_techEMA_Fast_H1 = InpEMA_Fast_H1;
      g_techEMA_Slow_H1 = InpEMA_Slow_H1;
   }
   
   // EMA M1
   if(InpEMA_Fast_M1 == 0 || InpEMA_Slow_M1 == 0)
   {
      int hEmaFast = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
      int hEmaSlow = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
      if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
      {
         double bufFast[], bufSlow[];
         ArraySetAsSeries(bufFast, true);
         ArraySetAsSeries(bufSlow, true);
         if(CopyBuffer(hEmaFast, 0, 0, 1, bufFast) >= 1)
            g_techEMA_Fast_M1 = bufFast[0];
         if(CopyBuffer(hEmaSlow, 0, 0, 1, bufSlow) >= 1)
            g_techEMA_Slow_M1 = bufSlow[0];
         IndicatorRelease(hEmaFast);
         IndicatorRelease(hEmaSlow);
      }
   }
   else
   {
      g_techEMA_Fast_M1 = InpEMA_Fast_M1;
      g_techEMA_Slow_M1 = InpEMA_Slow_M1;
   }
   
   // EMA M5
   if(InpEMA_Fast_M5 == 0 || InpEMA_Slow_M5 == 0)
   {
      int hEmaFast = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
      int hEmaSlow = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
      if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
      {
         double bufFast[], bufSlow[];
         ArraySetAsSeries(bufFast, true);
         ArraySetAsSeries(bufSlow, true);
         if(CopyBuffer(hEmaFast, 0, 0, 1, bufFast) >= 1)
            g_techEMA_Fast_M5 = bufFast[0];
         if(CopyBuffer(hEmaSlow, 0, 0, 1, bufSlow) >= 1)
            g_techEMA_Slow_M5 = bufSlow[0];
         IndicatorRelease(hEmaFast);
         IndicatorRelease(hEmaSlow);
      }
   }
   else
   {
      g_techEMA_Fast_M5 = InpEMA_Fast_M5;
      g_techEMA_Slow_M5 = InpEMA_Slow_M5;
   }
   
   // ATR
   if(InpATR == 0)
   {
      int hAtr = iATR(_Symbol, PERIOD_M1, 14);
      if(hAtr != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(hAtr, 0, 0, 1, atrBuf) >= 1)
            g_techATR = atrBuf[0];
         IndicatorRelease(hAtr);
      }
   }
   else
      g_techATR = InpATR;
   
   // Autres paramètres (utiliser les valeurs input si fournies)
   g_techVWAP = InpVWAP;
   g_techVWAPDistance = InpVWAPDistance;
   g_techAboveVWAP = InpAboveVWAP;
   g_techSuperTrendTrend = InpSuperTrendTrend;
   g_techSuperTrendLine = InpSuperTrendLine;
   g_techVolatilityRegime = InpVolatilityRegime;
   g_techVolatilityRatio = InpVolatilityRatio;
}

//+------------------------------------------------------------------+
//| Extraire une valeur string depuis JSON                             |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
   string searchKey = "\"" + key + "\"";
   int pos = StringFind(json, searchKey);
   if(pos < 0) return "";
   
   int colonPos = StringFind(json, ":", pos);
   if(colonPos < 0) return "";
   
   int valueStart = colonPos + 1;
   while(valueStart < (int)StringLen(json) && (json[valueStart] == ' ' || json[valueStart] == '\t'))
      valueStart++;
   
   if(valueStart >= (int)StringLen(json)) return "";
   
   bool isString = (json[valueStart] == '"');
   if(isString) valueStart++;
   
   int valueEnd = valueStart;
   if(isString)
   {
      while(valueEnd < (int)StringLen(json) && json[valueEnd] != '"')
         valueEnd++;
   }
   else
   {
      while(valueEnd < (int)StringLen(json) && json[valueEnd] != ',' && json[valueEnd] != '}' && json[valueEnd] != '\n')
         valueEnd++;
   }
   
   string result = StringSubstr(json, valueStart, valueEnd - valueStart);
   StringTrimRight(result);
   return result;
}

//+------------------------------------------------------------------+
//| Extraire une valeur double depuis JSON                            |
//+------------------------------------------------------------------+
double ExtractJsonDouble(string json, string key)
{
   string valueStr = ExtractJsonValue(json, key);
   if(valueStr == "") return 0.0;
   return StringToDouble(valueStr);
}

//+------------------------------------------------------------------+
//| Envoyer la requête de décision au serveur IA                       |
//+------------------------------------------------------------------+
string SendDecisionRequest()
{
   if(!UseAIServer)
   {
      Print("⚠️ Serveur IA désactivé");
      return "";
   }
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("❌ Impossible d'obtenir les prix");
      return "";
   }
   
   // Construire le JSON de la requête
   string json = "{";
   json += "\"symbol\":\"" + _Symbol + "\",";
   json += "\"bid\":" + DoubleToString(tick.bid, 5) + ",";
   json += "\"ask\":" + DoubleToString(tick.ask, 5) + ",";
   json += "\"rsi\":" + DoubleToString(g_techRSI, 2) + ",";
   json += "\"ema_fast_h1\":" + DoubleToString(g_techEMA_Fast_H1, 5) + ",";
   json += "\"ema_slow_h1\":" + DoubleToString(g_techEMA_Slow_H1, 5) + ",";
   json += "\"ema_fast_m1\":" + DoubleToString(g_techEMA_Fast_M1, 5) + ",";
   json += "\"ema_slow_m1\":" + DoubleToString(g_techEMA_Slow_M1, 5) + ",";
   json += "\"ema_fast_m5\":" + DoubleToString(g_techEMA_Fast_M5, 5) + ",";
   json += "\"ema_slow_m5\":" + DoubleToString(g_techEMA_Slow_M5, 5) + ",";
   json += "\"atr\":" + DoubleToString(g_techATR, 5) + ",";
   json += "\"dir_rule\":" + IntegerToString(InpDirRule) + ",";
   json += "\"is_spike_mode\":" + (InpIsSpikeMode ? "true" : "false") + ",";
   json += "\"vwap\":" + DoubleToString(g_techVWAP, 5) + ",";
   json += "\"vwap_distance\":" + DoubleToString(g_techVWAPDistance, 5) + ",";
   json += "\"above_vwap\":" + (g_techAboveVWAP ? "true" : "false") + ",";
   json += "\"supertrend_trend\":" + IntegerToString(g_techSuperTrendTrend) + ",";
   json += "\"supertrend_line\":" + DoubleToString(g_techSuperTrendLine, 5) + ",";
   json += "\"volatility_regime\":" + IntegerToString(g_techVolatilityRegime) + ",";
   json += "\"volatility_ratio\":" + DoubleToString(g_techVolatilityRatio, 2) + ",";
   json += "\"timestamp\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\"";
   json += "}";
   
   // Préparer la requête WebRequest
   char data[];
   char result[];
   string resultHeaders;
   StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(data, ArraySize(data) - 1); // Supprimer le null terminator
   
   string headers = "Content-Type: application/json\r\n";
   
   Print("📤 Envoi requête décision à ", AI_ServerURL, "/decision");
   
   int timeout = AI_Timeout_ms;
   int res = WebRequest("POST", AI_ServerURL + "/decision", headers, timeout, data, result, resultHeaders);
   
   if(res == 200)
   {
      string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("✅ Réponse reçue: ", response);
      return response;
   }
   else
   {
      Print("❌ Erreur WebRequest: ", res, " - ", GetLastError());
      return "";
   }
}

//+------------------------------------------------------------------+
//| Parser la réponse de décision IA                                   |
//+------------------------------------------------------------------+
bool ParseDecisionResponse(string json)
{
   if(json == "") return false;
   
   g_aiAction = ExtractJsonValue(json, "action");
   StringToUpper(g_aiAction);
   
   g_aiConfidence = ExtractJsonDouble(json, "confidence");
   g_aiReason = ExtractJsonValue(json, "reason");
   g_aiStopLoss = ExtractJsonDouble(json, "stop_loss");
   g_aiTakeProfit = ExtractJsonDouble(json, "take_profit");
   g_aiModelUsed = ExtractJsonValue(json, "model_used");
   
   // Si la réponse contient "trade_allowed", vérifier
   string tradeAllowed = ExtractJsonValue(json, "trade_allowed");
   if(tradeAllowed == "false" && g_aiAction == "HOLD")
      g_aiAction = "HOLD";
   
   g_aiAnalysisReady = true;
   
   Print("🤖 Analyse IA: Action=", g_aiAction, " Confiance=", g_aiConfidence, " Raison=", g_aiReason);
   
   return true;
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage des résultats IA                         |
//+------------------------------------------------------------------+
void UpdateAIDisplay()
{
   if(!g_aiAnalysisReady) return;
   
   // Afficher l'action
   string actionText = "⏳ WAIT";
   color actionColor = clrGray;
   
   if(g_aiAction == "BUY")
   {
      actionText = "📈 BUY";
      actionColor = clrLime;
   }
   else if(g_aiAction == "SELL")
   {
      actionText = "📉 SELL";
      actionColor = clrRed;
   }
   else if(g_aiAction == "HOLD")
   {
      actionText = "⏸️ HOLD";
      actionColor = clrOrange;
   }
   
   ObjectSetString(0, "AI_ACTION_VALUE", OBJPROP_TEXT, actionText);
   ObjectSetInteger(0, "AI_ACTION_VALUE", OBJPROP_COLOR, actionColor);
   
   // Afficher la confiance
   ObjectSetString(0, "AI_CONFIDENCE_VALUE", OBJPROP_TEXT, DoubleToString(g_aiConfidence * 100, 0) + "%");
   
   // Afficher la raison (tronquer si trop long pour l'interface compacte)
   string reasonDisplay = g_aiReason;
   if(StringLen(reasonDisplay) > 35)
      reasonDisplay = StringSubstr(reasonDisplay, 0, 35) + "...";
   ObjectSetString(0, "AI_REASON_VALUE", OBJPROP_TEXT, reasonDisplay);
   
   // Si l'IA propose un signal, le synchroniser avec le signal manuel
   if(g_aiAction == "BUY" || g_aiAction == "SELL")
   {
      g_signal = g_aiAction;
      ObjectSetString(0, "SIGNAL_VALUE", OBJPROP_TEXT, actionText);
      ObjectSetInteger(0, "SIGNAL_VALUE", OBJPROP_COLOR, actionColor);
      
      // Mettre à jour SL/TP si proposés par l'IA
      if(g_aiStopLoss > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         g_sl = g_aiStopLoss;
         int slPoints = (int)MathRound(MathAbs(g_entryPrice - g_sl) / point);
         ObjectSetString(0, "SL_INPUT", OBJPROP_TEXT, DoubleToString(slPoints, 1));
      }
      
      if(g_aiTakeProfit > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         g_tp1 = g_aiTakeProfit;
         int tpPoints = (int)MathRound(MathAbs(g_tp1 - g_entryPrice) / point);
         ObjectSetString(0, "TP1_INPUT", OBJPROP_TEXT, DoubleToString(tpPoints, 1));
      }
      
      CalculateTPSL();
      CalculateLotSize();
      UpdateDisplay();
   }
   
   // Envoyer notification push
   SendPushNotification();
}

//+------------------------------------------------------------------+
//| Envoyer notification push                                         |
//+------------------------------------------------------------------+
void SendPushNotification()
{
   string message = "🤖 Analyse IA " + _Symbol + ": " + g_aiAction + " (" + DoubleToString(g_aiConfidence * 100, 1) + "%)";
   if(g_aiReason != "")
      message += " - " + g_aiReason;
   
   SendNotification(message);
   Print("📱 Notification push envoyée: ", message);
}

//+------------------------------------------------------------------+
//| Exécuter l'analyse IA complète                                     |
//+------------------------------------------------------------------+
void ExecuteAIAnalysis()
{
   Print("📊 Début analyse technique pour ", _Symbol);
   
   // Calculer les indicateurs techniques
   CalculateTechnicalIndicators();
   
   // Envoyer la requête au serveur IA
   string response = SendDecisionRequest();
   
   if(response != "")
   {
      // Parser la réponse
      if(ParseDecisionResponse(response))
      {
         // Mettre à jour l'affichage
         UpdateAIDisplay();
         Print("✅ Analyse IA terminée avec succès");
      }
      else
      {
         Print("❌ Erreur lors du parsing de la réponse IA");
      }
   }
   else
   {
      Print("❌ Aucune réponse du serveur IA");
      ObjectSetString(0, "AI_ACTION_VALUE", OBJPROP_TEXT, "❌ ERREUR");
      ObjectSetInteger(0, "AI_ACTION_VALUE", OBJPROP_COLOR, clrRed);
   }
}

//+------------------------------------------------------------------+
