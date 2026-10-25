//+------------------------------------------------------------------+
//|                                        Test_Signal_Blocking.mq5 |
//|                        Copyright 2025, Test Signal Blocking     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Test Signal Blocking"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test du système de blocage des signaux défaillants"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🧪 TEST DU SYSTÈME DE BLOCAGE DES SIGNAUX");
    Print("==========================================");
    
    // Tester l'enregistrement de signaux défaillants
    TestFailedSignalRegistration();
    
    // Tester le blocage des signaux
    TestSignalBlocking();
    
    // Tester le nettoyage des signaux expirés
    TestSignalCleanup();
    
    Print("\n✅ TEST TERMINÉ");
}

//+------------------------------------------------------------------+
//| Tester l'enregistrement de signaux défaillants                  |
//+------------------------------------------------------------------+
void TestFailedSignalRegistration()
{
    Print("\n📝 TEST ENREGISTREMENT SIGNAUX DÉFAILLANTS");
    Print("-------------------------------------------");
    
    // Simuler des signaux défaillants
    string test_symbols[] = {"Boom 1000 Index", "Crash 1000 Index", "EURUSD"};
    int test_directions[] = {1, -1, 1};
    double test_prices[] = {18674.50, 5389.25, 1.0850};
    string test_reasons[] = {"Invalid volume", "Invalid stops", "No money"};
    
    for(int i = 0; i < ArraySize(test_symbols); i++) {
        Print("   Enregistrement signal défaillant: ", test_symbols[i], " ", 
              (test_directions[i] > 0 ? "BUY" : "SELL"), " @ ", DoubleToString(test_prices[i], 5));
        
        // Simuler l'enregistrement (fonction simplifiée pour le test)
        SimulateFailedSignalRegistration(test_symbols[i], test_directions[i], test_prices[i], test_reasons[i]);
    }
}

//+------------------------------------------------------------------+
//| Tester le blocage des signaux                                   |
//+------------------------------------------------------------------+
void TestSignalBlocking()
{
    Print("\n🚫 TEST BLOCAGE DES SIGNAUX");
    Print("----------------------------");
    
    // Tester différents scénarios de blocage
    TestBlockingScenario("Boom 1000 Index", 1, 18674.50, "Signal récent - devrait être bloqué");
    TestBlockingScenario("Crash 1000 Index", -1, 5389.25, "Signal récent - devrait être bloqué");
    TestBlockingScenario("EURUSD", 1, 1.0850, "Signal récent - devrait être bloqué");
    TestBlockingScenario("GBPUSD", -1, 1.2650, "Nouveau signal - ne devrait pas être bloqué");
}

//+------------------------------------------------------------------+
//| Tester le nettoyage des signaux expirés                         |
//+------------------------------------------------------------------+
void TestSignalCleanup()
{
    Print("\n🧹 TEST NETTOYAGE SIGNAUX EXPIRÉS");
    Print("----------------------------------");
    
    // Simuler le nettoyage
    int signals_before = 3; // Nombre de signaux avant nettoyage
    int signals_after = 1;  // Nombre de signaux après nettoyage
    
    Print("   Signaux avant nettoyage: ", signals_before);
    Print("   Signaux après nettoyage: ", signals_after);
    Print("   Signaux supprimés: ", signals_before - signals_after);
}

//+------------------------------------------------------------------+
//| Simuler l'enregistrement d'un signal défaillant                 |
//+------------------------------------------------------------------+
void SimulateFailedSignalRegistration(string symbol, int direction, double price, string reason)
{
    Print("   ✅ Signal défaillant enregistré: ", symbol, " ", 
          (direction > 0 ? "BUY" : "SELL"), " @ ", DoubleToString(price, 5), " - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Tester un scénario de blocage                                   |
//+------------------------------------------------------------------+
void TestBlockingScenario(string symbol, int direction, double price, string description)
{
    Print("   Test: ", description);
    Print("   Symbole: ", symbol, " Direction: ", (direction > 0 ? "BUY" : "SELL"), " Prix: ", DoubleToString(price, 5));
    
    // Simuler la vérification de blocage
    bool is_blocked = SimulateSignalBlocking(symbol, direction, price);
    
    if(is_blocked) {
        Print("   Résultat: 🚫 SIGNAL BLOQUÉ");
    } else {
        Print("   Résultat: ✅ SIGNAL AUTORISÉ");
    }
}

//+------------------------------------------------------------------+
//| Simuler la vérification de blocage d'un signal                  |
//+------------------------------------------------------------------+
bool SimulateSignalBlocking(string symbol, int direction, double price)
{
    // Simulation simple : bloquer les signaux récents
    if(symbol == "Boom 1000 Index" || symbol == "Crash 1000 Index" || symbol == "EURUSD") {
        return true; // Signal bloqué
    }
    return false; // Signal autorisé
}
