//+------------------------------------------------------------------+
//| SMC_AplusGate.mqh — porte A+ (AND) + journal CSV des signaux     |
//| Objectif : n'entrer que quand plusieurs signaux indépendants       |
//| concordent ; journaliser chaque évaluation pour calibrer ensuite. |
//| Inclure APRÈS SMC_ProbabilityGate.mqh et SMC_DowTrendline.mqh.   |
//+------------------------------------------------------------------+
#ifndef SMC_APLUS_GATE_MQH
#define SMC_APLUS_GATE_MQH

input group "=== PORTE A+ (faux signaux / haute proba) ==="
input bool   UseAPlusSetupOnly          = false; // true = bloquer toute entrée hors critères A+
input string APlusSymbolsFilter         = "FX Vol,Volatility,S FX"; // vide = tous ; sinon sous-chaînes séparées par virgule
input bool   APlusJournalEnable         = true;  // journal CSV même si porte soft (UseAPlusSetupOnly=false)
input string APlusJournalFolder         = "SMC_APlus"; // sous-dossier MQL5\\Files
input int    APlusMinVerdictAbs         = 2;     // |vn| min : 2=GOOD, 3=PERFECT
input bool   APlusRequireM5Aligned      = true;  // M5 dans le sens du trade (obligatoire)
input bool   APlusRequireExtraTF        = true;  // + au moins un parmi M1 / M15 / H1
input bool   APlusRequireDowAligned     = true;  // DOW active et dans le sens du verdict
input int    APlusMinConfluences        = 2;     // min confluences au prix (DOW/TL/OB/FVG/sweep)
input double APlusTouchATR              = 0.40;  // tolérance "près du niveau" = N x ATR M1
input double APlusMaxSpreadATR          = 0.35;  // spread max vs ATR M1 (0 = off)
input bool   APlusRequireRejectionCandle= false; // pin/engulf sur M1 avant entrée
input bool   APlusRequireLiquiditySweep = false; // sweep SSL/BSL récent aligné
input int    APlusLiquiditySweepMaxBars = 8;     // sweep ≤ N bougies M1
input bool   APlusRequireM1Structure    = false; // clôture M1 dans le sens après balayage
input double APlusMinProbabilityPct     = 0.0;   // 0 = off ; sinon utilise SMC_ComputeEntryProbability
input int    APlusMaxDailyTrades        = 0;     // 0 = pas de plafond A+ (MaxDailyTrades reste actif)
input int    APlusMaxPositions          = 0;     // 0 = pas de plafond A+ ; sinon max ordres terminal
input int    APlusLogThrottleSec        = 20;    // anti-spam Print + journal

// Snapshot d'évaluation → lié au position_id à l'ouverture, résultat à la clôture
struct APlusSnap
{
   ulong    posId;
   datetime tOpen;
   int      dir;
   int      vn;
   double   coh;
   double   prob;
   int      confN;
   string   tfs;
   string   dow;
   string   confTags;
   string   reason;
   bool     wouldPass; // true si A+ aurait laissé passer (même en soft)
};
APlusSnap g_aplusLastEval;
APlusSnap g_aplusTrack[32];
int       g_aplusTrackN = 0;
datetime  g_aplusSoftJournalAt = 0;

// Dépendances (définies ailleurs)
double SMC_ComputeEntryProbability(const int dirSign);
bool   SMC_FindReactionObjectLevel(const string symbol, const string token, double &level);
int    SMCGP_GetCachedVerdictNum(const string symbol);
double SMCGP_EntryTolerance(const double price);
bool   SMCGP_IsPriceInOBBull();
bool   SMCGP_IsPriceInOBBear();
bool   SMC_DetectLiquiditySweepEx(string symbol, ENUM_TIMEFRAMES tf, string &typeOut, int &barsAgoOut);
int    Strat_TfSign(const string d);
double SMC_EffectiveSymbolATR(const string symbol);
int    CountTerminalAllOrders();

//--- helpers locaux ------------------------------------------------
bool APlus_SymbolInScope(const string symbol)
{
   string filt = APlusSymbolsFilter;
   StringTrimLeft(filt); StringTrimRight(filt);
   if(StringLen(filt) == 0) return true;
   string up = symbol;
   StringToUpper(up);
   string parts[];
   int n = StringSplit(filt, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string p = parts[i];
      StringTrimLeft(p); StringTrimRight(p);
      if(StringLen(p) == 0) continue;
      StringToUpper(p);
      if(StringFind(up, p) >= 0) return true;
   }
   return false;
}

string APlus_Clean(string s)
{
   StringReplace(s, ",", ";");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   StringReplace(s, "\"", "'");
   return s;
}

string APlus_SafeSym(string s)
{
   StringReplace(s, " ", "_");
   StringReplace(s, "/", "_");
   StringReplace(s, "\\", "_");
   return s;
}

bool APlus_AppendCSV(const string path, const string header, const string line)
{
   int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return false;
   if(FileSize(h) == 0) FileWriteString(h, header + "\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
   return true;
}

bool APlus_NearLevel(const double price, const double level, const double tol)
{
   if(level <= 0.0 || price <= 0.0 || tol <= 0.0) return false;
   return (MathAbs(price - level) <= tol);
}

bool APlus_ZoneRejectionCandleOK(const string symbol, const int dirSign)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 3, rates) < 3) return false;

   double o = rates[1].open, c = rates[1].close, h = rates[1].high, l = rates[1].low;
   double range = h - l;
   if(range <= 0.0) return false;

   double lowerWick = MathMin(o, c) - l;
   double upperWick = h - MathMax(o, c);

   if(dirSign > 0)
   {
      bool pinBar    = (lowerWick >= range * 0.5) && (c > o) && (c >= l + range * 0.6);
      bool engulfing = (c > o) && (c > rates[2].open) && (o <= rates[2].close);
      return pinBar || engulfing;
   }
   bool pinBar    = (upperWick >= range * 0.5) && (c < o) && (c <= h - range * 0.6);
   bool engulfing = (c < o) && (c < rates[2].open) && (o >= rates[2].close);
   return pinBar || engulfing;
}

bool APlus_RecentLiquiditySweepAligned(const string symbol, const int dirSign, string &sweepTypeOut)
{
   sweepTypeOut = "";
   int barsAgo = 99;
   if(!SMC_DetectLiquiditySweepEx(symbol, PERIOD_M1, sweepTypeOut, barsAgo))
      return false;
   if(barsAgo > MathMax(1, APlusLiquiditySweepMaxBars)) return false;
   if(dirSign > 0) return (sweepTypeOut == "SSL");
   return (sweepTypeOut == "BSL");
}

// Clôture M1 dans le sens après un balayage : bougie[1] clôture > open (BUY) / < open (SELL)
// et dépasse le milieu de la range (déplacement minimal).
bool APlus_M1StructureShiftOK(const string symbol, const int dirSign)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 3, rates) < 3) return false;
   double o = rates[1].open, c = rates[1].close, h = rates[1].high, l = rates[1].low;
   double mid = (h + l) * 0.5;
   if(dirSign > 0) return (c > o && c >= mid);
   return (c < o && c <= mid);
}

bool APlus_TfAlignmentOK(const int dirSign, string &tfsOut)
{
   tfsOut = "";
   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   int s1  = Strat_TfSign(m1);
   int s5  = Strat_TfSign(g_smcTfM5Dir);
   int s15 = Strat_TfSign(g_smcTfM15Dir);
   int sh1 = Strat_TfSign(g_smcTfH1Dir);

   if(APlusRequireM5Aligned && s5 != dirSign)
      return false;

   tfsOut = "M5=" + g_smcTfM5Dir;
   bool extra = false;
   if(s1  == dirSign) { tfsOut += "+M1";  extra = true; }
   if(s15 == dirSign) { tfsOut += "+M15"; extra = true; }
   if(sh1 == dirSign) { tfsOut += "+H1";  extra = true; }

   if(APlusRequireExtraTF && !extra)
      return false;
   return true;
}

bool APlus_DowAligned(const int dirSign, string &dowInfo)
{
   dowInfo = "inactive";
   if(!g_dowState.active)
      return false;
   dowInfo = g_dowState.isBearish ? "BEAR" : "BULL";
   if(dirSign > 0) return !g_dowState.isBearish;
   if(dirSign < 0) return  g_dowState.isBearish;
   return false;
}

int APlus_CountConfluences(const string symbol, const int dirSign, const double price,
                           const double tol, string &tagsOut)
{
   tagsOut = "";
   int n = 0;

   // 1) DOW projetée / EP
   double dowLvl = 0.0;
   if(g_dowState.active)
   {
      if(g_dowState.projectedPrice > 0.0) dowLvl = g_dowState.projectedPrice;
      else if(g_dowState.currentEpPrice > 0.0) dowLvl = g_dowState.currentEpPrice;
   }
   if(dowLvl <= 0.0)
      SMC_FindReactionObjectLevel(symbol, "DOW_TL_line", dowLvl);
   if(APlus_NearLevel(price, dowLvl, tol))
   {
      n++;
      tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + "DOW";
   }

   // 2) GOM_TF_TL M1 / M5
   double m1 = 0.0, m5 = 0.0;
   bool nearTL = false;
   if(SMC_FindReactionObjectLevel(symbol, "GOM_TF_TL_M1", m1) && APlus_NearLevel(price, m1, tol))
      nearTL = true;
   if(SMC_FindReactionObjectLevel(symbol, "GOM_TF_TL_M5", m5) && APlus_NearLevel(price, m5, tol))
      nearTL = true;
   if(nearTL)
   {
      n++;
      tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + "GOM_TF_TL";
   }

   // 3) Order Block
   bool inOB = (dirSign > 0 && SMCGP_IsPriceInOBBull()) ||
               (dirSign < 0 && SMCGP_IsPriceInOBBear());
   if(inOB)
   {
      n++;
      tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + "OB";
   }

   // 4) FVG trail
   double fvg = 0.0;
   string fvgTok = (dirSign > 0) ? "SMC_DISP_FVG_TRAIL_Bull" : "SMC_DISP_FVG_TRAIL_Bear";
   if(SMC_FindReactionObjectLevel(symbol, fvgTok, fvg) && APlus_NearLevel(price, fvg, tol))
   {
      n++;
      tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + "FVG";
   }

   // 5) OTE / Kola / setup
   if(g_smcOteTop > 0.0 && g_smcOteBot > 0.0)
   {
      double lo = MathMin(g_smcOteTop, g_smcOteBot);
      double hi = MathMax(g_smcOteTop, g_smcOteBot);
      if(price >= lo && price <= hi)
      {
         n++;
         tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + "OTE";
      }
   }
   double kola = (dirSign > 0) ? g_smcGomKolaBuy : g_smcGomKolaSell;
   if(APlus_NearLevel(price, kola, MathMax(tol, SMCGP_EntryTolerance(price))))
   {
      n++;
      tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + "KOLA";
   }
   if(g_smcSetupValid && g_smcSetupEntry > 0.0 && g_smcSetupDir == dirSign &&
      APlus_NearLevel(price, g_smcSetupEntry, MathMax(tol, SMCGP_EntryTolerance(price))))
   {
      n++;
      tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + "SETUP";
   }

   // 6) Sweep liquidité (compte aussi comme confluence même si pas requis)
   string sw = "";
   if(APlus_RecentLiquiditySweepAligned(symbol, dirSign, sw))
   {
      n++;
      tagsOut += (StringLen(tagsOut) > 0 ? "|" : "") + sw;
   }

   return n;
}

void APlus_Journal(const string symbol, const int dirSign, const bool passed,
                   const string reason, const string tfs, const string dowInfo,
                   const string confTags, const int confN, const double prob,
                   const double spreadAtr)
{
   if(!APlusJournalEnable) return;

   static datetime s_lastJ = 0;
   static string   s_lastKey = "";
   string key = symbol + "|" + IntegerToString(dirSign) + "|" + (passed ? "1" : "0") + "|" + reason;
   datetime now = TimeCurrent();
   if(key == s_lastKey && now - s_lastJ < MathMax(5, APlusLogThrottleSec))
      return;
   s_lastKey = key;
   s_lastJ = now;

   string path = APlusJournalFolder + "\\signals_" + APlus_SafeSym(symbol) + ".csv";
   string header = "time,symbol,dir,passed,reason,vn,coh,tfs,dow,conf_n,conf_tags,prob,spread_atr,hour";
   MqlDateTime mt; TimeToStruct(now, mt);
   string line = StringFormat("%s,%s,%s,%d,%s,%d,%s,%s,%s,%d,%s,%s,%s,%02d",
      TimeToString(now, TIME_DATE|TIME_SECONDS),
      APlus_Clean(symbol),
      (dirSign > 0 ? "BUY" : "SELL"),
      passed ? 1 : 0,
      APlus_Clean(reason),
      g_smcGomVerdictNum,
      DoubleToString(g_smcGomCoherence, 1),
      APlus_Clean(tfs),
      APlus_Clean(dowInfo),
      confN,
      APlus_Clean(confTags),
      DoubleToString(prob, 1),
      DoubleToString(spreadAtr, 3),
      mt.hour);
   APlus_AppendCSV(path, header, line);
}

bool SMC_APlusSetupOK(const string symbol, const int dirSign); // forward

void APlus_RememberSnap(const string symbol, const int dirSign, const bool passed,
                        const string reason, const string tfs, const string dowInfo,
                        const string confTags, const int confN, const double prob)
{
   g_aplusLastEval.posId     = 0;
   g_aplusLastEval.tOpen     = TimeCurrent();
   g_aplusLastEval.dir       = dirSign;
   g_aplusLastEval.vn        = g_smcGomVerdictNum;
   g_aplusLastEval.coh       = g_smcGomCoherence;
   g_aplusLastEval.prob      = prob;
   g_aplusLastEval.confN     = confN;
   g_aplusLastEval.tfs       = tfs;
   g_aplusLastEval.dow       = dowInfo;
   g_aplusLastEval.confTags  = confTags;
   g_aplusLastEval.reason    = reason;
   g_aplusLastEval.wouldPass = passed;
}

void APlus_TrackOpen(const ulong posId, const int dirSign)
{
   if(posId == 0) return;
   for(int i = 0; i < g_aplusTrackN; i++)
      if(g_aplusTrack[i].posId == posId) return;
   if(g_aplusTrackN >= 32)
   {
      for(int j = 0; j < 31; j++) g_aplusTrack[j] = g_aplusTrack[j + 1];
      g_aplusTrackN = 31;
   }
   APlusSnap s = g_aplusLastEval;
   // Si le dernier eval n'est pas dans le même sens, snapshot minimal
   if(s.dir != dirSign)
   {
      s.dir = dirSign;
      s.vn = g_smcGomVerdictNum;
      s.coh = g_smcGomCoherence;
      s.reason = "no_snap";
      s.wouldPass = false;
      s.tfs = ""; s.dow = ""; s.confTags = ""; s.confN = 0; s.prob = 0.0;
   }
   s.posId = posId;
   s.tOpen = TimeCurrent();
   g_aplusTrack[g_aplusTrackN++] = s;
}

void APlus_LogResult(const ulong dealTk, const ulong posId)
{
   if(!APlusJournalEnable) return;
   string sym = HistoryDealGetString(dealTk, DEAL_SYMBOL);
   if(!APlus_SymbolInScope(sym)) return;

   long   dtype = HistoryDealGetInteger(dealTk, DEAL_TYPE);
   double pr    = HistoryDealGetDouble(dealTk, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTk, DEAL_SWAP)
                + HistoryDealGetDouble(dealTk, DEAL_COMMISSION);
   datetime t   = (datetime)HistoryDealGetInteger(dealTk, DEAL_TIME);
   string cm    = APlus_Clean(HistoryDealGetString(dealTk, DEAL_COMMENT));
   // deal OUT d'un BUY = SELL
   string side = (dtype == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   string outcome = (pr > 0.01) ? "WIN" : ((pr < -0.01) ? "LOSS" : "BE");

   APlusSnap s;
   s.posId = 0; s.dir = 0; s.vn = 0; s.coh = 0; s.prob = 0; s.confN = 0;
   s.tfs = ""; s.dow = ""; s.confTags = ""; s.reason = "unknown"; s.wouldPass = false;
   s.tOpen = 0;
   for(int i = 0; i < g_aplusTrackN; i++)
   {
      if(g_aplusTrack[i].posId != posId) continue;
      s = g_aplusTrack[i];
      for(int j = i; j < g_aplusTrackN - 1; j++) g_aplusTrack[j] = g_aplusTrack[j + 1];
      g_aplusTrackN--;
      break;
   }

   int dur = (s.tOpen > 0) ? (int)(t - s.tOpen) : 0;
   string path = APlusJournalFolder + "\\results_" + APlus_SafeSym(sym) + ".csv";
   string header = "time,symbol,pos_id,side,outcome,profit,duration_sec,would_aplus,reason,vn,coh,tfs,dow,conf_n,conf_tags,prob,comment";
   string line = StringFormat("%s,%s,%I64u,%s,%s,%s,%d,%d,%s,%d,%s,%s,%s,%d,%s,%s,%s",
      TimeToString(t, TIME_DATE|TIME_SECONDS),
      APlus_Clean(sym),
      posId,
      side,
      outcome,
      DoubleToString(pr, 2),
      dur,
      s.wouldPass ? 1 : 0,
      APlus_Clean(s.reason),
      s.vn,
      DoubleToString(s.coh, 1),
      APlus_Clean(s.tfs),
      APlus_Clean(s.dow),
      s.confN,
      APlus_Clean(s.confTags),
      DoubleToString(s.prob, 1),
      cm);
   APlus_AppendCSV(path, header, line);
   PrintFormat("[A+] RESULT %s %s %s $%s | wouldA+=%d reason=%s conf=%d P=%s",
               sym, side, outcome, DoubleToString(pr, 2),
               s.wouldPass ? 1 : 0, s.reason, s.confN, DoubleToString(s.prob, 0));
}

// Appelé depuis OnTradeTransaction (DEAL_ADD) — ouverture + résultat
void SMC_APlus_OnTransaction(const MqlTradeTransaction &trans)
{
   if(!APlusJournalEnable) return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0) return;

   static ulong s_seen[64];
   static int   s_seenIdx = 0;
   for(int i = 0; i < 64; i++)
      if(s_seen[i] == trans.deal) return;
   s_seen[s_seenIdx] = trans.deal;
   s_seenIdx = (s_seenIdx + 1) % 64;

   HistorySelect(TimeCurrent() - 6 * 3600, TimeCurrent() + 3600);
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)InpMagicNumber) return;
   long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) return;
   string sym = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   if(!APlus_SymbolInScope(sym)) return;

   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong pid  = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(entry == DEAL_ENTRY_IN)
   {
      int dir = (dtype == DEAL_TYPE_BUY) ? 1 : -1;
      APlus_TrackOpen(pid, dir);
   }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      APlus_LogResult(trans.deal, pid);
}

// Échantillonne le journal A+ même sans OrderSend (PERFECT non exécuté, etc.)
void SMC_APlus_SampleOnSignal(const string symbol, const int dirSign)
{
   if(!APlusJournalEnable || dirSign == 0) return;
   if(!APlus_SymbolInScope(symbol)) return;
   g_aplusSoftJournalAt = 0;
   SMC_APlusSetupOK(symbol, dirSign);
}

//+------------------------------------------------------------------+
//| Porte A+ : toutes les conditions obligatoires en AND             |
//| Soft mode (UseAPlusSetupOnly=false) : journalise puis laisse passer |
//| Filtre symboles : hors filtre → toujours OK (test FX Vol isolé)  |
//+------------------------------------------------------------------+
bool SMC_APlusSetupOK(const string symbol, const int dirSign)
{
   if(dirSign == 0)
   {
      if(UseAPlusSetupOnly && APlus_SymbolInScope(symbol)) return false;
      return true;
   }

   // Hors périmètre (ex. Boom/Crash pendant test FX Vol) : ne jamais bloquer
   if(!APlus_SymbolInScope(symbol))
      return true;

   // Soft mode : laisser passer, journaliser au plus 1x / throttle (pas de scan lourd à chaque tick)
   if(!UseAPlusSetupOnly && !APlusJournalEnable)
      return true;
   if(!UseAPlusSetupOnly && APlusJournalEnable &&
      TimeCurrent() - g_aplusSoftJournalAt < MathMax(5, APlusLogThrottleSec))
      return true;

   static datetime s_log = 0;
   bool doLog = (TimeCurrent() - s_log >= MathMax(5, APlusLogThrottleSec));

   string failReason = "";
   string tfs = "";
   string dowInfo = "";
   string confTags = "";
   int confN = 0;
   double prob = 0.0;
   double spreadAtr = 0.0;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price = (dirSign > 0) ? ask : bid;
   double atr = SMC_EffectiveSymbolATR(symbol);
   if(atr <= 0.0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50.0;
   double spread = ask - bid;
   if(atr > 0.0) spreadAtr = spread / atr;
   double tol = MathMax(atr * MathMax(0.05, APlusTouchATR), spread * 2.0);

   // --- évaluation ---
   int vn = -999;
   if(g_smcGomConnected)
      vn = SMCGP_GetCachedVerdictNum(symbol);
   if(vn == -999 && symbol == _Symbol)
      vn = g_smcGomVerdictNum;

   int minVn = MathMax(1, APlusMinVerdictAbs);
   if(vn == -999 || vn == 0 || MathAbs(vn) < minVn)
      failReason = "verdict";
   else if((dirSign > 0 && vn < minVn) || (dirSign < 0 && vn > -minVn))
      failReason = "verdict_dir";
   else if(!APlus_TfAlignmentOK(dirSign, tfs))
      failReason = "tf_align";
   else if(APlusRequireDowAligned && !APlus_DowAligned(dirSign, dowInfo))
      failReason = "dow";
   else
   {
      if(!APlusRequireDowAligned)
         APlus_DowAligned(dirSign, dowInfo); // info journal seulement

      confN = APlus_CountConfluences(symbol, dirSign, price, tol, confTags);
      if(confN < MathMax(1, APlusMinConfluences))
         failReason = "confluence";
      else if(APlusMaxSpreadATR > 0.0 && spreadAtr > APlusMaxSpreadATR)
         failReason = "spread";
      else if(APlusRequireRejectionCandle && !APlus_ZoneRejectionCandleOK(symbol, dirSign))
         failReason = "reject_candle";
      else if(APlusRequireLiquiditySweep)
      {
         string sw = "";
         if(!APlus_RecentLiquiditySweepAligned(symbol, dirSign, sw))
            failReason = "liq_sweep";
      }
      if(StringLen(failReason) == 0 && APlusRequireM1Structure &&
         !APlus_M1StructureShiftOK(symbol, dirSign))
         failReason = "m1_structure";
   }

   if(StringLen(failReason) == 0 && APlusMinProbabilityPct > 0.0)
   {
      prob = SMC_ComputeEntryProbability(dirSign);
      if(prob < APlusMinProbabilityPct)
         failReason = "prob";
   }
   else if(APlusMinProbabilityPct > 0.0 || APlusJournalEnable)
      prob = SMC_ComputeEntryProbability(dirSign);

   if(StringLen(failReason) == 0 && APlusMaxPositions > 0 &&
      CountTerminalAllOrders() >= MathMax(1, APlusMaxPositions))
      failReason = "max_pos";

   if(StringLen(failReason) == 0 && APlusMaxDailyTrades > 0 &&
      g_cmTradesToday >= APlusMaxDailyTrades)
      failReason = "max_daily";

   bool passed = (StringLen(failReason) == 0);
   string reason = passed ? "A+" : failReason;
   APlus_RememberSnap(symbol, dirSign, passed, reason, tfs, dowInfo, confTags, confN, prob);
   APlus_Journal(symbol, dirSign, passed, reason, tfs, dowInfo, confTags, confN, prob, spreadAtr);
   if(!UseAPlusSetupOnly)
      g_aplusSoftJournalAt = TimeCurrent();

   if(passed)
   {
      if(doLog && UseAPlusSetupOnly)
      {
         s_log = TimeCurrent();
         Print("[A+] OK ", symbol, " ", (dirSign > 0 ? "BUY" : "SELL"),
               " | TF=", tfs, " DOW=", dowInfo, " conf=", confN, " [", confTags, "]",
               " P=", DoubleToString(prob, 0), "%");
      }
      return true;
   }

   // Soft : journalise le refus mais laisse passer l'ordre
   if(!UseAPlusSetupOnly)
      return true;

   if(doLog)
   {
      s_log = TimeCurrent();
      string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
      Print("[A+] BLOQUÉ — ", symbol, " — ", failReason,
            " | vn=", vn,
            " | M1=", m1, " M5=", g_smcTfM5Dir, " M15=", g_smcTfM15Dir, " H1=", g_smcTfH1Dir,
            " | DOW=", dowInfo,
            " | conf=", confN, "/", APlusMinConfluences, " [", confTags, "]",
            " | P=", DoubleToString(prob, 0), "% spreadATR=", DoubleToString(spreadAtr, 2));
   }
   return false;
}

#endif // SMC_APLUS_GATE_MQH
