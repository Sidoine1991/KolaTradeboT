#!/usr/bin/env python3
"""
Script simple pour corriger les erreurs de syntaxe dans app_real_time.py
"""

def fix_syntax():
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Corriger les lignes problématiques
    # Ligne 3856 (index 3855) - corriger l'indentation
    if len(lines) > 3855:
        lines[3855] = '    else:\n'
    
    # Ligne 3862 (index 3861) - corriger l'indentation  
    if len(lines) > 3861:
        lines[3861] = 'else:\n'
    
    # Écrire le fichier corrigé
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("Corrections de syntaxe appliquées avec succès")

if __name__ == "__main__":
    fix_syntax()
