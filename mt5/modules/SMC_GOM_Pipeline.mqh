//+------------------------------------------------------------------+
//| SMC_GOM_Pipeline.mqh — GOM verdict + pipeline + dessins TV sync  |
//| Pattern TradeManager.mq5 (KOLA, OB setup, OTE zone)            |
//+------------------------------------------------------------------+
#ifndef SMC_GOM_PIPELINE_MQH
#define SMC_GOM_PIPELINE_MQH

#include "SMC_SignalGates.mqh"
#include "MT5_Candles_Uploader.mqh"

// inputs du .mq5 parent — déclarés extern pour compilation indépendante du .mqh
bool DisciplineAllowsPipelineAction(const string action);
bool SMCGP_GOMValidatesPrimarySignal(const int dir);
bool SMC_BCHourAllowsTrade(const string symbol = "");
bool SMC_HighProbabilityAllowsEntry(const int dirSign = 0);
bool PB_SendWhatsAppAlert(const string message);
int  SMC_ComputePropiceScore();
bool AreAllTimeframesAligned(string &direction);
extern double g_lastEntryProbability;
extern string g_lastAIAction;
extern double g_lastAIConfidence;

// RSI Squeeze / Impulse / TP1 dashboard variables (defined in SMC_Universal.mq5)
#define GOM_SIGNAL_BLINK_DURATION 2
// input variables (UseRSISqueezePredictor, TakeProfitAt1Dollar, UseCloseOnVerdictWait) are globally visible in MQL5
extern double g_dashSqueezeRSI;
extern bool   g_dashSqueezeActive;
extern bool   g_dashH1Aligned;
extern double g_impulseSupport20;
extern double g_impulseResistance20;
extern bool   g_impulseSupTouched;
extern bool   g_impulseResTouched;
extern datetime g_tp1LastCloseTime;
extern bool   g_tp1WaitingReEntry;

// ── Pure Momentum Gate ──────────────────────────────────────────────
// (inputs defined in SMC_Universal.mq5 — globally visible without extern)
int    pmRsiM1   = INVALID_HANDLE;
int    pmStochM1 = INVALID_HANDLE;

bool SMC_IsPureMomentumSymbol(const string sym)
{
   string s = sym;
   StringToUpper(s);
   return (StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0 ||
           StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0);
}

int SMC_PureMomentumScore(const int dirSign, int &pillars)
{
   pillars = 0;
   int score = 0;
   // Pillar 1: EMA alignment
   if(emaFastM1 != INVALID_HANDLE && emaSlowM1 != INVALID_HANDLE)
   {
      double emaF[], emaS[];
      ArraySetAsSeries(emaF, true);
      ArraySetAsSeries(emaS, true);
      if(CopyBuffer(emaFastM1, 0, 0, 1, emaF) > 0 && CopyBuffer(emaSlowM1, 0, 0, 1, emaS) > 0)
      {
         bool emaOk = dirSign > 0 ? (emaF[0] > emaS[0]) : (emaF[0] < emaS[0]);
         if(emaOk) score++;
         pillars++;
      }
   }
   // Pillar 2: RSI extreme
   if(pmRsiM1 != INVALID_HANDLE)
   {
      double rsiBuf[];
      ArraySetAsSeries(rsiBuf, true);
      if(CopyBuffer(pmRsiM1, 0, 0, 1, rsiBuf) > 0)
      {
         bool rsiOk = dirSign > 0 ? (rsiBuf[0] >= PureMomentumRSIBuyLevel) : (rsiBuf[0] <= PureMomentumRSISellLevel);
         if(rsiOk) score++;
         pillars++;
      }
   }
   // Pillar 3: Stochastic extreme
   if(pmStochM1 != INVALID_HANDLE)
   {
      double stochK[], stochD[];
      ArraySetAsSeries(stochK, true);
      ArraySetAsSeries(stochD, true);
      if(CopyBuffer(pmStochM1, 0, 0, 1, stochK) > 0 && CopyBuffer(pmStochM1, 1, 0, 1, stochD) > 0)
      {
         bool stochOk = dirSign > 0 ? (stochK[0] >= PureMomentumStochBuyLevel && stochK[0] > stochD[0])
                                    : (stochK[0] <= PureMomentumStochSellLevel && stochK[0] < stochD[0]);
         if(stochOk) score++;
         pillars++;
      }
   }
   // Pillar 4: HTF M5 candle
   {
      MqlRates m5Rates[];
      ArraySetAsSeries(m5Rates, true);
      if(CopyRates(_Symbol, PERIOD_M5, 0, 2, m5Rates) >= 1)
      {
         double body = m5Rates[0].close - m5Rates[0].open;
         double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double minBody = 50.0 * pointVal;
         bool htfOk = dirSign > 0 ? (body > minBody) : (body < -minBody);
         if(htfOk) score++;
         pillars++;
      }
   }
   // Pillar 5: Retracement
   {
      MqlRates m1Rates[];
      ArraySetAsSeries(m1Rates, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 6, m1Rates) >= 6)
      {
         double totalMove = 0, maxRetrace = 0;
         for(int i = 1; i <= 5; i++)
            totalMove += m1Rates[i-1].close - m1Rates[i].close;
         for(int i = 1; i <= 5; i++)
         {
            double delta = m1Rates[i-1].close - m1Rates[i].close;
            bool isRetrace = dirSign > 0 ? (delta < 0) : (delta > 0);
            if(isRetrace)
            {
               double rAmt = MathAbs(delta);
               if(rAmt > maxRetrace) maxRetrace = rAmt;
            }
         }
         double maxAllowed = MathAbs(totalMove) * PureMomentumMaxRetracePct / 100.0;
         bool retOk = (maxRetrace <= maxAllowed);
         if(retOk) score++;
         pillars++;
      }
   }
   return score;
}


bool SMCGP_IsBoomCrashSym(const string sym)
{
   string s = sym;
   StringToUpper(s);
   return (StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0 ||
           StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0);
}

MT5CandlesUploader *g_smcCandlesUploader = NULL;
datetime g_smcLastCandleUpload = 0;
// ── État GOM ───────────────────────────────────────────────────────
string   g_smcGomVerdict      = "WAIT";
int      g_smcGomVerdictNum   = 0;
int      g_smcGomVerdictReactiveNum = 0;
int      g_smcGomVerdictForecastNum = 0;
int      g_smcGomVerdictNumPrev = 999;  // 999 = pas encore armé
bool     g_smcGomForceExhausted = false; // PERFECT→GOOD : fin cycle spike Boom/Crash
datetime g_smcGomLastPerfectTime = 0;     // timestamp du dernier verdict PERFECT
string   g_smcGomVerdictPrev  = "";
string   g_smcGomVerdictServer   = "WAIT";  // verdict serveur avant overlay correction
int      g_smcGomVerdictNumServer = 0;
bool     g_smcGomCorrectionWait  = false;    // true = affichage/trading en WAIT (correction)
string   g_smcGomCorrectionReason = "";
bool     g_smcGomServerCorrWait    = false;  // correction_wait=true du serveur (dernier poll)
datetime g_smcGomCorrectionResumeUntil = 0;  // fenêtre MARKET après fin correction WAIT
bool     g_smcGomNotifReady     = false;
double   g_smcGomQuality      = 0.0;
double   g_smcGomCoherence    = 0.0;
double   g_smcGomKolaBuy      = 0.0;
double   g_smcGomKolaSell     = 0.0;
string   g_smcGomKolaState    = "";
string   g_smcGomGlobalDir    = "";
int      g_smcGomGlobalStr    = 0;
bool     g_smcGomConnected    = false;
double   g_iaStatusConfidence = 0.0;  // IA Status confiance (0-100%)
string   g_smcIAStatusAction  = "HOLD"; // IA Status action depuis dashboard GOM (BUY/SELL/HOLD)
double   g_smcCorrExhaustPct  = 0.0;  // Correction exhaustion 0-100 (>70 = safe)
string   g_smcCorrPhase       = "unknown"; // trending|correcting|exhausted|resuming|ranging
string   g_smcCorrType        = "";        // trend_run|micro_pullback|m5_pullback|...
bool     g_smcCorrEntrySafe   = false; // true = correction terminée, re-entrée safe
bool     g_smcM1EntryBlocked  = false; // gate M1 correction (serveur)
bool     g_smcActiveCorrection = false;
string   g_smcM1EntryReason   = "";
// Seuils blocage correction (configurés depuis SMC_Universal OnInit)
double   g_smcCorrBlockDefault    = 45.0;
double   g_smcCorrBlockTrending   = 35.0;
double   g_smcCorrBlockCorrecting = 45.0;
double   g_smcCorrBlockExhausted  = 40.0;
double   g_smcCorrBlockRanging    = 38.0;
double   g_smcCorrGomRelaxPts     = 10.0;  // assouplissement si |vn|>=2
double   g_smcEntryProbabilityPct = 0.0;   // probabilité entrée composite (ai_server)
bool     g_pathTrailBonusActive   = false; // trailing bonus path concordance
datetime g_smcLastGOMPoll     = 0;  // dernier poll RÉUSSI (HTTP 200 + données valides)
datetime g_smcLastGOMAttempt  = 0;  // dernière TENTATIVE (succès ou échec)
datetime g_smcLastMCPPoll      = 0;
datetime g_smcLastPipelineExec= 0;
string   g_smcLastPipelineId  = "";
datetime g_smcLastPipelineFail= 0;
string   g_smcFailedPipelineId= "";
int      g_smcPipelineFailCount = 0;

// ── Failover serveur IA (local → Render) pour tout le pipeline GOM ─────
int      g_smcGomFailCount  = 0;     // échecs consécutifs sur le serveur actif
bool     g_smcGomUseRender  = false;  // true = on bascule sur AI_ServerRender
int      g_smcGomFailThreshold = 2;  // nb d'échecs avant bascule
datetime g_smcGomLastBascule = 0;   // anti-oscillation : délais avant revenir local

string SMCGP_ActiveServerURL()
{
   if(g_smcGomUseRender && StringLen(AI_ServerRender) > 0)
      return AI_ServerRender;
   return AI_ServerURL;
}

void SMCGP_MarkResult(bool ok)
{
   if(ok)
   {
      g_smcGomFailCount = 0;
      // Si on était sur Render et que ça fait longtemps que tout va bien, on peut revenir au local
      if(g_smcGomUseRender && g_smcGomLastBascule > 0 && (TimeCurrent() - g_smcGomLastBascule) > 600)
         g_smcGomUseRender = false; // retour progressif au local (ré-évalué au prochain échec)
      return;
   }
   g_smcGomFailCount++;
   if(!g_smcGomUseRender && g_smcGomFailCount >= g_smcGomFailThreshold && StringLen(AI_ServerRender) > 0)
   {
      g_smcGomUseRender = true;
      g_smcGomLastBascule = TimeCurrent();
      Print("[GOM-FAILOVER] ⚠️ Bascule vers Render (", AI_ServerRender, ") après ", g_smcGomFailCount, " échecs locaux");
   }
   else if(g_smcGomUseRender && g_smcGomFailCount >= g_smcGomFailThreshold)
   {
      // Render aussi en échec : on repasse local pour réessayer le cycle
      g_smcGomUseRender = false;
      g_smcGomLastBascule = TimeCurrent();
      g_smcGomFailCount = 0;
      Print("[GOM-FAILOVER] ⚠️ Render aussi en échec, retour local");
   }
}

// ── Cache verdict GOM par symbole ──────────────────────────────────────
#define GOM_CACHE_MAX 64
string   g_gomCacheSym[GOM_CACHE_MAX];
int      g_gomCacheVn[GOM_CACHE_MAX];
string   g_gomCacheVerdict[GOM_CACHE_MAX];
datetime g_gomCacheTime[GOM_CACHE_MAX];
int      g_gomCacheCount = 0;

void SMCGP_CacheVerdict(const string symbol, int vn, const string &verdict)
{
   string sym = symbol;
   StringToUpper(sym);
   for(int i = 0; i < g_gomCacheCount; i++)
   {
      if(g_gomCacheSym[i] == sym)
      {
         g_gomCacheVn[i] = vn;
         g_gomCacheVerdict[i] = verdict;
         g_gomCacheTime[i] = TimeCurrent();
         return;
      }
   }
   if(g_gomCacheCount < GOM_CACHE_MAX)
   {
      g_gomCacheSym[g_gomCacheCount] = sym;
      g_gomCacheVn[g_gomCacheCount] = vn;
      g_gomCacheVerdict[g_gomCacheCount] = verdict;
      g_gomCacheTime[g_gomCacheCount] = TimeCurrent();
      g_gomCacheCount++;
   }
}

int SMCGP_GetCachedVerdictNum(const string symbol)
{
   string sym = symbol;
   StringToUpper(sym);
   for(int i = 0; i < g_gomCacheCount; i++)
   {
      if(g_gomCacheSym[i] == sym)
      {
         if(TimeCurrent() - g_gomCacheTime[i] > 120) return -999;
         return g_gomCacheVn[i];
      }
   }
   return -999;
}

// ── ENFORCEMENT: supprimer les LIMIT contre-tendance + max 2 par symbole ──
// À appeler périodiquement (OnTick / OnTimer)
void SMCGP_EnforceLimitDiscipline(const long magic, const int maxLimits = 2)
{
   // Ne PAS exiger g_smcGomConnected : sous WAIT (vn=0) on doit annuler les LIMIT
   // même si le serveur GOM est temporairement down. Le cache conserve le dernier
   // verdict connu. On ne touche pas si le verdict est inconnu (vn=-999).
   if(!g_smcGomConnected && g_smcLastGOMPoll > 0 && TimeCurrent() - g_smcLastGOMPoll > 900)
      return; // déconnexion > 15 min + cache périmé → on ne risque pas d'annuler à tort

   // 1) Supprimer les ordres LIMIT qui vont contre le verdict en cache
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

       string sym = OrderGetString(ORDER_SYMBOL);
       // Ne jamais toucher aux ordres LIMIT DOW (ancrés sur DOW PROJ)
       string cmt = OrderGetString(ORDER_COMMENT);
       if(StringFind(cmt, "DOW") >= 0)
          continue;

       // Grâce discipline LIMIT (3-5 min) — ne pas supprimer un LIMIT trop jeune
       if(!LimitCancelAllowed(ticket, false, "EnforceLimitDiscipline"))
          continue;

       int vn = SMCGP_GetCachedVerdictNum(sym);
       // Fallback: si le cache est inconnu/périmé, utiliser le verdict GLOBAL.
       // Sous WAIT global (vn=0) on ANNULE les LIMIT non-DOW (après délai min).
       if(vn == -999) vn = (sym == _Symbol) ? g_smcGomVerdictNum : 0;

       bool isBuyLimit = (t == ORDER_TYPE_BUY_LIMIT);
      // Ordres contraires Boom/Gainx (SELL) et Crash/Painx (BUY) — suppression immédiate
      string dirStr = isBuyLimit ? "BUY" : "SELL";
      if(!IsDirectionAllowedForBoomCrash(sym, dirStr))
      {
         LimitSafeOrderDelete(ticket, true, "contre-tendance Boom/Crash " + dirStr);
         continue;
      }
      // WAIT / SIMPLE (|vn|<2) : annuler les limits non-DOW (après délai min)
      bool waitOrWeak = (vn == 0 || MathAbs(vn) < 2);
      bool against = (isBuyLimit && vn < 0) || (!isBuyLimit && vn > 0);
      if(waitOrWeak || against)
      {
         string why = waitOrWeak ? "WAIT/WEAK" : "contre-tendance";
         LimitSafeOrderDelete(ticket, false,
                              why + " GOM vn=" + IntegerToString(vn) + " " + sym);
      }
   }

   // 2) Limiter à maxLimits ordres LIMIT par symbole
   struct LimInf { ulong ticket; double price; datetime tm; };
   string syms[]; int symCnt = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;
      string sym = OrderGetString(ORDER_SYMBOL);
      bool found = false;
      for(int s = 0; s < symCnt; s++) if(syms[s] == sym) { found = true; break; }
      if(!found) { ArrayResize(syms, symCnt + 1); syms[symCnt] = sym; symCnt++; }
   }
   for(int s = 0; s < symCnt; s++)
   {
      LimInf arr[]; int cnt = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
         ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;
         if(OrderGetString(ORDER_SYMBOL) != syms[s]) continue;
         // Ne jamais compter/supprimer un LIMIT DOW comme excédentaire
         if(StringFind(OrderGetString(ORDER_COMMENT), "DOW") >= 0) continue;
         int sz = cnt++; ArrayResize(arr, sz + 1);
         arr[sz].ticket = ticket;
         arr[sz].price  = OrderGetDouble(ORDER_PRICE_OPEN);
         arr[sz].tm     = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      }
      int excess = cnt - maxLimits;
      if(excess <= 0) continue;
      // Trier : supprimer les plus éloignés du prix d'abord (les plus vieux/lointains)
      int digits = (int)SymbolInfoInteger(syms[s], SYMBOL_DIGITS);
      double cur = SymbolInfoDouble(syms[s], SYMBOL_BID);
      for(int a = 0; a < cnt - 1; a++)
         for(int b = a + 1; b < cnt; b++)
         {
            double da = MathAbs(arr[a].price - cur);
            double db = MathAbs(arr[b].price - cur);
            if(da > db) { LimInf tmp = arr[a]; arr[a] = arr[b]; arr[b] = tmp; }
         }
      for(int k = 0; k < excess; k++)
      {
         LimitSafeOrderDelete(arr[k].ticket, false,
                              "LIMIT excédentaire sym=" + syms[s]);
      }
   }

   // 3) Plafond terminal: max MaxLimitOrdersTerminal LIMIT pending (tout symbole confondu)
   int termTotal = CountOpenLimitOrdersTerminal();
   int termExcess = termTotal - MaxLimitOrdersTerminal;
   if(termExcess > 0)
   {
      struct TermLim { ulong ticket; double price; string sym; datetime tm; };
      TermLim tarr[]; int tcnt = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if((long)OrderGetInteger(ORDER_MAGIC) != magic) continue;
         ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;
         if(!LimitCancelAllowed(ticket, false, "terminal excess")) continue;
         int sz = tcnt++; ArrayResize(tarr, sz + 1);
         tarr[sz].ticket = ticket;
         tarr[sz].price  = OrderGetDouble(ORDER_PRICE_OPEN);
         tarr[sz].sym    = OrderGetString(ORDER_SYMBOL);
         tarr[sz].tm     = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      }
      for(int a = 0; a < tcnt - 1; a++)
         for(int b = a + 1; b < tcnt; b++)
         {
            double curA = SymbolInfoDouble(tarr[a].sym, SYMBOL_BID);
            double curB = SymbolInfoDouble(tarr[b].sym, SYMBOL_BID);
            double da = (curA > 0) ? MathAbs(tarr[a].price - curA) : (double)tarr[a].tm;
            double db = (curB > 0) ? MathAbs(tarr[b].price - curB) : (double)tarr[b].tm;
            if(da > db) { TermLim tmp = tarr[a]; tarr[a] = tarr[b]; tarr[b] = tmp; }
         }
      for(int k = 0; k < termExcess && k < tcnt; k++)
      {
         LimitSafeOrderDelete(tarr[k].ticket, false, "LIMIT terminal excédentaire");
      }
   }
}
string   g_smcGomSource       = "OFF";
string   g_smcDashPrefix      = "SMC_DASH_";  // suffixé ChartID() dans SMCGP_Init()
double   g_smcGomScoreBuy     = 0.0;
double   g_smcGomScoreSell    = 0.0;
int      g_smcGomRsi          = 50;
double   g_smcGomPrice        = 0.0;
double   g_smcGomSpikePct     = 0.0;
int      g_smcGomSpikeLevel   = 0;
int      g_smcGomSpikeLevelPrev = -1;
double   g_smcGomImminencePct = 0.0;
double   g_smcPreSpikePct     = 0.0;
bool     g_smcGomSpikeTradable = false;
bool     g_smcGomSpikeTradablePrev = false;
double   g_smcGomSpikeProgressPct = 0.0;
int      g_smcGomBarsSinceSpike = 0;
int      g_smcGomSpikeFreqBars  = 0;
// Heures UTC Boom/Crash (bc_heure — enrichi par ai_server)
int      g_smcBcHourUtc         = -1;
double   g_smcBcConfidence      = 0.0;
bool     g_smcBcTradeable       = true;
string   g_smcBcSession         = "";
string   g_smcBcRating          = "";
string   g_smcBcWindowStart     = "";
string   g_smcBcWindowEnd       = "";
string   g_smcBcMappedKey       = "";
bool     g_smcSpikeNotifReady   = false;

// ── Price Action Zone (MA50/MA200) ─────────────────────────────────
string   g_smcPaTrend         = "UNKNOWN";
bool     g_smcPaInCorrection  = false;
bool     g_smcPaConsolidation = false;
double   g_smcPaMa50          = 0.0;
double   g_smcPaMa200         = 0.0;
double   g_smcPaRsi           = 0.0;
double   g_smcPaZoneSupport   = 0.0;
double   g_smcPaZoneResistance= 0.0;
double   g_smcPaCorrDepthPct  = 0.0;
bool     g_smcPaPriceInZone   = false;

// ── TradingView bias / score ──────────────────────────────────────
string   g_smcTvBias           = "";
double   g_smcTvScore          = 0.0;
string   g_smcTvEntryStrength  = "";
double   g_smcTvEntryRR        = 0.0;

void SMCGP_ConfigureCorrectionGate(const double blockDefault, const double blockTrending,
                                 const double blockCorrecting, const double blockExhausted,
                                 const double blockRanging, const double gomRelaxPts)
{
   g_smcCorrBlockDefault    = blockDefault;
   g_smcCorrBlockTrending   = blockTrending;
   g_smcCorrBlockCorrecting = blockCorrecting;
   g_smcCorrBlockExhausted  = blockExhausted;
   g_smcCorrBlockRanging    = blockRanging;
   g_smcCorrGomRelaxPts     = gomRelaxPts;
}

double SMCGP_CorrectionBlockThreshold(const string phase = "")
{
   string p = (StringLen(phase) > 0) ? phase : g_smcCorrPhase;
   if(p == "trending")   return g_smcCorrBlockTrending;
   if(p == "correcting") return g_smcCorrBlockCorrecting;
   if(p == "exhausted")  return g_smcCorrBlockExhausted;
   if(p == "resuming")   return MathMin(g_smcCorrBlockExhausted, 30.0);
   if(p == "ranging")    return g_smcCorrBlockRanging;
   return g_smcCorrBlockDefault;
}

bool SMCGP_CorrectionBlocksEntry(const bool isBoomCrash = false)
{
   if(g_smcCorrEntrySafe) return false;

   // FX Vol Weltrade : scalp continu en GOOD/PERFECT — micro-correction = opportunité
   if(SMC_IsWeltradeVolSymbol(_Symbol))
   {
      int vn = (MathAbs(g_smcGomVerdictNumServer) >= 2) ? g_smcGomVerdictNumServer : g_smcGomVerdictNum;
      if(MathAbs(vn) >= 2) return false;
   }

   double thresh = SMCGP_CorrectionBlockThreshold();
   if(MathAbs(g_smcGomVerdictNum) >= 2 && !isBoomCrash)
      thresh -= g_smcCorrGomRelaxPts;
   if(thresh < 22.0) thresh = 22.0;

   // Boom/Crash : pas de gate serveur sur trend_run, mais blocage si pullback profond
   if(isBoomCrash)
   {
      if(g_smcCorrType == "counter_move" || g_smcCorrType == "m15_pullback")
         thresh = MathMax(thresh, 52.0);
      else if(g_smcCorrType == "m5_pullback")
         thresh = MathMax(thresh, 48.0);
      else if(StringLen(g_smcCorrType) == 0)
         return false;
      else if(g_smcCorrType == "trend_run" || g_smcCorrType == "micro_pullback")
         return false;
   }

   return (g_smcCorrExhaustPct < thresh);
}

string SMCGP_CorrectionBlockReason(const bool isBoomCrash = false)
{
   if(!SMCGP_CorrectionBlocksEntry(isBoomCrash))
      return "";
   double thresh = SMCGP_CorrectionBlockThreshold();
   if(MathAbs(g_smcGomVerdictNum) >= 2)
      thresh -= g_smcCorrGomRelaxPts;
   if(thresh < 22.0) thresh = 22.0;
   return StringFormat("correction %s %s %.0f%% < seuil %.0f%%",
                       g_smcCorrType, g_smcCorrPhase, g_smcCorrExhaustPct, thresh);
}

int SMCGP_TfDirToSign(const string tfDir)
{
   string d = tfDir;
   StringToUpper(d);
   if(d == "BULL" || d == "BUY") return 1;
   if(d == "BEAR" || d == "SELL") return -1;
   return 0;
}

bool SMCGP_LiveMicroCorrectionAgainstVerdict(const string symbol, const int verdictNum)
{
   if(verdictNum == 0) return false;
   int tradeDir = (verdictNum > 0) ? 1 : -1;
   bool strongVerdict = (MathAbs(verdictNum) >= 2);

   // ── EARLY EXIT: Si M1+M5 sont d'accord avec la direction du trade, ignorer les micro-pullbacks ──
   // Le trend macro prime sur le bruit M1. Pas de blocage si le momentum HTF est aligné.
   {
      int m1s = SMCGP_TfDirToSign(g_smcTfM1Dir);
      int m5s = SMCGP_TfDirToSign(g_smcTfM5Dir);
      if(m1s == tradeDir && m5s == tradeDir)
         return false;
      // Même si seulement M5 est aligné et verdict strong, pas de blocage
      if(strongVerdict && m5s == tradeDir)
         return false;
   }

   int oppBars = 0;
   for(int i = 0; i <= 5; i++)
   {
      double o = iOpen(symbol, PERIOD_M1, i);
      double c = iClose(symbol, PERIOD_M1, i);
      if(o <= 0 || c <= 0) continue;
      if(tradeDir < 0 && c > o) oppBars++;
      if(tradeDir > 0 && c < o) oppBars++;
   }

   double c0 = iClose(symbol, PERIOD_M1, 0);
   double c1 = iClose(symbol, PERIOD_M1, 1);
   double c4 = iClose(symbol, PERIOD_M1, 4);
   double o0 = iOpen(symbol, PERIOD_M1, 0);
   double netMove = (c0 > 0 && c4 > 0) ? (c0 - c4) : 0.0;
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atr = 0.0;
   int m1AtrH = iATR(symbol, PERIOD_M1, 14);
   if(m1AtrH != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(m1AtrH, 0, 0, 1, atrBuf) > 0)
         atr = atrBuf[0];
      IndicatorRelease(m1AtrH);
   }
   double minMove = (atr > 0) ? atr * 0.08 : ((pt > 0) ? pt * 6 : 0.0);
   if(minMove <= 0 && pt > 0) minMove = pt * 6;

   // Bougie courante déjà contre le verdict → correction immédiate
   if(o0 > 0 && c0 > 0)
   {
      if(tradeDir > 0 && c0 < o0) return true;
      if(tradeDir < 0 && c0 > o0) return true;
   }

   // Séquence de closes montants/descendants = correction visible
   if(tradeDir < 0 && c0 > 0 && c1 > 0 && c4 > 0 && c0 > c1 && c1 > c4)
      return true;
   if(tradeDir > 0 && c0 > 0 && c1 > 0 && c4 > 0 && c0 < c1 && c1 < c4)
      return true;

   // PERFECT (|vn|≥3) : 1 bougie opposée suffit pour lever le doute
   bool isPerfect = (MathAbs(verdictNum) >= 3);
   if(tradeDir < 0)
   {
      int needOpp = isPerfect ? 1 : (strongVerdict ? 2 : 3);
      if(oppBars >= needOpp && netMove > minMove) return true;
      if(oppBars >= 2 && netMove > minMove * 0.5) return true;
   }
   else
   {
      int needOpp = isPerfect ? 1 : (strongVerdict ? 2 : 3);
      if(oppBars >= needOpp && netMove < -minMove) return true;
      if(oppBars >= 2 && netMove < -minMove * 0.5) return true;
   }

   int m1s = SMCGP_TfDirToSign(g_smcTfM1Dir);
   int m5s = SMCGP_TfDirToSign(g_smcTfM5Dir);

   // NB: M1+M5 agreement check already handled at function entry (early exit)
   // If we reach here, M1 or M5 disagree with trade direction

   if(tradeDir < 0 && m1s > 0 && m5s > 0) return true;
   if(tradeDir > 0 && m1s < 0 && m5s < 0) return true;
   if(tradeDir < 0 && m1s > 0 && oppBars >= 2) return true;
   if(tradeDir > 0 && m1s < 0 && oppBars >= 2) return true;

   return false;
}

bool SMCGP_VerdictWaitOnCorrectionCycle(const int serverVn)
{
   if(serverVn == 0) return false;

   if(g_smcM1EntryBlocked)
   {
      g_smcGomCorrectionReason = (StringLen(g_smcM1EntryReason) > 0)
                                 ? g_smcM1EntryReason : "M1 correction active";
      return true;
   }

   if(g_smcActiveCorrection)
   {
      string phase = g_smcCorrPhase;
      StringToLower(phase);
      if(phase == "correcting" || phase == "ranging")
      {
         g_smcGomCorrectionReason = StringFormat("correction %s (%s)",
                                                 g_smcCorrType, g_smcCorrPhase);
         return true;
      }
   }

   string ctype = g_smcCorrType;
   StringToLower(ctype);
   if(ctype == "micro_pullback" || ctype == "m5_pullback" || ctype == "counter_move")
   {
      string phase2 = g_smcCorrPhase;
      StringToLower(phase2);
      if(phase2 == "correcting")
      {
         g_smcGomCorrectionReason = StringFormat("phase correcting (%s)", g_smcCorrType);
         return true;
      }
   }

   // Seuil verdict WAIT sans assouplissement PERFECT (contrairement à CorrectionBlocksEntry)
   if(!g_smcCorrEntrySafe)
   {
      double thresh = SMCGP_CorrectionBlockThreshold();
      if(thresh > 40.0) thresh = 40.0;
      if(g_smcCorrExhaustPct < thresh)
      {
         g_smcGomCorrectionReason = StringFormat("correction %.0f%% < %.0f%%",
                                                 g_smcCorrExhaustPct, thresh);
         return true;
      }
   }

   return false;
}

bool SMCGP_ShouldForceWaitOnCorrection(const string symbol)
{
   int vn = g_smcGomVerdictNumServer;
   if(vn == 0) return false;

   // FX Vol : le verdict GOM GOOD/PERFECT prime — ne pas forcer WAIT sur micro-correction M1
   if(SMC_IsWeltradeVolSymbol(symbol) && MathAbs(vn) >= 2)
      return false;

   if(g_smcPaInCorrection && !g_smcCorrEntrySafe)
   {
      g_smcGomCorrectionReason = "PA correction";
      return true;
   }

   if(SMCGP_VerdictWaitOnCorrectionCycle(vn))
      return true;

   if(SMCGP_LiveMicroCorrectionAgainstVerdict(symbol, vn))
   {
      g_smcGomCorrectionReason = "M1 pullback live";
      return true;
   }

   return false;
}

void SMCGP_ArmCorrectionResumeWindow(const int sec = 90)
{
   g_smcGomCorrectionResumeUntil = TimeCurrent() + MathMax(15, sec);
}

bool SMCGP_IsCorrectionResumeWindow()
{
   return (g_smcGomCorrectionResumeUntil > 0 && TimeCurrent() < g_smcGomCorrectionResumeUntil);
}

void SMCGP_RefreshCorrectionWaitOverlay(const string symbol)
{
   if(g_smcGomVerdictNumServer == 0 && !g_smcGomServerCorrWait) return;

   bool clientWait = SMCGP_ShouldForceWaitOnCorrection(symbol);
   bool shouldWait = g_smcGomServerCorrWait || clientWait;

   // FX Vol GOOD/PERFECT : ne jamais écraser le verdict serveur par WAIT correction
   if(SMC_IsWeltradeVolSymbol(symbol) && MathAbs(g_smcGomVerdictNumServer) >= 2)
      shouldWait = false;

   bool wasWait = g_smcGomCorrectionWait;

   if(shouldWait)
   {
      if(!g_smcGomCorrectionWait)
      {
         static datetime s_log = 0;
         if(TimeCurrent() - s_log >= 15)
         {
            s_log = TimeCurrent();
            Print("[GOM-CORR-WAIT] ", symbol, " ", g_smcGomVerdictServer,
                  " (vn=", g_smcGomVerdictNumServer, ") → WAIT | ",
                  g_smcGomCorrectionReason,
                  " | srv=", (g_smcGomServerCorrWait ? "Y" : "N"),
                  " cli=", (clientWait ? "Y" : "N"),
                  " | M1=", g_smcTfM1Dir, " M5=", g_smcTfM5Dir);
         }
      }
      g_smcGomCorrectionWait = true;
      g_smcGomVerdictNum = 0;
      g_smcGomVerdict = "WAIT";
      g_smcGomCorrectionResumeUntil = 0;
      return;
   }

   if(wasWait)
   {
      g_smcGomCorrectionWait = false;
      g_smcGomCorrectionReason = "";
      g_smcGomVerdictNum = g_smcGomVerdictNumServer;
      g_smcGomVerdict = g_smcGomVerdictServer;
      SMCGP_ArmCorrectionResumeWindow(90);
      Print("[GOM-CORR-RESUME] ", symbol, " ", g_smcGomVerdict,
            " (vn=", g_smcGomVerdictNum, ") — fenêtre exécution 90s");
   }
}

void SMCGP_ApplyCorrectionVerdictWait(const string symbol, const bool serverFlag = false)
{
   if(serverFlag && StringLen(g_smcGomCorrectionReason) == 0)
      g_smcGomCorrectionReason = "serveur correction";
   SMCGP_RefreshCorrectionWaitOverlay(symbol);
}
string   g_smcTfM1Dir         = "";
string   g_smcTfM5Dir         = "";
string   g_smcTfM15Dir        = "";
string   g_smcTfH1Dir         = "";
string   g_smcTfH4Dir         = "";
string   g_smcTfD1Dir         = "";
int      g_smcTfM1Rsi         = 0;
int      g_smcTfM5Rsi         = 0;
int      g_smcTfM15Rsi        = 0;
int      g_smcTfH1Rsi         = 0;
int      g_smcTfH4Rsi         = 0;
int      g_smcTfD1Rsi         = 0;
double   g_smcGhostDelta      = 0.0;
double   g_smcGhostCVD        = 0.0;
double   g_smcGhostBuyPct     = 50.0;
double   g_smcGhostCompass    = 0.0;
string   g_smcPredPath        = "";
int      g_smcLastHttpCode    = 0;
string   g_smcServerUrl       = "";

// OTE zone (Optimal Trade Entry — Fibonacci 61.8%–78.6% du swing HH/LL)
double   g_smcOteTop          = 0.0;
double   g_smcOteBot          = 0.0;
bool     g_smcInOTE           = false;
int      g_smcOteDir          = 0;

// Setup TV (OB ICT)
bool     g_smcSetupValid      = false;
int      g_smcSetupDir        = 0;
double   g_smcSetupEntry      = 0.0;
double   g_smcSetupSL         = 0.0;
double   g_smcSetupTP1        = 0.0;
double   g_smcSetupTP2        = 0.0;
double   g_smcSetupRR         = 0.0;
string   g_smcSetupType       = "";
string   g_smcSetupConfirm    = "";

// Bollinger + OB synchronisés TradingView
double   g_smcBbUp            = 0.0;
double   g_smcBbMid           = 0.0;
double   g_smcBbDn            = 0.0;
double   g_smcObBullTop       = 0.0;
double   g_smcObBullBot       = 0.0;
double   g_smcObBearTop       = 0.0;
double   g_smcObBearBot       = 0.0;
datetime g_smcObBullTime      = 0;
datetime g_smcObBearTime      = 0;

// Prédictions Bollinger Bands (300 bougies)
double   g_smcPredBbMid[]     = {};
double   g_smcPredBbUp[]      = {};
double   g_smcPredBbDn[]      = {};

// Cognition forecast 200 bougies (ai_server)
double   g_cogStrength        = 0.0;
double   g_cogConfidence      = 0.0;
string   g_cogDirection       = "NEUTRAL";
string   g_cogDirection5m     = "NEUTRAL";
string   g_cogDirection15m    = "NEUTRAL";
double   g_cogSlope5m         = 0.0;
double   g_cogSlope15m        = 0.0;
double   g_cogShortConfidence = 0.0;
#ifndef G_PATH_CONCORDANCE_PCT_DEFINED
double   g_pathConcordancePct  = 0.0;
#define G_PATH_CONCORDANCE_PCT_DEFINED
#endif
int      g_pipelineEma9Handle = INVALID_HANDLE;  // EMA9 M1 pour re-entrées scalp pipeline
int      g_pipelineEma200Handle = INVALID_HANDLE; // EMA200 M5 pour tendance long terme
string   g_cogRegime          = "";
double   g_smcPredPathMid[]   = {};
double   g_smcPredPathUp[]    = {};
double   g_smcPredPathDn[]    = {};
double   g_smcCogOpen[]       = {};
double   g_smcCogHigh[]       = {};
double   g_smcCogLow[]        = {};
double   g_smcCogClose[]      = {};
double   g_smcCogQ10[]        = {};
double   g_smcCogQ90[]        = {};

// ── JSON helpers ───────────────────────────────────────────────────
double SMCGP_JsonDouble(const string &body, const string key, double def = 0.0)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return def;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   string sub = StringSubstr(body, pos, 40);
   for(int i = 0; i < StringLen(sub); i++)
   {
      ushort c = StringGetCharacter(sub, i);
      if(c == ',' || c == '}' || c == ' ' || c == '\n' || c == '\r')
      { sub = StringSubstr(sub, 0, i); break; }
   }
   return StringToDouble(sub);
}

string SMCGP_JsonString(const string &body, const string key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(body, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = StringFind(body, "\"", pos);
   if(end < 0) return "";
   return StringSubstr(body, pos, end - pos);
}

bool SMCGP_JsonBool(const string &body, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return false;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   return (StringGetCharacter(body, pos) == 't');
}

// Parse un tableau JSON d'entiers "[7, 8, 13]" ou pretty-print avec newlines → "7,8,13"
string SMCGP_ParseIntArray(const string &body, const string key)
{
   string search = "\"" + key + "\"";
   int pos = StringFind(body, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   // Avancer jusqu'au '['
   int len = StringLen(body);
   while(pos < len && StringGetCharacter(body, pos) != '[') pos++;
   if(pos >= len) return "";
   pos++; // sauter '['
   // Lire jusqu'au ']', extraire les chiffres séparés par virgule
   string result = "";
   string token  = "";
   while(pos < len)
   {
      ushort ch = StringGetCharacter(body, pos);
      if(ch == ']')
      {
         if(StringLen(token) > 0)
            result += (StringLen(result) > 0 ? "," : "") + token;
         break;
      }
      if(ch >= '0' && ch <= '9')
         token += ShortToString(ch);
      else if(ch == ',' && StringLen(token) > 0)
      {
         result += (StringLen(result) > 0 ? "," : "") + token;
         token = "";
      }
      pos++;
   }
   return result;
}

string SMCGP_ChartTfLabel()
{
   switch(_Period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      default:         return "M15";
   }
}

string SMCGP_EncodeSym(const string sym)
{
   string enc = sym;
   StringReplace(enc, " ", "%20");
   return enc;
}

string SMCGP_ResolveGOMSym(const string sym)
{
   if(sym == "XAUEUR" || sym == "GOLD" || sym == "OR") return "XAUUSD";
   // Garder le symbole exact du graphique (Boom 1000, Crash 300, Volatility 75, etc.)
   if(StringFind(sym, "Index") >= 0) return sym;
   return sym;
}

bool SMCGP_HttpPost(const string path, const string &jsonBody, int timeoutMs = 3000)
{
   string url = SMCGP_ActiveServerURL() + path;
   char post[], result[];
   StringToCharArray(jsonBody, post, 0, WHOLE_ARRAY, CP_UTF8);
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("POST", url, headers, timeoutMs, post, result, respH);
   g_smcLastHttpCode = code;
   bool ok = (code == 200 || code == 201);
   if(ok) SMCGP_MarkResult(true);
   else   SMCGP_MarkResult(false);
   return ok;
}

//+------------------------------------------------------------------+
//| HTTP POST avec retour du corps de réponse                         |
//+------------------------------------------------------------------+
bool SMCGP_HttpPostWithResponse(const string path, const string &jsonBody, string &bodyOut, int timeoutMs = 5000)
{
   bodyOut = "";
   string url = SMCGP_ActiveServerURL() + path;
   char post[], result[];
   StringToCharArray(jsonBody, post, 0, WHOLE_ARRAY, CP_UTF8);
   string headers = "Content-Type: application/json\r\n";
   string respH;
   g_smcLastHttpCode = 0;
   int code = WebRequest("POST", url, headers, timeoutMs, post, result, respH);
   g_smcLastHttpCode = code;
   if(code != 200)
   {
      SMCGP_MarkResult(false);
      return false;
   }
   bodyOut = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   SMCGP_MarkResult(true);
   return true;
}

void SMCGP_SendHeartbeat()
{
   if(!GOMSyncSymbolToTV) return;
   if(!UseGOMPipeline && !UseGOMVerdictFilter && !ShowGOMDashboard) return;
   static datetime s_lastHb = 0;
   if(TimeCurrent() - s_lastHb < 10) return;
   s_lastHb = TimeCurrent();

   string sym = SMCGP_ResolveGOMSym(_Symbol);
   string symJson = sym;
   StringReplace(symJson, "\\", "\\\\");
   StringReplace(symJson, "\"", "\\\"");
   string chartTf = SMCGP_ChartTfLabel();
   string body = StringFormat(
      "{\"symbol\":\"%s\",\"ea\":\"SMC_Universal\",\"magic\":%d,\"chart_id\":\"%I64d\",\"chart_tf\":\"%s\"}",
      symJson, InpMagicNumber, ChartID(), chartTf);
   SMCGP_HttpPost("/mt5/ea-heartbeat", body, AI_Timeout_ms);
}

string SMCGP_JsonEscape(const string s)
{
   string out = s;
   StringReplace(out, "\\", "\\\\");
   StringReplace(out, "\"", "\\\"");
   return out;
}

string SMCGP_BuildMarketWatchSymbolsJson(const int maxSyms = 80)
{
   string json = "[";
   int n = 0;
   int total = SymbolsTotal(true);
   for(int i = 0; i < total && n < maxSyms; i++)
   {
      string s = SymbolName(i, true);
      if(s == "") continue;
      if(n > 0) json += ",";
      json += "\"" + SMCGP_JsonEscape(s) + "\"";
      n++;
   }
   json += "]";
   return json;
}

void SMCGP_SendDashboardLive(const bool forceNow = false)
{
   if(!UseAIServer) return;
   if(!MT5DashboardSync()) return;
   static datetime s_lastLive = 0;
   if(!forceNow && TimeCurrent() - s_lastLive < 15) return;
   s_lastLive = TimeCurrent();

   string sym = SMCGP_ResolveGOMSym(_Symbol);
   string symJson = SMCGP_JsonEscape(sym);
   string chartTf = SMCGP_ChartTfLabel();

   long login = (long)AccountInfoInteger(ACCOUNT_LOGIN);
   string server = AccountInfoString(ACCOUNT_SERVER);
   string name = AccountInfoString(ACCOUNT_NAME);
   string company = AccountInfoString(ACCOUNT_COMPANY);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin  = AccountInfoDouble(ACCOUNT_MARGIN);
   double marginFree = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);

   string posJson = "[";
   int posCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(posCount > 0) posJson += ",";
      string pSym = SMCGP_JsonEscape(PositionGetString(POSITION_SYMBOL));
      string pType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      string pComment = SMCGP_JsonEscape(PositionGetString(POSITION_COMMENT));
      double pProfit = PositionGetDouble(POSITION_PROFIT)
                     + PositionGetDouble(POSITION_SWAP);
      posJson += StringFormat(
         "{\"ticket\":%I64u,\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.2f,"
         "\"price_open\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"profit\":%.2f,\"magic\":%d,\"comment\":\"%s\"}",
         ticket, pSym, pType, PositionGetDouble(POSITION_VOLUME),
         PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP),
         pProfit, (int)PositionGetInteger(POSITION_MAGIC), pComment);
      posCount++;
   }
   posJson += "]";

   string watchJson = SMCGP_BuildMarketWatchSymbolsJson(80);

   string body = StringFormat(
      "{\"symbol\":\"%s\",\"ea\":\"SMC_Universal\",\"magic\":%d,\"chart_id\":\"%I64d\",\"chart_tf\":\"%s\","
      "\"terminal_id\":\"%I64d\",\"symbols_watch\":%s,"
      "\"account\":{\"login\":%I64d,\"server\":\"%s\",\"name\":\"%s\","
      "\"company\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"margin\":%.2f,\"margin_free\":%.2f,"
      "\"profit\":%.2f,\"currency\":\"%s\",\"leverage\":%d},\"positions\":%s}",
      symJson, InpMagicNumber, ChartID(), chartTf, ChartID(), watchJson,
      login, SMCGP_JsonEscape(server), SMCGP_JsonEscape(name), SMCGP_JsonEscape(company),
      balance, equity, margin, marginFree, profit, SMCGP_JsonEscape(currency), leverage, posJson);

   if(SMCGP_HttpPost("/mt5/live-snapshot", body, AI_Timeout_ms))
   {
      static datetime s_lastOk = 0;
      if(TimeCurrent() - s_lastOk >= 120)
      {
         s_lastOk = TimeCurrent();
         Print("[MT5-DASH] Live snapshot OK | ", sym, " | balance=", DoubleToString(balance, 2),
               " | positions=", posCount);
      }
   }
   else
   {
      static datetime s_lastFail = 0;
      if(TimeCurrent() - s_lastFail >= 60)
      {
         s_lastFail = TimeCurrent();
         Print("[MT5-DASH] ECHEC HTTP ", g_smcLastHttpCode, " -> ", AI_ServerURL, "/mt5/live-snapshot");
         if(g_smcLastHttpCode == -1)
            Print("[MT5-DASH] Autoriser WebRequest pour ", AI_ServerURL, " dans MT5 > Options > Expert Advisors");
      }
   }
}

void SMCGP_PollServerLossGuard()
{
   if(!UseAIServer) return;
   static datetime s_lastPoll = 0;
   if((int)(TimeCurrent() - s_lastPoll) < 2) return;
   s_lastPoll = TimeCurrent();

   string path = "/mt5/loss-guard?terminal_id=" + IntegerToString((long)ChartID());
   string body;
   if(!SMCGP_HttpGet(path, body, AI_Timeout_ms)) return;
   if(!SMCGP_JsonBool(body, "ok")) return;

   int pos = StringFind(body, "\"actions\":[");
   if(pos < 0) return;
   int end = StringFind(body, "]", pos);
   if(end <= pos) return;
   string arr = StringSubstr(body, pos + 11, end - pos - 11);
   if(StringLen(arr) < 3) return;

   int start = 0;
   while(true)
   {
      int objStart = StringFind(arr, "{", start);
      if(objStart < 0) break;
      int objEnd = StringFind(arr, "}", objStart);
      if(objEnd < 0) break;
      string obj = StringSubstr(arr, objStart, objEnd - objStart + 1);

      string ticketStr = SMCGP_JsonString(obj, "ticket");
      string symClose = SMCGP_JsonString(obj, "symbol");
      string reason = SMCGP_JsonString(obj, "reason");
      if(StringLen(reason) == 0) reason = "LOSS-GUARD server emergency";
      ulong ticket = (ulong)StringToInteger(ticketStr);

      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if((long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionCloseWithLog(ticket, reason, true))
            {
               string ackBody = StringFormat(
                  "{\"terminal_id\":\"%I64d\",\"ticket\":\"%s\",\"symbol\":\"%s\"}",
                  ChartID(), ticketStr, SMCGP_JsonEscape(symClose));
               char post[], result[];
               string respH;
               string ackUrl = SMCGP_ActiveServerURL() + "/mt5/loss-guard/ack";
               StringToCharArray(ackBody, post, 0, WHOLE_ARRAY, CP_UTF8);
               ArrayResize(post, ArraySize(post) - 1);
               WebRequest("POST", ackUrl, "Content-Type: application/json\r\n", AI_Timeout_ms, post, result, respH);
            }
         }
      }

      start = objEnd + 1;
   }
}

bool SMCGP_HttpGet(const string path, string &bodyOut, int timeoutMs = 5000)
{
   bodyOut = "";
   g_smcServerUrl = SMCGP_ActiveServerURL() + path;
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("GET", g_smcServerUrl, headers, timeoutMs, post, result, respH);
   g_smcLastHttpCode = code;
   if(code != 200)
   {
      SMCGP_MarkResult(false);
      if(code == -1)
      {
         static datetime s_lastHttpHint = 0;
         if(TimeCurrent() - s_lastHttpHint >= 60)
         {
            s_lastHttpHint = TimeCurrent();
            int err = GetLastError();
            Print("[GOM-HTTP] WebRequest echoue (code -1, err=", err, ") url=", g_smcServerUrl);
            Print("[GOM-HTTP] MT5 > Outils > Options > Expert Advisors > autoriser WebRequest pour: ",
                  AI_ServerURL, " ET ", AI_ServerRender);
            Print("[GOM-HTTP] Verifier aussi que ai_server tourne (start_ai_server.bat)");
         }
      }
      return false;
   }
   bodyOut = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   SMCGP_MarkResult(true);
   return true;
}

int SMCGP_GOMTradeDirection()
{
   if(g_smcGomVerdictNum >= 2) return 1;
   if(g_smcGomVerdictNum <= -2) return -1;
   return 0;
}

int SMCGP_GOMPerfectDirection()
{
   if(g_smcGomVerdictNum >= 3) return 1;
   if(g_smcGomVerdictNum <= -3) return -1;
   return 0;
}

int SMCGP_GOMGoodDirection()
{
   if(g_smcGomVerdictNum == 2) return 1;
   if(g_smcGomVerdictNum == -2) return -1;
   return 0;
}

int SMCGP_GOMSimpleDirection()
{
   if(g_smcGomVerdictNum == 1) return 1;
   if(g_smcGomVerdictNum == -1) return -1;
   return 0;
}

bool SMCGP_IsPerfectVerdict(const int vnum)
{
   return (vnum >= 3 || vnum <= -3);
}

bool SMCGP_IsGoodVerdict(const int vnum)
{
   return (vnum == 2 || vnum == -2);
}

bool SMCGP_IsSimpleVerdict(const int vnum)
{
   return (vnum == 1 || vnum == -1);
}

bool SMCGP_IsGOMCorrectionExit(const int prevVn, const int curVn)
{
   if(MathAbs(prevVn) != 2) return false;
   if(curVn == 0) return true;
   if(MathAbs(curVn) < 2) return true;
   if((prevVn > 0 && curVn < 0) || (prevVn < 0 && curVn > 0)) return true;
   return false;
}

bool SMCGP_IsGOMForceExhausted(const int prevVn, const int curVn)
{
   return ((prevVn == 3 && curVn == 2) || (prevVn == -3 && curVn == -2));
}

bool SMCGP_GOMSpikeReentryAllowed()
{
   if(!g_smcGomForceExhausted) return true;
   if(SMCGP_IsPerfectVerdict(g_smcGomVerdictNum)) return true;
   // Allow re-entry if PERFECT was seen within last 30s (catches brief PERFECT windows)
   if(g_smcGomLastPerfectTime > 0 && (int)(TimeCurrent() - g_smcGomLastPerfectTime) < 30) return true;
   return false;
}

double SMCGP_GetGOMOBLimitPrice(const int dir)
{
   if(dir == 1 && g_smcObBullBot > 0 && g_smcObBullTop > 0)
      return MathMin(g_smcObBullBot, g_smcObBullTop);
   if(dir == -1 && g_smcObBearTop > 0 && g_smcObBearBot > 0)
      return MathMax(g_smcObBearTop, g_smcObBearBot);
   if(g_smcSetupValid && g_smcSetupEntry > 0 && g_smcSetupDir == dir)
      return g_smcSetupEntry;
   return 0.0;
}

bool SMCGP_IsGOMManagedComment(const string comment)
{
   if(StringFind(comment, "GOM_LIMIT") >= 0) return true;
   if(StringFind(comment, "GOM_GOOD") >= 0) return true;
   if(StringFind(comment, "GOM_PERFECT") >= 0) return true;
   if(StringFind(comment, "GOM_GP") >= 0) return true;
   if(StringFind(comment, "GOM_PATTERN") >= 0) return true;
   if(StringFind(comment, "GOM_ALIGN") >= 0) return true;
   if(StringFind(comment, "GOM_STAIR") >= 0) return true;
   return false;
}

string SMCGP_JsonTfDir(const string &body, const string key)
{
   string s = SMCGP_JsonString(body, key);
   if(StringLen(s) > 0)
   {
      StringToUpper(s);
      if(s == "1" || s == "BUY" || s == "LONG") return "BULL";
      if(s == "-1" || s == "SELL" || s == "SHORT") return "BEAR";
      if(s == "0" || s == "NEUT" || s == "NEUTRAL") return "NEUT";
      if(s == "BULL" || s == "BEAR") return s;
      return SMCGP_JsonString(body, key);
   }
   double n = SMCGP_JsonDouble(body, key, -999.0);
   if(n == 1.0) return "BULL";
   if(n == -1.0) return "BEAR";
   if(n == 0.0) return "NEUT";
   return "";
}

// Direction cognition effective — consensus 5m + 15m (prioritaire pour gates)
string SMCGP_EffectiveCogDirection()
{
   if(StringLen(g_cogDirection5m) > 0 && g_cogDirection5m != "NEUTRAL")
   {
      if(StringLen(g_cogDirection15m) > 0 && g_cogDirection15m != "NEUTRAL")
      {
         if(g_cogDirection5m == g_cogDirection15m)
            return g_cogDirection5m;
         return "NEUTRAL";
      }
      return g_cogDirection5m;
   }
   if(StringLen(g_cogDirection15m) > 0 && g_cogDirection15m != "NEUTRAL")
      return g_cogDirection15m;
   return g_cogDirection;
}

double SMCGP_ParseNestedConcordancePct(const string &body)
{
   int p = StringFind(body, "\"path_concordance\"");
   if(p < 0) return 0.0;
   int objStart = StringFind(body, "{", p);
   if(objStart < 0) return 0.0;
   int depth = 0;
   int objEnd = -1;
   for(int i = objStart; i < StringLen(body); i++)
   {
      ushort ch = StringGetCharacter(body, i);
      if(ch == '{') depth++;
      else if(ch == '}')
      {
         depth--;
         if(depth == 0) { objEnd = i; break; }
      }
   }
   if(objEnd <= objStart) return 0.0;
   string obj = StringSubstr(body, objStart, objEnd - objStart + 1);
   return SMCGP_JsonDouble(obj, "concordance_pct");
}

double SMCGP_EstimateConcordanceLocal()
{
   int n = ArraySize(g_smcPredPathMid);
   if(n < 10) return 0.0;

   int posDir = 0;
   if(g_smcGomVerdictNum >= 2) posDir = 1;
   else if(g_smcGomVerdictNum <= -2) posDir = -1;
   if(posDir == 0)
   {
      string cog = SMCGP_EffectiveCogDirection();
      if(cog == "BUY") posDir = 1;
      else if(cog == "SELL") posDir = -1;
   }
   if(posDir == 0) return 0.0;

   int aligned = 0, total = 0;
   int look = MathMin(n - 1, 60);
   for(int i = 1; i <= look; i++)
   {
      double d = g_smcPredPathMid[i] - g_smcPredPathMid[i - 1];
      if(MathAbs(d) <= 0.0) continue;
      total++;
      if(posDir > 0 && d > 0) aligned++;
      else if(posDir < 0 && d < 0) aligned++;
   }
   if(total <= 0) return 0.0;
   return (double)aligned * 100.0 / (double)total;
}

void SMCGP_SyncVerdictFromMTF(const string &body)
{
   string gate = SMCGP_JsonString(body, "gate");
   if(StringFind(gate, "weltrade") >= 0) return;
   if(g_smcGomVerdictNum != 0) return;

   double gap = MathAbs(g_smcGomScoreBuy - g_smcGomScoreSell);
   if(gap < 0.25) return;

   if(g_smcTfM1Dir == "BULL" && g_smcTfM5Dir == "BULL" && g_smcTfM15Dir == "BULL"
      && g_smcGomScoreBuy >= g_smcGomScoreSell)
   {
      g_smcGomVerdictNum = (gap >= 2.5) ? 2 : 1;
      g_smcGomVerdict = (g_smcGomVerdictNum == 2) ? "GOOD BUY" : "BUY";
      return;
   }
   if(g_smcTfM1Dir == "BEAR" && g_smcTfM5Dir == "BEAR" && g_smcTfM15Dir == "BEAR"
      && g_smcGomScoreSell >= g_smcGomScoreBuy)
   {
      g_smcGomVerdictNum = (gap >= 2.5) ? -2 : -1;
      g_smcGomVerdict = (g_smcGomVerdictNum == -2) ? "GOOD SELL" : "SELL";
      return;
   }

   int bulls = 0, bears = 0;
   if(g_smcTfM1Dir == "BULL") bulls++; else if(g_smcTfM1Dir == "BEAR") bears++;
   if(g_smcTfM5Dir == "BULL") bulls++; else if(g_smcTfM5Dir == "BEAR") bears++;
   if(g_smcTfM15Dir == "BULL") bulls++; else if(g_smcTfM15Dir == "BEAR") bears++;

   if(bulls >= 2 && g_smcGomGlobalDir == "BULL" && g_smcGomScoreBuy > g_smcGomScoreSell && gap >= 0.45)
   {
      g_smcGomVerdictNum = (gap >= 2.5) ? 2 : 1;
      g_smcGomVerdict = (g_smcGomVerdictNum == 2) ? "GOOD BUY" : "BUY";
   }
   if(bears >= 2 && g_smcGomGlobalDir == "BEAR" && g_smcGomScoreSell > g_smcGomScoreBuy && gap >= 0.45)
   {
      g_smcGomVerdictNum = (gap >= 2.5) ? -2 : -1;
      g_smcGomVerdict = (g_smcGomVerdictNum == -2) ? "GOOD SELL" : "SELL";
   }

   static datetime s_mtfSyncLog = 0;
   if(g_smcGomVerdictNum != 0 && TimeCurrent() - s_mtfSyncLog >= 30)
   {
      s_mtfSyncLog = TimeCurrent();
      Print("[GOM-MTF-SYNC] Verdict aligné MTF: ", g_smcGomVerdict,
            " (vn=", g_smcGomVerdictNum, " gap=", DoubleToString(gap, 2),
            " M1=", g_smcTfM1Dir, " M5=", g_smcTfM5Dir, " M15=", g_smcTfM15Dir, ")");
   }
}

void SMCGP_ReconcileOrderBlocks(const string symbol);

void SMCGP_ParseGOMBody(const string &body)
{
   string vmode = SMCGP_JsonString(body, "verdict_mode");
   bool predictiveBlend = (vmode == "predictive_blend");

   g_smcGomVerdict      = SMCGP_JsonString(body, "verdict");
   g_smcGomVerdictNum   = (int)SMCGP_JsonDouble(body, "verdict_num");

   if(predictiveBlend)
   {
      g_smcGomVerdictReactiveNum = (int)SMCGP_JsonDouble(body, "verdict_reactive_num", 0);
      g_smcGomVerdictForecastNum = (int)SMCGP_JsonDouble(body, "forecast_verdict_num", 0);
      int effVn = (int)SMCGP_JsonDouble(body, "effective_verdict_num", g_smcGomVerdictNum);
      string effV = SMCGP_JsonString(body, "effective_verdict");
      g_smcGomVerdictNum = effVn;
      if(StringLen(effV) > 0) g_smcGomVerdict = effV;
   }
   else
   {
      g_smcGomVerdictReactiveNum = g_smcGomVerdictNum;
      g_smcGomVerdictForecastNum = 0;
   }
   g_smcGomQuality      = SMCGP_JsonDouble(body, "entry_quality");
   g_smcGomCoherence    = SMCGP_JsonDouble(body, "coherence_pct");
   g_smcGomScoreBuy     = SMCGP_JsonDouble(body, "score_buy");
   g_smcGomScoreSell    = SMCGP_JsonDouble(body, "score_sell");
   g_smcGomKolaBuy      = SMCGP_JsonDouble(body, "kola_buy");
   g_smcGomKolaSell     = SMCGP_JsonDouble(body, "kola_sell");
   g_smcGomKolaState    = SMCGP_JsonString(body, "kola_state");
   g_smcGomGlobalDir    = SMCGP_JsonTfDir(body, "tf_global_dir");
   g_smcGomGlobalStr    = (int)SMCGP_JsonDouble(body, "tf_global_strength");
   g_smcGomRsi          = (int)SMCGP_JsonDouble(body, "rsi");
   g_smcGomPrice        = SMCGP_JsonDouble(body, "price");
   g_smcGomSpikePct     = SMCGP_JsonDouble(body, "spike_pct");
   g_smcGomSpikeLevel   = (int)SMCGP_JsonDouble(body, "spike_level");
   g_smcGomImminencePct = SMCGP_JsonDouble(body, "imminence_pct");
   g_smcPreSpikePct     = SMCGP_JsonDouble(body, "pre_spike_pct");
   g_smcGomSpikeProgressPct = SMCGP_JsonDouble(body, "spike_progress_pct");
   g_smcGomBarsSinceSpike = (int)SMCGP_JsonDouble(body, "bars_since_spike");
   g_smcGomSpikeFreqBars  = (int)SMCGP_JsonDouble(body, "spike_freq_bars");
   g_smcGomSpikeTradable  = SMCGP_JsonBool(body, "spike_tradable");
   if(!g_smcGomSpikeTradable && SMCGP_JsonDouble(body, "spike_tradable", -1.0) >= 1.0)
      g_smcGomSpikeTradable = true;
   g_smcBbUp            = SMCGP_JsonDouble(body, "bb_up");
   g_smcBbMid           = SMCGP_JsonDouble(body, "bb_mid");
   g_smcBbDn            = SMCGP_JsonDouble(body, "bb_dn");
   g_smcObBullTop       = SMCGP_JsonDouble(body, "ob_bull_top");
   g_smcObBullBot       = SMCGP_JsonDouble(body, "ob_bull_bot");
   g_smcObBearTop       = SMCGP_JsonDouble(body, "ob_bear_top");
   g_smcObBearBot       = SMCGP_JsonDouble(body, "ob_bear_bot");
   SMCGP_ReconcileOrderBlocks(_Symbol);
   // OTE zone
   g_smcOteTop          = SMCGP_JsonDouble(body, "ote_top");
   g_smcOteBot          = SMCGP_JsonDouble(body, "ote_bot");
   g_smcOteDir          = (int)SMCGP_JsonDouble(body, "ote_dir");
   string inOteStr      = SMCGP_JsonString(body, "in_ote");
   g_smcInOTE           = (inOteStr == "true" || inOteStr == "1");
   g_smcPredPath        = SMCGP_JsonString(body, "pred_path");
   if(g_smcGomPrice <= 0) g_smcGomPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Parser les prédictions Bollinger Bands (arrays JSON)
   SMCGP_ParsePredictionArrays(body);
   SMCGP_ParseCognitionArrays(body);

   if(ShowCognitionPath)
      SMCFP_DrawFromGlobals();
   else
      SMCFP_Clear();

   g_smcTfM1Dir  = SMCGP_JsonTfDir(body, "tf_m1_dir");
   g_smcTfM5Dir  = SMCGP_JsonTfDir(body, "tf_m5_dir");
   g_smcTfM15Dir = SMCGP_JsonTfDir(body, "tf_m15_dir");
   g_smcTfH1Dir  = SMCGP_JsonTfDir(body, "tf_h1_dir");
   g_smcTfH4Dir  = SMCGP_JsonTfDir(body, "tf_h4_dir");
   g_smcTfD1Dir  = SMCGP_JsonTfDir(body, "tf_d1_dir");
   g_smcTfM1Rsi  = (int)SMCGP_JsonDouble(body, "tf_m1_rsi");
   g_smcTfM5Rsi  = (int)SMCGP_JsonDouble(body, "tf_m5_rsi");
   g_smcTfM15Rsi = (int)SMCGP_JsonDouble(body, "tf_m15_rsi");
   g_smcTfH1Rsi  = (int)SMCGP_JsonDouble(body, "tf_h1_rsi");
   g_smcTfH4Rsi  = (int)SMCGP_JsonDouble(body, "tf_h4_rsi");
   g_smcTfD1Rsi  = (int)SMCGP_JsonDouble(body, "tf_d1_rsi");

   double gDelta = SMCGP_JsonDouble(body, "ghost_delta", -99999);
   double gCvd   = SMCGP_JsonDouble(body, "ghost_cvd", -99999);
   double gBuy   = SMCGP_JsonDouble(body, "ghost_buypct", -1);
   double gCmp   = SMCGP_JsonDouble(body, "ghost_compass", -1);
   if(gDelta > -99999) g_smcGhostDelta = gDelta;
   if(gCvd   > -99999) g_smcGhostCVD   = gCvd;
   if(gBuy   >= 0)     g_smcGhostBuyPct = gBuy;
   if(gCmp   >= 0)     g_smcGhostCompass = gCmp;

   g_smcBcHourUtc     = (int)SMCGP_JsonDouble(body, "bc_hour_utc", -1.0);
   g_smcBcConfidence  = SMCGP_JsonDouble(body, "bc_confidence");
   g_smcBcTradeable   = SMCGP_JsonBool(body, "bc_tradeable");
   if(!g_smcBcTradeable && SMCGP_JsonDouble(body, "bc_tradeable", -1.0) >= 1.0)
      g_smcBcTradeable = true;
   g_smcBcSession     = SMCGP_JsonString(body, "bc_session");
   g_smcBcRating      = SMCGP_JsonString(body, "bc_rating");
   g_smcBcWindowStart = SMCGP_JsonString(body, "bc_window_start");
   g_smcBcWindowEnd   = SMCGP_JsonString(body, "bc_window_end");
   g_smcBcMappedKey   = SMCGP_JsonString(body, "bc_mapped_key");

   g_cogDirection   = SMCGP_JsonString(body, "cog_direction");
   string d5 = SMCGP_JsonString(body, "cog_direction_5m");
   if(StringLen(d5) > 0) g_cogDirection5m = d5;
   string d15 = SMCGP_JsonString(body, "cog_direction_15m");
   if(StringLen(d15) > 0) g_cogDirection15m = d15;
   g_cogSlope5m      = SMCGP_JsonDouble(body, "cog_slope_5m");
   g_cogSlope15m     = SMCGP_JsonDouble(body, "cog_slope_15m");
   g_cogShortConfidence = SMCGP_JsonDouble(body, "cog_short_confidence");
   if(g_cogShortConfidence > 1.0) g_cogShortConfidence /= 100.0;
   double shortConfPct = SMCGP_JsonDouble(body, "cog_short_confidence_pct");
   if(shortConfPct > 0.0) g_cogShortConfidence = shortConfPct / 100.0;
   string effCog = SMCGP_EffectiveCogDirection();
   if(StringLen(effCog) > 0 && effCog != "NEUTRAL")
      g_cogDirection = effCog;
   else if(StringLen(g_cogDirection) == 0)
      g_cogDirection = effCog;
   g_cogRegime      = SMCGP_JsonString(body, "cog_regime");
   g_cogStrength    = SMCGP_JsonDouble(body, "cog_strength");
   if(g_cogStrength > 1.0) g_cogStrength /= 100.0;
   double strPct = SMCGP_JsonDouble(body, "cog_strength_pct");
   if(strPct > 0.0) g_cogStrength = strPct / 100.0;
   g_cogConfidence  = SMCGP_JsonDouble(body, "cog_confidence");
   if(g_cogConfidence > 1.0) g_cogConfidence /= 100.0;
   double confPct = SMCGP_JsonDouble(body, "cog_confidence_pct");
   if(confPct > 0.0)
      g_cogConfidence = confPct / 100.0;
   else if(g_cogConfidence <= 0.0 && g_cogShortConfidence > 0.0)
      g_cogConfidence = g_cogShortConfidence;
   g_pathConcordancePct = SMCGP_JsonDouble(body, "path_concordance_pct");
   if(g_pathConcordancePct <= 0.0)
      g_pathConcordancePct = SMCGP_ParseNestedConcordancePct(body);
   if(g_pathConcordancePct <= 0.0)
   {
      int concPos = StringFind(body, "\"concordance_pct\"");
      if(concPos >= 0)
         g_pathConcordancePct = SMCGP_JsonDouble(body, "concordance_pct");
   }
   if(g_pathConcordancePct <= 0.0)
      g_pathConcordancePct = SMCGP_EstimateConcordanceLocal();

   g_smcEntryProbabilityPct = SMCGP_JsonDouble(body, "entry_probability");

   // IA Status depuis dashboard (ia_status_action + ia_status_confidence_pct)
   string iaAct = SMCGP_JsonString(body, "ia_status_action");
   StringToUpper(iaAct);
   if(StringLen(iaAct) > 0)
      g_smcIAStatusAction = iaAct;
   else
      g_smcIAStatusAction = "HOLD";
   double iaCfPct = SMCGP_JsonDouble(body, "ia_status_confidence_pct", 0.0);
   if(iaCfPct > 0.0)
      g_iaStatusConfidence = iaCfPct;

   // Correction Cycle Detector
   g_smcCorrExhaustPct = SMCGP_JsonDouble(body, "correction_exhaustion_pct", 50.0);
   g_smcCorrPhase      = SMCGP_JsonString(body, "correction_phase");
   g_smcCorrType       = SMCGP_JsonString(body, "correction_type");
   string safeStr      = SMCGP_JsonString(body, "correction_entry_safe");
   g_smcCorrEntrySafe  = (safeStr == "true" || safeStr == "1" || SMCGP_JsonBool(body, "correction_entry_safe"));
   g_smcM1EntryBlocked = SMCGP_JsonBool(body, "m1_entry_blocked");
   g_smcActiveCorrection = SMCGP_JsonBool(body, "active_correction");
   g_smcM1EntryReason = SMCGP_JsonString(body, "m1_entry_reason");

    // Price Action Zone (MA50/MA200) depuis ai_server
    string paTrend = SMCGP_JsonString(body, "pa_trend");
    if(StringLen(paTrend) > 0) g_smcPaTrend = paTrend;
    g_smcPaInCorrection  = SMCGP_JsonBool(body, "pa_in_correction");
    g_smcPaConsolidation = SMCGP_JsonBool(body, "pa_consolidation");
    double paMa50  = SMCGP_JsonDouble(body, "pa_ma50", -1.0);
    if(paMa50 > 0)  g_smcPaMa50  = paMa50;
    double paMa200 = SMCGP_JsonDouble(body, "pa_ma200", -1.0);
    if(paMa200 > 0) g_smcPaMa200 = paMa200;
    double paRsi   = SMCGP_JsonDouble(body, "pa_rsi", -1.0);
    if(paRsi >= 0)  g_smcPaRsi   = paRsi;
    double paSup   = SMCGP_JsonDouble(body, "pa_zone_support", -1.0);
    if(paSup > 0)   g_smcPaZoneSupport    = paSup;
    double paRes   = SMCGP_JsonDouble(body, "pa_zone_resistance", -1.0);
    if(paRes > 0)   g_smcPaZoneResistance = paRes;
    double paDepth = SMCGP_JsonDouble(body, "pa_corr_depth_pct", -1.0);
    if(paDepth >= 0) g_smcPaCorrDepthPct  = paDepth;

    // TradingView bias / score depuis ai_server
    string tvBias = SMCGP_JsonString(body, "tv_bias");
    if(StringLen(tvBias) > 0) g_smcTvBias = tvBias;
    double tvSc = SMCGP_JsonDouble(body, "tv_score", -1.0);
    if(tvSc >= 0) g_smcTvScore = tvSc;
    string tvStr = SMCGP_JsonString(body, "tv_entry_strength");
    if(StringLen(tvStr) > 0) g_smcTvEntryStrength = tvStr;
    double tvRR = SMCGP_JsonDouble(body, "tv_entry_rr", -1.0);
   if(tvRR >= 0) g_smcTvEntryRR = tvRR;

   // Verdict prédictif calculé côté serveur (blend réactif + forecast 5 M1, latch anti-repaint)
   // SMCGP_SyncVerdictFromMTF désactivé — évite double uplift client qui simule du repaint

   if(StringLen(g_smcGomKolaState) == 0)
   {
      if(StringFind(body, "NEAR BUY") >= 0)  g_smcGomKolaState = "NEAR BUY";
      else if(StringFind(body, "NEAR SELL") >= 0) g_smcGomKolaState = "NEAR SELL";
      else g_smcGomKolaState = "---";
   }

   bool hasData = (StringLen(g_smcGomVerdict) > 0);
   g_smcGomConnected = (g_smcLastHttpCode == 200) && hasData;
   string src = SMCGP_JsonString(body, "data_source");
   if(StringLen(src) == 0) src = SMCGP_JsonString(body, "source");
   if(StringLen(src) == 0) src = "MT5";
   g_smcGomSource = g_smcGomConnected ? src : "OFF";

   if(ShowTVSyncedLevels || ShowGOMDashboard)
      SMCGP_ParseSetupFromGOM(body);

   bool serverCorrWait = SMCGP_JsonBool(body, "correction_wait");
   g_smcGomServerCorrWait = serverCorrWait;
   string serverCorrReason = SMCGP_JsonString(body, "correction_wait_reason");
   if(StringLen(serverCorrReason) > 0)
      g_smcGomCorrectionReason = serverCorrReason;

   int srvVn = (int)SMCGP_JsonDouble(body, "verdict_server_num", 0);
   string srvTxt = SMCGP_JsonString(body, "verdict_server");
   if(srvVn != 0)
   {
      g_smcGomVerdictNumServer = srvVn;
      if(StringLen(srvTxt) > 0) g_smcGomVerdictServer = srvTxt;
   }
   else if(g_smcGomVerdictNum != 0)
   {
      g_smcGomVerdictNumServer = g_smcGomVerdictNum;
      g_smcGomVerdictServer = g_smcGomVerdict;
   }

   SMCGP_ApplyCorrectionVerdictWait(_Symbol, serverCorrWait);
}

void SMCGP_InvalidateGOM()
{
   g_smcGomConnected  = false;
   g_smcGomVerdict    = "WAIT";
   g_smcGomVerdictNum = 0;
   g_smcSetupValid    = false;
   g_smcGomSource     = "OFF";
   // Reset no-repaint signal state
   g_gomCommittedSignal = SIGNAL_NONE;
   g_gomCommittedDir    = 0;
   g_gomConfirmCount    = 0;
   g_gomCommittedTime   = 0;
}

void SMCGP_ValidateSetup()
{
   g_smcSetupValid = (g_smcSetupDir != 0 && g_smcSetupEntry > 0 && g_smcSetupSL > 0 && g_smcSetupTP1 > 0);
   if(!g_smcSetupValid) return;
   if(g_smcSetupDir == 1 && !(g_smcSetupSL < g_smcSetupEntry && g_smcSetupTP1 > g_smcSetupEntry))
      g_smcSetupValid = false;
   if(g_smcSetupDir == -1 && !(g_smcSetupSL > g_smcSetupEntry && g_smcSetupTP1 < g_smcSetupEntry))
      g_smcSetupValid = false;
}

void SMCGP_InferSetupFromGOM(const string &body)
{
   double sb = SMCGP_JsonDouble(body, "score_buy");
   double ss = SMCGP_JsonDouble(body, "score_sell");
   double gap = SMCGP_JsonDouble(body, "verdict_gap");
   if(gap <= 0) gap = MathAbs(sb - ss);
   double kolaBuy  = SMCGP_JsonDouble(body, "kola_buy");
   double kolaSell = SMCGP_JsonDouble(body, "kola_sell");
   double bbUp = SMCGP_JsonDouble(body, "bb_up");
   double bbDn = SMCGP_JsonDouble(body, "bb_dn");
   double price = SMCGP_JsonDouble(body, "price");
   if(price <= 0) price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrEst = price * 0.0012;

   if(sb >= ss && gap >= 0.3 && kolaBuy > 0)
   {
      g_smcSetupDir   = 1;
      g_smcSetupType  = "OB_BULL";
      double entryCand = kolaBuy;
      if(bbUp > 0 && bbUp < price - price * 0.00005)
         entryCand = bbUp;
      else if(bbDn > 0 && bbDn < price)
         entryCand = MathMax(bbDn, kolaBuy);
      if(g_smcObBullTop > 0 && g_smcObBullTop < price)
         entryCand = MathMin(entryCand, g_smcObBullTop);
      g_smcSetupEntry = MathMin(entryCand, price - atrEst * 0.08);
      if(g_smcSetupEntry <= 0 || g_smcSetupEntry >= price) g_smcSetupEntry = kolaBuy;
      g_smcSetupSL  = (g_smcObBullBot > 0) ? g_smcObBullBot - atrEst * 0.12 : kolaBuy - atrEst * 0.12;
      double risk   = g_smcSetupEntry - g_smcSetupSL;
      if(risk <= price * 0.00005) return;
      g_smcSetupTP1 = g_smcSetupEntry + risk;
      g_smcSetupTP2 = g_smcSetupEntry + risk * 1.5;
      g_smcSetupRR  = 1.0;
   }
   else if(ss > sb && gap >= 0.3 && kolaSell > 0)
   {
      g_smcSetupDir   = -1;
      g_smcSetupType  = "OB_BEAR";
      double entryCandS = kolaSell;
      if(bbDn > 0 && bbDn > price + price * 0.00005)
         entryCandS = bbDn;
      else if(bbUp > 0 && bbUp > price)
         entryCandS = MathMin(bbUp, kolaSell);
      if(g_smcObBearBot > 0 && g_smcObBearBot > price)
         entryCandS = MathMax(entryCandS, g_smcObBearBot);
      g_smcSetupEntry = MathMax(entryCandS, price + atrEst * 0.08);
      if(g_smcSetupEntry <= 0 || g_smcSetupEntry <= price) g_smcSetupEntry = kolaSell;
      g_smcSetupSL  = (g_smcObBearTop > 0) ? g_smcObBearTop + atrEst * 0.12 : kolaSell + atrEst * 0.12;
      double risk   = g_smcSetupSL - g_smcSetupEntry;
      if(risk <= price * 0.00005) return;
      g_smcSetupTP1 = g_smcSetupEntry - risk;
      g_smcSetupTP2 = g_smcSetupEntry - risk * 1.5;
      g_smcSetupRR  = 1.0;
   }
   SMCGP_ValidateSetup();
}

void SMCGP_ApplyOBSetupFromTV()
{
   if(g_smcSetupValid) return;
   double price = (g_smcGomPrice > 0) ? g_smcGomPrice : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0) return;
   double atrEst = price * 0.0012;

   if(g_smcObBullTop > 0 && g_smcObBullBot > 0 && g_smcGomVerdictNum >= 2)
   {
      g_smcSetupDir   = 1;
      g_smcSetupType  = "OB_BULL";
      g_smcSetupEntry = g_smcObBullTop;
      g_smcSetupSL    = g_smcObBullBot - atrEst * 0.12;
      double risk     = g_smcSetupEntry - g_smcSetupSL;
      if(risk > price * 0.00005)
      {
         g_smcSetupTP1 = g_smcSetupEntry + risk;
         g_smcSetupTP2 = g_smcSetupEntry + risk * 1.5;
         g_smcSetupRR  = 1.0;
         SMCGP_ValidateSetup();
      }
   }
   else if(g_smcObBearTop > 0 && g_smcObBearBot > 0 && g_smcGomVerdictNum <= -2)
   {
      g_smcSetupDir   = -1;
      g_smcSetupType  = "OB_BEAR";
      g_smcSetupEntry = g_smcObBearBot;
      g_smcSetupSL    = g_smcObBearTop + atrEst * 0.12;
      double risk     = g_smcSetupSL - g_smcSetupEntry;
      if(risk > price * 0.00005)
      {
         g_smcSetupTP1 = g_smcSetupEntry - risk;
         g_smcSetupTP2 = g_smcSetupEntry - risk * 1.5;
         g_smcSetupRR  = 1.0;
         SMCGP_ValidateSetup();
      }
   }
}

void SMCGP_ParseSetupFromGOM(const string &body)
{
   g_smcSetupDir     = (int)SMCGP_JsonDouble(body, "setup_dir");
   g_smcSetupEntry   = SMCGP_JsonDouble(body, "setup_entry");
   g_smcSetupSL      = SMCGP_JsonDouble(body, "setup_sl");
   g_smcSetupTP1     = SMCGP_JsonDouble(body, "setup_tp1");
   g_smcSetupTP2     = SMCGP_JsonDouble(body, "setup_tp2");
   g_smcSetupRR      = SMCGP_JsonDouble(body, "setup_rr");
   g_smcSetupType    = SMCGP_JsonString(body, "setup_type");
   g_smcSetupConfirm = SMCGP_JsonString(body, "setup_confirm");
   if(StringLen(g_smcSetupConfirm) == 0)
   {
      int ccode = (int)SMCGP_JsonDouble(body, "setup_confirm_code");
      if(ccode == 1)       g_smcSetupConfirm = "PIN_BAR_BULL";
      else if(ccode == -1) g_smcSetupConfirm = "PIN_BAR_BEAR";
   }
   SMCGP_ValidateSetup();
   if(!g_smcSetupValid)
      SMCGP_InferSetupFromGOM(body);
   if(!g_smcSetupValid)
      SMCGP_ApplyOBSetupFromTV();
}

// ── Poll GOM ───────────────────────────────────────────────────────
void SMCGP_PollGOM()
{
   // ── MODE BACKTEST : simuler GOM depuis EMA locales (pas d'HTTP) ──────────
   long testerMode = MQL5InfoInteger((ENUM_MQL5_INFO_INTEGER)7); // MQL_TESTER = 7
   if(testerMode != 0)
   {
      if(GOMPollIntervalSec > 0 && (int)(TimeCurrent() - g_smcLastGOMPoll) < GOMPollIntervalSec)
         return;
      g_smcLastGOMPoll = TimeCurrent();

      MqlRates r[];
      ArraySetAsSeries(r, true);
      int copied = CopyRates(_Symbol, PERIOD_M1, 0, 50, r);
      if(copied >= 20)
      {
         // EMA8 et EMA21 rapides
         double k8 = 2.0/9.0, k21 = 2.0/22.0;
         double e8 = r[copied-1].close, e21 = r[copied-1].close;
         for(int i = copied-2; i >= 0; i--)
         { e8 = r[i].close*k8 + e8*(1-k8); e21 = r[i].close*k21 + e21*(1-k21); }
         double currentClose = r[0].close;
         double momentum = (e8 - e21) / e21;

         int prevVn = g_smcGomVerdictNum;
         string prevVerd = g_smcGomVerdict;

         if(momentum > 0.0003)
         {
            g_smcGomVerdictNum  = 2;   // GOOD BUY
            g_smcGomVerdict     = "GOOD BUY";
            g_smcGomCoherence   = MathMin(95.0, 70.0 + MathAbs(momentum)*5000.0);
         }
         else if(momentum < -0.0003)
         {
            g_smcGomVerdictNum  = -2;  // GOOD SELL
            g_smcGomVerdict     = "GOOD SELL";
            g_smcGomCoherence   = MathMin(95.0, 70.0 + MathAbs(momentum)*5000.0);
         }
         else
         {
            g_smcGomVerdictNum  = 0;
            g_smcGomVerdict     = "WAIT";
            g_smcGomCoherence   = 50.0;
         }
         g_smcGomConnected   = true;
         g_cogDirection      = (g_smcGomVerdictNum > 0) ? "BUY" : (g_smcGomVerdictNum < 0 ? "SELL" : "NEUTRAL");
         SMCGP_CacheVerdict(SMCGP_ResolveGOMSym(_Symbol), g_smcGomVerdictNum, g_smcGomVerdict);
         SMCGP_NotifyGOMVerdictChange(SMCGP_ResolveGOMSym(_Symbol), prevVn, prevVerd);
      }
      return;
   }
   // ────────────────────────────────────────────────────────────────────────

   // TOUJOURS poll (même si UseGOMVerdictFilter + UseGOMPipeline + ShowGOMDashboard sont OFF)
   // Pour affichage temps réel du verdict sur SMC dashboard

   // GOMPollIntervalSec = 0 → poll toutes les secondes (1s floor pour éviter HTTP flood)
   // Sinon, respecter l'interval en secondes (basé sur la dernière TENTATIVE, succès ou non)
   int effectiveInterval = MathMax(GOMPollIntervalSec, 1); // minimum 1s entre HTTP requests
   {
      int age = (int)(TimeCurrent() - g_smcLastGOMAttempt);
      if(age < effectiveInterval) return;
   }

   g_smcLastGOMAttempt = TimeCurrent();  // timestamp tentative (peu importe résultat)

   string sym = SMCGP_EncodeSym(SMCGP_ResolveGOMSym(_Symbol));
   string body;
   bool ok = false;

   string chartTf = SMCGP_ChartTfLabel();
   string srcParam = "local";
   if(GOMVerdictSource == GOM_SRC_TRADINGVIEW) srcParam = "tv";
   else if(GOMVerdictSource == GOM_SRC_PREDICTIVE) srcParam = "predictive";
   else if(GOMVerdictSource == GOM_SRC_LOCAL) srcParam = "local";
   else srcParam = "local"; // AUTO = calcul MT5 live (candles uploadées)
   string gomQuery = "/gom-kola-dashboard?symbol=" + sym + "&chart_tf=" + chartTf + "&source=" + srcParam;
   int gomTimeout = (GOM_Timeout_ms > 0 ? GOM_Timeout_ms : AI_Timeout_ms);

   // ✅ PRIORITÉ 1: /gom-kola-dashboard (calcul local MT5)
   if(SMCGP_HttpGet(gomQuery, body, gomTimeout)
      && (SMCGP_JsonBool(body, "ok") || StringFind(body, "\"ok\":true") >= 0))
      ok = true;
   // Fallback 2: cache TV — uniquement si source TradingView (évite stale PERFECT BUY)
   else if(GOMVerdictSource == GOM_SRC_TRADINGVIEW
      && SMCGP_HttpGet("/gom-tableau-complete?symbol=" + sym, body, gomTimeout)
      && (SMCGP_JsonBool(body, "ok") || StringFind(body, "\"ok\":true") >= 0))
      ok = true;
   // Fallback 3: /gom-verdict (lit gom_signal.json directement — données possibly stale mais meilleures que rien)
   else if(SMCGP_HttpGet("/gom-verdict?symbol=" + sym, body, gomTimeout)
      && (SMCGP_JsonBool(body, "ok") || StringFind(body, "\"ok\":true") >= 0))
      ok = true;

   string symLabel = SMCGP_ResolveGOMSym(_Symbol);

   if(!ok)
   {
      int errPrevVnum = g_smcGomVerdictNum;
      string errPrevVerd = g_smcGomVerdict;
      SMCGP_InvalidateGOM();
      SMCGP_NotifyGOMVerdictChange(symLabel, errPrevVnum, errPrevVerd);
      // Déterminer la source d'erreur
      if(g_smcLastHttpCode == 0 || g_smcLastHttpCode == -1)
         g_smcGomSource = "NO_HTTP";
      else if(StringFind(body, "WAIT") >= 0 || StringFind(body, "non disponibles") >= 0)
         g_smcGomSource = "WAIT_POLL";  // Données pas encore pollées
      else
         g_smcGomSource = "HTTP_" + IntegerToString(g_smcLastHttpCode);

      // DEBUG: Log des requêtes échouées
      Print("[GOM-POLL] ❌ FAILED for ", sym, " | Source: ", g_smcGomSource, " | Last HTTP: ", g_smcLastHttpCode);
      return;
   }

   int prevVnum = g_smcGomVerdictNum;
   string prevVerd = g_smcGomVerdict;
   int prevSpikeLevel = g_smcGomSpikeLevel;
   bool prevSpikeTrad = g_smcGomSpikeTradable;
   SMCGP_ParseGOMBody(body);

   // ── Correction locale immédiate : vérifier M1/M5 dès le poll ──────────
   SMCGP_RefreshCorrectionWaitOverlay(symLabel);

   // ── Poll réussi : mettre à jour le timestamp de succès ──────────────────
   g_smcLastGOMPoll = TimeCurrent();

   if(prevVnum != g_smcGomVerdictNum || prevVerd != g_smcGomVerdict)
      SMCGP_NotifyGOMVerdictChange(symLabel, prevVnum, prevVerd);
   if(prevSpikeLevel != g_smcGomSpikeLevel || prevSpikeTrad != g_smcGomSpikeTradable)
      SMCGP_NotifySpikeImminent(symLabel, prevSpikeLevel, prevSpikeTrad);

   // ── Mettre en cache le verdict pour ce symbole ──
   SMCGP_CacheVerdict(symLabel, g_smcGomVerdictNum, g_smcGomVerdict);

   // DEBUG: Log des requêtes réussies
   Print("[GOM-POLL] ✅ SUCCESS for ", sym, " | Verdict: ", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") | Coherence: ", g_smcGomCoherence, "%");
}

bool SMCGP_IsGoodPerfect(int vnum)
{
   return (MathAbs(vnum) >= 2);
}

void SMCGP_PushGOMMsg(const string msg)
{
   Print("[GOM-NOTIF] ", msg);
   Alert(msg);
   if(!SendNotification(msg))
      Print("[GOM-NOTIF] SendNotification a echoue — verifier Options > Notifications MT5");
   PB_SendWhatsAppAlert(msg);
}

void SMCGP_NotifyGOMVerdictChange(const string symLabel,
                                  const int prevVnum, const string &prevVerdict)
{
   if(!UseNotifications || !GOMVerdictPushNotify) return;

   const int newVnum = g_smcGomVerdictNum;
   const string newVerdict = g_smcGomVerdict;

   if(!g_smcGomNotifReady)
   {
      g_smcGomNotifReady = true;
      g_smcGomVerdictNumPrev = newVnum;
      g_smcGomVerdictPrev = newVerdict;
      Print("[GOM-NOTIF] Baseline ", symLabel, " vn=", newVnum, " ", newVerdict);
      return;
   }

   if(prevVnum == newVnum && prevVerdict == newVerdict) return;

   if(SMCGP_IsGOMForceExhausted(prevVnum, newVnum))
   {
      g_smcGomForceExhausted = true;
      Print("[GOM] Force mouvement épuisée ", symLabel, " ", prevVerdict, " -> ", newVerdict);
   }
if(SMCGP_IsPerfectVerdict(newVnum) || newVnum == 0)
       g_smcGomForceExhausted = false;
    if(SMCGP_IsPerfectVerdict(newVnum))
       g_smcGomLastPerfectTime = TimeCurrent();

   const bool wasGP = SMCGP_IsGoodPerfect(prevVnum);
   const bool isGP  = SMCGP_IsGoodPerfect(newVnum);

   if(!wasGP && isGP)
   {
      string side = (newVnum > 0) ? "BUY" : "SELL";
      string msg = StringFormat("[GOM] %s %s %s | Coh %.0f%% Q %.0f%%",
                                symLabel, newVerdict, side, g_smcGomCoherence, g_smcGomQuality);
      SMCGP_PushGOMMsg(msg);
   }
   else if(wasGP && isGP && prevVnum != newVnum)
   {
      string msg = StringFormat("[GOM] %s upgrade %s -> %s | Coh %.0f%%",
                                symLabel, prevVerdict, newVerdict, g_smcGomCoherence);
      SMCGP_PushGOMMsg(msg);
   }
   else if(wasGP && newVnum == 0)
   {
      string wasTxt = prevVerdict;
      if(StringLen(wasTxt) == 0)
      {
         if(prevVnum == 3)       wasTxt = "PERFECT BUY";
         else if(prevVnum == 2)  wasTxt = "GOOD BUY";
         else if(prevVnum == -3) wasTxt = "PERFECT SELL";
         else if(prevVnum == -2) wasTxt = "GOOD SELL";
         else                    wasTxt = "GOOD/PERFECT";
      }
      string msg = StringFormat("[GOM] WAIT %s (etait %s)", symLabel, wasTxt);
      SMCGP_PushGOMMsg(msg);
   }
   else
   {
      Print("[GOM-NOTIF] Changement ignore ", symLabel,
            " ", prevVnum, "->", newVnum, " (", prevVerdict, " -> ", newVerdict, ")");
   }

   g_smcGomVerdictNumPrev = newVnum;
   g_smcGomVerdictPrev = newVerdict;
}

int SMCGP_ResolveSpikeFreqFromSymbol(const string sym)
{
   string u = sym;
   StringToUpper(u);
   if(StringFind(u, "1000") >= 0) return 1000;
   if(StringFind(u, "500") >= 0)  return 500;
   if(StringFind(u, "300") >= 0)  return 300;
   return 0;
}

int SMCGP_EstimateSpikeMinutes()
{
   int freq = g_smcGomSpikeFreqBars;
   if(freq <= 0) freq = SMCGP_ResolveSpikeFreqFromSymbol(_Symbol);
   if(freq <= 0) return 0;

   if(g_smcGomSpikeProgressPct > 0.0 && g_smcGomSpikeProgressPct < 100.0)
      return (int)MathMax(1, MathRound((100.0 - g_smcGomSpikeProgressPct) / 100.0 * freq));

   if(g_smcGomBarsSinceSpike > 0 && g_smcGomBarsSinceSpike < freq)
      return (int)MathMax(1, freq - g_smcGomBarsSinceSpike);

   return (int)MathMax(1, MathRound(freq / 60.0));
}

void SMCGP_NotifySpikeImminent(const string symLabel, const int prevLevel, const bool prevTradable)
{
   if(!UseNotifications || !SpikeImminentPushNotify) return;

   string _smcSym = _Symbol;
   StringToUpper(_smcSym);
   if(StringFind(_smcSym, "BOOM") < 0 && StringFind(_smcSym, "CRASH") < 0 &&
      StringFind(_smcSym, "PAINX") < 0 && StringFind(_smcSym, "GAINX") < 0) return;

   const int lvl = g_smcGomSpikeLevel;
   const bool tradable = g_smcGomSpikeTradable;
   const bool isImminent = (lvl >= 3 && tradable);

   if(!g_smcSpikeNotifReady)
   {
      g_smcSpikeNotifReady = true;
      g_smcGomSpikeLevelPrev = lvl;
      g_smcGomSpikeTradablePrev = tradable;
      Print("[SPIKE-NOTIF] Baseline ", symLabel, " level=", lvl, " trad=", tradable);
      return;
   }

   const bool wasImminent = (prevLevel >= 3 && prevTradable);
   if(isImminent && !wasImminent)
   {
      int etaMin = SMCGP_EstimateSpikeMinutes();
      string symU = symLabel;
      StringToUpper(symU);
      string sc = symU;
      StringReplace(sc, " ", "");
      bool boomLike  = (StringFind(sc, "BOOM") >= 0 || StringFind(sc, "GAINX") >= 0);
      bool crashLike = (StringFind(sc, "CRASH") >= 0 || StringFind(sc, "PAINX") >= 0);
      string side = boomLike ? "BUY spike" : (crashLike ? "SELL spike" : "spike");
      string msg = StringFormat("[SPIKE] %s IMMINENT %s | prob %.0f%% imm %.0f%% ~%d min",
                                symLabel, side, g_smcGomSpikePct, g_smcGomImminencePct, etaMin);
      SMCGP_PushGOMMsg(msg);
   }
   else if(wasImminent && lvl < 3)
   {
      string msg = StringFormat("[SPIKE] %s fenetre fermee (niv %d)", symLabel, lvl);
      SMCGP_PushGOMMsg(msg);
   }

   g_smcGomSpikeLevelPrev = lvl;
   g_smcGomSpikeTradablePrev = tradable;
}

double SMCGP_EntryTolerance(const double price)
{
   double tol = price * 0.0005;
   int hAtr = iATR(_Symbol, PERIOD_M5, 14);
   if(hAtr != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(hAtr, 0, 1, 1, atrBuf) >= 1)
         tol = MathMax(tol, atrBuf[0] * 0.3);
      IndicatorRelease(hAtr);
   }
   return tol;
}

bool SMCGP_IsPriceInOBBull()
{
   if(g_smcObBullTop <= 0 || g_smcObBullBot <= 0) return false;
   double p = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double hi = MathMax(g_smcObBullTop, g_smcObBullBot);
   double lo = MathMin(g_smcObBullTop, g_smcObBullBot);
   return (p >= lo && p <= hi);
}

bool SMCGP_IsPriceInOBBear()
{
   if(g_smcObBearTop <= 0 || g_smcObBearBot <= 0) return false;
   double p = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double hi = MathMax(g_smcObBearTop, g_smcObBearBot);
   double lo = MathMin(g_smcObBearTop, g_smcObBearBot);
   return (p >= lo && p <= hi);
}

bool SMCGP_IsTVBBCounterTrend(const int dir)
{
   if(!UseTVBollingerFilter || dir == 0) return false;
   if(g_smcBbMid <= 0) return false;

   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Règle Pine: BUY au-dessus BB Mid, SELL en-dessous — exception zone OB TV
   if(dir == 1)
   {
      if(price >= g_smcBbMid) return false;
      if(SMCGP_IsPriceInOBBull()) return false;
      return true;
   }
   if(dir == -1)
   {
      if(price <= g_smcBbMid) return false;
      if(SMCGP_IsPriceInOBBear()) return false;
      return true;
   }
   return false;
}

bool SMCGP_IsOBBlockingPath(const int dir)
{
   if(!g_smcSetupValid || g_smcSetupTP1 <= 0) return false;

   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = g_smcSetupTP1;

   if(dir == 1)
   {
      if(g_smcGomKolaSell > price && g_smcGomKolaSell < tp) return true;
      if(g_smcBbUp > price && g_smcBbUp < tp) return true;
      if(g_smcObBearBot > price && g_smcObBearTop > 0 && g_smcObBearBot < tp) return true;
   }
   else
   {
      if(g_smcGomKolaBuy < price && g_smcGomKolaBuy > tp) return true;
      if(g_smcBbDn < price && g_smcBbDn > tp) return true;
      if(g_smcObBullTop < price && g_smcObBullBot > 0 && g_smcObBullTop > tp) return true;
   }
   return false;
}

bool SMCGP_IsPriceAtOBEntry(const int dir)
{
   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tol = SMCGP_EntryTolerance(price);

   double kolaLevel = (dir == 1) ? g_smcGomKolaBuy : g_smcGomKolaSell;
   if(kolaLevel > 0 && MathAbs(price - kolaLevel) <= tol)
      return true;

   if(dir == 1 && SMCGP_IsPriceInOBBull()) return true;
   if(dir == -1 && SMCGP_IsPriceInOBBear()) return true;

   if(g_smcSetupValid && g_smcSetupEntry > 0)
   {
      if(MathAbs(price - g_smcSetupEntry) <= tol)
         return true;
      return false;
   }

   if(kolaLevel > 0) return false;
   return true;
}

bool SMCGP_GOMCoherenceOK()
{
   double minCoh = SMC_EffectiveGOMMinCoherence();
   if(minCoh <= 0) return true;
   if(g_smcGomCoherence <= 0) return false;
   // Synthétiques Boom/Crash + Weltrade vol : 2/3 TF = 66.7% → seuil 65%
   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH && minCoh > 65.0) minCoh = 65.0;
   else if(SMC_IsWeltradeSymbol(_Symbol) && minCoh > 65.0) minCoh = 65.0;
   return (g_smcGomCoherence >= minCoh);
}

bool SMCGP_GOMAllowsDirectionEx(const int dir, const bool requireOBTouch)
{
   if(!UseGOMVerdictFilter) return true;
   if(!g_smcGomConnected) { Print("[GOM-ALLOW] Rejeté: NOT_CONNECTED"); return false; }
   if(g_smcGomVerdictNum == 0) { Print("[GOM-ALLOW] Rejeté: VERDICT_ZERO"); return false; }

   // PERFECT : gates allégés — le verdict |vn|>=3 prime sur BB/MTF
   if(SMCGP_IsPerfectVerdict(g_smcGomVerdictNum) || MathAbs(g_smcGomVerdictNum) >= 3)
   {
      if(dir == 1 && g_smcGomVerdictNum < 3) return false;
      if(dir == -1 && g_smcGomVerdictNum > -3) return false;
      if(!SMCGP_GOMCoherenceOK())
      { Print("[GOM-ALLOW] Rejeté PERFECT: LOW_COHERENCE ", g_smcGomCoherence, "%"); return false; }
      Print("[GOM-ALLOW] ✅ PERFECT autorisé dir=", dir, " vn=", g_smcGomVerdictNum);
      return true;
   }

   if(!SMCGP_IsGoodPerfect(g_smcGomVerdictNum)) { Print("[GOM-ALLOW] Rejeté: NOT_GOOD_PERFECT vn=", g_smcGomVerdictNum); return false; }

   if(!SMCGP_GOMCoherenceOK())
   { Print("[GOM-ALLOW] Rejeté: LOW_COHERENCE ", g_smcGomCoherence, "%"); return false; }

   if(dir == 1)
   {
      if(g_smcGomVerdictNum < 2) { Print("[GOM-ALLOW] Rejeté: BUY_VN_TOO_LOW vn=", g_smcGomVerdictNum); return false; }
      if(StringLen(g_smcGomGlobalDir) > 0 && StringCompare(g_smcGomGlobalDir, "BEAR") == 0
         && g_smcGomGlobalStr >= GOMGlobalMinConfidence)
      { Print("[GOM-ALLOW] Rejeté: BUY_AGAINST_GLOBAL_BEAR str=", g_smcGomGlobalStr); return false; }
   }
   else if(dir == -1)
   {
      if(g_smcGomVerdictNum > -2) { Print("[GOM-ALLOW] Rejeté: SELL_VN_TOO_HIGH vn=", g_smcGomVerdictNum); return false; }
      if(StringLen(g_smcGomGlobalDir) > 0 && StringCompare(g_smcGomGlobalDir, "BULL") == 0
         && g_smcGomGlobalStr >= GOMGlobalMinConfidence)
      { Print("[GOM-ALLOW] Rejeté: SELL_AGAINST_GLOBAL_BULL str=", g_smcGomGlobalStr); return false; }
   }
   else { Print("[GOM-ALLOW] Rejeté: DIR_INVALID"); return false; }

   if(dir == 1 && g_smcGomVerdictNum < 0) { Print("[GOM-ALLOW] Rejeté: BUY_SIGN_MISMATCH"); return false; }
   if(dir == -1 && g_smcGomVerdictNum > 0) { Print("[GOM-ALLOW] Rejeté: SELL_SIGN_MISMATCH"); return false; }

   // Détection FOREX (XAUUSD, EUR, GBP, JPY) — filtres moins stricts que Boom/Crash
   bool isForex = (StringFind(_Symbol, "USD") >= 0 || StringFind(_Symbol, "EUR") >= 0 ||
                    StringFind(_Symbol, "GBP") >= 0 || StringFind(_Symbol, "JPY") >= 0);

   // BB Filter: pour FOREX, on peut être légèrement contre-tendance vs BB (max -20 pips au-delà de BB Mid)
   // Pour Boom/Crash, on refuse les entrées contre BB (original strict)
   if(UseTVBollingerFilter && SMCGP_IsTVBBCounterTrend(dir))
   {
      if(!isForex)
      { Print("[GOM-ALLOW] Rejeté: BB_COUNTER_TREND (Boom/Crash)"); return false; }
      if(!SMCGP_IsNearBBForTrade(dir))
      { Print("[GOM-ALLOW] Rejeté: BB_TOO_FAR_FROM_MID (FOREX)"); return false; }
   }

   // OB Filter: pour FOREX, on accepte l'entrée si verdict est GOOD, même sans OB parfait
   if(requireOBTouch && GOMRequireOBTouch && !isForex)
   {
      if(!SMCGP_IsPriceAtOBEntry(dir)) { Print("[GOM-ALLOW] Rejeté: NOT_AT_OB_ENTRY"); return false; }
      if(SMCGP_IsOBBlockingPath(dir)) { Print("[GOM-ALLOW] Rejeté: OB_BLOCKING_PATH"); return false; }
   }

   // OTE Filter: prix doit être dans la zone Fibonacci 61.8%-78.6% du swing
   // BYPASS si verdict GOOD/PERFECT (vn ±2, ±3) — ils ont déjà des gates suffisantes
   bool isGoodPerfect = (g_smcGomVerdictNum >= 2 || g_smcGomVerdictNum <= -2);
   if(GOMRequireOTE && UseOTE && g_smcOteTop > 0 && g_smcOteBot > 0 && !isGoodPerfect)
   {
      double curPx = SymbolInfoDouble(_Symbol, (dir == 1) ? SYMBOL_ASK : SYMBOL_BID);
      double oteLo = MathMin(g_smcOteTop, g_smcOteBot);
      double oteHi = MathMax(g_smcOteTop, g_smcOteBot);
      bool priceInOTE = (curPx >= oteLo && curPx <= oteHi);

      if(!priceInOTE)
      { Print("[GOM-ALLOW] Rejeté: NOT_IN_OTE prix=", DoubleToString(curPx, _Digits),
              " zone=[", DoubleToString(oteLo, _Digits), "-", DoubleToString(oteHi, _Digits), "]"); return false; }

      if(g_smcOteDir != 0 && g_smcOteDir != dir)
      { Print("[GOM-ALLOW] Rejeté: OTE_DIR_MISMATCH ote_dir=", g_smcOteDir, " trade_dir=", dir); return false; }
   }

   Print("[GOM-ALLOW] ✅ Autorisé pour dir=", dir, " vn=", g_smcGomVerdictNum);
   return true;
}

bool SMCGP_GOMAllowsBasicDirection(const int dir)
{
   if(!UseGOMVerdictFilter) return true;
   if(!g_smcGomConnected) return false;
   if(!SMCGP_IsSimpleVerdict(g_smcGomVerdictNum)) return false;
   if(!SMCGP_GOMCoherenceOK()) return false;
   if(dir == 1 && g_smcGomVerdictNum != 1) return false;
   if(dir == -1 && g_smcGomVerdictNum != -1) return false;
   return true;
}

// Vérifier que le prix est proche de la BB Mid (max 30 pips de déviation pour FOREX)
bool SMCGP_IsNearBBForTrade(const int dir)
{
   if(g_smcBbMid <= 0) return true; // Si pas de BB disponible, autoriser

   double curPx = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(dir == -1) curPx = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tolerance = 30 * point; // 30 pips max deviation
   double deviation = MathAbs(curPx - g_smcBbMid);

   bool allowed = (deviation <= tolerance);
   if(!allowed)
      Print("🔍 [BB-FILTER] FOREX trade rejected — price ", DoubleToString(curPx, _Digits),
            " too far from BB Mid ", DoubleToString(g_smcBbMid, _Digits),
            " (deviation: ", DoubleToString(deviation/point, 0), " pips)");

   return allowed;
}

bool SMCGP_GOMAllowsDirection(const int dir)
{
   return SMCGP_GOMAllowsDirectionEx(dir, true);
}

// SMCGP_GOMValidatesPrimarySignal — implémentée dans SMC_Universal.mq5

// ── Vérification EA Indépendant: GOOD/PERFECT GOM + IA Status ≥70% ──
bool SMCGP_AllowsDirectIndependentEntry(const int dir)
{
   // Désactiver si la fonctionnalité est OFF
   if(!UseEAIndependentEntry)
   { return false; }

   // 1. Verdict GOOD/PERFECT requis
   if(!SMCGP_IsGoodPerfect(g_smcGomVerdictNum))
   { Print("[EA-INDEP] ❌ Rejeté: Verdict pas GOOD/PERFECT (vn=", g_smcGomVerdictNum, ")"); return false; }

   // 2. IA Status ne doit PAS être HOLD
   if(g_smcIAStatusAction == "HOLD" || StringLen(g_smcIAStatusAction) == 0)
   { Print("[EA-INDEP] ❌ Rejeté: IA Status=HOLD (", DoubleToString(g_iaStatusConfidence, 1), "%)"); return false; }

   // 3. IA Status confiance ≥ 50%
   if(g_iaStatusConfidence < 50.0)
   { Print("[EA-INDEP] ❌ Rejeté: IA Status=", DoubleToString(g_iaStatusConfidence, 1), "% < 50%"); return false; }

   // 4. Correction Cycle — seuil adapté à la phase (exempt Boom/Crash)
   if(SMCGP_CorrectionBlocksEntry(SMCGP_IsBoomCrashSym(_Symbol)))
   { Print("[EA-INDEP] ❌ Rejeté: ", SMCGP_CorrectionBlockReason(SMCGP_IsBoomCrashSym(_Symbol))); return false; }

   // 5. Vérifier direction du verdict GOM correspond à l'action
   if(dir == 1 && g_smcGomVerdictNum < 2)
   { Print("[EA-INDEP] ❌ Rejeté: BUY demandé mais verdict_num=", g_smcGomVerdictNum, " < 2 (GOOD)"); return false; }

   if(dir == -1 && g_smcGomVerdictNum > -2)
   { Print("[EA-INDEP] ❌ Rejeté: SELL demandé mais verdict_num=", g_smcGomVerdictNum, " > -2 (GOOD)"); return false; }

   // 5. IA Status direction ne doit pas contredire le trade
   if(dir == 1 && g_smcIAStatusAction == "SELL")
   { Print("[EA-INDEP] ❌ Rejeté: BUY demandé mais IA Status=SELL"); return false; }
   if(dir == -1 && g_smcIAStatusAction == "BUY")
   { Print("[EA-INDEP] ❌ Rejeté: SELL demandé mais IA Status=BUY"); return false; }

   Print("[EA-INDEP] ✅ Autorisé | Verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") | IA=", g_smcIAStatusAction, " ", DoubleToString(g_iaStatusConfidence, 1), "% | Dir=", dir);
   return true;
}


bool SMCGP_GOMAllowsAction(const string action)
{
   if(action == "BUY" || action == "buy")  return SMCGP_GOMAllowsDirection(1);
   if(action == "SELL" || action == "sell") return SMCGP_GOMAllowsDirection(-1);
   return false;
}

// ── Dessins TV (minimal ICT/SMC/OTE) ──────────────────────────────
void SMCGP_DrawTLine(const string name, const double price, const color clr,
                     const int width, const ENUM_LINE_STYLE style, const string lbl,
                     const int barsBack = 5, const int barsForward = 80)
{
   ObjectDelete(0, name);
   if(price <= 0) return;
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, barsBack);
   datetime tE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * barsForward;
   if(t0 <= 0) t0 = TimeCurrent() - PeriodSeconds(PERIOD_CURRENT) * barsBack;
   ObjectCreate(0, name, OBJ_TREND, 0, t0, price, tE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TEXT, lbl);
}

void SMCGP_DrawOTEZone()
{
   ObjectDelete(0, "SMC_OTE_ZONE");
   ObjectDelete(0, "SMC_OTE_LABEL");
   if(!UseOTE) return;

   // Priorité : niveaux OTE calculés par le serveur (Fib 61.8%–78.6% du swing MT5)
   double oteLo = 0.0, oteHi = 0.0;
   if(g_smcOteTop > 0 && g_smcOteBot > 0)
   {
      oteLo = MathMin(g_smcOteTop, g_smcOteBot);
      oteHi = MathMax(g_smcOteTop, g_smcOteBot);
   }
   else if(g_smcSetupValid && g_smcSetupEntry > 0 && g_smcSetupSL > 0)
   {
      // Fallback : recalcul local depuis Entry/SL du setup TV
      double hi = MathMax(g_smcSetupEntry, g_smcSetupSL);
      double lo = MathMin(g_smcSetupEntry, g_smcSetupSL);
      double range = hi - lo;
      if(range <= 0) return;
      if(g_smcSetupDir == 1) { oteHi = hi - range * 0.618; oteLo = hi - range * 0.786; }
      else                   { oteLo = lo + range * 0.618; oteHi = lo + range * 0.786; }
   }
   else return;

   if(oteHi <= oteLo || oteHi <= 0) return;

   // Couleur : vert si prix dans la zone, orange sinon
   color zoneColor = g_smcInOTE ? clrForestGreen : clrDarkOrange;
   string lbl = g_smcInOTE ? "OTE 61.8-78.6% ✅ PRIX DANS ZONE" : "OTE 61.8-78.6%";

   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 30);
   datetime tE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 80;
   ObjectCreate(0, "SMC_OTE_ZONE", OBJ_RECTANGLE, 0, t0, oteHi, tE, oteLo);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_FILL, true);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_SELECTABLE, false);

   ObjectCreate(0, "SMC_OTE_LABEL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, "SMC_OTE_LABEL", OBJPROP_TEXT, lbl);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_FONTSIZE, 9);
}

void SMCGP_CleanupLegacyDrawings()
{
   if(!CleanupLegacyDrawings) return;
   // OB locaux EA seulement — conserver SMC_OB_BULL_ZONE / SMC_OB_BEAR_ZONE (ai_server)
   string localObPrefixes[] = {"SMC_OB_Bull_", "SMC_OB_Bear_"};
   for(int o = 0; o < ArraySize(localObPrefixes); o++)
      ObjectsDeleteAll(0, localObPrefixes[o]);

   string prefixes[] = {
      "SMC_FVG_", "SMC_Liq_", "SMC_Fib_", "SMC_EMA_",
      "SMC_Hist_", "SMC_BC_", "SMC_CH_", "EMA_ST_", "SMC_Limit_",
      "SMC_Pred_", "SMC_Confirmed_", "SMC_Bookmark_"
   };
   for(int p = 0; p < ArraySize(prefixes); p++)
      ObjectsDeleteAll(0, prefixes[p]);
   string singles[] = {
      "SMC_ICT_PREMIUM_ZONE", "SMC_ICT_DISCOUNT_ZONE", "SMC_ICT_PREMIUM_LABEL",
      "SMC_ICT_DISCOUNT_LABEL", "SMC_ICT_EQUILIBRE", "SMC_ICT_EQUILIBRE_LABEL",
      "SMC_PAST_FUTURE_DIVIDER", "SMC_Chan_"
   };
   for(int s = 0; s < ArraySize(singles); s++)
      ObjectsDeleteAll(0, singles[s]);
}

bool SMCGP_LocalFindOB(const string symbol, const ENUM_TIMEFRAMES tf, const int wantDir,
                       double &outTop, double &outBot, datetime &outTime)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 50, rates) < 50) return false;
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt <= 0) return false;
   for(int i = 3; i < 45; i++)
   {
      if(wantDir == 1 && rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open)
      {
         double moveUp = rates[i+2].high - rates[i].low;
         if(moveUp > pt * 20)
         {
            outTop = rates[i].high;
            outBot = rates[i].low;
            outTime = rates[i].time;
            return true;
         }
      }
      if(wantDir == -1 && rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open)
      {
         double moveDown = rates[i].high - rates[i+2].low;
         if(moveDown > pt * 20)
         {
            outTop = rates[i].high;
            outBot = rates[i].low;
            outTime = rates[i].time;
            return true;
         }
      }
   }
   return false;
}

bool SMCGP_OBLevelsPlausible(const string symbol, const double top, const double bot)
{
   if(top <= 0 || bot <= 0) return false;
   double zH = MathMax(top, bot);
   double zL = MathMin(top, bot);
   if(zH <= zL) return false;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0) return false;
   double ratio = zH / bid;
   if(ratio > 8.0 || ratio < 0.125) return false;
   int hAtr = iATR(symbol, PERIOD_M15, 14);
   double atr = 0.0;
   if(hAtr != INVALID_HANDLE)
   {
      double b[];
      ArraySetAsSeries(b, true);
      if(CopyBuffer(hAtr, 0, 0, 1, b) >= 1) atr = b[0];
      IndicatorRelease(hAtr);
   }
   double maxDist = (atr > 0) ? atr * 35.0 : bid * 0.15;
   if(bid < zL - maxDist && bid > zH + maxDist) return false;
   return true;
}

void SMCGP_ReconcileOrderBlocks(const string symbol)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(g_smcGomPrice > 0 && bid > 0)
   {
      double scale = bid / g_smcGomPrice;
      if(scale > 1.35 || scale < 0.74)
      {
         if(g_smcObBullTop > 0) { g_smcObBullTop *= scale; g_smcObBullBot *= scale; }
         if(g_smcObBearTop > 0) { g_smcObBearTop *= scale; g_smcObBearBot *= scale; }
         if(g_smcBbUp > 0) g_smcBbUp *= scale;
         if(g_smcBbMid > 0) g_smcBbMid *= scale;
         if(g_smcBbDn > 0) g_smcBbDn *= scale;
      }
   }
   if(!SMCGP_OBLevelsPlausible(symbol, g_smcObBullTop, g_smcObBullBot))
   {
      double top = 0, bot = 0;
      datetime t = 0;
      if(SMCGP_LocalFindOB(symbol, PERIOD_M15, 1, top, bot, t))
      {
         g_smcObBullTop = top;
         g_smcObBullBot = bot;
         g_smcObBullTime = t;
      }
      else { g_smcObBullTop = 0; g_smcObBullBot = 0; g_smcObBullTime = 0; }
   }
   if(!SMCGP_OBLevelsPlausible(symbol, g_smcObBearTop, g_smcObBearBot))
   {
      double top = 0, bot = 0;
      datetime t = 0;
      if(SMCGP_LocalFindOB(symbol, PERIOD_M15, -1, top, bot, t))
      {
         g_smcObBearTop = top;
         g_smcObBearBot = bot;
         g_smcObBearTime = t;
      }
      else { g_smcObBearTop = 0; g_smcObBearBot = 0; g_smcObBearTime = 0; }
   }
}

void SMCGP_DrawTVLevels()
{
   if(!ShowTVSyncedLevels) return;

   static datetime s_last = 0;
   if((int)(TimeCurrent() - s_last) < 3) return;
   s_last = TimeCurrent();

   SMCGP_ReconcileOrderBlocks(_Symbol);
   SMCGP_CleanupLegacyDrawings();

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(g_smcGomKolaBuy > 0)
      SMCGP_DrawTLine("TM_KOLA_BUY", g_smcGomKolaBuy, clrDodgerBlue, 2, STYLE_DASH,
                      StringFormat("KOLA BUY %." + IntegerToString(dg) + "f", g_smcGomKolaBuy));
   else ObjectDelete(0, "TM_KOLA_BUY");

   if(g_smcGomKolaSell > 0)
      SMCGP_DrawTLine("TM_KOLA_SELL", g_smcGomKolaSell, clrOrangeRed, 2, STYLE_DASH,
                      StringFormat("KOLA SELL %." + IntegerToString(dg) + "f", g_smcGomKolaSell));
   else ObjectDelete(0, "TM_KOLA_SELL");

   if(g_smcSetupValid && g_smcSetupEntry > 0)
   {
      color cE = (g_smcSetupDir == 1) ? clrDodgerBlue : clrOrangeRed;
      SMCGP_DrawTLine("TM_OB_ENTRY", g_smcSetupEntry, cE, 3, STYLE_SOLID,
                      StringFormat("ENTRY %s", g_smcSetupType));
      SMCGP_DrawTLine("TM_OB_SL", g_smcSetupSL, clrCrimson, 2, STYLE_DASH, "SL");
      SMCGP_DrawTLine("TM_OB_TP1", g_smcSetupTP1, clrLimeGreen, 2, STYLE_DASH, "TP1");
      if(g_smcSetupTP2 > 0)
         SMCGP_DrawTLine("TM_OB_TP2", g_smcSetupTP2, clrLimeGreen, 1, STYLE_DOT, "TP2");

      ObjectDelete(0, "TM_OB_ZONE");
      datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 10);
      datetime tE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 60;
      double zH = MathMax(g_smcSetupEntry, g_smcSetupSL);
      double zL = MathMin(g_smcSetupEntry, g_smcSetupSL);
      ObjectCreate(0, "TM_OB_ZONE", OBJ_RECTANGLE, 0, t0, zH, tE, zL);
      ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_COLOR, cE);
      ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_BACK, true);
      ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_FILL, true);
      ObjectSetInteger(0, "TM_OB_ZONE", OBJPROP_SELECTABLE, false);

      ObjectDelete(0, "TM_OB_LABEL");
      ObjectCreate(0, "TM_OB_LABEL", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_YDISTANCE, 30);
      ObjectSetString(0, "TM_OB_LABEL", OBJPROP_TEXT,
         StringFormat("%s E:%.5f SL:%.5f TP1:%.5f RR:%.1f | GOM:%s",
                      g_smcSetupType, g_smcSetupEntry, g_smcSetupSL, g_smcSetupTP1,
                      g_smcSetupRR, g_smcGomVerdict));
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "TM_OB_LABEL", OBJPROP_FONTSIZE, 10);
   }
   else
   {
      ObjectDelete(0, "TM_OB_ENTRY");
      ObjectDelete(0, "TM_OB_SL");
      ObjectDelete(0, "TM_OB_TP1");
      ObjectDelete(0, "TM_OB_TP2");
      ObjectDelete(0, "TM_OB_ZONE");
      ObjectDelete(0, "TM_OB_LABEL");
   }

   SMCGP_DrawOTEZone();

   if(ShowTVBollingerLines)
   {
      if(g_smcBbUp > 0)
         SMCGP_DrawTLine("TM_BB_UP", g_smcBbUp, clrMediumPurple, 2, STYLE_SOLID,
                         StringFormat("BB UP %." + IntegerToString(dg) + "f", g_smcBbUp));
      else ObjectDelete(0, "TM_BB_UP");

      if(g_smcBbMid > 0)
         SMCGP_DrawTLine("TM_BB_MID", g_smcBbMid, clrGold, 2, STYLE_DASH,
                         StringFormat("BB MID %." + IntegerToString(dg) + "f", g_smcBbMid));
      else ObjectDelete(0, "TM_BB_MID");

      if(g_smcBbDn > 0)
         SMCGP_DrawTLine("TM_BB_DN", g_smcBbDn, clrMediumPurple, 2, STYLE_SOLID,
                         StringFormat("BB DN %." + IntegerToString(dg) + "f", g_smcBbDn));
      else ObjectDelete(0, "TM_BB_DN");
   }
   else
   {
      ObjectDelete(0, "TM_BB_UP");
      ObjectDelete(0, "TM_BB_MID");
      ObjectDelete(0, "TM_BB_DN");
   }

   double liveBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int barSec = PeriodSeconds(PERIOD_CURRENT);
   if(barSec <= 0) barSec = 60;
   datetime tObE = TimeCurrent() + (datetime)(barSec * 40);

   if(ShowTVOrderBlocks && g_smcObBullTop > 0 && g_smcObBullBot > 0)
   {
      double zH = MathMax(g_smcObBullTop, g_smcObBullBot);
      double zL = MathMin(g_smcObBullTop, g_smcObBullBot);
      int dp = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      datetime tOb0 = (g_smcObBullTime > 0) ? g_smcObBullTime : (TimeCurrent() - (datetime)(barSec * 30));
      ObjectDelete(0, "SMC_OB_BULL_ZONE");
      ObjectCreate(0, "SMC_OB_BULL_ZONE", OBJ_RECTANGLE, 0, tOb0, zH, tObE, zL);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_BACK, true);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_SELECTABLE, false);
      ObjectDelete(0, "SMC_OB_BULL_LBL");
      ObjectCreate(0, "SMC_OB_BULL_LBL", OBJ_TEXT, 0, tObE, zH);
      ObjectSetString(0, "SMC_OB_BULL_LBL", OBJPROP_TEXT,
         StringFormat("OB+ %.*f-%.*f | bid %.*f", dp, zL, dp, zH, dp, liveBid));
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "SMC_OB_BULL_LBL", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_SELECTABLE, false);
      ObjectDelete(0, "SMC_OB_BULL_LIVE");
      ObjectCreate(0, "SMC_OB_BULL_LIVE", OBJ_HLINE, 0, 0, liveBid);
      ObjectSetInteger(0, "SMC_OB_BULL_LIVE", OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, "SMC_OB_BULL_LIVE", OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "SMC_OB_BULL_LIVE", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, "SMC_OB_BULL_LIVE", OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, "SMC_OB_BULL_ZONE");
      ObjectDelete(0, "SMC_OB_BULL_LBL");
      ObjectDelete(0, "SMC_OB_BULL_LIVE");
   }

   if(ShowTVOrderBlocks && g_smcObBearTop > 0 && g_smcObBearBot > 0)
   {
      double zH = MathMax(g_smcObBearTop, g_smcObBearBot);
      double zL = MathMin(g_smcObBearTop, g_smcObBearBot);
      int dp = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      datetime tOb0 = (g_smcObBearTime > 0) ? g_smcObBearTime : (TimeCurrent() - (datetime)(barSec * 30));
      ObjectDelete(0, "SMC_OB_BEAR_ZONE");
      ObjectCreate(0, "SMC_OB_BEAR_ZONE", OBJ_RECTANGLE, 0, tOb0, zH, tObE, zL);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_BACK, true);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_SELECTABLE, false);
      ObjectDelete(0, "SMC_OB_BEAR_LBL");
      ObjectCreate(0, "SMC_OB_BEAR_LBL", OBJ_TEXT, 0, tObE, zH);
      ObjectSetString(0, "SMC_OB_BEAR_LBL", OBJPROP_TEXT,
         StringFormat("OB- %.*f-%.*f | bid %.*f", dp, zL, dp, zH, dp, liveBid));
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "SMC_OB_BEAR_LBL", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_SELECTABLE, false);
      ObjectDelete(0, "SMC_OB_BEAR_LIVE");
      ObjectCreate(0, "SMC_OB_BEAR_LIVE", OBJ_HLINE, 0, 0, liveBid);
      ObjectSetInteger(0, "SMC_OB_BEAR_LIVE", OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, "SMC_OB_BEAR_LIVE", OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "SMC_OB_BEAR_LIVE", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, "SMC_OB_BEAR_LIVE", OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, "SMC_OB_BEAR_ZONE");
      ObjectDelete(0, "SMC_OB_BEAR_LBL");
      ObjectDelete(0, "SMC_OB_BEAR_LIVE");
   }

   ChartRedraw(0);
}

void SMCGP_CleanupChartObjects()
{
   SMCGP_CleanupOrderFlowCompass();
   string prefixes[] = {"TM_KOLA_", "TM_OB_", "TM_BB_", "GOM_PRED_", "SMC_OTE_",
                        "SMC_OB_BULL_", "SMC_OB_BEAR_", "COG_FC_", "COG_FAN_", "COG_LBL_"};
   for(int p = 0; p < ArraySize(prefixes); p++)
      ObjectsDeleteAll(0, prefixes[p]);
   ObjectDelete(0, "TM_OB_LABEL");
   ObjectDelete(0, "COG_ARROW");
   ObjectDelete(0, "COG_SUMMARY");
   SMCGP_CleanupDashboard();
   SMCGP_CleanupLegacyDrawings();
}

// ── Pipeline /pending-order ─────────────────────────────────────────
bool SMCGP_MarkPipelineConsumed(const string sym)
{
   string symEnc = SMCGP_EncodeSym(sym);
   string url = SMCGP_ActiveServerURL() + "/pending-order?symbol=" + symEnc;
   char dp[], dr[];
   string dh;
   int code = WebRequest("DELETE", url, "Content-Type: application/json\r\n", AI_Timeout_ms, dp, dr, dh);
   if(code == 200 || code == 204) SMCGP_MarkResult(true);
   else SMCGP_MarkResult(false);
   return (code == 200 || code == 204);
}

bool SMCGP_DeletePendingOrder(const string sym)
{
   return SMCGP_MarkPipelineConsumed(sym);
}

double SMCGP_SnapToTick(const string sym, const double price)
{
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(tick <= 0) return price;
   return NormalizeDouble(MathRound(price / tick) * tick, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
}

double SMCGP_MinStopDistance(const string sym, const double refPrice = 0)
{
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = pt;
   if(pt <= 0) return 0;

   long stops  = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze = SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
   double minD = (double)(stops + freeze) * pt;
   if(minD <= 0) minD = 10.0 * pt;
   minD = MathMax(minD, tick * 5.0);

   double px = refPrice;
   if(px <= 0)
   {
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      px = (ask > 0) ? ask : bid;
   }
   if(px <= 0)
   {
      double last = SymbolInfoDouble(sym, SYMBOL_LAST);
      if(last > 0) px = last;
   }

   string symU = sym;
   StringToUpper(symU);
   string sc = symU;
   StringReplace(sc, " ", "");

   bool isWeltrade = SMC_IsWeltradeSymbol(sym);
   bool isDerivSynth = (StringFind(symU, "BOOM") >= 0 || StringFind(symU, "CRASH") >= 0
                        || StringFind(sc, "GAIN") >= 0 || StringFind(sc, "PAIN") >= 0
                        || StringFind(sc, "TREND") >= 0);
   bool isVol = (StringFind(symU, "VOLATILITY") >= 0 || StringFind(sc, "FXVOL") >= 0
                 || StringFind(sc, "SFVVOL") >= 0 || StringFind(sc, "SFXVOL") >= 0
                 || StringFind(symU, "VOL ") >= 0 || StringFind(symU, "FX VOL") >= 0);

   // Weltrade synth (GainX/PainX/FX Vol) : distances larges obligatoires (~0.2% du prix)
   if(isWeltrade && px > 0)
   {
      minD = MathMax(minD, px * 0.002);
      minD = MathMax(minD, MathMax(pt * 150.0, tick * 50.0));
   }
   else if(isDerivSynth && px > 0)
   {
      minD = MathMax(minD, MathMax(pt * 250.0, px * 0.005));
   }
   else if(isVol && px > 0)
   {
      minD = MathMax(minD, MathMax(pt * 500.0, px * 0.0015));
   }
   else if(px > 0)
      minD = MathMax(minD, pt * 30.0);

   return minD * 1.25 + tick;
}

bool SMCGP_OrderCheckMarket(const string sym, const ENUM_ORDER_TYPE otype,
                            const double lot, const double sl, const double tp)
{
   MqlTradeRequest req;
   MqlTradeCheckResult chk;
   ZeroMemory(req);
   ZeroMemory(chk);
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = sym;
   req.volume    = lot;
   req.type      = otype;
   req.price     = (otype == ORDER_TYPE_BUY)
                   ? SymbolInfoDouble(sym, SYMBOL_ASK)
                   : SymbolInfoDouble(sym, SYMBOL_BID);
   req.sl        = sl;
   req.tp        = tp;
   req.deviation = 30;
   req.magic     = InpMagicNumber;
   {
      long fillFlags = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
      if((fillFlags & SYMBOL_FILLING_IOC) != 0)
         req.type_filling = ORDER_FILLING_IOC;
      else if((fillFlags & SYMBOL_FILLING_FOK) != 0)
         req.type_filling = ORDER_FILLING_FOK;
      else
         req.type_filling = ORDER_FILLING_RETURN;
   }
   return OrderCheck(req, chk);
}

bool SMCGP_PrepareMarketStops(const string sym, const int dir, const double entryPx,
                              const double slOrig, const double tpOrig, const double lot,
                              double &sl, double &tp)
{
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return false;

   double px = (dir == 1) ? ask : bid;
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double minD = SMCGP_MinStopDistance(sym, px);

   double slDist = (slOrig > 0) ? MathAbs(px - slOrig) : 0;
   double tpDist = (tpOrig > 0) ? MathAbs(tpOrig - px) : 0;
   if(slDist <= 0) slDist = minD * 2.0;
   if(tpDist <= 0) tpDist = minD * 3.0;
   slDist = MathMax(slDist, minD);
   tpDist = MathMax(tpDist, minD * 1.5);
   if(pt > 0)
   {
      if(MarketSLExtraPoints > 0) slDist += (double)MarketSLExtraPoints * pt;
      if(MarketTPExtraPoints > 0) tpDist += (double)MarketTPExtraPoints * pt;
   }
   // Buffer SL +1$ (MarketSLExtraUSD) — élargit le stop d'environ 1$ de risque
   if(MarketSLExtraUSD > 0)
   {
      double tickVal  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double lotUse   = (lot > 0) ? lot : SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      if(tickVal > 0 && tickSize > 0 && lotUse > 0)
      {
         double profitPerTick = tickVal * lotUse;
         if(profitPerTick > 0)
            slDist += (MarketSLExtraUSD / profitPerTick) * tickSize;
      }
   }

   ENUM_ORDER_TYPE otype = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   long stopsLvl = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLvl = SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);

   // Détection Weltrade synthetics pour ajustements spécifiques
   string symU = sym;
   StringToUpper(symU);
   string sc = symU;
   StringReplace(sc, " ", "");
   bool isWeltrade = SMC_IsWeltradeSymbol(sym);
   bool isBoomCrash = (StringFind(symU, "BOOM") >= 0 || StringFind(symU, "CRASH") >= 0 ||
                      StringFind(symU, "PAINX") >= 0 || StringFind(symU, "GAINX") >= 0);

   // Pour Weltrade synthetics, utiliser des distances beaucoup plus grandes dès le départ
   if(isWeltrade && px > 0)
   {
      slDist = MathMax(slDist, px * 0.003);  // 0.3% minimum
      tpDist = MathMax(tpDist, px * 0.005);  // 0.5% minimum
   }
   
   // Pour Boom/Crash (Deriv et Weltrade), distances beaucoup plus grandes
   if(isBoomCrash && px > 0)
   {
      slDist = MathMax(slDist, px * 0.080);  // 8.0% minimum — évite invalid stops broker
      tpDist = MathMax(tpDist, px * 0.100);  // 10.0% minimum
   }

   for(int pass = 0; pass < 30; pass++)
   {
      if(dir == 1)
      {
         sl = SMCGP_SnapToTick(sym, px - slDist);
         tp = SMCGP_SnapToTick(sym, px + tpDist);
         if(sl >= px - pt) sl = SMCGP_SnapToTick(sym, px - minD);
         if(tp <= px + pt) tp = SMCGP_SnapToTick(sym, px + minD * 2.0);
      }
      else
      {
         sl = SMCGP_SnapToTick(sym, px + slDist);
         tp = SMCGP_SnapToTick(sym, px - tpDist);
         if(sl <= px + pt) sl = SMCGP_SnapToTick(sym, px + minD);
         if(tp >= px - pt) tp = SMCGP_SnapToTick(sym, px - minD * 2.0);
      }

      if(SMCGP_OrderCheckMarket(sym, otype, lot, sl, tp))
         return true;

      slDist *= 1.20;
      tpDist *= 1.20;
   }

   PrintFormat("[PrepareMarketStops] ECHEC %s dir=%d px=%.5f minD=%.5f stops=%d freeze=%d sl=%.5f tp=%.5f",
               sym, dir, px, minD, (int)stopsLvl, (int)freezeLvl, sl, tp);
   return false;
}

bool SMC_MarketDealSend(const string sym, const int dirSign, const double lot,
                        double slIn, double tpIn, const string comment,
                        MqlTradeResult &result)
{
   if(dirSign == 0 || lot <= 0) return false;
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return false;

   double sl = slIn;
   double tp = tpIn;
   if(!SMCGP_PrepareMarketStops(sym, dirSign, 0, slIn, tpIn, lot, sl, tp))
   {
      result.retcode = TRADE_RETCODE_INVALID_STOPS;
      return false;
   }

   MqlTradeRequest req;
   ZeroMemory(req);
   ZeroMemory(result);
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = sym;
   req.magic     = InpMagicNumber;
   req.volume    = lot;
   req.type      = (dirSign == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = (dirSign == 1) ? ask : bid;
   req.sl        = sl;
   req.tp        = tp;
   req.comment   = comment;
   req.deviation = 30;
   {
      long fillFlags = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
      if((fillFlags & SYMBOL_FILLING_IOC) != 0)
         req.type_filling = ORDER_FILLING_IOC;
      else if((fillFlags & SYMBOL_FILLING_FOK) != 0)
         req.type_filling = ORDER_FILLING_FOK;
      else
         req.type_filling = ORDER_FILLING_RETURN;
   }
   return SafeOrderSend(req, result);
}

bool SMCGP_ExecutePipelineOrder(const string sym, const string action,
                                double entry, double sl, double tp, double lot, const bool isPipeline)
{
   if(BlockAllTrades) return false;
   if(!CanOpenAdditionalPositionForSymbol(sym, action)) return false;
   if(!IsDirectionAllowedForBoomCrash(sym, action)) return false;

   // Spike Boom/Crash/Painx/Gainx: uniquement sous GOM GOOD/PERFECT + blink BUY/SELL
   if(SMC_IsSpikeStyleSymbol(sym))
   {
      if(MathAbs(g_smcGomVerdictNum) < 2)
      {
         Print("[SMC-GOM] 🚫 Pipeline spike bloqué — GOM pas GOOD/PERFECT vn=", g_smcGomVerdictNum);
         return false;
      }
      int wantDir = (action == "BUY") ? 1 : -1;
      if(!IsSignalConfirmed() || GetConfirmedSignalDir() != wantDir)
      {
         Print("[SMC-GOM] 🚫 Pipeline spike bloqué — décision finale pas clignotante (", action, ")");
         return false;
      }
      // Contre-verdict
      if((wantDir > 0 && g_smcGomVerdictNum < 0) || (wantDir < 0 && g_smcGomVerdictNum > 0))
      {
         Print("[SMC-GOM] 🚫 Pipeline spike bloqué — contre-verdict GOM");
         return false;
      }
   }

   // Max positions atteint : bloquer toute nouvelle entrée sans exception
    if(IsTerminalFull())
   {
      Print("[SMC-GOM] 🚫 Max positions (", SMC_EffectiveMaxPositionsTerminal(), ") — ", action, " ", sym, " bloqué");
      return false;
   }

   int dir = (action == "BUY") ? 1 : -1;

   // GATE IA STATUS — bloquer si dashboard GOM affiche HOLD
   if(g_smcIAStatusAction == "HOLD" || StringLen(g_smcIAStatusAction) == 0)
   {
      Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " bloqué — IA Status dashboard=HOLD (",
            DoubleToString(g_iaStatusConfidence, 1), "%)");
      return false;
   }
   if(UseLossCooldown && g_iaStatusConfidence < 50.0)
   {
      Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " bloqué — IA Status conf=",
            DoubleToString(g_iaStatusConfidence, 1), "% < 50% requis");
      return false;
   }

   // GATE CORRECTION CYCLE — seuil par phase (exempt Boom/Crash)
   if(SMCGP_CorrectionBlocksEntry(SMCGP_IsBoomCrashSym(sym)))
   {
      Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " bloqué — ",
            SMCGP_CorrectionBlockReason(SMCGP_IsBoomCrashSym(sym)));
      return false;
   }

   // Gate GOM direction — TOUS symboles (Deriv + Weltrade FX Vol + Boom/Crash)
   // Empêche un SELL pipeline quand le dashboard affiche PERFECT BUY (vn=+3)
   if(UseGOMVerdictFilter && g_smcGomConnected)
   {
      if(g_smcGomVerdictNum == 0)
      {
         Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " annulé — GOM=WAIT (vn=0)");
         return false;
      }
      int gomDir = (g_smcGomVerdictNum > 0) ? 1 : -1;
      if(gomDir != dir)
      {
         Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " annulé — GOM inversé (vn=",
               g_smcGomVerdictNum, " ", g_smcGomVerdict, ") vs action=", action);
         return false;
      }
   }

   // Pattern Charly requis si UsePatternEntrySignals (confirmation M1/M5/H1)
   if(UsePatternEntrySignals)
   {
      if(!SMCPS_PatternGateOK(sym, dir, true))
      {
         Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " bloqué — pattern non confirmé");
         return false;
      }
      if(!SMCPS_BreakoutConfirmed(sym, dir))
      {
         Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " bloqué — attente breakout pattern");
         return false;
      }
   }

   if(UseGOMVerdictFilter && !isPipeline)
   {
      if(UseSignalFirstDiscipline)
      {
         if(!SMCGP_GOMValidatesPrimarySignal(dir))
         {
            Print("[SMC-GOM] Ordre ", action, " bloqué — GOM n'a pas validé le signal (vn=",
                  g_smcGomVerdictNum, ")");
            return false;
         }
      }
      else
      {
         bool needOB = GOMRequireOBTouch && (isPipeline ? GOMOBTouchForPipeline : true);
         if(!SMCGP_GOMAllowsDirectionEx(dir, needOB))
         {
            Print("[SMC-GOM] Ordre ", action, " bloqué — GOM=", g_smcGomVerdict,
                  " vn=", g_smcGomVerdictNum, " BB/OB/tendance");
            return false;
         }
      }
   }

   if(!SMC_BCHourAllowsTrade(sym))
   {
      Print("[SMC-GOM] Pipeline ", action, " ", sym,
            " annule — hors plage bc_heure UTC (conf=", DoubleToString(g_smcBcConfidence, 1), "%)");
      return false;
   }

   int pipeDir = (action == "BUY") ? 1 : -1;
   if(UseCognitionFilter && StringLen(g_cogDirection) > 0 && g_cogDirection != "NEUTRAL")
   {
      if((pipeDir > 0 && g_cogDirection == "SELL") || (pipeDir < 0 && g_cogDirection == "BUY"))
      {
         Print("[SMC-GOM] Pipeline ", action, " ", sym,
               " annule — cognition ", g_cogDirection,
               " str=", DoubleToString(g_cogStrength, 2),
               " conf=", DoubleToString(g_cogConfidence, 2));
         return false;
      }
   }

   // ── Gate Triple Alignement (COG + IA + GOM même sens) ─────────────────────
   // Quand activé : si triple alignement détecté, on ajuste l'entrée sur EMA9 ou S/R proche.
   // Sans triple alignement, l'ordre est bloqué (signal insuffisamment confirmé).
   if(UseTripleAlignmentGate)
   {
      // Vérifier si cognition confirme la direction
      bool cogConfirms = (g_cogDirection == action) &&
                         (g_cogStrength >= CognitionMinStrength) &&
                         (g_cogConfidence >= CognitionMinConfidence);

      // Vérifier si IA confirm la direction
      string iaActionUp = g_lastAIAction;
      StringToUpper(iaActionUp);
      bool iaConfirms = (iaActionUp == action) && (g_lastAIConfidence >= 0.65);

      // GOM PERFECT uniquement (vn=±3) — GOOD (vn=±2) ne bypass pas l'indécision IA/COG
      bool gomPerfect = (MathAbs(g_smcGomVerdictNum) >= 3);

      bool tripleAligned = cogConfirms && iaConfirms;

      if(tripleAligned)
      {
         // Triple alignement : ajuster l'entrée sur EMA9 M1 ou prix actuel si proche
         if(g_pipelineEma9Handle != INVALID_HANDLE)
         {
            double ema9buf[];
            ArraySetAsSeries(ema9buf, true);
            if(CopyBuffer(g_pipelineEma9Handle, 0, 0, 3, ema9buf) == 3)
            {
               double ema9Val    = ema9buf[0];
               double curAsk     = SymbolInfoDouble(sym, SYMBOL_ASK);
               double curBid     = SymbolInfoDouble(sym, SYMBOL_BID);
               double atrVal     = SymbolInfoDouble(sym, SYMBOL_POINT) * 50; // fallback
               double tolPct     = 0.0015; // 0.15% tolérance autour EMA9
               double tol        = ema9Val * tolPct;

               if(pipeDir == 1)
               {
                  // BUY : re-entrer si ask proche ou sous EMA9 (rebond)
                  if(curAsk <= ema9Val + tol)
                  {
                     entry = curAsk;
                     Print("[TRIPLE] ✅ BUY aligné | COG+IA+GOM | EMA9=", DoubleToString(ema9Val, _Digits),
                           " Ask=", DoubleToString(curAsk, _Digits), " → re-entrée EMA9");
                  }
                  else
                  {
                     // Prix au-dessus EMA9 — attendre retour; on laisse l'entrée GOM
                     Print("[TRIPLE] ✅ BUY aligné | COG+IA+GOM | EMA9=", DoubleToString(ema9Val, _Digits),
                           " Ask=", DoubleToString(curAsk, _Digits), " → entrée GOM directe");
                  }
               }
               else
               {
                  // SELL : re-entrer si bid proche ou au-dessus EMA9
                  if(curBid >= ema9Val - tol)
                  {
                     entry = curBid;
                     Print("[TRIPLE] ✅ SELL aligné | COG+IA+GOM | EMA9=", DoubleToString(ema9Val, _Digits),
                           " Bid=", DoubleToString(curBid, _Digits), " → re-entrée EMA9");
                  }
                  else
                  {
                     Print("[TRIPLE] ✅ SELL aligné | COG+IA+GOM | EMA9=", DoubleToString(ema9Val, _Digits),
                           " Bid=", DoubleToString(curBid, _Digits), " → entrée GOM directe");
                  }
               }
            }
         }
         Print("[TRIPLE] 🔥 Signal FORT confirmé (Cog+IA+GOM) | gomPerfect=", gomPerfect ? "OUI" : "NON");
      }
      else
      {
         // Pas de triple alignement : bloquer si cognition ou IA s'oppose OU est indécise (HOLD/NEUTRAL)
         bool cogOppose  = (StringLen(g_cogDirection) > 0 && g_cogDirection != "NEUTRAL" &&
                            ((pipeDir > 0 && g_cogDirection == "SELL") || (pipeDir < 0 && g_cogDirection == "BUY")));
         bool iaOppose   = (StringLen(iaActionUp) > 0 && iaActionUp != "HOLD" &&
                            iaActionUp != action && g_lastAIConfidence >= 0.55);
         // Bloquer aussi si IA=HOLD ou Cognition=NEUTRAL sans confirmation forte GOM
         bool iaHold     = (iaActionUp == "HOLD" || StringLen(iaActionUp) == 0);
         bool cogNeutral = (g_cogDirection == "NEUTRAL" || StringLen(g_cogDirection) == 0);
         // HOLD + NEUTRAL = aucune confirmation directionnelle → bloquer sauf PERFECT GOM (vn=±3)
         bool neitherConfirms = (iaHold && cogNeutral && !gomPerfect);
         if(cogOppose || iaOppose || neitherConfirms)
         {
            Print("[TRIPLE] 🚫 Signal bloqué — alignement insuffisant | cogConfirms=", cogConfirms,
                  " iaConfirms=", iaConfirms, " cog=", g_cogDirection, " ia=", g_lastAIAction,
                  " gomPerfect=", gomPerfect ? "OUI" : "NON");
            return false;
         }
      }
   }

   if(!SMC_HighProbabilityAllowsEntry(pipeDir))
   {
      Print("[SMC-GOM] Pipeline ", action, " ", sym,
            " annule — prob=", DoubleToString(g_lastEntryProbability, 1), "%");
      return false;
   }

   if(!TryAcquireOpenLock()) return false;

   if(!SymbolSelect(sym, true))
   {
      ReleaseOpenLock();
      return false;
   }

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0 || bid <= 0)
   {
      ReleaseOpenLock();
      return false;
   }

   double mktPx   = (dir == 1) ? ask : bid;
   double entryPx = (entry > 0 && MathAbs(entry - mktPx) / mktPx <= 0.05) ? entry : mktPx;
   if(!SMCGP_PrepareMarketStops(sym, dir, entryPx, sl, tp, lot, sl, tp))
   {
      ReleaseOpenLock();
      g_smcLastPipelineFail = TimeCurrent();
      g_smcPipelineFailCount++;
      PrintFormat("[SMC-GOM] ❌ SL/TP invalides (OrderCheck) %s %s bid=%.5f ask=%.5f SL=%.5f TP=%.5f",
                  sym, action, bid, ask, sl, tp);
      SMCGP_DeletePendingOrder(sym);
      return false;
   }

   if(SMC_IsWeltradeVolSymbol(sym))
      lot = SMC_WeltradeFxVolLot();
   else if(lot <= 0)
      lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   else if(UseMinLotOnly)
      lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   // Utiliser SafeOrderSend pour respecter toutes les gates (max positions, DecisionEngine, etc.)
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   double execPx = (MathAbs(entryPx - mktPx) < SymbolInfoDouble(sym, SYMBOL_POINT)) ? 0 : entryPx;
   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = sym;
   req.volume   = lot;
   req.type     = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price    = (execPx > 0) ? execPx : ((dir == 1) ? ask : bid);
   req.sl          = sl;
   req.tp          = tp;
   req.deviation   = 10;
   req.magic       = InpMagicNumber;
   req.comment     = "SMC_PIPELINE";
   {
      long fillFlags = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
      if((fillFlags & SYMBOL_FILLING_IOC) != 0)
         req.type_filling = ORDER_FILLING_IOC;
      else if((fillFlags & SYMBOL_FILLING_FOK) != 0)
         req.type_filling = ORDER_FILLING_FOK;
      else
         req.type_filling = ORDER_FILLING_RETURN;
   }

   bool ok = SafeOrderSendAndAlert(req, res);

   ReleaseOpenLock();

   if(ok)
   {
      g_smcLastPipelineExec = TimeCurrent();
      g_smcPipelineFailCount = 0;
      g_smcFailedPipelineId = "";
      PrintFormat("[SMC-GOM] ✅ Pipeline %s %s lot=%.2f SL=%.5f TP=%.5f | GOM=%s",
                  sym, action, lot, sl, tp, g_smcGomVerdict);
      SMCGP_MarkPipelineConsumed(sym);
      return true;
   }

   PrintFormat("[SMC-GOM] ❌ Pipeline échec %s %s: %d", sym, action, res.retcode);
   if(res.retcode == TRADE_RETCODE_INVALID_STOPS || res.retcode == TRADE_RETCODE_INVALID_PRICE)
   {
      g_smcLastPipelineFail = TimeCurrent();
      g_smcPipelineFailCount++;
      SMCGP_DeletePendingOrder(sym);
   }
   return false;
}

void SMCGP_PollAndExecutePipeline()
{
   if(!UseGOMPipeline) return;
   if((int)(TimeCurrent() - g_smcLastMCPPoll) < MCPPollIntervalSec) return;
   g_smcLastMCPPoll = TimeCurrent();

   // Règle universelle : bloquer toute entrée si IA en HOLD (dashboard GOM ou /decide)
   // Exception : synthétiques Weltrade (PAINX/GAINX/FXVOL) — pas de décision IA valide,
   // ils s'appuient uniquement sur GOM. Le gate IA HOLD ne s'applique pas.
   bool isWeltradeSynth = SMC_IsWeltradeSymbol(_Symbol);
   if(!isWeltradeSynth)
   {
      bool holdFromDashboard = (g_smcIAStatusAction == "HOLD" || StringLen(g_smcIAStatusAction) == 0);
      bool holdFromDecide    = (g_lastAIAction == "hold" || g_lastAIAction == "HOLD" || g_lastAIAction == "");
      if(holdFromDashboard || holdFromDecide)
      {
         // NOUVEAU: Vérifier si un reset manuel a été forcé
         string gvReset = "SMC_GivebackManualReset_" + IntegerToString((long)ChartID());
         if(GlobalVariableCheck(gvReset))
         {
            // Reset manuel effectué — ignorer les restrictions hold pour forcer une nouvelle évaluation
            static datetime s_resetLog = 0;
            if(TimeCurrent() - s_resetLog >= 60)
            {
               s_resetLog = TimeCurrent();
               Print("[PIPELINE] ? Reset manuel forcé — les restrictions hold ignorées, pipeline repris | reset_time=", TimeToString(TimeCurrent(), TIME_MINUTES));
            }
            // Continuer à évaluer le pipeline, ignorer hold
         }
         else
         {
            static datetime s_holdLog = 0;
            if(TimeCurrent() - s_holdLog >= 60)
            {
               s_holdLog = TimeCurrent();
               Print("[PIPELINE] ⏸ IA en HOLD — pipeline suspendu sur ", _Symbol,
                     " | dashboard=", g_smcIAStatusAction, " (", DoubleToString(g_iaStatusConfidence,1), "%)",
                     " | decide=", g_lastAIAction);
            }
            return;
         }
      }
   }

   // Gate GOM=WAIT absolu : aucun ordre pipeline si vn=0 (TOUS symboles, y compris Weltrade)
   if(g_smcGomVerdictNum == 0)
   {
      static datetime s_waitLog = 0;
      if(TimeCurrent() - s_waitLog >= 60)
      {
         s_waitLog = TimeCurrent();
         Print("[PIPELINE] 🚫 GOM=WAIT (vn=0) — pipeline suspendu | ",
               _Symbol, " | IA=", g_smcIAStatusAction, " COG=", g_cogDirection);
      }
      return;
   }

   // Gate double-indécision : IA=HOLD ET Cognition=NEUTRAL sans GOM PERFECT → bloquer
   if(MathAbs(g_smcGomVerdictNum) < 3)
   {
      bool iaIndecis  = (g_smcIAStatusAction == "HOLD" || StringLen(g_smcIAStatusAction) == 0 ||
                         g_lastAIAction == "hold" || g_lastAIAction == "HOLD" || StringLen(g_lastAIAction) == 0);
      bool cogIndecis = (g_cogDirection == "NEUTRAL" || StringLen(g_cogDirection) == 0);
      if(iaIndecis && cogIndecis)
      {
         static datetime s_dblIndLog = 0;
         if(TimeCurrent() - s_dblIndLog >= 60)
         {
            s_dblIndLog = TimeCurrent();
            Print("[PIPELINE] ⏸ Double-indécision IA+COG — pipeline suspendu | ",
                  _Symbol, " | IA=", g_smcIAStatusAction, "/", g_lastAIAction,
                  " COG=", g_cogDirection, " GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")");
         }
         return;
      }
   }

   string sym = SMCGP_EncodeSym(_Symbol);
   string body;
   if(!SMCGP_HttpGet("/pending-order?symbol=" + sym, body, AI_Timeout_ms))
      return;

   if(!SMCGP_JsonBool(body, "ok"))
      return;

   int orderPos = StringFind(body, "\"order\":{");
   if(orderPos < 0) return;
   string orderBody = StringSubstr(body, orderPos);

   string orderId = SMCGP_JsonString(orderBody, "order_id");
   if(StringLen(orderId) > 0 && orderId == g_smcLastPipelineId
      && (int)(TimeCurrent() - g_smcLastPipelineExec) < 120)
      return;

   if(StringLen(orderId) > 0 && orderId == g_smcFailedPipelineId
      && (int)(TimeCurrent() - g_smcLastPipelineFail) < 300)
      return;

   if(g_smcPipelineFailCount >= 3 && (int)(TimeCurrent() - g_smcLastPipelineFail) < 300)
      return;

   string action = SMCGP_JsonString(orderBody, "action");
   if(StringLen(action) == 0) action = SMCGP_JsonString(orderBody, "recommendation");
   StringToUpper(action);
   if(action != "BUY" && action != "SELL") return;

   if(!SMC_BCHourAllowsTrade(_Symbol))
   {
      Print("[SMC-GOM] Pipeline poll ignore — bc_heure UTC non propice pour ", _Symbol);
      return;
   }

   string source = SMCGP_JsonString(orderBody, "source");
   bool isPipeline = (StringCompare(source, "pipeline") == 0);
   if(PipelineOnlyMode && !isPipeline) return;

   double entry = SMCGP_JsonDouble(orderBody, "entry_price");
   double sl    = SMCGP_JsonDouble(orderBody, "stop_loss");
   double tp    = SMCGP_JsonDouble(orderBody, "take_profit");
   double lot   = SMCGP_JsonDouble(orderBody, "lot");
   if(SMC_IsWeltradeVolSymbol(_Symbol))
      lot = SMC_WeltradeFxVolLot();
   else if(lot <= 0)
      lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   string serverVerdict = SMCGP_JsonString(orderBody, "gom_verdict");
   StringToUpper(serverVerdict);

   // Gate GOM WAIT absolu — bloque même les ordres pipeline
   // Le verdict Python peut être en cache (généré quand GOM était BUY/SELL),
   // mais si g_smcGomVerdictNum == 0 maintenant, on n'entre pas
   if(UseGOMVerdictFilter && g_smcGomConnected && g_smcGomVerdictNum == 0)
   {
      static datetime s_pipeWaitLog = 0;
      if(TimeCurrent() - s_pipeWaitLog >= 60)
      {
         s_pipeWaitLog = TimeCurrent();
         Print("[PIPELINE] BLOQUE — GOM=WAIT (vn=0) au moment de l'exécution | ", _Symbol,
               " action=", action, " source=", source);
      }
      return;
   }
// Gate stale — verdict trop vieux = traiter comme WAIT
    if(UseGOMVerdictFilter && g_smcGomConnected && g_smcLastGOMPoll > 0
       && (int)(TimeCurrent() - g_smcLastGOMPoll) > 15)
    {
       static datetime s_pipeStalLog = 0;
       if(TimeCurrent() - s_pipeStalLog >= 30)
       {
          s_pipeStalLog = TimeCurrent();
          Print("[PIPELINE] BLOQUE — GOM stale (", (int)(TimeCurrent() - g_smcLastGOMPoll),
               "s sans poll) | ", _Symbol, " action=", action);
      }
      return;
   }

   // source=pipeline : tous les filtres GOM déjà appliqués côté Python — bypass filtres secondaires
   if(!isPipeline && UseSignalFirstDiscipline && !DisciplineAllowsPipelineAction(action))
   {
      Print("[SMC-GOM] Pipeline rejeté — signal SMC/GOM discipline (action=", action, ")");
      return;
   }

   if(!isPipeline && UseGOMVerdictFilter)
   {
      int pDir = (action == "BUY") ? 1 : -1;
      if(UseSignalFirstDiscipline)
      {
         if(!SMCGP_GOMValidatesPrimarySignal(pDir))
         {
            Print("[SMC-GOM] Pipeline rejeté — GOM n'a pas validé (vn=", g_smcGomVerdictNum, ")");
            return;
         }
      }
      else
      {
         bool needOB = GOMRequireOBTouch && (isPipeline ? GOMOBTouchForPipeline : true);
         if(!SMCGP_GOMAllowsDirectionEx(pDir, needOB))
         {
            Print("[SMC-GOM] Pipeline rejeté — GOM=", g_smcGomVerdict,
                  " vn=", g_smcGomVerdictNum, " BB/OB/tendance");
            return;
         }
      }
   }

   if(entry > 0)
   {
      double curPx = (action == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(curPx > 0 && MathAbs(entry - curPx) / curPx > 0.20)
      {
         Print("[SMC-GOM] Pipeline entry aberrant — ignoré");
         return;
      }
   }

   if(SMCGP_ExecutePipelineOrder(_Symbol, action, entry, sl, tp, lot, isPipeline))
      g_smcLastPipelineId = orderId;
   else if(StringLen(orderId) > 0)
   {
      g_smcFailedPipelineId = orderId;
      g_smcLastPipelineFail = TimeCurrent();
   }
}

// ── Dashboard GOM (style TradeManager, préfixe SMC_DASH_) ───────────
#define SMC_DASH_C_BUY       0x2E7D32
#define SMC_DASH_C_SELL      0xC62828
#define SMC_DASH_C_NEUTRAL   0x616161
#define SMC_DASH_C_BG        0x0A0A0A  // Darker (more transparent)
#define SMC_DASH_C_TXT       0xB0B0B0  // Dimmer text
#define SMC_DASH_C_BORDER    0x2A2A2A  // Subtler border
#define SMC_DASH_C_HDR_BUY   0x1B5E20
#define SMC_DASH_C_HDR_SELL  0xB71C1C
#define SMC_DASH_ROW_H       32
#define SMC_DASH_FONT_SZ     9

color SMCGP_VerdictColor(const int verdictNum)
{
   if(verdictNum >= 2)  return (color)SMC_DASH_C_HDR_BUY;
   if(verdictNum == 1)  return (color)SMC_DASH_C_BUY;
   if(verdictNum == 0)  return (color)SMC_DASH_C_NEUTRAL;
   if(verdictNum == -1) return (color)SMC_DASH_C_SELL;
   if(verdictNum <= -2) return (color)SMC_DASH_C_HDR_SELL;
   return (color)SMC_DASH_C_NEUTRAL;
}

color SMCGP_TfColor(const string dir)
{
   if(StringFind(dir, "BUY") >= 0 || StringFind(dir, "BULL") >= 0) return (color)SMC_DASH_C_BUY;
   if(StringFind(dir, "SELL") >= 0 || StringFind(dir, "BEAR") >= 0) return (color)SMC_DASH_C_SELL;
   return (color)SMC_DASH_C_NEUTRAL;
}

string SMCGP_TfShort(const string dir)
{
   if(StringLen(dir) == 0) return "---";
   return dir;
}

void SMCGP_DrawDashCell(const string name, const int x, const int y, const int cellW, const int cellH,
                        const string text, const color bgColor, const color txtColor)
{
   string bgName  = g_smcDashPrefix + name + "_BG";
   string txtName = g_smcDashPrefix + name + "_TXT";

   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, cellW);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, cellH);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, SMC_DASH_C_BORDER);

   if(ObjectFind(0, txtName) < 0)
   {
      ObjectCreate(0, txtName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, txtName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, txtName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, txtName, OBJPROP_BACK, false);
      ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, txtName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   ObjectSetString(0, txtName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, txtName, OBJPROP_XDISTANCE, x + 4);
   ObjectSetInteger(0, txtName, OBJPROP_YDISTANCE, y - 4);
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, SMC_DASH_FONT_SZ);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, txtColor);
}

void SMCGP_CleanupDashboard()
{
   ObjectsDeleteAll(0, g_smcDashPrefix);
   // Nettoyage élargi : préfixe fixe sans ChartID (objets orphelins d'anciens reloads)
   ObjectsDeleteAll(0, "SMC_DASH_");
}

void SMCGP_CleanupOrderFlowCompass()
{
   ObjectsDeleteAll(0, "SMC_OF_CMP_");
}

// Boussole circulaire OrderFlow (momentum GHOST depuis ai_server)
void SMCGP_DrawOrderFlowCompass(const int chartW, const int marginBot,
                                const int cellH, const int gap)
{
   if(!ShowOrderFlowCompass) { SMCGP_CleanupOrderFlowCompass(); return; }

   const int radius = 38;
   const int marginLR = 12;
   // bottom-left, au-dessus du dashboard GOM (comme TradingView)
   int cx = marginLR + radius + 8;
    int cy = marginBot + (cellH + gap) * 3 + radius + 28;

   string pfx = "SMC_OF_CMP_";
   int compassOct = (int)((g_smcGhostCompass + 22.5) / 45.0) % 8;
   bool isBull = (compassOct == 0 || compassOct == 1 || compassOct == 2 || compassOct == 7);
   bool isBear = (compassOct == 3 || compassOct == 4 || compassOct == 5 || compassOct == 6);
   color activeClr = isBull ? (color)SMC_DASH_C_BUY : isBear ? (color)SMC_DASH_C_SELL : (color)SMC_DASH_C_NEUTRAL;
   color borderClr = (color)0xFF404040;
   color goldClr   = (color)0xFFFFD700;

   // Fond circulaire (carré arrondi)
   string bgName = pfx + "BG";
   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   }
   int boxSize = radius * 2 + 14;
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, cx - radius - 7);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, cy + radius + 7);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, boxSize);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, boxSize);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, (color)0xFF1A1A2E);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, borderClr);

   // Anneau (8 points cardinaux)
   static const string dirs[8] = {"E","NE","N","NW","W","SW","S","SE"};
   static const double cosA[8] = { 1.0,  0.707, 0.0, -0.707, -1.0, -0.707,  0.0,  0.707};
   static const double sinA[8] = { 0.0,  0.707, 1.0,  0.707,  0.0, -0.707, -1.0, -0.707};

   for(int d = 0; d < 8; d++)
   {
      string lName = pfx + "D" + IntegerToString(d);
      if(ObjectFind(0, lName) < 0)
      {
         ObjectCreate(0, lName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, lName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetString(0, lName, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, lName, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, lName, OBJPROP_SELECTABLE, false);
      }
      int lx = cx + (int)(cosA[d] * (radius - 6));
      int ly = cy - (int)(sinA[d] * (radius - 6));
      bool active = (d == compassOct);
      ObjectSetInteger(0, lName, OBJPROP_XDISTANCE, lx);
      ObjectSetInteger(0, lName, OBJPROP_YDISTANCE, ly);
      ObjectSetString(0, lName, OBJPROP_TEXT, dirs[d]);
      ObjectSetInteger(0, lName, OBJPROP_FONTSIZE, active ? 10 : 7);
      ObjectSetInteger(0, lName, OBJPROP_COLOR, active ? activeClr : (color)0xFF606060);
   }

   // Centre +
   string ctrName = pfx + "CTR";
   if(ObjectFind(0, ctrName) < 0)
   {
      ObjectCreate(0, ctrName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ctrName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, ctrName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, ctrName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, ctrName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, ctrName, OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, ctrName, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, ctrName, OBJPROP_TEXT, "+");
   ObjectSetInteger(0, ctrName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, ctrName, OBJPROP_COLOR, (color)0xFFB0B0B0);

   // Aiguille momentum
   string ndlName = pfx + "NDL";
   if(ObjectFind(0, ndlName) < 0)
   {
      ObjectCreate(0, ndlName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ndlName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, ndlName, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(0, ndlName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, ndlName, OBJPROP_SELECTABLE, false);
   }
   double rad = g_smcGhostCompass * M_PI / 180.0;
   int nx = cx + (int)(MathCos(rad) * radius * 0.62);
   int ny = cy - (int)(MathSin(rad) * radius * 0.62);
   ObjectSetInteger(0, ndlName, OBJPROP_XDISTANCE, nx);
   ObjectSetInteger(0, ndlName, OBJPROP_YDISTANCE, ny);
   ObjectSetString(0, ndlName, OBJPROP_TEXT, CharToString(108));
   ObjectSetInteger(0, ndlName, OBJPROP_FONTSIZE, 16);
   ObjectSetInteger(0, ndlName, OBJPROP_COLOR, activeClr);

   // Titre + angle
   string hdrName = pfx + "HDR";
   if(ObjectFind(0, hdrName) < 0)
   {
      ObjectCreate(0, hdrName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, hdrName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, hdrName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, hdrName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, hdrName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, hdrName, OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, hdrName, OBJPROP_YDISTANCE, cy - radius - 12);
   ObjectSetString(0, hdrName, OBJPROP_TEXT, "ORDERFLOW COMPASS");
   ObjectSetInteger(0, hdrName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, hdrName, OBJPROP_COLOR, goldClr);

   string valName = pfx + "VAL";
   if(ObjectFind(0, valName) < 0)
   {
      ObjectCreate(0, valName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, valName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, valName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, valName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, valName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, valName, OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, valName, OBJPROP_YDISTANCE, cy + radius + 12);
   ObjectSetString(0, valName, OBJPROP_TEXT, dirs[compassOct] + " " + DoubleToString(g_smcGhostCompass, 0) + "\xB0");
   ObjectSetInteger(0, valName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, valName, OBJPROP_COLOR, activeClr);

   // Métriques OrderFlow sous la boussole
   string ofName = pfx + "OF";
   if(ObjectFind(0, ofName) < 0)
   {
      ObjectCreate(0, ofName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ofName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetString(0, ofName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, ofName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, ofName, OBJPROP_SELECTABLE, false);
   }
   string fluxTxt = isBull ? "FLUX ACHETEUR" : isBear ? "FLUX VENDEUR" : "NEUTRE";
   string ofTxt = "D" + (g_smcGhostDelta >= 0 ? "+" : "") + DoubleToString(g_smcGhostDelta, 0)
      + " | CVD" + (g_smcGhostCVD >= 0 ? "+" : "") + DoubleToString(g_smcGhostCVD, 0)
      + " | " + DoubleToString(g_smcGhostBuyPct, 0) + "%"
      + "\n" + fluxTxt;
   ObjectSetInteger(0, ofName, OBJPROP_XDISTANCE, cx - radius);
   ObjectSetInteger(0, ofName, OBJPROP_YDISTANCE, cy + radius + 28);
   ObjectSetString(0, ofName, OBJPROP_TEXT, ofTxt);
   ObjectSetInteger(0, ofName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, ofName, OBJPROP_COLOR, activeClr);
}

void SMCGP_DrawGOMDashboard()
{
   if(!ShowGOMDashboard) return;

   SMCGP_RefreshCorrectionWaitOverlay(_Symbol);

    static int g_smcLastGoodChartW = 1000;
    int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    // FIX deformation: pendant un reload/resize MT5, CHART_WIDTH_IN_PIXELS
    // renvoie 0 brièvement -> fallback 1200px étirait le dashboard HORS ecran
    // sur les fenetres < 1200px. On memorise la derniere largeur valide et on
    // refuse tout < 400px (borne conservative) au lieu d'un fallback fixe.
    if(chartW < 400)
       chartW = (g_smcLastGoodChartW > 0) ? g_smcLastGoodChartW : 1000;
    else
       g_smcLastGoodChartW = chartW;

   const int COLS = 9;
   const int cellH = SMC_DASH_ROW_H;
   const int gap = 2;
   const int marginLR = 10;
   const int marginBot = GOMDashboardY;
   int totalW = chartW - 2 * marginLR;
   int cellW = (totalW - (COLS - 1) * gap) / COLS;
   if(cellW < 60) cellW = 60;

    int y1 = marginBot;
    int y2 = marginBot + (cellH + gap) * 1;
    int y3 = marginBot + (cellH + gap) * 2;
    int y4 = marginBot + (cellH + gap) * 3;

   color cVerdict = SMCGP_VerdictColor(g_smcGomVerdictNum);
   color cBg = (color)SMC_DASH_C_BG;
   color cTxt = (color)SMC_DASH_C_TXT;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string sym = SMCGP_ResolveGOMSym(_Symbol);
   string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   int pollAge = (g_smcLastGOMPoll > 0) ? (int)(TimeCurrent() - g_smcLastGOMPoll) : -1;

   string connTxt = g_smcGomConnected ? "PY+MT5 OK" : "PY/MT5 OFF";
   if(!g_smcGomConnected && g_smcLastHttpCode > 0)
      connTxt = "HTTP " + IntegerToString(g_smcLastHttpCode);
   else if(!g_smcGomConnected && g_smcLastHttpCode == 0)
      connTxt = "NO WEBREQ";

   string verdLabel = g_smcGomVerdict;
   if(g_smcGomCorrectionWait && g_smcGomVerdictNumServer != 0)
      verdLabel = "WAIT ← " + g_smcGomVerdictServer;
   else if(g_smcGomVerdictNum >= 2 || g_smcGomVerdictNum <= -2) verdLabel += " *";
   if(g_smcGomVerdictReactiveNum != 0 || g_smcGomVerdictForecastNum != 0)
      verdLabel += StringFormat(" [R:%d F:%d]", g_smcGomVerdictReactiveNum, g_smcGomVerdictForecastNum);

    int xCur = marginLR;
   int vn = g_smcGomVerdictNum;
   string scoreTxt = verdLabel + " B:" + DoubleToString(g_smcGomScoreBuy, 1) +
                      " S:" + DoubleToString(g_smcGomScoreSell, 1) +
                      " v" + IntegerToString(vn);
   SMCGP_DrawDashCell("V1_SCORE", xCur, y1, cellW, cellH, scoreTxt, cVerdict, cTxt);

   xCur += cellW + gap;
   color cRSI = (g_smcGomRsi < 35) ? (color)SMC_DASH_C_BUY :
                (g_smcGomRsi > 65) ? (color)SMC_DASH_C_SELL : cBg;
   string rsiAlertTxt = "";
   if(g_smcGomRsi < 28)        rsiAlertTxt = " SVRTE!";
   else if(g_smcGomRsi > 72)   rsiAlertTxt = " SRCHT!";
   SMCGP_DrawDashCell("V1_RSI", xCur, y1, cellW, cellH,
      "RSI " + IntegerToString(g_smcGomRsi) + rsiAlertTxt, cRSI, cTxt);

   xCur += cellW + gap;
   color cQ = (g_smcGomQuality >= 60) ? (color)SMC_DASH_C_BUY :
              (g_smcGomQuality >= 35) ? (color)SMC_DASH_C_NEUTRAL : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("V1_QUAL", xCur, y1, cellW, cellH,
                      "Q:" + DoubleToString(g_smcGomQuality, 0) + "% C:" +
                      DoubleToString(g_smcGomCoherence, 0) + "%", cQ, cTxt);

   xCur += cellW + gap;
   string spikeLvlTxt[] = {"ATTENTE","EARLY","WATCH","IMMINENT","SPIKE"};
   int sl = MathMax(0, MathMin(g_smcGomSpikeLevel, 4));
   string slTxt = spikeLvlTxt[sl];
   SMCGP_DrawDashCell("V1_PRICE", xCur, y1, cellW, cellH,
                      DoubleToString(g_smcGomPrice, dg) + " " + slTxt + " " +
                      DoubleToString(g_smcGomSpikePct, 0) + "%", cBg, cTxt);

   xCur += cellW + gap;
   SMCGP_DrawDashCell("V1_KB", xCur, y1, cellW, cellH,
                      "KBuy " + DoubleToString(g_smcGomKolaBuy, 2), (color)SMC_DASH_C_BUY, cTxt);

   xCur += cellW + gap;
   SMCGP_DrawDashCell("V1_KS", xCur, y1, cellW, cellH,
                      "KSell " + DoubleToString(g_smcGomKolaSell, 2), (color)SMC_DASH_C_SELL, cTxt);

xCur += cellW + gap;
    {
       double probScore = SMC_ComputeEntryProbability(0);
       color  cProb = !UseHighProbabilityFilter ? cBg
                    : (probScore >= MinEntryProbabilityPct) ? (color)SMC_DASH_C_BUY
                                                            : (color)SMC_DASH_C_SELL;
       string probTxt;
       if(!UseHighProbabilityFilter)
       {
          probTxt = "P:" + DoubleToString(probScore, 0) + "% OFF";
       }
       else if(probScore >= MinEntryProbabilityPct)
       {
          probTxt = "P:" + DoubleToString(probScore, 0) + "% >=" + DoubleToString(MinEntryProbabilityPct, 0);
       }
       else
       {
          probTxt = "P:" + DoubleToString(probScore, 0) + "% <" + DoubleToString(MinEntryProbabilityPct, 0);
       }
       SMCGP_DrawDashCell("V1_PIPE", xCur, y1, cellW, cellH, probTxt, cProb, cTxt);
    }

   xCur += cellW + gap;
   color cGlob = (g_smcGomGlobalStr >= GOMGlobalMinConfidence) ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("V1_GLOB", xCur, y1, cellW, cellH,
                      SMCGP_TfShort(g_smcGomGlobalDir) + " " + IntegerToString(g_smcGomGlobalStr) + "%",
                      cGlob, cTxt);

   xCur += cellW + gap;
   string srcTxt = g_smcGomSource;
   if(pollAge >= 0) srcTxt += " " + IntegerToString(pollAge) + "s";
   SMCGP_DrawDashCell("V1_SRC", xCur, y1, cellW, cellH, srcTxt, cBg, cTxt);

    // ── RANGÉE NOUVEAUX INDICATEURS (y2) ──────────────────────────────
   xCur = marginLR;

   // Cell 1: RSI Squeeze (Boom/Crash only)
   bool squeezeAvailable = UseRSISqueezePredictor && SMC_IsSpikeStyleSymbol(_Symbol);
   string sqzTxt = squeezeAvailable
      ? "SQZ " + DoubleToString(g_dashSqueezeRSI, 1) + (g_dashSqueezeActive ? " ON!" : "")
      : "SQZ ---";
   color cSqz = g_dashSqueezeActive ? (color)0xFF00E676 : (g_dashH1Aligned ? (color)SMC_DASH_C_NEUTRAL : cBg);
   SMCGP_DrawDashCell("I0_SQZ", xCur, y2, cellW, cellH, sqzTxt, cSqz, cTxt);

   // Cell 2: Impulse Support (20 bars)
   xCur += cellW + gap;
   string impSupTxt = (g_impulseSupport20 > 0)
      ? "SUP " + DoubleToString(g_impulseSupport20, dg) + (g_impulseSupTouched ? " !" : "")
      : "SUP ---";
   color cImpSup = g_impulseSupTouched ? (color)0xFF00E676 : cBg;
   SMCGP_DrawDashCell("I1_SUP", xCur, y2, cellW, cellH, impSupTxt, cImpSup, cTxt);

   // Cell 3: Impulse Resistance (20 bars)
   xCur += cellW + gap;
   string impResTxt = (g_impulseResistance20 > 0)
      ? "RES " + DoubleToString(g_impulseResistance20, dg) + (g_impulseResTouched ? " !" : "")
      : "RES ---";
   color cImpRes = g_impulseResTouched ? (color)0xFFFF1744 : cBg;
   SMCGP_DrawDashCell("I2_RES", xCur, y2, cellW, cellH, impResTxt, cImpRes, cTxt);

   // Cell 4: TP1 $1 Status
   xCur += cellW + gap;
   string tp1StatTxt;
   color cTp1Stat;
   if(!TakeProfitAt1Dollar) { tp1StatTxt = "TP1 OFF"; cTp1Stat = cBg; }
   else if(g_tp1WaitingReEntry) { tp1StatTxt = "TP1 WAIT RE"; cTp1Stat = (color)0xFFFF6D00; }
   else if(g_tp1LastCloseTime > 0 && TimeCurrent() - g_tp1LastCloseTime < 120)
      { tp1StatTxt = "TP1 $1 HIT"; cTp1Stat = (color)0xFF00E676; }
   else { tp1StatTxt = "TP1 ARMED"; cTp1Stat = cBg; }
   SMCGP_DrawDashCell("I3_TP1", xCur, y2, cellW, cellH, tp1StatTxt, cTp1Stat, cTxt);

   // Cell 5: CloseOnVerdictWait status
   xCur += cellW + gap;
   string waitTxt;
   color cWait;
   if(!UseCloseOnVerdictWait) { waitTxt = "WAIT OFF"; cWait = cBg; }
   else if(g_smcGomVerdictNum == 0 && CountPositionsForSymbol(_Symbol) > 0) { waitTxt = "WAIT CLOSE!"; cWait = (color)0xFFFF1744; }
   else { waitTxt = "WAIT ARMED"; cWait = cBg; }
   SMCGP_DrawDashCell("I4_WAIT", xCur, y2, cellW, cellH, waitTxt, cWait, cTxt);

   // Cell 6: GOM TF Alignment
   xCur += cellW + gap;
   string alignDir = "";
   bool aligned = AreAllTimeframesAligned(alignDir);
   string alignTxt = aligned ? ("6TF " + alignDir) : "6TF MIXED";
   color cAlign = aligned ? ((alignDir == "BUY") ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL) : (color)SMC_DASH_C_NEUTRAL;
   SMCGP_DrawDashCell("I5_ALIGN", xCur, y2, cellW, cellH, alignTxt, cAlign, cTxt);

    // Cell 8: Propice Score
   xCur += cellW + gap;
   int propScore2 = SMC_ComputePropiceScore();
   bool propOK2   = (!UsePropitiousScore || GOMMinPropiceScore <= 0 || propScore2 >= GOMMinPropiceScore);
   color cProp2   = propOK2 ? (propScore2 >= 85 ? (color)0xFF00E676 : (color)SMC_DASH_C_BUY)
                            : (propScore2 >= 55 ? (color)SMC_DASH_C_NEUTRAL : (color)SMC_DASH_C_SELL);
   string propTxt2 = "PROP " + IntegerToString(propScore2) + "/100";
   if(!UsePropitiousScore || GOMMinPropiceScore <= 0) propTxt2 += " OFF";
   else propTxt2 += (propOK2 ? " OK" : " /" + IntegerToString(GOMMinPropiceScore));
   SMCGP_DrawDashCell("I7_PROP", xCur, y2, cellW, cellH, propTxt2, cProp2, cTxt);

   // Cell 9: Cognition (compact)
   xCur += cellW + gap;
   bool cogOk2 = (g_cogStrength >= CognitionMinStrength && g_cogConfidence >= CognitionMinConfidence);
   double confCog2 = g_cogConfidence * 100.0;
   if(confCog2 <= 0.0 && g_cogShortConfidence > 0.0) confCog2 = g_cogShortConfidence * 100.0;
   string cogDir2 = (StringLen(g_cogDirection) > 0 && g_cogDirection != "NEUTRAL") ? g_cogDirection : "---";
   string cogTxt2 = cogDir2 + " " + DoubleToString(confCog2, 0) + "%";
   color cCog2 = cogOk2 ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("I8_COG", xCur, y2, cellW, cellH, cogTxt2, cCog2, cTxt);

   // ── RANGÉE GHOST + SESSION FUSIONNÉE (y3) ─────────────────────────
   xCur = marginLR;

   // Cell 1: CVD + Delta (compact)
   color cCVD = (g_smcGhostCVD >= 0) ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("G0_CVD", xCur, y3, cellW, cellH,
                      "CVD" + (g_smcGhostCVD >= 0 ? "+" : "") + DoubleToString(g_smcGhostCVD, 0) +
                      " D" + (g_smcGhostDelta >= 0 ? "+" : "") + DoubleToString(g_smcGhostDelta, 0), cCVD, cTxt);

   // Cell 2: Sentiment (compact)
   xCur += cellW + gap;
   color cSent = (g_smcGhostBuyPct > 60) ? (color)SMC_DASH_C_BUY :
                 (g_smcGhostBuyPct < 40) ? (color)SMC_DASH_C_SELL : (color)SMC_DASH_C_NEUTRAL;
   SMCGP_DrawDashCell("G2_SNT", xCur, y3, cellW, cellH,
                      "BUY " + DoubleToString(g_smcGhostBuyPct, 0) + "%", cSent, cTxt);

   // Cell 3: Compass + Ghost (compact)
   xCur += cellW + gap;
   int compassOct = (int)((g_smcGhostCompass + 22.5) / 45.0) % 8;
   static const string compassLbls[8] = {"E>", "NE", "N^", "NW", "W<", "SW", "Sv", "SE"};
   bool compassBull = (compassOct == 0 || compassOct == 1 || compassOct == 2 || compassOct == 7);
   int ghostBull = 0, ghostBear = 0;
   if(g_smcGhostCVD > 0) ghostBull++; else if(g_smcGhostCVD < 0) ghostBear++;
   if(g_smcGhostDelta > 0) ghostBull++; else if(g_smcGhostDelta < 0) ghostBear++;
   if(g_smcGhostBuyPct > 55) ghostBull++; else if(g_smcGhostBuyPct < 45) ghostBear++;
   if(compassBull) ghostBull++; else ghostBear++;
   color cCmp = compassBull ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   string cmpTxt = compassLbls[compassOct] + " G" + IntegerToString(ghostBull) + "/" + IntegerToString(ghostBear);
   SMCGP_DrawDashCell("G3_CMP", xCur, y3, cellW, cellH, cmpTxt, cCmp, cTxt);

   // Cell 4: Concordance
   xCur += cellW + gap;
   string concTxt = (g_pathConcordancePct > 0.0)
      ? ("CONC " + DoubleToString(g_pathConcordancePct, 0) + "%")
      : "CONC ---";
   if(g_pathTrailBonusActive)
      concTxt = "PATH+" + DoubleToString(g_pathConcordancePct, 0) + "%";
   color cConc = g_pathTrailBonusActive ? (color)0xFF00E676
               : (g_pathConcordancePct >= 65.0) ? (color)SMC_DASH_C_BUY
               : (g_pathConcordancePct >= 45.0) ? (color)SMC_DASH_C_NEUTRAL
               : (g_pathConcordancePct > 0.0) ? (color)SMC_DASH_C_SELL
               : cBg;
   SMCGP_DrawDashCell("G5B_CONC", xCur, y3, cellW, cellH, concTxt, cConc, cTxt);

   // Cell 5: IA (compact)
   xCur += cellW + gap;
   string iaTxt2; color cIA2;
   if(!UseAIServer) { iaTxt2 = "IA OFF"; cIA2 = cBg; }
   else
   {
      string displayAction2 = (StringLen(g_smcIAStatusAction) > 0) ? g_smcIAStatusAction : g_lastAIAction;
      double displayConf2   = (g_iaStatusConfidence > 0.0) ? g_iaStatusConfidence : g_lastAIConfidence * 100.0;
      StringToUpper(displayAction2);
      if(displayAction2 == "" || displayAction2 == "HOLD") { iaTxt2 = "IA " + DoubleToString(displayConf2, 0) + "%"; cIA2 = (color)SMC_DASH_C_NEUTRAL; }
      else { iaTxt2 = "IA " + displayAction2 + " " + DoubleToString(displayConf2, 0) + "%"; cIA2 = (displayAction2 == "BUY") ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL; }
   }
   SMCGP_DrawDashCell("G6_IA", xCur, y3, cellW, cellH, iaTxt2, cIA2, cTxt);

   // Cell 6: Correction Cycle (compact)
   xCur += cellW + gap;
   string corrTxt2 = g_smcCorrPhase + " " + DoubleToString(g_smcCorrExhaustPct, 0) + "%";
   if(StringLen(g_smcCorrType) > 0) corrTxt2 = g_smcCorrType + " " + DoubleToString(g_smcCorrExhaustPct, 0) + "%";
   color cCorr2 = g_smcCorrEntrySafe ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   if(g_smcCorrExhaustPct >= 45 && !g_smcCorrEntrySafe) cCorr2 = (color)SMC_DASH_C_NEUTRAL;
   SMCGP_DrawDashCell("G6B_CORR", xCur, y3, cellW, cellH, corrTxt2, cCorr2, cTxt);

   // Cell 7: READINESS + CB (compact)
   xCur += cellW + gap;
   string rdyStatus2 = g_readinessCBActive ? "HALT"
                     : g_readinessCBSymbolCool ? "COOL"
                     : g_readinessGo ? "GO" : "NO-GO";
   string rdyTxt2 = "RDY " + IntegerToString(g_readinessScore) + " " + rdyStatus2;
   color cRdy2 = g_readinessCBActive ? (color)SMC_DASH_C_SELL
               : g_readinessCBSymbolCool ? (color)0xFFE65100
               : g_readinessGo ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_NEUTRAL;
   SMCGP_DrawDashCell("R0_RDY", xCur, y3, cellW, cellH, rdyTxt2, cRdy2, cTxt);

   // Cell 8: Discipline + Target (compact)
   xCur += cellW + gap;
   bool discBlocked2 = (g_dailyTradeCount >= MaxDailyTrades);
   string discTxt2 = IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(MaxDailyTrades);
   if(g_dailyTargetHit) discTxt2 += " OBJ";
   color cDisc2 = discBlocked2 ? (color)SMC_DASH_C_SELL
               : (g_dailyTradeCount >= MaxDailyTrades * 7 / 10) ? (color)SMC_DASH_C_NEUTRAL : (color)SMC_DASH_C_BUY;
   SMCGP_DrawDashCell("R4_DISC", xCur, y3, cellW, cellH, discTxt2, cDisc2, cTxt);

   // Cell 9: UTC + Spike Zone (compact)
   xCur += cellW + gap;
   MqlDateTime dtUtc2; TimeGMT(dtUtc2);
   string utcTxt2 = StringFormat("%02d:%02d", dtUtc2.hour, dtUtc2.min);
   bool wtOpen2 = (dtUtc2.hour >= 4 && dtUtc2.hour < 16);
   if(SMCGP_IsBoomCrashSym(_Symbol)) utcTxt2 += wtOpen2 ? " O" : " X";
   string zoneAdd2 = "";
   color cZone2 = cBg;
   if(g_spikeBonusPts >= 20)      { zoneAdd2 = " H!"; cZone2 = (color)0xFFFF6D00; }
   else if(g_spikeBonusPts >= 10) { zoneAdd2 = " +10"; cZone2 = (color)SMC_DASH_C_NEUTRAL; }
   SMCGP_DrawDashCell("R8_ZONE", xCur, y3, cellW, cellH, utcTxt2 + zoneAdd2, cZone2, cTxt);

   if(ShowOrderFlowCompass)
      SMCGP_DrawOrderFlowCompass(chartW, marginBot, cellH, gap);
   else
      SMCGP_CleanupOrderFlowCompass();

   // ── Pure Momentum Row (y4) ────────────────────────────────────────
   if(UsePureMomentumGate && SMC_IsPureMomentumSymbol(_Symbol))
   {
      int pmDirSign = 0;
      if(g_lastAIAction == "BUY" || g_lastAIAction == "buy") pmDirSign = 1;
      else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell") pmDirSign = -1;

      int pmPillars = 0;
      int pmScore = (pmDirSign != 0) ? SMC_PureMomentumScore(pmDirSign, pmPillars) : 0;
      bool pmActive = (pmDirSign != 0);
      color cPmBg = (color)0x1A237E;  // Dark indigo background

      // Cell 1: PM Header
      xCur = marginLR;
      string pmHdr = pmActive ? "PURE MOMENTUM " + IntegerToString(pmScore) + "/5" : "PM OFF";
      color cPmHdr = (pmScore >= 4) ? (color)SMC_DASH_C_BUY :
                     (pmScore >= 2) ? (color)SMC_DASH_C_NEUTRAL : (color)SMC_DASH_C_SELL;
      SMCGP_DrawDashCell("PM_HDR", xCur, y4, cellW, cellH, pmHdr, cPmHdr, cTxt);

      // Pillar 1: EMA Alignment
      xCur += cellW + gap;
      bool emaOk = false;
      if(pmActive && emaFastM1 != INVALID_HANDLE && emaSlowM1 != INVALID_HANDLE)
      {
         double emaF[], emaS[];
         ArraySetAsSeries(emaF, true);
         ArraySetAsSeries(emaS, true);
         if(CopyBuffer(emaFastM1, 0, 0, 1, emaF) > 0 && CopyBuffer(emaSlowM1, 0, 0, 1, emaS) > 0)
            emaOk = pmDirSign > 0 ? (emaF[0] > emaS[0]) : (emaF[0] < emaS[0]);
      }
      SMCGP_DrawDashCell("PM_P1", xCur, y4, cellW, cellH, "EMA " + (emaOk ? "OK" : "NO"),
                         emaOk ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL, cTxt);

      // Pillar 2: RSI Extreme
      xCur += cellW + gap;
      bool rsiOk = false;
      if(pmActive && pmRsiM1 != INVALID_HANDLE)
      {
         double rsiBuf[];
         ArraySetAsSeries(rsiBuf, true);
         if(CopyBuffer(pmRsiM1, 0, 0, 1, rsiBuf) > 0)
         {
            if(pmDirSign > 0) rsiOk = (rsiBuf[0] >= PureMomentumRSIBuyLevel);
            else              rsiOk = (rsiBuf[0] <= PureMomentumRSISellLevel);
         }
      }
      string rsiTxt = rsiOk ? "RSI OK" : "RSI NO";
      if(pmActive && pmRsiM1 != INVALID_HANDLE)
      {
         double rsiBuf2[];
         ArraySetAsSeries(rsiBuf2, true);
         if(CopyBuffer(pmRsiM1, 0, 0, 1, rsiBuf2) > 0)
            rsiTxt = "RSI " + DoubleToString(rsiBuf2[0], 0) + (rsiOk ? " OK" : " NO");
      }
      SMCGP_DrawDashCell("PM_P2", xCur, y4, cellW, cellH, rsiTxt,
                         rsiOk ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL, cTxt);

      // Pillar 3: Stochastic Extreme
      xCur += cellW + gap;
      bool stochOk = false;
      if(pmActive && pmStochM1 != INVALID_HANDLE)
      {
         double stochK[], stochD[];
         ArraySetAsSeries(stochK, true);
         ArraySetAsSeries(stochD, true);
         if(CopyBuffer(pmStochM1, 0, 0, 1, stochK) > 0 && CopyBuffer(pmStochM1, 1, 0, 1, stochD) > 0)
         {
            if(pmDirSign > 0) stochOk = (stochK[0] >= PureMomentumStochBuyLevel && stochK[0] > stochD[0]);
            else              stochOk = (stochK[0] <= PureMomentumStochSellLevel && stochK[0] < stochD[0]);
         }
      }
      SMCGP_DrawDashCell("PM_P3", xCur, y4, cellW, cellH, "STCH " + (stochOk ? "OK" : "NO"),
                         stochOk ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL, cTxt);

      // Pillar 4: HTF M5 Candle
      xCur += cellW + gap;
      bool htfOk = false;
      if(pmActive)
      {
         MqlRates m5Rates[];
         ArraySetAsSeries(m5Rates, true);
         if(CopyRates(_Symbol, PERIOD_M5, 0, 2, m5Rates) >= 1)
         {
            double body = m5Rates[0].close - m5Rates[0].open;
            double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double minBody = 50.0 * pointVal;
            htfOk = pmDirSign > 0 ? (body > minBody) : (body < -minBody);
         }
      }
      SMCGP_DrawDashCell("PM_P4", xCur, y4, cellW, cellH, "M5 " + (htfOk ? "OK" : "NO"),
                         htfOk ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL, cTxt);

      // Pillar 5: Retracement
      xCur += cellW + gap;
      bool retOk = false;
      if(pmActive)
      {
         MqlRates m1Rates[];
         ArraySetAsSeries(m1Rates, true);
         if(CopyRates(_Symbol, PERIOD_M1, 0, 6, m1Rates) >= 6)
         {
            double totalMove = 0, maxRetrace = 0;
            for(int i = 1; i <= 5; i++)
               totalMove += m1Rates[i-1].close - m1Rates[i].close;
            for(int i = 1; i <= 5; i++)
            {
               double delta = m1Rates[i-1].close - m1Rates[i].close;
               bool isRetrace = pmDirSign > 0 ? (delta < 0) : (delta > 0);
               if(isRetrace)
               {
                  double rAmt = MathAbs(delta);
                  if(rAmt > maxRetrace) maxRetrace = rAmt;
               }
            }
            double maxAllowed = MathAbs(totalMove) * PureMomentumMaxRetracePct / 100.0;
            retOk = (maxRetrace <= maxAllowed);
         }
      }
      SMCGP_DrawDashCell("PM_P5", xCur, y4, cellW, cellH, "RET " + (retOk ? "OK" : "NO"),
                         retOk ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL, cTxt);

      // Cells 6-9: Status text
      xCur += cellW + gap;
      string pmStatus = "";
      if(pmScore >= 4) pmStatus = "ALLOWED";
      else if(pmScore >= 2) pmStatus = "WEAK";
      else pmStatus = "BLOCKED";
      color cPmStat = (pmScore >= 4) ? (color)SMC_DASH_C_BUY :
                      (pmScore >= 2) ? (color)SMC_DASH_C_NEUTRAL : (color)SMC_DASH_C_SELL;
      SMCGP_DrawDashCell("PM_STAT", xCur, y4, cellW, cellH, pmStatus, cPmStat, cTxt);

      xCur += cellW + gap;
      SMCGP_DrawDashCell("PM_DIR", xCur, y4, cellW, cellH,
                         pmDirSign > 0 ? "BUY" : pmDirSign < 0 ? "SELL" : "---",
                         pmDirSign > 0 ? (color)SMC_DASH_C_BUY :
                         pmDirSign < 0 ? (color)SMC_DASH_C_SELL : cBg, cTxt);

      xCur += cellW + gap;
      SMCGP_DrawDashCell("PM_FILL", xCur, y4, cellW * 2, cellH, "", cBg, cTxt);
   }

   ChartRedraw(0);
}

void SMCGP_UploadCandles()
{
   if(!GOMUploadCandles) return;
   if(g_smcCandlesUploader == NULL) return;
   int intervalSec = MathMax(60, GOMUploadIntervalMin * 60);
   if((int)(TimeCurrent() - g_smcLastCandleUpload) < intervalSec) return;
   g_smcLastCandleUpload = TimeCurrent();

   string sym = SMCGP_ResolveGOMSym(_Symbol);
   Print("[GOM-UPLOAD] Envoi candles MT5 → ai_server pour ", sym);
   g_smcCandlesUploader.UploadAllTimeframes(sym);

   // Market Watch Deriv — M15 pour les symboles visibles (rotation)
   static int s_watchRot = 0;
   int total = SymbolsTotal(true);
   int batch = MathMin(10, MathMax(total, 0));
   for(int k = 0; k < batch && total > 0; k++)
   {
      int idx = (s_watchRot + k) % total;
      string wsym = SymbolName(idx, true);
      if(wsym == "" || wsym == sym) continue;
      g_smcCandlesUploader.UploadCandles(wsym, PERIOD_M1, 80);
      Sleep(200);
      g_smcCandlesUploader.UploadCandles(wsym, PERIOD_M15, 120);
      Sleep(250);
   }
   if(total > 0) s_watchRot = (s_watchRot + batch) % total;
}

void SMCGP_OnTimer()
{
   // GOM poll + dashboard: indépendant par graphique (ChartID), même en UltraLightMode
   if(ShowGOMDashboard || UseGOMVerdictFilter || UseGOMPipeline)
   {
      SMCGP_PollGOM();
      if(ShowGOMDashboard)
         SMCGP_DrawGOMDashboard();
      else if(ShowOrderFlowCompass)
      {
         int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
         if(chartW < 400) chartW = 1200;
         SMCGP_DrawOrderFlowCompass(chartW, GOMDashboardY, SMC_DASH_ROW_H, 2);
      }
      else
         SMCGP_CleanupOrderFlowCompass();
   }

   if(UseAIServer && MT5DashboardSync())
   {
      SMCGP_SendDashboardLive();
      SMCGP_PollServerLossGuard();
   }

    // Dessins chart (EMA 200 + session asiatique + signal GOM)
    SMCGP_DrawEMA200();
    SMCGP_DrawAsianSession();
    SMCGP_DrawGOMSignal();

    // Timer pour le clignotement du signal central GOM (version blinking)
    static datetime s_lastSignalDraw = 0;
    if(TimeCurrent() - s_lastSignalDraw >= 2)
    {
        SMCGP_DrawGOMSignal();
        s_lastSignalDraw = TimeCurrent();
    }

    if(UltraLightMode) return;

   SMCGP_UploadCandles();
   if(GOMSyncSymbolToTV)
      SMCGP_SendHeartbeat();
   if(!BlockAllTrades)
      SMCGP_PollAndExecutePipeline();
}

void SMCGP_ParsePredictionArrays(const string &body)
{
   // Parser les arrays JSON pour prédictions Bollinger Bands
   // Format: "pred_bb_mid": [1.0, 1.1, 1.2, ...], "pred_bb_up": [...], "pred_bb_dn": [...]

   // Vider les anciens arrays
   ArrayFree(g_smcPredBbMid);
   ArrayFree(g_smcPredBbUp);
   ArrayFree(g_smcPredBbDn);

   // Parser pred_bb_mid
   int pos_mid = StringFind(body, "\"pred_bb_mid\"");
   if(pos_mid >= 0)
   {
      int start_bracket = StringFind(body, "[", pos_mid);
      int end_bracket = StringFind(body, "]", start_bracket);
      if(start_bracket >= 0 && end_bracket > start_bracket)
      {
         string arr_str = StringSubstr(body, start_bracket + 1, end_bracket - start_bracket - 1);
         SMCGP_ParseDoubleArray(arr_str, g_smcPredBbMid);
      }
   }

   // Parser pred_bb_up
   int pos_up = StringFind(body, "\"pred_bb_up\"");
   if(pos_up >= 0)
   {
      int start_bracket = StringFind(body, "[", pos_up);
      int end_bracket = StringFind(body, "]", start_bracket);
      if(start_bracket >= 0 && end_bracket > start_bracket)
      {
         string arr_str = StringSubstr(body, start_bracket + 1, end_bracket - start_bracket - 1);
         SMCGP_ParseDoubleArray(arr_str, g_smcPredBbUp);
      }
   }

   // Parser pred_bb_dn
   int pos_dn = StringFind(body, "\"pred_bb_dn\"");
   if(pos_dn >= 0)
   {
      int start_bracket = StringFind(body, "[", pos_dn);
      int end_bracket = StringFind(body, "]", start_bracket);
      if(start_bracket >= 0 && end_bracket > start_bracket)
      {
         string arr_str = StringSubstr(body, start_bracket + 1, end_bracket - start_bracket - 1);
         SMCGP_ParseDoubleArray(arr_str, g_smcPredBbDn);
      }
   }

   if(ArraySize(g_smcPredBbMid) > 0)
      Print("[SMCGP] Prédictions BB chargées: ", ArraySize(g_smcPredBbMid), " points");
}

void SMCGP_ParseJsonArrayKey(const string &body, const string key, double &arr[])
{
   ArrayFree(arr);
   int pos = StringFind(body, "\"" + key + "\"");
   if(pos < 0) return;
   int start_bracket = StringFind(body, "[", pos);
   int end_bracket = StringFind(body, "]", start_bracket);
   if(start_bracket < 0 || end_bracket <= start_bracket) return;
   string arr_str = StringSubstr(body, start_bracket + 1, end_bracket - start_bracket - 1);
   SMCGP_ParseDoubleArray(arr_str, arr);
}

void SMCGP_ParseCognitionArrays(const string &body)
{
   SMCGP_ParseJsonArrayKey(body, "pred_path_mid", g_smcPredPathMid);
   SMCGP_ParseJsonArrayKey(body, "pred_path_up", g_smcPredPathUp);
   SMCGP_ParseJsonArrayKey(body, "pred_path_dn", g_smcPredPathDn);
   SMCGP_ParseJsonArrayKey(body, "cog_fc_open", g_smcCogOpen);
   SMCGP_ParseJsonArrayKey(body, "cog_fc_high", g_smcCogHigh);
   SMCGP_ParseJsonArrayKey(body, "cog_fc_low", g_smcCogLow);
   SMCGP_ParseJsonArrayKey(body, "cog_fc_close", g_smcCogClose);
   SMCGP_ParseJsonArrayKey(body, "cog_fc_q10", g_smcCogQ10);
   SMCGP_ParseJsonArrayKey(body, "cog_fc_q90", g_smcCogQ90);

   if(ArraySize(g_smcCogClose) == 0 && ArraySize(g_smcPredPathMid) > 0)
      ArrayCopy(g_smcCogClose, g_smcPredPathMid);

   if(ArraySize(g_smcPredPathMid) > 0 || ArraySize(g_smcCogClose) > 0)
      Print("[SMCGP] Cognition path: ", ArraySize(g_smcCogClose), " bougies | ",
            g_cogDirection, " str=", DoubleToString(g_cogStrength, 2),
            " conf=", DoubleToString(g_cogConfidence, 2));
}

void SMCGP_ParseDoubleArray(const string &csv, double &arr[])
{
   // Parser une chaîne CSV "1.0,1.1,1.2" en tableau de doubles
   ArrayFree(arr);

   int count = 0;
   int pos = 0;
   while(pos < StringLen(csv))
   {
      int comma = StringFind(csv, ",", pos);
      if(comma < 0) comma = StringLen(csv);

      string val_str = StringSubstr(csv, pos, comma - pos);
      StringTrimLeft(val_str);
      StringTrimRight(val_str);

      if(StringLen(val_str) > 0)
      {
         double val = StringToDouble(val_str);
         ArrayResize(arr, count + 1);
         arr[count] = val;
         count++;
      }

      pos = comma + 1;
   }
}

void SMCGP_Init()
{
   g_smcDashPrefix = "SMC_DASH_" + IntegerToString((long)ChartID()) + "_";
   g_smcGomVerdict = "WAIT";
   g_smcGomVerdictNum = 0;
   g_smcGomVerdictNumPrev = 999;
   g_smcGomVerdictPrev = "";
   g_smcGomForceExhausted = false;
   g_smcGomNotifReady = false;
   g_smcGomSpikeLevel = 0;
   g_smcGomSpikeLevelPrev = -1;
   g_smcSpikeNotifReady = false;
   g_smcGomSpikeTradablePrev = false;
   if(g_smcCandlesUploader != NULL)
   {
      delete g_smcCandlesUploader;
      g_smcCandlesUploader = NULL;
   }
   if(GOMUploadCandles)
   {
      string sym = SMCGP_ResolveGOMSym(_Symbol);
      g_smcCandlesUploader = new MT5CandlesUploader(sym, AI_ServerURL);
      g_smcLastCandleUpload = 0;
   }
   if(g_pipelineEma9Handle != INVALID_HANDLE)
   { IndicatorRelease(g_pipelineEma9Handle); g_pipelineEma9Handle = INVALID_HANDLE; }
   g_pipelineEma9Handle = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   if(g_pipelineEma200Handle != INVALID_HANDLE)
   { IndicatorRelease(g_pipelineEma200Handle); g_pipelineEma200Handle = INVALID_HANDLE; }
   g_pipelineEma200Handle = iMA(_Symbol, PERIOD_M5, 200, 0, MODE_EMA, PRICE_CLOSE);

   Print("[SMC-GOM] Module actif | symbole=", _Symbol,
         " | Pipeline=", UseGOMPipeline ? "ON" : "OFF",
         " | GOM=", UseGOMVerdictFilter ? "ON" : "OFF",
         " | TV sync=", ShowTVSyncedLevels ? "ON" : "OFF",
         " | Dashboard=", ShowGOMDashboard ? "ON" : "OFF",
         " | Heartbeat=", GOMSyncSymbolToTV ? "ON" : "OFF",
         " | CandlesUpload=", GOMUploadCandles ? "ON" : "OFF",
         " | Serveur=", AI_ServerURL,
         " | Render fallback=", AI_ServerRender);
   string pingBody;
   if(SMCGP_HttpGet("/health", pingBody, 3000))
      Print("[SMC-GOM] ai_server OK — GOM local MT5 actif");
   else
      Print("[SMC-GOM] ai_server INJOIGNABLE (HTTP ", g_smcLastHttpCode,
            ") — verdict GOM indisponible tant que WebRequest + serveur ne sont pas OK");
   if(UseAIServer && MT5DashboardSync())
      SMCGP_SendDashboardLive(true);
}

void SMCGP_Deinit()
{
   ObjectDelete(0, "SMC_EMA200_LINE");
   ObjectDelete(0, "SMC_EMA200_LABEL");
   ObjectDelete(0, "SMC_ASIAN_SESSION");
   ObjectDelete(0, "SMC_ASIAN_LABEL");
   ObjectDelete(0, "SMC_GOM_SIGNAL");
   ObjectDelete(0, "SMC_GOM_SIGNAL_BG");
   if(g_smcCandlesUploader != NULL)
   {
      delete g_smcCandlesUploader;
      g_smcCandlesUploader = NULL;
   }
   if(g_pipelineEma9Handle != INVALID_HANDLE)
     { IndicatorRelease(g_pipelineEma9Handle); g_pipelineEma9Handle = INVALID_HANDLE; }
   if(g_pipelineEma200Handle != INVALID_HANDLE)
     { IndicatorRelease(g_pipelineEma200Handle); g_pipelineEma200Handle = INVALID_HANDLE; }
}

// ── Price Action Zone helpers ──────────────────────────────────────
bool SMCGP_UpdatePriceInActionZone(const string sym = "")
{
    g_smcPaPriceInZone = false;
    if(g_smcPaZoneSupport <= 0 || g_smcPaZoneResistance <= 0)
       return false;

    string s = (StringLen(sym) > 0) ? sym : _Symbol;
    double zLo = MathMin(g_smcPaZoneSupport, g_smcPaZoneResistance);
    double zHi = MathMax(g_smcPaZoneSupport, g_smcPaZoneResistance);
    if(zHi <= zLo) return false;

    double point = SymbolInfoDouble(s, SYMBOL_POINT);
    int dg = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
    double tol = (dg <= 3) ? point * 3.0 : point * 8.0;
    double bid = SymbolInfoDouble(s, SYMBOL_BID);
    g_smcPaPriceInZone = (bid >= zLo - tol && bid <= zHi + tol);
    return g_smcPaPriceInZone;
}

bool SMCGP_PriceActionBlocksEntry(const string sym = "")
{
    if(!g_usePriceActionZoneGate) return false;
    if(g_smcPaZoneSupport <= 0 || g_smcPaZoneResistance <= 0) return false;
    if(!SMCGP_UpdatePriceInActionZone(sym)) return false;
    return true;
}

string SMCGP_PriceActionBlockReason(const string sym = "")
{
    if(!SMCGP_PriceActionBlocksEntry(sym)) return "";
    string s = (StringLen(sym) > 0) ? sym : _Symbol;
    int dg = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
    double zLo = MathMin(g_smcPaZoneSupport, g_smcPaZoneResistance);
    double zHi = MathMax(g_smcPaZoneSupport, g_smcPaZoneResistance);
    string mode = g_smcPaConsolidation ? "consolidation" : (g_smcPaInCorrection ? "correction" : "MA zone");
    return StringFormat("prix dans zone %s %s (MA50/200 %.*f-%.*f) trend=%s RSI=%.0f",
                        mode, s, dg, zLo, dg, zHi, g_smcPaTrend, g_smcPaRsi);
}

void SMCGP_DrawPriceActionZone()
{
   ObjectDelete(0, "SMC_PA_ZONE");
   ObjectDelete(0, "SMC_PA_LABEL");
   ObjectDelete(0, "SMC_PA_MA50");
   ObjectDelete(0, "SMC_PA_MA200");

    if(!g_showPriceActionZone) return;
    if(g_smcPaZoneSupport <= 0 || g_smcPaZoneResistance <= 0) return;

    SMCGP_UpdatePriceInActionZone();

    double zLo = MathMin(g_smcPaZoneSupport, g_smcPaZoneResistance);
    double zHi = MathMax(g_smcPaZoneSupport, g_smcPaZoneResistance);
    if(zHi <= zLo) return;

    int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 40);
    datetime tE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 100;
    if(t0 <= 0) t0 = TimeCurrent() - PeriodSeconds(PERIOD_CURRENT) * 40;

    color zoneClr = g_smcPaPriceInZone ? clrTomato : clrDimGray;
    if(g_smcPaPriceInZone && g_smcPaConsolidation) zoneClr = clrOrangeRed;

    ObjectCreate(0, "SMC_PA_ZONE", OBJ_RECTANGLE, 0, t0, zHi, tE, zLo);
    ObjectSetInteger(0, "SMC_PA_ZONE", OBJPROP_COLOR, zoneClr);
    ObjectSetInteger(0, "SMC_PA_ZONE", OBJPROP_BACK, true);
    ObjectSetInteger(0, "SMC_PA_ZONE", OBJPROP_FILL, true);
    ObjectSetInteger(0, "SMC_PA_ZONE", OBJPROP_SELECTABLE, false);

    string lbl = g_smcPaPriceInZone
       ? StringFormat("PRIX DANS ZONE MA50/200 [%.*f-%.*f] %s RSI=%.0f",
                      dg, zLo, dg, zHi, g_smcPaTrend, g_smcPaRsi)
       : StringFormat("ZONE MA50/200 [%.*f-%.*f] %s RSI=%.0f",
                      dg, zLo, dg, zHi, g_smcPaTrend, g_smcPaRsi);

    ObjectCreate(0, "SMC_PA_LABEL", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "SMC_PA_LABEL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "SMC_PA_LABEL", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "SMC_PA_LABEL", OBJPROP_YDISTANCE, 70);
    ObjectSetString(0, "SMC_PA_LABEL", OBJPROP_TEXT, lbl);
    ObjectSetInteger(0, "SMC_PA_LABEL", OBJPROP_COLOR, zoneClr);
    ObjectSetInteger(0, "SMC_PA_LABEL", OBJPROP_FONTSIZE, 9);
}

void SMCGP_EnsurePriceActionData()
{
    if(g_smcPaMa50 > 0 && g_smcPaMa200 > 0)
    {
       g_smcPaZoneSupport = MathMin(g_smcPaMa50, g_smcPaMa200);
       g_smcPaZoneResistance = MathMax(g_smcPaMa50, g_smcPaMa200);
    }
}

// ── EMA 200 line on chart ─────────────────────────────────────────────
void SMCGP_DrawEMA200()
{
   ObjectDelete(0, "SMC_EMA200_LINE");
   ObjectDelete(0, "SMC_EMA200_LABEL");
   if(g_pipelineEma200Handle == INVALID_HANDLE) return;

   double ema200[];
   ArraySetAsSeries(ema200, true);
   if(CopyBuffer(g_pipelineEma200Handle, 0, 0, 3, ema200) < 1) return;
   if(ema200[0] <= 0.0) return;

   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 100);
   datetime tE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 100;
   if(t0 <= 0) t0 = TimeCurrent() - PeriodSeconds(PERIOD_CURRENT) * 100;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   color c = (bid >= ema200[0]) ? (color)0x1A6A1A : (color)0x6A1A1A;  // Dim green/red

   ObjectCreate(0, "SMC_EMA200_LINE", OBJ_TREND, 0, t0, ema200[0], tE, ema200[0]);
   ObjectSetInteger(0, "SMC_EMA200_LINE", OBJPROP_COLOR, c);
   ObjectSetInteger(0, "SMC_EMA200_LINE", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "SMC_EMA200_LINE", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "SMC_EMA200_LINE", OBJPROP_BACK, false);
   ObjectSetInteger(0, "SMC_EMA200_LINE", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "SMC_EMA200_LINE", OBJPROP_RAY_RIGHT, true);

   string txt = "EMA200 M5 " + DoubleToString(ema200[0], dg);
   ObjectCreate(0, "SMC_EMA200_LABEL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_EMA200_LABEL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SMC_EMA200_LABEL", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_EMA200_LABEL", OBJPROP_YDISTANCE, 88);
   ObjectSetString(0, "SMC_EMA200_LABEL", OBJPROP_TEXT, txt);
   ObjectSetInteger(0, "SMC_EMA200_LABEL", OBJPROP_COLOR, c);
   ObjectSetInteger(0, "SMC_EMA200_LABEL", OBJPROP_FONTSIZE, 9);
}

// ── Asian session rectangle ───────────────────────────────────────────
void SMCGP_DrawAsianSession()
{
   ObjectDelete(0, "SMC_ASIAN_SESSION");
   ObjectDelete(0, "SMC_ASIAN_LABEL");

   MqlDateTime dtUtc; TimeGMT(dtUtc);
   // Asian session approx: 23:00 UTC → 08:00 UTC (Tokyo → Sydney close)
   datetime dayStart = dtUtc.day; // aujourd'hui 00:00 UTC
   datetime asianStart = dayStart + 23 * 3600;  // 23:00 UTC
   datetime asianEnd   = dayStart + 32 * 3600;    // 08:00 UTC+1day
   datetime t0 = MathMax(asianStart - 86400, iTime(_Symbol, PERIOD_CURRENT, 200));
   datetime tE = asianEnd;

   double hi = ChartGetDouble(0, CHART_PRICE_MAX);
   double lo = ChartGetDouble(0, CHART_PRICE_MIN);
   if(hi <= 0 || lo <= 0) { hi = 1.3; lo = 1.2; }
   double range = (hi - lo) * 1.5;
   double zHi = hi + range;
   double zLo = lo - range;

   bool inAsian = (dtUtc.hour >= 23 || dtUtc.hour < 8);

   ObjectCreate(0, "SMC_ASIAN_SESSION", OBJ_RECTANGLE, 0, t0, zHi, tE, zLo);
   ObjectSetInteger(0, "SMC_ASIAN_SESSION", OBJPROP_COLOR, 0x1A3A5C);  // Dim blue (transparent-like)
   ObjectSetInteger(0, "SMC_ASIAN_SESSION", OBJPROP_BACK, true);
   ObjectSetInteger(0, "SMC_ASIAN_SESSION", OBJPROP_FILL, true);
   ObjectSetInteger(0, "SMC_ASIAN_SESSION", OBJPROP_SELECTABLE, false);

   string lbl = inAsian ? "ASIAN SESSION (active)" : "ASIAN SESSION (23:00-08:00 UTC)";
   ObjectCreate(0, "SMC_ASIAN_LABEL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_ASIAN_LABEL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SMC_ASIAN_LABEL", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_ASIAN_LABEL", OBJPROP_YDISTANCE, 102);
   ObjectSetString(0, "SMC_ASIAN_LABEL", OBJPROP_TEXT, lbl);
   ObjectSetInteger(0, "SMC_ASIAN_LABEL", OBJPROP_COLOR, inAsian ? 0x5C8AB5 : 0x4A4A4A);  // Dim label
   ObjectSetInteger(0, "SMC_ASIAN_LABEL", OBJPROP_FONTSIZE, 9);
}

// ── GOM verdict → BUY/SELL direction ─────────────────────────────────
// Retourne 1 pour BUY, -1 pour SELL, 0 pour WAIT/neutre
int SMCGP_GOMVerdictDirection()
{
   if(g_smcGomVerdictNum >= 2) return 1;
   if(g_smcGomVerdictNum <= -2) return -1;
   return 0;
}

// Vérifie si le verdict GOM valide un signal dans la direction donnée
// dir = 1 (BUY), -1 (SELL)
bool SMCGP_GOMValidatesPrimarySignal(const int dir)
{
   if(dir == 0) return false;
   // Verdict WAIT (0) → bloque tout
   if(g_smcGomVerdictNum == 0) return false;
   // Verdict dans la bonne direction (≥2 BUY, ≤-2 SELL)
   if(dir > 0 && g_smcGomVerdictNum >= 2) return true;
   if(dir < 0 && g_smcGomVerdictNum <= -2) return true;
   // Verdict faible (±1) → valide seulement si qualité ≥ 40%
   if(dir > 0 && g_smcGomVerdictNum == 1 && g_smcGomQuality >= 40.0) return true;
   if(dir < 0 && g_smcGomVerdictNum == -1 && g_smcGomQuality >= 40.0) return true;
   return false;
}

// Retourne le texte de direction (BUY/SELL/WAIT) basé sur le verdict GOM
string SMCGP_GOMVerdictAction()
{
   if(g_smcGomVerdictNum >= 2) return "BUY";
   if(g_smcGomVerdictNum <= -2) return "SELL";
   return "WAIT";
}

// ── Signal visuel GOM (full range: BUY_ENTER, SELL_ENTER, HOLD, EXIT_NOW, etc) ────
void SMCGP_DrawGOMSignal()
{
   // Supprimer l'ancien signal (version petite)
   ObjectDelete(0, "SMC_GOM_SIGNAL");
   ObjectDelete(0, "SMC_GOM_SIGNAL_BG");

    // CORRECTION: Calculer le signal à partir du verdict GOM + précédent + qualité/cohérence
    TradingSignal signal = GOM_CalcSignal(g_smcGomVerdictNum, g_smcGomVerdictNumPrev, g_smcGomQuality, g_smcGomCoherence);
   string action = SMCGP_GOMVerdictAction();
   string verdict = g_smcGomVerdict;
   double chartBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Supprimer l'ancien signal central s'il existe (de GOMG_DrawCentralSignal)
   ObjectDelete(0, "GOM_CENTER_SIGNAL");
   ObjectDelete(0, "GOM_CENTER_BG");
   ObjectDelete(0, "GOM_SIGNAL_ENTER_BG");

   // ********************** NOUVEAU : Signaux centraux GOM à gros coup de pinceau **************
   GOMG_DrawCentralSignal(signal, verdict, chartBid);

}

#include "SMC_FuturePath.mqh"

#endif



