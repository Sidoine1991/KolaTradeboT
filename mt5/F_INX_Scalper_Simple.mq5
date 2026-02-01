//+------------------------------------------------------------------+
//|                                    F_INX_Scalper_Simple.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "2.00 - SIMPLIFIÉ"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES SIMPLIFIÉS                                            |
//+------------------------------------------------------------------+
input group "=== CONFIGURATION PRINCIPALE ==="
input int    MagicNumber        = 888888;     // Magic Number
input double LotSize           = 0.01;        // Taille de lot fixe
input double StopLossPoints    = 100;         // Stop Loss en points
input double TakeProfitPoints  = 300;         // Take Profit en points (Ratio 3:1)
input double RiskPerTrade      = 2.0;         // Risque par trade en % du solde

input group "=== FILTRES DE TENDANCE ==="
input bool   UseTrendFilter    = true;        // Utiliser les filtres de tendance
input int    FastEMA           = 21;          // EMA rapide
input int    SlowEMA           = 50;          // EMA lente
input int    RSIPeriod         = 14;          // Période RSI
input double RSIOverbought     = 70;          // RSI surachat
input double RSIOversold       = 30;          // RSI survente

input group "=== FILTRE RANGE ==="
input bool   UseRangeFilter    = true;        // Détecter et éviter les ranges
input double MinRangePoints    = 50;          // Mouvement minimum pour sortir du range
input double MaxRangeSpread    = 20;          // Spread maximum des EMA pour considérer un range

input group "=== GESTION DES POSITIONS ==="
input int    MaxPositions      = 1;           // Nombre maximum de positions simultanées
input double DailyProfitTarget = 50.0;       // Objectif de profit quotidien
input double DailyLossLimit    = 20.0;        // Limite de perte quotidienne
input bool   CloseOnOppositeSignal = true;    // Fermer sur signal opposé

input group "=== SESSIONS DE TRADING ==="
input bool   UseSessionFilter  = true;        // Filtrer par sessions
input string StartHour         = "08:00";     // Heure de début
input string EndHour           = "18:00";     // Heure de fin

input group "=== DEBUG ==="
input bool   DebugMode         = true;        // Afficher les logs détaillés

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

static datetime lastTradeTime = 0;
static double dailyPL = 0;
static datetime lastResetDate = 0;

// Handle d'indicateurs
static int emaFastHandle;
static int emaSlowHandle;
static int rsiHandle;

//+------------------------------------------------------------------+
//| INITIALISATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   
   // Initialiser les indicateurs
   emaFastHandle = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   
   if(emaFastHandle < 0 || emaSlowHandle < 0 || rsiHandle < 0)
   {
      Print("❌ Erreur initialisation indicateurs");
      return INIT_FAILED;
   }
   
   Print("✅ F_INX_Scalper_Simple initialisé avec succès");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALISATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🔄 F_INX_Scalper_Simple arrêté");
}

//+------------------------------------------------------------------+
//| TICK PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les compteurs quotidiens
   ResetDailyCounters();
   
   // Vérifier les conditions de trading
   if(!IsTradingAllowed()) return;
   
   // Mettre à jour les indicateurs
   double emaFast[], emaSlow[], rsi[];
   ArrayResize(emaFast, 3);
   ArrayResize(emaSlow, 3);
   ArrayResize(rsi, 3);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) < 3 ||
      CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) < 3 ||
      CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3)
   {
      if(DebugMode) Print("❌ Erreur récupération indicateurs");
      return;
   }
   
   // Stratégie de trading simplifiée
   CheckTradingSignals(emaFast, emaSlow, rsi);
}

//+------------------------------------------------------------------+
//| RÉINITIALISATION COMPTEURS QUOTIDIENS                            |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   
   if(today != lastResetDate)
   {
      dailyPL = 0;
      lastResetDate = today;
      if(DebugMode) Print("📅 Compteurs quotidiens réinitialisés");
   }
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI LE TRADING EST AUTORISÉ                              |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Vérifier les objectifs quotidiens
   if(dailyPL >= DailyProfitTarget)
   {
      if(DebugMode) Print("🎯 Objectif quotidien atteint: ", dailyPL, "$");
      return false;
   }
   
   if(dailyPL <= -DailyLossLimit)
   {
      if(DebugMode) Print("🛑 Limite de perte quotidienne atteinte: ", dailyPL, "$");
      return false;
   }
   
   // Vérifier le nombre de positions
   int totalPositions = PositionsTotal();
   if(totalPositions >= MaxPositions)
   {
      if(DebugMode) Print("📊 Nombre maximum de positions atteint: ", totalPositions);
      return false;
   }
   
   // Vérifier les sessions de trading
   if(UseSessionFilter && !IsInTradingSession())
   {
      if(DebugMode) Print("⏰ Hors session de trading");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI ON EST DANS UNE SESSION DE TRADING                   |
//+------------------------------------------------------------------+
bool IsInTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int currentHour = dt.hour * 100 + dt.min;
   int startHour = StringToInteger(StringReplace(StartHour, ":", ""));
   int endHour = StringToInteger(StringReplace(EndHour, ":", ""));
   
   return (currentHour >= startHour && currentHour <= endHour);
}

//+------------------------------------------------------------------+
//| VÉRIFIER LES SIGNAUX DE TRADING                                   |
//+------------------------------------------------------------------+
void CheckTradingSignals(double &emaFast[], double &emaSlow[], double &rsi[])
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentRSI = rsi[2];
   
   // Vérifier si on est dans un range
   if(UseRangeFilter && IsInRange(emaFast, emaSlow))
   {
      if(DebugMode) Print("📊 Marché en range détecté - pas de trade");
      return;
   }
   
   // Signal BUY
   if(emaFast[2] > emaSlow[2] && emaFast[1] <= emaSlow[1] && currentRSI < RSIOverbought)
   {
      if(DebugMode) 
      {
         Print("📈 Signal BUY détecté:");
         Print("   EMA Fast: ", emaFast[2], " > EMA Slow: ", emaSlow[2]);
         Print("   RSI: ", currentRSI, " < ", RSIOverbought);
      }
      
      // Fermer position SELL si existante
      if(CloseOnOppositeSignal && HasSellPosition())
      {
         CloseAllPositions();
      }
      
      // Ouvrir position BUY
      if(!HasBuyPosition())
      {
         OpenBuyPosition();
      }
   }
   
   // Signal SELL
   else if(emaFast[2] < emaSlow[2] && emaFast[1] >= emaSlow[1] && currentRSI > RSIOversold)
   {
      if(DebugMode) 
      {
         Print("📉 Signal SELL détecté:");
         Print("   EMA Fast: ", emaFast[2], " < EMA Slow: ", emaSlow[2]);
         Print("   RSI: ", currentRSI, " > ", RSIOversold);
      }
      
      // Fermer position BUY si existante
      if(CloseOnOppositeSignal && HasBuyPosition())
      {
         CloseAllPositions();
      }
      
      // Ouvrir position SELL
      if(!HasSellPosition())
      {
         OpenSellPosition();
      }
   }
}

//+------------------------------------------------------------------+
//| DÉTECTER SI ON EST DANS UN RANGE                                  |
//+------------------------------------------------------------------+
bool IsInRange(double &emaFast[], double &emaSlow[])
{
   double spread = MathAbs(emaFast[2] - emaSlow[2]);
   double minMove = MinRangePoints * _Point;
   
   // Si les EMA sont trop proches, on est probablement dans un range
   if(spread < minMove)
   {
      if(DebugMode) Print("📊 Range détecté - spread EMA: ", spread, " < ", minMove);
      return true;
   }
   
   // Si le spread est inférieur au maximum autorisé pour un range
   if(spread < MaxRangeSpread * _Point)
   {
      // Vérifier si le prix oscille entre les EMA
      bool oscillating = (emaFast[0] > emaSlow[0] && emaFast[1] < emaSlow[1]) ||
                        (emaFast[0] < emaSlow[0] && emaFast[1] > emaSlow[1]);
      
      if(oscillating)
      {
         if(DebugMode) Print("📊 Oscillation dans range détectée");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| OUVRIR POSITION BUY                                               |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = ask - StopLossPoints * _Point;
   double tp = ask + TakeProfitPoints * _Point;
   
   // Validation des distances minimales
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minStopLevel > 0)
   {
      if(ask - sl < minStopLevel) sl = ask - minStopLevel;
      if(tp - ask < minStopLevel) tp = ask + minStopLevel;
   }
   
   if(trade.Buy(LotSize, _Symbol, ask, sl, tp, "Scalper Simple BUY"))
   {
      if(DebugMode) Print("✅ Position BUY ouverte à ", ask);
   }
   else
   {
      if(DebugMode) Print("❌ Erreur ouverture BUY: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| OUVRIR POSITION SELL                                              |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = bid + StopLossPoints * _Point;
   double tp = bid - TakeProfitPoints * _Point;
   
   // Validation des distances minimales
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minStopLevel > 0)
   {
      if(sl - bid < minStopLevel) sl = bid + minStopLevel;
      if(bid - tp < minStopLevel) tp = bid - minStopLevel;
   }
   
   if(trade.Sell(LotSize, _Symbol, bid, sl, tp, "Scalper Simple SELL"))
   {
      if(DebugMode) Print("✅ Position SELL ouverte à ", bid);
   }
   else
   {
      if(DebugMode) Print("❌ Erreur ouverture SELL: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI ON A UNE POSITION BUY                                 |
//+------------------------------------------------------------------+
bool HasBuyPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.PositionType() == POSITION_TYPE_BUY)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI ON A UNE POSITION SELL                                |
//+------------------------------------------------------------------+
bool HasSellPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.PositionType() == POSITION_TYPE_SELL)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| FERMER TOUTES LES POSITIONS                                       |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol)
         {
            if(position.PositionType() == POSITION_TYPE_BUY)
            {
               trade.PositionClose(position.Ticket());
            }
            else
            {
               trade.PositionClose(position.Ticket());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| METTRE À JOUR LE PROFIT QUOTIDIEN                                 |
//+------------------------------------------------------------------+
void UpdateDailyPL()
{
   double currentPL = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol)
         {
            currentPL += position.Profit();
         }
      }
   }
   
   dailyPL = currentPL;
}
