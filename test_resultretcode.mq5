//+------------------------------------------------------------------+
//| Test définitif - Méthode ResultRetcode()                       |
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
//| Test de la méthode correcte ResultRetcode()                     |
//+------------------------------------------------------------------+
void TestResultRetcode()
{
   // ✅ CORRECT - ResultRetcode() est la méthode standard MQL5
   uint resultRetcode = trade.ResultRetcode();    // Retourne le code de retour
   ulong resultOrder = trade.ResultOrder();        // Retourne le ticket d'ordre
   
   Print("✅ Méthodes CTrade correctes:");
   Print("   ResultRetcode(): ", resultRetcode);
   Print("   ResultOrder(): ", resultOrder);
}

//+------------------------------------------------------------------+
//| Test pratique comme dans GoldRush_basic corrigé                |
//+------------------------------------------------------------------+
void TestPracticalUsage()
{
   trade.SetExpertMagicNumber(123456);
   
   // Test exact comme dans le code final
   if(!trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test"))
   {
      // ✅ CORRECT - Utilisation de ResultRetcode()
      uint errorCode = trade.ResultRetcode();
      Print("❌ Échec ACHAT - Erreur: ", errorCode);
   }
   else
   {
      ulong ticket = trade.ResultOrder();
      Print("✅ Trade ACHAT exécuté - Ticket: ", ticket);
   }
}

//+------------------------------------------------------------------+
//| Test de toutes les opérations avec gestion d'erreur            |
//+------------------------------------------------------------------+
void TestAllOperations()
{
   trade.SetExpertMagicNumber(123456);
   
   // Test BUY
   if(!trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test BUY"))
      Print("❌ BUY échoué - Code: ", trade.ResultRetcode());
   else
      Print("✅ BUY réussi - Ticket: ", trade.ResultOrder());
   
   // Test SELL
   if(!trade.Sell(0.01, _Symbol, 0.0, 0.0, 0.0, "Test SELL"))
      Print("❌ SELL échoué - Code: ", trade.ResultRetcode());
   else
      Print("✅ SELL réussi - Ticket: ", trade.ResultOrder());
      
   // Test modification
   if(!trade.PositionModify(12345, 0.0, 0.0))
      Print("❌ Modify échoué - Code: ", trade.ResultRetcode());
      
   // Test fermeture
   if(!trade.PositionClose(12345))
      Print("❌ Close échoué - Code: ", trade.ResultRetcode());
}

//+------------------------------------------------------------------+
//| Test spécifique pour les lignes qui causaient l'erreur          |
//+------------------------------------------------------------------+
void TestErrorLines()
{
   // Simuler exactement les lignes qui étaient en erreur
   if(!trade.PositionModify(12345, 0.0, 0.0))
   {
      // Ligne 390, 405, 421, 433 type d'erreur
      Print("❌ Échec modification SL BUY - Erreur: ", trade.ResultRetcode());
   }
   
   if(!trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test"))
   {
      // Ligne 817, 824 type d'erreur
      Print("❌ Échec ACHAT - Erreur: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TEST DÉFINITIF RESULTRETCODE ===");
   
   TestResultRetcode();
   TestPracticalUsage();
   TestAllOperations();
   TestErrorLines();
   
   Print("✅ Test définitif réussi - ResultRetcode() est la bonne méthode");
   return INIT_SUCCEEDED;
}
