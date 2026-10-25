#!/usr/bin/env python3
"""
Script basique pour corriger les erreurs d'indentation
"""

def fix_indentation_basic():
    """Corriger les erreurs d'indentation basiques"""
    
    print("CORRECTION INDENTATION BASIQUE")
    print("=" * 40)
    
    # Lire le fichier
    with open('ai_server.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Corriger les problèmes évidents d'indentation
    lines = content.split('\n')
    fixed_lines = []
    errors_fixed = 0
    
    for line in lines:
        stripped = line.lstrip()
        
        # Si la ligne commence par un mot-clé Python et est trop indentée
        if (stripped.startswith(('if ', 'elif ', 'else:', 'for ', 'while ', 'try:', 'except', 'finally:', 'with ', 'def ', 'class ', '@app.')) and 
            line.startswith('                ') and  # 16 espaces ou plus
            not stripped.startswith('                ')):  # mais ne devrait pas avoir cette indentation
            
            # Corriger: enlever l'indentation excessive
            corrected_line = stripped
            fixed_lines.append(corrected_line)
            errors_fixed += 1
        else:
            fixed_lines.append(line)
    
    if errors_fixed > 0:
        # Sauvegarder
        with open('ai_server.py', 'w', encoding='utf-8') as f:
            f.write('\n'.join(fixed_lines))
        
        print(f"{errors_fixed} erreurs d'indentation corrigees")
    else:
        print("Aucune erreur evidente detectee")
    
    # Test de syntaxe simple
    try:
        compile('\n'.join(fixed_lines), 'ai_server.py', 'exec')
        print("Syntaxe Python valide")
    except SyntaxError as e:
        print(f"Erreur syntaxe: Ligne {e.lineno}")
        print(f"   {e.text}")

if __name__ == "__main__":
    fix_indentation_basic()
