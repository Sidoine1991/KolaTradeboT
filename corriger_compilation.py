#!/usr/bin/env python3
"""
Script pour corriger les erreurs de compilation dans SMC_Universal.mq5
"""

import re

def corriger_erreurs_compilation():
    """Corriger les erreurs de compilation identifiées"""
    print("🔧 CORRECTION DES ERREURS DE COMPILATION")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    corrections = []
    
    # 1. Corriger les variables non déclarées
    corrections.append({
        'pattern': r'existingPositions',
        'replacement': 'CountPositionsForSymbol(_Symbol)',
        'description': 'Variable existingPositions non déclarée'
    })
    
    # 2. Corriger les variables totalLimitOrders non déclarées
    corrections.append({
        'pattern': r'totalLimitOrders',
        'replacement': 'CountLimitOrdersTotal()',
        'description': 'Variable totalLimitOrders non déclarée'
    })
    
    # 3. Corriger les fonctions OrderSelect incorrectes
    corrections.append({
        'pattern': r'OrderSelect\(i, SELECT_BY_POS, MODE_TRADES\)',
        'replacement': 'OrderSelect(OrderGetTicket(i))',
        'description': 'Fonction OrderSelect avec mauvais paramètres'
    })
    
    # 4. Corriger les fonctions OrderGetString incorrectes
    corrections.append({
        'pattern': r'OrderGetString\(ORDER_MAGIC\)',
        'replacement': 'IntegerToString(OrderGetInteger(ORDER_MAGIC))',
        'description': 'Fonction OrderGetString incorrecte pour ORDER_MAGIC'
    })
    
    # 5. Corriger les fonctions OrderGetString sans paramètre
    corrections.append({
        'pattern': r'OrderGetString\(\)',
        'replacement': 'OrderGetString(ORDER_COMMENT)',
        'description': 'Fonction OrderGetString sans paramètre'
    })
    
    # 6. Supprimer les lignes en dehors des fonctions
    corrections.append({
        'pattern': r'\s*for\(int i = OrdersTotal\(\) - 1; i >= 0; i--\)\s*\{[^}]*?return count;\s*\}',
        'replacement': '',
        'description': 'Code en dehors des fonctions'
    })
    
    # 7. Corriger les opérations illégales
    corrections.append({
        'pattern': r'g_lastAIConfidence \* 40\.0',
        'replacement': '(g_lastAIConfidence * 40.0)',
        'description': 'Opération illégale avec priorité'
    })
    
    # Appliquer les corrections
    corrections_appliquees = 0
    for correction in corrections:
        pattern = correction['pattern']
        replacement = correction['replacement']
        desc = correction['description']
        
        if re.search(pattern, content, re.MULTILINE | re.DOTALL):
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            corrections_appliquees += 1
            print(f"✅ Correction appliquée: {desc}")
    
    # Sauvegarder le fichier corrigé
    if corrections_appliquees > 0:
        with open('SMC_Universal_corrige.mq5', 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n✅ {corrections_appliquees} corrections appliquées")
        print("📄 Fichier créé: SMC_Universal_corrige.mq5")
        print("\n🔄 ÉTAPES SUIVANTES:")
        print("1. Remplacer SMC_Universal.mq5 par SMC_Universal_corrige.mq5")
        print("2. Compiler le robot (F7)")
        print("3. Redémarrer l'EA dans MT5")
    else:
        print("\n⚠️ Aucune correction nécessaire - le fichier semble déjà correct")

def main():
    print(f"🔧 CORRECTION COMPILATION - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    corriger_erreurs_compilation()
    
    print("\n✅ OPÉRATION TERMINÉE")
    print("\n🎯 RÉSULTAT ATTENDU:")
    print("- Toutes les erreurs de compilation corrigées")
    print("- Variables déclarées correctement")
    print("- Fonctions OrderSelect corrigées")
    print("- Code en dehors des fonctions supprimé")

if __name__ == "__main__":
    from datetime import datetime
    main()
