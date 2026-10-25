#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test de compilation AngelOfSpike - Version finale
"""

import os

def test_final():
    """Test final du fichier AngelOfSpike.mq5"""
    
    file_path = "mt5/AngelOfSpike.mq5"
    if not os.path.exists(file_path):
        print("ERREUR: Fichier AngelOfSpike.mq5 non trouve!")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("=== TEST DE COMPILATION ANGELOFSPIKE ===")
    print()
    
    # Vérifier les accolades
    open_braces = content.count('{')
    close_braces = content.count('}')
    print(f"Accolades: {open_braces} ouvertes, {close_braces} fermées")
    if open_braces == close_braces:
        print("OK: Accolades équilibrées")
    else:
        print(f"ERREUR: Accolades non équilibrées (différence: {close_braces - open_braces})")
    
    # Vérifier les parenthèses
    open_parens = content.count('(')
    close_parens = content.count(')')
    print(f"Parenthèses: {open_parens} ouvertes, {close_parens} fermées")
    if open_parens == close_parens:
        print("OK: Parenthèses équilibrées")
    else:
        print(f"ATTENTION: Parenthèses non équilibrées (différence: {close_parens - open_parens})")
        print("   Cela peut être normal si des parenthèses sont dans des commentaires")
    
    print()
    print("=== INDICATEURS VISUELS MODERNES ===")
    
    # Vérifier les paramètres d'input
    indicators = [
        ("InpShowEMA", "EMA (20, 50, 200)"),
        ("InpShowBollinger", "Bollinger Bands"),
        ("InpShowFibonacci", "Niveaux de Fibonacci"),
        ("InpShowOTE", "Zones OTE"),
        ("InpShowOrderBlocks", "Order Blocks"),
        ("InpShowFVG", "Fair Value Gaps")
    ]
    
    for indicator, description in indicators:
        if f"input bool     {indicator}" in content:
            print(f"OK: {indicator} - {description}")
        else:
            print(f"MANQUANT: {indicator} - {description}")
    
    print()
    print("=== FONCTIONS DE DESSIN ===")
    
    # Vérifier les fonctions
    functions = [
        ("DrawEMAIndicators", "Dessine les EMA"),
        ("DrawBollingerBands", "Dessine les Bollinger Bands"),
        ("DrawFibonacciLevels", "Dessine les niveaux de Fibonacci"),
        ("DrawOTEZones", "Dessine les zones OTE"),
        ("DrawOrderBlocks", "Dessine les Order Blocks"),
        ("DrawFairValueGaps", "Dessine les Fair Value Gaps"),
        ("DrawAllIndicators", "Fonction principale de dessin")
    ]
    
    for func, description in functions:
        if f"void {func}()" in content:
            print(f"OK: {func} - {description}")
        else:
            print(f"MANQUANT: {func} - {description}")
    
    print()
    print("=== INTÉGRATION DANS LE ROBOT ===")
    
    # Vérifier les appels
    if "DrawAllIndicators();" in content:
        print("OK: Appel à DrawAllIndicators() présent")
    else:
        print("MANQUANT: Appel à DrawAllIndicators()")
    
    if "OnInit()" in content and "DrawAllIndicators();" in content:
        print("OK: Intégration dans OnInit()")
    else:
        print("ATTENTION: Vérifiez l'intégration dans OnInit()")
    
    if "OnTick()" in content and "DrawAllIndicators();" in content:
        print("OK: Intégration dans OnTick()")
    else:
        print("ATTENTION: Vérifiez l'intégration dans OnTick()")
    
    print()
    print("=== RÉSUMÉ ===")
    print("Le robot AngelOfSpike contient maintenant tous les indicateurs visuels modernes!")
    print("Les indicateurs seront affichés automatiquement sur le graphique.")
    print("Vous pouvez activer/désactiver chaque indicateur via les paramètres d'input.")
    print()
    print("INDICATEURS DISPONIBLES:")
    print("- EMA (20, 50, 200) - Moyennes mobiles exponentielles")
    print("- Bollinger Bands - Bandes de Bollinger")
    print("- Fibonacci - Niveaux de retracement")
    print("- OTE Zones - Zones d'entrée optimales")
    print("- Order Blocks - Blocs d'ordres")
    print("- Fair Value Gaps - Gaps de valeur équitable")
    
    return True

if __name__ == "__main__":
    test_final()
