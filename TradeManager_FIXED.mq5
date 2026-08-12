//+------------------------------------------------------------------+
//| TradeManager.mq5 v4.0 — FIXED — Institutional Orchestrator       |
//+------------------------------------------------------------------+
#property copyright "TradBOT Institutional"
#property version   "4.0"
#property strict

#include <Trade/Trade.mqh>

// ═══════════════════════════════════════════════════════════════════
// MODULE INCLUDES
// ═══════════════════════════════════════════════════════════════════

#include "modules/TMState.mqh"
#include "modules/TMDebug.mqh"
#include "modules/TMEvents.mqh"
#include "modules/HTTPTransport.mqh"
#include "modules/Notifications.mqh"
#include "modules/ValidationPipeline.mqh"
#include "modules/RiskManager.mqh"
#include "modules/MCPSignalManager.mqh"
#include "modules/GOMIntegration.mqh"
#include "modules/TVSetupManager.mqh"
#include "modules/TrailingStop.mqh"
#include "modules/DerivEngine.mqh"
#include "modules/Dashboard.mqh"

// ═══════════════════════════════════════════════════════════════════
// INPUT PARAMETERS (simple, no groups for MQL5 compatibility)
// ═══════════════════════════════════════════════════════════════════

input bool   PipelineOnlyMode       = true;
input string AIServerURL            = "http://127.0.0.1:8000";
input int    CheckIntervalSec       = 5;
input bool   UseCapitalManager      = true;
input double CM_DailyTargetPct      = 5.0;
input int    CM_MaxTradesPerDay      = 7;
input double CM_LotRiskPct          = 2.0;
input bool   UseGOMScalp            = true;
input int    GOMPollIntervalSec     = 1;
input bool   UseGOMAutoEntry        = true;
input double GOMMinQuality          = 35.0;
input bool   UseBBTrendFilter       = true;
input bool   UseTrailing            = true;
input double TrailActivateUSD       = 2.0;
input double TrailLockPct           = 0.30;
input bool   UseStagnationExit      = true;
input int    StagnationHoldSec      = 120;
input double StagnationMaxGivebackUSD = 0.60;
input bool   UseTVSetupLimit        = true;
input bool   TVSetupInferFromGOM    = true;
input bool   TVSetupMarketOnBreakout = true;
input bool   UseDerivEngine         = true;
input double DRV_SpikeBodyMult      = 0.50;
input int    DRV_BarsMin            = 8;
input bool   UseDashboard           = true;
input int    DashboardX             = 20;
input int    DashboardY             = 50;
input bool   UseWhatsApp            = true;

// ═══════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════

int OnInit()
{
   // Populate config from inputs
   g_state.config.pipelineOnlyMode = PipelineOnlyMode;
   g_state.config.aiServerURL = AIServerURL;
   g_state.config.checkIntervalSec = CheckIntervalSec;
   g_state.config.useCapitalManager = UseCapitalManager;
   g_state.config.cm_dailyTargetPct = CM_DailyTargetPct;
   g_state.config.cm_maxTradesPerDay = CM_MaxTradesPerDay;
   g_state.config.cm_lotRiskPct = CM_LotRiskPct;
   g_state.config.useGOMScalp = UseGOMScalp;
   g_state.config.gomPollIntervalSec = GOMPollIntervalSec;
   g_state.config.useGOMAutoEntry = UseGOMAutoEntry;
   g_state.config.gomMinQuality = GOMMinQuality;
   g_state.config.useBBTrendFilter = UseBBTrendFilter;
   g_state.config.useTrailing = UseTrailing;
   g_state.config.trailActivateUSD = TrailActivateUSD;
   g_state.config.trailLockPct = TrailLockPct;
   g_state.config.useStagnationExit = UseStagnationExit;
   g_state.config.stagnationHoldSec = StagnationHoldSec;
   g_state.config.stagnationMaxGivebackUSD = StagnationMaxGivebackUSD;
   g_state.config.useTVSetupLimit = UseTVSetupLimit;
   g_state.config.tvSetupInferFromGOM = TVSetupInferFromGOM;
   g_state.config.tvSetupMarketOnBreakout = TVSetupMarketOnBreakout;
   g_state.config.useDerivEngine = UseDerivEngine;
   g_state.config.drv_spikeBodyMult = DRV_SpikeBodyMult;
   g_state.config.drv_barsMin = DRV_BarsMin;
   g_state.config.useDashboard = UseDashboard;
   g_state.config.dashboardX = DashboardX;
   g_state.config.dashboardY = DashboardY;
   g_state.config.useWhatsApp = UseWhatsApp;

   // Initialize modules
   Debug_Init();
   Events_Init();
   Risk_Init();
   MCP_Init();
   GOM_Init();
   TV_Init();
   Trail_Init();
   DRV_Init();
   Dash_Init();
   Validation_Init();

   DebugInfo("TradeManager", "v4.0 initialized successfully", "All modules ready");
   EventSetTimer(CheckIntervalSec);

   return INIT_SUCCEEDED;
}

// ═══════════════════════════════════════════════════════════════════
// DEINITIALIZATION
// ═══════════════════════════════════════════════════════════════════

void OnDeinit(const int reason)
{
   EventKillTimer();

   Dash_Deinit();
   DRV_Deinit();
   Trail_Deinit();
   TV_Deinit();
   GOM_Deinit();
   MCP_Deinit();
   Risk_Deinit();
   Events_Deinit();
   Debug_Deinit();

   DebugInfo("TradeManager", "v4.0 shutdown complete", StringFormat("code=%d", reason));
}

// ═══════════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════════

void OnTimer()
{
   Risk_Tick();
   MCP_Tick();
   GOM_Tick();
   TV_Tick();
   Trail_Tick();
   DRV_Tick();
   Dash_Tick();
}

void OnTick()
{
   // No-op — all logic in OnTimer
}
