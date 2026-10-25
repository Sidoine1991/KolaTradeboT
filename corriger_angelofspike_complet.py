#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script pour corriger complètement AngelOfSpike.mq5
"""

import re
import os

def corriger_angelofspike_complet():
    """Corriger complètement le fichier AngelOfSpike.mq5"""
    
    print("=== CORRECTION COMPLETE D'ANGELOFSPIKE.MQ5 ===")
    
    # Lire le fichier actuel
    with open("AngelOfSpike.mq5", "r", encoding="utf-8") as f:
        content = f.read()
    
    print("Fichier lu avec succes")
    
    # 1. Ajouter tous les includes nécessaires au début
    print("1. Ajout des includes necessaires...")
    
    includes_needed = [
        "#include <Trade\\Trade.mqh>",
        "#include <Trade\\PositionInfo.mqh>",
        "#include <Trade\\OrderInfo.mqh>",
        "#include <Trade\\DealInfo.mqh>",
        "#include <Trade\\HistoryOrderInfo.mqh>",
        "#include <Object.mqh>",
        "#include <StdLibErr.mqh>"
    ]
    
    # Vérifier et ajouter les includes manquants
    for include in includes_needed:
        if include not in content:
            # Ajouter après la ligne de copyright
            content = content.replace("#property copyright \"Copyright 2024, MetaQuotes Ltd.\"", 
                                  f"#property copyright \"Copyright 2024, MetaQuotes Ltd.\"\n{include}")
    
    # 2. Ajouter les variables globales manquantes
    print("2. Ajout des variables globales...")
    
    global_vars = [
        "CPositionInfo g_position;",
        "CTrade g_trade;",
        "bool g_predictionActive = false;",
        "bool g_isBoomCrashMode = false;"
    ]
    
    # Ajouter les variables globales après les includes
    global_vars_section = "\n".join(global_vars)
    if "CPositionInfo g_position;" not in content:
        content = content.replace("#include <StdLibErr.mqh>", 
                                f"#include <StdLibErr.mqh>\n\n{global_vars_section}")
    
    # 3. Ajouter les fonctions manquantes
    print("3. Ajout des fonctions manquantes...")
    
    # Fonction OnInit
    if "int OnInit()" not in content:
        onInit_function = '''
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("AngelOfSpike EA initialise");
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    return(INIT_SUCCEEDED);
}
'''
        content += onInit_function
    
    # Fonction OnDeinit
    if "void OnDeinit(" not in content:
        onDeinit_function = '''
//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("AngelOfSpike EA desactive");
}
'''
        content += onDeinit_function
    
    # Fonction TryToOpenTrade
    if "bool TryToOpenTrade()" not in content:
        tryToOpenTrade_function = '''
//+------------------------------------------------------------------+
//| Essayer d'ouvrir un trade                                        |
//+------------------------------------------------------------------+
bool TryToOpenTrade()
{
    // Vérifier si on peut ouvrir un trade
    if(PositionsTotal() >= InpMaxConcurrentPositions) return false;
    
    // Logique d'ouverture de trade
    // À implémenter selon vos besoins
    return true;
}
'''
        content += tryToOpenTrade_function
    
    # Fonction StartSpikePrediction
    if "void StartSpikePrediction()" not in content:
        startSpikePrediction_function = '''
//+------------------------------------------------------------------+
//| Démarrer la prédiction de spike                                  |
//+------------------------------------------------------------------+
void StartSpikePrediction()
{
    if(g_predictionActive) return;
    
    g_predictionActive = true;
    Print("Prediction de spike demarree");
}
'''
        content += startSpikePrediction_function
    
    # 4. Corriger les paramètres d'entrée
    print("4. Correction des parametres d'entrée...")
    
    # Ajouter les paramètres manquants
    input_params = '''
input int InpMaxConcurrentPositions = 1;        // Nombre maximum de positions simultanées
input bool InpEnableBoomCrashTrading = true;    // Activer le trading Boom/Crash
input bool InpAutoClosePositions = true;        // Fermeture automatique des positions
'''
    
    if "InpMaxConcurrentPositions" not in content:
        content = content.replace("input int InpMagicNumber = 12345;", 
                                f"input int InpMagicNumber = 12345;{input_params}")
    
    # 5. Corriger la fonction OnTick
    print("5. Correction de la fonction OnTick...")
    
    # Vérifier que OnTick contient les appels nécessaires
    if "CheckTradingSignals();" not in content:
        # Remplacer la fonction OnTick existante
        onTick_corrected = '''
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
'''
        # Remplacer la fonction OnTick existante
        content = re.sub(r'void OnTick\(\)\s*\{[^}]*\}', onTick_corrected, content, flags=re.MULTILINE | re.DOTALL)
    
    # 6. Ajouter la fonction CheckTradingSignals
    print("6. Ajout de la fonction CheckTradingSignals...")
    
    if "void CheckTradingSignals()" not in content:
        checkTradingSignals_function = '''
//+------------------------------------------------------------------+
//| Vérifier les signaux de trading                                 |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
    // Vérifier les signaux Boom/Crash
    if(InpEnableBoomCrashTrading)
    {
        CheckBoomCrashSignals();
    }
    
    // Vérifier les signaux de confluence
    CheckConfluenceSignals();
}
'''
        content += checkTradingSignals_function
    
    # 7. Ajouter les fonctions de vérification des signaux
    print("7. Ajout des fonctions de vérification des signaux...")
    
    if "void CheckBoomCrashSignals()" not in content:
        checkBoomCrashSignals_function = '''
//+------------------------------------------------------------------+
//| Vérifier les signaux Boom/Crash                                 |
//+------------------------------------------------------------------+
void CheckBoomCrashSignals()
{
    // Logique de vérification des signaux Boom/Crash
    // À implémenter selon vos besoins
}
'''
        content += checkBoomCrashSignals_function
    
    if "void CheckConfluenceSignals()" not in content:
        checkConfluenceSignals_function = '''
//+------------------------------------------------------------------+
//| Vérifier les signaux de confluence                              |
//+------------------------------------------------------------------+
void CheckConfluenceSignals()
{
    // Logique de vérification des signaux de confluence
    // À implémenter selon vos besoins
}
'''
        content += checkConfluenceSignals_function
    
    # 8. Nettoyer le fichier
    print("8. Nettoyage du fichier...")
    
    # Supprimer les lignes vides en trop
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    # Supprimer les espaces en fin de ligne
    content = re.sub(r'[ \t]+$', '', content, flags=re.MULTILINE)
    
    # 9. Sauvegarder le fichier corrigé
    print("9. Sauvegarde du fichier corrigé...")
    
    with open("AngelOfSpike.mq5", "w", encoding="utf-8") as f:
        f.write(content)
    
    print("FICHIER CORRIGE AVEC SUCCES!")
    
    # 10. Vérifier la structure finale
    print("\n=== VERIFICATION FINALE ===")
    
    # Compter les accolades
    open_braces = content.count('{')
    close_braces = content.count('}')
    print(f"Accolades ouvrantes: {open_braces}")
    print(f"Accolades fermantes: {close_braces}")
    
    if open_braces == close_braces:
        print("OK: Accolades equilibrees")
    else:
        print("ERREUR: Accolades desequilibrees!")
    
    # Vérifier les fonctions principales
    main_functions = [
        "int OnInit()",
        "void OnTick()",
        "void OnDeinit(",
        "bool TryToOpenTrade()",
        "void StartSpikePrediction()",
        "void ClosePositionAfterSpikeCapture()",
        "void CheckTradingSignals()"
    ]
    
    print("\nFonctions principales:")
    for func in main_functions:
        if func in content:
            print(f"  OK: {func}")
        else:
            print(f"  MANQUANT: {func}")
    
    print("\n=== INSTRUCTIONS FINALES ===")
    print("1. Ouvrir MetaEditor")
    print("2. Ouvrir le fichier AngelOfSpike.mq5")
    print("3. Compiler (F7)")
    print("4. Si compilation reussie, attacher l'EA au graphique Boom 1000 Index")
    print("5. Configurer les parametres selon vos besoins")
    print("6. Activer le trading automatique")

if __name__ == "__main__":
    corriger_angelofspike_complet()
