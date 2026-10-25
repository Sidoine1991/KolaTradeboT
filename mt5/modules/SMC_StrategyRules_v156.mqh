//+------------------------------------------------------------------+
//| SMC_StrategyRules_v156.mqh                                        |
//| Règles strictes validées trader 2026-10-22                        |
//|                                                                   |
//| WAIT   : AUCUN ordre (MARKET ni LIMIT) — zéro bypass              |
//| GOOD   (|vn|=2) : LIMIT uniquement, juste avant touch DOW         |
//| PERFECT FX Vol : H1+M5 puis M1+M5 alignés                         |
//| PERFECT PainX/GainX : M5+DOW alignés suffisent (M1 peut laguer)   |
//| Correction structurelle (M5/H1 contre) : hors marché              |
//| Position ouverte + verdict hostile : attendre perte >= 1$         |
//| Post-entrée sans spike : rebond M5/M15, max 3 spikes scalping     |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property strict

#ifndef SMC_STRATEGY_RULES_V156_MQH
#define SMC_STRATEGY_RULES_V156_MQH

extern double   g_vpPocPrice;
extern double   g_vpVah;
extern double   g_vpVal;
extern datetime g_vpLastCalc;
extern int      g_smcGomVerdictNum;
extern string   g_smcTfM1Dir;
extern string   g_smcTfM1DirLive;
extern string   g_smcTfM5Dir;
extern string   g_smcTfH1Dir;
extern bool     g_secondSpikeInFlight;

input group "=== STRATEGIE STRICTE v1.56 (WAIT/GOOD/PERFECT) ==="
input bool   StratStrictEnable          = true;
input bool   StratWaitBlocksEverything  = true;
input bool   StratGoodLimitOnly         = true;
input bool   StratPerfectMarketTL       = true;
input bool   StratRequireM1M5Perfect    = true;  // FX Vol: H1+M5 puis M1+M5
input bool   StratLimitAnySymbol         = true;  // GOOD/PERFECT: LIMIT juste au-dessus/sous la DOW sur TOUT symbole (FX Vol, SFX, Volatility...), sans cascade H1/M1 ni flux prix
input bool   StratSpikePerfectM5DowOk   = true;  // PainX/GainX PERFECT: M5+DOW suffisent (sans attendre M1)
input double StratDowLimitBufferATR     = 0.12;
input double StratCloseMinLossUSD       = 1.0;
input int    StratMaxSpikeScaleIns      = 3;
input bool   StratBlockVAForGood        = true;

int      g_stratSpikeScaleCount = 0;
datetime g_stratLastSpikeScale  = 0;
bool     g_stratInCorrection    = false;

int Strat_LocalVn(const string symbol)
{
   return g_smcGomVerdictNum;
}

int Strat_TfSign(const string d)
{
   string u = d;
   StringToUpper(u);
   if(StringFind(u, "BULL") >= 0 || u == "BUY" || u == "UP" || u == "LONG") return 1;
   if(StringFind(u, "BEAR") >= 0 || u == "SELL" || u == "DOWN" || u == "SHORT") return -1;
   return 0;
}

// Flux prix M1 1-3 barres contre la direction = correction en cours
bool Strat_PriceFlowAgainst(const int dirSign)
{
   if(dirSign == 0) return true;
   double c1[], c3[];
   ArraySetAsSeries(c1, true);
   ArraySetAsSeries(c3, true);
   if(CopyClose(_Symbol, PERIOD_M1, 0, 4, c1) < 4) return false;
   // d1: close[0]-close[1], d3: close[0]-close[3]
   double d1 = c1[0] - c1[1];
   double d3 = c1[0] - c1[3];
   if(dirSign > 0 && d1 < 0 && d3 < 0) return true;  // BUY mais prix baisse
   if(dirSign < 0 && d1 > 0 && d3 > 0) return true;  // SELL mais prix monte
   return false;
}

//--- Confirmation HTF : H1 + M5 alignés dans le sens du trade
bool Strat_H1M5Aligned(const int dirSign)
{
   if(dirSign == 0) return false;
   int sH1 = Strat_TfSign(g_smcTfH1Dir);
   int s5  = Strat_TfSign(g_smcTfM5Dir);
   return (sH1 == dirSign && s5 == dirSign);
}

//--- Exécution : M1 + M5 alignés dans le sens du trade
bool Strat_M1M5Aligned(const int dirSign)
{
   if(dirSign == 0) return false;
   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   int s1 = Strat_TfSign(m1);
   int s5 = Strat_TfSign(g_smcTfM5Dir);
   return (s1 == dirSign && s5 == dirSign);
}

bool Strat_IsSpikeMarketSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0 ||
           StringFind(s, "BOOM")  >= 0 || StringFind(s, "CRASH") >= 0 ||
           StringFind(s, "PAIN")  >= 0 || StringFind(s, "GAIN")  >= 0);
}

bool Strat_IsFxVolFamily(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "FX VOL") >= 0 || StringFind(s, "FXVOL") >= 0 ||
           StringFind(s, "SFX") >= 0 || StringFind(s, "SFV") >= 0 ||
           StringFind(s, "VOLATILITY") >= 0);
}

// DOW aligné avec la direction (objet chart DOW SELL/BUY ou pente)
bool Strat_DowAligned(const int dirSign)
{
   // Scan TOUS les objets (ligne, texte, label) contenant DOW
   int total = ObjectsTotal(0, -1, -1);
   for(int j = 0; j < total; j++)
   {
      string on = ObjectName(0, j, -1, -1);
      if(StringLen(on) == 0) continue;
      string ou = on;
      StringToUpper(ou);
      if(StringFind(ou, "DOW") < 0) continue;
      string tip = ObjectGetString(0, on, OBJPROP_TOOLTIP);
      string txt = ObjectGetString(0, on, OBJPROP_TEXT);
      StringToUpper(tip);
      StringToUpper(txt);
      string blob = ou + " " + tip + " " + txt;
      if(dirSign < 0 && (StringFind(blob, "SELL") >= 0 || StringFind(blob, "BEAR") >= 0))
         return true;
      if(dirSign > 0 && (StringFind(blob, "BUY") >= 0 || StringFind(blob, "BULL") >= 0))
         return true;
   }
   return false;
}

// Correction structurelle = H1 ou M5 contre (M1 seul = micro, pas bloquant sur spike)
bool Strat_TfAgainstDirection(const int dirSign)
{
   if(dirSign == 0) return true;
   int s5  = Strat_TfSign(g_smcTfM5Dir);
   int sH1 = Strat_TfSign(g_smcTfH1Dir);
   // M5 contre = vraie correction / pas d'entrée
   if(s5 != 0 && s5 != dirSign) return true;
   // H1 contre sur marchés non-spike = bloquant
   if(!Strat_IsSpikeMarketSymbol(_Symbol) && sH1 != 0 && sH1 != dirSign)
      return true;
   return false;
}

// Cascade entrée précise :
// FX Vol : H1+M5 puis M1+M5
// PainX/GainX PERFECT : M5 + DOW (M1 peut rester BULL en micro-pullback)
bool Strat_PreciseEntryReady(const int dirSign, string &why)
{
   why = "";
   if(dirSign == 0) { why = "direction nulle"; return false; }

   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   int sH1 = Strat_TfSign(g_smcTfH1Dir);
   int s5  = Strat_TfSign(g_smcTfM5Dir);
   int s1  = Strat_TfSign(m1);
   int vn  = MathAbs(g_smcGomVerdictNum);
   bool isSpike = Strat_IsSpikeMarketSymbol(_Symbol);

   // --- PainX/GainX + GOOD/PERFECT : entrée spike
   // GOOD  : M5 + (DOW ou M1) dans le sens → LIMIT DOW autorisé
   // PERFECT: M5 + DOW (M1 optionnel)
   if(isSpike && StratSpikePerfectM5DowOk && vn >= 2)
   {
      if(s5 != dirSign)
      {
         why = StringFormat("spike: attente M5=%s (besoin %s)",
                            g_smcTfM5Dir, (dirSign > 0 ? "BULL" : "BEAR"));
         return false;
      }
      bool dowOk = Strat_DowAligned(dirSign);
      // GainX 400 cas réel: GOOD BUY + M1 BULL + M5 BULL + DOW BUY affiché
      if(dowOk)
         return true;
      if(s1 == dirSign)
         return true; // M5+M1 alignés suffisent (DOW objet non détecté)
      if(sH1 == dirSign)
         return true; // M5+H1
      why = "spike: M5 OK — besoin DOW ou M1 dans le sens";
      return false;
   }

   // --- FX Vol / autres : cascade stricte H1+M5 puis M1+M5 + flux prix
   if(sH1 != dirSign || s5 != dirSign)
   {
      why = StringFormat("attente confirmation H1+M5 (H1=%s M5=%s, besoin %s)",
                         g_smcTfH1Dir, g_smcTfM5Dir, (dirSign > 0 ? "BULL" : "BEAR"));
      return false;
   }
   if(s1 != dirSign || s5 != dirSign)
   {
      why = StringFormat("H1+M5 OK — attente alignement M1 (M1=%s M5=%s)",
                         m1, g_smcTfM5Dir);
      return false;
   }
   // PERFECT figé en correction : bloquer si le prix M1 va contre le trade
   if(Strat_PriceFlowAgainst(dirSign))
   {
      why = "FX Vol: prix M1 en correction contre le verdict — pas d'entrée";
      return false;
   }
   return true;
}

bool Strat_IsWaitBlocked(const string symbol)
{
   if(!StratStrictEnable || !StratWaitBlocksEverything) return false;
   int vn = Strat_LocalVn(symbol);
   return (vn == 0 || vn == -999);
}

bool Strat_AllowsOpen(const string symbol, const int dirSign, const bool isLimitOrder, string &why)
{
   why = "";
   if(!StratStrictEnable) return true;
   if(dirSign == 0) { why = "direction nulle"; return false; }

   int vn = Strat_LocalVn(symbol);
   if(vn == 0 || vn == -999)
   {
      why = "WAIT strict — aucun ordre autorisé";
      return false;
   }
   if((dirSign > 0 && vn < 0) || (dirSign < 0 && vn > 0))
   {
      why = "contre-verdict GOM";
      return false;
   }

   int absVn = MathAbs(vn);
   if(absVn == 1)
   {
      why = "SIMPLE refusé — GOOD (LIMIT DOW) ou PERFECT (MARKET TL) requis";
      return false;
   }

   // v1.56.3 entrée précise :
   //   1) verdict favorable (ci-dessus)
   //   2) H1+M5 alignés (confirmation)
   //   3) M1+M5 alignés (exécution)
   // LIMIT DOW (GOOD/PERFECT) : on attend justement un pullback vers la DOW, donc ni cascade H1/M1
   // ni "flux prix contre". Seul un M5 clairement contre le verdict bloque (vraie correction).
   // GOOD/PERFECT + LIMIT DOW : M5 contre = pullback vers la ligne, PAS un blocage
   if(StratRequireM1M5Perfect && isLimitOrder && StratLimitAnySymbol && absVn < 2)
   {
      int s5lim = Strat_TfSign(g_smcTfM5Dir);
      if(s5lim != 0 && s5lim != dirSign)
      {
         why = StringFormat("LIMIT DOW: M5=%s contre le verdict (correction)", g_smcTfM5Dir);
         return false;
      }
   }
   else if(StratRequireM1M5Perfect)
   {
      if(Strat_TfAgainstDirection(dirSign))
      {
         string m1x = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
         why = StringFormat("CORRECTION — TF contre verdict (H1=%s M5=%s M1=%s)",
                            g_smcTfH1Dir, g_smcTfM5Dir, m1x);
         return false;
      }
      // FX Vol: même si labels TF OK, prix réel contre = correction
      if(!Strat_IsSpikeMarketSymbol(symbol) && Strat_PriceFlowAgainst(dirSign))
      {
         why = "CORRECTION prix M1 contre verdict (PERFECT figé ignoré)";
         return false;
      }
      string whyTf = "";
      if(!Strat_PreciseEntryReady(dirSign, whyTf))
      {
         why = whyTf;
         return false;
      }
   }

   if(absVn == 2)
   {
      if(StratGoodLimitOnly && !isLimitOrder)
      {
         why = "GOOD = LIMIT DOW uniquement (MARKET interdit)";
         return false;
      }
      return true;
   }
   if(absVn >= 3)
   {
      return true; // alignement déjà vérifié ci-dessus
   }
   why = "verdict non tradable";
   return false;
}

// definies dans SMC_Stubs.mqh (inclus apres ce fichier)
double SMC_LimitMinGap(const string sym);
bool   SMC_PrepareLimitForSend(MqlTradeRequest &req, const string label, const double gapMult);
bool   SMC_LimitSlotGate(MqlTradeRequest &req, const string label);
bool   Strat_TryPerfectDowEpMarket(const int dirSign, bool &handled);
bool   Strat_TryPerfectTlMarket(const int dirSign, bool &handled);
bool   Strat_TryPerfectAlignedMarket(const int dirSign, bool &handled);

bool Strat_ComputeDowLimitPrice(const int dirSign, double &limitPrice, double &dowLevel, string &why)
{
   limitPrice = 0.0;
   dowLevel = 0.0;
   why = "";
   if(ObjectFind(0, "DOW_TL_line") >= 0)
      dowLevel = ObjectGetValueByTime(0, "DOW_TL_line", TimeCurrent(), 0);
   if(dowLevel <= 0.0)
   {
      why = "ligne DOW absente";
      return false;
   }

   double atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50.0;
   {
      double a[];
      int h = iATR(_Symbol, PERIOD_M1, 14);
      if(h != INVALID_HANDLE && CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0)
         atr = a[0];
      if(h != INVALID_HANDLE) IndicatorRelease(h);
   }
   double buf = atr * MathMax(0.05, StratDowLimitBufferATR);
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(dirSign > 0)
      limitPrice = NormalizeDouble(dowLevel + buf, dg);
   else
      limitPrice = NormalizeDouble(dowLevel - buf, dg);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double gapMin = SMC_LimitMinGap(_Symbol);
   if(dirSign > 0 && limitPrice >= ask - gapMin)
   {
      why = "prix déjà au contact DOW (LIMIT BUY non placable sans chase)";
      return false;
   }
   if(dirSign < 0 && limitPrice <= bid + gapMin)
   {
      why = "prix déjà au contact DOW (LIMIT SELL non placable sans chase)";
      return false;
   }
   return true;
}

bool Strat_GomTlM1Touched(const int dirSign, double &levelOut)
{
   levelOut = 0.0;
   double m1 = 0.0;
   if(ObjectFind(0, "GOM_TF_TL_M1") >= 0)
      m1 = ObjectGetValueByTime(0, "GOM_TF_TL_M1", TimeCurrent(), 0);
   if(m1 <= 0.0) return false;
   levelOut = m1;

   double atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 30.0;
   {
      double a[];
      int h = iATR(_Symbol, PERIOD_M1, 14);
      if(h != INVALID_HANDLE && CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0)
         atr = a[0];
      if(h != INVALID_HANDLE) IndicatorRelease(h);
   }
   double tol = atr * 0.35;
   double px = (dirSign > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (MathAbs(px - m1) <= tol);
}

bool Strat_AllowsCloseOnVerdictChange(const ulong ticket, const double currentProfitUSD)
{
   if(!StratStrictEnable) return true;
   if(currentProfitUSD >= 0.0) return false;
   if(currentProfitUSD > -MathMax(0.50, StratCloseMinLossUSD))
      return false;
   return true;
}

bool Strat_AllowsSpikeScaleIn()
{
   if(!StratStrictEnable) return true;
   return (g_stratSpikeScaleCount < MathMax(1, StratMaxSpikeScaleIns));
}

void Strat_RegisterSpikeScale()
{
   g_stratSpikeScaleCount++;
   g_stratLastSpikeScale = TimeCurrent();
}

void Strat_ResetSpikeScale()
{
   g_stratSpikeScaleCount = 0;
   g_stratInCorrection = false;
}

void Strat_MarkCorrection(const bool on)
{
   g_stratInCorrection = on;
   if(on)
      Print("[STRAT] Correction détectée — hors marché jusqu'au rebond M5/M15 TL");
}

bool Strat_IsInCorrection() { return g_stratInCorrection; }

bool Strat_VPAllowsForVerdict(const string symbol, const int dirSign)
{
   if(!StratStrictEnable) return true;
   int vn = Strat_LocalVn(symbol);
   if(StratBlockVAForGood && MathAbs(vn) == 2 && g_vpLastCalc > 0 && g_vpVah > g_vpVal)
   {
      double px = SymbolInfoDouble(symbol, (dirSign > 0) ? SYMBOL_ASK : SYMBOL_BID);
      if(px > g_vpVal && px < g_vpVah)
      {
         Print("[STRAT] GOOD bloqué — prix dans Value Area [",
               DoubleToString(g_vpVal, _Digits), "-", DoubleToString(g_vpVah, _Digits), "]");
         return false;
      }
   }
   return true;
}

string Strat_DashboardTag()
{
   if(!StratStrictEnable) return "STRAT OFF";
   int vn = g_smcGomVerdictNum;
   string mode = "WAIT";
   if(MathAbs(vn) >= 3) mode = "PERFECT-MKT";
   else if(MathAbs(vn) == 2) mode = "GOOD-LMT";
   else if(MathAbs(vn) == 1) mode = "SIMPLE-BLK";
   return StringFormat("STRAT %s spikes=%d%s", mode, g_stratSpikeScaleCount,
                       g_stratInCorrection ? " CORR" : "");
}


// Place LIMIT au niveau DOW projeté (GOOD/PERFECT, hors WAIT)
// Appelé depuis OnTick de l'EA. Retourne true si ordre envoyé ou déjà en place.
bool Strat_TryPlaceDowProjectedLimit()
{
   if(!StratStrictEnable) return false;
   int vn = g_smcGomVerdictNum;
   if(vn == 0 || vn == -999) return false;
   if(MathAbs(vn) < 2) return false; // GOOD/PERFECT only

   int dirSign = (vn > 0) ? 1 : -1;

   // PERFECT + TF alignes (M5+M1 / M5+M15 / M5+H1) + touch GOM_TF_TL M1/M5 : MARKET immediat, TOUS symboles
   {
      bool tlHandled = false;
      bool tlOk = Strat_TryPerfectTlMarket(dirSign, tlHandled);
      if(tlHandled) return tlOk;
   }

   // PERFECT + M1/M5 alignes + DOW EP dans le sens : MARKET (spike probable), pas de LIMIT d'attente
   {
      bool perfHandled = false;
      bool perfOk = Strat_TryPerfectDowEpMarket(dirSign, perfHandled);
      if(perfHandled) return perfOk;
   }

   // PERFECT + M1+M5 (+M15) alignes : MARKET rattrapage (prix deja parti, loin de DOW/TL)
   {
      bool alHandled = false;
      bool alOk = Strat_TryPerfectAlignedMarket(dirSign, alHandled);
      if(alHandled) return alOk;
   }

   string why = "";
   if(!Strat_AllowsOpen(_Symbol, dirSign, true, why))
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 30)
      {
         s_log = TimeCurrent();
         Print("[STRAT-DOW-LIMIT] refus: ", why);
      }
      return false;
   }

   // Un seul LIMIT DOW par symbole
   int pending = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
      string cm = OrderGetString(ORDER_COMMENT);
      if(StringFind(cm, "DOW") >= 0 || StringFind(cm, "STRAT") >= 0)
         pending++;
   }
   if(pending >= 1) return false;
   if(PositionsTotal() > 0)
   {
      for(int p = PositionsTotal() - 1; p >= 0; p--)
      {
         if(!PositionSelectByTicket(PositionGetTicket(p))) continue;
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            return false;
      }
   }

   double dowLevel = 0.0;
   bool bearish = false;
   // 1) g_dowState.projectedPrice si dispo via objets chart
   if(ObjectFind(0, "DOW_TL_line") >= 0)
   {
      dowLevel = ObjectGetValueByTime(0, "DOW_TL_line", TimeCurrent(), 0);
      if(dowLevel <= 0.0)
         dowLevel = ObjectGetDouble(0, "DOW_TL_line", OBJPROP_PRICE, 1);
   }
   if(dowLevel <= 0.0 && ObjectFind(0, "DOW_TL_hline") >= 0)
      dowLevel = ObjectGetDouble(0, "DOW_TL_hline", OBJPROP_PRICE, 0);

   // EP projetés
   if(dowLevel <= 0.0)
   {
      double ep = 0.0;
      if(dirSign > 0 && ObjectFind(0, "DOW_BULL_EP") >= 0)
         ep = ObjectGetDouble(0, "DOW_BULL_EP", OBJPROP_PRICE, 0);
      if(dirSign < 0 && ObjectFind(0, "DOW_BEAR_EP") >= 0)
         ep = ObjectGetDouble(0, "DOW_BEAR_EP", OBJPROP_PRICE, 0);
      // scan labels "DOW BUY" / "DOW SELL"
      if(ep <= 0.0)
      {
         int tot = ObjectsTotal(0, -1, -1);
         for(int j = 0; j < tot; j++)
         {
            string on = ObjectName(0, j, -1, -1);
            string ou = on; StringToUpper(ou);
            if(StringFind(ou, "DOW") < 0) continue;
            if(dirSign > 0 && StringFind(ou, "BUY") < 0 && StringFind(ou, "BULL") < 0) continue;
            if(dirSign < 0 && StringFind(ou, "SELL") < 0 && StringFind(ou, "BEAR") < 0) continue;
            double pr = ObjectGetDouble(0, on, OBJPROP_PRICE, 0);
            if(pr <= 0.0) pr = ObjectGetDouble(0, on, OBJPROP_PRICE, 1);
            if(pr > 0.0) { ep = pr; break; }
         }
      }
      if(ep > 0.0) dowLevel = ep;
   }

   if(dowLevel <= 0.0)
   {
      static datetime s_miss = 0;
      if(TimeCurrent() - s_miss >= 30)
      {
         s_miss = TimeCurrent();
         Print("[STRAT-DOW-LIMIT] aucun niveau DOW projeté trouvé sur ", _Symbol);
      }
      return false;
   }

   double atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50.0;
   {
      double a[];
      int h = iATR(_Symbol, PERIOD_M1, 14);
      if(h != INVALID_HANDLE && CopyBuffer(h, 0, 1, 1, a) >= 1 && a[0] > 0.0)
         atr = a[0];
      if(h != INVALID_HANDLE) IndicatorRelease(h);
   }
   double buf = atr * MathMax(0.05, StratDowLimitBufferATR);
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double limitPrice = 0.0;
   double gapMin = SMC_LimitMinGap(_Symbol); // stops-level + 2x spread + marge ticks

   if(dirSign > 0)
   {
      // BUY LIMIT légèrement AU-DESSUS du niveau DOW : le prix redescend vers le DOW,
      // l'ordre est exécuté juste avant le touch (anticipation), jamais en dessous.
      limitPrice = NormalizeDouble(dowLevel + buf, dg);
      if(limitPrice >= ask - gapMin)
      {
         // le prix est déjà dans la zone DOW (<= niveau + buf) : LIMIT impossible sans chase
         static datetime s_zoneBUY = 0;
         if(TimeCurrent() - s_zoneBUY >= 30)
         {
            s_zoneBUY = TimeCurrent();
            Print("[STRAT-DOW-LIMIT] BUY: prix déjà en zone DOW ", DoubleToString(dowLevel, dg),
                  " limite=", DoubleToString(limitPrice, dg),
                  " ask=", DoubleToString(ask, dg), " — pas de chase");
         }
         return false;
      }
   }
   else
   {
      // SELL LIMIT légèrement SOUS le niveau DOW : le prix remonte vers le DOW,
      // l'ordre est exécuté juste avant le touch (anticipation).
      limitPrice = NormalizeDouble(dowLevel - buf, dg);
      if(limitPrice <= bid + gapMin)
      {
         static datetime s_zoneSELL = 0;
         if(TimeCurrent() - s_zoneSELL >= 30)
         {
            s_zoneSELL = TimeCurrent();
            Print("[STRAT-DOW-LIMIT] SELL: prix déjà en zone DOW ", DoubleToString(dowLevel, dg),
                  " limite=", DoubleToString(limitPrice, dg),
                  " bid=", DoubleToString(bid, dg), " — pas de chase");
         }
         return false;
      }
   }

   // Lot + SL/TP $3
   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVl = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSz <= 0) tickSz = _Point;
   if(tickVl <= 0) tickVl = 1.0;
   double maxLoss = 3.0;
   if(MaxLossPerSpikeTradeDollars > 0.0) maxLoss = MaxLossPerSpikeTradeDollars;
   double slDist = (maxLoss / MathMax(lot, 0.01)) * (tickSz / tickVl);
   if(slDist <= 0) slDist = atr * 1.5;
   {
      // plancher : 1 ATR M1 et stops-level broker (FX Vol / indices : le SL $ seul est trop serre)
      double stopsMin = ((double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 2.0) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      slDist = MathMax(slDist, MathMax(atr, stopsMin));
   }
   double sl = 0.0, tp = 0.0;
   if(dirSign > 0)
   {
      sl = NormalizeDouble(limitPrice - slDist, dg);
      tp = NormalizeDouble(limitPrice + slDist * 1.5, dg);
   }
   else
   {
      sl = NormalizeDouble(limitPrice + slDist, dg);
      tp = NormalizeDouble(limitPrice - slDist * 1.5, dg);
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_PENDING;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.type      = (dirSign > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.price     = limitPrice;
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 20;
   req.magic     = InpMagicNumber;
   req.comment   = StringFormat("STRAT DOW LMT %s @%.5f", (dirSign > 0 ? "BUY" : "SELL"), dowLevel);
   req.type_filling = ORDER_FILLING_IOC;
   // filling fallback
   long fillMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      req.type_filling = ORDER_FILLING_FOK;
   else if((fillMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      req.type_filling = ORDER_FILLING_IOC;
   else
      req.type_filling = ORDER_FILLING_RETURN;

   // Revalidation avec cotations fraiches (anti "Invalid price") : alignement tick, pas de chase
   if(!SMC_PrepareLimitForSend(req, "STRAT-DOW-LIMIT", 1.0))
      return false;
   limitPrice = req.price;
   // Max N LIMIT dans le terminal : garde les meilleurs (remplace le pire si le nouveau est meilleur)
   if(!SMC_LimitSlotGate(req, "STRAT-DOW-LIMIT"))
      return false;

   // Gate final
   if(!SMC_FinalOpenGate_Impl(_Symbol, req.type))
   {
      Print("[STRAT-DOW-LIMIT] FinalOpenGate refuse");
      return false;
   }

   ResetLastError();
   bool okSend = OrderSend(req, res);
   if(res.retcode == TRADE_RETCODE_INVALID_PRICE || res.retcode == TRADE_RETCODE_INVALID_STOPS)
   {
      // 1 retry avec marge x2.5 (le prix a derive pendant la latence d'envoi)
      if(SMC_PrepareLimitForSend(req, "STRAT-DOW-LIMIT-RETRY", 2.5))
      {
         limitPrice = req.price;
         ResetLastError();
         ZeroMemory(res);
         okSend = OrderSend(req, res);
      }
   }
   if(!okSend)
   {
      Print("[STRAT-DOW-LIMIT] OrderSend fail err=", GetLastError(),
            " ret=", res.retcode, " ", res.comment);
      return false;
   }
   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL &&
      res.retcode != TRADE_RETCODE_PLACED)
   {
      Print("[STRAT-DOW-LIMIT] retcode=", res.retcode, " ", res.comment);
      return false;
   }

   Print("[STRAT-DOW-LIMIT] ✅ LIMIT ", (dirSign > 0 ? "BUY" : "SELL"),
         " @ ", DoubleToString(limitPrice, dg),
         " DOW=", DoubleToString(dowLevel, dg),
         " SL=", DoubleToString(sl, dg),
         " ticket=", res.order);
   return true;
}


#endif // SMC_STRATEGY_RULES_V156_MQH
