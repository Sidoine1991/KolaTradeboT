//+------------------------------------------------------------------+
//| Fx_robot_pred_v3.3 - Enhanced Spike Catcher (Optimized)         |
//| Optimisé pour les performances et la stabilité                  |
//| Copyright 2025, YEBADOKPO Sidoine                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YEBADOKPO Sidoine"
#property version   "3.3"
#property strict
#property description "Robot de trading optimisé pour la détection de spikes"
#property description "Version optimisée pour de meilleures performances"

//--- Paramètres d'entrée
input group "=== PARAMÈTRES GÉNÉRAUX ==="
input bool     InpEnableTrading     = true;    // Activer le trading
input int      InpMagicNumber       = 123456;  // Magic Number
input double   InpLotSize           = 0.1;     // Taille du lot
input int      InpSlippage          = 3;       // Slippage (points)
input bool     InpEnableDebugLog    = false;   // Activer les logs de débogage

//--- Paramètres de gestion du risque
input group "=== GESTION DU RISQUE ==="
input double   InpStopLoss          = 100.0;   // Stop Loss (points)
input double   InpTakeProfit        = 200.0;   // Take Profit (points)
input double   InpMaxDailyDrawdown  = 5.0;     // Drawdown quotidien max (%)
input double   InpMaxRiskPerTrade   = 2.0;     // Risque max par trade (%)

//--- Paramètres des indicateurs
input group "=== INDICATEURS ==="
input int      InpATRPeriod         = 14;      // Période ATR
input int      InpRSIPeriod         = 14;      // Période RSI
input double   InpRSIOverbought     = 70.0;    // Niveau de surachat RSI
input double   InpRSIOversold       = 30.0;    // Niveau de survente RSI

//--- Variables globales
int            g_atr_handle;                   // Handle ATR
int            g_rsi_handle;                   // Handle RSI
datetime       g_last_tick_time = 0;           // Dernier tick traité
datetime       g_last_bar_time  = 0;           // Dernière bougie traitée
double         g_last_atr       = 0.0;         // Dernière valeur ATR
double         g_last_rsi       = 50.0;        // Dernière valeur RSI

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Vérifier la connexion au terminal
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Print("ERREUR: Pas de connexion au terminal!");
      return(INIT_FAILED);
   }
   
   // Initialiser les indicateurs
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   
   if(g_atr_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE)
   {
      Print("ERREUR: Échec de l'initialisation des indicateurs!");
      return(INIT_FAILED);
   }
   
   // Afficher les paramètres
   Print("=== CONFIGURATION DU ROBOT ===");
   Print("Symbole: ", _Symbol);
   Print("Période: ", EnumToString(_Period));
   Print("Taille du lot: ", InpLotSize);
   Print("Stop Loss: ", InpStopLoss, " points");
   Print("Take Profit: ", InpTakeProfit, " points");
   
   Print("Robot initialisé avec succès!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libérer les indicateurs
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   
   Print("Robot arrêté. Raison: ", GetUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier si le trading est autorisé
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      if(InpEnableDebugLog) Print("Le trading n'est pas autorisé!");
      return;
   }
   
   // Vérifier si c'est un nouveau tick
   datetime current_time = TimeCurrent();
   if(current_time == g_last_tick_time) return;
   g_last_tick_time = current_time;
   
   try
   {
      // Vérifier si c'est une nouvelle bougie
      bool is_new_bar = IsNewBar();
      
      // Mettre à jour les indicateurs
      if(!UpdateIndicators(is_new_bar))
      {
         Print("ERREUR: Échec de la mise à jour des indicateurs!");
         return;
      }
      
      // Vérifier les signaux de trading sur nouvelle bougie
      if(is_new_bar)
      {
         CheckForTradingSignals();
      }
      
      // Gérer les positions ouvertes
      ManageOpenPositions();
   }
   catch(const string error)
   {
      Print("ERREUR dans OnTick: ", error);
   }
}

//+------------------------------------------------------------------+
//| Vérifie si une nouvelle bougie s'est formée                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(current_bar_time == 0)
   {
      Print("ERREUR: Impossible d'obtenir l'heure de la bougie actuelle!");
      return false;
   }
   
   if(current_bar_time > g_last_bar_time)
   {
      g_last_bar_time = current_bar_time;
      if(InpEnableDebugLog) Print("Nouvelle bougie à ", TimeToString(current_bar_time));
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour les indicateurs                                      |
//+------------------------------------------------------------------+
bool UpdateIndicators(bool force_update = false)
{
   static datetime last_update = 0;
   
   // Ne mettre à jour que si nécessaire (toutes les secondes ou si forcé)
   if(!force_update && (TimeCurrent() - last_update < 1))
   {
      return true;
   }
   
   last_update = TimeCurrent();
   
   // Mettre à jour l'ATR
   double atr_buffer[];
   if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_buffer) <= 0)
   {
      Print("ERREUR: Impossible de copier les données ATR!");
      return false;
   }
   g_last_atr = atr_buffer[0];
   
   // Mettre à jour le RSI
   double rsi_buffer[];
   if(CopyBuffer(g_rsi_handle, 0, 0, 1, rsi_buffer) <= 0)
   {
      Print("ERREUR: Impossible de copier les données RSI!");
      return false;
   }
   g_last_rsi = rsi_buffer[0];
   
   if(InpEnableDebugLog)
   {
      Print("Indicateurs mis à jour - ATR: ", g_last_atr, " RSI: ", g_last_rsi);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifie les signaux de trading                                  |
//+------------------------------------------------------------------+
void CheckForTradingSignals()
{
   // Vérifier si le trading est actif
   if(!InpEnableTrading) return;
   
   // Vérifier les conditions d'achat
   if(IsBuySignal())
   {
      OpenPosition(ORDER_TYPE_BUY);
   }
   // Vérifier les conditions de vente
   else if(IsSellSignal())
   {
      OpenPosition(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Vérifie les conditions d'achat                                  |
//+------------------------------------------------------------------+
bool IsBuySignal()
{
   // Exemple de condition d'achat: RSI < niveau de survente
   return (g_last_rsi < InpRSIOversold);
}

//+------------------------------------------------------------------+
//| Vérifie les conditions de vente                                 |
//+------------------------------------------------------------------+
bool IsSellSignal()
{
   // Exemple de condition de vente: RSI > niveau de surachat
   return (g_last_rsi > InpRSIOverbought);
}

//+------------------------------------------------------------------+
//| Ouvre une nouvelle position                                     |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE order_type)
{
   // Vérifier si une position est déjà ouverte
   if(PositionsTotal() > 0)
   {
      if(InpEnableDebugLog) Print("Position déjà ouverte, nouvelle position ignorée");
      return;
   }
   
   // Calculer le stop loss et le take profit
   double sl = 0.0, tp = 0.0;
   double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(InpStopLoss > 0)
   {
      sl = (order_type == ORDER_TYPE_BUY) ? 
           price - InpStopLoss * _Point : 
           price + InpStopLoss * _Point;
   }
   
   if(InpTakeProfit > 0)
   {
      tp = (order_type == ORDER_TYPE_BUY) ? 
           price + InpTakeProfit * _Point : 
           price - InpTakeProfit * _Point;
   }
   
   // Envoyer l'ordre
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   if(!trade.PositionOpen(_Symbol, order_type, InpLotSize, price, sl, tp, "Signal automatique"))
   {
      Print("ERREUR: Échec de l'ouverture de la position - ", trade.ResultRetcode(), ": ", trade.ResultRetcodeDescription());
   }
   else
   {
      Print("Position ouverte avec succès - Type: ", EnumToString(order_type), ", Prix: ", price, ", SL: ", sl, ", TP: ", tp);
   }
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes                                     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   // Vérifier si des positions sont ouvertes
   if(PositionsTotal() == 0) return;
   
   // Parcourir toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // Sélectionner la position
      if(!positionInfo.SelectByIndex(i)) continue;
      
      // Vérifier si c'est notre position
      if(positionInfo.Magic() != InpMagicNumber || positionInfo.Symbol() != _Symbol) continue;
      
      // Ici, vous pouvez ajouter la logique de gestion des positions
      // Par exemple, déplacer le stop loss, prendre des bénéfices partiels, etc.
   }
}

//+------------------------------------------------------------------+
//| Retourne la description de la raison de l'arrêt                 |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reason_code)
{
   switch(reason_code)
   {
      case REASON_ACCOUNT:    return "Compte changé";
      case REASON_CHARTCHANGE:return "Graphique changé";
      case REASON_CHARTCLOSE: return "Graphique fermé";
      case REASON_PARAMETERS: return "Paramètres modifiés";
      case REASON_RECOMPILE:  return "Recompilation";
      case REASON_REMOVE:     return "Suppression";
      case REASON_PROGRAM:    return "Arrêt du programme";
      default:                return "Autre raison";
   }
}
//+------------------------------------------------------------------+
