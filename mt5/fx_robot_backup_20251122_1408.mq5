//+------------------------------------------------------------------+
//| Fx_robot_pred_v3.1 - Spike catcher prédictif Boom/Crash          |
//| - BUY uniquement sur "Boom" symbols                              |
//| - SELL uniquement sur "Crash" symbols                            |
//| - 1 trade max (par magic+symbole)                                |

//| - Confirmations: MA trend, ADX, VPIN, OBI, CVD, optional FVG     |
//| - Protection contre le drawdown                                  |
//| Auteur: Adaptation pour l'utilisateur                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <Arrays\ArrayString.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo positionInfo;

// Structure pour stocker les informations de signal par symbole
struct SymbolSignal 
{
    datetime lastSignalTime;
    double lastPrice;
    double lastSL;
    double lastTP;
    bool hasPosition;
};

// Tableau des symboles à surveiller
string g_symbolsToWatch[] = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD"};

// Dictionnaire pour stocker les signaux par symbole
SymbolSignal g_symbolSignals[];

// ------------------- INPUTS (configuration) -----------------------
input bool     InpEnableTrading         = true;
input ulong    InpMagicNumber           = 20251115;
input ENUM_TIMEFRAMES InpSpikeTimeframe = PERIOD_M1;
input int      InpATR_Period            = 14;
input double   InpATRMultiplier         = 1.5;
input int      InpVPIN_WindowBars       = 500;
input int      InpOBI_Lookback          = 300;
input int      InpCVD_WindowBars        = 500;
input int      InpADX_Period            = 14;
input double   InpADX_Threshold         = 18.0;
input double   InpVPIN_Threshold        = 0.60;
input double   InpOBI_Threshold         = 0.55;
input double   InpRiskPercent           = 1.0;
input double   InpLotFixed              = 0.0;
input int      InpMinBarsRequired       = 600;
input bool     InpEnableTrailing        = true;
input double   InpTrailingATRMult       = 1.0;
input double   InpDailyDrawdownPercent   = 5.0;    // Drawdown journalier max (%)
input double   InpMaxPositionRiskPercent = 2.0;    // Risque max par position (%)
input bool     InpEnableProtections      = true;   // Activer les protections

input group "=== TRADE SETTINGS ==="
input int      InpSlippage             = 3;       // Slippage en points

input group "=== VISUALS ==="
input bool     InpShowVisuals           = true;   // Afficher les éléments visuels
input bool     InpPlaySounds            = false;  // Activer les sons
input bool     InpEnableNotifications   = true;   // Activer les notifications
input string   InpPhoneNumber           = "";     // Numéro de téléphone pour les notifications (format: 33612345678)
input color    InpColorOB_Bull          = clrLime;
input color    InpColorOB_Bear          = clrRed;
input color    InpColorSR               = clrAqua;
input color    InpColorTrend            = clrYellow;
input color    InpColorSpikeArrow       = clrMagenta;

// Liste des symboles prioritaires (gardée pour compatibilité)
const string PRIORITY_SYMBOLS[] = {
   "Volatility 10 Index", "Volatility 25 Index", "Volatility 50 Index",
   "Volatility 75 Index", "Volatility 100 Index", "Volatility 10 (1s) Index",
   "Volatility 25 (1s) Index", "Volatility 50 (1s) Index", "Volatility 75 (1s) Index",
   "Volatility 100 (1s) Index", "Volatility 150 (2s) Index", "Volatility 250 (2s) Index",
   "Boom 300 Index", "Boom 500 Index", "Boom 600 Index", "Boom 900 Index", "Boom 1000 Index",
   "Crash 150 Index", "Crash 300 Index", "Crash 500 Index", "Crash 600 Index", "Crash 900 Index",
   "Crash 1000 Index", "Step Index 1", "Step Index 2", "Step Index 3", "Step Index 4", "Step Index 5"
};

// internal handles
int g_atr_handle = INVALID_HANDLE;
int g_ma20_handle = INVALID_HANDLE;
int g_ma50_handle = INVALID_HANDLE;
int g_short_atr_handle = INVALID_HANDLE;
int g_long_atr_handle = INVALID_HANDLE;

// global state
int      g_drawCount   = 0;                     // Compteur pour les objets graphiques
datetime g_lastBarTime = 0;                     // Dernière bougie traitée
datetime g_lastDayChecked = 0;                  // Dernier jour vérifié pour le drawdown
double   g_dailyStartingBalance = 0.0;          // Solde de départ de la journée
double   g_maxDailyDrawdown = 0.0;              // Drawdown maximum autorisé
double   g_lastVPIN    = 0.0;                   // Dernière valeur VPIN calculée
double   g_lastOBI     = 0.0;                   // Dernière valeur OBI calculée
double   g_lastCVD     = 0.0;                   // Dernière valeur CVD calculée

// Suivi des signaux actifs par symbole
struct ActiveSignal {
   string  symbol;       // Symbole du signal
   bool    isActive;     // Si un signal est actif
   int     direction;    // Direction du signal (1 pour achat, -1 pour vente)
   double  entryLevel;   // Niveau d'entrée du signal
   datetime lastSignalTime; // Dernier moment où le signal a été émis
};

// Tableau pour stocker les signaux actifs par symbole
ActiveSignal g_activeSignals[];

//+------------------------------------------------------------------+
//| Vérifie si un signal de trading est actif pour le symbole courant |
//+------------------------------------------------------------------+
bool IsSignalActive(int checkDirection = 0)
{
   string symbol = _Symbol;
   
   // Parcourir le tableau des signaux actifs
   for(int i = 0; i < ArraySize(g_activeSignals); i++)
   {
      if(g_activeSignals[i].isActive && g_activeSignals[i].symbol == symbol)
      {
         // Si on vérifie une direction spécifique
         if(checkDirection != 0 && g_activeSignals[i].direction != checkDirection)
            return false;
            
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Marque un signal comme actif pour le symbole courant             |
//+------------------------------------------------------------------+
void SetSignalActive(int direction, double entryLevel)
{
   string symbol = _Symbol;
   bool found = false;
   
   // Vérifier si le symbole a déjà un signal actif
   for(int i = 0; i < ArraySize(g_activeSignals); i++)
   {
      if(g_activeSignals[i].symbol == symbol)
      {
         // Mettre à jour le signal existant
         g_activeSignals[i].isActive = true;
         g_activeSignals[i].direction = direction;
         g_activeSignals[i].entryLevel = entryLevel;
         g_activeSignals[i].lastSignalTime = TimeCurrent();
         found = true;
         break;
      }
   }
   
   // Si pas trouvé, ajouter un nouveau signal
   if(!found)
   {
      int size = ArraySize(g_activeSignals);
      ArrayResize(g_activeSignals, size + 1);
      g_activeSignals[size].symbol = symbol;
      g_activeSignals[size].isActive = true;
      g_activeSignals[size].direction = direction;
      g_activeSignals[size].entryLevel = entryLevel;
      g_activeSignals[size].lastSignalTime = TimeCurrent();
   }
   
   Print("Signal actif pour ", symbol, " - Direction: ", (direction > 0 ? "Achat" : "Vente"), 
         " à ", DoubleToString(entryLevel, _Digits));
}

//+------------------------------------------------------------------+
//| Vérifie et nettoie les signaux expirés                          |
//+------------------------------------------------------------------+
void CleanupExpiredSignals()
{
   datetime currentTime = TimeCurrent();
   
   for(int i = ArraySize(g_activeSignals) - 1; i >= 0; i--)
   {
      // Supprimer les signaux de plus de 24h
      if(currentTime - g_activeSignals[i].lastSignalTime > 86400) // 24 heures en secondes
      {
         Print("Suppression du signal expiré pour ", g_activeSignals[i].symbol);
         ArrayRemove(g_activeSignals, i, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Affiche le tableau de bord avec les tendances                   |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string prefix = "Dashboard_";
   
   // Supprimer les anciens objets
   for(int i = ObjectsTotal(0, 0, -1)-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
   
   // Paramètres d'affichage
   int x = 20;
   int y = 20;
   int lineHeight = 20;
   color textColor = clrWhite;
   
   // Créer le fond
   string bgName = prefix + "BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x-5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y-5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, lineHeight * 6 + 10);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,20,20');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   
   // Titre
   CreateLabel(prefix+"Title", "Tableau de bord - "+_Symbol, x, y, textColor, 10, "Arial Bold");
   y += lineHeight;
   
   // Fonction pour afficher la tendance d'un timeframe
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_H4, PERIOD_H1, PERIOD_M15, PERIOD_M5};
   string tfNames[] = {"H4", "H1", "M15", "M5"};
   
   for(int i = 0; i < ArraySize(timeframes); i++)
   {
      // Calculer la force de la tendance
      int maFastHandle = iMA(_Symbol, timeframes[i], 8, 0, MODE_EMA, PRICE_CLOSE);
      int maSlowHandle = iMA(_Symbol, timeframes[i], 21, 0, MODE_SMA, PRICE_CLOSE);
      int atrHandle = iATR(_Symbol, timeframes[i], 14);
      
      double maFast[1], maSlow[1], atr[1];
      double price = iClose(_Symbol, timeframes[i], 0);
      
      // Copier les valeurs des indicateurs
      if(CopyBuffer(maFastHandle, 0, 0, 1, maFast) <= 0) continue;
      if(CopyBuffer(maSlowHandle, 0, 0, 1, maSlow) <= 0) { IndicatorRelease(maFastHandle); continue; }
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) { IndicatorRelease(maFastHandle); IndicatorRelease(maSlowHandle); continue; }
      
      double strength = 0;
      string trend = "Neutre";
      color trendColor = textColor;
      
      if(maFast[0] > maSlow[0] && price > maSlow[0])
      {
         strength = ((maFast[0] - maSlow[0]) / atr[0]) * 10;
         trend = "Haussière";
         trendColor = clrLime;
      }
      else if(maFast[0] < maSlow[0] && price < maSlow[0])
      {
         strength = ((maSlow[0] - maFast[0]) / atr[0]) * 10;
         trend = "Baissière";
         trendColor = clrRed;
      }
      
      // Libérer les poignées d'indicateurs
      IndicatorRelease(maFastHandle);
      IndicatorRelease(maSlowHandle);
      IndicatorRelease(atrHandle);
      
      // Limiter la force à 100%
      strength = MathMin(MathMax(strength, 0), 100);
      
      // Afficher la ligne
      string line = StringFormat("%s: %s (%.0f%%)", tfNames[i], trend, strength);
      CreateLabel(prefix+"TF_"+tfNames[i], line, x, y, trendColor, 9);
      y += lineHeight;
   }
   
   // Rafraîchir le graphique
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Crée un label sur le graphique                                   |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize=8, string font="Arial")
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
}

//+------------------------------------------------------------------+
//| Détecte un spike sur le marché                                  |
//+------------------------------------------------------------------+
bool IsSpikeDetected()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 3, rates) < 3) return false;
    
    // Calcul du mouvement du prix sur les 3 dernières bougies
    double move1 = MathAbs(rates[1].close - rates[1].open);
    double move2 = MathAbs(rates[2].close - rates[2].open);
    
    // Si le mouvement actuel est 3x plus grand que le mouvement moyen récent
    double currentMove = MathAbs(rates[0].close - rates[0].open);
    double avgMove = (move1 + move2) / 2;
    
    return (avgMove > 0 && currentMove > (avgMove * 3));
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions ouvertes                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && positionInfo.SelectByTicket(ticket))
        {
            if(positionInfo.Magic() == InpMagicNumber)
            {
                trade.PositionClose(ticket);
                Print("Position fermée suite à la détection d'un spike");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Fx_robot_pred_v3.0 - Initialisation...");
   // Initialisation des poignées d'indicateurs
   g_atr_handle = iATR(_Symbol, InpSpikeTimeframe, InpATR_Period);
   g_ma20_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
   g_ma50_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
   g_short_atr_handle = iATR(_Symbol, InpSpikeTimeframe, 14);
   g_long_atr_handle = iATR(_Symbol, InpSpikeTimeframe, 100);
   
   // Initialisation des variables de suivi journalier
   g_lastDayChecked = TimeCurrent();
   g_dailyStartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_maxDailyDrawdown = g_dailyStartingBalance * (InpDailyDrawdownPercent / 100.0);
   
   // Vérification de l'initialisation des indicateurs
   if(g_atr_handle == INVALID_HANDLE || g_ma20_handle == INVALID_HANDLE || 
      g_ma50_handle == INVALID_HANDLE || g_short_atr_handle == INVALID_HANDLE ||
      g_long_atr_handle == INVALID_HANDLE)
   {
      Print("Erreur: échec initialisation des indicateurs");
      // Libération des poignées déjà créées
      if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
      if(g_short_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_short_atr_handle); g_short_atr_handle = INVALID_HANDLE; }
      if(g_long_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_long_atr_handle); g_long_atr_handle = INVALID_HANDLE; }
      if(g_ma20_handle != INVALID_HANDLE) { IndicatorRelease(g_ma20_handle); g_ma20_handle = INVALID_HANDLE; }
      if(g_ma50_handle != INVALID_HANDLE) { IndicatorRelease(g_ma50_handle); g_ma50_handle = INVALID_HANDLE; }
      return(INIT_FAILED);
   }
   // timer pour vérifier nouvelle bougie (1s)
   EventSetTimer(1);
   // nettoyer visuels précédents liés à ce EA sur ce graphique
   if(InpShowVisuals) DeleteAllEAObjects();
   Print("Initialisation OK");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
   if(g_short_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_short_atr_handle); g_short_atr_handle = INVALID_HANDLE; }
   if(g_long_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_long_atr_handle); g_long_atr_handle = INVALID_HANDLE; }
   if(g_ma20_handle != INVALID_HANDLE) { IndicatorRelease(g_ma20_handle); g_ma20_handle = INVALID_HANDLE; }
   if(g_ma50_handle != INVALID_HANDLE) { IndicatorRelease(g_ma50_handle); g_ma50_handle = INVALID_HANDLE; }
   EventKillTimer();
   if(InpShowVisuals) DeleteAllEAObjects();
   Print("Fx_robot_pred - Deinit");
}

//+------------------------------------------------------------------+
//| Analyse un symbole spécifique                                    |
//+------------------------------------------------------------------+
void AnalyzeSymbol(string symbol)
{
    // Sauvegarder le symbole actuel
    string currentSymbol = _Symbol;
    
    // Changer de symbole si nécessaire
    if(symbol != currentSymbol)
    {
        if(!SymbolSelect(symbol, true))
        {
            Print("Impossible de sélectionner le symbole: ", symbol);
            return;
        }
        // Attendre un court instant pour que les données se mettent à jour
        Sleep(100);
    }
    
    // Vérifier si le symbole est dans la liste des priorités (optionnel)
    if(!IsPrioritySymbol())
    {
        static datetime lastWarningTime = 0;
        if(TimeCurrent() - lastWarningTime > 60) // affiche max toutes les 60s
        {
            Print("Attention: Le symbole ", symbol, " n'est pas dans la liste des symboles prioritaires.");
            lastWarningTime = TimeCurrent();
        }
        return;
    }
    
    // Vérifier si une analyse est nécessaire (toutes les 5 secondes par défaut)
    static datetime lastAnalysisTime = 0;
    if(TimeCurrent() - lastAnalysisTime < 5)
        return;
        
    lastAnalysisTime = TimeCurrent();
    
    // Vérifier si un trade est déjà en cours ou si un signal est actif
    if(HasOpenPosition() || IsSignalActive())
    {
        // gérer trailing si activé
        if(InpEnableTrailing) ManageTrailing();
        
        if(HasOpenPosition())
            Print("Un trade est déjà en cours sur ", symbol, ". Attente de sa clôture.");
        else if(IsSignalActive())
            Print("Un signal est déjà actif pour ", symbol, ". Attente de son expiration.");
            
        return;
    }
    
    // Calcul des indicateurs
    double atr = GetCurrentATR(g_atr_handle);
    double vpin = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe);
    double obi = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe);
    double cvd = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe);
    double adx = ComputeADX(symbol, InpSpikeTimeframe, InpADX_Period);
    bool liquidity_sweep = DetectLiquiditySweep(InpSpikeTimeframe, atr, 2.5);
    int fvg = DetectFVG(InpSpikeTimeframe);
    bool isUp = IsUptrend();
    
    // Log des valeurs des indicateurs
    PrintFormat("%s - VPIN=%.2f, OBI=%.2f, CVD=%.2f, ADX=%.2f, ATR=%.5f",
                symbol, vpin, obi, cvd, adx, atr);
    
    // Logique de trading...
    // ... (le reste de votre logique de trading ici)
    
    // Restaurer le symbole d'origine si nécessaire
    if(symbol != currentSymbol)
    {
        SymbolSelect(currentSymbol, true);
    }
}

//+------------------------------------------------------------------+
//| OnTimer - main loop (chaque seconde)                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Mettre à jour le tableau de bord
    static datetime lastUpdate = 0;
    if(TimeCurrent() - lastUpdate >= 1) // Mise à jour toutes les secondes
    {
        UpdateDashboard();
        lastUpdate = TimeCurrent();
    }
    
    if(!InpEnableTrading) return;
    
    // Analyser chaque symbole de la liste
    for(int i = 0; i < ArraySize(g_symbolsToWatch); i++)
    {
        AnalyzeSymbol(g_symbolsToWatch[i]);
    }

   // travailler uniquement sur nouvelles bougies
   datetime t = iTime(_Symbol, InpSpikeTimeframe, 0);
   if(t == g_lastBarTime) return;
   g_lastBarTime = t;

   long bars = GetBarsCount(_Symbol, InpSpikeTimeframe);
   if(bars < InpMinBarsRequired)
   {
      PrintFormat("Attente des données : bars=%d < required=%d", (int)bars, InpMinBarsRequired);
      return;
   }

   // Calcul des indicateurs/proxies institutionnels
   double atr = GetCurrentATR(g_atr_handle);
   double vpin = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe);
   double obi  = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe);
   double cvd  = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe);
   double adx  = ComputeADX(_Symbol, InpSpikeTimeframe, InpADX_Period);
   bool liquidity_sweep = DetectLiquiditySweep(InpSpikeTimeframe, atr, 2.5);
   int fvg = DetectFVG(InpSpikeTimeframe);
   bool isUp = IsUptrend();
   g_lastVPIN = vpin; g_lastOBI = obi; g_lastCVD = cvd;

   // Décision de trading : Buy uniquement sur Boom, Sell uniquement sur Crash
   int direction = 0; // +1 BUY Boom, -1 SELL Crash

   // Log des valeurs des indicateurs
   PrintFormat("VPIN=%.2f (Seuil: %.2f), OBI=%.2f (Seuil: ±%.2f), CVD=%.2f, ADX=%.2f, ATR=%.5f",
               vpin, InpVPIN_Threshold, obi, InpOBI_Threshold, cvd, adx, atr);

   // Nettoyer les signaux expirés
   CleanupExpiredSignals();

   // Conditions de trading simplifiées pour permettre plus de signaux
   bool uptrend = IsUptrend();
   
   // Seuils assouplis
   double vp_threshold = InpVPIN_Threshold * 0.7; // Seuil VPIN réduit
   double obi_threshold = InpOBI_Threshold * 0.8; // Seuil OBI réduit
   double adx_threshold = InpADX_Threshold * 0.8; // Seuil ADX réduit
   
   // Log des conditions
   PrintFormat("Vérification des conditions - VPIN: %.2f (Seuil: %.2f), OBI: %.2f (Seuil: ±%.2f), ADX: %.2f (Seuil: %.2f)",
               vpin, vp_threshold, obi, obi_threshold, adx, adx_threshold);
   
   // Conditions BUY (BOOM) : tendance haussière + VPIN + OBI+ ou CVD+
   if(IsSymbolBoom(_Symbol) && vpin >= vp_threshold)
   {
      if((uptrend && adx >= adx_threshold) || (obi >= obi_threshold) || (cvd > 0))
      {
         direction = +1;
         Print("Signal BUY (BOOM) détecté - Conditions: ", 
               (uptrend ? "Tendance haussière, " : ""),
               (adx >= adx_threshold ? "ADX fort, " : ""),
               (obi >= obi_threshold ? "OBI positif, " : ""),
               (cvd > 0 ? "CVD positif" : ""));
      }
   }
   // Conditions SELL (CRASH) : tendance baissière + VPIN + OBI- ou CVD-
   else if(IsSymbolCrash(_Symbol) && vpin >= vp_threshold)
   {
      if((!uptrend && adx >= adx_threshold) || (obi <= -obi_threshold) || (cvd < 0))
      {
         direction = -1;
         Print("Signal SELL (CRASH) détecté - Conditions: ", 
               (!uptrend ? "Tendance baissière, " : ""),
               (adx >= adx_threshold ? "ADX fort, " : ""),
               (obi <= -obi_threshold ? "OBI négatif, " : ""),
               (cvd < 0 ? "CVD négatif" : ""));
      }
   }
   // Fallback : utiliser FVG si présent
   else if(liquidity_sweep && fvg != 0)
   {
      if((fvg > 0 && IsSymbolBoom(_Symbol)) || (fvg < 0 && IsSymbolCrash(_Symbol)))
      {
         direction = fvg;
         Print("Signal FVG détecté -> direction prise: ", (direction>0) ? "BUY" : "SELL");
      }
   }
   
   if(direction == 0)
   {
      Print("Aucun signal détecté - Conditions non remplies");
   }

   // Dessins si activés
   if(InpShowVisuals)
   {
      DrawOrderBlocksAroundLastBars(12, 20);
      DrawSimpleTrendline(30);
      DrawFiboOnLastMove(60);
      DrawSRZones(120, 10);
   }

   // Affichage flèche prédictive
   if(direction != 0) DrawSpikeArrow(direction);

   // Exécution (si permissions et conditions remplies)
   if(direction != 0 && CanPlaceNewOrder())
   {
      Print("Tentative d'exécution du trade...");
      
      // Vérifier qu'aucune position n'est déjà ouverte et qu'aucun signal n'est actif
      if(!HasOpenPosition() && !IsSignalActive())
      {
         // S'assurer que la direction est autorisée pour le symbole (Boom = BUY only, Crash = SELL only)
         if((direction > 0 && !IsSymbolBoom(_Symbol)) || (direction < 0 && !IsSymbolCrash(_Symbol)))
         {
            Print("Trade bloqué : Direction non autorisée pour ce symbole (Boom/Crash rule).");
            return;
         }
         
         // Vérifier si le prix a suffisamment bougé depuis le dernier signal
         double currentPrice = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         // Marquer le signal comme actif avant d'exécuter le trade
         SetSignalActive(direction, currentPrice);
         
         PrintFormat("Exécution du trade - Direction: %s", (direction > 0) ? "BUY (BOOM)" : "SELL (CRASH)");
         ExecuteTrade(direction, atr);
      }
      else
      {
         if(HasOpenPosition())
            Print("Trade non exécuté - Une position est déjà ouverte");
         else if(IsSignalActive())
            Print("Trade non exécuté - Un signal est déjà actif pour ce symbole");
      }
   }
}

//+------------------------------------------------------------------+
//| Helpers: identification Boom/Crash                               |
//+------------------------------------------------------------------+
bool IsSymbolBoom(string s)
{
   if(StringFind(s,"Boom",0) != -1) return true;
   if(StringFind(s,"BOOM",0) != -1) return true;
   if(StringFind(s,"boom",0) != -1) return true;
   return false;
}
bool IsSymbolCrash(string s)
{
   if(StringFind(s,"Crash",0) != -1) return true;
   if(StringFind(s,"CRASH",0) != -1) return true;
   if(StringFind(s,"crash",0) != -1) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Ajoute une zone de volume au graphique                           |
//+------------------------------------------------------------------+
void AddVolumeProfile()
{
   string vpName = "FXPRO_" + (string)InpMagicNumber + "_VP";
   ObjectDelete(0, vpName);
   datetime end = TimeCurrent();
   datetime start = end - PeriodSeconds(PERIOD_D1) * 5; // 5 jours
   double high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, 5, 0));
   double low = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, 5, 0));
   if(!ObjectCreate(0, vpName, OBJ_RECTANGLE, 0, start, high, end, low))
   {
      Print("Erreur création zone de volume: ", GetLastError());
      return;
   }
   ObjectSetInteger(0, vpName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, vpName, OBJPROP_BACK, true);
   ObjectSetInteger(0, vpName, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, vpName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, vpName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, vpName, OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetInteger(0, vpName, OBJPROP_FILL, true);
   ObjectSetInteger(0, vpName, OBJPROP_SELECTABLE, false);
   Print("Zone de volume ajoutée du ", TimeToString(start), " au ", TimeToString(end));
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires                                            |
//+------------------------------------------------------------------+
long GetBarsCount(string symbol, ENUM_TIMEFRAMES tf)
{
   long cnt = SeriesInfoInteger(symbol, tf, SERIES_BARS_COUNT);
   if(cnt < 0) cnt = 0;
   return cnt;
}

double GetCurrentATR(int handle)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return 0.0;
   return buf[0];
}

// VPIN proxy
double ComputeVPIN(int windowBars, ENUM_TIMEFRAMES tf)
{
   if(windowBars <= 10) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, windowBars, rates);
   if(copied <= 0) return 0.0;
   double buyVol=0.0, sellVol=0.0, totalVol=0.0;
   for(int i=0; i<copied; i++)
   {
      long tv = rates[i].tick_volume;
      totalVol += (double)tv;
      if(rates[i].close > rates[i].open) buyVol += (double)tv;
      else if(rates[i].close < rates[i].open) sellVol += (double)tv;
      else { buyVol += (double)tv*0.5; sellVol += (double)tv*0.5; }
   }
   if(totalVol <= 0.0) return 0.0;
   return MathAbs(buyVol - sellVol) / totalVol;
}

// OBI proxy
double ComputeOBI(int lookbackBars, ENUM_TIMEFRAMES tf)
{
   if(lookbackBars <= 10) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, lookbackBars, rates);
   if(copied <= 0) return 0.0;
   double buyVol=0.0, sellVol=0.0;
   for(int i=0; i<copied; i++)
   {
      long tv = rates[i].tick_volume;
      if(rates[i].close > rates[i].open) buyVol += (double)tv;
      else if(rates[i].close < rates[i].open) sellVol += (double)tv;
   }
   double total = buyVol + sellVol;
   if(total <= 0.0) return 0.0;
   return (buyVol - sellVol) / total;
}

// CVD proxy
double ComputeCVD(int windowBars, ENUM_TIMEFRAMES tf)
{
   if(windowBars <= 5) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, windowBars, rates);
   if(copied <= 0) return 0.0;
   double cvd = 0.0;
   for(int i=0; i<copied; i++)
   {
      double sign = 0.0;
      if(rates[i].close > rates[i].open) sign = 1.0;
      else if(rates[i].close < rates[i].open) sign = -1.0;
      cvd += sign * (double)rates[i].tick_volume;
   }
   return cvd;
}

bool DetectLiquiditySweep(ENUM_TIMEFRAMES tf, double atr_val, double wickMult)
{
   if(atr_val <= 0.0) return false;
   MqlRates r[];
   if(CopyRates(_Symbol, tf, 1, 2, r) < 2) return false;
   double high = r[0].high, low = r[0].low, open = r[0].open, close = r[0].close;
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   if(upperWick > wickMult * atr_val || lowerWick > wickMult * atr_val) return true;
   return false;
}

int DetectFVG(ENUM_TIMEFRAMES tf)
{
   MqlRates r[];
   if(CopyRates(_Symbol, tf, 1, 3, r) < 3) return 0;
   double prevClose = r[1].close;
   double curOpen   = r[0].open;
   if(curOpen - prevClose > 0.0) return +1;
   if(prevClose - curOpen > 0.0) return -1;
   return 0;
}

// ------------------ Visuals (OB, Trend, Fibo, SR, Flèches) ------------------
void DeleteAllEAObjects()
{
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_";
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0) ObjectDelete(0, name);
   }
}

void DrawOrderBlocksAroundLastBars(int lookbackBars, int widthBars)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);

   if(CopyRates(_Symbol, InpSpikeTimeframe, 0, lookbackBars, r) < lookbackBars) return;

   string prefix = "FXPRO_" + (string)InpMagicNumber + "_OB_";
   for(int i=0; i<lookbackBars-1; i++)
   {
      double body = MathAbs(r[i].close - r[i].open);
      double range = r[i].high - r[i].low;
      if(range <= 0) continue;
      if(body >= 0.6 * range)
      {
         datetime t_high = r[i].time;
         double price_high = r[i].high;
         double price_low  = r[i].low;
         string name = prefix + IntegerToString((int)t_high);
         if(ObjectFind(0, name) == -1)
         {
            datetime t2 = t_high + (datetime)(widthBars * PeriodSeconds(InpSpikeTimeframe));
            if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t_high, price_high, t2, price_low))
               Print("ObjectCreate OB failed: ", GetLastError());
            color clr = (r[i].close > r[i].open) ? InpColorOB_Bull : InpColorOB_Bear;
            ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
      }
   }
}

void DrawSimpleTrendline(int lookback)
{
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0) return;
   double maxv = -1e12; int idxMax = -1;
   double minv = 1e12;  int idxMin = -1;
   for(int i=0; i<lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; idxMax = i; }
      if(r[i].low  < minv) { minv = r[i].low;  idxMin = i; }
   }
   if(idxMax >= 0 && idxMin >= 0)
   {
      datetime t1 = r[idxMax].time; double p1 = r[idxMax].high;
      datetime t2 = r[idxMin].time; double p2 = r[idxMin].low;
      string name = "FXPRO_" + (string)InpMagicNumber + "_TREND";
      if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
         Print("ObjectCreate TREND failed: ", GetLastError());
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorTrend);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
   }
}

void DrawFiboOnLastMove(int lookback)
{
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0) return;
   double maxv = -1e12; int imax = -1;
   double minv = 1e12;  int imin = -1;
   for(int i=0; i<lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; imax = i; }
      if(r[i].low  < minv) { minv = r[i].low; imin = i; }
   }
   if(imax < 0 || imin < 0) return;
   datetime t_high = r[imax].time; datetime t_low = r[imin].time;
   double price_high = r[imax].high; double price_low = r[imin].low;
   string name = "FXPRO_" + (string)InpMagicNumber + "_FIBO";
   if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_FIBO, 0, t_low, price_low, t_high, price_high))
      Print("ObjectCreate FIBO failed: ", GetLastError());
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
}

void DrawSRZones(int lookback, double zonePips)
{
   MqlRates r[];
   if(CopyRates(_Symbol, PERIOD_H4, 0, lookback, r) < lookback) return;
   int buckets = 40;
   double high = r[0].high, low = r[0].low;
   for(int i=1; i<lookback; i++) { if(r[i].high > high) high = r[i].high; if(r[i].low < low) low = r[i].low; }
   double range = high - low;
   if(range <= 0.0) return;
   double step = range / buckets;
   double freq[];
   ArrayResize(freq, buckets);
   for(int i=0; i<buckets; i++) freq[i] = 0.0;
   for(int i=0; i<lookback; i++)
   {
      int idx = (int)((r[i].close - low) / step);
      if(idx < 0) idx = 0; if(idx >= buckets) idx = buckets - 1;
      freq[idx] += 1.0;
   }
   for(int i=0; i<buckets; i++)
   {
      if(freq[i] >= 3.0)
      {
         double price_center = low + (i + 0.5) * step;
         string name = "FXPRO_" + (string)InpMagicNumber + "_SR_" + IntegerToString(i);
         double top = price_center + zonePips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double bot = price_center - zonePips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
         datetime t0 = TimeCurrent();
         datetime t1 = t0 + (datetime)(PeriodSeconds(PERIOD_H4) * 10);
         if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, top, t1, bot))
            Print("ObjectCreate SR failed: ", GetLastError());
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
   }
}

//+------------------------------------------------------------------+
//| Envoie une notification pour un signal de trading                |
//+------------------------------------------------------------------+
void SendTradingNotification(string symbol, int direction, double price)
{
   if(!InpEnableNotifications || InpPhoneNumber == "") 
      return;
   
   string signalType = (direction > 0) ? "BOOM" : "CRASH";
   string message = StringFormat("Signal %s sur %s à %.5f", signalType, symbol, price);
   
   // Envoi de la notification via l'API REST
   string headers = "Content-Type: application/json";
   string request = StringFormat("{\"phone\":\"%s\",\"message\":\"%s\"}", 
                               InpPhoneNumber, message);
   
   // URL de l'API de notification (à remplacer par votre endpoint)
   string url = "https://votre-api-de-notification.com/send";
   
   // Envoi de la requête HTTP POST
   char post[], result[];
   string result_headers;
   StringToCharArray(request, post, 0, StringLen(request), CP_UTF8);
   
   int res = WebRequest("POST", url, headers, 10000, post, result, result_headers);
   
   if(res == -1)
   {
      Print("Erreur WebRequest. Erreur: ", GetLastError());
      // Tentative avec la méthode alternative si disponible
      // ...
   }
   else if(res == 200)
   {
      Print("Notification envoyée: ", message);
   }
   else
   {
      Print("Erreur d'envoi de notification. Code: ", res);
   }
}

//+------------------------------------------------------------------+
//| Dessine une flèche de signal et envoie une notification          |
//+------------------------------------------------------------------+
void DrawSpikeArrow(int direction)
{
   string symbol = _Symbol;
   double price = iClose(symbol, InpSpikeTimeframe, 0);
   datetime t = iTime(symbol, InpSpikeTimeframe, 0);
   
   // Créer la flèche avec la couleur appropriée
   string arrowName = "FXPRO_" + (string)InpMagicNumber + "_ARW_" + IntegerToString(g_drawCount++);
   
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, price))
   {
      // Bleu pour Boom (achat), Rouge pour Crash (vente)
      color arrowColor = (direction > 0) ? clrDodgerBlue : clrRed;
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
   }
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, (direction>0)?233:234);
   ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
   
   // Envoyer une notification
   if(InpEnableNotifications)
   {
      SendTradingNotification(symbol, direction, price);
   }
}

// ------------------ Gestion des trades ------------------
//+------------------------------------------------------------------+
//| Vérifie si un nouvel ordre peut être placé                       |
//+------------------------------------------------------------------+
bool CanPlaceNewOrder()
{
   string debugMsg = "Vérification des conditions de trading:\n";
   bool allConditions = true;
   
   if(!InpEnableTrading)
   {
      debugMsg += "- Le trading est désactivé dans les paramètres\n";
      allConditions = false;
   }
   
   // Vérifier les permissions de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      debugMsg += "- Le trading n'est pas autorisé par le terminal\n";
      allConditions = false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      debugMsg += "- Le trading n'est pas autorisé pour ce compte\n";
      allConditions = false;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      debugMsg += "- Le trading automatisé n'est pas autorisé\n";
      allConditions = false;
   }
   
   // Vérifier la connexion
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      debugMsg += "- Pas de connexion au serveur de trading\n";
      allConditions = false;
   }
   
   // Vérifier les permissions du symbole
   int tradeMode = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode != SYMBOL_TRADE_MODE_FULL)
   {
      debugMsg += "- Le trading n'est pas autorisé pour ce symbole. Mode: " + IntegerToString(tradeMode) + "\n";
      allConditions = false;
   }
   
   // Vérifier le drawdown journalier
   if(InpEnableProtections && !CheckDailyDrawdown())
   {
      debugMsg += "- Le drawdown journalier maximum a été atteint\n";
      allConditions = false;
   }
   
   // Afficher le message de débogage si une condition n'est pas remplie
   if(!allConditions)
   {
      Print(debugMsg);
   }
   else
   {
      Print("Toutes les conditions de trading sont remplies");
   }
   
   return allConditions;
}

//+------------------------------------------------------------------+
//| Vérifie le drawdown journalier                                   |
//+------------------------------------------------------------------+
bool CheckDailyDrawdown()
{
   if(!InpEnableProtections) return true;
   
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   // Réinitialiser au début d'une nouvelle journée
   MqlDateTime lastCheckedStruct;
   TimeToStruct(g_lastDayChecked, lastCheckedStruct);
   
   if(lastCheckedStruct.day != timeStruct.day || 
      lastCheckedStruct.mon != timeStruct.mon ||
      lastCheckedStruct.year != timeStruct.year)
   {
      g_dailyStartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_maxDailyDrawdown = g_dailyStartingBalance * (InpDailyDrawdownPercent / 100.0);
      g_lastDayChecked = currentTime;
      PrintFormat("Nouveau jour détecté. Solde de départ: %.2f, Drawdown max: %.2f", 
                 g_dailyStartingBalance, g_maxDailyDrawdown);
   }
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = g_dailyStartingBalance - currentEquity;
   
   if(drawdown > g_maxDailyDrawdown)
   {
      PrintFormat("Drawdown journalier dépassé: %.2f > %.2f (max)", 
                 drawdown, g_maxDailyDrawdown);
      return false;
   }
   
   return true;
}

// Compter positions ouvertes selon direction (filtre magic)
int CountOpenPositions(int direction)
{
   int count = 0;
   int total = PositionsTotal();

   for(int i=0; i<total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      long posType = PositionGetInteger(POSITION_TYPE);
      if(symbol == _Symbol && magic == (long)InpMagicNumber)
      {
         if(direction > 0 && posType == POSITION_TYPE_BUY) count++;
         if(direction < 0 && posType == POSITION_TYPE_SELL) count++;
      }
   }
   return count;
}

double CalculateLotSize(double atr_val)
{
   // si InpLotFixed > 0: utiliser it
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(InpLotFixed > 0.0)
   {
      double steps = MathFloor(InpLotFixed/lot_step + 0.5);
      double lot = steps * lot_step;
      if(lot < min_lot) lot = min_lot;
      if(lot > max_lot) lot = max_lot;
      return NormalizeDouble(lot,2);
   }

   // Sinon option basique: utiliser lot min (sécurisé)
   return NormalizeDouble(min_lot,2);
}

//+------------------------------------------------------------------+
//| Vérifie si on est en tendance haussière (true) ou baissière (false) |
//+------------------------------------------------------------------+
bool IsUptrend()
{
   if(g_ma20_handle == INVALID_HANDLE || g_ma50_handle == INVALID_HANDLE)
      return false;

   double ma20[], ma50[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);

   if(CopyBuffer(g_ma20_handle, 0, 0, 1, ma20) <= 0 ||
      CopyBuffer(g_ma50_handle, 0, 0, 1, ma50) <= 0)
   {
      Print("Erreur lecture MA20/MA50");
      return false;
   }

   return (ma20[0] > ma50[0]);
}

//+------------------------------------------------------------------+
//| Vérifie et gère les positions et ordres existants                |
//| - Limite à 1 position ouverte par symbole                        |
//| - Gère les ordres en attente existants                           |
//| Retourne true si une position est déjà ouverte sur ce symbole    |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   bool hasPosition = false;
   
   // Vérifier les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            hasPosition = true;
            break;
         }
      }
   }
   
   // Si une position est ouverte, annuler tous les ordres en attente
   if(hasPosition)
   {
      CancelAllPendingOrders();
      Print("Position déjà ouverte sur ", _Symbol, ". Tous les ordres en attente annulés.");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Annule tous les ordres en attente pour le symbole actuel         |
//+------------------------------------------------------------------+
void CancelAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(ticket);
            Print("Ordre en attente #", ticket, " annulé.");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si le lot est valide pour le trading                     |
//+------------------------------------------------------------------+
bool IsValidLotSize(double lot, string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Arrondir le lot selon le pas du broker
   lot = MathFloor(lot / stepLot) * stepLot;
   
   // Vérifier les limites
   if(lot < minLot || lot > maxLot)
      return false;
      
   // Pour les symboles Boom/Crash, forcer un minimum de 0.2
   if((StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0) && lot < 0.2)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Normalise le lot selon les spécifications du symbole             |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot, string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Pour les symboles Boom/Crash, forcer un minimum de 0.2
   if(StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
      lot = MathMax(0.2, lot);
   
   // Arrondir selon le pas du broker
   lot = MathFloor(lot / stepLot) * stepLot;
   
   // Respecter les limites
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return lot;
}

//+------------------------------------------------------------------+
//| Vérifie s'il y a un ordre en attente similaire                  |
//+------------------------------------------------------------------+
bool HasSimilarPendingOrder(ENUM_ORDER_TYPE orderType, double price, double sl, double tp)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double priceDiff = point * 10; // Tolérance de 10 points
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
            OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_TYPE) == orderType)
         {
            double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            double orderSL = OrderGetDouble(ORDER_SL);
            double orderTP = OrderGetDouble(ORDER_TP);
            
            // Vérifier si l'ordre est similaire (même type et prix proches)
            if(MathAbs(orderPrice - price) <= priceDiff &&
               MathAbs(orderSL - sl) <= priceDiff &&
               MathAbs(orderTP - tp) <= priceDiff)
            {
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si le symbole actuel est dans la liste des prioritaires  |
//+------------------------------------------------------------------+
bool IsPrioritySymbol()
{
   string currentSymbol = _Symbol;
   for(int i = 0; i < ArraySize(PRIORITY_SYMBOLS); i++)
   {
      if(currentSymbol == PRIORITY_SYMBOLS[i])
         return true;
   }
   // si tu veux ignorer ce check, retourne true ici
   Print("Symbole ", currentSymbol, " n'est pas dans la liste des symboles prioritaires");
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si la perte potentielle est acceptable                  |
//+------------------------------------------------------------------+
bool IsLossAcceptable(double lotSize, double stopLossPips, double maxLoss = 3.0)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue <= 0 || tickSize <= 0 || point <= 0)
   {
      Print("Erreur: Impossible de calculer la perte potentielle");
      return false;
   }
   
   double lossInAccountCurrency = (lotSize * stopLossPips * point * tickValue) / tickSize;
   return (lossInAccountCurrency <= maxLoss);
}

//+------------------------------------------------------------------+
//| Compte le nombre d'ordres limites actifs                        |
//+------------------------------------------------------------------+
int CountPendingLimitOrders()
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

//+------------------------------------------------------------------+
//| Fonction d'exécution des trades                                 |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction, double atr_val, bool isLimitOrder = false, double limitPrice = 0.0)
{
   if(direction == 0) return;
   
   string symbol = _Symbol;
   
   // Vérifier si une position est déjà ouverte (sauf pour les ordres limites)
   if(!isLimitOrder && HasOpenPosition())
   {
      Print("Position déjà ouverte sur ", symbol, ". Aucun nouveau trade ne sera pris.");
      return;
   }
   
   // Vérifier le nombre d'ordres limites
   if(isLimitOrder && CountPendingLimitOrders() >= 2)
   {
      Print("Nombre maximum d'ordres limites atteint (2).");
      return;
   }
   
   // Calcul des paramètres du trade
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double entry = (direction > 0) ? ask : bid;
   double sl = 0, tp = 0;
   
   // Définir le lot à 0.2 pour les symboles Boom/Crash
   double lot = 0.2;
   
   // Vérifier que le lot est valide
   if(!IsValidLotSize(lot, symbol))
   {
      Print("Erreur: Taille de lot invalide pour ", symbol, ". Lot demandé: ", lot);
      return;
   }
   
   // Normaliser le lot selon les spécifications du symbole
   lot = NormalizeLotSize(lot, symbol);
   
   // Calcul des niveaux de SL/TP basés sur l'ATR
   if(direction > 0) // Achat
   {
      sl = ask - (atr_val * 2); // SL à 2 ATR sous l'entrée
      tp = ask + (atr_val * 4); // TP à 4 ATR au-dessus (ratio 1:2)
   }
   else // Vente
   {
      sl = bid + (atr_val * 2); // SL à 2 ATR au-dessus de l'entrée
      tp = bid - (atr_val * 4); // TP à 4 ATR en dessous (ratio 1:2)
   }
   
   // Arrondir les prix selon les spécifications du symbole
   sl = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   tp = NormalizeDouble(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   
   // Pour les ordres limites, diviser le lot par 2 (minimum 0.1)
   if(isLimitOrder)
   {
      lot = MathMax(0.1, lot * 0.5);
      lot = NormalizeLotSize(lot, symbol);
   }
   
   // Vérifier à nouveau que le lot est valide après ajustement
   if(!IsValidLotSize(lot, symbol))
   {
      Print("Erreur: Taille de lot invalide après ajustement. Lot: ", lot);
      return;
   }
   
   // Annuler tous les ordres en attente avant d'exécuter un ordre au marché
   if(!isLimitOrder) CancelAllPendingOrders();
   
   // Exécution du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Calculer le stop loss en pips pour la vérification du risque
   double stopLossPips = (direction > 0) ? (entry - sl) / point : (sl - entry) / point;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double potentialLoss = (lot * stopLossPips * point * tickValue) / tickSize;
   
   // Vérifier si la perte potentielle est acceptable (max 3$)
   if(potentialLoss > 3.0)
   {
      Print("Perte potentielle trop élevée: ", DoubleToString(potentialLoss, 2), " $");
      return;
   }
   
   if(direction > 0)
   {
      if(isLimitOrder)
      {
         if(!trade.BuyLimit(lot, limitPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SMC Buy Limit"))
         {
            Print("Échec de l'ordre d'achat limite. Erreur: ", GetLastError(), 
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre d'achat limite placé à ", DoubleToString(limitPrice, _Digits), 
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits), 
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
      else
      {
         if(!trade.Buy(lot, _Symbol, 0, sl, tp, "SMC Buy Signal"))
         {
            Print("Échec de l'ordre d'achat. Erreur: ", GetLastError(), 
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre d'achat exécuté à ", DoubleToString(ask, _Digits), 
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits), 
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
   }
   else
   {
      if(isLimitOrder)
      {
         if(!trade.SellLimit(lot, limitPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SMC Sell Limit"))
         {
            Print("Échec de l'ordre de vente limite. Erreur: ", GetLastError(),
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre de vente limite placé à ", DoubleToString(limitPrice, _Digits),
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits),
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
      else
      {
         if(!trade.Sell(lot, _Symbol, 0, sl, tp, "SMC Sell Signal"))
         {
            Print("Échec de l'ordre de vente. Erreur: ", GetLastError(),
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre de vente exécuté à ", DoubleToString(bid, _Digits),
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits),
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Exécution trade pour logique prédictive (ATR-based SL/TP) avec gestion des positions uniques
//+------------------------------------------------------------------+
void ExecuteTradePredictive(int direction, double atrVal)
{
   if(direction == 0) return;
   
   // Vérifier si une position est déjà ouverte
   if(HasOpenPosition())
   {
      Print("Position déjà ouverte sur ", _Symbol, ". Aucun nouveau trade ne sera pris.");
      return;
   }

   bool isUp = IsUptrend();
   if((direction > 0 && !isUp) || (direction < 0 && isUp))
   {
      Print("Rejet trade prédictif : contre-tendance détectée");
      return;
   }

   double lot = CalculateLotSize(atrVal);
   if(lot <= 0) 
   { 
      Print("Erreur: Taille de lot invalide: ", lot); 
      return; 
   }

   // Calcul des prix d'entrée, SL et TP
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (direction > 0) ? ask : bid;
   double sl, tp;
   double sl_distance = atrVal * InpATRMultiplier;
   double tp_distance = atrVal * (InpATRMultiplier * 2.5);
   double limit_distance = atrVal * 0.5; // Distance pour les ordres limites

   // 1. Exécution de l'ordre au marché principal
   if(direction > 0)
   {
      sl = price - sl_distance;
      tp = price + tp_distance;
   }
   else
   {
      sl = price + sl_distance;
      tp = price - tp_distance;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   bool ok = false;
   if(direction > 0) 
      ok = trade.Buy(lot, _Symbol, price, sl, tp, "FxPro_PRED_BUY");
   else 
      ok = trade.Sell(lot, _Symbol, price, sl, tp, "FxPro_PRED_SELL");

   if(!ok) 
   {
      Print("Erreur execution trade prédictif: ", GetLastError());
      return;
   }
   else 
   {
      PrintFormat("Trade prédictif exécuté dir=%d lot=%.2f price=%.5f sl=%.5f tp=%.5f", 
                 direction, lot, price, sl, tp);
   }

   // 2. Ajout des ordres limites
   double limit_price1, limit_price2;
   double limit_lot = lot * 0.5; // Taille réduite pour les ordres limites

   if(direction > 0)
   {
      // Ordre d'achat limite 1 (en dessous du prix actuel)
      limit_price1 = price - limit_distance;
      sl = limit_price1 - sl_distance;
      tp = limit_price1 + tp_distance;
      ok = trade.BuyLimit(limit_lot, limit_price1, _Symbol, sl, tp, 
                         ORDER_TIME_GTC, 0, "FxPro_LIMIT_BUY_1");
      PrintFormat("Ordre d'achat limite 1: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price1, ok ? "placé" : "échoué");

      // Ordre d'achat limite 2 (encore plus bas)
      limit_price2 = limit_price1 - limit_distance;
      sl = limit_price2 - sl_distance;
      tp = limit_price2 + tp_distance;
      ok = trade.BuyLimit(limit_lot, limit_price2, _Symbol, sl, tp, 
                         ORDER_TIME_GTC, 0, "FxPro_LIMIT_BUY_2");
      PrintFormat("Ordre d'achat limite 2: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price2, ok ? "placé" : "échoué");
   }
   else
   {
      // Ordre de vente limite 1 (au-dessus du prix actuel)
      limit_price1 = price + limit_distance;
      sl = limit_price1 + sl_distance;
      tp = limit_price1 - tp_distance;
      ok = trade.SellLimit(limit_lot, limit_price1, _Symbol, sl, tp, 
                          ORDER_TIME_GTC, 0, "FxPro_LIMIT_SELL_1");
      PrintFormat("Ordre de vente limite 1: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price1, ok ? "placé" : "échoué");

      // Ordre de vente limite 2 (encore plus haut)
      limit_price2 = limit_price1 + limit_distance;
      sl = limit_price2 + sl_distance;
      tp = limit_price2 - tp_distance;
      ok = trade.SellLimit(limit_lot, limit_price2, _Symbol, sl, tp, 
                          ORDER_TIME_GTC, 0, "FxPro_LIMIT_SELL_2");
      PrintFormat("Ordre de vente limite 2: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price2, ok ? "placé" : "échoué");
   }
}

//+------------------------------------------------------------------+
//| Gestionnaire d'événements de trading                             |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Vérifier si une nouvelle position a été ouverte
   if(HistorySelect(TimeCurrent()-1, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      if(total > 0)
      {
         ulong ticket = HistoryDealGetTicket(total-1);
         if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            // Annuler tous les ordres en attente
            int ord_total = OrdersTotal();
            for(int i = ord_total-1; i >= 0; i--)
            {
               ulong ord_ticket = OrderGetTicket(i);
               if(ord_ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol)
               {
                  trade.OrderDelete(ord_ticket);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ADX compute                                                       |
//+------------------------------------------------------------------+
double ComputeADX(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iADX(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) { IndicatorRelease(handle); return 0.0; }
   double val = buf[0];
   IndicatorRelease(handle);
   return val;
}

//+------------------------------------------------------------------+
//| Trailing stop basé sur ATR                                       |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   int total = PositionsTotal();
   for(int i=0; i<total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      string sym = PositionGetString(POSITION_SYMBOL);
      if(magic != (long)InpMagicNumber || sym != _Symbol) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double cur_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double atr = GetCurrentATR(g_atr_handle);
      if(atr <= 0) continue;
      double trail = atr * InpTrailingATRMult;

      if(type == POSITION_TYPE_BUY)
      {
         double new_sl = cur_price - trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl > cur_sl + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing BUY pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double new_sl = cur_price + trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl < cur_sl - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing SELL pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
   }
}
