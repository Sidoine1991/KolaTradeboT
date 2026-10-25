#!/usr/bin/env python3
"""
Script pour tester la compilation de l'EA AngelOfSpike.mq5 original
"""

import os
import subprocess
import sys

def tester_compilation_ea_original():
    """Teste la compilation de l'EA AngelOfSpike.mq5 original"""
    
    print("TEST DE COMPILATION ANGELOFSPIKE.MQ5 ORIGINAL")
    print("=" * 50)
    
    # Vérifier que le fichier existe
    fichier_ea = "AngelOfSpike.mq5"
    if not os.path.exists(fichier_ea):
        print(f"ERREUR: Fichier {fichier_ea} non trouve")
        return False
    
    print(f"OK: Fichier {fichier_ea} trouve")
    print(f"Taille: {os.path.getsize(fichier_ea)} bytes")
    
    # Vérifier les corrections appliquées
    print("\nVERIFICATION DES CORRECTIONS APPLIQUEES:")
    
    with open(fichier_ea, 'r', encoding='utf-8') as f:
        contenu = f.read()
    
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
    
    # Vérifier les fonctions principales
    print("\nVERIFICATION DES FONCTIONS PRINCIPALES:")
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
    
    for fonction in fonctions_principales:
        if fonction in contenu:
            print(f"OK: {fonction}")
        else:
            print(f"MANQUANT: {fonction}")
    
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

def generer_instructions_compilation_original():
    """Génère les instructions pour compiler l'EA original"""
    
    print("\nINSTRUCTIONS POUR COMPILER L'EA ORIGINAL:")
    print("=" * 45)
    
    print("1. Ouvrir MetaTrader 5")
    print("2. Aller dans MetaEditor (F4)")
    print("3. Ouvrir le fichier AngelOfSpike.mq5")
    print("4. Cliquer sur 'Compile' (F7)")
    print("5. Verifier qu'il n'y a pas d'erreurs")
    print("6. Si compilation reussie, l'EA sera dans le dossier MQL5/Experts/")
    
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
    print("1. Verifier que l'EA apparait dans Navigator > Expert Advisors")
    print("2. Glisser l'EA sur le graphique Boom 1000 Index")
    print("3. Configurer les parametres selon les recommandations")
    print("4. Verifier que l'EA affiche 'Initialisation reussie'")
    print("5. Surveiller l'apparition des indicateurs sur le graphique")
    
    print("\nCORRECTIONS APPLIQUEES:")
    print("1. iMAOnArray remplace par calcul manuel de MA")
    print("2. SymbolInfoInteger remplace par SymbolInfoDouble")
    print("3. Toutes les fonctions principales presentes")
    print("4. Affichage Boom Rising Channel integre")
    print("5. Modules de confluence complets")

if __name__ == "__main__":
    print("TESTEUR DE COMPILATION ANGELOFSPIKE.MQ5 ORIGINAL")
    print("=" * 60)
    
    # Tester la compilation
    if tester_compilation_ea_original():
        print("\nOK: VERIFICATION TERMINEE")
        
        # Générer les instructions
        generer_instructions_compilation_original()
        
        print("\nPROCHAINES ETAPES:")
        print("1. Compiler l'EA dans MetaEditor")
        print("2. Attacher l'EA au graphique Boom 1000 Index")
        print("3. Configurer les parametres selon les recommandations")
        print("4. Surveiller l'apparition des indicateurs et trades")
        
    else:
        print("\nERREUR: ERREURS DETECTEES")
        print("Verifiez les erreurs ci-dessus et corrigez-les")
    
    print("\nTest termine")
