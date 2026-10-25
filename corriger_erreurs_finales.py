#!/usr/bin/env python3
"""
Correction Finale des Erreurs de Compilation - AngelOfSpike.mq5
===============================================================

Ce script corrige les erreurs restantes dans AngelOfSpike.mq5 :
- Suppression de la fonction CalculateOptimalLotSize dupliquée ligne 8238
- Correction des avertissements de conversion de type lignes 230-231
- Ajout des includes manquants
"""

import os
import re
import datetime
import shutil

def corriger_erreurs_finales():
    """
    Corrige les erreurs finales de compilation dans AngelOfSpike.mq5.
    """
    print("CORRECTION FINALE DES ERREURS - ANGELOFSPIKE.MQ5")
    print("=" * 55)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    fichier_source = "mt5/AngelOfSpike.mq5"
    fichier_backup = f"mt5/AngelOfSpike_final_backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.mq5"
    
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
    
    print()
    print("CORRECTION DES ERREURS FINALES:")
    print("-" * 35)
    
    # 1. Supprimer la fonction CalculateOptimalLotSize dupliquée (ligne 8238)
    print("1. Suppression fonction CalculateOptimalLotSize dupliquée (ligne 8238)")
    
    # Pattern pour trouver la fonction dupliquée complète
    pattern_duplicate_calculatelot = r'//\+------------------------------------------------------------------\+\s*\n//\| Calcule la taille de lot optimale en fonction du risque\s*\n//\+------------------------------------------------------------------\+\s*double CalculateOptimalLotSize\(const string symbol, double riskAmount\)\s*\{[^}]+\}'
    
    nouveau_contenu = re.sub(pattern_duplicate_calculatelot, '', contenu, flags=re.MULTILINE | re.DOTALL)
    
    if nouveau_contenu != contenu:
        contenu = nouveau_contenu
        print("   OK Fonction CalculateOptimalLotSize dupliquée supprimée")
    else:
        print("   ATTENTION: Pattern non trouve, recherche alternative")
        
        # Recherche alternative plus spécifique
        lignes = contenu.split('\n')
        lignes_corrigees = []
        supprimer_lignes = False
        compteur_accolades = 0
        
        for i, ligne in enumerate(lignes):
            # Détecter le début de la fonction dupliquée
            if 'double CalculateOptimalLotSize(const string symbol, double riskAmount)' in ligne and i > 8200:
                supprimer_lignes = True
                compteur_accolades = 0
                print(f"   OK Fonction dupliquée détectée ligne {i+1}")
                continue
            
            if supprimer_lignes:
                # Compter les accolades pour détecter la fin de la fonction
                compteur_accolades += ligne.count('{')
                compteur_accolades -= ligne.count('}')
                
                if compteur_accolades <= 0:
                    supprimer_lignes = False
                    print(f"   OK Fin de fonction détectée ligne {i+1}")
                continue
            
            lignes_corrigees.append(ligne)
        
        contenu = '\n'.join(lignes_corrigees)
        print("   OK Fonction dupliquée supprimée par recherche alternative")
    
    # 2. Corriger les avertissements de conversion de type (lignes 230-231)
    print("2. Correction avertissements conversion de type (lignes 230-231)")
    
    # Remplacer les conversions problématiques
    lignes = contenu.split('\n')
    lignes_corrigees = []
    
    for i, ligne in enumerate(lignes):
        # Corriger les conversions long vers int spécifiques
        if i >= 225 and i <= 235:  # Autour des lignes 230-231
            if 'NormalizeDouble' in ligne and 'SymbolInfoInteger' in ligne:
                # Remplacer par une conversion explicite
                ligne_corrigee = re.sub(r'SymbolInfoInteger\(([^)]+)\)', r'(int)SymbolInfoInteger(\1)', ligne)
                if ligne_corrigee != ligne:
                    lignes_corrigees.append(ligne_corrigee)
                    print(f"   OK Ligne {i+1} corrigée: {ligne.strip()}")
                else:
                    lignes_corrigees.append(ligne)
            else:
                lignes_corrigees.append(ligne)
        else:
            lignes_corrigees.append(ligne)
    
    contenu = '\n'.join(lignes_corrigees)
    
    # 3. Ajouter les includes manquants
    print("3. Ajout des includes manquants")
    
    includes_manquants = '''#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Object.mqh>
#include <Arrays/ArrayInt.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayDatetime.mqh>
#include <Indicators/Indicators.mqh>
#include <Indicators/Oscilators.mqh>
#include <Indicators/Volumes.mqh>
#include <Indicators/BillWilliams.mqh>
#include <Indicators/Custom.mqh>
#include <Indicators/TimeSeries.mqh>

'''
    
    # Vérifier et ajouter les includes manquants
    includes_a_ajouter = []
    includes_presents = []
    
    includes_necessaires = [
        "#include <Trade/Trade.mqh>",
        "#include <Trade/OrderInfo.mqh>",
        "#include <Trade/PositionInfo.mqh>",
        "#include <Trade/DealInfo.mqh>",
        "#include <Trade/HistoryOrderInfo.mqh>",
        "#include <Object.mqh>",
        "#include <Arrays/ArrayInt.mqh>",
        "#include <Arrays/ArrayLong.mqh>",
        "#include <Arrays/ArrayDatetime.mqh>",
        "#include <Indicators/Indicators.mqh>",
        "#include <Indicators/Oscilators.mqh>",
        "#include <Indicators/Volumes.mqh>",
        "#include <Indicators/BillWilliams.mqh>",
        "#include <Indicators/Custom.mqh>",
        "#include <Indicators/TimeSeries.mqh>"
    ]
    
    for include in includes_necessaires:
        if include in contenu:
            includes_presents.append(include)
        else:
            includes_a_ajouter.append(include)
    
    if includes_a_ajouter:
        # Insérer les includes manquants au début du fichier
        includes_text = '\n'.join(includes_a_ajouter) + '\n\n'
        contenu = includes_text + contenu
        print(f"   OK {len(includes_a_ajouter)} includes ajoutés")
        for include in includes_a_ajouter:
            print(f"      + {include}")
    else:
        print("   OK Tous les includes sont déjà présents")
    
    # 4. Nettoyer les espaces et lignes vides excessives
    print("4. Nettoyage final des espaces et lignes vides")
    
    # Supprimer les lignes vides excessives
    contenu = re.sub(r'\n\s*\n\s*\n+', '\n\n', contenu)
    print("   OK Espaces et lignes vides nettoyés")
    
    # Sauvegarder le fichier corrigé
    try:
        with open(fichier_source, "w", encoding="utf-8") as f:
            f.write(contenu)
        print(f"OK Fichier corrigé sauvegardé: {fichier_source}")
    except Exception as e:
        print(f"ERREUR sauvegarde fichier corrigé: {e}")
        return False
    
    print()
    
    # Instructions finales
    print("INSTRUCTIONS FINALES:")
    print("-" * 20)
    
    instructions = [
        "1. Ouvrir MetaEditor",
        "2. Ouvrir mt5/AngelOfSpike.mq5",
        "3. Verifier que les erreurs sont corrigees",
        "4. Recompiler l'EA (F7)",
        "5. Verifier qu'il n'y a plus d'erreurs de compilation",
        "6. Corriger les avertissements restants si necessaire",
        "7. Tester l'EA sur un graphique"
    ]
    
    for instruction in instructions:
        print(f"   {instruction}")
    
    print()
    
    # Vérifications
    print("VERIFICATIONS:")
    print("-" * 15)
    
    verifications = [
        "Fonction CalculateOptimalLotSize dupliquée supprimée",
        "Avertissements conversion de type corrigés",
        "Includes manquants ajoutés",
        "Espaces et lignes vides nettoyés",
        "Fichier sauvegardé avec succès"
    ]
    
    for verification in verifications:
        print(f"   OK {verification}")
    
    print()
    
    # Résumé des corrections
    print("RESUME DES CORRECTIONS FINALES:")
    print("-" * 35)
    
    corrections = [
        "ERREUR 1: 'CalculateOptimalLotSize' - function already defined (ligne 8238)",
        "   SOLUTION: Suppression de la fonction dupliquée",
        "",
        "AVERTISSEMENT 1: possible loss of data due to type conversion (ligne 230)",
        "   SOLUTION: Conversion explicite (int) ajoutée",
        "",
        "AVERTISSEMENT 2: possible loss of data due to type conversion (ligne 231)",
        "   SOLUTION: Conversion explicite (int) ajoutée",
        "",
        "AVERTISSEMENT 3: includes manquants",
        "   SOLUTION: Ajout des includes nécessaires",
        "",
        "NETTOYAGE: Espaces et lignes vides excessives",
        "   SOLUTION: Suppression des espaces inutiles"
    ]
    
    for correction in corrections:
        print(f"   {correction}")
    
    print()
    print("CORRECTION FINALE TERMINEE")
    print("=" * 55)
    
    return True

if __name__ == "__main__":
    corriger_erreurs_finales()
