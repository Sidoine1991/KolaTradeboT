//+------------------------------------------------------------------+
//|                                    SNIPER_RADAR_EA_V1_2.mq5     |
//|                          Sniper Radar Expert Advisor             |
//|          Strategy: Multi-Confluence Scanner (BOS+OB+FVG+MSS)    |
//+------------------------------------------------------------------+
#property copyright "Sniper Radar EA v1.2"
#property version   "1.2"
#property description "Scanner de confluence: BOS, MSS, OB, FVG, Rejection"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;

//=== INPUTS ===================================================================

input group "══════════ GESTION DU RISQUE ══════════"
input double   InpRiskPercent     = 1.0;    // Risque par trade (%)
input double   InpRRRatio         = 2.5;    // Ratio Risque/Rendement
input int      InpMaxPositions    = 2;      // Positions max simultanées
input double   InpMaxLot          = 10.0;   // Lot maximum

input group "══════════ FILTRE DE CONFLUENCE ══════════"
input int      InpMinConfluence   = 3;      // Score min de confluence (1-5)
input bool     InpNeedBOS         = true;   // Exiger BOS/MSS
input bool     InpNeedOB          = true;   // Exiger Order Block
input bool     InpNeedFVG         = false;  // Exiger FVG
input bool     InpNeedRejection   = true;   // Exiger rejet de wick
input bool     InpNeedVolume      = false;  // Exiger confirmation volume

input group "══════════ STRUCTURE DU MARCHÉ ══════════"
input int      InpSwingLookback   = 20;     // Lookback pour swing H/L
input int      InpBOSLookback     = 50;     // Lookback pour BOS
input ENUM_TIMEFRAMES InpHTF      = PERIOD_H1;  // Timeframe biais (HTF)
input ENUM_TIMEFRAMES InpExec     = PERIOD_M15; // Timeframe exécution

input group "══════════ ORDER BLOCKS ══════════"
input int      InpOBLookback      = 25;     // Lookback OB (bougies)
input double   InpOBMinPips       = 5.0;    // Taille min OB (pips)
input double   InpOBEntryPercent  = 50.0;   // Entrée dans l'OB (% depuis bas)

input group "══════════ DÉTECTION WICK ══════════"
input double   InpWickRatio       = 2.0;    // Ratio wick/corps pour rejet
input double   InpMinWickPips     = 5.0;    // Wick min (pips)

input group "══════════ SESSIONS DE TRADING ══════════"
input bool     InpLondonSession   = true;   // Session Londres (7h-12h UTC)
input bool     InpNYSession       = true;   // Session New York (13h-18h UTC)
input bool     InpAsiaSession     = false;  // Session Asie (0h-6h UTC)
input bool     InpKillzoneOnly    = true;   // Entrer uniquement en killzone

input group "══════════ PARAMÈTRES TRADE ══════════"
input int      InpMagicNumber     = 77002;  // Magic Number
input int      InpSlippage        = 10;     // Slippage (points)
input bool     InpAllowBuy        = true;   // Autoriser BUY
input bool     InpAllowSell       = true;   // Autoriser SELL
input bool     InpTrailingStop    = true;   // Trailing Stop actif
input double   InpTrailPips       = 15.0;   // Distance trailing (pips)
input bool     InpBreakEven       = true;   // Break Even actif
input double   InpBEThreshold     = 1.0;    // BE à (x * risque) profit

//=== STRUCTURES ===============================================================

struct SwingPoint
{
   double   price;
   bool     isHigh;
   int      bar;
   datetime time;
};

struct MarketStructure
{
   bool     bullish;       // Structure haussière validée
   bool     bearish;       // Structure baissière validée
   bool     bosDetected;   // Break of Structure détecté
   bool     mssDetected;   // Market Structure Shift détecté
   double   lastHH;        // Dernier Higher High
   double   lastHL;        // Dernier Higher Low
   double   lastLH;        // Dernier Lower High
   double   lastLL;        // Dernier Lower Low
   double   bosLevel;      // Niveau du BOS
};

struct OBZone
{
   double   high, low, mid;
   bool     bullish;
   bool     mitigated;
   int      strength;      // Score force (1-3)
   datetime time;
};

struct FVGZone
{
   double   high, low;
   bool     bullish;
   bool     filled;
   datetime time;
};

struct SetupScore
{
   int      score;
   bool     hasBOS;
   bool     hasMSS;
   bool     hasOB;
   bool     hasFVG;
   bool     hasRejection;
   bool     hasVolume;
   string   description;
};

//=== VARIABLES GLOBALES =======================================================

double         g_Point, g_PipValue;
int            g_Digits;
string         g_Symbol;
datetime       g_LastBar = 0;
MarketStructure g_HTF_MS, g_Exec_MS;
OBZone         g_OBs[];
FVGZone        g_FVGs[];
SwingPoint     g_Swings[];

//=== INITIALISATION ===========================================================

int OnInit()
{
   g_Symbol  = Symbol();
   g_Digits  = (int)SymbolInfoInteger(g_Symbol, SYMBOL_DIGITS);
   g_Point   = SymbolInfoDouble(g_Symbol, SYMBOL_POINT);
   g_PipValue = (g_Digits == 3 || g_Digits == 5) ? g_Point * 10 : g_Point;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   PrintFormat("📡 SNIPER RADAR EA v1.2 | %s | Exec=%s | HTF=%s",
               g_Symbol,
               EnumToString(InpExec),
               EnumToString(InpHTF));
   PrintFormat("   Confluence min: %d/5 | RR: %.1f | Risque: %.1f%%",
               InpMinConfluence, InpRRRatio, InpRiskPercent);

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SR_");
   PrintFormat("🔴 SNIPER RADAR EA arrêté.");
}

//=== TICK PRINCIPAL ===========================================================

void OnTick()
{
   //--- Nouvelle bougie sur le TF d'exécution
   datetime barTime = iTime(g_Symbol, InpExec, 0);
   if(barTime == g_LastBar)
   {
      ManagePositions();
      return;
   }
   g_LastBar = barTime;

   //--- Analyses
   AnalyzeMarketStructure(InpHTF,  g_HTF_MS);
   AnalyzeMarketStructure(InpExec, g_Exec_MS);
   ScanOrderBlocks();
   ScanFVGs();

   //--- Recherche setups si slots disponibles
   if(CountPositions() < InpMaxPositions)
   {
      if(InpAllowBuy)  ScanBuySetup();
      if(InpAllowSell) ScanSellSetup();
   }
}

//=== ANALYSE DE STRUCTURE DE MARCHÉ ==========================================

void AnalyzeMarketStructure(ENUM_TIMEFRAMES tf, MarketStructure &ms)
{
   ArrayResize(g_Swings, 0);
   int swingCount = 0;

   //--- Détecter les swing points
   for(int i = InpSwingLookback; i >= 2; i--)
   {
      double hi  = iHigh(g_Symbol, tf, i);
      double lo  = iLow(g_Symbol,  tf, i);
      bool isSwH = IsSwingHigh(tf, i, 2);
      bool isSwL = IsSwingLow(tf, i, 2);

      if(isSwH || isSwL)
      {
         SwingPoint sp;
         sp.price  = isSwH ? hi : lo;
         sp.isHigh = isSwH;
         sp.bar    = i;
         sp.time   = iTime(g_Symbol, tf, i);
         ArrayResize(g_Swings, swingCount + 1);
         g_Swings[swingCount++] = sp;
      }
   }

   if(swingCount < 4) return;

   //--- Identifier HH, HL, LH, LL
   double lastHigh = 0, prevHigh = 0;
   double lastLow  = DBL_MAX, prevLow = DBL_MAX;
   int    highCount = 0, lowCount = 0;

   for(int i = 0; i < swingCount; i++)
   {
      if(g_Swings[i].isHigh)
      {
         if(highCount == 0) lastHigh = g_Swings[i].price;
         else prevHigh = g_Swings[i].price;
         highCount++;
      }
      else
      {
         if(lowCount == 0) lastLow = g_Swings[i].price;
         else prevLow = g_Swings[i].price;
         lowCount++;
      }
   }

   bool hasHH = (lastHigh > prevHigh && prevHigh > 0);
   bool hasHL = (lastLow  > prevLow  && prevLow  < DBL_MAX);
   bool hasLH = (lastHigh < prevHigh && prevHigh > 0);
   bool hasLL = (lastLow  < prevLow  && prevLow  < DBL_MAX);

   ms.bullish = hasHH && hasHL;
   ms.bearish = hasLH && hasLL;
   ms.lastHH  = lastHigh;
   ms.lastHL  = lastLow;
   ms.lastLH  = lastHigh;
   ms.lastLL  = lastLow;

   //--- Détecter BOS
   double currentClose = iClose(g_Symbol, tf, 1);
   ms.bosDetected = false;
   ms.mssDetected = false;

   if(ms.bullish && currentClose > lastHigh)
   {
      ms.bosDetected = true;
      ms.bosLevel    = lastHigh;
   }
   if(ms.bearish && currentClose < lastLow)
   {
      ms.bosDetected = true;
      ms.bosLevel    = lastLow;
   }

   //--- MSS (Market Structure Shift = contre-tendance)
   if(!ms.bullish && currentClose > lastHigh)
   {
      ms.mssDetected = true;
      ms.bosLevel    = lastHigh;
   }
   if(!ms.bearish && currentClose < lastLow)
   {
      ms.mssDetected = true;
      ms.bosLevel    = lastLow;
   }
}

bool IsSwingHigh(ENUM_TIMEFRAMES tf, int bar, int range)
{
   double hi = iHigh(g_Symbol, tf, bar);
   for(int i = 1; i <= range; i++)
   {
      if(iHigh(g_Symbol, tf, bar - i) >= hi) return false;
      if(iHigh(g_Symbol, tf, bar + i) >= hi) return false;
   }
   return true;
}

bool IsSwingLow(ENUM_TIMEFRAMES tf, int bar, int range)
{
   double lo = iLow(g_Symbol, tf, bar);
   for(int i = 1; i <= range; i++)
   {
      if(iLow(g_Symbol, tf, bar - i) <= lo) return false;
      if(iLow(g_Symbol, tf, bar + i) <= lo) return false;
   }
   return true;
}

//=== SCAN ORDER BLOCKS ========================================================

void ScanOrderBlocks()
{
   ArrayResize(g_OBs, 0);
   int count = 0;

   for(int i = 3; i <= InpOBLookback; i++)
   {
      double open_i  = iOpen(g_Symbol,  InpExec, i);
      double close_i = iClose(g_Symbol, InpExec, i);
      double high_i  = iHigh(g_Symbol,  InpExec, i);
      double low_i   = iLow(g_Symbol,   InpExec, i);
      double size    = MathAbs(close_i - open_i) / g_PipValue;

      if(size < InpOBMinPips) continue;

      bool bearishCandle = close_i < open_i;
      bool bullishCandle = close_i > open_i;

      //--- Bullish OB : bougie baissière puis impulsion haussière
      if(bearishCandle)
      {
         double nextClose = iClose(g_Symbol, InpExec, i - 1);
         double nextOpen  = iOpen(g_Symbol,  InpExec, i - 1);
         if(nextClose > high_i && nextClose > nextOpen)
         {
            OBZone ob;
            ob.high      = high_i;
            ob.low       = low_i;
            ob.mid       = low_i + (high_i - low_i) * (InpOBEntryPercent / 100.0);
            ob.bullish   = true;
            ob.mitigated = IsOBMitigated(ob.high, ob.low, true, i);
            ob.strength  = ScoreOBStrength(i, true);
            ob.time      = iTime(g_Symbol, InpExec, i);
            ArrayResize(g_OBs, count + 1);
            g_OBs[count++] = ob;
         }
      }

      //--- Bearish OB : bougie haussière puis impulsion baissière
      if(bullishCandle)
      {
         double nextClose = iClose(g_Symbol, InpExec, i - 1);
         double nextOpen  = iOpen(g_Symbol,  InpExec, i - 1);
         if(nextClose < low_i && nextClose < nextOpen)
         {
            OBZone ob;
            ob.high      = high_i;
            ob.low       = low_i;
            ob.mid       = high_i - (high_i - low_i) * (InpOBEntryPercent / 100.0);
            ob.bullish   = false;
            ob.mitigated = IsOBMitigated(ob.high, ob.low, false, i);
            ob.strength  = ScoreOBStrength(i, false);
            ob.time      = iTime(g_Symbol, InpExec, i);
            ArrayResize(g_OBs, count + 1);
            g_OBs[count++] = ob;
         }
      }
   }
}

bool IsOBMitigated(double high, double low, bool bullish, int fromBar)
{
   for(int i = fromBar - 1; i >= 1; i--)
   {
      double lo = iLow(g_Symbol, InpExec, i);
      double hi = iHigh(g_Symbol, InpExec, i);
      if(bullish && lo <= low)   return true;
      if(!bullish && hi >= high) return true;
   }
   return false;
}

int ScoreOBStrength(int bar, bool bullish)
{
   int score = 1;
   double range = iHigh(g_Symbol, InpExec, bar) - iLow(g_Symbol, InpExec, bar);
   double body  = MathAbs(iClose(g_Symbol, InpExec, bar) - iOpen(g_Symbol, InpExec, bar));

   if(body / range > 0.6) score++;  // Corps fort

   //--- Vérifier si l'OB correspond à un niveau de structure
   double hi = iHigh(g_Symbol, InpExec, bar);
   double lo = iLow(g_Symbol,  InpExec, bar);
   double tol = 5 * g_PipValue;
   for(int i = 0; i < ArraySize(g_Swings); i++)
   {
      if(MathAbs(g_Swings[i].price - (bullish ? lo : hi)) < tol)
      {
         score++;
         break;
      }
   }
   return MathMin(score, 3);
}

//=== SCAN FAIR VALUE GAPS =====================================================

void ScanFVGs()
{
   ArrayResize(g_FVGs, 0);
   int count = 0;

   for(int i = 2; i <= InpOBLookback; i++)
   {
      double hi_prev = iHigh(g_Symbol, InpExec, i + 1);
      double lo_prev = iLow(g_Symbol,  InpExec, i + 1);
      double hi_next = iHigh(g_Symbol, InpExec, i - 1);
      double lo_next = iLow(g_Symbol,  InpExec, i - 1);

      //--- Bullish FVG
      if(lo_next > hi_prev + g_PipValue)
      {
         FVGZone fvg;
         fvg.low     = hi_prev;
         fvg.high    = lo_next;
         fvg.bullish = true;
         fvg.filled  = IsFVGFilled(fvg.high, fvg.low, true, i);
         fvg.time    = iTime(g_Symbol, InpExec, i);
         ArrayResize(g_FVGs, count + 1);
         g_FVGs[count++] = fvg;
      }

      //--- Bearish FVG
      if(hi_next < lo_prev - g_PipValue)
      {
         FVGZone fvg;
         fvg.high    = lo_prev;
         fvg.low     = hi_next;
         fvg.bullish = false;
         fvg.filled  = IsFVGFilled(fvg.high, fvg.low, false, i);
         fvg.time    = iTime(g_Symbol, InpExec, i);
         ArrayResize(g_FVGs, count + 1);
         g_FVGs[count++] = fvg;
      }
   }
}

bool IsFVGFilled(double high, double low, bool bullish, int fromBar)
{
   for(int i = fromBar - 1; i >= 1; i--)
   {
      double lo = iLow(g_Symbol, InpExec, i);
      double hi = iHigh(g_Symbol, InpExec, i);
      if(bullish && lo <= low)   return true;
      if(!bullish && hi >= high) return true;
   }
   return false;
}

//=== SCAN SETUP ACHAT =========================================================

void ScanBuySetup()
{
   if(!g_HTF_MS.bullish && !g_HTF_MS.mssDetected) return;
   if(InpKillzoneOnly && !IsKillzone()) return;

   double ask = SymbolInfoDouble(g_Symbol, SYMBOL_ASK);

   for(int i = 0; i < ArraySize(g_OBs); i++)
   {
      if(!g_OBs[i].bullish || g_OBs[i].mitigated) continue;
      if(ask < g_OBs[i].low || ask > g_OBs[i].high) continue;

      SetupScore sc = EvaluateBuySetup(i, ask);
      if(sc.score < InpMinConfluence) continue;

      double sl   = g_OBs[i].low - (2 * g_PipValue);
      double tp   = ask + (ask - sl) * InpRRRatio;
      double lots = CalcLots(ask, sl);

      if(lots <= 0) continue;

      PrintFormat("📡 BUY Setup [Score: %d/5] | Ask=%.5f | OB[%.5f-%.5f]",
                  sc.score, ask, g_OBs[i].low, g_OBs[i].high);
      PrintFormat("   🔹 %s", sc.description);

      ExecuteTrade(ORDER_TYPE_BUY, lots, sl, tp);
      return;
   }

   //--- Entrée sur FVG bullish si pas d'OB
   if(!InpNeedOB)
   {
      for(int i = 0; i < ArraySize(g_FVGs); i++)
      {
         if(!g_FVGs[i].bullish || g_FVGs[i].filled) continue;
         if(ask < g_FVGs[i].low || ask > g_FVGs[i].high) continue;

         SetupScore sc = EvaluateBuyFVG(i, ask);
         if(sc.score < InpMinConfluence) continue;

         double sl   = g_FVGs[i].low - (2 * g_PipValue);
         double tp   = ask + (ask - sl) * InpRRRatio;
         double lots = CalcLots(ask, sl);

         if(lots <= 0) continue;

         PrintFormat("📡 BUY Setup FVG [Score: %d/5] | Ask=%.5f | FVG[%.5f-%.5f]",
                     sc.score, ask, g_FVGs[i].low, g_FVGs[i].high);
         ExecuteTrade(ORDER_TYPE_BUY, lots, sl, tp);
         return;
      }
   }
}

//=== SCAN SETUP VENTE =========================================================

void ScanSellSetup()
{
   if(!g_HTF_MS.bearish && !g_HTF_MS.mssDetected) return;
   if(InpKillzoneOnly && !IsKillzone()) return;

   double bid = SymbolInfoDouble(g_Symbol, SYMBOL_BID);

   for(int i = 0; i < ArraySize(g_OBs); i++)
   {
      if(g_OBs[i].bullish || g_OBs[i].mitigated) continue;
      if(bid < g_OBs[i].low || bid > g_OBs[i].high) continue;

      SetupScore sc = EvaluateSellSetup(i, bid);
      if(sc.score < InpMinConfluence) continue;

      double sl   = g_OBs[i].high + (2 * g_PipValue);
      double tp   = bid - (sl - bid) * InpRRRatio;
      double lots = CalcLots(bid, sl);

      if(lots <= 0) continue;

      PrintFormat("📡 SELL Setup [Score: %d/5] | Bid=%.5f | OB[%.5f-%.5f]",
                  sc.score, bid, g_OBs[i].low, g_OBs[i].high);
      PrintFormat("   🔸 %s", sc.description);

      ExecuteTrade(ORDER_TYPE_SELL, lots, sl, tp);
      return;
   }

   //--- Entrée sur FVG bearish
   if(!InpNeedOB)
   {
      for(int i = 0; i < ArraySize(g_FVGs); i++)
      {
         if(g_FVGs[i].bullish || g_FVGs[i].filled) continue;
         if(bid < g_FVGs[i].low || bid > g_FVGs[i].high) continue;

         SetupScore sc = EvaluateSellFVG(i, bid);
         if(sc.score < InpMinConfluence) continue;

         double sl   = g_FVGs[i].high + (2 * g_PipValue);
         double tp   = bid - (sl - bid) * InpRRRatio;
         double lots = CalcLots(bid, sl);

         if(lots <= 0) continue;

         PrintFormat("📡 SELL Setup FVG [Score: %d/5] | Bid=%.5f | FVG[%.5f-%.5f]",
                     sc.score, bid, g_FVGs[i].low, g_FVGs[i].high);
         ExecuteTrade(ORDER_TYPE_SELL, lots, sl, tp);
         return;
      }
   }
}

//=== SCORING DE CONFLUENCE ====================================================

SetupScore EvaluateBuySetup(int obIdx, double price)
{
   SetupScore sc;
   sc.score       = 0;
   sc.description = "";

   //--- 1. BOS/MSS haussier sur HTF
   if(g_HTF_MS.bullish || g_HTF_MS.mssDetected)
   {
      sc.score++;
      sc.hasBOS = true;
      sc.description += "HTF Bullish | ";
   }

   //--- 2. BOS sur exécution
   if(g_Exec_MS.bosDetected || g_Exec_MS.bullish)
   {
      sc.score++;
      sc.description += "Exec BOS | ";
   }

   //--- 3. Order Block valide
   if(InpNeedOB && !g_OBs[obIdx].mitigated)
   {
      sc.score += g_OBs[obIdx].strength;
      sc.hasOB = true;
      sc.description += StringFormat("Bullish OB (str=%d) | ", g_OBs[obIdx].strength);
   }
   else if(!InpNeedOB) sc.score++;

   //--- 4. FVG dans la même zone
   if(InpNeedFVG)
   {
      for(int i = 0; i < ArraySize(g_FVGs); i++)
      {
         if(g_FVGs[i].bullish && !g_FVGs[i].filled)
         {
            if(MathAbs(g_FVGs[i].low - g_OBs[obIdx].low) < 10 * g_PipValue)
            {
               sc.score++;
               sc.hasFVG = true;
               sc.description += "FVG confluence | ";
               break;
            }
         }
      }
   }
   else sc.score++;

   //--- 5. Rejet de wick baissier sur la bougie précédente
   if(InpNeedRejection)
   {
      double open1  = iOpen(g_Symbol,  InpExec, 1);
      double close1 = iClose(g_Symbol, InpExec, 1);
      double low1   = iLow(g_Symbol,   InpExec, 1);
      double high1  = iHigh(g_Symbol,  InpExec, 1);
      double body   = MathAbs(close1 - open1);
      double lowerWick = MathMin(open1, close1) - low1;
      double wickPips  = lowerWick / g_PipValue;

      if(lowerWick > body * InpWickRatio && wickPips >= InpMinWickPips && close1 > open1)
      {
         sc.score++;
         sc.hasRejection = true;
         sc.description += StringFormat("Bullish Rejection (%.1fpips) | ", wickPips);
      }
   }
   else sc.score++;

   return sc;
}

SetupScore EvaluateSellSetup(int obIdx, double price)
{
   SetupScore sc;
   sc.score       = 0;
   sc.description = "";

   if(g_HTF_MS.bearish || g_HTF_MS.mssDetected)
   {
      sc.score++;
      sc.hasBOS = true;
      sc.description += "HTF Bearish | ";
   }

   if(g_Exec_MS.bosDetected || g_Exec_MS.bearish)
   {
      sc.score++;
      sc.description += "Exec BOS | ";
   }

   if(InpNeedOB && !g_OBs[obIdx].mitigated)
   {
      sc.score += g_OBs[obIdx].strength;
      sc.hasOB = true;
      sc.description += StringFormat("Bearish OB (str=%d) | ", g_OBs[obIdx].strength);
   }
   else if(!InpNeedOB) sc.score++;

   if(InpNeedFVG)
   {
      for(int i = 0; i < ArraySize(g_FVGs); i++)
      {
         if(!g_FVGs[i].bullish && !g_FVGs[i].filled)
         {
            if(MathAbs(g_FVGs[i].high - g_OBs[obIdx].high) < 10 * g_PipValue)
            {
               sc.score++;
               sc.hasFVG = true;
               sc.description += "FVG confluence | ";
               break;
            }
         }
      }
   }
   else sc.score++;

   if(InpNeedRejection)
   {
      double open1  = iOpen(g_Symbol,  InpExec, 1);
      double close1 = iClose(g_Symbol, InpExec, 1);
      double high1  = iHigh(g_Symbol,  InpExec, 1);
      double body   = MathAbs(close1 - open1);
      double upperWick = high1 - MathMax(open1, close1);
      double wickPips  = upperWick / g_PipValue;

      if(upperWick > body * InpWickRatio && wickPips >= InpMinWickPips && close1 < open1)
      {
         sc.score++;
         sc.hasRejection = true;
         sc.description += StringFormat("Bearish Rejection (%.1fpips) | ", wickPips);
      }
   }
   else sc.score++;

   return sc;
}

SetupScore EvaluateBuyFVG(int fvgIdx, double price)
{
   SetupScore sc;
   sc.score = 0;
   sc.description = "FVG Entry | ";
   if(g_HTF_MS.bullish)  { sc.score++; sc.description += "HTF Bull | "; }
   if(g_Exec_MS.bullish) { sc.score++; sc.description += "Exec Bull | "; }
   sc.score++;
   return sc;
}

SetupScore EvaluateSellFVG(int fvgIdx, double price)
{
   SetupScore sc;
   sc.score = 0;
   sc.description = "FVG Entry | ";
   if(g_HTF_MS.bearish)  { sc.score++; sc.description += "HTF Bear | "; }
   if(g_Exec_MS.bearish) { sc.score++; sc.description += "Exec Bear | "; }
   sc.score++;
   return sc;
}

//=== GESTION DES POSITIONS OUVERTES ==========================================

void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != g_Symbol)      continue;

      ulong  ticket    = posInfo.Ticket();
      double openPrice = posInfo.PriceOpen();
      double sl        = posInfo.StopLoss();
      double tp        = posInfo.TakeProfit();
      double bid       = SymbolInfoDouble(g_Symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(g_Symbol, SYMBOL_ASK);
      bool   isBuy     = (posInfo.PositionType() == POSITION_TYPE_BUY);

      double riskPips   = MathAbs(openPrice - sl) / g_PipValue;
      double profitPips = isBuy ? (bid - openPrice) / g_PipValue
                                : (openPrice - ask) / g_PipValue;

      //--- Break Even
      if(InpBreakEven && profitPips >= riskPips * InpBEThreshold)
      {
         double newSL = isBuy ? openPrice + g_PipValue
                              : openPrice - g_PipValue;
         bool needUpdate = isBuy ? (sl < newSL) : (sl > newSL || sl == 0);
         if(needUpdate)
            trade.PositionModify(ticket, NormalizeDouble(newSL, g_Digits), tp);
      }

      //--- Trailing Stop
      if(InpTrailingStop)
      {
         double dist  = InpTrailPips * g_PipValue;
         double newSL = isBuy ? bid - dist : ask + dist;
         bool canTrail = isBuy ? (newSL > sl && newSL > openPrice)
                                : ((newSL < sl || sl == 0) && newSL < openPrice);
         if(canTrail)
            trade.PositionModify(ticket, NormalizeDouble(newSL, g_Digits), tp);
      }
   }
}

//=== UTILITAIRES ==============================================================

bool IsKillzone()
{
   MqlDateTime dt;
   TimeGMT(dt);
   int h = dt.hour;

   bool london  = InpLondonSession && (h >= 7  && h < 12);
   bool newYork = InpNYSession     && (h >= 13 && h < 18);
   bool asia    = InpAsiaSession   && (h >= 0  && h < 6);

   return (london || newYork || asia);
}

double CalcLots(double entryPrice, double slPrice)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt   = balance * InpRiskPercent / 100.0;
   double slPips    = MathAbs(entryPrice - slPrice) / g_PipValue;
   if(slPips < 1.0) return 0;

   double tickVal  = SymbolInfoDouble(g_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(g_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipVal   = (g_PipValue / tickSize) * tickVal;

   double lots     = riskAmt / (slPips * pipVal);
   double minLot   = SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot   = MathMin(SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_MAX), InpMaxLot);
   double step     = SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / step) * step;
   return MathMax(minLot, MathMin(maxLot, lots));
}

void ExecuteTrade(ENUM_ORDER_TYPE type, double lots, double sl, double tp)
{
   sl = NormalizeDouble(sl, g_Digits);
   tp = NormalizeDouble(tp, g_Digits);

   bool ok = false;
   if(type == ORDER_TYPE_BUY)
      ok = trade.Buy(lots, g_Symbol, SymbolInfoDouble(g_Symbol, SYMBOL_ASK), sl, tp, "SR_BUY");
   else
      ok = trade.Sell(lots, g_Symbol, SymbolInfoDouble(g_Symbol, SYMBOL_BID), sl, tp, "SR_SELL");

   if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      PrintFormat("✅ Trade exécuté | %s | %.2f lots | SL=%.5f | TP=%.5f",
                  type == ORDER_TYPE_BUY ? "BUY" : "SELL", lots, sl, tp);
   else
      PrintFormat("❌ Erreur exécution: %d | %s", trade.ResultRetcode(), trade.ResultComment());
}

int CountPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == g_Symbol) n++;
   }
   return n;
}

//+------------------------------------------------------------------+
