//+------------------------------------------------------------------+
//|                                           BoomDisplayEA.mq5     |
//|                        Copyright 2024, Boom Rising Channel     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Boom Rising Channel"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "EA avec affichage dynamique des résultats d'analyse Boom"

//--- Paramètres d'entrée
input group "=== Configuration API ==="
input string InpApiUrl = "http://localhost:8002/angelofspike/trend";  // URL de l'API Boom
input string InpSymbol = "Boom 1000 Index";                          // Symbole à analyser
input string InpTimeframe = "M1";                                    // Timeframe d'analyse
input int    InpUpdateInterval = 5;                                  // Intervalle de mise à jour (secondes)

input group "=== Configuration Affichage ==="
input double InpDisplayX = 0.75;                                      // Position X (0-1)
input double InpDisplayY = 0.15;                                      // Position Y (0-1)
input double InpDisplayWidth = 0.23;                                  // Largeur (0-1)
input double InpDisplayHeight = 0.25;                                // Hauteur (0-1)
input int    InpFontSize = 8;                                         // Taille de police
input string InpFontName = "Arial";                                   // Nom de police

input group "=== Configuration Couleurs ==="
input color  InpBackgroundColor = C'30,30,30';                        // Couleur de fond
input color  InpTextColor = C'255,255,255';                           // Couleur du texte
input color  InpBorderColorBuy = C'0,255,0';                          // Couleur bordure BUY
input color  InpBorderColorSell = C'255,0,0';                        // Couleur bordure SELL
input color  InpBorderColorNeutral = C'255,255,0';                    // Couleur bordure NEUTRAL

input group "=== Configuration Trading ==="
input bool   InpEnableTrading = false;                                // Activer le trading automatique
input double InpLotSize = 0.1;                                       // Taille de lot
input int    InpStopLoss = 20;                                        // Stop Loss (points)
input int    InpTakeProfit = 50;                                      // Take Profit (points)
input int    InpMagicNumber = 123456;                                 // Numéro magique

//--- Variables globales
string g_displayObjectName = "BoomAnalysisDisplay";
string g_textObjectName = "BoomAnalysisText";
datetime g_lastUpdateTime = 0;
string g_lastAnalysis = "";
bool g_displayCreated = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 Initialisation EA Boom Rising Channel Display");
    
    // Vérifier la connexion MT5
    if(!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        Print("❌ Terminal non connecté");
        return INIT_FAILED;
    }
    
    // Vérifier le trading automatique
    if(InpEnableTrading)
    {
        if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
            Print("❌ Trading non autorisé dans le terminal");
            return INIT_FAILED;
        }
        
        if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
            Print("❌ Trading automatique non autorisé pour les EA");
            return INIT_FAILED;
        }
        
        Print("✅ Trading automatique activé");
    }
    
    // Créer l'affichage initial
    CreateBoomDisplay();
    
    // Démarrer le timer
    EventSetTimer(InpUpdateInterval);
    
    Print("✅ EA Boom Rising Channel Display initialisé");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("⏹️ Arrêt EA Boom Rising Channel Display");
    
    // Arrêter le timer
    EventKillTimer();
    
    // Supprimer l'affichage
    RemoveBoomDisplay();
    
    Print("✅ EA Boom Rising Channel Display arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Mise à jour de l'affichage si nécessaire
    if(TimeCurrent() - g_lastUpdateTime >= InpUpdateInterval)
    {
        UpdateBoomDisplay();
        g_lastUpdateTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    UpdateBoomDisplay();
}

//+------------------------------------------------------------------+
//| Créer l'affichage Boom                                          |
//+------------------------------------------------------------------+
void CreateBoomDisplay()
{
    // Supprimer l'ancien affichage s'il existe
    RemoveBoomDisplay();
    
    // Créer le rectangle de fond
    if(!ObjectCreate(0, g_displayObjectName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        Print("❌ Erreur création rectangle d'affichage");
        return;
    }
    
    // Configurer le rectangle
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_XDISTANCE, (int)(InpDisplayX * ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)));
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_YDISTANCE, (int)(InpDisplayY * ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)));
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_XSIZE, (int)(InpDisplayWidth * ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)));
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_YSIZE, (int)(InpDisplayHeight * ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)));
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_BGCOLOR, InpBackgroundColor);
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_BORDER_COLOR, InpBorderColorNeutral);
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_BORDER_WIDTH, 2);
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_BACK, true);
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_ZORDER, 1000);
    
    // Créer le texte
    if(!ObjectCreate(0, g_textObjectName, OBJ_LABEL, 0, 0, 0))
    {
        Print("❌ Erreur création texte d'affichage");
        return;
    }
    
    // Configurer le texte
    ObjectSetInteger(0, g_textObjectName, OBJPROP_XDISTANCE, (int)(InpDisplayX * ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)) + 10);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_YDISTANCE, (int)(InpDisplayY * ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)) + 10);
    ObjectSetString(0, g_textObjectName, OBJPROP_TEXT, "🚀 BOOM RISING CHANNEL\\n━━━━━━━━━━━━━━━━━━━━━━\\nChargement...");
    ObjectSetString(0, g_textObjectName, OBJPROP_FONT, InpFontName);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_FONTSIZE, InpFontSize);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_COLOR, InpTextColor);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_BACK, false);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, g_textObjectName, OBJPROP_ZORDER, 1001);
    
    g_displayCreated = true;
    Print("✅ Affichage Boom créé sur le graphique");
}

//+------------------------------------------------------------------+
//| Mettre à jour l'affichage Boom                                  |
//+------------------------------------------------------------------+
void UpdateBoomDisplay()
{
    if(!g_displayCreated)
    {
        CreateBoomDisplay();
        return;
    }
    
    // Récupérer l'analyse depuis l'API
    string analysis = GetBoomAnalysis();
    
    if(analysis == "")
    {
        // Afficher un message d'erreur
        ObjectSetString(0, g_textObjectName, OBJPROP_TEXT, 
            "🚀 BOOM RISING CHANNEL\\n━━━━━━━━━━━━━━━━━━━━━━\\n❌ Erreur API\\nVérifiez la connexion");
        ObjectSetInteger(0, g_displayObjectName, OBJPROP_BORDER_COLOR, C'128,128,128');
        return;
    }
    
    // Vérifier si l'analyse a changé
    if(analysis != g_lastAnalysis)
    {
        g_lastAnalysis = analysis;
        
        // Formater le texte d'affichage
        string displayText = FormatAnalysisText(analysis);
        
        // Mettre à jour le texte
        ObjectSetString(0, g_textObjectName, OBJPROP_TEXT, displayText);
        
        // Mettre à jour la couleur de bordure selon la direction
        UpdateBorderColor(analysis);
        
        // Traiter le trading si activé
        if(InpEnableTrading)
        {
            ProcessTradingSignal(analysis);
        }
        
        Print("📊 Affichage Boom mis à jour");
    }
}

//+------------------------------------------------------------------+
//| Récupérer l'analyse Boom depuis l'API                           |
//+------------------------------------------------------------------+
string GetBoomAnalysis()
{
    // Simuler une requête API (à remplacer par une vraie requête HTTP)
    // Pour l'instant, on utilise des données simulées
    
    string url = InpApiUrl + "?symbol=" + InpSymbol + "&timeframe=" + InpTimeframe;
    
    // Simulation de données d'analyse
    static int counter = 0;
    counter++;
    
    string direction = "NEUTRAL";
    int strength = 0;
    int confidence = 0;
    string signal = "boom_hold";
    string trend = "neutral";
    double spike_prob = 0.0;
    int time_to_spike = 0;
    string ema_proximity = "N/A";
    string channel_pos = "N/A";
    double current_price = 0.0;
    double channel_strength = 0.0;
    double breakout_prob = 0.0;
    
    // Simulation de différents scénarios
    if(counter % 10 == 0)
    {
        direction = "BUY";
        strength = 85;
        confidence = 78;
        signal = "boom_trade";
        trend = "bullish";
        spike_prob = 0.85;
        time_to_spike = 120;
        ema_proximity = "EMA10";
        channel_pos = "lower";
        current_price = 10050.0;
        channel_strength = 0.87;
        breakout_prob = 0.18;
    }
    else if(counter % 15 == 0)
    {
        direction = "SELL";
        strength = 72;
        confidence = 65;
        signal = "boom_trade";
        trend = "bearish";
        spike_prob = 0.72;
        time_to_spike = 90;
        ema_proximity = "EMA30";
        channel_pos = "upper";
        current_price = 10030.0;
        channel_strength = 0.82;
        breakout_prob = 0.25;
    }
    else
    {
        direction = "NEUTRAL";
        strength = 45;
        confidence = 35;
        signal = "boom_hold";
        trend = "neutral";
        spike_prob = 0.35;
        time_to_spike = 0;
        ema_proximity = "N/A";
        channel_pos = "middle";
        current_price = 10040.0;
        channel_strength = 0.74;
        breakout_prob = 0.12;
    }
    
    // Créer la réponse JSON simulée
    string jsonResponse = StringFormat(
        "{\"symbol\":\"%s\",\"timeframe\":\"%s\",\"timestamp\":%d,\"direction\":\"%s\",\"strength\":%d,\"confidence\":%d,\"signal\":\"%s\",\"trend\":\"%s\",\"spike_probability\":%.2f,\"time_to_spike\":%d,\"ema_proximity\":\"%s\",\"channel_position\":\"%s\",\"current_price\":%.2f,\"channel_strength\":%.2f,\"breakout_probability\":%.2f}",
        InpSymbol, InpTimeframe, (int)TimeCurrent(), direction, strength, confidence, signal, trend, spike_prob, time_to_spike, ema_proximity, channel_pos, current_price, channel_strength, breakout_prob
    );
    
    return jsonResponse;
}

//+------------------------------------------------------------------+
//| Formater le texte d'analyse pour l'affichage                    |
//+------------------------------------------------------------------+
string FormatAnalysisText(string analysis)
{
    // Parser le JSON (simulation)
    string direction = "N/A";
    int strength = 0;
    int confidence = 0;
    string signal = "N/A";
    double spike_prob = 0.0;
    int time_to_spike = 0;
    string ema_proximity = "N/A";
    string channel_pos = "N/A";
    double current_price = 0.0;
    double channel_strength = 0.0;
    double breakout_prob = 0.0;
    
    // Extraction simple des valeurs (à améliorer avec un vrai parser JSON)
    if(StringFind(analysis, "\"direction\":\"BUY\"") >= 0)
        direction = "BUY";
    else if(StringFind(analysis, "\"direction\":\"SELL\"") >= 0)
        direction = "SELL";
    else
        direction = "NEUTRAL";
    
    // Extraire d'autres valeurs de manière simplifiée
    int pos = StringFind(analysis, "\"strength\":");
    if(pos >= 0)
    {
        string strengthStr = StringSubstr(analysis, pos + 11, 3);
        strength = (int)StringToInteger(strengthStr);
    }
    
    pos = StringFind(analysis, "\"confidence\":");
    if(pos >= 0)
    {
        string confidenceStr = StringSubstr(analysis, pos + 13, 3);
        confidence = (int)StringToInteger(confidenceStr);
    }
    
    pos = StringFind(analysis, "\"spike_probability\":");
    if(pos >= 0)
    {
        string probStr = StringSubstr(analysis, pos + 20, 4);
        spike_prob = StringToDouble(probStr);
    }
    
    pos = StringFind(analysis, "\"time_to_spike\":");
    if(pos >= 0)
    {
        string timeStr = StringSubstr(analysis, pos + 17, 3);
        time_to_spike = (int)StringToInteger(timeStr);
    }
    
    pos = StringFind(analysis, "\"ema_proximity\":\"");
    if(pos >= 0)
    {
        int endPos = StringFind(analysis, "\"", pos + 17);
        if(endPos > pos + 17)
            ema_proximity = StringSubstr(analysis, pos + 17, endPos - pos - 17);
    }
    
    pos = StringFind(analysis, "\"channel_position\":\"");
    if(pos >= 0)
    {
        int endPos = StringFind(analysis, "\"", pos + 20);
        if(endPos > pos + 20)
            channel_pos = StringSubstr(analysis, pos + 20, endPos - pos - 20);
    }
    
    pos = StringFind(analysis, "\"current_price\":");
    if(pos >= 0)
    {
        string priceStr = StringSubstr(analysis, pos + 16, 8);
        current_price = StringToDouble(priceStr);
    }
    
    pos = StringFind(analysis, "\"channel_strength\":");
    if(pos >= 0)
    {
        string strengthStr = StringSubstr(analysis, pos + 19, 5);
        channel_strength = StringToDouble(strengthStr);
    }
    
    pos = StringFind(analysis, "\"breakout_probability\":");
    if(pos >= 0)
    {
        string breakoutStr = StringSubstr(analysis, pos + 23, 5);
        breakout_prob = StringToDouble(breakoutStr);
    }
    
    // Formater le texte d'affichage
    string displayText = StringFormat(
        "🚀 BOOM RISING CHANNEL\\n━━━━━━━━━━━━━━━━━━━━━━\\nDirection: %s\\nForce: %d%%\\nConfiance: %d%%\\nSignal: %s\\nSpike Prob: %.1f%%\\nTemps: %ds\\nEMA: %s\\nCanal: %s\\nPrix: %.2f\\nCanal Force: %.1f%%\\nBreakout: %.1f%%\\n⏰ %s",
        direction, strength, confidence, signal, spike_prob * 100, time_to_spike, ema_proximity, channel_pos, current_price, channel_strength * 100, breakout_prob * 100, TimeToString(TimeCurrent(), TIME_MINUTES)
    );
    
    return displayText;
}

//+------------------------------------------------------------------+
//| Mettre à jour la couleur de bordure                             |
//+------------------------------------------------------------------+
void UpdateBorderColor(string analysis)
{
    color borderColor = InpBorderColorNeutral;
    
    if(StringFind(analysis, "\"direction\":\"BUY\"") >= 0)
        borderColor = InpBorderColorBuy;
    else if(StringFind(analysis, "\"direction\":\"SELL\"") >= 0)
        borderColor = InpBorderColorSell;
    
    ObjectSetInteger(0, g_displayObjectName, OBJPROP_BORDER_COLOR, borderColor);
}

//+------------------------------------------------------------------+
//| Traiter le signal de trading                                    |
//+------------------------------------------------------------------+
void ProcessTradingSignal(string analysis)
{
    if(!InpEnableTrading)
        return;
    
    // Vérifier les conditions de trading
    if(StringFind(analysis, "\"direction\":\"BUY\"") >= 0 && StringFind(analysis, "\"confidence\":") >= 0)
    {
        // Extraire la confiance
        int pos = StringFind(analysis, "\"confidence\":");
        if(pos >= 0)
        {
            string confidenceStr = StringSubstr(analysis, pos + 13, 3);
            int confidence = (int)StringToInteger(confidenceStr);
            
            if(confidence >= 70)  // Seuil de confiance minimum
            {
                ExecuteBuyOrder();
            }
        }
    }
    else if(StringFind(analysis, "\"direction\":\"SELL\"") >= 0 && StringFind(analysis, "\"confidence\":") >= 0)
    {
        // Extraire la confiance
        int pos = StringFind(analysis, "\"confidence\":");
        if(pos >= 0)
        {
            string confidenceStr = StringSubstr(analysis, pos + 13, 3);
            int confidence = (int)StringToInteger(confidenceStr);
            
            if(confidence >= 70)  // Seuil de confiance minimum
            {
                ExecuteSellOrder();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Exécuter un ordre d'achat                                        |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = InpSymbol;
    request.volume = InpLotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
    request.sl = request.price - InpStopLoss * SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    request.tp = request.price + InpTakeProfit * SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    request.magic = InpMagicNumber;
    request.comment = "Boom Rising Channel BUY";
    
    if(OrderSend(request, result))
    {
        Print("✅ Ordre BUY exécuté: ", result.order);
    }
    else
    {
        Print("❌ Erreur ordre BUY: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Exécuter un ordre de vente                                       |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = InpSymbol;
    request.volume = InpLotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    request.sl = request.price + InpStopLoss * SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    request.tp = request.price - InpTakeProfit * SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    request.magic = InpMagicNumber;
    request.comment = "Boom Rising Channel SELL";
    
    if(OrderSend(request, result))
    {
        Print("✅ Ordre SELL exécuté: ", result.order);
    }
    else
    {
        Print("❌ Erreur ordre SELL: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Supprimer l'affichage Boom                                      |
//+------------------------------------------------------------------+
void RemoveBoomDisplay()
{
    ObjectDelete(0, g_displayObjectName);
    ObjectDelete(0, g_textObjectName);
    g_displayCreated = false;
    Print("✅ Affichage Boom supprimé");
}
