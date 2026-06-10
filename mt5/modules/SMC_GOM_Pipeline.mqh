//+------------------------------------------------------------------+
//| SMC_GOM_Pipeline.mqh — GOM verdict + pipeline + dessins TV sync  |
//| Pattern TradeManager.mq5 (KOLA, OB setup, OTE zone)            |
//+------------------------------------------------------------------+
#ifndef SMC_GOM_PIPELINE_MQH
#define SMC_GOM_PIPELINE_MQH

// ── État GOM ───────────────────────────────────────────────────────
string   g_smcGomVerdict      = "WAIT";
int      g_smcGomVerdictNum   = 0;
double   g_smcGomQuality      = 0.0;
double   g_smcGomCoherence    = 0.0;
double   g_smcGomKolaBuy      = 0.0;
double   g_smcGomKolaSell     = 0.0;
string   g_smcGomKolaState    = "";
string   g_smcGomGlobalDir    = "";
int      g_smcGomGlobalStr    = 0;
bool     g_smcGomConnected    = false;
datetime g_smcLastGOMPoll     = 0;
datetime g_smcLastMCPPoll      = 0;
datetime g_smcLastPipelineExec= 0;
string   g_smcLastPipelineId  = "";
string   g_smcGomSource       = "OFF";
double   g_smcGomScoreBuy     = 0.0;
double   g_smcGomScoreSell    = 0.0;
int      g_smcGomRsi          = 50;
double   g_smcGomPrice        = 0.0;
double   g_smcGomSpikePct     = 0.0;
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

string SMCGP_EncodeSym(const string sym)
{
   string enc = sym;
   StringReplace(enc, " ", "%20");
   return enc;
}

string SMCGP_ResolveGOMSym(const string sym)
{
   // Mapping pour symboles non-reconnus par le serveur IA
   if(sym == "XAUEUR" || sym == "GOLD" || sym == "OR") return "XAUUSD";

   // Boom/Crash → Deriv equivalent (reconnaissance serveur)
   if(StringFind(sym, "Boom") >= 0)  return "Boom 500 Index";  // OU découper par taille
   if(StringFind(sym, "Crash") >= 0) return "Crash 500 Index";

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
   string body = StringFormat(
      "{\"symbol\":\"%s\",\"ea\":\"SMC_Universal\",\"magic\":%d,\"chart_id\":%I64d}",
      symJson, InpMagicNumber, ChartID());
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
   if(code != 200) return false;
   bodyOut = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return true;
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
   g_smcBbUp            = SMCGP_JsonDouble(body, "bb_up");
   g_smcBbMid           = SMCGP_JsonDouble(body, "bb_mid");
   g_smcBbDn            = SMCGP_JsonDouble(body, "bb_dn");
   g_smcObBullTop       = SMCGP_JsonDouble(body, "ob_bull_top");
   g_smcObBullBot       = SMCGP_JsonDouble(body, "ob_bull_bot");
   g_smcObBearTop       = SMCGP_JsonDouble(body, "ob_bear_top");
   g_smcObBearBot       = SMCGP_JsonDouble(body, "ob_bear_bot");
   g_smcPredPath        = SMCGP_JsonString(body, "pred_path");
   if(g_smcGomPrice <= 0) g_smcGomPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Parser les prédictions Bollinger Bands (arrays JSON)
   SMCGP_ParsePredictionArrays(body);

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

   if(StringLen(g_smcGomKolaState) == 0)
   {
      if(StringFind(body, "NEAR BUY") >= 0)  g_smcGomKolaState = "NEAR BUY";
      else if(StringFind(body, "NEAR SELL") >= 0) g_smcGomKolaState = "NEAR SELL";
      else g_smcGomKolaState = "---";
   }

   bool hasData = (g_smcGomVerdictNum != 0 || g_smcGomScoreBuy > 0 || g_smcGomScoreSell > 0);
   g_smcGomConnected = hasData && StringLen(g_smcGomVerdict) > 0;
   string src = SMCGP_JsonString(body, "data_source");
   if(StringLen(src) == 0) src = "TV";
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
   if(!UseGOMVerdictFilter && !UseGOMPipeline && !ShowGOMDashboard) return;
   if((int)(TimeCurrent() - g_smcLastGOMPoll) < GOMPollIntervalSec) return;
   g_smcLastGOMPoll = TimeCurrent();

   string sym = SMCGP_EncodeSym(SMCGP_ResolveGOMSym(_Symbol));
   string body;
   bool ok = false;

   if(SMCGP_HttpGet("/gom-tableau-complete?symbol=" + sym, body, AI_Timeout_ms)
      && (SMCGP_JsonBool(body, "ok") || StringFind(body, "\"ok\":true") >= 0))
      ok = true;
   else if(SMCGP_HttpGet("/gom-verdict?symbol=" + sym, body, AI_Timeout_ms)
           && (SMCGP_JsonBool(body, "ok") || StringFind(body, "\"ok\":true") >= 0))
      ok = true;

   if(!ok)
   {
      SMCGP_InvalidateGOM();
      // Déterminer la source d'erreur
      if(g_smcLastHttpCode == 0 || g_smcLastHttpCode == -1)
         g_smcGomSource = "NO_HTTP";
      else if(StringFind(body, "WAIT") >= 0 || StringFind(body, "non disponibles") >= 0)
         g_smcGomSource = "WAIT_POLL";  // Données pas encore pollées
      else
         g_smcGomSource = "HTTP_" + IntegerToString(g_smcLastHttpCode);
      return;
   }

   SMCGP_ParseGOMBody(body);
}

bool SMCGP_IsGoodPerfect(int vnum)
{
   return (vnum == 2 || vnum == 3 || vnum == -2 || vnum == -3);
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

bool SMCGP_GOMAllowsDirectionEx(const int dir, const bool requireOBTouch)
{
   if(!UseGOMVerdictFilter) return true;
   if(!g_smcGomConnected) { Print("[GOM-ALLOW] Rejeté: NOT_CONNECTED"); return false; }
   if(g_smcGomVerdictNum == 0) { Print("[GOM-ALLOW] Rejeté: VERDICT_ZERO"); return false; }
   if(!SMCGP_IsGoodPerfect(g_smcGomVerdictNum)) { Print("[GOM-ALLOW] Rejeté: NOT_GOOD_PERFECT vn=", g_smcGomVerdictNum); return false; }

   if(GOMMinCoherencePct > 0 && g_smcGomCoherence > 0 && g_smcGomCoherence < GOMMinCoherencePct)
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

   Print("[GOM-ALLOW] ✅ Autorisé pour dir=", dir, " vn=", g_smcGomVerdictNum);
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
   if(!UseOTE || !g_smcSetupValid || g_smcSetupEntry <= 0 || g_smcSetupSL <= 0) return;

   double hi = MathMax(g_smcSetupEntry, g_smcSetupSL);
   double lo = MathMin(g_smcSetupEntry, g_smcSetupSL);
   double range = hi - lo;
   if(range <= 0) return;

   double oteLo, oteHi;
   if(g_smcSetupDir == 1)
   {
      oteHi = hi - range * 0.62;
      oteLo = hi - range * 0.79;
   }
   else
   {
      oteLo = lo + range * 0.62;
      oteHi = lo + range * 0.79;
   }

   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 10);
   datetime tE = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 60;
   ObjectCreate(0, "SMC_OTE_ZONE", OBJ_RECTANGLE, 0, t0, oteHi, tE, oteLo);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_COLOR, clrDarkOrange);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_FILL, true);
   ObjectSetInteger(0, "SMC_OTE_ZONE", OBJPROP_SELECTABLE, false);

   ObjectCreate(0, "SMC_OTE_LABEL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, "SMC_OTE_LABEL", OBJPROP_TEXT, "OTE 62-79%");
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_COLOR, clrDarkOrange);
   ObjectSetInteger(0, "SMC_OTE_LABEL", OBJPROP_FONTSIZE, 9);
}

void SMCGP_CleanupLegacyDrawings()
{
   if(!CleanupLegacyDrawings) return;
   string prefixes[] = {
      "SMC_OB_", "SMC_FVG_", "SMC_Liq_", "SMC_Fib_", "SMC_EMA_",
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
      ObjectDelete(0, "SMC_OB_BULL_ZONE");
      ObjectCreate(0, "SMC_OB_BULL_ZONE", OBJ_RECTANGLE, 0, tOb0, zH, tObE, zL);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_BACK, true);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SMC_OB_BULL_ZONE", OBJPROP_SELECTABLE, false);
   }
   else ObjectDelete(0, "SMC_OB_BULL_ZONE");

   if(ShowTVOrderBlocks && g_smcObBearTop > 0 && g_smcObBearBot > 0)
   {
      double zH = MathMax(g_smcObBearTop, g_smcObBearBot);
      double zL = MathMin(g_smcObBearTop, g_smcObBearBot);
      ObjectDelete(0, "SMC_OB_BEAR_ZONE");
      ObjectCreate(0, "SMC_OB_BEAR_ZONE", OBJ_RECTANGLE, 0, tOb0, zH, tObE, zL);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_BACK, true);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SMC_OB_BEAR_ZONE", OBJPROP_SELECTABLE, false);
   }
   else ObjectDelete(0, "SMC_OB_BEAR_ZONE");

   ChartRedraw(0);
}

void SMCGP_CleanupChartObjects()
{
   string prefixes[] = {"TM_KOLA_", "TM_OB_", "TM_BB_", "GOM_PRED_", "SMC_OTE_", "SMC_OB_"};
   for(int p = 0; p < ArraySize(prefixes); p++)
      ObjectsDeleteAll(0, prefixes[p]);
   ObjectDelete(0, "TM_OB_LABEL");
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

bool SMCGP_ExecutePipelineOrder(const string sym, const string action,
                                double sl, double tp, double lot, const bool isPipeline)
{
   if(BlockAllTrades) return false;
   if(CountPositionsForSymbol(sym) > 0) return false;
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return false;
   if(!IsDirectionAllowedForBoomCrash(sym, action)) return false;

   int dir = (action == "BUY") ? 1 : -1;

   if(UseGOMVerdictFilter)
   {
      bool needOB = GOMRequireOBTouch && (isPipeline ? GOMOBTouchForPipeline : true);
      if(!SMCGP_GOMAllowsDirectionEx(dir, needOB))
      {
         Print("[SMC-GOM] Ordre ", action, " bloqué — GOM=", g_smcGomVerdict,
               " vn=", g_smcGomVerdictNum, " BB/OB/tendance");
         return false;
      }
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

   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   int stopsLvl = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (double)MathMax(stopsLvl + 5, 10) * SymbolInfoDouble(sym, SYMBOL_POINT);
   double refPx = (dir == 1) ? ask : bid;

   if(sl > 0 && MathAbs(refPx - sl) < minDist)
      sl = NormalizeDouble((dir == 1) ? refPx - minDist : refPx + minDist, dg);
   if(tp > 0 && MathAbs(tp - refPx) < minDist)
      tp = NormalizeDouble((dir == 1) ? refPx + minDist : refPx - minDist, dg);

   if(lot <= 0) lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(UseMinLotOnly) lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   trade.SetExpertMagicNumber(InpMagicNumber);
   bool ok = (dir == 1)
      ? trade.Buy(lot, sym, 0, sl, tp, "SMC_PIPELINE")
      : trade.Sell(lot, sym, 0, sl, tp, "SMC_PIPELINE");

   ReleaseOpenLock();

   if(ok)
   {
      g_smcLastPipelineExec = TimeCurrent();
      PrintFormat("[SMC-GOM] ✅ Pipeline %s %s lot=%.2f SL=%.5f TP=%.5f | GOM=%s",
                  sym, action, lot, sl, tp, g_smcGomVerdict);
      SMCGP_MarkPipelineConsumed(sym);
      return true;
   }

   PrintFormat("[SMC-GOM] ❌ Pipeline échec %s %s: %s", sym, action, trade.ResultRetcodeDescription());
   return false;
}

void SMCGP_PollAndExecutePipeline()
{
   if(!UseGOMPipeline) return;
   if((int)(TimeCurrent() - g_smcLastMCPPoll) < MCPPollIntervalSec) return;
   g_smcLastMCPPoll = TimeCurrent();

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

   string action = SMCGP_JsonString(orderBody, "action");
   if(StringLen(action) == 0) action = SMCGP_JsonString(orderBody, "recommendation");
   StringToUpper(action);
   if(action != "BUY" && action != "SELL") return;

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
   if(UseGOMVerdictFilter)
   {
      int pDir = (action == "BUY") ? 1 : -1;
      bool needOB = GOMRequireOBTouch && (isPipeline ? GOMOBTouchForPipeline : true);
      if(!SMCGP_GOMAllowsDirectionEx(pDir, needOB))
      {
         Print("[SMC-GOM] Pipeline rejeté — GOM=", g_smcGomVerdict,
               " vn=", g_smcGomVerdictNum, " BB/OB/tendance");
         return;
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

   if(SMCGP_ExecutePipelineOrder(_Symbol, action, sl, tp, lot, isPipeline))
      g_smcLastPipelineId = orderId;
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
   string bgName  = "SMC_DASH_" + name + "_BG";
   string txtName = "SMC_DASH_" + name + "_TXT";

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
   ObjectsDeleteAll(0, "SMC_DASH_");
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
   string ts = TimeToString(TimeCurrent(), TIME_MINUTES);
   int pollAge = (g_smcLastGOMPoll > 0) ? (int)(TimeCurrent() - g_smcLastGOMPoll) : -1;

   string connTxt = g_smcGomConnected ? "PY+TV OK" : "PY/TV OFF";
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
   SMCGP_DrawDashCell("V1_PIPE", xCur, y1, cellW, cellH,
                      "PIPE " + (UseGOMPipeline ? "ON" : "OFF"), cBg, cTxt);

   xCur += cellW + gap;
   color cGlob = (g_smcGomGlobalStr >= GOMGlobalMinConfidence) ? (color)SMC_DASH_C_BUY : (color)SMC_DASH_C_SELL;
   SMCGP_DrawDashCell("V1_GLOB", xCur, y1, cellW, cellH,
                      SMCGP_TfShort(g_smcGomGlobalDir) + " " + IntegerToString(g_smcGomGlobalStr) + "%",
                      cGlob, cTxt);

   xCur += cellW + gap;
   string srcTxt = g_smcGomSource + " " + ts;
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
   SMCGP_DrawDashCell("G5_LINK", xCur, y3, cellW * 2, cellH, connTxt, cConn, cTxt);

   ChartRedraw(0);
}

void SMCGP_OnTimer()
{
   if(UltraLightMode) return;
   SMCGP_SendHeartbeat();
   SMCGP_PollGOM();
   if(ShowGOMDashboard)
      SMCGP_DrawGOMDashboard();
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
      Print("[SMCGP] Prédictions chargées: ", ArraySize(g_smcPredBbMid), " points");
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
   g_smcGomVerdict = "WAIT";
   Print("[SMC-GOM] Module actif | symbole=", _Symbol,
         " | Pipeline=", UseGOMPipeline ? "ON" : "OFF",
         " | GOM=", UseGOMVerdictFilter ? "ON" : "OFF",
         " | TV sync=", ShowTVSyncedLevels ? "ON" : "OFF",
         " | Dashboard=", ShowGOMDashboard ? "ON" : "OFF",
         " | Heartbeat=", GOMSyncSymbolToTV ? "ON" : "OFF",
         " | Serveur=", AI_ServerURL);
}

#endif
