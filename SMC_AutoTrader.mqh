//+------------------------------------------------------------------+
//| SMC_AutoTrader.mqh                                                |
//| Module de trading automatique pour le scanner                     |
//| Place des ordres automatiques sur les opportunités détectées      |
//+------------------------------------------------------------------+

#ifndef SMC_AUTO_TRADER_MQH
#define SMC_AUTO_TRADER_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

// Structure pour les statistiques de trading
struct TradingStats
{
    int totalTrades;        // Nombre total de trades
    int winningTrades;      // Trades gagnants
    int losingTrades;       // Trades perdants
    double totalProfit;     // Profit total ($)
    double totalLoss;       // Perte totale ($)
    double netProfit;       // Profit net ($)
    double winRate;         // Taux de réussite (%)
    datetime lastNotifyTime; // Dernière notification
};

// Classe de trading automatique
class CAutoTrader
{
private:
    CTrade m_trade;
    CPositionInfo m_position;

    // Paramètres de trading
    double m_maxRiskDollars;        // Risque max par trade ($)
    double m_minLotSize;            // Lot minimum
    double m_maxLotSize;            // Lot maximum
    long m_magicNumber;             // Magic number
    string m_tradeComment;          // Commentaire des ordres

    // Paramètres de scalping
    double m_scalpTpPoints;         // Take profit scalping (points)
    double m_scalpSlPoints;         // Stop loss scalping (points)
    bool m_enableTrailingStop;      // Activer trailing stop
    double m_trailingStopPoints;    // Distance trailing stop (points)
    double m_trailingStepPoints;    // Pas de déplacement (points)

    // Notifications
    int m_notifyIntervalMinutes;    // Intervalle notifications (minutes)
    bool m_enablePushNotifications; // Activer notifications push

    // Statistiques
    TradingStats m_stats;

    // Throttle trading
    datetime m_lastTradeTime[];     // Dernier trade par symbole
    int m_minSecondsBetweenTrades;  // Temps minimum entre trades

    // Gestion des positions
    int m_maxPositionsPerSymbol;    // Max positions par symbole
    int m_maxTotalPositions;        // Max positions totales

public:
    // Constructeur
    CAutoTrader()
    {
        m_maxRiskDollars = 0.50;        // 50 cents par trade (pour capital 10$)
        m_minLotSize = 0.01;
        m_maxLotSize = 0.10;
        m_magicNumber = 91305800;       // Magic number unique
        m_tradeComment = "Scanner_Auto";

        // Scalping
        m_scalpTpPoints = 50;           // 50 points TP
        m_scalpSlPoints = 30;           // 30 points SL
        m_enableTrailingStop = true;
        m_trailingStopPoints = 20;      // 20 points trailing
        m_trailingStepPoints = 5;       // 5 points step

        // Notifications
        m_notifyIntervalMinutes = 10;
        m_enablePushNotifications = true;

        // Limites
        m_minSecondsBetweenTrades = 120; // 2 minutes entre trades
        m_maxPositionsPerSymbol = 1;
        m_maxTotalPositions = 2;         // LIMITE STRICTE: 2 positions maximum (reste annulé)

        // Init stats
        ResetStats();

        // Configuration du trade
        m_trade.SetExpertMagicNumber(m_magicNumber);
        m_trade.SetDeviationInPoints(50);
        m_trade.SetTypeFilling(ORDER_FILLING_IOC);
    }

    // Configuration
    void SetMaxRiskDollars(double risk) { m_maxRiskDollars = MathMax(0.10, risk); }
    void SetScalpingParams(double tpPoints, double slPoints)
    {
        m_scalpTpPoints = tpPoints;
        m_scalpSlPoints = slPoints;
    }
    void SetTrailingStop(bool enable, double points, double step)
    {
        m_enableTrailingStop = enable;
        m_trailingStopPoints = points;
        m_trailingStepPoints = step;
    }
    void SetNotifications(bool enable, int intervalMinutes)
    {
        m_enablePushNotifications = enable;
        m_notifyIntervalMinutes = intervalMinutes;
    }
    void SetMaxPositions(int perSymbol, int total)
    {
        m_maxPositionsPerSymbol = perSymbol;
        m_maxTotalPositions = total;
    }

    // Trading automatique sur une opportunité - UTILISE LES NIVEAUX DU SCANNER
    bool TradeOpportunity(const string symbol, const string direction, const string quality,
                         const double entry, const double sl, const double tp1,
                         const double spikeProb)
    {
        // Vérifications de sécurité
        if(!IsGoodOpportunity(quality, spikeProb))
            return false;

        // VÉRIFIER LIMITE STRICTE: 2 POSITIONS MAXIMUM
        int currentPositions = CountOpenPositions();
        if(currentPositions >= m_maxTotalPositions)
        {
            // TERMINAL OCCUPÉ - ANNULER cette opportunité
            static datetime lastRejectLog = 0;
            static int rejectedCount = 0;

            rejectedCount++;

            // Log groupé toutes les 60 secondes
            if(TimeCurrent() - lastRejectLog > 60)
            {
                Print("🚫 TERMINAL OCCUPÉ (", currentPositions, "/", m_maxTotalPositions,
                      ") - ", rejectedCount, " opportunité(s) annulée(s) dans la dernière minute");
                lastRejectLog = TimeCurrent();
                rejectedCount = 0;
            }
            return false;
        }

        if(!CanTrade(symbol))
            return false;

        // PRIORITÉ ABSOLUE: Utiliser les niveaux calculés par le scanner
        double finalEntry = entry;
        double finalSl = sl;
        double finalTp = tp1; // Utiliser TP1 du scanner

        // Validation des niveaux du scanner (pas de log, silencieux)
        if(finalEntry <= 0 || finalSl <= 0 || finalTp <= 0)
            return false;

        // Vérifier cohérence des niveaux (pas de log, silencieux)
        if(direction == "BUY")
        {
            if(finalSl >= finalEntry || finalTp <= finalEntry)
                return false;
        }
        else if(direction == "SELL")
        {
            if(finalSl <= finalEntry || finalTp >= finalEntry)
                return false;
        }

        // Calculer le lot size basé sur le risque et le SL du scanner
        double lotSize = CalculateLotSize(symbol, finalEntry, finalSl);
        if(lotSize < m_minLotSize)
            return false;

        // Placer l'ordre AVEC LES NIVEAUX EXACTS DU SCANNER
        bool success = false;
        if(direction == "BUY")
            success = OpenBuyPosition(symbol, lotSize, finalEntry, finalSl, finalTp);
        else if(direction == "SELL")
            success = OpenSellPosition(symbol, lotSize, finalEntry, finalSl, finalTp);

        // Mise à jour stats
        if(success)
        {
            m_stats.totalTrades++;
            UpdateLastTradeTime(symbol);

            string msg = StringFormat("✅ TRADE OUVERT: %s %s %.2f lots @ %.5f\n(SL:%.5f TP:%.5f) Quality:%s",
                                     symbol, direction, lotSize, finalEntry, finalSl, finalTp, quality);
            Print(msg);

            if(m_enablePushNotifications)
                SendNotification(msg);
        }

        return success;
    }

    // Gérer les positions ouvertes (trailing stop)
    void ManageOpenPositions()
    {
        if(!m_enableTrailingStop)
            return;

        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(!m_position.SelectByIndex(i))
                continue;

            if(m_position.Magic() != m_magicNumber)
                continue;

            string symbol = m_position.Symbol();
            double currentSl = m_position.StopLoss();
            double currentTp = m_position.TakeProfit();

            // Calculer nouveau SL avec trailing
            double newSl = 0;
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)m_position.Type();
            if(CalculateTrailingStop(symbol, posType, m_position.PriceOpen(),
                                    currentSl, newSl))
            {
                if(MathAbs(newSl - currentSl) > m_trailingStepPoints * SymbolInfoDouble(symbol, SYMBOL_POINT))
                {
                    m_trade.PositionModify(m_position.Ticket(), newSl, currentTp);
                    Print("📊 Trailing Stop: ", symbol, " nouveau SL: ", newSl);
                }
            }
        }
    }

    // Envoyer notification périodique
    void SendPeriodicNotification()
    {
        if(!m_enablePushNotifications)
            return;

        datetime now = TimeCurrent();
        if(now - m_stats.lastNotifyTime < m_notifyIntervalMinutes * 60)
            return;

        m_stats.lastNotifyTime = now;

        // Mettre à jour les statistiques
        UpdateStats();

        // Construire le message
        string msg = "📊 SCANNER AUTO-TRADING\n";
        msg += "━━━━━━━━━━━━━━━━━━━━\n";
        msg += StringFormat("⏰ %s\n\n", TimeToString(now, TIME_DATE|TIME_MINUTES));

        // Stats globales
        msg += StringFormat("📈 Trades: %d (W:%d L:%d)\n",
                           m_stats.totalTrades,
                           m_stats.winningTrades,
                           m_stats.losingTrades);

        if(m_stats.totalTrades > 0)
            msg += StringFormat("✅ Win Rate: %.1f%%\n", m_stats.winRate);

        msg += StringFormat("💰 Profit Net: $%.2f\n", m_stats.netProfit);

        // Positions ouvertes
        int openPos = CountOpenPositions();
        msg += StringFormat("\n📊 Positions Ouvertes: %d\n", openPos);

        if(openPos > 0)
        {
            double totalPL = 0;
            for(int i = 0; i < PositionsTotal(); i++)
            {
                if(!m_position.SelectByIndex(i))
                    continue;

                if(m_position.Magic() != m_magicNumber)
                    continue;

                double pl = m_position.Profit() + m_position.Swap() + m_position.Commission();
                totalPL += pl;

                string dir = (m_position.Type() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
                msg += StringFormat("  %s %s: $%.2f\n",
                                   m_position.Symbol(),
                                   dir,
                                   pl);
            }
            msg += StringFormat("\n💵 P/L Total: $%.2f\n", totalPL);
        }

        msg += "\n━━━━━━━━━━━━━━━━━━━━";

        SendNotification(msg);
        Print(msg);
    }

    // Obtenir les statistiques
    TradingStats GetStats() { return m_stats; }

    // Réinitialiser les statistiques
    void ResetStats()
    {
        m_stats.totalTrades = 0;
        m_stats.winningTrades = 0;
        m_stats.losingTrades = 0;
        m_stats.totalProfit = 0;
        m_stats.totalLoss = 0;
        m_stats.netProfit = 0;
        m_stats.winRate = 0;
        m_stats.lastNotifyTime = 0;
    }


private:
    // Vérifier si l'opportunité est assez bonne
    bool IsGoodOpportunity(const string quality, const double spikeProb)
    {
        // Trader seulement PERFECT et GOOD
        if(quality != "PERFECT" && quality != "GOOD")
            return false;

        // Pour GOOD, exiger une probabilité spike élevée
        if(quality == "GOOD" && spikeProb < 0.50)
            return false;

        return true;
    }

    // Vérifier si on peut trader ce symbole
    bool CanTrade(const string symbol)
    {
        // Vérifier limite positions totales (pas de log, déjà géré dans TradeOpportunity)
        if(CountOpenPositions() >= m_maxTotalPositions)
            return false;

        // Vérifier limite par symbole (log uniquement si problème)
        if(CountSymbolPositions(symbol) >= m_maxPositionsPerSymbol)
            return false;

        // Vérifier throttle temps (pas de log, trop verbeux)
        datetime lastTrade = GetLastTradeTime(symbol);
        if(lastTrade > 0 && TimeCurrent() - lastTrade < m_minSecondsBetweenTrades)
            return false;

        return true;
    }

    // Calculer le lot size basé sur le risque
    double CalculateLotSize(const string symbol, const double entry, const double sl)
    {
        if(sl <= 0 || entry <= 0)
            return m_minLotSize;

        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        // Distance SL en points
        double slDistance = MathAbs(entry - sl) / point;
        if(slDistance < 10)
            slDistance = 10;

        // Calcul du lot pour ne pas risquer plus de m_maxRiskDollars
        double riskPerPoint = m_maxRiskDollars / slDistance;
        double lotSize = riskPerPoint / tickValue;

        // Arrondir au step
        lotSize = MathFloor(lotSize / lotStep) * lotStep;

        // Limiter
        if(lotSize < minLot) lotSize = minLot;
        if(lotSize > maxLot) lotSize = maxLot;
        if(lotSize > m_maxLotSize) lotSize = m_maxLotSize;

        return lotSize;
    }

    // Calculer les niveaux de scalping
    void CalculateScalpingLevels(const string symbol, const string direction,
                                 const double entry, double &sl, double &tp)
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

        if(direction == "BUY")
        {
            sl = entry - (m_scalpSlPoints * point);
            tp = entry + (m_scalpTpPoints * point);
        }
        else // SELL
        {
            sl = entry + (m_scalpSlPoints * point);
            tp = entry - (m_scalpTpPoints * point);
        }

        // Normaliser
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        sl = NormalizeDouble(sl, digits);
        tp = NormalizeDouble(tp, digits);
    }

    // Ouvrir position BUY avec prix d'entrée du scanner
    bool OpenBuyPosition(const string symbol, const double lots, const double entry, const double sl, const double tp)
    {
        // Utiliser le prix d'entrée calculé du scanner (pas ASK du marché)
        double price = entry > 0 ? entry : SymbolInfoDouble(symbol, SYMBOL_ASK);
        return m_trade.Buy(lots, symbol, price, sl, tp, m_tradeComment);
    }

    // Ouvrir position SELL avec prix d'entrée du scanner
    bool OpenSellPosition(const string symbol, const double lots, const double entry, const double sl, const double tp)
    {
        // Utiliser le prix d'entrée calculé du scanner (pas BID du marché)
        double price = entry > 0 ? entry : SymbolInfoDouble(symbol, SYMBOL_BID);
        return m_trade.Sell(lots, symbol, price, sl, tp, m_tradeComment);
    }

    // Calculer trailing stop
    bool CalculateTrailingStop(const string symbol, ENUM_POSITION_TYPE posType,
                              const double openPrice, const double currentSl, double &newSl)
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

        if(posType == POSITION_TYPE_BUY)
        {
            // BUY: trailing stop monte avec le prix
            double trailLevel = bid - (m_trailingStopPoints * point);
            if(trailLevel > currentSl && trailLevel > openPrice)
            {
                newSl = trailLevel;
                return true;
            }
        }
        else // SELL
        {
            // SELL: trailing stop descend avec le prix
            double trailLevel = ask + (m_trailingStopPoints * point);
            if((currentSl == 0 || trailLevel < currentSl) && trailLevel < openPrice)
            {
                newSl = trailLevel;
                return true;
            }
        }

        return false;
    }

    // Compter positions ouvertes
    int CountOpenPositions()
    {
        int count = 0;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(!m_position.SelectByIndex(i))
                continue;

            if(m_position.Magic() == m_magicNumber)
                count++;
        }
        return count;
    }

    // Compter positions pour un symbole
    int CountSymbolPositions(const string symbol)
    {
        int count = 0;
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(!m_position.SelectByIndex(i))
                continue;

            if(m_position.Magic() == m_magicNumber && m_position.Symbol() == symbol)
                count++;
        }
        return count;
    }

    // Obtenir dernier trade sur symbole
    datetime GetLastTradeTime(const string symbol)
    {
        int size = ArraySize(m_lastTradeTime);
        long symbolHash = StringToInteger(symbol);
        for(int i = 0; i < size; i += 2)
        {
            if(i+1 >= size) break;

            // Format: [hash_symbol, timestamp]
            if((long)m_lastTradeTime[i] == symbolHash)
                return m_lastTradeTime[i+1];
        }
        return 0;
    }

    // Mettre à jour dernier trade
    void UpdateLastTradeTime(const string symbol)
    {
        long hash = StringToInteger(symbol);
        int size = ArraySize(m_lastTradeTime);

        // Chercher si existe
        for(int i = 0; i < size; i += 2)
        {
            if(i+1 >= size) break;

            if((long)m_lastTradeTime[i] == hash)
            {
                m_lastTradeTime[i+1] = TimeCurrent();
                return;
            }
        }

        // Ajouter nouveau
        ArrayResize(m_lastTradeTime, size + 2);
        m_lastTradeTime[size] = (datetime)hash;
        m_lastTradeTime[size + 1] = TimeCurrent();
    }

    // Mettre à jour statistiques
    void UpdateStats()
    {
        m_stats.totalProfit = 0;
        m_stats.totalLoss = 0;
        m_stats.winningTrades = 0;
        m_stats.losingTrades = 0;

        // Analyser l'historique
        HistorySelect(0, TimeCurrent());
        int totalDeals = HistoryDealsTotal();

        for(int i = 0; i < totalDeals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket == 0) continue;

            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magicNumber)
                continue;

            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
                continue;

            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);

            double netPL = profit + swap + commission;

            if(netPL > 0)
            {
                m_stats.winningTrades++;
                m_stats.totalProfit += netPL;
            }
            else if(netPL < 0)
            {
                m_stats.losingTrades++;
                m_stats.totalLoss += MathAbs(netPL);
            }
        }

        m_stats.netProfit = m_stats.totalProfit - m_stats.totalLoss;

        int total = m_stats.winningTrades + m_stats.losingTrades;
        if(total > 0)
            m_stats.winRate = (m_stats.winningTrades * 100.0) / total;
    }

};

#endif
