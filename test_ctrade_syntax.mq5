//+------------------------------------------------------------------+
//| Test de compilation après corrections syntaxe                   |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| Test des propriétés CTrade correctes                           |
//+------------------------------------------------------------------+
void TestCTradeProperties()
{
   // Test des propriétés (sans parenthèses)
   uint resultCode = trade.ResultCode;        // ✅ Propriété, pas méthode
   string resultComment = trade.ResultComment; // ✅ Propriété, pas méthode
   ulong resultOrder = trade.ResultOrder;      // ✅ Propriété, pas méthode
   
   Print("✅ Propriétés CTrade accessibles:");
   Print("   ResultCode: ", resultCode);
   Print("   ResultComment: ", resultComment);
   Print("   ResultOrder: ", resultOrder);
}

//+------------------------------------------------------------------+
//| Test des méthodes CTrade correctes                             |
//+------------------------------------------------------------------+
void TestCTradeMethods()
{
   double lot = 0.01;
   double sl = 0.0;
   double tp = 0.0;
   string comment = "Test";
   
   // Test des méthodes (avec parenthèses)
   bool buyResult = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);     // ✅ Méthode
   bool sellResult = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);   // ✅ Méthode
   bool modifyResult = trade.PositionModify(12345, sl, tp);            // ✅ Méthode
   bool closeResult = trade.PositionClose(12345);                      // ✅ Méthode
   
   Print("✅ Méthodes CTrade testées:");
   Print("   Buy: ", buyResult ? "Succès" : "Échec");
   Print("   Sell: ", sellResult ? "Succès" : "Échec");
   Print("   Modify: ", modifyResult ? "Succès" : "Échec");
   Print("   Close: ", closeResult ? "Succès" : "Échec");
}

//+------------------------------------------------------------------+
//| Test d'intégration complet                                     |
//+------------------------------------------------------------------+
void TestCompleteIntegration()
{
   trade.SetExpertMagicNumber(123456);
   
   // Simuler une opération de trading avec gestion d'erreur
   if(!trade.Buy(0.01, _Symbol, 0.0, 0.0, 0.0, "Test Integration"))
   {
      uint errorCode = trade.ResultCode;
      string errorMsg = trade.ResultComment;
      
      Print("❌ Échec trade - Code: ", errorCode, " - Message: ", errorMsg);
   }
   else
   {
      ulong ticket = trade.ResultOrder;
      Print("✅ Trade réussi - Ticket: ", ticket);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TEST DE COMPILATION APRÈS CORRECTIONS ===");
   
   TestCTradeProperties();
   TestCTradeMethods();
   TestCompleteIntegration();
   
   Print("✅ Tous les tests complétés - Compilation OK");
   return INIT_SUCCEEDED;
}
