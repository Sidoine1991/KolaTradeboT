#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def integrer_indicateurs_spike_prediction():
    """Intégrer les fonctionnalités des indicateurs et la prédiction de spike dans AngelOfSpike_Fixed.mq5"""
    
    print("=== INTEGRATION DES INDICATEURS ET PREDICTION DE SPIKE ===")
    
    # Chemin vers les fichiers
    fichier_fixed = "AngelOfSpike_Fixed.mq5"
    fichier_original = "mt5/AngelOfSpike.mq5"
    
    if not os.path.exists(fichier_fixed):
        print(f"Fichier {fichier_fixed} non trouve!")
        return False
    
    if not os.path.exists(fichier_original):
        print(f"Fichier {fichier_original} non trouve!")
        return False
    
    try:
        # Lire le fichier AngelOfSpike_Fixed.mq5
        with open(fichier_fixed, 'r', encoding='utf-8') as f:
            contenu_fixed = f.read()
        
        # Lire le fichier AngelOfSpike.mq5 pour extraire les indicateurs
        with open(fichier_original, 'r', encoding='utf-8') as f:
            contenu_original = f.read()
        
        print(f"Fichiers lus avec succes")
        
        # 1. Ajouter les variables globales pour les indicateurs
        print("Ajout des variables globales pour les indicateurs...")
        
        variables_indicateurs = '''
//--- Variables globales pour les indicateurs
int g_ma20Handle = INVALID_HANDLE, g_ma50Handle = INVALID_HANDLE, g_ema12Handle = INVALID_HANDLE, g_ema26Handle = INVALID_HANDLE;
int g_rsiHandle = INVALID_HANDLE, g_macdHandle = INVALID_HANDLE, g_stochHandle = INVALID_HANDLE, g_atrHandle = INVALID_HANDLE, g_bbHandle = INVALID_HANDLE;
string g_currentSymbol = ""; // Current symbol for indicator operations

//--- Structure pour le cache des données d'indicateurs
struct IndicatorData
{
    string symbol;
    double ma20[2], ma50[2], ema12[2], ema26[2], rsi[2];
    double macdMain[2], macdSignal[2], stochMain[2], stochSignal[2], atr[2];
    double bbMiddle[2], bbUpper[2], bbLower[2];
    datetime lastUpdate;
};

//--- Cache des indicateurs par symbole
IndicatorData g_indicatorCache[];
int g_indicatorCacheSize = 0;

//--- Dernière mise à jour des indicateurs
datetime g_lastIndicatorUpdate = 0;
const int INDICATOR_UPDATE_INTERVAL = 1; // Mise à jour toutes les secondes

//--- Variables pour la prédiction de spike
bool g_spikePredictionActive = false;
string g_spikePredictionSymbol = "";
int g_spikePredictionDirection = 0;
double g_spikePredictionProbability = 0.0;
datetime g_spikePredictionTime = 0;
double g_spikePredictionEntryPrice = 0.0;
double g_spikePredictionStopLoss = 0.0;
double g_spikePredictionTakeProfit = 0.0;
bool g_spikePredictionExecuted = false;
'''
        
        # Ajouter les variables après les includes
        contenu_fixed = contenu_fixed.replace('#include <StdLibErr.mqh>', '#include <StdLibErr.mqh>\n' + variables_indicateurs)
        
        # 2. Ajouter les fonctions d'initialisation des indicateurs
        print("Ajout des fonctions d'initialisation des indicateurs...")
        
        fonction_init_indicators = '''
//+------------------------------------------------------------------+
//| Initialiser les indicateurs pour un symbole                      |
//+------------------------------------------------------------------+
bool InitializeIndicators(string symbol)
{
    if(symbol == g_currentSymbol) return true; // Déjà initialisé
    
    // Libérer les anciens handles
    if(g_currentSymbol != "")
    {
        ReleaseIndicators();
    }
    
    g_currentSymbol = symbol;
    
    // Initialiser les indicateurs
    g_ma20Handle = iMA(symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE);
    g_ma50Handle = iMA(symbol, PERIOD_M1, 50, 0, MODE_SMA, PRICE_CLOSE);
    g_ema12Handle = iMA(symbol, PERIOD_M1, 12, 0, MODE_EMA, PRICE_CLOSE);
    g_ema26Handle = iMA(symbol, PERIOD_M1, 26, 0, MODE_EMA, PRICE_CLOSE);
    g_rsiHandle = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE);
    g_macdHandle = iMACD(symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
    g_stochHandle = iStochastic(symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
    g_atrHandle = iATR(symbol, PERIOD_M1, 14);
    g_bbHandle = iBands(symbol, PERIOD_M1, 20, 0, 2.0, PRICE_CLOSE);
    
    // Vérifier que tous les handles sont valides
    if(g_ma20Handle == INVALID_HANDLE || g_ma50Handle == INVALID_HANDLE || 
       g_ema12Handle == INVALID_HANDLE || g_ema26Handle == INVALID_HANDLE ||
       g_rsiHandle == INVALID_HANDLE || g_macdHandle == INVALID_HANDLE ||
       g_stochHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE || g_bbHandle == INVALID_HANDLE)
    {
        Print("Erreur initialisation indicateurs pour ", symbol);
        return false;
    }
    
    Print("Indicateurs initialises pour ", symbol);
    return true;
}

//+------------------------------------------------------------------+
//| Libérer les handles des indicateurs                              |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
    if(g_ma20Handle != INVALID_HANDLE) { IndicatorRelease(g_ma20Handle); g_ma20Handle = INVALID_HANDLE; }
    if(g_ma50Handle != INVALID_HANDLE) { IndicatorRelease(g_ma50Handle); g_ma50Handle = INVALID_HANDLE; }
    if(g_ema12Handle != INVALID_HANDLE) { IndicatorRelease(g_ema12Handle); g_ema12Handle = INVALID_HANDLE; }
    if(g_ema26Handle != INVALID_HANDLE) { IndicatorRelease(g_ema26Handle); g_ema26Handle = INVALID_HANDLE; }
    if(g_rsiHandle != INVALID_HANDLE) { IndicatorRelease(g_rsiHandle); g_rsiHandle = INVALID_HANDLE; }
    if(g_macdHandle != INVALID_HANDLE) { IndicatorRelease(g_macdHandle); g_macdHandle = INVALID_HANDLE; }
    if(g_stochHandle != INVALID_HANDLE) { IndicatorRelease(g_stochHandle); g_stochHandle = INVALID_HANDLE; }
    if(g_atrHandle != INVALID_HANDLE) { IndicatorRelease(g_atrHandle); g_atrHandle = INVALID_HANDLE; }
    if(g_bbHandle != INVALID_HANDLE) { IndicatorRelease(g_bbHandle); g_bbHandle = INVALID_HANDLE; }
    
    g_currentSymbol = "";
}
'''
        
        # Ajouter les fonctions avant la fonction OnInit
        contenu_fixed = contenu_fixed.replace('//+------------------------------------------------------------------+\n//| Expert initialization function', fonction_init_indicators + '\n//+------------------------------------------------------------------+\n//| Expert initialization function')
        
        # 3. Améliorer la fonction AnalyzeConfluenceStrategy pour la prédiction de spike
        print("Amelioration de la fonction AnalyzeConfluenceStrategy pour la prediction de spike...")
        
        nouvelle_fonction_confluence = '''
//+------------------------------------------------------------------+
//| Analyser la stratégie de confluence avec prédiction de spike     |
//+------------------------------------------------------------------+
int AnalyzeConfluenceStrategy(string symbol)
{
    if(!InpEnableConfluence) return 0;

    // Initialiser les indicateurs si nécessaire
    if(!InitializeIndicators(symbol))
    {
        Print("Erreur initialisation indicateurs pour ", symbol);
        return 0;
    }

    int buySignals = 0;
    int sellSignals = 0;
    double spikeProbability = 0.0;
    bool spikeDetected = false;

    // --- Collection des signaux de chaque module ---
    if(InpEnableIndicator2025) 
    {
        int signal = AnalyzeIndicator2025(symbol);
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    if(InpEnableSR)
    {
        int signal = CheckSupportResistance(symbol);
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    if(InpEnableOrderBlock)
    {
        int signal = AnalyzeOrderBlock(symbol);
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    if(InpEnableOTE)
    {
        int signal = AnalyzeOTE_FIBO(symbol);
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }
    if(InpEnableBOS_CHoCH)
    {
        int signal = AnalyzeBOS_CHoCH(symbol);
        if(signal == 1) buySignals++;
        if(signal == -1) sellSignals++;
    }

    // --- Analyse de prédiction de spike ---
    spikeProbability = AnalyzeSpikePrediction(symbol);
    
    // --- Logique de décision de confluence avec prédiction de spike ---
    if(buySignals >= InpMinConfluenceSignals && sellSignals == 0)
    {
        if(spikeProbability >= 0.7) // Probabilité de spike élevée
        {
            if(InpDebug) Print("SPIKE PREDICTION BUY: ", IntegerToString(buySignals), " signaux, probabilité: ", DoubleToString(spikeProbability, 2));
            StartSpikePrediction(symbol, 1, spikeProbability);
            return 1; // Signal d'achat avec prédiction de spike
        }
        else if(buySignals >= InpMinConfluenceSignals + 1) // Plus de signaux requis si probabilité faible
        {
            if(InpDebug) Print("Confluence ACHAT: ", IntegerToString(buySignals), " signaux alignes.");
            return 1; // Signal d'achat standard
        }
    }
    
    if(sellSignals >= InpMinConfluenceSignals && buySignals == 0)
    {
        if(spikeProbability >= 0.7) // Probabilité de spike élevée
        {
            if(InpDebug) Print("SPIKE PREDICTION SELL: ", IntegerToString(sellSignals), " signaux, probabilité: ", DoubleToString(spikeProbability, 2));
            StartSpikePrediction(symbol, -1, spikeProbability);
            return -1; // Signal de vente avec prédiction de spike
        }
        else if(sellSignals >= InpMinConfluenceSignals + 1) // Plus de signaux requis si probabilité faible
        {
            if(InpDebug) Print("Confluence VENTE: ", IntegerToString(sellSignals), " signaux alignes.");
            return -1; // Signal de vente standard
        }
    }

    return 0; // Pas de signal de trading clair
}'''
        
        # Remplacer l'ancienne fonction
        contenu_fixed = re.sub(r'int AnalyzeConfluenceStrategy\(string symbol\)\s*\{[^}]*\}', nouvelle_fonction_confluence, contenu_fixed, flags=re.DOTALL)
        
        # 4. Ajouter la fonction d'analyse de prédiction de spike
        print("Ajout de la fonction d'analyse de prediction de spike...")
        
        fonction_spike_prediction = '''
//+------------------------------------------------------------------+
//| Analyser la prédiction de spike                                  |
//+------------------------------------------------------------------+
double AnalyzeSpikePrediction(string symbol)
{
    double spikeProbability = 0.0;
    
    // Obtenir les données des indicateurs
    double rsi[], ma20[], ma50[], ema12[], ema26[], macdMain[], macdSignal[], stochMain[], stochSignal[], atr[], bbUpper[], bbLower[], bbMiddle[];
    
    if(CopyBuffer(g_rsiHandle, 0, 0, 3, rsi) < 3) return 0.0;
    if(CopyBuffer(g_ma20Handle, 0, 0, 3, ma20) < 3) return 0.0;
    if(CopyBuffer(g_ma50Handle, 0, 0, 3, ma50) < 3) return 0.0;
    if(CopyBuffer(g_ema12Handle, 0, 0, 3, ema12) < 3) return 0.0;
    if(CopyBuffer(g_ema26Handle, 0, 0, 3, ema26) < 3) return 0.0;
    if(CopyBuffer(g_macdHandle, 0, 0, 3, macdMain) < 3) return 0.0;
    if(CopyBuffer(g_macdHandle, 1, 0, 3, macdSignal) < 3) return 0.0;
    if(CopyBuffer(g_stochHandle, 0, 0, 3, stochMain) < 3) return 0.0;
    if(CopyBuffer(g_stochHandle, 1, 0, 3, stochSignal) < 3) return 0.0;
    if(CopyBuffer(g_atrHandle, 0, 0, 3, atr) < 3) return 0.0;
    if(CopyBuffer(g_bbHandle, 1, 0, 3, bbUpper) < 3) return 0.0;
    if(CopyBuffer(g_bbHandle, 2, 0, 3, bbLower) < 3) return 0.0;
    if(CopyBuffer(g_bbHandle, 0, 0, 3, bbMiddle) < 3) return 0.0;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double spread = ask - currentPrice;
    
    // Facteurs de prédiction de spike
    double rsiFactor = 0.0;
    double maFactor = 0.0;
    double macdFactor = 0.0;
    double stochFactor = 0.0;
    double bbFactor = 0.0;
    double atrFactor = 0.0;
    
    // 1. RSI - Momentum extrême
    if(rsi[1] < 20 || rsi[1] > 80)
    {
        rsiFactor = 0.3; // RSI extrême
        if((rsi[1] < 20 && rsi[0] > rsi[1]) || (rsi[1] > 80 && rsi[0] < rsi[1]))
        {
            rsiFactor = 0.5; // RSI extrême + retournement
        }
    }
    else if(rsi[1] < 30 || rsi[1] > 70)
    {
        rsiFactor = 0.2; // RSI proche des extrêmes
    }
    
    // 2. Moyennes mobiles - Alignement
    if(ma20[1] > ma50[1] && ema12[1] > ema26[1])
    {
        maFactor = 0.2; // Tendance haussière
    }
    else if(ma20[1] < ma50[1] && ema12[1] < ema26[1])
    {
        maFactor = 0.2; // Tendance baissière
    }
    
    // 3. MACD - Divergence
    if(macdMain[1] > macdSignal[1] && macdMain[0] > macdMain[1])
    {
        macdFactor = 0.2; // MACD haussier
    }
    else if(macdMain[1] < macdSignal[1] && macdMain[0] < macdMain[1])
    {
        macdFactor = 0.2; // MACD baissier
    }
    
    // 4. Stochastic - Momentum
    if(stochMain[1] < 20 || stochMain[1] > 80)
    {
        stochFactor = 0.2; // Stochastic extrême
    }
    
    // 5. Bollinger Bands - Compression
    double bbWidth = bbUpper[1] - bbLower[1];
    double bbWidthAvg = (bbUpper[0] + bbUpper[1] + bbUpper[2]) / 3 - (bbLower[0] + bbLower[1] + bbLower[2]) / 3;
    
    if(bbWidth < bbWidthAvg * 0.8) // Compression des bandes
    {
        bbFactor = 0.3; // Compression = potentiel de breakout
    }
    
    // 6. ATR - Volatilité
    if(atr[1] > atr[0] * 1.2) // Volatilité croissante
    {
        atrFactor = 0.2;
    }
    
    // Calculer la probabilité totale
    spikeProbability = rsiFactor + maFactor + macdFactor + stochFactor + bbFactor + atrFactor;
    
    // Limiter entre 0 et 1
    if(spikeProbability > 1.0) spikeProbability = 1.0;
    if(spikeProbability < 0.0) spikeProbability = 0.0;
    
    if(InpDebug && spikeProbability > 0.5)
    {
        Print("SPIKE PREDICTION: ", DoubleToString(spikeProbability, 2), " RSI:", DoubleToString(rsi[1], 1), " MA:", DoubleToString(maFactor, 2), " MACD:", DoubleToString(macdFactor, 2));
    }
    
    return spikeProbability;
}'''
        
        # Ajouter la fonction avant la fonction ExecuteTrade
        contenu_fixed = contenu_fixed.replace('//+------------------------------------------------------------------+\n//| Exécuter le trade basé sur la confluence', fonction_spike_prediction + '\n//+------------------------------------------------------------------+\n//| Exécuter le trade basé sur la confluence')
        
        # 5. Ajouter la fonction de démarrage de prédiction de spike
        print("Ajout de la fonction de demarrage de prediction de spike...")
        
        fonction_start_spike_prediction = '''
//+------------------------------------------------------------------+
//| Démarrer la prédiction de spike                                  |
//+------------------------------------------------------------------+
void StartSpikePrediction(string symbol, int direction, double probability)
{
    g_spikePredictionActive = true;
    g_spikePredictionSymbol = symbol;
    g_spikePredictionDirection = direction;
    g_spikePredictionProbability = probability;
    g_spikePredictionTime = TimeCurrent();
    g_spikePredictionExecuted = false;
    
    // Calculer les niveaux de prix
    double currentPrice = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double atr = 0.0;
    double atrBuffer[];
    if(CopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) > 0)
    {
        atr = atrBuffer[0];
    }
    
    // Calculer SL et TP basés sur ATR
    double slDistance = atr * 2.0; // SL à 2 ATR
    double tpDistance = atr * 3.0; // TP à 3 ATR (ratio 1:1.5)
    
    if(direction == 1) // Achat
    {
        g_spikePredictionEntryPrice = currentPrice;
        g_spikePredictionStopLoss = currentPrice - slDistance;
        g_spikePredictionTakeProfit = currentPrice + tpDistance;
    }
    else // Vente
    {
        g_spikePredictionEntryPrice = currentPrice;
        g_spikePredictionStopLoss = currentPrice + slDistance;
        g_spikePredictionTakeProfit = currentPrice - tpDistance;
    }
    
    if(InpDebug)
    {
        Print("SPIKE PREDICTION DEMARREE: ", symbol, " Direction: ", direction, " Probabilité: ", DoubleToString(probability, 2));
        Print("Entry: ", DoubleToString(g_spikePredictionEntryPrice, 5), " SL: ", DoubleToString(g_spikePredictionStopLoss, 5), " TP: ", DoubleToString(g_spikePredictionTakeProfit, 5));
    }
    
    // Afficher la flèche de prédiction
    if(InpShowSpikeArrows)
    {
        ShowPredictionArrow(symbol, 0, direction);
    }
    
    // Envoyer notification
    if(InpNotifyPreSpike)
    {
        string message = "SPIKE PREDICTION: " + symbol + " " + (direction == 1 ? "BUY" : "SELL") + " Probabilité: " + DoubleToString(probability * 100, 1) + "%";
        SendCustomNotification(message);
    }
}'''
        
        # Ajouter la fonction avant la fonction ExecuteTrade
        contenu_fixed = contenu_fixed.replace('//+------------------------------------------------------------------+\n//| Exécuter le trade basé sur la confluence', fonction_start_spike_prediction + '\n//+------------------------------------------------------------------+\n//| Exécuter le trade basé sur la confluence')
        
        # 6. Améliorer la fonction ExecuteTrade pour la prédiction de spike
        print("Amelioration de la fonction ExecuteTrade pour la prediction de spike...")
        
        nouvelle_fonction_execute_trade = '''
//+------------------------------------------------------------------+
//| Exécuter le trade basé sur la confluence et prédiction de spike  |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, int direction)
{
    // Vérifier le cooldown
    if(TimeCurrent() - g_lastTradeTime < InpMinSecondsBetweenOrders) return;
    if(symbol == g_lastSameSymbol && TimeCurrent() - g_lastSameSymbolTradeTime < InpMinSecondsBetweenSameSymbol) return;
    
    // Vérifier si c'est une prédiction de spike
    bool isSpikePrediction = g_spikePredictionActive && g_spikePredictionSymbol == symbol && g_spikePredictionDirection == direction;
    
    // Calculer la taille de lot
    double lotSize = CalculateLotSize(symbol);
    
    // Calculer SL et TP
    double sl = 0.0, tp = 0.0;
    
    if(isSpikePrediction)
    {
        // Utiliser les niveaux de la prédiction de spike
        sl = g_spikePredictionStopLoss;
        tp = g_spikePredictionTakeProfit;
        
        if(InpDebug)
        {
            Print("EXECUTION SPIKE PREDICTION: ", symbol, " Direction: ", direction, " SL: ", DoubleToString(sl, 5), " TP: ", DoubleToString(tp, 5));
        }
    }
    else
    {
        // Utiliser les niveaux par défaut
        double currentPrice = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
        
        if(InpUseFallbackPercentSLTP)
        {
            sl = currentPrice * (1.0 - InpSLPercent / 100.0 * direction);
            tp = currentPrice * (1.0 + InpTPPercent / 100.0 * direction);
        }
        else
        {
            sl = currentPrice - spread * 2 * direction;
            tp = currentPrice + spread * 3 * direction;
        }
    }
    
    // Exécuter le trade
    bool result = false;
    if(direction == 1) // Achat
    {
        result = trade.Buy(lotSize, symbol, 0, sl, tp, "AngelOfSpike BUY" + (isSpikePrediction ? " SPIKE" : ""));
    }
    else if(direction == -1) // Vente
    {
        result = trade.Sell(lotSize, symbol, 0, sl, tp, "AngelOfSpike SELL" + (isSpikePrediction ? " SPIKE" : ""));
    }
    
    if(result)
    {
        g_lastTradeTime = TimeCurrent();
        g_lastSameSymbolTradeTime = TimeCurrent();
        g_lastSameSymbol = symbol;
        
        // Marquer la prédiction comme exécutée
        if(isSpikePrediction)
        {
            g_spikePredictionExecuted = true;
            if(InpDebug) Print("SPIKE PREDICTION EXECUTEE: ", symbol, " Direction: ", direction);
        }
        
        if(InpDebug) Print("Trade execute: ", (direction == 1 ? "BUY" : "SELL"), " ", DoubleToString(lotSize), " ", symbol);
        
        if(InpSendNotifications)
        {
            string message = InpNotifyTag + ": Trade " + (direction == 1 ? "BUY" : "SELL") + " " + symbol + (isSpikePrediction ? " (SPIKE PREDICTION)" : "");
            SendCustomNotification(message);
        }
    }
    else
    {
        if(InpDebug) Print("Erreur execution trade: ", IntegerToString(trade.ResultRetcode()));
    }
}'''
        
        # Remplacer l'ancienne fonction
        contenu_fixed = re.sub(r'void ExecuteTrade\(string symbol, int direction\)\s*\{[^}]*\}', nouvelle_fonction_execute_trade, contenu_fixed, flags=re.DOTALL)
        
        # 7. Ajouter la fonction de vérification des prédictions de spike
        print("Ajout de la fonction de verification des predictions de spike...")
        
        fonction_check_spike_prediction = '''
//+------------------------------------------------------------------+
//| Vérifier les prédictions de spike                               |
//+------------------------------------------------------------------+
void CheckSpikePrediction()
{
    if(!g_spikePredictionActive) return;
    
    // Vérifier si la prédiction a expiré (5 minutes)
    if(TimeCurrent() - g_spikePredictionTime > 300) // 5 minutes
    {
        if(InpDebug) Print("SPIKE PREDICTION EXPIREE: ", g_spikePredictionSymbol);
        g_spikePredictionActive = false;
        return;
    }
    
    // Vérifier si la prédiction a été exécutée
    if(g_spikePredictionExecuted)
    {
        // Vérifier si le trade est toujours ouvert
        bool positionOpen = false;
        CPositionInfo pos;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(pos.SelectByIndex(i))
            {
                if(pos.Magic() == InpMagicNumber && pos.Symbol() == g_spikePredictionSymbol)
                {
                    positionOpen = true;
                    break;
                }
            }
        }
        
        if(!positionOpen)
        {
            // Le trade a été fermé, réinitialiser la prédiction
            g_spikePredictionActive = false;
            if(InpDebug) Print("SPIKE PREDICTION TERMINEE: ", g_spikePredictionSymbol);
        }
    }
}'''
        
        # Ajouter la fonction avant la fonction UpdateHUD
        contenu_fixed = contenu_fixed.replace('//+------------------------------------------------------------------+\n//| Mettre à jour le HUD', fonction_check_spike_prediction + '\n//+------------------------------------------------------------------+\n//| Mettre à jour le HUD')
        
        # 8. Modifier la fonction OnTick pour inclure la vérification des prédictions
        print("Modification de la fonction OnTick pour inclure la verification des predictions...")
        
        nouvelle_fonction_ontick = '''
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérifier les prédictions de spike
    CheckSpikePrediction();
    
    // Logique principale AngelOfSpike
    ProcessAngelOfSpikeLogic();
    
    // Mise à jour de l'affichage Boom si activé
    if(InpEnableBoomDisplay)
    {
        if(TimeCurrent() - g_lastBoomUpdateTime >= InpBoomUpdateInterval)
        {
            UpdateBoomDisplay();
            g_lastBoomUpdateTime = TimeCurrent();
        }
    }
    
    // Mise à jour du HUD
    if(InpShowHUD)
    {
        UpdateHUD();
    }
}'''
        
        # Remplacer l'ancienne fonction OnTick
        contenu_fixed = re.sub(r'void OnTick\(\)\s*\{[^}]*\}', nouvelle_fonction_ontick, contenu_fixed, flags=re.DOTALL)
        
        # 9. Améliorer la fonction UpdateHUD pour afficher les informations de prédiction
        print("Amelioration de la fonction UpdateHUD pour afficher les informations de prediction...")
        
        nouvelle_fonction_update_hud = '''
//+------------------------------------------------------------------+
//| Mettre à jour le HUD                                             |
//+------------------------------------------------------------------+
void UpdateHUD()
{
    // Créer ou mettre à jour le HUD
    string hudText = StringFormat(
        "AngelOfSpike v2.01\\n" +
        "Trading: %s\\n" +
        "Symboles: %d/%d\\n" +
        "Perte Totale: $%.2f\\n" +
        "Dernier Trade: %s\\n" +
        "Boom Display: %s\\n" +
        "API: %s\\n" +
        "Symbole: %s\\n" +
        "%s",
        InpEnableTrading ? "ACTIF" : "INACTIF",
        g_concurrentSymbols,
        InpMaxConcurrentSymbols,
        g_totalOpenLossUSD,
        g_lastSameSymbol == "" ? "Aucun" : g_lastSameSymbol,
        InpEnableBoomDisplay ? "ACTIF" : "INACTIF",
        InpBoomApiUrl,
        InpBoomSymbol,
        TimeToString(TimeCurrent(), TIME_MINUTES)
    );
    
    // Ajouter les informations de prédiction de spike
    if(g_spikePredictionActive)
    {
        hudText += StringFormat(
            "\\n--- SPIKE PREDICTION ---\\n" +
            "Symbole: %s\\n" +
            "Direction: %s\\n" +
            "Probabilité: %.1f%%\\n" +
            "Temps restant: %ds\\n" +
            "Entry: %.5f\\n" +
            "SL: %.5f\\n" +
            "TP: %.5f\\n" +
            "Statut: %s",
            g_spikePredictionSymbol,
            g_spikePredictionDirection == 1 ? "BUY" : "SELL",
            g_spikePredictionProbability * 100,
            300 - (int)(TimeCurrent() - g_spikePredictionTime),
            g_spikePredictionEntryPrice,
            g_spikePredictionStopLoss,
            g_spikePredictionTakeProfit,
            g_spikePredictionExecuted ? "EXECUTE" : "EN ATTENTE"
        );
    }
    
    // Créer l'objet HUD s'il n'existe pas
    if(ObjectFind(0, "AngelOfSpikeHUD") < 0)
    {
        ObjectCreate(0, "AngelOfSpikeHUD", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_XDISTANCE, InpHUDX);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_YDISTANCE, InpHUDY);
        ObjectSetString(0, "AngelOfSpikeHUD", OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_COLOR, InpHUDColor);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_BACK, false);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_ZORDER, 500);
    }
    
    // Mettre à jour le texte
    ObjectSetString(0, "AngelOfSpikeHUD", OBJPROP_TEXT, hudText);
}'''
        
        # Remplacer l'ancienne fonction UpdateHUD
        contenu_fixed = re.sub(r'void UpdateHUD\(\)\s*\{[^}]*\}', nouvelle_fonction_update_hud, contenu_fixed, flags=re.DOTALL)
        
        # 10. Modifier la fonction OnDeinit pour libérer les indicateurs
        print("Modification de la fonction OnDeinit pour liberer les indicateurs...")
        
        nouvelle_fonction_ondeinit = '''
//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Arret AngelOfSpike avec Boom Display");
    
    // Arrêter le timer
    EventKillTimer();
    
    // Libérer les indicateurs
    ReleaseIndicators();
    
    // Supprimer l'affichage Boom
    if(InpEnableBoomDisplay)
    {
        RemoveBoomDisplay();
    }
    
    Print("AngelOfSpike avec Boom Display arrete");
}'''
        
        # Remplacer l'ancienne fonction OnDeinit
        contenu_fixed = re.sub(r'void OnDeinit\(const int reason\)\s*\{[^}]*\}', nouvelle_fonction_ondeinit, contenu_fixed, flags=re.DOTALL)
        
        # Sauvegarder le fichier intégré
        with open(fichier_fixed, 'w', encoding='utf-8') as f:
            f.write(contenu_fixed)
        
        print(f"Fichier {fichier_fixed} integre avec succes!")
        
        # Vérification finale
        print("Verification finale...")
        
        # Vérifier que les corrections ont été appliquées
        if 'AnalyzeSpikePrediction' in contenu_fixed:
            print("OK: Fonction AnalyzeSpikePrediction ajoutee")
        else:
            print("MANQUANT: Fonction AnalyzeSpikePrediction")
        
        if 'StartSpikePrediction' in contenu_fixed:
            print("OK: Fonction StartSpikePrediction ajoutee")
        else:
            print("MANQUANT: Fonction StartSpikePrediction")
        
        if 'CheckSpikePrediction' in contenu_fixed:
            print("OK: Fonction CheckSpikePrediction ajoutee")
        else:
            print("MANQUANT: Fonction CheckSpikePrediction")
        
        if 'InitializeIndicators' in contenu_fixed:
            print("OK: Fonction InitializeIndicators ajoutee")
        else:
            print("MANQUANT: Fonction InitializeIndicators")
        
        if 'ReleaseIndicators' in contenu_fixed:
            print("OK: Fonction ReleaseIndicators ajoutee")
        else:
            print("MANQUANT: Fonction ReleaseIndicators")
        
        print("\\n=== INTEGRATION TERMINEE ===")
        print("Le fichier AngelOfSpike_Fixed.mq5 a ete integre avec:")
        print("1. Fonctionnalites des indicateurs du fichier original")
        print("2. Prediction de spike avant l'arrivee du spike")
        print("3. Analyse de confluence amelioree")
        print("4. Gestion intelligente des positions")
        print("5. Affichage des informations de prediction")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de l'integration: {e}")
        return False

if __name__ == "__main__":
    integrer_indicateurs_spike_prediction()
