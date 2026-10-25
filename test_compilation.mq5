//+------------------------------------------------------------------+
//| Script de test pour vérifier la compilation                      |
//+------------------------------------------------------------------+
#property script_show_inputs

// Test des fonctions corrigées
void OnStart()
{
   Print("Test de compilation des fonctions corrigées...");
   
   // Test NormalizeStopLevel
   double testPrice = 1.12345;
   double testStop = 1.12000;
   double normalizedStop = NormalizeStopLevel(testPrice, testStop, true);
   Print("NormalizeStopLevel test: ", normalizedStop);
   
   // Test StringToTime
   string testTimeStr = "2025.01.01 12:00:00";
   datetime testTime = StringToTime(testTimeStr);
   Print("StringToTime test: ", TimeToString(testTime));
   
   Print("Test terminé avec succès!");
}
