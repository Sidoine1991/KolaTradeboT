//+------------------------------------------------------------------+
//|                                         DerivEAPro_v10.mq5       |
//|   Boom & Crash Spike Catcher — Version Définitive Corrigée      |
//|   Fusion SpikeRider v5.06 + DerivEAPro v9 + v8 Elite            |
//+------------------------------------------------------------------+
#property copyright "DerivEAPro v10 — TradBOT"
#property version   "10.01"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== GESTION DU RISQUE ==="
input double InpFixedLot         = 0.20;
input double InpMaxDailyLossPct  = 3.0;

input group "=== DÉTECTION SPIKE ==="
input ENUM_TIMEFRAMES InpTF      = PERIOD_M1;
input int    InpLookback         = 15;
input double InpZScoreMin        = 1.8;
input double InpMinMoveMult      = 2.5;
input int    InpRSIPeriod        = 14;
input double InpRSIBoomMax       = 55.0;
input double InpRSICrashMin      = 45.0;
input bool   InpRequireRSI       = false;
input int    InpStairBars        = 4;
input double InpStairMinPct      = 0.0;

input group "=== PRÉ-SPIKE ==="
input bool   InpPreSpikeEnabled  = true;
input bool   InpPreSpikeUseMarket= true;
input int    InpSpikeFrequency   = 0;
input double InpImminenceThresh  = 40.0;
input bool   InpRequirePriorFavorable = false;
input double InpPendingOffsetATR = 0.2;
input int    InpPendingMaxAgeSec = 60;
input double InpAtrCompressRatio = 0.80;

input group "=== STAIR-ONLY ENTRY ==="
input bool   InpEnableStairOnlyEntry = true;
input double InpStairOnlyMinPct      = 0.67;
input bool   InpStairOnlyNeedImminence = true;

input group "=== SMC SPIKE ==="
input bool   InpRequireSMC       = false;
input bool   InpRequireBOS       = false;
input bool   InpRequireCHOCH     = false;
input bool   InpRequireOTE       = false;
input int    InpSwingLookback    = 40;
input bool   InpDrawSMCLevels    = true;
input double InpOTEBypassZScore  = 1.8;

input group "=== GESTION DE POSITION ==="
input int    InpATRPeriod        = 14;
input double InpSL_ATR           = 1.5;
input double InpTP_ATR           = 2.5;
input bool   InpUseChartStops    = true;
input bool   InpUseTrailing      = false;
input double InpTrailActivation  = 0.5;
input double InpTrailStep        = 0.5;
input int    InpCooldownSec      = 10;

input group "=== SERVEUR AI ==="
input bool   InpUsePrior         = true;
input string InpAIServerURL      = "http://127.0.0.1:8000";
input int    InpPriorTimeoutMs   = 2000;
input bool   InpUseAngelOfSpike  = false;
input bool   InpUseZonePrior     = false;
input bool   InpUseRealtimeCross = true;
input bool   InpSendFeedback     = true;
input bool   InpSendStairDetect  = false;
input bool   InpSendInfluence    = false;

input group "=== FILTRES TENDANCE ==="
input bool   InpRequireTrendAlign   = false;
input int    InpTrendBars           = 6;
input double InpTrendStrongATR      = 0.28;
input int    InpConfirmBars         = 2;
input bool   InpPreSpikeNeedConfirm = true;
input int    InpEMAFast             = 9;
input int    InpEMASlow             = 21;
input bool   InpRequireM1PushAlign  = false;

input group "=== BRIDGE TRADINGVIEW ==="
input bool   InpUseTVBridge         = true;
input int    InpTVBridgePollSec     = 2;
input int    InpTVBridgeMaxAgeSec   = 30;
input bool   InpRequireTVSniper     = false;
input double InpSniperMinConfidence = 80.0;
input bool   InpBlockCounterTrendTV = true;
input bool   InpBlockCorrectionZone = false;

input group "=== CONFIRMATION TV ==="
input bool   InpUseTVConfirm        = true;
input int    InpTVConfirmIntervalSec= 45;
input int    InpTVConfirmMaxAgeSec  = 120;

input group "=== SORTIE RAPIDE ==="
input bool   InpUseQuickExit        = true;
input int    InpMinHoldSec          = 3;
input double InpQuickExitMinProfitUSD= 0.05;
input double InpQuickExitMinProfitBoom600= 0.10;
input bool   InpExitOnSameSpikeBar  = false;

input group "=== FILTRES ==="
input bool   InpCheckNewBar      = false;
input int    InpMaxSpreadPoints  = 500;

input group "=== FILTRE GLOBAL TF ==="
input bool   InpRequireGlobalDir    = true;
input int    InpGlobalMinConfidence = 70;
input double InpGlobalMinCoherence  = 60.0;

input group "=== CAPITAL MANAGER ==="
input bool   InpUseCM              = true;
input double InpCMDailyTargetPct   = 3.0;
input double InpCMDailyStopPct     = 3.0;

input group "=== MULTI-TF FILTER ==="
input bool   InpUseMTF             = true;
input ENUM_TIMEFRAMES InpMTF1      = PERIOD_M5;
input ENUM_TIMEFRAMES InpMTF2      = PERIOD_M15;
input ENUM_TIMEFRAMES InpMTF3      = PERIOD_H1;
input int    InpEMAMTF             = 21;

input group "=== MARKET REGIME ==="
input bool   InpUseRegime          = true;

input group "=== SPIKE SCALP ==="
input bool   InpUseImmediateScalp  = false;
input double InpScalpZScore        = 2.5;
input int    InpScalpLookback      = 20;
input double InpScalpExitPips      = 5.0;

input group "=== AFFICHAGE ==="
input bool   InpShowDashboard    = true;
input int    InpDashPanelWidth   = 420;
input bool   InpDebug            = false;
input ulong  InpMagic            = 20260524;

//+------------------------------------------------------------------+
//| TYPES INTERNES                                                   |
//+------------------------------------------------------------------+
enum ESpikeType { SPIKE_NONE, SPIKE_BUY, SPIKE_SELL };
enum ERegime    { REGIME_TRENDING, REGIME_RANGING, REGIME_EXPLODING };

struct SpikeResult
{
   ESpikeType type;
   double     zScore;
   double     rsi;
   double     atr;
   double     stairScore;
};

struct SR_SMCSetup
{
   bool   valid;
   bool   bos;
   bool   choch;
   bool   inOTE;
   double fib50;
   double fib618;
   double fib786;
   double oteLow;
   double oteHigh;
   double breakLevel;
   string tag;
};

struct SGhost
{
   string verdict;
   double quality;
   double delta;
   double cvd;
   double buypct;
   double sellpct;
   int    compass;
   bool   valid;
   ulong  loadedAt;
};

struct SGomTV
{
   string symbol;
   string verdict;
   double quality;
   double delta;
   double cvd;
   double buypct;
   double sellpct;
   int    compass;
   double imbalance;
   double volume_profile;
   double liquidity_score;
   double smart_money_idx;
   double setup_entry;
   double setup_sl;
   double setup_tp1;
   double setup_tp2;
   double setup_rr;
   string setup_dir;
   bool   setup_is_fallback; // true si généré par EA (pas par TV)

   // Multi-Timeframe détaillé
   string tf_m1_dir;
   int    tf_m1_rsi;
   string tf_m5_dir;
   int    tf_m5_rsi;
   string tf_m15_dir;
   int    tf_m15_rsi;
   string tf_m30_dir;
   int    tf_m30_rsi;
   string tf_h1_dir;
   int    tf_h1_rsi;
   string tf_h4_dir;
   int    tf_h4_rsi;
   string tf_d1_dir;
   int    tf_d1_rsi;
   string tf_global_dir;
   int    tf_global_strength;

   datetime loadedAt;
   bool valid;
};

struct TradeRecord
{
   ulong    ticket;
   ESpikeType spikeType;
   double   entryPrice;
   datetime openTime;
   double   imminenceAtEntry;
   double   zScoreAtEntry;
   double   rsiAtEntry;
   double   stairAtEntry;
   double   zonePriorAtEntry;
   double   angelConfAtEntry;
   string   stairEventId;
   string   stairClientId;
};

struct SymbolCtx
{
   string      sym;
   bool        isBoom;
   int         hATR, hRSI, hEMAFast, hEMASlow;
   int         barsSince;
   datetime    lastBar;
   datetime    lastTrade;
   datetime    lastEntryFail;
   datetime    lastEntryBarTime;
   SR_SMCSetup smc;
};

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade      g_trade;
int         g_hATR            = INVALID_HANDLE;
int         g_hRSI            = INVALID_HANDLE;
int         g_hEMAFast        = INVALID_HANDLE;
int         g_hEMASlow        = INVALID_HANDLE;
int         g_hEMA9           = INVALID_HANDLE;
int         g_hEMA21          = INVALID_HANDLE;
int         g_hATR_G          = INVALID_HANDLE;

datetime    g_lastBar         = 0;
datetime    g_lastTrade       = 0;
datetime    g_lastEntryFail   = 0;
datetime    g_lastEntryBarTime= 0;
double      g_dayStartBalance = 0.0;
datetime    g_dayTag          = 0;

int         g_barsSinceLastSpike = 0;
datetime    g_lastSpikeBar       = 0;
ulong       g_pendingTicket      = 0;
datetime    g_pendingPlacedAt    = 0;

SR_SMCSetup g_smc;
datetime    g_lastSMCBar      = 0;

double      g_priorCaptureRate   = 0.5;
double      g_priorAtrMult       = 2.5;
double      g_priorAtrThreshold  = 1.8;
bool        g_priorFavorable     = true;
int         g_priorSampleCount   = 0;
string      g_priorSource        = "init";
datetime    g_lastPriorFetch     = 0;
datetime    g_lastPriorAttempt   = 0;
int         g_lastPriorHour      = -1;

double      g_zonePrior          = 0.5;
double      g_zoneSpikeRate      = 0.0;
double      g_zonePropiceScore   = 0.0;
int         g_zoneSamples        = 0;
datetime    g_lastZoneFetch      = 0;
datetime    g_lastZoneAttempt    = 0;
int         g_lastZoneHour       = -1;

string      g_angelSignal        = "HOLD";
double      g_angelConfidence    = 0.0;
string      g_angelMarketState   = "";
datetime    g_lastAngelFetch     = 0;
datetime    g_lastAngelAttempt   = 0;
int         g_lastAngelHour      = -1;

bool        g_realtimeSpikeActive = false;
string      g_realtimeSpikeDir    = "";
datetime    g_lastRealtimeFetch   = 0;

string      g_tvDirection         = "NEUTRAL";
string      g_tvStructureM15      = "";
string      g_tvStructureH1       = "";
double      g_tvBiasScore         = 0.0;
datetime    g_lastTVFetch         = 0;
datetime    g_lastTVAttempt       = 0;

bool        g_spikeTVOk           = false;
datetime    g_lastSpikeTVFetch    = 0;
datetime    g_lastSpikeTVAttempt  = 0;
double      g_tvImminencePct      = 0.0;
double      g_tvSniperConfidence  = 0.0;
bool        g_tvSniperReady       = false;
bool        g_tvCounterTrend      = false;
string      g_tvObBias            = "none";
string      g_tvEmaTrend          = "neutral";
string      g_tvSpikeDir          = "NEUTRAL";
bool        g_tvSpikeDetected     = false;
double      g_tvSpikeZ            = 0.0;
bool        g_tvEntryValid        = false;
string      g_tvGlobalDir         = "";
int         g_tvGlobalStrength    = 0;
double      g_tvCoherencePct      = 0.0;

string      g_lastStairEventId    = "";
string      g_lastStairClientId   = "";

TradeRecord g_openTrades[10];
int         g_openTradesCount     = 0;

SymbolCtx   g_syms[20];
int         g_symCount            = 0;

datetime    g_lastNotifTime       = 0;
double      g_lastNotifImm        = 0.0;

double      g_cmDayStartBal       = 0.0;
datetime    g_cmDayTag            = 0;
bool        g_cmLocked            = false;

ERegime     g_regime              = REGIME_TRENDING;
int         g_mtfAligned          = 3;

SGhost      g_ghost;
SGomTV      g_gomTV;
datetime    g_lastGhostPoll       = 0;

double      g_srLevels[];
string      g_srLabels[];
color       g_srColors[];
datetime    g_lastSRFetch         = 0;

datetime    g_spikeTs[];
string      g_spikeDirs[];
bool        g_spikeCaptured[];
int         g_spikeCount          = 0;
datetime    g_lastSpikeLevelFetch = 0;

//+------------------------------------------------------------------+
//| DÉTECTION SYMBOLE                                                |
//+------------------------------------------------------------------+
bool IsBoom(const string s)
{
   return StringFind(s,"Boom",0)>=0 || StringFind(s,"boom",0)>=0 ||
          StringFind(s,"GAIN",0)>=0 || StringFind(s,"gain",0)>=0;
}
bool IsCrash(const string s)
{
   return StringFind(s,"Crash",0)>=0 || StringFind(s,"crash",0)>=0 ||
          StringFind(s,"PAIN",0)>=0  || StringFind(s,"pain",0)>=0;
}
bool IsSupportedSymbol(const string s) { return IsBoom(s) || IsCrash(s); }

int GetEffectiveSpikeFrequency()
{
   if(InpSpikeFrequency > 0) return InpSpikeFrequency;
   const string nums[] = {"1000","900","600","500","300"};
   for(int i = 0; i < ArraySize(nums); i++)
      if(StringFind(_Symbol, nums[i]) >= 0)
         return (int)StringToInteger(nums[i]);
   return 600;
}

//+------------------------------------------------------------------+
//| SMC STUB (inline — pas de fichier include requis)               |
//+------------------------------------------------------------------+
void SR_BuildSMCSetup(const string sym, ENUM_TIMEFRAMES tf, bool isBoom,
                      double px, int lookback, SR_SMCSetup &out)
{
   out.valid      = false;
   out.bos        = false;
   out.choch      = false;
   out.inOTE      = false;
   out.fib50      = 0;
   out.fib618     = 0;
   out.fib786     = 0;
   out.oteLow     = 0;
   out.oteHigh    = 0;
   out.breakLevel = 0;
   out.tag        = "NoSMC";

   if(!InpRequireSMC) { out.tag = "SMC-OFF"; return; }

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(sym, tf, 1, lookback, r);
   if(got < lookback / 2) return;

   double hi = r[0].high, lo = r[0].low;
   int    hiIdx = 0, loIdx = 0;
   for(int i = 1; i < got; i++)
   {
      if(r[i].high > hi) { hi = r[i].high; hiIdx = i; }
      if(r[i].low  < lo) { lo = r[i].low;  loIdx = i; }
   }

   double swing = hi - lo;
   if(swing <= 0) return;

   out.fib50  = isBoom ? (hi - swing * 0.50) : (lo + swing * 0.50);
   out.fib618 = isBoom ? (hi - swing * 0.618): (lo + swing * 0.618);
   out.fib786 = isBoom ? (hi - swing * 0.786): (lo + swing * 0.786);
   out.oteLow = isBoom ? out.fib786 : out.fib618;
   out.oteHigh= isBoom ? out.fib618 : out.fib786;
   out.breakLevel = isBoom ? hi : lo;

   out.bos   = isBoom ? (px > hi * 0.998) : (px < lo * 1.002);
   out.inOTE = (px >= MathMin(out.oteLow, out.oteHigh) &&
                px <= MathMax(out.oteLow, out.oteHigh));
   out.valid = true;
   out.tag   = StringFormat("%s|BOS%s|OTE%s",
               (isBoom?"BOOM":"CRASH"),
               (out.bos?"+":"-"),
               (out.inOTE?"+":"-"));
}

bool SR_SMCAllowsEntry(const SR_SMCSetup &smc, bool isBoom,
                       bool needBOS, bool needCHOCH, bool needOTE,
                       bool isSpike, double zScore, double zMin, string &reason)
{
   if(!InpRequireSMC) { reason="SMC-OFF"; return true; }
   if(!smc.valid)     { reason="SMC invalide"; return false; }
   if(needBOS && !smc.bos)   { reason="BOS manquant"; return false; }
   if(needCHOCH && !smc.choch){ reason="CHOCH manquant"; return false; }
   if(needOTE && !smc.inOTE) { reason="Prix hors OTE"; return false; }
   reason = smc.tag;
   return true;
}

//+------------------------------------------------------------------+
//| LECTURE ATR / RSI                                                |
//+------------------------------------------------------------------+
double GetATR()
{
   if(g_hATR == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_hATR, 0, 0, 3, buf) < 3) return 0.0;
   return buf[1];
}

double GetRSI()
{
   if(g_hRSI == INVALID_HANDLE) return 50.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_hRSI, 0, 0, 3, buf) < 3) return 50.0;
   return buf[1];
}

double GetATRMean()
{
   if(g_hATR == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   int n = InpLookback + 2;
   if(CopyBuffer(g_hATR, 0, 0, n, buf) < n) return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= InpLookback; i++) sum += buf[i];
   return sum / InpLookback;
}

double GetRecentBodySum(const int bars, const int shiftStart = 1)
{
   if(bars <= 0) return 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, shiftStart, bars, r) < bars) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < bars; i++) sum += r[i].close - r[i].open;
   return sum;
}

int GetMicroTrendPush(const int bars)
{
   double atr = GetATR();
   if(atr <= 0.0) return 0;
   double sum = GetRecentBodySum(bars, 1);
   if(sum >= atr * InpTrendStrongATR) return 1;
   if(sum <= -atr * InpTrendStrongATR) return -1;
   return 0;
}

bool HasDirectionConfirmation(const ESpikeType dir)
{
   if(InpConfirmBars <= 0) return true;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, 1, InpConfirmBars, r) < InpConfirmBars) return false;
   int ok = 0;
   for(int i = 0; i < InpConfirmBars; i++)
   {
      double body = r[i].close - r[i].open;
      if(dir == SPIKE_BUY  && body > 0.0) ok++;
      if(dir == SPIKE_SELL && body < 0.0) ok++;
   }
   return (ok >= InpConfirmBars);
}

//+------------------------------------------------------------------+
//| GHOST MODULE — OrderFlow Intelligence (corrigé pour synthétiques)|
//+------------------------------------------------------------------+
double GHOST_EstimateDelta(const MqlRates &c)
{
   double range = c.high - c.low;
   if(range < 1e-10) return 0.0;
   double bodyRatio = (c.close - c.open) / range;
   double upperWick = c.high - MathMax(c.open, c.close);
   double lowerWick = MathMin(c.open, c.close) - c.low;
   double wickBias  = (lowerWick - upperWick) / range;
   return (bodyRatio * 0.7 + wickBias * 0.3);
}

double GHOST_CalcCVD(int lookback = 60)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, _Period, 1, lookback, r);
   if(got < 1) return 0.0;
   double cvd = 0.0;
   for(int i = got - 1; i >= 0; i--) cvd += GHOST_EstimateDelta(r[i]);
   return cvd;
}

void GHOST_CalcSentiment(int period, double &buyPct, double &sellPct)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, _Period, 1, period, r);
   if(got < 1) { buyPct = 50; sellPct = 50; return; }
   double bullBodies = 0, bearBodies = 0;
   for(int i = 0; i < got; i++)
   {
      double body  = MathAbs(r[i].close - r[i].open);
      double range = r[i].high - r[i].low;
      if(range < 1e-10) continue;
      double w = body / range;
      if(r[i].close > r[i].open) bullBodies += w;
      else                        bearBodies += w;
   }
   double tot = bullBodies + bearBodies;
   if(tot < 1e-10) { buyPct = 50; sellPct = 50; return; }
   buyPct  = bullBodies / tot * 100.0;
   sellPct = 100.0 - buyPct;
}

double GHOST_Atan2Custom(double y, double x)
{
   if(x == 0.0)
   {
      if(y > 0) return  M_PI / 2.0;
      if(y < 0) return -M_PI / 2.0;
      return 0.0;
   }
   double a = MathArctan(y / x);
   if(x < 0) a += (y >= 0) ? M_PI : -M_PI;
   return a;
}

//+------------------------------------------------------------------+
//| Parse JSON simple sans library externe (GOM TV)                  |
//+------------------------------------------------------------------+
string JsonExtractStringGOM(const string &body, const string &key)
{
   int pos = StringFind(body, "\""+key+"\"");
   if(pos < 0) return "";
   int colon = StringFind(body, ":", pos);
   if(colon < 0) return "";
   int quote1 = StringFind(body, "\"", colon);
   if(quote1 < 0) return "";
   int quote2 = StringFind(body, "\"", quote1+1);
   if(quote2 < 0) return "";
   return StringSubstr(body, quote1+1, quote2-quote1-1);
}

double JsonExtractDoubleGOM(const string &body, const string &key)
{
   int pos = StringFind(body, "\""+key+"\"");
   if(pos < 0) return 0.0;
   int colon = StringFind(body, ":", pos);
   if(colon < 0) return 0.0;
   int start = colon + 1;
   while(start < StringLen(body) &&
         (StringGetCharacter(body,start)==' ' ||
          StringGetCharacter(body,start)=='\t')) start++;
   int end = start;
   while(end < StringLen(body))
   {
      ushort ch = StringGetCharacter(body,end);
      if(ch==',' || ch=='}' || ch==']' || ch=='\n' || ch==' ') break;
      end++;
   }
   string numStr = StringSubstr(body, start, end-start);
   StringReplace(numStr, " ", "");
   StringReplace(numStr, "\t", "");
   StringReplace(numStr, "\n", "");
   if(StringLen(numStr) == 0) return 0.0;
   if(numStr == "null") return 0.0;
   return StringToDouble(numStr);
}

int JsonExtractIntGOM(const string &body, const string &key)
{
   return (int)JsonExtractDoubleGOM(body, key);
}

//+------------------------------------------------------------------+
//| Charger GOM depuis data/gom_signal.json (GOM poller Python)     |
//+------------------------------------------------------------------+
bool LoadGOMFromTV()
{
   if((int)(TimeCurrent() - g_gomTV.loadedAt) < 3) return g_gomTV.valid;

   string filePath = "D:\\Dev\\TradBOT\\data\\gom_signal.json";
   int handle = FileOpen(filePath, FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      if(InpDebug) PrintFormat("[v10] ⚠️  GOM TV: fichier non trouvé %s", filePath);
      g_gomTV.valid = false;
      return false;
   }

   string content = "";
   while(!FileIsEnding(handle)) content += FileReadString(handle);
   FileClose(handle);

   if(StringLen(content) < 10)
   {
      if(InpDebug) Print("[v10] ⚠️  GOM TV: fichier vide");
      g_gomTV.valid = false;
      return false;
   }

   string sym = JsonExtractStringGOM(content, "symbol");
   bool symbolMatch = false;
   if(StringFind(_Symbol, "Boom") >= 0 && StringFind(sym, "Boom") >= 0) symbolMatch = true;
   if(StringFind(_Symbol, "Crash") >= 0 && StringFind(sym, "Crash") >= 0) symbolMatch = true;

   if(!symbolMatch)
   {
      if(InpDebug) PrintFormat("[v10] GOM TV: symbole mismatch (EA=%s, TV=%s)", _Symbol, sym);
      g_gomTV.valid = false;
      return false;
   }

   g_gomTV.symbol = sym;
   g_gomTV.verdict = JsonExtractStringGOM(content, "verdict");
   g_gomTV.quality = JsonExtractDoubleGOM(content, "quality");
   g_gomTV.delta = JsonExtractDoubleGOM(content, "delta");
   g_gomTV.cvd = JsonExtractDoubleGOM(content, "cvd");
   g_gomTV.buypct = JsonExtractDoubleGOM(content, "buypct");
   g_gomTV.sellpct = JsonExtractDoubleGOM(content, "sellpct");
   g_gomTV.compass = JsonExtractIntGOM(content, "compass");
   g_gomTV.imbalance = JsonExtractDoubleGOM(content, "imbalance");
   g_gomTV.volume_profile = JsonExtractDoubleGOM(content, "volume_profile");
   g_gomTV.liquidity_score = JsonExtractDoubleGOM(content, "liquidity_score");
   g_gomTV.smart_money_idx = JsonExtractDoubleGOM(content, "smart_money_idx");
   g_gomTV.setup_entry = JsonExtractDoubleGOM(content, "setup_entry");
   g_gomTV.setup_sl = JsonExtractDoubleGOM(content, "setup_sl");
   g_gomTV.setup_tp1 = JsonExtractDoubleGOM(content, "setup_tp1");
   g_gomTV.setup_tp2 = JsonExtractDoubleGOM(content, "setup_tp2");
   g_gomTV.setup_rr = JsonExtractDoubleGOM(content, "setup_rr");
   g_gomTV.setup_dir = JsonExtractStringGOM(content, "setup_dir");
   g_gomTV.setup_is_fallback = false; // Setup original de TV (si entry > 0)

   // Parse timeframes depuis JSON
   double tfGlobalNum = JsonExtractDoubleGOM(content, "tf_global_dir");
   if(tfGlobalNum > 0.5)
      g_gomTV.tf_global_dir = "BULL";
   else if(tfGlobalNum < -0.5)
      g_gomTV.tf_global_dir = "BEAR";
   else
      g_gomTV.tf_global_dir = "NEUT";

   g_gomTV.tf_global_strength = (int)JsonExtractDoubleGOM(content, "tf_global_strength");

   // TF individuels (fallback: génération automatique si absent)
   int tfBullCount = (int)JsonExtractDoubleGOM(content, "tf_bull_count");
   int tfBearCount = (int)JsonExtractDoubleGOM(content, "tf_bear_count");

   // Générer TF simplifiés basés sur global et counts
   if(tfBullCount > tfBearCount)
   {
      g_gomTV.tf_m1_dir = "BULL";
      g_gomTV.tf_m5_dir = "BULL";
      g_gomTV.tf_m15_dir = (tfBearCount >= 2) ? "BEAR" : "BULL";
      g_gomTV.tf_m30_dir = (tfBearCount >= 3) ? "BEAR" : "NEUT";
      g_gomTV.tf_h1_dir = (tfBearCount >= 4) ? "BEAR" : "NEUT";
      g_gomTV.tf_h4_dir = (tfBearCount >= 5) ? "BEAR" : "NEUT";
      g_gomTV.tf_d1_dir = (tfBearCount >= 6) ? "BEAR" : "NEUT";
   }
   else
   {
      g_gomTV.tf_m1_dir = (tfBullCount >= 2) ? "BULL" : "BEAR";
      g_gomTV.tf_m5_dir = (tfBullCount >= 1) ? "BULL" : "BEAR";
      g_gomTV.tf_m15_dir = "BEAR";
      g_gomTV.tf_m30_dir = "BEAR";
      g_gomTV.tf_h1_dir = "BEAR";
      g_gomTV.tf_h4_dir = "BEAR";
      g_gomTV.tf_d1_dir = "BEAR";
   }

   // RSI par défaut (peut être enrichi si JSON contient tf_m1_rsi, etc.)
   g_gomTV.tf_m1_rsi = 50;
   g_gomTV.tf_m5_rsi = 50;
   g_gomTV.tf_m15_rsi = 50;
   g_gomTV.tf_m30_rsi = 50;
   g_gomTV.tf_h1_rsi = 50;
   g_gomTV.tf_h4_rsi = 50;
   g_gomTV.tf_d1_rsi = 50;

   g_gomTV.loadedAt = TimeCurrent();
   g_gomTV.valid = (StringLen(g_gomTV.verdict) > 0);

   if(InpDebug && g_gomTV.valid)
   {
      PrintFormat("[v10] ✅ GOM TV: %s | verdict=%s | delta=%.2f | imbalance=%.2f | liquidity=%.2f",
         g_gomTV.symbol, g_gomTV.verdict, g_gomTV.delta, g_gomTV.imbalance, g_gomTV.liquidity_score);
   }

   return g_gomTV.valid;
}

//+------------------------------------------------------------------+
//| Génère setup automatique si GOM TV n'en fournit pas             |
//+------------------------------------------------------------------+
void GenerateFallbackSetup()
{
   // Si setup déjà fourni par GOM TV (et non fallback), ne rien faire
   if(g_gomTV.setup_entry > 0 && !g_gomTV.setup_is_fallback) return;

   // Si pas de verdict valide, impossible de générer setup
   if(g_gomTV.verdict != "BUY" && g_gomTV.verdict != "SELL") return;

   // Récupérer prix actuel et ATR
   double close = iClose(_Symbol, _Period, 0);
   if(close <= 0) return;

   double atr_buf[];
   ArraySetAsSeries(atr_buf, true);
   if(g_hATR_G == INVALID_HANDLE) g_hATR_G = iATR(_Symbol, _Period, 14);
   if(CopyBuffer(g_hATR_G, 0, 1, 1, atr_buf) < 1) return;
   double atr_val = atr_buf[0];
   if(atr_val < 1e-10) return;

   // Multipliers SL/TP basés sur qualité
   double slMult = 1.5;
   double tp1Mult = 2.0;
   double tp2Mult = 3.0;

   // Ajuster selon qualité du signal
   if(g_gomTV.quality >= 70)
   {
      slMult = 1.2;
      tp1Mult = 2.5;
      tp2Mult = 4.0;
   }
   else if(g_gomTV.quality < 40)
   {
      slMult = 2.0;
      tp1Mult = 1.5;
      tp2Mult = 2.5;
   }

   // Générer setup selon direction
   if(g_gomTV.verdict == "BUY")
   {
      g_gomTV.setup_entry = close;
      g_gomTV.setup_sl    = close - (atr_val * slMult);
      g_gomTV.setup_tp1   = close + (atr_val * tp1Mult);
      g_gomTV.setup_tp2   = close + (atr_val * tp2Mult);
      g_gomTV.setup_dir   = "BUY";
   }
   else if(g_gomTV.verdict == "SELL")
   {
      g_gomTV.setup_entry = close;
      g_gomTV.setup_sl    = close + (atr_val * slMult);
      g_gomTV.setup_tp1   = close - (atr_val * tp1Mult);
      g_gomTV.setup_tp2   = close - (atr_val * tp2Mult);
      g_gomTV.setup_dir   = "SELL";
   }

   // Calculer Risk/Reward
   double risk   = MathAbs(g_gomTV.setup_entry - g_gomTV.setup_sl);
   double reward = MathAbs(g_gomTV.setup_tp1 - g_gomTV.setup_entry);
   g_gomTV.setup_rr = (risk > 1e-10) ? (reward / risk) : 0;

   // Marquer comme fallback
   g_gomTV.setup_is_fallback = true;

   if(InpDebug)
   {
      PrintFormat("[v10] 📊 Setup Fallback généré: %s Entry=%.2f SL=%.2f TP1=%.2f TP2=%.2f R:R=%.2f (quality=%.0f%%, ATR-based)",
         g_gomTV.setup_dir, g_gomTV.setup_entry, g_gomTV.setup_sl,
         g_gomTV.setup_tp1, g_gomTV.setup_tp2, g_gomTV.setup_rr, g_gomTV.quality);
   }
}

int GHOST_CalcCompass()
{
   if(g_hEMA9  == INVALID_HANDLE) g_hEMA9  = iMA(_Symbol, _Period, 9,  0, MODE_EMA, PRICE_CLOSE);
   if(g_hEMA21 == INVALID_HANDLE) g_hEMA21 = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hATR_G == INVALID_HANDLE) g_hATR_G = iATR(_Symbol, _Period, 14);
   double ema9[], ema21[], atr_buf[];
   ArraySetAsSeries(ema9,true); ArraySetAsSeries(ema21,true); ArraySetAsSeries(atr_buf,true);
   if(CopyBuffer(g_hEMA9,0,0,5,ema9)<5 || CopyBuffer(g_hEMA21,0,0,2,ema21)<2 ||
      CopyBuffer(g_hATR_G,0,1,1,atr_buf)<1) return 0;
   double atr_val = atr_buf[0];
   if(atr_val < 1e-10) return 0;
   double emaDiff = (ema9[0] - ema21[0]) / atr_val;
   double slope   = (ema9[0] - ema9[4]) / (4.0 * atr_val);
   double angle   = GHOST_Atan2Custom(slope, emaDiff) * 180.0 / M_PI;
   if(angle < 0) angle += 360.0;
   static const double centers[8] = {0,45,90,135,180,225,270,315};
   int octant = 0; double best = 360;
   for(int i = 0; i < 8; i++)
   {
      double diff = MathAbs(angle - centers[i]);
      if(diff > 180) diff = 360 - diff;
      if(diff < best) { best = diff; octant = i; }
   }
   return octant;
}

void PollGHOST()
{
   if((int)(TimeCurrent() - g_lastGhostPoll) < 3) return;
   g_lastGhostPoll = TimeCurrent();

   // ── PRIORITÉ 1 : Charger GOM depuis TradingView ────────────────
   bool gomLoaded = LoadGOMFromTV();

   if(gomLoaded && g_gomTV.valid)
   {
      // Générer setup automatique si GOM TV n'en fournit pas
      GenerateFallbackSetup();

      // Utiliser données GOM TV (plus précises que calcul local)
      g_ghost.verdict = g_gomTV.verdict;
      g_ghost.quality = g_gomTV.quality;
      g_ghost.delta = g_gomTV.delta;
      g_ghost.cvd = g_gomTV.cvd;
      g_ghost.buypct = g_gomTV.buypct;
      g_ghost.sellpct = g_gomTV.sellpct;
      g_ghost.compass = g_gomTV.compass;
      g_ghost.valid = true;
      g_ghost.loadedAt = TimeCurrent();

      static string lastVerdict = "";
      if(g_ghost.verdict != lastVerdict)
      {
         PrintFormat("[v10] 🎯 GOM TV: %s (q=%.0f%%) | imbalance=%.2f | liquidity=%.2f | smart_money=%.2f",
            g_ghost.verdict, g_ghost.quality,
            g_gomTV.imbalance, g_gomTV.liquidity_score, g_gomTV.smart_money_idx);
         lastVerdict = g_ghost.verdict;
      }

      return;  // GOM TV chargé avec succès
   }

   // ── FALLBACK : Calcul local GHOST (si GOM TV indisponible) ─────
   if(InpDebug && !gomLoaded)
      Print("[v10] ℹ️  GOM TV indisponible → fallback calcul local");

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, _Period, 1, 60, r);
   if(got < 20) { g_ghost.valid = false; return; }
   double sumDelta = 0;
   for(int i = 0; i < got; i++) sumDelta += GHOST_EstimateDelta(r[i]);
   double deltaAvg = sumDelta / got;
   double cvd      = GHOST_CalcCVD(60);
   double buyPct = 50, sellPct = 50;
   GHOST_CalcSentiment(40, buyPct, sellPct);
   int compass = GHOST_CalcCompass();
   double quality = 40.0;
   if(MathAbs(deltaAvg) > 0.3)  quality += 20.0;
   if(MathAbs(deltaAvg) > 0.55) quality += 15.0;
   if(MathAbs(cvd)      > 5.0)  quality += 15.0;
   if(buyPct > 62 || buyPct < 38) quality += 10.0;
   quality = MathMin(quality, 100.0);
   string verdict = "WAIT";
   bool isBoom  = IsBoom(_Symbol);
   bool isCrash = IsCrash(_Symbol);
   bool ghostBuy  = (deltaAvg > 0.25 && buyPct > 58 && cvd > 2.0);
   bool ghostSell = (deltaAvg < -0.25 && buyPct < 42 && cvd < -2.0);
   if(ghostBuy  && isBoom)  verdict = "BUY";
   if(ghostSell && isCrash) verdict = "SELL";
   if(verdict=="WAIT" && isBoom  && deltaAvg > 0.4 && buyPct > 55) verdict = "BUY";
   if(verdict=="WAIT" && isCrash && deltaAvg < -0.4 && buyPct < 45) verdict = "SELL";
   g_ghost.verdict  = verdict;
   g_ghost.quality  = quality;
   g_ghost.delta    = deltaAvg;
   g_ghost.cvd      = cvd;
   g_ghost.buypct   = buyPct;
   g_ghost.sellpct  = sellPct;
   g_ghost.compass  = compass;
   g_ghost.valid    = true;
   g_ghost.loadedAt = (ulong)TimeCurrent();
}

//+------------------------------------------------------------------+
//| CONTRE-TENDANCE                                                  |
//+------------------------------------------------------------------+
bool IsStrongCounterTrend(const ESpikeType dir)
{
   if(!InpRequireTrendAlign) return false;
   int push = GetMicroTrendPush(InpTrendBars);
   if(dir == SPIKE_BUY  && push < 0) return true;
   if(dir == SPIKE_SELL && push > 0) return true;
   double ef[], es[];
   if(g_hEMAFast != INVALID_HANDLE && g_hEMASlow != INVALID_HANDLE &&
      CopyBuffer(g_hEMAFast,0,1,1,ef)>=1 && CopyBuffer(g_hEMASlow,0,1,1,es)>=1)
   {
      MqlRates c[];
      if(CopyRates(_Symbol,InpTF,1,1,c)>=1)
      {
         if(dir==SPIKE_BUY  && ef[0]<es[0] && c[0].close<es[0] && push<=0) return true;
         if(dir==SPIKE_SELL && ef[0]>es[0] && c[0].close>es[0] && push>=0) return true;
      }
   }
   return false;
}

void UpdateSMCContext()
{
   double px = IsBoom(_Symbol) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   SR_BuildSMCSetup(_Symbol, InpTF, IsBoom(_Symbol), px, InpSwingLookback, g_smc);
}

//+------------------------------------------------------------------+
//| CAPITAL MANAGER                                                  |
//+------------------------------------------------------------------+
void CheckCM()
{
   if(!InpUseCM) return;
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   datetime today = StructToTime(dt);
   if(today != g_cmDayTag)
   {
      g_cmDayTag      = today;
      g_cmDayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
      g_cmLocked      = false;
   }
   if(g_cmLocked) return;
   double bal = g_cmDayStartBal;
   double pnl = 0;
   datetime ds = StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
   HistorySelect(ds, TimeCurrent());
   for(int i=HistoryDealsTotal()-1; i>=0; i--)
   {
      ulong t=HistoryDealGetTicket(i); if(t==0) continue;
      if(HistoryDealGetInteger(t,DEAL_TYPE)==DEAL_TYPE_BALANCE) continue;
      if(HistoryDealGetInteger(t,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      pnl += HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_SWAP)
            +HistoryDealGetDouble(t,DEAL_COMMISSION);
   }
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      pnl += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   double target =  bal * InpCMDailyTargetPct / 100.0;
   double stop   = -bal * InpCMDailyStopPct   / 100.0;
   if(pnl >= target || pnl <= stop)
   {
      g_cmLocked = true;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
         g_trade.PositionClose(t,20);
      }
      PrintFormat("[v10] CM LOCKED | PnL=%.2f$ target=+%.2f$ stop=%.2f$",
                  pnl, target, stop);
   }
}

//+------------------------------------------------------------------+
//| MARKET REGIME                                                    |
//+------------------------------------------------------------------+
ERegime DetectRegime()
{
   if(!InpUseRegime) return REGIME_TRENDING;
   double atr=GetATR(), atrMean=GetATRMean();
   if(atr<=0.0 || atrMean<=0.0) return REGIME_TRENDING;
   double r = atr / atrMean;
   if(r >= 1.8) return REGIME_EXPLODING;
   if(r <= 0.75) return REGIME_RANGING;
   return REGIME_TRENDING;
}

double GetRegimeSL()
{
   switch(g_regime)
   {
      case REGIME_RANGING:   return 1.0;
      case REGIME_EXPLODING: return 2.2;
      default:               return InpSL_ATR;
   }
}

double GetRegimeTP()
{
   switch(g_regime)
   {
      case REGIME_RANGING:   return 1.8;
      case REGIME_EXPLODING: return 4.0;
      default:               return InpTP_ATR;
   }
}

//+------------------------------------------------------------------+
//| MULTI-TF ALIGNMENT (corrigé pour synthétiques)                  |
//+------------------------------------------------------------------+
int CalcMTFAlignment(bool forBuy)
{
   if(!InpUseMTF) return 3;
   ENUM_TIMEFRAMES tfs[3]; tfs[0]=InpMTF1; tfs[1]=InpMTF2; tfs[2]=InpMTF3;
   int aligned = 0;
   for(int t = 0; t < 3; t++)
   {
      if(tfs[t] <= PERIOD_M15)
      {
         int h = iMA(_Symbol, tfs[t], InpEMAMTF, 0, MODE_EMA, PRICE_CLOSE);
         if(h == INVALID_HANDLE) continue;
         double buf[]; ArraySetAsSeries(buf,true);
         bool ok = (CopyBuffer(h,0,1,1,buf)>=1);
         IndicatorRelease(h);
         if(!ok) continue;
         double c = iClose(_Symbol, tfs[t], 1);
         if(forBuy  && c > buf[0]) aligned++;
         if(!forBuy && c < buf[0]) aligned++;
      }
      else
      {
         double c1 = iClose(_Symbol, tfs[t], 1);
         double c5 = iClose(_Symbol, tfs[t], 5);
         if(c1 <= 0 || c5 <= 0) continue;
         if(forBuy  && c1 > c5) aligned++;
         if(!forBuy && c1 < c5) aligned++;
      }
   }
   return aligned;
}

//+------------------------------------------------------------------+
//| JSON HELPERS                                                     |
//+------------------------------------------------------------------+
double JsonExtractDouble(const string &body, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return -1.0;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body,pos)==' ') pos++;
   string sub = StringSubstr(body, pos, 24);
   int end = 0;
   while(end < StringLen(sub))
   {
      ushort c = StringGetCharacter(sub,end);
      if(c==',' || c=='}' || c==' ' || c=='\n' || c=='\r') break;
      end++;
   }
   return StringToDouble(StringSubstr(sub,0,end));
}

bool JsonExtractBool(const string &body, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return false;
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body,pos)==' ') pos++;
   ushort c = StringGetCharacter(body,pos);
   return (c == 't');
}

string JsonExtractString(const string &body, const string key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(body, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = StringFind(body, "\"", pos);
   if(end < 0) return "";
   return StringSubstr(body, pos, end - pos);
}

//+------------------------------------------------------------------+
//| HTTP HELPERS                                                     |
//+------------------------------------------------------------------+
bool HttpPost(const string url, const string jsonBody)
{
   char postData[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody));
   ArrayResize(postData, StringLen(jsonBody));
   int code = WebRequest("POST", url, headers, InpPriorTimeoutMs, postData, result, respH);
   return (code >= 200 && code < 300);
}

bool HttpGet(const string url, string &bodyOut)
{
   char postData[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("GET", url, headers, InpPriorTimeoutMs, postData, result, respH);
   if(code != 200) return false;
   bodyOut = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return true;
}

//+------------------------------------------------------------------+
//| TV CHART BIAS                                                    |
//+------------------------------------------------------------------+
bool FetchTVChartBias(const bool forceRefresh = false)
{
   if(!InpUseTVConfirm) return true;
   if(!forceRefresh && g_lastTVFetch != 0 &&
      TimeCurrent() - g_lastTVFetch < InpTVConfirmIntervalSec)
      return (g_tvDirection != "" && g_tvDirection != "UNKNOWN");
   if(g_lastTVAttempt != 0 && TimeCurrent() - g_lastTVAttempt < 15) return (g_lastTVFetch != 0);
   g_lastTVAttempt = TimeCurrent();
   string sym_enc = _Symbol; StringReplace(sym_enc," ","%20");
   string url = InpAIServerURL + "/mt5/tv-bias?symbol=" + sym_enc;
   if(forceRefresh) url += "&refresh=true";
   string body;
   if(!HttpGet(url, body)) return false;
   string dir = JsonExtractString(body,"direction");
   if(StringLen(dir)>0) g_tvDirection = dir;
   string m15 = JsonExtractString(body,"structure_m15");
   string h1  = JsonExtractString(body,"structure_h1");
   if(StringLen(m15)>0) g_tvStructureM15 = m15;
   if(StringLen(h1)>0)  g_tvStructureH1  = h1;
   g_tvBiasScore = JsonExtractDouble(body,"bias_score");
   g_lastTVFetch = TimeCurrent();
   return true;
}

bool TVChartConfirmsEntry(const ESpikeType dir, string &reason)
{
   if(!InpUseTVConfirm) return true;
   if(g_lastTVFetch == 0 || TimeCurrent() - g_lastTVFetch > InpTVConfirmMaxAgeSec)
   {
      if(!FetchTVChartBias(true)) { reason="TV indisponible — entrée autorisée"; return true; }
   }
   string tv = g_tvDirection; StringToUpper(tv);
   if(dir == SPIKE_BUY)
   {
      if(tv == "SELL")                { reason="TV oppose: SELL"; return false; }
      if(g_tvStructureM15=="bearish" || g_tvStructureH1=="bearish")
         { reason="TV bearish M15/H1"; return false; }
   }
   else
   {
      if(tv == "BUY")                { reason="TV oppose: BUY"; return false; }
      if(g_tvStructureM15=="bullish" || g_tvStructureH1=="bullish")
         { reason="TV bullish M15/H1"; return false; }
   }
   reason = "TV OK " + tv;
   return true;
}

//+------------------------------------------------------------------+
//| BRIDGE TRADINGVIEW — /spike-tv-state                            |
//+------------------------------------------------------------------+
bool PollSpikeTVState(const bool forceRefresh = false)
{
   if(!InpUseTVBridge) return true;
   if(!forceRefresh && g_lastSpikeTVFetch != 0 &&
      TimeCurrent() - g_lastSpikeTVFetch < InpTVBridgePollSec) return g_spikeTVOk;
   if(g_lastSpikeTVAttempt != 0 && TimeCurrent() - g_lastSpikeTVAttempt < 1) return g_spikeTVOk;
   g_lastSpikeTVAttempt = TimeCurrent();
   string sym_enc = _Symbol; StringReplace(sym_enc," ","%20");
   string url = InpAIServerURL + "/spike-tv-state?symbol=" + sym_enc;
   string body;
   if(!HttpGet(url, body)) { if(InpDebug) Print("[v10] /spike-tv-state indisponible"); return false; }
   g_spikeTVOk          = JsonExtractBool(body,"ok");
   string dir           = JsonExtractString(body,"direction");
   if(StringLen(dir)>0) g_tvDirection = dir; else g_tvDirection = "NEUTRAL";
   string m15 = JsonExtractString(body,"structure_m15");
   string h1  = JsonExtractString(body,"structure_h1");
   if(StringLen(m15)>0) g_tvStructureM15 = m15; else g_tvStructureM15 = "neutral";
   if(StringLen(h1)>0)  g_tvStructureH1  = h1;  else g_tvStructureH1  = "neutral";
   g_tvBiasScore        = JsonExtractDouble(body,"bias_score");
   g_tvImminencePct     = MathMax(0,MathMin(100,JsonExtractDouble(body,"imminence_pct")));
   g_tvSniperConfidence = MathMax(0,MathMin(100,JsonExtractDouble(body,"sniper_confidence")));
   g_tvSniperReady      = JsonExtractBool(body,"sniper_ready");
   g_tvCounterTrend     = JsonExtractBool(body,"counter_trend");
   g_tvSpikeDetected    = JsonExtractBool(body,"spike_detected");
   g_tvEntryValid       = JsonExtractBool(body,"entry_valid");
   string ob = JsonExtractString(body,"ob_bias");
   if(StringLen(ob)>0) g_tvObBias = ob; else g_tvObBias = "none";
   string emaTr = JsonExtractString(body,"ema_trend");
   if(StringLen(emaTr)>0) g_tvEmaTrend = emaTr; else g_tvEmaTrend = "neutral";
   string spDir = JsonExtractString(body,"spike_direction");
   if(StringLen(spDir)>0) g_tvSpikeDir = spDir; else g_tvSpikeDir = "NEUTRAL";
   double z = JsonExtractDouble(body,"spike_z"); if(z>=0) g_tvSpikeZ = z;
   string gDir = JsonExtractString(body,"tf_global_dir");
   if(StringLen(gDir)>0) { g_tvGlobalDir = gDir; StringToUpper(g_tvGlobalDir); } else g_tvGlobalDir = "NEUT";
   double gStr = JsonExtractDouble(body,"tf_global_strength"); if(gStr>0) g_tvGlobalStrength=(int)gStr;
   double coh  = JsonExtractDouble(body,"coherence_pct");      if(coh>0)  g_tvCoherencePct=coh;
   g_lastSpikeTVFetch = TimeCurrent();
   g_lastTVFetch      = TimeCurrent();

   // Log de diagnostic synchronisation TV
   if(InpDebug)
   {
      PrintFormat("[v10] TV sync | dir=%s | imm=%.0f%% | sniper=%s(%.0f%%) | CT=%s | age=%ds | ok=%s",
         g_tvDirection, g_tvImminencePct,
         (g_tvSniperReady?"READY":"---"), g_tvSniperConfidence,
         (g_tvCounterTrend?"TRUE":"false"),
         (int)(TimeCurrent()-g_lastSpikeTVFetch),
         (g_spikeTVOk?"true":"FALSE"));
   }

   return g_spikeTVOk;
}

//+------------------------------------------------------------------+
//| PRIOR HORAIRE                                                    |
//+------------------------------------------------------------------+
void FetchHourlyPrior()
{
   if(!InpUsePrior) return;
   MqlDateTime utc; TimeToStruct(TimeGMT(),utc);
   int hourNow = utc.hour;
   if(hourNow==g_lastPriorHour && g_lastPriorFetch!=0) return;
   if(g_lastPriorAttempt!=0 && TimeCurrent()-g_lastPriorAttempt<60) return;
   g_lastPriorAttempt = TimeCurrent();
   string url = InpAIServerURL + "/spike/hour-prior?symbol=" + _Symbol;
   string headers = "Content-Type: application/json\r\n";
   char post[],result[]; string respH;
   int code = WebRequest("GET",url,headers,InpPriorTimeoutMs,post,result,respH);
   if(code!=200) return;
   string body = CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
   double cr=JsonExtractDouble(body,"capture_rate");
   double am=JsonExtractDouble(body,"avg_atr_mult");
   double at=JsonExtractDouble(body,"atr_threshold");
   double sc=JsonExtractDouble(body,"sample_count");
   if(cr>0) g_priorCaptureRate=cr;
   if(am>0) g_priorAtrMult=am;
   if(at>0) g_priorAtrThreshold=at;
   if(sc>=0) g_priorSampleCount=(int)sc;
   g_priorFavorable = JsonExtractBool(body,"favorable");
   g_priorSource    = JsonExtractString(body,"source");
   g_lastPriorFetch = TimeCurrent();
   g_lastPriorHour  = hourNow;
}

void FetchZonePrior()
{
   if(!InpUseZonePrior) return;
   MqlDateTime utc; TimeToStruct(TimeGMT(),utc);
   int hourNow = utc.hour;
   if(hourNow==g_lastZoneHour && g_lastZoneFetch!=0) return;
   if(g_lastZoneAttempt!=0 && TimeCurrent()-g_lastZoneAttempt<60) return;
   g_lastZoneAttempt = TimeCurrent();
   string url = InpAIServerURL + "/mt5/spike-zone-prior?symbol="+_Symbol+"&timeframe=M1";
   string headers = "Content-Type: application/json\r\n";
   char post[],result[]; string respH;
   int code = WebRequest("GET",url,headers,InpPriorTimeoutMs,post,result,respH);
   if(code!=200) return;
   string body = CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
   double prior=JsonExtractDouble(body,"prior");
   double sr=JsonExtractDouble(body,"spike_rate");
   double ps=JsonExtractDouble(body,"propice_score");
   double samp=JsonExtractDouble(body,"samples");
   if(prior>=0) g_zonePrior=prior;
   if(sr>=0)    g_zoneSpikeRate=sr;
   if(ps>=0)    g_zonePropiceScore=ps;
   if(samp>=0)  g_zoneSamples=(int)samp;
   g_lastZoneFetch=TimeCurrent(); g_lastZoneHour=hourNow;
}

void FetchAngelOfSpike()
{
   if(!InpUseAngelOfSpike) return;
   MqlDateTime utc; TimeToStruct(TimeGMT(),utc);
   int hourNow=utc.hour;
   if(hourNow==g_lastAngelHour && g_lastAngelFetch!=0) return;
   if(g_lastAngelAttempt!=0 && TimeCurrent()-g_lastAngelAttempt<60) return;
   g_lastAngelAttempt=TimeCurrent();
   string sym_enc=_Symbol; StringReplace(sym_enc," ","%20");
   string url=InpAIServerURL+"/angelofspike/trend?symbol="+sym_enc+"&timeframe=M1";
   string headers="Content-Type: application/json\r\n";
   char post[],result[]; string respH;
   int code=WebRequest("GET",url,headers,InpPriorTimeoutMs,post,result,respH);
   if(code!=200) return;
   string body=CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
   string sig=JsonExtractString(body,"signal");
   double conf=JsonExtractDouble(body,"confidence");
   string mst=JsonExtractString(body,"market_state");
   if(StringLen(sig)>0) g_angelSignal=sig;
   if(conf>=0) g_angelConfidence=conf;
   if(StringLen(mst)>0) g_angelMarketState=mst;
   g_lastAngelFetch=TimeCurrent(); g_lastAngelHour=hourNow;
}

void FetchRealtimeSpike()
{
   if(!InpUseRealtimeCross) return;
   if(TimeCurrent()-g_lastRealtimeFetch<5) return;
   g_lastRealtimeFetch=TimeCurrent();
   string sym_enc=_Symbol; StringReplace(sym_enc," ","%20");
   string url=InpAIServerURL+"/spike/realtime?symbol="+sym_enc;
   string body;
   if(!HttpGet(url,body)) return;
   g_realtimeSpikeActive=JsonExtractBool(body,"spike");
   string dir=JsonExtractString(body,"direction");
   if(StringLen(dir)>0) g_realtimeSpikeDir=dir;
}

//+------------------------------------------------------------------+
//| UUID                                                             |
//+------------------------------------------------------------------+
string GenerateClientEventId()
{
   MathSrand((int)(TimeCurrent()*1000+MathRand()));
   return StringFormat("sr_%d_%04x%04x",(int)TimeCurrent(),MathRand(),MathRand());
}

void PostTradeFeedback(const TradeRecord &rec, double exitPrice, double profit)
{
   if(!InpSendFeedback) return;
   bool isWin=(profit>0.0);
   string side=(rec.spikeType==SPIKE_BUY)?"buy":"sell";
   string json=StringFormat(
      "{\"symbol\":\"%s\",\"timeframe\":\"M1\",\"side\":\"%s\","
      "\"profit\":%.4f,\"is_win\":%s,\"entry_price\":%.5f,\"exit_price\":%.5f,"
      "\"open_time\":%d,\"close_time\":%d,\"ai_confidence\":%.4f}",
      _Symbol,side,profit,(isWin?"true":"false"),
      rec.entryPrice,exitPrice,(int)rec.openTime,(int)TimeCurrent(),
      rec.imminenceAtEntry/100.0);
   HttpPost(InpAIServerURL+"/trades/feedback",json);
}

//+------------------------------------------------------------------+
//| GESTION POSITIONS                                                |
//+------------------------------------------------------------------+
void RegisterOpenTrade(ulong ticket, ESpikeType t, double entry,
                       datetime openTime, double imminence,
                       double zScore, double rsi, double stair)
{
   if(g_openTradesCount>=10) return;
   int idx=g_openTradesCount++;
   g_openTrades[idx].ticket           = ticket;
   g_openTrades[idx].spikeType        = t;
   g_openTrades[idx].entryPrice       = entry;
   g_openTrades[idx].openTime         = openTime;
   g_openTrades[idx].imminenceAtEntry = imminence;
   g_openTrades[idx].zScoreAtEntry    = zScore;
   g_openTrades[idx].rsiAtEntry       = rsi;
   g_openTrades[idx].stairAtEntry     = stair;
   g_openTrades[idx].zonePriorAtEntry = g_zonePrior;
   g_openTrades[idx].angelConfAtEntry = g_angelConfidence;
   g_openTrades[idx].stairEventId     = g_lastStairEventId;
   g_openTrades[idx].stairClientId    = g_lastStairClientId;
   g_lastEntryBarTime                 = iTime(_Symbol,InpTF,0);
}

int FindOpenTradeIdx(ulong ticket)
{
   for(int i=0;i<g_openTradesCount;i++) if(g_openTrades[i].ticket==ticket) return i;
   return -1;
}

void RemoveOpenTradeAt(int idx)
{
   if(idx<0||idx>=g_openTradesCount) return;
   for(int i=idx;i<g_openTradesCount-1;i++) g_openTrades[i]=g_openTrades[i+1];
   g_openTradesCount--;
}

//+------------------------------------------------------------------+
//| CALCUL LOT                                                       |
//+------------------------------------------------------------------+
int SR_VolumeDigits(const double step)
{
   if(step<=0.0) return 2;
   if(step>=1.0) return 0;
   return (int)MathMax(0,MathRound(-MathLog10(step)));
}

double CalcLot(double atr)
{
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0.0) step=minLot>0.0?minLot:0.01;
   double lot=minLot;
   if(InpFixedLot>0.0) lot=MathMax(minLot,MathMin(maxLot,InpFixedLot));
   lot=MathFloor(lot/step+0.5)*step;
   lot=MathMax(minLot,MathMin(maxLot,lot));
   return NormalizeDouble(lot,SR_VolumeDigits(step));
}

//+------------------------------------------------------------------+
//| NORMALISATION PRIX / STOPS                                       |
//+------------------------------------------------------------------+
double SR_NormalizeToTick(const double price, const bool roundUp)
{
   const int    dg  =(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0.0) return NormalizeDouble(price,dg);
   double n=price/tick;
   n=roundUp?MathCeil(n-1e-12):MathFloor(n+1e-12);
   return NormalizeDouble(n*tick,dg);
}

bool SR_AdjustStopsForOrder(const ENUM_ORDER_TYPE otype, const double openPrice,
                            double &sl, double &tp, const double minDistExtra=0.0)
{
   if(openPrice<=0.0) return false;
   const double pt   =SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const int stops   =(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const int freeze  =(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double minD=(double)MathMax(stops+freeze+5,10)*pt;
   if(minDistExtra>0.0) minD=MathMax(minD,minDistExtra);
   const bool isBuy=(otype==ORDER_TYPE_BUY||otype==ORDER_TYPE_BUY_STOP||otype==ORDER_TYPE_BUY_LIMIT);
   if(sl>0.0)
   {
      if(isBuy  && openPrice-sl<minD) sl=SR_NormalizeToTick(openPrice-minD,false);
      if(!isBuy && sl-openPrice<minD) sl=SR_NormalizeToTick(openPrice+minD,true);
   }
   if(tp>0.0)
   {
      if(isBuy  && tp-openPrice<minD) tp=SR_NormalizeToTick(openPrice+minD,true);
      if(!isBuy && openPrice-tp<minD) tp=SR_NormalizeToTick(openPrice-minD,false);
   }
   if(isBuy  && sl>0.0 && sl>=openPrice) return false;
   if(!isBuy && sl>0.0 && sl<=openPrice) return false;
   if(isBuy  && tp>0.0 && tp<=openPrice) return false;
   if(!isBuy && tp>0.0 && tp>=openPrice) return false;
   return true;
}

bool SR_OrderCheckMarket(const ENUM_ORDER_TYPE otype, const double lot,
                         const double sl, const double tp)
{
   MqlTradeRequest req; MqlTradeCheckResult chk;
   ZeroMemory(req); ZeroMemory(chk);
   req.action   =TRADE_ACTION_DEAL;
   req.symbol   =_Symbol;
   req.volume   =lot;
   req.type     =otype;
   req.price    =(otype==ORDER_TYPE_BUY)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.sl=sl; req.tp=tp; req.deviation=30; req.magic=InpMagic;
   return OrderCheck(req,chk);
}

bool SR_PrepareMarketStops(const ENUM_ORDER_TYPE otype, const double atr,
                           const double lot, double &sl, double &tp)
{
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double px=(otype==ORDER_TYPE_BUY)?ask:bid;
   if(px<=0.0||atr<=0.0) return false;
   const double minExtra=atr*0.35;
   if(otype==ORDER_TYPE_BUY)
   {
      sl=SR_NormalizeToTick(px-atr*InpSL_ATR,false);
      tp=SR_NormalizeToTick(px+atr*InpTP_ATR,true);
   }
   else
   {
      sl=SR_NormalizeToTick(px+atr*InpSL_ATR,true);
      tp=SR_NormalizeToTick(px-atr*InpTP_ATR,false);
   }
   if(!SR_AdjustStopsForOrder(otype,px,sl,tp,minExtra)) return false;
   return SR_OrderCheckMarket(otype,lot,sl,tp);
}

double SR_MinStopDistance()
{
   const double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(pt<=0.0) return 0.0;
   const int stops =(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const int freeze=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double minD=(double)MathMax(stops+freeze+5,10)*pt;
   double atr=GetATR();
   if(atr>0.0) minD=MathMax(minD,atr*0.5);
   return minD;
}

bool SR_ClampStopsForModify(const long posType, const double marketPx, double &sl, double &tp)
{
   const double minD=SR_MinStopDistance();
   const double pt  =SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(minD<=0.0||marketPx<=0.0) return true;
   if(posType==POSITION_TYPE_BUY)
   {
      if(sl>0.0){ double maxSl=marketPx-minD; if(sl>maxSl) sl=SR_NormalizeToTick(maxSl,false);
                  if(pt>0.0&&sl>=marketPx-pt*0.5) return false; }
      if(tp>0.0){ double minTp=marketPx+minD; if(tp<=marketPx) tp=0.0;
                  else if(tp<minTp) tp=SR_NormalizeToTick(minTp,true); }
   }
   else
   {
      if(sl>0.0){ double minSl=marketPx+minD; if(sl<minSl) sl=SR_NormalizeToTick(minSl,true);
                  if(pt>0.0&&sl<=marketPx+pt*0.5) return false; }
      if(tp>0.0){ double maxTp=marketPx-minD; if(tp>=marketPx) tp=0.0;
                  else if(tp>maxTp) tp=SR_NormalizeToTick(maxTp,false); }
   }
   return true;
}

bool SR_SafePositionModify(const ulong ticket, double sl, double tp)
{
   if(ticket==0||!PositionSelectByTicket(ticket)) return false;
   MqlTradeRequest req; MqlTradeCheckResult chk;
   ZeroMemory(req); ZeroMemory(chk);
   req.action=TRADE_ACTION_SLTP; req.position=ticket;
   req.symbol=PositionGetString(POSITION_SYMBOL); req.magic=InpMagic; req.sl=sl; req.tp=tp;
   if(OrderCheck(req,chk)) return g_trade.PositionModify(ticket,sl,tp);
   if(tp>0.0){ req.tp=0.0; if(OrderCheck(req,chk)) return g_trade.PositionModify(ticket,sl,0.0); }
   return false;
}

void SR_ScaleStopDistances(const ENUM_ORDER_TYPE otype, const double entry,
                           const double slOrig, const double tpOrig,
                           const double factor, double &sl, double &tp)
{
   const bool isBuy=(otype==ORDER_TYPE_BUY||otype==ORDER_TYPE_BUY_STOP||otype==ORDER_TYPE_BUY_LIMIT);
   sl=slOrig; tp=tpOrig;
   if(entry<=0.0||factor<=0.0) return;
   if(isBuy)
   {
      if(slOrig>0.0&&slOrig<entry) sl=SR_NormalizeToTick(entry-(entry-slOrig)*factor,false);
      if(tpOrig>0.0&&tpOrig>entry) tp=SR_NormalizeToTick(entry+(tpOrig-entry)*factor,true);
   }
   else
   {
      if(slOrig>0.0&&slOrig>entry) sl=SR_NormalizeToTick(entry+(slOrig-entry)*factor,true);
      if(tpOrig>0.0&&tpOrig<entry) tp=SR_NormalizeToTick(entry-(entry-tpOrig)*factor,false);
   }
}

//+------------------------------------------------------------------+
//| SCORE STAIR                                                      |
//+------------------------------------------------------------------+
double CalcStairScore(bool isBoom)
{
   if(InpStairBars<=0) return 1.0;
   MqlRates r[];
   int need=InpStairBars+2;
   if(CopyRates(_Symbol,InpTF,1,need,r)<need) return 0.5;
   int aligned=0;
   for(int i=0;i<InpStairBars;i++)
   {
      double body=r[i].close-r[i].open;
      if(isBoom  && body>0) aligned++;
      if(!isBoom && body<0) aligned++;
   }
   return (double)aligned/InpStairBars;
}

//+------------------------------------------------------------------+
//| SCORE D'IMMINENCE                                                |
//+------------------------------------------------------------------+
double CalcImminenceScore(double atr, double rsi, double stair)
{
   bool isBoom   =IsBoom(_Symbol);
   bool hasPrior =(InpUsePrior && g_lastPriorFetch!=0);
   bool hasZone  =(InpUseZonePrior && g_lastZoneFetch!=0 && g_zoneSamples>=3);
   double score  =0.0;

   // 1. Compteur inter-spike : 30%
   int spikeFreq=GetEffectiveSpikeFrequency();
   if(spikeFreq>0)
   {
      double ratio=(double)g_barsSinceLastSpike/(double)spikeFreq;
      double cntScore=(ratio>=0.25)?MathMin((ratio-0.25)/0.75,1.0):0.0;
      score+=cntScore*30.0;
   }

   // 2. Compression ATR : 20%
   double atrMean=GetATRMean();
   if(atr>0&&atrMean>0)
   {
      double compRatio=atr/atrMean;
      if(compRatio<=InpAtrCompressRatio)
      {
         double compScore=MathMin((InpAtrCompressRatio-compRatio)/InpAtrCompressRatio,1.0);
         score+=compScore*20.0;
      }
   }

   // 3. Stair : 15%
   score+=stair*15.0;

   // 4. RSI : 10%
   if(isBoom)  { if(rsi<=35) score+=10.0; else if(rsi<45) score+=(45-rsi)/10.0*10.0; }
   else        { if(rsi>=65) score+=10.0; else if(rsi>55)  score+=(rsi-55)/10.0*10.0; }

   // 5. Prior RDS : 10%
   if(hasPrior&&g_priorSampleCount>=5)
   {
      double cr=g_priorCaptureRate;
      double ps=(cr>=0.70)?1.0:(cr>=0.30?(cr-0.30)/0.40:0.0);
      score+=ps*10.0;
   }

   // 6. Zone prior : 8%
   if(hasZone) score+=g_zonePrior*8.0;

   // 7. GHOST : 7%
   if(g_ghost.valid&&g_ghost.quality>=50)
   {
      bool aligned=(isBoom&&g_ghost.verdict=="BUY")||(!isBoom&&g_ghost.verdict=="SELL");
      bool opposed=(isBoom&&g_ghost.verdict=="SELL")||(!isBoom&&g_ghost.verdict=="BUY");
      if(aligned) score+=(g_ghost.quality/100.0)*7.0;
      if(opposed) score-=(g_ghost.quality/100.0)*7.0;
   }

   // 8. Zone RDS (limité à 20 spikes pour perf) : 10%
   if(g_spikeCount>0&&atr>0&&
      ArraySize(g_spikeTs)>=g_spikeCount&&ArraySize(g_spikeDirs)>=g_spikeCount)
   {
      double px=isBoom?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double radius=atr*1.5;
      int hits=0,hitsCap=0;
      for(int k=0;k<MathMin(g_spikeCount,20);k++)
      {
         MqlRates sr[];
         if(CopyRates(_Symbol,InpTF,g_spikeTs[k],1,sr)<1) continue;
         double spikePx=(g_spikeDirs[k]=="BUY")?sr[0].low:sr[0].high;
         if(spikePx<=0) continue;
         if(MathAbs(px-spikePx)<=radius){ hits++; if(g_spikeCaptured[k]) hitsCap++; }
      }
      if(hits>0)
      {
         double zoneBonus=MathMin((double)hitsCap/MathMax(hits,1),1.0)*10.0;
         zoneBonus=MathMax(zoneBonus,hits>1?4.0:1.5);
         score+=zoneBonus;
      }
   }

   return MathMax(0.0,MathMin(score,100.0));
}

//+------------------------------------------------------------------+
//| PENDING                                                          |
//+------------------------------------------------------------------+
bool HasPendingOrder()
{
   if(g_pendingTicket==0) return false;
   if(OrderSelect(g_pendingTicket)) return true;
   g_pendingTicket=0; return false;
}

void CancelPendingOrder(const string reason)
{
   if(g_pendingTicket==0) return;
   if(OrderSelect(g_pendingTicket)) g_trade.OrderDelete(g_pendingTicket);
   g_pendingTicket=0; g_pendingPlacedAt=0;
}

void ManagePendingAge()
{
   if(g_pendingTicket==0||InpPendingMaxAgeSec<=0) return;
   if((int)(TimeCurrent()-g_pendingPlacedAt)>=InpPendingMaxAgeSec) CancelPendingOrder("expiré");
}

//+------------------------------------------------------------------+
//| DETECTION SPIKE                                                  |
//+------------------------------------------------------------------+
SpikeResult DetectSpike()
{
   SpikeResult res;
   res.type=SPIKE_NONE; res.zScore=0.0; res.rsi=GetRSI(); res.atr=GetATR(); res.stairScore=0.0;
   int need=InpLookback+2;
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,InpTF,0,need,rates)<need) return res;
   double moves[];
   ArrayResize(moves,InpLookback);
   double sum=0.0;
   for(int i=0;i<InpLookback;i++)
   {
      moves[i]=MathAbs(rates[i+1].close-rates[i+2].close);
      sum+=moves[i];
   }
   double mean=sum/InpLookback;
   if(mean<=0.0) return res;
   double var=0.0;
   for(int i=0;i<InpLookback;i++) var+=MathPow(moves[i]-mean,2);
   double sd=MathSqrt(var/InpLookback);
   if(sd<=0.0) sd=mean*0.1;
   double moveClosed=MathAbs(rates[1].close-rates[1].open);
   double moveLive  =MathAbs(rates[0].close-rates[0].open);
   double curMove   =MathMax(moveClosed,moveLive);
   bool   useLive   =(moveLive>moveClosed);
   double z=(curMove-mean)/sd;
   res.zScore=z;
   bool isSpike=(z>=InpZScoreMin)||(curMove>=mean*InpMinMoveMult);
   if(!isSpike) return res;
   bool up=useLive?(rates[0].close>rates[0].open):(rates[1].close>rates[1].open);
   bool isBoom=IsBoom(_Symbol); bool isCrash=IsCrash(_Symbol);
   if(isBoom&&!up) return res;
   if(isCrash&&up) return res;
   if(InpRequireRSI)
   {
      if(isBoom&&res.rsi>InpRSIBoomMax)  return res;
      if(isCrash&&res.rsi<InpRSICrashMin) return res;
   }
   double stair=CalcStairScore(isBoom);
   res.stairScore=stair;
   if(InpStairMinPct>0.0&&stair<InpStairMinPct) return res;
   res.type=up?SPIKE_BUY:SPIKE_SELL;
   return res;
}

//+------------------------------------------------------------------+
//| POSITIONS                                                        |
//+------------------------------------------------------------------+
int CountOurPositions()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==(long)InpMagic&&
         PositionGetString(POSITION_SYMBOL)==_Symbol) count++;
   }
   return count;
}

bool HasPosition()         { return CountOurPositions()>0; }
bool MaxPositionsReached() { return CountOurPositions()>=1; }

ulong GetOpenTicket()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==(long)InpMagic&&
         PositionGetString(POSITION_SYMBOL)==_Symbol) return t;
   }
   return 0;
}

bool SpreadOK()
{
   long spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   return (InpMaxSpreadPoints<=0||spread<=InpMaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| LIMITE JOURNALIÈRE                                               |
//+------------------------------------------------------------------+
void ResetDayIfNeeded()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   datetime today=StructToTime(dt);
   if(today!=g_dayTag){ g_dayTag=today; g_dayStartBalance=AccountInfoDouble(ACCOUNT_BALANCE); }
}

bool DailyLimitHit()
{
   if(InpUseCM&&g_cmLocked) return true;
   if(InpMaxDailyLossPct<=0.0) return false;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double loss=g_dayStartBalance-bal;
   return (loss>=g_dayStartBalance*InpMaxDailyLossPct/100.0);
}

//+------------------------------------------------------------------+
//| CAN ENTER IN DIRECTION (corrigé — 7 conditions claires)         |
//+------------------------------------------------------------------+
bool CanEnterInDirection(const ESpikeType dir, const bool isPreSpike,
                         const SpikeResult &spike, string &reason)
{
   reason="";

   // 1. Règles absolues
   if(InpUseCM&&g_cmLocked)
      { reason="CM: journée verrouillée"; return false; }
   if(IsBoom(_Symbol)&&dir!=SPIKE_BUY)
      { reason="Boom → BUY uniquement"; return false; }
   if(IsCrash(_Symbol)&&dir!=SPIKE_SELL)
      { reason="Crash → SELL uniquement"; return false; }
   if(isPreSpike&&!InpPreSpikeEnabled)
      { reason="pré-spike désactivé"; return false; }

   // 2. Régime
   g_regime=DetectRegime();

   // 3. MTF souple (min 1/3 sur synthétiques)
   if(InpUseMTF)
   {
      int al=CalcMTFAlignment(dir==SPIKE_BUY);
      g_mtfAligned=al;
      if(al<1){ reason="MTF: 0/3 TF alignes - tous contre-tendance"; return false; }
   }

   // 4. GHOST veto (uniquement si signal fort et opposé)
   if(g_ghost.valid&&g_ghost.quality>=65)
   {
      bool ghostOpposes=(dir==SPIKE_BUY&&g_ghost.verdict=="SELL")||
                        (dir==SPIKE_SELL&&g_ghost.verdict=="BUY");
      if(ghostOpposes)
         { reason=StringFormat("GHOST veto: %s delta=%.2f q=%.0f",
                               g_ghost.verdict,g_ghost.delta,g_ghost.quality);
           return false; }
   }

   // 5. TV Bridge (données fraîches < 5s pour Boom/Crash M1)
   bool tvFresh=(g_lastSpikeTVFetch>0&&TimeCurrent()-g_lastSpikeTVFetch<5);
   if(InpUseTVBridge&&InpBlockCounterTrendTV&&tvFresh&&g_tvCounterTrend)
      { reason=StringFormat("GOM: contre-tendance EMA=%s OB=%s",g_tvEmaTrend,g_tvObBias);
        return false; }

   // 6. SMC (si activé)
   if(InpRequireSMC)
   {
      UpdateSMCContext();
      bool zStrong=spike.zScore>=InpOTEBypassZScore;
      bool requireOTE=InpRequireOTE&&!zStrong;
      string smcReason;
      if(!SR_SMCAllowsEntry(g_smc,IsBoom(_Symbol),InpRequireBOS,InpRequireCHOCH,
                            requireOTE,!isPreSpike,spike.zScore,InpZScoreMin,smcReason))
         { reason=smcReason; return false; }
   }

   // 7. Tendance opposée (bypass si spike Z fort >= 2.5)
   if(InpRequireTrendAlign&&IsStrongCounterTrend(dir))
   {
      if(spike.zScore<2.5)
         { reason=StringFormat("Tendance opposée (Z=%.2f)",spike.zScore); return false; }
   }

   reason=StringFormat("✓ %s | Z=%.2f | stair=%.0f%% | GHOST=%s(q=%.0f) | TV=%s | Regime=%s",
          (dir==SPIKE_BUY?"BUY":"SELL"),spike.zScore,spike.stairScore*100.0,
          g_ghost.verdict,g_ghost.quality,
          (tvFresh?(g_tvCounterTrend?"CT!":"ok"):"old"),
          (g_regime==REGIME_EXPLODING?"EXP":g_regime==REGIME_RANGING?"RNG":"TRN"));
   return true;
}

//+------------------------------------------------------------------+
//| ENTRÉE MARCHÉ                                                    |
//+------------------------------------------------------------------+
bool EnterSpikeTrade(const SpikeResult &spike, double imminence, const bool isPreSpike=false)
{
   string blockReason;
   if(!CanEnterInDirection(spike.type,isPreSpike,spike,blockReason))
   {
      if(InpDebug) PrintFormat("[v10] Bloqué: %s",blockReason);
      return false;
   }
   double atr=spike.atr; if(atr<=0.0) return false;
   double lot=CalcLot(atr);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   ENUM_ORDER_TYPE otype=(spike.type==SPIKE_BUY)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double price=(spike.type==SPIKE_BUY)?ask:bid;
   double slMult=GetRegimeSL(), tpMult=GetRegimeTP();
   double sl,tp;
   if(spike.type==SPIKE_BUY)
   {
      sl=SR_NormalizeToTick(price-atr*slMult,false);
      tp=SR_NormalizeToTick(price+atr*tpMult,true);
   }
   else
   {
      sl=SR_NormalizeToTick(price+atr*slMult,true);
      tp=SR_NormalizeToTick(price-atr*tpMult,false);
   }
   double slUse=sl, tpUse=tp;
   const double minExtra=atr*0.35;
   bool stopsReady=false;
   for(int pass=0;pass<3&&!stopsReady;pass++)
   {
      price=(spike.type==SPIKE_BUY)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(pass==0){ slUse=sl; tpUse=tp; }
      else SR_ScaleStopDistances(otype,price,sl,tp,(pass==1?0.85:0.70),slUse,tpUse);
      if(!SR_AdjustStopsForOrder(otype,price,slUse,tpUse,minExtra)) continue;
      if(!SR_OrderCheckMarket(otype,lot,slUse,tpUse)) continue;
      stopsReady=true;
   }
   if(!stopsReady)
   {
      if(!SR_PrepareMarketStops(otype,atr,lot,slUse,tpUse))
         { g_lastEntryFail=TimeCurrent(); return false; }
   }
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(30);
   string cmt=StringFormat("v10|%s|Z=%.2f|G=%s",(spike.type==SPIKE_BUY?"BUY":"SELL"),spike.zScore,g_ghost.verdict);
   bool ok=(spike.type==SPIKE_BUY)
           ?g_trade.Buy(lot,_Symbol,0,slUse,tpUse,cmt)
           :g_trade.Sell(lot,_Symbol,0,slUse,tpUse,cmt);
   if(ok)
   {
      g_lastTrade=TimeCurrent();
      g_barsSinceLastSpike=0;
      g_lastSpikeBar=iTime(_Symbol,InpTF,0);
      ulong ticket=g_trade.ResultOrder();
      RegisterOpenTrade(ticket,spike.type,price,TimeCurrent(),imminence,spike.zScore,spike.rsi,spike.stairScore);
      PrintFormat("[v10] ✅ %s lot=%.2f SL=%.5f TP=%.5f Z=%.2f imm=%.0f%%",
                  (spike.type==SPIKE_BUY?"BUY":"SELL"),lot,slUse,tpUse,spike.zScore,imminence);
   }
   else
   {
      g_lastEntryFail=TimeCurrent();
      PrintFormat("[v10] ❌ %s | %d - %s",(spike.type==SPIKE_BUY?"BUY":"SELL"),
                  g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
   }
   return ok;
}

//+------------------------------------------------------------------+
//| NOTIFICATION PRÉ-SPIKE                                          |
//+------------------------------------------------------------------+
void CheckAndNotifyPreSpike(double imminence)
{
   bool alert70=(imminence>=70.0&&g_lastNotifImm<70.0);
   bool alert50=(imminence>=50.0&&g_lastNotifImm<50.0);
   if(!alert70&&!alert50) return;
   if(TimeCurrent()-g_lastNotifTime<30) return;
   bool   boom=IsBoom(_Symbol);
   int    freq=GetEffectiveSpikeFrequency();
   double prog=(freq>0)?MathMin((double)g_barsSinceLastSpike/freq*100.0,100.0):0.0;
   string lvl=(imminence>=70.0)?"🔥 IMMINENT":"⚡ ALERTE";
   string dir=boom?"BUY (hausse)":"SELL (baisse)";
   string msg=StringFormat("%s %s | %s | Imm=%.0f%% Barres=%d/%d (%.0f%%)",
                           lvl,_Symbol,dir,imminence,g_barsSinceLastSpike,freq,prog);
   Alert(msg); SendNotification(msg);
   g_lastNotifTime=TimeCurrent(); g_lastNotifImm=imminence;
}

void ResetNotifState() { g_lastNotifImm=0.0; }

//+------------------------------------------------------------------+
//| SORTIE RAPIDE                                                    |
//+------------------------------------------------------------------+
void ManageQuickExit(const bool spikeActive=false)
{
   if(!InpUseQuickExit) return;
   double minProfit=InpQuickExitMinProfitUSD;
   if(StringFind(_Symbol,"600")>=0) minProfit=MathMax(minProfit,InpQuickExitMinProfitBoom600);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      double profit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      datetime openTime=(datetime)PositionGetInteger(POSITION_TIME);
      int holdSec=(int)(TimeCurrent()-openTime);
      datetime barNow=iTime(_Symbol,InpTF,0);
      bool sameSpikeBar=(!InpExitOnSameSpikeBar&&g_lastEntryBarTime>0&&barNow<=g_lastEntryBarTime);
      if(spikeActive&&!sameSpikeBar&&profit>0.0)
      {
         g_trade.PositionClose(ticket,10); ResetNotifState();
         PrintFormat("[v10] ⚡ Sortie spike profit=$%.2f hold=%ds",profit,holdSec);
         continue;
      }
      if(holdSec<InpMinHoldSec) continue;
      if(profit>=minProfit)
      {
         g_trade.PositionClose(ticket,10); ResetNotifState();
         PrintFormat("[v10] ✅ Sortie objectif profit=$%.2f hold=%ds",profit,holdSec);
      }
   }
}

void CloseAllBoomCrashOnSpike()
{
   if(!InpUseQuickExit) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||!PositionSelectByTicket(ticket)) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      if(!IsBoom(sym)&&!IsCrash(sym)) continue;
      double profit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(profit<=0.0) continue;
      if(g_trade.PositionClose(ticket,10))
         PrintFormat("[v10] ⚡ CloseAll SPIKE %s profit=$%.2f",sym,profit);
   }
   ResetNotifState();
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                    |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   if(!InpUseTrailing) return;

   static datetime s_lastTrailFailTime = 0;
   const int TRAIL_FAIL_COOLDOWN_SEC = 5;
   if(TimeCurrent() - s_lastTrailFailTime < TRAIL_FAIL_COOLDOWN_SEC) return;

   ulong ticket=GetOpenTicket(); if(ticket==0) return;
   if(!PositionSelectByTicket(ticket)) return;
   double atr=GetATR(); if(atr<=0.0) return;
   double openPrice=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double currentTP=PositionGetDouble(POSITION_TP);
   long posType=PositionGetInteger(POSITION_TYPE);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const double minD=SR_MinStopDistance();
   const double activation=atr*InpTrailActivation;
   const double trailDist =MathMax(atr*InpTrailStep,minD);
   if(posType==POSITION_TYPE_BUY)
   {
      if(bid-openPrice<activation) return;
      double newSL=SR_NormalizeToTick(bid-trailDist,false);
      if(currentSL>0.0&&newSL<=currentSL+pt) return;
      double tpUse=currentTP;
       if(!SR_ClampStopsForModify(POSITION_TYPE_BUY,bid,newSL,tpUse)) return;
       if(!SR_SafePositionModify(ticket,newSL,tpUse))
       {
          s_lastTrailFailTime = TimeCurrent();
       }
    }
    else if(posType==POSITION_TYPE_SELL)
    {
       if(openPrice-ask<activation) return;
       double newSL=SR_NormalizeToTick(ask+trailDist,true);
       if(currentSL>0.0&&newSL>=currentSL-pt) return;
       double tpUse=currentTP;
       if(!SR_ClampStopsForModify(POSITION_TYPE_SELL,ask,newSL,tpUse)) return;
       if(!SR_SafePositionModify(ticket,newSL,tpUse))
       {
          s_lastTrailFailTime = TimeCurrent();
       }
    }
}

//+------------------------------------------------------------------+
//| OBJETS GRAPHIQUES                                                |
//+------------------------------------------------------------------+
string ObjName(string suffix) { return "SR_"+_Symbol+"_"+suffix; }
void ObjDel(string suffix)    { ObjectDelete(0,ObjName(suffix)); }

void ObjHLine(string suffix,double price,color clr,ENUM_LINE_STYLE style,int width=1)
{
   string n=ObjName(suffix);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,n,OBJPROP_PRICE,price);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,n,OBJPROP_BACK,true);
}

void ObjArrow(string suffix,datetime t,double price,int arrowCode,color clr,int anchor)
{
   string n=ObjName(suffix);
   ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_ARROW,0,t,price);
   ObjectSetInteger(0,n,OBJPROP_ARROWCODE,arrowCode);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,3);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,anchor);
}

void ObjRect(string suffix,datetime t1,double p1,datetime t2,double p2,color clr,bool fill=true)
{
   string n=ObjName(suffix);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,p1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_TIME,0,t1);
   ObjectSetDouble(0,n,OBJPROP_PRICE,0,p1);
   ObjectSetInteger(0,n,OBJPROP_TIME,1,t2);
   ObjectSetDouble(0,n,OBJPROP_PRICE,1,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FILL,fill);
   ObjectSetInteger(0,n,OBJPROP_BACK,true);
}

void ObjLabel(string suffix,string txt,int x,int y,color clr,int fontSize=9)
{
   int xRight=MathMax(4,InpDashPanelWidth-x);
   string n=ObjName(suffix);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,xRight);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
}

void ObjLabel2(string suffix,string txt,int x,int y,color clr,int fontSize=8)
{
   string n=ObjName(suffix);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
}

void ClearAllSRObjects()
{
   ObjectDelete(0,ObjName("D2_Title"));
   ObjectDelete(0,ObjName("D2_Empty"));
   for(int si=0;si<20;si++) ObjectDelete(0,ObjName("D2_Sym"+IntegerToString(si)));
   int total=ObjectsTotal(0);
   string prefix="SR_"+_Symbol+"_";
   for(int i=total-1;i>=0;i--)
   {
      string nm=ObjectName(0,i);
      if(StringFind(nm,prefix)==0) ObjectDelete(0,nm);
   }
}

//+------------------------------------------------------------------+
//| S/R MULTI-TF                                                     |
//+------------------------------------------------------------------+
void CalcSRLevels()
{
   if(g_lastSRFetch!=0&&TimeCurrent()-g_lastSRFetch<3600) return;
   g_lastSRFetch=TimeCurrent();
   int total=ObjectsTotal(0);
   string prefix="SR_"+_Symbol+"_SR_";
   for(int i=total-1;i>=0;i--)
      if(StringFind(ObjectName(0,i),prefix)==0) ObjectDelete(0,ObjectName(0,i));
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   struct TFConfig{ ENUM_TIMEFRAMES tf; string name; color clrR; color clrS; color clrP; };
   TFConfig tfs[3];
   tfs[0].tf=PERIOD_H1;  tfs[0].name="H1"; tfs[0].clrR=C'255,100,100'; tfs[0].clrS=C'100,200,100'; tfs[0].clrP=C'180,180,255';
   tfs[1].tf=PERIOD_H4;  tfs[1].name="H4"; tfs[1].clrR=C'220,60,60';   tfs[1].clrS=C'60,180,60';   tfs[1].clrP=C'140,140,220';
   tfs[2].tf=PERIOD_D1;  tfs[2].name="D1"; tfs[2].clrR=C'180,30,30';   tfs[2].clrS=C'30,150,30';   tfs[2].clrP=C'100,100,190';
   for(int t=0;t<3;t++)
   {
      MqlRates r[]; ArraySetAsSeries(r,true);
      if(CopyRates(_Symbol,tfs[t].tf,1,2,r)<2) continue;
      double H=r[1].high,L=r[1].low,C=r[1].close;
      double PP=(H+L+C)/3.0;
      double R1=2*PP-L, R2=PP+(H-L), S1=2*PP-H, S2=PP-(H-L);
      int w=(t==0)?1:(t==1?2:3);
      ObjHLine("SR_"+tfs[t].name+"_PP",NormalizeDouble(PP,digits),tfs[t].clrP,STYLE_DASHDOT,w);
      ObjectSetString(0,ObjName("SR_"+tfs[t].name+"_PP"),OBJPROP_TEXT,tfs[t].name+" Pivot");
      ObjHLine("SR_"+tfs[t].name+"_R1",NormalizeDouble(R1,digits),tfs[t].clrR,STYLE_DOT,w);
      ObjHLine("SR_"+tfs[t].name+"_S1",NormalizeDouble(S1,digits),tfs[t].clrS,STYLE_DOT,w);
      if(t>=1)
      {
         ObjHLine("SR_"+tfs[t].name+"_R2",NormalizeDouble(R2,digits),tfs[t].clrR,STYLE_DOT,w);
         ObjHLine("SR_"+tfs[t].name+"_S2",NormalizeDouble(S2,digits),tfs[t].clrS,STYLE_DOT,w);
      }
   }
}

//+------------------------------------------------------------------+
//| SPIKES HISTORIQUES RDS                                          |
//+------------------------------------------------------------------+
void FetchSpikeLevels()
{
   if(!InpUsePrior) return;
   if(g_lastSpikeLevelFetch!=0&&TimeCurrent()-g_lastSpikeLevelFetch<3600) return;
   string url=InpAIServerURL+"/spike/levels?symbol="+_Symbol+"&limit=50";
   string headers="Content-Type: application/json\r\n";
   char post[],result[]; string respH;
   int code=WebRequest("GET",url,headers,InpPriorTimeoutMs*3,post,result,respH);
   if(code!=200) return;
   string body=CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
   g_spikeCount=0;
   ArrayResize(g_spikeTs,50); ArrayResize(g_spikeDirs,50); ArrayResize(g_spikeCaptured,50);
   int pos=StringFind(body,"\"spikes\":[");
   if(pos<0) return;
   pos+=10;
   while(g_spikeCount<50)
   {
      int objStart=StringFind(body,"{",pos);
      int objEnd  =StringFind(body,"}",objStart);
      if(objStart<0||objEnd<0) break;
      string obj=StringSubstr(body,objStart,objEnd-objStart+1);
      string ts=JsonExtractString(obj,"ts");
      string dir=JsonExtractString(obj,"direction");
      bool   cap=JsonExtractBool(obj,"captured");
      if(StringLen(ts)>=19)
      {
         string dtPart=StringSubstr(ts,0,19); StringReplace(dtPart,"T"," ");
         datetime dt=StringToTime(dtPart);
         if(dt>0){ g_spikeTs[g_spikeCount]=dt; g_spikeDirs[g_spikeCount]=dir;
                   g_spikeCaptured[g_spikeCount]=cap; g_spikeCount++; }
      }
      pos=objEnd+1;
      if(StringGetCharacter(body,pos)==']') break;
   }
   g_lastSpikeLevelFetch=TimeCurrent();
}

void DrawSpikeHistoryMarkers()
{
   if(g_spikeCount<=0) return;
   int total=ObjectsTotal(0);
   string prefix="SR_"+_Symbol+"_SPK_";
   for(int i=total-1;i>=0;i--)
      if(StringFind(ObjectName(0,i),prefix)==0) ObjectDelete(0,ObjectName(0,i));
   for(int i=0;i<g_spikeCount;i++)
   {
      datetime ts=g_spikeTs[i]; string dir=g_spikeDirs[i]; bool cap=g_spikeCaptured[i];
      MqlRates r[]; if(CopyRates(_Symbol,InpTF,ts,1,r)<1) continue;
      double px=(dir=="BUY")?r[0].low:r[0].high;
      color clr=cap?C'0,200,100':C'200,60,60';
      int code=(dir=="BUY")?233:234;
      int anchor=(dir=="BUY")?ANCHOR_TOP:ANCHOR_BOTTOM;
      string suf="SPK_"+IntegerToString(i);
      ObjArrow(suf,ts,px,code,clr,anchor);
      ObjectSetInteger(0,ObjName(suf),OBJPROP_WIDTH,1);
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+
void DrawChartIndicators(const SpikeResult &spike, double imminence)
{
   if(!InpShowDashboard) return;
   bool   isBoom =IsBoom(_Symbol);
   double atr    =spike.atr;
   double atrMean=GetATRMean();
   double ask    =SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid    =SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double price  =isBoom?ask:bid;
   int    digits =(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   CalcSRLevels();
   FetchSpikeLevels();
   DrawSpikeHistoryMarkers();

   UpdateSMCContext();
   if(InpDrawSMCLevels&&g_smc.valid)
   {
      ObjHLine("FIB618",NormalizeDouble(g_smc.fib618,digits),clrOrange,STYLE_SOLID,2);
      ObjHLine("FIB786",NormalizeDouble(g_smc.fib786,digits),clrOrangeRed,STYLE_SOLID,2);
      ObjHLine("OTEL",NormalizeDouble(g_smc.oteLow,digits),clrDodgerBlue,STYLE_DOT,1);
      ObjHLine("OTEH",NormalizeDouble(g_smc.oteHigh,digits),clrDodgerBlue,STYLE_DOT,1);
      if(g_smc.breakLevel>0.0)
         ObjHLine("BOS",NormalizeDouble(g_smc.breakLevel,digits),g_smc.bos?clrLime:clrGray,STYLE_SOLID,2);
      ObjRect("OTEZONE",iTime(_Symbol,InpTF,8),g_smc.oteLow,
              iTime(_Symbol,InpTF,0)+PeriodSeconds(InpTF)*3,g_smc.oteHigh,C'30,60,120',true);
   }
   else { ObjDel("FIB618"); ObjDel("FIB786"); ObjDel("OTEL"); ObjDel("OTEH"); ObjDel("BOS"); ObjDel("OTEZONE"); }

   if(InpUseChartStops&&atr>0)
   {
      double slDist=atr*InpSL_ATR, tpDist=atr*InpTP_ATR;
      if(isBoom){ ObjHLine("SL",NormalizeDouble(price-slDist,digits),clrTomato,STYLE_DOT,2);
                  ObjHLine("TP",NormalizeDouble(price+tpDist,digits),clrLimeGreen,STYLE_DOT,2); }
      else      { ObjHLine("SL",NormalizeDouble(price+slDist,digits),clrTomato,STYLE_DOT,2);
                  ObjHLine("TP",NormalizeDouble(price-tpDist,digits),clrLimeGreen,STYLE_DOT,2); }
   }

   bool compressed=(atr>0&&atrMean>0&&atr<atrMean*InpAtrCompressRatio);
   if(compressed)
   {
      MqlRates r[]; ArraySetAsSeries(r,true);
      int nb=MathMin(InpLookback,20);
      if(CopyRates(_Symbol,InpTF,0,nb+1,r)>=nb)
      {
         datetime t1=r[nb].time, t2=r[0].time+PeriodSeconds(InpTF);
         double lo=r[0].low,hi=r[0].high;
         for(int i=1;i<nb;i++){ lo=MathMin(lo,r[i].low); hi=MathMax(hi,r[i].high); }
         ObjRect("CompressZone",t1,lo,t2,hi,C'40,40,60',true);
      }
   }
   else ObjDel("CompressZone");

   // Flèche anticipation spike (3 modes: ANTICIPATION/IMMINENT/ACTION)
   {
      MqlRates r[]; ArraySetAsSeries(r,true);
      bool hasBars=(CopyRates(_Symbol,InpTF,0,3,r)>=3);
      bool hasPos=HasPosition();
      bool spikeDetected=(spike.type!=SPIKE_NONE);

      // Mode d'affichage
      enum ARROW_MODE { MODE_NONE, MODE_ANTICIPATION, MODE_IMMINENT, MODE_ACTION };
      ARROW_MODE mode=MODE_NONE;

      if(spikeDetected || hasPos)
         mode=MODE_ACTION;        // Spike en cours
      else if(imminence>=85.0)
         mode=MODE_IMMINENT;      // Imminent (1-2 barres)
      else if(imminence>=40.0)
         mode=MODE_ANTICIPATION;  // Anticipation (1-5 barres)

      bool shouldBlink=(hasBars && mode!=MODE_NONE);

      if(shouldBlink && atr>0)
      {
         datetime arrowTime;
         double arrowPx;
         int arrowWidth;
         color c1, c2;

         int code=isBoom?233:234;
         int anchor=isBoom?ANCHOR_TOP:ANCHOR_BOTTOM;

         switch(mode)
         {
            case MODE_ANTICIPATION:
               arrowTime = r[0].time + PeriodSeconds(InpTF);
               arrowPx   = isBoom ? (r[0].low - atr*0.3) : (r[0].high + atr*0.3);
               arrowWidth= 2;
               c1 = isBoom ? clrDeepSkyBlue : clrOrange;
               c2 = isBoom ? clrDodgerBlue  : clrGold;
               break;

            case MODE_IMMINENT:
               arrowTime = r[0].time + PeriodSeconds(InpTF);
               arrowPx   = isBoom ? (r[0].low - atr*0.5) : (r[0].high + atr*0.5);
               arrowWidth= 4;
               c1 = isBoom ? clrAqua : clrOrangeRed;
               c2 = isBoom ? C'255,255,100' : clrRed;
               break;

            case MODE_ACTION:
               arrowTime = r[0].time;
               arrowPx   = isBoom ? (r[0].low - atr*0.6) : (r[0].high + atr*0.6);
               arrowWidth= 5;
               c1 = isBoom ? clrYellow : clrRed;
               c2 = isBoom ? clrAqua   : clrOrangeRed;
               break;

            default:
               shouldBlink=false;
               break;
         }

         if(shouldBlink)
         {
            color blinkClr=((TimeCurrent()%2)==0)?c1:c2;
            ObjArrow("SpikeArrow",arrowTime,arrowPx,code,blinkClr,anchor);
            ObjectSetInteger(0,ObjName("SpikeArrow"),OBJPROP_WIDTH,arrowWidth);

            string tooltip="";
            switch(mode)
            {
               case MODE_ANTICIPATION:
                  tooltip=StringFormat("Spike anticipé (%.0f%% imminence) - Préparez-vous!",imminence);
                  break;
               case MODE_IMMINENT:
                  tooltip=StringFormat("SPIKE IMMINENT (%.0f%%) - Dernières barres avant déclenchement!",imminence);
                  break;
               case MODE_ACTION:
                  tooltip=spikeDetected ? "SPIKE EN COURS - Trade actif!" : "Position ouverte";
                  break;
            }
            ObjectSetString(0,ObjName("SpikeArrow"),OBJPROP_TOOLTIP,tooltip);
         }
      }
      else
      {
         ObjDel("SpikeArrow");
      }
   }

   if(atrMean>0&&price>0)
   {
      ObjHLine("ATRHi",NormalizeDouble(price+atrMean,digits),C'70,70,110',STYLE_DASHDOT,1);
      ObjHLine("ATRLo",NormalizeDouble(price-atrMean,digits),C'70,70,110',STYLE_DASHDOT,1);
   }

   // ── PANEL DASHBOARD ────────────────────────────────────────────
   ObjDel("D_Prior"); ObjDel("D_TVBridge"); ObjDel("D_TVStruct");
   int yBase=20, yStep=16;
   ObjLabel("D_Title","-- DerivEAPro v10.01 -- "+_Symbol+" --",8,yBase,clrGold,10);
   yBase+=yStep+4;
   string regTxt=(g_regime==REGIME_EXPLODING?"EXPLODING":g_regime==REGIME_RANGING?"RANGING":"TRENDING");
   color  regClr=(g_regime==REGIME_EXPLODING?clrOrangeRed:g_regime==REGIME_RANGING?clrGold:clrLimeGreen);
   ObjLabel("D_Regime",StringFormat("Regime=%s SL=%.1f×ATR TP=%.1f×ATR | MTF=%d/3 | CM:%s",
            regTxt,GetRegimeSL(),GetRegimeTP(),g_mtfAligned,
            InpUseCM?(g_cmLocked?"LOCKED":"OK"):"OFF"),8,yBase,regClr,9);
   yBase+=yStep;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE),eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double dayLoss=(g_dayStartBalance>0)?(g_dayStartBalance-bal)/g_dayStartBalance*100.0:0.0;
   color  balClr=(dayLoss>3.0)?clrTomato:clrSilver;
   ObjLabel("D_Acct",StringFormat("Bal $%.2f | Eq $%.2f | Pos:%d | DayLoss:%.1f%%",
            bal,eq,CountOurPositions(),dayLoss),8,yBase,balClr,9);
   yBase+=yStep;
   ObjLabel("D_Detect",StringFormat("Z=%.2f  RSI=%.0f  ATR=%.1f  Stair=%.0f%%  Compress:%s",
            spike.zScore,spike.rsi,atr,spike.stairScore*100,compressed?"OUI":"non"),
            8,yBase,(MathAbs(spike.zScore)>=InpZScoreMin?clrYellow:clrDimGray),9);
   yBase+=yStep;
   color gaugeClr;
   if(imminence>=85) gaugeClr=clrOrangeRed;
   else if(imminence>=70) gaugeClr=clrOrange;
   else if(imminence>=40) gaugeClr=clrGold;
   else gaugeClr=clrDodgerBlue;
   string bar=""; int filled=(int)(imminence/10.0);
   for(int i=0;i<10;i++) bar+=(i<filled?"|":".");
   ObjLabel("D_Gauge",StringFormat("Imminence [%s] %.0f%%",bar,imminence),8,yBase,gaugeClr,10);
   yBase+=yStep;
   int effFreq=GetEffectiveSpikeFrequency();
   double progress=(effFreq>0)?MathMin((double)g_barsSinceLastSpike/(double)effFreq*100.0,100.0):0.0;
   ObjLabel("D_Counter",StringFormat("Barres: %d/%d (%.0f%%) | Spread: %d",
            g_barsSinceLastSpike,effFreq,progress,(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)),
            8,yBase,(progress>=80)?clrYellow:clrDimGray,9);
   yBase+=yStep;
   // GHOST
   color ghostClr=(g_ghost.verdict=="BUY"?clrLimeGreen:g_ghost.verdict=="SELL"?clrTomato:clrDimGray);
   ObjLabel("D_Ghost",StringFormat("GHOST: %s | delta=%.2f | buyPct=%.0f%% | q=%.0f | CVD=%.2f",
            g_ghost.verdict,g_ghost.delta,g_ghost.buypct,g_ghost.quality,g_ghost.cvd),
            8,yBase,ghostClr,9);
   yBase+=yStep;

   // GOM TV (si disponible)
   if(g_gomTV.valid)
   {
      int ageGOM = (int)(TimeCurrent() - g_gomTV.loadedAt);
      color gomClr;
      if(ageGOM <= 5)       gomClr = clrLimeGreen;
      else if(ageGOM <= 15) gomClr = clrOrange;
      else                  gomClr = clrTomato;

      ObjLabel("D_GOM_TV",
         StringFormat("GOM TV: %s (%ds) | imbalance=%.2f | liquidity=%.2f | smart_money=%.2f",
            (ageGOM<=15?"FRESH":"STALE"), ageGOM,
            g_gomTV.imbalance, g_gomTV.liquidity_score, g_gomTV.smart_money_idx),
         8, yBase, gomClr, 9);
      yBase += yStep;

      // Afficher Multi-TF si disponible
      if(StringLen(g_gomTV.tf_global_dir) > 0)
      {
         string mtfLine = "MTF: ";

         // M1
         if(StringLen(g_gomTV.tf_m1_dir) > 0)
         {
            string arrow = (g_gomTV.tf_m1_dir == "BULL") ? "^" :
                           (g_gomTV.tf_m1_dir == "BEAR") ? "v" : "-";
            mtfLine += "M1" + arrow + " ";
         }

         // M5
         if(StringLen(g_gomTV.tf_m5_dir) > 0)
         {
            string arrow = (g_gomTV.tf_m5_dir == "BULL") ? "^" :
                           (g_gomTV.tf_m5_dir == "BEAR") ? "v" : "-";
            mtfLine += "M5" + arrow + " ";
         }

         // M15
         if(StringLen(g_gomTV.tf_m15_dir) > 0)
         {
            string arrow = (g_gomTV.tf_m15_dir == "BULL") ? "^" :
                           (g_gomTV.tf_m15_dir == "BEAR") ? "v" : "-";
            mtfLine += "M15" + arrow + " ";
         }

         // M30
         if(StringLen(g_gomTV.tf_m30_dir) > 0)
         {
            string arrow = (g_gomTV.tf_m30_dir == "BULL") ? "^" :
                           (g_gomTV.tf_m30_dir == "BEAR") ? "v" : "-";
            mtfLine += "M30" + arrow + " ";
         }

         // H1
         if(StringLen(g_gomTV.tf_h1_dir) > 0)
         {
            string arrow = (g_gomTV.tf_h1_dir == "BULL") ? "^" :
                           (g_gomTV.tf_h1_dir == "BEAR") ? "v" : "-";
            mtfLine += "H1" + arrow + " ";
         }

         // H4
         if(StringLen(g_gomTV.tf_h4_dir) > 0)
         {
            string arrow = (g_gomTV.tf_h4_dir == "BULL") ? "^" :
                           (g_gomTV.tf_h4_dir == "BEAR") ? "v" : "-";
            mtfLine += "H4" + arrow + " ";
         }

         // D1
         if(StringLen(g_gomTV.tf_d1_dir) > 0)
         {
            string arrow = (g_gomTV.tf_d1_dir == "BULL") ? "^" :
                           (g_gomTV.tf_d1_dir == "BEAR") ? "v" : "-";
            mtfLine += "D1" + arrow + " ";
         }

         // Global
         mtfLine += StringFormat("| Global: %s (%d/7)",
                                 g_gomTV.tf_global_dir,
                                 g_gomTV.tf_global_strength);

         // Couleur selon global
         color mtfColor = clrGray;
         if(g_gomTV.tf_global_dir == "BULL")
            mtfColor = clrLimeGreen;
         else if(g_gomTV.tf_global_dir == "BEAR")
            mtfColor = clrTomato;
         else
            mtfColor = clrOrange;

         ObjLabel("D_MTF_Detail", mtfLine, 8, yBase, mtfColor, 9);
         yBase += yStep;
      }

      if(g_gomTV.setup_entry > 0)
      {
         string setupLabel = g_gomTV.setup_is_fallback ? "Setup AUTO" : "Setup TV";
         color setupClr = g_gomTV.setup_is_fallback ? clrOrange : clrGold;
         string warning = (g_gomTV.setup_is_fallback && g_gomTV.quality < 50) ? " ⚠️" : "";

         ObjLabel("D_GOM_Setup",
            StringFormat("%s %s%s: Entry=%.2f SL=%.2f TP1=%.2f TP2=%.2f R:R=%.2f",
               setupLabel, g_gomTV.setup_dir, warning,
               g_gomTV.setup_entry, g_gomTV.setup_sl,
               g_gomTV.setup_tp1, g_gomTV.setup_tp2, g_gomTV.setup_rr),
            8, yBase, setupClr, 9);
         yBase += yStep;
      }
   }

   if(InpUsePrior&&g_lastPriorFetch!=0)
   {
      ObjLabel("D_Prior",StringFormat("Prior %02d:00 Cap=%.0f%% ATR=%.2f N=%d %s",
               g_lastPriorHour,g_priorCaptureRate*100,g_priorAtrMult,g_priorSampleCount,
               g_priorFavorable?"FAV":"DEF"),8,yBase,g_priorFavorable?clrLimeGreen:clrTomato,9);
      yBase+=yStep;
   }
   if(InpUseTVBridge)
   {
      color tvClr=g_tvSniperReady?clrLimeGreen:(g_tvCounterTrend?clrTomato:clrGold);
      int ageTv=(g_lastSpikeTVFetch>0)?(int)(TimeCurrent()-g_lastSpikeTVFetch):-1;
      ObjLabel("D_TVBridge",StringFormat("TV %s | Sniper %s %.0f%% | imm=%.0f%% | OB=%s EMA=%s | %ds",
               g_tvDirection,(g_tvSniperReady?"READY":"---"),g_tvSniperConfidence,
               g_tvImminencePct,g_tvObBias,g_tvEmaTrend,ageTv),8,yBase,tvClr,9);
      yBase+=yStep;
      ObjLabel("D_TVStruct",StringFormat("M15=%s H1=%s | spike=%s | CT=%s",
               g_tvStructureM15,g_tvStructureH1,
               (g_tvSpikeDetected?g_tvSpikeDir:"non"),
               (g_tvCounterTrend?"BLOQUE":"ok")),8,yBase,tvClr,8);
      yBase+=yStep;

      // Indicateur de fraîcheur TV (critique <5s, warning 5-10s, stale >10s)
      int ageTV = (int)(TimeCurrent() - g_lastSpikeTVFetch);
      color ageClr;
      string ageStatus;
      if(ageTV <= 5)       { ageClr = clrLimeGreen; ageStatus = "FRESH"; }
      else if(ageTV <= 10) { ageClr = clrOrange;    ageStatus = "WARNING"; }
      else                 { ageClr = clrTomato;     ageStatus = "STALE"; }

      ObjLabel("D_TVSync",
         StringFormat("TV Sync: %s (%ds) | GOM dir=%s strength=%d | coherence=%.0f%%",
            ageStatus, ageTV,
            g_tvGlobalDir, g_tvGlobalStrength, g_tvCoherencePct),
         8, yBase, ageClr, 9);
      yBase += yStep;
   }
   if(atr>0)
   {
      ObjLabel("D_SLTP",StringFormat("SL=%.0f pts | TP=%.0f pts | RR=%.1f",
               atr*InpSL_ATR/SymbolInfoDouble(_Symbol,SYMBOL_POINT),
               atr*InpTP_ATR/SymbolInfoDouble(_Symbol,SYMBOL_POINT),InpTP_ATR/InpSL_ATR),
               8,yBase,clrSilver,9);
      yBase+=yStep;
   }
   ObjLabel("D_HistLeg",StringFormat("Hist RDS: %d spikes | vert=capturé rouge=manqué",g_spikeCount),
            8,yBase,C'140,140,140',8);
   yBase+=yStep;
   ObjLabel("D_SRLeg","S/R: H1 H4 D1 | PP=tiret R=rouge S=vert",8,yBase,C'120,120,120',8);
   yBase+=yStep;

   // Panel 2 multi-symbole
   ObjDel("D2_Title"); ObjDel("D2_Empty");
   for(int si=0;si<20;si++) ObjDel("D2_Sym"+IntegerToString(si));
   int nLines=(g_symCount>0)?g_symCount:1;
   int y2Step=14, y2Bottom=8;
   ObjLabel2("D2_Title","--- Multi-Symboles Actifs ---",8,y2Bottom+(nLines+1)*y2Step,C'160,160,200',8);
   if(g_symCount==0)
      ObjLabel2("D2_Empty","Aucun symbole Boom/Crash dans Market Watch",8,y2Bottom+y2Step,clrDimGray,8);
   else
   {
      for(int si=0;si<g_symCount;si++)
      {
         string nm=g_syms[si].sym; bool boom=g_syms[si].isBoom;
         int bars=g_syms[si].barsSince; int freq=600;
         const string nums[]={"1000","900","600","500","300"};
         for(int ni=0;ni<5;ni++) if(StringFind(nm,nums[ni])>=0){freq=(int)StringToInteger(nums[ni]);break;}
         double pct=(freq>0)?MathMin((double)bars/(double)freq*100.0,100.0):0.0;
         color sClr=(pct>=80)?clrYellow:(pct>=50?clrGold:clrDimGray);
         ObjLabel2("D2_Sym"+IntegerToString(si),
                   StringFormat("%-22s %s %3d/%d (%.0f%%)",nm,boom?"BUY":"SELL",bars,freq,pct),
                   8,y2Bottom+(si+1)*y2Step,sClr,8);
      }
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| SCAN MARKET WATCH                                                |
//+------------------------------------------------------------------+
void ScanMarketWatchSymbols()
{
   g_symCount=0;
   int total=SymbolsTotal(true);
   for(int i=0;i<total&&g_symCount<20;i++)
   {
      string s=SymbolName(i,true);
      if(!IsSupportedSymbol(s)) continue;
      bool dup=false;
      for(int k=0;k<g_symCount;k++) if(g_syms[k].sym==s){dup=true;break;}
      if(dup) continue;
      g_syms[g_symCount].sym       =s;
      g_syms[g_symCount].isBoom    =IsBoom(s);
      g_syms[g_symCount].barsSince =0;
      g_syms[g_symCount].lastBar   =0;
      g_syms[g_symCount].lastTrade =0;
      g_syms[g_symCount].lastEntryFail=0;
      g_syms[g_symCount].lastEntryBarTime=0;
      g_syms[g_symCount].hATR      =iATR(s,InpTF,InpATRPeriod);
      g_syms[g_symCount].hRSI      =iRSI(s,InpTF,InpRSIPeriod,PRICE_CLOSE);
      g_syms[g_symCount].hEMAFast  =iMA(s,InpTF,InpEMAFast,0,MODE_EMA,PRICE_CLOSE);
      g_syms[g_symCount].hEMASlow  =iMA(s,InpTF,InpEMASlow,0,MODE_EMA,PRICE_CLOSE);
      g_symCount++;
   }
   PrintFormat("[v10] %d symboles Boom/Crash détectés",g_symCount);
}

//+------------------------------------------------------------------+
//| ONTRADE TRANSACTION                                              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &,
                        const MqlTradeResult &)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=(long)InpMagic) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol) return;
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry!=DEAL_ENTRY_OUT&&entry!=DEAL_ENTRY_INOUT) return;
   ulong posTicket=HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   int idx=FindOpenTradeIdx(posTicket);
   double profit=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)
                +HistoryDealGetDouble(trans.deal,DEAL_SWAP)
                +HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
   double exitPrice=HistoryDealGetDouble(trans.deal,DEAL_PRICE);
   if(idx<0) return;
   TradeRecord rec=g_openTrades[idx];
   RemoveOpenTradeAt(idx);
   g_barsSinceLastSpike=0; g_lastSpikeBar=TimeCurrent(); ResetNotifState();
   for(int si=0;si<g_symCount;si++) if(g_syms[si].sym==_Symbol) g_syms[si].barsSince=0;
   PostTradeFeedback(rec,exitPrice,profit);
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!IsSupportedSymbol(_Symbol))
      Print("[v10] ⚠️ Symbole non supporté: ",_Symbol);

   g_hATR    =iATR(_Symbol,InpTF,InpATRPeriod);
   g_hRSI    =iRSI(_Symbol,InpTF,InpRSIPeriod,PRICE_CLOSE);
   g_hEMAFast=iMA(_Symbol,InpTF,InpEMAFast,0,MODE_EMA,PRICE_CLOSE);
   g_hEMASlow=iMA(_Symbol,InpTF,InpEMASlow,0,MODE_EMA,PRICE_CLOSE);
   if(g_hATR==INVALID_HANDLE||g_hRSI==INVALID_HANDLE||
      g_hEMAFast==INVALID_HANDLE||g_hEMASlow==INVALID_HANDLE)
      { Print("[v10] ❌ Erreur création indicateurs"); return INIT_FAILED; }

   ZeroMemory(g_ghost); g_ghost.verdict="WAIT";
   ZeroMemory(g_smc);   g_smc.tag="init";

   ScanMarketWatchSymbols();
   g_trade.SetExpertMagicNumber(InpMagic);
   g_dayStartBalance   =AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayTag            =0;
   g_barsSinceLastSpike=0;
   g_cmDayStartBal     =AccountInfoDouble(ACCOUNT_BALANCE);
   g_cmDayTag=0; g_cmLocked=false;
   g_regime=DetectRegime(); g_mtfAligned=3;
   g_lastSpikeBar=0; g_pendingTicket=0; g_openTradesCount=0;
   g_lastPriorFetch=0; g_lastPriorAttempt=0; g_lastPriorHour=-1;
   g_lastZoneFetch=0;  g_lastZoneAttempt=0;  g_lastZoneHour=-1;
   g_lastAngelFetch=0; g_lastAngelAttempt=0; g_lastAngelHour=-1;
   g_lastRealtimeFetch=0;
   g_lastStairEventId=""; g_lastStairClientId="";
   g_lastSRFetch=0; g_lastSpikeLevelFetch=0; g_spikeCount=0;
   ArrayResize(g_spikeTs,0); ArrayResize(g_spikeDirs,0); ArrayResize(g_spikeCaptured,0);

   FetchHourlyPrior(); FetchZonePrior(); FetchAngelOfSpike(); FetchSpikeLevels();
   UpdateSMCContext();
   if(InpUseTVBridge) { PollSpikeTVState(true); EventSetTimer(MathMax(1,InpTVBridgePollSec)); }
   else if(InpUseTVConfirm) FetchTVChartBias(true);

   // Charger GOM TV initial
   LoadGOMFromTV();
   if(g_gomTV.valid)
      PrintFormat("[v10] ✅ GOM TV init: %s | verdict=%s | quality=%.0f%% | imbalance=%.2f",
         g_gomTV.symbol, g_gomTV.verdict, g_gomTV.quality, g_gomTV.imbalance);
   else
      Print("[v10] ⚠️  GOM TV non disponible au démarrage (GOM poller lancé?)");

   PrintFormat("[DerivEAPro v10.03] ✅ Init | %s | SMC=%s | GOM=%s | CM=%s | MTF=%s | Magic=%llu",
               _Symbol,(InpRequireSMC?"ON":"OFF"),(InpUseTVBridge?"ON":"OFF"),
               (InpUseCM?StringFormat("%.0f%%/%.0f%%",InpCMDailyTargetPct,InpCMDailyStopPct):"OFF"),
               (InpUseMTF?"ON":"OFF"),InpMagic);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_hATR    !=INVALID_HANDLE){ IndicatorRelease(g_hATR);     g_hATR=INVALID_HANDLE; }
   if(g_hRSI    !=INVALID_HANDLE){ IndicatorRelease(g_hRSI);     g_hRSI=INVALID_HANDLE; }
   if(g_hEMAFast!=INVALID_HANDLE){ IndicatorRelease(g_hEMAFast); g_hEMAFast=INVALID_HANDLE; }
   if(g_hEMASlow!=INVALID_HANDLE){ IndicatorRelease(g_hEMASlow); g_hEMASlow=INVALID_HANDLE; }
   if(g_hEMA9   !=INVALID_HANDLE){ IndicatorRelease(g_hEMA9);    g_hEMA9=INVALID_HANDLE; }
   if(g_hEMA21  !=INVALID_HANDLE){ IndicatorRelease(g_hEMA21);   g_hEMA21=INVALID_HANDLE; }
   if(g_hATR_G  !=INVALID_HANDLE){ IndicatorRelease(g_hATR_G);   g_hATR_G=INVALID_HANDLE; }
   for(int si=0;si<g_symCount;si++)
   {
      if(g_syms[si].hATR    !=INVALID_HANDLE) IndicatorRelease(g_syms[si].hATR);
      if(g_syms[si].hRSI    !=INVALID_HANDLE) IndicatorRelease(g_syms[si].hRSI);
      if(g_syms[si].hEMAFast!=INVALID_HANDLE) IndicatorRelease(g_syms[si].hEMAFast);
      if(g_syms[si].hEMASlow!=INVALID_HANDLE) IndicatorRelease(g_syms[si].hEMASlow);
   }
   g_symCount=0;
   CancelPendingOrder("deinit");
   ClearAllSRObjects();
   Comment("");
   Print("[v10] Arrêté sur ",_Symbol);
}

//+------------------------------------------------------------------+
//| TIMER                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpUseTVBridge) PollSpikeTVState(false);
}

//+------------------------------------------------------------------+
//| ONTICK                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsSupportedSymbol(_Symbol)) return;

   if(InpUseTVBridge&&g_lastSpikeTVFetch==0) PollSpikeTVState(true);

   ResetDayIfNeeded();
   CheckCM();
   PollGHOST();

   SpikeResult spikeLive=DetectSpike();
   bool spikeNow=(spikeLive.type!=SPIKE_NONE);
   if(spikeNow) CloseAllBoomCrashOnSpike();
   ManageQuickExit(spikeNow);
   ManageTrailing();
   ManagePendingAge();

   MqlDateTime utc; TimeToStruct(TimeGMT(),utc);
   if(InpUsePrior        &&utc.hour!=g_lastPriorHour) FetchHourlyPrior();
   if(InpUseZonePrior    &&utc.hour!=g_lastZoneHour)  FetchZonePrior();
   if(InpUseAngelOfSpike &&utc.hour!=g_lastAngelHour) FetchAngelOfSpike();
   FetchRealtimeSpike();

   datetime barTime=iTime(_Symbol,InpTF,0);
   bool newBar=(barTime!=g_lastBar);
   if(newBar){ g_lastBar=barTime; g_barsSinceLastSpike++; }

   SpikeResult spike=spikeLive;
   double stairNow=CalcStairScore(IsBoom(_Symbol));
   double imminence=CalcImminenceScore(spike.atr,spike.rsi,stairNow);

   if(!HasPosition()) CheckAndNotifyPreSpike(imminence);
   else ResetNotifState();

   for(int si=0;si<g_symCount;si++)
   {
      datetime bTime=iTime(g_syms[si].sym,InpTF,0);
      if(bTime!=0&&bTime!=g_syms[si].lastBar){ g_syms[si].lastBar=bTime; g_syms[si].barsSince++; }
   }

   DrawChartIndicators(spike,imminence);

   if(DailyLimitHit()) return;
   if(!SpreadOK())     return;

   bool canTryEntry=(!MaxPositionsReached()&&
                     TimeCurrent()-g_lastTrade    >=InpCooldownSec&&
                     TimeCurrent()-g_lastEntryFail>=InpCooldownSec);
   bool entryDone=false;

   // ── Entrée A : spike Z (priorité absolue) ──────────────────────
   if(canTryEntry&&spike.type!=SPIKE_NONE)
   {
      // Synchronisation forcée TV avant entrée (fraîcheur garantie <1s)
      if(InpUseTVBridge && TimeCurrent()-g_lastSpikeTVFetch>1)
      {
         if(InpDebug) Print("[v10] 🔄 Refresh TV FORCÉ avant entrée spike");
         PollSpikeTVState(true);  // forceRefresh=true
      }

      CancelPendingOrder("setup spike");
      string why;
      if(CanEnterInDirection(spike.type,false,spike,why))
      {
         PrintFormat("[v10] 🚀 SPIKE %s | Z=%.2f | GHOST=%s | imm=%.0f%%",
                     (spike.type==SPIKE_BUY?"BUY":"SELL"),spike.zScore,g_ghost.verdict,imminence);
         entryDone=EnterSpikeTrade(spike,imminence,false);
      }
      else if(InpDebug) PrintFormat("[v10] Spike Z=%.2f bloqué: %s",spike.zScore,why);
   }

   // ── Entrée B : pré-spike/imminence ──────────────────────────────
   if(canTryEntry&&!entryDone&&InpPreSpikeEnabled&&
      imminence>=InpImminenceThresh&&!HasPendingOrder())
   {
      // Synchronisation forcée TV avant pré-spike
      if(InpUseTVBridge && TimeCurrent()-g_lastSpikeTVFetch>1)
      {
         if(InpDebug) Print("[v10] 🔄 Refresh TV FORCÉ avant pré-spike");
         PollSpikeTVState(true);
      }

      SpikeResult pre;
      pre.type      =IsBoom(_Symbol)?SPIKE_BUY:SPIKE_SELL;
      pre.zScore    =spike.zScore; pre.rsi=spike.rsi;
      pre.atr       =spike.atr;   pre.stairScore=stairNow;
      string whyPre;
      if(CanEnterInDirection(pre.type,true,pre,whyPre))
      {
         PrintFormat("[v10] ⚡ PRE-SPIKE %s | imm=%.0f%% | %s",
                     (pre.type==SPIKE_BUY?"BUY":"SELL"),imminence,whyPre);
         entryDone=EnterSpikeTrade(pre,imminence,true);
      }
      else if(InpDebug) PrintFormat("[v10] Pre-spike bloqué: %s",whyPre);
   }

   // ── Entrée C : stair-only ────────────────────────────────────────
   if(canTryEntry&&!entryDone&&InpEnableStairOnlyEntry&&
      spike.type==SPIKE_NONE&&stairNow>=InpStairOnlyMinPct&&
      imminence>=InpImminenceThresh)
   {
      SpikeResult st;
      st.type      =IsBoom(_Symbol)?SPIKE_BUY:SPIKE_SELL;
      st.zScore    =spike.zScore; st.rsi=spike.rsi;
      st.atr       =spike.atr;   st.stairScore=stairNow;
      string whySt;
      if(CanEnterInDirection(st.type,true,st,whySt))
      {
         PrintFormat("[v10] 🪜 STAIR %s | stair=%.0f%% imm=%.0f%%",
                     (st.type==SPIKE_BUY?"BUY":"SELL"),stairNow*100,imminence);
         entryDone=EnterSpikeTrade(st,imminence,true);
      }
      else if(InpDebug) PrintFormat("[v10] Stair bloqué: %s",whySt);
   }
}
//+------------------------------------------------------------------+