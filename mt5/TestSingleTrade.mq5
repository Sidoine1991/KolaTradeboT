//+------------------------------------------------------------------+
//|                                            TestSingleTrade.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test pour vérifier qu'un seul trade s'exécute à la fois"

//--- Inputs
input string InpTestSymbol = "Boom 1000 Index"; // Symbole de test
input int    InpTestDuration = 60;              // Durée du test en secondes

//--- Variables
datetime g_testStartTime = 0;
int g_tradeCount = 0;
bool g_testActive = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🧪 TEST SINGLE TRADE - Démarrage");
    g_testStartTime = TimeCurrent();
    g_testActive = true;
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
        Print("🧪 TEST TERMINÉ - Durée: ", InpTestDuration, "s - Trades détectés: ", g_tradeCount);
        g_testActive = false;
        return;
    }
    
    // Compter les positions ouvertes
    int currentPositions = PositionsTotal();
    
    if(currentPositions > 1)
    {
        Print("❌ PROBLÈME DÉTECTÉ: ", currentPositions, " positions ouvertes simultanément!");
        Print("   Temps: ", TimeToString(TimeCurrent()));
        
        // Lister toutes les positions
        for(int i = 0; i < currentPositions; i++)
        {
            if(PositionGetSymbol(i) != "")
            {
                Print("   Position ", i+1, ": ", PositionGetSymbol(i), 
                      " ", (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                      " Magic: ", PositionGetInteger(POSITION_MAGIC));
            }
        }
    }
    else if(currentPositions == 1)
    {
        g_tradeCount++;
        if(g_tradeCount == 1)
        {
            Print("✅ PREMIER TRADE DÉTECTÉ - Symbole: ", PositionGetSymbol(0),
                  " Direction: ", (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL"));
        }
    }
    
    // Afficher le statut toutes les 10 secondes
    static datetime lastStatusTime = 0;
    if(TimeCurrent() - lastStatusTime >= 10)
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
}
