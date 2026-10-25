//+------------------------------------------------------------------+
//| SMC_ChartEyes.mqh — Yeux temps réel via ai_server                 |
//| Scanne indicateurs + zones graphiques et renvoie opportunités     |
//+------------------------------------------------------------------+
#ifndef SMC_CHART_EYES_MQH
#define SMC_CHART_EYES_MQH

// Déclarées dans SMC_Universal.mq5 (après les includes)
extern double   g_cachedBestBuyLevel;
extern double   g_cachedBestSellLevel;

input bool UseChartEyes      = true;
input int  ChartEyesPollSec  = 15;

string   g_chartEyesAction       = "";
double   g_chartEyesConfidence   = 0.0;
bool     g_chartEyesExecuteReady = false;
datetime g_chartEyesLastPoll     = 0;
string   g_chartEyesOpportunity  = "";

double SMCCE_CalcEMA(const int period)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = period + 5;
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, need, r) < need) return 0.0;
   double k = 2.0 / (period + 1.0);
   double ema = r[need - 1].close;
   for(int i = need - 2; i >= 0; i--)
      ema = r[i].close * k + ema * (1.0 - k);
   return ema;
}

double SMCCE_CalcRSI(const int period = 14)
{
   int h = iRSI(_Symbol, PERIOD_CURRENT, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 50.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, 0, 1, buf) < 1) { IndicatorRelease(h); return 50.0; }
   double v = buf[0];
   IndicatorRelease(h);
   return v;
}

double SMCCE_CalcATR(const int period = 14)
{
   int h = iATR(_Symbol, PERIOD_CURRENT, period);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, 0, 1, buf) < 1) { IndicatorRelease(h); return 0.0; }
   double v = buf[0];
   IndicatorRelease(h);
   return v;
}

void SMCCE_PollChartOpportunities()
{
   if(!UseChartEyes || !UseAIServer) return;
   if(ChartEyesPollSec > 0 && (int)(TimeCurrent() - g_chartEyesLastPoll) < ChartEyesPollSec)
      return;
   g_chartEyesLastPoll = TimeCurrent();

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;

   double close = (bid + ask) / 2.0;
   double ema9  = SMCCE_CalcEMA(9);
   double ema21 = SMCCE_CalcEMA(21);
   double ema50 = SMCCE_CalcEMA(50);
   double rsi   = SMCCE_CalcRSI(14);
   double atr   = SMCCE_CalcATR(14);

   string sym = SMCGP_JsonEscape(SMCGP_ResolveGOMSym(_Symbol));
   string tf  = SMCGP_ChartTfLabel();

   string body = StringFormat(
      "{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"close\":%.8f,"
      "\"indicators\":{\"close\":%.8f,\"ema9\":%.8f,\"ema21\":%.8f,\"ema50\":%.8f,"
      "\"rsi\":%.4f,\"atr\":%.8f,\"in_correction_zone\":%s},"
      "\"gom_verdict\":\"%s\",\"gom_verdict_num\":%d,\"gom_connected\":%s,"
      "\"chart_levels\":{\"buy_zone\":%.8f,\"sell_zone\":%.8f,"
      "\"dow_ep\":%.8f,\"dow_projected\":%.8f},"
      "\"blink_action\":\"%s\",\"blink_confirmed\":%s}",
      sym, tf, close,
      close, ema9, ema21, ema50, rsi, atr,
      (g_smcGomVerdictNum == 0 ? "true" : "false"),
      SMCGP_JsonEscape(g_smcGomVerdict), g_smcGomVerdictNum,
      (g_smcGomConnected ? "true" : "false"),
      g_cachedBestBuyLevel, g_cachedBestSellLevel,
      g_dowState.currentEpPrice, g_dowState.projectedPrice,
      SMCGP_JsonEscape(g_signalActiveAction),
      (IsSignalConfirmed() ? "true" : "false"));

   char post[], result[];
   StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   string url = SMCGP_ActiveServerURL() + "/ml/chart-opportunity-scan";
   string headers = "Content-Type: application/json\r\n";
   string respH;
   int code = WebRequest("POST", url, headers, AI_Timeout_ms, post, result, respH);
   if(code != 200 && code != 201) return;

   string resp = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(StringFind(resp, "\"ok\":true") < 0 && StringFind(resp, "\"ok\": true") < 0) return;

   string action = SMCGP_JsonString(resp, "action");
   StringToUpper(action);
   g_chartEyesAction = action;
   g_chartEyesConfidence = SMCGP_JsonDouble(resp, "confidence", 0.0);
   g_chartEyesExecuteReady = SMCGP_JsonBool(resp, "execution_ready");
   g_chartEyesOpportunity = SMCGP_JsonString(resp, "best_opportunity");

   if(g_chartEyesExecuteReady && (action == "BUY" || action == "SELL"))
   {
      static datetime s_lastLog = 0;
      if(TimeCurrent() - s_lastLog >= 30)
      {
         s_lastLog = TimeCurrent();
         Print("[CHART-EYES] ", action, " prêt | conf=", DoubleToString(g_chartEyesConfidence * 100, 1),
               "% | opp=", g_chartEyesOpportunity, " | GOM vn=", g_smcGomVerdictNum);
      }
   }
}

// Exécution opportunité scannée (DOW EP / SMC zone) si GOM PERFECT + blink confirmé
bool SMCCE_TryExecuteChartOpportunity()
{
   if(!UseChartEyes || !g_chartEyesExecuteReady) return false;
   if(g_smcGomVerdictNum == 0) return false;
   if(!IsSignalConfirmed()) return false;

   int wantDir = (g_chartEyesAction == "BUY") ? 1 : ((g_chartEyesAction == "SELL") ? -1 : 0);
   if(wantDir == 0 || GetConfirmedSignalDir() != wantDir) return false;
   if(MathAbs(g_smcGomVerdictNum) < 3) return false;
   if((wantDir > 0 && g_smcGomVerdictNum < 3) || (wantDir < 0 && g_smcGomVerdictNum > -3)) return false;
   if(CountPositionsForSymbol(_Symbol) > 0) return false;

   string direction = g_chartEyesAction;
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction)) return false;

   string src = g_chartEyesOpportunity;
   if(StringFind(src, "ZONE") >= 0 || StringFind(src, "DOW") >= 0)
   {
      if(PlaceGOMMarketOrder(direction, "GOM_CHARTEYES", src))
      {
         Print("[CHART-EYES] MARKET ", direction, " exécuté via ", src,
               " | conf=", DoubleToString(g_chartEyesConfidence * 100, 1), "%");
         g_chartEyesExecuteReady = false;
         return true;
      }
   }
   return false;
}

#endif
