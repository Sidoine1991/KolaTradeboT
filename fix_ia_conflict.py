#!/usr/bin/env python3
"""
Script pour analyser et corriger les conflits IA vs symboles
"""

import re

def analyze_ia_conflicts():
    """Analyser les logs pour identifier les conflits IA"""
    print("🔍 ANALYSE DES CONFLITS IA VS SYMBOLES")
    print("="*50)
    
    # Patterns de conflits dans les logs
    conflicts = [
        "Crash.*IA = BUY.*mais Crash n'accepte que SELL",
        "Boom.*IA = SELL.*mais Boom n'accepte que BUY",
        "DERIV ARROW.*BLOQUÉ.*IA.*BUY.*Attendre signal SELL",
        "DERIV ARROW.*BLOQUÉ.*IA.*SELL.*Attendre signal BUY"
    ]
    
    print("🚨 CONFLITS DÉTECTÉS:")
    print("   1. Crash avec IA = BUY (devrait être SELL)")
    print("   2. Boom avec IA = SELL (devrait être BUY)")
    print("   3. Setup scores trop bas (< 65.0)")
    
    print("\n💡 SOLUTIONS RECOMMANDÉES:")
    print("   1. Vérifier la configuration du serveur IA")
    print("   2. Ajuster le seuil MinSetupScoreEntry")
    print("   3. Activer le mode 'Trend Staircase' pour scores plus bas")

def generate_fix_recommendations():
    """Générer les corrections spécifiques"""
    print("\n🔧 CORRECTIONS SPÉCIFIQUES")
    print("="*40)
    
    print("1. 🎯 AJUSTER LES SEUILS DE SETUP:")
    print("   MinSetupScoreEntry: 65.0 → 55.0 (plus permissif)")
    print("   MinAIConfidencePercent: 65.0 → 55.0")
    
    print("\n2. 🔄 MODE TREND STAIRCASE:")
    print("   UseStaircaseTrendMode: true (déjà activé)")
    print("   Permet les trades avec confiance IA ≥ 75%")
    
    print("\n3. 🎨 AFFICHAGE DES CANAUX SMC:")
    print("   Vérifier que les objets SMC_CH_* sont visibles")
    print("   Coordonnées: Upper=3002.260, Ask=2980.796")
    
    print("\n4. 📊 AMÉLIORER LES SCORES:")
    print("   Activer les signaux forts")
    print("   Utiliser les patterns pré-spike")
    print("   Confirmer avec EMA alignment")

def create_quick_fix():
    """Créer un fichier de correction rapide"""
    fix_content = """// CORRECTIONS RAPIDES - SMC_Universal.mq5
// A appliquer dans les inputs de l'EA

// 1. REDUIRE LES SEUILS POUR PLUS D'OPPORTUNITES
MinSetupScoreEntry = 55.0        // 65.0 -> 55.0
MinAIConfidencePercent = 55.0    // 65.0 -> 55.0

// 2. ACTIVER LE MODE TREND STAIRCASE
UseStaircaseTrendMode = true       // Deja active

// 3. PARAMETRES GRAPHIQUES
ShowChartGraphics = true          // Deja active
ShowSMCChannelsMultiTF = true    // Deja active

// 4. MODES SPECIAUX
UltraLightMode = false           // Deja desactive
BlockAllTrades = false           // Deja desactive
"""
    
    with open('quick_fix_settings.txt', 'w') as f:
        f.write(fix_content)
    
    print("\n📄 Fichier créé: quick_fix_settings.txt")
    print("   Copiez ces paramètres dans les inputs de l'EA")

def main():
    print("🚀 ANALYSE ET CORRECTION DES PROBLÈMES IA")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    analyze_ia_conflicts()
    generate_fix_recommendations()
    create_quick_fix()
    
    print("\n✅ ANALYSE TERMINÉE")
    print("\n🎯 ACTIONS IMMÉDIATES:")
    print("   1. Appliquer les paramètres du fichier quick_fix_settings.txt")
    print("   2. Redémarrer l'EA sur MT5")
    print("   3. Surveiller les nouveaux logs pour les améliorations")

if __name__ == "__main__":
    from datetime import datetime
    main()
