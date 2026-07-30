//+------------------------------------------------------------------+
//| SMC_LimitDiscipline.mqh — Placement / annulation LIMIT stabilisés |
//| Évite le cycle place→supprime trop rapide                         |
//+------------------------------------------------------------------+
#ifndef SMC_LIMIT_DISCIPLINE_MQH
#define SMC_LIMIT_DISCIPLINE_MQH

#include "SMC_SignalGates.mqh"

// Inputs définis dans SMC_Universal.mq5
// input int  LimitCancelMinAgeSec
// input int  LimitCancelUnfilledMinAgeSec
// input int  LimitPlaceCooldownSec
// input bool LimitRequireBlinkBeforePlace
// input bool KeepPendingUntilTrigger

//+------------------------------------------------------------------+
//| Âge en secondes depuis ORDER_TIME_SETUP                           |
//+------------------------------------------------------------------+
int LimitOrderAgeSec(const ulong ticket)
{
   if(ticket == 0 || !OrderSelect(ticket)) return 0;
   datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
   if(setup <= 0) return 0;
   return (int)(TimeCurrent() - setup);
}

bool LimitOrderIsBuySellLimit(const ulong ticket)
{
   if(!OrderSelect(ticket)) return false;
   ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   return (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT);
}

bool LimitOrderIsPendingUnfilled(const ulong ticket)
{
   if(!OrderSelect(ticket)) return false;
   ENUM_ORDER_STATE st = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
   return (st == ORDER_STATE_PLACED);
}

//+------------------------------------------------------------------+
//| Délai minimum avant annulation (5 min standard, 3 min si pending)|
//+------------------------------------------------------------------+
int LimitCancelMinAgeRequired(const ulong ticket)
{
   int minFilled = MathMax(60, LimitCancelMinAgeSec);
   int minUnfilled = MathMax(60, LimitCancelUnfilledMinAgeSec);
   if(LimitOrderIsPendingUnfilled(ticket))
      return minUnfilled;
   return minFilled;
}

string LimitCancelBlockReason(const ulong ticket)
{
   int age = LimitOrderAgeSec(ticket);
   int needStandard = MathMax(60, LimitCancelMinAgeSec);
   int needUnfilled = MathMax(60, LimitCancelUnfilledMinAgeSec);

   if(LimitOrderIsPendingUnfilled(ticket))
   {
      if(KeepPendingUntilTrigger && age < needStandard)
         return StringFormat("KeepPendingUntilTrigger (âge %ds < %ds)", age, needStandard);
      if(age < needUnfilled)
         return StringFormat("pending non rempli — âge %ds < min %ds", age, needUnfilled);
      return "";
   }

   if(age < needStandard)
      return StringFormat("âge %ds < min %ds", age, needStandard);
   return "";
}

//+------------------------------------------------------------------+
//| Autoriser l'annulation d'un LIMIT ?                               |
//| forceCounterTrend=true : bypass délai (SELL Boom / BUY Crash)    |
//+------------------------------------------------------------------+
bool LimitCancelAllowed(const ulong ticket, const bool forceCounterTrend = false,
                        const string reason = "")
{
   if(ticket == 0) return false;
   if(!LimitOrderIsBuySellLimit(ticket)) return true;

   if(forceCounterTrend)
      return true;

   string block = LimitCancelBlockReason(ticket);
   if(StringLen(block) > 0)
   {
      static datetime s_lastLog = 0;
      if(TimeCurrent() - s_lastLog >= 45)
      {
         s_lastLog = TimeCurrent();
         Print("[LIMIT-DISC] Annulation refusée #", ticket, " — ", block,
               (StringLen(reason) > 0 ? " | " + reason : ""));
      }
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Enregistrer une annulation (cooldown avant replacer)              |
//+------------------------------------------------------------------+
void LimitRegisterCancel(const string symbol)
{
   string key = "SMC_LIMCD_" + IntegerToString((long)InpMagicNumber) + "_" + symbol;
   GlobalVariableSet(key, (double)TimeCurrent());
}

int LimitPlaceCooldownRemainingSec(const string symbol)
{
   if(LimitPlaceCooldownSec <= 0) return 0;
   string key = "SMC_LIMCD_" + IntegerToString((long)InpMagicNumber) + "_" + symbol;
   if(!GlobalVariableCheck(key)) return 0;
   datetime last = (datetime)GlobalVariableGet(key);
   int rem = LimitPlaceCooldownSec - (int)(TimeCurrent() - last);
   return (rem > 0) ? rem : 0;
}

//+------------------------------------------------------------------+
//| Gate placement LIMIT : GOM + blink + cooldown                     |
//+------------------------------------------------------------------+
bool LimitPlaceDisciplineOK(const string symbol, const int dirSign, string &reasonOut)
{
   reasonOut = "";
   if(dirSign == 0) { reasonOut = "direction invalide"; return false; }

   if(LimitRequireBlinkBeforePlace)
   {
      if(!IsSignalConfirmed())
      {
         reasonOut = "décision BUY/SELL pas encore confirmée (blink)";
         return false;
      }
      if(GetConfirmedSignalDir() != dirSign)
      {
         reasonOut = "blink " + g_signalActiveAction + " ≠ direction demandée";
         return false;
      }
   }

   if(UseGOMVerdictFilter)
   {
      if(!g_smcGomConnected || g_smcGomVerdictNum == 0)
      {
         reasonOut = "GOM WAIT/déconnecté";
         return false;
      }
      if(MathAbs(g_smcGomVerdictNum) < MinGOMVerdictNumAbs)
      {
         reasonOut = "GOM pas GOOD/PERFECT";
         return false;
      }
      if((dirSign > 0 && g_smcGomVerdictNum < 0) || (dirSign < 0 && g_smcGomVerdictNum > 0))
      {
         reasonOut = "GOM contre direction";
         return false;
      }
   }

   int cd = LimitPlaceCooldownRemainingSec(symbol);
   if(cd > 0)
   {
      reasonOut = StringFormat("cooldown post-annulation %ds", cd);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Annuler un LIMIT si discipline OK (+ log)                         |
//+------------------------------------------------------------------+
bool LimitSafeOrderDelete(const ulong ticket, const bool forceCounterTrend = false,
                          const string reason = "")
{
   if(ticket == 0) return false;
   if(!LimitCancelAllowed(ticket, forceCounterTrend, reason)) return false;

   string sym = OrderGetString(ORDER_SYMBOL);
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   req.symbol = sym;
   if(!SafeOrderSend(req, res))
   {
      Print("[LIMIT-DISC] Échec annulation #", ticket, " err=", res.retcode, " | ", reason);
      return false;
   }
   LimitRegisterCancel(sym);
   Print("[LIMIT-DISC] LIMIT annulé #", ticket, " sym=", sym, " | ", reason);
   return true;
}

#endif // SMC_LIMIT_DISCIPLINE_MQH

