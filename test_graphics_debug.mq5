//+------------------------------------------------------------------+
//| Script de test pour vérifier l'affichage des graphiques SMC     |
//+------------------------------------------------------------------+
#property script_show_inputs
#property version   "1.00"

input bool TestFVG = true;
input bool TestOB = true;
input bool TestBookmarks = true;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("🚀 DÉMARRAGE DU TEST GRAPHIQUES SMC");
   Print("📅 ", TimeToString(TimeCurrent()));
   
   // Nettoyer les anciens objets
   ObjectsDeleteAll(0, "TEST_");
   
   // Test 1: Créer un rectangle simple
   if(ObjectCreate(0, "TEST_RECTANGLE", OBJ_RECTANGLE, 0, 
      TimeCurrent() - 3600, SymbolInfoDouble(_Symbol, SYMBOL_BID) - 0.001,
      TimeCurrent(), SymbolInfoDouble(_Symbol, SYMBOL_BID) + 0.001))
   {
      ObjectSetInteger(0, "TEST_RECTANGLE", OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, "TEST_RECTANGLE", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "TEST_RECTANGLE", OBJPROP_BACK, false);
      ObjectSetInteger(0, "TEST_RECTANGLE", OBJPROP_FILL, false);
      Print("✅ Rectangle de test créé avec succès");
   }
   else
   {
      Print("❌ Erreur création rectangle de test");
   }
   
   // Test 2: Créer une flèche simple
   if(ObjectCreate(0, "TEST_ARROW", OBJ_ARROW, 0, 
      TimeCurrent(), SymbolInfoDouble(_Symbol, SYMBOL_BID)))
   {
      ObjectSetInteger(0, "TEST_ARROW", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "TEST_ARROW", OBJPROP_ARROWCODE, 233);
      ObjectSetInteger(0, "TEST_ARROW", OBJPROP_WIDTH, 3);
      Print("✅ Flèche de test créée avec succès");
   }
   else
   {
      Print("❌ Erreur création flèche de test");
   }
   
   // Test 3: Vérifier les objets existants
   int totalObjects = ObjectsTotal(0);
   Print("📊 Nombre total d'objets sur le graphique: ", totalObjects);
   
   for(int i = 0; i < totalObjects; i++)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "SMC_") >= 0 || StringFind(objName, "TEST_") >= 0)
      {
         Print("   📋 Objet trouvé: ", objName);
      }
   }
   
   // Test 4: Forcer le rafraîchissement du graphique
   ChartRedraw();
   Print("🔄 Graphique rafraîchi");
   
   Print("✅ TEST TERMINÉ - Vérifiez visuellement le graphique");
   Print("   - Rectangle jaune devrait être visible");
   Print("   - Flèche verte devrait être visible");
   Print("   - Consultez l'onglet 'Experts' pour les logs");
}
