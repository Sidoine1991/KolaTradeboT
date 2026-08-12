//+------------------------------------------------------------------+
//| SMC_GOMAlign.mqh — Triple alignement GOM + IA + Cognition 5min   |
//| MARKET / LIMIT aux niveaux S/R quand GOOD/PERFECT + pred 5min    |
//+------------------------------------------------------------------+
#ifndef SMC_GOM_ALIGN_MQH
#define SMC_GOM_ALIGN_MQH

#include "TMState.mqh"
#include "SMC_SignalGates.mqh"

datetime g_gomAlignLastNotify   = 0;
int      g_gomAlignLastNotifyVn = 999;
string   g_gomAlignLimitDir     = "";

// Déclarations externes (SMC_Universal.mq5 + SMC_GOM_Pipeline.mqh)
// input bool GOMAlignPushNotify, GOMAlignLimitAuto, GOMAlignPreferLimit, etc.

// Forward declaration
bool ConvertPendingToMarketOrder(const string symbol, const string direction,
                                 const string tag, const double limitPrice,
                                 const string levelSource);

bool GOMAlign_IsPendingType(const ENUM_ORDER_TYPE t)
{
   return (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT
        || t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP
        || t == ORDER_TYPE_BUY_STOP_LIMIT || t == ORDER_TYPE_SELL_STOP_LIMIT);
}

int GOMAlign_CountOpenLimitsTerminal()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT) count++;
   }
   return count;
}

int CountGOMPendingByTag(const string symbol, const string tagPrefix)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(!GOMAlign_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE))) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, tagPrefix) >= 0) count++;
   }
   return count;
}

void CancelGOMPendingByTag(const string symbol, const string tagPrefix)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, tagPrefix) < 0) continue;
      if((int)OrderGetInteger(ORDER_STATE) != ORDER_STATE_PLACED) continue;
      LimitSafeOrderDelete(ticket, false, "GOM-ALIGN annulation " + tagPrefix);
   }
}

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

bool COG_ConflictsWithGOM()
{
   if(g_smcGomVerdictNum >= 2 && g_cogDirection == "SELL") return true;
   if(g_smcGomVerdictNum <= -2 && g_cogDirection == "BUY") return true;
   string eff = SMCGP_EffectiveCogDirection();
   if(g_smcGomVerdictNum >= 2 && eff == "SELL") return true;
   if(g_smcGomVerdictNum <= -2 && eff == "BUY") return true;
   return false;
}

bool SMC_IAAndCOGAligned(const int dirSign)
{
   if(dirSign == 0) return false;
   string want = (dirSign == 1) ? "BUY" : "SELL";
   string ia = g_smcIAStatusAction;
   StringToUpper(ia);
   if(ia != want) return false;
   string cog = SMCGP_EffectiveCogDirection();
   return (cog == want);
}

bool GOM_EntryAlignmentOK(const int dirSign)
{
   string reason = "";
   return SMC_AlignExecStrictGateOK(dirSign, reason);
}

bool SMC_TfDirMatchesSign(const int dirSign, const string tfDir)
{
   if(dirSign == 0 || StringLen(tfDir) == 0) return false;
   string d = tfDir;
   StringToUpper(d);
   if(dirSign == 1)  return (d == "BULL" || d == "BUY");
   if(dirSign == -1) return (d == "BEAR" || d == "SELL");
   return false;
}

bool SMC_M5H1PreciseAligned(const int dirSign)
{
   return SMC_TfDirMatchesSign(dirSign, g_smcTfM5Dir) && SMC_TfDirMatchesSign(dirSign, g_smcTfH1Dir);
}

bool SMC_PricePullbackM5EMA(const int dirSign, double &emaPrice, const double tolAtrMult = 0.40)
{
   emaPrice = 0;
   if(dirSign == 0) return false;
   double emaBuf[];
   ArraySetAsSeries(emaBuf, true);
   if(emaFastM5 != INVALID_HANDLE && CopyBuffer(emaFastM5, 0, 0, 1, emaBuf) >= 1)
      emaPrice = emaBuf[0];
   else if(emaSlowM5 != INVALID_HANDLE && CopyBuffer(emaSlowM5, 0, 0, 1, emaBuf) >= 1)
      emaPrice = emaBuf[0];
   if(emaPrice <= 0) return false;

   double atrVal = GOM_GetATRValue();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;
   double px = (dirSign == 1) ? bid : ask;
   double tol = MathMax(atrVal * tolAtrMult, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
   return (MathAbs(px - emaPrice) <= tol);
}

// GOM GOOD/PERFECT + IA Status + Cognition 5min + prédiction 5min alignée
bool SMC_AlignExecStrictGateOK(const int dirSign, string &reasonOut)
{
   reasonOut = "";
   if(dirSign == 0) { reasonOut = "dirSign=0"; return false; }

   if(!g_smcGomConnected)
   { reasonOut = "GOM non connecté"; return false; }
if(g_smcLastGOMPoll > 0 && (int)(TimeCurrent() - g_smcLastGOMPoll) > 15)
    { reasonOut = StringFormat("GOM stale (%ds)", (int)(TimeCurrent() - g_smcLastGOMPoll)); return false; }

   if(g_smcGomVerdictNum == 0 || StringFind(g_smcGomVerdict, "WAIT") >= 0)
   {
      reasonOut = StringFormat("GOM=WAIT (vn=%d)", g_smcGomVerdictNum);
      return false;
   }
   if(!SMCGP_IsGoodPerfect(g_smcGomVerdictNum))
   {
      reasonOut = StringFormat("GOM hors GOOD/PERFECT (vn=%d)", g_smcGomVerdictNum);
      return false;
   }
   if(dirSign == 1 && g_smcGomVerdictNum <= 0)
   { reasonOut = "GOM BUY requis"; return false; }
   if(dirSign == -1 && g_smcGomVerdictNum >= 0)
   { reasonOut = "GOM SELL requis"; return false; }

   string wantDir = (dirSign == 1) ? "BUY" : "SELL";

   // Cognition 5min explicite
   if(StringLen(g_cogDirection5m) == 0 || g_cogDirection5m == "NEUTRAL")
   {
      reasonOut = StringFormat("COG 5m=%s (attendu %s)", g_cogDirection5m, wantDir);
      return false;
   }
   if(g_cogDirection5m != wantDir)
   {
      reasonOut = StringFormat("COG 5m=%s (attendu %s)", g_cogDirection5m, wantDir);
      return false;
   }

   string effCog = SMCGP_EffectiveCogDirection();
   if(effCog != wantDir)
   {
      reasonOut = StringFormat("COG eff=%s (attendu %s)", effCog, wantDir);
      return false;
   }
   if(COG_ConflictsWithGOM())
   {
      reasonOut = "COG en conflit avec GOM";
      return false;
   }

   // Prédiction 5min — chemin pred_path_mid aligné
   double concord = SMCGP_EstimateConcordanceLocal();
   if(ArraySize(g_smcPredPathMid) >= 10 && concord < GOMAlignMinPredConcordPct)
   {
      reasonOut = StringFormat("Pred 5m concordance %.0f%% < min %.0f%%", concord, GOMAlignMinPredConcordPct);
      return false;
   }

   // IA Status dashboard
   string iaDir = g_smcIAStatusAction;
   StringToUpper(iaDir);
   if(StringLen(iaDir) == 0 || iaDir == "HOLD")
   {
      reasonOut = StringFormat("IA Status=%s (attendu %s)", g_smcIAStatusAction, wantDir);
      return false;
   }
   if(iaDir != wantDir)
   {
      reasonOut = StringFormat("IA Status=%s (attendu %s)", g_smcIAStatusAction, wantDir);
      return false;
   }

   if(g_iaStatusConfidence > 0)
   {
      double iaConf = (g_iaStatusConfidence > 1.0) ? g_iaStatusConfidence / 100.0 : g_iaStatusConfidence;
      double minConf = SMC_EffectiveMinAIConfidence() / 100.0;
      if(iaConf < minConf)
      {
         reasonOut = StringFormat("IA conf %.0f%% < min %.0f%%", g_iaStatusConfidence, SMC_EffectiveMinAIConfidence());
         return false;
      }
   }

   return true;
}

bool GOM_CanOpenAlignedTrade(const int dirSign)
{
   if(BlockAllTrades) return false;
   if(dirSign == 0) return false;
   if(MathAbs(g_smcGomVerdictNum) < 2)
   {
      static datetime s_logAlign = 0;
      if(TimeCurrent() - s_logAlign >= 30)
      {
         s_logAlign = TimeCurrent();
         Print("[GOM-OPEN] BLOQUE aligned-trade — GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum,
               ") — seul GOOD/PERFECT (|vn|>=2) autorisé");
      }
      return false;
   }
   string alignReason = "";
   if(!SMC_AlignExecStrictGateOK(dirSign, alignReason))
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[GOM-OPEN] BLOQUE aligned-trade — ", alignReason);
      }
      return false;
   }
   if(!IsDirectionAllowedForBoomCrash(_Symbol, (dirSign == 1) ? "BUY" : "SELL")) return false;
   if(!SMC_DailyDisciplineAllowsEntry()) return false;
   if(UseSessionReadiness && g_readinessCBActive) return false;
    if(CountPositionsForSymbol(_Symbol) > 0) return false;
    if(IsTerminalFull()) return false;
    if(GOMAlign_CountOpenLimitsTerminal() >= MaxLimitOrdersTerminal) return false;
   return true;
}

bool GOM_CanOpenNewTrade(const int dirSign = 0)
{
   if(g_smcAlignExecBypass)
      return GOM_CanOpenAlignedTrade(dirSign);
   if(BlockAllTrades) return false;
   if(MathAbs(g_smcGomVerdictNum) < 2)
   {
      static datetime s_logNewTrade = 0;
      if(TimeCurrent() - s_logNewTrade >= 30)
      {
         s_logNewTrade = TimeCurrent();
         Print("[GOM-NEWTRADE] BLOQUE — GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum,
               ") — seul GOOD/PERFECT (|vn|>=2) autorisé");
      }
      return false;
   }
   if(!SMC_DailyDisciplineAllowsEntry()) return false;
   if(g_smcGomConnected && g_smcLastGOMPoll > 0 && (int)(TimeCurrent() - g_smcLastGOMPoll) > 90)
      return false;
   if(dirSign != 0 && GOMPerfectAutoEntry && !GOM_EntryAlignmentOK(dirSign)) return false;
   if(CountPositionsForSymbol(_Symbol) > 0) return false;
   if(GOMAlign_CountOpenLimitsTerminal() >= MaxLimitOrdersTerminal) return false;
   return true;
}

bool PlaceGOMMarketOrder(const string direction, const string tag, const string levelSource)
{
   int dir = (direction == "BUY") ? 1 : -1;
   //--- Blink gate: signal doit clignoter ~1.5s avant MARKET
   if(!IsSignalConfirmed())
   {
      static datetime s_lastBlinkLog = 0;
      if(TimeCurrent() - s_lastBlinkLog >= 30)
      {
         s_lastBlinkLog = TimeCurrent();
         Print("[GOM] MARKET BLOQUE — signal pas encore confirmé (blink) | ", _Symbol);
      }
      return false;
   }
   if(StringFind(tag, "GOM_ALIGN") >= 0 || StringFind(tag, "GOM_PERFECT") >= 0)
   {
      string alignReason = "";
      if(!SMC_AlignExecStrictGateOK(dir, alignReason))
      {
         Print("[GOM-ALIGN-GATE] BLOQUE MARKET — ", alignReason, " | ", _Symbol, " @ ", levelSource);
         return false;
      }
   }
   if(!GOM_CanOpenNewTrade(dir)) return false;
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction)) return false;
   if(!CanTradeOnSymbol(_Symbol, direction)) return false;
   if(!TryAcquireOpenLock()) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) { ReleaseOpenLock(); return false; }

   double atrVal = GOM_GetATRValue();
   double slDist = atrVal * GOMAlignSL_ATRMult;
   double tpDist = atrVal * GOMAlignTP_ATRMult;
   double sl = 0, tp = 0;
   if(direction == "BUY")
   {
      sl = bid - slDist;
      tp = bid + tpDist;
   }
   else
   {
      sl = ask + slDist;
      tp = ask - tpDist;
   }

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.magic     = InpMagicNumber;
   req.volume    = CalculateLotSize();
   req.type      = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = (direction == "BUY") ? ask : bid;
   req.sl        = NormalizeDouble(sl, _Digits);
   req.tp        = NormalizeDouble(tp, _Digits);
   req.comment   = tag + " " + direction + " " + levelSource;
   req.deviation = 20;
   long fillFlags = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   req.type_filling = ((fillFlags & SYMBOL_FILLING_IOC) != 0) ? ORDER_FILLING_IOC :
                      ((fillFlags & SYMBOL_FILLING_FOK) != 0) ? ORDER_FILLING_FOK :
                      ORDER_FILLING_RETURN;

   bool ok = SafeOrderSend(req, res);
   ReleaseOpenLock();
   if(ok)
   {
      Print("[GOM-MARKET] ", tag, " ", direction, " @ ", levelSource,
            " | GOM=", g_smcGomVerdict, " COG5m=", g_cogDirection5m,
            " IA=", g_smcIAStatusAction);
      if(StringFind(tag, "GOM_PERFECT") >= 0)
      {
         g_lastPerfectEntryTime = TimeCurrent();
         g_lastPerfectEntrySymbol = _Symbol;
      }
   }
   return ok;
}

bool PlaceGOMLimitAtLevel(const string direction, const string tag, const double limitPrice, const string levelSource)
{
   if(limitPrice <= 0) return false;
   //--- Blink gate: signal doit clignoter ~1.5s avant LIMIT
   if(!IsSignalConfirmed())
   {
      static datetime s_lastBlinkLog2 = 0;
      if(TimeCurrent() - s_lastBlinkLog2 >= 30)
      {
         s_lastBlinkLog2 = TimeCurrent();
         Print("[GOM] LIMIT BLOQUE — signal pas encore confirmé (blink) | ", _Symbol);
      }
      return false;
   }
   int dir = (direction == "BUY") ? 1 : -1;
   if(StringFind(tag, "GOM_ALIGN") >= 0)
   {
      string alignReason = "";
      if(!SMC_AlignExecStrictGateOK(dir, alignReason))
      {
         Print("[GOM-ALIGN-GATE] BLOQUE LIMIT — ", alignReason);
         return false;
      }
   }
   if(!GOM_CanOpenNewTrade(dir)) return false;
   if(CountGOMPendingByTag(_Symbol, tag) > 0) return false;
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction)) return false;
   if(!TryAcquireOpenLock()) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) { ReleaseOpenLock(); return false; }

   // Auto-convert pending orders to market orders for GOM GOOD/PERFECT
   string upperTag = tag;
   StringToUpper(upperTag);
   bool isAutoConvert = (g_state.config.gomAutoConvertPending &&
                         (StringFind(upperTag, "GOM_PERFECT") >= 0 ||
                          StringFind(upperTag, "GOM_GOOD") >= 0 ||
                           StringFind(upperTag, "GOM_ALIGN") >= 0));

   if(isAutoConvert)
   {
      // Release lock before converting to avoid deadlock
      ReleaseOpenLock();
      return ConvertPendingToMarketOrder(_Symbol, direction, tag, limitPrice, levelSource);
   }

   double atrVal = GOM_GetATRValue();
   double refPrice = (direction == "BUY") ? bid : ask;
   double maxDist = atrVal * GOMAlignLimitMaxDistATR;
   if(MathAbs(limitPrice - refPrice) > maxDist)
   {
      ReleaseOpenLock();
      return false;
   }

   double slDist = atrVal * SR20BarSL_ATRMult;
   double tpDist = atrVal * SR20BarTP_ATRMult;
   double sl = 0, tp = 0;
   if(direction == "BUY")
   {
      sl = limitPrice - slDist;
      tp = limitPrice + tpDist;
   }
   else
   {
      sl = limitPrice + slDist;
      tp = limitPrice - tpDist;
   }

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action  = TRADE_ACTION_PENDING;
   req.symbol  = _Symbol;
   req.magic   = InpMagicNumber;
   req.volume  = CalculateLotSize();
   req.type    = (direction == "BUY") ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.price   = NormalizeDouble(limitPrice, _Digits);
   req.sl      = NormalizeDouble(sl, _Digits);
   req.tp      = NormalizeDouble(tp, _Digits);
   req.comment = tag + " " + direction + " " + levelSource;

   ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)req.type;
   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ot))
   {
      ReleaseOpenLock();
      return false;
   }

   bool ok = SafeOrderSend(req, res);
   ReleaseOpenLock();
   if(ok)
      Print("[GOM-LIMIT] ", tag, " ", direction, " @ ", levelSource, " prix=", DoubleToString(limitPrice, _Digits));
   return ok;
}

void SMC_PushAlignMT5Notify(const string msg)
{
   Print("[GOM-ALIGN-NOTIF] ", msg);
   if(!UseNotifications || !GOMAlignPushNotify) return;
   Alert(msg);
   SendNotification(msg);
}

bool SMC_ExecuteAlignMarketIfOK(const int dirSign, const string direction, const string levelSource)
{
   string blockReason = "";
   if(!SMC_AlignExecStrictGateOK(dirSign, blockReason))
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[GOM-ALIGN] MARKET BLOQUE @ ", levelSource, " — ", blockReason);
      }
      return false;
   }
   if(!PlaceGOMMarketOrder(direction, "GOM_ALIGN", levelSource))
      return false;

   Print("[GOM-ALIGN] MARKET ", direction, " @ ", levelSource,
         " | GOM=", g_smcGomVerdict, " COG5m=", g_cogDirection5m,
         " IA=", g_smcIAStatusAction);
   SMC_PushAlignMT5Notify(StringFormat("[ALIGN-EXEC] %s %s MARKET @ %s | GOM %s COG5m %s IA %s",
                        _Symbol, direction, levelSource,
                        g_smcGomVerdict, g_cogDirection5m, g_smcIAStatusAction));
   return true;
}

// Triple alignement → MARKET spike ou LIMIT S/R 20 bars
void ManageGOMAlignedLimitOrders()
{
   // Mode DOW-only : pas de LIMIT GOM-ALIGN (seulement trendline DOW)
   if(Dow_IsDowOnlyLimitMode()) return;

   const string TAG = "GOM_ALIGN_LIM";

   if(!g_smcGomConnected || BlockAllTrades) return;

     if(g_smcGomVerdictNum == 0 || !SMCGP_IsGoodPerfect(g_smcGomVerdictNum))
     {
        // GOM=WAIT (vn=0) OU verdict faible : ANNULER les LIMIT déjà placés.
        // On ne doit PAS laisser un ordre LIMIT s'exécuter sous WAIT.
        if(CountGOMPendingByTag(_Symbol, TAG) > 0)
        {
           Print("[GOM-ALIGN] Verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum,
                 ") — ANNULATION LIMIT en attente");
           CancelGOMPendingByTag(_Symbol, TAG);
        }
        g_gomAlignLimitDir = "";
        return;
     }

   int dirSign = 0;
   if(g_smcGomVerdictNum >= 2)       dirSign = 1;
   else if(g_smcGomVerdictNum <= -2) dirSign = -1;
   else return;

   string alignBlockReason = "";
   bool aligned = SMC_AlignExecStrictGateOK(dirSign, alignBlockReason);

   if(!aligned)
   {
      if(CountGOMPendingByTag(_Symbol, TAG) > 0)
      {
         Print("[GOM-ALIGN] Alignement rompu — annulation LIMIT | ", alignBlockReason);
         CancelGOMPendingByTag(_Symbol, TAG);
      }
      g_gomAlignLimitDir = "";
      return;
   }

   string direction = (dirSign == 1) ? "BUY" : "SELL";
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction))
   {
      CancelGOMPendingByTag(_Symbol, TAG);
      return;
   }

   if(TimeCurrent() - g_gomAlignLastNotify > 180 || g_gomAlignLastNotifyVn != g_smcGomVerdictNum)
   {
      g_gomAlignLastNotify   = TimeCurrent();
      g_gomAlignLastNotifyVn = g_smcGomVerdictNum;
      string msg = StringFormat("[ALIGN] %s %s | GOM %s | IA %s %.0f%% | COG5m %s | Pred OK",
                              _Symbol, direction, g_smcGomVerdict,
                              g_smcIAStatusAction, g_iaStatusConfidence, g_cogDirection5m);
      SMC_PushAlignMT5Notify(msg);
   }

    if(CountPositionsForSymbol(_Symbol) > 0) return;
    if(IsTerminalFull()) return;

   g_smcAlignExecBypass = true;

   // Boom/Crash : spike massif attendu → MARKET immédiat si triple align
   if(GOMAlignSpikeImmediateMarket && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
   {
      if(SMC_ExecuteAlignMarketIfOK(dirSign, direction, "TRIPLE_ALIGN_SPIKE"))
      {
         g_smcAlignExecBypass = false;
         return;
      }
   }

   if(!GOMAlignLimitAuto)
   {
      g_smcAlignExecBypass = false;
      return;
   }

   if(g_gomAlignLimitDir != "" && g_gomAlignLimitDir != direction)
      CancelGOMPendingByTag(_Symbol, TAG);
   g_gomAlignLimitDir = direction;

   if(CountGOMPendingByTag(_Symbol, TAG) > 0)
   {
      g_smcAlignExecBypass = false;
      return;
   }

   static datetime s_lastLimitTry = 0;
   if(TimeCurrent() - s_lastLimitTry < 15)
   {
      g_smcAlignExecBypass = false;
      return;
   }

   double atrVal = GOM_GetATRValue();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) { g_smcAlignExecBypass = false; return; }

   s_lastLimitTry = TimeCurrent();

   if(GOMAlignM5EMAMarket && SMC_M5H1PreciseAligned(dirSign))
   {
      double emaM5 = 0;
      if(SMC_PricePullbackM5EMA(dirSign, emaM5, GOMAlignM5EMATolATR))
      {
         if(SMC_ExecuteAlignMarketIfOK(dirSign, direction, "M5_EMA_PB"))
         {
            g_smcAlignExecBypass = false;
            return;
         }
      }
   }

   if(SMC_IsWeltradeBoomCrash(_Symbol))
   {
      SMC_ExecuteAlignMarketIfOK(dirSign, direction, "weltrade_mkt");
      g_smcAlignExecBypass = false;
      return;
   }

   string levelSource = "";
   double entryLvl = 0;
   double refPx = (dirSign == 1) ? bid : ask;
   if(dirSign == 1)
      entryLvl = GetClosestBuyLevel(bid, atrVal, GOMAlignLimitMaxDistATR, levelSource);
   else
      entryLvl = GetClosestSellLevel(ask, atrVal, GOMAlignLimitMaxDistATR, levelSource);

   if(entryLvl <= 0)
   {
      g_smcAlignExecBypass = false;
      return;
   }

   if(dirSign == 1 && entryLvl >= ask)
      entryLvl = bid - MathMax(atrVal * 0.15, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);
   if(dirSign == -1 && entryLvl <= bid)
      entryLvl = ask + MathMax(atrVal * 0.15, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);

   double nearTol = MathMax(atrVal * 0.35, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
   bool priceAtLevel = (MathAbs(refPx - entryLvl) <= nearTol);
   bool executed = false;

   if(priceAtLevel)
      executed = SMC_ExecuteAlignMarketIfOK(dirSign, direction, levelSource);
   else if(GOMAlignPreferLimit)
      executed = PlaceGOMLimitAtLevel(direction, TAG, entryLvl, levelSource);
   else
      executed = SMC_ExecuteAlignMarketIfOK(dirSign, direction, levelSource);

   if(!executed && GOMAlignMarketFallback)
      executed = SMC_ExecuteAlignMarketIfOK(dirSign, direction, levelSource + "_fb");

   g_smcAlignExecBypass = false;
}

//+------------------------------------------------------------------+
//| ConvertPendingToMarketOrder: annule LIMIT en attente → MARKET    |
//+------------------------------------------------------------------+
bool ConvertPendingToMarketOrder(const string symbol, const string direction,
                                 const string tag, const double limitPrice,
                                 const string levelSource)
{
   if(!IsDirectionAllowedForBoomCrash(symbol, direction)) return false;
   if(!CanTradeOnSymbol(symbol, direction)) return false;

   // Vérifier âge min runtime si configuré
   if(g_state.config.gomAutoConvertMinRuntimeSec > 0)
   {
      datetime now = TimeCurrent();
      bool ageOk = false;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
         ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
         string cmt = OrderGetString(ORDER_COMMENT);
         if(StringFind(cmt, tag) < 0) continue;
         datetime otime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         if((int)(now - otime) >= g_state.config.gomAutoConvertMinRuntimeSec)
            ageOk = true;
         break;
      }
      if(!ageOk)
      {
         Print("[GOM-AUTOCONV] SKIP — âge min ", g_state.config.gomAutoConvertMinRuntimeSec, "s pas atteint | ", symbol, " ", tag);
         return false;
      }
   }

   // Vérifier quality min (g_smcGomQuality disponible via SMC_GOM_Pipeline.mqh, check fait au call site)
   // Note: la vérification quality est optionnelle — si nécessaire, caller vérifie avant l'appel

   // Annuler les pending orders correspondantes
   int cancelled = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, tag) < 0) continue;

      if(LimitSafeOrderDelete(ticket, false, "GOM-AUTOCONV " + tag + " " + direction))
         cancelled++;
   }

   if(cancelled > 0)
      Print("[GOM-AUTOCONV] ", cancelled, " LIMIT(s) annulé(s) → conversion MARKET | ", symbol, " ", tag);

   // Exécuter MARKET
   return PlaceGOMMarketOrder(direction, tag + "_AUTOCONV", levelSource);
}

#endif



