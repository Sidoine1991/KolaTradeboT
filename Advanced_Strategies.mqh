//+------------------------------------------------------------------+
//| Stratégies Avancées de Trading - Entrées Précises                 |
//+------------------------------------------------------------------+

//--- Structure pour scoring multi-stratégies
struct SignalScore
{
    double total_score;        // Score total 0-100%
    int    strategies_count;   // Nombre de stratégies validées
    string strategy_names[10]; // Noms des stratégies activées
    double individual_scores[10]; // Scores individuels
};

//--- Variables globales pour stratégies avancées
SignalScore g_buySignal, g_sellSignal;

//+------------------------------------------------------------------+
//| STRATÉGIE 1: DÉTECTION DE PATTERNS DE BOUGIES AVANCÉS          |
//+------------------------------------------------------------------+
bool DetectCandlePatterns(string& pattern_name, double& confidence)
{
    double open[], high[], low[], close[];
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyOpen(_Symbol, _Period, 0, 5, open) < 5 ||
       CopyHigh(_Symbol, _Period, 0, 5, high) < 5 ||
       CopyLow(_Symbol, _Period, 0, 5, low) < 5 ||
       CopyClose(_Symbol, _Period, 0, 5, close) < 5)
       return false;
    
    // Pattern Hammer/Hanging Man (retournement)
    double body_size = MathAbs(close[0] - open[0]);
    double upper_shadow = high[0] - MathMax(open[0], close[0]);
    double lower_shadow = MathMin(open[0], close[0]) - low[0];
    double total_range = high[0] - low[0];
    
    if(total_range == 0) return false;
    
    // Hammer (bullish)
    if(lower_shadow > 2 * body_size && upper_shadow < 0.1 * total_range && close[0] > open[0])
    {
        pattern_name = "HAMMER_BULLISH";
        confidence = 75.0;
        return true;
    }
    
    // Shooting Star (bearish)
    if(upper_shadow > 2 * body_size && lower_shadow < 0.1 * total_range && close[0] < open[0])
    {
        pattern_name = "SHOOTING_STAR_BEARISH";
        confidence = 75.0;
        return true;
    }
    
    // Engulfing patterns
    if(close[1] > open[1] && close[0] < open[0] && open[0] > close[1] && close[0] < open[1])
    {
        pattern_name = "BEARISH_ENGULFING";
        confidence = 85.0;
        return true;
    }
    
    if(close[1] < open[1] && close[0] > open[0] && open[0] < close[1] && close[0] > open[1])
    {
        pattern_name = "BULLISH_ENGULFING";
        confidence = 85.0;
        return true;
    }
    
    // Doji (hésitation)
    if(body_size < 0.1 * total_range)
    {
        pattern_name = "DOJI";
        confidence = 60.0;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| STRATÉGIE 2: CONFIRMATION MULTI-INDICATEURS                     |
//+------------------------------------------------------------------+
bool GetMultiIndicatorConfirmation(bool is_buy, double& confidence)
{
    double rsi[], macd_main[], macd_signal[], bb_upper[], bb_lower[], stoch_k[];
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);
    ArraySetAsSeries(stoch_k, true);
    
    int rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    int macd_handle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
    int bb_handle = iBands(_Symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);
    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
    
    if(rsi_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE || 
       bb_handle == INVALID_HANDLE || stoch_handle == INVALID_HANDLE)
       return false;
    
    if(CopyBuffer(rsi_handle, 0, 0, 2, rsi) < 2 ||
       CopyBuffer(macd_handle, 0, 0, 2, macd_main) < 2 ||
       CopyBuffer(macd_handle, 1, 0, 2, macd_signal) < 2 ||
       CopyBuffer(bb_handle, 1, 0, 2, bb_upper) < 2 ||
       CopyBuffer(bb_handle, 2, 0, 2, bb_lower) < 2 ||
       CopyBuffer(stoch_handle, 0, 0, 2, stoch_k) < 2)
    {
        IndicatorRelease(rsi_handle);
        IndicatorRelease(macd_handle);
        IndicatorRelease(bb_handle);
        IndicatorRelease(stoch_handle);
        return false;
    }
    
    int confirmations = 0;
    
    if(is_buy)
    {
        // RSI survente
        if(rsi[0] < 35) confirmations++;
        // MACD croisement haussier
        if(macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1]) confirmations++;
        // Prix près bande inférieure Bollinger
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(current_price <= bb_lower[0] * 1.02) confirmations++;
        // Stochastic survente
        if(stoch_k[0] < 20) confirmations++;
        
        confidence = (confirmations * 25.0); // Max 100%
    }
    else // SELL
    {
        // RSI surachat
        if(rsi[0] > 65) confirmations++;
        // MACD croisement baissier
        if(macd_main[0] < macd_signal[0] && macd_main[1] >= macd_signal[1]) confirmations++;
        // Prix près bande supérieure Bollinger
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if(current_price >= bb_upper[0] * 0.98) confirmations++;
        // Stochastic surachat
        if(stoch_k[0] > 80) confirmations++;
        
        confidence = (confirmations * 25.0); // Max 100%
    }
    
    IndicatorRelease(rsi_handle);
    IndicatorRelease(macd_handle);
    IndicatorRelease(bb_handle);
    IndicatorRelease(stoch_handle);
    
    return confirmations >= 2; // Au moins 2 confirmations requises
}

//+------------------------------------------------------------------+
//| STRATÉGIE 3: FILTRE DE VOLATILITÉ ET VOLUME                      |
//+------------------------------------------------------------------+
bool CheckVolatilityVolumeFilter(bool is_buy, double& confidence)
{
    double atr[], volume[];
    ArraySetAsSeries(atr, true);
    ArraySetAsSeries(volume, true);
    
    int atr_handle = iATR(_Symbol, _Period, 14);
    if(atr_handle == INVALID_HANDLE) return false;
    
    if(CopyBuffer(atr_handle, 0, 0, 10, atr) < 10 ||
       CopyTickVolume(_Symbol, _Period, 0, 10, volume) < 10)
    {
        IndicatorRelease(atr_handle);
        return false;
    }
    
    double current_atr = atr[0];
    double avg_atr = 0;
    double current_volume = volume[0];
    double avg_volume = 0;
    
    for(int i = 1; i < 10; i++)
    {
        avg_atr += atr[i];
        avg_volume += volume[i];
    }
    avg_atr /= 9;
    avg_volume /= 9;
    
    IndicatorRelease(atr_handle);
    
    // Volatilité expansion (bon pour spikes)
    double volatility_ratio = current_atr / avg_atr;
    double volume_ratio = current_volume / avg_volume;
    
    bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
    bool is_crash = (StringFind(_Symbol, "Crash") >= 0);
    
    if(is_boom && is_buy)
    {
        // Boom: volatilité élevée + volume élevé = bon signal
        confidence = MathMin(100.0, (volatility_ratio * 30.0) + (volume_ratio * 20.0));
        return volatility_ratio > 1.2 && volume_ratio > 1.5;
    }
    else if(is_crash && !is_buy)
    {
        // Crash: même logique
        confidence = MathMin(100.0, (volatility_ratio * 30.0) + (volume_ratio * 20.0));
        return volatility_ratio > 1.2 && volume_ratio > 1.5;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| STRATÉGIE 4: ALIGNEMENT MULTI-TIMEFRAME                          |
//+------------------------------------------------------------------+
bool CheckMultiTimeframeAlignment(bool is_buy, double& confidence)
{
    double ema_m5_fast[], ema_m5_slow[], ema_h1_fast[], ema_h1_slow[];
    ArraySetAsSeries(ema_m5_fast, true);
    ArraySetAsSeries(ema_m5_slow, true);
    ArraySetAsSeries(ema_h1_fast, true);
    ArraySetAsSeries(ema_h1_slow, true);
    
    int ema_m5_fast_handle = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);
    int ema_m5_slow_handle = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
    int ema_h1_fast_handle = iMA(_Symbol, PERIOD_H1, 10, 0, MODE_EMA, PRICE_CLOSE);
    int ema_h1_slow_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    
    if(ema_m5_fast_handle == INVALID_HANDLE || ema_m5_slow_handle == INVALID_HANDLE ||
       ema_h1_fast_handle == INVALID_HANDLE || ema_h1_slow_handle == INVALID_HANDLE)
       return false;
    
    if(CopyBuffer(ema_m5_fast_handle, 0, 0, 2, ema_m5_fast) < 2 ||
       CopyBuffer(ema_m5_slow_handle, 0, 0, 2, ema_m5_slow) < 2 ||
       CopyBuffer(ema_h1_fast_handle, 0, 0, 2, ema_h1_fast) < 2 ||
       CopyBuffer(ema_h1_slow_handle, 0, 0, 2, ema_h1_slow) < 2)
    {
        IndicatorRelease(ema_m5_fast_handle);
        IndicatorRelease(ema_m5_slow_handle);
        IndicatorRelease(ema_h1_fast_handle);
        IndicatorRelease(ema_h1_slow_handle);
        return false;
    }
    
    int alignments = 0;
    
    if(is_buy)
    {
        if(ema_m5_fast[0] > ema_m5_slow[0]) alignments++;
        if(ema_h1_fast[0] > ema_h1_slow[0]) alignments++;
        if(ema_m5_fast[0] > ema_m5_fast[1]) alignments++; // Momentum M5
        if(ema_h1_fast[0] > ema_h1_fast[1]) alignments++; // Momentum H1
    }
    else // SELL
    {
        if(ema_m5_fast[0] < ema_m5_slow[0]) alignments++;
        if(ema_h1_fast[0] < ema_h1_slow[0]) alignments++;
        if(ema_m5_fast[0] < ema_m5_fast[1]) alignments++; // Momentum M5
        if(ema_h1_fast[0] < ema_h1_fast[1]) alignments++; // Momentum H1
    }
    
    IndicatorRelease(ema_m5_fast_handle);
    IndicatorRelease(ema_m5_slow_handle);
    IndicatorRelease(ema_h1_fast_handle);
    IndicatorRelease(ema_h1_slow_handle);
    
    confidence = alignments * 25.0; // Max 100%
    return alignments >= 3; // Au moins 3/4 alignements
}

//+------------------------------------------------------------------+
//| STRATÉGIE 5: SUPPORT/RESISTANCE DYNAMIQUE                        |
//+------------------------------------------------------------------+
bool CheckDynamicSupportResistance(bool is_buy, double& confidence)
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(_Symbol, _Period, 0, 50, high) < 50 ||
       CopyLow(_Symbol, _Period, 0, 50, low) < 50 ||
       CopyClose(_Symbol, _Period, 0, 50, close) < 50)
       return false;
    
    double current_price = SymbolInfoDouble(_Symbol, is_buy ? SYMBOL_ASK : SYMBOL_BID);
    
    // Calculer pivots et niveaux SR
    double resistance = 0, support = 0;
    int resistance_touches = 0, support_touches = 0;
    
    // Identifier les niveaux de résistance
    for(int i = 5; i < 45; i++)
    {
        double level = high[i];
        int touches = 1;
        
        for(int j = 0; j < 50; j++)
        {
            if(j != i && MathAbs(high[j] - level) < (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10))
            {
                touches++;
                if(high[j] > level) level = high[j];
            }
        }
        
        if(touches >= 3 && level > resistance)
        {
            resistance = level;
            resistance_touches = touches;
        }
    }
    
    // Identifier les niveaux de support
    for(int i = 5; i < 45; i++)
    {
        double level = low[i];
        int touches = 1;
        
        for(int j = 0; j < 50; j++)
        {
            if(j != i && MathAbs(low[j] - level) < (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10))
            {
                touches++;
                if(low[j] < level) level = low[j];
            }
        }
        
        if(touches >= 3 && (support == 0 || level > support))
        {
            support = level;
            support_touches = touches;
        }
    }
    
    if(is_buy && support > 0)
    {
        double distance_to_support = current_price - support;
        double avg_range = (high[0] - low[0] + high[1] - low[1] + high[2] - low[2]) / 3;
        
        if(distance_to_support < avg_range * 0.5) // Proche du support
        {
            confidence = MathMin(100.0, support_touches * 20.0);
            return true;
        }
    }
    else if(!is_buy && resistance > 0)
    {
        double distance_to_resistance = resistance - current_price;
        double avg_range = (high[0] - low[0] + high[1] - low[1] + high[2] - low[2]) / 3;
        
        if(distance_to_resistance < avg_range * 0.5) // Proche de la résistance
        {
            confidence = MathMin(100.0, resistance_touches * 20.0);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| SYSTÈME DE SCORING COMPLET                                       |
//+------------------------------------------------------------------+
SignalScore CalculateComprehensiveSignal(bool is_buy)
{
    SignalScore score = {0, 0};
    
    // Stratégie 1: Patterns de bougies
    string pattern_name = "";
    double pattern_confidence = 0;
    if(DetectCandlePatterns(pattern_name, pattern_confidence))
    {
        score.strategy_names[score.strategies_count] = "Pattern: " + pattern_name;
        score.individual_scores[score.strategies_count] = pattern_confidence;
        score.total_score += pattern_confidence;
        score.strategies_count++;
    }
    
    // Stratégie 2: Multi-indicateurs
    double multi_confidence = 0;
    if(GetMultiIndicatorConfirmation(is_buy, multi_confidence))
    {
        score.strategy_names[score.strategies_count] = "Multi-Indicators";
        score.individual_scores[score.strategies_count] = multi_confidence;
        score.total_score += multi_confidence;
        score.strategies_count++;
    }
    
    // Stratégie 3: Volatilité/Volume
    double vol_confidence = 0;
    if(CheckVolatilityVolumeFilter(is_buy, vol_confidence))
    {
        score.strategy_names[score.strategies_count] = "Volatility/Volume";
        score.individual_scores[score.strategies_count] = vol_confidence;
        score.total_score += vol_confidence;
        score.strategies_count++;
    }
    
    // Stratégie 4: Multi-timeframe
    double mtf_confidence = 0;
    if(CheckMultiTimeframeAlignment(is_buy, mtf_confidence))
    {
        score.strategy_names[score.strategies_count] = "Multi-Timeframe";
        score.individual_scores[score.strategies_count] = mtf_confidence;
        score.total_score += mtf_confidence;
        score.strategies_count++;
    }
    
    // Stratégie 5: Support/Resistance
    double sr_confidence = 0;
    if(CheckDynamicSupportResistance(is_buy, sr_confidence))
    {
        score.strategy_names[score.strategies_count] = "Support/Resistance";
        score.individual_scores[score.strategies_count] = sr_confidence;
        score.total_score += sr_confidence;
        score.strategies_count++;
    }
    
    // Calculer le score moyen
    if(score.strategies_count > 0)
        score.total_score /= score.strategies_count;
    
    return score;
}

//+------------------------------------------------------------------+
//| DÉCISION FINALE BASÉE SUR LE SCORING                            |
//+------------------------------------------------------------------+
bool ShouldExecuteTrade(bool is_buy, double min_confidence = 65.0)
{
    SignalScore score = CalculateComprehensiveSignal(is_buy);
    
    if(is_buy)
        g_buySignal = score;
    else
        g_sellSignal = score;
    
    // Afficher les détails du signal
    if(score.strategies_count > 0)
    {
        string details = "Signal " + (is_buy ? "BUY" : "SELL") + " - Score: " + DoubleToString(score.total_score, 1) + "%\n";
        for(int i = 0; i < score.strategies_count; i++)
        {
            details += "  " + score.strategy_names[i] + ": " + DoubleToString(score.individual_scores[i], 1) + "%\n";
        }
        Print(details);
    }
    
    return score.total_score >= min_confidence && score.strategies_count >= 2;
}

//+------------------------------------------------------------------+
