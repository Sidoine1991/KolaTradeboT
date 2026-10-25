import re

def fix_all_indentation():
    """Corriger toutes les erreurs d'indentation dans le fichier"""
    
    print("🔧 Correction de toutes les erreurs d'indentation...")
    
    # Lire le fichier
    with open('frontend/app_real_time.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Corrections spécifiques
    corrections = [
        # Ligne 60 - import sous try
        (59, "        try:"),
        (60, "            from frontend.whatsapp_notify import send_whatsapp_message_unified"),
        
        # Autres corrections d'indentation communes
        (61, "            "),
        (62, "            # Calculer les pips"),
        (63, "            pip_size = 0.0001 if \"JPY\" not in symbol else 0.01"),
    ]
    
    # Appliquer les corrections
    for line_num, new_content in corrections:
        if line_num < len(lines):
            lines[line_num] = new_content + "\n"
            print(f"Ligne {line_num + 1}: Corrigée")
    
    # Corriger les problèmes d'indentation généraux
    for i, line in enumerate(lines):
        # Corriger les lignes qui devraient être indentées après try/except/if/for/while
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
                not line.startswith('\t')):
                
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
    
    print("✅ Corrections d'indentation terminées")
    
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
    success = fix_all_indentation()
    if success:
        print("\n🎉 Toutes les erreurs d'indentation ont été corrigées !")
        print("🚀 L'application peut maintenant être lancée !")
    else:
        print("\n⚠️ Il reste des erreurs à corriger.")
