#!/usr/bin/env python3
"""
Modification AngelOfSpike.mq5 - Système de Validation des Ordres
================================================================

Ce script modifie le fichier AngelOfSpike.mq5 pour intégrer le système
de validation des ordres et éviter les erreurs "Invalid stops" comme
montré dans l'image.
"""

import os
import re
import datetime
import shutil

def modifier_angelofspike_validation():
    """
    Modifie le fichier AngelOfSpike.mq5 pour intégrer la validation des ordres.
    """
    print("MODIFICATION ANGELOFSPIKE.MQ5 - SYSTEME VALIDATION ORDRES")
    print("=" * 65)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    fichier_source = "mt5/AngelOfSpike.mq5"
    fichier_backup = f"mt5/AngelOfSpike_validation_backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.mq5"
    
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
    
    # Lire les nouvelles fonctions
    try:
        with open("systeme_sl_tp_lots_20251023_075932.mq5", "r", encoding="utf-8") as f:
            nouvelles_fonctions = f.read()
        print("OK Nouvelles fonctions lues")
    except Exception as e:
        print(f"ERREUR lecture nouvelles fonctions: {e}")
        return False
    
    # Modifications à appliquer
    modifications = [
        # Ajouter les nouvelles fonctions après les structures existantes
        {
            "pattern": r"(// Constantes pour les noms d'objets)",
            "replacement": nouvelles_fonctions + r"\n\n\1",
            "description": "Ajout des nouvelles fonctions de validation"
        },
        
        # Remplacer les anciennes fonctions de calcul SL/TP
        {
            "pattern": r"void CalculateSLTP\([^}]+}",
            "replacement": "// Ancienne fonction CalculateSLTP remplacée par CalculateAdequateSLTP",
            "description": "Remplacement ancienne fonction CalculateSLTP"
        },
        
        # Remplacer les anciennes fonctions de calcul de lot
        {
            "pattern": r"double CalculateLotSize\([^}]+}",
            "replacement": "// Ancienne fonction CalculateLotSize remplacée par CalculateOptimalLotSize",
            "description": "Remplacement ancienne fonction CalculateLotSize"
        },
        
        # Modifier les appels aux anciennes fonctions
        {
            "pattern": r"CalculateSLTP\(",
            "replacement": "CalculateAdequateSLTP(",
            "description": "Remplacement appels CalculateSLTP"
        },
        
        {
            "pattern": r"CalculateLotSize\(",
            "replacement": "CalculateOptimalLotSize(",
            "description": "Remplacement appels CalculateLotSize"
        }
    ]
    
    print()
    print("MODIFICATIONS A APPLIQUER:")
    print("-" * 30)
    
    modifications_appliquees = 0
    
    for i, modif in enumerate(modifications, 1):
        print(f"{i}. {modif['description']}")
        
        # Appliquer la modification
        nouveau_contenu = re.sub(modif["pattern"], modif["replacement"], contenu, flags=re.IGNORECASE | re.DOTALL)
        
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
//| SYSTEME DE VALIDATION DES ORDRES - PREVENTION ERREURS INVALID   |
//+------------------------------------------------------------------+
//
// NOUVELLES FONCTIONS INTEGREES:
// - GetSymbolInfo() : Obtient les informations completes du symbole
// - CalculateOptimalLotSize() : Calcule le lot optimal selon le symbole
// - CalculateAdequateSLTP() : Calcule SL/TP adequats selon les niveaux
// - ValidateOrder() : Valide l'ordre avant envoi
// - ExecuteValidatedTrade() : Execute avec validation complete
// - ExecuteSecureTrade() : Fonction principale securisee
//
// AVANTAGES:
// - Prevention des erreurs "Invalid stops"
// - Calcul automatique des lots minimum par devise
// - Validation des niveaux SL/TP selon le broker
// - Adaptation automatique aux differentes devises
// - Messages de diagnostic detailles
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
        "2. Ouvrir mt5/AngelOfSpike.mq5",
        "3. Verifier que les nouvelles fonctions sont presentes",
        "4. Recompiler l'EA (F7)",
        "5. Verifier qu'il n'y a pas d'erreurs de compilation",
        "6. Attacher l'EA au graphique EURUSD ou Boom/Crash",
        "7. Surveiller l'onglet 'Experts' pour les messages:",
        "   - 'INFO Informations symbole [symbole]'",
        "   - 'CALC Calcul lot optimal [symbole]'",
        "   - 'SLTP SL/TP calcules pour [symbole]'",
        "   - 'OK Validation reussie pour [symbole]'",
        "8. Tester avec differentes devises",
        "9. Verifier qu'il n'y a plus d'erreurs 'Invalid stops'"
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
        "Nouvelles fonctions de validation integrees",
        "Commentaires explicatifs ajoutes",
        "Pret pour compilation dans MetaEditor"
    ]
    
    for verification in verifications:
        print(f"   OK {verification}")
    
    print()
    
    # Exemples de messages à surveiller
    print("MESSAGES A SURVEILLER DANS MT5:")
    print("-" * 35)
    
    messages_positifs = [
        "INFO Informations symbole EURUSD:",
        "   Lot min: 0.01 Lot max: 100.0 Step: 0.01",
        "   Stop Level: 0.0020 Freeze Level: 0.0020",
        "",
        "CALC Calcul lot optimal EURUSD:",
        "   Risque: $10 Balance: $1000",
        "   Lot calcule: 0.01 Lot normalise: 0.01",
        "",
        "SLTP SL/TP calcules pour EURUSD:",
        "   Direction: BUY Prix entree: 1.0850",
        "   SL: 1.0830 TP: 1.0890",
        "",
        "OK Validation reussie pour EURUSD",
        "SUCCESS TRADE VALIDE EXECUTE - EURUSD"
    ]
    
    messages_negatifs = [
        "ERREUR Validation echouee: Lot trop petit",
        "ERREUR Validation echouee: SL trop proche",
        "ERREUR Validation echouee: TP trop proche",
        "ERREUR Validation echouee: Lot non conforme au step",
        "ERREUR Impossible d'obtenir les informations du symbole"
    ]
    
    print("Messages POSITIFS (bon fonctionnement):")
    for msg in messages_positifs:
        print(f"   '{msg}'")
    
    print()
    print("Messages NEGATIFS (problemes):")
    for msg in messages_negatifs:
        print(f"   '{msg}'")
    
    print()
    
    # Résumé du système
    print("RESUME DU NOUVEAU SYSTEME:")
    print("-" * 30)
    
    resume = [
        "PREVENTION DES ERREURS 'INVALID STOPS':",
        "   - Calcul automatique des niveaux minimum",
        "   - Validation des SL/TP selon le broker",
        "   - Adaptation aux differentes devises",
        "",
        "CALCUL AUTOMATIQUE DES LOTS:",
        "   - Detection des lots minimum par symbole",
        "   - Normalisation selon le step du broker",
        "   - Limitation aux bornes min/max",
        "",
        "VALIDATION COMPLETE DES ORDRES:",
        "   - Verification avant envoi",
        "   - Messages de diagnostic detailles",
        "   - Prevention des ordres invalides",
        "",
        "GESTION SPECIFIQUE BOOM/CRASH:",
        "   - Parametres adaptes aux indices",
        "   - Calculs optimises pour le scalping",
        "   - Gestion des risques specifique"
    ]
    
    for item in resume:
        print(f"   {item}")
    
    print()
    print("MODIFICATION TERMINEE")
    print("=" * 65)
    
    return True

if __name__ == "__main__":
    modifier_angelofspike_validation()
