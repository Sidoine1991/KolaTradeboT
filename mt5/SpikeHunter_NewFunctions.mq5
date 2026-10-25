//+------------------------------------------------------------------+
//| NOUVELLES FONCTIONS À AJOUTER À LA FIN DE SpikeHunter_EA.mq5   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Programmer un trade automatique                                   |
//+------------------------------------------------------------------+
void ScheduleAutoTrade(int direction, int delay_seconds)
{
    //--- Créer un timer pour l'ouverture automatique
    datetime trade_time = TimeCurrent() + delay_seconds;
    
    //--- Stocker les informations du trade programmé
    static datetime scheduled_trade_time = 0;
    static int scheduled_direction = 0;
    
    scheduled_trade_time = trade_time;
    scheduled_direction = direction;
    
    Print("📅 TRADE PROGRAMMÉ: ", (direction > 0) ? "BUY" : "SELL", " dans ", delay_seconds, " secondes");
}

//+------------------------------------------------------------------+
//| Vérifier et exécuter les trades programmés                       |
//+------------------------------------------------------------------+
void CheckScheduledTrades()
{
    static datetime scheduled_trade_time = 0;
    static int scheduled_direction = 0;
    
    if(scheduled_trade_time > 0 && TimeCurrent() >= scheduled_trade_time) {
        //--- Vérifier si on peut ouvrir un trade
        if(IsTradeViable()) {
            Print("🤖 EXÉCUTION TRADE AUTOMATIQUE: ", (scheduled_direction > 0) ? "BUY" : "SELL");
            OpenTrade(scheduled_direction);
        } else {
            Print("❌ TRADE AUTOMATIQUE ANNULÉ - Conditions non remplies");
        }
        
        //--- Réinitialiser
        scheduled_trade_time = 0;
        scheduled_direction = 0;
    }
}

//+------------------------------------------------------------------+
//| Supprimer la flèche de prédiction                                |
//+------------------------------------------------------------------+
void RemovePredictionArrow()
{
    //--- Supprimer toutes les flèches de prédiction
    ObjectsDeleteAll(0, "SpikePrediction_");
    ObjectsDeleteAll(0, "SpikeText_");
    
    Print("🗑️ FLÈCHE DE PRÉDICTION SUPPRIMÉE");
}

//+------------------------------------------------------------------+
//| Vérification des trades avec limite de perte                     |
//+------------------------------------------------------------------+
void CheckTradeLossLimits()
{
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;
        
        if(PositionSelectByTicket(active_trades[i].ticket)) {
            double current_profit = PositionGetDouble(POSITION_PROFIT);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = (active_trades[i].direction > 0) ? 
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            //--- Calculer la perte en pips
            double loss_pips = 0;
            if(active_trades[i].direction > 0) {
                loss_pips = (open_price - current_price) / _Point;
            } else {
                loss_pips = (current_price - open_price) / _Point;
            }
            
            //--- Si la perte dépasse la limite, fermer le trade
            if(loss_pips >= InpMaxLossPips) {
                Print("⚠️ LIMITE DE PERTE ATTEINTE: ", DoubleToString(loss_pips, 0), " pips - Fermeture automatique");
                CloseTrade(active_trades[i].ticket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fermer un trade                                                  |
//+------------------------------------------------------------------+
void CloseTrade(ulong ticket)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.deviation = 10;
    request.magic = InpMagicNumber;
    request.comment = "AutoClose_LossLimit";
    
    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            Print("✅ TRADE FERMÉ AUTOMATIQUEMENT: ", ticket);
        } else {
            Print("❌ ERREUR FERMETURE TRADE: ", result.retcode, " - ", result.comment);
        }
    }
}
