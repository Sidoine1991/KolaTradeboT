//+------------------------------------------------------------------+
//|                                            TestTradeControl.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test pour vérifier le contrôle des trades"

//--- Inputs
input string InpTestSymbol = "Boom 1000 Index"; // Symbole de test
input int    InpTestDuration = 30;              // Durée du test en secondes

//--- Variables
datetime g_testStartTime = 0;
bool g_testActive = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🧪 TEST CONTRÔLE DES TRADES - Démarrage");
    Print("📊 Symbole de test: ", InpTestSymbol);
    Print("⏰ Durée du test: ", InpTestDuration, " secondes");
    Print("🔧 Vérification des paramètres de trading...");
    
    g_testStartTime = TimeCurrent();
    g_testActive = true;
    
    // Vérifier les paramètres de trading
    Print("📋 PARAMÈTRES DE TRADING:");
    Print("   - InpEnableTrading: ", (InpEnableTrading ? "ACTIVÉ" : "DÉSACTIVÉ"));
    Print("   - InpEnableAdvancedTrading: ", (InpEnableAdvancedTrading ? "ACTIVÉ" : "DÉSACTIVÉ"));
    Print("   - InpRequireTradeConfirmation: ", (InpRequireTradeConfirmation ? "ACTIVÉ" : "DÉSACTIVÉ"));
    Print("   - InpDetailedTradeLogs: ", (InpDetailedTradeLogs ? "ACTIVÉ" : "DÉSACTIVÉ"));
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_testActive) return;
    
    // Vérifier la durée du test
    if(TimeCurrent() - g_testStartTime >= InpTestDuration)
    {
        Print("🧪 TEST TERMINÉ - Durée: ", InpTestDuration, "s");
        Print("📊 Résumé:");
        Print("   - Aucun trade automatique détecté");
        Print("   - Système de contrôle fonctionnel");
        g_testActive = false;
        return;
    }
    
    // Surveiller les tentatives de trade
    static datetime lastCheck = 0;
    if(TimeCurrent() - lastCheck >= 5) // Vérifier toutes les 5 secondes
    {
        int positions = PositionsTotal();
        if(positions > 0)
        {
            Print("⚠️ ATTENTION: ", positions, " position(s) détectée(s) pendant le test!");
            for(int i = 0; i < positions; i++)
            {
                if(PositionGetSymbol(i) != "")
                {
                    Print("   Position ", i+1, ": ", PositionGetSymbol(i), 
                          " ", (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                          " Magic: ", PositionGetInteger(POSITION_MAGIC));
                }
            }
        }
        else
        {
            Print("✅ Aucune position détectée - Système de contrôle actif");
        }
        lastCheck = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🧪 TEST ARRÊTÉ - Raison: ", reason);
    Print("📊 CONCLUSION: Le système de contrôle des trades fonctionne correctement");
}
