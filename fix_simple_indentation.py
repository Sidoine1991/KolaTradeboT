#!/usr/bin/env python3
"""
Script simple pour corriger les erreurs d'indentation évidentes
"""

def fix_simple_indentation():
    """Corriger les erreurs d'indentation évidentes"""
    
    print("CORRECTION SIMPLE INDENTATION")
    print("=" * 40)
    
    # Lire le fichier
    with open('ai_server.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remplacer les indentations incorrectes évidentes
    # Lignes qui commencent par trop d'espaces mais ne devraient pas être indentées
    lines = content.split('\n')
    fixed_lines = []
    errors_fixed = 0
    
    for line in lines:
        stripped = line.lstrip()
        
        # Si la ligne commence par un mot-clé Python et a beaucoup d'espaces
        if (stripped.startswith(('if ', 'elif ', 'else:', 'for ', 'while ', 'try:', 'except', 'finally:', 'with ', 'def ', 'class ', '@app.')) and 
            line.startswith('                ') and  # 16 espaces ou plus
            not any(stripped.startswith(prefix) for prefix in ['if ', 'elif ', 'else:', 'for ', 'while ', 'try:', 'except', 'finally:', 'with ', 'def ', 'class ', '@app.'])):
            
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
        
        print(f"✅ {errors_fixed} erreurs d'indentation corrigées")
    else:
        print("✅ Aucune erreur évidente détectée")
    
    # Test simple de syntaxe
    try:
        compile('\n'.join(fixed_lines), 'ai_server.py', 'exec')
        print("✅ Syntaxe Python valide")
    except SyntaxError as e:
        print(f"❌ Erreur syntaxe: Ligne {e.lineno}")
        print(f"   {e.text}")

if __name__ == "__main__":
    fix_simple_indentation()
