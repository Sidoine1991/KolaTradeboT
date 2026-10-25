//+------------------------------------------------------------------+
//|                                                SpikeDetector.mq5 |
//|                        Copyright 2025, TradBOT Spike Detector   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TradBOT Spike Detector"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Indicateur de détection de spikes pour Boom/Crash"

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   5

//--- Plot Spike Detection
#property indicator_label1  "Spike Detection"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot Spike Strength
#property indicator_label2  "Spike Strength"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot Reversal Signal
#property indicator_label3  "Reversal Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrYellow
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- Plot Confidence
#property indicator_label4  "Confidence %"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrAqua
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Plot Lead Seconds
#property indicator_label5  "Lead Seconds"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrSilver
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

//--- Paramètres d'entrée
input group "=== CONFIGURATION GÉNÉRALE ==="
input int      InpPeriod = 20;           // Période de détection
input double   InpThreshold = 0.5;       // Seuil de spike (%)
input int      InpSmoothing = 3;         // Lissage
input bool     InpShowArrows = true;     // Afficher les flèches
input color    InpBuyColor = clrLime;    // Couleur achat
input color    InpSellColor = clrRed;    // Couleur vente

input group "=== INDICATEURS RENFORCÉS ==="
input int      InpRSIPeriod = 14;        // Période RSI
input int      InpMACDFast = 12;         // MACD Fast
input int      InpMACDSlow = 26;         // MACD Slow
input int      InpMACDSignal = 9;        // MACD Signal
input int      InpBBPeriod = 20;         // Bollinger Bands période
input double   InpBBDeviation = 2.0;     // Bollinger Bands déviation
input int      InpStochK = 14;           // Stochastic %K
input int      InpStochD = 3;            // Stochastic %D
input int      InpWilliamsR = 14;        // Williams %R période

input group "=== DÉTECTION AVANCÉE ==="
input bool     InpUseMultiTimeframe = true;  // Analyse multi-timeframe
input bool     InpUseVolumeAnalysis = true;  // Analyse du volume
input bool     InpUseMomentumDivergence = true; // Détection divergence momentum
input double   InpVolumeThreshold = 1.5;     // Seuil volume (multiplicateur)
input int      InpDivergenceLookback = 10;   // Période divergence

input group "=== SEUILS ET ANTI-REPAINT ==="
input double   InpMinConfidence = 85.0;      // Confiance minimale (%) pour valider un signal

//--- Buffers d'indicateur
double SpikeBuffer[];
double StrengthBuffer[];
double ReversalBuffer[];
double ConfidenceBuffer[];
double LeadSecondsBuffer[];

//--- Variables globales
int ma_handle;
int atr_handle;
int rsi_handle;
int macd_handle;
int bb_handle;
int stoch_handle;
int williams_handle;
double ma_buffer[];
double atr_buffer[];
double rsi_buffer[];
double macd_main_buffer[];
double macd_signal_buffer[];
double bb_upper_buffer[];
double bb_lower_buffer[];
double stoch_main_buffer[];
double stoch_signal_buffer[];
double williams_buffer[];

//--- Variables pour l'analyse avancée
double volume_ma_buffer[];
double momentum_buffer[];
double divergence_buffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Définition des buffers
    SetIndexBuffer(0, SpikeBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, StrengthBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, ReversalBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, ConfidenceBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, LeadSecondsBuffer, INDICATOR_DATA);
    
    //--- Configuration des propriétés
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpBuyColor);
    PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
    
    PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpSellColor);
    PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
    
    PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(2, PLOT_ARROW, 233);
    PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, 0);
    PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrYellow);
    PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 3);

    // Buffers 3 & 4 (confidence and lead) use default line settings
    
    //--- Initialisation des handles d'indicateurs renforcés
    ma_handle = iMA(_Symbol, _Period, InpPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(ma_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur MA");
        return INIT_FAILED;
    }
    
    atr_handle = iATR(_Symbol, _Period, 14);
    if(atr_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur ATR");
        return INIT_FAILED;
    }
    
    //--- RSI
    rsi_handle = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur RSI");
        return INIT_FAILED;
    }
    
    //--- MACD
    macd_handle = iMACD(_Symbol, _Period, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur MACD");
        return INIT_FAILED;
    }
    
    //--- Bollinger Bands
    bb_handle = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur Bollinger Bands");
        return INIT_FAILED;
    }
    
    //--- Stochastic
    stoch_handle = iStochastic(_Symbol, _Period, InpStochK, InpStochD, InpStochD, MODE_SMA, STO_LOWHIGH);
    if(stoch_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur Stochastic");
        return INIT_FAILED;
    }
    
    //--- Williams %R
    williams_handle = iWPR(_Symbol, _Period, InpWilliamsR);
    if(williams_handle == INVALID_HANDLE) {
        Print("ERREUR: Impossible de créer l'indicateur Williams %R");
        return INIT_FAILED;
    }
    
    //--- Initialisation des buffers
    ArraySetAsSeries(ma_buffer, true);
    ArraySetAsSeries(atr_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);
    ArraySetAsSeries(macd_main_buffer, true);
    ArraySetAsSeries(macd_signal_buffer, true);
    ArraySetAsSeries(bb_upper_buffer, true);
    ArraySetAsSeries(bb_lower_buffer, true);
    ArraySetAsSeries(stoch_main_buffer, true);
    ArraySetAsSeries(stoch_signal_buffer, true);
    ArraySetAsSeries(williams_buffer, true);
    ArraySetAsSeries(volume_ma_buffer, true);
    ArraySetAsSeries(momentum_buffer, true);
    ArraySetAsSeries(divergence_buffer, true);
    
    //--- Noms des indicateurs
    IndicatorSetString(INDICATOR_SHORTNAME, "SpikeDetector(" + IntegerToString(InpPeriod) + ")");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Libération des handles
    if(ma_handle != INVALID_HANDLE)
        IndicatorRelease(ma_handle);
    if(atr_handle != INVALID_HANDLE)
        IndicatorRelease(atr_handle);
    if(rsi_handle != INVALID_HANDLE)
        IndicatorRelease(rsi_handle);
    if(macd_handle != INVALID_HANDLE)
        IndicatorRelease(macd_handle);
    if(bb_handle != INVALID_HANDLE)
        IndicatorRelease(bb_handle);
    if(stoch_handle != INVALID_HANDLE)
        IndicatorRelease(stoch_handle);
    if(williams_handle != INVALID_HANDLE)
        IndicatorRelease(williams_handle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    //--- Vérification des données
    if(rates_total < InpPeriod) return 0;
    
    //--- Calcul du nombre de barres à traiter
    int start = prev_calculated;
    if(start == 0) {
        start = InpPeriod;
        ArrayInitialize(SpikeBuffer, 0.0);
        ArrayInitialize(StrengthBuffer, 0.0);
        ArrayInitialize(ReversalBuffer, 0.0);
    }
    
    //--- Mise à jour des indicateurs renforcés
    if(CopyBuffer(ma_handle, 0, 0, rates_total, ma_buffer) < 0) return 0;
    if(CopyBuffer(atr_handle, 0, 0, rates_total, atr_buffer) < 0) return 0;
    if(CopyBuffer(rsi_handle, 0, 0, rates_total, rsi_buffer) < 0) return 0;
    if(CopyBuffer(macd_handle, 0, 0, rates_total, macd_main_buffer) < 0) return 0;
    if(CopyBuffer(macd_handle, 1, 0, rates_total, macd_signal_buffer) < 0) return 0;
    if(CopyBuffer(bb_handle, 1, 0, rates_total, bb_upper_buffer) < 0) return 0;
    if(CopyBuffer(bb_handle, 2, 0, rates_total, bb_lower_buffer) < 0) return 0;
    if(CopyBuffer(stoch_handle, 0, 0, rates_total, stoch_main_buffer) < 0) return 0;
    if(CopyBuffer(stoch_handle, 1, 0, rates_total, stoch_signal_buffer) < 0) return 0;
    if(CopyBuffer(williams_handle, 0, 0, rates_total, williams_buffer) < 0) return 0;
    
    //--- Calcul des spikes
    for(int i = start; i < rates_total; i++) {
        CalculateSpike(i, close, high, low, tick_volume, rates_total);
    }

    //--- Remplir buffers auxiliaires (confidence/lead) avec 0 si non initialisés
    if(prev_calculated == 0) {
        for(int i = 0; i < rates_total; i++) {
            if(i >= ArraySize(ConfidenceBuffer)) break;
            ConfidenceBuffer[i] = 0.0;
            LeadSecondsBuffer[i] = 0.0;
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Calcul du spike pour une barre donnée (VERSION RENFORCÉE)      |
//+------------------------------------------------------------------+
void CalculateSpike(int bar, const double &close[], const double &high[], const double &low[], const long &tick_volume[], int total)
{
    if(bar < InpPeriod) return;
    
    double current_price = close[bar];
    double ma_value = ma_buffer[bar];
    double atr_value = atr_buffer[bar];
    
    //--- Calcul du changement de prix par rapport à la MA
    double price_change = 0;
    if(ma_value > 0) {
        price_change = (current_price - ma_value) / ma_value * 100;
    }
    
    //--- ANALYSE MULTI-INDICATEURS RENFORCÉE
    double spike_score = 0;
    bool is_spike = false;
    bool is_strong_spike = false;
    
    //--- 1. Analyse RSI (survente/surachat)
    double rsi_value = rsi_buffer[bar];
    if(rsi_value < 30) {
        spike_score += 20; // Survente = potentiel spike haussier
    } else if(rsi_value > 70) {
        spike_score += 20; // Surachat = potentiel spike baissier
    }
    
    //--- 2. Analyse MACD (croisement et divergence)
    double macd_main = macd_main_buffer[bar];
    double macd_signal = macd_signal_buffer[bar];
    if(bar > 0) {
        double prev_macd_main = macd_main_buffer[bar - 1];
        double prev_macd_signal = macd_signal_buffer[bar - 1];
        
        // Croisement MACD
        if((macd_main > macd_signal && prev_macd_main <= prev_macd_signal) ||
           (macd_main < macd_signal && prev_macd_main >= prev_macd_signal)) {
            spike_score += 25;
        }
        
        // Divergence MACD
        if(InpUseMomentumDivergence && DetectMACDDivergence(bar, close)) {
            spike_score += 30;
        }
    }
    
    //--- 3. Analyse Bollinger Bands (touches des bandes)
    double bb_upper = bb_upper_buffer[bar];
    double bb_lower = bb_lower_buffer[bar];
    if(current_price >= bb_upper * 0.999) { // Proche de la bande supérieure
        spike_score += 15;
    } else if(current_price <= bb_lower * 1.001) { // Proche de la bande inférieure
        spike_score += 15;
    }
    
    //--- 4. Analyse Stochastic (extrêmes)
    double stoch_main = stoch_main_buffer[bar];
    double stoch_signal = stoch_signal_buffer[bar];
    if(stoch_main < 20 && stoch_signal < 20) {
        spike_score += 15; // Survente
    } else if(stoch_main > 80 && stoch_signal > 80) {
        spike_score += 15; // Surachat
    }
    
    //--- 5. Analyse Williams %R
    double williams_value = williams_buffer[bar];
    if(williams_value < -80) {
        spike_score += 10; // Survente
    } else if(williams_value > -20) {
        spike_score += 10; // Surachat
    }
    
    //--- 6. Analyse du volume (si activée)
    if(InpUseVolumeAnalysis && bar > 0) {
        double volume_ratio = CalculateVolumeRatio(bar, tick_volume, total);
        if(volume_ratio > InpVolumeThreshold) {
            spike_score += 20; // Volume élevé
        }
    }
    
    //--- 7. Analyse de la volatilité ATR
    double volatility_ratio = CalculateVolatilityRatio(bar, atr_value);
    if(volatility_ratio > 1.5) {
        spike_score += 15; // Volatilité élevée
    }
    
    //--- 8. Analyse multi-timeframe (si activée)
    if(InpUseMultiTimeframe) {
        double mtf_score = CalculateMultiTimeframeScore(bar);
        spike_score += mtf_score;
    }
    
    //--- DÉTERMINATION DU SPIKE
    if(MathAbs(price_change) >= InpThreshold) {
        is_spike = true;
        if(spike_score >= 50) {
            is_strong_spike = true;
        }
    }
    
    //--- Calcul de la force du spike renforcée
    double spike_strength = MathAbs(price_change);
    if(spike_score > 0) {
        spike_strength = spike_strength * (1 + spike_score / 100);
    }
    
    //--- DÉTECTION D'INVERSION AVANCÉE
    bool reversal_signal = false;
    if(is_spike && bar >= 2) {
        // Vérifier la convergence des indicateurs
        bool rsi_reversal = (rsi_value < 30 && rsi_buffer[bar - 1] >= 30) || 
                           (rsi_value > 70 && rsi_buffer[bar - 1] <= 70);
        
        bool macd_reversal = (macd_main > macd_signal && macd_main_buffer[bar - 1] <= macd_signal_buffer[bar - 1]) ||
                            (macd_main < macd_signal && macd_main_buffer[bar - 1] >= macd_signal_buffer[bar - 1]);
        
        bool stoch_reversal = (stoch_main < 20 && stoch_main_buffer[bar - 1] >= 20) ||
                             (stoch_main > 80 && stoch_main_buffer[bar - 1] <= 80);
        
        // Inversion si au moins 2 indicateurs convergent
        int reversal_count = 0;
        if(rsi_reversal) reversal_count++;
        if(macd_reversal) reversal_count++;
        if(stoch_reversal) reversal_count++;
        
        if(reversal_count >= 2) {
            reversal_signal = true;
        }
    }
    
    //--- Confidence et lead seconds (prédictif simple)
    double confidence = MathMin(95.0, spike_score); // échelle 0-100
    int lead_seconds = 0;
    if(is_spike) {
        // Heuristique de lead: plus le score est élevé et la volatilité est forte, plus le lead est grand
        lead_seconds = (int)MathRound( MathMin(60.0, 10 + (spike_score/2.0) + (volatility_ratio*5.0)) );
    }

    //--- Filtrage par confiance minimale
    bool pass_conf = (confidence >= InpMinConfidence);

    //--- Mise à jour des buffers
    SpikeBuffer[bar] = (is_spike && pass_conf) ? price_change : 0;
    StrengthBuffer[bar] = spike_strength;
    ReversalBuffer[bar] = (reversal_signal && pass_conf) ? (price_change > 0 ? 1 : -1) : 0;
    ConfidenceBuffer[bar] = pass_conf ? confidence : 0;
    LeadSecondsBuffer[bar] = pass_conf ? lead_seconds : 0;
    
    //--- Affichage des flèches amélioré
    if(InpShowArrows && reversal_signal) {
        if(price_change > 0) {
            ReversalBuffer[bar] = high[bar] + atr_value * 2;
        } else {
            ReversalBuffer[bar] = low[bar] - atr_value * 2;
        }
    }
    
    //--- Log des spikes forts
    if(is_strong_spike) {
        string direction = (price_change > 0) ? "BOOM" : "CRASH";
        Print("🚀 SPIKE FORT DÉTECTÉ: ", direction, " - Score: ", DoubleToString(spike_score, 1), 
              " - Force: ", DoubleToString(spike_strength, 2), "%");
    }
}

//+------------------------------------------------------------------+
//| Fonction de calcul de la moyenne mobile exponentielle           |
//+------------------------------------------------------------------+
double CalculateEMA(const double &data[], int period, int bar)
{
    if(bar < period) return data[bar];
    
    double alpha = 2.0 / (period + 1);
    double ema = data[bar];
    
    for(int i = bar - 1; i >= bar - period && i >= 0; i--) {
        ema = alpha * data[i] + (1 - alpha) * ema;
    }
    
    return ema;
}

//+------------------------------------------------------------------+
//| Fonction de calcul de la volatilité                             |
//+------------------------------------------------------------------+
double CalculateVolatility(const double &close[], int period, int bar)
{
    if(bar < period) return 0;
    
    double sum = 0;
    for(int i = 0; i < period; i++) {
        if(bar - i - 1 >= 0) {
            double change = MathAbs(close[bar - i] - close[bar - i - 1]) / close[bar - i - 1];
            sum += change;
        }
    }
    
    return sum / period * 100;
}

//+------------------------------------------------------------------+
//| Fonction de détection de pattern de spike                       |
//+------------------------------------------------------------------+
bool DetectSpikePattern(const double &close[], int bar, int lookback)
{
    if(bar < lookback) return false;
    
    double current_price = close[bar];
    double min_price = current_price;
    double max_price = current_price;
    
    //--- Recherche du min et max dans la période
    for(int i = 1; i <= lookback; i++) {
        if(bar - i >= 0) {
            min_price = MathMin(min_price, close[bar - i]);
            max_price = MathMax(max_price, close[bar - i]);
        }
    }
    
    //--- Calcul de l'amplitude
    double amplitude = (max_price - min_price) / min_price * 100;
    
    return amplitude >= InpThreshold;
}

//+------------------------------------------------------------------+
//| Fonction de calcul du momentum                                  |
//+------------------------------------------------------------------+
double CalculateMomentum(const double &close[], int period, int bar)
{
    if(bar < period) return 0;
    
    double current_price = close[bar];
    double past_price = close[bar - period];
    
    if(past_price > 0) {
        return (current_price - past_price) / past_price * 100;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Fonction de normalisation des valeurs                           |
//+------------------------------------------------------------------+
double NormalizeValue(double value, double min_val, double max_val)
{
    if(max_val == min_val) return 0;
    
    return (value - min_val) / (max_val - min_val);
}

//+------------------------------------------------------------------+
//| Fonction de lissage des données                                 |
//+------------------------------------------------------------------+
double SmoothValue(double value, double prev_value, int smoothing)
{
    if(smoothing <= 1) return value;
    
    return (value + (smoothing - 1) * prev_value) / smoothing;
}

//+------------------------------------------------------------------+
//| Détection de divergence MACD                                      |
//+------------------------------------------------------------------+
bool DetectMACDDivergence(int bar, const double &close[])
{
    if(bar < InpDivergenceLookback) return false;
    
    //--- Rechercher les points hauts et bas récents
    double current_price = close[bar];
    double current_macd = macd_main_buffer[bar];
    
    double max_price = current_price;
    double max_macd = current_macd;
    double min_price = current_price;
    double min_macd = current_macd;
    
    //--- Analyser les barres précédentes
    for(int i = 1; i <= InpDivergenceLookback; i++) {
        if(bar - i >= 0) {
            double price = close[bar - i];
            double macd = macd_main_buffer[bar - i];
            
            if(price > max_price) {
                max_price = price;
                max_macd = macd;
            }
            if(price < min_price) {
                min_price = price;
                min_macd = macd;
            }
        }
    }
    
    //--- Détecter divergence haussière (prix bas mais MACD plus haut)
    if(current_price <= min_price * 1.001 && current_macd > min_macd * 1.1) {
        return true;
    }
    
    //--- Détecter divergence baissière (prix haut mais MACD plus bas)
    if(current_price >= max_price * 0.999 && current_macd < max_macd * 0.9) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calcul du ratio de volume                                        |
//+------------------------------------------------------------------+
double CalculateVolumeRatio(int bar, const long &tick_volume[], int total)
{
    if(bar < InpPeriod) return 1.0;
    
    //--- Calculer la moyenne du volume sur la période
    double volume_sum = 0;
    for(int i = 0; i < InpPeriod; i++) {
        if(bar - i >= 0) {
            volume_sum += tick_volume[bar - i];
        }
    }
    double avg_volume = volume_sum / InpPeriod;
    
    //--- Calculer le ratio volume actuel / moyenne
    if(avg_volume > 0) {
        return tick_volume[bar] / avg_volume;
    }
    
    return 1.0;
}

//+------------------------------------------------------------------+
//| Calcul du ratio de volatilité                                    |
//+------------------------------------------------------------------+
double CalculateVolatilityRatio(int bar, double current_atr)
{
    if(bar < InpPeriod) return 1.0;
    
    //--- Calculer la moyenne ATR sur la période
    double atr_sum = 0;
    for(int i = 0; i < InpPeriod; i++) {
        if(bar - i >= 0) {
            atr_sum += atr_buffer[bar - i];
        }
    }
    double avg_atr = atr_sum / InpPeriod;
    
    //--- Calculer le ratio ATR actuel / moyenne
    if(avg_atr > 0) {
        return current_atr / avg_atr;
    }
    
    return 1.0;
}

//+------------------------------------------------------------------+
//| Calcul du score multi-timeframe                                  |
//+------------------------------------------------------------------+
double CalculateMultiTimeframeScore(int bar)
{
    double mtf_score = 0;
    
    //--- Analyser les timeframes supérieurs
    ENUM_TIMEFRAMES higher_tf = GetHigherTimeframe(_Period);
    if(higher_tf != PERIOD_CURRENT) {
        //--- Simuler l'analyse du timeframe supérieur
        // En réalité, vous devriez utiliser iMA, iRSI, etc. avec le timeframe supérieur
        mtf_score += 10; // Score de base pour multi-timeframe
    }
    
    return mtf_score;
}

//+------------------------------------------------------------------+
//| Obtenir le timeframe supérieur                                   |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES current_tf)
{
    switch(current_tf) {
        case PERIOD_M1:  return PERIOD_M5;
        case PERIOD_M5:  return PERIOD_M15;
        case PERIOD_M15: return PERIOD_M30;
        case PERIOD_M30: return PERIOD_H1;
        case PERIOD_H1:  return PERIOD_H4;
        case PERIOD_H4:  return PERIOD_D1;
        default:         return PERIOD_CURRENT;
    }
}

//+------------------------------------------------------------------+
//| Calcul de la force relative des spikes                          |
//+------------------------------------------------------------------+
double CalculateRelativeStrength(int bar, const double &close[])
{
    if(bar < InpPeriod) return 0;
    
    double current_price = close[bar];
    double max_price = current_price;
    double min_price = current_price;
    
    //--- Trouver le max et min sur la période
    for(int i = 0; i < InpPeriod; i++) {
        if(bar - i >= 0) {
            double price = close[bar - i];
            max_price = MathMax(max_price, price);
            min_price = MathMin(min_price, price);
        }
    }
    
    //--- Calculer la position relative
    if(max_price > min_price) {
        return (current_price - min_price) / (max_price - min_price) * 100;
    }
    
    return 50; // Position neutre
}

//+------------------------------------------------------------------+
//| Détection de pattern de consolidation                            |
//+------------------------------------------------------------------+
bool DetectConsolidationPattern(int bar, const double &close[])
{
    if(bar < InpPeriod) return false;
    
    double current_price = close[bar];
    double max_price = current_price;
    double min_price = current_price;
    
    //--- Calculer l'amplitude sur la période
    for(int i = 0; i < InpPeriod; i++) {
        if(bar - i >= 0) {
            double price = close[bar - i];
            max_price = MathMax(max_price, price);
            min_price = MathMin(min_price, price);
        }
    }
    
    //--- Consolidation si amplitude < 1%
    double amplitude = (max_price - min_price) / min_price * 100;
    return amplitude < 1.0;
}

//+------------------------------------------------------------------+
//| Calcul de l'accélération du momentum                             |
//+------------------------------------------------------------------+
double CalculateMomentumAcceleration(int bar, const double &close[])
{
    if(bar < 3) return 0;
    
    double momentum1 = CalculateMomentum(close, 1, bar);
    double momentum2 = CalculateMomentum(close, 1, bar - 1);
    double momentum3 = CalculateMomentum(close, 1, bar - 2);
    
    //--- Calculer l'accélération
    double acceleration = momentum1 - 2 * momentum2 + momentum3;
    
    return acceleration;
}

//+------------------------------------------------------------------+
//| Détection de rupture de niveau                                   |
//+------------------------------------------------------------------+
bool DetectLevelBreakout(int bar, const double &close[], const double &high[], const double &low[])
{
    if(bar < InpPeriod) return false;
    
    double current_price = close[bar];
    double current_high = high[bar];
    double current_low = low[bar];
    
    //--- Trouver les niveaux de support/résistance récents
    double resistance_level = 0;
    double support_level = 0;
    
    for(int i = 1; i <= InpPeriod; i++) {
        if(bar - i >= 0) {
            double prev_high = high[bar - i];
            double prev_low = low[bar - i];
            
            if(prev_high > resistance_level) {
                resistance_level = prev_high;
            }
            if(prev_low < support_level || support_level == 0) {
                support_level = prev_low;
            }
        }
    }
    
    //--- Détecter rupture de résistance
    if(current_high > resistance_level * 1.001) {
        return true;
    }
    
    //--- Détecter rupture de support
    if(current_low < support_level * 0.999) {
        return true;
    }
    
    return false;
}
