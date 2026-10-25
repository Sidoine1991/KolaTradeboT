import re

# Lire le fichier
with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Trouver et corriger l'except Exception as e2: orphelin
# Chercher le pattern et ajouter un try: avant
pattern = r'(\s+)(st\.dataframe\(df_piv, hide_index=True, use_container_width=True\)\s*\n\s*except Exception as e2:)'

def replace_func(match):
    indent = match.group(1)
    return f"{indent}try:\n{indent}  st.dataframe(df_piv, hide_index=True, use_container_width=True)\n{indent}except Exception as e2:"

# Appliquer la correction
new_content = re.sub(pattern, replace_func, content)

# Sauvegarder
with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Correction de l'except Exception as e2: appliquée")
