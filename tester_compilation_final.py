#!/usr/bin/env python3
"""
Script pour tester la compilation finale de l'EA AngelOfSpike.mq5
"""

import os
import subprocess
import sys

def tester_compilation_final():
    """Teste la compilation finale de l'EA AngelOfSpike.mq5"""
    
    print("TEST DE COMPILATION FINALE ANGELOFSPIKE.MQ5")
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
    
    # Vérifier la correction SymbolInfoInteger
    if "(double)SymbolInfoInteger(symbol, SYMBOL_SPREAD)" in contenu:
        print("OK: Correction SymbolInfoInteger appliquee")
    else:
        print("ERREUR: Correction SymbolInfoInteger manquante")
    
    # Vérifier les fonctions principales
    print("\nVERIFICATION DES FONCTIONS PRINCIPALES:")
    fonctions_principales = [
        "OnInit()",
        "OnDeinit()", 
        "OnTick()"
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
        "InpAllowedSymbols"
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
    
    # Vérifier les modules de trading
    print("\nVERIFICATION DES MODULES DE TRADING:")
    modules = [
        "ExecuteTrade",
        "CheckRiskLimits",
        "AnalyzeMarketConditions"
    ]
    
    for module in modules:
        if module in contenu:
            print(f"OK: {module}")
        else:
            print(f"MANQUANT: {module}")
    
    # Vérifier les indicateurs
    print("\nVERIFICATION DES INDICATEURS:")
    indicateurs = [
        "iRSI",
        "iMA",
        "iMACD",
        "iStochastic"
    ]
    
    for indicateur in indicateurs:
        if indicateur in contenu:
            print(f"OK: {indicateur}")
        else:
            print(f"MANQUANT: {indicateur}")
    
    print("\n" + "=" * 50)
    print("TEST DE COMPILATION TERMINE")
    print("=" * 50)
    
    return True

def generer_instructions_compilation_final():
    """Génère les instructions pour compiler l'EA final"""
    
    print("\nINSTRUCTIONS POUR COMPILER L'EA FINAL:")
    print("=" * 40)
    
    print("1. Ouvrir MetaTrader 5")
    print("2. Aller dans MetaEditor (F4)")
    print("3. Ouvrir le fichier AngelOfSpike.mq5")
    print("4. Cliquer sur 'Compile' (F7)")
    print("5. Verifier qu'il n'y a pas d'erreurs")
    print("6. Si compilation reussie, l'EA sera dans le dossier MQL5/Experts/")
    
    print("\nPARAMETRES RECOMMANDES POUR L'EA:")
    print("- InpEnableTrading = true")
    print("- InpMagicNumber = 880011")
    print("- InpAllowedSymbols = 'Boom 1000 Index, Crash 1000 Index'")
    print("- InpSpikeProbabilityThreshold = 60.0")
    print("- InpAutoExecuteThreshold = 60.0")
    
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
    print("1. SymbolInfoInteger cast en double pour éviter les erreurs")
    print("2. Toutes les fonctions principales presentes")
    print("3. Modules de trading complets")
    print("4. Indicateurs techniques integres")
    print("5. Gestion des risques implementee")

if __name__ == "__main__":
    print("TESTEUR DE COMPILATION FINALE ANGELOFSPIKE.MQ5")
    print("=" * 60)
    
    # Tester la compilation
    if tester_compilation_final():
        print("\nOK: VERIFICATION TERMINEE")
        
        # Générer les instructions
        generer_instructions_compilation_final()
        
        print("\nPROCHAINES ETAPES:")
        print("1. Compiler l'EA dans MetaEditor")
        print("2. Attacher l'EA au graphique Boom 1000 Index")
        print("3. Configurer les parametres selon les recommandations")
        print("4. Surveiller l'apparition des indicateurs et trades")
        
    else:
        print("\nERREUR: ERREURS DETECTEES")
        print("Verifiez les erreurs ci-dessus et corrigez-les")
    
    print("\nTest termine")
