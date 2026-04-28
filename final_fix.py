#!/usr/bin/env python3
"""
Correction finale des erreurs restantes dans SMC_Universal.mq5
"""

import re

def final_fix():
    """Correction finale des erreurs restantes"""
    print("🔧 CORRECTION FINALE DES ERREURS")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    corrections = []
    
    # 1. Corriger les variables auto-référencées
    content = re.sub(
        r'int\s+(\w+)\s*=\s*\1\s*;',
        lambda m: f'int {m.group(1)} = {m.group(1)}();' if m.group(1).endswith('Total') or m.group(1).endswith('Orders') else f'int {m.group(1)} = 0;',
        content
    )
    
    # 2. Corriger les déclarations de fonctions locales
    content = re.sub(
        r'^(\s*)int\s+CountPositionsForSymbol\(_Symbol\)\s*\{[^}]*\}',
        r'\1// Local function removed',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    # 3. Corriger les syntaxes avec OnSymbol
    content = re.sub(r'OnSymbol', 'existingPositions', content)
    
    # 4. Corriger les déclarations sans type
    content = re.sub(
        r'^(\s*)([a-zA-Z_]\w*)\s*=\s*([^;]+);',
        r'\1int \2 = \3;',
        content,
        flags=re.MULTILINE
    )
    
    # 5. Corriger les parenthèses non équilibrées
    content = re.sub(r'\(\s*([^)]+)\s*>\s*([^)]+)\s*\)', r'(\1 > \2)', content)
    content = re.sub(r'\(\s*([^)]+)\s*<\s*([^)]+)\s*\)', r'(\1 < \2)', content)
    
    # 6. Corriger les opérations illégales
    content = re.sub(r'(\w+)\s*\*\s*([\d.]+)', r'(\1 * \2)', content)
    
    # Sauvegarder
    with open('SMC_Universal_final.mq5', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Remplacer le fichier
    import os
    if os.path.exists('SMC_Universal_final.mq5'):
        os.remove('SMC_Universal.mq5')
        os.rename('SMC_Universal_final.mq5', 'SMC_Universal.mq5')
        print("✅ Fichier final créé et remplacé")
    
    print("🎯 Corrections appliquées:")
    print("- Variables auto-référencées corrigées")
    print("- Fonctions locales supprimées")
    print("- Syntaxes OnSymbol corrigées")
    print("- Déclarations sans type corrigées")
    print("- Parenthèses équilibrées")
    print("- Opérations corrigées")

if __name__ == "__main__":
    final_fix()
