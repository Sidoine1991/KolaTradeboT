//+------------------------------------------------------------------+
//| Dashboard.mqh — Real-time display of GOM, discipline, filter stats|
//+------------------------------------------------------------------+
#ifndef TM_DASHBOARD_MQH
#define TM_DASHBOARD_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"

// ═══════════════════════════════════════════════════════════════════
// DASHBOARD RENDERING
// ═══════════════════════════════════════════════════════════════════

void Dash_DrawCell(int row, const string label, const string value, color bgColor, color textColor)
{
   int x = g_state.config.dashboardX;
   int y = g_state.config.dashboardY + (row * g_state.config.rowHeight);

   string objName = StringFormat("DASH_ROW_%d", row);

   // Create rectangle background
   string rectName = objName + "_BG";
   ObjectCreate(0, rectName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, rectName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, rectName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, rectName, OBJPROP_XSIZE, g_state.config.panelWidth);
   ObjectSetInteger(0, rectName, OBJPROP_YSIZE, g_state.config.rowHeight);
   ObjectSetInteger(0, rectName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, rectName, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // Create text
   string textName = objName + "_TEXT";
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, y + 3);
   ObjectSetString(0, textName, OBJPROP_TEXT, StringFormat("%s: %s", label, value));
   ObjectSetInteger(0, textName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, g_state.config.fontSize);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
}

void Dash_Clear()
{
   // Remove all dashboard objects
   for(int row = 0; row < 20; row++)
   {
      string rectName = StringFormat("DASH_ROW_%d_BG", row);
      string textName = StringFormat("DASH_ROW_%d_TEXT", row);
      ObjectDelete(0, rectName);
      ObjectDelete(0, textName);
   }
}

void Dash_RefreshDisplay()
{
   int row = 0;

   // ─────────────────────────────────────────────────────────────
   // Header: GOM Status
   // ─────────────────────────────────────────────────────────────

   string gomVerdict = g_state.gom.verdict;
   color gomColor = (g_state.gom.verdictNum > 0) ? g_state.config.colorBuy :
                    (g_state.gom.verdictNum < 0) ? g_state.config.colorSell :
                    g_state.config.colorNeutral;
   color gomHeaderColor = (g_state.gom.verdictNum > 0) ? g_state.config.colorHeaderBuy :
                          (g_state.gom.verdictNum < 0) ? g_state.config.colorHeaderSell :
                          g_state.config.colorNeutral;

   Dash_DrawCell(row++, "GOM", gomVerdict, gomHeaderColor, g_state.config.colorText);

   // ─────────────────────────────────────────────────────────────
   // Quality & Coherence
   // ─────────────────────────────────────────────────────────────

   Dash_DrawCell(row++, "Quality", StringFormat("%.1f%%", g_state.gom.quality), g_state.config.colorBackground, gomColor);
   Dash_DrawCell(row++, "Coherence", StringFormat("%.1f%%", g_state.gom.coherence), g_state.config.colorBackground, gomColor);

   // ─────────────────────────────────────────────────────────────
   // Global Direction
   // ─────────────────────────────────────────────────────────────

   color globalColor = (StringFind(g_state.gom.globalDir, "BULL") >= 0) ? g_state.config.colorBuy :
                       (StringFind(g_state.gom.globalDir, "BEAR") >= 0) ? g_state.config.colorSell :
                       g_state.config.colorNeutral;
   Dash_DrawCell(row++, "Global", StringFormat("%s (%d%%)", g_state.gom.globalDir, g_state.gom.globalStrength),
                g_state.config.colorBackground, globalColor);

   row++;  // Space

   // ─────────────────────────────────────────────────────────────
   // Discipline: Trade Counter
   // ─────────────────────────────────────────────────────────────

   string tradeCountStr = StringFormat("%d/%d", g_state.discipline.dailyTradeCount, g_state.discipline.maxDailyTrades);
   color tradeCountColor = (g_state.discipline.dailyTradeCount >= g_state.discipline.maxDailyTrades) ?
                           g_state.config.colorSell : g_state.config.colorBuy;
   Dash_DrawCell(row++, "Trades (Daily)", tradeCountStr, g_state.config.colorBackground, tradeCountColor);

   // ─────────────────────────────────────────────────────────────
   // Win/Loss Stats
   // ─────────────────────────────────────────────────────────────

   int totalTrades = g_state.discipline.totalWins + g_state.discipline.totalLosses;
   double winRate = (totalTrades > 0) ? (double)g_state.discipline.totalWins / totalTrades * 100.0 : 0.0;
   string winLossStr = StringFormat("%d/%d (%.0f%%)", g_state.discipline.totalWins, g_state.discipline.totalLosses, winRate);
   color winLossColor = (g_state.discipline.totalWins >= g_state.discipline.totalLosses) ?
                        g_state.config.colorBuy : g_state.config.colorSell;
   Dash_DrawCell(row++, "W/L", winLossStr, g_state.config.colorBackground, winLossColor);

   // ─────────────────────────────────────────────────────────────
   // Profit/Loss
   // ─────────────────────────────────────────────────────────────

   double dailyProfit = g_state.discipline.totalProfitWins - g_state.discipline.totalLossAmount;
   string profitStr = StringFormat("%.2f$", dailyProfit);
   color profitColor = (dailyProfit >= 0) ? g_state.config.colorBuy : g_state.config.colorSell;
   Dash_DrawCell(row++, "P&L", profitStr, g_state.config.colorBackground, profitColor);

   // ─────────────────────────────────────────────────────────────
   // Daily Target Status
   // ─────────────────────────────────────────────────────────────

   string targetStr = g_state.discipline.dailyTargetHit ? "✓ HIT" : StringFormat("%.2f$ / %.2f$",
                      dailyProfit, g_state.discipline.dailyProfitTarget);
   color targetColor = g_state.discipline.dailyTargetHit ? g_state.config.colorBuy : g_state.config.colorNeutral;
   Dash_DrawCell(row++, "Daily Target", targetStr, g_state.config.colorBackground, targetColor);

   row++;  // Space

   // ─────────────────────────────────────────────────────────────
   // Validation Pipeline Status
   // ─────────────────────────────────────────────────────────────

   int filtersPassed = 0;
   // Count total available filters (placeholder — would track actual filter passes)
   int totalFilters = 14;
   string robustStr = StringFormat("%d/%d ✓", filtersPassed, totalFilters);
   Dash_DrawCell(row++, "Robust", robustStr, g_state.config.colorBackground, g_state.config.colorBuy);

   // ─────────────────────────────────────────────────────────────
   // Correction Status
   // ─────────────────────────────────────────────────────────────

   string correctionStr = (g_state.gom.coherence < g_state.config.globalMinCoherencePct) ? "ACTIVE" : "CLEAR";
   color correctionColor = (g_state.gom.coherence < g_state.config.globalMinCoherencePct) ?
                           g_state.config.colorSell : g_state.config.colorBuy;
   Dash_DrawCell(row++, "Correction", correctionStr, g_state.config.colorBackground, correctionColor);

   // ─────────────────────────────────────────────────────────────
   // Open Positions
   // ─────────────────────────────────────────────────────────────

   int openPos = PositionsTotal();
   string posStr = StringFormat("%d/%d", openPos, g_state.config.maxGlobalPositions);
   color posColor = (openPos > 0) ? g_state.config.colorBuy : g_state.config.colorNeutral;
   Dash_DrawCell(row++, "Positions", posStr, g_state.config.colorBackground, posColor);
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void Dash_Init()
{
   DebugInfo("Dashboard", "Initialized", StringFormat("width=%d rowHeight=%d fontSize=%d",
            g_state.config.panelWidth, g_state.config.rowHeight, g_state.config.fontSize));
}

void Dash_Tick()
{
   if(!g_state.config.useDashboard)
      return;

   // Refresh at interval
   if(TimeCurrent() - g_state.timing.lastDashboardUpdate < g_state.config.dashboardUpdateSec)
      return;

   g_state.timing.lastDashboardUpdate = TimeCurrent();

   Dash_Clear();
   Dash_RefreshDisplay();
}

void Dash_Deinit()
{
   Dash_Clear();
   DebugInfo("Dashboard", "Shutdown", "Objects cleared");
}

#endif // TM_DASHBOARD_MQH
