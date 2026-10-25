import re

# Lire le fichier
with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Remplacer les f-strings avec {} vides par {e}
content = re.sub(r'f"([^"]*)\{\}"', r'f"\1{e}"', content)
content = re.sub(r"f'([^']*)\{\}'", r"f'\1{e}'", content)

# Écrire le fichier corrigé
with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
    f.write(content)

print('F-strings corrigées')
