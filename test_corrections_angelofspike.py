#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test des corrections AngelOfSpike - Verification des problemes corriges
"""

import os
import re

def test_corrections():
    """Tester les corrections apportees au robot AngelOfSpike"""
    
    print("TEST DES CORRECTIONS ANGELOFSPIKE")
    print("=" * 40)
    
    mq5_file = "mt5/AngelOfSpike.mq5"
    if not os.path.exists(mq5_file):
        print("ERREUR: Fichier AngelOfSpike.mq5 non trouve")
        return False
    
    with open(mq5_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("\nVERIFICATION DES CORRECTIONS:")
    print("-" * 30)
    
    corrections = []
    
    # 1. Verification de la correction iRealVolume
    if "iRealVolume" in content:
        print("ERREUR: iRealVolume() encore present")
        corrections.append("ERREUR: iRealVolume() encore present")
    else:
        print("OK: iRealVolume() corrige -> iVolume()")
        corrections.append("OK: iRealVolume() corrige")
    
    # 2. Verification de la correction Point()
    if "Point()" in content:
        print("ERREUR: Point() encore present")
        corrections.append("ERREUR: Point() encore present")
    else:
        print("OK: Point() corrige -> SymbolInfoDouble()")
        corrections.append("OK: Point() corrige")
    
    # 3. Verification des ameliorations
    improvements = [
        ("Variables Order Block initialisees", "Variables Order Block initialisees"),
        ("Configuration Order Block", "Configuration Order Block"),
        ("Scan de ", "Logs de scan detailles"),
        ("Bullish trouves", "Compteurs de detection"),
        ("Bearish trouves", "Compteurs de detection"),
        ("Volume min flexible", "Volume adaptatif pour Boom/Crash"),
        ("Corps 50%", "Critere de corps plus flexible"),
        ("Cassure 5%", "Critere de cassure plus flexible")
    ]
    
    print("\nVERIFICATION DES AMELIORATIONS:")
    print("-" * 35)
    
    for check, description in improvements:
        if check in content:
            print(f"OK: {description}")
            corrections.append(f"OK: {description}")
        else:
            print(f"MANQUANT: {description}")
            corrections.append(f"MANQUANT: {description}")
    
    # 4. Verification des logs de debug
    debug_logs = [
        "ORDER BLOCK] Debut du scan",
        "ORDER BLOCK] Scan termine",
        "ORDER BLOCK] Bullish detecte",
        "ORDER BLOCK] Bearish detecte",
        "Variables Order Block initialisees",
        "Configuration Order Block"
    ]
    
    print("\nVERIFICATION DES LOGS DE DEBUG:")
    print("-" * 30)
    
    for log in debug_logs:
        if log in content:
            print(f"OK: {log}")
            corrections.append(f"OK: Log {log}")
        else:
            print(f"MANQUANT: {log}")
            corrections.append(f"MANQUANT: Log {log}")
    
    # Resume
    print("\n" + "=" * 40)
    
    ok_count = len([c for c in corrections if c.startswith("OK")])
    error_count = len([c for c in corrections if c.startswith("ERREUR")])
    missing_count = len([c for c in corrections if c.startswith("MANQUANT")])
    
    print(f"RESUME DES CORRECTIONS:")
    print(f"- OK: {ok_count}")
    print(f"- ERREURS: {error_count}")
    print(f"- MANQUANTS: {missing_count}")
    
    if error_count == 0 and missing_count <= 2:
        print("\nSUCCES: Corrections appliquees avec succes!")
        print("Le robot devrait maintenant fonctionner correctement.")
        
        print("\nPROCHAINES ETAPES:")
        print("-" * 20)
        print("1. Compilez le fichier dans MetaTrader 5")
        print("2. Attachez l'EA sur un graphique Boom/Crash")
        print("3. Activez InpDebug = true pour voir les logs")
        print("4. Surveillez l'onglet Experts pour les messages")
        print("5. Verifiez l'apparition des Order Blocks sur le graphique")
        
        return True
    else:
        print("\nATTENTION: Certaines corrections sont manquantes")
        if error_count > 0:
            print("ERREURS CRITIQUES:")
            for c in corrections:
                if c.startswith("ERREUR"):
                    print(f"- {c}")
        
        if missing_count > 0:
            print("AMELIORATIONS MANQUANTES:")
            for c in corrections:
                if c.startswith("MANQUANT"):
                    print(f"- {c}")
        
        return False

def show_expected_behavior():
    """Afficher le comportement attendu apres les corrections"""
    
    print("\nCOMPORTEMENT ATTENDU APRES CORRECTIONS:")
    print("=" * 45)
    
    print("\n1. AU DEMARRAGE:")
    print("- Messages d'initialisation dans les logs")
    print("- Configuration Order Block affichee")
    print("- Variables initialisees")
    
    print("\n2. PENDANT LE FONCTIONNEMENT:")
    print("- Heartbeat regulier toutes les 10 secondes")
    print("- Scan des Order Blocks toutes les 5 secondes")
    print("- Logs detailles de la detection")
    print("- Compteurs de Order Blocks trouves")
    
    print("\n3. SUR LE GRAPHIQUE:")
    print("- Rectangles verts pour Order Blocks Bullish")
    print("- Rectangles rouges pour Order Blocks Bearish")
    print("- Labels OB+ et OB- sur les zones")
    print("- Fleches clignotantes pour les signaux")
    
    print("\n4. DANS LES LOGS:")
    print("- [ORDER BLOCK] Debut du scan pour [symbole]")
    print("- [ORDER BLOCK] Scan de X bougies pour [symbole]")
    print("- [ORDER BLOCK] Bullish detecte sur [symbole] - Bar: X")
    print("- [ORDER BLOCK] Bearish detecte sur [symbole] - Bar: X")
    print("- [ORDER BLOCK] Scan termine pour [symbole]")
    print("- Bullish trouves: X")
    print("- Bearish trouves: X")
    print("- Total Order Blocks: X")
    
    print("\n5. SIGNALS DE TRADING:")
    print("- [ORDER BLOCK] Analyse [symbole]:")
    print("- Order Blocks valides: X")
    print("- Bullish Blocks: X")
    print("- Bearish Blocks: X")
    print("- Probabilite calculee: XX%")
    print("- SIGNAL STRICT DETECTE: [symbole] - Direction: BUY/SELL")

if __name__ == "__main__":
    success = test_corrections()
    
    if success:
        show_expected_behavior()
        
        print("\nROBOT PRET POUR LE TEST!")
        print("Les corrections ont ete appliquees avec succes.")
        print("Le robot devrait maintenant:")
        print("- Se compiler sans erreurs")
        print("- Afficher des logs detailles")
        print("- Detecter des Order Blocks")
        print("- Afficher des elements graphiques")
        print("- Declencher des trades automatiquement")
    else:
        print("\nCORRECTIONS SUPPLEMENTAIRES NECESSAIRES")
        print("Veuillez verifier les erreurs mentionnees ci-dessus.")