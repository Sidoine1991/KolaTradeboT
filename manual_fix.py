#!/usr/bin/env python3
"""
Correction manuelle précise des erreurs de compilation dans SMC_Universal.mq5
"""

import re

def manual_fix():
    """Correction manuelle précise"""
    print("🔧 CORRECTION MANUELLE PRÉCISE")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    corrections_appliquees = 0
    
    # 1. Corriger les variables non déclarées
    corrections = [
        # Variables non déclarées
        (r'existingPositions', 'CountPositionsForSymbol(_Symbol)'),
        
        # Corriger les déclarations de variables incorrectes
        (r'int\s+CountLimitOrdersTotal\(\)\s*=\s*CountLimitOrdersTotal\(\);', 
         'int totalLimitOrders = CountLimitOrdersTotal();'),
        
        # Corriger les utilisations incorrectes
        (r'CountLimitOrdersTotal\(\)', 'totalLimitOrders'),
        
        # Corriger les opérations illégales
        (r'g_lastAIConfidence\s*\*\s*40\.0', '(g_lastAIConfidence * 40.0)'),
        
        # Corriger les déclarations avec OnSymbol
        (r'int\s+CountPositionsForSymbol\(_Symbol\)OnSymbol\s*=\s*CountPositionsForSymbol\(_Symbol\);',
         'int existingPositions = CountPositionsForSymbol(_Symbol);'),
        
        (r'CountPositionsForSymbol\(_Symbol\)OnSymbol', 'existingPositions'),
        
        # Corriger les déclarations de fonctions locales incorrectes
        (r'^(\s*)int\s+CountPositionsForSymbol\(_Symbol\)\s*\{[^}]*\}',
         r'\1// Local function removed',
         re.MULTILINE | re.DOTALL),
    ]
    
    for correction in corrections:
        if len(correction) == 2:
            pattern, replacement = correction
            flags = 0
        else:
            pattern, replacement, flags = correction
        
        if re.search(pattern, content, flags):
            content = re.sub(pattern, replacement, content, flags)
            corrections_appliquees += 1
            print(f"✅ Correction: {pattern[:50]}...")
    
    # 2. Supprimer le code en dehors des fonctions
    patterns_to_remove = [
        r'\n\s*for\(int i = OrdersTotal\(\) - 1; i >= 0; i--\)\s*\{[^}]*?return count;\s*\}',
        r'\n\s*int\s+count\s*=\s*0;\s*for\(int i = 0; i < OrdersTotal\(\); i\+\+\)\s*\{[^}]*?return count;\s*\}',
    ]
    
    for pattern in patterns_to_remove:
        matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
        for match in matches:
            content = content.replace(match, '')
            corrections_appliquees += 1
            print(f"✅ Suppression code hors fonction")
    
    # 3. Corriger les déclarations de variables mal formatées
    content = re.sub(
        r'^(\s*)([a-zA-Z_]\w*)\s*=\s*([^;]+);',
        lambda m: f'{m.group(1)}int {m.group(2)} = {m.group(3)};' if not m.group(1).strip().startswith('//') else m.group(0),
        content,
        flags=re.MULTILINE
    )
    
    # 4. Corriger les parenthèses et opérateurs
    content = re.sub(r'\(\s*([^)]+)\s*>\s*([^)]+)\s*\)', r'(\1 > \2)', content)
    content = re.sub(r'\(\s*([^)]+)\s*<\s*([^)]+)\s*\)', r'(\1 < \2)', content)
    content = re.sub(r'\s*>\s*=\s*', ' >= ', content)
    content = re.sub(r'\s*<\s*=\s*', ' <= ', content)
    
    # 5. Corriger les types incorrects
    content = re.sub(r'int\s+direction\s*=\s*"BUY";', 'string direction = "BUY";', content)
    content = re.sub(r'int\s+direction\s*=\s*"SELL";', 'string direction = "SELL";', content)
    content = re.sub(r'int\s+entryPrice\s*=', 'double entryPrice =', content)
    
    # Sauvegarder
    with open('SMC_Universal_manual.mq5', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Remplacer le fichier
    import os
    if os.path.exists('SMC_Universal_manual.mq5'):
        os.remove('SMC_Universal.mq5')
        os.rename('SMC_Universal_manual.mq5', 'SMC_Universal.mq5')
        print("✅ Fichier corrigé et remplacé")
    
    print(f"\n✅ {corrections_appliquees} corrections appliquées")
    print("\n🎯 Corrections principales:")
    print("- Variables non déclarées corrigées")
    print("- Déclarations incorrectes fixées")
    print("- Code hors fonctions supprimé")
    print("- Types de variables corrigés")
    print("- Opérateurs formatés")

if __name__ == "__main__":
    manual_fix()
