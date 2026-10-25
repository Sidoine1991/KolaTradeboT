#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def corriger_erreurs_compilation():
    """Corriger les erreurs de compilation dans AngelOfSpike.mq5"""
    
    print("=== CORRECTION DES ERREURS DE COMPILATION ===")
    
    # Chemin vers le fichier AngelOfSpike.mq5
    fichier_ea = "mt5/AngelOfSpike.mq5"
    
    if not os.path.exists(fichier_ea):
        print(f"❌ Fichier {fichier_ea} non trouvé!")
        return False
    
    try:
        # Lire le contenu du fichier
        with open(fichier_ea, 'r', encoding='utf-8') as f:
            contenu = f.read()
        
        print(f"Fichier {fichier_ea} lu avec succes")
        print(f"Taille du fichier: {len(contenu)} caracteres")
        
        # 1. Corriger les déclarations de fonctions mal placées
        print("\nCorrection des declarations de fonctions...")
        
        # Supprimer les déclarations de fonctions mal placées
        contenu = re.sub(r'void\s+ClosePositionAfterSpikeCapture\(\)\s*\{[^}]*\}', '', contenu, flags=re.DOTALL)
        
        # 2. Corriger les identifiants non déclarés
        print("Correction des identifiants non declares...")
        
        # Ajouter les déclarations manquantes
        if 'int i;' not in contenu:
            contenu = contenu.replace('for(int i = 0; i < PositionsTotal(); i++)', 'int i;\n    for(i = 0; i < PositionsTotal(); i++)')
        
        # 3. Corriger les problèmes de portée des variables
        print("Correction des problemes de portee...")
        
        # Déplacer les déclarations de variables au bon endroit
        contenu = re.sub(r'for\(int i = 0; i < PositionsTotal\(\); i\+\+\)', 'for(i = 0; i < PositionsTotal(); i++)', contenu)
        
        # 4. Corriger les problèmes de cast
        print("Correction des problemes de cast...")
        
        # Corriger les casts invalides
        contenu = re.sub(r'\(ENUM_TRADE_REQUEST_ACTIONS\)', '', contenu)
        
        # 5. Ajouter les includes manquants
        print("Ajout des includes manquants...")
        
        includes_manquants = [
            '#include <Trade.mqh>',
            '#include <PositionInfo.mqh>',
            '#include <OrderInfo.mqh>',
            '#include <DealInfo.mqh>',
            '#include <HistoryOrderInfo.mqh>',
            '#include <Object.mqh>',
            '#include <StdLibErr.mqh>'
        ]
        
        for include in includes_manquants:
            if include not in contenu:
                contenu = contenu.replace('#include <Expert.mqh>', f'#include <Expert.mqh>\n{include}')
        
        # 6. Corriger la structure des accolades
        print("Correction de la structure des accolades...")
        
        # Compter les accolades
        accolades_ouvrantes = contenu.count('{')
        accolades_fermantes = contenu.count('}')
        
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes != accolades_fermantes:
            print("Accolades desequilibrees!")
            # Ajouter les accolades manquantes
            if accolades_ouvrantes > accolades_fermantes:
                contenu += '\n}' * (accolades_ouvrantes - accolades_fermantes)
                print(f"Ajout de {accolades_ouvrantes - accolades_fermantes} accolades fermantes")
        
        # 7. Ajouter la fonction ClosePositionAfterSpikeCapture à la fin
        print("Ajout de la fonction ClosePositionAfterSpikeCapture...")
        
        fonction_fermeture = '''
//+------------------------------------------------------------------+
//| Fermer les positions après capture de spike                      |
//+------------------------------------------------------------------+
void ClosePositionAfterSpikeCapture()
{
    if(!InpAutoClosePositions) return;
    
    CPositionInfo pos;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == InpMagicNumber)
            {
                double currentPrice = (pos.PositionType() == POSITION_TYPE_BUY) ? 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_BID) : 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_ASK);
                double entryPrice = pos.PriceOpen();
                double profit = pos.Profit();
                
                // Vérifier si le spike a été capturé
                if (profit >= InpTargetProfitUSD || 
                    (pos.PositionType() == POSITION_TYPE_BUY && currentPrice > entryPrice + (SymbolInfoDouble(pos.Symbol(), SYMBOL_POINT) * 100)) || 
                    (pos.PositionType() == POSITION_TYPE_SELL && currentPrice < entryPrice - (SymbolInfoDouble(pos.Symbol(), SYMBOL_POINT) * 100)))
                {
                    if(g_trade.PositionClose(pos.Ticket()))
                    {
                        Print("POSITION FERMEE APRES SPIKE: ", pos.Symbol(), " Ticket: ", pos.Ticket(), " Profit: ", DoubleToString(profit, 2));
                    }
                    else
                    {
                        Print("ECHEC FERMETURE POSITION APRES SPIKE: ", pos.Symbol(), " Erreur: ", g_trade.ResultRetcode());
                    }
                }
                // Fermeture en cas de perte maximale
                else if (profit <= -InpMaxLossPerTradeUSD)
                {
                    if(g_trade.PositionClose(pos.Ticket()))
                    {
                        Print("POSITION FERMEE EN PERTE MAX: ", pos.Symbol(), " Ticket: ", pos.Ticket(), " Perte: ", DoubleToString(profit, 2));
                    }
                    else
                    {
                        Print("ECHEC FERMETURE POSITION EN PERTE MAX: ", pos.Symbol(), " Erreur: ", g_trade.ResultRetcode());
                    }
                }
            }
        }
    }
}
'''
        
        # Ajouter la fonction à la fin du fichier
        contenu += fonction_fermeture
        
        # 8. S'assurer que la fonction est appelée dans OnTick
        print("Verification de l'appel de ClosePositionAfterSpikeCapture dans OnTick...")
        
        if 'ClosePositionAfterSpikeCapture();' not in contenu:
            # Trouver la fin de OnTick et ajouter l'appel
            onTick_end = contenu.find('void OnTick()')
            if onTick_end != -1:
                # Trouver la fin de la fonction OnTick
                start = contenu.find('{', onTick_end)
                if start != -1:
                    # Compter les accolades pour trouver la fin
                    count = 1
                    i = start + 1
                    while i < len(contenu) and count > 0:
                        if contenu[i] == '{':
                            count += 1
                        elif contenu[i] == '}':
                            count -= 1
                        i += 1
                    
                    if count == 0:
                        # Insérer l'appel avant la dernière accolade
                        contenu = contenu[:i-1] + '\n    ClosePositionAfterSpikeCapture();\n' + contenu[i-1:]
                        print("Appel de ClosePositionAfterSpikeCapture ajoute dans OnTick")
        
        # Sauvegarder le fichier corrigé
        with open(fichier_ea, 'w', encoding='utf-8') as f:
            f.write(contenu)
        
        print(f"\nFichier {fichier_ea} corrige avec succes!")
        
        # Vérification finale
        print("\nVerification finale...")
        
        # Vérifier que les corrections ont été appliquées
        if 'ClosePositionAfterSpikeCapture();' in contenu:
            print("Fonction ClosePositionAfterSpikeCapture correctement ajoutee")
        else:
            print("Fonction ClosePositionAfterSpikeCapture manquante")
        
        if 'ClosePositionAfterSpikeCapture()' in contenu:
            print("Declaration de ClosePositionAfterSpikeCapture trouvee")
        else:
            print("Declaration de ClosePositionAfterSpikeCapture manquante")
        
        # Vérifier les accolades
        accolades_ouvrantes = contenu.count('{')
        accolades_fermantes = contenu.count('}')
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes == accolades_fermantes:
            print("Accolades equilibrees")
        else:
            print("Accolades desequilibrees")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la correction: {e}")
        return False

if __name__ == "__main__":
    corriger_erreurs_compilation()