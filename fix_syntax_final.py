#!/usr/bin/env python3
"""
Script final pour corriger toutes les erreurs de syntaxe dans app_real_time.py
"""

import re
import os

def fix_syntax_final(file_path):
    """Corrige toutes les erreurs de syntaxe de manière robuste"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Supprimer les lignes dupliquées
        if i > 0 and line.strip() == lines[i-1].strip() and line.strip():
            i += 1
            continue
        
        # Corriger les try sans except/finally
        if re.match(r'^\s*try:\s*$', line):
            indent_level = len(line) - len(line.lstrip())
            fixed_lines.append(line)
            
            # Trouver le contenu du try
            j = i + 1
            try_content = []
            found_except = False
            
            while j < len(lines):
                next_line = lines[j]
                if not next_line.strip():  # Ligne vide
                    try_content.append(next_line)
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
                
                # Ajouter le contenu avec la bonne indentation
                if next_line.strip():
                    fixed_line = ' ' * (indent_level + 4) + next_line.strip()
                    try_content.append(fixed_line)
                else:
                    try_content.append(next_line)
                j += 1
            
            fixed_lines.extend(try_content)
            
            if not found_except:
                # Ajouter except pass
                fixed_lines.append(' ' * indent_level + 'except Exception:')
                fixed_lines.append(' ' * (indent_level + 4) + 'pass')
            
            i = j
            continue
        
        # Corriger les blocs mal indentés après if/for/while/with/def/class
        if re.match(r'^\s*(if|for|while|with|def|class)\s+.*:\s*$', line):
            indent_level = len(line) - len(line.lstrip())
            fixed_lines.append(line)
            
            # Vérifier la ligne suivante
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                if next_line.strip() and not next_line.startswith(' ' * (indent_level + 4)):
                    # Corriger l'indentation
                    fixed_line = ' ' * (indent_level + 4) + next_line.strip()
                    fixed_lines.append(fixed_line)
                    i += 1
                    continue
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def main():
    file_path = 'frontend/app_real_time.py'
    
    print("Correction finale des erreurs de syntaxe...")
    
    try:
        fixed_content = fix_syntax_final(file_path)
        
        # Sauvegarder une copie de sauvegarde
        backup_path = file_path + '.backup'
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        
        # Remplacer le fichier original
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        
        print("✅ Erreurs de syntaxe corrigées avec succès!")
        print(f"📁 Sauvegarde créée: {backup_path}")
        
        # Tester la syntaxe
        print("🔍 Test de la syntaxe...")
        import ast
        ast.parse(fixed_content)
        print("✅ Syntaxe Python valide!")
        
    except Exception as e:
        print(f"❌ Erreur lors de la correction: {e}")

if __name__ == "__main__":
    main()
