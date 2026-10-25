import ast
import re

def fix_remaining_syntax():
    """Corriger les erreurs de syntaxe restantes"""
    
    print("🔧 Correction des erreurs restantes...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    # Analyser la structure try/except/finally
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Chercher les try sans except/finally correspondant
        if stripped == 'try:' or stripped.startswith('try:'):
            # Trouver le bloc try correspondant
            try_indent = len(line) - len(line.lstrip())
            j = i + 1
            found_except = False
            found_finally = False
            
            while j < len(lines):
                next_line = lines[j]
                next_stripped = next_line.strip()
                next_indent = len(next_line) - len(next_line.lstrip())
                
                # Si on trouve un except ou finally au même niveau
                if next_indent == try_indent and (next_stripped.startswith('except') or next_stripped.startswith('finally')):
                    found_except = True
                    break
                
                # Si on trouve un bloc au niveau supérieur, on sort du try
                if next_stripped and next_indent <= try_indent:
                    break
                
                j += 1
            
            # Si pas d'except trouvé, ajouter un except: pass
            if not found_except:
                indent_str = ' ' * try_indent
                lines.insert(j, f"{indent_str}except Exception:")
                lines.insert(j + 1, f"{indent_str}  pass")
                print(f"Ligne {i+1}: Ajouté except: pass pour try orphelin")
                i += 2  # Skip les lignes ajoutées
        
        i += 1
    
    # Rejoindre les lignes
    content = '\n'.join(lines)
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Corrections appliquées")
    
    # Tester la syntaxe
    try:
        ast.parse(content)
        print("✅ Syntaxe Python valide !")
        return True
    except SyntaxError as e:
        print(f"❌ Erreur de syntaxe restante: {e}")
        print(f"   Ligne {e.lineno}: {e.text}")
        
        # Afficher le contexte de l'erreur
        error_line = e.lineno - 1
        start = max(0, error_line - 3)
        end = min(len(lines), error_line + 3)
        print("\nContexte de l'erreur:")
        for k in range(start, end):
            marker = ">>> " if k == error_line else "    "
            print(f"{marker}{k+1:4d}: {lines[k]}")
        
        return False

if __name__ == "__main__":
    success = fix_remaining_syntax()
    if success:
        print("\n🎉 Toutes les erreurs de syntaxe ont été corrigées !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger manuellement.")
