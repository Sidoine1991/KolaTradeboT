//+------------------------------------------------------------------+
//|                          F_INX_robot4_v2.mq5                     |
//|           Synthetic Indices Scalping Expert Advisor              |
//|       Improved Version : Fixed MM, Martingale, Multi-Pos         |
//+------------------------------------------------------------------+
#property copyright "F_INX_robot4_Improved"
#property version   "2.00"
#property strict

// AI Signal Types
enum ENUM_IA_SIGNAL {
   IA_SIGNAL_NONE = 0,
   IA_SIGNAL_BUY = 1,
   IA_SIGNAL_SELL = -1
};

// Global variables for AI
string g_lastAIAction = "";
double g_lastAIConfidence = 0.0;
string g_lastAIReason = "";
double g_aiBuyZoneLow = 0.0;
double g_aiBuyZoneHigh = 0.0;
double g_aiSellZoneLow = 0.0;
double g_aiSellZoneHigh = 0.0;
datetime g_lastAIRequest = 0;
string g_lastValidationReason = "";

// Variables pour la gestion des pertes consécutives
int g_consecutiveLosses = 0;                 // Compteur de pertes consécutives
datetime g_recoveryUntil = 0;                // Heure de fin de la période de récupération

// Variables pour les niveaux Fibonacci
double g_fibLevels[];                        // Tableau pour stocker les niveaux Fibonacci
bool g_fibLevelsCalculated = false;          // Indique si les niveaux ont été calculés
datetime g_lastFibUpdate = 0;                // Dernière mise à jour des niveaux Fibonacci

// Paramètres de validation ATR
const double MinATR = 0.0005;  // Valeur minimale de l'ATR pour considérer le trade
const double MaxATR = 0.0050;  // Valeur maximale de l'ATR pour considérer le trade

// Contrôle des notifications
input bool SendNotifications = true;  // Activer les notifications push
input bool ShowZones = true;         // Afficher les zones de trading

// Function declarations
int AI_GetDecision(double rsi, double atr, double emaFastH1, double emaSlowH1, 
                  double emaFastM1, double emaSlowM1, double ask, double bid, 
                  int dirRule, bool spikeMode);
bool IsNewBar();
void ManagePositionsWithFibonacci();
void CheckForEntrySignals();
void ManageOpenPositions();
void UpdatePanel();
int AllowedDirectionFromSymbol(string symbol);
void DrawAIRecommendation(string action, double confidence, string reason, double price);
void AI_UpdateAnalysis();
void ParseAndDrawFibonacciFromResponse(string resp);
void DrawFibonacciLevels(double &fibValues[]);
void ParseTrendlinesFromResponse(string resp);
void ExtractAndDrawTrendline(string resp, int startPos, bool isBull);
void PerformLocalAnalysis();
void EvaluateBoomCrashZoneScalps();
void EvaluateAIZoneBounceStrategy();
bool SMC_UpdateZones();
void DrawTimeWindowsPanel();
void SendAISummaryIfDue();
void DrawAIBlockLabel(string symbol, string title, string reason);
void CloseExcessPositions();
void AI_UpdateFundamentalAnalysis();
//--- Fonctions Fibonacci pour le trading ---
bool IsPriceNearFibonacciLevel(double price, double &fibLevel, double tolerance);
bool ValidateFibonacciTradeSignal(bool isBuy, double price);
double GetFibonacciStopLoss(bool isBuy, double entryPrice);
double GetFibonacciTakeProfit(bool isBuy, double entryPrice);
bool IsFibonacciBounceConfirming(bool isBuy, int lookbackBars);
void UpdateFibonacciLevels();
bool IsFundamentalConfirming(string direction);
bool PredictSpikeFromSMCOB(double &spikePrice, bool &isBuySpike, double &confidence);
bool SMC_OB_CheckZones(double currentPrice, bool &isBuySpike, double &confidence);
int CountPositionsForSymbolMagic();
int CountAllPositionsForMagic();
int CountOpenForexPositions();
bool CanOpenNewPosition();
void AI_UpdateTimeWindows();
void DrawAIZones();
void CheckAIZoneAlerts();
void EvaluateAIZoneEMAScalps();
void ManageGlobalProfitSecurity();
void CheckSpikeSignals();
bool ExecuteTrade(ENUM_ORDER_TYPE orderType, double lotSize, double sl = 0.0, double tp = 0.0, string comment = "", bool isBoomCrash = false, bool isVol = false, bool isSpike = false);
bool ExecuteTrade(ENUM_ORDER_TYPE type, double atr, double price, string comment, double lotMultiplier = 1.0, bool isSpikePriority = false);
void ManageTrade();
bool ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE type, double &executionPrice, double &sl, double &tp);
double CalculateLot(double atr);
void CloseAllPositionsForSymbolMagic();
void UpdateSMCOBZones();
void DrawSMCOBZones();
void CheckTotalLossProtection()
{
   if(!EnableTotalLossProtection)
      return;
      
   // Calculer le profit/perte total du compte
   double totalProfit = 0;
   double worstPositionProfit = 0;
   ulong worstPositionTicket = 0;
   
   // Parcourir toutes les positions ouvertes
   for(int i = 0; i < PositionsTotal(); i++)
   {
      string posSymbol = PositionGetSymbol(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         double posProfit = PositionGetDouble(POSITION_PROFIT);
         totalProfit += posProfit;
         
         // Trouver la position avec la plus grande perte
         if(posProfit < worstPositionProfit)
         {
            worstPositionProfit = posProfit;
            worstPositionTicket = PositionGetInteger(POSITION_TICKET);
         }
      }
   }
   
   // Vérifier si la perte totale dépasse la limite
   if(totalProfit <= MaxTotalLossAmount)
   {
      Print("Protection contre pertes totales activée - Perte totale: ", totalProfit, " $");
      
      if(CloseWorstPositionOnLoss && worstPositionTicket > 0)
      {
         // Fermer la position avec la plus grande perte
         if(PositionSelectByTicket(worstPositionTicket))
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = worstPositionTicket;
            request.symbol = PositionGetString(POSITION_SYMBOL);
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
            request.price = PositionGetDouble(POSITION_PRICE_CURRENT);
            request.deviation = 3;
            request.magic = InpMagicNumber;
            
            if(OrderSend(request, result))
            {
               Print("Position avec perte la plus élevée fermée: Ticket ", worstPositionTicket, 
                     ", Perte: ", worstPositionProfit, " $");
            }
            else
            {
               Print("Erreur lors de la fermeture de la position: ", GetLastError());
            }
         }
      }
   }
}


#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <WinAPI/winapi.mqh>
#include "temp_can_trade_after_losses.mqh"

// Forward declarations
void DisplaySpikeAlert();
void UpdateSpikeAlertDisplay();

// Structure pour le suivi des positions dynamiques
struct DynamicPositionState {
   double initialLot;         // Taille de lot initiale
   double currentLot;         // Taille de lot actuelle
   double highestProfit;      // Plus haut profit atteint
   bool trendConfirmed;       // La tendance est confirmée
   datetime lastAdjustmentTime; // Dernier ajustement
   double highestPrice;       // Plus haut prix atteint (pour les positions d'achat)
   double lowestPrice;        // Plus bas prix atteint (pour les positions de vente)
   int slModifyCount;         // Nombre de modifications SL (limité à 4 pour Boom/Crash)
};

// Tableau pour suivre l'état des positions dynamiques
DynamicPositionState g_dynamicPosStates[];

// Structure pour tracker le nombre de modifications SL par position (Boom/Crash)
struct PositionSLModifyCount {
   ulong ticket;
   int modifyCount;  // Nombre de modifications SL effectuées
   datetime lastModifyTime;
};

// Tableau pour tracker les modifications SL (max 4 pour Boom/Crash)
PositionSLModifyCount g_slModifyTracker[100];
int g_slModifyTrackerCount = 0;

// Variables pour le suivi des positions dynamiques
double g_lotMultiplier = 1.0;
bool g_trendConfirmed = false;
datetime g_lastTrendCheck = 0;

// Variables pour le suivi des spikes
datetime g_lastSpikeTradeTime = 0;
int g_lastSpikeDirection = 0; // 1 = Achat, -1 = Vente
int g_spikeFailCount = 0;
datetime g_spikeCooldownUntil = 0;


// Paramètres du position sizing dynamique - DÉSACTIVÉ
input group "=== Dynamic Position Sizing ==="
input bool   UseDynamicPositionSizing = false;   // DÉSACTIVÉ - Ne pas doubler le lot
input double DynamicLotMultiplier = 1.0;               // Désactivé
input double MaxLotMultiplier = 1.0;                   // Désactivé
input int MinBarsForAdjustment = 5;                    // Nombre minimum de bougies avant ajustement
input int AdjustmentIntervalSeconds = 300;              // Intervalle minimum entre les ajustements (5 minutes)
// Simple JSON parsing functions
#include <Arrays\ArrayString.mqh>

// Déclaration de la fonction d'affichage des données fondamentales
void UpdateFundamentalDisplay(double peRatio, double dividendYield);

// Simple JSON parsing functions
string getJsonString(string json, string key, string defaultValue = "")
{
   int start = StringFind(json, "\"" + key + "\"");
   if(start < 0) return defaultValue;
   
   int valueStart = StringFind(json, ":", start);
   if(valueStart < 0) return defaultValue;
   
   int quote1 = StringFind(json, "\"", valueStart + 1);
   if(quote1 < 0) return defaultValue;
   
   int quote2 = StringFind(json, "\"", quote1 + 1);
   if(quote2 < 0) return defaultValue;
   
   return StringSubstr(json, quote1 + 1, quote2 - quote1 - 1);
}

double getJsonDouble(string json, string key, double defaultValue = 0.0)
{
   int start = StringFind(json, "\"" + key + "\"");
   if(start < 0) return defaultValue;
   
   int valueStart = StringFind(json, ":", start);
   if(valueStart < 0) return defaultValue;
   
   int valueEnd = StringFind(json, ",", valueStart + 1);
   if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart + 1);
   if(valueEnd < 0) return defaultValue;
   
   string valueStr = StringSubstr(json, valueStart + 1, valueEnd - valueStart - 1);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return StringToDouble(valueStr);
}

bool getJsonBool(string json, string key, bool defaultValue = false)
{
   int start = StringFind(json, "\"" + key + "\"");
   if(start < 0) return defaultValue;
   
   int valueStart = StringFind(json, ":", start);
   if(valueStart < 0) return defaultValue;
   
   int valueEnd = StringFind(json, ",", valueStart + 1);
   if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart + 1);
   if(valueEnd < 0) return defaultValue;
   
   string valueStr = StringSubstr(json, valueStart + 1, valueEnd - valueStart - 1);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return (valueStr == "true" || valueStr == "1");
}

// Helper function to parse JSON arrays
string getJsonArrayItem(string json, int index)
{
   int bracket1 = StringFind(json, "[");
   if(bracket1 < 0) return "";
   
   int bracket2 = StringFind(json, "]", bracket1 + 1);
   if(bracket2 < 0) return "";
   
   string arrayStr = StringSubstr(json, bracket1 + 1, bracket2 - bracket1 - 1);
   
   int count = 0;
   int start = 0;
   int end = 0;
   
   for(int i = 0; i < StringLen(arrayStr); i++)
   {
      if(StringGetCharacter(arrayStr, i) == ',' && count == 0)
      {
         if(index == 0)
         {
            end = i;
            return StringSubstr(arrayStr, start, end - start);
         }
         else
         {
            index--;
            start = i + 1;
         }
      }
      else if(StringGetCharacter(arrayStr, i) == '{')
      {
         count++;
      }
      else if(StringGetCharacter(arrayStr, i) == '}')
      {
         count--;
      }
   }
   
   if(index == 0)
   {
      return StringSubstr(arrayStr, start);
   }
   
   return "";
}

CTrade trade;

//========================= INPUTS ===================================
input group "--- RISK MANAGEMENT ---"
input double RiskPercent        = 1.0;      // % du capital à risquer par trade (0-5%)
input double FixedLotSize       = 0.1;      // Lot fixe si RiskPercent = 0
input double MaxLotSize         = 5.0;      // Plafond absolu de taille de lot
input double DailyProfitTarget  = 100.0;    // Objectif de profit quotidien (0 = illimité)
input double DailyLossLimit     = 200.0;    // Limite de perte quotidienne (0 = illimitée)
input double MinRiskReward      = 1.5;      // Ratio Risque/Récompense minimum (ex: 1.5 pour 1:1.5)
input int    MaxConsecLosses    = 5;        // Arrêter après X pertes consécutives

// Variables globales pour le suivi des performances
double g_dailyProfit = 0.0;
double g_dailyLoss = 0.0;
datetime g_lastTradeDay = 0;  // Dernier jour de trading

// Variables pour le bilan des trades
int g_totalTradesCount = 0;
double g_totalCapitalEngaged = 0.0;
double g_totalProfitLoss = 0.0;
string g_tradedSymbols = "";
datetime g_lastBilanNotification = 0;
string g_tradedSymbolsList[100]; // Tableau pour stocker les symboles uniques
datetime g_lastTradeTime = 0; // Dernière heure de trade

// Structure pour suivre les pertes consécutives par symbole
struct SymbolLossTracker {
   string symbol;          // Symbole
   int consecutiveLosses;  // Nombre de pertes consécutives
   datetime lastLossTime;   // Heure de la dernière perte
};
SymbolLossTracker g_symbolLossTrackers[100]; // Tableau pour suivre les pertes par symbole

//+------------------------------------------------------------------+
//| Vérifie si on peut trader sur ce symbole après des pertes       |
//+------------------------------------------------------------------+
bool CanTradeSymbolAfterLoss(string symbol)
{
   // Vérifier si le symbole a des pertes consécutives
   for(int i = 0; i < ArraySize(g_symbolLossTrackers); i++)
   {
      if(g_symbolLossTrackers[i].symbol == symbol)
      {
         // Si 2 pertes ou plus, attendre 10 minutes
         if(g_symbolLossTrackers[i].consecutiveLosses >= 2)
         {
            datetime now = TimeCurrent();
            if(now - g_symbolLossTrackers[i].lastLossTime < 600) // 600 secondes = 10 minutes
            {
               Print("⏳ Attente de 10 minutes avant de retrader ", symbol, " après 2 pertes consécutives");
               return false;
            }
            else
            {
               // Réinitialiser le compteur après 10 minutes
               g_symbolLossTrackers[i].consecutiveLosses = 0;
               return true;
            }
         }
         return true; // Moins de 2 pertes, trading autorisé
      }
   }
   return true; // Aucune entrée pour ce symbole, trading autorisé
}

//+------------------------------------------------------------------+
//| Met à jour le suivi des pertes par symbole                      |
//+------------------------------------------------------------------+
void UpdateSymbolLossTracking(string symbol, double profit)
{
   bool symbolFound = false;
   int firstEmptySlot = -1;
   
   // Parcourir le tableau pour trouver ou ajouter le symbole
   for(int i = 0; i < ArraySize(g_symbolLossTrackers); i++)
   {
      if(g_symbolLossTrackers[i].symbol == symbol)
      {
         symbolFound = true;
         if(profit < 0) // Perte
         {
            g_symbolLossTrackers[i].consecutiveLosses++;
            g_symbolLossTrackers[i].lastLossTime = TimeCurrent();
            Print("⚠️ Perte consécutive #", g_symbolLossTrackers[i].consecutiveLosses, " sur ", symbol);
            
            if(g_symbolLossTrackers[i].consecutiveLosses >= 2)
            {
               Print("⏸️ Pause de 10 minutes sur ", symbol, " après 2 pertes consécutives");
            }
         }
         else // Profit, réinitialiser le compteur
         {
            if(g_symbolLossTrackers[i].consecutiveLosses > 0)
            {
               Print("✅ Profit sur ", symbol, " - Réinitialisation du compteur de pertes");
               g_symbolLossTrackers[i].consecutiveLosses = 0;
            }
         }
         break;
      }
      else if(firstEmptySlot == -1 && g_symbolLossTrackers[i].symbol == "")
      {
         firstEmptySlot = i;
      }
   }
   
   // Si le symbole n'existe pas encore et qu'il y a une perte, l'ajouter
   if(!symbolFound && profit < 0 && firstEmptySlot != -1)
   {
      g_symbolLossTrackers[firstEmptySlot].symbol = symbol;
      g_symbolLossTrackers[firstEmptySlot].consecutiveLosses = 1;
      g_symbolLossTrackers[firstEmptySlot].lastLossTime = TimeCurrent();
      Print("⚠️ Première perte sur ", symbol);
   }
}
input int    MaxSpreadPoints = 100000;   // Spread max autorisé (filtre assoupli)
input int    MaxSimultaneousSymbols = 2; // Nombre maximum de symboles tradés en même temps
input bool   UseGlobalLossStop = false;   // Stop global sur pertes cumulées
input double GlobalLossLimit   = -3.0;    // Perte max cumulée avant clôture de toutes les positions (en $, si activé)
input double LossCutDollars    = 2.0;     // Coupure max pour la position principale (en $)
input double ProfitSecureDollars = 2.0;   // Gain à sécuriser (en $) par position
input int    MinPositionLifetimeSec = 60; // Délai minimum avant fermeture (secondes) - évite ouvertures/fermetures trop rapides

// === Gestion du Risque ===
input group "=== Gestion du Risque ==="
input double RiskPerTrade = 0.5;    // Risque par trade (% du capital) [0.1-2.0]
input double MaxDailyLoss = 2.0;    // Perte quotidienne maximale (%)
input double MaxDrawdown = 10.0;    // Drawdown maximal autorisé (%)
input bool UseDynamicPositionSizing2 = true;  // Ajustement dynamique des tailles de position
input double MaxLeverage = 5.0;     // Effet de levier maximum autorisé

// --- PROTECTION CONTRE LES PERTES TOTALES ---
input bool   EnableTotalLossProtection = true;  // Activer la protection contre les pertes totales
input double MaxTotalLossAmount = -6.0;         // Perte totale maximale avant déclenchement (en $)
input bool   CloseWorstPositionOnLoss = true;   // Fermer automatiquement la position avec la plus grande perte

// --- AJOUT: INPUTS DE SÉCURITÉ ---
input bool   EnableTrading = true;            // Master switch: activer/désactiver le trading
input double MinEquityForTrading = 100.0;     // Equity minimale pour ouvrir une position
input int    MaxConsecutiveLosses = 3;        // Stop après X pertes consécutives
input bool   EnableAutoAI = false;            // Désactiver exécutions AI automatiques si pertinent
input double MaxDailyLossPercent = 2.0;       // Perte journalière max en %
input bool   LogTradeDecisions = true;        // Activer logs supplémentaires

input group "--- MARTINGALE ---"
input bool   UseMartingale   = false;    // Désactivé pour éviter l'augmentation du risque
input double MartingaleMult  = 1.3;      // Multiplicateur réduit si activé
input int    MartingaleSteps = 2;        // Nombre max réduit de coups perdants consécutifs

input group "--- STRATEGY SETTINGS ---"
input ulong  InpMagicNumber  = 13579;    // Magic number
input int    RSI_Period      = 14;
input int    EMA_Fast        = 50;
input int    EMA_Slow        = 200;
input int    EMA_Scalp_M1    = 10;       // EMA 10 pour scalping M1
input int    ATR_Period      = 14;

input double TP_ATR_Mult     = 3.0;      // Multiplicateur ATR pour le Take Profit (ratio 1:2)
input double SL_ATR_Mult     = 1.5;      // Multiplicateur ATR pour le Stop Loss

input bool   UseBreakEven    = true;
input double BE_ATR_Mult     = 0.8;      // Distance pour activer le BE
input double BE_Offset       = 10;       // Profit sécurisé en points (au-dessus du prix d'entrée)

input bool   UseTrailing     = true;
input double Trail_ATR_Mult  = 0.6;

input group "--- ORDRES BACKUP (LIMIT) ---"
input bool   UseBackupLimit       = true;    // Placer un limit si le marché échoue
input double BackupLimitAtrMult   = 0.5;     // Distance en ATR pour le prix du limit
input int    BackupLimitMinPoints = 50;      // Distance mini en points si ATR faible
input int    BackupLimitExpirySec = 300;     // Expiration du limit (0 = GTC)
input int    MaxLimitOrdersPerSymbol = 2;    // Nombre maximum d'ordres limit par symbole
input bool   ExecuteClosestLimitForScalping = true; // Exécuter l'ordre limit le plus proche en scalping

input group "--- SÉCURITÉ AVANCÉE ---"
input double MaxDrawdownPercent = 3.0;    // Stop global si perte > X% (utilisé ici comme 3$ max sur petit compte)
input bool   UseTimeFilter      = true;   // Filtrer par heures de trading (les fenêtres IA sont TOUJOURS appliquées)
input string TradingHoursStart  = "00:00";// Heure début (HH:MM, heure serveur)
input string TradingHoursEnd    = "23:59";// Heure fin   (HH:MM, heure serveur)
input double MaxLotPerSymbol    = 1.0;    // Lot maximum cumulé par symbole
input bool   UsePartialClose    = false;  // Activer la fermeture partielle
input double PartialCloseRatio  = 0.5;    // % du volume à fermer (0.5 = 50%)
input double BoomCrashProfitCut = 0.30;   // Clôture Boom/Crash dès profit >= X$ (0 pour désactiver)
input bool   UseVolumeFilter    = true;   // Activer le filtre de volume M1
input double VolumeMinMultiplier = 2.0;   // Volume actuel >= moyenne * X
input bool   UseSpikeSpeedFilter = true;  // Activer le filtre de vitesse des spikes
input double SpikeSpeedMin      = 50.0;   // Vitesse minimale (points/minute)
input bool   UseAdvancedLogging = false;  // Journalisation avancée des erreurs
input bool   UseInstantProfitClose = false; // CLÔTURE immédiate dès 0.01$ de profit (désactivée par défaut)
input int    SpikePreEntrySeconds   = 15;  // Nombre de secondes AVANT le spike estimé pour déclencher l'alerte et entrer (15s = alerte 15s avant)

input group "--- ENTRY FILTERS ---"
input ENUM_TIMEFRAMES TF_Trend = PERIOD_H1;
input ENUM_TIMEFRAMES TF_Entry = PERIOD_M1;
input bool   AutoTradeStrongM1 = true;   // Ouvrir auto si tendance M1 marquée
input bool   UseTrendlineFilter = true;  // Activer le filtre de tendance pour les signaux
input int    AutoCooldownSec   = 90;     // Délai min entre deux autos
input int    AfterLossCooldownSec = 0;    // Patience après un SL touché (0 = pas de cooldown)
input double MinMAGapPoints    = 10;     // Ecart min MA rapide/lente
input bool   AllowContraAuto   = true;   // Autoriser BUY sur Crash et SELL sur Boom
input bool   DebugBlocks       = true;   // Logs détaillés

// Indicateurs techniques additionnels (aident l'IA)
input group "--- INDICATEURS SUPPLÉMENTAIRES ---"
input bool   UseExtraIndicators = true;
input int    MACD_Fast          = 12;
input int    MACD_Slow          = 26;
input int    MACD_Signal        = 9;
input int    BB_Period          = 20;
input double BB_Deviation       = 2.0;
input int    Stoch_K            = 14;
input int    Stoch_D            = 3;
input int    Stoch_Slowing      = 3;

input group "--- BROKER LIMITS ---"
input int    MinStopPointsOverride = 0;  // 0 = utiliser StopsLevel broker, >0 = forcer ce minimum (en points)

input group "--- AI AGENT ---"
input bool   UseAI_Agent       = true;               // Activer l'agent IA (via serveur externe)
input string AI_ServerURL      = "http://127.0.0.1:8000/decision"; // URL serveur IA (FastAPI / autre)
input int    AI_Timeout_ms     = 800;                // Timeout WebRequest en millisecondes
input bool   AI_CanBlockTrades = false;              // Si true, l'IA peut bloquer des entrées (false = guide seulement)
input double AI_MinConfidence  = 0.3;                // Confiance minimale IA pour influencer/autoriser les décisions (0.0-1.0) - RÉDUIT pour Crash
input bool   AI_UseNotifications = true;             // Envoyer notifications pour signaux consolidés
input bool   AI_AutoExecuteTrades = true;             // Exécuter automatiquement les trades IA (true = actif par défaut)
input bool   AI_PredictSpikes   = true;              // Prédire les zones de spike Boom/Crash avec flèches
input int    SignalValidationMinScore = 70;           // Score minimum de validation (0-100) - RÉDUIT pour capturer cette opportunité
input string AI_AnalysisURL    = "http://127.0.0.1:8000/analysis";  // URL base pour l'analyse complète (structure H1, etc.)
input int    AI_AnalysisIntervalSec = 60;                           // Fréquence de rafraîchissement de l'analyse (secondes)
input bool   AI_DrawH1Structure = true;                             // Tracer la structure H1 (trendlines, ETE) sur le graphique
input string AI_TimeWindowsURLBase = "http://127.0.0.1:8000";       // Racine API pour /time_windows
//--- Paramètres Fibonacci pour le trading ---
input bool   UseFibonacciInTrading = true;                          // Intégrer les niveaux Fibonacci dans les décisions de trade
input double FibonacciTolerancePips = 5.0;                          // Tolérance en pips pour considérer une proximité avec un niveau Fibonacci
input bool   FibonacciFilterTrades = true;                          // Filtrer les trades qui ne sont pas proches des niveaux Fibonacci
input bool   FibonacciAdjustSLTP = true;                            // Ajuster SL/TP selon les niveaux Fibonacci
input int    FibonacciConfirmationBars = 2;                         // Nombre de bougies pour confirmer un rebond Fibonacci
// Paramètres de trading pour les spikes
input double TakeProfitDollars = 10.0; // Objectif de profit en dollars
input double MinATRForTrading = 0.0001; // ATR minimum pour le trading
input group "--- AI ZONE STRATEGY ---"
input bool   UseAIZoneBounceStrategy   = true;       // Utiliser la stratégie de rebond entre zones BUY/SELL
input int    AIZoneConfirmBarsM5       = 2;          // Nombre de bougies M5 pour confirmer le rebond
input int    AIZoneScalpEMAPeriodM5    = 50;         // EMA utilisée pour les scalps de pullback (par défaut 50)
input int    AIZoneScalpCooldownSec    = 60;         // Délai minimum entre deux scalps sur le même symbole
input double AIZoneScalpEMAToleranceP  = 5.0;        // Tolérance en points autour de l'EMA pour considérer un contact
input group "--- BOOM/CRASH ZONE SCALPS ---"
input bool   UseBoomCrashZoneScalps    = true;       // Boom/Crash: rebond simple dans zone = scalp agressif
input int    BC_TP_Points              = 300;        // TP fixe en points (par défaut ~300 points)
input int    BC_SL_Points              = 150;        // SL fixe en points (par défaut moitié du TP)
input ENUM_TIMEFRAMES BC_ConfirmTF     = PERIOD_M15; // TF de confirmation du rebond (ex: M15 sur Boom 1000)
input int    BC_ConfirmBars            = 1;          // Nombre de bougies de confirmation dans le sens du rebond
input group "--- SMC / OrderBlock ---"
input bool   Use_SMC_OB_Filter      = true;     // SMC valide ou bloque les signaux existants
input bool   Use_SMC_OB_Entries     = false;    // SMC peut déclencher un trade (MM inchangé)
input ENUM_TIMEFRAMES SMC_HTF       = PERIOD_M15;
input ENUM_TIMEFRAMES SMC_LTF       = PERIOD_M1;
input double SMC_OB_ATR_Tolerance   = 0.6;      // distance max (en ATR HTF) au support/résistance
input double SMC_OB_SL_ATR          = 0.8;      // SL multiplié par ATR HTF
input double SMC_OB_TP_ATR          = 2.5;      // TP multiplié par ATR HTF
input bool   SMC_DrawZones          = true;     // dessiner les niveaux SMC sur le graphique

input group "=== GLOBAL PROFIT SECURITY ===";
input bool   InpUseGlobalProfitLock = true;   // Activer la sécurisation globale
input double InpGlobalProfitTarget  = 2.50;   // Cible de profit net ($) pour couper les gains

// Inclure le module SMC après la déclaration des inputs pour éviter les redéfinitions
#define SMC_OB_PARAMS_DECLARED
#include "D:\\Dev\\TradBOT\\mt5\\SMC_OB_signals.mqh"

//+------------------------------------------------------------------+
//| Trade Execution Module                                           |
//+------------------------------------------------------------------+
enum ENUM_TRADE_VALIDATION {
   TRADE_VALIDATION_OK = 0,
   TRADE_VALIDATION_DISABLED,
   TRADE_VALIDATION_INSUFFICIENT_EQUITY,
   TRADE_VALIDATION_POSITION_LIMIT,
   TRADE_VALIDATION_SPREAD_TOO_HIGH,
   TRADE_VALIDATION_COOLDOWN,
   TRADE_VALIDATION_OTHER
};

// Trade validation structure
struct STradeValidation {
   ENUM_TRADE_VALIDATION code;
   string message;
   bool canRetry;
};

//+------------------------------------------------------------------+
//| Performance monitoring structure                                 |
//+------------------------------------------------------------------+
struct SPerformanceMetrics {
   int totalTrades;
   int successfulTrades;
   int failedTrades;
   double totalProfit;
   double maxDrawdown;
   double winRate;
   datetime lastUpdate;
   
   void Update(bool success, double profit = 0) {
      totalTrades++;
      if(success) {
         successfulTrades++;
         totalProfit += profit;
      } else {
         failedTrades++;
      }
      winRate = (totalTrades > 0) ? (double)successfulTrades / totalTrades * 100.0 : 0;
      lastUpdate = TimeCurrent();
   }
};

//+------------------------------------------------------------------+
//| Enhanced risk management system                                  |
//+------------------------------------------------------------------+
class CRiskManager {
private:
   double m_maxRiskPerTrade;    // Maximum risk per trade (% of balance)
   double m_dailyLossLimit;     // Daily loss limit (% of balance)
   double m_maxDrawdown;        // Maximum drawdown (%)
   double m_startingBalance;    // Starting balance for the day
   double m_currentDrawdown;    // Current drawdown
   
public:
   CRiskManager(double riskPerTrade = 1.0, double dailyLossLimit = 2.0, double maxDrawdown = 10.0) {
      m_maxRiskPerTrade = riskPerTrade;
      m_dailyLossLimit = dailyLossLimit;
      m_maxDrawdown = maxDrawdown;
      m_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_currentDrawdown = 0.0;
   }
   
   // Check if we can open a new position
   bool CanOpenPosition(double riskAmount) {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Check daily loss limit
      double dailyPnL = balance - m_startingBalance;
      if(dailyPnL < 0 && MathAbs(dailyPnL) >= m_startingBalance * (m_dailyLossLimit / 100.0)) {
         Print("Daily loss limit reached: ", dailyPnL);
         return false;
      }
      
      // Check drawdown
      double drawdown = (equity < balance) ? (balance - equity) / balance * 100.0 : 0.0;
      if(drawdown >= m_maxDrawdown) {
         Print("Maximum drawdown reached: ", drawdown, "%");
         return false;
      }
      
      // Check risk per trade
      if(riskAmount > balance * (m_maxRiskPerTrade / 100.0)) {
         Print("Risk per trade too high: ", riskAmount);
         return false;
      }
      
      return true;
   }
   
   // Update drawdown
   void UpdateDrawdown() {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_currentDrawdown = (equity < balance) ? (balance - equity) / balance * 100.0 : 0.0;
   }
   
   // Get current drawdown
   double GetCurrentDrawdown() const {
      return m_currentDrawdown;
   }
};

//+------------------------------------------------------------------+
//| Trade journal for better tracking                                |
//+------------------------------------------------------------------+
class CTradeJournal {
private:
   string m_filename;
   
public:
   CTradeJournal() {
      m_filename = "TradeLog_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".csv";
      Initialize();
   }
   
   // Initialize the trade journal
   void Initialize() {
      int handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(handle != INVALID_HANDLE) {
         FileWrite(handle, "DateTime", "Symbol", "Type", "Lots", "OpenPrice", 
                  "StopLoss", "TakeProfit", "ClosePrice", "Profit", "Comment");
         FileClose(handle);
      }
   }
   
   // Log a new trade
   void LogTrade(string symbol, ENUM_ORDER_TYPE type, double lots, 
                double openPrice, double sl, double tp, 
                double closePrice, double profit, string comment = "") {
      int handle = FileOpen(m_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(handle != INVALID_HANDLE) {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, 
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                  symbol,
                  EnumToString(type),
                  DoubleToString(lots, 2),
                  DoubleToString(openPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(closePrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(profit, 2),
                  comment);
         FileClose(handle);
      }
   }
};

// Global instances
static SPerformanceMetrics g_performance;
static CRiskManager g_riskManager(1.0, 2.0, 10.0);
static CTradeJournal g_tradeJournal;

//+------------------------------------------------------------------+
//| Validate trade conditions                                        |
//+------------------------------------------------------------------+
STradeValidation ValidateTradeConditions(ENUM_ORDER_TYPE type, bool isSpikePriority = false)
{
   STradeValidation result = {TRADE_VALIDATION_OK, "", true};
   
   if(!EnableTrading) {
      result.code = TRADE_VALIDATION_DISABLED;
      result.message = "Trading is disabled by user setting";
      return result;
   }
   
   if(AccountInfoDouble(ACCOUNT_EQUITY) < MinEquityForTrading) {
      result.code = TRADE_VALIDATION_INSUFFICIENT_EQUITY;
      result.message = "Insufficient equity to open new position";
      return result;
   }
   
   // Add more validation checks here...
   
   return result;
}

//+------------------------------------------------------------------+
//| Execute trade with enhanced error handling                       |
//+------------------------------------------------------------------+
bool ExecuteTradeWithRetry(ENUM_ORDER_TYPE type, double atr, double price, 
                          string comment, double lotMultiplier = 1.0, 
                          bool isSpikePriority = false, int maxRetries = 3)
{
   for(int attempt = 1; attempt <= maxRetries; attempt++) {
      STradeValidation validation = ValidateTradeConditions(type, isSpikePriority);
      if(validation.code != TRADE_VALIDATION_OK) {
         Print("Trade validation failed: ", validation.message);
         if(!validation.canRetry) return false;
         continue;
      }
      
      // Proceed with trade execution
      if(ExecuteTrade(type, atr, price, comment, lotMultiplier, isSpikePriority)) {
         return true;
      }
      
      // If we get here, the trade failed
      int error = GetLastError();
      string errorMsg = "";
      switch(error) {
         case 10001: errorMsg = "Invalid request"; break;
         case 10002: errorMsg = "Invalid parameters"; break;
         case 10003: errorMsg = "Trade disabled"; break;
         case 10004: errorMsg = "Trade busy"; break;
         case 10005: errorMsg = "Invalid price"; break;
         case 10006: errorMsg = "Invalid SL/TP"; break;
         case 10007: errorMsg = "Insufficient funds"; break;
         case 10008: errorMsg = "Invalid volume"; break;
         case 10009: errorMsg = "Market closed"; break;
         case 10010: errorMsg = "No quotes"; break;
         case 10011: errorMsg = "Invalid expiration"; break;
         case 10012: errorMsg = "Order changed"; break;
         case 10013: errorMsg = "Invalid order type"; break;
         case 10014: errorMsg = "Invalid stops"; break;
         case 10015: errorMsg = "Invalid trade volume"; break;
         case 10016: errorMsg = "Market closed"; break;
         case 10017: errorMsg = "No quotes to trade"; break;
         case 10018: errorMsg = "Price changed"; break;
         case 10019: errorMsg = "Off quotes"; break;
         case 10020: errorMsg = "Requote"; break;
         case 10021: errorMsg = "Order expires"; break;
         case 10022: errorMsg = "Order accepted"; break;
         case 10023: errorMsg = "Order already exists"; break;
         case 10024: errorMsg = "Order accepted for execution"; break;
         case 10025: errorMsg = "Order placed"; break;
         case 10026: errorMsg = "Order modified"; break;
         case 10027: errorMsg = "Order cancelled"; break;
         case 10028: errorMsg = "Position already exists"; break;
         case 10029: errorMsg = "Position modified"; break;
         case 10030: errorMsg = "Position closed"; break;
         case 10031: errorMsg = "Position closed by opposite trade"; break;
         case 10032: errorMsg = "Position reversed"; break;
         case 10033: errorMsg = "Position volume added"; break;
         case 10034: errorMsg = "Position volume subtracted"; break;
         case 10035: errorMsg = "Position opened"; break;
         case 10036: errorMsg = "Position closed partially"; break;
         case 10037: errorMsg = "Position volume added partially"; break;
         case 10038: errorMsg = "Position volume subtracted partially"; break;
         case 10039: errorMsg = "Position reversed partially"; break;
         case 10040: errorMsg = "Request rejected"; break;
         case 10041: errorMsg = "Request rejected - timeout"; break;
         case 10042: errorMsg = "Request rejected - invalid price"; break;
         case 10043: errorMsg = "Request rejected - invalid volume"; break;
         case 10044: errorMsg = "Request rejected - market closed"; break;
         case 10045: errorMsg = "Request rejected - no quotes"; break;
         case 10046: errorMsg = "Request rejected - client disabled"; break;
         case 10047: errorMsg = "Request rejected - server busy"; break;
         case 10048: errorMsg = "Request rejected - old version"; break;
         case 10049: errorMsg = "Request rejected - not enough rights"; break;
         case 10050: errorMsg = "Request rejected - request frequency too high"; break;
         case 10051: errorMsg = "Request rejected - no connection"; break;
         case 10052: errorMsg = "Request rejected - server shutdown"; break;
         case 10053: errorMsg = "Request rejected - operation disabled"; break;
         case 10054: errorMsg = "Request rejected - invalid stop loss"; break;
         case 10055: errorMsg = "Request rejected - invalid take profit"; break;
         case 10056: errorMsg = "Request rejected - invalid position"; break;
         case 10057: errorMsg = "Request rejected - invalid order"; break;
         case 10058: errorMsg = "Request rejected - invalid expiration"; break;
         case 10059: errorMsg = "Request rejected - invalid order type"; break;
         case 10060: errorMsg = "Request rejected - invalid trade volume"; break;
         case 10061: errorMsg = "Request rejected - market closed"; break;
         case 10062: errorMsg = "Request rejected - no quotes"; break;
         case 10063: errorMsg = "Request rejected - price changed"; break;
         case 10064: errorMsg = "Request rejected - off quotes"; break;
         case 10065: errorMsg = "Request rejected - requote"; break;
         case 10066: errorMsg = "Request rejected - order expires"; break;
         case 10067: errorMsg = "Request rejected - order already exists"; break;
         case 10068: errorMsg = "Request rejected - order accepted"; break;
         case 10069: errorMsg = "Request rejected - order accepted for execution"; break;
         case 10070: errorMsg = "Request rejected - order placed"; break;
         case 10071: errorMsg = "Request rejected - order modified"; break;
         case 10072: errorMsg = "Request rejected - order cancelled"; break;
         case 10073: errorMsg = "Request rejected - position already exists"; break;
         case 10074: errorMsg = "Request rejected - position modified"; break;
         case 10075: errorMsg = "Request rejected - position closed"; break;
         case 10076: errorMsg = "Request rejected - position closed by opposite trade"; break;
         case 10077: errorMsg = "Request rejected - position reversed"; break;
         case 10078: errorMsg = "Request rejected - position volume added"; break;
         case 10079: errorMsg = "Request rejected - position volume subtracted"; break;
         case 10080: errorMsg = "Request rejected - position reversed partially"; break;
         case 10081: errorMsg = "Request rejected - request rejected"; break;
         case 10082: errorMsg = "Request rejected - request rejected - timeout"; break;
         case 10083: errorMsg = "Request rejected - request rejected - invalid price"; break;
         case 10084: errorMsg = "Request rejected - request rejected - invalid volume"; break;
         case 10085: errorMsg = "Request rejected - request rejected - market closed"; break;
         case 10086: errorMsg = "Request rejected - request rejected - no quotes"; break;
         case 10087: errorMsg = "Request rejected - request rejected - client disabled"; break;
         case 10088: errorMsg = "Request rejected - request rejected - server busy"; break;
         case 10089: errorMsg = "Request rejected - request rejected - old version"; break;
         case 10090: errorMsg = "Request rejected - request rejected - not enough rights"; break;
         case 10091: errorMsg = "Request rejected - request rejected - request frequency too high"; break;
         case 10092: errorMsg = "Request rejected - request rejected - no connection"; break;
         case 10093: errorMsg = "Request rejected - request rejected - server shutdown"; break;
         case 10094: errorMsg = "Request rejected - request rejected - operation disabled"; break;
         case 10095: errorMsg = "Request rejected - request rejected - invalid stop loss"; break;
         case 10096: errorMsg = "Request rejected - request rejected - invalid take profit"; break;
         case 10097: errorMsg = "Request rejected - request rejected - invalid position"; break;
         case 10098: errorMsg = "Request rejected - request rejected - invalid order"; break;
         case 10099: errorMsg = "Request rejected - request rejected - invalid expiration"; break;
         case 10100: errorMsg = "Request rejected - request rejected - invalid order type"; break;
         case 10101: errorMsg = "Request rejected - request rejected - invalid trade volume"; break;
         case 10102: errorMsg = "Request rejected - request rejected - market closed"; break;
         case 10103: errorMsg = "Request rejected - request rejected - no quotes"; break;
         case 10104: errorMsg = "Request rejected - request rejected - price changed"; break;
         case 10105: errorMsg = "Request rejected - request rejected - off quotes"; break;
         case 10106: errorMsg = "Request rejected - request rejected - requote"; break;
         case 10107: errorMsg = "Request rejected - request rejected - order expires"; break;
         case 10108: errorMsg = "Request rejected - request rejected - order already exists"; break;
         case 10109: errorMsg = "Request rejected - request rejected - order accepted"; break;
         case 10110: errorMsg = "Request rejected - request rejected - order accepted for execution"; break;
         case 10111: errorMsg = "Request rejected - request rejected - order placed"; break;
         case 10112: errorMsg = "Request rejected - request rejected - order modified"; break;
         case 10113: errorMsg = "Request rejected - request rejected - order cancelled"; break;
         case 10114: errorMsg = "Request rejected - request rejected - position already exists"; break;
         case 10115: errorMsg = "Request rejected - request rejected - position modified"; break;
         case 10116: errorMsg = "Request rejected - request rejected - position closed"; break;
         case 10117: errorMsg = "Request rejected - request rejected - position closed by opposite trade"; break;
         case 10118: errorMsg = "Request rejected - request rejected - position reversed"; break;
         case 10119: errorMsg = "Request rejected - request rejected - position volume added"; break;
         case 10120: errorMsg = "Request rejected - request rejected - position volume subtracted"; break;
         case 10121: errorMsg = "Request rejected - request rejected - position reversed partially"; break;
         case 10122: errorMsg = "Request rejected - request rejected - request rejected"; break;
         case 10123: errorMsg = "Request rejected - request rejected - request rejected - timeout"; break;
         case 10124: errorMsg = "Request rejected - request rejected - request rejected - invalid price"; break;
         case 10125: errorMsg = "Request rejected - request rejected - request rejected - invalid volume"; break;
         case 10126: errorMsg = "Request rejected - request rejected - request rejected - market closed"; break;
         case 10127: errorMsg = "Request rejected - request rejected - request rejected - no quotes"; break;
         case 10128: errorMsg = "Request rejected - request rejected - request rejected - client disabled"; break;
         case 10129: errorMsg = "Request rejected - request rejected - request rejected - server busy"; break;
         case 10130: errorMsg = "Request rejected - request rejected - request rejected - old version"; break;
         case 10131: errorMsg = "Request rejected - request rejected - request rejected - not enough rights"; break;
         case 10132: errorMsg = "Request rejected - request rejected - request rejected - request frequency too high"; break;
         case 10133: errorMsg = "Request rejected - request rejected - request rejected - no connection"; break;
         case 10134: errorMsg = "Request rejected - request rejected - request rejected - server shutdown"; break;
         case 10135: errorMsg = "Request rejected - request rejected - request rejected - operation disabled"; break;
         case 10136: errorMsg = "Request rejected - request rejected - request rejected - invalid stop loss"; break;
         case 10137: errorMsg = "Request rejected - request rejected - request rejected - invalid take profit"; break;
         case 10138: errorMsg = "Request rejected - request rejected - request rejected - invalid position"; break;
         case 10139: errorMsg = "Request rejected - request rejected - request rejected - invalid order"; break;
         case 10140: errorMsg = "Request rejected - request rejected - request rejected - invalid expiration"; break;
         case 10141: errorMsg = "Request rejected - request rejected - request rejected - invalid order type"; break;
         case 10142: errorMsg = "Request rejected - request rejected - request rejected - invalid trade volume"; break;
         case 10143: errorMsg = "Request rejected - request rejected - request rejected - market closed"; break;
         case 10144: errorMsg = "Request rejected - request rejected - request rejected - no quotes"; break;
         case 10145: errorMsg = "Request rejected - request rejected - request rejected - price changed"; break;
         case 10146: errorMsg = "Request rejected - request rejected - request rejected - off quotes"; break;
         case 10147: errorMsg = "Request rejected - request rejected - request rejected - requote"; break;
         case 10148: errorMsg = "Request rejected - request rejected - request rejected - order expires"; break;
         case 10149: errorMsg = "Request rejected - request rejected - request rejected - order already exists"; break;
         case 10150: errorMsg = "Request rejected - request rejected - request rejected - order accepted"; break;
         case 10151: errorMsg = "Request rejected - request rejected - request rejected - order accepted for execution"; break;
         case 10152: errorMsg = "Request rejected - request rejected - request rejected - order placed"; break;
         case 10153: errorMsg = "Request rejected - request rejected - request rejected - order modified"; break;
         case 10154: errorMsg = "Request rejected - request rejected - request rejected - order cancelled"; break;
         case 10155: errorMsg = "Request rejected - request rejected - request rejected - position already exists"; break;
         case 10156: errorMsg = "Request rejected - request rejected - request rejected - position modified"; break;
         case 10157: errorMsg = "Request rejected - request rejected - request rejected - position closed"; break;
         case 10158: errorMsg = "Request rejected - request rejected - request rejected - position closed by opposite trade"; break;
         case 10159: errorMsg = "Request rejected - request rejected - request rejected - position reversed"; break;
         case 10160: errorMsg = "Request rejected - request rejected - request rejected - position volume added"; break;
         case 10161: errorMsg = "Request rejected - request rejected - request rejected - position volume subtracted"; break;
         case 10162: errorMsg = "Request rejected - request rejected - request rejected - position reversed partially"; break;
         case 10163: errorMsg = "Request rejected - request rejected - request rejected - request rejected"; break;
         case 10164: errorMsg = "Request rejected - request rejected - request rejected - request rejected - timeout"; break;
         case 10165: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid price"; break;
         case 10166: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid volume"; break;
         case 10167: errorMsg = "Request rejected - request rejected - request rejected - request rejected - market closed"; break;
         case 10168: errorMsg = "Request rejected - request rejected - request rejected - request rejected - no quotes"; break;
         case 10169: errorMsg = "Request rejected - request rejected - request rejected - request rejected - client disabled"; break;
         case 10170: errorMsg = "Request rejected - request rejected - request rejected - request rejected - server busy"; break;
         case 10171: errorMsg = "Request rejected - request rejected - request rejected - request rejected - old version"; break;
         case 10172: errorMsg = "Request rejected - request rejected - request rejected - request rejected - not enough rights"; break;
         case 10173: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request frequency too high"; break;
         case 10174: errorMsg = "Request rejected - request rejected - request rejected - request rejected - no connection"; break;
         case 10175: errorMsg = "Request rejected - request rejected - request rejected - request rejected - server shutdown"; break;
         case 10176: errorMsg = "Request rejected - request rejected - request rejected - request rejected - operation disabled"; break;
         case 10177: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid stop loss"; break;
         case 10178: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid take profit"; break;
         case 10179: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid position"; break;
         case 10180: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid order"; break;
         case 10181: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid expiration"; break;
         case 10182: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid order type"; break;
         case 10183: errorMsg = "Request rejected - request rejected - request rejected - request rejected - invalid trade volume"; break;
         case 10184: errorMsg = "Request rejected - request rejected - request rejected - request rejected - market closed"; break;
         case 10185: errorMsg = "Request rejected - request rejected - request rejected - request rejected - no quotes"; break;
         case 10186: errorMsg = "Request rejected - request rejected - request rejected - request rejected - price changed"; break;
         case 10187: errorMsg = "Request rejected - request rejected - request rejected - request rejected - off quotes"; break;
         case 10188: errorMsg = "Request rejected - request rejected - request rejected - request rejected - requote"; break;
         case 10189: errorMsg = "Request rejected - request rejected - request rejected - request rejected - order expires"; break;
         case 10190: errorMsg = "Request rejected - request rejected - request rejected - request rejected - order already exists"; break;
         case 10191: errorMsg = "Request rejected - request rejected - request rejected - request rejected - order accepted"; break;
         case 10192: errorMsg = "Request rejected - request rejected - request rejected - request rejected - order accepted for execution"; break;
         case 10193: errorMsg = "Request rejected - request rejected - request rejected - request rejected - order placed"; break;
         case 10194: errorMsg = "Request rejected - request rejected - request rejected - request rejected - order modified"; break;
         case 10195: errorMsg = "Request rejected - request rejected - request rejected - request rejected - order cancelled"; break;
         case 10196: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position already exists"; break;
         case 10197: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position modified"; break;
         case 10198: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position closed"; break;
         case 10199: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position closed by opposite trade"; break;
         case 10200: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position reversed"; break;
         case 10201: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position volume added"; break;
         case 10202: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position volume subtracted"; break;
         case 10203: errorMsg = "Request rejected - request rejected - request rejected - request rejected - position reversed partially"; break;
         case 10204: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request rejected"; break;
         case 10205: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request rejected - timeout"; break;
         case 10206: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request rejected - invalid price"; break;
         case 10207: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request rejected - invalid volume"; break;
         case 10208: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request rejected - market closed"; break;
         case 10209: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request rejected - no quotes"; break;
         case 10210: errorMsg = "Request rejected - request rejected - request rejected - request rejected - request rejected - client disabled"; break;
                 default: errorMsg = "Unknown error"; break;
      }
      PrintFormat("Trade attempt %d/%d failed with error %d: %s", 
                 attempt, maxRetries, error, errorMsg);
      
      if(attempt < maxRetries) {
         Sleep(1000); // Wait before retry
      }
   }
   return false;
}

//========================= GLOBALS ==================================
int rsiHandle, g_atrHandle, emaFastHandle, emaSlowHandle;
int emaFastEntryHandle, emaSlowEntryHandle;
// EMA multi-timeframe pour alignement M5 / H1
int emaFastM4Handle, emaSlowM4Handle;
int emaFastM15Handle, emaSlowM15Handle;
int emaFastM5Handle, emaSlowM5Handle;  // M5 pour confirmation tendance
int emaScalpEntryHandle;        // EMA 10 M1 pour scalping/sniper
static datetime lastAutoTradeTime = 0;
static double   accountStartBalance = 0.0;

// Etat IA (facultatif, pour debug / affichage)
static datetime g_lastAITime      = 0;

// Prédictions de spike IA
static bool     g_aiSpikePredicted = false;
static double   g_aiSpikeZonePrice = 0.0;
static bool     g_aiSpikeDirection = true; // true=BUY, false=SELL
static datetime g_aiSpikePredictionTime = 0;
static bool     g_aiSpikeExecuted  = false;
static datetime g_aiSpikeExecTime  = 0;
static bool     g_aiSpikePendingPlaced = false; // Un ordre stop/limit pré-spike déjà placé
// Pré‑alerte de spike (warning anticipé, sans exécution auto)
static bool     g_aiEarlySpikeWarning   = false;
static double   g_aiEarlySpikeZonePrice = 0.0;
static bool     g_aiEarlySpikeDirection = true;
static bool     g_aiStrongSpike         = false; // true si spike_prediction (signal fort), false si seulement pré‑alerte
// Zones IA H1 confirmées M5
static bool     g_aiZoneAlertBuy  = false;
static bool     g_aiZoneAlertSell = false;
// Indicateurs modernes 2025 (VWAP, SuperTrend)
static double   g_currentVWAP = 0.0;
static double   g_currentSuperTrendLine = 0.0;
static int      g_currentSuperTrendDirection = 0; // 1=UP, -1=DOWN, 0=indéterminé
static datetime g_lastIndicatorsUpdate = 0;

// Analyse fondamentale (sentiment marché via Alpha Vantage / Deriv)
static double   g_fundamentalSentiment = 0.0;     // Score sentiment (-1 bearish à +1 bullish)
static string   g_fundamentalBias = "neutral";    // bullish, bearish, neutral
static datetime g_lastFundamentalUpdate = 0;
static int      g_fundamentalNewsCount = 0;
static datetime g_aiLastZoneAlert = 0;
static datetime g_lastAISummaryTime = 0;
// Stratégie de rebond sur zones IA : armement quand le prix touche la zone
static bool     g_aiBuyZoneArmed      = false;
static bool     g_aiSellZoneArmed     = false;
static datetime g_aiBuyZoneTouchTime  = 0;
static datetime g_aiSellZoneTouchTime = 0;
// Contexte de tendance après rebond / cassure pour scalping EMA50
static bool     g_aiBuyTrendActive    = false;
static bool     g_aiSellTrendActive   = false;
static datetime g_aiLastScalpTime     = 0;
// Tolérance de cassure de trendline pour validations (en points)
input int       AIZoneTrendlineBreakTolerance = 5;
// Cooldown après un trade spike (évite ré-entrées immédiates)
static datetime g_lastSpikeBlockTime = 0;
// Cooldown après pertes consécutives sur un symbole :
// - après 2 pertes consécutives : pause courte (10 minutes)
// - après 3 pertes consécutives : pause longue (30 minutes)
struct SymbolLossData {
   string symbol;          // Symbole concerné
   int consecutiveLosses;  // Nombre de pertes consécutives
   datetime cooldownUntil; // Jusqu'à quand le cooldown est actif
};

static SymbolLossData g_symbolLosses[];  // Tableau des pertes par symbole
static ulong lastAlertTimeGlobal = 0;  // Pour limiter la fréquence des alertes
static ulong lastForexLimitAlertTime = 0;  // Pour limiter les alertes de limite Forex
// g_consecutiveLosses est déjà déclaré plus haut comme variable globale
// g_recoveryUntil est déjà déclaré plus haut
static datetime g_lastSymbolLossTime = 0; // Pour compatibilité ascendante
// Cooldown spécifique Boom 300 après 2 pertes impliquant ce symbole
static datetime g_boom300CooldownUntil = 0;
// Dernière réponse JSON brute du serveur IA (pour affichage)
static string   g_lastAIJson = "";

// Mise à jour des indicateurs IA
static datetime g_lastAIIndicatorsUpdate = 0;
#define AI_INDICATORS_UPDATE_INTERVAL 300  // 5 minutes

// Variables pour les fenêtres horaires et analyse fondamentale
input bool AI_ShowTimeWindows = true;  // Afficher les fenêtres de temps

// Notifications (éviter spam)
static datetime g_lastNotificationTime = 0;
static string   g_lastNotificationSignal = "";

// Détection des spikes
static datetime g_aiSpikeDetectedTime = 0; // Heure à laquelle le dernier spike a été détecté
static datetime g_lastSpikeAlertNotifTime = 0; // Dernière notification sonore spike envoyée

// Compteur d'échecs de spike et cooldown par symbole
// Note: g_spikeFailCount et g_spikeCooldownUntil sont déjà déclarées globalement

// Timing d'entrée pré-spike
static datetime g_spikeEntryTime      = 0;  // Heure prévue d'entrée (dernière bougie avant spike)

// Helper: réinitialiser complètement l'état de signal de spike
void ClearSpikeSignal()
{
   bool wasExecuted = g_aiSpikeExecuted;

   g_aiSpikePredicted        = false;
   g_aiEarlySpikeWarning     = false;
   g_aiStrongSpike           = false;
   g_aiSpikeZonePrice        = 0.0;
   g_aiSpikeExecuted         = false;
   g_aiSpikePendingPlaced    = false;
   g_aiSpikeDetectedTime     = 0;
   g_lastSpikeAlertNotifTime = 0;
   g_spikeEntryTime          = 0;

   string arrowName = "SPIKE_ARROW_" + _Symbol;
   ObjectDelete(0, arrowName);
   string labelName = "SPIKE_COUNTDOWN_" + _Symbol;
   ObjectDelete(0, labelName);

   // Gestion des tentatives ratées: si aucun trade spike n'a été exécuté
   // avant l'annulation du signal, incrémenter le compteur d'échecs.
   if(!wasExecuted)
   {
      g_spikeFailCount++;
      if(g_spikeFailCount >= 3)
      {
         g_spikeCooldownUntil = TimeCurrent() + 10 * 60; // 10 minutes de cooldown
         g_spikeFailCount = 0;
         Print("⏸ Cooldown spike 10 minutes sur ", _Symbol, " après 3 tentatives sans spike.");
      }
   }
   else
   {
      // Sur un spike réussi, on remet à zéro le compteur et le cooldown
      g_spikeFailCount     = 0;
      g_spikeCooldownUntil = 0;
   }
}

// Structure pour les zones SMC_OB (Order Blocks)
struct SMC_OB_Zone {
   double price;           // Niveau de prix de la zone
   bool isBuyZone;         // true = zone d'achat (verte), false = zone de vente (rouge)
   datetime time;          // Heure de création de la zone
   double strength;        // Force de la zone (0-1)
   double width;           // Largeur de la zone en points
   bool isActive;          // Si la zone est toujours active
};

// Tableau des zones SMC_OB détectées
SMC_OB_Zone g_smcZones[50];
int g_smcZonesCount = 0;   // Nombre de zones actives

// Paramètres de détection des zones SMC_OB
input group "=== Paramètres SMC_OB ==="
input int SMC_OB_Lookback = 50;           // Nombre de bougies à analyser
input int SMC_OB_MinCandles = 3;          // Nombre minimum de bougies pour former une zone
input double SMC_OB_ZoneWidth = 0.0002;   // Largeur de la zone (en pourcentage du prix)
input int SMC_OB_ExpiryBars = 20;         // Nombre de bougies avant expiration d'une zone
input bool SMC_OB_UseForSpikes = true;    // Utiliser les zones SMC_OB pour la détection des spikes

// Fenêtres horaires optimales (24 heures, indexées 0-23) - spécifiques au symbole
static bool g_hourPreferred[24];  // Heures préférées pour le trading
static bool g_hourForbidden[24];  // Heures interdites pour le trading
static datetime g_lastTimeWindowsUpdate = 0;
static string   g_timeWindowsSymbol = ""; // Symbole pour lequel les fenêtres ont été récupérées

// Structure H1 (trendlines, ETE) récupérée via /analysis
static datetime g_lastAIAnalysisTime   = 0;
static double   g_h1BullStartPrice    = 0.0;
static double   g_h1BullEndPrice      = 0.0;
static datetime g_h1BullStartTime     = 0;
static datetime g_h1BullEndTime       = 0;
static double   g_h1BearStartPrice    = 0.0;
static double   g_h1BearEndPrice      = 0.0;
static datetime g_h1BearStartTime     = 0;
static datetime g_h1BearEndTime       = 0;
static bool     g_h1ETEFound          = false;
static double   g_h1ETEHeadPrice      = 0.0;
static datetime g_h1ETEHeadTime       = 0;

// Niveaux Fibonacci pour le trading
static double   g_fibonacciLevels[7] = {0.0}; // 0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100%
static datetime g_fibonacciUpdateTime = 0;
static bool     g_fibonacciValid = false;

// Trendlines supplémentaires pour H4 et M15 (même logique que H1)
static double   g_h4BullStartPrice    = 0.0;
static double   g_h4BullEndPrice      = 0.0;
static datetime g_h4BullStartTime     = 0;
static datetime g_h4BullEndTime       = 0;
static double   g_h4BearStartPrice    = 0.0;
static double   g_h4BearEndPrice      = 0.0;
static datetime g_h4BearStartTime     = 0;
static datetime g_h4BearEndTime       = 0;

static double   g_m15BullStartPrice   = 0.0;
static double   g_m15BullEndPrice     = 0.0;
static datetime g_m15BullStartTime    = 0;
static datetime g_m15BullEndTime      = 0;
static double   g_m15BearStartPrice   = 0.0;
static double   g_m15BearEndPrice     = 0.0;
static datetime g_m15BearStartTime    = 0;
static datetime g_m15BearEndTime      = 0;

// Stats volume & vitesse
static datetime lastVolumeCheck = 0;
static double   volumeAvg       = 0.0;
static double   prevSpeedPrice  = 0.0;
static datetime prevSpeedTime   = 0;
static datetime g_lastTradeAttemptTime = 0;

//-------------------- STRUCTURE INTERNE H1 (swings/creux/sommets) ----------------
struct H1SwingPoint
{
   int      index;
   datetime time;
   double   price;
   bool     isHigh;  // true = swing high, false = swing low
};

//-------------------- SÉCURITÉ AVANCÉE ------------------------------

// Vérifie si l'heure actuelle est dans la plage autorisée
// NOTE: Restriction horaire désactivée - Trading 24/7 autorisé
bool IsTradingTimeAllowed()
{
   // Trading autorisé à toute heure - pas de restriction
   return true;
}

// Stoppe les nouvelles entrées si drawdown global trop élevé
bool IsDrawdownExceeded()
{
   if(MaxDrawdownPercent <= 0.0) return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountStartBalance <= 0.0)
   {
      accountStartBalance = equity;
      return false;
   }

   double dd = (accountStartBalance - equity) / accountStartBalance * 100.0;
   if(dd >= MaxDrawdownPercent)
   {
      PrintFormat("SECURITY: Drawdown %.2f%% >= %.2f%%, blocage des nouvelles entrées", dd, MaxDrawdownPercent);
      return true;
   }
   return false;
}

// Journalisation avancée dans un fichier + Journal
void LogError(string msg)
{
   if(UseAdvancedLogging)
   {
      int h = FileOpen("F_INX_robot4_log.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_READ);
      if(h != INVALID_HANDLE)
      {
         FileSeek(h, 0, SEEK_END);
         FileWrite(h, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " ", msg);
         FileClose(h);
      }
   }
   Print(msg);
}

// Filtre: volume suffisant sur M1
bool IsVolumeSufficient()
{
   if(!UseVolumeFilter) return true;

   // Recalcule la moyenne toutes les 5 minutes
   if(TimeCurrent() - lastVolumeCheck > 300)
   {
      long buf[];
      if(CopyTickVolume(_Symbol, TF_Entry, 0, 20, buf) > 0)
      {
         double sum = 0.0;
         int cnt = ArraySize(buf);
         for(int i=0;i<cnt;i++) sum += (double)buf[i];
         volumeAvg = (cnt>0) ? sum/cnt : 0.0;
         g_lastAIIndicatorsUpdate = TimeCurrent();
      }
      lastVolumeCheck = TimeCurrent();
   }

   long curBuf[];
   if(CopyTickVolume(_Symbol, TF_Entry, 0, 1, curBuf) > 0)
   {
      if(volumeAvg <= 0.0) return true;
      double cur = (double)curBuf[0];
      return cur >= volumeAvg * VolumeMinMultiplier;
   }
   return true;
}

// Filtre: spike trop rapide (utilisé avant d'entrer)
bool IsSpikeTooFast(double currentPrice)
{
   if(!UseSpikeSpeedFilter) return false;

   datetime now = TimeCurrent();
   if(prevSpeedTime == 0 || prevSpeedPrice <= 0.0)
   {
      prevSpeedTime  = now;
      prevSpeedPrice = currentPrice;
      return false;
   }

   double dtMin = (now - prevSpeedTime) / 60.0;
   if(dtMin <= 0.0)
      return false;

   double dpPoints = MathAbs(currentPrice - prevSpeedPrice) / _Point;
   double speed    = dpPoints / dtMin; // points / minute

   prevSpeedTime  = now;
   prevSpeedPrice = currentPrice;

   return (speed >= SpikeSpeedMin);
}

// Fermeture partielle simple
void PartialClose(ulong ticket, double ratio)
{
   if(!UsePartialClose || ratio <= 0.0 || ratio >= 1.0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double vol = PositionGetDouble(POSITION_VOLUME);
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double closeVol = vol * ratio;
   // Ajuster au pas et au min
   closeVol = MathMax(minVol, MathFloor(closeVol/step)*step);
   if(closeVol < minVol || closeVol >= vol) return;

   if(!trade.PositionClosePartial(ticket, closeVol))
      LogError("PartialClose échoué, retcode=" + IntegerToString(trade.ResultRetcode()));
}

// Affiche tous les indicateurs techniques sur le graphique
void AttachChartIndicators()
{
   // Désactivé : pas d'indicateurs affichés pour garder le graphique épuré
}

//+------------------------------------------------------------------+
//| Vérification périodique de sécurité des positions               |
//+------------------------------------------------------------------+
void CheckPositionsSafety()
{
   static datetime lastCheck = 0;
   if(TimeCurrent() - lastCheck < 30) // Vérifier toutes les 30 secondes
      return;
   lastCheck = TimeCurrent();
   
   int totalPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0 && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         totalPositions++;
      }
   }
   
   if(totalPositions > 2)
   {
      Print("⚠️ ALERTE SÉCURITÉ: ", totalPositions, " positions détectées. Nettoyage en cours...");
      CloseExcessPositions();
   }
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialisation des indicateurs
   rsiHandle          = iRSI(_Symbol, TF_Entry, RSI_Period, PRICE_CLOSE);
   g_atrHandle          = iATR(_Symbol, TF_Entry, ATR_Period);
   emaFastHandle      = iMA(_Symbol, TF_Trend, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle      = iMA(_Symbol, TF_Trend, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaFastEntryHandle = iMA(_Symbol, TF_Entry, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowEntryHandle = iMA(_Symbol, TF_Entry, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaScalpEntryHandle = iMA(_Symbol, TF_Entry, EMA_Scalp_M1, 0, MODE_EMA, PRICE_CLOSE);

   // EMA multi-timeframe pour Forex / Volatilités : M5 / H1
   emaFastM4Handle   = iMA(_Symbol, PERIOD_M4,  EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM4Handle   = iMA(_Symbol, PERIOD_M4,  EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM15Handle  = iMA(_Symbol, PERIOD_M15, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM15Handle  = iMA(_Symbol, PERIOD_M15, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM5Handle   = iMA(_Symbol, PERIOD_M5,  EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5Handle   = iMA(_Symbol, PERIOD_M5,  EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   // Indicateurs de base obligatoires
   if(rsiHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE || 
      emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE ||
      emaScalpEntryHandle == INVALID_HANDLE ||
      emaFastM4Handle == INVALID_HANDLE || emaSlowM4Handle == INVALID_HANDLE ||
      emaFastM15Handle == INVALID_HANDLE || emaSlowM15Handle == INVALID_HANDLE ||
      emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE)
   {
      Print("Erreur création indicateurs de base (RSI/ATR/MA)");
      return INIT_FAILED;
   }

   // Affichage visuel des indicateurs utilisés par le robot
   AttachChartIndicators();

   // Sauvegarder le capital de départ pour le suivi du drawdown
   accountStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Vérification WebRequest pour l'IA
   if(UseAI_Agent && StringLen(AI_ServerURL) > 0)
   {
      // Extraire le domaine de l'URL pour vérifier s'il est autorisé
      string urlDomain = AI_ServerURL;
      int protocolPos = StringFind(urlDomain, "://");
      if(protocolPos >= 0)
      {
         urlDomain = StringSubstr(urlDomain, protocolPos + 3);
         int pathPos = StringFind(urlDomain, "/");
         if(pathPos >= 0)
            urlDomain = StringSubstr(urlDomain, 0, pathPos);
      }
      
      Print("========================================");
      Print("CONFIGURATION IA:");
      Print("URL Serveur: ", AI_ServerURL);
      Print("IMPORTANT: Assurez-vous que l'URL suivante est autorisée dans MT5:");
      Print("  Outils -> Options -> Expert Advisors -> Autoriser les WebRequest pour:");
      Print("  ", urlDomain);
      Print("  OU ajoutez: http://127.0.0.1");
      Print("========================================");
   }
   
   // Afficher les limites de volume et positions
   Print("========================================");
   Print("LIMITES DE TRADING:");
   Print("  - Forex: Maximum 0.01 lot");
   Print("  - Indices (Boom/Crash/Volatility): Maximum 0.2 lot");
   Print("  - Maximum 2 positions ouvertes simultanément");
   Print("  - Les autres signaux seront placés en ordres limit");
   Print("========================================");
   
   Comment("F_INX_robot4 v2 Running...");
   // Init SMC OB (ne bloque pas le robot en cas d'échec)
   if(!SMC_Init())
      Print("SMC_OB: init partielle (handles manquants), le filtre SMC sera ignoré si indisponible");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Met à jour les indicateurs techniques                             |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   // Mettre à jour les indicateurs techniques
   double rsiBuffer[3], atrBuffer[3], emaFastBuffer[3], emaSlowBuffer[3];
   
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) <= 0) return false;
   if(CopyBuffer(g_atrHandle, 0, 0, 3, atrBuffer) <= 0) return false;
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFastBuffer) <= 0) return false;
   if(CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlowBuffer) <= 0) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| ONTICK - Fonction principale appelée à chaque tick              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Mettre à jour les indicateurs
   if(!UpdateIndicators())
   {
      Print("Erreur lors de la mise à jour des indicateurs");
      return;
   }
   
   // Gérer les positions existantes avec les niveaux Fibonacci
   if(PositionsTotal() > 0)
   {
      ManagePositionsWithFibonacci();
   }
   
   // Vérifier les conditions d'entrée
   if(IsNewBar())
   {
      // Calculer les niveaux Fibonacci si nécessaire
      if(!g_fibLevelsCalculated || (TimeCurrent() - g_lastFibUpdate) > 86400) // Mise à jour quotidienne
      {
         if(CalculateFibonacciLevels())
         {
            Print("Niveaux Fibonacci mis à jour avec succès");
         }
      }
      
      CheckForEntrySignals();
   }
   
   // Gérer les positions ouvertes
   ManageOpenPositions();
   
   // Mettre à jour l'interface utilisateur
   UpdatePanel();
   
   // Afficher les niveaux Fibonacci si activé
   static datetime lastFibDraw = 0;
   if(ShowZones && (TimeCurrent() - lastFibDraw) > 60) // Mise à jour toutes les minutes
   {
      DrawFibonacciLevels();
      lastFibDraw = TimeCurrent();
   }
   
   // Vérifier les signaux de spike
   CheckSpikeSignals();
   
   // SÉCURITÉ GLOBALE : Couper les gains si objectif atteint (net profit > 2.5$)
   ManageGlobalProfitSecurity();
   
   // PROTECTION CONTRE LES PERTES TOTALES : Fermer la position avec la plus grande perte si perte totale > -6$
   CheckTotalLossProtection();
   
   // Gérer les positions ouvertes (trailing stop, break even, etc.)
   ManageTrade();
   
   // Si l'IA est activée, envoyer une requête périodiquement
   if(UseAI_Agent && StringLen(AI_ServerURL) > 0)
   {
      static datetime lastAIRequest = 0;
      static int aiRequestInterval = 5; // Envoyer une requête toutes les 5 secondes
      
      // Vérifier si assez de temps s'est écoulé depuis la dernière requête
      if(TimeCurrent() - lastAIRequest >= aiRequestInterval)
      {
         // Récupérer les données des indicateurs
         double rsi[], atr[], emaFastH1[], emaSlowH1[], emaFastM1[], emaSlowM1[];
         
         if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) > 0 &&
            CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0 &&
            CopyBuffer(emaFastHandle, 0, 0, 1, emaFastH1) > 0 &&
            CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowH1) > 0 &&
            CopyBuffer(emaFastEntryHandle, 0, 0, 1, emaFastM1) > 0 &&
            CopyBuffer(emaSlowEntryHandle, 0, 0, 1, emaSlowM1) > 0)
         {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // Déterminer les règles de direction selon le symbole
            int dirRule = AllowedDirectionFromSymbol(_Symbol);
            bool spikeMode = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            
            // Appeler l'IA pour obtenir une décision
            int aiDecision = AI_GetDecision(rsi[0], atr[0],
                                           emaFastH1[0], emaSlowH1[0],
                                           emaFastM1[0], emaSlowM1[0],
                                           ask, bid,
                                           dirRule, spikeMode);
            
            // Mettre à jour le timestamp de la dernière requête
            lastAIRequest = TimeCurrent();
            
            // Appliquer un filtre de zones extrêmes à la décision IA (éviter BUY en pleine SELL zone, etc.)
            double midPrice = (ask + bid) / 2.0;
            if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
               midPrice >= g_aiSellZoneLow && midPrice <= g_aiSellZoneHigh)
            {
               // Prix dans la SELL zone -> neutraliser les signaux BUY trop agressifs
               string actUpper = g_lastAIAction;
               StringToUpper(actUpper);
               if(actUpper == "BUY" || actUpper == "ACHAT")
               {
                  g_lastAIAction = "hold";
                  if(g_lastAIConfidence > 0.5) g_lastAIConfidence = 0.5;
                  g_lastAIReason = "Prix dans zone VENTE IA - BUY neutralisé";
               }
            }
            else if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
                    midPrice >= g_aiBuyZoneLow && midPrice <= g_aiBuyZoneHigh)
            {
               // Prix dans la BUY zone -> neutraliser les signaux SELL agressifs
               string actUpper2 = g_lastAIAction;
               StringToUpper(actUpper2);
               if(actUpper2 == "SELL" || actUpper2 == "VENTE")
               {
                  g_lastAIAction = "hold";
                  if(g_lastAIConfidence > 0.5) g_lastAIConfidence = 0.5;
                  g_lastAIReason = "Prix dans zone ACHAT IA - SELL neutralisé";
               }
            }

            // Afficher la décision IA si disponible
            if(DebugBlocks && g_lastAIAction != "")
            {
               Print("IA Decision: ", g_lastAIAction, " (Confiance: ", DoubleToString(g_lastAIConfidence, 2), ") - ", g_lastAIReason);
            }

            // Affichage sur le graphique de la décision IA (action / confiance / raison)
            if(g_lastAIAction != "")
            {
               DrawAIRecommendation(g_lastAIAction, g_lastAIConfidence, g_lastAIReason, ask);
            }
            
            // Afficher l'alerte de spike si prédit
            if(g_aiSpikePredicted)
            {
               DisplaySpikeAlert();
            }
         }
      }
   }
   
   // Mettre à jour l'affichage clignotant des alertes de spike
   UpdateSpikeAlertDisplay();
   DrawAIZones();
   CheckAIZoneAlerts();

   // Détection Boom/Crash pour activer la variante spéciale de scalp de zone
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);

   if(UseAIZoneBounceStrategy)
   {
      // Sur Boom/Crash, si activé, on utilise une logique plus agressive:
      // tout rebond propre dans la zone BUY/SELL ouvre un scalp avec TP fixe.
      if(isBoomCrashSymbol && UseBoomCrashZoneScalps)
         EvaluateBoomCrashZoneScalps();
      else
      EvaluateAIZoneBounceStrategy();
   }
   SendAISummaryIfDue();
   // Rafraîchir périodiquement la structure H1 (trendlines, ETE) et la tracer
   AI_UpdateAnalysis();

   // Rafraîchir les zones SMC sur le graphique (~10s)
   static datetime lastSmcZoneUpdate = 0;
   if(TimeCurrent() - lastSmcZoneUpdate >= 10)
   {
      lastSmcZoneUpdate = TimeCurrent();
      SMC_UpdateZones();
   }

   // Mise à jour périodique des fenêtres horaires + affichage mini bas-gauche
   AI_UpdateTimeWindows();
   AI_UpdateFundamentalAnalysis(); // Mise à jour analyse fondamentale
   DrawTimeWindowsPanel();

   // Entrées autonomes SMC (optionnel, non bloquant)
   if(Use_SMC_OB_Entries && IsTradingTimeAllowed() && !IsDrawdownExceeded() && CountPositionsForSymbolMagic() == 0)
   {
      static datetime lastSmcEntryCheck = 0;
      if(TimeCurrent() - lastSmcEntryCheck >= 10) // throttle 10s
      {
         lastSmcEntryCheck = TimeCurrent();
         bool smcIsBuy = false;
         double smcEntry = 0, smcSL = 0, smcTP = 0, smcAtr = 0;
         string smcReason = "";
         if(SMC_GenerateSignal(smcIsBuy, smcEntry, smcSL, smcTP, smcReason, smcAtr))
         {
            ENUM_ORDER_TYPE orderType = smcIsBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            double price = smcIsBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            string comment = "SMC_OB";
            if(StringLen(smcReason) > 0) comment += "_" + smcReason;
            ExecuteTrade(orderType, smcAtr, price, comment, 1.0);
         }
      }
   }

   // Scalp EMA50 sur mouvement en cours (après rebond / cassure zones IA)
   // Désactivé pour Boom/Crash quand la variante spéciale de scalp de zone est active,
   // afin d'éviter des doublons de trades.
   if(UseAIZoneBounceStrategy && AI_AutoExecuteTrades)
   {
      if(!(isBoomCrashSymbol && UseBoomCrashZoneScalps))
      EvaluateAIZoneEMAScalps();
   }
}

//+------------------------------------------------------------------+
//| Gestionnaire d'événements pour le timer                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Supprimer les anciennes alertes
   datetime now = TimeCurrent();
   
   // Calculer le profit moyen par trade
   double avgProfit = (g_totalTradesCount > 0) ? g_totalProfitLoss / g_totalTradesCount : 0.0;
   
   // Préparer la liste des symboles uniques
   string uniqueSymbols = "";
   for(int i = 0; i < ArraySize(g_tradedSymbolsList); i++)
   {
      if(g_tradedSymbolsList[i] != "")
      {
         if(uniqueSymbols != "") uniqueSymbols += ", ";
         uniqueSymbols += g_tradedSymbolsList[i];
      }
   }
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "SpikeAlert_") == 0)
      {
         datetime time = (datetime)StringToInteger(StringSubstr(name, 11));
         if(now - time >= 30) // 30 secondes
         {
            ObjectDelete(0, name);
         }
      }
   }
   
   // Créer le message de bilan
   string bilan = StringFormat(
      "📊 BILAN DES TRADES 📊\n" +
      "------------------------\n" +
      "🔢 Nombre total de trades: %d\n" +
      "💰 Capital total engagé: %.2f $\n" +
      "💵 Profit/Perte total: %.2f $ (%.2f $ par trade)\n" +
      "📈📉 Symboles tradés: %s\n" +
      "⏱️ Dernier trade: %s",
      g_totalTradesCount,
      g_totalCapitalEngaged,
      g_totalProfitLoss,
      avgProfit,
      (uniqueSymbols == "" ? "Aucun" : uniqueSymbols),
      (g_lastTradeTime > 0 ? TimeToString(g_lastTradeTime, TIME_DATE|TIME_MINUTES) : "Aucun")
   );
   
   // Envoyer la notification
   SendNotification(bilan);
   Print("📤 Bilan des trades envoyé: ", bilan);
}

//+------------------------------------------------------------------+
//| Envoie un bilan des trades par notification                     |
//+------------------------------------------------------------------+
void SendTradeBilanNotification(bool forceSend = false)
{
   // Vérifier si on envoie le bilan (toutes les heures ou si forcé)
   datetime now = TimeCurrent();
   if(!forceSend && (now - g_lastBilanNotification < 3600)) // Toutes les heures
      return;
      
   // Mettre à jour le temps de la dernière notification
   g_lastBilanNotification = now;
   
   // Calculer le profit moyen par trade
   double avgProfit = (g_totalTradesCount > 0) ? g_totalProfitLoss / g_totalTradesCount : 0;
   
   // Préparer la liste des symboles uniques
   string uniqueSymbols = "";
   for(int i = 0; i < ArraySize(g_tradedSymbolsList); i++)
   {
      if(g_tradedSymbolsList[i] != "")
      {
         if(uniqueSymbols != "") uniqueSymbols += ", ";
         uniqueSymbols += g_tradedSymbolsList[i];
      }
   }
   
   // Créer le message de bilan
   string bilan = StringFormat(
      "📊 BILAN DES TRADES 📊\n" +
      "------------------------\n" +
      "🔢 Nombre total de trades: %d\n" +
      "💰 Capital total engagé: %.2f $\n" +
      "💵 Profit/Perte total: %.2f $ (%.2f $ par trade)\n" +
      "📈📉 Symboles tradés: %s\n" +
      "⏱️ Dernier trade: %s",
      g_totalTradesCount,
      g_totalCapitalEngaged,
      g_totalProfitLoss,
      avgProfit,
      (uniqueSymbols == "" ? "Aucun" : uniqueSymbols),
      (g_lastTradeTime > 0 ? TimeToString(g_lastTradeTime, TIME_DATE|TIME_MINUTES) : "Aucun")
   );
   
   // Envoyer la notification
   SendNotification(bilan);
   Print("📤 Bilan des trades envoyé: ", bilan);
}

//+------------------------------------------------------------------+
//| Met à jour les statistiques de trading                          |
//+------------------------------------------------------------------+
void UpdateTradingStats(double lotSize, double profit, string symbol)
{
   // Mettre à jour le compteur de trades
   g_totalTradesCount++;
   
   // Mettre à jour le capital engagé (lot * 100000 pour avoir la valeur en devise)
   g_totalCapitalEngaged += lotSize * 100000;
   
   // Mettre à jour le profit/perte total
   g_totalProfitLoss += profit;
   
   // Mettre à jour la liste des symboles tradés
   bool symbolExists = false;
   for(int i = 0; i < ArraySize(g_tradedSymbolsList); i++)
   {
      if(g_tradedSymbolsList[i] == symbol)
      {
         symbolExists = true;
         break;
      }
      else if(g_tradedSymbolsList[i] == "")
      {
         g_tradedSymbolsList[i] = symbol;
         symbolExists = true;
         break;
      }
   }
   
   // Mettre à jour le temps du dernier trade
   g_lastTradeTime = TimeCurrent();
   
   // Mettre à jour le suivi des pertes pour ce symbole
   UpdateSymbolLossTracking(symbol, profit);
   
   // Envoyer le bilan si nécessaire
   SendTradeBilanNotification(false);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(rsiHandle);
   IndicatorRelease(g_atrHandle);
}

//+------------------------------------------------------------------+
//| Dessine les indicateurs modernes 2025 (VWAP et SuperTrend)      |
//+------------------------------------------------------------------+
void DrawModernIndicators()
{
   // Vérifier si on doit envoyer un bilan quotidien (à minuit)
   datetime now = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(now, timeStruct);
   if(timeStruct.hour == 0 && timeStruct.min == 0 && now - g_lastBilanNotification > 3600)
   {
      SendTradeBilanNotification(true);
   }
   long chart_id = ChartFirst(); // Commencer par le premier graphique du symbole
   while(chart_id >= 0)
   {
      if(ChartSymbol(chart_id) != _Symbol)
      {
         chart_id = ChartNext(chart_id);
         continue;
      }
      
      // ========== VWAP (Volume Weighted Average Price) ==========
      if(g_currentVWAP > 0.0)
      {
         string vwapName = "VWAP_" + _Symbol;
         
         // Supprimer l'ancien VWAP s'il existe
         ObjectDelete(chart_id, vwapName);
         
         // Créer une ligne horizontale pour VWAP
         if(ObjectCreate(chart_id, vwapName, OBJ_HLINE, 0, 0, g_currentVWAP))
         {
            ObjectSetInteger(chart_id, vwapName, OBJPROP_COLOR, (long)clrCyan); // Cyan pour VWAP
            ObjectSetInteger(chart_id, vwapName, OBJPROP_STYLE, (long)STYLE_DASH);
            ObjectSetInteger(chart_id, vwapName, OBJPROP_WIDTH, (long)2);
            ObjectSetInteger(chart_id, vwapName, OBJPROP_BACK, (long)true);
            ObjectSetInteger(chart_id, vwapName, OBJPROP_SELECTABLE, (long)false);
            ObjectSetInteger(chart_id, vwapName, OBJPROP_TIMEFRAMES, (long)OBJ_ALL_PERIODS);
            ObjectSetString(chart_id, vwapName, OBJPROP_TEXT, "VWAP");
            
            // Ajouter un label avec la valeur
            string vwapLabelName = "VWAP_LABEL_" + _Symbol;
            ObjectDelete(chart_id, vwapLabelName);
            
            datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, 0);
            if(ObjectCreate(chart_id, vwapLabelName, OBJ_TEXT, 0, labelTime, g_currentVWAP))
            {
               ObjectSetString(chart_id, vwapLabelName, OBJPROP_TEXT, "VWAP: " + DoubleToString(g_currentVWAP, _Digits));
               ObjectSetInteger(chart_id, vwapLabelName, OBJPROP_COLOR, (long)clrCyan);
               ObjectSetInteger(chart_id, vwapLabelName, OBJPROP_FONTSIZE, (long)9);
               ObjectSetString(chart_id, vwapLabelName, OBJPROP_FONT, "Arial");
               ObjectSetInteger(chart_id, vwapLabelName, OBJPROP_ANCHOR, (long)ANCHOR_RIGHT);
               ObjectSetInteger(chart_id, vwapLabelName, OBJPROP_BACK, (long)false);
               ObjectSetInteger(chart_id, vwapLabelName, OBJPROP_SELECTABLE, (long)false);
               ObjectSetInteger(chart_id, vwapLabelName, OBJPROP_TIMEFRAMES, (long)OBJ_ALL_PERIODS);
            }
         }
      }
      
      // ========== SuperTrend ==========
      if(g_currentSuperTrendLine > 0.0)
      {
         string stName = "SUPERTREND_" + _Symbol;
         
         // Supprimer l'ancien SuperTrend s'il existe
         ObjectDelete(chart_id, stName);
         
         // Couleur selon la direction (vert = uptrend, rouge = downtrend)
         color stColor = (g_currentSuperTrendDirection > 0) ? clrLime : clrOrange;
         if(g_currentSuperTrendDirection == 0) stColor = clrSilver;
         
         // Créer une ligne horizontale pour SuperTrend
         if(ObjectCreate(chart_id, stName, OBJ_HLINE, 0, 0, g_currentSuperTrendLine))
         {
            ObjectSetInteger(chart_id, stName, OBJPROP_COLOR, stColor);
            ObjectSetInteger(chart_id, stName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(chart_id, stName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(chart_id, stName, OBJPROP_BACK, true);
            ObjectSetInteger(chart_id, stName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(chart_id, stName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            
            string trendText = (g_currentSuperTrendDirection > 0) ? "SuperTrend ↑" : 
                               (g_currentSuperTrendDirection < 0) ? "SuperTrend ↓" : "SuperTrend";
            ObjectSetString(chart_id, stName, OBJPROP_TEXT, trendText);
            
            // Ajouter un label avec la valeur
            string stLabelName = "SUPERTREND_LABEL_" + _Symbol;
            ObjectDelete(chart_id, stLabelName);
            
            datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, 0);
            if(ObjectCreate(chart_id, stLabelName, OBJ_TEXT, 0, labelTime, g_currentSuperTrendLine))
            {
               string directionIcon = (g_currentSuperTrendDirection > 0) ? "↑" : 
                                      (g_currentSuperTrendDirection < 0) ? "↓" : "→";
               ObjectSetString(chart_id, stLabelName, OBJPROP_TEXT, "ST " + directionIcon + ": " + DoubleToString(g_currentSuperTrendLine, _Digits));
               ObjectSetInteger(chart_id, stLabelName, OBJPROP_COLOR, stColor);
               ObjectSetInteger(chart_id, stLabelName, OBJPROP_FONTSIZE, 9);
               ObjectSetString(chart_id, stLabelName, OBJPROP_FONT, "Arial Bold");
               ObjectSetInteger(chart_id, stLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
               ObjectSetInteger(chart_id, stLabelName, OBJPROP_BACK, false);
               ObjectSetInteger(chart_id, stLabelName, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(chart_id, stLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            }
         }
      }
      
      ChartRedraw(chart_id);
      chart_id = ChartNext(chart_id);
   }
}

//+------------------------------------------------------------------+
//| Notification périodique des analyses IA                          |
//+------------------------------------------------------------------+
void SendAISummaryIfDue()
{
   if(!AI_UseNotifications) return;
   int intervalSec = 600; // 10 minutes
   datetime now = TimeCurrent();
   if(g_lastAISummaryTime > 0 && (now - g_lastAISummaryTime) < intervalSec)
      return;

   // Construire un résumé compact
   string msg = StringFormat("IA RÉSUMÉ %s\nAction: %s (conf %.1f%%)\nRaison: %s",
                             _Symbol,
                             g_lastAIAction,
                             g_lastAIConfidence * 100.0,
                             g_lastAIReason);

   // Ajouter zones si disponibles
   if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0)
      msg += StringFormat("\nZone Achat H1/M5: %.5f - %.5f", g_aiBuyZoneLow, g_aiBuyZoneHigh);
   if(g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0)
      msg += StringFormat("\nZone Vente H1/M5: %.5f - %.5f", g_aiSellZoneLow, g_aiSellZoneHigh);

   // Spike info
   if(g_aiSpikePredicted && g_aiSpikeZonePrice > 0.0)
   {
      msg += StringFormat("\nSpike prévu: %s zone %.5f", (g_aiSpikeDirection ? "BUY" : "SELL"), g_aiSpikeZonePrice);
   }

   SendNotification(msg);
   g_lastAISummaryTime = now;
}

//+------------------------------------------------------------------+
//| Notification quand le prix entre dans une zone IA                 |
//+------------------------------------------------------------------+
void CheckAIZoneAlerts()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (bid + ask) / 2.0;
   datetime now = TimeCurrent();

   int alertCooldown = 60; // 1 minute anti-spam

   // BUY zone
   bool inBuyZone = (g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
                     price >= g_aiBuyZoneLow && price <= g_aiBuyZoneHigh);
   if(inBuyZone && !g_aiZoneAlertBuy && (now - g_aiLastZoneAlert > alertCooldown))
   {
      g_aiZoneAlertBuy = true;
      g_aiLastZoneAlert = now;
      string msg = StringFormat("Zone ACHAT (H1/M5) touchée sur %s : %.5f-%.5f | Prix %.5f (attente rebond M5, %d bougie(s))",
                                _Symbol, g_aiBuyZoneLow, g_aiBuyZoneHigh, price, AIZoneConfirmBarsM5);
      Print(msg);
      if(AI_UseNotifications)
         SendNotification(msg);

      // Armer la stratégie de rebond BUY (le trade sera déclenché après confirmation M5)
      g_aiBuyZoneArmed     = true;
      g_aiBuyZoneTouchTime = now;
   }
   if(!inBuyZone)
   {
      g_aiZoneAlertBuy = false;
      g_aiBuyZoneArmed = false;
   }

   // SELL zone
   bool inSellZone = (g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0 &&
                      price >= g_aiSellZoneLow && price <= g_aiSellZoneHigh);
   if(inSellZone && !g_aiZoneAlertSell && (now - g_aiLastZoneAlert > alertCooldown))
   {
      g_aiZoneAlertSell = true;
      g_aiLastZoneAlert = now;
      string msg = StringFormat("Zone VENTE (H1/M5) touchée sur %s : %.5f-%.5f | Prix %.5f (attente rebond M5, %d bougie(s))",
                                _Symbol, g_aiSellZoneLow, g_aiSellZoneHigh, price, AIZoneConfirmBarsM5);
      Print(msg);
      if(AI_UseNotifications)
         SendNotification(msg);

      // Armer la stratégie de rebond SELL
      g_aiSellZoneArmed     = true;
      g_aiSellZoneTouchTime = now;
   }
   if(!inSellZone)
   {
      g_aiZoneAlertSell = false;
      g_aiSellZoneArmed = false;
   }
}

//+------------------------------------------------------------------+
//| Stratégie de rebond entre zones IA BUY/SELL                      |
//| - Attend que le prix touche une zone (CheckAIZoneAlerts)        |
//| - Puis confirme le rebond avec des bougies M5                    |
//| - Ouvre un trade vers le milieu entre les deux zones             |
//+------------------------------------------------------------------+
void EvaluateAIZoneBounceStrategy()
{
   if(!UseAIZoneBounceStrategy || !AI_AutoExecuteTrades)
      return;

   // Sécurité globale : limite dynamique selon le type de symbole
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   int maxPerSymbol = isBoomCrashSymbol ? 3 : 2;
   if(!CanOpenNewPosition() || CountPositionsForSymbolMagic() >= maxPerSymbol)
      return;

   // S'assurer que les deux zones sont définies pour pouvoir calculer le milieu
   if(!(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
        g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
      return;
   double price = (bid + ask) / 2.0;

   // Charger les bougies M5 pour détecter le rebond
   // On exige au moins 3 bougies pour une structure de retournement plus fiable
   int neededBars = MathMax(3, AIZoneConfirmBarsM5);
   MqlRates ratesM5[];
   if(CopyRates(_Symbol, PERIOD_M5, 0, neededBars + 1, ratesM5) <= neededBars)
      return;

   // Helper local pour tester "rebond haussier" / "rebond baissier"
   bool bullishConfirm = true;
   bool bearishConfirm = true;
   for(int i = 0; i < neededBars; i++)
   {
      // i=0 => bougie la plus récente
      double o = ratesM5[i].open;
      double c = ratesM5[i].close;
      if(!(c > o))
         bullishConfirm = false;
      if(!(c < o))
         bearishConfirm = false;
   }

   // EMA M5 pour filtrer les faux rebonds (éviter de trader une simple correction)
   double emaM5Buf[];
   if(CopyBuffer(emaFastM5Handle, 0, 0, 1, emaM5Buf) <= 0)
      return;
   double emaM5 = emaM5Buf[0];

   // Filtre cassure de trendlines H1/M15
   double tlTolerance = AIZoneTrendlineBreakTolerance * _Point;

   // Récupérer la valeur des trendlines H1 au prix courant
   double bullH1 = 0.0, bearH1 = 0.0;
   if(ObjectFind(0, "AI_H1_BULL_TL") >= 0)
      bullH1 = ObjectGetValueByTime(0, "AI_H1_BULL_TL", TimeCurrent(), 0);
   if(ObjectFind(0, "AI_H1_BEAR_TL") >= 0)
      bearH1 = ObjectGetValueByTime(0, "AI_H1_BEAR_TL", TimeCurrent(), 0);

   // Trendlines M15 optionnelles (si tu les ajoutes plus tard)
   double bullM15 = 0.0, bearM15 = 0.0;
   if(ObjectFind(0, "AI_M15_BULL_TL") >= 0)
      bullM15 = ObjectGetValueByTime(0, "AI_M15_BULL_TL", TimeCurrent(), 0);
   if(ObjectFind(0, "AI_M15_BEAR_TL") >= 0)
      bearM15 = ObjectGetValueByTime(0, "AI_M15_BEAR_TL", TimeCurrent(), 0);

   bool buyTrendlineBroken = false;
   bool sellTrendlineBroken = false;

   // Cassure baissière des trendlines haussières (pour SELL)
   if(bullH1 > 0 && price < bullH1 - tlTolerance) sellTrendlineBroken = true;
   if(bullM15 > 0 && price < bullM15 - tlTolerance) sellTrendlineBroken = true;

   // Cassure haussière des trendlines baissières (pour BUY)
   if(bearH1 > 0 && price > bearH1 + tlTolerance) buyTrendlineBroken = true;
   if(bearM15 > 0 && price > bearM15 + tlTolerance) buyTrendlineBroken = true;

   // Centres des zones et cible au milieu
   double buyCenter  = (g_aiBuyZoneLow  + g_aiBuyZoneHigh)  * 0.5;
   double sellCenter = (g_aiSellZoneLow + g_aiSellZoneHigh) * 0.5;
   double midTarget  = (buyCenter + sellCenter) * 0.5;

   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0)
      return;

   // BUY après rebond dans la zone de résistance (BUY zone)
   // Conditions assouplies pour détecter plus d'opportunités :
   //  - Le prix doit toucher ou être proche de la zone de résistance
   //  - Confirmation par au moins 2 bougies M5 haussières
   //  - La dernière bougie doit clôturer au-dessus de l'ouverture
   //  - Pas de vérification stricte de l'EMA M5 pour plus de flexibilité
   bool nearResistance = (price >= g_aiBuyZoneLow * 0.9995 && price <= g_aiBuyZoneHigh * 1.0005);
   
   // Vérifier si on a au moins 2 bougies M5 haussières
   int bullishBars = 0;
   for(int i = 0; i < 3; i++) {
      if(ratesM5[i].close > ratesM5[i].open) bullishBars++;
   }
   
   // Vérifier la pente des lignes de tendance IA
   bool trendlineSupport = false;
   double trendlineValue = 0;
   
   // Vérifier la ligne de tendance haussière IA si elle existe
   if(ObjectFind(0, "AI_H1_BULL_TL") >= 0) {
      trendlineValue = ObjectGetValueByTime(0, "AI_H1_BULL_TL", TimeCurrent(), 0);
      // Vérifier si le prix est proche de la ligne de tendance (dans 0.2%)
      if(MathAbs(price - trendlineValue) / price <= 0.002) {
         trendlineSupport = true;
      }
   }
   
   // Conditions d'entrée améliorées avec les lignes de tendance IA
   if((g_aiBuyZoneArmed || nearResistance || trendlineSupport) && 
      bullishBars >= 2 && 
      ratesM5[0].close > ratesM5[0].open &&
      (buyTrendlineBroken || !UseTrendlineFilter || trendlineSupport))
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_BUY_BOUNCE";
         if(ExecuteTrade(ORDER_TYPE_BUY, atr[0], ask, comment, 1.0))
         {
            // Ajuster TP au milieu des zones et SL au bord inférieur de la BUY zone
            if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double slLevel = NormalizeDouble(g_aiBuyZoneLow, _Digits);   // bord inférieur rectangle vert
               double tpLevel = NormalizeDouble(midTarget, _Digits);        // milieu entre BUY et SELL zones
               trade.PositionModify(_Symbol, slLevel, tpLevel);
            }

            if(AI_UseNotifications)
            {
               string msg = StringFormat("AI BUY ZONE: rebond confirmé (%d bougies M5). Trade BUY ouvert, TP au milieu des zones: %.5f",
                                         neededBars, midTarget);
               SendNotification(msg);
            }
            g_aiBuyTrendActive  = true;
            g_aiSellTrendActive = false;
         }
      }
      g_aiBuyZoneArmed = false;
   }

   // SELL après rebond dans la zone de support (SELL zone)
   // Conditions assouplies pour détecter plus d'opportunités :
   //  - Le prix doit toucher ou être proche de la zone de support
   //  - Confirmation par au moins 2 bougies M5 baissières
   //  - La dernière bougie doit clôturer en-dessous de l'ouverture
   //  - Pas de vérification stricte de l'EMA M5 pour plus de flexibilité
   bool nearSupport = (price <= g_aiSellZoneHigh * 1.0005 && price >= g_aiSellZoneLow * 0.9995);
   
   // Vérifier si on a au moins 1 bougie M5 baissière (condition assouplie)
   bool hasBearishBar = (ratesM5[0].close < ratesM5[0].open);
   
   // Vérifier la tendance M5 (moyenne mobile 20 périodes)
   double ema20M5[];
   bool downtrend = false;
   int ema20Handle = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(CopyBuffer(ema20Handle, 0, 0, 2, ema20M5) > 0) {
      // Tendance baissière si le prix est sous l'EMA20 et que l'EMA pointe vers le bas
      downtrend = (price < ema20M5[0]) && (ema20M5[0] < ema20M5[1]);
   }
   
   // Vérifier la résistance de la ligne de tendance baissière IA
   bool trendlineResistance = false;
   double trendlineResistValue = 0;
   
   if(ObjectFind(0, "AI_H1_BEAR_TL") >= 0) {
      trendlineResistValue = ObjectGetValueByTime(0, "AI_H1_BEAR_TL", TimeCurrent(), 0);
      // Vérifier si le prix est proche de la ligne de tendance (dans 0.2%)
      if(MathAbs(price - trendlineResistValue) / price <= 0.002) {
         trendlineResistance = true;
      }
   }
   
   // Conditions d'entrée améliorées avec détection de tendance
   bool sellSignal = (g_aiSellZoneArmed || nearSupport || trendlineResistance || downtrend);
   bool priceBelowEMA = (ema20M5[0] > 0 && price < ema20M5[0]);
   
   if(sellSignal && 
      (hasBearishBar || downtrend) &&  // Une seule bougie baissière suffit si tendance
      (sellTrendlineBroken || !UseTrendlineFilter || trendlineResistance || priceBelowEMA))
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_SELL_BOUNCE";
         if(ExecuteTrade(ORDER_TYPE_SELL, atr[0], bid, comment, 1.0))
         {
            // Ajuster TP au milieu des zones et SL au bord supérieur de la SELL zone
            if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double slLevel = NormalizeDouble(g_aiSellZoneHigh, _Digits); // bord supérieur rectangle rouge
               double tpLevel = NormalizeDouble(midTarget, _Digits);
               trade.PositionModify(_Symbol, slLevel, tpLevel);
            }

            if(AI_UseNotifications)
            {
               string msg = StringFormat("AI SELL ZONE: rebond confirmé (%d bougies M5). Trade SELL ouvert, TP au milieu des zones: %.5f",
                                         neededBars, midTarget);
               SendNotification(msg);
            }
            g_aiSellTrendActive = true;
            g_aiBuyTrendActive  = false;
         }
      }
      g_aiSellZoneArmed = false;
   }

   // -----------------------------------------------------------------
   // Cas 2 : Cassure franche de la zone -> trade dans le sens tendance
   // -----------------------------------------------------------------

   // Cassure BAISSIÈRE de la BUY zone => SELL de continuation (scalping)
   if(g_aiBuyZoneArmed && bearishConfirm && price < g_aiBuyZoneLow)
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_BUY_BREAK_SELL";
         if(ExecuteTrade(ORDER_TYPE_SELL, atr[0], bid, comment, 1.0))
         {
            // SL au-dessus du bord inférieur de la BUY zone, TP au milieu
            if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double slLevel = NormalizeDouble(g_aiBuyZoneLow, _Digits);   // quelques points au-dessus seront ajustés par ValidateAndAdjustStops
               double tpLevel = NormalizeDouble(midTarget, _Digits);
               trade.PositionModify(_Symbol, slLevel, tpLevel);
            }

            if(AI_UseNotifications)
            {
               string msg = StringFormat("AI BUY ZONE cassée à la baisse. Rebond absent, SELL de tendance ouvert (scalping). Prix: %.5f",
                                         price);
               SendNotification(msg);
            }
            g_aiSellTrendActive = true;
            g_aiBuyTrendActive  = false;
         }
      }
      g_aiBuyZoneArmed = false;
   }

   // Cassure HAUSSIÈRE de la SELL zone => BUY de continuation
   if(g_aiSellZoneArmed && bullishConfirm && price > g_aiSellZoneHigh)
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_SELL_BREAK_BUY";
         if(ExecuteTrade(ORDER_TYPE_BUY, atr[0], ask, comment, 1.0))
         {
            // SL en dessous du bord supérieur de la SELL zone, TP au milieu
            if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double slLevel = NormalizeDouble(g_aiSellZoneHigh, _Digits);
               double tpLevel = NormalizeDouble(midTarget, _Digits);
               trade.PositionModify(_Symbol, slLevel, tpLevel);
            }

            if(AI_UseNotifications)
            {
               string msg = StringFormat("AI SELL ZONE cassée à la hausse. Rebond absent, BUY de tendance ouvert (scalping). Prix: %.5f",
                                         price);
               SendNotification(msg);
            }
            g_aiBuyTrendActive  = true;
            g_aiSellTrendActive = false;
         }
      }
      g_aiSellZoneArmed = false;
   }
}

//+------------------------------------------------------------------+
//| BOOM/CRASH : scalp agressif sur rebond propre en zone IA         |
//| - S'applique uniquement aux symboles Boom/Crash                   |
//| - Ne demande PAS que les deux zones (BUY & SELL) soient définies |
//| - Confirmation simple : X bougies dans le sens du rebond sur TF  |
//|   configurable (par défaut M15, adapté à Boom 1000 M15)          |
//| - TP / SL fixes en points, indépendants de l'ATR                 |
//+------------------------------------------------------------------+
void EvaluateBoomCrashZoneScalps()
{
   if(!UseBoomCrashZoneScalps || !AI_AutoExecuteTrades)
      return;

   // Uniquement pour Boom/Crash
   bool isBoom  = (StringFind(_Symbol, "Boom")  != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   if(!isBoom && !isCrash)
      return;

   // Respecter les limites globales (3 positions max pour Boom/Crash)
   int maxPerSymbol = 3;
   if(!CanOpenNewPosition() || CountPositionsForSymbolMagic() >= maxPerSymbol)
      return;
   if(!IsTradingTimeAllowed() || IsDrawdownExceeded())
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
      return;
   double price = (bid + ask) * 0.5;

   // Charger les bougies sur le TF de confirmation (par défaut M15)
   int neededBars = MathMax(1, BC_ConfirmBars);
   MqlRates ratesConf[];
   if(CopyRates(_Symbol, BC_ConfirmTF, 0, neededBars + 1, ratesConf) <= neededBars)
      return;

   // Helpers : confirmation haussière / baissière simple
   bool bullishConfirm = true;
   bool bearishConfirm = true;
   for(int i = 0; i < neededBars; i++)
   {
      double o = ratesConf[i].open;
      double c = ratesConf[i].close;
      if(!(c > o))
         bullishConfirm = false;
      if(!(c < o))
         bearishConfirm = false;
   }

   // Récupérer ATR pour la taille de lot (mais TP/SL seront fixes)
   double atrBuf[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atrBuf) <= 0)
      return;
   double atr = atrBuf[0];

   // Taille fixe SL/TP en points
   double tpDist = BC_TP_Points * _Point;
   double slDist = BC_SL_Points * _Point;

   // -------------------------- BUY SCALP ---------------------------
   // - Rebond propre dans BUY zone
   // - Pour Boom : BUY uniquement
   bool inBuyZone = (g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
                     price >= g_aiBuyZoneLow && price <= g_aiBuyZoneHigh);

   if(inBuyZone && g_aiBuyZoneArmed && bullishConfirm && isBoom)
   {
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
      double entryPrice = ask;

      if(ExecuteTrade(orderType, atr, entryPrice, "BC_ZONE_BUY_SCALP", 1.0))
      {
         // Ajuster TP/SL immédiatement après ouverture: TP/SL FIXES
         if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double sl = NormalizeDouble(entryPrice - slDist, _Digits);
            double tp = NormalizeDouble(entryPrice + tpDist, _Digits);
            trade.PositionModify(_Symbol, sl, tp);
         }

         if(AI_UseNotifications)
         {
            string msg = StringFormat("Boom BUY zone scalp: rebond confirmé (%d bougie(s) %s). TP fixe: +%d pts",
                                      neededBars,
                                      EnumToString(BC_ConfirmTF),
                                      BC_TP_Points);
            SendNotification(msg);
         }

         // On désarme la zone pour éviter les doublons
         g_aiBuyZoneArmed = false;
      }
   }

   // -------------------------- SELL SCALP --------------------------
   // - Rebond propre dans SELL zone
   // - Pour Crash : SELL uniquement
   bool inSellZone = (g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0 &&
                      price >= g_aiSellZoneLow && price <= g_aiSellZoneHigh);

   if(inSellZone && g_aiSellZoneArmed && bearishConfirm && isCrash)
   {
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_SELL;
      double entryPrice = bid;

      if(ExecuteTrade(orderType, atr, entryPrice, "BC_ZONE_SELL_SCALP", 1.0))
      {
         if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double sl = NormalizeDouble(entryPrice + slDist, _Digits);
            double tp = NormalizeDouble(entryPrice - tpDist, _Digits);
            trade.PositionModify(_Symbol, sl, tp);
         }

         if(AI_UseNotifications)
         {
            string msg = StringFormat("Crash SELL zone scalp: rebond confirmé (%d bougie(s) %s). TP fixe: +%d pts",
                                      neededBars,
                                      EnumToString(BC_ConfirmTF),
                                      BC_TP_Points);
            SendNotification(msg);
         }

         g_aiSellZoneArmed = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Scalping EMA50 sur mouvement en cours                           |
//| - Après rebond/cassure, utilise les retours vers l'EMA M5       |
//+------------------------------------------------------------------+
void EvaluateAIZoneEMAScalps()
{
   if(!UseAIZoneBounceStrategy || !AI_AutoExecuteTrades)
      return;

   // Contexte : tendance active (BUY ou SELL)
   if(!g_aiBuyTrendActive && !g_aiSellTrendActive)
      return;

   // Respecter limites globales et par symbole
   if(!CanOpenNewPosition() || CountPositionsForSymbolMagic() >= 2)
      return;

   // Cooldown entre deux scalps
   if(g_aiLastScalpTime != 0 && (TimeCurrent() - g_aiLastScalpTime) < AIZoneScalpCooldownSec)
      return;

   // Zones nécessaires pour calculer TP/SL
   if(!(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
        g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
      return;
   double price = (bid + ask) / 2.0;

   // EMA M5 (période configurable, par défaut 50)
   double emaBuf[];
   int handle = emaFastM5Handle;
   if(AIZoneScalpEMAPeriodM5 != EMA_Fast)
      handle = iMA(_Symbol, PERIOD_M5, AIZoneScalpEMAPeriodM5, 0, MODE_EMA, PRICE_CLOSE);

   if(handle == INVALID_HANDLE || CopyBuffer(handle, 0, 0, 1, emaBuf) <= 0)
      return;

   double ema = emaBuf[0];
   double tolerance = AIZoneScalpEMAToleranceP * _Point;

   // Cible commune : milieu des deux zones
   double buyCenter  = (g_aiBuyZoneLow  + g_aiBuyZoneHigh)  * 0.5;
   double sellCenter = (g_aiSellZoneLow + g_aiSellZoneHigh) * 0.5;
   double midTarget  = (buyCenter + sellCenter) * 0.5;

   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0)
      return;

   // BUY scalp : tendance haussière active + pullback vers EMA
   if(g_aiBuyTrendActive && MathAbs(price - ema) <= tolerance)
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_EMA_BUY_SCALP";
         if(ExecuteTrade(ORDER_TYPE_BUY, atr[0], ask, comment, 1.0))
         {
            if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double slLevel = NormalizeDouble(g_aiBuyZoneLow, _Digits);
               double tpLevel = NormalizeDouble(midTarget, _Digits);
               trade.PositionModify(_Symbol, slLevel, tpLevel);
            }
            g_aiLastScalpTime = TimeCurrent();
         }
      }
   }

   // SELL scalp : tendance baissière active + pullback vers EMA
   if(g_aiSellTrendActive && MathAbs(price - ema) <= tolerance)
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_EMA_SELL_SCALP";
         if(ExecuteTrade(ORDER_TYPE_SELL, atr[0], bid, comment, 1.0))
         {
            if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double slLevel = NormalizeDouble(g_aiSellZoneHigh, _Digits);
               double tpLevel = NormalizeDouble(midTarget, _Digits);
               trade.PositionModify(_Symbol, slLevel, tpLevel);
            }
            g_aiLastScalpTime = TimeCurrent();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si un signal d'entrée est valide et cohérent avec l'IA   |
//| VALIDATION RENFORCÉE : Signaux vérifiés et validés à 100%        |
//+------------------------------------------------------------------+
bool IsValidSignal(ENUM_ORDER_TYPE type, double confidence = 1.0)
{
   g_lastValidationReason = "";
   int validationScore = 0;  // Score de validation (doit atteindre 100 pour valider)
   int maxScore = 100;
   string rejectionReasons = "";
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   
   // AUDIT: Ajuster le seuil dynamiquement pour Boom/Crash (plus réactif)
   int effectiveMinScore = SignalValidationMinScore;
   if(isBoomCrash) effectiveMinScore = 70;  // Plus permissif pour capter les spikes
   
   // ========== VALIDATION 1: COHÉRENCE IA (20 points) ==========
   if(UseAI_Agent)
   {
      if(g_lastAIAction == "")
      {
         rejectionReasons += "IA non disponible; ";
         g_lastValidationReason = rejectionReasons;
         return false; // Rejet immédiat si IA activée mais pas de réponse
      }
      
      bool aiAgrees = false;
      string aiActionUpper = g_lastAIAction;
      StringToUpper(aiActionUpper);
      
      if((type == ORDER_TYPE_BUY && (aiActionUpper == "BUY" || aiActionUpper == "ACHAT")) ||
         (type == ORDER_TYPE_SELL && (aiActionUpper == "SELL" || aiActionUpper == "VENTE")))
      {
         aiAgrees = true;
         validationScore += 10; // +10 si direction cohérente
      }
      else
      {
         rejectionReasons += "IA en désaccord (" + g_lastAIAction + "); ";
         // Pour Boom/Crash on bloque, pour le reste (Forex, indices) on laisse passer si AI_CanBlockTrades=false
         if(isBoomCrash || AI_CanBlockTrades)
         {
            g_lastValidationReason = rejectionReasons;
            return false; // Rejet si IA n'est pas d'accord
         }
      }
      
      // Confiance IA élevée requise (minimum 0.7 pour validation complète)
      if(g_lastAIConfidence >= 0.7)
      {
         validationScore += 10; // +10 si confiance élevée
      }
      else if(g_lastAIConfidence < AI_MinConfidence)
      {
         rejectionReasons += "Confiance IA trop faible (" + DoubleToString(g_lastAIConfidence, 2) + "); ";
         // Pour Boom/Crash ou si AI_CanBlockTrades=true, on bloque ; sinon on laisse passer mais avec moins de points
         if(isBoomCrash || AI_CanBlockTrades)
         {
            g_lastValidationReason = rejectionReasons;
            return false; // Rejet si confiance trop faible
         }
      }
      else
      {
         validationScore += 5; // +5 si confiance moyenne
      }
   }
   else
   {
      validationScore += 20; // Si IA désactivée, on donne les points
   }
   
   // ========== VALIDATION 2: CONDITIONS DE MARCHÉ (15 points) ==========
   // Vérifier le spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(spread > MaxSpreadPoints * _Point)
   {
      rejectionReasons += "Spread trop élevé (" + DoubleToString(spread, 5) + "); ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   validationScore += 5; // Spread acceptable
   
   // Vérifier la volatilité
   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) < 1)
   {
      rejectionReasons += "ATR indisponible; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   if(atr[0] >= MinATR && atr[0] <= MaxATR)
   {
      validationScore += 10; // Volatilité dans la plage optimale
   }
   else
   {
      rejectionReasons += "Volatilité hors plage (ATR=" + DoubleToString(atr[0], 5) + "); ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // ========== VALIDATION 3: INDICATEURS MULTI-TIMEFRAME STRICT (25 points) ==========
   // RÈGLE STRICTE: H1 + M5 doivent être 100% alignés, puis trader en M1
   double rsi[], rsiM1[];
   double emaFastH1[], emaSlowH1[];
   double emaFastM5[], emaSlowM5[];
   double emaFastM1[], emaSlowM1[];
   
   // Récupérer RSI
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3 ||
      CopyBuffer(rsiHandle, 0, 0, 3, rsiM1) < 3)
   {
      rejectionReasons += "RSI indisponible; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // Récupérer EMA H1, M5 et M1 (STRICT: ces 3 TF doivent être alignés)
   if(CopyBuffer(emaFastHandle,   0, 0, 3, emaFastH1)  < 3 ||
      CopyBuffer(emaSlowHandle,   0, 0, 3, emaSlowH1)  < 3 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 3, emaFastM5)  < 3 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 3, emaSlowM5)  < 3 ||
      CopyBuffer(emaFastEntryHandle,0,0,3, emaFastM1)  < 3 ||
      CopyBuffer(emaSlowEntryHandle,0,0,3, emaSlowM1)  < 3)
   {
      rejectionReasons += "EMA H1/M5/M1 indisponibles; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // DÉTECTION STRICTE: tendance claire sur les 3 dernières bougies
   // H1: tendance de fond (DOIT être claire à 100%)
   bool h1TrendUp   = emaFastH1[0] > emaSlowH1[0] && emaFastH1[1] > emaSlowH1[1] && emaFastH1[2] > emaSlowH1[2];
   bool h1TrendDown = emaFastH1[0] < emaSlowH1[0] && emaFastH1[1] < emaSlowH1[1] && emaFastH1[2] < emaSlowH1[2];
   
   // M5: confirmation intermédiaire (DOIT être alignée avec H1)
   bool m5TrendUp   = emaFastM5[0] > emaSlowM5[0] && emaFastM5[1] > emaSlowM5[1] && emaFastM5[2] > emaSlowM5[2];
   bool m5TrendDown = emaFastM5[0] < emaSlowM5[0] && emaFastM5[1] < emaSlowM5[1] && emaFastM5[2] < emaSlowM5[2];
   
   // M1: entrée (DOIT confirmer la direction)
   bool m1TrendUp   = emaFastM1[0] > emaSlowM1[0] && emaFastM1[1] > emaSlowM1[1];
   bool m1TrendDown = emaFastM1[0] < emaSlowM1[0] && emaFastM1[1] < emaSlowM1[1];
   
   // BLOCAGE STRICT: Si H1 n'a pas de tendance claire, on ne trade PAS
   if(!h1TrendUp && !h1TrendDown)
   {
      rejectionReasons += "PAS DE TENDANCE CLAIRE EN H1 - ON SE CALME; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // BLOCAGE STRICT: Si M5 n'est pas aligné avec H1, on ne trade PAS
   if(h1TrendUp && !m5TrendUp)
   {
      rejectionReasons += "M5 NON ALIGNÉ AVEC H1 (haussier) - ON SE CALME; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   if(h1TrendDown && !m5TrendDown)
   {
      rejectionReasons += "M5 NON ALIGNÉ AVEC H1 (baissier) - ON SE CALME; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // RÈGLE ANTI-CONTRE-TENDANCE: Ne JAMAIS trader contre H1
   if(type == ORDER_TYPE_BUY && h1TrendDown)
   {
      rejectionReasons += "INTERDIT: BUY contre tendance H1 baissière; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   if(type == ORDER_TYPE_SELL && h1TrendUp)
   {
      rejectionReasons += "INTERDIT: SELL contre tendance H1 haussière; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // Validation finale: H1 + M5 + M1 tous alignés
   if(type == ORDER_TYPE_BUY)
   {
      if(!(h1TrendUp && m5TrendUp && m1TrendUp))
      {
         rejectionReasons += "Tendances non 100% alignées (BUY) sur H1/M5/M1 - ON SE CALME; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      validationScore += 25; // Tendances parfaitement alignées
   }
   else // SELL
   {
      if(!(h1TrendDown && m5TrendDown && m1TrendDown))
      {
         rejectionReasons += "Tendances non 100% alignées (SELL) sur H1/M5/M1 - ON SE CALME; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      validationScore += 25; // Tendances parfaitement alignées
   }
   
   // ========== VALIDATION 4: SMC / ORDER BLOCK (20 points) ==========
   if(Use_SMC_OB_Filter)
   {
      bool smcIsBuy = false;
      double smcEntry = 0, smcSL = 0, smcTP = 0, smcAtr = 0;
      string smcReason = "";
      if(!SMC_GenerateSignal(smcIsBuy, smcEntry, smcSL, smcTP, smcReason, smcAtr))
      {
         rejectionReasons += "Pas de setup SMC; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      if((type == ORDER_TYPE_BUY && !smcIsBuy) || (type == ORDER_TYPE_SELL && smcIsBuy))
      {
         rejectionReasons += "SMC oppose la direction; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      validationScore += 20;
   }
   
   // ========== VALIDATION 5: MOMENTUM ET CONVERGENCE (20 points) ==========
   // Vérifier que le momentum est fort (EMA rapide s'éloigne de la lente)
   double emaGapH1 = MathAbs(emaFastH1[0] - emaSlowH1[0]);
   double emaGapM1 = MathAbs(emaFastM1[0] - emaSlowM1[0]);
   double priceH1  = (emaFastH1[0] + emaSlowH1[0]) / 2.0;
   double priceM1  = (emaFastM1[0] + emaSlowM1[0]) / 2.0;
   
   // Le gap doit être significatif (au moins 0.1% du prix)
   double minGapH1 = priceH1 * 0.001;
   double minGapM1 = priceM1 * 0.001;
   
   if(emaGapH1 >= minGapH1 && emaGapM1 >= minGapM1)
   {
      validationScore += 10; // Momentum fort
   }
   else
   {
      rejectionReasons += "Momentum insuffisant (gap EMA trop faible); ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // Vérifier la convergence des indicateurs (tous doivent pointer dans la même direction)
   bool rsiConfirm = (type == ORDER_TYPE_BUY && rsi[0] > 50 && rsiM1[0] > 50) ||
                     (type == ORDER_TYPE_SELL && rsi[0] < 50 && rsiM1[0] < 50);
   
   if(rsiConfirm)
   {
      validationScore += 10; // RSI confirme la direction
   }
   else
   {
      rejectionReasons += "RSI ne confirme pas la direction; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // ========== VALIDATION 5: CONDITIONS TEMPORELLES ET SÉCURITÉ (10 points) ==========
   if(!IsTradingTimeAllowed())
   {
      rejectionReasons += "Hors heures de trading; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   validationScore += 5;
   
   // Vérifier qu'on n'a pas déjà une position ouverte
   if(CountPositionsForSymbolMagic() > 0)
   {
      rejectionReasons += "Position déjà ouverte; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   // Gestion des pertes consécutives sur ce marché (symbole)
   int consecLoss = GetConsecutiveLosses();
   // Règle primordiale: après 3 pertes consécutives, rester loin de ce marché pendant 30 minutes minimum
   if(consecLoss >= 3)
   {
      // Démarrer un cooldown long si pas déjà actif
      if(!IsSymbolLossCooldownActive(1800))
         StartSymbolLossCooldown();
      
      if(IsSymbolLossCooldownActive(1800))
      {
         rejectionReasons += "Cooldown après 3 pertes consécutives (30 min); ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
   }
   // Protection intermédiaire: après au moins 2 pertes consécutives, courte pause de 3 minutes
   else if(consecLoss >= 2)
   {
      if(!IsSymbolLossCooldownActive(180))
         StartSymbolLossCooldown();
      
      if(IsSymbolLossCooldownActive(180))
      {
         rejectionReasons += "Cooldown après pertes (3 min); ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
   }
   validationScore += 5;
   
   // ========== VALIDATION 6: VOLUME ET LIQUIDITÉ (10 points) ==========
   // Vérifier le volume si le filtre est activé
   if(UseVolumeFilter)
   {
      if(!IsVolumeSufficient())
      {
         rejectionReasons += "Volume insuffisant; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      validationScore += 10;
   }
   else
   {
      validationScore += 10; // Si filtre désactivé, on donne les points
   }
   
   // ========== VALIDATION FINALE ==========
   // Le score doit atteindre le seuil minimum (ajusté pour Boom/Crash)
   if(validationScore >= effectiveMinScore)
   {
      Print("✅ SIGNAL VALIDÉ - Score: ", validationScore, "/", maxScore, " (Seuil: ", effectiveMinScore, ") - Type: ", EnumToString(type), 
            " - Confiance IA: ", DoubleToString(g_lastAIConfidence, 2));
      return true;
   }
   else
   {
      g_lastValidationReason = rejectionReasons;
      Print("❌ Signal rejeté - Score: ", validationScore, "/", maxScore, " (Seuil: ", effectiveMinScore, ") - Raisons: ", rejectionReasons);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Calcule les niveaux Fibonacci à partir des points pivots         |
//+------------------------------------------------------------------+
bool CalculateFibonacciLevels()
{
   // Niveaux Fibonacci standards
   double fiboLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
   ArrayResize(g_fibLevels, ArraySize(fiboLevels));
   
   // Récupérer les points pivots (high et low) de la veille
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, rates) < 2)
   {
      Print("Erreur lors de la récupération des données historiques");
      return false;
   }
   
   double high = rates[1].high;
   double low = rates[1].low;
   double range = high - low;
   
   // Calculer les niveaux de prix pour chaque niveau Fibonacci
   for(int i = 0; i < ArraySize(fiboLevels); i++)
   {
      g_fibLevels[i] = low + (range * fiboLevels[i]);
      PrintFormat("Niveau Fibonacci %d: %s", i, DoubleToString(g_fibLevels[i], _Digits));
   }
   
   g_lastFibUpdate = TimeCurrent();
   g_fibLevelsCalculated = true;
   return true;
}

//+------------------------------------------------------------------+
//| Affiche les niveaux Fibonacci sur le graphique                   |
//+------------------------------------------------------------------+
void DrawFibonacciLevels()
{
   if(!g_fibLevelsCalculated) return;
   
   // Supprimer les anciens objets
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "Fib_Level_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   // Afficher les niveaux
   for(int i = 0; i < ArraySize(g_fibLevels); i++)
   {
      string levelName = "Fib_Level_" + IntegerToString(i);
      double price = g_fibLevels[i];
      string text = "Fib " + DoubleToString(price, _Digits);
      
      // Créer une ligne horizontale pour le niveau
      if(!ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, price))
      {
         Print("Erreur lors de la création du niveau Fibonacci: ", GetLastError());
         continue;
      }
      
      // Définir les propriétés de la ligne
      ObjectSetInteger(0, levelName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, levelName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, levelName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, levelName, OBJPROP_BACK, true);
      
      // Ajouter une étiquette de texte
      string labelName = levelName + "_Label";
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), price))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, text);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
   }
   
   // Mettre à jour le graphique
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes avec les niveaux Fibonacci           |
//+------------------------------------------------------------------+
void ManagePositionsWithFibonacci()
{
   // Vérifier si les niveaux Fibonacci sont à jour
   if(!g_fibLevelsCalculated || (TimeCurrent() - g_lastFibUpdate) > 86400) // Mise à jour quotidienne
   {
      if(CalculateFibonacciLevels())
      {
         Print("Niveaux Fibonacci mis à jour avec succès");
      }
      else
      {
         Print("Erreur lors de la mise à jour des niveaux Fibonacci");
         return;
      }
   }
   
   // Afficher les niveaux Fibonacci sur le graphique
   if(ShowZones)
   {
      DrawFibonacciLevels();
   }
   
   // Parcourir toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      // Récupérer les informations de la position
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;
      
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Vérifier si le prix est proche d'un niveau Fibonacci
      for(int j = 0; j < ArraySize(g_fibLevels); j++)
      {
         double distance = MathAbs(currentPrice - g_fibLevels[j]) / _Point;
         
         // Si le prix est proche d'un niveau Fibonacci (dans une zone de 5 points)
         if(distance < 5)
         {
            string levelName = "Fib " + DoubleToString(g_fibLevels[j], _Digits);
            
            // Ajuster le stop loss pour les positions en profit
            if(posType == POSITION_TYPE_BUY && currentPrice > openPrice)
            {
               // Pour les positions d'achat en profit, ajuster le stop loss
               double newSL = g_fibLevels[j] - (10 * _Point); // 10 points sous le niveau Fibonacci
               if(newSL > stopLoss + (10 * _Point)) // Ne déplacer que vers le haut
               {
                  trade.PositionModify(ticket, newSL, takeProfit);
                  PrintFormat("Stop loss ajusté pour la position #%d à %s (Niveau: %s)", 
                             ticket, DoubleToString(newSL, _Digits), levelName);
               }
            }
            else if(posType == POSITION_TYPE_SELL && currentPrice < openPrice)
            {
               // Pour les positions de vente en profit, ajuster le stop loss
               double newSL = g_fibLevels[j] + (10 * _Point); // 10 points au-dessus du niveau Fibonacci
               if(newSL < stopLoss - (10 * _Point) || stopLoss == 0) // Ne déplacer que vers le bas
               {
                  trade.PositionModify(ticket, newSL, takeProfit);
                  PrintFormat("Stop loss ajusté pour la position #%d à %s (Niveau: %s)", 
                             ticket, DoubleToString(newSL, _Digits), levelName);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si un stop loss est valide selon les règles du broker    |
//+------------------------------------------------------------------+
bool IsValidStopLoss(string symbol, double entry, double sl, bool isBuy)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   long digits = (long)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long stopLevel = (long)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopLevel * point * 1.5; // Marge de sécurité 50%
   
   double distance = MathAbs(entry - sl);
   
   if(distance < minStopDistance)
   {
      Print("Stop Loss invalide: ", DoubleToString(distance, (int)digits), 
            " (min: ", DoubleToString(minStopDistance, (int)digits), ")");
      return false;
   }
   
   // Vérifier que le stop n'est pas trop éloigné (plus de 5x la distance minimale)
   if(distance > (minStopDistance * 5))
   {
      Print("Stop Loss trop éloigné: ", DoubleToString(distance, (int)digits));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Compte le nombre d'ordres en attente pour le symbole courant     |
//+------------------------------------------------------------------+
int CountPendingOrdersForSymbol()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

// Compte tous les ordres en attente (tous symboles) pour ce Magic
int CountAllPendingOrdersForMagic()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Trouve l'ordre limit le plus proche du prix actuel               |
//+------------------------------------------------------------------+
ulong FindClosestPendingOrder(double &closestPrice)
{
   ulong closestTicket = 0;
   double minDistance = DBL_MAX;
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if((orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT) ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;
      
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double distance = MathAbs(orderPrice - currentPrice);
      
      if(distance < minDistance)
      {
         minDistance = distance;
         closestTicket = ticket;
         closestPrice = orderPrice;
      }
   }
   
   return closestTicket;
}

//+------------------------------------------------------------------+
//| Exécute l'ordre limit le plus proche en scalping                  |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE orderType, double lotSize, double sl = 0.0, double tp = 0.0, string comment = "", bool isBoomCrash = false, bool isVol = false, bool isSpike = false)
{
   // Vérifier s'il existe déjà une position sur ce symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         // Vérifier si la position existante est dans la même direction
         if((orderType == ORDER_TYPE_BUY && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ||
            (orderType == ORDER_TYPE_SELL && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY))
         {
            // Fermer la position existante avant d'en ouvrir une nouvelle dans la direction opposée
            CTrade localTrade;
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
               localTrade.PositionClose(ticket);
               Print("Fermeture de la position opposée #", ticket, " avant d'ouvrir une nouvelle position");
               // Attendre un court instant pour que la fermeture soit traitée
               Sleep(500);
            }
         }
         else
         {
            // Une position dans la même direction existe déjà
            Print("Une position ", EnumToString((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)), " existe déjà sur ", _Symbol);
            return false;
         }
      }
   }
   
   // Vérifier si on peut ouvrir une nouvelle position
   double closestPrice = 0.0;
   ulong closestTicket = FindClosestPendingOrder(closestPrice);
   
   if(closestTicket == 0)
   {
      Print("Aucun ordre en attente trouvé");
      return false;
   }
   
   if(!OrderSelect(closestTicket))
   {
      Print("Échec de la sélection de l'ordre ", closestTicket);
      return false;
   }
   
   // Récupérer les paramètres de l'ordre
   ENUM_ORDER_TYPE currentOrderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   double orderLot = OrderGetDouble(ORDER_VOLUME_CURRENT);
   double orderSl = OrderGetDouble(ORDER_SL);
   double orderTp = OrderGetDouble(ORDER_TP);
   string orderComment = OrderGetString(ORDER_COMMENT);
   
   // Supprimer l'ordre limit
   // Utiliser l'objet trade global pour supprimer l'ordre
   if(!trade.OrderDelete(closestTicket))
   {
      Print("Erreur suppression ordre limit le plus proche: ", GetLastError());
      return false;
   }
   
   // VÉRIFIER LA LIMITE DE POSITIONS AVANT D'OUVRIR (GLOBALE + PAR SYMBOLE)
   // Limite globale: 2 par défaut, 3 pour Boom/Crash
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   int maxPerSymbol = isBoomCrashSymbol ? 3 : 2;
   if(!CanOpenNewPosition())
   {
      Print("❌ Scalping bloqué: limite globale de positions atteinte");
      return false;
   }

   // Limite par symbole: dynamique selon Boom/Crash ou non
   if(CountPositionsForSymbolMagic() >= maxPerSymbol)
   {
      Print("🛑 Scalping bloqué: ", maxPerSymbol, " positions déjà ouvertes sur ", _Symbol);
      return false;
   }
   
   // Exécuter au marché immédiatement
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool result = false;
   
   if(currentOrderType == ORDER_TYPE_BUY_LIMIT || currentOrderType == ORDER_TYPE_BUY)
   {
      result = trade.Buy(orderLot, _Symbol, ask, orderSl, orderTp, orderComment + "_SCALP");
   }
   else if(currentOrderType == ORDER_TYPE_SELL_LIMIT || currentOrderType == ORDER_TYPE_SELL)
   {
      result = trade.Sell(orderLot, _Symbol, bid, orderSl, orderTp, orderComment + "_SCALP");
   }
   
   if(result)
   {
      Print("Ordre limit le plus proche exécuté en scalping: ", closestTicket, " Prix: ", closestPrice);
   }
   else
   {
      Print("Erreur exécution ordre limit le plus proche: ", trade.ResultRetcode());
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Gère les ordres limit: exécute le plus proche, garde les autres  |
//+------------------------------------------------------------------+
void ManagePendingOrders()
{
   // Ne pas gérer si on a déjà une position ouverte (laisser finir)
   if(CountPositionsForSymbolMagic() > 0)
      return;
   
   int pendingCount = CountPendingOrdersForSymbol();
   
   // Si on a plus de 2 ordres limit, supprimer les plus éloignés
   if(pendingCount > MaxLimitOrdersPerSymbol)
   {
      // Créer un tableau pour stocker les tickets et distances
      ulong tickets[];
      double distances[];
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
      
      ArrayResize(tickets, pendingCount);
      ArrayResize(distances, pendingCount);
      int idx = 0;
      
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket)) continue;
         
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT) ||
            OrderGetString(ORDER_SYMBOL) != _Symbol ||
            OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
            continue;
         
         double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         tickets[idx] = ticket;
         distances[idx] = MathAbs(orderPrice - currentPrice);
         idx++;
      }
      
      // Trier par distance (tri à bulles simple)
      for(int i = 0; i < idx - 1; i++)
      {
         for(int j = 0; j < idx - i - 1; j++)
         {
            if(distances[j] > distances[j + 1])
            {
               // Échanger distances
               double tempDist = distances[j];
               distances[j] = distances[j + 1];
               distances[j + 1] = tempDist;
               
               // Échanger tickets
               ulong tempTicket = tickets[j];
               tickets[j] = tickets[j + 1];
               tickets[j + 1] = tempTicket;
            }
         }
      }
      
      // Supprimer les ordres les plus éloignés (garder seulement les 2 plus proches)
      for(int i = MaxLimitOrdersPerSymbol; i < idx; i++)
      {
         trade.OrderDelete(tickets[i]);
         Print("Ordre limit éloigné supprimé (max ", MaxLimitOrdersPerSymbol, "): ", tickets[i]);
      }
   }
   
   // Si on a exactement 2 ordres limit et que l'option scalping est activée, exécuter le plus proche
   if(pendingCount == MaxLimitOrdersPerSymbol && ExecuteClosestLimitForScalping)
   {
      ExecuteClosestPendingOrder();
   }
}

//+------------------------------------------------------------------+
//| Exécute l'ordre en attente le plus proche du prix actuel        |
//+------------------------------------------------------------------+
bool ExecuteClosestPendingOrder()
{
   double closestPrice = 0.0;
   ulong closestTicket = FindClosestPendingOrder(closestPrice);
   
   if(closestTicket == 0)
   {
      Print("Aucun ordre en attente trouvé pour exécution");
      return false;
   }
   
   if(!OrderSelect(closestTicket))
   {
      Print("Échec de la sélection de l'ordre ", closestTicket);
      return false;
   }
   
   // Récupérer les paramètres de l'ordre
   ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   double orderLot = OrderGetDouble(ORDER_VOLUME_CURRENT);
   double orderSl = OrderGetDouble(ORDER_SL);
   double orderTp = OrderGetDouble(ORDER_TP);
   string orderComment = OrderGetString(ORDER_COMMENT);
   
   // Supprimer l'ordre en attente
   if(!trade.OrderDelete(closestTicket))
   {
      Print("Erreur lors de la suppression de l'ordre ", closestTicket, ": ", GetLastError());
      return false;
   }
   
   // Exécuter l'ordre au marché
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool result = false;
   
   if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)
   {
      result = trade.Buy(orderLot, _Symbol, ask, orderSl, orderTp, orderComment + "_EXECUTED");
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP)
   {
      result = trade.Sell(orderLot, _Symbol, bid, orderSl, orderTp, orderComment + "_EXECUTED");
   }
   
   if(result)
   {
      Print("Ordre en attente exécuté: ", closestTicket, " Type: ", EnumToString(orderType), " Prix: ", closestPrice);
      return true;
   }
   else
   {
      Print("Échec de l'exécution de l'ordre ", closestTicket, ": ", trade.ResultRetcode());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Annule tous les ordres en attente pour le symbole courant        |
//+------------------------------------------------------------------+
void CancelAllPendingOrders()
{
   // Use the global trade object instead of creating a new one
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            trade.OrderDelete(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Valide et ajuste les SL/TP selon les distances minimales du broker |
//+------------------------------------------------------------------+
bool ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE type, double &executionPrice, double &sl, double &tp)
{
   // Récupérer les paramètres de distance minimale du broker
   long stopLevel   = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   long minPoints   = stopLevel + freezeLevel + 2; // Marge de sécurité supplémentaire
   if(minPoints < 1) minPoints = 1; // Minimum 1 point
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minDist = minPoints * point;
   
   // Récupérer les prix de marché actuels pour validation
   double curAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double curBid = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Prix de référence pour la validation (prix d'exécution ou prix de marché)
   double refPrice = executionPrice;
   if(refPrice <= 0.0)
   {
      // Si pas de prix d'exécution spécifié, utiliser le prix de marché
      refPrice = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT) ? curAsk : curBid;
   }
   
   // Normaliser le prix de référence
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   refPrice = NormalizeDouble(refPrice, digits);
   
   bool isValid = true;
   
   // Valider et ajuster le SL
   if(sl != 0.0)
   {
      double slDistance = MathAbs(refPrice - sl);
      
      if(slDistance < minDist)
      {
         // Ajuster le SL pour respecter la distance minimale
         if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
         {
            sl = NormalizeDouble(refPrice - minDist, digits);
         }
         else // SELL ou SELL_LIMIT
         {
            sl = NormalizeDouble(refPrice + minDist, digits);
         }
         
         // Vérifier aussi par rapport au prix de marché actuel
         double marketRefPrice = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT) ? curAsk : curBid;
         if(marketRefPrice > 0.0)
         {
            double slDistFromMarket = MathAbs(marketRefPrice - sl);
            if(slDistFromMarket < minDist)
            {
               if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
                  sl = NormalizeDouble(marketRefPrice - minDist, digits);
               else
                  sl = NormalizeDouble(marketRefPrice + minDist, digits);
            }
         }
      }
      
      // Vérification finale : le SL ne doit pas être au-delà du prix d'exécution pour BUY
      // ou en-deçà pour SELL
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
      {
         if(sl >= refPrice)
         {
            sl = NormalizeDouble(refPrice - minDist, digits);
         }
      }
      else
      {
         if(sl <= refPrice)
         {
            sl = NormalizeDouble(refPrice + minDist, digits);
         }
      }
   }
   
   // Valider et ajuster le TP
   if(tp != 0.0)
   {
      double tpDistance = MathAbs(refPrice - tp);
      
      if(tpDistance < minDist)
      {
         // Ajuster le TP pour respecter la distance minimale
         if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
         {
            tp = NormalizeDouble(refPrice + minDist, digits);
         }
         else // SELL ou SELL_LIMIT
         {
            tp = NormalizeDouble(refPrice - minDist, digits);
         }
         
         // Vérifier aussi par rapport au prix de marché actuel
         double marketRefPrice = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT) ? curAsk : curBid;
         if(marketRefPrice > 0.0)
         {
            double tpDistFromMarket = MathAbs(marketRefPrice - tp);
            if(tpDistFromMarket < minDist)
            {
               if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
                  tp = NormalizeDouble(marketRefPrice + minDist, digits);
               else
                  tp = NormalizeDouble(marketRefPrice - minDist, digits);
            }
         }
      }
      
      // Vérification finale : le TP doit être dans le bon sens
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
      {
         if(tp <= refPrice)
         {
            tp = NormalizeDouble(refPrice + minDist, digits);
         }
      }
      else
      {
         if(tp >= refPrice)
         {
            tp = NormalizeDouble(refPrice - minDist, digits);
         }
      }
   }
   
   return isValid;
}

//+------------------------------------------------------------------+
//| Exécution des trades et gestion Lots/Pending                     |
//| isSpikePriority=true : permet à un trade spike de passer devant  |
//| la limite globale de 2 positions/ordres pour ne pas louper le   |
//| mouvement, tout en respectant le max 2 positions par symbole.   |
//+------------------------------------------------------------------+
// Variable globale anti-spam
static datetime g_lastExecuteTime = 0;

//+------------------------------------------------------------------+
//| Vérifie les conditions de trading                               |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Vérifier les objectifs quotidiens
   if(IsDailyTargetReached())
      return false;
      
   // Vérifier les pertes consécutives sur ce symbole
   if(!CanTradeSymbolAfterLoss(_Symbol))
      return false;

   // Vérifier la limite de perte quotidienne
   if(IsDailyLossLimitReached())
   {
      if(GetTickCount() % 60000 < 1000) // Afficher une fois par minute max
         Print("❌ Limite de perte quotidienne atteinte: ", g_dailyLoss, " ", AccountInfoString(ACCOUNT_CURRENCY));
      return false;
   }
   
   // Vérifier le nombre de pertes consécutives
   if(g_consecutiveLosses >= MaxConsecLosses && MaxConsecLosses > 0)
   {
      if(GetTickCount() % 60000 < 1000) // Afficher une fois par minute max
         Print("⚠️ Arrêt après ", g_consecutiveLosses, " pertes consécutives");
      return false;
   }
   
   // Vérifier les pertes consécutives (fonction existante)
   if(!CanTradeAfterLosses())
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Vérifie si les objectifs quotidiens sont atteints               |
//+------------------------------------------------------------------+
bool IsDailyTargetReached()
{
   if(DailyProfitTarget <= 0) return false;
   
   // Réinitialiser les compteurs si nouveau jour
   if(TimeCurrent() >= g_lastTradeDay + 86400) // 86400 secondes = 1 jour
   {
      g_dailyProfit = 0.0;
      g_dailyLoss = 0.0;
      g_lastTradeDay = iTime(_Symbol, PERIOD_D1, 0);
   }
   
   return (g_dailyProfit >= DailyProfitTarget);
}

//+------------------------------------------------------------------+
//| Vérifie si la limite de perte quotidienne est atteinte           |
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached()
{
   if(DailyLossLimit <= 0) return false;
   
   // Réinitialiser les compteurs si nouveau jour
   if(TimeCurrent() >= g_lastTradeDay + 86400) // 86400 secondes = 1 jour
   {
      g_dailyProfit = 0.0;
      g_dailyLoss = 0.0;
      g_lastTradeDay = iTime(_Symbol, PERIOD_D1, 0);
   }
   
   return (g_dailyLoss >= DailyLossLimit);
}

//+------------------------------------------------------------------+
//| Vérifie si une nouvelle bougie est apparue sur le timeframe actuel |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour les statistiques de trading (version simplifiée)     |
//+------------------------------------------------------------------+
void UpdateTradingStats(double profit)
{
   if(profit > 0)
   {
      g_dailyProfit += profit;
      g_consecutiveLosses = 0; // Réinitialiser le compteur de pertes
   }
   else
   {
      g_dailyLoss += MathAbs(profit);
      g_consecutiveLosses++;
   }
   
   // Mettre à jour le suivi des pertes par symbole
   UpdateSymbolLossTracking(_Symbol, profit);
   
   // Utiliser une taille de lot par défaut si non spécifiée
   double defaultLotSize = 0.1; // Valeur par défaut
   
   // Mettre à jour les statistiques de trading (fonction surchargée)
   UpdateTradingStats(defaultLotSize, profit, _Symbol);
   
   // Journaliser les performances
   if(profit != 0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      PrintFormat("Trade clôturé: %+.2f %s (Total: %.2f %s | Objectif: %.2f | Perte max: %.2f)",
                 profit, AccountInfoString(ACCOUNT_CURRENCY),
                 balance, AccountInfoString(ACCOUNT_CURRENCY),
                 DailyProfitTarget, DailyLossLimit);
   }
}

//+------------------------------------------------------------------+
//| Met à jour le compteur de pertes après une position fermée       |
//+------------------------------------------------------------------+
void UpdateLossCounter(double profit)
{
   if(profit < 0) // Perte
   {
      g_consecutiveLosses++;
      Print("📉 Perte enregistrée. Pertes consécutives: ", g_consecutiveLosses);
      
      if(g_consecutiveLosses == 2) // Après 2 pertes consécutives
      {
         // 30 minutes de pause après 2 pertes
         g_recoveryUntil = TimeCurrent() + 1800; // 30 minutes
         Print("⏸ Pause de 30 minutes après 2 pertes consécutives. Reprise à ", 
               TimeToString(g_recoveryUntil, TIME_MINUTES));
      }
   }
   else if(profit > 0) // Profit, on réinitialise le compteur
   {
      if(g_consecutiveLosses > 0)
      {
         Print("✅ Profit réalisé, réinitialisation du compteur de pertes consécutives");
         g_consecutiveLosses = 0;
         g_recoveryUntil = 0;
      }
   }
}

bool ExecuteTrade(ENUM_ORDER_TYPE type, double atr, double price, string comment, double lotMultiplier = 1.0, bool isSpikePriority = false)
{
   // Vérifier si le trading est activé
   if(!EnableTrading)
   {
      Print("Trading is disabled by user setting");
      return false;
   }
   
   // Vérifier l'équité minimale
   if(AccountInfoDouble(ACCOUNT_EQUITY) < MinEquityForTrading)
   {
      Print("Insufficient equity to open new position");
      return false;
   }
   
   // Vérifier si on peut trader
   if(!CanOpenNewPosition()) 
   {
      Print("Cannot open new position - position limit reached");
      return false;
   }
   
   // Vérifier le spread maximum
   double spreadCheck = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(spreadCheck > MaxSpreadPoints * _Point)
   {
      Print("Spread too high: ", spreadCheck, " > ", MaxSpreadPoints * _Point);
      return false;
   }
   
   // Vérification stricte du nombre de positions (2 maximum)
   int posCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0 && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         posCount++;
         if(posCount >= 2 && !isSpikePriority) // Limite stricte à 2 positions
         {
            static datetime lastPosLimitAlert = 0;
            if(TimeCurrent() - lastPosLimitAlert > 300) // Alerte toutes les 5 minutes max
            {
               Print("❌ Limite stricte: 2 positions maximum. Position actuelle: ", posCount);
               lastPosLimitAlert = TimeCurrent();
            }
            return false;
         }
      }
   }
   
   // Vérifier si on peut trader après des pertes consécutives
   if(!isSpikePriority && !CanTradeAfterLosses())
   {
      return false;
   }
   
   // Vérifier la limite de positions (max 2)
   if(!isSpikePriority) // Ne pas appliquer cette limite pour les trades prioritaires (spikes)
   {
      int currentPosCount = CountOpenForexPositions();
      if(currentPosCount >= 2)
      {
         static datetime lastForexLimitAlert = 0;
         if(TimeCurrent() - lastForexLimitAlert > 300) // Alerte toutes les 5 minutes max
         {
            Print("❌ Limite stricte: 2 positions maximum. Position actuelle: ", currentPosCount);
            lastForexLimitAlert = TimeCurrent();
            
            // Tenter de fermer les positions excédentaires
            CloseExcessPositions();
         }
         return false;
      }
   }
   
   // ========== BLOCAGE DES ORDRES NON LOGIQUES SUR VOLATILITÉS ==========
   // Règle stricte: Boom = BUY Only, Crash = SELL Only
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   // Vérifier le type d'ordre
   bool isBuyOrder = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP);
   bool isSellOrder = (type == ORDER_TYPE_SELL || type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP);

   if(isBoom && isSellOrder)
   {
      Print("🛑 ORDRE BLOQUÉ - Sell sur Boom non autorisé (Boom est un symbole haussier)");
      return false;
   }
   
   if(isCrash && isBuyOrder)
   {
      Print("🛑 ORDRE BLOQUÉ - Buy sur Crash non autorisé (Crash est un symbole baissier)");
      return false;
   }
   // Détection Boom/Crash pour adapter les garde-fous (plus agressif)
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isBoom300Symbol   = (StringFind(_Symbol, "Boom 300") != -1);
   int totalPositions = CountAllPositionsForMagic();
   bool noOpenPositions = (totalPositions == 0);

   // Protection spéciale Boom 300 : si cooldown actif après pertes, ne plus ouvrir
   if(isBoom300Symbol && g_boom300CooldownUntil > 0 && TimeCurrent() < g_boom300CooldownUntil)
   {
      Print("⏸ ExecuteTrade: Boom 300 en cooldown jusqu'à ", TimeToString(g_boom300CooldownUntil, TIME_SECONDS));
      return false;
   }

   // ========== BLOCAGE ABSOLU #1: Anti-spam ==========
   //  - 60s pour tous les symboles classiques
   //  - 15s uniquement pour Boom/Crash (scalping plus fréquent)
   int antiSpamSec = isBoomCrashSymbol ? 15 : 60;
   if(TimeCurrent() - g_lastExecuteTime < antiSpamSec && !(isSpikePriority && noOpenPositions))
   {
      return false;
   }
   
   // ========== SI POSITION OPPOSÉE EXISTE: LA FERMER D'ABORD ==========

   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      ENUM_POSITION_TYPE existingType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Si une position existe déjà (même direction ou opposée), on ne fait rien
      // pour éviter les fermetures prématurées
      Print("ℹ️ Position ", EnumToString(existingType), " existe déjà sur ", _Symbol, " - Aucune action entreprise");
      return false;
   }
   
   // Anti-multi lancement
   datetime now = TimeCurrent();
   // 30s par défaut, 10s seulement pour Boom/Crash.
   // Si isSpikePriority et aucune position ouverte, on ignore ce cooldown.
   int attemptCooldown = isBoomCrashSymbol ? 10 : 30;
   if((now - g_lastTradeAttemptTime) < attemptCooldown && !(isSpikePriority && noOpenPositions))
   {
      return false;
   }
   g_lastTradeAttemptTime = now;

   // Marquer le temps d'exécution
   g_lastExecuteTime = TimeCurrent();

   // Vérification après fermeture - s'assurer qu'il n'y a plus de position
   int remaining = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         remaining++;
   }
   if(remaining > 0)
   {
      Print("⚠️ Position encore présente après tentative de fermeture");
      return false;
   }
   
   // Vérification finale : si une position existe déjà, on ne fait rien
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      // Si une position existe déjà (dans n'importe quelle direction), on ne fait rien
      Print("ℹ️ Une position est déjà ouverte sur ", _Symbol, " - Aucune nouvelle entrée ne sera effectuée");
      return false;
   }

   // Limite globale d'ordres en attente (tous symboles confondus) : 3 max
   if(CountAllPendingOrdersForMagic() >= 3)
   {
       Print("⚠️ Trop d'ordres en attente (>=3). Nouvelle exécution annulée.");
       return false;
   }

   double sl = 0, tp = 0;
   double lot = CalculateLot(atr);
   if(lot <= 0.0)
      return false;

   // --- BLOCAGE STEP INDEX : lot maximum 0.1 ---
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
   if(isStepIndex && lot > 0.1)
   {
      Print("⚠️ Signal bloqué pour Step Index : lot calculé (", DoubleToString(lot, 2), ") dépasse le maximum autorisé (0.1)");
      return false;
   }

   // Limiter à un maximum de symboles tradés simultanément
   if(MaxSimultaneousSymbols > 0)
   {
      string tradedSymbols[];
      int symCount = 0;
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         ulong tk = PositionGetTicket(i);
         if(tk == 0 || !PositionSelectByTicket(tk)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         string s = PositionGetString(POSITION_SYMBOL);
         bool found = false;
         for(int k=0; k<symCount; k++)
         {
            if(tradedSymbols[k] == s) { found = true; break; }
         }
         if(!found)
         {
            ArrayResize(tradedSymbols, symCount+1);
            tradedSymbols[symCount] = s;
            symCount++;
         }
      }
      // Si on atteint déjà la limite et que ce symbole n'en fait pas partie, on ne trade pas
      bool alreadyTraded = false;
      for(int k=0; k<symCount; k++)
      {
         if(tradedSymbols[k] == _Symbol) { alreadyTraded = true; break; }
      }
      if(symCount >= MaxSimultaneousSymbols && !alreadyTraded)
         return false;
   }
   
   // Appliquer le multiplicateur IA (guidage plutôt que blocage)
   if(lotMultiplier != 1.0 && lot > 0.0)
   {
      lot = lot * lotMultiplier;
      // S'assurer que le lot reste dans les limites
      double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      lot = MathMax(lot, minVol);
      lot = MathMin(lot, maxVol);
      lot = MathFloor(lot / stepVol) * stepVol;
      
      // Si le lot est toujours en dessous du minimum, on prend le minimum
      if(lot < minVol)
      {
         lot = minVol;
      }
   }
   long calcMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);
   bool isForex     = (calcMode == SYMBOL_CALC_MODE_FOREX);
   bool isVol       = (!isForex &&
                       (StringFind(_Symbol, "Volatility") != -1 ||
                        StringFind(_Symbol, "VOLATILITY") != -1 ||
                        StringFind(_Symbol, "volatility") != -1));
   bool isBoomCrash = (StringFind(_Symbol, "Boom")  != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isBoom300   = (StringFind(_Symbol, "Boom 300") != -1);
   
   // Calcul SL/TP
   if(isBoom300)
   {
      // Boom 300 : certains brokers refusent les SL/TP à l'ouverture -> on ouvre SANS SL/TP
      // La gestion du risque se fait ensuite via BoomCrashProfitCut et protections monétaires.
      sl = 0.0;
      tp = 0.0;
   }
   else if(isBoomCrash)
   {
      // Autres Boom/Crash : appliquer un SL/TP basé sur l'ATR avec ratio 20% SL / 80% TP
      double baseRange = (atr > 0.0) ? atr : 20 * _Point;
      double slDist    = baseRange * 0.2;  // 20% risque
      double tpDist    = baseRange * 0.8;  // 80% profit

      if(type == ORDER_TYPE_BUY)
      {
         sl = price - slDist;
         tp = price + tpDist;
      }
      else
      {
         sl = price + slDist;
         tp = price - tpDist;
      }
   }
   else if(isVol)
   {
      // Volatility Index (Deriv) : appliquer un SL/TP immédiat basé sur l'ATR avec ratio 20% SL / 80% TP
      double baseRange = (atr > 0.0) ? atr : 20 * _Point;
      double slDist    = baseRange * 0.2;  // 20% risque
      double tpDist    = baseRange * 0.8;  // 80% profit
      if(type == ORDER_TYPE_BUY)
      {
         sl = price - slDist;
         tp = price + tpDist;
      }
      else
      {
         sl = price + slDist;
         tp = price - tpDist;
      }
   }
   else if(isForex)
   {
      // Forex : respecter 20% de perte et 80% de gain
      double baseRange = atr;
      if(baseRange <= 0.0)
         baseRange = 20 * _Point; // fallback si ATR indisponible

      double slDist = baseRange * 0.2;  // 20% risque
      double tpDist = baseRange * 0.8;  // 80% profit

      if(type == ORDER_TYPE_BUY)
      {
         sl = price - slDist;
         tp = price + tpDist;
      }
      else
      {
         sl = price + slDist;
         tp = price - tpDist;
      }
   }
   else
   {
      // Mode scalping amélioré avec ATR et tendance
      double atrBuf[];
      double currentATR = 0;
      int atrHandleLocal = iATR(_Symbol, PERIOD_M5, 14);
      if(CopyBuffer(atrHandleLocal, 0, 0, 1, atrBuf) > 0)
         currentATR = atrBuf[0];
         
      // Ajuster les distances en fonction de la volatilité
      double slDist = currentATR * 1.5;  // Stop plus large pour laisser respirer
      double tpDist = currentATR * 2.5;  // Objectif plus ambitieux

      if(type == ORDER_TYPE_BUY)
      {
         sl = price - slDist;
         tp = price + tpDist;
      }
      else
      {
         sl = price + slDist;
         tp = price - tpDist;
      }
   }
   
  // Vérification / correction des distances minimales (StopsLevel + FreezeLevel) sauf Boom/Crash/Vol (sl/tp à 0)
  long stopLevel   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
  long minPoints   = stopLevel + freezeLevel + 2;
  double minDist   = minPoints * _Point;
  if(!isBoomCrash && !isVol)
  {
     // Corriger par rapport au prix d'entrée prévu (market ou pending)
     if(MathAbs(price - sl) < minDist)
        sl = (type==ORDER_TYPE_BUY) ? price - minDist : price + minDist;
     if(MathAbs(price - tp) < minDist)
        tp = (type==ORDER_TYPE_BUY) ? price + minDist : price - minDist;

     // Double sécurité : corriger aussi par rapport au prix de marché actuel
     double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     double refPrice = (type == ORDER_TYPE_BUY) ? curAsk : curBid;
     if(curBid > 0 && curAsk > 0)
     {
        if(MathAbs(refPrice - sl) < minDist)
           sl = (type==ORDER_TYPE_BUY) ? refPrice - minDist : refPrice + minDist;
        if(MathAbs(refPrice - tp) < minDist)
           tp = (type==ORDER_TYPE_BUY) ? refPrice + minDist : refPrice - minDist;
     }
  }

  // Vérifier le nombre total de positions ouvertes (maximum 3 autorisées)
  totalPositions = CountAllPositionsForMagic();
   bool placeAsLimit = false;

   // ---------------------------------------------------------
  // SÉCURITÉ : MAXIMUM 3 POSITIONS PAR SYMBOLE (PAR LE ROBOT)
  // Si 3 positions avec ce magic number existent déjà sur _Symbol,
   // on BLOQUE toute nouvelle ouverture pour ce symbole.
   // ---------------------------------------------------------
   int symbolPositions = CountPositionsForSymbolMagic();
  if(symbolPositions >= 3)
   {
     Print("🛑 Blocage ouverture: maximum de 3 positions atteint sur ", _Symbol,
            " (", symbolPositions, " position(s) pour ce symbole).");
      return false;
   }
   
   // Définir les prix actuels
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentPrice = (bid + ask) / 2.0;
   
   // Calculer le stop loss et take profit
   double currentATR = atr; // Utiliser la valeur ATR passée en paramètre
   
   // Calculer SL et TP en fonction du type d'ordre
   if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP)
   {
      sl = NormalizeDouble(bid - (currentATR * SL_ATR_Mult), _Digits);
      tp = NormalizeDouble(ask + (currentATR * TP_ATR_Mult), _Digits);
   }
   else // Ordres de vente
   {
      sl = NormalizeDouble(ask + (currentATR * SL_ATR_Mult), _Digits);
      tp = NormalizeDouble(bid - (currentATR * TP_ATR_Mult), _Digits);
   }
   
   // Vérifier la validité du stop loss avant d'ouvrir la position
   if(!IsValidStopLoss(_Symbol, currentPrice, sl, type == ORDER_TYPE_BUY))
   {
      Print("Annulation de l'ouverture: Stop Loss invalide");
      return false;
   }
   
   // Vérifier le spread actuel
   double spreadPoints = (ask - bid) / _Point;
   if(spreadPoints > MaxSpreadPoints)
   {
      Print("Spread trop élevé: ", DoubleToString(spreadPoints, 1), " points (max: ", MaxSpreadPoints, ")");
      return false;
   }

  if(totalPositions >= 3)
   {
     Print("⚠️ Maximum de 3 positions ouvertes atteint (", totalPositions, "). Placement en ordre limit...");
      placeAsLimit = true; // Placer en limit au lieu d'exécuter au marché
   }
   
   // Vérifier le nombre d'ordres en attente pour ce symbole
   int pendingOrders = CountPendingOrdersForSymbol();
   
   // Si on a déjà atteint le maximum d'ordres limit, ne pas créer de nouvel ordre
   if(pendingOrders >= MaxLimitOrdersPerSymbol)
   {
      Print("Maximum d'ordres limit atteint (", MaxLimitOrdersPerSymbol, "). Gestion des ordres existants...");
      // Gérer les ordres existants (exécuter le plus proche si scalping activé)
      ManagePendingOrders();
      return false; // Ne pas créer de nouvel ordre
   }
   
   // Vérifier les niveaux de prix et de stop
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   // Utiliser les variables bid et ask déjà définies plus haut
   
   // Si on doit placer en limit, calculer le prix du limit
   if(placeAsLimit)
   {
      // Calculer la distance du limit en fonction de l'ATR
      double atrPoints = atr * BackupLimitAtrMult;
      double minPoints = BackupLimitMinPoints * _Point;
      double distPending = MathMax(atrPoints, minPoints);
      
      if(type == ORDER_TYPE_BUY)
      {
         currentPrice = NormalizeDouble(bid - distPending, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      }
      else
      {
         currentPrice = NormalizeDouble(ask + distPending, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      }
   }
   else
   {
      // Ajuster le prix d'ordre pour le marché
      if(type == ORDER_TYPE_BUY) currentPrice = ask;
      else if(type == ORDER_TYPE_SELL) currentPrice = bid;
   }
   
   // VALIDATION FINALE : Vérifier et ajuster les SL/TP selon les distances minimales du broker
   // Convertir ORDER_TYPE en ORDER_TYPE pour les limit si nécessaire
   ENUM_ORDER_TYPE orderTypeForValidation = type;
   if(placeAsLimit)
   {
      orderTypeForValidation = (type == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   }
   
   // Valider et ajuster les stops AVANT d'envoyer l'ordre
   if(!ValidateAndAdjustStops(_Symbol, orderTypeForValidation, price, sl, tp))
   {
      Print("⚠️ Erreur de validation des stops pour ordre limit spike sur ", _Symbol);
      return false;
   }
   
   // Si on doit placer en limit (2 positions déjà ouvertes)
   if(placeAsLimit)
   {
      ENUM_ORDER_TYPE_TIME otime = ORDER_TIME_GTC;
      datetime exp = 0;
      if(BackupLimitExpirySec > 0)
      {
         otime = ORDER_TIME_SPECIFIED;
         exp = TimeCurrent() + BackupLimitExpirySec;
      }
      
      if(type == ORDER_TYPE_BUY)
      {
         if(trade.BuyLimit(lot, price, _Symbol, sl, tp, otime, exp, comment + "_LIMIT"))
         {
            Print("✅ Ordre limit BUY placé à ", DoubleToString(price, _Digits), " (2 positions déjà ouvertes)");
            return true;
         }
      }
      else
      {
         if(trade.SellLimit(lot, price, _Symbol, sl, tp, otime, exp, comment + "_LIMIT"))
         {
            Print("✅ Ordre limit SELL placé à ", DoubleToString(price, _Digits), " (2 positions déjà ouvertes)");
            return true;
         }
      }
      return false;
   }
   
   // VALIDATION FINALE pour ordres au marché : Vérifier et ajuster les SL/TP selon les distances minimales
   if(!ValidateAndAdjustStops(_Symbol, type, price, sl, tp))
   {
      Print("⚠️ Erreur de validation des stops pour ordre au marché sur ", _Symbol);
      return false;
   }
   
   // Tentative d'ouverture au marché (moins de 2 positions ouvertes)
   bool res = false;
   if(type == ORDER_TYPE_BUY) res = trade.Buy(lot, _Symbol, price, sl, tp, comment);
   else                       res = trade.Sell(lot, _Symbol, price, sl, tp, comment);

   // Si succès, enregistrer le temps pour anti-spam
   if(res)
   {
      g_lastExecuteTime = TimeCurrent();
      Print("✅ Trade ouvert - Prochain trade possible dans 60s");
   }

   // AUDIT: Retry logic pour erreurs de Requote ou Connection
   if(!res)
   {
      uint errMain = (uint)trade.ResultRetcode();
      string errDesc = trade.ResultRetcodeDescription();
      Print("❌ Trade échoué. Code: ", errMain, " Desc: ", errDesc);
      
      // Retry si Requote (10004) ou No Connection (10006) ou Invalid Price (10015)
      if(errMain == 10004 || errMain == 10006 || errMain == 10015)
      {
         Sleep(100);
         // Rafraîchir les prix
         if(type == ORDER_TYPE_BUY) price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         else price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         Print("🔄 Retry trade avec nouveau prix: ", price);
         if(type == ORDER_TYPE_BUY) res = trade.Buy(lot, _Symbol, price, sl, tp, comment + "_R");
         else res = trade.Sell(lot, _Symbol, price, sl, tp, comment + "_R");
         
         if(res) Print("✅ Retry réussi!");
      }
      else if(errMain == 10016 /* TRADE_RETCODE_INVALID_STOPS */)
      {
         Print("❌ Echec: stops invalides, aucun ordre sans SL/TP envoyé.");
      }
   }
   
   // Si échec à cause du prix (ex: mouvement rapide), on place un Pending (optionnel)
   // Vérifier qu'on n'a pas déjà atteint le maximum d'ordres limit
   if(!res && UseBackupLimit && CountPendingOrdersForSymbol() < MaxLimitOrdersPerSymbol)
   {
      uint err = (uint)trade.ResultRetcode();
      if(err == 10004 || err == 10015 || err == 10016 || err == 10014) // Requote, prix invalide, ou stops invalides
      {
         // Calculer la distance du pending en fonction de l'ATR et des points minimums
         double atrPoints = atr * BackupLimitAtrMult;
         double minPoints = BackupLimitMinPoints * _Point;
         double distPending = MathMax(atrPoints, minPoints);
         
         // Obtenir le pas de prix minimum
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         // Calculer le prix du pending en fonction du type d'ordre
         double pPrice;
         if(type == ORDER_TYPE_BUY)
         {
            pPrice = NormalizeDouble(price - distPending, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
            // Vérifier que le prix n'est pas trop bas
            double minPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) - SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
            pPrice = MathMax(pPrice, minPrice);
         }
         else
         {
            pPrice = NormalizeDouble(price + distPending, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
            // Vérifier que le prix n'est pas trop haut
            double maxPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
            pPrice = MathMin(pPrice, maxPrice);
         }
         
         // S'assurer que le prix est un multiple du tick size
         pPrice = NormalizeDouble(MathFloor(pPrice / tickSize) * tickSize, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
         
         // Recalcul SL/TP pour le pending (en réutilisant la même logique de distance minimale)
         if(isForex)
         {
            double cashTP    = 1.0;
            double cashSL    = 2.0;
            double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

            double tpDelta = 0, slDelta = 0;
            if(tickSize > 0 && tickValue > 0 && lot > 0)
            {
               tpDelta = (cashTP / (tickValue * lot)) * tickSize;
               slDelta = (cashSL / (tickValue * lot)) * tickSize;
            }
            if(type == ORDER_TYPE_BUY) { sl = pPrice - slDelta; tp = pPrice + tpDelta; }
            else                       { sl = pPrice + slDelta; tp = pPrice - tpDelta; }
         }
         else if(isVol)
         {
            // Volatility Index : SL/TP basés sur l'ATR avec ratio 20% SL / 80% TP
            double baseRange = (atr > 0.0) ? atr : 20 * _Point;
            double slDist    = baseRange * 0.2;  // 20% risque
            double tpDist    = baseRange * 0.8;  // 80% profit
            if(type == ORDER_TYPE_BUY) { sl = pPrice - slDist; tp = pPrice + tpDist; }
            else                       { sl = pPrice + slDist; tp = pPrice - tpDist; }
         }
         else
         {
            // Ratio 20% SL / 80% TP pour tous les autres instruments
            double baseRange = (atr > 0.0) ? atr : 20 * _Point;
            double slDist = baseRange * 0.2;  // 20% risque
            double tpDist = baseRange * 0.8;  // 80% profit
            if(type == ORDER_TYPE_BUY) { sl = pPrice - slDist; tp = pPrice + tpDist; }
            else                       { sl = pPrice + slDist; tp = pPrice - tpDist; }
         }

         // Appliquer aussi la distance minimale pour le pending
         long pendingStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         long freezeLevelP = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
         long minPointsP = pendingStopLevel + freezeLevelP + 2;
         double minDistP = minPointsP * _Point;
         
         // Vérifier et ajuster le volume pour respecter les limites du broker
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         
         lot = MathMax(lot, minLot);
         lot = MathMin(lot, maxLot);
         lot = MathFloor(lot / lotStep) * lotStep;
         
         // Si le lot est toujours en dessous du minimum, on prend le minimum
         if(lot < minLot) lot = minLot;
         
         // VALIDATION FINALE pour ordres limit de secours : Vérifier et ajuster les SL/TP
         ENUM_ORDER_TYPE limitType = (type == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
         if(!ValidateAndAdjustStops(_Symbol, limitType, pPrice, sl, tp))
         {
            Print("⚠️ Erreur de validation des stops pour ordre limit de secours sur ", _Symbol);
            return res; // Retourner le résultat de l'ordre au marché même si le backup échoue
         }

         ENUM_ORDER_TYPE_TIME otime = ORDER_TIME_GTC;
         datetime exp = 0;
         if(BackupLimitExpirySec > 0)
         {
            otime = ORDER_TIME_SPECIFIED;
            exp = TimeCurrent() + BackupLimitExpirySec;
         }

         if(type == ORDER_TYPE_BUY) trade.BuyLimit(lot, pPrice, _Symbol, sl, tp, otime, exp, comment+"_L");
         else trade.SellLimit(lot, pPrice, _Symbol, sl, tp, otime, exp, comment+"_L");
      }
   }
   
   return res;
}

//+------------------------------------------------------------------+
//| Analyse et envoi du signal IA (appelé toutes les 5 minutes)     |
//+------------------------------------------------------------------+
void CheckAndSendAISignal()
{
   if(!AI_UseNotifications) return;
   
   // Récupérer les données des indicateurs
   double rsi[], atr[], emaFast[], emaSlow[], emaFastEntry[], emaSlowEntry[];
   
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsi) <= 0) return;
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0) return;
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) <= 0) return;
   if(CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) <= 0) return;
   if(CopyBuffer(emaFastEntryHandle, 0, 0, 1, emaFastEntry) <= 0) return;
   if(CopyBuffer(emaSlowEntryHandle, 0, 0, 1, emaSlowEntry) <= 0) return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Analyse de tendance
   bool trendUp = emaFast[0] > emaSlow[0];
   bool trendDown = emaFast[0] < emaSlow[0];
   
   // Calcul des niveaux de stop loss et take profit
   double sl = 0, tp = 0;
   double atrValue = atr[0];

   // Déterminer le signal
   string signal = "NEUTRE";
   string timeframe = "M1";
   string comment = "";
   
   // bid et ask sont déjà déclarés plus haut dans la fonction
   if(trendUp && rsi[0] > 50 && rsi[0] < 70)
   {
      signal = "ACHAT";
      sl = bid - (atrValue * SL_ATR_Mult);
      tp = ask + (atrValue * TP_ATR_Mult);
      comment = StringFormat("Tendance haussière, RSI: %.1f", rsi[0]);
   }
   else if(trendDown && rsi[0] < 50 && rsi[0] > 30)
   {
      signal = "VENTE";
      sl = ask + (atrValue * SL_ATR_Mult);
      tp = bid - (atrValue * TP_ATR_Mult);
      comment = StringFormat("Tendance baissière, RSI: %.1f", rsi[0]);
   }
   
   // Vérifier si on a un signal valide
   if(signal != "NEUTRE")
   {
      // Envoyer la notification
      double price = (signal == "ACHAT") ? ask : bid;
      int direction = (signal == "ACHAT") ? 1 : -1;
      SendTradingSignalNotification(_Symbol, direction, price, sl, tp);
      PrintFormat("Signal %s envoyé - Prix: %.5f, SL: %.5f, TP: %.5f", signal, price, sl, tp);
      
      // Afficher le signal sur le graphique
      string objName = "SIGNAL_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      datetime time = TimeCurrent();
      
      // Créer l'objet avec la signature correcte pour MQL5
      if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
      {
         // Configurer les propriétés de l'objet
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, (signal == "ACHAT") ? 233 : 234);
         ObjectSetString(0, objName, OBJPROP_TOOLTIP, signal + " " + comment);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, (signal == "ACHAT") ? clrLime : clrRed);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         
         // Journaliser le signal
         PrintFormat("Signal %s à %.5f - %s", signal, price, comment);
      }
      else
      {
         Print("Erreur lors de la création de l'objet: ", GetLastError());
      }
      
      // Supprimer les anciens signaux (garder les 5 derniers)
      CleanOldSignals();
   }
}

//+------------------------------------------------------------------+
//| Envoie une notification de signal de trading                     |
//+------------------------------------------------------------------+
void SendTradingSignalNotification(const string symbol, int direction, double entryPrice, double sl, double tp)
{
   string directionText = (direction > 0) ? "ACHAT" : "VENTE";
   string signalText = StringFormat("🚨 SIGNAL %s - %s\nPrix: %s\nSL: %s\nTP: %s",
                                 directionText, symbol,
                                 DoubleToString(entryPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                                 DoubleToString(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                                 DoubleToString(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
   
   // Envoyer la notification
   if(SendNotifications)
   {
      SendNotification(signalText);
   }
   
   // Journaliser le signal
   Print(signalText);
}

//+------------------------------------------------------------------+
//| Nettoyage des anciens signaux graphiques                         |
//+------------------------------------------------------------------+
void CleanOldSignals()
{
   string prefix = "SIGNAL_";
   int total = ObjectsTotal(0, 0, -1);
   string names[];
   ArrayResize(names, total);
   
   // Récupérer tous les noms d'objets
   for(int i = 0; i < total; i++)
      names[i] = ObjectName(0, i);
   
   // Trier par date (du plus ancien au plus récent)
   ArraySort(names);
   
   // Supprimer les anciens signaux (en gardant les 5 plus récents)
   int count = 0;
   for(int i = 0; i < total; i++)
   {
      if(StringFind(names[i], prefix) == 0) // Si le nom commence par "SIGNAL_"
      {
         count++;
         if(count > 5) // Garder uniquement les 5 signaux les plus récents
            ObjectDelete(0, names[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| SÉCURITÉ GLOBALE : Couper les gains si objectif atteint          |
//+------------------------------------------------------------------+
void ManageGlobalProfitSecurity()
{
   if(!InpUseGlobalProfitLock) return;
   
   double netProfit = 0.0;
   int totalPos = 0;
   
   // 1. Calculer le profit net global (tous symboles confondus si Magic match)
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      // Filtre uniquement sur le MagicNumber pour ne toucher qu'aux trades du robot
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         double swap   = PositionGetDouble(POSITION_SWAP);
         netProfit += (profit + swap);
         totalPos++;
      }
   }
   
   // 2. Si cible atteinte (exemple 2.5$)
   if(totalPos > 0 && netProfit >= InpGlobalProfitTarget)
   {
      Print("💰 OBJECTIF GLOBAL ATTEINT: Net Profit = ", DoubleToString(netProfit, 2), " USD. Sécurisation des gains...");
      
      // 3. Couper UNIQUEMENT les gagnants
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            // On ferme si c'est un gain
            if(profit > 0)
            {
               if(trade.PositionClose(ticket))
                  Print("✅ Gain sécurisé: ", ticket, " (", DoubleToString(profit, 2), ")");
               else
                  Print("❌ Erreur fermeture gain: ", ticket, " err=", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gère la taille dynamique des positions                           |
//+------------------------------------------------------------------+
void ManageDynamicPositionSizing()
{
   if(!UseDynamicPositionSizing2) return;
   
   datetime now = TimeCurrent();
   if(now - g_lastTrendCheck < AdjustmentIntervalSeconds) return;
   
   g_lastTrendCheck = now;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double lotSize = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Initialiser l'état de la position si nécessaire
      if(ArraySize(g_dynamicPosStates) <= i)
      {
         ArrayResize(g_dynamicPosStates, i + 1);
         g_dynamicPosStates[i].initialLot = lotSize;
         g_dynamicPosStates[i].currentLot = lotSize;
         g_dynamicPosStates[i].highestProfit = 0;
         g_dynamicPosStates[i].trendConfirmed = false;
         g_dynamicPosStates[i].lastAdjustmentTime = 0;
         g_dynamicPosStates[i].highestPrice = (posType == POSITION_TYPE_BUY) ? currentPrice : 0;
         g_dynamicPosStates[i].lowestPrice = (posType == POSITION_TYPE_SELL) ? currentPrice : 999999;
         g_dynamicPosStates[i].slModifyCount = 0; // Initialiser le compteur de modifications SL
      }
      
      // Mettre à jour les prix extrêmes
      if(posType == POSITION_TYPE_BUY)
      {
         g_dynamicPosStates[i].highestPrice = MathMax(g_dynamicPosStates[i].highestPrice, currentPrice);
         g_dynamicPosStates[i].lowestPrice = MathMin(g_dynamicPosStates[i].lowestPrice, currentPrice);
      }
      else
      {
         g_dynamicPosStates[i].lowestPrice = MathMin(g_dynamicPosStates[i].lowestPrice, currentPrice);
         g_dynamicPosStates[i].highestPrice = MathMax(g_dynamicPosStates[i].highestPrice, currentPrice);
      }
      
      // Vérifier la tendance
      bool isUptrend = (posType == POSITION_TYPE_BUY && currentPrice > openPrice) || 
                      (posType == POSITION_TYPE_SELL && currentPrice < openPrice);
      
      // Calculer le mouvement depuis l'ouverture
      double priceMove = (posType == POSITION_TYPE_BUY) ? 
                        (currentPrice - openPrice) / _Point : 
                        (openPrice - currentPrice) / _Point;
      
      // Si le profit est positif et la tendance est favorable
      if(currentProfit > g_dynamicPosStates[i].highestProfit && isUptrend)
      {
         g_dynamicPosStates[i].highestProfit = currentProfit;
         
         // --- STRATÉGIE DE DOUBLAGE (FOREX UNIQUEMENT) ---
         // Filtre strict pour ne pas appliquer sur Indices/Synthetics (Boom, Crash, Vol, Step)
         bool isForex = (StringFind(symbol, "Boom") == -1 && 
                         StringFind(symbol, "Crash") == -1 && 
                         StringFind(symbol, "Vol") == -1 && 
                         StringFind(symbol, "Step") == -1);
         
         double maxAllowedLot = g_dynamicPosStates[i].initialLot * 4.0;
         
         // Condition: Forex + Profit significatif (bat le record) + Pas au max
         if(isForex && lotSize < maxAllowedLot)
         {
             // On double le lot si on a "bien" progressé
             // Note: Pour éviter le spam, on pourrait ajouter un seuil minimal de profit absolu
             // ici on le fait dès qu'on bat le record de profit, ce qui est agressif mais demandé.
             
             double newLot = lotSize * 2.0;
             newLot = NormalizeLotSize(symbol, newLot);
             
             // Sécurité: ne pas dépasser le max
             if(newLot > maxAllowedLot) newLot = maxAllowedLot;
             
             if(ModifyPositionSize(ticket, newLot, symbol))
             {
                 g_dynamicPosStates[i].currentLot = newLot;
                 g_dynamicPosStates[i].trendConfirmed = true; 
                 Print("🚀 Forex Winning Streak: Position ", ticket, " DOUBLÉE à ", newLot, " lots (Profit record: ", currentProfit, ")");
             }
         }
      }
      // Si la tendance s'inverse ou que le profit commence à baisser
      else if((!isUptrend || currentProfit < g_dynamicPosStates[i].highestProfit * 0.7) && 
              g_dynamicPosStates[i].trendConfirmed)
      {
         // Revenir progressivement au lot initial
         if(lotSize > g_dynamicPosStates[i].initialLot * 1.1)
         {
            double newLot = MathMax(lotSize * 0.8, g_dynamicPosStates[i].initialLot);
            newLot = NormalizeLotSize(symbol, newLot);
            
            if(ModifyPositionSize(ticket, newLot, symbol))
            {
               g_dynamicPosStates[i].currentLot = newLot;
               g_dynamicPosStates[i].lastAdjustmentTime = now;
               Print("Position ", ticket, " réduite à ", newLot, " lots (Changement de tendance)");
               
               if(MathAbs(newLot - g_dynamicPosStates[i].initialLot) < 0.01)
               {
                  g_dynamicPosStates[i].trendConfirmed = false;
                  g_dynamicPosStates[i].highestProfit = 0;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modifie la taille d'une position existante                       |
//+------------------------------------------------------------------+
bool ModifyPositionSize(ulong ticket, double newLot, string symbol)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   double currentLot = PositionGetDouble(POSITION_VOLUME);
   if(MathAbs(currentLot - newLot) < 0.01) return true; // Aucun changement nécessaire
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   
   // Fermer la position existante en utilisant l'objet global trade
   if(!trade.PositionClose(ticket))
   {
      Print("Erreur fermeture position: ", GetLastError());
      return false;
   }
   
   // Rouvrir avec le nouveau lot
   double price = (posType == POSITION_TYPE_BUY) ? 
                 SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                 SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Récupérer le commentaire original pour le conserver
   string comment = PositionGetString(POSITION_COMMENT);
   
   // Convertir le type de position en type d'ordre
   ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   if(!trade.PositionOpen(symbol, orderType, newLot, price, sl, tp, comment))
   {
      Print("Erreur réouverture position: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Normalise la taille du lot selon les règles du broker            |
//+------------------------------------------------------------------+
double NormalizeLotSize(string symbol, double lot)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(lot, maxLot));
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| CLÔTURE IMMÉDIATE DÈS QU'UN PROFIT EST DÉTECTÉ                   |
//| Ferme toute position en profit (même 0.01$) pour sécuriser gains |
//+------------------------------------------------------------------+
void ClosePositionsInProfit()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double totalProfit = profit + swap;
      
      // Si le profit total est positif (même 0.01$), on ferme immédiatement
      if(totalProfit > 0.0)
      {
         double lot = PositionGetDouble(POSITION_VOLUME);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         Print("💰 PROFIT DÉTECTÉ: ", DoubleToString(totalProfit, 2), "$ - Fermeture immédiate!");
         
         if(posType == POSITION_TYPE_BUY)
         {
            if(trade.Sell(lot, _Symbol, 0, 0, 0, "PROFIT_SECURE"))
               Print("✅ Position BUY fermée avec profit: ", DoubleToString(totalProfit, 2), "$");
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if(trade.Buy(lot, _Symbol, 0, 0, 0, "PROFIT_SECURE"))
               Print("✅ Position SELL fermée avec profit: ", DoubleToString(totalProfit, 2), "$");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Détecte un spike à partir des zones SMC/OB                       |
//+------------------------------------------------------------------+
bool PredictSpikeFromSMCOB(double &spikePrice, bool &isBuySpike, double &confidence)
{
   if(!SMC_OB_UseForSpikes) return false;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Récupérer les données ATR pour la volatilité
   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0) return false;
   
   // Seuil de volatilité minimum pour déclencher un spike
   double minAtrForSpike = 0.0; // Ajustez selon votre symbole
   if(atr[0] < minAtrForSpike) return false;
   
   // Vérifier les conditions de spike
   bool spikeDetected = false;
   double spikeConfidence = 0.0;
   
   // 1. Vérifier les zones SMC/OB
   if(SMC_OB_CheckZones(currentPrice, isBuySpike, spikeConfidence))
   {
      spikePrice = isBuySpike ? ask : bid;
      confidence = spikeConfidence;
      return true;
   }
   
   // 2. Vérifier les mouvements de prix brusques
   double priceChange = (currentPrice - iClose(_Symbol, PERIOD_M1, 1)) / _Point;
   if(MathAbs(priceChange) > 50) // 50 points en 1 minute
   {
      isBuySpike = (priceChange > 0);
      spikePrice = isBuySpike ? ask : bid;
      confidence = 0.7; // 70% de confiance
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Exécute un trade de spike                                        |
//+------------------------------------------------------------------+
bool ExecuteSpikeTrade(bool isBuy, double entryPrice, double confidence)
{
   // ========== VALIDATIONS STRICTES POUR ÉVITER LES OUVERTURES AUTOMATIQUES ==========
   // Ne pas ouvrir de positions sur les symboles de volatilité sans confirmation manuelle
   string symbol = _Symbol;
   bool isVolatilitySymbol = (StringFind(symbol, "Boom") != -1 || StringFind(symbol, "Crash") != -1 || 
                              StringFind(symbol, "Volatility") != -1 || StringFind(symbol, "RNG") != -1);
   
   // ========== BLOCAGE DES ORDRES NON LOGIQUES SUR VOLATILITÉS ==========
   // Bloquer les ordres Sell sur Boom (Boom monte, donc on achète)
   // Bloquer les ordres Buy sur Crash (Crash descend, donc on vend)
   if(StringFind(symbol, "Boom") != -1 && !isBuy)
   {
      Print("ORDRE BLOQUÉ - Sell sur Boom non autorisé (Boom est un symbole haussier)");
      return false;
   }
   
   if(StringFind(symbol, "Crash") != -1 && isBuy)
   {
      Print("ORDRE BLOQUÉ - Buy sur Crash non autorisé (Crash est un symbole baissier)");
      return false;
   }
   
   // Pour les symboles de volatilité, exiger une confiance très élevée et confirmation manuelle
   if(isVolatilitySymbol && confidence < 0.85)
   {
      Print("Symbole de volatilité détecté - Confiance insuffisante: ", confidence, " (minimum 0.85 requis)");
      return false;
   }
   
   // Vérifier les conditions de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) || IsDrawdownExceeded())
   {
      Print("Conditions de trading non remplies");
      return false;
   }
   
   // Vérifier si on a déjà une position ouverte
   if(CountPositionsForSymbolMagic() > 0)
   {
      Print("Position déjà ouverte");
      return false;
   }
   
   // Vérification supplémentaire pour les volatilités : pas plus d'un trade par heure
   if(isVolatilitySymbol)
   {
      datetime currentTime = TimeCurrent();
      if(currentTime - g_lastSpikeTradeTime < 3600) // 1 heure = 3600 secondes
      {
         Print("Symbole de volatilité - Délai minimum d'une heure non respecté");
         return false;
      }
   }
   
   // Calculer la taille de la position
   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0)
   {
      Print("Erreur lors de la récupération de l'ATR pour le calcul du lot");
      return false;
   }
   
   double lotSize = CalculateLot(atr[0]);
   if(lotSize <= 0)
   {
      Print("Taille de lot invalide");
      return false;
   }
   
   // Calculer les niveaux de stop loss et take profit
   double stopLoss = 0, takeProfit = 0;
   if(isBuy)
   {
      stopLoss = NormalizeDouble(entryPrice - (atr[0] * 1.5), _Digits);
      takeProfit = NormalizeDouble(entryPrice + (atr[0] * 3.0), _Digits);
   }
   else
   {
      stopLoss = NormalizeDouble(entryPrice + (atr[0] * 1.5), _Digits);
      takeProfit = NormalizeDouble(entryPrice - (atr[0] * 3.0), _Digits);
   }
   
   // Exécuter le trade
   CTrade spikeTrade;
   spikeTrade.SetExpertMagicNumber(InpMagicNumber);
   spikeTrade.SetMarginMode();
   spikeTrade.SetTypeFilling(ORDER_FILLING_FOK);
   
   if(spikeTrade.PositionOpen(_Symbol, isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, 
      lotSize, 
      isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID),
      stopLoss, 
      takeProfit, 
      "Spike Trade - " + (isBuy ? "BUY" : "SELL")))
   {
      Print("Trade de spike exécuté avec succès - ", 
            (isBuy ? "BUY" : "SELL"), 
            " Lot: ", lotSize,
            " SL: ", stopLoss,
            " TP: ", takeProfit);
            
      // Mettre à jour les variables de suivi
      g_lastSpikeTradeTime = TimeCurrent();
      g_lastSpikeDirection = isBuy ? 1 : -1;
      g_spikeFailCount = 0;
      
      return true;
   }
   else
   {
      Print("Échec de l'exécution du trade - Erreur: ", GetLastError());
      g_spikeFailCount++;
      
      // Activer le cooldown après plusieurs échecs
      if(g_spikeFailCount >= 3)
      {
         g_spikeCooldownUntil = TimeCurrent() + 300; // 5 minutes de cooldown
         Print("Trop d'échecs - Activation du cooldown jusqu'à ", 
               TimeToString(g_spikeCooldownUntil, TIME_MINUTES));
      }
      
      return false;
   }
}

//+------------------------------------------------------------------+
//| Vérifie les conditions de marché                                 |
//+------------------------------------------------------------------+
bool IsMarketConditionGoodForTrading()
{
   // Vérifier l'heure de trading
   if(!IsTradingTimeAllowed())
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 60) // Log toutes les minutes
      {
         lastLog = TimeCurrent();
         Print("Hors des heures de trading");
      }
      return false;
   }
   
   // Vérifier le spread
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints)
   {
      Print("Spread trop élevé: ", spread, " > ", MaxSpreadPoints);
      return false;
   }
   
   // Vérifier la volatilité
   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0)
   {
      if(atr[0] < MinATRForTrading)
      {
         Print("Volatilité trop faible - ATR: ", atr[0], " < ", MinATRForTrading);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Met à jour l'interface utilisateur pour les spikes               |
//+------------------------------------------------------------------+
void UpdateSpikeUI(bool isBuy, double price, double confidence)
{
   string objName = "SpikeAlert_" + IntegerToString(TimeCurrent());
   string text = (isBuy ? "ACHAT" : "VENTE") + " SPIKE DÉTECTÉ\n" +
                 "Prix: " + DoubleToString(price, _Digits) + "\n" +
                 "Confiance: " + DoubleToString(confidence * 100, 1) + "%";
   
   int x = 20;
   int y = 20;
   color clr = isBuy ? clrLime : clrRed;
   
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, (long)CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, (long)x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, (long)y);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, (long)10);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, objName, OBJPROP_BACK, (long)false);
   }
   
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   
   // Supprimer l'objet après 30 secondes
   EventSetTimer(30);
}

//+------------------------------------------------------------------+
//| Vérifie les signaux de spike                                     |
//+------------------------------------------------------------------+
void CheckSpikeSignals()
{
   // Vérifier si on est en cooldown
   if(TimeCurrent() < g_spikeCooldownUntil)
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 10) // Log toutes les 10 secondes
      {
         lastLog = TimeCurrent();
         Print("En cooldown jusqu'à ", TimeToString(g_spikeCooldownUntil, TIME_MINUTES));
      }
      return;
   }
   
   // Vérifier les conditions de marché
   if(!IsMarketConditionGoodForTrading())
   {
      return;
   }
   
   // Détecter les signaux de spike
   double spikePrice = 0.0;
   bool isBuySpike = false;
   double confidence = 0.0;
   
   if(PredictSpikeFromSMCOB(spikePrice, isBuySpike, confidence))
   {
      // ========== BLOCAGE DES ORDRES NON LOGIQUES SUR VOLATILITÉS ==========
      // Bloquer les ordres Sell sur Boom et Buy sur Crash avant même l'exécution
      string symbol = _Symbol;
      if(StringFind(symbol, "Boom") != -1 && !isBuySpike)
      {
         Print("SIGNAL BLOQUÉ - Sell sur Boom non autorisé (Boom est un symbole haussier)");
         return;
      }
      
      if(StringFind(symbol, "Crash") != -1 && isBuySpike)
      {
         Print("SIGNAL BLOQUÉ - Buy sur Crash non autorisé (Crash est un symbole baissier)");
         return;
      }
      
      // Vérifier la confiance minimale
      if(confidence < AI_MinConfidence)
      {
         Print("Confiance trop faible: ", confidence, " < ", AI_MinConfidence);
         return;
      }
      
      // Exécuter le trade
      if(ExecuteSpikeTrade(isBuySpike, spikePrice, confidence))
      {
         // Succès - Mettre à jour l'interface
         UpdateSpikeUI(isBuySpike, spikePrice, confidence);
      }
   }
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes (version améliorée pour spikes)        |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   // ========== DÉSACTIVATION COMPLÈTE DES FERMETURES AUTOMATIQUES ==========
   // Les positions ne doivent être fermées que par SL/TP atteints
   // Aucune fermeture automatique basée sur le profit ou autres conditions
   
   // Parcourir les positions pour monitoring uniquement (pas de fermeture automatique)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         // Monitoring uniquement - afficher l'état de la position
         Print("Position ", ticket, " en cours - Profit: $", DoubleToString(profit, 2), 
               " | Prix: ", DoubleToString(currentPrice, _Digits),
               " | SL/TP gèrent la fermeture automatiquement");
         
         // AUCUNE FERMETURE AUTOMATIQUE - laisser le SL/TP gérer
      }
   }
}

//+------------------------------------------------------------------+
//| Gestion des Positions (Trailing + BE)                            |
//+------------------------------------------------------------------+
void ManageTrade()
{
   // ========== DÉSACTIVATION COMPLÈTE DES MODIFICATIONS AUTOMATIQUES ==========
   // Le robot ne doit PAS modifier les SL/TP automatiquement
   // Les positions évoluent selon leurs paramètres initiaux jusqu'à atteindre SL/TP
   
   // Monitoring uniquement des positions existantes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string psym = PositionGetString(POSITION_SYMBOL);
      if(psym != _Symbol) continue;
      
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      double profit    = PositionGetDouble(POSITION_PROFIT);
      
      // Afficher l'état de la position pour monitoring
      Print("Position ", ticket, " monitoring - SL: ", DoubleToString(curSL, _Digits), 
            " | TP: ", DoubleToString(curTP, _Digits), 
            " | Profit: $", DoubleToString(profit, 2));
      
      // AUCUNE MODIFICATION AUTOMATIQUE - laisser les SL/TP initiaux gérer
   }
}

// Minimum de lot imposé par type d'instrument (Forex / Volatility / Boom/Crash)
double GetMinLotFloorBySymbol(string sym)
{
   long calcMode = SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE);
   bool isForex  = (calcMode == SYMBOL_CALC_MODE_FOREX);
   bool isVol    = (StringFind(sym, "Volatility")  != -1 ||
                    StringFind(sym, "VOLATILITY")  != -1 ||
                    StringFind(sym, "volatility")  != -1);
   bool isBoom   = (StringFind(sym, "Boom")  != -1);
   bool isCrash  = (StringFind(sym, "Crash") != -1);

   double floorLot = 0.0;
   if(isVol)
      floorLot = 0.01;   // Volatility Index
   else if(isBoom || isCrash)
      floorLot = 0.2;    // Boom/Crash
   else if(isForex)
      floorLot = 0.01;   // Forex

   return floorLot;
}

//+------------------------------------------------------------------+
//| Calcul de Lot Intelligent (MM + Martingale)                      |
//+------------------------------------------------------------------+
double CalculateLot(double atr)
{
   double lot = FixedLotSize;
   bool isForex = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE) == SYMBOL_CALC_MODE_FOREX);
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);

   // 1. Calcul basé sur le risque % si activé
   if(RiskPercent > 0 && atr > 0 && !isBoomCrash)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * RiskPercent / 100.0;
      double slPoints = (atr * SL_ATR_Mult) / _Point;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      // Ajustement spécifique pour le Forex
      if(isForex)
      {
         // Valeur par défaut sécurisée pour le Forex
         lot = 0.1;
         
         if(slPoints > 0 && tickValue > 0 && tickSize > 0 && point > 0)
         {
            // Calcul plus précis pour le Forex
            double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            if(contractSize > 0 && price > 0)
            {
               double riskPerLot = slPoints * tickValue * point / tickSize;
               if(riskPerLot > 0)
                  lot = riskMoney / riskPerLot;
            }
         }
      }
      else if(slPoints > 0 && tickValue > 0)
      {
         lot = riskMoney / (slPoints * tickValue);
      }
   }

   // Vérifier si le symbole commence par "UK" pour forcer le lot à 0.01
   bool isUKIndex = (StringSubstr(_Symbol, 0, 2) == "UK");
   if(isUKIndex)
   {
      lot = 0.1;
      return lot; // Retourner directement 0.01 pour les indices UK
   }
   
   // 2. Martingale (Vérifier le dernier trade clos) - désactivé pour Boom/Crash (lots fixes)
   if(UseMartingale && !isBoomCrash)
   {
      double lastLot;
      double lastProfit;
      if(GetLastHistoryTrade(lastLot, lastProfit))
      {
         if(lastProfit < 0) // Si perte
         {
            lot = lastLot * MartingaleMult;
            // Limite martingale steps
            if(MartingaleSteps > 0)
            {
               int lossStreak = GetConsecutiveLosses();
               if(lossStreak >= MartingaleSteps)
                  lot = lastLot; // Ne pas augmenter plus après le nombre max d'étapes
            }
         }
      }
   }

   // 3. Vérification des limites du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Arrondir au step le plus proche
   if(lotStep > 0)
      lot = MathFloor(lot / lotStep) * lotStep;
   
   // Appliquer les limites
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   
   // Limite spécifique selon le type d'instrument
   bool isVol = (!isForex &&
                 (StringFind(_Symbol, "Volatility") != -1 ||
                  StringFind(_Symbol, "VOLATILITY") != -1 ||
                  StringFind(_Symbol, "volatility") != -1));
   bool isIndex = (isVol || isBoomCrash);

   // --- Règle spécifique Step Index : lot maximum 0.1 ---
   if(isStepIndex)
   {
      // Lot minimum 0.10
      if(lot < 0.10)
         lot = 0.10;
      // Lot maximum 0.1 (bloquer si dépassé)
      if(lot > 0.1)
         lot = 0.0; // Retourner 0 pour bloquer le signal
   }

   // --- Lots fixes et bloqués pour Boom/Crash selon les spécifications ---
   if(isBoomCrash)
   {
      // Valeur par défaut pour tous les Boom/Crash
      lot = 0.2;

      // Crash 300 -> 0.5 lot
      if(StringFind(_Symbol, "Crash 300") != -1)
         lot = 0.5;

      // Boom 300 -> 1 lot
      if(StringFind(_Symbol, "Boom 300") != -1)
         lot = 1.0;

      // S'assurer que le lot respecte les min/max broker
      lot = MathMax(lot, minLot);
      lot = MathMin(lot, maxLot);
   }
   else if(isForex)
   {
      // Forex : maximum 0.01 lot
      double maxForexLot = 0.01;
      lot = MathMin(lot, maxForexLot);
   }
   else if(isIndex)
   {
      // Indices de volatilité uniquement (hors Boom/Crash) : maximum 0.2 lot
      double maxIndexLot = 0.2;
      lot = MathMin(lot, maxIndexLot);
   }
   
   // Cap utilisateur global
   lot = MathMin(lot, MaxLotSize);
   
   // Dernier arrondi et vérification
   if(lot > 0.0)
   {
      // S'assurer que le lot est un multiple du pas minimum
      if(lotStep > 0)
         lot = MathFloor(lot / lotStep) * lotStep;
         
      // Vérifier que le lot n'est pas en dessous du minimum
      if(lot < minLot)
         lot = minLot;
         
      // Vérifier que le lot ne dépasse pas le maximum
      lot = MathMin(lot, maxLot);
   }
   
   return (lot > 0.0) ? NormalizeDouble(lot, 2) : 0.0;
}

//+------------------------------------------------------------------+
//| Gestion des pertes par symbole                                  |
//+------------------------------------------------------------------+

// Vérifie si un symbole est en cooldown (sans paramètre de sortie)
bool IsSymbolInCooldown(string symbol) {
   int dummy; // Variable inutilisée
   return IsSymbolInCooldown(symbol, dummy);
}

// Vérifie si un symbole est en cooldown (avec paramètre de sortie)
bool IsSymbolInCooldown(string symbol, int &consecutiveLosses) {
   // Variable locale pour stocker les pertes consécutives
   int tempConsecutiveLosses = 0;
   bool inCooldown = false;
   
   for(int i = 0; i < ArraySize(g_symbolLosses); i++) {
      if(g_symbolLosses[i].symbol == symbol) {
         if(TimeCurrent() < g_symbolLosses[i].cooldownUntil) {
            tempConsecutiveLosses = g_symbolLosses[i].consecutiveLosses;
            inCooldown = true;
         } else {
            // Supprimer l'entrée si le cooldown est terminé
            ArrayRemove(g_symbolLosses, i, 1);
         }
         break;
      }
   }
   
   // Mettre à jour la référence
   consecutiveLosses = tempConsecutiveLosses;
      
   return inCooldown;
}

// Démarre un cooldown pour un symbole spécifique
void StartSymbolCooldown(string symbol, int consecutiveLosses) {
   int cooldownMinutes = (consecutiveLosses >= 3) ? 30 : 10; // 30 min si 3+ pertes, sinon 10 min
   
   // Vérifier si le symbole existe déjà
   for(int i = 0; i < ArraySize(g_symbolLosses); i++) {
      if(g_symbolLosses[i].symbol == symbol) {
         g_symbolLosses[i].consecutiveLosses = consecutiveLosses;
         g_symbolLosses[i].cooldownUntil = TimeCurrent() + (cooldownMinutes * 60);
         Print("⏸ Cooldown ", symbol, ": ", cooldownMinutes, " minutes après ", consecutiveLosses, " pertes consécutives");
         return;
      }
   }
   
   // Ajouter une nouvelle entrée
   int size = ArraySize(g_symbolLosses);
   ArrayResize(g_symbolLosses, size + 1);
   g_symbolLosses[size].symbol = symbol;
   g_symbolLosses[size].consecutiveLosses = consecutiveLosses;
   g_symbolLosses[size].cooldownUntil = TimeCurrent() + (cooldownMinutes * 60);
   Print("⏸ Nouveau cooldown ", symbol, ": ", cooldownMinutes, " minutes après ", consecutiveLosses, " pertes consécutives");
}

//+------------------------------------------------------------------+
//| Compte le nombre de pertes consécutives sur CE symbole          |
//| (du plus récent vers l'ancien)                                  |
//+------------------------------------------------------------------+
int GetConsecutiveLosses()
{
   int consecutiveLosses = 0;
   static int boom300RecentLosses = 0;
   HistorySelect(0, TimeCurrent());
   
   // Vérifier d'abord si le symbole est en cooldown
   int existingLosses = 0;
   if(IsSymbolInCooldown(_Symbol, existingLosses)) {
      return existingLosses; // Retourne le nombre de pertes enregistrées
   }
   
   // Compter les pertes consécutives
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      // Vérifier si c'est un trade de clôture
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      
      // Vérifier si c'est notre EA
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;

      // Vérifier que c'est bien le même symbole (ce "marché")
      string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(sym != _Symbol) continue;
      
      // Vérifier le profit
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      
      if(profit < 0.0)
         consecutiveLosses++;
      else
         break; // On s'arrête au premier trade gagnant
   }
   
   // Si on a 2 pertes ou plus, démarrer un cooldown
   if(consecutiveLosses >= 2) {
      StartSymbolCooldown(_Symbol, consecutiveLosses);
   }
   
   // Gestion spécifique pour Boom 300
   if(StringFind(_Symbol, "Boom 300") != -1)
   {
      boom300RecentLosses = consecutiveLosses;
      if(boom300RecentLosses >= 2)
      {
         // Démarre un cooldown minimum de 10 minutes sur Boom 300
         if(g_boom300CooldownUntil < TimeCurrent())
         {
            g_boom300CooldownUntil = TimeCurrent() + 10 * 60;
            Print("⏸ Cooldown Boom 300: pause 10 minutes après ", boom300RecentLosses, " pertes consécutives.");
         }
      }
   }
   
   return consecutiveLosses;
}

//+------------------------------------------------------------------+
//| Récupère info dernier trade fermé (Pour Martingale)              |
//+------------------------------------------------------------------+
bool GetLastHistoryTrade(double &lastLot, double &lastProfit)
{
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue; // On veut la sortie

      lastLot = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      lastProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      return true;
   }
   return false;
}

// Dernière perte (pour cooldown après SL)
bool GetLastLoss(datetime &lossTime, double &lossProfit)
{
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue; // On veut la sortie

      lossProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      lossTime   = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      return (lossProfit < 0);
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void CleanPendingOrders()
{
   bool hasPosition = (CountPositionsForSymbolMagic() > 0);
   
   // Si on a une position ouverte, ne pas toucher aux ordres limit (laisser finir)
   if(hasPosition)
   {
      // Gérer les ordres limit: s'assurer qu'on ne dépasse pas le maximum
      ManagePendingOrders();
      return;
   }
   
   // Gérer les ordres limit: exécuter le plus proche si scalping activé
   ManagePendingOrders();
   
   // Supprimer les ordres trop vieux (> 30 min)
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
         continue;
      
      // Supprimer si trop vieux (> 30 min)
      long setupTime = OrderGetInteger(ORDER_TIME_SETUP);
      if(TimeCurrent() - setupTime > 1800) // 30 minutes
         trade.OrderDelete(ticket);
   }
}

int CountPositionsForSymbolMagic()
{
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| LIMITE: MAXIMUM 2 POSITIONS OUVERTES TOUS SYMBOLES CONFONDUS     |
//| NOTE: cette limite est GLOBALE, elle compte toutes les positions |
//|      du compte, quel que soit le symbole ou le magic number.     |
//+------------------------------------------------------------------+
bool CanOpenNewPosition()
{
   // Utiliser le compteur global pour toutes les positions ouvertes
   int count = CountAllPositionsForMagic();
   
   // Limite GLOBALE: maximum 3 positions ouvertes en même temps (tous symboles confondus)
   int maxGlobal = 3;

   if(count >= maxGlobal)
   {
      Print("❌ PROTECTION: ", count, " positions déjà ouvertes. Maximum ", maxGlobal, " positions autorisées.");
      return false;
   }
   
   return true;
}

// Cooldown après 2 pertes consécutives sur ce symbole (3 minutes par défaut)
bool IsSymbolLossCooldownActive(int cooldownSec = 180)
{
   if(g_lastSymbolLossTime == 0) return false;
   return (TimeCurrent() - g_lastSymbolLossTime) < cooldownSec;
}

void StartSymbolLossCooldown()
{
   g_lastSymbolLossTime = TimeCurrent();
}

// ------------------------------------------------------------------
// Gestion des fenêtres horaires envoyées par le serveur IA
// ------------------------------------------------------------------

int ParseInt(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) == 0) return 0;
   return (int)StringToInteger(s);
}

void AI_UpdateTimeWindows()
{
   if(!UseAI_Agent || StringLen(AI_TimeWindowsURLBase) == 0)
      return;

   datetime now = TimeCurrent();
   // Mise à jour toutes les 4 heures OU si le symbole a changé
   bool symbolChanged = (g_timeWindowsSymbol != _Symbol);
   if(!symbolChanged && g_lastTimeWindowsUpdate != 0 && (now - g_lastTimeWindowsUpdate) < (4 * 3600))
      return;

   string url = AI_TimeWindowsURLBase;
   // S'assurer qu'on n'a pas déjà le suffixe
   if(StringSubstr(url, StringLen(url)-1, 1) == "/")
      url = StringSubstr(url, 0, StringLen(url)-1);
   
   // Encoder le symbole pour l'URL (remplacer les espaces par %20)
   string encodedSymbol = _Symbol;
   StringReplace(encodedSymbol, " ", "%20");
   url += "/time_windows/" + encodedSymbol;

   char data[];
   char result[];
   string headers = "";
   string result_headers = "";

   int res = WebRequest("GET", url, headers, AI_Timeout_ms, data, result, result_headers);
   if(res < 200 || res >= 300)
   {
      Print("AI_TimeWindows: WebRequest échec http=", res, " err=", GetLastError());
      return;
   }

   string resp = CharArrayToString(result, 0, -1, CP_UTF8);

   // Initialiser les tableaux à false
   ArrayInitialize(g_hourPreferred, false);
   ArrayInitialize(g_hourForbidden, false);

   // Parsing simple des tableaux preferred_hours et forbidden_hours (valeurs int séparées par virgules)
   int prefPos = StringFind(resp, "\"preferred_hours\"");
   if(prefPos >= 0)
   {
      int bracket1 = StringFind(resp, "[", prefPos);
      int bracket2 = StringFind(resp, "]", bracket1+1);
      if(bracket1 >= 0 && bracket2 > bracket1)
      {
         string arr = StringSubstr(resp, bracket1+1, bracket2-bracket1-1);
         int idx = 0;
         while(true)
         {
            string item = getJsonArrayItem("[" + arr + "]", idx);
            if(StringLen(item) == 0) break;
            int h = ParseInt(item);
            if(h >= 0 && h < 24) g_hourPreferred[h] = true;
            idx++;
         }
      }
   }

   int forbPos = StringFind(resp, "\"forbidden_hours\"");
   if(forbPos >= 0)
   {
      int bracket1 = StringFind(resp, "[", forbPos);
      int bracket2 = StringFind(resp, "]", bracket1+1);
      if(bracket1 >= 0 && bracket2 > bracket1)
      {
         string arr = StringSubstr(resp, bracket1+1, bracket2-bracket1-1);
         int idx = 0;
         while(true)
         {
            string item = getJsonArrayItem("[" + arr + "]", idx);
            if(StringLen(item) == 0) break;
            int h = ParseInt(item);
            if(h >= 0 && h < 24) g_hourForbidden[h] = true;
            idx++;
         }
      }
   }

   g_lastTimeWindowsUpdate = now;
   g_timeWindowsSymbol = _Symbol; // Mémoriser le symbole pour lequel les fenêtres ont été récupérées
}

//+------------------------------------------------------------------+
//| Récupère l'analyse fondamentale via API Alpha Vantage et NewsAPI |
//+------------------------------------------------------------------+
void AI_UpdateFundamentalAnalysis()
{
   // Mise à jour toutes les 10 minutes (limite API)
   datetime now = TimeCurrent();
   if(now - g_lastFundamentalUpdate < 600) return; // 10 min
   
   // Configuration de l'API Deriv
   string derivAppId = "YOUR_DERIV_APP_ID"; // À remplacer par votre App ID Deriv
   
   // Variables pour stocker les résultats
   double peRatio = 0;
   double dividendYield = 0;
   int newsCount = 0;
   double sentimentScore = 0;
   string marketBias = "neutral";
   
   // 1. Récupération des données fondamentales via API Deriv
   char data[];
   char result[];
   string headers = "";
   
   // Simulation de données pour les indices synthétiques Deriv
   if(StringFind(_Symbol, "BOOM") >= 0 || StringFind(_Symbol, "CRASH") >= 0 || 
      StringFind(_Symbol, "RANGE") >= 0 || StringFind(_Symbol, "STEP") >= 0)
   {
      // Pour les indices synthétiques, utiliser des données simulées
      peRatio = 15.5 + (MathRand() % 10) / 10.0;  // PER simulé entre 15.5 et 25.5
      dividendYield = 2.0 + (MathRand() % 5) / 10.0; // Dividende simulé entre 2.0% et 7.0%
      newsCount = MathRand() % 8 + 3; // 3-10 articles
      
      // Sentiment basé sur le type d'indice
      if(StringFind(_Symbol, "BOOM") >= 0)
      {
         sentimentScore = 0.3 + (MathRand() % 40) / 100.0; // Sentiment positif pour BOOM
         marketBias = (sentimentScore > 0.5) ? "bullish" : "neutral";
      }
      else if(StringFind(_Symbol, "CRASH") >= 0)
      {
         sentimentScore = -0.3 - (MathRand() % 40) / 100.0; // Sentiment négatif pour CRASH
         marketBias = (sentimentScore < -0.5) ? "bearish" : "neutral";
      }
      else
      {
         sentimentScore = (MathRand() % 21 - 10) / 100.0; // Sentiment neutre pour autres
         if(sentimentScore > 0.1) marketBias = "bullish";
         else if(sentimentScore < -0.1) marketBias = "bearish";
         else marketBias = "neutral";
      }
   }
   
   // Mise à jour des variables globales
   g_fundamentalSentiment = sentimentScore;
   g_fundamentalBias = marketBias;
   g_fundamentalNewsCount = newsCount;
   g_lastFundamentalUpdate = now;
   
   // Affichage des résultats dans le journal
   Print("📊 Données fondamentales mises à jour pour ", _Symbol);
   Print("   - PER: ", DoubleToString(peRatio, 2));
   Print("   - Rendement dividende: ", DoubleToString(dividendYield, 2), "%");
   Print("   - Nombre d'articles: ", newsCount);
   Print("   - Score de sentiment: ", DoubleToString(sentimentScore, 3), " (", marketBias, ")");
   
   // Mise à jour de l'affichage
   UpdateFundamentalDisplay(peRatio, dividendYield);
}

//+------------------------------------------------------------------+
//| Vérifie si le sentiment fondamental confirme la direction        |
//+------------------------------------------------------------------+
bool IsFundamentalConfirming(string direction)
{
   // Si pas de données récentes (>30min), on ignore le filtre
   if(TimeCurrent() - g_lastFundamentalUpdate > 1800) return true;
   
   // Seuils de sentiment
   double bullishThreshold = 0.1;   // Sentiment > 0.1 = bullish
   double bearishThreshold = -0.1;  // Sentiment < -0.1 = bearish
   
   if(direction == "buy")
   {
      // Pour un BUY, on veut un sentiment non-bearish (neutre ou bullish OK)
      if(g_fundamentalSentiment < bearishThreshold)
      {
         if(DebugBlocks)
            Print("⚠️ BUY bloqué par sentiment bearish: ", DoubleToString(g_fundamentalSentiment, 4));
         return false;
      }
   }
   else if(direction == "sell")
   {
      // Pour un SELL, on veut un sentiment non-bullish (neutre ou bearish OK)
      if(g_fundamentalSentiment > bullishThreshold)
      {
         if(DebugBlocks)
            Print("⚠️ SELL bloqué par sentiment bullish: ", DoubleToString(g_fundamentalSentiment, 4));
         return false;
      }
   }
   
   return true;
}

void DrawTimeWindowsPanel()
{
   // Marqueur visuel en bas à gauche avec résumé des heures
   string name = "TIME_WINDOWS_PANEL";
   int corner = CORNER_LEFT_LOWER;

   // Vérifier que les fenêtres horaires correspondent au symbole actuel
   if(g_timeWindowsSymbol != _Symbol && StringLen(g_timeWindowsSymbol) > 0)
   {
      // Les fenêtres ne correspondent pas au symbole actuel
      string txt = "TimeWindows\nSymbol mismatch!\nCurrent: " + _Symbol + "\nWindows: " + g_timeWindowsSymbol;
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, (long)corner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (long)5);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, (long)5);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, (long)ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      }
      ObjectSetString(0, name, OBJPROP_TEXT, txt);
      return;
   }

   MqlDateTime td;
   TimeCurrent(td);
   int hNow = td.hour;
   string status = "NEUTRAL";
   if(hNow >= 0 && hNow < 24)
   {
      if(g_hourForbidden[hNow]) status = "FORBIDDEN";
      else if(g_hourPreferred[hNow]) status = "PREFERRED";
   }

   // Construire un petit texte compact avec sentiment fondamental
   string sentimentIcon = "⚪";
   color sentimentColor = clrWhite;
   if(g_fundamentalBias == "bullish")
   {
      sentimentIcon = "🟢";
      sentimentColor = clrLime;
   }
   else if(g_fundamentalBias == "bearish")
   {
      sentimentIcon = "🔴";
      sentimentColor = clrRed;
   }
   
   string txt = "📊 ANALYSE\n";
   txt += "Sentiment: " + sentimentIcon + " " + g_fundamentalBias + " (" + DoubleToString(g_fundamentalSentiment, 3) + ")\n";
   txt += "News: " + IntegerToString(g_fundamentalNewsCount) + " articles\n";
   txt += "Trading: 24/7 ACTIF";

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, (long)corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (long)5);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, (long)5);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, (long)ANCHOR_LEFT_LOWER);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, sentimentColor);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

// Vérifie si une position peut être fermée (respecte le délai minimum)
bool CanClosePosition(ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   
   // Si le délai minimum est désactivé (0), on peut toujours fermer
   if(MinPositionLifetimeSec <= 0)
      return true;
   
   // Récupérer le temps d'ouverture de la position
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   datetime now = TimeCurrent();
   int ageSeconds = (int)(now - openTime);
   
   // Vérifier si la position est assez ancienne
   if(ageSeconds < MinPositionLifetimeSec)
   {
      Print("⚠️ Fermeture bloquée: position ", ticket, " trop récente (", ageSeconds, "s < ", MinPositionLifetimeSec, "s)");
      return false;
   }
   
   return true;
}

// Ferme toutes les positions ouvertes pour ce symbole/magic, quel que soit le gain/perte
void CloseAllPositionsForSymbolMagic()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Vérifier le délai minimum avant fermeture
      if(!CanClosePosition(ticket))
         continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      if(ticket > 0 && vol > 0)
      {
         Print("Clôture position spike sur ", _Symbol, " ticket=", ticket, " volume=", DoubleToString(vol, 2));
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Cette fonction compte uniquement les positions ouvertes par ce   |
//| robot (filtre par magic number)                                  |
//+------------------------------------------------------------------+
int CountAllPositionsForMagic()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         cnt++;
   }
   return cnt;
}

int AllowedDirectionFromSymbol(string sym)
{
   if(StringFind(sym, "Boom") != -1) return 1;  // Buy Only
   if(StringFind(sym, "Crash") != -1) return -1; // Sell Only
   return 0;
}

// Dessine une flèche de spike Boom/Crash
void DrawSpikeArrow(bool isBuySpike, double price)
{
   string prefix = isBuySpike ? "SPIKE_BUY_" : "SPIKE_SELL_";
   string name   = prefix + TimeToString(TimeCurrent(), TIME_SECONDS) + "_" + IntegerToString(MathRand());

   // Nettoyer éventuellement un ancien objet avec le même nom (très improbable mais sûr)
   ObjectDelete(0, name);

   ENUM_OBJECT arrowType = isBuySpike ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
   if(!ObjectCreate(0, name, arrowType, 0, TimeCurrent(), price))
      return;

   color clr = isBuySpike ? clrLime : clrRed;
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, (long)2);
}

// -------------------------------------------------------------------
// IA : Appel serveur externe via WebRequest
// -------------------------------------------------------------------

//+------------------------------------------------------------------+
//| Calcul VWAP (Volume Weighted Average Price) intraday            |
//+------------------------------------------------------------------+
double CalculateVWAP(int period = 500)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, period, rates);
   if(copied < 2) return 0.0;
   
   double sumPV = 0.0; // Sum(Price * Volume)
   double sumV  = 0.0; // Sum(Volume)
   
   for(int i = 0; i < copied; i++)
   {
      double typicalPrice = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      double volume = rates[i].tick_volume > 0 ? rates[i].tick_volume : 1.0;
      sumPV += typicalPrice * volume;
      sumV  += volume;
   }
   
   if(sumV > 0.0)
      return sumPV / sumV;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calcul SuperTrend simplifié (basé sur ATR + HL2)                |
//+------------------------------------------------------------------+
double CalculateSuperTrend(int period, double multiplier, int &trendOut)
{
   trendOut = 0; // 1 = UP, -1 = DOWN
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M15, 0, period + 5, rates);
   if(copied < period + 2) return 0.0;
   
   // Calculer ATR sur M15 (utiliser un nom différent pour éviter conflit avec global)
   int g_atrHandleST = iATR(_Symbol, PERIOD_M15, period);
   if(g_atrHandleST == INVALID_HANDLE) return 0.0;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandleST, 0, 0, 2, atr) < 2)
   {
      IndicatorRelease(g_atrHandleST);
      return 0.0;
   }
   IndicatorRelease(g_atrHandleST);
   
   double hl2 = (rates[0].high + rates[0].low) / 2.0;
   double upperBand = hl2 + (multiplier * atr[0]);
   double lowerBand = hl2 - (multiplier * atr[0]);
   
   double prevHL2 = (rates[1].high + rates[1].low) / 2.0;
   double prevUpper = prevHL2 + (multiplier * atr[1]);
   double prevLower = prevHL2 - (multiplier * atr[1]);
   
   // SuperTrend basic logic
   if(rates[0].close > prevUpper)
      trendOut = 1; // UPTREND
   else if(rates[0].close < prevLower)
      trendOut = -1; // DOWNTREND
   else
      trendOut = (rates[1].close > prevHL2) ? 1 : -1; // Continue previous trend
   
   return (trendOut > 0) ? lowerBand : upperBand;
}

int AI_GetDecision(double rsi, double atr,
                   double emaFastH1, double emaSlowH1,
                   double emaFastM1, double emaSlowM1,
                   double ask, double bid,
                   int dirRule, bool spikeMode)
{
   // Reset AI decision variables
   g_lastAIAction     = "";
   g_lastAIConfidence = 0.0;
   g_lastAIReason     = "";
   g_aiBuyZoneLow     = 0.0;
   g_aiBuyZoneHigh    = 0.0;
   g_aiSellZoneLow    = 0.0;
   g_aiSellZoneHigh   = 0.0;

   // Sécurité : si URL vide, on n'appelle pas
   if(StringLen(AI_ServerURL) == 0)
      return 0;
   
   // Normaliser l'URL : s'assurer qu'elle se termine par "/decision" si elle ne contient pas de chemin
   string urlToUse = AI_ServerURL;
   int pathPos = StringFind(urlToUse, "/", StringFind(urlToUse, "://") + 3);
   if(pathPos < 0)
   {
      // Pas de chemin dans l'URL, ajouter "/decision"
      if(StringSubstr(urlToUse, StringLen(urlToUse) - 1) != "/")
         urlToUse += "/decision";
      else
         urlToUse += "decision";
   }
   else if(StringFind(urlToUse, "/decision") < 0)
   {
      // L'URL a un chemin mais ce n'est pas "/decision"
      // Extraire la base et ajouter "/decision"
      string baseUrl = StringSubstr(urlToUse, 0, pathPos);
      if(StringSubstr(baseUrl, StringLen(baseUrl) - 1) != "/")
         urlToUse = baseUrl + "/decision";
      else
         urlToUse = baseUrl + "decision";
   }

   // Validation des valeurs numériques (éviter NaN/Infinity)
   if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || 
      !MathIsValidNumber(rsi) || !MathIsValidNumber(atr) ||
      !MathIsValidNumber(emaFastH1) || !MathIsValidNumber(emaSlowH1) ||
      !MathIsValidNumber(emaFastM1) || !MathIsValidNumber(emaSlowM1))
   {
      if(DebugBlocks)
         Print("AI: valeurs invalides (NaN/Inf), skip WebRequest");
      return 0;
   }

   // Normalisation des valeurs pour éviter les problèmes de précision
   double safeBid = NormalizeDouble(bid, _Digits);
   double safeAsk = NormalizeDouble(ask, _Digits);
   double midPrice = (safeBid + safeAsk) / 2.0;
   double safeRsi = NormalizeDouble(rsi, 2);
   double safeAtr = NormalizeDouble(atr, _Digits);
   double safeEmaFastH1 = NormalizeDouble(emaFastH1, _Digits);
   double safeEmaSlowH1 = NormalizeDouble(emaSlowH1, _Digits);
   double safeEmaFastM1 = NormalizeDouble(emaFastM1, _Digits);
   double safeEmaSlowM1 = NormalizeDouble(emaSlowM1, _Digits);

   // Calcul VWAP (Volume Weighted Average Price) - indicateur moderne 2025
   double vwap = CalculateVWAP(500);
   double vwapDistance = 0.0;
   bool aboveVWAP = false;
   if(vwap > 0.0)
   {
      vwapDistance = ((midPrice - vwap) / vwap) * 100.0; // Distance en %
      aboveVWAP = midPrice > vwap;
   }

   // Calcul SuperTrend M15 (indicateur de tendance moderne)
   int supertrendTrend = 0; // 1 = UP, -1 = DOWN, 0 = indéterminé
   double supertrendLine = CalculateSuperTrend(10, 3.0, supertrendTrend);
   
   // Stocker les valeurs pour affichage graphique
   g_currentVWAP = vwap;
   g_currentSuperTrendLine = supertrendLine;
   g_currentSuperTrendDirection = supertrendTrend;
   g_lastIndicatorsUpdate = TimeCurrent();

   // Calcul régime de volatilité (High/Low/Normal)
   double volatilityRatio = 0.0;
   int volatilityRegime = 0; // 0 = Normal, 1 = High Vol, -1 = Low Vol
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, PERIOD_M1, 0, 200, rates);
      if(copied >= 100)
      {
         // ATR court (10) vs ATR long (50)
         double atrShort[], atrLong[];
         ArraySetAsSeries(atrShort, true);
         ArraySetAsSeries(atrLong, true);
         int atrShortHandle = iATR(_Symbol, PERIOD_M1, 10);
         int atrLongHandle = iATR(_Symbol, PERIOD_M1, 50);
         if(atrShortHandle != INVALID_HANDLE && atrLongHandle != INVALID_HANDLE)
         {
            if(CopyBuffer(atrShortHandle, 0, 0, 1, atrShort) > 0 &&
               CopyBuffer(atrLongHandle, 0, 0, 1, atrLong) > 0 &&
               atrLong[0] > 0.0)
            {
               volatilityRatio = atrShort[0] / atrLong[0];
               if(volatilityRatio > 1.5)
                  volatilityRegime = 1; // High Vol
               else if(volatilityRatio < 0.7)
                  volatilityRegime = -1; // Low Vol
            }
            IndicatorRelease(atrShortHandle);
            IndicatorRelease(atrLongHandle);
         }
      }
   }

   // Construction JSON sécurisée (échappement du symbole)
   string safeSymbol = _Symbol;
   StringReplace(safeSymbol, "\"", "\\\""); // Échapper les guillemets
   StringReplace(safeSymbol, "\\", "\\\\"); // Échapper les backslashes
   
   string payload = "{";
   payload += "\"symbol\":\"" + safeSymbol + "\",";
   payload += "\"bid\":" + DoubleToString(safeBid, _Digits) + ",";
   payload += "\"ask\":" + DoubleToString(safeAsk, _Digits) + ",";
   payload += "\"rsi\":" + DoubleToString(safeRsi, 2) + ",";
   payload += "\"ema_fast_h1\":" + DoubleToString(safeEmaFastH1, _Digits) + ",";
   payload += "\"ema_slow_h1\":" + DoubleToString(safeEmaSlowH1, _Digits) + ",";
   payload += "\"ema_fast_m1\":" + DoubleToString(safeEmaFastM1, _Digits) + ",";
   payload += "\"ema_slow_m1\":" + DoubleToString(safeEmaSlowM1, _Digits) + ",";
   payload += "\"atr\":" + DoubleToString(safeAtr, _Digits) + ",";
   payload += "\"dir_rule\":" + IntegerToString(dirRule) + ",";
   payload += "\"is_spike_mode\":" + (spikeMode ? "true" : "false") + ",";
   payload += "\"vwap\":" + DoubleToString(vwap, _Digits) + ",";
   payload += "\"vwap_distance\":" + DoubleToString(vwapDistance, 4) + ",";
   payload += "\"above_vwap\":" + (aboveVWAP ? "true" : "false") + ",";
   payload += "\"supertrend_trend\":" + IntegerToString(supertrendTrend) + ",";
   payload += "\"supertrend_line\":" + DoubleToString(supertrendLine, _Digits) + ",";
   payload += "\"volatility_regime\":" + IntegerToString(volatilityRegime) + ",";
   payload += "\"volatility_ratio\":" + DoubleToString(volatilityRatio, 4);
   payload += "}";

   // Conversion en UTF-8 avec dimensionnement correct du tableau
   int payloadLen = StringLen(payload);
   char data[];
   ArrayResize(data, payloadLen + 1);
   int copied = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Vérification que la conversion a réussi
   if(copied <= 0 || copied > payloadLen + 1)
   {
      if(DebugBlocks)
         Print("AI: erreur conversion JSON en UTF-8, skip WebRequest");
      return 0;
   }
   
   // Ajuster la taille du tableau pour correspondre exactement aux données
   ArrayResize(data, copied - 1); // -1 car StringToCharArray ajoute un \0 terminal

   // Debug: vérifier le JSON complet (optionnel, peut être désactivé)
   if(DebugBlocks && StringLen(payload) > 200)
   {
      Print("AI JSON (preview): ", StringSubstr(payload, 0, 100), "...", StringSubstr(payload, StringLen(payload) - 50));
   }

   char result[];
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";

   int res = WebRequest("POST", urlToUse, headers, AI_Timeout_ms, data, result, result_headers);

   // WebRequest renvoie directement le code HTTP (200, 404, etc.) ou -1 en cas d'erreur
   if(res < 200 || res >= 300)
   {
      int errorCode = GetLastError();
      Print("❌ AI WebRequest échec: http=", res, " - Erreur MT5: ", errorCode);
      if(errorCode == 4060)
      {
         Print("⚠️ ERREUR 4060: URL non autorisée dans MT5!");
         Print("   Allez dans: Outils -> Options -> Expert Advisors");
         Print("   Cochez 'Autoriser les WebRequest pour les URL listées'");
         Print("   Ajoutez: http://127.0.0.1");
      }
      return 0;
   }
   
   // Succès
   if(DebugBlocks)
      Print("✅ AI WebRequest réussi: http=", res);

   string resp = CharArrayToString(result, 0, -1, CP_UTF8);
   g_lastAIJson = resp; // Stocker la réponse brute pour affichage sur le graphique

   // Parsing minimaliste du JSON pour récupérer "action" et "confidence"
   int actionPos = StringFind(resp, "\"action\"");
   if(actionPos >= 0)
   {
      // Chercher "buy" ou "sell"
      if(StringFind(resp, "\"buy\"", actionPos) >= 0)
      {
         g_lastAIAction = "buy";
      }
      else if(StringFind(resp, "\"sell\"", actionPos) >= 0)
      {
         g_lastAIAction = "sell";
      }
      else
      {
         g_lastAIAction = "hold";
      }
   }

   int confPos = StringFind(resp, "\"confidence\"");
   if(confPos >= 0)
   {
      int colon = StringFind(resp, ":", confPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string confStr = StringSubstr(resp, colon+1, endPos-colon-1);
            g_lastAIConfidence = StringToDouble(confStr);
         }
      }
   }

   // Extraire la raison (reason)
   g_lastAIReason = "";
   int reasonPos = StringFind(resp, "\"reason\"");
   if(reasonPos >= 0)
   {
      int colonR = StringFind(resp, ":", reasonPos);
      if(colonR > 0)
      {
         // Chercher le début de la chaîne (après ": ")
         int startQuote = StringFind(resp, "\"", colonR);
         if(startQuote > 0)
         {
            int endQuote = StringFind(resp, "\"", startQuote + 1);
            if(endQuote > startQuote)
            {
               g_lastAIReason = StringSubstr(resp, startQuote + 1, endQuote - startQuote - 1);
            }
         }
      }
   }

   // Extraire prédiction de spike (spike_prediction) et pré‑alerte (early_spike_warning)
   g_aiSpikePredicted      = false;
   g_aiSpikeZonePrice      = 0.0;
   g_aiSpikeDirection      = true;
   g_aiStrongSpike         = false;
   g_aiEarlySpikeWarning   = false;
   g_aiEarlySpikeZonePrice = 0.0;
   g_aiEarlySpikeDirection = true;
   int spikePredPos = StringFind(resp, "\"spike_prediction\"");
   if(spikePredPos >= 0)
   {
      int colonSP = StringFind(resp, ":", spikePredPos);
      if(colonSP > 0)
      {
         // Chercher true/false
         if(StringFind(resp, "true", colonSP) >= 0)
         {
            g_aiSpikePredicted = true;
            g_aiStrongSpike    = true;
            // Chercher spike_zone_price
            int zonePos = StringFind(resp, "\"spike_zone_price\"");
            if(zonePos >= 0)
            {
               int colonZ = StringFind(resp, ":", zonePos);
               if(colonZ > 0)
               {
                  int endZ = StringFind(resp, ",", colonZ);
                  if(endZ < 0) endZ = StringFind(resp, "}", colonZ);
                  if(endZ > colonZ)
                  {
                     string zoneStr = StringSubstr(resp, colonZ+1, endZ-colonZ-1);
                     g_aiSpikeZonePrice = StringToDouble(zoneStr);
                  }
               }
            }
            // Chercher spike_direction (true=BUY, false=SELL)
            int dirPos = StringFind(resp, "\"spike_direction\"");
            if(dirPos >= 0)
            {
               int colonD = StringFind(resp, ":", dirPos);
               if(colonD > 0)
               {
                  if(StringFind(resp, "true", colonD) >= 0)
                     g_aiSpikeDirection = true; // BUY
                  else if(StringFind(resp, "false", colonD) >= 0)
                     g_aiSpikeDirection = false; // SELL
               }
            }
         }
      }
   }

   // Pré‑alerte de spike (early_spike_warning)
   int earlyPos = StringFind(resp, "\"early_spike_warning\"");
   if(earlyPos >= 0)
   {
      int colonE = StringFind(resp, ":", earlyPos);
      if(colonE > 0)
      {
         if(StringFind(resp, "true", colonE) >= 0)
         {
            g_aiEarlySpikeWarning = true;
            // Zone de pré‑spike
            int zonePosE = StringFind(resp, "\"early_spike_zone_price\"");
            if(zonePosE >= 0)
            {
               int colonZE = StringFind(resp, ":", zonePosE);
               if(colonZE > 0)
               {
                  int endZE = StringFind(resp, ",", colonZE);
                  if(endZE < 0) endZE = StringFind(resp, "}", colonZE);
                  if(endZE > colonZE)
                  {
                     string zoneStrE = StringSubstr(resp, colonZE+1, endZE-colonZE-1);
                     g_aiEarlySpikeZonePrice = StringToDouble(zoneStrE);
                  }
               }
            }
            // Direction early_spike_direction
            int dirPosE = StringFind(resp, "\"early_spike_direction\"");
            if(dirPosE >= 0)
            {
               int colonDE = StringFind(resp, ":", dirPosE);
               if(colonDE > 0)
               {
                  if(StringFind(resp, "true", colonDE) >= 0)
                     g_aiEarlySpikeDirection = true;
                  else if(StringFind(resp, "false", colonDE) >= 0)
                     g_aiEarlySpikeDirection = false;
               }
            }

            // Si aucun spike "fort" n'est encore détecté, utiliser la pré‑alerte pour l'affichage
            if(!g_aiStrongSpike)
            {
               g_aiSpikePredicted = true;
               g_aiSpikeZonePrice = g_aiEarlySpikeZonePrice;
               g_aiSpikeDirection = g_aiEarlySpikeDirection;
            }
         }
      }
   }

   // Extraire les zones H1 confirmées M5
   int zoneBuyLowPos = StringFind(resp, "\"buy_zone_low\"");
   if(zoneBuyLowPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneBuyLowPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
            g_aiBuyZoneLow = StringToDouble(StringSubstr(resp, colon+1, endPos-colon-1));
      }
   }
   int zoneBuyHighPos = StringFind(resp, "\"buy_zone_high\"");
   if(zoneBuyHighPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneBuyHighPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
            g_aiBuyZoneHigh = StringToDouble(StringSubstr(resp, colon+1, endPos-colon-1));
      }
   }
   int zoneSellLowPos = StringFind(resp, "\"sell_zone_low\"");
   if(zoneSellLowPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneSellLowPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
            g_aiSellZoneLow = StringToDouble(StringSubstr(resp, colon+1, endPos-colon-1));
      }
   }
   int zoneSellHighPos = StringFind(resp, "\"sell_zone_high\"");
   if(zoneSellHighPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneSellHighPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
            g_aiSellZoneHigh = StringToDouble(StringSubstr(resp, colon+1, endPos-colon-1));
      }
   }

   g_lastAITime = TimeCurrent();
   
   // Si une prédiction de spike est détectée, afficher l'alerte immédiatement
   if(g_aiSpikePredicted)
   {
      DisplaySpikeAlert();
   }

   if(g_lastAIAction == "buy")
      return 1;
   if(g_lastAIAction == "sell")
      return -1;
   return 0; // hold / inconnu
}

// -------------------------------------------------------------------
//  IA - Analyse complète /analysis : structure H1 (trendlines, ETE)
// -------------------------------------------------------------------

// Helper interne : récupère un double après "\"key\":" à partir d'une position
double AI_ExtractJsonDouble(string &json, string key, int start_pos)
{
   int pos = StringFind(json, "\"" + key + "\"", start_pos);
   if(pos < 0) return 0.0;
   int colon = StringFind(json, ":", pos);
   if(colon < 0) return 0.0;
   int endPos = StringFind(json, ",", colon);
   if(endPos < 0) endPos = StringFind(json, "}", colon);
   if(endPos <= colon) return 0.0;
   string val = StringSubstr(json, colon+1, endPos-colon-1);
   StringTrimLeft(val);
   StringTrimRight(val);
   return StringToDouble(val);
}

// Helper : extrait deux paires (time, price) à partir d'un bloc trendline
void AI_ParseTrendlineBlock(string &json, int block_start,
                            double &start_price, datetime &start_time,
                            double &end_price, datetime &end_time)
{
   start_price = 0.0;
   end_price   = 0.0;
   start_time  = 0;
   end_time    = 0;

   if(block_start < 0) return;

   // Limiter la recherche au bloc courant (jusqu'à la prochaine trendline ou fin)
   int block_end = StringFind(json, "\"bearish\"", block_start+1);
   if(block_end < 0)
      block_end = StringFind(json, "}", block_start+1);
   if(block_end < 0)
      block_end = StringLen(json);

   int pos = block_start;
   // start.time
   int time1_pos = StringFind(json, "\"time\"", pos);
   if(time1_pos >= 0 && time1_pos < block_end)
   {
      start_time = (datetime)AI_ExtractJsonDouble(json, "time", time1_pos);
      int price1_pos = StringFind(json, "\"price\"", time1_pos);
      if(price1_pos >= 0 && price1_pos < block_end)
         start_price = AI_ExtractJsonDouble(json, "price", price1_pos);
      pos = price1_pos + 1;
   }
   // end.time
   int time2_pos = StringFind(json, "\"time\"", pos);
   if(time2_pos >= 0 && time2_pos < block_end)
   {
      end_time = (datetime)AI_ExtractJsonDouble(json, "time", time2_pos);
      int price2_pos = StringFind(json, "\"price\"", time2_pos);
      if(price2_pos >= 0 && price2_pos < block_end)
         end_price = AI_ExtractJsonDouble(json, "price", price2_pos);
   }
}

void DrawH1Structure()
{
   if(!AI_DrawH1Structure)
      return;

   // Nettoyer anciens objets
   ObjectDelete(0, "AI_H1_BULL_TL");
   ObjectDelete(0, "AI_H1_BEAR_TL");
   ObjectDelete(0, "AI_H1_ETE_HEAD");
   ObjectDelete(0, "AI_H4_BULL_TL");
   ObjectDelete(0, "AI_H4_BEAR_TL");
   ObjectDelete(0, "AI_M15_BULL_TL");
   ObjectDelete(0, "AI_M15_BEAR_TL");

   // Trendline haussière H1
   if(g_h1BullStartTime > 0 && g_h1BullEndTime > 0 &&
      g_h1BullStartPrice > 0 && g_h1BullEndPrice > 0)
   {
      ObjectCreate(0, "AI_H1_BULL_TL", OBJ_TREND, 0,
                   g_h1BullStartTime, g_h1BullStartPrice,
                   g_h1BullEndTime,   g_h1BullEndPrice);
      ObjectSetInteger(0, "AI_H1_BULL_TL", OBJPROP_COLOR, (long)clrLime);
      ObjectSetInteger(0, "AI_H1_BULL_TL", OBJPROP_WIDTH, (long)2);
      ObjectSetInteger(0, "AI_H1_BULL_TL", OBJPROP_RAY_RIGHT, (long)true);
   }

   // Trendline baissière H1
   if(g_h1BearStartTime > 0 && g_h1BearEndTime > 0 &&
      g_h1BearStartPrice > 0 && g_h1BearEndPrice > 0)
   {
      ObjectCreate(0, "AI_H1_BEAR_TL", OBJ_TREND, 0,
                   g_h1BearStartTime, g_h1BearStartPrice,
                   g_h1BearEndTime,   g_h1BearEndPrice);
      ObjectSetInteger(0, "AI_H1_BEAR_TL", OBJPROP_COLOR, (long)clrRed);
      ObjectSetInteger(0, "AI_H1_BEAR_TL", OBJPROP_WIDTH, (long)2);
      ObjectSetInteger(0, "AI_H1_BEAR_TL", OBJPROP_RAY_RIGHT, (long)true);
   }

   // Trendline haussière H4
   if(g_h4BullStartTime > 0 && g_h4BullEndTime > 0 &&
      g_h4BullStartPrice > 0 && g_h4BullEndPrice > 0)
   {
      ObjectCreate(0, "AI_H4_BULL_TL", OBJ_TREND, 0,
                   g_h4BullStartTime, g_h4BullStartPrice,
                   g_h4BullEndTime,   g_h4BullEndPrice);
      ObjectSetInteger(0, "AI_H4_BULL_TL", OBJPROP_COLOR, (long)clrForestGreen);
      ObjectSetInteger(0, "AI_H4_BULL_TL", OBJPROP_WIDTH, (long)2);
      ObjectSetInteger(0, "AI_H4_BULL_TL", OBJPROP_RAY_RIGHT, (long)true);
   }

   // Trendline baissière H4
   if(g_h4BearStartTime > 0 && g_h4BearEndTime > 0 &&
      g_h4BearStartPrice > 0 && g_h4BearEndPrice > 0)
   {
      ObjectCreate(0, "AI_H4_BEAR_TL", OBJ_TREND, 0,
                   g_h4BearStartTime, g_h4BearStartPrice,
                   g_h4BearEndTime,   g_h4BearEndPrice);
      ObjectSetInteger(0, "AI_H4_BEAR_TL", OBJPROP_COLOR, (long)clrMaroon);
      ObjectSetInteger(0, "AI_H4_BEAR_TL", OBJPROP_WIDTH, (long)2);
      ObjectSetInteger(0, "AI_H4_BEAR_TL", OBJPROP_RAY_RIGHT, (long)true);
   }

   // Trendline haussière M15
   if(g_m15BullStartTime > 0 && g_m15BullEndTime > 0 &&
      g_m15BullStartPrice > 0 && g_m15BullEndPrice > 0)
   {
      ObjectCreate(0, "AI_M15_BULL_TL", OBJ_TREND, 0,
                   g_m15BullStartTime, g_m15BullStartPrice,
                   g_m15BullEndTime,   g_m15BullEndPrice);
      ObjectSetInteger(0, "AI_M15_BULL_TL", OBJPROP_COLOR, clrDarkOliveGreen);
      ObjectSetInteger(0, "AI_M15_BULL_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_M15_BULL_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Trendline baissière M15
   if(g_m15BearStartTime > 0 && g_m15BearEndTime > 0 &&
      g_m15BearStartPrice > 0 && g_m15BearEndPrice > 0)
   {
      ObjectCreate(0, "AI_M15_BEAR_TL", OBJ_TREND, 0,
                   g_m15BearStartTime, g_m15BearStartPrice,
                   g_m15BearEndTime,   g_m15BearEndPrice);
      ObjectSetInteger(0, "AI_M15_BEAR_TL", OBJPROP_COLOR, clrFireBrick);
      ObjectSetInteger(0, "AI_M15_BEAR_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_M15_BEAR_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Tête de la figure ETE (si présente)
   if(g_h1ETEFound && g_h1ETEHeadTime > 0 && g_h1ETEHeadPrice > 0)
   {
      ObjectCreate(0, "AI_H1_ETE_HEAD", OBJ_ARROW_DOWN, 0,
                   g_h1ETEHeadTime, g_h1ETEHeadPrice);
      ObjectSetInteger(0, "AI_H1_ETE_HEAD", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "AI_H1_ETE_HEAD", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_H1_ETE_HEAD", OBJPROP_ARROWCODE, 234);
   }
}

void AI_UpdateAnalysis()
{
   if(!AI_DrawH1Structure)
      return;
   
   datetime now = TimeCurrent();
   if(now - g_lastAIAnalysisTime < AI_AnalysisIntervalSec)
      return;

   g_lastAIAnalysisTime = now;

   // Appeler le serveur IA pour obtenir les données Fibonacci et structure H1
   if(UseAI_Agent && StringLen(AI_AnalysisURL) > 0)
   {
      string payload = "";
      string resp = "";
      string headers = "Content-Type: application/json\r\n";
      
      // Préparer les données pour l'analyse
      payload = "{";
      payload += "\"symbol\":\"" + _Symbol + "\",";
      payload += "\"timeframe\":\"H1\",";
      payload += "\"request_type\":\"fibonacci_analysis\"";
      payload += "}";
      
      // Appel WebRequest au serveur IA
      int timeout = 5000; // 5 secondes timeout
      char data[];
      char result_data[];
      StringToCharArray(payload, data);
      
      ResetLastError();
      int result = WebRequest("POST", AI_AnalysisURL, headers, timeout, data, result_data, headers);
      
      // Convertir la réponse en string
      if(result == 200)
      {
         resp = CharArrayToString(result_data);
      }
      
      if(result == 200)
      {
         // Parser la réponse JSON pour extraire les données Fibonacci
         ParseAndDrawFibonacciFromResponse(resp);
      }
      else
      {
         Print("Erreur appel AI Analysis: ", result, " - ", GetLastError());
         // En cas d'erreur, utiliser l'analyse locale
         PerformLocalAnalysis();
      }
   }
   else
   {
      // Utiliser l'analyse locale si le serveur IA n'est pas disponible
      PerformLocalAnalysis();
   }
}

// Fonction pour parser la réponse JSON et dessiner les Fibonacci
void ParseAndDrawFibonacciFromResponse(string resp)
{
   // Parser les niveaux Fibonacci de la réponse
   string fibLevels[] = {"fib_0", "fib_236", "fib_382", "fib_500", "fib_618", "fib_786", "fib_1000"};
   double fibValues[7];
   
   for(int i = 0; i < 7; i++)
   {
      int pos = StringFind(resp, "\"" + fibLevels[i] + "\"");
      if(pos >= 0)
      {
         int colon = StringFind(resp, ":", pos);
         if(colon > 0)
         {
            int endPos = StringFind(resp, ",", colon);
            if(endPos < 0) endPos = StringFind(resp, "}", colon);
            if(endPos > colon)
            {
               string valueStr = StringSubstr(resp, colon + 1, endPos - colon - 1);
               fibValues[i] = StringToDouble(valueStr);
            }
         }
      }
   }
   
   // Dessiner les niveaux Fibonacci sur le graphique
   DrawFibonacciLevels(fibValues);
   
   // Parser et dessiner les trendlines si présentes
   ParseTrendlinesFromResponse(resp);
}

// Fonction pour dessiner les niveaux Fibonacci
void DrawFibonacciLevels(double &fibValues[])
{
   string fibPrefix = "FIB_";
   
   // Supprimer anciens objets Fibonacci
   ObjectsDeleteAll(0, fibPrefix);
   
   // Créer les lignes horizontales pour chaque niveau Fibonacci
   string fibNames[] = {"0.0%", "23.6%", "38.2%", "50.0%", "61.8%", "78.6%", "100.0%"};
   color fibColors[] = {clrGray, clrCyan, clrBlue, clrPurple, clrOrange, clrYellow, clrRed};
   
   datetime time1 = TimeCurrent() - (datetime)Period() * 60 * 50; // 50 périodes en arrière
   datetime time2 = TimeCurrent() + (datetime)Period() * 60 * 10; // 10 périodes en avant
   
   for(int i = 0; i < 7; i++)
   {
      if(fibValues[i] > 0)
      {
         string objName = fibPrefix + (string)StringReplace(fibNames[i], ".", "_");
         if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, fibValues[i]))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, fibColors[i]);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetString(0, objName, OBJPROP_TEXT, fibNames[i]);
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            
            // Ajouter un label
            string labelName = objName + "_LABEL";
            if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time1, fibValues[i]))
            {
               ObjectSetString(0, labelName, OBJPROP_TEXT, "Fib " + fibNames[i]);
               ObjectSetInteger(0, labelName, OBJPROP_COLOR, fibColors[i]);
               ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            }
         }
      }
   }
}

// Fonction pour parser les trendlines de la réponse
void ParseTrendlinesFromResponse(string resp)
{
   // Parser trendline haussière
   int bullTLPos = StringFind(resp, "\"bull_trendline\"");
   if(bullTLPos >= 0)
   {
      // Extraire les points de la trendline haussière
      ExtractAndDrawTrendline(resp, bullTLPos, true);
   }
   
   // Parser trendline baissière  
   int bearTLPos = StringFind(resp, "\"bear_trendline\"");
   if(bearTLPos >= 0)
   {
      ExtractAndDrawTrendline(resp, bearTLPos, false);
   }
}

// Fonction pour extraire et dessiner une trendline
void ExtractAndDrawTrendline(string resp, int startPos, bool isBull)
{
   string prefix = isBull ? "BULL_TL" : "BEAR_TL";
   color tlColor = isBull ? clrLime : clrRed;
   
   // Parser les 4 points (time1, price1, time2, price2)
   double points[4];
   string pointNames[] = {"\"time1\"", "\"price1\"", "\"time2\"", "\"price2\""};
   
   for(int i = 0; i < 4; i++)
   {
      int pos = StringFind(resp, pointNames[i], startPos);
      if(pos >= 0)
      {
         int colon = StringFind(resp, ":", pos);
         if(colon > 0)
         {
            int endPos = StringFind(resp, ",", colon);
            if(endPos < 0) endPos = StringFind(resp, "}", colon);
            if(endPos > colon)
            {
               string valueStr = StringSubstr(resp, colon + 1, endPos - colon - 1);
               points[i] = StringToDouble(valueStr);
            }
         }
      }
   }
   
   // Dessiner la trendline
   string tlName = "AI_" + prefix;
   if(ObjectCreate(0, tlName, OBJ_TREND, 0, (datetime)points[0], points[1], (datetime)points[2], points[3]))
   {
      ObjectSetInteger(0, tlName, OBJPROP_COLOR, tlColor);
      ObjectSetInteger(0, tlName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, tlName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, tlName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }
}

// Fonction d'analyse locale (fallback)
void PerformLocalAnalysis()
{
   // Récupérer les données H1 locales
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_H1, 0, 400, rates);
   if(copied <= 0)
      return;

   ArraySetAsSeries(rates, false); // 0 = plus ancien

   // Détecter les swings H1
   H1SwingPoint swings[];
   int total = 0;

   int lookback   = 3;  // fenêtre de détection des swings (peut être ajustée)
   int minSpacing = 3;  // espacement minimum entre deux swings
   if(lookback < 1) lookback = 1;
   if(minSpacing < 1) minSpacing = 1;

   for(int i = lookback; i < copied - lookback; i++)
   {
      double hi = rates[i].high;
      double lo = rates[i].low;

      bool isHigh = true;
      bool isLow  = true;

      for(int j = i - lookback; j <= i + lookback; j++)
      {
         if(j == i) continue;
         if(rates[j].high >= hi) isHigh = false;
         if(rates[j].low  <= lo) isLow  = false;
         if(!isHigh && !isLow) break;
      }

      if(isHigh || isLow)
      {
         if(total > 0 && (i - swings[total-1].index) < minSpacing)
            continue;

         H1SwingPoint sp;
         sp.index  = i;
         sp.time   = rates[i].time;
         sp.price  = isHigh ? hi : lo;
         sp.isHigh = isHigh;

         ArrayResize(swings, total + 1);
         swings[total] = sp;
         total++;
      }
   }

   // Réinitialiser structure H1
   g_h1BullStartPrice = g_h1BullEndPrice = 0.0;
   g_h1BullStartTime  = g_h1BullEndTime  = 0;
   g_h1BearStartPrice = g_h1BearEndPrice = 0.0;
   g_h1BearStartTime  = g_h1BearEndTime  = 0;

   // Trendline haussière (deux derniers creux ascendants)
   H1SwingPoint lows[];
   int lowCount = 0;
   for(int k = 0; k < total; k++)
   {
      if(!swings[k].isHigh)
      {
         ArrayResize(lows, lowCount + 1);
         lows[lowCount] = swings[k];
         lowCount++;
      }
   }
   if(lowCount >= 2)
   {
      H1SwingPoint l1 = lows[lowCount-2];
      H1SwingPoint l2 = lows[lowCount-1];
      if(l2.price > l1.price)
      {
         g_h1BullStartPrice = l1.price;
         g_h1BullEndPrice   = l2.price;
         g_h1BullStartTime  = l1.time;
         g_h1BullEndTime    = l2.time;
      }
   }

   // Trendline baissière (deux derniers sommets descendants)
   H1SwingPoint highs[];
   int highCount = 0;
   for(int k = 0; k < total; k++)
   {
      if(swings[k].isHigh)
      {
         ArrayResize(highs, highCount + 1);
         highs[highCount] = swings[k];
         highCount++;
      }
   }
   if(highCount >= 2)
   {
      H1SwingPoint h1 = highs[highCount-2];
      H1SwingPoint h2 = highs[highCount-1];
      if(h2.price < h1.price)
      {
         g_h1BearStartPrice = h1.price;
         g_h1BearEndPrice   = h2.price;
         g_h1BearStartTime  = h1.time;
         g_h1BearEndTime    = h2.time;
      }
   }

   // Calculer et dessiner les niveaux Fibonacci locaux
   CalculateAndDrawLocalFibonacci(rates, swings, total);

   // Appeler la fonction de dessin existante
   DrawH1Structure();
}

// Fonction pour calculer et dessiner les Fibonacci locaux
void CalculateAndDrawLocalFibonacci(MqlRates &rates[], H1SwingPoint &swings[], int total)
{
   if(total < 2) return;
   
   // Trouver le dernier swing significatif (haut ou bas)
   H1SwingPoint lastSwing = swings[total-1];
   H1SwingPoint prevSwing = swings[total-2];
   
   double highPrice = MathMax(lastSwing.price, prevSwing.price);
   double lowPrice = MathMin(lastSwing.price, prevSwing.price);
   
   // Calculer les niveaux Fibonacci
   double fib0 = lowPrice;
   double fib100 = highPrice;
   double diff = fib100 - fib0;
   
   double fib236 = fib0 + diff * 0.236;
   double fib382 = fib0 + diff * 0.382;
   double fib500 = fib0 + diff * 0.500;
   double fib618 = fib0 + diff * 0.618;
   double fib786 = fib0 + diff * 0.786;
   
   double fibValues[7] = {fib0, fib236, fib382, fib500, fib618, fib786, fib100};
   
   // Dessiner les niveaux
   DrawFibonacciLevels(fibValues);
}

//+------------------------------------------------------------------+
//| Fonction DrawH1Structure existante déjà plus haut dans le code    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Autres fonctions existantes                                       |
//+------------------------------------------------------------------+

// -------------------------------------------------------------------
// IA : Affichage dans un panneau séparé (BAS À DROITE, 3 lignes max)
// -------------------------------------------------------------------
void DrawAIRecommendation(string action, double confidence, string reason, double price)
{
   // Nom unique par symbole pour éviter les collisions entre graphiques
   string panelName = "AI_PANEL_MAIN_" + _Symbol;
   
   // Supprimer l'ancien panneau s'il existe
   ObjectDelete(0, panelName);
   
   // Créer un label fixe en bas à droite (coordonnées écran)
   if(!ObjectCreate(0, panelName, OBJ_LABEL, 0, 0, 0))
      return;
   
   // Positionner en bas à droite (X=20, Y=50 pixels depuis le bord)
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, (long)20);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, (long)50);
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, (long)CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, panelName, OBJPROP_ANCHOR, (long)ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, (long)false);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTED, (long)false);
   ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, (long)true);
   ObjectSetInteger(0, panelName, OBJPROP_ZORDER, (long)0);
   ObjectSetInteger(0, panelName, OBJPROP_FONTSIZE, (long)16); // Taille plus grande
   ObjectSetString(0, panelName, OBJPROP_FONT, "Arial Bold");
   
   // Couleur selon l'action
   color clr = clrWhite;
   if(action == "buy")  clr = clrLime;
   if(action == "sell") clr = clrRed;
   if(action == "hold") clr = clrSilver;
   
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clr);
   
   // Construire le texte du panneau (3 lignes max, message clair)
   string actionUpper = action;
   StringToUpper(actionUpper);
   
   string txt = "";
   if(action == "buy")
      txt += "🤖 IA " + _Symbol + ": ACHAT " + DoubleToString(confidence * 100.0, 0) + "%\n";
   else if(action == "sell")
      txt += "🤖 IA " + _Symbol + ": VENTE " + DoubleToString(confidence * 100.0, 0) + "%\n";
   else
      txt += "🤖 IA " + _Symbol + ": ATTENTE\n";
   
   // Ligne 2: Confiance
   if(confidence > 0.0)
      txt += "Confiance: " + DoubleToString(confidence * 100.0, 1) + "%\n";
   else
      txt += "Analyse en cours...\n";
   
   // Ligne 3: Raison (limitée à 40 caractères)
   if(StringLen(reason) > 0)
   {
      string shortReason = reason;
      if(StringLen(shortReason) > 40)
         shortReason = StringSubstr(shortReason, 0, 37) + "...";
      txt += shortReason;
   }
   else
      txt += "En attente de signal";
   
   ObjectSetString(0, panelName, OBJPROP_TEXT, txt);
}

// Affiche un label d'information quand un signal IA est bloqué par la validation
void DrawAIBlockLabel(string symbol, string title, string reason)
{
   string name = "AI_BLOCK_LABEL_" + symbol;
   ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return;

   string txt = title + " (" + symbol + ")\n" + reason;
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (long)10);
   ObjectSetInteger(0, name, OBJPROP_CORNER, (long)CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (long)10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, (long)40);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, (long)false);
   ObjectSetInteger(0, name, OBJPROP_BACK, (long)true);
}
// -------------------------------------------------------------------
// Tableau de bord serveur IA (affichage continu des données renvoyées)
// -------------------------------------------------------------------
void DrawServerDashboard()
{
   string panelName = "AI_SERVER_DASH_" + _Symbol;
   string textName  = panelName + "_TXT";

   // Créer le conteneur si absent
   if(ObjectFind(0, panelName) < 0)
   {
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 50);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 320);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 90);
      ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, panelName, OBJPROP_BACK, true);
      ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   }

   // Construire le texte avec les dernières données serveur
   string action = (g_lastAIAction == "") ? "hold" : g_lastAIAction;
   string actionLabel = (action == "buy") ? "ACHAT" : (action == "sell" ? "VENTE" : "ATTENTE");
   color actionColor = (action == "buy") ? clrLime : (action == "sell" ? clrRed : clrSilver);

   string reason = g_lastAIReason;
   if(StringLen(reason) > 70) reason = StringSubstr(reason, 0, 67) + "...";

   string spike = "";
   if(g_aiSpikePredicted && g_lastAIConfidence > 0)
   {
      spike = StringFormat("\n📈 Spike prévu: %s @ %.2f (Confiance: %.0f%%)",
                           g_aiSpikeDirection ? "ACHAT" : "VENTE",
                           g_aiSpikeZonePrice,
                           g_lastAIConfidence * 100.0);
   }
   else
   {
      spike = "Spike: n/a";
   }

   string updated = (g_lastAITime > 0) ? TimeToString(g_lastAITime, TIME_DATE|TIME_SECONDS) : "n/a";

   // Aperçu JSON (brut) renvoyé par le serveur IA pour ce symbole
   string jsonPreview = g_lastAIJson;
   if(StringLen(jsonPreview) > 180)
      jsonPreview = StringSubstr(jsonPreview, 0, 177) + "...";

   string txt = StringFormat("Action: %s   Conf: %.0f%%\nRaison: %s\n%s\nMaj: %s\nJSON: %s",
                             actionLabel,
                             g_lastAIConfidence * 100.0,
                             reason,
                             spike,
                             updated,
                             jsonPreview);

   // Créer / mettre à jour le label texte
   if(ObjectFind(0, textName) < 0)
      ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);

   ObjectSetString(0, textName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, actionColor);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, 55);
   ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
}
// -------------------------------------------------------------------
// IA : Calcul multiplicateur de lot basé sur la confiance IA
// -------------------------------------------------------------------
double AI_GetLotMultiplier(ENUM_ORDER_TYPE type, int aiAction, double aiConfidence)
{
   if(!UseAI_Agent || aiConfidence < AI_MinConfidence)
      return 1.0; // Pas d'influence si confiance trop faible
   
   // Si l'IA est d'accord avec la direction
   bool aiAgrees = ((type == ORDER_TYPE_BUY && aiAction > 0) || 
                    (type == ORDER_TYPE_SELL && aiAction < 0));
   
   if(aiAgrees)
   {
      // Augmenter le lot selon la confiance (max 1.5x si confiance = 1.0)
      return 0.5 + (aiConfidence * 1.0); // 0.5 à 1.5
   }
   else
   {
      // Réduire le lot si l'IA n'est pas d'accord (min 0.3x)
      return 0.3 + ((1.0 - aiConfidence) * 0.2); // 0.3 à 0.5
   }
}

// -------------------------------------------------------------------
// IA : Envoyer notification push MT5 pour signal consolidé
// -------------------------------------------------------------------
void AI_SendNotification(string signalType, string direction, double confidence, string reason)
{
   if(!AI_UseNotifications) return;
   
   // Vérifier si on a déjà envoyé cette notification récemment (anti-spam)
   static datetime lastNotifTime = 0;
   static string lastNotif = "";
   string currentNotif = signalType + "_" + direction + "_" + DoubleToString(confidence, 2);
   
   if(TimeCurrent() - lastNotifTime < 300 && lastNotif == currentNotif) // 5 minutes entre notifications identiques
      return;
   
   // Construire le message de notification
   string msg = "";
   string spikeProb = "";
   
   // Calculer la probabilité de spike si disponible
   if(g_aiSpikePredicted && g_lastAIConfidence > 0)
   {
      spikeProb = StringFormat("\n📈 Probabilité de spike: %.1f%%", g_lastAIConfidence * 100.0);
   }
   
   if(signalType == "IA_SIGNAL")
   {
      msg = StringFormat("🚀 SIGNAL %s - %s\nConfiance: %.1f%%%s\n%s", 
                        _Symbol, direction, confidence * 100.0, spikeProb, reason);
   }
   else if(signalType == "AUTO_M1")
   {
      msg = StringFormat("⚡ %s - %s (M1)\nConfiance: %.1f%%%s\n%s", 
                        _Symbol, direction, confidence * 100.0, spikeProb, reason);
   }
   else if(signalType == "RSI_TREND_BUY" || signalType == "RSI_TREND_SELL")
   {
      string type = (signalType == "RSI_TREND_BUY") ? "RSI ACHAT" : "RSI VENTE";
      msg = StringFormat("📊 %s - %s\nConfiance: %.1f%%%s\n%s", 
                        _Symbol, type, confidence * 100.0, spikeProb, reason);
   }
   else if(signalType == "SPIKE_DETECTED")
   {
      msg = StringFormat("🚨 SPIKE DÉTECTÉ - %s\nProbabilité: %.1f%%\n%s", 
                        direction, confidence * 100.0, reason);
   }
   
   if(msg == "") return; // Type de signal non géré
   
   // Envoyer notification push MT5 (apparaît dans les notifications du terminal)
   SendNotification(msg);
   Print("📱 NOTIFICATION PUSH MT5: ", msg);
   
   g_lastNotificationTime = TimeCurrent();
   g_lastNotificationSignal = signalType;
   lastNotifTime = TimeCurrent();
   lastNotif = currentNotif;
}

// -------------------------------------------------------------------
// IA : Affichage des prédictions de spike (une seule flèche qui se met à jour)
// -------------------------------------------------------------------
void DrawSpikePrediction(double price, bool isUp)
{
   if(!AI_PredictSpikes || price <= 0) 
   {
      // Si désactivé ou prix invalide, supprimer la flèche existante
      ObjectDelete(0, "AI_SPIKE_PREDICTION");
      g_aiSpikePredicted = false;
      g_aiSpikeExecuted  = false;
      g_aiSpikePendingPlaced = false;
      return;
   }
   
   // Créer ou mettre à jour la flèche existante
   if(ObjectFind(0, "AI_SPIKE_PREDICTION") < 0)
   {
      if(!ObjectCreate(0, "AI_SPIKE_PREDICTION", OBJ_ARROW, 0, TimeCurrent(), price))
      {
         Print("Erreur création flèche prédiction: ", GetLastError());
         return;
      }
   }
   else
   {
      ObjectMove(0, "AI_SPIKE_PREDICTION", 0, TimeCurrent(), price);
   }

   // Style de la flèche
   int arrowCode = isUp ? 233 : 234; // Flèche vers le haut ou vers le bas
   color arrowColor = isUp ? clrLime : clrRed;
   
   // Mettre à jour les propriétés de l'objet
   string objName = "AI_SPIKE_PREDICTION";
   
   // Vérifier si l'objet existe, sinon le créer
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), price);
   }
   
   // Mettre à jour les propriétés
   ObjectMove(0, objName, 0, TimeCurrent(), price);
   ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   
   // Mettre à jour les variables globales
   g_aiSpikePredicted = true;
   g_aiSpikeZonePrice = price;
   g_aiSpikeDirection = isUp;
   g_aiSpikePredictionTime = TimeCurrent();
   g_aiSpikeExecuted  = false;
   g_aiSpikeExecTime  = 0;
   g_aiSpikePendingPlaced = false;
   
   // Forcer le rafraîchissement du graphique
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Affiche la flèche clignotante de spike prédit et exécute le trade|
//+------------------------------------------------------------------+
void DisplaySpikeAlert()
{
   // Ne gérer les spikes automatiquement que sur les indices Boom/Crash et en M1
   if(Period() != PERIOD_M1)
      return;

   // Cooldown après plusieurs tentatives ratées : ignorer les nouveaux signaux
   if(g_spikeCooldownUntil > 0 && TimeCurrent() < g_spikeCooldownUntil)
      return;

   // Déterminer le type de spike selon le symbole
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);

   // Vérifier les signaux de spike depuis les zones SMC_OB
   double smcSpikePrice = 0.0;
   bool smcIsBuySpike = false;
   double smcConfidence = 0.0;
   
   // Détecter un spike basé sur les zones SMC_OB
   bool smcSpikeDetected = PredictSpikeFromSMCOB(smcSpikePrice, smcIsBuySpike, smcConfidence);
   
   // Si un spike est détecté avec une bonne confiance, l'utiliser
   if(smcSpikeDetected && smcConfidence >= 0.7)
   {
      isBoom = smcIsBuySpike;
      double spikePrice = smcSpikePrice;
      g_aiStrongSpike = true; // Marquer comme un spike fort
      g_aiSpikeZonePrice = spikePrice;
      g_aiSpikeDetectedTime = TimeCurrent();
      
      Print("🔍 Détection SMC_OB: Spike ", (isBoom ? "hausier" : "baissier"), 
            " détecté à ", DoubleToString(spikePrice, _Digits), 
            " - Confiance: ", DoubleToString(smcConfidence * 100, 1), "%");
   }
   
   // Si c'est un symbole Boom/Crash, vérifier les signaux de spike
   if((isBoom || isCrash) && g_aiStrongSpike)
   {
      // Déclarer les variables de prix une seule fois au début
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // Cooldown anti-mitraillage: pas de nouvelle exécution si une tentative a eu lieu récemment,
      // sauf s'il n'y a AUCUNE position ouverte (on veut alors absolument saisir l'opportunité).
      if(g_lastSpikeBlockTime > 0 && (TimeCurrent() - g_lastSpikeBlockTime) < 120) // 2 minutes
      {
         if(CountAllPositionsForMagic() > 0)
         return;
      }
   
      bool isBuySpike = false;
   
      if(isBoom)
      {
         isBuySpike = true;
      }
      else if(isCrash)
      {
         isBuySpike = false;
      }
      // Règle stricte: BUY uniquement sur Boom, SELL uniquement sur Crash
      
      // Utiliser le prix de la zone de spike ou le prix actuel
      double spikePrice = (g_aiSpikeZonePrice > 0.0) ? g_aiSpikeZonePrice : 
                         ((isBuySpike) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
      
      // Créer ou mettre à jour la flèche clignotante sur le graphique
      string arrowName = "SPIKE_ARROW_" + _Symbol;
      
      if(ObjectFind(0, arrowName) < 0)
      {
         ObjectCreate(0, arrowName, OBJ_ARROW, 0, TimeCurrent(), spikePrice);
      }
      else
      {
         ObjectMove(0, arrowName, 0, TimeCurrent(), spikePrice);
      }
   
      // Propriétés de la flèche
      int arrowCode = isBuySpike ? 233 : 234; // Flèche vers le haut ou vers le bas
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuySpike ? clrLime : clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   
      // Envoyer une notification + bip sonore à la première apparition de la flèche
      if(TimeCurrent() - g_lastSpikeAlertNotifTime > 5)
      {
         g_lastSpikeAlertNotifTime = TimeCurrent();
         string dirText = isBuySpike ? "BUY (spike haussier)" : "SELL (spike baissier)";
         string msg = StringFormat("ALERTE SPIKE %s\nSymbole: %s\nDirection: %s\nZone: %.5f\nAction: Préparez-vous, exécution auto du trade.",
                                   (isBuySpike ? "BOOM" : "CRASH"), _Symbol, dirText, spikePrice);
         SendNotification(msg);
         PlaySound("alert.wav");
      }

      // Définir l'heure d'entrée pré-spike (30 secondes AVANT le spike estimé pour déclencher l'alerte)
      // L'alerte se déclenche immédiatement, le trade s'exécute après le délai
      if(g_spikeEntryTime == 0)
      {
         g_spikeEntryTime = TimeCurrent() + SpikePreEntrySeconds; // 30 secondes avant le spike
         g_aiSpikeDetectedTime = TimeCurrent(); // Marquer le moment de détection pour le countdown
         Print("🚨 SPIKE DÉTECTÉ: Alerte déclenchée ", SpikePreEntrySeconds, " secondes avant le spike estimé");
      }
   
      // Exécuter automatiquement le trade uniquement sur spike "fort" (spike_prediction),
      // pas sur simple pré‑alerte early_spike_warning.
      if(!g_aiStrongSpike)
         return;
      
      // Exécuter automatiquement le trade si pas encore fait,
      // TOUJOURS après le délai défini (30 secondes après détection = au moment du spike estimé)
      // Le trade se déclenche immédiatement si le délai est déjà passé (alerte tardive)
      bool timeToExecute = (g_spikeEntryTime > 0 && TimeCurrent() >= g_spikeEntryTime);
      if(!g_aiSpikeExecuted && timeToExecute)
      {
         // Récupérer les données nécessaires
         double atr[];
         if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0)
         {
            double price = isBuySpike ? ask : bid;
         
            ENUM_ORDER_TYPE orderType = isBuySpike ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            string comment = "SPIKE_" + (isBuySpike ? "BUY" : "SELL");

            // Sécurité Boom/Crash: fermer toute position existante sur ce symbole,
            // même avec un petit gain (par ex. 0.20$), puis appliquer conditions minimales.
            if(CountPositionsForSymbolMagic() > 0)
               CloseAllPositionsForSymbolMagic();

            // Conditions minimales (heure, drawdown, spread)
            if(!IsTradingTimeAllowed())
            {
               ClearSpikeSignal();
               return;
            }
            if(IsDrawdownExceeded())
            {
               ClearSpikeSignal();
               return;
            }
            double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
            if(spread > MaxSpreadPoints * _Point)
            {
               ClearSpikeSignal();
               return;
            }

            // Vérifier l'accord de l'IA si disponible (mais ne pas bloquer si pas de réponse)
            // Pour les spikes, on privilégie l'exécution automatique
            if(UseAI_Agent && g_lastAIAction != "")
            {
               string act = g_lastAIAction;
               StringToUpper(act);
               bool aiAgree = false;
               if(isBuySpike && (act == "BUY" || act == "ACHAT"))
                  aiAgree = true;
               if(!isBuySpike && (act == "SELL" || act == "VENTE"))
                  aiAgree = true;
               
               // Si l'IA est en désaccord total (direction opposée), on peut toujours exécuter
               // mais on log un avertissement. On bloque seulement si confiance très faible.
               if(!aiAgree)
               {
                  Print("⚠️ ATTENTION: Spike ", (isBuySpike ? "BUY" : "SELL"), " mais IA suggère ", g_lastAIAction, " - Exécution quand même");
               }
               
               // Bloquer seulement si confiance très faible (< 50%) ET désaccord
               if(!aiAgree && g_lastAIConfidence < 0.5)
               {
                  Print("❌ Spike bloqué: IA fortement en désaccord (", g_lastAIAction, " conf=", g_lastAIConfidence, ")");
                  ClearSpikeSignal();
                  return;
               }
            }

            // Si une zone de spike est connue, placer un LIMIT pré-spike pour être en position avant l'explosion
            bool placedPending = false;
            double slDist = 0.0, tpDist = 0.0;
            if(!g_aiSpikePendingPlaced && g_aiSpikeZonePrice > 0.0 && CountAllPendingOrdersForMagic() < 3)
            {
               double spikePrice = NormalizeDouble(g_aiSpikeZonePrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
               double sl = 0.0, tp = 0.0;

               // SL/TP basés sur l'ATR avec ratio 20% SL / 80% TP pour le pending pré-spike
               double baseRange = (atr[0] > 0.0) ? atr[0] : 20 * _Point;
               slDist = baseRange * 0.2;  // 20% risque
               tpDist = baseRange * 0.8;  // 80% profit
               if(isBuySpike)
               {
                  sl = spikePrice - slDist;
                  tp = spikePrice + tpDist;
               }
               else
               {
                  sl = spikePrice + slDist;
                  tp = spikePrice - tpDist;
               }

               long stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
               double minStopDistance = stopLevelPoints * _Point;
               double cur = isBuySpike ? ask : bid;
               
               // Ajuster le prix LIMIT : pour un BUY_LIMIT, le prix doit être sous le marché ;
               // pour un SELL_LIMIT, au-dessus. On force également la distance mini broker.
               if(isBuySpike)
               {
                  // BUY_LIMIT sous le prix actuel
                  if(cur - spikePrice < minStopDistance || spikePrice >= cur)
                     spikePrice = cur - minStopDistance;
               }
               else
               {
                  // SELL_LIMIT au-dessus du prix actuel
                  if(spikePrice - cur < minStopDistance || spikePrice <= cur)
                     spikePrice = cur + minStopDistance;
               }

               // Vérification Step Index / Boom 300 : contraintes particulières de stops
               double spikeLot = CalculateLot(atr[0]);
               bool isStepIndexSpike = (StringFind(_Symbol, "Step Index") != -1);
               bool isBoom300Spike   = (StringFind(_Symbol, "Boom 300") != -1);

               if(isStepIndexSpike && spikeLot > 0.1)
               {
                  Print("⚠️ Ordre limit spike bloqué pour Step Index : lot calculé (", DoubleToString(spikeLot, 2), ") dépasse le maximum autorisé (0.1)");
                  ClearSpikeSignal();
                  return; // Bloquer l'ordre limit
               }
               
               if(spikeLot <= 0.0)
               {
                  Print("⚠️ Ordre limit spike bloqué : lot invalide (", DoubleToString(spikeLot, 2), ")");
                  ClearSpikeSignal();
                  return; // Bloquer l'ordre limit
               }

               // Pour Boom 300 : certains brokers refusent SL/TP sur pending -> ouvrir SANS SL/TP
               if(isBoom300Spike)
               {
                  sl = 0.0;
                  tp = 0.0;
               }
               else
               {
                  // VALIDATION FINALE pour ordres limit de spike : Vérifier et ajuster les SL/TP
                  ENUM_ORDER_TYPE spikeLimitType = isBuySpike ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
                  double executionPrice = spikePrice; // Créer une copie pour la validation
                  double slCopy = sl; // Créer des copies pour la validation
                  double tpCopy = tp; // car les paramètres sont passés par référence
                  if(!ValidateAndAdjustStops(_Symbol, spikeLimitType, executionPrice, slCopy, tpCopy))
                  {
                     sl = slCopy; // Mettre à jour les valeurs après validation
                     tp = tpCopy;
                     Print("⚠️ Erreur de validation des stops pour ordre limit spike sur ", _Symbol);
                     ClearSpikeSignal();
                     return; // Bloquer l'ordre limit
                  }
               }

               bool ok = (isBuySpike)
                  ? trade.BuyLimit(spikeLot, spikePrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment + "_LIMIT")
                  : trade.SellLimit(spikeLot, spikePrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment + "_LIMIT");

               if(ok)
               {
                  placedPending = true;
                  g_aiSpikePendingPlaced = true;
                  g_lastSpikeBlockTime = TimeCurrent(); // éviter double placement immédiat
                  Print("🟡 Ordre LIMIT pré-spike placé: ", (isBuySpike ? "BUY_LIMIT" : "SELL_LIMIT"), " @", DoubleToString(spikePrice, _Digits));
               }
               else
               {
                  Print("❌ Échec placement ordre LIMIT pré-spike: ", trade.ResultRetcode());
                  ClearSpikeSignal();
                  return;
               }
         }

         // Si pas de pending placé, fallback exécution marché immédiate
         if(!placedPending)
         {
            // Calculer le lot en fonction de l'ATR et du multiplicateur
            double lotSize = CalculateLot(atr[0]);
            if(ExecuteTrade(orderType, lotSize, 0.0, 0.0, comment, false, false, true))
            {
               g_aiSpikeExecuted = true;
               g_aiSpikeExecTime = TimeCurrent();
               g_lastSpikeBlockTime = TimeCurrent(); // démarrer cooldown
               // On garde g_aiSpikePredicted = true pour permettre à UpdateSpikeAlertDisplay
               // de détecter le spike et de clôturer automatiquement la position.
               g_aiSpikePendingPlaced = false;
               Print("✅ TRADE SPIKE EXÉCUTÉ: ", (isBuySpike ? "BUY" : "SELL"), " à ", DoubleToString(price, _Digits));
               // Message explicite SPIKEPREDIT
               Comment("SPIKEPREDIT ", (isBuySpike ? "BUY" : "SELL"), " ", _Symbol);
            }
            else
            {
               Print("❌ Échec exécution trade spike: ", GetLastError());
               ClearSpikeSignal();
            }
         }
      }
   }
   
   Print("🔔 FLÈCHE SPIKE PRÉDIT: ", (isBuySpike ? "BUY" : "SELL"), " sur ", _Symbol, " - Zone: ", DoubleToString(spikePrice, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Ferme les positions excédentaires (plus de 2 positions)          |
//+------------------------------------------------------------------+
void CloseExcessPositions()
{
   int totalPositions = 0;
   int positionsToClose = 0;
   ulong tickets[];
   
   // Compter les positions et collecter les tickets
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         totalPositions++;
         if(totalPositions > 2) // Si on dépasse 2 positions
         {
            int size = ArraySize(tickets);
            ArrayResize(tickets, size + 1);
            tickets[size] = ticket;
            positionsToClose++;
         }
      }
   }
   
   // Fermer les positions excédentaires (les plus anciennes en premier)
   if(positionsToClose > 0)
   {
      Print("⚠️ Fermeture de ", positionsToClose, " positions excédentaires (limite de 2 positions)");
      for(int i = 0; i < positionsToClose; i++)
      {
         if(PositionSelectByTicket(tickets[i]))
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double volume = PositionGetDouble(POSITION_VOLUME);
            Print("Fermeture position excédentaire #", tickets[i], " sur ", symbol, " (volume: ", volume, ")");
            trade.PositionClose(tickets[i]);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Compte le nombre de positions ouvertes pour ce robot (tous symboles) |
//+------------------------------------------------------------------+
int CountOpenForexPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         count++;
      }
   }
   
   // Si on dépasse 2 positions, déclencher le nettoyage
   if(count > 2)
   {
      CloseExcessPositions();
      return 2; // Retourne la limite maximale
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Vérifie si le prix est dans une zone SMC_OB                       |
//+------------------------------------------------------------------+
bool IsInSMCOBZone(double price, double &zoneStrength, bool &isBuyZone, double &zoneWidth)
{
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      if(!g_smcZones[i].isActive) continue;
      
      double zoneHigh = g_smcZones[i].price * (1 + g_smcZones[i].width);
      double zoneLow = g_smcZones[i].price * (1 - g_smcZones[i].width);
      
      if(price >= zoneLow && price <= zoneHigh)
      {
         zoneStrength = g_smcZones[i].strength;
         isBuyZone = g_smcZones[i].isBuyZone;
         zoneWidth = g_smcZones[i].width;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie les zones SMC/OB pour détecter un spike                  |
//+------------------------------------------------------------------+
bool SMC_OB_CheckZones(double currentPrice, bool &isBuySpike, double &confidence)
{
   double zoneStrength = 0.0;
   double zoneWidth = 0.0;
   bool isBuyZone = false;
   
   if(IsInSMCOBZone(currentPrice, zoneStrength, isBuyZone, zoneWidth))
   {
      isBuySpike = isBuyZone;
      confidence = zoneStrength;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Détecte et met à jour les zones SMC_OB                           |
//+------------------------------------------------------------------+
void UpdateSMCOBZones()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 60) // Mettre à jour toutes les minutes
      return;
      
   lastUpdate = TimeCurrent();
   
   // Réinitialiser le compteur de zones
   g_smcZonesCount = 0;
   
   // Obtenir les données des bougies
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, rates);
   if(copied <= 0) return;
   
   // Détecter les zones SMC_OB (Order Blocks)
   for(int i = SMC_OB_MinCandles; i < copied - SMC_OB_MinCandles; i++)
   {
      // Vérifier si c'est un bloc d'achat (bearish candle suivie de bougies haussières)
      if(rates[i].close < rates[i].open) // Bearish candle
      {
         bool isBuyZone = true;
         for(int j = 1; j <= SMC_OB_MinCandles; j++)
         {
            if(rates[i+j].close <= rates[i].close)
            {
               isBuyZone = false;
               break;
            }
         }
         
         if(isBuyZone && g_smcZonesCount < ArraySize(g_smcZones))
         {
            g_smcZones[g_smcZonesCount].price = rates[i].close;
            g_smcZones[g_smcZonesCount].isBuyZone = true;
            g_smcZones[g_smcZonesCount].time = rates[i].time;
            g_smcZones[g_smcZonesCount].strength = 0.7; // Force moyenne par défaut
            g_smcZones[g_smcZonesCount].width = SMC_OB_ZoneWidth;
            g_smcZones[g_smcZonesCount].isActive = true;
            g_smcZonesCount++;
            continue;
         }
      }
      
      // Vérifier si c'est un bloc de vente (bullish candle suivie de bougies baissières)
      if(rates[i].close > rates[i].open) // Bullish candle
      {
         bool isSellZone = true;
         for(int j = 1; j <= SMC_OB_MinCandles; j++)
         {
            if(rates[i+j].close >= rates[i].close)
            {
               isSellZone = false;
               break;
            }
         }
         
         if(isSellZone && g_smcZonesCount < ArraySize(g_smcZones))
         {
            g_smcZones[g_smcZonesCount].price = rates[i].close;
            g_smcZones[g_smcZonesCount].isBuyZone = false;
            g_smcZones[g_smcZonesCount].time = rates[i].time;
            g_smcZones[g_smcZonesCount].strength = 0.7; // Force moyenne par défaut
            g_smcZones[g_smcZonesCount].width = SMC_OB_ZoneWidth;
            g_smcZones[g_smcZonesCount].isActive = true;
            g_smcZonesCount++;
         }
      }
   }
   
   // Désactiver les zones trop anciennes
   int currentBar = iBars(_Symbol, PERIOD_CURRENT);
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      int zoneBar = iBarShift(_Symbol, PERIOD_CURRENT, g_smcZones[i].time);
      if(currentBar - zoneBar > SMC_OB_ExpiryBars)
      {
         g_smcZones[i].isActive = false;
      }
   }
}

//+------------------------------------------------------------------+
//| STRATÉGIE SPIKE ZONE - Retournement ou Cassure                   |
//| 1. Prix entre dans zone → Attendre                                |
//| 2. Prix se retourne → Trade retournement                          |
//| 3. Prix casse la zone → Trade continuation                        |
//+------------------------------------------------------------------+
// Variables statiques pour tracker l'état de la zone
static bool g_priceWasInZone = false;
static double g_zoneEntryPrice = 0;
static double g_zoneHigh = 0;
static double g_zoneLow = 0;
static bool g_zoneIsBuy = false;
static datetime g_zoneEntryTime = 0;

//+------------------------------------------------------------------+
//| Dessine les zones de trading basées sur l'IA                      |
//+------------------------------------------------------------------+
void DrawAIZones()
{
   // Vérifier si on est en mode démo ou si l'affichage est désactivé
   if(!ShowZones || !MQLInfoInteger(MQL_TESTER))
      return;
      
   // Effacer les anciennes zones
   ObjectsDeleteAll(0, "AI_Zone_");
   
   // Récupérer les données du marché
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Définir les niveaux de zones (exemple avec 3 zones de chaque côté)
   double zones[][2] = {
      {ask + 20 * point, ask + 50 * point},    // Zone de vente 1
      {ask + 50 * point, ask + 100 * point},   // Zone de vente 2
      {bid - 100 * point, bid - 50 * point},   // Zone d'achat 1
      {bid - 50 * point, bid - 20 * point}     // Zone d'achat 2
   };
   
   // Couleurs des zones (rouge pour vente, vert pour achat)
   color zoneColors[] = {clrRed, clrOrangeRed, clrLimeGreen, clrLime};
   
   // Dessiner chaque zone
   for(int i = 0; i < ArraySize(zones); i++)
   {
      string name = StringFormat("AI_Zone_%d", i);
      
      // Créer un rectangle pour la zone
      if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, 0, 0, 0, 0))
      {
         Print("Erreur création zone ", name, ": ", GetLastError());
         continue;
      }
      
      // Configurer le rectangle avec la signature correcte pour MQL5
      datetime time1 = TimeCurrent();
      datetime time2 = time1 + 3600; // 1h de visibilité
      
      // Créer le rectangle avec les coordonnées directement
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, zones[i][0], time2, zones[i][1]))
      {
         // Configurer les propriétés du rectangle
         ObjectSetInteger(0, name, OBJPROP_COLOR, zoneColors[i]);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      }
   }
   
   // Mettre à jour le graphique
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Affiche les zones SMC_OB sur le graphique                        |
//+------------------------------------------------------------------+
void DrawSMCOBZones()
{
   static datetime lastDraw = 0;
   if(TimeCurrent() - lastDraw < 10) // Mettre à jour toutes les 10 secondes
      return;
      
   lastDraw = TimeCurrent();
   
   // Supprimer les anciens objets
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      string objName = "SMC_OB_" + IntegerToString(i);
      ObjectDelete(0, objName);
   }
   
   // Afficher les zones actives
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      if(!g_smcZones[i].isActive) continue;
      
      string objName = "SMC_OB_" + IntegerToString(i);
      color zoneColor = g_smcZones[i].isBuyZone ? clrLime : clrRed;
      
      double zoneHigh = g_smcZones[i].price * (1 + g_smcZones[i].width);
      double zoneLow = g_smcZones[i].price * (1 - g_smcZones[i].width);
      
      // Créer un rectangle pour la zone
      if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 0, 0, 0, 0))
         continue;
         
      // Définir les propriétés du rectangle avec les bonnes énumérations
      datetime time1 = TimeCurrent() - 3600*24*30; // Début (il y a 30 jours)
      datetime time2 = TimeCurrent() + 3600*24;    // Fin (dans 1 jour)
      
      // Définir les points du rectangle avec ObjectCreate
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time1, zoneHigh, time2, zoneLow);
      
      // Définir les propriétés du rectangle
      ObjectSetInteger(0, objName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Met à jour l'affichage clignotant de la flèche et détecte le spike|
//+------------------------------------------------------------------+
void UpdateSpikeAlertDisplay()
{
   // Déclaration des variables locales pour l'affichage
   string name = "SPIKE_ALERT_" + _Symbol;
   int corner = CORNER_LEFT_UPPER;
   int xOffset = 10;
   int yOffset = 10;
   
   // Déclaration des variables pour les données fondamentales
   color textColor = clrWhite;
   double peRatio = 0;
   double dividendYield = 0;
   
   // Tant qu'un trade spike est en cours d'exécution, on laisse la logique
   // de détection/fermeture fonctionner même si g_aiSpikePredicted passe à false.
   if(!g_aiSpikePredicted && !g_aiSpikeExecuted)
   {
      // Supprimer la flèche si plus de prédiction
      string arrowName = "SPIKE_ARROW_" + _Symbol;
      ObjectDelete(0, arrowName);
      return;
   }
   
   // Vérifier si le spike a été détecté (mouvement rapide vers la zone)
   if(g_aiSpikeExecuted && CountPositionsForSymbolMagic() > 0)
   {
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
      double spikeZonePrice = (g_aiSpikeZonePrice > 0.0) ? g_aiSpikeZonePrice : currentPrice;
      
      // Détecter si le prix a atteint la zone de spike (dans un rayon de 0.1% du prix)
      double priceDiff = MathAbs(currentPrice - spikeZonePrice);
      double tolerance = currentPrice * 0.001; // 0.1% de tolérance
      
      bool isBoom = (StringFind(_Symbol, "Boom") != -1);
      bool isCrash = (StringFind(_Symbol, "Crash") != -1);
      bool isBuySpike = (isBoom || (!isCrash && g_aiSpikeDirection));
      bool isBoom300 = (StringFind(_Symbol, "Boom 300") != -1);
      
      bool spikeDetected = false;

      // Cas spécial Boom 300 : clôture immédiate dès le premier spike exécuté,
      // sans attendre que le prix atteigne une zone théorique.
      if(isBoom300)
      {
         spikeDetected = true;
      }
      else
      {
         // Pour BUY: prix doit monter vers la zone
         // Pour SELL: prix doit descendre vers la zone
         if(isBuySpike && currentPrice >= spikeZonePrice - tolerance)
            spikeDetected = true;
         else if(!isBuySpike && currentPrice <= spikeZonePrice + tolerance)
         spikeDetected = true;
      }
      
      // Pour Boom/Crash : dès que le spike est validé, on clôture rapidement
      // la ou les positions du symbole et on arrête l'alerte sonore.
      if(spikeDetected && (isBoom || isCrash))
      {
         CloseAllPositionsForSymbolMagic();
         string msgEnd = StringFormat("SPIKE EXECUTE sur %s - Position clôturée après spike.", _Symbol);
         SendNotification(msgEnd);
         // Arrêter la flèche et le clignotement
         string arrowEnd = "SPIKE_ARROW_" + _Symbol;
         ObjectDelete(0, arrowEnd);
         g_aiSpikePredicted = false;
         g_aiStrongSpike = false;
         g_aiSpikeExecuted = false;
         g_aiSpikePendingPlaced = false;
         return;
      }
   }
   
   // Ne pas garder un signal spike trop longtemps : après 60 secondes (30s avant + 30s après),
   // on le considère comme expiré (sinon risque de trade très en retard).
   if(g_aiSpikeDetectedTime > 0 && (TimeCurrent() - g_aiSpikeDetectedTime) > 60)
   {
      if(DebugBlocks)
         Print("⏱️ Signal spike expiré après 60 secondes");
      ClearSpikeSignal();
      return;
   }
   
   // Mettre à jour le label de compte à rebours (affiché en gros sur le graphique) - TOUJOURS ACTIF
   string labelName = "SPIKE_COUNTDOWN_" + _Symbol;
   if(g_spikeEntryTime > 0 && g_aiSpikePredicted)
   {
      int remaining = (int)(g_spikeEntryTime - TimeCurrent());
      if(remaining < 0) remaining = 0;

      // Calculer les dimensions du graphique
      int chartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
      
      // Créer ou mettre à jour un label centré au milieu du graphique
      if(ObjectFind(0, labelName) < 0)
      {
         if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
         {
            Print("❌ Erreur création label countdown: ", GetLastError());
         }
         else
         {
            // Configuration initiale du label
            ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 48); // Taille plus grande pour visibilité
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Black");
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         }
      }

      // Mettre à jour le label à chaque appel (position et texte)
      if(ObjectFind(0, labelName) >= 0)
      {
         // Recalculer les dimensions au cas où la fenêtre a été redimensionnée
         chartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
         chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
         
         // Positionner au centre du graphique
         ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, chartWidth / 2);
         ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, chartHeight / 2);

         // Mettre à jour le texte
         string txt = "SPIKE dans: " + IntegerToString(remaining) + "s";
         ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
         
         // Forcer la visibilité
         ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
      }
      else if(remaining > 0)
      {
         // Si le label n'existe pas mais qu'il devrait, essayer de le recréer
         Print("⚠️ Label countdown introuvable mais spike actif. Tentative de recréation...");
      }
   }
   else
   {
      // Si pas de spike prévu, supprimer le label
      if(ObjectFind(0, labelName) >= 0)
         ObjectDelete(0, labelName);
   }
   
   // Faire clignoter la flèche (changement de visibilité toutes les 1 secondes)
   static datetime lastBlinkTime = 0;
   static bool blinkState = false;

   // Utiliser 1 seconde (TimeCurrent retourne un entier), évite comparaison flottante incorrecte
   if(TimeCurrent() - lastBlinkTime >= 1)
   {
      blinkState = !blinkState;
      lastBlinkTime = TimeCurrent();

      string arrowName = "SPIKE_ARROW_" + _Symbol;
      if(ObjectFind(0, arrowName) >= 0)
      {
         bool isBoom = (StringFind(_Symbol, "Boom") != -1);
         bool isCrash = (StringFind(_Symbol, "Crash") != -1);
         bool isBuySpike = (isBoom || (!isCrash && g_aiSpikeDirection));

         // Toujours afficher la flèche en couleur vive pendant les 20 secondes
         color arrowColor = isBuySpike ? clrLime : clrRed;

         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
      }
   }
   
   // Ligne de séparation
   string lineName = name + "_Line";
   if(ObjectFind(0, lineName) < 0)
   {
      ObjectCreate(0, lineName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lineName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, lineName, OBJPROP_XDISTANCE, xOffset);
      ObjectSetInteger(0, lineName, OBJPROP_YDISTANCE, yOffset + 25);
      ObjectSetInteger(0, lineName, OBJPROP_XSIZE, 200);
      ObjectSetInteger(0, lineName, OBJPROP_YSIZE, 1);
      ObjectSetInteger(0, lineName, OBJPROP_BGCOLOR, clrGray);
      ObjectSetInteger(0, lineName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   }
   
   // Affichage du PER
   string peName = name + "_PE";
   if(ObjectFind(0, peName) < 0)
   {
      ObjectCreate(0, peName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, peName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, peName, OBJPROP_XDISTANCE, xOffset + 10);
      ObjectSetInteger(0, peName, OBJPROP_YDISTANCE, yOffset + 35);
      ObjectSetInteger(0, peName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, peName, OBJPROP_FONTSIZE, 8);
   }
   string peText = "PER: " + (peRatio > 0 ? DoubleToString(peRatio, 2) : "N/A");
   ObjectSetString(0, peName, OBJPROP_TEXT, peText);
   
   // Affichage du rendement du dividende
   string divName = name + "_Div";
   if(ObjectFind(0, divName) < 0)
   {
      ObjectCreate(0, divName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, divName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, divName, OBJPROP_XDISTANCE, xOffset + 100);
      ObjectSetInteger(0, divName, OBJPROP_YDISTANCE, yOffset + 35);
      ObjectSetInteger(0, divName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, divName, OBJPROP_FONTSIZE, 8);
   }
   string divText = "Dividende: " + (dividendYield > 0 ? DoubleToString(dividendYield, 2) + "%" : "N/A");
   ObjectSetString(0, divName, OBJPROP_TEXT, divText);
   
   // Affichage du sentiment
   string sentName = name + "_Sentiment";
   if(ObjectFind(0, sentName) < 0)
   {
      ObjectCreate(0, sentName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, sentName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, sentName, OBJPROP_XDISTANCE, xOffset + 10);
      ObjectSetInteger(0, sentName, OBJPROP_YDISTANCE, yOffset + 55);
      ObjectSetInteger(0, sentName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, sentName, OBJPROP_FONTSIZE, 8);
   }
   
   string sentimentIcon = "⚪";
   if(g_fundamentalBias == "bullish") sentimentIcon = "🟢";
   else if(g_fundamentalBias == "bearish") sentimentIcon = "🔴";
   
   string sentText = "Sentiment: " + sentimentIcon + " " + g_fundamentalBias + 
                    " (" + DoubleToString(g_fundamentalSentiment, 3) + ")";
   ObjectSetString(0, sentName, OBJPROP_TEXT, sentText);
   
   // Affichage du nombre d'articles
   string newsName = name + "_News";
   if(ObjectFind(0, newsName) < 0)
   {
      ObjectCreate(0, newsName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, newsName, OBJPROP_CORNER, (long)corner);
      ObjectSetInteger(0, newsName, OBJPROP_XDISTANCE, (long)(xOffset + 10));
      ObjectSetInteger(0, newsName, OBJPROP_YDISTANCE, (long)(yOffset + 75));
      ObjectSetInteger(0, newsName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, newsName, OBJPROP_FONTSIZE, 8);
   }
   ObjectSetString(0, newsName, OBJPROP_TEXT, "📰 Actualités récentes: " + IntegerToString(g_fundamentalNewsCount));
   
   // Dernière mise à jour
   string timeName = name + "_Time";
   if(ObjectFind(0, timeName) < 0)
   {
      ObjectCreate(0, timeName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, timeName, OBJPROP_CORNER, (long)corner);
      ObjectSetInteger(0, timeName, OBJPROP_XDISTANCE, (long)(xOffset + 10));
      ObjectSetInteger(0, timeName, OBJPROP_YDISTANCE, (long)(yOffset + 95));
      ObjectSetInteger(0, timeName, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, timeName, OBJPROP_FONTSIZE, 7);
   }
   ObjectSetString(0, timeName, OBJPROP_TEXT, "Dernière mise à jour: " + TimeToString(TimeCurrent(), TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Met à jour l'affichage des données fondamentales                 |
//+------------------------------------------------------------------+
void UpdateFundamentalDisplay(double peRatio, double dividendYield)
{
   // Déclaration des variables locales
   string name = "AI_FundamentalPanel";
   int corner = CORNER_LEFT_LOWER;
   int xOffset = 5;
   int yOffset = 5;
   
   // Couleurs
   color bullColor = C'0,200,0';    // Vert pour haussier
   color bearColor = C'200,0,0';    // Rouge pour baissier
   color neutralColor = clrGray;    // Gris pour neutre
   color textColor = clrWhite;      // Couleur du texte
   
   // Déterminer la couleur en fonction du sentiment
   color sentimentColor = neutralColor;
   if(g_fundamentalBias == "bullish") sentimentColor = bullColor;
   else if(g_fundamentalBias == "bearish") sentimentColor = bearColor;
   
   // Déclaration des constantes pour les types d'objets
   #define OBJ_RECTANGLE_LABEL 0
   #define OBJ_LABEL 1
   
   // Déclaration des constantes pour les coins
   #define CORNER_LEFT_LOWER 1
   
   // Déclaration des constantes pour les bordures
   #define BORDER_FLAT 0
   
   // Déclaration des constantes pour le temps
   #define AI_TIME_MINUTES 1
   
   // Créer ou mettre à jour le panneau principal
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yOffset);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 200);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 120);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'20,20,20');
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, sentimentColor);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
   
   // Titre du panneau
   string titleName = name + "_Title";
   if(ObjectFind(0, titleName) < 0)
   {
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, titleName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, xOffset + 5);
      ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, yOffset + 5);
      ObjectSetInteger(0, titleName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, titleName, OBJPROP_BACK, false);
      ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetString(0, titleName, OBJPROP_TEXT, "📊 ANALYSE FONDAMENTALE - " + _Symbol);
   
   // Ligne de séparation
   string lineName = name + "_Line";
   if(ObjectFind(0, lineName) < 0)
   {
      ObjectCreate(0, lineName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lineName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, lineName, OBJPROP_XDISTANCE, xOffset);
      ObjectSetInteger(0, lineName, OBJPROP_YDISTANCE, yOffset + 25);
      ObjectSetInteger(0, lineName, OBJPROP_XSIZE, 200);
      ObjectSetInteger(0, lineName, OBJPROP_YSIZE, 1);
      ObjectSetInteger(0, lineName, OBJPROP_BGCOLOR, clrGray);
      ObjectSetInteger(0, lineName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   }
   
   // Affichage du PER
   string peName = name + "_PE";
   if(ObjectFind(0, peName) < 0)
   {
      ObjectCreate(0, peName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, peName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, peName, OBJPROP_XDISTANCE, xOffset + 10);
      ObjectSetInteger(0, peName, OBJPROP_YDISTANCE, yOffset + 35);
      ObjectSetInteger(0, peName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, peName, OBJPROP_FONTSIZE, 8);
   }
   string peText = "PER: " + (peRatio > 0 ? DoubleToString(peRatio, 2) : "N/A");
   ObjectSetString(0, peName, OBJPROP_TEXT, peText);
   
   // Affichage du rendement du dividende
   string divName = name + "_Div";
   if(ObjectFind(0, divName) < 0)
   {
      ObjectCreate(0, divName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, divName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, divName, OBJPROP_XDISTANCE, xOffset + 100);
      ObjectSetInteger(0, divName, OBJPROP_YDISTANCE, yOffset + 35);
      ObjectSetInteger(0, divName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, divName, OBJPROP_FONTSIZE, 8);
   }
   string divText = "Dividende: " + (dividendYield > 0 ? DoubleToString(dividendYield, 2) + "%" : "N/A");
   ObjectSetString(0, divName, OBJPROP_TEXT, divText);
   
   // Affichage du sentiment
   string sentName = name + "_Sentiment";
   if(ObjectFind(0, sentName) < 0)
   {
      ObjectCreate(0, sentName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, sentName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, sentName, OBJPROP_XDISTANCE, xOffset + 10);
      ObjectSetInteger(0, sentName, OBJPROP_YDISTANCE, yOffset + 55);
      ObjectSetInteger(0, sentName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, sentName, OBJPROP_FONTSIZE, 8);
   }
   
   string sentimentIcon = "⚪";
   if(g_fundamentalBias == "bullish") sentimentIcon = "🟢";
   else if(g_fundamentalBias == "bearish") sentimentIcon = "🔴";
   
   string sentText = "Sentiment: " + sentimentIcon + " " + g_fundamentalBias + 
                    " (" + DoubleToString(g_fundamentalSentiment, 3) + ")";
   ObjectSetString(0, sentName, OBJPROP_TEXT, sentText);
   
   // Affichage du nombre d'articles
   string newsName = name + "_News";
   if(ObjectFind(0, newsName) < 0)
   {
      ObjectCreate(0, newsName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, newsName, OBJPROP_CORNER, (long)corner);
      ObjectSetInteger(0, newsName, OBJPROP_XDISTANCE, (long)(xOffset + 10));
      ObjectSetInteger(0, newsName, OBJPROP_YDISTANCE, (long)(yOffset + 75));
      ObjectSetInteger(0, newsName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, newsName, OBJPROP_FONTSIZE, 8);
   }
   ObjectSetString(0, newsName, OBJPROP_TEXT, "📰 Actualités récentes: " + IntegerToString(g_fundamentalNewsCount));
   
   // Dernière mise à jour
   string timeName = name + "_Time";
   if(ObjectFind(0, timeName) < 0)
   {
      ObjectCreate(0, timeName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, timeName, OBJPROP_CORNER, (long)corner);
      ObjectSetInteger(0, timeName, OBJPROP_XDISTANCE, (long)(xOffset + 10));
      ObjectSetInteger(0, timeName, OBJPROP_YDISTANCE, (long)(yOffset + 95));
      ObjectSetInteger(0, timeName, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, timeName, OBJPROP_FONTSIZE, 7);
   }
   ObjectSetString(0, timeName, OBJPROP_TEXT, "Dernière mise à jour: " + TimeToString(TimeCurrent(), TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Vérifie les signaux d'entrée                                     |
//+------------------------------------------------------------------+
void CheckForEntrySignals()
{
   // Vérifier si le trading est activé
   if(!EnableTrading)
      return;
      
   // Vérifier si on peut placer un nouvel ordre
   if(!IsMarketConditionGoodForTrading())
      return;
      
   // Logique de base pour les signaux d'entrée
   // Cette fonction peut être étendue avec des stratégies spécifiques
   static datetime lastSignalTime = 0;
   datetime currentTime = TimeCurrent();
   
   // Éviter les signaux trop fréquents (minimum 60 secondes entre les signaux)
   if(currentTime - lastSignalTime < 60)
      return;
      
   // Ici vous pouvez ajouter votre logique de détection de signaux
   // Par exemple: vérification des indicateurs, conditions de marché, etc.
   
   lastSignalTime = currentTime;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Met à jour le panneau d'affichage                                |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   // Mettre à jour les différents panneaux d'affichage
   if(ShowZones)
      DrawTimeWindowsPanel();
      
   // Autres mises à jour d'interface peuvent être ajoutées ici
   // Par exemple: mise à jour des indicateurs, zones AI, etc.
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+\n//| V�rifie si on peut trader apr�s des pertes cons�cutives          |\n//+------------------------------------------------------------------+\nbool CanTradeAfterLosses()\n{\n   datetime now = TimeCurrent();\n   static datetime lastAlertTime = 0;\n   \n   // Si on a d�j� 2 pertes cons�cutives et que le temps de r�cup�ration n'est pas �coul�\n   if(g_consecutiveLosses >= 2 && now < g_recoveryUntil)\n   {\n      if(GetTickCount() - lastAlertTime > 300000) // Alerte toutes les 5 minutes\n      {\n         Print(\ ? Trading en pause apr�s \ + (string)g_consecutiveLosses + \ pertes cons�cutives. Reprise � \ + \n               TimeToString(g_recoveryUntil, TIME_MINUTES));\n         lastAlertTime = GetTickCount();\n      }\n      return false;\n   }\n   \n   // R�initialiser le compteur si le temps de r�cup�ration est �coul�\n   if(g_consecutiveLosses >= 2 && now >= g_recoveryUntil)\n   {\n      Print(\? Fin de la pause apr�s pertes cons�cutives. Reprise du trading.\);\n      g_consecutiveLosses = 0;\n      g_recoveryUntil = 0;\n   }\n   \n   return true;\n}
