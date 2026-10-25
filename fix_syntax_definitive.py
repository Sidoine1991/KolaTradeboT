import ast
import re

def fix_syntax_definitive():
    """Script définitif pour corriger toutes les erreurs de syntaxe"""
    
    print("🔧 Correction définitive des erreurs de syntaxe...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    
    # Variables pour suivre les blocs try/except
    try_stack = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Détecter les try
        if stripped.startswith('try:'):
            try_stack.append(i)
            fixed_lines.append(line)
        
        # Détecter les except
        elif stripped.startswith('except'):
            if try_stack:
                # Il y a un try correspondant
                try_stack.pop()
                fixed_lines.append(line)
            else:
                # Except orphelin - ajouter un try: avant
                indent = len(line) - len(line.lstrip())
                indent_str = ' ' * indent
                fixed_lines.append(f"{indent_str}try:")
                fixed_lines.append(f"{indent_str}  pass")
                fixed_lines.append(line)
                print(f"Ligne {i+1}: Ajouté try: pour except orphelin")
        
        # Détecter les try: vides (suivis directement d'un except)
        elif stripped == 'try:' and i + 1 < len(lines) and lines[i + 1].strip().startswith('except'):
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * (indent + 2)
            fixed_lines.append(line)
            fixed_lines.append(f"{indent_str}pass")
            print(f"Ligne {i+1}: Ajouté pass après try: vide")
        
        # Corriger les indentation errors après except
        elif stripped.startswith('except') and i + 1 < len(lines):
            next_line = lines[i + 1]
            if next_line.strip() and not next_line.startswith(' ' * (len(line) - len(line.lstrip()) + 2)):
                # Corriger l'indentation
                indent = len(line) - len(line.lstrip())
                lines[i + 1] = ' ' * (indent + 2) + next_line.lstrip()
                print(f"Ligne {i+2}: Indentation corrigée après except")
            fixed_lines.append(line)
        
        else:
            fixed_lines.append(line)
        
        i += 1
    
    # Rejoindre les lignes
    content = '\n'.join(fixed_lines)
    
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
        return False

if __name__ == "__main__":
    success = fix_syntax_definitive()
    if success:
        print("\n🎉 Toutes les erreurs de syntaxe ont été corrigées !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger manuellement.")
