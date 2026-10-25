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
input string            AI_ServerURL = "https://kolatradebot.onrender.com/decision"; // Décision IA (fonctionne)
input string            TrendAPIURL = "";    // Désactivé (404)
input string            AI_PredictURL = ""; // Désactivé (404)
input int               AI_Timeout_ms = 10000;         // Timeout WebRequest (ms)
input int               AI_UpdateInterval_sec = 30;     // Rafraîchir l'API toutes les N secondes (augmenté pour réduire spam)
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
input bool              ShowDashboard = true;                // Tableau de bord (infos, alertes spike, entrées, durée)
input int               DashboardRefresh_sec = 5;            // Rafraîchir tableau de bord (sec) - 5 = moins de charge CPU
input int               GraphicsRefresh_sec = 5;             // Rafraîchir graphiques MA/RSI (sec) - 5 = moins de charge CPU

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

//--- EMA rapides pour M1, M5, H1
int         emaFastM1_handle;
int         emaSlowM1_handle;
int         emaFastM5_handle;
int         emaSlowM5_handle;
int         emaFastH1_handle;
int         emaSlowH1_handle;

//--- Variables pour les buffers
double      ma_buffer[];
double      rsi_buffer[];
double      atr_buffer[];
double      emaFastM1_buffer[];
double      emaSlowM1_buffer[];
double      emaFastM5_buffer[];
double      emaSlowM5_buffer[];
double      emaFastH1_buffer[];
double      emaSlowH1_buffer[];

//--- Variables globales
MqlTick     last_tick;
double      pip_value;

//--- Variables pour les signaux IA
datetime    g_lastAPIUpdate = 0;
string      g_lastAIAction = "";
double      g_lastAIConfidence = 0.0;
int         g_api_trend_direction = 0;
double      g_api_trend_confidence = 0.0;
bool        g_api_trend_valid = false;

//--- Structure pour les signaux IA
struct AISignal
{
    string   action;        // BUY/SELL/HOLD
    double   confidence;     // Confiance 0-1
    string   reason;        // Raison du signal
    double   prediction;     // Prédiction de prix
    datetime timestamp;     // Timestamp du signal
};

AISignal current_ai_signal;

//--- Variables pour prédictions et affichage
double      price_predictions[100]; // Prédictions sur 100 bougies
int         prediction_index = 0;
datetime    last_prediction_update = 0;
string      spike_arrow_name = "";
datetime    spike_arrow_time = 0;
bool        spike_arrow_blink = false;
int         spike_blink_counter = 0;

//--- Variables pour Dashboard
string      g_lastSpikeType = "";
datetime    g_lastSpikeTime = 0;
double      g_lastEntryPrice = 0;
datetime    g_lastEntryTime = 0;

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
   // Mettre à jour les indicateurs (buffers globaux pour OpenNewPositions/UpdateGraphics)
   double close_price[1];
   if(CopyBuffer(ma_handle, 0, 1, 1, ma_buffer) <= 0 ||
      CopyBuffer(rsi_handle, 0, 1, 1, rsi_buffer) <= 0 ||
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

   // --- Appels API limités (évite surcharge réseau + CPU)
   if(TimeCurrent() - g_lastAPIUpdate >= AI_UpdateInterval_sec)
   {
      g_lastAPIUpdate = TimeCurrent();
      if(UseRenderAPI)
      {
         UpdateFromDecision();
         // UpdateFromPredict(); // Désactivé (404)
         // UpdateFromTrendAnalysis(); // Désactivé (404)
      }
   }

   // Gérer les positions existantes (toujours à chaque tick pour SL/TP)
   ManagePositions();

   // Graphiques et tableau de bord : rafraîchis seulement toutes les N secondes (réduit fortement la charge CPU)
   static datetime s_lastGraphicsUpdate = 0;
   static datetime s_lastDashboardUpdate = 0;
   if(TimeCurrent() - s_lastGraphicsUpdate >= GraphicsRefresh_sec)
   {
      s_lastGraphicsUpdate = TimeCurrent();
      UpdateGraphics();
   }
   if(ShowDashboard && TimeCurrent() - s_lastDashboardUpdate >= DashboardRefresh_sec)
   {
      s_lastDashboardUpdate = TimeCurrent();
      UpdateDashboard();
   }
   
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

   double ma_val = ma_buffer[0];
   double rsi_val = rsi_buffer[0];
   double ema_fast_m1 = emaFastM1[0];
   double ema_slow_m1 = emaSlowM1[0];
   double ema_fast_m5 = emaFastM5[0];
   double ema_slow_m5 = emaSlowM5[0];
   double ema_fast_h1 = emaFastH1[0];
   double ema_slow_h1 = emaSlowH1[0];

   // Vérifier le type de symbole
   bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
   bool is_crash = (StringFind(_Symbol, "Crash") >= 0);

   // Signaux techniques basés sur EMA rapides M1
   bool tech_buy_m1 = (price > ema_fast_m1 && rsi_val < RSI_Oversold_Level);
   bool tech_sell_m1 = (price < ema_fast_m1 && rsi_val > RSI_Overbought_Level);

   // Alignement des tendances M5/M1 (OBLIGATOIRE)
   bool trend_alignment_buy = (ema_fast_m1 > ema_slow_m1) && (ema_fast_m5 > ema_slow_m5);
   bool trend_alignment_sell = (ema_fast_m1 < ema_slow_m1) && (ema_fast_m5 < ema_slow_m5);
   
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
            g_lastSpikeType = "BOOM";
            g_lastSpikeTime = TimeCurrent();
            g_lastEntryPrice = ask;
            g_lastEntryTime = TimeCurrent();
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
            g_lastSpikeType = "CRASH";
            g_lastSpikeTime = TimeCurrent();
            g_lastEntryPrice = bid;
            g_lastEntryTime = TimeCurrent();
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
         Print("  - EMA M1 BUY: ", (price > ema_fast_m1 ? "" : ""),
               " | Alignement M5/M1: ", (trend_alignment_buy ? "" : ""),
               " | IA BUY: ", (ai_buy ? "" : ""));
      else
         Print("  - EMA M1 SELL: ", (price < ema_fast_m1 ? "" : ""),
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
      int colon_pos = StringFind(json, ":", dirPos);
      if(colon_pos > 0)
      {
         string part = StringSubstr(json, colon_pos + 1, 25);
         StringToUpper(part);
         if(StringFind(part, "BUY") >= 0 || StringFind(part, "1") >= 0) g_api_trend_direction = 1;
         else if(StringFind(part, "SELL") >= 0 || StringFind(part, "-1") >= 0) g_api_trend_direction = -1;
      }
   }
   int confPos = StringFind(json, "\"confidence\"");
   if(confPos >= 0)
   {
      int colon_conf = StringFind(json, ":", confPos);
      if(colon_conf > 0)
      {
         int end = StringFind(json, ",", colon_conf);
         if(end < 0) end = StringFind(json, "}", colon_conf);
         if(end > colon_conf)
            g_api_trend_confidence = StringToDouble(StringSubstr(json, colon_conf + 1, end - colon_conf - 1));
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
   double commission = 0.0;  // POSITION_COMMISSION deprecated; use history if needed
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
//| Gérer les positions (trailing stop, fermeture spike/perte max)     |
//+------------------------------------------------------------------+
void ManagePositions()
{
   ulong ticket = GetMyPositionTicket();
   if(ticket != 0)
      ManageTrailingStop(ticket);
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
    if(StringLen(AI_ServerURL) == 0 || !UseRenderAPI) return;
    
    // Récupérer les données de marché
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Récupérer les indicateurs techniques
    double rsi[], atr[], ema_fast[], ema_slow[];
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(atr, true);
    ArraySetAsSeries(ema_fast, true);
    ArraySetAsSeries(ema_slow, true);
    
    double rsi_val = 50.0, atr_val = 0.001, ema_fast_val = bid, ema_slow_val = ask;
    int dir_rule = 0;
    
    // Récupérer les valeurs des indicateurs si disponibles
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) > 0) rsi_val = rsi[0];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) > 0) atr_val = atr[0];
    if(CopyBuffer(emaFastM1_handle, 0, 0, 1, ema_fast) > 0) ema_fast_val = ema_fast[0];
    if(CopyBuffer(emaSlowM1_handle, 0, 0, 1, ema_slow) > 0) ema_slow_val = ema_slow[0];
    
    // Déterminer la direction EMA (dir_rule)
    if(ema_fast_val > ema_slow_val) dir_rule = 1;      // BUY
    else if(ema_fast_val < ema_slow_val) dir_rule = -1; // SELL
    else dir_rule = 0; // NEUTRE
    
    // Créer le JSON COMPLET comme attendu par ai_server.py (DecisionRequest)
    string data = "{";
    data += "\"symbol\":\"" + _Symbol + "\"";
    data += ",\"bid\":" + DoubleToString(bid, 5);
    data += ",\"ask\":" + DoubleToString(ask, 5);
    data += ",\"rsi\":" + DoubleToString(rsi_val, 2);
    data += ",\"atr\":" + DoubleToString(atr_val, 6);
    data += ",\"ema_fast\":" + DoubleToString(ema_fast_val, 5);
    data += ",\"ema_slow\":" + DoubleToString(ema_slow_val, 5);
    data += ",\"ema_fast_h1\":" + DoubleToString(ema_fast_val, 5);  // Utiliser M1 comme fallback
    data += ",\"ema_slow_h1\":" + DoubleToString(ema_slow_val, 5);  // Utiliser M1 comme fallback
    data += ",\"ema_fast_m1\":" + DoubleToString(ema_fast_val, 5);
    data += ",\"ema_slow_m1\":" + DoubleToString(ema_slow_val, 5);
    data += ",\"is_spike_mode\":" + (UseSpikeDetection ? "true" : "false");
    data += ",\"dir_rule\":" + IntegerToString(dir_rule);
    data += ",\"supertrend_trend\":" + IntegerToString(dir_rule);  // Utiliser dir_rule comme fallback
    data += ",\"volatility_regime\":0";
    data += ",\"volatility_ratio\":" + DoubleToString(1.0, 2);
    data += "}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", AI_ServerURL, headers, AI_Timeout_ms, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParseAIResponse(response);
        if(DebugLog) Print("✅ /decision succès: ", StringSubstr(response, 0, 150));
    }
    else if(res == 422)
    {
        if(DebugLog) 
        {
            Print("⚠️ Erreur /decision 422 - Données invalides:");
            Print("   Envoi format complet avec indicateurs...");
            Print("   Data: ", StringSubstr(data, 0, 200));
        }
        current_ai_signal.action = "HOLD";
        current_ai_signal.confidence = 0.0;
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
    // DÉSACTIVÉ - Endpoint /predict retourne 404
    if(DebugLog && StringLen(AI_PredictURL) > 0) 
        Print("ℹ️ /predict désactivé - endpoint non disponible (404)");
    return;
}

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /trend-analysis                        |
//+------------------------------------------------------------------+
void UpdateFromTrendAnalysis()
{
    // DÉSACTIVÉ - Endpoint /trend retourne 404
    if(DebugLog && StringLen(TrendAPIURL) > 0) 
        Print("ℹ️ /trend-analysis désactivé - endpoint non disponible (404)");
    return;
}

//+------------------------------------------------------------------+
//| Parser la réponse IA                                             |
//+------------------------------------------------------------------+
void ParseAIResponse(string response)
{
    // Réinitialiser le signal
    current_ai_signal.action = "HOLD";
    current_ai_signal.confidence = 0.0;
    current_ai_signal.reason = "No response";
    current_ai_signal.timestamp = TimeCurrent();
    
    // Parser action (buy, sell, hold)
    int action_pos = StringFind(response, "\"action\"");
    if(action_pos >= 0)
    {
        int colon_pos = StringFind(response, ":", action_pos);
        int quote_start = StringFind(response, "\"", colon_pos);
        int quote_end = StringFind(response, "\"", quote_start + 1);
        
        if(quote_end > quote_start)
        {
            current_ai_signal.action = StringSubstr(response, quote_start + 1, quote_end - quote_start - 1);
            StringToUpper(current_ai_signal.action);
        }
    }
    
    // Parser confidence
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
    
    // Parser reason
    int reason_pos = StringFind(response, "\"reason\"");
    if(reason_pos >= 0)
    {
        int colon_reason = StringFind(response, ":", reason_pos);
        int quote_start = StringFind(response, "\"", colon_reason);
        int quote_end = StringFind(response, "\"", quote_start + 1);
        
        if(quote_end > quote_start)
        {
            current_ai_signal.reason = StringSubstr(response, quote_start + 1, quote_end - quote_start - 1);
        }
    }
    
    // Parser prediction si disponible
    int pred_pos = StringFind(response, "\"prediction\"");
    if(pred_pos >= 0)
    {
        int colon_pred = StringFind(response, ":", pred_pos);
        int pred_end = StringFind(response, ",", colon_pred);
        if(pred_end < 0) pred_end = StringFind(response, "}", colon_pred);
        
        if(pred_end > colon_pred)
        {
            string pred_str = StringSubstr(response, colon_pred + 1, pred_end - colon_pred - 1);
            current_ai_signal.prediction = StringToDouble(pred_str);
        }
    }
    
    // Parser SL/TP si disponibles
    int sl_pos = StringFind(response, "\"stop_loss\"");
    if(sl_pos >= 0)
    {
        int colon_sl = StringFind(response, ":", sl_pos);
        int sl_end = StringFind(response, ",", colon_sl);
        if(sl_end < 0) sl_end = StringFind(response, "}", colon_sl);
        
        if(sl_end > colon_sl)
        {
            string sl_str = StringSubstr(response, colon_sl + 1, sl_end - colon_sl - 1);
            // Stocker dans une variable globale si nécessaire
        }
    }
    
    int tp_pos = StringFind(response, "\"take_profit\"");
    if(tp_pos >= 0)
    {
        int colon_tp = StringFind(response, ":", tp_pos);
        int tp_end = StringFind(response, ",", colon_tp);
        if(tp_end < 0) tp_end = StringFind(response, "}", colon_tp);
        
        if(tp_end > colon_tp)
        {
            string tp_str = StringSubstr(response, colon_tp + 1, tp_end - colon_tp - 1);
            // Stocker dans une variable globale si nécessaire
        }
    }
    
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
//| Afficher les indicateurs graphiques                                 |
//+------------------------------------------------------------------+
void UpdateGraphics()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // MA et EMA : créer une fois, puis seulement déplacer (ObjectMove) = moins de charge
    if(ShowMA && ArraySize(ma_buffer) > 0)
    {
        string ma_name = "BoomCrash_MA_" + IntegerToString(MA_Period);
        if(ObjectFind(0, ma_name) < 0)
        {
            ObjectCreate(0, ma_name, OBJ_HLINE, 0, 0, ma_buffer[0]);
            ObjectSetInteger(0, ma_name, OBJPROP_COLOR, MA_Color);
            ObjectSetInteger(0, ma_name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, ma_name, OBJPROP_STYLE, STYLE_SOLID);
        }
        else
            ObjectMove(0, ma_name, 0, 0, ma_buffer[0]);
    }
    if(ShowMA && ArraySize(emaFastM1) > 0 && ArraySize(emaSlowM1) > 0)
    {
        string n1 = "BoomCrash_EMA_Fast_M1", n2 = "BoomCrash_EMA_Slow_M1";
        if(ObjectFind(0, n1) < 0) { ObjectCreate(0, n1, OBJ_HLINE, 0, 0, emaFastM1[0]); ObjectSetInteger(0, n1, OBJPROP_COLOR, clrGreen); ObjectSetInteger(0, n1, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n1, 0, 0, emaFastM1[0]);
        if(ObjectFind(0, n2) < 0) { ObjectCreate(0, n2, OBJ_HLINE, 0, 0, emaSlowM1[0]); ObjectSetInteger(0, n2, OBJPROP_COLOR, clrRed); ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n2, 0, 0, emaSlowM1[0]);
    }
    if(ShowMA && ArraySize(emaFastM5) > 0 && ArraySize(emaSlowM5) > 0)
    {
        string n1 = "BoomCrash_EMA_Fast_M5", n2 = "BoomCrash_EMA_Slow_M5";
        if(ObjectFind(0, n1) < 0) { ObjectCreate(0, n1, OBJ_HLINE, 0, 0, emaFastM5[0]); ObjectSetInteger(0, n1, OBJPROP_COLOR, clrLime); ObjectSetInteger(0, n1, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n1, 0, 0, emaFastM5[0]);
        if(ObjectFind(0, n2) < 0) { ObjectCreate(0, n2, OBJ_HLINE, 0, 0, emaSlowM5[0]); ObjectSetInteger(0, n2, OBJPROP_COLOR, clrOrange); ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n2, 0, 0, emaSlowM5[0]);
    }
    if(ShowMA && ArraySize(emaFastH1) > 0 && ArraySize(emaSlowH1) > 0)
    {
        string n1 = "BoomCrash_EMA_Fast_H1", n2 = "BoomCrash_EMA_Slow_H1";
        if(ObjectFind(0, n1) < 0) { ObjectCreate(0, n1, OBJ_HLINE, 0, 0, emaFastH1[0]); ObjectSetInteger(0, n1, OBJPROP_COLOR, clrBlue); ObjectSetInteger(0, n1, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n1, 0, 0, emaFastH1[0]);
        if(ObjectFind(0, n2) < 0) { ObjectCreate(0, n2, OBJ_HLINE, 0, 0, emaSlowH1[0]); ObjectSetInteger(0, n2, OBJPROP_COLOR, clrPurple); ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n2, 0, 0, emaSlowH1[0]);
    }
    if(ShowRSI && ArraySize(rsi_buffer) > 0)
    {
        string rsi_name = "BoomCrash_RSI_" + IntegerToString(RSI_Period);
        color rsi_color = (rsi_buffer[0] < RSI_Oversold_Level) ? RSI_Color_Up : (rsi_buffer[0] > RSI_Overbought_Level) ? RSI_Color_Down : clrGray;
        if(ObjectFind(0, rsi_name) < 0)
        {
            ObjectCreate(0, rsi_name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, rsi_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, rsi_name, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, rsi_name, OBJPROP_YDISTANCE, 30);
            ObjectSetInteger(0, rsi_name, OBJPROP_FONTSIZE, 10);
        }
        ObjectSetString(0, rsi_name, OBJPROP_TEXT, "RSI: " + DoubleToString(rsi_buffer[0], 1));
        ObjectSetInteger(0, rsi_name, OBJPROP_COLOR, rsi_color);
    }
    
    // === AFFICHAGE DES DONNÉES IA EN TEMPS RÉEL ===
    if(UseRenderAPI && StringLen(current_ai_signal.action) > 0)
    {
        // Afficher le signal IA
        string ai_signal_name = "BoomCrash_AI_Signal";
        if(ObjectFind(0, ai_signal_name) < 0)
        {
            ObjectCreate(0, ai_signal_name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, ai_signal_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, ai_signal_name, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, ai_signal_name, OBJPROP_YDISTANCE, 50);
            ObjectSetInteger(0, ai_signal_name, OBJPROP_FONTSIZE, 11);
        }
        
        // Couleur selon le signal
        color ai_color = clrWhite;
        if(current_ai_signal.action == "BUY") ai_color = clrLime;
        else if(current_ai_signal.action == "SELL") ai_color = clrRed;
        else if(current_ai_signal.action == "HOLD") ai_color = clrYellow;
        
        string ai_text = "🤖 IA: " + current_ai_signal.action + 
                        " | Conf: " + DoubleToString(current_ai_signal.confidence * 100, 1) + "%" +
                        " | " + StringSubstr(current_ai_signal.reason, 0, 30);
        
        ObjectSetString(0, ai_signal_name, OBJPROP_TEXT, ai_text);
        ObjectSetInteger(0, ai_signal_name, OBJPROP_COLOR, ai_color);
        
        // Afficher la prédiction si disponible
        if(current_ai_signal.prediction > 0)
        {
            string ai_pred_name = "BoomCrash_AI_Prediction";
            if(ObjectFind(0, ai_pred_name) < 0)
            {
                ObjectCreate(0, ai_pred_name, OBJ_LABEL, 0, 0, 0);
                ObjectSetInteger(0, ai_pred_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                ObjectSetInteger(0, ai_pred_name, OBJPROP_XDISTANCE, 10);
                ObjectSetInteger(0, ai_pred_name, OBJPROP_YDISTANCE, 70);
                ObjectSetInteger(0, ai_pred_name, OBJPROP_FONTSIZE, 9);
            }
            
            string pred_text = "📊 Prédiction: " + DoubleToString(current_ai_signal.prediction, _Digits);
            ObjectSetString(0, ai_pred_name, OBJPROP_TEXT, pred_text);
            ObjectSetInteger(0, ai_pred_name, OBJPROP_COLOR, clrCyan);
        }
        
        // Afficher le timestamp de dernière mise à jour
        string ai_time_name = "BoomCrash_AI_Time";
        if(ObjectFind(0, ai_time_name) < 0)
        {
            ObjectCreate(0, ai_time_name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, ai_time_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, ai_time_name, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, ai_time_name, OBJPROP_YDISTANCE, 90);
            ObjectSetInteger(0, ai_time_name, OBJPROP_FONTSIZE, 8);
        }
        
        string time_text = "⏰ MAJ: " + TimeToString(current_ai_signal.timestamp, TIME_SECONDS);
        ObjectSetString(0, ai_time_name, OBJPROP_TEXT, time_text);
        ObjectSetInteger(0, ai_time_name, OBJPROP_COLOR, clrGray);
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
    
    // Une seule flèche BUY/SELL réutilisée (évite accumulation d'objets = moins de ram)
    const string buy_arrow = "BoomCrash_BUY_Arrow", sell_arrow = "BoomCrash_SELL_Arrow";
    bool buy_signal = (current_price > ma_value && rsi_value < RSI_Oversold_Level);
    bool sell_signal = (current_price < ma_value && rsi_value > RSI_Overbought_Level);
    if(buy_signal && current_ai_signal.action == "BUY" && current_ai_signal.confidence > 0.5)
    {
        if(ObjectFind(0, buy_arrow) < 0)
        {
            ObjectCreate(0, buy_arrow, OBJ_ARROW_UP, 0, TimeCurrent(), current_price);
            ObjectSetInteger(0, buy_arrow, OBJPROP_COLOR, BuySignalColor);
            ObjectSetInteger(0, buy_arrow, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, buy_arrow, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
        }
        else ObjectMove(0, buy_arrow, 0, TimeCurrent(), current_price);
    }
    else if(ObjectFind(0, buy_arrow) >= 0) ObjectDelete(0, buy_arrow);
    if(sell_signal && current_ai_signal.action == "SELL" && current_ai_signal.confidence > 0.5)
    {
        if(ObjectFind(0, sell_arrow) < 0)
        {
            ObjectCreate(0, sell_arrow, OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price);
            ObjectSetInteger(0, sell_arrow, OBJPROP_COLOR, SellSignalColor);
            ObjectSetInteger(0, sell_arrow, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, sell_arrow, OBJPROP_ANCHOR, ANCHOR_TOP);
        }
        else ObjectMove(0, sell_arrow, 0, TimeCurrent(), current_price);
    }
    else if(ObjectFind(0, sell_arrow) >= 0) ObjectDelete(0, sell_arrow);
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
//| Tableau de bord complet (infos, alertes spike, entrées, durée)   |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   static bool s_dash_created = false;
   const int x_start = 10, line_height = 18, font_size = 9;
   color text_color = clrWhite, header_color = clrGold;

   // Création une seule fois (réduit charge CPU au rafraîchissement)
   if(!s_dash_created)
   {
      s_dash_created = true;
      string bg_name = "BoomCrash_Dash_BG";
      ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, x_start - 5);
      ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, 25);
      ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, 350);
      ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, 450);
      ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, bg_name, OBJPROP_SELECTABLE, false);
      string names[] = {"BoomCrash_Dash_Title","BoomCrash_Dash_InfoHeader","BoomCrash_Dash_Price","BoomCrash_Dash_RSI","BoomCrash_Dash_MA","BoomCrash_Dash_EMA_M1","BoomCrash_Dash_APIHeader","BoomCrash_Dash_AIAction","BoomCrash_Dash_Trend","BoomCrash_Dash_SpikeHeader","BoomCrash_Dash_SpikeType","BoomCrash_Dash_EntryPrice","BoomCrash_Dash_Duration","BoomCrash_Dash_AlertTime","BoomCrash_Dash_PosHeader","BoomCrash_Dash_PosStatus","BoomCrash_Dash_PosPnL"};
      int y = 30;
      for(int i = 0; i < ArraySize(names); i++)
      {
         if(ObjectFind(0, names[i]) < 0)
         {
            ObjectCreate(0, names[i], OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, names[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, names[i], OBJPROP_XDISTANCE, x_start);
            ObjectSetInteger(0, names[i], OBJPROP_YDISTANCE, y);
            ObjectSetInteger(0, names[i], OBJPROP_FONTSIZE, font_size);
         }
         y += line_height;
         if(i == 0 || i == 1 || i == 6 || i == 9 || i == 14) y += 5;
      }
   }

   // Mise à jour du texte uniquement (léger)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double rsi_val = (ArraySize(rsi_buffer) > 0) ? rsi_buffer[0] : 0;
   double ma_val = (ArraySize(ma_buffer) > 0) ? ma_buffer[0] : 0;
   double ema_fast_m1_val = (ArraySize(emaFastM1) > 0) ? emaFastM1[0] : 0;
   double ema_slow_m1_val = (ArraySize(emaSlowM1) > 0) ? emaSlowM1[0] : 0;
   long duration_sec = (g_lastSpikeTime > 0) ? (long)(TimeCurrent() - g_lastSpikeTime) : 0;

   ObjectSetString(0, "BoomCrash_Dash_Title", OBJPROP_TEXT, "═══════ TABLEAU DE BORD ═══════");
   ObjectSetString(0, "BoomCrash_Dash_InfoHeader", OBJPROP_TEXT, "INFORMATIONS");
   ObjectSetString(0, "BoomCrash_Dash_Price", OBJPROP_TEXT, _Symbol + " | Bid: " + DoubleToString(bid, _Digits) + " | Ask: " + DoubleToString(ask, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_RSI", OBJPROP_TEXT, "RSI: " + DoubleToString(rsi_val, 2));
   ObjectSetInteger(0, "BoomCrash_Dash_RSI", OBJPROP_COLOR, (rsi_val < RSI_Oversold_Level) ? clrLime : (rsi_val > RSI_Overbought_Level) ? clrRed : text_color);
   ObjectSetString(0, "BoomCrash_Dash_MA", OBJPROP_TEXT, "MA(" + IntegerToString(MA_Period) + "): " + DoubleToString(ma_val, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_EMA_M1", OBJPROP_TEXT, "EMA M1: " + DoubleToString(ema_fast_m1_val, _Digits) + " / " + DoubleToString(ema_slow_m1_val, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_APIHeader", OBJPROP_TEXT, "ETAT API");
   ObjectSetString(0, "BoomCrash_Dash_AIAction", OBJPROP_TEXT, "IA: " + StringToUpper(g_lastAIAction) + " " + DoubleToString(g_lastAIConfidence * 100, 1) + "%");
   ObjectSetInteger(0, "BoomCrash_Dash_AIAction", OBJPROP_COLOR, (g_lastAIAction == "buy") ? clrLime : (g_lastAIAction == "sell") ? clrRed : clrGray);
   string trend_str = (g_api_trend_direction == 1) ? "HAUSS." : (g_api_trend_direction == -1) ? "BAISS." : "NEUTRE";
   ObjectSetString(0, "BoomCrash_Dash_Trend", OBJPROP_TEXT, "Tendance: " + trend_str + " " + DoubleToString(g_api_trend_confidence * 100, 1) + "%");
   ObjectSetInteger(0, "BoomCrash_Dash_Trend", OBJPROP_COLOR, (g_api_trend_direction == 1) ? clrLime : (g_api_trend_direction == -1) ? clrRed : clrGray);
   ObjectSetString(0, "BoomCrash_Dash_SpikeHeader", OBJPROP_TEXT, "ALERTE SPIKE");
   ObjectSetString(0, "BoomCrash_Dash_SpikeType", OBJPROP_TEXT, "Spike: " + ((g_lastSpikeType != "") ? g_lastSpikeType : "Aucune"));
   ObjectSetInteger(0, "BoomCrash_Dash_SpikeType", OBJPROP_COLOR, (g_lastSpikeType == "BOOM") ? clrLime : (g_lastSpikeType == "CRASH") ? clrRed : clrGray);
   ObjectSetString(0, "BoomCrash_Dash_EntryPrice", OBJPROP_TEXT, "Entrée: " + ((g_lastEntryPrice > 0) ? DoubleToString(g_lastEntryPrice, _Digits) : "N/A"));
   ObjectSetString(0, "BoomCrash_Dash_Duration", OBJPROP_TEXT, "Durée alerte: " + (duration_sec > 0 ? IntegerToString((int)duration_sec) + " sec" : "N/A"));
   ObjectSetInteger(0, "BoomCrash_Dash_Duration", OBJPROP_COLOR, (duration_sec > 0 && duration_sec < 60) ? clrYellow : text_color);
   ObjectSetString(0, "BoomCrash_Dash_AlertTime", OBJPROP_TEXT, (g_lastSpikeTime > 0) ? TimeToString(g_lastSpikeTime, TIME_DATE|TIME_SECONDS) : "N/A");

   ObjectSetString(0, "BoomCrash_Dash_PosHeader", OBJPROP_TEXT, "POSITION");
   ulong ticket = GetMyPositionTicket();
   if(ticket > 0 && PositionSelectByTicket(ticket))
   {
      double pos_total = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      ObjectSetString(0, "BoomCrash_Dash_PosStatus", OBJPROP_TEXT, "Type: " + EnumToString((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)) + " | Vol: " + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2));
      ObjectSetString(0, "BoomCrash_Dash_PosPnL", OBJPROP_TEXT, "P&L: " + DoubleToString(pos_total, 2) + " USD");
      ObjectSetInteger(0, "BoomCrash_Dash_PosStatus", OBJPROP_COLOR, (pos_total > 0) ? clrLime : (pos_total < 0) ? clrRed : text_color);
      ObjectSetInteger(0, "BoomCrash_Dash_PosPnL", OBJPROP_COLOR, (pos_total > 0) ? clrLime : (pos_total < 0) ? clrRed : text_color);
   }
   else
   {
      ObjectSetString(0, "BoomCrash_Dash_PosStatus", OBJPROP_TEXT, "Aucune position ouverte");
      ObjectSetInteger(0, "BoomCrash_Dash_PosStatus", OBJPROP_COLOR, clrGray);
      ObjectSetString(0, "BoomCrash_Dash_PosPnL", OBJPROP_TEXT, "");
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
//| Mettre à jour depuis endpoint /decision                             |
//+------------------------------------------------------------------+
void UpdateFromDecision()
{
    if(StringLen(AI_ServerURL) == 0 || !UseRenderAPI) return;
    
    // Récupérer les données de marché
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Récupérer les indicateurs techniques
    double rsi[], atr[], ema_fast[], ema_slow[];
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(atr, true);
    ArraySetAsSeries(ema_fast, true);
    ArraySetAsSeries(ema_slow, true);
    
    double rsi_val = 50.0, atr_val = 0.001, ema_fast_val = bid, ema_slow_val = ask;
    int dir_rule = 0;
    
    // Récupérer les valeurs des indicateurs si disponibles
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) > 0) rsi_val = rsi[0];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) > 0) atr_val = atr[0];
    if(CopyBuffer(emaFastM1_handle, 0, 0, 1, ema_fast) > 0) ema_fast_val = ema_fast[0];
    if(CopyBuffer(emaSlowM1_handle, 0, 0, 1, ema_slow) > 0) ema_slow_val = ema_slow[0];
    
    // Déterminer la direction EMA (dir_rule)
    if(ema_fast_val > ema_slow_val) dir_rule = 1;      // BUY
    else if(ema_fast_val < ema_slow_val) dir_rule = -1; // SELL
    else dir_rule = 0; // NEUTRE
    
    // Créer le JSON COMPLET comme attendu par ai_server.py (DecisionRequest)
    string data = "{";
    data += "\"symbol\":\"" + _Symbol + "\"";
    data += ",\"bid\":" + DoubleToString(bid, 5);
    data += ",\"ask\":" + DoubleToString(ask, 5);
    data += ",\"rsi\":" + DoubleToString(rsi_val, 2);
    data += ",\"atr\":" + DoubleToString(atr_val, 6);
    data += ",\"ema_fast\":" + DoubleToString(ema_fast_val, 5);
    data += ",\"ema_slow\":" + DoubleToString(ema_slow_val, 5);
    data += ",\"ema_fast_h1\":" + DoubleToString(ema_fast_val, 5);
    data += ",\"ema_slow_h1\":" + DoubleToString(ema_slow_val, 5);
    data += ",\"ema_fast_m1\":" + DoubleToString(ema_fast_val, 5);
    data += ",\"ema_slow_m1\":" + DoubleToString(ema_slow_val, 5);
    data += ",\"is_spike_mode\":" + (UseSpikeDetection ? "true" : "false");
    data += ",\"dir_rule\":" + IntegerToString(dir_rule);
    data += ",\"supertrend_trend\":" + IntegerToString(dir_rule);
    data += ",\"volatility_regime\":0";
    data += ",\"volatility_ratio\":" + DoubleToString(1.0, 2);
    data += "}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", AI_ServerURL, headers, AI_Timeout_ms, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParseAIResponse(response);
        
        // Mettre à jour les variables globales pour le dashboard
        g_lastAIAction = current_ai_signal.action;
        g_lastAIConfidence = current_ai_signal.confidence;
        
        if(DebugLog) Print("✅ /decision succès: ", StringSubstr(response, 0, 150));
    }
    else if(res == 422)
    {
        if(DebugLog) 
        {
            Print("⚠️ Erreur /decision 422 - Données invalides:");
            Print("   Envoi format complet avec indicateurs...");
            Print("   Data: ", StringSubstr(data, 0, 200));
        }
        current_ai_signal.action = "HOLD";
        current_ai_signal.confidence = 0.0;
        g_lastAIAction = "HOLD";
        g_lastAIConfidence = 0.0;
    }
    else if(DebugLog)
    {
        Print("⚠️ Erreur /decision: ", res);
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse IA                                             |
//+------------------------------------------------------------------+
void ParseAIResponse(string response)
{
    // Réinitialiser le signal
    current_ai_signal.action = "HOLD";
    current_ai_signal.confidence = 0.0;
    current_ai_signal.reason = "No response";
    current_ai_signal.timestamp = TimeCurrent();
    
    // Parser action (buy, sell, hold)
    int action_pos = StringFind(response, "\"action\"");
    if(action_pos >= 0)
    {
        int colon_pos = StringFind(response, ":", action_pos);
        int quote_start = StringFind(response, "\"", colon_pos);
        int quote_end = StringFind(response, "\"", quote_start + 1);
        
        if(quote_end > quote_start)
        {
            current_ai_signal.action = StringSubstr(response, quote_start + 1, quote_end - quote_start - 1);
            StringToUpper(current_ai_signal.action);
        }
    }
    
    // Parser confidence
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
    
    // Parser reason
    int reason_pos = StringFind(response, "\"reason\"");
    if(reason_pos >= 0)
    {
        int colon_reason = StringFind(response, ":", reason_pos);
        int quote_start = StringFind(response, "\"", colon_reason);
        int quote_end = StringFind(response, "\"", quote_start + 1);
        
        if(quote_end > quote_start)
        {
            current_ai_signal.reason = StringSubstr(response, quote_start + 1, quote_end - quote_start - 1);
        }
    }
    
    if(DebugLog)
    {
        Print("🤖 Signal IA reçu: ", current_ai_signal.action, 
              " | Confiance: ", DoubleToString(current_ai_signal.confidence * 100, 1), "%",
              " | Raison: ", current_ai_signal.reason);
    }
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Vérifie si une flèche DERIV est présente sur le graphique        |
//+------------------------------------------------------------------+
bool IsDerivArrowPresent()
{
    int total = ObjectsTotal(0, 0, -1);
    for(int i = total-1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, "DERIV ARROW") >= 0)
        {
            datetime arrowTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
            // Vérifier si la flèche est sur la bougie actuelle
            if(TimeCurrent() - arrowTime <= PeriodSeconds())
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Vérifie si un signal fort est présent (ACHAT FORT ou VENTE FORTE)|
//+------------------------------------------------------------------+
bool HasStrongSignal(string &signalType)
{
    // Vérifier les signaux IA
    if(current_ai_signal.confidence >= 0.7)
    {
        if(current_ai_signal.action == "BUY" && g_api_trend_direction > 0)
        {
            signalType = "ACHAT FORT (IA)";
            return true;
        }
        else if(current_ai_signal.action == "SELL" && g_api_trend_direction < 0)
        {
            signalType = "VENTE FORTE (IA)";
            return true;
        }
    }
    
    // Vérifier les signaux techniques forts
    double rsi_val = rsi_buffer[0];
    double emaFast = emaFastM1[0];
    double emaSlow = emaSlowM1[0];
    
    if(emaFast > emaSlow && rsi_val < 30)
    {
        signalType = "ACHAT FORT (RSI + EMA)";
        return true;
    }
    else if(emaFast < emaSlow && rsi_val > 70)
    {
        signalType = "VENTE FORTE (RSI + EMA)";
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifie si la direction est autorisée pour le symbole            |
//+------------------------------------------------------------------+
bool IsDirectionAllowedForBoomCrash(bool isBuy)
{
    bool isBoom = StringFind(_Symbol, "Boom") >= 0;
    bool isCrash = StringFind(_Symbol, "Crash") >= 0;
    
    if(isBoom && !isBuy) return false;  // Pas de vente sur Boom
    if(isCrash && isBuy) return false;  // Pas d'achat sur Crash
    
    return true;
}

//+------------------------------------------------------------------+
//| Exécute un trade pour capturer un spike Boom/Crash               |
//+------------------------------------------------------------------+
void ExecuteBoomCrashSpikeTrade(bool isBuy, string signalType)
{
    double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculer le stop loss et take profit
    double atr_val = atr_buffer[0];
    double sl = isBuy ? price - (atr_val * 2) : price + (atr_val * 2);
    double tp = isBuy ? price + (atr_val * 4) : price - (atr_val * 3);
    
    // Préparer la transaction
    CTrade spike_trade;
    spike_trade.SetExpertMagicNumber(MagicNumber);
    
    // Exécuter l'ordre
    if(isBuy)
    {
        if(spike_trade.Buy(LotSize, _Symbol, price, sl, tp, "BoomSpike: " + signalType))
        {
            Print("🚀 ACHAT exécuté sur ", _Symbol, " - ", signalType);
            SendNotification("ACHAT " + _Symbol + " - " + signalType);
            
            // Mettre à jour les variables globales
            g_lastSpikeType = "BOOM";
            g_lastSpikeTime = TimeCurrent();
            g_lastEntryPrice = price;
            g_lastEntryTime = TimeCurrent();
        }
    }
    else
    {
        if(spike_trade.Sell(LotSize, _Symbol, price, sl, tp, "CrashSpike: " + signalType))
        {
            Print("🚀 VENTE exécutée sur ", _Symbol, " - ", signalType);
            SendNotification("VENTE " + _Symbol + " - " + signalType);
            
            // Mettre à jour les variables globales
            g_lastSpikeType = "CRASH";
            g_lastSpikeTime = TimeCurrent();
            g_lastEntryPrice = price;
            g_lastEntryTime = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| Fonction principale de recherche d'opportunités de trading       |
//+------------------------------------------------------------------+
void LookForTradingOpportunity()
{
    // Vérifier si nous sommes sur un symbole Boom/Crash
    bool isBoomCrash = (StringFind(_Symbol, "Boom") >= 0 || 
                        StringFind(_Symbol, "Crash") >= 0);
    
    if(!isBoomCrash) return;
    
    // Vérifier la présence d'une flèche DERIV
    if(!IsDerivArrowPresent()) return;
    
    // Vérifier les signaux forts
    string signalType = "";
    if(!HasStrongSignal(signalType)) return;
    
    // Déterminer la direction du trade
    bool isBuy = (StringFind(signalType, "ACHAT") >= 0);
    
    // Vérifier si la direction est autorisée
    if(!IsDirectionAllowedForBoomCrash(isBuy)) return;
    
    // Exécuter le trade
    ExecuteBoomCrashSpikeTrade(isBuy, signalType);
}

//+------------------------------------------------------------------+
