//+------------------------------------------------------------------+
//| SMC_BearDistributionSetup.mqh — Séquence SMC baissière (image)   |
//| Rally+BOS → OB supply → MSS → Inducement → Retest OB → SELL      |
//+------------------------------------------------------------------+
#ifndef SMC_BEAR_DISTRIBUTION_SETUP_MQH
#define SMC_BEAR_DISTRIBUTION_SETUP_MQH

input group "=== SETUP DISTRIBUTION BEAR (SMC séquentiel) ==="
input bool   UseBearDistributionSetup   = true;   // Détecteur séquence bear (BOS→OB→MSS→Inducement→SELL)
input bool   BearDistDrawOnChart        = true;   // Afficher phases + zone OB sur graphique
input ENUM_TIMEFRAMES BearDistTF        = PERIOD_M5; // Timeframe principal de la séquence
input int    BearDistMaxBars            = 120;    // Expiration setup (barres)
input double BearDistInducementMaxPct   = 0.55;   // Inducement max = % retracement vers OB (0-1)
input bool   BearDistRequireGOM         = true;   // Exiger GOM SELL pour entrée auto

enum SMCDS_PHASE
{
   SMCDS_IDLE = 0,
   SMCDS_BOS_BULL,
   SMCDS_OB_BEAR,
   SMCDS_MARKET_SHIFT,
   SMCDS_INDUCEMENT,
   SMCDS_ENTRY_READY
};

struct SMCDS_State
{
   SMCDS_PHASE phase;
   datetime    phaseTime;
   datetime    bosTime;
   double      bosLevel;
   double      obHigh;
   double      obLow;
   double      peakHigh;
   double      shiftLevel;
   double      inducementHigh;
   double      sslTarget;
   int         startBar;
   string      summary;
};

SMCDS_State g_smcds = { SMCDS_IDLE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "" };

double SMCDS_ATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period = 14)
{
   int h = iATR(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, 0, 1, buf) < 1) { IndicatorRelease(h); return 0.0; }
   IndicatorRelease(h);
   return buf[0];
}

void SMCDS_Reset(const string reason = "")
{
   g_smcds.phase = SMCDS_IDLE;
   g_smcds.phaseTime = 0;
   g_smcds.bosTime = 0;
   g_smcds.bosLevel = 0;
   g_smcds.obHigh = 0;
   g_smcds.obLow = 0;
   g_smcds.peakHigh = 0;
   g_smcds.shiftLevel = 0;
   g_smcds.inducementHigh = 0;
   g_smcds.sslTarget = 0;
   g_smcds.startBar = 0;
   g_smcds.summary = (reason != "") ? reason : "";
}

bool SMCDS_FindSwingHigh(const MqlRates &rates[], const int idx, const int depth = 2)
{
   if(idx < depth || idx + depth >= ArraySize(rates)) return false;
   for(int d = 1; d <= depth; d++)
   {
      if(rates[idx].high <= rates[idx - d].high) return false;
      if(rates[idx].high <= rates[idx + d].high) return false;
   }
   return true;
}

bool SMCDS_FindSwingLow(const MqlRates &rates[], const int idx, const int depth = 2)
{
   if(idx < depth || idx + depth >= ArraySize(rates)) return false;
   for(int d = 1; d <= depth; d++)
   {
      if(rates[idx].low >= rates[idx - d].low) return false;
      if(rates[idx].low >= rates[idx + d].low) return false;
   }
   return true;
}

bool SMCDS_DetectBullBOS(const string symbol, const ENUM_TIMEFRAMES tf,
                           double &bosLevelOut, datetime &bosTimeOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 40, rates) < 40) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minBreak = point * 8;

   for(int i = 3; i < 25; i++)
   {
      if(!SMCDS_FindSwingHigh(rates, i)) continue;
      double swingHigh = rates[i].high;
      if(rates[1].close > swingHigh + minBreak && rates[1].close > rates[1].open)
      {
         bosLevelOut = swingHigh;
         bosTimeOut = rates[1].time;
         return true;
      }
   }
   return false;
}

bool SMCDS_DetectBearOB(const string symbol, const ENUM_TIMEFRAMES tf,
                        const datetime afterTime, double &hiOut, double &loOut, double &peakOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 60, rates) < 60) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minMove = point * 15;

   for(int i = 3; i < 50; i++)
   {
      if(rates[i].time < afterTime) continue;
      if(rates[i].close <= rates[i].open) continue;
      if(rates[i + 1].close >= rates[i + 1].open) continue;

      double moveDown = rates[i].high - rates[i + 2].low;
      if(moveDown < minMove) continue;

      hiOut = rates[i].high;
      loOut = rates[i].low;
      peakOut = hiOut;
      for(int j = i; j >= MathMax(0, i - 8); j--)
         if(rates[j].high > peakOut) peakOut = rates[j].high;
      return true;
   }
   return false;
}

bool SMCDS_DetectMarketShift(const string symbol, const ENUM_TIMEFRAMES tf,
                             const double obLow, double &shiftLevelOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 30, rates) < 30) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minBreak = point * 6;

   for(int i = 4; i < 22; i++)
   {
      if(!SMCDS_FindSwingLow(rates, i)) continue;
      double hl = rates[i].low;
      if(rates[1].close < hl - minBreak && rates[1].close < rates[1].open)
      {
         if(obLow > 0 && hl >= obLow) continue;
         shiftLevelOut = hl;
         return true;
      }
   }
   return false;
}

bool SMCDS_DetectInducement(const string symbol, const ENUM_TIMEFRAMES tf,
                            const double obHigh, const double shiftLevel,
                            double &indHighOut)
{
   if(obHigh <= 0 || shiftLevel <= 0) return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 20, rates) < 20) return false;

   double postShiftLow = rates[1].low;
   for(int i = 1; i < 12; i++)
      if(rates[i].low < postShiftLow) postShiftLow = rates[i].low;

   double rallyHigh = rates[1].high;
   for(int j = 1; j < 8; j++)
      if(rates[j].high > rallyHigh) rallyHigh = rates[j].high;

   double range = obHigh - postShiftLow;
   if(range <= 0) return false;

   double retracePct = (rallyHigh - postShiftLow) / range;
   if(retracePct < 0.18 || retracePct > BearDistInducementMaxPct) return false;
   if(rallyHigh >= obHigh) return false;
   if(rallyHigh <= shiftLevel) return false;

   indHighOut = rallyHigh;
   return true;
}

bool SMCDS_DetectOBRetest(const string symbol, const ENUM_TIMEFRAMES tf,
                          const double obHigh, const double obLow)
{
   if(obHigh <= 0 || obLow <= 0) return false;

   double zH = MathMax(obHigh, obLow);
   double zL = MathMin(obHigh, obLow);
   double hi = iHigh(symbol, tf, 1);
   double lo = iLow(symbol, tf, 1);
   double cl = iClose(symbol, tf, 1);
   double op = iOpen(symbol, tf, 1);
   double atr = SMCDS_ATR(symbol, tf);
   if(atr <= 0) atr = (zH - zL) * 0.5;

   if(hi < zL - atr * 0.25) return false;
   if(hi > zH + atr * 0.25) return false;
   if(cl >= zH) return false;
   return (cl < op && cl < zH);
}

bool SMCDS_FindSSLTarget(const string symbol, const ENUM_TIMEFRAMES tf, double &sslOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 40, rates) < 40) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minSweep = point * 5;

   for(int i = 2; i < 30; i++)
   {
      if(!SMCDS_FindSwingLow(rates, i)) continue;
      double ssl = rates[i].low;
      for(int j = 1; j < i; j++)
      {
         if(rates[j].low < ssl - minSweep)
         {
            sslOut = ssl;
            return true;
         }
      }
   }
   return false;
}

string SMCDS_PhaseName(const SMCDS_PHASE ph)
{
   switch(ph)
   {
      case SMCDS_BOS_BULL:      return "BOS↑";
      case SMCDS_OB_BEAR:       return "OB Supply";
      case SMCDS_MARKET_SHIFT:  return "MSS";
      case SMCDS_INDUCEMENT:    return "Inducement";
      case SMCDS_ENTRY_READY:   return "SELL READY";
      default:                  return "IDLE";
   }
}

void SMCDS_SetPhase(const SMCDS_PHASE ph, const string symbol)
{
   if(g_smcds.phase == ph) return;
   g_smcds.phase = ph;
   g_smcds.phaseTime = TimeCurrent();
   g_smcds.summary = SMCDS_PhaseName(ph);
   Print("[BEAR-DIST] ", symbol, " → phase ", SMCDS_PhaseName(ph),
         (g_smcds.obHigh > 0 ? StringFormat(" | OB %.5f-%.5f", g_smcds.obLow, g_smcds.obHigh) : ""));
}

bool SMCDS_Expired(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(g_smcds.startBar <= 0) return false;
   int curBar = iBars(symbol, tf);
   return (curBar - g_smcds.startBar > BearDistMaxBars);
}

void SMCDS_Update(const string symbol)
{
   if(!UseBearDistributionSetup) return;

   const ENUM_TIMEFRAMES tf = BearDistTF;

   if(g_smcds.phase != SMCDS_IDLE && SMCDS_Expired(symbol, tf))
   {
      SMCDS_Reset("expired");
      return;
   }

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(g_smcds.obHigh > 0 && bid > g_smcds.obHigh + SMCDS_ATR(symbol, tf) * 0.35)
   {
      SMCDS_Reset("invalidated above OB");
      return;
   }

   if(g_smcds.phase == SMCDS_IDLE || g_smcds.phase == SMCDS_BOS_BULL)
   {
      double bosLvl = 0;
      datetime bosT = 0;
      if(SMCDS_DetectBullBOS(symbol, tf, bosLvl, bosT))
      {
         g_smcds.bosLevel = bosLvl;
         g_smcds.bosTime = bosT;
         g_smcds.startBar = iBars(symbol, tf);
         SMCDS_SetPhase(SMCDS_BOS_BULL, symbol);
      }
   }

   if(g_smcds.phase == SMCDS_BOS_BULL)
   {
      double hi = 0, lo = 0, peak = 0;
      if(SMCDS_DetectBearOB(symbol, tf, g_smcds.bosTime, hi, lo, peak))
      {
         g_smcds.obHigh = hi;
         g_smcds.obLow = lo;
         g_smcds.peakHigh = peak;
         SMCDS_SetPhase(SMCDS_OB_BEAR, symbol);
      }
   }

   if(g_smcds.phase == SMCDS_OB_BEAR)
   {
      double shift = 0;
      if(SMCDS_DetectMarketShift(symbol, tf, g_smcds.obLow, shift))
      {
         g_smcds.shiftLevel = shift;
         SMCDS_SetPhase(SMCDS_MARKET_SHIFT, symbol);
      }
   }

   if(g_smcds.phase == SMCDS_MARKET_SHIFT)
   {
      double indHi = 0;
      if(SMCDS_DetectInducement(symbol, tf, g_smcds.obHigh, g_smcds.shiftLevel, indHi))
      {
         g_smcds.inducementHigh = indHi;
         SMCDS_SetPhase(SMCDS_INDUCEMENT, symbol);
      }
      else if(SMCDS_DetectOBRetest(symbol, tf, g_smcds.obHigh, g_smcds.obLow))
      {
         SMCDS_FindSSLTarget(symbol, tf, g_smcds.sslTarget);
         SMCDS_SetPhase(SMCDS_ENTRY_READY, symbol);
      }
   }

   if(g_smcds.phase == SMCDS_INDUCEMENT)
   {
      if(SMCDS_DetectOBRetest(symbol, tf, g_smcds.obHigh, g_smcds.obLow))
      {
         SMCDS_FindSSLTarget(symbol, tf, g_smcds.sslTarget);
         SMCDS_SetPhase(SMCDS_ENTRY_READY, symbol);
      }
   }
}

bool SMCDS_IsEntryReady(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!UseBearDistributionSetup) return false;
   if(tf != BearDistTF && tf != PERIOD_M1 && tf != PERIOD_H1) return false;
   if(g_smcds.phase != SMCDS_ENTRY_READY) return false;
   if(g_smcds.obHigh <= 0 || g_smcds.obLow <= 0) return false;

   if(BearDistRequireGOM && UseGOMVerdictFilter)
   {
      if(MathAbs(g_smcGomVerdictNum) < 2) return false;
      if(g_smcGomVerdictNum > -2) return false;
   }

   return SMCDS_DetectOBRetest(symbol, tf, g_smcds.obHigh, g_smcds.obLow);
}

double SMCDS_EntryLevel()
{
   return (g_smcds.obLow > 0) ? g_smcds.obLow : 0;
}

double SMCDS_StopLevel()
{
   return (g_smcds.obHigh > 0) ? g_smcds.obHigh : 0;
}

double SMCDS_TakeProfitLevel()
{
   return g_smcds.sslTarget;
}

string SMCDS_GetSummary()
{
   if(g_smcds.phase == SMCDS_IDLE) return "";
   string s = "BearDist:" + SMCDS_PhaseName(g_smcds.phase);
   if(g_smcds.obHigh > 0)
      s += StringFormat(" OB=%.2f-%.2f", g_smcds.obLow, g_smcds.obHigh);
   return s;
}

void SMCDS_ClearDrawings()
{
   ObjectsDeleteAll(0, "SMCDS_");
}

void SMCDS_DrawOnChart(const string symbol)
{
   if(!BearDistDrawOnChart || !UseBearDistributionSetup) return;
   SMCDS_ClearDrawings();

   if(g_smcds.phase == SMCDS_IDLE) return;

   string panel = "SMCDS_PANEL";
   ObjectCreate(0, panel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, panel, OBJPROP_YDISTANCE, 145);
   ObjectSetString(0, panel, OBJPROP_TEXT, SMCDS_GetSummary());
   ObjectSetInteger(0, panel, OBJPROP_COLOR,
      (g_smcds.phase == SMCDS_ENTRY_READY) ? clrLime : clrOrange);
   ObjectSetInteger(0, panel, OBJPROP_FONTSIZE, 9);

   if(g_smcds.obHigh > 0 && g_smcds.obLow > 0)
   {
      datetime t1 = iTime(symbol, BearDistTF, 30);
      datetime t2 = iTime(symbol, BearDistTF, 0) + PeriodSeconds(BearDistTF) * 5;
      double zH = MathMax(g_smcds.obHigh, g_smcds.obLow);
      double zL = MathMin(g_smcds.obHigh, g_smcds.obLow);

      string obName = "SMCDS_OB";
      ObjectCreate(0, obName, OBJ_RECTANGLE, 0, t1, zH, t2, zL);
      ObjectSetInteger(0, obName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, obName, OBJPROP_FILL, true);
      ObjectSetInteger(0, obName, OBJPROP_BACK, true);
      ObjectSetInteger(0, obName, OBJPROP_WIDTH, 1);

      if(g_smcds.phase == SMCDS_ENTRY_READY)
      {
         string slName = "SMCDS_SL";
         ObjectCreate(0, slName, OBJ_HLINE, 0, 0, zH + SMCDS_ATR(symbol, BearDistTF) * 0.1);
         ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DASH);

         if(g_smcds.sslTarget > 0)
         {
            string tpName = "SMCDS_SSL";
            ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, g_smcds.sslTarget);
            ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DOT);
         }
      }
   }
}

#endif // SMC_BEAR_DISTRIBUTION_SETUP_MQH
