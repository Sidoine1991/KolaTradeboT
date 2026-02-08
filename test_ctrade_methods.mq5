//+------------------------------------------------------------------+
//| Test final de syntaxe CTrade - MÉTHODES avec parenthèses        |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| Test des méthodes CTrade correctes (AVEC parenthèses)          |
//+------------------------------------------------------------------+
void TestCTradeMethods()
{
   // ✅ CORRECT - Ce sont des MÉTHODES, donc avec parenthèses
   uint resultCode = trade.ResultCode();        // Méthode pour obtenir le code d'erreur
   string resultComment = trade.ResultComment(); // Méthode pour obtenir le message d'erreur
   ulong resultOrder = trade.ResultOrder();      // Méthode pour obtenir le ticket d'ordre
   
   Print("✅ Méthodes CTrade testées:");
   Print("   ResultCode(): ", resultCode);
   Print("   ResultComment(): ", resultComment);
   Print("   ResultOrder(): ", resultOrder);
}

//+------------------------------------------------------------------+
//| Test d'utilisation pratique                                   |
//+------------------------------------------------------------------+
void TestPracticalUsage()
{
   trade.SetExpertMagicNumber(123456);
   
   // Tenter un trade (qui va probablement échouer en test)
   bool success = trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test");
   
   if(!success)
   {
      // ✅ CORRECT - Utilisation des méthodes avec parenthèses
      uint errorCode = trade.ResultCode();
      string errorMsg = trade.ResultComment();
      
      Print("❌ Échec trade détecté:");
      Print("   Code erreur: ", errorCode);
      Print("   Message: ", errorMsg);
   }
   else
   {
      // ✅ CORRECT - Utilisation de la méthode avec parenthèses
      ulong ticket = trade.ResultOrder();
      Print("✅ Trade réussi - Ticket: ", ticket);
   }
}

//+------------------------------------------------------------------+
//| Test de toutes les méthodes de trading                         |
//+------------------------------------------------------------------+
void TestAllTradingMethods()
{
   double lot = 0.01;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - 100 * _Point;
   double tp = price + 200 * _Point;
   
   // Test BUY
   if(trade.Buy(lot, _Symbol, price, sl, tp, "Test BUY"))
   {
      ulong buyTicket = trade.ResultOrder();
      Print("✅ BUY réussi - Ticket: ", buyTicket);
   }
   else
   {
      Print("❌ BUY échoué - Code: ", trade.ResultCode(), " - ", trade.ResultComment());
   }
   
   // Test SELL
   if(trade.Sell(lot, _Symbol, price, sl, tp, "Test SELL"))
   {
      ulong sellTicket = trade.ResultOrder();
      Print("✅ SELL réussi - Ticket: ", sellTicket);
   }
   else
   {
      Print("❌ SELL échoué - Code: ", trade.ResultCode(), " - ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TEST SYNTAXE CTRADE MÉTHODES ===");
   
   TestCTradeMethods();
   TestPracticalUsage();
   TestAllTradingMethods();
   
   Print("✅ Tous les tests de syntaxe CTrade complétés");
   return INIT_SUCCEEDED;
}
