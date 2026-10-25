import re

# Lire le fichier
with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Variables pour suivre les try/except
try_stack = []
orphan_excepts = []

for i, line in enumerate(lines, 1):
    line_stripped = line.strip()
    
    # Détecter les try
    if line_stripped.startswith('try:'):
        try_stack.append(i)
    
    # Détecter les except
    elif line_stripped.startswith('except'):
        if try_stack:
            # Il y a un try correspondant, on le retire de la pile
            try_stack.pop()
        else:
            # Except orphelin !
            orphan_excepts.append((i, line_stripped))

# Corriger les except orphelins en ajoutant un try avant chacun
if orphan_excepts:
    print(f"Correction de {len(orphan_excepts)} except orphelins...")
    
    # Traiter les corrections de la fin vers le début pour ne pas décaler les numéros de ligne
    for line_num, line_content in reversed(orphan_excepts):
        print(f"Correction ligne {line_num}: {line_content}")
        
        # Obtenir l'indentation de l'except
        original_line = lines[line_num - 1]
        indent = len(original_line) - len(original_line.lstrip())
        indent_str = ' ' * indent
        
        # Insérer un try avec la même indentation avant l'except
        try_line = f"{indent_str}try:\n"
        
        # Chercher la ligne précédente avec du code pour y ajouter le try
        insert_pos = line_num - 1
        while insert_pos > 0:
            prev_line = lines[insert_pos - 1].strip()
            if prev_line and not prev_line.startswith('#'):
                break
            insert_pos -= 1
        
        # Insérer le try avant l'except
        lines.insert(line_num - 1, try_line)
    
    # Sauvegarder le fichier corrigé
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("Corrections appliquées")
else:
    print("Aucun except orphelin trouvé")
