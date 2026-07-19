//+------------------------------------------------------------------+
//| SMC_ExitManagement.mqh — Partial closes, thesis invalidation     |
//| Gère la sortie optimisée des positions pour maximiser le gain    |
//| et minimiser les pertes (scale-out, breakeven, early exit)       |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Forward declarations from main EA                                |
//+------------------------------------------------------------------+
bool   SMC_IsGoldProfileActive();
void   SMC_ReportTradeClose(const string symbol, double netProfit, bool isWin);

// InpMagicNumber / SL_ATRMult : inputs du .mq5 parent — ne PAS redéclarer ici (conflit compile)

//+------------------------------------------------------------------+
//| Configuration variables (defaults; overridden by .mq5 inputs)   |
//+------------------------------------------------------------------+
bool   ExtUsePartialClose       = true;    // Partial close system
double ExtPartialTP1_RR         = 1.5;     // TP1 ratio
double ExtPartialTP2_RR         = 3.0;     // TP2 ratio
double ExtPartialTP3_RR         = 5.0;     // TP3 ratio
double ExtPartialTP1_Pct        = 30.0;    // % à fermer à TP1
double ExtPartialTP2_Pct        = 30.0;    // % à fermer à TP2
double ExtPartialTP3_Pct        = 40.0;    // % à fermer à TP3
double ExtMinProfitUSD          = 0.50;    // Profit mini $ pour déclencher BE
bool   ExtUseThesisInvalidation = true;    // Early exit si thèse invalide
double ExtThesisInvalidRR       = -0.60;   // Sortie à -0.6R si la thèse échoue
double ExtThesisConfirmRR       = 0.50;    // RR mini pour confirmer thèse
double ExtMinContinuationScore  = 50.0;    // Score min continuation (0-100) pour rester après 2 spikes

//+------------------------------------------------------------------+
//| Continuation Strength — GOM + COG + IA                           |
//| Retourne un score 0-100 indiquant si la position doit rester     |
//+------------------------------------------------------------------+
double SMC_CheckContinuationStrength(const string symbol, const int direction)
{
   double score = 0.0;

   // --- GOM Verdict (40 points max) ---
   // direction: 1=BUY, -1=SELL
   int vn = g_smcGomVerdictNum;
   bool gomAligned = false;

   if(direction > 0 && vn >= 2)  gomAligned = true;   // BUY demandé, verdict GOOD/PERFECT BUY
   if(direction < 0 && vn <= -2) gomAligned = true;   // SELL demandé, verdict GOOD/PERFECT SELL

   if(gomAligned)
   {
      if(MathAbs(vn) == 3)
         score += 40.0;  // PERFECT = 40 pts
      else
         score += 30.0;  // GOOD = 30 pts
   }
   else if(vn != 0)
   {
      // Verdict?? mais pas aligné ? pénalité
      score += 5.0;  // Minimum pour ne pas bloquer
   }

   // --- COG Direction (30 points max) ---
   bool cogAligned = false;
   if(direction > 0 && g_cogDirection == "BUY")  cogAligned = true;
   if(direction < 0 && g_cogDirection == "SELL") cogAligned = true;

   if(cogAligned)
      score += 30.0;
   else if(g_cogDirection == "NEUTRAL")
      score += 10.0;  // NEUTRAL = neutre
   else
      score += 0.0;   // COG opposé = 0

   // --- IA Confidence (30 points max) ---
   if(g_iaStatusConfidence >= 80.0)
      score += 30.0;
   else if(g_iaStatusConfidence >= 65.0)
      score += 20.0;
   else if(g_iaStatusConfidence >= 50.0)
      score += 10.0;
   else
      score += 0.0;   // IA faible

   return score;
}

//+------------------------------------------------------------------+
//| Tracked position state                                           |
//+------------------------------------------------------------------+
enum ENUM_PARTIAL_STATE
{
   PARTIAL_NONE     = 0,   // Pas de close partiel effectué
   PARTIAL_TP1_DONE = 1,   // TP1 fermé, SL au BE
   PARTIAL_TP2_DONE = 2,   // TP2 fermé
   PARTIAL_TP3_DONE = 3    // TP3 fermé (position restante en trailing)
};

struct SMC_PositionTracker
{
   ulong            ticket;         // Position ticket
   string           symbol;         // Symbol
   double           entryPrice;     // Prix d'entrée
   double           slDistance;     // Distance SL en prix (pour RR calc)
   ENUM_PARTIAL_STATE state;        // État des closes partiels
   double           maxFavorable;   // Plus haut gain en $ (pour trailing)
   double           invalidationLevel; // Prix déclenchant early exit
   double           confirmationLevel; // Prix confirmant la thèse
   datetime         lastUpdate;     // Dernier update
   bool             thesisConfirmed;// La thèse a été confirmée
   bool             hasRealSL;      // Vrai si le SL vient de la position, pas d'un calcul ATR synthétique
};

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
SMC_PositionTracker g_trackedPositions[];
int g_trackedCount = 0;
CTrade g_partialTrade;
CPositionInfo g_partialPosInfo;

//+------------------------------------------------------------------+
//| Initialize tracker for a new position                            |
//+------------------------------------------------------------------+
void SMC_TrackNewPosition(const ulong ticket, const string symbol,
                          const double entryPrice, const double slPrice,
                          const bool realSL = true)
{
   int idx = -1;
   for(int i = 0; i < g_trackedCount; i++)
   {
      if(g_trackedPositions[i].ticket == ticket)
      {
         idx = i;
         break;
      }
      if(g_trackedPositions[i].ticket == 0 && idx < 0)
         idx = i;
   }

   if(idx < 0)
   {
      idx = g_trackedCount;
      g_trackedCount++;
      ArrayResize(g_trackedPositions, g_trackedCount);
   }

   double slDist = MathAbs(entryPrice - slPrice);
   if(slDist <= 0) slDist = 0.001; // fallback

   g_trackedPositions[idx].ticket           = ticket;
   g_trackedPositions[idx].symbol           = symbol;
   g_trackedPositions[idx].entryPrice       = entryPrice;
   g_trackedPositions[idx].slDistance       = slDist;
   g_trackedPositions[idx].state            = PARTIAL_NONE;
   g_trackedPositions[idx].maxFavorable     = 0;
   g_trackedPositions[idx].thesisConfirmed  = false;
   g_trackedPositions[idx].lastUpdate       = TimeCurrent();
   g_trackedPositions[idx].hasRealSL        = realSL;

   // Calculer seuils d'invalidation et confirmation
   bool isBuy = (slPrice < entryPrice); // SL en dessous = BUY
   if(isBuy)
   {
      g_trackedPositions[idx].invalidationLevel = entryPrice - slDist * MathAbs(ExtThesisInvalidRR);
      g_trackedPositions[idx].confirmationLevel = entryPrice + slDist * ExtThesisConfirmRR;
   }
   else
   {
      g_trackedPositions[idx].invalidationLevel = entryPrice + slDist * MathAbs(ExtThesisInvalidRR);
      g_trackedPositions[idx].confirmationLevel = entryPrice - slDist * ExtThesisConfirmRR;
   }

   Print(StringFormat("[SMC-Exit] Tracking #%d | %s EP=%.5f SL=%.5f | Inval=%.5f Confirm=%.5f",
         ticket, symbol, entryPrice, slPrice,
         g_trackedPositions[idx].invalidationLevel,
         g_trackedPositions[idx].confirmationLevel));
}

//+------------------------------------------------------------------+
//| Clean up stale tracked positions                                 |
//+------------------------------------------------------------------+
void SMC_CleanTrackedPositions()
{
   for(int i = g_trackedCount - 1; i >= 0; i--)
   {
      if(g_trackedPositions[i].ticket == 0) continue;
      if(!PositionSelectByTicket(g_trackedPositions[i].ticket))
      {
         g_trackedPositions[i].ticket = 0;
         g_trackedPositions[i].symbol = "";
         // Compact later if needed
      }
   }
}

//+------------------------------------------------------------------+
//| Get position info for tracked position                           |
//+------------------------------------------------------------------+
bool SMC_GetTrackedPosition(const ulong ticket, SMC_PositionTracker &out)
{
   for(int i = 0; i < g_trackedCount; i++)
   {
      if(g_trackedPositions[i].ticket == ticket)
      {
         out = g_trackedPositions[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update tracked position state                                    |
//+------------------------------------------------------------------+
void SMC_UpdateTrackedPosition(const ulong ticket, const SMC_PositionTracker &src)
{
   for(int i = 0; i < g_trackedCount; i++)
   {
      if(g_trackedPositions[i].ticket == ticket)
      {
         g_trackedPositions[i] = src;
         g_trackedPositions[i].lastUpdate = TimeCurrent();
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Process partial closes for a position                            |
//+------------------------------------------------------------------+
bool SMC_ProcessPartialClose(ulong ticket)
{
   if(!ExtUsePartialClose) return false;
   if(!g_partialPosInfo.SelectByTicket(ticket)) return false;
   if(g_partialPosInfo.Magic() != InpMagicNumber) return false;

   SMC_PositionTracker tr;
   if(!SMC_GetTrackedPosition(ticket, tr)) return false;

   // Ne pas agir sur l'Or (déjà géré par SMC_ManageGoldPartialTP)
   if(SMC_IsGoldProfileActive() && g_partialPosInfo.Symbol() == _Symbol)
   {
      // Gold has its own partial close, skip if gold profile active and it's the managed gold symbol
      return false;
   }

   double curPrice = g_partialPosInfo.PriceCurrent();
   double openPrice = tr.entryPrice;
   double slDist = tr.slDistance;
   if(slDist <= 0) return false;

   bool isBuy = (g_partialPosInfo.PositionType() == POSITION_TYPE_BUY);
   double profit = g_partialPosInfo.Profit() + g_partialPosInfo.Swap() + g_partialPosInfo.Commission();

   // Track max favorable excursion
   if(profit > tr.maxFavorable)
      tr.maxFavorable = profit;

   bool modified = false;
   string symbol = g_partialPosInfo.Symbol();
   double volume = g_partialPosInfo.Volume();
   double currentSL = g_partialPosInfo.StopLoss();

   //--- Thesis confirmation check
   if(!tr.thesisConfirmed)
   {
      bool confirmed = isBuy ? (curPrice >= tr.confirmationLevel)
                             : (curPrice <= tr.confirmationLevel);
      if(confirmed)
      {
         tr.thesisConfirmed = true;
         Print(StringFormat("[SMC-Exit] Thèse CONFIRMÉE #%d %s à %.5f", ticket, symbol, curPrice));
      }
   }

   //--- Thesis invalidation: early exit if thesis invalid before confirmation
   //    Ne s'applique que si la position a un vrai SL (pas un SL ATR synthétique)
   if(ExtUseThesisInvalidation && !tr.thesisConfirmed && tr.hasRealSL)
   {
      bool invalidated = isBuy ? (curPrice <= tr.invalidationLevel)
                               : (curPrice >= tr.invalidationLevel);
      if(invalidated && tr.maxFavorable < 0.5)
      {
         // Early exit - thesis invalid
         if(g_partialPosInfo.SelectByTicket(ticket))
         {
            if(g_partialTrade.PositionClose(ticket))
            {
               Print(StringFormat("[SMC-Exit] THÈSE INVALIDE — fermeture anticipée #%d %s à %.5f (perte %.2f$)",
                     ticket, symbol, curPrice, profit));
            }
            SMC_ReportTradeClose(symbol, profit, false);
            tr.ticket = 0;
            SMC_UpdateTrackedPosition(ticket, tr);
            return true;
         }
      }
   }

   //--- Partial close logic (only for confirmed or thesis-unnecessary situations)
   // Wait for at least breakeven before partial close
   if(profit < ExtMinProfitUSD)
   {
      SMC_UpdateTrackedPosition(ticket, tr);
      return false;
   }

   // Calculate current RR
   double currentRR = isBuy ? ((curPrice - openPrice) / slDist)
                            : ((openPrice - curPrice) / slDist);
   if(currentRR < 0) currentRR = 0;

   string dg = IntegerToString((int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

   //--- TP1: partial close at ExtPartialTP1_RR
   if(tr.state == PARTIAL_NONE && currentRR >= ExtPartialTP1_RR)
   {
      double closePct = ExtPartialTP1_Pct / 100.0;
      double closeVol = volume * closePct;
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      closeVol = MathMax(minLot, MathFloor(closeVol / stepLot) * stepLot);

      if(closeVol >= minLot)
      {
         ResetLastError();
         if(g_partialTrade.PositionClosePartial(ticket, closeVol))
         {
            tr.state = PARTIAL_TP1_DONE;
            modified = true;

            // Move SL to breakeven
            double beSL = NormalizeDouble(openPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
            double minStop = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
            bool slOk = isBuy ? (beSL < curPrice - minStop) : (beSL > curPrice + minStop);
            if(slOk && PositionSelectByTicket(ticket))
            {
               g_partialTrade.PositionModify(ticket, beSL, g_partialPosInfo.TakeProfit());
            }

            Print(StringFormat("[SMC-Exit] TP1 PARTIEL #%d %s | %.2f lots fermés à RR=%.1f | SL au BE",
                  ticket, symbol, closeVol, ExtPartialTP1_RR));
         }
         else
         {
            Print(StringFormat("[SMC-Exit] ERREUR TP1 #%d %s: %s", ticket, symbol, _LastError == 0 ? "unknown" : IntegerToString(_LastError)));
         }
      }
   }

   //--- TP2: partial close at ExtPartialTP2_RR
   if(tr.state == PARTIAL_TP1_DONE && currentRR >= ExtPartialTP2_RR)
   {
      // Re-select position after partial close
      if(!g_partialPosInfo.SelectByTicket(ticket))
      {
         SMC_UpdateTrackedPosition(ticket, tr);
         return modified;
      }
      double remainingVol = g_partialPosInfo.Volume();
      double closePct = ExtPartialTP2_Pct / (ExtPartialTP2_Pct + ExtPartialTP3_Pct); // % of remaining
      double closeVol = remainingVol * closePct;
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      closeVol = MathMax(minLot, MathFloor(closeVol / stepLot) * stepLot);

      if(closeVol >= minLot)
      {
         ResetLastError();
         if(g_partialTrade.PositionClosePartial(ticket, closeVol))
         {
            tr.state = PARTIAL_TP2_DONE;
            modified = true;

            Print(StringFormat("[SMC-Exit] TP2 PARTIEL #%d %s | %.2f lots fermés à RR=%.1f",
                  ticket, symbol, closeVol, ExtPartialTP2_RR));
         }
         else
         {
            Print(StringFormat("[SMC-Exit] ERREUR TP2 #%d %s: %s", ticket, symbol, _LastError == 0 ? "unknown" : IntegerToString(_LastError)));
         }
      }
   }

   //--- CONTINUATION CHECK: après 2 spikes (TP1+TP2), vérifier si le 3ème vaut la peine
   if(tr.state == PARTIAL_TP2_DONE)
   {
      int direction = isBuy ? 1 : -1;
      double contScore = SMC_CheckContinuationStrength(symbol, direction);

      if(contScore < ExtMinContinuationScore)
      {
         // Conditions affaiblies ? fermer le reste
         if(g_partialPosInfo.SelectByTicket(ticket))
         {
            double remainingVol = g_partialPosInfo.Volume();
            double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            if(remainingVol >= minLot)
            {
               ResetLastError();
               if(g_partialTrade.PositionClosePartial(ticket, remainingVol))
               {
                  tr.state = PARTIAL_TP3_DONE;
                  modified = true;
                  Print(StringFormat("[SMC-Exit] CONTINUATION WEAK #%d %s | Score=%.0f/%.0f — clôturé reste %.2f lots",
                        ticket, symbol, contScore, ExtMinContinuationScore, remainingVol));
               }
            }
         }
         SMC_UpdateTrackedPosition(ticket, tr);
         return modified;
      }
      else
      {
         // Conditions encore bonnes ? laisser courir vers TP3
         static datetime s_contLog = 0;
         if(TimeCurrent() - s_contLog >= 120)
         {
            s_contLog = TimeCurrent();
            Print(StringFormat("[SMC-Exit] CONTINUATION OK #%d %s | Score=%.0f/%.0f — reste ouvert vers TP3",
                  ticket, symbol, contScore, ExtMinContinuationScore));
         }
      }
   }

   //--- TP3: final partial close at ExtPartialTP3_RR
   if(tr.state == PARTIAL_TP2_DONE && currentRR >= ExtPartialTP3_RR)
   {
      if(!g_partialPosInfo.SelectByTicket(ticket))
      {
         SMC_UpdateTrackedPosition(ticket, tr);
         return modified;
      }
      double remainingVol = g_partialPosInfo.Volume();
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      if(remainingVol >= minLot)
      {
         ResetLastError();
         if(g_partialTrade.PositionClosePartial(ticket, remainingVol))
         {
            tr.state = PARTIAL_TP3_DONE;
            modified = true;

            Print(StringFormat("[SMC-Exit] TP3 FINAL #%d %s | %.2f lots fermés à RR=%.1f",
                  ticket, symbol, remainingVol, ExtPartialTP3_RR));
         }
         else
         {
            Print(StringFormat("[SMC-Exit] ERREUR TP3 #%d %s: %s", ticket, symbol, _LastError == 0 ? "unknown" : IntegerToString(_LastError)));
         }
      }
   }

   SMC_UpdateTrackedPosition(ticket, tr);
   return modified;
}

//+------------------------------------------------------------------+
//| Main exit management — called from OnTick                        |
//+------------------------------------------------------------------+
void SMC_ManageExitManagement()
{
   if(!ExtUsePartialClose && !ExtUseThesisInvalidation) return;

   // Nettoyer les positions fermées
   SMC_CleanTrackedPositions();

   // Parcourir toutes nos positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_partialPosInfo.SelectByIndex(i)) continue;
      if(g_partialPosInfo.Magic() != InpMagicNumber) continue;

      ulong ticket = g_partialPosInfo.Ticket();

      // Si cette position n'est pas trackée, l'ajouter
      SMC_PositionTracker dummy;
      if(!SMC_GetTrackedPosition(ticket, dummy))
      {
         // Calculer le SL original à partir du ticket
         double sl = g_partialPosInfo.StopLoss();
         double ep = g_partialPosInfo.PriceOpen();
         bool hasRealSL = (sl != 0);
         if(!hasRealSL)
         {
            // Utiliser la distance SL standard si pas de SL défini
            string sym = g_partialPosInfo.Symbol();
            double atrVal = 0;
            double atrArr[];
            ArraySetAsSeries(atrArr, true);
            int atrH = iATR(sym, PERIOD_M5, 14);
            if(atrH != INVALID_HANDLE && CopyBuffer(atrH, 0, 0, 1, atrArr) >= 1)
               atrVal = atrArr[0];
            if(atrH != INVALID_HANDLE) IndicatorRelease(atrH);

            if(atrVal > 0)
            {
               sl = (g_partialPosInfo.PositionType() == POSITION_TYPE_BUY)
                    ? ep - atrVal * SL_ATRMult
                    : ep + atrVal * SL_ATRMult;
            }
         }

         SMC_TrackNewPosition(ticket, g_partialPosInfo.Symbol(), ep, sl, hasRealSL);
      }

      // Process partial close for this position
      SMC_ProcessPartialClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| Track a position explicitly from OrderSend success               |
//+------------------------------------------------------------------+
void SMC_OnPositionOpened(const ulong ticket, const string symbol,
                          const double entryPrice, const double slPrice)
{
   if(!ExtUsePartialClose && !ExtUseThesisInvalidation) return;
   SMC_TrackNewPosition(ticket, symbol, entryPrice, slPrice, slPrice != 0);
}

//+------------------------------------------------------------------+
//| Init exit management                                             |
//+------------------------------------------------------------------+
void SMC_InitExitManagement()
{
   g_trackedCount = 0;
   ArrayResize(g_trackedPositions, 10);
   for(int i = 0; i < 10; i++)
   {
      g_trackedPositions[i].ticket    = 0;
      g_trackedPositions[i].hasRealSL = false;
   }
   Print("[SMC-Exit] Module initialisé | PartialClose=", ExtUsePartialClose,
         " ThesisInvalidation=", ExtUseThesisInvalidation);
}
//+------------------------------------------------------------------+
