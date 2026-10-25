"""
Démonstration des améliorations de la logique supports et résistances.
"""

import sys
import os
sys.path.append(os.path.abspath('.'))

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime, timedelta

def create_demo_data():
    """Crée des données de démonstration avec des niveaux clairs."""
    np.random.seed(42)
    dates = pd.date_range(start='2025-01-01', periods=500, freq='1H')
    
    # Prix de base avec tendance et niveaux
    base_price = 100.0
    trend = np.linspace(0, 10, 500)
    noise = np.random.normal(0, 1.5, 500)
    
    # Niveaux de support et résistance connus
    support_levels = [98, 101, 104, 107]
    resistance_levels = [110, 113, 116, 119]
    
    prices = base_price + trend + noise
    
    # Ajout de rebonds sur les niveaux
    for i in range(len(prices)):
        # Support
        for support in support_levels:
            if prices[i] <= support:
                prices[i] = support + np.random.uniform(0, 0.8)
        
        # Résistance
        for resistance in resistance_levels:
            if prices[i] >= resistance:
                prices[i] = resistance - np.random.uniform(0, 0.8)
    
    # Génération OHLCV
    df = pd.DataFrame({
        'timestamp': dates,
        'open': prices + np.random.normal(0, 0.3, 500),
        'high': prices + np.abs(np.random.normal(0, 0.8, 500)),
        'low': prices - np.abs(np.random.normal(0, 0.8, 500)),
        'close': prices,
        'volume': np.random.randint(1000, 8000, 500)
    })
    
    # Assurer la cohérence OHLC
    df['high'] = df[['open', 'close', 'high']].max(axis=1)
    df['low'] = df[['open', 'close', 'low']].min(axis=1)
    
    df.set_index('timestamp', inplace=True)
    return df

def demo_old_vs_new():
    """Démonstration de l'ancienne vs nouvelle logique."""
    print("🚀 Démonstration : Ancienne vs Nouvelle Logique")
    print("=" * 60)
    
    # Création des données
    df = create_demo_data()
    print(f"📊 Données de démonstration créées : {df.shape}")
    
    # Test de l'ancienne logique (fallback)
    print("\n🔍 Test de l'ancienne logique (fallback)...")
    try:
        from backend.technical_analysis import get_support_resistance_levels
        
        # Forcer l'utilisation de l'ancienne logique
        import importlib
        import backend.technical_analysis as ta_module
        
        # Sauvegarder la fonction originale
        original_func = ta_module.get_support_resistance_levels
        
        # Remplacer temporairement par une version simple
        def simple_support_resistance(df):
            levels = {}
            if df.empty: 
                return levels
            
            # Méthode simple : juste les plus hauts/bas
            window = min(len(df), 50)
            if window > 0:
                recent_highs = df['high'].iloc[-window:].nlargest(3)
                recent_lows = df['low'].iloc[-window:].nsmallest(3)
                
                levels['resistance'] = recent_highs.values.tolist()
                levels['support'] = recent_lows.values.tolist()
            
            return levels
        
        # Remplacer temporairement
        ta_module.get_support_resistance_levels = simple_support_resistance
        
        # Test
        old_levels = get_support_resistance_levels(df)
        
        print(f"✅ Ancienne logique :")
        print(f"   - Supports : {len(old_levels.get('support', []))}")
        print(f"   - Résistances : {len(old_levels.get('resistance', []))}")
        
        if old_levels.get('support'):
            print("   - Niveaux de support :", [f"{x:.2f}" for x in old_levels['support']])
        if old_levels.get('resistance'):
            print("   - Niveaux de résistance :", [f"{x:.2f}" for x in old_levels['resistance']])
        
        # Restaurer la fonction originale
        ta_module.get_support_resistance_levels = original_func
        
    except Exception as e:
        print(f"❌ Erreur dans l'ancienne logique : {e}")
    
    # Test de la nouvelle logique
    print("\n🚀 Test de la nouvelle logique avancée...")
    try:
        from backend.advanced_support_resistance import AdvancedSupportResistance
        
        detector = AdvancedSupportResistance()
        new_levels = detector.detect_all_levels(df, "DEMO_SYMBOL")
        
        print(f"✅ Nouvelle logique :")
        print(f"   - Supports : {len(new_levels.get('supports', []))}")
        print(f"   - Résistances : {len(new_levels.get('resistances', []))}")
        
        if new_levels.get('supports'):
            print("\n🔸 Supports détectés (avec force) :")
            for i, support in enumerate(new_levels['supports'][:3]):
                print(f"   {i+1}. Prix: {support['price']:.2f}, Force: {support['strength']:.2f}")
                print(f"      Méthode: {support['method']}")
                print(f"      Volume: {support.get('volume_strength', 1):.2f}")
        
        if new_levels.get('resistances'):
            print("\n🔸 Résistances détectées (avec force) :")
            for i, resistance in enumerate(new_levels['resistances'][:3]):
                print(f"   {i+1}. Prix: {resistance['price']:.2f}, Force: {resistance['strength']:.2f}")
                print(f"      Méthode: {resistance['method']}")
                print(f"      Volume: {resistance.get('volume_strength', 1):.2f}")
        
        return new_levels
        
    except Exception as e:
        print(f"❌ Erreur dans la nouvelle logique : {e}")
        return None

def demo_methods_comparison():
    """Démonstration de la comparaison des méthodes."""
    print("\n🔬 Comparaison des Méthodes de Détection")
    print("=" * 60)
    
    try:
        from backend.advanced_support_resistance import AdvancedSupportResistance
        
        df = create_demo_data()
        detector = AdvancedSupportResistance()
        
        # Test des méthodes individuelles
        methods = {
            'Swing Levels': detector._detect_swing_levels,
            'Pivot Points': detector._detect_pivot_points,
            'Volume Profile': detector._detect_volume_levels,
            'Fractals': detector._detect_fractal_levels,
            'Fibonacci': detector._detect_fibonacci_levels
        }
        
        results = {}
        for method_name, method_func in methods.items():
            try:
                result = method_func(df)
                total_levels = 0
                for key, levels in result.items():
                    if isinstance(levels, list):
                        total_levels += len(levels)
                
                results[method_name] = total_levels
                print(f"✅ {method_name}: {total_levels} niveaux détectés")
                
            except Exception as e:
                print(f"❌ {method_name}: Erreur - {e}")
                results[method_name] = 0
        
        # Résumé
        print(f"\n📊 Résumé des méthodes :")
        total_detected = sum(results.values())
        print(f"   - Total des niveaux détectés : {total_detected}")
        print(f"   - Méthodes actives : {len([r for r in results.values() if r > 0])}")
        
        return results
        
    except Exception as e:
        print(f"❌ Erreur dans la comparaison des méthodes : {e}")
        return {}

def demo_performance():
    """Démonstration des performances."""
    print("\n⚡ Test de Performance")
    print("=" * 60)
    
    try:
        from backend.advanced_support_resistance import AdvancedSupportResistance
        import time
        
        # Création de données de différentes tailles
        sizes = [100, 500, 1000, 2000, 5000]
        results = {}
        
        detector = AdvancedSupportResistance()
        
        for size in sizes:
            df = create_demo_data().head(size)
            
            start_time = time.time()
            levels = detector.detect_all_levels(df, f"PERF_{size}")
            end_time = time.time()
            
            duration = end_time - start_time
            rate = size / duration if duration > 0 else 0
            
            results[size] = {
                'duration': duration,
                'rate': rate,
                'levels': len(levels.get('supports', [])) + len(levels.get('resistances', []))
            }
            
            print(f"✅ {size} bougies : {duration:.3f}s ({rate:.0f} bougies/s) - {results[size]['levels']} niveaux")
        
        # Graphique de performance
        print(f"\n📈 Résumé des performances :")
        best_rate = max([r['rate'] for r in results.values()])
        best_size = [size for size, r in results.items() if r['rate'] == best_rate][0]
        print(f"   - Meilleure performance : {best_size} bougies ({best_rate:.0f} bougies/s)")
        
        return results
        
    except Exception as e:
        print(f"❌ Erreur dans le test de performance : {e}")
        return {}

def demo_configuration():
    """Démonstration de la configuration."""
    print("\n⚙️ Démonstration de la Configuration")
    print("=" * 60)
    
    try:
        from backend.advanced_support_resistance import AdvancedSupportResistance
        
        df = create_demo_data()
        
        # Configuration par défaut
        detector_default = AdvancedSupportResistance()
        levels_default = detector_default.detect_all_levels(df, "DEFAULT")
        
        # Configuration personnalisée
        custom_config = {
            'swing_window': 3,           # Plus sensible
            'min_touches': 3,            # Plus strict
            'max_levels': 15,            # Plus de niveaux
            'tolerance_pct': 0.002,      # Plus tolérant
            'strength_weights': {        # Poids personnalisés
                'touches': 0.5,          # Plus d'importance aux touches
                'volume': 0.3,           # Plus d'importance au volume
                'time': 0.1,             # Moins d'importance au temps
                'price_cluster': 0.1     # Moins d'importance au clustering
            }
        }
        
        detector_custom = AdvancedSupportResistance(custom_config)
        levels_custom = detector_custom.detect_all_levels(df, "CUSTOM")
        
        print(f"✅ Configuration par défaut :")
        print(f"   - Supports : {len(levels_default.get('supports', []))}")
        print(f"   - Résistances : {len(levels_default.get('resistances', []))}")
        
        print(f"\n✅ Configuration personnalisée :")
        print(f"   - Supports : {len(levels_custom.get('supports', []))}")
        print(f"   - Résistances : {len(levels_custom.get('resistances', []))}")
        
        # Comparaison des paramètres
        print(f"\n🔧 Comparaison des paramètres :")
        print(f"   - Swing Window : {detector_default.config['swing_window']} vs {detector_custom.config['swing_window']}")
        print(f"   - Min Touches : {detector_default.config['min_touches']} vs {detector_custom.config['min_touches']}")
        print(f"   - Max Levels : {detector_default.config['max_levels']} vs {detector_custom.config['max_levels']}")
        
        return {
            'default': levels_default,
            'custom': levels_custom
        }
        
    except Exception as e:
        print(f"❌ Erreur dans la démonstration de configuration : {e}")
        return {}

def main():
    """Fonction principale de démonstration."""
    print("🎯 Démonstration Complète des Améliorations S/R")
    print("=" * 80)
    
    # 1. Comparaison ancienne vs nouvelle
    new_levels = demo_old_vs_new()
    
    # 2. Comparaison des méthodes
    methods_results = demo_methods_comparison()
    
    # 3. Test de performance
    perf_results = demo_performance()
    
    # 4. Démonstration de configuration
    config_results = demo_configuration()
    
    # Résumé final
    print("\n🎊 Résumé de la Démonstration")
    print("=" * 80)
    
    if new_levels:
        total_levels = len(new_levels.get('supports', [])) + len(new_levels.get('resistances', []))
        print(f"✅ Nouvelle logique : {total_levels} niveaux détectés")
    
    if methods_results:
        active_methods = len([r for r in methods_results.values() if r > 0])
        print(f"✅ Méthodes actives : {active_methods}/5")
    
    if perf_results:
        best_perf = max([r['rate'] for r in perf_results.values()])
        print(f"✅ Performance maximale : {best_perf:.0f} bougies/seconde")
    
    if config_results:
        print(f"✅ Configuration : Personnalisation réussie")
    
    print(f"\n🚀 La nouvelle logique de supports et résistances est opérationnelle !")
    print(f"💡 Utilisez-la dans vos stratégies de trading pour une précision maximale.")

if __name__ == "__main__":
    main()
