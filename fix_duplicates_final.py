import re

def fix_duplicates_final():
    """Nettoyer définitivement tous les doublons et erreurs de structure"""
    
    print("🔧 Nettoyage final des doublons et erreurs de structure...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Nettoyer les doublons consécutifs
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
    
    # Corriger les problèmes de structure spécifiques
    final_lines = []
    i = 0
    while i < len(cleaned_lines):
        line = cleaned_lines[i]
        
        # Corriger les with dupliqués
        if (line.strip().startswith('with ') and 
            i + 1 < len(cleaned_lines) and 
            cleaned_lines[i + 1].strip() == line.strip()):
            print(f"Ligne {i+1}: Suppression du 'with' dupliqué")
            final_lines.append(line)
            i += 2  # Skip la ligne dupliquée
            continue
        
        # Corriger les if dupliqués
        if (line.strip().startswith('if ') and 
            i + 1 < len(cleaned_lines) and 
            cleaned_lines[i + 1].strip() == line.strip()):
            print(f"Ligne {i+1}: Suppression du 'if' dupliqué")
            final_lines.append(line)
            i += 2  # Skip la ligne dupliquée
            continue
        
        final_lines.append(line)
        i += 1
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(final_lines)
    
    print("✅ Nettoyage final terminé")
    
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
    success = fix_duplicates_final()
    if success:
        print("\n🎉 Toutes les erreurs ont été corrigées !")
        print("🚀 L'application peut maintenant être lancée !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger.")
