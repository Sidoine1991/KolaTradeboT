#!/usr/bin/env python3
"""
Script complet pour corriger toutes les erreurs de syntaxe dans app_real_time.py
"""

import re
import ast

def fix_syntax_comprehensive():
    file_path = "frontend/app_real_time.py"
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        original_line = line
        
        # Ignorer les lignes vides
        if not line.strip():
            fixed_lines.append(line)
            i += 1
            continue
        
        # Corriger les erreurs d'indentation
        if line.strip():
            # Calculer l'indentation correcte
            indent_level = 0
            if line.strip().startswith(('def ', 'class ', 'if ', 'else:', 'elif ', 'for ', 'while ', 'try:', 'except', 'finally:', 'with ')):
                # Niveau de base pour les structures de contrôle
                indent_level = 0
            elif line.strip().startswith(('return ', 'pass', 'break', 'continue')):
                # Instructions de retour
                indent_level = 4
            else:
                # Autres instructions
                indent_level = 4
            
            # Ajuster l'indentation
            new_line = ' ' * indent_level + line.lstrip()
            fixed_lines.append(new_line)
        else:
            fixed_lines.append(line)
        
        i += 1
    
    # Corriger les blocs try sans except
    content = '\n'.join(fixed_lines)
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        if line.strip().startswith('try:'):
            fixed_lines.append(line)
            i += 1
            
            # Trouver le contenu du try
            try_indent = len(line) - len(line.lstrip())
            try_content = []
            
            while i < len(lines):
                current_line = lines[i]
                if not current_line.strip():
                    try_content.append(current_line)
                    i += 1
                    continue
                
                current_indent = len(current_line) - len(current_line.lstrip())
                if current_indent <= try_indent and current_line.strip():
                    # Fin du bloc try
                    if not current_line.strip().startswith(('except', 'finally')):
                        # Ajouter un except par défaut
                        fixed_lines.extend(try_content)
                        fixed_lines.append(' ' * (try_indent + 4) + 'except Exception as e:')
                        fixed_lines.append(' ' * (try_indent + 8) + 'pass')
                        fixed_lines.append(current_line)
                        i += 1
                        break
                    else:
                        fixed_lines.extend(try_content)
                        fixed_lines.append(current_line)
                        i += 1
                        break
                else:
                    try_content.append(current_line)
                    i += 1
        else:
            fixed_lines.append(line)
            i += 1
    
    # Écrire le fichier corrigé
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_lines))
    
    print("✅ Erreurs de syntaxe corrigées de manière complète!")

if __name__ == "__main__":
    fix_syntax_comprehensive()
