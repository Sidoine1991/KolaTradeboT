//+------------------------------------------------------------------+
//|                                                  PureMomentumEA.mq5 |
//|                                                      Manus AI |
//|                                                  https://manus.im |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://manus.im"
#property version   "1.00"
#property description "Expert Advisor for trading pure momentum spikes on synthetic indices (Boom/Crash, Painx/Gainx)"
#property script_show_inputs

// EA Settings
input double      LotSize = 0.01;           // Lot size for trading
input int         StopLossPips = 100;       // Stop Loss in pips
input int         TakeProfitPips = 200;     // Take Profit in pips
input int         MagicNumber = 12345;      // Magic number for trades
input int         MaxTrades = 1;            // Maximum number of open trades

// Indicator Settings
input int         EMAPeriodFast = 9;        // EMA Fast Period (M1)
input int         EMAPeriodSlow = 21;       // EMA Slow Period (M1)
input int         RSIPeriod = 14;           // RSI Period (M1)
input ENUM_APPLIED_PRICE RSIAppliedPrice = PRICE_CLOSE; // RSI Applied Price
input int         StochKPeriod = 5;         // Stochastic %K Period (M1)
input int         StochDPeriod = 3;         // Stochastic %D Period (M1)
input int         StochSlowing = 3;         // Stochastic Slowing (M1)
input ENUM_MA_METHOD StochMethod = MODE_SMA; // Stochastic MA Method
input ENUM_APPLIED_PRICE StochAppliedPrice = PRICE_CLOSE; // Stochastic Applied Price

// Momentum Thresholds
input int         RSIOverbought = 70;       // RSI Overbought Level for Boom/Gainx
input int         RSISold = 30;             // RSI Oversold Level for Crash/Painx
input int         StochOverbought = 80;     // Stochastic Overbought Level
input int         StochOversold = 20;       // Stochastic Oversold Level
input int         MaxRetracementCandles = 5; // Max M1 candles for retracement

// Multi-Timeframe Confluence
input ENUM_TIMEFRAMES HigherTimeframe = PERIOD_M5; // Higher Timeframe for confluence

// Global variables
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
  }

void OnTick()
  {
   if(!IsNewBar(PERIOD_M1)) return; // Process only on new M1 bar

   // Check for existing trades
   if(PositionsTotal() >= MaxTrades) return;

   // Get current prices
   MqlTick lastTick;
   SymbolInfoTick(_Symbol, lastTick);
   double currentPrice = lastTick.bid;

   // Get indicator values on M1
   double emaFast = iMA(_Symbol, PERIOD_M1, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(_Symbol, PERIOD_M1, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 0);
   double rsi = iRSI(_Symbol, PERIOD_M1, RSIPeriod, RSIAppliedPrice, 0);
   double stochMain = iStochastic(_Symbol, PERIOD_M1, StochKPeriod, StochDPeriod, StochSlowing, StochMethod, StochAppliedPrice, MODE_MAIN, 0);
   double stochSignal = iStochastic(_Symbol, PERIOD_M1, StochKPeriod, StochDPeriod, StochSlowing, StochMethod, StochAppliedPrice, MODE_SIGNAL, 0);

   // Get higher timeframe candle info
   MqlRates rates_htf[];
   if(CopyRates(_Symbol, HigherTimeframe, 0, 2, rates_htf) < 2) return;
   double htf_prev_open = rates_htf[1].open;
   double htf_prev_close = rates_htf[1].close;

   // Check for Boom/Gainx (Buy) conditions
   if(CheckBuySignal(currentPrice, emaFast, emaSlow, rsi, stochMain, stochSignal, htf_prev_open, htf_prev_close))
     {
      SendOrder(ORDER_TYPE_BUY);
     }

   // Check for Crash/Painx (Sell) conditions
   if(CheckSellSignal(currentPrice, emaFast, emaSlow, rsi, stochMain, stochSignal, htf_prev_open, htf_prev_close))
     {
      SendOrder(ORDER_TYPE_SELL);
     }
  }

//+------------------------------------------------------------------+
//| Custom Functions                                                 |
//+------------------------------------------------------------------+

bool IsNewBar(ENUM_TIMEFRAMES timeframe)
  {
   static datetime lastBarTime[ENUM_TIMEFRAMES_COUNT];
   datetime currentTime = iTime(_Symbol, timeframe, 0);
   if(lastBarTime[timeframe] != currentTime)
     {
      lastBarTime[timeframe] = currentTime;
      return true;
     }
   return false;
  }

bool CheckBuySignal(double currentPrice, double emaFast, double emaSlow, double rsi, double stochMain, double stochSignal, double htf_prev_open, double htf_prev_close)
  {
   // EMA Crossover / Price above EMAs
   if(emaFast <= emaSlow || currentPrice <= emaFast) return false; // Price must be above fast EMA, fast EMA above slow EMA

   // RSI Overbought (dynamic)
   if(rsi < RSIOverbought) return false; // RSI must be in overbought zone

   // Stochastic Overbought (dynamic)
   if(stochMain < StochOverbought || stochSignal < StochOverbought) return false; // Stoch must be in overbought zone
   if(stochMain < stochSignal) return false; // Stoch main line must be above signal line

   // Higher Timeframe Confluence (Impulsive candle)
   if(htf_prev_close <= htf_prev_open) return false; // Previous HTF candle must be bullish
   if(MathAbs(htf_prev_close - htf_prev_open) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50) return false; // HTF candle must be significant (e.g., > 50 points)

   // Minimal Retracement (Check previous M1 candles - simplified, needs more robust implementation)
   // This is a simplified check. A more robust implementation would involve analyzing recent candle patterns.
   MqlRates rates_m1[];
   if(CopyRates(_Symbol, PERIOD_M1, 1, MaxRetracementCandles + 1, rates_m1) < MaxRetracementCandles + 1) return false;
   
   int bearishCount = 0;
   for(int i = 0; i < MaxRetracementCandles; i++)
     {
      if(rates_m1[i].close < rates_m1[i].open) bearishCount++;
     }
   if(bearishCount > MaxRetracementCandles / 2) return false; // More than half retracement candles are bearish

   // FVG logic (simplified - needs actual FVG detection)
   // For a real FVG, you'd need to identify a 3-candle pattern where the middle candle's high/low doesn't overlap with the first/third.
   // This is a placeholder for future FVG detection.
   
   return true;
  }

bool CheckSellSignal(double currentPrice, double emaFast, double emaSlow, double rsi, double stochMain, double stochSignal, double htf_prev_open, double htf_prev_close)
  {
   // EMA Crossover / Price below EMAs
   if(emaFast >= emaSlow || currentPrice >= emaFast) return false; // Price must be below fast EMA, fast EMA below slow EMA

   // RSI Oversold (dynamic)
   if(rsi > RSISold) return false; // RSI must be in oversold zone

   // Stochastic Oversold (dynamic)
   if(stochMain > StochOversold || stochSignal > StochOversold) return false; // Stoch must be in oversold zone
   if(stochMain > stochSignal) return false; // Stoch main line must be below signal line

   // Higher Timeframe Confluence (Impulsive candle)
   if(htf_prev_close >= htf_prev_open) return false; // Previous HTF candle must be bearish
   if(MathAbs(htf_prev_close - htf_prev_open) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50) return false; // HTF candle must be significant (e.g., > 50 points)

   // Minimal Retracement (Check previous M1 candles - simplified, needs more robust implementation)
   MqlRates rates_m1[];
   if(CopyRates(_Symbol, PERIOD_M1, 1, MaxRetracementCandles + 1, rates_m1) < MaxRetracementCandles + 1) return false;
   
   int bullishCount = 0;
   for(int i = 0; i < MaxRetracementCandles; i++)
     {
      if(rates_m1[i].close > rates_m1[i].open) bullishCount++;
     }
   if(bullishCount > MaxRetracementCandles / 2) return false; // More than half retracement candles are bullish

   // FVG logic (simplified - needs actual FVG detection)
   // This is a placeholder for future FVG detection.

   return true;
  }

void SendOrder(ENUM_ORDER_TYPE orderType)
  {
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = 10; // Max price deviation in points
   request.magic = MagicNumber;
   request.comment = "PureMomentumEA";

   // Calculate Stop Loss and Take Profit
   double sl = 0;
   double tp = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(orderType == ORDER_TYPE_BUY)
     {
      sl = request.price - StopLossPips * point;
      tp = request.price + TakeProfitPips * point;
     }
   else // ORDER_TYPE_SELL
     {
      sl = request.price + StopLossPips * point;
      tp = request.price - TakeProfitPips * point;
     }
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);

   SafeOrderSend(request, result);

   if(result.retcode == TRADE_RETCODE_DONE)
     {
      PrintFormat("Order %s opened successfully: #%I64d", EnumToString(orderType), result.order);
     }
   else
     {
      PrintFormat("Order %s failed: %d", EnumToString(orderType), result.retcode);
     }
  }

// Function to get the number of open trades for this EA
int PositionsTotal()
  {
   int total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong position_ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         total++;
        }
     }
   return total;
  }



