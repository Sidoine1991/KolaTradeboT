import re

def fix_final_indentation():
    """Corriger toutes les erreurs d'indentation restantes"""
    
    print("🔧 Correction finale de toutes les erreurs d'indentation...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Corrections spécifiques pour les erreurs connues
    corrections = [
        (321, "        if 'ml_predictor' not in st.session_state:"),
        (322, "            st.session_state.ml_predictor.is_trained = True"),
    ]
    
    # Appliquer les corrections spécifiques
    for line_num, new_content in corrections:
        if line_num < len(lines):
            lines[line_num] = new_content + "\n"
            print(f"Ligne {line_num + 1}: Corrigée")
    
    # Corriger les problèmes d'indentation généraux
    for i, line in enumerate(lines):
        # Corriger les lignes qui devraient être indentées après if/for/while/try/except/with
        if i > 0:
            prev_line = lines[i-1].strip()
            current_line = line.strip()
            
            # Si la ligne précédente se termine par : et la ligne actuelle n'est pas indentée
            if (prev_line.endswith(':') and 
                current_line and 
                not current_line.startswith('#') and
                not current_line.startswith('"""') and
                not current_line.startswith("'''") and
                not line.startswith('    ') and
                not line.startswith('\t') and
                not current_line.startswith('else:') and
                not current_line.startswith('elif ') and
                not current_line.startswith('except') and
                not current_line.startswith('finally:')):
                
                # Ajouter l'indentation appropriée
                if prev_line.startswith('    '):
                    lines[i] = '    ' + line.lstrip()
                elif prev_line.startswith('\t'):
                    lines[i] = '\t' + line.lstrip()
                else:
                    lines[i] = '    ' + line.lstrip()
                
                print(f"Ligne {i + 1}: Indentation corrigée")
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("✅ Corrections d'indentation finales terminées")
    
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
    success = fix_final_indentation()
    if success:
        print("\n🎉 Toutes les erreurs d'indentation ont été corrigées !")
        print("🚀 L'application peut maintenant être lancée !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger.")