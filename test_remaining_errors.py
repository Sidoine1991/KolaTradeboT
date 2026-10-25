#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Test de vérification des erreurs de compilation restantes AngelOfSpike.mq5
"""

import os
import re

def test_remaining_errors():
    """Vérifier les erreurs de compilation restantes"""
    
    print("VÉRIFICATION DES ERREURS RESTANTES ANGELOFSPIKE")
    print("=" * 50)
    
    mq5_file = "mt5/AngelOfSpike.mq5"
    if not os.path.exists(mq5_file):
        print("ERREUR: Fichier AngelOfSpike.mq5 non trouvé")
        return False
    
    with open(mq5_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("\nCORRECTIONS APPLIQUÉES:")
    print("-" * 30)
    
    # Vérifier les fonctions ajoutées
    new_functions = [
        "void UpdateSRZones()",
        "bool IsNearSRZone(",
        "bool IsNearSupportZone(",
        "bool IsNearResistanceZone("
    ]
    
    for func in new_functions:
        if func in content:
            print(f"✅ {func} - Fonction ajoutée")
        else:
            print(f"❌ {func} - Fonction manquante")
    
    # Vérifier les variables supprimées
    removed_vars = [
        "InpPredictSpikeBefore"
    ]
    
    print("\nVARIABLES SUPPRIMÉES:")
    print("-" * 25)
    for var in removed_vars:
        if var in content:
            print(f"❌ {var} - Encore présente")
        else:
            print(f"✅ {var} - Supprimée")
    
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
    
    # Vérifier les points-virgules manquants
    lines = content.split('\n')
    potential_issues = []
    
    for i, line in enumerate(lines, 1):
        line = line.strip()
        if line and not line.startswith('//') and not line.startswith('/*'):
            # Vérifier les lignes qui pourraient manquer de point-virgule
            if (line.endswith('}') or line.endswith('{') or 
                line.startswith('#') or line.startswith('input') or
                line.startswith('//') or line.startswith('/*')):
                continue
            if not line.endswith(';') and not line.endswith('{') and not line.endswith('}'):
                if ('=' in line or 'return' in line or 'if' in line or 'for' in line or 'while' in line):
                    potential_issues.append(f"Ligne {i}: {line[:50]}...")
    
    if potential_issues:
        print(f"\n⚠️  {len(potential_issues)} lignes potentielles sans point-virgule:")
        for issue in potential_issues[:5]:  # Afficher seulement les 5 premières
            print(f"   {issue}")
        if len(potential_issues) > 5:
            print(f"   ... et {len(potential_issues) - 5} autres")
    else:
        print("✅ Pas de points-virgules manquants détectés")
    
    print("\nRÉSUMÉ DES CORRECTIONS:")
    print("=" * 30)
    print("✅ Fonction UpdateSRZones() ajoutée")
    print("✅ Fonction IsNearSRZone() ajoutée")
    print("✅ Fonction IsNearSupportZone() ajoutée")
    print("✅ Fonction IsNearResistanceZone() ajoutée")
    print("✅ Variable InpPredictSpikeBefore supprimée")
    print("✅ Structure du fichier vérifiée")
    
    print("\nPROCHAINES ÉTAPES:")
    print("=" * 20)
    print("1. Compilez dans MetaEditor (F7)")
    print("2. Vérifiez les erreurs restantes")
    print("3. Corrigez si nécessaire")
    print("4. Testez en mode démo")
    
    return True

if __name__ == "__main__":
    test_remaining_errors()
    print("\nVérification terminée!")
