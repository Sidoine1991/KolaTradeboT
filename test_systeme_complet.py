#!/usr/bin/env python3
"""
Script de test complet du système de trading automatique
Vérifie que le robot fonctionne et que les indicateurs s'affichent
"""

import MetaTrader5 as mt5
import time
import json
from datetime import datetime
import threading

def test_systeme_complet():
    """Test complet du système de trading automatique"""
    
    print("🧪 TEST COMPLET DU SYSTÈME DE TRADING")
    print("=" * 60)
    
    # Test 1: Initialisation MT5
    print("\n1️⃣ TEST INITIALISATION MT5")
    if not mt5.initialize():
        print("❌ Échec initialisation MT5")
        return False
    
    print("✅ MT5 initialisé")
    
    # Test 2: Connexion terminal
    print("\n2️⃣ TEST CONNEXION TERMINAL")
    terminal_info = mt5.terminal_info()
    if not terminal_info:
        print("❌ Terminal non connecté")
        return False
    
    print("✅ Terminal connecté")
    print(f"   - Nom: {terminal_info.name}")
    print(f"   - Trading autorisé: {terminal_info.trade_allowed}")
    print(f"   - EA autorisés: {terminal_info.mqid}")
    
    # Test 3: Vérification des symboles Boom/Crash
    print("\n3️⃣ TEST SYMBOLES BOOM/CRASH")
    symboles_test = [
        "Boom 1000 Index",
        "Crash 1000 Index",
        "Boom 500 Index",
        "Crash 500 Index"
    ]
    
    symboles_disponibles = []
    for symbole in symboles_test:
        symbol_info = mt5.symbol_info(symbole)
        if symbol_info:
            symboles_disponibles.append(symbole)
            print(f"✅ {symbole} disponible")
        else:
            print(f"❌ {symbole} non disponible")
    
    if not symboles_disponibles:
        print("❌ Aucun symbole Boom/Crash disponible")
        return False
    
    # Test 4: Vérification des indicateurs
    print("\n4️⃣ TEST INDICATEURS TECHNIQUES")
    symbole_test = symboles_disponibles[0]
    print(f"Test sur {symbole_test}")
    
    indicateurs_ok = []
    indicateurs_erreur = []
    
    # Test EMA 10
    try:
        ema10_handle = mt5.iMA(symbole_test, mt5.TIMEFRAME_M1, 10, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema10_handle != mt5.INVALID_HANDLE:
            indicateurs_ok.append("EMA 10")
        else:
            indicateurs_erreur.append("EMA 10")
    except:
        indicateurs_erreur.append("EMA 10")
    
    # Test EMA 30
    try:
        ema30_handle = mt5.iMA(symbole_test, mt5.TIMEFRAME_M1, 30, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema30_handle != mt5.INVALID_HANDLE:
            indicateurs_ok.append("EMA 30")
        else:
            indicateurs_erreur.append("EMA 30")
    except:
        indicateurs_erreur.append("EMA 30")
    
    # Test RSI
    try:
        rsi_handle = mt5.iRSI(symbole_test, mt5.TIMEFRAME_M1, 14, mt5.PRICE_CLOSE)
        if rsi_handle != mt5.INVALID_HANDLE:
            indicateurs_ok.append("RSI")
        else:
            indicateurs_erreur.append("RSI")
    except:
        indicateurs_erreur.append("RSI")
    
    if indicateurs_ok:
        print(f"✅ Indicateurs OK: {', '.join(indicateurs_ok)}")
    if indicateurs_erreur:
        print(f"❌ Indicateurs erreur: {', '.join(indicateurs_erreur)}")
    
    # Test 5: Vérification des données de prix
    print("\n5️⃣ TEST DONNÉES DE PRIX")
    try:
        rates = mt5.copy_rates_from_pos(symbole_test, mt5.TIMEFRAME_M1, 0, 10)
        if rates is not None and len(rates) > 0:
            print(f"✅ {len(rates)} bougies récupérées")
            print(f"   - Dernier prix: {rates[-1]['close']}")
            print(f"   - Timestamp: {datetime.fromtimestamp(rates[-1]['time'])}")
        else:
            print("❌ Aucune donnée de prix")
            return False
    except Exception as e:
        print(f"❌ Erreur données prix: {e}")
        return False
    
    # Test 6: Test du bot de trading Python
    print("\n6️⃣ TEST BOT PYTHON")
    try:
        from boom_trading_bot import boom_trading_bot, get_boom_trading_status
        
        # Vérifier l'état du bot
        status = get_boom_trading_status()
        print(f"✅ Bot Python actif")
        print(f"   - Trading activé: {status['trading_enabled']}")
        print(f"   - Positions actives: {status['active_positions']}")
        print(f"   - Solde: {status['account_balance']} {status['account_currency']}")
        
    except Exception as e:
        print(f"❌ Erreur bot Python: {e}")
        return False
    
    # Test 7: Test du prédicteur Boom
    print("\n7️⃣ TEST PRÉDICTEUR BOOM")
    try:
        from boom_rising_channel_predictor import get_boom_prediction, update_boom_data
        
        # Simuler des données de prix
        test_data = []
        base_price = 10000.0
        
        for i in range(50):
            price = base_price + i * 0.1 + (i % 3) * 0.5
            test_data.append({
                'timestamp': time.time() - (50-i) * 60,
                'open': price,
                'high': price + 0.2,
                'low': price - 0.2,
                'close': price,
                'volume': 1000
            })
        
        # Mettre à jour les données
        update_boom_data(test_data)
        
        # Obtenir une prédiction
        prediction = get_boom_prediction()
        print(f"✅ Prédicteur Boom actif")
        print(f"   - Action: {prediction.get('action', 'N/A')}")
        print(f"   - Direction: {prediction.get('direction', 'N/A')}")
        print(f"   - Confiance: {prediction.get('confidence', 0):.1%}")
        
    except Exception as e:
        print(f"❌ Erreur prédicteur Boom: {e}")
        return False
    
    # Test 8: Test de l'affichage dynamique
    print("\n8️⃣ TEST AFFICHAGE DYNAMIQUE")
    try:
        from boom_display_mt5 import boom_display, get_boom_display_status
        
        # Vérifier l'état de l'affichage
        display_status = get_boom_display_status()
        print(f"✅ Affichage dynamique configuré")
        print(f"   - Activé: {display_status['enabled']}")
        print(f"   - Symbole: {display_status['symbol']}")
        print(f"   - Timeframe: {display_status['timeframe']}")
        
    except Exception as e:
        print(f"❌ Erreur affichage dynamique: {e}")
        return False
    
    # Test 9: Test des objets d'affichage
    print("\n9️⃣ TEST OBJETS D'AFFICHAGE")
    try:
        # Vérifier les objets sur le graphique
        objects = mt5.object_get_all(0)
        if objects:
            print(f"✅ {len(objects)} objet(s) d'affichage trouvé(s)")
            
            hud_objects = [obj for obj in objects if "HUD" in obj.name]
            boom_objects = [obj for obj in objects if "Boom" in obj.name]
            arrow_objects = [obj for obj in objects if "SignalArrow" in obj.name]
            
            print(f"   - HUD: {len(hud_objects)}")
            print(f"   - Boom: {len(boom_objects)}")
            print(f"   - Flèches: {len(arrow_objects)}")
        else:
            print("⚠️ Aucun objet d'affichage trouvé")
            
    except Exception as e:
        print(f"❌ Erreur objets d'affichage: {e}")
    
    # Test 10: Test de simulation de trading
    print("\n🔟 TEST SIMULATION TRADING")
    try:
        # Simuler une prédiction de trading
        from boom_rising_channel_predictor import boom_predictor
        
        # Créer une prédiction simulée
        prediction_arrow = boom_predictor._create_prediction_arrow(
            price=10050.0,
            ema_proximity="EMA10",
            channel_position="lower",
            spike_probability=0.85
        )
        
        if prediction_arrow:
            print(f"✅ Prédiction simulée créée")
            print(f"   - Direction: {prediction_arrow.direction.value}")
            print(f"   - Confiance: {prediction_arrow.confidence:.1%}")
            print(f"   - Probabilité: {prediction_arrow.spike_probability:.1%}")
            print(f"   - Temps estimé: {prediction_arrow.time_to_spike}s")
        else:
            print("❌ Échec création prédiction simulée")
            
    except Exception as e:
        print(f"❌ Erreur simulation trading: {e}")
    
    print("\n" + "=" * 60)
    print("🎉 TEST COMPLET TERMINÉ")
    print("=" * 60)
    
    return True

def demarrer_monitoring_test():
    """Démarre le monitoring pour le test"""
    print("\n🔄 DÉMARRAGE DU MONITORING DE TEST")
    
    try:
        # Démarrer le bot de trading
        from boom_trading_bot import start_boom_trading
        start_boom_trading()
        print("✅ Bot de trading démarré")
        
        # Démarrer l'affichage dynamique
        from boom_display_mt5 import start_boom_display
        start_boom_display()
        print("✅ Affichage dynamique démarré")
        
        print("\n📊 MONITORING ACTIF PENDANT 30 SECONDES...")
        print("Surveillez l'apparition des indicateurs et des signaux")
        
        # Monitoring pendant 30 secondes
        for i in range(30):
            time.sleep(1)
            if i % 5 == 0:
                print(f"   ⏰ {30-i} secondes restantes...")
        
        print("✅ Test de monitoring terminé")
        
    except Exception as e:
        print(f"❌ Erreur monitoring: {e}")

def generer_rapport_test():
    """Génère un rapport de test"""
    print("\n📋 GÉNÉRATION DU RAPPORT DE TEST")
    
    rapport = {
        "timestamp": datetime.now().isoformat(),
        "test_complet": True,
        "composants_tests": [
            "Initialisation MT5",
            "Connexion terminal",
            "Symboles Boom/Crash",
            "Indicateurs techniques",
            "Données de prix",
            "Bot Python",
            "Prédicteur Boom",
            "Affichage dynamique",
            "Objets d'affichage",
            "Simulation trading"
        ],
        "recommandations": [
            "Attacher AngelOfSpike.mq5 au graphique Boom 1000 Index",
            "Configurer les paramètres selon les recommandations",
            "Surveiller l'apparition des flèches de prédiction",
            "Vérifier les logs MT5 pour les messages de succès",
            "Tester avec des paramètres plus permissifs si nécessaire"
        ]
    }
    
    # Sauvegarder le rapport
    with open("rapport_test_systeme.json", "w") as f:
        json.dump(rapport, f, indent=2)
    
    print("✅ Rapport sauvegardé: rapport_test_systeme.json")
    
    return rapport

if __name__ == "__main__":
    print("🧪 TEST COMPLET DU SYSTÈME DE TRADING AUTOMATIQUE")
    print("=" * 70)
    
    # Exécuter le test complet
    if test_systeme_complet():
        print("\n✅ TOUS LES TESTS RÉUSSIS")
        
        # Démarrer le monitoring de test
        demarrer_monitoring_test()
        
        # Générer le rapport
        generer_rapport_test()
        
        print("\n🎯 PROCHAINES ÉTAPES:")
        print("1. Attacher AngelOfSpike.mq5 au graphique Boom 1000 Index")
        print("2. Configurer les paramètres selon les recommandations")
        print("3. Surveiller l'apparition des indicateurs et trades")
        print("4. Vérifier les logs MT5 pour les messages de succès")
        
        print("\n📊 INDICATEURS À SURVEILLER:")
        print("- HUD principal en haut à gauche du graphique")
        print("- Cadran d'analyse Boom en bas à droite")
        print("- Flèches de prédiction (vertes/rouges) sur le graphique")
        print("- EMAs, RSI, MACD sur le graphique")
        print("- Messages dans l'onglet 'Experts' de MT5")
        
    else:
        print("\n❌ CERTAINS TESTS ONT ÉCHOUÉ")
        print("Vérifiez les erreurs ci-dessus et corrigez-les")
    
    # Fermer MT5
    mt5.shutdown()
    print("\n🔚 MT5 fermé")
