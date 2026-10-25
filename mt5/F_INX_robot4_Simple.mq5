//+------------------------------------------------------------------+
//|                                                   F_INX_robot4   |
//|              Synthetic Indices Scalping Expert Advisor           |
//|              Author : Senior MQL5 Developer (20 years exp)       |
//+------------------------------------------------------------------+
#property copyright "F_INX_robot4"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//========================= INPUTS ===================================
input group "--- RISK MANAGEMENT ---"
input double RiskPercent      = 2.0;     // Risk per trade (%)
input bool   UseMartingale    = false;
input double MartingaleMult   = 1.8;
input double MaxLotSize       = 1.0;     // Maximum lot size

input group "--- INDICATORS ---"
input int    RSI_Period       = 14;
input int    EMA_Fast         = 50;
input int    EMA_Slow         = 200;
input int    ATR_Period       = 14;

input group "--- PROFIT TARGETS ---"
input double TP_ATR_Mult      = 1.5;
input double SL_ATR_Mult      = 1.0;
input double FixedTP_Dollar   = 1.0;     // Fixed TP in dollars for Boom/Crash

input group "--- TRADE MANAGEMENT ---"
input bool   UseBreakEven     = true;
input double BE_ATR_Mult      = 0.8;
input bool   UseTrailing      = true;
input double Trail_ATR_Mult   = 0.6;

input group "--- TIMEFRAMES ---"
input ENUM_TIMEFRAMES TF_Trend = PERIOD_H1;
input ENUM_TIMEFRAMES TF_Entry = PERIOD_M5;

input group "--- ALERTS ---"
input bool   EnableAlerts    = true;
input bool   EnableSoundAlerts = true;
input bool   EnablePushNotifications = true;

input group "--- BOOM/CRASH SETTINGS ---"
input bool   UseBoomCrashMode = true;     // Special mode for Boom/Crash
input int    MaxPositionsBoomCrash = 3;   // Max positions for Boom/Crash
input int    SignalCooldownSeconds = 60; // Cooldown between signals

//========================= GLOBALS ==================================
int rsiHandle, atrHandle, emaFastHandle, emaSlowHandle;
double lotSize = 0.01;
datetime lastSignalTime = 0;
string lastSignalType = "";

//+------------------------------------------------------------------+
int OnInit()
{
   rsiHandle     = iRSI(_Symbol, TF_Entry, RSI_Period, PRICE_CLOSE);
   atrHandle     = iATR(_Symbol, TF_Entry, ATR_Period);
   emaFastHandle = iMA(_Symbol, TF_Trend, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, TF_Trend, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   if(rsiHandle < 0 || atrHandle < 0 || emaFastHandle < 0 || emaSlowHandle < 0)
   {
      Print("Error creating indicator handles");
      return INIT_FAILED;
   }

   Comment("F_INX_robot4 Simple running on ", _Symbol);
   Print("Robot initialized on ", _Symbol, " | TF_Entry: ", EnumToString(TF_Entry), " | TF_Trend: ", EnumToString(TF_Trend));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we already have positions
   int currentPositions = CountPositions();
   
   // Special rules for Boom/Crash
   if(UseBoomCrashMode)
   {
      if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
      {
         if(currentPositions >= MaxPositionsBoomCrash)
         {
            Comment("Max positions reached for Boom/Crash: ", currentPositions, "/", MaxPositionsBoomCrash);
            return;
         }
      }
      else
      {
         if(currentPositions >= 1) // Only 1 position for other symbols
         {
            return;
         }
      }
   }
   else
   {
      if(currentPositions >= 1) // Default: only 1 position
      {
         return;
      }
   }

   // Check cooldown
   if(TimeCurrent() - lastSignalTime < SignalCooldownSeconds)
   {
      return;
   }

   CheckEntry();
   
   // Manage existing positions
   if(currentPositions > 0)
   {
      ManageTrade();
   }
}

//+------------------------------------------------------------------+
void CheckEntry()
{
   double rsi[], atr[], emaFast[], emaSlow[];
   
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsi) <= 0) return;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return;
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) <= 0) return;
   if(CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp;
   string signalType = "";

   // SIMPLIFIED BUY CONDITIONS
   bool buyCondition1 = (emaFast[0] > emaSlow[0]) && (rsi[0] < 35);  // Trend up + oversold
   bool buyCondition2 = (rsi[0] < 25) && (rsi[1] >= 25);              // RSI oversold crossover
   bool buyCondition3 = (emaFast[0] > emaSlow[0]) && (emaFast[1] <= emaSlow[1]); // EMA bullish crossover

   // SIMPLIFIED SELL CONDITIONS  
   bool sellCondition1 = (emaFast[0] < emaSlow[0]) && (rsi[0] > 65); // Trend down + overbought
   bool sellCondition2 = (rsi[0] > 75) && (rsi[1] <= 75);             // RSI overbought crossover
   bool sellCondition3 = (emaFast[0] < emaSlow[0]) && (emaFast[1] >= emaSlow[1]); // EMA bearish crossover

   // Check BUY signals
   if(buyCondition1 || buyCondition2 || buyCondition3)
   {
      // Additional check for Boom/Crash direction
      if(UseBoomCrashMode)
      {
         if(StringFind(_Symbol, "Crash") != -1) // Don't BUY on Crash
         {
            if(EnableAlerts) Print("BLOCK: BUY signal ignored on Crash (SELL-only symbol)");
            return;
         }
      }
      
      lotSize = CalculateLot(atr[0]);
      
      if(UseBoomCrashMode && (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1))
      {
         // Fixed TP in dollars for Boom/Crash
         sl = ask - atr[0] * SL_ATR_Mult;
         tp = 0; // Will be calculated by fixed TP function
         
         if(ExecuteFixedTPTrade(ORDER_TYPE_BUY, lotSize, ask, sl, FixedTP_Dollar, "BUY_SIMPLE"))
         {
            signalType = "BUY_SIMPLE";
            DrawSignal("BUY", ask);
            AlertUser("BUY SIGNAL - Simple Strategy");
         }
      }
      else
      {
         // Regular ATR-based TP/SL for other symbols
         sl = ask - atr[0] * SL_ATR_Mult;
         tp = ask + atr[0] * TP_ATR_Mult;
         
         if(trade.Buy(lotSize, _Symbol, ask, sl, tp))
         {
            signalType = "BUY_ATR";
            DrawSignal("BUY", ask);
            AlertUser("BUY SIGNAL - ATR Strategy");
         }
      }
   }

   // Check SELL signals
   if(sellCondition1 || sellCondition2 || sellCondition3)
   {
      // Additional check for Boom/Crash direction
      if(UseBoomCrashMode)
      {
         if(StringFind(_Symbol, "Boom") != -1) // Don't SELL on Boom
         {
            if(EnableAlerts) Print("BLOCK: SELL signal ignored on Boom (BUY-only symbol)");
            return;
         }
      }
      
      lotSize = CalculateLot(atr[0]);
      
      if(UseBoomCrashMode && (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1))
      {
         // Fixed TP in dollars for Boom/Crash
         sl = bid + atr[0] * SL_ATR_Mult;
         tp = 0; // Will be calculated by fixed TP function
         
         if(ExecuteFixedTPTrade(ORDER_TYPE_SELL, lotSize, bid, sl, FixedTP_Dollar, "SELL_SIMPLE"))
         {
            signalType = "SELL_SIMPLE";
            DrawSignal("SELL", bid);
            AlertUser("SELL SIGNAL - Simple Strategy");
         }
      }
      else
      {
         // Regular ATR-based TP/SL for other symbols
         sl = bid + atr[0] * SL_ATR_Mult;
         tp = bid - atr[0] * TP_ATR_Mult;
         
         if(trade.Sell(lotSize, _Symbol, bid, sl, tp))
         {
            signalType = "SELL_ATR";
            DrawSignal("SELL", bid);
            AlertUser("SELL SIGNAL - ATR Strategy");
         }
      }
   }
   
   // Update last signal
   if(signalType != "")
   {
      lastSignalTime = TimeCurrent();
      lastSignalType = signalType;
      Print("Signal executed: ", signalType, " on ", _Symbol, " at ", TimeToString(TimeCurrent()));
   }
}

//+------------------------------------------------------------------+
void ManageTrade()
{
   if(!PositionSelect(_Symbol)) return;
   
   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   ulong ticket = PositionGetInteger(POSITION_TICKET);

   // BREAK EVEN
   if(UseBreakEven && currentSL > 0)
   {
      double beDistance = atr[0] * BE_ATR_Mult;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         if(price > openPrice + beDistance && currentSL < openPrice)
         {
            if(trade.PositionModify(ticket, openPrice, currentTP))
            {
               Print("Break Even activated for BUY #", ticket);
            }
         }
      }
      else // SELL
      {
         if(price < openPrice - beDistance && currentSL > openPrice)
         {
            if(trade.PositionModify(ticket, openPrice, currentTP))
            {
               Print("Break Even activated for SELL #", ticket);
            }
         }
      }
   }

   // TRAILING STOP
   if(UseTrailing && currentSL > 0)
   {
      double trailDistance = atr[0] * Trail_ATR_Mult;
      double newSL;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         newSL = price - trailDistance;
         if(newSL > currentSL)
         {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
               Print("Trailing Stop updated for BUY #", ticket, " | New SL: ", newSL);
            }
         }
      }
      else // SELL
      {
         newSL = price + trailDistance;
         if(newSL < currentSL)
         {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
               Print("Trailing Stop updated for SELL #", ticket, " | New SL: ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
double CalculateLot(double atr)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;
   double lot = riskMoney / (atr * 100);

   // Apply minimum and maximum limits
   if(lot < 0.01) lot = 0.01;
   if(lot > MaxLotSize) lot = MaxLotSize;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
bool ExecuteFixedTPTrade(ENUM_ORDER_TYPE type, double lot, double price, double sl, double targetUSD, string comment)
{
   // Calculate TP based on fixed dollar target
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue <= 0 || tickSize <= 0)
   {
      Print("Error: Invalid tick value or size");
      return false;
   }
   
   // Calculate TP distance in points for target profit in USD
   double tpDistancePoints = (targetUSD / (lot * tickValue)) * tickSize;
   double tp;
   
   if(type == ORDER_TYPE_BUY)
   {
      tp = price + tpDistancePoints;
      return trade.Buy(lot, _Symbol, price, sl, tp, comment);
   }
   else
   {
      tp = price - tpDistancePoints;
      return trade.Sell(lot, _Symbol, price, sl, tp, comment);
   }
}

//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
void DrawSignal(string type, double price)
{
   string name = type + "_" + TimeToString(TimeCurrent(), TIME_SECONDS);
   ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, type=="BUY" ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, type=="BUY" ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

//+------------------------------------------------------------------+
void AlertUser(string msg)
{
   if(!EnableAlerts) return;
   
   string fullMessage = msg + " on " + _Symbol + " at " + TimeToString(TimeCurrent(), TIME_MINUTES);
   
   // Sound alert
   if(EnableSoundAlerts)
   {
      PlaySound("alert.wav");
   }
   
   // Platform alert
   Alert(fullMessage);
   
   // Push notification
   if(EnablePushNotifications)
   {
      SendNotification(fullMessage);
   }
   
   // Print to log
   Print("ALERT: ", fullMessage);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("F_INX_robot4 Simple stopped on ", _Symbol);
}
//+------------------------------------------------------------------+
