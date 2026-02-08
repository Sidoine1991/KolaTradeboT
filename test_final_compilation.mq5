//+------------------------------------------------------------------+
//| Test final de compilation - Méthodes CTrade simplifiées         |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| Test des méthodes CTrade standard (uniquement ResultCode)        |
//+------------------------------------------------------------------+
void TestStandardCTradeMethods()
{
   // ✅ CORRECT - Seulement les méthodes standard et éprouvées
   uint resultCode = trade.ResultCode();        // Méthode standard pour le code d'erreur
   ulong resultOrder = trade.ResultOrder();      // Méthode standard pour le ticket
   
   Print("✅ Méthodes CTrade standard testées:");
   Print("   ResultCode(): ", resultCode);
   Print("   ResultOrder(): ", resultOrder);
}

//+------------------------------------------------------------------+
//| Test d'utilisation pratique comme dans GoldRush_basic          |
//+------------------------------------------------------------------+
void TestGoldRushUsage()
{
   trade.SetExpertMagicNumber(123456);
   
   // Test exact comme dans le code corrigé
   if(!trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test"))
   {
      // ✅ CORRECT - Uniquement ResultCode(), pas de ResultComment()
      uint errorCode = trade.ResultCode();
      Print("❌ Échec ACHAT - Erreur: ", errorCode);
   }
   else
   {
      ulong ticket = trade.ResultOrder();
      Print("✅ Trade ACHAT exécuté - Ticket: ", ticket);
   }
   
   // Test PositionModify comme dans trailing stop
   if(!trade.PositionModify(12345, 0.0, 0.0))
   {
      uint modifyError = trade.ResultCode();
      Print("❌ Échec modification - Erreur: ", modifyError);
   }
}

//+------------------------------------------------------------------+
//| Test de toutes les méthodes de trading principales              |
//+------------------------------------------------------------------+
void TestAllMainMethods()
{
   // Configuration
   trade.SetExpertMagicNumber(123456);
   
   // Test BUY
   bool buySuccess = trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test BUY");
   if(!buySuccess)
      Print("❌ BUY échoué - Code: ", trade.ResultCode());
   else
      Print("✅ BUY réussi - Ticket: ", trade.ResultOrder());
   
   // Test SELL  
   bool sellSuccess = trade.Sell(0.01, _Symbol, 0.0, 0.0, 0.0, "Test SELL");
   if(!sellSuccess)
      Print("❌ SELL échoué - Code: ", trade.ResultCode());
   else
      Print("✅ SELL réussi - Ticket: ", trade.ResultOrder());
      
   // Test modification
   bool modifySuccess = trade.PositionModify(12345, 0.0, 0.0);
   if(!modifySuccess)
      Print("❌ Modify échoué - Code: ", trade.ResultCode());
      
   // Test fermeture
   bool closeSuccess = trade.PositionClose(12345);
   if(!closeSuccess)
      Print("❌ Close échoué - Code: ", trade.ResultCode());
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TEST COMPILATION FINALE GOLDRUSH_BASIC ===");
   
   TestStandardCTradeMethods();
   TestGoldRushUsage();
   TestAllMainMethods();
   
   Print("✅ Compilation finale réussie - Plus d'erreurs de syntaxe");
   return INIT_SUCCEEDED;
}
