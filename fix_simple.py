#!/usr/bin/env python3
"""
Script simple pour corriger les erreurs de syntaxe
"""

def fix_file():
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Corriger les problèmes d'indentation courants
    lines = content.split('\n')
    fixed_lines = []
    
    for i, line in enumerate(lines):
        # Supprimer les lignes dupliquées
        if i > 0 and line.strip() == lines[i-1].strip() and line.strip():
            continue
        
        # Corriger l'indentation après try
        if line.strip().startswith('try:'):
            fixed_lines.append(line)
            # Vérifier la ligne suivante
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                if next_line.strip() and not next_line.startswith('    '):
                    # Ajouter l'indentation manquante
                    fixed_lines.append('    ' + next_line.strip())
                    continue
        
        # Corriger l'indentation après if/for/while/with/def/class
        if any(line.strip().startswith(keyword + ' ') for keyword in ['if', 'for', 'while', 'with', 'def', 'class']):
            if line.strip().endswith(':'):
                fixed_lines.append(line)
                # Vérifier la ligne suivante
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.strip() and not next_line.startswith('    '):
                        # Ajouter l'indentation manquante
                        fixed_lines.append('    ' + next_line.strip())
                        continue
        
        fixed_lines.append(line)
    
    return '\n'.join(fixed_lines)

if __name__ == "__main__":
    try:
        fixed_content = fix_file()
        with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print("✅ Fichier corrigé!")
    except Exception as e:
        print(f"❌ Erreur: {e}")
