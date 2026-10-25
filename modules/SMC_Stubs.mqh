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
int  SMC_ExecutableGomVn();
int  SMC_EffectiveMaxPositionsTerminal();
bool IsTerminalFull();
bool SymbolHasActiveOrder(const string symbol);
int  CountTerminalAllOrders();
void RegisterOrderPlaced();
bool CanTradeOnSymbol(const string symbol, const string direction = "");
bool SMC_IsWeltradeSynthSymbol(const string symbol);
void UpdateDailyEquityStats();
bool IsDailyDrawdownExceeded();
bool SMC_UnifiedFindTouchedLevel(const int dirSign, const double price,
                                 const double tolerance, double &levelOut,
                                 string &sourceOut);
double SMC_StubCalcLossUSD(const string symbol, const ENUM_ORDER_TYPE otype,
                           const double lot, const double pxPrice, const double pxSL);
// SMC_IsWeltradeSymbol / SMC_IsWeltradeBoomCrash / SMC_IsWeltradeVolSymbol → définies dans SMC_Universal.mq5

// GOM Scanner forward declarations
void GOMSCAN_ScanAll();
void GOMSCAN_Init();

// --- Globals needed by multiple modules ---
bool g_smcAlignExecBypass = false;
// g_dowPriceLeadInFlight defined in SMC_Universal.mq5 (main entry point)
extern bool g_dowPriceLeadInFlight;
bool MT5DashboardSync() { return false; }

// --- Stubs non-conflitantes ---
bool SMC_PerformancePauseAllowsEntry(const string sym)
{
   return true;
}
bool GOM_EntryEnvironmentOK(const int dirSign)
{
   if(!g_smcGomConnected) return true;
   if(g_smcLastGOMPoll > 0 && (int)(TimeCurrent() - g_smcLastGOMPoll) > 90)
      return false;
   if(dirSign > 0 && g_smcGomVerdictNum < 0) return false;
   if(dirSign < 0 && g_smcGomVerdictNum > 0) return false;
   return true;
}
bool SMC_SurvivalMarginOK(const string symbol, double lot, double entryPrice, double sl)
{
   if(lot <= 0.0 || sl <= 0.0 || entryPrice <= 0.0)
      return true;

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double stopOutLvl = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   if(stopOutLvl <= 0.0) stopOutLvl = 50.0;

   ENUM_ORDER_TYPE orderType = (entryPrice >= sl) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double newMargin = 0.0;
   if(!OrderCalcMargin(orderType, symbol, lot, entryPrice, newMargin) || newMargin <= 0.0)
   {
      double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double contSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contSize > 0.0 && tickVal > 0.0 && tickSize > 0.0)
         newMargin = lot * contSize * entryPrice / 100.0;
      else
         return true;
   }

   double maxLossUSD = SMC_StubCalcLossUSD(symbol, orderType, lot, entryPrice, sl);
   double equityAtSL = equity - (maxLossUSD * 1.25);
   double stopOutEquityUSD = (usedMargin + newMargin) * (stopOutLvl / 100.0);
   if(equityAtSL <= stopOutEquityUSD * 1.10)
      return false;
   if(freeMargin < newMargin * 1.20)
      return false;
   return true;
}
bool SMC_ReadinessAllowsEntry(const string sym)
{
   return true;
}
void SMC_PollDailyReadiness() {}
void SMC_ResetDailyReadiness() {}
bool SMC_BCHourAllowsTrade(const string symbol = "") { return true; }
bool SMC_DailyDisciplineAllowsEntry()
{
   if(!UseDailyDiscipline) return true;
   if(BlockAllTrades) return false;
   if(!SMC_PerformancePauseAllowsEntry(_Symbol)) return false;
   UpdateDailyEquityStats();
   if(IsDailyDrawdownExceeded()) return false;
   double dailyProfit = SMC_GetDailyProfitUSD();
   double dailyTarget = SMC_GetDailyProfitTargetUSD();
   if(StopOnDailyTarget && dailyTarget > 0.0 && dailyProfit >= dailyTarget)
   {
      g_dailyTargetHit = 1;
      return false;
   }
   if(g_dailyTargetHit != 0 && dailyTarget > 0.0 && dailyProfit < dailyTarget)
      g_dailyTargetHit = 0;
   return true;
}
bool SMC_IsCrash150Symbol(const string symbol) { return false; }
// --- Weltrade helpers ---
// SMC_IsWeltradeSymbol, SMC_IsWeltradeBoomCrash, SMC_IsWeltradeVolSymbol
// → tous définis dans SMC_Universal.mq5 (avant #include SMC_Stubs.mqh)
extern double WeltradeFxVolFixedLot;  // global du .mq5 parent (pas input)
// FxVol20LotMult / UseLearnEntryOnnxGate : déclarés en `input` dans SMC_Universal.mq5
// AVANT cet include — ne pas les re-déclarer en extern (type différent → erreur compile).

// Boom/Crash + volatilité Weltrade : stratégie GOM autonome (spikes)
// SMC_IsSyntheticAutonomousSym → définie dans SMC_Universal.mq5
bool SMC_IsSyntheticAutonomousSym(const string symbol);
bool SMC_GOMAutonomousAllowed(const string symbol) { return true; }
bool SMC_IsPropitiousTradeHour(const string symbol = "") { return true; }

//--- A+ Setup gate — corps dans SMC_AplusGate.mqh (après ProbabilityGate + DowTrendline)
bool SMC_APlusSetupOK(const string symbol, const int dirSign);
void SMC_APlus_OnTransaction(const MqlTradeTransaction &trans);
void SMC_APlus_SampleOnSignal(const string symbol, const int dirSign);
//--- LearnJournal / LearnEntry ONNX (définis dans modules inclus par le .mq5 parent)
bool LJ_ExpectancyAllowsEntry(const int dirSign, const string symbol = "");
void LJ_ShadowCandidate(const string sym, const bool isBuy, const string reason);
bool LE_OnnxAllowsEntry(const string symbol, const int dirSign);

//--- Shared effective per-position loss cap, taking the tightest active limit
double SMC_HardMaxLossUSD()
{
   // v1.56.6: plancher FORCÉ à $3 — les inputs chart anciens (MaxLossDollars=2)
   // ne doivent plus couper à $2. Log journal: MaxLossDollars: 2.0 confirmé.
   double floorUSD = 3.0;
   if(MaxLossPerSpikeTradeDollars > floorUSD)
      floorUSD = MaxLossPerSpikeTradeDollars;
   double cap = floorUSD;
   if(MaxLossHardCapDollars > 0.0 && MaxLossHardCapDollars >= floorUSD)
      cap = MathMin(cap, MaxLossHardCapDollars);
   // Ignorer MaxLossDollars / UniversalMaxLossUSD s'ils sont < floor (valeurs
   // héritées 2.0 sur le graphique après recompile)
   if(MaxLossDollars > floorUSD)
      cap = MathMin(cap, MaxLossDollars);
   if(UniversalMaxLossUSD > floorUSD)
      cap = MathMin(cap, UniversalMaxLossUSD);
   if(MaxLossPerTradeDollars > floorUSD)
      cap = MathMin(cap, MaxLossPerTradeDollars);
   if(cap < floorUSD) cap = floorUSD;
   return cap;
}

//--- Cap SL to max loss USD — implémentation réelle (AUDIT C7: le stub
//    retournait true sans rien faire → les SL au-delà du cap passaient).
//    Resserre le SL au plafond effectif (2$ par défaut)
//    ou rejette (false) si même le SL minimum dépasse le cap.
double SMC_StubCalcLossUSD(const string symbol, const ENUM_ORDER_TYPE otype,
                           const double lot, const double pxPrice, const double pxSL)
{
   double loss = 0.0;
   if(OrderCalcProfit(otype, symbol, lot, pxPrice, pxSL, loss))
      return MathMax(0.0, -loss);
   double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0)
      return 0.0;
   return MathAbs(pxPrice - pxSL) / tickSize * tickVal * lot;
}

bool SMC_CapSLToMaxLossUSD(const string symbol, const int dir, const double entry,
                           const double lot, double &sl)
{
   if(dir == 0 || lot <= 0.0 || entry <= 0.0)
      return false;
   double cap = SMC_HardMaxLossUSD();
   if(cap <= 0.0) cap = 3.0;

   ENUM_ORDER_TYPE otype = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   // SL déjà dans le cap → OK tel quel
   if(sl > 0.0)
   {
      double loss = SMC_StubCalcLossUSD(symbol, otype, lot, entry, sl);
      if(loss > 0.0 && loss <= cap * 1.001)
         return true;
   }

   double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int    dg       = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(tickVal <= 0.0 || tickSize <= 0.0)
   {
      Print("❌ SL $ cap: tickValue/tickSize manquants sur ", symbol);
      return false;
   }

   double maxDist = (cap / (tickVal * lot)) * tickSize;
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int stopsLvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (double)(stopsLvl + 2) * pt;
   if(maxDist < minDist)
   {
      Print("❌ SL $ cap: dist max $", DoubleToString(cap, 2),
            " < stops level sur ", symbol, " lot=", DoubleToString(lot, 2));
      return false;
   }

   double newSL = (dir > 0) ? NormalizeDouble(entry - maxDist, dg)
                            : NormalizeDouble(entry + maxDist, dg);
   double loss2 = SMC_StubCalcLossUSD(symbol, otype, lot, entry, newSL);
   if(loss2 > cap * 1.001)
   {
      Print("❌ SL $ cap: perte ", DoubleToString(loss2, 2), "$ > ",
            DoubleToString(cap, 2), "$ sur ", symbol);
      return false;
   }

   sl = newSL;
   Print("🛡️ SL capé à $", DoubleToString(cap, 2), " | ", symbol,
         " | SL=", DoubleToString(sl, dg), " | perte=", DoubleToString(loss2, 2), "$");
   return true;
}

string PB_JsonEscape(const string s) { return s; }
bool PB_SendWhatsAppViaAI(const string event, const string symbol, const string message,
                          const string direction, double entry, double sl,
                          double tp, double lot) { return false; }
bool PB_SendWhatsAppDirect(const string message) { return false; }
bool PB_SendWhatsAppAlert(const string message) { return false; }
bool SMC_GOM_M5H1SMCConfirmOK(const string symbol, const string sym2) { return true; }
double SMC_WeltradeFxVolLot()
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lotStep <= 0) lotStep = minLot;
   double lot = WeltradeFxVolFixedLot;
   // FIX v1.57: FX Vol 20 — expectancy shadow negative + perte reelle → lot reduit.
   if(StringFind(_Symbol, "FX Vol 20") >= 0 || StringFind(_Symbol, "FXVOL20") >= 0)
   {
      double mult = (FxVol20LotMult > 0.0 && FxVol20LotMult <= 1.0) ? FxVol20LotMult : 0.5;
      lot *= mult;
   }
   if(lotStep > 0) lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return NormalizeDouble(lot, 2);
}
double SMC_WeltradeFxEqLot() { return SMC_WeltradeFxVolLot(); }
double SMC_WeltradeFxSwissLot() { return SMC_WeltradeFxVolLot(); }
//+------------------------------------------------------------------+
//| SMC_SymbolATR : ATR réel du symbole, en unités de prix.            |
//|                                                                   |
//| BUG CORRIGÉ 2026-09-26 : SMC_EffectiveSymbolATR() retournait 0 en  |
//| permanence. SMC_UnifiedGOMEntryOnTick() faisait                    |
//| `if(atr <= 0.0) return;` juste avant de chercher le niveau        |
//| FVG/SMC/DOW/Pivot => plus aucun ordre market ne pouvait partir,   |
//| quel que soit le verdict GOM.                                     |
//|                                                                   |
//| Résolution :                                                      |
//|  1) handle iATR mis en cache (1 handle / symbole) — pas de       |
//|     création/libération à chaque tick, sinon fuite de handles.     |
//|  2) lecture sur la bougie clôturée (shift 1) pour éviter le       |
//|     repainting intra-bougie.                                      |
//|  3) repli sur un True Range moyen calculé depuis CopyRates si     |
//|     l'indicateur n'est pas encore prêt.                           |
//|  4) plancher = distance de stop minimale du broker, sinon le SL   |
//|     calculé en aval serait rejeté (invalid stops).                |
//|                                                                   |
//| NOM VOLONTAIREMENT DIFFERENT de SMC_EffectiveSymbolATR : sans      |
//| argument par defaut, aucune surcharge ambiguë n'est possible avec  |
//| les declarations forward obsoletes a 1 parametre encore presentes  |
//| dans certaines copies de SMC_Universal.mq5.                       |
//+------------------------------------------------------------------+
double SMC_SymbolATR(const string symbol, const ENUM_TIMEFRAMES tf, const int atrPeriod)
{
   string sym = (StringLen(symbol) > 0) ? symbol : _Symbol;
   if(StringLen(sym) == 0) return 0.0;

   const double point    = SymbolInfoDouble(sym, SYMBOL_POINT);
   const long   stopLvl  = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   // Plancher : SL/TP doivent rester à distance légale du marché.
   const double minAtr   = (double)(stopLvl + 5) * point;
   if(point <= 0.0) return 0.0;

   static int             cachedHandle = INVALID_HANDLE;
   static string          cachedSymbol = "";
   static int             cachedPeriod = 0;
   static ENUM_TIMEFRAMES cachedTF      = PERIOD_CURRENT;

   // Le handle n'est valable que pour (symbole, timeframe, période).
   if(cachedHandle != INVALID_HANDLE &&
      (cachedSymbol != sym || cachedTF != tf || cachedPeriod != atrPeriod))
   {
      IndicatorRelease(cachedHandle);
      cachedHandle = INVALID_HANDLE;
   }

   double out = 0.0;
   if(cachedHandle == INVALID_HANDLE)
   {
      cachedHandle = iATR(sym, tf, atrPeriod);
      cachedSymbol = sym;
      cachedTF     = tf;
      cachedPeriod = atrPeriod;
   }
   if(cachedHandle != INVALID_HANDLE && BarsCalculated(cachedHandle) > 0)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(cachedHandle, 0, 1, 1, buf) >= 1) out = buf[0];
   }
   if(out <= 0.0)
   {
      // Repli manuel : True Range moyen sur la bougie clôturée.
      MqlRates r[];
      ArraySetAsSeries(r, true);
      if(CopyRates(sym, tf, 1, 14, r) >= 2)
      {
         double tr = 0.0;
         int bars = 0;
         for(int i = 0; i < 14 && i < ArraySize(r); i++)
         {
            double prevClose = (i + 1 < ArraySize(r)) ? r[i + 1].close : r[i].close;
            tr += MathMax(r[i].high - r[i].low,
                          MathMax(MathAbs(r[i].high - prevClose), MathAbs(r[i].low - prevClose)));
            bars++;
         }
         if(bars > 0) out = tr / bars;
      }
   }
   if(out < minAtr) out = minAtr;
   return out;
}

//+------------------------------------------------------------------+
//| SMC_EffectiveSymbolATR : ATR M1(14) du symbole.                    |
//| Signature volontairement inchangée (1 seul paramètre) pour rester  |
//| compatible avec les déclarations forward existantes.              |
//+------------------------------------------------------------------+
double SMC_EffectiveSymbolATR(const string symbol)
{
   return SMC_SymbolATR(symbol, PERIOD_M1, 14);
}

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
   return MathMax(5, UnifiedEntryCooldownSec);
}
bool SMC_DetectBounceAtLevel(const int dirSign, const string symbol)
{
   if(dirSign == 0) return false;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 3, r) < 3) return false;
   if(dirSign > 0)
      return (r[1].low < r[2].low && r[1].close > r[1].open && r[1].close > r[2].close);
   return (r[1].high > r[2].high && r[1].close < r[1].open && r[1].close < r[2].close);
}
bool SMC_IsPriceNearLevel(const int dirSign, const string sym, const double mult)
{
   string src = "";
   double lvl = 0.0;
   double atr = SMC_EffectiveSymbolATR(sym);
   if(atr <= 0.0) return false;
   double px = (dirSign > 0) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   return SMC_UnifiedFindTouchedLevel(dirSign, px, atr * MathMax(0.05, mult), lvl, src);
}
// SMC_M5H1PreciseAligned → SMC_GOMAlign.mqh
bool SMC_M5EMATrendAligned(const int dirSign)
{
   if(dirSign == 0) return true;
   string d = g_smcTfM5Dir;
   StringToUpper(d);
   if(StringLen(d) == 0 || d == "NEUT" || d == "NEUTRAL") return true;
   if(dirSign > 0)
      return !(StringFind(d, "BEAR") >= 0 || d == "SELL" || d == "DOWN");
   return !(StringFind(d, "BULL") >= 0 || d == "BUY" || d == "UP");
}
bool SMC_M1BarConfirmsDirection(const int dirSign)
{
   if(dirSign == 0) return false;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 2, r) < 2) return false;
   if(dirSign > 0)
      return r[1].close > r[1].open;
   else
      return r[1].close < r[1].open;
}
bool SMC_GhostOrderflowAligned(const int dirSign)
{
   if(dirSign == 0) return true;
   if(dirSign > 0) return (g_smcGhostBuyPct >= 45.0);
   return (g_smcGhostBuyPct <= 55.0);
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
   double minCoh = SMC_EffectiveGOMMinCoherence();
   if(minCoh <= 0.0) return true;
   if(g_smcGomCoherence <= 0.0) return false;
   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH && minCoh > 65.0) minCoh = 65.0;
   else if(SMC_IsWeltradeSymbol(_Symbol) && minCoh > 65.0) minCoh = 65.0;
   return (g_smcGomCoherence >= minCoh);
}
// COG_ConflictsWithGOM → SMC_GOMAlign.mqh
// TryExecuteGOMPerfectEntry, ManageGOMAutonomousStrategy → SMC_GOM_Autonomous.mqh
void ManageManualTradeSLTP() {}
void ManageGOMWaitPullbackLimit() {}
void ManageGOMVerdictExits()
{
   if(!UseGOMWaitAutoClose && !UseCloseOnVerdictWait) return;
   if(!g_smcGomConnected) return;
   if(PositionsTotal() <= 0) return;

   TradingSignal sig = GOM_CalcSignal(SMCGP_DisplayVerdictNum(), g_smcGomVerdictNumPrev,
                                      g_smcGomQuality, g_smcGomCoherence);
   bool waitClose = (SMCGP_DisplayVerdictNum() == 0);
   bool exitNow   = (sig == SIGNAL_EXIT_NOW || sig == SIGNAL_EXIT_SOON);
   if(!waitClose && !exitNow) return;

   if(waitClose)
   {
      if(g_gomWaitSince <= 0) return;
      if(TimeCurrent() - g_gomWaitSince < 5) return;
   }

   // v1.56.6: PainX/GainX/Boom/Crash — ne jamais couper avant ~90% du SL hard ($3)
   // (logs 2026-10-25: GOM EXIT NOW a -0.70$ / -1.91$ juste avant le spike)
   bool spikeSym = SMC_IsSynthSpikeFamily(_Symbol);
   double hard = SMC_HardMaxLossUSD();
   if(hard <= 0.0) hard = MathMax(3.0, UniversalMaxLossUSD);
   double minLoss = MathMax(GOMWaitCloseMinLossUSD, CloseOnWaitLossMinUSD);
   if(spikeSym)
      minLoss = MathMax(minLoss, MathMin(hard * 0.90, MaxLossPerSpikeTradeDollars * 0.90));

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;

      ulong  ticket = posInfo.Ticket();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      int    posDir = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      string reason = "";
      bool   force  = false;

      if(waitClose)
      {
         if(profit >= 0.0)
            continue; // gains: trailing / giveback
         if(profit <= -minLoss)
            reason = "CLOSE NOW - WAIT perte >= seuil $";
         else
            continue; // attendre SL ~$3 — plus de WAIT soutenu a -0.2$
      }
      else if(exitNow)
      {
         bool inversion = ((g_smcGomVerdictNum > 0 && posDir < 0) ||
                           (g_smcGomVerdictNum < 0 && posDir > 0));
         if(spikeSym)
         {
            if(profit > -minLoss)
               continue;
            reason = inversion ? "GOM inversion - EXIT NOW near SL"
                               : "GOM EXIT NOW near SL";
         }
         else
         {
            if(inversion)
               reason = "GOM inversion - EXIT NOW";
            else if(profit <= -minLoss)
               reason = "GOM EXIT NOW";
            else
               continue;
            force = true;
         }
      }
      if(StringLen(reason) == 0) continue;

      Print("[GOM-EXIT] ", _Symbol, " ticket=", ticket,
            " P/L=", DoubleToString(profit, 2), "$ seuil=-", DoubleToString(minLoss, 2),
            "$ | ", reason, " | vn=", g_smcGomVerdictNum, " spike=", spikeSym);
      PositionCloseWithLog(ticket, reason, force);
   }
}

void SMC_EnforceTerminalOrderLimits() {}
void SMC_ClearSymbolLocksOnInit() {}
void SMC_ResetPerformancePauseDaily() {}
void SMC_ResetPerformancePauseFull() {}
void SMC_RecordDailyTradeOpen() {}
double SMC_GetDailyBalanceDepositsUSD()
{
   if(g_dailyStartEquity <= 0.0) return 0.0;
   MqlDateTime dtStart;
   TimeCurrent(dtStart);
   datetime dayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00",
                                                 dtStart.year, dtStart.mon, dtStart.day));
   if(!HistorySelect(dayStart, TimeCurrent())) return 0.0;
   double deposits = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE) != DEAL_TYPE_BALANCE)
         continue;
      double amount = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(amount > 0.0) deposits += amount;
   }
   return deposits;
}
double SMC_GetDailyProfitUSD()
{
   UpdateDailyEquityStats();
   if(g_dailyStartEquity <= 0.0) return 0.0;
   return AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity - SMC_GetDailyBalanceDepositsUSD();
}
double SMC_GetDailyProfitTargetUSD()
{
   UpdateDailyEquityStats();
   if(g_dailyStartEquity <= 0.0 || DailyProfitTargetPct <= 0.0) return 0.0;
   return g_dailyStartEquity * DailyProfitTargetPct / 100.0;
}
bool SMC_GOMSupportsOpenPosition(const int posDir)
{
   if(!UseGOMVerdictFilter || !g_smcGomConnected) return true;
   if(g_smcGomVerdictNum == 0) return false;
   if(g_smcGomForceExhausted) return false;
   if(posDir == 1 && g_smcGomVerdictNum <= 0) return false;
   if(posDir == -1 && g_smcGomVerdictNum >= 0) return false;
   return true;
}
double SMC_GetPositionMaxLossUSD(const int posDir, const bool isGomWait)
{
   if(isGomWait)
      return MathMax(0.01, GOMWaitCloseMinLossUSD);
   if(UseGOMVerdictFilter && g_smcGomConnected)
   {
      if(g_smcGomVerdictNum == 0 || !SMC_GOMSupportsOpenPosition(posDir))
         return MathMax(0.01, GOMWaitCloseMinLossUSD);
      return MathMax(0.01, MathMin(GOMHoldMaxLossUSD, SMC_HardMaxLossUSD()));
   }
   return SMC_HardMaxLossUSD();
}
bool GOM_EntrySupportsOpenPosition(const int posDir)
{
   return SMC_GOMSupportsOpenPosition(posDir);
}
// SMC_MarkSpikeCaptured — implémenté dans SMC_Universal.mq5
// SMC_CountSmallM1BarsAfterTime — implémenté dans SMC_Universal.mq5
bool EvaluateEntryWithMultipleSignals() { return false; }

bool SMC_EntryPermissionsOK(const string symbol, const int dirSign, const string label)
{
   string reason = "";
   if(BlockAllTrades)
      reason = "BlockAllTrades activé";
   else if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      reason = "terminal déconnecté";
   else if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      reason = "AutoTrading terminal désactivé";
   else if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      reason = "trading interdit dans les propriétés de l'EA";
   else if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      reason = "trading interdit sur le compte";
   else
   {
      long mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
         reason = "symbole non-ouvert aux nouvelles positions";
      else if(mode == SYMBOL_TRADE_MODE_LONGONLY && dirSign < 0)
         reason = "symbole réservé aux positions BUY";
      else if(mode == SYMBOL_TRADE_MODE_SHORTONLY && dirSign > 0)
         reason = "symbole réservé aux positions SELL";
   }

   if(StringLen(reason) == 0)
      return true;

   static datetime lastLog = 0;
   static string lastReason = "";
   if(reason != lastReason || TimeCurrent() - lastLog >= 30)
   {
      Print("[AUTO-ENTRY] Ouverture bloquée | ", symbol, " | ", reason,
            " | ", label);
      lastLog = TimeCurrent();
      lastReason = reason;
   }
   return false;
}

// Marqueur : SMC_Universal.mq5 ne definit ses propres helpers de repli que si ce marqueur est absent (stub ancien)
#define SMC_STUBS_LIMIT_HELPERS 1

//--- Anti "Invalid price" sur LIMIT (Boom/Crash : le prix derive tick par tick pendant la latence d'envoi)
input double LimitMaxDistATR = 4.0; // distance max marche->LIMIT en ATR M1 (0 = pas de plafond) : au-dela l'ordre est refuse
input int LimitSafetyTicks = 15; // marge (ticks) entre un LIMIT et le prix marche, en plus stops-level + 2x spread

// Distance minimale (en prix) exigee entre le marche et un LIMIT
double SMC_LimitMinGap(const string sym)
{
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tick  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = point;
   long lvl = MathMax(SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL),
                      SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL));
   double spread = SymbolInfoDouble(sym, SYMBOL_ASK) - SymbolInfoDouble(sym, SYMBOL_BID);
   if(spread < 0.0) spread = 0.0;
   return (double)lvl * point + 2.0 * spread + (double)MathMax(0, LimitSafetyTicks) * tick;
}

// Aligne un prix sur le tick size du symbole (BUY LIMIT -> arrondi bas, SELL LIMIT -> arrondi haut)
double SMC_AlignToTick(const string sym, const double price, const bool roundUp)
{
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double p = price;
   if(tick > 0.0)
   {
      double n = p / tick;
      n = roundUp ? MathCeil(n - 1e-9) : MathFloor(n + 1e-9);
      p = n * tick;
   }
   return NormalizeDouble(p, dg);
}

// Revalide un LIMIT avec les cotations FRAICHES juste avant OrderSend.
// - BUY LIMIT doit etre <= Ask - gap ; SELL LIMIT >= Bid + gap
// - LIMIT "DOW" : jamais decale (on garde le niveau), refuse si le prix est deja trop pres (pas de chase)
// - autres LIMIT : decales (SL/TP suivent) pour respecter la distance minimale
// Retourne false si l'ordre ne doit pas partir.
bool SMC_PrepareLimitForSend(MqlTradeRequest &req, const string label, const double gapMult)
{
   if(req.action != TRADE_ACTION_PENDING) return true;
   if(req.type != ORDER_TYPE_BUY_LIMIT && req.type != ORDER_TYPE_SELL_LIMIT) return true;
   string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || req.price <= 0.0) return true;

   double gap = SMC_LimitMinGap(sym) * MathMax(1.0, gapMult);
   bool isBuy = (req.type == ORDER_TYPE_BUY_LIMIT);
   bool isDow = (StringFind(req.comment, "DOW") >= 0);
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double oldPrice = req.price;
   double limitPx  = isBuy ? (ask - gap) : (bid + gap);
   bool tooClose   = isBuy ? (req.price > limitPx) : (req.price < limitPx);

   if(tooClose && !isDow)
   {
      static datetime s_lastLog = 0;
      bool doLog = (TimeCurrent() - s_lastLog >= 5);
      double shift = MathAbs(req.price - limitPx);
      req.price = limitPx;
      if(isBuy) { if(req.sl > 0.0) req.sl -= shift; if(req.tp > 0.0) req.tp -= shift; }
      else      { if(req.sl > 0.0) req.sl += shift; if(req.tp > 0.0) req.tp += shift; }
      if(doLog)
      {
         s_lastLog = TimeCurrent();
         PrintFormat("[LIMIT-GUARD] %s %s decale %.5f -> %.5f (bid=%.5f ask=%.5f gap=%.5f) | %s",
                     sym, (isBuy ? "BUY LIMIT" : "SELL LIMIT"), oldPrice, limitPx, bid, ask, gap, label);
      }
   }
   else if(tooClose && isDow)
   {
      static datetime s_lastDowClose = 0;
      if(TimeCurrent() - s_lastDowClose >= 5)
      {
         s_lastDowClose = TimeCurrent();
         PrintFormat("[LIMIT-GUARD] %s %s DOW trop pres du marche — fill attendu | %s",
                     sym, (isBuy ? "BUY LIMIT" : "SELL LIMIT"), label);
      }
   }

   // Plafond de distance : un LIMIT trop eloigne du marche n'est pas envoye (0 = desactive)
   // LIMIT DOW : ancré sur DOW_TL_Proj — ne jamais refuser pour "trop loin"
   if(LimitMaxDistATR > 0.0 && !isDow)
   {
      double atrM1Val = 0.0;
      {
         double a[];
         int h = iATR(sym, PERIOD_M1, 14);
         if(h != INVALID_HANDLE && CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0) atrM1Val = a[0];
         if(h != INVALID_HANDLE) IndicatorRelease(h);
      }
      double mkt  = isBuy ? ask : bid;
      double dist = MathAbs(mkt - req.price);
      if(atrM1Val > 0.0 && dist > atrM1Val * LimitMaxDistATR)
      {
         static datetime s_lastFar = 0;
         if(TimeCurrent() - s_lastFar >= 5)
         {
            s_lastFar = TimeCurrent();
            PrintFormat("[LIMIT-GUARD] %s %s refuse: trop eloigne (%.5f = %.1f ATR M1 > max %.1f) | %s",
                        sym, (isBuy ? "BUY LIMIT" : "SELL LIMIT"), dist, dist / atrM1Val, LimitMaxDistATR, label);
         }
         return false;
      }
   }

   req.price = SMC_AlignToTick(sym, req.price, !isBuy);
   if(req.sl > 0.0) req.sl = NormalizeDouble(req.sl, dg);
   if(req.tp > 0.0) req.tp = NormalizeDouble(req.tp, dg);
   return true;
}

//--- Max N ordres LIMIT en attente dans tout le terminal : on ne garde que les MEILLEURS
//--- (input MaxLimitOrdersTerminal deja defini dans SMC_Universal.mq5, DISCIPLINE ROBOT)

// Score d'un LIMIT : verdict GOM du symbole (PERFECT > GOOD), penalite si verdict oppose, proximite du marche
double SMC_LimitScore(const string sym, const bool isBuy, const double price)
{
   int vn = SMCGP_GetCachedVerdictNum(sym);
   if(vn == -999 && sym == _Symbol) vn = g_smcGomVerdictNum;
   if(vn == -999) vn = 0;
   double score = MathAbs((double)vn) * 100.0;
   if((isBuy && vn < 0) || (!isBuy && vn > 0)) score -= 200.0;
   double mkt = isBuy ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   if(mkt > 0.0 && price > 0.0)
   {
      double distBps = MathAbs(price - mkt) / mkt * 10000.0;
      score -= MathMin(distBps, 80.0) * 0.5; // plus proche du marche = plus probable
   }
   return score;
}

// Garde le nombre de LIMIT en attente <= MaxLimitOrdersTerminal.
// Plein : le nouveau LIMIT remplace le PIRE existant s'il est nettement meilleur (+5 pts), sinon il est refuse.
bool SMC_LimitSlotGate(MqlTradeRequest &req, const string label)
{
   const int maxLimits = MathMax(1, MaxLimitOrdersTerminal);
   if(req.action != TRADE_ACTION_PENDING) return true;
   if(req.type != ORDER_TYPE_BUY_LIMIT && req.type != ORDER_TYPE_SELL_LIMIT) return true;

   string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
   bool isBuy = (req.type == ORDER_TYPE_BUY_LIMIT);
   double newScore = SMC_LimitScore(sym, isBuy, req.price);

   int n = 0;
   ulong worstTk = 0;
   double worstScore = DBL_MAX;
   string worstSym = "";
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      n++;
      string osym = OrderGetString(ORDER_SYMBOL);
      double sc = SMC_LimitScore(osym, (ot == ORDER_TYPE_BUY_LIMIT), OrderGetDouble(ORDER_PRICE_OPEN));
      if(sc < worstScore) { worstScore = sc; worstTk = tk; worstSym = osym; }
   }
   if(n < maxLimits) return true;

   static datetime s_lastLog = 0;
   bool doLog = (TimeCurrent() - s_lastLog >= 10);
   if(worstTk == 0 || newScore <= worstScore + 5.0)
   {
      if(doLog)
      {
         s_lastLog = TimeCurrent();
         PrintFormat("[LIMIT-SLOTS] %d/%d LIMIT deja en attente - %s refuse (score %.1f <= pire %.1f) | %s",
                     n, maxLimits, sym, newScore, worstScore, label);
      }
      return false;
   }
   MqlTradeRequest rm = {};
   MqlTradeResult  rr = {};
   rm.action = TRADE_ACTION_REMOVE;
   rm.order  = worstTk;
   if(!OrderSend(rm, rr) ||
      (rr.retcode != TRADE_RETCODE_DONE && rr.retcode != TRADE_RETCODE_PLACED))
   {
      if(doLog) { s_lastLog = TimeCurrent(); Print("[LIMIT-SLOTS] annulation du pire LIMIT #", worstTk, " impossible ret=", rr.retcode); }
      return false;
   }
   PrintFormat("[LIMIT-SLOTS] LIMIT #%I64u %s (score %.1f) remplace par %s (score %.1f) | max=%d | %s",
               worstTk, worstSym, worstScore, sym, newScore, maxLimits, label);
   return true;
}

//--- PERFECT + DOW : MARKET immediat apres reaction DOW
//--- Spike (PainX/GainX) ET FX Vol : quand le prix est deja en zone DOW, le LIMIT refuse
//--- ("pas de chase") — il faut un MARKET pour capturer le move.
input bool   StratPerfectDowEpMarket      = true;  // PERFECT + DOW => MARKET (spike + FX Vol)
input int    StratDowEpMarketCooldownSec  = 60;    // pause min entre 2 entrees MARKET DOW EP sur ce graphique (s)
input double StratDowEpMarketMaxATR       = 3.0;   // refuse si le prix est a plus de N ATR M1 du niveau DOW EP (niveau perime)

// handled=true => ce module gere le signal PERFECT (le LIMIT DOW ne doit pas etre pose en parallele).
// Retourne true seulement si une position a ete ouverte.
bool Strat_TryPerfectDowEpMarket(const int dirSign, bool &handled)
{
   handled = false;
   if(!StratPerfectDowEpMarket || dirSign == 0) return false;
   if(MathAbs(g_smcGomVerdictNum) < 3) return false;               // PERFECT uniquement
   // Spike OU FX Vol (LIMIT en zone DOW = pas de chase → MARKET requis)
   if(!Strat_IsSpikeMarketSymbol(_Symbol) && !Strat_IsFxVolFamily(_Symbol)) return false;

   static datetime s_diag = 0;
   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   int s5 = Strat_TfSign(g_smcTfM5Dir);
   // M5 clairement contre = vraie correction → bloquer. Neutre / aligné = OK (M1 non requis).
   if(s5 != 0 && s5 != dirSign)
   {
      if(TimeCurrent() - s_diag >= 15)
      {
         s_diag = TimeCurrent();
         PrintFormat("[STRAT-DOW-EP-MKT] PERFECT non execute — M5 contre | M1=%s M5=%s | dir=%s",
                     m1, g_smcTfM5Dir, (dirSign > 0 ? "BUY" : "SELL"));
      }
      return false;
   }
   if(!Strat_DowAligned(dirSign))
   {
      if(TimeCurrent() - s_diag >= 15)
      {
         s_diag = TimeCurrent();
         PrintFormat("[STRAT-DOW-EP-MKT] PERFECT non execute — DOW pas dans le sens | M5=%s dir=%s",
                     g_smcTfM5Dir, (dirSign > 0 ? "BUY" : "SELL"));
      }
      return false;
   }

   // Niveau DOW EP / TL dans le sens (BULL -> BUY, BEAR -> SELL)
   string tok = (dirSign > 0) ? "DOW_BULL_EP" : "DOW_BEAR_EP";
   double ep = 0.0;
   if(ObjectFind(0, tok) >= 0) ep = ObjectGetDouble(0, tok, OBJPROP_PRICE, 0);
   if(ep <= 0.0)
   {
      int tot = ObjectsTotal(0, -1, -1);
      for(int j = 0; j < tot; j++)
      {
         string on = ObjectName(0, j, -1, -1);
         string ou = on; StringToUpper(ou);
         if(StringFind(ou, "DOW") < 0) continue;
         // EP ou TL/EP (label chart "DOW SELL TL/EP")
         if(StringFind(ou, "EP") < 0 && StringFind(ou, "TL") < 0) continue;
         if(dirSign < 0 && StringFind(ou, "SELL") < 0 && StringFind(ou, "BEAR") < 0) continue;
         if(dirSign > 0 && StringFind(ou, "BUY")  < 0 && StringFind(ou, "BULL") < 0) continue;
         double pr = ObjectGetDouble(0, on, OBJPROP_PRICE, 0);
         if(pr <= 0.0) pr = ObjectGetDouble(0, on, OBJPROP_PRICE, 1);
         if(pr > 0.0) { ep = pr; break; }
      }
   }
   if(ep <= 0.0)
   {
      if(TimeCurrent() - s_diag >= 15)
      {
         s_diag = TimeCurrent();
         Print("[STRAT-DOW-EP-MKT] PERFECT non execute — pas de niveau DOW EP/TL");
      }
      return false;       // pas de DOW EP : LIMIT seulement (ALIGN mid-air interdit v1.56.7)
   }

   // Deja en position sur ce symbole : rien a faire
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong pt = PositionGetTicket(p);
      if(pt == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
         return false;
   }

   static datetime s_lastOk = 0, s_lastTry = 0, s_lastLog = 0;
   datetime now = TimeCurrent();
   if(s_lastOk > 0 && now - s_lastOk < MathMax(5, StratDowEpMarketCooldownSec)) return false;
   if(s_lastTry > 0 && now - s_lastTry < 3) return false;          // anti-rafale

   // PERFECT spike + DOW : ne pas re-bloquer via cascade M1/M5 de Strat_AllowsOpen
   // (M1 lag / GTF MIXED est exactement le cas où on doit entrer pour capturer la chaîne).
   if(StratStrictEnable)
   {
      int vnChk = Strat_LocalVn(_Symbol);
      if(vnChk == 0 || MathAbs(vnChk) < 3)
      { if(now - s_lastLog >= 15) { s_lastLog = now; Print("[STRAT-DOW-EP-MKT] refus: pas PERFECT"); } return false; }
      if((dirSign > 0 && vnChk < 0) || (dirSign < 0 && vnChk > 0))
      { if(now - s_lastLog >= 15) { s_lastLog = now; Print("[STRAT-DOW-EP-MKT] refus: contre-verdict"); } return false; }
   }

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return false;
   double price = (dirSign > 0) ? ask : bid;

   double atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50.0;
   {
      double a[];
      int h = iATR(_Symbol, PERIOD_M1, 14);
      if(h != INVALID_HANDLE && CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0) atr = a[0];
      if(h != INVALID_HANDLE) IndicatorRelease(h);
   }
   // Trop loin de la DOW → ne PAS marquer handled : laisser le MARKET rattrapage (Aligned)
   if(StratDowEpMarketMaxATR > 0.0 && MathAbs(price - ep) > atr * StratDowEpMarketMaxATR)
   {
      if(now - s_lastLog >= 15)
      {
         s_lastLog = now;
         PrintFormat("[STRAT-DOW-EP-MKT] DOW EP %s trop loin (> %.1f ATR) — delegation rattrapage TF",
                     DoubleToString(ep, dg), StratDowEpMarketMaxATR);
      }
      return false;
   }
   handled = true; // zone DOW valide : ce module prend le relais (pas de LIMIT en parallele)

   // Lot / SL / TP : meme calcul que le LIMIT DOW (perte max $ par trade spike)
   double lot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVl = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSz <= 0) tickSz = _Point;
   if(tickVl <= 0) tickVl = 1.0;
   double maxLoss = 3.0;
   if(MaxLossPerSpikeTradeDollars > 0.0) maxLoss = MaxLossPerSpikeTradeDollars;
   double slDist = (maxLoss / MathMax(lot, 0.01)) * (tickSz / tickVl);
   if(slDist <= 0) slDist = atr * 1.5;
   double sl = (dirSign > 0) ? NormalizeDouble(price - slDist, dg)       : NormalizeDouble(price + slDist, dg);
   double tp = (dirSign > 0) ? NormalizeDouble(price + slDist * 1.5, dg) : NormalizeDouble(price - slDist * 1.5, dg);

   s_lastTry = now;

   // Un LIMIT DOW en attente sur ce symbole est remplace par l'entree MARKET
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      string cm = OrderGetString(ORDER_COMMENT);
      if(StringFind(cm, "DOW") < 0 && StringFind(cm, "STRAT") < 0) continue;
      MqlTradeRequest rm = {};
      MqlTradeResult  rr = {};
      rm.action = TRADE_ACTION_REMOVE;
      rm.order  = tk;
      if(OrderSend(rm, rr))
         Print("[STRAT-DOW-EP-MKT] LIMIT DOW #", tk, " remplace par entree MARKET (PERFECT + DOW)");
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.type      = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = price;
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 30;
   req.magic     = InpMagicNumber;
   req.comment   = StringFormat("STRAT DOW EP MKT %s @%.5f", (dirSign > 0 ? "BUY" : "SELL"), ep);
   long fillMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)      req.type_filling = ORDER_FILLING_FOK;
   else if((fillMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) req.type_filling = ORDER_FILLING_IOC;
   else                                                           req.type_filling = ORDER_FILLING_RETURN;

   // Bypass cascade H1+M1 de FinalOpenGate : PERFECT+DOW a déjà validé M5/DOW ici.
   bool sent = SafeOrderSend(req, res, "STRAT-DOW-EP-MKT");
   if(sent && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL))
   {
      s_lastOk = now;
      PrintFormat("[STRAT-DOW-EP-MKT] %s MARKET @ %s | DOW EP=%s | SL=%s TP=%s | vn=%d M1=%s M5=%s | ticket=%I64u",
                  (dirSign > 0 ? "BUY" : "SELL"), DoubleToString(price, dg), DoubleToString(ep, dg),
                  DoubleToString(sl, dg), DoubleToString(tp, dg), g_smcGomVerdictNum, m1, g_smcTfM5Dir, res.order);
      return true;
   }
   if(now - s_lastLog >= 10)
   {
      s_lastLog = now;
      Print("[STRAT-DOW-EP-MKT] echec MARKET ", (dirSign > 0 ? "BUY" : "SELL"), " ret=", res.retcode, " ", res.comment);
   }
   return false;
}

//--- PERFECT + TF alignes + prix au touch du trendline GOM_TF_TL_M1/M5 : MARKET IMMEDIAT, TOUS symboles
//--- (FX Vol, SFX Vol, Volatility Index, Step, ... en plus des Boom/Crash/PainX/GainX)
double SMC_TrendLineValueAt(const string objName, const datetime at);                    // definie dans SMC_Universal.mq5
bool   SMC_FindReactionObjectLevel(const string symbol, const string token, double &level); // idem

input bool   StratPerfectTlMarket         = true;  // PERFECT + alignement TF + touch GOM_TF_TL M1/M5 => MARKET direct
input int    StratTlMarketCooldownSec     = 60;    // pause min entre 2 entrees MARKET TL sur ce symbole (s)
input double StratTlTouchATR              = 0.35;  // tolerance de touch = N x ATR M1 (min 2x spread)
input double StratTlSlATR                 = 1.5;   // SL = N x ATR M1 (min stops-level broker)
input double StratTlTpRR                  = 1.5;   // TP = RR x distance SL

// Alignement requis : M5 dans le sens ET au moins un parmi M1 / M15 / H1  (M5+M1, M5+M15 ou M5+H1)
bool Strat_TlAlignmentOK(const int dirSign, string &tfs)
{
   tfs = "";
   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   int s1  = Strat_TfSign(m1);
   int s5  = Strat_TfSign(g_smcTfM5Dir);
   int s15 = Strat_TfSign(g_smcTfM15Dir);
   int sh1 = Strat_TfSign(g_smcTfH1Dir);
   if(s5 != dirSign) return false;
   tfs = "M5";
   if(s1  == dirSign) tfs += "+M1";
   if(s15 == dirSign) tfs += "+M15";
   if(sh1 == dirSign) tfs += "+H1";
   return (s1 == dirSign || s15 == dirSign || sh1 == dirSign);
}

// handled=true => signal PERFECT + TL touche : ce module gere (pas de LIMIT en parallele).
// Retourne true seulement si une position a ete ouverte.
bool Strat_TryPerfectTlMarket(const int dirSign, bool &handled)
{
   handled = false;
   if(!StratPerfectTlMarket || dirSign == 0) return false;
   if(MathAbs(g_smcGomVerdictNum) < 3) return false;                 // PERFECT uniquement
   if((dirSign > 0 && g_smcGomVerdictNum < 0) || (dirSign < 0 && g_smcGomVerdictNum > 0)) return false;

   static datetime s_diag = 0;
   string tfs = "";
   if(!Strat_TlAlignmentOK(dirSign, tfs))
   {
      if(TimeCurrent() - s_diag >= 20)
      {
         s_diag = TimeCurrent();
         string m1d = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
         PrintFormat("[STRAT-TL-MKT] PERFECT non execute — alignement insuffisant | M1=%s M5=%s M15=%s H1=%s | dir=%s",
                     m1d, g_smcTfM5Dir, g_smcTfM15Dir, g_smcTfH1Dir, (dirSign > 0 ? "BUY" : "SELL"));
         SMC_APlus_SampleOnSignal(_Symbol, dirSign);
      }
      return false;
   }

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return false;
   double price  = (dirSign > 0) ? ask : bid;
   double spread = ask - bid;

   double atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50.0;
   {
      double a[];
      int h = iATR(_Symbol, PERIOD_M1, 14);
      if(h != INVALID_HANDLE && CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0) atr = a[0];
      if(h != INVALID_HANDLE) IndicatorRelease(h);
   }
   double tol = MathMax(atr * MathMax(0.05, StratTlTouchATR), spread * 2.0);

   // Touch du trendline M1 puis M5 (le plus proche du prix gagne)
   string tlNames[2] = {"GOM_TF_TL_M1", "GOM_TF_TL_M5"};
   string tlHit = "";
   double tlLvl = 0.0, bestD = DBL_MAX;
   string distInfo = "";
   for(int k = 0; k < 2; k++)
   {
      double lv = 0.0;
      if(!SMC_FindReactionObjectLevel(_Symbol, tlNames[k], lv) || lv <= 0.0)
      {
         if(StringLen(distInfo) > 0) distInfo += " ";
         distInfo += tlNames[k] + "=ABSENT";
         continue;
      }
      double d = MathAbs(price - lv);
      if(StringLen(distInfo) > 0) distInfo += " ";
      distInfo += StringFormat("%s dist=%s tol=%s", tlNames[k],
                               DoubleToString(d, dg), DoubleToString(tol, dg));
      if(d <= tol && d < bestD) { bestD = d; tlHit = tlNames[k]; tlLvl = lv; }
   }
   if(StringLen(tlHit) == 0)
   {
      if(TimeCurrent() - s_diag >= 20)
      {
         s_diag = TimeCurrent();
         PrintFormat("[STRAT-TL-MKT] PERFECT non execute — pas de contact GOM_TF_TL | %s | TF=%s | dir=%s px=%s",
                     distInfo, tfs, (dirSign > 0 ? "BUY" : "SELL"), DoubleToString(price, dg));
         SMC_APlus_SampleOnSignal(_Symbol, dirSign);
      }
      return false;     // pas de touch : le chemin LIMIT habituel reste actif
   }
   handled = true;

   // Deja en position sur ce symbole : rien a faire
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong pt = PositionGetTicket(p);
      if(pt == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
         return false;
   }

   static datetime s_lastOk = 0, s_lastTry = 0, s_lastLog = 0;
   datetime now = TimeCurrent();
   if(s_lastOk > 0 && now - s_lastOk < MathMax(5, StratTlMarketCooldownSec)) return false;
   if(s_lastTry > 0 && now - s_lastTry < 3) return false;           // anti-rafale

   // SL / TP : ATR M1, jamais sous le stops-level du broker
   double pt   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minStop = ((double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 2.0) * pt;
   double slDist = MathMax(MathMax(atr * MathMax(0.5, StratTlSlATR), spread * 3.0), minStop);
   double tpDist = slDist * MathMax(0.5, StratTlTpRR);
   double sl = (dirSign > 0) ? NormalizeDouble(price - slDist, dg) : NormalizeDouble(price + slDist, dg);
   double tp = (dirSign > 0) ? NormalizeDouble(price + tpDist, dg) : NormalizeDouble(price - tpDist, dg);
   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   s_lastTry = now;

   // Un LIMIT DOW/STRAT en attente sur ce symbole est remplace par l'entree MARKET
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      string cm = OrderGetString(ORDER_COMMENT);
      if(StringFind(cm, "DOW") < 0 && StringFind(cm, "STRAT") < 0) continue;
      MqlTradeRequest rm = {};
      MqlTradeResult  rr = {};
      rm.action = TRADE_ACTION_REMOVE;
      rm.order  = tk;
      if(OrderSend(rm, rr))
         Print("[STRAT-TL-MKT] LIMIT #", tk, " remplace par entree MARKET (PERFECT + ", tfs, ")");
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.type      = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = price;
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 30;
   req.magic     = InpMagicNumber;
   req.comment   = StringFormat("STRAT TL MKT %s %s", (dirSign > 0 ? "BUY" : "SELL"), tlHit);
   long fillMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)      req.type_filling = ORDER_FILLING_FOK;
   else if((fillMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) req.type_filling = ORDER_FILLING_IOC;
   else                                                           req.type_filling = ORDER_FILLING_RETURN;

   bool sent = SafeOrderSend(req, res, "STRAT-TL-MKT");
   if(sent && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL))
   {
      s_lastOk = now;
      PrintFormat("[STRAT-TL-MKT] %s MARKET @ %s | %s=%s | SL=%s TP=%s | vn=%d TF=%s | ticket=%I64u",
                  (dirSign > 0 ? "BUY" : "SELL"), DoubleToString(price, dg), tlHit, DoubleToString(tlLvl, dg),
                  DoubleToString(sl, dg), DoubleToString(tp, dg), g_smcGomVerdictNum, tfs, res.order);
      return true;
   }
   if(now - s_lastLog >= 10)
   {
      s_lastLog = now;
      Print("[STRAT-TL-MKT] echec MARKET ", (dirSign > 0 ? "BUY" : "SELL"), " ", _Symbol,
            " ret=", res.retcode, " ", res.comment);
   }
   return false;
}

//--- PERFECT + M1+M5 : MARKET UNIQUEMENT pres d'un niveau (DOW/TL)
//--- v1.56.7: PLUS JAMAIS de "rattrapage" mid-air (cas PainX 800 2026-10-25:
//--- STRAT-DOW/TL avaient refuse, ALIGN a quand meme SELL contre M5 BULL / coh 33%).
input bool   StratPerfectAlignedMarket    = false; // v1.57: OFF — mid-air ALIGN = pertes; FX Vol via DOW-EP/TL only
input int    StratAlignedCooldownSec      = 45;    // pause min entre 2 entrees
input bool   StratAlignedRequireM15       = true;  // exiger M15 aussi (triple conf)
input double StratAlignedSlATR            = 1.2;   // SL = N x ATR M1
input double StratAlignedTpRR             = 1.5;   // TP = RR x SL
input double StratAlignedMaxDistATR       = 0.28;  // distance max prix->DOW/TL (x ATR)
input double StratAlignedMinCoherence     = 55.0;  // coherence GOM min (%)
input double StratAlignedMinQuality       = 50.0;  // qualite GOM min (%)

bool Strat_TryPerfectAlignedMarket(const int dirSign, bool &handled)
{
   handled = false;
   if(!StratPerfectAlignedMarket || dirSign == 0) return false;
   if(MathAbs(g_smcGomVerdictNum) < 3) return false;
   if((dirSign > 0 && g_smcGomVerdictNum < 0) || (dirSign < 0 && g_smcGomVerdictNum > 0))
      return false;

   static datetime s_diag = 0;
   datetime now = TimeCurrent();

   // Spikes PainX/GainX/Boom/Crash UNIQUEMENT (PAS FX Vol — bug 2026-10-25)
   if(Strat_IsSpikeMarketSymbol(_Symbol))
   {
      if(now - s_diag >= 20)
      {
         s_diag = now;
         Print("[STRAT-ALIGN-MKT] REFUS spike ", _Symbol,
               " — MARKET mid-air interdit (utiliser DOW-EP / TL uniquement)");
      }
      return false;
   }

   if(!Strat_IsFxVolFamily(_Symbol))
      return false;

   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   int s1  = Strat_TfSign(m1);
   int s5  = Strat_TfSign(g_smcTfM5Dir);
   int s15 = Strat_TfSign(g_smcTfM15Dir);

   if(s1 != dirSign || s5 != dirSign)
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         PrintFormat("[STRAT-ALIGN-MKT] besoin M1+M5 | M1=%s M5=%s M15=%s dir=%s",
                     m1, g_smcTfM5Dir, g_smcTfM15Dir, (dirSign > 0 ? "BUY" : "SELL"));
      }
      return false;
   }
   if(Strat_TfAgainstDirection(dirSign))
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         Print("[STRAT-ALIGN-MKT] REFUS TF contre | M5=", g_smcTfM5Dir, " H1=", g_smcTfH1Dir);
      }
      return false;
   }
   if(StratAlignedRequireM15 && s15 != dirSign)
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         PrintFormat("[STRAT-ALIGN-MKT] attente M15 | M15=%s dir=%s",
                     g_smcTfM15Dir, (dirSign > 0 ? "BUY" : "SELL"));
      }
      return false;
   }

   // Coherence / qualite : bloquer PERFECT "sale" (33%/30% = piege)
   if(g_smcGomCoherence > 0.0 && g_smcGomCoherence < StratAlignedMinCoherence)
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         PrintFormat("[STRAT-ALIGN-MKT] REFUS coherence %.1f%% < %.1f%%",
                     g_smcGomCoherence, StratAlignedMinCoherence);
      }
      return false;
   }
   if(g_smcGomQuality > 0.0 && g_smcGomQuality < StratAlignedMinQuality)
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         PrintFormat("[STRAT-ALIGN-MKT] REFUS qualite %.1f%% < %.1f%%",
                     g_smcGomQuality, StratAlignedMinQuality);
      }
      return false;
   }

   // DOW doit etre aligne (Strat_DowAligned — pas g_dowState ici: include trop tot)
   if(!Strat_DowAligned(dirSign))
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         Print("[STRAT-ALIGN-MKT] REFUS DOW non aligne | dir=", (dirSign > 0 ? "BUY" : "SELL"));
      }
      return false;
   }

   // Niveau DOW EP / TL obligatoire (objets chart — pas g_dowState avant include Dow)
   double ep = 0.0;
   {
      string tok = (dirSign > 0) ? "DOW_BULL_EP" : "DOW_BEAR_EP";
      if(ObjectFind(0, tok) >= 0) ep = ObjectGetDouble(0, tok, OBJPROP_PRICE, 0);
      if(ep <= 0.0)
      {
         int tot = ObjectsTotal(0, -1, -1);
         for(int j = 0; j < tot; j++)
         {
            string on = ObjectName(0, j, -1, -1);
            string ou = on; StringToUpper(ou);
            if(StringFind(ou, "DOW") < 0) continue;
            if(StringFind(ou, "EP") < 0 && StringFind(ou, "TL") < 0) continue;
            if(dirSign < 0 && StringFind(ou, "SELL") < 0 && StringFind(ou, "BEAR") < 0) continue;
            if(dirSign > 0 && StringFind(ou, "BUY")  < 0 && StringFind(ou, "BULL") < 0) continue;
            double pr = ObjectGetDouble(0, on, OBJPROP_PRICE, 0);
            if(pr <= 0.0) pr = ObjectGetDouble(0, on, OBJPROP_PRICE, 1);
            if(pr > 0.0) { ep = pr; break; }
         }
      }
   }
   if(ep <= 0.0)
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         Print("[STRAT-ALIGN-MKT] REFUS — pas de niveau DOW/TL (plus de rattrapage mid-air)");
      }
      return false;
   }

   double atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50.0;
   {
      double a[];
      int h = iATR(_Symbol, PERIOD_M1, 14);
      if(h != INVALID_HANDLE && CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0) atr = a[0];
      if(h != INVALID_HANDLE) IndicatorRelease(h);
   }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return false;
   double px = (dirSign > 0) ? ask : bid;
   double maxDist = atr * MathMax(0.10, StratAlignedMaxDistATR);
   if(MathAbs(px - ep) > maxDist)
   {
      if(now - s_diag >= 15)
      {
         s_diag = now;
         PrintFormat("[STRAT-ALIGN-MKT] REFUS trop loin du niveau | dist=%.1f > max=%.1f (%.2f ATR) ep=%s px=%s",
                     MathAbs(px - ep), maxDist, StratAlignedMaxDistATR,
                     DoubleToString(ep, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                     DoubleToString(px, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      }
      return false;
   }

   string tfs = "M1+M5";
   if(s15 == dirSign) tfs += "+M15";

   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong pt = PositionGetTicket(p);
      if(pt == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
         return false;
   }

   static datetime s_lastOk = 0, s_lastTry = 0, s_lastLog = 0;
   if(s_lastOk > 0 && now - s_lastOk < MathMax(5, StratAlignedCooldownSec)) return false;
   if(s_lastTry > 0 && now - s_lastTry < 3) return false;

   // A partir d'ici seulement : on prend la main (pas de LIMIT parallele)
   handled = true;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double spread = ask - bid;
   double price  = px;
   double pt   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minStop = ((double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 2.0) * pt;
   double slDist = MathMax(MathMax(atr * MathMax(0.5, StratAlignedSlATR), spread * 3.0), minStop);
   double tpDist = slDist * MathMax(0.5, StratAlignedTpRR);
   double sl = (dirSign > 0) ? NormalizeDouble(price - slDist, dg) : NormalizeDouble(price + slDist, dg);
   double tp = (dirSign > 0) ? NormalizeDouble(price + tpDist, dg) : NormalizeDouble(price - tpDist, dg);
   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   s_lastTry = now;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != (long)InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      string cm = OrderGetString(ORDER_COMMENT);
      if(StringFind(cm, "DOW") < 0 && StringFind(cm, "STRAT") < 0) continue;
      MqlTradeRequest rm = {};
      MqlTradeResult  rr = {};
      rm.action = TRADE_ACTION_REMOVE;
      rm.order  = tk;
      if(OrderSend(rm, rr))
         Print("[STRAT-ALIGN-MKT] LIMIT #", tk, " remplace par MARKET pres niveau (", tfs, ")");
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.type      = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = price;
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 30;
   req.magic     = InpMagicNumber;
   req.comment   = StringFormat("STRAT ALIGN NEAR %s %s", (dirSign > 0 ? "BUY" : "SELL"), tfs);
   long fillMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)      req.type_filling = ORDER_FILLING_FOK;
   else if((fillMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) req.type_filling = ORDER_FILLING_IOC;
   else                                                           req.type_filling = ORDER_FILLING_RETURN;

   // v1.56.7: NE PLUS bypasser FinalOpenGate (LEARN-ONNX / M1M5 / gates)
   bool sent = SafeOrderSend(req, res, "STRAT-ALIGN-MKT");

   if(sent && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL))
   {
      s_lastOk = now;
      PrintFormat("[STRAT-ALIGN-MKT] %s MARKET @ %s | near EP=%s | SL=%s TP=%s | vn=%d TF=%s coh=%.0f | ticket=%I64u",
                  (dirSign > 0 ? "BUY" : "SELL"), DoubleToString(price, dg),
                  DoubleToString(ep, dg), DoubleToString(sl, dg), DoubleToString(tp, dg),
                  g_smcGomVerdictNum, tfs, g_smcGomCoherence, res.order);
      return true;
   }
   if(now - s_lastLog >= 10)
   {
      s_lastLog = now;
      Print("[STRAT-ALIGN-MKT] echec MARKET ", (dirSign > 0 ? "BUY" : "SELL"),
            " ret=", res.retcode, " ", res.comment);
   }
   return false;
}

//--- SafeOrder wrappers — gate GOM WAIT / contre-verdict avant tout envoi
bool SafeOrderSend(MqlTradeRequest &req, MqlTradeResult &result, const string label = "")
{
   ENUM_ORDER_TYPE t = req.type;
   bool isMarket = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_SELL);
   bool isLimit  = (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT);

   if(req.action == TRADE_ACTION_DEAL && req.position > 0)
   {
      if(!SMC_AllowEAExitAfterM1Bars(req.position, label))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         return false;
      }
      return OrderSend(req, result);
   }

   bool isEntryOrder = (req.position == 0 &&
                        (t == ORDER_TYPE_BUY || t == ORDER_TYPE_SELL ||
                         t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT ||
                         t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP ||
                         t == ORDER_TYPE_BUY_STOP_LIMIT || t == ORDER_TYPE_SELL_STOP_LIMIT));
   if((req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING) &&
      isEntryOrder)
   {
      string symbol = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      bool isBuy = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT ||
                    t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_BUY_STOP_LIMIT);
      if(!SMC_EntryPermissionsOK(symbol, isBuy ? 1 : -1, label))
      {
         result.retcode = TRADE_RETCODE_TRADE_DISABLED;
         return false;
      }

      string verdictReason = "";
      if(!SMCGP_EntryVerdictAllowsTrade(symbol, verdictReason))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — verdict GOM non tradable | ",
               symbol, " | ", verdictReason, " | ", label);
         return false;
      }
   }
   if((req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING) &&
      isEntryOrder)
   {
      string spikeSymbol = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      bool isBuyOrder = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT ||
                         t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_BUY_STOP_LIMIT);
      string spikeReason = "";
      if(!SMC_SpikeBlink_OrderAllowed(spikeSymbol, isBuyOrder ? 1 : -1,
                                      isMarket, spikeReason))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — Spike Blink requis | ", spikeSymbol, " ",
               EnumToString(t), " | ", spikeReason, " | ", label);
         return false;
      }
   }

   if((req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING) &&
      isEntryOrder && MathAbs(g_smcGomVerdictNum) < 2 &&
      MathAbs(g_smcGomVerdictNumServer) < 2 &&
      SMC_GOMCurrentVerdictIsWait(req.symbol))
   {
      result.retcode = TRADE_RETCODE_REJECT;
      Print("[SAFE] ORDRE BLOQUÉ — verdict GOM courant WAIT | ", label, " | ",
            EnumToString(t), " | ", req.symbol);
      return false;
   }

   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      if(IsTerminalFull())
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — Terminal plein (", CountTerminalAllOrders(), "/", SMC_EffectiveMaxPositionsTerminal(), ") | ", label, " | ", req.symbol);
         return false;
      }
      string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      if(CountPositionsForSymbol(sym) > 0 || SymbolHasActiveOrder(sym))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — déjà 1 position/ordre sur ", sym, " | ", label);
         return false;
      }
   }

   // ── GATE FINALE OBLIGATOIRE — POINT D'ENTRÉE UNIQUE (AUDIT C1) ──
   // SMC_FinalOpenGate est LE verrou central (WAIT/OFF, direction GOM, famille
   // Boom/Crash, anti-hedge, 1 position/symbole, cap terminal, M1+M5, niveau
   // SMC précis, consolidation, whipsaw). AVANT, seuls les chemins IA l'appelaient :
   // les scalpers (Dow/VolMomentum/FX/Range) le contournaient → deux politiques
   // inégales. C'est DÉSORMAIS vérifié ici, pour TOUT ordre d'ouverture MARKET/PENDING.
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      ENUM_ORDER_TYPE ot = t;
      string symGate = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      bool isOpening = (req.position == 0) && (ot == ORDER_TYPE_BUY || ot == ORDER_TYPE_SELL ||
                       ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT ||
                       ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP);
      if(isOpening && !g_smcAlignExecBypass && !SMC_FinalOpenGate(symGate, ot))
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — GATE FINALE (SMC_FinalOpenGate) | ", symGate, " ",
               EnumToString(ot), " | ", label);
         return false;
      }
   }

   // WAIT (vn=0) : bloquer seulement si local ET serveur sont WAIT
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      int execVn = SMC_ExecutableGomVn();
      if(execVn == 0)
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — GOM=WAIT (vn=0 srv=", g_smcGomVerdictNumServer,
               ") | ", label, " | ",
               (isMarket ? "MARKET" : (isLimit ? "LIMIT" : EnumToString(t))), " | ", req.symbol);
         return false;
      }
      string wSym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      int wVn = SMCGP_GetCachedVerdictNum(wSym);
      if(wVn == 0 && MathAbs(execVn) < 2)
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — GOM WAIT par symbole ", wSym, " (vn=0) | ", label, " | ",
               (isMarket ? "MARKET" : (isLimit ? "LIMIT" : EnumToString(t))));
         return false;
      }
      if(g_smcGomConnected && MathAbs(execVn) < 2)
      {
         string vStr = SMCGP_GetCachedVerdictStr(wSym);
         string gStr = (wSym == _Symbol) ? g_smcGomVerdict : "";
         if(StringFind(vStr, "WAIT") >= 0 || StringFind(gStr, "WAIT") >= 0)
         {
            string shown = (StringLen(vStr) > 0) ? vStr : gStr;
            result.retcode = TRADE_RETCODE_REJECT;
            Print("[SAFE] ORDRE BLOQUÉ — verdict texte WAIT (", shown, ") | ", label, " | ",
                  (isMarket ? "MARKET" : (isLimit ? "LIMIT" : EnumToString(t))), " | ", wSym);
            return false;
         }
      }
    }

   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      if(!g_dowPriceLeadInFlight && MathAbs(SMC_ExecutableGomVn()) < 2)
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum,
               " srv=", g_smcGomVerdictNumServer,
               ") — seul GOOD/PERFECT (|vn|>=2) autorisé | ", label, " | ",
               (isMarket ? "MARKET" : (isLimit ? "LIMIT" : EnumToString(t))), " | ", req.symbol);
         return false;
      }
   }

   // FIX 2026-09-20: Gate M1+M5 OBLIGATOIRE dans SafeOrderSend pour TOUS les ordres
   // Certains chemins d'exécution contournent SMC_FinalOpenGate, donc cette vérification
   // doit être ici pour garantir que M1 et M5 sont alignés avec le sens de l'ordre.
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
      int dirSign = 0;
      if(t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_BUY_STOP)
         dirSign = 1;
      else if(t == ORDER_TYPE_SELL || t == ORDER_TYPE_SELL_LIMIT || t == ORDER_TYPE_SELL_STOP)
         dirSign = -1;
      
      if(dirSign != 0 && !g_dowPriceLeadInFlight)
      {
         string m1Dir = g_smcTfM1Dir;
         string m5Dir = g_smcTfM5Dir;
         StringToUpper(m1Dir);
         StringToUpper(m5Dir);
         
         bool m1Bear = (StringFind(m1Dir, "BEAR") >= 0 || m1Dir == "SELL" || m1Dir == "DOWN");
         bool m1Bull = (StringFind(m1Dir, "BULL") >= 0 || m1Dir == "BUY" || m1Dir == "UP");
         bool m5Bear = (StringFind(m5Dir, "BEAR") >= 0 || m5Dir == "SELL" || m5Dir == "DOWN");
         bool m5Bull = (StringFind(m5Dir, "BULL") >= 0 || m5Dir == "BUY" || m5Dir == "UP");
         
         bool m1Conflict = (dirSign > 0 && m1Bear) || (dirSign < 0 && m1Bull);
         bool m5Conflict = (dirSign > 0 && m5Bear) || (dirSign < 0 && m5Bull);
         
         if(MathAbs(SMC_ExecutableGomVn()) < 2 && (m1Conflict || m5Conflict))
         {
            string conflictTF = m1Conflict ? "M1" : (m5Conflict ? "M5" : "M1+M5");
            result.retcode = TRADE_RETCODE_REJECT;
            Print("[SAFE] ORDRE BLOQUÉ — M1+M5 non alignés : ", sym, " | ",
                  (dirSign > 0 ? "BUY" : "SELL"),
                  " | M1=", g_smcTfM1Dir, " | M5=", g_smcTfM5Dir,
                  " | conflit sur ", conflictTF, " | ", label);
            return false;
         }
      }
   }

   // Cohérence GOM (prédiction vs sentiment / état global du marché) — même seuil
   // profil que CanPlaceOrderByGOM (4469). Si la prédiction et la tendance globale
   // s'opposent (coherence basse), on ne place ni DEAL ni PENDING : le serveur
   // abaisse la cohérence dès qu'il détecte une contradiction (direction_conflict).
   if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
   {
      if(!g_dowPriceLeadInFlight && g_smcGomConnected
      && MathAbs(SMC_ExecutableGomVn()) < 2
      && g_smcGomCoherence > 0.0
      && g_smcGomCoherence < SMC_EffectiveGOMMinCoherence())
      {
         result.retcode = TRADE_RETCODE_REJECT;
         Print("[SAFE] ORDRE BLOQUÉ — cohérence GOM ", DoubleToString(g_smcGomCoherence,1),
               "% < min ", DoubleToString(SMC_EffectiveGOMMinCoherence(),1),
               "% (prédiction/sentiment contradictoires) | ", label, " | ",
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
       string dirCheck = "";
       if(t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT) dirCheck = "BUY";
       else if(t == ORDER_TYPE_SELL || t == ORDER_TYPE_SELL_LIMIT) dirCheck = "SELL";

       // Gate anti-hedge universel (positions + pending opposés + direction PainX/GainX)
       // Toujours actif — jamais contourné par g_smcAlignExecBypass
       if(dirCheck != "" && !CanTradeOnSymbol(sym, dirCheck))
       {
          result.retcode = TRADE_RETCODE_REJECT;
          Print("[SAFE] ORDRE BLOQUÉ — gate CanTradeOnSymbol | ", sym, " ", dirCheck, " | ", label);
          return false;
       }
       if(dirSign != 0 && !SMC_APlusSetupOK(sym, dirSign))
       {
          result.retcode = TRADE_RETCODE_REJECT;
          Print("[SAFE] A+ BLOQUÉ | ", sym, " | ", label);
          return false;
       }
       // Gate apprentissage local (WR / expectancy depuis SMC_Learn CSV)
       if(dirSign != 0 && !LJ_ExpectancyAllowsEntry(dirSign, sym))
       {
          result.retcode = TRADE_RETCODE_REJECT;
          Print("[SAFE] LEARN BLOQUÉ | ", sym, " | ", label);
          LJ_ShadowCandidate(sym, dirSign > 0, "LEARN_GATE");
          return false;
       }
       // FIX v1.57: gate ONNX learn_entry (respecte UseLearnEntryOnnxGate du parent)
       if(UseLearnEntryOnnxGate && dirSign != 0 && !LE_OnnxAllowsEntry(sym, dirSign))
       {
          result.retcode = TRADE_RETCODE_REJECT;
          Print("[SAFE] LEARN-ONNX BLOQUÉ | ", sym, " | ", label);
          LJ_ShadowCandidate(sym, dirSign > 0, "LEARN_ONNX_GATE");
          return false;
       }

       // ── GARDE DIRECTION OPPOSÉE sur même symbole (inconditionnel, bypass-proof) ──
       {
          int opPosType = 0; string opDir = "";
          if(dirSign > 0) { opPosType = (int)POSITION_TYPE_SELL; opDir = "SELL"; }
          else if(dirSign < 0) { opPosType = (int)POSITION_TYPE_BUY; opDir = "BUY"; }
          if(opPosType != 0)
          {
             for(int i = PositionsTotal() - 1; i >= 0; i--)
             {
                ulong tick = PositionGetTicket(i);
                if(tick == 0 || !PositionSelectByTicket(tick)) continue;
                if(PositionGetString(POSITION_SYMBOL) != sym) continue;
                if((int)PositionGetInteger(POSITION_TYPE) == opPosType)
                {
                   result.retcode = TRADE_RETCODE_REJECT;
                   Print("[SAFE] ORDRE BLOQUÉ — ", sym, " — position ", opDir, " déjà ouverte | ", label);
                   return false;
                }
             }
          }
       }
       if(isMarket && !g_smcAlignExecBypass && !g_dowPriceLeadInFlight && !CanPlaceMarketOrder(sym, dirSign))
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
    // Enforcer le SL broker sur le plafond de perte effectif.
    double capPerPositionUSD = SMC_HardMaxLossUSD();
    if(capPerPositionUSD <= 0.0) capPerPositionUSD = 3.0;
    if((req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING) && req.volume > 0)
    {
       string sym = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
       double entryPrice = req.price;
       double slPrice = req.sl;
       bool isBuySide = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT ||
                         t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_BUY_STOP_LIMIT);
       int dirCap = isBuySide ? 1 : -1;
       if(req.action == TRADE_ACTION_PENDING)
       {
          if(t == ORDER_TYPE_BUY_STOP_LIMIT || t == ORDER_TYPE_SELL_STOP_LIMIT)
             entryPrice = req.stoplimit;
          if(entryPrice <= 0.0 ||
             !SMC_CapSLToMaxLossUSD(sym, dirCap, entryPrice, req.volume, slPrice))
          {
             result.retcode = TRADE_RETCODE_REJECT;
             PrintFormat("[SAFE] ORDRE EN ATTENTE REJETÉ — SL absent/incompatible avec le cap $%.2f | %s",
                         capPerPositionUSD, label);
             return false;
          }
          req.sl = slPrice;
       }
       else if(slPrice > 0.0 && entryPrice > 0.0 && slPrice != entryPrice)
       {
          if(SMC_CapSLToMaxLossUSD(sym, dirCap, entryPrice, req.volume, slPrice))
             req.sl = slPrice;
          else
          {
             result.retcode = TRADE_RETCODE_REJECT;
             PrintFormat("[SAFE] ORDRE REJETÉ — impossible de caper SL à $%.2f | %s",
                         capPerPositionUSD, label);
             return false;
          }
       }
    }

    // FIX 2026-09-13 (Claude, demande Sidoine — SFX Vol 20 "Invalid stops",
    // SL négatif -104145.33 / TP absurde 208572.01 poussés par le serveur) :
    // filet de sécurité universel des stops, AVANT OrderSend, pour TOUS les
    // types d'entrée (market + pending). On rejette tout ordre dont un stop
    // existe mais est incohérent (négatif, nul, ou du mauvais côté du prix).
    // Les entrées pending doivent avoir un SL broker; les MARKET reçoivent le
    // leur dans SMCGP_PrepareMarketStops ci-dessous.
    if(req.action == TRADE_ACTION_DEAL || req.action == TRADE_ACTION_PENDING)
    {
       if(req.price > 0)
       {
          bool isBuySide = (t == ORDER_TYPE_BUY || t == ORDER_TYPE_BUY_LIMIT ||
                            t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_BUY_STOP_LIMIT);
          bool stopBad = false;
          if(req.sl < 0.0 || req.tp < 0.0) stopBad = true;
          if(req.sl > 0.0 && (( isBuySide && req.sl >= req.price) || (!isBuySide && req.sl <= req.price))) stopBad = true;
          if(req.tp > 0.0 && (( isBuySide && req.tp <= req.price) || (!isBuySide && req.tp >= req.price))) stopBad = true;
          if(stopBad)
          {
             result.retcode = TRADE_RETCODE_INVALID_STOPS;
             PrintFormat("[SAFE] ORDRE BLOQUÉ — stops invalides (SL=%.5f TP=%.5f @ %.5f %s) | %s",
                         req.sl, req.tp, req.price,
                         (isBuySide ? "BUY" : "SELL"),
                         (StringLen(label) > 0 ? label : "?"));
             return false;
          }
       }
    }

    // FIX v1.35: cible SL initiale de 10 pips et TP de 30 pips; le cap $ prime.
    if(req.action == TRADE_ACTION_DEAL && isMarket)
    {
       string symStops = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
       int dirStops = (t == ORDER_TYPE_BUY) ? 1 : -1;
       double slUse = req.sl, tpUse = req.tp;
       if(!SMCGP_PrepareMarketStops(symStops, dirStops, req.price, req.sl, req.tp, req.volume, slUse, tpUse))
       {
          result.retcode = TRADE_RETCODE_INVALID_STOPS;
          Print("[SAFE] MARKET BLOQUÉ — stops invalides ou incompatibles avec le cap $ | ",
                label, " | ", symStops);
          return false;
       }
       req.sl = slUse;
       req.tp = tpUse;
    }

    // Anti "Invalid price" : revalidation du LIMIT avec les cotations fraiches + 1 retry
    bool isPendLimit = (req.action == TRADE_ACTION_PENDING && isLimit);
    if(isPendLimit && !SMC_PrepareLimitForSend(req, label, 1.0))
    {
       result.retcode = TRADE_RETCODE_INVALID_PRICE;
       return false;
    }
    if(isPendLimit && !SMC_LimitSlotGate(req, label))
    {
       result.retcode = TRADE_RETCODE_REJECT;
       return false;
    }
    bool sent = OrderSend(req, result);
    if(isPendLimit &&
       (result.retcode == TRADE_RETCODE_INVALID_PRICE || result.retcode == TRADE_RETCODE_INVALID_STOPS))
    {
       Print("[LIMIT-GUARD] retcode=", result.retcode, " -> retry avec marge x2.5 | ", req.symbol, " | ", label);
       if(SMC_PrepareLimitForSend(req, label, 2.5))
          sent = OrderSend(req, result);
    }
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

// --- Safe trade wrappers for CTrade::Buy/Sell to enforce GOM gates
bool SafeTradeBuy(double lot, const string symbol, double price, double sl, double tp, const string comment = "")
{
   if(!SMC_EntryPermissionsOK(symbol, 1, comment))
      return false;
   string verdictReason = "";
   if(!SMCGP_EntryVerdictAllowsTrade(symbol, verdictReason))
   {
      Print("[SAFE-TRADE] BUY bloqué — verdict GOM non tradable: ",
            symbol, " | ", verdictReason, " | ", comment);
      return false;
   }
   if(!g_smcAlignExecBypass && !SMC_FinalOpenGate(symbol, ORDER_TYPE_BUY))
   {
      Print("[SAFE-TRADE] BUY bloqué par le gate final: ", symbol, " | ", comment);
      return false;
   }

   bool spikeHTFOverride = SMC_SpikeBlink_HTFOverrideInFlight(symbol, 1);
   string spikeReason = "";
   if(!SMC_SpikeBlink_OrderAllowed(symbol, 1, true, spikeReason))
   {
      Print("[SAFE-TRADE] BUY bloqué — Spike Blink requis: ", symbol,
            " | ", spikeReason);
      return false;
   }
   if(!spikeHTFOverride && MathAbs(g_smcGomVerdictNum) < 2 &&
      MathAbs(g_smcGomVerdictNumServer) < 2 &&
      SMC_GOMCurrentVerdictIsWait(symbol))
   {
      Print("[SAFE-TRADE] BUY blocked — verdict GOM courant WAIT: ", symbol);
      return false;
   }
   if(!spikeHTFOverride && !g_dowPriceLeadInFlight &&
      SMC_ExecutableGomVn() == 0 && !SMCGP_SpikeFireAllowed(symbol, 1))
   {
      Print("[SAFE-TRADE] BUY blocked — GOM=WAIT (vn=0 srv=", g_smcGomVerdictNumServer, "): ", symbol);
      return false;
   }
   if(!spikeHTFOverride && !g_dowPriceLeadInFlight && UseGOMVerdictFilter &&
      MathAbs(SMC_ExecutableGomVn()) < MinGOMVerdictNumAbs &&
      !SMCGP_M1ScalpSimpleAllowsDirection(symbol, 1) &&
      !SMCGP_SpikeFireAllowed(symbol, 1))
   {
      Print("[SAFE-TRADE] BUY blocked — GOM pas GOOD/PERFECT (vn=", g_smcGomVerdictNum,
            " srv=", g_smcGomVerdictNumServer, "): ", symbol);
      return false;
   }
   if(!CanTradeOnSymbol(symbol, "BUY"))
   {
      Print("[SAFE-TRADE] BUY blocked — gate symbole/anti-hedge: ", symbol);
      return false;
   }
   // Pas de BUY si BUY déjà ouverte sur ce symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol && (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         Print("[SAFE-TRADE] BUY sur ", symbol, " bloqué — BUY déjà ouverte");
         return false;
      }
    }
   // Pas de BUY si SELL déjà ouverte sur ce même symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol && (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         Print("[SAFE-TRADE] BUY sur ", symbol, " bloqué — SELL déjà ouverte sur le même symbole");
         return false;
      }
   }
   // Bloquer BUY sur Crash/PainX si une SELL sur Boom/GainX existe déjà
   if(IsCrashLikeSymbol(symbol))
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(!PositionSelectByTicket(t)) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         string s = PositionGetString(POSITION_SYMBOL);
         ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(IsBoomLikeSymbol(s) && pt == POSITION_TYPE_SELL)
         {
            Print("[SAFE-TRADE] BUY sur Crash/PainX bloqué — SELL sur Boom/GainX déjà ouverte: ", s);
            return false;
         }
      }
   }
   int dirSign = 1;
   if(!spikeHTFOverride && !g_dowPriceLeadInFlight &&
      !g_secondSpikeInFlight && !CanPlaceMarketOrder(symbol, dirSign))
   {
      Print("[SAFE-TRADE] BUY blocked by GOM/CAN'T trade on symbol: ", symbol);
      return false;
   }
   if(CountPositionsForSymbol(symbol) > 0)
   {
      Print("[SAFE-TRADE] BUY bloqué — déjà une position sur ", symbol);
      return false;
   }
   double slUse = sl, tpUse = tp;
   if(!SMCGP_PrepareMarketStops(symbol, 1, price, sl, tp, lot, slUse, tpUse))
   {
      Print("[SAFE-TRADE] BUY bloqué — stops invalides ou incompatibles avec le cap $: ", symbol);
      return false;
   }
   CTrade t;
   t.SetExpertMagicNumber(InpMagicNumber);
   t.SetDeviationInPoints(50);
   bool sent = t.Buy(lot, symbol, price, slUse, tpUse, comment);
   if(!sent)
      Print("[SAFE-TRADE] BUY send failed | ", symbol, " | ", comment,
            " | retcode=", t.ResultRetcode(),
            " | description=", t.ResultRetcodeDescription(),
            " | broker_comment=", t.ResultComment(),
            " | last_error=", GetLastError());
   return sent;
}

bool SafeTradeSell(double lot, const string symbol, double price, double sl, double tp, const string comment = "")
{
   if(!SMC_EntryPermissionsOK(symbol, -1, comment))
      return false;
   string verdictReason = "";
   if(!SMCGP_EntryVerdictAllowsTrade(symbol, verdictReason))
   {
      Print("[SAFE-TRADE] SELL bloqué — verdict GOM non tradable: ",
            symbol, " | ", verdictReason, " | ", comment);
      return false;
   }
   if(!g_smcAlignExecBypass && !SMC_FinalOpenGate(symbol, ORDER_TYPE_SELL))
   {
      Print("[SAFE-TRADE] SELL bloqué par le gate final: ", symbol, " | ", comment);
      return false;
   }

   bool spikeHTFOverride = SMC_SpikeBlink_HTFOverrideInFlight(symbol, -1);
   string spikeReason = "";
   if(!SMC_SpikeBlink_OrderAllowed(symbol, -1, true, spikeReason))
   {
      Print("[SAFE-TRADE] SELL bloqué — Spike Blink requis: ", symbol,
            " | ", spikeReason);
      return false;
   }
   if(!spikeHTFOverride && MathAbs(g_smcGomVerdictNum) < 2 &&
      MathAbs(g_smcGomVerdictNumServer) < 2 &&
      SMC_GOMCurrentVerdictIsWait(symbol))
   {
      Print("[SAFE-TRADE] SELL blocked — verdict GOM courant WAIT: ", symbol);
      return false;
   }
   if(!spikeHTFOverride && !g_dowPriceLeadInFlight &&
      SMC_ExecutableGomVn() == 0 && !SMCGP_SpikeFireAllowed(symbol, -1))
   {
      Print("[SAFE-TRADE] SELL blocked — GOM=WAIT (vn=0 srv=", g_smcGomVerdictNumServer, "): ", symbol);
      return false;
   }
   if(!spikeHTFOverride && !g_dowPriceLeadInFlight && UseGOMVerdictFilter &&
      MathAbs(SMC_ExecutableGomVn()) < MinGOMVerdictNumAbs &&
      !SMCGP_M1ScalpSimpleAllowsDirection(symbol, -1) &&
      !SMCGP_SpikeFireAllowed(symbol, -1))
   {
      Print("[SAFE-TRADE] SELL blocked — GOM pas GOOD/PERFECT (vn=", g_smcGomVerdictNum,
            " srv=", g_smcGomVerdictNumServer, "): ", symbol);
      return false;
   }
   if(!CanTradeOnSymbol(symbol, "SELL"))
   {
      Print("[SAFE-TRADE] SELL blocked — gate symbole/anti-hedge: ", symbol);
      return false;
   }
   // Pas de SELL si SELL déjà ouverte sur ce symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol && (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         Print("[SAFE-TRADE] SELL sur ", symbol, " bloqué — SELL déjà ouverte");
         return false;
      }
    }
   // Pas de SELL si BUY déjà ouverte sur ce même symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol && (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         Print("[SAFE-TRADE] SELL sur ", symbol, " bloqué — BUY déjà ouverte sur le même symbole");
         return false;
      }
   }
   // Bloquer SELL sur Boom/GainX si une BUY sur Crash/PainX existe déjà
   if(IsBoomLikeSymbol(symbol))
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(!PositionSelectByTicket(t)) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         string s = PositionGetString(POSITION_SYMBOL);
         ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(IsCrashLikeSymbol(s) && pt == POSITION_TYPE_BUY)
         {
            Print("[SAFE-TRADE] SELL sur Boom/GainX bloqué — BUY sur Crash/PainX déjà ouverte: ", s);
            return false;
         }
      }
   }
   int dirSign = -1;
   if(!spikeHTFOverride && !g_dowPriceLeadInFlight &&
      !g_secondSpikeInFlight && !CanPlaceMarketOrder(symbol, dirSign))
   {
      Print("[SAFE-TRADE] SELL blocked by GOM/CAN'T trade on symbol: ", symbol);
      return false;
   }
   if(CountPositionsForSymbol(symbol) > 0)
   {
      Print("[SAFE-TRADE] SELL bloqué — déjà une position sur ", symbol);
      return false;
   }
   double slUse = sl, tpUse = tp;
   if(!SMCGP_PrepareMarketStops(symbol, -1, price, sl, tp, lot, slUse, tpUse))
   {
      Print("[SAFE-TRADE] SELL bloqué — stops invalides ou incompatibles avec le cap $: ", symbol);
      return false;
   }
   CTrade t;
   t.SetExpertMagicNumber(InpMagicNumber);
   t.SetDeviationInPoints(50);
   bool sent = t.Sell(lot, symbol, price, slUse, tpUse, comment);
   if(!sent)
      Print("[SAFE-TRADE] SELL send failed | ", symbol, " | ", comment,
            " | retcode=", t.ResultRetcode(),
            " | description=", t.ResultRetcodeDescription(),
            " | broker_comment=", t.ResultComment(),
            " | last_error=", GetLastError());
   return sent;
}

//--- OTE stubs
// OTE_* : voir SMC_OTE_Zone.mqh (vraie implémentation, plus de stub ici)

//--- Pipeline discipline stub
bool DisciplineAllowsPipelineAction(const string action) { return true; }
int SMC_ComputePropiceScore()
{
   int score = 0;
   int absVn = MathAbs(g_smcGomVerdictNum);
   if(absVn >= 3)      score += 30;
   else if(absVn == 2) score += 20;
   else if(absVn == 1) score += 8;

   double coh = g_smcGomCoherence;
   if(coh >= 95.0)      score += 20;
   else if(coh >= 60.0) score += 13;
   else if(coh >= 30.0) score += 6;

   if(!(g_lastLossSymbol == _Symbol && g_lastLossTime > 0
        && (TimeCurrent() - g_lastLossTime) < 1800))
      score += 15;

   if(g_smcGomBarsSinceSpike >= 1 && g_smcGomBarsSinceSpike <= 3)
      score += 10;
   else if(g_smcGomBarsSinceSpike > 3 && g_smcGomBarsSinceSpike <= 8)
      score += 5;
   else if(g_smcGomSpikeLevel >= 2)
      score += 8;

   MqlDateTime utc;
   TimeGMT(utc);
   int h = utc.hour;
   if((h >= 7 && h < 13) || (h >= 13 && h < 17))
      score += 15;
   else if(h >= 4 && h < 20)
      score += 7;

   if(g_smcGomGlobalStr >= 60)      score += 10;
   else if(g_smcGomGlobalStr >= 35) score += 5;

   if(g_smcForecast5mReady && g_smcForecastHorizonMinutes == 5 &&
      g_smcGomVerdictForecastNum != 0 &&
      ((g_smcGomVerdictForecastNum > 0) == (g_smcGomVerdictNum > 0)))
      score += 10;

   return MathMin(score, 100);
}

// --- Symboles requis par SMC_PatternSignals.mqh ---

#endif
