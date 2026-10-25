
//+------------------------------------------------------------------+
//| SYSTÈME INTELLIGENT SL/TP ET LOTS MINIMUM - ANGELOFSPIKE         |
//+------------------------------------------------------------------+

// Structure pour les informations de symbole
struct SymbolInfo {
    string symbol;
    double minLot;
    double maxLot;
    double lotStep;
    double point;
    double tickValue;
    double tickSize;
    double spread;
    double stopLevel;
    double freezeLevel;
    bool isValid;
};

// Cache des informations de symboles
SymbolInfo g_symbolCache[100];
int g_symbolCacheCount = 0;

//+------------------------------------------------------------------+
//| Obtient les informations complètes d'un symbole                 |
//+------------------------------------------------------------------+
bool GetSymbolInfo(const string symbol, SymbolInfo &info)
{
    // Vérifier le cache d'abord
    for(int i = 0; i < g_symbolCacheCount; i++)
    {
        if(g_symbolCache[i].symbol == symbol)
        {
            info = g_symbolCache[i];
            return info.isValid;
        }
    }
    
    // Remplir les informations du symbole
    info.symbol = symbol;
    info.minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    info.maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    info.lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    info.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    info.tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    info.tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    info.spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * info.point;
    info.stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * info.point;
    info.freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * info.point;
    
    // Vérifier la validité
    info.isValid = (info.minLot > 0 && info.maxLot > 0 && info.lotStep > 0);
    
    // Ajouter au cache
    if(g_symbolCacheCount < 100)
    {
        g_symbolCache[g_symbolCacheCount] = info;
        g_symbolCacheCount++;
    }
    
    Print("📊 Informations symbole ", symbol, ":");
    Print("   Lot min: ", info.minLot, " Lot max: ", info.maxLot, " Step: ", info.lotStep);
    Print("   Stop Level: ", info.stopLevel, " Freeze Level: ", info.freezeLevel);
    Print("   Spread: ", info.spread, " Tick Value: ", info.tickValue);
    
    return info.isValid;
}

//+------------------------------------------------------------------+
//| Calcule la taille de lot optimale pour un symbole               |
//+------------------------------------------------------------------+
double CalculateOptimalLotSize(const string symbol, double riskUSD = 10.0)
{
    SymbolInfo info;
    if(!GetSymbolInfo(symbol, info))
    {
        Print("❌ Impossible d'obtenir les informations du symbole ", symbol);
        return 0.0;
    }
    
    // Calculer la taille de lot basée sur le risque
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskPercent = riskUSD / accountBalance;
    
    // Calculer le lot basé sur le risque
    double calculatedLot = riskPercent * accountBalance / info.tickValue;
    
    // Normaliser selon le step
    double normalizedLot = MathRound(calculatedLot / info.lotStep) * info.lotStep;
    
    // Limiter aux bornes min/max
    normalizedLot = MathMax(normalizedLot, info.minLot);
    normalizedLot = MathMin(normalizedLot, info.maxLot);
    
    // Arrondir à 2 décimales
    normalizedLot = NormalizeDouble(normalizedLot, 2);
    
    Print("💰 Calcul lot optimal ", symbol, ":");
    Print("   Risque: $", riskUSD, " Balance: $", accountBalance);
    Print("   Lot calculé: ", calculatedLot, " Lot normalisé: ", normalizedLot);
    
    return normalizedLot;
}

//+------------------------------------------------------------------+
//| Calcule les SL/TP adéquats pour un symbole                      |
//+------------------------------------------------------------------+
bool CalculateAdequateSLTP(const string symbol, int direction, double entryPrice, 
                          double riskUSD, double rewardUSD, 
                          double &sl, double &tp)
{
    SymbolInfo info;
    if(!GetSymbolInfo(symbol, info))
    {
        Print("❌ Impossible d'obtenir les informations du symbole ", symbol);
        return false;
    }
    
    // Calculer les distances en points
    double slDistancePoints = riskUSD / info.tickValue;
    double tpDistancePoints = rewardUSD / info.tickValue;
    
    // Convertir en prix
    double slDistance = slDistancePoints * info.point;
    double tpDistance = tpDistancePoints * info.point;
    
    // Calculer les niveaux SL/TP
    if(direction == POSITION_TYPE_BUY)
    {
        sl = entryPrice - slDistance;
        tp = entryPrice + tpDistance;
    }
    else
    {
        sl = entryPrice + slDistance;
        tp = entryPrice - tpDistance;
    }
    
    // Vérifier les niveaux minimum (Stop Level)
    double minDistance = info.stopLevel;
    if(direction == POSITION_TYPE_BUY)
    {
        if(entryPrice - sl < minDistance)
        {
            sl = entryPrice - minDistance;
            Print("⚠️ SL ajusté au niveau minimum pour ", symbol);
        }
        if(tp - entryPrice < minDistance)
        {
            tp = entryPrice + minDistance;
            Print("⚠️ TP ajusté au niveau minimum pour ", symbol);
        }
    }
    else
    {
        if(sl - entryPrice < minDistance)
        {
            sl = entryPrice + minDistance;
            Print("⚠️ SL ajusté au niveau minimum pour ", symbol);
        }
        if(entryPrice - tp < minDistance)
        {
            tp = entryPrice - minDistance;
            Print("⚠️ TP ajusté au niveau minimum pour ", symbol);
        }
    }
    
    // Normaliser les prix
    sl = NormalizeDouble(sl, SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    tp = NormalizeDouble(tp, SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    
    Print("🎯 SL/TP calculés pour ", symbol, ":");
    Print("   Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    Print("   Prix entrée: ", entryPrice);
    Print("   SL: ", sl, " (distance: ", MathAbs(sl - entryPrice), ")");
    Print("   TP: ", tp, " (distance: ", MathAbs(tp - entryPrice), ")");
    Print("   Stop Level: ", info.stopLevel);
    
    return true;
}

//+------------------------------------------------------------------+
//| Valide un ordre avant envoi                                      |
//+------------------------------------------------------------------+
bool ValidateOrder(const string symbol, int direction, double lotSize, 
                   double entryPrice, double sl, double tp)
{
    SymbolInfo info;
    if(!GetSymbolInfo(symbol, info))
    {
        Print("❌ Validation échouée: Informations symbole invalides");
        return false;
    }
    
    // Vérifier la taille de lot
    if(lotSize < info.minLot)
    {
        Print("❌ Validation échouée: Lot trop petit (", lotSize, " < ", info.minLot, ")");
        return false;
    }
    
    if(lotSize > info.maxLot)
    {
        Print("❌ Validation échouée: Lot trop grand (", lotSize, " > ", info.maxLot, ")");
        return false;
    }
    
    // Vérifier le step du lot
    double remainder = MathMod(lotSize, info.lotStep);
    if(remainder > 0.0001) // Tolérance pour les erreurs de précision
    {
        Print("❌ Validation échouée: Lot non conforme au step (", lotSize, " step: ", info.lotStep, ")");
        return false;
    }
    
    // Vérifier les niveaux SL/TP
    double minDistance = info.stopLevel;
    double slDistance = MathAbs(sl - entryPrice);
    double tpDistance = MathAbs(tp - entryPrice);
    
    if(slDistance < minDistance)
    {
        Print("❌ Validation échouée: SL trop proche (", slDistance, " < ", minDistance, ")");
        return false;
    }
    
    if(tpDistance < minDistance)
    {
        Print("❌ Validation échouée: TP trop proche (", tpDistance, " < ", minDistance, ")");
        return false;
    }
    
    // Vérifier le spread
    double currentSpread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * info.point;
    if(currentSpread > info.spread * 2) // Spread trop élevé
    {
        Print("⚠️ Attention: Spread élevé (", currentSpread, ")");
    }
    
    Print("✅ Validation réussie pour ", symbol);
    Print("   Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
    
    return true;
}

//+------------------------------------------------------------------+
//| Exécute un trade avec validation complète                        |
//+------------------------------------------------------------------+
bool ExecuteValidatedTrade(const string symbol, int direction, double riskUSD = 10.0, 
                          double rewardUSD = 20.0)
{
    // Obtenir le prix d'entrée
    double entryPrice = 0;
    if(direction == POSITION_TYPE_BUY)
        entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
    else
        entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(entryPrice <= 0)
    {
        Print("❌ Impossible d'obtenir le prix d'entrée pour ", symbol);
        return false;
    }
    
    // Calculer la taille de lot optimale
    double lotSize = CalculateOptimalLotSize(symbol, riskUSD);
    if(lotSize <= 0)
    {
        Print("❌ Impossible de calculer la taille de lot pour ", symbol);
        return false;
    }
    
    // Calculer les SL/TP adéquats
    double sl = 0, tp = 0;
    if(!CalculateAdequateSLTP(symbol, direction, entryPrice, riskUSD, rewardUSD, sl, tp))
    {
        Print("❌ Impossible de calculer les SL/TP pour ", symbol);
        return false;
    }
    
    // Valider l'ordre
    if(!ValidateOrder(symbol, direction, lotSize, entryPrice, sl, tp))
    {
        Print("❌ Ordre invalide pour ", symbol);
        return false;
    }
    
    // Exécuter l'ordre
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lotSize;
    request.type = (direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = entryPrice;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = InpMagicNumber;
    request.comment = "Validated Trade";
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ORDER_FILLING_IOC;
    
    // Envoyer l'ordre
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            Print("✅ TRADE VALIDÉ EXÉCUTÉ - ", symbol);
            Print("   Ticket: ", result.order);
            Print("   Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
            Print("   Lot: ", lotSize);
            Print("   Prix: ", entryPrice);
            Print("   SL: ", sl);
            Print("   TP: ", tp);
            return true;
        }
        else
        {
            Print("❌ Échec exécution: ", result.retcode, " - ", result.comment);
            return false;
        }
    }
    else
    {
        Print("❌ Erreur envoi ordre: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Fonction utilitaire pour les symboles Boom/Crash                 |
//+------------------------------------------------------------------+
bool IsBoomCrashSymbol(const string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

//+------------------------------------------------------------------+
//| Calcule les paramètres spécifiques pour Boom/Crash              |
//+------------------------------------------------------------------+
bool CalculateBoomCrashParameters(const string symbol, int direction, 
                                 double &lotSize, double &sl, double &tp)
{
    if(!IsBoomCrashSymbol(symbol))
        return false;
    
    // Paramètres spécifiques pour Boom/Crash
    double riskUSD = InpMaxLossBoomCrashUSD;
    double rewardUSD = InpTargetProfitUSD;
    
    // Lot fixe pour Boom/Crash
    lotSize = InpBCLotFixed;
    
    // Obtenir le prix d'entrée
    double entryPrice = (direction == POSITION_TYPE_BUY) ? 
                       SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Calculer SL/TP
    return CalculateAdequateSLTP(symbol, direction, entryPrice, riskUSD, rewardUSD, sl, tp);
}

//+------------------------------------------------------------------+
//| Fonction principale pour exécuter un trade sécurisé              |
//+------------------------------------------------------------------+
bool ExecuteSecureTrade(const string symbol, int direction)
{
    Print("🔒 EXÉCUTION TRADE SÉCURISÉ - ", symbol);
    
    if(IsBoomCrashSymbol(symbol))
    {
        // Traitement spécial pour Boom/Crash
        double lotSize, sl, tp;
        if(CalculateBoomCrashParameters(symbol, direction, lotSize, sl, tp))
        {
            double entryPrice = (direction == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                               SymbolInfoDouble(symbol, SYMBOL_BID);
            
            if(ValidateOrder(symbol, direction, lotSize, entryPrice, sl, tp))
            {
                return ExecuteValidatedTrade(symbol, direction, InpMaxLossBoomCrashUSD, InpTargetProfitUSD);
            }
        }
    }
    else
    {
        // Traitement standard pour autres symboles
        return ExecuteValidatedTrade(symbol, direction, InpMaxLossOtherUSD, InpTargetProfitUSD);
    }
    
    return false;
}
