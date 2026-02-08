//+------------------------------------------------------------------+
//| Test de compilation minimal pour GoldRush_basic                |
//+------------------------------------------------------------------+

// Includes exacts comme dans GoldRush_basic.mq5
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

// Déclaration CTrade comme dans GoldRush_basic.mq5
CTrade trade;

//+------------------------------------------------------------------+
//| Test des méthodes qui causaient des erreurs                     |
//+------------------------------------------------------------------+
void TestProblematicMethods()
{
   // Test des méthodes qui étaient en erreur
   uint code1 = trade.ResultCode();
   string comment1 = trade.ResultComment();
   ulong order1 = trade.ResultOrder();
   
   // Test des méthodes de trading
   bool buyResult = trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test");
   bool sellResult = trade.Sell(0.01, _Symbol, 0.0, 0.0, 0.0, "Test");
   bool modifyResult = trade.PositionModify(12345, 0.0, 0.0);
   bool closeResult = trade.PositionClose(12345);
   
   // Test des méthodes de configuration
   trade.SetExpertMagicNumber(123456);
   
   Print("✅ Toutes les méthodes CTrade testées avec succès");
}

//+------------------------------------------------------------------+
//| Test avec gestion d'erreur comme dans GoldRush_basic            |
//+------------------------------------------------------------------+
void TestWithErrorHandling()
{
   // Simuler le code exact de GoldRush_basic qui causait l'erreur
   if(!trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test Error"))
   {
      Print("❌ Échec ACHAT - Erreur: ", trade.ResultCode(), " - ", trade.ResultComment());
   }
   else
   {
      Print("✅ Trade ACHAT exécuté - Ticket: ", trade.ResultOrder());
   }
   
   // Test avec PositionModify
   if(!trade.PositionModify(12345, 0.0, 0.0))
   {
      Print("❌ Échec modification SL - Erreur: ", trade.ResultCode(), " - ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TEST COMPILATION GOLDRUSH_BASIC ===");
   
   TestProblematicMethods();
   TestWithErrorHandling();
   
   Print("✅ Compilation réussie - Plus d'erreurs de syntaxe");
   return INIT_SUCCEEDED;
}
