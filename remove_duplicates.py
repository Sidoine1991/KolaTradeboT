#!/usr/bin/env python3
"""
Script pour supprimer toutes les duplications de lignes
"""

def remove_duplicates():
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
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

if __name__ == "__main__":
    try:
        fixed_content = remove_duplicates()
        with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print("✅ Duplications supprimées!")
    except Exception as e:
        print(f"❌ Erreur: {e}")
