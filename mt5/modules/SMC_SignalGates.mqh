//+------------------------------------------------------------------+
//| SMC_SignalGates.mqh — Gates de confirmation de signal            |
//| Fonctions utilitaires appelées par les modules d'entrée          |
//+------------------------------------------------------------------+
#ifndef SMC_SIGNAL_GATES_MQH
#define SMC_SIGNAL_GATES_MQH

#define SIGNAL_BLINK_CONFIRM_MS  1500  // 3 clignotements × 500ms

//--- Horodatage du dernier changement d'action BUY/SELL (mis à jour par SMC_Universal.mq5)
datetime g_signalAppearTime = 0;
string   g_signalActiveAction = "";  // "BUY" / "SELL" / ""

//+------------------------------------------------------------------+
//| Met à jour le timer d'apparition du signal                       |
//| newAction = décision finale à confirmer (BUY/SELL), typiquement  |
//| la décision GOM clignotante. Chaîne vide = pas de signal.        |
//+------------------------------------------------------------------+
void UpdateSignalAppearTime(const string newAction)
{
   string decision = newAction;
   StringToUpper(decision);
   if(decision != "BUY" && decision != "SELL")
      decision = "";

   static string s_prevDecision = "";
   bool wasEntry = (s_prevDecision == "BUY" || s_prevDecision == "SELL");
   bool isEntry  = (decision == "BUY" || decision == "SELL");

   if(isEntry && (!wasEntry || decision != s_prevDecision))
   {
      g_signalAppearTime = TimeCurrent();
      g_signalActiveAction = decision;
   }
   else if(!isEntry)
   {
      g_signalAppearTime = 0;
      g_signalActiveAction = "";
   }

   s_prevDecision = decision;
}

//+------------------------------------------------------------------+
//| Vérifie si le signal a clignoté assez longtemps pour confirmer   |
//| Retourne true si BUY/SELL final actif depuis >= 1.5s             |
//+------------------------------------------------------------------+
bool IsSignalConfirmed()
{
   if(g_signalAppearTime <= 0) return false;
   if(g_signalActiveAction != "BUY" && g_signalActiveAction != "SELL")
      return false;
   return (TimeCurrent() - g_signalAppearTime) * 1000 >= SIGNAL_BLINK_CONFIRM_MS;
}

//+------------------------------------------------------------------+
//| Direction de la décision finale confirmée (0 si non confirmée)   |
//+------------------------------------------------------------------+
int GetConfirmedSignalDir()
{
   if(!IsSignalConfirmed()) return 0;
   if(g_signalActiveAction == "BUY")  return 1;
   if(g_signalActiveAction == "SELL") return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Pending order helpers (shared across modules)                    |
//+------------------------------------------------------------------+
#ifndef COMMON_PENDING_ORDER_HELPERS
#define COMMON_PENDING_ORDER_HELPERS

bool IsEAPendingOrderType(const ENUM_ORDER_TYPE t)
{
   return (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT
        || t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP
        || t == ORDER_TYPE_BUY_STOP_LIMIT || t == ORDER_TYPE_SELL_STOP_LIMIT);
}

int CountOpenLimitOrdersTerminal()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(IsEAPendingOrderType(t))
         count++;
   }
   return count;
}
#endif

#endif // SMC_SIGNAL_GATES_MQH
