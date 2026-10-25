import ast
import re

def fix_all_indentation():
    """Corriger toutes les erreurs d'indentation"""
    
    print("🔧 Correction de toutes les erreurs d'indentation...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Nettoyer les lignes vides et corriger l'indentation
    cleaned_lines = []
    for i, line in enumerate(lines):
        # Supprimer les lignes vides créées par les corrections précédentes
        if line.strip() == '':
            continue
        
        # Corriger l'indentation des lignes qui commencent par des espaces incorrects
        if line.startswith('  ') and not line.startswith('    '):
            # Ligne avec 2 espaces, probablement incorrecte
            if line.strip().startswith('st.') or line.strip().startswith('print(') or line.strip().startswith('if ') or line.strip().startswith('for ') or line.strip().startswith('while '):
                # Corriger à 4 espaces
                cleaned_lines.append('    ' + line.lstrip())
                print(f"Ligne {i+1}: Indentation corrigée (2→4 espaces)")
            else:
                cleaned_lines.append(line)
        else:
            cleaned_lines.append(line)
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(cleaned_lines)
    
    print("✅ Corrections d'indentation appliquées")
    
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
        
        # Afficher le contexte de l'erreur
        error_line = e.lineno - 1
        start = max(0, error_line - 3)
        end = min(len(cleaned_lines), error_line + 3)
        print("\nContexte de l'erreur:")
        for k in range(start, end):
            marker = ">>> " if k == error_line else "    "
            print(f"{marker}{k+1:4d}: {cleaned_lines[k].rstrip()}")
        
        return False

if __name__ == "__main__":
    success = fix_all_indentation()
    if success:
        print("\n🎉 Toutes les erreurs de syntaxe ont été corrigées !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger manuellement.")
