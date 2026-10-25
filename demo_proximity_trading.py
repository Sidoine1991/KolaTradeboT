#!/usr/bin/env python3
"""
Démonstration du Système de Trading par Proximité des Supports/Résistances
"""

import time
import json
from proximity_trading_system import ProximityTradingSystem
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def load_config():
    """Charge la configuration depuis le fichier JSON"""
    try:
        with open('proximity_trading_config.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        logger.warning("Fichier de configuration non trouvé, utilisation des valeurs par défaut")
        return {}

def demo_support_resistance_analysis():
    """Démonstration de l'analyse des supports/résistances"""
    print("🔍 DÉMONSTRATION: Analyse des Supports/Résistances")
    print("=" * 60)
    
    # Charger la configuration
    config = load_config()
    
    # Créer le système
    trading_system = ProximityTradingSystem()
    
    # Symboles de démonstration
    demo_symbols = ["Boom 1000 Index", "Crash 1000 Index"]
    
    for symbol in demo_symbols:
        print(f"\n📊 Analyse de {symbol}:")
        print("-" * 40)
        
        try:
            # Détecter les niveaux
            levels = trading_system.detect_support_resistance_levels(symbol)
            
            if levels:
                print(f"✅ {len(levels)} niveaux détectés")
                
                # Afficher les niveaux par type
                supports = [l for l in levels if l.level_type == 'support']
                resistances = [l for l in levels if l.level_type == 'resistance']
                
                print(f"   📈 Supports: {len(supports)}")
                for i, support in enumerate(supports[:3]):  # Top 3
                    print(f"      {i+1}. Prix: {support.price:.2f} "
                          f"(force: {support.strength:.2f}, méthode: {support.method})")
                
                print(f"   📉 Résistances: {len(resistances)}")
                for i, resistance in enumerate(resistances[:3]):  # Top 3
                    print(f"      {i+1}. Prix: {resistance.price:.2f} "
                          f"(force: {resistance.strength:.2f}, méthode: {resistance.method})")
            else:
                print("⚠️ Aucun niveau détecté")
                
        except Exception as e:
            print(f"❌ Erreur: {e}")

def demo_trading_signals():
    """Démonstration de la génération des signaux"""
    print("\n🎯 DÉMONSTRATION: Génération des Signaux de Trading")
    print("=" * 60)
    
    trading_system = ProximityTradingSystem()
    
    # Symboles de démonstration
    demo_symbols = ["Boom 1000 Index", "Crash 1000 Index"]
    
    for symbol in demo_symbols:
        print(f"\n📈 Signaux pour {symbol}:")
        print("-" * 40)
        
        try:
            # Générer les signaux
            signals = trading_system.generate_trading_signals(symbol)
            
            if signals:
                print(f"✅ {len(signals)} signaux générés")
                
                for i, signal in enumerate(signals):
                    print(f"\n   Signal {i+1}:")
                    print(f"      Action: {signal.action}")
                    print(f"      Prix d'entrée: {signal.entry_price:.2f}")
                    print(f"      Stop Loss: {signal.sl:.2f}")
                    print(f"      Take Profit: {signal.tp:.2f}")
                    print(f"      Confiance: {signal.confidence:.2f}")
                    print(f"      Raison: {signal.reason}")
                    
                    # Calculer le ratio risque/récompense
                    if signal.action == 'BUY':
                        risk = signal.entry_price - signal.sl
                        reward = signal.tp - signal.entry_price
                    else:
                        risk = signal.sl - signal.entry_price
                        reward = signal.entry_price - signal.tp
                    
                    if risk > 0:
                        rr_ratio = reward / risk
                        print(f"      Ratio R/R: {rr_ratio:.2f}")
            else:
                print("⚠️ Aucun signal généré")
                
        except Exception as e:
            print(f"❌ Erreur: {e}")

def demo_proximity_calculation():
    """Démonstration du calcul de proximité"""
    print("\n📏 DÉMONSTRATION: Calcul de Proximité")
    print("=" * 60)
    
    # Prix fictifs pour la démonstration
    current_price = 1000.0
    proximity_threshold = 0.002  # 0.2%
    
    # Niveaux fictifs
    demo_levels = [
        {"price": 1001.5, "type": "resistance", "method": "swing_high"},
        {"price": 998.5, "type": "support", "method": "swing_low"},
        {"price": 1005.0, "type": "resistance", "method": "psychological"},
        {"price": 995.0, "type": "support", "method": "pivot_s1"},
        {"price": 1002.0, "type": "resistance", "method": "pivot_r1"}
    ]
    
    print(f"Prix actuel: {current_price}")
    print(f"Seuil de proximité: {proximity_threshold * 100:.1f}%")
    print()
    
    for i, level in enumerate(demo_levels):
        distance_pct = abs(level["price"] - current_price) / current_price
        is_proximate = distance_pct <= proximity_threshold
        
        status = "✅ PROCHE" if is_proximate else "❌ LOIN"
        
        print(f"Niveau {i+1}: {level['type'].upper()} à {level['price']}")
        print(f"   Distance: {distance_pct * 100:.2f}%")
        print(f"   Statut: {status}")
        print(f"   Méthode: {level['method']}")
        print()

def demo_risk_management():
    """Démonstration de la gestion des risques"""
    print("\n🛡️ DÉMONSTRATION: Gestion des Risques")
    print("=" * 60)
    
    trading_system = ProximityTradingSystem()
    
    # Afficher les paramètres de risque
    print("Paramètres de risque actuels:")
    print(f"   Positions max: {trading_system.max_positions}")
    print(f"   Taille de lot: {trading_system.lot_size}")
    print(f"   Perte quotidienne max: {trading_system.max_daily_loss}$")
    print(f"   Trades quotidiens max: {trading_system.max_daily_trades}")
    print(f"   Seuil de proximité: {trading_system.proximity_threshold * 100:.1f}%")
    print(f"   Force minimale: {trading_system.min_strength}")
    print(f"   Confiance minimale: {trading_system.min_confidence}")
    
    # Afficher le statut actuel
    status = trading_system.get_status()
    print(f"\nStatut actuel:")
    print(f"   Positions actives: {status['active_positions']}")
    print(f"   Trades aujourd'hui: {status['daily_trades']}")
    print(f"   Perte quotidienne: {status['daily_loss']:.2f}$")

def demo_system_workflow():
    """Démonstration du workflow du système"""
    print("\n🔄 DÉMONSTRATION: Workflow du Système")
    print("=" * 60)
    
    print("Le système fonctionne selon ce workflow:")
    print()
    print("1. 📊 ANALYSE DES DONNÉES")
    print("   - Récupération des données de prix (M1)")
    print("   - Calcul des indicateurs techniques")
    print("   - Détection des patterns de marché")
    print()
    print("2. 🎯 DÉTECTION DES NIVEAUX")
    print("   - Swing highs/lows")
    print("   - Pivot points")
    print("   - Niveaux psychologiques")
    print("   - Niveaux de volume")
    print()
    print("3. 📏 CALCUL DE PROXIMITÉ")
    print("   - Distance entre prix actuel et niveaux")
    print("   - Validation des seuils de proximité")
    print("   - Calcul de la confiance")
    print()
    print("4. 🚦 GÉNÉRATION DES SIGNAUX")
    print("   - Signal BUY près d'un support")
    print("   - Signal SELL près d'une résistance")
    print("   - Validation des distances SL/TP")
    print()
    print("5. ⚡ EXÉCUTION DES TRADES")
    print("   - Vérification des limites de risque")
    print("   - Envoi des ordres MT5")
    print("   - Suivi des positions")
    print()
    print("6. 🛡️ GESTION DES RISQUES")
    print("   - Surveillance des positions")
    print("   - Respect des limites quotidiennes")
    print("   - Fermeture automatique si nécessaire")

def main():
    """Fonction principale de démonstration"""
    print("🎯 DÉMONSTRATION DU SYSTÈME DE TRADING PAR PROXIMITÉ")
    print("=" * 70)
    print()
    print("Ce système exécute des trades quand le prix est proche:")
    print("   📈 D'un SUPPORT → Signal BUY (Boom)")
    print("   📉 D'une RÉSISTANCE → Signal SELL (Crash)")
    print()
    
    try:
        # Démonstrations
        demo_support_resistance_analysis()
        demo_trading_signals()
        demo_proximity_calculation()
        demo_risk_management()
        demo_system_workflow()
        
        print("\n🎉 DÉMONSTRATION TERMINÉE AVEC SUCCÈS!")
        print()
        print("Pour lancer le système en mode réel:")
        print("   python proximity_trading_system.py")
        print()
        print("Pour tester le système:")
        print("   python test_proximity_trading.py")
        
    except Exception as e:
        print(f"\n❌ Erreur lors de la démonstration: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    main()
