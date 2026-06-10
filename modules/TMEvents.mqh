//+------------------------------------------------------------------+
//| TMEvents.mqh — Cross-module event queue                          |
//| Enables modules to signal each other without direct coupling     |
//+------------------------------------------------------------------+
#ifndef TM_EVENTS_MQH
#define TM_EVENTS_MQH

#include "TMState.mqh"

// ═══════════════════════════════════════════════════════════════════
// EVENT TYPE ENUMERATION
// ═══════════════════════════════════════════════════════════════════

enum TM_EVENT_TYPE
{
   EVT_GOM_UPDATE = 0,              // GOM verdict refreshed (bool)
   EVT_MCP_SIGNAL_RECEIVED = 1,     // New pending order ingested (string)
   EVT_POSITION_OPENED = 2,         // Trade executed (ulong ticket)
   EVT_POSITION_CLOSED = 3,         // Position closed (ulong ticket)
   EVT_DAILY_TARGET_HIT = 4,        // Capital manager target reached (double profit)
   EVT_DAILY_STOP_LOSS_HIT = 5,     // Capital manager stop-loss hit (double loss)
   EVT_SETUP_CHANGED = 6,           // TV setup changed (string symbol)
   EVT_SPIKE_DETECTED = 7,          // Deriv spike detected (string symbol)
   EVT_WHITELIST_RELOADED = 8,      // Whitelist refreshed (int count)
   EVT_FILTER_REJECTED = 9,         // Signal rejected by filter (string reason)
   EVT_GRACE_PERIOD_EXPIRED = 10,   // Position 120s hold time passed (ulong ticket)
   EVT_CORRECTION_DETECTED = 11,    // Correction zone entered (string symbol)
   EVT_COUNT = 12
};

// ═══════════════════════════════════════════════════════════════════
// EVENT STRUCT
// ═══════════════════════════════════════════════════════════════════

struct TMEvent
{
   TM_EVENT_TYPE type;
   string        symbol;
   double        value;           // numeric payload
   string        data;            // string payload
   ulong         ticket;          // order/position ticket
   int           direction;       // 1=BUY, -1=SELL
   datetime      timestamp;
};

// ═══════════════════════════════════════════════════════════════════
// EVENT QUEUE (FIFO circular buffer)
// ═══════════════════════════════════════════════════════════════════

#define TM_MAX_EVENTS 64

TMEvent  g_eventQueue[TM_MAX_EVENTS];
int      g_eventHead = 0;
int      g_eventTail = 0;

// ═══════════════════════════════════════════════════════════════════
// EVENT OPERATIONS
// ═══════════════════════════════════════════════════════════════════

void EmitEvent(TM_EVENT_TYPE type, const string symbol = "", double value = 0.0,
               const string data = "", ulong ticket = 0, int direction = 0)
{
   int next = (g_eventTail + 1) % TM_MAX_EVENTS;

   // Queue full: drop oldest event (FIFO behavior)
   if(next == g_eventHead)
   {
      g_eventHead = (g_eventHead + 1) % TM_MAX_EVENTS;
      PrintFormat("[TMEvents] Queue overflow: dropped oldest event, now at %d events",
                  (g_eventTail - g_eventHead + TM_MAX_EVENTS) % TM_MAX_EVENTS);
   }

   // Insert new event
   g_eventQueue[g_eventTail].type = type;
   g_eventQueue[g_eventTail].symbol = symbol;
   g_eventQueue[g_eventTail].value = value;
   g_eventQueue[g_eventTail].data = data;
   g_eventQueue[g_eventTail].ticket = ticket;
   g_eventQueue[g_eventTail].direction = direction;
   g_eventQueue[g_eventTail].timestamp = TimeCurrent();

   g_eventTail = next;
}

bool PollEvent(TMEvent &evt)
{
   if(g_eventHead == g_eventTail)
   {
      return false;  // Queue empty
   }

   evt = g_eventQueue[g_eventHead];
   g_eventHead = (g_eventHead + 1) % TM_MAX_EVENTS;
   return true;
}

int GetEventQueueSize()
{
   return (g_eventTail - g_eventHead + TM_MAX_EVENTS) % TM_MAX_EVENTS;
}

void ClearEventQueue()
{
   g_eventHead = 0;
   g_eventTail = 0;
}

// ═══════════════════════════════════════════════════════════════════
// CONVENIENCE EMITTERS (type-safe wrappers)
// ═══════════════════════════════════════════════════════════════════

void Event_GOMUpdate()
{
   EmitEvent(EVT_GOM_UPDATE);
}

void Event_MCPSignalReceived(const string symbol, int direction)
{
   EmitEvent(EVT_MCP_SIGNAL_RECEIVED, symbol, 0.0, "", 0, direction);
}

void Event_PositionOpened(ulong ticket, const string symbol, int direction, double entry, double lot)
{
   EmitEvent(EVT_POSITION_OPENED, symbol, lot, StringFormat("entry=%.5f", entry), ticket, direction);
}

void Event_PositionClosed(ulong ticket, const string symbol, int direction, double closePrice, double profit)
{
   EmitEvent(EVT_POSITION_CLOSED, symbol, profit, StringFormat("close=%.5f", closePrice), ticket, direction);
}

void Event_DailyTargetHit(double profit)
{
   EmitEvent(EVT_DAILY_TARGET_HIT, "", profit);
}

void Event_DailyStopLossHit(double loss)
{
   EmitEvent(EVT_DAILY_STOP_LOSS_HIT, "", loss);
}

void Event_SetupChanged(const string symbol)
{
   EmitEvent(EVT_SETUP_CHANGED, symbol);
}

void Event_SpikeDetected(const string symbol, int direction)
{
   EmitEvent(EVT_SPIKE_DETECTED, symbol, 0.0, "", 0, direction);
}

void Event_WhitelistReloaded(int count)
{
   EmitEvent(EVT_WHITELIST_RELOADED, "", count);
}

void Event_FilterRejected(const string symbol, const string reason, int direction)
{
   EmitEvent(EVT_FILTER_REJECTED, symbol, 0.0, reason, 0, direction);
}

void Event_GracePeriodExpired(ulong ticket, const string symbol)
{
   EmitEvent(EVT_GRACE_PERIOD_EXPIRED, symbol, 0.0, "", ticket);
}

void Event_CorrectionDetected(const string symbol)
{
   EmitEvent(EVT_CORRECTION_DETECTED, symbol);
}

// ═══════════════════════════════════════════════════════════════════
// EVENT TYPE STRING CONVERSION (debugging)
// ═══════════════════════════════════════════════════════════════════

string EventTypeToString(TM_EVENT_TYPE type)
{
   switch(type)
   {
      case EVT_GOM_UPDATE:          return "GOM_UPDATE";
      case EVT_MCP_SIGNAL_RECEIVED: return "MCP_SIGNAL_RECEIVED";
      case EVT_POSITION_OPENED:     return "POSITION_OPENED";
      case EVT_POSITION_CLOSED:     return "POSITION_CLOSED";
      case EVT_DAILY_TARGET_HIT:    return "DAILY_TARGET_HIT";
      case EVT_DAILY_STOP_LOSS_HIT: return "DAILY_STOP_LOSS_HIT";
      case EVT_SETUP_CHANGED:       return "SETUP_CHANGED";
      case EVT_SPIKE_DETECTED:      return "SPIKE_DETECTED";
      case EVT_WHITELIST_RELOADED:  return "WHITELIST_RELOADED";
      case EVT_FILTER_REJECTED:     return "FILTER_REJECTED";
      case EVT_GRACE_PERIOD_EXPIRED: return "GRACE_PERIOD_EXPIRED";
      case EVT_CORRECTION_DETECTED: return "CORRECTION_DETECTED";
      default:                      return "UNKNOWN";
   }
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void Events_Init()
{
   ClearEventQueue();
}

void Events_Tick()
{
   // No recurring work for event queue
}

void Events_Deinit()
{
   // Cleanup
   ClearEventQueue();
}

#endif // TM_EVENTS_MQH
