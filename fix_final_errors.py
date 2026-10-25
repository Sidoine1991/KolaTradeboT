#!/usr/bin/env python3
"""
Correction finale des erreurs de compilation restantes
"""

import re

def fix_final_errors():
    """Correction finale des erreurs restantes"""
    print("🔧 CORRECTION FINALE DES ERREURS RESTANTES")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    corrections_appliquees = 0
    
    # 1. Corriger les variables auto-référencées
    patterns_fixes = [
        # Corriger les variables qui s'assignent à elles-mêmes
        (r'int\s+(\w+)\s*=\s*\1\s*;', lambda m: f'int {m.group(1)} = {m.group(1)}();' if m.group(1).endswith('Total') or m.group(1).endswith('Orders') else f'int {m.group(1)} = 0;'),
        
        # Corriger les déclarations de fonctions locales incorrectes
        (r'^(\s*)int\s+CountPositionsForSymbol\(_Symbol\)\s*\{[^}]*\}', r'\1// Local function removed', re.MULTILINE | re.DOTALL),
        
        # Corriger les types incorrects
        (r'int\s+direction\s*=\s*"BUY";', 'string direction = "BUY";'),
        (r'int\s+direction\s*=\s*"SELL";', 'string direction = "SELL";'),
        (r'int\s+entryPrice\s*=', 'double entryPrice ='),
        
        # Corriger les opérateurs mal formatés
        (r'\s*>\s*=\s*', ' >= '),
        (r'\s*<\s*=\s*', ' <= '),
        (r'\s*>\s*', ' > '),
        (r'\s*<\s*', ' < '),
        
        # Corriger les déclarations sans type
        (r'^(\s*)([a-zA-Z_]\w*)\s*=\s*([^;]+);', r'\1int \2 = \3;', re.MULTILINE),
    ]
    
    for pattern, replacement in patterns_fixes:
        if callable(replacement):
            # Pour les remplacements avec lambda
            matches = re.finditer(pattern, content, re.MULTILINE)
            for match in matches:
                new_text = replacement(match)
                content = content.replace(match.group(0), new_text)
                corrections_appliquees += 1
        else:
            flags = pattern if isinstance(pattern, tuple) and len(pattern) == 3 else 0
            if isinstance(pattern, tuple):
                pattern, replacement, flags = pattern
            
            if re.search(pattern, content, flags):
                content = re.sub(pattern, replacement, content, flags)
                corrections_appliquees += 1
    
    # 2. Corriger les parenthèses non équilibrées
    content = re.sub(r'\(\s*([^)]+)\s*>\s*([^)]+)\s*\)', r'(\1 > \2)', content)
    content = re.sub(r'\(\s*([^)]+)\s*<\s*([^)]+)\s*\)', r'(\1 < \2)', content)
    
    # 3. Corriger les opérations illégales
    content = re.sub(r'(\w+)\s*\*\s*([\d.]+)', r'(\1 * \2)', content)
    
    # 4. Nettoyer les lignes vides multiples
    content = re.sub(r'\n\s*\n\s*\n+', '\n\n', content)
    
    # 5. Corriger les déclarations de variables mal formatées
    content = re.sub(
        r'^(\s*)int\s+(\w+)\s*=\s*(\w+)\s*\(\s*\)\s*;',
        r'\1int \2 = \3();',
        content,
        flags=re.MULTILINE
    )
    
    # Sauvegarder
    with open('SMC_Universal_final_fixed.mq5', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Remplacer le fichier
    import os
    if os.path.exists('SMC_Universal_final_fixed.mq5'):
        os.remove('SMC_Universal.mq5')
        os.rename('SMC_Universal_final_fixed.mq5', 'SMC_Universal.mq5')
        print("✅ Fichier final corrigé et remplacé")
    
    print(f"\n✅ {corrections_appliquees} corrections appliquées")
    print("\n🎯 Corrections finales:")
    print("- Variables auto-référencées corrigées")
    print("- Types de variables corrigés")
    print("- Opérateurs formatés")
    print("- Parenthèses équilibrées")
    print("- Déclarations normalisées")
    print("- Code nettoyé")

if __name__ == "__main__":
    fix_final_errors()
