//+------------------------------------------------------------------+
//| SMC_TradeJournal.mqh — Journal CSV complet (Common/Files)        |
//+------------------------------------------------------------------+
#ifndef SMC_TRADE_JOURNAL_MQH
#define SMC_TRADE_JOURNAL_MQH

#define SMC_JOURNAL_MAIN_FILE  "TradBOT/trade_journal.csv"
#define SMC_JOURNAL_DAILY_DIR  "TradBOT/daily"

// Forward declare ENUM_SYMBOL_CATEGORY if not already defined
#ifndef ENUM_SYMBOL_CATEGORY_DEFINED
   enum ENUM_SYMBOL_CATEGORY
   {
      SYM_BOOM_CRASH,
      SYM_VOLATILITY,
      SYM_FOREX,
      SYM_COMMODITY,
      SYM_METAL,
      SYM_CRYPTO,
      SYM_UNKNOWN
   };
   #define ENUM_SYMBOL_CATEGORY_DEFINED
#endif

bool   g_journalEnabled      = true;
int    g_journalMagic        = 0;
int    g_journalBackfillDays = 30;
string g_journalEAName       = "SMC_Universal";

ulong  g_journalLoggedDeals[];
int    g_journalLoggedCount  = 0;
#define SMC_JOURNAL_MAX_LOGGED 1000

//+------------------------------------------------------------------+
string SMC_JournalCategoryStr(const ENUM_SYMBOL_CATEGORY category)
{
   switch(category)
   {
      case SYM_BOOM_CRASH:  return "BOOM_CRASH";
      case SYM_VOLATILITY:  return "VOLATILITY";
      case SYM_FOREX:       return "FOREX";
      case SYM_COMMODITY:   return "COMMODITY";
      case SYM_METAL:       return "METAL";
      case SYM_CRYPTO:      return "CRYPTO";
      default:              return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
// SMC_GetSymbolCategory is now implemented in SMC_Universal.mq5
//+------------------------------------------------------------------+
string SMC_JournalDayFile(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%s/trade_journal_%04d-%02d-%02d.csv",
                       SMC_JOURNAL_DAILY_DIR, dt.year, dt.mon, dt.day);
}

//+------------------------------------------------------------------+
bool SMC_JournalDealAlreadyLogged(const ulong dealTicket)
{
   for(int i = 0; i < g_journalLoggedCount; i++)
      if(g_journalLoggedDeals[i] == dealTicket)
         return true;
   return false;
}

//+------------------------------------------------------------------+
void SMC_JournalMarkDealLogged(const ulong dealTicket)
{
   if(SMC_JournalDealAlreadyLogged(dealTicket))
      return;

   if(g_journalLoggedCount >= SMC_JOURNAL_MAX_LOGGED)
   {
      for(int i = 1; i < g_journalLoggedCount; i++)
         g_journalLoggedDeals[i - 1] = g_journalLoggedDeals[i];
      g_journalLoggedCount--;
   }

   ArrayResize(g_journalLoggedDeals, g_journalLoggedCount + 1);
   g_journalLoggedDeals[g_journalLoggedCount] = dealTicket;
   g_journalLoggedCount++;
}

//+------------------------------------------------------------------+
bool SMC_JournalEnsureHeader(const string filePath)
{
   int h = FileOpen(filePath, FILE_READ | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
      return false;

   bool hasHeader = false;
   if(FileSize(h) > 0)
   {
      FileSeek(h, 0, SEEK_SET);
      string first = FileReadString(h);
      hasHeader = (first == "close_time" || first == "deal_ticket");
   }
   FileClose(h);

   if(hasHeader)
      return true;

   h = FileOpen(filePath, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
   {
      Print("[TradeJournal] Erreur création ", filePath, " err=", GetLastError());
      return false;
   }

   FileWrite(h,
      "close_time", "trade_date", "hour_utc", "day_of_week",
      "deal_ticket", "position_id", "symbol", "category", "direction", "volume",
      "open_time", "close_time_full", "open_price", "close_price",
      "profit", "swap", "commission", "net_profit",
      "duration_sec", "duration_min", "result",
      "ai_confidence", "ai_action", "balance", "equity", "daily_pnl",
      "ea_name", "magic", "account", "comment"
   );
   FileClose(h);
   return true;
}

//+------------------------------------------------------------------+
void SMC_JournalConfigure(const bool enabled, const int magic,
                          const string eaName = "SMC_Universal",
                          const int backfillDays = 30)
{
   g_journalEnabled      = enabled;
   g_journalMagic        = magic;
   g_journalEAName       = eaName;
   g_journalBackfillDays = backfillDays;
}

//+------------------------------------------------------------------+
double SMC_JournalGetDailyPnL(const int magic, const datetime dayStart)
{
   if(!HistorySelect(dayStart, TimeCurrent()))
      return 0.0;

   double total = 0.0;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      total += HistoryDealGetDouble(ticket, DEAL_PROFIT)
             + HistoryDealGetDouble(ticket, DEAL_SWAP)
             + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
   return total;
}

//+------------------------------------------------------------------+
bool SMC_JournalExtractPosition(const ulong positionId, const int magic,
                                string &symbol, string &direction,
                                double &volume, datetime &openTime, datetime &closeTime,
                                double &openPrice, double &closePrice,
                                double &profit, double &swap, double &commission,
                                ulong &closeDealTicket, string &comment)
{
   symbol = "";
   direction = "";
   volume = 0;
   openTime = 0;
   closeTime = 0;
   openPrice = 0;
   closePrice = 0;
   profit = 0;
   swap = 0;
   commission = 0;
   closeDealTicket = 0;
   comment = "";

   if(!HistorySelectByPosition(positionId))
      return false;

   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      ENUM_DEAL_TYPE  dtype = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);

      if(entry == DEAL_ENTRY_IN)
      {
         symbol    = HistoryDealGetString(ticket, DEAL_SYMBOL);
         openTime  = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         openPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
         volume    = HistoryDealGetDouble(ticket, DEAL_VOLUME);
         comment   = HistoryDealGetString(ticket, DEAL_COMMENT);
         direction = (dtype == DEAL_TYPE_BUY) ? "BUY" : "SELL";
      }
      else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
      {
         closeDealTicket = ticket;
         closeTime  = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
         profit    += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         swap      += HistoryDealGetDouble(ticket, DEAL_SWAP);
         commission += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         if(symbol == "")
            symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      }
   }

   return (closeDealTicket > 0 && symbol != "" && closeTime > 0);
}

//+------------------------------------------------------------------+
void SMC_JournalWriteRow(const string filePath,
                         const datetime closeTime,
                         const ulong closeDealTicket,
                         const ulong positionId,
                         const string symbol,
                         const string category,
                         const string direction,
                         const double volume,
                         const datetime openTime,
                         const double openPrice,
                         const double closePrice,
                         const double profit,
                         const double swap,
                         const double commission,
                         const double netProfit,
                         const int durationSec,
                         const string result,
                         const double aiConfidence,
                         const string aiAction,
                         const double balance,
                         const double equity,
                         const double dailyPnL,
                         const string comment)
{
   SMC_JournalEnsureHeader(filePath);

   int h = FileOpen(filePath, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
   {
      Print("[TradeJournal] Erreur ouverture ", filePath, " err=", GetLastError());
      return;
   }

   FileSeek(h, 0, SEEK_END);

   MqlDateTime dt;
   TimeToStruct(closeTime, dt);
   string tradeDate = StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);
   string dow[] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};
   string dayOfWeek = (dt.day_of_week >= 0 && dt.day_of_week <= 6) ? dow[dt.day_of_week] : "?";
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits <= 0) digits = 5;

   FileWrite(h,
      TimeToString(closeTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      tradeDate,
      IntegerToString(dt.hour),
      dayOfWeek,
      IntegerToString(closeDealTicket),
      IntegerToString(positionId),
      symbol,
      category,
      direction,
      DoubleToString(volume, 2),
      TimeToString(openTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      TimeToString(closeTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      DoubleToString(openPrice, digits),
      DoubleToString(closePrice, digits),
      DoubleToString(profit, 2),
      DoubleToString(swap, 2),
      DoubleToString(commission, 2),
      DoubleToString(netProfit, 2),
      IntegerToString(durationSec),
      DoubleToString((durationSec > 0) ? (double)durationSec / 60.0 : 0.0, 1),
      result,
      DoubleToString(aiConfidence, 4),
      aiAction,
      DoubleToString(balance, 2),
      DoubleToString(equity, 2),
      DoubleToString(dailyPnL, 2),
      g_journalEAName,
      IntegerToString(g_journalMagic),
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
      comment
   );
   FileClose(h);
}

//+------------------------------------------------------------------+
bool SMC_JournalLogPositionClose(const ulong positionId,
                                 const double aiConfidence = 0.0,
                                 const string aiAction = "")
{
   if(!g_journalEnabled || g_journalMagic <= 0)
      return false;

   string symbol, direction, comment;
   double volume, openPrice, closePrice, profit, swap, commission;
   datetime openTime, closeTime;
   ulong closeDealTicket = 0;

   if(!SMC_JournalExtractPosition(positionId, g_journalMagic,
                                  symbol, direction, volume, openTime, closeTime,
                                  openPrice, closePrice, profit, swap, commission,
                                  closeDealTicket, comment))
      return false;

   if(SMC_JournalDealAlreadyLogged(closeDealTicket))
      return false;

   double netProfit = profit + swap + commission;
   int durationSec = (openTime > 0 && closeTime > openTime) ? (int)(closeTime - openTime) : 0;
   string result = (netProfit > 0) ? "WIN" : ((netProfit < 0) ? "LOSS" : "BE");
   string category = SMC_JournalCategoryStr(SMC_GetSymbolCategory(symbol));

   MqlDateTime dayStart;
   TimeToStruct(closeTime, dayStart);
   dayStart.hour = 0; dayStart.min = 0; dayStart.sec = 0;
   double dailyPnL = SMC_JournalGetDailyPnL(g_journalMagic, StructToTime(dayStart));

   SMC_JournalWriteRow(SMC_JOURNAL_MAIN_FILE,
                       closeTime, closeDealTicket, positionId,
                       symbol, category, direction, volume,
                       openTime, openPrice, closePrice,
                       profit, swap, commission, netProfit,
                       durationSec, result, aiConfidence, aiAction,
                       AccountInfoDouble(ACCOUNT_BALANCE),
                       AccountInfoDouble(ACCOUNT_EQUITY),
                       dailyPnL, comment);

   SMC_JournalWriteRow(SMC_JournalDayFile(closeTime),
                       closeTime, closeDealTicket, positionId,
                       symbol, category, direction, volume,
                       openTime, openPrice, closePrice,
                       profit, swap, commission, netProfit,
                       durationSec, result, aiConfidence, aiAction,
                       AccountInfoDouble(ACCOUNT_BALANCE),
                       AccountInfoDouble(ACCOUNT_EQUITY),
                       dailyPnL, comment);

   SMC_JournalMarkDealLogged(closeDealTicket);

   Print("[TradeJournal] ", result, " ", category, " ", symbol, " ", direction,
         " net=", DoubleToString(netProfit, 2), "$");
   return true;
}

//+------------------------------------------------------------------+
bool SMC_JournalLogDealClose(const ulong dealTicket,
                             const double aiConfidence = 0.0,
                             const string aiAction = "")
{
   if(!g_journalEnabled || dealTicket == 0)
      return false;

   if(SMC_JournalDealAlreadyLogged(dealTicket))
      return false;

   if(!HistoryDealSelect(dealTicket))
      return false;

   if((int)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != g_journalMagic)
      return false;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
      return false;

   ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   return SMC_JournalLogPositionClose(positionId, aiConfidence, aiAction);
}

//+------------------------------------------------------------------+
void SMC_JournalBackfillRecent(const int daysBack = 30)
{
   if(!g_journalEnabled || g_journalMagic <= 0)
      return;

   datetime from = TimeCurrent() - (daysBack * 86400);
   if(!HistorySelect(from, TimeCurrent()))
      return;

   ulong seenPositions[];
   int seenCount = 0;
   int deals = HistoryDealsTotal();

   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != g_journalMagic) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      ulong posId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      bool dup = false;
      for(int j = 0; j < seenCount; j++)
         if(seenPositions[j] == posId) { dup = true; break; }
      if(dup) continue;

      ArrayResize(seenPositions, seenCount + 1);
      seenPositions[seenCount++] = posId;
      SMC_JournalLogPositionClose(posId, 0.0, "");
   }

   Print("[TradeJournal] Backfill ", daysBack, "j — fichier: Common/Files/", SMC_JOURNAL_MAIN_FILE);
}

//+------------------------------------------------------------------+
void SMC_JournalExportHistoryToCSV(const int daysBack = 30)
{
   if(!g_journalEnabled || g_journalMagic <= 0)
      return;

   datetime from = TimeCurrent() - (daysBack * 86400);
   if(!HistorySelect(from, TimeCurrent()))
      return;

   SMC_JournalEnsureHeader(SMC_JOURNAL_MAIN_FILE);

   ulong processedDeals[];
   int processedCount = 0;
   int deals = HistoryDealsTotal();

   Print("[TradeJournal] Exporting ", deals, " deals from MT5 history (", daysBack, " days)...");

   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != g_journalMagic) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      bool alreadyProcessed = false;
      for(int j = 0; j < processedCount; j++)
         if(processedDeals[j] == ticket) { alreadyProcessed = true; break; }
      if(alreadyProcessed) continue;

      ArrayResize(processedDeals, processedCount + 1);
      processedDeals[processedCount++] = ticket;

      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      ulong positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      ENUM_DEAL_TYPE dtype = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
      double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

      datetime openTime = 0;
      double openPrice = 0;
      string direction = (dtype == DEAL_TYPE_BUY) ? "BUY" : "SELL";

      if(!HistorySelectByPosition(positionId))
         continue;

      int posDeals = HistoryDealsTotal();
      for(int j = 0; j < posDeals; j++)
      {
         ulong openTicket = HistoryDealGetTicket(j);
         if(openTicket == 0) continue;
         ENUM_DEAL_ENTRY openEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(openTicket, DEAL_ENTRY);
         if(openEntry == DEAL_ENTRY_IN)
         {
            openTime = (datetime)HistoryDealGetInteger(openTicket, DEAL_TIME);
            openPrice = HistoryDealGetDouble(openTicket, DEAL_PRICE);
            break;
         }
      }

      if(openTime == 0 || openPrice == 0) continue;

      double netProfit = profit + swap + commission;
      int durationSec = (openTime > 0 && closeTime > openTime) ? (int)(closeTime - openTime) : 0;
      string result = (netProfit > 0) ? "WIN" : ((netProfit < 0) ? "LOSS" : "BE");
      string category = SMC_JournalCategoryStr(SMC_GetSymbolCategory(symbol));

      MqlDateTime dayStart;
      TimeToStruct(closeTime, dayStart);
      dayStart.hour = 0; dayStart.min = 0; dayStart.sec = 0;
      double dailyPnL = SMC_JournalGetDailyPnL(g_journalMagic, StructToTime(dayStart));

      SMC_JournalWriteRow(SMC_JOURNAL_MAIN_FILE,
                          closeTime, ticket, positionId,
                          symbol, category, direction, volume,
                          openTime, openPrice, closePrice,
                          profit, swap, commission, netProfit,
                          durationSec, result, 0.0, "",
                          AccountInfoDouble(ACCOUNT_BALANCE),
                          AccountInfoDouble(ACCOUNT_EQUITY),
                          dailyPnL, comment);

      SMC_JournalWriteRow(SMC_JournalDayFile(closeTime),
                          closeTime, ticket, positionId,
                          symbol, category, direction, volume,
                          openTime, openPrice, closePrice,
                          profit, swap, commission, netProfit,
                          durationSec, result, 0.0, "",
                          AccountInfoDouble(ACCOUNT_BALANCE),
                          AccountInfoDouble(ACCOUNT_EQUITY),
                          dailyPnL, comment);
   }

   Print("[TradeJournal] ✅ Exported ", processedCount, " deals to CSV");
}

//+------------------------------------------------------------------+
void SMC_JournalInit()
{
   if(!g_journalEnabled)
      return;

   SMC_JournalEnsureHeader(SMC_JOURNAL_MAIN_FILE);
   SMC_JournalEnsureHeader(SMC_JournalDayFile(TimeCurrent()));

   SMC_JournalExportHistoryToCSV(g_journalBackfillDays);
   SMC_JournalBackfillRecent(g_journalBackfillDays);

   Print("[TradeJournal] Actif → Common/Files/", SMC_JOURNAL_MAIN_FILE);
}

#endif
