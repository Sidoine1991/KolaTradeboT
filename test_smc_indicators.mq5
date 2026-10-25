//+------------------------------------------------------------------+
//| Test des Indicateurs SMC                                        |
//| Script de test pour vérifier le fonctionnement des indicateurs |
//+------------------------------------------------------------------+
#property copyright "AngelOfSpike Pro"
#property version   "1.0"
#property script_show_inputs

//--- Paramètres de test
input bool TestOrderBlock = true;        // Tester Order Block
input bool TestFairValueGap = true;      // Tester Fair Value Gap
input bool TestBBSqueeze = true;         // Tester BB Squeeze
input int  TestLookback = 50;           // Période de test
input string TestSymbol = "Boom500";     // Symbole de test

//--- Structures SMC (copiées du robot principal)
struct OrderBlock
{
    double high;
    double low;
    bool   isValid;
    datetime time;
};

struct FairValueGap
{
    double top;
    double bottom;
    bool   isValid;
    datetime time;
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🧪 Début du test des indicateurs SMC");
    Print("Symbole de test: ", TestSymbol);
    Print("Période de test: ", TestLookback);
    
    // Vérifier que le symbole existe
    if(!SymbolSelect(TestSymbol, true))
    {
        Print("❌ Erreur: Symbole ", TestSymbol, " non trouvé");
        return;
    }
    
    // Test Order Block
    if(TestOrderBlock)
    {
        Print("\n📊 Test Order Block:");
        OrderBlock ob = FindBullishOrderBlock(TestSymbol, TestLookback);
        if(ob.isValid)
        {
            Print("✅ Order Block trouvé:");
            Print("   - High: ", DoubleToString(ob.high, 5));
            Print("   - Low: ", DoubleToString(ob.low, 5));
            Print("   - Time: ", TimeToString(ob.time));
        }
        else
        {
            Print("❌ Aucun Order Block trouvé");
        }
    }
    
    // Test Fair Value Gap
    if(TestFairValueGap)
    {
        Print("\n📊 Test Fair Value Gap:");
        FairValueGap fvg = FindBullishFVG(TestSymbol, TestLookback);
        if(fvg.isValid)
        {
            Print("✅ Fair Value Gap trouvé:");
            Print("   - Top: ", DoubleToString(fvg.top, 5));
            Print("   - Bottom: ", DoubleToString(fvg.bottom, 5));
            Print("   - Time: ", TimeToString(fvg.time));
        }
        else
        {
            Print("❌ Aucun Fair Value Gap trouvé");
        }
    }
    
    // Test BB Squeeze
    if(TestBBSqueeze)
    {
        Print("\n📊 Test BB Squeeze:");
        bool isSqueeze = IsBBSqueeze(TestSymbol);
        if(isSqueeze)
        {
            Print("✅ BB Squeeze détecté - Le marché est en compression");
        }
        else
        {
            Print("❌ Pas de BB Squeeze - Le marché n'est pas en compression");
        }
    }
    
    // Test de confluence
    Print("\n🎯 Test de Confluence SMC:");
    bool smcSignal = CheckSMCSignal(TestSymbol);
    if(smcSignal)
    {
        Print("🚀 SIGNAL SMC DÉTECTÉ - Conditions de confluence remplies!");
    }
    else
    {
        Print("❌ Pas de signal SMC - Conditions de confluence non remplies");
    }
    
    Print("\n✅ Test des indicateurs SMC terminé");
}

//+------------------------------------------------------------------+
//| Cherche le dernier Order Block HAUSSIER                         |
//+------------------------------------------------------------------+
OrderBlock FindBullishOrderBlock(const string symbol, const int lookback)
{
    OrderBlock ob = {0, 0, false, 0};
    MqlRates rates[];
    
    if(CopyRates(symbol, PERIOD_M1, 0, lookback, rates) < lookback)
        return ob;

    // On parcourt les bougies à l'envers (du plus récent au plus ancien)
    for(int i = lookback - 2; i > 1; i--)
    {
        // 1. On cherche une bougie baissière (l'OB potentiel)
        if(rates[i].close < rates[i].open)
        {
            // 2. On vérifie que la bougie suivante est une forte impulsion haussière
            // qui "casse" le plus haut de notre OB potentiel.
            if(rates[i-1].close > rates[i-1].open && rates[i-1].close > rates[i].high)
            {
                // C'est un OB valide. On le sauvegarde.
                ob.high = rates[i].high;
                ob.low = rates[i].low;
                ob.isValid = true;
                ob.time = rates[i].time;
                return ob; // On retourne le plus récent trouvé
            }
        }
    }
    return ob;
}

//+------------------------------------------------------------------+
//| Cherche le dernier Fair Value Gap HAUSSIER                      |
//+------------------------------------------------------------------+
FairValueGap FindBullishFVG(const string symbol, const int lookback)
{
    FairValueGap fvg = {0, 0, false, 0};
    MqlRates rates[];
    
    if(CopyRates(symbol, PERIOD_M1, 0, lookback, rates) < lookback)
        return fvg;

    // On parcourt les bougies à l'envers
    for(int i = lookback - 3; i > 0; i--)
    {
        // On cherche un FVG haussier : le bas de la bougie N-2 est plus haut que le haut de la bougie N
        if(rates[i-2].low > rates[i].high)
        {
            fvg.top = rates[i-2].low;
            fvg.bottom = rates[i].high;
            fvg.isValid = true;
            fvg.time = rates[i].time;
            return fvg; // On retourne le plus récent
        }
    }
    return fvg;
}

//+------------------------------------------------------------------+
//| Vérifie si le marché est en compression (BB Squeeze)            |
//+------------------------------------------------------------------+
bool IsBBSqueeze(const string symbol)
{
    // Récupérer les valeurs des indicateurs
    double bb_upper[], bb_lower[], atr_values[];
    
    int bb_handle = iBands(symbol, PERIOD_M1, 20, 0, 2.0, PRICE_CLOSE);
    int atr_handle = iATR(symbol, PERIOD_M1, 14);
    
    if(bb_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE) return false;
    
    if(CopyBuffer(bb_handle, 1, 0, 1, bb_upper) < 1 ||
       CopyBuffer(bb_handle, 2, 0, 1, bb_lower) < 1 ||
       CopyBuffer(atr_handle, 0, 0, 1, atr_values) < 1)
    {
        return false;
    }
    
    double bb_width = bb_upper[0] - bb_lower[0];
    double atr = atr_values[0];

    // La condition du Squeeze : la largeur des bandes est très faible par rapport à la volatilité moyenne (ATR)
    if(bb_width < 1.5 * atr)
    {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifie les signaux SMC pour décision de trading                |
//+------------------------------------------------------------------+
bool CheckSMCSignal(const string symbol)
{
    double current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // 1. Pré-requis : Le marché est-il en compression, prêt à exploser ?
    bool is_ready_to_spike = IsBBSqueeze(symbol);
    
    // Si le marché n'est pas prêt, on ne fait RIEN.
    if (!is_ready_to_spike)
    {
        return false;
    }
    
    // 2. Recherche de zones d'intérêt : Y a-t-il une raison FONDAMENTALE pour que le prix réagisse ici ?
    OrderBlock ob = FindBullishOrderBlock(symbol, TestLookback);
    FairValueGap fvg = FindBullishFVG(symbol, TestLookback);
    
    bool in_ob_zone = (ob.isValid && current_price <= ob.high && current_price >= ob.low);
    bool in_fvg_zone = (fvg.isValid && current_price <= fvg.top && current_price >= fvg.bottom);
    
    // 3. Signal de Confluence : on a le pré-requis ET on est dans une zone d'intérêt.
    if (is_ready_to_spike && (in_ob_zone || in_fvg_zone))
    {
        string reason = in_ob_zone ? "Order Block" : "Fair Value Gap";
        Print("🚀 SIGNAL ACHAT SMC sur ", symbol, " détecté. Raison : ", reason, " + BB Squeeze.");
        return true;
    }
    
    return false;
}
