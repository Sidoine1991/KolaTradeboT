// SMC_Stubs.mqh — Implémentations temporaires pour les fonctions non encore définies
// Ces stubs seront remplacés par les vraies implémentations de FXVOL_020726.txt

#ifndef SMC_STUBS_MQH
#define SMC_STUBS_MQH

//--- SMC_EffectiveGOMMinCoherence et SMC_EffectiveMaxPositionsTerminal
//--- définis dans SMC_Universal.mq5 (profil Gold/Forex/Crypto)

double GOM_GetATRValue()
{
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0) atrVal = atrBuf[0];
   }
   if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;
   return atrVal;
}
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
bool SMC_IsCorrectionZoneForDirection(const string sym, const int dirSign)
{
   return false;
}
bool SMC_IAAndCOGAligned(const int dirSign)
{
   return true;
}
bool GOM_EntryAlignmentOK(const int dirSign)
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
bool SMC_M5H1PreciseAligned(const int dirSign)
{
   return true;
}
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
bool SMC_TfDirMatchesSign(const int dirSign, const string tfDir)
{
   return true;
}
bool SMC_AlignExecStrictGateOK(const int dirSign, string &reason)
{
   return true;
}
bool SMC_ExecuteAlignMarketIfOK(const int dirSign, const string dir, const string level)
{
   return false;
}
bool GOM_CanOpenAlignedTrade(const int dirSign)
{
   return true;
}
bool GOM_EntryCoherenceOK()
{
   return true;
}
bool COG_ConflictsWithGOM()
{
   return false;
}
bool TryExecuteGOMPerfectEntry()
{
   return false;
}
void ManageManualTradeSLTP() {}
void ManageGOMVerdictExits() {}
void ManageGOMAutonomousStrategy() {}
void ManageGOMWaitPullbackLimit() {}
void ManageGOMAlignedLimitOrders() {}
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
bool SMC_PricePullbackM5EMA(const int dirSign, double &emaPrice, const double tol = 0.40) { return false; }
bool EvaluateEntryWithMultipleSignals() { return false; }

//--- SafeOrder wrappers — gate GOM WAIT / contre-verdict avant tout envoi
bool SafeOrderSend(MqlTradeRequest &req, MqlTradeResult &result, const string label = "")
{
   ENUM_ORDER_TYPE t = req.type;
   bool isMarket = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_SELL);
   bool isLimit  = (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT);
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      int dirSign = 0;
      if(t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) dirSign = 1;
      else if(t == ORDER_TYPE_SELL || t == ORDER_TYPE_SELL_LIMIT) dirSign = -1;
      string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      if(isMarket && !CanPlaceMarketOrder(sym, dirSign))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] MARKET rejeté GOM | ", label, " | ", sym);
         return false;
      }
      if(isLimit && !CanPlaceLimitOrder(sym, t))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] LIMIT rejeté GOM | ", label, " | ", sym);
         return false;
      }
   }
   return OrderSend(req, result);
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

bool PlaceGOMMarketOrder(const string direction, const string src, const string tag)
{
   if(BlockAllTrades) return false;
   if(!CanOpenAdditionalPositionForSymbol(_Symbol, direction)) return false;
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction)) return false;
   if(CountPositionsOurEA() >= SMC_EffectiveMaxPositionsTerminal()) return false;

   int dir = (direction == "BUY") ? 1 : -1;

   if(!CanPlaceMarketOrder(_Symbol, dir)) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return false;
   double px = (dir == 1) ? ask : bid;

   double slDist = px * 0.001;
   double tpDist = slDist * 3.0;

   double sl, tp;
   if(dir == 1) { sl = px - slDist; tp = px + tpDist; }
   else         { sl = px + slDist; tp = px - tpDist; }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   if(!SMCGP_PrepareMarketStops(_Symbol, dir, px, sl, tp, 0.01, sl, tp))
      return false;

   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.type      = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = (dir == 1) ? ask : bid;
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 10;
   req.magic     = InpMagicNumber;
   req.comment   = src + ":" + tag;

   long fillFlags = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillFlags & SYMBOL_FILLING_IOC) != 0)      req.type_filling = ORDER_FILLING_IOC;
   else if((fillFlags & SYMBOL_FILLING_FOK) != 0)  req.type_filling = ORDER_FILLING_FOK;
   else                                             req.type_filling = ORDER_FILLING_RETURN;

   if(SafeOrderSendAndAlert(req, res))
   {
      PrintFormat("[GOM-MARKET] %s %s @ %.5f | SL=%.5f TP=%.5f | %s | %s",
                  src, direction, req.price, sl, tp, tag, g_smcGomVerdict);
      return true;
   }
   PrintFormat("[GOM-MARKET] ECHEC %s %s: %d | %s", src, direction, res.retcode, tag);
   return false;
}

#endif
