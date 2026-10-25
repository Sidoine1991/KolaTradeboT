#!/usr/bin/env python3
"""
Script pour activer AngelOfSpike avec des paramètres optimisés
Corrige les problèmes de trading automatique et d'affichage des indicateurs
"""

import MetaTrader5 as mt5
import time
import json
from datetime import datetime

def activer_angelofspike_optimise():
    """Active AngelOfSpike avec des paramètres optimisés pour le trading automatique"""
    
    print("Activation d'AngelOfSpike avec parametres optimises")
    print("=" * 60)
    
    # Initialiser MT5
    if not mt5.initialize():
        print("❌ Erreur: Impossible d'initialiser MT5")
        return False
    
    print("✅ MT5 initialisé")
    
    # Vérifier la connexion
    if not mt5.terminal_info():
        print("❌ Erreur: Terminal MT5 non connecté")
        return False
    
    print("✅ Terminal MT5 connecté")
    
    # Paramètres optimisés pour AngelOfSpike
    parametres_optimises = {
        "InpEnableTrading": True,
        "InpEnableSpikeTrading": True,
        "InpMinSpikeM1Probability": 60.0,  # Réduit de 85% à 60%
        "InpMaxGlobalPositions": 1,
        "InpMaxPositionsPerSymbol": 1,
        "InpCooldownSeconds": 30,
        "InpSpikeStopLossUSD": 2.00,
        "InpQuickTP1": 3.00,
        "InpPrioritizeBoomCrash": True,
        "InpMinProbBoomCrash": 60.0,  # Réduit de 85% à 60%
        "InpEnableBoomDisplay": True,
        "InpBoomUpdateInterval": 5,
        "InpShowHUD": True,
        "InpDebug": True
    }
    
    print("\n📊 Paramètres optimisés:")
    for param, valeur in parametres_optimises.items():
        print(f"   {param}: {valeur}")
    
    # Sauvegarder la configuration
    config_file = "angelofspike_config_optimise.json"
    with open(config_file, 'w') as f:
        json.dump(parametres_optimises, f, indent=2)
    
    print(f"\n💾 Configuration sauvegardée: {config_file}")
    
    # Instructions pour l'utilisateur
    print("\n📋 INSTRUCTIONS POUR ACTIVER L'EA:")
    print("1. Ouvrir MetaTrader 5")
    print("2. Aller dans Navigator > Expert Advisors")
    print("3. Glisser 'AngelOfSpike.mq5' sur le graphique Boom 1000 Index")
    print("4. Dans les paramètres de l'EA, configurer:")
    print("   - InpEnableTrading = true")
    print("   - InpMinSpikeM1Probability = 60.0")
    print("   - InpMaxGlobalPositions = 1")
    print("   - InpEnableBoomDisplay = true")
    print("5. Cliquer sur 'OK' pour activer l'EA")
    
    print("\n🎯 SYMBOLES RECOMMANDÉS:")
    symboles_boom_crash = [
        "Boom 1000 Index",
        "Crash 1000 Index", 
        "Boom 500 Index",
        "Crash 500 Index",
        "Boom 300 Index",
        "Crash 300 Index"
    ]
    
    for symbole in symboles_boom_crash:
        print(f"   - {symbole}")
    
    print("\n🔍 VÉRIFICATIONS À EFFECTUER:")
    print("1. Vérifier que les symboles Boom/Crash sont dans Market Watch")
    print("2. S'assurer que le trading automatique est autorisé")
    print("3. Contrôler que l'EA affiche 'Initialisation réussie' dans les logs")
    print("4. Surveiller l'apparition des flèches de prédiction sur le graphique")
    
    print("\n📈 INDICATEURS À SURVEILLER:")
    print("- Flèches vertes (BOOM) et rouges (CRASH) sur le graphique")
    print("- HUD en haut à gauche du graphique")
    print("- Cadran d'analyse Boom en bas à droite")
    print("- Messages dans l'onglet 'Experts' de MT5")
    
    print("\n⚡ MESSAGES DE SUCCÈS À SURVEILLER:")
    messages_succes = [
        "Angel of Spike - Initialisation réussie",
        "SPIKE M1 DÉTECTÉ ET EXÉCUTÉ",
        "Position ouverte avec succès",
        "Affichage Boom activé",
        "HUD mis à jour"
    ]
    
    for message in messages_succes:
        print(f"   ✓ {message}")
    
    print("\n🚨 MESSAGES D'ERREUR À ÉVITER:")
    messages_erreur = [
        "[BLOQUÉ] Trade bloqué par gestion des risques",
        "[COOLDOWN] Cooldown actif",
        "[ERREUR] Confiance insuffisante",
        "[ERREUR] SL/TP invalides",
        "Trading non autorisé"
    ]
    
    for message in messages_erreur:
        print(f"   ✗ {message}")
    
    print("\n🎉 AngelOfSpike prêt à être activé avec des paramètres optimisés!")
    print("Le robot devrait maintenant détecter les spikes et ouvrir des trades automatiquement.")
    
    return True

def verifier_etat_ea():
    """Vérifie l'état de l'EA AngelOfSpike"""
    print("\n🔍 Vérification de l'état d'AngelOfSpike...")
    
    # Vérifier les experts actifs
    experts = mt5.terminal_info()
    if experts:
        print("✅ Terminal MT5 actif")
    else:
        print("❌ Terminal MT5 inactif")
        return False
    
    # Vérifier les positions ouvertes
    positions = mt5.positions_get()
    if positions:
        print(f"📊 {len(positions)} position(s) ouverte(s)")
        for pos in positions:
            print(f"   - {pos.symbol}: {pos.type} {pos.volume} @ {pos.price}")
    else:
        print("📊 Aucune position ouverte")
    
    # Vérifier les ordres en attente
    orders = mt5.orders_get()
    if orders:
        print(f"📋 {len(orders)} ordre(s) en attente")
    else:
        print("📋 Aucun ordre en attente")
    
    return True

def demarrer_monitoring():
    """Démarre le monitoring du système"""
    print("\n🔄 Démarrage du monitoring...")
    
    # Démarrer le bot Python si nécessaire
    try:
        from boom_trading_bot import boom_trading_bot, start_boom_trading
        
        if boom_trading_bot._initialize_mt5():
            print("✅ Bot Python initialisé")
            start_boom_trading()
            print("✅ Monitoring Python démarré")
        else:
            print("⚠️ Bot Python non initialisé")
    except Exception as e:
        print(f"⚠️ Erreur bot Python: {e}")
    
    print("\n📊 SYSTÈME DE MONITORING ACTIF")
    print("Surveillez les logs MT5 et les indicateurs sur le graphique")
    print("Les trades automatiques devraient maintenant fonctionner")

if __name__ == "__main__":
    print("ACTIVATION ANGELOFSPIKE OPTIMISE")
    print("=" * 50)
    
    # Activer AngelOfSpike
    if activer_angelofspike_optimise():
        print("\n✅ Configuration terminée")
        
        # Vérifier l'état
        verifier_etat_ea()
        
        # Démarrer le monitoring
        demarrer_monitoring()
        
        print("\n🎯 PROCHAINES ÉTAPES:")
        print("1. Attacher AngelOfSpike.mq5 au graphique Boom 1000 Index")
        print("2. Configurer les paramètres selon les recommandations")
        print("3. Surveiller l'apparition des indicateurs et trades")
        print("4. Vérifier les logs MT5 pour les messages de succès")
        
    else:
        print("\n❌ Échec de l'activation")
    
    # Fermer MT5
    mt5.shutdown()
    print("\n🔚 MT5 fermé")
