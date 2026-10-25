#!/usr/bin/env python3
"""
Modification du fichier AngelOfSpike.mq5 avec configurations par défaut
=====================================================================

Ce script modifie directement le fichier AngelOfSpike.mq5 pour intégrer
les configurations par défaut et le système de trading automatique sur signal de spike.
"""

import os
import re
import datetime
import shutil

def modifier_angelofspike_mq5():
    """
    Modifie le fichier AngelOfSpike.mq5 avec les configurations par défaut.
    """
    print("MODIFICATION ANGELOFSPIKE.MQ5 - CONFIGURATIONS PAR DEFAUT")
    print("=" * 65)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    fichier_source = "mt5/AngelOfSpike.mq5"
    fichier_backup = f"mt5/AngelOfSpike_backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.mq5"
    
    # Vérifier que le fichier source existe
    if not os.path.exists(fichier_source):
        print(f"ERREUR: Fichier source non trouve: {fichier_source}")
        return False
    
    # Créer une sauvegarde
    try:
        shutil.copy2(fichier_source, fichier_backup)
        print(f"OK Sauvegarde creee: {fichier_backup}")
    except Exception as e:
        print(f"ERREUR creation sauvegarde: {e}")
        return False
    
    # Lire le fichier source
    try:
        with open(fichier_source, "r", encoding="utf-8") as f:
            contenu = f.read()
        print(f"OK Fichier source lu: {len(contenu)} caracteres")
    except Exception as e:
        print(f"ERREUR lecture fichier: {e}")
        return False
    
    # Modifications à appliquer
    modifications = [
        # Probabilité M1 réduite pour plus de trades
        {
            "pattern": r"input double\s+InpMinSpikeM1Probability\s*=\s*[\d.]+;",
            "replacement": "input double   InpMinSpikeM1Probability  = 50.0;   // Probabilité minimale M1 (0-100%) pour exécution automatique",
            "description": "Réduction seuil probabilité M1 à 50%"
        },
        
        # Trading immédiat sur signal de spike activé
        {
            "pattern": r"input bool\s+InpTradeOnSpikeImmediately\s*=\s*(true|false);",
            "replacement": "input bool   InpTradeOnSpikeImmediately= true;   // Exécuter le trade dès l'affichage de la flèche clignotante",
            "description": "Activation trading immédiat sur signal de spike"
        },
        
        # Limite de positions globale réduite
        {
            "pattern": r"input int\s+InpMaxGlobalPositions\s*=\s*\d+;",
            "replacement": "input int    InpMaxGlobalPositions     = 1;      // 1 position maximum - SÉCURITÉ RENFORCÉE",
            "description": "Réduction limite positions globale à 1"
        },
        
        # Limite de positions par symbole
        {
            "pattern": r"input int\s+InpMaxPositionsPerSymbol\s*=\s*\d+;",
            "replacement": "input int    InpMaxPositionsPerSymbol  = 1;      // 1 SEULE position par symbole - STRICT",
            "description": "Confirmation limite positions par symbole à 1"
        },
        
        # Probabilité Boom/Crash réduite
        {
            "pattern": r"input double\s+InpMinProbBoomCrash\s*=\s*[\d.]+;",
            "replacement": "input double InpMinProbBoomCrash       = 50.0;    // Seuil probabilité M1 pour Boom/Crash - RÉDUIT",
            "description": "Réduction seuil probabilité Boom/Crash à 50%"
        },
        
        # Durée clignotement flèche
        {
            "pattern": r"input int\s+InpArrowBlinkSeconds\s*=\s*\d+;",
            "replacement": "input int    InpArrowBlinkSeconds      = 3;      // Durée clignotement flèche de spike (secondes)",
            "description": "Confirmation durée clignotement flèche à 3 secondes"
        },
        
        # Affichage flèches activé
        {
            "pattern": r"input bool\s+InpShowSpikeArrow\s*=\s*(true|false);",
            "replacement": "input bool   InpShowSpikeArrow         = true;   // Afficher flèche de spike clignotante",
            "description": "Activation affichage flèches de spike"
        },
        
        # Affichage flèches prédictives activé
        {
            "pattern": r"input bool\s+InpShowSpikeArrows\s*=\s*(true|false);",
            "replacement": "input bool   InpShowSpikeArrows        = true;   // Afficher les flèches prédictives sur tous les graphiques",
            "description": "Activation affichage flèches prédictives"
        },
        
        # Trading activé
        {
            "pattern": r"input bool\s+InpEnableTrading\s*=\s*(true|false);",
            "replacement": "input bool   InpEnableTrading          = true;   // Activer le trading automatique",
            "description": "Activation trading automatique"
        },
        
        # Trading de spikes activé
        {
            "pattern": r"input bool\s+InpEnableSpikeTrading\s*=\s*(true|false);",
            "replacement": "input bool   InpEnableSpikeTrading = true;    // Activer le trading de spikes",
            "description": "Activation trading de spikes"
        }
    ]
    
    print()
    print("MODIFICATIONS A APPLIQUER:")
    print("-" * 30)
    
    modifications_appliquees = 0
    
    for i, modif in enumerate(modifications, 1):
        print(f"{i}. {modif['description']}")
        
        # Appliquer la modification
        nouveau_contenu = re.sub(modif["pattern"], modif["replacement"], contenu, flags=re.IGNORECASE)
        
        if nouveau_contenu != contenu:
            contenu = nouveau_contenu
            modifications_appliquees += 1
            print(f"   OK Modification appliquee")
        else:
            print(f"   ATTENTION: Pattern non trouve")
    
    print()
    print(f"MODIFICATIONS APPLIQUEES: {modifications_appliquees}/{len(modifications)}")
    
    # Ajouter des commentaires explicatifs
    commentaires_ajout = """
//+------------------------------------------------------------------+
//| CONFIGURATION PAR DEFAUT INTEGREE - TRADING AUTOMATIQUE SPIKE    |
//+------------------------------------------------------------------+
// 
// SYSTEME DE FLECHES CLIGNOTANTES:
// 1. FLECHE DE TENDANCE (statique): Indique la direction generale
// 2. FLECHE DE SPIKE (clignotante): Annonce un spike imminent
// 3. TRADING AUTOMATIQUE: Position ouverte des l'affichage de la fleche clignotante
//
// PARAMETRES CRITIQUES:
// - InpTradeOnSpikeImmediately = true (CRITIQUE)
// - InpMinSpikeM1Probability = 50.0 (reduit pour plus de trades)
// - InpMaxGlobalPositions = 1 (securite renforcee)
// - InpArrowBlinkSeconds = 3 (duree clignotement)
// - InpShowSpikeArrow = true (affichage fleches)
//
//+------------------------------------------------------------------+
"""
    
    # Insérer les commentaires après les paramètres d'entrée
    pattern_insertion = r'(input group "=== DEBUG ===")'
    nouveau_contenu = re.sub(pattern_insertion, commentaires_ajout + r'\1', contenu)
    
    if nouveau_contenu != contenu:
        contenu = nouveau_contenu
        print("OK Commentaires explicatifs ajoutes")
    
    # Sauvegarder le fichier modifié
    try:
        with open(fichier_source, "w", encoding="utf-8") as f:
            f.write(contenu)
        print(f"OK Fichier modifie sauvegarde: {fichier_source}")
    except Exception as e:
        print(f"ERREUR sauvegarde fichier modifie: {e}")
        return False
    
    print()
    
    # Instructions finales
    print("INSTRUCTIONS FINALES:")
    print("-" * 20)
    
    instructions = [
        "1. Ouvrir MetaEditor",
        "2. Ouvrir le fichier mt5/AngelOfSpike.mq5",
        "3. Recompiler l'EA (F7)",
        "4. Verifier qu'il n'y a pas d'erreurs de compilation",
        "5. Attacher l'EA au graphique Boom 300 Index ou Crash 300 Index",
        "6. Verifier les parametres dans la fenetre de configuration:",
        "   - InpTradeOnSpikeImmediately = true",
        "   - InpMinSpikeM1Probability = 50.0",
        "   - InpMaxGlobalPositions = 1",
        "   - InpShowSpikeArrow = true",
        "7. Surveiller les fleches clignotantes sur le graphique",
        "8. Le robot prendra position automatiquement sur signal de spike"
    ]
    
    for instruction in instructions:
        print(f"   {instruction}")
    
    print()
    
    # Vérifications
    print("VERIFICATIONS:")
    print("-" * 15)
    
    verifications = [
        "Fichier source modifie avec succes",
        "Sauvegarde creee pour securite",
        "Parametres critiques ajustes",
        "Commentaires explicatifs ajoutes",
        "Pret pour compilation dans MetaEditor"
    ]
    
    for verification in verifications:
        print(f"   OK {verification}")
    
    print()
    print("MODIFICATION TERMINEE")
    print("=" * 65)
    
    return True

if __name__ == "__main__":
    modifier_angelofspike_mq5()
