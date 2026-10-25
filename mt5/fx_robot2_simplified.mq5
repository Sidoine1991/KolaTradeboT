//+------------------------------------------------------------------+
//|                 Fx_robot_v2_Simplifié                            |
//|      Version simplifiée avec stratégie BOOM/CRASH fonctionnelle   |
//|               Basé sur le travail de YEBADOKPO Sidoine             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025 - YEBADOKPO Sidoine & AI Assistant"
#property version   "2.01"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// --- STRUCTURES DE DONNÉES CLÉS ---
struct Signal
{
   bool     isValid;         // Le signal est-il valide pour le trading ?
   string   symbol;          // Symbole
   int      direction;       // +1 pour BUY, -1 pour SELL
   double   confidence;      // Score de confiance du signal (0-100)
   double   entryPrice;      // Prix d'entrée suggéré
   double   stopLoss;        // Prix du Stop Loss
   double   takeProfit;      // Prix du Take Profit
   string   reason;          // Quelle logique a généré le signal
   bool     isReverseTrade;  // S'agit-il d'un trade à contre-tendance ?
};

// --- PARAMÈTRES PRINCIPAUX ---
input group "=== STRATÉGIE & RISQUE ==="
input int    InpMagicNumber      = 20251116;  // Magic Number pour identifier les trades de ce robot
input double InpCapitalRisk       = 10.0;      // Capital total disponible pour le trading
input double InpMaxRiskPerTrade  = 1.0;       // Risque MAX par trade (10% du capital)
input double InpTargetProfit     = 2.0;       // Gain cible en dollars pour fermer le trade
input double InpMaxLossPerTrade  = 1.0;       // Perte maximale autorisée par trade
input double InpRiskRewardRatio  = 2.0;       // Ratio Risque/Récompense (ex: 2.0 pour 1:2)
input int    InpMaxOpenPositions = 1;         // Nombre MAX de positions ouvertes simultanément
input bool   InpEnableTrading    = true;      // Activer/Désactiver le trading

input group "=== INDICATEURS & SIGNAUX ==="
input int    InpFastEMA          = 9;         // Période EMA rapide
input int    InpSlowEMA          = 21;        // Période EMA lente
input int    InpTrendEMA         = 50;        // Période EMA de tendance
input int    InpSMCLookback       = 100;       // Nombre de bougies pour analyse SMC
input int    InpSwingWindow      = 5;         // Fenêtre pour détecter swings
input double InpMinMovePips      = 5.0;       // Mouvement minimum en pips pour signal

input group "=== VISUEL & NOTIFICATIONS ==="
input bool   InpShowDashboard    = true;      // Afficher le dashboard de trading
input bool   InpShowIndicators   = true;      // Afficher tous les indicateurs sur le graphique ?
input bool   InpShowSMCVisuals   = true;      // Afficher les zones SMC (BOS, CHOCH) ?
input bool   InpNotifyAllSignals = true;      // Notifier TOUS les signaux (même rejetés)
input bool   InpEnableNotifications = true;   // Activer notifications mobiles
input bool   InpEnableAlerts     = true;      // Activer alertes PC

// --- VARIABLES GLOBALES ---
CTrade trade;
CPositionInfo positionInfo;

// Handles d'indicateurs
int h_emaFast;
int h_emaSlow;
int h_emaTrend;
int h_emaM5_34;
int h_emaM5_50;
int h_emaM1_10;
int h_emaM1_13;

// Variables globales pour supports/résistances H1
double g_h1Supports[10];
int    g_h1SupportCount = 0;
double g_h1Resistances[10];
int    g_h1ResistanceCount = 0;

// --- DÉCLARATION DES FONCTIONS ---
int OnInit();
void OnDeinit(const int reason);
void OnTick();
void OnTimer();

// Fonctions de trading
Signal CheckSMCSignal_();
Signal CheckScientificSpikeSignal();
bool ValidateSignal(Signal &signal);
void ExecuteTrade(Signal &signal);
void CheckTargetProfitLoss();

// Fonctions de gestion des positions
bool HasOpenPosition();
double GetPositionProfit();
void CloseAllPositions();

// Fonctions d'analyse
int GetTrendDirection();
double GetIndicatorValue(int handle, int index);
bool IsBoomCrashSymbol();
bool DetectEmaBouncePattern(bool isBuySignal);
bool CheckM5EmaConfluence(bool isBuySignal);
bool CheckM1EmaConfluence(bool isBuySignal);

// Fonctions utilitaires
void UpdateDashboard();
string FormatMoney(double amount);
string FormatTime(datetime time);
void SendNotification(string message);
void DrawSignalVisuals(Signal &signal);
void DrawAllIndicators();

// Fonctions H1 S/R
void LoadH1SupportsResistances();
void DrawH1SupportsResistances();
double FindNearestH1Support(double currentPrice);
double FindNearestH1Resistance(double currentPrice);

//+------------------------------------------------------------------+
//| FONCTION D'INITIALISATION                                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialiser les handles d'indicateurs
    h_emaFast = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
    h_emaSlow = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
    h_emaTrend = iMA(_Symbol, PERIOD_CURRENT, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
    
    // EMA pour M5
    h_emaM5_34 = iMA(_Symbol, PERIOD_M5, 34, 0, MODE_EMA, PRICE_CLOSE);
    h_emaM5_50 = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
    
    // EMA pour M1
    h_emaM1_10 = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
    h_emaM1_13 = iMA(_Symbol, PERIOD_M1, 13, 0, MODE_EMA, PRICE_CLOSE);
    
    // Vérifier les handles
    if(h_emaFast == INVALID_HANDLE || h_emaSlow == INVALID_HANDLE || 
       h_emaTrend == INVALID_HANDLE || h_emaM5_34 == INVALID_HANDLE ||
       h_emaM5_50 == INVALID_HANDLE || h_emaM1_10 == INVALID_HANDLE ||
       h_emaM1_13 == INVALID_HANDLE)
    {
        Print("ERREUR: Impossible d'initialiser les indicateurs");
        return INIT_FAILED;
    }
    
    // Configurer le trade
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    
    // Charger les supports/résistances H1
    LoadH1SupportsResistances();
    
    // Créer le timer pour mise à jour dashboard
    EventSetTimer(1);
    
    Print("=== fx_robot2.mq5 Initialisé ===");
    Print("Stratégie: BUY BOOM / SELL CRASH avec zones d'opportunité");
    Print("Capital: $", FormatMoney(InpCapitalRisk));
    Print("Risk/Reward: 1:", DoubleToString(InpRiskRewardRatio, 1));
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| FONCTION DE DÉSINITIALISATION                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    
    // Nettoyer les objets graphiques
    ObjectsDeleteAll(0, "FX_ROBOT_");
    ObjectsDeleteAll(0, "H1_SR_");
    ObjectsDeleteAll(0, "SIGNAL_");
    ObjectsDeleteAll(0, "IND_");
    
    Print("=== fx_robot2.mq5 Désinitialisé ===");
}

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE ON TICK                                       |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérifier si le trading est activé
    if(!InpEnableTrading) return;
    
    // Vérifier si on a déjà une position ouverte
    if(HasOpenPosition())
    {
        // Gérer la position existante
        CheckTargetProfitLoss();
        return;
    }
    
    // Analyser les signaux de trading
    Signal smcSignal = CheckSMCSignal_();
    Signal spikeSignal = CheckScientificSpikeSignal();
    
    // Choisir le meilleur signal
    Signal bestSignal;
    bestSignal.isValid = false;
    
    if(smcSignal.isValid && spikeSignal.isValid)
    {
        // Comparer la confiance des signaux
        bestSignal = (smcSignal.confidence > spikeSignal.confidence) ? smcSignal : spikeSignal;
    }
    else if(smcSignal.isValid)
    {
        bestSignal = smcSignal;
    }
    else if(spikeSignal.isValid)
    {
        bestSignal = spikeSignal;
    }
    
    // Valider et exécuter le signal
    if(bestSignal.isValid)
    {
        if(ValidateSignal(bestSignal))
        {
            ExecuteTrade(bestSignal);
        }
        else if(InpNotifyAllSignals)
        {
            Print("🚫 SIGNAL REJETÉ: ", bestSignal.reason, " | Validation échouée");
            SendNotification("🚫 Signal rejeté: " + bestSignal.reason);
        }
    }
    
    // Mettre à jour le dashboard
    if(InpShowDashboard)
    {
        static datetime lastUpdate = 0;
        if(TimeCurrent() - lastUpdate >= 5) // Mise à jour toutes les 5 secondes
        {
            UpdateDashboard();
            lastUpdate = TimeCurrent();
        }
    }
    
    // Dessiner les indicateurs si activés
    if(InpShowIndicators)
    {
        static datetime lastDraw = 0;
        if(TimeCurrent() - lastDraw >= 10) // Mise à jour toutes les 10 secondes
        {
            DrawAllIndicators();
            lastDraw = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| TIMER POUR MISES À JOUR                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Mettre à jour le dashboard régulièrement
    if(InpShowDashboard)
    {
        UpdateDashboard();
    }
    
    // Redessiner les supports/résistances H1
    static datetime lastH1Update = 0;
    if(TimeCurrent() - lastH1Update >= 300) // Toutes les 5 minutes
    {
        LoadH1SupportsResistances();
        DrawH1SupportsResistances();
        lastH1Update = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| FONCTION SMC SIMPLIFIÉE                                           |
//+------------------------------------------------------------------+
Signal CheckSMCSignal_()
{
    Signal sig;
    sig.isValid = false;
    sig.symbol = _Symbol;
    
    // Implémentation SMC de base simplifiée
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, InpSMCLookback, rates) < InpSMCLookback) return sig;
    ArraySetAsSeries(rates, true);

    // Trouver les derniers swing high et swing low
    int lastSwingHighIdx = iHighest(_Symbol, _Period, MODE_HIGH, 2 * InpSwingWindow + 1, InpSwingWindow);
    int lastSwingLowIdx = iLowest(_Symbol, _Period, MODE_LOW, 2 * InpSwingWindow + 1, InpSwingWindow);

    // CHOCH Haussier: le prix casse le dernier swing high après une tendance baissière
    if(rates[0].close > rates[lastSwingHighIdx].high && GetTrendDirection() < 0)
    {
        sig.isValid = true;
        sig.reason = "SMC CHOCH Bullish";
        sig.direction = 1;
        sig.confidence = 60.0;
        sig.entryPrice = rates[0].high;
        
        // Placer le SL sous le dernier swing low
        double slPrice = rates[iLowest(_Symbol, _Period, MODE_LOW, 20, 1)].low;
        double tpPrice = sig.entryPrice + (sig.entryPrice - slPrice) * InpRiskRewardRatio;
        sig.stopLoss = slPrice;
        sig.takeProfit = tpPrice;
        return sig;
    }

    // CHOCH Baissier: le prix casse le dernier swing low après une tendance haussière
    if(rates[0].close < rates[iLowest(_Symbol, _Period, MODE_LOW, 2 * InpSwingWindow + 1, InpSwingWindow)].low && GetTrendDirection() > 0)
    {
        sig.isValid = true;
        sig.reason = "SMC CHOCH Bearish";
        sig.direction = -1;
        sig.confidence = 60.0;
        sig.entryPrice = rates[0].low;

        // Placer le SL au-dessus du dernier swing high
        double slPrice = rates[iHighest(_Symbol, _Period, MODE_HIGH, 20, 1)].high;
        double tpPrice = sig.entryPrice - (slPrice - sig.entryPrice) * InpRiskRewardRatio;
        sig.stopLoss = slPrice;
        sig.takeProfit = tpPrice;
        return sig;
    }
    
    return sig;
}

//+------------------------------------------------------------------+
//| DÉTECTION DES SPIKES SCIENTIFIQUES                                |
//+------------------------------------------------------------------+
Signal CheckScientificSpikeSignal()
{
    Signal sig;
    sig.isValid = false;
    sig.symbol = _Symbol;
    
    // Récupérer les données de prix
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, 50, rates) < 50) return sig;
    ArraySetAsSeries(rates, true);
    
    // Calculer le volume moyen et le range moyen
    double avgVolume = 0;
    double avgRange = 0;
    for(int i = 1; i < 20; i++) // Exclure la bougie actuelle
    {
        avgVolume += rates[i].tick_volume;
        avgRange += rates[i].high - rates[i].low;
    }
    avgVolume /= 19;
    avgRange /= 19;
    
    // Détecter un spike potentiel
    long currentVolume = rates[0].tick_volume;
    double currentRange = rates[0].high - rates[0].low;
    
    bool volumeSpike = (currentVolume > avgVolume * 2.0);
    bool rangeSpike = (currentRange > avgRange * 1.5);
    
    if(volumeSpike && rangeSpike)
    {
        // Déterminer la direction du spike
        if(rates[0].close > rates[0].open)
        {
            // Spike haussier
            sig.isValid = true;
            sig.direction = 1; // BUY
            sig.reason = "Scientific Spike Bullish";
            sig.confidence = 75.0;
            sig.entryPrice = rates[0].high;
            
            // Calculer SL/TP
            double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
            sig.stopLoss = sig.entryPrice - atr * 1.5;
            sig.takeProfit = sig.entryPrice + atr * 3.0;
        }
        else
        {
            // Spike baissier
            sig.isValid = true;
            sig.direction = -1; // SELL
            sig.reason = "Scientific Spike Bearish";
            sig.confidence = 75.0;
            sig.entryPrice = rates[0].low;
            
            // Calculer SL/TP
            double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
            sig.stopLoss = sig.entryPrice + atr * 1.5;
            sig.takeProfit = sig.entryPrice - atr * 3.0;
        }
    }
    
    return sig;
}

//+------------------------------------------------------------------+
//| VALIDATION DES SIGNAUX AVEC STRATÉGIE BOOM/CRASH                   |
//+------------------------------------------------------------------+
bool ValidateSignal(Signal &signal)
{
    bool isBoomSymbol = (StringFind(_Symbol, "Boom") >= 0);
    bool isCrashSymbol = (StringFind(_Symbol, "Crash") >= 0);
    
    // LOGIQUE NOUVELLE: BUY sur BOOM, SELL sur CRASH en zone d'opportunité
    if(isBoomSymbol)
    {
        if(signal.direction == -1) // SELL sur BOOM
        {
            if(InpNotifyAllSignals)
            {
                Print("🚫 SELL REJETÉ sur ", _Symbol, " | Stratégie: BUY uniquement sur BOOM");
                SendNotification("🚫 SELL rejeté sur " + _Symbol + " - Stratégie BOOM uniquement");
            }
            return false;
        }
        
        // Pour BUY sur BOOM, vérifier la zone d'opportunité
        if(!DetectEmaBouncePattern(true))
        {
            if(InpNotifyAllSignals)
            {
                Print("🚫 BUY BOOM REJETÉ | Pas en zone d'opportunité pour spike");
                SendNotification("🚫 BUY BOOM rejeté - Pas en zone d'opportunité");
            }
            return false;
        }
        
        // Vérifier la tendance (éviter tendance très baissière)
        int trend = GetTrendDirection();
        if(trend < -2)
        {
            if(InpNotifyAllSignals)
            {
                Print("🚫 BUY BOOM REJETÉ | Tendance trop baissière (", trend, ") | Attendre zone neutre");
                SendNotification("🚫 BUY BOOM rejeté - Tendance trop baissière");
            }
            return false;
        }
        
        Print("✅ BUY BOOM VALIDÉ | ", signal.reason, " | Confiance: ", signal.confidence, "%");
        return true;
    }
    else if(isCrashSymbol)
    {
        if(signal.direction == 1) // BUY sur CRASH
        {
            if(InpNotifyAllSignals)
            {
                Print("🚫 BUY REJETÉ sur ", _Symbol, " | Stratégie: SELL uniquement sur CRASH");
                SendNotification("🚫 BUY rejeté sur " + _Symbol + " - Stratégie CRASH uniquement");
            }
            return false;
        }
        
        // Pour SELL sur CRASH, vérifier la zone d'opportunité
        if(!DetectEmaBouncePattern(false))
        {
            if(InpNotifyAllSignals)
            {
                Print("🚫 SELL CRASH REJETÉ | Pas en zone d'opportunité pour spike");
                SendNotification("🚫 SELL CRASH rejeté - Pas en zone d'opportunité");
            }
            return false;
        }
        
        // Vérifier la tendance (éviter tendance très haussière)
        int trend = GetTrendDirection();
        if(trend > 2)
        {
            if(InpNotifyAllSignals)
            {
                Print("🚫 SELL CRASH REJETÉ | Tendance trop haussière (", trend, ") | Attendre zone neutre");
                SendNotification("🚫 SELL CRASH rejeté - Tendance trop haussière");
            }
            return false;
        }
        
        Print("✅ SELL CRASH VALIDÉ | ", signal.reason, " | Confiance: ", signal.confidence, "%");
        return true;
    }
    else
    {
        // Pour les autres symboles, logique standard
        // Vérifier si on est près d'un support/résistance H1
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        bool nearH1SR = false;
        
        if(signal.direction > 0) // BUY
        {
            double nearestSupport = FindNearestH1Support(currentPrice);
            if(nearestSupport > 0 && MathAbs(currentPrice - nearestSupport) <= 15 * _Point)
            {
                nearH1SR = true;
            }
        }
        else // SELL
        {
            double nearestResistance = FindNearestH1Resistance(currentPrice);
            if(nearestResistance > 0 && MathAbs(currentPrice - nearestResistance) <= 15 * _Point)
            {
                nearH1SR = true;
            }
        }
        
        if(!nearH1SR)
        {
            if(InpNotifyAllSignals)
            {
                Print("🚫 SIGNAL REJETÉ sur ", _Symbol, " | Pas près de S/R H1");
                SendNotification("🚫 Signal rejeté sur " + _Symbol + " - Pas près S/R H1");
            }
            return false;
        }
        
        Print("✅ SIGNAL VALIDÉ sur ", _Symbol, " | ", signal.reason, " | Confiance: ", signal.confidence, "%");
        return true;
    }
}

//+------------------------------------------------------------------+
//| EXÉCUTION DES TRADES                                              |
//+------------------------------------------------------------------+
void ExecuteTrade(Signal &signal)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lotSize;
    
    // Calculer la taille de position basée sur le risque
    double riskAmount = MathMin(InpMaxRiskPerTrade, InpCapitalRisk * 0.1);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize > 0)
    {
        double pointValue = tickValue / tickSize;
        double riskPoints = MathAbs(signal.entryPrice - signal.stopLoss) / _Point;
        lotSize = riskAmount / (riskPoints * pointValue);
    }
    else
    {
        lotSize = 0.001; // Taille minimale par défaut
    }
    
    // Arrondir la taille de position
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lotSize = MathFloor(lotSize / stepLot) * stepLot;
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    // Exécuter le trade
    bool success = false;
    
    if(signal.direction > 0) // BUY
    {
        success = trade.Buy(lotSize, _Symbol, signal.entryPrice, signal.stopLoss, signal.takeProfit, signal.reason);
    }
    else // SELL
    {
        success = trade.Sell(lotSize, _Symbol, signal.entryPrice, signal.stopLoss, signal.takeProfit, signal.reason);
    }
    
    if(success)
    {
        Print("✅ TRADE OUVERT: ", (signal.direction > 0) ? "BUY" : "SELL", " ", _Symbol, 
              " @", DoubleToString(signal.entryPrice, 5), ", Lot: ", DoubleToString(lotSize, 3));
        Print("   SL: ", DoubleToString(signal.stopLoss, 5), " | TP: ", DoubleToString(signal.takeProfit, 5));
        Print("   Raison: ", signal.reason, " | Confiance: ", signal.confidence, "%");
        
        // Envoyer notification
        if(InpEnableNotifications)
        {
            string msg = "✅ Trade ouvert: " + (signal.direction > 0 ? "BUY" : "SELL") + " " + _Symbol + 
                        " @ " + DoubleToString(signal.entryPrice, 5) + "\n" +
                        "SL: " + DoubleToString(signal.stopLoss, 5) + " | TP: " + DoubleToString(signal.takeProfit, 5) + 
                        "\nRaison: " + signal.reason;
            SendNotification(msg);
        }
        
        // Dessiner le signal visuel
        if(InpShowIndicators)
        {
            DrawSignalVisuals(signal);
        }
    }
    else
    {
        Print("❌ ÉCHEC TRADE: Erreur ", trade.ResultCode(), " - ", trade.ResultComment());
        SendNotification("❌ Échec d'ouverture de trade sur " + _Symbol);
    }
}

//+------------------------------------------------------------------+
//| VÉRIFICATION DU PROFIT/PARTE CIBLE                                |
//+------------------------------------------------------------------+
void CheckTargetProfitLoss()
{
    if(!HasOpenPosition()) return;
    
    double profit = GetPositionProfit();
    
    // Fermer si le profit cible est atteint
    if(profit >= InpTargetProfit)
    {
        Print("🎯 OBJECTIF ATTEINT: Profit $", FormatMoney(profit));
        CloseAllPositions();
        
        if(InpEnableNotifications)
        {
            SendNotification("🎯 Objectif atteint: Profit $" + FormatMoney(profit));
        }
        return;
    }
    
    // Fermer si la perte maximale est atteinte
    if(profit <= -InpMaxLossPerTrade)
    {
        Print("🛑 PERTE MAXIMALE ATTEINTE: Perte $", FormatMoney(MathAbs(profit)));
        CloseAllPositions();
        
        if(InpEnableNotifications)
        {
            SendNotification("🛑 Perte maximale atteinte: $" + FormatMoney(MathAbs(profit)));
        }
        return;
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS DE GESTION DES POSITIONS                                |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
            {
                return true;
            }
        }
    }
    return false;
}

double GetPositionProfit()
{
    if(!HasOpenPosition()) return 0;
    
    if(positionInfo.SelectByIndex(0))
    {
        return positionInfo.Profit();
    }
    
    return 0;
}

void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
            {
                trade.PositionClose(positionInfo.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS D'ANALYSE                                               |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
    double emaFast[], emaSlow[];
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaSlow, true);

    if(CopyBuffer(h_emaFast, 0, 0, 2, emaFast) <= 0 ||
       CopyBuffer(h_emaSlow, 0, 0, 2, emaSlow) <= 0)
    {
        return 0; // Neutre en cas d'erreur
    }

    if(emaFast[0] > emaSlow[0] && emaFast[1] > emaSlow[1])
        return 1; // Haussier
    else if(emaFast[0] < emaSlow[0] && emaFast[1] < emaSlow[1])
        return -1; // Baissier
    else
        return 0; // Neutre
}

double GetIndicatorValue(int handle, int index)
{
    double buffer[];
    ArraySetAsSeries(buffer, true);

    if(CopyBuffer(handle, 0, index, 1, buffer) > 0)
    {
        return buffer[0];
    }

    return 0;
}

bool IsBoomCrashSymbol()
{
    return (StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0);
}

//+------------------------------------------------------------------+
//| DÉTECTION DES ZONES D'OPPORTUNITÉ POUR BOOM/CRASH                |
//+------------------------------------------------------------------+
bool DetectEmaBouncePattern(bool isBuySignal)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool isBoomSymbol = (StringFind(_Symbol, "Boom") >= 0);
    bool isCrashSymbol = (StringFind(_Symbol, "Crash") >= 0);
    
    // Vérifier si on est dans une zone d'opportunité
    bool inOpportunityZone = false;
    
    if(isBuySignal && isBoomSymbol) // BUY sur BOOM
    {
        // Zone d'opportunité BOOM: près d'un support H1 OU zone de survente EMA
        bool nearH1Support = false;
        
        // Vérifier les supports H1 (zone plus large pour spikes)
        for(int i = 0; i < g_h1SupportCount; i++)
        {
            if(MathAbs(currentPrice - g_h1Supports[i]) <= 25 * _Point) // Zone plus large
            {
                nearH1Support = true;
                break;
            }
        }
        
        // Vérifier si on est dans une zone de survente temporaire
        bool inOversoldZone = false;
        double emaFast[], emaSlow[];
        ArraySetAsSeries(emaFast, true);
        ArraySetAsSeries(emaSlow, true);
        
        if(CopyBuffer(h_emaFast, 0, 0, 3, emaFast) > 0 && CopyBuffer(h_emaSlow, 0, 0, 3, emaSlow) > 0)
        {
            // Zone de survente: prix sous EMA rapide mais proche de EMA lente
            if(currentPrice < emaFast[0] && MathAbs(currentPrice - emaSlow[0]) <= 10 * _Point)
            {
                inOversoldZone = true;
            }
        }
        
        // Vérifier la confluence EMA M5/M1 pour confirmation
        bool m5Confluence = CheckM5EmaConfluence(true); // BUY confluence
        bool m1Confluence = CheckM1EmaConfluence(true); // BUY confluence
        
        inOpportunityZone = (nearH1Support || inOversoldZone) && (m5Confluence || m1Confluence);
        
        if(inOpportunityZone)
        {
            Print("🎯 ZONE D'OPPORTUNITÉ BOOM détectée | Support H1: ", nearH1Support, " | Survente: ", inOversoldZone);
        }
    }
    else if(!isBuySignal && isCrashSymbol) // SELL sur CRASH
    {
        // Zone d'opportunité CRASH: près d'une résistance H1 OU zone de surachat EMA
        bool nearH1Resistance = false;
        
        // Vérifier les résistances H1 (zone plus large pour spikes)
        for(int i = 0; i < g_h1ResistanceCount; i++)
        {
            if(MathAbs(currentPrice - g_h1Resistances[i]) <= 25 * _Point) // Zone plus large
            {
                nearH1Resistance = true;
                break;
            }
        }
        
        // Vérifier si on est dans une zone de surachat temporaire
        bool inOverboughtZone = false;
        double emaFast[], emaSlow[];
        ArraySetAsSeries(emaFast, true);
        ArraySetAsSeries(emaSlow, true);
        
        if(CopyBuffer(h_emaFast, 0, 0, 3, emaFast) > 0 && CopyBuffer(h_emaSlow, 0, 0, 3, emaSlow) > 0)
        {
            // Zone de surachat: prix au-dessus EMA rapide mais proche de EMA lente
            if(currentPrice > emaFast[0] && MathAbs(currentPrice - emaSlow[0]) <= 10 * _Point)
            {
                inOverboughtZone = true;
            }
        }
        
        // Vérifier la confluence EMA M5/M1 pour confirmation
        bool m5Confluence = CheckM5EmaConfluence(false); // SELL confluence
        bool m1Confluence = CheckM1EmaConfluence(false); // SELL confluence
        
        inOpportunityZone = (nearH1Resistance || inOverboughtZone) && (m5Confluence || m1Confluence);
        
        if(inOpportunityZone)
        {
            Print("🎯 ZONE D'OPPORTUNITÉ CRASH détectée | Résistance H1: ", nearH1Resistance, " | Surachat: ", inOverboughtZone);
        }
    }
    else
    {
        // Pour les autres symboles, logique standard
        bool nearH1SR = false;
        
        if(isBuySignal)
        {
            for(int i = 0; i < g_h1SupportCount; i++)
            {
                if(MathAbs(currentPrice - g_h1Supports[i]) <= 15 * _Point)
                {
                    nearH1SR = true;
                    break;
                }
            }
        }
        else
        {
            for(int i = 0; i < g_h1ResistanceCount; i++)
            {
                if(MathAbs(currentPrice - g_h1Resistances[i]) <= 15 * _Point)
                {
                    nearH1SR = true;
                    break;
                }
            }
        }
        
        if(!nearH1SR) return false;
        
        bool m5Confluence = CheckM5EmaConfluence(isBuySignal);
        bool m1Confluence = CheckM1EmaConfluence(isBuySignal);
        
        inOpportunityZone = (m5Confluence && m1Confluence);
    }

    return inOpportunityZone;
}

//+------------------------------------------------------------------+
//| CONFLUENCE EMA M5                                                 |
//+------------------------------------------------------------------+
bool CheckM5EmaConfluence(bool isBuySignal)
{
    if(h_emaM5_34 == INVALID_HANDLE || h_emaM5_50 == INVALID_HANDLE)
    {
        Print("Handles EMA M5 invalides");
        return false;
    }
    
    double ema34[], ema50[];
    ArraySetAsSeries(ema34, true);
    ArraySetAsSeries(ema50, true);
    
    if(CopyBuffer(h_emaM5_34, 0, 0, 3, ema34) < 3 || CopyBuffer(h_emaM5_50, 0, 0, 3, ema50) < 3)
    {
        Print("Erreur lecture EMA M5");
        return false;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(isBuySignal)
    {
        // Pour BOOM: Le prix doit rebondir sur EMA 34 ou 50 en M5
        bool nearEma34 = (MathAbs(currentPrice - ema34[0]) <= 10 * _Point);
        bool nearEma50 = (MathAbs(currentPrice - ema50[0]) <= 10 * _Point);
        
        // Les EMA doivent être orientées vers le haut (tendance haussière sur M5)
        bool ema34Bullish = (ema34[0] > ema34[1] && ema34[1] > ema34[2]);
        bool ema50Bullish = (ema50[0] > ema50[1] && ema50[1] > ema50[2]);
        
        // EMA 34 au-dessus de EMA 50 (alignement haussier)
        bool bullishAlignment = (ema34[0] > ema50[0]);
        
        bool confluence = (nearEma34 || nearEma50) && (ema34Bullish || ema50Bullish) && bullishAlignment;
        
        if(confluence)
        {
            PrintFormat(" M5 EMA CONFLUENCE BUY: Prix @%.5f | EMA34: %.5f | EMA50: %.5f | Alignement: OK", 
                        currentPrice, ema34[0], ema50[0]);
        }
        
        return confluence;
    }
    else
    {
        // Pour CRASH: Le prix doit rebondir sur EMA 34 ou 50 en M5
        bool nearEma34 = (MathAbs(currentPrice - ema34[0]) <= 10 * _Point);
        bool nearEma50 = (MathAbs(currentPrice - ema50[0]) <= 10 * _Point);
        
        // Les EMA doivent être orientées vers le bas (tendance baissière sur M5)
        bool ema34Bearish = (ema34[0] < ema34[1] && ema34[1] < ema34[2]);
        bool ema50Bearish = (ema50[0] < ema50[1] && ema50[1] < ema50[2]);
        
        // EMA 34 en-dessous de EMA 50 (alignement baissier)
        bool bearishAlignment = (ema34[0] < ema50[0]);
        
        bool confluence = (nearEma34 || nearEma50) && (ema34Bearish || ema50Bearish) && bearishAlignment;
        
        if(confluence)
        {
            PrintFormat(" M5 EMA CONFLUENCE SELL: Prix @%.5f | EMA34: %.5f | EMA50: %.5f | Alignement: OK", 
                        currentPrice, ema34[0], ema50[0]);
        }
        
        return confluence;
    }
}

//+------------------------------------------------------------------+
//| CONFLUENCE EMA M1                                                 |
//+------------------------------------------------------------------+
bool CheckM1EmaConfluence(bool isBuySignal)
{
    if(h_emaM1_10 == INVALID_HANDLE || h_emaM1_13 == INVALID_HANDLE)
    {
        Print("Handles EMA M1 invalides");
        return false;
    }
    
    double ema10[], ema13[];
    ArraySetAsSeries(ema10, true);
    ArraySetAsSeries(ema13, true);
    
    if(CopyBuffer(h_emaM1_10, 0, 0, 3, ema10) < 3 || CopyBuffer(h_emaM1_13, 0, 0, 3, ema13) < 3)
    {
        Print("Erreur lecture EMA M1");
        return false;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(isBuySignal)
    {
        // Pour BOOM: Le prix doit rebondir sur EMA 10 ou 13 en M1
        bool nearEma10 = (MathAbs(currentPrice - ema10[0]) <= 5 * _Point);
        bool nearEma13 = (MathAbs(currentPrice - ema13[0]) <= 5 * _Point);
        
        // Les EMA doivent être orientées vers le haut (tendance haussière sur M1)
        bool ema10Bullish = (ema10[0] > ema10[1] && ema10[1] > ema10[2]);
        bool ema13Bullish = (ema13[0] > ema13[1] && ema13[1] > ema13[2]);
        
        // EMA 10 au-dessus de EMA 13 (alignement haussier)
        bool bullishAlignment = (ema10[0] > ema13[0]);
        
        bool confluence = (nearEma10 || nearEma13) && (ema10Bullish || ema13Bullish) && bullishAlignment;
        
        if(confluence)
        {
            PrintFormat(" M1 EMA CONFLUENCE BUY: Prix @%.5f | EMA10: %.5f | EMA13: %.5f | Alignement: OK", 
                        currentPrice, ema10[0], ema13[0]);
        }
        
        return confluence;
    }
    else
    {
        // Pour CRASH: Le prix doit rebondir sur EMA 10 ou 13 en M1
        bool nearEma10 = (MathAbs(currentPrice - ema10[0]) <= 5 * _Point);
        bool nearEma13 = (MathAbs(currentPrice - ema13[0]) <= 5 * _Point);
        
        // Les EMA doivent être orientées vers le bas (tendance baissière sur M1)
        bool ema10Bearish = (ema10[0] < ema10[1] && ema10[1] < ema10[2]);
        bool ema13Bearish = (ema13[0] < ema13[1] && ema13[1] < ema13[2]);
        
        // EMA 10 en-dessous de EMA 13 (alignement baissier)
        bool bearishAlignment = (ema10[0] < ema13[0]);
        
        bool confluence = (nearEma10 || nearEma13) && (ema10Bearish || ema13Bearish) && bearishAlignment;
        
        if(confluence)
        {
            PrintFormat(" M1 EMA CONFLUENCE SELL: Prix @%.5f | EMA10: %.5f | EMA13: %.5f | Alignement: OK", 
                        currentPrice, ema10[0], ema13[0]);
        }
        
        return confluence;
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS UTILITAIRES                                             |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    // Effacer l'ancien dashboard
    ObjectsDeleteAll(0, "FX_ROBOT_DASHBOARD_");
    
    int startX = 20;
    int startY = 30;
    int lineHeight = 18;
    
    // Titre
    ObjectCreate(0, "FX_ROBOT_DASHBOARD_TITLE", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "FX_ROBOT_DASHBOARD_TITLE", OBJPROP_TEXT, "=== fx_robot2 v2.01 ===");
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TITLE", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TITLE", OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TITLE", OBJPROP_YDISTANCE, startY);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TITLE", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TITLE", OBJPROP_FONTSIZE, 12);
    
    // Stratégie
    ObjectCreate(0, "FX_ROBOT_DASHBOARD_STRATEGY", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "FX_ROBOT_DASHBOARD_STRATEGY", OBJPROP_TEXT, "Stratégie: BUY BOOM / SELL CRASH");
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_STRATEGY", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_STRATEGY", OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_STRATEGY", OBJPROP_YDISTANCE, startY + lineHeight);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_STRATEGY", OBJPROP_COLOR, clrLime);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_STRATEGY", OBJPROP_FONTSIZE, 10);
    
    // Symbole actuel
    ObjectCreate(0, "FX_ROBOT_DASHBOARD_SYMBOL", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "FX_ROBOT_DASHBOARD_SYMBOL", OBJPROP_TEXT, "Symbole: " + _Symbol);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_SYMBOL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_SYMBOL", OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_SYMBOL", OBJPROP_YDISTANCE, startY + lineHeight * 2);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_SYMBOL", OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_SYMBOL", OBJPROP_FONTSIZE, 10);
    
    // Capital
    ObjectCreate(0, "FX_ROBOT_DASHBOARD_CAPITAL", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "FX_ROBOT_DASHBOARD_CAPITAL", OBJPROP_TEXT, "Capital: $" + FormatMoney(InpCapitalRisk));
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_CAPITAL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_CAPITAL", OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_CAPITAL", OBJPROP_YDISTANCE, startY + lineHeight * 3);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_CAPITAL", OBJPROP_COLOR, clrAqua);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_CAPITAL", OBJPROP_FONTSIZE, 10);
    
    // Position actuelle
    if(HasOpenPosition())
    {
        double profit = GetPositionProfit();
        color profitColor = (profit >= 0) ? clrLime : clrRed;
        
        ObjectCreate(0, "FX_ROBOT_DASHBOARD_POSITION", OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_TEXT, "Position: OUVERTE | P/L: $" + FormatMoney(profit));
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_XDISTANCE, startX);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_YDISTANCE, startY + lineHeight * 4);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_COLOR, profitColor);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_FONTSIZE, 10);
    }
    else
    {
        ObjectCreate(0, "FX_ROBOT_DASHBOARD_POSITION", OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_TEXT, "Position: AUCUNE");
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_XDISTANCE, startX);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_YDISTANCE, startY + lineHeight * 4);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_POSITION", OBJPROP_FONTSIZE, 10);
    }
    
    // Objectifs
    ObjectCreate(0, "FX_ROBOT_DASHBOARD_TARGETS", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "FX_ROBOT_DASHBOARD_TARGETS", OBJPROP_TEXT, "Objectifs: Gain $" + FormatMoney(InpTargetProfit) + " | Perte $" + FormatMoney(InpMaxLossPerTrade));
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TARGETS", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TARGETS", OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TARGETS", OBJPROP_YDISTANCE, startY + lineHeight * 5);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TARGETS", OBJPROP_COLOR, clrOrange);
    ObjectSetInteger(0, "FX_ROBOT_DASHBOARD_TARGETS", OBJPROP_FONTSIZE, 10);
}

string FormatMoney(double amount)
{
    return DoubleToString(amount, 2);
}

string FormatTime(datetime time)
{
    return TimeToString(time, TIME_SECONDS);
}

void SendNotification(string message)
{
    if(InpEnableNotifications)
    {
        SendNotification(message);
    }
    
    if(InpEnableAlerts)
    {
        Alert(message);
    }
}

void DrawSignalVisuals(Signal &signal)
{
    string name = "SIGNAL_" + IntegerToString(TimeCurrent());
    datetime time = iTime(_Symbol, _Period, 0);

    ObjectCreate(0, name, OBJ_ARROW, 0, time, signal.entryPrice);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, signal.direction > 0 ? 241 : 242);
    ObjectSetInteger(0, name, OBJPROP_COLOR, signal.direction > 0 ? clrBlue : clrRed);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
}

void DrawAllIndicators()
{
    // Nettoyer les anciens indicateurs
    ObjectsDeleteAll(0, "IND_");
    ObjectsDeleteAll(0, "H1_SR_");
    
    // Dessiner les supports/résistances H1
    DrawH1SupportsResistances();
    
    // Dessiner les EMA sur le graphique
    double emaFast[], emaSlow[];
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaSlow, true);
    
    if(CopyBuffer(h_emaFast, 0, 0, 50, emaFast) > 0)
    {
        for(int i = 0; i < 50; i++)
        {
            datetime time = iTime(_Symbol, _Period, i);
            string name = "IND_EMA_Fast_" + IntegerToString(i);
            
            ObjectCreate(0, name, OBJ_ARROW, 0, time, emaFast[i]);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        }
    }
    
    if(CopyBuffer(h_emaSlow, 0, 0, 50, emaSlow) > 0)
    {
        for(int i = 0; i < 50; i++)
        {
            datetime time = iTime(_Symbol, _Period, i);
            string name = "IND_EMA_Slow_" + IntegerToString(i);
            
            ObjectCreate(0, name, OBJ_ARROW, 0, time, emaSlow[i]);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS H1 SUPPORTS/RÉSISTANCES                                 |
//+------------------------------------------------------------------+
void LoadH1SupportsResistances()
{
    g_h1SupportCount = 0;
    g_h1ResistanceCount = 0;
    
    // Copier les données H1
    MqlRates h1Rates[];
    if(CopyRates(_Symbol, PERIOD_H1, 0, 200, h1Rates) < 200)
    {
        Print("Erreur chargement données H1");
        return;
    }
    ArraySetAsSeries(h1Rates, true);
    
    // Détecter les supports (swing lows)
    for(int i = 5; i < 150; i++)
    {
        double low = h1Rates[i].low;
        
        // Vérifier si c'est un swing low
        bool isSwingLow = true;
        for(int j = MathMax(0, i-3); j <= MathMin(ArraySize(h1Rates)-1, i+3); j++)
        {
            if(j != i && h1Rates[j].low < low)
            {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow && g_h1SupportCount < 10)
        {
            g_h1Supports[g_h1SupportCount] = low;
            g_h1SupportCount++;
        }
    }
    
    // Détecter les résistances (swing highs)
    for(int i = 5; i < 150; i++)
    {
        double high = h1Rates[i].high;
        
        // Vérifier si c'est un swing high
        bool isSwingHigh = true;
        for(int j = MathMax(0, i-3); j <= MathMin(ArraySize(h1Rates)-1, i+3); j++)
        {
            if(j != i && h1Rates[j].high > high)
            {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh && g_h1ResistanceCount < 10)
        {
            g_h1Resistances[g_h1ResistanceCount] = high;
            g_h1ResistanceCount++;
        }
    }
    
    PrintFormat(" H1 S/R chargés: %d supports, %d résistances", g_h1SupportCount, g_h1ResistanceCount);
}

void DrawH1SupportsResistances()
{
    // Nettoyer les anciens objets
    ObjectsDeleteAll(0, "H1_SR_");
    
    datetime currentTime = TimeCurrent();
    datetime futureTime = currentTime + 3600; // 1 heure dans le futur
    
    // Dessiner les supports (lignes vertes)
    for(int i = 0; i < g_h1SupportCount; i++)
    {
        string lineName = "H1_SR_Support_" + IntegerToString(i);
        
        ObjectCreate(0, lineName, OBJ_TREND, 0, currentTime - 3600, g_h1Supports[i], futureTime, g_h1Supports[i]);
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
        
        // Label pour le support
        string labelName = "H1_SR_Support_Label_" + IntegerToString(i);
        ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, g_h1Supports[i]);
        ObjectSetString(0, labelName, OBJPROP_TEXT, "H1 Support");
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    }
    
    // Dessiner les résistances (lignes rouges)
    for(int i = 0; i < g_h1ResistanceCount; i++)
    {
        string lineName = "H1_SR_Resistance_" + IntegerToString(i);
        
        ObjectCreate(0, lineName, OBJ_TREND, 0, currentTime - 3600, g_h1Resistances[i], futureTime, g_h1Resistances[i]);
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
        
        // Label pour la résistance
        string labelName = "H1_SR_Resistance_Label_" + IntegerToString(i);
        ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, g_h1Resistances[i]);
        ObjectSetString(0, labelName, OBJPROP_TEXT, "H1 Resistance");
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    }
}

double FindNearestH1Support(double currentPrice)
{
    double nearestSupport = 0;
    double minDistance = DBL_MAX;

    for(int i = 0; i < g_h1SupportCount; i++)
    {
        double distance = MathAbs(currentPrice - g_h1Supports[i]);
        if(distance < minDistance && g_h1Supports[i] < currentPrice)
        {
            minDistance = distance;
            nearestSupport = g_h1Supports[i];
        }
    }

    return nearestSupport;
}

double FindNearestH1Resistance(double currentPrice)
{
    double nearestResistance = 0;
    double minDistance = DBL_MAX;

    for(int i = 0; i < g_h1ResistanceCount; i++)
    {
        double distance = MathAbs(currentPrice - g_h1Resistances[i]);
        if(distance < minDistance && g_h1Resistances[i] > currentPrice)
        {
            minDistance = distance;
            nearestResistance = g_h1Resistances[i];
        }
    }

    return nearestResistance;
}
//+------------------------------------------------------------------+
