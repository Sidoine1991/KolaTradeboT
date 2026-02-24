//+------------------------------------------------------------------+
//| Fonctions de détection pré-spike pour BoomCrash_Strategy_Bot.mq5 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DÉTECTION PRÉ-SPIKE : afficher flèche d'alerte quelques secondes avant |
//+------------------------------------------------------------------+
void CheckPreSpikeDetection(bool is_boom, bool is_crash, bool allow_buy, bool allow_sell, double rsi_val, double ema_fast, double ema_slow)
{
    // Calculer la confiance pré-spike (0-100%)
    double confidence = 0.0;
    bool spike_imminent = false;
    
    if(is_boom && allow_buy)
    {
        // Boom : RSI très bas + EMA fast < EMA slow (prêt à croiser)
        confidence = (RSI_Oversold_Level - rsi_val) * 2.0; // Plus RSI est bas, plus confiance est haute
        if(ema_fast < ema_slow && confidence > 30) spike_imminent = true;
    }
    else if(is_crash && allow_sell)
    {
        // Crash : RSI très haut + EMA fast > EMA slow (prêt à croiser)
        confidence = (rsi_val - RSI_Overbought_Level) * 2.0; // Plus RSI est haut, plus confiance est haute
        if(ema_fast > ema_slow && confidence > 30) spike_imminent = true;
    }
    
    // Si un spike est imminent et qu'on n'a pas déjà affiché la flèche
    if(spike_imminent && confidence > g_preSpikeConfidence && !g_preSpikeDetected)
    {
        CreatePreSpikeArrow(is_boom ? "BOOM" : "CRASH", confidence);
        g_preSpikeDetected = true;
        g_preSpikeConfidence = confidence;
        g_preSpikeArrowTime = TimeCurrent();
        
        Print("🚨 ALERTE PRÉ-SPIKE ", (is_boom ? "BOOM" : "CRASH"), " - Confiance: ", DoubleToString(confidence, 1), "% - Spike attendu dans quelques secondes!");
    }
    // Réinitialiser si la confiance diminue ou si le temps est écoulé
    else if(!spike_imminent || (TimeCurrent() - g_preSpikeArrowTime > 60))
    {
        if(g_preSpikeArrowName != "" && ObjectFind(0, g_preSpikeArrowName) >= 0)
        {
            ObjectDelete(0, g_preSpikeArrowName);
        }
        g_preSpikeDetected = false;
        g_preSpikeConfidence = 0.0;
        g_preSpikeArrowName = "";
    }
}

//+------------------------------------------------------------------+
//| Créer une flèche de pré-spike (alerte quelques secondes avant)  |
//+------------------------------------------------------------------+
void CreatePreSpikeArrow(string type, double confidence)
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    g_preSpikeArrowName = "BoomCrash_PRE_SPIKE_" + IntegerToString((int)TimeCurrent());
    
    // Couleur selon le type et la confiance
    color arrow_color = (type == "BOOM") ? 
        (confidence > 70 ? clrLime : clrGreen) : 
        (confidence > 70 ? clrRed : clrOrange);
    
    // Créer la flèche
    ObjectCreate(0, g_preSpikeArrowName, OBJ_ARROW_UP, 0, TimeCurrent(), current_price);
    ObjectSetInteger(0, g_preSpikeArrowName, OBJPROP_COLOR, arrow_color);
    ObjectSetInteger(0, g_preSpikeArrowName, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, g_preSpikeArrowName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    ObjectSetString(0, g_preSpikeArrowName, OBJPROP_TEXT, "⚡ " + type + " " + DoubleToString(confidence, 0) + "%");
    
    // Ajouter un label explicatif
    string label_name = g_preSpikeArrowName + "_LABEL";
    ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent() + 5, current_price);
    ObjectSetString(0, label_name, OBJPROP_TEXT, "SPIKE IMMINENT\n" + DoubleToString(confidence, 1) + "% confiance");
    ObjectSetInteger(0, label_name, OBJPROP_COLOR, arrow_color);
    ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
}

//+------------------------------------------------------------------+
