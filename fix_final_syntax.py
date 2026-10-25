import re

# Lire le fichier
with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Corriger l'indentation de l'except Exception as e2:
# Chercher le pattern et corriger l'indentation
lines = content.split('\n')
for i, line in enumerate(lines):
    if 'except Exception as e2:' in line and i + 1 < len(lines):
        next_line = lines[i + 1]
        if 'st.error("Indicateurs modernes indisponibles' in next_line:
            # Corriger l'indentation
            indent = len(line) - len(line.lstrip())
            lines[i + 1] = ' ' * (indent + 2) + next_line.lstrip()
            print(f"Ligne {i+2}: Indentation corrigée")

# Rejoindre les lignes
content = '\n'.join(lines)

# Sauvegarder
with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Correction finale appliquée")
