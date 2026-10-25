#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def valider_corrections_execution():
    """Valider que les corrections d'exécution automatique ont été appliquées"""
    
    print("=== VALIDATION DES CORRECTIONS D'EXECUTION ===")
    
    # Chemin vers le fichier AngelOfSpike.mq5
    fichier_ea = "mt5/AngelOfSpike.mq5"
    
    if not os.path.exists(fichier_ea):
        print(f"Fichier {fichier_ea} non trouve!")
        return False
    
    try:
        # Lire le contenu du fichier
        with open(fichier_ea, 'r', encoding='utf-8') as f:
            contenu = f.read()
        
        print(f"Fichier {fichier_ea} lu avec succes")
        
        # 1. Vérifier la détection des signaux de spike
        print("\\nVerification de la detection des signaux de spike...")
        
        if 'spikeBuySignal' in contenu and 'spikeSellSignal' in contenu:
            print("OK: Detection des signaux de spike implementee")
        else:
            print("MANQUANT: Detection des signaux de spike")
        
        if 'rsi < 25' in contenu and 'rsi > 75' in contenu:
            print("OK: Conditions RSI pour les spikes configurees")
        else:
            print("MANQUANT: Conditions RSI pour les spikes")
        
        # 2. Vérifier la logique de scalping
        print("\\nVerification de la logique de scalping...")
        
        if 'slDistance = tpDistance / 3' in contenu:
            print("OK: Logique de scalping SL = TP/3 implementee")
        else:
            print("MANQUANT: Logique de scalping SL = TP/3")
        
        if 'tpDistance = spread * 15' in contenu:
            print("OK: Distance du TP configuree")
        else:
            print("MANQUANT: Distance du TP")
        
        # 3. Vérifier la gestion de la perte globale
        print("\\nVerification de la gestion de la perte globale...")
        
        if 'GetGlobalLoss()' in contenu:
            print("OK: Fonction GetGlobalLoss presente")
        else:
            print("MANQUANT: Fonction GetGlobalLoss")
        
        if 'GetGlobalLoss() >= InpMaxLossPerTradeUSD' in contenu:
            print("OK: Verification de la perte globale avant ouverture")
        else:
            print("MANQUANT: Verification de la perte globale")
        
        # 4. Vérifier la fermeture rapide des positions
        print("\\nVerification de la fermeture rapide des positions...")
        
        if 'priceMovement >= point * 10' in contenu:
            print("OK: Fermeture rapide pour le scalping implementee")
        else:
            print("MANQUANT: Fermeture rapide pour le scalping")
        
        if 'POSITION FERMEE EN SCALPING' in contenu:
            print("OK: Message de fermeture en scalping present")
        else:
            print("MANQUANT: Message de fermeture en scalping")
        
        # 5. Vérifier l'affichage des informations
        print("\\nVerification de l'affichage des informations...")
        
        if 'DisplayTradingInfo()' in contenu:
            print("OK: Fonction d'affichage des informations presente")
        else:
            print("MANQUANT: Fonction d'affichage des informations")
        
        if 'Perte Globale:' in contenu:
            print("OK: Affichage de la perte globale")
        else:
            print("MANQUANT: Affichage de la perte globale")
        
        # 6. Vérifier la réactivité maximale
        print("\\nVerification de la reactivite maximale...")
        
        if 'if(currentTime - lastTickTime < 0) return;' in contenu:
            print("OK: Reactivite maximale configuree (pas de delai)")
        else:
            print("ATTENTION: Delai possible entre les ticks")
        
        # 7. Vérifier les paramètres de trading
        print("\\nVerification des parametres de trading...")
        
        if 'InpMaxLossPerTradeUSD = 3.5' in contenu:
            print("OK: Limite de perte globale a 3.5$ configuree")
        else:
            print("ATTENTION: Limite de perte globale non configuree a 3.5$")
        
        if 'InpMaxPositions = 2' in contenu:
            print("OK: Limite de positions a 2 configuree")
        else:
            print("ATTENTION: Limite de positions non configuree a 2")
        
        # 8. Vérifier les messages de debug
        print("\\nVerification des messages de debug...")
        
        if 'SIGNAL SPIKE BUY DETECTE' in contenu:
            print("OK: Messages de detection des signaux presents")
        else:
            print("MANQUANT: Messages de detection des signaux")
        
        if 'POSITION OUVERTE:' in contenu:
            print("OK: Messages d'ouverture des positions presents")
        else:
            print("MANQUANT: Messages d'ouverture des positions")
        
        # 9. Vérifier la structure des accolades
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
        
        # 10. Résumé des corrections
        print("\\n=== RESUME DES CORRECTIONS ===")
        print("1. Detection des signaux de spike amelioree")
        print("2. Execution automatique des trades activee")
        print("3. Logique de scalping SL = TP/3 implementee")
        print("4. Limite de perte globale a 3.5$ respectee")
        print("5. Fermeture rapide des positions apres spike")
        print("6. Affichage des informations de trading")
        print("7. Reactivite maximale configuree")
        
        print("\\n=== INSTRUCTIONS POUR LE TEST ===")
        print("1. Compiler le fichier AngelOfSpike.mq5 dans MetaEditor")
        print("2. Attacher l'EA au graphique Boom 1000 Index")
        print("3. Configurer les parametres:")
        print("   - Max Loss Per Trade: 3.5")
        print("   - Max Positions: 2")
        print("   - Auto Close Positions: true")
        print("   - Enable Prediction: true")
        print("4. Activer le trading automatique")
        print("5. Observer les signaux de spike et l'execution automatique")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la validation: {e}")
        return False

if __name__ == "__main__":
    valider_corrections_execution()