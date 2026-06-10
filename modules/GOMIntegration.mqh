//+------------------------------------------------------------------+
//| GOMIntegration.mqh — Poll /gom-verdict, detect corrections, entry|
//+------------------------------------------------------------------+
#ifndef TM_GOM_INTEGRATION_MQH
#define TM_GOM_INTEGRATION_MQH

#include "TMState.mqh"
#include "HTTPTransport.mqh"
#include "ValidationPipeline.mqh"
#include "TMEvents.mqh"
#include "TMDebug.mqh"
#include "Notifications.mqh"

// ═══════════════════════════════════════════════════════════════════
// POLL GOM VERDICT FROM TRADINGVIEW
// ═══════════════════════════════════════════════════════════════════

void GOM_PollVerdict()
{
   // Rate limit
   if(TimeCurrent() - g_state.timing.lastGOMPoll < g_state.config.gomPollIntervalSec)
      return;

   g_state.timing.lastGOMPoll = TimeCurrent();

   HTTPResponse resp = HTTP_GetGOMVerdict(_Symbol);
   if(!resp.success)
   {
      DebugWarn("GOM", "Poll failed", StringFormat("code=%d", resp.code));
      return;
   }

   // Parse JSON: {"verdict":"GOOD BUY","vnum":2,"quality":75.5,"coherence":80.2,"rsi":45,"globalDir":"BULL","globalStrength":72, ... }
   string verdict = "";
   int vnum = 999;
   double quality = 0.0, coherence = 0.0;
   int rsi = 50;
   string globalDir = "NEUT";
   int globalStrength = 0;
   double bbUp = 0.0, bbMid = 0.0, bbDn = 0.0;
   double kolaBuy = 0.0, kolaSell = 0.0;
   string kolaState = "NEUTRAL";
   double buyPct = 50.0;
   double compass = 0.0;
   string predPath = "";

   JsonGetString(resp.body, "verdict", verdict);
   JsonGetInt(resp.body, "vnum", vnum);
   JsonGetDouble(resp.body, "quality", quality);
   JsonGetDouble(resp.body, "coherence", coherence);
   JsonGetInt(resp.body, "rsi", rsi);
   JsonGetString(resp.body, "globalDir", globalDir);
   JsonGetInt(resp.body, "globalStrength", globalStrength);
   JsonGetDouble(resp.body, "bbUp", bbUp);
   JsonGetDouble(resp.body, "bbMid", bbMid);
   JsonGetDouble(resp.body, "bbDn", bbDn);
   JsonGetDouble(resp.body, "kolaBuy", kolaBuy);
   JsonGetDouble(resp.body, "kolaSell", kolaSell);
   JsonGetString(resp.body, "kolaState", kolaState);
   JsonGetDouble(resp.body, "buyPct", buyPct);  // GHOST sentiment
   JsonGetDouble(resp.body, "compass", compass);  // GHOST momentum
   JsonGetString(resp.body, "predPath", predPath);  // Predictive path

   // Update state
   g_state.gom.verdict = verdict;
   g_state.gom.verdictNum = vnum;
   g_state.gom.quality = quality;
   g_state.gom.coherence = coherence;
   g_state.gom.rsi = rsi;
   g_state.gom.globalDir = globalDir;
   g_state.gom.globalStrength = globalStrength;
   g_state.gom.bbUp = bbUp;
   g_state.gom.bbMid = bbMid;
   g_state.gom.bbDn = bbDn;
   g_state.gom.kolaBuy = kolaBuy;
   g_state.gom.kolaSell = kolaSell;
   g_state.gom.kolaState = kolaState;
   g_state.ghost.buyPct = buyPct;
   g_state.ghost.compass = compass;
   g_state.pred.predPath = predPath;

   DebugLogGOMVerdict(_Symbol, verdict, vnum, quality, coherence);
   Event_GOMUpdate();
}

// ═══════════════════════════════════════════════════════════════════
// CORRECTION DETECTION
// ═══════════════════════════════════════════════════════════════════

bool GOM_IsCorrection()
{
   if(!g_state.config.gomBlockCorrectionZone)
      return false;

   if(g_state.gom.verdictNum == 0)
      return false;  // WAIT = consolidation, not correction

   // Correction signature: pred_path shows alternate direction OR
   // coherence is low + kolaState contradicts verdict
   if(g_state.gom.coherence < g_state.config.globalMinCoherencePct)
      return true;  // Low coherence = consolidation = correction

   // Check if pred_path alternates too much (corrective wave)
   if(g_state.pred.predPath != "" && StringLen(g_state.pred.predPath) > g_state.config.gomCorrectionPathLook)
   {
      string recentPath = StringSubstr(g_state.pred.predPath, 0, g_state.config.gomCorrectionPathLook);
      int upCount = 0, downCount = 0;

      for(int i = 0; i < StringLen(recentPath); i++)
      {
         if(recentPath[i] == 'U') upCount++;
         if(recentPath[i] == 'D') downCount++;
      }

      int alternations = MathMin(upCount, downCount);
      if(alternations >= g_state.config.gomCorrectionMinBars)
      {
         DebugDetail("GOM", "Correction detected", StringFormat("path alternations=%d", alternations));
         return true;
      }
   }

   return false;
}

// ═══════════════════════════════════════════════════════════════════
// AUTO ENTRY (when GOM signals GOOD/PERFECT)
// ═══════════════════════════════════════════════════════════════════

void GOM_CheckAutoEntry()
{
   if(!g_state.config.useGOMAutoEntry)
      return;

   if(g_state.gom.verdictNum == 0)
      return;  // WAIT

   // Cooldown
   if(TimeCurrent() - g_state.timing.lastGOMAutoEntry < g_state.config.gomAutoEntryCooldownSec)
      return;

   // Quality threshold
   if(g_state.gom.quality < g_state.config.gomMinQuality)
      return;

   // Correction check
   if(GOM_IsCorrection())
   {
      DebugDetail("GOM", "AutoEntry blocked", "Correction detected");
      Event_CorrectionDetected(_Symbol);
      return;
   }

   // ───────────────────────────────────────────────────────────────
   // DETERMINE DIRECTION
   // ───────────────────────────────────────────────────────────────

   int direction = 0;
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_state.gom.verdictNum > 0)  // BUY bias
   {
      direction = 1;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   else if(g_state.gom.verdictNum < 0)  // SELL bias
   {
      direction = -1;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }

   // ───────────────────────────────────────────────────────────────
   // VALIDATE
   // ───────────────────────────────────────────────────────────────

   FilterContext ctx;
   ctx.symbol = _Symbol;
   ctx.direction = direction;
   ctx.entryPrice = entry;
   ctx.stopLoss = entry - (g_state.gom.bbMid - g_state.gom.bbDn);  // Use BB width
   ctx.takeProfit = entry + (g_state.gom.bbUp - g_state.gom.bbMid);
   ctx.source = "gom_auto";
   ctx.isPipeline = false;

   string rejectReason = "", rejectFilter = "";
   if(!ValidateGOMAutoEntry(ctx, rejectReason, rejectFilter))
   {
      DebugDetail("GOM", "AutoEntry rejected", rejectReason);
      return;
   }

   // ───────────────────────────────────────────────────────────────
   // EXECUTE (minimal — just signal, don't execute directly)
   // ───────────────────────────────────────────────────────────────

   g_state.timing.lastGOMAutoEntry = TimeCurrent();
   DebugInfo("GOM", "AutoEntry signal ready", StringFormat("%s %s", _Symbol, direction==1?"BUY":"SELL"));
   SendWAAlert("GOM AutoEntry", StringFormat("%s %s @ %.5f (quality=%.0f%% coherence=%.0f%%)",
              _Symbol, direction==1?"BUY":"SELL", entry, g_state.gom.quality, g_state.gom.coherence));
   Event_MCPSignalReceived(_Symbol, direction);
}

// ═══════════════════════════════════════════════════════════════════
// RE-ENTRY ON PULLBACK (when GOM realigns after correction)
// ═══════════════════════════════════════════════════════════════════

void GOM_CheckReEntry()
{
   if(!g_state.config.useGOMReEntry)
      return;

   // Check for existing re-entry opportunity
   int reIdx = FindGOMReEntry(_Symbol);
   if(reIdx >= 0)
   {
      // Waiting for re-entry pullback
      if(TimeCurrent() - g_state.gomReEntries[reIdx].closedAt > 300)  // 5 min timeout
      {
         g_state.gomReEntries[reIdx].active = false;
         DebugDetail("GOM", "ReEntry timeout", _Symbol);
      }
      return;
   }

   // No active re-entry, nothing to do
   // (Re-entries are typically triggered by TrailingStop closure)
}

// ═══════════════════════════════════════════════════════════════════
// INGEST RE-ENTRY (called by TrailingStop when position closes)
// ═══════════════════════════════════════════════════════════════════

void GOM_RegisterReEntry(const string symbol, int lastDirection, double closePrice)
{
   if(!g_state.config.useGOMReEntry)
      return;

   // Check if we should re-enter
   if(g_state.gom.verdictNum == 0)
      return;  // WAIT = no re-entry

   if(TimeCurrent() - g_state.timing.lastGOMReEntry < g_state.config.gomReEntryCooldownSec)
      return;  // Cooldown

   int reEntryIdx = FindGOMReEntry(symbol);
   if(reEntryIdx >= 0)
      return;  // Already have pending re-entry

   // Create re-entry opportunity
   int idx = AddGOMReEntry();
   g_state.gomReEntries[idx].active = true;
   g_state.gomReEntries[idx].symbol = symbol;
   g_state.gomReEntries[idx].direction = (g_state.gom.verdictNum > 0) ? 1 : -1;
   g_state.gomReEntries[idx].entryPrice = (g_state.gom.verdictNum > 0) ?
                                           SymbolInfoDouble(symbol, SYMBOL_ASK) :
                                           SymbolInfoDouble(symbol, SYMBOL_BID);
   g_state.gomReEntries[idx].stopLoss = g_state.gomReEntries[idx].entryPrice -
                                        (g_state.gom.bbMid - g_state.gom.bbDn);
   g_state.gomReEntries[idx].takeProfit = g_state.gomReEntries[idx].entryPrice +
                                          (g_state.gom.bbUp - g_state.gom.bbMid);
   g_state.gomReEntries[idx].lot = g_state.config.gomReEntryLot;
   g_state.gomReEntries[idx].closedAt = TimeCurrent();
   g_state.gomReEntries[idx].reEntryCount = 0;

   g_state.timing.lastGOMReEntry = TimeCurrent();
   DebugInfo("GOM", "ReEntry registered", StringFormat("%s %s", symbol, g_state.gom.verdictNum>0?"BUY":"SELL"));
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void GOM_Init()
{
   g_state.gom.verdictNum = 999;  // Uninit
   g_state.timing.lastGOMPoll = 0;
   g_state.timing.lastGOMAutoEntry = 0;
   g_state.timing.lastGOMReEntry = 0;
   DebugInfo("GOMIntegration", "Initialized", "Ready to poll /gom-verdict");
}

void GOM_Tick()
{
   GOM_PollVerdict();
   GOM_CheckAutoEntry();
   GOM_CheckReEntry();
}

void GOM_Deinit()
{
   DebugInfo("GOMIntegration", "Shutdown", StringFormat("last verdict=%s", g_state.gom.verdict));
}

#endif // TM_GOM_INTEGRATION_MQH
