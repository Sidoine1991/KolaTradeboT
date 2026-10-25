#!/usr/bin/env python3
"""
Test du Nouveau Système de Trading Automatique - AngelOfSpike
============================================================

Ce script teste et valide le nouveau système de trading automatique
avec flèches distinguées et exécution automatique sur signal de spike.
"""

import os
import datetime
import json

def tester_nouveau_systeme():
    """
    Teste le nouveau système de trading automatique AngelOfSpike.
    """
    print("TEST NOUVEAU SYSTEME TRADING AUTOMATIQUE - ANGELOFSPIKE")
    print("=" * 65)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # 1. Vérifier les fichiers modifiés
    print("1. VERIFICATION DES FICHIERS MODIFIES")
    print("-" * 40)
    
    fichiers_a_verifier = [
        "mt5/AngelOfSpike.mq5",
        "angelofspike_config_defaut_20251023_074913.json",
        "fonctions_fleches_distinguées_20251023_075130.mq5"
    ]
    
    for fichier in fichiers_a_verifier:
        if os.path.exists(fichier):
            taille = os.path.getsize(fichier)
            modif = datetime.datetime.fromtimestamp(os.path.getmtime(fichier))
            print(f"OK {fichier}")
            print(f"   Taille: {taille} bytes")
            print(f"   Modifie: {modif.strftime('%Y-%m-%d %H:%M:%S')}")
        else:
            print(f"ERREUR {fichier} - FICHIER MANQUANT")
        print()
    
    # 2. Vérifier les modifications dans AngelOfSpike.mq5
    print("2. VERIFICATION DES MODIFICATIONS ANGELOFSPIKE.MQ5")
    print("-" * 50)
    
    try:
        with open("mt5/AngelOfSpike.mq5", "r", encoding="utf-8") as f:
            contenu = f.read()
        
        modifications_verifiees = [
            ("InpMinSpikeM1Probability  = 50.0", "Seuil probabilité M1 réduit à 50%"),
            ("InpTradeOnSpikeImmediately= true", "Trading immédiat sur signal activé"),
            ("InpMaxGlobalPositions     = 1", "Limite positions globale réduite à 1"),
            ("InpMaxPositionsPerSymbol  = 1", "Limite positions par symbole confirmée à 1"),
            ("InpMinProbBoomCrash       = 50.0", "Seuil probabilité Boom/Crash réduit à 50%"),
            ("InpArrowBlinkSeconds      = 3", "Durée clignotement flèche confirmée à 3s"),
            ("InpShowSpikeArrow         = true", "Affichage flèches de spike activé"),
            ("InpShowSpikeArrows        = true", "Affichage flèches prédictives activé"),
            ("InpEnableTrading          = true", "Trading automatique activé"),
            ("InpEnableSpikeTrading = true", "Trading de spikes activé")
        ]
        
        modifications_trouvees = 0
        
        for pattern, description in modifications_verifiees:
            if pattern in contenu:
                print(f"OK {description}")
                modifications_trouvees += 1
            else:
                print(f"ERREUR {description} - Pattern non trouve")
        
        print()
        print(f"MODIFICATIONS VERIFIEES: {modifications_trouvees}/{len(modifications_verifiees)}")
        
    except Exception as e:
        print(f"ERREUR lecture fichier AngelOfSpike.mq5: {e}")
    
    print()
    
    # 3. Vérifier la configuration par défaut
    print("3. VERIFICATION CONFIGURATION PAR DEFAUT")
    print("-" * 40)
    
    try:
        with open("angelofspike_config_defaut_20251023_074913.json", "r", encoding="utf-8") as f:
            config = json.load(f)
        
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
        
        print("Parametres critiques dans la configuration:")
        for param in parametres_critiques:
            if param in config:
                print(f"   OK {param} = {config[param]}")
            else:
                print(f"   ERREUR {param} - MANQUANT")
        
    except Exception as e:
        print(f"ERREUR lecture configuration: {e}")
    
    print()
    
    # 4. Vérifier les fonctions MQL5 générées
    print("4. VERIFICATION FONCTIONS MQL5 GENEREES")
    print("-" * 40)
    
    try:
        with open("fonctions_fleches_distinguées_20251023_075130.mq5", "r", encoding="utf-8") as f:
            fonctions = f.read()
        
        fonctions_verifiees = [
            ("DrawTrendArrow", "Fonction flèche de tendance"),
            ("DrawSpikeArrow", "Fonction flèche de spike"),
            ("StartArrowBlinking", "Fonction clignotement"),
            ("ExecuteSpikeTrade", "Fonction exécution automatique"),
            ("CalculateLotSize", "Fonction calcul taille de lot"),
            ("CalculateSLTP", "Fonction calcul SL/TP"),
            ("IsBoomCrashSymbol", "Fonction vérification symbole"),
            ("CountOpenPositionsEA", "Fonction comptage positions")
        ]
        
        print("Fonctions MQL5 générées:")
        for fonction, description in fonctions_verifiees:
            if fonction in fonctions:
                print(f"   OK {description} - {fonction}()")
            else:
                print(f"   ERREUR {description} - {fonction}() MANQUANTE")
        
    except Exception as e:
        print(f"ERREUR lecture fonctions MQL5: {e}")
    
    print()
    
    # 5. Instructions de test
    print("5. INSTRUCTIONS DE TEST")
    print("-" * 25)
    
    instructions_test = [
        "1. Ouvrir MetaEditor",
        "2. Ouvrir mt5/AngelOfSpike.mq5",
        "3. Copier les fonctions depuis fonctions_fleches_distinguées_*.mq5",
        "4. Recompiler l'EA (F7)",
        "5. Verifier qu'il n'y a pas d'erreurs de compilation",
        "6. Attacher l'EA au graphique Boom 300 Index",
        "7. Verifier les parametres dans la fenetre de configuration",
        "8. Surveiller l'onglet 'Experts' pour les messages",
        "9. Observer les fleches sur le graphique:",
        "   - Fleche de tendance (bleue/orange, statique)",
        "   - Fleche de spike (verte/rouge, clignotante)",
        "10. Verifier que le trading automatique se declenche sur signal de spike"
    ]
    
    for instruction in instructions_test:
        print(f"   {instruction}")
    
    print()
    
    # 6. Messages à surveiller
    print("6. MESSAGES A SURVEILLER DANS MT5")
    print("-" * 35)
    
    messages_positifs = [
        "Angel of Spike - Initialisation reussie",
        "FLECHE DE TENDANCE dessinee",
        "FLECHE DE SPIKE CLIGNOTANTE dessinee",
        "TRADE SPIKE EXECUTE",
        "Clignotement termine",
        "SPIKE M1 DETECTE ET EXECUTE"
    ]
    
    messages_negatifs = [
        "Erreur creation fleche",
        "Trading desactive",
        "Limite de positions atteinte",
        "Cooldown actif",
        "Taille de lot invalide",
        "Echec execution trade"
    ]
    
    print("Messages POSITIFS (bon fonctionnement):")
    for msg in messages_positifs:
        print(f"   '{msg}'")
    
    print()
    print("Messages NEGATIFS (problemes):")
    for msg in messages_negatifs:
        print(f"   '{msg}'")
    
    print()
    
    # 7. Checklist de validation
    print("7. CHECKLIST DE VALIDATION")
    print("-" * 30)
    
    checklist = [
        "EA compile sans erreur",
        "EA s'attache au graphique Boom/Crash",
        "Smiley sourit dans le coin du graphique",
        "Parametres corrects dans la configuration",
        "Fleches de tendance apparaissent (statiques)",
        "Fleches de spike apparaissent (clignotantes)",
        "Trading automatique se declenche sur signal",
        "Positions s'ouvrent automatiquement",
        "SL/TP sont appliques correctement",
        "Messages positifs dans l'onglet Experts"
    ]
    
    for i, item in enumerate(checklist, 1):
        print(f"   {i}. {item}")
    
    print()
    
    # 8. Résumé du système
    print("8. RESUME DU NOUVEAU SYSTEME")
    print("-" * 30)
    
    resume = [
        "SYSTEME DE FLECHES DISTINGUEES:",
        "   - Fleche de tendance: Bleue/Orange, statique",
        "   - Fleche de spike: Verte/Rouge, clignotante",
        "",
        "TRADING AUTOMATIQUE:",
        "   - Detection du signal de spike",
        "   - Affichage de la fleche clignotante",
        "   - Execution automatique du trade",
        "   - Gestion des SL/TP",
        "",
        "CONFIGURATION OPTIMISEE:",
        "   - Seuil probabilite M1: 50% (reduit)",
        "   - Limite positions: 1 globale, 1 par symbole",
        "   - Trading immediat sur signal: Active",
        "   - Clignotement fleche: 3 secondes",
        "",
        "SECURITE RENFORCEE:",
        "   - Limite stricte des positions",
        "   - Cooldown entre trades",
        "   - Verification des conditions",
        "   - Gestion des risques"
    ]
    
    for item in resume:
        print(f"   {item}")
    
    print()
    print("TEST TERMINE")
    print("=" * 65)

if __name__ == "__main__":
    tester_nouveau_systeme()
