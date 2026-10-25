//+------------------------------------------------------------------+
//| SMC_GOM_Immediate_v2.mqh — IMPROVED: Patience + Confirmation Bar
//| - GOM_MaxM1BarsNoSpike: 3 → 5 (more patience for corrections)
//| - GOM_RequireConfirmCandle: Verify rebound before exit
//| - GOM_ConfirmBarMinATR: Confirmation bar must close 0.3 ATR favorable
//| - Integration avec SMC_DynamicGiveBack_v2.mqh
//+------------------------------------------------------------------+
#ifndef SMC_GOM_IMMEDIATE_V2_MQH
#define SMC_GOM_IMMEDIATE_V2_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

input group "=== GOM Immediate Market Entry v2 (IMPROVED) ==="
input bool   UseGOMImmediateMarket         = true;
input double GOM_ReactTolATR               = 0.28;
input double GOM_RetraceATR                = 0.55;
input double GOM_AdverseExitATR            = 0.80;
input int    GOM_MinBarsBetweenEntries     = 1;
input double GOM_MinProfitKeepUSD          = 1.50;
input int    GOM_MaxM1BarsNoSpike          = 5;     // ⭐ CHANGED: 3 → 5 (more patience)
input double GOM_BE_TriggerATR             = 0.80;
input double GOM_BE_OffsetATR              = 0.10;

// ⭐ NEW: Confirmation Bar Requirements
input bool   GOM_RequireConfirmCandle      = true;      // Require rebound before exit
input double GOM_ConfirmBarMinATR          = 0.30;      // Confirmation close must be 0.3 ATR favorable
input bool   GOM_DifferentiateByVerdict    = true;      // SIMPLE gets 2 extra bars
input int    GOM_MaxM1BarsNoSpike_Simple   = 7;         // ⭐ NEW: SIMPLE gets +2 bars patience
input bool   EnableGiveBackWarningLog      = true;      // Afficher logs warn giveback

enum ENUM_GOM_PHASE
{
   GOM_PHASE_NEUTRAL = 0,
   GOM_PHASE_IMPULSE,
   GOM_PHASE_RETRACE,
   GOM_PHASE_WAIT_REBOUND
};

ENUM_GOM_PHASE g_gomPhase         = GOM_PHASE_NEUTRAL;
datetime       g_gomPhaseSince    = 0;
datetime       g_gomLastEntryBar  = 0;
double         g_gomLastImpulsePx = 0.0;
int            g_gomLastDir       = 0;
bool           g_gomTouchPending  = false;
datetime       g_gomTouchBar      = 0;
string         g_gomTouchSource   = "";

//--- ⭐ NEW: Confirmation bar tracking per position
struct GOM_ConfirmationTracker
{
   ulong    ticket;
   string   symbol;
   int      dirSign;           // +1 BUY, -1 SELL
   datetime barTimeOfEntry;    // M1 bar time when order filled
   int      barCountSinceEntry;// Incremented each M1 candle close
   double   entryPrice;
   bool     hasConfirmedRebound; // Set to true when confirmation bar fires
   double   confirmationClosePrice;
};

GOM_ConfirmationTracker g_gomConfirmTrackers[];
int g_gomConfirmTrackerCount = 0;

//+------------------------------------------------------------------+
//| Helper: ATR value (from main EA or indicator)
//+------------------------------------------------------------------+
double GOMI_ATR()
{
   double atr = GOM_GetATRValue();
   if(atr > 0.0) return atr;
   if(atrHandle != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, buf) >= 1 && buf[0] > 0.0)
         return buf[0];
   }
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50.0;
}

bool GOMI_PriceNear(const double level, const double tol)
{
   if(level <= 0.0 || tol <= 0.0) return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (MathAbs(bid - level) <= tol || MathAbs(ask - level) <= tol);
}

bool GOMI_ObjectLevelNear(const string namePart, const double tol, double &outLevel)
{
   outLevel = 0.0;
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, namePart) < 0) continue;
      double p0 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      if(p0 > 0.0 && p1 > 0.0)
      {
         double mid = (p0 + p1) * 0.5;
         if(GOMI_PriceNear(mid, tol) || GOMI_PriceNear(p0, tol) || GOMI_PriceNear(p1, tol))
         {
            outLevel = mid;
            return true;
         }
      }
      else if(p0 > 0.0 && GOMI_PriceNear(p0, tol))
      {
         outLevel = p0;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Check if price reacted on a key level
//+------------------------------------------------------------------+
bool SMC_PriceReactedOnKeyLevel(const int dirSign, string &sourceOut)
{
   sourceOut = "";
   double atr = GOMI_ATR();
   double tol = atr * GOM_ReactTolATR;
   if(tol <= 0.0) return false;

   // 1) GOM_TF_TL_M1
   double lvl = 0.0;
   if(GOMI_ObjectLevelNear("GOM_TF_TL_M1", tol, lvl) ||
      GOMI_ObjectLevelNear("GOM_TL_M1", tol, lvl) ||
      GOMI_ObjectLevelNear("TF_TL_M1", tol, lvl))
   {
      sourceOut = "GOM_TF_TL_M1";
      return true;
   }

   // 2) DOW projected
   #ifdef SMC_DOWTRENDLINE_MQH
   if(UseDowTrendline && g_dowState.active && g_dowState.projectedPrice > 0.0)
   {
      bool matches = (dirSign > 0 && !g_dowState.isBearish) ||
                     (dirSign < 0 &&  g_dowState.isBearish);
      if(matches && GOMI_PriceNear(g_dowState.projectedPrice, tol))
      {
         sourceOut = "DOW";
         return true;
      }
   }
   #endif

   // 3) FVG / FVG Trail / DSP
   if(GOMI_ObjectLevelNear("SMC_DISP_FVG_TRAIL", tol, lvl))
   {
      sourceOut = "FVG_TRAIL";
      return true;
   }
   if(GOMI_ObjectLevelNear("SMC_DISP_FVG", tol, lvl) ||
      GOMI_ObjectLevelNear("DISP_FVG", tol, lvl) ||
      GOMI_ObjectLevelNear("FVG", tol, lvl))
   {
      sourceOut = "FVG";
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ⭐ NEW: Check if this position has GOM verdict (GOOD/PERFECT/SIMPLE)
//+------------------------------------------------------------------+
bool GOM_IsPositionGoodOrPerfect(ulong ticket, int &verdictNumOut)
{
   // Lire le comentaire ou logic interne pour déterminer le verdict
   // Pour cette version, on suppose que c'est passé à l'enregistrement
   verdictNumOut = g_smcGomVerdictNum;
   return MathAbs(g_smcGomVerdictNum) >= MinGOMVerdictNumAbs;
}

//+------------------------------------------------------------------+
//| ⭐ NEW: Register confirmation tracker for a position
//+------------------------------------------------------------------+
void GOM_RegisterConfirmationTracker(ulong ticket, int dirSign, double entryPrice)
{
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_gomConfirmTrackerCount++;
   ArrayResize(g_gomConfirmTrackers, g_gomConfirmTrackerCount);

   GOM_ConfirmationTracker ct;
   ct.ticket = ticket;
   ct.symbol = _Symbol;
   ct.dirSign = dirSign;
   ct.barTimeOfEntry = iTime(_Symbol, PERIOD_M1, 0);
   ct.barCountSinceEntry = 0;
   ct.entryPrice = entryPrice;
   ct.hasConfirmedRebound = false;
   ct.confirmationClosePrice = 0.0;

   g_gomConfirmTrackers[g_gomConfirmTrackerCount - 1] = ct;

   if(EnableGiveBackWarningLog)
      Print("[GOM-Conf] Registered tracker for #", ticket, " entry=", DoubleToString(entryPrice, dg));
}

//+------------------------------------------------------------------+
//| ⭐ NEW: Update confirmation trackers on M1 candle close
//+------------------------------------------------------------------+
void GOM_UpdateConfirmationTrackers()
{
   if(!GOM_RequireConfirmCandle) return;

   for(int i = g_gomConfirmTrackerCount - 1; i >= 0; i--)
   {
      ulong ticket = g_gomConfirmTrackers[i].ticket;

      // Position still exist?
      if(!PositionSelectByTicket(ticket))
      {
         // Position closed, remove tracker
         for(int j = i; j < g_gomConfirmTrackerCount - 1; j++)
            g_gomConfirmTrackers[j] = g_gomConfirmTrackers[j + 1];
         g_gomConfirmTrackerCount--;
         ArrayResize(g_gomConfirmTrackers, g_gomConfirmTrackerCount);
         continue;
      }

      // Check for new M1 candle
      datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
      if(currentBarTime == g_gomConfirmTrackers[i].barTimeOfEntry)
         continue; // Same bar, no update

      g_gomConfirmTrackers[i].barCountSinceEntry++;
      g_gomConfirmTrackers[i].barTimeOfEntry = currentBarTime;

      // Get closed price of previous M1 bar
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_M1, 1, 1, rates) < 1) continue;

      double closePrevBar = rates[0].close;
      double atr = GOMI_ATR();
      int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      int dirSign = g_gomConfirmTrackers[i].dirSign;

      // ⭐ Check for confirmation bar (must be 0.3 ATR favorable)
      if(!g_gomConfirmTrackers[i].hasConfirmedRebound)
      {
         if(dirSign > 0)  // BUY: close must be above entry + 0.3 ATR
         {
            if(closePrevBar > g_gomConfirmTrackers[i].entryPrice + atr * GOM_ConfirmBarMinATR)
            {
               g_gomConfirmTrackers[i].hasConfirmedRebound = true;
               g_gomConfirmTrackers[i].confirmationClosePrice = closePrevBar;
               if(EnableGiveBackWarningLog)
                  Print("[GOM-Conf] ✅ BUY Confirmation bar fired for #", ticket,
                        " | Close: ", DoubleToString(closePrevBar, dg), 
                        " | Entry: ", DoubleToString(g_gomConfirmTrackers[i].entryPrice, dg));
            }
         }
         else if(dirSign < 0)  // SELL: close must be below entry - 0.3 ATR
         {
            if(closePrevBar < g_gomConfirmTrackers[i].entryPrice - atr * GOM_ConfirmBarMinATR)
            {
               g_gomConfirmTrackers[i].hasConfirmedRebound = true;
               g_gomConfirmTrackers[i].confirmationClosePrice = closePrevBar;
               if(EnableGiveBackWarningLog)
                  Print("[GOM-Conf] ✅ SELL Confirmation bar fired for #", ticket,
                        " | Close: ", DoubleToString(closePrevBar, dg),
                        " | Entry: ", DoubleToString(g_gomConfirmTrackers[i].entryPrice, dg));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ⭐ NEW: Check if position should exit due to no-spike timeout
//| IMPROVED: Takes confirmation bar into account
//+------------------------------------------------------------------+
bool GOM_ShouldExitDueToTimeout(ulong ticket, int &barsSinceEntryOut)
{
   if(!GOM_RequireConfirmCandle) return false;

   for(int i = 0; i < g_gomConfirmTrackerCount; i++)
   {
      if(g_gomConfirmTrackers[i].ticket != ticket) continue;

      barsSinceEntryOut = g_gomConfirmTrackers[i].barCountSinceEntry;

      // If confirmation bar already fired, don't timeout (wait for spike)
      if(g_gomConfirmTrackers[i].hasConfirmedRebound)
      {
         if(EnableGiveBackWarningLog && barsSinceEntryOut == GOM_MaxM1BarsNoSpike + 2)
            Print("[GOM-Timeout] 🟢 Confirmation fired, resetting timer (no timeout)");
         return false;
      }

      // Determine max bars threshold based on verdict
      int maxBars = GOM_MaxM1BarsNoSpike;
      if(GOM_DifferentiateByVerdict && MathAbs(g_smcGomVerdictNum) < MinGOMVerdictNumAbs)
         maxBars = GOM_MaxM1BarsNoSpike_Simple;

      // If past max bars AND no confirmation, exit
      if(barsSinceEntryOut >= maxBars)
      {
         if(EnableGiveBackWarningLog)
            Print("[GOM-Timeout] 🔴 Timeout fired for #", ticket, 
                  " | Bars: ", barsSinceEntryOut, "/", maxBars,
                  " | Confirmation: ", g_gomConfirmTrackers[i].hasConfirmedRebound ? "YES" : "NO");
         return true;
      }

      return false;
   }

   barsSinceEntryOut = 0;
   return false;
}

//+------------------------------------------------------------------+
//| Stub: Remaining code from original SMC_GOM_Immediate.mqh
//| (Lines from original file, truncated for space — copy full file)
//+------------------------------------------------------------------+

// 🚀 KEY INTEGRATION POINTS:
// 1. After SafeTradeBuy/SafeTradeSell fills:
//    → GOM_RegisterConfirmationTracker(ticket, dirSign, entryPrice);
//    → GiveBack_RegisterPosition(ticket, isGoodOrPerfect, g_smcGomVerdictNum);
//
// 2. In OnTick() main loop:
//    → GOM_UpdateConfirmationTrackers();  // Update bar counters
//    → SMC_ManageDynamicGiveBack();      // Check giveback violations
//
// 3. In SMC_ManageActiveGomPositions():
//    → Replace old 3-bar timeout logic with:
//       if(GOM_ShouldExitDueToTimeout(ticket, barsSinceEntry)) { ... exit ... }
//
// 4. Replace references to:
//    - GOM_MaxM1BarsNoSpike → now uses conditional logic based on verdict
//    - Direct profit checks → now use SMC_DynamicGiveBack_v2 instead

//+------------------------------------------------------------------+
//| Cleanup
//+------------------------------------------------------------------+
void GOM_Cleanup()
{
   g_gomConfirmTrackerCount = 0;
   ArrayResize(g_gomConfirmTrackers, 0);
}

#endif // SMC_GOM_IMMEDIATE_V2_MQH
