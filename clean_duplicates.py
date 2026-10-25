import re

def clean_duplicates():
    """Nettoyer les lignes dupliquées"""
    
    print("🔧 Nettoyage des lignes dupliquées...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Supprimer les lignes dupliquées consécutives
    cleaned_lines = []
    prev_line = None
    
    for i, line in enumerate(lines):
        # Ignorer les lignes vides
        if not line.strip():
            cleaned_lines.append(line)
            prev_line = None
            continue
        
        # Si la ligne est différente de la précédente, l'ajouter
        if line != prev_line:
            cleaned_lines.append(line)
            prev_line = line
        else:
            print(f"Ligne {i+1}: Suppression du doublon")
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(cleaned_lines)
    
    print("✅ Nettoyage terminé")
    
    # Tester la syntaxe
    try:
        import ast
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
    success = clean_duplicates()
    if success:
        print("\n🎉 Le fichier a été nettoyé avec succès !")
        print("🚀 L'application peut maintenant être lancée !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger.")
