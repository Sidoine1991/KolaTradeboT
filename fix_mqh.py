import os

mqh_path = "d:/Dev/TradBOT/SMC_Advanced_Entry_System.mqh"

# Read current content
with open(mqh_path, "r", encoding="utf-8", errors="ignore") as f:
    content = f.read()

# If already ends with #endif, nothing to do
if "#endif // __SMC_ADVANCED_ENTRY_SYSTEM_MQH__" in content[-200:]:
    print("File already complete.")
    exit(0)

# Truncate at the last complete function boundary
# Find the start of AnalyzeLiquidityZonesScore which is truncated
marker = "double AnalyzeLiquidityZonesScore(const string direction)"
pos = content.rfind(marker)
if pos >= 0:
    content = content[:pos]
else:
    print("Marker not found, keeping existing content")

# Now append all remaining functions
appendix = r'''double AnalyzeLiquidityZonesScore(const string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 40, rates);
   if(copied < 15) return 0.0;

   double currentPrice = rates[0].close;
   double score = 0.0;

   if(direction == "BUY")
   {
      for(int i = 10; i < 30; i++)
      {
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
         {
            double distance = currentPrice - rates[i].low;
            if(distance > 0 && distance < (GetATRForTimeframe(_Symbol, PERIOD_M5, 0) * 2.0))
               score = MathMax(score, 0.75);
         }
      }
   }
   else if(direction == "SELL")
   {
      for(int i = 10; i < 30; i++)
      {
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
         {
            double distance = rates[i].high - currentPrice;
            if(distance > 0 && distance < (GetATRForTimeframe(_Symbol, PERIOD_M5, 0) * 2.0))
               score = MathMax(score, 0.75);
         }
      }
   }

   return score;
}

double AnalyzeMultiTimeframeScore(const string direction)
{
   double scoreM1 = GetTrendScore(PERIOD_M1, direction);
   double scoreM5 = GetTrendScore(PERIOD_M5, direction);
   double scoreH1 = GetTrendScore(PERIOD_H1, direction);

   int alignedCount = 0;
   if(scoreM1 >= 0.6) alignedCount++;
   if(scoreM5 >= 0.6) alignedCount++;
   if(scoreH1 >= 0.6) alignedCount++;

   if(alignedCount == 3) return 0.9;
   else if(alignedCount == 2) return 0.7;
   else if(alignedCount == 1) return 0.4;
   else return 0.2;
}

double GetSupportLevel(MqlRates &rates[], int bars)
{
   double support = 0.0;
   for(int i = 1; i < bars; i++)
   {
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
         support = MathMax(support, rates[i].low);
   }
   return support;
}

double GetResistanceLevel(MqlRates &rates[], int bars)
{
   double resistance = 0.0;
   for(int i = 1; i < bars; i++)
   {
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
         resistance = MathMax(resistance, rates[i].high);
   }
   return resistance;
}

double GetATRForTimeframe(const string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, shift, 15, rates) < 14) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < 14; i++) sum += (rates[i].high - rates[i].low);
   return sum / 14.0;
}

double GetTrendScore(ENUM_TIMEFRAMES tf, const string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, tf, 0, 20, rates) < 10) return 0.5;
   double close = rates[0].close;
   double ema13 = CalculateEMA(_Symbol, tf, 13, 0);
   double ema21 = CalculateEMA(_Symbol, tf, 21, 0);
   if(direction == "BUY")
   {
      if(close > ema13 && ema13 > ema21) return 0.85;
      else if(close > ema13 || ema13 > ema21) return 0.65;
      else return 0.35;
   }
   else if(direction == "SELL")
   {
      if(close < ema13 && ema13 < ema21) return 0.85;
      else if(close < ema13 || ema13 < ema21) return 0.65;
      else return 0.35;
   }
   return 0.5;
}

double CalculateEMA(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, shift, period + 1, rates) < period) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < period; i++) sum += rates[i].close;
   return sum / period;
}

struct SetupScore
{
   double patternScore;
   double confluenceScore;
   double totalScore;
   bool isValid;
};

bool CalculateCompleteSetupScore(const string direction, SetupScore &scoreOut)
{
   scoreOut.patternScore = 0.0;
   scoreOut.confluenceScore = 0.0;
   scoreOut.totalScore = 0.0;
   scoreOut.isValid = false;
   PatternDetection pattern;
   bool foundPattern = false;

   if(AdvancedEntryUseEngulfing && DetectEngulfing(PERIOD_M1, 50, pattern))
      foundPattern = true;
   else if(AdvancedEntryUsePinBar && DetectPinBar(PERIOD_M1, 50, pattern))
      foundPattern = true;
   else if(AdvancedEntryUseInsideBar && DetectInsideBar(PERIOD_M1, 50, pattern))
      foundPattern = true;
   else if(AdvancedEntryUseHarami && DetectHarami(PERIOD_M1, 50, pattern))
      foundPattern = true;

   if(!foundPattern) return false;
   if(pattern.direction != direction) return false;

   scoreOut.patternScore = pattern.strength * 100.0;

   if(AdvancedEntryRequireMultiTimeframeConfluence)
   {
      ConfluenceAnalysis confluence;
      AnalyzeConfluence(direction, confluence);
      scoreOut.confluenceScore = confluence.totalConfluenceScore * 100.0;
   }
   else scoreOut.confluenceScore = 50.0;

   scoreOut.totalScore = (scoreOut.patternScore * 0.60) + (scoreOut.confluenceScore * 0.40);
   scoreOut.isValid = (scoreOut.totalScore >= AdvancedEntryMinimumScorePercent);
   return true;
}

#endif // __SMC_ADVANCED_ENTRY_SYSTEM_MQH__
'''

with open(mqh_path, "w", encoding="utf-8") as f:
    f.write(content + appendix)

print("File fixed. Total lines:", len(open(mqh_path, "r", encoding="utf-8", errors="ignore").read().splitlines()))
