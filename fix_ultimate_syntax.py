import ast
import re

def fix_ultimate_syntax():
    """Script ultime pour corriger toutes les erreurs de syntaxe"""
    
    print("🔧 Correction ultime de toutes les erreurs de syntaxe...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Ignorer les lignes vides
        if not stripped:
            fixed_lines.append('')
            i += 1
            continue
        
        # Corriger les problèmes d'indentation spécifiques
        if stripped.startswith('return ') or stripped.startswith('pass') or stripped.startswith('break') or stripped.startswith('continue'):
            # Ces instructions doivent être indentées
            if not line.startswith('    '):
                # Trouver le niveau d'indentation approprié
                indent_level = 4  # Niveau par défaut
                fixed_lines.append(' ' * indent_level + stripped)
            else:
                fixed_lines.append(line)
        
        elif stripped.startswith('if ') or stripped.startswith('elif ') or stripped.startswith('else:') or stripped.startswith('for ') or stripped.startswith('while '):
            # Structures de contrôle
            if stripped == 'else:' and i > 0:
                # Vérifier si c'est un else: orphelin
                prev_line = lines[i-1].strip()
                if not (prev_line.startswith('except') or prev_line.startswith('finally')):
                    # else: orphelin, l'ignorer
                    print(f"Ligne {i+1}: Suppression du else: orphelin")
                    i += 1
                    continue
            
            fixed_lines.append(line)
        
        elif stripped.startswith('try:') or stripped.startswith('except') or stripped.startswith('finally:'):
            # Blocs try/except
            fixed_lines.append(line)
        
        elif stripped.startswith('def ') or stripped.startswith('class '):
            # Définitions
            fixed_lines.append(line)
        
        elif stripped.startswith('import ') or stripped.startswith('from '):
            # Imports
            fixed_lines.append(line)
        
        elif stripped.startswith('st.') or stripped.startswith('print(') or stripped.startswith('with '):
            # Appels Streamlit et autres
            if not line.startswith('    '):
                # Indenter si nécessaire
                fixed_lines.append('    ' + stripped)
            else:
                fixed_lines.append(line)
        
        elif stripped.startswith('#') or stripped.startswith('"""') or stripped.startswith("'''"):
            # Commentaires et docstrings
            fixed_lines.append(line)
        
        else:
            # Autres lignes
            fixed_lines.append(line)
        
        i += 1
    
    # Rejoindre les lignes
    content = '\n'.join(fixed_lines)
    
    # Nettoyer les lignes vides multiples
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Corrections ultimes appliquées")
    
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
            print(f"{marker}{k+1:4d}: {lines[k].rstrip()}")
        
        return False

if __name__ == "__main__":
    success = fix_ultimate_syntax()
    if success:
        print("\n🎉 Toutes les erreurs de syntaxe ont été corrigées !")
        print("🚀 L'application peut maintenant être lancée !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger manuellement.")
