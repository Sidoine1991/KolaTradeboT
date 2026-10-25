//+------------------------------------------------------------------+
//| SMC_TradeExecutor.mqh                                            |
//|                                                                   |
//| POINT D'ENTRÉE UNIQUE pour toute ouverture de trade — MARKET ou   |
//| LIMIT — quel que soit le module/stratégie appelant (DOW, OTE,     |
//| GOM Immediate, EMA/SMC, scanner, pattern chartiste, etc.).        |
//|                                                                   |
//| Objectif : remplacer tout appel direct à OrderSend()/trade.Buy()/ |
//| trade.Sell()/trade.OrderSend() par SMC_SubmitEntry(), pour que    |
//| CHAQUE ordre — sans exception — traverse la même chaîne de        |
//| gardes, dans le même ordre, et déclenche le même enregistrement   |
//| post-envoi.                                                       |
//|                                                                   |
//| Ce module NE réimplémente PAS les gardes existantes : il les      |
//| ORCHESTRE dans le bon ordre. Dépendances (déjà présentes dans     |
//| SMC_Universal.mq5 / SMC_Stubs.mqh) :                              |
//|   - SMC_FinalOpenGate()       : cap global, anti-hedge mémoire,   |
//|                                 confluence OTE, reaction tracker  |
//|   - IsTerminalFull()          : cap terminal (positions+pendings) |
//|   - CleanupExcessLimits()     : discipline LIMIT (purge avant     |
//|                                 d'en ajouter un nouveau)          |
//|   - ValidateAndAdjustLimitPrice() : distance mini broker (stops   |
//|                                 level) pour les pendings          |
//|   - SafeOrderSend()           : GOM WAIT / seuil / cohérence,     |
//|                                 contre-trend Boom/Crash, A+ setup,|
//|                                 cap SL en $, RegisterOrderPlaced()|
//|                                 et notification                   |
//|   - SMC_GateRegisterOpened()  : mémoire anti-hedge 90s            |
//|   - CalculateLotSize()        : dimensionnement par défaut        |
//|                                 (utilisé seulement si volume<=0)  |
//|                                                                   |
//| À inclure APRÈS SMC_Stubs.mqh (SafeOrderSend) et après la section |
//| GARDE FINALE ABSOLUE de SMC_Universal.mq5 (SMC_FinalOpenGate,     |
//| SMC_GateRegisterOpened) dans la liste des #include.               |
//+------------------------------------------------------------------+
#ifndef SMC_TRADE_EXECUTOR_MQH
#define SMC_TRADE_EXECUTOR_MQH

//--- Requête d'entrée générique, agnostique MARKET/LIMIT -------------
struct SMC_EntryRequest
{
   string          symbol;          // "" = _Symbol
   ENUM_ORDER_TYPE orderType;       // ORDER_TYPE_BUY/SELL/BUY_LIMIT/SELL_LIMIT (STOP aussi supporté)
   double          volume;          // 0 = CalculateLotSize() par défaut
   double          price;           // ASK/BID pour MARKET ; niveau pour LIMIT/STOP
   double          sl;
   double          tp;
   ulong           magic;           // 0 = InpMagicNumber
   ulong           deviation;       // 0 = 30 points par défaut
   int             maxPendingPerSymbol; // 0 = 2 par défaut (utilisé par CleanupExcessLimits)
   int             expirationSec;   // 0 = GTC ; >0 = ORDER_TIME_SPECIFIED (expire dans N s)
   string          comment;         // libellé court stocké dans l'ordre (visible MT5)
   string          sourceLabel;     // libellé du module appelant, pour logs/notifications
                                     // ex: "DOW RECT", "EMA SMC", "OTE", "GOM IMMEDIATE"...
};

//--- Initialise une requête avec les valeurs par défaut --------------
void SMC_EntryRequest_Init(SMC_EntryRequest &er)
{
   er.symbol              = "";
   er.orderType           = ORDER_TYPE_BUY;
   er.volume              = 0.0;
   er.price               = 0.0;
   er.sl                  = 0.0;
   er.tp                  = 0.0;
   er.magic               = 0;
   er.deviation           = 0;
   er.maxPendingPerSymbol = 0;
   er.expirationSec       = 0;
   er.comment             = "";
   er.sourceLabel         = "";
}

//--- Construit un MqlTradeRequest normalisé à partir d'un SMC_EntryRequest
void SMC_BuildTradeRequest(const SMC_EntryRequest &er, const string symbol, MqlTradeRequest &req)
{
   ZeroMemory(req);
   bool isPending = (er.orderType == ORDER_TYPE_BUY_LIMIT  || er.orderType == ORDER_TYPE_SELL_LIMIT ||
                     er.orderType == ORDER_TYPE_BUY_STOP   || er.orderType == ORDER_TYPE_SELL_STOP);
   req.action    = isPending ? TRADE_ACTION_PENDING : TRADE_ACTION_DEAL;
   req.symbol    = symbol;
   req.volume    = er.volume;
   req.type      = er.orderType;
   req.price     = er.price;
   req.sl        = er.sl;
   req.tp        = er.tp;
   req.magic     = (er.magic != 0) ? er.magic : InpMagicNumber;
   req.deviation = (er.deviation != 0) ? er.deviation : 30;
   req.comment   = er.comment;
   if(isPending && er.expirationSec > 0)
   {
      req.type_time   = ORDER_TIME_SPECIFIED;
      req.expiration  = (datetime)(TimeCurrent() + er.expirationSec);
   }
}

//+------------------------------------------------------------------+
//| SMC_BrokerMinLotCap                                               |
//| Plafond de volume d'un ordre, par symbole.                       |
//|                                                                  |
//| Demande 2026-09-25 (Sidoine) : l'EA ne doit PAS executer un ordre |
//| dont le lot depasse le lot MINIMAL du broker sur ce symbole.      |
//| Reference broker : 0.10 sur PainX/GainX, 0.20 sur Boom/Crash.     |
//|                                                                  |
//| Constat : CalculateLotSize() dimensionne par % d'equite          |
//| (riskAmount / dollarRiskPerLot) et borne seulement par           |
//| SYMBOL_VOLUME_MAX + le filet $ dynamique. Sur un indice synthetique|
//| a SL serré, dollarRiskPerLot est petit, donc le lot sort facilement|
//| au-dela de 0.10 : 0.25 / 0.50 sur PainX/GainX. Aucun garde-fou    |
//| ne comparait jamais le lot final au min broker du symbole.        |
//|                                                                  |
//| Plafond = max(SYMBOL_VOLUME_MIN broker, plancher de famille).     |
//| Le plancher de famille (0.10 Weltrade synth, 0.20 Boom/Crash,     |
//| 0.01 ailleurs) sert de filet si SymbolInfoDouble echoue. Si le    |
//| broker annonce PLUS haut que la famille, le broker gagne : on ne  |
//| bloque jamais un volume que le broker accepterait.                 |
//|                                                                  |
//| Ordre de test indispensable : SMC_IsWeltradeSynthSymbol matche    |
//| "PAINX" et IsCrashLikeSymbol matche aussi "PAINX" -> le test      |
//| Weltrade passe en PREMIER, sinon PainX heriterait de 0.20 au lieu|
//| de 0.10.                                                          |
//+------------------------------------------------------------------+
double SMC_BrokerMinLotCap(const string symbol)
{
   double brokerMin   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double familyFloor = 0.01;

   if(SMC_IsWeltradeSynthSymbol(symbol))              // PainX / GainX
      familyFloor = 0.10;
   else if(IsBoomLikeSymbol(symbol) || IsCrashLikeSymbol(symbol))  // Boom / Crash
      familyFloor = 0.20;

   double cap = MathMax(brokerMin, familyFloor);
   if(cap <= 0.0) cap = familyFloor;
   return NormalizeDouble(cap, 2);
}

//+------------------------------------------------------------------+
//| SMC_VolumeWithinCap                                               |
//| true  = volume autorise                                            |
//| false = volume BLOQUE (l'ordre ne partira pas)                    |
//|                                                                  |
//| On BLOQUE au lieu de clamper en silence : un volume invalide doit |
//| rester visible dans le journal, sinon on perd le diagnostic du    |
//| sous-dimensionnement (un clamp masquerait le lot reel demande).   |
//|                                                                  |
//| volume <= 0 n'est PAS traite ici : c'est le controle existant de |
//| SMC_SubmitEntry (CalculateLotSize) qui en a la charge.           |
//+------------------------------------------------------------------+
bool SMC_VolumeWithinCap(const string symbol, const double lot, const string label, string &reason)
{
   reason = "";
   if(lot <= 0.0) return true;

   double cap = SMC_BrokerMinLotCap(symbol);
   if(lot <= cap + 1e-8) return true;

   reason = StringFormat("lot %.2f > plafond broker %.2f", lot, cap);
   Print("[EXEC] REJET LOT - ", label, " | ", symbol, " | ", reason);
   return false;
}

//+------------------------------------------------------------------+
//| SMC_SubmitEntry — POINT D'ENTRÉE UNIQUE                           |
//| Retourne true SEULEMENT si l'ordre a été accepté (DONE).          |
//| result est rempli dans tous les cas (utile pour lire retcode).    |
//+------------------------------------------------------------------+
bool SMC_SubmitEntry(SMC_EntryRequest &er, MqlTradeResult &result)
{
   ZeroMemory(result);

   string symbol = (StringLen(er.symbol) > 0) ? er.symbol : _Symbol;
   bool isBuySide = (er.orderType == ORDER_TYPE_BUY || er.orderType == ORDER_TYPE_BUY_LIMIT ||
                     er.orderType == ORDER_TYPE_BUY_STOP);
   bool isLimit   = (er.orderType == ORDER_TYPE_BUY_LIMIT || er.orderType == ORDER_TYPE_SELL_LIMIT);
   string label   = (StringLen(er.sourceLabel) > 0) ? er.sourceLabel : "ENTRY";

   // 0) Volume — calcul par défaut si non fourni par l'appelant
   if(er.volume <= 0.0)
      er.volume = CalculateLotSize();
   if(er.volume <= 0.0)
   {
      Print("[EXEC] ❌ REJET — volume <= 0 après CalculateLotSize | ", label, " | ", symbol);
      return false;
   }

   // 0b) Plafond de volume (demande 2026-09-25) : aucun ordre au-dessus du lot
   //     MINIMAL du broker pour ce symbole (0.10 PainX/GainX, 0.20 Boom/Crash).
   //     Placé ici, avant SMC_FinalOpenGate, pour que le rejet soit la cause
   //     la plus précoce possible et jamais contournable par un appelant.
   string lotCapReason = "";
   if(!SMC_VolumeWithinCap(symbol, er.volume, label, lotCapReason))
      return false; // SMC_VolumeWithinCap journalise déjà le refus

   // 1) GARDE FINALE (cap global terminal, anti-hedge mémoire 90s, confluence OTE,
   //    reaction tracker) — identique pour MARKET et LIMIT, jamais contournée.
   if(!SMC_FinalOpenGate(symbol, er.orderType))
   {
      Print("[EXEC] VETO stage=SMC_FinalOpenGate | source=", label,
            " | symbol=", symbol, " | type=", (int)er.orderType,
            " | volume=", DoubleToString(er.volume, 2),
            " | price=", DoubleToString(er.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
      return false; // SMC_FinalOpenGate journalise déjà la raison du refus
   }

   // 2) Discipline spécifique aux PENDING (LIMIT) : cap terminal + purge des
   //    limites excédentaires avant d'en ajouter une nouvelle sur ce symbole.
   if(isLimit)
   {
      if(IsTerminalFull())
      {
         Print("[EXEC] ❌ REJET LIMIT — terminal plein | ", label, " | ", symbol);
         return false;
      }
      int maxPending = (er.maxPendingPerSymbol > 0) ? er.maxPendingPerSymbol : 2;
      CleanupExcessLimits(symbol, maxPending);
   }

   // 3) Construction de la requête broker normalisée
   MqlTradeRequest req;
   SMC_BuildTradeRequest(er, symbol, req);

   // 4) Ajustement/validation du prix pour les PENDING (distance mini broker —
   //    stops level). Fait ICI, une seule fois, pour tous les appelants.
   if(isLimit && !ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, er.orderType))
   {
      Print("[EXEC] ❌ REJET LIMIT — ValidateAndAdjustLimitPrice a échoué | ", label, " | ", symbol);
      return false;
   }

   // 5) ENVOI — TOUJOURS via SafeOrderSend (jamais OrderSend()/trade.OrderSend()
   //    ailleurs) : applique GOM WAIT/seuil/cohérence, contre-trend Boom/Crash,
   //    anti-hedge CanTradeOnSymbol, A+ setup, cap SL en $, RegisterOrderPlaced()
   //    et notification — dans CE SEUL endroit.
   Print("[EXEC] SUBMIT stage=SafeOrderSend | source=", label,
         " | symbol=", symbol, " | type=", (int)req.type,
         " | volume=", DoubleToString(req.volume, 2),
         " | price=", DoubleToString(req.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
         " | SL=", DoubleToString(req.sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
         " | TP=", DoubleToString(req.tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
   bool sent = SafeOrderSend(req, result, label);
   bool ok   = sent && result.retcode == TRADE_RETCODE_DONE;

   // 6) Post-enregistrement anti-hedge (mémoire 90s) — fait ici une seule fois
   //    pour tous les appelants, plus besoin de s'en souvenir à chaque site.
   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(ok)
   {
      SMC_GateRegisterOpened(symbol, isBuySide);
      Print((isBuySide ? "🟢 " : "🔴 "), label, " ", (isBuySide ? "BUY" : "SELL"),
            (isLimit ? " LIMIT" : " MARKET"), " @ ", DoubleToString(req.price, dg),
            " | SL=", DoubleToString(req.sl, dg), " | TP=", DoubleToString(req.tp, dg),
            " | vol=", DoubleToString(req.volume, 2), " | ", symbol);
   }
   else
   {
      Print("[EXEC] ❌ SUBMIT FAILED | source=", label, " | symbol=", symbol,
            " | SafeOrderSend_return=", sent,
            " | broker_retcode=", result.retcode,
            " | broker_retcode_external=", result.retcode_external,
            " | broker_comment=", result.comment,
            " | request_id=", result.request_id,
            " | (retcode=0: aucun résultat broker reçu ou rejet local SafeOrderSend)");
   }

   return ok;
}

//--- Variante pratique quand on n'a pas besoin de lire le MqlTradeResult
bool SMC_SubmitEntry(SMC_EntryRequest &er)
{
   MqlTradeResult res;
   return SMC_SubmitEntry(er, res);
}

#endif // SMC_TRADE_EXECUTOR_MQH
