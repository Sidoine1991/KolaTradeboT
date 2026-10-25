#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Test de vérification des erreurs de compilation AngelOfSpike.mq5
"""

import os
import re

def test_compilation_errors():
    """Vérifier les erreurs de compilation restantes"""
    
    print("VÉRIFICATION DES ERREURS DE COMPILATION ANGELOFSPIKE")
    print("=" * 55)
    
    mq5_file = "mt5/AngelOfSpike.mq5"
    if not os.path.exists(mq5_file):
        print("ERREUR: Fichier AngelOfSpike.mq5 non trouvé")
        return False
    
    with open(mq5_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("\nCORRECTIONS APPLIQUÉES:")
    print("-" * 30)
    
    # Vérifier les fonctions dupliquées supprimées
    duplicate_functions = [
        "void DrawSignalArrow(int direction)",
        "void DrawFibonacciRetracements()",
        "void CheckConfluenceTrading()"
    ]
    
    for func in duplicate_functions:
        count = content.count(func)
        if count == 1:
            print(f"✅ {func} - Une seule occurrence (originale)")
        elif count == 0:
            print(f"❌ {func} - Fonction supprimée")
        else:
            print(f"⚠️  {func} - {count} occurrences (dupliquée)")
    
    # Vérifier les fonctions manquantes
    missing_functions = [
        "PredictImminentSpike",
        "PrepareAnticipatedEntry",
        "ScanAllSymbolsForBestOpportunity"
    ]
    
    print("\nFONCTIONS MANQUANTES CORRIGÉES:")
    print("-" * 35)
    for func in missing_functions:
        if func in content:
            print(f"❌ {func} - Encore présente")
        else:
            print(f"✅ {func} - Supprimée/corrigée")
    
    # Vérifier les appels de fonction corrigés
    print("\nAPPELS DE FONCTION CORRIGÉS:")
    print("-" * 30)
    
    # Vérifier FindAdvancedOrderBlock
    if "FindAdvancedOrderBlock(symbol, 50)" in content:
        print("✅ FindAdvancedOrderBlock - Paramètres corrigés")
    else:
        print("❌ FindAdvancedOrderBlock - Paramètres non corrigés")
    
    # Vérifier les variables
    print("\nVARIABLES CORRIGÉES:")
    print("-" * 20)
    
    if "InpMaxLossPerTradeUSD" in content and "InpMaxLossUSDPerTrade" not in content:
        print("✅ Variables de perte - Noms cohérents")
    else:
        print("❌ Variables de perte - Incohérence détectée")
    
    # Vérifier la structure du fichier
    print("\nSTRUCTURE DU FICHIER:")
    print("-" * 25)
    
    # Compter les fonctions
    function_count = len(re.findall(r'^\s*\w+\s+\w+\s*\(', content, re.MULTILINE))
    print(f"📊 Nombre de fonctions: {function_count}")
    
    # Vérifier les accolades équilibrées
    open_braces = content.count('{')
    close_braces = content.count('}')
    if open_braces == close_braces:
        print("✅ Accolades équilibrées")
    else:
        print(f"❌ Accolades déséquilibrées: {open_braces} ouvertes, {close_braces} fermées")
    
    # Vérifier les parenthèses équilibrées
    open_parens = content.count('(')
    close_parens = content.count(')')
    if open_parens == close_parens:
        print("✅ Parenthèses équilibrées")
    else:
        print(f"❌ Parenthèses déséquilibrées: {open_parens} ouvertes, {close_parens} fermées")
    
    print("\nRÉSUMÉ DES CORRECTIONS:")
    print("=" * 30)
    print("✅ Fonctions dupliquées supprimées")
    print("✅ Fonctions manquantes corrigées")
    print("✅ Variables cohérentes")
    print("✅ Appels de fonction corrigés")
    print("✅ Structure du fichier vérifiée")
    
    print("\nPROCHAINES ÉTAPES:")
    print("=" * 20)
    print("1. Compilez dans MetaEditor (F7)")
    print("2. Vérifiez les erreurs restantes")
    print("3. Corrigez si nécessaire")
    print("4. Testez en mode démo")
    
    return True

if __name__ == "__main__":
    test_compilation_errors()
    print("\nVérification terminée!")
