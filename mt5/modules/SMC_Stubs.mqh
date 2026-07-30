// SMC_Stubs.mqh — Implémentations temporaires pour les fonctions non encore définies
// Ces stubs seront remplacés par les vraies implémentations de FXVOL_020726.txt
// CONFLITS SUPPRIMÉS: fonctions déjà définies dans SMC_Universal.mq5

#ifndef SMC_STUBS_MQH
#define SMC_STUBS_MQH

//--- SMC_EffectiveGOMMinCoherence et SMC_EffectiveMaxPositionsTerminal
//--- définis dans SMC_Universal.mq5 (profil Gold/Forex/Crypto)
//--- CountTerminalAllOrders, IsTerminalFull, SymbolHasActiveOrder, RegisterOrderPlaced
//--- définis dans SMC_Universal.mq5 (versions complètes avec comptage terminal)

// GOM_GetATRValue → SMC_GOMAlign.mqh

// --- Forward declarations (définies dans SMC_Universal.mq5) ---
int  CountPositionsOurEA();
int  CountPositionsForSymbol(const string symbol);
int  SMC_EffectiveMaxPositionsTerminal();
bool IsTerminalFull();
bool SymbolHasActiveOrder(const string symbol);
int  CountTerminalAllOrders();
void RegisterOrderPlaced();

// --- Globals needed by multiple modules ---
bool g_smcAlignExecBypass = false;
bool MT5DashboardSync() { return false; }

// --- Stubs non-conflitantes ---
bool SMC_PerformancePauseAllowsEntry(const string sym)
{
   return true;
}
bool GOM_EntryEnvironmentOK(const int dirSign)
{
   return true;
}
bool SMC_SurvivalMarginOK(const string sym, double lot, double entryPrice, double sl)
{
   return true;
}
bool SMC_ReadinessAllowsEntry(const string sym)
{
   return true;
}
void SMC_PollDailyReadiness() {}
void SMC_ResetDailyReadiness() {}
bool SMC_BCHourAllowsTrade(const string symbol = "") { return true; }
bool SMC_DailyDisciplineAllowsEntry() { return true; }
bool SMC_IsCrash150Symbol(const string symbol) { return false; }
bool SMC_IsWeltradeSymbol(const string symbol) { return false; }
bool SMC_IsWeltradeBoomCrash(const string symbol) { return false; }
bool SMC_IsWeltradeVolSymbol(const string symbol) { return false; }
bool SMC_IsSyntheticAutonomousSym(const string symbol) { return true; }
bool SMC_GOMAutonomousAllowed(const string symbol) { return true; }
bool SMC_IsPropitiousTradeHour(const string symbol = "") { return true; }
string PB_JsonEscape(const string s) { return s; }
bool PB_SendWhatsAppViaAI(const string event, const string symbol, const string message,
                          const string direction, double entry, double sl,
                          double tp, double lot) { return false; }
bool PB_SendWhatsAppDirect(const string message) { return false; }
bool PB_SendWhatsAppAlert(const string message) { return false; }
bool SMC_GOM_M5H1SMCConfirmOK(const string symbol, const string sym2) { return true; }
double SMC_WeltradeFxVolLot() { return 0; }
double SMC_WeltradeFxEqLot() { return 0; }
double SMC_WeltradeFxSwissLot() { return 0; }
double SMC_EffectiveSymbolATR(const string symbol) { return 0; }

// --- Contre-tendance: affichage d'avertissement visuel ---
void DrawCounterTrendCross(const string name, color clr, const string label)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1) return;
   double price = r[0].high + r[0].close * 0.001;
   datetime time = r[0].time;
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(ObjectFind(0, name + "_TXT") >= 0) ObjectDelete(0, name + "_TXT");
   ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 74);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectCreate(0, name + "_TXT", OBJ_TEXT, 0, time, price + r[0].close * 0.0005);
   ObjectSetString(0, name + "_TXT", OBJPROP_TEXT, label);
   ObjectSetInteger(0, name + "_TXT", OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name + "_TXT", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name + "_TXT", OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0, name + "_TXT", OBJPROP_SELECTABLE, false);
   ChartRedraw(0);
}
void ShowCounterTrendWarning(const string direction)
{
   string sym = _Symbol;
   bool isCrash = IsCrashLikeSymbol(sym);
   bool isBoom  = IsBoomLikeSymbol(sym);
   if(isCrash && direction == "BUY")
      DrawCounterTrendCross("CT_WARN_BUY_" + sym, clrLime, "CONTRE-TREND BUY\nPainX = SELL only");
   else if(isBoom && direction == "SELL")
      DrawCounterTrendCross("CT_WARN_SELL_" + sym, clrRed, "CONTRE-TREND SELL\nGainX = BUY only");
}
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
// TryExecuteGOMPerfectEntry, ManageGOMAutonomousStrategy → SMC_GOM_Autonomous.mqh
void ManageManualTradeSLTP() {}
void ManageGOMVerdictExits() {}
void ManageGOMWaitPullbackLimit() {}
// ManageGOMAlignedLimitOrders → SMC_GOMAlign.mqh
// ManageOTEEAutonomousStrategy : non utilisée (logique OTE pilotée depuis OnTick, voir SMC_OTE_Zone.mqh)
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

   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      if(IsTerminalFull())
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — Terminal plein (", CountTerminalAllOrders(), "/", SMC_EffectiveMaxPositionsTerminal(), ") | ", label, " | ", req.symbol);
         return false;
      }
      string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      if(SymbolHasActiveOrder(sym))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — ", sym, " a déjà un ordre actif | ", label);
         return false;
      }
   }

   // WAIT absolu (vn=0) — incontournable
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      if(g_smcGomVerdictNum == 0)
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — GOM=WAIT (vn=0) | ", label, " | ",
               (isMarket ? "MARKET" : (isLimit ? "LIMIT" : EnumToString(t))), " | ", req.symbol);
         return false;
      }
   }

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

   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      string symDir = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      string dirCheck = "";
      if(t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) dirCheck = "BUY";
      else if(t == ORDER_TYPE_SELL || t == ORDER_TYPE_SELL_LIMIT) dirCheck = "SELL";
       if(dirCheck != "" && !IsDirectionAllowedForBoomCrash(symDir, dirCheck))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] CONTRE-TREND BLOQUÉ — ", symDir, " — ", dirCheck, " interdit (règle Boom/Crash) | ", label, " | ALERTE VISUELLE");
         ShowCounterTrendWarning(dirCheck);
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
     if(sent && result.retcode == TRADE_RETCODE_DONE)
    {
       RegisterOrderPlaced();
       if(UseNotifications)
       {
          string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
          string dir = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) ? "BUY" : "SELL";
          int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
          double entry = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) ? req.price : req.price;
          string msg = "ORDRE " + dir + " [" + sym + "]\n";
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
// OTE_* : voir SMC_OTE_Zone.mqh (vraie implémentation, plus de stub ici)

//--- Pipeline discipline stub
bool DisciplineAllowsPipelineAction(const string action) { return true; }
int SMC_ComputePropiceScore() { return 0; }

// --- Symboles requis par SMC_PatternSignals.mqh ---

#endif
