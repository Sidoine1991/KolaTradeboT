import ast

def fix_function_body():
    """Corriger les fonctions sans corps"""
    
    print("🔧 Correction des fonctions sans corps...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Chercher les fonctions sans corps
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Détecter une définition de fonction
        if stripped.startswith('def ') and stripped.endswith(':'):
            # Vérifier si la ligne suivante est une docstring
            if i + 1 < len(lines):
                next_line = lines[i + 1].strip()
                if next_line.startswith('"""') or next_line.startswith("'''"):
                    # Trouver la fin de la docstring
                    j = i + 2
                    while j < len(lines):
                        if '"""' in lines[j] or "'''" in lines[j]:
                            break
                        j += 1
                    
                    # Vérifier si après la docstring il y a du code indenté
                    if j + 1 < len(lines):
                        after_docstring = lines[j + 1]
                        if not after_docstring.strip() or not after_docstring.startswith('  '):
                            # Pas de corps de fonction, ajouter pass
                            indent = len(line) - len(line.lstrip())
                            indent_str = ' ' * (indent + 2)
                            lines.insert(j + 1, f"{indent_str}pass\n")
                            print(f"Ligne {i+1}: Ajouté 'pass' pour fonction sans corps")
                            i += 1
        
        i += 1
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("✅ Corrections appliquées")
    
    # Tester la syntaxe
    try:
        with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
            content = f.read()
        ast.parse(content)
        print("✅ Syntaxe Python valide !")
        return True
    except SyntaxError as e:
        print(f"❌ Erreur de syntaxe restante: {e}")
        print(f"   Ligne {e.lineno}: {e.text}")
        return False

if __name__ == "__main__":
    success = fix_function_body()
    if success:
        print("\n🎉 Toutes les erreurs de syntaxe ont été corrigées !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger manuellement.")
