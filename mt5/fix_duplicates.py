import re
import os

def clean_mql_file(file_path):
    print(f"Début du nettoyage du fichier: {file_path}")
    
    # Lire le fichier d'entrée
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Créer une sauvegarde
    backup_path = file_path + '.bak'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Sauvegarde créée: {backup_path}")
    
    # Dictionnaires pour suivre les éléments vus
    global_vars = {}
    functions = {}
    includes = set()
    
    # Nouvelles lignes nettoyées
    cleaned_lines = []
    
    # Variables d'état
    in_function = False
    in_global_scope = True
    current_function = None
    function_lines = []
    in_comment_block = False
    brace_count = 0
    
    # Expressions régulières pour détecter les patterns courants
    var_decl_pattern = r'^\s*([a-zA-Z_][a-zA-Z0-9_]*\s+[a-zA-Z_][a-zA-Z0-9_]*)\s*(?:=|;)'
    func_decl_pattern = r'^([a-zA-Z_][a-zA-Z0-9_]*\s+[a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*\{?$'
    include_pattern = r'^\s*#include\s+[<"]([^>"]+)[>"]'
    
    # Parcourir le fichier ligne par ligne
    lines = content.split('\n')
    i = 0
    
    while i < len(lines):
        line = lines[i]
        stripped_line = line.strip()
        
        # Gérer les directives de préprocesseur
        if stripped_line.startswith('#'):
            # Gérer les #include
            include_match = re.match(include_pattern, stripped_line)
            if include_match:
                include_file = include_match.group(1)
                if include_file not in includes:
                    includes.add(include_file)
                    cleaned_lines.append(line)
                else:
                    print(f"Fichier include en double supprimé: {include_file}")
            else:
                cleaned_lines.append(line)
            i += 1
            continue
            
        # Gérer les blocs de commentaires
        if '/*' in stripped_line and '*/' not in stripped_line:
            in_comment_block = True
            cleaned_lines.append(line)
            i += 1
            continue
            
        if '*/' in stripped_line and in_comment_block:
            in_comment_block = False
            cleaned_lines.append(line)
            i += 1
            continue
            
        if in_comment_block:
            cleaned_lines.append(line)
            i += 1
            continue
            
        # Ignorer les commentaires de ligne pour le traitement
        clean_line = stripped_line.split('//')[0].strip()
        
        # Détecter le début d'une fonction
        func_match = re.match(func_decl_pattern, clean_line)
        if func_match and not in_function:
            in_function = True
            in_global_scope = False
            func_decl = func_match.group(1)
            func_name = func_decl.split()[-1]  # Prendre le dernier mot comme nom de fonction
            current_function = func_name
            function_lines = [line]
            brace_count = 1 if '{' in clean_line else 0
            i += 1
            continue
        
        # Si nous sommes dans une fonction
        if in_function:
            function_lines.append(line)
            
            # Compter les accolades pour détecter la fin de la fonction
            brace_count += line.count('{')
            brace_count -= line.count('}')
            
            # Détecter la fin d'une fonction
            if brace_count <= 0 and (line.strip() == '}' or line.strip().endswith('};')):
                in_function = False
                in_global_scope = True
                
                # Vérifier si cette fonction a déjà été vue
                if current_function in functions:
                    print(f"Fonction en double supprimée: {current_function}")
                else:
                    functions[current_function] = True
                    cleaned_lines.extend(function_lines)
                
                current_function = None
                function_lines = []
                brace_count = 0
            
            i += 1
            continue
        
        # Si nous sommes dans la portée globale
        if in_global_scope:
            # Ignorer les lignes vides et les commentaires
            if not clean_line:
                cleaned_lines.append(line)
                i += 1
                continue
                
            # Détecter les déclarations de variables globales
            var_match = re.match(var_decl_pattern, clean_line)
            if var_match:
                var_decl = var_match.group(1).strip()
                if var_decl in global_vars:
                    print(f"Variable globale en double supprimée: {var_decl}")
                    i += 1
                    continue
                else:
                    global_vars[var_decl] = True
                    cleaned_lines.append(line)
                    i += 1
                    continue
            
            # Ignorer le code exécutable dans la portée globale
            if any(keyword in clean_line for keyword in ['if', 'for', 'while', 'switch', 'return', 'break', 'continue']):
                print(f"Code exécutable ignoré dans la portée globale: {clean_line[:50]}...")
                i += 1
                continue
        
        # Ajouter la ligne nettoyée
        cleaned_lines.append(line)
        i += 1
    
    # Reconstruire le contenu nettoyé
    cleaned_content = '\n'.join(cleaned_lines)
    
    # Écrire directement dans le fichier original
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(cleaned_content)
    
    # Afficher un résumé des modifications
    print("\nRésumé des modifications:")
    print(f"- {len(global_vars)} variables globales uniques conservées")
    print(f"- {len(functions)} fonctions uniques conservées")
    print(f"- {len(includes)} fichiers includes uniques détectés")
    print(f"\nNettoyage terminé. Fichier original mis à jour: {file_path}")
    print(f"Une sauvegarde a été créée: {backup_path}")
    
    # Afficher des recommandations pour les prochaines étapes
    print("\nRecommandations pour les prochaines étapes:")
    print("1. Vérifiez les erreurs de compilation restantes dans MetaEditor")
    print("2. Si des erreurs persistent, examinez le fichier de sauvegarde (.bak) pour récupérer du code si nécessaire")
    print("3. Consultez la documentation MQL5 pour les erreurs spécifiques restantes")
    
    return {
        'variables_conservées': len(global_vars),
        'fonctions_conservées': len(functions),
        'includes': len(includes),
        'fichier_sortie': file_path,
        'sauvegarde': backup_path
    }

if __name__ == "__main__":
    file_to_clean = r"d:\Dev\TradBOT\mt5\F_INX_robot4.mq5"
    clean_mql_file(file_to_clean)
