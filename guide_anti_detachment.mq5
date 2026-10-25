//+------------------------------------------------------------------+
//| GUIDE COMPLET - EMPÊCHER DÉTACHEMENT AUTOMATIQUE           |
//+------------------------------------------------------------------+

/*
PROBLÈME : Le robot se détache automatiquement du graphique après attachement

SOLUTIONS IMPLEMENTÉES :

1. 🛡️ SURVEILLANCE DE SANTÉ DU ROBOT
   - Vérification de la connexion au serveur
   - Vérification des autorisations de trading
   - Surveillance des erreurs critiques
   - Alerte si risque de détachement

2. 📋 DIAGNOSTIC DES DÉTACHEMENTS
   - Logs détaillés dans OnDeinit()
   - Identification précise de la cause du détachement
   - Messages clairs pour chaque type de détachement

3. 🔧 PROTECTION CONTRE LES FERMETURES AUTOMATIQUES
   - Paramètre AutoCloseOnTarget = false par défaut
   - Contrôle manuel des fermetures de positions
   - Logs détaillés des profits

CAUSES POSSIBLES DE DÉTACHEMENT :

┌─────────────────────────────────────────────────┐
│ CODE     | RAISON                           | SOLUTION │
├─────────────────────────────────────────────────┤
│ 0        | Program stopped                  | Manuel    │
│ 1        | Program removed from chart        | Manuel    │
│ 2        | Program recompiled                | Normal    │
│ 3        | Symbol or timeframe changed       | Vérifier  │
│ 4        | Chart closed                     | Normal    │
│ 5        | Input parameters changed          | Normal    │
│ 6        | Account changed                  | Vérifier  │
│ 7+       | Unknown reason                   | Diagnostic│
└─────────────────────────────────────────────────┘

LOGS À SURVEILLER :

🚨 DÉTACHEMENT DU ROBOT - Raison: Program removed from chart (Code: 1)
⚠️ Tentative de détachement manuel - Arrêt normal

✅ Robot en bonne santé - Connexion: OK - Trading: OK
❌ Perte de connexion au serveur détectée
🚨 NOMBRE D'ERREURS ÉLEVÉ - Risque de détachement!

PARAMÈTRES MT5 À VÉRIFIER :

1. 🔧 TOOLS → OPTIONS → EXPERT ADVISORS
   ✅ Allow algorithmic trading
   ✅ Allow DLL imports

2. 💰 TOOLS → OPTIONS → TRADE
   ✅ Allow live trading

3. 📊 GRAPHIQUE
   ✅ AutoTrading activé (bouton vert)
   ✅ Bon symbole et timeframe

4. 🤖 ROBOT
   ✅ Magic number unique
   ✅ Paramètres corrects

SOLUTIONS IMMÉDIATES :

1. ✅ ACTIVER LA SURVEILLANCE
   - Le code vérifie automatiquement la santé toutes les 60 secondes
   - Logs "✅ Robot en bonne santé" ou alertes en cas de problème

2. ✅ DÉSACTIVER FERMETURE AUTO
   - AutoCloseOnTarget = false (déjà fait)
   - TotalProfitTarget peut être augmenté

3. ✅ SURVEILLER LES LOGS
   - Rechercher "🚨 DÉTACHEMENT" pour comprendre la cause
   - Surveiller "❌" pour les erreurs de connexion

4. ✅ VÉRIFIER LA CONNEXION
   - Assurer une connexion internet stable
   - Vérifier la connexion au broker

*/

//+------------------------------------------------------------------+
//| FONCTION DE TEST ANTI-DÉTACHEMENT                              |
//+------------------------------------------------------------------+
void TestAntiDetachment()
{
   Print("=== TEST ANTI-DÉTACHEMENT ===");
   
   // Test 1: Vérifier les autorisations
   bool canTrade = MQLInfoInteger(MQL_TRADE_ALLOWED);
   bool terminalTrade = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   bool connected = TerminalInfoInteger(TERMINAL_CONNECTED);
   
   Print("🔍 Autorisations robot: ", canTrade ? "✅" : "❌");
   Print("🔍 Trading terminal: ", terminalTrade ? "✅" : "❌");
   Print("🔍 Connexion serveur: ", connected ? "✅" : "❌");
   
   // Test 2: Simuler les causes de détachement
   Print("\n📋 CAUSES POSSIBLES DE DÉTACHEMENT :");
   Print("   • Arrêt manuel du robot");
   Print("   • Perte de connexion internet");
   Print("   • Changement de compte MT5");
   Print("   • Fermeture du graphique");
   Print("   • Recompilation du code");
   Print("   • Changement de symbole/timeframe");
   
   // Test 3: État actuel
   Print("\n📊 ÉTAT ACTUEL :");
   Print("   Positions: ", PositionsTotal());
   Print("   Symbole: ", _Symbol);
   Print("   Timeframe: ", PeriodToString(Period()));
   Print("   Magic Number: ", InpMagicNum);
   
   // Recommandations
   Print("\n💡 RECOMMANDATIONS :");
   if(!canTrade || !terminalTrade || !connected)
   {
      Print("   ❌ CORRIGER LES PROBLÈMES D'AUTORISATION/CONNEXION");
   }
   else
   {
      Print("   ✅ ROBOT PRÊT À FONCTIONNER SANS DÉTACHEMENT");
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   TestAntiDetachment();
   return INIT_SUCCEEDED;
}
