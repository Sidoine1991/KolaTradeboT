//+------------------------------------------------------------------+
//| TMState.mqh — Centralized state replacing 50+ globals             |
//| Institutional-grade EA state management (Phase 1 refactoring)     |
//+------------------------------------------------------------------+
#ifndef TM_STATE_MQH
#define TM_STATE_MQH

// ═══════════════════════════════════════════════════════════════════
// SUB-STRUCTS (logically grouped for clarity)
// ═══════════════════════════════════════════════════════════════════

struct TMConfig
{
   // Execution mode
   bool     pipelineOnlyMode;
   bool     useMCPSignals;
   bool     useGOMScalp;
   bool     useGOMAutoEntry;
   bool     useGOMReEntry;
   bool     useTrailing;
   bool     useStagnationExit;
   bool     useProfitGiveback;
   bool     useDerivEngine;
   bool     useDashboard;
   bool     useTVSetup;
   bool     useCapitalManager;
   bool     useWhatsApp;

   // Thresholds & Targets
   bool     useGlobalProfitTarget;
   double   maxRiskUSD;
   double   targetProfitUSD;
   double   trailActivateUSD;
   double   trailLockPct;
   double   stagnationTriggerUSD;
   int      stagnationHoldSec;
   double   stagnationMaxGivebackUSD;
   double   stagnationLockMinUSD;
   double   stagnationFlatBandUSD;
   double   profitGivebackArmUSD;
   double   maxGivebackFromPeakUSD;
   double   maxLossCapUSD;
   double   globalProfitTargetUSD;
   bool     globalProfitMCPOnly;

   // Limits
   int      maxGlobalPositions;
   int      maxPositionsPerSymbol;
   bool     reEntryIgnoreGlobal;
   int      checkIntervalSec;
   int      mcpMagicNumber;
   int      tvSetupMagicNumber;

   // MCP Configuration
   string   aiServerURL;
   int      mcpPollIntervalSec;
   int      mcpMagicNumber2;  // Alias for compatibility
   double   mcpEntryTolerancePct;
   bool     mcpExecuteAtMarket;
   bool     mcpBypassConsolidation;
   bool     mcpDuplicateOnce;
   double   mcpDuplicateMinProfit;
   bool     duplicateManualOrders;
   bool     duplicateRequireGoodPerfect;
   int      duplicateMinGlobalStrength;
   double   duplicateMinQuality;
   double   duplicateMinCoherence;
   int      dupProfitStableSec;
   double   dupMinSetupProb;

   // GOM Configuration
   int      gomPollIntervalSec;
   int      gomSignalMaxAgeSec;
   double   gomMinQuality;
   double   gomMinCoherence;
   bool     gomAllowStrongSimple;
   double   gomStrongScoreGap;
   bool     gomAllowSimpleDespiteKola;
   int      gomReEntryCooldownSec;
   double   gomReEntryLot;
   int      gomReEntryMaxCount;
   bool     gomUseGlobalTrendFilter;
   int      gomGlobalTrendMinStrength;
   bool     gomWaitPullbackToKola;
   bool     requireGlobalDirMatch;
   int      globalDirMinConfidence;
   double   globalMinCoherencePct;

   // Filters
   bool     useConsolidationFilter;
   int      adx_period;
   double   adx_minTrend;
   double   consolidationATRRatio;
   bool     useEMAFilter;
   int      rsi_period;
   double   rsi_sellMax;
   double   rsi_buyMin;
   bool     useBBTrendFilter;
   int      bbTrendPeriod;
   int      bbTrendSlopeBars;
   bool     gomBlockCorrectionZone;
   bool     gomUseMicroTFCorrection;
   int      gomCorrectionPathLook;
   int      gomCorrectionMinBars;
   double   gomMinSetupProb;

   // TV Setup Configuration
   bool     useTVSetupLimit;
   double   tvSetupEntryTolPct;
   bool     tvSetupRequirePinBar;
   bool     tvSetupBlockPlaceOnWait;
   bool     tvSetupCancelOnWaitTouch;
   int      tvSetupRearmCooldownSec;
   bool     tvSetupInferFromGOM;
   bool     tvSetupMarketOnBreakout;
   double   tvSetupBreakoutTolPct;
   bool     tvSetupSpikeMarket;

   // Predictive Path Configuration
   bool     showGOMPathCandles;
   int      gomPathDrawBars;
   int      gomPathDrawRefreshSec;
   double   gomPathStepAtr;

   // Deriv Engine Configuration
   bool     useDerivEngine2;  // Alias for compatibility
   bool     drv_autoPresets;
   double   drv_spikeBodyMult;
   double   drv_spikeWickMult;
   int      drv_barsMin;
   double   drv_windowStart;
   double   drv_windowEnd;
   int      drv_pullbackBars;
   bool     drv_useBOS;
   bool     drv_useCHOCH;
   bool     drv_useLiqSweep;
   bool     drv_useOB;
   bool     drv_useFVG;
   bool     drv_useOTE;
   int      drv_minICTScore;
   int      drv_ictLookback;
   double   drv_sl_atr;
   double   drv_tp_atr;
   bool     drv_useQuickExit;
   double   drv_quickExitMinPct;
   int      drv_timeStopMin;
   bool     drv_useSmartBE;
   double   drv_beTrigger;
   bool     drv_useTrail;
   double   drv_trailATR;
   double   drv_trailActivation;

   // Dashboard Configuration
   int      dashboardX;
   int      dashboardY;
   int      dashboardUpdateSec;
   bool     dashboardLocalMTF;
   int      panelWidth;
   int      rowHeight;
   int      fontSize;
   color    colorHeaderBuy;
   color    colorBuy;
   color    colorNeutral;
   color    colorSell;
   color    colorHeaderSell;
   color    colorBackground;
   color    colorText;
   color    colorBorder;

   // Capital Manager
   bool     useCapitalManager2;  // Alias for compatibility
   double   cm_dailyTargetPct;
   double   cm_dailyStopLossPct;
   int      cm_maxTradesPerDay;
   double   cm_minCapitalToTrade;
   double   cm_lotRiskPct;
   bool     cm_persistStats;

   // WhatsApp
   bool     useWhatsApp2;  // Alias for compatibility
   int      waTimeoutMs;

   // Advanced Filters
   bool     requireSignalAlign;
   int      signalCacheAgeSec;
   double   minTAConfidence;
   int      maxSignalFailCount;

   // Whitelist
   string   pipelineWhitelistPath;
   string   inpPollSymbols;
};

struct TMGOMState
{
   datetime lastPoll;
   string   verdict;
   int      verdictNum;        // -3..+3
   double   scoreBuy;
   double   scoreSell;
   double   quality;
   double   coherence;
   int      rsi;
   bool     rsIOversold;
   bool     rsIOverbought;
   string   kolaState;
   bool     isConsolidation;
   string   globalDir;
   int      globalStrength;
   int      stDir;
   double   kolaBuy;
   double   kolaSell;
   double   bbUp;
   double   bbMid;
   double   bbDn;
};

struct TMGHOSTState
{
   double   delta;
   double   cvd;
   double   buyPct;
   double   compass;
};

struct TMPredictiveState
{
   string   predPath;
   string   drawKey;
   int      predNet;
   double   buyProb;
   double   sellProb;
   double   validProb;
   double   hitRate;
   bool     spikeTradable;
   double   spikeImminence;
   datetime lastDraw;
};

struct TMSetupState
{
   bool     valid;
   int      direction;
   double   entry;
   double   sl;
   double   tp1;
   double   tp2;
   double   rr;
   string   type;
   string   confirm;
   string   key;
   ulong    orderTicket;
   datetime placedAt;
   bool     entryTouched;
   datetime cancelAt;
   datetime breakoutDone;
   datetime placeFailAt;
};

struct TMDerivState
{
   int      barsSinceSpike;
   datetime lastSpikeBar;
   datetime lastProcessedBar;
   double   spikeExtLow;
   double   spikeExtHigh;
   bool     tradeTaken;
   datetime lastTradeBar;
   datetime openTime;
   ulong    ticket;
   bool     beTriggered;
   string   lastReason;
   int      ictScore;
   string   ictGrade;
   int      hATR;
   int      hRSI;
};

struct TMDisciplineState
{
   bool     dailyTargetHit;
   datetime dailyResetDate;
   double   dailyStartBalance;
   int      dailyTradeCount;
   int      maxDailyTrades;
   double   dailyProfitTarget;
   int      totalWins;
   int      totalLosses;
   double   totalProfitWins;
   double   totalLossAmount;
   double   lastTradeProfit;
};

struct TMWhitelistState
{
   string   symbols[];
   int      count;
   datetime loadedAt;
};

struct TMSymbolState
{
   string   symbol;
   int      direction;
   double   openPrice;
   double   originalSL;
   double   originalTP;
   double   originalLot;
   double   slDist;
   double   tpDist;
   double   peakProfit;
   datetime closeTime;
   double   closePrice;
   int      reEntryCount;
   datetime lastReEntry;
   bool     waitingReEntry;
   bool     forceTrailing;
   datetime lastReEntryFail;
   datetime lastSLHitTime;
   int      consecutiveLosses;
   datetime stagnationZoneSince;
   datetime stagnationLastPeakTime;
   double   stagnationPeakUSD;
   bool     stagnationArmed;
   int      hRSI;
   int      hEMAFast;
   int      hEMASlow;
   int      hADX;
   int      hATR;
};

struct TMMCPSignal
{
   bool     active;
   bool     executed;
   bool     marketExec;
   bool     duplicated;
   string   symbol;
   int      direction;
   double   entryPrice;
   double   stopLoss;
   double   takeProfit1;
   double   lot;
   ulong    ticket;
   datetime receivedAt;
   bool     entryNotifSent;
   string   orderId;
   int      failCount;
   string   source;
};

struct TMGOMReEntry
{
   bool     active;
   string   symbol;
   int      direction;
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   lot;
   datetime closedAt;
   int      reEntryCount;
};

struct TMOrderBlockState
{
   double   bullTop;
   double   bullBot;
   double   bearTop;
   double   bearBot;
};

struct TMTimingState
{
   datetime lastMCPPoll;
   datetime lastGOMPoll;
   datetime lastDashboardUpdate;
   datetime lastBBCurveDraw;
   datetime lastGOMAutoEntry;
   datetime lastGOMReEntry;
};

// ═══════════════════════════════════════════════════════════════════
// MASTER STATE STRUCT
// ═══════════════════════════════════════════════════════════════════

struct TradeManagerState
{
   TMConfig           config;
   TMGOMState         gom;
   TMGHOSTState       ghost;
   TMPredictiveState  pred;
   TMSetupState       setup;
   TMDerivState       deriv;
   TMDisciplineState  discipline;
   TMWhitelistState   whitelist;
   TMOrderBlockState  orderBlocks;
   TMTimingState      timing;

   // Dynamic arrays (resized on demand)
   TMSymbolState      symbols[];
   int                symbolCount;
   TMMCPSignal        mcpSignals[];
   int                mcpCount;
   TMGOMReEntry       gomReEntries[];
   int                gomReEntryCount;

   // Ticket peak tracking
   ulong              peakTickets[];
   double             peakValues[];
   int                peakCount;

   // Manual duplicate tracking
   ulong              manualDupTickets[];
   int                manualDupCount;

   // Global state flags
   bool               globalCloseDone;
   datetime           globalCloseTime;
};

// ═══════════════════════════════════════════════════════════════════
// GLOBAL STATE INSTANCE (singleton pattern)
// ═══════════════════════════════════════════════════════════════════

TradeManagerState g_state;

// ═══════════════════════════════════════════════════════════════════
// ACCESSOR FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

int FindSymbolState(const string sym)
{
   for(int i = 0; i < g_state.symbolCount; i++)
      if(g_state.symbols[i].symbol == sym) return i;
   return -1;
}

int AddOrGetSymbolState(const string sym)
{
   int idx = FindSymbolState(sym);
   if(idx >= 0) return idx;

   idx = g_state.symbolCount;
   ArrayResize(g_state.symbols, idx + 1);
   g_state.symbols[idx].symbol = sym;
   g_state.symbols[idx].direction = 0;
   g_state.symbols[idx].hRSI = INVALID_HANDLE;
   g_state.symbols[idx].hEMAFast = INVALID_HANDLE;
   g_state.symbols[idx].hEMASlow = INVALID_HANDLE;
   g_state.symbols[idx].hADX = INVALID_HANDLE;
   g_state.symbols[idx].hATR = INVALID_HANDLE;
   g_state.symbolCount++;
   return idx;
}

int FindMCPSignal(const string sym)
{
   for(int i = 0; i < g_state.mcpCount; i++)
      if(g_state.mcpSignals[i].symbol == sym && g_state.mcpSignals[i].active) return i;
   return -1;
}

int AddMCPSignal()
{
   int idx = g_state.mcpCount;
   ArrayResize(g_state.mcpSignals, idx + 1);
   g_state.mcpCount++;
   return idx;
}

int FindGOMReEntry(const string sym)
{
   for(int i = 0; i < g_state.gomReEntryCount; i++)
      if(g_state.gomReEntries[i].symbol == sym && g_state.gomReEntries[i].active) return i;
   return -1;
}

int AddGOMReEntry()
{
   int idx = g_state.gomReEntryCount;
   ArrayResize(g_state.gomReEntries, idx + 1);
   g_state.gomReEntryCount++;
   return idx;
}

double GetTicketPeak(ulong ticket)
{
   for(int i = 0; i < g_state.peakCount; i++)
      if(g_state.peakTickets[i] == ticket) return g_state.peakValues[i];
   return 0.0;
}

void SetTicketPeak(ulong ticket, double value)
{
   for(int i = 0; i < g_state.peakCount; i++)
   {
      if(g_state.peakTickets[i] == ticket)
      {
         g_state.peakValues[i] = value;
         return;
      }
   }
   int n = g_state.peakCount;
   ArrayResize(g_state.peakTickets, n + 1);
   ArrayResize(g_state.peakValues, n + 1);
   g_state.peakTickets[n] = ticket;
   g_state.peakValues[n] = value;
   g_state.peakCount++;
}

bool HasDuplicateTicket(ulong ticket)
{
   for(int i = 0; i < g_state.manualDupCount; i++)
      if(g_state.manualDupTickets[i] == ticket) return true;
   return false;
}

void AddDuplicateTicket(ulong ticket)
{
   int n = g_state.manualDupCount;
   ArrayResize(g_state.manualDupTickets, n + 1);
   g_state.manualDupTickets[n] = ticket;
   g_state.manualDupCount++;
}

#endif // TM_STATE_MQH
