//+------------------------------------------------------------------+
//|                                     BoomCrash_Strategy_Bot.mq5 |
//|         Stratégie Boom/Crash avec synthèse Render + détection spike |
//|  IMPORTANT: Dans MT5, Outils -> Options -> Expert Advisors ->     |
//|  "Autoriser WebRequest pour les URL listées" : ajouter             |
//|  https://kolatradebot.onrender.com                                 |
//+------------------------------------------------------------------+
#property copyright "Conçu comme un exemple éducatif"
#property link      "https://www.example.com"
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Stratégie de Trading
input group             "Stratégie de Trading"
input int               MA_Period = 100;                // Période de la Moyenne Mobile
input ENUM_MA_METHOD    MA_Method = MODE_SMA;          // Méthode MA (Simple, Exponentielle...)
input int               RSI_Period = 14;               // Période du RSI
input double            RSI_Overbought_Level = 65.0;   // RSI surachat (vente / repli)
input double            RSI_Oversold_Level = 35.0;     // RSI survente (achat / rebond)
input int               ModeOuverture = 2;             // 0=Strict 1=+Spike 2=Classique seul (max trades)
input bool              TradeBothDirections = true;    // true = acheter sur survente ET vendre sur surachat
input bool              RSIOnlyReverse = true;         // sens inverse sur RSI seul (pas de filtre MA) = plus d'ouvertures

//--- Détection SPIKE locale (optionnel - mode 2 l'ignore)
input group             "Détection Spike locale"
input bool              UseSpikeDetection = false;     // Désactivé par défaut pour laisser le robot trader
input int               ATR_Period = 14;               // Période ATR pour volatilité
input double            MinATRExpansionRatio = 1.15;   // ATR actuel / ATR moyen > ce ratio = spike volatilité
input int               ATR_AverageBars = 20;          // Barres pour moyenne ATR
input double            MinCandleBodyATR = 0.35;      // Corps bougie / ATR min (grosse bougie = spike)
input double            MinRSISpike = 25.0;            // RSI extrême pour Crash (plus bas = spike)
input double            MaxRSISpike = 75.0;            // RSI extrême pour Boom (plus haut = spike)

//--- API Render (synthèse des analyses - comme F_INX_scalper_double)
input group             "API Render (synthèse)"
input bool              UseRenderAPI = true;           // Utiliser les endpoints Render pour la décision
input string            AI_ServerURL = "https://kolatradebot.onrender.com/decision"; // Décision IA
input string            TrendAPIURL = "https://kolatradebot.onrender.com/trend";    // Tendance
input string            AI_PredictURL = "https://kolatradebot.onrender.com/predict"; // Prédiction par symbole
input int               AI_Timeout_ms = 10000;         // Timeout WebRequest (ms)
input int               AI_UpdateInterval_sec = 8;     // Rafraîchir l'API toutes les N secondes
input double            MinAPIConfidence = 0.40;      // Confiance minimale API (0-1) - baisser si pas d'ouvertures
input bool              RequireTrendAlignment = false;  // Exiger tendance API alignée (désactivé = plus d'ouvertures)
input bool              RequireAPIToOpen = false;       // Si false: ouvrir avec Classique+Spike même sans accord API

//--- Gestion du Risque (en Pips/Points)
input group             "Gestion du Risque (en Pips)"
input double            LotSize = 0.2;                 // Taille du lot fixe
input int               StopLoss_Pips = 0;              // Stop Loss en pips (DÉSACTIVÉ)
input int               TakeProfit_Pips = 0;            // Take Profit en pips (DÉSACTIVÉ)

input group             "Fermeture après spike (réaliser le gain)"
input bool              CloseOnSpikeProfit = true;     // Fermer la position quand le spike a donné ce profit
input double            SpikeProfitClose_USD = 0.50;   // Fermer quand profit >= ce montant (USD)

input group             "Gestion des Pertes"
input bool              CloseOnMaxLoss = true;         // Fermer après perte maximale
input double            MaxLoss_USD = 3.0;            // Fermer quand perte >= ce montant (USD)

input group             "Trailing Stop"
input bool              UseTrailingStop = true;         // Activer le Trailing Stop
input int               TrailingStop_Pips = 5000;       // Distance du Trailing Stop en pips

input group             "Identification du Robot"
input long              MagicNumber = 12345;           // Numéro magique
input bool              DebugLog = true;               // Afficher raison des non-ouvertures (toutes les 20 s)

//--- Variables globales
CTrade      trade;

//+------------------------------------------------------------------+
//| Calcule SL/TP valides (respecte STOPS_LEVEL et bon sens)         |
//+------------------------------------------------------------------+
void NormalizeSLTP(bool isBuy, double entry, double& sl, double& tp)
{
   // Si SL/TP sont désactivés, mettre à 0 directement
   if(StopLoss_Pips == 0 && TakeProfit_Pips == 0)
   {
      sl = 0;
      tp = 0;
      return;
   }
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (stopsLevel > 0) ? (stopsLevel * point) : (10 * point);

   double slDist = MathMax(StopLoss_Pips * point, minDist);
   double tpDist = MathMax(TakeProfit_Pips * point, minDist);

   if(isBuy)
   {
      sl = NormalizeDouble(entry - slDist, digits);
      tp = NormalizeDouble(entry + tpDist, digits);
      if(sl >= entry - minDist) sl = NormalizeDouble(entry - minDist - point, digits);
      if(tp <= entry + minDist) tp = NormalizeDouble(entry + minDist + point, digits);
   }
   else
   {
      sl = NormalizeDouble(entry + slDist, digits);
      tp = NormalizeDouble(entry - tpDist, digits);
      if(sl <= entry + minDist) sl = NormalizeDouble(entry + minDist + point, digits);
      if(tp >= entry - minDist) tp = NormalizeDouble(entry - minDist - point, digits);
   }
}

//--- Variables globales (suite)
int         ma_handle;
int         rsi_handle;
int         atr_handle;                   // ATR pour détection spike
MqlTick     last_tick;
double      pip_value;

// État API Render (synthèse)
string      g_lastAIAction = "";          // "buy", "sell", "hold"
double      g_lastAIConfidence = 0.0;
int         g_api_trend_direction = 0;     // 1=BUY, -1=SELL, 0=neutre
double      g_api_trend_confidence = 0.0;
bool        g_api_trend_valid = false;
datetime    g_lastAPIUpdate = 0;

//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'Expert Advisor                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialisation de l'objet de trading
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);

   //--- Création des handles pour les indicateurs
   ma_handle = iMA(_Symbol, _Period, MA_Period, 0, MA_Method, PRICE_CLOSE);
   if(ma_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du handle de la Moyenne Mobile.");
      return(INIT_FAILED);
   }

   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du handle du RSI.");
      return(INIT_FAILED);
   }

   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du handle ATR.");
      return(INIT_FAILED);
   }
   
   pip_value = _Point * pow(10, _Digits % 2);

   if(UseRenderAPI && StringLen(AI_ServerURL) > 0)
      Print("Robot initialisé. API Render activée. Détection spike: ", UseSpikeDetection ? "OUI" : "NON");
   else
      Print("Robot initialisé. Mode local uniquement.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ma_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);
   Print("Robot désinitialisé.");
}

//+------------------------------------------------------------------+
//| Fonction principale, exécutée à chaque nouveau tick              |
//+------------------------------------------------------------------+
void OnTick()
{
   ulong ticket = GetMyPositionTicket();
   if(ticket != 0 && PositionSelectByTicket(ticket))
   {
      ManageTrailingStop(ticket);
      return;
   }

   // Rafraîchir la synthèse Render à l'intervalle défini
   if(UseRenderAPI && (TimeCurrent() - g_lastAPIUpdate >= AI_UpdateInterval_sec))
   {
      UpdateRenderDecision();
      UpdateTrendAPI();
      g_lastAPIUpdate = TimeCurrent();
   }

   double ma_value[1], rsi_value[1], close_price[1];
   if(CopyBuffer(ma_handle, 0, 1, 1, ma_value) <= 0 ||
      CopyBuffer(rsi_handle, 0, 1, 1, rsi_value) <= 0 ||
      CopyClose(_Symbol, _Period, 1, 1, close_price) <= 0)
      return;

   SymbolInfoTick(_Symbol, last_tick);
   double ask = last_tick.ask;
   double bid = last_tick.bid;
   double price = close_price[0];

   bool apiOkBuy  = (g_lastAIAction == "buy" && g_lastAIConfidence >= MinAPIConfidence && (!RequireTrendAlignment || g_api_trend_direction >= 0));
   bool apiOkSell = (g_lastAIAction == "sell" && g_lastAIConfidence >= MinAPIConfidence && (!RequireTrendAlignment || g_api_trend_direction <= 0));
   bool apiAllowsBuy  = !UseRenderAPI || !RequireAPIToOpen || apiOkBuy;
   bool apiAllowsSell = !UseRenderAPI || !RequireAPIToOpen || apiOkSell;

   bool requireSpike = (ModeOuverture == 0);
   bool requireAPI    = (ModeOuverture <= 1);

   string symLower = _Symbol;
   StringToLower(symLower);
   bool isCrash = (StringFind(symLower, "crash") >= 0);
   bool isBoom  = (StringFind(symLower, "boom") >= 0);

   //--- CRASH: BUY sur survente (rebond) OU SELL sur surachat (repli) si TradeBothDirections
   if(isCrash)
   {
      bool classicBuy  = (price > ma_value[0] && rsi_value[0] < RSI_Oversold_Level);
      bool classicSell = (price < ma_value[0] && rsi_value[0] > RSI_Overbought_Level);
      bool reverseSell = RSIOnlyReverse && (rsi_value[0] > RSI_Overbought_Level);  // SELL sur RSI surachat seul
      bool spikeOkBuy  = !UseSpikeDetection || IsLocalSpikeCrash(ma_value[0], rsi_value[0]);
      bool spikeOkSell = !UseSpikeDetection || IsLocalSpikeBoom(ma_value[0], rsi_value[0]);
      bool canBuy  = classicBuy  && (!requireSpike || spikeOkBuy)  && (!requireAPI || apiAllowsBuy);
      bool canSell = TradeBothDirections && (classicSell || reverseSell) && (!requireSpike || spikeOkSell) && (!requireAPI || apiAllowsSell);

      if(canBuy)
      {
         double sl = 0, tp = 0;
         NormalizeSLTP(true, ask, sl, tp);
         if(trade.Buy(LotSize, _Symbol, ask, sl, tp, "BoomCrash Crash BUY rebond"))
            Print("✅ CRASH BUY | RSI=", DoubleToString(rsi_value[0],1), " (survente)");
         else
            Print("❌ CRASH BUY échec: ", trade.ResultRetcode());
      }
      else if(canSell)
      {
         double sl = 0, tp = 0;
         NormalizeSLTP(false, bid, sl, tp);
         if(trade.Sell(LotSize, _Symbol, bid, sl, tp, "BoomCrash Crash SELL surachat"))
            Print("✅ CRASH SELL | RSI=", DoubleToString(rsi_value[0],1), " (surachat)");
         else
            Print("❌ CRASH SELL échec: ", trade.ResultRetcode());
      }
      else if(DebugLog) LogNoOpen("Crash", price, ma_value[0], rsi_value[0], classicBuy || classicSell, spikeOkBuy, apiAllowsBuy);
   }
   //--- BOOM: SELL sur surachat (repli) OU BUY sur survente (rebond) si TradeBothDirections
   else if(isBoom)
   {
      bool classicSell = (price < ma_value[0] && rsi_value[0] > RSI_Overbought_Level);
      bool classicBuy  = (price > ma_value[0] && rsi_value[0] < RSI_Oversold_Level);
      bool reverseBuy  = RSIOnlyReverse && (rsi_value[0] < RSI_Oversold_Level);       // BUY sur RSI survente seul
      bool spikeOkSell = !UseSpikeDetection || IsLocalSpikeBoom(ma_value[0], rsi_value[0]);
      bool spikeOkBuy  = !UseSpikeDetection || IsLocalSpikeCrash(ma_value[0], rsi_value[0]);
      bool canSell = classicSell && (!requireSpike || spikeOkSell) && (!requireAPI || apiAllowsSell);
      bool canBuy  = TradeBothDirections && (classicBuy || reverseBuy) && (!requireSpike || spikeOkBuy) && (!requireAPI || apiAllowsBuy);

      if(canSell)
      {
         double sl = 0, tp = 0;
         NormalizeSLTP(false, bid, sl, tp);
         if(trade.Sell(LotSize, _Symbol, bid, sl, tp, "BoomCrash Boom SELL surachat"))
            Print("✅ BOOM SELL | RSI=", DoubleToString(rsi_value[0],1), " (surachat)");
         else
            Print("❌ BOOM SELL échec: ", trade.ResultRetcode());
      }
      else if(canBuy)
      {
         double sl = 0, tp = 0;
         NormalizeSLTP(true, ask, sl, tp);
         if(trade.Buy(LotSize, _Symbol, ask, sl, tp, "BoomCrash Boom BUY rebond"))
            Print("✅ BOOM BUY | RSI=", DoubleToString(rsi_value[0],1), " (survente)");
         else
            Print("❌ BOOM BUY échec: ", trade.ResultRetcode());
      }
      else if(DebugLog) LogNoOpen("Boom", price, ma_value[0], rsi_value[0], classicSell || classicBuy, spikeOkSell, apiAllowsSell);
   }
}

//+------------------------------------------------------------------+
//| Log pourquoi pas d'ouverture (toutes les 20 s max)               |
//+------------------------------------------------------------------+
void LogNoOpen(string type, double price, double ma, double rsi, bool classic, bool spikeOk, bool apiAllows)
{
   static datetime s_lastLog = 0;
   if(TimeCurrent() - s_lastLog < 20) return;
   s_lastLog = TimeCurrent();
   string reason = "";
   if(!classic) reason = "classique KO (prix " + (type == "Crash" ? ">MA?" : "<MA?") + " RSI " + DoubleToString(rsi, 1) + ")";
   else if(!spikeOk) reason = "spike KO";
   else if(!apiAllows) reason = "API KO";
   else reason = "?";
   Print("BoomCrash ", type, " | pas d'ouverture: ", reason, " | prix=", DoubleToString(price, _Digits), " MA=", DoubleToString(ma, _Digits), " RSI=", DoubleToString(rsi, 1));
}

//+------------------------------------------------------------------+
//| Détection spike CRASH (mouvement baissier violent + survente)    |
//+------------------------------------------------------------------+
bool IsLocalSpikeCrash(double ma_val, double rsi_val)
{
   if(rsi_val > MinRSISpike) return false;  // RSI pas assez extrême
   double atr[], open[], close[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   int need = MathMax(ATR_AverageBars + 1, 3);
   if(CopyBuffer(atr_handle, 0, 0, need, atr) < need ||
      CopyOpen(_Symbol, _Period, 0, 3, open) < 3 ||
      CopyClose(_Symbol, _Period, 0, 3, close) < 3)
      return true;  // Données manquantes: on laisse passer la condition classique
   double atrAvg = 0;
   for(int i = 1; i < need; i++) atrAvg += atr[i];
   atrAvg /= (need - 1);
   if(atrAvg <= 0) return true;
   if(atr[0] / atrAvg < MinATRExpansionRatio) return false;  // Pas d'expansion volatilité
   double body = MathAbs(close[0] - open[0]);
   if(body / atr[0] < MinCandleBodyATR) return false;       // Bougie pas assez forte
   return true;
}

//+------------------------------------------------------------------+
//| Détection spike BOOM (mouvement haussier violent + surachat)      |
//+------------------------------------------------------------------+
bool IsLocalSpikeBoom(double ma_val, double rsi_val)
{
   if(rsi_val < MaxRSISpike) return false;
   double atr[], open[], close[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   int need = MathMax(ATR_AverageBars + 1, 3);
   if(CopyBuffer(atr_handle, 0, 0, need, atr) < need ||
      CopyOpen(_Symbol, _Period, 0, 3, open) < 3 ||
      CopyClose(_Symbol, _Period, 0, 3, close) < 3)
      return true;
   double atrAvg = 0;
   for(int i = 1; i < need; i++) atrAvg += atr[i];
   atrAvg /= (need - 1);
   if(atrAvg <= 0) return true;
   if(atr[0] / atrAvg < MinATRExpansionRatio) return false;
   double body = MathAbs(close[0] - open[0]);
   if(body / atr[0] < MinCandleBodyATR) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Mise à jour décision IA (endpoint /decision - comme scalper)      |
//+------------------------------------------------------------------+
void UpdateRenderDecision()
{
   if(StringLen(AI_ServerURL) == 0) return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double rsi[], emaF[], emaS[], atr[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(emaF, true);
   ArraySetAsSeries(emaS, true);
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) <= 0 || CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return;
   int emaFast = iMA(_Symbol, _Period, 20, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlow = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   int emaH1F = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   int emaH1S = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(emaFast == INVALID_HANDLE || emaSlow == INVALID_HANDLE || emaH1F == INVALID_HANDLE || emaH1S == INVALID_HANDLE) return;
   if(CopyBuffer(emaFast, 0, 0, 1, emaF) <= 0 || CopyBuffer(emaSlow, 0, 0, 1, emaS) <= 0) { IndicatorRelease(emaFast); IndicatorRelease(emaSlow); IndicatorRelease(emaH1F); IndicatorRelease(emaH1S); return; }
   double emaH1Fast[], emaH1Slow[];
   ArraySetAsSeries(emaH1Fast, true);
   ArraySetAsSeries(emaH1Slow, true);
   if(CopyBuffer(emaH1F, 0, 0, 1, emaH1Fast) <= 0 || CopyBuffer(emaH1S, 0, 0, 1, emaH1Slow) <= 0)
   { IndicatorRelease(emaFast); IndicatorRelease(emaSlow); IndicatorRelease(emaH1F); IndicatorRelease(emaH1S); return; }
   int dirRule = (emaF[0] > emaS[0]) ? 1 : (emaF[0] < emaS[0]) ? -1 : 0;
   string safeSymbol = _Symbol;
   StringReplace(safeSymbol, "\"", "\\\"");
   string payload = "{";
   payload += "\"symbol\":\"" + safeSymbol + "\"";
   payload += ",\"bid\":" + DoubleToString(bid, _Digits);
   payload += ",\"ask\":" + DoubleToString(ask, _Digits);
   payload += ",\"rsi\":" + DoubleToString(rsi[0], 2);
   payload += ",\"ema_fast_h1\":" + DoubleToString(emaH1Fast[0], _Digits);
   payload += ",\"ema_slow_h1\":" + DoubleToString(emaH1Slow[0], _Digits);
   payload += ",\"ema_fast_m1\":" + DoubleToString(emaF[0], _Digits);
   payload += ",\"ema_slow_m1\":" + DoubleToString(emaS[0], _Digits);
   payload += ",\"atr\":" + DoubleToString(atr[0], _Digits);
   payload += ",\"dir_rule\":" + IntegerToString(dirRule);
   payload += ",\"is_spike_mode\":true";
   payload += "}";
   IndicatorRelease(emaFast); IndicatorRelease(emaSlow); IndicatorRelease(emaH1F); IndicatorRelease(emaH1S);
   uchar data[];
   int len = StringLen(payload);
   ArrayResize(data, len + 1);
   int copied = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(copied <= 0) return;
   ArrayResize(data, copied - 1);
   uchar result[];
   string result_headers = "";
   int res = WebRequest("POST", AI_ServerURL, "Content-Type: application/json\r\n", AI_Timeout_ms, data, result, result_headers);
   if(res < 200 || res >= 300) return;
   string resp = CharArrayToString(result, 0, -1, CP_UTF8);
   ParseDecisionResponse(resp);
}

//+------------------------------------------------------------------+
//| Parse réponse JSON /decision -> action, confidence                |
//+------------------------------------------------------------------+
void ParseDecisionResponse(string resp)
{
   g_lastAIAction = "hold";
   g_lastAIConfidence = 0.0;
   string r = resp;
   StringToLower(r);
   int buyPos = StringFind(r, "\"buy\"");
   int sellPos = StringFind(r, "\"sell\"");
   if(buyPos >= 0 && (sellPos < 0 || buyPos < sellPos)) g_lastAIAction = "buy";
   else if(sellPos >= 0) g_lastAIAction = "sell";
   int confPos = StringFind(resp, "\"confidence\"");
   if(confPos >= 0)
   {
      int col = StringFind(resp, ":", confPos);
      if(col > 0)
      {
         int end = StringFind(resp, ",", col);
         if(end < 0) end = StringFind(resp, "}", col);
         if(end > col)
            g_lastAIConfidence = StringToDouble(StringSubstr(resp, col + 1, end - col - 1));
      }
   }
}

//+------------------------------------------------------------------+
//| Mise à jour API Tendance (GET /trend?symbol=...&timeframe=M1)     |
//+------------------------------------------------------------------+
void UpdateTrendAPI()
{
   if(StringLen(TrendAPIURL) == 0) return;
   string safeSymbol = _Symbol;
   StringReplace(safeSymbol, " ", "%20");
   string url = TrendAPIURL + "?symbol=" + safeSymbol + "&timeframe=M1";
   uchar data[];
   ArrayResize(data, 0);
   uchar result[];
   string result_headers = "";
   int res = WebRequest("GET", url, "Accept: application/json\r\n", AI_Timeout_ms, data, result, result_headers);
   if(res < 200 || res >= 300) { g_api_trend_valid = false; return; }
   ParseTrendResponse(CharArrayToString(result, 0, -1, CP_UTF8));
}

//+------------------------------------------------------------------+
//| Parse réponse API /trend -> direction, confidence                 |
//+------------------------------------------------------------------+
void ParseTrendResponse(string json)
{
   g_api_trend_valid = false;
   g_api_trend_direction = 0;
   g_api_trend_confidence = 0.0;
   int dirPos = StringFind(json, "\"direction\"");
   if(dirPos >= 0)
   {
      int col = StringFind(json, ":", dirPos);
      if(col > 0)
      {
         string part = StringSubstr(json, col + 1, 25);
         StringToUpper(part);
         if(StringFind(part, "BUY") >= 0 || StringFind(part, "1") >= 0) g_api_trend_direction = 1;
         else if(StringFind(part, "SELL") >= 0 || StringFind(part, "-1") >= 0) g_api_trend_direction = -1;
      }
   }
   int confPos = StringFind(json, "\"confidence\"");
   if(confPos >= 0)
   {
      int col = StringFind(json, ":", confPos);
      if(col > 0)
      {
         int end = StringFind(json, ",", col);
         if(end < 0) end = StringFind(json, "}", col);
         if(end > col)
            g_api_trend_confidence = StringToDouble(StringSubstr(json, col + 1, end - col - 1));
      }
   }
   g_api_trend_valid = (g_api_trend_direction != 0 || g_api_trend_confidence > 0);
}

//+------------------------------------------------------------------+
//| Gérer position: fermeture après spike (profit USD) + Trailing Stop |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;

   double profit  = PositionGetDouble(POSITION_PROFIT);
   double swap    = PositionGetDouble(POSITION_SWAP);
   double commission = PositionGetDouble(POSITION_COMMISSION);
   double totalUSD = profit + swap + commission;

   // Fermer après l'arrivée du spike: dès que le profit atteint le seuil
   if(CloseOnSpikeProfit && SpikeProfitClose_USD > 0 && totalUSD >= SpikeProfitClose_USD)
   {
      if(trade.PositionClose(ticket))
         Print("✅ Position fermée après spike | Profit réalisé: ", DoubleToString(totalUSD, 2), " USD");
      return;
   }

   // Fermer après perte maximale: dès que la perte dépasse 3$
   if(CloseOnMaxLoss && MaxLoss_USD > 0 && totalUSD <= -MaxLoss_USD)
   {
      if(trade.PositionClose(ticket))
         Print("❌ Position fermée après perte maximale | Perte: ", DoubleToString(totalUSD, 2), " USD (limite: ", DoubleToString(MaxLoss_USD, 2), " USD)");
      return;
   }

   if(!UseTrailingStop) return;

   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   SymbolInfoTick(_Symbol, last_tick);

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      double new_sl = last_tick.bid - TrailingStop_Pips * _Point;
      if(last_tick.bid > open_price + TrailingStop_Pips * _Point && new_sl > current_sl)
         trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      double new_sl = last_tick.ask + TrailingStop_Pips * _Point;
      if(last_tick.ask < open_price - TrailingStop_Pips * _Point && (new_sl < current_sl || current_sl == 0))
         trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
   }
}

//+------------------------------------------------------------------+
//| Fonction pour obtenir le ticket de notre position                |
//+------------------------------------------------------------------+
ulong GetMyPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         return PositionGetTicket(i);
      }
   }
   return 0;
}
//+------------------------------------------------------------------+
