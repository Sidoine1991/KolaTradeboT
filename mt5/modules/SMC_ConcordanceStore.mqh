//+------------------------------------------------------------------+
//| SMC_ConcordanceStore.mqh — persistance concordance path + outcome |
//+------------------------------------------------------------------+
#ifndef SMC_CONCORDANCE_STORE_MQH
#define SMC_CONCORDANCE_STORE_MQH

#define SMC_CONC_OUTCOMES_FILE  "TradBOT/concordance_outcomes.csv"
#define SMC_CONC_PENDING_FILE   "TradBOT/concordance_pending.csv"
#define SMC_CONC_MAX_PENDING    64

struct SMC_ConcEntrySnap
{
   ulong    positionId;
   string   symbol;
   string   direction;
   datetime openTime;
   double   concPct;
   double   concHist;
   double   concTraj;
   double   concLive;
   int      gomVn;
   double   gomCoherence;
   string   corrPhase;
   string   corrType;
   double   corrExhaust;
};

ulong             g_concSnapPosIds[];
SMC_ConcEntrySnap g_concSnaps[];
int               g_concSnapCount = 0;

//+------------------------------------------------------------------+
bool SMC_ConcEnsureHeader(const string filePath, const bool isPending)
{
   int h = FileOpen(filePath, FILE_READ | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
      return false;

   bool hasHeader = false;
   if(FileSize(h) > 0)
   {
      FileSeek(h, 0, SEEK_SET);
      string first = FileReadString(h);
      hasHeader = (first == "open_time" || first == "position_id");
   }
   FileClose(h);

   if(hasHeader)
      return true;

   h = FileOpen(filePath, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
   {
      Print("[ConcStore] Erreur création ", filePath, " err=", GetLastError());
      return false;
   }

   if(isPending)
   {
      FileWrite(h,
         "open_time", "position_id", "symbol", "direction",
         "conc_pct", "conc_hist", "conc_traj", "conc_live",
         "gom_vn", "gom_coherence", "corr_phase", "corr_type", "corr_exhaust"
      );
   }
   else
   {
      FileWrite(h,
         "open_time", "close_time", "position_id", "symbol", "direction",
         "conc_pct", "conc_hist", "conc_traj", "conc_live",
         "gom_vn", "gom_coherence", "corr_phase", "corr_type", "corr_exhaust",
         "net_profit", "result", "duration_sec"
      );
   }
   FileClose(h);
   return true;
}

//+------------------------------------------------------------------+
int SMC_ConcFindSnapIndex(const ulong positionId)
{
   for(int i = 0; i < g_concSnapCount; i++)
      if(g_concSnapPosIds[i] == positionId)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
void SMC_ConcRemoveSnapAt(const int idx)
{
   if(idx < 0 || idx >= g_concSnapCount)
      return;
   for(int i = idx + 1; i < g_concSnapCount; i++)
   {
      g_concSnapPosIds[i - 1] = g_concSnapPosIds[i];
      g_concSnaps[i - 1]      = g_concSnaps[i];
   }
   g_concSnapCount--;
   ArrayResize(g_concSnapPosIds, g_concSnapCount);
   ArrayResize(g_concSnaps, g_concSnapCount);
}

//+------------------------------------------------------------------+
void SMC_ConcPersistPending(const SMC_ConcEntrySnap &snap)
{
   SMC_ConcEnsureHeader(SMC_CONC_PENDING_FILE, true);

   int h = FileOpen(SMC_CONC_PENDING_FILE, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
      return;

   FileSeek(h, 0, SEEK_END);
   FileWrite(h,
      TimeToString(snap.openTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      IntegerToString(snap.positionId),
      snap.symbol,
      snap.direction,
      DoubleToString(snap.concPct, 1),
      DoubleToString(snap.concHist, 1),
      DoubleToString(snap.concTraj, 1),
      DoubleToString(snap.concLive, 1),
      IntegerToString(snap.gomVn),
      DoubleToString(snap.gomCoherence, 1),
      snap.corrPhase,
      snap.corrType,
      DoubleToString(snap.corrExhaust, 1)
   );
   FileClose(h);
}

//+------------------------------------------------------------------+
void SMC_ConcWriteOutcome(const SMC_ConcEntrySnap &snap,
                          const datetime closeTime,
                          const double netProfit,
                          const int durationSec)
{
   SMC_ConcEnsureHeader(SMC_CONC_OUTCOMES_FILE, false);

   int h = FileOpen(SMC_CONC_OUTCOMES_FILE, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
   {
      Print("[ConcStore] Erreur outcomes err=", GetLastError());
      return;
   }

   string result = (netProfit > 0) ? "WIN" : ((netProfit < 0) ? "LOSS" : "BE");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h,
      TimeToString(snap.openTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      TimeToString(closeTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      IntegerToString(snap.positionId),
      snap.symbol,
      snap.direction,
      DoubleToString(snap.concPct, 1),
      DoubleToString(snap.concHist, 1),
      DoubleToString(snap.concTraj, 1),
      DoubleToString(snap.concLive, 1),
      IntegerToString(snap.gomVn),
      DoubleToString(snap.gomCoherence, 1),
      snap.corrPhase,
      snap.corrType,
      DoubleToString(snap.corrExhaust, 1),
      DoubleToString(netProfit, 2),
      result,
      IntegerToString(durationSec)
   );
   FileClose(h);

   Print("[ConcStore] ", result, " ", snap.symbol, " conc=", DoubleToString(snap.concPct, 0),
         "% hist=", DoubleToString(snap.concHist, 0), "% P/L=", DoubleToString(netProfit, 2), "$");
}

//+------------------------------------------------------------------+
void SMC_ConcStoreEntry(const ulong positionId,
                        const string symbol,
                        const string direction,
                        const double concPct,
                        const double concHist,
                        const double concTraj,
                        const double concLive,
                        const int gomVn,
                        const double gomCoherence,
                        const string corrPhase,
                        const string corrType,
                        const double corrExhaust)
{
   if(positionId == 0 || symbol == "")
      return;

   int idx = SMC_ConcFindSnapIndex(positionId);
   if(idx < 0)
   {
      if(g_concSnapCount >= SMC_CONC_MAX_PENDING)
         SMC_ConcRemoveSnapAt(0);
      g_concSnapCount++;
      ArrayResize(g_concSnapPosIds, g_concSnapCount);
      ArrayResize(g_concSnaps, g_concSnapCount);
      idx = g_concSnapCount - 1;
      g_concSnapPosIds[idx] = positionId;
   }

   g_concSnaps[idx].positionId   = positionId;
   g_concSnaps[idx].symbol       = symbol;
   g_concSnaps[idx].direction    = direction;
   g_concSnaps[idx].openTime     = TimeCurrent();
   g_concSnaps[idx].concPct      = concPct;
   g_concSnaps[idx].concHist     = concHist;
   g_concSnaps[idx].concTraj     = concTraj;
   g_concSnaps[idx].concLive     = concLive;
   g_concSnaps[idx].gomVn        = gomVn;
   g_concSnaps[idx].gomCoherence = gomCoherence;
   g_concSnaps[idx].corrPhase    = corrPhase;
   g_concSnaps[idx].corrType     = corrType;
   g_concSnaps[idx].corrExhaust  = corrExhaust;

   SMC_ConcPersistPending(g_concSnaps[idx]);
}

//+------------------------------------------------------------------+
bool SMC_ConcFinalizePosition(const ulong positionId,
                            const datetime closeTime,
                            const double netProfit,
                            SMC_ConcEntrySnap &outSnap)
{
   int idx = SMC_ConcFindSnapIndex(positionId);
   if(idx < 0)
      return false;

   outSnap = g_concSnaps[idx];
   int durationSec = (outSnap.openTime > 0 && closeTime > outSnap.openTime)
                     ? (int)(closeTime - outSnap.openTime) : 0;
   SMC_ConcWriteOutcome(outSnap, closeTime, netProfit, durationSec);
   SMC_ConcRemoveSnapAt(idx);
   return true;
}

//+------------------------------------------------------------------+
bool SMC_ConcGetSnap(const ulong positionId, SMC_ConcEntrySnap &outSnap)
{
   int idx = SMC_ConcFindSnapIndex(positionId);
   if(idx < 0)
      return false;
   outSnap = g_concSnaps[idx];
   return true;
}

#endif
