//+------------------------------------------------------------------+
//| Notifications.mqh — WhatsApp + trade event notifications         |
//+------------------------------------------------------------------+
#ifndef TM_NOTIFICATIONS_MQH
#define TM_NOTIFICATIONS_MQH

#include "TMState.mqh"
#include "HTTPTransport.mqh"

// ═══════════════════════════════════════════════════════════════════
// WHATSAPP MESSAGE FORMATTING
// ═══════════════════════════════════════════════════════════════════

string FormatWAOrderEntry(const string symbol, int direction, double entry,
                          double sl, double tp, double lot, const string reason)
{
   string dir = (direction == 1) ? "BUY" : "SELL";
   string msg = StringFormat(
      "📊 %s %s\nEntry: %.5f\nSL: %.5f\nTP: %.5f\nLot: %.2f\nReason: %s",
      symbol, dir, entry, sl, tp, lot, reason
   );
   return msg;
}

string FormatWAOrderClose(const string symbol, int direction, double entry,
                          double closePrice, double profit, const string reason)
{
   string dir = (direction == 1) ? "BUY" : "SELL";
   string profitStr = (profit >= 0) ? StringFormat("+%.2f$", profit) : StringFormat("%.2f$", profit);
   string emoji = (profit >= 0) ? "✅" : "❌";
   string msg = StringFormat(
      "%s %s %s CLOSED\nEntry: %.5f\nClose: %.5f\nProfit: %s\nReason: %s",
      emoji, symbol, dir, entry, closePrice, profitStr, reason
   );
   return msg;
}

string FormatWAGOMUpdate(const string symbol, const string verdict,
                         double quality, double coherence)
{
   string msg = StringFormat(
      "🎯 GOM UPDATE: %s\nVerdict: %s\nQuality: %.1f%%\nCoherence: %.1f%%",
      symbol, verdict, quality, coherence
   );
   return msg;
}

string FormatWADailyStats(int wins, int losses, double profit, int trades)
{
   double winRate = (trades > 0) ? (double)wins / trades * 100.0 : 0.0;
   string profitStr = (profit >= 0) ? StringFormat("+%.2f$", profit) : StringFormat("%.2f$", profit);
   string msg = StringFormat(
      "📈 DAILY STATS\nTrades: %d\nWins: %d | Losses: %d\nWin Rate: %.1f%%\nProfit: %s",
      trades, wins, losses, winRate, profitStr
   );
   return msg;
}

string FormatWAAlert(const string title, const string detail)
{
   return StringFormat("⚠️ %s\n%s", title, detail);
}

// ═══════════════════════════════════════════════════════════════════
// WHATSAPP SENDING
// ═══════════════════════════════════════════════════════════════════

bool SendWAEvent(const string message, const string eventType = "INFO")
{
   if(!g_state.config.useWhatsApp) return false;
   if(message == "") return false;

   string json = StringFormat(
      "{\"message\":\"%s\",\"event_type\":\"%s\",\"timestamp\":%lld}",
      message, eventType, TimeCurrent()
   );

   // Escape quotes in message for JSON
   json = StringReplace(json, "\"", "\\\"");
   json = StringFormat("{\"message\":\"%s\",\"event_type\":\"%s\",\"timestamp\":%lld}",
                       StringReplace(message, "\"", "\\\""), eventType, TimeCurrent());

   HTTPResponse resp = HTTP_NotifyWhatsApp(json);
   bool success = resp.success;

   if(!success)
   {
      PrintFormat("[Notifications] WhatsApp send failed: %s", resp.error);
   }

   return success;
}

bool SendWAOrderEntry(const string symbol, int direction, double entry,
                      double sl, double tp, double lot, const string reason)
{
   string msg = FormatWAOrderEntry(symbol, direction, entry, sl, tp, lot, reason);
   return SendWAEvent(msg, "ORDER_ENTRY");
}

bool SendWAOrderClose(const string symbol, int direction, double entry,
                      double closePrice, double profit, const string reason)
{
   string msg = FormatWAOrderClose(symbol, direction, entry, closePrice, profit, reason);
   string eventType = (profit >= 0) ? "ORDER_WIN" : "ORDER_LOSS";
   return SendWAEvent(msg, eventType);
}

bool SendWAGOMUpdate(const string symbol, const string verdict,
                     double quality, double coherence)
{
   string msg = FormatWAGOMUpdate(symbol, verdict, quality, coherence);
   return SendWAEvent(msg, "GOM_UPDATE");
}

bool SendWADailyStats(int wins, int losses, double profit, int trades)
{
   string msg = FormatWADailyStats(wins, losses, profit, trades);
   return SendWAEvent(msg, "DAILY_STATS");
}

bool SendWAAlert(const string title, const string detail)
{
   string msg = FormatWAAlert(title, detail);
   return SendWAEvent(msg, "ALERT");
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void Notif_Init()
{
   // Nothing to initialize
}

void Notif_Tick()
{
   // No recurring notifications in Tick
   // Notifications are event-driven (called from other modules)
}

void Notif_Deinit()
{
   // Cleanup if needed
}

#endif // TM_NOTIFICATIONS_MQH
