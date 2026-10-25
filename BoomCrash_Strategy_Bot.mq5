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

//--- Stratégies Avancées
input group             "Stratégies Avancées"
input bool              UseAdvancedStrategies = false;       // DÉSACTIVÉ par défaut pour performances
input double            AdvancedMinConfidence = 65.0;       // Confiance minimale pour stratégies avancées (0-100%)
input int               AdvancedUpdateInterval = 60;         // Mettre à jour stratégies toutes les N secondes (60 = moins de charge)

#include <Trade\Trade.mqh>
// #include "BoomCrash_PreSpike_Functions.mqh"  // File not found - commented out
// #include "Advanced_Strategies.mqh"           // File not found - commented out

//--- Constantes manquantes pour la compatibilité
#ifndef ANCHOR_LEFT_UPPER
#define ANCHOR_LEFT_UPPER 0
#endif

//--- Stratégie de Trading
input group             "Stratégie de Trading"
input int               MA_Period = 50;                 // Période de la Moyenne Mobile (réduit pour plus de réactivité)
input ENUM_MA_METHOD    MA_Method = MODE_SMA;          // Méthode MA (Simple, Exponentielle...)
input int               RSI_Period = 14;               // Période du RSI
input double            RSI_Overbought_Level = 60.0;   // RSI surachat (vente / repli) - assoupli
input double            RSI_Oversold_Level = 40.0;     // RSI survente (achat / rebond) - assoupli
input int               ModeOuverture = 2;             // 0=Strict 1=+Spike 2=Classique seul (max trades)
input bool              TradeBothDirections = true;    // true = acheter sur survente ET vendre sur surachat
input bool              RSIOnlyReverse = true;         // sens inverse sur RSI seul (pas de filtre MA) = plus d'ouvertures

//--- Détection SPIKE locale (optionnel - mode 2 l'ignore)
input group             "Détection Spike locale"
input bool              UseSpikeDetection = true;      // ACTIVÉ pour détecter les spikes Boom/Crash
input int               ATR_Period = 14;               // Période ATR pour volatilité
input double            MinATRExpansionRatio = 1.15;   // ATR actuel / ATR moyen > ce ratio = spike volatilité
input int               ATR_AverageBars = 20;          // Barres pour moyenne ATR
input double            MinCandleBodyATR = 0.35;      // Corps bougie / ATR min (grosse bougie = spike)
input double            MinRSISpike = 25.0;            // RSI extrême pour Crash (plus bas = spike)
input double            MaxRSISpike = 75.0;            // RSI extrême pour Boom (plus haut = spike)

//--- API Render (synthèse des analyses - comme F_INX_scalper_double)
input group             "API Render (synthèse)"
input bool              UseRenderAPI = true;           // Utiliser les endpoints Render pour la décision
input string            AI_ServerURL = "http://127.0.0.1:8000/decision"; // Décision IA (local: 127.0.0.1:8000 | Render: https://kolatradebot.onrender.com/decision)
input string            TrendAPIURL = "";    // Désactivé (404)
input string            AI_PredictURL = ""; // Désactivé (404)
input int               AI_Timeout_ms = 10000;         // Timeout WebRequest (ms)
input int               AI_UpdateInterval_sec = 60;     // Rafraîchir l'API toutes les N secondes (augmenté pour réduire spam)
input double            MinAPIConfidence = 0.65;      // Ajusté pour 68% minimum (0-1)
input bool              RequireTrendAlignment = false;  // Exiger tendance API alignée (désactivé = plus d'ouvertures)
input bool              RequireAPIToOpen = false;       // Si false: ouvrir avec Classique+Spike même sans accord API

//--- Affichage Graphique et Signaux
input group             "Affichage Graphique"
input bool              ShowMA = true;                     // Afficher MA mobile
input bool              ShowRSI = true;                    // Afficher RSI
input bool              ShowSignals = true;                 // Afficher signaux d'entrée
input bool              ShowPredictions = true;             // Afficher prédictions sur 100 bougies
input bool              ShowSpikeArrows = true;            // Afficher flèches de spike clignotantes
input bool              ShowSpikeChannel = true;          // Afficher canal prédictif zones spike (ATR)
input double            SpikeChannelATRMult = 2.0;        // Canal = prix ± (ATR * ce multiplicateur)
input color             SpikeChannelColor = clrDodgerBlue; // Couleur canal spike
input bool              UseLimitOrdersInChannel = true;   // Ordres limite dans le canal (BuyLimit Boom, SellLimit Crash)
input int               LimitOrderOffsetPoints = 5;       // Décalage du prix limite (points) depuis le bord du canal
input bool              PlaceLimitOrdersOnAlignmentEnabled = true; // Placer ordres limite lors d'alignement buy/sell sur tableau de bord
input color             MA_Color = clrBlue;                // Couleur MA
input color             RSI_Color_Up = clrGreen;           // Couleur RSI survente
input color             RSI_Color_Down = clrRed;         // Couleur RSI surachat
input color             BuySignalColor = clrLime;          // Couleur signal BUY
input color             SellSignalColor = clrRed;          // Couleur signal SELL
input color             SpikeArrowColor = clrYellow;        // Couleur flèche spike
input bool              ShowDashboard = true;                // Tableau de bord (infos, alertes spike, entrées, durée)
input int               DashboardRefresh_sec = 30;            // Rafraîchir tableau de bord (sec) - 30 = moins de charge
input int               GraphicsRefresh_sec = 30;             // Rafraîchir graphiques (sec) - 30 = moins de charge
input bool              EntryOnNewBarOnly = true;             // true = vérifier entrée seulement à chaque nouvelle barre (très léger)

//--- Gestion du Risque (en Pips/Points)
input group             "Gestion du Risque (en Pips)"
input double            LotSize = 0.2;                 // Taille du lot fixe
input int               StopLoss_Pips = 0;              // Stop Loss en pips (DÉSACTIVÉ)
input int               TakeProfit_Pips = 0;            // Take Profit en pips (DÉSACTIVÉ)

input group             "GESTION DU RISQUE PAR TRADE"
input double            InpRiskPercentPerTrade = 0.8;     // 0.8 % max par trade
input double            InpFixedRiskUSD        = 0.0;     // ou mets 2.0 si tu préfères fixe

input group             "Gestion Boom/Crash Spéciale"
input bool              UseBoomCrashAutoClose = true;   // Fermeture automatique après spike
input double            BoomCrashMinProfitUSD = 0.50;   // Profit minimum pour fermeture (USD)
input int               BoomCrashMinProfitPips = 50;    // Profit minimum pour fermeture (pips)
input bool              UseBoomCrashTrailing = true;    // Trailing stop spécial Boom/Crash

input group             "Fermeture après spike (réaliser le gain)"
input bool              CloseOnSpikeProfit = true;     // Fermer la position quand le spike a donné ce profit
input double            SpikeProfitClose_USD = 0.50;   // Fermer quand profit >= ce montant (USD)

input group             "Gestion des Pertes"
input bool              CloseOnMaxLoss = true;         // Fermer après perte maximale
input double            MaxLoss_USD = 3.0;            // Fermer quand perte >= ce montant (USD)

input group             "Trailing Stop"
input bool              InpUseTrailing       = true;
input bool              UseTrailingStop      = true;      // Activer trailing stop
input int               InpTrailDist         = 20;               // trailing assez serré
input double            BreakevenTriggerPips = 15.0;          // points de profit pour breakeven
input double            BreakevenBufferPips  = 2.5;            // buffer au-dessus/au-dessous de l'entrée
input double            BoomCrashTrailDistPips = 35.0;
input double            BoomCrashTrailStartPips = 22.0;

input group             "Identification du Robot"
input long              MagicNumber = 12345;           // Numéro magique
input bool              DebugLog = false;              // Désactivé par défaut pour performances

//--- Variables globales
CTrade      trade;

//--- Handles pour indicateurs
int         ma_handle;
int         rsi_handle;
int         atr_handle;
int         atr_M1_handle;  // ATR M1 pour filtre anti-spike

//--- EMA rapides pour M1, M5, H1
int         emaFastM1_handle;
int         emaSlowM1_handle;
int         emaFastM5_handle;
int         emaSlowM5_handle;
int         emaFastH1_handle;
int         emaSlowH1_handle;
int         rsiM5_handle;  // RSI M5 pour confirmation multi-timeframe spike

//--- Variables pour les buffers
double      ma_buffer[];
double      rsi_buffer[];
double      atr_buffer[];
double      rsiM5_buffer[];
double      emaFastM1_buffer[];
double      emaSlowM1_buffer[];
double      emaFastM5_buffer[];
double      emaSlowM5_buffer[];
double      emaFastH1_buffer[];
double      emaSlowH1_buffer[];

//--- Constants for trailing stop tracking
#define MAX_TRACKED_TICKETS 100

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

//--- Variables pour optimisation performances
datetime    g_lastAdvancedUpdate = 0;

//--- Variables pour filtre local
datetime    g_lastLocalFilterLog = 0;

// ─────────────────────────────────────
// Variables pour dashboard gauche
// ─────────────────────────────────────
datetime lastDashboardUpdate = 0;
int dashboardX = 10;   // Position gauche
int dashboardY = 20;   // Haut
color colorOK    = clrGreen;
color colorAlert = clrRed;
color colorWarn  = clrYellow;

//+------------------------------------------------------------------+
//| Valide et normalise la taille du lot selon les specs du symbole  |
//+------------------------------------------------------------------+
double ValidateLotSize(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Arrondir au step le plus proche
   if(stepLot > 0)
      lot = MathRound(lot / stepLot) * stepLot;
   
   // Limiter entre min et max
   if(lot < minLot)
   {
      Print("⚠️ Lot ", lot, " trop petit. Ajusté à ", minLot);
      lot = minLot;
   }
   if(lot > maxLot)
   {
      Print("⚠️ Lot ", lot, " trop grand. Ajusté à ", maxLot);
      lot = maxLot;
   }
   
   // Normaliser à 2 décimales
   lot = NormalizeDouble(lot, 2);
   
   return lot;
}

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

   // Handle ATR M1 pour filtre anti-spike
   atr_M1_handle = iATR(_Symbol, PERIOD_M1, 14);
   if(atr_M1_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du handle ATR M1.");
      return(INIT_FAILED);
   }

   // Initialiser les EMA rapides pour M1, M5, H1
   emaFastM1_handle = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM1_handle = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM5_handle = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5_handle = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   emaFastH1_handle = iMA(_Symbol, PERIOD_H1, 10, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowH1_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(emaFastM1_handle == INVALID_HANDLE || emaSlowM1_handle == INVALID_HANDLE)
   {
      Print("ERREUR CRITIQUE : Impossible de créer EMA 9/21 M1");
      return INIT_FAILED;
   }
   
   if(emaFastM5_handle == INVALID_HANDLE || emaSlowM5_handle == INVALID_HANDLE ||
      emaFastH1_handle == INVALID_HANDLE || emaSlowH1_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création des handles EMA.");
      return(INIT_FAILED);
   }
   
   rsiM5_handle = iRSI(_Symbol, PERIOD_M5, RSI_Period, PRICE_CLOSE);
   if(rsiM5_handle == INVALID_HANDLE)
      Print("RSI M5 optionnel non créé (détection spike renforcée désactivée).");
   
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
   // Nettoyage dashboard
   ObjectsDeleteAll(0, "DASH_LEFT_");
   
   IndicatorRelease(ma_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);
   IndicatorRelease(atr_M1_handle);
   IndicatorRelease(emaFastM1_handle);
   IndicatorRelease(emaSlowM1_handle);
   IndicatorRelease(emaFastM5_handle);
   IndicatorRelease(emaSlowM5_handle);
   IndicatorRelease(emaFastH1_handle);
   IndicatorRelease(emaSlowH1_handle);
   if(rsiM5_handle != INVALID_HANDLE) IndicatorRelease(rsiM5_handle);
   CleanChartObjects();
   ObjectsDeleteAll(0, "DASH_LEFT_");
   Print("Robot désinitialisé.");
}

//+------------------------------------------------------------------+
//| Fonction principale, exécutée à chaque nouveau tick              |
//+------------------------------------------------------------------+
void OnTick()
{
   SymbolInfoTick(_Symbol, last_tick);

   // ────────────────────────────────────────────────
   // Initialisation des variables IA pour le dashboard
   // ────────────────────────────────────────────────
   if(g_lastAIAction == "")
   {
      g_lastAIAction = "hold";
      g_lastAIConfidence = 0.50;
   }

   // ────────────────────────────────────────────────
   // Mise à jour dashboard gauche (toujours exécuté)
   // ────────────────────────────────────────────────
   if(TimeCurrent() - lastDashboardUpdate >= 10)  // Mise à jour toutes les 10 secondes
   {
      UpdateLeftDashboard();
      lastDashboardUpdate = TimeCurrent();
      static int dashboardDebugCounter = 0;
      if(++dashboardDebugCounter % 6 == 0) // Message toutes les 60 secondes
         Print("📊 Dashboard actif - Mise à jour toutes les 10 secondes");
   }
   
   // ────────────────────────────────────────────────
   // Nettoyage des objets expirés (toutes les 5 minutes)
   // ────────────────────────────────────────────────
   static datetime lastCleanupTime = 0;
   if(TimeCurrent() - lastCleanupTime >= 300) // Nettoyer toutes les 5 minutes
   {
      CleanExpiredObjects();
      lastCleanupTime = TimeCurrent();
      Print("🧹 Nettoyage des objets graphiques expirés");
   }

   // ────────────────────────────────────────────────
   // Objectif journalier atteint → on arrête de trader aujourd'hui
   // ────────────────────────────────────────────────
   static datetime last_daily_profit_check_time = 0;
   double current_daily_net = CalculateDailyNetProfit();

   if(current_daily_net >= 50.0)   // Augmenté pour tests (était 10$)
   {
   }

   // --- Quand une position est ouverte : travail minimal (SL/TP + rafraîchissements espacés)
   if(PositionsTotal() > 0)
   {
      ManagePositions();
      ManageBoomCrashPositions(); // Gestion spécifique Boom/Crash
      CheckMaxLossPerTrade();    // Gestion des risques - limite perte à 5$
      static datetime s_lastGraphicsUpdate = 0;
      static datetime s_lastDashboardUpdate = 0;
      if(TimeCurrent() - s_lastGraphicsUpdate >= GraphicsRefresh_sec)
      {
         s_lastGraphicsUpdate = TimeCurrent();
         if(RefreshAllBuffers()) UpdateGraphics();
      }
      if(ShowDashboard && TimeCurrent() - s_lastDashboardUpdate >= DashboardRefresh_sec)
      {
         s_lastDashboardUpdate = TimeCurrent();
         if(RefreshAllBuffers()) UpdateDashboard();
      }
      if(TimeCurrent() - g_lastAPIUpdate >= AI_UpdateInterval_sec)
      {
         if(UseRenderAPI) UpdateFromDecision();
      }
      return;
   }

   // --- Pas de position : ne faire le travail lourd qu'à la nouvelle barre (évite rame)
   static datetime s_lastGraphicsUpdate = 0;
   static datetime s_lastDashboardUpdate = 0;
   static datetime s_lastBarTime = 0;
   static datetime s_lastBufferUpdate = 0;
   static datetime lastLogLocalFilter = 0;
   datetime barTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (barTime != s_lastBarTime);
   if(isNewBar) s_lastBarTime = barTime;

   // Objectif journalier atteint → on arrête de trader aujourd'hui
   // ────────────────────────────────────────────────
   if(current_daily_net >= 50.0)   // Augmenté pour tests (était 10$)
   {
      if(TimeCurrent() - last_daily_profit_check_time >= 300) // Message toutes les 5 minutes au lieu d'une heure
      {
         PrintFormat("🎯 Objectif journalier NET atteint : +%.2f USD → plus de trades aujourd'hui", current_daily_net);
         last_daily_profit_check_time = TimeCurrent();
      }
      return;   // ← on sort immédiatement de OnTick()
   }

   bool timerGraphics = (TimeCurrent() - s_lastGraphicsUpdate >= GraphicsRefresh_sec);
   bool timerDashboard = ShowDashboard && (TimeCurrent() - s_lastDashboardUpdate >= DashboardRefresh_sec);
   bool updateBuffers = isNewBar || (TimeCurrent() - s_lastBufferUpdate >= 30); // Max 1x/30sec
   if(updateBuffers) s_lastBufferUpdate = TimeCurrent();
   bool doHeavyWork = isNewBar || timerGraphics || timerDashboard;

   if(EntryOnNewBarOnly && !doHeavyWork)
      return;

   // Vérification rapide des buffers de base (seulement si nécessaire)
   if(updateBuffers)
   {
      if(ArraySize(ma_buffer) < 1 || ArraySize(rsi_buffer) < 1)
         return;
      
      double close_price[1];
      if(CopyBuffer(ma_handle, 0, 1, 1, ma_buffer) <= 0 ||
         CopyBuffer(rsi_handle, 0, 1, 1, rsi_buffer) <= 0 ||
         CopyClose(_Symbol, _Period, 1, 1, close_price) <= 0)
         return;
      CopyBuffer(atr_handle, 0, 0, 1, atr_buffer);
   }

   double ask = last_tick.ask;
   double bid = last_tick.bid;

   if(TimeCurrent() - g_lastAPIUpdate >= AI_UpdateInterval_sec)
   {
      g_lastAPIUpdate = TimeCurrent();
      if(UseRenderAPI) UpdateFromDecision();
   }

   if(timerGraphics)
   {
      s_lastGraphicsUpdate = TimeCurrent();
      UpdateGraphics();
   }
   if(timerDashboard)
   {
      s_lastDashboardUpdate = TimeCurrent();
      UpdateDashboard();
   }

   if(isNewBar || !EntryOnNewBarOnly)
   {
      // ─────────────────────────────────────────────────────────────
      // Filtre local de sécurité – doit être validé EN PLUS de l'IA
      // ─────────────────────────────────────────────────────────────
      string filterReason = "";
      if(!IsLocalFilterValid(g_lastAIAction, g_lastAIConfidence, filterReason))
      {
         if(TimeCurrent() - g_lastLocalFilterLog > 120) // log toutes les 2 minutes max
         {
            Print("Filtre local → TRADE BLOQUÉ | Raison : ", filterReason);
            g_lastLocalFilterLog = TimeCurrent();
         }
         return;  // ou continue; selon où tu es exactement dans OnTick()
      }
      else
      {
         Print("Filtre local → VALIDÉ | ", filterReason);
      }

      OpenNewPositions();
      // Placer ordres limite lors d'alignement sur tableau de bord
      if(PlaceLimitOrdersOnAlignmentEnabled) PlaceLimitOrdersOnAlignment();
   }

   // Gestion du trailing stop et breakeven
   static datetime lastTrailCheck = 0;
   if(TimeCurrent() - lastTrailCheck >= 5)
   {
      ManageTrailingAndBreakeven();
      lastTrailCheck = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Fonction helper pour créer les labels du dashboard               |
//+------------------------------------------------------------------+
void CreateDashboardLabel(string name, string text, int x, int y, color clr, int fontSize=10)
{
   string objName = "DASH_LEFT_" + name;
   if(ObjectFind(0, objName) >= 0) ObjectDelete(0, objName);
   
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Fonction de mise à jour du dashboard gauche                      |
//+------------------------------------------------------------------+
void UpdateLeftDashboard()
{
   // Calculs pour dashboard (basés sur étapes 1–3D)
   double dailyNetProfit = CalculateDailyNetProfit();  // Étape 1
   string profitStatus = (dailyNetProfit >= 10.0) ? "ATTEINT (stop trades)" : StringFormat("%.2f $ / 10.0 $", dailyNetProfit);
   color profitColor = (dailyNetProfit >= 10.0) ? colorOK : (dailyNetProfit > 0 ? colorWarn : colorAlert);
   
   double lotExample = CalculateRiskBasedLotSize(InpRiskPercentPerTrade, StopLoss_Pips);  // Étape 2
   string riskStatus = StringFormat("Risque/trade: %.1f %% → Lot: %.2f", InpRiskPercentPerTrade, lotExample);
   
   // Étape 3A/D : filtre local
   string filterReason = "";
   bool filterValid = IsLocalFilterValid(g_lastAIAction, g_lastAIConfidence, filterReason);  // Utilise ta fonction renforcée
   string filterStatus = filterValid ? "VALIDÉ" : "REFUSÉ";
   color filterColor = filterValid ? colorOK : colorAlert;
   
   // Étape 3B : statut breakeven/trailing
   int openPositions = PositionsTotal();
   string trailStatus = (openPositions > 0) ? StringFormat("%d positions ouvertes (trailing actif)", openPositions) : "Aucune position (breakeven prêt)";
   
   // Confiance IA (étape 3D fallback)
   string aiStatus = StringFormat("Confiance IA: %.2f %% (%s)", g_lastAIConfidence * 100, (g_lastAIConfidence >= 0.78) ? "OK" : "Fallback renforcé");
   color aiColor = (g_lastAIConfidence >= 0.78) ? colorOK : colorWarn;
   
   // ────────────────────────────────
   // Création des labels (coin gauche)
   // ────────────────────────────────
   int lineY = dashboardY;  // Commence en haut gauche
   
   CreateDashboardLabel("Dash_Profit", "Profit Net Jour: " + profitStatus, dashboardX, lineY, profitColor);
   lineY += 20;
   
   CreateDashboardLabel("Dash_Risk", riskStatus, dashboardX, lineY, clrWhite);
   lineY += 20;
   
   CreateDashboardLabel("Dash_FilterLocal", "Filtre Local: " + filterStatus + " (" + filterReason + ")", dashboardX, lineY, filterColor);
   lineY += 20;
   
   CreateDashboardLabel("Dash_TrailBE", "Breakeven/Trailing: " + trailStatus, dashboardX, lineY, clrWhite);
   lineY += 20;
   
   CreateDashboardLabel("Dash_AI", aiStatus, dashboardX, lineY, aiColor);
   lineY += 20;
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
   
   // Vérification rapide des buffers de base
   if(ArraySize(ma_buffer) < 1 || ArraySize(rsi_buffer) < 1)
      return;

   double ma_val = ma_buffer[0];
   double rsi_val = rsi_buffer[0];

   // Vérifier le type de symbole
   bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
   bool is_crash = (StringFind(_Symbol, "Crash") >= 0);

   // Signaux techniques BASIQUES (optimisés - pas d'EMA multi-timeframe inutiles)
   double ema_fast_val = (ArraySize(emaFastM1_buffer) > 0) ? emaFastM1_buffer[0] : ma_val;
   double ema_slow_val = (ArraySize(emaSlowM1_buffer) > 0) ? emaSlowM1_buffer[0] : ma_val;
   bool tech_buy_m1 = (price > ema_fast_val && rsi_val < RSI_Oversold_Level);
   bool tech_sell_m1 = (price < ema_fast_val && rsi_val > RSI_Overbought_Level);

   // Signaux IA
   bool ai_buy = (current_ai_signal.action == "BUY" && current_ai_signal.confidence > MinAPIConfidence);
   bool ai_sell = (current_ai_signal.action == "SELL" && current_ai_signal.confidence > MinAPIConfidence);
   bool api_required = RequireAPIToOpen;
   bool allow_buy = tech_buy_m1 && (ai_buy || !api_required);
   bool allow_sell = tech_sell_m1 && (ai_sell || !api_required);
   
   // DÉTECTION PRÉ-SPIKE : seulement si buffers EMA M1 disponibles (optimisé)
   if(ArraySize(emaFastM1_buffer) >= 1 && ArraySize(emaSlowM1_buffer) >= 1 && UseSpikeDetection)
   {
      // Utiliser seulement EMA M1 pour la détection de spike (plus rapide)
      bool is_spike_buy = IsLocalSpikeBoom(ma_val, rsi_val);
      bool is_spike_sell = IsLocalSpikeCrash(ma_val, rsi_val);
      
      if(is_boom && is_spike_buy && !allow_buy)
         allow_buy = true;
      if(is_crash && is_spike_sell && !allow_sell)
         allow_sell = true;
   }
   
   // SYSTÈME AVANCÉ : désactivé - fonctions non disponibles
   bool advanced_buy_signal = false;
   bool advanced_sell_signal = false;
   
   /*
   if(UseAdvancedStrategies && (TimeCurrent() - g_lastAdvancedUpdate >= AdvancedUpdateInterval))
   {
      g_lastAdvancedUpdate = TimeCurrent();
      advanced_buy_signal = ShouldExecuteTrade(true, AdvancedMinConfidence);
      advanced_sell_signal = ShouldExecuteTrade(false, AdvancedMinConfidence);
      
      Print(" STRATÉGIES AVANCÉES - BUY Score: ", DoubleToString(g_buySignal.total_score, 1), "% (", g_buySignal.strategies_count, " stratégies)");
      Print(" STRATÉGIES AVANCÉES - SELL Score: ", DoubleToString(g_sellSignal.total_score, 1), "% (", g_sellSignal.strategies_count, " stratégies)");
   }
   */
   
   // Vérification anti-spike avant d'ouvrir un trade
   if(IsSpikeRiskTooHigh()) return;
   
   // Logique d'ouverture SIMPLIFIÉE
   if(is_boom)
   {
      // Boom: seulement BUY
      if(allow_buy && (advanced_buy_signal || !UseAdvancedStrategies))
      {
         double tradeRiskPercent = InpRiskPercentPerTrade;
         if(InpFixedRiskUSD > 0.0)
         {
            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            tradeRiskPercent = (InpFixedRiskUSD / balance) * 100.0;
         }

         // On suppose que tu as déjà calculé sl_points (distance SL en points)
         double sl_points = 300.0; // Default SL points for Boom/Crash
         double lotToUse = CalculateRiskBasedLotSize(tradeRiskPercent, sl_points);

         // Sécurité ultime
         if(lotToUse < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            Print("Lot trop petit → trade annulé");
            return;
         }

         if(trade.Buy(lotToUse, _Symbol, ask, 0, 0, "BoomCrash Boom BUY (Stratégie Optimisée)"))
         {
            g_lastSpikeType = "BOOM";
            g_lastSpikeTime = TimeCurrent();
            g_lastEntryPrice = ask;
            g_lastEntryTime = TimeCurrent();
            Print("🚀 BOOM BUY OUVERT - Mode Ultra-Léger Optimisé");
            CreateSpikeArrow();
         }
      }
   }
   else if(is_crash)
   {
      // Crash: seulement SELL
      if(allow_sell && (advanced_sell_signal || !UseAdvancedStrategies))
      {
         double tradeRiskPercent = InpRiskPercentPerTrade;
         if(InpFixedRiskUSD > 0.0)
         {
            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            tradeRiskPercent = (InpFixedRiskUSD / balance) * 100.0;
         }

         // On suppose que tu as déjà calculé sl_points (distance SL en points)
         double sl_points = 300.0; // Default SL points for Boom/Crash
         double lotToUse = CalculateRiskBasedLotSize(tradeRiskPercent, sl_points);

         // Sécurité ultime
         if(lotToUse < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            Print("Lot trop petit → trade annulé");
            return;
         }

         if(trade.Sell(lotToUse, _Symbol, bid, 0, 0, "BoomCrash Crash SELL (Stratégie Optimisée)"))
         {
            g_lastSpikeType = "CRASH";
            g_lastSpikeTime = TimeCurrent();
            g_lastEntryPrice = bid;
            g_lastEntryTime = TimeCurrent();
            Print("🚀 CRASH SELL OUVERT - Mode Ultra-Léger Optimisé");
            CreateSpikeArrow();
         }
      }
   }
   
   // DIAGNOSTIC DÉTAILLÉ (toutes les 20 s)
   if(DebugLog)
   {
      static datetime s_lastDetailedLog = 0;
      if(TimeCurrent() - s_lastDetailedLog >= 20)
      {
         s_lastDetailedLog = TimeCurrent();
         Print("═══════════════════════════════════════════════════");
         Print("🔍 DIAGNOSTIC BOOMCRASH - ", _Symbol);
         Print("───────────────────────────────────────────────────");
         Print("📊 Prix: ", DoubleToString(price, _Digits), " | MA(", MA_Period, "): ", DoubleToString(ma_val, _Digits));
         Print("📈 RSI: ", DoubleToString(rsi_val, 1), " (Survente<", RSI_Oversold_Level, ", Surachat>", RSI_Overbought_Level, ")");
         Print("───────────────────────────────────────────────────");
         Print("🎯 Type: ", is_boom ? "BOOM" : (is_crash ? "CRASH" : "AUTRE"));
         Print("📊 Conditions Techniques:");
         Print("   • tech_buy_m1 = ", tech_buy_m1 ? "✅ OUI" : "❌ NON", " (prix>MA && RSI<", RSI_Oversold_Level, ")");
         Print("   • tech_sell_m1 = ", tech_sell_m1 ? "✅ OUI" : "❌ NON", " (prix<MA && RSI>", RSI_Overbought_Level, ")");
         Print("🤖 Signaux IA:");
         Print("   • Action IA: ", current_ai_signal.action, " | Confiance: ", DoubleToString(current_ai_signal.confidence * 100, 1), "%");
         Print("   • ai_buy = ", ai_buy ? "✅ OUI" : "❌ NON", " (action=BUY && conf>", DoubleToString(MinAPIConfidence, 2), ")");
         Print("   • ai_sell = ", ai_sell ? "✅ OUI" : "❌ NON", " (action=SELL && conf>", DoubleToString(MinAPIConfidence, 2), ")");
         Print("   • RequireAPIToOpen = ", api_required ? "OUI (bloquant)" : "NON (optionnel)");
         Print("───────────────────────────────────────────────────");
         Print("✅ Conditions Finales:");
         Print("   • allow_buy = ", allow_buy ? "✅ OUI" : "❌ NON");
         Print("   • allow_sell = ", allow_sell ? "✅ OUI" : "❌ NON");
         
         if(is_boom && !allow_buy)
         {
            Print("⚠️ BOOM: Pas d'ouverture BUY car:");
            if(!tech_buy_m1) Print("   ❌ Conditions techniques non remplies (prix<=MA ou RSI>=", RSI_Oversold_Level, ")");
            if(api_required && !ai_buy) Print("   ❌ IA requise mais pas de signal BUY valide");
         }
         else if(is_crash && !allow_sell)
         {
            Print("⚠️ CRASH: Pas d'ouverture SELL car:");
            if(!tech_sell_m1) Print("   ❌ Conditions techniques non remplies (prix>=MA ou RSI<=", RSI_Overbought_Level, ")");
            if(api_required && !ai_sell) Print("   ❌ IA requise mais pas de signal SELL valide");
         }
         Print("═══════════════════════════════════════════════════");
      }
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
   // Confirmation multi-timeframe: RSI M5 en zone basse (évite faux signaux)
   if(rsiM5_handle != INVALID_HANDLE && CopyBuffer(rsiM5_handle, 0, 0, 1, rsiM5_buffer) > 0 &&
      rsiM5_buffer[0] > 45) return false;  // RSI M5 pas en survente
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
   // Confirmation multi-timeframe: RSI M5 en zone haute
   if(rsiM5_handle != INVALID_HANDLE && CopyBuffer(rsiM5_handle, 0, 0, 1, rsiM5_buffer) > 0 &&
      rsiM5_buffer[0] < 55) return false;  // RSI M5 pas en surachat
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
      double new_sl = last_tick.bid - InpTrailDist * _Point;
      if(last_tick.bid > open_price + InpTrailDist * _Point && new_sl > current_sl)
         trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      double new_sl = last_tick.ask + InpTrailDist * _Point;
      if(last_tick.ask < open_price - InpTrailDist * _Point && (new_sl < current_sl || current_sl == 0))
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
    
    // JSON strict DecisionRequest (pas de champs extra pour éviter 422)
    if(ask <= bid)
       ask = bid + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2;
    string safeSymbol = _Symbol;
    StringReplace(safeSymbol, "\\", "\\\\");
    StringReplace(safeSymbol, "\"", "\\\"");
    string data = "{";
    data += "\"symbol\":\"" + safeSymbol + "\"";
    data += ",\"bid\":" + DoubleToString(bid, 5);
    data += ",\"ask\":" + DoubleToString(ask, 5);
    data += ",\"rsi\":" + DoubleToString(rsi_val, 2);
    data += ",\"atr\":" + DoubleToString(atr_val, 6);
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
        g_lastAIAction = current_ai_signal.action;
        g_lastAIConfidence = current_ai_signal.confidence;
        if(DebugLog) Print("✅ /decision 200 OK | action=", current_ai_signal.action, " confidence=", DoubleToString(current_ai_signal.confidence * 100, 1), "%");
    }
    else if(res == 422)
    {
        if(DebugLog)
        {
            Print("⚠️ /decision 422 - Le serveur a rejeté la requête (format ou validation).");
            Print("   Si vous utilisez ai_server en LOCAL, définir AI_ServerURL = http://127.0.0.1:8000/decision");
            Print("   et ajouter cette URL dans MT5: Outils > Options > Expert Advisors > WebRequest.");
            Print("   Data envoyée: ", StringSubstr(data, 0, 180));
        }
        current_ai_signal.action = "HOLD";
        current_ai_signal.confidence = 0.0;
        g_lastAIAction = "HOLD";
        g_lastAIConfidence = 0.0;
    }
    else if(DebugLog)
    {
        if(res == -1)
            Print("⚠️ /decision échec WebRequest (-1): vérifier URL dans MT5 (WebRequest autorisées) et que le serveur est démarré.");
        else
            Print("⚠️ /decision HTTP: ", res);
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
//| Rafraîchit tous les buffers d'indicateurs                        |
//+------------------------------------------------------------------+
bool RefreshAllBuffers()
{
   // Copier les données des indicateurs principaux seulement
   bool success = true;
   
   // Indicateurs essentiels uniquement
   if(CopyBuffer(ma_handle, 0, 0, 2, ma_buffer) <= 0) success = false;
   if(CopyBuffer(rsi_handle, 0, 0, 2, rsi_buffer) <= 0) success = false;
   if(CopyBuffer(atr_handle, 0, 0, 2, atr_buffer) <= 0) success = false;
   
   // EMA M1 seulement (plus important pour Boom/Crash)
   if(CopyBuffer(emaFastM1_handle, 0, 0, 2, emaFastM1_buffer) <= 0) success = false;
   if(CopyBuffer(emaSlowM1_handle, 0, 0, 2, emaSlowM1_buffer) <= 0) success = false;
   
   // Les autres EMA seulement si nécessaire (économie de CPU)
   static datetime s_lastMultiTimeframeUpdate = 0;
   if(TimeCurrent() - s_lastMultiTimeframeUpdate >= 60) // 1x/minute max
   {
      s_lastMultiTimeframeUpdate = TimeCurrent();
      if(CopyBuffer(emaFastM5_handle, 0, 0, 2, emaFastM5_buffer) <= 0) success = false;
      if(CopyBuffer(emaSlowM5_handle, 0, 0, 2, emaSlowM5_buffer) <= 0) success = false;
      if(CopyBuffer(emaFastH1_handle, 0, 0, 2, emaFastH1_buffer) <= 0) success = false;
      if(CopyBuffer(emaSlowH1_handle, 0, 0, 2, emaSlowH1_buffer) <= 0) success = false;
   }
   
   // RSI M5 optionnel
   if(rsiM5_handle != INVALID_HANDLE)
   {
      if(CopyBuffer(rsiM5_handle, 0, 0, 2, rsiM5_buffer) <= 0) success = false;
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
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
    
    // Rafraîchir les buffers avant utilisation
    if(CopyBuffer(ma_handle, 0, 0, 1, ma_buffer) <= 0) return;
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) <= 0) return;
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0) return;
    
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
    if(ShowMA && ArraySize(emaFastM1_buffer) > 0 && ArraySize(emaSlowM1_buffer) > 0)
    {
        string n1 = "BoomCrash_EMA_Fast_M1", n2 = "BoomCrash_EMA_Slow_M1";
        if(ObjectFind(0, n1) < 0) { ObjectCreate(0, n1, OBJ_HLINE, 0, 0, emaFastM1_buffer[0]); ObjectSetInteger(0, n1, OBJPROP_COLOR, clrGreen); ObjectSetInteger(0, n1, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n1, 0, 0, emaFastM1_buffer[0]);
        if(ObjectFind(0, n2) < 0) { ObjectCreate(0, n2, OBJ_HLINE, 0, 0, emaSlowM1_buffer[0]); ObjectSetInteger(0, n2, OBJPROP_COLOR, clrRed); ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n2, 0, 0, emaSlowM1_buffer[0]);
    }
    if(ShowMA && ArraySize(emaFastM5_buffer) > 0 && ArraySize(emaSlowM5_buffer) > 0)
    {
        string n1 = "BoomCrash_EMA_Fast_M5", n2 = "BoomCrash_EMA_Slow_M5";
        if(ObjectFind(0, n1) < 0) { ObjectCreate(0, n1, OBJ_HLINE, 0, 0, emaFastM5_buffer[0]); ObjectSetInteger(0, n1, OBJPROP_COLOR, clrLime); ObjectSetInteger(0, n1, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n1, 0, 0, emaFastM5_buffer[0]);
        if(ObjectFind(0, n2) < 0) { ObjectCreate(0, n2, OBJ_HLINE, 0, 0, emaSlowM5_buffer[0]); ObjectSetInteger(0, n2, OBJPROP_COLOR, clrOrange); ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n2, 0, 0, emaSlowM5_buffer[0]);
    }
    if(ShowMA && ArraySize(emaFastH1_buffer) > 0 && ArraySize(emaSlowH1_buffer) > 0)
    {
        string n1 = "BoomCrash_EMA_Fast_H1", n2 = "BoomCrash_EMA_Slow_H1";
        if(ObjectFind(0, n1) < 0) { ObjectCreate(0, n1, OBJ_HLINE, 0, 0, emaFastH1_buffer[0]); ObjectSetInteger(0, n1, OBJPROP_COLOR, clrBlue); ObjectSetInteger(0, n1, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n1, 0, 0, emaFastH1_buffer[0]);
        if(ObjectFind(0, n2) < 0) { ObjectCreate(0, n2, OBJ_HLINE, 0, 0, emaSlowH1_buffer[0]); ObjectSetInteger(0, n2, OBJPROP_COLOR, clrPurple); ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2); }
        else ObjectMove(0, n2, 0, 0, emaSlowH1_buffer[0]);
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
    
    // === CANAL PRÉDICTIF DES ZONES DE SPIKE (prix ± ATR * mult) ===
    double atr_val = (ArraySize(atr_buffer) > 0) ? atr_buffer[0] : 0;
    if(atr_val <= 0 && CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) atr_val = atr_buffer[0];
    if(ShowSpikeChannel && atr_val > 0)
    {
        double mid = current_price;
        double upper = mid + SpikeChannelATRMult * atr_val;
        double lower = mid - SpikeChannelATRMult * atr_val;
        string ch_upper = "BoomCrash_SpikeChannel_Upper", ch_lower = "BoomCrash_SpikeChannel_Lower";
        string ch_label = "BoomCrash_SpikeChannel_Label";
        if(ObjectFind(0, ch_upper) < 0) { ObjectCreate(0, ch_upper, OBJ_HLINE, 0, 0, upper); ObjectSetInteger(0, ch_upper, OBJPROP_COLOR, SpikeChannelColor); ObjectSetInteger(0, ch_upper, OBJPROP_WIDTH, 1); ObjectSetInteger(0, ch_upper, OBJPROP_STYLE, STYLE_DOT); }
        else ObjectMove(0, ch_upper, 0, 0, upper);
        if(ObjectFind(0, ch_lower) < 0) { ObjectCreate(0, ch_lower, OBJ_HLINE, 0, 0, lower); ObjectSetInteger(0, ch_lower, OBJPROP_COLOR, SpikeChannelColor); ObjectSetInteger(0, ch_lower, OBJPROP_WIDTH, 1); ObjectSetInteger(0, ch_lower, OBJPROP_STYLE, STYLE_DOT); }
        else ObjectMove(0, ch_lower, 0, 0, lower);
        if(ObjectFind(0, ch_label) < 0)
        {
            ObjectCreate(0, ch_label, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, ch_label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, ch_label, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, ch_label, OBJPROP_YDISTANCE, 90);
            ObjectSetInteger(0, ch_label, OBJPROP_FONTSIZE, 9);
        }
        ObjectSetString(0, ch_label, OBJPROP_TEXT, "Zone Spike ±" + DoubleToString(SpikeChannelATRMult, 1) + " ATR");
        ObjectSetInteger(0, ch_label, OBJPROP_COLOR, SpikeChannelColor);
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
//| Supprime les objets obsolètes du tableau de bord                  |
//+------------------------------------------------------------------+
void CleanOldDashboardObjects()
{
   string prefix = "BoomCrash_Dash_";
   int total = ObjectsTotal(0, 0, -1);
   
   for(int i = total-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0) // Si le nom commence par le préfixe
      {
         datetime createTime = (datetime)ObjectGetInteger(0, name, OBJPROP_CREATETIME);
         if(TimeCurrent() - createTime > 300) // Supprimer les objets de plus de 5 minutes
         {
            ObjectDelete(0, name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Tableau de bord complet enrichi (infos, alertes spike, entrées, durée)   |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   static bool s_dash_created = false;
   static datetime s_lastCleanup = 0;
   static datetime s_lastFullUpdate = 0;
   const int x_start = 10, line_height = 16, font_size = 9;
   color text_color = clrWhite, header_color = clrGold;

   // Nettoyer les objets obsolètes toutes les 120 secondes (au lieu de 60)
   if(TimeCurrent() - s_lastCleanup > 120)
   {
      CleanOldDashboardObjects();
      s_lastCleanup = TimeCurrent();
   }

   // Mise à jour complète seulement toutes les 30 secondes (au lieu de chaque appel)
   bool doFullUpdate = (TimeCurrent() - s_lastFullUpdate >= 30);
   if(doFullUpdate) s_lastFullUpdate = TimeCurrent();

   // Rafraîchir les buffers essentiels seulement (pas tous les EMA à chaque fois)
   bool buffers_ok = true;
   if(CopyBuffer(ma_handle, 0, 0, 1, ma_buffer) <= 0) { ArrayResize(ma_buffer, 1); ma_buffer[0] = 0; buffers_ok = false; }
   if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) <= 0) { ArrayResize(rsi_buffer, 1); rsi_buffer[0] = 0; buffers_ok = false; }
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0) { ArrayResize(atr_buffer, 1); atr_buffer[0] = 0; buffers_ok = false; }
   
   // EMA M1 seulement (plus important)
   if(CopyBuffer(emaFastM1_handle, 0, 0, 1, emaFastM1_buffer) <= 0) { ArrayResize(emaFastM1_buffer, 1); emaFastM1_buffer[0] = 0; buffers_ok = false; }
   if(CopyBuffer(emaSlowM1_handle, 0, 0, 1, emaSlowM1_buffer) <= 0) { ArrayResize(emaSlowM1_buffer, 1); emaSlowM1_buffer[0] = 0; buffers_ok = false; }
   
   // Autres EMA seulement si mise à jour complète
   if(doFullUpdate)
   {
      if(CopyBuffer(emaFastM5_handle, 0, 0, 1, emaFastM5_buffer) <= 0) { ArrayResize(emaFastM5_buffer, 1); emaFastM5_buffer[0] = 0; buffers_ok = false; }
      if(CopyBuffer(emaSlowM5_handle, 0, 0, 1, emaSlowM5_buffer) <= 0) { ArrayResize(emaSlowM5_buffer, 1); emaSlowM5_buffer[0] = 0; buffers_ok = false; }
      if(CopyBuffer(emaFastH1_handle, 0, 0, 1, emaFastH1_buffer) <= 0) { ArrayResize(emaFastH1_buffer, 1); emaFastH1_buffer[0] = 0; buffers_ok = false; }
      if(CopyBuffer(emaSlowH1_handle, 0, 0, 1, emaSlowH1_buffer) <= 0) { ArrayResize(emaSlowH1_buffer, 1); emaSlowH1_buffer[0] = 0; buffers_ok = false; }
   }
   
   // Log si les buffers ne sont pas prêts (une seule fois toutes les 60s)
   if(!buffers_ok)
   {
      static datetime s_lastBufferWarning = 0;
      if(TimeCurrent() - s_lastBufferWarning >= 60)
      {
         s_lastBufferWarning = TimeCurrent();
         Print("⚠️ DASHBOARD: Certains indicateurs ne sont pas encore prêts. Affichage de 0 en attendant.");
      }
   }

   // Création une seule fois (réduit charge CPU au rafraîchissement)
   if(!s_dash_created)
   {
      s_dash_created = true;
      string bg_name = "BoomCrash_Dash_BG";
      ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, x_start - 5);
      ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, 380);
      ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, 620);
      ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, bg_name, OBJPROP_SELECTABLE, false);
      string names[] = {
         "BoomCrash_Dash_Title",
         "BoomCrash_Dash_InfoHeader",
         "BoomCrash_Dash_Price",
         "BoomCrash_Dash_RSI",
         "BoomCrash_Dash_MA",
         "BoomCrash_Dash_EMA_M1",
         "BoomCrash_Dash_EMA_M5",
         "BoomCrash_Dash_EMA_H1",
         "BoomCrash_Dash_ATR",
         "BoomCrash_Dash_Volatility",
         "BoomCrash_Dash_SignalsHeader",
         "BoomCrash_Dash_TechBuy",
         "BoomCrash_Dash_TechSell",
         "BoomCrash_Dash_AlignBuy",
         "BoomCrash_Dash_AlignSell",
         "BoomCrash_Dash_APIHeader",
         "BoomCrash_Dash_AIAction",
         "BoomCrash_Dash_Trend",
         "BoomCrash_Dash_APITime",
         "BoomCrash_Dash_SpikeHeader",
         "BoomCrash_Dash_SpikeType",
         "BoomCrash_Dash_EntryPrice",
         "BoomCrash_Dash_Duration",
         "BoomCrash_Dash_AlertTime",
         "BoomCrash_Dash_PosHeader",
         "BoomCrash_Dash_PosStatus",
         "BoomCrash_Dash_PosPnL",
         "BoomCrash_Dash_PosSLTP",
         "BoomCrash_Dash_LimitHeader",
         "BoomCrash_Dash_LimitBuyStatus",
         "BoomCrash_Dash_LimitSellStatus"
      };
      int y = 25;
      for(int i = 0; i < ArraySize(names); i++)
      {
         if(ObjectFind(0, names[i]) < 0)
         {
            ObjectCreate(0, names[i], OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, names[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, names[i], OBJPROP_XDISTANCE, x_start);
            ObjectSetInteger(0, names[i], OBJPROP_YDISTANCE, y);
            ObjectSetInteger(0, names[i], OBJPROP_FONTSIZE, font_size);
            ObjectSetInteger(0, names[i], OBJPROP_COLOR, text_color);
         }
         y += line_height;
         if(i == 0 || i == 1 || i == 10 || i == 15 || i == 19 || i == 24) y += 3;
      }
   }

   // Mise à jour du texte uniquement (léger)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = bid;
   double rsi_val = (ArraySize(rsi_buffer) > 0) ? rsi_buffer[0] : 0;
   double ma_val = (ArraySize(ma_buffer) > 0) ? ma_buffer[0] : 0;
   double ema_fast_m1_val = (ArraySize(emaFastM1_buffer) > 0) ? emaFastM1_buffer[0] : 0;
   double ema_slow_m1_val = (ArraySize(emaSlowM1_buffer) > 0) ? emaSlowM1_buffer[0] : 0;
   double ema_fast_m5_val = (ArraySize(emaFastM5_buffer) > 0) ? emaFastM5_buffer[0] : 0;
   double ema_slow_m5_val = (ArraySize(emaSlowM5_buffer) > 0) ? emaSlowM5_buffer[0] : 0;
   double ema_fast_h1_val = (ArraySize(emaFastH1_buffer) > 0) ? emaFastH1_buffer[0] : 0;
   double ema_slow_h1_val = (ArraySize(emaSlowH1_buffer) > 0) ? emaSlowH1_buffer[0] : 0;
   double atr_val = 0;
   if(ArraySize(atr_buffer) > 0) atr_val = atr_buffer[0];
   else if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) atr_val = atr_buffer[0];
   long duration_sec = (g_lastSpikeTime > 0) ? (long)(TimeCurrent() - g_lastSpikeTime) : 0;
   
   // Calculs des signaux techniques
   bool tech_buy_m1 = (price > ema_fast_m1_val && rsi_val < RSI_Oversold_Level);
   bool tech_sell_m1 = (price < ema_fast_m1_val && rsi_val > RSI_Overbought_Level);
   bool trend_alignment_buy = (ema_fast_m1_val > ema_slow_m1_val) && (ema_fast_m5_val > ema_slow_m5_val);
   bool trend_alignment_sell = (ema_fast_m1_val < ema_slow_m1_val) && (ema_fast_m5_val < ema_slow_m5_val);
   bool ai_buy = (current_ai_signal.action == "BUY" && current_ai_signal.confidence > MinAPIConfidence);
   bool ai_sell = (current_ai_signal.action == "SELL" && current_ai_signal.confidence > MinAPIConfidence);
   bool allow_buy = tech_buy_m1 && trend_alignment_buy && (ai_buy || !RequireAPIToOpen);
   bool allow_sell = tech_sell_m1 && trend_alignment_sell && (ai_sell || !RequireAPIToOpen);
   
   // Calcul volatilité (ATR / prix)
   double volatility_pct = (atr_val > 0 && price > 0) ? (atr_val / price) * 100.0 : 0;

   // === TITRE ===
   ObjectSetString(0, "BoomCrash_Dash_Title", OBJPROP_TEXT, "═══════ TABLEAU DE BORD ═══════");
   ObjectSetInteger(0, "BoomCrash_Dash_Title", OBJPROP_COLOR, header_color);
   ObjectSetInteger(0, "BoomCrash_Dash_Title", OBJPROP_FONTSIZE, 10);

   // === INFORMATIONS MARCHÉ ===
   ObjectSetString(0, "BoomCrash_Dash_InfoHeader", OBJPROP_TEXT, "📊 INFORMATIONS MARCHÉ");
   ObjectSetInteger(0, "BoomCrash_Dash_InfoHeader", OBJPROP_COLOR, header_color);
   ObjectSetString(0, "BoomCrash_Dash_Price", OBJPROP_TEXT, _Symbol + " | Bid: " + DoubleToString(bid, _Digits) + " | Ask: " + DoubleToString(ask, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_RSI", OBJPROP_TEXT, "RSI(" + IntegerToString(RSI_Period) + "): " + DoubleToString(rsi_val, 2));
   ObjectSetInteger(0, "BoomCrash_Dash_RSI", OBJPROP_COLOR, (rsi_val < RSI_Oversold_Level) ? clrLime : (rsi_val > RSI_Overbought_Level) ? clrRed : text_color);
   ObjectSetString(0, "BoomCrash_Dash_MA", OBJPROP_TEXT, "MA(" + IntegerToString(MA_Period) + "): " + DoubleToString(ma_val, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_EMA_M1", OBJPROP_TEXT, "EMA M1: " + DoubleToString(ema_fast_m1_val, _Digits) + " / " + DoubleToString(ema_slow_m1_val, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_EMA_M5", OBJPROP_TEXT, "EMA M5: " + DoubleToString(ema_fast_m5_val, _Digits) + " / " + DoubleToString(ema_slow_m5_val, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_EMA_H1", OBJPROP_TEXT, "EMA H1: " + DoubleToString(ema_fast_h1_val, _Digits) + " / " + DoubleToString(ema_slow_h1_val, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_ATR", OBJPROP_TEXT, "ATR(" + IntegerToString(ATR_Period) + "): " + DoubleToString(atr_val, _Digits));
   ObjectSetString(0, "BoomCrash_Dash_Volatility", OBJPROP_TEXT, "Volatilité: " + DoubleToString(volatility_pct, 2) + "%");
   ObjectSetInteger(0, "BoomCrash_Dash_Volatility", OBJPROP_COLOR, (volatility_pct > 1.0) ? clrOrange : text_color);

   // === SIGNAUX TECHNIQUES ===
   ObjectSetString(0, "BoomCrash_Dash_SignalsHeader", OBJPROP_TEXT, "🎯 SIGNAUX TECHNIQUES");
   ObjectSetInteger(0, "BoomCrash_Dash_SignalsHeader", OBJPROP_COLOR, header_color);
   ObjectSetString(0, "BoomCrash_Dash_TechBuy", OBJPROP_TEXT, "Tech BUY: " + (tech_buy_m1 ? "✅" : "❌"));
   ObjectSetInteger(0, "BoomCrash_Dash_TechBuy", OBJPROP_COLOR, tech_buy_m1 ? clrLime : clrGray);
   ObjectSetString(0, "BoomCrash_Dash_TechSell", OBJPROP_TEXT, "Tech SELL: " + (tech_sell_m1 ? "✅" : "❌"));
   ObjectSetInteger(0, "BoomCrash_Dash_TechSell", OBJPROP_COLOR, tech_sell_m1 ? clrRed : clrGray);
   ObjectSetString(0, "BoomCrash_Dash_AlignBuy", OBJPROP_TEXT, "Alignement BUY: " + (trend_alignment_buy ? "✅" : "❌"));
   ObjectSetInteger(0, "BoomCrash_Dash_AlignBuy", OBJPROP_COLOR, trend_alignment_buy ? clrLime : clrGray);
   ObjectSetString(0, "BoomCrash_Dash_AlignSell", OBJPROP_TEXT, "Alignement SELL: " + (trend_alignment_sell ? "✅" : "❌"));
   ObjectSetInteger(0, "BoomCrash_Dash_AlignSell", OBJPROP_COLOR, trend_alignment_sell ? clrRed : clrGray);

   // === ÉTAT API ===
   ObjectSetString(0, "BoomCrash_Dash_APIHeader", OBJPROP_TEXT, "🤖 ÉTAT API");
   ObjectSetInteger(0, "BoomCrash_Dash_APIHeader", OBJPROP_COLOR, header_color);
   string aiActionText = g_lastAIAction;
   StringToUpper(aiActionText);
   ObjectSetString(0, "BoomCrash_Dash_AIAction", OBJPROP_TEXT, "IA: " + aiActionText + " " + DoubleToString(g_lastAIConfidence * 100, 1) + "%");
   color dash_ai_color = clrGray;
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy") dash_ai_color = clrLime;
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell") dash_ai_color = clrRed;
   ObjectSetInteger(0, "BoomCrash_Dash_AIAction", OBJPROP_COLOR, dash_ai_color);
   string trend_str = (g_api_trend_direction == 1) ? "HAUSS." : (g_api_trend_direction == -1) ? "BAISS." : "NEUTRE";
   ObjectSetString(0, "BoomCrash_Dash_Trend", OBJPROP_TEXT, "Tendance: " + trend_str + " " + DoubleToString(g_api_trend_confidence * 100, 1) + "%");
   ObjectSetInteger(0, "BoomCrash_Dash_Trend", OBJPROP_COLOR, (g_api_trend_direction == 1) ? clrLime : (g_api_trend_direction == -1) ? clrRed : clrGray);
   long api_age = (g_lastAPIUpdate > 0) ? (long)(TimeCurrent() - g_lastAPIUpdate) : 999999;
   string api_time_str = (api_age < 60) ? IntegerToString((int)api_age) + "s" : IntegerToString((int)(api_age / 60)) + "min";
   ObjectSetString(0, "BoomCrash_Dash_APITime", OBJPROP_TEXT, "Dernière MAJ: " + (g_lastAPIUpdate > 0 ? api_time_str + " ago" : "Jamais"));
   ObjectSetInteger(0, "BoomCrash_Dash_APITime", OBJPROP_COLOR, (api_age < AI_UpdateInterval_sec * 2) ? clrCyan : clrOrange);

   // === ALERTE SPIKE ===
   ObjectSetString(0, "BoomCrash_Dash_SpikeHeader", OBJPROP_TEXT, "🚨 ALERTE SPIKE");
   ObjectSetInteger(0, "BoomCrash_Dash_SpikeHeader", OBJPROP_COLOR, header_color);
   ObjectSetString(0, "BoomCrash_Dash_SpikeType", OBJPROP_TEXT, "Spike: " + ((g_lastSpikeType != "") ? g_lastSpikeType : "Aucune"));
   ObjectSetInteger(0, "BoomCrash_Dash_SpikeType", OBJPROP_COLOR, (g_lastSpikeType == "BOOM") ? clrLime : (g_lastSpikeType == "CRASH") ? clrRed : clrGray);
   ObjectSetString(0, "BoomCrash_Dash_EntryPrice", OBJPROP_TEXT, "Entrée: " + ((g_lastEntryPrice > 0) ? DoubleToString(g_lastEntryPrice, _Digits) : "N/A"));
   ObjectSetString(0, "BoomCrash_Dash_Duration", OBJPROP_TEXT, "Durée alerte: " + (duration_sec > 0 ? IntegerToString((int)duration_sec) + " sec" : "N/A"));
   ObjectSetInteger(0, "BoomCrash_Dash_Duration", OBJPROP_COLOR, (duration_sec > 0 && duration_sec < 60) ? clrYellow : text_color);
   ObjectSetString(0, "BoomCrash_Dash_AlertTime", OBJPROP_TEXT, (g_lastSpikeTime > 0) ? TimeToString(g_lastSpikeTime, TIME_DATE|TIME_SECONDS) : "N/A");

   // === POSITION ===
   ObjectSetString(0, "BoomCrash_Dash_PosHeader", OBJPROP_TEXT, "💰 POSITION");
   ObjectSetInteger(0, "BoomCrash_Dash_PosHeader", OBJPROP_COLOR, header_color);
   ulong ticket = GetMyPositionTicket();
   if(ticket > 0 && PositionSelectByTicket(ticket))
   {
      double pos_total = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double pos_volume = PositionGetDouble(POSITION_VOLUME);
      double pos_open = PositionGetDouble(POSITION_PRICE_OPEN);
      double pos_sl = PositionGetDouble(POSITION_SL);
      double pos_tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      string pos_type_str = (pos_type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      ObjectSetString(0, "BoomCrash_Dash_PosStatus", OBJPROP_TEXT, pos_type_str + " | Vol: " + DoubleToString(pos_volume, 2) + " | Prix: " + DoubleToString(pos_open, _Digits));
      ObjectSetString(0, "BoomCrash_Dash_PosPnL", OBJPROP_TEXT, "P&L: " + DoubleToString(pos_total, 2) + " USD");
      ObjectSetInteger(0, "BoomCrash_Dash_PosStatus", OBJPROP_COLOR, (pos_total > 0) ? clrLime : (pos_total < 0) ? clrRed : text_color);
      ObjectSetInteger(0, "BoomCrash_Dash_PosPnL", OBJPROP_COLOR, (pos_total > 0) ? clrLime : (pos_total < 0) ? clrRed : text_color);
      string sltp_str = "SL: " + (pos_sl > 0 ? DoubleToString(pos_sl, _Digits) : "N/A") + " | TP: " + (pos_tp > 0 ? DoubleToString(pos_tp, _Digits) : "N/A");
      ObjectSetString(0, "BoomCrash_Dash_PosSLTP", OBJPROP_TEXT, sltp_str);
      ObjectSetInteger(0, "BoomCrash_Dash_PosSLTP", OBJPROP_COLOR, text_color);
   }
   else
   {
      ObjectSetString(0, "BoomCrash_Dash_PosStatus", OBJPROP_TEXT, "Aucune position ouverte");
      ObjectSetInteger(0, "BoomCrash_Dash_PosStatus", OBJPROP_COLOR, clrGray);
      ObjectSetString(0, "BoomCrash_Dash_PosPnL", OBJPROP_TEXT, "");
      ObjectSetString(0, "BoomCrash_Dash_PosSLTP", OBJPROP_TEXT, "");
   }
   
   // === STATUT ORDRES LIMITES ===
   ObjectSetString(0, "BoomCrash_Dash_LimitHeader", OBJPROP_TEXT, "🎯 ORDRES LIMITES");
   ObjectSetInteger(0, "BoomCrash_Dash_LimitHeader", OBJPROP_COLOR, header_color);
   
   // Vérifier les ordres limites actifs
   int buyLimitCount = 0, sellLimitCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == MagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT) buyLimitCount++;
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT) sellLimitCount++;
         }
      }
   }
   
   // Afficher statut ordres BUY LIMIT
   string buyLimitStatus = "BUY LIMIT: " + (buyLimitCount > 0 ? IntegerToString(buyLimitCount) + " actif(s)" : "Aucun");
   if(trend_alignment_buy && PlaceLimitOrdersOnAlignmentEnabled && buyLimitCount == 0)
      buyLimitStatus += " (⏳ En attente)";
   ObjectSetString(0, "BoomCrash_Dash_LimitBuyStatus", OBJPROP_TEXT, buyLimitStatus);
   ObjectSetInteger(0, "BoomCrash_Dash_LimitBuyStatus", OBJPROP_COLOR, (buyLimitCount > 0) ? clrLime : (trend_alignment_buy ? clrYellow : clrGray));
   
   // Afficher statut ordres SELL LIMIT  
   string sellLimitStatus = "SELL LIMIT: " + (sellLimitCount > 0 ? IntegerToString(sellLimitCount) + " actif(s)" : "Aucun");
   if(trend_alignment_sell && PlaceLimitOrdersOnAlignmentEnabled && sellLimitCount == 0)
      sellLimitStatus += " (⏳ En attente)";
   ObjectSetString(0, "BoomCrash_Dash_LimitSellStatus", OBJPROP_TEXT, sellLimitStatus);
   ObjectSetInteger(0, "BoomCrash_Dash_LimitSellStatus", OBJPROP_COLOR, (sellLimitCount > 0) ? clrRed : (trend_alignment_sell ? clrYellow : clrGray));
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES - Limite perte à 5$ par trade              |
//+------------------------------------------------------------------+
void CheckMaxLossPerTrade()
{
   if(MaxLoss_USD <= 0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double totalLoss = profit + swap;
      
      // Fermer si la perte dépasse la limite
      if(totalLoss <= -MaxLoss_USD)
      {
         if(trade.PositionClose(ticket))
         {
            Print("🛑 FERMETURE AUTOMATIQUE - Perte: ", DoubleToString(totalLoss, 2), 
                  "$ sur ", _Symbol, " (limite: ", DoubleToString(MaxLoss_USD, 2), "$)");
            SendNotification("BoomCrash: Position fermée - Perte limite atteinte");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES - Calcul profit net quotidien                 |
//+------------------------------------------------------------------+
//| Retourne le profit net (profit + swap + commission) réalisé       |
//| aujourd'hui par cet EA (magic number MagicNumber)                 |
//+------------------------------------------------------------------+
double CalculateDailyNetProfit()
{
   double net_profit = 0.0;
   
   // On prend le début de la journée actuelle
   datetime today_start = iTime(_Symbol, PERIOD_D1, 0);
   
   if(!HistorySelect(today_start, TimeCurrent()))
   {
      Print("CalculateDailyNetProfit → HistorySelect a échoué");
      return 0.0;
   }
   
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      
      // On ne prend que les deals de type BUY/SELL (pas les dépôts/retraits)
      long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_IN && entry_type != DEAL_ENTRY_OUT) continue;
      
      double profit     = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap       = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      
      net_profit += profit + swap + commission;
   }
   
   return net_profit;
}

//+------------------------------------------------------------------+
//| FILTRE LOCAL DE SÉCURITÉ - Validation technique supplémentaire    |
//+------------------------------------------------------------------+
bool IsLocalFilterValid(string aiDirection, double aiConfidence, string &outReason)
{
   outReason = "";
   
   // Récupération indicateurs (ajuste les shifts si besoin)
   double rsi[1], macd_main[1], macd_sig[1], ema9[1], ema21[1], atr[1];
   
   if(CopyBuffer(rsi_handle,         0, 0, 1, rsi)      !=1 ||
      CopyBuffer(emaFastM1_handle, 0, 0, 1, ema9)   !=1 ||
      CopyBuffer(emaSlowM1_handle, 0, 0, 1, ema21)  !=1 ||
      CopyBuffer(atr_M1_handle,    0, 0, 1, atr)    !=1)
   {
      outReason = "Erreur copie buffers indicateurs";
      return false;
   }
   
   // MACD (tu peux créer le handle dans OnInit si absent)
   int macd_handle = iMACD(_Symbol, PERIOD_M1, 12,26,9, PRICE_CLOSE);
   if(CopyBuffer(macd_handle, 0, 0, 1, macd_main) !=1 ||
      CopyBuffer(macd_handle, 1, 0, 1, macd_sig)  !=1)
   {
      outReason = "Erreur MACD";
      return false;
   }
   
   bool isBuyDirection  = (StringFind(aiDirection,"BUY")>=0 || StringFind(aiDirection,"LONG")>=0);
   bool isSellDirection = (StringFind(aiDirection,"SELL")>=0 || StringFind(aiDirection,"SHORT")>=0);
   
   int conditionsOK = 0;
   
   // Condition 1 : tendance EMA
   if(isBuyDirection  && ema9[0] > ema21[0]) conditionsOK++;
   if(isSellDirection && ema9[0] < ema21[0]) conditionsOK++;
   
   // Condition 2 : RSI pas extrême
   if(isBuyDirection  && rsi[0] < 68.0) conditionsOK++;
   if(isSellDirection && rsi[0] > 32.0) conditionsOK++;
   
   // Condition 3 : MACD haussier/baissier
   if(isBuyDirection  && macd_main[0] > macd_sig[0]) conditionsOK++;
   if(isSellDirection && macd_main[0] < macd_sig[0]) conditionsOK++;
   
   // Condition 4 : volatilité raisonnable (ATR pas trop élevé)
   double atr50[1];
   int atr50_handle = iATR(_Symbol, PERIOD_M1, 50);
   if(CopyBuffer(atr50_handle, 0, 0, 1, atr50) == 1)
   {
      if(atr[0] < 1.6 * atr50[0]) conditionsOK++;
   IndicatorRelease(atr50_handle);
   }
   
   // Règle finale - ajustée pour le nouveau seuil de 68%
   int requiredConditions = (aiConfidence >= 0.68) ? 2 : 3;
   
   if(conditionsOK >= requiredConditions)
   {
      outReason = StringFormat("Local OK (%d/%d conditions)", conditionsOK, requiredConditions);
      return true;
   }
   
   outReason = StringFormat("Local refusé (%d/%d conditions) - confiance IA=%.2f", 
                            conditionsOK, requiredConditions, aiConfidence);
   return false;
}

//+------------------------------------------------------------------+
//| GESTION TRAILING STOP + BREAKEVEN AUTOMATIQUE                 |
//+------------------------------------------------------------------+
void ManageTrailingAndBreakeven()
{
   if(!InpUseTrailing) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL   = PositionGetDouble(POSITION_SL);
      double currentTP   = PositionGetDouble(POSITION_TP);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double profitPoints = 0.0;
      
      if(posType == POSITION_TYPE_BUY)
         profitPoints = (currentPrice - openPrice) / point;
      else
         profitPoints = (openPrice - currentPrice) / point;
      
      // ───────────────────────────────
      // 1. Breakeven : dès + BreakevenTriggerPips
      // ───────────────────────────────
      static ulong lastBreakevenSet[MAX_TRACKED_TICKETS];
      static int breakevenCount = 0;
      
      bool alreadyBreakeven = false;
      for(int j = 0; j < breakevenCount; j++)
         if(lastBreakevenSet[j] == ticket) { alreadyBreakeven = true; break; }
      
      if(profitPoints >= BreakevenTriggerPips && !alreadyBreakeven)
      {
         double newSL = 0.0;
         if(posType == POSITION_TYPE_BUY)
            newSL = openPrice + BreakevenBufferPips * point;
         else
            newSL = openPrice - BreakevenBufferPips * point;
         
         newSL = NormalizeDouble(newSL, _Digits);
         
         if((posType == POSITION_TYPE_BUY && newSL > currentSL + point) ||
            (posType == POSITION_TYPE_SELL && (currentSL == 0 || newSL < currentSL - point)))
         {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
               PrintFormat("Breakeven activé ticket %I64u | Profit: %.1f pts | New SL: %.5f", ticket, profitPoints, newSL);
               
               if(breakevenCount < MAX_TRACKED_TICKETS)
                  lastBreakevenSet[breakevenCount++] = ticket;
            }
         }
      }
      
      // ───────────────────────────────
      // 2. Trailing stop normal
      // ───────────────────────────────
      double trailDistance = InpTrailDist * point;
      
      // Mode plus agressif Boom/Crash après un certain profit
      if(profitPoints > BoomCrashTrailStartPips)
      {
         trailDistance = MathMin(trailDistance, BoomCrashTrailDistPips * point);
      }
      
      double newSL = 0.0;
      
      if(posType == POSITION_TYPE_BUY)
      {
         newSL = currentPrice - trailDistance;
         if(newSL > currentSL + point) // on ne modifie que si meilleur
         {
            newSL = NormalizeDouble(newSL, _Digits);
            if(trade.PositionModify(ticket, newSL, currentTP))
               PrintFormat("Trailing BUY ticket %I64u | Profit: %.1f pts | New SL: %.5f", ticket, profitPoints, newSL);
         }
      }
      else // SELL
      {
         newSL = currentPrice + trailDistance;
         if(currentSL == 0 || newSL < currentSL - point)
         {
            newSL = NormalizeDouble(newSL, _Digits);
            if(trade.PositionModify(ticket, newSL, currentTP))
               PrintFormat("Trailing SELL ticket %I64u | Profit: %.1f pts | New SL: %.5f", ticket, profitPoints, newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| VÉRIFICATION FENÊTRE HORAIRE AUTORISÉE (7h-23h UTC)    |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   
   int hourUTC = t.hour;  // TimeCurrent() est déjà en UTC sur la plupart des brokers Deriv
   
   // 7h → 23h UTC = 7:00 à 22:59
   if(hourUTC < 7 || hourUTC >= 23)
   {
      static datetime lastTimeMsg = 0;
      if(TimeCurrent() - lastTimeMsg >= 900) // toutes les 15 min
      {
         Print("Hors fenêtre autorisée (7h-23h UTC) → trading bloqué");
         lastTimeMsg = TimeCurrent();
      }
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| FILTRE ANTI-SPIKE BASIQUE (BOUGIE PRÉCÉDENTE)           |
//+------------------------------------------------------------------+
bool IsSpikeRiskTooHigh()
{
   double atr[1], close[2], open[2];
   
   if(CopyBuffer(atr_M1_handle, 0, 1, 1, atr) != 1) return true; // sécurité
   if(CopyClose(_Symbol, PERIOD_M1, 1, 2, close) != 2) return true;
   if(CopyOpen (_Symbol, PERIOD_M1, 1, 2, open)  != 2) return true;
   
   double prevCandleRange = MathAbs(close[0] - open[0]);
   double atrValue = atr[0];
   
   if(prevCandleRange > 2.8 * atrValue)
   {
      PrintFormat("Spike détecté sur bougie précédente (%.1f pts > %.1f × ATR) → entrée bloquée", 
                  prevCandleRange/_Point, 2.8);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES - Calcul taille de lot basée sur le risque     |
//+------------------------------------------------------------------+
double CalculateRiskBasedLotSize(double riskPercent = 1.0, double stopLossPoints = 0.0)
{
   if(riskPercent <= 0.0) return LotSize; // sécurité : fallback valeur input
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(accountBalance <= 0.0) return 0.0;
   
   double riskAmountUSD = accountBalance * (riskPercent / 100.0);
   
   // Valeur monétaire d'un point pour 1 lot
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue == 0.0 || tickSize == 0.0 || point == 0.0)
   {
      Print("CalculateRiskBasedLotSize → Impossible de récupérer tickValue/tickSize/point");
      return LotSize; // fallback
   }
   
   double valuePerPointPerLot = tickValue / (tickSize / point);
   
   // Si on n'a pas de SL valide → on utilise une valeur par défaut conservatrice
   double slPoints = (stopLossPoints > 10) ? stopLossPoints : 300.0; // 300 points par défaut pour Boom/Crash
   
   double lotSize = riskAmountUSD / (slPoints * valuePerPointPerLot);
   
   // Respect des contraintes du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Arrondi au step le plus proche
   if(lotStep > 0.0)
      lotSize = MathRound(lotSize / lotStep) * lotStep;
   
   lotSize = NormalizeDouble(lotSize, 2);
   
   PrintFormat("CalculateRiskBasedLotSize → Balance=%.2f$ | Risque=%.1f%% | SL=%.0f pts → Lot=%.2f",
               accountBalance, riskPercent, slPoints, lotSize);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| GESTION DES POSITIONS BOOM/CRASH                                |
//+------------------------------------------------------------------+
void ManageBoomCrashPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;

      bool isBoom = (StringFind(symbol, "Boom") >= 0);
      bool isCrash = (StringFind(symbol, "Crash") >= 0);

      if(!isBoom && !isCrash) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double totalProfit = profit + swap;
      
      // Fermeture automatique si profit minimum atteint
      if(UseBoomCrashAutoClose && totalProfit >= BoomCrashMinProfitUSD)
      {
         if(trade.PositionClose(ticket))
         {
            Print("🚀 FERMETURE BOOM/CRASH - Profit: ", DoubleToString(totalProfit, 2), "$ >= ", DoubleToString(BoomCrashMinProfitUSD, 2), "$");
            g_lastSpikeType = (isBoom ? "BOOM_FERME" : "CRASH_FERME");
            g_lastSpikeTime = TimeCurrent();
            return;
         }
      }

      // Trailing stop spécial Boom/Crash - plus agressif pour sécuriser les gains
      if(UseBoomCrashTrailing)
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         // Calcul du profit en pips
         double profitPips = 0.0;
         if(posType == POSITION_TYPE_BUY)
            profitPips = (currentPrice - openPrice) / point;
         else
            profitPips = (openPrice - currentPrice) / point;

         // Trailing agressif : déclencher plus tôt et distance plus serrée
         double aggressiveTrailStart = BoomCrashTrailStartPips * 0.5; // 50% plus tôt
         double aggressiveTrailDist = BoomCrashTrailDistPips * 0.7; // 30% plus serré
         
         if(profitPips >= aggressiveTrailStart)
         {
            if(posType == POSITION_TYPE_BUY)
            {
               double newSL = currentPrice - (aggressiveTrailDist * point);
               // Breakeven rapide après 15 pips de profit
               if(profitPips >= 15.0)
                  newSL = MathMax(newSL, openPrice + (2.0 * point));
               
               if(newSL > sl && newSL > openPrice)
               {
                  if(trade.PositionModify(ticket, newSL, tp))
                  {
                     Print("🔄 BOOM/CRASH Trailing AGGRESSIF BUY - SL: ", DoubleToString(newSL, _Digits), 
                           " | Profit: ", DoubleToString(profitPips, 1), " pips");
                  }
               }
            }
            else // POSITION_TYPE_SELL
            {
               double newSL = currentPrice + (aggressiveTrailDist * point);
               // Breakeven rapide après 15 pips de profit
               if(profitPips >= 15.0)
                  newSL = MathMin(newSL, openPrice - (2.0 * point));
               
               if((sl == 0 || newSL < sl) && newSL < openPrice)
               {
                  if(trade.PositionModify(ticket, newSL, tp))
                  {
                     Print("🔄 BOOM/CRASH Trailing AGGRESSIF SELL - SL: ", DoubleToString(newSL, _Digits),
                           " | Profit: ", DoubleToString(profitPips, 1), " pips");
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter les niveaux de support/résistance les plus proches      |
//+------------------------------------------------------------------+
double FindNearestSupport(double currentPrice, double& ema_fast, double& ema_slow, double& lowerChannel)
{
   double supportLevels[];
   ArrayResize(supportLevels, 4);
   
   // Ajouter les niveaux de support potentiels
   supportLevels[0] = ema_slow;      // EMA lente comme support
   supportLevels[1] = ema_fast;      // EMA rapide comme support  
   supportLevels[2] = lowerChannel;   // Canal inférieur comme support
   supportLevels[3] = currentPrice * 0.995; // Support technique à 0.5% sous le prix
   
   double nearestSupport = 0;
   double minDistance = DBL_MAX;
   
   for(int i = 0; i < ArraySize(supportLevels); i++)
   {
      if(supportLevels[i] > 0 && supportLevels[i] < currentPrice)
      {
         double distance = currentPrice - supportLevels[i];
         if(distance < minDistance)
         {
            minDistance = distance;
            nearestSupport = supportLevels[i];
         }
      }
   }
   
   return nearestSupport;
}

//+------------------------------------------------------------------+
//| Détecter les niveaux de résistance les plus proches             |
//+------------------------------------------------------------------+
double FindNearestResistance(double currentPrice, double& ema_fast, double& ema_slow, double& upperChannel)
{
   double resistanceLevels[];
   ArrayResize(resistanceLevels, 4);
   
   // Ajouter les niveaux de résistance potentiels
   resistanceLevels[0] = ema_slow;      // EMA lente comme résistance
   resistanceLevels[1] = ema_fast;      // EMA rapide comme résistance
   resistanceLevels[2] = upperChannel;  // Canal supérieur comme résistance
   resistanceLevels[3] = currentPrice * 1.005; // Résistance technique à 0.5% au-dessus du prix
   
   double nearestResistance = 0;
   double minDistance = DBL_MAX;
   
   for(int i = 0; i < ArraySize(resistanceLevels); i++)
   {
      if(resistanceLevels[i] > 0 && resistanceLevels[i] > currentPrice)
      {
         double distance = resistanceLevels[i] - currentPrice;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearestResistance = resistanceLevels[i];
         }
      }
   }
   
   return nearestResistance;
}

//+------------------------------------------------------------------+
//| Placer ordres limite lors d'alignement buy/sell sur tableau de bord|
//+------------------------------------------------------------------+
void PlaceLimitOrdersOnAlignment()
{
   if(PositionsTotal() > 0) return; // Pas d'ordres si position déjà ouverte
   
   // Vérifier si les buffers sont prêts
   if(ArraySize(emaFastM1_buffer) < 1 || ArraySize(emaSlowM1_buffer) < 1 || 
      ArraySize(emaFastM5_buffer) < 1 || ArraySize(emaSlowM5_buffer) < 1 ||
      ArraySize(atr_buffer) < 1)
      return;
   
   SymbolInfoTick(_Symbol, last_tick);
   double currentPrice = last_tick.bid;
   double ema_fast_m1 = emaFastM1_buffer[0];
   double ema_slow_m1 = emaSlowM1_buffer[0];
   double ema_fast_m5 = emaFastM5_buffer[0];
   double ema_slow_m5 = emaSlowM5_buffer[0];
   double atr_val = atr_buffer[0];
   
   // Calculer les canaux supérieur et inférieur
   double upperChannel = currentPrice + (SpikeChannelATRMult * atr_val);
   double lowerChannel = currentPrice - (SpikeChannelATRMult * atr_val);
   
   // Détecter l'alignement (même logique que dans le dashboard)
   bool trend_alignment_buy = (ema_fast_m1 > ema_slow_m1) && (ema_fast_m5 > ema_slow_m5);
   bool trend_alignment_sell = (ema_fast_m1 < ema_slow_m1) && (ema_fast_m5 < ema_slow_m5);
   
   // Vérifier le type de symbole
   bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
   bool is_crash = (StringFind(_Symbol, "Crash") >= 0);
   
   // Placer ordre limite BUY si alignement buy détecté
   if(trend_alignment_buy && !is_crash) // Pas de BUY sur Crash
   {
      double nearestSupport = FindNearestSupport(currentPrice, ema_fast_m1, ema_slow_m1, lowerChannel);
      
      if(nearestSupport > 0)
      {
         double limitPrice = nearestSupport - (LimitOrderOffsetPoints * _Point);
         
         double tradeRiskPercent = InpRiskPercentPerTrade;
         if(InpFixedRiskUSD > 0.0)
         {
            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            tradeRiskPercent = (InpFixedRiskUSD / balance) * 100.0;
         }

         // On suppose que tu as déjà calculé sl_points (distance SL en points)
         double sl_points = 300.0; // Default SL points for Boom/Crash
         double lotToUse = CalculateRiskBasedLotSize(tradeRiskPercent, sl_points);

         // Sécurité ultime
         if(lotToUse < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            Print("Lot trop petit → ordre BUY LIMIT annulé");
            return;
         }
         
         // Placer ordre BUY LIMIT
         if(trade.BuyLimit(lotToUse, limitPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "ALIGNMENT BUY LIMIT"))
         {
            Print("📈 ORDRE BUY LIMIT PLACÉ - Alignement détecté");
            Print("   Prix actuel: ", DoubleToString(currentPrice, _Digits));
            Print("   Support le plus proche: ", DoubleToString(nearestSupport, _Digits));
            Print("   Prix limite: ", DoubleToString(limitPrice, _Digits));
            SendNotification("BoomCrash: Ordre BUY LIMIT placé - Alignement");
         }
      }
   }
   
   // Placer ordre limite SELL si alignement sell détecté
   if(trend_alignment_sell && !is_boom) // Pas de SELL sur Boom
   {
      double nearestResistance = FindNearestResistance(currentPrice, ema_fast_m1, ema_slow_m1, upperChannel);
      
      if(nearestResistance > 0)
      {
         double limitPrice = nearestResistance + (LimitOrderOffsetPoints * _Point);
         
         double tradeRiskPercent = InpRiskPercentPerTrade;
         if(InpFixedRiskUSD > 0.0)
         {
            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            tradeRiskPercent = (InpFixedRiskUSD / balance) * 100.0;
         }

         // On suppose que tu as déjà calculé sl_points (distance SL en points)
         double sl_points = 300.0; // Default SL points for Boom/Crash
         double lotToUse = CalculateRiskBasedLotSize(tradeRiskPercent, sl_points);

         // Sécurité ultime
         if(lotToUse < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         {
            Print("Lot trop petit → ordre SELL LIMIT annulé");
            return;
         }
         
         // Placer ordre SELL LIMIT
         if(trade.SellLimit(lotToUse, limitPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "ALIGNMENT SELL LIMIT"))
         {
            Print("📉 ORDRE SELL LIMIT PLACÉ - Alignement détecté");
            Print("   Prix actuel: ", DoubleToString(currentPrice, _Digits));
            Print("   Résistance la plus proche: ", DoubleToString(nearestResistance, _Digits));
            Print("   Prix limite: ", DoubleToString(limitPrice, _Digits));
            SendNotification("BoomCrash: Ordre SELL LIMIT placé - Alignement");
         }
      }
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
//| Nettoyer tous les objets graphiques expirés                      |
//+------------------------------------------------------------------+
void CleanExpiredObjects()
{
    datetime currentTime = TimeCurrent();
    datetime cutoffTime = currentTime - 3600; // Supprimer les objets de plus d'1 heure
    
    for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, -1, -1);
        
        // Vérifier si c'est un objet de nos robots
        if(StringFind(objName, "BoomCrash_") >= 0 || 
           StringFind(objName, "DASH_") >= 0 ||
           StringFind(objName, "SpikeArrow_") >= 0 ||
           StringFind(objName, "Prediction_") >= 0)
        {
            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            
            // Si l'objet est trop ancien ou a une date future, le supprimer
            if(objTime < cutoffTime || objTime > currentTime)
            {
                ObjectDelete(0, objName);
            }
        }
    }
}

//+------------------------------------------------------------------+
