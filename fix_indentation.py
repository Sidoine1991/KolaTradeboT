#!/usr/bin/env python3
"""
Script pour corriger les erreurs d'indentation dans ai_server.py
"""

import re

def fix_indentation():
    """Corriger les erreurs d'indentation dans ai_server.py"""
    
    print("CORRECTION INDENTATION AI_SERVER.PY")
    print("=" * 40)
    
    # Lire le fichier
    with open('ai_server.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    fixed_lines = []
    errors_found = 0
    
    for i, line in enumerate(lines, 1):
        # Détecter les lignes avec indentation incorrecte
        stripped = line.lstrip()
        if not stripped or stripped.startswith('#'):
            fixed_lines.append(line)
            continue
        
        # Calculer l'indentation correcte basée sur le contexte
        leading_spaces = len(line) - len(stripped)
        
        # Vérifier si c'est une ligne de fonction ou de classe
        if stripped.startswith(('def ', 'class ', '@app.', 'async def', 'try:', 'except', 'finally:', 'with ', 'for ', 'if ', 'elif ', 'else:', 'while ')):
            # Ces lignes ne devraient pas avoir d'indentation excessive
            if i > 1:
                prev_line = fixed_lines[-1] if fixed_lines else ""
                prev_stripped = prev_line.lstrip()
                
                # Si la ligne précédente se termine par ':', on ajoute 4 espaces
                if prev_stripped.rstrip().endswith(':'):
                    expected_indent = 4
                else:
                    expected_indent = 0
                
                if leading_spaces != expected_indent and leading_spaces > expected_indent:
                    # Corriger l'indentation
                    corrected_line = ' ' * expected_indent + stripped
                    fixed_lines.append(corrected_line + '\n')
                    print(f"Ligne {i}: Indentation corrigée ({leading_spaces} -> {expected_indent})")
                    print(f"  Avant: {repr(line)}")
                    print(f"  Après: {repr(corrected_line)}")
                    errors_found += 1
                    continue
        
        fixed_lines.append(line)
    
    if errors_found > 0:
        # Sauvegarder le fichier corrigé
        with open('ai_server.py', 'w', encoding='utf-8') as f:
            f.writelines(fixed_lines)
        
        print(f"\n✅ {errors_found} erreurs d'indentation corrigées")
    else:
        print("\n✅ Aucune erreur d'indentation détectée")
    
    print("\n🎯 Vérification syntaxe Python...")
    
    # Vérifier la syntaxe Python
    try:
        compile(''.join(fixed_lines), 'ai_server.py', 'exec')
        print("✅ Syntaxe Python valide")
    except SyntaxError as e:
        print(f"❌ Erreur de syntaxe: {e}")
        print(f"   Ligne {e.lineno}: {e.text}")

if __name__ == "__main__":
    fix_indentation()
