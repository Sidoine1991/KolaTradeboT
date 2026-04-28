//+------------------------------------------------------------------+
//|                                      MT5_DealsUploader.mq5      |
//|                 Upload historique DEALS MT5 vers AI Server       |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"
#property strict

input string API_URL = "https://kolatradebot.onrender.com/mt5/deals-upload"; // Endpoint serveur
input int    UploadInterval = 60;     // secondes
input int    LookbackDays   = 7;      // jours d'historique à uploader
input bool   AutoUpload     = true;   // upload périodique
input bool   IncludeAllMagics = false; // true = tous trades du compte, false = filtrer par Magic
input long   MagicNumberFilter = 202502; // utilisé si IncludeAllMagics=false

datetime lastUploadTime = 0;

int OnInit()
{
   Print("🚀 MT5 Deals Uploader initialisé");
   Print("   ├─ URL API: ", API_URL);
   Print("   ├─ Intervalle: ", UploadInterval, " sec");
   Print("   ├─ LookbackDays: ", LookbackDays);
   Print("   └─ Magics: ", IncludeAllMagics ? "TOUS" : ("Magic=" + IntegerToString((int)MagicNumberFilter)));

   if(AutoUpload)
   {
      EventSetTimer(1);
      UploadDeals();
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("🛑 MT5 Deals Uploader arrêté");
}

void OnTick() {}

void OnTimer()
{
   if(!AutoUpload) return;
   datetime now = TimeCurrent();
   if(now - lastUploadTime >= UploadInterval)
   {
      UploadDeals();
      lastUploadTime = now;
   }
}

bool UploadDeals()
{
   datetime toTime = TimeCurrent();
   datetime fromTime = toTime - (LookbackDays * 24 * 60 * 60);
   if(LookbackDays <= 0) fromTime = toTime - 24 * 60 * 60;

   if(!HistorySelect(fromTime, toTime))
   {
      Print("❌ HistorySelect échoué");
      return false;
   }

   int total = HistoryDealsTotal();
   if(total <= 0)
   {
      Print("ℹ️ Aucun deal dans la période");
      return true;
   }

   string json = "{\"deals\":[";
   int count = 0;

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long entry = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue; // uniquement clôtures

      long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(!IncludeAllMagics && magic != MagicNumberFilter) continue;

      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(StringLen(symbol) <= 0) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
      long posId = (long)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);

      // is_win basé sur profit (cohérent)
      string isWinStr = (profit > 0 ? "true" : "false");

      // Construire objet deal minimal (idempotence côté serveur via mt5_deal_id)
      string obj = StringFormat("{\"mt5_deal_id\":%llu,\"position_id\":%lld,\"symbol\":\"%s\",\"profit\":%.5f,\"is_win\":%s,\"close_time\":\"%s\",\"price\":%.5f,\"magic\":%lld}",
                                ticket, posId, symbol, profit, isWinStr,
                                TimeToString(closeTime, TIME_DATE|TIME_SECONDS),
                                price, magic);

      if(count > 0) json += ",";
      json += obj;
      count++;

      // éviter payloads trop gros
      if(count >= 500) break;
   }

   json += "]}";

   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string resultHeaders;
   StringToCharArray(json, post, 0, StringLen(json));

   int res = WebRequest("POST", API_URL, headers, 15000, post, result, resultHeaders);
   if(res != 200 && res != 201)
   {
      Print("❌ Upload deals échoué HTTP ", res, " | ", CharArrayToString(result));
      return false;
   }

   Print("✅ Upload deals OK: ", count, " deals (OUT) envoyés");
   return true;
}

