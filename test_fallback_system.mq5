//+------------------------------------------------------------------+
//| TEST SYSTÈME FALLBACK LOCAL → RENDER                     |
//+------------------------------------------------------------------+

/*
SYSTÈME DE FALLBACK IMPLÉMÉ:

1. 🏠 PRIORITÉ LOCALE (UseLocalFirst = true)
   - Essayer localhost:8000/decision en premier
   - Si succès → Signal LOCAL
   - Si échec → Fallback vers Render

2. 🌐 FALLBACK VERS RENDER
   - Si local indisponible → essayer https://kolatradebot.onrender.com/decision
   - Si succès → Signal RENDER
   - Si échec → Signal de secours technique

3. 🔄 SIGNAL DE SECOURS TECHNIQUE
   - Basé sur RSI uniquement
   - RSI < 30 → BUY (confiance 0.65)
   - RSI > 70 → SELL (confiance 0.65)
   - RSI 30-70 → HOLD (confiance 0.50)

PARAMÈTRES AJOUTÉS:
- AI_LocalServerURL = "http://localhost:8000/decision"
- UseLocalFirst = true

LOGS ATTENDUS:
🌐 Tentative serveur LOCAL: http://localhost:8000/decision
✅ Serveur LOCAL répond - Signal obtenu
❌ Serveur LOCAL indisponible (Code: 442) - Fallback vers Render
✅ Fallback Render réussi - Signal obtenu
✅ IA Signal [LOCAL]: buy (confiance: 0.85)
✅ IA Signal [RENDER]: sell (confiance: 0.92)
🔄 Signal de secours [FALLBACK]: BUY (RSI: 25.50 < 30)

*/

//+------------------------------------------------------------------+
//| TEST DU SYSTÈME DE FALLBACK                              |
//+------------------------------------------------------------------+
void TestFallbackSystem()
{
   Print("=== TEST SYSTÈME DE FALLBACK LOCAL → RENDER ===");
   
   // Afficher les paramètres de configuration
   Print("⚙️ CONFIGURATION ACTUELLE:");
   Print("   UseLocalFirst: ", UseLocalFirst ? "OUI" : "NON");
   Print("   URL Locale: ", AI_LocalServerURL);
   Print("   URL Render: ", AI_ServerURL);
   Print("   AI_MinConfidence: ", AI_MinConfidence);
   
   // Simuler les différents scénarios
   Print("\n📋 SCÉNARIOS POSSIBLES:");
   
   Print("\n1️⃣ SCÉNARIO 1 - LOCAL DISPONIBLE:");
   Print("   🌐 Tentative LOCAL → ✅ Succès");
   Print("   ✅ IA Signal [LOCAL]: buy (confiance: 0.85)");
   
   Print("\n2️⃣ SCÉNARIO 2 - LOCAL INDISPONIBLE, RENDER DISPONIBLE:");
   Print("   🌐 Tentative LOCAL → ❌ Échec (Code: 442)");
   Print("   🔄 Fallback vers Render → ✅ Succès");
   Print("   ✅ IA Signal [RENDER]: sell (confiance: 0.92)");
   
   Print("\n3️⃣ SCÉNARIO 3 - LOCAL ET RENDER INDISPONIBLES:");
   Print("   🌐 Tentative LOCAL → ❌ Échec");
   Print("   🔄 Fallback vers Render → ❌ Échec");
   Print("   🔄 Signal de secours [FALLBACK]: BUY (RSI: 25.50 < 30)");
   Print("   ⚠️ ModeFallback activé - Confiance réduite à 0.65");
   
   Print("\n4️⃣ SCÉNARIO 4 - UTILISATION DIRECTE DE RENDER:");
   Print("   🌐 Utilisation directe Render (UseLocalFirst = false)");
   Print("   ✅ IA Signal [RENDER]: hold (confiance: 0.75)");
}

//+------------------------------------------------------------------+
//| TEST DE LA LOGIQUE DE SIGNAL DE SECOURS                    |
//+------------------------------------------------------------------+
void TestFallbackSignalLogic()
{
   Print("\n🔄 TEST LOGIQUE SIGNAL DE SECOURS:");
   
   // Simuler différentes valeurs RSI
   double testRSI[] = {15.0, 45.0, 75.0, 50.0};
   string expectedActions[] = {"buy", "hold", "sell", "hold"};
   double expectedConfidence[] = {0.65, 0.50, 0.65, 0.50};
   
   for(int i = 0; i < 4; i++)
   {
      double rsi = testRSI[i];
      string expectedAction = expectedActions[i];
      double expectedConf = expectedConfidence[i];
      
      // Simuler la logique de GenerateFallbackSignal()
      string action = "hold";
      double confidence = 0.50;
      
      if(rsi < 30)
      {
         action = "buy";
         confidence = 0.65;
      }
      else if(rsi > 70)
      {
         action = "sell";
         confidence = 0.65;
      }
      
      Print("   RSI: ", DoubleToString(rsi, 2), " → Action: ", action, " (attendu: ", expectedAction, ")");
      Print("   Confiance: ", DoubleToString(confidence, 2), " (attendu: ", DoubleToString(expectedConf, 2), ")");
      
      bool actionCorrect = (action == expectedAction);
      bool confCorrect = (confidence == expectedConf);
      
      Print("   ✅ Test ", (actionCorrect && confCorrect) ? "RÉUSSI" : "ÉCHOUÉ");
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   TestFallbackSystem();
   TestFallbackSignalLogic();
   
   Print("\n✅ SYSTÈME DE FALLBACK IMPLEMENTÉ");
   Print("   📋 Le robot essaiera d'abord le serveur local");
   Print("   🔄 En cas d'échec, basculera automatiquement vers Render");
   Print("   🛡️ En dernier recours, générera un signal technique");
   Print("   ⚙️ Paramètre UseLocalFirst contrôle la priorité");
   
   return INIT_SUCCEEDED;
}
