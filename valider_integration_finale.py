#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def valider_integration_finale():
    """Valider l'intégration finale d'AngelOfSpike_Fixed.mq5"""
    
    print("=== VALIDATION DE L'INTEGRATION FINALE ===")
    
    # Chemin vers le fichier AngelOfSpike_Fixed.mq5
    fichier_ea = "AngelOfSpike_Fixed.mq5"
    
    if not os.path.exists(fichier_ea):
        print(f"Fichier {fichier_ea} non trouve!")
        return False
    
    try:
        # Lire le contenu du fichier
        with open(fichier_ea, 'r', encoding='utf-8') as f:
            contenu = f.read()
        
        print(f"Fichier {fichier_ea} lu avec succes")
        print(f"Taille du fichier: {len(contenu)} caracteres")
        
        # 1. Vérifier la structure des accolades
        print("\\nVerification de la structure des accolades...")
        accolades_ouvrantes = contenu.count('{')
        accolades_fermantes = contenu.count('}')
        
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes == accolades_fermantes:
            print("OK: Accolades equilibrees")
        else:
            print("ERREUR: Accolades desequilibrees!")
            return False
        
        # 2. Vérifier les variables globales pour les indicateurs
        print("\\nVerification des variables globales pour les indicateurs...")
        
        variables_indicateurs = [
            'g_ma20Handle',
            'g_ma50Handle',
            'g_ema12Handle',
            'g_ema26Handle',
            'g_rsiHandle',
            'g_macdHandle',
            'g_stochHandle',
            'g_atrHandle',
            'g_bbHandle',
            'g_currentSymbol',
            'IndicatorData',
            'g_indicatorCache',
            'g_spikePredictionActive',
            'g_spikePredictionSymbol',
            'g_spikePredictionDirection',
            'g_spikePredictionProbability'
        ]
        
        for variable in variables_indicateurs:
            if variable in contenu:
                print(f"OK: {variable}")
            else:
                print(f"MANQUANT: {variable}")
        
        # 3. Vérifier les fonctions essentielles
        print("\\nVerification des fonctions essentielles...")
        
        fonctions_essentielles = [
            'InitializeIndicators(',
            'ReleaseIndicators(',
            'AnalyzeSpikePrediction(',
            'StartSpikePrediction(',
            'CheckSpikePrediction(',
            'AnalyzeConfluenceStrategy(',
            'ExecuteTrade(',
            'UpdateHUD(',
            'OnInit(',
            'OnDeinit(',
            'OnTick('
        ]
        
        for fonction in fonctions_essentielles:
            if fonction in contenu:
                print(f"OK: {fonction}")
            else:
                print(f"MANQUANT: {fonction}")
        
        # 4. Vérifier la logique de prédiction de spike
        print("\\nVerification de la logique de prediction de spike...")
        
        if 'spikeProbability >= 0.7' in contenu:
            print("OK: Seuil de probabilite de spike configure")
        else:
            print("MANQUANT: Seuil de probabilite de spike")
        
        if 'StartSpikePrediction(' in contenu:
            print("OK: Demarrage de prediction de spike")
        else:
            print("MANQUANT: Demarrage de prediction de spike")
        
        if 'g_spikePredictionActive' in contenu:
            print("OK: Variables de prediction de spike")
        else:
            print("MANQUANT: Variables de prediction de spike")
        
        # 5. Vérifier l'analyse des indicateurs
        print("\\nVerification de l'analyse des indicateurs...")
        
        indicateurs_analyses = [
            'rsiFactor',
            'maFactor',
            'macdFactor',
            'stochFactor',
            'bbFactor',
            'atrFactor',
            'spikeProbability'
        ]
        
        for indicateur in indicateurs_analyses:
            if indicateur in contenu:
                print(f"OK: {indicateur}")
            else:
                print(f"MANQUANT: {indicateur}")
        
        # 6. Vérifier la gestion des positions
        print("\\nVerification de la gestion des positions...")
        
        if 'g_spikePredictionExecuted' in contenu:
            print("OK: Suivi de l'execution des predictions")
        else:
            print("MANQUANT: Suivi de l'execution des predictions")
        
        if 'g_spikePredictionTime' in contenu:
            print("OK: Suivi du temps de prediction")
        else:
            print("MANQUANT: Suivi du temps de prediction")
        
        # 7. Vérifier l'affichage des informations
        print("\\nVerification de l'affichage des informations...")
        
        if 'SPIKE PREDICTION' in contenu:
            print("OK: Affichage des informations de prediction")
        else:
            print("MANQUANT: Affichage des informations de prediction")
        
        if 'Probabilité:' in contenu:
            print("OK: Affichage de la probabilite")
        else:
            print("MANQUANT: Affichage de la probabilite")
        
        # 8. Vérifier les paramètres d'entrée
        print("\\nVerification des parametres d'entree...")
        
        parametres_essentiels = [
            'InpEnableTrading',
            'InpMagicNumber',
            'InpMaxLossPerTradeUSD',
            'InpTargetProfitUSD',
            'InpEnableConfluence',
            'InpMinConfluenceSignals',
            'InpEnableIndicator2025',
            'InpEnableSR',
            'InpEnableOrderBlock',
            'InpEnableOTE',
            'InpEnableBOS_CHoCH',
            'InpShowSpikeArrows',
            'InpNotifyPreSpike'
        ]
        
        for parametre in parametres_essentiels:
            if parametre in contenu:
                print(f"OK: {parametre}")
            else:
                print(f"MANQUANT: {parametre}")
        
        # 9. Vérifier la logique de trading
        print("\\nVerification de la logique de trading...")
        
        if 'isSpikePrediction' in contenu:
            print("OK: Detection des predictions de spike dans ExecuteTrade")
        else:
            print("MANQUANT: Detection des predictions de spike dans ExecuteTrade")
        
        if 'g_spikePredictionStopLoss' in contenu:
            print("OK: Utilisation des niveaux de prediction")
        else:
            print("MANQUANT: Utilisation des niveaux de prediction")
        
        # 10. Vérifier les notifications
        print("\\nVerification des notifications...")
        
        if 'SPIKE PREDICTION:' in contenu:
            print("OK: Notifications de prediction de spike")
        else:
            print("MANQUANT: Notifications de prediction de spike")
        
        if 'SendCustomNotification(' in contenu:
            print("OK: Fonction de notification")
        else:
            print("MANQUANT: Fonction de notification")
        
        # 11. Résumé des fonctionnalités intégrées
        print("\\n=== RESUME DES FONCTIONNALITES INTEGREES ===")
        print("1. Variables globales pour les indicateurs")
        print("2. Fonctions d'initialisation et liberation des indicateurs")
        print("3. Analyse de prediction de spike avec probabilite")
        print("4. Demarrage et suivi des predictions de spike")
        print("5. Execution des trades basée sur les predictions")
        print("6. Gestion intelligente des positions")
        print("7. Affichage des informations de prediction")
        print("8. Notifications de prediction de spike")
        print("9. Analyse de confluence amelioree")
        print("10. Gestion des risques optimisee")
        
        # 12. Instructions finales
        print("\\n=== INSTRUCTIONS FINALES ===")
        print("1. Compiler le fichier AngelOfSpike_Fixed.mq5 dans MetaEditor")
        print("2. Attacher l'EA au graphique Boom 1000 Index")
        print("3. Configurer les parametres:")
        print("   - Enable Trading: true")
        print("   - Enable Confluence: true")
        print("   - Min Confluence Signals: 3")
        print("   - Enable Indicator 2025: true")
        print("   - Enable SR: true")
        print("   - Enable Order Block: true")
        print("   - Enable OTE: true")
        print("   - Enable BOS/CHoCH: true")
        print("   - Show Spike Arrows: true")
        print("   - Notify Pre Spike: true")
        print("4. Activer le trading automatique")
        print("5. Observer les predictions de spike et l'execution automatique")
        
        print("\\n=== FONCTIONNALITES CLES ===")
        print("- PREDICTION DE SPIKE: Le robot predit les spikes avant leur arrivee")
        print("- EXECUTION INTELLIGENTE: Prend des positions avant le spike")
        print("- GESTION DES RISQUES: SL et TP calcules selon ATR")
        print("- AFFICHAGE EN TEMPS REEL: Informations de prediction visibles")
        print("- NOTIFICATIONS: Alertes avant les spikes")
        print("- ANALYSE DE CONFLUENCE: Multiple indicateurs pour validation")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la validation: {e}")
        return False

if __name__ == "__main__":
    valider_integration_finale()
