//+------------------------------------------------------------------+
//| EXEMPLE_INTEGRATION_NOTIFICATIONS_ENRICHIES.mq5                  |
//| Exemple pratique d'intégration du module de notifications       |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include <Enhanced_Push_Notifications.mqh>  // ⬅️ NOUVEAU MODULE

//+------------------------------------------------------------------+
//| PARAMÈTRES                                                       |
//+------------------------------------------------------------------+

input group "=== TRADING SETTINGS ==="
input bool   EnableTrading = false;              // Activer le trading réel
input double RiskPercent = 1.0;                  // Risque par trade (%)
input int    MagicNumber = 123456;               // Magic Number

input group "=== NOTIFICATIONS ==="
input bool   UseNotifications = true;            // Activer notifications
input bool   NotifyOnSignalDetection = true;     // Notifier détection signal
input bool   NotifyOnTradeExecution = true;      // Notifier exécution trade
input bool   NotifyOnTradeClose = true;          // Notifier fermeture trade

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+

CTrade trade;
datetime g_lastSignalTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 Démarrage EA avec notifications enrichies...");

   // Configuration trade
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   // Initialiser module notifications enrichies
   InitEnhancedNotifications();

   // Test optionnel des notifications
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("📊 Mode testeur détecté - tests notifications désactivés");
   }
   else
   {
      // Test immédiat en mode réel/démo
      Print("\n🧪 Test des notifications enrichies...");
      TestNotifications();
   }

   Print("✅ EA initialisé avec succès");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("👋 EA arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier nouveau signal uniquement sur nouvelle barre
   if(!IsNewBar()) return;

   // Analyser le marché
   AnalyzeMarketAndNotify();
}

//+------------------------------------------------------------------+
//| Vérifier si nouvelle barre                                       |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Analyser le marché et envoyer notifications                     |
//+------------------------------------------------------------------+
void AnalyzeMarketAndNotify()
{
   // Exemple simplifié de détection de signal
   // Dans un vrai EA, remplacer par votre logique SMC/PA

   double ema9 = iMA(_Symbol, PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE);
   double ema21 = iMA(_Symbol, PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);

   double ema9_val[], ema21_val[], rsi_val[];
   ArraySetAsSeries(ema9_val, true);
   ArraySetAsSeries(ema21_val, true);
   ArraySetAsSeries(rsi_val, true);

   if(CopyBuffer(ema9, 0, 0, 3, ema9_val) < 3) return;
   if(CopyBuffer(ema21, 0, 0, 3, ema21_val) < 3) return;
   if(CopyBuffer(rsi, 0, 0, 3, rsi_val) < 3) return;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Détection signal BUY
   if(ema9_val[0] > ema21_val[0] &&
      ema9_val[1] <= ema21_val[1] &&
      rsi_val[0] > 50 && rsi_val[0] < 70)
   {
      OnSignalDetected("BUY", "EMA Crossover", currentPrice, 0.75);
   }

   // Détection signal SELL
   else if(ema9_val[0] < ema21_val[0] &&
           ema9_val[1] >= ema21_val[1] &&
           rsi_val[0] < 50 && rsi_val[0] > 30)
   {
      OnSignalDetected("SELL", "EMA Crossover", currentPrice, 0.75);
   }
}

//+------------------------------------------------------------------+
//| Gestionnaire de signal détecté                                   |
//+------------------------------------------------------------------+
void OnSignalDetected(const string signal, const string concept, const double entryPrice, const double confidence)
{
   // Éviter notifications répétées
   datetime now = TimeCurrent();
   if(now - g_lastSignalTime < 60) return; // Max 1 notif/minute
   g_lastSignalTime = now;

   Print("🔔 Signal détecté: ", signal, " - ", concept);

   // Calculer SL/TP
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
   double atr_val[];
   ArraySetAsSeries(atr_val, true);
   CopyBuffer(atr, 0, 0, 1, atr_val);

   double sl = 0, tp = 0;

   if(signal == "BUY")
   {
      sl = entryPrice - (atr_val[0] * 1.5);
      tp = entryPrice + (atr_val[0] * 2.5);
   }
   else if(signal == "SELL")
   {
      sl = entryPrice + (atr_val[0] * 1.5);
      tp = entryPrice - (atr_val[0] * 2.5);
   }

   // Normaliser prix
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   // Notification enrichie avec analyse complète
   if(UseNotifications && NotifyOnSignalDetection)
   {
      SendFullAnalysisNotification(
         signal,
         concept,
         entryPrice,
         sl,
         tp,
         confidence,
         _Symbol
      );
   }

   // Exécuter le trade si activé
   if(EnableTrading)
   {
      ExecuteTrade(signal, entryPrice, sl, tp, concept);
   }
}

//+------------------------------------------------------------------+
//| Exécuter un trade                                                |
//+------------------------------------------------------------------+
void ExecuteTrade(const string signal, const double entry, const double sl, const double tp, const string reason)
{
   Print("📊 Exécution trade: ", signal);

   // Calculer volume basé sur risque
   double volume = CalculateVolume(entry, sl);

   bool success = false;

   if(signal == "BUY")
   {
      success = trade.Buy(volume, _Symbol, 0, sl, tp, reason);
   }
   else if(signal == "SELL")
   {
      success = trade.Sell(volume, _Symbol, 0, sl, tp, reason);
   }

   // Notification du résultat
   if(success)
   {
      Print("✅ Trade exécuté avec succès - Ticket: ", trade.ResultOrder());

      if(UseNotifications && NotifyOnTradeExecution)
      {
         SendTradeExecutedNotification(
            "OPENED",
            signal,
            entry,
            volume,
            0,
            reason,
            _Symbol
         );
      }
   }
   else
   {
      Print("❌ Échec exécution trade - Erreur: ", GetLastError());

      if(UseNotifications)
      {
         SendEnhancedNotification(
            "❌ ÉCHEC TRADE " + signal + " " + _Symbol + "\nErreur: " + IntegerToString(GetLastError()),
            _Symbol,
            true
         );
      }
   }
}

//+------------------------------------------------------------------+
//| Calculer volume selon gestion du risque                         |
//+------------------------------------------------------------------+
double CalculateVolume(const double entry, const double sl)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);

   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double riskPoints = MathAbs(entry - sl) / pointSize;

   if(riskPoints == 0) return 0;

   double volume = riskAmount / (riskPoints * pointValue);

   // Normaliser volume
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   volume = MathFloor(volume / stepLot) * stepLot;
   volume = MathMax(minLot, MathMin(maxLot, volume));

   return volume;
}

//+------------------------------------------------------------------+
//| Surveiller positions ouvertes                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckOpenPositions();
}

//+------------------------------------------------------------------+
//| Vérifier et gérer positions ouvertes                            |
//+------------------------------------------------------------------+
void CheckOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      // Exemple: Fermeture si profit >= 50$
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(profit >= 50.0)
      {
         Print("💰 Profit target atteint: ", profit, "$ - Fermeture position");

         if(trade.PositionClose(ticket))
         {
            if(UseNotifications && NotifyOnTradeClose)
            {
               SendTradeExecutedNotification(
                  "CLOSED",
                  PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  PositionGetDouble(POSITION_PRICE_CURRENT),
                  PositionGetDouble(POSITION_VOLUME),
                  profit,
                  "Profit Target Hit",
                  _Symbol
               );
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Test des notifications (appelé au démarrage)                    |
//+------------------------------------------------------------------+
void TestNotifications()
{
   Print("\n═══════════════════════════════════");
   Print("🧪 TEST DES NOTIFICATIONS ENRICHIES");
   Print("═══════════════════════════════════\n");

   Sleep(500);

   // Test 1: Notification simple
   Print("Test 1: Notification simple");
   SendEnhancedNotification("🔔 Test notification simple - " + _Symbol, _Symbol, true);

   Sleep(2000);

   // Test 2: Signal détecté
   Print("\nTest 2: Signal BUY détecté");
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   SendFullAnalysisNotification(
      "BUY",
      "Test EMA Crossover",
      currentPrice,
      currentPrice - 0.0050,
      currentPrice + 0.0100,
      0.80,
      _Symbol
   );

   Sleep(2000);

   // Test 3: Trade ouvert
   Print("\nTest 3: Trade ouvert");
   SendTradeExecutedNotification(
      "OPENED",
      "BUY",
      currentPrice,
      0.10,
      0,
      "Test FVG Entry",
      _Symbol
   );

   Sleep(2000);

   // Test 4: Trade fermé avec profit
   Print("\nTest 4: Trade fermé (profit)");
   SendTradeExecutedNotification(
      "CLOSED",
      "BUY",
      currentPrice + 0.0080,
      0.10,
      35.50,
      "TP Hit",
      _Symbol
   );

   Sleep(2000);

   // Test 5: Résumé économique
   Print("\nTest 5: Résumé économique");
   string economicSummary = GetCurrentEconomicSummary(_Symbol);
   Print(economicSummary);

   Print("\n═══════════════════════════════════");
   Print("✅ TESTS TERMINÉS");
   Print("═══════════════════════════════════\n");
}

//+------------------------------------------------------------------+
//| Bouton de test manuel                                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "BTN_TEST_NOTIF")
      {
         Print("🧪 Test manuel des notifications...");
         TestNotifications();

         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == "BTN_ECONOMIC_SUMMARY")
      {
         Print("📊 Résumé économique:");
         Print(GetCurrentEconomicSummary(_Symbol));

         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Créer boutons de test sur le graphique                          |
//+------------------------------------------------------------------+
void CreateTestButtons()
{
   // Bouton Test Notifications
   ObjectCreate(0, "BTN_TEST_NOTIF", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "BTN_TEST_NOTIF", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "BTN_TEST_NOTIF", OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, "BTN_TEST_NOTIF", OBJPROP_XSIZE, 150);
   ObjectSetInteger(0, "BTN_TEST_NOTIF", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "BTN_TEST_NOTIF", OBJPROP_TEXT, "🧪 Test Notifications");
   ObjectSetInteger(0, "BTN_TEST_NOTIF", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "BTN_TEST_NOTIF", OBJPROP_BGCOLOR, clrBlue);
   ObjectSetInteger(0, "BTN_TEST_NOTIF", OBJPROP_CORNER, CORNER_RIGHT_UPPER);

   // Bouton Résumé Économique
   ObjectCreate(0, "BTN_ECONOMIC_SUMMARY", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_YDISTANCE, 70);
   ObjectSetInteger(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_XSIZE, 150);
   ObjectSetInteger(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_TEXT, "📊 Résumé Économique");
   ObjectSetInteger(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_BGCOLOR, clrGreen);
   ObjectSetInteger(0, "BTN_ECONOMIC_SUMMARY", OBJPROP_CORNER, CORNER_RIGHT_UPPER);

   ChartRedraw();
}

//+------------------------------------------------------------------+
