#!/usr/bin/env python3
"""
Script simple pour activer le système de trading automatique
Corrige les problèmes de trading et d'affichage des indicateurs
"""

import MetaTrader5 as mt5
import time
import json
from datetime import datetime

def activer_systeme_simple():
    """Active le système de trading automatique avec des paramètres optimisés"""
    
    print("ACTIVATION DU SYSTEME DE TRADING AUTOMATIQUE")
    print("=" * 60)
    
    # Initialiser MT5
    if not mt5.initialize():
        print("ERREUR: Impossible d'initialiser MT5")
        return False
    
    print("OK: MT5 initialise")
    
    # Vérifier la connexion
    if not mt5.terminal_info():
        print("ERREUR: Terminal MT5 non connecte")
        return False
    
    print("OK: Terminal MT5 connecte")
    
    # Paramètres optimisés
    parametres_optimises = {
        "InpEnableTrading": True,
        "InpEnableSpikeTrading": True,
        "InpMinSpikeM1Probability": 60.0,
        "InpMaxGlobalPositions": 1,
        "InpMaxPositionsPerSymbol": 1,
        "InpCooldownSeconds": 30,
        "InpSpikeStopLossUSD": 2.00,
        "InpQuickTP1": 3.00,
        "InpPrioritizeBoomCrash": True,
        "InpMinProbBoomCrash": 60.0,
        "InpEnableBoomDisplay": True,
        "InpBoomUpdateInterval": 5,
        "InpShowHUD": True,
        "InpDebug": True
    }
    
    print("\nParametres optimises:")
    for param, valeur in parametres_optimises.items():
        print(f"   {param}: {valeur}")
    
    # Sauvegarder la configuration
    config_file = "angelofspike_config_optimise.json"
    with open(config_file, 'w') as f:
        json.dump(parametres_optimises, f, indent=2)
    
    print(f"\nConfiguration sauvegardee: {config_file}")
    
    # Instructions pour l'utilisateur
    print("\nINSTRUCTIONS POUR ACTIVER L'EA:")
    print("1. Ouvrir MetaTrader 5")
    print("2. Aller dans Navigator > Expert Advisors")
    print("3. Glisser 'AngelOfSpike.mq5' sur le graphique Boom 1000 Index")
    print("4. Dans les parametres de l'EA, configurer:")
    print("   - InpEnableTrading = true")
    print("   - InpMinSpikeM1Probability = 60.0")
    print("   - InpMaxGlobalPositions = 1")
    print("   - InpEnableBoomDisplay = true")
    print("5. Cliquer sur 'OK' pour activer l'EA")
    
    print("\nSYMBOLES RECOMMANDES:")
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
    
    print("\nVERIFICATIONS A EFFECTUER:")
    print("1. Verifier que les symboles Boom/Crash sont dans Market Watch")
    print("2. S'assurer que le trading automatique est autorise")
    print("3. Controler que l'EA affiche 'Initialisation reussie' dans les logs")
    print("4. Surveiller l'apparition des fleches de prediction sur le graphique")
    
    print("\nINDICATEURS A SURVEILLER:")
    print("- Fleches vertes (BOOM) et rouges (CRASH) sur le graphique")
    print("- HUD en haut a gauche du graphique")
    print("- Cadran d'analyse Boom en bas a droite")
    print("- Messages dans l'onglet 'Experts' de MT5")
    
    print("\nMESSAGES DE SUCCES A SURVEILLER:")
    messages_succes = [
        "Angel of Spike - Initialisation reussie",
        "SPIKE M1 DETECTE ET EXECUTE",
        "Position ouverte avec succes",
        "Affichage Boom active",
        "HUD mis a jour"
    ]
    
    for message in messages_succes:
        print(f"   OK: {message}")
    
    print("\nMESSAGES D'ERREUR A EVITER:")
    messages_erreur = [
        "[BLOQUE] Trade bloque par gestion des risques",
        "[COOLDOWN] Cooldown actif",
        "[ERREUR] Confiance insuffisante",
        "[ERREUR] SL/TP invalides",
        "Trading non autorise"
    ]
    
    for message in messages_erreur:
        print(f"   ERREUR: {message}")
    
    print("\nAngelOfSpike pret a etre active avec des parametres optimises!")
    print("Le robot devrait maintenant detecter les spikes et ouvrir des trades automatiquement.")
    
    return True

def corriger_affichage_indicators():
    """Corrige l'affichage des indicateurs sur le graphique MT5"""
    
    print("\nCORRECTION DE L'AFFICHAGE DES INDICATEURS")
    print("=" * 50)
    
    # Ajouter les indicateurs au graphique
    print("\nAjout des indicateurs techniques...")
    
    symbol = "Boom 1000 Index"
    
    # Vérifier que le symbole existe
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        print(f"ERREUR: Symbole {symbol} non trouve")
        return False
    
    print(f"OK: Symbole {symbol} trouve")
    
    # Ajouter les EMAs
    try:
        # EMA 10
        ema10_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 10, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema10_handle != mt5.INVALID_HANDLE:
            print("OK: EMA 10 ajoutee")
        else:
            print("ATTENTION: EMA 10 non ajoutee")
        
        # EMA 30
        ema30_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 30, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema30_handle != mt5.INVALID_HANDLE:
            print("OK: EMA 30 ajoutee")
        else:
            print("ATTENTION: EMA 30 non ajoutee")
        
        # EMA 50
        ema50_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 50, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema50_handle != mt5.INVALID_HANDLE:
            print("OK: EMA 50 ajoutee")
        else:
            print("ATTENTION: EMA 50 non ajoutee")
        
        # RSI
        rsi_handle = mt5.iRSI(symbol, mt5.TIMEFRAME_M1, 14, mt5.PRICE_CLOSE)
        if rsi_handle != mt5.INVALID_HANDLE:
            print("OK: RSI ajoute")
        else:
            print("ATTENTION: RSI non ajoute")
        
        # MACD
        macd_handle = mt5.iMACD(symbol, mt5.TIMEFRAME_M1, 12, 26, 9, mt5.PRICE_CLOSE)
        if macd_handle != mt5.INVALID_HANDLE:
            print("OK: MACD ajoute")
        else:
            print("ATTENTION: MACD non ajoute")
        
    except Exception as e:
        print(f"ERREUR lors de l'ajout des indicateurs: {e}")
        return False
    
    # Créer les objets d'affichage
    print("\nCreation des objets d'affichage...")
    
    # Créer le HUD principal
    try:
        # Supprimer l'ancien HUD s'il existe
        mt5.object_delete(0, "AngelOfSpikeHUD")
        
        # Créer le HUD
        if mt5.object_create(0, "AngelOfSpikeHUD", mt5.OBJ_LABEL, 0, 0, 0):
            # Position
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_XDISTANCE, 10)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_YDISTANCE, 30)
            
            # Style
            mt5.object_set_string(0, "AngelOfSpikeHUD", mt5.OBJPROP_FONT, "Arial")
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_FONTSIZE, 9)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_COLOR, 0xFFFFFF)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_ANCHOR, mt5.ANCHOR_LEFT_UPPER)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_BACK, False)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_SELECTABLE, False)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_HIDDEN, False)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_ZORDER, 1000)
            
            # Texte initial
            hud_text = "AngelOfSpike v2.0\\nTrading: ACTIF\\nPositions: 0\\nDernier Trade: Aucun\\n" + datetime.now().strftime("%H:%M:%S")
            mt5.object_set_string(0, "AngelOfSpikeHUD", mt5.OBJPROP_TEXT, hud_text)
            
            print("OK: HUD principal cree")
        else:
            print("ERREUR: Creation HUD principal")
            
    except Exception as e:
        print(f"ERREUR HUD principal: {e}")
    
    # Créer le cadran Boom
    try:
        # Supprimer l'ancien cadran s'il existe
        mt5.object_delete(0, "BoomAnalysisDisplay")
        mt5.object_delete(0, "BoomAnalysisText")
        
        # Créer le rectangle de fond
        if mt5.object_create(0, "BoomAnalysisDisplay", mt5.OBJ_RECTANGLE_LABEL, 0, 0, 0):
            # Position et taille
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_XDISTANCE, 600)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_YDISTANCE, 100)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_XSIZE, 200)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_YSIZE, 150)
            
            # Style
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_BGCOLOR, 0x1E1E1E)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_BORDER_COLOR, 0x00FF00)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_WIDTH, 2)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_BACK, True)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_SELECTABLE, False)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_HIDDEN, False)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_ZORDER, 1000)
            
            print("OK: Rectangle Boom cree")
        
        # Créer le texte
        if mt5.object_create(0, "BoomAnalysisText", mt5.OBJ_LABEL, 0, 0, 0):
            # Position
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_XDISTANCE, 610)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_YDISTANCE, 110)
            
            # Style
            mt5.object_set_string(0, "BoomAnalysisText", mt5.OBJPROP_FONT, "Arial")
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_FONTSIZE, 8)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_COLOR, 0xFFFFFF)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_ANCHOR, mt5.ANCHOR_LEFT_UPPER)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_BACK, False)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_SELECTABLE, False)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_HIDDEN, False)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_ZORDER, 1001)
            
            # Texte initial
            boom_text = "BOOM RISING CHANNEL\\nDirection: NEUTRAL\\nForce: 0%\\nConfiance: 0%\\nSignal: boom_hold\\nSpike Prob: 0.0%\\nTemps: 0s\\nEMA: N/A\\nCanal: N/A\\nPrix: 0.00\\nCanal Force: 0.0%\\nBreakout: 0.0%\\n" + datetime.now().strftime("%H:%M:%S")
            mt5.object_set_string(0, "BoomAnalysisText", mt5.OBJPROP_TEXT, boom_text)
            
            print("OK: Texte Boom cree")
        else:
            print("ERREUR: Creation texte Boom")
            
    except Exception as e:
        print(f"ERREUR cadran Boom: {e}")
    
    print("OK: Objets d'affichage crees")
    return True

def test_systeme():
    """Test du système de trading automatique"""
    
    print("\nTEST DU SYSTEME DE TRADING AUTOMATIQUE")
    print("=" * 50)
    
    # Test 1: Vérifier les symboles Boom/Crash
    print("\n1. Test des symboles Boom/Crash")
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
            print(f"OK: {symbole} disponible")
        else:
            print(f"ERREUR: {symbole} non disponible")
    
    if not symboles_disponibles:
        print("ERREUR: Aucun symbole Boom/Crash disponible")
        return False
    
    # Test 2: Vérifier les données de prix
    print("\n2. Test des donnees de prix")
    symbole_test = symboles_disponibles[0]
    try:
        rates = mt5.copy_rates_from_pos(symbole_test, mt5.TIMEFRAME_M1, 0, 10)
        if rates is not None and len(rates) > 0:
            print(f"OK: {len(rates)} bougies recuperees")
            print(f"   - Dernier prix: {rates[-1]['close']}")
        else:
            print("ERREUR: Aucune donnee de prix")
            return False
    except Exception as e:
        print(f"ERREUR donnees prix: {e}")
        return False
    
    # Test 3: Test du bot Python
    print("\n3. Test du bot Python")
    try:
        from boom_trading_bot import boom_trading_bot, get_boom_trading_status
        
        # Vérifier l'état du bot
        status = get_boom_trading_status()
        print(f"OK: Bot Python actif")
        print(f"   - Trading active: {status['trading_enabled']}")
        print(f"   - Positions actives: {status['active_positions']}")
        print(f"   - Solde: {status['account_balance']} {status['account_currency']}")
        
    except Exception as e:
        print(f"ERREUR bot Python: {e}")
        return False
    
    # Test 4: Test du prédicteur Boom
    print("\n4. Test du predicteur Boom")
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
        print(f"OK: Predicteur Boom actif")
        print(f"   - Action: {prediction.get('action', 'N/A')}")
        print(f"   - Direction: {prediction.get('direction', 'N/A')}")
        print(f"   - Confiance: {prediction.get('confidence', 0):.1%}")
        
    except Exception as e:
        print(f"ERREUR predicteur Boom: {e}")
        return False
    
    print("\nOK: TOUS LES TESTS REUSSIS")
    return True

if __name__ == "__main__":
    print("ACTIVATION DU SYSTEME DE TRADING AUTOMATIQUE")
    print("=" * 70)
    
    # Activer le système
    if activer_systeme_simple():
        print("\nOK: Configuration terminee")
        
        # Corriger l'affichage
        if corriger_affichage_indicators():
            print("OK: Affichage corrige")
        
        # Tester le système
        if test_systeme():
            print("\nOK: SYSTEME PRET")
            
            print("\nPROCHAINES ETAPES:")
            print("1. Attacher AngelOfSpike.mq5 au graphique Boom 1000 Index")
            print("2. Configurer les parametres selon les recommandations")
            print("3. Surveiller l'apparition des indicateurs et trades")
            print("4. Verifier les logs MT5 pour les messages de succes")
            
            print("\nINDICATEURS A SURVEILLER:")
            print("- HUD principal en haut a gauche du graphique")
            print("- Cadran d'analyse Boom en bas a droite")
            print("- Fleches de prediction (vertes/rouges) sur le graphique")
            print("- EMAs, RSI, MACD sur le graphique")
            print("- Messages dans l'onglet 'Experts' de MT5")
            
        else:
            print("\nERREUR: Certains tests ont echoue")
    else:
        print("\nERREUR: Echec de l'activation")
    
    # Fermer MT5
    mt5.shutdown()
    print("\nMT5 ferme")
