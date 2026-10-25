//+------------------------------------------------------------------+
//| Angel of Spike - Autonomous Spike Hunter EA                      |
//|                     avec détection ultra-réactive des spikes      |
//|                     et gestion optimisée des positions            |
//+------------------------------------------------------------------+
#property copyright "AngelOfSpike Team"
#property version   "2.0"
#property description "EA autonome pour la chasse aux spikes avec détection avancée"

#include <Trade\Trade.mqh>

//--- Variables globales
CTrade g_trade;
datetime g_lastBarTime = 0;
int g_tradesToday = 0;
datetime g_lastTradeDay = 0;

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

input group "=== GESTION DU RISQUE ==="
input double InpMaxLotSize = 0.10;          // Taille maximale des lots
input double InpMinLotSize = 0.01;          // Taille minimale des lots
input int    InpSlippagePoints = 3;         // Slippage maximum en points
input double InpMaxSpread = 10.0;           // Spread maximum autorisé (points)

input group "=== FILTRES DE TRADING ==="
input bool   InpUseVolumeFilter = true;      // Utiliser le filtre de volume
input bool   InpUseVelocityFilter = true;    // Utiliser le filtre de vélocité
input bool   InpUsePivotFilter = true;       // Utiliser le filtre de pivot
input bool   InpUseEMAFilter = true;         // Utiliser le filtre EMA

input group "=== SYMBOLES ADDITIONNELS ==="
input bool   InpTradeOtherSymbols = false;   // Trader sur d'autres symboles
input string InpOtherSymbols = "EURUSD,GBPJPY"; // Symboles additionnels

//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'EA                                 |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Configuration du trading
   g_trade.SetExpertMagicNumber(12345);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   //--- Initialisation des variables
   g_lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_tradesToday = 0;
   g_lastTradeDay = TimeCurrent();
   
   //--- Vérification des paramètres
   if(InpRiskPercent <= 0 || InpRiskPercent > 10)
   {
      Print("❌ Erreur: InpRiskPercent doit être entre 0.1 et 10");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(InpMaxLotSize < InpMinLotSize)
   {
      Print("❌ Erreur: InpMaxLotSize doit être >= InpMinLotSize");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   Print("🚀 Angel of Spike initialisé avec succès");
   Print("📊 Paramètres: Risque=", InpRiskPercent, "%, MaxLots=", InpMaxLotSize);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Nettoyage des objets graphiques
   ObjectsDeleteAll(0, "AngelOfSpike_");
   
   Print("👋 Angel of Spike désactivé");
}

//+------------------------------------------------------------------+
//| Fonction principale - Tick par tick                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Vérifier si le trading est activé
   if(!InpEnableSpikeTrading || !InpEnableAutoTrading)
      return;
   
   //--- Vérifier si nouvelle barre (pour éviter les traitements multiples)
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;
   
   //--- Réinitialiser le compteur quotidien si nouveau jour
   if(TimeDay(TimeCurrent()) != TimeDay(g_lastTradeDay))
   {
      g_tradesToday = 0;
      g_lastTradeDay = TimeCurrent();
   }
   
   //--- Vérifier la limite de trades quotidiens
   if(g_tradesToday >= InpMaxTradesPerDay)
   {
      Print("📊 Limite de trades quotidiens atteinte: ", g_tradesToday, "/", InpMaxTradesPerDay);
      return;
   }
   
   //--- Vérifier le spread
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(spread > InpMaxSpread)
   {
      Print("📊 Spread trop élevé: ", spread, " > ", InpMaxSpread);
      return;
   }
   
   //--- Générer et traiter les signaux de trading
   int signal = GenerateTradingSignal();
   
   if(signal != 0)
   {
      //--- Exécuter le trade selon le signal
      ExecuteSignal(signal);
   }
   
   //--- Gérer les positions existantes
   ManageExistingPositions();
   
   //--- Mettre à jour les indicateurs visuels
   if(InpShowIndicators)
   {
      UpdateVisualIndicators();
   }
}

//+------------------------------------------------------------------+
//| Génère les signaux de trading                                     |
//+------------------------------------------------------------------+
int GenerateTradingSignal()
{
   //--- Récupérer les données de marché
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, InpVelocityBars + 10, rates) < InpVelocityBars + 10)
      return 0;
   
   //--- Calculer les indicateurs
   double volumeRatio = CalculateVolumeRatio(rates);
   double rangeRatio = CalculateRangeRatio(rates);
   double velocity = CalculateVelocity(rates);
   double pivot = CalculatePivot(rates);
   
   //--- Filtrage des signaux
   if(InpUseVolumeFilter && volumeRatio < InpSpikeMinVolumeRatio)
      return 0;
   
   if(InpUseVelocityFilter && velocity < InpVelocityPercent)
      return 0;
   
   if(InpUsePivotFilter && !IsNearPivot(rates[0].close, pivot))
      return 0;
   
   if(InpUseEMAFilter && !IsEMAAligned())
      return 0;
   
   //--- Détection des spikes
   bool spikeDetected = (volumeRatio >= InpSpikeMinVolumeRatio && rangeRatio >= InpSpikeMinRangeRatio);
   
   if(!spikeDetected)
      return 0;
   
   //--- Déterminer la direction du signal
   int signal = 0;
   if(rates[0].close > rates[0].open && velocity > InpVelocityPercent)
   {
      signal = 1; // Signal d'achat
   }
   else if(rates[0].close < rates[0].open && velocity > InpVelocityPercent)
   {
      signal = -1; // Signal de vente
   }
   
   //--- Afficher les informations de signal
   if(signal != 0 && InpShowTradingInfo)
   {
      Print("🎯 Signal détecté: ", signal > 0 ? "ACHAT" : "VENTE");
      Print("📊 Volume: ", volumeRatio, " Range: ", rangeRatio, " Vélocité: ", velocity);
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| Exécute un signal de trading                                      |
//+------------------------------------------------------------------+
void ExecuteSignal(int signal)
{
   //--- Calculer la taille du lot
   double lotSize = CalculateLotSize();
   if(lotSize <= 0)
      return;
   
   //--- Déterminer les niveaux de prix
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double entryPrice = (signal > 0) ? ask : bid;
   double sl = (signal > 0) ? entryPrice - InpStopLoss * point : entryPrice + InpStopLoss * point;
   double tp = (signal > 0) ? entryPrice + InpTakeProfit * point : entryPrice - InpTakeProfit * point;
   
   //--- Exécuter le trade
   bool success = false;
   if(signal > 0)
   {
      success = g_trade.Buy(lotSize, _Symbol, entryPrice, sl, tp, "AngelOfSpike BUY");
   }
   else
   {
      success = g_trade.Sell(lotSize, _Symbol, entryPrice, sl, tp, "AngelOfSpike SELL");
   }
   
   if(success)
   {
      g_tradesToday++;
      Print("✅ Trade exécuté: ", signal > 0 ? "ACHAT" : "VENTE", " Lot: ", lotSize);
      
      //--- Envoyer une notification
      if(InpShowNotification)
      {
         string notification = StringFormat("AngelOfSpike: %s %s @%.5f", 
                                           _Symbol, 
                                           signal > 0 ? "BUY" : "SELL", 
                                           entryPrice);
         SendNotification(notification);
      }
   }
   else
   {
      Print("❌ Erreur d'exécution: ", g_trade.ResultRetcode(), " - ", g_trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Gère les positions existantes                                     |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         
         //--- Vérifier si c'est une position de notre EA
         if(magic == g_trade.RequestMagic() && symbol == _Symbol)
         {
            //--- Gérer le trailing stop
            if(InpUseTrailingStop)
            {
               ManageTrailingStop();
            }
            
            //--- Fermeture automatique si nécessaire
            CheckAutoClose();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gère le trailing stop                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   double positionPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentSL = PositionGetDouble(POSITION_SL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double newSL = 0;
   bool needModify = false;
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      //--- Position BUY
      if(currentPrice - positionPrice >= InpTrailingStart * point)
      {
         newSL = currentPrice - InpTrailingStopPts * point;
         if(newSL > currentSL + InpTrailingStep * point)
         {
            needModify = true;
         }
      }
   }
   else
   {
      //--- Position SELL
      if(positionPrice - currentPrice >= InpTrailingStart * point)
      {
         newSL = currentPrice + InpTrailingStopPts * point;
         if(newSL < currentSL - InpTrailingStep * point || currentSL == 0)
         {
            needModify = true;
         }
      }
   }
   
   if(needModify && newSL > 0)
   {
      if(g_trade.PositionModify(PositionGetTicket(POSITION_TICKET), newSL, PositionGetDouble(POSITION_TP)))
      {
         Print("🔄 Trailing stop modifié: ", newSL);
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie la fermeture automatique                                  |
//+------------------------------------------------------------------+
void CheckAutoClose()
{
   double positionPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double profitPoints = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                        (currentPrice - positionPrice) / point : 
                        (positionPrice - currentPrice) / point;
   
   //--- Fermeture si profit rapide atteint
   if(profitPoints >= InpQuickTP1 / point)
   {
      if(g_trade.PositionClose(PositionGetTicket(POSITION_TICKET)))
      {
         Print("💰 Fermeture rapide: profit de ", profitPoints, " points");
      }
   }
}

//+------------------------------------------------------------------+
//| Fonctions de calcul des indicateurs                               |
//+------------------------------------------------------------------+
double CalculateVolumeRatio(MqlRates &rates[])
{
   if(ArraySize(rates) < InpVelocityBars + 1)
      return 0;
   
   double avgVolume = 0;
   for(int i = 1; i <= InpVelocityBars; i++)
   {
      avgVolume += rates[i].tick_volume;
   }
   avgVolume /= InpVelocityBars;
   
   return (avgVolume > 0) ? rates[0].tick_volume / avgVolume : 0;
}

double CalculateRangeRatio(MqlRates &rates[])
{
   if(ArraySize(rates) < InpVelocityBars + 1)
      return 0;
   
   double avgRange = 0;
   for(int i = 1; i <= InpVelocityBars; i++)
   {
      avgRange += rates[i].high - rates[i].low;
   }
   avgRange /= InpVelocityBars;
   
   return (avgRange > 0) ? (rates[0].high - rates[0].low) / avgRange : 0;
}

double CalculateVelocity(MqlRates &rates[])
{
   if(ArraySize(rates) < InpVelocityBars + 1)
      return 0;
   
   double totalMove = 0;
   for(int i = 1; i <= InpVelocityBars; i++)
   {
      totalMove += MathAbs(rates[i].close - rates[i].open);
   }
   
   double avgMove = totalMove / InpVelocityBars;
   double currentMove = MathAbs(rates[0].close - rates[0].open);
   
   return (avgMove > 0) ? (currentMove / avgMove) * 100 : 0;
}

double CalculatePivot(MqlRates &rates[])
{
   if(ArraySize(rates) < InpPivotBars + 1)
      return rates[0].close;
   
   double high = rates[0].high;
   double low = rates[0].low;
   
   for(int i = 1; i <= InpPivotBars; i++)
   {
      if(rates[i].high > high) high = rates[i].high;
      if(rates[i].low < low) low = rates[i].low;
   }
   
   return (high + low) / 2;
}

bool IsNearPivot(double price, double pivot)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double distance = MathAbs(price - pivot) / point;
   return distance <= InpPivotBuffer;
}

bool IsEMAAligned()
{
   double ema1[], ema2[], ema3[];
   int handle1 = iMA(_Symbol, PERIOD_CURRENT, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);
   int handle2 = iMA(_Symbol, PERIOD_CURRENT, InpEMA2, 0, MODE_EMA, PRICE_CLOSE);
   int handle3 = iMA(_Symbol, PERIOD_CURRENT, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handle1 == INVALID_HANDLE || handle2 == INVALID_HANDLE || handle3 == INVALID_HANDLE)
      return false;
   
   ArraySetAsSeries(ema1, true);
   ArraySetAsSeries(ema2, true);
   ArraySetAsSeries(ema3, true);
   
   if(CopyBuffer(handle1, 0, 0, 2, ema1) < 2 || 
      CopyBuffer(handle2, 0, 0, 2, ema2) < 2 || 
      CopyBuffer(handle3, 0, 0, 2, ema3) < 2)
   {
      IndicatorRelease(handle1);
      IndicatorRelease(handle2);
      IndicatorRelease(handle3);
      return false;
   }
   
   //--- Vérifier l'alignement des EMA
   bool aligned = (ema1[0] > ema2[0] && ema2[0] > ema3[0]) || 
                  (ema1[0] < ema2[0] && ema2[0] < ema3[0]);
   
   IndicatorRelease(handle1);
   IndicatorRelease(handle2);
   IndicatorRelease(handle3);
   
   return aligned;
}

//+------------------------------------------------------------------+
//| Calcule la taille du lot                                         |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * InpRiskPercent / 100;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0)
      return InpMinLotSize;
   
   double lotSize = riskAmount / (InpStopLoss * tickValue / tickSize);
   
   //--- Limiter la taille du lot
   if(lotSize < InpMinLotSize) lotSize = InpMinLotSize;
   if(lotSize > InpMaxLotSize) lotSize = InpMaxLotSize;
   
   //--- Arrondir au pas de lot valide
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Met à jour les indicateurs visuels                               |
//+------------------------------------------------------------------+
void UpdateVisualIndicators()
{
   //--- Afficher les informations de trading
   string info = StringFormat("AngelOfSpike v2.0\n"
                             "Trades aujourd'hui: %d/%d\n"
                             "Risque: %.1f%%\n"
                             "Spread: %.1f",
                             g_tradesToday, InpMaxTradesPerDay,
                             InpRiskPercent,
                             (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   
   ObjectCreate(0, "AngelOfSpike_Info", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "AngelOfSpike_Info", OBJPROP_TEXT, info);
   ObjectSetInteger(0, "AngelOfSpike_Info", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "AngelOfSpike_Info", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "AngelOfSpike_Info", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "AngelOfSpike_Info", OBJPROP_FONTSIZE, 9);
}

//+------------------------------------------------------------------+
