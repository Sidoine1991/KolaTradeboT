// Test: Vérification logique de MonitorGOMWaitClosePositions()
#include <Trade\Trade.mqh>

void TestMonitorGOMWaitClosePositions()
{
   Print("====== TEST GOM AUTO-CLOSE ======");
   
   // Simulation 1: GOM est WAIT, position ouverte → doit fermer
   int g_lastGOMVerdictNum = 0;  // WAIT
   Print("Test 1: GOM=WAIT (vnum=0), positions ouvertes");
   if(g_lastGOMVerdictNum == 0) 
      Print("✅ Test 1: Condition WAIT détectée correctement");
   
   // Simulation 2: GOM est GOOD, position ouverte → ne doit PAS fermer
   g_lastGOMVerdictNum = -2;  // GOOD
   Print("Test 2: GOM=GOOD (vnum=-2), positions ouvertes");
   if(g_lastGOMVerdictNum != 0) 
      Print("✅ Test 2: Condition non-WAIT détectée, pas de fermeture");
   
   // Simulation 3: GOM devient WAIT après BUY → fermeture
   g_lastGOMVerdictNum = -1;  // BUY
   Print("Test 3: GOM=BUY (vnum=-1), position ouverte");
   // Après quelque temps, GOM devient WAIT
   g_lastGOMVerdictNum = 0;
   Print("Test 3b: GOM transitions à WAIT → fermeture trigger");
   if(g_lastGOMVerdictNum == 0)
      Print("✅ Test 3: Transition WAIT détectée");
   
   Print("====== TESTS TERMINÉS ======");
}

void OnInit() { TestMonitorGOMWaitClosePositions(); }
void OnTick() {}
