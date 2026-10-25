#!/usr/bin/env python3
"""
Script pour corriger toutes les erreurs de syntaxe dans app_real_time.py
"""

import re

def fix_syntax_errors(file_path):
    """Corrige les erreurs de syntaxe dans le fichier"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Corriger les try sans except/finally
        if re.match(r'^\s*try:\s*$', line):
            # Trouver le prochain except ou finally
            j = i + 1
            indent_level = len(line) - len(line.lstrip())
            found_except = False
            
            while j < len(lines):
                next_line = lines[j]
                if not next_line.strip():  # Ligne vide
                    j += 1
                    continue
                
                next_indent = len(next_line) - len(next_line.lstrip())
                
                # Si on trouve un except ou finally au même niveau
                if (next_indent == indent_level and 
                    (next_line.strip().startswith('except') or next_line.strip().startswith('finally'))):
                    found_except = True
                    break
                
                # Si on trouve un bloc au niveau supérieur, on s'arrête
                if next_indent < indent_level:
                    break
                    
                j += 1
            
            if not found_except:
                # Ajouter un except pass
                fixed_lines.append(line)
                # Ajouter le contenu du try avec la bonne indentation
                j = i + 1
                while j < len(lines):
                    next_line = lines[j]
                    if not next_line.strip():
                        fixed_lines.append(next_line)
                        j += 1
                        continue
                    
                    next_indent = len(next_line) - len(next_line.lstrip())
                    if next_indent <= indent_level:
                        break
                    
                    # Corriger l'indentation
                    fixed_line = ' ' * (indent_level + 4) + next_line.strip()
                    fixed_lines.append(fixed_line)
                    j += 1
                
                # Ajouter except pass
                fixed_lines.append(' ' * indent_level + 'except Exception:')
                fixed_lines.append(' ' * (indent_level + 4) + 'pass')
                i = j
                continue
        
        # Corriger les blocs mal indentés après if/for/while
        if re.match(r'^\s*(if|for|while|with|def|class)\s+.*:\s*$', line):
            indent_level = len(line) - len(line.lstrip())
            fixed_lines.append(line)
            
            # Vérifier la ligne suivante
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                if next_line.strip() and not next_line.startswith(' ' * (indent_level + 4)):
                    # Corriger l'indentation
                    if not next_line.startswith(' ' * (indent_level + 4)):
                        fixed_line = ' ' * (indent_level + 4) + next_line.strip()
                        fixed_lines.append(fixed_line)
                        i += 1
                        continue
        
        # Corriger les lignes avec des erreurs d'expression
        if 'Expected expression' in str(line) or re.match(r'^\s*$', line):
            if line.strip():
                fixed_lines.append(line)
        else:
            fixed_lines.append(line)
        
        i += 1
    
    return '\n'.join(fixed_lines)

def main():
    file_path = 'frontend/app_real_time.py'
    
    print("Correction des erreurs de syntaxe...")
    
    try:
        fixed_content = fix_syntax_errors(file_path)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        
        print("✅ Erreurs de syntaxe corrigées avec succès!")
        
    except Exception as e:
        print(f"❌ Erreur lors de la correction: {e}")

if __name__ == "__main__":
    main()
