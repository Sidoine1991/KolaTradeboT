import ast

def fix_final_else():
    """Corriger le else: orphelin"""
    
    print("🔧 Correction du else: orphelin...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Chercher et corriger le else: orphelin
    for i, line in enumerate(lines):
        if line.strip() == 'else:' and i > 0:
            # Vérifier si le else: est orphelin
            prev_line = lines[i-1].strip()
            if not prev_line.startswith('except') and not prev_line.startswith('finally'):
                # C'est un else: orphelin, le supprimer
                print(f"Ligne {i+1}: Suppression du else: orphelin")
                lines[i] = ''  # Remplacer par une ligne vide
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("✅ Correction appliquée")
    
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
    success = fix_final_else()
    if success:
        print("\n🎉 Toutes les erreurs de syntaxe ont été corrigées !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger manuellement.")
