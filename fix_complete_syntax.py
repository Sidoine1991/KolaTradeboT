import ast
import re

def fix_complete_syntax():
    """Script complet et définitif pour corriger toutes les erreurs de syntaxe"""
    
    print("🔧 Correction complète et définitive des erreurs de syntaxe...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    
    # Variables pour suivre la structure
    indent_stack = [0]  # Stack des niveaux d'indentation
    i = 0
    
    while i < len(lines):
        line = lines[i]
        original_line = line
        
        # Calculer l'indentation actuelle
        current_indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        
        # Ignorer les lignes vides
        if not stripped:
            fixed_lines.append('')
            i += 1
            continue
        
        # Corriger l'indentation selon le contexte
        if stripped.startswith('def ') or stripped.startswith('class ') or stripped.startswith('if __name__'):
            # Définitions de fonctions/classes - niveau 0
            fixed_lines.append(stripped)
            indent_stack = [0]
        
        elif stripped.startswith('import ') or stripped.startswith('from '):
            # Imports - niveau 0
            fixed_lines.append(stripped)
        
        elif stripped.startswith('try:') or stripped.startswith('except') or stripped.startswith('finally:'):
            # Blocs try/except - maintenir l'indentation relative
            if stripped.startswith('try:'):
                # try: doit être au même niveau que le bloc précédent
                expected_indent = indent_stack[-1] if indent_stack else 0
                fixed_lines.append(' ' * expected_indent + stripped)
                indent_stack.append(expected_indent + 4)
            else:
                # except/finally au même niveau que try
                expected_indent = indent_stack[-2] if len(indent_stack) > 1 else 0
                fixed_lines.append(' ' * expected_indent + stripped)
                if stripped.startswith('except'):
                    indent_stack.append(expected_indent + 4)
        
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
            
            expected_indent = indent_stack[-1] if indent_stack else 0
            fixed_lines.append(' ' * expected_indent + stripped)
            indent_stack.append(expected_indent + 4)
        
        elif stripped.startswith('with ') or stripped.startswith('st.'):
            # Blocs with ou appels Streamlit
            expected_indent = indent_stack[-1] if indent_stack else 0
            fixed_lines.append(' ' * expected_indent + stripped)
        
        elif stripped.startswith('return ') or stripped.startswith('pass') or stripped.startswith('break') or stripped.startswith('continue'):
            # Instructions de contrôle
            expected_indent = indent_stack[-1] if indent_stack else 0
            fixed_lines.append(' ' * expected_indent + stripped)
        
        elif stripped.startswith('#') or stripped.startswith('"""') or stripped.startswith("'''"):
            # Commentaires et docstrings
            expected_indent = indent_stack[-1] if indent_stack else 0
            fixed_lines.append(' ' * expected_indent + stripped)
        
        else:
            # Autres lignes - maintenir l'indentation relative
            if current_indent > 0:
                # Ligne indentée - corriger selon le contexte
                expected_indent = indent_stack[-1] if indent_stack else 0
                fixed_lines.append(' ' * expected_indent + stripped)
            else:
                # Ligne au niveau 0
                fixed_lines.append(stripped)
                indent_stack = [0]
        
        # Ajuster la stack d'indentation
        if stripped.endswith(':'):
            # Ligne qui ouvre un bloc
            if not (stripped.startswith('except') or stripped.startswith('finally')):
                # Pas pour except/finally car déjà géré
                pass
        
        i += 1
    
    # Rejoindre les lignes
    content = '\n'.join(fixed_lines)
    
    # Nettoyer les lignes vides multiples
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    # Sauvegarder
    with open('frontend/app_real_time.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Corrections complètes appliquées")
    
    # Tester la syntaxe
    try:
        ast.parse(content)
        print("✅ Syntaxe Python valide !")
        return True
    except SyntaxError as e:
        print(f"❌ Erreur de syntaxe restante: {e}")
        print(f"   Ligne {e.lineno}: {e.text}")
        return False

if __name__ == "__main__":
    success = fix_complete_syntax()
    if success:
        print("\n🎉 Toutes les erreurs de syntaxe ont été corrigées !")
        print("🚀 L'application peut maintenant être lancée !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger manuellement.")