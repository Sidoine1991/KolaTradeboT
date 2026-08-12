//+------------------------------------------------------------------+
//|                                F_INX_RapidCompound.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "3.00 - RAPID COMPOUND"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES POUR COMPOUNDING RAPIDE                               |
//+------------------------------------------------------------------+
input group "=== STRATÉGIE COMPOUNDING ==="
input double BaseLotSize       = 0.01;        // Lot de base
input double MaxLotSize        = 1.0;         // Lot maximum
input double QuickProfitTarget = 0.50;       // Profit cible rapide ($)
input double CompoundMultiplier = 1.5;        // Multiplicateur de lot après profit
input int    MaxCompoundLevels = 5;           // Niveaux max de compound

input group "=== GESTION RAPIDE ==="
input double QuickStopLoss    = 30;          // Stop Loss rapide (points)
input double QuickTakeProfit  = 90;          // Take Profit rapide (ratio 3:1)
input int    MaxPositions     = 3;           // Max positions simultanées
input double DailyProfitTarget = 100.0;      // Objectif profit quotidien

input group "=== FILTRES SIGNALS ==="
input int    FastEMA          = 9;           // EMA ultra-rapide
input int    SlowEMA          = 21;          // EMA rapide
input int    RSIPeriod        = 7;           // RSI court pour réactivité
input double RSIOverbought    = 75;          // RSI surachat
input double RSIOversold      = 25;          // RSI survente

input group "=== SESSIONS INTENSIVES ==="
input bool   UseHighVolumeSessions = true;   // Sessions haut volume
input int    StartHour         = 8;           // Début session
input int    EndHour           = 22;          // Fin session (étendue)

input group "=== COMPOUNDING AVANCÉ ==="
input bool   EnableAutoCompound = true;      // Activer compound automatique
input double CompoundThreshold = 0.30;       // Seuil de compound ($)
input bool   UsePyramiding     = true;       // Ajouter des positions
input int    PyramidMaxPositions = 2;        // Max positions pyramides

input group "=== DEBUG ==="
input bool   DebugMode         = true;       // Logs détaillés

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

// Variables de compound
static double currentLotSize = 0.01;
static int compoundLevel = 0;
static double dailyProfit = 0;
static datetime lastResetDate = 0;
static double totalCompoundProfit = 0;

// Variables de timing
static datetime lastCompoundTime = 0;
static int rapidTradeCount = 0;

// Indicateurs
static int emaFastHandle;
static int emaSlowHandle;
static int rsiHandle;

// Structure pour suivi des positions rapides
struct RapidPosition {
   ulong ticket;
   double entryPrice;
   double lotSize;
   datetime openTime;
   double targetProfit;
   bool isPyramid;
};

static RapidPosition rapidPositions[];

//+------------------------------------------------------------------+
//| INITIALISATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(888888);
   trade.SetDeviationInPoints(10);
   
   // Initialiser les indicateurs rapides
   emaFastHandle = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   
   if(emaFastHandle < 0 || emaSlowHandle < 0 || rsiHandle < 0)
   {
      Print("❌ Erreur initialisation indicateurs");
      return INIT_FAILED;
   }
   
   currentLotSize = BaseLotSize;
   ArrayResize(rapidPositions, MaxPositions);
   
   Print("✅ F_INX_RapidCompound initialisé");
   Print("📊 Lot de base: ", BaseLotSize, " | Target rapide: ", QuickProfitTarget, "$");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| TICK PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les compteurs quotidiens
   ResetDailyCounters();
   
   // Mettre à jour le profit quotidien
   UpdateDailyProfit();
   
   // Vérifier si le trading est autorisé
   if(!IsTradingAllowed()) return;
   
   // Vérifier les profits rapides et compound
   CheckQuickProfitsAndCompound();
   
   // Récupérer les données des indicateurs
   double emaFast[], emaSlow[], rsi[];
   ArrayResize(emaFast, 3);
   ArrayResize(emaSlow, 3);
   ArrayResize(rsi, 3);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) < 3 ||
      CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) < 3 ||
      CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3)
   {
      return;
   }
   
   // Stratégie de trading rapide
   CheckRapidTradingSignals(emaFast, emaSlow, rsi);
}

//+------------------------------------------------------------------+
//| RÉINITIALISATION COMPTEURS QUOTIDIENS                             |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   
   if(today != lastResetDate)
   {
      dailyProfit = 0;
      totalCompoundProfit = 0;
      compoundLevel = 0;
      currentLotSize = BaseLotSize;
      rapidTradeCount = 0;
      lastResetDate = today;
      
      if(DebugMode) 
      {
         Print("📅 Réinitialisation quotidienne - Compound réinitialisé");
         Print("🔄 Lot size remis à: ", BaseLotSize);
      }
   }
}

//+------------------------------------------------------------------+
//| METTRE À JOUR PROFIT QUOTIDIEN                                   |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
   double totalProfit = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 888888)
         {
            totalProfit += position.Profit();
         }
      }
   }
   
   dailyProfit = totalProfit;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI LE TRADING EST AUTORISÉ                              |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Vérifier l'objectif quotidien
   if(dailyProfit >= DailyProfitTarget)
   {
      if(DebugMode) Print("🎯 Objectif quotidien atteint: ", dailyProfit, "$");
      return false;
   }
   
   // Vérifier les sessions
   if(UseHighVolumeSessions && !IsInHighVolumeSession())
   {
      if(DebugMode) Print("⏰ Hors session de haut volume");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SESSION HAUT VOLUME                                      |
//+------------------------------------------------------------------+
bool IsInHighVolumeSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   return (dt.hour >= StartHour && dt.hour < EndHour);
}

//+------------------------------------------------------------------+
//| VÉRIFIER PROFITS RAPIDES ET COMPOUND                              |
//+------------------------------------------------------------------+
void CheckQuickProfitsAndCompound()
{
   double totalProfit = 0;
   int positionCount = 0;
   
   // Calculer le profit total des positions actuelles
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 888888)
         {
            totalProfit += position.Profit();
            positionCount++;
         }
      }
   }
   
   // Vérifier si on atteint le seuil de compound
   if(EnableAutoCompound && totalProfit >= CompoundThreshold && positionCount > 0)
   {
      // Vérifier si assez de temps s'est écoulé depuis le dernier compound
      if(TimeCurrent() - lastCompoundTime > 60) // 1 minute minimum
      {
         ExecuteCompoundStrategy(totalProfit);
         lastCompoundTime = TimeCurrent();
      }
   }
   
   // Fermer les positions qui atteignent l'objectif rapide
   if(totalProfit >= QuickProfitTarget)
   {
      CloseAndReopenPositions(totalProfit);
   }
}

//+------------------------------------------------------------------+
//| EXÉCUTER STRATÉGIE DE COMPOUND                                   |
//+------------------------------------------------------------------+
void ExecuteCompoundStrategy(double currentProfit)
{
   if(compoundLevel >= MaxCompoundLevels)
   {
      if(DebugMode) Print("📊 Niveau maximum de compound atteint: ", MaxCompoundLevels);
      return;
   }
   
   // Augmenter le lot size
   double newLotSize = MathMin(currentLotSize * CompoundMultiplier, MaxLotSize);
   
   if(newLotSize > currentLotSize)
   {
      compoundLevel++;
      currentLotSize = newLotSize;
      totalCompoundProfit += currentProfit;
      
      if(DebugMode)
      {
         Print("🚀 COMPOUND Niveau ", compoundLevel, " activé!");
         Print("💰 Profit utilisé: ", DoubleToString(currentProfit, 2), "$");
         Print("📈 Nouveau lot size: ", DoubleToString(currentLotSize, 3));
         Print("🎯 Total compound: ", DoubleToString(totalCompoundProfit, 2), "$");
      }
      
      // Envoyer notification
      string message = StringFormat("COMPOUND Lv%d - Lot: %.3f - Profit: %.2f$", 
                                   compoundLevel, currentLotSize, totalCompoundProfit);
      SendNotification(message);
      
      // Ajouter des positions pyramides si activé
      if(UsePyramiding && positionCount < PyramidMaxPositions)
      {
         AddPyramidPosition();
      }
   }
}

//+------------------------------------------------------------------+
//| FERMER ET ROUVRIR POSITIONS                                       |
//+------------------------------------------------------------------+
void CloseAndReopenPositions(double totalProfit)
{
   if(DebugMode) 
   {
      Print("💰 Profit rapide atteint: ", DoubleToString(totalProfit, 2), "$");
      Print("🔄 Fermeture et réouverture des positions...");
   }
   
   // Fermer toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 888888)
         {
            ENUM_POSITION_TYPE posType = position.PositionType();
            double lotSize = position.Volume();
            
            // Fermer la position
            if(trade.PositionClose(position.Ticket()))
            {
               rapidTradeCount++;
               
               // Rouvrir immédiatement avec le lot size actuel
               ReopenPosition(posType, lotSize);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
|// ROUVRIR POSITION                                                  |
//+------------------------------------------------------------------+
void ReopenPosition(ENUM_POSITION_TYPE posType, double lotSize)
{
   double price, sl, tp;
   
   if(posType == POSITION_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - QuickStopLoss * _Point;
      tp = price + QuickTakeProfit * _Point;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + QuickStopLoss * _Point;
      tp = price - QuickTakeProfit * _Point;
   }
   
   bool result = false;
   if(posType == POSITION_TYPE_BUY)
   {
      result = SafeTradeBuy(lotSize, _Symbol, price, sl, tp, "Rapid Compound BUY");
   }
   else
   {
      result = SafeTradeSell(lotSize, _Symbol, price, sl, tp, "Rapid Compound SELL");
   }
   
   if(result)
   {
      if(DebugMode) 
      {
         Print("✅ Position réouverte - Type: ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL");
         Print("📊 Lot: ", lotSize, " | SL: ", sl, " | TP: ", tp);
      }
   }
}

//+------------------------------------------------------------------+
//| AJOUTER POSITION PYRAMIDE                                         |
//+------------------------------------------------------------------+
void AddPyramidPosition()
{
   // Détecter la direction de la tendance actuelle
   double emaFast[], emaSlow[];
   ArrayResize(emaFast, 2);
   ArrayResize(emaSlow, 2);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) < 2 ||
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) < 2)
   {
      return;
   }
   
   ENUM_POSITION_TYPE pyramidType = POSITION_TYPE_BUY;
   
   if(emaFast[1] > emaSlow[1])
   {
      pyramidType = POSITION_TYPE_BUY;
   }
   else
   {
      pyramidType = POSITION_TYPE_SELL;
   }
   
   // Ouvrir une position pyramide avec lot size réduit
   double pyramidLot = currentLotSize * 0.5; // 50% du lot actuel
   
   if(DebugMode) Print("🔺 Ajout position pyramide - Lot: ", pyramidLot);
   
   ReopenPosition(pyramidType, pyramidLot);
}

//+------------------------------------------------------------------+
//| VÉRIFIER SIGNAUX RAPIDES                                          |
//+------------------------------------------------------------------+
void CheckRapidTradingSignals(double &emaFast[], double &emaSlow[], double &rsi[])
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentRSI = rsi[2];
   
   // Compter les positions actuelles
   int currentPositions = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 888888)
            currentPositions++;
      }
   }
   
   // Signal BUY ultra-rapide
   if(emaFast[2] > emaSlow[2] && emaFast[1] <= emaSlow[1] && 
      currentRSI < RSIOverbought && currentRSI > 40)
   {
      if(currentPositions < MaxPositions)
      {
         if(DebugMode) 
         {
            Print("⚡ Signal BUY ultra-rapide:");
            Print("   EMA Fast: ", emaFast[2], " > EMA Slow: ", emaSlow[2]);
            Print("   RSI: ", currentRSI, " | Lot: ", currentLotSize);
         }
         
         OpenRapidPosition(POSITION_TYPE_BUY);
      }
   }
   
   // Signal SELL ultra-rapide
   else if(emaFast[2] < emaSlow[2] && emaFast[1] >= emaSlow[1] && 
           currentRSI > RSIOversold && currentRSI < 60)
   {
      if(currentPositions < MaxPositions)
      {
         if(DebugMode) 
         {
            Print("⚡ Signal SELL ultra-rapide:");
            Print("   EMA Fast: ", emaFast[2], " < EMA Slow: ", emaSlow[2]);
            Print("   RSI: ", currentRSI, " | Lot: ", currentLotSize);
         }
         
         OpenRapidPosition(POSITION_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| OUVRIR POSITION RAPIDE                                            |
//+------------------------------------------------------------------+
void OpenRapidPosition(ENUM_POSITION_TYPE posType)
{
   double price, sl, tp;
   
   if(posType == POSITION_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - QuickStopLoss * _Point;
      tp = price + QuickTakeProfit * _Point;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + QuickStopLoss * _Point;
      tp = price - QuickTakeProfit * _Point;
   }
   
   // Validation des distances minimales
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minStopLevel > 0)
   {
      if(posType == POSITION_TYPE_BUY)
      {
         if(price - sl < minStopLevel) sl = price - minStopLevel;
         if(tp - price < minStopLevel) tp = price + minStopLevel;
      }
      else
      {
         if(sl - price < minStopLevel) sl = price + minStopLevel;
         if(price - tp < minStopLevel) tp = price - minStopLevel;
      }
   }
   
   bool result = false;
   if(posType == POSITION_TYPE_BUY)
   {
      result = SafeTradeBuy(currentLotSize, _Symbol, price, sl, tp, "Rapid Compound BUY");
   }
   else
   {
      result = SafeTradeSell(currentLotSize, _Symbol, price, sl, tp, "Rapid Compound SELL");
   }
   
   if(result)
   {
      rapidTradeCount++;
      if(DebugMode) 
      {
         Print("⚡ Position rapide ouverte #", rapidTradeCount);
         Print("📊 Type: ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL");
         Print("💰 Lot: ", currentLotSize, " | Compound Lv: ", compoundLevel);
      }
   }
   else
   {
      if(DebugMode) Print("❌ Erreur ouverture rapide: ", trade.ResultComment());
   }
}

