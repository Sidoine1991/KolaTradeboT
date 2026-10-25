//+------------------------------------------------------------------+
//| Common.mqh - Déclarations communes pour Fx_robot                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

//--- Paramètres d'entrée (déclarés en externe dans le fichier principal)
input group "Paramètres généraux"
input bool     InpEnableTrading    = true;     // Activer le trading
input bool     InpShowVisuals      = true;     // Afficher les éléments visuels
input bool     InpUsePendingQueue  = false;    // Utiliser la file d'attente des signaux
input int      InpMaxOpenPositions = 3;        // Nombre max de positions ouvertes
input bool     InpNotifyOnSignal   = true;     // Notifier les signaux
input ulong    InpMagicNumber      = 20251115; // Magic Number

//--- Paramètres du marché
input group "Paramètres du marché"
input string   InpSymbolsToTrade   = "Volatility 10 Index,Volatility 25 Index,Volatility 50 Index,Volatility 75 Index,Volatility 100 Index,Volatility 10 (1s) Index,Volatility 25 (1s) Index,Volatility 50 (1s) Index,Volatility 75 (1s) Index,Volatility 100 (1s) Index,Volatility 150 (2s) Index,Volatility 250 (2s) Index,Boom 300 Index,Boom 500 Index,Boom 600 Index,Boom 900 Index,Boom 1000 Index,Crash 150 Index,Crash 300 Index,Crash 500 Index,Crash 600 Index,Crash 900 Index,Crash 1000 Index,Step Index 1,Step Index 2,Step Index 3,Step Index 4,Step Index 5"; // Liste des symboles à trader
input ENUM_TIMEFRAMES InpSpikeTimeframe = PERIOD_M1; // Période pour la détection des signaux
input int      InpMinBarsRequired  = 600;      // Nombre minimum de bougies requises

//--- Paramètres des indicateurs
input group "Paramètres des indicateurs"
input int      InpVPIN_WindowBars  = 500;      // Fenêtre du VPIN (en bougies)
input double   InpVPIN_Threshold   = 0.60;     // Seuil du VPIN pour les signaux
input int      InpOBI_Lookback     = 300;      // Période de l'OBI
input double   InpOBI_Threshold    = 0.55;     // Seuil de l'OBI
input int      InpCVD_WindowBars   = 500;      // Fenêtre du CVD
input int      InpATR_Period       = 14;       // Période de l'ATR
input double   InpATRMultiplier    = 1.5;      // Multiplicateur ATR pour le SL/TP

//--- Couleurs pour les éléments visuels
input group "Paramètres visuels"
color InpColorBuy = clrLime;                   // Couleur des flèches d'achat
color InpColorSell = clrRed;                   // Couleur des flèches de vente
color InpColorSL = clrRed;                     // Couleur des lignes de stop loss
color InpColorTP = clrBlue;                    // Couleur des lignes de take profit
color InpColorSR = C'30,144,255';              // Couleur des zones de support/résistance
color InpColorTrendUp = C'0,100,0';            // Couleur de la tendance haussière
color InpColorTrendDown = C'139,0,0';          // Couleur de la tendance baissière

//--- Variables globales
CTrade trade;              // Objet de trading
string g_symbols[];        // Tableau des symboles à trader

//--- Handles des indicateurs
int g_atr_handle;
int g_short_atr_handle;
int g_long_atr_handle;

//+------------------------------------------------------------------+
//| Initialise les variables globales                                |
//+------------------------------------------------------------------+
void InitializeGlobals()
{
   // Initialiser les handles à INVALID_HANDLE
   g_atr_handle = INVALID_HANDLE;
   g_short_atr_handle = INVALID_HANDLE;
   g_long_atr_handle = INVALID_HANDLE;
   
   // Initialiser l'objet de trading
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.LogLevel(LOG_LEVEL_ALL);
}

//--- Structure pour les signaux en attente
struct PendingSignal
{
   string symbol;
   int direction;       // +1 = Achat, -1 = Vente
   datetime timestamp;
   double entry_price;
   double stop_loss;
   double take_profit;
};

//--- Tableau des signaux en attente
extern PendingSignal g_pendingSignals[];

//--- Déclarations de fonctions partagées
#import "stdlib.ex5"
   string StringTrim(string str);
   string StringReplace(string str, string find, string replacement);
#import

//--- Déclarations des fonctions de l'EA
// Ces fonctions sont définies dans leurs fichiers respectifs
// et déclarées ici pour être accessibles partout

// Fonctions de gestion des positions (définies dans Trading.mqh)
void CloseAllPositions();
int CountOpenPositions(string symbol = "", int magic = -1);
bool CheckAndCloseOppositePosition(string symbol, int direction);
bool CanPlaceNewOrder(string symbol);
void ProcessPendingSignals();

// Fonctions de gestion des indicateurs (définies dans Indicators.mqh)
bool InitializeIndicators();

// Fonctions utilitaires (définies dans Utils.mqh)
double CalculateDrawdown();
bool IsDailyLossLimitReached();
bool IsMaxDrawdownReached(double maxDrawdownPercent);
double CalculateLotSize(string symbol, double riskPercent, double stopLossPips);
void HandleTradingError(int error, string function);
void UpdateVisuals();
void DeleteAllEAObjects();
void ToLowerCase(string &str);

// Fonctions d'initialisation et de nettoyage
void InitializeRobot();
void DeinitializeRobot();
