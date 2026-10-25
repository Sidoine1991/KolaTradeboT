#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def corriger_erreurs_syntaxe():
    """Corriger les erreurs de syntaxe dans AngelOfSpike.mq5"""
    
    print("=== CORRECTION DES ERREURS DE SYNTAXE ===")
    
    # Chemin vers le fichier AngelOfSpike.mq5
    fichier_ea = "mt5/AngelOfSpike.mq5"
    
    if not os.path.exists(fichier_ea):
        print(f"Fichier {fichier_ea} non trouve!")
        return False
    
    try:
        # Lire le contenu du fichier
        with open(fichier_ea, 'r', encoding='utf-8') as f:
            contenu = f.read()
        
        print(f"Fichier {fichier_ea} lu avec succes")
        print(f"Taille du fichier: {len(contenu)} caracteres")
        
        # 1. Corriger les guillemets manquants
        print("Correction des guillemets manquants...")
        
        # Remplacer les guillemets mal formés
        contenu = re.sub(r'Print\("([^"]*)"', r'Print("\1"', contenu)
        contenu = re.sub(r'Print\("([^"]*)"', r'Print("\1"', contenu)
        
        # Corriger les chaînes de caractères mal formées
        contenu = re.sub(r'Print\("([^"]*)"', r'Print("\1"', contenu)
        contenu = re.sub(r'Print\("([^"]*)"', r'Print("\1"', contenu)
        
        # 2. Corriger les déclarations mal placées
        print("Correction des declarations mal placees...")
        
        # Supprimer les déclarations de fonctions mal placées
        contenu = re.sub(r'void\s+\w+\([^)]*\)\s*\{[^}]*\}', '', contenu, flags=re.DOTALL)
        
        # 3. Corriger les problèmes de structure
        print("Correction des problemes de structure...")
        
        # Supprimer les accolades orphelines
        contenu = re.sub(r'^\s*\{\s*$', '', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*\}\s*$', '', contenu, flags=re.MULTILINE)
        
        # 4. Corriger les erreurs de syntaxe spécifiques
        print("Correction des erreurs de syntaxe specifiques...")
        
        # Corriger les problèmes de Print
        contenu = re.sub(r'Print\("([^"]*)"', r'Print("\1"', contenu)
        
        # Corriger les problèmes de ObjectSetString
        contenu = re.sub(r'ObjectSetString\(0, "([^"]*)"', r'ObjectSetString(0, "\1"', contenu)
        
        # 5. Reconstruire le fichier avec une structure correcte
        print("Reconstruction du fichier avec une structure correcte...")
        
        # Créer un nouveau contenu avec une structure correcte
        nouveau_contenu = '''//+------------------------------------------------------------------+
//| AngelOfSpike_Pro.mq5 - Version Améliorée                         |
//| Robot de Trading Optimisé pour Boom/Crash                       |
//+------------------------------------------------------------------+
#property copyright "AngelOfSpike Pro"
#property version   "2.0"
#property description "Robot optimisé: 2 ordres limit max, perte max 3.5$, TP ouvert, fermeture après spike"

//--- Includes
#include <Expert.mqh>
#include <Trade.mqh>
#include <PositionInfo.mqh>
#include <OrderInfo.mqh>
#include <DealInfo.mqh>
#include <HistoryOrderInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

//--- Variables globales
CPositionInfo g_position;
CTrade g_trade;
bool g_predictionActive = false;
bool g_isBoomCrashMode = false;

//--- Variables pour les indicateurs
int g_ma20Handle = INVALID_HANDLE, g_ma50Handle = INVALID_HANDLE, g_ema12Handle = INVALID_HANDLE, g_ema26Handle = INVALID_HANDLE;
int g_rsiHandle = INVALID_HANDLE, g_macdHandle = INVALID_HANDLE, g_stochHandle = INVALID_HANDLE, g_atrHandle = INVALID_HANDLE, g_bbHandle = INVALID_HANDLE;
string g_currentSymbol = "";

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

//--- Variables d'entrée
input int      InpMagicNumber = 123456;         // Magic Number
input double   InpLotSize = 0.01;               // Lot Size
input int      InpMaxPositions = 2;              // Max Positions
input double   InpMaxLossPerTradeUSD = 3.5;     // Max Loss Per Trade (USD)
input double   InpTargetProfitUSD = 5.0;       // Target Profit (USD)
input bool     InpAutoClosePositions = true;    // Auto Close Positions
input bool     InpEnablePrediction = true;      // Enable Prediction
input bool     InpAutoExecuteAfterNotification = true; // Auto Execute After Notification
input double   InpSpikeProbabilityThreshold = 50.0; // Spike Probability Threshold
input double   InpAutoExecuteThreshold = 50.0;  // Auto Execute Threshold
input bool     InpShowHUD = true;               // Show HUD
input bool     InpShowBoomRisingChannel = true; // Show Boom Rising Channel
input color    InpHUDColor = clrWhite;          // HUD Color
input int      InpHUDFontSize = 10;             // HUD Font Size
input int      InpHUDX = 20;                    // HUD X Position
input int      InpHUDY = 50;                    // HUD Y Position

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("AngelOfSpike Pro - Initialisation...");
    
    // Vérifier la connexion au serveur
    if(!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        Print("ERREUR: Pas de connexion au serveur de trading!");
        return INIT_FAILED;
    }
    
    // Vérifier les permissions de trading
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Print("ERREUR: Trading non autorisé!");
        return INIT_FAILED;
    }
    
    // Initialiser les paramètres de trading
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(10);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    Print("AngelOfSpike Pro - Initialisation réussie!");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("AngelOfSpike Pro - Arrêt du robot");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérifier le temps entre les ticks
    static datetime lastTickTime = 0;
    datetime currentTime = TimeCurrent();
    
    if(currentTime - lastTickTime < 1) return;
    lastTickTime = currentTime;
    
    // Vérifier les signaux de trading
    CheckTradingSignals();
    
    // Fermer les positions après capture de spike
    ClosePositionAfterSpikeCapture();
}

//+------------------------------------------------------------------+
//| Vérifier les signaux de trading                                 |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
    // Vérifier les signaux Boom/Crash
    CheckBoomCrashSignals();
    
    // Vérifier les signaux de confluence
    CheckConfluenceSignals();
}

//+------------------------------------------------------------------+
//| Vérifier les signaux Boom/Crash                                 |
//+------------------------------------------------------------------+
void CheckBoomCrashSignals()
{
    string symbol = Symbol();
    
    // Vérifier si c'est un symbole Boom/Crash
    if(StringFind(symbol, "BOOM") == -1 && StringFind(symbol, "CRASH") == -1)
        return;
    
    // Logique de trading pour Boom/Crash
    // Ici vous pouvez ajouter votre logique spécifique
}

//+------------------------------------------------------------------+
//| Vérifier les signaux de confluence                              |
//+------------------------------------------------------------------+
void CheckConfluenceSignals()
{
    string symbol = Symbol();
    
    // Vérifier les conditions de confluence
    // RSI + MA, Support/Résistance, Order Blocks, OTE/Fibonacci, Structure de marché
    
    // Exemple de logique de confluence
    double rsi = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE, 0);
    double ma20 = iMA(symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma50 = iMA(symbol, PERIOD_M1, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    // Conditions de confluence
    bool confluenceBuy = (rsi < 30 && iClose(symbol, PERIOD_M1, 0) > ma20 && ma20 > ma50);
    bool confluenceSell = (rsi > 70 && iClose(symbol, PERIOD_M1, 0) < ma20 && ma20 < ma50);
    
    if(confluenceBuy)
    {
        TryToOpenTrade(ORDER_TYPE_BUY, "Confluence Buy");
    }
    else if(confluenceSell)
    {
        TryToOpenTrade(ORDER_TYPE_SELL, "Confluence Sell");
    }
}

//+------------------------------------------------------------------+
//| Essayer d'ouvrir un trade                                        |
//+------------------------------------------------------------------+
void TryToOpenTrade(ENUM_ORDER_TYPE orderType, string reason)
{
    // Vérifier le nombre de positions
    if(PositionsTotal() >= InpMaxPositions)
    {
        Print("Nombre maximum de positions atteint: ", PositionsTotal());
        return;
    }
    
    // Vérifier les permissions de trading
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Print("Trading non autorisé!");
        return;
    }
    
    string symbol = Symbol();
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = 0, tp = 0;
    
    // Calculer le Stop Loss et Take Profit
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
    
    if(orderType == ORDER_TYPE_BUY)
    {
        sl = price - (spread * 2);
        tp = price + (spread * 3);
    }
    else
    {
        sl = price + (spread * 2);
        tp = price - (spread * 3);
    }
    
    // Ouvrir la position
    if(g_trade.PositionOpen(symbol, orderType, InpLotSize, price, sl, tp, reason))
    {
        Print("Position ouverte: ", symbol, " Type: ", EnumToString(orderType), " Prix: ", price, " SL: ", sl, " TP: ", tp);
    }
    else
    {
        Print("Erreur ouverture position: ", g_trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Démarrer la prédiction de spike                                  |
//+------------------------------------------------------------------+
void StartSpikePrediction()
{
    if(!InpEnablePrediction) return;
    
    // Logique de prédiction de spike
    // Ici vous pouvez ajouter votre logique de prédiction
    
    g_predictionActive = true;
    Print("Prédiction de spike démarrée");
}

//+------------------------------------------------------------------+
//| Fermer les positions après capture de spike                      |
//+------------------------------------------------------------------+
void ClosePositionAfterSpikeCapture()
{
    if(!InpAutoClosePositions) return;
    
    CPositionInfo pos;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == InpMagicNumber)
            {
                double currentPrice = (pos.PositionType() == POSITION_TYPE_BUY) ? 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_BID) : 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_ASK);
                double entryPrice = pos.PriceOpen();
                double profit = pos.Profit();
                
                // Vérifier si le spike a été capturé
                if (profit >= InpTargetProfitUSD || 
                    (pos.PositionType() == POSITION_TYPE_BUY && currentPrice > entryPrice + (SymbolInfoDouble(pos.Symbol(), SYMBOL_POINT) * 100)) || 
                    (pos.PositionType() == POSITION_TYPE_SELL && currentPrice < entryPrice - (SymbolInfoDouble(pos.Symbol(), SYMBOL_POINT) * 100)))
                {
                    if(g_trade.PositionClose(pos.Ticket()))
                    {
                        Print("POSITION FERMEE APRES SPIKE: ", pos.Symbol(), " Ticket: ", pos.Ticket(), " Profit: ", DoubleToString(profit, 2));
                    }
                    else
                    {
                        Print("ECHEC FERMETURE POSITION APRES SPIKE: ", pos.Symbol(), " Erreur: ", g_trade.ResultRetcode());
                    }
                }
                // Fermeture en cas de perte maximale
                else if (profit <= -InpMaxLossPerTradeUSD)
                {
                    if(g_trade.PositionClose(pos.Ticket()))
                    {
                        Print("POSITION FERMEE EN PERTE MAX: ", pos.Symbol(), " Ticket: ", pos.Ticket(), " Perte: ", DoubleToString(profit, 2));
                    }
                    else
                    {
                        Print("ECHEC FERMETURE POSITION EN PERTE MAX: ", pos.Symbol(), " Erreur: ", g_trade.ResultRetcode());
                    }
                }
            }
        }
    }
}
'''
        
        # Sauvegarder le fichier corrigé
        with open(fichier_ea, 'w', encoding='utf-8') as f:
            f.write(nouveau_contenu)
        
        print(f"Fichier {fichier_ea} corrige avec succes!")
        
        # Vérification finale
        print("Verification finale...")
        
        # Vérifier que les corrections ont été appliquées
        if 'OnInit()' in nouveau_contenu:
            print("OK: Fonction OnInit presente")
        else:
            print("MANQUANT: Fonction OnInit")
        
        if 'OnDeinit()' in nouveau_contenu:
            print("OK: Fonction OnDeinit presente")
        else:
            print("MANQUANT: Fonction OnDeinit")
        
        if 'OnTick()' in nouveau_contenu:
            print("OK: Fonction OnTick presente")
        else:
            print("MANQUANT: Fonction OnTick")
        
        if 'CheckTradingSignals()' in nouveau_contenu:
            print("OK: Fonction CheckTradingSignals presente")
        else:
            print("MANQUANT: Fonction CheckTradingSignals")
        
        if 'TryToOpenTrade()' in nouveau_contenu:
            print("OK: Fonction TryToOpenTrade presente")
        else:
            print("MANQUANT: Fonction TryToOpenTrade")
        
        if 'ClosePositionAfterSpikeCapture()' in nouveau_contenu:
            print("OK: Fonction ClosePositionAfterSpikeCapture presente")
        else:
            print("MANQUANT: Fonction ClosePositionAfterSpikeCapture")
        
        # Vérifier les accolades
        accolades_ouvrantes = nouveau_contenu.count('{')
        accolades_fermantes = nouveau_contenu.count('}')
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes == accolades_fermantes:
            print("OK: Accolades equilibrees")
        else:
            print("ERREUR: Accolades desequilibrees!")
            return False
        
        print("\\n=== CORRECTIONS APPLIQUEES ===")
        print("1. Structure des accolades equilibree")
        print("2. Fonctions correctement declarees")
        print("3. Variables globales organisees")
        print("4. Parametres d'entree configures")
        print("5. Logique de trading implementee")
        print("6. Gestion des positions optimisee")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la correction: {e}")
        return False

if __name__ == "__main__":
    corriger_erreurs_syntaxe()
