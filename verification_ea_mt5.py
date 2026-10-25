#!/usr/bin/env python3
"""
Vérification de l'Expert Advisor AngelOfSpike dans MT5
=====================================================

Ce script vérifie l'état de l'EA et fournit des instructions pour le relancer.
"""

import os
import datetime

def verification_ea_mt5():
    """
    Vérification complète de l'état de l'Expert Advisor AngelOfSpike.
    """
    print("VERIFICATION EXPERT ADVISOR ANGELOFSPIKE")
    print("=" * 50)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # 1. Vérifier l'existence du fichier EA
    print("1. VERIFICATION DU FICHIER EA")
    print("-" * 30)
    
    ea_file = "mt5/AngelOfSpike.mq5"
    if os.path.exists(ea_file):
        taille = os.path.getsize(ea_file)
        modif = datetime.datetime.fromtimestamp(os.path.getmtime(ea_file))
        print(f"OK Fichier EA trouve: {ea_file}")
        print(f"   Taille: {taille} bytes")
        print(f"   Derniere modification: {modif.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Vérifier si le fichier a été modifié récemment
        maintenant = datetime.datetime.now()
        diff_heures = (maintenant - modif).total_seconds() / 3600
        if diff_heures < 24:
            print(f"   INFO: Fichier modifie il y a {diff_heures:.1f} heures")
        else:
            print(f"   ATTENTION: Fichier modifie il y a {diff_heures:.1f} heures")
    else:
        print(f"ERREUR: Fichier EA non trouve: {ea_file}")
        return
    
    print()
    
    # 2. Analyser les paramètres critiques du fichier EA
    print("2. ANALYSE DES PARAMETRES CRITIQUES")
    print("-" * 35)
    
    try:
        with open(ea_file, "r", encoding="utf-8") as f:
            contenu = f.read()
        
        # Chercher les paramètres critiques
        parametres_critiques = [
            "InpEnableSpikeTrading",
            "InpMinSpikeM1Probability", 
            "InpMaxGlobalPositions",
            "InpMaxPositionsPerSymbol",
            "InpCooldownSeconds",
            "InpSpikeStopLossUSD",
            "InpQuickTP1",
            "InpPrioritizeBoomCrash",
            "InpMinProbBoomCrash"
        ]
        
        print("Parametres critiques detectes:")
        for param in parametres_critiques:
            if param in contenu:
                # Extraire la ligne contenant le paramètre
                lignes = contenu.split('\n')
                for ligne in lignes:
                    if param in ligne and 'input' in ligne.lower():
                        print(f"   {ligne.strip()}")
                        break
            else:
                print(f"   ATTENTION: {param} non trouve")
        
        # Vérifier les valeurs par défaut problématiques
        if "InpMinSpikeM1Probability" in contenu:
            if "85.0" in contenu:
                print("   ATTENTION: Seuil de probabilite M1 tres eleve (85%)")
            elif "60.0" in contenu or "70.0" in contenu:
                print("   OK: Seuil de probabilite M1 raisonnable")
        
        if "InpMaxGlobalPositions" in contenu:
            if "1" in contenu:
                print("   OK: Limite de positions globale = 1")
            else:
                print("   ATTENTION: Limite de positions globale > 1")
                
    except Exception as e:
        print(f"ERREUR lecture fichier EA: {e}")
    
    print()
    
    # 3. Instructions pour vérifier l'état dans MT5
    print("3. INSTRUCTIONS POUR VERIFIER DANS MT5")
    print("-" * 40)
    
    instructions = [
        "1. Ouvrir MetaTrader 5",
        "2. Aller dans Navigator > Expert Advisors",
        "3. Chercher 'AngelOfSpike' dans la liste",
        "4. Verifier que l'EA est compile (pas d'erreur de compilation)",
        "5. Glisser l'EA sur un graphique Boom 300 Index ou Crash 300 Index",
        "6. Dans la fenetre de parametres, verifier:",
        "   - InpEnableSpikeTrading = true",
        "   - InpMinSpikeM1Probability = 60.0 (au lieu de 85.0)",
        "   - InpMaxGlobalPositions = 1",
        "   - InpMaxPositionsPerSymbol = 1",
        "7. Cliquer sur OK pour attacher l'EA",
        "8. Verifier que le smiley sourit dans le coin du graphique",
        "9. Surveiller l'onglet 'Experts' pour les messages"
    ]
    
    for instruction in instructions:
        print(f"   {instruction}")
    
    print()
    
    # 4. Messages à surveiller dans MT5
    print("4. MESSAGES A SURVEILLER DANS MT5")
    print("-" * 35)
    
    messages_positifs = [
        "Angel of Spike - Initialisation reussie",
        "SPIKE M1 DETECTE ET EXECUTE", 
        "Position ouverte avec succes",
        "Signal detecte sur Boom",
        "Signal detecte sur Crash"
    ]
    
    messages_negatifs = [
        "[BLOQUE] Trade bloque par gestion des risques",
        "[COOLDOWN] Cooldown actif",
        "[ERREUR] Confiance insuffisante",
        "[ERREUR] SL/TP invalides",
        "[ERREUR] Taille de lot invalide",
        "Trading desactive"
    ]
    
    print("Messages POSITIFS (bon fonctionnement):")
    for msg in messages_positifs:
        print(f"   '{msg}'")
    
    print()
    print("Messages NEGATIFS (problemes):")
    for msg in messages_negatifs:
        print(f"   '{msg}'")
    
    print()
    
    # 5. Actions de dépannage
    print("5. ACTIONS DE DEPANNAGE")
    print("-" * 25)
    
    actions = [
        "Si l'EA ne s'attache pas:",
        "   - Verifier que le symbole est dans Market Watch",
        "   - Redemarrer MT5",
        "   - Recompiler l'EA (F7)",
        "",
        "Si l'EA s'attache mais ne trade pas:",
        "   - Reduire InpMinSpikeM1Probability a 50.0",
        "   - Desactiver temporairement le cooldown",
        "   - Verifier que le trading automatique est autorise",
        "",
        "Si l'EA trade mais ferme immediatement:",
        "   - Verifier les parametres SL/TP",
        "   - Augmenter InpSpikeStopLossUSD",
        "   - Verifier la taille de lot minimum"
    ]
    
    for action in actions:
        print(f"   {action}")
    
    print()
    
    # 6. Configuration recommandée pour test
    print("6. CONFIGURATION RECOMMANDEE POUR TEST")
    print("-" * 40)
    
    config_test = {
        "InpEnableSpikeTrading": "true",
        "InpMinSpikeM1Probability": "50.0",
        "InpMaxGlobalPositions": "1",
        "InpMaxPositionsPerSymbol": "1", 
        "InpCooldownSeconds": "30",
        "InpSpikeStopLossUSD": "2.00",
        "InpQuickTP1": "3.00",
        "InpPrioritizeBoomCrash": "true",
        "InpMinProbBoomCrash": "50.0",
        "InpBCLotFixed": "0.10"
    }
    
    print("Parametres recommandes pour test:")
    for param, value in config_test.items():
        print(f"   {param} = {value}")
    
    print()
    
    # 7. Vérification finale
    print("7. VERIFICATION FINALE")
    print("-" * 25)
    
    checklist = [
        "EA AngelOfSpike.mq5 compile sans erreur",
        "EA attache sur graphique Boom/Crash",
        "Smiley sourit dans le coin du graphique",
        "Parametres ajustes selon recommandations",
        "Symbole Boom/Crash dans Market Watch",
        "Trading automatique autorise dans MT5",
        "Aucune position ouverte actuellement",
        "Messages positifs dans l'onglet Experts"
    ]
    
    print("Checklist de verification:")
    for i, item in enumerate(checklist, 1):
        print(f"   {i}. {item}")
    
    print()
    print("VERIFICATION TERMINEE")
    print("=" * 50)

if __name__ == "__main__":
    verification_ea_mt5()
