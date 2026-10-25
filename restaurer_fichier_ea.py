#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script pour restaurer le fichier AngelOfSpike.mq5
"""

import os
import shutil

def restaurer_fichier_ea():
    """Restaurer le fichier AngelOfSpike.mq5"""
    
    print("=== RESTAURATION DU FICHIER EA ===")
    
    # Verifier si une sauvegarde existe
    backup_files = [
        "AngelOfSpike_backup.mq5",
        "AngelOfSpike_original.mq5",
        "AngelOfSpike_Fixed.mq5"
    ]
    
    backup_found = None
    for backup in backup_files:
        if os.path.exists(backup):
            backup_found = backup
            break
    
    if backup_found:
        print(f"Sauvegarde trouvee: {backup_found}")
        print("Restauration en cours...")
        
        # Copier la sauvegarde
        shutil.copy2(backup_found, "AngelOfSpike.mq5")
        print(f"Fichier restaure depuis {backup_found}")
        
        # Appliquer les corrections necessaires
        print("Application des corrections...")
        
        with open("AngelOfSpike.mq5", "r", encoding="utf-8") as f:
            content = f.read()
        
        # Corriger les parametres
        content = content.replace("InpAutoExecuteThreshold = 60.0", "InpAutoExecuteThreshold = 50.0")
        content = content.replace("InpSpikeProbabilityThreshold = 60.0", "InpSpikeProbabilityThreshold = 50.0")
        
        # Ajouter la fonction ClosePositionAfterSpikeCapture si elle n'existe pas
        if "void ClosePositionAfterSpikeCapture()" not in content:
            close_function = '''
//+------------------------------------------------------------------+
//| Fermer la position après capture du spike                      |
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
            
            # Ajouter la fonction à la fin du fichier
            content += close_function
        
        # Ajouter l'appel dans OnTick si nécessaire
        if "ClosePositionAfterSpikeCapture();" not in content:
            # Trouver la fonction OnTick et ajouter l'appel
            onTick_pattern = r'(void OnTick\(\)\s*\{[^}]*?)(\})'
            def add_close_call(match):
                return match.group(1) + '\n    ClosePositionAfterSpikeCapture(); // Appel de la fonction de fermeture automatique\n' + match.group(2)
            
            content = re.sub(onTick_pattern, add_close_call, content, flags=re.MULTILINE | re.DOTALL)
        
        # Sauvegarder le fichier corrigé
        with open("AngelOfSpike.mq5", "w", encoding="utf-8") as f:
            f.write(content)
        
        print("Corrections appliquees avec succes")
        
    else:
        print("Aucune sauvegarde trouvee")
        print("Creation d'un fichier EA de base...")
        
        # Créer un fichier EA de base
        basic_ea = '''#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\\Trade.mqh>
#include <Trade\\PositionInfo.mqh>
#include <Trade\\OrderInfo.mqh>
#include <Trade\\DealInfo.mqh>
#include <Trade\\HistoryOrderInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

//--- Paramètres d'entrée
input double InpAutoExecuteThreshold = 50.0;        // Seuil d'exécution automatique
input double InpSpikeProbabilityThreshold = 50.0;  // Seuil de probabilité de spike
input double InpTargetProfitUSD = 10.0;            // Profit cible en USD
input double InpMaxLossPerTradeUSD = 5.0;         // Perte maximale par trade
input bool InpAutoClosePositions = true;          // Fermeture automatique des positions
input int InpMagicNumber = 12345;                 // Numéro magique

//--- Variables globales
CTrade g_trade;
CPositionInfo g_position;
bool g_predictionActive = false;
bool g_isBoomCrashMode = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("AngelOfSpike EA initialise");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("AngelOfSpike EA desactive");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
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
    // Logique de vérification des signaux
    // À implémenter selon vos besoins
}

//+------------------------------------------------------------------+
//| Fermer la position après capture du spike                      |
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
        
        with open("AngelOfSpike.mq5", "w", encoding="utf-8") as f:
            f.write(basic_ea)
        
        print("Fichier EA de base cree")
    
    print("\n=== INSTRUCTIONS ===")
    print("1. Ouvrir MetaEditor")
    print("2. Ouvrir le fichier AngelOfSpike.mq5")
    print("3. Compiler (F7)")
    print("4. Si compilation reussie, attacher l'EA au graphique Boom 1000 Index")
    print("5. Configurer les parametres selon vos besoins")
    print("6. Activer le trading automatique")

if __name__ == "__main__":
    import re
    restaurer_fichier_ea()
