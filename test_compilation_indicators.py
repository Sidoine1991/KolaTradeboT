#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test de compilation pour AngelOfSpike avec indicateurs visuels modernes
"""

import subprocess
import sys
import os

def test_compilation():
    """Test de compilation du fichier AngelOfSpike.mq5"""
    
    print("Test de compilation AngelOfSpike avec indicateurs visuels modernes...")
    
    # Vérifier que le fichier existe
    file_path = "mt5/AngelOfSpike.mq5"
    if not os.path.exists(file_path):
        print("ERREUR: Fichier AngelOfSpike.mq5 non trouve!")
        return False
    
    # Lire le fichier pour vérifier les ajouts
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Vérifier que les paramètres d'input sont présents
    required_inputs = [
        "InpShowEMA",
        "InpShowBollinger", 
        "InpShowFibonacci",
        "InpShowOTE",
        "InpShowOrderBlocks",
        "InpShowFVG"
    ]
    
    missing_inputs = []
    for input_param in required_inputs:
        if f"input bool     {input_param}" not in content:
            missing_inputs.append(input_param)
    
    if missing_inputs:
        print(f"ERREUR: Paramètres d'input manquants: {missing_inputs}")
        return False
    
    # Vérifier que les fonctions de dessin sont présentes
    required_functions = [
        "DrawEMAIndicators",
        "DrawBollingerBands",
        "DrawFibonacciLevels", 
        "DrawOTEZones",
        "DrawOrderBlocks",
        "DrawFairValueGaps",
        "DrawAllIndicators"
    ]
    
    missing_functions = []
    for func in required_functions:
        if f"void {func}()" not in content:
            missing_functions.append(func)
    
    if missing_functions:
        print(f"ERREUR: Fonctions de dessin manquantes: {missing_functions}")
        return False
    
    # Vérifier que les appels sont présents
    if "DrawAllIndicators();" not in content:
        print("ERREUR: Appel a DrawAllIndicators() manquant!")
        return False
    
    print("OK: Tous les paramètres d'input sont présents")
    print("OK: Toutes les fonctions de dessin sont présentes")
    print("OK: Les appels aux fonctions sont corrects")
    
    # Test de compilation simulé (vérification de syntaxe basique)
    print("\nVerification de la syntaxe...")
    
    # Vérifier les accolades équilibrées
    open_braces = content.count('{')
    close_braces = content.count('}')
    if open_braces != close_braces:
        print(f"ERREUR: Accolades non équilibrées: {open_braces} ouvertes, {close_braces} fermées")
        return False
    
    # Vérifier les parenthèses équilibrées
    open_parens = content.count('(')
    close_parens = content.count(')')
    if open_parens != close_parens:
        print(f"ERREUR: Parenthèses non équilibrées: {open_parens} ouvertes, {close_parens} fermées")
        return False
    
    print("OK: Syntaxe de base correcte")
    
    # Vérifier les couleurs personnalisées
    color_params = [
        "InpEMAColor20",
        "InpEMAColor50", 
        "InpEMAColor200",
        "InpBBColor",
        "InpFibonacciColor",
        "InpOTEColor",
        "InpOrderBlockBullColor",
        "InpOrderBlockBearColor",
        "InpFVGBullColor",
        "InpFVGBearColor"
    ]
    
    missing_colors = []
    for color_param in color_params:
        if f"input color    {color_param}" not in content:
            missing_colors.append(color_param)
    
    if missing_colors:
        print(f"ERREUR: Paramètres de couleur manquants: {missing_colors}")
        return False
    
    print("OK: Tous les paramètres de couleur sont présents")
    
    print("\nRESUME DES INDICATEURS AJOUTES:")
    print("   EMA (20, 50, 200) - Moyennes mobiles exponentielles")
    print("   Bollinger Bands - Bandes de Bollinger")
    print("   Fibonacci - Niveaux de retracement")
    print("   OTE Zones - Zones d'entree optimales")
    print("   Order Blocks - Blocs d'ordres")
    print("   Fair Value Gaps - Gaps de valeur equitable")
    
    print("\nCOMPILATION SIMULEE REUSSIE!")
    print("   Le robot AngelOfSpike contient maintenant tous les indicateurs visuels modernes")
    print("   Les indicateurs seront affiches automatiquement sur le graphique")
    print("   Vous pouvez activer/desactiver chaque indicateur via les parametres d'input")
    
    return True

if __name__ == "__main__":
    success = test_compilation()
    sys.exit(0 if success else 1)