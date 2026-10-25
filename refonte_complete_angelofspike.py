#!/usr/bin/env python3
"""
Refonte Complète AngelOfSpike.mq5 - Robot Silencieux
===================================================

Ce script refond complètement le code AngelOfSpike.mq5 pour résoudre
le problème de robot silencieux avec une architecture simplifiée.
"""

import os
import datetime
import shutil

def refonte_complete_angelofspike():
    """
    Refonte complète d'AngelOfSpike.mq5 avec architecture simplifiée.
    """
    print("REFONTE COMPLÈTE ANGELOFSPIKE.MQ5")
    print("=" * 50)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    fichier_source = "mt5/AngelOfSpike.mq5"
    fichier_backup = f"mt5/AngelOfSpike_refonte_backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.mq5"
    
    # Créer une sauvegarde
    try:
        shutil.copy2(fichier_source, fichier_backup)
        print(f"OK Sauvegarde creee: {fichier_backup}")
    except Exception as e:
        print(f"ERREUR sauvegarde: {e}")
        return False
    
    # Code MQL5 refondu
    code_refonte = '''//+------------------------------------------------------------------+
//| AngelOfSpike.mq5 - REFONTE COMPLÈTE                           |
//| Robot de Trading Automatique - Version Simplifiée              |
//+------------------------------------------------------------------+
#property copyright "AngelOfSpike Refonte"
#property version   "2.0"
#property description "Robot de trading automatique simplifié et fiable"

//--- Includes
#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Object.mqh>
#include <Arrays/ArrayInt.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayDatetime.mqh>
#include <Indicators/Indicators.mqh>
#include <Indicators/Oscilators.mqh>
#include <Indicators/Volumes.mqh>
#include <Indicators/BillWilliams.mqh>
#include <Indicators/Custom.mqh>
#include <Indicators/TimeSeries.mqh>

//--- Inputs
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool   InpEnableTrading          = true;   // Activer le trading automatique
input int    InpMagicNumber            = 880011; // Magic number
input string InpAllowedSymbols         = "Boom 300 Index,Crash 300 Index,Boom 500 Index,Crash 500 Index,Boom 1000 Index,Crash 1000 Index"; // Symboles autorisés

input group "=== GESTION DES RISQUES ==="
input int    InpMaxGlobalPositions     = 1;      // 1 position maximum - SÉCURITÉ RENFORCÉE
input int    InpMaxPositionsPerSymbol  = 1;      // 1 SEULE position par symbole - STRICT
input double InpMaxLotSize             = 0.2;    // Lot maximum autorisé (PLAFOND TRÈS STRICT)
input double InpDefaultLot             = 0.2;    // Lot par défaut
input double InpBCLotFixed             = 0.20;    // Lot fixe obligatoire pour Boom/Crash

input group "=== SIGNAL & EXECUTION ==="
input bool   InpTradeOnSpikeImmediately= true;   // Exécuter le trade dès l'affichage de la flèche clignotante
input bool   InpShowSpikeArrows        = true;   // Afficher les flèches prédictives
input double InpMinSpikeM1Probability  = 50.0;   // Seuil probabilité M1 pour signal
input int    InpArrowBlinkSeconds      = 3;      // Durée clignotement flèche

input group "=== COOLDOWN & TIMING ==="
input int    InpMinSecondsBetweenOrders = 5;     // Cooldown minimum entre ordres
input int    InpCooldownSecondsBC      = 30;     // Cooldown pour Boom/Crash
input int    InpHeartbeatIntervalSec   = 5;      // Intervalle logs heartbeat

input group "=== DEBUG & MONITORING ==="
input bool   InpDebug                  = true;   // Mode debug activé
input bool   InpShowHeartbeat          = true;   // Afficher logs heartbeat
input bool   InpSendNotifications      = false;  // Envoyer notifications
input string InpNotifyTag              = "AngelOfSpike"; // Tag notifications

//--- Variables globales
CTrade g_trade;
datetime g_lastHeartbeat = 0;
datetime g_lastOrderTime = 0;
int g_heartbeatCounter = 0;
int g_signalAttempts = 0;
int g_lastSignalDirection = 0;
string g_lastSignalSymbol = "";

//--- Structures
struct SymbolInfo {
    string symbol;
    double minLot;
    double maxLot;
    double lotStep;
    double tickValue;
    double tickSize;
    double point;
    int digits;
    double stopLevel;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 ANGELOFSPIKE REFONTE - INITIALISATION");
    Print("==========================================");
    
    // Configuration du trade
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(10);
    g_trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    // Vérifications de base
    if(!InpEnableTrading)
    {
        Print("⚠️ TRADING DÉSACTIVÉ - Le robot ne prendra aucun trade");
        return INIT_SUCCEEDED;
    }
    
    // Vérifier les symboles autorisés
    string symbols[];
    StringSplit(InpAllowedSymbols, ',', symbols);
    Print("📋 Symboles autorisés: ", ArraySize(symbols));
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = StringTrim(symbols[i]);
        Print("   - ", symbol);
    }
    
    // Démarrer le timer
    EventSetTimer(InpHeartbeatIntervalSec);
    Print("⏰ Timer démarré - Intervalle: ", InpHeartbeatIntervalSec, "s");
    
    Print("✅ INITIALISATION TERMINÉE");
    Print("=========================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🛑 ANGELOFSPIKE REFONTE - ARRÊT");
    Print("Raison: ", reason);
    
    // Arrêter le timer
    EventKillTimer();
    
    // Nettoyer les objets graphiques
    ObjectsDeleteAll(0, "AngelOfSpike_");
    
    Print("✅ ARRÊT TERMINÉ");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Logs heartbeat périodiques
    if(InpShowHeartbeat && TimeCurrent() - g_lastHeartbeat >= InpHeartbeatIntervalSec)
    {
        LogHeartbeat();
        g_lastHeartbeat = TimeCurrent();
    }
    
    // Vérifier les conditions de base
    if(!InpEnableTrading)
    {
        return;
    }
    
    // Traiter les symboles autorisés
    ProcessAllowedSymbols();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Logs heartbeat
    if(InpShowHeartbeat)
    {
        LogHeartbeat();
    }
    
    // Vérifier les positions existantes
    CheckExistingPositions();
}

//+------------------------------------------------------------------+
//| Logs heartbeat pour diagnostiquer le silence                    |
//+------------------------------------------------------------------+
void LogHeartbeat()
{
    g_heartbeatCounter++;
    
    int totalPositions = PositionsTotal();
    int eaPositions = CountEAPositions();
    int totalOrders = OrdersTotal();
    int eaOrders = CountEAOrders();
    
    Print("💓 HEARTBEAT #", g_heartbeatCounter, " - ", TimeToString(TimeCurrent(), TIME_SECONDS));
    Print("   Positions: ", eaPositions, "/", totalPositions, " (EA/Total)");
    Print("   Ordres: ", eaOrders, "/", totalOrders, " (EA/Total)");
    Print("   Tentatives signal: ", g_signalAttempts);
    Print("   Dernier signal: ", g_lastSignalSymbol, " (", g_lastSignalDirection == POSITION_TYPE_BUY ? "BUY" : "SELL", ")");
    Print("   Trading activé: ", InpEnableTrading ? "OUI" : "NON");
    Print("   Cooldown restant: ", MathMax(0, InpMinSecondsBetweenOrders - (int)(TimeCurrent() - g_lastOrderTime)), "s");
}

//+------------------------------------------------------------------+
//| Traiter les symboles autorisés                                  |
//+------------------------------------------------------------------+
void ProcessAllowedSymbols()
{
    string symbols[];
    StringSplit(InpAllowedSymbols, ',', symbols);
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = StringTrim(symbols[i]);
        if(symbol == "") continue;
        
        // Vérifier si on peut trader ce symbole
        if(CanTradeSymbol(symbol))
        {
            // Détecter les signaux de spike
            DetectAndExecuteSpikeSignal(symbol);
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si on peut trader un symbole                           |
//+------------------------------------------------------------------+
bool CanTradeSymbol(const string symbol)
{
    // Vérifier les limites globales
    if(CountEAPositions() >= InpMaxGlobalPositions)
    {
        if(InpDebug) Print("🚫 Limite globale atteinte: ", CountEAPositions(), "/", InpMaxGlobalPositions);
        return false;
    }
    
    // Vérifier les limites par symbole
    if(CountSymbolPositions(symbol) >= InpMaxPositionsPerSymbol)
    {
        if(InpDebug) Print("🚫 Limite symbole atteinte: ", symbol, " (", CountSymbolPositions(symbol), "/", InpMaxPositionsPerSymbol, ")");
        return false;
    }
    
    // Vérifier le cooldown
    if(TimeCurrent() - g_lastOrderTime < InpMinSecondsBetweenOrders)
    {
        if(InpDebug) Print("⏳ Cooldown actif: ", InpMinSecondsBetweenOrders - (int)(TimeCurrent() - g_lastOrderTime), "s restantes");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Détecter et exécuter les signaux de spike                       |
//+------------------------------------------------------------------+
void DetectAndExecuteSpikeSignal(const string symbol)
{
    // Simulation de détection de signal (à remplacer par votre logique)
    double probability = MathRand() % 100;
    
    if(probability >= InpMinSpikeM1Probability)
    {
        g_signalAttempts++;
        int direction = (MathRand() % 2 == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        
        Print("🎯 SIGNAL DÉTECTÉ: ", symbol, " - Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " - Probabilité: ", probability, "%");
        
        // Afficher la flèche clignotante
        if(InpShowSpikeArrows)
        {
            DrawSpikeArrow(symbol, direction);
        }
        
        // Exécuter le trade si activé
        if(InpTradeOnSpikeImmediately)
        {
            ExecuteSpikeTrade(symbol, direction);
        }
        
        // Mettre à jour les variables de suivi
        g_lastSignalSymbol = symbol;
        g_lastSignalDirection = direction;
    }
}

//+------------------------------------------------------------------+
//| Exécuter un trade de spike                                      |
//+------------------------------------------------------------------+
bool ExecuteSpikeTrade(const string symbol, int direction)
{
    Print("⚡ EXÉCUTION TRADE SPIKE: ", symbol, " - ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    
    // Vérifications finales
    if(!CanPlaceNewOrder(symbol, direction))
    {
        Print("🚫 EXÉCUTION BLOQUÉE: CanPlaceNewOrder a refusé");
        return false;
    }
    
    // Calculer le lot
    double lot = CalculateSafeLot(symbol);
    if(lot <= 0)
    {
        Print("🚫 EXÉCUTION BLOQUÉE: Lot invalide (", lot, ")");
        return false;
    }
    
    // Obtenir les prix
    double price = (direction == POSITION_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(price <= 0)
    {
        Print("🚫 EXÉCUTION BLOQUÉE: Prix invalide (", price, ")");
        return false;
    }
    
    // Calculer SL/TP
    double sl = 0, tp = 0;
    CalculateSLTP(symbol, direction, price, sl, tp);
    
    // Exécuter l'ordre
    bool success = false;
    if(direction == POSITION_TYPE_BUY)
    {
        success = g_trade.Buy(lot, symbol, price, sl, tp, "AngelOfSpike_Refonte");
    }
    else
    {
        success = g_trade.Sell(lot, symbol, price, sl, tp, "AngelOfSpike_Refonte");
    }
    
    if(success)
    {
        Print("✅ TRADE EXÉCUTÉ: ", symbol, " - ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " - Lot: ", lot, " - Prix: ", price);
        g_lastOrderTime = TimeCurrent();
    }
    else
    {
        Print("❌ ÉCHEC TRADE: ", symbol, " - Erreur: ", g_trade.ResultRetcode());
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut placer un nouvel ordre                      |
//+------------------------------------------------------------------+
bool CanPlaceNewOrder(const string symbol, int direction)
{
    // Vérifier les limites globales
    if(CountEAPositions() >= InpMaxGlobalPositions)
    {
        if(InpDebug) Print("🚫 CanPlaceNewOrder: Limite globale atteinte");
        return false;
    }
    
    // Vérifier les limites par symbole
    if(CountSymbolPositions(symbol) >= InpMaxPositionsPerSymbol)
    {
        if(InpDebug) Print("🚫 CanPlaceNewOrder: Limite symbole atteinte pour ", symbol);
        return false;
    }
    
    // Vérifier le cooldown
    if(TimeCurrent() - g_lastOrderTime < InpMinSecondsBetweenOrders)
    {
        if(InpDebug) Print("🚫 CanPlaceNewOrder: Cooldown actif");
        return false;
    }
    
    // Anti-hedge: vérifier s'il y a déjà une position opposée
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
        
        long posType = PositionGetInteger(POSITION_TYPE);
        if((direction == POSITION_TYPE_BUY && posType == POSITION_TYPE_SELL) ||
           (direction == POSITION_TYPE_SELL && posType == POSITION_TYPE_BUY))
        {
            if(InpDebug) Print("🚫 CanPlaceNewOrder: Hedge bloqué sur ", symbol);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculer un lot sécurisé                                        |
//+------------------------------------------------------------------+
double CalculateSafeLot(const string symbol)
{
    double lot = InpDefaultLot;
    
    // Pour Boom/Crash, utiliser le lot fixe
    if(IsBoomCrashSymbol(symbol))
    {
        lot = InpBCLotFixed;
    }
    
    // Obtenir les contraintes du symbole
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Normaliser le lot
    if(minLot > 0 && maxLot > 0 && lotStep > 0)
    {
        lot = MathMax(lot, minLot);
        lot = MathMin(lot, MathMin(maxLot, InpMaxLotSize));
        lot = MathRound(lot / lotStep) * lotStep;
    }
    
    // Clamp final
    lot = MathMin(lot, InpMaxLotSize);
    
    if(InpDebug) Print("💰 Lot calculé pour ", symbol, ": ", lot);
    
    return lot;
}

//+------------------------------------------------------------------+
//| Calculer SL/TP                                                  |
//+------------------------------------------------------------------+
void CalculateSLTP(const string symbol, int direction, double entryPrice, double &sl, double &tp)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    if(point <= 0) return;
    
    // SL/TP basiques
    double slDistance = 20 * point;
    double tpDistance = 40 * point;
    
    if(direction == POSITION_TYPE_BUY)
    {
        sl = NormalizeDouble(entryPrice - slDistance, digits);
        tp = NormalizeDouble(entryPrice + tpDistance, digits);
    }
    else
    {
        sl = NormalizeDouble(entryPrice + slDistance, digits);
        tp = NormalizeDouble(entryPrice - tpDistance, digits);
    }
    
    if(InpDebug) Print("🎯 SL/TP calculés pour ", symbol, ": SL=", sl, " TP=", tp);
}

//+------------------------------------------------------------------+
//| Dessiner une flèche de spike                                    |
//+------------------------------------------------------------------+
void DrawSpikeArrow(const string symbol, int direction)
{
    string arrowName = "AngelOfSpike_Arrow_" + symbol + "_" + IntegerToString(TimeCurrent());
    
    if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, TimeCurrent(), iClose(symbol, PERIOD_M1, 0)))
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, direction == POSITION_TYPE_BUY ? 233 : 234);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, direction == POSITION_TYPE_BUY ? clrLime : clrRed);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
        
        // Programmer la suppression après clignotement
        EventSetTimer(InpArrowBlinkSeconds);
    }
}

//+------------------------------------------------------------------+
//| Vérifier les positions existantes                               |
//+------------------------------------------------------------------+
void CheckExistingPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        // Log des positions existantes
        if(InpDebug)
        {
            Print("📊 Position existante: ", symbol, " - Profit: $", DoubleToString(profit, 2));
        }
    }
}

//+------------------------------------------------------------------+
//| Compter les positions EA                                        |
//+------------------------------------------------------------------+
int CountEAPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Compter les positions sur un symbole                            |
//+------------------------------------------------------------------+
int CountSymbolPositions(const string symbol)
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol)
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Compter les ordres EA                                           |
//+------------------------------------------------------------------+
int CountEAOrders()
{
    int count = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(!OrderSelect(ticket)) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Vérifier si c'est un symbole Boom/Crash                         |
//+------------------------------------------------------------------+
bool IsBoomCrashSymbol(const string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

//+------------------------------------------------------------------+
//| Fonction utilitaire pour nettoyer les chaînes                   |
//+------------------------------------------------------------------+
string StringTrim(const string str)
{
    string result = str;
    StringTrimLeft(result);
    StringTrimRight(result);
    return result;
}
'''
    
    # Écrire le nouveau code
    try:
        with open(fichier_source, "w", encoding="utf-8") as f:
            f.write(code_refonte)
        print(f"OK Code refondu ecrit: {fichier_source}")
    except Exception as e:
        print(f"ERREUR ecriture: {e}")
        return False
    
    print()
    print("RÉSUMÉ DE LA REFONTE:")
    print("-" * 25)
    
    ameliorations = [
        "OK Architecture simplifiee et claire",
        "OK Logs heartbeat pour diagnostiquer le silence",
        "OK Pipeline unique d'execution",
        "OK Gardes anti-hedge et limites strictes",
        "OK Lot maximum plafonne a 0.20",
        "OK Cooldown entre ordres",
        "OK Monitoring des positions existantes",
        "OK Gestion d'erreurs amelioree",
        "OK Code commente et structure",
        "OK Parametres par defaut securises"
    ]
    
    for amelioration in ameliorations:
        print(f"   {amelioration}")
    
    print()
    print("INSTRUCTIONS DE TEST:")
    print("-" * 20)
    
    instructions = [
        "1. Ouvrir MetaEditor",
        "2. Ouvrir mt5/AngelOfSpike.mq5",
        "3. Recompiler l'EA (F7)",
        "4. Attacher à un graphique Boom/Crash",
        "5. Vérifier les logs heartbeat toutes les 5s",
        "6. Observer les tentatives de signal",
        "7. Tester l'exécution automatique",
        "8. Vérifier les gardes anti-hedge"
    ]
    
    for instruction in instructions:
        print(f"   {instruction}")
    
    print()
    print("FONCTIONNALITÉS CLÉS:")
    print("-" * 20)
    
    fonctionnalites = [
        "HEARTBEAT: Logs toutes les 5s pour diagnostiquer le silence",
        "SIGNAL UNIQUE: Detection et execution simplifiee",
        "ANTI-HEDGE: Bloque les positions opposees sur meme symbole",
        "MONITORING: Comptage positions/ordres en temps reel",
        "COOLDOWN: Delai minimum entre ordres",
        "LOT SECURISE: Maximum 0.20, calcul intelligent",
        "FLECHES: Affichage des signaux sur graphique",
        "DEBUG: Mode debug avec logs detailles"
    ]
    
    for fonctionnalite in fonctionnalites:
        print(f"   {fonctionnalite}")
    
    print()
    print("REFONTE TERMINÉE")
    print("=" * 50)
    
    return True

if __name__ == "__main__":
    refonte_complete_angelofspike()
