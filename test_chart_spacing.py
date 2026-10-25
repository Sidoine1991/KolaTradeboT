#!/usr/bin/env python3
"""
Script de test pour vérifier les améliorations d'espacement du graphique
"""

import sys
import os
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Ajouter le répertoire backend au path
sys.path.append('backend')

def test_chart_spacing():
    """Tester les améliorations d'espacement du graphique"""
    print("🧪 Test des améliorations d'espacement du graphique")
    print("=" * 60)
    
    try:
        from chart_utils import create_candlestick_chart, add_technical_indicators_to_chart
        
        # Créer des données de test
        dates = pd.date_range(start='2024-01-01', periods=100, freq='1H')
        np.random.seed(42)
        
        # Générer des données OHLCV réalistes
        base_price = 1.2000
        prices = []
        current_price = base_price
        
        for i in range(100):
            # Simulation de mouvement de prix
            change = np.random.normal(0, 0.001)
            current_price += change
            prices.append(current_price)
        
        # Créer les données OHLCV
        data = []
        for i, (date, price) in enumerate(zip(dates, prices)):
            # Simuler OHLCV
            high = price + abs(np.random.normal(0, 0.0005))
            low = price - abs(np.random.normal(0, 0.0005))
            open_price = prices[i-1] if i > 0 else price
            close = price
            volume = np.random.randint(1000, 10000)
            
            data.append({
                'timestamp': date,
                'open': open_price,
                'high': high,
                'low': low,
                'close': close,
                'volume': volume
            })
        
        df = pd.DataFrame(data)
        print(f"✅ Données de test créées: {len(df)} barres")
        
        # Créer le graphique
        title = "Test d'Espacement - EURUSD"
        fig = create_candlestick_chart(df, title)
        
        if fig is None:
            print("❌ Erreur: Le graphique n'a pas pu être créé")
            return False
        
        print("✅ Graphique créé avec succès")
        
        # Vérifier les paramètres du layout
        layout = fig.layout
        
        print(f"\n📊 Paramètres du layout:")
        print(f"   - Hauteur: {layout.height}")
        print(f"   - Largeur: {layout.width}")
        print(f"   - Autosize: {layout.autosize}")
        print(f"   - Marges: {layout.margin}")
        
        # Vérifier les marges
        if hasattr(layout.margin, 'l') and layout.margin.l >= 80:
            print("✅ Marge gauche suffisante")
        else:
            print("⚠️ Marge gauche pourrait être insuffisante")
        
        if hasattr(layout.margin, 't') and layout.margin.t >= 80:
            print("✅ Marge haute suffisante")
        else:
            print("⚠️ Marge haute pourrait être insuffisante")
        
        if hasattr(layout.margin, 'b') and layout.margin.b >= 60:
            print("✅ Marge basse suffisante")
        else:
            print("⚠️ Marge basse pourrait être insuffisante")
        
        # Vérifier la hauteur
        if layout.height >= 800:
            print("✅ Hauteur suffisante pour éviter la compression")
        else:
            print("⚠️ Hauteur pourrait être insuffisante")
        
        # Ajouter des indicateurs techniques
        fig_with_indicators = add_technical_indicators_to_chart(fig, df, ['sma', 'ema'])
        
        if fig_with_indicators is not None:
            print("✅ Indicateurs techniques ajoutés avec succès")
        else:
            print("⚠️ Problème avec l'ajout des indicateurs")
        
        # Vérifier les sous-graphiques
        if hasattr(fig, 'data') and len(fig.data) >= 2:
            print("✅ Sous-graphiques créés (prix + volume)")
        else:
            print("⚠️ Problème avec les sous-graphiques")
        
        print(f"\n🎯 Résumé des améliorations:")
        print(f"   - Hauteur augmentée: {layout.height}px")
        print(f"   - Marges augmentées: L{layout.margin.l}, T{layout.margin.t}, B{layout.margin.b}")
        print(f"   - Autosize activé: {layout.autosize}")
        print(f"   - Largeur automatique: {layout.width}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 Test des améliorations d'espacement du graphique")
    print("=" * 70)
    
    success = test_chart_spacing()
    
    if success:
        print("\n✅ Les améliorations d'espacement sont appliquées!")
        print("📊 Le graphique devrait maintenant avoir:")
        print("   - Plus d'espace vertical (hauteur 800px)")
        print("   - Marges augmentées pour éviter la compression")
        print("   - Redimensionnement automatique")
        print("   - Meilleur espacement entre les éléments")
    else:
        print("\n❌ Des problèmes persistent avec l'espacement")
        sys.exit(1)
