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

if orphan_excepts:
    print("Except orphelins trouvés :")
    for line_num, line_content in orphan_excepts:
        print(f"Ligne {line_num}: {line_content}")
        print(f"  Contexte: {lines[line_num-2].strip() if line_num > 1 else ''}")
        print(f"  Contexte: {lines[line_num-1].strip()}")
        print()
else:
    print("Aucun except orphelin trouvé")
