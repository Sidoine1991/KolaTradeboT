//+------------------------------------------------------------------+
//| SMC_LearnJournal.mqh  (v1.57)                                    |
//| Journal d'apprentissage : instantane d'indicateurs a l'entree,   |
//| resultat a la sortie (MAE/MFE), trades "fantomes" (entrees       |
//| refusees + resultat simule), reconstitution de l'historique.     |
//| Fichiers CSV dans MQL5\Files\<LJ_Folder>\ (un jeu par symbole).  |
//+------------------------------------------------------------------+
#ifndef SMC_LEARN_JOURNAL_MQH
#define SMC_LEARN_JOURNAL_MQH

input group "=== APPRENTISSAGE : JOURNAL CSV (v1.57) ==="
input bool   LJ_Enable           = true;         // Journal d'apprentissage actif
input string LJ_Folder           = "SMC_Learn";  // Sous-dossier de MQL5\Files (local terminal)
input bool   LJ_UseCommonFiles   = true;         // Aussi ecrire/lire Common\\Files\\TradBOT\\SMC_Learn (multi-terminaux)
input string LJ_CommonFolder     = "TradBOT\\SMC_Learn"; // Dossier FILE_COMMON partage
input int    LJ_ShadowMinSec     = 300;          // FIX v1.57: 120->300s pour reduire le churn shadow
input int    LJ_ShadowHorizonSec = 900;          // Horizon d'evaluation d'un trade fantome (s)
input bool   LJ_BackfillOnInit   = true;         // Reconstituer l'historique du compte (1 fois / symbole)
input int    LJ_BackfillDays     = 365;          // Profondeur de la reconstitution
input bool   LJ_ShowOnChart      = true;         // Ligne LEARN sur le dashboard (WR / expectancy / shadow)
input bool   LJ_ShowEquityCurve  = true;         // Courbe d'equity LEARN sur le graphique (derniers N closes)
input int    LJ_EquityPoints     = 40;           // Points max de la courbe equity
input bool   LJ_UseExpectancyGate= true;         // Filtrer les entrees si assez d'echantillons et expectancy < seuil
// FIX v1.57: seuils recalibrés sur les 7896 shadow trades (WR reelle = 40,6%).
// Avant, LJ_GateMinWinRate=0.40 etait INFERIEUR a la WR reelle -> la gate ne bloquait JAMAIS.
// On passe a 0.50 (seuil rentabilite) et on utilise les shadows comme echantillon d'apprentissage.
input int    LJ_GateMinSamples   = 100;          // Min shadows (close+hist+shadow) avant de bloquer
input double LJ_GateMinWinRate   = 0.50;         // WR min (0..1) pour autoriser le sens
input double LJ_GateMinExpectancyUSD = 0.0;      // Espérance $ moyenne min (bloquer si sous ce seuil)
input double LJ_ShadowMinExpAtr  = 0.0;          // Espérance (mfe-mae)/ATR min sur les shadows (seuil rentabilite)
input string LJ_HardBlockSymbols = "GainX 800,GainX 999,PainX 999,PainX 1200"; // FIX v1.57: E[mfe-mae]/ATR < -0.6
input bool   LJ_PreferLearnedSide= true;         // Preferer le sens BUY|SELL avec meilleur WR
input bool   LJ_EnforcePreferSide= true;         // true = bloquer le sens oppose au sens appris (apres warmup)
input bool   LJ_UseJournalAdvisor= true;         // Consulter ai_server /journal/decision avant entree
input int    LJ_JournalAdvisorTimeoutMs = 800;   // Timeout WebRequest advisor (ms)
input int    LJ_StatsRefreshSec  = 60;           // Recalcul stats CSV (s)

int g_ljRsi  = INVALID_HANDLE;
int g_ljEmaF = INVALID_HANDLE;
int g_ljEmaS = INVALID_HANDLE;

struct LJ_PosTrack { ulong id; double mfe; double mae; datetime t; };
LJ_PosTrack g_ljTrack[32];
int g_ljTrackN = 0;

struct LJ_Shadow { datetime t0; int dir; double px; double atr; string reason; string feat; };
LJ_Shadow g_ljSh[64];
int g_ljShN = 0;
datetime g_ljShLast[2];

//--- utilitaires --------------------------------------------------
string LJ_Clean(string s)
{
   StringReplace(s, ",", ";");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   StringReplace(s, "\"", "'");
   return s;
}

string LJ_D(const double v, const int dg)
{
   if(!MathIsValidNumber(v)) return "";
   return DoubleToString(v, dg);
}

string LJ_SafeSym(string s)
{
   StringReplace(s, " ", "_");
   StringReplace(s, "/", "_");
   StringReplace(s, "\\", "_");
   return s;
}

string LJ_Path(const string kind, const string sym)
{
   return LJ_Folder + "\\" + kind + "_" + LJ_SafeSym(sym) + ".csv";
}

string LJ_CommonPath(const string kind, const string sym)
{
   return LJ_CommonFolder + "\\" + kind + "_" + LJ_SafeSym(sym) + ".csv";
}

bool LJ_AppendLineFlags(const string path, const string header, const string line, const int flags)
{
   int h = FileOpen(path, flags);
   if(h == INVALID_HANDLE) return false;
   if(FileSize(h) == 0) FileWriteString(h, header + "\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
   return true;
}

bool LJ_AppendLine(const string path, const string header, const string line)
{
   int baseFlags = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE;
   bool ok = LJ_AppendLineFlags(path, header, line, baseFlags);
   if(LJ_UseCommonFiles)
   {
      string rest = path;
      string prefix = LJ_Folder + "\\";
      if(StringFind(path, prefix) == 0)
         rest = StringSubstr(path, StringLen(prefix));
      FolderCreate(LJ_CommonFolder, FILE_COMMON);
      LJ_AppendLineFlags(LJ_CommonFolder + "\\" + rest, header, line, baseFlags | FILE_COMMON);
   }
   return ok;
}

double LJ_Buf(const int handle)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double b[];
   ArraySetAsSeries(b, true);
   if(CopyBuffer(handle, 0, 0, 1, b) < 1) return 0.0;
   return b[0];
}

string LJ_ReasonTxt(const int rs)
{
   if(rs == DEAL_REASON_SL)     return "SL";
   if(rs == DEAL_REASON_TP)     return "TP";
   if(rs == DEAL_REASON_EXPERT) return "EXPERT";
   if(rs == DEAL_REASON_CLIENT) return "CLIENT";
   if(rs == DEAL_REASON_SO)     return "STOPOUT";
   return "OTHER";
}

//--- instantane d'indicateurs (valable pour _Symbol) -------------------
string LJ_FeatHeader()
{
   return "vn,vn_srv,coh,qual,tf_m1,tf_m5,tf_m15,delta,cvd,poc_d,vah_d,val_d,in_va,flow20,flow3,"
          "atr,atr_pct,rsi14,ema_gap,spread_pts,hour,dow,imminence,consec_loss,consec_win,ai_conf,gom_conn";
}

string LJ_Features(const string sym, const double price)
{
   double atr = SMC_EffectiveSymbolATR(sym);
   double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
   string pocD = "", vahD = "", valD = "", inVA = "";
   if(g_vpLastCalc > 0 && atr > 0.0 && price > 0.0 && g_vpVah > g_vpVal)
   {
      pocD = LJ_D((price - g_vpPocPrice) / atr, 3);
      vahD = LJ_D((price - g_vpVah) / atr, 3);
      valD = LJ_D((price - g_vpVal) / atr, 3);
      inVA = (price <= g_vpVah && price >= g_vpVal) ? "1" : "0";
   }
   double rsi = LJ_Buf(g_ljRsi);
   double ef  = LJ_Buf(g_ljEmaF);
   double es  = LJ_Buf(g_ljEmaS);
   string emaGap = (atr > 0.0 && ef > 0.0 && es > 0.0) ? LJ_D((ef - es) / atr, 3) : "";
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double spr = (pt > 0.0) ? (ask - bid) / pt : 0.0;
   MqlDateTime mt;
   TimeToStruct(TimeCurrent(), mt);

   string s = "";
   s += LJ_D((double)g_smcGomVerdictNum, 0) + ",";
   s += LJ_D((double)g_smcGomVerdictNumServer, 0) + ",";
   s += LJ_D(g_smcGomCoherence, 1) + ",";
   s += LJ_D(g_smcGomQuality, 1) + ",";
   s += LJ_Clean(g_smcTfM1Dir) + "," + LJ_Clean(g_smcTfM5Dir) + "," + LJ_Clean(g_smcTfM15Dir) + ",";
   s += LJ_D(g_smcGhostDelta, 1) + "," + LJ_D(g_smcGhostCVD, 1) + ",";
   s += pocD + "," + vahD + "," + valD + "," + inVA + ",";
   s += LJ_D(VPF_MoneyFlow(sym, VPF_FlowBars, 1), 3) + ",";
   s += LJ_D(VPF_MoneyFlow(sym, 3, 1), 3) + ",";
   s += LJ_D(atr, 5) + ",";
   s += ((price > 0.0) ? LJ_D(atr / price * 100.0, 5) : "") + ",";
   s += LJ_D(rsi, 1) + "," + emaGap + ",";
   s += LJ_D(spr, 1) + ",";
   s += IntegerToString(mt.hour) + "," + IntegerToString(mt.day_of_week) + ",";
   s += LJ_D(ChainPred_GetImminence(), 1) + ",";
   s += IntegerToString(g_cmConsecLosses) + "," + IntegerToString(g_cmConsecWins) + ",";
   s += LJ_D(g_lastAIConfidence, 3) + ",";
   s += (g_smcGomConnected ? "1" : "0");
   return s;
}

//--- suivi MAE/MFE par position --------------------------------------
int LJ_TrackFind(const ulong id)
{
   for(int i = 0; i < g_ljTrackN; i++)
      if(g_ljTrack[i].id == id) return i;
   return -1;
}

int LJ_TrackAdd(const ulong id, const datetime t)
{
   if(g_ljTrackN >= 32) return -1;
   int k = g_ljTrackN++;
   g_ljTrack[k].id = id;
   g_ljTrack[k].mfe = 0.0;
   g_ljTrack[k].mae = 0.0;
   g_ljTrack[k].t = t;
   return k;
}

void LJ_TrackRemove(const int k)
{
   if(k < 0 || k >= g_ljTrackN) return;
   g_ljTrackN--;
   if(k != g_ljTrackN) g_ljTrack[k] = g_ljTrack[g_ljTrackN];
}

//--- journal OUVERTURE / CLOTURE -------------------------------------
void LJ_LogOpen(const ulong dealTk, const ulong pid)
{
   long   dtype = HistoryDealGetInteger(dealTk, DEAL_TYPE);
   double vol   = HistoryDealGetDouble(dealTk, DEAL_VOLUME);
   double px    = HistoryDealGetDouble(dealTk, DEAL_PRICE);
   datetime t   = (datetime)HistoryDealGetInteger(dealTk, DEAL_TIME);
   string cm    = LJ_Clean(HistoryDealGetString(dealTk, DEAL_COMMENT));
   double sl = 0.0, tp = 0.0;
   if(PositionSelectByTicket(pid))
   {
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
   }
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string line = TimeToString(t, TIME_DATE | TIME_SECONDS) + "," + LJ_Clean(_Symbol) + "," + (string)pid + "," +
                 ((dtype == DEAL_TYPE_BUY) ? "BUY" : "SELL") + "," + DoubleToString(vol, 2) + "," +
                 DoubleToString(px, dg) + "," + DoubleToString(sl, dg) + "," + DoubleToString(tp, dg) + "," +
                 cm + "," + LJ_Features(_Symbol, px);
   string head = "time,symbol,pos_id,side,volume,price,sl,tp,comment," + LJ_FeatHeader();
   LJ_AppendLine(LJ_Path("open", _Symbol), head, line);
   if(LJ_TrackFind(pid) < 0) LJ_TrackAdd(pid, t);
}

void LJ_LogClose(const ulong dealTk, const ulong pid)
{
   long   dtype = HistoryDealGetInteger(dealTk, DEAL_TYPE);
   double vol   = HistoryDealGetDouble(dealTk, DEAL_VOLUME);
   double px    = HistoryDealGetDouble(dealTk, DEAL_PRICE);
   double pr    = HistoryDealGetDouble(dealTk, DEAL_PROFIT);
   double sw    = HistoryDealGetDouble(dealTk, DEAL_SWAP);
   double cmn   = HistoryDealGetDouble(dealTk, DEAL_COMMISSION);
   datetime t   = (datetime)HistoryDealGetInteger(dealTk, DEAL_TIME);
   string cm    = LJ_Clean(HistoryDealGetString(dealTk, DEAL_COMMENT));
   string why   = LJ_ReasonTxt((int)HistoryDealGetInteger(dealTk, DEAL_REASON));
   string dur = "", mfe = "", mae = "";
   int k = LJ_TrackFind(pid);
   if(k >= 0)
   {
      dur = IntegerToString((int)(t - g_ljTrack[k].t));
      mfe = DoubleToString(g_ljTrack[k].mfe, 2);
      mae = DoubleToString(g_ljTrack[k].mae, 2);
      LJ_TrackRemove(k);
   }
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   // le deal de sortie d'une position BUY est de type SELL (et inversement)
   string side = (dtype == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   string line = TimeToString(t, TIME_DATE | TIME_SECONDS) + "," + LJ_Clean(_Symbol) + "," + (string)pid + "," +
                 side + "," + DoubleToString(vol, 2) + "," + DoubleToString(px, dg) + "," +
                 DoubleToString(pr, 2) + "," + DoubleToString(sw, 2) + "," + DoubleToString(cmn, 2) + "," +
                 dur + "," + mfe + "," + mae + "," + why + "," + cm;
   string head = "time,symbol,pos_id,side,volume,price_close,profit,swap,commission,duration_sec,mfe_usd,mae_usd,reason,comment";
   LJ_AppendLine(LJ_Path("close", _Symbol), head, line);
}

void LJ_OnTransaction(const MqlTradeTransaction &trans)
{
   if(!LJ_Enable) return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dt = trans.deal;
   if(dt == 0) return;

   static ulong s_seen[64];
   static int   s_seenIdx = 0;
   for(int i = 0; i < 64; i++)
      if(s_seen[i] == dt) return;
   s_seen[s_seenIdx] = dt;
   s_seenIdx = (s_seenIdx + 1) % 64;

   HistorySelect(TimeCurrent() - 6 * 3600, TimeCurrent() + 3600);
   if(!HistoryDealSelect(dt)) return;
   if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(dt, DEAL_MAGIC) != (long)InpMagicNumber) return;
   long dtype = HistoryDealGetInteger(dt, DEAL_TYPE);
   if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) return;
   long entry = HistoryDealGetInteger(dt, DEAL_ENTRY);
   ulong pid = (ulong)HistoryDealGetInteger(dt, DEAL_POSITION_ID);
   if(entry == DEAL_ENTRY_IN)
      LJ_LogOpen(dt, pid);
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      LJ_LogClose(dt, pid);
}

//--- trades fantomes (entrees refusees) ------------------------------
void LJ_ShadowCandidate(const string sym, const bool isBuy, const string reason)
{
   if(!LJ_Enable || sym != _Symbol) return;
   // uniquement les candidats alignes avec le verdict GOM courant
   if(g_smcGomVerdictNum == 0 || ((g_smcGomVerdictNum > 0) != isBuy)) return;
   int ix = isBuy ? 1 : 0;
   datetime now = TimeCurrent();
   if(now - g_ljShLast[ix] < MathMax(30, LJ_ShadowMinSec)) return;
   if(g_ljShN >= 64) return;
   double px  = SymbolInfoDouble(sym, isBuy ? SYMBOL_ASK : SYMBOL_BID);
   double atr = SMC_EffectiveSymbolATR(sym);
   if(px <= 0.0 || atr <= 0.0) return;
   g_ljShLast[ix] = now;
   int k = g_ljShN++;
   g_ljSh[k].t0     = now;
   g_ljSh[k].dir    = isBuy ? 1 : -1;
   g_ljSh[k].px     = px;
   g_ljSh[k].atr    = atr;
   g_ljSh[k].reason = LJ_Clean(reason);
   g_ljSh[k].feat   = LJ_Features(sym, px);
}

void LJ_ShadowProcess(const datetime now)
{
   int horizon = MathMax(120, LJ_ShadowHorizonSec);
   for(int i = g_ljShN - 1; i >= 0; i--)
   {
      if(now - g_ljSh[i].t0 < horizon) continue;
      MqlRates r[];
      ArraySetAsSeries(r, false);
      int n = CopyRates(_Symbol, PERIOD_M1, g_ljSh[i].t0, g_ljSh[i].t0 + horizon, r);
      bool drop = true;
      if(n > 0)
      {
         double px = g_ljSh[i].px, atr = g_ljSh[i].atr;
         int d = g_ljSh[i].dir;
         double hi = r[0].high, lo = r[0].low;
         double c5 = r[0].close, cEnd = r[n - 1].close;
         for(int j = 0; j < n; j++)
         {
            if(r[j].high > hi) hi = r[j].high;
            if(r[j].low  < lo) lo = r[j].low;
            if(r[j].time <= g_ljSh[i].t0 + 300) c5 = r[j].close;
         }
         double mfe = (d > 0) ? (hi - px) : (px - lo);
         double mae = (d > 0) ? (px - lo) : (hi - px);
         int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         string line = TimeToString(g_ljSh[i].t0, TIME_DATE | TIME_SECONDS) + "," + LJ_Clean(_Symbol) + "," +
                       ((d > 0) ? "BUY" : "SELL") + "," + g_ljSh[i].reason + "," + DoubleToString(px, dg) + "," +
                       LJ_D(atr, 5) + "," + LJ_D(d * (c5 - px) / atr, 3) + "," + LJ_D(d * (cEnd - px) / atr, 3) + "," +
                       LJ_D(mfe / atr, 3) + "," + LJ_D(mae / atr, 3) + "," + g_ljSh[i].feat;
         string head = "time,symbol,side,reason,price,atr,ret5_atr,ret15_atr,mfe_atr,mae_atr," + LJ_FeatHeader();
         LJ_AppendLine(LJ_Path("shadow", _Symbol), head, line);
      }
      else if(now - g_ljSh[i].t0 < horizon * 3)
         drop = false;   // donnees M1 pas encore disponibles : reessayer
      if(drop)
      {
         g_ljShN--;
         if(i != g_ljShN) g_ljSh[i] = g_ljSh[g_ljShN];
      }
   }
}

//--- tick : MAE/MFE + fantomes -----------------------------------------
void LJ_OnTick()
{
   if(!LJ_Enable) return;
   static datetime s_last = 0;
   datetime now = TimeCurrent();
   if(now == s_last) return;
   s_last = now;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      ulong pid = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      int k = LJ_TrackFind(pid);
      if(k < 0) k = LJ_TrackAdd(pid, (datetime)PositionGetInteger(POSITION_TIME));
      if(k < 0) continue;
      if(pl > g_ljTrack[k].mfe) g_ljTrack[k].mfe = pl;
      if(pl < g_ljTrack[k].mae) g_ljTrack[k].mae = pl;
   }
   LJ_ShadowProcess(now);
}

//--- wrapper de la gate finale : journalise les refus -----------------
bool SMC_FinalOpenGate(const string symbol, const ENUM_ORDER_TYPE orderType)
{
   bool ok = SMC_FinalOpenGate_Impl(symbol, orderType);
   if(!ok)
   {
      bool isBuy = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT ||
                    orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_STOP_LIMIT);
      LJ_ShadowCandidate(symbol, isBuy, "FINAL_GATE");
   }
   return ok;
}

//--- reconstitution de l'historique du compte ---------------------------
void LJ_Profile(const MqlRates &r[], const int n, double &poc, double &vah, double &val)
{
   poc = 0.0; vah = 0.0; val = 0.0;
   if(n < 20) return;
   double lo = r[0].low, hi = r[0].high;
   for(int i = 1; i < n; i++)
   {
      if(r[i].low  < lo) lo = r[i].low;
      if(r[i].high > hi) hi = r[i].high;
   }
   if(hi <= lo) return;
   int bins = MathMax(10, VP_PriceBins);
   double step = (hi - lo) / bins;
   long vol[];
   ArrayResize(vol, bins);
   ArrayInitialize(vol, 0);
   for(int i = 0; i < n; i++)
   {
      long v = (long)r[i].tick_volume;
      int bLo = (int)((r[i].low  - lo) / step);
      int bHi = (int)((r[i].high - lo) / step);
      if(bLo < 0) bLo = 0;
      if(bHi >= bins) bHi = bins - 1;
      if(bHi < bLo) bHi = bLo;
      int span = bHi - bLo + 1;
      for(int b = bLo; b <= bHi; b++) vol[b] += (long)(v / span);
   }
   int pocBin = 0;
   for(int b = 1; b < bins; b++) if(vol[b] > vol[pocBin]) pocBin = b;
   double total = 0.0;
   for(int b = 0; b < bins; b++) total += (double)vol[b];
   double target = total * (VP_ValueAreaPct / 100.0);
   int loB = pocBin, hiB = pocBin;
   double acc = (double)vol[pocBin];
   while(acc < target && (loB > 0 || hiB < bins - 1))
   {
      double vLo = -1.0;
      double vHi = -1.0;
      if(loB > 0)
         vLo = (double)vol[loB - 1];
      if(hiB < bins - 1)
         vHi = (double)vol[hiB + 1];
      if(vLo >= vHi && loB > 0)  { loB--; acc += vLo; }
      else if(hiB < bins - 1)    { hiB++; acc += vHi; }
      else break;
   }
   poc = lo + (pocBin + 0.5) * step;
   vah = lo + (hiB + 1.0) * step;
   val = lo + loB * step;
}

double LJ_FlowArr(const MqlRates &r[], const int n, const int bars)
{
   double num = 0.0, den = 0.0;
   int from = n - bars;
   if(from < 0) from = 0;
   for(int i = from; i < n; i++)
   {
      double v = (double)r[i].tick_volume;
      if(v <= 0.0) continue;
      double rng = r[i].high - r[i].low;
      double mfm = 0.0;
      if(rng > 0.0)
         mfm = ((r[i].close - r[i].low) - (r[i].high - r[i].close)) / rng;
      num += mfm * v;
      den += v;
   }
   return (den > 0.0) ? num / den : 0.0;
}

void LJ_Backfill()
{
   if(!LJ_BackfillOnInit) return;
   string flag = LJ_Path("backfill_done", _Symbol);
   if(FileIsExist(flag)) return;

   datetime from = TimeCurrent() - (datetime)LJ_BackfillDays * 86400;
   if(!HistorySelect(from, TimeCurrent() + 3600)) return;
   int total = HistoryDealsTotal();

   ulong    inPid[];
   datetime inT[];
   double   inPx[];
   long     inType[];
   string   inCm[];
   ulong    outPid[];
   datetime outT[];
   double   outPx[];
   double   outPr[];
   double   outSw[];
   double   outCmn[];
   double   outVol[];
   string   outWhy[];
   int nIn = 0, nOut = 0;
   for(int i = 0; i < total; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      long dtype = HistoryDealGetInteger(tk, DEAL_TYPE);
      if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
      {
         ArrayResize(inPid, nIn + 1); ArrayResize(inT, nIn + 1); ArrayResize(inPx, nIn + 1);
         ArrayResize(inType, nIn + 1); ArrayResize(inCm, nIn + 1);
         inPid[nIn]  = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
         inT[nIn]    = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
         inPx[nIn]   = HistoryDealGetDouble(tk, DEAL_PRICE);
         inType[nIn] = dtype;
         inCm[nIn]   = LJ_Clean(HistoryDealGetString(tk, DEAL_COMMENT));
         nIn++;
      }
      else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
         ArrayResize(outPid, nOut + 1); ArrayResize(outT, nOut + 1); ArrayResize(outPx, nOut + 1);
         ArrayResize(outPr, nOut + 1); ArrayResize(outSw, nOut + 1); ArrayResize(outCmn, nOut + 1);
         ArrayResize(outVol, nOut + 1); ArrayResize(outWhy, nOut + 1);
         outPid[nOut] = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
         outT[nOut]   = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
         outPx[nOut]  = HistoryDealGetDouble(tk, DEAL_PRICE);
         outPr[nOut]  = HistoryDealGetDouble(tk, DEAL_PROFIT);
         outSw[nOut]  = HistoryDealGetDouble(tk, DEAL_SWAP);
         outCmn[nOut] = HistoryDealGetDouble(tk, DEAL_COMMISSION);
         outVol[nOut] = HistoryDealGetDouble(tk, DEAL_VOLUME);
         outWhy[nOut] = LJ_ReasonTxt((int)HistoryDealGetInteger(tk, DEAL_REASON));
         nOut++;
      }
   }

   if(nOut == 0) return;   // rien a reconstituer : reessayer au prochain demarrage

   string path = LJ_Path("hist", _Symbol);
   string head = "t_open,t_close,symbol,pos_id,side,volume,price_open,price_close,profit,swap,commission,duration_sec,reason,comment_open,"
                 "atr,atr_pct,rsi14,ema_gap,flow20,flow3,poc_d,vah_d,val_d,in_va,hour,dow";
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int written = 0;
   for(int o = 0; o < nOut; o++)
   {
      int ii = -1;
      for(int i = 0; i < nIn; i++) if(inPid[i] == outPid[o]) { ii = i; break; }
      if(ii < 0) continue;
      datetime to = inT[ii];
      double pxo = inPx[ii];

      string atrS = "", atrP = "", rsiS = "", emaS = "", f20 = "", f3 = "", pocS = "", vahS = "", valS = "", inV = "";
      MqlRates r[];
      ArraySetAsSeries(r, false);
      int n = CopyRates(_Symbol, PERIOD_M1, to - 240 * 60, to, r);
      n = n - 1;   // exclure la bougie en formation a l'instant d'entree
      if(n >= 30)
      {
         double sumTR = 0.0;
         for(int i = n - 14; i < n; i++)
         {
            double tr = MathMax(r[i].high - r[i].low, MathMax(MathAbs(r[i].high - r[i - 1].close), MathAbs(r[i].low - r[i - 1].close)));
            sumTR += tr;
         }
         double atr = sumTR / 14.0;
         double gain = 0.0, loss = 0.0;
         for(int i = n - 14; i < n; i++)
         {
            double df = r[i].close - r[i - 1].close;
            if(df > 0.0) gain += df; else loss -= df;
         }
         double rsi = (loss <= 0.0) ? 100.0 : 100.0 - 100.0 / (1.0 + gain / loss);
         double ef = r[0].close, es = r[0].close;
         for(int i = 1; i < n; i++)
         {
            ef = r[i].close * (2.0 / 10.0) + ef * (1.0 - 2.0 / 10.0);
            es = r[i].close * (2.0 / 22.0) + es * (1.0 - 2.0 / 22.0);
         }
         atrS = LJ_D(atr, 5);
         atrP = (pxo > 0.0) ? LJ_D(atr / pxo * 100.0, 5) : "";
         rsiS = LJ_D(rsi, 1);
         if(atr > 0.0) emaS = LJ_D((ef - es) / atr, 3);
         f20 = LJ_D(LJ_FlowArr(r, n, 20), 3);
         f3  = LJ_D(LJ_FlowArr(r, n, 3), 3);
         int nv = MathMin(n, MathMax(20, VP_LookbackBars));
         MqlRates rv[];
         ArrayResize(rv, nv);
         for(int i = 0; i < nv; i++) rv[i] = r[n - nv + i];
         double poc, vah, val;
         LJ_Profile(rv, nv, poc, vah, val);
         if(atr > 0.0 && vah > val)
         {
            pocS = LJ_D((pxo - poc) / atr, 3);
            vahS = LJ_D((pxo - vah) / atr, 3);
            valS = LJ_D((pxo - val) / atr, 3);
            inV  = (pxo <= vah && pxo >= val) ? "1" : "0";
         }
      }
      MqlDateTime mt;
      TimeToStruct(to, mt);
      string line = TimeToString(to, TIME_DATE | TIME_SECONDS) + "," + TimeToString(outT[o], TIME_DATE | TIME_SECONDS) + "," +
                    LJ_Clean(_Symbol) + "," + (string)outPid[o] + "," + ((inType[ii] == DEAL_TYPE_BUY) ? "BUY" : "SELL") + "," +
                    DoubleToString(outVol[o], 2) + "," + DoubleToString(pxo, dg) + "," + DoubleToString(outPx[o], dg) + "," +
                    DoubleToString(outPr[o], 2) + "," + DoubleToString(outSw[o], 2) + "," + DoubleToString(outCmn[o], 2) + "," +
                    IntegerToString((int)(outT[o] - to)) + "," + outWhy[o] + "," + inCm[ii] + "," +
                    atrS + "," + atrP + "," + rsiS + "," + emaS + "," + f20 + "," + f3 + "," +
                    pocS + "," + vahS + "," + valS + "," + inV + "," + IntegerToString(mt.hour) + "," + IntegerToString(mt.day_of_week);
      if(LJ_AppendLine(path, head, line)) written++;
   }
   LJ_AppendLine(flag, "done_at,rows", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "," + IntegerToString(written));
   Print("[LEARN] reconstitution historique ", _Symbol, " : ", written, " trades -> ", path);
}

//--- Stats locales depuis CSV (close + hist + shadow) → chart + gate ---
struct LJ_LocalStats
{
   int      n;
   int      wins;
   int      losses;
   double   sumProfit;
   double   lastProfit;
   int      buyN;
   int      buyW;
   int      sellN;
   int      sellW;
   int      shadowN;
   int      shadowHit;
   int      shadowBuyN;
   int      shadowBuyW;
   int      shadowSellN;
   int      shadowSellW;
   double   shadowExpAtr;   // E[mfe-mae]/ATR sur les shadows (signal le plus discriminant)
   int      gateBlocks;
   int      advisorBlocks;
   datetime updated;
};
LJ_LocalStats g_ljStats;

#define LJ_EQ_MAX 64
double   g_ljEqPnL[LJ_EQ_MAX];
datetime g_ljEqTime[LJ_EQ_MAX];
int      g_ljEqN = 0;

void LJ_RefreshStats(const bool force=false);
string LJ_DashboardLine();
bool   LJ_ExpectancyAllowsEntry(const int dirSign, const string symbol = "");
bool   LJ_HardBlockedSymbol(const string symbol);
bool   LJ_JournalAdvisorAllows(const string symbol, const int dirSign);
void   LJ_RenderEquityCurve();

void LJ_Init()
{
   if(!LJ_Enable) return;
   FolderCreate(LJ_Folder);
   if(LJ_UseCommonFiles)
      FolderCreate(LJ_CommonFolder, FILE_COMMON);
   g_ljRsi  = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   g_ljEmaF = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_ljEmaS = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_ljShLast[0] = 0;
   g_ljShLast[1] = 0;
   g_ljEqN = 0;
   Print("[LEARN] journal actif | local=MQL5\\Files\\", LJ_Folder,
         " | common=", (LJ_UseCommonFiles ? ("Common\\Files\\" + LJ_CommonFolder) : "off"),
         " | ", _Symbol);
   LJ_Backfill();
   LJ_RefreshStats(true);
   LJ_RenderEquityCurve();
}

void LJ_StatsReset()
{
   ZeroMemory(g_ljStats);
}

void LJ_IngestCloseLine(const string line)
{
   // close_*: time,symbol,pos_id,side,volume,price_close,profit,...
   // hist_*:  open,close,symbol,pos_id,side,volume,open_px,close_px,profit,...
   string parts[];
   int n = StringSplit(line, ',', parts);
   if(n < 7) return;
   string side = "";
   double profit = 0.0;
   // detect format by header-less row: hist has datetime in col0 AND col1 with space/date
   bool looksHist = (n >= 9 && StringFind(parts[0], ".") >= 0 && StringFind(parts[1], ".") >= 0 &&
                     (parts[4] == "BUY" || parts[4] == "SELL"));
   if(looksHist)
   {
      side = parts[4];
      profit = StringToDouble(parts[8]);
   }
   else
   {
      side = parts[3];
      profit = StringToDouble(parts[6]);
   }
   if(side != "BUY" && side != "SELL") return;
   g_ljStats.n++;
   g_ljStats.sumProfit += profit;
   g_ljStats.lastProfit = profit;
   if(profit > 0.0) g_ljStats.wins++;
   else if(profit < 0.0) g_ljStats.losses++;
   if(side == "BUY")
   {
      g_ljStats.buyN++;
      if(profit > 0.0) g_ljStats.buyW++;
   }
   else
   {
      g_ljStats.sellN++;
      if(profit > 0.0) g_ljStats.sellW++;
   }
   // courbe equity (FIFO borné)
   if(g_ljEqN < LJ_EQ_MAX)
   {
      g_ljEqPnL[g_ljEqN] = (g_ljEqN > 0 ? g_ljEqPnL[g_ljEqN - 1] : 0.0) + profit;
      g_ljEqTime[g_ljEqN] = TimeCurrent();
      g_ljEqN++;
   }
   else
   {
      for(int i = 1; i < LJ_EQ_MAX; i++)
      {
         g_ljEqPnL[i - 1] = g_ljEqPnL[i];
         g_ljEqTime[i - 1] = g_ljEqTime[i];
      }
      g_ljEqPnL[LJ_EQ_MAX - 1] = g_ljEqPnL[LJ_EQ_MAX - 2] + profit;
      g_ljEqTime[LJ_EQ_MAX - 1] = TimeCurrent();
   }
}

void LJ_IngestShadowLine(const string line)
{
   // time,symbol,side,reason,price,atr,ret5_atr,ret15_atr,mfe_atr,mae_atr,...
   string parts[];
   int n = StringSplit(line, ',', parts);
   if(n < 10) return;
   string side = parts[2];
   double ret15 = StringToDouble(parts[7]);
   double mfe   = StringToDouble(parts[8]);
   double mae   = StringToDouble(parts[9]);
   g_ljStats.shadowN++;
   if(ret15 > 0.0) g_ljStats.shadowHit++;
   // FIX v1.57: stats par sens + expectancy ATR (le signal le plus discriminant,
   // WIN avg ret5=+1,98/ATR vs LOSS avg -1,44/ATR). Avant on ne comptait que shadowHit.
   if(side == "BUY")
   {
      g_ljStats.shadowBuyN++;
      if(mfe > mae) g_ljStats.shadowBuyW++;
   }
   else if(side == "SELL")
   {
      g_ljStats.shadowSellN++;
      if(mfe > mae) g_ljStats.shadowSellW++;
   }
   g_ljStats.shadowExpAtr += (mfe - mae);
}

void LJ_LoadCsvIntoStatsFlags(const string path, const bool isShadow, const int flags)
{
   int h = FileOpen(path, flags);
   if(h == INVALID_HANDLE) return;
   bool first = true;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(StringLen(line) == 0) continue;
      if(first)
      {
         first = false;
         if(StringFind(line, "time") == 0 || StringFind(line, "symbol") >= 0)
            continue; // header
      }
      if(isShadow) LJ_IngestShadowLine(line);
      else         LJ_IngestCloseLine(line);
   }
   FileClose(h);
}

void LJ_LoadCsvIntoStats(const string path, const bool isShadow)
{
   LJ_LoadCsvIntoStatsFlags(path, isShadow,
                            FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
}

void LJ_RefreshStats(const bool force)
{
   if(!LJ_Enable) return;
   datetime now = TimeCurrent();
   if(!force && g_ljStats.updated > 0 &&
      now - g_ljStats.updated < MathMax(15, LJ_StatsRefreshSec))
      return;

   int savedBlocks = g_ljStats.gateBlocks;
   int savedAdv    = g_ljStats.advisorBlocks;
   LJ_StatsReset();
   g_ljEqN = 0;
   g_ljStats.gateBlocks = savedBlocks;
   g_ljStats.advisorBlocks = savedAdv;

   // Priorité Common (multi-terminaux unifiés). Local en secours.
   // Ne jamais charger les deux : le miroir AppendLine doublerait les stats.
   if(LJ_UseCommonFiles)
   {
      int cf = FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON;
      LJ_LoadCsvIntoStatsFlags(LJ_CommonPath("close", _Symbol), false, cf);
      LJ_LoadCsvIntoStatsFlags(LJ_CommonPath("hist", _Symbol), false, cf);
      // FIX v1.57: les shadows sont le jeu d'apprentissage principal (7896 echantillons).
      // Avant on ne les chargeait que si g_ljStats.n==0 -> la gate voyait 3 trades reels.
      LJ_LoadCsvIntoStatsFlags(LJ_CommonPath("shadow", _Symbol), true, cf);
   }
   else
   {
      LJ_LoadCsvIntoStats(LJ_Path("close", _Symbol), false);
      LJ_LoadCsvIntoStats(LJ_Path("hist", _Symbol), false);
      LJ_LoadCsvIntoStats(LJ_Path("shadow", _Symbol), true);
   }
   g_ljStats.updated = now;
   if(LJ_ShowEquityCurve) LJ_RenderEquityCurve();
}

double LJ_WinRate()
{
   if(g_ljStats.n <= 0) return 0.0;
   return (double)g_ljStats.wins / (double)g_ljStats.n;
}

// FIX v1.57: WR sur les shadows (le jeu d'apprentissage principal, 7896 echantillons).
double LJ_ShadowWinRate()
{
   if(g_ljStats.shadowN <= 0) return 0.0;
   return (double)g_ljStats.shadowHit / (double)g_ljStats.shadowN;
}

double LJ_ExpectancyUSD()
{
   if(g_ljStats.n <= 0) return 0.0;
   return g_ljStats.sumProfit / (double)g_ljStats.n;
}

// FIX v1.57: sens prefere calcule sur les shadows (avant : buyN/sellN = 3 trades reels).
int LJ_PreferredDir()
{
   double buyWR  = (g_ljStats.shadowBuyN  > 0) ? (double)g_ljStats.shadowBuyW  / g_ljStats.shadowBuyN  : -1.0;
   double sellWR = (g_ljStats.shadowSellN > 0) ? (double)g_ljStats.shadowSellW / g_ljStats.shadowSellN : -1.0;
   if(buyWR < 0.0 && sellWR < 0.0) return 0;
   if(buyWR > sellWR) return 1;
   if(sellWR > buyWR) return -1;
   return 0;
}

string LJ_DashboardLine()
{
   if(!LJ_Enable || !LJ_ShowOnChart) return "";
   LJ_RefreshStats(false);
   if(g_ljStats.n <= 0 && g_ljStats.shadowN <= 0)
      return "LEARN: collecte (0 trade) | shadows=" + IntegerToString(g_ljStats.shadowN) +
             " | CSV=" + LJ_Folder + (LJ_UseCommonFiles ? "+Common" : "");

   double wr = LJ_WinRate() * 100.0;
   double exp = LJ_ExpectancyUSD();
   double shWR = (g_ljStats.shadowN > 0)
                 ? (100.0 * (double)g_ljStats.shadowHit / (double)g_ljStats.shadowN) : 0.0;
   int pref = LJ_PreferredDir();
   string side = (pref > 0) ? "BUY" : (pref < 0) ? "SELL" : "—";
   string gate = LJ_UseExpectancyGate
                 ? ((g_ljStats.n >= LJ_GateMinSamples) ? "GATE:ON" : "GATE:warm")
                 : "GATE:off";
   double buyWR  = (g_ljStats.buyN  > 0) ? (100.0 * g_ljStats.buyW  / g_ljStats.buyN)  : 0.0;
   double sellWR = (g_ljStats.sellN > 0) ? (100.0 * g_ljStats.sellW / g_ljStats.sellN) : 0.0;
   return StringFormat(
      "LEARN: %d tr | WR %.0f%% | PnL $%s | E $%s | last $%s | B%d/%.0f%% S%d/%.0f%% | sh %d(%.0f%%) | pref %s | %s | blk %d/%d",
      g_ljStats.n, wr,
      DoubleToString(g_ljStats.sumProfit, 2), DoubleToString(exp, 2), DoubleToString(g_ljStats.lastProfit, 2),
      g_ljStats.buyN, buyWR, g_ljStats.sellN, sellWR,
      g_ljStats.shadowN, shWR, side, gate,
      g_ljStats.gateBlocks, g_ljStats.advisorBlocks);
}

void LJ_RenderEquityCurve()
{
   if(!LJ_Enable || !LJ_ShowEquityCurve) return;
   string prefix = "LJ_EQ_" + _Symbol + "_";
   // nettoyer anciens segments
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, prefix) == 0)
         ObjectDelete(0, nm);
   }
   int n = MathMin(g_ljEqN, MathMax(2, LJ_EquityPoints));
   if(n < 2) return;

   // ancrer la courbe sous le prix courant (echelle visuelle en ATR)
   double atr = SMC_EffectiveSymbolATR(_Symbol);
   if(atr <= 0.0) atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50.0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minP = g_ljEqPnL[g_ljEqN - n], maxP = g_ljEqPnL[g_ljEqN - n];
   for(int i = g_ljEqN - n; i < g_ljEqN; i++)
   {
      if(g_ljEqPnL[i] < minP) minP = g_ljEqPnL[i];
      if(g_ljEqPnL[i] > maxP) maxP = g_ljEqPnL[i];
   }
   double span = MathMax(1.0, maxP - minP);

   datetime t1 = iTime(_Symbol, PERIOD_M1, n);
   if(t1 <= 0) t1 = TimeCurrent() - n * 60;
   for(int k = 1; k < n; k++)
   {
      int i0 = g_ljEqN - n + k - 1;
      int i1 = g_ljEqN - n + k;
      double y0 = bid - atr * 2.0 + ((g_ljEqPnL[i0] - minP) / span) * atr * 1.5;
      double y1 = bid - atr * 2.0 + ((g_ljEqPnL[i1] - minP) / span) * atr * 1.5;
      datetime ta = t1 + (k - 1) * 60;
      datetime tb = t1 + k * 60;
      string nm = prefix + IntegerToString(k);
      ObjectCreate(0, nm, OBJ_TREND, 0, ta, y0, tb, y1);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, (g_ljEqPnL[i1] >= 0.0) ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   }
   string lbl = prefix + "LBL";
   ObjectCreate(0, lbl, OBJ_TEXT, 0, TimeCurrent(), bid - atr * 2.0);
   ObjectSetString(0, lbl, OBJPROP_TEXT, "LEARN equity $" + DoubleToString(g_ljStats.sumProfit, 2));
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
}

// Consulte ai_server /journal/decision (fail-open). Utilise le CSV Common TradBOT.
bool LJ_JournalAdvisorAllows(const string symbol, const int dirSign)
{
   if(!LJ_Enable || !LJ_UseJournalAdvisor || dirSign == 0)
      return true;
   if(!UseAIServer || StringLen(AI_ServerURL) == 0)
      return true;

   static datetime s_last = 0;
   static string   s_lastKey = "";
   static bool     s_lastAllow = true;
   string side = (dirSign > 0) ? "BUY" : "SELL";
   string key = symbol + "|" + side + "|" + IntegerToString(g_smcGomVerdictNum);
   datetime now = TimeCurrent();
   if(key == s_lastKey && now - s_last < 5)
      return s_lastAllow;

   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   MqlDateTime mt; TimeGMT(mt);
   string url = AI_ServerURL + "/journal/decision?symbol=" + symbol +
                "&side=" + side +
                "&vn=" + IntegerToString(g_smcGomVerdictNum) +
                "&m1=" + m1 + "&m5=" + g_smcTfM5Dir +
                "&m15=" + g_smcTfM15Dir + "&h1=" + g_smcTfH1Dir +
                "&hour=" + IntegerToString(mt.hour);

   char post[];
   char result[];
   string headers = "";
   string resultHeaders = "";
   int res = WebRequest("GET", url, headers, MathMax(200, LJ_JournalAdvisorTimeoutMs),
                        post, result, resultHeaders);
   s_lastKey = key;
   s_last = now;
   if(res == -1 || ArraySize(result) <= 0)
   {
      s_lastAllow = true; // fail-open
      return true;
   }
   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   // parse minimal "allow": true/false
   bool allow = true;
   int p = StringFind(body, "\"allow\"");
   if(p >= 0)
   {
      int c = StringFind(body, ":", p);
      if(c > 0)
      {
         string tail = StringSubstr(body, c + 1, 20);
         StringToLower(tail);
         if(StringFind(tail, "false") >= 0) allow = false;
      }
   }
   s_lastAllow = allow;
   if(!allow)
   {
      g_ljStats.advisorBlocks++;
      static datetime s_log = 0;
      if(now - s_log >= 20)
      {
         s_log = now;
         Print("[LEARN] JOURNAL-ADVISOR VETO ", symbol, " ", side, " | ", StringSubstr(body, 0, 160));
      }
   }
   return allow;
}

// Porte d'esperance : fail-open tant que pas assez d'echantillons.
// Bloque le sens sous-performant / expectancy negative.
// FIX v1.57: la gate s'appuie SUR LES SHADOWS (7896 echantillons, le vrai jeu
// d'apprentissage) et non plus sur les 3 trades reels. Avant, g_ljStats.n=3
// bloquait la gate en warmup perpetual. On ajoute aussi un seuil d'expectancy
// en ATR (E[mfe-mae]/ATR), le signal le plus discriminant.
// FIX v1.57: hard-block des symboles a expectancy negative (ex. GainX 800 -1,456 ATR).
// Verifie le symbole courant et le symbole de la gate (peut etre hors graphique).
bool LJ_HardBlockedSymbol(const string symbol)
{
   if(StringLen(LJ_HardBlockSymbols) == 0) return false;
   string sym = symbol;
   if(StringLen(sym) == 0) sym = _Symbol;
   string tokens[];
   int n = StringSplit(LJ_HardBlockSymbols, ',', tokens);
   for(int i = 0; i < n; i++)
   {
      string t = tokens[i];
      StringTrimLeft(t); StringTrimRight(t);
      if(StringLen(t) == 0) continue;
      if(StringCompare(sym, t, true) == 0)
         return true;
   }
   return false;
}

bool LJ_ExpectancyAllowsEntry(const int dirSign, const string symbol = "")
{
   if(!LJ_Enable || dirSign == 0)
      return true;

   // FIX v1.57: hard-block des symboles a expectancy negative (ex. GainX 800 -1,456 ATR).
   // Le symbole de la gate peut etre different de _Symbol (execution hors graphique).
   if(LJ_HardBlockedSymbol(symbol))
      return false;

   // Advisor journal (Common TradBOT) — avant la gate locale
   if(!LJ_JournalAdvisorAllows(symbol, dirSign))
      return false;

   if(!LJ_UseExpectancyGate)
      return true;

   LJ_RefreshStats(false);

   // Echantillon : priorite aux shadows (apprentissage), secours aux trades reels.
   int totalN = g_ljStats.shadowN + g_ljStats.n;
   if(totalN < MathMax(5, LJ_GateMinSamples))
      return true; // warmup : laisser apprendre

   static datetime s_log = 0;
   bool doLog = (TimeCurrent() - s_log >= 30);

   // 1) Expectancy ATR globale (shadows) — seuil rentabilite
   if(g_ljStats.shadowN > 0)
   {
      double expAtr = g_ljStats.shadowExpAtr / (double)g_ljStats.shadowN;
      if(expAtr < LJ_ShadowMinExpAtr)
      {
         g_ljStats.gateBlocks++;
         if(doLog)
         {
            s_log = TimeCurrent();
            Print("[LEARN] BLOQUÉ expectancy ATR ", DoubleToString(expAtr, 3),
                  " < ", DoubleToString(LJ_ShadowMinExpAtr, 3),
                  " | shadows=", g_ljStats.shadowN, " WR=", DoubleToString(LJ_ShadowWinRate() * 100.0, 0), "%");
         }
         return false;
      }
   }

   // 2) Expectancy $ (trades reels)
   if(g_ljStats.n >= MathMax(5, LJ_GateMinSamples))
   {
      double exp = LJ_ExpectancyUSD();
      if(exp < LJ_GateMinExpectancyUSD)
      {
         g_ljStats.gateBlocks++;
         if(doLog)
         {
            s_log = TimeCurrent();
            Print("[LEARN] BLOQUÉ expectancy ", DoubleToString(exp, 2),
                  "$ < ", DoubleToString(LJ_GateMinExpectancyUSD, 2),
                  " | n=", g_ljStats.n, " WR=", DoubleToString(LJ_WinRate() * 100.0, 0), "%");
         }
         return false;
      }
   }

   // 3) Filtre par sens sur les shadows (le jeu d'apprentissage principal)
   int sideN = (dirSign > 0) ? g_ljStats.shadowBuyN : g_ljStats.shadowSellN;
   int sideW = (dirSign > 0) ? g_ljStats.shadowBuyW : g_ljStats.shadowSellW;
   if(sideN >= MathMax(8, LJ_GateMinSamples / 2))
   {
      double sideWR = (double)sideW / (double)sideN;
      if(sideWR < LJ_GateMinWinRate)
      {
         g_ljStats.gateBlocks++;
         if(doLog)
         {
            s_log = TimeCurrent();
            Print("[LEARN] BLOQUÉ sens ", (dirSign > 0 ? "BUY" : "SELL"),
                  " WR=", DoubleToString(sideWR * 100.0, 0),
                  "% < ", DoubleToString(LJ_GateMinWinRate * 100.0, 0),
                  "% | shadows=", sideN);
         }
         return false;
      }
   }

   if(LJ_PreferLearnedSide)
   {
      int pref = LJ_PreferredDir();
      if(pref != 0 && pref != dirSign)
      {
         // FIX v1.57: warmup sur shadows (pas les 3 trades reels) — sinon EnforcePreferSide
         // ne s'active jamais (buyN/sellN restent a 0/1/2).
         int prefSideN = (pref > 0) ? g_ljStats.shadowBuyN : g_ljStats.shadowSellN;
         if(LJ_EnforcePreferSide &&
            g_ljStats.shadowN >= LJ_GateMinSamples &&
            prefSideN >= MathMax(8, LJ_GateMinSamples / 2))
         {
            g_ljStats.gateBlocks++;
            if(doLog)
            {
               s_log = TimeCurrent();
               Print("[LEARN] BLOQUÉ sens oppose au pref appris=",
                     (pref > 0 ? "BUY" : "SELL"), " | demande=", (dirSign > 0 ? "BUY" : "SELL"),
                     " | shadows=", g_ljStats.shadowN);
            }
            return false;
         }
         if(doLog && TimeCurrent() - s_log >= 60)
         {
            s_log = TimeCurrent();
            Print("[LEARN] info: sens appris preferé=", (pref > 0 ? "BUY" : "SELL"),
                  " | demande=", (dirSign > 0 ? "BUY" : "SELL"));
         }
      }
   }
   return true;
}

#endif // SMC_LEARN_JOURNAL_MQH
