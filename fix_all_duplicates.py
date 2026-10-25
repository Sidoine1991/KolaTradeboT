#!/usr/bin/env python3
"""
Script pour supprimer toutes les duplications et corriger l'indentation
"""

def fix_duplicates_and_indentation():
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Supprimer les lignes dupliquées consécutives
        if i > 0 and line.strip() == lines[i-1].strip() and line.strip():
            i += 1
            continue
        
        # Corriger l'indentation après if/for/while/with/def/class/try
        if any(line.strip().startswith(keyword) for keyword in ['if ', 'for ', 'while ', 'with ', 'def ', 'class ', 'try:']):
            if line.strip().endswith(':'):
                fixed_lines.append(line)
                # Vérifier la ligne suivante
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.strip() and not next_line.startswith('    '):
                        # Ajouter l'indentation manquante
                        fixed_lines.append('    ' + next_line.strip())
                        i += 1
                        continue
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

if __name__ == "__main__":
    try:
        fixed_content = fix_duplicates_and_indentation()
        with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print("✅ Duplications supprimées et indentation corrigée!")
    except Exception as e:
        print(f"❌ Erreur: {e}")
