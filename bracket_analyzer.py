#!/usr/bin/env python3
"""
Analyseur d'accolades pour le fichier MQL5
"""

def analyze_brackets(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    stack = []
    issues = []
    
    for i, line in enumerate(lines, 1):
        for j, char in enumerate(line):
            if char == '{':
                stack.append((i, j + 1))
            elif char == '}':
                if not stack:
                    issues.append(f"Ligne {i}: Accolade fermante sans ouvrante à la position {j + 1}")
                else:
                    stack.pop()
    
    # Vérifier les accolades non fermées
    while stack:
        line, pos = stack.pop()
        issues.append(f"Ligne {line}: Accolade ouvrante non fermée à la position {pos}")
    
    return issues

if __name__ == "__main__":
    file_path = "D:\\Dev\\TradBOT\\mt5\\F_INX_robot4.mq5"
    issues = analyze_brackets(file_path)
    
    if issues:
        print("Problèmes d'accolades trouvés:")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("Aucun problème d'accolades détecté.")
