#!/usr/bin/env python3
"""
Nettoyage final de la syntaxe dans SMC_Universal.mq5
"""

import re

def clean_syntax():
    """Nettoyage final de la syntaxe"""
    print("🧹 NETTOYAGE FINAL DE LA SYNTAXE")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    # Corriger les espaces dans les opérateurs
    content = re.sub(r'\s*>\s*=\s*', ' >= ', content)
    content = re.sub(r'\s*<\s*=\s*', ' <= ', content)
    content = re.sub(r'\s*>\s*', ' > ', content)
    content = re.sub(r'\s*<\s*', ' < ', content)
    content = re.sub(r'\s*\*\s*', ' * ', content)
    content = re.sub(r'\s*=\s*', ' = ', content)
    
    # Corriger les parenthèses mal formatées
    content = re.sub(r'\(\s*([^)]+)\s*\)', r'(\1)', content)
    
    # Corriger les déclarations de variables mal formatées
    content = re.sub(r'^(\s*)int\s+(\w+)\s*=\s*(\w+)\s*\(\s*\)\s*;', r'\1int \2 = \3();', content, flags=re.MULTILINE)
    
    # Nettoyer les lignes vides multiples
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    # Sauvegarder
    with open('SMC_Universal_clean.mq5', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Remplacer le fichier
    import os
    if os.path.exists('SMC_Universal_clean.mq5'):
        os.remove('SMC_Universal.mq5')
        os.rename('SMC_Universal_clean.mq5', 'SMC_Universal.mq5')
        print("✅ Fichier nettoyé et remplacé")
    
    print("🎯 Nettoyage appliqué:")
    print("- Opérateurs formatés correctement")
    print("- Parenthèses nettoyées")
    print("- Déclarations corrigées")
    print("- Espaces normalisés")

if __name__ == "__main__":
    clean_syntax()
