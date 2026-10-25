#!/usr/bin/env python3
"""
Diagnostic Complet du Robot de Trading - AngelOfSpike
====================================================

Ce script diagnostique pourquoi le robot ne prend plus de trades depuis 10h.
"""

import os
import json
import datetime
from pathlib import Path

def diagnostic_robot_complet():
    """
    Diagnostic complet des causes possibles d'arrêt du robot.
    """
    print("DIAGNOSTIC COMPLET - ROBOT ANGELOFSPIKE")
    print("=" * 60)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # 1. Vérifier l'état des fichiers principaux
    print("VERIFICATION DES FICHIERS PRINCIPAUX")
    print("-" * 40)
    
    fichiers_critiques = [
        "mt5/AngelOfSpike.mq5",
        "boom_trading_bot.py", 
        "logs/auto_signals.log",
        "logs/auto_monitor_config.json"
    ]
    
    for fichier in fichiers_critiques:
        if os.path.exists(fichier):
            taille = os.path.getsize(fichier)
            modif = datetime.datetime.fromtimestamp(os.path.getmtime(fichier))
            print(f"OK {fichier} - {taille} bytes - Modifie: {modif.strftime('%Y-%m-%d %H:%M:%S')}")
        else:
            print(f"ERREUR {fichier} - FICHIER MANQUANT")
    
    print()
    
    # 2. Analyser la configuration
    print("ANALYSE DE LA CONFIGURATION")
    print("-" * 35)
    
    try:
        with open("logs/auto_monitor_config.json", "r") as f:
            config = json.load(f)
        
        print("Configuration actuelle:")
        for key, value in config.items():
            print(f"   {key}: {value}")
            
        # Vérifier les paramètres critiques
        if config.get("min_confidence", 0) > 80:
            print("ATTENTION: Seuil de confiance tres eleve (>80%)")
        if config.get("scan_interval", 0) > 5:
            print("ATTENTION: Intervalle de scan eleve (>5min)")
            
    except Exception as e:
        print(f"ERREUR lecture config: {e}")
    
    print()
    
    # 3. Analyser les logs récents
    print("ANALYSE DES LOGS RECENTS")
    print("-" * 30)
    
    try:
        with open("logs/auto_signals.log", "r") as f:
            lignes = f.readlines()
        
        if lignes:
            derniere_ligne = lignes[-1].strip()
            print(f"Derniere activite: {derniere_ligne}")
            
            # Chercher les erreurs récentes
            erreurs_recentes = []
            for ligne in lignes[-50:]:  # 50 dernières lignes
                if any(mot in ligne.lower() for mot in ['error', 'erreur', 'bloque', 'cooldown', 'désactivé']):
                    erreurs_recentes.append(ligne.strip())
            
            if erreurs_recentes:
                print("ERREURS RECENTES DETECTEES:")
                for erreur in erreurs_recentes[-5:]:  # 5 dernières erreurs
                    print(f"   {erreur}")
            else:
                print("Aucune erreur recente detectee")
        else:
            print("Fichier de log vide")
            
    except Exception as e:
        print(f"ERREUR lecture logs: {e}")
    
    print()
    
    # 4. Vérifier l'état du système Python
    print("ETAT DU SYSTEME PYTHON")
    print("-" * 25)
    
    # Vérifier si boom_trading_bot.py est désactivé
    try:
        with open("boom_trading_bot.py", "r") as f:
            contenu = f.read()
        
        if "DISABLED = True" in contenu:
            print("ATTENTION: boom_trading_bot.py est DESACTIVE (DISABLED = True)")
            print("   -> Le systeme Python ne peut pas trader automatiquement")
        else:
            print("OK boom_trading_bot.py est active")
            
    except Exception as e:
        print(f"ERREUR lecture boom_trading_bot.py: {e}")
    
    print()
    
    # 5. Causes probables d'arrêt
    print("CAUSES PROBABLES D'ARRET")
    print("-" * 30)
    
    causes = [
        {
            "cause": "Système Python Désactivé",
            "probabilite": "HAUTE",
            "description": "boom_trading_bot.py a DISABLED = True",
            "solution": "Le trading automatique Python est désactivé. Utiliser uniquement AngelOfSpike.mq5"
        },
        {
            "cause": "Seuil de Confiance Trop Élevé", 
            "probabilite": "MOYENNE",
            "description": "min_confidence > 80% dans la config",
            "solution": "Réduire min_confidence à 50-60%"
        },
        {
            "cause": "Cooldown Actif",
            "probabilite": "MOYENNE", 
            "description": "Le robot est en période de cooldown après des pertes",
            "solution": "Attendre la fin du cooldown ou le réinitialiser"
        },
        {
            "cause": "EA AngelOfSpike Non Chargé",
            "probabilite": "HAUTE",
            "description": "L'Expert Advisor n'est pas attaché au graphique MT5",
            "solution": "Attacher AngelOfSpike.mq5 au graphique Boom/Crash"
        },
        {
            "cause": "Paramètres EA Trop Stricts",
            "probabilite": "MOYENNE",
            "description": "Seuils de probabilité M1 trop élevés dans l'EA",
            "solution": "Réduire InpMinSpikeM1Probability à 60-70%"
        }
    ]
    
    for i, cause in enumerate(causes, 1):
        print(f"{i}. {cause['cause']} [{cause['probabilite']}]")
        print(f"   Description: {cause['description']}")
        print(f"   Solution: {cause['solution']}")
        print()
    
    # 6. Actions immédiates recommandées
    print("ACTIONS IMMEDIATES RECOMMANDEES")
    print("-" * 40)
    
    actions = [
        "1. Vérifier que AngelOfSpike.mq5 est attaché au graphique MT5",
        "2. Contrôler les paramètres de l'EA dans MT5:",
        "   - InpEnableSpikeTrading = true",
        "   - InpMinSpikeM1Probability = 60.0 (au lieu de 85.0)",
        "   - InpMaxGlobalPositions = 1",
        "3. Vérifier que le symbole Boom/Crash est dans Market Watch",
        "4. Redémarrer l'EA si nécessaire",
        "5. Surveiller les logs MT5 pour les messages d'erreur",
        "6. Tester avec des paramètres plus permissifs"
    ]
    
    for action in actions:
        print(f"   {action}")
    
    print()
    
    # 7. Paramètres de test recommandés
    print("PARAMETRES DE TEST RECOMMANDES")
    print("-" * 35)
    
    params_test = {
        "InpEnableSpikeTrading": "true",
        "InpMinSpikeM1Probability": "60.0",
        "InpMaxGlobalPositions": "1", 
        "InpMaxPositionsPerSymbol": "1",
        "InpCooldownSeconds": "30",
        "InpSpikeStopLossUSD": "2.00",
        "InpQuickTP1": "3.00",
        "InpPrioritizeBoomCrash": "true",
        "InpMinProbBoomCrash": "60.0"
    }
    
    for param, value in params_test.items():
        print(f"   {param} = {value}")
    
    print()
    
    # 8. Messages à surveiller dans MT5
    print("MESSAGES A SURVEILLER DANS MT5")
    print("-" * 35)
    
    messages = [
        "Angel of Spike - Initialisation reussie",
        "SPIKE M1 DETECTE ET EXECUTE",
        "[BLOQUE] Trade bloque par gestion des risques", 
        "[COOLDOWN] Cooldown actif",
        "[ERREUR] Confiance insuffisante",
        "[ERREUR] SL/TP invalides",
        "Position fermee avec profit",
        "Position fermee avec perte"
    ]
    
    for message in messages:
        print(f"   '{message}'")
    
    print()
    print("DIAGNOSTIC TERMINE")
    print("=" * 60)

if __name__ == "__main__":
    diagnostic_robot_complet()
