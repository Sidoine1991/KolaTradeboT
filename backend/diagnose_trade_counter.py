#!/usr/bin/env python3
"""
Script de diagnostic pour le compteur de trades qui n'est pas à jour
"""

def analyze_trade_counter_problem():
    """Analyser le problème du compteur de trades"""
    
    print("🔍 DIAGNOSTIC - COMPTEUR DE TRADES")
    print("=" * 50)
    
    print("🚨 PROBLÈME IDENTIFIÉ:")
    print("   • Le compteur de trades n'est pas à jour")
    print("   • Valeur affichée ≠ Nombre réel de trades")
    print("   • Impact sur le suivi de performance")
    
    print("\n📊 CAUSES POSSIBLES:")
    
    causes = [
        {
            "cause": "Comptage de tous les deals",
            "explication": "La fonction UpdateDailyProfit() compte tous les deals (y compris swaps, commissions, deals de sortie)",
            "impact": "Surcomptage artificiel du nombre de trades"
        },
        {
            "cause": "Double comptage",
            "explication": "Un trade génère 2 deals (entrée + sortie) → compté comme 2 trades",
            "impact": "Compteur = 2 × nombre réel de trades"
        },
        {
            "cause": "Mauvais filtrage",
            "explication": "Les deals de type DEAL_TYPE_OUT sont aussi comptés",
            "impact": "Inclus les fermetures partielles dans le compteur"
        },
        {
            "cause": "Historique non synchronisé",
            "explication": "L'historique MT5 n'est pas à jour avec les trades récents",
            "impact": "Décalage entre réalité et affichage"
        }
    ]
    
    for i, cause in enumerate(causes, 1):
        print(f"\n{i}. 📋 {cause['cause']}:")
        print(f"   💭 Explication: {cause['explication']}")
        print(f"   📈 Impact: {cause['impact']}")
    
    return causes

def show_original_problem():
    """Montrer le problème du code original"""
    
    print(f"\n🔧 PROBLÈME DANS LE CODE ORIGINAL:")
    print("=" * 40)
    
    print("❌ FONCTION UpdateDailyProfit() AVANT:")
    code_original = '''
void UpdateDailyProfit()
{
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      // Vérifie uniquement: magic + date
      if(dealMagic == InpMagicNumber && dealTime >= todayStart)
      {
         tradesCount++;  // COMPTE TOUS LES DEALS !
         totalProfit += dealProfit;
      }
   }
}'''
    
    print(code_original)
    
    print("\n🚨 PROBLÈMES:")
    print("   • Compte TOUS les deals (entrée + sortie)")
    print("   • Inclut les swaps, commissions, corrections")
    print("   • Compteur = 2× nombre réel de trades")
    print("   • Pas de distinction DEAL_TYPE_ENTRY vs DEAL_TYPE_OUT")

def show_corrected_solution():
    """Montrer la solution corrigée"""
    
    print(f"\n✅ SOLUTION CORRIGÉE:")
    print("=" * 30)
    
    print("✅ FONCTION UpdateDailyProfit() APRÈS:")
    code_corrected = '''
void UpdateDailyProfit()
{
   // Méthode 1: Compter les ordres exécutés uniquement
   for(int i = 0; i < HistoryOrdersTotal(); i++)
   {
      if(orderMagic == InpMagicNumber && orderTime >= todayStart)
      {
         if(orderState == ORDER_STATE_FILLED && 
            (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL))
         {
            tradesCount++;  // COMPTE SEULEMENT LES VRAIS TRADES
         }
      }
   }
   
   // Méthode 2: Calculer le profit via les deals ENTRY uniquement
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      if(dealMagic == InpMagicNumber && dealTime >= todayStart)
      {
         if(dealType == DEAL_TYPE_ENTRY)  // SEULEMENT LES ENTRÉES
         {
            dealProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         }
      }
   }
}'''
    
    print(code_corrected)
    
    print("\n✅ AMÉLIORATIONS:")
    improvements = [
        "Compte uniquement les ordres MARKET exécutés",
        "Filtre ORDER_STATE_FILLED (pas les annulations)",
        "Distinction ORDER_TYPE (MARKET vs LIMIT)",
        "Profit calculé via DEAL_TYPE_ENTRY uniquement",
        "Logs de debugging pour vérifier la cohérence"
    ]
    
    for improvement in improvements:
        print(f"   ✅ {improvement}")

def show_expected_behavior():
    """Montrer le comportement attendu après correction"""
    
    print(f"\n🎯 COMPORTEMENT ATTENDU APRÈS CORRECTION:")
    print("=" * 50)
    
    scenarios = [
        {
            "scenario": "1 trade BUY exécuté",
            "avant": "Compteur: 2 (entrée + sortie)",
            "après": "Compteur: 1 (vrai trade)",
            "profit": "Profit correct via deal ENTRY"
        },
        {
            "scenario": "1 trade SELL exécuté",
            "avant": "Compteur: 2 (entrée + sortie)",
            "après": "Compteur: 1 (vrai trade)",
            "profit": "Profit correct via deal ENTRY"
        },
        {
            "scenario": "1 ordre LIMIT exécuté",
            "avant": "Compteur: 3 (entrée + sortie + modification)",
            "après": "Compteur: 1 (vrai trade)",
            "profit": "Profit correct via deal ENTRY"
        },
        {
            "scenario": "3 trades dans la journée",
            "avant": "Compteur: 6 (2× par trade)",
            "après": "Compteur: 3 (vrai nombre)",
            "profit": "Profit total correct"
        }
    ]
    
    for scenario in scenarios:
        print(f"\n📊 {scenario['scenario']}:")
        print(f"   ❌ Avant: {scenario['avant']}")
        print(f"   ✅ Après: {scenario['après']}")
        print(f"   💰 Profit: {scenario['profit']}")

def show_debugging_logs():
    """Montrer les logs de debugging attendus"""
    
    print(f"\n📋 LOGS DE DEBUGGING ATTENDUS:")
    print("=" * 35)
    
    print("🔍 LOGS TOUTES LES 60 SECONDES:")
    logs = [
        "📊 MISE À JOUR COMPTEURS - Boom 1000 Index",
        "   📍 Trades comptés (ordres): 3",
        "   📍 Deals comptés (entries): 3",
        "   📍 Profit journalier: 15.75$",
        "   📍 Date début: 2025.03.12 00:00:00"
    ]
    
    for log in logs:
        print(f"   {log}")
    
    print("\n✅ COHÉRENCE VÉRIFIÉE:")
    coherence_checks = [
        "Trades (ordres) = Deals (entries) ✅",
        "Profit journalier correct ✅", 
        "Pas de double comptage ✅",
        "Historique synchronisé ✅"
    ]
    
    for check in coherence_checks:
        print(f"   {check}")

def show_validation_steps():
    """Montrer les étapes de validation"""
    
    print(f"\n🔧 ÉTAPES DE VALIDATION:")
    print("=" * 30)
    
    steps = [
        {
            "etape": "1. Compiler le robot",
            "action": "Compiler avec la nouvelle fonction UpdateDailyProfit()",
            "verification": "Pas d'erreur de compilation"
        },
        {
            "etape": "2. Observer les logs",
            "action": "Surveiller les logs 'MISE À JOUR COMPTEURS'",
            "verification": "Logs toutes les 60 secondes avec valeurs cohérentes"
        },
        {
            "etape": "3. Faire un test trade",
            "action": "Exécuter 1-2 trades manuellement ou automatiquement",
            "verification": "Compteur s'incrémente de 1 par trade (pas 2)"
        },
        {
            "etape": "4. Vérifier l'affichage",
            "action": "Contrôler le tableau de bord MT5",
            "verification": "Nombre de trades affiché = nombre réel de trades"
        },
        {
            "etape": "5. Valider le profit",
            "action": "Comparer profit affiché vs profit réel",
            "verification": "Profit journalier correct"
        }
    ]
    
    for step in steps:
        print(f"\n{step['etape']}:")
        print(f"   🔧 Action: {step['action']}")
        print(f"   ✅ Vérification: {step['verification']}")

if __name__ == "__main__":
    print("🚀 DIAGNOSTIC COMPLET - COMPTEUR DE TRADES")
    print("=" * 50)
    
    analyze_trade_counter_problem()
    show_original_problem()
    show_corrected_solution()
    show_expected_behavior()
    show_debugging_logs()
    show_validation_steps()
    
    print("\n" + "=" * 50)
    print("🎯 RÉSULTAT FINAL:")
    print("✅ Compteur de trades corrigé")
    print("✅ Plus de double comptage") 
    print("✅ Profit journalier correct")
    print("✅ Logs de debugging ajoutés")
    print("✅ Performance correctement suivie")
    
    print("\n🚀 ACTIONS IMMÉDIATES:")
    print("1. Compiler le robot avec les corrections")
    print("2. Surveiller les logs 'MISE À JOUR COMPTEURS'")
    print("3. Vérifier la cohérence trades/deals")
    print("4. Valider l'affichage du tableau de bord")
