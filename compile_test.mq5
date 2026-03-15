//+------------------------------------------------------------------+
//| Test compilation                                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Test simple functions                                           |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("Test compilation OK");
   
   // Test des fonctions de prix
   double entry_price = 1000.0;
   double exit_price = 1010.0;
   double profit = -1.0;
   
   Print("Entry: ", entry_price, " Exit: ", exit_price, " Profit: ", profit);
}
