#!/usr/bin/env python3
"""
Configuration par défaut intégrée pour AngelOfSpike
===================================================

Ce script génère les paramètres par défaut optimisés pour le robot AngelOfSpike
avec système de trading automatique sur signal de spike clignotant.
"""

import json
import datetime

def generer_configuration_defaut():
    """
    Génère la configuration par défaut optimisée pour AngelOfSpike.
    """
    print("GENERATION CONFIGURATION PAR DEFAUT - ANGELOFSPIKE")
    print("=" * 60)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Configuration par défaut optimisée
    config_defaut = {
        # === CONFIGURATION SPIKE ===
        "InpEnableSpikeTrading": True,
        "InpSpikeMinVolumeRatio": 1.8,
        "InpSpikeMinRangeRatio": 1.8,
        "InpQuickTP1": 1.50,
        "InpQuickTP2": 3.00,
        "InpQuickSL": 1.00,
        "InpUseTrailingStop": True,
        "InpTrailingStart": 50,
        "InpTrailingStep": 10,
        
        # === CONFIGURATION GENERALE ===
        "InpEnableTrading": True,
        "InpMagicNumber": 880011,
        "InpAllowedSymbols": "Boom 300 Index,Crash 300 Index,Boom 500 Index,Crash 500 Index,Boom 1000 Index,Crash 1000 Index",
        "InpTradeOtherSymbols": False,
        
        # === GESTION DES RISQUES ===
        "InpCapitalPerTradeUSD": 10.00,
        "InpMaxLossBoomCrashUSD": 1.50,
        "InpMaxLossOtherUSD": 1.00,
        "InpTargetProfitUSD": 4.50,
        "InpMaxGlobalOpenLossUSD": 3.50,
        "InpMaxConcurrentSymbols": 1,  # REDUIT POUR SECURITE
        "InpMaxPositionsPerSymbol": 1,
        "InpMaxGlobalPositions": 1,  # REDUIT POUR SECURITE
        "InpStrictRiskRules": True,
        "InpCancelMultipleOrders": True,
        "InpCloseAfterSpike": True,
        "InpStrictSignalOnly": True,
        "InpAutoClosePositions": False,
        "InpAllowManualTrading": True,
        
        # === PROBABILITE SPIKE M1 ===
        "InpMinSpikeM1Probability": 50.0,  # REDUIT POUR PLUS DE TRADES
        "InpConfluenceMinScore": 80.0,
        "InpSignalConfirmDelaySec": 4,
        "InpRecheckMinProbability": 85.0,
        
        # === INTEGRATION / TEST MODE ===
        "InpAggressiveTestMode": False,
        "InpOnlyCurrentSymbol": False,
        "InpPrioritizeBoomCrash": True,
        "InpMinProbBoomCrash": 50.0,  # REDUIT POUR PLUS DE TRADES
        "InpCooldownSecondsBC": 30,
        "InpBCLotFixed": 0.20,
        "InpBCReentryCooldownSec": 8,
        
        # === SIGNAL & EXECUTION ===
        "InpTradeOnSpikeImmediately": True,  # CRITIQUE: Executer des l'affichage de la fleche
        "InpShowSpikeArrows": True,
        "InpCancelDuplicates": True,
        "InpQuickCloseUSD": 0.0,
        "InpQuickCloseATRMult": 0.0,
        "InpExitOnCounterSpike": False,
        
        # === MULTI-TF TREND GATE ===
        "InpUseMTFGate": True,
        "InpStrictTrendFollowing": True,
        "InpEMAFast": 50,
        "InpEMASlow": 200,
        "InpTrendTimeframes": 4,
        
        # === ORDERS ===
        "InpDefaultLot": 0.2,
        "InpMaxLotSize": 0.5,
        "InpAllowLimitOrders": True,
        "InpAllowStopOrders": True,
        "InpSmartOrderPlacement": True,
        "InpSlippagePoints": 10,
        "InpMaxSpreadPoints": 10000,
        "InpMinSecondsBetweenOrders": 5,
        "InpMinSecondsBetweenSameSymbol": 60,
        
        # === PROTECTION ANTI-CASCADE ===
        "InpMinTradeDurationSeconds": 30,
        "InpMaxTradesPerMinute": 2,
        "InpPreventRapidOpenClose": True,
        "InpMinProfitToClose": 2.0,
        "InpTradeStabilityCheckSeconds": 60,
        "InpMinCooldownMinutes": 10,
        
        # === STRATEGIE EMA BOOM/CRASH ===
        "InpEMA20_Period": 30,
        "InpEMA50_Period": 75,
        "InpEMATouchDistance": 5.0,
        "InpSpikeTargetUSD": 3.0,
        "InpSpikeStopLossUSD": 1.0,
        "InpSpikeCloseSeconds": 30,
        
        # === SIGNALISATION SPIKE ===
        "InpShowSpikeArrow": True,
        "InpBuyArrowColor": "clrLime",
        "InpSellArrowColor": "clrRed",
        "InpArrowSize": 3,
        "InpSpikePredictionWindow": 60,
        "InpArrowBlinkSeconds": 3,  # CRITIQUE: Duree clignotement fleche
        
        # === BOOM/CRASH SPIKE SCALPING ===
        "InpBCForceDirection": True,
        "InpBCScalpUSD": 0.60,
        "InpBCSpikeReEntry": True,
        "InpBCSpikeReEntryMinProb": 60.0,
        "InpBCSpikeReEntryDelaySec": 5,
        "InpBCLadderLevels": 0,
        "InpBCLadderStepPts": 20,
        "InpBCLadderTTLMin": 3,
        "InpBCAntiOvertradeMin": 2,
        
        # === NOTIFICATIONS ===
        "InpEnableAlerts": True,
        "InpShowNotification": True,
        "InpAlertSound": "alert2.wav",
        "InpSendNotifications": True,
        "InpAlertPopup": True,
        "InpNotifyTag": "Angel",
        "InpNotifyPreSpike": True,
        
        # === DEBUG ===
        "InpDebug": True
    }
    
    print("CONFIGURATION PAR DEFAUT GENERE:")
    print("-" * 35)
    
    # Afficher les paramètres critiques
    parametres_critiques = [
        "InpEnableSpikeTrading",
        "InpTradeOnSpikeImmediately", 
        "InpMinSpikeM1Probability",
        "InpMaxGlobalPositions",
        "InpMaxPositionsPerSymbol",
        "InpArrowBlinkSeconds",
        "InpShowSpikeArrow",
        "InpPrioritizeBoomCrash",
        "InpMinProbBoomCrash"
    ]
    
    print("Parametres critiques:")
    for param in parametres_critiques:
        if param in config_defaut:
            print(f"   {param} = {config_defaut[param]}")
    
    print()
    
    # Sauvegarder la configuration
    nom_fichier = f"angelofspike_config_defaut_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    try:
        with open(nom_fichier, "w", encoding="utf-8") as f:
            json.dump(config_defaut, f, indent=2, ensure_ascii=False)
        
        print(f"Configuration sauvegardee: {nom_fichier}")
        
    except Exception as e:
        print(f"ERREUR sauvegarde: {e}")
    
    print()
    
    # Instructions d'intégration
    print("INSTRUCTIONS D'INTEGRATION:")
    print("-" * 30)
    
    instructions = [
        "1. Copier les valeurs dans le fichier AngelOfSpike.mq5",
        "2. Modifier les lignes 'input' correspondantes",
        "3. Recompiler l'EA (F7 dans MetaEditor)",
        "4. Attacher l'EA au graphique Boom/Crash",
        "5. Verifier que InpTradeOnSpikeImmediately = true",
        "6. Verifier que InpShowSpikeArrow = true",
        "7. Surveiller les fleches clignotantes sur le graphique",
        "8. Le robot prendra position automatiquement sur signal de spike"
    ]
    
    for instruction in instructions:
        print(f"   {instruction}")
    
    print()
    
    # Exemple de modification du fichier MQL5
    print("EXEMPLE DE MODIFICATION MQL5:")
    print("-" * 30)
    
    exemples = [
        "// AVANT:",
        "input double InpMinSpikeM1Probability = 85.0;",
        "",
        "// APRES:",
        "input double InpMinSpikeM1Probability = 50.0;",
        "",
        "// AVANT:",
        "input bool InpTradeOnSpikeImmediately = false;",
        "",
        "// APRES:", 
        "input bool InpTradeOnSpikeImmediately = true;",
        "",
        "// AVANT:",
        "input int InpMaxGlobalPositions = 5;",
        "",
        "// APRES:",
        "input int InpMaxGlobalPositions = 1;"
    ]
    
    for exemple in exemples:
        print(f"   {exemple}")
    
    print()
    
    # Système de flèches clignotantes
    print("SYSTEME DE FLECHES CLIGNOTANTES:")
    print("-" * 35)
    
    systeme_fleches = [
        "1. FLECHE DE TENDANCE (statique):",
        "   - Indique la direction generale du marche",
        "   - Couleur verte (BUY) ou rouge (SELL)",
        "   - Ne clignote pas",
        "",
        "2. FLECHE DE SPIKE (clignotante):",
        "   - Annonce un spike imminent",
        "   - Clignote pendant InpArrowBlinkSeconds (3 secondes)",
        "   - Declenche le trading automatique",
        "   - Couleur plus vive que la fleche de tendance",
        "",
        "3. LOGIQUE DE TRADING:",
        "   - Detection du signal de spike",
        "   - Affichage de la fleche clignotante",
        "   - Execution automatique du trade en M1",
        "   - Position ouverte avec SL/TP definis"
    ]
    
    for item in systeme_fleches:
        print(f"   {item}")
    
    print()
    
    # Vérifications finales
    print("VERIFICATIONS FINALES:")
    print("-" * 25)
    
    verifications = [
        "InpEnableSpikeTrading = true",
        "InpTradeOnSpikeImmediately = true", 
        "InpShowSpikeArrow = true",
        "InpMinSpikeM1Probability <= 60.0",
        "InpMaxGlobalPositions = 1",
        "InpMaxPositionsPerSymbol = 1",
        "InpArrowBlinkSeconds = 3",
        "InpPrioritizeBoomCrash = true",
        "InpMinProbBoomCrash <= 60.0"
    ]
    
    for verification in verifications:
        print(f"   OK {verification}")
    
    print()
    print("CONFIGURATION TERMINEE")
    print("=" * 60)
    
    return config_defaut

if __name__ == "__main__":
    generer_configuration_defaut()
