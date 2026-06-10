//+------------------------------------------------------------------+
//| SMC_TVBridge.mqh — TradingView ↔ MT5 Real-Time Bridge              |
//| Reads GOM verdict, Order Blocks, FVG via MCP + File I/O             |
//+------------------------------------------------------------------+
#ifndef SMC_TV_BRIDGE_MQH
#define SMC_TV_BRIDGE_MQH

#include "GOMIntegration.mqh"

// ═══════════════════════════════════════════════════════════════════
// STRUCTURE: TV SNAPSHOT
// ═══════════════════════════════════════════════════════════════════

struct STVSnapshot
{
   // Price levels from TradingView
   double bid;
   double ask;
   double high20;    // 20-bar high
   double low20;     // 20-bar low

   // GOM indicators
   string gomVerdict;
   int gomScore;
   double gomQuality;
   double gomImbalance;

   // Order Blocks (from Pine labels)
   double obBullish;
   double obBearish;

   // Fair Value Gaps
   double fvgUp;
   double fvgDown;

   // RSI + Stochastic
   double rsi;
   double stochK;
   double stochD;

   // Coherence flags
   bool h4TrendUp;
   bool h4TrendDown;
   bool h1Impulsive;
   bool m15GOMAlignment;

   datetime capturedAt;
   bool valid;
};

// Global TV snapshot
STVSnapshot g_tvSnapshot;

// ═══════════════════════════════════════════════════════════════════
// LIVE CAPTURE: MCP DATA_GET_PINE_LABELS
// ═══════════════════════════════════════════════════════════════════

bool TV_CaptureLiveData()
{
   // In production: Use MCP tradingview-kola:data_get_pine_labels
   // to fetch GOM labels (OB levels, FVG, setup entry/SL/TP)

   // For now: Fallback to file-based polling
   return TV_LoadFromFile();
}

// ═══════════════════════════════════════════════════════════════════
// FILE-BASED POLLING
// ═══════════════════════════════════════════════════════════════════

bool TV_LoadFromFile()
{
   string filePath = "data\\tv_snapshot.json";

   int h = FileOpen(filePath, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      h = FileOpen(filePath, FILE_READ | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE)
         return false;
   }

   string json = "";
   while(!FileIsEnding(h))
      json += FileReadString(h);
   FileClose(h);

   if(StringLen(json) < 20)
      return false;

   // Parse JSON snapshot
   g_tvSnapshot.bid = StringToDouble(TV_JsonExtract(json, "bid"));
   g_tvSnapshot.ask = StringToDouble(TV_JsonExtract(json, "ask"));
   g_tvSnapshot.high20 = StringToDouble(TV_JsonExtract(json, "high20"));
   g_tvSnapshot.low20 = StringToDouble(TV_JsonExtract(json, "low20"));

   g_tvSnapshot.gomVerdict = TV_JsonExtract(json, "gom_verdict");
   g_tvSnapshot.gomScore = (int)StringToInteger(TV_JsonExtract(json, "gom_score"));
   g_tvSnapshot.gomQuality = StringToDouble(TV_JsonExtract(json, "gom_quality"));
   g_tvSnapshot.gomImbalance = StringToDouble(TV_JsonExtract(json, "gom_imbalance"));

   g_tvSnapshot.obBullish = StringToDouble(TV_JsonExtract(json, "ob_bullish"));
   g_tvSnapshot.obBearish = StringToDouble(TV_JsonExtract(json, "ob_bearish"));

   g_tvSnapshot.fvgUp = StringToDouble(TV_JsonExtract(json, "fvg_up"));
   g_tvSnapshot.fvgDown = StringToDouble(TV_JsonExtract(json, "fvg_down"));

   g_tvSnapshot.rsi = StringToDouble(TV_JsonExtract(json, "rsi"));
   g_tvSnapshot.stochK = StringToDouble(TV_JsonExtract(json, "stoch_k"));
   g_tvSnapshot.stochD = StringToDouble(TV_JsonExtract(json, "stoch_d"));

   g_tvSnapshot.h4TrendUp = (StringFind(TV_JsonExtract(json, "h4_trend"), "UP") >= 0);
   g_tvSnapshot.h4TrendDown = (StringFind(TV_JsonExtract(json, "h4_trend"), "DOWN") >= 0);
   g_tvSnapshot.h1Impulsive = (StringFind(TV_JsonExtract(json, "h1_structure"), "IMPULSIVE") >= 0);
   g_tvSnapshot.m15GOMAlignment = (StringFind(TV_JsonExtract(json, "m15_alignment"), "GOM") >= 0);

   g_tvSnapshot.capturedAt = TimeCurrent();
   g_tvSnapshot.valid = true;

   return true;
}

string TV_JsonExtract(const string &json, const string &key)
{
   string needle = "\"" + key + "\"";
   int pos = StringFind(json, needle);
   if(pos < 0) return "";

   pos = StringFind(json, ":", pos);
   if(pos < 0) return "";
   pos++;

   while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' ||
         StringGetCharacter(json, pos) == '\t'))
      pos++;

   if(pos >= StringLen(json)) return "";

   ushort c = StringGetCharacter(json, pos);
   if(c == '"')
   {
      pos++;
      int end = StringFind(json, "\"", pos);
      if(end < 0) return "";
      return StringSubstr(json, pos, end - pos);
   }

   int end = pos;
   while(end < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, end);
      if(ch == ',' || ch == '}') break;
      end++;
   }

   string val = StringSubstr(json, pos, end - pos);
   StringTrimLeft(val);
   StringTrimRight(val);
   return val;
}

// ═══════════════════════════════════════════════════════════════════
// VALIDATION: CHECK TV DATA FRESHNESS
// ═══════════════════════════════════════════════════════════════════

bool TV_IsDataFresh(int maxAgeSec = 10)
{
   if(!g_tvSnapshot.valid)
      return false;

   return ((int)(TimeCurrent() - g_tvSnapshot.capturedAt) < maxAgeSec);
}

// ═══════════════════════════════════════════════════════════════════
// CONFLUENCE: TV DATA + GOM VERDICT
// ═══════════════════════════════════════════════════════════════════

int TV_CalculateConfluence()
{
   int score = 0;

   if(!g_tvSnapshot.valid)
      return 0;

   // H4 Trend aligned with GOM
   if(g_tvSnapshot.h4TrendUp && g_tvSnapshot.gomVerdict == "BUY")
      score += 2;
   if(g_tvSnapshot.h4TrendDown && g_tvSnapshot.gomVerdict == "SELL")
      score += 2;

   // H1 Impulsive wave
   if(g_tvSnapshot.h1Impulsive)
      score += 1;

   // M15 GOM alignment
   if(g_tvSnapshot.m15GOMAlignment)
      score += 2;

   // RSI confirmation
   if(g_tvSnapshot.rsi < 35 && g_tvSnapshot.gomVerdict == "BUY")
      score += 1;
   if(g_tvSnapshot.rsi > 65 && g_tvSnapshot.gomVerdict == "SELL")
      score += 1;

   // Order Block at price
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(MathAbs(bid - g_tvSnapshot.obBullish) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20)
      score += 1;
   if(MathAbs(bid - g_tvSnapshot.obBearish) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20)
      score += 1;

   return MathMin(score, 7);
}

// ═══════════════════════════════════════════════════════════════════
// ENTRY VALIDATION: TV SIGNALS + GOM VERDICT
// ═══════════════════════════════════════════════════════════════════

bool TV_ValidateEntry(int &direction, double &entryPrice, double &sl, double &tp)
{
   direction = 0;
   entryPrice = 0;
   sl = 0;
   tp = 0;

   if(!g_tvSnapshot.valid)
      return false;

   if(!TV_IsDataFresh())
      return false;

   // Direction from GOM
   if(g_tvSnapshot.gomVerdict == "BUY")
      direction = 1;
   else if(g_tvSnapshot.gomVerdict == "SELL")
      direction = -1;
   else
      return false;

   if(g_tvSnapshot.gomQuality < 60.0)
      return false;

   // Entry price: At Order Block if available, else at bid/ask
   entryPrice = (direction > 0) ?
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
      SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // SL: Below/above Order Block or FVG
   if(direction > 0)
   {
      sl = g_tvSnapshot.obBearish > 0 ?
         g_tvSnapshot.obBearish :
         g_tvSnapshot.fvgDown;
   }
   else
   {
      sl = g_tvSnapshot.obBullish > 0 ?
         g_tvSnapshot.obBullish :
         g_tvSnapshot.fvgUp;
   }

   // TP: 1.5-2x risk
   if(sl > 0)
      tp = entryPrice + (entryPrice - sl) * 1.5 * (direction > 0 ? 1 : -1);

   return (sl > 0 && tp > 0);
}

// ═══════════════════════════════════════════════════════════════════
// CORRECTION DETECTION VIA TV DATA
// ═══════════════════════════════════════════════════════════════════

bool TV_IsCorrectionZone()
{
   if(!g_tvSnapshot.valid)
      return false;

   // Price between multiple conflicting signals = correction
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check if price is between OB levels (no clear direction)
   if(g_tvSnapshot.obBullish > 0 && g_tvSnapshot.obBearish > 0)
   {
      double lower = MathMin(g_tvSnapshot.obBullish, g_tvSnapshot.obBearish);
      double upper = MathMax(g_tvSnapshot.obBullish, g_tvSnapshot.obBearish);

      if(bid > lower && bid < upper)
         return true;  // Price stuck between OBs = consolidation
   }

   // Low GOM quality + divergent stochastic = choppy
   if(g_tvSnapshot.gomQuality < 50.0 && MathAbs(g_tvSnapshot.stochK - g_tvSnapshot.stochD) < 10.0)
      return true;

   return false;
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void TVBridge_Init()
{
   ArrayInitialize(&g_tvSnapshot, 0);
   g_tvSnapshot.valid = false;
   Print("[TVBridge] Initialized");
}

void TVBridge_Poll()
{
   TV_CaptureLiveData();
}

void TVBridge_Deinit()
{
   Print("[TVBridge] Shutdown");
}

#endif // SMC_TV_BRIDGE_MQH
