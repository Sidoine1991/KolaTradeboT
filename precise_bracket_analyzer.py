#!/usr/bin/env python3
"""
Analyseur précis d'accolades pour identifier les problèmes exacts
"""

def analyze_brackets_precise(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    open_brackets = []
    close_brackets = []
    
    for i, line in enumerate(lines, 1):
        for j, char in enumerate(line):
            if char == '{':
                open_brackets.append((i, j + 1, line.strip()))
            elif char == '}':
                close_brackets.append((i, j + 1, line.strip()))
    
    print(f"Total accolades ouvrantes: {len(open_brackets)}")
    print(f"Total accolades fermantes: {len(close_brackets)}")
    print(f"Différence: {len(open_brackets) - len(close_brackets)}")
    
    # Vérifier les premières lignes problématiques
    problematic_lines = [299, 318, 6909, 6960, 6974, 6986, 6998, 7010, 7025, 7045, 7086, 7275, 7377, 9220, 9251, 9254]
    
    for line_num in problematic_lines:
        if line_num <= len(lines):
            print(f"\n--- Ligne {line_num} ---")
            print(f"Contenu: {lines[line_num-1].strip()}")
            
            # Vérifier les accolades autour de cette ligne
            for i in range(max(0, line_num-3), min(len(lines), line_num+2)):
                open_count = lines[i].count('{')
                close_count = lines[i].count('}')
                if open_count > 0 or close_count > 0:
                    print(f"  Ligne {i+1}: {open_count} ouvrantes, {close_count} fermantes - {lines[i].strip()}")

if __name__ == "__main__":
    file_path = "D:\\Dev\\TradBOT\\mt5\\F_INX_robot4.mq5"
    analyze_brackets_precise(file_path)
