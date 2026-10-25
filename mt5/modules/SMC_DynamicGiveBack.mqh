//+------------------------------------------------------------------+
//| SMC_DynamicGiveBack_v2.mqh — Profit Preservation Guard
//| Tick-by-tick peakProfit tracking + dynamic SL adjustment
//|
//| HOTFIX 2026-09-15 (v1.20)
//|  - Dès peak >= 0.50$ : lock armé, SL protège au moins 0.20$
//|  - Si peak >= 0.50$ et profit redescend < 0.20$ → CLOSE forcé
//|  - Soft warning 20%, hard exit 40% de giveback
//|  - GOOD/PERFECT: max 25% | SIMPLE: max 35%
//|
//| HOTFIX 2026-09-15 (v1.21)
//|  - FIX: Ne ferme PAS les positions si GOM verdict = WAIT (vn=0)
//|  - Ajout vérification g_smcGomVerdictNum avant fermeture
//|
//| AUCUN input ici — tous déclarés dans SMC_Universal.mq5
//+------------------------------------------------------------------+
#ifndef SMC_DYNAMIC_GIVEBACK_V2_MQH
#define SMC_DYNAMIC_GIVEBACK_V2_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

// Extern globals from main EA
extern int    g_smcGomVerdictNum;
extern bool   g_smcGomConnected;

// Floor absolu (si non exposé en input)
#ifndef GiveBackFloorUSD
#define GiveBackFloorUSD 0.20
#endif

//--- Local tracking per ticket
struct GiveBackTracker
{
   ulong    ticket;
   string   symbol;
   double   peakProfit;
   double   entryPrice;
   datetime lastUpdate;
   bool     softWarningFired;
   bool     goodOrPerfectVerdict;
   int      verdictNum;
   bool     lockArmed;
};

GiveBackTracker g_giveBackTrackers[];
int g_giveBackTrackerCount = 0;

SMC_GatedTrade g_giveBackTrade;
CPositionInfo g_giveBackPosInfo;

// Prototype (AUDIT C5): GiveBack_RegisterPosition est défini plus bas mais
// appelé par SMC_ManageDynamicGiveBack → déclaration anticipée.
void GiveBack_RegisterPosition(ulong ticket, bool isGoodOrPerfect, int verdictNum);

//+------------------------------------------------------------------+
int GiveBack_FindOrAdd(ulong ticket, bool isGoodOrPerfect, int verdictNum)
{
   for(int i = 0; i < g_giveBackTrackerCount; i++)
   {
      if(g_giveBackTrackers[i].ticket == ticket)
         return i;
   }

   int idx = g_giveBackTrackerCount;
   g_giveBackTrackerCount++;
   ArrayResize(g_giveBackTrackers, g_giveBackTrackerCount);

   GiveBackTracker gbt;
   gbt.ticket              = ticket;
   gbt.symbol              = "";
   gbt.peakProfit          = 0.0;
   gbt.entryPrice          = 0.0;
   gbt.lastUpdate          = 0;
   gbt.softWarningFired    = false;
   gbt.goodOrPerfectVerdict= isGoodOrPerfect;
   gbt.verdictNum          = verdictNum;
   gbt.lockArmed           = false;

   g_giveBackTrackers[idx] = gbt;
   return idx;
}

//+------------------------------------------------------------------+
void GiveBack_Remove(int idx)
{
   if(idx < 0 || idx >= g_giveBackTrackerCount) return;
   for(int i = idx; i < g_giveBackTrackerCount - 1; i++)
      g_giveBackTrackers[i] = g_giveBackTrackers[i + 1];
   g_giveBackTrackerCount--;
   ArrayResize(g_giveBackTrackers, g_giveBackTrackerCount);
}

//+------------------------------------------------------------------+
void GiveBack_Log(const string msg)
{
   if(EnableGiveBackWarningLog)
      Print("[GIVEBACK] ", msg);
}

//+------------------------------------------------------------------+
void SMC_ManageDynamicGiveBack()
{
   if(!UseAggressiveGiveBackCheck) return;

   // ── AUDIT C5: auto-enregistrement — GiveBack_RegisterPosition n'étant
   // jamais appelé par les modules d'entrée, le tracker restait vide et la
   // garde était inerte. On enregistre ici chaque position du magic.
   for(int pi = PositionsTotal() - 1; pi >= 0; pi--)
   {
      if(!g_giveBackPosInfo.SelectByIndex(pi)) continue;
      if(g_giveBackPosInfo.Magic() != InpMagicNumber) continue;

      ulong pticket = g_giveBackPosInfo.Ticket();
      bool registered = false;
      for(int qi = 0; qi < g_giveBackTrackerCount; qi++)
      {
         if(g_giveBackTrackers[qi].ticket == pticket) { registered = true; break; }
      }
      if(!registered)
      {
         bool isGP = (g_smcGomConnected) ? (MathAbs(g_smcGomVerdictNum) >= 2) : true;
         GiveBack_RegisterPosition(pticket, isGP, g_smcGomVerdictNum);
      }
   }

   for(int i = g_giveBackTrackerCount - 1; i >= 0; i--)
   {
      ulong ticket = g_giveBackTrackers[i].ticket;

      if(!PositionSelectByTicket(ticket))
      {
         GiveBack_Remove(i);
         continue;
      }

      string symbol        = PositionGetString(POSITION_SYMBOL);
      int    posType       = (int)PositionGetInteger(POSITION_TYPE);
      double entryPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double bid           = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask           = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double sl            = PositionGetDouble(POSITION_SL);
      double tp            = PositionGetDouble(POSITION_TP);

      g_giveBackTrackers[i].symbol = symbol;
      if(g_giveBackTrackers[i].entryPrice == 0.0)
         g_giveBackTrackers[i].entryPrice = entryPrice;

      // Peak update
      if(currentProfit > g_giveBackTrackers[i].peakProfit)
      {
         g_giveBackTrackers[i].peakProfit = currentProfit;
         g_giveBackTrackers[i].softWarningFired = false;
      }

      // Armer dès peak >= seuil
      if(g_giveBackTrackers[i].peakProfit >= GiveBackMinPeakActivate)
         g_giveBackTrackers[i].lockArmed = true;

      if(g_giveBackTrackers[i].peakProfit < GiveBackMinPeakActivate && !g_giveBackTrackers[i].lockArmed)
         continue;

      // ═══ FORCE FLOOR : peak >= seuil et profit < floor → CLOSE ═══
      // FIX v1.21: Ne pas fermer si GOM verdict = WAIT (vn=0)
      // FIX v1.29: Floor plus élevé pour FXVOL/commodities ($0.50 au lieu de $0.20)
      double floorUSD = GiveBackFloorUSD;
      string symCat = PositionGetString(POSITION_SYMBOL);
      // Détection FXVOL/commodities par nom de symbole
      bool isFxVolComm = (StringFind(symCat, "VOL") >= 0 || 
                         StringFind(symCat, "XAU") >= 0 || 
                         StringFind(symCat, "XAG") >= 0 ||
                         StringFind(symCat, "BTC") >= 0);
      if(isFxVolComm) floorUSD = 0.50; // $0.50 minimum pour FXVOL/commodities - AUGMENTÉ v1.29
      
      if(g_giveBackTrackers[i].lockArmed && currentProfit < floorUSD)
      {
         // FIX v1.21: Ne pas fermer si GOM verdict = WAIT (vn=0)
         if(g_smcGomConnected && g_smcGomVerdictNum == 0)
         {
            // GOM WAIT: ne pas fermer, laisser le SL faire son travail
            GiveBack_Log(StringFormat(
               "⏸️ FLOOR CLOSE BLOCKED by GOM WAIT #%llu %s | Peak: $%.2f → Current: $%.2f",
               ticket, symbol,
               g_giveBackTrackers[i].peakProfit, currentProfit));
            continue;
         }
         
         GiveBack_Log(StringFormat(
            "🔒 FLOOR CLOSE #%llu %s | Peak: $%.2f → Current: $%.2f < Floor $%.2f",
            ticket, symbol,
            g_giveBackTrackers[i].peakProfit, currentProfit, GiveBackFloorUSD));
         if(g_giveBackTrade.PositionClose(ticket))
         {
            GiveBack_Log(StringFormat("✅ Closed #%llu via floor (peak was $%.2f)",
               ticket, g_giveBackTrackers[i].peakProfit));
            GiveBack_Remove(i);
         }
         else
            GiveBack_Log(StringFormat("❌ Failed close #%llu | Error: %d", ticket, GetLastError()));
         continue;
      }

      // Giveback %
      double currentGivebackPct = 0.0;
      if(g_giveBackTrackers[i].peakProfit > 0.001)
      {
         currentGivebackPct = (1.0 - (currentProfit / g_giveBackTrackers[i].peakProfit)) * 100.0;
         if(currentGivebackPct < 0.0) currentGivebackPct = 0.0;
      }

      double maxGivebackPct = g_giveBackTrackers[i].goodOrPerfectVerdict
                              ? GiveBackMaxPctGoodPerfect
                              : GiveBackMaxPctSimple;

      // Soft warning
      if(currentGivebackPct >= GiveBackSoftWarningPct && !g_giveBackTrackers[i].softWarningFired)
      {
         g_giveBackTrackers[i].softWarningFired = true;
         GiveBack_Log(StringFormat(
            "⚠️ SOFT WARNING #%llu %s | Peak: $%.2f → Current: $%.2f | Giveback: %.1f%% (%s)",
            ticket, symbol,
            g_giveBackTrackers[i].peakProfit, currentProfit, currentGivebackPct,
            g_giveBackTrackers[i].goodOrPerfectVerdict ? "GOOD/PERFECT" : "SIMPLE"));
      }

      // Hard exit
      if(currentGivebackPct >= GiveBackHardExitPct)
      {
         // FIX v1.21: Ne pas fermer si GOM verdict = WAIT (vn=0)
         if(g_smcGomConnected && g_smcGomVerdictNum == 0)
         {
            // GOM WAIT: ne pas fermer, laisser le SL faire son travail
            GiveBack_Log(StringFormat(
               "⏸️ HARD EXIT BLOCKED by GOM WAIT #%llu %s | Peak: $%.2f → Current: $%.2f | Giveback: %.1f%%",
               ticket, symbol,
               g_giveBackTrackers[i].peakProfit, currentProfit,
               currentGivebackPct));
            continue;
         }
         
         GiveBack_Log(StringFormat(
            "🔴 HARD EXIT #%llu %s | Peak: $%.2f → Current: $%.2f | Giveback: %.1f%% >= %.1f%%",
            ticket, symbol,
            g_giveBackTrackers[i].peakProfit, currentProfit,
            currentGivebackPct, GiveBackHardExitPct));
         if(g_giveBackTrade.PositionClose(ticket))
         {
            GiveBack_Log(StringFormat("✅ Closed #%llu via hard exit", ticket));
            GiveBack_Remove(i);
         }
         else
            GiveBack_Log(StringFormat("❌ Failed close #%llu | Error: %d", ticket, GetLastError()));
         continue;
      }

      // Dynamic SL resserrage
      if(currentGivebackPct >= maxGivebackPct - 5.0)
      {
         double minProfitToKeep = g_giveBackTrackers[i].peakProfit * (1.0 - maxGivebackPct / 100.0);
         if(minProfitToKeep < GiveBackFloorUSD)
            minProfitToKeep = GiveBackFloorUSD;

         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double dist = 0.0;
         if(tickSize > 0.0 && tickValue > 0.0 && volume > 0.0)
            dist = (minProfitToKeep * tickSize) / (tickValue * volume);

         if(dist > 0.0)
         {
            double newSL = 0.0;
            if(posType == 0)  // BUY
            {
               newSL = NormalizeDouble(entryPrice + dist, digits);
               newSL = MathMax(newSL, entryPrice);
            }
            else
            {
               newSL = NormalizeDouble(entryPrice - dist, digits);
               newSL = MathMin(newSL, entryPrice);
            }

            bool needModify = false;
            if(posType == 0 && (sl == 0.0 || newSL > sl)) needModify = true;
            if(posType == 1 && (sl == 0.0 || newSL < sl)) needModify = true;

            long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double minDist = (double)stopsLevel * point;
            if(minDist <= 0.0) minDist = point * 5.0;
            if(posType == 0 && newSL >= bid - minDist) needModify = false;
            if(posType == 1 && newSL <= ask + minDist) needModify = false;

            if(needModify && newSL != sl)
            {
               if(g_giveBackTrade.PositionModify(ticket, newSL, tp))
               {
                  GiveBack_Log(StringFormat(
                     "🛡️ SL Adjusted #%llu | %s | OldSL: %.5f → NewSL: %.5f | Protect $%.2f",
                     ticket, posType == 0 ? "BUY" : "SELL", sl, newSL, minProfitToKeep));
               }
            }
         }
      }

      g_giveBackTrackers[i].lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
void GiveBack_RegisterPosition(ulong ticket, bool isGoodOrPerfect, int verdictNum)
{
   int idx = GiveBack_FindOrAdd(ticket, isGoodOrPerfect, verdictNum);
   if(idx >= 0)
   {
      GiveBack_Log(StringFormat(
         "📌 Registered #%llu | %s | VerdictNum: %d",
         ticket, isGoodOrPerfect ? "GOOD/PERFECT" : "SIMPLE", verdictNum));
   }
}

//+------------------------------------------------------------------+
void GiveBack_Cleanup()
{
   if(g_giveBackTrackerCount > 0)
   {
      GiveBack_Log(StringFormat("Cleanup: %d trackers cleared", g_giveBackTrackerCount));
      g_giveBackTrackerCount = 0;
      ArrayResize(g_giveBackTrackers, 0);
   }
}

#endif // SMC_DYNAMIC_GIVEBACK_V2_MQH
