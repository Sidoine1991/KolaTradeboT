//+------------------------------------------------------------------+
//| SMC_DynamicDollarSL.mqh                                           |
//| SL dynamique en dollars pour TOUTES les positions de l'EA         |
//|                                                                   |
//| HOTFIX 2026-09-15 (v1.20):                                        |
//|  - Bug: lockStartUSD = max(0.50, plannedReward*20%) retardait le  |
//|    verrouillage → un gain déjà à +0.50$ pouvait retomber en perte |
//|  - Fix: seuil de démarrage FIXE à DynSL_StartLockUSD (0.50$)      |
//|  - Peak profit par ticket : à partir de 0.50$, lock >=70% du pic  |
//|  - Si le prix traverse le plancher cible avant activation du SL,   |
//|    fermeture marché de secours (indépendante du verdict GOM)      |
//| - Le SL ne recule jamais une fois le verrouillage arme            |
//|                                                                   |
//| HOTFIX 2026-09-15 (v1.21):                                        |
//| 1) Perte max : le seuil global USD prime sur DynSL_MaxLossUSD     |
//| 2) Dès +0.50 $ au pic → SL cible protégeant au moins 70% du pic   |
//| 3) Filet marché au plancher cible si le SL n'a pas pu être posé   |
//+------------------------------------------------------------------+
#ifndef SMC_DYNAMIC_DOLLAR_SL_MQH
#define SMC_DYNAMIC_DOLLAR_SL_MQH

// Extern globals from main EA
extern CPositionInfo posInfo;
extern bool PositionCloseWithLog(ulong ticket, string reason = "", bool forceClose = false);

input group "=== Dynamic Dollar SL (toutes positions) ==="
input bool   UseDynamicDollarSL      = true;  // FIX v1.35: SL dynamique ON (sécuriser le profit)
input double DynSL_MaxLossUSD        = 3.00;  // Plafond local; le cap global peut être plus bas ($)
input double DynSL_StartLockUSD      = 0.50;  // Valeur de référence; seuil actif fixé à $0.50
input double DynSL_LockPct           = 70.0;  // Minimum % du meilleur gain à protéger
input double DynSL_MinLockUSD        = 0.35;  // Plancher à protéger dès un pic de $0.50
input double DynSL_StepUSD           = 0.05;  // Pas minimum de progression du SL ($)
input int    DynSL_MinAgeSec         = 3;     // Âge min, ignoré dès que le pic atteint $0.50
input bool   DynSL_OnlyOurMagic      = true;  // Uniquement Magic Number de l'EA
input bool   DynSL_ForceCloseOnGiveback = true; // Secours si le gain net passe sous le plancher protégé

//--- Peak profit par ticket (mémoire locale, survit aux ticks)
struct DynSL_PeakMem
{
   ulong  ticket;
   double peakProfit;
   bool   lockArmed;   // true dès que peak a atteint StartLockUSD
};
DynSL_PeakMem g_dynSLPeaks[128];
int           g_dynSLPeakCount = 0;

int DynSL_FindPeakIdx(const ulong ticket)
{
   for(int i = 0; i < g_dynSLPeakCount; i++)
      if(g_dynSLPeaks[i].ticket == ticket) return i;
   return -1;
}

int DynSL_EnsurePeak(const ulong ticket, const double profit)
{
   int idx = DynSL_FindPeakIdx(ticket);
   if(idx >= 0)
   {
      if(profit > g_dynSLPeaks[idx].peakProfit)
         g_dynSLPeaks[idx].peakProfit = profit;
      if(g_dynSLPeaks[idx].peakProfit >= DynSL_StartLockUSD)
         g_dynSLPeaks[idx].lockArmed = true;
      return idx;
   }
   if(g_dynSLPeakCount >= 128)
   {
      // Eviction du plus ancien (shift)
      for(int i = 0; i < 127; i++)
         g_dynSLPeaks[i] = g_dynSLPeaks[i + 1];
      g_dynSLPeakCount = 127;
   }
   idx = g_dynSLPeakCount++;
   g_dynSLPeaks[idx].ticket     = ticket;
   g_dynSLPeaks[idx].peakProfit = profit;
   g_dynSLPeaks[idx].lockArmed  = (profit >= DynSL_StartLockUSD);
   return idx;
}

void DynSL_RemovePeak(const ulong ticket)
{
   int idx = DynSL_FindPeakIdx(ticket);
   if(idx < 0) return;
   for(int i = idx; i < g_dynSLPeakCount - 1; i++)
      g_dynSLPeaks[i] = g_dynSLPeaks[i + 1];
   g_dynSLPeakCount--;
}

//+------------------------------------------------------------------+
//| Convertit un montant $ en distance prix pour le volume donné      |
//+------------------------------------------------------------------+
double DynSL_USDToPriceDist(const string symbol, const double volume, const double usd)
{
   if(volume <= 0.0 || usd <= 0.0) return 0.0;

   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      return usd * point * 10.0;
   }
   return (usd * tickSize) / (tickValue * volume);
}

//+------------------------------------------------------------------+
//| SL cible qui locke lockUSD de gain au-dessus de l'entry           |
//+------------------------------------------------------------------+
double DynSL_CalcLockSL(const bool isBuy,
                        const double openPrice,
                        const double volume,
                        const string symbol,
                        const double lockUSD)
{
   double dist = DynSL_USDToPriceDist(symbol, volume, lockUSD);
   if(dist <= 0.0) return 0.0;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(isBuy)
      return NormalizeDouble(openPrice + dist, digits);
   else
      return NormalizeDouble(openPrice - dist, digits);
}

bool DynSL_RespectStopsLevel(const string symbol, const bool isBuy,
                             const double newSL, const double bid, const double ask)
{
   long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minDist  = (double)MathMax(stopsLevel, freezeLevel) * point;
   if(minDist <= 0.0) minDist = point * 5.0;

   if(isBuy)
      return (newSL < bid - minDist);
   else
      return (newSL > ask + minDist);
}

//+------------------------------------------------------------------+
//| Orchestrateur — appeler chaque tick depuis OnTick()               |
//+------------------------------------------------------------------+
bool DynSL_IsSynthFamily(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   string sc = s;
   StringReplace(sc, " ", "");
   return (StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0 ||
           StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0 ||
           StringFind(sc, "FXVOL") >= 0 || StringFind(sc, "SFXVOL") >= 0 ||
           StringFind(sc, "SFVVOL") >= 0 ||
           StringFind(s, "FX VOL") >= 0 || StringFind(s, "SFX VOL") >= 0);
}

void SMC_ManageDynamicDollarSL()
{
   if(!UseDynamicDollarSL) return;

   static ulong s_lastRunMs = 0;
   ulong nowMs = GetTickCount64();
   if(nowMs - s_lastRunMs < 200) return;
   s_lastRunMs = nowMs;

   for(int p = g_dynSLPeakCount - 1; p >= 0; p--)
   {
      if(!PositionSelectByTicket(g_dynSLPeaks[p].ticket))
         DynSL_RemovePeak(g_dynSLPeaks[p].ticket);
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;

      string symbol = posInfo.Symbol();
      if(DynSL_OnlyOurMagic && posInfo.Magic() != InpMagicNumber) continue;

      ulong  ticket   = posInfo.Ticket();
      double profit   = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPx   = posInfo.PriceOpen();
      double curSL    = posInfo.StopLoss();
      double curTP    = posInfo.TakeProfit();
      double volume   = posInfo.Volume();
      bool   isBuy    = (posInfo.PositionType() == POSITION_TYPE_BUY);
      datetime openT  = posInfo.Time();
      bool   synth    = DynSL_IsSynthFamily(symbol);

      int ageSec = (int)(TimeCurrent() - openT);
      int minAge = synth ? 2 : DynSL_MinAgeSec;

      int peakIdx = DynSL_EnsurePeak(ticket, profit);
      double peak = g_dynSLPeaks[peakIdx].peakProfit;
      bool   armed = g_dynSLPeaks[peakIdx].lockArmed;

      const double startLock = 0.50;
      if(peak >= startLock)
         g_dynSLPeaks[peakIdx].lockArmed = true;
      armed = g_dynSLPeaks[peakIdx].lockArmed;
      if(ageSec < minAge && !armed)
         continue;

      double maxLossUSD = SMC_HardMaxLossUSD();
      if(maxLossUSD <= 0.0) maxLossUSD = 3.0;
      if(DynSL_MaxLossUSD > 0.0)
         maxLossUSD = MathMin(maxLossUSD, DynSL_MaxLossUSD);
      // Respect minimum loss threshold before auto-close (from main EA)
      if(maxLossUSD < MinLossBeforeAutoCloseUSD)
         maxLossUSD = MinLossBeforeAutoCloseUSD;
      if(profit <= -maxLossUSD)
      {
         Print("🛑 DYN-SL MAX LOSS $", DoubleToString(maxLossUSD, 2),
               " atteint | ", symbol, " #", ticket,
               " P/L=", DoubleToString(profit, 2), "$ → FERMETURE");
         PositionCloseWithLog(ticket, "DynSL MaxLoss $" + DoubleToString(maxLossUSD, 2), true);
         DynSL_RemovePeak(ticket);
         continue;
      }

      double lockPct = MathMax(70.0, MathMin(95.0, DynSL_LockPct));
      double lockUSD = 0.0;
      if(armed)
      {
         double minLock = MathMax(0.35, DynSL_MinLockUSD);
         lockUSD = MathMin(peak, MathMax(minLock, peak * (lockPct / 100.0)));
      }

      if(DynSL_ForceCloseOnGiveback && armed && profit < lockUSD)
      {
         Print("🔒 DYN-SL GIVEBACK CLOSE | ", symbol, " #", ticket,
               " | peak=$", DoubleToString(peak, 2),
               " → now=$", DoubleToString(profit, 2),
               " < lock cible $", DoubleToString(lockUSD, 2),
               " → fermeture de secours (indépendante du verdict GOM)");
         if(PositionCloseWithLog(ticket,
            "DynSL Giveback peak=$" + DoubleToString(peak, 2) +
            " floor=$" + DoubleToString(lockUSD, 2) +
            " now=$" + DoubleToString(profit, 2), true))
            DynSL_RemovePeak(ticket);
         continue;
      }

      if(profit < startLock && !armed)
         continue; // pas encore assez de gain, et jamais armé

      double costs = posInfo.Swap() + posInfo.Commission();
      double grossLockUSD = MathMax(0.01, lockUSD - costs);
      double targetSL = DynSL_CalcLockSL(isBuy, openPx, volume, symbol, grossLockUSD);
      if(targetSL <= 0.0) continue;

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0) continue;

      // Le nouveau SL doit améliorer l'existant (jamais élargir le risque)
      bool improves = false;
      double stepDist = DynSL_USDToPriceDist(symbol, volume, DynSL_StepUSD) * 0.5;
      if(isBuy)
         improves = (curSL == 0.0 || targetSL > curSL + stepDist);
      else
         improves = (curSL == 0.0 || targetSL < curSL - stepDist);

      // Une fois armé : corriger un SL moins protecteur que le plancher garanti.
      if(!improves && armed)
      {
         double minLockSL = DynSL_CalcLockSL(isBuy, openPx, volume, symbol, grossLockUSD);
         if(isBuy && (curSL == 0.0 || curSL < openPx || curSL < minLockSL - stepDist))
         {
            targetSL = minLockSL;
            improves = true;
         }
         else if(!isBuy && (curSL == 0.0 || curSL > openPx || curSL > minLockSL + stepDist))
         {
            targetSL = minLockSL;
            improves = true;
         }
      }

      if(!improves) continue;

      if(!DynSL_RespectStopsLevel(symbol, isBuy, targetSL, bid, ask))
         continue;

      // Vérifier que le nouveau SL est différent du SL actuel d'au moins le minimum step
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      long digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double minStep = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(minStep <= 0.0) minStep = point;
      
      double slDiff = MathAbs(targetSL - curSL);
      if(slDiff < minStep)
      {
         // Ajuster au step le plus proche
         if(isBuy)
            targetSL = NormalizeDouble(curSL + MathCeil((targetSL - curSL) / minStep) * minStep, (int)digits);
         else
            targetSL = NormalizeDouble(curSL + MathFloor((targetSL - curSL) / minStep) * minStep, (int)digits);
         
         // Si toujours trop proche, abandonner
         if(MathAbs(targetSL - curSL) < minStep)
            continue;
      }

      if(!DynSL_RespectStopsLevel(symbol, isBuy, targetSL, bid, ask))
         continue;

      if(trade.PositionModify(ticket, targetSL, curTP))
      {
         Print("🔒 DYN-SL LOCK ", (isBuy ? "BUY" : "SELL"), " ", symbol,
               " #", ticket,
               " | profit=$", DoubleToString(profit, 2),
               " | peak=$", DoubleToString(peak, 2),
               " | floor net=$", DoubleToString(lockUSD, 2),
               " | SL ", DoubleToString(curSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
               " → ", DoubleToString(targetSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
      }
   }
}

#endif // SMC_DYNAMIC_DOLLAR_SL_MQH
