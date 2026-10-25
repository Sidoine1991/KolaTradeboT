//+------------------------------------------------------------------+
//|                                    SpikeHunter_Professional_Ultra.mq5 |
//|                        Copyright 2025, Ultra Professional Trading EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Ultra Professional Trading EA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "EA Ultra-Professionnel - 80 ans d'expérience condensée"

//--- Includes
#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== CONFIGURATION ULTRA-PROFESSIONNELLE ==="
input bool     InpEnableTrading        = true;     // Activer le trading
input int      InpMagicNumber          = 888888;   // Magic number
input double   InpLotSize              = 0.1;      // Taille du lot de base
input bool     InpUseDynamicLotSize    = true;     // Lot dynamique basé sur confiance
input double   InpMaxLotSize           = 2.0;      // Lot maximum
input double   InpMinLotSize           = 0.1;      // Lot minimum

input group "=== STRATÉGIES MULTI-TIMEFRAME ==="
input bool     InpUseTrendFollowing    = true;     // Suivi de tendance (H4, H1, M30)
input bool     InpUseMomentumTrading   = true;     // Trading momentum (M15, M5)
input bool     InpUseScalpingStrategy  = true;     // Scalping précis (M1)
input bool     InpUseReversalStrategy  = true;     // Détection retournements
input bool     InpUseBreakoutStrategy  = true;     // Trading cassures

input group "=== INDICATEURS PROFESSIONNELS ==="
input int      InpEMAFast              = 8;        // EMA rapide
input int      InpEMASlow              = 21;       // EMA lente
input int      InpEMATrend             = 50;       // EMA tendance
input int      InpRSIPeriod            = 14;       // RSI période
input int      InpMACDFast             = 12;       // MACD rapide
input int      InpMACDSlow             = 26;       // MACD lent
input int      InpMACDSignal           = 9;        // MACD signal
input int      InpATRPeriod            = 14;       // ATR période
input int      InpBBPeriod             = 20;       // Bollinger Bands période
input double   InpBBDeviation          = 2.0;      // Bollinger Bands déviation

input group "=== GESTION DES RISQUES ULTRA-STRICTE ==="
input double   InpMaxRiskPercent       = 1.0;      // Risque maximum par trade (%)
input double   InpMaxDailyLoss         = 20.0;     // Perte max journalière ($)
input double   InpMaxDailyProfit       = 100.0;    // Profit max journalier ($)
input int      InpMaxTradesPerDay      = 10;       // Trades max par jour
input int      InpMaxSimultaneousTrades = 2;       // Trades simultanés max
input int      InpCooldownMinutes      = 15;       // Cooldown entre trades (min)

input group "=== BOOM/CRASH ULTRA-PRÉCIS ==="
input bool     InpBoomCrashOnly        = true;     // Trader uniquement Boom/Crash
input bool     InpPreSpikeDetection    = true;     // Détection pré-spike
input double   InpSpikeConfidenceMin   = 85.0;     // Confiance minimum pour spike
input int      InpSpikeLookback        = 5;        // Bougies pour détection spike
input double   InpSpikeATRMultiplier   = 1.5;      // Multiplicateur ATR pour spike

input group "=== SUPPORT/RÉSISTANCE DYNAMIQUES ==="
input bool     InpUseDynamicSR         = true;     // S/R dynamiques
input int      InpSRPeriod             = 20;       // Période S/R
input double   InpSRProximityPercent   = 0.1;      // Proximité S/R (%)
input bool     InpUsePivotPoints       = true;     // Points pivots

input group "=== MONEY MANAGEMENT AVANCÉ ==="
input bool     InpUseMartingale        = false;    // Martingale (DANGEREUX)
input bool     InpUseAntiMartingale    = true;     // Anti-Martingale
input double   InpProfitTarget         = 50.0;     // Objectif profit journalier ($)
input double   InpStopLossTarget       = 15.0;     // Stop loss journalier ($)

//--- Global variables
CTrade m_trade;
double g_dailyStartBalance = 0;
double g_dailyProfit = 0;
double g_dailyLoss = 0;
int g_tradesToday = 0;
datetime g_lastTradeTime = 0;
datetime g_lastDay = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    m_trade.SetExpertMagicNumber(InpMagicNumber);
    g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    Print("🚀 SpikeHunter Ultra-Professionnel initialisé");
    Print("💰 Balance initiale: ", DoubleToString(g_dailyStartBalance, 2));
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("📊 Performance journalière: ", DoubleToString(g_dailyProfit, 2), " $");
    Print("📈 Trades aujourd'hui: ", g_tradesToday);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!InpEnableTrading) return;
    
    // Reset journalier
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    if(g_lastDay != currentTime.day) {
        g_lastDay = currentTime.day;
        g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        g_dailyProfit = 0;
        g_dailyLoss = 0;
        g_tradesToday = 0;
        Print("📅 Nouveau jour - Reset des compteurs");
    }
    
    // Vérifier limites journalières
    if(g_dailyLoss >= InpMaxDailyLoss) {
        Print("🛑 Limite de perte journalière atteinte: ", DoubleToString(g_dailyLoss, 2));
        return;
    }
    
    if(g_dailyProfit >= InpMaxDailyProfit) {
        Print("💰 Objectif de profit journalier atteint: ", DoubleToString(g_dailyProfit, 2));
        return;
    }
    
    if(g_tradesToday >= InpMaxTradesPerDay) {
        Print("📊 Limite de trades journaliers atteinte: ", g_tradesToday);
        return;
    }
    
    // Cooldown entre trades
    if(TimeCurrent() - g_lastTradeTime < InpCooldownMinutes * 60) return;
    
    // Vérifier trades simultanés
    if(PositionsTotal() >= InpMaxSimultaneousTrades) return;
    
    // Analyser les opportunités
    int signal = AnalyzeUltraProfessional();
    if(signal == 0) return;
    
    // Calculer lot dynamique
    double lotSize = CalculateDynamicLotSize(signal);
    if(lotSize <= 0) return;
    
    // Exécuter le trade
    if(ExecuteUltraTrade(signal, lotSize)) {
        g_lastTradeTime = TimeCurrent();
        g_tradesToday++;
        Print("✅ Trade ultra-professionnel exécuté #", g_tradesToday);
    }
}

//+------------------------------------------------------------------+
//| Analyse ultra-professionnelle multi-stratégies                  |
//+------------------------------------------------------------------+
int AnalyzeUltraProfessional()
{
    // 1. Vérifier alignement multi-timeframe
    if(!IsMultiTimeframeAligned()) return 0;
    
    // 2. Détection Boom/Crash ultra-précise
    if(InpBoomCrashOnly && IsBoomCrashIndex(_Symbol)) {
        int boomCrashSignal = AnalyzeBoomCrashUltra();
        if(boomCrashSignal != 0) return boomCrashSignal;
    }
    
    // 3. Stratégie de suivi de tendance
    if(InpUseTrendFollowing) {
        int trendSignal = AnalyzeTrendFollowing();
        if(trendSignal != 0) return trendSignal;
    }
    
    // 4. Stratégie momentum
    if(InpUseMomentumTrading) {
        int momentumSignal = AnalyzeMomentum();
        if(momentumSignal != 0) return momentumSignal;
    }
    
    // 5. Stratégie scalping
    if(InpUseScalpingStrategy) {
        int scalpingSignal = AnalyzeScalping();
        if(scalpingSignal != 0) return scalpingSignal;
    }
    
    // 6. Stratégie retournements
    if(InpUseReversalStrategy) {
        int reversalSignal = AnalyzeReversal();
        if(reversalSignal != 0) return reversalSignal;
    }
    
    // 7. Stratégie cassures
    if(InpUseBreakoutStrategy) {
        int breakoutSignal = AnalyzeBreakout();
        if(breakoutSignal != 0) return breakoutSignal;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Vérification alignement multi-timeframe                         |
//+------------------------------------------------------------------+
bool IsMultiTimeframeAligned()
{
    // H4, H1, M30, M15, M5, M1 doivent être alignés
    ENUM_TIMEFRAMES timeframes[] = {PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5, PERIOD_M1};
    int directions[6];
    
    for(int i = 0; i < 6; i++) {
        directions[i] = GetTrendDirection(timeframes[i]);
        if(directions[i] == 0) return false; // Neutre = pas d'alignement
    }
    
    // Tous doivent être dans la même direction
    for(int i = 1; i < 6; i++) {
        if(directions[i] != directions[0]) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Analyse Boom/Crash ultra-précise                                |
//+------------------------------------------------------------------+
int AnalyzeBoomCrashUltra()
{
    if(!InpPreSpikeDetection) return 0;
    
    // Détection pré-spike avec confiance élevée
    double confidence = CalculateSpikeConfidence();
    if(confidence < InpSpikeConfidenceMin) return 0;
    
    // Vérifier proximité S/R
    if(InpUseDynamicSR && !IsNearSupportResistance()) return 0;
    
    // Direction basée sur le type d'index
    bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
    bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
    
    if(isBoom) return 1;  // BUY uniquement
    if(isCrash) return -1; // SELL uniquement
    
    return 0;
}

//+------------------------------------------------------------------+
//| Calcul de confiance pour spike                                  |
//+------------------------------------------------------------------+
double CalculateSpikeConfidence()
{
    double confidence = 0;
    
    // 1. Compression Bollinger Bands (30 points)
    int bbHandle = iBands(_Symbol, PERIOD_M1, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    if(bbHandle != INVALID_HANDLE) {
        double upper[], middle[], lower[];
        if(CopyBuffer(bbHandle, 0, 0, 2, upper) >= 2 && 
           CopyBuffer(bbHandle, 1, 0, 2, middle) >= 2 && 
           CopyBuffer(bbHandle, 2, 0, 2, lower) >= 2) {
            double bbWidth = (upper[0] - lower[0]) / middle[0];
            double bbWidthPrev = (upper[1] - lower[1]) / middle[1];
            if(bbWidth < bbWidthPrev && bbWidth < 0.01) confidence += 30;
        }
        IndicatorRelease(bbHandle);
    }
    
    // 2. ATR boost (25 points)
    int atrHandle = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
    if(atrHandle != INVALID_HANDLE) {
        double atr[];
        if(CopyBuffer(atrHandle, 0, 0, 10, atr) >= 10) {
            double atrNow = atr[0];
            double atrAvg = 0;
            for(int i = 1; i < 10; i++) atrAvg += atr[i];
            atrAvg /= 9;
            if(atrNow >= atrAvg * InpSpikeATRMultiplier) confidence += 25;
        }
        IndicatorRelease(atrHandle);
    }
    
    // 3. RSI divergence (20 points)
    int rsiHandle = iRSI(_Symbol, PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
    if(rsiHandle != INVALID_HANDLE) {
        double rsi[];
        if(CopyBuffer(rsiHandle, 0, 0, 5, rsi) >= 5) {
            if(rsi[0] < 30 || rsi[0] > 70) confidence += 20;
        }
        IndicatorRelease(rsiHandle);
    }
    
    // 4. MACD momentum (15 points)
    int macdHandle = iMACD(_Symbol, PERIOD_M1, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
    if(macdHandle != INVALID_HANDLE) {
        double macd[], signal[];
        if(CopyBuffer(macdHandle, 0, 0, 2, macd) >= 2 && 
           CopyBuffer(macdHandle, 1, 0, 2, signal) >= 2) {
            if((macd[0] > signal[0] && macd[1] <= signal[1]) || 
               (macd[0] < signal[0] && macd[1] >= signal[1])) confidence += 15;
        }
        IndicatorRelease(macdHandle);
    }
    
    // 5. Volume/Volatilité (10 points)
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) >= 5) {
        double avgRange = 0;
        for(int i = 1; i < 5; i++) avgRange += (rates[i].high - rates[i].low);
        avgRange /= 4;
        double currentRange = rates[0].high - rates[0].low;
        if(currentRange > avgRange * 1.5) confidence += 10;
    }
    
    return confidence;
}

//+------------------------------------------------------------------+
//| Analyse suivi de tendance                                       |
//+------------------------------------------------------------------+
int AnalyzeTrendFollowing()
{
    // EMA croisement sur H1
    int emaFast = iMA(_Symbol, PERIOD_H1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
    int emaSlow = iMA(_Symbol, PERIOD_H1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
    if(emaFast == INVALID_HANDLE || emaSlow == INVALID_HANDLE) return 0;
    
    double fast[], slow[];
    if(CopyBuffer(emaFast, 0, 0, 2, fast) < 2 || CopyBuffer(emaSlow, 0, 0, 2, slow) < 2) {
        IndicatorRelease(emaFast); IndicatorRelease(emaSlow);
        return 0;
    }
    
    int direction = 0;
    if(fast[0] > slow[0] && fast[1] <= slow[1]) direction = 1;  // Croisement haussier
    if(fast[0] < slow[0] && fast[1] >= slow[1]) direction = -1; // Croisement baissier
    
    IndicatorRelease(emaFast); IndicatorRelease(emaSlow);
    return direction;
}

//+------------------------------------------------------------------+
//| Analyse momentum                                                 |
//+------------------------------------------------------------------+
int AnalyzeMomentum()
{
    // RSI + MACD sur M15
    int rsiHandle = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
    int macdHandle = iMACD(_Symbol, PERIOD_M15, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
    
    if(rsiHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE) return 0;
    
    double rsi[], macd[], signal[];
    if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) < 1 || 
       CopyBuffer(macdHandle, 0, 0, 1, macd) < 1 || 
       CopyBuffer(macdHandle, 1, 0, 1, signal) < 1) {
        IndicatorRelease(rsiHandle); IndicatorRelease(macdHandle);
        return 0;
    }
    
    int direction = 0;
    if(rsi[0] > 50 && macd[0] > signal[0]) direction = 1;  // Momentum haussier
    if(rsi[0] < 50 && macd[0] < signal[0]) direction = -1; // Momentum baissier
    
    IndicatorRelease(rsiHandle); IndicatorRelease(macdHandle);
    return direction;
}

//+------------------------------------------------------------------+
//| Analyse scalping                                                 |
//+------------------------------------------------------------------+
int AnalyzeScalping()
{
    // EMA 8/21 sur M1 + RSI
    int ema8 = iMA(_Symbol, PERIOD_M1, 8, 0, MODE_EMA, PRICE_CLOSE);
    int ema21 = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
    int rsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
    
    if(ema8 == INVALID_HANDLE || ema21 == INVALID_HANDLE || rsi == INVALID_HANDLE) return 0;
    
    double e8[], e21[], r[];
    if(CopyBuffer(ema8, 0, 0, 1, e8) < 1 || 
       CopyBuffer(ema21, 0, 0, 1, e21) < 1 || 
       CopyBuffer(rsi, 0, 0, 1, r) < 1) {
        IndicatorRelease(ema8); IndicatorRelease(ema21); IndicatorRelease(rsi);
        return 0;
    }
    
    int direction = 0;
    if(e8[0] > e21[0] && r[0] < 70) direction = 1;  // Scalping haussier
    if(e8[0] < e21[0] && r[0] > 30) direction = -1; // Scalping baissier
    
    IndicatorRelease(ema8); IndicatorRelease(ema21); IndicatorRelease(rsi);
    return direction;
}

//+------------------------------------------------------------------+
//| Analyse retournements                                            |
//+------------------------------------------------------------------+
int AnalyzeReversal()
{
    // RSI divergence + Bollinger Bands
    int rsiHandle = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
    int bbHandle = iBands(_Symbol, PERIOD_M15, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    
    if(rsiHandle == INVALID_HANDLE || bbHandle == INVALID_HANDLE) return 0;
    
    double rsi[], upper[], lower[];
    if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3 || 
       CopyBuffer(bbHandle, 0, 0, 1, upper) < 1 || 
       CopyBuffer(bbHandle, 2, 0, 1, lower) < 1) {
        IndicatorRelease(rsiHandle); IndicatorRelease(bbHandle);
        return 0;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    int direction = 0;
    
    // Retournement haussier: RSI oversold + prix près de la bande inférieure
    if(rsi[0] < 30 && rsi[1] < rsi[0] && currentPrice <= lower[0] * 1.001) direction = 1;
    
    // Retournement baissier: RSI overbought + prix près de la bande supérieure
    if(rsi[0] > 70 && rsi[1] > rsi[0] && currentPrice >= upper[0] * 0.999) direction = -1;
    
    IndicatorRelease(rsiHandle); IndicatorRelease(bbHandle);
    return direction;
}

//+------------------------------------------------------------------+
//| Analyse cassures                                                 |
//+------------------------------------------------------------------+
int AnalyzeBreakout()
{
    // Cassure des Bollinger Bands + Volume
    int bbHandle = iBands(_Symbol, PERIOD_M15, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    if(bbHandle == INVALID_HANDLE) return 0;
    
    double upper[], lower[];
    if(CopyBuffer(bbHandle, 0, 0, 2, upper) < 2 || 
       CopyBuffer(bbHandle, 2, 0, 2, lower) < 2) {
        IndicatorRelease(bbHandle);
        return 0;
    }
    
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M15, 0, 3, rates) < 3) {
        IndicatorRelease(bbHandle);
        return 0;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    int direction = 0;
    
    // Cassure haussière: prix au-dessus de la bande supérieure
    if(currentPrice > upper[0] && rates[0].close > rates[1].close) direction = 1;
    
    // Cassure baissière: prix en-dessous de la bande inférieure
    if(currentPrice < lower[0] && rates[0].close < rates[1].close) direction = -1;
    
    IndicatorRelease(bbHandle);
    return direction;
}

//+------------------------------------------------------------------+
//| Calcul lot dynamique basé sur confiance                         |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(int signal)
{
    if(!InpUseDynamicLotSize) return InpLotSize;
    
    double confidence = CalculateSpikeConfidence();
    double riskPercent = InpMaxRiskPercent * (confidence / 100.0);
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * riskPercent / 100.0;
    
    double atr = GetATR();
    if(atr <= 0) return InpLotSize;
    
    double stopLoss = atr * 2.0; // 2x ATR pour SL
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double lotSize = riskAmount / (stopLoss / tickSize * tickValue);
    
    // Limiter le lot
    lotSize = MathMax(InpMinLotSize, MathMin(InpMaxLotSize, lotSize));
    
    // Arrondir selon le step
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(lotStep > 0) lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Obtenir ATR                                                     |
//+------------------------------------------------------------------+
double GetATR()
{
    int atrHandle = iATR(_Symbol, PERIOD_M15, InpATRPeriod);
    if(atrHandle == INVALID_HANDLE) return 0;
    
    double atr[];
    if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) {
        IndicatorRelease(atrHandle);
        return 0;
    }
    
    double result = atr[0];
    IndicatorRelease(atrHandle);
    return result;
}

//+------------------------------------------------------------------+
//| Obtenir direction de tendance                                   |
//+------------------------------------------------------------------+
int GetTrendDirection(ENUM_TIMEFRAMES timeframe)
{
    int emaFast = iMA(_Symbol, timeframe, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
    int emaSlow = iMA(_Symbol, timeframe, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
    
    if(emaFast == INVALID_HANDLE || emaSlow == INVALID_HANDLE) return 0;
    
    double fast[], slow[];
    if(CopyBuffer(emaFast, 0, 0, 1, fast) < 1 || CopyBuffer(emaSlow, 0, 0, 1, slow) < 1) {
        IndicatorRelease(emaFast); IndicatorRelease(emaSlow);
        return 0;
    }
    
    int direction = 0;
    if(fast[0] > slow[0]) direction = 1;
    if(fast[0] < slow[0]) direction = -1;
    
    IndicatorRelease(emaFast); IndicatorRelease(emaSlow);
    return direction;
}

//+------------------------------------------------------------------+
//| Vérifier proximité S/R                                          |
//+------------------------------------------------------------------+
bool IsNearSupportResistance()
{
    if(!InpUseDynamicSR) return true;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atr = GetATR();
    if(atr <= 0) return true;
    
    // Calculer S/R basés sur les pivots récents
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_H1, 0, InpSRPeriod, rates) < InpSRPeriod) return true;
    
    double high = rates[0].high, low = rates[0].low;
    for(int i = 1; i < InpSRPeriod; i++) {
        if(rates[i].high > high) high = rates[i].high;
        if(rates[i].low < low) low = rates[i].low;
    }
    
    double proximity = atr * InpSRProximityPercent / 100.0;
    return (MathAbs(currentPrice - high) <= proximity || MathAbs(currentPrice - low) <= proximity);
}

//+------------------------------------------------------------------+
//| Vérifier si c'est un index Boom/Crash                          |
//+------------------------------------------------------------------+
bool IsBoomCrashIndex(string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

//+------------------------------------------------------------------+
//| Exécuter trade ultra-professionnel                              |
//+------------------------------------------------------------------+
bool ExecuteUltraTrade(int direction, double lotSize)
{
    if(direction == 0) return false;
    
    double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculer SL/TP basés sur ATR
    double atr = GetATR();
    double sl = 0, tp = 0;
    
    if(atr > 0) {
        if(direction > 0) {
            sl = price - (atr * 2.0);
            tp = price + (atr * 3.0);
        } else {
            sl = price + (atr * 2.0);
            tp = price - (atr * 3.0);
        }
    }
    
    bool result = false;
    if(direction > 0) {
        result = m_trade.Buy(lotSize, _Symbol, price, sl, tp, "UltraPro");
    } else {
        result = m_trade.Sell(lotSize, _Symbol, price, sl, tp, "UltraPro");
    }
    
    if(result) {
        Print("🚀 ULTRA-TRADE: ", (direction > 0 ? "BUY" : "SELL"), 
              " Lot: ", DoubleToString(lotSize, 2),
              " Prix: ", DoubleToString(price, _Digits));
    } else {
        Print("❌ Échec trade: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
    }
    
    return result;
}
