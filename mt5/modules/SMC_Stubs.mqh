// SMC_Stubs.mqh — Implémentations temporaires pour les fonctions non encore définies
// Ces stubs seront remplacés par les vraies implémentations de FXVOL_020726.txt

#ifndef SMC_STUBS_MQH
#define SMC_STUBS_MQH

//--- SMC_EffectiveGOMMinCoherence et SMC_EffectiveMaxPositionsTerminal
//--- définis dans SMC_Universal.mq5 (profil Gold/Forex/Crypto)

// GOM_GetATRValue → SMC_GOMAlign.mqh
bool SMC_GOM_M5H1SMCConfirmOK(const string sym, const string sym2 = "")
{
   return true; // Backup: autoriser
}
double SMC_EffectiveSymbolATR(const string sym)
{
   return 0; // Utilise ATR standard
}
double SMC_WeltradeFxVolLot()
{
   return 0; // Utilise lot par défaut
}
double SMC_WeltradeFxEqLot()
{
   return 0;
}
double SMC_WeltradeFxSwissLot()
{
   return 0;
}
bool SMC_IsWeltradeVolSymbol(const string sym)
{
   string s = sym; StringToUpper(s);
   string sc = s; StringReplace(sc, " ", "");
   return (StringFind(sc, "FXVOL") >= 0 || StringFind(sc, "SFVVOL") >= 0 ||
           StringFind(sc, "SFXVOL") >= 0 ||
           StringFind(s, "FX VOL") >= 0 || StringFind(s, "SFX VOL") >= 0 ||
           StringFind(s, "SFV VOL") >= 0);
}
bool SMC_IsWeltradeSymbol(const string sym)
{
   string s = sym; StringToUpper(s);
   string sc = s; StringReplace(sc, " ", "");
   return (StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0 ||
           SMC_IsWeltradeVolSymbol(sym));
}
bool SMC_IsWeltradeBoomCrash(const string sym)
{
   return false;
}
bool SMC_IsSyntheticAutonomousSym(const string sym)
{
   return true; // Synthétiques autonomes
}
bool SMC_GOMAutonomousAllowed(const string sym)
{
   return true;
}
bool SMC_IsPropitiousTradeHour(const string sym)
{
   return true;
}
bool SMC_BCHourAllowsTrade(const string sym)
{
   return true;
}
/* bool SMC_HighProbabilityAllowsEntry(const int dirSign = 0) - defined in SMC_ProbabilityGate.mqh */
bool SMC_PerformancePauseAllowsEntry(const string sym)
{
   return true;
}
/* bool SMC_IsCorrectionZoneForDirection — défini dans SMC_Universal.mq5 */
// SMC_IAAndCOGAligned, GOM_EntryAlignmentOK → SMC_GOMAlign.mqh
bool GOM_EntryEnvironmentOK(const int dirSign)
{
   return true;
}
bool SMC_SurvivalMarginOK(const string sym, double lot, double entryPrice, double sl)
{
   return true;
}
bool SMC_DailyDisciplineAllowsEntry()
{
   return true;
}
bool SMC_ReadinessAllowsEntry(const string sym)
{
   return true;
}
bool SMC_IsCrash150Symbol(const string sym)
{
   return false;
}
void SMC_PollDailyReadiness() {}
void SMC_ResetDailyReadiness() {}
void SMC_LoadPerformancePauseState() {}
void SMC_ResetTradeStatistics() {}
void SMC_InitializeSessionReadiness() {}
int SMC_GOMReentryCooldownSec()
{
   return 0;
}
bool SMC_DetectBounceAtLevel(const int dirSign, const string symbol)
{
   return false;
}
bool SMC_IsPriceNearLevel(const int dirSign, const string sym, const double mult)
{
   return false;
}
// SMC_M5H1PreciseAligned → SMC_GOMAlign.mqh
bool SMC_M5EMATrendAligned(const int dirSign)
{
   return true;
}
bool SMC_M1BarConfirmsDirection(const int dirSign)
{
   return true;
}
bool SMC_GhostOrderflowAligned(const int dirSign)
{
   return true;
}
bool SMC_M5BarConfirmsPullback(const int dirSign, const double ema)
{
   return true;
}
bool SMC_M5EMAPullbackConfirmOK(const int dirSign, const double ema, string &reason)
{
   return true;
}
// SMC_TfDirMatchesSign, SMC_AlignExecStrictGateOK, SMC_ExecuteAlignMarketIfOK,
// GOM_CanOpenAlignedTrade, SMC_PricePullbackM5EMA → SMC_GOMAlign.mqh
bool GOM_EntryCoherenceOK()
{
   return true;
}
// COG_ConflictsWithGOM → SMC_GOMAlign.mqh
bool TryExecuteGOMPerfectEntry()
{
   return false;
}
void ManageManualTradeSLTP() {}
void ManageGOMVerdictExits() {}
void ManageGOMAutonomousStrategy() {}
void ManageGOMWaitPullbackLimit() {}
// ManageGOMAlignedLimitOrders → SMC_GOMAlign.mqh
void ManageOTEEAutonomousStrategy() {}
void SMC_EnforceTerminalOrderLimits() {}
void SMC_ClearSymbolLocksOnInit() {}
void SMC_ResetPerformancePauseDaily() {}
void SMC_ResetPerformancePauseFull() {}
void SMC_RecordDailyTradeOpen() {}
double SMC_GetDailyBalanceDepositsUSD() { return 0; }
double SMC_GetDailyProfitUSD() { return 0; }
double SMC_GetDailyProfitTargetUSD() { return 0; }
double SMC_GetPositionMaxLossUSD(const int posDir, const bool isGomWait) { return 0; }
/* double SMC_ComputeEntryProbability(const int dirSign) - defined in SMC_ProbabilityGate.mqh */
bool GOM_EntrySupportsOpenPosition(const int posDir) { return false; }
void SMC_MarkSpikeCaptured(const string sym) {}
int SMC_CountSmallM1BarsAfterTime(const string sym, const datetime after) { return 0; }
bool EvaluateEntryWithMultipleSignals() { return false; }

//--- SafeOrder wrappers — gate GOM WAIT / contre-verdict avant tout envoi
bool SafeOrderSend(MqlTradeRequest &req, MqlTradeResult &result, const string label = "")
{
   ENUM_ORDER_TYPE t = req.type;
   bool isMarket = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_SELL);
   bool isLimit  = (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT);

   // ── GARDE TERMINAL GLOBAL: positions + pending orders <= MaxPositionsTerminal ──
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      if(IsTerminalFull())
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — Terminal plein (", CountTerminalAllOrders(), "/", MaxPositionsTerminal, ") | ", label, " | ", req.symbol);
         return false;
      }
      // ── GARDE PAR SYMBOLE: pas de 2ème ordre sur même symbole ──
      string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      if(SymbolHasActiveOrder(sym))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — ", sym, " a déjà un ordre actif | ", label);
         return false;
      }
   }

   // ── GARDE WAIT ABSOLU: QUE GOOD/PERFECT ──
   // Aucun ORDRE (marché OU limit) ne peut être créé/ouvert sauf si
   // GOM est GOOD (|vn|>=2) ou PERFECT (|vn|>=3). WAIT (vn=0) et
   // SIMPLE (|vn|=1) sont bloqués.
   // Ce garde est INCONTOURNABLE (même via g_smcAlignExecBypass).
   // On autorise uniquement les actions de gestion: annulation (REMOVE) et
   // modification (MODIFY) d'ordres déjà existants (nécessaire pour annuler les LIMIT).
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      if(MathAbs(g_smcGomVerdictNum) < 2)
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum,
               ") — seul GOOD/PERFECT (|vn|>=2) autorisé | ", label, " | ",
               (isMarket ? "MARKET" : (isLimit ? "LIMIT" : EnumToString(t))), " | ", req.symbol);
         return false;
      }
   }

   // ── GARDE DIRECTION BOOM/CRASH: INCONTOURNABLE (même via bypass) ──
   // Pas de SELL sur Boom/Gainx, pas de BUY sur Crash/Painx
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      string symDir = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      string dirCheck = "";
      if(t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) dirCheck = "BUY";
      else if(t == ORDER_TYPE_SELL || t == ORDER_TYPE_SELL_LIMIT) dirCheck = "SELL";
      if(dirCheck != "" && !IsDirectionAllowedForBoomCrash(symDir, dirCheck))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — ", symDir, " — ", dirCheck, " interdit (règle Boom/Crash) | ", label);
         return false;
      }
   }

   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      int dirSign = 0;
      if(t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) dirSign = 1;
      else if(t == ORDER_TYPE_SELL || t == ORDER_TYPE_SELL_LIMIT) dirSign = -1;
      string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      if(isMarket && !g_smcAlignExecBypass && !CanPlaceMarketOrder(sym, dirSign))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] MARKET rejeté GOM | ", label, " | ", sym);
         return false;
      }
      if(isLimit && !g_smcAlignExecBypass && !CanPlaceLimitOrder(sym, t))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] LIMIT rejeté GOM | ", label, " | ", sym);
         return false;
      }
   }
    bool sent = OrderSend(req, result);
    // ── NOTIFICATION PUSH: tout ordre exécuté (limit ou marché) avec Entry/TP/SL ──
     if(sent && result.retcode == TRADE_RETCODE_DONE)
    {
       RegisterOrderPlaced();  // Anti-race: incrémenter compteur immédiatement
       if(UseNotifications)
       {
          string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
          string dir = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) ? "BUY" : "SELL";
          int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
          double entry = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) ? req.price : req.price;
          string msg = "📩 ORDRE " + dir + " [" + sym + "]\n";
          msg += "Type: " + (isMarket ? "MARKET" : "LIMIT") + " | " + (StringLen(label) > 0 ? label : "—") + "\n";
          msg += "Entry: " + DoubleToString(entry, dg) + "\n";
          msg += "SL: " + DoubleToString(req.sl, dg) + "\n";
          msg += "TP: " + DoubleToString(req.tp, dg) + "\n";
          msg += "Lot: " + DoubleToString(req.volume, 2);
          SendNotification(msg);
       }
    }
    return sent;
}
bool SafeOrderSendAndAlert(MqlTradeRequest &req, MqlTradeResult &result, const string label = "")
{
   bool ok = SafeOrderSend(req, result, label);
   if(!ok || result.retcode != TRADE_RETCODE_DONE)
      Print("[SAFE] OrderSend failed: ", result.retcode, " ", label);
   return ok;
}

//--- OTE stubs
bool OTE_IsActiveSymbol(const string s) { return false; }
void OTE_InitHandles() {}
void OTE_ReleaseHandles() {}
void OTE_FindSwings(double &h1,double &h2,datetime &ht1,datetime &ht2,double &l1,double &l2,datetime &lt1,datetime &lt2) {}
void OTE_AnalyzeStructure() {}
void OTE_UpdateHTFBias() {}
void OTE_DetectZone() {}
void OTE_DetectOrderBlock() {}
void OTE_DetectFVG() {}
bool OTE_ConfirmBullish() { return false; }
bool OTE_ConfirmBearish() { return false; }
bool OTE_CheckDailyLimits() { return true; }
bool OTE_IsSessionOK() { return true; }
int OTE_CountTrades() { return 0; }
double OTE_PipsToPrice(double p) { return p; }
double OTE_PriceToPips(double d) { return d; }
double OTE_CalcBuySL(double e,double b) { return 0; }
double OTE_CalcSellSL(double e,double a) { return 0; }
double OTE_CalcBuyTP(double e,double sl) { return 0; }
double OTE_CalcSellTP(double e,double sl) { return 0; }
double OTE_CalcLots(double e,double sl) { return 0; }
bool OTE_PlaceTrade(string dir,double ask,double bid,double sl,double tp,double l) { return false; }
void OTE_ManageTrades() {}
void OTE_DailyReset() {}
void OTE_OnNewBar() {}
bool OTE_IsNewBar() { return false; }
bool OTE_PlaceOTETrade(const int dir) { return false; }
void OTE_DrawZone() {}

//--- PB send stubs
string PB_JsonEscape(const string s) { return s; }
bool PB_SendWhatsAppViaAI(const string event,const string sym,const string msg,const string dir="",double e=0,double sl=0,double tp=0,double lot=0) { return false; }
bool PB_SendWhatsAppDirect(const string msg) { return false; }
bool PB_SendWhatsAppAlert(const string msg) { return false; }

//--- MT5Dashboard sync stub
bool MT5DashboardSync() { return false; }

//--- Pipeline discipline stub
bool DisciplineAllowsPipelineAction(const string action) { return true; }
int SMC_ComputePropiceScore() { return 0; }

// --- Symboles requis par SMC_PatternSignals.mqh ---
bool g_smcAlignExecBypass = false;

// PlaceGOMMarketOrder → SMC_GOMAlign.mqh

#endif
