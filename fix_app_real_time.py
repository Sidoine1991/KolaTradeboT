#!/usr/bin/env python3
"""
Script pour corriger les erreurs d'indentation dans app_real_time.py
"""

def fix_indentation():
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Corriger les lignes problématiques
    corrections = {
        3855: "    else:\n",  # Ligne 3856 (index 3855)
        3861: "else:\n",      # Ligne 3862 (index 3861)
    }
    
    # Appliquer les corrections
    for line_num, new_content in corrections.items():
        if line_num < len(lines):
            lines[line_num] = new_content
    
    # Écrire le fichier corrigé
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("Corrections d'indentation appliquées avec succès")

if __name__ == "__main__":
    fix_indentation()
