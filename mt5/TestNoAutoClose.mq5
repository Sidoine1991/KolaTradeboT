//+------------------------------------------------------------------+
//|                                            TestNoAutoClose.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test pour vérifier qu'aucun trade n'est fermé automatiquement"

//--- Inputs
input string InpTestSymbol = "Boom 1000 Index"; // Symbole de test
input int    InpTestDuration = 120;             // Durée du test en secondes

//--- Variables
datetime g_testStartTime = 0;
bool g_testActive = false;
int g_initialPositions = 0;
int g_positionCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🧪 TEST PAS DE FERMETURE AUTOMATIQUE - Démarrage");
    Print("📊 Symbole de test: ", InpTestSymbol);
    Print("⏰ Durée du test: ", InpTestDuration, " secondes");
    
    g_testStartTime = TimeCurrent();
    g_testActive = true;
    g_initialPositions = PositionsTotal();
    g_positionCount = g_initialPositions;
    
    Print("📋 POSITIONS INITIALES: ", g_initialPositions);
    Print("📋 PARAMÈTRES DE FERMETURE:");
    Print("   - InpAutoClosePositions: ", (InpAutoClosePositions ? "ACTIVÉ" : "DÉSACTIVÉ"));
    Print("   - InpAutoCloseAfterSpike: ", (InpAutoCloseAfterSpike ? "ACTIVÉ" : "DÉSACTIVÉ"));
    Print("   - InpCloseOnSpikePeak: ", (InpCloseOnSpikePeak ? "ACTIVÉ" : "DÉSACTIVÉ"));
    Print("   - InpSpikeProfitTarget: $", InpSpikeProfitTarget);
    Print("   - InpMaxTotalLoss: $", InpMaxTotalLoss);
    
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
        Print("📊 RÉSULTATS:");
        Print("   - Positions initiales: ", g_initialPositions);
        Print("   - Positions finales: ", PositionsTotal());
        Print("   - Positions fermées automatiquement: ", g_initialPositions - PositionsTotal());
        
        if(PositionsTotal() == g_initialPositions)
        {
            Print("✅ SUCCÈS: Aucune position fermée automatiquement!");
        }
        else
        {
            Print("❌ PROBLÈME: ", g_initialPositions - PositionsTotal(), " position(s) fermée(s) automatiquement!");
        }
        
        g_testActive = false;
        return;
    }
    
    // Surveiller les changements de positions
    int currentPositions = PositionsTotal();
    if(currentPositions != g_positionCount)
    {
        if(currentPositions < g_positionCount)
        {
            Print("⚠️ ATTENTION: Position fermée détectée!");
            Print("   - Avant: ", g_positionCount, " positions");
            Print("   - Maintenant: ", currentPositions, " positions");
            Print("   - Temps: ", TimeToString(TimeCurrent()));
            
            // Lister les positions restantes
            for(int i = 0; i < currentPositions; i++)
            {
                if(PositionGetSymbol(i) != "")
                {
                    Print("   Position restante ", i+1, ": ", PositionGetSymbol(i), 
                          " ", (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                          " Magic: ", PositionGetInteger(POSITION_MAGIC));
                }
            }
        }
        else
        {
            Print("📈 NOUVELLE POSITION: ", currentPositions - g_positionCount, " position(s) ouverte(s)");
        }
        g_positionCount = currentPositions;
    }
    
    // Afficher le statut toutes les 30 secondes
    static datetime lastStatusTime = 0;
    if(TimeCurrent() - lastStatusTime >= 30)
    {
        Print("📊 STATUT TEST: ", TimeCurrent() - g_testStartTime, "s écoulées - Positions: ", currentPositions);
        lastStatusTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🧪 TEST ARRÊTÉ - Raison: ", reason);
    Print("📊 CONCLUSION: Vérification de la fermeture automatique terminée");
}
