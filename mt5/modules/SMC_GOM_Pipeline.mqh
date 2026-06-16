//+------------------------------------------------------------------+
//| SMC_GOM_Pipeline.mqh — GOM verdict + pipeline + dessins TV sync  |
//| Pattern TradeManager.mq5 (KOLA, OB setup, OTE zone)            |
//+------------------------------------------------------------------+
#ifndef SMC_GOM_PIPELINE_MQH
#define SMC_GOM_PIPELINE_MQH

#include "MT5_Candles_Uploader.mqh"

// inputs du .mq5 parent — visibles globalement, pas besoin de extern en MQL5

// Déclaré / implémenté dans SMC_Universal.mq5
bool DisciplineAllowsPipelineAction(const string action);
bool SMCGP_GOMValidatesPrimarySignal(const int dir);
bool SMC_BCHourAllowsTrade(const string symbol = "");
bool SMC_HighProbabilityAllowsEntry(const int dirSign = 0);
extern double g_lastEntryProbability;
extern string g_lastAIAction;
extern double g_lastAIConfidence;

bool SMCGP_IsBoomCrashSym(const string sym)
{
   string s = sym;
   StringToUpper(s);
   return (StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0);
}

MT5CandlesUploader *g_smcCandlesUploader = NULL;
datetime g_smcLastCandleUpload = 0;
// ── État GOM ───────────────────────────────────────────────────────
string   g_smcGomVerdict      = "WAIT";
int      g_smcGomVerdictNum   = 0;
int      g_smcGomVerdictNumPrev = 999;  // 999 = pas encore armé
bool     g_smcGomForceExhausted = false; // PERFECT→GOOD : fin cycle spike Boom/Crash
string   g_smcGomVerdictPrev  = "";
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
string   g_smcCorrPhase       = "unknown"; // trending|correcting|exhausted|resuming
bool     g_smcCorrEntrySafe   = false; // true = correction terminée, re-entrée safe
datetime g_smcLastGOMPoll     = 0;
datetime g_smcLastMCPPoll      = 0;
datetime g_smcLastPipelineExec= 0;
string   g_smcLastPipelineId  = "";
datetime g_smcLastPipelineFail= 0;
string   g_smcFailedPipelineId= "";
int      g_smcPipelineFailCount = 0;
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

// Prédictions Bollinger Bands (300 bougies)
double   g_smcPredBbMid[]     = {};
double   g_smcPredBbUp[]      = {};
double   g_smcPredBbDn[]      = {};

// Cognition forecast 200 bougies (ai_server)
double   g_cogStrength        = 0.0;
double   g_cogConfidence      = 0.0;
string   g_cogDirection       = "NEUTRAL";
int      g_pipelineEma9Handle = INVALID_HANDLE;  // EMA9 M1 pour re-entrées scalp pipeline
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
   string url = AI_ServerURL + path;
   char post[], result[];
   StringToCharArray(jsonBody, post, 0, WHOLE_ARRAY, CP_UTF8);
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("POST", url, headers, timeoutMs, post, result, respH);
   g_smcLastHttpCode = code;
   return (code == 200 || code == 201);
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

bool SMCGP_HttpGet(const string path, string &bodyOut, int timeoutMs = 5000)
{
   bodyOut = "";
   g_smcServerUrl = AI_ServerURL + path;
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("GET", g_smcServerUrl, headers, timeoutMs, post, result, respH);
   g_smcLastHttpCode = code;
   if(code != 200)
   {
      if(code == -1)
      {
         static datetime s_lastHttpHint = 0;
         if(TimeCurrent() - s_lastHttpHint >= 60)
         {
            s_lastHttpHint = TimeCurrent();
            int err = GetLastError();
            Print("[GOM-HTTP] WebRequest echoue (code -1, err=", err, ") url=", g_smcServerUrl);
            Print("[GOM-HTTP] MT5 > Outils > Options > Expert Advisors > autoriser WebRequest pour: ",
                  AI_ServerURL);
            Print("[GOM-HTTP] Verifier aussi que ai_server tourne (start_ai_server.bat)");
         }
      }
      return false;
   }
   bodyOut = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
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
   if(g_smcGomVerdictNum == 3) return 1;
   if(g_smcGomVerdictNum == -3) return -1;
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
   return (vnum == 3 || vnum == -3);
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
   return SMCGP_IsPerfectVerdict(g_smcGomVerdictNum);
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

void SMCGP_ParseGOMBody(const string &body)
{
   g_smcGomVerdict      = SMCGP_JsonString(body, "verdict");
   g_smcGomVerdictNum   = (int)SMCGP_JsonDouble(body, "verdict_num");
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
   g_cogRegime      = SMCGP_JsonString(body, "cog_regime");
   g_cogStrength    = SMCGP_JsonDouble(body, "cog_strength");
   g_cogConfidence  = SMCGP_JsonDouble(body, "cog_confidence");

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
   string safeStr      = SMCGP_JsonString(body, "correction_entry_safe");
   g_smcCorrEntrySafe  = (safeStr == "true" || safeStr == "1" || SMCGP_JsonBool(body, "correction_entry_safe"));

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
}

void SMCGP_InvalidateGOM()
{
   g_smcGomConnected  = false;
   g_smcGomVerdict    = "WAIT";
   g_smcGomVerdictNum = 0;
   g_smcSetupValid    = false;
   g_smcGomSource     = "OFF";
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
         SMCGP_NotifyGOMVerdictChange(SMCGP_ResolveGOMSym(_Symbol), prevVn, prevVerd);
      }
      return;
   }
   // ────────────────────────────────────────────────────────────────────────

   // TOUJOURS poll (même si UseGOMVerdictFilter + UseGOMPipeline + ShowGOMDashboard sont OFF)
   // Pour affichage temps réel du verdict sur SMC dashboard

   // Si GOMPollIntervalSec = 0, poll à chaque tick (instantané)
   // Sinon, respecter l'interval en secondes
   if(GOMPollIntervalSec > 0)
   {
      int age = (int)(TimeCurrent() - g_smcLastGOMPoll);
      if(age < GOMPollIntervalSec) return;  // Interval pas encore écoulé
   }
   // else: GOMPollIntervalSec == 0 → poll TOUJOURS (instantané)

   g_smcLastGOMPoll = TimeCurrent();

   string sym = SMCGP_EncodeSym(SMCGP_ResolveGOMSym(_Symbol));
   string body;
   bool ok = false;

   string chartTf = SMCGP_ChartTfLabel();
   string srcParam = "local";
   if(GOMVerdictSource == GOM_SRC_TRADINGVIEW) srcParam = "tv";
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
   // Fallback 3 supprimé — /gom-verdict retourne des données stales (cache Python non temps-réel)
   // En cas d'échec des deux premiers endpoints, on invalide le GOM plutôt que de trader sur données stales

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
   if(prevVnum != g_smcGomVerdictNum || prevVerd != g_smcGomVerdict)
      SMCGP_NotifyGOMVerdictChange(symLabel, prevVnum, prevVerd);
   if(prevSpikeLevel != g_smcGomSpikeLevel || prevSpikeTrad != g_smcGomSpikeTradable)
      SMCGP_NotifySpikeImminent(symLabel, prevSpikeLevel, prevSpikeTrad);

   // DEBUG: Log des requêtes réussies
   Print("[GOM-POLL] ✅ SUCCESS for ", sym, " | Verdict: ", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") | Coherence: ", g_smcGomCoherence, "%");
}

bool SMCGP_IsGoodPerfect(int vnum)
{
   return (vnum == 2 || vnum == 3 || vnum == -2 || vnum == -3);
}

void SMCGP_PushGOMMsg(const string msg)
{
   Print("[GOM-NOTIF] ", msg);
   Alert(msg);
   if(!SendNotification(msg))
      Print("[GOM-NOTIF] SendNotification a echoue — verifier Options > Notifications MT5");
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
   if(StringFind(_smcSym, "BOOM") < 0 && StringFind(_smcSym, "CRASH") < 0) return;

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
      string side = (StringFind(symLabel, "Boom") >= 0 || StringFind(_Symbol, "Boom") >= 0) ? "BUY spike" : "SELL spike";
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
   return (g_smcGomCoherence >= minCoh);
}

bool SMCGP_GOMAllowsDirectionEx(const int dir, const bool requireOBTouch)
{
   if(!UseGOMVerdictFilter) return true;
   if(!g_smcGomConnected) { Print("[GOM-ALLOW] Rejeté: NOT_CONNECTED"); return false; }
   if(g_smcGomVerdictNum == 0) { Print("[GOM-ALLOW] Rejeté: VERDICT_ZERO"); return false; }

   // PERFECT : gates allégés — le verdict vn=±3 prime sur BB/MTF
   if(SMCGP_IsPerfectVerdict(g_smcGomVerdictNum))
   {
      if(dir == 1 && g_smcGomVerdictNum != 3) return false;
      if(dir == -1 && g_smcGomVerdictNum != -3) return false;
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

   // 4. Correction Cycle — ne pas entrer pendant une correction (exempt Boom/Crash)
   if(!SMCGP_IsBoomCrashSym(_Symbol) && !g_smcCorrEntrySafe && g_smcCorrExhaustPct < 65.0)
   { Print("[EA-INDEP] ❌ Rejeté: correction active (", g_smcCorrPhase, " ", DoubleToString(g_smcCorrExhaustPct, 0), "%)"); return false; }

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

void SMCGP_DrawTVLevels()
{
   if(!ShowTVSyncedLevels) return;

   static datetime s_last = 0;
   if((int)(TimeCurrent() - s_last) < 3) return;
   s_last = TimeCurrent();

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

   datetime tOb0 = iTime(_Symbol, PERIOD_CURRENT, 10);
   datetime tObE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 60;

   if(ShowTVOrderBlocks && g_smcObBullTop > 0 && g_smcObBullBot > 0)
   {
      double zH = MathMax(g_smcObBullTop, g_smcObBullBot);
      double zL = MathMin(g_smcObBullTop, g_smcObBullBot);
      int dp = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      ObjectDelete(0, "SMC_OB_BULL_ZONE");
      ObjectCreate(0, "SMC_OB_BULL_ZONE", OBJ_RECTANGLE, 0, tOb0, zH, tObE, zL);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_BACK, true);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_SELECTABLE, false);
      // Label prix OB Bull
      ObjectDelete(0, "SMC_OB_BULL_LBL");
      ObjectCreate(0, "SMC_OB_BULL_LBL", OBJ_TEXT, 0, tObE, zH);
      ObjectSetString(0, "SMC_OB_BULL_LBL", OBJPROP_TEXT,
         "OB+ " + DoubleToString(zL, dp) + "-" + DoubleToString(zH, dp));
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "SMC_OB_BULL_LBL", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, "SMC_OB_BULL_LBL", OBJPROP_SELECTABLE, false);
   }
   else { ObjectDelete(0, "SMC_OB_BULL_ZONE"); ObjectDelete(0, "SMC_OB_BULL_LBL"); }

   if(ShowTVOrderBlocks && g_smcObBearTop > 0 && g_smcObBearBot > 0)
   {
      double zH = MathMax(g_smcObBearTop, g_smcObBearBot);
      double zL = MathMin(g_smcObBearTop, g_smcObBearBot);
      int dp = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      ObjectDelete(0, "SMC_OB_BEAR_ZONE");
      ObjectCreate(0, "SMC_OB_BEAR_ZONE", OBJ_RECTANGLE, 0, tOb0, zH, tObE, zL);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_BACK, true);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_SELECTABLE, false);
      // Label prix OB Bear
      ObjectDelete(0, "SMC_OB_BEAR_LBL");
      ObjectCreate(0, "SMC_OB_BEAR_LBL", OBJ_TEXT, 0, tObE, zH);
      ObjectSetString(0, "SMC_OB_BEAR_LBL", OBJPROP_TEXT,
         "OB- " + DoubleToString(zL, dp) + "-" + DoubleToString(zH, dp));
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "SMC_OB_BEAR_LBL", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, "SMC_OB_BEAR_LBL", OBJPROP_SELECTABLE, false);
   }
   else { ObjectDelete(0, "SMC_OB_BEAR_ZONE"); ObjectDelete(0, "SMC_OB_BEAR_LBL"); }

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
   string url = AI_ServerURL + "/pending-order?symbol=" + symEnc;
   char dp[], dr[];
   string dh;
   int code = WebRequest("DELETE", url, "Content-Type: application/json\r\n", AI_Timeout_ms, dp, dr, dh);
   return (code == 200 || code == 204);
}

bool SMCGP_DeletePendingOrder(const string sym)
{
   return SMCGP_MarkPipelineConsumed(sym);
}

double SMCGP_MinStopDistance(const string sym)
{
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0) return 0;
   int stops  = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
   double minD = (double)MathMax(stops + freeze + 5, 10) * pt;
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   bool isBC = (StringFind(sym, "Boom") >= 0 || StringFind(sym, "Crash") >= 0);
   if(isBC && ask > 0)
      minD = MathMax(minD, ask * 0.0008);
   return minD;
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
   double minD = SMCGP_MinStopDistance(sym);
   double refEntry = (entryPx > 0) ? entryPx : px;

   double slDist = (slOrig > 0) ? MathAbs(refEntry - slOrig) : minD * 2.0;
   double tpDist = (tpOrig > 0) ? MathAbs(tpOrig - refEntry) : minD * 3.0;
   slDist = MathMax(slDist, minD);
   tpDist = MathMax(tpDist, minD);

   ENUM_ORDER_TYPE otype = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   for(int pass = 0; pass < 4; pass++)
   {
      if(dir == 1)
      {
         sl = NormalizeDouble(refEntry - slDist, dg);
         tp = NormalizeDouble(refEntry + tpDist, dg);
         if(sl >= refEntry) sl = NormalizeDouble(refEntry - minD, dg);
         if(tp <= refEntry) tp = NormalizeDouble(refEntry + minD * 2.0, dg);
      }
      else
      {
         sl = NormalizeDouble(refEntry + slDist, dg);
         tp = NormalizeDouble(refEntry - tpDist, dg);
         if(sl <= refEntry) sl = NormalizeDouble(refEntry + minD, dg);
         if(tp >= refEntry) tp = NormalizeDouble(refEntry - minD * 2.0, dg);
      }

      if(SMCGP_OrderCheckMarket(sym, otype, lot, sl, tp))
         return true;

      slDist *= 1.2;
      tpDist *= 1.2;
   }
   return false;
}

bool SMCGP_ExecutePipelineOrder(const string sym, const string action,
                                double entry, double sl, double tp, double lot, const bool isPipeline)
{
   if(BlockAllTrades) return false;
   if(CountPositionsForSymbol(sym) > 0) return false;
   if(!IsDirectionAllowedForBoomCrash(sym, action)) return false;

   // Max positions atteint : si signal PERFECT, placer ordre LIMIT au lieu de bloquer
   if(CountPositionsOurEA() >= MaxPositionsTerminal)
   {
      if(SMCGP_IsPerfectVerdict(g_smcGomVerdictNum) && entry > 0 && sl > 0 && tp > 0)
      {
         Print("[SMC-GOM] Max positions (", MaxPositionsTerminal, ") — signal PERFECT ",
               action, " ", sym, " → ordre LIMIT placé au lieu de marché");
         // L'ordre LIMIT sera exécuté quand une position se libère + prix touche l'entry
      }
      else
      {
         Print("[SMC-GOM] 🚫 Max positions (", MaxPositionsTerminal, ") — ", action, " ", sym, " bloqué");
         return false;
      }
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

   // GATE CORRECTION CYCLE — bloquer si correction en cours (entrée trop tôt)
   // Exempt Boom/Crash (pas de corrections classiques)
   if(!SMCGP_IsBoomCrashSym(sym) && !g_smcCorrEntrySafe && g_smcCorrExhaustPct < 65.0)
   {
      Print("[SMC-GOM] 🚫 Ordre ", action, " ", sym, " bloqué — correction en cours (",
            g_smcCorrPhase, " ", DoubleToString(g_smcCorrExhaustPct, 0), "% < 65%)");
      return false;
   }

   // source=pipeline : filtre GOM déjà appliqué côté Python au moment du POST.
   // Vérification minimale en live : si le verdict a changé à WAIT ou s'est inversé depuis, annuler.
   if(isPipeline && UseGOMVerdictFilter)
   {
      if(g_smcGomVerdictNum == 0)
      {
         Print("[SMC-GOM] 🚫 Pipeline ", action, " ", sym, " annulé — GOM=WAIT depuis le POST Python");
         return false;
      }
      int gomDir = (g_smcGomVerdictNum > 0) ? 1 : -1;
      if(gomDir != dir)
      {
         Print("[SMC-GOM] 🚫 Pipeline ", action, " ", sym, " annulé — GOM inversé (vn=",
               g_smcGomVerdictNum, ") depuis le POST Python");
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

      // GOM dans le même sens (déjà validé avant, mais on vérifie le niveau)
      bool gomPerfect = (pipeDir > 0) ? (g_smcGomVerdictNum >= 2) : (g_smcGomVerdictNum <= -2);

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
         // Pas de triple alignement : bloquer si cognition ou IA s'oppose/est faible
         bool cogOppose = (StringLen(g_cogDirection) > 0 && g_cogDirection != "NEUTRAL" &&
                           ((pipeDir > 0 && g_cogDirection == "SELL") || (pipeDir < 0 && g_cogDirection == "BUY")));
         bool iaOppose  = (StringLen(iaActionUp) > 0 && iaActionUp != "HOLD" &&
                           iaActionUp != action && g_lastAIConfidence >= 0.55);
         if(cogOppose || iaOppose)
         {
            Print("[TRIPLE] 🚫 Signal bloqué — pas de triple alignement | cogConfirms=", cogConfirms,
                  " iaConfirms=", iaConfirms, " cog=", g_cogDirection, " ia=", g_lastAIAction);
            return false;
         }
         // Alignement partiel acceptable (cognition neutre ou IA faible) — on laisse passer
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

   if(lot <= 0) lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(UseMinLotOnly) lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   trade.SetExpertMagicNumber(InpMagicNumber);
   double execPx = (MathAbs(entryPx - mktPx) < SymbolInfoDouble(sym, SYMBOL_POINT)) ? 0 : entryPx;
   bool ok = (dir == 1)
      ? trade.Buy(lot, sym, execPx, sl, tp, "SMC_PIPELINE")
      : trade.Sell(lot, sym, execPx, sl, tp, "SMC_PIPELINE");

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

   PrintFormat("[SMC-GOM] ❌ Pipeline échec %s %s: %s", sym, action, trade.ResultRetcodeDescription());
   uint rc = trade.ResultRetcode();
   if(rc == TRADE_RETCODE_INVALID_STOPS || rc == TRADE_RETCODE_INVALID_PRICE)
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
   bool holdFromDashboard = (g_smcIAStatusAction == "HOLD" || StringLen(g_smcIAStatusAction) == 0);
   bool holdFromDecide    = (g_lastAIAction == "hold" || g_lastAIAction == "HOLD" || g_lastAIAction == "");
   if(holdFromDashboard || holdFromDecide)
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
   if(lot <= 0) lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   string serverVerdict = SMCGP_JsonString(orderBody, "gom_verdict");
   StringToUpper(serverVerdict);
   // source=pipeline : tous les filtres GOM déjà appliqués côté Python — bypass
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
#define SMC_DASH_C_BG        0x1E1E1E
#define SMC_DASH_C_TXT       0xE0E0E0
#define SMC_DASH_C_BORDER    0x404040
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
   int cy = marginBot + (cellH + gap) * 4 + radius + 28;

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

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   if(chartW < 400) chartW = 1200;

   const int COLS = 9;
   const int cellH = SMC_DASH_ROW_H;
   const int gap = 2;
   const int marginLR = 10;
   const int marginBot = GOMDashboardY;
   int totalW = chartW - 2 * marginLR;
   int cellW = (totalW - (COLS - 1) * gap) / COLS;
   if(cellW < 60) cellW = 60;

   int y0 = marginBot + cellH + gap;
   int y1 = marginBot;
   int y2 = marginBot + (cellH + gap) * 2;
   int y3 = marginBot + (cellH + gap) * 3;

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
   if(g_smcGomVerdictNum >= 2 || g_smcGomVerdictNum <= -2) verdLabel += " *";

   int xCur = marginLR;
   SMCGP_DrawDashCell("V0_HDR", xCur, y0, cellW, cellH, sym + " GOM", cVerdict, cTxt);

   string tfLbl[7] = {"M1", "M5", "M15", "H1", "H4", "D1", "GLOB"};
   string tfDir[7];
   int    tfRsi[7];
   tfDir[0] = g_smcTfM1Dir;  tfRsi[0] = g_smcTfM1Rsi;
   tfDir[1] = g_smcTfM5Dir;  tfRsi[1] = g_smcTfM5Rsi;
   tfDir[2] = g_smcTfM15Dir; tfRsi[2] = g_smcTfM15Rsi;
   tfDir[3] = g_smcTfH1Dir;  tfRsi[3] = g_smcTfH1Rsi;
   tfDir[4] = g_smcTfH4Dir;  tfRsi[4] = g_smcTfH4Rsi;
   tfDir[5] = g_smcTfD1Dir;  tfRsi[5] = g_smcTfD1Rsi;
   tfDir[6] = g_smcGomGlobalDir; tfRsi[6] = g_smcGomGlobalStr;

   for(int i = 0; i < 7; i++)
   {
      xCur += cellW + gap;
      color cTF = SMCGP_TfColor(tfDir[i]);
      string tfTxt = tfLbl[i] + " " + SMCGP_TfShort(tfDir[i]);
      if(tfRsi[i] > 0) tfTxt += " R" + IntegerToString(tfRsi[i]);
      SMCGP_DrawDashCell("V0_TF" + IntegerToString(i), xCur, y0, cellW, cellH, tfTxt, cTF, cTxt);
   }

   xCur += cellW + gap;
   color cKola = SMCGP_TfColor(g_smcGomKolaState);
   SMCGP_DrawDashCell("V0_KOLA", xCur, y0, cellW, cellH,
                      "KOLA " + (StringLen(g_smcGomKolaState) > 0 ? g_smcGomKolaState : "---"), cKola, cTxt);

   xCur = marginLR;
   string scoreTxt = verdLabel + " B:" + DoubleToString(g_smcGomScoreBuy, 1) +
                     " S:" + DoubleToString(g_smcGomScoreSell, 1);
   SMCGP_DrawDashCell("V1_SCORE", xCur, y1, cellW, cellH, scoreTxt, cVerdict, cTxt);

   xCur += cellW + gap;
   color cRSI = (g_smcGomRsi < 35) ? (color)SMC_DASH_C_BUY :
                (g_smcGomRsi > 65) ? (color)SMC_DASH_C_SELL : cBg;
   SMCGP_DrawDashCell("V1_RSI", xCur, y1, cellW, cellH, "RSI " + IntegerToString(g_smcGomRsi), cRSI, cTxt);

   xCur += cellW + gap;
   color cQ = (g_smcGomQuality >= 60) ? (color)SMC_DASH_C_BUY :
              (g_smcGomQuality >= 35) ? (color)SMC_DASH_C_NEUTRAL : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("V1_QUAL", xCur, y1, cellW, cellH,
                      "Q:" + DoubleToString(g_smcGomQuality, 0) + "% C:" +
                      DoubleToString(g_smcGomCoherence, 0) + "%", cQ, cTxt);

   xCur += cellW + gap;
   SMCGP_DrawDashCell("V1_PRICE", xCur, y1, cellW, cellH,
                      DoubleToString(g_smcGomPrice, dg) + " Spk:" +
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
      string probTxt = UseHighProbabilityFilter
         ? ("P:" + DoubleToString(probScore, 0) + "% >" + DoubleToString(MinEntryProbabilityPct, 0))
         : ("P:" + DoubleToString(probScore, 0) + "% OFF");
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

   xCur = marginLR;
   color cSetup = (g_smcSetupDir == 1) ? (color)SMC_DASH_C_BUY :
                  (g_smcSetupDir == -1) ? (color)SMC_DASH_C_SELL : (color)SMC_DASH_C_NEUTRAL;
   string setupLabel = (g_smcSetupValid && g_smcSetupEntry > 0)
      ? g_smcSetupType + (g_smcSetupDir == 1 ? " ^" : " v")
      : "NO SETUP";
   SMCGP_DrawDashCell("S0_TYPE", xCur, y2, cellW, cellH, setupLabel, cSetup, cTxt);

   xCur += cellW + gap;
   string entryTxt = (g_smcSetupEntry > 0) ? "E " + DoubleToString(g_smcSetupEntry, dg) : "---";
   SMCGP_DrawDashCell("S1_ENTRY", xCur, y2, cellW, cellH, entryTxt, cSetup, cTxt);

   xCur += cellW + gap;
   string slTxt = (g_smcSetupSL > 0) ? "SL " + DoubleToString(g_smcSetupSL, dg) : "---";
   SMCGP_DrawDashCell("S2_SL", xCur, y2, cellW, cellH, slTxt, (color)SMC_DASH_C_SELL, cTxt);

   xCur += cellW + gap;
   string tp1Txt = (g_smcSetupTP1 > 0) ? "TP1 " + DoubleToString(g_smcSetupTP1, dg) : "---";
   SMCGP_DrawDashCell("S3_TP1", xCur, y2, cellW, cellH, tp1Txt, (color)SMC_DASH_C_BUY, cTxt);

   xCur += cellW + gap;
   string tp2Txt = (g_smcSetupTP2 > 0) ? "TP2 " + DoubleToString(g_smcSetupTP2, dg) : "---";
   SMCGP_DrawDashCell("S4_TP2", xCur, y2, cellW, cellH, tp2Txt, (color)SMC_DASH_C_BUY, cTxt);

   xCur += cellW + gap;
   string rrTxt = (g_smcSetupRR > 0) ? "R/R " + DoubleToString(g_smcSetupRR, 1) : "R/R ---";
   color cRR = (g_smcSetupRR >= 1.5) ? (color)SMC_DASH_C_BUY :
               (g_smcSetupRR > 0) ? (color)SMC_DASH_C_NEUTRAL : cBg;
   SMCGP_DrawDashCell("S5_RR", xCur, y2, cellW, cellH, rrTxt, cRR, cTxt);

   xCur += cellW + gap;
   string confTxt = (StringLen(g_smcSetupConfirm) > 0) ? g_smcSetupConfirm : "CONFIRM ---";
   SMCGP_DrawDashCell("S6_CONF", xCur, y2, cellW, cellH, confTxt, cBg, cTxt);

   xCur += cellW + gap;
   double curPx = (g_smcSetupDir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tol = (curPx > 0) ? curPx * 0.0015 : 0;
   bool nearEntry = (g_smcSetupEntry > 0 && tol > 0 && MathAbs(curPx - g_smcSetupEntry) <= tol);
   string guardTxt = (g_smcSetupEntry > 0) ? (nearEntry ? "AT OB OK" : "WAIT OB") : "---";
   color cGuard = nearEntry ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_NEUTRAL;
   SMCGP_DrawDashCell("S7_GUARD", xCur, y2, cellW, cellH, guardTxt, cGuard, cTxt);

   xCur += cellW + gap;
   string pathTxt = (StringLen(g_smcPredPath) > 0) ? g_smcPredPath :
                    (g_smcSetupValid ? "PATH OK" : "---");
   SMCGP_DrawDashCell("S8_PATH", xCur, y2, cellW, cellH, pathTxt, cBg, cTxt);

   xCur = marginLR;
   color cCVD = (g_smcGhostCVD >= 0) ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("G0_CVD", xCur, y3, cellW, cellH,
                      "CVD " + (g_smcGhostCVD >= 0 ? "+" : "") + DoubleToString(g_smcGhostCVD, 0), cCVD, cTxt);

   xCur += cellW + gap;
   color cDelta = (g_smcGhostDelta >= 0) ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("G1_DLT", xCur, y3, cellW, cellH,
                      "D " + (g_smcGhostDelta >= 0 ? "+" : "") + DoubleToString(g_smcGhostDelta, 0), cDelta, cTxt);

   xCur += cellW + gap;
   color cSent = (g_smcGhostBuyPct > 60) ? (color)SMC_DASH_C_BUY :
                 (g_smcGhostBuyPct < 40) ? (color)SMC_DASH_C_SELL : (color)SMC_DASH_C_NEUTRAL;
   SMCGP_DrawDashCell("G2_SNT", xCur, y3, cellW, cellH,
                      "BUY " + DoubleToString(g_smcGhostBuyPct, 0) + "%", cSent, cTxt);

   xCur += cellW + gap;
   int compassOct = (int)((g_smcGhostCompass + 22.5) / 45.0) % 8;
   static const string compassLbls[8] = {"E>", "NE", "N^", "NW", "W<", "SW", "Sv", "SE"};
   bool compassBull = (compassOct == 0 || compassOct == 1 || compassOct == 2 || compassOct == 7);
   color cCmp = compassBull ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   string cmpTxt = compassLbls[compassOct] + " " + DoubleToString(g_smcGhostCompass, 0) + "d";
   SMCGP_DrawDashCell("G3_CMP", xCur, y3, cellW, cellH, cmpTxt, cCmp, cTxt);

   xCur += cellW + gap;
   int ghostBull = 0, ghostBear = 0;
   if(g_smcGhostCVD > 0) ghostBull++; else if(g_smcGhostCVD < 0) ghostBear++;
   if(g_smcGhostDelta > 0) ghostBull++; else if(g_smcGhostDelta < 0) ghostBear++;
   if(g_smcGhostBuyPct > 55) ghostBull++; else if(g_smcGhostBuyPct < 45) ghostBear++;
   if(compassBull) ghostBull++; else ghostBear++;
   string ghostCnf = "GHOST " + IntegerToString(ghostBull) + "B/" + IntegerToString(ghostBear) + "S";
   color cGhostCnf = (ghostBull >= 3) ? (color)SMC_DASH_C_BUY :
                     (ghostBear >= 3) ? (color)SMC_DASH_C_SELL : (color)SMC_DASH_C_NEUTRAL;
   SMCGP_DrawDashCell("G4_CNF", xCur, y3, cellW * 2, cellH, ghostCnf, cGhostCnf, cTxt);

   xCur += (cellW + gap) * 2;
   color cConn = g_smcGomConnected ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   string linkTxt = connTxt;
   // Cellule IA status commune aux deux branches
   // Priorité: IA status du dashboard GOM (ia_status_action) si disponible, sinon /decide
   string iaTxt; color cIA;
   if(!UseAIServer)
   {
      iaTxt = "IA OFF";
      cIA   = cBg;
   }
   else
   {
      // Utiliser l'action dashboard GOM si disponible (plus en phase avec ce qui est affiché)
      string displayAction = (StringLen(g_smcIAStatusAction) > 0) ? g_smcIAStatusAction : g_lastAIAction;
      double displayConf   = (g_iaStatusConfidence > 0.0) ? g_iaStatusConfidence : g_lastAIConfidence * 100.0;
      StringToUpper(displayAction);
      if(displayAction == "" || displayAction == "HOLD")
      {
         iaTxt = "IA HOLD " + DoubleToString(displayConf, 0) + "%";
         cIA   = (color)SMC_DASH_C_NEUTRAL;
      }
      else
      {
         iaTxt = "IA " + displayAction + " " + DoubleToString(displayConf, 0) + "%";
         cIA   = (displayAction == "BUY") ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
      }
   }

   {
      bool cogOk = (g_cogStrength >= CognitionMinStrength && g_cogConfidence >= CognitionMinConfidence);

      // Triple alignement : cog + IA + GOM dans le même sens
      string iaUp = g_lastAIAction;
      StringToUpper(iaUp);
      int gomDir = (g_smcGomVerdictNum > 0) ? 1 : (g_smcGomVerdictNum < 0) ? -1 : 0;
      bool cogAlignsBuy  = (g_cogDirection == "BUY"  && cogOk);
      bool cogAlignsSell = (g_cogDirection == "SELL" && cogOk);
      bool iaAlignsBuy   = (iaUp == "BUY"  && g_lastAIConfidence >= 0.65);
      bool iaAlignsSell  = (iaUp == "SELL" && g_lastAIConfidence >= 0.65);
      bool tripleAlignedBuy  = cogAlignsBuy  && iaAlignsBuy  && (gomDir == 1);
      bool tripleAlignedSell = cogAlignsSell && iaAlignsSell && (gomDir == -1);
      bool tripleAligned = tripleAlignedBuy || tripleAlignedSell;

      color cCog;
      string cogTxt;
      if(tripleAligned)
      {
         cCog   = tripleAlignedBuy ? (color)0xFF00E676 : (color)0xFFFF1744; // vert/rouge vif
         cogTxt = (tripleAlignedBuy ? "🔥BUY" : "🔥SELL") + " " + DoubleToString(g_cogConfidence * 100, 0) + "% 3x";
      }
      else
      {
         cCog   = cogOk ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
         cogTxt = "->5m " + g_cogDirection + " " + DoubleToString(g_cogConfidence * 100, 0) + "%";
      }
      SMCGP_DrawDashCell("G5_COG", xCur, y3, cellW, cellH, cogTxt, cCog, cTxt);
      xCur += cellW + gap;
      SMCGP_DrawDashCell("G6_IA", xCur, y3, cellW, cellH, iaTxt, cIA, cTxt);
      xCur += cellW + gap;

      // Cellule Correction Cycle
      string corrTxt = g_smcCorrPhase + " " + DoubleToString(g_smcCorrExhaustPct, 0) + "%";
      color cCorr = g_smcCorrEntrySafe ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
      if(g_smcCorrExhaustPct >= 45 && !g_smcCorrEntrySafe) cCorr = (color)SMC_DASH_C_NEUTRAL;
      SMCGP_DrawDashCell("G6B_CORR", xCur, y3, cellW, cellH, corrTxt, cCorr, cTxt);
      xCur += cellW + gap;

      SMCGP_DrawDashCell("G7_LINK", xCur, y3, cellW, cellH, linkTxt, cConn, cTxt);
   }

   if(ShowOrderFlowCompass)
      SMCGP_DrawOrderFlowCompass(chartW, marginBot, cellH, gap);
   else
      SMCGP_CleanupOrderFlowCompass();

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

   Print("[SMC-GOM] Module actif | symbole=", _Symbol,
         " | Pipeline=", UseGOMPipeline ? "ON" : "OFF",
         " | GOM=", UseGOMVerdictFilter ? "ON" : "OFF",
         " | TV sync=", ShowTVSyncedLevels ? "ON" : "OFF",
         " | Dashboard=", ShowGOMDashboard ? "ON" : "OFF",
         " | Heartbeat=", GOMSyncSymbolToTV ? "ON" : "OFF",
         " | CandlesUpload=", GOMUploadCandles ? "ON" : "OFF",
         " | Serveur=", AI_ServerURL);
   string pingBody;
   if(SMCGP_HttpGet("/health", pingBody, 3000))
      Print("[SMC-GOM] ai_server OK — GOM local MT5 actif");
   else
      Print("[SMC-GOM] ai_server INJOIGNABLE (HTTP ", g_smcLastHttpCode,
            ") — verdict GOM indisponible tant que WebRequest + serveur ne sont pas OK");
}

void SMCGP_Deinit()
{
   if(g_smcCandlesUploader != NULL)
   {
      delete g_smcCandlesUploader;
      g_smcCandlesUploader = NULL;
   }
   if(g_pipelineEma9Handle != INVALID_HANDLE)
   { IndicatorRelease(g_pipelineEma9Handle); g_pipelineEma9Handle = INVALID_HANDLE; }
}

#include "SMC_FuturePath.mqh"

#endif
