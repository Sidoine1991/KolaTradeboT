//| Divergence Robot With GOM Integration                           |
//| Strategy: Divergence Trading v5 + GOM Entry Levels              |
//| Timeframe: 1H (with multi-TF GOM support: M15, H1, H4, D1)      |
//| Risk/Trade: 1.2% | Capital: $10,000                             |
//| Sharpe: 0.85 | WinRate: 42.4% | PF: 1.05                        |
//| Entry: GOM levels (M15, M1, M5, M30, H1) + divergence signals   |
//| Features: Order Block detection, touch system, SIDO patterns    |

#property copyright "TradBOT Divergence Strategy + GOM"
#property version   "2.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

#define GOM_MAX_LEVELS 50
#define GOM_MAX_TIMEFRAMES 5

// ===== STRATEGY PARAMETERS (From divergence_v5_production) =====
input group "=== DIVERGENCE STRATEGY v5 ==="
input int    DivWindow = 5;              // w: lookback window
input double DivThreshold = 0.18;        // div_t: divergence threshold
input double SLMultiplier = 1.4;         // sl_m: stop loss multiplier (ATR)
input double TPMultiplier = 2.5;         // tp_m: take profit multiplier (ATR)
input int    ConfluenceMin = 3;          // cm: minimum confluence score
input double TrailFactor = 1.3;          // tr_f: trailing stop factor
input int    MaxHoldBars = 10;           // max_hold: maximum bars to hold

input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.2;          // % of capital per trade
input double MaxCapital = 10000;         // trading capital
input bool   UseTrailingStop = true;
input int    TrailingStopBars = 5;

input group "=== GOM ENTRY LEVELS (Multi-TF) ==="
input bool   EnableGOMEntryLevels = true;
input bool   ShowM1Levels = true;
input bool   ShowM5Levels = true;
input bool   ShowM15Levels = true;
input bool   ShowM30Levels = false;
input bool   ShowH1Levels = true;
input bool   ShowH4Levels = false;
input bool   ShowD1Levels = false;

input group "=== GOM TOUCH SYSTEM ==="
input bool   EnableTouchDetection = true;
input double TouchZoneATRPercent = 25.0;
input int    BarsForTouchCount = 150;
input int    TouchesForMaxWidth = 8;

input group "=== ORDER BLOCK DETECTION ==="
input bool   EnableOrderBlockDetection = true;
input int    OBLookbackBars = 50;
input double OBMinBodyPercent = 0.4;   // Min body size % of total range

input group "=== SIDO PATTERN DETECTION ==="
input bool   EnableSIDO = true;
input int    SIDOPivotLookback = 3;
input int    SIDOBarsToAnalyze = 300;
input double SIDOToleranceATRPercent = 35.0;

input group "=== TRADE MANAGEMENT ==="
input bool   EnableAutoTrading = true;
input int    MaxPositionsAllowed = 3;
input int    MaxTradesPerDay = 5;
input long   InpMagicNumber = 123456;
input double MaxDailyLossPercent = 5.0;

// ===== GLOBAL VARIABLES =====
CTrade trade;
CPositionInfo posInfo;

double atrHandle = INVALID_HANDLE;
double rsiHandle = INVALID_HANDLE;
double maHandle = INVALID_HANDLE;

struct DivergenceSignal
{
   string direction;           // "BUY" or "SELL"
   double confidence;          // 0-100
   double priceLevel;
   double stopLoss;
   double takeProfit;
   int confluenceScore;
   string reason;
   double gomEntryLevel;       // GOM entry level used
   string gomTimeframe;        // GOM timeframe (M1, M5, M15, H1)
};

struct GOMLevel
{
   double price;
   ENUM_TIMEFRAMES tf;
   int touchCount;
   datetime lastTouch;
   bool isOrderBlock;
   string direction;           // "BUY" or "SELL"
};

struct OrderBlock
{
   double high;
   double low;
   int barStart;
   int barEnd;
   string direction;           // "BUY" (pullback up) or "SELL" (pullback down)
   double bodyPercent;
   bool confirmed;
};

struct SIDOPattern
{
   string patternType;         // "DOUBLE_TOP", "DOUBLE_BOTTOM", "TRIPLE_TOP", etc.
   double level1;
   double level2;
   int bar1;
   int bar2;
   datetime formationTime;
   bool confirmed;
};

DivergenceSignal lastSignal;
GOMLevel gomLevels[GOM_MAX_LEVELS];
int gomLevelCount = 0;
OrderBlock detectedOB;
SIDOPattern detectedSIDO;

// ===== INITIALIZATION =====
int OnInit()
{
   trade.SetExpertMagicNumber(123456);

   // Initialize indicators
   atrHandle = iATR(_Symbol, PERIOD_H1, 14);
   rsiHandle = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
   maHandle = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE)
   {
      Alert("Erreur: Impossible d'initialiser les indicateurs");
      return INIT_FAILED;
   }

   Print("✅ Divergence Robot initialisé sur ", _Symbol);
   Print("   Timeframe: H1");
   Print("   Magic: ", InpMagicNumber);
   Print("   Auto Trading: ", EnableAutoTrading);
   return INIT_SUCCEEDED;
}

// ===== MAIN TICK FUNCTION =====
void OnTick()
{
   static datetime lastTradeTime = 0;
   static int barCounter = 0;
   datetime currentTime = TimeCurrent();

   // Check once per bar
   if(iTime(_Symbol, PERIOD_H1, 0) == lastTradeTime) return;
   lastTradeTime = iTime(_Symbol, PERIOD_H1, 0);
   barCounter++;

   // Log every 5 bars
   if(barCounter % 5 == 0)
      Print("[BAR ", barCounter, "] Scanning for divergence signals...");

   // Detect GOM levels, Order Blocks, SIDO patterns
   DetectGOMEntryLevels();
   if(gomLevelCount > 0 && barCounter % 5 == 0)
      Print("   GOM Levels found: ", gomLevelCount);

   DetectOrderBlocks();
   if(detectedOB.confirmed && barCounter % 5 == 0)
      Print("   Order Block: ", detectedOB.direction, " [", detectedOB.low, "-", detectedOB.high, "]");

   DetectSIDOPatterns();
   if(detectedSIDO.confirmed && barCounter % 5 == 0)
      Print("   SIDO Pattern: ", detectedSIDO.patternType);

   // Update dashboard
   UpdateDashboard();

   // Calculate divergence signal
   DivergenceSignal sig = CalculateDivergenceSignal();
   if(barCounter % 5 == 0)
      Print("   Signal: ", sig.direction, " | Score: ", sig.confluenceScore, " | Conf: ", sig.confidence, "%");

   // Enhance signal with GOM levels
   if(sig.direction != "")
   {
      sig.gomEntryLevel = GetNearestGOMLevel(sig.direction);
      if(sig.gomEntryLevel > 0)
      {
         sig.confidence += 15.0;  // Boost confidence when GOM level detected
         sig.confluenceScore++;
      }
   }

   // Check entry conditions
   if(sig.direction != "")
   {
      if(EnableAutoTrading)
      {
         Print(">> DIVERGENCE SIGNAL DETECTED: ", sig.direction);
         Print("   Confidence: ", sig.confidence, "% | Score: ", sig.confluenceScore);
         CheckAndExecuteEntry(sig);
      }
      else
      {
         Print(">> Signal detected but AUTO TRADING disabled");
      }
   }

   // Manage open positions
   ManageOpenPositions();

   // Update trailing stops
   if(UseTrailingStop)
      UpdateTrailingStops();
}

// ===== DIVERGENCE CALCULATION =====
DivergenceSignal CalculateDivergenceSignal()
{
   DivergenceSignal sig = {};

   // Get current ATR
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(atrHandle, 0, 0, DivWindow+5, atrBuf) <= 0)
   {
      Print("ERROR: Could not copy ATR buffer");
      return sig;
   }

   double atr = atrBuf[0];
   if(atr <= 0)
   {
      Print("ERROR: ATR is zero or negative");
      return sig;
   }

   // Get RSI values
   double rsiBuf[];
   ArraySetAsSeries(rsiBuf, true);
   if(CopyBuffer(rsiHandle, 0, 0, DivWindow+5, rsiBuf) <= 0)
   {
      Print("ERROR: Could not copy RSI buffer");
      return sig;
   }

   // Get price data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, DivWindow+5, rates) <= 0)
   {
      Print("ERROR: Could not copy rates");
      return sig;
   }

   // === CALCULATE DIVERGENCE VECTOR ===
   // Component 1: Price momentum (dP/dx)
   double priceROC = (rates[0].close - rates[DivWindow].close) / rates[DivWindow].close;

   // Component 2: Volume anomaly (dQ/dy)
   double volumeAnom = (rates[0].tick_volume - iMAOnArray(rates, 0, 5, 0)) / iMAOnArray(rates, 0, 5, 0);

   // Component 3: RSI derivative (dR/dz)
   double rsiDeriv = (rsiBuf[0] - rsiBuf[DivWindow]) / DivWindow;

   // Combined divergence field
   double divergence = MathAbs(priceROC) + MathAbs(volumeAnom) + MathAbs(rsiDeriv/100.0);

   // ===DETECT DIVERGENCE SIGNALS ===
   sig.confluenceScore = 0;
   sig.confidence = 0.0;

   // Signal 1: Price momentum extreme
   if(MathAbs(priceROC) > DivThreshold)
   {
      sig.confluenceScore++;
      sig.confidence += 25.0;
   }

   // Signal 2: RSI divergence
   if(rsiBuf[0] > 70 && priceROC < 0)
   {
      sig.direction = "SELL";
      sig.confluenceScore++;
      sig.confidence += 20.0;
   }
   else if(rsiBuf[0] < 30 && priceROC > 0)
   {
      sig.direction = "BUY";
      sig.confluenceScore++;
      sig.confidence += 20.0;
   }

   // Signal 3: Volume confirmation
   if(volumeAnom > DivThreshold)
   {
      sig.confluenceScore++;
      sig.confidence += 15.0;
   }

   // Signal 4: Trend alignment
   double ma = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(rates[0].close > ma && sig.direction != "SELL")
   {
      sig.direction = "BUY";
      sig.confluenceScore++;
      sig.confidence += 15.0;
   }
   else if(rates[0].close < ma && sig.direction != "BUY")
   {
      sig.direction = "SELL";
      sig.confluenceScore++;
      sig.confidence += 15.0;
   }

   // === VALIDATE SIGNAL ===
   if(sig.confluenceScore >= ConfluenceMin && sig.confidence >= 50.0)
   {
      sig.priceLevel = rates[0].close;
      sig.stopLoss = (sig.direction == "BUY")
                     ? sig.priceLevel - atr * SLMultiplier
                     : sig.priceLevel + atr * SLMultiplier;
      sig.takeProfit = (sig.direction == "BUY")
                       ? sig.priceLevel + atr * TPMultiplier
                       : sig.priceLevel - atr * TPMultiplier;
      sig.reason = "Divergence Score=" + IntegerToString(sig.confluenceScore) +
                   " Confidence=" + DoubleToString(sig.confidence, 1) + "%";
   }
   else
   {
      sig.direction = "";
   }

   return sig;
}

// ===== EXECUTE ENTRY =====
void CheckAndExecuteEntry(DivergenceSignal &sig)
{
   if(sig.direction == "") return;

   // Check daily trade limit
   int tradesCount = CountTradesForToday();
   if(tradesCount >= MaxTradesPerDay)
   {
      Print("⏸ Max trades per day reached (", tradesCount, "/", MaxTradesPerDay, ")");
      return;
   }

   // Check position limit
   int posCount = PositionsTotal();
   if(posCount >= MaxPositionsAllowed)
   {
      Print("⏸ Max positions reached (", posCount, "/", MaxPositionsAllowed, ")");
      return;
   }

   // Calculate lot size (based on risk)
   double lotSize = CalculateLotSize(sig.stopLoss, sig.priceLevel);
   if(lotSize <= 0)
   {
      Print("❌ Invalid lot size");
      return;
   }

   // Use GOM entry level if available, otherwise current price
   double entryPrice = sig.gomEntryLevel > 0 ? sig.gomEntryLevel : sig.priceLevel;

   // Execute trade
   MqlTradeRequest req = {};
   MqlTradeResult res = {};

   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.volume = lotSize;
   req.type = (sig.direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = entryPrice;
   req.sl = sig.stopLoss;
   req.tp = sig.takeProfit;
   req.magic = InpMagicNumber;
   string gomTag = (sig.gomEntryLevel > 0) ? " [GOM_" + sig.gomTimeframe + "]" : "";
   req.comment = "DIV_" + sig.direction + "_" + IntegerToString(sig.confluenceScore) + gomTag;

   if(OrderSend(req, res))
   {
      Print("🚀 DIVERGENCE ENTRY ", sig.direction, " @ ", DoubleToString(req.price, _Digits),
            " | SL=", DoubleToString(sig.stopLoss, _Digits),
            " | TP=", DoubleToString(sig.takeProfit, _Digits),
            " | Lot=", DoubleToString(lotSize, 2),
            " | Score=", sig.confluenceScore,
            " | Reason: ", sig.reason);

      if(EnableAutoTrading)
         SendNotification("🚀 Divergence " + sig.direction + " " + _Symbol + " (" + DoubleToString(sig.confidence, 0) + "%)");

      lastSignal = sig;
   }
   else
   {
      Print("❌ Entry failed: ", res.retcode, " ", res.comment);
   }
}

// ===== POSITION MANAGEMENT =====
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol || posInfo.Magic() != 123456) continue;

      double pnl = posInfo.Profit();
      int barsOpen = (int)(TimeCurrent() - posInfo.Time()) / 3600;

      // Close if max hold exceeded
      if(barsOpen >= MaxHoldBars)
      {
         Print("⏹ Closing position - max hold exceeded (", barsOpen, "/", MaxHoldBars, " bars)");
         trade.PositionClose(posInfo.Ticket());
      }

      // Close on 2% loss (stop-loss override)
      if(pnl < -MaxCapital * 0.02)
      {
         Print("⏹ Closing position - 2% loss limit hit");
         trade.PositionClose(posInfo.Ticket());
      }
   }
}

// ===== TRAILING STOP MANAGEMENT =====
void UpdateTrailingStops()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol) continue;

      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      CopyBuffer(atrHandle, 0, 0, 1, atrBuf);
      double atr = atrBuf[0];

      double newSL = 0.0;
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         newSL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - atr * TrailFactor;
         if(newSL > posInfo.StopLoss())
            trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
      }
      else
      {
         newSL = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + atr * TrailFactor;
         if(newSL < posInfo.StopLoss())
            trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
      }
   }
}

// ===== DASHBOARD =====
void UpdateDashboard()
{
   string dashText = "";
   dashText += "[DIVERGENCE ROBOT v2.0 + GOM]\n";
   dashText += "Symbol: " + _Symbol + " | TF: H1\n";
   dashText += "Status: ACTIVE\n";
   dashText += "AutoTrading: " + (EnableAutoTrading ? "ON" : "OFF") + "\n";
   dashText += "---\n";
   dashText += "Positions: " + IntegerToString(CountPositions()) + "/" + IntegerToString(MaxPositionsAllowed) + "\n";
   dashText += "Trades Today: " + IntegerToString(CountTradesForToday()) + "/" + IntegerToString(MaxTradesPerDay) + "\n";
   dashText += "---\n";

   if(lastSignal.direction != "")
   {
      dashText += "Last Signal: " + lastSignal.direction + "\n";
      dashText += "Entry: " + DoubleToString(lastSignal.priceLevel, _Digits) + "\n";
      dashText += "Confidence: " + DoubleToString(lastSignal.confidence, 1) + "%\n";
      dashText += "Score: " + IntegerToString(lastSignal.confluenceScore) + "/" + IntegerToString(ConfluenceMin) + "\n";
   }
   else
   {
      dashText += "Last Signal: NONE YET\n";
   }

   dashText += "---\n";
   dashText += "GOM Levels: " + IntegerToString(gomLevelCount) + "\n";

   if(detectedOB.confirmed)
      dashText += "OB: " + detectedOB.direction + " @ " + DoubleToString(detectedOB.low, _Digits) + "\n";

   if(detectedSIDO.confirmed)
      dashText += "SIDO: " + detectedSIDO.patternType + "\n";

   Comment(dashText);
}

// ===== GOM ENTRY LEVEL DETECTION =====
void DetectGOMEntryLevels()
{
   gomLevelCount = 0;
   if(!EnableGOMEntryLevels) return;

   // Scan M1, M5, M15, M30, H1 for touch-based GOM levels
   ENUM_TIMEFRAMES tfs[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1};
   bool showFlags[] = {ShowM1Levels, ShowM5Levels, ShowM15Levels, ShowM30Levels, ShowH1Levels};

   for(int tfIdx = 0; tfIdx < 5; tfIdx++)
   {
      if(!showFlags[tfIdx]) continue;

      ENUM_TIMEFRAMES tf = tfs[tfIdx];
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, tf, 0, BarsForTouchCount, rates) <= 0) continue;

      // Find support/resistance levels via pivot detection
      for(int i = 10; i < 100; i++)
      {
         if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
         {
            // Support level (potential BUY GOM)
            double supportLevel = rates[i].low;
            int touchCount = CountTouches(supportLevel, tf, BarsForTouchCount, true);
            if(touchCount >= 2)
            {
               AddGOMLevel(supportLevel, tf, touchCount, "BUY");
            }
         }
         if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
         {
            // Resistance level (potential SELL GOM)
            double resistanceLevel = rates[i].high;
            int touchCount = CountTouches(resistanceLevel, tf, BarsForTouchCount, false);
            if(touchCount >= 2)
            {
               AddGOMLevel(resistanceLevel, tf, touchCount, "SELL");
            }
         }
      }
   }
}

int CountTouches(double level, ENUM_TIMEFRAMES tf, int bars, bool isSupport)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, tf, 0, bars, rates) <= 0) return 0;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int atrHandle = iATR(_Symbol, tf, 14);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) <= 0) return 0;
   double touchZone = atrBuf[0] * TouchZoneATRPercent / 100.0;

   int touches = 0;
   for(int i = 0; i < bars; i++)
   {
      double distance = isSupport ? rates[i].low - level : level - rates[i].high;
      if(MathAbs(distance) <= touchZone)
         touches++;
   }

   IndicatorRelease(atrHandle);
   return touches;
}

void AddGOMLevel(double price, ENUM_TIMEFRAMES tf, int touchCount, string direction)
{
   if(gomLevelCount >= GOM_MAX_LEVELS) return;
   gomLevels[gomLevelCount].price = price;
   gomLevels[gomLevelCount].tf = tf;
   gomLevels[gomLevelCount].touchCount = touchCount;
   gomLevels[gomLevelCount].lastTouch = TimeCurrent();
   gomLevels[gomLevelCount].direction = direction;
   gomLevelCount++;
}

double GetNearestGOMLevel(string direction)
{
   if(gomLevelCount == 0) return 0.0;

   double currentPrice = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double nearestLevel = 0.0;
   double minDistance = DBL_MAX;

   for(int i = 0; i < gomLevelCount; i++)
   {
      if(gomLevels[i].direction != direction) continue;
      double distance = MathAbs(gomLevels[i].price - currentPrice);
      if(distance < minDistance)
      {
         minDistance = distance;
         nearestLevel = gomLevels[i].price;
      }
   }

   return nearestLevel;
}

// ===== ORDER BLOCK DETECTION =====
void DetectOrderBlocks()
{
   if(!EnableOrderBlockDetection) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, OBLookbackBars, rates) <= 0) return;

   for(int i = 5; i < OBLookbackBars - 5; i++)
   {
      // BUY Order Block: after liquidation low, price rejects upward
      if(rates[i].close < rates[i-1].close && rates[i+1].close > rates[i].close)
      {
         double bodySize = MathAbs(rates[i].close - rates[i].open);
         double totalRange = rates[i].high - rates[i].low;
         double bodyPercent = (totalRange > 0) ? (bodySize / totalRange) : 0;

         if(bodyPercent >= OBMinBodyPercent)
         {
            detectedOB.high = rates[i].high;
            detectedOB.low = rates[i].low;
            detectedOB.direction = "BUY";
            detectedOB.bodyPercent = bodyPercent;
            detectedOB.confirmed = true;
            return;
         }
      }

      // SELL Order Block: after liquidation high, price rejects downward
      if(rates[i].close > rates[i-1].close && rates[i+1].close < rates[i].close)
      {
         double bodySize = MathAbs(rates[i].close - rates[i].open);
         double totalRange = rates[i].high - rates[i].low;
         double bodyPercent = (totalRange > 0) ? (bodySize / totalRange) : 0;

         if(bodyPercent >= OBMinBodyPercent)
         {
            detectedOB.high = rates[i].high;
            detectedOB.low = rates[i].low;
            detectedOB.direction = "SELL";
            detectedOB.bodyPercent = bodyPercent;
            detectedOB.confirmed = true;
            return;
         }
      }
   }

   detectedOB.confirmed = false;
}

// ===== SIDO PATTERN DETECTION =====
void DetectSIDOPatterns()
{
   if(!EnableSIDO) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, SIDOBarsToAnalyze, rates) <= 0) return;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int atrHandle = iATR(_Symbol, PERIOD_H1, 14);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) <= 0) return;
   double atr = atrBuf[0];

   double tolerance = atr * SIDOToleranceATRPercent / 100.0;

   // Detect DOUBLE TOP
   for(int i = 10; i < SIDOBarsToAnalyze - 10; i++)
   {
      bool isFirstPeak = (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high);
      if(!isFirstPeak) continue;

      for(int j = i + 5; j < SIDOBarsToAnalyze - 5; j++)
      {
         bool isSecondPeak = (rates[j].high > rates[j-1].high && rates[j].high > rates[j+1].high);
         if(!isSecondPeak) continue;

         if(MathAbs(rates[i].high - rates[j].high) <= tolerance)
         {
            detectedSIDO.patternType = "DOUBLE_TOP";
            detectedSIDO.level1 = rates[i].high;
            detectedSIDO.level2 = rates[j].high;
            detectedSIDO.bar1 = i;
            detectedSIDO.bar2 = j;
            detectedSIDO.confirmed = true;
            IndicatorRelease(atrHandle);
            return;
         }
      }
   }

   // Detect DOUBLE BOTTOM
   for(int i = 10; i < SIDOBarsToAnalyze - 10; i++)
   {
      bool isFirstTrough = (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low);
      if(!isFirstTrough) continue;

      for(int j = i + 5; j < SIDOBarsToAnalyze - 5; j++)
      {
         bool isSecondTrough = (rates[j].low < rates[j-1].low && rates[j].low < rates[j+1].low);
         if(!isSecondTrough) continue;

         if(MathAbs(rates[i].low - rates[j].low) <= tolerance)
         {
            detectedSIDO.patternType = "DOUBLE_BOTTOM";
            detectedSIDO.level1 = rates[i].low;
            detectedSIDO.level2 = rates[j].low;
            detectedSIDO.bar1 = i;
            detectedSIDO.bar2 = j;
            detectedSIDO.confirmed = true;
            IndicatorRelease(atrHandle);
            return;
         }
      }
   }

   detectedSIDO.confirmed = false;
   IndicatorRelease(atrHandle);
}

// ===== HELPER FUNCTIONS =====
double CalculateLotSize(double stopLoss, double entryPrice)
{
   double risk = MathAbs(entryPrice - stopLoss);
   if(risk <= 0) return 0.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return 0.01;

   double riskAmount = MaxCapital * RiskPercent / 100.0;
   double lotSize = riskAmount / (risk / tickSize * tickValue);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   return NormalizeDouble(lotSize, 2);
}

int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i) && posInfo.Symbol() == _Symbol && posInfo.Magic() == 123456)
         count++;
   }
   return count;
}

int CountTradesForToday()
{
   int count = 0;
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      if(!HistoryDealGetTicket(i)) continue;
      if(HistoryDealGetString(i, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(i, DEAL_MAGIC) != 123456) continue;
      if(HistoryDealGetInteger(i, DEAL_TIME) >= today)
         count++;
   }
   return count;
}

double iMAOnArray(MqlRates &rates[], int shift, int period, int index)
{
   double sum = 0;
   for(int i = 0; i < period; i++)
      sum += rates[shift + i].close;
   return sum / period;
}

void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
}
