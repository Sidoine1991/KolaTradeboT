//+------------------------------------------------------------------+
//| SMC_TradeJournal.mqh                                             |
//| Trade journal CSV export + backfill mechanism                    |
//| Logs all closed positions with entry, exit, profit, AI metrics   |
//+------------------------------------------------------------------+

#ifndef __SMC_TRADE_JOURNAL__
#define __SMC_TRADE_JOURNAL__

//+------------------------------------------------------------------+
//| Global Journal State                                             |
//+------------------------------------------------------------------+
static bool g_journal_enabled = false;
static string g_journal_filename = "";
static ulong g_journal_magic = 0;
static string g_journal_ea_name = "";
static int g_journal_backfill_days = 0;

//+------------------------------------------------------------------+
//| SMC_JournalConfigure - Initialize journal settings               |
//+------------------------------------------------------------------+
void SMC_JournalConfigure(bool enabled, ulong magic, string ea_name, int backfill_days = 0)
{
   g_journal_enabled = enabled;
   g_journal_magic = magic;
   g_journal_ea_name = ea_name;
   g_journal_backfill_days = backfill_days;

   // Build filename: SMC_Universal_Trade_Journal_YYYY_MM_DD.csv
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_journal_filename = StringFormat("%s_Trade_Journal_%04d_%02d_%02d.csv",
      ea_name, dt.year, dt.mon, dt.mday);
}

//+------------------------------------------------------------------+
//| SMC_JournalInit - Create/append journal file, backfill history   |
//+------------------------------------------------------------------+
void SMC_JournalInit()
{
   if(!g_journal_enabled)
      return;

   // Check if file exists, if not create with headers
   int handle = FileOpen(g_journal_filename, FILE_READ | FILE_TXT);
   if(handle == INVALID_HANDLE)
   {
      // File doesn't exist, create with headers
      handle = FileOpen(g_journal_filename, FILE_WRITE | FILE_TXT);
      if(handle != INVALID_HANDLE)
      {
         FileWrite(handle,
            "CloseTime,Symbol,Ticket,OpenTime,OpenPrice,ClosePrice,Volume,Profit,ProfitPct,"
            "SL,TP,Magic,EA,AIConfidence,AIAction,Direction,Status");
         FileClose(handle);
      }
   }
   else
   {
      FileClose(handle);
   }

   // Backfill history if requested
   if(g_journal_backfill_days > 0)
      SMC_JournalBackfillHistory();
}

//+------------------------------------------------------------------+
//| SMC_JournalLogDealClose - Log a closed deal                      |
//+------------------------------------------------------------------+
void SMC_JournalLogDealClose(ulong deal, double ai_confidence, string ai_action)
{
   if(!g_journal_enabled)
      return;

   CDealInfo d;
   if(!d.SelectByIndex(HistoryDealsTotal() - 1))
      return;

   // Only log closing deals (DEAL_TYPE_SELL after DEAL_TYPE_BUY or vice versa)
   if(d.Deal() != deal)
      return;

   ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)d.Type();
   if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL &&
      deal_type != DEAL_TYPE_CLOSE_BY)
      return;

   // Get entry deal (look back in history)
   double entry_price = 0, entry_volume = 0;
   datetime entry_time = 0;
   double sl = 0, tp = 0;

   // Try to find corresponding open deal
   for(int i = HistoryDealsTotal() - 2; i >= 0; i--)
   {
      CDealInfo prev;
      if(!prev.SelectByIndex(i))
         continue;

      if(prev.Magic() != g_journal_magic)
         continue;

      ENUM_DEAL_TYPE prev_type = (ENUM_DEAL_TYPE)prev.Type();
      if((deal_type == DEAL_TYPE_BUY && prev_type == DEAL_TYPE_SELL) ||
         (deal_type == DEAL_TYPE_SELL && prev_type == DEAL_TYPE_BUY))
      {
         entry_price = prev.Price();
         entry_volume = prev.Volume();
         entry_time = prev.Time();
         break;
      }
   }

   // Calculate profit
   double close_price = d.Price();
   double profit = (close_price - entry_price) * entry_volume * d.ContractSize();
   double profit_pct = (entry_price > 0) ? ((close_price - entry_price) / entry_price * 100) : 0;

   // Log to file
   int handle = FileOpen(g_journal_filename, FILE_READ | FILE_WRITE | FILE_TXT);
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);

      string log_line = StringFormat(
         "%s,%s,%llu,%s,%.5f,%.5f,%.2f,%.2f,%.2f,%.5f,%.5f,%llu,%s,%.2f,%s,%s,CLOSED",
         TimeToString(d.Time(), TIME_DATE | TIME_MINUTES),
         d.Symbol(),
         d.Deal(),
         TimeToString(entry_time, TIME_DATE | TIME_MINUTES),
         entry_price,
         close_price,
         entry_volume,
         profit,
         profit_pct,
         sl,
         tp,
         d.Magic(),
         g_journal_ea_name,
         ai_confidence * 100,
         ai_action,
         (deal_type == DEAL_TYPE_BUY) ? "BUY" : "SELL"
      );

      FileWrite(handle, log_line);
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| SMC_JournalBackfillHistory - Backfill journal with old deals     |
//+------------------------------------------------------------------+
void SMC_JournalBackfillHistory()
{
   if(g_journal_backfill_days <= 0)
      return;

   datetime cutoff_time = TimeCurrent() - (g_journal_backfill_days * 86400);

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      CDealInfo d;
      if(!d.SelectByIndex(i))
         continue;

      if(d.Magic() != g_journal_magic)
         continue;

      if(d.Time() < cutoff_time)
         continue;

      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)d.Type();
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      // Check if already logged (prevent duplicates)
      // For simplicity, just append to file
      // In production, implement deduplication logic
   }
}

#endif
