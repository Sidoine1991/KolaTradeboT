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

//--- Affichage Graphique et Signaux
input group             "Affichage Graphique"
input bool              ShowMA = true;                     // Afficher MA mobile
input bool              ShowRSI = true;                    // Afficher RSI
input bool              ShowSignals = true;                 // Afficher signaux d'entrée
input bool              ShowPredictions = true;             // Afficher prédictions sur 100 bougies
input bool              ShowSpikeArrows = true;            // Afficher flèches de spike clignotantes
input color             MA_Color = clrBlue;                // Couleur MA
input color             RSI_Color_Up = clrGreen;           // Couleur RSI survente
input color             RSI_Color_Down = clrRed;         // Couleur RSI surachat
input color             BuySignalColor = clrLime;          // Couleur signal BUY
input color             SellSignalColor = clrRed;          // Couleur signal SELL
input color             SpikeArrowColor = clrYellow;        // Couleur flèche spike

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

//--- Handles pour indicateurs
int         ma_handle;
int         rsi_handle;
int         atr_handle;
int         emaFastM1_handle;    // EMA rapide M1
int         emaSlowM1_handle;    // EMA lent M1
int         emaFastM5_handle;    // EMA rapide M5
int         emaSlowM5_handle;    // EMA lent M5
int         emaFastH1_handle;    // EMA rapide H1
int         emaSlowH1_handle;    // EMA lent H1

//--- Variables pour prédictions et affichage
double      price_predictions[100]; // Prédictions sur 100 bougies
int         prediction_index = 0;
datetime    last_prediction_update = 0;
string      spike_arrow_name = "";
datetime    spike_arrow_time = 0;
bool        spike_arrow_blink = false;
int         spike_blink_counter = 0;

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

   // Initialiser les EMA rapides pour M1, M5, H1
   emaFastM1_handle = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM1_handle = iMA(_Symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM5_handle = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5_handle = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   emaFastH1_handle = iMA(_Symbol, PERIOD_H1, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowH1_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   if(emaFastM1_handle == INVALID_HANDLE || emaSlowM1_handle == INVALID_HANDLE ||
      emaFastM5_handle == INVALID_HANDLE || emaSlowM5_handle == INVALID_HANDLE ||
      emaFastH1_handle == INVALID_HANDLE || emaSlowH1_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création des handles EMA.");
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
   IndicatorRelease(emaFastM1_handle);
   IndicatorRelease(emaSlowM1_handle);
   IndicatorRelease(emaFastM5_handle);
   IndicatorRelease(emaSlowM5_handle);
   IndicatorRelease(emaFastH1_handle);
   IndicatorRelease(emaSlowH1_handle);
   CleanChartObjects();
   Print("Robot désinitialisé.");
}

//+------------------------------------------------------------------+
//| Fonction principale, exécutée à chaque nouveau tick              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Mettre à jour les indicateurs
   double ma_value[1], rsi_value[1], close_price[1];
   double emaFastM1[1], emaSlowM1[1], emaFastM5[1], emaSlowM5[1], emaFastH1[1], emaSlowH1[1];
   
   if(CopyBuffer(ma_handle, 0, 1, 1, ma_value) <= 0 ||
      CopyBuffer(rsi_handle, 0, 1, 1, rsi_value) <= 0 ||
      CopyBuffer(emaFastM1_handle, 0, 0, 1, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowM1_handle, 0, 0, 1, emaSlowM1) <= 0 ||
      CopyBuffer(emaFastM5_handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5_handle, 0, 0, 1, emaSlowM5) <= 0 ||
      CopyBuffer(emaFastH1_handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1_handle, 0, 0, 1, emaSlowH1) <= 0 ||
      CopyClose(_Symbol, _Period, 1, 1, close_price) <= 0)
      return;
   
   SymbolInfoTick(_Symbol, last_tick);
   double ask = last_tick.ask;
   double bid = last_tick.bid;
   double price = close_price[0];
   
   // Mettre à jour les signaux IA (tous les endpoints)
   UpdateFromDecision();
   UpdateFromPredict();
   UpdateFromTrendAnalysis();
   
   // Afficher les indicateurs graphiques
   UpdateGraphics();
   
   // Gérer les positions existantes
   ManagePositions();
   
   // Ouvrir nouvelles positions selon signaux IA et EMA rapides
   OpenNewPositions();
}

//+------------------------------------------------------------------+
//| Ouvrir de nouvelles positions                                      |
//+------------------------------------------------------------------+
void OpenNewPositions()
{
   if(PositionsTotal() > 0) return; // Une position à la fois
   
   SymbolInfoTick(_Symbol, last_tick);
   double ask = last_tick.ask;
   double bid = last_tick.bid;
   double price = bid;
   
   if(ArraySize(ma_buffer) < 1 || ArraySize(rsi_buffer) < 1 ||
      ArraySize(emaFastM1) < 1 || ArraySize(emaSlowM1) < 1 ||
      ArraySize(emaFastM5) < 1 || ArraySize(emaSlowM5) < 1 ||
      ArraySize(emaFastH1) < 1 || ArraySize(emaSlowH1) < 1)
      return;
   
   double ma_value = ma_buffer[0];
   double rsi_value = rsi_buffer[0];
   double emaFastM1 = emaFastM1[0];
   double emaSlowM1 = emaSlowM1[0];
   double emaFastM5 = emaFastM5[0];
   double emaSlowM5 = emaSlowM5[0];
   double emaFastH1 = emaFastH1[0];
   double emaSlowH1 = emaSlowH1[0];
   
   // Vérifier le type de symbole
   bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
   bool is_crash = (StringFind(_Symbol, "Crash") >= 0);
   
   // Signaux techniques basés sur EMA rapides M1
   bool tech_buy_m1 = (price > emaFastM1 && rsi_value < RSI_Oversold_Level);
   bool tech_sell_m1 = (price < emaFastM1 && rsi_value > RSI_Overbought_Level);
   
   // Alignement des tendances M5/M1 (OBLIGATOIRE)
   bool trend_alignment_buy = (emaFastM1 > emaSlowM1) && (emaFastM5 > emaSlowM5);
   bool trend_alignment_sell = (emaFastM1 < emaSlowM1) && (emaFastM5 < emaSlowM5);
   
   // Signaux IA
   bool ai_buy = (current_ai_signal.action == "BUY" && current_ai_signal.confidence > 0.5);
   bool ai_sell = (current_ai_signal.action == "SELL" && current_ai_signal.confidence > 0.5);
   
   // Logique d'ouverture COMPLÈTE
   if(is_boom)
   {
      // Boom: seulement BUY avec conditions strictes
      if(tech_buy_m1 && trend_alignment_buy && ai_buy)
      {
         if(trade.Buy(LotSize, _Symbol, ask, 0, 0, "BoomCrash Boom BUY (EMA M1 + Alignement M5/M1 + IA)"))
         {
            Print(" BOOM BUY OUVERT - Signal technique EMA M1 + Alignement M5/M1 + IA FORTE");
            CreateSpikeArrow(); // Flèche de spike
         }
      }
   }
   else if(is_crash)
   {
      // Crash: seulement SELL avec conditions strictes
      if(tech_sell_m1 && trend_alignment_sell && ai_sell)
      {
         if(trade.Sell(LotSize, _Symbol, bid, 0, 0, "BoomCrash Crash SELL (EMA M1 + Alignement M5/M1 + IA FORTE)"))
         {
            Print(" CRASH SELL OUVERT - Signal technique EMA M1 + Alignement M5/M1 + IA FORTE");
            CreateSpikeArrow(); // Flèche de spike
         }
      }
   }
   
   if(DebugLog && !((is_boom && tech_buy_m1 && trend_alignment_buy && ai_buy) || 
                    (is_crash && tech_sell_m1 && trend_alignment_sell && ai_sell)))
   {
      Print("BoomCrash ", _Symbol, " | pas d'ouverture:");
      if(is_boom)
         Print("  - EMA M1 BUY: ", (price > emaFastM1 ? "" : ""),
               " | Alignement M5/M1: ", (trend_alignment_buy ? "" : ""),
               " | IA BUY: ", (ai_buy ? "" : ""));
      else
         Print("  - EMA M1 SELL: ", (price < emaFastM1 ? "" : ""),
               " | Alignement M5/M1: ", (trend_alignment_sell ? "" : ""),
               " | IA SELL: ", (ai_sell ? "" : ""));
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
//| Structure pour les signaux IA                                     |
//+------------------------------------------------------------------+
struct AISignal
{
    string   action;        // BUY/SELL/HOLD
    double   confidence;     // Confiance 0-1
    string   reason;        // Raison du signal
    double   prediction;     // Prédiction de prix
    datetime timestamp;     // Timestamp du signal
};

AISignal current_ai_signal;

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /decision                             |
//+------------------------------------------------------------------+
void UpdateFromDecision()
{
    string url = AI_ServerURL;
    string data = "{\"symbol\":\"" + _Symbol + "\",\"bid\":" + 
                 DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), 5) + 
                 ",\"ask\":" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 5) + "}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", url, headers, AI_Timeout_ms, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParseAIResponse(response);
    }
    else if(DebugLog)
    {
        Print("⚠️ Erreur /decision: ", res);
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /predict                              |
//+------------------------------------------------------------------+
void UpdateFromPredict()
{
    string url = AI_PredictURL;
    string data = "{\"symbol\":\"" + _Symbol + "\",\"bars\":100}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", url, headers, AI_Timeout_ms, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParsePredictResponse(response);
        last_prediction_update = TimeCurrent();
    }
    else if(DebugLog)
    {
        Print("⚠️ Erreur /predict: ", res);
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /trend-analysis                        |
//+------------------------------------------------------------------+
void UpdateFromTrendAnalysis()
{
    string url = TrendAPIURL;
    string data = "{\"symbol\":\"" + _Symbol + "\"}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", url, headers, AI_Timeout_ms, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParseTrendResponse(response);
    }
    else if(DebugLog)
    {
        Print("⚠️ Erreur /trend-analysis: ", res);
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse IA                                             |
//+------------------------------------------------------------------+
void ParseAIResponse(string response)
{
    // Parser simple pour extraire action, confidence, reason
    int action_pos = StringFind(response, "\"action\"");
    if(action_pos >= 0)
    {
        int colon_pos = StringFind(response, ":", action_pos);
        int quote_start = StringFind(response, "\"", colon_pos);
        int quote_end = StringFind(response, "\"", quote_start + 1);
        
        if(quote_end > quote_start)
        {
            current_ai_signal.action = StringSubstr(response, quote_start + 1, quote_end - quote_start - 1);
        }
    }
    
    // Parser confiance
    int conf_pos = StringFind(response, "\"confidence\"");
    if(conf_pos >= 0)
    {
        int colon_conf = StringFind(response, ":", conf_pos);
        int conf_end = StringFind(response, ",", colon_conf);
        if(conf_end < 0) conf_end = StringFind(response, "}", colon_conf);
        
        if(conf_end > colon_conf)
        {
            string conf_str = StringSubstr(response, colon_conf + 1, conf_end - colon_conf - 1);
            current_ai_signal.confidence = StringToDouble(conf_str);
        }
    }
    
    current_ai_signal.timestamp = TimeCurrent();
    
    if(DebugLog)
    {
        Print("🤖 Signal IA reçu: ", current_ai_signal.action, 
              " | Confiance: ", DoubleToString(current_ai_signal.confidence * 100, 1), "%",
              " | Raison: ", current_ai_signal.reason);
    }
}

//+------------------------------------------------------------------+
//| Parser les prédictions                                             |
//+------------------------------------------------------------------+
void ParsePredictResponse(string response)
{
    // Parser pour extraire les prédictions sur 100 bougies
    int pred_pos = StringFind(response, "\"predictions\"");
    if(pred_pos >= 0)
    {
        // Extraire le tableau de prédictions
        int start = StringFind(response, "[", pred_pos);
        int end = StringFind(response, "]", start);
        
        if(end > start)
        {
            string pred_str = StringSubstr(response, start + 1, end - start - 1);
            // Parser les valeurs séparées par virgules
            string values[];
            StringSplit(pred_str, ',', values);
            
            for(int i = 0; i < MathMin(100, ArraySize(values)); i++)
            {
                price_predictions[i] = StringToDouble(values[i]);
            }
            prediction_index = 0;
            
            if(DebugLog)
            {
                Print("📊 Prédictions reçues: ", ArraySize(values), " valeurs");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse tendance                                         |
//+------------------------------------------------------------------+
void ParseTrendResponse(string response)
{
    // Parser les informations de tendance
    if(StringFind(response, "\"trend\":\"up\"") >= 0)
    {
        if(DebugLog) Print("📈 Tendance: HAUSSIÈRE");
    }
    else if(StringFind(response, "\"trend\":\"down\"") >= 0)
    {
        if(DebugLog) Print("📉 Tendance: BAISSIÈRE");
    }
}

//+------------------------------------------------------------------+
//| Afficher les indicateurs graphiques                                 |
//+------------------------------------------------------------------+
void UpdateGraphics()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Afficher MA mobile classique
    if(ShowMA && ArraySize(ma_buffer) > 0)
    {
        string ma_name = "BoomCrash_MA_" + IntegerToString(MA_Period);
        ObjectCreate(0, ma_name, OBJ_HLINE, 0, 0, ma_buffer[0]);
        ObjectSetInteger(0, ma_name, OBJPROP_COLOR, MA_Color);
        ObjectSetInteger(0, ma_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ma_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ma_name, OBJPROP_TOOLTIP, "MA Classique");
    }
    
    // Afficher EMA rapides M1
    if(ShowMA && ArraySize(emaFastM1) > 0 && ArraySize(emaSlowM1) > 0)
    {
        string ema_fast_m1_name = "BoomCrash_EMA_Fast_M1";
        string ema_slow_m1_name = "BoomCrash_EMA_Slow_M1";
        
        ObjectCreate(0, ema_fast_m1_name, OBJ_HLINE, 0, 0, emaFastM1[0]);
        ObjectSetInteger(0, ema_fast_m1_name, OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, ema_fast_m1_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ema_fast_m1_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ema_fast_m1_name, OBJPROP_TOOLTIP, "EMA Rapide M1");
        
        ObjectCreate(0, ema_slow_m1_name, OBJ_HLINE, 0, 0, emaSlowM1[0]);
        ObjectSetInteger(0, ema_slow_m1_name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, ema_slow_m1_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ema_slow_m1_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ema_slow_m1_name, OBJPROP_TOOLTIP, "EMA Lent M1");
    }
    
    // Afficher EMA rapides M5
    if(ShowMA && ArraySize(emaFastM5) > 0 && ArraySize(emaSlowM5) > 0)
    {
        string ema_fast_m5_name = "BoomCrash_EMA_Fast_M5";
        string ema_slow_m5_name = "BoomCrash_EMA_Slow_M5";
        
        ObjectCreate(0, ema_fast_m5_name, OBJ_HLINE, 0, 0, emaFastM5[0]);
        ObjectSetInteger(0, ema_fast_m5_name, OBJPROP_COLOR, clrLime);
        ObjectSetInteger(0, ema_fast_m5_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ema_fast_m5_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ema_fast_m5_name, OBJPROP_TOOLTIP, "EMA Rapide M5");
        
        ObjectCreate(0, ema_slow_m5_name, OBJ_HLINE, 0, 0, emaSlowM5[0]);
        ObjectSetInteger(0, ema_slow_m5_name, OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, ema_slow_m5_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ema_slow_m5_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ema_slow_m5_name, OBJPROP_TOOLTIP, "EMA Lent M5");
    }
    
    // Afficher EMA rapides H1
    if(ShowMA && ArraySize(emaFastH1) > 0 && ArraySize(emaSlowH1) > 0)
    {
        string ema_fast_h1_name = "BoomCrash_EMA_Fast_H1";
        string ema_slow_h1_name = "BoomCrash_EMA_Slow_H1";
        
        ObjectCreate(0, ema_fast_h1_name, OBJ_HLINE, 0, 0, emaFastH1[0]);
        ObjectSetInteger(0, ema_fast_h1_name, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, ema_fast_h1_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ema_fast_h1_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ema_fast_h1_name, OBJPROP_TOOLTIP, "EMA Rapide H1");
        
        ObjectCreate(0, ema_slow_h1_name, OBJ_HLINE, 0, 0, emaSlowH1[0]);
        ObjectSetInteger(0, ema_slow_h1_name, OBJPROP_COLOR, clrPurple);
        ObjectSetInteger(0, ema_slow_h1_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ema_slow_h1_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ema_slow_h1_name, OBJPROP_TOOLTIP, "EMA Lent H1");
    }
    
    // Afficher RSI
    if(ShowRSI && ArraySize(rsi_buffer) > 0)
    {
        string rsi_name = "BoomCrash_RSI_" + IntegerToString(RSI_Period);
        color rsi_color = (rsi_buffer[0] < RSI_Oversold_Level) ? RSI_Color_Up : 
                        (rsi_buffer[0] > RSI_Overbought_Level) ? RSI_Color_Down : clrGray;
        
        ObjectCreate(0, rsi_name, OBJ_TEXT, 0, 0, 0);
        ObjectSetString(0, rsi_name, OBJPROP_TEXT, "RSI: " + DoubleToString(rsi_buffer[0], 1));
        ObjectSetInteger(0, rsi_name, OBJPROP_COLOR, rsi_color);
        ObjectSetInteger(0, rsi_name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, rsi_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetString(0, rsi_name, OBJPROP_TOOLTIP, "RSI: " + DoubleToString(rsi_buffer[0], 1) + 
            " | Survente: " + DoubleToString(RSI_Oversold_Level, 1) + 
            " | Surachat: " + DoubleToString(RSI_Overbought_Level, 1));
    }
    
    // Afficher les signaux d'entrée
    if(ShowSignals)
    {
        DisplayTradeSignals();
    }
    
    // Mettre à jour la flèche de spike clignotante
    UpdateSpikeArrow();
}

//+------------------------------------------------------------------+
//| Afficher les signaux de trading                                   |
//+------------------------------------------------------------------+
void DisplayTradeSignals()
{
    if(ArraySize(ma_buffer) < 2 || ArraySize(rsi_buffer) < 1)
        return;
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ma_value = ma_buffer[0];
    double rsi_value = rsi_buffer[0];
    
    // Signaux d'achat
    bool buy_signal = (current_price > ma_value && rsi_value < RSI_Oversold_Level);
    if(buy_signal && current_ai_signal.action == "BUY" && current_ai_signal.confidence > 0.5)
    {
        string buy_arrow = "BoomCrash_BUY_" + IntegerToString((int)TimeCurrent());
        ObjectCreate(0, buy_arrow, OBJ_ARROW_UP, 0, TimeCurrent(), current_price);
        ObjectSetInteger(0, buy_arrow, OBJPROP_COLOR, BuySignalColor);
        ObjectSetInteger(0, buy_arrow, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, buy_arrow, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
        ObjectSetString(0, buy_arrow, OBJPROP_TEXT, "BUY");
    }
    
    // Signaux de vente
    bool sell_signal = (current_price < ma_value && rsi_value > RSI_Overbought_Level);
    if(sell_signal && current_ai_signal.action == "SELL" && current_ai_signal.confidence > 0.5)
    {
        string sell_arrow = "BoomCrash_SELL_" + IntegerToString((int)TimeCurrent());
        ObjectCreate(0, sell_arrow, OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price);
        ObjectSetInteger(0, sell_arrow, OBJPROP_COLOR, SellSignalColor);
        ObjectSetInteger(0, sell_arrow, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, sell_arrow, OBJPROP_ANCHOR, ANCHOR_TOP);
        ObjectSetString(0, sell_arrow, OBJPROP_TEXT, "SELL");
    }
}

//+------------------------------------------------------------------+
//| Afficher les prédictions sur 100 bougies                           |
//+------------------------------------------------------------------+
void UpdatePredictions()
{
    if(!ShowPredictions || ArraySize(price_predictions) < 10)
        return;
    
    // Afficher les prédictions futures
    for(int i = 0; i < 10; i++) // Afficher 10 prochaines bougies
    {
        if(i >= ArraySize(price_predictions)) break;
        
        datetime future_time = TimeCurrent() + (i + 1) * PeriodSeconds();
        double pred_price = price_predictions[prediction_index + i];
        
        string pred_line = "BoomCrash_PRED_" + IntegerToString(i);
        ObjectCreate(0, pred_line, OBJ_TREND, 0, TimeCurrent(), price_predictions[prediction_index], 
                   future_time, pred_price);
        
        // Couleur selon la direction
        if(pred_price > price_predictions[prediction_index])
            ObjectSetInteger(0, pred_line, OBJPROP_COLOR, clrGreen);
        else
            ObjectSetInteger(0, pred_line, OBJPROP_COLOR, clrRed);
            
        ObjectSetInteger(0, pred_line, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, pred_line, OBJPROP_STYLE, STYLE_DOT);
    }
}

//+------------------------------------------------------------------+
//| Créer une flèche de spike clignotante                          |
//+------------------------------------------------------------------+
void CreateSpikeArrow()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    spike_arrow_name = "BoomCrash_SPIKE_" + IntegerToString((int)TimeCurrent());
    spike_arrow_time = TimeCurrent();
    spike_arrow_blink = true;
    spike_blink_counter = 0;
    
    ObjectCreate(0, spike_arrow_name, OBJ_ARROW_UP, 0, spike_arrow_time, current_price);
    ObjectSetInteger(0, spike_arrow_name, OBJPROP_COLOR, SpikeArrowColor);
    ObjectSetInteger(0, spike_arrow_name, OBJPROP_WIDTH, 5);
    ObjectSetInteger(0, spike_arrow_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    ObjectSetString(0, spike_arrow_name, OBJPROP_TEXT, "🚨 SPIKE");
    
    Print("🚨 FLÈCHE DE SPIKE CRÉÉE - Clignotement activé");
}

//+------------------------------------------------------------------+
//| Gérer le clignotement de la flèche de spike                        |
//+------------------------------------------------------------------+
void UpdateSpikeArrow()
{
    if(!spike_arrow_blink || spike_arrow_name == "")
        return;
    
    datetime current_time = TimeCurrent();
    spike_blink_counter++;
    
    // Clignoter toutes les secondes
    if(current_time - spike_arrow_time >= 1)
    {
        color new_color = (spike_blink_counter % 2 == 0) ? SpikeArrowColor : clrOrange;
        ObjectSetInteger(0, spike_arrow_name, OBJPROP_COLOR, new_color);
        spike_arrow_time = current_time;
    }
    
    // Supprimer après 30 secondes
    if(current_time - ObjectGetInteger(0, spike_arrow_name, OBJPROP_TIME) >= 30)
    {
        ObjectDelete(0, spike_arrow_name);
        spike_arrow_name = "";
        spike_arrow_blink = false;
        spike_blink_counter = 0;
    }
}

//+------------------------------------------------------------------+
//| Nettoyer les objets graphiques                                   |
//+------------------------------------------------------------------+
void CleanChartObjects()
{
    for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i, -1, -1);
        if(StringFind(obj_name, "BoomCrash_") >= 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
}
//+------------------------------------------------------------------+
