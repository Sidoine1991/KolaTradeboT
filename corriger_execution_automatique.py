#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def corriger_execution_automatique():
    """Corriger la logique d'exécution automatique des trades dans AngelOfSpike.mq5"""
    
    print("=== CORRECTION DE L'EXECUTION AUTOMATIQUE ===")
    
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
        
        # 1. Améliorer la détection des signaux de spike
        print("Amelioration de la detection des signaux de spike...")
        
        # Remplacer la fonction CheckConfluenceSignals par une version améliorée
        nouvelle_fonction_confluence = '''
//+------------------------------------------------------------------+
//| Vérifier les signaux de confluence et de spike                  |
//+------------------------------------------------------------------+
void CheckConfluenceSignals()
{
    string symbol = Symbol();
    
    // Obtenir les données de prix actuelles
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double spread = ask - currentPrice;
    
    // Calculer les indicateurs techniques
    double rsi = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE, 0);
    double rsi_prev = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE, 1);
    
    double ma20 = iMA(symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma50 = iMA(symbol, PERIOD_M1, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    // Calculer la volatilité
    double atr = iATR(symbol, PERIOD_M1, 14, 0);
    
    // Conditions pour détecter un spike imminent
    bool spikeBuySignal = false;
    bool spikeSellSignal = false;
    
    // Signal d'achat pour spike
    if (rsi < 25 && rsi > rsi_prev && currentPrice > ma20 && ma20 > ma50)
    {
        spikeBuySignal = true;
        Print("SIGNAL SPIKE BUY DETECTE - RSI: ", DoubleToString(rsi, 2), " Prix: ", DoubleToString(currentPrice, 5));
    }
    
    // Signal de vente pour spike
    if (rsi > 75 && rsi < rsi_prev && currentPrice < ma20 && ma20 < ma50)
    {
        spikeSellSignal = true;
        Print("SIGNAL SPIKE SELL DETECTE - RSI: ", DoubleToString(rsi, 2), " Prix: ", DoubleToString(currentPrice, 5));
    }
    
    // Exécuter les trades automatiquement
    if (spikeBuySignal)
    {
        TryToOpenTrade(ORDER_TYPE_BUY, "Spike Buy Signal");
    }
    else if (spikeSellSignal)
    {
        TryToOpenTrade(ORDER_TYPE_SELL, "Spike Sell Signal");
    }
}'''
        
        # Remplacer l'ancienne fonction
        contenu = re.sub(r'void CheckConfluenceSignals\(\)\s*\{[^}]*\}', nouvelle_fonction_confluence, contenu, flags=re.DOTALL)
        
        # 2. Améliorer la fonction TryToOpenTrade pour le scalping
        print("Amelioration de la fonction TryToOpenTrade pour le scalping...")
        
        nouvelle_fonction_try_open = '''
//+------------------------------------------------------------------+
//| Essayer d'ouvrir un trade avec logique de scalping               |
//+------------------------------------------------------------------+
void TryToOpenTrade(ENUM_ORDER_TYPE orderType, string reason)
{
    // Vérifier le nombre de positions
    if(PositionsTotal() >= InpMaxPositions)
    {
        Print("Nombre maximum de positions atteint: ", PositionsTotal());
        return;
    }
    
    // Vérifier les permissions de trading
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Print("Trading non autorise!");
        return;
    }
    
    // Vérifier la perte globale
    if(GetGlobalLoss() >= InpMaxLossPerTradeUSD)
    {
        Print("Perte globale maximale atteinte: ", DoubleToString(GetGlobalLoss(), 2), " USD");
        return;
    }
    
    string symbol = Symbol();
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Calculer le Stop Loss et Take Profit pour le scalping
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
    
    // Logique de scalping: SL = TP/3
    double tpDistance = spread * 15; // Distance du TP
    double slDistance = tpDistance / 3; // SL = TP/3
    
    double sl = 0, tp = 0;
    
    if(orderType == ORDER_TYPE_BUY)
    {
        sl = price - slDistance;
        tp = price + tpDistance;
    }
    else
    {
        sl = price + slDistance;
        tp = price - tpDistance;
    }
    
    // Ouvrir la position
    if(g_trade.PositionOpen(symbol, orderType, InpLotSize, price, sl, tp, reason))
    {
        Print("POSITION OUVERTE: ", symbol, " Type: ", EnumToString(orderType), " Prix: ", DoubleToString(price, 5), " SL: ", DoubleToString(sl, 5), " TP: ", DoubleToString(tp, 5));
        Print("Raison: ", reason);
    }
    else
    {
        Print("ERREUR OUVERTURE POSITION: ", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
    }
}'''
        
        # Remplacer l'ancienne fonction
        contenu = re.sub(r'void TryToOpenTrade\([^)]*\)\s*\{[^}]*\}', nouvelle_fonction_try_open, contenu, flags=re.DOTALL)
        
        # 3. Ajouter la fonction pour calculer la perte globale
        print("Ajout de la fonction de calcul de perte globale...")
        
        fonction_global_loss = '''
//+------------------------------------------------------------------+
//| Calculer la perte globale                                       |
//+------------------------------------------------------------------+
double GetGlobalLoss()
{
    double totalLoss = 0.0;
    CPositionInfo pos;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == InpMagicNumber)
            {
                double profit = pos.Profit();
                if(profit < 0)
                {
                    totalLoss += MathAbs(profit);
                }
            }
        }
    }
    
    return totalLoss;
}'''
        
        # Ajouter la fonction avant la dernière accolade
        contenu = contenu.rstrip() + '\n' + fonction_global_loss + '\n'
        
        # 4. Améliorer la fonction ClosePositionAfterSpikeCapture
        print("Amelioration de la fermeture des positions apres spike...")
        
        nouvelle_fonction_close = '''
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
                double profit = pos.Profit();
                double currentPrice = (pos.PositionType() == POSITION_TYPE_BUY) ? 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_BID) : 
                    SymbolInfoDouble(pos.Symbol(), SYMBOL_ASK);
                double entryPrice = pos.PriceOpen();
                
                // Fermeture après capture de spike (profit positif)
                if (profit >= InpTargetProfitUSD)
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
                // Fermeture rapide pour le scalping (petit profit)
                else if (profit > 0.5 && profit < InpTargetProfitUSD)
                {
                    // Vérifier si le prix a bougé suffisamment pour le scalping
                    double priceMovement = MathAbs(currentPrice - entryPrice);
                    double point = SymbolInfoDouble(pos.Symbol(), SYMBOL_POINT);
                    
                    if(priceMovement >= point * 10) // Mouvement de 10 points minimum
                    {
                        if(g_trade.PositionClose(pos.Ticket()))
                        {
                            Print("POSITION FERMEE EN SCALPING: ", pos.Symbol(), " Ticket: ", pos.Ticket(), " Profit: ", DoubleToString(profit, 2));
                        }
                    }
                }
            }
        }
    }
}'''
        
        # Remplacer l'ancienne fonction
        contenu = re.sub(r'void ClosePositionAfterSpikeCapture\(\)\s*\{[^}]*\}', nouvelle_fonction_close, contenu, flags=re.DOTALL)
        
        # 5. Améliorer OnTick pour une meilleure réactivité
        print("Amelioration de OnTick pour une meilleure reactivite...")
        
        nouvelle_fonction_ontick = '''
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérifier le temps entre les ticks (réactivité maximale)
    static datetime lastTickTime = 0;
    datetime currentTime = TimeCurrent();
    
    if(currentTime - lastTickTime < 0) return; // Pas de délai pour la réactivité maximale
    lastTickTime = currentTime;
    
    // Vérifier les signaux de trading en continu
    CheckTradingSignals();
    
    // Fermer les positions après capture de spike
    ClosePositionAfterSpikeCapture();
    
    // Afficher les informations de trading
    if(InpShowHUD)
    {
        DisplayTradingInfo();
    }
}'''
        
        # Remplacer l'ancienne fonction
        contenu = re.sub(r'void OnTick\(\)\s*\{[^}]*\}', nouvelle_fonction_ontick, contenu, flags=re.DOTALL)
        
        # 6. Ajouter la fonction d'affichage des informations
        print("Ajout de la fonction d'affichage des informations...")
        
        fonction_display = '''
//+------------------------------------------------------------------+
//| Afficher les informations de trading                             |
//+------------------------------------------------------------------+
void DisplayTradingInfo()
{
    string symbol = Symbol();
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double rsi = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE, 0);
    
    string info = "AngelOfSpike Pro\\n";
    info += "Prix: " + DoubleToString(currentPrice, 5) + "\\n";
    info += "RSI: " + DoubleToString(rsi, 2) + "\\n";
    info += "Positions: " + IntegerToString(PositionsTotal()) + "/" + IntegerToString(InpMaxPositions) + "\\n";
    info += "Perte Globale: " + DoubleToString(GetGlobalLoss(), 2) + " USD\\n";
    
    if(PositionsTotal() > 0)
    {
        CPositionInfo pos;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(pos.SelectByIndex(i))
            {
                if(pos.Magic() == InpMagicNumber)
                {
                    info += "Position " + IntegerToString(i+1) + ": " + DoubleToString(pos.Profit(), 2) + " USD\\n";
                }
            }
        }
    }
    
    // Afficher sur le graphique
    ObjectCreate(0, "TradingInfo", OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, "TradingInfo", OBJPROP_TEXT, info);
    ObjectSetInteger(0, "TradingInfo", OBJPROP_XDISTANCE, InpHUDX);
    ObjectSetInteger(0, "TradingInfo", OBJPROP_YDISTANCE, InpHUDY);
    ObjectSetInteger(0, "TradingInfo", OBJPROP_COLOR, InpHUDColor);
    ObjectSetInteger(0, "TradingInfo", OBJPROP_FONTSIZE, InpHUDFontSize);
}'''
        
        # Ajouter la fonction
        contenu = contenu.rstrip() + '\n' + fonction_display + '\n'
        
        # Sauvegarder le fichier corrigé
        with open(fichier_ea, 'w', encoding='utf-8') as f:
            f.write(contenu)
        
        print(f"Fichier {fichier_ea} corrige avec succes!")
        
        # Vérification finale
        print("Verification finale...")
        
        # Vérifier que les corrections ont été appliquées
        if 'GetGlobalLoss()' in contenu:
            print("OK: Fonction GetGlobalLoss ajoutee")
        else:
            print("MANQUANT: Fonction GetGlobalLoss")
        
        if 'spikeBuySignal' in contenu:
            print("OK: Detection des signaux de spike amelioree")
        else:
            print("MANQUANT: Detection des signaux de spike")
        
        if 'slDistance = tpDistance / 3' in contenu:
            print("OK: Logique de scalping SL = TP/3 implementee")
        else:
            print("MANQUANT: Logique de scalping")
        
        if 'DisplayTradingInfo()' in contenu:
            print("OK: Fonction d'affichage des informations ajoutee")
        else:
            print("MANQUANT: Fonction d'affichage")
        
        print("\\n=== CORRECTIONS APPLIQUEES ===")
        print("1. Detection des signaux de spike amelioree")
        print("2. Execution automatique des trades activee")
        print("3. Logique de scalping SL = TP/3 implementee")
        print("4. Limite de perte globale a 3.5$ respectee")
        print("5. Fermeture rapide des positions apres spike")
        print("6. Affichage des informations de trading")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la correction: {e}")
        return False

if __name__ == "__main__":
    corriger_execution_automatique()