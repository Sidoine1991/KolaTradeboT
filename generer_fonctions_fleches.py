#!/usr/bin/env python3
"""
Système de Flèches Distinguées - AngelOfSpike
=============================================

Ce script crée les fonctions MQL5 pour distinguer clairement entre:
1. Flèche de tendance (statique)
2. Flèche de spike (clignotante) - déclenche le trading automatique
"""

def generer_fonctions_fleches_mql5():
    """
    Génère les fonctions MQL5 pour le système de flèches distinguées.
    """
    print("GENERATION FONCTIONS FLECHES DISTINGUEES - MQL5")
    print("=" * 55)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Fonctions MQL5 pour le système de flèches
    fonctions_mql5 = '''
//+------------------------------------------------------------------+
//| SYSTÈME DE FLÈCHES DISTINGUÉES - ANGELOFSPIKE                    |
//+------------------------------------------------------------------+

// Variables globales pour les flèches
datetime g_lastTrendArrowTime = 0;
datetime g_lastSpikeArrowTime = 0;
int g_trendArrowCounter = 0;
int g_spikeArrowCounter = 0;

//+------------------------------------------------------------------+
//| Dessine une flèche de tendance (statique)                       |
//+------------------------------------------------------------------+
void DrawTrendArrow(const string symbol, int direction, double price, datetime time)
{
    string arrowName = "TREND_" + symbol + "_" + IntegerToString(time);
    
    // Supprimer l'ancienne flèche de tendance si elle existe
    if(ObjectFind(0, arrowName) >= 0)
        ObjectDelete(0, arrowName);
    
    // Créer la flèche de tendance
    if(!ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, price))
    {
        Print("Erreur création flèche de tendance: ", GetLastError());
        return;
    }
    
    // Configuration de la flèche de tendance
    if(direction == POSITION_TYPE_BUY)
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrDodgerBlue); // Bleu pour tendance
    }
    else
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 234); // Flèche vers le bas
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrOrange); // Orange pour tendance
    }
    
    ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
    ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
    
    g_lastTrendArrowTime = time;
    g_trendArrowCounter++;
    
    Print("📈 FLÈCHE DE TENDANCE dessinée sur ", symbol, " - Direction: ", 
          (direction == POSITION_TYPE_BUY ? "HAUSSIÈRE" : "BAISSIÈRE"));
}

//+------------------------------------------------------------------+
//| Dessine une flèche de spike (clignotante)                       |
//+------------------------------------------------------------------+
void DrawSpikeArrow(const string symbol, int direction, double price, datetime time)
{
    string arrowName = "SPIKE_" + symbol + "_" + IntegerToString(time);
    
    // Supprimer l'ancienne flèche de spike si elle existe
    if(ObjectFind(0, arrowName) >= 0)
        ObjectDelete(0, arrowName);
    
    // Créer la flèche de spike
    if(!ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, price))
    {
        Print("Erreur création flèche de spike: ", GetLastError());
        return;
    }
    
    // Configuration de la flèche de spike (plus visible)
    if(direction == POSITION_TYPE_BUY)
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime); // Vert vif pour spike
    }
    else
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 234); // Flèche vers le bas
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed); // Rouge vif pour spike
    }
    
    ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3); // Plus épaisse
    ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
    ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
    
    g_lastSpikeArrowTime = time;
    g_spikeArrowCounter++;
    
    // Démarrer le clignotement
    StartArrowBlinking(arrowName, InpArrowBlinkSeconds);
    
    Print("⚡ FLÈCHE DE SPIKE CLIGNOTANTE dessinée sur ", symbol, " - Direction: ", 
          (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    
    // Déclencher le trading automatique si activé
    if(InpTradeOnSpikeImmediately)
    {
        ExecuteSpikeTrade(symbol, direction, price);
    }
}

//+------------------------------------------------------------------+
//| Démarre le clignotement d'une flèche                             |
//+------------------------------------------------------------------+
void StartArrowBlinking(const string arrowName, int blinkSeconds)
{
    // Créer un timer pour le clignotement
    static int blinkTimer = 0;
    
    // Démarrer le clignotement
    datetime blinkEndTime = TimeCurrent() + blinkSeconds;
    
    // Boucle de clignotement
    while(TimeCurrent() < blinkEndTime)
    {
        // Alterner la visibilité
        ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
        Sleep(500); // 500ms cachée
        
        if(TimeCurrent() >= blinkEndTime) break;
        
        ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, false);
        Sleep(500); // 500ms visible
        
        if(TimeCurrent() >= blinkEndTime) break;
    }
    
    // Arrêter le clignotement - laisser la flèche visible
    ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, false);
    
    Print("🔄 Clignotement terminé pour ", arrowName);
}

//+------------------------------------------------------------------+
//| Exécute un trade sur signal de spike                             |
//+------------------------------------------------------------------+
void ExecuteSpikeTrade(const string symbol, int direction, double price)
{
    // Vérifier les conditions de trading
    if(!InpEnableTrading || !InpEnableSpikeTrading)
    {
        Print("⚠️ Trading désactivé - Trade non exécuté");
        return;
    }
    
    // Vérifier les limites de positions
    if(CountOpenPositionsEA() >= InpMaxGlobalPositions)
    {
        Print("⚠️ Limite de positions atteinte - Trade non exécuté");
        return;
    }
    
    // Vérifier le cooldown
    if(TimeCurrent() - g_lastTradeTime < InpMinSecondsBetweenSameSymbol)
    {
        Print("⚠️ Cooldown actif - Trade non exécuté");
        return;
    }
    
    // Calculer la taille de lot
    double lotSize = CalculateLotSize(symbol);
    if(lotSize <= 0)
    {
        Print("⚠️ Taille de lot invalide - Trade non exécuté");
        return;
    }
    
    // Calculer SL et TP
    double sl = 0, tp = 0;
    CalculateSLTP(symbol, direction, price, sl, tp);
    
    // Exécuter le trade
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lotSize;
    request.type = (direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = (direction == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    request.sl = sl;
    request.tp = tp;
    request.deviation = InpSlippagePoints;
    request.magic = InpMagicNumber;
    request.comment = "Spike Auto Trade";
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ORDER_FILLING_IOC;
    
    // Envoyer l'ordre
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            g_lastTradeTime = TimeCurrent();
            Print("✅ TRADE SPIKE EXÉCUTÉ - Ticket: ", result.order, " Direction: ", 
                  (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " Lot: ", lotSize);
            
            // Déclencher une alerte
            if(InpEnableAlerts)
            {
                string alertMsg = StringFormat("SPIKE TRADE EXÉCUTÉ\\n%s %s\\nLot: %.2f", 
                                              symbol, (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), lotSize);
                Alert(alertMsg);
            }
        }
        else
        {
            Print("❌ Échec exécution trade: ", result.retcode, " - ", result.comment);
        }
    }
    else
    {
        Print("❌ Erreur envoi ordre: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calcule la taille de lot pour un trade                           |
//+------------------------------------------------------------------+
double CalculateLotSize(const string symbol)
{
    // Utiliser le lot fixe pour Boom/Crash
    if(IsBoomCrashSymbol(symbol))
    {
        return InpBCLotFixed;
    }
    
    // Calculer basé sur le capital par trade
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lotSize = InpCapitalPerTradeUSD / accountBalance;
    
    // Limiter la taille de lot
    lotSize = MathMax(lotSize, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
    lotSize = MathMin(lotSize, InpMaxLotSize);
    
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Calcule SL et TP pour un trade                                   |
//+------------------------------------------------------------------+
void CalculateSLTP(const string symbol, int direction, double price, double &sl, double &tp)
{
    if(IsBoomCrashSymbol(symbol))
    {
        // SL et TP fixes pour Boom/Crash
        double slUSD = InpMaxLossBoomCrashUSD;
        double tpUSD = InpTargetProfitUSD;
        
        // Convertir en points
        double pointValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double slPoints = slUSD / pointValue;
        double tpPoints = tpUSD / pointValue;
        
        if(direction == POSITION_TYPE_BUY)
        {
            sl = price - slPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
            tp = price + tpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
        }
        else
        {
            sl = price + slPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
            tp = price - tpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
        }
    }
    else
    {
        // SL et TP pour autres symboles
        double slUSD = InpMaxLossOtherUSD;
        double tpUSD = InpTargetProfitUSD;
        
        // Convertir en points
        double pointValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double slPoints = slUSD / pointValue;
        double tpPoints = tpUSD / pointValue;
        
        if(direction == POSITION_TYPE_BUY)
        {
            sl = price - slPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
            tp = price + tpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
        }
        else
        {
            sl = price + slPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
            tp = price - tpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est Boom/Crash                             |
//+------------------------------------------------------------------+
bool IsBoomCrashSymbol(const string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

//+------------------------------------------------------------------+
//| Compte les positions ouvertes par l'EA                           |
//+------------------------------------------------------------------+
int CountOpenPositionsEA()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                count++;
            }
        }
    }
    return count;
}
'''
    
    # Sauvegarder les fonctions dans un fichier
    nom_fichier = f"fonctions_fleches_distinguées_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.mq5"
    
    try:
        with open(nom_fichier, "w", encoding="utf-8") as f:
            f.write(fonctions_mql5)
        
        print(f"OK Fonctions MQL5 sauvegardees: {nom_fichier}")
        
    except Exception as e:
        print(f"ERREUR sauvegarde: {e}")
    
    print()
    
    # Instructions d'intégration
    print("INSTRUCTIONS D'INTEGRATION:")
    print("-" * 30)
    
    instructions = [
        "1. Copier les fonctions dans le fichier AngelOfSpike.mq5",
        "2. Ajouter les variables globales au debut du fichier",
        "3. Remplacer les anciennes fonctions DrawSpikeArrow par les nouvelles",
        "4. Ajouter les nouvelles fonctions:",
        "   - DrawTrendArrow() (flèche de tendance statique)",
        "   - DrawSpikeArrow() (flèche de spike clignotante)",
        "   - StartArrowBlinking() (gestion du clignotement)",
        "   - ExecuteSpikeTrade() (exécution automatique)",
        "5. Modifier la logique de détection pour utiliser les deux types de flèches",
        "6. Recompiler l'EA (F7)",
        "7. Tester sur un graphique Boom/Crash"
    ]
    
    for instruction in instructions:
        print(f"   {instruction}")
    
    print()
    
    # Différences entre les flèches
    print("DIFFERENCES ENTRE LES FLECHES:")
    print("-" * 35)
    
    differences = [
        "FLECHE DE TENDANCE (statique):",
        "   - Couleur: Bleu (BUY) / Orange (SELL)",
        "   - Taille: Normale (width=2)",
        "   - Comportement: Ne clignote pas",
        "   - Usage: Indique la direction generale",
        "   - Fonction: DrawTrendArrow()",
        "",
        "FLECHE DE SPIKE (clignotante):",
        "   - Couleur: Vert vif (BUY) / Rouge vif (SELL)",
        "   - Taille: Plus epaisse (width=3)",
        "   - Comportement: Clignote pendant 3 secondes",
        "   - Usage: Annonce un spike imminent",
        "   - Fonction: DrawSpikeArrow()",
        "   - Action: Declenche le trading automatique"
    ]
    
    for difference in differences:
        print(f"   {difference}")
    
    print()
    
    # Logique de trading
    print("LOGIQUE DE TRADING AUTOMATIQUE:")
    print("-" * 35)
    
    logique = [
        "1. DETECTION DU SIGNAL:",
        "   - Analyse des conditions de spike",
        "   - Calcul de la probabilite M1",
        "   - Verification des seuils",
        "",
        "2. AFFICHAGE DE LA FLECHE:",
        "   - Flèche de spike clignotante",
        "   - Couleur vive selon la direction",
        "   - Clignotement pendant 3 secondes",
        "",
        "3. EXECUTION AUTOMATIQUE:",
        "   - Verification des conditions de trading",
        "   - Calcul de la taille de lot",
        "   - Calcul des SL/TP",
        "   - Envoi de l'ordre au marché",
        "",
        "4. CONFIRMATION:",
        "   - Message de confirmation",
        "   - Alerte si activée",
        "   - Mise à jour des statistiques"
    ]
    
    for item in logique:
        print(f"   {item}")
    
    print()
    print("GENERATION TERMINEE")
    print("=" * 55)
    
    return fonctions_mql5

if __name__ == "__main__":
    import datetime
    generer_fonctions_fleches_mql5()
