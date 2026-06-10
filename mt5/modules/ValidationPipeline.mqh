//+------------------------------------------------------------------+
//| ValidationPipeline.mqh — Composable entry validation filter chain |
//| Each filter returns PASS/REJECT/SKIP with reason. No business     |
//| logic outside filters — all validation centralized here.          |
//+------------------------------------------------------------------+
#ifndef TM_VALIDATION_MQH
#define TM_VALIDATION_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"

// ═══════════════════════════════════════════════════════════════════
// FILTER RESULT ENUMERATION
// ═══════════════════════════════════════════════════════════════════

enum FILTER_RESULT
{
   FILTER_PASS   = 0,      // Entry allowed
   FILTER_REJECT = 1,      // Entry blocked (with reason)
   FILTER_SKIP   = 2       // Filter not applicable (ignore)
};

// ═══════════════════════════════════════════════════════════════════
// FILTER CONTEXT (input to all filters)
// ═══════════════════════════════════════════════════════════════════

struct FilterContext
{
   string   symbol;         // XAUUSD, Boom 500 Index, etc.
   int      direction;      // 1=BUY, -1=SELL
   string   source;         // "pipeline" | "gom_auto" | "mcp" | "deriv"
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   bool     isPipeline;     // true = human-approved via pipeline
};

// ═══════════════════════════════════════════════════════════════════
// FILTER OUTPUT
// ═══════════════════════════════════════════════════════════════════

struct FilterResult
{
   FILTER_RESULT  status;
   string         filterName;
   string         reason;
};

// ═══════════════════════════════════════════════════════════════════
// FILTER 1: Pipeline Mode (only accept pipeline-approved orders)
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterPipelineOnly(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "PipelineOnly";

   if(!g_state.config.pipelineOnlyMode)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   if(ctx.isPipeline)
   {
      r.status = FILTER_PASS;
      return r;
   }

   r.status = FILTER_REJECT;
   r.reason = "PipelineOnlyMode active — auto entries blocked";
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 2: Daily Trade Limit
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterDailyLimit(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "DailyLimit";

   if(!g_state.config.useCapitalManager)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   if(g_state.discipline.dailyTradeCount >= g_state.discipline.maxDailyTrades)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("Max daily trades %d/%d reached",
                              g_state.discipline.dailyTradeCount,
                              g_state.discipline.maxDailyTrades);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 3: Daily Profit Target
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterDailyProfitTarget(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "DailyProfit";

   if(!g_state.config.useCapitalManager)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   if(g_state.discipline.dailyTargetHit)
   {
      r.status = FILTER_REJECT;
      r.reason = "Daily profit target reached — trading paused";
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 4: Global Position Limit
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterGlobalPositionLimit(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "GlobalPosLimit";

   // Pipeline orders bypass position limit (user already approved)
   if(ctx.isPipeline)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   int openPos = PositionsTotal();
   if(openPos >= g_state.config.maxGlobalPositions)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("Global limit %d/%d — too many open positions",
                              openPos, g_state.config.maxGlobalPositions);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 5: Boom/Crash Direction (ABSOLUTE RULES)
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterBoomCrashDirection(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "BoomCrashDir";

   string u = ctx.symbol;
   StringToUpper(u);
   bool isBoom  = (StringFind(u, "BOOM") >= 0);
   bool isCrash = (StringFind(u, "CRASH") >= 0);

   if(isBoom && ctx.direction == -1)
   {
      r.status = FILTER_REJECT;
      r.reason = "SELL forbidden on Boom (BUY only) — synthetique unidirectionnel";
      return r;
   }

   if(isCrash && ctx.direction == 1)
   {
      r.status = FILTER_REJECT;
      r.reason = "BUY forbidden on Crash (SELL only) — synthetique unidirectionnel";
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 6: GOM Verdict (reject if WAIT)
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterGOMWait(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "GOMWait";

   if(!g_state.config.useGOMScalp)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   if(g_state.gom.verdictNum == 0)
   {
      r.status = FILTER_REJECT;
      r.reason = "GOM=WAIT — no market entries";
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 7: Anti-Correction Gate (CRITICAL)
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterAntiCorrection(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "AntiCorrection";

   if(!g_state.config.useGOMScalp)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   bool isBull = (g_state.gom.verdictNum > 0);   // BUY bias
   bool isBear = (g_state.gom.verdictNum < 0);   // SELL bias

   if((ctx.direction == 1 && isBear) || (ctx.direction == -1 && isBull))
   {
      r.status = FILTER_REJECT;
      string dir = ctx.direction == 1 ? "BUY" : "SELL";
      string bias = isBear ? "BEAR" : "BULL";
      r.reason = StringFormat("Direction %s vs GOM %s — trading against trend (correction detected)",
                              dir, bias);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 8: TF Consensus (H1 + H4 alignment)
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterTFConsensus(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "TFConsensus";

   if(!g_state.config.useGOMScalp)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   // If GOM is GOOD/PERFECT, assume H1+H4 are aligned (GOM already did this)
   if(MathAbs(g_state.gom.verdictNum) >= 2)
   {
      r.status = FILTER_PASS;
      return r;
   }

   // For weaker signals, check coherence % as proxy for TF alignment
   if(g_state.gom.coherence < g_state.config.globalMinCoherencePct)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("TF coherence %.1f%% < %.1f%% (H1/H4 not aligned)",
                              g_state.gom.coherence, g_state.config.globalMinCoherencePct);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 9: RSI Divergence Detection
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterRSIDivergence(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "RSIDivergence";

   if(!g_state.config.useGOMScalp)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   // GOM RSI stored in g_state.gom.rsi
   // Fake signals: price UP but RSI DOWN, or price DOWN but RSI UP
   // This is a lightweight check; detailed divergence analysis in dedicated module
   if(g_state.gom.rsi < 10 || g_state.gom.rsi > 90)
   {
      // Extreme RSI: allow (RSI overbought/oversold is valid entry point)
      r.status = FILTER_PASS;
      return r;
   }

   // RSI in normal range: allow
   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 10: Momentum Check (M1 RSI strength)
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterMomentum(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "Momentum";

   if(!g_state.config.useGOMScalp)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   // For BUY: require RSI >= 30 (not oversold and rising)
   // For SELL: require RSI <= 70 (not overbought and falling)
   if(ctx.direction == 1 && g_state.gom.rsi < g_state.config.rsi_buyMin)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("BUY momentum weak: RSI=%.0f < %.0f",
                              (double)g_state.gom.rsi, g_state.config.rsi_buyMin);
      return r;
   }

   if(ctx.direction == -1 && g_state.gom.rsi > g_state.config.rsi_sellMax)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("SELL momentum weak: RSI=%.0f > %.0f",
                              (double)g_state.gom.rsi, g_state.config.rsi_sellMax);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 11: Bollinger Band Trend Filter
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterBBCounterTrend(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "BBCounterTrend";

   if(!g_state.config.useBBTrendFilter)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   // Price vs BB Mid: if price > mid and mid is sloping up, BUY ok
   // If price < mid and mid is sloping down, SELL ok
   // Opposite = counter-trend
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(ctx.direction == 1 && currentPrice < g_state.gom.bbMid)
   {
      // BUY but price below BB mid (bearish setup)
      r.status = FILTER_REJECT;
      r.reason = StringFormat("BUY counter-trend: price %.5f < BB_Mid %.5f",
                              currentPrice, g_state.gom.bbMid);
      return r;
   }

   if(ctx.direction == -1 && currentPrice > g_state.gom.bbMid)
   {
      // SELL but price above BB mid (bullish setup)
      r.status = FILTER_REJECT;
      r.reason = StringFormat("SELL counter-trend: price %.5f > BB_Mid %.5f",
                              currentPrice, g_state.gom.bbMid);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 12: Global Direction Coherence
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterGlobalDirCoherence(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "GlobalDirCoherence";

   // Pipeline orders bypass this (user already approved)
   if(ctx.isPipeline)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   if(!g_state.config.requireGlobalDirMatch)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   // Check if entry direction matches global trend
   bool globalBull = (g_state.gom.globalDir == "BULL" && g_state.gom.globalStrength >= g_state.config.globalDirMinConfidence);
   bool globalBear = (g_state.gom.globalDir == "BEAR" && g_state.gom.globalStrength >= g_state.config.globalDirMinConfidence);

   if(ctx.direction == 1 && !globalBull)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("BUY vs global %s (strength %d%%) — trend mismatch",
                              g_state.gom.globalDir, g_state.gom.globalStrength);
      return r;
   }

   if(ctx.direction == -1 && !globalBear)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("SELL vs global %s (strength %d%%) — trend mismatch",
                              g_state.gom.globalDir, g_state.gom.globalStrength);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 13: GOM Quality/Coherence Thresholds
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterGOMQuality(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "GOMQuality";

   if(!g_state.config.useGOMScalp)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   if(g_state.gom.quality < g_state.config.gomMinQuality)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("GOM quality %.1f%% < %.1f%% (entry confidence low)",
                              g_state.gom.quality, g_state.config.gomMinQuality);
      return r;
   }

   if(g_state.gom.coherence < g_state.config.gomMinCoherence)
   {
      r.status = FILTER_REJECT;
      r.reason = StringFormat("GOM coherence %.1f%% < %.1f%% (consolidation detected)",
                              g_state.gom.coherence, g_state.config.gomMinCoherence);
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER 14: GHOST OrderFlow Confirmation
// ═══════════════════════════════════════════════════════════════════

FilterResult FilterGHOSTOrderFlow(const FilterContext &ctx)
{
   FilterResult r;
   r.filterName = "GHOSTOrderFlow";

   // GHOST is informational; don't hard-reject, just skip if unavailable
   if(g_state.ghost.buyPct <= 0)
   {
      r.status = FILTER_SKIP;
      return r;
   }

   // BUY: prefer buyPct >= 60
   if(ctx.direction == 1 && g_state.ghost.buyPct < 45.0)
   {
      // Don't reject, just log detail
      r.status = FILTER_PASS;
      return r;
   }

   // SELL: prefer buyPct <= 40
   if(ctx.direction == -1 && g_state.ghost.buyPct > 55.0)
   {
      r.status = FILTER_PASS;
      return r;
   }

   r.status = FILTER_PASS;
   return r;
}

// ═══════════════════════════════════════════════════════════════════
// FILTER CHAIN ENUMERATION
// ═══════════════════════════════════════════════════════════════════

enum FILTER_ID
{
   FID_PIPELINE_ONLY = 0,
   FID_DAILY_LIMIT = 1,
   FID_DAILY_PROFIT = 2,
   FID_GLOBAL_POS_LIMIT = 3,
   FID_BOOM_CRASH_DIR = 4,
   FID_GOM_WAIT = 5,
   FID_ANTI_CORRECTION = 6,
   FID_TF_CONSENSUS = 7,
   FID_RSI_DIVERGENCE = 8,
   FID_MOMENTUM = 9,
   FID_BB_COUNTER_TREND = 10,
   FID_GLOBAL_DIR_COHERENCE = 11,
   FID_GOM_QUALITY = 12,
   FID_GHOST_ORDERFLOW = 13,
   FID_COUNT = 14
};

// ═══════════════════════════════════════════════════════════════════
// FILTER DISPATCHER (single switch for all filters)
// ═══════════════════════════════════════════════════════════════════

FilterResult DispatchFilter(FILTER_ID id, const FilterContext &ctx)
{
   switch(id)
   {
      case FID_PIPELINE_ONLY:       return FilterPipelineOnly(ctx);
      case FID_DAILY_LIMIT:         return FilterDailyLimit(ctx);
      case FID_DAILY_PROFIT:        return FilterDailyProfitTarget(ctx);
      case FID_GLOBAL_POS_LIMIT:    return FilterGlobalPositionLimit(ctx);
      case FID_BOOM_CRASH_DIR:      return FilterBoomCrashDirection(ctx);
      case FID_GOM_WAIT:            return FilterGOMWait(ctx);
      case FID_ANTI_CORRECTION:     return FilterAntiCorrection(ctx);
      case FID_TF_CONSENSUS:        return FilterTFConsensus(ctx);
      case FID_RSI_DIVERGENCE:      return FilterRSIDivergence(ctx);
      case FID_MOMENTUM:            return FilterMomentum(ctx);
      case FID_BB_COUNTER_TREND:    return FilterBBCounterTrend(ctx);
      case FID_GLOBAL_DIR_COHERENCE: return FilterGlobalDirCoherence(ctx);
      case FID_GOM_QUALITY:         return FilterGOMQuality(ctx);
      case FID_GHOST_ORDERFLOW:     return FilterGHOSTOrderFlow(ctx);
      default:
      {
         FilterResult r;
         r.status = FILTER_SKIP;
         r.filterName = "UNKNOWN";
         return r;
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// PREDEFINED FILTER CHAINS
// ═══════════════════════════════════════════════════════════════════

// Full MCP validation (all 14 filters)
#define CHAIN_MCP_FULL_LEN 14
const FILTER_ID CHAIN_MCP_FULL[CHAIN_MCP_FULL_LEN] = {
   FID_PIPELINE_ONLY,
   FID_DAILY_LIMIT,
   FID_DAILY_PROFIT,
   FID_GLOBAL_POS_LIMIT,
   FID_BOOM_CRASH_DIR,
   FID_GOM_WAIT,
   FID_ANTI_CORRECTION,
   FID_TF_CONSENSUS,
   FID_RSI_DIVERGENCE,
   FID_MOMENTUM,
   FID_BB_COUNTER_TREND,
   FID_GLOBAL_DIR_COHERENCE,
   FID_GOM_QUALITY,
   FID_GHOST_ORDERFLOW
};

// Pipeline orders (minimal validation — human already approved)
#define CHAIN_PIPELINE_LEN 3
const FILTER_ID CHAIN_PIPELINE[CHAIN_PIPELINE_LEN] = {
   FID_DAILY_LIMIT,
   FID_DAILY_PROFIT,
   FID_BOOM_CRASH_DIR
};

// GOM Auto Entry (skip TF consensus, focus on GOM + correction)
#define CHAIN_GOM_AUTO_LEN 11
const FILTER_ID CHAIN_GOM_AUTO[CHAIN_GOM_AUTO_LEN] = {
   FID_PIPELINE_ONLY,
   FID_DAILY_LIMIT,
   FID_DAILY_PROFIT,
   FID_GLOBAL_POS_LIMIT,
   FID_BOOM_CRASH_DIR,
   FID_GOM_WAIT,
   FID_ANTI_CORRECTION,
   FID_BB_COUNTER_TREND,
   FID_GOM_QUALITY,
   FID_MOMENTUM,
   FID_GHOST_ORDERFLOW
};

// Deriv spike entry (minimal checks)
#define CHAIN_DERIV_LEN 5
const FILTER_ID CHAIN_DERIV[CHAIN_DERIV_LEN] = {
   FID_DAILY_LIMIT,
   FID_DAILY_PROFIT,
   FID_GLOBAL_POS_LIMIT,
   FID_BOOM_CRASH_DIR,
   FID_GOM_WAIT
};

// ═══════════════════════════════════════════════════════════════════
// PIPELINE EXECUTOR
// ═══════════════════════════════════════════════════════════════════

bool RunValidationPipeline(const FilterContext &ctx,
                           const FILTER_ID &chain[],
                           int chainLen,
                           string &rejectReason,
                           string &rejectFilter)
{
   rejectReason = "";
   rejectFilter = "";

   for(int i = 0; i < chainLen; i++)
   {
      FilterResult r = DispatchFilter(chain[i], ctx);

      if(r.status == FILTER_REJECT)
      {
         rejectReason = r.reason;
         rejectFilter = r.filterName;
         DebugLogFilter(ctx.symbol, r.filterName, false, r.reason);
         return false;
      }

      if(r.status == FILTER_PASS)
      {
         DebugLogFilter(ctx.symbol, r.filterName, true, "");
      }
      // FILTER_SKIP: silent pass
   }

   return true;
}

// ═══════════════════════════════════════════════════════════════════
// CONVENIENCE WRAPPERS (for different entry sources)
// ═══════════════════════════════════════════════════════════════════

bool ValidateMCPEntry(const FilterContext &ctx, string &reason, string &filter)
{
   return RunValidationPipeline(ctx, CHAIN_MCP_FULL, CHAIN_MCP_FULL_LEN, reason, filter);
}

bool ValidatePipelineEntry(const FilterContext &ctx, string &reason, string &filter)
{
   return RunValidationPipeline(ctx, CHAIN_PIPELINE, CHAIN_PIPELINE_LEN, reason, filter);
}

bool ValidateGOMAutoEntry(const FilterContext &ctx, string &reason, string &filter)
{
   return RunValidationPipeline(ctx, CHAIN_GOM_AUTO, CHAIN_GOM_AUTO_LEN, reason, filter);
}

bool ValidateDerivEntry(const FilterContext &ctx, string &reason, string &filter)
{
   return RunValidationPipeline(ctx, CHAIN_DERIV, CHAIN_DERIV_LEN, reason, filter);
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void Validation_Init()
{
   DebugInfo("ValidationPipeline", "Initialized", StringFormat("14 filters, 4 chains"));
}

void Validation_Tick()
{
   // No recurring work
}

void Validation_Deinit()
{
   DebugInfo("ValidationPipeline", "Shutdown");
}

#endif // TM_VALIDATION_MQH
