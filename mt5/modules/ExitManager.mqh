//+------------------------------------------------------------------+
//| ExitManager.mqh - Unified exit logic                              |
//| All inputs come from main EA — NO input declarations here         |
//+------------------------------------------------------------------+
#ifndef SMC_EXIT_MANAGER_MQH
#define SMC_EXIT_MANAGER_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include "SMC_BoomCrashStrategy.mqh"  // Pour second spike prediction

//--- Forward declarations from main EA (inputs/globals are accessible via include order)
extern bool     SMC_IsGoldProfileActive();
extern void     SMC_ReportTradeClose(const string symbol, double netProfit, bool isWin);

//--- Local state
struct ExitPosition
{
   ulong            ticket;
   string           symbol;
   double           entryPrice;
   double           slDistance;
   int              partialState;   // 0=none, 1=TP1, 2=TP2, 3=TP3
   double           maxFavorable;
   double           invalidationLevel;
   double           confirmationLevel;
   datetime         lastUpdate;
   bool             thesisConfirmed;
   bool             hasRealSL;
   double           peakProfit;
   datetime         stagnationZoneSince;
   datetime         stagnationLastPeakTime;
   bool             stagnationArmed;
   bool             givebackArmed;
};

ExitPosition g_exitPositions[];
int g_exitCount = 0;
CTrade g_exitTrade;
CPositionInfo g_exitPosInfo;

//+------------------------------------------------------------------+
//| Helper: Position net P/L                                         |
//+------------------------------------------------------------------+
double ExitMgr_PositionPL(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0.0;
   return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
}

//+------------------------------------------------------------------+
//| Helper: Position age in seconds                                  |
//+------------------------------------------------------------------+
int ExitMgr_PositionAgeSec(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   return (int)(TimeCurrent() - openTime);
}

//+------------------------------------------------------------------+
//| Helper: Safe close with log                                      |
//+------------------------------------------------------------------+
bool ExitMgr_Close(ulong ticket, string reason)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string sym = PositionGetString(POSITION_SYMBOL);
   double pl = ExitMgr_PositionPL(ticket);

   if(g_exitTrade.PositionClose(ticket))
   {
      Print("[EXIT] ", reason, " | ", sym, " #", ticket, " P/L=", DoubleToString(pl, 2), "$");
      return true;
   }
   Print("[EXIT] FAILED ", reason, " | ", sym, " #", ticket, " err=", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Find or create tracked position                                  |
//+------------------------------------------------------------------+
int ExitMgr_FindOrAdd(ulong ticket)
{
   for(int i = 0; i < g_exitCount; i++)
   {
      if(g_exitPositions[i].ticket == ticket) return i;
   }

   int idx = g_exitCount;
   g_exitCount++;
   ArrayResize(g_exitPositions, g_exitCount);

   ExitPosition ep;
   ep.ticket = ticket;
   ep.symbol = "";
   ep.entryPrice = 0;
   ep.slDistance = 0;
   ep.partialState = 0;
   ep.maxFavorable = 0;
   ep.invalidationLevel = 0;
   ep.confirmationLevel = 0;
   ep.lastUpdate = 0;
   ep.thesisConfirmed = false;
   ep.hasRealSL = false;
   ep.peakProfit = 0;
   ep.stagnationZoneSince = 0;
   ep.stagnationLastPeakTime = 0;
   ep.stagnationArmed = false;
   ep.givebackArmed = false;
   g_exitPositions[idx] = ep;

   return idx;
}

//+------------------------------------------------------------------+
//| Clean stale entries                                              |
//+------------------------------------------------------------------+
void ExitMgr_CleanStale()
{
   for(int i = g_exitCount - 1; i >= 0; i--)
   {
      if(g_exitPositions[i].ticket == 0) continue;
      if(!PositionSelectByTicket(g_exitPositions[i].ticket))
      {
         g_exitPositions[i].ticket = 0;
         g_exitPositions[i].symbol = "";
      }
   }
}

//+------------------------------------------------------------------+
//| Track new position                                               |
//+------------------------------------------------------------------+
void ExitMgr_TrackPosition(ulong ticket, string symbol, double entryPrice, double slPrice, bool realSL)
{
   int idx = ExitMgr_FindOrAdd(ticket);

   double slDist = MathAbs(entryPrice - slPrice);
   if(slDist <= 0) slDist = 0.001;

   g_exitPositions[idx].symbol = symbol;
   g_exitPositions[idx].entryPrice = entryPrice;
   g_exitPositions[idx].slDistance = slDist;
   g_exitPositions[idx].partialState = 0;
   g_exitPositions[idx].maxFavorable = 0;
   g_exitPositions[idx].thesisConfirmed = false;
   g_exitPositions[idx].hasRealSL = realSL;
   g_exitPositions[idx].lastUpdate = TimeCurrent();
   g_exitPositions[idx].peakProfit = 0;
   g_exitPositions[idx].stagnationArmed = false;
   g_exitPositions[idx].givebackArmed = false;

   bool isBuy = (slPrice < entryPrice);
   if(isBuy)
   {
      g_exitPositions[idx].invalidationLevel = entryPrice - slDist * MathAbs(ExtThesisInvalidRR);
      g_exitPositions[idx].confirmationLevel = entryPrice + slDist * ExtThesisConfirmRR;
   }
   else
   {
      g_exitPositions[idx].invalidationLevel = entryPrice + slDist * MathAbs(ExtThesisInvalidRR);
      g_exitPositions[idx].confirmationLevel = entryPrice - slDist * ExtThesisConfirmRR;
   }

   Print(StringFormat("[EXIT] Track #%d %s EP=%.5f SL=%.5f", ticket, symbol, entryPrice, slPrice));
}

//+------------------------------------------------------------------+
//| Continuation strength score (0-100)                              |
//+------------------------------------------------------------------+
double ExitMgr_ContinuationScore(string symbol, int direction)
{
   double score = 0.0;

   // GOM Verdict (40 pts)
   int vn = g_smcGomVerdictNum;
   bool gomAligned = (direction > 0 && vn >= 2) || (direction < 0 && vn <= -2);
   if(gomAligned)
      score += (MathAbs(vn) == 3) ? 40.0 : 30.0;
   else if(vn != 0)
      score += 5.0;

   // COG Direction (30 pts)
   bool cogAligned = (direction > 0 && g_cogDirection == "BUY") || (direction < 0 && g_cogDirection == "SELL");
   if(cogAligned) score += 30.0;
   else if(g_cogDirection == "NEUTRAL") score += 10.0;

   // IA Confidence (30 pts)
   if(g_iaStatusConfidence >= 80.0) score += 30.0;
   else if(g_iaStatusConfidence >= 65.0) score += 20.0;
   else if(g_iaStatusConfidence >= 50.0) score += 10.0;

   return score;
}

//+------------------------------------------------------------------+
//| PARTIAL CLOSE LOGIC                                              |
//+------------------------------------------------------------------+
bool ExitMgr_ProcessPartialClose(ulong ticket)
{
   if(!ExtUsePartialClose) return false;
   if(!g_exitPosInfo.SelectByTicket(ticket)) return false;
   if(g_exitPosInfo.Magic() != InpMagicNumber) return false;
   if(SMC_IsGoldProfileActive() && g_exitPosInfo.Symbol() == _Symbol) return false;

   int idx = ExitMgr_FindOrAdd(ticket);

   double curPrice = g_exitPosInfo.PriceCurrent();
   double openPrice = g_exitPositions[idx].entryPrice;
   double slDist = g_exitPositions[idx].slDistance;
   if(slDist <= 0) return false;

   bool isBuy = (g_exitPosInfo.PositionType() == POSITION_TYPE_BUY);
   double profit = g_exitPosInfo.Profit() + g_exitPosInfo.Swap() + g_exitPosInfo.Commission();
   double volume = g_exitPosInfo.Volume();
   string symbol = g_exitPosInfo.Symbol();

   if(profit > g_exitPositions[idx].maxFavorable)
      g_exitPositions[idx].maxFavorable = profit;

   bool modified = false;

   //--- Thesis confirmation
   if(!g_exitPositions[idx].thesisConfirmed)
   {
      bool confirmed = isBuy ? (curPrice >= g_exitPositions[idx].confirmationLevel)
                             : (curPrice <= g_exitPositions[idx].confirmationLevel);
      if(confirmed)
      {
         g_exitPositions[idx].thesisConfirmed = true;
         Print(StringFormat("[EXIT] Theses CONFIRMED #%d %s at %.5f", ticket, symbol, curPrice));
      }
   }

   //--- Thesis invalidation: early exit
   if(ExtUseThesisInvalidation && !g_exitPositions[idx].thesisConfirmed && g_exitPositions[idx].hasRealSL)
   {
      bool invalidated = isBuy ? (curPrice <= g_exitPositions[idx].invalidationLevel)
                               : (curPrice >= g_exitPositions[idx].invalidationLevel);
      if(invalidated && g_exitPositions[idx].maxFavorable < ExtMinProfitUSD)
      {
         if(g_exitPosInfo.SelectByTicket(ticket))
         {
            if(g_exitTrade.PositionClose(ticket))
            {
               Print(StringFormat("[EXIT] THESIS INVALID early close #%d %s at %.5f (loss %.2f$)",
                     ticket, symbol, curPrice, profit));
            }
            SMC_ReportTradeClose(symbol, profit, false);
            g_exitPositions[idx].ticket = 0;
            return true;
         }
      }
   }

   //--- Need minimum profit before partial close
   if(profit < ExtMinProfitUSD)
   {
      g_exitPositions[idx].lastUpdate = TimeCurrent();
      return false;
   }

   // Calculate current RR
   double currentRR = isBuy ? ((curPrice - openPrice) / slDist) : ((openPrice - curPrice) / slDist);
   if(currentRR < 0) currentRR = 0;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   //--- TP1: partial close
   if(g_exitPositions[idx].partialState == 0 && currentRR >= ExtPartialTP1_RR)
   {
      double closeVol = volume * (ExtPartialTP1_Pct / 100.0);
      closeVol = MathMax(minLot, MathFloor(closeVol / stepLot) * stepLot);

      if(closeVol >= minLot)
      {
         if(g_exitTrade.PositionClosePartial(ticket, closeVol))
         {
            g_exitPositions[idx].partialState = 1;
            modified = true;

            // Move SL to breakeven
            double beSL = NormalizeDouble(openPrice, digits);
            double minStop = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
            bool slOk = isBuy ? (beSL < curPrice - minStop) : (beSL > curPrice + minStop);
            if(slOk && PositionSelectByTicket(ticket))
               g_exitTrade.PositionModify(ticket, beSL, g_exitPosInfo.TakeProfit());

            Print(StringFormat("[EXIT] TP1 PARTIAL #%d %s | %.2f lots at RR=%.1f | SL to BE",
                  ticket, symbol, closeVol, ExtPartialTP1_RR));
         }
      }
   }

   //--- TP2: partial close
   if(g_exitPositions[idx].partialState == 1 && currentRR >= ExtPartialTP2_RR)
   {
      if(!g_exitPosInfo.SelectByTicket(ticket)) { g_exitPositions[idx].lastUpdate = TimeCurrent(); return modified; }
      double remaining = g_exitPosInfo.Volume();
      double closeVol = remaining * (ExtPartialTP2_Pct / (ExtPartialTP2_Pct + ExtPartialTP3_Pct));
      closeVol = MathMax(minLot, MathFloor(closeVol / stepLot) * stepLot);

      if(closeVol >= minLot)
      {
         if(g_exitTrade.PositionClosePartial(ticket, closeVol))
         {
            g_exitPositions[idx].partialState = 2;
            modified = true;
            Print(StringFormat("[EXIT] TP2 PARTIAL #%d %s | %.2f lots at RR=%.1f",
                  ticket, symbol, closeVol, ExtPartialTP2_RR));
         }
      }
   }

   //--- Continuation check after TP2
   if(g_exitPositions[idx].partialState == 2)
   {
      int direction = isBuy ? 1 : -1;
      double contScore = ExitMgr_ContinuationScore(symbol, direction);

      if(contScore < ExtMinContinuationScore)
      {
         if(g_exitPosInfo.SelectByTicket(ticket))
         {
            double remaining = g_exitPosInfo.Volume();
            if(remaining >= minLot)
            {
               if(g_exitTrade.PositionClosePartial(ticket, remaining))
               {
                  g_exitPositions[idx].partialState = 3;
                  modified = true;
                  Print(StringFormat("[EXIT] CONTINUATION WEAK #%d %s | Score=%.0f - close remaining %.2f lots",
                        ticket, symbol, contScore, remaining));
               }
            }
         }
         g_exitPositions[idx].lastUpdate = TimeCurrent();
         return modified;
      }
   }

   //--- TP3: final close
   if(g_exitPositions[idx].partialState == 2 && currentRR >= ExtPartialTP3_RR)
   {
      if(!g_exitPosInfo.SelectByTicket(ticket)) { g_exitPositions[idx].lastUpdate = TimeCurrent(); return modified; }
      double remaining = g_exitPosInfo.Volume();
      if(remaining >= minLot)
      {
         if(g_exitTrade.PositionClosePartial(ticket, remaining))
         {
            g_exitPositions[idx].partialState = 3;
            modified = true;
            Print(StringFormat("[EXIT] TP3 FINAL #%d %s | %.2f lots at RR=%.1f",
                  ticket, symbol, remaining, ExtPartialTP3_RR));
         }
      }
   }

   g_exitPositions[idx].lastUpdate = TimeCurrent();
   return modified;
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                    |
//+------------------------------------------------------------------+
void ExitMgr_ManageTrailing()
{
   if(!UseTrailingStop) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      int posType = (int)PositionGetInteger(POSITION_TYPE);
      double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(profit < TrailActivateUSD) continue;

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double currentPrice = (posType == 0) ? bid : ask;

      int idx = ExitMgr_FindOrAdd(ticket);

      if(profit > g_exitPositions[idx].peakProfit)
         g_exitPositions[idx].peakProfit = profit;

      double givebackDistance = (g_exitPositions[idx].peakProfit * TrailLockPct) / (posType == 0 ? bid : ask);
      double newSL = 0.0;

      if(posType == 0) // BUY
      {
         newSL = bid - givebackDistance;
         newSL = MathMax(newSL, posOpen);
      }
      else // SELL
      {
         newSL = ask + givebackDistance;
         newSL = MathMin(newSL, posOpen);
      }

      if((posType == 0 && newSL > sl) || (posType == 1 && newSL < sl))
         g_exitTrade.PositionModify(ticket, newSL, tp);
   }
}

//+------------------------------------------------------------------+
//| STAGNATION EXIT                                                  |
//+------------------------------------------------------------------+
void ExitMgr_ManageStagnation()
{
   if(!UseStagnationExit) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(profit < StagnationTriggerUSD)
      {
         int idx = ExitMgr_FindOrAdd(ticket);
         g_exitPositions[idx].stagnationArmed = false;
         continue;
      }

      int idx = ExitMgr_FindOrAdd(ticket);

      if(!g_exitPositions[idx].stagnationArmed)
      {
         g_exitPositions[idx].stagnationArmed = true;
         g_exitPositions[idx].stagnationZoneSince = TimeCurrent();
         g_exitPositions[idx].stagnationLastPeakTime = TimeCurrent();
         g_exitPositions[idx].peakProfit = profit;
         continue;
      }

      if(profit > g_exitPositions[idx].peakProfit)
      {
         g_exitPositions[idx].peakProfit = profit;
         g_exitPositions[idx].stagnationLastPeakTime = TimeCurrent();
         continue;
      }

      double maxGiveback = g_exitPositions[idx].peakProfit * StagnationMaxGiveback;
      double floor = g_exitPositions[idx].peakProfit - maxGiveback;

      if(profit < floor)
      {
         ExitMgr_Close(ticket, "Stagnation exit: recul > threshold");
         g_exitPositions[idx].stagnationArmed = false;
         continue;
      }

      if(TimeCurrent() - g_exitPositions[idx].stagnationLastPeakTime > StagnationHoldSec)
      {
         ExitMgr_Close(ticket, "Stagnation exit: timeout");
         g_exitPositions[idx].stagnationArmed = false;
      }
   }
}

//+------------------------------------------------------------------+
//| PROFIT GIVEBACK EXIT                                             |
//+------------------------------------------------------------------+
void ExitMgr_ManageGiveback()
{
   if(!UseProfitGiveback) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);

      int idx = ExitMgr_FindOrAdd(ticket);

      if(profit > g_exitPositions[idx].peakProfit)
         g_exitPositions[idx].peakProfit = profit;

      if(!g_exitPositions[idx].givebackArmed && profit >= ProfitGivebackArmUSD)
         g_exitPositions[idx].givebackArmed = true;

      if(g_exitPositions[idx].givebackArmed)
      {
         double maxGiveback = g_exitPositions[idx].peakProfit * MaxGivebackFromPeak;
         double floor = g_exitPositions[idx].peakProfit - maxGiveback;

         if(profit < floor)
         {
            ExitMgr_Close(ticket, "Giveback exit: peak=" + DoubleToString(g_exitPositions[idx].peakProfit, 2));
            g_exitPositions[idx].givebackArmed = false;
            g_exitPositions[idx].peakProfit = 0.0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DOLLAR EXIT - Hard max loss + profit target                      |
//+------------------------------------------------------------------+
void ExitMgr_ManageDollarExits()
{
   if(!UseDollarExits) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = ExitMgr_PositionPL(ticket);
      int ageSec = ExitMgr_PositionAgeSec(ticket);
      int posDir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;

      // Hard max loss
      if(profit <= -UniversalMaxLossUSD)
      {
         ExitMgr_Close(ticket, "Max loss " + DoubleToString(UniversalMaxLossUSD, 2) + "$");
         continue;
      }

      // Profit target (if enabled)
      if(ProfitTakeTargetUSD > 0 && profit >= ProfitTakeTargetUSD)
      {
         ExitMgr_Close(ticket, "Profit target " + DoubleToString(ProfitTakeTargetUSD, 2) + "$");
         continue;
      }

      // Boom/Crash: close if >90s without profit
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      if(cat == SYM_BOOM_CRASH && ageSec >= 90 && profit <= 0.0)
      {
         ExitMgr_Close(ticket, "BC time-exit 90s no-profit");
         continue;
      }

      // GOM WAIT: close if loss exceeds threshold
      if(symbol == _Symbol && g_smcGomVerdictNum == 0 && profit <= -GOMWaitCloseMinLoss)
      {
         ExitMgr_Close(ticket, "GOM WAIT loss " + DoubleToString(profit, 2) + "$");
         continue;
      }

      // Boom/Crash spike TP
      if(cat == SYM_BOOM_CRASH && profit >= BoomCrashSpikeTP && profit < 2.0)
      {
         // NOUVEAU: Vérifier si on doit attendre le second spike
         if(SMC_BC_ShouldWaitSecondSpike())
         {
            // Enregistrer le premier spike capturé
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            int direction = (posDir == 1) ? 1 : -1;
            SMC_SSP_RegisterFirstSpike(entryPrice, PositionGetDouble(POSITION_PRICE_CURRENT), direction);
            
            Print("[EXIT] Premier spike capturé - attente second spike | profit=", 
                  DoubleToString(profit, 2), "$ | prob second spike=", 
                  DoubleToString(SMC_SSP_GetSecondSpikeProb(), 1), "%");
            
            // Ne pas fermer la position - continuer à attendre
            continue;
         }
         
         // Si on n'attend pas le second spike, fermer normalement
         ExitMgr_Close(ticket, "BC Spike TP " + DoubleToString(profit, 2) + "$");
         
         // Réinitialiser le système de second spike après fermeture
         SMC_BC_ResetSecondSpike();
         continue;
      }
      
      // NOUVEAU: Vérifier si on attend le second spike et si le second spike est détecté
      if(cat == SYM_BOOM_CRASH && SMC_BC_ShouldWaitSecondSpike())
      {
         // Détecter un mouvement significatif qui pourrait être un second spike
         // Un second spike est caractérisé par un mouvement rapide dans la même direction
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         int direction = (posDir == 1) ? 1 : -1;
         
         // Calculer le profit total depuis l'entrée
         double totalProfit = (direction > 0) ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
         
         // Si le profit a augmenté significativement depuis le premier spike (ex: +50%)
         // on considère que c'est un second spike
         double firstSpikeProfit = SMC_SSP_GetCurrentProfit();
         if(totalProfit > firstSpikeProfit * 1.5 && totalProfit > 1.0)
         {
            SMC_BC_RegisterSecondSpike(currentPrice);
            
            Print("[EXIT] Second spike détecté - fermeture position | profit total=", 
                  DoubleToString(totalProfit, 2), "$");
            
            ExitMgr_Close(ticket, "BC Second Spike TP " + DoubleToString(totalProfit, 2) + "$");
            
            // Réinitialiser le système de second spike après fermeture
            SMC_BC_ResetSecondSpike();
            continue;
         }
         
         // Timeout: si trop de bougies depuis le premier spike, fermer quand même
         int barsSinceFirst = SMC_SSP_GetBarsSinceFirstSpike();
         if(barsSinceFirst > 15)  // 15 bougies max d'attente
         {
            Print("[EXIT] Timeout second spike - fermeture | bars=", barsSinceFirst,
                  " | profit=", DoubleToString(profit, 2), "$");
            
            ExitMgr_Close(ticket, "BC Second Spike Timeout " + DoubleToString(profit, 2) + "$");
            
            // Réinitialiser le système de second spike après fermeture
            SMC_BC_ResetSecondSpike();
            continue;
         }
      }

      // Max hold time
      if(MaxPositionHoldSec > 0 && ageSec >= MaxPositionHoldSec && profit <= 0.0)
      {
         ExitMgr_Close(ticket, "Max hold " + IntegerToString(MaxPositionHoldSec) + "s no-profit");
         continue;
      }

      // GOM direction conflict
      if(symbol == _Symbol && g_smcGomConnected && MathAbs(g_smcGomVerdictNum) >= 2)
      {
         bool gomConflict = (posDir == 1 && g_smcGomVerdictNum < 0)
                         || (posDir == -1 && g_smcGomVerdictNum > 0);
         if(gomConflict)
         {
            ExitMgr_Close(ticket, "GOM direction conflict");
            continue;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| IA HOLD CLOSE                                                    |
//+------------------------------------------------------------------+
void ExitMgr_ManageIAHold()
{
   if(!UseIAHoldClose) return;

   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   if(aiAction != "HOLD") return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;

      ExitMgr_Close(ticket, "IA HOLD");
   }
}

//+------------------------------------------------------------------+
//| IA DIRECTION CONFLICT                                            |
//+------------------------------------------------------------------+
void ExitMgr_ManageDirectionConflict()
{
   if(!UseDirectionConflictClose) return;

   string ai = g_lastAIAction;
   StringToUpper(ai);
   if(ai != "BUY" && ai != "SELL") return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool conflict = (ptype == POSITION_TYPE_SELL && ai == "BUY")
                   || (ptype == POSITION_TYPE_BUY && ai == "SELL");

      if(conflict)
         ExitMgr_Close(ticket, "Direction conflict IA=" + ai);
   }
}

//+------------------------------------------------------------------+
//| MAIN EXIT MANAGER - Called from OnTick                            |
//+------------------------------------------------------------------+
void ExitManager_Tick()
{
   ExitMgr_CleanStale();
   ExitMgr_ManageDollarExits();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      ExitMgr_ProcessPartialClose(ticket);
   }

   ExitMgr_ManageTrailing();
   ExitMgr_ManageStagnation();
   ExitMgr_ManageGiveback();
   ExitMgr_ManageIAHold();
   ExitMgr_ManageDirectionConflict();
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
void ExitManager_Init()
{
   g_exitCount = 0;
   ArrayResize(g_exitPositions, 10);
   Print("[EXIT] Manager initialized");
}

//+------------------------------------------------------------------+
//| Track new position from OrderSend                                |
//+------------------------------------------------------------------+
void ExitManager_OnPositionOpened(ulong ticket, string symbol, double entryPrice, double slPrice)
{
   ExitMgr_TrackPosition(ticket, symbol, entryPrice, slPrice, slPrice != 0);
}

#endif // SMC_EXIT_MANAGER_MQH
