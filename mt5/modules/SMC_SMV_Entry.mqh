//+------------------------------------------------------------------+
//| SMC_SMV_Entry.mqh — Scalp unique sur niveaux chart KOLA / OB     |
//| Prefixe SMVE_ pour ne pas conflictuer avec SMC_SmartMoneyVolume  |
//|                                                                  |
//| Sources (priorite):                                              |
//|  1) g_smcSetup* (OB_BULL / OB_BEAR — Entry/SL/TP)                |
//|  2) g_smcGomKolaBuy / KolaSell + objets TM_/GOM_KOLA_*           |
//|  3) OTE / DOW EP / FVG (fallback)                                |
//|                                                                  |
//| GOOD  (|vn|==2)  → LIMIT au niveau                               |
//| PERFECT (|vn|>=3)→ MARKET si proche, sinon LIMIT                 |
//+------------------------------------------------------------------+
#ifndef SMC_SMV_ENTRY_MQH
#define SMC_SMV_ENTRY_MQH

// Dependances resolues dans SMC_Universal.mq5 (inclus APRES InpMagicNumber / gates)

input group "=== SMVE SCALP (KOLA / OB_BULL / OB_BEAR) ==="
input bool   SMVE_Enable              = true;   // Scalp auto sur KOLA/OB + GOM GOOD/PERFECT
input bool   SMVE_PreferSetupOB       = true;   // Priorite setup OB_BULL / OB_BEAR
input bool   SMVE_PreferKOLA          = true;   // Puis KOLA BUY/SELL
input bool   SMVE_RequireLevelInDir   = true;   // Niveau du bon cote (pullback)
input double SMVE_NearATR             = 0.55;   // Proche = MARKET si PERFECT
input double SMVE_LimitBufferATR      = 0.06;   // Buffer LIMIT au-dessus/sous le niveau
input double SMVE_MaxChaseATR         = 1.20;   // Distance max prix↔niveau (LIMIT utile)
input double SMVE_MinRR               = 1.20;   // RR mini (sinon TP recalcule)
input double SMVE_SL_ATR_Fallback     = 1.00;   // SL si absent du chart
input double SMVE_TP1_R_Fallback      = 1.50;   // TP1 en R si absent
input double SMVE_MaxLossUSD          = 3.00;   // Cap risque $
input int    SMVE_CooldownSec         = 45;     // Anti-spam entre 2 essais
input int    SMVE_LogSec              = 12;     // Throttle logs

bool     g_smveInFlight   = false;
bool     g_smveGateBypass = false; // saute M1/M5 align gate pour LIMIT KOLA/OB
datetime g_smveLastTry  = 0;
datetime g_smveLastOk   = 0;
datetime g_smveLastLog  = 0;
string   g_smveLastWhy  = "";

struct SMVELevelPack
{
   double entry;
   double sl;
   double tp1;
   double tp2;
   string source;
   int    dir;
   double rr;
   bool   valid;
};

void SMVE_Log(const string msg)
{
   if(TimeCurrent() - g_smveLastLog < SMVE_LogSec) return;
   g_smveLastLog = TimeCurrent();
   g_smveLastWhy = msg;
   Print("[SMVE] ", msg);
}

double SMVE_ATR(const string sym, const ENUM_TIMEFRAMES tf = PERIOD_M5, const int period = 14)
{
   double a[];
   int h = iATR(sym, tf, period);
   if(h == INVALID_HANDLE) return SymbolInfoDouble(sym, SYMBOL_POINT) * 50.0;
   double atr = SymbolInfoDouble(sym, SYMBOL_POINT) * 50.0;
   if(CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0) atr = a[0];
   IndicatorRelease(h);
   return atr;
}

double SMVE_LotForRisk(const string sym, const double entry, const double sl, const double maxLossUSD)
{
   double tickVal = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double volMin  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double volMax  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double volStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if(tickVal <= 0.0 || tickSz <= 0.0 || volStep <= 0.0) return volMin;
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) return volMin;
   double lossPerLot = (dist / tickSz) * tickVal;
   if(lossPerLot <= 0.0) return volMin;
   double lot = maxLossUSD / lossPerLot;
   lot = MathFloor(lot / volStep) * volStep;
   if(lot < volMin) lot = volMin;
   if(lot > volMax) lot = volMax;
   return NormalizeDouble(lot, 2);
}

bool SMVE_ReadObjPrice(const string name, double &price)
{
   price = 0.0;
   if(ObjectFind(0, name) < 0) return false;
   if(StringFind(name, "TL") >= 0 || StringFind(name, "LINE") >= 0)
   {
      double lv = ObjectGetValueByTime(0, name, TimeCurrent(), 0);
      if(lv > 0.0) { price = lv; return true; }
   }
   double p0 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
   if(p0 > 0.0) { price = p0; return true; }
   if(p1 > 0.0) { price = p1; return true; }
   return false;
}

bool SMVE_ScanTokenPrice(const string token, double &price)
{
   price = 0.0;
   int tot = ObjectsTotal(0, -1, -1);
   string tokU = token; StringToUpper(tokU);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double best = 0.0, bestD = 1e100;
   for(int i = 0; i < tot; i++)
   {
      string on = ObjectName(0, i, -1, -1);
      string ou = on; StringToUpper(ou);
      if(StringFind(ou, tokU) < 0) continue;
      double p = 0.0;
      if(!SMVE_ReadObjPrice(on, p) || p <= 0.0) continue;
      double d = MathAbs(bid - p);
      if(d < bestD) { bestD = d; best = p; }
   }
   if(best > 0.0) { price = best; return true; }
   return false;
}

bool SMVE_ValidatePack(SMVELevelPack &pk, const int dirSign)
{
   if(pk.entry <= 0.0) return false;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double atr = SMVE_ATR(_Symbol);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px  = (dirSign > 0) ? ask : bid;

   if(pk.sl <= 0.0)
   {
      if(dirSign > 0) pk.sl = NormalizeDouble(pk.entry - atr * SMVE_SL_ATR_Fallback, dg);
      else            pk.sl = NormalizeDouble(pk.entry + atr * SMVE_SL_ATR_Fallback, dg);
   }
   if(dirSign > 0 && pk.sl >= pk.entry)
      pk.sl = NormalizeDouble(pk.entry - atr * SMVE_SL_ATR_Fallback, dg);
   if(dirSign < 0 && pk.sl <= pk.entry)
      pk.sl = NormalizeDouble(pk.entry + atr * SMVE_SL_ATR_Fallback, dg);

   double risk = MathAbs(pk.entry - pk.sl);
   if(risk <= 0.0) return false;

   if(pk.tp1 <= 0.0)
   {
      if(dirSign > 0) pk.tp1 = NormalizeDouble(pk.entry + risk * SMVE_TP1_R_Fallback, dg);
      else            pk.tp1 = NormalizeDouble(pk.entry - risk * SMVE_TP1_R_Fallback, dg);
   }
   if(dirSign > 0 && pk.tp1 <= pk.entry)
      pk.tp1 = NormalizeDouble(pk.entry + risk * SMVE_TP1_R_Fallback, dg);
   if(dirSign < 0 && pk.tp1 >= pk.entry)
      pk.tp1 = NormalizeDouble(pk.entry - risk * SMVE_TP1_R_Fallback, dg);

   pk.rr = MathAbs(pk.tp1 - pk.entry) / risk;
   if(pk.rr < SMVE_MinRR)
   {
      if(dirSign > 0) pk.tp1 = NormalizeDouble(pk.entry + risk * SMVE_MinRR, dg);
      else            pk.tp1 = NormalizeDouble(pk.entry - risk * SMVE_MinRR, dg);
      pk.rr = SMVE_MinRR;
   }

   if(pk.tp2 <= 0.0)
   {
      if(dirSign > 0) pk.tp2 = NormalizeDouble(pk.entry + risk * MathMax(2.0, SMVE_MinRR + 0.5), dg);
      else            pk.tp2 = NormalizeDouble(pk.entry - risk * MathMax(2.0, SMVE_MinRR + 0.5), dg);
   }

   if(atr > 0.0 && MathAbs(px - pk.entry) > atr * SMVE_MaxChaseATR)
      return false;

   // Soft: n'interdit plus le niveau "du mauvais cote" — LIMIT peut attendre le pullback
   // (anti-chase global via SMVE_MaxChaseATR suffit).

   pk.dir = dirSign;
   pk.valid = true;
   return true;
}

bool SMVE_BuildLevels(const int dirSign, SMVELevelPack &pk)
{
   ZeroMemory(pk);
   pk.valid = false;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // 1) Setup OB officiel (OB_BULL / OB_BEAR)
   if(SMVE_PreferSetupOB && g_smcSetupValid && g_smcSetupEntry > 0.0 &&
      (g_smcSetupDir == 0 || g_smcSetupDir == dirSign))
   {
      pk.entry  = g_smcSetupEntry;
      pk.sl     = g_smcSetupSL;
      pk.tp1    = g_smcSetupTP1;
      pk.tp2    = g_smcSetupTP2;
      pk.source = (StringLen(g_smcSetupType) > 0 ? g_smcSetupType : "OB_SETUP");
      if(SMVE_ValidatePack(pk, dirSign))
         return true;
   }

   {
      double e = 0, s = 0, t1 = 0, t2 = 0;
      if(SMVE_ReadObjPrice("TM_OB_ENTRY", e) && e > 0.0)
      {
         SMVE_ReadObjPrice("TM_OB_SL", s);
         SMVE_ReadObjPrice("TM_OB_TP1", t1);
         SMVE_ReadObjPrice("TM_OB_TP2", t2);
         pk.entry = e; pk.sl = s; pk.tp1 = t1; pk.tp2 = t2;
         pk.source = "TM_OB_ENTRY";
         if(SMVE_ValidatePack(pk, dirSign))
            return true;
      }
   }

   // 2) KOLA BUY / SELL
   if(SMVE_PreferKOLA)
   {
      double kola = 0.0;
      if(dirSign > 0)
      {
         if(g_smcGomKolaBuy > 0.0) kola = g_smcGomKolaBuy;
         if(kola <= 0.0) SMVE_ReadObjPrice("TM_KOLA_BUY", kola);
         if(kola <= 0.0) SMVE_ReadObjPrice("GOM_KOLA_BUY", kola);
         if(kola <= 0.0) SMVE_ScanTokenPrice("KOLA_BUY", kola);
      }
      else
      {
         if(g_smcGomKolaSell > 0.0) kola = g_smcGomKolaSell;
         if(kola <= 0.0) SMVE_ReadObjPrice("TM_KOLA_SELL", kola);
         if(kola <= 0.0) SMVE_ReadObjPrice("GOM_KOLA_SELL", kola);
         if(kola <= 0.0) SMVE_ScanTokenPrice("KOLA_SELL", kola);
      }
      if(kola > 0.0)
      {
         pk.entry = kola;
         pk.sl = 0; pk.tp1 = 0; pk.tp2 = 0;
         double s = 0, t1 = 0, t2 = 0;
         SMVE_ReadObjPrice("TM_OB_SL", s);
         SMVE_ReadObjPrice("TM_OB_TP1", t1);
         SMVE_ReadObjPrice("TM_OB_TP2", t2);
         // Si setup OB meme sens: recuperer SL/TP meme sans entry OB
         if(s <= 0.0 && g_smcSetupValid && g_smcSetupDir == dirSign)
         {
            s = g_smcSetupSL; t1 = g_smcSetupTP1; t2 = g_smcSetupTP2;
         }
         pk.sl = s; pk.tp1 = t1; pk.tp2 = t2;
         pk.source = (dirSign > 0 ? "KOLA_BUY" : "KOLA_SELL");
         if(SMVE_ValidatePack(pk, dirSign))
            return true;
      }
   }

   // 3) OTE
   {
      double oteHi = g_smcOteTop, oteLo = g_smcOteBot;
      if(oteHi <= 0.0 || oteLo <= 0.0)
      {
         if(ObjectFind(0, "SMC_OTE_ZONE") >= 0)
         {
            double p0 = ObjectGetDouble(0, "SMC_OTE_ZONE", OBJPROP_PRICE, 0);
            double p1 = ObjectGetDouble(0, "SMC_OTE_ZONE", OBJPROP_PRICE, 1);
            oteHi = MathMax(p0, p1);
            oteLo = MathMin(p0, p1);
         }
      }
      if(oteHi > 0.0 && oteLo > 0.0 && (g_smcOteDir == 0 || g_smcOteDir == dirSign))
      {
         pk.entry = NormalizeDouble((oteHi + oteLo) * 0.5, dg);
         pk.sl = 0; pk.tp1 = 0; pk.tp2 = 0;
         pk.source = "OTE_ZONE";
         if(SMVE_ValidatePack(pk, dirSign))
            return true;
      }
   }

   return false;
}

bool SMVE_HasOpenOrPending()
{
   if(CountPositionsForSymbol(_Symbol) > 0) return true;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      ulong tk = OrderGetTicket(j);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      long om = (long)OrderGetInteger(ORDER_MAGIC);
      if(om != InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT ||
         ot == ORDER_TYPE_BUY_STOP  || ot == ORDER_TYPE_SELL_STOP)
         return true;
   }
   return false;
}

bool SMVE_GomAllows(const int dirSign, int &vnOut, string &why, const bool forMarket)
{
   // Garder vn déjà résolu (srv fallback) ; sinon lire local puis serveur
   if(MathAbs(vnOut) < 2)
      vnOut = g_smcGomVerdictNum;
   if(MathAbs(vnOut) < 2 && MathAbs(g_smcGomVerdictNumServer) >= 2)
      vnOut = g_smcGomVerdictNumServer;
   if(vnOut == 0 || vnOut == -999) { why = "WAIT"; return false; }
   if(MathAbs(vnOut) < 2) { why = "SIMPLE — besoin GOOD/PERFECT"; return false; }
   // Sur GainX/PainX le sens trade est force natif : ne pas exiger vn meme signe
   bool nativeForced = (IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol));
   if(!nativeForced && ((dirSign > 0 && vnOut < 0) || (dirSign < 0 && vnOut > 0)))
   { why = "contre-verdict"; return false; }

   // M5 contre : bloque MARKET seulement. LIMIT KOLA/OB reste autorise (pullback).
   if(forMarket)
   {
      int s5 = 0;
      string m5 = g_smcTfM5Dir; StringToUpper(m5);
      if(StringFind(m5, "BULL") >= 0 || StringFind(m5, "BUY") >= 0) s5 = 1;
      if(StringFind(m5, "BEAR") >= 0 || StringFind(m5, "SELL") >= 0) s5 = -1;
      if(s5 != 0 && s5 != dirSign) { why = "M5 contre (MARKET)"; return false; }
   }
   why = "OK";
   return true;
}

bool SMVE_SendPack(const SMVELevelPack &pk, const int vn, const bool asLimitIn)
{
   bool asLimit = asLimitIn;
   string sym = _Symbol;
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double atr = SMVE_ATR(sym);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   int dirSign = pk.dir;
   string dir = (dirSign > 0) ? "BUY" : "SELL";

   double entry = NormalizeDouble(pk.entry, dg);
   double sl    = NormalizeDouble(pk.sl, dg);
   double tp    = NormalizeDouble(pk.tp1, dg);
   ENUM_ORDER_TYPE ot = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(asLimit)
   {
      double buf = atr * SMVE_LimitBufferATR;
      if(dirSign > 0)
      {
         entry = NormalizeDouble(pk.entry + buf, dg);
         if(entry >= ask)
         {
            // Prix déjà sur/au-delà du niveau : MARKET (scalp) au lieu d'abandonner
            SMVE_Log("prix sur " + pk.source + " → MARKET (plus de chase LIMIT)");
            asLimit = false;
         }
         if(asLimit) ot = ORDER_TYPE_BUY_LIMIT;
      }
      else
      {
         entry = NormalizeDouble(pk.entry - buf, dg);
         if(entry <= bid)
         {
            SMVE_Log("prix sur " + pk.source + " → MARKET (plus de chase LIMIT)");
            asLimit = false;
         }
         if(asLimit) ot = ORDER_TYPE_SELL_LIMIT;
      }
   }

   if(!asLimit)
   {
      entry = (dirSign > 0) ? ask : bid;
      ot = (dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double risk = MathAbs(pk.entry - pk.sl);
      if(risk <= 0.0) risk = atr * SMVE_SL_ATR_Fallback;
      if(dirSign > 0)
      {
         sl = NormalizeDouble(entry - risk, dg);
         tp = NormalizeDouble(entry + risk * MathMax(pk.rr, SMVE_MinRR), dg);
      }
      else
      {
         sl = NormalizeDouble(entry + risk, dg);
         tp = NormalizeDouble(entry - risk * MathMax(pk.rr, SMVE_MinRR), dg);
      }
   }

   // Aligner l'état GOM local sur le vn exécutable (évite WAIT overlay qui bloque FinalOpenGate)
   int vnSaved = g_smcGomVerdictNum;
   if(MathAbs(vn) >= 2 && MathAbs(g_smcGomVerdictNum) < 2)
   {
      g_smcGomVerdictNum = vn;
      g_smcGomVerdict    = (vn > 0)
         ? ((MathAbs(vn) >= 3) ? "PERFECT BUY" : "GOOD BUY")
         : ((MathAbs(vn) >= 3) ? "PERFECT SELL" : "GOOD SELL");
   }

   g_smveGateBypass = true;
   if(!CanTradeOnSymbol(sym, dir)) { SMVE_Log("CanTradeOnSymbol refuse " + dir); g_smveGateBypass = false; g_smcGomVerdictNum = vnSaved; return false; }
   if(asLimit)
   {
      if(!CanPlaceLimitOrder(sym, ot)) { SMVE_Log("CanPlaceLimitOrder refuse"); g_smveGateBypass = false; g_smcGomVerdictNum = vnSaved; return false; }
   }
   else
   {
      if(!CanPlaceMarketOrder(sym, dirSign)) { SMVE_Log("CanPlaceMarketOrder refuse"); g_smveGateBypass = false; g_smcGomVerdictNum = vnSaved; return false; }
   }
   if(!SMC_FinalOpenGate(sym, ot)) { SMVE_Log("FinalOpenGate refuse"); g_smveGateBypass = false; g_smcGomVerdictNum = vnSaved; return false; }
   if(!TryAcquireOpenLock()) { SMVE_Log("OpenLock refuse"); g_smveGateBypass = false; g_smcGomVerdictNum = vnSaved; return false; }

   double lot = SMVE_LotForRisk(sym, entry, sl, SMVE_MaxLossUSD);
   g_smveInFlight = true;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.symbol    = sym;
   req.volume    = lot;
   req.price     = entry;
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 30;
   req.magic     = InpMagicNumber;
   req.type      = ot;
   req.action    = asLimit ? TRADE_ACTION_PENDING : TRADE_ACTION_DEAL;
   req.comment   = StringFormat("SMVE %s %s vn=%d @%s RR=%.2f",
                                dir, (asLimit ? "LMT" : "MKT"), vn, pk.source, pk.rr);

   long fillMode = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   if((fillMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      req.type_filling = ORDER_FILLING_IOC;
   else if((fillMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      req.type_filling = ORDER_FILLING_FOK;
   else
      req.type_filling = ORDER_FILLING_RETURN;

   bool ok = SafeOrderSend(req, res, req.comment);
   if(!ok || (res.retcode != TRADE_RETCODE_DONE &&
              res.retcode != TRADE_RETCODE_DONE_PARTIAL &&
              res.retcode != TRADE_RETCODE_PLACED))
   {
      ZeroMemory(res);
      ResetLastError();
      ok = OrderSend(req, res);
   }
   g_smveInFlight = false;
   g_smveGateBypass = false;
   ReleaseOpenLock();

   if(!ok || (res.retcode != TRADE_RETCODE_DONE &&
              res.retcode != TRADE_RETCODE_DONE_PARTIAL &&
              res.retcode != TRADE_RETCODE_PLACED))
   {
      g_smcGomVerdictNum = vnSaved;
      SMVE_Log(StringFormat("FAIL ret=%d %s | %s E=%.5f SL=%.5f TP=%.5f",
                           res.retcode, res.comment, req.comment, entry, sl, tp));
      return false;
   }

   SMC_GateRegisterOpened(sym, dirSign > 0);
   RegisterOrderPlaced();
   g_smveLastOk = TimeCurrent();
   Print("[SMVE] OK ", req.comment,
         " E=", DoubleToString(entry, dg),
         " SL=", DoubleToString(sl, dg),
         " TP=", DoubleToString(tp, dg),
         " lot=", lot, " ticket=", res.order);
   PB_SendWhatsAppViaAI("ORDER_EXECUTED", sym,
      StringFormat("SMVE %s %s @%s", dir, (asLimit ? "LIMIT" : "MARKET"), pk.source),
      dir, entry, sl, tp, lot);
   return true;
}

// Helper public: prix proche d'un niveau KOLA/OB (pour assouplir MARKET GOOD)
bool SMVE_NearKolaOrOb(const int dirSign, const double nearAtrMult = 0.55)
{
   SMVELevelPack pk;
   if(!SMVE_BuildLevels(dirSign, pk) || !pk.valid) return false;
   double atr = SMVE_ATR(_Symbol);
   if(atr <= 0.0) return false;
   double px = (dirSign > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (MathAbs(px - pk.entry) <= atr * nearAtrMult);
}

bool SMVE_TryEntry()
{
   if(!SMVE_Enable) return false;
   if(TimeCurrent() - g_smveLastTry < 2) return false;
   if(g_smveLastOk > 0 && TimeCurrent() - g_smveLastOk < SMVE_CooldownSec) return false;
   g_smveLastTry = TimeCurrent();

   if(IsTerminalFull()) { SMVE_Log("terminal plein"); return false; }
   if(SMVE_HasOpenOrPending())
   {
      SMVE_Log("position/pending existant — skip");
      return false;
   }

   // Preferer le verdict exécutable : local, sinon serveur (dashboard peut montrer GOOD
   // pendant que correction overlay a mis local=WAIT).
   int vn = g_smcGomVerdictNum;
   if(MathAbs(vn) < 2 && MathAbs(g_smcGomVerdictNumServer) >= 2)
      vn = g_smcGomVerdictNumServer;
   if(vn == 0 || vn == -999 || MathAbs(vn) < 2)
   {
      SMVE_Log(StringFormat("vn=%d (srv=%d) — pas GOOD/PERFECT",
                            g_smcGomVerdictNum, g_smcGomVerdictNumServer));
      return false;
   }
   // Qualite GOOD/PERFECT (|vn|>=2) debloque l'entree — sens = NATIF symbole :
   // GainX/Boom = BUY only ; PainX/Crash = SELL only.
   // (GOM peut afficher BUY sur PainX : on ne le suit PAS, on scale KOLA_SELL.)
   int dirSign = (vn > 0) ? 1 : -1;
   if(IsBoomLikeSymbol(_Symbol))
   {
      if(dirSign < 0)
         SMVE_Log(StringFormat("vn=%d SELL ignore → BUY natif GainX/Boom @KOLA", vn));
      dirSign = 1;
   }
   else if(IsCrashLikeSymbol(_Symbol))
   {
      if(dirSign > 0)
         SMVE_Log(StringFormat("vn=%d BUY ignore → SELL natif PainX/Crash @KOLA", vn));
      dirSign = -1;
   }

   SMVELevelPack pk;
   if(!SMVE_BuildLevels(dirSign, pk) || !pk.valid)
   {
      SMVE_Log(StringFormat("aucun niveau KOLA/OB pour %s", (dirSign > 0 ? "BUY" : "SELL")));
      return false;
   }

   double atr = SMVE_ATR(_Symbol);
   double px  = (dirSign > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist = MathAbs(px - pk.entry);
   bool near = (atr > 0.0 && dist <= atr * SMVE_NearATR);
   // PERFECT + proche → MARKET ; sinon LIMIT (GOOD toujours LIMIT)
   bool wantMarket = (MathAbs(vn) >= 3 && near);

   string why = "";
   if(!SMVE_GomAllows(dirSign, vn, why, wantMarket))
   {
      // PERFECT + M5 contre → rétrograder en LIMIT KOLA (pas d'abandon)
      if(wantMarket && StringFind(why, "M5 contre") >= 0)
      {
         wantMarket = false;
         SMVE_Log("PERFECT M5 contre → LIMIT @" + pk.source);
      }
      else
      {
         SMVE_Log(why);
         return false;
      }
   }

   SMVE_Log(StringFormat("%s %s src=%s E=%.5f SL=%.5f TP1=%.5f RR=%.2f dist=%.5f near=%s vn=%d",
                        (dirSign > 0 ? "BUY" : "SELL"),
                        (wantMarket ? "MARKET" : "LIMIT"),
                        pk.source, pk.entry, pk.sl, pk.tp1, pk.rr, dist,
                        (near ? "Y" : "N"), vn));

   return SMVE_SendPack(pk, vn, !wantMarket);
}

#endif // SMC_SMV_ENTRY_MQH
