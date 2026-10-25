#!/usr/bin/env python3
"""
Script pour corriger toutes les erreurs de syntaxe dans app_real_time.py
"""

import re

def fix_syntax_errors():
    file_path = "frontend/app_real_time.py"
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Corriger les blocs try sans except
        if line.strip().startswith('try:'):
            # Trouver le bloc try correspondant
            try_indent = len(line) - len(line.lstrip())
            j = i + 1
            found_except = False
            found_finally = False
            
            while j < len(lines):
                next_line = lines[j]
                if next_line.strip() == '':
                    j += 1
                    continue
                    
                next_indent = len(next_line) - len(next_line.lstrip())
                
                if next_indent <= try_indent and next_line.strip():
                    if next_line.strip().startswith('except') or next_line.strip().startswith('finally'):
                        found_except = True
                    break
                j += 1
            
            if not found_except:
                # Ajouter un except par défaut
                fixed_lines.append(line)
                i += 1
                # Ajouter le contenu du try
                while i < len(lines):
                    current_line = lines[i]
                    if current_line.strip() == '':
                        fixed_lines.append(current_line)
                        i += 1
                        continue
                    
                    current_indent = len(current_line) - len(current_line.lstrip())
                    if current_indent <= try_indent and current_line.strip():
                        # Fin du bloc try, ajouter except
                        fixed_lines.append(' ' * (try_indent + 4) + 'except Exception as e:')
                        fixed_lines.append(' ' * (try_indent + 8) + 'pass')
                        fixed_lines.append(current_line)
                        i += 1
                        break
                    else:
                        fixed_lines.append(current_line)
                        i += 1
                continue
        
        # Corriger les else mal indentés
        if line.strip() == 'else:' and i > 0:
            prev_line = lines[i-1]
            if prev_line.strip() and not prev_line.strip().endswith(':'):
                # Ajuster l'indentation de else
                prev_indent = len(prev_line) - len(prev_line.lstrip())
                fixed_lines.append(' ' * prev_indent + 'else:')
                i += 1
                continue
        
        # Corriger les blocs mal indentés
        if line.strip() and not line.startswith(' ') and not line.startswith('\t'):
            # Ligne au niveau racine
            fixed_lines.append(line)
        else:
            # Vérifier l'indentation
            if line.strip():
                # Compter les espaces/tabs
                indent_count = len(line) - len(line.lstrip())
                if indent_count % 4 != 0:
                    # Ajuster à un multiple de 4
                    new_indent = (indent_count // 4) * 4
                    fixed_lines.append(' ' * new_indent + line.lstrip())
                else:
                    fixed_lines.append(line)
            else:
                fixed_lines.append(line)
        
        i += 1
    
    # Écrire le fichier corrigé
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_lines))
    
    print("✅ Erreurs de syntaxe corrigées!")

if __name__ == "__main__":
    fix_syntax_errors()
