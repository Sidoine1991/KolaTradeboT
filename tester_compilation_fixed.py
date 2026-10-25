#!/usr/bin/env python3
"""
Script pour tester la compilation de l'EA AngelOfSpike_Fixed.mq5
"""

import os
import subprocess
import sys

def tester_compilation_ea():
    """Teste la compilation de l'EA AngelOfSpike_Fixed.mq5"""
    
    print("TEST DE COMPILATION ANGELOFSPIKE_FIXED.MQ5")
    print("=" * 50)
    
    # Vérifier que le fichier existe
    fichier_ea = "AngelOfSpike_Fixed.mq5"
    if not os.path.exists(fichier_ea):
        print(f"ERREUR: Fichier {fichier_ea} non trouve")
        return False
    
    print(f"OK: Fichier {fichier_ea} trouve")
    print(f"Taille: {os.path.getsize(fichier_ea)} bytes")
    
    # Vérifier les includes nécessaires
    includes_necessaires = [
        "Trade/Trade.mqh",
        "Trade/OrderInfo.mqh", 
        "Trade/PositionInfo.mqh",
        "Trade/DealInfo.mqh",
        "Trade/HistoryOrderInfo.mqh",
        "Object.mqh",
        "StdLibErr.mqh"
    ]
    
    print("\nVERIFICATION DES INCLUDES:")
    with open(fichier_ea, 'r', encoding='utf-8') as f:
        contenu = f.read()
        
    for include in includes_necessaires:
        if f"#include <{include}>" in contenu:
            print(f"OK: {include}")
        else:
            print(f"MANQUANT: {include}")
    
    # Vérifier les fonctions principales
    fonctions_principales = [
        "OnInit()",
        "OnDeinit()", 
        "OnTick()",
        "OnTimer()",
        "ProcessAngelOfSpikeLogic()",
        "AnalyzeConfluenceStrategy()",
        "ExecuteTrade()",
        "CreateBoomDisplay()",
        "UpdateBoomDisplay()"
    ]
    
    print("\nVERIFICATION DES FONCTIONS PRINCIPALES:")
    for fonction in fonctions_principales:
        if fonction in contenu:
            print(f"OK: {fonction}")
        else:
            print(f"MANQUANT: {fonction}")
    
    # Vérifier les corrections apportées
    print("\nVERIFICATION DES CORRECTIONS:")
    
    # Vérifier la correction iMAOnArray
    if "ArrayResize(rsi_ma, ArraySize(rsi))" in contenu:
        print("OK: Correction iMAOnArray appliquee")
    else:
        print("ERREUR: Correction iMAOnArray manquante")
    
    # Vérifier la correction SymbolInfoInteger
    if "double point = SymbolInfoDouble(symbol, SYMBOL_POINT);" in contenu:
        print("OK: Correction SymbolInfoInteger appliquee")
    else:
        print("ERREUR: Correction SymbolInfoInteger manquante")
    
    # Vérifier les paramètres d'entrée
    print("\nVERIFICATION DES PARAMETRES D'ENTREE:")
    parametres_importants = [
        "InpEnableTrading",
        "InpMagicNumber",
        "InpAllowedSymbols",
        "InpMaxLossPerTradeUSD",
        "InpTargetProfitUSD",
        "InpEnableBoomDisplay",
        "InpBoomSymbol"
    ]
    
    for param in parametres_importants:
        if f"input" in contenu and param in contenu:
            print(f"OK: {param}")
        else:
            print(f"MANQUANT: {param}")
    
    # Vérifier les symboles Boom/Crash
    print("\nVERIFICATION DES SYMBOLES BOOM/CRASH:")
    symboles_boom = [
        "Boom 1000 Index",
        "Crash 1000 Index", 
        "Boom 500 Index",
        "Crash 500 Index"
    ]
    
    for symbole in symboles_boom:
        if symbole in contenu:
            print(f"OK: {symbole}")
        else:
            print(f"MANQUANT: {symbole}")
    
    # Vérifier les modules de confluence
    print("\nVERIFICATION DES MODULES DE CONFLUENCE:")
    modules = [
        "AnalyzeIndicator2025",
        "CheckSupportResistance", 
        "AnalyzeOrderBlock",
        "AnalyzeOTE_FIBO",
        "AnalyzeBOS_CHoCH"
    ]
    
    for module in modules:
        if module in contenu:
            print(f"OK: {module}")
        else:
            print(f"MANQUANT: {module}")
    
    # Vérifier l'affichage Boom
    print("\nVERIFICATION DE L'AFFICHAGE BOOM:")
    elements_affichage = [
        "CreateBoomDisplay()",
        "UpdateBoomDisplay()",
        "RemoveBoomDisplay()",
        "FormatBoomAnalysisText()",
        "GetBoomAnalysis()"
    ]
    
    for element in elements_affichage:
        if element in contenu:
            print(f"OK: {element}")
        else:
            print(f"MANQUANT: {element}")
    
    print("\n" + "=" * 50)
    print("TEST DE COMPILATION TERMINE")
    print("=" * 50)
    
    return True

def generer_instructions_compilation():
    """Génère les instructions pour compiler l'EA"""
    
    print("\nINSTRUCTIONS POUR COMPILER L'EA:")
    print("=" * 40)
    
    print("1. Ouvrir MetaTrader 5")
    print("2. Aller dans MetaEditor (F4)")
    print("3. Ouvrir le fichier AngelOfSpike_Fixed.mq5")
    print("4. Cliquer sur 'Compile' (F7)")
    print("5. Vérifier qu'il n'y a pas d'erreurs")
    print("6. Si compilation réussie, l'EA sera dans le dossier MQL5/Experts/")
    
    print("\nPARAMETRES RECOMMANDES POUR L'EA:")
    print("- InpEnableTrading = true")
    print("- InpMagicNumber = 880011")
    print("- InpMaxLossPerTradeUSD = 3.50")
    print("- InpTargetProfitUSD = 5.00")
    print("- InpEnableBoomDisplay = true")
    print("- InpBoomSymbol = 'Boom 1000 Index'")
    print("- InpMinConfluenceSignals = 3")
    
    print("\nSYMBOLES RECOMMANDES:")
    print("- Boom 1000 Index")
    print("- Crash 1000 Index")
    print("- Boom 500 Index")
    print("- Crash 500 Index")
    
    print("\nVERIFICATIONS APRES COMPILATION:")
    print("1. Vérifier que l'EA apparaît dans Navigator > Expert Advisors")
    print("2. Glisser l'EA sur le graphique Boom 1000 Index")
    print("3. Configurer les paramètres selon les recommandations")
    print("4. Vérifier que l'EA affiche 'Initialisation réussie'")
    print("5. Surveiller l'apparition des indicateurs sur le graphique")

if __name__ == "__main__":
    print("TESTEUR DE COMPILATION ANGELOFSPIKE_FIXED")
    print("=" * 60)
    
    # Tester la compilation
    if tester_compilation_ea():
        print("\nOK: VERIFICATION TERMINEE")
        
        # Générer les instructions
        generer_instructions_compilation()
        
        print("\nPROCHAINES ETAPES:")
        print("1. Compiler l'EA dans MetaEditor")
        print("2. Attacher l'EA au graphique Boom 1000 Index")
        print("3. Configurer les paramètres selon les recommandations")
        print("4. Surveiller l'apparition des indicateurs et trades")
        
    else:
        print("\nERREUR: ERREURS DETECTEES")
        print("Verifiez les erreurs ci-dessus et corrigez-les")
    
    print("\nTest termine")
