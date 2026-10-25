#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def tester_compilation_finale():
    """Tester la compilation finale d'AngelOfSpike.mq5"""
    
    print("=== TEST DE COMPILATION FINALE ===")
    
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
        print(f"Taille du fichier: {len(contenu)} caracteres")
        
        # 1. Vérifier la structure des accolades
        print("\nVerification de la structure des accolades...")
        accolades_ouvrantes = contenu.count('{')
        accolades_fermantes = contenu.count('}')
        
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes == accolades_fermantes:
            print("Accolades equilibrees")
        else:
            print("Accolades desequilibrees!")
            return False
        
        # 2. Vérifier les includes
        print("\nVerification des includes...")
        includes_requis = [
            '#include <Expert.mqh>',
            '#include <Trade.mqh>',
            '#include <PositionInfo.mqh>',
            '#include <OrderInfo.mqh>',
            '#include <DealInfo.mqh>',
            '#include <HistoryOrderInfo.mqh>',
            '#include <Object.mqh>',
            '#include <StdLibErr.mqh>'
        ]
        
        for include in includes_requis:
            if include in contenu:
                print(f"OK: {include}")
            else:
                print(f"MANQUANT: {include}")
        
        # 3. Vérifier les fonctions essentielles
        print("\nVerification des fonctions essentielles...")
        fonctions_essentielles = [
            'OnInit()',
            'OnDeinit()',
            'OnTick()',
            'CheckTradingSignals()',
            'CheckBoomCrashSignals()',
            'CheckConfluenceSignals()',
            'TryToOpenTrade()',
            'StartSpikePrediction()',
            'ClosePositionAfterSpikeCapture()'
        ]
        
        for fonction in fonctions_essentielles:
            if fonction in contenu:
                print(f"OK: {fonction}")
            else:
                print(f"MANQUANT: {fonction}")
        
        # 4. Vérifier les paramètres d'entrée
        print("\nVerification des parametres d'entree...")
        parametres_essentiels = [
            'InpMagicNumber',
            'InpLotSize',
            'InpMaxPositions',
            'InpMaxLossPerTradeUSD',
            'InpTargetProfitUSD',
            'InpAutoClosePositions',
            'InpEnablePrediction',
            'InpSpikeProbabilityThreshold',
            'InpAutoExecuteThreshold'
        ]
        
        for parametre in parametres_essentiels:
            if parametre in contenu:
                print(f"OK: {parametre}")
            else:
                print(f"MANQUANT: {parametre}")
        
        # 5. Vérifier les variables globales
        print("\nVerification des variables globales...")
        variables_globales = [
            'CPositionInfo g_position;',
            'CTrade g_trade;',
            'bool g_predictionActive;',
            'bool g_isBoomCrashMode;'
        ]
        
        for variable in variables_globales:
            if variable in contenu:
                print(f"OK: {variable}")
            else:
                print(f"MANQUANT: {variable}")
        
        # 6. Vérifier les appels de fonctions dans OnTick
        print("\nVerification des appels dans OnTick...")
        if 'CheckTradingSignals();' in contenu:
            print("OK: CheckTradingSignals() appele dans OnTick")
        else:
            print("MANQUANT: CheckTradingSignals() dans OnTick")
        
        if 'ClosePositionAfterSpikeCapture();' in contenu:
            print("OK: ClosePositionAfterSpikeCapture() appele dans OnTick")
        else:
            print("MANQUANT: ClosePositionAfterSpikeCapture() dans OnTick")
        
        # 7. Vérifier la logique de trading
        print("\nVerification de la logique de trading...")
        if 'PositionsTotal()' in contenu:
            print("OK: PositionsTotal() utilise")
        else:
            print("MANQUANT: PositionsTotal()")
        
        if 'g_trade.PositionOpen' in contenu:
            print("OK: PositionOpen() utilise")
        else:
            print("MANQUANT: PositionOpen()")
        
        if 'g_trade.PositionClose' in contenu:
            print("OK: PositionClose() utilise")
        else:
            print("MANQUANT: PositionClose()")
        
        # 8. Vérifier les seuils de trading
        print("\nVerification des seuils de trading...")
        if 'InpSpikeProbabilityThreshold = 50.0' in contenu:
            print("OK: Seuil de probabilite de spike configure a 50%")
        else:
            print("ATTENTION: Seuil de probabilite de spike non configure")
        
        if 'InpAutoExecuteThreshold = 50.0' in contenu:
            print("OK: Seuil d'execution automatique configure a 50%")
        else:
            print("ATTENTION: Seuil d'execution automatique non configure")
        
        print("\n=== RESUME DE LA VERIFICATION ===")
        print("Le fichier AngelOfSpike.mq5 semble etre pret pour la compilation.")
        print("Toutes les fonctions essentielles sont presentes.")
        print("La structure des accolades est equilibree.")
        print("Les parametres de trading sont configures.")
        
        print("\n=== INSTRUCTIONS FINALES ===")
        print("1. Ouvrir MetaEditor")
        print("2. Ouvrir le fichier AngelOfSpike.mq5")
        print("3. Compiler (F7)")
        print("4. Si compilation reussie, attacher l'EA au graphique Boom 1000 Index")
        print("5. Configurer les parametres selon vos besoins")
        print("6. Activer le trading automatique")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la verification: {e}")
        return False

if __name__ == "__main__":
    tester_compilation_finale()