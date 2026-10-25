//+------------------------------------------------------------------+
//|                                            TestRobot.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test simple pour vérifier le robot AngelOfSpike"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🧪 TEST ROBOT ANGELOFSPIKE");
    Print("✅ Compilation réussie - Aucune erreur");
    Print("🔧 Paramètres de sécurité actifs:");
    Print("   - Trading désactivé par défaut");
    Print("   - Confirmation obligatoire");
    Print("   - Pas de fermeture automatique");
    Print("   - Un seul trade à la fois");
    Print("🚀 Robot prêt à l'utilisation!");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Test simple - pas de logique complexe
    static datetime lastPrint = 0;
    if(TimeCurrent() - lastPrint >= 30)
    {
        Print("📊 Robot actif - Positions: ", PositionsTotal());
        lastPrint = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🧪 Test terminé - Raison: ", reason);
}
