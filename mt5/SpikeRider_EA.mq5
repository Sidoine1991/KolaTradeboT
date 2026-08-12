//+------------------------------------------------------------------+
//|                                            SpikeRider_EA.mq5    |
//|   Boom & Crash Spike Catcher — Version Complète                 |
//|                                                                  |
//|   Philosophie :                                                  |
//|   - Boom  : BUY  uniquement (spike haussier ~toutes les N bares)|
//|   - Crash : SELL uniquement (spike baissier ~toutes les N bares)|
//|                                                                  |
//|   Moteurs :                                                      |
//|   1. Détection spike multi-critères                              |
//|      (Corps, Mèche, Z-Score, Compression ATR, Pattern)          |
//|   2. Mode HYBRID : Anticipation (60-85%) + Pullback post-spike  |
//|   3. Filtres ICT/SMC : BOS / CHoCH / LiqSweep / OB / FVG / OTE |
//|   4. GOM verdict (AI server) — GOOD/PERFECT obligatoire         |
//|   5. Capital Manager : 5% gain/jour + 5% stop perte             |
//|   6. Gestion position : SmartBE + Trailing ATR + QuickExit      |
//|   7. Dashboard visuel complet                                    |
//+------------------------------------------------------------------+
#property copyright "SpikeRider v1.0 — TradBOT"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+

input group "═══ SYMBOLE & MAGIC ═══"
input int    InpMagic            = 77000;
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;

input group "═══ DÉTECTION SPIKE ═══"
input int    InpATRPeriod        = 14;
input int    InpLookback         = 30;         // Historique stats spike
input double InpSpikeBodyMult    = 0.50;       // Corps min = N×ATR
input double InpSpikeWickMult    = 0.60;       // Mèche min = N×ATR
input double InpSpikeZScoreMin   = 1.5;        // Z-Score min (0=désactivé)
input bool   InpAutoPresets      = true;       // Seuils auto selon variant

input group "═══ CYCLE & FENÊTRE ═══"
input int    InpBarsMin          = 8;          // Cycle de base
input double InpWindowStart      = 0.60;       // Début fenêtre (% cycle)
input double InpWindowEnd        = 0.85;       // Fin fenêtre (% cycle)
input int    InpPullbackBars     = 3;          // Barres max post-spike

input group "═══ FILTRES ICT/SMC ═══"
input bool   InpUseBOS           = true;
input bool   InpUseCHOCH         = true;
input bool   InpUseLiqSweep      = true;
input bool   InpUseOB            = true;
input bool   InpUseFVG           = true;
input bool   InpUseOTE           = true;
input int    InpMinICTScore      = 0;          // 0=désactivé, 40=souple, 70=strict
input int    InpICTLookback      = 20;

input group "═══ FILTRE RSI ═══"
input bool   InpUseRSI           = true;
input int    InpRSIPeriod        = 14;
input double InpRSIBoomMax       = 72.0;
input double InpRSICrashMin      = 28.0;

input group "═══ FILTRE GOM (AI SERVER) ═══"
input bool   InpUseGOM           = true;       // Activer filtre GOM verdict
input string InpAIServer         = "http://127.0.0.1:8000"; // URL AI server
input int    InpGOMPollSec       = 5;          // Intervalle poll verdict
input int    InpGOMMaxAgeSec     = 60;         // Verdict trop vieux = ignorer
// GOOD/PERFECT = |verdict_num| >= 2
// GOOD=±2, PERFECT=±3

input group "═══ GESTION DE POSITION ═══"
input bool   InpUseRiskPercent   = true;
input double InpRiskPercent      = 1.5;        // % balance par trade
input double InpFixedLot         = 0.10;       // Lot fixe si pas %
input double InpSL_ATR           = 1.5;
input double InpTP_ATR           = 3.0;
input bool   InpUseSmartBE       = true;
input double InpBETrigger        = 1.0;        // Déclencher BE à N×ATR profit
input bool   InpUseTrail         = true;
input double InpTrailATR         = 0.5;
input double InpTrailActivation  = 0.8;
input bool   InpUseQuickExit     = true;       // Fermer sur spike suivant
input double InpQuickExitMinPct  = 0.3;
input int    InpTimeStopMin      = 20;
input int    InpCooldownBars     = 1;

input group "═══ CAPITAL MANAGER ═══"
input bool   InpUseCM            = true;
input double InpCMDailyTargetPct = 5.0;        // Stop gain journalier (%)
input double InpCMDailyLossPct   = 5.0;        // Stop perte journalier (%)

input group "═══ AFFICHAGE ═══"
input bool   InpShowDashboard    = true;
input bool   InpDebug            = false;

//+------------------------------------------------------------------+
//| TYPES                                                            |
//+------------------------------------------------------------------+
enum ESignal    { SIG_NONE, SIG_BUY, SIG_SELL };
enum EEntryType { ENTRY_NONE, ENTRY_ANTICIPATION, ENTRY_PULLBACK };

struct SSpikeState
{
   bool     detected;
   bool     inWindow;
   string   level;       // none / early / watch / imminent / spike / overdue
   double   cyclePct;
   double   atr;
   double   zScore;
   int      barsSince;
   datetime lastSpikeTime;
};

struct SICTState
{
   bool   BOS, CHOCH, LiqSweep, OB, FVG, OTE;
   int    Score;
   string Grade;
};

struct SGOMState
{
   string verdict;
   int    verdictNum;    // -3..+3  (GOOD/PERFECT = |x|>=2)
   double scoreBuy;
   double scoreSell;
   double quality;
   double coherence;
   string kolaState;
   datetime lastPoll;
   bool   valid;
   bool   counterTrend;  // verdict GOM : entrée contre structure TV
   bool   connected;     // dernier poll HTTP ok + ok:true serveur
};

struct STradeState
{
   bool       hasPosition;
   ulong      ticket;
   ESignal    direction;
   EEntryType entryType;
   double     entryPrice;
   double     spikeExtLow;
   double     spikeExtHigh;
   datetime   openTime;
   bool       beTriggered;
   bool       tradeTakenCycle;
};

struct SSessionStats
{
   double pnl;
   int    trades;
   int    wins;
   double dayStartBalance;
   datetime dayTag;
   bool   dailyLocked;
};

//+------------------------------------------------------------------+
//| ÉTAT GLOBAL                                                      |
//+------------------------------------------------------------------+
CTrade g_trade;

int g_hATR  = INVALID_HANDLE;
int g_hRSI  = INVALID_HANDLE;

int      g_barsSinceSpike     = 0;
datetime g_lastSpikeBarTime   = 0;
datetime g_lastProcessedBar   = 0;
datetime g_lastTradeBar       = 0;
double   g_spikeExtLow        = 0;
double   g_spikeExtHigh       = 0;

SSpikeState  g_spike;
SICTState    g_ict;
SGOMState    g_gom;
STradeState  g_ts;
SSessionStats g_sess;

string   g_lastReason  = "Init...";
datetime g_lastGOMPoll = 0;
datetime g_lastGOMFailLog = 0;

//+------------------------------------------------------------------+
//| HELPERS SYMBOLE                                                  |
//+------------------------------------------------------------------+
bool IsBoom()  { return StringFind(_Symbol,"Boom")>=0  || StringFind(_Symbol,"boom")>=0; }
bool IsCrash() { return StringFind(_Symbol,"Crash")>=0 || StringFind(_Symbol,"crash")>=0; }

int GetCycleLength()
{
   if(StringFind(_Symbol,"300")>=0)  return 5;
   if(StringFind(_Symbol,"500")>=0)  return 8;
   if(StringFind(_Symbol,"600")>=0)  return 10;
   if(StringFind(_Symbol,"900")>=0)  return 13;
   if(StringFind(_Symbol,"1000")>=0) return 16;
   return InpBarsMin;
}

double GetBodyMult() { return (InpAutoPresets && StringFind(_Symbol,"1000")>=0) ? 0.60 : InpSpikeBodyMult; }
double GetWickMult() { return (InpAutoPresets && StringFind(_Symbol,"1000")>=0) ? 0.70 : InpSpikeWickMult; }
double GetSL_ATR()   { return (InpAutoPresets && StringFind(_Symbol,"1000")>=0) ? 2.0  : InpSL_ATR; }
double GetTP_ATR()   { return (InpAutoPresets && StringFind(_Symbol,"1000")>=0) ? 3.5  : InpTP_ATR; }

//+------------------------------------------------------------------+
//| INDICATEURS                                                      |
//+------------------------------------------------------------------+
double GetATR(int shift=1)
{
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(g_hATR,0,shift,1,b)<1) return 0;
   return b[0];
}

double GetATRAvg(int bars=30)
{
   double buf[]; ArraySetAsSeries(buf,true);
   if(CopyBuffer(g_hATR,0,1,bars,buf)<bars) return 0;
   double s=0; for(int i=0;i<bars;i++) s+=buf[i];
   return s/bars;
}

double GetRSI(int shift=1)
{
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(g_hRSI,0,shift,1,b)<1) return 50;
   return b[0];
}

//+------------------------------------------------------------------+
//| DÉTECTION SPIKE                                                  |
//+------------------------------------------------------------------+
bool IsSpikeCandle(const MqlRates &c, double atr, bool forBoom)
{
   double body   = MathAbs(c.close - c.open);
   double wickUp = c.high - MathMax(c.open, c.close);
   double wickDn = MathMin(c.open, c.close) - c.low;

   bool bigBody = body >= atr * GetBodyMult();
   bool dirOk   = forBoom ? (c.close > c.open) : (c.close < c.open);

   if(forBoom)
      return (bigBody || wickUp >= atr*GetWickMult()) && dirOk;
   else
      return (bigBody || wickDn >= atr*GetWickMult()) && dirOk;
}

// Score de compression ATR (0-1) : faible ATR récent = compression probable
double CalcATRCompression()
{
   double atrNow = GetATR(1);
   double atrOld = GetATRAvg(InpLookback);
   if(atrOld <= 0) return 0;
   double ratio = atrNow / atrOld;
   if(ratio < 0.7) return 1.0;
   if(ratio < 0.85) return 0.6;
   if(ratio < 0.95) return 0.3;
   return 0;
}

// Z-Score du corps de la dernière bougie
double CalcZScore(double bodySize)
{
   MqlRates hist[]; ArraySetAsSeries(hist,true);
   if(CopyRates(_Symbol,InpTF,2,InpLookback,hist) < InpLookback) return 0;
   double sumB=0, sumB2=0;
   for(int i=0;i<InpLookback;i++)
   {
      double b = MathAbs(hist[i].close - hist[i].open);
      sumB  += b;
      sumB2 += b*b;
   }
   double avg = sumB / InpLookback;
   double std = MathSqrt(MathMax(0, sumB2/InpLookback - avg*avg));
   return (std > 0) ? (bodySize - avg) / std : 0;
}

// Détection pré-spike : compression des corps en série
bool DetectPreSpikeCompression(bool forBoom)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,1,6,r)<6) return false;
   double bodies[6];
   for(int i=0;i<6;i++) bodies[i] = MathAbs(r[i].close - r[i].open);
   // Corps récents plus petits que corps anciens = compression
   bool compressing = (bodies[0] < bodies[2]) && (bodies[1] < bodies[3]);
   // Direction des dernières bougies alignée
   bool dirOk = forBoom
      ? (r[0].close >= r[0].open && r[1].close >= r[1].open)
      : (r[0].close <= r[0].open && r[1].close <= r[1].open);
   return compressing && dirOk;
}

void UpdateSpikeCounter()
{
   double atr = GetATR(1); if(atr<=0) return;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,1,1,r)<1) return;

   bool spike = IsSpikeCandle(r[0], atr, IsBoom());
   if(spike)
   {
      g_lastSpikeBarTime = r[0].time;
      g_spikeExtLow      = r[0].low;
      g_spikeExtHigh     = r[0].high;
      g_barsSinceSpike   = 0;
      g_ts.tradeTakenCycle = false;
      if(InpDebug) PrintFormat("[SR] Spike détecté @ %s | body=%.5f atr=%.5f",
                               TimeToString(r[0].time), MathAbs(r[0].close-r[0].open), atr);
   }
   else
   {
      g_barsSinceSpike++;
      int cyMax = GetCycleLength() * 3;
      if(g_barsSinceSpike > cyMax) g_barsSinceSpike = GetCycleLength();
   }
}

SSpikeState AnalyzeSpike()
{
   SSpikeState sp;
   sp.detected      = false;
   sp.inWindow      = false;
   sp.level         = "none";
   sp.cyclePct      = 0;
   sp.atr           = GetATR(1);
   sp.zScore        = 0;
   sp.barsSince     = g_barsSinceSpike;
   sp.lastSpikeTime = g_lastSpikeBarTime;
   if(sp.atr <= 0) return sp;

   int    cycle = GetCycleLength();
   double pct   = (cycle > 0) ? MathMin((double)g_barsSinceSpike / cycle, 1.2) : 0.5;
   sp.cyclePct  = pct;

   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,1,2,r)>=1)
   {
      sp.detected = IsSpikeCandle(r[0], sp.atr, IsBoom());
      double bodySize = MathAbs(r[0].close - r[0].open);
      sp.zScore = CalcZScore(bodySize);
   }

   // Classification du niveau
   if(sp.detected)
      { sp.level = "spike";    sp.inWindow = false; }
   else if(pct >= 1.0)
      { sp.level = "overdue";  sp.inWindow = false; }
   else if(pct >= InpWindowEnd)
      { sp.level = "late";     sp.inWindow = false; }
   else if(pct >= InpWindowStart)
      { sp.level = "imminent"; sp.inWindow = true;  }
   else if(pct >= 0.40)
      { sp.level = "watch";    sp.inWindow = false; }
   else
      { sp.level = "early";    sp.inWindow = false; }

   return sp;
}

//+------------------------------------------------------------------+
//| FILTRES ICT / SMC                                                |
//+------------------------------------------------------------------+
bool ICT_BOS(bool forBuy)
{
   if(!InpUseBOS) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n = InpICTLookback + 4;
   if(CopyRates(_Symbol,InpTF,0,n,r)<n) return false;
   double hh=r[2].high, ll=r[2].low;
   for(int i=3;i<n-1;i++) { hh=MathMax(hh,r[i].high); ll=MathMin(ll,r[i].low); }
   return forBuy ? (r[1].close > hh) : (r[1].close < ll);
}

bool ICT_CHOCH(bool forBuy)
{
   if(!InpUseCHOCH) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,0,8,r)<8) return false;
   if(forBuy)
   {
      bool down = (r[5].low > r[4].low) && (r[4].low > r[3].low);
      double hi = MathMax(MathMax(r[2].high,r[3].high),r[4].high);
      return down && r[1].close > hi;
   }
   bool up = (r[5].high < r[4].high) && (r[4].high < r[3].high);
   double lo = MathMin(MathMin(r[2].low,r[3].low),r[4].low);
   return up && r[1].close < lo;
}

bool ICT_LiqSweep(bool forBuy)
{
   if(!InpUseLiqSweep) return false;
   double atr = GetATR(1); if(atr<=0) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,0,12,r)<12) return false;
   if(forBuy)
   {
      double ll1=r[5].low, ll2=r[9].low;
      if(MathAbs(ll1-ll2)<atr*0.2 && r[1].low<MathMin(ll1,ll2) && r[1].close>MathMin(ll1,ll2)+atr*0.1) return true;
      if(MathAbs(r[2].high-r[3].high)<atr*0.15 && r[1].high>MathMax(r[2].high,r[3].high)+atr*0.25 && r[1].close<MathMax(r[2].high,r[3].high)) return true;
   }
   else
   {
      double hh1=r[5].high, hh2=r[9].high;
      if(MathAbs(hh1-hh2)<atr*0.2 && r[1].high>MathMax(hh1,hh2) && r[1].close<MathMax(hh1,hh2)-atr*0.1) return true;
      if(MathAbs(r[2].low-r[3].low)<atr*0.15 && r[1].low<MathMin(r[2].low,r[3].low)-atr*0.25 && r[1].close>MathMin(r[2].low,r[3].low)) return true;
   }
   return false;
}

bool ICT_OB(bool forBuy)
{
   if(!InpUseOB) return false;
   double atr=GetATR(1); if(atr<=0) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,0,12,r)<12) return false;
   double cur = r[1].close;
   for(int i=3;i<11;i++)
   {
      if(forBuy && r[i].close < r[i].open)
      {
         double imp=0; for(int j=i-1;j>=2;j--) imp+=(r[j].close-r[j].open);
         if(imp>=atr*1.2 && cur>=r[i].close-atr*0.1 && cur<=r[i].open+atr*0.2) return true;
      }
      if(!forBuy && r[i].close > r[i].open)
      {
         double imp=0; for(int j=i-1;j>=2;j--) imp+=(r[j].open-r[j].close);
         if(imp>=atr*1.2 && cur<=r[i].close+atr*0.1 && cur>=r[i].open-atr*0.2) return true;
      }
   }
   return false;
}

bool ICT_FVG(bool forBuy)
{
   if(!InpUseFVG) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,0,6,r)<6) return false;
   double cur = r[1].close;
   for(int i=1;i<=3;i++)
   {
      if(forBuy  && r[i].low  > r[i+2].high && cur>=r[i+2].high && cur<=r[i].low)  return true;
      if(!forBuy && r[i].high < r[i+2].low  && cur<=r[i+2].low  && cur>=r[i].high) return true;
   }
   return false;
}

bool ICT_OTE(bool forBuy)
{
   if(!InpUseOTE) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n = InpICTLookback + 2;
   if(CopyRates(_Symbol,InpTF,0,n,r)<n) return false;
   double hi=r[1].high, lo=r[1].low;
   for(int i=2;i<n;i++) { hi=MathMax(hi,r[i].high); lo=MathMin(lo,r[i].low); }
   double rng=hi-lo; if(rng<=0) return false;
   double cur=r[1].close;
   if(forBuy)  { double f62=hi-rng*0.62, f79=hi-rng*0.79; return cur>=f79 && cur<=f62; }
   double f62=lo+rng*0.62, f79=lo+rng*0.79; return cur>=f62 && cur<=f79;
}

SICTState CalcICT(bool forBuy)
{
   SICTState ict;
   ict.BOS      = ICT_BOS(forBuy);
   ict.CHOCH    = ICT_CHOCH(forBuy);
   ict.LiqSweep = ICT_LiqSweep(forBuy);
   ict.OB       = ICT_OB(forBuy);
   ict.FVG      = ICT_FVG(forBuy);
   ict.OTE      = ICT_OTE(forBuy);
   int s = 0;
   if(ict.BOS)      s += 20;
   if(ict.CHOCH)    s += 20;
   if(ict.LiqSweep) s += 20;
   if(ict.OB)       s += 15;
   if(ict.FVG)      s += 15;
   if(ict.OTE)      s += 10;
   ict.Score = s;
   ict.Grade = (s>=85)?"A+":(s>=70)?"A":(s>=50)?"B":"C";
   return ict;
}

//+------------------------------------------------------------------+
//| GOM VERDICT (AI SERVER)                                          |
//+------------------------------------------------------------------+
string JsonGetStr(const string &body, const string &key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(body, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = StringFind(body, "\"", pos);
   if(end < 0) return "";
   return StringSubstr(body, pos, end - pos);
}

bool JsonGetBool(const string &body, const string &key, bool def=false)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return def;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   if(StringFind(body, "true", pos) == pos)  return true;
   if(StringFind(body, "false", pos) == pos) return false;
   return def;
}

void InvalidateGOM(const string why)
{
   g_gom.valid        = false;
   g_gom.connected    = false;
   g_gom.counterTrend = false;
   g_gom.verdict      = "WAIT";
   g_gom.verdictNum   = 0;
   if(InpDebug || TimeCurrent() - g_lastGOMFailLog >= 60)
   {
      g_lastGOMFailLog = TimeCurrent();
      Print("[SpikeRider] GOM OFF — ", why);
   }
}

double JsonGetDbl(const string &body, const string &key, double def=0)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return def;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body,pos)==' ') pos++;
   string val = "";
   while(pos < StringLen(body))
   {
      ushort c = StringGetCharacter(body, pos);
      if(c==','||c=='}'||c==']') break;
      val += ShortToString(c);
      pos++;
   }
   StringTrimRight(val);
   double result = def;
   if(StringToDouble(val) != 0 || val == "0") result = StringToDouble(val);
   return result;
}

string ResolveGOMSymbol(const string sym)
{
   if(sym == "XAUEUR" || sym == "GOLD") return "XAUUSD";
   return sym;
}

void PollGOM()
{
   if(!InpUseGOM) return;
   if((int)(TimeCurrent() - g_lastGOMPoll) < InpGOMPollSec) return;
   g_lastGOMPoll = TimeCurrent();

   string sym = ResolveGOMSymbol(_Symbol);
   StringReplace(sym, " ", "%20");
   string url = InpAIServer + "/gom-verdict?symbol=" + sym;

   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("GET", url, headers, 10000, post, result, respH);
   if(code != 200)
   {
      InvalidateGOM(StringFormat("HTTP %d (vérifier ai_server + WebRequest)", code));
      return;
   }

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(StringFind(body, "\"ok\":false") >= 0 || StringFind(body, "\"ok\":null") >= 0)
   {
      string msg = JsonGetStr(body, "message");
      if(StringLen(msg) == 0) msg = "serveur ok:false";
      InvalidateGOM(msg);
      return;
   }

   g_gom.verdict       = JsonGetStr(body, "verdict");
   g_gom.verdictNum    = (int)JsonGetDbl(body, "verdict_num");
   g_gom.scoreBuy      = JsonGetDbl(body, "score_buy");
   g_gom.scoreSell     = JsonGetDbl(body, "score_sell");
   g_gom.quality       = JsonGetDbl(body, "entry_quality");
   g_gom.coherence     = JsonGetDbl(body, "coherence_pct");
   g_gom.kolaState     = JsonGetStr(body, "kola_state");
   g_gom.counterTrend  = JsonGetBool(body, "counter_trend", false);
   g_gom.lastPoll      = TimeCurrent();
   g_gom.connected     = true;
   g_gom.valid         = true;
}

bool GOMAllowsTrade(bool forBuy)
{
   if(!InpUseGOM) return true;
   if(!g_gom.connected || !g_gom.valid) return false;

   if((int)(TimeCurrent() - g_gom.lastPoll) > InpGOMMaxAgeSec)
   {
      g_gom.valid = false;
      return false;
   }

   if(g_gom.counterTrend) return false;

   int vn = g_gom.verdictNum;
   if(forBuy)  return (vn >= 2);
   else        return (vn <= -2);
}

//+------------------------------------------------------------------+
//| CAPITAL MANAGER                                                  |
//+------------------------------------------------------------------+
double CalcDailyClosedPnL()
{
   if(!InpUseCM) return 0;
   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   HistorySelect(dayStart, TimeCurrent());
   double pnl = 0;
   for(int i=HistoryDealsTotal()-1; i>=0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket==0) continue;
      if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BALANCE) continue;
      if(HistoryDealGetInteger(ticket,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      pnl += HistoryDealGetDouble(ticket,DEAL_PROFIT)
           + HistoryDealGetDouble(ticket,DEAL_SWAP)
           + HistoryDealGetDouble(ticket,DEAL_COMMISSION);
   }
   return pnl;
}

void CheckDailyLimits()
{
   if(!InpUseCM) return;

   // Reset quotidien
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   datetime today = StructToTime(dt);
   if(today != g_sess.dayTag)
   {
      g_sess.dayTag          = today;
      g_sess.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_sess.dailyLocked     = false;
      g_sess.pnl             = 0;
      g_sess.trades          = 0;
      g_sess.wins            = 0;
   }
   if(g_sess.dailyLocked) return;

   double bal    = g_sess.dayStartBalance;
   double target = bal * InpCMDailyTargetPct / 100.0;
   double stop   = bal * InpCMDailyLossPct   / 100.0;

   double closedPnL  = CalcDailyClosedPnL();
   double floatPnL   = 0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      floatPnL += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   double totalPnL = closedPnL + floatPnL;

   if(totalPnL >= target)
   {
      g_sess.dailyLocked = true;
      CloseAllPositions("DAILY TARGET +" + DoubleToString(totalPnL,2) + "$");
      PrintFormat("[SR] OBJECTIF JOURNALIER +%.1f%% ($%.2f) — ARRÊT DU JOUR",
                  totalPnL/bal*100, totalPnL);
   }
   else if(totalPnL <= -stop)
   {
      g_sess.dailyLocked = true;
      CloseAllPositions("DAILY STOP -" + DoubleToString(MathAbs(totalPnL),2) + "$");
      PrintFormat("[SR] STOP PERTE JOURNALIER -%.1f%% ($%.2f) — ARRÊT DU JOUR",
                  MathAbs(totalPnL)/bal*100, MathAbs(totalPnL));
   }
}

void CloseAllPositions(const string reason)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      g_trade.PositionClose(PositionGetTicket(i), 30);
   }
   Print("[SR] Fermeture : ", reason);
}

//+------------------------------------------------------------------+
//| LOGIQUE D'ENTRÉE                                                 |
//+------------------------------------------------------------------+
bool EvaluateEntry(ESignal &signal, EEntryType &entryType, string &reason)
{
   signal    = SIG_NONE;
   entryType = ENTRY_NONE;
   reason    = "";

   if(g_ts.tradeTakenCycle)       { reason="1 trade/cycle déjà pris";  return false; }
   if(g_sess.dailyLocked)         { reason="Capital Manager — journée verrouillée"; return false; }

   double atr = GetATR(1); if(atr<=0) { reason="ATR invalide"; return false; }
   bool forBuy = IsBoom();

   // ── Filtre RSI ──────────────────────────────────────────────────
   if(InpUseRSI)
   {
      double rsi = GetRSI(1);
      if(forBuy  && rsi > InpRSIBoomMax)  { reason=StringFormat("RSI %.0f > %.0f (suracheté)",  rsi, InpRSIBoomMax);  return false; }
      if(!forBuy && rsi < InpRSICrashMin) { reason=StringFormat("RSI %.0f < %.0f (survendu)",   rsi, InpRSICrashMin); return false; }
   }

   // ── Filtre GOM (fail-closed si déconnecté) ───────────────────────
   if(InpUseGOM)
   {
      if(!g_gom.connected || !g_gom.valid)
      {
         reason = "GOM déconnecté — pas de trade sans verdict frais";
         return false;
      }
      if(g_gom.counterTrend)
      {
         reason = StringFormat("GOM contre-tendance (verdict=%s)", g_gom.verdict);
         return false;
      }
      if(!GOMAllowsTrade(forBuy))
      {
         reason = StringFormat("GOM %s (besoin %s GOOD/PERFECT)",
                               g_gom.verdict, forBuy?"BUY":"SELL");
         return false;
      }
   }

   // ── Score ICT ───────────────────────────────────────────────────
   g_ict = CalcICT(forBuy);
   if(InpMinICTScore > 0 && g_ict.Score < InpMinICTScore)
   {
      reason = StringFormat("ICT %d(%s) < min %d", g_ict.Score, g_ict.Grade, InpMinICTScore);
      return false;
   }

   // ── Compression pré-spike ───────────────────────────────────────
   bool preSpike = DetectPreSpikeCompression(forBuy);

   // ── MODE 1 : ANTICIPATION (fenêtre InpWindowStart-InpWindowEnd) ─
   g_spike = AnalyzeSpike();
   if(g_spike.inWindow && g_spike.level == "imminent")
   {
      // Bonus si compression détectée
      signal    = forBuy ? SIG_BUY : SIG_SELL;
      entryType = ENTRY_ANTICIPATION;
      reason    = StringFormat("ANTICIPATION %.0f%% | ICT=%d(%s) | GOM=%s | %s%s%s%s%s%s%s",
                               g_spike.cyclePct*100, g_ict.Score, g_ict.Grade,
                               InpUseGOM ? g_gom.verdict : "OFF",
                               g_ict.BOS?"BOS ":"", g_ict.CHOCH?"CHoCH ":"",
                               g_ict.LiqSweep?"Liq ":"", g_ict.OB?"OB ":"",
                               g_ict.FVG?"FVG ":"", g_ict.OTE?"OTE ":"",
                               preSpike?"[Pre-Spike]":"");
      return true;
   }

   // ── MODE 2 : PULLBACK post-spike ────────────────────────────────
   if(!g_spike.detected && g_lastSpikeBarTime > 0
      && g_barsSinceSpike >= 1 && g_barsSinceSpike <= InpPullbackBars)
   {
      double refPx  = forBuy ? g_spikeExtLow : g_spikeExtHigh;
      double curPx  = forBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double dist   = forBuy ? (curPx - refPx) : (refPx - curPx);

      if(dist >= -atr*0.3 && dist <= atr*2.5
         && (InpMinICTScore==0 || g_ict.Score >= InpMinICTScore))
      {
         signal    = forBuy ? SIG_BUY : SIG_SELL;
         entryType = ENTRY_PULLBACK;
         reason    = StringFormat("PULLBACK %d bar(s) | ICT=%d(%s) | GOM=%s | dist=%.5f",
                                  g_barsSinceSpike, g_ict.Score, g_ict.Grade,
                                  InpUseGOM ? g_gom.verdict : "OFF", dist);
         return true;
      }
   }

   // ── Pas de signal ────────────────────────────────────────────────
   if(g_spike.level=="overdue" || g_spike.level=="late")
      reason = StringFormat("Cycle dépassé (%.0f%%) — attente prochain spike", g_spike.cyclePct*100);
   else if(g_spike.level=="watch")
      reason = StringFormat("Zone watch (%.0f%%) — ICT=%d — fenêtre à %.0f%%",
                            g_spike.cyclePct*100, g_ict.Score, InpWindowStart*100);
   else
      reason = StringFormat("Trop tôt (%.0f%%) | ICT=%d | GOM=%s",
                            g_spike.cyclePct*100, g_ict.Score,
                            InpUseGOM ? g_gom.verdict : "OFF");
   return false;
}

//+------------------------------------------------------------------+
//| CALCUL LOT                                                       |
//+------------------------------------------------------------------+
double CalcLot(double slDist)
{
   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep = minLot;

   double lot = InpFixedLot;
   if(InpUseRiskPercent && InpRiskPercent>0 && slDist>0)
   {
      double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk = bal * InpRiskPercent / 100.0;
      double tv   = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double ts   = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(tv>0 && ts>0)
      { double lpl = (slDist/ts)*tv; if(lpl>0) lot = risk/lpl; }
   }
   lot = MathFloor(lot/lotStep + 0.5) * lotStep;
   return NormalizeDouble(MathMax(minLot, MathMin(maxLot, lot)), 2);
}

double MinStopDist(double atr)
{
   double pt  = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int    sl  = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   int    fr  = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   return MathMax((double)(sl+fr+100)*pt, atr*0.3);
}

double NormTick(double price, bool up)
{
   double tick = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   int    dg   = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(tick<=0) return NormalizeDouble(price,dg);
   double n = price/tick;
   n = up ? MathCeil(n-1e-9) : MathFloor(n+1e-9);
   return NormalizeDouble(n*tick,dg);
}

//+------------------------------------------------------------------+
//| OUVERTURE ORDRE                                                  |
//+------------------------------------------------------------------+
bool OpenTrade(ESignal sig, EEntryType etype)
{
   double atr   = GetATR(1); if(atr<=0) return false;
   bool   isBuy = (sig==SIG_BUY);
   double price = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(price<=0) return false;

   double minD = MinStopDist(atr);
   double slD, tpD;

   if(etype==ENTRY_PULLBACK && g_lastSpikeBarTime>0)
   {
      // SL ancré sur l'extrême du spike
      if(isBuy) slD = MathMax(price-(g_spikeExtLow-atr*0.2), atr*GetSL_ATR());
      else       slD = MathMax((g_spikeExtHigh+atr*0.2)-price, atr*GetSL_ATR());
      slD = MathMax(slD, minD);
   }
   else
      slD = MathMax(atr * GetSL_ATR(), minD);

   tpD = MathMax(atr * GetTP_ATR(), minD * 1.5);

   int  dg = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl, tp;
   if(isBuy)
   {
      sl = NormTick(price-slD, false);
      tp = NormTick(price+tpD, true);
      if(price-sl < minD) sl = NormTick(price-minD*1.1, false);
      if(tp-price < minD) tp = NormTick(price+minD*1.5, true);
      if(sl >= price) return false;
   }
   else
   {
      sl = NormTick(price+slD, true);
      tp = NormTick(price-tpD, false);
      if(sl-price < minD) sl = NormTick(price+minD*1.1, true);
      if(price-tp < minD) tp = NormTick(price-minD*1.5, false);
      if(sl <= price) return false;
   }

   double lot = CalcLot(slD);
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(50);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

   string cmt = StringFormat("SR|%s|%s|ICT%d|GOM%d",
                             isBuy?"BUY":"SELL",
                             etype==ENTRY_ANTICIPATION?"ANTI":"PULL",
                             g_ict.Score, g_gom.verdictNum);

   bool ok = isBuy ? g_trade.Buy(lot,_Symbol,0,sl,tp,cmt)
                   : g_trade.Sell(lot,_Symbol,0,sl,tp,cmt);
   if(ok)
   {
      g_ts.hasPosition    = true;
      g_ts.ticket         = g_trade.ResultOrder();
      g_ts.direction      = sig;
      g_ts.entryType      = etype;
      g_ts.entryPrice     = price;
      g_ts.openTime       = TimeCurrent();
      g_ts.spikeExtLow    = g_spikeExtLow;
      g_ts.spikeExtHigh   = g_spikeExtHigh;
      g_ts.beTriggered    = false;
      g_ts.tradeTakenCycle= true;
      g_lastTradeBar      = iTime(_Symbol,InpTF,0);
      PrintFormat("[SR] %s | %s | lot=%.2f | E=%.5f SL=%.5f TP=%.5f | ICT=%d(%s) | GOM=%s vn=%d",
                  isBuy?"BUY":"SELL",
                  etype==ENTRY_ANTICIPATION?"ANTICIPATION":"PULLBACK",
                  lot, price, sl, tp,
                  g_ict.Score, g_ict.Grade,
                  g_gom.verdict, g_gom.verdictNum);
   }
   else
   {
      PrintFormat("[SR] Ordre échoué %d: %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
      g_ts.tradeTakenCycle = true;
   }
   return ok;
}

//+------------------------------------------------------------------+
//| GESTION POSITION                                                 |
//+------------------------------------------------------------------+
void ManagePosition()
{
   ulong ticket = 0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==(long)InpMagic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) { ticket=t; break; }
   }
   if(ticket==0) { g_ts.hasPosition=false; return; }
   if(!PositionSelectByTicket(ticket)) return;

   double profit  = PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   double openPx  = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL   = PositionGetDouble(POSITION_SL);
   double curTP   = PositionGetDouble(POSITION_TP);
   long   posType = PositionGetInteger(POSITION_TYPE);
   double bid     = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask     = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double atr     = GetATR(1); if(atr<=0) return;
   double minD    = MinStopDist(atr);
   int    dg      = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   // ── Time Stop ───────────────────────────────────────────────────
   if(InpTimeStopMin > 0 && (int)(TimeCurrent()-g_ts.openTime) >= InpTimeStopMin*60)
   {
      g_trade.PositionClose(ticket,20);
      PrintFormat("[SR] TimeStop %dmin | PnL=$%.2f", InpTimeStopMin, profit);
      return;
   }

   // ── Quick Exit sur spike suivant ────────────────────────────────
   if(InpUseQuickExit && g_barsSinceSpike==0)
   {
      datetime lastBar = iTime(_Symbol,InpTF,1);
      if(lastBar != g_ts.openTime && profit >= atr*InpQuickExitMinPct)
      {
         g_trade.PositionClose(ticket,20);
         PrintFormat("[SR] QuickExit spike suivant | PnL=$%.2f", profit);
         return;
      }
   }

   // ── Smart Breakeven ─────────────────────────────────────────────
   if(InpUseSmartBE && !g_ts.beTriggered)
   {
      double spread = ask - bid;
      if(posType==POSITION_TYPE_BUY && bid-openPx >= atr*InpBETrigger)
      {
         double nsl = NormTick(openPx+spread*1.5, true);
         if(bid-nsl>=minD && nsl>curSL) { g_trade.PositionModify(ticket,nsl,curTP); g_ts.beTriggered=true; }
      }
      else if(posType==POSITION_TYPE_SELL && openPx-ask >= atr*InpBETrigger)
      {
         double nsl = NormTick(openPx-spread*1.5, false);
         if(nsl-ask>=minD && (curSL==0||nsl<curSL)) { g_trade.PositionModify(ticket,nsl,curTP); g_ts.beTriggered=true; }
      }
   }

   // ── Trailing Stop ────────────────────────────────────────────────
   if(InpUseTrail)
   {
      double trD = MathMax(atr*InpTrailATR, minD);
      if(posType==POSITION_TYPE_BUY && bid-openPx >= atr*InpTrailActivation)
      {
         double nsl = NormTick(bid-trD, false);
         if(nsl>curSL && bid-nsl>=minD) g_trade.PositionModify(ticket,nsl,curTP);
      }
      else if(posType==POSITION_TYPE_SELL && openPx-ask >= atr*InpTrailActivation)
      {
         double nsl = NormTick(ask+trD, true);
         if((curSL==0||nsl<curSL) && nsl-ask>=minD) g_trade.PositionModify(ticket,nsl,curTP);
      }
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+
void DashLbl(string id, string txt, int y, color clr, int sz=9)
{
   string n = "SR_" + id;
   if(ObjectFind(0,n) < 0)
   {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_BACK,      false);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetString (0,n,OBJPROP_FONT,      "Consolas");
   }
   ObjectSetString (0,n,OBJPROP_TEXT,     txt);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,6);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,    clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE, sz);
}

void ClearDash()
{
   string ids[] = {"T0","T1","T2","T3","T4","T5","T6","T7","T8","T9","T10","T11"};
   for(int i=0;i<ArraySize(ids);i++) ObjectDelete(0,"SR_"+ids[i]);
}

void DrawDash()
{
   if(!InpShowDashboard) return;

   double atr   = GetATR(1);
   double rsi   = GetRSI(1);
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq    = AccountInfoDouble(ACCOUNT_EQUITY);
   int    cycle = GetCycleLength();
   double pct   = (cycle>0) ? MathMin((double)g_barsSinceSpike/cycle,1.2)*100.0 : 0;
   int    nPos  = 0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==(long)InpMagic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) nPos++;
   }
   int wr = (g_sess.trades>0)?(int)MathRound((double)g_sess.wins/g_sess.trades*100):0;

   // Barre de cycle ASCII
   string bar=""; int fi=(int)(pct/10.0); if(fi>10)fi=10;
   for(int i=0;i<10;i++) bar+=(i<fi?"█":"░");

   int y=20, s=17;

   // Titre
   string cat = IsBoom() ? "▲ BOOM" : "▼ CRASH";
   DashLbl("T0", StringFormat("── SpikeRider | %s | %s ──", _Symbol, cat),
           y, clrGold, 10); y+=s+3;

   // Compte
   color bc = (eq < bal*0.97) ? clrTomato : clrSilver;
   DashLbl("T1", StringFormat("Bal $%.2f  Eq $%.2f  Pos:%d", bal, eq, nPos), y, bc); y+=s;

   // Session
   color pc = (g_sess.pnl >= 0) ? clrLimeGreen : clrTomato;
   DashLbl("T2", StringFormat("Session %+.2f$  %d trades  WR:%d%%  %s",
           g_sess.pnl, g_sess.trades, wr,
           g_sess.dailyLocked?"[VERROUILLÉ]":""), y, pc); y+=s;

   // Capital Manager target
   double target = g_sess.dayStartBalance * InpCMDailyTargetPct / 100.0;
   double stopL  = g_sess.dayStartBalance * InpCMDailyLossPct   / 100.0;
   DashLbl("T3", StringFormat("CM: target +$%.2f | stop -$%.2f", target, stopL), y, clrDimGray, 8); y+=s;

   // Indicateurs
   color rc = (rsi<30)?clrLimeGreen:(rsi>70)?clrTomato:clrSilver;
   DashLbl("T4", StringFormat("RSI %.1f  ATR %.5f  Compr:%.0f%%",
           rsi, atr, CalcATRCompression()*100), y, rc); y+=s;

   // Cycle
   string lvl = g_spike.level;
   color sc = (lvl=="imminent")?clrLime:(lvl=="spike")?clrOrangeRed:
              (lvl=="watch")?clrGold:(lvl=="overdue"||lvl=="late")?clrOrange:clrDimGray;
   DashLbl("T5", StringFormat("Cycle [%s] %.0f%%  %d/%d barres  %s",
           bar, pct, g_barsSinceSpike, cycle, lvl), y, sc); y+=s;

   // ZScore
   color zc = (MathAbs(g_spike.zScore)>=InpSpikeZScoreMin && InpSpikeZScoreMin>0)?clrLimeGreen:clrDimGray;
   DashLbl("T6", StringFormat("Z-Score %.2f  PreSpike:%s",
           g_spike.zScore,
           DetectPreSpikeCompression(IsBoom())?"🔥 OUI":"non"), y, zc); y+=s;

   // ICT Score
   color ic = (g_ict.Score>=70)?clrLimeGreen:(g_ict.Score>=50)?clrYellow:clrDimGray;
   DashLbl("T7", StringFormat("ICT %d(%s) %s%s%s%s%s%s",
           g_ict.Score, g_ict.Grade,
           g_ict.BOS?"BOS ":"", g_ict.CHOCH?"CHoCH ":"", g_ict.LiqSweep?"Liq ":"",
           g_ict.OB?"OB ":"", g_ict.FVG?"FVG ":"", g_ict.OTE?"OTE":""), y, ic); y+=s;

   // GOM verdict
   if(InpUseGOM)
   {
      int vn = g_gom.verdictNum;
      bool live = g_gom.connected && g_gom.valid &&
                  (int)(TimeCurrent()-g_gom.lastPoll) <= InpGOMMaxAgeSec;
      color gc = !live ? clrDimGray :
                 g_gom.counterTrend ? clrTomato :
                 (vn>=2)?clrLimeGreen:(vn<=-2)?clrTomato:clrOrange;
      int age = (g_gom.lastPoll>0) ? (int)(TimeCurrent()-g_gom.lastPoll) : -1;
      DashLbl("T8", StringFormat("GOM %s %-10s vn=%+d  Q=%.0f%%  C=%.0f%%  [%ds]",
              live ? "OK" : "OFF",
              g_gom.verdict, vn, g_gom.quality, g_gom.coherence, age),
              y, gc); y+=s;
   }

   // Fenêtre d'entrée
   color wc = g_spike.inWindow ? clrLimeGreen : clrDimGray;
   DashLbl("T9", StringFormat("Fenêtre %.0f-%.0f%%  BE:%s  Trail:%s  QExit:%s",
           InpWindowStart*100, InpWindowEnd*100,
           InpUseSmartBE?"ON":"off", InpUseTrail?"ON":"off", InpUseQuickExit?"ON":"off"),
           y, wc); y+=s;

   // Raison
   DashLbl("T10", StringFormat("→ %s", g_lastReason), y, clrDimGray, 8); y+=s;

   // Mode actif
   color mc = clrDimGray;
   if(g_spike.inWindow)      mc = clrLime;
   else if(g_ts.hasPosition) mc = clrOrange;
   DashLbl("T11", StringFormat("Mode: %s  |  Cooldown:%dbar",
           g_spike.inWindow?"[FENÊTRE ACTIVE]":(g_ts.hasPosition?"[POSITION]":"attente"),
           InpCooldownBars), y, mc, 8);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest&,
                        const MqlTradeResult&)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=(long)InpMagic) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol) return;
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_INOUT) return;

   double pnl = HistoryDealGetDouble(trans.deal,DEAL_PROFIT)
              + HistoryDealGetDouble(trans.deal,DEAL_SWAP)
              + HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
   g_sess.trades++;
   g_sess.pnl += pnl;
   if(pnl>0) g_sess.wins++;
   g_ts.hasPosition = false;

   PrintFormat("[SR] CLÔTURE | %s | PnL=%+.2f$ | Session=%+.2f$ | WR:%d/%d",
               pnl>0?"✓ GAIN":"✗ PERTE", pnl, g_sess.pnl, g_sess.wins, g_sess.trades);
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!IsBoom() && !IsCrash())
   {
      Alert("[SpikeRider] Symbole non Boom/Crash — attachez sur Boom ou Crash");
      return INIT_FAILED;
   }

   g_hATR = iATR(_Symbol, InpTF, InpATRPeriod);
   g_hRSI = iRSI(_Symbol, InpTF, InpRSIPeriod, PRICE_CLOSE);
   if(g_hATR==INVALID_HANDLE || g_hRSI==INVALID_HANDLE)
   { Alert("[SpikeRider] Erreur création indicateurs"); return INIT_FAILED; }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(50);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Etat initial
   ZeroMemory(g_ts);
   ZeroMemory(g_spike);
   ZeroMemory(g_ict);
   ZeroMemory(g_gom);
   ZeroMemory(g_sess);

   g_spike.level          = "none";
   g_ict.Grade            = "C";
   g_gom.verdict          = "WAIT";
   g_barsSinceSpike       = GetCycleLength() / 2;   // Démarrer à mi-cycle
   g_sess.dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_lastReason           = "Initialisation";

   int cycle = GetCycleLength();
   PrintFormat("[SpikeRider] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   PrintFormat("[SpikeRider] Symbole : %s | %s | Magic=%d",
               _Symbol, IsBoom()?"BOOM":"CRASH", InpMagic);
   PrintFormat("[SpikeRider] Cycle   : %d barres | Fenêtre %.0f-%.0f%%",
               cycle, InpWindowStart*100, InpWindowEnd*100);
   PrintFormat("[SpikeRider] ICT min : %d | GOM : %s | CM : %s",
               InpMinICTScore, InpUseGOM?"ON":"OFF", InpUseCM?"ON":"OFF");
   PrintFormat("[SpikeRider] SL=%.1f×ATR | TP=%.1f×ATR | Lot=%s",
               GetSL_ATR(), GetTP_ATR(),
               InpUseRiskPercent?StringFormat("%.1f%%",InpRiskPercent):StringFormat("%.2f",InpFixedLot));

   // GOM initial
   if(InpUseGOM) PollGOM();

   EventSetMillisecondTimer(500);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(g_hATR);
   IndicatorRelease(g_hRSI);
   ClearDash();
   Comment("");
   int wr = (g_sess.trades>0)?(int)MathRound((double)g_sess.wins/g_sess.trades*100):0;
   PrintFormat("[SpikeRider] Arrêté | Session=%+.2f$ | Trades=%d | WR=%d%%",
               g_sess.pnl, g_sess.trades, wr);
}

//+------------------------------------------------------------------+
//| OnTimer (500ms)                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   PollGOM();
   CheckDailyLimits();
   DrawDash();
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   // ── Nouvelle barre ──────────────────────────────────────────────
   datetime curBar = iTime(_Symbol, InpTF, 0);
   bool newBar = (curBar != g_lastProcessedBar);
   if(newBar)
   {
      g_lastProcessedBar = curBar;
      UpdateSpikeCounter();
   }

   // ── Sync position ───────────────────────────────────────────────
   bool hasPos = false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==(long)InpMagic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) { hasPos=true; break; }
   }
   if(!hasPos) g_ts.hasPosition = false;

   // ── Gestion position ouverte ────────────────────────────────────
   if(hasPos) { ManagePosition(); return; }

   // ── Guards ──────────────────────────────────────────────────────
   if(g_sess.dailyLocked) return;
   if(!newBar)             return;
   if(g_ts.tradeTakenCycle) return;

   // Cooldown entre trades
   if(g_lastTradeBar != 0 && InpCooldownBars > 0)
   {
      int bars = Bars(_Symbol, InpTF, g_lastTradeBar, curBar);
      if(bars < InpCooldownBars) return;
   }

   // ── Mise à jour spike + ICT pour le dashboard ───────────────────
   g_spike = AnalyzeSpike();
   g_ict   = CalcICT(IsBoom());

   // ── Évaluation entrée ───────────────────────────────────────────
   ESignal    sig   = SIG_NONE;
   EEntryType etype = ENTRY_NONE;
   string     reason= "";

   bool go = EvaluateEntry(sig, etype, reason);
   g_lastReason = reason;

   if(!go || sig==SIG_NONE) return;

   // Guard direction stricte
   if(IsBoom()  && sig==SIG_SELL) return;
   if(IsCrash() && sig==SIG_BUY)  return;

   PrintFormat("[SR] SETUP %s | %s | %s",
               sig==SIG_BUY?"BUY":"SELL",
               etype==ENTRY_ANTICIPATION?"ANTICIPATION":"PULLBACK",
               reason);

   OpenTrade(sig, etype);
}
//+------------------------------------------------------------------+
