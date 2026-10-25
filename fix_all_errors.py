#!/usr/bin/env python3
"""
Script pour corriger toutes les erreurs de compilation dans SMC_Universal.mq5
"""

import re

def fix_all_errors():
    """Corriger toutes les erreurs de compilation identifiées"""
    print("🔧 CORRECTION COMPLÈTE DES ERREURS")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    corrections_appliquees = 0
    
    # 1. Corriger les déclarations de variables incorrectes
    patterns_to_fix = [
        # Corriger les déclarations de variables avec noms de fonctions
        (r'int\s+CountLimitOrdersTotal\(\)\s*=\s*CountLimitOrdersTotal\(\);', 
         'int totalLimitOrders = CountLimitOrdersTotal();'),
        
        # Corriger les déclarations avec OnSymbol
        (r'int\s+CountPositionsForSymbol\(_Symbol\)OnSymbol\s*=\s*CountPositionsForSymbol\(_Symbol\);',
         'int existingPositions = CountPositionsForSymbol(_Symbol);'),
        
        # Corriger les utilisations de variables incorrectes
        (r'CountLimitOrdersTotal\(\)', 'totalLimitOrders'),
        (r'CountPositionsForSymbol\(_Symbol\)OnSymbol', 'existingPositions'),
        
        # Corriger les opérations illégales
        (r'g_lastAIConfidence\s*\*\s*40\.0', '(g_lastAIConfidence * 40.0)'),
        
        # Corriger les déclarations de fonctions locales incorrectes
        (r'int\s+CountPositionsForSymbol\(_Symbol\)\s*=', 'int existingPositions ='),
        
        # Corriger les déclarations sans type
        (r'^(\s*)CountPositionsForSymbol\(_Symbol\)\s*=', r'\1int existingPositions ='),
        
        # Corriger les syntaxes avec OnSymbol
        (r'OnSymbol\s*>\s*0', 'existingPositions > 0'),
        (r'OnSymbol\s*<\s*0', 'existingPositions < 0'),
        (r'OnSymbol\s*>=\s*0', 'existingPositions >= 0'),
        (r'OnSymbol\s*<=\s*0', 'existingPositions <= 0'),
        
        # Corriger les déclarations de variables mal formées
        (r'^(\s*)(\w+)\s*=\s*([^;]+);', r'\1int \2 = \3;'),
    ]
    
    for pattern, replacement in patterns_to_fix:
        if re.search(pattern, content, re.MULTILINE):
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            corrections_appliquees += 1
            print(f"✅ Correction appliquée: {pattern[:50]}...")
    
    # 2. Supprimer les déclarations de fonctions locales incorrectes
    local_function_patterns = [
        r'int\s+CountPositionsForSymbol\(_Symbol\)\s*\{[^}]*\}',
        r'int\s+CountLimitOrdersTotal\(\)\s*\{[^}]*\}',
    ]
    
    for pattern in local_function_patterns:
        matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
        for match in matches:
            content = content.replace(match, '')
            corrections_appliquees += 1
            print(f"✅ Fonction locale supprimée")
    
    # 3. Corriger les parenthèses non équilibrées
    content = re.sub(r'\(\s*([a-zA-Z_]\w*)\s*>\s*([0-9.]+)\s*\)', r'(\1 > \2)', content)
    content = re.sub(r'\(\s*([a-zA-Z_]\w*)\s*<\s*([0-9.]+)\s*\)', r'(\1 < \2)', content)
    
    # 4. Corriger les conversions implicites
    content = re.sub(r'CountPositionsForSymbol\(_Symbol\)', 'CountPositionsForSymbol(_Symbol)', content)
    
    # Sauvegarder le fichier corrigé
    with open('SMC_Universal_fixed.mq5', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n✅ {corrections_appliquees} corrections appliquées")
    print("📄 Fichier créé: SMC_Universal_fixed.mq5")
    
    # Remplacer le fichier original
    import os
    if os.path.exists('SMC_Universal_fixed.mq5'):
        os.remove('SMC_Universal.mq5')
        os.rename('SMC_Universal_fixed.mq5', 'SMC_Universal.mq5')
        print("🔄 Fichier original remplacé")

def main():
    print(f"🔧 CORRECTION COMPLÈTE - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    fix_all_errors()
    
    print("\n✅ OPÉRATION TERMINÉE")
    print("\n🎯 RÉSULTAT ATTENDU:")
    print("- Toutes les erreurs de compilation corrigées")
    print("- Variables déclarées correctement")
    print("- Syntaxe MQL5 respectée")
    print("- Fichier prêt à compiler")

if __name__ == "__main__":
    from datetime import datetime
    main()
