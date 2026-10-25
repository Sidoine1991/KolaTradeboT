//+------------------------------------------------------------------+
//| Trading.mqh - Logique de trading pour Fx_robot                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

//--- Inclusions
#include "D:\\Dev\\TradBOT\\mt5\\includes\\Common.mqh"

//--- Variables globales
datetime g_lastBarTime = 0;
double g_lastVPIN = 0.0;
double g_lastOBI = 0.0;
double g_lastCVD = 0.0;
int g_drawCount = 0;

//--- Handles des indicateurs
int g_atr_handle = INVALID_HANDLE;
int g_short_atr_handle = INVALID_HANDLE;
int g_long_atr_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialise les indicateurs                                      |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   // Libérer les handles existants
   if(g_atr_handle != INVALID_HANDLE) 
      IndicatorRelease(g_atr_handle);
   if(g_short_atr_handle != INVALID_HANDLE) 
      IndicatorRelease(g_short_atr_handle);
   if(g_long_atr_handle != INVALID_HANDLE) 
      IndicatorRelease(g_long_atr_handle);
   
   // Initialiser les nouveaux indicateurs
   g_atr_handle = iATR(_Symbol, InpSpikeTimeframe, InpATR_Period);
   g_short_atr_handle = iATR(_Symbol, InpSpikeTimeframe, 14);
   g_long_atr_handle = iATR(_Symbol, InpSpikeTimeframe, 100);
   
   if(g_atr_handle == INVALID_HANDLE || 
      g_short_atr_handle == INVALID_HANDLE || 
      g_long_atr_handle == INVALID_HANDLE)
   {
      Print("Erreur: échec d'initialisation des indicateurs ATR");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifie les opportunités de trading pour un symbole donné        |
//+------------------------------------------------------------------+
void CheckTradingOpportunity(string symbol)
{
   if(!SymbolSelect(symbol, true))
   {
      Print("Symbole ", symbol, " non disponible");
      return;
   }

   // Vérifier les données historiques suffisantes
   long bars = GetBarsCount(symbol, InpSpikeTimeframe);
   if(bars < InpMinBarsRequired)
   {
      PrintFormat("%s: Données insuffisantes (%d < %d)", symbol, bars, InpMinBarsRequired);
      return;
   }

   // Calculer les indicateurs
   double atr = GetCurrentATR(g_atr_handle);
   double vpin = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe, symbol);
   double obi = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe, symbol);
   double cvd = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe, symbol);

   // Journaliser les valeurs des indicateurs
   PrintFormat("%s | VPIN=%.2f (Seuil:%.2f) | OBI=%.2f (Seuil:±%.2f) | CVD=%.2f",
               symbol, vpin, InpVPIN_Threshold, obi, InpOBI_Threshold, cvd);

   // Vérifier les conditions de trading
   int direction = 0;
   if(vpin >= InpVPIN_Threshold)
   {
      // Signal d'achat (pour les indices Crash)
      if(obi <= -InpOBI_Threshold && cvd < 0) 
      {
         direction = 1; // Achat
         Print("Signal ACHAT détecté - OBI baissier et CVD négatif");
      }
      // Signal de vente (pour les indices Boom)
      else if(obi >= InpOBI_Threshold && cvd > 0) 
      {
         direction = -1; // Vente
         Print("Signal VENTE détecté - OBI haussier et CVD positif");
      }
   }

   // Exécuter le trade si un signal valide est détecté
   if(direction != 0)
   {
      ProcessTradingSignal(symbol, direction, atr, vpin, obi, cvd);
   }
}

//+------------------------------------------------------------------+
//| Traite un signal de trading                                      |
//+------------------------------------------------------------------+
void ProcessTradingSignal(string symbol, int direction, double atr, double vpin, double obi, double cvd)
{
   // Afficher le signal détecté
   string signalType = (direction > 0) ? "ACHAT" : "VENTE";
   Print("Signal détecté pour ", symbol, ": ", signalType);
   
   // Vérifier si on peut trader
   if(!CanPlaceNewOrder(symbol))
   {
      Print("Impossible de placer un nouvel ordre pour ", symbol);
      
      // Si la file d'attente est activée, ajouter le signal en attente
      if(InpUsePendingQueue)
      {
         AddPendingSignal(symbol, direction, atr);
      }
      return;
   }
   
   // Vérifier le nombre de positions ouvertes
   int openPositions = CountOpenPositions(0, symbol);
   if(openPositions >= InpMaxOpenPositions)
   {
      Print("Nombre maximum de positions atteint (", InpMaxOpenPositions, "). Trade non exécuté.");
      
      // Si la file d'attente est activée, ajouter le signal en attente
      if(InpUsePendingQueue)
      {
         AddPendingSignal(symbol, direction, atr);
      }
      return;
   }
   
   // Vérifier et fermer les positions opposées si nécessaire
   if(CheckAndCloseOppositePosition(symbol, direction))
   {
      Print("Position opposée fermée pour ", symbol);
      Sleep(1000); // Attendre un peu après la fermeture
   }
   
   // Exécuter le trade
   Print("Tentative d'exécution du trade...");
   bool tradeResult = ExecuteTrade(symbol, direction, atr);
   
   // Afficher la flèche si activé
   if(tradeResult && InpShowVisuals) 
   {
      DrawSpikeArrow(direction);
   }
   
   // Envoyer une notification si activé
   if(tradeResult && InpNotifyOnSignal)
   {
      double currentPrice = SymbolInfoDouble(symbol, (direction > 0) ? SYMBOL_ASK : SYMBOL_BID);
      string msg = StringFormat("FX Pro: %s - %s | VPIN=%.2f | OBI=%.2f | CVD=%.2f | Prix: %s",
                              symbol,
                              signalType,
                              vpin, 
                              obi, 
                              cvd, 
                              DoubleToString(currentPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
      Print(msg);
      // SendNotification(msg); // Décommentez pour activer les notifications push
   }
}

//+------------------------------------------------------------------+
//| Ajoute un signal à la file d'attente                             |
//+------------------------------------------------------------------+
void AddPendingSignal(string symbol, int direction, double atr)
{
   if(!InpUsePendingQueue) return;
   
   // Vérifier si un signal similaire existe déjà
   for(int i = 0; i < ArraySize(g_pendingSignals); i++)
   {
      if(g_pendingSignals[i].symbol == symbol && 
         g_pendingSignals[i].direction == direction)
      {
         // Mettre à jour le signal existant
         g_pendingSignals[i].timestamp = TimeCurrent();
         
         double price = (direction > 0) ? 
                        SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(symbol, SYMBOL_BID);
                        
         if(price > 0)
         {
            g_pendingSignals[i].entry_price = price;
            
            double sl = 0, tp = 0;
            CalculateSLTP(symbol, price, direction, atr, sl, tp);
            
            g_pendingSignals[i].stop_loss = sl;
            g_pendingSignals[i].take_profit = tp;
         }
         
         Print("Signal existant mis à jour pour ", symbol);
         return;
      }
   }
   
   // Ajouter un nouveau signal
   int size = ArraySize(g_pendingSignals);
   ArrayResize(g_pendingSignals, size + 1);
   
   g_pendingSignals[size].symbol = symbol;
   g_pendingSignals[size].direction = direction;
   g_pendingSignals[size].timestamp = TimeCurrent();
   
   double price = (direction > 0) ? 
                  SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(symbol, SYMBOL_BID);
                  
   if(price > 0)
   {
      g_pendingSignals[size].entry_price = price;
      
      double sl = 0, tp = 0;
      CalculateSLTP(symbol, price, direction, atr, sl, tp);
      
      g_pendingSignals[size].stop_loss = sl;
      g_pendingSignals[size].take_profit = tp;
   }
   
   Print("Nouveau signal ajouté à la file d'attente pour ", symbol);
}

//+------------------------------------------------------------------+
//| Vérifie et traite les signaux en attente                         |
//+------------------------------------------------------------------+
void ProcessPendingSignals()
{
   if(!InpUsePendingQueue || ArraySize(g_pendingSignals) == 0) 
      return;
      
   // Vérifier les positions ouvertes
   if(CountOpenPositions(0, "") >= InpMaxOpenPositions)
      return;
   
   // Trier le tableau par timestamp (du plus ancien au plus récent)
   ArraySort(g_pendingSignals);
   
   // Traiter le signal le plus ancien
   string symbol = g_pendingSignals[0].symbol;
   int direction = g_pendingSignals[0].direction;
   
   // Vérifier si le symbole est toujours valide
   if(!SymbolSelect(symbol, true))
   {
      ArrayRemove(g_pendingSignals, 0, 1);
      ArrayResize(g_pendingSignals, ArraySize(g_pendingSignals) - 1);
      return;
   }
   
   // Vérifier si le signal est toujours valide (pas trop ancien)
   if(TimeCurrent() - g_pendingSignals[0].timestamp > 300) // 5 minutes max
   {
      Print("Signal expiré pour ", symbol);
      ArrayRemove(g_pendingSignals, 0, 1);
      ArrayResize(g_pendingSignals, ArraySize(g_pendingSignals) - 1);
      return;
   }
   
   // Vérifier et fermer les positions opposées si nécessaire
   if(CheckAndCloseOppositePosition(symbol, direction))
   {
      Print("Position opposée fermée pour ", symbol);
      Sleep(1000); // Attendre un peu après la fermeture
   }
   
   // Exécuter le trade
   double atr = GetCurrentATR(g_atr_handle);
   bool tradeResult = ExecuteTrade(symbol, direction, atr);
   
   // Si le trade a réussi, supprimer le signal de la file d'attente
   if(tradeResult)
   {
      // Afficher la flèche si activé
      if(InpShowVisuals) 
      {
         DrawSpikeArrow(direction);
      }
      
      // Supprimer le signal traité
      ArrayRemove(g_pendingSignals, 0, 1);
      ArrayResize(g_pendingSignals, ArraySize(g_pendingSignals) - 1);
   }
}

//+------------------------------------------------------------------+
//| Vérifie et ferme une position opposée si nécessaire              |
//+------------------------------------------------------------------+
bool CheckAndCloseOppositePosition(string symbol, int direction)
{
   bool positionClosed = false;
   int total = PositionsTotal();
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            long posType = PositionGetInteger(POSITION_TYPE);
            
            // Vérifier si la position est dans la direction opposée
            if((direction > 0 && posType == POSITION_TYPE_SELL) || 
               (direction < 0 && posType == POSITION_TYPE_BUY))
            {
               trade.SetExpertMagicNumber(InpMagicNumber);
               trade.PositionClose(ticket);
               positionClosed = true;
            }
         }
      }
   }
   
   return positionClosed;
}

//+------------------------------------------------------------------+
//| Exécute un ordre de trading                                      |
//+------------------------------------------------------------------+
bool ExecuteTrade(string symbol, int direction, double atr)
{
   if(!CanPlaceNewOrder(symbol)) 
      return false;

   // Obtenir le prix actuel
   double price = (direction > 0) ? 
                  SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(symbol, SYMBOL_BID);
                  
   if(price <= 0) 
   {
      Print("Erreur: Prix invalide pour ", symbol);
      return false;
   }

   // Calculer la taille de la position
   double slPoints = atr * InpATRMultiplier;
   double lotSize = CalculateLotSize(symbol, slPoints);
   
   if(lotSize <= 0)
   {
      Print("Erreur: Taille de lot invalide pour ", symbol);
      return false;
   }

   // Calculer les niveaux de stop loss et take profit
   double sl = 0, tp = 0;
   CalculateSLTP(symbol, price, direction, atr, sl, tp);
   
   // Configurer les paramètres de trading
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetMarginMode();
   trade.LogLevel(LOG_LEVEL_ALL);

   // Exécuter l'ordre
   bool result = false;
   
   if(direction > 0) // Achat
   {
      result = trade.Buy(lotSize, symbol, price, sl, tp, "Achat signal");
   }
   else // Vente
   {
      result = trade.Sell(lotSize, symbol, price, sl, tp, "Vente signal");
   }
   
   // Vérifier le résultat de l'opération
   if(!result) 
   {
      int error = GetLastError();
      string errorDesc = "";
      
      switch(error)
      {
         case 10004: errorDesc = "Requête rejetée"; break;
         case 10006: errorDesc = "Requête de trading en cours"; break;
         case 10007: errorDesc = "Opération en attente"; break;
         case 10008: errorDesc = "Requête invalide"; break;
         case 10009: errorDesc = "Ordre invalide"; break;
         case 10010: errorDesc = "Volume invalide"; break;
         case 10011: errorDesc = "Prix invalide"; break;
         case 10012: errorDesc = "Stop invalide"; break;
         case 10013: errorDesc = "Trade désactivé"; break;
         case 10014: errorDesc = "Pas assez d'argent"; break;
         case 10015: errorDesc = "Contexte occupé"; break;
         case 10016: errorDesc = "Trop de requêtes"; break;
         default: errorDesc = "Erreur inconnue";
      }
      
      Print("ERREUR d'exécution du trade ", (direction > 0 ? "ACHAT" : "VENTE"), 
            " sur ", symbol, ": ", error, " - ", errorDesc);
      
      return false;
   }
   
   // Journaliser le succès du trade
   Print("Trade exécuté avec succès: ", (direction > 0 ? "ACHAT" : "VENTE"), 
         " ", lotSize, " lots sur ", symbol, 
         " à ", DoubleToString(price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
         " SL:", (sl > 0 ? DoubleToString(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) : "Aucun"),
         " TP:", (tp > 0 ? DoubleToString(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) : "Aucun"));
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifie si un nouvel ordre peut être placé                       |
//+------------------------------------------------------------------+
bool CanPlaceNewOrder(string symbol)
{
   // Vérifier si le trading est activé dans les paramètres de l'EA
   if(!InpEnableTrading)
   {
      Print("ERREUR: Le trading est désactivé dans les paramètres de l'EA");
      return false;
   }
   
   // Vérifier les autorisations de trading du terminal
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("ERREUR: Le trading n'est pas autorisé dans le terminal");
      return false;
   }
   
   // Vérifier les autorisations MQL
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("ERREUR: Le trading n'est pas autorisé pour l'EA");
      return false;
   }
   
   // Vérifier la connexion au serveur de trading
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Print("ERREUR: Pas de connexion au serveur de trading");
      return false;
   }
   
   // Vérifier si le symbole est sélectionné et disponible pour le trading
   if(!SymbolSelect(symbol, true))
   {
      Print("ERREUR: Impossible de sélectionner le symbole ", symbol);
      return false;
   }
   
   // Vérifier si le trading est autorisé pour ce symbole
   long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == 0)
   {
      Print("ERREUR: Impossible de récupérer le mode de trading pour ", symbol);
      return false;
   }
   
   if(tradeMode != SYMBOL_TRADE_MODE_FULL)
   {
      string modeDesc = "";
      switch((int)tradeMode)
      {
         case SYMBOL_TRADE_MODE_DISABLED: modeDesc = "désactivé"; break;
         case SYMBOL_TRADE_MODE_LONGONLY: modeDesc = "uniquement les positions longues"; break;
         case SYMBOL_TRADE_MODE_SHORTONLY: modeDesc = "uniquement les positions courtes"; break;
         case SYMBOL_TRADE_MODE_CLOSEONLY: modeDesc = "fermeture uniquement"; break;
         default: modeDesc = "mode inconnu (" + (string)tradeMode + ")";
      }
      
      PrintFormat("ERREUR: Le trading pour %s est limité: %s", symbol, modeDesc);
      return false;
   }
   
   // Vérifier si le symbole est visible dans le Market Watch
   long is_visible = SymbolInfoInteger(symbol, SYMBOL_VISIBLE);
   if(is_visible == 0)
   {
      Print("ERREUR: Le symbole ", symbol, " n'est pas visible dans le Market Watch");
      return false;
   }
   
   // Vérifier si le symbole est synchronisé
   long is_synchronized = SymbolInfoInteger(symbol, SYMBOL_SYNCHRONIZED);
   if(is_synchronized == 0)
   {
      Print("ERREUR: Le symbole ", symbol, " n'est pas synchronisé");
      return false;
   }
   
   // Vérifier si le marché est ouvert pour ce symbole
   long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(tradeMode != SYMBOL_TRADE_MODE_FULL)
   {
      Print("ERREUR: Le marché n'est pas ouvert pour le symbole ", symbol);
      return false;
   }
   
   // Vérifier la limite de perte quotidienne
   if(IsDailyLossLimitReached())
   {
      Print("ERREUR: Limite de perte quotidienne atteinte");
      return false;
   }
   
   // Toutes les vérifications sont passées avec succès
   return true;
}

//+------------------------------------------------------------------+
//| Compte le nombre de positions ouvertes selon la direction        |
//+------------------------------------------------------------------+
int CountOpenPositions(int direction = 0, string symbol = "")
{
   if(symbol == "") 
      symbol = _Symbol; // Utiliser le symbole courant si non spécifié
   
   int count = 0;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) 
         continue;
      
      if(!PositionSelectByTicket(ticket)) 
         continue;
      
      // Vérifier le symbole et le magic number
      if(PositionGetString(POSITION_SYMBOL) != symbol || 
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      {
         continue;
      }
      
      // Vérifier la direction si spécifiée
      if(direction == 0) // Toutes les positions
      {
         count++;
      }
      else if(direction > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) // Achat
      {
         count++;
      }
      else if(direction < 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) // Vente
      {
         count++;
      }
   }
   
   return count;
}
