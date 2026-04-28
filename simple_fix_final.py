#!/usr/bin/env python3
"""
Correction simple et finale des erreurs
"""

import re

def simple_fix():
    """Correction simple des erreurs principales"""
    print("🔧 CORRECTION SIMPLE FINALE")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    corrections = 0
    
    # 1. Corriger les variables auto-référencées
    content = re.sub(
        r'int\s+totalLimitOrders\s*=\s*totalLimitOrders\s*;',
        'int totalLimitOrders = CountLimitOrdersTotal();',
        content
    )
    corrections += 1
    
    # 2. Corriger les types
    content = re.sub(r'int\s+direction\s*=\s*"BUY";', 'string direction = "BUY";', content)
    content = re.sub(r'int\s+direction\s*=\s*"SELL";', 'string direction = "SELL";', content)
    content = re.sub(r'int\s+entryPrice\s*=', 'double entryPrice =', content)
    corrections += 3
    
    # 3. Corriger les opérateurs
    content = re.sub(r'\s*>\s*=\s*', ' >= ', content)
    content = re.sub(r'\s*<\s*=\s*', ' <= ', content)
    corrections += 2
    
    # 4. Corriger les déclarations sans type
    content = re.sub(
        r'^(\s*)([a-zA-Z_]\w*)\s*=\s*([^;]+);',
        r'\1int \2 = \3;',
        content,
        flags=re.MULTILINE
    )
    corrections += 1
    
    # Sauvegarder
    with open('SMC_Universal_simple.mq5', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Remplacer
    import os
    if os.path.exists('SMC_Universal_simple.mq5'):
        os.remove('SMC_Universal.mq5')
        os.rename('SMC_Universal_simple.mq5', 'SMC_Universal.mq5')
        print("✅ Fichier corrigé et remplacé")
    
    print(f"\n✅ {corrections} corrections appliquées")
    print("🎯 Erreurs principales corrigées")

if __name__ == "__main__":
    simple_fix()
