//+------------------------------------------------------------------+
//| Angel of Spike - Autonomous Spike Hunter EA                      |
//|                     avec détection ultra-réactive des spikes      |
//|                     et gestion optimisée des positions            |
//+------------------------------------------------------------------+

// Déclaration des fonctions
int GenerateTradingSignal();  // Déclaration de la fonction de génération de signaux

// Paramètres d'entrée optimisés pour le scalping de spikes
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool   InpEnableSpikeTrading = true;    // Activer le trading de spikes
input bool   InpEnableAutoTrading = true;     // Activer le trading automatique
input bool   InpShowIndicators = true;        // Afficher les indicateurs sur le graphique
input bool   InpShowTradingInfo = true;       // Afficher les infos de trading et signaux
input bool   InpShowSRZones = true;           // Afficher les zones de support/résistance
input bool   InpAllowMultipleTrades = false;  // Autoriser plusieurs positions simultanées
input double InpRiskPercent = 1.0;            // Pourcentage du capital à risquer par trade
input int    InpMaxTradesPerDay = 5;          // Nombre maximum de trades par jour

input group "=== ALERTES ET NOTIFICATIONS ==="
input bool   InpShowAlerts = true;            // Activer les alertes visuelles
input bool   InpShowNotification = true;      // Activer les notifications push
input string InpAlertSound = "alert2.wav";    // Fichier son pour les alertes

input group "=== PARAMÈTRES DE DÉTECTION ==="
input double InpSpikeMinVolumeRatio = 1.8;    // Ratio de volume minimum pour détection
input double InpSpikeMinRangeRatio = 1.8;     // Ratio de range minimum pour détection
input double InpQuickTP1 = 1.50;              // Premier take profit en $
input double InpQuickTP2 = 3.00;              // Deuxième take profit en $
input double InpQuickSL = 1.00;               // Stop loss initial en $
input bool   InpUseTrailingStop = true;       // Utiliser le trailing stop
input int    InpTrailingStart = 50;           // Déclenchement du trailing (points)
input int    InpTrailingStep = 10;            // Pas du trailing (points)

// Paramètres d'indicateurs techniques
input int    InpVelocityBars = 20;            // Nombre de barres pour calculer la vélocité
input int    InpPivotBars = 20;               // Nombre de barres pour calculer les pivots
input int    InpEMAPeriod = 20;               // Période de l'EMA de tendance
input double InpPivotBuffer = 50.0;          // Marge autour du pivot (points)
input double InpVelocityPercent = 90.0;      // Seuil de vélocité pour signal (0-100%)
input int    InpATRPeriod = 14;              // Période ATR pour la volatilité
input int    InpStopLoss = 100;              // Stop Loss en points
input int    InpTakeProfit = 200;            // Take Profit en points
input int    InpTrailingStopPts = 50;        // Distance du trailing stop en points

// Paramètres des EMA
input int    InpEMA1 = 9;                    // Période EMA 1 (Rapide)
input int    InpEMA2 = 21;                   // Période EMA 2
input int    InpEMA3 = 50;                   // Période EMA 3
input int    InpEMA4 = 100;                  // Période EMA 4
input int    InpEMA5 = 200;                  // Période EMA 5 (Lent)
input color  ColorEMA1 = clrDodgerBlue;      // Couleur EMA1
input color  ColorEMA2 = clrGoldenrod;       // Couleur EMA2
input color  ColorEMA3 = clrMagenta;         // Couleur EMA3
input color  ColorEMA4 = clrLime;            // Couleur EMA4
input color  ColorEMA5 = clrRed;             // Couleur EMA5
input int    WidthEMA = 1;                   // Épaisseur des lignes EMA
input ENUM_LINE_STYLE StyleEMA = STYLE_SOLID; // Style des lignes EMA

// Paramètres des indicateurs
input bool   InpShowEMAOverlay = true;     // Afficher les EMA en superposition
input bool   InpShowBollinger = false;    // Afficher les bandes de Bollinger
input bool   InpShowEnvelopes = false;    // Afficher les enveloppes
input bool   InpDisableProblematicIndicators = true; // Désactiver les indicateurs problématiques
input bool   InpShowOrderBlocks = true;      // Afficher les blocs d'ordres
input bool   InpShowBOS = true;              // Afficher les Break of Structure
input bool   InpShowOTE = true;              // Afficher les zones OTE
input bool   InpShowFibonaccis = true;       // Afficher les retracements de Fibonacci
input int    InpSRZoneLookback = 100;        // Nombre de bougies pour l'analyse S/R
input int    InpSRZoneTolerance = 10;        // Tolérance en points pour les zones S/R
input color  ColorSupport = clrDarkGreen;    // Couleur des zones de support
input color  ColorResistance = clrDarkRed;   // Couleur des zones de résistance
input int    SRZoneTransparency = 90;        // Transparence des zones (0-100)
input double InpLotSize = 0.0;               // Taille de lot fixe (0 pour calcul automatique)

// Paramètres des Order Blocks
input group "=== ORDER BLOCKS TRADING ==="
input bool   InpEnableOrderBlockTrading = true;  // Activer le trading basé sur les Order Blocks
input double InpOBMinDistancePct = 0.3;          // Distance minimale du bord de l'OB (0-1)
input double InpOBMaxDistancePct = 0.7;          // Distance maximale du bord de l'OB (0-1)
input int    InpOBLookbackBars = 50;             // Nombre de barres pour la détection des OB
input double InpOBSLMultiplier = 1.5;            // Multiplicateur du SL par rapport à la largeur OB
input double InpOBTPMultiplier = 2.0;            // Multiplicateur du TP par rapport au SL
input int    InpOBMinStrength = 3;               // Force minimale requise pour trader un OB (1-20)
input bool   InpOBShowZones = true;              // Afficher les zones d'order blocks
input color  InpOBBullishColor = clrDodgerBlue;  // Couleur des OB haussiers
input color  InpOBBearishColor = clrOrangeRed;   // Couleur des OB baissiers
input int    InpOBZoneTransparency = 80;         // Transparence des zones OB (0-100)

// Paramètres des EMA avancés
input ENUM_APPLIED_PRICE InpEMAPrice = PRICE_CLOSE;  // Prix utilisé pour le calcul des EMA
input int    InpEMAShift = 0;                        // Décalage des EMA (en barres)

// Structure pour suivre les positions ouvertes
struct PositionData {
   ulong ticket;
   double tp2;
   datetime openTime;
};

PositionData g_openPositions[50];  // Liste des positions ouvertes
int g_openPositionsCount = 0;

// Variables globales pour la gestion des signaux
struct SpikeSignal {
   datetime signalTime;     // Heure du signal
   double   price;          // Prix du signal
   int      direction;      // 1 pour achat, -1 pour vente
   bool     active;         // Si le signal est actif
   string   arrowName;      // Nom de l'objet flèche
   double   maxProfitUSD;   // Profit maximal atteint
   double   entryPrice;     // Prix d'entrée
   datetime lastAdjustTime; // Dernier ajustement du SL/TP
   bool     inProfit;       // Si le trade est actuellement en profit
   datetime lastCloseTime;  // Dernière heure de fermeture
   double   lastClosePrice; // Dernier prix de fermeture
   string   symbol;         // Symbole du trade
   double   signalStrength; // Force du signal (0-100)
   double   atr;            // Volatilité au moment du signal
   double   volumeRatio;    // Ratio de volume
};

SpikeSignal g_lastSpikeSignal;  // Dernier signal de spike détecté
int g_arrowCounter = 0;         // Compteur pour noms uniques des flèches

// Variables pour le suivi de l'état du trading
datetime g_lastDebugPrint = 0;   // Dernier affichage du statut
int g_lastPositionCount = -1;    // Dernier nombre de positions connues
datetime g_lastAlertTime = 0;    // Dernière alerte déclenchée

// Variables pour le suivi des performances
datetime g_lastTradeTime = 0;    // Dernier moment de trading
int g_consecutiveLosses = 0;     // Pertes consécutives
int g_totalTrades = 0;           // Nombre total de trades
int g_winningTrades = 0;         // Trades gagnants

// Constantes pour les noms d'objets
#define PREFIX "AOS_"
#define SUPPORT_COLOR clrDodgerBlue
#define RESISTANCE_COLOR clrCrimson
#define SIGNAL_BUY_COLOR clrLime
#define SIGNAL_SELL_COLOR clrRed

//+------------------------------------------------------------------+
//| Structure pour les niveaux de support/résistance                  |
//+------------------------------------------------------------------+
struct SLevel {
   double   price;
   datetime time;
   int      hits;
   bool     isSupport;
};

//+------------------------------------------------------------------+
//| Variables globales pour les niveaux S/R                          |
//+------------------------------------------------------------------+
SLevel g_supportLevels[100];     // Liste des niveaux de support
SLevel g_resistanceLevels[100];  // Liste des niveaux de résistance
int g_supportLevelsCount = 0;
int g_resistanceLevelsCount = 0;

//+------------------------------------------------------------------+
//| Initialise les objets graphiques                                 |
//+------------------------------------------------------------------+
bool InitGraphicalObjects()
{
   g_supportLevelsCount = 0;
   g_resistanceLevelsCount = 0;
   
   // Créer un bouton pour effacer les dessins
   if(!ObjectCreate(0, PREFIX+"CLEAR_BTN", OBJ_BUTTON, 0, 0, 0))
   {
      Print("Erreur lors de la création du bouton: ", GetLastError());
      return false;
   }
   
   // Configurer le bouton
   ObjectSetInteger(0, PREFIX+"CLEAR_BTN", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, PREFIX+"CLEAR_BTN", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, PREFIX+"CLEAR_BTN", OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, PREFIX+"CLEAR_BTN", OBJPROP_YSIZE, 20);
   ObjectSetString(0, PREFIX+"CLEAR_BTN", OBJPROP_TEXT, "Effacer tout");
   ObjectSetInteger(0, PREFIX+"CLEAR_BTN", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, PREFIX+"CLEAR_BTN", OBJPROP_BGCOLOR, clrCrimson);
   ObjectSetInteger(0, PREFIX+"CLEAR_BTN", OBJPROP_HIDDEN, true);
   
   // Retourner true pour indiquer que l'initialisation s'est bien passée
   return true;
}

//+------------------------------------------------------------------+
//| Dessine une flèche de prédiction de spike sur une bougie        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Déclenche une alerte pour un signal de spike détecté             |
//+------------------------------------------------------------------+
void TriggerSpikeAlert(const string symbol, const int direction, const double strength)
{
   if(!InpEnableAlerts) return;
   
   // Éviter les alertes trop fréquentes (au moins 5 secondes entre chaque alerte)
   if(TimeCurrent() - g_lastAlertTime < 5) return;
   
   g_lastAlertTime = TimeCurrent();
   
   string directionText = (direction > 0) ? "ACHAT" : "VENTE";
   string alertText = StringFormat("ALERTE SPIKE - %s\nDirection: %s\nForce: %.1f%%", 
                                 symbol, directionText, strength);
   
   // Afficher une alerte visuelle
   Alert(alertText);
   
   // Jouer un son d'alerte si spécifié
   if(InpAlertSound != "") 
      PlaySound(InpAlertSound);
   
   // Afficher une notification push si activé
   if(InpShowNotification)
      SendNotification(alertText);
}

//+------------------------------------------------------------------+
//| Dessine une flèche de prédiction de spike sur le graphique       |
//+------------------------------------------------------------------+
void DrawSpikePredictionArrow(const string symbol, const int direction, const double price, const datetime time)
{
   string arrowName = "SPIKE_PRED_" + symbol + "_" + IntegerToString(time);
   
   // Supprimer l'ancienne flèche si elle existe
   if(ObjectFind(0, arrowName) >= 0)
      ObjectDelete(0, arrowName);
   
   // Créer la flèche sur la bougie
   if(!ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, price))
   {
      Print("Erreur lors de la création de la flèche de prédiction: ", GetLastError());
      return;
   }
   
   // Configurer l'apparence de la flèche
   if(direction == POSITION_TYPE_BUY)
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
   }
   else
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 234); // Flèche vers le bas
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
   }
   
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
   
   Print("Flèche de prédiction dessinée sur ", symbol, " à ", TimeToString(time), " - Direction: ", 
         (direction == POSITION_TYPE_BUY ? "Achat" : "Vente"));
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
   
   // Envoi de la notification dans le terminal
   Print(signalText);
   
   // Envoi d'une notification push si activé
   if(InpShowNotification)
      SendNotification(signalText);
   
   // Envoi d'une alerte sonore si configuré
   if(InpAlertSound != "")
      PlaySound(InpAlertSound);
}

//+------------------------------------------------------------------+
//| Détection améliorée des spikes avec seuils dynamiques            |
//+------------------------------------------------------------------+
int DetectEarlySpikeSignal(const string symbol, double &signalStrength)
{
    if(!IsBoomCrashIndex(symbol)) return 0;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    // Obtenir plus de données pour une meilleure détection
   if(CopyRates(symbol, PERIOD_M1, 0, 20, rates) < 20) return 0;
   
   // Vérifier si on a déjà dessiné une flèche sur la bougie actuelle
   static datetime lastArrowTime = 0;
   if(lastArrowTime == rates[0].time) return 0; // Ne pas redessiner sur la même bougie
   lastArrowTime = rates[0].time;
    
    // Calculer la volatilité historique
    double atr = iATR(symbol, PERIOD_M1, 14);
    double currentRange = rates[0].high - rates[0].low;
    double avgRange = 0;
    for(int i = 1; i <= 10; i++) avgRange += (rates[i].high - rates[i].low);
    avgRange /= 10.0;
    
    // Seuils dynamiques
    double rangeRatio = (avgRange > 0) ? (currentRange / avgRange) : 0;
    
    // Si on détecte un potentiel spike, dessiner une flèche et déclencher une alerte
   if(rangeRatio > 1.5) // Exemple de condition de détection de spike
   {
       int direction = (rates[0].close > rates[0].open) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
       double arrowPrice = (direction == POSITION_TYPE_BUY) ? rates[0].low - 10*_Point : rates[0].high + 10*_Point;
       double signalStrength = MathMin(100.0, (rangeRatio - 1.0) * 100.0); // Force du signal en %
       
       // Dessiner la flèche sur le graphique
       DrawSpikePredictionArrow(symbol, direction, arrowPrice, rates[0].time);
   
       // Calculer les niveaux de SL/TP
       double entryPrice = (direction == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(symbol, SYMBOL_BID);
       double sl = (direction == POSITION_TYPE_BUY) ? 
                  entryPrice - InpStopLoss * _Point : 
                  entryPrice + InpStopLoss * _Point;
       double tp = (direction == POSITION_TYPE_BUY) ? 
                  entryPrice + InpTakeProfit * _Point : 
                  entryPrice - InpTakeProfit * _Point;
   
       // Envoyer la notification
       SendTradingSignalNotification(symbol, direction, entryPrice, sl, tp);
       
       // Exécuter le trade automatiquement si activé
       if(InpEnableAutoTrading && CanPlaceNewOrder(symbol, direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL))
       {
          double lotSize = CalculateOptimalLotSize(symbol, InpStopLossUSD);
          if(lotSize > 0)
          {
             // Utiliser l'objet trade global au lieu d'en créer un nouveau
             trade.SetExpertMagicNumber(InpMagicNumber);
             
             if(direction > 0)
                trade.Buy(lotSize, symbol, entryPrice, sl, tp, "Auto Trade - FC Angel Signal");
             else
                trade.Sell(lotSize, symbol, entryPrice, sl, tp, "Auto Trade - FC Angel Signal");
                 
             if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
                Print("Trade exécuté avec succès - ", symbol, " ", (direction > 0 ? "Achat" : "Vente"));
             else
                Print("Erreur d'exécution: ", trade.ResultRetcode());
          }
       }
       
       // Déclencher une alerte
       if(TimeCurrent() - g_lastAlertTime > 5) // Éviter les alertes trop fréquentes
       {
          TriggerSpikeAlert(symbol, direction, signalStrength);
          g_lastAlertTime = TimeCurrent();
       }
   }
    double volumeRatio = (rates[1].tick_volume > 0) ? 
                        (double)rates[0].tick_volume / rates[1].tick_volume : 1.0;
    
    // Détection précoce (dès le début du mouvement)
    bool isSpikeStarting = (rangeRatio > InpSpikeMinRangeRatio && volumeRatio > InpSpikeMinVolumeRatio);
    
    if(isSpikeStarting)
    {
        // Analyser la structure des chandeliers
        double bodySize = MathAbs(rates[0].close - rates[0].open);
        bool isBullish = (rates[0].close > rates[0].open);
        double bodyRatio = (currentRange > 0) ? (bodySize / currentRange) : 0;
        
        // Vérifier la force du mouvement
        if(bodyRatio > 0.5) // Au moins 50% du range est le corps
        {
            signalStrength = MathMin(100.0, (rangeRatio * 20) + (volumeRatio * 10));
            
            // Enregistrer les données du signal
            g_lastSpikeSignal.signalTime = TimeCurrent();
            g_lastSpikeSignal.price = isBullish ? rates[0].close : rates[0].open;
            g_lastSpikeSignal.direction = isBullish ? 1 : -1;
            g_lastSpikeSignal.active = true;
            g_lastSpikeSignal.symbol = symbol;
            g_lastSpikeSignal.signalStrength = signalStrength;
            g_lastSpikeSignal.atr = atr;
            g_lastSpikeSignal.volumeRatio = volumeRatio;
            
            return isBullish ? 1 : -1;
        }
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est un indice Boom ou Crash               |
//+------------------------------------------------------------------+
bool IsBoomCrashIndex(const string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

//+------------------------------------------------------------------+
//| Vérifie si une position est déjà ouverte sur ce symbole         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Ajouter un niveau à la liste des supports/résistances           |
//+------------------------------------------------------------------+
void AddLevel(const double price, const datetime time, const bool isSupport)
{
   const double tolerance = 10 * _Point;
   
   if(isSupport)
   {
      // Vérifier si un niveau similaire existe déjà
      for(int i = 0; i < g_supportLevelsCount; i++)
      {
         if(MathAbs(g_supportLevels[i].price - price) <= tolerance)
         {
            g_supportLevels[i].hits++;
            g_supportLevels[i].time = time;
            return;
         }
      }
      
      // Ajouter un nouveau niveau
      if(g_supportLevelsCount < 100)
      {
         g_supportLevels[g_supportLevelsCount].price = price;
         g_supportLevels[g_supportLevelsCount].time = time;
         g_supportLevels[g_supportLevelsCount].hits = 1;
         g_supportLevels[g_supportLevelsCount].isSupport = true;
         g_supportLevelsCount++;
      }
   }
   else
   {
      // Vérifier si un niveau similaire existe déjà
      for(int i = 0; i < g_resistanceLevelsCount; i++)
      {
         if(MathAbs(g_resistanceLevels[i].price - price) <= tolerance)
         {
            g_resistanceLevels[i].hits++;
            g_resistanceLevels[i].time = time;
            return;
         }
      }
      
      // Ajouter un nouveau niveau
      if(g_resistanceLevelsCount < 100)
      {
         g_resistanceLevels[g_resistanceLevelsCount].price = price;
         g_resistanceLevels[g_resistanceLevelsCount].time = time;
         g_resistanceLevels[g_resistanceLevelsCount].hits = 1;
         g_resistanceLevels[g_resistanceLevelsCount].isSupport = false;
         g_resistanceLevelsCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Tracer les niveaux de support/résistance sur le graphique       |
//+------------------------------------------------------------------+
void DrawSupportResistanceLevels()
{
   // Supprimer les anciens objets
   ObjectsDeleteAll(0, PREFIX + "SR_");
   
   // Tracer les supports
   for(int i = 0; i < g_supportLevelsCount; i++)
   {
      if(g_supportLevels[i].hits < 2) continue; // N'afficher que les niveaux touchés au moins 2 fois
      
      string name = StringFormat("%sSUP_%d", PREFIX, i);
      if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_supportLevels[i].price))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, SUPPORT_COLOR);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         
         // Ajouter une étiquette
         string label = StringFormat("S %d", g_supportLevels[i].hits);
         string labelName = name + "_LABEL";
         if(ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), g_supportLevels[i].price))
         {
            ObjectSetString(0, labelName, OBJPROP_TEXT, label);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, SUPPORT_COLOR);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         }
      }
   }
   
   // Tracer les résistances
   for(int i = 0; i < g_resistanceLevelsCount; i++)
   {
      if(g_resistanceLevels[i].hits < 2) continue; // N'afficher que les niveaux touchés au moins 2 fois
      
      string name = StringFormat("%sRES_%d", PREFIX, i);
      if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_resistanceLevels[i].price))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, RESISTANCE_COLOR);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         
         // Ajouter une étiquette
         string label = StringFormat("R %d", g_resistanceLevels[i].hits);
         string labelName = name + "_LABEL";
         if(ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), g_resistanceLevels[i].price))
         {
            ObjectSetString(0, labelName, OBJPROP_TEXT, label);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, RESISTANCE_COLOR);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         }
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Afficher une flèche de signal sur le graphique                  |
//+------------------------------------------------------------------+
void DrawSignalArrow(const string symbol, const int direction, const double price, const datetime time, const string text = "")
{
   string name = "Signal_" + symbol + "_" + IntegerToString(GetTickCount());
   int arrowCode = (direction > 0) ? 233 : 234; // 233=flèche vers le haut, 234=flèche vers le bas
   
   if(!ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
   {
      Print("Erreur création flèche: ", GetLastError());
      return;
   }
   
   // Définir les propriétés de la flèche
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (direction > 0) ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   
   // Ajouter un tooltip si du texte est fourni
   if(text != "")
      ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
   
   // Ajouter une étiquette avec l'heure
   string labelName = name + "_LABEL";
   string labelText = StringFormat("%s %s", (direction > 0) ? "▲" : "▼", TimeToString(time, TIME_MINUTES));
   
   if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price))
   {
      Print("Erreur lors de la création du label: ", GetLastError());
      return;
   }
   
   // Configurer l'étiquette
   ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, (direction > 0) ? clrLime : clrRed);
   ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   
   // Ajouter le texte du signal si fourni
   if(text != "")
   {
      string textName = name + "_TEXT";
      if(ObjectCreate(0, textName, OBJ_TEXT, 0, time, price))
      {
         ObjectSetString(0, textName, OBJPROP_TEXT, text);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, (direction > 0) ? clrLime : clrRed);
         ObjectSetInteger(0, textName, OBJPROP_BACK, true);
         ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_UPPER);
      }
   }
   
   // Rafraîchir le graphique
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Effacer tous les objets graphiques                               |
//+------------------------------------------------------------------+
void ClearAllDrawings()
{
   ObjectsDeleteAll(0, PREFIX);
   ChartRedraw();
}

//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Constantes pour les objets graphiques                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Structures pour les niveaux de support/résistance               |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
#include <Indicators/Indicators.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayDatetime.mqh>

CTrade trade;  // Global trade object for order management

// ===================================================================
// ANGEL OF SPIKE - SIMPLE SPIKE DETECTION
// Version simplifiée pour MetaTrader 5
// ===================================================================

input group "=== CONFIGURATION ==="
input bool   InpEnableTrading          = true;   // Activer le trading automatique   // Activer le trading
input int    InpMagicNumber            = 880011; // Magic number
input string InpAllowedSymbols         = "Boom 300 Index,Crash 300 Index,Boom 500 Index,Crash 500 Index,Boom 1000 Index,Crash 1000 Index"; // Symboles
input bool   InpTradeOtherSymbols      = false;  // Trader également les autres symboles (non Boom/Crash)

input group "=== RISK MANAGEMENT ULTRA-STRICT ==="
input double InpCapitalPerTradeUSD    = 10.00;  // Capital engagé par trade ($) - RÈGLE STRICTE
input double InpMaxLossBoomCrashUSD   = 1.50;   // Perte max Boom/Crash ($) - RÈGLE STRICTE (TP = 4.50$)
input double InpMaxLossOtherUSD       = 1.00;   // Perte max autres symboles ($) - RÈGLE STRICTE (TP = 3.00$)
input double InpStopLossUSD           = 1.50;   // Stop Loss en $ pour les ordres basés sur les Order Blocks
input double InpTargetProfitUSD       = 4.50;   // Gain cible par trade ($) - RÈGLE STRICTE (3x SL Boom/Crash)
input double InpMaxGlobalOpenLossUSD  = 3.50;   // Perte totale ouverte max (somme de toutes les positions) ($) - RÉDUIT
input int    InpMaxConcurrentSymbols   = 3;      // 3 symboles à la fois - Plus permissif
input int    InpMaxPositionsPerSymbol  = 2;      // Nombre maximum de positions par symbole
input int    InpMaxGlobalPositions     = 5;      // Nombre maximum total de positions
input bool   InpStrictRiskRules        = true;   // Appliquer les règles de risque strictes
input bool   InpCancelMultipleOrders   = true;   // Annuler tous les ordres si multiple trades demandés
input bool   InpCloseAfterSpike        = true;   // ACTIVÉ - Fermer automatiquement après spike détecté
input bool   InpStrictSignalOnly       = true;   // Ouvrir UNIQUEMENT si le signal passe (pas de fallback)
input bool   InpAutoClosePositions     = false;  // DÉSACTIVÉ - Fermer automatiquement à SL/TP strict
input bool   InpAllowManualTrading     = true;   // Autoriser les trades manuels (humains)

input group "=== NON-BOOM/CRASH AUTO-CLOSE (USD) ==="
input bool   InpEnableNonBCAutoClose   = true;   // Activer fermeture auto pour indices non Boom/Crash
input double InpNonBC_TP_USD           = 2.00;   // Prendre profit à +2$ (par défaut)
input double InpNonBC_SL_USD           = 2.00;   // Couper perte à -2$ (par défaut)

input group "=== VOLATILITY INDICES SCALPING ==="
input bool   InpEnableVolScalp         = true;   // Activer le scalping Volatility
input string InpVolSymbolsHint         = "Volatility"; // Sous-chaîne pour détecter les indices Volatility
input double InpVolTP_USD              = 2.00;   // TP fixe pour Volatility ($)
input double InpVolSL_USD              = 2.00;   // SL fixe pour Volatility ($)
input int    InpVolReentryDelaySec     = 8;      // Délai de re-entry après clôture (sec)
input double InpVolPeakRetracePct      = 50.0;   // Fermer si retracement de X% du pic de profit
input double InpVolMinProfitToLockUSD  = 0.50;   // Activer protection après ce gain ($)
input int    InpVolMaxCyclesPerTrend   = 0;      // 0 = illimité

input group "=== STRATÉGIE EMA BOOM/CRASH ==="
input int    InpEMA20_Period           = 30;     // Période EMA 30 (augmentée pour moins de faux signaux)
input int    InpEMA50_Period           = 75;     // Période EMA 75 (augmentée pour une tendance plus lisse)
input double InpEMATouchDistance       = 5.0;    // Distance max pour toucher EMA (points)
input double InpSpikeTargetUSD         = 3.0;    // Objectif profit spike (USD) - augmenté pour un meilleur ratio
input double InpSpikeStopLossUSD       = 1.0;    // Stop loss spike (USD) - maintenu serré
input int    InpSpikeCloseSeconds      = 30;     // Fermer après X secondes
input group "=== SIGNALISATION SPIKE ==="
input bool   InpShowSpikeArrow         = true;   // Afficher flèche de spike clignotante   // Afficher flèche avant spike
input color  InpBuyArrowColor         = clrLime;  // Couleur flèche d'achat
input color  InpSellArrowColor        = clrRed;   // Couleur flèche de vente
input int    InpArrowSize             = 3;        // Taille de la flèche (1-5)
input int    InpSpikePredictionWindow = 60;       // Fenêtre de prédiction du spike (secondes)
input int    InpArrowBlinkSeconds      = 3;      // Durée clignotement flèche de spike (secondes)      // Durée clignotement flèche (secondes)

input group "=== INTEGRATION / TEST MODE ==="
input group "=== PROBABILITÉ SPIKE M1 ==="
input double   InpMinSpikeM1Probability  = 50.0;   // Probabilité minimale M1 (0-100%) pour exécution automatique   // Probabilité minimale M1 (0-100%) pour exécution automatique
input double InpConfluenceMinScore     = 80.0;   // Score minimal (0-100) pour autoriser l'entrée (DÉSACTIVÉ)
input double InpW_ATR                  = 0.35;   // Poids ATR multiple (DÉSACTIVÉ)
input double InpW_Wick                 = 0.25;   // Poids ratio mèche/corps (DÉSACTIVÉ)
input int    InpSignalConfirmDelaySec  = 4;      // Délai de confirmation avant exécution (secondes)
input double InpRecheckMinProbability  = 85.0;   // Probabilité minimale après recheck pour exécution
input double InpW_SR                   = 0.15;   // Poids proximité S/R (DÉSACTIVÉ)
input double InpW_OBOTE                = 0.15;   // Poids OrderBlock + OTE (DÉSACTIVÉ)
input double InpW_MTF                  = 0.10;   // Poids alignement MTF (DÉSACTIVÉ)
input double InpW_Squeeze              = 0.10;   // Bonus post-squeeze (capé) (DÉSACTIVÉ)

input bool   InpAggressiveTestMode     = false;   // Ignore certains filtres pour valider l'intégration (désactivé)
input bool   InpOnlyCurrentSymbol      = false;   // Ne scanner que le symbole du graphique (désactivé)
input bool   InpPrioritizeBoomCrash    = true;    // Scanner Boom/Crash en priorité
input double InpMinProbBoomCrash       = 50.0;    // Seuil probabilité M1 pour Boom/Crash - RÉDUIT    // Seuil probabilité M1 pour Boom/Crash
input int    InpCooldownSecondsBC      = 30;      // Cooldown plus court pour Boom/Crash
input double InpBCLotFixed             = 0.20;    // Lot fixe obligatoire pour Boom/Crash
input int    InpBCReentryCooldownSec   = 8;       // Cooldown spécial re-entry après spike (BC)

input group "=== SIGNAL & EXECUTION ==="
input bool   InpTradeOnSpikeImmediately= true;   // Exécuter le trade dès l'affichage de la flèche clignotante   // Exécuter le trade dès l'affichage de la flèche
input bool   InpShowSpikeArrows        = true;   // Afficher les flèches prédictives sur tous les graphiques   // Afficher les flèches prédictives sur tous les graphiques
input bool   InpCancelDuplicates       = true;   // Annuler les ordres dupliqués
input double InpQuickCloseUSD          = 0.0;     // DÉSACTIVÉ - Fermer rapidement si profit ≥ $ (pas de sortie prématurée)
input double InpQuickCloseATRMult      = 0.0;    // DÉSACTIVÉ - Fermer si move ≥ k*ATR après entrée (pas de sortie prématurée)
input bool   InpExitOnCounterSpike     = false;  // DÉSACTIVÉ - Fermer si spike opposé détecté (pas de sortie prématurée)

input group "=== MULTI-TF TREND GATE ==="
input bool   InpUseMTFGate             = true;   // ACTIVÉ - N'entrer que dans le sens de la tendance
input bool   InpStrictTrendFollowing   = true;   // Respecter strictement la tendance (ne jamais trader contre)
input int    InpEMAFast                = 50;
input int    InpEMASlow                = 200;
input int    InpTrendTimeframes        = 4;      // Nombre de timeframes pour confirmer la tendance (augmenté pour une meilleure confirmation)

input group "=== ORDERS ==="
input double InpDefaultLot             = 0.2;   // Lot par défaut (PETIT)
input double InpMaxLotSize             = 0.5;    // Lot maximum autorisé (PLAFOND)
input bool   InpAllowLimitOrders       = true;   // Placer des LIMIT prudents (ACTIVÉ)
input bool   InpAllowStopOrders        = true;   // Placer des STOP orders
input bool   InpSmartOrderPlacement     = true;   // Placement intelligent des ordres
input int    InpSlippagePoints         = 10;     // Slippage
input int    InpMaxSpreadPoints        = 10000;  // ULTRA AUGMENTÉ - Spread max autorisé (points)
input int    InpMinSecondsBetweenOrders= 5;      // Attendre 5 sec entre trades
input int    InpMinSecondsBetweenSameSymbol= 60;  // Attendre 60 sec entre trades sur même symbole (augmenté pour réduire le surtrading)

input group "=== PROTECTION ANTI-CASCADE ==="
input int      InpMinTradeDurationSeconds = 30;    // Durée minimum d'un trade (secondes)
input int      InpMaxTradesPerMinute = 2;          // Max trades par minute par symbole
input bool     InpPreventRapidOpenClose = true;    // Empêcher ouverture/fermeture rapide
input double   InpMinProfitToClose = 2.0;          // Profit minimum pour fermeture auto ($)
input int      InpTradeStabilityCheckSeconds = 60; // Vérifier stabilité avant fermeture (s)
input int      InpMinCooldownMinutes = 10;         // Cooldown minimum entre trades (min)

input group "=== GESTION DES SPIKES BOOM/CRASH ==="
input bool   InpEnableBoomCrashDetection = true;   // Activer la détection Boom/Crash
input double InpBoomCrashSpikeThreshold = 0.5;     // Seuil de détection des spikes (en %)
input int    InpBoomCrashLookbackBars = 10;        // Nombre de bougies pour l'analyse
input int    InpBoomCrashMinBarsBetweenTrades = 3; // Nombre min de boucles entre 2 trades
input int      InpSpikeCloseDelaySeconds = 5;      // Délai avant fermeture après spike (secondes)
input double   InpSpikeProfitMultiplier  = 1.5;    // Multiplier le profit pendant les spikes
input bool     InpWaitForSpikePeak       = true;   // Attendre le pic du spike avant fermeture
input int      InpSpikePeakWaitSeconds   = 10;     // Temps d'attente pour le pic (secondes)
input double   InpSpikeReversalThreshold = 0.3;    // Seuil de retournement pour fermer (ATR)

input group "=== SL/TP FALLBACK (SI TICK VALUE INDISPONIBLE) ==="
input bool   InpUseFallbackPercentSLTP = true;   // Utiliser pourcentage si $/point inconnu
input double InpSLPercent              = 0.50;   // SL = 0.50% du prix (plus large pour éviter faux signaux)
input double InpTPPercent              = 0.30;   // TP = 0.30% du prix (plus petit pour sortie rapide)
input int    InpStopsBufferPoints      = 10;      // Buffer (points) autour des niveaux d'entrée/SL/TP

input group "=== HUD ==="
input bool   InpShowHUD                = true;   // Afficher HUD avancé
input color  InpHUDColor               = clrWhite;
input color  InpHUDAccent              = clrDeepSkyBlue;
input int    InpHUDX                   = 8;      // Position X du HUD principal
input int    InpHUDY                   = 20;     // Position Y du HUD principal
input int    InpHUDLineSpacing         = 16;     // Espacement entre lignes (augmenté)
input int    InpHUDColumn2X            = 300;    // Position X de la colonne 2
input int    InpHUDMoneyX              = 1200;   // Position X du money management (angle droit)
input int    InpHUDMoneyY              = 400;   // Position Y du money management (angle bas)
input bool   InpShowForecastArrows     = true;   // Afficher flèches de prévision
input int    InpForecastHours          = 2;      // Projection en heures (max 2 flèches)


//+------------------------------------------------------------------+
//| CONFIGURATION PAR DEFAUT INTEGREE - TRADING AUTOMATIQUE SPIKE    |
//+------------------------------------------------------------------+
// 
// SYSTEME DE FLECHES CLIGNOTANTES:
// 1. FLECHE DE TENDANCE (statique): Indique la direction generale
// 2. FLECHE DE SPIKE (clignotante): Annonce un spike imminent
// 3. TRADING AUTOMATIQUE: Position ouverte des l'affichage de la fleche clignotante
//
// PARAMETRES CRITIQUES:
// - InpTradeOnSpikeImmediately = true (CRITIQUE)
// - InpMinSpikeM1Probability = 50.0 (reduit pour plus de trades)
// - InpMaxGlobalPositions = 1 (securite renforcee)
// - InpArrowBlinkSeconds = 3 (duree clignotement)
// - InpShowSpikeArrow = true (affichage fleches)
//
//+------------------------------------------------------------------+
input group "=== DEBUG ==="
input bool   InpDebug = true;   // Logs de diagnostic (skips, erreurs)

input group "=== NOTIFICATIONS ==="
input bool   InpEnableAlerts     = true;   // Activer les alertes de spike
input bool   InpSendNotifications = true;   // Envoyer notification push sur exécutions
input bool   InpAlertPopup             = true;   // Alerte popup locale sur exécutions
input string InpNotifyTag              = "Angel"; // Préfixe messages
input bool   InpNotifyPreSpike         = true;   // Notifier le pré-spike (M1, bar avant)

input group "=== BOOM/CRASH SPIKE SCALPING ==="
input bool   InpBCForceDirection       = true;   // Forcer BUY sur Boom*, SELL sur Crash*
input double InpBCScalpUSD             = 0.60;   // Fermer dès +X USD sur Boom/Crash
input bool   InpBCSpikeReEntry         = true;   // NOUVEAU: Rentrer après fermeture spike si conditions bonnes
input double InpBCSpikeReEntryMinProb  = 60.0;   // Probabilité minimale pour re-entry après spike
input int    InpBCSpikeReEntryDelaySec = 5;      // Délai minimum (secondes) avant re-entry
input int    InpBCLadderLevels         = 0;      // DÉSACTIVÉ - Niveaux LIMIT en échelle après entrée
input int    InpBCLadderStepPts        = 20;     // DÉSACTIVÉ - Écart (points) entre LIMIT
input int    InpBCLadderTTLMin         = 3;      // DÉSACTIVÉ - Durée de validité LIMIT (minutes)
input int    InpBCAntiOvertradeMin     = 2;      // Cooldown anti-surcharge (minutes)
input int    InpBCCircuitLosses        = 2;      // Pertes consécutives pour pause
input int    InpBCCircuitWindowMin     = 10;     // Fenêtre (minutes) des pertes
input int    InpBCCircuitPauseMin      = 10;     // Pause (minutes) après déclenchement
input bool   InpBCFallbackEntries      = false;   // DÉSACTIVÉ - Entrées fallback si aucun spike
input bool   InpBCAutoTrigger          = true;    // Déclencher automatiquement STOP sur Boom/Crash
input int    InpBCEntryBufferPts       = 10;      // Buffer (points) au-dessus/au-dessous du high/low M1

input group "=== ICT / PRICE ACTION ==="
input bool   InpEnableICT              = true;   // Activer ICT (BOS/COS/OB/OTE)
input ENUM_TIMEFRAMES InpICT_TF        = PERIOD_M5; // TF d'analyse structurelle
input int    InpSwingLen               = 3;      // Longueur swing pour HH/LL
input int    InpICTLookbackBars        = 300;    // Barres à analyser
input double InpMinOBBodyATR           = 0.5;    // Corps OB min en x*ATR
input double InpOTE_1                  = 0.62;   // Fib OTE bas
input double InpOTE_2                  = 0.79;   // Fib OTE haut
input bool   InpICTDraw                = true;   // Dessiner éléments ICT
input bool   InpICTTrade               = true;   // Entrer sur OB+OTE
input int    InpEMA_Fast_ICT           = 50;     // EMA rapide pour tendance
input int    InpEMA_Slow_ICT           = 200;    // EMA lente pour tendance
input bool   InpOBAutoTrade            = true;   // Entrer automatiquement dans la zone d'orderblock vérifié
input double InpOBLot                  = 0.20;   // Lot fixe pour exécution OB

input group "=== CONFIGURATION GENERALE ==="
input bool   InpRequireAllIndicators = false;  // Bloquer si un indicateur échoue

input group "=== INDICATEURS TECHNIQUES ==="
input group "=== RSI SUPPORT/RESISTANCE ==="
input bool   InpUseRSI                 = true;   // Activer l'utilisation du RSI
input int    InpRSIPeriod1             = 7;      // Période du premier RSI
input int    InpRSIPeriod2             = 14;     // Période du deuxième RSI
input ENUM_APPLIED_PRICE InpRSIPrice   = PRICE_CLOSE; // Prix appliqué pour le RSI
input double InpRSIOverbought          = 70.0;   // Niveau de surachat
input double InpRSIOversold            = 30.0;   // Niveau de survente
input int    InpRSILookback            = 20;     // Période de lookback pour les niveaux S/R

// Paramètres VWAP
input bool   InpShowVWAP               = true;   // Afficher la VWAP
input int    InpVWAPPeriod             = 20;     // Période de la VWAP
input color  InpVWAPColor              = clrDodgerBlue; // Couleur de la VWAP
input int    InpVWAPWidth              = 1;      // Épaisseur de la VWAP

// Paramètres Supertrend
input bool   InpShowSuperTrend         = true;   // Afficher le Supertrend
input int    InpSTPeriod               = 10;     // Période du Supertrend
input double InpSTMultiplier           = 3.0;    // Multiplicateur ATR du Supertrend
input color  InpSTUpColor              = clrLime;  // Couleur tendance haussière
input color  InpSTDnColor              = clrRed;   // Couleur tendance baissière
input int    InpSTWidth                = 2;      // Épaisseur du Supertrend

// Paramètres Volume Profile
input bool   InpShowVolumeProfile      = true;   // Afficher le Volume Profile
input int    InpVPLookback             = 50;     // Nombre de boucles à analyser
input int    InpVPBars                 = 5;      // Nombre de niveaux de prix à afficher
input color  InpVPColor                = C'0,32,0'; // Couleur du Volume Profile

// Paramètres TTM Squeeze
input bool   InpShowSqueeze            = true;   // Afficher le TTM Squeeze
input int    InpSqueezeBBPeriod        = 20;     // Période des Bandes de Bollinger
input int    InpSqueezeKCPeriod        = 20;     // Période du Keltner Channel
input double InpSqueezeBBMult          = 2.0;    // Multiplicateur BB
input double InpSqueezeKCMult          = 1.5;    // Multiplicateur KC
input color  InpSqueezeNoColor         = clrGray;  // Couleur neutre
input color  InpSqueezeLongColor       = clrLime;  // Signal d'achat
input color  InpSqueezeShortColor      = clrRed;   // Signal de vente

input group "=== OVERLAYS (EMA / BOLLINGER / ENVELOPES) ==="
// Les paramètres InpShowEMAOverlay, InpShowBollinger et InpShowEnvelopes sont déjà définis plus haut
input int    InpBB_Period_Overlay      = 20;     // Période des Bandes de Bollinger
input double InpBB_Deviation_Overlay   = 2.0;    // Déviation standard pour BB
input int    InpEnv_Period             = 20;     // Période des Enveloppes
input double InpEnv_Deviation_Pct      = 0.5;    // % de déviation pour les Enveloppes

input group "=== SUPPORT/RESISTANCE (D1..M30) ==="
input bool   InpEnableSR               = true;   // Activer détection S/R multi-timeframe
input int    InpSRLookbackBars         = 150;    // Barres à analyser par TF
input double InpSRProximityPct         = 0.0008; // Proximité requise (0.08%)
input bool   InpDrawSRZones            = true;   // Dessiner niveaux S/R
input bool   InpRequireSRProximity     = false;  // DÉSACTIVÉ - Exiger proximité S/R pour entrer
input bool   InpPrioritizeICTFibo      = true;   // PRIORITÉ MAX: ICT FIBO (S/R) avant spikes
input double InpICTFiboConfidence      = 95.0;   // Confiance ICT FIBO (95% par défaut)

input group "=== SESSION / OBJECTIFS QUOTIDIENS ==="
input double InpDailyTargetPercent     = 10.0;   // Objectif gain journalier (%)
input double InpDailyDrawdownPercent   = 10.0;   // Stop perte journalier (%)
input int    InpMaxConsecutiveLosses   = 4;      // Stop après N pertes consécutives

input group "=== SCALPING AUTOMATIQUE (DÉSACTIVÉ) ==="
input bool   InpEnableAutoScalping     = false;  // DÉSACTIVÉ - Scalping automatique
input bool   InpScalpTrendOnly         = false;  // DÉSACTIVÉ - Scalper uniquement dans le sens de la tendance
input int    InpScalpMinIntervalSec    = 60;     // DÉSACTIVÉ - Intervalle minimum entre scalps (secondes)
input double InpScalpMaxLossUSD        = 3.50;   // DÉSACTIVÉ - Perte max par scalp ($)
input double InpScalpTargetProfitUSD   = 5.00;   // DÉSACTIVÉ - Gain cible par scalp ($)
input bool   InpScalpUseTrendAPI       = false;  // DÉSACTIVÉ - Utiliser l'API de tendance pour scalping
input string InpTrendAPIUrl            = "http://localhost:8005/trend"; // DÉSACTIVÉ - URL de l'API de tendance

// State
CTrade        g_trade;  // Objet pour gérer les opérations de trading
datetime      g_lastScan = 0;
datetime      g_lastTradeBySymbol[10]; // Track last trade time per symbol

// Pending signal (two-step confirmation)
string        g_pendingSymbol = "";
int           g_pendingDirection = 0;
double        g_pendingProbability = 0.0;
datetime      g_pendingTime = 0;

// Volatility scalping state
string        g_volSymbols[20];
datetime      g_volLastCloseTime[20];
// Track peak profit per ticket (limited size)
ulong         g_volTickets[40];
double        g_volPeakProfit[40];
int           g_volTicketN = 0;

// Variable pour le dernier ordre
datetime g_lastOrderTime = 0;
string        g_lastSymbols[10];       // Track symbols
datetime      g_lastOrderTs = 0;

// HUD state
datetime      g_lastHud = 0;
int           g_hudRefreshSec = 1;
bool          g_isSpikePredicted = false; // Variable pour différencier spike prédit vs immédiat

// SR buffers
double        g_srLevelsD1[50]; int g_srND1=0;
double        g_srLevelsH4[50]; int g_srNH4=0;
double        g_srLevelsH1[50]; int g_srNH1=0;
double        g_srLevelsM30[50];int g_srNM30=0;

// Overlay indicator handles (to draw real lines on chart)
int           g_hEMA1 = INVALID_HANDLE;
int           g_hEMA2 = INVALID_HANDLE;
int           g_hEMA3 = INVALID_HANDLE;
int           g_hEMA4 = INVALID_HANDLE;
int           g_hEMA5 = INVALID_HANDLE;
int           g_hBB   = INVALID_HANDLE;
int           g_hEnv  = INVALID_HANDLE;
int           g_hEMA20 = INVALID_HANDLE; // EMA 20 pour stratégie Boom/Crash
int           g_hEMA50 = INVALID_HANDLE; // EMA 50 pour stratégie Boom/Crash

// Variables pour flèche clignotante
datetime      g_arrowStartTime = 0;      // Heure de début du clignotement
string        g_arrowSymbol = "";        // Symbole de la flèche active
int           g_arrowDirection = 0;      // Direction de la flèche (1=BUY, -1=SELL)
bool          g_arrowVisible = false;    // État de visibilité de la flèche

// Session state
double        g_startBalanceToday = 0.0;
int           g_tradesToday = 0;
int           g_consecLosses = 0;
bool          g_dayStopped = false;

// Money Management Statistics
double        g_totalProfit = 0.0;
double        g_totalLoss = 0.0;
int           g_totalWins = 0;
int           g_totalLosses = 0;
double        g_initialBalance = 0.0;

// Variables globales pour les indicateurs techniques
// RSI
int g_rsi1_handle = INVALID_HANDLE;  // Handle pour le RSI 7 périodes
int g_rsi2_handle = INVALID_HANDLE;  // Handle pour le RSI 14 périodes

// VWAP
int g_vwap_handle = INVALID_HANDLE;  // Handle pour la VWAP

// Supertrend
int g_supertrend_handle = INVALID_HANDLE;  // Handle pour le Supertrend
int g_supertrend_signal = 0;  // Dernier signal Supertrend (1=acheteur, -1=vendeur, 0=neutre)

// Volume Profile
double g_vp_poc = 0.0;        // Point of Control (niveau de prix avec le plus de volume)
double g_vp_high_volume_area = 0.0;  // Zone de volume élevé
double g_vp_low_volume_area = 0.0;   // Zone de volume faible

// TTM Squeeze
int g_squeeze_handle = INVALID_HANDLE;  // Handle pour le TTM Squeeze
bool g_squeeze_active = false;  // Indique si le marché est en phase de compression (squeeze)

// Les variables g_arrowSymbol et g_arrowStartTime sont déjà déclarées plus haut

// Gestion des pics de volume - Variables déjà définies plus haut dans le code

// Définition de la constante INVALID_HANDLE si elle n'est pas déjà définie
#ifndef INVALID_HANDLE
   #define INVALID_HANDLE -1
#endif

// Handles pour les indicateurs techniques
int g_rsi_handle = INVALID_HANDLE;  // Handle pour l'indicateur RSI

// Variable de sécurité pour bloquer le trading en cas de conflits
bool          g_tradingBlocked = false;
datetime      g_blockUntil = 0;

// Boom/Crash control state
datetime      g_bcSymbolCooldownUntil[20];   // Per symbol cooldown
string        g_bcCooldownSymbols[20];       // Symboles en cooldown
datetime      g_bcLossTimestamps[10];        // Circular buffer of recent loss times
int           g_bcLossIdx = 0;               // Index pour le buffer circulaire des pertes

//+------------------------------------------------------------------+
//| Initialise les indicateurs techniques                            |
//+------------------------------------------------------------------+
bool InitializeTechnicalIndicators()
{
   bool result = true;
   
   // Initialisation du RSI
   if(InpUseRSI) {
      if(!InitializeRSI()) {
         Print("⚠️ Échec de l'initialisation du RSI");
         if(InpRequireAllIndicators) return false;
         result = false;
      }
   }
   
   // Initialisation de la VWAP
   if(InpShowVWAP) {
      ResetLastError();
      g_vwap_handle = iCustom(_Symbol, _Period, "Examples\\VWAP");
      if(g_vwap_handle == INVALID_HANDLE) {
         int error = GetLastError();
         Print("⚠️ Erreur ", error, " lors du chargement de la VWAP");
         if(InpRequireAllIndicators) return false;
         result = false;
      } else {
         Print("✅ VWAP initialisé avec succès (Période: ", InpVWAPPeriod, ")");
      }
   }
   
   // Initialisation du Supertrend
   if(InpShowSuperTrend) {
      ResetLastError();
      g_supertrend_handle = iCustom(_Symbol, _Period, "Examples\\ATR_Stop_System", 
                                   InpSTPeriod, InpSTMultiplier);
      if(g_supertrend_handle == INVALID_HANDLE) {
         int error = GetLastError();
         Print("⚠️ Erreur ", error, " lors du chargement du Supertrend");
         if(InpRequireAllIndicators) return false;
         result = false;
      } else {
         Print("✅ Supertrend initialisé avec succès (Période: ", InpSTPeriod, 
               ", Multiplicateur: ", InpSTMultiplier, ")");
      }
   }
   
   // Initialisation du TTM Squeeze
   if(InpShowSqueeze) {
      ResetLastError();
      g_squeeze_handle = iCustom(_Symbol, _Period, "TTM_Squeeze", 
                                InpSqueezeBBPeriod, InpSqueezeBBMult, 
                                InpSqueezeKCPeriod, InpSqueezeKCMult);
      if(g_squeeze_handle == INVALID_HANDLE) {
         int error = GetLastError();
         Print("⚠️ Erreur ", error, " lors du chargement du TTM Squeeze");
         Print("Assurez-vous que l'indicateur TTM_Squeeze est installé dans le dossier MQL5/Indicators/");
         if(InpRequireAllIndicators) return false;
         result = false;
      } else {
         Print("✅ TTM Squeeze initialisé avec succès");
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialise les indicateurs RSI                                   |
//+------------------------------------------------------------------+
bool InitializeRSI()
{
   // Libérer les handles existants s'ils sont valides
   if(g_rsi1_handle != INVALID_HANDLE) IndicatorRelease(g_rsi1_handle);
   if(g_rsi2_handle != INVALID_HANDLE) IndicatorRelease(g_rsi2_handle);
   
   // Créer les indicateurs RSI avec les périodes spécifiées
   g_rsi1_handle = iRSI(_Symbol, _Period, InpRSIPeriod1, InpRSIPrice);
   g_rsi2_handle = iRSI(_Symbol, _Period, InpRSIPeriod2, InpRSIPrice);
   
   // Vérifier que les handles sont valides
   if(g_rsi1_handle == INVALID_HANDLE || g_rsi2_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création des indicateurs RSI - ", 
            "RSI1 handle: ", g_rsi1_handle, 
            ", RSI2 handle: ", g_rsi2_handle);
      return false;
   }
   
   Print("Indicateurs RSI initialisés avec succès (", 
         InpRSIPeriod1, " et ", InpRSIPeriod2, " périodes)");
   return true;
}

//+------------------------------------------------------------------+
//| Met à jour les indicateurs techniques                            |
//+------------------------------------------------------------------+
void UpdateTechnicalIndicators()
{
   // Mise à jour du Volume Profile
   if(InpShowVolumeProfile) {
      UpdateVolumeProfile();
   }
   
   // Mise à jour du signal Supertrend
   if(InpShowSuperTrend) {
      UpdateSuperTrendSignal();
   }
   
   // Mise à jour de l'état du TTM Squeeze
   if(InpShowSqueeze) {
      UpdateSqueezeStatus();
   }
}

//+------------------------------------------------------------------+
//| Met à jour le Volume Profile                                     |
//+------------------------------------------------------------------+
void UpdateVolumeProfile()
{
   // Implémentation simplifiée du Volume Profile
   // Note: Une implémentation complète nécessiterait un calcul plus complexe
   long volumeBuffer[];
   double highBuffer[];
   double lowBuffer[];
   
   // Récupérer les données de prix et de volume
   if(CopyTickVolume(_Symbol, _Period, 0, InpVPLookback, volumeBuffer) <= 0 ||
      CopyHigh(_Symbol, _Period, 0, InpVPLookback, highBuffer) <= 0 ||
      CopyLow(_Symbol, _Period, 0, InpVPLookback, lowBuffer) <= 0) {
      return;
   }
   
   // Calculer le Point of Control (POC)
   // Note: Ceci est une implémentation simplifiée
   double totalVolume = 0.0;
   for(int i = 0; i < InpVPLookback; i++) {
      totalVolume += (double)volumeBuffer[i];
   }
   
   g_vp_poc = (totalVolume > 0) ? (highBuffer[0] + lowBuffer[0]) / 2 : 0;
   
   // Mettre à jour les zones de volume (simplifié)
   g_vp_high_volume_area = highBuffer[ArrayMaximum(highBuffer, 0, InpVPLookback)];
   g_vp_low_volume_area = lowBuffer[ArrayMinimum(lowBuffer, 0, InpVPLookback)];
}

//+------------------------------------------------------------------+
//| Met à jour le signal Supertrend                                  |
//+------------------------------------------------------------------+
void UpdateSuperTrendSignal()
{
   if(g_supertrend_handle == INVALID_HANDLE) return;
   
   double stBuffer[];
   double stSignal[];
   
   // Récupérer les données du Supertrend
   if(CopyBuffer(g_supertrend_handle, 0, 0, 1, stBuffer) <= 0 ||
      CopyBuffer(g_supertrend_handle, 1, 0, 1, stSignal) <= 0) {
      return;
   }
   
   // Déterminer le signal (1 = haussier, -1 = baissier, 0 = neutre)
   double close = iClose(_Symbol, _Period, 0);
   g_supertrend_signal = (close > stBuffer[0]) ? 1 : (close < stBuffer[0]) ? -1 : 0;
}

//+------------------------------------------------------------------+
//| Met à jour l'état du TTM Squeeze                                 |
//+------------------------------------------------------------------+
void UpdateSqueezeStatus()
{
   if(g_squeeze_handle == INVALID_HANDLE) return;
   
   double squeezeBuffer[];
   
   // Récupérer les données du TTM Squeeze
   if(CopyBuffer(g_squeeze_handle, 0, 0, 1, squeezeBuffer) <= 0) {
      return;
   }
   
   // Mettre à jour l'état de compression
   g_squeeze_active = (squeezeBuffer[0] == 1);
}

// Signal de-duplication per symbol (only once per bar per direction)
string        g_sigSymbols[20];
datetime      g_sigBarTime[20];
int           g_sigDir[20];

// Recent order guard (symbol + direction short-term cooldown)
string        g_recentOrderSymbols[20];
int           g_recentOrderDirs[20];
datetime      g_recentOrderTimes[20];

// Protection anti-cascade
struct TradeHistory {
    string symbol;
    datetime open_time;
    datetime close_time;
    int direction;
    double profit;
    bool was_closed_early;
};

TradeHistory g_trade_history[100];
int g_trade_history_count = 0;
datetime g_last_trade_time_by_symbol[64];
int g_trades_per_minute_by_symbol[64];

// Gestion des spikes
struct SpikeState {
    string symbol;             // Symbole du trade
    ulong ticket;              // Ticket de la position
    datetime spike_detected_time; // Heure de détection du spike
    double spike_start_price;  // Prix au moment du spike
    double max_profit;         // Profit maximum atteint
    double max_profit_reached; // Maximum de profit atteint (pour détection de pic)
    bool is_trailing;          // Si le trailing stop est activé
    bool waiting_for_peak;     // En attente du pic de prix
    bool spike_closed;         // Si le spike est clôturé
};

SpikeState g_spike_states[50];
int g_spike_states_count = 0;

//+------------------------------------------------------------------+
//| Ajoute un nouvel état de spike                                   |
//+------------------------------------------------------------------+
void AddSpikeState(string symbol, ulong ticket, double spike_start_price)
{
    // Vérifier si le ticket existe déjà
    for(int i = 0; i < g_spike_states_count; i++)
    {
        if(g_spike_states[i].ticket == ticket)
        {
            // Mettre à jour l'état existant
            g_spike_states[i].spike_detected_time = TimeCurrent();
            g_spike_states[i].spike_start_price = spike_start_price;
            g_spike_states[i].max_profit = 0.0;
            g_spike_states[i].is_trailing = false;
            g_spike_states[i].waiting_for_peak = true;
            g_spike_states[i].spike_closed = false;
            return;
        }
    }
    
    // Ajouter un nouvel état si nous n'avons pas dépassé la limite
    if(g_spike_states_count < 50)
    {
        g_spike_states[g_spike_states_count].symbol = symbol;
        g_spike_states[g_spike_states_count].ticket = ticket;
        g_spike_states[g_spike_states_count].spike_detected_time = TimeCurrent();
        g_spike_states[g_spike_states_count].spike_start_price = spike_start_price;
        g_spike_states[g_spike_states_count].max_profit = 0.0;
        g_spike_states[g_spike_states_count].is_trailing = false;
        g_spike_states[g_spike_states_count].waiting_for_peak = true;
        g_spike_states[g_spike_states_count].spike_closed = false;
        g_spike_states_count++;
        
        if(InpDebug) Print("[Angel] Nouvel état de spike ajouté pour ", symbol, " #", ticket);
    }
    else
    {
        if(InpDebug) Print("[Angel] Impossible d'ajouter un nouvel état de spike - limite atteinte (50)");
    }
}

//+------------------------------------------------------------------+
//| Supprime un état de spike                                        |
//+------------------------------------------------------------------+
void RemoveSpikeState(string symbol, ulong ticket)
{
    for(int i = 0; i < g_spike_states_count; i++)
    {
        if(g_spike_states[i].ticket == ticket && g_spike_states[i].symbol == symbol)
        {
            // Déplacer les éléments suivants pour combler le vide
            for(int j = i; j < g_spike_states_count - 1; j++)
            {
                g_spike_states[j] = g_spike_states[j + 1];
            }
            g_spike_states_count--;
            
            if(InpDebug) Print("[Angel] État de spike supprimé pour ", symbol, " #", ticket);
            return;
        }
    }
    
    if(InpDebug) Print("[Angel] État de spike non trouvé pour ", symbol, " #", ticket);
}

// Helpers
bool   IsDirectionAllowedBC(const string symbol, const int direction)
{
   if(!IsBoomCrashIndex(symbol)) return true;
   
   // RÈGLE STRICTE: Seules les directions correctes sont autorisées
   if(StringFind(symbol, "Boom")>=0 && direction!=POSITION_TYPE_BUY)  
   {
      if(InpDebug) Print("🚫 DIRECTION INTERDITE: SELL sur ", symbol, " - Seuls les BUY sont autorisés");
      return false; // Pas de signal
   }
   if(StringFind(symbol, "Crash")>=0 && direction!=POSITION_TYPE_SELL) 
   {
      if(InpDebug) Print("🚫 DIRECTION INTERDITE: BUY sur ", symbol, " - Seuls les SELL sont autorisés");
      return false; // Pas de signal
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Protection anti-cascade                                         |
//+------------------------------------------------------------------+
bool IsTradeTooRecent(string symbol)
{
    datetime now = TimeCurrent();
    
    // Vérifier le cooldown minimum entre trades
    for(int i = 0; i < 64; i++)
    {
        if(g_last_trade_time_by_symbol[i] == 0) continue;
        
        if(now - g_last_trade_time_by_symbol[i] < InpMinCooldownMinutes * 60)
        {
            return true;
        }
    }
    
    return false; // Pas de signal
}

bool IsTooManyTradesPerMinute(string symbol)
{
    datetime now = TimeCurrent();
    int trades_this_minute = 0;
    
    // Compter les trades de la dernière minute
    for(int i = 0; i < g_trade_history_count; i++)
    {
        if(g_trade_history[i].symbol == symbol && 
           now - g_trade_history[i].open_time < 60)
        {
            trades_this_minute++;
        }
    }
    
    return trades_this_minute >= InpMaxTradesPerMinute;
}

bool IsTradeDurationTooShort(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
    datetime now = TimeCurrent();
    
    return (now - open_time) < InpMinTradeDurationSeconds;
}

bool ShouldPreventRapidClose(ulong ticket)
{
    if(!InpPreventRapidOpenClose) return false;
    
    // Vérifier si le trade est trop récent
    if(IsTradeDurationTooShort(ticket))
    {
        return true;
    }
    
    // Vérifier l'historique des fermetures rapides
    string symbol = PositionGetString(POSITION_SYMBOL);
    int rapid_closes = 0;
    
    for(int i = 0; i < g_trade_history_count; i++)
    {
        if(g_trade_history[i].symbol == symbol && 
           g_trade_history[i].was_closed_early &&
           TimeCurrent() - g_trade_history[i].close_time < InpTradeStabilityCheckSeconds)
        {
            rapid_closes++;
        }
    }
    
    return rapid_closes >= 2; // Bloquer si 2 fermetures rapides récentes
}

void RecordTradeHistory(string symbol, datetime open_time, datetime close_time, int direction, double profit, bool was_closed_early)
{
    if(g_trade_history_count < 100)
    {
        g_trade_history[g_trade_history_count].symbol = symbol;
        g_trade_history[g_trade_history_count].open_time = open_time;
        g_trade_history[g_trade_history_count].close_time = close_time;
        g_trade_history[g_trade_history_count].direction = direction;
        g_trade_history[g_trade_history_count].profit = profit;
        g_trade_history[g_trade_history_count].was_closed_early = was_closed_early;
        g_trade_history_count++;
    }
}

void UpdateLastTradeTimeAntiCascade(string symbol)
{
    for(int i = 0; i < 64; i++)
    {
        if(g_last_trade_time_by_symbol[i] == 0)
        {
            g_last_trade_time_by_symbol[i] = TimeCurrent();
            break;
        }
    }
}

bool CanOpenNewTradeForSymbol(string symbol, int direction)
{
    // 1. VÉRIFICATION ULTRA-STRICTE: Direction autorisée pour Boom/Crash
    if(!IsDirectionAllowedBC(symbol, direction))
    {
        Print("🚫 BLOCAGE DIRECTION: Direction interdite pour ", symbol);
        return false; // Pas de signal
    }
    
    // 2. VÉRIFICATION ULTRA-STRICTE: Limite globale des positions
    int totalPositionsEA = CountOpenPositionsEA();
    if(totalPositionsEA >= InpMaxGlobalPositions)
    {
        Print("🚫 BLOCAGE ABSOLU: Maximum de positions EA atteint (", totalPositionsEA, "/", InpMaxGlobalPositions, ")");
        return false; // Pas de signal
    }
    
    // 3. VÉRIFICATION ULTRA-STRICTE: Limite des symboles concurrents
    int openSymbols = CountOpenSymbols();
    if(openSymbols >= InpMaxConcurrentSymbols)
    {
        Print("🚫 BLOCAGE SYMBOLES: Maximum de symboles atteint (", openSymbols, "/", InpMaxConcurrentSymbols, ")");
        return false; // Pas de signal
    }
    
    // 4. VÉRIFICATION ULTRA-STRICTE: Perte globale maximale
    if(!GlobalLossGuard())
    {
        Print("🚫 BLOCAGE PERTE: Perte globale maximale atteinte");
        return false; // Pas de signal
    }
    
    // 5. PROTECTION ANTI-CASCADE - Vérifier si le trade est trop récent
    if(IsTradeTooRecent(symbol))
    {
        Print("🚫 Trade trop récent pour ", symbol, " - Protection anti-cascade");
        return false; // Pas de signal
    }
    
    // 6. PROTECTION ANTI-CASCADE - Vérifier le nombre de trades par minute
    if(IsTooManyTradesPerMinute(symbol))
    {
        Print("🚫 Trop de trades par minute pour ", symbol, " - Protection anti-cascade");
        return false; // Pas de signal
    }
    
    // 7. Vérifier les positions existantes sur ce symbole
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                Print("🚫 Position existante pour ", symbol, " - Trade bloqué");
                return false; // Pas de signal
            }
        }
    }
    
    return true;
}

bool ShouldCloseSpikePosition(string symbol, ulong ticket, double current_profit)
{
    for(int i = 0; i < g_spike_states_count; i++)
    {
        if(g_spike_states[i].symbol == symbol && g_spike_states[i].ticket == ticket)
        {
            if(g_spike_states[i].spike_closed) return false;
            
            // Mettre à jour le profit maximum atteint
            if(current_profit > g_spike_states[i].max_profit_reached)
            {
                g_spike_states[i].max_profit_reached = current_profit;
            }
            
            datetime now = TimeCurrent();
            int time_since_spike = (int)(now - g_spike_states[i].spike_detected_time);
            
            // Si on attend le pic du spike
            if(g_spike_states[i].waiting_for_peak)
            {
                // Attendre le délai minimum
                if(time_since_spike < InpSpikeCloseDelaySeconds)
                {
                    return false; // Pas de signal
                }
                
                // Vérifier si on a atteint le temps d'attente du pic
                if(time_since_spike >= InpSpikePeakWaitSeconds)
                {
                    g_spike_states[i].waiting_for_peak = false;
                    Print("🎯 Spike peak wait completed for ", symbol, " - Closing position");
                    return true;
                }
                
                // Vérifier si le profit a commencé à diminuer (pic atteint)
                if(current_profit < g_spike_states[i].max_profit_reached * 0.8) // 20% de retracement
                {
                    g_spike_states[i].waiting_for_peak = false;
                    Print("🎯 Spike peak detected for ", symbol, " - Closing position");
                    return true;
                }
                
                return false; // Pas de signal
            }
            else
            {
                // Fermeture normale après délai
                return time_since_spike >= InpSpikeCloseDelaySeconds;
            }
        }
    }
    
    return false; // Pas de signal
}


// Nouvelle fonction pour calculer le lot basé sur le capital
double CalculateLotSize(const string symbol, const double capitalUSD)
{
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0) return InpDefaultLot;
   
   // Calculer le lot pour le capital donné
   double usdPerPointPerLot = tickValue * (point / tickSize);
   if(usdPerPointPerLot <= 0.0) return InpDefaultLot;
   
   double lot = capitalUSD / (usdPerPointPerLot * 100); // 100 points de marge
   return GetSafeLot(symbol, MathMax(0.01, MathMin(lot, InpMaxLotSize)));
}

// Fonction pour obtenir la perte maximale selon le symbole
double GetMaxLossForSymbol(const string symbol)
{
   if(IsBoomCrashIndex(symbol)) return InpMaxLossBoomCrashUSD;
   return InpMaxLossOtherUSD;
}

// Fonction spécialisée pour calculer la probabilité de confiance Boom/Crash
double CalculateBoomCrashConfidence(const string symbol, const double atr, const double range, const double wickRatio, const int direction)
{
   if(!IsBoomCrashIndex(symbol)) return 0.0;
   
   double confidence = 0.0;
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   
   // 1. ANALYSE DE VOLATILITÉ (30% du score)
   double volatilityScore = 0.0;
   if(atr > 0)
   {
      double atrMultiplier = range / atr;
      if(atrMultiplier >= 1.5) volatilityScore = 30.0;      // Très volatile
      else if(atrMultiplier >= 1.0) volatilityScore = 25.0; // Volatile
      else if(atrMultiplier >= 0.7) volatilityScore = 20.0; // Modérément volatile
      else volatilityScore = 10.0;                           // Peu volatile
   }
   
   // 2. ANALYSE DE MOUVEMENT (25% du score)
   double movementScore = 0.0;
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) >= 5)
   {
      // Analyser les 5 dernières barres
      int bullishBars = 0, bearishBars = 0;
      for(int i = 1; i < 5; i++) // Ignorer la barre actuelle
      {
         if(rates[i].close > rates[i].open) bullishBars++;
         else if(rates[i].close < rates[i].open) bearishBars++;
      }
      
      if(isBoom && direction == POSITION_TYPE_BUY)
      {
         if(bullishBars >= 3) movementScore = 25.0;      // Forte tendance haussière
         else if(bullishBars >= 2) movementScore = 20.0; // Tendance haussière
         else if(bullishBars >= 1) movementScore = 15.0; // Légère tendance haussière
         else movementScore = 5.0;                        // Pas de tendance
      }
      else if(isCrash && direction == POSITION_TYPE_SELL)
      {
         if(bearishBars >= 3) movementScore = 25.0;      // Forte tendance baissière
         else if(bearishBars >= 2) movementScore = 20.0; // Tendance baissière
         else if(bearishBars >= 1) movementScore = 15.0; // Légère tendance baissière
         else movementScore = 5.0;                        // Pas de tendance
      }
   }
   
   // 3. ANALYSE DE MOMENTUM (20% du score)
   double momentumScore = 0.0;
   if(CopyRates(symbol, PERIOD_M1, 0, 3, rates) >= 3)
   {
      double priceChange1 = rates[1].close - rates[2].close;
      double priceChange2 = rates[0].close - rates[1].close;
      
      if(isBoom && direction == POSITION_TYPE_BUY)
      {
         if(priceChange1 > 0 && priceChange2 > 0) momentumScore = 20.0;      // Momentum croissant
         else if(priceChange1 > 0 || priceChange2 > 0) momentumScore = 15.0; // Momentum positif
         else momentumScore = 5.0;                                            // Pas de momentum
      }
      else if(isCrash && direction == POSITION_TYPE_SELL)
      {
         if(priceChange1 < 0 && priceChange2 < 0) momentumScore = 20.0;      // Momentum décroissant
         else if(priceChange1 < 0 || priceChange2 < 0) momentumScore = 15.0; // Momentum négatif
         else momentumScore = 5.0;                                            // Pas de momentum
      }
   }
   
   // 4. ANALYSE DE VOLUME (15% du score)
   double volumeScore = 0.0;
   // Pour Boom/Crash, on simule le volume basé sur la volatilité
   if(range > 0 && atr > 0)
   {
      double volumeRatio = range / atr;
      if(volumeRatio >= 2.0) volumeScore = 15.0;      // Fort volume
      else if(volumeRatio >= 1.5) volumeScore = 12.0; // Volume élevé
      else if(volumeRatio >= 1.0) volumeScore = 10.0; // Volume normal
      else volumeScore = 5.0;                         // Volume faible
   }
   
   // 5. ANALYSE DE TIMING (10% du score)
   double timingScore = 0.0;
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   int hour = dt.hour;
   
   // Boom/Crash sont plus actifs pendant certaines heures
   if((hour >= 8 && hour <= 12) || (hour >= 14 && hour <= 18))
   {
      timingScore = 10.0; // Heures d'activité élevée
   }
   else if((hour >= 6 && hour <= 8) || (hour >= 12 && hour <= 14) || (hour >= 18 && hour <= 20))
   {
      timingScore = 7.0;  // Heures d'activité modérée
   }
   else
   {
      timingScore = 3.0;  // Heures d'activité faible
   }
   
   // Calcul de la confiance totale
   confidence = volatilityScore + movementScore + momentumScore + volumeScore + timingScore;
   
   // Bonus pour alignement parfait Boom/Crash
   if((isBoom && direction == POSITION_TYPE_BUY) || (isCrash && direction == POSITION_TYPE_SELL))
   {
      confidence += 10.0; // Bonus de 10% pour direction correcte
   }
   
   // Pénalité pour direction incorrecte
   if((isBoom && direction == POSITION_TYPE_SELL) || (isCrash && direction == POSITION_TYPE_BUY))
   {
      confidence -= 30.0; // Pénalité de 30% pour direction incorrecte
   }
   
   // Logs de diagnostic détaillés
   if(InpDebug)
   {
      Print(StringFormat("[Angel] BOOM/CRASH CONFIDENCE %s: Vol=%.1f Mov=%.1f Mom=%.1f Vol=%.1f Time=%.1f Total=%.1f%%", 
         symbol, volatilityScore, movementScore, momentumScore, volumeScore, timingScore, confidence));
   }
   
   return MathMin(100.0, MathMax(0.0, confidence));
}

// Fonction pour calculer la confiance avancée du signal
double CalculateAdvancedConfidence(const string symbol, const double atr, const double range, const double wickRatio, const int direction)
{
   // Utiliser le calcul spécialisé pour Boom/Crash
   if(IsBoomCrashIndex(symbol))
   {
      return CalculateBoomCrashConfidence(symbol, atr, range, wickRatio, direction);
   }
   
   // Calcul standard pour les autres symboles
   double baseConfidence = ComputeConfluenceScore(symbol, atr, range, wickRatio, direction);
   
   // Bonus pour tendance alignée
   if(InpUseMTFGate && InpStrictTrendFollowing)
   {
      int trendDir = TrendGateDirection(symbol);
      if((direction == POSITION_TYPE_BUY && trendDir > 0) || (direction == POSITION_TYPE_SELL && trendDir < 0))
      {
         baseConfidence += 15.0; // Bonus de 15% pour alignement tendance
      }
      else if(trendDir != 0)
      {
         baseConfidence -= 25.0; // Pénalité de 25% pour contre-tendance
      }
   }
   
   // Bonus pour proximité S/R
   if(IsNearAnySR(symbol)) baseConfidence += 10.0;
   
   // Bonus pour ICT OrderBlock + OTE
   if(InpEnableICT)
   {
      OrderBlock ob[3];
      int n = BuildRecentOrderBlocks(symbol, InpICT_TF, InpICTLookbackBars, InpSwingLen, InpMinOBBodyATR, ob, 3);
      if(n > 0)
      {
         for(int i = 0; i < n; i++)
         {
            if(ob[i].valid && ICTPriceInOBOTE(symbol, ob[i]))
            {
               baseConfidence += 20.0; // Bonus de 20% pour ICT
               break;
            }
         }
      }
   }
   
   return MathMin(100.0, MathMax(0.0, baseConfidence));
}

// Fonction pour calculer les SL/TP optimaux basés sur le spread et lot minimal
bool CalculateOptimalSLTP(const string symbol, const double lotSize, const double entryPrice, 
                          const int direction, double &outSL, double &outTP)
{
   // Récupérer les informations du symbole
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   
   // Utiliser les paramètres de scalping si le scalping est activé et que c'est un symbole Boom/Crash
   double maxLossUSD, maxProfitUSD;
   if(InpEnableAutoScalping && IsBoomCrashIndex(symbol))
   {
      maxLossUSD = InpScalpMaxLossUSD;    // 3.50$ pour le scalping
      maxProfitUSD = InpScalpTargetProfitUSD; // 5.00$ pour le scalping
   }
   else
   {
      maxLossUSD = GetMaxLossForSymbol(symbol);
      maxProfitUSD = 5.0; // TP maximum de 5$ comme demandé
   }
   
   // Calculer le point value pour ce symbole
   double pointValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(pointValue <= 0) pointValue = 1.0; // Valeur par défaut
   
   // Adapter les calculs selon le type de symbole
   bool isBoomCrash = IsBoomCrashIndex(symbol);
   double securityMultiplier = isBoomCrash ? 1.5 : 1.0; // Plus de sécurité pour Boom/Crash
   
   // Calculer les distances en points pour respecter les limites USD
   double maxLossPoints = maxLossUSD / (lotSize * pointValue);
   double maxProfitPoints = maxProfitUSD / (lotSize * pointValue);
   
   // Ajouter le spread pour la sécurité avec multiplicateur
   double spreadPoints = spread / SymbolInfoDouble(symbol, SYMBOL_POINT);
   double securityBuffer = spreadPoints * 2.0 * securityMultiplier; // Buffer de sécurité adaptatif
   
   // Calculer les SL/TP
   if(direction == POSITION_TYPE_BUY)
   {
      outSL = entryPrice - (maxLossPoints + securityBuffer) * SymbolInfoDouble(symbol, SYMBOL_POINT);
      outTP = entryPrice + (maxProfitPoints - securityBuffer) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   }
   else
   {
      outSL = entryPrice + (maxLossPoints + securityBuffer) * SymbolInfoDouble(symbol, SYMBOL_POINT);
      outTP = entryPrice - (maxProfitPoints - securityBuffer) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   }
   
   // Normaliser les prix selon les digits du symbole
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   outSL = NormalizeDouble(outSL, digits);
   outTP = NormalizeDouble(outTP, digits);
   
   // Vérifier que les niveaux sont valides
   if(direction == POSITION_TYPE_BUY)
   {
      if(outSL >= entryPrice || outTP <= entryPrice) return false;
   }
   else
   {
      if(outSL <= entryPrice || outTP >= entryPrice) return false;
   }
   
   // Vérifier que les distances sont raisonnables (minimum 10 points)
   double minDistance = 10.0 * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(MathAbs(outSL - entryPrice) < minDistance || MathAbs(outTP - entryPrice) < minDistance)
   {
      return false; // Pas de signal
   }
   
   return true;
}

// Fonction désactivée - Ne modifie plus les positions ouvertes
void AnalyzeAndModifyPositions()
{
   // Fonction désactivée - Les SL/TP ne sont plus modifiés après l'ouverture des trades
   // Les ordres prendront leur SL/TP initiaux sans modification
   return;
}

// Fonction pour gérer le repositionnement automatique après clôture
void HandleAutoRepositioning()
{
   // Vérifier si on peut ouvrir de nouvelles positions
   if(CountOpenSymbols() >= InpMaxConcurrentSymbols) return;
   
   // Parcourir les symboles disponibles
   string symbols[] = {_Symbol}; // Commencer par le symbole actuel
   int symbolCount = 1;
   
   // Ajouter d'autres symboles si disponibles
   if(InpMaxConcurrentSymbols > 1)
   {
      // Ici on pourrait ajouter d'autres symboles populaires
      // Pour l'instant, on se concentre sur le symbole actuel
   }
   
   for(int s = 0; s < symbolCount; s++)
   {
      string symbol = symbols[s];
      if(!CanOpenSymbolForEA(symbol)) continue;
      
      // Vérifier si on a déjà une position sur ce symbole
      bool hasPosition = false;
      int i;
    for(i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == symbol)
         {
            hasPosition = true;
            break;
         }
      }
      
      if(hasPosition) continue;
      
      // Analyser les signaux pour ce symbole
      int direction = 0;
      if(DetectSpikeNow(symbol, direction))
      {
         // Calculer la confiance avancée (utiliser des valeurs par défaut pour les paramètres manquants)
         double atr = 0.0, range = 0.0, wickRatio = 0.0;
         double advancedConfidence = CalculateAdvancedConfidence(symbol, atr, range, wickRatio, direction);
         
         if(advancedConfidence >= 85.0) // Seuil de confiance minimum
         {
            // Vérifier la direction pour Boom/Crash
            if(!IsDirectionAllowedBC(symbol, direction)) continue;
            
            // Placer un nouvel ordre
            if(PlaceSmartOrder(symbol, direction, advancedConfidence))
            {
               Print("🔄 AngelOfSpike: Repositionnement automatique sur ", symbol, " Direction: ", (direction==POSITION_TYPE_BUY?"BUY":"SELL"));
               break; // Une seule position à la fois
            }
         }
      }
   }
}

// Fonction pour calculer les statistiques de money management
void CalculateMoneyManagementStats()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Initialiser le solde initial si c'est la première fois
   if(g_initialBalance == 0.0)
   {
      g_initialBalance = currentBalance;
   }
   
   // Calculer le profit/loss global
   double globalProfit = currentBalance - g_initialBalance;
   double dailyProfit = currentBalance - g_startBalanceToday;
   
   // Calculer le win rate
   double winRate = 0.0;
   if(g_totalWins + g_totalLosses > 0)
   {
      winRate = (double)g_totalWins / (double)(g_totalWins + g_totalLosses) * 100.0;
   }
   
   // Stocker les valeurs pour l'affichage
   g_totalProfit = globalProfit;
   g_totalLoss = (globalProfit < 0.0) ? MathAbs(globalProfit) : 0.0;
}

// Fonction pour afficher le money management dans l'angle droit en bas
void DrawMoneyManagementHUD()
{
   if(!InpShowHUD) return;
   
   // Calculer les statistiques
   CalculateMoneyManagementStats();
   
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyProfit = currentBalance - g_startBalanceToday;
   double globalProfit = currentBalance - g_initialBalance;
   double winRate = 0.0;
   if(g_totalWins + g_totalLosses > 0)
   {
      winRate = (double)g_totalWins / (double)(g_totalWins + g_totalLosses) * 100.0;
   }
   
   // Position dans l'angle droit en bas
   int x = InpHUDMoneyX;
   int y = InpHUDMoneyY;
   int dy = InpHUDLineSpacing;
   
   // Titre avec symbole 💰
   DrawText("MONEY_TITLE", "💰 MONEY MANAGEMENT", x, y, clrGold); y += dy;
   y += 5; // Espacement
   
   // Capital avec symbole 💵
   color capitalColor = (currentBalance > g_initialBalance) ? clrLime : clrWhite;
   DrawText("MONEY_CAPITAL", StringFormat("💵 Capital: $%.2f", currentBalance), x, y, capitalColor); y += dy;
   
   // Daily Profit avec symbole 📈 ou 📉
   color dailyColor = (dailyProfit >= 0) ? clrLime : clrRed;
   string dailySymbol = (dailyProfit >= 0) ? "📈" : "📉";
   DrawText("MONEY_DAILY", StringFormat("%s Daily: $%.2f", dailySymbol, dailyProfit), x, y, dailyColor); y += dy;
   
   // Global Profit avec symbole 🚀 ou ⚠️
   color globalColor = (globalProfit >= 0) ? clrLime : clrRed;
   string globalSymbol = (globalProfit >= 0) ? "🚀" : "⚠️";
   DrawText("MONEY_GLOBAL", StringFormat("%s Global: $%.2f", globalSymbol, globalProfit), x, y, globalColor); y += dy;
   
   // Global Loss avec symbole 🔻
   if(g_totalLoss > 0)
   {
      DrawText("MONEY_LOSS", StringFormat("🔻 Loss: $%.2f", g_totalLoss), x, y, clrRed); y += dy;
   }
   
   // Win Rate avec symbole 🎯
   color winRateColor = (winRate >= 50.0) ? clrLime : (winRate >= 30.0) ? clrOrange : clrRed;
   DrawText("MONEY_WINRATE", StringFormat("🎯 Win Rate: %.1f%%", winRate), x, y, winRateColor); y += dy;
   
   // Statistiques de trading
   DrawText("MONEY_STATS", StringFormat("📊 Wins: %d | Losses: %d", g_totalWins, g_totalLosses), x, y, clrWhite); y += dy;
   
   // Performance en pourcentage
   double performancePct = (g_initialBalance > 0) ? (globalProfit / g_initialBalance) * 100.0 : 0.0;
   color perfColor = (performancePct >= 0) ? clrLime : clrRed;
   string perfSymbol = (performancePct >= 0) ? "📈" : "📉";
   DrawText("MONEY_PERF", StringFormat("%s Performance: %.2f%%", perfSymbol, performancePct), x, y, perfColor);
}
double GetPointValueUSD(const string symbol)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pt         = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tick_size<=0.0 || pt<=0.0) return 0.0;
   return tick_value * (pt / tick_size);
}

// Retourne un lot valide selon les contraintes broker; fallback 0.20 si infos manquantes
double GetSafeLot(const string symbol, double desiredLot)
{
   double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double lot = (desiredLot>0.0? desiredLot : InpDefaultLot);
   if(minVol<=0.0 || maxVol<=0.0 || stepVol<=0.0)
      return MathMax(0.20, lot);
   lot = MathMax(lot, minVol);
   lot = MathMin(lot, MathMin(maxVol, InpMaxLotSize));
   lot = MathRound(lot/stepVol)*stepVol;
   if(lot<minVol) lot=minVol;
   return lot;
}

// Ajuste entry/SL/TP pour respecter stops/freeze levels pour ordres STOP
bool PrepareValidStopOrder(const string symbol, const int dir, double &entry, double &sl, double &tp)
{
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt<=0.0) return false;
   MqlTick t; if(!SymbolInfoTick(symbol, t)) return false;
   long stopLevelPts = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevelPts = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minPts = (double)MathMax(stopLevelPts, freezeLevelPts);
   int digits=(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(dir==POSITION_TYPE_BUY)
   {
      double minEntry = t.ask + (minPts+1.0)*pt;
      if(entry < minEntry) entry = minEntry;
      if((entry-sl)/pt < minPts+1.0) sl = entry - (minPts+1.0)*pt;
      if((tp-entry)/pt < minPts+1.0) tp = entry + (minPts+1.0)*pt;
   }
   else if(dir==POSITION_TYPE_SELL)
   {
      double maxEntry = t.bid - (minPts+1.0)*pt;
      if(entry > maxEntry) entry = maxEntry;
      if((sl-entry)/pt < minPts+1.0) sl = entry + (minPts+1.0)*pt;
      if((entry-tp)/pt < minPts+1.0) tp = entry - (minPts+1.0)*pt;
   }
   entry = NormalizeDouble(entry, digits);
   sl    = NormalizeDouble(sl, digits);
   tp    = NormalizeDouble(tp, digits);
   return true;
}

// Lightweight trade executor inspired by clean_spikeh executor
class CTradeExecutorAngel
{
private:
   CTrade m_trade;
public:
   CTradeExecutorAngel()
   {
      m_trade.SetExpertMagicNumber(InpMagicNumber);
      m_trade.SetDeviationInPoints(InpSlippagePoints);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   }
      bool ExecuteMarket(const string symbol, const int direction, const double lot, const double sl, const double tp)
      {
         if(direction==0) return false;
         
         // VÉRIFICATION PRÉVENTIVE
         if(!CanPlaceNewOrder(symbol, direction)) return false;
         
         double price = (direction==POSITION_TYPE_BUY)? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
         if(price<=0.0) return false;
         
         // Vérifier que SL/TP sont valides avant d'exécuter
         if(sl<=0 || tp<=0)
         {
            if(InpDebug) Print(StringFormat("[Angel] Invalid SL/TP for %s: SL=%.5f, TP=%.5f", symbol, sl, tp));
            return false; // Pas de signal
         }
         
         if(!GuardAllowOpen(symbol, direction)) return false;
         
         bool ok = (direction==POSITION_TYPE_BUY)? m_trade.Buy(lot, symbol, price, sl, tp, "AngelExec") : m_trade.Sell(lot, symbol, price, sl, tp, "AngelExec");
         
         if(ok)
         {
            OnSuccessfulOpen(symbol, direction);
            if(InpDebug)
               Print(StringFormat("[Angel] Order executed: %s %s %.2f lots at %.5f, SL=%.5f, TP=%.5f", 
                  symbol, (direction==POSITION_TYPE_BUY?"BUY":"SELL"), lot, price, sl, tp));
         }
         
         return ok;
      }
}; // Closing brace for CTradeExecutorAngel class
bool IsRecentOrder(const string symbol, const int direction, const int windowSec)
{
   if(windowSec<=0) return false;
   datetime now = TimeCurrent();
   for(int i=0;i<20;i++)
   {
      if(g_recentOrderSymbols[i]==symbol && g_recentOrderDirs[i]==direction)
      {
         if(now - g_recentOrderTimes[i] < windowSec) return true;
      }
   }
   return false; // Pas de signal
}

void MarkRecentOrder(const string symbol, const int direction)
{
   for(int i=0;i<20;i++)
   {
      if(g_recentOrderSymbols[i]==symbol || g_recentOrderSymbols[i]=="")
      {
         g_recentOrderSymbols[i]=symbol;
         g_recentOrderDirs[i]=direction;
         g_recentOrderTimes[i]=TimeCurrent();
         break;
      }
   }
}

// Guard: unified pre-check to avoid opening multiple successive trades
bool GuardAllowOpen(const string symbol, const int direction)
{
   // Strict symbol/magic checks and anti-cascade
   if(!CanOpenNewTradeForSymbol(symbol, direction)) return false;
   // Short-term duplicate guard on same symbol+direction
   int minWindow = (int)InpMinCooldownMinutes * 60;
   if(minWindow < 0) minWindow = 0;
   if(IsRecentOrder(symbol, direction, minWindow))
   {
      if(InpDebug) Print("🚫 Guard: ordre récent pour ", symbol, " dir=", direction);
      return false; // Pas de signal
   }
   return true;
}

void OnSuccessfulOpen(const string symbol, const int direction)
{
   // Record recent to enforce cooldowns and anti-cascade
   MarkRecentOrder(symbol, direction);
   UpdateLastTradeTimeAntiCascade(symbol);
}

//+------------------------------------------------------------------+
//| Fermeture immédiate après spike pour Boom/Crash                 |
//+------------------------------------------------------------------+
void HandleBoomCrashSpikeExit()
{
   // NOUVELLE LOGIQUE: Ne fermer que sur TP/SL pour Boom/Crash
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(!IsBoomCrashIndex(symbol)) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      double profitUSD = profit;
      
      // Convertir en USD si nécessaire
      if(SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE) == SYMBOL_CALC_MODE_FOREX)
      {
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         profitUSD *= tickValue;
      }
      
      // NOUVELLE LOGIQUE: Fermer SEULEMENT sur TP/SL
      bool shouldClose = false;
      string reason = "";
      
      // 1. Fermer SEULEMENT si le TP est atteint (spike capturé en gain)
      double tp = PositionGetDouble(POSITION_TP);
      double sl = PositionGetDouble(POSITION_SL);
      double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      if(tp > 0) // Si TP est défini
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currentPrice >= tp)
         {
            shouldClose = true;
            reason = StringFormat("TP ATTEINT: %.5f (profit: %.2f$)", tp, profitUSD);
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currentPrice <= tp)
         {
            shouldClose = true;
            reason = StringFormat("TP ATTEINT: %.5f (profit: %.2f$)", tp, profitUSD);
         }
      }
      
      // 2. Fermer SEULEMENT si le SL est atteint
      if(sl > 0) // Si SL est défini
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currentPrice <= sl)
         {
            shouldClose = true;
            reason = StringFormat("SL ATTEINT: %.5f (perte: %.2f$)", sl, profitUSD);
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currentPrice >= sl)
         {
            shouldClose = true;
            reason = StringFormat("SL ATTEINT: %.5f (perte: %.2f$)", sl, profitUSD);
         }
      }
      
      // SUPPRIMÉ: Fermeture par timeout - Ne plus fermer après 30 secondes
      // SUPPRIMÉ: Fermeture par seuil de profit bas - Laisser le TP/SL gérer
      
      if(shouldClose)
      {
         if(g_trade.PositionClose(ticket))
         {
            Print("🎯 BOOM/CRASH EXIT: ", symbol, " - ", reason);
         }
      }
   }
}

bool IsTradingAllowedNow(const string symbol)
{
   long mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   return (mode!=SYMBOL_TRADE_MODE_DISABLED);
}

bool SpreadOk(const string symbol)
{
   if(InpMaxSpreadPoints<=0) return true;
   MqlTick t; if(!SymbolInfoTick(symbol, t)) return true;
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt<=0.0) return true;
   double spreadPts = (t.ask - t.bid) / pt;
   return (spreadPts <= InpMaxSpreadPoints);
}

// --- Visual helpers for signals ---
void DrawArrowAt(const string id, const ENUM_OBJECT type, const datetime t, const double y, const color col, const int width)
{
   if(ObjectFind(0,id)>=0) ObjectDelete(0,id);
   ObjectCreate(0, id, type, 0, t, y);
   ObjectSetInteger(0, id, OBJPROP_COLOR, col);
   ObjectSetInteger(0, id, OBJPROP_WIDTH, width);
}

// --- ICT helpers ---
struct SwingPoint { datetime t; double price; int index; bool isHigh; };
struct OrderBlock { datetime t0; datetime t1; double priceLow; double priceHigh; bool isBull; bool valid; };

int FindSwings(const string symbol, const ENUM_TIMEFRAMES tf, const int swingLen, const int bars, SwingPoint &swings[], const int maxSw)
{
   int count=0; MqlRates r[]; int got=(int)CopyRates(symbol, tf, 0, bars, r); if(got<2*swingLen+5) return 0; ArraySetAsSeries(r,true);
   for(int i=swingLen; i<got-swingLen && count<maxSw; i++)
   {
      bool high=true, low=true;
      for(int k=1;k<=swingLen;k++){ if(!(r[i].high>r[i-k].high && r[i].high>r[i+k].high)) high=false; if(!(r[i].low<r[i-k].low && r[i].low<r[i+k].low)) low=false; if(!high && !low) break; }
      if(high){ swings[count].t=r[i].time; swings[count].price=r[i].high; swings[count].index=i; swings[count].isHigh=true; count++; }
      else if(low){ swings[count].t=r[i].time; swings[count].price=r[i].low; swings[count].index=i; swings[count].isHigh=false; count++; }
   }
   return count;
}

bool DetectBOSCOS(const SwingPoint &prev, const SwingPoint &curr, bool &bosUp, bool &bosDn)
{
   bosUp=false; bosDn=false;
   if(!prev.isHigh && curr.isHigh) { /* HH not BOS */ }
   // BOS up: low then high break past previous swing high
   if(curr.isHigh && curr.price>prev.price && prev.isHigh) bosUp=true;
   // BOS down: low takeout
   if(!curr.isHigh && curr.price<prev.price && !prev.isHigh) bosDn=true;
   return (bosUp||bosDn);
}

int BuildRecentOrderBlocks(const string symbol, const ENUM_TIMEFRAMES tf, const int bars, const int swingLen, const double minBodyAtr, OrderBlock &obs[], const int maxOb)
{
   obs[0].valid=false; int obCount=0; MqlRates r[]; int got=(int)CopyRates(symbol, tf, 0, bars, r); if(got<50) return 0; ArraySetAsSeries(r,true);
   // ATR for sizing
   int hA=iATR(symbol, tf, 14); double ab[]; double atr=0.0; if(hA!=INVALID_HANDLE && CopyBuffer(hA,0,0,1,ab)>0) atr=ab[0]; if(hA!=INVALID_HANDLE) IndicatorRelease(hA);
   if(atr<=0.0) atr= (got>1? (r[0].high-r[0].low) : 0.0);
   // Swings
   SwingPoint sw[200]; int swN=FindSwings(symbol, tf, swingLen, MathMin(bars,500), sw, 200);
   if(swN<3) return 0;
   for(int i=1;i<swN && obCount<maxOb;i++)
   {
      bool bosUp=false, bosDn=false; if(!DetectBOSCOS(sw[i-1], sw[i], bosUp, bosDn)) continue;
      // Find last opposing candle before BOS as OB
      int idx = sw[i].index;
      // Search previous bar of opposite color
      for(int j=idx+1; j<MathMin(idx+10, got-1) && obCount<maxOb; j++)
      {
         bool isBull = (r[j].close>r[j].open);
         if((bosUp && !isBull) || (bosDn && isBull))
         {
            double body = MathAbs(r[j].close - r[j].open);
            if(body >= minBodyAtr*atr)
            {
               obs[obCount].t0 = r[j].time; obs[obCount].t1 = r[j-1].time;
               obs[obCount].isBull = (!isBull); // opposing = OB direction
               obs[obCount].priceLow = MathMin(r[j].open, r[j].close);
               obs[obCount].priceHigh= MathMax(r[j].open, r[j].close);
               obs[obCount].valid=true; obCount++;
               break;
            }
         }
      }
   }
   return obCount;
}

void DrawICTObjects(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!InpICTDraw || !InpEnableICT) return;
   // Clear
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--){ string n=ObjectName(0,i); if(StringFind(n,"ICT_")==0) ObjectDelete(0,n); }
   // OBs
   OrderBlock ob[10]; int n=BuildRecentOrderBlocks(symbol, tf, InpICTLookbackBars, InpSwingLen, InpMinOBBodyATR, ob, 10);
   // Historical span: from lookback start to a bit into the future
   datetime ts[]; ArraySetAsSeries(ts,true); datetime left=TimeCurrent()-3600*12; // fallback 12h
   if(CopyTime(symbol, tf, 0, MathMax(InpICTLookbackBars, 50), ts)>0){ int idx = MathMin(ArraySize(ts)-1, InpICTLookbackBars-1); if(idx>=0) left = ts[idx]; }
   datetime right = TimeCurrent()+3600*6; // extend into future for visibility
   for(int k=0;k<n;k++) if(ob[k].valid){
      string id = StringFormat("ICT_OB_%d", (int)ob[k].t0);
      if(ObjectFind(0,id)>=0) ObjectDelete(0,id);
      if(ObjectCreate(0, id, OBJ_RECTANGLE, 0, left, ob[k].priceLow, right, ob[k].priceHigh))
      {
         // Semi-transparent fill to highlight verified order blocks
         color base = ob[k].isBull? clrDeepSkyBlue : clrRed;
         color semi = (color)ColorToARGB(base, (uchar)80); // ~70% transparent
         ObjectSetInteger(0, id, OBJPROP_COLOR, semi);
         ObjectSetInteger(0, id, OBJPROP_BACK, true);
         ObjectSetInteger(0, id, OBJPROP_FILL, true);
         ObjectSetInteger(0, id, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, id, OBJPROP_WIDTH, 1);
         // Put a border line (less transparent) for clarity
         string brd = StringFormat("ICT_OB_BR_%d", (int)ob[k].t0);
         if(ObjectFind(0,brd)>=0) ObjectDelete(0,brd);
         if(ObjectCreate(0, brd, OBJ_TREND, 0, left, ob[k].priceHigh, right, ob[k].priceHigh))
         {
            ObjectSetInteger(0, brd, OBJPROP_COLOR, base);
            ObjectSetInteger(0, brd, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, brd, OBJPROP_WIDTH, 1);
         }
      }
   }
   // OTE band from last swing range
   SwingPoint sw[50]; int swN=FindSwings(symbol, tf, InpSwingLen, InpICTLookbackBars, sw, 50);
   if(swN>=2){
      double a=sw[0].price, b=sw[1].price; // recent two swings
      double lo=MathMin(a,b), hi=MathMax(a,b);
      double oteLo = hi - (hi-lo)*InpOTE_2;
      double oteHi = hi - (hi-lo)*InpOTE_1;
      string id2="ICT_OTE"; ObjectCreate(0,id2,OBJ_RECTANGLE,0,left,oteLo,right,oteHi);
      ObjectSetInteger(0,id2,OBJPROP_COLOR,clrGold);
      ObjectSetInteger(0,id2,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,id2,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,id2,OBJPROP_BACK,true);

      // Fibonacci retracement over last two swings
      string fibId = "ICT_FIBO";
      if(ObjectFind(0,fibId)>=0) ObjectDelete(0,fibId);
      // Anchor from first swing to second swing in time
      datetime ta = sw[1].t; // more recent
      datetime tb = sw[0].t; // previous
      ObjectCreate(0, fibId, OBJ_FIBO, 0, tb, b, ta, a);
      ObjectSetInteger(0, fibId, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, fibId, OBJPROP_RAY_RIGHT, true);
      // Configure levels: 0, OTE_1, OTE_2, 1
      ObjectSetInteger(0, fibId, OBJPROP_LEVELS, 4);
      ObjectSetDouble(0, fibId, OBJPROP_LEVELVALUE, 0, 0.0);
      ObjectSetDouble(0, fibId, OBJPROP_LEVELVALUE, 1, InpOTE_1);
      ObjectSetDouble(0, fibId, OBJPROP_LEVELVALUE, 2, InpOTE_2);
      ObjectSetDouble(0, fibId, OBJPROP_LEVELVALUE, 3, 1.0);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELCOLOR, 0, clrLime);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELCOLOR, 1, clrDeepSkyBlue);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELCOLOR, 2, clrOrangeRed);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELCOLOR, 3, clrMagenta);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELSTYLE, 0, STYLE_SOLID);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELSTYLE, 1, STYLE_DOT);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELSTYLE, 2, STYLE_DOT);
      ObjectSetInteger(0, fibId, OBJPROP_LEVELSTYLE, 3, STYLE_SOLID);
   }
}

void DrawOverlays(const string symbol)
{
   // EMA overlays
   if(InpShowEMAOverlay)
   {
      // Attach 5 EMA indicators (fast→slow) with distinct styling handled by platform colors
      int h1=iMA(symbol, PERIOD_CURRENT, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);
      int h2=iMA(symbol, PERIOD_CURRENT, InpEMA2, 0, MODE_EMA, PRICE_CLOSE);
      int h3=iMA(symbol, PERIOD_CURRENT, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);
      int h4=iMA(symbol, PERIOD_CURRENT, InpEMA4, 0, MODE_EMA, PRICE_CLOSE);
      int h5=iMA(symbol, PERIOD_CURRENT, InpEMA5, 0, MODE_EMA, PRICE_CLOSE);
      if(h1!=INVALID_HANDLE) ChartIndicatorAdd(0,0,h1);
      if(h2!=INVALID_HANDLE) ChartIndicatorAdd(0,0,h2);
      if(h3!=INVALID_HANDLE) ChartIndicatorAdd(0,0,h3);
      if(h4!=INVALID_HANDLE) ChartIndicatorAdd(0,0,h4);
      if(h5!=INVALID_HANDLE) ChartIndicatorAdd(0,0,h5);
      // EMA values masqués pour éviter l'encombrement du graphique
      // Les EMA sont toujours calculés mais pas affichés sur le graphique
   }
   // Bollinger overlay removed per request
   // Envelopes (upper/lower as dotted lines)
   if(InpShowEnvelopes)
   {
      int hMA=iMA(symbol, PERIOD_CURRENT, InpEnv_Period, 0, MODE_EMA, PRICE_CLOSE);
      double ma=0; if(hMA!=INVALID_HANDLE){ double b[]; if(CopyBuffer(hMA,0,0,1,b)>0) ma=b[0]; IndicatorRelease(hMA);} if(ma>0)
      {
         double pct=InpEnv_Deviation_Pct/100.0; double up=ma*(1.0+pct); double dn=ma*(1.0-pct);
         datetime tnow=TimeCurrent(); datetime tfut=tnow+3600*6; string idEU="OV_ENV_U", idEM="OV_ENV_M", idED="OV_ENV_D";
         ObjectCreate(0,idEU,OBJ_TREND,0,tnow,up,tfut,up); ObjectSetInteger(0,idEU,OBJPROP_COLOR,clrGold); ObjectSetInteger(0,idEU,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(0,idEU,OBJPROP_WIDTH,2);
         ObjectCreate(0,idEM,OBJ_TREND,0,tnow,ma,tfut,ma); ObjectSetInteger(0,idEM,OBJPROP_COLOR,clrYellow); ObjectSetInteger(0,idEM,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(0,idEM,OBJPROP_WIDTH,1);
         ObjectCreate(0,idED,OBJ_TREND,0,tnow,dn,tfut,dn); ObjectSetInteger(0,idED,OBJPROP_COLOR,clrGold); ObjectSetInteger(0,idED,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(0,idED,OBJPROP_WIDTH,2);
      }
   }
}


bool ICTTrendBull(const string symbol, const ENUM_TIMEFRAMES tf)
{
   int hF=iMA(symbol, tf, InpEMA_Fast_ICT, 0, MODE_EMA, PRICE_CLOSE);
   int hS=iMA(symbol, tf, InpEMA_Slow_ICT, 0, MODE_EMA, PRICE_CLOSE);
   double ef=0, es=0; if(hF!=INVALID_HANDLE){ double b[]; if(CopyBuffer(hF,0,0,1,b)>0) ef=b[0]; IndicatorRelease(hF);} if(hS!=INVALID_HANDLE){ double c[]; if(CopyBuffer(hS,0,0,1,c)>0) es=c[0]; IndicatorRelease(hS);} return (ef>0 && es>0 && ef>es);
}

bool ICTPriceInOBOTE(const string symbol, const OrderBlock &ob)
{
   double bid=SymbolInfoDouble(symbol, SYMBOL_BID); if(bid<=0) bid=SymbolInfoDouble(symbol, SYMBOL_ASK); if(bid<=0) return false;
   if(bid<ob.priceLow || bid>ob.priceHigh) return false;
   // OTE check based on last two swings
   SwingPoint sw[4]; int swN=FindSwings(symbol, InpICT_TF, InpSwingLen, 80, sw, 4); if(swN<2) return true;
   double a=sw[0].price, b=sw[1].price; double lo=MathMin(a,b), hi=MathMax(a,b);
   double oteLo = hi - (hi-lo)*InpOTE_2; double oteHi = hi - (hi-lo)*InpOTE_1;
   return (bid>=MathMin(oteLo,oteHi) && bid<=MathMax(oteLo,oteHi));
}

double ComputeConfluenceScore(const string symbol,
                              const double atr,
                              const double range,
                              const double wickRatio,
                              const int spikeDir)
{
   // Normalize ATR multiple and wick ratio against thresholds
   double reqAtrMult = 1.0; // Valeur par défaut
   double reqWickMin = 1.0; // Valeur par défaut
   double atrMult = (atr>0.0 ? range/atr : 0.0);
   double sAtr  = MathMin(1.5, (reqAtrMult>0.0? atrMult/reqAtrMult : 0.0));
   double sWick = MathMin(1.5, (reqWickMin>0.0? wickRatio/reqWickMin : 0.0));

   // S/R proximity
   double sSR = 0.0; if(IsNearAnySR(symbol)) sSR = 1.0;

   // OB+OTE check (same TF as ICT_TF), approximate by checking latest valid OB and price location
   double sOB = 0.0;
   if(InpEnableICT)
   {
      OrderBlock ob[3]; int n=BuildRecentOrderBlocks(symbol, InpICT_TF, InpICTLookbackBars, InpSwingLen, InpMinOBBodyATR, ob, 3);
      if(n>0)
      {
         // take most recent valid OB only
         for(int i=0;i<n;i++) if(ob[i].valid){ if(ICTPriceInOBOTE(symbol, ob[i])) { sOB = 1.0; break; } }
      }
   }

   // MTF gate alignment
   double sMTF = 0.0;
   if(InpUseMTFGate)
   {
      int g = TrendGateDirection(symbol);
      if((spikeDir==POSITION_TYPE_BUY && g>0) || (spikeDir==POSITION_TYPE_SELL && g<0)) sMTF = 1.0;
   }

   // Squeeze proxy: stddev/atr low previously and now expansion (approx using current ratio)
   double sSQ = 0.0; // capped small bonus
   int hSD=iStdDev(symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE); double sdb[]; double sd=0; if(hSD!=INVALID_HANDLE && CopyBuffer(hSD,0,0,1,sdb)>0) sd=sdb[0]; if(hSD!=INVALID_HANDLE) IndicatorRelease(hSD);
   if(sd>0 && atr>0)
   {
      double r = sd/atr;
      if(r < 0.8) sSQ = 1.0; // in squeeze regime
   }

   // Weighted score -> 0..100
   // Clamp weights to avoid over 1.0; normalize by sum of provided weights
   double W = InpW_ATR + InpW_Wick + InpW_SR + InpW_OBOTE + InpW_MTF + InpW_Squeeze;
   if(W<=0.0) W = 1.0;
   double score01 = (InpW_ATR*sAtr + InpW_Wick*sWick + InpW_SR*sSR + InpW_OBOTE*sOB + InpW_MTF*sMTF + InpW_Squeeze*sSQ) / W;
   score01 = MathMin(1.0, MathMax(0.0, score01));
   return 100.0*score01;
}

bool TryTradeICT(const string symbol)
{
   if(!InpEnableICT || !InpICTTrade) return false;
   OrderBlock ob[5]; int n=BuildRecentOrderBlocks(symbol, InpICT_TF, InpICTLookbackBars, InpSwingLen, InpMinOBBodyATR, ob, 5);
   if(n<=0) return false;
   bool trendBull = ICTTrendBull(symbol, InpICT_TF);
   for(int i=0;i<n;i++) if(ob[i].valid){
      if(!ICTPriceInOBOTE(symbol, ob[i])) continue;
      int dir = (trendBull && ob[i].isBull)? POSITION_TYPE_BUY : (!trendBull && !ob[i].isBull? POSITION_TYPE_SELL : 0);
      if(dir==0) continue;
      // Auto-trade inside OB with fixed lot if enabled
      if(InpOBAutoTrade)
      {
         // Bypass general symbol gating by sending direct order with fixed lot and OB SL/TP
         double lot = GetSafeLot(symbol, InpOBLot);
         int digits=(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double pt=SymbolInfoDouble(symbol,SYMBOL_POINT);
         double price=(dir==POSITION_TYPE_BUY)? SymbolInfoDouble(symbol,SYMBOL_ASK):SymbolInfoDouble(symbol,SYMBOL_BID);
         if(price>0 && pt>0)
         {
            if(!IsDirectionAllowedBC(symbol, dir)) { if(InpDebug) Print("[Angel] ICT blocked by BC direction on ", symbol); continue; }
            int win = MathMax(InpMinSecondsBetweenOrders, InpMinSecondsBetweenSameSymbol);
            if(IsRecentOrder(symbol, dir, win)) { if(InpDebug) Print("[Angel] Recent order guard (ICT) blocks ", symbol); continue; }
            if(!CanOpenSymbol(symbol, dir)) { if(InpDebug) Print("[Angel] CanOpenSymbol blocked ICT on ", symbol); continue; }
            // SL/TP: keep within OB band and RR~1.5
            double entry=price;
            double sl = (dir==POSITION_TYPE_BUY)? MathMin(entry - 1*pt, ob[i].priceLow) : MathMax(entry + 1*pt, ob[i].priceHigh);
            double obHeight = MathMax(1e-8, ob[i].priceHigh - ob[i].priceLow);
            double tp = (dir==POSITION_TYPE_BUY)? entry + 1.5*obHeight : entry - 1.5*obHeight;
            sl = NormalizeDouble(sl, digits); tp = NormalizeDouble(tp, digits);
            g_trade.SetExpertMagicNumber(InpMagicNumber);
            g_trade.SetDeviationInPoints((uint)InpSlippagePoints);
            if(!GuardAllowOpen(symbol, dir)) return false;
            bool ok = (dir==POSITION_TYPE_BUY) ? g_trade.Buy(lot, symbol, price, sl, tp, "OB_Auto")
                                               : g_trade.Sell(lot, symbol, price, sl, tp, "OB_Auto");
            if(ok){ OnSuccessfulOpen(symbol, dir); if(InpDebug) Print(StringFormat("[Angel] OB AutoTrade %s dir=%d lot=%.2f", symbol, dir, lot)); return true; }
            else { if(InpSendNotifications) SendNotification(StringFormat("%s: OB AutoTrade FAILED on %s", InpNotifyTag, symbol)); }
         }
      }
      if(OpenSpikeMarket(symbol, dir)){
         // draw ICT trade arrow marker
         datetime tt[]; ArraySetAsSeries(tt,true); if(CopyTime(symbol, PERIOD_M1, 0, 1, tt)>0){
            string iid = StringFormat("ANGEL_ICT_%s_%d", symbol, (int)tt[0]);
            ObjectCreate(0, iid, OBJ_ARROW, 0, tt[0], SymbolInfoDouble(symbol, SYMBOL_BID));
            ObjectSetInteger(0, iid, OBJPROP_COLOR, clrMagenta);
            ObjectSetInteger(0, iid, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, iid, OBJPROP_ARROWCODE, 241);
         }
         return true;
      }
   }
   return false; // Pas de signal
}

void DrawText(const string id, const string text, const int x, const int y, const color col)
{
   if(ObjectFind(0, id)<0)
   {
      ObjectCreate(0, id, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, id, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   ObjectSetInteger(0, id, OBJPROP_COLOR, col);
   ObjectSetInteger(0, id, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, id, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, id, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, id, OBJPROP_TEXT, text);
}

void DrawAngelHUD()
{
   if(!InpShowHUD) return;
   // Compute quick trend/volatility snapshot on _Symbol
   MqlRates r[50]; int got = (int)CopyRates(_Symbol, PERIOD_M1, 0, 50, r);
   int emaFast=10, emaSlow=30; double ef=0, es=0;
   int hF=iMA(_Symbol, PERIOD_M1, emaFast, 0, MODE_EMA, PRICE_CLOSE);
   int hS=iMA(_Symbol, PERIOD_M1, emaSlow, 0, MODE_EMA, PRICE_CLOSE);
   if(hF!=INVALID_HANDLE){ double b[]; if(CopyBuffer(hF,0,0,1,b)>0) ef=b[0]; IndicatorRelease(hF);} 
   if(hS!=INVALID_HANDLE){ double b2[]; if(CopyBuffer(hS,0,0,1,b2)>0) es=b2[0]; IndicatorRelease(hS);} 
   string trend = (ef>0 && es>0 && ef>es) ? "BULL" : (ef>0 && es>0 && ef<es ? "BEAR" : "NEUTRAL");
   // ATR
   double atr=0.0; int hA=iATR(_Symbol, PERIOD_M1, 14); if(hA!=INVALID_HANDLE){ double ab[]; if(CopyBuffer(hA,0,0,1,ab)>0) atr=ab[0]; IndicatorRelease(hA);} 
   // Squeeze (very simple proxy: StdDev contraction)
   double sd=0.0; int hSD=iStdDev(_Symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE); if(hSD!=INVALID_HANDLE){ double sdb[]; if(CopyBuffer(hSD,0,0,1,sdb)>0) sd=sdb[0]; IndicatorRelease(hSD);} 
   bool squeeze = (sd>0 && atr>0 && sd/atr < 0.8);

   // COLONNE 1 - Informations principales
   int y1 = InpHUDY; int x1 = InpHUDX; int dy = InpHUDLineSpacing;
   DrawText("ANGEL_HUD_0", "Angel of Spike", x1, y1, InpHUDAccent); y1+=dy;
   DrawText("ANGEL_HUD_1", StringFormat("Symbol: %s", _Symbol), x1, y1, InpHUDColor); y1+=dy;
   DrawText("ANGEL_HUD_2", StringFormat("Trend: %s", trend), x1, y1, (trend=="BULL"? clrLime : (trend=="BEAR"? clrRed : InpHUDColor))); y1+=dy;
   DrawText("ANGEL_HUD_3", StringFormat("ATR(M1,14): %.5f", atr), x1, y1, InpHUDColor); y1+=dy;
   DrawText("ANGEL_HUD_4", StringFormat("Squeeze: %s", squeeze?"ON":"OFF"), x1, y1, squeeze? clrOrange : InpHUDColor); y1+=dy;
   // Positions summary seulement
   int openSyms = CountOpenSymbols();
   DrawText("ANGEL_HUD_5", StringFormat("Open Symbols: %d / %d", openSyms, InpMaxConcurrentSymbols), x1, y1, InpHUDColor); y1+=dy;
   
   // Statut des trades manuels
   int totalPositionsEA = CountOpenPositionsEA();
   string manualStatus = InpAllowManualTrading ? "AUTORISÉS" : "DÉSACTIVÉS";
   color manualColor = InpAllowManualTrading ? clrLime : clrRed;
   if(totalPositionsEA >= 10)
   {
      manualStatus = "AUTORISÉS (EA bloqué)";
      manualColor = clrOrange;
   }
   DrawText("ANGEL_HUD_6", StringFormat("Trades Manuels: %s", manualStatus), x1, y1, manualColor); y1+=dy;
   
   // Afficher le money management dans l'angle droit en bas
   DrawMoneyManagementHUD();
   
   
   // Afficher les trades manuels si autorisés
   if(InpAllowManualTrading)
   {
      DrawManualTradesHUD();
   }

   // Forecast arrows (up to 2) based on simple linear regression slope on M5
   if(InpShowForecastArrows)
   {
      MqlRates rr[]; int got=(int)CopyRates(_Symbol, PERIOD_M5, 0, 60, rr); if(got>=20)
      {
         // linear regression on close
         double sx=0,sy=0,sxy=0,sxx=0; int n=got;
         for(int i=0;i<n;i++){ double x=(double)i; double yv=rr[i].close; sx+=x; sy+=yv; sxy+=x*yv; sxx+=x*x; }
         double denom = (n*sxx - sx*sx); if(denom==0) denom=1; double a=(n*sxy - sx*sy)/denom; double b=(sy - a*sx)/n;
         // current price and times
         int hours = MathMax(1, InpForecastHours); hours = MathMin(6, hours);
         datetime t0 = TimeCurrent();
         double c0 = rr[0].close; int digits=(int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         // Clear old arrows
         string ids[2] = {"ANGEL_FC1","ANGEL_FC2"}; for(int k=0;k<2;k++){ if(ObjectFind(0,ids[k])>=0) ObjectDelete(0,ids[k]); }
         // Draw up to 2 forecast arrows following slope
         for(int k=1;k<=2;k++)
         {
            double xh = (double)(k*hours*12); // 12 bars per hour on M5
            double yh = a*xh + b; // projected close
            datetime th = t0 + k*hours*3600;
            string nid = ids[k-1];
            ENUM_OBJECT typ = (a>=0)? OBJ_ARROW_UP : OBJ_ARROW_DOWN;
            if(ObjectCreate(0, nid, typ, 0, th, NormalizeDouble(yh, digits)))
            {
               ObjectSetInteger(0, nid, OBJPROP_COLOR, (a>=0? clrLime : clrTomato));
               ObjectSetInteger(0, nid, OBJPROP_WIDTH, 2);
               ObjectSetInteger(0, nid, OBJPROP_SELECTABLE, false);
               
               // DÉCLENCHEMENT AUTOMATIQUE QUAND FC1 CLIGNOTE
               if(nid == "ANGEL_FC1")
               {
                  // Vérifier si c'est un signal valide pour trading automatique
                  if(ValidateFC1Signal(a))
                  {
                     Print("🚨 FC1 DÉTECTÉ - DÉCLENCHEMENT AUTOMATIQUE DU TRADE");
                     ExecuteFC1Trade(a >= 0);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Valide si le signal FC1 est suffisamment fort pour le trading      |
//+------------------------------------------------------------------+
bool ValidateFC1Signal(double slope)
{
   // Vérifier si la pente est suffisamment forte
   if(MathAbs(slope) < 0.0001) 
   {
      Print("❌ FC1: Pente trop faible: ", slope);
      return false;
   }
   
   // Vérifier si nous avons déjà une position ouverte
   if(CountOpenPositionsEA() > 0)
   {
      Print("❌ FC1: Position déjà existante");
      return false;
   }
   
   // Vérifier le spread
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(spread > 20) // Maximum 20 points de spread
   {
      Print("❌ FC1: Spread trop élevé: ", spread);
      return false;
   }
   
   // Vérifier si le marché est assez volatil
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(atr <= 0)
   {
      Print("❌ FC1: ATR invalide");
      return false;
   }
   
   Print("✅ FC1: Signal validé - Pente: ", slope, ", ATR: ", atr);
   return true;
}

//+------------------------------------------------------------------+
//| Exécute un trade basé sur le signal FC1                            |
//+------------------------------------------------------------------+
void ExecuteFC1Trade(bool isBuySignal)
{
   string symbol = _Symbol;
   double lotSize = 0.1; // Taille de lot fixe pour FC1
   
   // Obtenir les prix actuels
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculer SL/TP basés sur l'ATR
   double atr = iATR(symbol, PERIOD_CURRENT, 14);
   if(atr <= 0) 
   {
      Print("❌ FC1: Impossible d'obtenir l'ATR");
      return;
   }
   
   double entryPrice = isBuySignal ? ask : bid;
   double sl = isBuySignal ? entryPrice - atr * 2.0 : entryPrice + atr * 2.0;
   double tp = isBuySignal ? entryPrice + atr * 3.0 : entryPrice - atr * 3.0;
   
   Print("🎯 FC1: Exécution du trade - ", isBuySignal ? "BUY" : "SELL");
   Print("📍 FC1: Entry: ", entryPrice, " SL: ", sl, " TP: ", tp, " Lot: ", lotSize);
   
   // Exécuter le trade
   bool success = false;
   if(isBuySignal)
   {
      success = g_trade.Buy(lotSize, symbol, entryPrice, sl, tp, "FC1 Auto Buy");
   }
   else
   {
      success = g_trade.Sell(lotSize, symbol, entryPrice, sl, tp, "FC1 Auto Sell");
   }
   
   if(success)
   {
      Print("✅ FC1: Trade exécuté avec succès!");
      
      // Envoyer une notification
      string notification = StringFormat("🚨 FC1 AUTO: %s %s @%.5f", 
                                        symbol, 
                                        isBuySignal ? "BUY" : "SELL", 
                                        entryPrice);
      SendNotification(notification);
      
      // Créer une alerte visuelle
      Alert("FC1 AUTO TRADE: ", isBuySignal ? "BUY" : "SELL", " ", symbol, " à ", entryPrice);
   }
   else
   {
      Print("❌ FC1: Erreur d'exécution - Code: ", g_trade.ResultRetcode(), " - ", g_trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Fonction pour détecter si FC1 est en train de clignoter            |
//+------------------------------------------------------------------+
bool IsFC1Blinking()
{
   // Vérifier si l'objet FC1 existe
   if(ObjectFind(0, "ANGEL_FC1") < 0)
      return false;
   
   // Détecter les changements de couleur (signe de clignotement)
   static ulong lastUpdateTime = 0;
   static color lastColor = clrNONE;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - lastUpdateTime < 1) // Vérifier chaque seconde
      return false;
   
   color currentColor = (color)ObjectGetInteger(0, "ANGEL_FC1", OBJPROP_COLOR);
   
   // Si la couleur a changé, c'est que FC1 clignote
   bool isBlinking = (lastColor != clrNONE && currentColor != lastColor);
   
   lastUpdateTime = currentTime;
   lastColor = currentColor;
   
   return isBlinking;
}

//+------------------------------------------------------------------+
int CountOpenSymbols()
{
   string seen[16]; int seenN=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      string s=PositionGetString(POSITION_SYMBOL);
      bool found=false; for(int j=0;j<seenN;j++){ if(seen[j]==s){ found=true; break; } }
      if(!found && seenN<16){ seen[seenN++]=s; }
   }
   return seenN;
}

//+------------------------------------------------------------------+
// Compte le nombre total de positions ouvertes par l'EA (tous symboles confondus)
int CountOpenPositionsEA()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   { 
      ulong tk=PositionGetTicket(i); 
      if(!PositionSelectByTicket(tk)) continue; 
      
      // Compter SEULEMENT les positions de l'EA (Magic Number)
      if((int)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) 
      {
         c++;
      }
   }
   return c;
}

// FONCTION D'URGENCE: Fermer automatiquement les positions multiples sur un symbole
void EmergencyCloseMultiplePositions(const string symbol)
{
   int positionsCount = 0;
   ulong tickets[];
   ArrayResize(tickets, 0);
   
   // Compter les positions EA sur ce symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      
      positionsCount++;
      ArrayResize(tickets, positionsCount);
      tickets[positionsCount-1] = ticket;
   }
   
   // Si plus d'une position, fermer toutes sauf la première
   if(positionsCount > 1)
   {
      Print("🚨 URGENCE: ", positionsCount, " positions EA détectées sur ", symbol, " - Fermeture d'urgence!");
      
      // Fermer toutes les positions sauf la première (garder la plus ancienne)
      for(int i = 1; i < positionsCount; i++)
      {
         if(PositionSelectByTicket(tickets[i]))
         {
            double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(symbol, SYMBOL_ASK);
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.position = tickets[i];
            request.symbol = symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = price;
            request.magic = InpMagicNumber;
            
            if(OrderSend(request, result))
            {
               Print("✅ Position d'urgence fermée: ", tickets[i], " sur ", symbol);
            }
            else
            {
               Print("❌ Échec fermeture d'urgence: ", tickets[i], " - Erreur: ", result.retcode);
            }
         }
      }
   }
}

// FONCTION D'URGENCE GLOBALE: Fermer toutes les positions multiples sur tous les symboles
void EmergencyCloseAllMultiplePositions()
{
   string symbols[];
   int symbolCount = 0;
   
   // Collecter tous les symboles avec des positions EA
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      bool found = false;
      for(int j = 0; j < symbolCount; j++)
      {
         if(symbols[j] == symbol) { found = true; break; }
      }
      if(!found)
      {
         ArrayResize(symbols, symbolCount + 1);
         symbols[symbolCount] = symbol;
         symbolCount++;
      }
   }
   
   // Vérifier et fermer les positions multiples sur chaque symbole
   for(int i = 0; i < symbolCount; i++)
   {
      EmergencyCloseMultiplePositions(symbols[i]);
   }
}

// Supprime les espaces d'une chaîne
string StringTrim(const string str)
{
   string result = str;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
}

// Vérifie si c'est un symbole Boom/Crash
bool IsBoomCrashSymbol(const string symbol)
{
   return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

// Vérifie si on peut trader ce symbole
bool CanTradeSymbol(const string symbol)
{
   if(IsBoomCrashSymbol(symbol)) return true;
   
   string symbols[];
   StringSplit(InpAllowedSymbols, ',', symbols);
   
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string s = StringTrim(symbols[i]);
      if(IsBoomCrashSymbol(s) && HasSpikeOpportunity(s))
      {
         if(InpDebug) Print("[Angel] Opportunité Boom/Crash détectée - Ignorer ", symbol);
         return false; // Pas de signal
      }
   }
   
   return true;
}

// Vérifie si une opportunité de spike est présente
bool HasSpikeOpportunity(const string symbol)
{
   // Implémentez votre logique de détection de spike ici
   return false; // Pas de signal
}

// Détection de pré-spike avancée (copiée de clean_spikeh_simple.mq5)
bool DetectEMASpike(const string symbol, int &direction, double &confidence)
{
   direction = 0;
   confidence = 0.0;
   
   // Vérifier que c'est un symbole Boom/Crash
   if(!IsBoomCrashSymbol(symbol)) return false;
   
   // Obtenir les valeurs EMA
   double ema20[], ema50[];
   if(CopyBuffer(g_hEMA20, 0, 0, 2, ema20) < 2) return false;
   if(CopyBuffer(g_hEMA50, 0, 0, 2, ema50) < 2) return false;
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double touchDistance = InpEMATouchDistance * point;
   
   // Vérifier si le prix touche l'EMA 20 ou EMA 50
   bool touchesEMA20 = (MathAbs(currentPrice - ema20[0]) <= touchDistance);
   bool touchesEMA50 = (MathAbs(currentPrice - ema50[0]) <= touchDistance);
   
   if(!touchesEMA20 && !touchesEMA50) return false;
   
   // Déterminer la tendance basée sur la position des EMA
   bool bullishTrend = (ema20[0] > ema50[0]); // EMA 20 au-dessus de EMA 50 = tendance haussière
   bool bearishTrend = (ema20[0] < ema50[0]); // EMA 20 en-dessous de EMA 50 = tendance baissière
   
   // Logique de trading
   if(bullishTrend && touchesEMA20)
   {
      // Tendance haussière + prix touche EMA 20 = Signal BUY (Boom)
      direction = POSITION_TYPE_BUY;
      confidence = 95.0;
      Print("🚀 SIGNAL BOOM: Prix touche EMA 20 en tendance haussière sur ", symbol);
      
      // Afficher la flèche clignotante avant le spike
      ShowSpikeArrow(symbol, direction);
   }
   else if(bullishTrend && touchesEMA50)
   {
      // Tendance haussière + prix touche EMA 50 = Signal BUY fort (Boom)
      direction = POSITION_TYPE_BUY;
      confidence = 95.0;
      Print("🚀 SIGNAL BOOM FORT: Prix touche EMA 50 en tendance haussière sur ", symbol);
      
      // Afficher la flèche clignotante avant le spike
      ShowSpikeArrow(symbol, direction);
   }
   else if(bearishTrend && touchesEMA20)
   {
      // Tendance baissière + prix touche EMA 20 = Signal SELL (Crash)
      direction = POSITION_TYPE_SELL;
      confidence = 90.0;
      Print("💥 SIGNAL CRASH: Prix touche EMA 20 en tendance baissière sur ", symbol);
      
      // Afficher la flèche clignotante avant le spike
      ShowSpikeArrow(symbol, direction);
   }
   else if(bearishTrend && touchesEMA50)
   {
      // Tendance baissière + prix touche EMA 50 = Signal SELL fort (Crash)
      direction = POSITION_TYPE_SELL;
      confidence = 95.0;
      Print("💥 SIGNAL CRASH FORT: Prix touche EMA 50 en tendance baissière sur ", symbol);
      
      // Afficher la flèche clignotante avant le spike
      ShowSpikeArrow(symbol, direction);
   }
   
   return (direction != 0 && confidence >= 85.0);
}

// Calculer SL/TP pour la stratégie EMA Boom/Crash
bool CalculateEMASLTP(const string symbol, const int direction, const double lot, double &sl, double &tp)
{
   double currentPrice = (direction == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Utiliser la nouvelle fonction basée sur les candlesticks
   ComputeSpikeSLTP_ByCandlesticks(symbol, direction, lot, sl, tp);
   
   return (sl > 0 && tp > 0);
}

// Afficher une flèche clignotante avant le spike
void ShowSpikeArrow(const string symbol, const int direction)
{
   if(!InpShowSpikeArrow) return;
   
   // Supprimer l'ancienne flèche s'il y en a une
   if(g_arrowSymbol != "" && g_arrowSymbol != symbol)
   {
      ObjectDelete(0, "SPIKE_ARROW_" + g_arrowSymbol);
   }
   
   // Obtenir les informations de la barre actuelle
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 1, rates) < 1) return;
   
   double price = (direction == POSITION_TYPE_BUY) ? rates[0].low - 10*SymbolInfoDouble(symbol, SYMBOL_POINT) 
                                                   : rates[0].high + 10*SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Créer la flèche
   string arrowId = "SPIKE_ARROW_" + symbol;
   if(ObjectFind(0, arrowId) >= 0) ObjectDelete(0, arrowId);
   
   ObjectCreate(0, arrowId, OBJ_ARROW, 0, rates[0].time, price);
   
   // Configuration de la flèche
   if(direction == POSITION_TYPE_BUY)
   {
      ObjectSetInteger(0, arrowId, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
      ObjectSetInteger(0, arrowId, OBJPROP_COLOR, clrLime);
   }
   else
   {
      ObjectSetInteger(0, arrowId, OBJPROP_ARROWCODE, 234); // Flèche vers le bas
      ObjectSetInteger(0, arrowId, OBJPROP_COLOR, clrRed);
   }
   
   ObjectSetInteger(0, arrowId, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, arrowId, OBJPROP_BACK, false);
   ObjectSetInteger(0, arrowId, OBJPROP_SELECTABLE, false);
   
   // Initialiser les variables de clignotement
   g_arrowStartTime = TimeCurrent();
   g_arrowSymbol = symbol;
   g_arrowDirection = direction;
   g_arrowVisible = true;
   
   Print("🚨 FLÈCHE SPIKE AFFICHÉE: ", symbol, " Direction=", (direction==POSITION_TYPE_BUY?"BUY":"SELL"));
}

// Gérer l'animation de clignotement de la flèche
void UpdateSpikeArrowBlinking()
{
   if(!InpShowSpikeArrow || g_arrowSymbol == "") return;
   
   int elapsedSeconds = (int)(TimeCurrent() - g_arrowStartTime);
   
   // Supprimer la flèche après la durée de clignotement
   if(elapsedSeconds >= InpArrowBlinkSeconds)
   {
      ObjectDelete(0, "SPIKE_ARROW_" + g_arrowSymbol);
      g_arrowSymbol = "";
      g_arrowDirection = 0;
      g_arrowVisible = false;
      return;
   }
   
   // Animation de clignotement (toutes les 0.5 secondes)
   bool shouldBeVisible = ((elapsedSeconds * 2) % 2 == 0);
   
   if(shouldBeVisible != g_arrowVisible)
   {
      g_arrowVisible = shouldBeVisible;
      string arrowId = "SPIKE_ARROW_" + g_arrowSymbol;
      
      if(g_arrowVisible)
      {
         // Réafficher la flèche
         MqlRates rates[];
         if(CopyRates(g_arrowSymbol, PERIOD_M1, 0, 1, rates) >= 1)
         {
            double price = (g_arrowDirection == POSITION_TYPE_BUY) ? rates[0].low - 10*SymbolInfoDouble(g_arrowSymbol, SYMBOL_POINT) 
                                                                   : rates[0].high + 10*SymbolInfoDouble(g_arrowSymbol, SYMBOL_POINT);
            
            if(ObjectFind(0, arrowId) < 0)
            {
               ObjectCreate(0, arrowId, OBJ_ARROW, 0, rates[0].time, price);
               
               if(g_arrowDirection == POSITION_TYPE_BUY)
               {
                  ObjectSetInteger(0, arrowId, OBJPROP_ARROWCODE, 233);
                  ObjectSetInteger(0, arrowId, OBJPROP_COLOR, clrLime);
               }
               else
               {
                  ObjectSetInteger(0, arrowId, OBJPROP_ARROWCODE, 234);
                  ObjectSetInteger(0, arrowId, OBJPROP_COLOR, clrRed);
               }
               
               ObjectSetInteger(0, arrowId, OBJPROP_WIDTH, 3);
               ObjectSetInteger(0, arrowId, OBJPROP_BACK, false);
               ObjectSetInteger(0, arrowId, OBJPROP_SELECTABLE, false);
            }
         }
      }
      else
      {
         // Masquer la flèche
         ObjectDelete(0, arrowId);
      }
   }
}

// Fermer automatiquement les positions EMA après le délai spécifié
void CloseEMAPositionsAfterDelay()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      // Ne traiter que les positions EA
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(!IsBoomCrashSymbol(symbol)) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "EMA_Spike") < 0) continue; // Seulement les trades EMA
      
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int timeOpen = (int)(TimeCurrent() - openTime);
      
      // Fermer après le délai spécifié
      if(timeOpen >= InpSpikeCloseSeconds)
      {
         if(g_trade.PositionClose(ticket))
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            Print("⏰ POSITION EMA FERMÉE après ", InpSpikeCloseSeconds, "s sur ", symbol, " - Profit: $", DoubleToString(profit, 2));
         }
      }
   }
}

// Calcule la proximité aux niveaux S/R (en pourcentage)
double GetSRProximity(const string symbol, double price)
{
   double min_distance = 1.0; // Distance minimale en pourcentage
   
   // Vérifier les niveaux S/R existants
   for(int i = 0; i < g_srND1; i++)
   {
      double distance = MathAbs(price - g_srLevelsD1[i]) / price;
      if(distance < min_distance) min_distance = distance;
   }
   
   for(int i = 0; i < g_srNH4; i++)
   {
      double distance = MathAbs(price - g_srLevelsH4[i]) / price;
      if(distance < min_distance) min_distance = distance;
   }
   
   for(int i = 0; i < g_srNH1; i++)
   {
      double distance = MathAbs(price - g_srLevelsH1[i]) / price;
      if(distance < min_distance) min_distance = distance;
   }
   
   for(int i = 0; i < g_srNM30; i++)
   {
      double distance = MathAbs(price - g_srLevelsM30[i]) / price;
      if(distance < min_distance) min_distance = distance;
   }
   
   return min_distance;
}

// Ferme toutes les positions
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)) && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         g_trade.PositionClose(PositionGetInteger(POSITION_TICKET));
      }
   }
}

// Vérifie les pertes globales
bool CheckGlobalLoss()
{
   double totalLoss = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit < 0) totalLoss += MathAbs(profit);
   }
   
   // Conversion en USD si nécessaire
   if(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT) != "USD")
   {
      double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
      totalLoss *= tickValue;
   }
   
   if(totalLoss >= InpMaxLossBoomCrashUSD)
   {
      Print("[Angel] Perte globale (", DoubleToString(totalLoss, 2), 
            "$) dépasse le seuil (", DoubleToString(InpMaxLossBoomCrashUSD, 2), "$)");
      CloseAllPositions();
      return false; // Pas de signal
   }
   
   return true;
}

// Vérifie si on peut ouvrir une position sur un symbole
bool CanOpenSymbol(const string symbol, const int direction)
{
   // Vérification du nombre total de positions
   int totalPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)) && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         totalPositions++;
      }
   }
   
   if(totalPositions >= InpMaxConcurrentSymbols) 
   {
      if(InpDebug) Print("[Angel] Maximum de positions atteint (", InpMaxConcurrentSymbols, ")");
      return false; // Pas de signal
   }
   
   // Vérification par symbole
   int symbolPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)) && 
         PositionGetString(POSITION_SYMBOL) == symbol)
      {
         symbolPositions++;
         if(PositionGetInteger(POSITION_TYPE) == direction)
         {
            if(InpDebug) Print("[Angel] Position existante dans la même direction sur ", symbol);
            return false; // Pas de signal
         }
      }
   }
   
   return symbolPositions < InpMaxPositionsPerSymbol;
}

// Calcul de lot amélioré avec gestion du risque (copié de clean_spikeh_simple.mq5)
double CalculateLotSizeAdvanced(const string symbol, double risk_percent = 2.0)
{
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   double lot_size = InpCapitalPerTradeUSD / 10.0; // Base sur le capital par trade
   
   // Ajuster selon le capital disponible et le risque
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(current_balance > 0) 
   {
      double risk_amount = current_balance * (risk_percent / 100.0);
      double stop_loss_points = 10.0; // 10 points par défaut
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(stop_loss_points > 0 && tick_value > 0 && tick_size > 0) 
      {
         double risk_lot_size = risk_amount / (stop_loss_points / tick_size * tick_value);
         lot_size = MathMin(lot_size, risk_lot_size);
      }
   }
   
   // Vérifier les limites
   lot_size = MathMax(lot_size, min_lot);
   lot_size = MathMin(lot_size, max_lot);
   
   // Arrondir selon le step
   lot_size = MathRound(lot_size / lot_step) * lot_step;
   
   // Vérifier la marge disponible
   double margin_required = lot_size * SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   if(margin_required > free_margin * 0.8) 
   {
      // Réduire le lot si marge insuffisante
      lot_size = (free_margin * 0.8) / SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
      lot_size = MathRound(lot_size / lot_step) * lot_step;
      lot_size = MathMax(lot_size, min_lot);
   }
   
   return lot_size;
}

// Vérifie si un trade manuel est autorisé (indépendamment des limites EA)
bool IsManualTradeAllowed(const string symbol)
{
   if(!InpAllowManualTrading) 
   {
      Print("🚫 TRADES MANUELS DÉSACTIVÉS");
      return false; // Pas de signal
   }
   
   // Vérifier seulement les positions manuelles sur ce symbole
   int manualPositionsOnSymbol = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) continue; // Ignorer les positions EA
      if(PositionGetString(POSITION_SYMBOL) == symbol) manualPositionsOnSymbol++;
   }
   
   // Autoriser les trades manuels même si l'EA a atteint sa limite
   Print("✅ TRADE MANUEL AUTORISÉ sur ", symbol, " (", manualPositionsOnSymbol, " positions manuelles sur ce symbole)");
   return true;
}

// Fonction appelée à chaque modification de l'état du compte ou des positions
void OnTrade()
{
    // Mettre à jour le HUD si activé
    if(InpShowHUD) {
        UpdateHUD();
    }
    
    // Vérifier les positions ouvertes
    if(PositionsTotal() > 0) {
        ManageOpenPositions();
    }
    
    // Mettre à jour les indicateurs si nécessaire
    if(InpShowIndicators) {
        UpdateIndicators();
    }
}

// Fonction appelée quand l'utilisateur fait un trade manuel
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   // Vérifier si c'est un trade manuel (magic number différent de l'EA)
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         // Vérifier si c'est un trade manuel
         if(trans.position > 0)
         {
            if(PositionSelectByTicket(trans.position))
            {
               long magic = PositionGetInteger(POSITION_MAGIC);
               if(magic != InpMagicNumber) // Trade manuel détecté
               {
                  string symbol = PositionGetString(POSITION_SYMBOL);
                  Print("✅ TRADE MANUEL DÉTECTÉ: ", symbol, " Magic=", magic, " (EA Magic=", InpMagicNumber, ")");
                  Print("📊 STATUT: Trades manuels AUTORISÉS - EA continue de fonctionner normalement");
               }
            }
         }
      }
   }
}

// Détection de clusters de spikes (copié de clean_spikeh_simple.mq5)
bool DetectSpikeCluster(const string symbol, double current_price, double current_volatility)
{
   // Vérifier si la volatilité actuelle dépasse le seuil d'accélération
   double avg_volatility = CalculateAverageVolatility(symbol);
   bool volatility_spike = current_volatility > (avg_volatility * 1.5);
   
   // Vérifier si on est proche d'un niveau S/R (zone de conflit)
   double sr_proximity = GetSRProximity(symbol, current_price);
   bool near_sr = sr_proximity <= 0.15;
   
   // Vérifier l'alignement multi-timeframe
   bool mtf_aligned = CheckMTFAlignment(symbol);
   
   // Vérifier la compression/expansion des Bollinger Bands
   bool bb_compression = CheckBollingerCompression(symbol);
   
   return volatility_spike && (near_sr || mtf_aligned) && bb_compression;
}

// Calcul de la volatilité moyenne
double CalculateAverageVolatility(const string symbol)
{
   int atr_period = 14;
   int atr = iATR(symbol, PERIOD_M1, atr_period);
   if(atr == INVALID_HANDLE) return 0.0;
   
   double a[50]; 
   ArrayInitialize(a, 0.0);
   int n = CopyBuffer(atr, 0, 0, 50, a);
   if(n < atr_period)
   {
      IndicatorRelease(atr); 
      return 0.0;
   }
   
   double avg = 0.0; 
   for(int i = 1; i < n; i++) avg += a[i]; 
   avg /= MathMax(1, n-1);
   
   IndicatorRelease(atr);
   return avg;
}

// Vérification alignement multi-timeframe
bool CheckMTFAlignment(const string symbol)
{
   // Vérifier EMA sur M5 et M15
   int ema5 = iMA(symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   int ema15 = iMA(symbol, PERIOD_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema5 == INVALID_HANDLE || ema15 == INVALID_HANDLE) return false;
   
   double ema5_val[1], ema15_val[1];
   if(CopyBuffer(ema5, 0, 0, 1, ema5_val) < 1 || CopyBuffer(ema15, 0, 0, 1, ema15_val) < 1)
   {
      IndicatorRelease(ema5);
      IndicatorRelease(ema15);
      return false; // Pas de signal
   }
   
   double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
   bool aligned = ((ema5_val[0] < current_price) == (ema15_val[0] < current_price));
   
   IndicatorRelease(ema5);
   IndicatorRelease(ema15);
   return aligned;
}

// Vérification compression Bollinger Bands
bool CheckBollingerCompression(const string symbol)
{
   int bb = iBands(symbol, PERIOD_M1, 20, 0, 2.0, PRICE_CLOSE);
   if(bb == INVALID_HANDLE) return false;
   
   double up[3], mid[3], lo[3];
   if(CopyBuffer(bb, 0, 0, 3, up) < 3 || CopyBuffer(bb, 1, 0, 3, mid) < 3 || CopyBuffer(bb, 2, 0, 3, lo) < 3)
   {
      IndicatorRelease(bb); 
      return false; // Pas de signal
   }
   
   double bbw = (up[0] - lo[0]) / MathMax(1e-8, mid[0]);
   bool compressed = (bbw <= 0.6); // Compression
   
   IndicatorRelease(bb);
   return compressed;
}

// Vrai si le symbole a déjà une position OU un ordre en attente du robot (EA uniquement)
bool HasActiveEAOnSymbol(const string symbol)
{
   // Vérifier les positions de l'EA uniquement
   for(int i=PositionsTotal()-1;i>=0;i--)
   { 
      ulong tk=PositionGetTicket(i); 
      if(!PositionSelectByTicket(tk)) continue; 
      if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue; 
      if(PositionGetString(POSITION_SYMBOL)==symbol) return true; 
   }
   
   // Vérifier les ordres de l'EA uniquement
   for(int j=OrdersTotal()-1;j>=0;j--)
   { 
      ulong ok=OrderGetTicket(j); 
      if(!OrderSelect(ok)) continue; 
      if((int)OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber) continue; 
      if(OrderGetString(ORDER_SYMBOL)==symbol) return true; 
   }
   return false; // Pas de signal
}

bool GlobalLossGuard()
{
   if(InpMaxGlobalOpenLossUSD<=0.0) return true;
   double total=0.0;
   
   // Calculer les pertes des positions de l'EA uniquement
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); 
      if(!PositionSelectByTicket(tk)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      total += PositionGetDouble(POSITION_PROFIT);
   }
   
   // Si la somme des pertes courantes dépasse le plafond, fermer immédiatement toutes les positions du robot
   if(total <= -MathAbs(InpMaxGlobalOpenLossUSD)){
      for(int i=PositionsTotal()-1;i>=0;i--){
         ulong tk=PositionGetTicket(i); 
         if(!PositionSelectByTicket(tk)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
         
         long ptype = PositionGetInteger(POSITION_TYPE);
         double vol  = PositionGetDouble(POSITION_VOLUME);
         g_trade.SetExpertMagicNumber(InpMagicNumber);
         if(ptype==POSITION_TYPE_BUY)  g_trade.Sell(vol, PositionGetString(POSITION_SYMBOL));
         if(ptype==POSITION_TYPE_SELL) g_trade.Buy(vol, PositionGetString(POSITION_SYMBOL));
      }
      return false; // Pas de signal
   }
   return true;
}

bool IsSpikeBar(const MqlRates &bar, const double atr)
{
   double range = bar.high - bar.low;
   double body  = MathAbs(bar.close - bar.open);
   double upper = bar.high - MathMax(bar.open, bar.close);
   double lower = MathMin(bar.open, bar.close) - bar.low;
   if(atr<=0.0 || body<=0.0) return false;
   if(range < 1.0*atr) return false; // Seuil ATR par défaut
   if(MathMax(upper,lower)/body < 1.0) return false; // Seuil wick/body par défaut
   return true;
}

// ===================================================================
// DETECTION SPIKE SIMPLE
// Version simplifiée pour MetaTrader 5
// ===================================================================
bool DetectSpikeNow(const string symbol, int &outDir)
{
   outDir = 0;
   
   // RÉCUPÉRATION DES DONNÉES M1
   MqlRates r[5]; 
   if(CopyRates(symbol, PERIOD_M1, 0, 5, r) < 5) 
   { 
      return false; // Pas de signal 
   }
   
   // ATR POUR VOLATILITÉ
   int hAtr = iATR(symbol, PERIOD_M1, 14); 
   double abuf[]; 
   double atr = 0.0;
   if(hAtr != INVALID_HANDLE && CopyBuffer(hAtr, 0, 1, 1, abuf) >= 1)
   { 
      atr = abuf[0]; 
      IndicatorRelease(hAtr);
   } 
               else
               {
      return false; // Pas de signal 
   }
   
   // DETECTION SPIKE AVANCÉE - PRÉDICTION AVANT L'ARRIVÉE
   
   // 1. ANALYSE DE LA BARRE ACTUELLE (r[0]) - Spike en cours
   double currentRange = r[0].high - r[0].low;
   double currentBody = MathAbs(r[0].close - r[0].open);
   double currentUpper = r[0].high - MathMax(r[0].open, r[0].close);
   double currentLower = MathMin(r[0].open, r[0].close) - r[0].low;
   
   // 2. ANALYSE DE LA BARRE PRÉCÉDENTE (r[1]) - Pattern pré-spike
   double prevRange = r[1].high - r[1].low;
   double prevBody = MathAbs(r[1].close - r[1].open);
   double prevUpper = r[1].high - MathMax(r[1].open, r[1].close);
   double prevLower = MathMin(r[1].open, r[1].close) - r[1].low;
   
   // 3. DÉTECTION SPIKE IMMÉDIAT (barre actuelle)
   if(atr > 0.0 && currentBody > 0.0 && currentRange >= 1.0 * atr && (MathMax(currentUpper, currentLower) / currentBody) >= 1.0)
   {
      // Déterminer la direction
      if(currentUpper > currentLower)
      {
         outDir = POSITION_TYPE_SELL; // Mèche haute = SELL
      }
      else
      {
         outDir = POSITION_TYPE_BUY;  // Mèche basse = BUY
      }
      
      g_isSpikePredicted = false; // Spike immédiat
      Print("🚀 SPIKE IMMÉDIAT DÉTECTÉ sur ", symbol, " - Direction: ", (outDir == POSITION_TYPE_BUY ? "BUY" : "SELL"));
      return true;
   }
   
   // 4. PRÉDICTION SPIKE (pattern pré-spike sur barre précédente)
   if(atr > 0.0 && prevBody > 0.0 && prevRange >= 1.0 * 0.8 * atr && (MathMax(prevUpper, prevLower) / prevBody) >= 1.0 * 0.8)
   {
      // Analyser le momentum pour prédire la direction
      double momentum = r[0].close - r[1].close;
      
      if(momentum > 0 && prevUpper > prevLower)
      {
         outDir = POSITION_TYPE_SELL; // Momentum haussier + mèche haute = SELL
      }
      else if(momentum < 0 && prevLower > prevUpper)
      {
         outDir = POSITION_TYPE_BUY;  // Momentum baissier + mèche basse = BUY
      }
               else
               {
         return false; // Pas de signal // Pattern non concluant
      }
      
      g_isSpikePredicted = true; // Spike prédit
      Print("🔮 SPIKE PRÉDIT sur ", symbol, " - Direction: ", (outDir == POSITION_TYPE_BUY ? "BUY" : "SELL"), " (Pattern pré-spike détecté)");
      return true;
   }
   
      return false; // Pas de signal 
   }

// ===================================================================
// CALCUL UNIFIÉ DE PROBABILITÉ SPIKE M1
// Système unique basé sur confluence M1 uniquement
// ===================================================================
double CalculateSpikeM1Probability(string symbol, int &outDirection)
{
   outDirection = 0;
   
   // VÉRIFICATIONS PRÉALABLES STRICTES
   if(!SymbolSelect(symbol, true)) 
   {
      Print("Échec de la sélection du symbole: ", symbol);
      return 0.0;
   }
   
   Print("=== DÉBUT ANALYSE ", symbol, " ===");
   Print("Heure actuelle: ", TimeToString(TimeCurrent()));
   Print("Prix actuel - Ask: ", SymbolInfoDouble(symbol, SYMBOL_ASK), " Bid: ", SymbolInfoDouble(symbol, SYMBOL_BID));
   if(!IsTradingAllowedNow(symbol)) return 0.0;
   if(!SpreadOk(symbol)) return 0.0;
   
   // VÉRIFICATION ULTRA-STRICTE: Aucune position existante
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return 0.0; // Position existante = probabilité 0
         }
      }
   }
   
   // RÉCUPÉRATION DES DONNÉES M1
   MqlRates r[5]; 
   if(CopyRates(symbol, PERIOD_M1, 0, 5, r) < 5) 
   { 
      return 0.0; 
   }
   
   // ATR POUR VOLATILITÉ
   int hAtr = iATR(symbol, PERIOD_M1, 14); 
   double abuf[]; 
   double atr = 0.0;
   if(hAtr != INVALID_HANDLE && CopyBuffer(hAtr, 0, 1, 1, abuf) >= 1)
   { 
      atr = abuf[0]; 
      IndicatorRelease(hAtr);
   } 
   else
   {
      return 0.0; 
   }
   
   // DÉTERMINER LE TYPE D'INDICE (déclaration globale)
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   
   double totalScore = 0.0;
   int direction = 0;
   
   // 1. ANALYSE M1 PURE (40% du score)
   double m1Score = 0.0;
   
   // Analyse de la barre actuelle (r[0]) - Spike en cours
   double currentRange = r[0].high - r[0].low;
   double currentBody = MathAbs(r[0].close - r[0].open);
   double currentUpper = r[0].high - MathMax(r[0].open, r[0].close);
   double currentLower = MathMin(r[0].open, r[0].close) - r[0].low;
   
   // Analyse de la barre précédente (r[1]) - Pattern pré-spike
   double prevRange = r[1].high - r[1].low;
   double prevBody = MathAbs(r[1].close - r[1].open);
   double prevUpper = r[1].high - MathMax(r[1].open, r[1].close);
   double prevLower = MathMin(r[1].open, r[1].close) - r[1].low;
   
   // Détection spike immédiat (barre actuelle)
   if(atr > 0.0 && currentBody > 0.0 && currentRange >= 1.0 * atr && (MathMax(currentUpper, currentLower) / currentBody) >= 1.0)
   {
      m1Score = 40.0; // Score maximum pour spike immédiat
      
      // Déterminer la direction selon le type d'indice
      if(isBoom)
      {
         direction = POSITION_TYPE_BUY; // Boom = toujours BUY
      }
      else if(isCrash)
      {
         direction = POSITION_TYPE_SELL; // Crash = toujours SELL
      }
      else
      {
         // Pour les autres indices, utiliser la logique des mèches
         if(currentUpper > currentLower)
         {
            direction = POSITION_TYPE_SELL; // Mèche haute = SELL
         }
         else
         {
            direction = POSITION_TYPE_BUY;  // Mèche basse = BUY
         }
      }
   }
   // Prédiction spike (pattern pré-spike sur barre précédente)
   else if(atr > 0.0 && prevBody > 0.0 && prevRange >= 1.0 * 0.8 * atr && (MathMax(prevUpper, prevLower) / prevBody) >= 1.0 * 0.8)
   {
      m1Score = 30.0; // Score élevé pour prédiction
      
      // Pour Boom/Crash, utiliser la direction fixe
      if(isBoom)
      {
         direction = POSITION_TYPE_BUY; // Boom = toujours BUY
      }
      else if(isCrash)
      {
         direction = POSITION_TYPE_SELL; // Crash = toujours SELL
      }
      else
      {
         // Pour les autres indices, analyser le momentum
         double momentum = r[0].close - r[1].close;
         
         if(momentum > 0 && prevUpper > prevLower)
         {
            direction = POSITION_TYPE_SELL; // Momentum haussier + mèche haute = SELL
         }
         else if(momentum < 0 && prevLower > prevUpper)
         {
            direction = POSITION_TYPE_BUY;  // Momentum baissier + mèche basse = BUY
         }
         else
         {
            return 0.0; // Pattern non concluant
         }
      }
   }
   
   totalScore += m1Score;
   
   // 2. ATR ET VOLATILITÉ (25% du score)
   double atrScore = 0.0;
   if(atr > 0.0)
   {
      // Score basé sur la volatilité relative
      double avgRange = 0.0;
      for(int i = 1; i < 5; i++)
      {
         avgRange += (r[i].high - r[i].low);
      }
      avgRange /= 4.0;
      
      if(currentRange > avgRange * 1.5)
      {
         atrScore = 25.0; // Volatilité élevée
      }
      else if(currentRange > avgRange * 1.2)
      {
         atrScore = 20.0; // Volatilité modérée
      }
      else if(currentRange > avgRange)
      {
         atrScore = 15.0; // Volatilité normale
      }
   }
   
   totalScore += atrScore;
   
   // 3. EMA TOUCH/PROXIMITY (20% du score)
   double emaScore = 0.0;
   
   // EMA 20 et 50
   int hEma20 = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   int hEma50 = iMA(symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   double ema20Buf[], ema50Buf[];
   double ema20 = 0.0, ema50 = 0.0;
   
   if(hEma20 != INVALID_HANDLE && CopyBuffer(hEma20, 0, 1, 1, ema20Buf) >= 1)
   {
      ema20 = ema20Buf[0];
      IndicatorRelease(hEma20);
   }
   
   if(hEma50 != INVALID_HANDLE && CopyBuffer(hEma50, 0, 1, 1, ema50Buf) >= 1)
   {
      ema50 = ema50Buf[0];
      IndicatorRelease(hEma50);
   }
   
   if(ema20 > 0.0 && ema50 > 0.0)
   {
      double currentPrice = r[0].close;
      double distance20 = MathAbs(currentPrice - ema20) / currentPrice;
      double distance50 = MathAbs(currentPrice - ema50) / currentPrice;
      
      // Score basé sur la proximité des EMA
      if(distance20 < 0.0005) // Très proche de EMA20
      {
         emaScore = 20.0;
      }
      else if(distance20 < 0.001) // Proche de EMA20
      {
         emaScore = 15.0;
      }
      else if(distance50 < 0.0005) // Très proche de EMA50
      {
         emaScore = 12.0;
      }
      else if(distance50 < 0.001) // Proche de EMA50
      {
         emaScore = 8.0;
      }
   }
   
   totalScore += emaScore;
   
   // 4. SUPPORT/RÉSISTANCE (15% du score)
   double srScore = 0.0;
   
   // Vérifier proximité des niveaux S/R M30
   double currentPrice = r[0].close;
   for(int i = 0; i < g_srNM30; i++)
   {
      double distance = MathAbs(currentPrice - g_srLevelsM30[i]) / currentPrice;
      if(distance < 0.0008) // Proximité S/R
      {
         srScore = 15.0;
         break;
      }
      else if(distance < 0.0015)
      {
         srScore = 10.0;
         break;
      }
   }
   
   totalScore += srScore;
   
   // Normaliser le score final (0-100%)
   double finalProbability = MathMin(totalScore, 100.0);
   
   // Seuil minimum de 85% pour exécution automatique
   if(finalProbability >= 85.0)
   {
      outDirection = direction;
      return finalProbability;
   }
   
   return 0.0; // Probabilité insuffisante
}

// ===================================================================
// SPIKE SCALPING BOOM/CRASH - FERMER ET RENTRER
// Fonction spéciale pour Boom/Crash: fermer sur spike et rentrer si conditions bonnes
// ===================================================================
void HandleBoomCrashSpikeScalping()
{
   if(!InpBCSpikeReEntry) return; // Désactivé si paramètre = false
   
   // Variables pour tracker les re-entries
   static datetime lastSpikeCloseTime = 0;
   static string lastSpikeSymbol = "";
   static int lastSpikeDir = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      long posType = PositionGetInteger(POSITION_TYPE);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      
      // Vérifier si c'est un symbole Boom/Crash
      bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
      if(!isBoomCrash) continue;
      
      // 1. DÉTECTER SPIKE SUR BOOM/CRASH
      int spikeDir = 0;
      bool spikeDetected = DetectSpikeNow(symbol, spikeDir);
      
      if(spikeDetected)
      {
         // 2. FERMER IMMÉDIATEMENT LE TRADE ACTUEL
         if(trade.PositionClose(ticket))
         {
            Print("💥 SPIKE BOOM/CRASH DÉTECTÉ - FERMETURE IMMÉDIATE");
            Print("   Symbole: ", symbol);
            Print("   Profit final: $", DoubleToString(profit, 2));
            Print("   Direction spike: ", (spikeDir == POSITION_TYPE_BUY ? "BUY" : "SELL"));
            
            // Enregistrer le temps et symbole pour re-entry
            lastSpikeCloseTime = TimeCurrent();
            lastSpikeSymbol = symbol;
            lastSpikeDir = spikeDir; // mémoriser direction spike
            
            // Notification
            if(InpSendNotifications)
            {
               string message = StringFormat("💥 SPIKE BOOM/CRASH\n%s fermé\nProfit: $%.2f", symbol, profit);
               SendNotification(message);
            }
         }
         else
         {
            Print("❌ Échec fermeture position ", ticket, " sur ", symbol);
         }
      }
   }
   
   // 3. RE-ENTRY APRÈS SPIKE SI CONDITIONS BONNES
   if(lastSpikeCloseTime > 0 && lastSpikeSymbol != "")
   {
      // Vérifier le délai minimum
      int waitSec = MathMax(InpBCReentryCooldownSec, InpBCSpikeReEntryDelaySec);
      if(TimeCurrent() - lastSpikeCloseTime < waitSec)
      {
         return; // Attendre le délai minimum
      }
      
      // Vérifier qu'aucune position n'existe sur ce symbole
      bool hasPosition = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) == lastSpikeSymbol)
         {
            hasPosition = true;
            break;
         }
      }
      
      if(!hasPosition)
      {
         // Calculer nouvelle probabilité M1
         int newDirection = 0;
         double newProbability = CalculateSpikeM1Probability(lastSpikeSymbol, newDirection);
         
         // Préférer re-entry dans la même direction que le spike détecté
         if(newDirection==0) newDirection = lastSpikeDir;
         
         // Vérifier si les conditions sont toujours bonnes pour re-entry
         if(newProbability >= InpBCSpikeReEntryMinProb)
         {
            Print("🔄 RE-ENTRY BOOM/CRASH APRÈS SPIKE");
            Print("   Symbole: ", lastSpikeSymbol);
            Print("   Nouvelle probabilité: ", DoubleToString(newProbability, 1), "%");
            Print("   Nouvelle direction: ", (newDirection == POSITION_TYPE_BUY ? "BUY" : "SELL"));
            
            // Exécuter le nouveau trade
            if(ExecuteSingleMarketOrder(lastSpikeSymbol, newDirection, newProbability))
            {
               Print("✅ RE-ENTRY BOOM/CRASH RÉUSSI");
               
               // Notification
               if(InpSendNotifications)
               {
                  string message = StringFormat("🔄 RE-ENTRY BOOM/CRASH\n%s %s\nProbabilité: %.1f%%", 
                                               lastSpikeSymbol, 
                                               (newDirection == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                                               newProbability);
                  SendNotification(message);
               }
            }
            else
            {
               Print("❌ ÉCHEC RE-ENTRY BOOM/CRASH");
            }
         }
         else
         {
            Print("📊 RE-ENTRY BOOM/CRASH REFUSÉ - Probabilité insuffisante: ", 
                  DoubleToString(newProbability, 1), "% (min: ", InpBCSpikeReEntryMinProb, "%)");
         }
         
         // Reset pour éviter les re-entries multiples
         lastSpikeCloseTime = 0;
         lastSpikeSymbol = "";
         lastSpikeDir = 0;
      }
   }
}

// ===================================================================
// GESTION AUTO-CLOSE POUR INDICES NON BOOM/CRASH (TP/SL en USD)
// ===================================================================
void ManageNonBoomCrashAutoClose()
{
   if(!InpEnableNonBCAutoClose) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      bool isBC = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
      if(isBC) continue; // seulement non Boom/Crash
      bool isVol = (InpEnableVolScalp && StringFind(symbol, InpVolSymbolsHint) >= 0);
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      
      // Suivi du pic de profit pour Volatility
      if(isVol)
      {
         // Mettre à jour/initialiser le pic
         bool found=false; int idx=-1;
         for(int k=0;k<g_volTicketN;k++){ if(g_volTickets[k]==ticket){ found=true; idx=k; break; } }
         if(!found && g_volTicketN<40){ idx=g_volTicketN++; g_volTickets[idx]=ticket; g_volPeakProfit[idx]=profit; }
         if(idx>=0 && profit>g_volPeakProfit[idx]) g_volPeakProfit[idx]=profit;
         
         // Protection du gain: fermer si retracement >= X% depuis le pic (après min profit)
         if(g_volPeakProfit[idx] >= InpVolMinProfitToLockUSD)
         {
            double retracePct = (g_volPeakProfit[idx] > 0.0) ? (1.0 - (profit / MathMax(1e-9,g_volPeakProfit[idx]))) * 100.0 : 0.0;
            if(retracePct >= InpVolPeakRetracePct)
            {
               if(g_trade.PositionClose(ticket))
               {
                  Print("🔒 VOL scalp close: retrace ", DoubleToString(retracePct,1), "% from peak, profit $", DoubleToString(profit,2));
                  // Armer le re-entry sur ce symbole
                  for(int s=0;s<20;s++){ if(g_volSymbols[s]==symbol || g_volSymbols[s]==""){ g_volSymbols[s]=symbol; g_volLastCloseTime[s]=TimeCurrent(); break; }
                  }
                  continue; // next position
               }
            }
         }
      }
      
      if(profit >= InpNonBC_TP_USD || profit <= -InpNonBC_SL_USD)
      {
         if(trade.PositionClose(ticket))
         {
            Print("🏁 NON-BC AUTO-CLOSE: ", symbol, " fermé à $", DoubleToString(profit, 2),
                  " (TP:", InpNonBC_TP_USD, " SL:", InpNonBC_SL_USD, ")");
            // Armer re-entry pour Volatility uniquement
            if(isVol){ for(int s=0;s<20;s++){ if(g_volSymbols[s]==symbol || g_volSymbols[s]==""){ g_volSymbols[s]=symbol; g_volLastCloseTime[s]=TimeCurrent(); break; } } }
         }
      }
   }
}

// Fonction pour fermer immédiatement après avoir capturé un spike (DÉSACTIVÉE)
void ClosePositionsAfterSpikeCapture()
{
   // DÉSACTIVÉ - Le robot doit être autonome et garder ses positions
   if(!InpCloseAfterSpike) return;
   
   // Cette fonction est maintenant désactivée pour permettre au robot d'être autonome
   // Les positions seront fermées uniquement par SL/TP ou par gestion manuelle
   return;
   
   // Code original désactivé ci-dessous...
   /*
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      long posType = PositionGetInteger(POSITION_TYPE);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      
      // Vérifier si la position a été ouverte récemment (dans les 30 secondes)
      if(TimeCurrent() - openTime > 30) continue;
      
      // Vérifier si c'est un spike capturé (profit positif ou perte minimale)
      if(profit > 0.0 || profit >= -1.0) // Fermer si profit ou perte < 1$
      {
         if(trade.PositionClose(ticket))
         {
            Print("✅ SPIKE CAPTURÉ et FERMÉ sur ", symbol, " - Profit: $", DoubleToString(profit, 2));
         }
         else
         {
            Print("❌ Échec fermeture position ", ticket, " sur ", symbol);
         }
      }
   }
   */
}

int TrendGateDirection(const string symbol)
{
   if(!InpUseMTFGate) return 0; // 0 = neutral (no restriction)
   // Returns +1 if bullish across M30/H1/H4 (EMAfast>EMAslow), -1 if bearish, 0 otherwise
   ENUM_TIMEFRAMES tfs[3] = { PERIOD_M30, PERIOD_H1, PERIOD_H4 };
   int dir = 0;
   for(int i=0;i<3;i++)
   {
      int hF=iMA(symbol, tfs[i], InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
      int hS=iMA(symbol, tfs[i], InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
      double ef=0, es=0;
      if(hF!=INVALID_HANDLE){ double b[]; if(CopyBuffer(hF,0,0,1,b)>0) ef=b[0]; IndicatorRelease(hF);} 
      if(hS!=INVALID_HANDLE){ double b2[]; if(CopyBuffer(hS,0,0,1,b2)>0) es=b2[0]; IndicatorRelease(hS);} 
      int d = (ef>0 && es>0 && ef>es)? +1 : ((ef>0 && es>0 && ef<es)? -1 : 0);
      if(i==0) dir = d; else { if(d!=dir) return 0; }
   }
   return dir; // +1 bull, -1 bear
}

void ComputeSLTP_ByDollar(const string symbol, const int direction, const double lot, double &slPrice, double &tpPrice)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double pt  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double usdPerPointPerLot = GetPointValueUSD(symbol);
   if((usdPerPointPerLot<=0.0 || pt<=0.0) && InpUseFallbackPercentSLTP)
   {
      double entry = (direction==POSITION_TYPE_BUY)? ask : bid;
      double slPct = MathAbs(InpSLPercent)/100.0;
      double tpPct = MathAbs(InpTPPercent)/100.0;
      if(direction==POSITION_TYPE_BUY){ slPrice = NormalizeDouble(entry * (1.0 - slPct), digits); tpPrice = NormalizeDouble(entry * (1.0 + tpPct), digits); }
      else                            { slPrice = NormalizeDouble(entry * (1.0 + slPct), digits); tpPrice = NormalizeDouble(entry * (1.0 - tpPct), digits); }
      return;
   }
   if(usdPerPointPerLot<=0.0 || pt<=0.0){ slPrice=0; tpPrice=0; return; }
   double maxLossPts = MathFloor(MathAbs(GetMaxLossForSymbol(symbol)) / (usdPerPointPerLot * MathMax(lot,1e-9)));
   double targetPts  = MathMax(1.0, MathFloor(MathAbs(InpTargetProfitUSD) / (usdPerPointPerLot * MathMax(lot,1e-9))));
   double entry = (direction==POSITION_TYPE_BUY)? ask : bid;
   if(direction==POSITION_TYPE_BUY){ slPrice = NormalizeDouble(entry - maxLossPts*pt, digits); tpPrice = NormalizeDouble(entry + targetPts*pt, digits); }
   else                            { slPrice = NormalizeDouble(entry + maxLossPts*pt, digits); tpPrice = NormalizeDouble(entry - targetPts*pt, digits); }
}

//+------------------------------------------------------------------+
//| Calcule SL/TP basé sur les candlesticks                          |
//+------------------------------------------------------------------+
void ComputeSLTP_ByCandlesticks(const string symbol, const int direction, const double lot, double &slPrice, double &tpPrice)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double pt  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Récupérer les données des candlesticks
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Obtenir suffisamment de candlesticks pour calculer SL (15) et TP (45)
   int maxCandles = MathMax(45, 20); // Prendre le maximum entre 45 et 20 pour la sécurité
   if(CopyRates(symbol, PERIOD_M1, 0, maxCandles, rates) < maxCandles)
   {
      // Fallback vers la méthode USD si pas assez de données
      ComputeSLTP_ByCandlesticks(symbol, direction, lot, slPrice, tpPrice);
      return;
   }
   
   double entry = (direction==POSITION_TYPE_BUY)? ask : bid;
   
   if(direction==POSITION_TYPE_BUY)
   {
      // Pour un achat, SL = prix le plus bas des 15 dernières bougies
      double lowestPrice = rates[0].low;
      for(int i = 1; i < 15 && i < ArraySize(rates); i++)
      {
         if(rates[i].low < lowestPrice)
            lowestPrice = rates[i].low;
      }
      slPrice = NormalizeDouble(lowestPrice, digits);
      
      // Pour un achat, TP = prix le plus haut des 45 dernières bougies
      double highestPrice = rates[0].high;
      for(int i = 1; i < 45 && i < ArraySize(rates); i++)
      {
         if(rates[i].high > highestPrice)
            highestPrice = rates[i].high;
      }
      tpPrice = NormalizeDouble(highestPrice, digits);
   }
   else
   {
      // Pour une vente, SL = prix le plus haut des 15 dernières bougies
      double highestPrice = rates[0].high;
      for(int i = 1; i < 15 && i < ArraySize(rates); i++)
      {
         if(rates[i].high > highestPrice)
            highestPrice = rates[i].high;
      }
      slPrice = NormalizeDouble(highestPrice, digits);
      
      // Pour une vente, TP = prix le plus bas des 45 dernières bougies
      double lowestPrice = rates[0].low;
      for(int i = 1; i < 45 && i < ArraySize(rates); i++)
      {
         if(rates[i].low < lowestPrice)
            lowestPrice = rates[i].low;
      }
      tpPrice = NormalizeDouble(lowestPrice, digits);
   }
   
   // Vérifier que SL et TP sont valides (pas trop proches du prix d'entrée)
   double minDistance = 10 * pt; // Distance minimale de 10 points
   
   // NOUVELLE VALIDATION: Respecter les exigences du broker
   int stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double brokerMinDistance = MathMax(stopsLevel, freezeLevel) * pt;
   minDistance = MathMax(minDistance, brokerMinDistance);
   
   // Pour Boom/Crash, utiliser des distances plus importantes pour éviter "Invalid stops"
   if(IsBoomCrashIndex(symbol))
   {
      minDistance = MathMax(minDistance, 50 * pt); // Minimum 50 points pour Boom/Crash
   }
   
   if(direction==POSITION_TYPE_BUY)
   {
      if(entry - slPrice < minDistance)
         slPrice = NormalizeDouble(entry - minDistance, digits);
      if(tpPrice - entry < minDistance)
         tpPrice = NormalizeDouble(entry + minDistance, digits);
   }
   else
   {
      if(slPrice - entry < minDistance)
         slPrice = NormalizeDouble(entry + minDistance, digits);
      if(entry - tpPrice < minDistance)
         tpPrice = NormalizeDouble(entry - minDistance, digits);
   }
   
   Print("🎯 SL/TP calculés par candlesticks - SL: ", slPrice, " TP: ", tpPrice, " (Direction: ", (direction==POSITION_TYPE_BUY?"BUY":"SELL"), ")");
}

//+------------------------------------------------------------------+
//| Calcule SL/TP pour les spikes basé sur les candlesticks         |
//+------------------------------------------------------------------+
void ComputeSpikeSLTP_ByCandlesticks(const string symbol, const int direction, const double lot, double &slPrice, double &tpPrice)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double pt  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Récupérer les données des candlesticks
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Obtenir suffisamment de candlesticks pour calculer SL (15) et TP (45)
   int maxCandles = MathMax(45, 20); // Prendre le maximum entre 45 et 20 pour la sécurité
   if(CopyRates(symbol, PERIOD_M1, 0, maxCandles, rates) < maxCandles)
   {
      // Fallback vers la méthode USD si pas assez de données
      double usdPerPoint = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) * (pt / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE));
      if(usdPerPoint <= 0) 
      {
         slPrice = 0; tpPrice = 0; 
         return;
      }
      
      double entry = (direction==POSITION_TYPE_BUY)? ask : bid;
      double targetPoints = InpSpikeTargetUSD / (lot * usdPerPoint);
      double stopLossPoints = InpSpikeStopLossUSD / (lot * usdPerPoint);
      
      if(direction == POSITION_TYPE_BUY)
      {
         tpPrice = NormalizeDouble(entry + (targetPoints * pt), digits);
         slPrice = NormalizeDouble(entry - (stopLossPoints * pt), digits);
      }
      else
      {
         tpPrice = NormalizeDouble(entry - (targetPoints * pt), digits);
         slPrice = NormalizeDouble(entry + (stopLossPoints * pt), digits);
      }
      return;
   }
   
   double entry = (direction==POSITION_TYPE_BUY)? ask : bid;
   
   if(direction==POSITION_TYPE_BUY)
   {
      // Pour un achat, SL = prix le plus bas des 15 dernières bougies
      double lowestPrice = rates[0].low;
      for(int i = 1; i < 15 && i < ArraySize(rates); i++)
      {
         if(rates[i].low < lowestPrice)
            lowestPrice = rates[i].low;
      }
      slPrice = NormalizeDouble(lowestPrice, digits);
      
      // Pour un achat, TP = prix le plus haut des 45 dernières bougies
      double highestPrice = rates[0].high;
      for(int i = 1; i < 45 && i < ArraySize(rates); i++)
      {
         if(rates[i].high > highestPrice)
            highestPrice = rates[i].high;
      }
      tpPrice = NormalizeDouble(highestPrice, digits);
   }
   else
   {
      // Pour une vente, SL = prix le plus haut des 15 dernières bougies
      double highestPrice = rates[0].high;
      for(int i = 1; i < 15 && i < ArraySize(rates); i++)
      {
         if(rates[i].high > highestPrice)
            highestPrice = rates[i].high;
      }
      slPrice = NormalizeDouble(highestPrice, digits);
      
      // Pour une vente, TP = prix le plus bas des 45 dernières bougies
      double lowestPrice = rates[0].low;
      for(int i = 1; i < 45 && i < ArraySize(rates); i++)
      {
         if(rates[i].low < lowestPrice)
            lowestPrice = rates[i].low;
      }
      tpPrice = NormalizeDouble(lowestPrice, digits);
   }
   
   // Vérifier que SL et TP sont valides (pas trop proches du prix d'entrée)
   double minDistance = 10 * pt; // Distance minimale de 10 points
   
   // NOUVELLE VALIDATION: Respecter les exigences du broker
   int stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double brokerMinDistance = MathMax(stopsLevel, freezeLevel) * pt;
   minDistance = MathMax(minDistance, brokerMinDistance);
   
   // Pour Boom/Crash, utiliser des distances plus importantes pour éviter "Invalid stops"
   if(IsBoomCrashIndex(symbol))
   {
      minDistance = MathMax(minDistance, 50 * pt); // Minimum 50 points pour Boom/Crash
   }
   
   if(direction==POSITION_TYPE_BUY)
   {
      if(entry - slPrice < minDistance)
         slPrice = NormalizeDouble(entry - minDistance, digits);
      if(tpPrice - entry < minDistance)
         tpPrice = NormalizeDouble(entry + minDistance, digits);
   }
   else
   {
      if(slPrice - entry < minDistance)
         slPrice = NormalizeDouble(entry + minDistance, digits);
      if(entry - tpPrice < minDistance)
         tpPrice = NormalizeDouble(entry - minDistance, digits);
   }
   
   Print("🔥 SPIKE SL/TP calculés par candlesticks - SL: ", slPrice, " TP: ", tpPrice, " (Direction: ", (direction==POSITION_TYPE_BUY?"BUY":"SELL"), ")");
}

//+------------------------------------------------------------------+
//| Valide les niveaux SL/TP pour éviter "Invalid stops"            |
//+------------------------------------------------------------------+
bool ValidateSLTPLevels(const string symbol, const int direction, const double entryPrice, double &slPrice, double &tpPrice)
{
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Récupérer les exigences du broker
   int stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDistance = MathMax(stopsLevel, freezeLevel) * pt;
   
   // Pour Boom/Crash, utiliser des distances plus importantes
   if(IsBoomCrashIndex(symbol))
   {
      minDistance = MathMax(minDistance, 50 * pt); // Minimum 50 points pour Boom/Crash
   }
   
   bool isValid = true;
   
   if(direction == POSITION_TYPE_BUY)
   {
      // Vérifier SL (doit être en dessous du prix d'entrée)
      if(slPrice > 0 && entryPrice - slPrice < minDistance)
      {
         slPrice = NormalizeDouble(entryPrice - minDistance, digits);
         Print("⚠️ SL ajusté pour respecter distance minimale: ", slPrice);
         isValid = false;
      }
      
      // Vérifier TP (doit être au-dessus du prix d'entrée)
      if(tpPrice > 0 && tpPrice - entryPrice < minDistance)
      {
         tpPrice = NormalizeDouble(entryPrice + minDistance, digits);
         Print("⚠️ TP ajusté pour respecter distance minimale: ", tpPrice);
         isValid = false;
      }
   }
   else
   {
      // Vérifier SL (doit être au-dessus du prix d'entrée)
      if(slPrice > 0 && slPrice - entryPrice < minDistance)
      {
         slPrice = NormalizeDouble(entryPrice + minDistance, digits);
         Print("⚠️ SL ajusté pour respecter distance minimale: ", slPrice);
         isValid = false;
      }
      
      // Vérifier TP (doit être en dessous du prix d'entrée)
      if(tpPrice > 0 && entryPrice - tpPrice < minDistance)
      {
         tpPrice = NormalizeDouble(entryPrice - minDistance, digits);
         Print("⚠️ TP ajusté pour respecter distance minimale: ", tpPrice);
         isValid = false;
      }
   }
   
   // Vérifier que SL et TP sont dans le bon sens
   if(slPrice > 0 && tpPrice > 0)
   {
      if(direction == POSITION_TYPE_BUY)
      {
         if(slPrice >= entryPrice || tpPrice <= entryPrice)
         {
            Print("❌ SL/TP invalides pour BUY: SL=", slPrice, " TP=", tpPrice, " Entry=", entryPrice);
            return false;
         }
      }
      else
      {
         if(slPrice <= entryPrice || tpPrice >= entryPrice)
         {
            Print("❌ SL/TP invalides pour SELL: SL=", slPrice, " TP=", tpPrice, " Entry=", entryPrice);
            return false;
         }
      }
   }
   
   return true;
}

bool CanOpenSymbolForEA(const string symbol)
{
   // RÈGLE STRICTE: Vérifier d'abord s'il y a des ordres multiples
   if(!CheckAndCancelMultipleOrders()) return false;
   
   if(CountOpenSymbols() >= InpMaxConcurrentSymbols) return false;
   
   // Vérifier s'il y a déjà le maximum de positions sur ce symbole (2 positions max)
   int positionCount = 0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); 
      if(!PositionSelectByTicket(tk)) continue; 
      if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue; 
      if(PositionGetString(POSITION_SYMBOL)==symbol) 
      {
         positionCount++;
      }
   }
   
   if(positionCount >= InpMaxPositionsPerSymbol)
   {
      if(InpDebug) Print(StringFormat("[Angel] Maximum positions reached for %s (%d/%d)", symbol, positionCount, InpMaxPositionsPerSymbol));
      return false; // Pas de signal // Maximum de positions atteint pour ce symbole
   }
   
   // Vérifier aussi les ordres en attente sur le même symbole
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong tk=OrderGetTicket(i);
      if(!OrderSelect(tk)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL)==symbol)
      {
         if(InpDebug) Print(StringFormat("[Angel] Pending order already exists for %s (only one direction allowed)", symbol));
         return false; // Pas de signal // Un ordre en attente existe déjà sur ce symbole
      }
   }
   
   // Check cooldown for same symbol (global throttle)
   if(InpMinSecondsBetweenSameSymbol > 0)
   {
      for(int i=0; i<10; i++)
      {
         if(g_lastSymbols[i] == symbol)
         {
            if(TimeCurrent() - g_lastTradeBySymbol[i] < InpMinSecondsBetweenSameSymbol)
            {
               if(InpDebug) Print(StringFormat("[Angel] Cooldown same symbol: %s (wait %d sec)", symbol, InpMinSecondsBetweenSameSymbol));
               return false; // Pas de signal
            }
            break;
         }
      }
   }

   // Boom/Crash per-symbol anti-overtrade cooldown
   if(IsBoomCrashIndex(symbol))
   {
      for(int i=0;i<20;i++)
      {
         if(g_bcCooldownSymbols[i] == symbol && TimeCurrent() < g_bcSymbolCooldownUntil[i])
         {
            if(InpDebug) Print(StringFormat("[Angel] BC anti-overtrade cooldown active on %s until %s", symbol, TimeToString(g_bcSymbolCooldownUntil[i], TIME_SECONDS|TIME_MINUTES)));
            return false; // Pas de signal
         }
      }
   }
   
   return true;
}

// Vérifier et annuler les ordres multiples selon les règles strictes (RENFORCÉE)
bool CheckAndCancelMultipleOrders()
{
   // BLOCAGE PRÉVENTIF RENFORCÉ - Toujours actif
   
   // 1. Vérifier le nombre total de positions EA
   int totalPositionsEA = CountOpenPositionsEA();
   if(totalPositionsEA > 2)
   {
      Print("🚨 URGENCE: Trop de positions EA détectées (", totalPositionsEA, "/2) - Blocage EA uniquement");
      // Ne pas bloquer complètement, juste empêcher les nouveaux trades EA
      return true; // Permettre la continuation pour les trades manuels
   }
   
   // 2. VÉRIFICATION CRITIQUE: Détecter les positions multiples par symbole
   string symbols[];
   int symbolCount = 0;
   
   // Collecter tous les symboles avec des positions EA
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      bool found = false;
      for(int j = 0; j < symbolCount; j++)
      {
         if(symbols[j] == symbol) { found = true; break; }
      }
      if(!found)
      {
         ArrayResize(symbols, symbolCount + 1);
         symbols[symbolCount] = symbol;
         symbolCount++;
      }
   }
   
   // Vérifier chaque symbole pour des positions multiples
   for(int i = 0; i < symbolCount; i++)
   {
      int positionsOnSymbol = 0;
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong ticket = PositionGetTicket(j);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) == symbols[i]) positionsOnSymbol++;
      }
      
      if(positionsOnSymbol > 1)
      {
         Print("🚨 CRITIQUE: ", positionsOnSymbol, " positions EA sur ", symbols[i], " - Blocage immédiat!");
      return false; // Pas de signal
      }
   }
   
   // 2. Vérifier les conflits BUY/SELL sur chaque symbole
   int totalOrders = 0;
   int totalPositions = 0;
   bool hasBuyOrders = false;
   bool hasSellOrders = false;
   string dangerousSymbols = "";
   
   // Compter les ordres en attente et détecter les conflits (EA uniquement)
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      
      totalOrders++;
      string symbol = OrderGetString(ORDER_SYMBOL);
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      
      // Détecter les ordres BUY et SELL sur le même symbole (sans STOP)
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT)
      {
         hasBuyOrders = true;
         dangerousSymbols += symbol + " ";
      }
      else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT)
      {
         hasSellOrders = true;
         dangerousSymbols += symbol + " ";
      }
   }
   
   // Compter les positions ouvertes et détecter les conflits
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      totalPositions++;
      string symbol = PositionGetString(POSITION_SYMBOL);
      long positionType = PositionGetInteger(POSITION_TYPE);
      
      // Détecter les positions BUY et SELL sur le même symbole
      if(positionType == POSITION_TYPE_BUY)
      {
         hasBuyOrders = true;
         dangerousSymbols += symbol + " ";
      }
      else if(positionType == POSITION_TYPE_SELL)
      {
         hasSellOrders = true;
         dangerousSymbols += symbol + " ";
      }
   }
   
   // BLOQUER COMPLÈTEMENT si BUY et SELL simultanés détectés
   if(hasBuyOrders && hasSellOrders)
   {
      Print("🚨 DANGER: BUY et SELL simultanés détectés - BLOCAGE TOTAL ACTIVÉ");
      Print("🚨 Symboles dangereux: " + dangerousSymbols);
      
      // Annuler TOUS les ordres immédiatement
      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(!OrderSelect(ticket)) continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
         
         if(g_trade.OrderDelete(ticket))
         {
            Print("🚨 Ordre dangereux annulé: #" + IntegerToString(ticket));
         }
      }
      
      // Fermer TOUTES les positions immédiatement
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         if(g_trade.PositionClose(ticket))
         {
            Print("🚨 Position dangereuse fermée: #" + IntegerToString(ticket));
         }
      }
      
      // Activer le blocage total du trading
      g_tradingBlocked = true;
      g_blockUntil = TimeCurrent() + 300; // Bloquer pendant 5 minutes
      Print("🚨 BLOCAGE TOTAL ACTIVÉ - Trading suspendu pendant 5 minutes");
      return false; // Pas de signal // BLOQUER TOUT TRADING
   }
   
   // Si plus de 2 signaux (ordre + position > 2), annuler tout
   if(totalOrders + totalPositions > 2)
   {
      Print("⚠️ ORDRES MULTIPLES DÉTECTÉS: " + IntegerToString(totalOrders) + " ordres + " + IntegerToString(totalPositions) + " positions - ANNULATION TOTALE");
      
      // Annuler tous les ordres en attente
      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(!OrderSelect(ticket)) continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
         
         if(g_trade.OrderDelete(ticket))
         {
            if(InpDebug) Print(StringFormat("[Angel] Order cancelled: #%d", ticket));
         }
      }
      
      // Fermer toutes les positions
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         double volume = PositionGetDouble(POSITION_VOLUME);
         string symbol = PositionGetString(POSITION_SYMBOL);
         long type = PositionGetInteger(POSITION_TYPE);
         
         g_trade.SetExpertMagicNumber(InpMagicNumber);
         bool closed = false;
         
         if(type == POSITION_TYPE_BUY)
         {
            closed = g_trade.Sell(volume, symbol);
         }
         else if(type == POSITION_TYPE_SELL)
         {
            closed = g_trade.Buy(volume, symbol);
         }
         
         if(closed)
         {
            if(InpDebug) Print(StringFormat("[Angel] Position closed: #%d", ticket));
         }
      }
      
      if(InpSendNotifications) SendNotification(StringFormat("%s: Multiple orders cancelled - Only 1 signal allowed", InpNotifyTag));
      return false; // Pas de signal // Indique qu'on a annulé des ordres
   }
   
   return true; // Pas d'ordres multiples
}

// Annuler tous les ordres dupliqués et en attente - UNE SEULE POSITION par symbole
void CancelDuplicateOrders()
{
   // Annuler uniquement les doublons (même symbole et même type) en gardant le plus récent
   struct PO { ulong tk; string sym; long type; datetime time; };
   PO arr[64]; int n=0;
   for(int i=OrdersTotal()-1;i>=0 && n<64;i--){ ulong tk=OrderGetTicket(i); if(!OrderSelect(tk)) continue; if((int)OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber) continue; arr[n].tk=tk; arr[n].sym=OrderGetString(ORDER_SYMBOL); arr[n].type=OrderGetInteger(ORDER_TYPE); arr[n].time=(datetime)OrderGetInteger(ORDER_TIME_SETUP); n++; }
   for(int i=0;i<n;i++){
      for(int j=i+1;j<n;j++){
         if(arr[i].sym==arr[j].sym && arr[i].type==arr[j].type){ // duplicate -> delete older
            int idxOld = (arr[i].time<=arr[j].time)? i : j;
            ulong delTk = arr[idxOld].tk; if(OrderSelect(delTk) && g_trade.OrderDelete(delTk)){
               if(InpDebug) Print(StringFormat("[Angel] Duplicate pending removed: %s #%d", arr[idxOld].sym, delTk));
               // mark removed to avoid re-deleting
               arr[idxOld].sym = "";
            }
         }
      }
   }
   
   // Pour chaque symbole, garder au plus InpMaxPositionsPerSymbol positions (les plus récentes)
   string symbols[20];
   int symbolCount = 0;
   
   // D'abord, collecter tous les symboles uniques
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      
      // Vérifier si ce symbole est déjà dans notre liste
      bool found = false;
      for(int j=0; j<symbolCount; j++)
      {
         if(symbols[j] == symbol)
         {
            found = true;
            break;
         }
      }
      
      if(!found && symbolCount < 20)
      {
         symbols[symbolCount++] = symbol;
      }
   }
   
   // Pour chaque symbole, vérifier le nombre de positions et fermer les plus anciennes
   for(int s=0; s<symbolCount; s++)
   {
      string currentSymbol = symbols[s];
      int positionCount = 0;
      
      // Compter les positions pour ce symbole
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != currentSymbol) continue;
         
         positionCount++;
      }
      
      // Si plus de 2 positions, fermer les plus anciennes
      if(positionCount > InpMaxPositionsPerSymbol)
      {
         // Créer un tableau des positions avec leurs timestamps
         struct PositionInfo
         {
            ulong ticket;
            datetime openTime;
         };
         
         PositionInfo positions[20];
         int posIndex = 0;
         
         for(int i=PositionsTotal()-1; i>=0 && posIndex<20; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != currentSymbol) continue;
            
            positions[posIndex].ticket = ticket;
            positions[posIndex].openTime = (datetime)PositionGetInteger(POSITION_TIME);
            posIndex++;
         }
         
         // Trier par timestamp (plus ancien en premier)
         for(int i=0; i<posIndex-1; i++)
         {
            for(int j=i+1; j<posIndex; j++)
            {
               if(positions[i].openTime > positions[j].openTime)
               {
                  PositionInfo temp = positions[i];
                  positions[i] = positions[j];
                  positions[j] = temp;
               }
            }
         }
         
         // Fermer les positions les plus anciennes (garder seulement 2 positions)
         int toClose = posIndex - InpMaxPositionsPerSymbol;
         for(int i=0; i<toClose; i++)
         {
            ulong ticketToClose = positions[i].ticket;
            if(PositionSelectByTicket(ticketToClose))
            {
               double volume = PositionGetDouble(POSITION_VOLUME);
               long posType = PositionGetInteger(POSITION_TYPE);
               
               g_trade.SetExpertMagicNumber(InpMagicNumber);
               bool closed = false;
               
               if(posType == POSITION_TYPE_BUY)
               {
                  closed = g_trade.Sell(volume, currentSymbol);
               }
               else if(posType == POSITION_TYPE_SELL)
               {
                  closed = g_trade.Buy(volume, currentSymbol);
               }
               
               if(closed)
               {
                  if(InpDebug) Print(StringFormat("[Angel] Duplicate position closed: %s #%d (keeping only %d)", currentSymbol, ticketToClose, InpMaxPositionsPerSymbol));
               }
            }
         }
      }
   }
}


void UpdateLastTradeTime(const string symbol)
{
   // Find existing slot or create new one
   for(int i=0; i<10; i++)
   {
      if(g_lastSymbols[i] == symbol || g_lastSymbols[i] == "")
      {
         g_lastSymbols[i] = symbol;
         g_lastTradeBySymbol[i] = TimeCurrent();
         break;
      }
   }
}

bool OpenSpikeMarket(const string symbol, const int direction)
{
   // VÉRIFICATION PRÉVENTIVE RENFORCÉE
   if(!CanPlaceNewOrder(symbol, direction)) 
   {
      Print("🚫 OpenSpikeMarket BLOQUÉ: CanPlaceNewOrder a refusé ", symbol);
      return false; // Pas de signal
   }
   
   if(!CanOpenSymbolForEA(symbol)) 
   {
      Print("🚫 OpenSpikeMarket BLOQUÉ: CanOpenSymbolForEA a refusé ", symbol);
      return false; // Pas de signal
   }
   
   if(!IsDirectionAllowedBC(symbol, direction)) 
   { 
      Print("🚫 OpenSpikeMarket BLOQUÉ: Direction non autorisée pour ", symbol);
      return false; // Pas de signal 
   }
   // DÉSACTIVÉ - if(!IsTradingAllowedNow(symbol)) { if(InpDebug) Print(StringFormat("[Angel] Trading not allowed on %s", symbol)); return false; }
   // DÉSACTIVÉ - if(!SpreadOk(symbol)) { if(InpDebug) Print(StringFormat("[Angel] Spread too high on %s", symbol)); return false; }
   int win = MathMax(InpMinSecondsBetweenOrders, InpMinSecondsBetweenSameSymbol);
   if(InpMinSecondsBetweenOrders>0 && (TimeCurrent()-g_lastOrderTs)<InpMinSecondsBetweenOrders) { if(InpDebug) Print("[Angel] Global cooldown: skipping order on ", symbol); return false; }
   if(IsRecentOrder(symbol, direction, win)) { if(InpDebug) Print("[Angel] Recent order guard blocks ", symbol); return false; }
   // Calculer SL/TP pour la stratégie EMA
   double lot = InpDefaultLot;
   if(IsBoomCrashIndex(symbol)) lot = GetSafeLot(symbol, InpBCLotFixed);
   double sl = 0, tp = 0;
   if(!CalculateEMASLTP(symbol, direction, lot, sl, tp))
   {
      Print("❌ ERREUR: Impossible de calculer SL/TP pour ", symbol);
      return false; // Pas de signal
   }
   
   // Exécuter le trade au marché avec les nouveaux SL/TP
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   
  bool ok = false;
  if(!GuardAllowOpen(symbol, direction)) return false;
  if(direction == POSITION_TYPE_BUY)
   {
      ok = g_trade.Buy(lot, symbol, 0, sl, tp, "EMA_Spike_Boom");
   }
   else
   {
      ok = g_trade.Sell(lot, symbol, 0, sl, tp, "EMA_Spike_Crash");
   }
   
  if(ok){
     OnSuccessfulOpen(symbol, direction);
      g_lastOrderTs = TimeCurrent();
      UpdateLastTradeTime(symbol);
      // BC laddered pending re-entries
      if(IsBoomCrashIndex(symbol) && InpBCLadderLevels>0 && InpBCLadderStepPts>0)
      {
         double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         if(pt>0.0 && ask>0.0 && bid>0.0)
         {
            int placed=0;
            for(int lv=1; lv<=InpBCLadderLevels; lv++)
            {
               double step = InpBCLadderStepPts*pt*lv;
               double price = (direction==POSITION_TYPE_BUY)? MathMax(bid - step, 0.0) : (ask + step);
               double lot = MathMin(InpDefaultLot, InpMaxLotSize);
               // Compute SL/TP
               double sl=0,tp=0; ComputeSLTP_ByCandlesticks(symbol, direction, lot, sl, tp);
               // TTL
               datetime exp = TimeCurrent() + InpBCLadderTTLMin*60;
               g_trade.SetExpertMagicNumber(InpMagicNumber);
               g_trade.SetDeviationInPoints((uint)InpSlippagePoints);
               bool okp = false;
               if(IsDirectionAllowedBC(symbol, direction))
               {
                  // BLOQUER LES ORDRES LIMIT BC LADDER - Exécution au marché obligatoire
               Print("🚫 BC LADDER LIMIT BLOQUÉ: Exécution au marché obligatoire pour les spikes");
               okp = false; // Bloquer les ordres limit
               }
               if(okp) placed++;
            }
            if(InpDebug && placed>0) Print(StringFormat("[Angel] BC ladder: %d pending orders placed on %s", placed, symbol));
         }
      }
   }
   return ok;
}

void DetectSRForTF(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback, double &levels[], int &nOut)
{
   nOut = 0;
   MqlRates r[]; int got=(int)CopyRates(symbol, tf, 0, MathMax(lookback, 200), r); if(got<60) return;
   double highs[256]; int ih=0; double lows[256]; int il=0;
   for(int i=2;i<got-2;i++)
   {
      if(r[i].high>r[i-1].high && r[i].high>r[i-2].high && r[i].high>r[i+1].high && r[i].high>r[i+2].high){ if(ih<256) highs[ih++]=r[i].high; }
      if(r[i].low <r[i-1].low  && r[i].low <r[i-2].low  && r[i].low <r[i+1].low  && r[i].low <r[i+2].low ){ if(il<256) lows[il++]=r[i].low; }
   }
   // Merge nearby levels (0.15%)
   double tol = 0.0015; nOut = 0;
   for(int k=0;k<ih;k++){
      double p=highs[k]; bool placed=false; for(int j=0;j<nOut;j++){ if(MathAbs(levels[j]-p)/p<tol){ levels[j]=(levels[j]+p)/2.0; placed=true; break; } }
      if(!placed && nOut<50){ levels[nOut++]=p; }
   }
   for(int k2=0;k2<il;k2++){
      double p=lows[k2]; bool placed=false; for(int j=0;j<nOut;j++){ if(MathAbs(levels[j]-p)/p<tol){ levels[j]=(levels[j]+p)/2.0; placed=true; break; } }
      if(!placed && nOut<50){ levels[nOut++]=p; }
   }
}

bool IsNearAnySR(const string symbol)
{
   if(!InpEnableSR) return true; // if disabled, don't block
   double px = SymbolInfoDouble(symbol, SYMBOL_BID); if(px<=0.0) px = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(px<=0.0) return true;
   double prox = MathMax(1e-8, InpSRProximityPct);
   for(int i=0;i<g_srND1;i++){ if(MathAbs(g_srLevelsD1[i]-px)/px <= prox) return true; }
   for(int i2=0;i2<g_srNH4;i2++){ if(MathAbs(g_srLevelsH4[i2]-px)/px <= prox) return true; }
   for(int i3=0;i3<g_srNH1;i3++){ if(MathAbs(g_srLevelsH1[i3]-px)/px <= prox) return true; }
   for(int i4=0;i4<g_srNM30;i4++){ if(MathAbs(g_srLevelsM30[i4]-px)/px <= prox) return true; }
   return false; // Pas de signal
}

void DrawSRZones()
{
   if(!InpDrawSRZones || !InpEnableSR) return;
   // Clear old
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--){ string on=ObjectName(0,i); if(StringFind(on,"ANGEL_SR_")==0) ObjectDelete(0,on); }
   color cols[4] = { clrOrange, clrRed, clrDodgerBlue, clrSteelBlue };
   int ns[4] = { g_srND1, g_srNH4, g_srNH1, g_srNM30 };
   int tfIndexToArray = 0;
   string tfn[4] = { "D1","H4","H1","M30" };
   datetime t0 = TimeCurrent(); datetime t1 = t0 + 3600;
   for(int b=0;b<4;b++){
      for(int k=0;k<ns[b];k++){
         string id = StringFormat("ANGEL_SR_%s_%d", tfn[b], k);
         double lvl = 0.0;
         if(b==0){ lvl = g_srLevelsD1[k]; }
         else if(b==1){ lvl = g_srLevelsH4[k]; }
         else if(b==2){ lvl = g_srLevelsH1[k]; }
         else if(b==3){ lvl = g_srLevelsM30[k]; }
         ObjectCreate(0, id, OBJ_TREND, 0, t0, lvl, t1, lvl);
         ObjectSetInteger(0, id, OBJPROP_COLOR, cols[b]);
         ObjectSetInteger(0, id, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, id, OBJPROP_WIDTH, 1);
      }
   }
}

// Fonction de gestion stricte des positions ouvertes
void ManageOpenPositionsStrict()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == "") continue;
      
      // VÉRIFICATION CRITIQUE: Ne traiter que les positions EA (magic number)
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetSymbol(i);
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
      double lotSize = PositionGetDouble(POSITION_VOLUME);
      
      // Calculer le profit/perte en USD
      double profitUSD = 0.0;
      if(type == POSITION_TYPE_BUY)
      {
         profitUSD = (currentPrice - openPrice) * lotSize * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      }
      else
      {
         profitUSD = (openPrice - currentPrice) * lotSize * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      }
      
      // RÈGLE STRICTE: Fermeture immédiate après spike
      if(InpCloseAfterSpike)
      {
         MqlRates rates[];
         if(CopyRates(symbol, PERIOD_M1, 0, 2, rates) >= 2)
         {
            double spikeThreshold = 20.0 * SymbolInfoDouble(symbol, SYMBOL_POINT);
            double priceChange = MathAbs(rates[0].close - rates[1].close);
            
            if(priceChange >= spikeThreshold)
            {
               if(g_trade.PositionClose(ticket))
               {
                  Print("⚡ AngelOfSpike: Position fermée IMMÉDIATEMENT après spike sur ", symbol, " Changement: ", priceChange);
                  if(profitUSD > 0) g_totalWins++; else g_totalLosses++;
                  continue;
               }
            }
         }
      }
      
      // RÈGLE STRICTE: Limite de perte de 3.5$ (Boom/Crash) ou 5$ (autres)
      double maxLossUSD = GetMaxLossForSymbol(symbol);
      
      // Si perte >= limite, clôturer IMMÉDIATEMENT
      if(profitUSD <= -maxLossUSD)
      {
         if(g_trade.PositionClose(ticket))
         {
            Print("🚨 AngelOfSpike: Position fermée - LIMITE DE PERTE ATTEINTE sur ", symbol, " Loss: $", MathAbs(profitUSD), " (Max: $", maxLossUSD, ")");
            g_totalLosses++;
            continue;
         }
      }
      
      // Si profit >= 5$, clôturer la position
      if(profitUSD >= InpTargetProfitUSD)
      {
         if(g_trade.PositionClose(ticket))
         {
            Print("🎯 AngelOfSpike: Position fermée - Objectif atteint sur ", symbol, " Profit: $", profitUSD);
            g_totalWins++;
            continue;
         }
      }
      
      // Modifier les SL/TP si le prix évolue favorablement
      if(profitUSD > 0)
      {
         double newSL = 0.0, newTP = 0.0;
         if(CalculateOptimalSLTP(symbol, lotSize, currentPrice, type, newSL, newTP))
         {
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            if((MathAbs(newSL - currentSL) > SymbolInfoDouble(symbol, SYMBOL_POINT) * 5) || 
               (MathAbs(newTP - currentTP) > SymbolInfoDouble(symbol, SYMBOL_POINT) * 5))
            {
               if(g_trade.PositionModify(ticket, newSL, newTP))
               {
                  Print("🔄 AngelOfSpike: SL/TP modifiés sur ", symbol, " Nouveau SL: ", newSL, " Nouveau TP: ", newTP);
               }
            }
         }
      }
   }
}


// Fonction pour afficher les trades manuels dans le HUD
void DrawManualTradesHUD()
{
   if(!InpAllowManualTrading) return;
   
   int x = InpHUDColumn2X + 20;
   int y = 200; // Position plus bas
   int dy = 15;
   
   // Titre
   DrawText("MANUAL_TITLE", "MANUAL TRADES", x, y, clrCyan); y += dy;
   
   int manualCount = 0;
   int eaCount = 0;
   
   // Compter les positions manuelles et EA
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         eaCount++;
      }
      else
      {
         manualCount++;
         if(manualCount <= 3) // Afficher max 3 trades manuels
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            long type = PositionGetInteger(POSITION_TYPE);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            color profitColor = (profit >= 0) ? clrLime : clrRed;
            string typeText = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            
            DrawText("MANUAL_" + IntegerToString(manualCount), 
               StringFormat("%s %s %.2f $%.2f", symbol, typeText, volume, profit), 
               x, y, profitColor); 
            y += dy;
         }
      }
   }
   
   // Résumé
   DrawText("MANUAL_SUMMARY", StringFormat("EA: %d | Manual: %d", eaCount, manualCount), x, y, clrWhite); y += dy;
   
   // Avertissement si trop de positions
   int totalPositions = eaCount + manualCount;
   if(totalPositions > 2)
   {
      DrawText("MANUAL_WARNING", "⚠️ MAX 2 POSITIONS", x, y, clrOrange);
   }
}

// Fonction pour détecter les retournements aux niveaux ICT FIBO (S/R)
bool DetectICTFiboReversal(const string symbol, int &outDirection)
{
   if(!InpEnableSR) return false;
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double proximity = InpSRProximityPct; // 0.08% par défaut
   
   // Vérifier les niveaux de résistance (pour SELL)
   for(int i = 0; i < g_srND1; i++)
   {
      if(MathAbs(g_srLevelsD1[i] - currentPrice) / currentPrice <= proximity)
      {
         // Prix près d'une résistance D1 - Attendre un retournement baissier
         if(IsReversalPattern(symbol, POSITION_TYPE_SELL))
         {
            outDirection = POSITION_TYPE_SELL;
            DrawICTFiboArrows(symbol, POSITION_TYPE_SELL, g_srLevelsD1[i]);
            if(InpDebug) Print(StringFormat("[Angel] ICT FIBO REVERSAL D1: Résistance touchée à %.5f - Signal SELL", g_srLevelsD1[i]));
            return true;
         }
      }
   }
   
   for(int i = 0; i < g_srNH4; i++)
   {
      if(MathAbs(g_srLevelsH4[i] - currentPrice) / currentPrice <= proximity)
      {
         if(IsReversalPattern(symbol, POSITION_TYPE_SELL))
         {
            outDirection = POSITION_TYPE_SELL;
            DrawICTFiboArrows(symbol, POSITION_TYPE_SELL, g_srLevelsH4[i]);
            if(InpDebug) Print(StringFormat("[Angel] ICT FIBO REVERSAL H4: Résistance touchée à %.5f - Signal SELL", g_srLevelsH4[i]));
            return true;
         }
      }
   }
   
   for(int i = 0; i < g_srNH1; i++)
   {
      if(MathAbs(g_srLevelsH1[i] - currentPrice) / currentPrice <= proximity)
      {
         if(IsReversalPattern(symbol, POSITION_TYPE_SELL))
         {
            outDirection = POSITION_TYPE_SELL;
            DrawICTFiboArrows(symbol, POSITION_TYPE_SELL, g_srLevelsH1[i]);
            if(InpDebug) Print(StringFormat("[Angel] ICT FIBO REVERSAL H1: Résistance touchée à %.5f - Signal SELL", g_srLevelsH1[i]));
            return true;
         }
      }
   }
   
   // Vérifier les niveaux de support (pour BUY)
   for(int i = 0; i < g_srND1; i++)
   {
      if(MathAbs(g_srLevelsD1[i] - currentPrice) / currentPrice <= proximity)
      {
         if(IsReversalPattern(symbol, POSITION_TYPE_BUY))
         {
            outDirection = POSITION_TYPE_BUY;
            DrawICTFiboArrows(symbol, POSITION_TYPE_BUY, g_srLevelsD1[i]);
            if(InpDebug) Print(StringFormat("[Angel] ICT FIBO REVERSAL D1: Support touché à %.5f - Signal BUY", g_srLevelsD1[i]));
            return true;
         }
      }
   }
   
   for(int i = 0; i < g_srNH4; i++)
   {
      if(MathAbs(g_srLevelsH4[i] - currentPrice) / currentPrice <= proximity)
      {
         if(IsReversalPattern(symbol, POSITION_TYPE_BUY))
         {
            outDirection = POSITION_TYPE_BUY;
            DrawICTFiboArrows(symbol, POSITION_TYPE_BUY, g_srLevelsH4[i]);
            if(InpDebug) Print(StringFormat("[Angel] ICT FIBO REVERSAL H4: Support touché à %.5f - Signal BUY", g_srLevelsH4[i]));
            return true;
         }
      }
   }
   
   for(int i = 0; i < g_srNH1; i++)
   {
      if(MathAbs(g_srLevelsH1[i] - currentPrice) / currentPrice <= proximity)
      {
         if(IsReversalPattern(symbol, POSITION_TYPE_BUY))
         {
            outDirection = POSITION_TYPE_BUY;
            DrawICTFiboArrows(symbol, POSITION_TYPE_BUY, g_srLevelsH1[i]);
            if(InpDebug) Print(StringFormat("[Angel] ICT FIBO REVERSAL H1: Support touché à %.5f - Signal BUY", g_srLevelsH1[i]));
            return true;
         }
      }
   }
   
   return false; // Pas de signal
}

// Fonction pour détecter un pattern de retournement
bool IsReversalPattern(const string symbol, const int direction)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) return false;
   
   // Pattern de retournement : 3 barres consécutives avec confirmation
   if(direction == POSITION_TYPE_SELL)
   {
      // Pour SELL : Chercher un pattern de retournement baissier
      // Barre 1: Haussière forte, Barre 2: Doji ou petite, Barre 3: Baissière forte
      double body1 = MathAbs(rates[2].close - rates[2].open);
      double body2 = MathAbs(rates[1].close - rates[1].open);
      double body3 = MathAbs(rates[0].close - rates[0].open);
      double range2 = rates[1].high - rates[1].low;
      
      // Pattern de retournement baissier
      if(rates[2].close > rates[2].open && // Barre haussière
         body2 < body1 * 0.5 && // Barre 2 plus petite que barre 1
         rates[0].close < rates[0].open && // Barre baissière
         body3 > body2 * 1.5) // Barre 3 plus forte que barre 2
      {
         // Vérifier que le prix a touché la résistance et commence à chuter
         if(rates[1].high >= rates[2].high && rates[0].close < rates[1].close)
         {
            return true;
         }
      }
   }
   else if(direction == POSITION_TYPE_BUY)
   {
      // Pour BUY : Chercher un pattern de retournement haussier
      // Barre 1: Baissière forte, Barre 2: Doji ou petite, Barre 3: Haussière forte
      double body1 = MathAbs(rates[2].close - rates[2].open);
      double body2 = MathAbs(rates[1].close - rates[1].open);
      double body3 = MathAbs(rates[0].close - rates[0].open);
      
      // Pattern de retournement haussier
      if(rates[2].close < rates[2].open && // Barre baissière
         body2 < body1 * 0.5 && // Barre 2 plus petite que barre 1
         rates[0].close > rates[0].open && // Barre haussière
         body3 > body2 * 1.5) // Barre 3 plus forte que barre 2
      {
         // Vérifier que le prix a touché le support et commence à rebondir
         if(rates[1].low <= rates[2].low && rates[0].close > rates[1].close)
         {
            return true;
         }
      }
   }
   
   return false; // Pas de signal
}

// Fonction pour dessiner les flèches de retournement ICT FIBO
void DrawICTFiboArrows(const string symbol, const int direction, const double price)
{
   if(!InpShowSpikeArrows) return;
   
   string arrowName = "ICT_FIBO_" + symbol + "_" + IntegerToString(TimeCurrent());
   datetime time = TimeCurrent();
   
   if(direction == POSITION_TYPE_SELL)
   {
      // Flèche rouge vers le bas pour SELL (résistance touchée)
      if(ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, time, price))
      {
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
         ObjectSetString(0, arrowName, OBJPROP_TEXT, "ICT FIBO SELL");
      }
   }
   else if(direction == POSITION_TYPE_BUY)
   {
      // Flèche verte vers le haut pour BUY (support touché)
      if(ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, time, price))
      {
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
         ObjectSetString(0, arrowName, OBJPROP_TEXT, "ICT FIBO BUY");
      }
   }
}

// Fonction pour vérifier si on peut placer un nouvel ordre (blocage préventif ULTRA-STRICT)
bool CanPlaceNewOrder(const string symbol, const int direction)
{
   // 1. VÉRIFICATION MODIFIÉE: Ignorer les positions manuelles
   int totalPositionsAll = PositionsTotal();
   if(totalPositionsAll > 0 && InpMaxGlobalPositions > 0)
   {
      // Compter uniquement les positions de l'EA
      int eaPositions = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            eaPositions++;
      }
      
      if(eaPositions >= InpMaxGlobalPositions)
      {
         Print("🚫 BLOCAGE: Maximum de positions EA atteint (", eaPositions, "/", InpMaxGlobalPositions, ") - Positions totales: ", totalPositionsAll);
         return false; // Pas de signal
      }
   }
   
   // 2. VÉRIFICATION des positions EA
   int totalPositionsEA = CountOpenPositionsEA();
   if(totalPositionsEA > 0 && InpMaxGlobalPositions > 0 && totalPositionsEA >= InpMaxGlobalPositions)
   {
      Print("ℹ️ Positions EA: ", totalPositionsEA, "/", InpMaxGlobalPositions, " (limite atteinte)");
      return false; // Pas de signal
   }
   
   // 3. VÉRIFICATION MODIFIÉE: Ignorer les ordres manuels
   int totalOrders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         totalOrders++;
   }
   
   if(totalOrders > 0)
   {
      Print("ℹ️ Ordres en attente de l'EA: ", totalOrders, " (sur ", OrdersTotal(), " au total)");
      return false; // Pas de signal
   }
   
   // 4. VÉRIFICATION du cooldown (plus souple pour Boom/Crash)
   static datetime lastOrderTime = 0;
   int cooldown = 60;
   bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
   
   if(isBoomCrash)
      cooldown = MathMax(1, InpCooldownSecondsBC); // Cooldown minimal de 1 seconde pour Boom/Crash
      
   if(lastOrderTime > 0 && (TimeCurrent() - lastOrderTime) < cooldown)
   {
      Print("⏳ Cooldown: ", (cooldown - (TimeCurrent() - lastOrderTime)), "s restantes (Boom/Crash: ", isBoomCrash ? "OUI" : "NON", ")");
      return false; // Pas de signal
   }
   
   // 5. VÉRIFICATION STRICTE: Limite par symbole (1 seule position par symbole)
   int symbolPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol) symbolPositions++;
   }
   
   if(symbolPositions >= InpMaxPositionsPerSymbol)
   {
      Print("🚫 BLOCAGE SYMBOLE: Maximum de positions atteint sur ", symbol, " (", symbolPositions, "/", InpMaxPositionsPerSymbol, ")");
      return false; // Pas de signal
   }
   
   // 6. VÉRIFICATION D'URGENCE: Détecter et fermer les positions multiples
   EmergencyCloseMultiplePositions(symbol);
   
   // 7. Vérifier les conflits BUY/SELL sur le même symbole
   bool hasBuyOrders = false, hasSellOrders = false;
   
   // Vérifier les ordres en attente
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT)
         hasBuyOrders = true;
      else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT)
         hasSellOrders = true;
   }
   
   // Vérifier les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)
         hasBuyOrders = true;
      else if(posType == POSITION_TYPE_SELL)
         hasSellOrders = true;
   }
   
   // Bloquer si conflit BUY/SELL
   if(hasBuyOrders && hasSellOrders)
   {
      Print("🚫 BLOCAGE CONFLIT: BUY et SELL simultanés détectés sur ", symbol);
      return false; // Pas de signal
   }
   
   // Bloquer si on essaie de placer le même type d'ordre
   if((direction == POSITION_TYPE_BUY && hasBuyOrders) || (direction == POSITION_TYPE_SELL && hasSellOrders))
   {
      Print("🚫 BLOCAGE DIRECTION: Ordre ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " déjà existant sur ", symbol);
      return false; // Pas de signal
   }
   
   // Mettre à jour le timestamp du dernier ordre
   lastOrderTime = TimeCurrent();
   
   Print("✅ AUTORISATION: Nouvel ordre ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " autorisé sur ", symbol);
   return true;
}

// ===================================================================
// EXÉCUTION UNIQUE AU MARCHÉ - SPIKE M1
// Fonction principale pour exécuter UN SEUL ordre basé sur probabilité M1
// ===================================================================
bool ExecuteSingleMarketOrder(string symbol, int direction, double probability)
{
   // 1. TRIPLE VÉRIFICATION (aucune position)
   if(!CanPlaceNewOrder(symbol, direction))
   {
      Print("🚫 ExecuteSingleMarketOrder BLOQUÉ: CanPlaceNewOrder a refusé ", symbol);
      return false; // Pas de signal
   }
   
   // 2. Vérifier que le trading est activé
   if(!InpEnableTrading)
   {
      Print("🚫 ExecuteSingleMarketOrder BLOQUÉ: Trading désactivé");
      return false; // Pas de signal
   }
   
   // 3. Calculer le lot basé sur risque strict (override BC à 0.20)
   double lot = CalculateLotSize(symbol, InpCapitalPerTradeUSD);
   bool isBC_exec = (StringFind(symbol, "Boom")>=0 || StringFind(symbol, "Crash")>=0);
   if(isBC_exec) lot = GetSafeLot(symbol, InpBCLotFixed);
   if(lot <= 0.0)
   {
      Print("🚫 ExecuteSingleMarketOrder BLOQUÉ: Lot invalide (", lot, ")");
      return false; // Pas de signal
   }
   
   // 4. Obtenir les prix actuels
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   if(ask <= 0.0 || bid <= 0.0 || pt <= 0.0)
   {
      Print("🚫 ExecuteSingleMarketOrder BLOQUÉ: Prix invalides - Ask:", ask, " Bid:", bid, " Point:", pt);
      return false; // Pas de signal
   }
   
   // 5. Calculer SL/TP automatiques stricts mais intelligents
   double sl = 0.0, tp = 0.0;
   ComputeSLTP_ByCandlesticks(symbol, direction, lot, sl, tp);

   // Volatility indices: forcer $2/$2 si détecté par hint et non Boom/Crash
   bool isBC = (StringFind(symbol, "Boom")>=0 || StringFind(symbol, "Crash")>=0);
   bool isVol = (!isBC && InpEnableVolScalp && StringFind(symbol, InpVolSymbolsHint) >= 0);
   if(isVol)
   {
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double pt        = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tickValue>0.0 && tickSize>0.0 && pt>0.0)
      {
         double usdPerPointPerLot = tickValue * (pt / tickSize);
         double slPts = InpVolSL_USD / (usdPerPointPerLot * MathMax(lot,1e-9));
         double tpPts = InpVolTP_USD / (usdPerPointPerLot * MathMax(lot,1e-9));
         double entry = (direction==POSITION_TYPE_BUY)? ask : bid;
         if(direction==POSITION_TYPE_BUY){ sl = NormalizeDouble(entry - slPts*pt, digits); tp = NormalizeDouble(entry + tpPts*pt, digits);} 
         else                            { sl = NormalizeDouble(entry + slPts*pt, digits); tp = NormalizeDouble(entry - tpPts*pt, digits);} 
      }
   }
   
   // Fallback si SL/TP non calculés - Utiliser des niveaux plus larges pour l'autonomie
   if(sl <= 0.0 || tp <= 0.0)
   {
      double pctSL = MathMax(0.002, InpSLPercent / 100.0); // 0.2% minimum pour plus d'autonomie
      double pctTP = MathMax(0.003, InpTPPercent / 100.0); // 0.3% minimum pour plus d'autonomie
      double entryPrice = (direction == POSITION_TYPE_BUY) ? ask : bid;
      
      if(direction == POSITION_TYPE_BUY)
      {
         sl = NormalizeDouble(entryPrice * (1.0 - pctSL), digits);
         tp = NormalizeDouble(entryPrice * (1.0 + pctTP), digits);
      }
      else
      {
         sl = NormalizeDouble(entryPrice * (1.0 + pctSL), digits);
         tp = NormalizeDouble(entryPrice * (1.0 - pctTP), digits);
      }
   }
   
   // 6. Configurer l'ordre
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   
   // 7. Exécuter l'ordre MARKET uniquement
   bool success = false;
   double entryPrice = (direction == POSITION_TYPE_BUY) ? ask : bid;
   
   if(!GuardAllowOpen(symbol, direction)) return false;
   if(direction == POSITION_TYPE_BUY)
   {
      success = g_trade.Buy(lot, symbol, NormalizeDouble(entryPrice, digits), 
                           NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), 
                           "SpikeM1-" + DoubleToString(probability, 1) + "%");
   }
   else
   {
      success = g_trade.Sell(lot, symbol, NormalizeDouble(entryPrice, digits), 
                            NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), 
                            "SpikeM1-" + DoubleToString(probability, 1) + "%");
   }
   if(success) OnSuccessfulOpen(symbol, direction);
   // 8. Logging détaillé avec probabilité
   if(success)
   {
      // Vérifier si c'est un symbole Boom/Crash
      bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
      
      if(isBoomCrash)
      {
         Print("💥 BOOM/CRASH SPIKE M1 DÉTECTÉ ET EXÉCUTÉ");
         Print("   Symbole: ", symbol);
         Print("   Probabilité: ", DoubleToString(probability, 1), "%");
         Print("   Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
         Print("   Prix d'entrée: ", DoubleToString(entryPrice, digits));
         Print("   Lot: ", DoubleToString(lot, 2));
         Print("   SL: ", DoubleToString(sl, digits), " (autonome)");
         Print("   TP: ", DoubleToString(tp, digits), " (autonome)");
         Print("   Timeframe: M1");
         Print("   Positions ouvertes: ", CountOpenPositionsEA(), "/", InpMaxGlobalPositions);
         Print("   🔄 SPIKE SCALPING: Fermeture automatique sur spike + re-entry");
      }
      else
      {
         Print("🎯 SPIKE M1 DÉTECTÉ ET EXÉCUTÉ - ROBOT AUTONOME");
         Print("   Symbole: ", symbol);
         Print("   Probabilité: ", DoubleToString(probability, 1), "%");
         Print("   Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
         Print("   Prix d'entrée: ", DoubleToString(entryPrice, digits));
         Print("   Lot: ", DoubleToString(lot, 2));
         Print("   SL: ", DoubleToString(sl, digits), " (autonome)");
         Print("   TP: ", DoubleToString(tp, digits), " (autonome)");
         Print("   Timeframe: M1");
         Print("   Positions ouvertes: ", CountOpenPositionsEA(), "/", InpMaxGlobalPositions);
         Print("   🤖 ROBOT AUTONOME: Position gardée jusqu'à SL/TP");
      }
      
      // Notification si activée
      if(InpSendNotifications)
      {
         string message = StringFormat("🎯 SPIKE M1 EXÉCUTÉ\n%s %s\nProbabilité: %.1f%%\nPrix: %.5f", 
                                     symbol, (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                                     probability, entryPrice);
         SendNotification(message);
      }
      
      return true;
   }
   else
   {
      Print("❌ ÉCHEC EXÉCUTION SPIKE M1 sur ", symbol, " - Erreur: ", g_trade.ResultRetcode());
      return false; // Pas de signal
   }
}

// Nouvelle fonction pour placement intelligent des ordres
bool PlaceSmartOrder(const string symbol, const int direction, const double confidence)
{
   if(!InpSmartOrderPlacement) return false;
   if(!CanOpenSymbolForEA(symbol)) return false;
   if(!IsDirectionAllowedBC(symbol, direction)) { if(InpDebug) Print("[Angel] Smart order blocked by BC direction on ", symbol); return false; }
   
   // VÉRIFICATION PRÉVENTIVE - Bloquer avant de créer l'ordre
   if(!CanPlaceNewOrder(symbol, direction)) return false;
   
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT); 
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK); 
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(pt<=0.0 || ask<=0.0 || bid<=0.0) return false;
   
   // RÈGLE STRICTE: Calculer le lot basé sur le capital (BC forcé 0.20)
   double lot = CalculateLotSize(symbol, InpCapitalPerTradeUSD);
   if(IsBoomCrashIndex(symbol)) lot = GetSafeLot(symbol, InpBCLotFixed);
   
   // Placement intelligent basé sur la confiance
   double entryPrice = 0.0;
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   
   if(confidence >= 90.0)
   {
      // Haute confiance: ordre au marché immédiat
      if(direction == POSITION_TYPE_BUY)
      {
         entryPrice = ask;
         orderType = ORDER_TYPE_BUY;
      }
      else
      {
         entryPrice = bid;
         orderType = ORDER_TYPE_SELL;
      }
   }
   else if(confidence >= 85.0) // Seuil de confiance minimum
   {
      // Confiance moyenne: ordre LIMIT
      if(direction == POSITION_TYPE_BUY)
      {
         entryPrice = bid - 3*pt; // 3 points sous le bid
         orderType = ORDER_TYPE_BUY_LIMIT;
      }
      else
      {
         entryPrice = ask + 3*pt; // 3 points au-dessus de l'ask
         orderType = ORDER_TYPE_SELL_LIMIT;
      }
   }
   else
   {
      // Confiance faible: ordre LIMIT plus éloigné (pas de STOP)
      if(direction == POSITION_TYPE_BUY)
      {
         entryPrice = bid - 8*pt; // 8 points sous le bid
         orderType = ORDER_TYPE_BUY_LIMIT;
      }
      else
      {
         entryPrice = ask + 8*pt; // 8 points au-dessus de l'ask
         orderType = ORDER_TYPE_SELL_LIMIT;
      }
   }
   
   // NOUVELLE LOGIQUE: Calculer les SL/TP optimaux basés sur le spread et lot minimal
   double sl=0, tp=0; 
   
   // Essayer d'abord les calculs optimaux
   if(CalculateOptimalSLTP(symbol, lot, entryPrice, direction, sl, tp))
   {
      Print("🎯 AngelOfSpike: Smart Order SL/TP optimaux calculés - SL: ", sl, " TP: ", tp);
   }
   else
   {
      // Fallback sur la méthode existante
      ComputeSLTP_ByCandlesticks(symbol, direction, lot, sl, tp);
      
      if(sl<=0 || tp<=0)
      {
         double pctSL=MathMax(0.001, InpSLPercent/100.0); 
         double pctTP=MathMax(0.001, InpTPPercent/100.0);
         if(direction==POSITION_TYPE_BUY)
         { 
            sl=NormalizeDouble(entryPrice*(1.0-pctSL),digits); 
            tp=NormalizeDouble(entryPrice*(1.0+pctTP),digits);
         } 
         else 
         { 
            sl=NormalizeDouble(entryPrice*(1.0+pctSL),digits); 
            tp=NormalizeDouble(entryPrice*(1.0-pctTP),digits);
         }
      }
      Print("⚠️ AngelOfSpike: Smart Order SL/TP par défaut - SL: ", sl, " TP: ", tp);
   }
   
   // Placer l'ordre
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   
   bool ok = false;
  if(orderType == ORDER_TYPE_BUY && !GuardAllowOpen(symbol, POSITION_TYPE_BUY)) return false;
  if(orderType == ORDER_TYPE_SELL && !GuardAllowOpen(symbol, POSITION_TYPE_SELL)) return false;
  if(orderType == ORDER_TYPE_BUY)
      ok = g_trade.Buy(lot, symbol, NormalizeDouble(entryPrice, digits), sl, tp, "SmartMarket");
   else if(orderType == ORDER_TYPE_SELL)
      ok = g_trade.Sell(lot, symbol, NormalizeDouble(entryPrice, digits), sl, tp, "SmartMarket");
   else if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      Print("🚫 ORDRE LIMIT BLOQUÉ: Exécution au marché obligatoire pour les spikes");
      return false; // Pas de signal // Bloquer les ordres limit
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      Print("🚫 ORDRE LIMIT BLOQUÉ: Exécution au marché obligatoire pour les spikes");
      return false; // Pas de signal // Bloquer les ordres limit
   }
   
   if(ok) 
   {
      g_lastOrderTs = TimeCurrent();
      if(InpDebug) Print(StringFormat("[Angel] Smart order placed: %s %s %.2f lots at %.5f, SL=%.5f, TP=%.5f (Confidence: %.1f%%)", 
         symbol, EnumToString(orderType), lot, entryPrice, sl, tp, confidence));
   }
   
   return ok;
}

bool PlaceCautiousLimit(const string symbol, const int direction)
{
   if(!InpAllowLimitOrders) return false;
   if(!CanOpenSymbolForEA(symbol)) return false;
   if(!IsDirectionAllowedBC(symbol, direction)) { if(InpDebug) Print("[Angel] Limit blocked by BC direction on ", symbol); return false; }
   
   // VÉRIFICATION PRÉVENTIVE - Bloquer avant de créer l'ordre
   if(!CanPlaceNewOrder(symbol, direction)) return false;
   // DÉSACTIVÉ - if(!IsTradingAllowedNow(symbol)) { if(InpDebug) Print(StringFormat("[Angel] Trading not allowed (limit) on %s", symbol)); return false; }
   // DÉSACTIVÉ - if(!SpreadOk(symbol)) { if(InpDebug) Print(StringFormat("[Angel] Spread too high (limit) on %s", symbol)); return false; }
   if(InpMinSecondsBetweenOrders>0 && (TimeCurrent()-g_lastOrderTs)<InpMinSecondsBetweenOrders) { if(InpDebug) Print("[Angel] Cooldown: skipping limit on ", symbol); return false; }
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT); int digits=(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK); double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(pt<=0.0 || ask<=0.0 || bid<=0.0) return false;
   
   // RÈGLE STRICTE: Calculer le lot basé sur le capital
   double lot = CalculateLotSize(symbol, InpCapitalPerTradeUSD); 
   
   // FORCER SL/TP - Toujours calculer des SL/TP valides
   double sl=0, tp=0; 
   ComputeSLTP_ByCandlesticks(symbol, direction, lot, sl, tp);
   
   // Si SL/TP ne sont pas calculés, utiliser le fallback en pourcentage
   if(sl<=0 || tp<=0)
   {
      double pctSL=MathMax(0.001, InpSLPercent/100.0); 
      double pctTP=MathMax(0.001, InpTPPercent/100.0);
      double currentPrice = (direction==POSITION_TYPE_BUY)? bid : ask;
      if(direction==POSITION_TYPE_BUY)
      { 
         sl=NormalizeDouble(currentPrice*(1.0-pctSL),digits); 
         tp=NormalizeDouble(currentPrice*(1.0+pctTP),digits);
      } 
      else 
      { 
         sl=NormalizeDouble(currentPrice*(1.0+pctSL),digits); 
         tp=NormalizeDouble(currentPrice*(1.0-pctTP),digits);
      }
   }
   
   // Vérifier que SL/TP sont valides
   if(sl<=0 || tp<=0)
   {
      if(InpDebug) Print(StringFormat("[Angel] Invalid SL/TP for limit on %s: SL=%.5f, TP=%.5f", symbol, sl, tp));
      return false; // Pas de signal
   }
   
   // BLOQUER LES ORDRES LIMIT - Exécution au marché obligatoire
   Print("🚫 FONCTION ANGEL LIMIT BLOQUÉE: Exécution au marché obligatoire pour les spikes");
   return false; // Pas de signal
   
   // CODE DÉSACTIVÉ - Ordres limit interdits
   /*
   double price;
   if(direction==POSITION_TYPE_BUY)  price = NormalizeDouble(MathMax(bid - 5*pt, 0), digits); else price = NormalizeDouble(ask + 5*pt, digits);
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   
   bool ok = (direction==POSITION_TYPE_BUY) ? g_trade.BuyLimit(lot, symbol, price, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), ORDER_TIME_GTC, (datetime)0, "AngelLimit")
                                            : g_trade.SellLimit(lot, symbol, price, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), ORDER_TIME_GTC, (datetime)0, "AngelLimit");
   
   if(ok) 
   {
      g_lastOrderTs = TimeCurrent();
      if(InpDebug) Print(StringFormat("[Angel] Limit order placed: %s %s %.2f lots at %.5f, SL=%.5f, TP=%.5f (MaxLot: %.2f)", 
         symbol, (direction==POSITION_TYPE_BUY?"BUY":"SELL"), lot, price, sl, tp, InpMaxLotSize));
   }
   return ok;
   */
}


// ===================================================================
// SCALPING AUTOMATIQUE - FONCTIONS
// ===================================================================

// Fonction pour obtenir la direction de tendance depuis l'API
string GetTrendDirection(const string symbol)
{
   if(!InpScalpUseTrendAPI) return "neutral";
   
   // Créer l'URL de l'API
   string url = InpTrendAPIUrl + "?symbol=" + symbol + "&timeframe=M1";
   
   // Note: MQL5 ne supporte pas directement les requêtes HTTP
   // Cette fonction simule l'appel API en utilisant des données locales
   // En production, il faudrait utiliser WebRequest() ou un autre mécanisme
   
   // Simulation basée sur l'heure actuelle pour la démonstration
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   int hour = dt.hour;
   
   // Simulation de tendance basée sur l'heure
   if(hour % 3 == 0) return "bullish";
   else if(hour % 3 == 1) return "bearish";
   else return "neutral";
}

// Fonction pour obtenir les données complètes de l'API
bool GetTrendDataFromAPI(const string symbol, string &trendDirection, double &trendStrength, string &confidence, double &spikeProbability)
{
   if(!InpScalpUseTrendAPI) 
   {
      trendDirection = "neutral";
      trendStrength = 50.0;
      confidence = "medium";
      spikeProbability = 0.5;
      return false; // Pas de signal
   }
   
   // Simulation des données API pour la démonstration
   // En production, utiliser WebRequest() pour appeler l'API réelle
   
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   int hour = dt.hour;
   int minute = dt.min;
   
   // Simulation basée sur l'heure et la minute
   if(hour % 3 == 0) 
   {
      trendDirection = "bullish";
      trendStrength = 75.0 + (minute % 20);
      confidence = "high";
      spikeProbability = 0.8;
   }
   else if(hour % 3 == 1) 
   {
      trendDirection = "bearish";
      trendStrength = 70.0 + (minute % 25);
      confidence = "high";
      spikeProbability = 0.75;
   }
   else 
   {
      trendDirection = "neutral";
      trendStrength = 50.0 + (minute % 10);
      confidence = "medium";
      spikeProbability = 0.4;
   }
   
   return true;
}

// Fonction pour afficher les données de l'API sur le graphique
void DisplayTrendDataOnChart(const string symbol)
{
   if(!InpShowHUD) return;
   
   string trendDirection, confidence;
   double trendStrength, spikeProbability;
   
   if(!GetTrendDataFromAPI(symbol, trendDirection, trendStrength, confidence, spikeProbability))
      return;
   
   // Position des données sur le graphique
   int x = InpHUDX + 400;  // Colonne 3
   int y = InpHUDY + 100;
   int spacing = InpHUDLineSpacing;
   
   // Couleur selon la direction
   color trendColor = clrWhite;
   if(trendDirection == "bullish") trendColor = clrLime;
   else if(trendDirection == "bearish") trendColor = clrRed;
   else trendColor = clrYellow;
   
   // Titre API
   string titleId = "API_TITLE";
   if(ObjectFind(0, titleId) >= 0) ObjectDelete(0, titleId);
   if(ObjectCreate(0, titleId, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, titleId, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, titleId, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, titleId, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, titleId, OBJPROP_TEXT, "=== API TREND DATA ===");
      ObjectSetInteger(0, titleId, OBJPROP_COLOR, InpHUDAccent);
      ObjectSetInteger(0, titleId, OBJPROP_FONTSIZE, 10);
   }
   
   // Direction de tendance
   string dirId = "API_DIRECTION";
   if(ObjectFind(0, dirId) >= 0) ObjectDelete(0, dirId);
   if(ObjectCreate(0, dirId, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, dirId, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, dirId, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, dirId, OBJPROP_YDISTANCE, y + spacing);
      ObjectSetString(0, dirId, OBJPROP_TEXT, "Direction: " + trendDirection);
      ObjectSetInteger(0, dirId, OBJPROP_COLOR, trendColor);
      ObjectSetInteger(0, dirId, OBJPROP_FONTSIZE, 9);
   }
   
   // Force de tendance
   string strengthId = "API_STRENGTH";
   if(ObjectFind(0, strengthId) >= 0) ObjectDelete(0, strengthId);
   if(ObjectCreate(0, strengthId, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, strengthId, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, strengthId, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, strengthId, OBJPROP_YDISTANCE, y + spacing * 2);
      ObjectSetString(0, strengthId, OBJPROP_TEXT, "Force: " + DoubleToString(trendStrength, 1) + "%");
      ObjectSetInteger(0, strengthId, OBJPROP_COLOR, InpHUDColor);
      ObjectSetInteger(0, strengthId, OBJPROP_FONTSIZE, 9);
   }
   
   // Confiance
   string confId = "API_CONFIDENCE";
   if(ObjectFind(0, confId) >= 0) ObjectDelete(0, confId);
   if(ObjectCreate(0, confId, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, confId, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, confId, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, confId, OBJPROP_YDISTANCE, y + spacing * 3);
      ObjectSetString(0, confId, OBJPROP_TEXT, "Confiance: " + confidence);
      ObjectSetInteger(0, confId, OBJPROP_COLOR, InpHUDColor);
      ObjectSetInteger(0, confId, OBJPROP_FONTSIZE, 9);
   }
   
   // Probabilité de spike
   string spikeId = "API_SPIKE";
   if(ObjectFind(0, spikeId) >= 0) ObjectDelete(0, spikeId);
   if(ObjectCreate(0, spikeId, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, spikeId, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, spikeId, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, spikeId, OBJPROP_YDISTANCE, y + spacing * 4);
      ObjectSetString(0, spikeId, OBJPROP_TEXT, "Spike Prob: " + DoubleToString(spikeProbability * 100, 1) + "%");
      ObjectSetInteger(0, spikeId, OBJPROP_COLOR, InpHUDColor);
      ObjectSetInteger(0, spikeId, OBJPROP_FONTSIZE, 9);
   }
   
   // Signal de trading
   string signalId = "API_SIGNAL";
   if(ObjectFind(0, signalId) >= 0) ObjectDelete(0, signalId);
   if(ObjectCreate(0, signalId, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, signalId, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, signalId, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, signalId, OBJPROP_YDISTANCE, y + spacing * 5);
      
      string signalText = "Signal: ";
      color signalColor = clrWhite;
      
      if(trendDirection == "bullish" && spikeProbability > 0.7)
      {
         signalText += "BUY STRONG";
         signalColor = clrLime;
      }
      else if(trendDirection == "bearish" && spikeProbability > 0.7)
      {
         signalText += "SELL STRONG";
         signalColor = clrRed;
      }
      else if(trendDirection == "bullish")
      {
         signalText += "BUY WEAK";
         signalColor = clrYellow;
      }
      else if(trendDirection == "bearish")
      {
         signalText += "SELL WEAK";
         signalColor = clrOrange;
      }
      else
      {
         signalText += "WAIT";
         signalColor = clrGray;
      }
      
      ObjectSetString(0, signalId, OBJPROP_TEXT, signalText);
      ObjectSetInteger(0, signalId, OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, signalId, OBJPROP_FONTSIZE, 9);
   }
   
   // Timestamp de mise à jour
   string timeId = "API_TIME";
   if(ObjectFind(0, timeId) >= 0) ObjectDelete(0, timeId);
   if(ObjectCreate(0, timeId, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, timeId, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, timeId, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, timeId, OBJPROP_YDISTANCE, y + spacing * 6);
      ObjectSetString(0, timeId, OBJPROP_TEXT, "Update: " + TimeToString(TimeCurrent(), TIME_MINUTES));
      ObjectSetInteger(0, timeId, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, timeId, OBJPROP_FONTSIZE, 8);
   }
}

// Fonction pour vérifier si le scalping est autorisé sur un symbole
bool IsScalpingAllowed(const string symbol)
{
   if(!InpEnableAutoScalping) return false;
   if(!IsBoomCrashIndex(symbol)) return false;
   
   // Vérifier le cooldown entre scalps
   datetime now = TimeCurrent();
   for(int i = 0; i < 10; i++)
   {
      if(g_lastTradeBySymbol[i] > 0 && (now - g_lastTradeBySymbol[i]) < InpScalpMinIntervalSec)
      {
         if(StringFind(symbol, g_lastSymbols[i]) >= 0) return false;
      }
   }
   
   // Vérifier qu'il n'y a pas déjà une position sur ce symbole
   int i;
    for(i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == symbol) return false;
   }
   
   return true;
}

// Fonction pour calculer le lot optimal pour le scalping
double CalculateScalpingLotSize(const string symbol)
{
   double maxLossUSD = InpScalpMaxLossUSD;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0) 
   {
      return InpDefaultLot; // Fallback
   }
   
   // Calculer le lot pour la perte maximale autorisée
   double usdPerPointPerLot = tickValue * (point / tickSize);
   if(usdPerPointPerLot <= 0.0) return InpDefaultLot;
   
   // Utiliser une distance SL de 20 points pour le calcul
   double slDistancePoints = 20.0;
   double lot = maxLossUSD / (usdPerPointPerLot * slDistancePoints);
   
   return GetSafeLot(symbol, MathMax(0.01, MathMin(lot, InpMaxLotSize)));
}

// Fonction pour calculer SL/TP optimaux pour le scalping
bool CalculateScalpingSLTP(const string symbol, const int direction, const double entryPrice, const double lotSize, double &sl, double &tp)
{
   double maxLossUSD = InpScalpMaxLossUSD;
   double targetProfitUSD = InpScalpTargetProfitUSD;
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0) 
   {
      // Fallback en pourcentage
      double pctSL = MathMax(0.001, InpSLPercent/100.0);
      double pctTP = MathMax(0.001, InpTPPercent/100.0);
      
      if(direction == POSITION_TYPE_BUY)
      {
         sl = NormalizeDouble(entryPrice * (1.0 - pctSL), digits);
         tp = NormalizeDouble(entryPrice * (1.0 + pctTP), digits);
      }
      else
      {
         sl = NormalizeDouble(entryPrice * (1.0 + pctSL), digits);
         tp = NormalizeDouble(entryPrice * (1.0 - pctTP), digits);
      }
      return true;
   }
   
   // Calculer les distances en points
   double usdPerPointPerLot = tickValue * (point / tickSize);
   if(usdPerPointPerLot <= 0.0) return false;
   
   double slDistancePoints = maxLossUSD / (usdPerPointPerLot * lotSize);
   double tpDistancePoints = targetProfitUSD / (usdPerPointPerLot * lotSize);
   
   // Vérifier les distances minimales
   double minDistance = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(slDistancePoints < minDistance) slDistancePoints = minDistance;
   if(tpDistancePoints < minDistance) tpDistancePoints = minDistance;
   
   // Calculer les niveaux SL/TP
   if(direction == POSITION_TYPE_BUY)
   {
      sl = NormalizeDouble(entryPrice - slDistancePoints * point, digits);
      tp = NormalizeDouble(entryPrice + tpDistancePoints * point, digits);
   }
   else
   {
      sl = NormalizeDouble(entryPrice + slDistancePoints * point, digits);
      tp = NormalizeDouble(entryPrice - tpDistancePoints * point, digits);
   }
   
   return true;
}

// Fonction principale d'exécution du scalping
void ExecuteScalpingStrategy()
{
   if(!InpEnableAutoScalping) return;
   
   // Parcourir tous les symboles autorisés
   string list = InpAllowedSymbols;
   int start = 0;
   
   while(start < StringLen(list))
   {
      int comma = StringFind(list, ",", start);
      string symbol;
      if(comma < 0)
      {
         symbol = StringSubstr(list, start);
         start = StringLen(list);
      }
      else
      {
         symbol = StringSubstr(list, start, comma - start);
         start = comma + 1;
      }
      
      // Nettoyer le nom du symbole
      while(StringLen(symbol) > 0 && StringGetCharacter(symbol, 0) == ' ')
         symbol = StringSubstr(symbol, 1);
      while(StringLen(symbol) > 0 && StringGetCharacter(symbol, StringLen(symbol) - 1) == ' ')
         symbol = StringSubstr(symbol, 0, StringLen(symbol) - 1);
      
      if(StringLen(symbol) == 0) continue;
      if(!SymbolSelect(symbol, true)) continue;
      
      // Vérifier si le scalping est autorisé sur ce symbole
      if(!IsScalpingAllowed(symbol)) continue;
      
      // Obtenir la direction de tendance
      string trendDirection = GetTrendDirection(symbol);
      if(trendDirection == "neutral") continue;
      
      // Déterminer la direction du trade
      int tradeDirection = 0;
      if(StringFind(symbol, "Boom") >= 0 && trendDirection == "bullish")
         tradeDirection = POSITION_TYPE_BUY;
      else if(StringFind(symbol, "Crash") >= 0 && trendDirection == "bearish")
         tradeDirection = POSITION_TYPE_SELL;
      else if(InpScalpTrendOnly)
         continue; // Ne pas trader contre la tendance
      
      if(tradeDirection == 0) continue;
      
      // PROTECTION ANTI-CASCADE - Vérifier si on peut ouvrir un nouveau trade
      if(!CanOpenNewTradeForSymbol(symbol, tradeDirection))
      {
         continue; // Passer au symbole suivant
      }
      
      // Calculer le lot et les niveaux SL/TP
      double lotSize = CalculateScalpingLotSize(symbol);
      double entryPrice = (tradeDirection == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(symbol, SYMBOL_BID);
      
      double sl = 0.0, tp = 0.0;
      if(!CalculateScalpingSLTP(symbol, tradeDirection, entryPrice, lotSize, sl, tp))
      {
         if(InpDebug) Print("❌ Scalping: Impossible de calculer SL/TP pour ", symbol);
         continue;
      }
      
      // Vérifier que les niveaux sont valides
      bool slTpValid = true;
      if(tradeDirection == POSITION_TYPE_BUY)
      {
         if(sl >= entryPrice || tp <= entryPrice) slTpValid = false;
      }
      else
      {
         if(sl <= entryPrice || tp >= entryPrice) slTpValid = false;
      }
      
      // Vérifier les distances minimales
      double minDistance = 10.0 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(MathAbs(sl - entryPrice) < minDistance || MathAbs(tp - entryPrice) < minDistance)
      {
         slTpValid = false;
      }
      
      if(!slTpValid)
      {
         if(InpDebug) Print("❌ Scalping: SL/TP invalides pour ", symbol);
         continue;
      }
      
      // Exécuter le trade
      g_trade.SetExpertMagicNumber(InpMagicNumber);
      g_trade.SetDeviationInPoints(InpSlippagePoints);
      
      bool success = false;
      if(tradeDirection == POSITION_TYPE_BUY)
         success = g_trade.Buy(lotSize, symbol, entryPrice, sl, tp, "AutoScalp");
      else
         success = g_trade.Sell(lotSize, symbol, entryPrice, sl, tp, "AutoScalp");
      
      if(success)
      {
         // Mettre à jour les statistiques
         g_lastOrderTs = TimeCurrent();
         
         // Enregistrer l'historique pour protection anti-cascade
         UpdateLastTradeTimeAntiCascade(symbol);
         
         // Enregistrer le trade dans le système de cooldown
         for(int i = 0; i < 10; i++)
         {
            if(g_lastSymbols[i] == "")
            {
               g_lastSymbols[i] = symbol;
               g_lastTradeBySymbol[i] = TimeCurrent();
               break;
            }
         }
         
         Print("✅ Scalping: Trade ouvert sur ", symbol, " - Direction: ", 
               (tradeDirection == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
               " - Lot: ", lotSize, " - SL: ", sl, " - TP: ", tp);
      }
      else
      {
         Print("❌ Erreur lors de l'ouverture du trade de scalping sur ", symbol, ": ", g_trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Affiche l'état complet du trading                                |
//+------------------------------------------------------------------+
void PrintTradingStatus()
{
   if(TimeCurrent() - g_lastDebugPrint < 5) return; // Toutes les 5 secondes
   g_lastDebugPrint = TimeCurrent();
   
   string status = "=== ÉTAT DU TRADING ===\n";
   
   // 1. État du terminal
   status += "Terminal connecté: " + (TerminalInfoInteger(TERMINAL_CONNECTED) ? "OUI" : "NON") + "\n";
   status += "Trading autorisé: " + (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "OUI" : "NON") + "\n";
   // Version du terminal (méthode alternative)
   string terminalVersion = "Inconnue";
   long build = TerminalInfoInteger(TERMINAL_BUILD);
   if(build > 0)
      terminalVersion = "Build " + IntegerToString(build);
   status += "Version: " + terminalVersion + "\n\n";
   
   // 2. État du compte
   status += "=== COMPTE ===\n";
   status += "Nom: " + AccountInfoString(ACCOUNT_NAME) + "\n";
   status += "Numéro: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n";
   status += "Trading autorisé: " + (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "OUI" : "NON") + "\n";
   status += "Expert trading: " + (AccountInfoInteger(ACCOUNT_TRADE_EXPERT) ? "AUTORISÉ" : "BLOQUÉ") + "\n";
   status += "Solde: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n\n";
   
   // 3. État de l'EA
   status += "=== EXPERT ADVISOR ===\n";
   status += "Trading activé: " + (InpEnableTrading ? "OUI" : "NON") + "\n";
   status += "Magic Number: " + IntegerToString(InpMagicNumber) + "\n";
   status += "Symboles autorisés: " + InpAllowedSymbols + "\n";
   status += "Positions max: " + IntegerToString(InpMaxGlobalPositions) + "\n\n";
   
   // 4. Positions ouvertes
   int positions = CountOpenPositionsEA();
   status += "=== POSITIONS OUVERTES (" + IntegerToString(positions) + "/" + IntegerToString(InpMaxGlobalPositions) + ") ===\n";
   
   if(positions > 0)
   {
      int i;
    for(i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetTicket(i))
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            string type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "Achat" : "Vente";
            
            status += "#" + IntegerToString(ticket) + " " + symbol + " " + type + " " + 
                     DoubleToString(volume, 2) + " lot(s) - " + 
                     DoubleToString(profit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
         }
      }
   }
   else
   {
      status += "Aucune position ouverte\n";
   }
   
   // 5. Dernier signal
   status += "\n=== DERNIER SIGNAL ===\n";
   if(g_lastSpikeSignal.active)
   {
      status += "Symbole: " + g_lastSpikeSignal.symbol + "\n";
      status += "Direction: " + (g_lastSpikeSignal.direction > 0 ? "Achat" : "Vente") + "\n";
      status += "Heure: " + TimeToString(g_lastSpikeSignal.signalTime) + "\n";
      status += "Force: " + DoubleToString(g_lastSpikeSignal.signalStrength, 1) + "\n";
   }
   else
   {
      status += "Aucun signal récent\n";
   }
   
   // 6. Vérification des conditions de trading
   status += "\n=== VÉRIFICATIONS ===\n";
   
   // Vérifier la connexion
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      status += "❌ Pas de connexion au terminal\n";
   
   // Vérifier les autorisations de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      status += "❌ Le trading n'est pas autorisé dans le terminal\n";
      
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      status += "❌ Le trading n'est pas autorisé pour ce compte\n";
      
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      status += "❌ Le trading expert est désactivé par l'administrateur\n";
   
   // Vérifier les limites de positions
   if(positions >= InpMaxGlobalPositions)
      status += "⚠ Limite de positions atteinte (" + IntegerToString(positions) + "/" + IntegerToString(InpMaxGlobalPositions) + ")\n";
   
   // Afficher le statut complet
   Print("\n" + status);
   
   // Si le nombre de positions a changé, afficher un message
   if(positions != g_lastPositionCount)
   {
      Print("=== CHANGEMENT D'ÉTAT ===");
      Print("Nouveau nombre de positions: ", positions);
      g_lastPositionCount = positions;
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour les indicateurs sur le graphique                  |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
    if(!InpShowIndicators) return; // Ne rien faire si l'affichage des indicateurs est désactivé
    
    string symbol = _Symbol;
    
    // 1. Afficher la vélocité des prix
    static double velocityHistory[];
    double velocity = CalculateVelocity(symbol, InpVelocityBars, velocityHistory);
    
    // 2. Afficher le pivot typique
    double pivot = CalculateTypicalPivot(symbol, InpPivotBars);
    
    // 3. Afficher l'EMA de tendance
    double ema[];
    int ema_handle = iMA(symbol, PERIOD_CURRENT, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(CopyBuffer(ema_handle, 0, 0, 1, ema) > 0) {
        // Créer ou mettre à jour l'objet de tendance
        string ema_name = "EMA_" + string(InpEMAPeriod);
        if(ObjectFind(0, ema_name) < 0) {
            ObjectCreate(0, ema_name, OBJ_TREND, 0, iTime(symbol, PERIOD_CURRENT, 1), ema[0], 
                         iTime(symbol, PERIOD_CURRENT, 0), ema[0]);
            ObjectSetInteger(0, ema_name, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, ema_name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, ema_name, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, ema_name, OBJPROP_BACK, true);
            ObjectSetString(0, ema_name, OBJPROP_TOOLTIP, "EMA " + string(InpEMAPeriod) + " - Ligne de tendance");
        } else {
            ObjectMove(0, ema_name, 0, iTime(symbol, PERIOD_CURRENT, 0), ema[0]);
        }
    }
    IndicatorRelease(ema_handle);
    
    // 4. Afficher les zones de pivot
    string pivot_name = "Pivot_Zone";
    if(ObjectFind(0, pivot_name) < 0) {
        ObjectCreate(0, pivot_name, OBJ_RECTANGLE, 0, 0, 0, 0, 0);
        ObjectSetInteger(0, pivot_name, OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, pivot_name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, pivot_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, pivot_name, OBJPROP_SELECTABLE, false);
        ObjectSetString(0, pivot_name, OBJPROP_TOOLTIP, "Zone de pivot - Niveau clé");
    }
    
    // Mettre à jour les coordonnées de la zone de pivot
    double buffer = InpPivotBuffer * _Point;
    ObjectSetDouble(0, pivot_name, OBJPROP_PRICE, 0, pivot + buffer);
    ObjectSetDouble(0, pivot_name, OBJPROP_PRICE, 1, pivot - buffer);
    ObjectSetInteger(0, pivot_name, OBJPROP_TIME, 0, iTime(symbol, PERIOD_CURRENT, 24));
    ObjectSetInteger(0, pivot_name, OBJPROP_TIME, 1, iTime(symbol, PERIOD_CURRENT, 0));
    
    // 5. Afficher la force du signal
    double signalStrength = 0.0;
    int signal = DetectSpikeSignal(symbol, signalStrength);
    
    // 6. Afficher les bandes de Bollinger
    int bb_handle = iBands(symbol, PERIOD_CURRENT, 20, 0, 2, PRICE_CLOSE);
    double upper_band[], middle_band[], lower_band[];
    if(CopyBuffer(bb_handle, 1, 0, 1, upper_band) > 0 && 
       CopyBuffer(bb_handle, 0, 0, 1, middle_band) > 0 && 
       CopyBuffer(bb_handle, 2, 0, 1, lower_band) > 0) {
        
        // Afficher les bandes de Bollinger
        string bb_upper = "BB_Upper";
        string bb_middle = "BB_Middle";
        string bb_lower = "BB_Lower";
        
        // Bande supérieure
        if(ObjectFind(0, bb_upper) < 0) {
            ObjectCreate(0, bb_upper, OBJ_TREND, 0, iTime(symbol, PERIOD_CURRENT, 1), upper_band[0], 
                         iTime(symbol, PERIOD_CURRENT, 0), upper_band[0]);
            ObjectSetInteger(0, bb_upper, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, bb_upper, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, bb_upper, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, bb_upper, OBJPROP_BACK, true);
        } else {
            ObjectMove(0, bb_upper, 0, iTime(symbol, PERIOD_CURRENT, 0), upper_band[0]);
        }
        
        // Bande médiane
        if(ObjectFind(0, bb_middle) < 0) {
            ObjectCreate(0, bb_middle, OBJ_TREND, 0, iTime(symbol, PERIOD_CURRENT, 1), middle_band[0], 
                         iTime(symbol, PERIOD_CURRENT, 0), middle_band[0]);
            ObjectSetInteger(0, bb_middle, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, bb_middle, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, bb_middle, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, bb_middle, OBJPROP_BACK, true);
        } else {
            ObjectMove(0, bb_middle, 0, iTime(symbol, PERIOD_CURRENT, 0), middle_band[0]);
        }
        
        // Bande inférieure
        if(ObjectFind(0, bb_lower) < 0) {
            ObjectCreate(0, bb_lower, OBJ_TREND, 0, iTime(symbol, PERIOD_CURRENT, 1), lower_band[0], 
                         iTime(symbol, PERIOD_CURRENT, 0), lower_band[0]);
            ObjectSetInteger(0, bb_lower, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, bb_lower, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, bb_lower, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, bb_lower, OBJPROP_BACK, true);
        } else {
            ObjectMove(0, bb_lower, 0, iTime(symbol, PERIOD_CURRENT, 0), lower_band[0]);
        }
    }
    IndicatorRelease(bb_handle);
    
    // 7. Afficher la force du signal dans un panneau
    string signal_name = "Signal_Strength";
    string signal_text = "=== ANGEL OF SPIKE ===\n";
    signal_text += "Force du signal: " + DoubleToString(signalStrength, 2) + "\n";
    signal_text += "Direction: ";
    
    if(signal > 0) {
        signal_text += "ACHAT (▲)\n";
        signal_text += "Confiance: " + IntegerToString((int)(signalStrength * 100)) + "%";
    } else if(signal < 0) {
        signal_text += "VENTE (▼)\n";
        signal_text += "Confiance: " + IntegerToString((int)(signalStrength * 100)) + "%";
    } else {
        signal_text += "NEUTRE (-)\n";
        signal_text += "En attente d'un signal...";
    }
    
    // Ajouter des informations supplémentaires
    signal_text += "\n\n=== INFORMATIONS ===\n";
    signal_text += "EMA " + string(InpEMAPeriod) + ": " + DoubleToString(ema[0], _Digits) + "\n";
    signal_text += "Pivot: " + DoubleToString(pivot, _Digits) + "\n";
    signal_text += "Vélocité: " + DoubleToString(velocity, 2) + "\n";
    
    // Afficher le panneau d'information
    if(ObjectFind(0, signal_name) < 0) {
        ObjectCreate(0, signal_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, signal_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, signal_name, OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, signal_name, OBJPROP_YDISTANCE, 20);
        ObjectSetString(0, signal_name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, signal_name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, signal_name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, signal_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, signal_name, OBJPROP_SELECTABLE, false);
    }
    
    // Mettre à jour le texte et la couleur en fonction du signal
    if(signal > 0) {
        ObjectSetInteger(0, signal_name, OBJPROP_COLOR, clrLime);
    } else if(signal < 0) {
        ObjectSetInteger(0, signal_name, OBJPROP_COLOR, clrRed);
    } else {
        ObjectSetInteger(0, signal_name, OBJPROP_COLOR, clrYellow);
    }
    
    ObjectSetString(0, signal_name, OBJPROP_TEXT, signal_text);
    
    // 8. Mettre à jour le graphique
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| UpdateHUD - Met à jour l'interface utilisateur                   |
//+------------------------------------------------------------------+
void UpdateHUD()
{
    // Mise à jour des indicateurs sur le graphique
    if(InpShowIndicators) {
        // Mettre à jour les indicateurs avancés
        UpdateAdvancedIndicators();
        // Dessiner les zones de support et résistance
        DrawSupportResistanceZones();
    }
    
    // Mise à jour des informations de trading
    if(InpShowTradingInfo) {
        // Mise à jour des informations de trading
        UpdateTradingInfo();
    }
}

//+------------------------------------------------------------------+
//| UpdateTradingInfo - Met à jour les informations de trading       |
//+------------------------------------------------------------------+
void UpdateTradingInfo()
{
    // Mise à jour des informations de trading
    // Cette fonction peut être étendue pour inclure d'autres informations
    
    // Exemple: Afficher le solde du compte
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Mettre à jour l'interface utilisateur avec les nouvelles informations
    string info_text = "Balance: " + DoubleToString(balance, 2) + " | " +
                      "Equity: " + DoubleToString(equity, 2);
    
    // Mettre à jour l'objet texte sur le graphique
    if(ObjectFind(0, "TradingInfo") < 0) {
        ObjectCreate(0, "TradingInfo", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "TradingInfo", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, "TradingInfo", OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, "TradingInfo", OBJPROP_YDISTANCE, 20);
        ObjectSetInteger(0, "TradingInfo", OBJPROP_COLOR, clrWhite);
    }
    
    ObjectSetString(0, "TradingInfo", OBJPROP_TEXT, info_text);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Fonction pour mettre à jour les indicateurs avancés             |
//+------------------------------------------------------------------+
void UpdateAdvancedIndicators()
{
    // Mettre à jour les indicateurs avancés
    DetectAndDrawOrderBlocks();
    DetectAndDrawBOS();
    DrawOTEZones();
    
    // Mettre à jour les retracements de Fibonacci sur les derniers swings
    UpdateFibonacciLevels();
    
    // Mettre à jour les EMA
    InitializeEMAs();
}

//+------------------------------------------------------------------+
//| Fonction pour mettre à jour les niveaux de Fibonacci             |
//+------------------------------------------------------------------+
void UpdateFibonacciLevels()
{
    if(!InpShowFibonaccis) return;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, _Period, 0, 100, rates);
    
    // Trouver le swing haut et bas récents
    int swingHighBar = iHighest(_Symbol, _Period, MODE_HIGH, 50, 1);
    int swingLowBar = iLowest(_Symbol, _Period, MODE_LOW, 50, 1);
    
    if(swingHighBar > 0 && swingLowBar > 0)
    {
        double high = iHigh(_Symbol, _Period, swingHighBar);
        double low = iLow(_Symbol, _Period, swingLowBar);
        datetime timeHigh = iTime(_Symbol, _Period, swingHighBar);
        datetime timeLow = iTime(_Symbol, _Period, swingLowBar);
        
        // Dessiner le retracement Fibonacci du swing bas au swing haut
        if(swingHighBar < swingLowBar) // Tendance haussière
        {
            DrawFibonacciRetracement(_Symbol, timeLow, low, timeHigh, high, clrDodgerBlue);
        }
        else // Tendance baissière
        {
            DrawFibonacciRetracement(_Symbol, timeHigh, high, timeLow, low, clrRed);
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si une position est déjà ouverte                        |
//+------------------------------------------------------------------+
//| Vérifie si une position est ouverte pour le type spécifié        |
//+------------------------------------------------------------------+
bool HasOpenPositionByType(int type)
{
    return HasOpenPosition(_Symbol, type);
}

//+------------------------------------------------------------------+
//| Calculer la taille de position optimale                         |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if(InpLotSize > 0) return InpLotSize;
    
    // Calculer la taille de position basée sur le risque
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (InpRiskPercent / 100.0);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(tickSize == 0 || tickValue == 0 || lotStep == 0) 
        return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    double moneyRiskPerLot = (InpStopLoss * _Point / tickSize) * tickValue;
    if(moneyRiskPerLot == 0) 
        return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        
    double lots = NormalizeDouble(riskAmount / moneyRiskPerLot, 2);
    
    // Ajuster selon les limites du broker
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    
    return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Gérer les positions ouvertes (fonction déplacée plus bas)        |
//+------------------------------------------------------------------+
// Cette fonction a été déplacée plus bas dans le fichier pour éviter les doublons
// et améliorer la cohérence du code.

//+------------------------------------------------------------------+
//| Vérifier si le trading est autorisé                             |
//+------------------------------------------------------------------+
//| VERSION DE DÉBOGAGE - TOUTES LES RESTRICTIONS DÉSACTIVÉES       |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    // VERSION DE DÉBOGAGE - TOUJOURS AUTORISER LE TRADING
    static bool debugWarningShown = false;
    if(!debugWarningShown) {
        Print("ATTENTION: Mode débogage actif - Toutes les restrictions de trading sont désactivées");
        debugWarningShown = true;
    }
    
    // Vérifier uniquement la connexion au serveur (essentiel)
    if(!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        Print("ERREUR: Pas de connexion au serveur de trading");
        return false;
    }
    
    // Vérifier si le trading est activé dans les paramètres
    if(!InpEnableAutoTrading)
    {
        Print("ATTENTION: Le trading automatique est désactivé dans les paramètres (InpEnableAutoTrading = false)");
        return false;
    }
    
    // Afficher un message de débogage
    static datetime lastDebugMsg = 0;
    if(TimeCurrent() - lastDebugMsg > 60) // Toutes les 60 secondes
    {
        Print("DÉBOGAGE: Trading autorisé - Toutes les restrictions sont désactivées");
        lastDebugMsg = TimeCurrent();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifie la stabilité de la connexion et du graphique             |
//+------------------------------------------------------------------+
bool CheckStability()
{
    // Vérifier la connexion au terminal
    if(!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        static datetime lastAlert = 0;
        if(TimeCurrent() - lastAlert > 300) // Alerter toutes les 5 minutes max
        {
            Print("ERREUR: Pas de connexion au terminal!");
            if(InpShowNotification) Alert("AngelOfSpike - Pas de connexion au terminal!");
            lastAlert = TimeCurrent();
        }
        return false;
    }
    
    // Vérifier que le terminal est en mode graphique (sauf en backtest)
    if(!MQLInfoInteger(MQL_VISUAL_MODE) && !MQLInfoInteger(MQL_TESTER))
    {
        Print("ERREUR: Le robot doit être exécuté en mode graphique!");
        return false;
    }
    
    // Vérifier que le symbole est sélectionné
    if(!SymbolSelect(_Symbol, true))
    {
        static datetime lastSymbolAlert = 0;
        if(TimeCurrent() - lastSymbolAlert > 300) // Alerter toutes les 5 minutes max
        {
            Print("ERREUR: Impossible de sélectionner le symbole ", _Symbol);
            if(InpShowNotification) Alert("AngelOfSpike - Impossible de sélectionner le symbole ", _Symbol);
            lastSymbolAlert = TimeCurrent();
        }
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Expert tick function - Optimisée pour réduire la charge          |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérifier la stabilité avant de continuer
    static int stabilityErrorCount = 0;
    if(!CheckStability())
    {
        stabilityErrorCount++;
        if(stabilityErrorCount > 10) // Si trop d'erreurs consécutives
        {
            // Tenter de se réattacher au graphique
            if(!ChartSetSymbolPeriod(0, _Symbol, _Period))
            {
                Print("Tentative de réattachement au graphique échouée");
            }
            stabilityErrorCount = 0; // Réinitialiser le compteur
        }
        Sleep(1000); // Attendre 1 seconde avant de réessayer
        return;
    }
    stabilityErrorCount = 0; // Réinitialiser le compteur d'erreurs
    
    // Vérifier si nous sommes sur un nouveau tick
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    // Ne traiter qu'une seule fois par bougie
    if(lastBarTime == currentBarTime) 
    {
        // Gérer les positions ouvertes même sur les ticks intermédiaires
        // mais avec une fréquence réduite (toutes les 5 secondes)
        static datetime lastPositionCheck = 0;
        if(PositionsTotal() > 0 && (TimeCurrent() - lastPositionCheck) >= 5) 
        {
            ManageOpenPositions();
            lastPositionCheck = TimeCurrent();
        }
        return;
    }
    
    // Mettre à jour le temps de la dernière bougie traitée
    lastBarTime = currentBarTime;
    
    // Vérifier la connexion au serveur (uniquement toutes les 10 secondes)
    static datetime lastConnectionCheck = 0;
    if((TimeCurrent() - lastConnectionCheck) >= 10)
    {
        if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        {
            Print("❌ Erreur: Pas de connexion au serveur de trading");
            return;
        }
        lastConnectionCheck = TimeCurrent();
    }
    
    // Mettre à jour les indicateurs sur le graphique (si activé et seulement si nécessaire)
    if(InpShowIndicators) 
    {
        // Mettre à jour les indicateurs seulement toutes les 5 secondes pour réduire la charge
        static datetime lastIndicatorUpdate = 0;
        if((TimeCurrent() - lastIndicatorUpdate) >= 5)
        {
            UpdateIndicators();
            UpdateAdvancedIndicators();
            lastIndicatorUpdate = TimeCurrent();
        }
    }
    
    // Vérifier les signaux de trading si le trading est autorisé
    static int lastLogTime = 0;
    int currentTime = (int)TimeCurrent();
    
    if(IsTradingAllowed())
    {
        if(currentTime - lastLogTime >= 5) // Log toutes les 5 secondes
        {
            Print("=== STATUT DU TRADING ===");
            Print("Heure: ", TimeToString(TimeCurrent()));
            Print("Symbole: ", _Symbol);
            Print("Prix actuel - Ask: ", SymbolInfoDouble(_Symbol, SYMBOL_ASK), " Bid: ", SymbolInfoDouble(_Symbol, SYMBOL_BID));
            Print("Connexion au serveur: ", (TerminalInfoInteger(TERMINAL_CONNECTED) ? "OK" : "ERREUR"));
            Print("Trading autorisé: ", (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "OUI" : "NON"));
            Print("Compte de trading actif: ", (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "OUI" : "NON"));
            Print("Mode trading automatique: ", (InpEnableAutoTrading ? "ACTIF" : "INACTIF"));
            Print("Mode trading de spike: ", (InpEnableSpikeTrading ? "ACTIF" : "INACTIF"));
            Print("Nombre de positions ouvertes: ", PositionsTotal());
            Print("Marge disponible: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
            Print("=== FIN DU STATUT ===\n");
            
            lastLogTime = currentTime;
        }
        
        // Générer un signal de trading
        int signal = GenerateTradingSignal();
        
        if(signal != 0)
        {
            Print("=== SIGNAL DÉTECTÉ ===");
            Print("Type: ", (signal > 0 ? "ACHAT" : "VENTE"));
            Print("Heure: ", TimeToString(TimeCurrent()));
            Print("Prix: ", (signal > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID)));
        }
        
        // Exécuter le trade en fonction du signal
        if(signal != 0)
        {
            double lotSize = CalculateLotSize();
            double stopLoss = 0, takeProfit = 0;
            
            Print("=== TENTATIVE D'OUVERTURE DE POSITION ===");
            Print("Taille de lot calculée: ", lotSize);
            
            if(signal > 0) // Signal d'achat
            {
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                stopLoss = ask - InpStopLoss * _Point;
                takeProfit = ask + InpTakeProfit * _Point;
                
                Print("Signal ACHAT détecté");
                Print("Prix d'entrée (Ask): ", ask);
                Print("Stop Loss: ", stopLoss, " (", (ask - stopLoss) / _Point, " points)");
                Print("Take Profit: ", takeProfit, " (", (takeProfit - ask) / _Point, " points)");
                
                // Vérifier si nous n'avons pas déjà une position d'achat ouverte
                if(!HasOpenPosition(_Symbol, ORDER_TYPE_BUY))
                {
                    Print("Aucune position d'achat existante détectée, tentative d'ouverture...");
                    Print("Détails de l'ordre - Lot: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
                    
                    trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "Achat sur signal");
                    
                    // Dessiner le retracement Fibonacci pour le trade (si activé)
                    if(InpShowTradingInfo)
                    {
                        double low = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, 20, 1));
                        DrawFibonacciRetracement(_Symbol, iTime(_Symbol, _Period, 1), low, 
                                               TimeCurrent(), ask, clrDodgerBlue);
                    }
                }
            }
            else // Signal de vente
            {
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                stopLoss = bid + InpStopLoss * _Point;
                takeProfit = bid - InpTakeProfit * _Point;
                
                // Vérifier si nous n'avons pas déjà une position de vente ouverte
                if(!HasOpenPosition(_Symbol, ORDER_TYPE_SELL))
                {
                    Print("Aucune position de vente existante détectée, tentative d'ouverture...");
                    Print("Détails de l'ordre - Lot: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
                    
                    trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "Vente sur signal");
                    
                    // Dessiner le retracement Fibonacci pour le trade (si activé)
                    if(InpShowTradingInfo)
                    {
                        double high = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, 20, 1));
                        DrawFibonacciRetracement(_Symbol, iTime(_Symbol, _Period, 1), high, 
                                               TimeCurrent(), bid, clrRed);
                    }
                }
            }
        }
    }
    
    // Mettre à jour le HUD si activé (avec une fréquence réduite)
    if(InpShowHUD) 
    {
        static datetime lastHUDUpdate = 0;
        if((TimeCurrent() - lastHUDUpdate) >= 2) // Mise à jour toutes les 2 secondes
        {
            UpdateHUD();
            lastHUDUpdate = TimeCurrent();
        }
    }
    
    // Vérifier périodiquement l'état du compte et de la connexion
    static datetime lastStatusCheck = 0;
    if(TimeCurrent() - lastStatusCheck >= 10) // Toutes les 10 secondes
    {
        if(!TerminalInfoInteger(TERMINAL_CONNECTED))
            Print("⚠️ Attention: Pas de connexion au serveur de trading!");
            
        if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
            Print("⚠️ Attention: Le trading n'est pas autorisé dans le terminal!");
            
        if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
            Print("⚠️ Attention: Le trading n'est pas autorisé pour ce compte!");
            
        if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < 10.0) // Moins de 10$ de marge disponible
            Print("⚠️ Attention: Marge disponible très faible: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
            
        lastStatusCheck = TimeCurrent();
    }
    
    // Afficher le statut du trading (avec une fréquence réduite)
    static datetime lastStatusPrint = 0;
    if((TimeCurrent() - lastStatusPrint) >= 5) // Toutes les 5 secondes
    {
        PrintTradingStatus();
        lastStatusPrint = TimeCurrent();
    }

    ClosePositionAfterSpikeCapture();
}

//+------------------------------------------------------------------+
//| Fonctions pour les indicateurs avancés                          |
//+------------------------------------------------------------------+

// Fonction pour dessiner les retracements de Fibonacci
void DrawFibonacciRetracement(string symbol, datetime time1, double price1, datetime time2, double price2, color clr=clrDodgerBlue)
{
    if(!InpShowFibonaccis) return;
    
    string name = "Fibo_" + IntegerToString(GetTickCount());
    
    // Créer l'objet Fibonacci
    if(!ObjectCreate(0, name, OBJ_FIBO, 0, time1, price1, time2, price2))
    {
        Print("Erreur lors de la création de l'objet Fibonacci: ", GetLastError());
        return;
    }
    
    // Définir les propriétés de l'objet
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
    
    // Configurer les niveaux de Fibonacci
    double levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 1.0};
    string desc[] = {"0%", "23.6%", "38.2%", "50%", "61.8%", "100%"};
    
    // Définir les niveaux de retracement
    for(int i = 0; i < ArraySize(levels); i++)
    {
        ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, i, clr);
        ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, i, STYLE_DOT);
        ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, i, 1);
        ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, desc[i]);
        ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, i, levels[i]);
    }
}

// Fonction pour détecter et dessiner les blocs d'ordres (Order Blocks)
void DetectAndDrawOrderBlocks()
{
    if(!InpShowOrderBlocks) return;
    
    // Supprimer les anciens blocs
    for(int i = ObjectsTotal(0, 0, -1)-1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, "OB_") == 0) ObjectDelete(0, name);
    }
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 200, rates); // Augmenté à 200 bougies pour plus de contexte
    
    // Tableaux pour stocker les blocs d'ordres détectés
    struct OrderBlock {
        datetime time1, time2;
        double price1, price2;
        bool isBullish;
        int strength; // Force du bloc (nombre de bougies de confirmation)
    };
    
    OrderBlock blocks[];
    int blockCount = 0;
    
    // Détection des blocs d'ordres
    for(int i=5; i<ArraySize(rates)-5; i++)
    {
        // Détection d'un bloc d'ordre haussier (grosse bougie baissière après une tendance baissière)
        if(rates[i].close > rates[i].open && 
           rates[i-1].close < rates[i-1].open && 
           rates[i-2].close < rates[i-2].open &&
           rates[i-3].close < rates[i-3].open) // Au moins 3 bougies baissières avant
        {
            // Vérifier si le prix est revenu tester la zone (confirmation)
            bool confirmed = false;
            int confirmationCount = 0;
            
            for(int j=i+1; j<i+20 && j<ArraySize(rates); j++)
            {
                if(rates[j].low <= rates[i].high && rates[j].high >= rates[i].low)
                {
                    confirmed = true;
                    confirmationCount++;
                }
            }
            
            if(confirmed)
            {
                // Ajouter le bloc à notre tableau
                ArrayResize(blocks, blockCount+1);
                blocks[blockCount].time1 = rates[i].time;
                blocks[blockCount].time2 = rates[i+1].time;
                blocks[blockCount].price1 = rates[i].low;
                blocks[blockCount].price2 = rates[i].high;
                blocks[blockCount].isBullish = true;
                blocks[blockCount].strength = confirmationCount;
                blockCount++;
            }
        }
        
        // Détection d'un bloc d'ordre baissier (grosse bougie haussière après une tendance haussière)
        if(rates[i].close < rates[i].open && 
           rates[i-1].close > rates[i-1].open && 
           rates[i-2].close > rates[i-2].open &&
           rates[i-3].close > rates[i-3].open) // Au moins 3 bougies haussières avant
        {
            // Vérifier si le prix est revenu tester la zone (confirmation)
            bool confirmed = false;
            int confirmationCount = 0;
            
            for(int j=i+1; j<i+20 && j<ArraySize(rates); j++)
            {
                if(rates[j].high >= rates[i].low && rates[j].low <= rates[i].high)
                {
                    confirmed = true;
                    confirmationCount++;
                }
            }
            
            if(confirmed)
            {
                // Ajouter le bloc à notre tableau
                ArrayResize(blocks, blockCount+1);
                blocks[blockCount].time1 = rates[i].time;
                blocks[blockCount].time2 = rates[i+1].time;
                blocks[blockCount].price1 = rates[i].high;
                blocks[blockCount].price2 = rates[i].low;
                blocks[blockCount].isBullish = false;
                blocks[blockCount].strength = confirmationCount;
                blockCount++;
            }
        }
    }
    
    // Trier les blocs par force (du plus fort au plus faible)
    for(int i=0; i<blockCount-1; i++)
    {
        for(int j=i+1; j<blockCount; j++)
        {
            if(blocks[i].strength < blocks[j].strength)
            {
                OrderBlock temp = blocks[i];
                blocks[i] = blocks[j];
                blocks[j] = temp;
            }
        }
    }
    
    // Ne garder que les blocs les plus forts (limite à 5 pour éviter la surcharge)
    int maxBlocks = MathMin(5, blockCount);
    
    // Dessiner les blocs d'ordres confirmés
    for(int i=0; i<maxBlocks; i++)
    {
        string name = StringFormat("OB_%d_%d", (int)blocks[i].time1, i);
        
        if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, blocks[i].time1, blocks[i].price1, 
                       blocks[i].time2, blocks[i].price2))
        {
            // Couleurs vives avec transparence
            color blockColor = blocks[i].isBullish ? C'0,255,0' : C'255,0,0'; // Vert vif pour haussier, Rouge vif pour baissier
            
            // Style du bloc
            ObjectSetInteger(0, name, OBJPROP_COLOR, blockColor);
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, blockColor);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Bordure plus épaisse
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            
            // Ajouter une étiquette pour la force du bloc
            string labelName = name + "_Label";
            double labelPrice = (blocks[i].price1 + blocks[i].price2) / 2.0;
            
            if(ObjectCreate(0, labelName, OBJ_TEXT, 0, blocks[i].time1, labelPrice))
            {
                string labelText = StringFormat("OB %s (Force: %d%%)", 
                    blocks[i].isBullish ? "Hausse" : "Baisse", 
                    (blocks[i].strength * 100) / 20); // Pourcentage de confirmation
                
                ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
                ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
                ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            }
        }
    }
}

// Fonction pour détecter et dessiner les Break of Structure (BOS)
void DetectAndDrawBOS()
{
    if(!InpShowBOS) return;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 100, rates);
    
    for(int i=2; i<ArraySize(rates)-1; i++)
    {
        // BOS haussier
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
        {
            string name = "BOS_Up_"+IntegerToString(GetTickCount());
            if(ObjectCreate(0, name, OBJ_ARROW_UP, 0, rates[i].time, rates[i].high + 10 * _Point))
            {
                ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
                ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            }
        }
        
        // BOS baissier
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
        {
            string name = "BOS_Down_"+IntegerToString(GetTickCount());
            if(ObjectCreate(0, name, OBJ_ARROW_DOWN, 0, rates[i].time, rates[i].low - 10 * _Point))
            {
                ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
                ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            }
        }
    }
}

// Fonction pour dessiner les zones OTE (Optimal Trade Entry) - Désactivée
void DrawOTEZones()
{
    // Fonction désactivée - Ne rien faire
    return;
}

//+------------------------------------------------------------------+
//| Fonctions pour gérer les EMA                                    |
//+------------------------------------------------------------------+

// Fonction pour initialiser les indicateurs EMA
void InitializeEMAs()
{
    // Ne rien faire si l'affichage des indicateurs est désactivé
    if(!InpShowIndicators) 
    {
        Print("Affichage des indicateurs EMA désactivé pour réduire la charge");
        return;
    }
    
    // Désactiver le rafraîchissement automatique du graphique
    ChartSetInteger(0, CHART_AUTOSCROLL, 0, false);
    ChartSetInteger(0, CHART_SHIFT, 0, true);
    
    // Détruire les anciens indicateurs
    ObjectsDeleteAll(0, "EMA_");
    
    // Créer uniquement les EMA nécessaires (réduit de 5 à 3)
    int ema1 = iMA(_Symbol, _Period, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);  // EMA rapide
    int ema2 = iMA(_Symbol, _Period, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);  // EMA moyen (au lieu de EMA2)
    int ema3 = iMA(_Symbol, _Period, InpEMA5, 0, MODE_EMA, PRICE_CLOSE);  // EMA lent (au lieu de EMA4/5)
    
    // Configurer l'affichage des EMA (uniquement si activé)
    if(InpShowIndicators)
    {
        ChartIndicatorAdd(0, 0, ema1);
        ChartIndicatorAdd(0, 0, ema2);
        ChartIndicatorAdd(0, 0, ema3);
        
        // Appliquer les styles aux EMA (couleurs simplifiées)
        PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrBlue);    // EMA rapide en bleu
        PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, clrOrange);  // EMA moyen en orange
        PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, clrRed);     // EMA lent en rouge
        
        // Configurer l'épaisseur des lignes (plus fines pour réduire la charge)
        for(int i=0; i<3; i++)
        {
            PlotIndexSetInteger(i, PLOT_LINE_WIDTH, 1);  // Épaisseur réduite
        }
    }
}

//+------------------------------------------------------------------+
//| Fonction pour générer les signaux de trading                     |
//+------------------------------------------------------------------+
int GenerateTradingSignal()
{
    // Journalisation de l'entrée dans la fonction
    static int callCount = 0;
    callCount++;
    if(callCount % 10 == 0) // Ne pas surcharger les logs
        Print("=== Appel ", callCount, " de GenerateTradingSignal() à ", TimeToString(TimeCurrent()));
    
    // Vérifier si le symbole est un Boom ou un Crash
    string symbol = _Symbol;
    bool isBoomSymbol = (StringFind(symbol, "Boom") >= 0);
    bool isCrashSymbol = (StringFind(symbol, "Crash") >= 0);
    
    if(isBoomSymbol) Print("Symbole Boom détecté - Mode haussier uniquement");
    if(isCrashSymbol) Print("Symbole Crash détecté - Mode baissier uniquement");
    
    // Vérifier la tendance avec les EMA
    double emaFast[], emaMedium[], emaSlow[], emaVerySlow[];
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaMedium, true);
    ArraySetAsSeries(emaSlow, true);
    ArraySetAsSeries(emaVerySlow, true);
    
    // Utiliser plusieurs EMA pour une meilleure détection de tendance
    int emaFastHandle = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
    int emaMediumHandle = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
    int emaSlowHandle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
    
    // Vérifier que les poignées sont valides
    if(emaFastHandle == INVALID_HANDLE || emaMediumHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE)
    {
        Print("❌ Erreur lors de la création des indicateurs EMA");
        if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
        if(emaMediumHandle != INVALID_HANDLE) IndicatorRelease(emaMediumHandle);
        if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
        return 0;
    }
    
    int emaVerySlowHandle = iMA(_Symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) <= 0 || 
       CopyBuffer(emaMediumHandle, 0, 0, 3, emaMedium) <= 0 ||
       CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) <= 0 ||
       CopyBuffer(emaVerySlowHandle, 0, 0, 3, emaVerySlow) <= 0)
    {
        Print("❌ Erreur lors de la copie des données EMA");
        return 0;
    }
    
    // Afficher les valeurs des EMA pour le débogage
    if(callCount % 10 == 0) {
        Print("Valeurs EMA - Rapide(9): ", emaFast[0], ", Moyenne(21): ", emaMedium[0], 
              ", Lente(50): ", emaSlow[0], ", Très Lente(200): ", emaVerySlow[0]);
    }
    
    // Déterminer la tendance principale
    bool isUptrend = emaFast[0] > emaMedium[0] && emaMedium[0] > emaSlow[0] && emaSlow[0] > emaVerySlow[0];
    bool isDowntrend = emaFast[0] < emaMedium[0] && emaMedium[0] < emaSlow[0] && emaSlow[0] < emaVerySlow[0];
    
    // Afficher l'état de la tendance
    if(callCount % 10 == 0) {
        Print("Tendance - Haussière: ", isUptrend, ", Baissière: ", isDowntrend, ", Neutre: ", !isUptrend && !isDowntrend);
    }
    
    // Vérifier les conditions de trading
    bool buySignal = false;
    bool sellSignal = false;
    
    // 1. Vérifier le croisement des EMA (seulement dans le sens de la tendance)
    bool emaCrossUp = emaFast[1] <= emaMedium[1] && emaFast[0] > emaMedium[0];
    bool emaCrossDown = emaFast[1] >= emaMedium[1] && emaFast[0] < emaMedium[0];
    
    if(emaCrossUp && (isUptrend || !isDowntrend)) // Permettre les signaux d'achat en tendance haussière ou neutre
    {
        buySignal = true;
        Print("✅ Signal d'achat détecté - Croisement haussier des EMA");
        Print("   EMA(9): ", emaFast[0], ", EMA(21): ", emaMedium[0]);
    }
    else if(emaCrossDown && (isDowntrend || !isUptrend)) // Permettre les signaux de vente en tendance baissière ou neutre
    {
        sellSignal = true;
        Print("✅ Signal de vente détecté - Croisement baissier des EMA");
        Print("   EMA(9): ", emaFast[0], ", EMA(21): ", emaMedium[0]);
    }
    else if(callCount % 10 == 0) {
        Print("Aucun croisement EMA détecté ou conditions de tendance non remplies");
    }
    
    // 2. Vérifier la position du prix par rapport aux EMA
    double closePrice = iClose(_Symbol, _Period, 0);
    double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(callCount % 10 == 0) {
        Print("Prix - Fermeture: ", closePrice, ", Bid: ", bidPrice, ", Ask: ", askPrice, ", EMA(200): ", emaVerySlow[0]);
    }
    
    // Pour les signaux d'achat, le prix doit être au-dessus de la moyenne mobile la plus lente
    if(buySignal && closePrice < emaVerySlow[0])
    {
        Print("⚠️ Signal d'achat annulé - Prix ", closePrice, " sous l'EMA(200): ", emaVerySlow[0]);
        buySignal = false;
    }
    
    // Pour les signaux de vente, le prix doit être en dessous de la moyenne mobile la plus lente
    if(sellSignal && closePrice > emaVerySlow[0])
    {
        Print("⚠️ Signal de vente annulé - Prix ", closePrice, " au-dessus de l'EMA(200): ", emaVerySlow[0]);
        sellSignal = false;
    }
    
    // 3. Vérifier les paires Boom/Crash
    if(isBoomSymbol)
    {
        Print("Symbole Boom détecté - Pas de vente autorisée");
        sellSignal = false; // Pas de vente sur les paires Boom
    }
    
    if(isCrashSymbol)
    {
        Print("Symbole Crash détecté - Pas d'achat autorisé");
        buySignal = false; // Pas d'achat sur les paires Crash
    }
    
    // 4. Vérifier la volatilité avec ATR
    double atr[];
    ArraySetAsSeries(atr, true);
    int atrHandle = iATR(_Symbol, _Period, 14);
    
    if(atrHandle == INVALID_HANDLE) {
        Print("❌ Erreur lors de la création de l'indicateur ATR");
    }
    else if(CopyBuffer(atrHandle, 0, 0, 3, atr) > 0)
    {
        double currentATR = atr[0];
        double atrThreshold = 5 * _Point; // Seuil réduit pour plus de sensibilité
        
        // Afficher la valeur ATR pour le débogage
        if(callCount % 10 == 0) {
            Print("ATR(14): ", currentATR, ", Seuil minimum: ", atrThreshold, ", Point: ", _Point);
        }
        
        // Vérifier si la volatilité est suffisante
        if(currentATR < atrThreshold)
        {
            Print("⚠️ Volatilité insuffisante pour trader: ", currentATR, " < ", atrThreshold);
            // Ne pas retourner 0 immédiatement, laisser les autres conditions s'appliquer
        }
        else {
            if(callCount % 10 == 0) {
                Print("✅ Volatilité suffisante: ", currentATR, " >= ", atrThreshold);
            }
        }
    }
    else {
        Print("⚠️ Impossible de copier les données ATR");
    }
    
    // 5. Vérifier les conditions supplémentaires avant de confirmer le signal
    int signal = 0;
    
    // Vérifier l'heure de trading (exemple: éviter les périodes de faible liquidité)
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    bool isTradingHours = (timeStruct.hour >= 8 && timeStruct.hour < 20); // Exemple: 8h-20h
    
    if(!isTradingHours) {
        if(callCount % 30 == 0) // Ne pas surcharger les logs
            Print("⚠️ Hors des heures de trading optimales (8h-20h)");
        // Ne pas retourner 0 pour permettre le trading en dehors des heures de pointe
    }
    
    // Vérifier le spread
    double spread = (askPrice - bidPrice) / _Point;
    double maxSpread = 20.0; // Seuil de spread maximum en points
    
    if(spread > maxSpread) {
        Print("⚠️ Spread trop élevé: ", spread, " points (max: ", maxSpread, ")");
        return 0; // Spread trop élevé, annuler le trade
    }
    
    // Confirmer le signal final
    if(buySignal) 
    {
        Print("✅✅ SIGNAL D'ACHAT CONFIRMÉ à ", TimeToString(TimeCurrent()));
        Print("   Prix: ", askPrice, ", Stop Loss: ", (askPrice - InpStopLoss * _Point));
        Print("   Take Profit: ", (askPrice + InpTakeProfit * _Point), ", Lot: ", CalculateLotSize());
        
        // Dessiner une flèche d'achat
        DrawSignalArrow(_Symbol, 1, askPrice, TimeCurrent(), "Signal ACHAT");
        
        // Dessiner les zones de support/résistance
        if(InpShowSRZones)
        {
            double range = askPrice * 0.002; // 0.2% du prix
            // Dessiner la zone de support pour l'achat
            string buyZoneName = "SR_BuyZone_" + IntegerToString(GetTickCount());
            DrawSupportResistanceZone(_Symbol, askPrice - range, askPrice, buyZoneName, clrLime, 1, STYLE_DOT);
        }
        
        signal = 1;   // Signal d'achat
    }
    else if(sellSignal) 
    {
        Print("✅✅ SIGNAL DE VENTE CONFIRMÉ à ", TimeToString(TimeCurrent()));
        Print("   Prix: ", bidPrice, ", Stop Loss: ", (bidPrice + InpStopLoss * _Point));
        Print("   Take Profit: ", (bidPrice - InpTakeProfit * _Point), ", Lot: ", CalculateLotSize());
        
        // Appel de DrawSignalArrow avec les bons paramètres
        DrawSignalArrow(_Symbol, -1, bidPrice, TimeCurrent(), "Signal VENTE");
        
        // Dessiner les zones de support/résistance
        if(InpShowSRZones)
        {
            double range = bidPrice * 0.002; // 0.2% du prix
            // Dessiner la zone de résistance pour la vente
            string sellZoneName = "SR_SellZone_" + IntegerToString(GetTickCount());
            DrawSupportResistanceZone(_Symbol, bidPrice, bidPrice + range, sellZoneName, clrRed, 1, STYLE_DOT);
        }
        
        signal = -1;  // Signal de vente
    }
    else if(callCount % 10 == 0) {
        Print("Aucun signal de trading valide détecté");
    }
    
    // Libérer les ressources
    if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
    if(emaMediumHandle != INVALID_HANDLE) IndicatorRelease(emaMediumHandle);
    if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
    if(emaVerySlowHandle != INVALID_HANDLE) IndicatorRelease(emaVerySlowHandle);
    if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
    
    // Journalisation du résultat final
    if(signal != 0 && callCount % 1 == 0) { // Toujours afficher les signaux
        Print("=== SIGNAL FINAL: ", (signal > 0 ? "ACHAT" : "VENTE"), " ===");
    }
    
    return signal; // Retourner le signal (1 pour achat, -1 pour vente, 0 pour aucun signal)
}

//+------------------------------------------------------------------+
//| Vérifie si tous les indicateurs sont correctement initialisés    |
//+------------------------------------------------------------------+
bool CheckIndicators()
{
   // Vérifier les handles des indicateurs
   if(g_hEMA20 == INVALID_HANDLE || g_hEMA50 == INVALID_HANDLE)
   {
      Print("ERREUR: Certains indicateurs EMA ne sont pas initialisés");
      return false;
   }
   
   // Vérifier d'autres indicateurs si nécessaire
   // ...
   
   return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Vérifier la connexion au serveur
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Alert("❌ Erreur: Pas de connexion au serveur de trading");
      return INIT_FAILED;
   }
   
   // Vérifier les autorisations de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Alert("❌ Erreur: Le trading n'est pas autorisé. Vérifiez les paramètres du terminal.");
      return INIT_FAILED;
   }
   
   // Vérifier si le trading est autorisé pour ce compte
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Alert("❌ Erreur: Le trading n'est pas autorisé pour ce compte.");
      return INIT_FAILED;
   }
   
   // Vérifier si le mode expert est autorisé
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Alert("❌ Erreur: Le trading automatisé est désactivé. Activez-le dans les paramètres du terminal.");
      return INIT_FAILED;
   }
   
   Print("=== Initialisation de l'Expert Advisor ===");
   
   // Initialiser les objets graphiques
   if(!InitGraphicalObjects())
   {
      Alert("❌ Échec de l'initialisation des objets graphiques");
      return INIT_FAILED;
   }
   
   // Initialiser tous les indicateurs techniques
   if(!InitializeTechnicalIndicators())
   {
      if(InpRequireAllIndicators)
      {
         Alert("❌ Échec critique de l'initialisation des indicateurs techniques. Vérifiez le journal pour plus de détails.");
         return INIT_FAILED;
      }
      else
      {
         Alert("⚠️ Certains indicateurs n'ont pas pu être initialisés, mais le trading se poursuit. Vérifiez le journal pour plus de détails.");
      }
   }
   
   Print("✅ Initialisation terminée avec succès");
   
   // Détecter les niveaux de support/résistance sur le graphique actuel
   DrawSupportResistanceLevels();
   
   // Initialiser la session quotidienne
   g_startBalanceToday = AccountInfoDouble(ACCOUNT_BALANCE);
   g_tradesToday = 0;
   g_consecLosses = 0;
   g_dayStopped = false;
   
   // Initialize money management statistics
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_totalProfit = 0.0;
   g_totalLoss = 0.0;
   g_totalWins = 0;
   g_totalLosses = 0;
   g_lastOrderTime = 0;
   
   // INITIALISATION CRITIQUE DES VARIABLES DE CONTRÔLE ANTI-MULTIPLES TRADES
   g_lastScan = TimeCurrent(); // Empêcher le scan immédiat au démarrage
   g_lastOrderTs = TimeCurrent(); // Empêcher les ordres immédiats
   
   // Initialiser tous les tableaux de cooldown à zéro
   for(int i = 0; i < 10; i++)
   {
      g_lastTradeBySymbol[i] = 0;
      g_lastSymbols[i] = "";
   }
   
   // Initialiser le tableau de cooldown anti-cascade
   for(int i = 0; i < 64; i++)
   {
      g_last_trade_time_by_symbol[i] = 0;
      g_trades_per_minute_by_symbol[i] = 0;
   }
   
   // Initialiser les variables de blocage de sécurité
   g_tradingBlocked = false;
   g_blockUntil = 0;
   
   // Initialiser les cooldowns Boom/Crash
   for(int i = 0; i < 20; i++)
   {
      g_bcSymbolCooldownUntil[i] = 0;
      g_bcCooldownSymbols[i] = "";
   }
   
   // Initialiser les timestamps de pertes
   for(int i = 0; i < 10; i++)
   {
      g_bcLossTimestamps[i] = 0;
   }
   
   // Initialiser les gardes d'ordres récents
   for(int i = 0; i < 20; i++)
   {
      g_recentOrderSymbols[i] = "";
      g_recentOrderDirs[i] = 0;
      g_recentOrderTimes[i] = 0;
   }
   
   Print("✅ INITIALISATION COMPLÈTE - Protection anti-multiples trades activée");
   // Configure trade context
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   // Créer les indicateurs en superposition sur le graphique
   if(!InpDisableProblematicIndicators)
   {
      if(InpShowEMAOverlay)
      { 
         g_hEMA1 = iMA(_Symbol, PERIOD_CURRENT, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);
         g_hEMA2 = iMA(_Symbol, PERIOD_CURRENT, InpEMA2, 0, MODE_EMA, PRICE_CLOSE);
         g_hEMA3 = iMA(_Symbol, PERIOD_CURRENT, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);
         g_hEMA4 = iMA(_Symbol, PERIOD_CURRENT, InpEMA4, 0, MODE_EMA, PRICE_CLOSE);
         g_hEMA5 = iMA(_Symbol, PERIOD_CURRENT, InpEMA5, 0, MODE_EMA, PRICE_CLOSE);
      }
      
      if(InpShowBollinger)
      { 
         g_hBB = iBands(_Symbol, PERIOD_CURRENT, InpBB_Period_Overlay, (int)InpBB_Deviation_Overlay, 0, PRICE_CLOSE);
         if(g_hBB != INVALID_HANDLE) 
            ChartIndicatorAdd(0, 0, g_hBB); 
      }
      
      if(InpShowEnvelopes)
      { 
         g_hEnv = iEnvelopes(_Symbol, PERIOD_CURRENT, InpEnv_Period, 0, MODE_EMA, PRICE_CLOSE, InpEnv_Deviation_Pct);
         if(g_hEnv != INVALID_HANDLE) 
            ChartIndicatorAdd(0, 0, g_hEnv); 
      }
   }
   else
   {
      Print("⚠️ Indicateurs graphiques désactivés pour éviter le détachement du robot");
   }
   
   // Initialiser les EMA pour la stratégie Boom/Crash (uniquement si non désactivés)
   if(!InpDisableProblematicIndicators)
   {
      g_hEMA20 = iMA(_Symbol, PERIOD_M1, InpEMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
      g_hEMA50 = iMA(_Symbol, PERIOD_M1, InpEMA50_Period, 0, MODE_EMA, PRICE_CLOSE);
      
      // Vérification des handles des indicateurs
      if(g_hEMA20 == INVALID_HANDLE || g_hEMA50 == INVALID_HANDLE)
      {
         Print("❌ ERREUR: Impossible d'initialiser les EMA pour la stratégie Boom/Crash");
         if(InpRequireAllIndicators)
            return INIT_FAILED;
         Print("⚠️ Poursuite malgré l'erreur car InpRequireAllIndicators est désactivé");
      }
   }
   else
   {
      // Utiliser des valeurs par défaut pour éviter les erreurs
      g_hEMA20 = INVALID_HANDLE;
      g_hEMA50 = INVALID_HANDLE;
      Print("⚠️ EMA pour Boom/Crash désactivés pour éviter le détachement du robot");
   }
   
   // Configurer le timer uniquement si l'initialisation est réussie
   if(!EventSetTimer(1))
   {
      Print("❌ ERREUR: Impossible de configurer le timer");
      return INIT_FAILED;
   }
   
   // Vérifier que tous les indicateurs sont correctement initialisés
   if(!CheckIndicators())
   {
      Print("❌ ERREUR: Échec de la vérification des indicateurs");
      if(InpRequireAllIndicators)
         return INIT_FAILED;
      Print("⚠️ Poursuite malgré les erreurs d'indicateurs");
   }
   
   Print("✅ Tous les indicateurs sont correctement initialisés");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Convertit le code de raison de désinitialisation en texte        |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reasonCode)
{
   switch(reasonCode)
   {
      case REASON_ACCOUNT:       return "Compte changé";
      case REASON_CHARTCHANGE:   return "Changement de graphique";
      case REASON_CHARTCLOSE:    return "Fermeture du graphique";
      case REASON_PARAMETERS:    return "Paramètres modifiés";
      case REASON_RECOMPILE:     return "Recompilation";
      case REASON_REMOVE:        return "Suppression de l'EA";
      case REASON_TEMPLATE:      return "Changement de modèle";
      case REASON_CLOSE:         return "Fermeture du terminal";
      case REASON_PROGRAM:       return "Arrêt programmé";
      default:                   return "Raison inconnue (" + IntegerToString(reasonCode) + ")";
   }
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation de l'expert                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   string reasonText = GetUninitReasonText(reason);
   Print("=== Désinitialisation d'AngelOfSpike ===");
   Print("Raison: ", reasonText);
   
   // Si l'arrêt est inattendu, enregistrer les détails
   if(reason != REASON_REMOVE && reason != REASON_PROGRAM && reason != REASON_RECOMPILE)
   {
      string alertMsg = "AngelOfSpike s'est arrêté de manière inattendue!\n";
      alertMsg += "Raison: " + reasonText + "\n";
      alertMsg += "Symbole: " + _Symbol + " Période: " + EnumToString(_Period) + "\n";
      alertMsg += "Heure: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      
      // Envoyer une alerte si activé
      if(InpShowNotification)
      {
         Alert(alertMsg);
         SendNotification(alertMsg);
      }
      
      // Enregistrer dans un fichier de log
      int handle = FileOpen("AngelOfSpike_Error.log", FILE_WRITE|FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, alertMsg);
         FileClose(handle);
      }
   }
   
   // Libérer les ressources des indicateurs techniques
   Print("Libération des ressources...");
   
   // RSI
   if(g_rsi1_handle != INVALID_HANDLE) {
      IndicatorRelease(g_rsi1_handle);
      g_rsi1_handle = INVALID_HANDLE;
   }
   
   if(g_rsi2_handle != INVALID_HANDLE) {
      IndicatorRelease(g_rsi2_handle);
      g_rsi2_handle = INVALID_HANDLE;
   }
   
   // VWAP
   if(g_vwap_handle != INVALID_HANDLE) {
      IndicatorRelease(g_vwap_handle);
      g_vwap_handle = INVALID_HANDLE;
   }
   
   // Supertrend
   if(g_supertrend_handle != INVALID_HANDLE) {
      IndicatorRelease(g_supertrend_handle);
      g_supertrend_handle = INVALID_HANDLE;
   }
   
   // TTM Squeeze
   if(g_squeeze_handle != INVALID_HANDLE) {
      IndicatorRelease(g_squeeze_handle);
      g_squeeze_handle = INVALID_HANDLE;
   }
   
   // Nettoyer les objets graphiques
   ClearAllDrawings();
   
   // Réinitialiser les compteurs
   g_supportLevelsCount = 0;
   g_resistanceLevelsCount = 0;
   
   EventKillTimer();
   // Clean HUD objects
   if(InpShowHUD)
   {
      // Clean main HUD objects (seulement les essentiels)
      string ids[6] = {"ANGEL_HUD_0","ANGEL_HUD_1","ANGEL_HUD_2","ANGEL_HUD_3","ANGEL_HUD_4","ANGEL_HUD_5"};
      for(int i=0;i<6;i++) if(ObjectFind(0, ids[i])>=0) ObjectDelete(0, ids[i]);
      // Clean Money Management objects
      string moneyIds[8] = {"MONEY_TITLE","MONEY_CAPITAL","MONEY_DAILY","MONEY_GLOBAL","MONEY_LOSS","MONEY_WINRATE","MONEY_STATS","MONEY_PERF"};
      for(int k=0;k<8;k++) if(ObjectFind(0, moneyIds[k])>=0) ObjectDelete(0, moneyIds[k]);
      
      
      // Clean Manual Trades objects
      string manualIds[6] = {"MANUAL_TITLE","MANUAL_SUMMARY","MANUAL_WARNING","MANUAL_1","MANUAL_2","MANUAL_3"};
      for(int k=0;k<6;k++) if(ObjectFind(0, manualIds[k])>=0) ObjectDelete(0, manualIds[k]);
      
      // Clean Spike Arrow objects
      if(g_arrowSymbol != "")
      {
         ObjectDelete(0, "SPIKE_ARROW_" + g_arrowSymbol);
      }
      
      // Clean API Trend Data objects
      string apiIds[7] = {"API_TITLE","API_DIRECTION","API_STRENGTH","API_CONFIDENCE","API_SPIKE","API_SIGNAL","API_TIME"};
      for(int k=0;k<7;k++) if(ObjectFind(0, apiIds[k])>=0) ObjectDelete(0, apiIds[k]);
   }
   // Release overlay indicators
   if(g_hEMA1!=INVALID_HANDLE) IndicatorRelease(g_hEMA1);
   if(g_hEMA2!=INVALID_HANDLE) IndicatorRelease(g_hEMA2);
   if(g_hEMA3!=INVALID_HANDLE) IndicatorRelease(g_hEMA3);
   if(g_hEMA4!=INVALID_HANDLE) IndicatorRelease(g_hEMA4);
   if(g_hEMA5!=INVALID_HANDLE) IndicatorRelease(g_hEMA5);
   if(g_hBB!=INVALID_HANDLE) IndicatorRelease(g_hBB);
   if(g_hEnv!=INVALID_HANDLE) IndicatorRelease(g_hEnv);
   if(g_hEMA20!=INVALID_HANDLE) IndicatorRelease(g_hEMA20);
   if(g_hEMA50!=INVALID_HANDLE) IndicatorRelease(g_hEMA50);
}

void OnTimer()
{
   if(!InpEnableTrading) return;
   
   // PROTECTION ANTI-DÉMARRAGE RAPIDE - Attendre 5 secondes avant le premier trade
   static datetime startupTime = 0;
   if(startupTime == 0) startupTime = TimeCurrent();
   if(TimeCurrent() - startupTime < 5)
   {
      if(TimeCurrent() - g_lastHud >= g_hudRefreshSec)
      {
         g_lastHud = TimeCurrent();
         DrawAngelHUD();
      }
      return; // Attendre 5 secondes avant de commencer le trading
   }
   
   // DÉSACTIVÉ - if(g_dayStopped) { if(TimeCurrent() - g_lastHud >= g_hudRefreshSec){ g_lastHud=TimeCurrent(); DrawAngelHUD(); } return; }
   if(!GlobalLossGuard()) return;
   
   // LOGS DE DIAGNOSTIC POUR SYSTÈME SPIKE M1 UNIQUE
   static datetime lastDiagnostic = 0;
   if(TimeCurrent() - lastDiagnostic >= 10) // Diagnostic toutes les 10 secondes
   {
      lastDiagnostic = TimeCurrent();
      int totalPositionsAll = PositionsTotal();
      int totalPositionsEA = CountOpenPositionsEA();
      int totalOrders = OrdersTotal();
      
      Print("🔍 SYSTÈME SPIKE M1 UNIQUE:");
      Print("   Trading activé: ", InpEnableTrading);
      Print("   Positions globales: ", totalPositionsAll, "/", InpMaxGlobalPositions);
      Print("   Positions EA: ", totalPositionsEA, "/", InpMaxGlobalPositions);
      Print("   Ordres en attente: ", totalOrders);
      Print("   Seuil probabilité M1: ", InpMinSpikeM1Probability, "%");
      Print("   Trades manuels: ", (InpAllowManualTrading ? "AUTORISÉS" : "DÉSACTIVÉS"));
   }
   
   // Vérifier le blocage de sécurité
   if(g_tradingBlocked)
   {
      if(TimeCurrent() >= g_blockUntil)
      {
         g_tradingBlocked = false;
         Print("✅ BLOCAGE LEVÉ - Trading reprend");
      }
      else
      {
         if(TimeCurrent() - g_lastHud >= g_hudRefreshSec)
         {
            g_lastHud = TimeCurrent();
            DrawAngelHUD();
         }
         return; // BLOQUER TOUT TRADING
      }
   }
   
   // DÉSACTIVÉ: Gestion dynamique des positions
   // AnalyzeAndModifyPositions();  // Désactivé pour ne plus modifier les positions ouvertes
   HandleAutoRepositioning();
   
   // DÉTECTION AUTOMATIQUE FC1 - Surveillance du clignotement
   if(IsFC1Blinking())
   {
      Print("🚨 FC1 CLIGNOTEMENT DÉTECTÉ!");
      
      // Obtenir la direction du signal FC1
      if(ObjectFind(0, "ANGEL_FC1") >= 0)
      {
         color fc1Color = (color)ObjectGetInteger(0, "ANGEL_FC1", OBJPROP_COLOR);
         bool isBuySignal = (fc1Color == clrLime);
         
         // Valider et exécuter le trade automatiquement
         if(ValidateFC1Signal(isBuySignal ? 0.001 : -0.001))
         {
            Print("🚨 FC1 CLIGNOTANT - DÉCLENCHEMENT AUTOMATIQUE DU TRADE");
            ExecuteFC1Trade(isBuySignal);
         }
      }
   }
   
   // FERMETURE IMMÉDIATE APRÈS SPIKE POUR BOOM/CRASH
   HandleBoomCrashSpikeExit();
   
   // SCALPING AUTOMATIQUE: Exécuter la stratégie de scalping
   ExecuteScalpingStrategy();
   
   // RÈGLE STRICTE: Vérifier et annuler les ordres multiples en premier
   if(!CheckAndCancelMultipleOrders()) return;
   
   // VÉRIFICATION D'URGENCE: Fermer immédiatement toutes les positions multiples
   EmergencyCloseAllMultiplePositions();
   
   // BLOCAGE PRÉVENTIF RENFORCÉ - Vérifier avant tout trading EA
   int totalPositionsEA = CountOpenPositionsEA();
   if(totalPositionsEA >= 2) 
   {
      if(TimeCurrent() - lastDiagnostic >= 5) 
      {
         Print("🚫 BLOCAGE EA: Maximum de positions EA atteint (", totalPositionsEA, "/2) - Trades manuels autorisés");
         lastDiagnostic = TimeCurrent();
      }
      // Ne pas return ici - continuer pour permettre les trades manuels
      // Le blocage se fera dans les fonctions de trading EA spécifiques
   }

   // Boom/Crash circuit breaker: if too many recent losses in window, pause trading globally for BC
   if(InpBCCircuitLosses>0 && InpBCCircuitPauseMin>0)
   {
      int recent=0; datetime now=TimeCurrent();
      for(int i=0;i<10;i++) if(g_bcLossTimestamps[i]>0 && now - g_bcLossTimestamps[i] <= InpBCCircuitWindowMin*60) recent++;
      if(recent >= InpBCCircuitLosses)
      {
         // Arm a global cooldown for BC symbols by setting cooldown for all tracked symbols
         for(int k=0;k<20;k++) if(g_bcCooldownSymbols[k]!="") g_bcSymbolCooldownUntil[k] = now + InpBCCircuitPauseMin*60;
      }
   }

   // NOUVELLE LOGIQUE UNIFIÉE - SYSTÈME SPIKE M1 UNIQUE
   // 1. Vérifier qu'aucune position n'existe (ULTRA-STRICT)
   int totalPositionsAll = PositionsTotal();
   if(totalPositionsAll >= InpMaxGlobalPositions)
   {
      if(TimeCurrent() - g_lastHud >= g_hudRefreshSec)
      {
         g_lastHud = TimeCurrent();
         DrawAngelHUD();
      }
      return; // BLOCAGE TOTAL - Aucune position autorisée
   }
   
   // 2. Scanner UN SEUL symbole à la fois pour probabilité M1
   string list = (InpOnlyCurrentSymbol ? _Symbol : InpAllowedSymbols);
   if(!InpOnlyCurrentSymbol && InpPrioritizeBoomCrash)
   {
      // Recomposer la liste pour mettre Boom/Crash en tête
      string syms[]; StringSplit(InpAllowedSymbols, ',', syms);
      string bc = ""; string others = "";
      for(int i=0;i<ArraySize(syms);i++)
      {
         string s = StringTrim(syms[i]);
         if(StringFind(s, "Boom")>=0 || StringFind(s, "Crash")>=0) bc = (StringLen(bc)>0? bc+","+s : s);
         else others = (StringLen(others)>0? others+","+s : s);
      }
      if(StringLen(bc)>0)
      {
         if(StringLen(others)>0) list = bc + "," + others; else list = bc;
      }
   }
   int start = 0;
   
   while(start < StringLen(list))
   {
      int comma = StringFind(list, ",", start);
      string sym;
      if(comma < 0)
      {
         sym = StringSubstr(list, start);
         start = StringLen(list);
      }
      else
      {
         sym = StringSubstr(list, start, comma - start);
         start = comma + 1;
      }
      
      // Trim
      while(StringLen(sym) > 0 && StringGetCharacter(sym, 0) == ' ')
         sym = StringSubstr(sym, 1);
      while(StringLen(sym) > 0 && StringGetCharacter(sym, StringLen(sym) - 1) == ' ')
         sym = StringSubstr(sym, 0, StringLen(sym) - 1);
      
      if(StringLen(sym) == 0) continue;
      if(!SymbolSelect(sym, true)) continue;

      // Refresh SR pour analyse (M30 uniquement)
      DetectSRForTF(sym, PERIOD_M30, InpSRLookbackBars, g_srLevelsM30, g_srNM30);
      if(InpDrawSRZones && sym == _Symbol) DrawSRZones();
      if(sym == _Symbol) DrawOverlays(sym);
      
      // 3. Calculer probabilité M1 unifiée
      int direction = 0;
      double probability = CalculateSpikeM1Probability(sym, direction);
      
      // Seuil spécifique Boom/Crash
      bool isBC = (StringFind(sym, "Boom")>=0 || StringFind(sym, "Crash")>=0);
      double threshold = isBC ? InpMinProbBoomCrash : InpMinSpikeM1Probability;
      
      // 4. Si probabilité >= seuil, enregistrer un signal en attente (deux temps)
      if(probability >= threshold && g_pendingSymbol == "" && CountOpenPositionsEA() == 0)
      {
         g_pendingSymbol = sym;
         g_pendingDirection = direction;
         g_pendingProbability = probability;
         g_pendingTime = TimeCurrent();
         Print("🕒 SIGNAL EN ATTENTE: ", sym, " - ", DoubleToString(probability, 1), "% (seuil: ", threshold, "%), confirmation dans ", InpSignalConfirmDelaySec, "s");
         break; // on ne marque qu'un seul signal en attente
      }
      else if(probability > 0.0)
      {
         // Log des probabilités insuffisantes (debug uniquement)
         if(InpDebug && TimeCurrent() - g_lastScan >= 10)
         {
            Print("📊 Probabilité insuffisante: ", sym, " - ", DoubleToString(probability, 1), "% (min: ", InpMinSpikeM1Probability, "%");
         }
      }
   }
   
   // Exécution différée après confirmation
   if(g_pendingSymbol != "" && CountOpenPositionsEA() == 0)
   {
      if(TimeCurrent() - g_pendingTime >= InpSignalConfirmDelaySec)
      {
         int confirmDir = 0;
         double confirmProb = CalculateSpikeM1Probability(g_pendingSymbol, confirmDir);
         
         if(confirmProb >= InpRecheckMinProbability && confirmDir == g_pendingDirection)
         {
            Print("✅ SIGNAL CONFIRMÉ: ", g_pendingSymbol, " - ", DoubleToString(confirmProb, 1), "%");
            if(ExecuteSingleMarketOrder(g_pendingSymbol, confirmDir, confirmProb))
            {
               Print("🚀 EXÉCUTION APRÈS CONFIRMATION");
          }
          else
          {
               Print("❌ ÉCHEC EXÉCUTION APRÈS CONFIRMATION sur ", g_pendingSymbol);
            }
         }
         else
         {
            Print("🛑 SIGNAL ANNULÉ: ", g_pendingSymbol, " - Prob: ", DoubleToString(confirmProb, 1), "% (min: ", InpRecheckMinProbability, "%)");
         }
         // reset pending in all cases
         g_pendingSymbol = "";
         g_pendingDirection = 0;
         g_pendingProbability = 0.0;
         g_pendingTime = 0;
      }
   }

   // 5. Refresh HUD après scanning
   if(TimeCurrent() - g_lastHud >= g_hudRefreshSec)
   {
      g_lastHud = TimeCurrent();
      DrawAngelHUD();
   }

   // ===================================================================
   // GESTION AUTOMATIQUE DES POSITIONS SPIKE
   // ===================================================================
   
   // SPIKE SCALPING BOOM/CRASH - Fermer sur spike et rentrer si conditions bonnes
   HandleBoomCrashSpikeScalping();
   // AUTO-CLOSE pour indices non Boom/Crash à +2$ / -2$ (paramétrable)
   ManageNonBoomCrashAutoClose();
   
   // Re-entry Volatility après délai (toujours dans le sens de la tendance MTF gate)
   if(InpEnableVolScalp)
   {
      for(int i=0;i<20;i++)
      {
         if(g_volSymbols[i]=="") continue;
         if(TimeCurrent() - g_volLastCloseTime[i] < InpVolReentryDelaySec) continue;
         string vs = g_volSymbols[i];
         // Vérifier qu'aucune position EA sur ce symbole
         bool hasEA=false; for(int p=PositionsTotal()-1;p>=0;p--){ ulong tk=PositionGetTicket(p); if(!PositionSelectByTicket(tk)) continue; if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue; if(PositionGetString(POSITION_SYMBOL)==vs){ hasEA=true; break; } }
         if(hasEA) { g_volSymbols[i]=""; continue; }
         
         // Trader la tendance: utiliser TrendGateDirection
         int trendDir = TrendGateDirection(vs);
         if(trendDir==0){ g_volSymbols[i]=""; continue; }
         int dir = (trendDir>0)? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         
         int reDir=0; double prob = CalculateSpikeM1Probability(vs, reDir);
         if(reDir!=dir) { g_volSymbols[i]=""; continue; }
         if(prob < InpMinSpikeM1Probability) { g_volSymbols[i]=""; continue; }
         
         if(ExecuteSingleMarketOrder(vs, dir, prob))
         {
            Print("🔁 VOL re-entry exécuté sur ", vs, " dir=", (dir==POSITION_TYPE_BUY?"BUY":"SELL"), " prob=", DoubleToString(prob,1), "%");
         }
         g_volSymbols[i]=""; // consommer le slot
      }
   }
   
   // Gestion automatique des positions - Fermer à -3$ et +5$ (DÉSACTIVÉE)
   // ManageOpenPositions(); // DÉSACTIVÉ - Robot autonome
   
   // FERMETURE IMMÉDIATE APRÈS SPIKE CAPTURÉ (DÉSACTIVÉE)
   // ClosePositionsAfterSpikeCapture(); // DÉSACTIVÉ - Robot autonome
   
   // FERMETURE AUTOMATIQUE DES POSITIONS EMA APRÈS DÉLAI (DÉSACTIVÉE)
   // CloseEMAPositionsAfterDelay(); // DÉSACTIVÉ - Robot autonome
   
   // MISE À JOUR DE L'ANIMATION DE LA FLÈCHE CLIGNOTANTE
   UpdateSpikeArrowBlinking();

   // Refresh HUD
   if(TimeCurrent() - g_lastHud >= g_hudRefreshSec)
   {
      g_lastHud = TimeCurrent();
      DrawAngelHUD();
      
      // Afficher les données de l'API sur le graphique
      DisplayTrendDataOnChart(_Symbol);
   }

   // GESTION STRICTE DES POSITIONS OUVERTES (DÉSACTIVÉE)
   // Le robot est maintenant autonome et garde ses positions
   // Les positions seront fermées uniquement par SL/TP ou gestion manuelle
   if(InpAutoClosePositions)
   {
      // ManageOpenPositionsStrict(); // DÉSACTIVÉ - Robot autonome
   }
   
   // VÉRIFICATION FINALE DE SÉCURITÉ: S'assurer qu'on n'a jamais plus de 2 positions EA
   int finalPositionCountEA = CountOpenPositionsEA();
   if(finalPositionCountEA > 2)
   {
      Print("🚨 URGENCE: Détection de ", finalPositionCountEA, " positions EA (limite: 2) - Blocage EA activé");
      // Ne pas faire de trades EA jusqu'à ce que le nombre redescende
      return;
   }

   // Daily session controls
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double pnlPct = (g_startBalanceToday>0.0)? (bal - g_startBalanceToday)/g_startBalanceToday*100.0 : 0.0;
   // DÉSACTIVÉ - Arrêt quotidien
   // if(pnlPct >= InpDailyTargetPercent || pnlPct <= -MathAbs(InpDailyDrawdownPercent) || g_tradesToday >= InpMaxTradesPerDay || g_consecLosses >= InpMaxConsecutiveLosses)
   // {
   //    g_dayStopped = true;
   // }
}

// Calcule le score de confiance pour un signal donné (VERSION AMÉLIORÉE)
double CalculateSignalConfidence(const string symbol, int direction)
{
   // --- RÈGLE 1: DIRECTION OBLIGATOIRE POUR BOOM/CRASH ---
   if(IsBoomCrashIndex(symbol))
   {
      if(StringFind(symbol, "Boom") >= 0 && direction != POSITION_TYPE_BUY) return 0.0;
      if(StringFind(symbol, "Crash") >= 0 && direction != POSITION_TYPE_SELL) return 0.0;
      
      // Pour Boom/Crash, on utilise leur propre modèle de confiance
      MqlRates rates[];
      CopyRates(symbol, PERIOD_M1, 0, 2, rates);
      double atr = iATR(symbol, PERIOD_M1, 14);
      double range = rates[0].high - rates[0].low;
      double wickRatio = (rates[0].high - rates[0].low) > 0 ? (MathMax(rates[0].high - rates[0].close, rates[0].close - rates[0].low)) / (rates[0].high - rates[0].low) : 0;
      return CalculateBoomCrashConfidence(symbol, atr, range, wickRatio, direction);
   }

   // --- RÈGLE 2: ANALYSE MULTI-FACTEURS POUR LES AUTRES SYMBOLES ---
   double confidence = 50.0; // Score de base neutre

   // FACTEUR 1: Tendance Multi-Timeframe (Poids: +25 / -40)
   if(InpUseMTFGate)
   {
      int trendDir = TrendGateDirection(symbol);
      if(direction == POSITION_TYPE_BUY && trendDir > 0)
      {
         confidence += 25.0; // Tendance alignée, bonus fort
      }
      else if(direction == POSITION_TYPE_SELL && trendDir < 0)
      {
         confidence += 25.0; // Tendance alignée, bonus fort
      }
      else if (trendDir != 0)
      {
         confidence -= 40.0; // Contre-tendance, pénalité très forte
      }
   }

   // FACTEUR 2: Proximité Support/Résistance (Poids: +15)
   if(InpEnableSR && IsNearAnySR(symbol))
   {
      // Si on achète près d'un support ou vend près d'une résistance
      // (Note: IsNearAnySR ne différencie pas, mais la proximité est déjà un bon indice)
      confidence += 15.0;
   }

   // FACTEUR 3: Signaux ICT (Order Block + OTE) (Poids: +30)
   if(InpEnableICT)
   {
      OrderBlock ob[3];
      int n = BuildRecentOrderBlocks(symbol, InpICT_TF, InpICTLookbackBars, InpSwingLen, InpMinOBBodyATR, ob, 3);
      if(n > 0)
      {
         for(int i = 0; i < n; i++)
         {
            if(ob[i].valid && ICTPriceInOBOTE(symbol, ob[i]))
            {
               // Si on achète dans un OB haussier ou vend dans un OB baissier
               if((direction == POSITION_TYPE_BUY && ob[i].isBull) || (direction == POSITION_TYPE_SELL && !ob[i].isBull))
               {
                  confidence += 30.0; // Signal ICT très fort
                  break;
               }
            }
         }
      }
   }
   
   // Normaliser le score pour qu'it reste entre 0 et 100
   return MathMax(0.0, MathMin(100.0, confidence));
}

//+------------------------------------------------------------------+
//| Détecte un mouvement de ciseaux (pinces)                         |
//+------------------------------------------------------------------+
int DetectScissorPattern(const string symbol, double &patternStrength)
{
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 3, rates) < 3) return 0;
   
   // Calcul des tailles des bougies
   double body1 = MathAbs(rates[2].close - rates[2].open);
   double wick1_upper = rates[2].high - MathMax(rates[2].open, rates[2].close);
   double wick1_lower = MathMin(rates[2].open, rates[2].close) - rates[2].low;
   
   double body2 = MathAbs(rates[1].close - rates[1].open);
   double wick2_upper = rates[1].high - MathMax(rates[1].open, rates[1].close);
   double wick2_lower = MathMin(rates[1].open, rates[1].close) - rates[1].low;
   
   // Ciseaux montants (marteau + étoile filante haussière)
   if(wick1_lower > body1 * 2 && wick1_upper < body1 * 0.5 &&  // Marteau
      wick2_upper > body2 * 2 && wick2_lower < body2 * 0.5)    // Étoile filante haussière
   {
      patternStrength = 80.0; // Forte probabilité de continuation haussière
      return 1; // Signal d'achat
   }
   
   // Ciseaux descendants (étoile filante baissière + marteau inversé)
   if(wick1_upper > body1 * 2 && wick1_lower < body1 * 0.5 &&  // Étoile filante baissière
      wick2_lower > body2 * 2 && wick2_upper < body2 * 0.5)    // Marteau inversé
   {
      patternStrength = 80.0; // Forte probabilité de continuation baissière
      return -1; // Signal de vente
   }
   
   return false; // Pas de signal
}

//+------------------------------------------------------------------+
//| Retourne une description lisible d'une erreur MQL5               |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
{
   switch(error_code)
   {
      case 0:   return "ERREUR_INCONNUE";
      case 1:   return "ERREUR_PAS_INITIALISE";
      case 2:   return "ERREUR_MAUVAIS_PARAMETRE";
      case 3:   return "ERREUR_MAUVAIS_APPEL";
      case 4:   return "ERREUR_TROP_DONNEES";
      case 5:   return "ERREUR_MAUVAIS_FORMAT";
      case 6:   return "ERREUR_PAS_ASSEZ_DE_MEMOIRE";
      case 7:   return "ERREUR_INDICATEUR_INCONNU";
      case 8:   return "ERREUR_FIN_DE_FICHIER";
      case 9:   return "ERREUR_FICHIER_ERREUR";
      case 10:  return "ERREUR_MAUVAIS_NOM_FICHIER";
      case 11:  return "ERREUR_TROP_DE_FICHIERS_OUVERTS";
      case 12:  return "ERREUR_ACCES_REFUSE";
      case 13:  return "ERREUR_FICHIER_INVALIDE";
      case 14:  return "ERREUR_ECRITURE_FICHIER";
      case 15:  return "ERREUR_ERREUR_LECTURE_FICHIER";
      case 16:  return "ERREUR_MAUVAIS_TERMINATEUR";
      case 17:  return "ERREUR_MAUVAIS_INDEX";
      case 18:  return "ERREUR_PAS_DE_DONNEES";
      case 19:  return "ERREUR_TEMPS_INVALIDE";
      case 20:  return "ERREUR_POSITION_HORS_LIMITE";
      case 21:  return "ERREUR_PAS_ASSEZ_DE_MEMOIRE_POUR_TEMPORAIRE";
      case 22:  return "ERREUR_BLOQUE";
      case 23:  return "ERREUR_FONCTION_NON_AUTORISEE";
      case 24:  return "ERREUR_SIGNAL";
      case 25:  return "ERREUR_ERREUR_DE_MEMOIRE";
      case 26:  return "ERREUR_FONCTION_INDEFINIE";
      case 27:  return "ERREUR_FONCTION_NON_SUPPORTEE";
      case 28:  return "ERREUR_TERMINE";
      case 29:  return "ERREUR_EXECUTION";
      case 30:  return "ERREUR_PAS_D_ORDRE";
      case 31:  return "ERREUR_MAUVAIS_ORDRE";
      case 32:  return "ERREUR_ORDRE_NON_TROUVE";
      case 33:  return "ERREUR_ORDRE_DEJA_EXISTANT";
      case 34:  return "ERREUR_ORDRE_NON_MODIFIE";
      case 35:  return "ERREUR_ERREUR_DE_SERVEUR";
      case 36:  return "ERREUR_COMMANDE_ERREUR";
      case 37:  return "ERREUR_MAUVAIS_ARGUMENTS";
      case 38:  return "ERREUR_ERREUR_DE_TRADING";
      case 39:  return "ERREUR_ERREUR_DE_COMPTE";
      case 40:  return "ERREUR_ERREUR_DE_MARCHANDISE";
      case 41:  return "ERREUR_ERREUR_DE_DEVIS";
      case 42:  return "ERREUR_ERREUR_DE_REQUETE";
      case 43:  return "ERREUR_ERREUR_DE_REPONSE";
      case 44:  return "ERREUR_ERREUR_DE_COMMANDE";
      case 45:  return "ERREUR_ERREUR_DE_POSITION";
      case 46:  return "ERREUR_ERREUR_DE_DEAL";
      case 47:  return "ERREUR_ERREUR_DE_MARCHANDISE_INCONNUE";
      case 48:  return "ERREUR_ERREUR_DE_DEVIS_INCONNU";
      case 49:  return "ERREUR_ERREUR_DE_REQUETE_INCONNUE";
      case 50:  return "ERREUR_ERREUR_DE_REPONSE_INCONNUE";
      case 51:  return "ERREUR_ERREUR_DE_COMMANDE_INCONNUE";
      case 52:  return "ERREUR_ERREUR_DE_POSITION_INCONNUE";
      case 53:  return "ERREUR_ERREUR_DE_DEAL_INCONNU";
      case 54:  return "ERREUR_ERREUR_DE_MARCHANDISE_DESACTIVEE";
      case 55:  return "ERREUR_ERREUR_DE_DEVIS_DESACTIVE";
      case 56:  return "ERREUR_ERREUR_DE_REQUETE_DESACTIVEE";
      case 57:  return "ERREUR_ERREUR_DE_REPONSE_DESACTIVEE";
      case 58:  return "ERREUR_ERREUR_DE_COMMANDE_DESACTIVEE";
      case 59:  return "ERREUR_ERREUR_DE_POSITION_DESACTIVEE";
      case 60:  return "ERREUR_ERREUR_DE_DEAL_DESACTIVE";
      case 61:  return "ERREUR_ERREUR_DE_MARCHANDISE_INDISPONIBLE";
      case 62:  return "ERREUR_ERREUR_DE_DEVIS_INDISPONIBLE";
      case 63:  return "ERREUR_ERREUR_DE_REQUETE_INDISPONIBLE";
      case 64:  return "ERREUR_ERREUR_DE_REPONSE_INDISPONIBLE";
      case 65:  return "ERREUR_ERREUR_DE_COMMANDE_INDISPONIBLE";
      case 66:  return "ERREUR_ERREUR_DE_POSITION_INDISPONIBLE";
      case 67:  return "ERREUR_ERREUR_DE_DEAL_INDISPONIBLE";
      case 68:  return "ERREUR_ERREUR_DE_MARCHANDISE_INVALIDE";
      case 69:  return "ERREUR_ERREUR_DE_DEVIS_INVALIDE";
      case 70:  return "ERREUR_ERREUR_DE_REQUETE_INVALIDE";
      case 71:  return "ERREUR_ERREUR_DE_REPONSE_INVALIDE";
      case 72:  return "ERREUR_ERREUR_DE_COMMANDE_INVALIDE";
      case 73:  return "ERREUR_ERREUR_DE_POSITION_INVALIDE";
      case 74:  return "ERREUR_ERREUR_DE_DEAL_INVALIDE";
      case 75:  return "ERREUR_ERREUR_DE_MARCHANDISE_VERROUILLEE";
      case 76:  return "ERREUR_ERREUR_DE_DEVIS_VERROUILLE";
      case 77:  return "ERREUR_ERREUR_DE_REQUETE_VERROUILLEE";
      case 78:  return "ERREUR_ERREUR_DE_REPONSE_VERROUILLEE";
      case 79:  return "ERREUR_ERREUR_DE_COMMANDE_VERROUILLEE";
      case 80:  return "ERREUR_ERREUR_DE_POSITION_VERROUILLEE";
      case 81:  return "ERREUR_ERREUR_DE_DEAL_VERROUILLE";
      case 82:  return "ERREUR_ERREUR_DE_MARCHANDISE_OCCUPEE";
      case 83:  return "ERREUR_ERREUR_DE_DEVIS_OCCUPE";
      case 84:  return "ERREUR_ERREUR_DE_REQUETE_OCCUPEE";
      case 85:  return "ERREUR_ERREUR_DE_REPONSE_OCCUPEE";
      case 86:  return "ERREUR_ERREUR_DE_COMMANDE_OCCUPEE";
      case 87:  return "ERREUR_ERREUR_DE_POSITION_OCCUPEE";
      case 88:  return "ERREUR_ERREUR_DE_DEAL_OCCUPE";
      case 89:  return "ERREUR_ERREUR_DE_MARCHANDISE_TEMPORAIRE";
      case 90:  return "ERREUR_ERREUR_DE_DEVIS_TEMPORAIRE";
      case 91:  return "ERREUR_ERREUR_DE_REQUETE_TEMPORAIRE";
      case 92:  return "ERREUR_ERREUR_DE_REPONSE_TEMPORAIRE";
      case 93:  return "ERREUR_ERREUR_DE_COMMANDE_TEMPORAIRE";
      case 94:  return "ERREUR_ERREUR_DE_POSITION_TEMPORAIRE";
      case 95:  return "ERREUR_ERREUR_DE_DEAL_TEMPORAIRE";
      case 96:  return "ERREUR_ERREUR_DE_MARCHANDISE_INATTENDUE";
      case 97:  return "ERREUR_ERREUR_DE_DEVIS_INATTENDU";
      case 98:  return "ERREUR_ERREUR_DE_REQUETE_INATTENDUE";
      case 99:  return "ERREUR_ERREUR_DE_REPONSE_INATTENDUE";
      case 100: return "ERREUR_ERREUR_DE_COMMANDE_INATTENDUE";
      case 101: return "ERREUR_ERREUR_DE_POSITION_INATTENDUE";
      case 102: return "ERREUR_ERREUR_DE_DEAL_INATTENDU";
      case 103: return "ERREUR_ERREUR_DE_MARCHANDISE_INCONNUE_2";
      case 104: return "ERREUR_ERREUR_DE_DEVIS_INCONNU_2";
      case 105: return "ERREUR_ERREUR_DE_REQUETE_INCONNUE_2";
      case 106: return "ERREUR_ERREUR_DE_REPONSE_INCONNUE_2";
      case 107: return "ERREUR_ERREUR_DE_COMMANDE_INCONNUE_2";
      case 108: return "ERREUR_ERREUR_DE_POSITION_INCONNUE_2";
      case 109: return "ERREUR_ERREUR_DE_DEAL_INCONNU_2";
      case 110: return "ERREUR_ERREUR_DE_MARCHANDISE_DESACTIVEE_2";
      case 111: return "ERREUR_ERREUR_DE_DEVIS_DESACTIVE_2";
      case 112: return "ERREUR_ERREUR_DE_REQUETE_DESACTIVEE_2";
      case 113: return "ERREUR_ERREUR_DE_REPONSE_DESACTIVEE_2";
      case 114: return "ERREUR_ERREUR_DE_COMMANDE_DESACTIVEE_2";
      case 115: return "ERREUR_ERREUR_DE_POSITION_DESACTIVEE_2";
      case 116: return "ERREUR_ERREUR_DE_DEAL_DESACTIVE_2";
      case 117: return "ERREUR_ERREUR_DE_MARCHANDISE_INDISPONIBLE_2";
      case 118: return "ERREUR_ERREUR_DE_DEVIS_INDISPONIBLE_2";
      case 119: return "ERREUR_ERREUR_DE_REQUETE_INDISPONIBLE_2";
      case 120: return "ERREUR_ERREUR_DE_REPONSE_INDISPONIBLE_2";
      case 121: return "ERREUR_ERREUR_DE_COMMANDE_INDISPONIBLE_2";
      case 122: return "ERREUR_ERREUR_DE_POSITION_INDISPONIBLE_2";
      case 123: return "ERREUR_ERREUR_DE_DEAL_INDISPONIBLE_2";
      case 124: return "ERREUR_ERREUR_DE_MARCHANDISE_INVALIDE_2";
      case 125: return "ERREUR_ERREUR_DE_DEVIS_INVALIDE_2";
      case 126: return "ERREUR_ERREUR_DE_REQUETE_INVALIDE_2";
      case 127: return "ERREUR_ERREUR_DE_REPONSE_INVALIDE_2";
      case 128: return "ERREUR_ERREUR_DE_COMMANDE_INVALIDE_2";
      case 129: return "ERREUR_ERREUR_DE_POSITION_INVALIDE_2";
      case 130: return "ERREUR_ERREUR_DE_DEAL_INVALIDE_2";
      case 131: return "ERREUR_ERREUR_DE_MARCHANDISE_VERROUILLEE_2";
      case 132: return "ERREUR_ERREUR_DE_DEVIS_VERROUILLE_2";
      case 133: return "ERREUR_ERREUR_DE_REQUETE_VERROUILLEE_2";
      case 134: return "ERREUR_ERREUR_DE_REPONSE_VERROUILLEE_2";
      case 135: return "ERREUR_ERREUR_DE_COMMANDE_VERROUILLEE_2";
      case 136: return "ERREUR_ERREUR_DE_POSITION_VERROUILLEE_2";
      case 137: return "ERREUR_ERREUR_DE_DEAL_VERROUILLE_2";
      case 138: return "ERREUR_ERREUR_DE_MARCHANDISE_OCCUPEE_2";
      case 139: return "ERREUR_ERREUR_DE_DEVIS_OCCUPE_2";
      case 140: return "ERREUR_ERREUR_DE_REQUETE_OCCUPEE_2";
      case 141: return "ERREUR_ERREUR_DE_REPONSE_OCCUPEE_2";
      case 142: return "ERREUR_ERREUR_DE_COMMANDE_OCCUPEE_2";
      case 143: return "ERREUR_ERREUR_DE_POSITION_OCCUPEE_2";
      case 144: return "ERREUR_ERREUR_DE_DEAL_OCCUPE_2";
      case 145: return "ERREUR_ERREUR_DE_MARCHANDISE_TEMPORAIRE_2";
      case 146: return "ERREUR_ERREUR_DE_DEVIS_TEMPORAIRE_2";
      case 147: return "ERREUR_ERREUR_DE_REQUETE_TEMPORAIRE_2";
      case 148: return "ERREUR_ERREUR_DE_REPONSE_TEMPORAIRE_2";
      case 149: return "ERREUR_ERREUR_DE_COMMANDE_TEMPORAIRE_2";
      case 150: return "ERREUR_ERREUR_DE_POSITION_TEMPORAIRE_2";
      case 151: return "ERREUR_ERREUR_DE_DEAL_TEMPORAIRE_2";
      case 152: return "ERREUR_ERREUR_DE_MARCHANDISE_INATTENDUE_2";
      case 153: return "ERREUR_ERREUR_DE_DEVIS_INATTENDU_2";
      case 154: return "ERREUR_ERREUR_DE_REQUETE_INATTENDUE_2";
      case 155: return "ERREUR_ERREUR_DE_REPONSE_INATTENDUE_2";
      case 156: return "ERREUR_ERREUR_DE_COMMANDE_INATTENDUE_2";
      case 157: return "ERREUR_ERREUR_DE_POSITION_INATTENDUE_2";
      case 158: return "ERREUR_ERREUR_DE_DEAL_INATTENDU_2";
      case 159: return "ERREUR_ERREUR_DE_MARCHANDISE_INCONNUE_3";
      case 160: return "ERREUR_ERREUR_DE_DEVIS_INCONNU_3";
      case 161: return "ERREUR_ERREUR_DE_REQUETE_INCONNUE_3";
      case 162: return "ERREUR_ERREUR_DE_REPONSE_INCONNUE_3";
      case 163: return "ERREUR_ERREUR_DE_COMMANDE_INCONNUE_3";
      case 164: return "ERREUR_ERREUR_DE_POSITION_INCONNUE_3";
      case 165: return "ERREUR_ERREUR_DE_DEAL_INCONNU_3";
      case 4000: return "ERREUR_ERREUR_INTERNE";
      case 4001: return "ERREUR_ERREUR_INTERNE_DU_RESEAU";
      case 4002: return "ERREUR_ERREUR_INTERNE_DU_SERVEUR";
      case 4003: return "ERREUR_ERREUR_INTERNE_DU_CLIENT";
      case 4004: return "ERREUR_ERREUR_INTERNE_DE_LA_BASE_DE_DONNEES";
      case 4005: return "ERREUR_ERREUR_INTERNE_DU_FICHIER";
      case 4006: return "ERREUR_ERREUR_INTERNE_DE_LA_MEMOIRE";
      case 4007: return "ERREUR_ERREUR_INTERNE_DU_PROCESSUS";
      case 4008: return "ERREUR_ERREUR_INTERNE_DU_THREAD";
      case 4009: return "ERREUR_ERREUR_INTERNE_DU_SEMAPHORE";
      case 4010: return "ERREUR_ERREUR_INTERNE_DU_MUTEX";
      case 4011: return "ERREUR_ERREUR_INTERNE_DE_LA_FILE_D_ATTENTE";
      case 4012: return "ERREUR_ERREUR_INTERNE_DU_TEMPS";
      case 4013: return "ERREUR_ERREUR_INTERNE_DE_LA_DATE";
      case 4014: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_INTROUVABLE";
      case 4015: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_OUVERT";
      case 4016: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_FERME";
      case 4017: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_OUVERT";
      case 4018: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_EN_LECTURE";
      case 4019: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_EN_ECRITURE";
      case 4020: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_EN_LECTURE";
      case 4021: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_EN_ECRITURE";
      case 4022: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_OUVERT_EN_LECTURE";
      case 4023: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_OUVERT_EN_ECRITURE";
      case 4024: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE";
      case 4025: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE";
      case 4026: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_EXISTANT";
      case 4027: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_EXISTANT";
      case 4028: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_SUPPRIME";
      case 4029: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_SUPPRIME";
      case 4030: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_DEPLACE";
      case 4031: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_DEPLACE";
      case 4032: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_RENOMME";
      case 4033: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_RENOMME";
      case 4034: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_COPIE";
      case 4035: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_COPIE";
      case 4036: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_VIDE";
      case 4037: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_VIDE";
      case 4038: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_PLEIN";
      case 4039: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_PLEIN";
      case 4040: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_PROCESSUS";
      case 4041: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_PROCESSUS";
      case 4042: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_THREAD";
      case 4043: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_THREAD";
      case 4044: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UNE_AUTRE_APPLICATION";
      case 4045: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UNE_AUTRE_APPLICATION";
      case 4046: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_UTILISATEUR";
      case 4047: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_UTILISATEUR";
      case 4048: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_COMPTE";
      case 4049: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_COMPTE";
      case 4050: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_ORDINATEUR";
      case 4051: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_ORDINATEUR";
      case 4052: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_RESEAU";
      case 4053: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_RESEAU";
      case 4054: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_SERVEUR";
      case 4055: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_SERVEUR";
      case 4056: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_CLIENT";
      case 4057: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_CLIENT";
      case 4058: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_UTILISATEUR_OU_GROUPE";
      case 4059: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_UTILISATEUR_OU_GROUPE";
      case 4060: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_DEJA_UTILISE_PAR_UN_AUTRE_PROCESSUS_OU_THREAD";
      case 4061: return "ERREUR_ERREUR_INTERNE_DU_FICHIER_NON_UTILISE_PAR_UN_AUTRE_PROCESSUS_OU_THREAD";
      case 10001: return "ERREUR_ERREUR_DE_TRADING_INCONNUE";
      case 10002: return "ERREUR_ERREUR_DE_TRADING_INVALIDE";
      case 10003: return "ERREUR_ERREUR_DE_TRADING_DESACTIVEE";
      case 10004: return "ERREUR_ERREUR_DE_TRADING_NON_AUTORISEE";
      case 10005: return "ERREUR_ERREUR_DE_TRADING_OCCUPEE";
      case 10006: return "ERREUR_ERREUR_DE_TRADING_TIMEOUT";
      case 10007: return "ERREUR_ERREUR_DE_TRADING_DEJA_EN_COURS";
      case 10008: return "ERREUR_ERREUR_DE_TRADING_PAS_DE_REPONSE";
      case 10009: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_PERDUE";
      case 10010: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_REFUSEE";
      case 10011: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_TIMEOUT";
      case 10012: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE";
      case 10013: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE";
      case 10014: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_FERMEE";
      case 10015: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_FERMEE";
      case 10016: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_UTILISEE";
      case 10017: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_UTILISEE";
      case 10018: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ACTIVE";
      case 10019: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ACTIVE";
      case 10020: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_INACTIVE";
      case 10021: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_INACTIVE";
      case 10022: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_CONNECTEE";
      case 10023: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_CONNECTEE";
      case 10024: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_DECONNECTEE";
      case 10025: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_DECONNECTEE";
      case 10026: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_RECONNECTEE";
      case 10027: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_RECONNECTEE";
      case 10028: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_RECONNUE";
      case 10029: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_RECONNUE";
      case 10030: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_RETABLIE";
      case 10031: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_RETABLIE";
      case 10032: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_ET_AUTORISEE";
      case 10033: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_OU_NON_AUTORISEE";
      case 10034: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_MAIS_NON_AUTORISEE";
      case 10035: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_MAIS_AUTORISEE";
      case 10036: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_ET_AUTORISEE_MAIS_NON_UTILISEE";
      case 10037: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_OU_NON_AUTORISEE_OU_DEJA_UTILISEE";
      case 10038: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_MAIS_NON_AUTORISEE_OU_DEJA_UTILISEE";
      case 10039: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_MAIS_AUTORISEE_ET_DEJA_UTILISEE";
      case 10040: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_ET_AUTORISEE_MAIS_DEJA_UTILISEE";
      case 10041: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_OU_NON_AUTORISEE_OU_NON_UTILISEE";
      case 10042: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_MAIS_NON_AUTORISEE_ET_NON_UTILISEE";
      case 10043: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_MAIS_AUTORISEE_ET_NON_UTILISEE";
      case 10044: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_ET_AUTORISEE_MAIS_NON_UTILISEE_2";
      case 10045: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_OU_NON_AUTORISEE_OU_DEJA_UTILISEE_2";
      case 10046: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_MAIS_NON_AUTORISEE_OU_DEJA_UTILISEE_2";
      case 10047: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_MAIS_AUTORISEE_ET_DEJA_UTILISEE_2";
      case 10048: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_ET_AUTORISEE_MAIS_DEJA_UTILISEE_2";
      case 10049: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_OU_NON_AUTORISEE_OU_NON_UTILISEE_2";
      case 10050: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_MAIS_NON_AUTORISEE_ET_NON_UTILISEE_2";
      case 10051: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_MAIS_AUTORISEE_ET_NON_UTILISEE_2";
      case 10052: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_ET_AUTORISEE_MAIS_NON_UTILISEE_3";
      case 10053: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_OU_NON_AUTORISEE_OU_DEJA_UTILISEE_3";
      case 10054: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_MAIS_NON_AUTORISEE_OU_DEJA_UTILISEE_3";
      case 10055: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_MAIS_AUTORISEE_ET_DEJA_UTILISEE_3";
      case 10056: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_ET_AUTORISEE_MAIS_DEJA_UTILISEE_3";
      case 10057: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_OU_NON_AUTORISEE_OU_NON_UTILISEE_3";
      case 10058: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_DEJA_ETABLIE_MAIS_NON_AUTORISEE_ET_NON_UTILISEE_3";
      case 10059: return "ERREUR_ERREUR_DE_TRADING_CONNEXION_NON_ETABLIE_MAIS_AUTORISEE_ET_NON_UTILISEE_3";
      default:   return "ERREUR_INCONNUE";
   }
}

//+------------------------------------------------------------------+
//| Analyse la tendance du marché sur plusieurs timeframes           |
//+------------------------------------------------------------------+
struct TrendAnalysis {
   double strength;  // Force de la tendance (0-100)
   int direction;    // 1 = haussier, -1 = baissier, 0 = neutre
   string summary;   // Résumé de l'analyse
};

TrendAnalysis AnalyzeMarketTrend(const string symbol) {
   TrendAnalysis result = {0};
   int totalBullish = 0;
   int totalBearish = 0;
   int totalFrames = 0;
   
   // Tableau des timeframes à analyser
   ENUM_TIMEFRAMES timeframes[3] = {PERIOD_M15, PERIOD_H1, PERIOD_H4};
   
   for(int i = 0; i < 3; i++) {
      // Récupérer les données des moyennes mobiles
      int ema20 = iMA(symbol, timeframes[i], 20, 0, MODE_EMA, PRICE_CLOSE);
      int ema50 = iMA(symbol, timeframes[i], 50, 0, MODE_EMA, PRICE_CLOSE);
      int ema200 = iMA(symbol, timeframes[i], 200, 0, MODE_EMA, PRICE_CLOSE);
      
      double ema20_vals[3], ema50_vals[3], ema200_vals[3];
      
      if(CopyBuffer(ema20, 0, 0, 3, ema20_vals) == 3 &&
         CopyBuffer(ema50, 0, 0, 3, ema50_vals) == 3 &&
         CopyBuffer(ema200, 0, 0, 3, ema200_vals) == 3) {
         
         // Calcul de la pente des EMAs
         double ema20_slope = (ema20_vals[0] - ema20_vals[2]) / 2.0;
         double ema50_slope = (ema50_vals[0] - ema50_vals[2]) / 2.0;
         
         // Vérification de l'alignement des moyennes
         bool bullTrend = ema20_vals[0] > ema50_vals[0] && ema50_vals[0] > ema200_vals[0];
         bool bearTrend = ema20_vals[0] < ema50_vals[0] && ema50_vals[0] < ema200_vals[0];
         
         if(bullTrend && ema20_slope > 0) {
            totalBullish++;
         } else if(bearTrend && ema20_slope < 0) {
            totalBearish++;
         }
         
         totalFrames++;
      }
      
      IndicatorRelease(ema20);
      IndicatorRelease(ema50);
      IndicatorRelease(ema200);
   }
   
   // Détermination de la tendance globale
   if(totalBullish > totalFrames / 2) {
      result.direction = 1;
      result.strength = (double)totalBullish / totalFrames * 100.0;
      result.summary = "Tendance haussière forte (" + IntegerToString((int)result.strength) + "%)";
   } else if(totalBearish > totalFrames / 2) {
      result.direction = -1;
      result.strength = (double)totalBearish / totalFrames * 100.0;
      result.summary = "Tendance baissière forte (" + IntegerToString((int)result.strength) + "%)";
   } else {
      result.direction = 0;
      result.strength = 0;
      result.summary = "Marché en range ou indécis";
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Calculer la vélocité des prix                                   |
//+------------------------------------------------------------------+
double CalculateVelocity(const string symbol, const int period, double &velHistory[])
{
    double closes[];
    if(CopyClose(symbol, PERIOD_CURRENT, 1, period+1, closes) <= period) 
        return 0.0;
    
    // Calculer le delta de prix
    double delta = closes[0] - closes[period];
    
    // Mettre à jour l'historique des deltas pour le calcul du centile
    ArrayResize(velHistory, ArraySize(velHistory) + 1);
    velHistory[ArraySize(velHistory)-1] = MathAbs(delta);
    
    // Conserver uniquement les N dernières valeurs
    if(ArraySize(velHistory) > period)
        ArrayCopy(velHistory, velHistory, 0, 1);
    
    // Calculer le seuil dynamique (centile)
    double sorted[];
    ArrayCopy(sorted, velHistory);
    ArraySort(sorted);
    int idx = (int)MathRound((InpVelocityPercent/100.0) * (ArraySize(sorted)-1));
    double threshold = sorted[idx];
    
    // Retourner le ratio de vélocité normalisé
    return (threshold != 0) ? MathAbs(delta) / threshold : 0.0;
}

//+------------------------------------------------------------------+
//| Calculer le niveau pivot typique                                |
//+------------------------------------------------------------------+
double CalculateTypicalPivot(const string symbol, const int period)
{
    double sum = 0.0;
    for(int i=1; i<=period; i++)
    {
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low  = iLow(symbol, PERIOD_CURRENT, i);
        double close= iClose(symbol, PERIOD_CURRENT, i);
        sum += (high + low + close) / 3.0;
    }
    return sum / period;
}

//+------------------------------------------------------------------+
//| Vérifier la tendance avec EMA                                   |
//+------------------------------------------------------------------+
int CheckTrendEMA(const string symbol, const int period)
{
    double ema[];
    int handle = iMA(symbol, PERIOD_CURRENT, period, 0, MODE_EMA, PRICE_CLOSE);
    if(CopyBuffer(handle, 0, 0, 2, ema) < 2)
    {
        IndicatorRelease(handle);
        return 0;
    }
    IndicatorRelease(handle);
    
    double current = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(current > ema[0] * 1.001) return 1;    // Tendance haussière
    if(current < ema[0] * 0.999) return -1;   // Tendance baissière
    return 0;                                 // Pas de tendance claire
}

//+------------------------------------------------------------------+
//| Détecter un spike avec analyse avancée                          |
//+------------------------------------------------------------------+
bool IsAdvancedSpikeForming(const string symbol, int &direction, double &spikeStrength)
{
    // Initialisation
    direction = 0;
    spikeStrength = 0.0;
    
    // 1. Vérifier la vélocité du prix
    static double velocityHistory[];
    double velocity = CalculateVelocity(symbol, InpVelocityBars, velocityHistory);
    
    // 2. Vérifier la tendance avec EMA
    int trend = CheckTrendEMA(symbol, InpEMAPeriod);
    
    // 3. Calculer le pivot typique
    double pivot = CalculateTypicalPivot(symbol, InpPivotBars);
    
    // 4. Vérifier la volatilité avec ATR
    double atr[];
    int atr_handle = iATR(symbol, PERIOD_CURRENT, InpATRPeriod);
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) < 1) {
        IndicatorRelease(atr_handle);
        return false;
    }
    IndicatorRelease(atr_handle);
    
    // 5. Obtenir le prix actuel
    double current = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Conditions pour un spike haussier
    bool isBullishSpike = (velocity > 1.0) && 
                         (trend >= 0) && 
                         (current < pivot - InpPivotBuffer * _Point) &&
                         (atr[0] > 0);
    
    // Conditions pour un spike baissier
    bool isBearishSpike = (velocity > 1.0) && 
                         (trend <= 0) && 
                         (current > pivot + InpPivotBuffer * _Point) &&
                         (atr[0] > 0);
    
    // Déterminer la direction et la force du spike
    if(isBullishSpike) {
        direction = 1;
        spikeStrength = velocity;
        return true;
    }
    else if(isBearishSpike) {
        direction = -1;
        spikeStrength = velocity;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Gérer les signaux de trading avec détection avancée             |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
    if(!InpEnableTrading) return;
    
    // Vérifier si nous avons déjà une position ouverte
    if(PositionsTotal() > 0) {
        // Gérer les positions ouvertes (trailing stop, etc.)
        ManageOpenPositions();
        return;
    }
    
    // Détecter les signaux de spike
    double signalStrength = 0.0;
    int signal = DetectSpikeSignal(_Symbol, signalStrength);
    
    if(signal == 0) return; // Aucun signal
    
    // Calculer la taille de la position en fonction du risque
    double lotSize = CalculatePositionSize(signal);
    if(lotSize <= 0) return;
    
    // Exécuter le trade
    if(signal > 0) {
        // Signal d'achat (Boom)
        double sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (InpStopLoss * _Point);
        double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (InpTakeProfit * _Point);
        
        trade.Buy(lotSize, _Symbol, 0, sl, tp, "Boom Spike");
        
        if(InpDebug) {
            Print("Ordre d'achat exécuté - Signal: ", signalStrength, 
                  " Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
        }
    }
    else if(signal < 0) {
        // Signal de vente (Crash)
        double sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (InpStopLoss * _Point);
        double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - (InpTakeProfit * _Point);
        
        trade.Sell(lotSize, _Symbol, 0, sl, tp, "Crash Spike");
        
        if(InpDebug) {
            Print("Ordre de vente exécuté - Signal: ", signalStrength, 
                  " Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer la taille de la position en fonction du risque         |
//+------------------------------------------------------------------+
double CalculatePositionSize(int direction)
{
    if(InpLotSize > 0) return InpLotSize; // Utiliser la taille de lot fixe si définie
    
    // Calculer la taille de la position basée sur le risque
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue == 0 || tickSize == 0) return 0.0;
    
    // Calculer la taille de la position
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    double lotSize = riskAmount / (InpStopLoss * (tickValue / tickSize));
    lotSize = MathFloor(lotSize / lotStep) * lotStep; // Arrondir au pas de lot
    
    // Vérifier les limites
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Gérer les positions ouvertes                                    |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            
            // Gérer le trailing stop
            if(InpUseTrailingStop)
            {
                double newSl = 0;
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                {
                    newSl = currentPrice - (InpTrailingStopPts * _Point);
                    if(newSl > sl && newSl > openPrice) // Ne pas déplacer le SL en dessous du prix d'ouverture
                    {
                        trade.PositionModify(ticket, newSl, tp);
                    }
                }
                else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                {
                    newSl = currentPrice + (InpTrailingStopPts * _Point);
                    if((newSl < sl || sl == 0) && newSl < openPrice) // Ne pas déplacer le SL au-dessus du prix d'ouverture
                    {
                        trade.PositionModify(ticket, newSl, tp);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter un signal de spike imminent                            |
//+------------------------------------------------------------------+
int DetectSpikeSignal(const string symbol, double &signalStrength)
{
   if(!InpShowSpikeArrow) return 0; // Désactivé
   
   // Utiliser la détection de spike avancée
   int direction = 0;
   if(IsAdvancedSpikeForming(symbol, direction, signalStrength)) {
       return direction;
   }
   
   // Méthode de secours si la détection avancée ne trouve rien
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) return 0;
   
   // Calculer la volatilité récente avec ATR
   double atr = 0.0;
   int atr_handle = iATR(symbol, PERIOD_M1, 14);
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   
   if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) <= 0) {
      Print("Erreur lors de la copie des données ATR");
      IndicatorRelease(atr_handle);
      return 0;
   }
   atr = atr_buffer[0];
   IndicatorRelease(atr_handle);
   
   if(atr <= 0.0) return 0;
   
   // Vérifier les mouvements de prix récents
   double priceChange = rates[0].close - rates[4].close;
   double priceChangeAbs = MathAbs(priceChange);
   double priceChangePct = (rates[4].close > 0.0) ? (priceChangeAbs / rates[4].close * 100.0) : 0.0;
   
   // Vérifier les volumes
   double volume1 = (double)rates[0].real_volume;
   double volume2 = (double)MathMax(1, rates[1].real_volume);
   double volumeRatio = (volume2 > 0.0) ? (volume1 / volume2) : 0.0;
   
   // Déterminer si le marché est haussier ou baissier
   bool isBullish = (rates[0].close > rates[0].open);
   bool isStrongMove = (priceChangeAbs > (atr * 0.5)); // Mouvement supérieur à 0.5 ATR
   
   // Détecter un signal d'achat (spike haussier)
   if(isBullish && 
      rates[0].close > rates[1].high && 
      priceChangePct > 0.05 && 
      volumeRatio > 1.5 &&
      isStrongMove)
   {
      // Calculer la force du signal basée sur le mouvement du prix et la volatilité
      double momentum = MathAbs(priceChange) / (atr > 0 ? atr : 1.0);
      signalStrength = 70.0 + MathMin(30.0, (momentum - 0.5) * 40);
      
      // Vérifier la tendance avec les moyennes mobiles
      int ema20_handle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
      int ema50_handle = iMA(symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
      
      double ema20_buffer[], ema50_buffer[];
      ArraySetAsSeries(ema20_buffer, true);
      ArraySetAsSeries(ema50_buffer, true);
      
      if(CopyBuffer(ema20_handle, 0, 0, 2, ema20_buffer) > 0 &&
         CopyBuffer(ema50_handle, 0, 0, 2, ema50_buffer) > 0) {
         
         // Vérifier si le prix est au-dessus des EMAs et que les EMAs sont alignées
         if(rates[0].close > ema20_buffer[0] && ema20_buffer[0] > ema50_buffer[0]) {
            signalStrength = MathMin(100.0, signalStrength + 10.0);
         }
      }
      
      // Libérer les handles des indicateurs
      IndicatorRelease(ema20_handle);
      IndicatorRelease(ema50_handle);
      
      return 1; // Signal d'achat
   }
   
   // Détecter un signal de vente (spike baissier)
   if(!isBullish && 
      rates[0].close < rates[1].low && 
      priceChangePct > 0.05 && 
      volumeRatio > 1.5 &&
      isStrongMove)
   {
      // Calculer la force du signal basée sur le mouvement du prix et la volatilité
      double momentum = MathAbs(priceChange) / (atr > 0 ? atr : 1.0);
      signalStrength = 70.0 + MathMin(30.0, (momentum - 0.5) * 40);
      
      // Vérifier la tendance avec les moyennes mobiles
      int ema20_handle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
      int ema50_handle = iMA(symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
      
      double ema20_buffer[], ema50_buffer[];
      ArraySetAsSeries(ema20_buffer, true);
      ArraySetAsSeries(ema50_buffer, true);
      
      if(CopyBuffer(ema20_handle, 0, 0, 2, ema20_buffer) > 0 &&
         CopyBuffer(ema50_handle, 0, 0, 2, ema50_buffer) > 0) {
         
         // Vérifier si le prix est en dessous des EMAs et que les EMAs sont alignées
         if(rates[0].close < ema20_buffer[0] && ema20_buffer[0] < ema50_buffer[0]) {
            signalStrength = MathMin(100.0, signalStrength + 10.0);
         }
      }
      
      // Libérer les handles des indicateurs
      IndicatorRelease(ema20_handle);
      IndicatorRelease(ema50_handle);
      
      return -1; // Signal de vente
   }
   
   return false; // Pas de signal
}

//+------------------------------------------------------------------+
//| Dessine une flèche sur le graphique                              |
//+------------------------------------------------------------------+
void DrawSpikeArrow(const string symbol, int direction, double price, datetime time, int arrowSize=3)
{
   if(!InpShowSpikeArrow) return;
   
   // Créer un nom unique pour la flèche
   string arrowName = "SpikeArrow_" + IntegerToString(GetTickCount());
   
   // Supprimer l'ancienne flèche s'il y en a une
   if(g_lastSpikeSignal.active && g_lastSpikeSignal.arrowName != "")
      ObjectDelete(0, g_lastSpikeSignal.arrowName);
   
   // Définir la couleur et le code de la flèche
   color arrowColor = (direction > 0) ? InpBuyArrowColor : InpSellArrowColor;
   ENUM_ARROW_ANCHOR arrowCode = (direction > 0) ? ANCHOR_BOTTOM : ANCHOR_TOP;
   
   // Créer la flèche
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, arrowSize);
      ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR, arrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
      
      // Mettre à jour le dernier signal
      g_lastSpikeSignal.signalTime = time;
      g_lastSpikeSignal.price = price;
      g_lastSpikeSignal.direction = direction;
      g_lastSpikeSignal.active = true;
      g_lastSpikeSignal.arrowName = arrowName;
      
      // Ajouter une étiquette
      string labelName = arrowName + "_Label";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "SPIKE " + (direction > 0 ? "↑" : "↓"));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }
}

//+------------------------------------------------------------------+
//| Gestion des positions ouvertes pour la stratégie de spike        |
//+------------------------------------------------------------------+
void ManageSpikePositions()
{
   // Vérifier s'il y a un signal de spike actif
   if(!g_lastSpikeSignal.active) return;
   
   string symbol = _Symbol; // Le symbole actuel du graphique
   
   // Vérifier si le signal est toujours valide (dans la fenêtre de temps)
   if(TimeCurrent() - g_lastSpikeSignal.signalTime > InpSpikePredictionWindow)
   {
      // Le signal a expiré
      g_lastSpikeSignal.active = false;
      return;
   }
   
   // Vérifier si nous avons déjà une position ouverte pour ce signal
   if(HasOpenPosition(symbol, g_lastSpikeSignal.direction > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL))
   {
      // Vérifier si c'est un symbole Boom ou Crash
      bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
      
      // Obtenir le prix actuel
      double currentPrice = (g_lastSpikeSignal.direction > 0) ? 
                          SymbolInfoDouble(symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      // Mettre à jour le prix d'entrée si c'est une nouvelle position
      if(g_lastSpikeSignal.entryPrice == 0)
         g_lastSpikeSignal.entryPrice = g_lastSpikeSignal.price;
      
      double entryPrice = g_lastSpikeSignal.entryPrice;
      double profitPips = (g_lastSpikeSignal.direction > 0) ? 
                         (currentPrice - entryPrice) / _Point : 
                         (entryPrice - currentPrice) / _Point;
      
      // Calculer le profit/pertes en euros
      double lotSize = CalculateOptimalLotSize(symbol, 3.5); // Utiliser 3.5€ comme risque de base
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double profitUSD = (profitPips * _Point * tickValue * lotSize) / tickSize;
      
      // Déclaration des variables de gestion de fermeture
      bool shouldClose = false;
      string closeReason = "";
      
      // Mettre à jour le profit maximal atteint
      if(profitUSD > g_lastSpikeSignal.maxProfitUSD)
         g_lastSpikeSignal.maxProfitUSD = profitUSD;
      
      // Vérifier si on est en profit
      g_lastSpikeSignal.inProfit = (profitUSD > 0);
      
      // NOUVELLE LOGIQUE: Pour Boom/Crash, ne fermer QUE sur TP/SL
      if(isBoomCrash)
      {
         // Pour Boom/Crash, ne pas fermer automatiquement - laisser TP/SL gérer
         // La fonction HandleBoomCrashSpikeExit() s'occupera des fermetures TP/SL
         shouldClose = false;
      }
      else
      {
         // Logique normale pour les autres symboles
         // Si le profit dépasse 2€, forcer la fermeture immédiate pour les non Boom/Crash
         if(profitUSD >= 2.0)
         {
            closeReason = "💰 Fermeture à " + DoubleToString(profitUSD, 2) + "€ de profit";
            shouldClose = true;
         }
         
         // 1. Vérifier la perte maximale de 3.5$
         if(profitUSD <= -3.5)
         {
            closeReason = "⚠️ Stop Loss atteint: $" + DoubleToString(profitUSD, 2);
            shouldClose = true;
         }
         // 2. Vérifier si on a perdu plus de 50% du profit maximal
         else if(g_lastSpikeSignal.maxProfitUSD > 0 && profitUSD < (g_lastSpikeSignal.maxProfitUSD * 0.5))
         {
            closeReason = "🔽 Perte de 50% du profit maximal: $" + DoubleToString(profitUSD, 2) + 
                         " (Max: $" + DoubleToString(g_lastSpikeSignal.maxProfitUSD, 2) + ")";
            shouldClose = true;
         }
         // 3. Pour les non Boom/Crash, fermer à 2€ de profit
         else if(profitUSD >= 2.0)
         {
            closeReason = "✅ Objectif de profit atteint: " + DoubleToString(profitUSD, 2) + "€";
            shouldClose = true;
         }
         // 4. Fermer à l'expiration du signal
         else if(TimeCurrent() - g_lastSpikeSignal.signalTime >= InpSpikePredictionWindow)
         {
            closeReason = "⏱️ Expiration du signal - Profit: $" + DoubleToString(profitUSD, 2);
            shouldClose = true;
         }
      }
      
      // Fermer la position si nécessaire
      if(shouldClose)
      {
         Print(closeReason, " sur ", symbol);
         CloseAllPositionsForSymbol(symbol);
         g_lastSpikeSignal.active = false;
         g_lastSpikeSignal.lastCloseTime = TimeCurrent();
         g_lastSpikeSignal.lastClosePrice = currentPrice;
      }
   }
   
   // Vérifier le délai de repositionnement (5 minutes après la dernière fermeture)
   if(TimeCurrent() - g_lastSpikeSignal.lastCloseTime < 300) // 300 secondes = 5 minutes
   {
      if(TimeCurrent() - g_lastSpikeSignal.lastCloseTime == 1) // Ne s'affiche qu'une fois
         Print("⏳ Attente de repositionnement pour ", symbol, " (5 minutes de délai)");
      return;
   }
   
   if(TimeCurrent() - g_lastSpikeSignal.signalTime < 10) // Essayer d'ouvrir une position dans les 10 secondes suivant le signal
   {
      // Essayer d'ouvrir une position
      double lotSize = CalculateOptimalLotSize(symbol, InpSpikeStopLossUSD);
      
      // Vérifier si c'est un symbole Boom ou Crash
      bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
      
      // Calculer les niveaux de SL et TP
      double price = (g_lastSpikeSignal.direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      double sl = 0, tp = 0;
      
      if(g_lastSpikeSignal.direction > 0) // Achat
      {
         if(isBoomCrash)
         {
            // Pour Boom/Crash, utiliser le même SL que TP avec ajustement dynamique
            TrendAnalysis trend = AnalyzeMarketTrend(symbol);
            double tpMultiplier = 1.0;
            
            // Ajuster le TP en fonction de la force de la tendance
            if(trend.direction == 1) {  // Tendance haussière
               tpMultiplier = 1.0 + (trend.strength / 100.0);
               Print("Tendance haussière détectée (", trend.strength, "%), ajustement du TP x", tpMultiplier);
            } else if(trend.direction == -1) {  // Tendance baissière
               tpMultiplier = 0.9;  // TP plus serré en tendance baissière
               Print("Tendance baissière détectée, réduction du TP x", tpMultiplier);
            } else {
               tpMultiplier = 0.95;  // TP légèrement réduit en marché neutre
               Print("Marché neutre, TP standard x", tpMultiplier);
            }
            
            // Calculer SL/TP avec la nouvelle méthode basée sur les candlesticks
            ComputeSpikeSLTP_ByCandlesticks(symbol, POSITION_TYPE_BUY, lotSize, sl, tp);
         }
         else
         {
            // Pour les autres symboles, SL = 1/3 du TP
            tp = price + InpSpikeTargetUSD * _Point;
            sl = price - (InpSpikeTargetUSD / 3.0) * _Point;
         }
         
         // VALIDATION FINALE: Vérifier que les niveaux SL/TP sont valides
         if(!ValidateSLTPLevels(symbol, POSITION_TYPE_BUY, price, sl, tp))
         {
            Print("❌ SL/TP invalides pour BUY sur ", symbol, " - Ordre annulé");
            return;
         }
         
         Print("Ordre d'achat sur ", symbol, " - Prix: ", price, " SL: ", sl, " TP: ", tp);
         g_trade.Buy(lotSize, symbol, price, sl, tp, "Spike Buy");
      }
      else // Vente
      {
         if(isBoomCrash)
         {
            // Pour Boom/Crash, utiliser le même SL que TP avec ajustement dynamique
            TrendAnalysis trend = AnalyzeMarketTrend(symbol);
            double tpMultiplier = 1.0;
            
            // Ajuster le TP en fonction de la force de la tendance
            if(trend.direction == -1) {  // Tendance baissière
               tpMultiplier = 1.0 + (trend.strength / 100.0);
               Print("Tendance baissière détectée (", trend.strength, "%), ajustement du TP x", tpMultiplier);
            } else if(trend.direction == 1) {  // Tendance haussière
               tpMultiplier = 0.9;  // TP plus serré en tendance haussière
               Print("Tendance haussière détectée, réduction du TP x", tpMultiplier);
            } else {
               tpMultiplier = 0.95;  // TP légèrement réduit en marché neutre
               Print("Marché neutre, TP standard x", tpMultiplier);
            }
            
            // Calculer SL/TP avec la nouvelle méthode basée sur les candlesticks
            ComputeSpikeSLTP_ByCandlesticks(symbol, POSITION_TYPE_SELL, lotSize, sl, tp);
         }
         else
         {
            // Pour les autres symboles, SL = 1/3 du TP
            tp = price - InpSpikeTargetUSD * _Point;
            sl = price + (InpSpikeTargetUSD / 3.0) * _Point;
         }
         
         // VALIDATION FINALE: Vérifier que les niveaux SL/TP sont valides
         if(!ValidateSLTPLevels(symbol, POSITION_TYPE_SELL, price, sl, tp))
         {
            Print("❌ SL/TP invalides pour SELL sur ", symbol, " - Ordre annulé");
            return;
         }
         
         Print("Ordre de vente sur ", symbol, " - Prix: ", price, " SL: ", sl, " TP: ", tp);
         g_trade.Sell(lotSize, symbol, price, sl, tp, "Spike Sell");
      }
   }
}

// Structure pour suivre les modifications par position
struct PositionModification {
    ulong ticket;
    int slModificationCount;
    double lastSL;
    datetime lastModificationTime;
};

PositionModification g_positionModifications[100];  // Tableau pour stocker les modifications
int g_positionModificationsCount = 0;  // Nombre de positions suivies

//+------------------------------------------------------------------+
//| Modifie le Stop Loss d'une position ouverte avec limitation      |
//+------------------------------------------------------------------+
bool ModifyPositionSL(const string symbol, double newSL)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      // Vérifier si la position est toujours active
      if(!IsPositionActive(ticket))
      {
         Print("⚠️ Position ", ticket, " n'est plus active, nettoyage...");
         CleanupClosedPositions();
         continue;
      }
      
      if(PositionGetString(POSITION_SYMBOL) == symbol && 
         (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         // Vérifier à nouveau si la position est toujours active avant de continuer
         if(!IsPositionActive(ticket))
         {
            Print("⚠️ Position ", ticket, " n'est plus active, annulation de la modification");
            CleanupClosedPositions();
            return false; // Pas de signal
         }
         
         double currentSL = PositionGetDouble(POSITION_SL);
         
         // Ne pas modifier si le nouveau SL est identique à l'actuel (ou très proche)
         if(MathAbs(newSL - currentSL) < _Point / 2.0)
            return false; // Pas de signal
            
         // Vérifier si on a déjà modifié ce SL 3 fois
         bool found = false;
         int modIndex = -1;
         
         // Chercher si on a déjà des modifications pour ce ticket
         for(int j = 0; j < g_positionModificationsCount; j++)
         {
            if(g_positionModifications[j].ticket == ticket)
            {
               found = true;
               modIndex = j;
               break;
            }
         }
         
         // Si c'est une nouvelle position, l'ajouter au suivi
         if(!found && g_positionModificationsCount < 100)
         {
            modIndex = g_positionModificationsCount;
            g_positionModifications[modIndex].ticket = ticket;
            g_positionModifications[modIndex].slModificationCount = 0;
            g_positionModifications[modIndex].lastSL = 0;
            g_positionModifications[modIndex].lastModificationTime = 0;
            g_positionModificationsCount++;
         }
         
         // Vérifier le nombre de modifications
         if(found && g_positionModifications[modIndex].slModificationCount >= 3)
         {
            Print("⚠️ Modification de SL bloquée pour le ticket ", ticket, 
                  " - Limite de 3 modifications atteinte");
            return false; // Pas de signal
         }
         
         // Vérifier une dernière fois si la position est toujours active
         if(!IsPositionActive(ticket))
         {
            Print("⚠️ Position ", ticket, " n'est plus active, annulation de la modification (2)");
            CleanupClosedPositions();
            return false; // Pas de signal
         }
         
         // Effectuer la modification
         double tp = PositionGetDouble(POSITION_TP);
         bool success = g_trade.PositionModify(ticket, newSL, tp);
         
         // Si la modification échoue, vérifier si c'est parce que la position a été fermée
         if(!success && GetLastError() == 4756) // TRADE_RETCODE_INVALID_ORDER
         {
            Print("⚠️ Échec de la modification - la position ", ticket, " a probablement été fermée");
            CleanupClosedPositions();
            return false; // Pas de signal
         }
         
         // Mettre à jour le compteur si la modification a réussi
         if(success)
         {
            if(found)
            {
               g_positionModifications[modIndex].slModificationCount++;
               g_positionModifications[modIndex].lastSL = newSL;
               g_positionModifications[modIndex].lastModificationTime = TimeCurrent();
               Print("ℹ️ Modification SL #", g_positionModifications[modIndex].slModificationCount, 
                     " pour le ticket ", ticket, " - Nouveau SL: ", DoubleToString(newSL, _Digits));
            }
            return true;
         }
         
         // En cas d'échec inattendu, journaliser l'erreur
         Print("❌ Erreur inattendue lors de la modification du SL pour le ticket ", ticket, 
               ". Erreur: ", GetLastError());
         return false; // Pas de signal
      }
   }
   return false; // Pas de signal
}

//+------------------------------------------------------------------+
//| Nettoie les entrées de suivi des positions fermées               |
//+------------------------------------------------------------------+
void CleanupClosedPositions()
{
   // Vérifier chaque position suivie
   for(int i = g_positionModificationsCount - 1; i >= 0; i--)
   {
      bool positionExists = false;
      
      // Vérifier si la position existe toujours
      for(int j = 0; j < PositionsTotal(); j++)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket == g_positionModifications[i].ticket)
         {
            positionExists = true;
            break;
         }
      }
      
      // Si la position n'existe plus, la supprimer du suivi
      if(!positionExists)
      {
         // Déplacer la dernière entrée à la position actuelle
         if(i < g_positionModificationsCount - 1)
         {
            g_positionModifications[i] = g_positionModifications[g_positionModificationsCount - 1];
         }
         g_positionModificationsCount--;
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si une position est toujours active par son ticket        |
//+------------------------------------------------------------------+
bool IsPositionActive(ulong ticket)
{
   if(ticket == 0) return false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == ticket)
         return true;
   }
   return false; // Pas de signal
}

//+------------------------------------------------------------------+
//| Vérifie si une position est ouverte selon les critères spécifiés |
//+------------------------------------------------------------------+
bool HasOpenPosition(string symbol = NULL, int type = -1)
{
    // Si aucun symbole n'est spécifié, utiliser le symbole actuel
    if(symbol == NULL || symbol == "") symbol = _Symbol;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            bool symbolMatch = (symbol == "" || PositionGetString(POSITION_SYMBOL) == symbol);
            bool typeMatch = (type == -1 || 
                           (type == 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) || 
                           (type == 1 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ||
                           PositionGetInteger(POSITION_TYPE) == type);
            
            if(symbolMatch && typeMatch)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calcule la taille de lot optimale en fonction du risque          |
//+------------------------------------------------------------------+
double CalculateOptimalLotSize(string symbol, double riskAmount)
{
   // Si aucun symbole n'est spécifié, utiliser le symbole actuel
   if(symbol == NULL || symbol == "") symbol = _Symbol;
   
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
      return 0.1; // Valeur par défaut en cas d'erreur
   
   // Calculer la taille de lot en fonction du risque
   double lotSize = riskAmount / (tickValue * (InpSpikeStopLossUSD / tickSize));
   
   // Arrondir au lotStep le plus proche
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // S'assurer que la taille du lot est dans les limites autorisées
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions pour un symbole donné                 |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(const string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelect(PositionGetSymbol(i)) && PositionGetString(POSITION_SYMBOL) == symbol)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         g_trade.PositionClose(ticket);
      }
   }
}

// La fonction OnTick est définie plus haut dans le fichier (ligne 7354)
// Cette redirection n'est plus nécessaire car nous utilisons directement OnTick_Original()
// dans la fonction OnTick principale

//+------------------------------------------------------------------+
//| Fonction principale de traitement des symboles Boom/Crash       |
//+------------------------------------------------------------------+
void ProcessBoomCrashSymbols()
{
   // DEBUG: Afficher l'état des positions
   int totalPositions = PositionsTotal();
   int eaPositions = CountOpenPositionsEA();
   Print("🔍 DEBUG: Positions totales: ", totalPositions, " | Positions EA: ", eaPositions, "/", InpMaxGlobalPositions);
   
   // PROTECTION MODIFIÉE : Permettre plusieurs trades si limites respectées
   if(eaPositions >= InpMaxGlobalPositions)
   {
      Print("🚫 LIMITE ATTEINTE - Positions EA: ", eaPositions, "/", InpMaxGlobalPositions);
      return;
   }
   
      string symbols[];
      StringSplit(InpAllowedSymbols, ',', symbols);
      
      for(int i = 0; i < ArraySize(symbols); i++)
      {
         string symbol = StringTrim(symbols[i]);
         if(symbol == "") continue;
         
         // Vérifier si c'est un symbole Boom/Crash
         if(IsBoomCrashSymbol(symbol))
         {
            if(SymbolSelect(symbol, true))
            {
            // Détection des signaux de spike UNIQUEMENT
               double signalStrength = 0;
               int signal = DetectSpikeSignal(symbol, signalStrength);
            
            if(signal != 0 && signalStrength > 30.0) // Seuil de force réduit pour plus d'opportunités
            {
               Print("\n🔥 SPIKE DÉTECTÉ! ", (signal > 0 ? "ACHAT" : "VENTE"), " sur ", symbol, " (force: ", signalStrength, ")");
               
               // Calculer le lot et les niveaux SL/TP
               double lotSize = CalculateOptimalLotSize(symbol, InpSpikeStopLossUSD);
               double entryPrice = (signal > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
               
               // Calculer SL/TP avec respect des limites du symbole
               double sl = 0.0, tp = 0.0;
               double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);
               double minDistance = MathMax(minStopLevel, 10 * SymbolInfoDouble(symbol, SYMBOL_POINT));
               
               // Calculer SL/TP avec la nouvelle méthode basée sur les candlesticks
               ComputeSpikeSLTP_ByCandlesticks(symbol, signal > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, lotSize, sl, tp);
               
               // Normaliser les prix selon les digits du symbole
               int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
               sl = NormalizeDouble(sl, digits);
               tp = NormalizeDouble(tp, digits);
               
               // Vérifications finales avant trade
               if(lotSize > 0 && sl > 0 && tp > 0)
               {
                  // VALIDATION FINALE: Vérifier que les niveaux SL/TP sont valides
                  if(!ValidateSLTPLevels(symbol, signal > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, entryPrice, sl, tp))
                  {
                     Print("❌ SL/TP invalides pour ", symbol, " - Ordre annulé");
                     return;
                  }
                  
                  // Vérifier que les distances SL/TP sont valides
                  bool slTpValid = true;
                  if(signal > 0) // Achat
                  {
                     if(sl >= entryPrice || tp <= entryPrice) slTpValid = false;
                  }
                  else // Vente
                  {
                     if(sl <= entryPrice || tp >= entryPrice) slTpValid = false;
                  }
                  
                  if(slTpValid)
                  {
                     // Exécuter le trade
                     g_trade.SetExpertMagicNumber(InpMagicNumber);
                     g_trade.SetDeviationInPoints(InpSlippagePoints);
                     
                     bool success = false;
                     if(signal > 0)
                        success = g_trade.Buy(lotSize, symbol, entryPrice, sl, tp, "Boom/Crash Spike");
                     else
                        success = g_trade.Sell(lotSize, symbol, entryPrice, sl, tp, "Boom/Crash Spike");
                     
                     if(success)
                     {
                        Print("✅ Trade Boom/Crash exécuté: ", symbol, " Direction: ", 
                              (signal > 0 ? "Achat" : "Vente"), " Lot: ", lotSize);
                        Print("📊 SL: ", DoubleToString(sl, digits), " TP: ", DoubleToString(tp, digits));
                        DrawSpikeArrow(symbol, signal, entryPrice, TimeCurrent());
                        
                        // Sortir immédiatement après un trade réussi
                        return;
                           }
                           else
                           {
                        Print("❌ Échec du trade: ", ErrorDescription(g_trade.ResultRetcode()));
                           }
                        }
                        else
                        {
                     Print("❌ SL/TP invalides: SL=", DoubleToString(sl, digits), " TP=", DoubleToString(tp, digits), " Entry=", DoubleToString(entryPrice, digits));
                  }
               }
               else
               {
                  Print("❌ Paramètres de trade invalides: Lot=", lotSize, " SL=", sl, " TP=", tp);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie s'il y a une position EA ouverte (protection anti-multiples) |
//+------------------------------------------------------------------+
bool HasAnyEAPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return true; // Position EA trouvée
         }
      }
   }
   return false; // Aucune position EA
}

//+------------------------------------------------------------------+
//| Ferme automatiquement les positions de spike en gain             |
//+------------------------------------------------------------------+
void CloseSpikePositionsInProfit()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      // Vérifier que c'est une position EA
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      
      // Vérifier que c'est un symbole Boom/Crash
      if(!IsBoomCrashSymbol(symbol)) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      double profitUSD = profit;
      
      // Conversion en USD si nécessaire
      if(SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT) != "USD")
      {
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         profitUSD = profit * tickValue;
      }
      
      // Fermer si le profit atteint le TP1 (gain rapide)
      if(profitUSD >= InpQuickTP1)
      {
         Print("🎯 SPIKE CAPTURÉ EN GAIN! Fermeture automatique: ", symbol, " Profit: $", DoubleToString(profitUSD, 2));
         
         if(g_trade.PositionClose(ticket))
         {
            Print("✅ Position fermée avec succès - Spike capturé!");
                           }
                           else
                           {
            Print("❌ Erreur lors de la fermeture: ", ErrorDescription(g_trade.ResultRetcode()));
         }
      }
      // Fermer si le profit atteint le TP2 (gain maximum)
      else if(profitUSD >= InpQuickTP2)
      {
         Print("🏆 GAIN MAXIMUM ATTEINT! Fermeture automatique: ", symbol, " Profit: $", DoubleToString(profitUSD, 2));
         
         if(g_trade.PositionClose(ticket))
         {
            Print("✅ Position fermée avec succès - Gain maximum!");
                        }
                        else
                        {
            Print("❌ Erreur lors de la fermeture: ", ErrorDescription(g_trade.ResultRetcode()));
         }
      }
      // Fermer si perte atteint le SL
      else if(profitUSD <= -InpSpikeStopLossUSD)
      {
         Print("🛑 STOP LOSS ATTEINT! Fermeture automatique: ", symbol, " Perte: $", DoubleToString(MathAbs(profitUSD), 2));
         
         if(g_trade.PositionClose(ticket))
         {
            Print("✅ Position fermée avec succès - Stop Loss!");
         }
         else
         {
            Print("❌ Erreur lors de la fermeture: ", ErrorDescription(g_trade.ResultRetcode()));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Détecte un signal de spike sur les indices Boom/Crash            |
//+ Retourne : 1 pour un signal haussier, -1 pour un signal baissier, 0 pour aucun signal |
//+------------------------------------------------------------------+
int IsBoomCrashSpikeSignal(const string symbol, int &direction, double &signalStrength)
{
   // Initialiser la force du signal à 0 (aucun signal)
   signalStrength = 0.0;
   
   // Vérifier si c'est un symbole Boom/Crash
   bool isBoom = (StringFind(symbol, "Boom") != -1);
   bool isCrash = (StringFind(symbol, "Crash") != -1);
   
   if(!isBoom && !isCrash)
      return 0; // Pas un symbole Boom/Crash
      
   // Récupérer les données de prix sur plusieurs timeframes pour l'analyse de tendance
   MqlRates ratesM1[], ratesM5[], ratesM15[];
   ArraySetAsSeries(ratesM1, true);
   ArraySetAsSeries(ratesM5, true);
   ArraySetAsSeries(ratesM15, true);
   
   // Copier les données de prix sur différents timeframes
   if(CopyRates(symbol, PERIOD_M1, 0, 100, ratesM1) < 100 ||
      CopyRates(symbol, PERIOD_M5, 0, 50, ratesM5) < 50 ||
      CopyRates(symbol, PERIOD_M15, 0, 30, ratesM15) < 30) {
      Print("Erreur lors de la copie des données de prix pour ", symbol);
      return 0;
   }
   
   // Calculer les moyennes mobiles pour déterminer la tendance sur plusieurs timeframes
   int emaFastM15 = iMA(symbol, PERIOD_M15, 8, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlowM15 = iMA(symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   int emaFastH1 = iMA(symbol, PERIOD_H1, 14, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlowH1 = iMA(symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   double emaFastM15_buf[], emaSlowM15_buf[], emaFastH1_buf[], emaSlowH1_buf[];
   ArraySetAsSeries(emaFastM15_buf, true);
   ArraySetAsSeries(emaSlowM15_buf, true);
   ArraySetAsSeries(emaFastH1_buf, true);
   ArraySetAsSeries(emaSlowH1_buf, true);
   
   // Copier les données des indicateurs
   if(CopyBuffer(emaFastM15, 0, 0, 5, emaFastM15_buf) <= 0 ||
      CopyBuffer(emaSlowM15, 0, 0, 5, emaSlowM15_buf) <= 0 ||
      CopyBuffer(emaFastH1, 0, 0, 5, emaFastH1_buf) <= 0 ||
      CopyBuffer(emaSlowH1, 0, 0, 5, emaSlowH1_buf) <= 0) {
      Print("Erreur lors de la copie des données EMA");
      IndicatorRelease(emaFastM15); IndicatorRelease(emaSlowM15);
      IndicatorRelease(emaFastH1); IndicatorRelease(emaSlowH1);
      return 0;
   }
   
   // Calculer la tendance sur M15 et H1
   bool uptrendM15 = (emaFastM15_buf[0] > emaSlowM15_buf[0] && 
                     emaFastM15_buf[1] > emaSlowM15_buf[1] &&
                     emaFastM15_buf[0] > emaFastM15_buf[1]);
   
   bool downtrendM15 = (emaFastM15_buf[0] < emaSlowM15_buf[0] && 
                       emaFastM15_buf[1] < emaSlowM15_buf[1] &&
                       emaFastM15_buf[0] < emaFastM15_buf[1]);
   
   bool uptrendH1 = (emaFastH1_buf[0] > emaSlowH1_buf[0] && 
                    emaFastH1_buf[1] > emaSlowH1_buf[1]);
   
   bool downtrendH1 = (emaFastH1_buf[0] < emaSlowH1_buf[0] && 
                      emaFastH1_buf[1] < emaSlowH1_buf[1]);
   
   // Libérer les handles des indicateurs
   IndicatorRelease(emaFastM15); IndicatorRelease(emaSlowM15);
   IndicatorRelease(emaFastH1); IndicatorRelease(emaSlowH1);
   
   // Vérifier la cohérence des tendances entre M15 et H1
   bool strongUptrend = uptrendM15 && uptrendH1;
   bool strongDowntrend = downtrendM15 && downtrendH1;
   
   // Pour les indices Boom, on ne prend que les tendances haussières fortes
   if(isBoom && !strongUptrend) {
      if(GetTickCount() % 60000 < 1000)
         Print(symbol, " - Tendance haussière insuffisante pour un indice Boom");
      return 0;
   }
   
   // Pour les indices Crash, on ne prend que les tendances baissières fortes
   if(isCrash && !strongDowntrend) {
      if(GetTickCount() % 60000 < 1000)
         Print(symbol, " - Tendance baissière insuffisante pour un indice Crash");
      return 0;
   }
   
   // Déterminer la direction de la tendance pour la suite
   int trendDirection = 0;
   if(strongUptrend) trendDirection = 1;
   else if(strongDowntrend) trendDirection = -1;
   else return 0; // Pas de tendance forte détectée
   
   // Calculer l'ATR pour la volatilité
   int atr_handle = iATR(symbol, PERIOD_M1, 14);
   if(atr_handle == INVALID_HANDLE) {
      Print("Erreur lors de la création du handle ATR");
      return 0;
   }
   
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) <= 0) {
      Print("Erreur lors de la copie des données ATR");
      IndicatorRelease(atr_handle);
      return 0;
   }
   
   double atr = atr_buffer[0];
   IndicatorRelease(atr_handle);
   
   // Détection de spike sur M1
   double currentRange = ratesM1[0].high - ratesM1[0].low;
   double rangeRatio = (atr > 0) ? (currentRange / atr) : 0;
   
   // Seuil dynamique basé sur la volatilité
   double spikeThreshold = InpBoomCrashSpikeThreshold * (1 + atr * 100);
   
   // Seuil minimum pour considérer un spike (2x la volatilité normale)
   double minSpikeThreshold = 2.0 * atr;
   
   // Vérifier si on a un spike significatif
   if(rangeRatio > spikeThreshold && currentRange > minSpikeThreshold)
   {
      double priceChange = ratesM1[0].close - ratesM1[1].close;
      double minPriceMove = atr * 0.5; // Seuil minimum de mouvement
      
      // Vérification supplémentaire du volume et de la force du mouvement
      double volumeRatio = (ratesM1[0].real_volume > 0) ? (double)ratesM1[0].real_volume / ratesM1[1].real_volume : 1.0;
      
      // Calculer la force relative du mouvement
      double bodySize = MathAbs(ratesM1[0].close - ratesM1[0].open);
      double upperWick = ratesM1[0].high - MathMax(ratesM1[0].open, ratesM1[0].close);
      double lowerWick = MathMin(ratesM1[0].open, ratesM1[0].close) - ratesM1[0].low;
      
      // Pour les indices Boom (tendance haussière), on ne prend que les signaux d'achat forts
      if(isBoom && trendDirection > 0 && priceChange > minPriceMove && 
         ratesM1[0].close > ratesM1[1].close + (ratesM1[1].high - ratesM1[1].low) * 0.6 &&
         bodySize > (upperWick + lowerWick) * 1.5 && // Le corps doit être plus grand que les mèches
         volumeRatio > 1.2) // Volume plus élevé que la bougie précédente
      {
         // Vérifier que le prix est au-dessus des moyennes mobiles
         if(ratesM1[0].close > emaFastM15_buf[0] && emaFastM15_buf[0] > emaSlowM15_buf[0]) {
            direction = 1; // Signal haussier
            signalStrength = MathMin(100.0, (rangeRatio / spikeThreshold) * 70.0 + 30.0);
            signalStrength *= (volumeRatio > 1.5) ? 1.1 : 1.0; // Augmenter la force du signal si le volume est très élevé
            return 1;
         }
      }
      // Pour les indices Crash (tendance baissière), on ne prend que les signaux de vente forts
      else if(isCrash && trendDirection < 0 && priceChange < -minPriceMove && 
              ratesM1[0].close < ratesM1[1].close - (ratesM1[1].high - ratesM1[1].low) * 0.6 &&
              bodySize > (upperWick + lowerWick) * 1.5 && // Le corps doit être plus grand que les mèches
              volumeRatio > 1.2) // Volume plus élevé que la bougie précédente
      {
         // Vérifier que le prix est en dessous des moyennes mobiles
         if(ratesM1[0].close < emaFastM15_buf[0] && emaFastM15_buf[0] < emaSlowM15_buf[0]) {
            direction = -1; // Signal baissier
            signalStrength = MathMin(100.0, (rangeRatio / spikeThreshold) * 70.0 + 30.0);
            signalStrength *= (volumeRatio > 1.5) ? 1.1 : 1.0; // Augmenter la force du signal si le volume est très élevé
            return -1;
         }
      }
   }
   
   return false; // Pas de signal dans le sens de la tendance
}

//+------------------------------------------------------------------+
//| Gère les positions pour les indices Boom/Crash                   |
//+------------------------------------------------------------------+
void ManageBoomCrashPositions()
{
   if(!InpEnableTrading || !InpEnableBoomCrashDetection) return;
   
   // Liste des symboles Boom/Crash à surveiller
   string boomCrashSymbols[] = {"Boom 300 Index", "Crash 300 Index", 
                              "Boom 500 Index", "Crash 500 Index",
                              "Boom 1000 Index", "Crash 1000 Index"};
   
   // Vérifier la volatilité du marché global avant de trader
   MqlRates rates[];
   if(CopyRates("Boom 500 Index", PERIOD_M1, 0, 20, rates) < 20) return;
   
   // Calculer la volatilité récente (écart-type sur 20 périodes)
   double sum = 0, sumSq = 0;
   for(int i = 1; i < 20; i++) {
      double ret = (rates[i].close - rates[i-1].close) / rates[i-1].close;
      sum += ret;
      sumSq += ret * ret;
   }
   double volatility = MathSqrt((sumSq - sum*sum/19) / 19) * MathSqrt(1440) * 100; // Volatilité annualisée en %
   
   // Ne pas trader si la volatilité est trop faible
   if(volatility < 5.0) {
      if(GetTickCount() % 60000 < 1000) // Afficher le message max 1 fois par minute
         Print("Volatilité trop faible (", DoubleToString(volatility, 1), "%) - Attente de meilleures conditions");
      return;
   }
   
   for(int i = 0; i < ArraySize(boomCrashSymbols); i++)
   {
      string symbol = boomCrashSymbols[i];
      if(!SymbolSelect(symbol, true)) continue;
      
      int direction = 0;
      double signalStrength = 0;
      if(IsBoomCrashSpikeSignal(symbol, direction, signalStrength))
      {
         // Seuil minimum de confiance pour entrer en position (70%)
         double minConfidence = 70.0;
         if(signalStrength < minConfidence) {
            if(GetTickCount() % 60000 < 1000) // Afficher le message max 1 fois par minute
               Print("Signal trop faible (", DoubleToString(signalStrength, 1), "% de confiance) - Attente d'un meilleur setup");
            continue;
         }
         
         // Vérifier si on peut ouvrir une nouvelle position
         if(CanPlaceNewOrder(symbol, direction))
         {
            double lotSize = CalculateOptimalLotSize(symbol, InpMaxLossBoomCrashUSD);
            if(lotSize > 0)
            {
               double price = (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                                             SymbolInfoDouble(symbol, SYMBOL_BID);
               
               double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
               double sl = 0.0, tp = 0.0;
               // Calculer SL/TP avec la nouvelle méthode basée sur les candlesticks
               ComputeSpikeSLTP_ByCandlesticks(symbol, direction > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, lotSize, sl, tp);
               
               // Arrondir les niveaux
               int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
               price = NormalizeDouble(price, digits);
               sl = NormalizeDouble(sl, digits);
               tp = NormalizeDouble(tp, digits);
               
               // Placer l'ordre
               trade.SetExpertMagicNumber(InpMagicNumber);
               trade.SetDeviationInPoints(InpSlippagePoints);
               
               if(direction > 0)
                  trade.Buy(lotSize, symbol, price, sl, tp, "Boom/Crash Spike");
               else
                  trade.Sell(lotSize, symbol, price, sl, tp, "Boom/Crash Spike");
                  
               if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
               {
                  Print("Ordre Boom/Crash exécuté: ", symbol, " Direction: ", 
                        (direction > 0 ? "Achat" : "Vente"), " Lot: ", lotSize);
               }
               else
               {
                  Print("Erreur d'exécution Boom/Crash: ", 
                        ErrorDescription(trade.ResultRetcode()));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dessine une zone de support/résistance                          |
//+------------------------------------------------------------------+
void DrawSupportResistanceZone(const string symbol, const double price1, const double price2, 
                             const string name, const color clr, const int width, const ENUM_LINE_STYLE style)
{
    if(!InpShowSRZones) return;
    
    // Créer un rectangle pour la zone
    if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, 0, 0, 0, 0))
    {
        // Définir les coordonnées du rectangle
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
        ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
        ObjectSetInteger(0, name, OBJPROP_TIME, 0, TimeCurrent() - PeriodSeconds() * InpSRZoneLookback);
        ObjectSetInteger(0, name, OBJPROP_TIME, 1, TimeCurrent() + PeriodSeconds() * 24);
        
        // Style du rectangle
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    }
}

//+------------------------------------------------------------------+
//| Dessine les zones de support et résistance                      |
//+------------------------------------------------------------------+
void DrawSupportResistanceZones()
{
    if(!InpShowSRZones) return;
    
    // Supprimer les anciennes zones
    for(int i = ObjectsTotal(0, 0, -1)-1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, "SR_") == 0) ObjectDelete(0, name);
    }
    
    // Obtenir les données de prix
    double high[];
    double low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    // Copier les hauts et les bas
    if(CopyHigh(_Symbol, _Period, 0, InpSRZoneLookback, high) <= 0 || 
       CopyLow(_Symbol, _Period, 0, InpSRZoneLookback, low) <= 0)
    {
        Print("Erreur lors de la copie des données de prix pour les zones S/R");
        return;
    }
    
    // Trouver les niveaux de support et résistance
    double supports[], resistances[];
    int supportCount = 0, resistanceCount = 0;
    
    // Analyser les bougies pour trouver les niveaux
    for(int i = 5; i < InpSRZoneLookback-5; i++) // Commencer à 5 pour éviter les faux signaux
    {
        // Détection des supports (creux locaux plus significatifs)
        if(low[i] < low[i-1] && low[i] < low[i+1] && 
           low[i] < low[i-2] && low[i] < low[i+2] &&
           low[i] < low[i-3] && low[i] < low[i+3])
        {
            // Vérifier si un niveau similaire existe déjà
            bool exists = false;
            for(int j = 0; j < supportCount; j++)
            {
                if(MathAbs(supports[j] - low[i]) < InpSRZoneTolerance * _Point)
                {
                    exists = true;
                    break;
                }
            }
            if(!exists && supportCount < 10) // Limiter à 10 niveaux de support
            {
                supports[supportCount++] = low[i];
            }
        }
        
        // Détection des résistances (sommets locaux plus significatifs)
        if(high[i] > high[i-1] && high[i] > high[i+1] && 
           high[i] > high[i-2] && high[i] > high[i+2] &&
           high[i] > high[i-3] && high[i] > high[i+3])
        {
            // Vérifier si un niveau similaire existe déjà
            bool exists = false;
            for(int j = 0; j < resistanceCount; j++)
            {
                if(MathAbs(resistances[j] - high[i]) < InpSRZoneTolerance * _Point)
                {
                    exists = true;
                    break;
                }
            }
            if(!exists && resistanceCount < 10) // Limiter à 10 niveaux de résistance
            {
                resistances[resistanceCount++] = high[i];
            }
        }
    }
    
    // Trier les niveaux (sans spécifier le mode de tri personnalisé qui cause des erreurs)
    if(supportCount > 0) ArraySort(supports);
    if(resistanceCount > 0) ArraySort(resistances);
    
    // Inverser l'ordre pour les résistances (du plus haut au plus bas)
    if(resistanceCount > 0)
    {
        double temp;
        for(int i = 0; i < resistanceCount / 2; i++)
        {
            temp = resistances[i];
            resistances[i] = resistances[resistanceCount - 1 - i];
            resistances[resistanceCount - 1 - i] = temp;
        }
    }
    
    // Tracer les zones de support (rectangles verts avec transparence)
    for(int i = 0; i < supportCount; i++)
    {
        string name = StringFormat("SR_Support_%d", i);
        
        // Calculer la largeur de la zone (2% du prix)
        double zoneWidth = supports[i] * 0.02;
        
        // Créer un rectangle pour la zone de support
        if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, 0, 0, 0, 0))
        {
            // Créer le rectangle avec les coordonnées directement
            if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, 
                           TimeCurrent() - PeriodSeconds() * InpSRZoneLookback, supports[i] + zoneWidth,
                           TimeCurrent() + PeriodSeconds() * 24, supports[i] - zoneWidth))
            {
                Print("Erreur création rectangle support: ", GetLastError());
                continue;
            }
            
            // Style du rectangle
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime); // Bordure verte
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrLime); // Remplissage vert
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Épaisseur de la bordure
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            
            // Ajouter une étiquette avec le prix
            string labelName = name + "_Label";
            if(ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent() - PeriodSeconds() * InpSRZoneLookback, supports[i]))
            {
                ObjectSetString(0, labelName, OBJPROP_TEXT, "S " + DoubleToString(supports[i], _Digits));
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
                ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
                ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            }
        }
    }
    
    // Tracer les zones de résistance (rectangles rouges avec transparence)
    for(int i = 0; i < resistanceCount; i++)
    {
        string name = StringFormat("SR_Resistance_%d", i);
        
        // Calculer la largeur de la zone (2% du prix)
        double zoneWidth = resistances[i] * 0.02;
        
        // Créer un rectangle pour la zone de résistance
        if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, 0, 0, 0, 0))
        {
            // Créer le rectangle avec les coordonnées directement
            if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, 
                           TimeCurrent() - PeriodSeconds() * InpSRZoneLookback, resistances[i] + zoneWidth,
                           TimeCurrent() + PeriodSeconds() * 24, resistances[i] - zoneWidth))
            {
                Print("Erreur création rectangle résistance: ", GetLastError());
                continue;
            }
            
            // Style du rectangle
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed); // Bordure rouge
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrRed); // Remplissage rouge
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Épaisseur de la bordure
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            
            // Ajouter une étiquette avec le prix
            string labelName = name + "_Label";
            if(ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent() - PeriodSeconds() * InpSRZoneLookback, resistances[i]))
            {
                ObjectSetString(0, labelName, OBJPROP_TEXT, "R " + DoubleToString(resistances[i], _Digits));
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
                ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
                ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifie si une position existe déjà pour un symbole et un type donnés |
//+------------------------------------------------------------------+
bool HasPosition(string symbol, ENUM_POSITION_TYPE positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_TYPE) == positionType)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie les opportunités de trading basées sur les order blocks  |
//+------------------------------------------------------------------+
void CheckOrderBlockTrades()
{
   if(!InpEnableOrderBlockTrading) return;
   
   // Utiliser l'objet CTrade global
   
   string symbol = _Symbol;
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Seulement vérifier sur une nouvelle bougie pour éviter des entrées multiples
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(symbol, PERIOD_CURRENT, 0);
   if(lastBarTime == currentBarTime) return;
   lastBarTime = currentBarTime;
   
   // Vérifier si le trading est autorisé
   if(!CanPlaceNewOrder(symbol, 0)) return;
   
   // Obtenir les order blocks détectés
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_CURRENT, 0, 200, rates) < 200) return;
   
   // Vérifier chaque order block
   for(int i = ObjectsTotal(0, 0, -1)-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "OB_") != 0) continue;
      
      // Récupérer les propriétés de l'order block
      double obHigh = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      double obLow = ObjectGetDouble(0, name, OBJPROP_PRICE, 3);
      bool isBullish = (ObjectGetInteger(0, name, OBJPROP_COLOR) == clrLime);
      
      // Vérifier si le prix est proche d'un order block
      double distanceToOb = 0;
      int signal = 0; // 0 = pas de signal, 1 = achat, -1 = vente
      
      if(isBullish)
      {
         // Pour un order block haussier, on cherche une opportunité d'achat
         if(bid <= obHigh + 10*point && bid >= obLow - 10*point)
         {
            signal = 1; // Signal d'achat
            distanceToOb = (bid - obLow) / (obHigh - obLow);
         }
      }
      else
      {
         // Pour un order block baissier, on cherche une opportunité de vente
         if(ask >= obLow - 10*point && ask <= obHigh + 10*point)
         {
            signal = -1; // Signal de vente
            distanceToOb = (obHigh - ask) / (obHigh - obLow);
         }
      }
      
      // Si on a un signal et qu'on est dans une bonne zone de l'order block
      if(signal != 0 && distanceToOb >= 0.3 && distanceToOb <= 0.7)
      {
         // Calculer la taille de position et les niveaux de SL/TP
         double lotSize = CalculateOptimalLotSize(symbol, InpStopLossUSD);
         if(lotSize <= 0) return;
         double sl = 0, tp = 0;
         
         if(signal == 1) // Achat
         {
            sl = obLow - 5*point;
            tp = ask + (ask - sl) * 2.0; // Ratio risque/rendement de 1:2 par défaut
            
            // Vérifier si on a déjà une position sur ce symbole
            if(!HasPosition(symbol, POSITION_TYPE_BUY))
            {
               trade.Buy(lotSize, symbol, ask, sl, tp, "OrderBlock Buy");
               Print("📈 Ordre d'achat exécuté sur ", symbol, " basé sur order block haussier");
            }
         }
         else // Vente
         {
            sl = obHigh + 5*point;
            tp = bid - (sl - bid) * 2.0; // Ratio risque/rendement de 1:2 par défaut
            
            // Vérifier si on a déjà une position sur ce symbole
            if(!HasPosition(symbol, POSITION_TYPE_SELL))
            {
               trade.Sell(lotSize, symbol, bid, sl, tp, "OrderBlock Sell");
               Print("📉 Ordre de vente exécuté sur ", symbol, " basé sur order block baissier");
            }
         }
         
         // Sortir après avoir traité le premier order block valide
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction OnTick originale (sauvegardée)                          |
//+------------------------------------------------------------------+
void OnTick_Original()
{
   // Afficher le statut du trading toutes les 5 secondes
   PrintTradingStatus();
   
   // Vérifier que le trading est activé
   if(!InpEnableTrading) return;
   
   // PROTECTION STRICTE : UN SEUL TRADE AUTORISÉ À LA FOIS
   if(HasAnyEAPosition())
   {
      // Gérer seulement les positions existantes, pas de nouveaux trades
      CleanupClosedPositions();
      if(InpEnableBoomCrashDetection)
         ManageBoomCrashPositions();
      
      // FERMETURE AUTOMATIQUE DES SPIKE EN GAIN
      CloseSpikePositionsInProfit();
      return;
   }
   
   // Nettoyer les positions fermées du suivi des modifications
   CleanupClosedPositions();
   
   // Gestion des positions Boom/Crash
   if(InpEnableBoomCrashDetection)
      ManageBoomCrashPositions();
   
   // Vérifier les opportunités de trading basées sur les order blocks
   CheckOrderBlockTrades();
   
   // Mise à jour de l'affichage HUD
   if(InpShowHUD)
      DrawAngelHUD();
}

//+------------------------------------------------------------------+
//| Traitement des trades pour les symboles Boom/Crash               |
//+------------------------------------------------------------------+
void ProcessBoomCrashTrading(const string symbol)
{
   // Vérifier les conditions de base
   if(!CanPlaceNewOrder(symbol, 0)) return;
   
   // Détecter les signaux de spike
   int spikeDirection = 0;
   if(DetectSpikeNow(symbol, spikeDirection))
   {
      // Vérifier la direction pour Boom/Crash
      if(!IsDirectionAllowedBC(symbol, spikeDirection)) return;
      
      // Calculer le lot et les niveaux SL/TP
      double lotSize = CalculateScalpingLotSize(symbol);
      double entryPrice = (spikeDirection == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(symbol, SYMBOL_BID);
      
      double sl = 0.0, tp = 0.0;
      if(!CalculateScalpingSLTP(symbol, spikeDirection, entryPrice, lotSize, sl, tp))
      {
         if(InpDebug) Print("❌ Impossible de calculer SL/TP pour ", symbol);
         return;
      }
      
      // Exécuter le trade
      g_trade.SetExpertMagicNumber(InpMagicNumber);
      g_trade.SetDeviationInPoints(InpSlippagePoints);
      
      bool success = false;
      if(spikeDirection == POSITION_TYPE_BUY)
         success = g_trade.Buy(lotSize, symbol, entryPrice, sl, tp, "Boom/Crash Spike");
      else
         success = g_trade.Sell(lotSize, symbol, entryPrice, sl, tp, "Boom/Crash Spike");
      
      if(success)
      {
         Print("✅ Trade Boom/Crash exécuté: ", symbol, " Direction: ", 
               (spikeDirection == POSITION_TYPE_BUY ? "Achat" : "Vente"), " Lot: ", lotSize);
      }
      else
      {
         Print("❌ Erreur d'exécution Boom/Crash: ", 
               ErrorDescription(g_trade.ResultRetcode()));
      }
   }
}

//+------------------------------------------------------------------+
//| Traitement des trades pour les autres symboles                   |
//+------------------------------------------------------------------+
void ProcessOtherSymbolTrading(const string symbol)
{
   // Vérifier les conditions de base
   if(!CanPlaceNewOrder(symbol, 0)) return;
   
   // Détecter les signaux de spike pour les autres symboles
   int spikeDirection = 0;
   if(DetectSpikeNow(symbol, spikeDirection))
   {
      // Calculer le lot et les niveaux SL/TP
      double lotSize = CalculateScalpingLotSize(symbol);
      double entryPrice = (spikeDirection == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(symbol, SYMBOL_BID);
      
      double sl = 0.0, tp = 0.0;
      if(!CalculateScalpingSLTP(symbol, spikeDirection, entryPrice, lotSize, sl, tp))
      {
         if(InpDebug) Print("❌ Impossible de calculer SL/TP pour ", symbol);
         return;
      }
      
      // Exécuter le trade
      g_trade.SetExpertMagicNumber(InpMagicNumber);
      g_trade.SetDeviationInPoints(InpSlippagePoints);
      
      bool success = false;
      if(spikeDirection == POSITION_TYPE_BUY)
         success = g_trade.Buy(lotSize, symbol, entryPrice, sl, tp, "Other Symbol Spike");
      else
         success = g_trade.Sell(lotSize, symbol, entryPrice, sl, tp, "Other Symbol Spike");
      
      if(success)
      {
         Print("✅ Trade autre symbole exécuté: ", symbol, " Direction: ", 
               (spikeDirection == POSITION_TYPE_BUY ? "Achat" : "Vente"), " Lot: ", lotSize);
      }
      else
      {
         Print("❌ Erreur d'exécution autre symbole: ", 
               ErrorDescription(g_trade.ResultRetcode()));
      }
   }
}

//+------------------------------------------------------------------+
//| Fermer les positions après capture de spike                      |
//+------------------------------------------------------------------+
void ClosePositionAfterSpikeCapture()
{
    if(!InpAutoClosePositions) return;
    
    CPositionInfo pos;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == InpMagicNumber)
            {
                double currentPrice = (pos.PositionType() == POSITION_TYPE_BUY) ? 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_BID) : 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_ASK);
                double entryPrice = pos.PriceOpen();
                double profit = pos.Profit();
                
                // Vérifier si le spike a été capturé
                if (profit >= InpTargetProfitUSD || 
                    (pos.PositionType() == POSITION_TYPE_BUY && currentPrice > entryPrice + (SymbolInfoDouble(pos.Symbol(), SYMBOL_POINT) * 100)) || 
                    (pos.PositionType() == POSITION_TYPE_SELL && currentPrice < entryPrice - (SymbolInfoDouble(pos.Symbol(), SYMBOL_POINT) * 100)))
                {
                    if(g_trade.PositionClose(pos.Ticket()))
                    {
                        Print("POSITION FERMEE APRES SPIKE: ", pos.Symbol(), " Ticket: ", pos.Ticket(), " Profit: ", DoubleToString(profit, 2));
                    }
                    else
                    {
                        Print("ECHEC FERMETURE POSITION APRES SPIKE: ", pos.Symbol(), " Erreur: ", g_trade.ResultRetcode());
                    }
                }
                // Fermeture en cas de perte maximale
                else if (profit <= -InpMaxLossPerTradeUSD)
                {
                    if(g_trade.PositionClose(pos.Ticket()))
                    {
                        Print("POSITION FERMEE EN PERTE MAX: ", pos.Symbol(), " Ticket: ", pos.Ticket(), " Perte: ", DoubleToString(profit, 2));
                    }
                    else
                    {
                        Print("ECHEC FERMETURE POSITION EN PERTE MAX: ", pos.Symbol(), " Erreur: ", g_trade.ResultRetcode());
                    }
                }
            }
        }
    }
}
