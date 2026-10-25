#!/usr/bin/env python3
"""
Script pour vérifier les paramètres graphiques dans SMC_Universal.mq5
"""

import re

def check_graphics_settings():
    """Vérifier les paramètres graphiques dans le fichier MQ5"""
    print("🔍 VÉRIFICATION DES PARAMÈTRES GRAPHIQUES")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    # Rechercher les paramètres d'input
    graphics_params = {
        'ShowChartGraphics': r'input\s+bool\s+ShowChartGraphics\s*=\s*(true|false)',
        'ShowFVG': r'input\s+bool\s+UseFVG\s*=\s*(true|false)',
        'ShowBookmarkLevels': r'input\s+bool\s+ShowBookmarkLevels\s*=\s*(true|false)',
        'ShowPredictionChannel': r'input\s+bool\s+ShowPredictionChannel\s*=\s*(true|false)',
        'ShowPremiumDiscount': r'input\s+bool\s+ShowPremiumDiscount\s*=\s*(true|false)',
        'ShowSignalArrow': r'input\s+bool\s+ShowSignalArrow\s*=\s*(true|false)',
        'UltraLightMode': r'input\s+bool\s+UltraLightMode\s*=\s*(true|false)',
        'BlockAllTrades': r'input\s+bool\s+BlockAllTrades\s*=\s*(true|false)'
    }
    
    print("📋 PARAMÈTRES TROUVÉS:")
    for param, pattern in graphics_params.items():
        match = re.search(pattern, content)
        if match:
            value = match.group(1)
            status = "✅ ACTIVÉ" if value == "true" else "❌ DÉSACTIVÉ"
            print(f"   {param}: {status} ({value})")
        else:
            print(f"   {param}: ❌ NON TROUVÉ")
    
    # Vérifier les appels conditionnels
    print("\n🔍 VÉRIFICATION DES APPELS GRAPHIQUES:")
    
    # Rechercher les appels directs
    direct_functions = ['DrawFVGOnChart', 'DrawOBOnChart', 'DrawBookmarkLevels', 'DrawPremiumDiscountZones']
    
    for func_name in direct_functions:
        direct_calls = content.count(f'{func_name}()')
        if direct_calls > 0:
            print(f"   ✅ {func_name}: {direct_calls} appel(s) trouvé(s)")
        else:
            print(f"   ❌ {func_name}: Aucun appel trouvé")
    
    # Vérifier les fréquences de mise à jour
    print("\n⏱️ FRÉQUENCES DE MISE À JOUR:")
    
    frequency_patterns = [
        ('Graphiques', r'lastGraphicsUpdate.*>=\s*(\d+)'),
        ('IA', r'lastAIUpdate.*>=\s*(\d+)'),
        ('Positions', r'lastPositionCheck.*>=\s*(\d+)')
    ]
    
    for name, pattern in frequency_patterns:
        matches = re.findall(pattern, content)
        if matches:
            print(f"   {name}: {matches[0]} secondes")
        else:
            print(f"   {name}: Non spécifié")
    
    # Vérifier les modes spéciaux
    print("\n🚨 MODES SPÉCIAUX:")
    
    if 'UltraLightMode = true' in content:
        print("   ❌ UltraLightMode: ACTIVÉ (graphiques désactivés)")
    else:
        print("   ✅ UltraLightMode: Désactivé")
        
    if 'BlockAllTrades = true' in content:
        print("   ❌ BlockAllTrades: ACTIVÉ (mode observation)")
    else:
        print("   ✅ BlockAllTrades: Désactivé")

def check_function_definitions():
    """Vérifier si les fonctions graphiques sont définies"""
    print("\n🔧 VÉRIFICATION DES DÉFINITIONS DE FONCTIONS:")
    print("="*50)
    
    try:
        with open('SMC_Universal.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print("❌ Fichier SMC_Universal.mq5 non trouvé")
        return
    
    functions_to_check = [
        'DrawFVGOnChart',
        'DrawOBOnChart', 
        'DrawBookmarkLevels',
        'DrawPremiumDiscountZones',
        'DrawSwingHighLow',
        'DrawFibonacciOnChart',
        'DrawEMACurveOnChart',
        'DrawLiquidityZonesOnChart'
    ]
    
    for func_name in functions_to_check:
        pattern = rf'void\s+{func_name}\s*\('
        if re.search(pattern, content):
            print(f"   ✅ {func_name}: Définie")
        else:
            print(f"   ❌ {func_name}: Non définie")

def generate_fix_recommendations():
    """Générer des recommandations pour corriger les problèmes"""
    print("\n💡 RECOMMANDATIONS DE CORRECTION:")
    print("="*45)
    
    print("1. 🔧 VÉRIFIER LES PARAMÈTRES MT5:")
    print("   - Ouvrir MT5")
    print("   - Aller dans F5 -> Experts")
    print("   - Cliquer droit sur SMC_Universal -> Inputs")
    print("   - Vérifier que ShowChartGraphics = true")
    print("   - Vérifier que UseFVG = true")
    print("   - Vérifier que ShowBookmarkLevels = true")
    
    print("\n2. 🎯 PARAMÈTRES RECOMMANDÉS:")
    print("   ShowChartGraphics = true")
    print("   UseFVG = true") 
    print("   ShowBookmarkLevels = true")
    print("   ShowPredictionChannel = true")
    print("   ShowPremiumDiscount = true")
    print("   UltraLightMode = false")
    print("   BlockAllTrades = false")
    
    print("\n3. 📊 INSÉRER DES DONNÉES DANS LES TABLES VIDES:")
    print("   - Exécuter le script d'insertion de données")
    print("   - Ou utiliser l'interface Supabase pour ajouter manuellement")
    
    print("\n4. 🔄 REDÉMARRER LE ROBOT:")
    print("   - Arrêter le robot")
    print("   - Modifier les paramètres si nécessaire")
    print("   - Redémarrer le robot")

def main():
    print(f"🚀 DIAGNOSTIC GRAPHIQUES MT5")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    check_graphics_settings()
    check_function_definitions()
    generate_fix_recommendations()

if __name__ == "__main__":
    from datetime import datetime
    main()
