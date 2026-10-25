import re

# Lire le fichier
with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Corriger les try: vides
fixed_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # Si c'est un try: vide (suivi d'un except)
    if line.strip() == 'try:' and i + 1 < len(lines) and lines[i + 1].strip().startswith('except'):
        # Ajouter un pass après le try:
        indent = len(line) - len(line.lstrip())
        indent_str = ' ' * (indent + 2)  # +2 pour l'indentation du pass
        fixed_lines.append(line)
        fixed_lines.append(f"{indent_str}pass\n")
        print(f"Ligne {i+1}: Ajouté 'pass' après try: vide")
    else:
        fixed_lines.append(line)
    
    i += 1

# Sauvegarder le fichier corrigé
with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
    f.writelines(fixed_lines)

print("Corrections des try: vides appliquées")
