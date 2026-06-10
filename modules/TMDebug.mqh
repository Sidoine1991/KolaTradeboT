//+------------------------------------------------------------------+
//| TMDebug.mqh — Unified logging with context prefixing            |
//+------------------------------------------------------------------+
#ifndef TM_DEBUG_MQH
#define TM_DEBUG_MQH

#include "TMState.mqh"

// ═══════════════════════════════════════════════════════════════════
// DEBUG LEVELS
// ═══════════════════════════════════════════════════════════════════

enum DEBUG_LEVEL
{
   DBG_ERROR = 0,      // Critical errors only
   DBG_WARN = 1,       // Warnings + errors
   DBG_INFO = 2,       // Info + warnings + errors (default)
   DBG_DETAIL = 3,     // Detailed trace (verbose)
   DBG_TRACE = 4       // Full trace (very verbose)
};

// ═══════════════════════════════════════════════════════════════════
// GLOBAL DEBUG SETTING
// ═══════════════════════════════════════════════════════════════════

DEBUG_LEVEL g_debugLevel = DBG_INFO;
bool        g_debugToFile = false;
string      g_debugFilePath = "logs/tradbot_debug.log";

// ═══════════════════════════════════════════════════════════════════
// LOGGING FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

string DebugLevelToString(DEBUG_LEVEL level)
{
   switch(level)
   {
      case DBG_ERROR:  return "ERROR";
      case DBG_WARN:   return "WARN";
      case DBG_INFO:   return "INFO";
      case DBG_DETAIL: return "DETAIL";
      case DBG_TRACE:  return "TRACE";
      default:         return "UNKNOWN";
   }
}

void DebugLog(DEBUG_LEVEL level, const string module, const string message, const string context = "")
{
   if(level > g_debugLevel) return;  // Skip if below threshold

   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   string levelStr = DebugLevelToString(level);
   string logLine = StringFormat("[%s] %s [%s] %s", timestamp, levelStr, module, message);

   if(context != "")
      logLine += " | " + context;

   Print(logLine);

   if(g_debugToFile)
   {
      int handle = FileOpen(g_debugFilePath, FILE_READ | FILE_WRITE | FILE_TXT);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, logLine);
         FileClose(handle);
      }
   }
}

void DebugError(const string module, const string message, const string context = "")
{
   DebugLog(DBG_ERROR, module, message, context);
}

void DebugWarn(const string module, const string message, const string context = "")
{
   DebugLog(DBG_WARN, module, message, context);
}

void DebugInfo(const string module, const string message, const string context = "")
{
   DebugLog(DBG_INFO, module, message, context);
}

void DebugDetail(const string module, const string message, const string context = "")
{
   DebugLog(DBG_DETAIL, module, message, context);
}

void DebugTrace(const string module, const string message, const string context = "")
{
   DebugLog(DBG_TRACE, module, message, context);
}

// ═══════════════════════════════════════════════════════════════════
// SPECIALIZED LOGGERS
// ═══════════════════════════════════════════════════════════════════

void DebugLogHTTP(const string endpoint, int statusCode, int elapsedMs, const string errorMsg = "")
{
   string ctx = StringFormat("code=%d elapsed=%dms", statusCode, elapsedMs);
   if(errorMsg != "") ctx += " error=" + errorMsg;
   DebugDetail("HTTPTransport", endpoint, ctx);
}

void DebugLogSignal(const string symbol, int direction, double entry, double sl, double tp, const string source)
{
   string dir = (direction == 1) ? "BUY" : "SELL";
   string ctx = StringFormat("entry=%.5f sl=%.5f tp=%.5f source=%s", entry, sl, tp, source);
   DebugInfo("Signal", StringFormat("%s %s", symbol, dir), ctx);
}

void DebugLogGOMVerdict(const string symbol, const string verdict, int vnum, double quality, double coherence)
{
   string ctx = StringFormat("vnum=%d quality=%.1f%% coherence=%.1f%%", vnum, quality, coherence);
   DebugDetail("GOMIntegration", StringFormat("%s: %s", symbol, verdict), ctx);
}

void DebugLogFilter(const string symbol, const string filterName, bool passed, const string reason = "")
{
   string status = passed ? "PASS" : "REJECT";
   DebugTrace("ValidationPipeline", StringFormat("%s %s filter", symbol, filterName),
              StringFormat("status=%s %s", status, reason));
}

void DebugLogPosition(ulong ticket, const string symbol, int direction, double entry,
                      double sl, double tp, double lot)
{
   string dir = (direction == 1) ? "BUY" : "SELL";
   string ctx = StringFormat("entry=%.5f sl=%.5f tp=%.5f lot=%.2f", entry, sl, tp, lot);
   DebugInfo("Position", StringFormat("Opened #%llu %s %s", ticket, symbol, dir), ctx);
}

void DebugLogClose(ulong ticket, const string symbol, int direction, double closePrice,
                   double profit, const string reason)
{
   string dir = (direction == 1) ? "BUY" : "SELL";
   string ctx = StringFormat("close=%.5f profit=%.2f reason=%s", closePrice, profit, reason);
   string profitEmoji = (profit >= 0) ? "✅" : "❌";
   DebugInfo("Position", StringFormat("Closed #%llu %s %s %s", ticket, symbol, dir, profitEmoji), ctx);
}

void DebugLogError(const string module, const string errorDesc, const string recoveryAction = "")
{
   DebugError(module, errorDesc);
   if(recoveryAction != "")
      DebugInfo(module, "Recovery: " + recoveryAction);
}

// ═══════════════════════════════════════════════════════════════════
// STATE SNAPSHOT LOGGING
// ═══════════════════════════════════════════════════════════════════

void DebugDumpGOMState()
{
   DebugDetail("GOM", "Snapshot",
      StringFormat("verdict=%s vnum=%d quality=%.1f coherence=%.1f globalDir=%s globalStrength=%d",
                   g_state.gom.verdict, g_state.gom.verdictNum, g_state.gom.quality,
                   g_state.gom.coherence, g_state.gom.globalDir, g_state.gom.globalStrength));
}

void DebugDumpDisciplineState()
{
   DebugDetail("Discipline", "Snapshot",
      StringFormat("trades=%d wins=%d losses=%d profit=%.2f dailyTarget=%s dailyTradeCount=%d/%d",
                   g_state.discipline.totalLosses + g_state.discipline.totalWins,
                   g_state.discipline.totalWins, g_state.discipline.totalLosses,
                   g_state.discipline.totalProfitWins - g_state.discipline.totalLossAmount,
                   g_state.discipline.dailyTargetHit ? "HIT" : "ACTIVE",
                   g_state.discipline.dailyTradeCount, g_state.discipline.maxDailyTrades));
}

void DebugDumpConfig()
{
   DebugDetail("Config", "Execution Mode",
      StringFormat("pipelineOnly=%d mcpSignals=%d gomScalp=%d trailing=%d deriv=%d",
                   g_state.config.pipelineOnlyMode ? 1 : 0,
                   g_state.config.useMCPSignals ? 1 : 0,
                   g_state.config.useGOMScalp ? 1 : 0,
                   g_state.config.useTrailing ? 1 : 0,
                   g_state.config.useDerivEngine ? 1 : 0));
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void Debug_Init()
{
   DebugInfo("Debug", "Logging initialized", StringFormat("level=%s", DebugLevelToString(g_debugLevel)));
}

void Debug_Tick()
{
   // No recurring debug work
}

void Debug_Deinit()
{
   DebugInfo("Debug", "Logging closed");
}

// ═══════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════

void SetDebugLevel(DEBUG_LEVEL level)
{
   g_debugLevel = level;
   DebugInfo("Debug", StringFormat("Level changed to %s", DebugLevelToString(level)));
}

void SetDebugFile(bool enable, const string filepath = "logs/tradbot_debug.log")
{
   g_debugToFile = enable;
   g_debugFilePath = filepath;
   if(enable)
      DebugInfo("Debug", StringFormat("File logging enabled: %s", filepath));
}

#endif // TM_DEBUG_MQH
