//+------------------------------------------------------------------+
//|                                      SpikeScalperProMax.mq5      |
//|  Scalper spike SELL (contexte baissier) — MQL5 propre            |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- inputs
input double InpLotSize            = 0.2;
input double InpMinConfidencePct   = 90.0;   // À brancher sur ton IA : remplacer par lecture serveur
input int    InpMagic              = 20260412;
input int    InpMaxPositions       = 7;
input double InpBasketProfitTarget = 0.5;
input double InpTrailingStart      = 0.2;
input double InpTrailingStep       = 0.05;
input int    InpEmaPeriod          = 16;
input int    InpAtrPeriod          = 14;
input double InpSpikeMultiplier    = 1.8;
input int    InpSlippagePoints     = 30;

//--- timeframes
const ENUM_TIMEFRAMES TF_M1 = PERIOD_M1;
const ENUM_TIMEFRAMES TF_M5 = PERIOD_M5;
const ENUM_TIMEFRAMES TF_H1 = PERIOD_H1;

CTrade trade;

int g_hAtrM1 = INVALID_HANDLE;
int g_hEmaM1 = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_hAtrM1 = iATR(_Symbol, TF_M1, InpAtrPeriod);
   g_hEmaM1 = iMA(_Symbol, TF_M1, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hAtrM1 == INVALID_HANDLE || g_hEmaM1 == INVALID_HANDLE)
   {
      Print("SpikeScalperProMax: échec création indicateurs");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_hAtrM1 != INVALID_HANDLE) { IndicatorRelease(g_hAtrM1); g_hAtrM1 = INVALID_HANDLE; }
   if(g_hEmaM1 != INVALID_HANDLE) { IndicatorRelease(g_hEmaM1); g_hEmaM1 = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
double Buf1(const int handle, const int shift)
{
   double b[];
   ArraySetAsSeries(b, true);
   if(CopyBuffer(handle, 0, shift, 1, b) != 1)
      return 0.0;
   return b[0];
}

//+------------------------------------------------------------------+
bool IsBearishBar(const ENUM_TIMEFRAMES tf, const int shift)
{
   double c = iClose(_Symbol, tf, shift);
   double o = iOpen(_Symbol, tf, shift);
   return (c < o);
}

//+------------------------------------------------------------------+
double GetAtrM1(const int shift)
{
   return Buf1(g_hAtrM1, shift);
}

//+------------------------------------------------------------------+
double GetEmaM1(const int shift)
{
   return Buf1(g_hEmaM1, shift);
}

//+------------------------------------------------------------------+
bool IsRealSpike()
{
   double o0 = iOpen(_Symbol, TF_M1, 0);
   double c0 = iClose(_Symbol, TF_M1, 0);
   double body = MathAbs(c0 - o0);
   double atr = GetAtrM1(0);
   if(atr <= 0.0)
      return false;
   return (body > atr * InpSpikeMultiplier);
}

//+------------------------------------------------------------------+
bool BreakStructure()
{
   double low0 = iLow(_Symbol, TF_M1, 0);
   double low1 = iLow(_Symbol, TF_M1, 1);
   double low2 = iLow(_Symbol, TF_M1, 2);
   return (low0 < low1 && low1 < low2);
}

//+------------------------------------------------------------------+
bool ConfirmMomentum()
{
   double close0 = iClose(_Symbol, TF_M1, 0);
   double ema = GetEmaM1(0);
   if(ema <= 0.0)
      return false;
   return (close0 < ema);
}

//+------------------------------------------------------------------+
bool AttackMode()
{
   return (IsRealSpike() && BreakStructure() && ConfirmMomentum());
}

//+------------------------------------------------------------------+
bool ReEntrySell()
{
   double close0 = iClose(_Symbol, TF_M1, 0);
   double close1 = iClose(_Symbol, TF_M1, 1);
   return (close0 < close1 && ConfirmMomentum());
}

//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
double TotalMyProfit()
{
   double total = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

//+------------------------------------------------------------------+
void OpenSell()
{
   if(CountMyPositions() >= InpMaxPositions)
      return;
   if(!trade.Sell(InpLotSize, _Symbol, 0.0, 0.0, 0.0, "SPIKE_SCALPER_MAX"))
      Print("OpenSell failed: ", trade.ResultRetcode(), " ", trade.ResultComment());
}

//+------------------------------------------------------------------+
void CloseAllMy()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
void BasketTrailing()
{
   static double maxProfit = 0.0;

   double currentProfit = TotalMyProfit();

   if(currentProfit > maxProfit)
      maxProfit = currentProfit;

   if(maxProfit > InpTrailingStart)
   {
      if(currentProfit < (maxProfit - InpTrailingStep))
      {
         CloseAllMy();
         maxProfit = 0.0;
      }
   }

   if(CountMyPositions() == 0 && MathAbs(currentProfit) < 1e-8)
      maxProfit = 0.0;
}

//+------------------------------------------------------------------+
// Remplace par ton appel IA (fichier, GlobalVariable, WebRequest…).
bool GetAIContext(double &confidencePct, string &trendOut)
{
   confidencePct = 98.0;   // TODO: lire décision réelle
   trendOut = "DOWN";
   return true;
}

//+------------------------------------------------------------------+
void OnTick()
{
   double confidence = 0.0;
   string trend = "";
   if(!GetAIContext(confidence, trend))
      return;

   StringToUpper(trend);
   if(confidence < InpMinConfidencePct || trend != "DOWN")
      return;

   if(!IsBearishBar(TF_M5, 0) || !IsBearishBar(TF_H1, 0))
      return;

   if(AttackMode())
      OpenSell();

   if(ReEntrySell())
      OpenSell();

   if(TotalMyProfit() >= InpBasketProfitTarget)
      CloseAllMy();

   BasketTrailing();
}

//+------------------------------------------------------------------+
