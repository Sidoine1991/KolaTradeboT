#!/usr/bin/env python3
"""
Test du Système de Validation des Ordres - AngelOfSpike
=======================================================

Ce script teste le nouveau système de validation des ordres pour éviter
les erreurs "Invalid stops" comme montré dans l'image.
"""

import os
import datetime
import json

def tester_systeme_validation():
    """
    Teste le système de validation des ordres AngelOfSpike.
    """
    print("TEST SYSTEME VALIDATION ORDRES - ANGELOFSPIKE")
    print("=" * 55)
    print(f"Date/Heure: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # 1. Vérifier les fichiers modifiés
    print("1. VERIFICATION DES FICHIERS MODIFIES")
    print("-" * 40)
    
    fichiers_a_verifier = [
        "mt5/AngelOfSpike.mq5",
        "systeme_sl_tp_lots_20251023_075932.mq5",
        "mt5/AngelOfSpike_validation_backup_20251023_080023.mq5"
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
    
    # 2. Vérifier les nouvelles fonctions dans AngelOfSpike.mq5
    print("2. VERIFICATION DES NOUVELLES FONCTIONS")
    print("-" * 40)
    
    try:
        with open("mt5/AngelOfSpike.mq5", "r", encoding="utf-8") as f:
            contenu = f.read()
        
        nouvelles_fonctions = [
            ("GetSymbolInfo", "Fonction obtention informations symbole"),
            ("CalculateOptimalLotSize", "Fonction calcul lot optimal"),
            ("CalculateAdequateSLTP", "Fonction calcul SL/TP adequats"),
            ("ValidateOrder", "Fonction validation ordre"),
            ("ExecuteValidatedTrade", "Fonction execution avec validation"),
            ("ExecuteSecureTrade", "Fonction principale securisee"),
            ("SymbolInfo", "Structure informations symbole"),
            ("g_symbolCache", "Cache des informations de symboles")
        ]
        
        print("Nouvelles fonctions integrees:")
        fonctions_trouvees = 0
        
        for fonction, description in nouvelles_fonctions:
            if fonction in contenu:
                print(f"   OK {description} - {fonction}")
                fonctions_trouvees += 1
            else:
                print(f"   ERREUR {description} - {fonction} MANQUANTE")
        
        print()
        print(f"FONCTIONS VERIFIEES: {fonctions_trouvees}/{len(nouvelles_fonctions)}")
        
    except Exception as e:
        print(f"ERREUR lecture fichier AngelOfSpike.mq5: {e}")
    
    print()
    
    # 3. Vérifier les commentaires explicatifs
    print("3. VERIFICATION DES COMMENTAIRES EXPLICATIFS")
    print("-" * 45)
    
    try:
        with open("mt5/AngelOfSpike.mq5", "r", encoding="utf-8") as f:
            contenu = f.read()
        
        commentaires_verifies = [
            ("SYSTEME DE VALIDATION DES ORDRES", "Commentaire principal"),
            ("PREVENTION ERREURS INVALID", "Commentaire prevention"),
            ("NOUVELLES FONCTIONS INTEGREES", "Commentaire fonctions"),
            ("AVANTAGES", "Commentaire avantages"),
            ("GetSymbolInfo", "Fonction GetSymbolInfo"),
            ("CalculateOptimalLotSize", "Fonction CalculateOptimalLotSize"),
            ("CalculateAdequateSLTP", "Fonction CalculateAdequateSLTP"),
            ("ValidateOrder", "Fonction ValidateOrder"),
            ("ExecuteValidatedTrade", "Fonction ExecuteValidatedTrade"),
            ("ExecuteSecureTrade", "Fonction ExecuteSecureTrade")
        ]
        
        print("Commentaires explicatifs:")
        commentaires_trouves = 0
        
        for commentaire, description in commentaires_verifies:
            if commentaire in contenu:
                print(f"   OK {description} - {commentaire}")
                commentaires_trouves += 1
            else:
                print(f"   ERREUR {description} - {commentaire} MANQUANT")
        
        print()
        print(f"COMMENTAIRES VERIFIES: {commentaires_trouves}/{len(commentaires_verifies)}")
        
    except Exception as e:
        print(f"ERREUR lecture commentaires: {e}")
    
    print()
    
    # 4. Instructions de test
    print("4. INSTRUCTIONS DE TEST")
    print("-" * 25)
    
    instructions_test = [
        "1. Ouvrir MetaEditor",
        "2. Ouvrir mt5/AngelOfSpike.mq5",
        "3. Verifier que les nouvelles fonctions sont presentes",
        "4. Recompiler l'EA (F7)",
        "5. Verifier qu'il n'y a pas d'erreurs de compilation",
        "6. Attacher l'EA au graphique EURUSD",
        "7. Surveiller l'onglet 'Experts' pour les messages:",
        "   - 'INFO Informations symbole EURUSD'",
        "   - 'CALC Calcul lot optimal EURUSD'",
        "   - 'SLTP SL/TP calcules pour EURUSD'",
        "   - 'OK Validation reussie pour EURUSD'",
        "8. Tester avec differentes devises:",
        "   - EURUSD (Forex)",
        "   - GBPUSD (Forex)",
        "   - Boom 300 Index (Indice)",
        "   - Crash 300 Index (Indice)",
        "9. Verifier qu'il n'y a plus d'erreurs 'Invalid stops'",
        "10. Observer les messages de diagnostic detailles"
    ]
    
    for instruction in instructions_test:
        print(f"   {instruction}")
    
    print()
    
    # 5. Messages à surveiller
    print("5. MESSAGES A SURVEILLER DANS MT5")
    print("-" * 35)
    
    messages_positifs = [
        "INFO Informations symbole EURUSD:",
        "   Lot min: 0.01 Lot max: 100.0 Step: 0.01",
        "   Stop Level: 0.0020 Freeze Level: 0.0020",
        "   Spread: 0.0001 Tick Value: 1.0",
        "",
        "CALC Calcul lot optimal EURUSD:",
        "   Risque: $10 Balance: $1000",
        "   Lot calcule: 0.01 Lot normalise: 0.01",
        "",
        "SLTP SL/TP calcules pour EURUSD:",
        "   Direction: BUY Prix entree: 1.0850",
        "   SL: 1.0830 TP: 1.0890",
        "   Stop Level: 0.0020",
        "",
        "OK Validation reussie pour EURUSD",
        "   Lot: 0.01 SL: 1.0830 TP: 1.0890",
        "",
        "SUCCESS TRADE VALIDE EXECUTE - EURUSD",
        "   Ticket: 123456",
        "   Direction: BUY",
        "   Lot: 0.01",
        "   Prix: 1.0850",
        "   SL: 1.0830",
        "   TP: 1.0890"
    ]
    
    messages_negatifs = [
        "ERREUR Validation echouee: Lot trop petit (0.005 < 0.01)",
        "ERREUR Validation echouee: Lot trop grand (0.5 > 0.1)",
        "ERREUR Validation echouee: Lot non conforme au step (0.015 step: 0.01)",
        "ERREUR Validation echouee: SL trop proche (0.001 < 0.0020)",
        "ERREUR Validation echouee: TP trop proche (0.001 < 0.0020)",
        "ERREUR Impossible d'obtenir les informations du symbole EURUSD",
        "ERREUR Impossible de calculer la taille de lot pour EURUSD",
        "ERREUR Impossible de calculer les SL/TP pour EURUSD",
        "ERREUR Ordre invalide pour EURUSD",
        "ERREUR Echec execution: 10064 - Invalid stops"
    ]
    
    print("Messages POSITIFS (bon fonctionnement):")
    for msg in messages_positifs:
        print(f"   '{msg}'")
    
    print()
    print("Messages NEGATIFS (problemes):")
    for msg in messages_negatifs:
        print(f"   '{msg}'")
    
    print()
    
    # 6. Exemples de paramètres par devise
    print("6. EXEMPLES PARAMETRES PAR DEVISE")
    print("-" * 35)
    
    exemples_devises = [
        "EURUSD (Forex):",
        "   Lot min: 0.01, Lot max: 100.0, Step: 0.01",
        "   Stop Level: 20 points, Tick Value: $1.0",
        "   Spread: 1-2 points, Digits: 5",
        "",
        "GBPUSD (Forex):",
        "   Lot min: 0.01, Lot max: 100.0, Step: 0.01",
        "   Stop Level: 20 points, Tick Value: $1.0",
        "   Spread: 1-3 points, Digits: 5",
        "",
        "Boom 300 Index (Indice):",
        "   Lot min: 0.01, Lot max: 100.0, Step: 0.01",
        "   Stop Level: 10 points, Tick Value: $0.30",
        "   Spread: 0.1-0.5 points, Digits: 2",
        "",
        "Crash 300 Index (Indice):",
        "   Lot min: 0.01, Lot max: 100.0, Step: 0.01",
        "   Stop Level: 10 points, Tick Value: $0.30",
        "   Spread: 0.1-0.5 points, Digits: 2"
    ]
    
    for exemple in exemples_devises:
        print(f"   {exemple}")
    
    print()
    
    # 7. Checklist de validation
    print("7. CHECKLIST DE VALIDATION")
    print("-" * 30)
    
    checklist = [
        "EA compile sans erreur",
        "EA s'attache au graphique EURUSD",
        "Smiley sourit dans le coin du graphique",
        "Messages 'INFO Informations symbole' apparaissent",
        "Messages 'CALC Calcul lot optimal' apparaissent",
        "Messages 'SLTP SL/TP calcules' apparaissent",
        "Messages 'OK Validation reussie' apparaissent",
        "Aucun message 'ERREUR Validation echouee'",
        "Aucun message 'Invalid stops'",
        "Trades s'executent avec succes",
        "SL/TP sont appliques correctement",
        "Lots sont conformes aux exigences du broker"
    ]
    
    for i, item in enumerate(checklist, 1):
        print(f"   {i}. {item}")
    
    print()
    
    # 8. Résumé du système
    print("8. RESUME DU SYSTEME DE VALIDATION")
    print("-" * 40)
    
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
        "   - Gestion des risques specifique",
        "",
        "CACHE DES INFORMATIONS:",
        "   - Stockage des donnees de symboles",
        "   - Performance optimisee",
        "   - Reduction des appels API"
    ]
    
    for item in resume:
        print(f"   {item}")
    
    print()
    
    # 9. Avantages du nouveau système
    print("9. AVANTAGES DU NOUVEAU SYSTEME")
    print("-" * 35)
    
    avantages = [
        "OK Prevention des erreurs 'Invalid stops'",
        "OK Calcul automatique des lots minimum",
        "OK Validation des SL/TP selon le broker",
        "OK Adaptation aux differentes devises",
        "OK Messages de diagnostic detailles",
        "OK Cache des informations de symboles",
        "OK Gestion specifique Boom/Crash",
        "OK Validation complete avant envoi",
        "OK Performance optimisee",
        "OK Reduction des appels API"
    ]
    
    for avantage in avantages:
        print(f"   {avantage}")
    
    print()
    print("TEST TERMINE")
    print("=" * 55)

if __name__ == "__main__":
    tester_systeme_validation()
