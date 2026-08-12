#property script_show_inputs

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

input int   InpMagicNumber = 202502; // Magic number used by SMC EA
input bool  EnableNotifications = true;
input bool  ShowDetails = true;

CTrade trade;
CPositionInfo position;

bool IsBoomLikeSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "BOOM") >= 0 || StringFind(s, "GAINX") >= 0);
}

bool IsCrashLikeSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "CRASH") >= 0 || StringFind(s, "PAINX") >= 0);
}

bool ClosePositionWithRetry(ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket)) return false;
   // Try several times
   for(int attempt=0; attempt<4; attempt++)
   {
      if(trade.PositionClose(ticket)) return true;
      Sleep(100 * (attempt+1));
   }
   int err = GetLastError();
   PrintFormat("[CloseContradictory] Failed to close ticket %d (err %d)", ticket, err);
   return false;
}

void OnStart()
{
   Print("[CloseContradictory] Starting scan for contradictory Boom/Crash positions (Magic=", InpMagicNumber, ")");
   int closed = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if((long)magic != (long)InpMagicNumber) continue; // only our EA positions

      string sym = PositionGetString(POSITION_SYMBOL);
      long ptype = PositionGetInteger(POSITION_TYPE); // POSITION_TYPE_BUY / SELL

      bool isBoom = IsBoomLikeSymbol(sym);
      bool isCrash = IsCrashLikeSymbol(sym);

      bool shouldClose = false;
      string reason = "";

      if(ptype == POSITION_TYPE_BUY && isCrash)
      {
         shouldClose = true; reason = "BUY on Crash-like symbol (PAINX/CRASH)";
      }
      else if(ptype == POSITION_TYPE_SELL && isBoom)
      {
         shouldClose = true; reason = "SELL on Boom-like symbol (GAINX/BOOM)";
      }

      if(shouldClose)
      {
         if(ShowDetails)
         {
            double vol = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
            PrintFormat("[CloseContradictory] Closing ticket %d symbol=%s type=%s vol=%.2f profit=%.2f reason=%s",
                        ticket, sym, (ptype==POSITION_TYPE_BUY?"BUY":"SELL"), vol, profit, reason);
         }
         bool ok = ClosePositionWithRetry(ticket);
         if(ok)
         {
            closed++;
            PrintFormat("[CloseContradictory] Ticket %d closed", ticket);
            if(EnableNotifications)
            {
               SendNotification(StringFormat("CloseContradictory: closed %s #%d (%s)", sym, ticket, reason));
            }
         }
         else
         {
            PrintFormat("[CloseContradictory] Failed to close ticket %d", ticket);
         }
      }
   }

   if(closed == 0) Print("[CloseContradictory] No contradictory positions found/closed.");
   else PrintFormat("[CloseContradictory] Completed - positions closed: %d", closed);
}
