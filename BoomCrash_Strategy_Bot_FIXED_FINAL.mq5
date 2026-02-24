//+------------------------------------------------------------------+
//|                                           BoomCrash_Strategy_Bot.mq5 |
//|                             Copyright 2024, Sidoine1991/KolaTradeboT |
//|                                          https://github.com/Sidoine1991 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Sidoine1991/KolaTradeboT"
#property link      "https://github.com/Sidoine1991"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Paramètres de stratégie
input group           "Paramètres de Stratégie"
input int             MA_Period = 20;              // Période de la Moyenne Mobile
input ENUM_MA_METHOD  MA_Method = MODE_EMA;        // Méthode de la Moyenne Mobile
input int             RSI_Period = 14;             // Période du RSI
input double          RSI_Oversold_Level = 30.0;    // Niveau de survente RSI
input double          RSI_Overbought_Level = 70.0;  // Niveau de surachat RSI
input int             ATR_Period = 14;             // Période ATR pour détection spike

//--- Détection Spike (comme F_INX_scalper_double)
input group           "Détection Spike"
input bool            UseSpikeDetection = true;     // Activer détection spike
input double          MinATRExpansionRatio = 1.15;   // ATR actuel / ATR moyen > ce ratio = spike volatilité
input int             ATR_AverageBars = 20;          // Barres pour moyenne ATR
input double          MinCandleBodyATR = 0.35;      // Corps bougie / ATR min (grosse bougie = spike)
input double          MinRSISpike = 25.0;            // RSI extrême pour Crash (plus bas = spike)
input double          MaxRSISpike = 75.0;            // RSI extrême pour Boom (plus haut = spike)

//--- API Render (DÉSACTIVÉE POUR ÉVITER LES ERREURS)
input group           "API Render (DÉSACTIVÉE)"
input bool            UseRenderAPI = false;         // API désactivée pour éviter erreurs 422/404
input string          AI_ServerURL = "";             // Non utilisé
input string          TrendAPIURL = "";              // Non utilisé
input string          AI_PredictURL = "";            // Non utilisé
input int             AI_Timeout_ms = 10000;         // Non utilisé
input int             AI_UpdateInterval_sec = 60;    // Non utilisé
input double          MinAPIConfidence = 0.40;       // Non utilisé

//--- Gestion du Risque
input group           "Gestion du Risque"
input double          LotSize = 0.01;               // Taille de position
input int             StopLoss_Pips = 0;            // SL en pips (0 = désactivé)
input int             TakeProfit_Pips = 0;          // TP en pips (0 = désactivé)

input group           "Gestion des Profits/Pertes"
input bool            CloseOnSpikeProfit = true;    // Fermer après spike profit
input double          SpikeProfitClose_USD = 0.50;  // Fermer quand profit >= ce montant
input bool            CloseOnMaxLoss = true;         // Fermer après perte maximale
input double          MaxLoss_USD = 3.0;            // Fermer quand perte >= ce montant

input group           "Trailing Stop"
input bool            UseTrailingStop = true;        // Activer Trailing Stop
input int             TrailingStop_Pips = 5000;      // Distance Trailing Stop

input group           "Identification du Robot"
input long            MagicNumber = 12345;          // Numéro magique
input bool            DebugLog = true;              // Afficher logs de debug

//--- Affichage Graphique
input group           "Affichage Graphique"
input bool            ShowMA = true;                // Afficher MA mobile
input bool            ShowRSI = true;               // Afficher RSI
input bool            ShowSignals = true;           // Afficher signaux d'entrée
input color           MA_Color = clrBlue;           // Couleur MA
input color           RSI_Color_Up = clrGreen;      // Couleur RSI survente
input color           RSI_Color_Down = clrRed;      // Couleur RSI surachat
input color           BuySignalColor = clrLime;     // Couleur signal BUY
input color           SellSignalColor = clrRed;     // Couleur signal SELL

//--- Variables globales
CTrade trade;

//--- Handles pour indicateurs
int ma_handle;
int rsi_handle;
int atr_handle;

//--- EMA rapides pour M1, M5, H1
int emaFastM1_handle;
int emaSlowM1_handle;
int emaFastM5_handle;
int emaSlowM5_handle;
int emaFastH1_handle;
int emaSlowH1_handle;

//--- Variables pour les buffers
double ma_buffer[];
double rsi_buffer[];
double atr_buffer[];
double emaFastM1_buffer[];
double emaSlowM1_buffer[];
double emaFastM5_buffer[];
double emaSlowM5_buffer[];
double emaFastH1_buffer[];
double emaSlowH1_buffer[];

//--- Variables globales
MqlTick last_tick;
double pip_value;

//+------------------------------------------------------------------+
//| Calcule SL/TP valides                                            |
//+------------------------------------------------------------------+
void NormalizeSLTP(bool isBuy, double entry, double& sl, double& tp)
{
   if(StopLoss_Pips == 0 && TakeProfit_Pips == 0)
   {
      sl = 0;
      tp = 0;
      return;
   }
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (stopsLevel > 0) ? (stopsLevel * point) : (10 * point);

   double slDist = MathMax(StopLoss_Pips * point, minDist);
   double tpDist = MathMax(TakeProfit_Pips * point, minDist);

   if(isBuy)
   {
      sl = NormalizeDouble(entry - slDist, digits);
      tp = NormalizeDouble(entry + tpDist, digits);
   }
   else
   {
      sl = NormalizeDouble(entry + slDist, digits);
      tp = NormalizeDouble(entry - tpDist, digits);
   }
}

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);

   // Créer les handles
   ma_handle = iMA(_Symbol, _Period, MA_Period, 0, MA_Method, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   
   // EMA rapides
   emaFastM1_handle = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM1_handle = iMA(_Symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM5_handle = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5_handle = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   emaFastH1_handle = iMA(_Symbol, PERIOD_H1, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowH1_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(ma_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE ||
      emaFastM1_handle == INVALID_HANDLE || emaSlowM1_handle == INVALID_HANDLE ||
      emaFastM5_handle == INVALID_HANDLE || emaSlowM5_handle == INVALID_HANDLE ||
      emaFastH1_handle == INVALID_HANDLE || emaSlowH1_handle == INVALID_HANDLE)
   {
      Print("Erreur création handles indicateurs");
      return(INIT_FAILED);
   }

   pip_value = _Point * pow(10, _Digits % 2);
   
   Print("BoomCrash Bot initialisé - Mode Technique (API désactivée)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Désinitialisation                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ma_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);
   IndicatorRelease(emaFastM1_handle);
   IndicatorRelease(emaSlowM1_handle);
   IndicatorRelease(emaFastM5_handle);
   IndicatorRelease(emaSlowM5_handle);
   IndicatorRelease(emaFastH1_handle);
   IndicatorRelease(emaSlowH1_handle);
   
   // Nettoyer les objets graphiques
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(0, i, -1, -1);
      if(StringFind(obj_name, "BoomCrash_") >= 0)
      {
         ObjectDelete(0, obj_name);
      }
   }
   
   Print("BoomCrash Bot désinitialisé");
}

//+------------------------------------------------------------------+
//| Tick principal                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime last_update = 0;
   if(TimeCurrent() - last_update < 1) return; // Limiter à 1 update par seconde
   last_update = TimeCurrent();

   // Mettre à jour les indicateurs
   if(!UpdateIndicators()) return;

   // Gérer les positions existantes
   ManagePositions();

   // Ouvrir nouvelles positions
   OpenNewPositions();

   // Afficher les graphiques
   UpdateGraphics();
}

//+------------------------------------------------------------------+
//| Mettre à jour les indicateurs                                     |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   if(CopyBuffer(ma_handle, 0, 0, 1, ma_buffer) <= 0 ||
      CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) <= 0 ||
      CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0 ||
      CopyBuffer(emaFastM1_handle, 0, 0, 1, emaFastM1_buffer) <= 0 ||
      CopyBuffer(emaSlowM1_handle, 0, 0, 1, emaSlowM1_buffer) <= 0 ||
      CopyBuffer(emaFastM5_handle, 0, 0, 1, emaFastM5_buffer) <= 0 ||
      CopyBuffer(emaSlowM5_handle, 0, 0, 1, emaSlowM5_buffer) <= 0 ||
      CopyBuffer(emaFastH1_handle, 0, 0, 1, emaFastH1_buffer) <= 0 ||
      CopyBuffer(emaSlowH1_handle, 0, 0, 1, emaSlowH1_buffer) <= 0)
   {
      return false;
   }
   
   SymbolInfoTick(_Symbol, last_tick);
   return true;
}

//+------------------------------------------------------------------+
//| Gérer les positions                                              |
//+------------------------------------------------------------------+
void ManagePositions()
{
   ulong ticket = GetMyPositionTicket();
   if(ticket != 0)
      ManageTrailingStop(ticket);
}

//+------------------------------------------------------------------+
//| Ouvrir nouvelles positions                                        |
//+------------------------------------------------------------------+
void OpenNewPositions()
{
   if(PositionsTotal() > 0) return; // Une position à la fois

   double ask = last_tick.ask;
   double bid = last_tick.bid;
   double price = bid;
   
   // Vérifier le type de symbole
   bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
   bool is_crash = (StringFind(_Symbol, "Crash") >= 0);
   
   // Signaux techniques basés sur EMA rapides M1
   bool tech_buy_m1 = (price > emaFastM1_buffer[0] && rsi_buffer[0] < RSI_Oversold_Level);
   bool tech_sell_m1 = (price < emaFastM1_buffer[0] && rsi_buffer[0] > RSI_Overbought_Level);
   
   // Alignement des tendances M5/M1 (OBLIGATOIRE)
   bool trend_alignment_buy = (emaFastM1_buffer[0] > emaSlowM1_buffer[0]) && (emaFastM5_buffer[0] > emaSlowM5_buffer[0]);
   bool trend_alignment_sell = (emaFastM1_buffer[0] < emaSlowM1_buffer[0]) && (emaFastM5_buffer[0] < emaSlowM5_buffer[0]);
   
   // Logique d'ouverture COMPLÈTE
   if(is_boom)
   {
      // Boom: seulement BUY avec conditions strictes
      if(tech_buy_m1 && trend_alignment_buy)
      {
         if(trade.Buy(LotSize, _Symbol, ask, 0, 0, "BoomCrash Boom BUY (EMA M1 + Alignement M5/M1)"))
         {
            Print("🚀 BOOM BUY OUVERT - Signal technique EMA M1 + Alignement M5/M1");
         }
      }
   }
   else if(is_crash)
   {
      // Crash: seulement SELL avec conditions strictes
      if(tech_sell_m1 && trend_alignment_sell)
      {
         if(trade.Sell(LotSize, _Symbol, bid, 0, 0, "BoomCrash Crash SELL (EMA M1 + Alignement M5/M1)"))
         {
            Print("🚀 CRASH SELL OUVERT - Signal technique EMA M1 + Alignement M5/M1");
         }
      }
   }
   
   if(DebugLog && !((is_boom && tech_buy_m1 && trend_alignment_buy) || 
                    (is_crash && tech_sell_m1 && trend_alignment_sell)))
   {
      if(is_boom)
         Print("BoomCrash ", _Symbol, " | pas d'ouverture BUY: EMA M1=", (price > emaFastM1_buffer[0] ? "✅" : "❌"), 
               " | Alignement M5/M1=", (trend_alignment_buy ? "✅" : "❌"));
      else
         Print("BoomCrash ", _Symbol, " | pas d'ouverture SELL: EMA M1=", (price < emaFastM1_buffer[0] ? "✅" : "❌"), 
               " | Alignement M5/M1=", (trend_alignment_sell ? "✅" : "❌"));
   }
}

//+------------------------------------------------------------------+
//| Gérer trailing stop                                              |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;

   double profit = PositionGetDouble(POSITION_PROFIT);
   double swap = PositionGetDouble(POSITION_SWAP);
   double commission = PositionGetDouble(POSITION_COMMISSION);
   double totalUSD = profit + swap + commission;

   // Fermer après spike profit
   if(CloseOnSpikeProfit && SpikeProfitClose_USD > 0 && totalUSD >= SpikeProfitClose_USD)
   {
      if(trade.PositionClose(ticket))
         Print("✅ Position fermée après spike | Profit: ", DoubleToString(totalUSD, 2), " USD");
      return;
   }

   // Fermer après perte maximale
   if(CloseOnMaxLoss && MaxLoss_USD > 0 && totalUSD <= -MaxLoss_USD)
   {
      if(trade.PositionClose(ticket))
         Print("❌ Position fermée après perte max | Perte: ", DoubleToString(totalUSD, 2), " USD");
      return;
   }

   if(!UseTrailingStop) return;

   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   SymbolInfoTick(_Symbol, last_tick);

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      double new_sl = last_tick.bid - TrailingStop_Pips * _Point;
      if(last_tick.bid > open_price + TrailingStop_Pips * _Point && new_sl > current_sl)
         trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      double new_sl = last_tick.ask + TrailingStop_Pips * _Point;
      if(last_tick.ask < open_price - TrailingStop_Pips * _Point && (new_sl < current_sl || current_sl == 0))
         trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
   }
}

//+------------------------------------------------------------------+
//| Obtenir ticket de position                                       |
//+------------------------------------------------------------------+
ulong GetMyPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         return PositionGetTicket(i);
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage graphique                              |
//+------------------------------------------------------------------+
void UpdateGraphics()
{
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Afficher MA mobile
   if(ShowMA && ArraySize(ma_buffer) > 0)
   {
      string ma_name = "BoomCrash_MA_" + IntegerToString(MA_Period);
      ObjectCreate(0, ma_name, OBJ_HLINE, 0, 0, ma_buffer[0]);
      ObjectSetInteger(0, ma_name, OBJPROP_COLOR, MA_Color);
      ObjectSetInteger(0, ma_name, OBJPROP_WIDTH, 2);
   }
   
   // Afficher EMA rapides M1
   if(ShowMA && ArraySize(emaFastM1_buffer) > 0 && ArraySize(emaSlowM1_buffer) > 0)
   {
      string ema_fast_m1_name = "BoomCrash_EMA_Fast_M1";
      string ema_slow_m1_name = "BoomCrash_EMA_Slow_M1";
      
      ObjectCreate(0, ema_fast_m1_name, OBJ_HLINE, 0, 0, emaFastM1_buffer[0]);
      ObjectSetInteger(0, ema_fast_m1_name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, ema_fast_m1_name, OBJPROP_WIDTH, 2);
      
      ObjectCreate(0, ema_slow_m1_name, OBJ_HLINE, 0, 0, emaSlowM1_buffer[0]);
      ObjectSetInteger(0, ema_slow_m1_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, ema_slow_m1_name, OBJPROP_WIDTH, 2);
   }
   
   // Afficher RSI
   if(ShowRSI && ArraySize(rsi_buffer) > 0)
   {
      string rsi_name = "BoomCrash_RSI_" + IntegerToString(RSI_Period);
      color rsi_color = (rsi_buffer[0] < RSI_Oversold_Level) ? RSI_Color_Up : 
                        (rsi_buffer[0] > RSI_Overbought_Level) ? RSI_Color_Down : clrGray;
      
      ObjectCreate(0, rsi_name, OBJ_TEXT, 0, 0, 0);
      ObjectSetString(0, rsi_name, OBJPROP_TEXT, "RSI: " + DoubleToString(rsi_buffer[0], 1));
      ObjectSetInteger(0, rsi_name, OBJPROP_COLOR, rsi_color);
      ObjectSetInteger(0, rsi_name, OBJPROP_FONTSIZE, 10);
   }
   
   // Afficher les signaux d'entrée
   if(ShowSignals)
   {
      DisplayTradeSignals();
   }
}

//+------------------------------------------------------------------+
//| Afficher les signaux de trading                                   |
//+------------------------------------------------------------------+
void DisplayTradeSignals()
{
   if(ArraySize(ma_buffer) < 2 || ArraySize(rsi_buffer) < 1)
      return;
   
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ma_value = ma_buffer[0];
   double rsi_value = rsi_buffer[0];
   
   // Signaux d'achat
   bool buy_signal = (current_price > ma_value && rsi_value < RSI_Oversold_Level);
   if(buy_signal)
   {
      string buy_arrow = "BoomCrash_BUY_" + IntegerToString((int)TimeCurrent());
      ObjectCreate(0, buy_arrow, OBJ_ARROW_UP, 0, TimeCurrent(), current_price);
      ObjectSetInteger(0, buy_arrow, OBJPROP_COLOR, BuySignalColor);
      ObjectSetInteger(0, buy_arrow, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, buy_arrow, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetString(0, buy_arrow, OBJPROP_TEXT, "BUY");
   }
   
   // Signaux de vente
   bool sell_signal = (current_price < ma_value && rsi_value > RSI_Overbought_Level);
   if(sell_signal)
   {
      string sell_arrow = "BoomCrash_SELL_" + IntegerToString((int)TimeCurrent());
      ObjectCreate(0, sell_arrow, OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price);
      ObjectSetInteger(0, sell_arrow, OBJPROP_COLOR, SellSignalColor);
      ObjectSetInteger(0, sell_arrow, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, sell_arrow, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetString(0, sell_arrow, OBJPROP_TEXT, "SELL");
   }
}
//+------------------------------------------------------------------+
