#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Diagnostic AngelOfSpike - Problemes graphiques et trading
"""

import os
import re

def diagnose_angelofspike():
    """Diagnostiquer les problemes du robot AngelOfSpike"""
    
    print("DIAGNOSTIC ANGELOFSPIKE - PROBLEMES GRAPHIQUES ET TRADING")
    print("=" * 65)
    
    mq5_file = "mt5/AngelOfSpike.mq5"
    if not os.path.exists(mq5_file):
        print("ERREUR: Fichier AngelOfSpike.mq5 non trouve")
        return False
    
    with open(mq5_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("\nPROBLEMES IDENTIFIES:")
    print("-" * 25)
    
    problems = []
    
    # 1. Probleme avec iRealVolume
    if "iRealVolume" in content:
        problems.append("ERREUR: iRealVolume() n'existe pas en MQL5")
        print("ERREUR: iRealVolume() n'existe pas en MQL5")
    else:
        print("OK: Pas d'utilisation de iRealVolume")
    
    # 2. Probleme avec Point()
    if "Point()" in content:
        problems.append("ERREUR: Point() peut causer des problemes")
        print("ERREUR: Point() peut causer des problemes")
    else:
        print("OK: Pas d'utilisation de Point()")
    
    # 3. Verification des fonctions critiques
    critical_functions = [
        "ScanOrderBlocks",
        "IsBullishOrderBlock", 
        "IsBearishOrderBlock",
        "DrawOrderBlock",
        "AnalyzeTechnicalConditions"
    ]
    
    print("\nVERIFICATION DES FONCTIONS CRITIQUES:")
    print("-" * 40)
    
    for func in critical_functions:
        if func in content:
            print(f"OK: {func}")
        else:
            problems.append(f"ERREUR: Fonction {func} manquante")
            print(f"ERREUR: Fonction {func} manquante")
    
    # 4. Verification des parametres critiques
    critical_params = [
        "InpEnableOrderBlocks",
        "InpShowOrderBlocks",
        "InpEnableTrading",
        "InpDebug"
    ]
    
    print("\nVERIFICATION DES PARAMETRES:")
    print("-" * 30)
    
    for param in critical_params:
        if param in content:
            print(f"OK: {param}")
        else:
            problems.append(f"ERREUR: Parametre {param} manquant")
            print(f"ERREUR: Parametre {param} manquant")
    
    # 5. Verification des includes
    print("\nVERIFICATION DES INCLUDES:")
    print("-" * 25)
    
    required_includes = [
        "#include <Trade/Trade.mqh>",
        "#include <Object.mqh>",
        "#include <Indicators/Indicators.mqh>"
    ]
    
    for include in required_includes:
        if include in content:
            print(f"OK: {include}")
        else:
            problems.append(f"ERREUR: Include manquant {include}")
            print(f"ERREUR: Include manquant {include}")
    
    # Resume
    print("\n" + "=" * 65)
    if problems:
        print(f"ERREURS TROUVEES: {len(problems)}")
        for i, problem in enumerate(problems, 1):
            print(f"{i}. {problem}")
        
        print("\nCORRECTIONS NECESSAIRES:")
        print("-" * 25)
        print("1. Remplacer iRealVolume() par iVolume()")
        print("2. Remplacer Point() par SymbolInfoDouble(symbol, SYMBOL_POINT)")
        print("3. Verifier la compilation dans MetaTrader 5")
        print("4. Verifier les parametres dans l'EA")
        
        return False
    else:
        print("SUCCES: Aucun probleme majeur detecte")
        print("\nVERIFICATIONS SUPPLEMENTAIRES:")
        print("-" * 30)
        print("1. Verifiez que l'EA est compile sans erreurs")
        print("2. Verifiez que les parametres sont correctement configures")
        print("3. Verifiez que le symbole est dans la liste autorisee")
        print("4. Verifiez les logs dans l'onglet Experts")
        
        return True

def show_troubleshooting_guide():
    """Afficher le guide de depannage"""
    
    print("\nGUIDE DE DEPANNAGE:")
    print("=" * 25)
    
    print("\n1. ROBOT NE REAGIT PAS:")
    print("- Verifiez InpEnableTrading = true")
    print("- Verifiez InpEnableOrderBlocks = true")
    print("- Verifiez que le symbole est autorise")
    print("- Verifiez les logs dans l'onglet Experts")
    
    print("\n2. RIEN N'APPARAIT SUR LE GRAPHIQUE:")
    print("- Verifiez InpShowOrderBlocks = true")
    print("- Verifiez InpShowSpikeArrows = true")
    print("- Verifiez InpDebug = true pour les logs")
    print("- Redemarrez l'EA")
    
    print("\n3. TRADING AUTOMATIQUE NE MARCHE PAS:")
    print("- Verifiez InpEnableTrading = true")
    print("- Verifiez InpTradeOnSpikeImmediately = true")
    print("- Verifiez les limites de positions")
    print("- Verifiez le cooldown entre ordres")
    
    print("\n4. INDICATEURS TECHNIQUES N'APPARAISSENT PAS:")
    print("- Verifiez InpShowOrderBlocks = true")
    print("- Verifiez InpOrderBlockLookback = 50")
    print("- Verifiez InpOrderBlockMinVolume = 1.5")
    print("- Verifiez que le symbole a des donnees de volume")

if __name__ == "__main__":
    success = diagnose_angelofspike()
    
    if not success:
        show_troubleshooting_guide()
        
        print("\nCORRECTIONS AUTOMATIQUES DISPONIBLES:")
        print("-" * 40)
        print("1. Correction de iRealVolume() -> iVolume()")
        print("2. Correction de Point() -> SymbolInfoDouble()")
        print("3. Verification de la compilation")
        print("4. Test des parametres")
        
        print("\nVoulez-vous que je corrige automatiquement ces problemes?")
    else:
        print("\nLe robot semble correct. Verifiez la configuration dans MetaTrader 5.")
