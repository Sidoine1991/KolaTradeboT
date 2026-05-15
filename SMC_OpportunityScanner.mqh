//+------------------------------------------------------------------+
//| SMC_OpportunityScanner.mqh                                        |
//| Scanner temps réel multi-symboles pour opportunités de trading   |
//| TradBOT build 2026-05-15 — utilise g_SmcOpportunityScannerAutoTrader (pas m_autoTrader)
//+------------------------------------------------------------------+

#ifndef SMC_OPPORTUNITY_SCANNER_MQH
#define SMC_OPPORTUNITY_SCANNER_MQH

#include "SMC_AutoTrader.mqh"

// Instance unique du module auto-trading du scanner (une définition par programme compilé).
#ifndef G_SMC_OPPORTUNITY_SCANNER_AUTOTRADER_DEFINED
#define G_SMC_OPPORTUNITY_SCANNER_AUTOTRADER_DEFINED
CAutoTrader g_SmcOpportunityScannerAutoTrader;
#endif

// Structure pour stocker les opportunités détectées
struct OpportunityData
{
    string symbol;           // Symbole
    string direction;        // BUY / SELL / WAIT
    string quality;          // PERFECT / GOOD / FAIR / WAIT
    double entry;            // Prix d'entrée
    double sl;               // Stop Loss
    double tp1;              // Take Profit 1
    double tp2;              // Take Profit 2
    double tp3;              // Take Profit 3
    double spikeProb;        // Probabilité spike (0-1)
    double confidence;       // Confiance globale (0-100)
    double techBuyScore;     // Score technique BUY
    double techSellScore;    // Score technique SELL
    datetime timestamp;      // Dernière mise à jour
    string timeframe;        // Timeframe principal
    bool isValid;            // Opportunité valide
    double currentPrice;     // Prix actuel
    double distanceToEntry;  // Distance à l'entrée (points)
    int touchCount;          // Nombre de touches niveau
    string nearLevels;       // Niveaux proches (ex: "M5 BUY, H1 SELL")
};

// Classe Scanner d'Opportunités
class COpportunityScanner
{
private:
    OpportunityData m_opportunities[];  // Tableau des opportunités
    int m_maxSymbols;                   // Nombre max de symboles
    datetime m_lastScanTime;            // Dernière analyse
    int m_scanIntervalSeconds;          // Intervalle de scan

    // Position du panneau sur le graphique
    int m_panelX;
    int m_panelY;
    bool m_panelAnchorRight; // true: m_panelX = marge depuis le bord droit
    int m_panelWidth;
    int m_rowHeight;
    int m_headerHeight;

    // Couleurs
    color m_colorBuy;
    color m_colorSell;
    color m_colorWait;
    color m_colorPerfect;
    color m_colorGood;
    color m_colorFair;
    color m_colorBackground;
    color m_colorHeader;
    color m_colorBorder;
    color m_colorText;

    // Paramètres d'affichage
    int m_fontSize;
    string m_fontName;
    bool m_showPanel;

    bool m_enableAutoTrading;
    datetime m_tradedOpportunities[];  // Tracker opportunités déjà tradées

    // Cache pour optimisation
    int m_atrHandles[];                // Handles ATR par symbole (cache)
    string m_atrSymbols[];             // Symboles correspondants
    int m_atrCacheSize;
    datetime m_lastPanelUpdate;        // Dernière mise à jour affichage
    int m_panelUpdateInterval;         // Intervalle update affichage (secondes)

public:
    // Constructeur
    COpportunityScanner()
    {
        m_enableAutoTrading = false;
        m_maxSymbols = 20;
        m_lastScanTime = 0;
        m_scanIntervalSeconds = 4;  // Scan toutes les N secondes (défaut allégé)

        // Position par défaut (coin supérieur droit : évite le dashboard)
        m_panelX = 12;
        m_panelY = 100;
        m_panelAnchorRight = true;
        m_panelWidth = 520;  // Largeur augmentée pour afficher tous les niveaux
        m_rowHeight = 45;    // Hauteur augmentée pour 2 lignes (info + niveaux)
        m_headerHeight = 30;

        // Cache optimisation
        m_atrCacheSize = 0;
        ArrayResize(m_atrHandles, 0);
        ArrayResize(m_atrSymbols, 0);
        m_lastPanelUpdate = 0;
        m_panelUpdateInterval = 8;  // Update panneau toutes les N secondes

        // Couleurs par défaut
        m_colorBuy = clrLimeGreen;
        m_colorSell = clrRed;
        m_colorWait = clrGray;
        m_colorPerfect = clrGold;
        m_colorGood = clrLimeGreen;
        m_colorFair = clrOrange;
        m_colorBackground = C'20,20,25';
        m_colorHeader = C'30,30,35';
        m_colorBorder = C'60,60,65';
        m_colorText = clrWhite;

        m_fontSize = 8;
        m_fontName = "Consolas";
        m_showPanel = true;

        ArrayResize(m_opportunities, 0);
    }

    // Destructeur
    ~COpportunityScanner()
    {
        CleanupPanel();
    }

    // Configuration
    void SetScanInterval(int seconds) { m_scanIntervalSeconds = MathMax(1, seconds); }
    void SetPanelPosition(int x, int y)
    {
        m_panelX = x;
        m_panelY = y;
    }
    void SetPanelAnchorRight(bool anchorRight) { m_panelAnchorRight = anchorRight; }

    int PanelContentLeftPx()
    {
        if(!m_panelAnchorRight)
            return m_panelX;
        long cw = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
        if(cw <= 50)
            cw = 1200;
        return (int)cw - m_panelWidth - m_panelX;
    }
    void SetPanelWidth(int width) { m_panelWidth = MathMax(300, width); }
    void SetRowHeight(int height) { m_rowHeight = MathMax(20, height); }
    void ShowPanel(bool show) { m_showPanel = show; }

    // Configuration auto-trading
    void EnableAutoTrading(bool enable, double maxRisk, double tpPoints, double slPoints,
                          bool trailingStop, double trailPoints, double trailStep)
    {
        m_enableAutoTrading = enable;
        if(!enable)
            return;

        g_SmcOpportunityScannerAutoTrader.SetMaxRiskDollars(maxRisk);
        g_SmcOpportunityScannerAutoTrader.SetScalpingParams(tpPoints, slPoints);
        g_SmcOpportunityScannerAutoTrader.SetTrailingStop(trailingStop, trailPoints, trailStep);
        g_SmcOpportunityScannerAutoTrader.SetNotifications(true, 10);  // Notifications toutes les 10 min
        g_SmcOpportunityScannerAutoTrader.SetMaxPositions(1, 3);       // 1 par symbole, 3 total
    }

    // Scanner principal - appelé à chaque tick
    void ScanMarkets(const string symbolsList)
    {
        // Throttle: ne scanner que toutes les N secondes
        datetime now = TimeCurrent();
        if(now - m_lastScanTime < m_scanIntervalSeconds)
            return;

        m_lastScanTime = now;

        // Parser la liste des symboles
        string symbols[];
        ParseSymbolsList(symbolsList, symbols);

        // Redimensionner le tableau des opportunités
        int count = ArraySize(symbols);
        ArrayResize(m_opportunities, count);

        // Scanner chaque symbole
        for(int i = 0; i < count; i++)
        {
            ScanSymbol(symbols[i], m_opportunities[i]);

            // Trading automatique sur opportunités PERFECT et GOOD
            if(m_enableAutoTrading && m_opportunities[i].isValid)
            {
                if(!HasBeenTraded(m_opportunities[i]))
                {
                    bool success = g_SmcOpportunityScannerAutoTrader.TradeOpportunity(
                        m_opportunities[i].symbol,
                        m_opportunities[i].direction,
                        m_opportunities[i].quality,
                        m_opportunities[i].entry,
                        m_opportunities[i].sl,
                        m_opportunities[i].tp1,
                        m_opportunities[i].spikeProb
                    );

                    if(success)
                        MarkAsTraded(m_opportunities[i]);
                }
            }
        }

        // Gérer les positions ouvertes (trailing stop)
        if(m_enableAutoTrading)
        {
            g_SmcOpportunityScannerAutoTrader.ManageOpenPositions();
            g_SmcOpportunityScannerAutoTrader.SendPeriodicNotification();
        }

        // Mettre à jour l'affichage (throttle pour réduire charge CPU)
        if(m_showPanel && (now - m_lastPanelUpdate >= m_panelUpdateInterval))
        {
            UpdatePanel();
            m_lastPanelUpdate = now;
        }
    }

    // Scanner un symbole spécifique avec analyse technique complète
    void ScanSymbol(const string symbol, OpportunityData &opp)
    {
        opp.symbol = symbol;
        opp.timestamp = TimeCurrent();
        opp.isValid = false;

        // Récupérer le prix actuel
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        opp.currentPrice = (bid + ask) / 2.0;

        if(bid <= 0 || ask <= 0)
            return;

        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        // ANALYSE TECHNIQUE COMPLÈTE POUR DÉTECTER OPPORTUNITÉS
        bool hasTechnicalSetup = AnalyzeSymbolTechnicals(symbol, opp);

        if(!hasTechnicalSetup)
        {
            // Pas d'opportunité technique détectée, marquer comme WAIT
            opp.direction = "WAIT";
            opp.quality = "WAIT";
            opp.isValid = false;
            return;
        }

        // Si analyse technique a trouvé un setup, les niveaux sont déjà calculés
        // Calculer la distance à l'entrée
        if(opp.entry > 0)
        {
            opp.distanceToEntry = MathAbs(opp.currentPrice - opp.entry) / point;
        }
        else
            opp.distanceToEntry = 0;

        // Timeframe principal
        opp.timeframe = "M5/M15";

        // Valider l'opportunité SEULEMENT si setup complet
        if(opp.direction == "BUY" || opp.direction == "SELL")
        {
            // UNIQUEMENT OPPORTUNITÉS CERTAINES (PERFECT ou GOOD)
            if(opp.quality == "PERFECT" || opp.quality == "GOOD")
            {
                // Vérifier que tous les niveaux sont définis
                if(opp.entry > 0 && opp.sl > 0 && opp.tp1 > 0)
                {
                    // Vérifier cohérence des niveaux
                    if(opp.direction == "BUY")
                    {
                        if(opp.sl < opp.entry && opp.tp1 > opp.entry)
                            opp.isValid = true;
                    }
                    else if(opp.direction == "SELL")
                    {
                        if(opp.sl > opp.entry && opp.tp1 < opp.entry)
                            opp.isValid = true;
                    }
                }
            }
        }
    }

    // Analyse technique complète d'un symbole
    bool AnalyzeSymbolTechnicals(const string symbol, OpportunityData &opp)
    {
        // ÉTAPE 1: Lire le verdict GOM depuis Global Variables
        double verdictNum = ReadGVDouble(symbol, "VERDICT_NUM");
        double gomBuyEntry = ReadGVDouble(symbol, "BUY_ENTRY");
        double gomSellEntry = ReadGVDouble(symbol, "SELL_ENTRY");
        double gomSL = ReadGVDouble(symbol, "SL");
        double gomTP1 = ReadGVDouble(symbol, "TP1");
        double gomTP2 = ReadGVDouble(symbol, "TP2");
        double gomTP3 = ReadGVDouble(symbol, "TP3");
        double spikeProb = ReadGVDouble(symbol, "SPIKE_PROB");

        opp.spikeProb = spikeProb;

        // Déterminer verdict GOM
        string gomDirection = "";
        string gomQuality = "";
        double gomConfidence = 0;

        if(verdictNum >= 3.0)
        {
            gomDirection = "BUY";
            gomQuality = "PERFECT";
            gomConfidence = 95.0;
        }
        else if(verdictNum >= 2.0)
        {
            gomDirection = "BUY";
            gomQuality = "GOOD";
            gomConfidence = 75.0;
        }
        else if(verdictNum <= -3.0)
        {
            gomDirection = "SELL";
            gomQuality = "PERFECT";
            gomConfidence = 95.0;
        }
        else if(verdictNum <= -2.0)
        {
            gomDirection = "SELL";
            gomQuality = "GOOD";
            gomConfidence = 75.0;
        }

        // ÉTAPE 2: Faire AUSSI l'analyse technique du scanner
        double m5Buy = 0, m5Sell = 0, m15Buy = 0, m15Sell = 0, h1Buy = 0, h1Sell = 0;
        int m5BuyTouch = 0, m5SellTouch = 0;

        // Lire niveaux depuis Global Variables
        m5Buy = ReadGVDouble(symbol, "M5_BUY");
        m5Sell = ReadGVDouble(symbol, "M5_SELL");
        m15Buy = ReadGVDouble(symbol, "M15_BUY");
        m15Sell = ReadGVDouble(symbol, "M15_SELL");
        h1Buy = ReadGVDouble(symbol, "H1_BUY");
        h1Sell = ReadGVDouble(symbol, "H1_SELL");
        m5BuyTouch = (int)ReadGVDouble(symbol, "M5_BUY_TOUCH");
        m5SellTouch = (int)ReadGVDouble(symbol, "M5_SELL_TOUCH");

        // Calculer les scores techniques BUY et SELL
        double buyScore = 0, sellScore = 0;
        int buyCount = 0, sellCount = 0;

        // Score basé sur les niveaux disponibles
        if(m5Buy > 0) { buyScore += 30; buyCount++; }
        if(m5Sell > 0) { sellScore += 30; sellCount++; }
        if(m15Buy > 0) { buyScore += 40; buyCount++; }
        if(m15Sell > 0) { sellScore += 40; sellCount++; }
        if(h1Buy > 0) { buyScore += 30; buyCount++; }
        if(h1Sell > 0) { sellScore += 30; sellCount++; }

        // Bonus pour touches multiples
        if(m5BuyTouch >= 2) buyScore += 20;
        if(m5SellTouch >= 2) sellScore += 20;

        // Bonus spike
        if(spikeProb > 0.6)
        {
            buyScore += 30;
            sellScore += 30;
        }

        opp.techBuyScore = buyScore;
        opp.techSellScore = sellScore;

        // Distance actuelle aux niveaux
        double distM5Buy = (m5Buy > 0) ? MathAbs(opp.currentPrice - m5Buy) : 999999;
        double distM5Sell = (m5Sell > 0) ? MathAbs(opp.currentPrice - m5Sell) : 999999;
        double distM15Buy = (m15Buy > 0) ? MathAbs(opp.currentPrice - m15Buy) : 999999;
        double distM15Sell = (m15Sell > 0) ? MathAbs(opp.currentPrice - m15Sell) : 999999;

        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double atr = GetATR(symbol, PERIOD_M15, 14);
        double threshold = atr * 0.3; // 30% ATR comme seuil de proximité

        // Déterminer la direction basée sur la proximité et le score
        bool nearBuyLevel = (distM5Buy < threshold || distM15Buy < threshold);
        bool nearSellLevel = (distM5Sell < threshold || distM15Sell < threshold);

        // ÉTAPE 3: FUSION GOM + SCANNER
        // Si GOM et Scanner concordent → Confiance maximale
        // Si seulement GOM (GOOD/PERFECT) → Utiliser GOM
        // Si seulement Scanner → Utiliser Scanner

        string finalDirection = "";
        string finalQuality = "";
        double finalConfidence = 0;
        bool useGomLevels = false;

        // Analyse scanner
        bool scannerBuy = (nearBuyLevel && buyScore > sellScore && buyScore >= 50);
        bool scannerSell = (nearSellLevel && sellScore > buyScore && sellScore >= 50);
        string scannerDirection = scannerBuy ? "BUY" : (scannerSell ? "SELL" : "");
        double scannerConfidence = scannerBuy ? buyScore : (scannerSell ? sellScore : 0);

        // Cas 1: GOM + SCANNER concordent → PARFAIT (confiance boostée)
        if(gomDirection != "" && gomDirection == scannerDirection)
        {
            finalDirection = gomDirection;
            finalConfidence = MathMax(gomConfidence, scannerConfidence) + 10; // Bonus concordance

            // Qualité = la meilleure des deux
            if(gomQuality == "PERFECT" || finalConfidence >= 100)
                finalQuality = "PERFECT";
            else if(gomQuality == "GOOD" || finalConfidence >= 80)
                finalQuality = "GOOD";
            else
                finalQuality = "FAIR";

            useGomLevels = true; // Utiliser niveaux GOM (plus précis)
        }
        // Cas 2: Seulement GOM GOOD/PERFECT → Utiliser GOM
        else if(gomDirection != "" && (gomQuality == "PERFECT" || gomQuality == "GOOD"))
        {
            finalDirection = gomDirection;
            finalQuality = gomQuality;
            finalConfidence = gomConfidence;
            useGomLevels = true;
        }
        // Cas 3: Seulement Scanner → Utiliser Scanner
        else if(scannerDirection != "")
        {
            finalDirection = scannerDirection;
            finalConfidence = scannerConfidence;

            if(finalConfidence >= 90) finalQuality = "PERFECT";
            else if(finalConfidence >= 70) finalQuality = "GOOD";
            else if(finalConfidence >= 50) finalQuality = "FAIR";
            else return false;

            useGomLevels = false;
        }
        else
        {
            // Aucune opportunité détectée
            return false;
        }

        // Appliquer la décision finale
        opp.direction = finalDirection;
        opp.quality = finalQuality;
        opp.confidence = finalConfidence;

        // Utiliser les niveaux appropriés
        if(useGomLevels && gomSL > 0 && gomTP1 > 0)
        {
            // Niveaux GOM disponibles et valides
            if(finalDirection == "BUY")
                opp.entry = gomBuyEntry;
            else
                opp.entry = gomSellEntry;

            opp.sl = gomSL;
            opp.tp1 = gomTP1;
            opp.tp2 = (gomTP2 > 0) ? gomTP2 : opp.tp1 * 1.5;
            opp.tp3 = (gomTP3 > 0) ? gomTP3 : opp.tp1 * 2.0;
        }
        else
        {
            // Calculer les niveaux avec le scanner
            if(finalDirection == "BUY")
                CalculateBuyLevels(symbol, opp, m5Buy, m15Buy, h1Buy, atr);
            else
                CalculateSellLevels(symbol, opp, m5Sell, m15Sell, h1Sell, atr);
        }

        // Détecter les niveaux proches (affichage)
        opp.nearLevels = DetectNearLevels(symbol, opp.currentPrice);
        opp.touchCount = (finalDirection == "BUY") ? m5BuyTouch : m5SellTouch;

        return true;
    }

    // Calculer les niveaux précis pour BUY
    void CalculateBuyLevels(const string symbol, OpportunityData &opp,
                            double m5Buy, double m15Buy, double h1Buy, double atr)
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

        // ENTRY: Niveau le plus proche (M5 prioritaire)
        if(m5Buy > 0) opp.entry = m5Buy;
        else if(m15Buy > 0) opp.entry = m15Buy;
        else if(h1Buy > 0) opp.entry = h1Buy;
        else opp.entry = opp.currentPrice; // Fallback

        // SL: En dessous de l'entrée (basé sur ATR)
        double slDistance = atr * 1.5; // 1.5x ATR
        opp.sl = NormalizeDouble(opp.entry - slDistance, digits);

        // TP1: Ratio 1:1.5 (risque:rendement)
        double riskDistance = opp.entry - opp.sl;
        opp.tp1 = NormalizeDouble(opp.entry + (riskDistance * 1.5), digits);

        // TP2: Ratio 1:2.5
        opp.tp2 = NormalizeDouble(opp.entry + (riskDistance * 2.5), digits);

        // TP3: Ratio 1:4.0
        opp.tp3 = NormalizeDouble(opp.entry + (riskDistance * 4.0), digits);
    }

    // Calculer les niveaux précis pour SELL
    void CalculateSellLevels(const string symbol, OpportunityData &opp,
                             double m5Sell, double m15Sell, double h1Sell, double atr)
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

        // ENTRY: Niveau le plus proche (M5 prioritaire)
        if(m5Sell > 0) opp.entry = m5Sell;
        else if(m15Sell > 0) opp.entry = m15Sell;
        else if(h1Sell > 0) opp.entry = h1Sell;
        else opp.entry = opp.currentPrice; // Fallback

        // SL: Au dessus de l'entrée (basé sur ATR)
        double slDistance = atr * 1.5; // 1.5x ATR
        opp.sl = NormalizeDouble(opp.entry + slDistance, digits);

        // TP1: Ratio 1:1.5 (risque:rendement)
        double riskDistance = opp.sl - opp.entry;
        opp.tp1 = NormalizeDouble(opp.entry - (riskDistance * 1.5), digits);

        // TP2: Ratio 1:2.5
        opp.tp2 = NormalizeDouble(opp.entry - (riskDistance * 2.5), digits);

        // TP3: Ratio 1:4.0
        opp.tp3 = NormalizeDouble(opp.entry - (riskDistance * 4.0), digits);
    }

    // Détecter les niveaux proches
    string DetectNearLevels(const string symbol, const double price)
    {
        string levels = "";
        double atr = GetATR(symbol, PERIOD_M15, 14);
        double threshold = atr * 0.5;

        // Vérifier M5
        double m5Buy = ReadGVDouble(symbol, "M5_BUY");
        double m5Sell = ReadGVDouble(symbol, "M5_SELL");

        if(m5Buy > 0 && MathAbs(price - m5Buy) <= threshold)
        {
            if(StringLen(levels) > 0) levels += ", ";
            levels += "M5 BUY";
        }
        if(m5Sell > 0 && MathAbs(price - m5Sell) <= threshold)
        {
            if(StringLen(levels) > 0) levels += ", ";
            levels += "M5 SELL";
        }

        // Vérifier H1
        double h1Buy = ReadGVDouble(symbol, "H1_BUY");
        double h1Sell = ReadGVDouble(symbol, "H1_SELL");

        if(h1Buy > 0 && MathAbs(price - h1Buy) <= threshold)
        {
            if(StringLen(levels) > 0) levels += ", ";
            levels += "H1 BUY";
        }
        if(h1Sell > 0 && MathAbs(price - h1Sell) <= threshold)
        {
            if(StringLen(levels) > 0) levels += ", ";
            levels += "H1 SELL";
        }

        if(StringLen(levels) == 0)
            levels = "-";

        return levels;
    }

    // Lire la direction et la qualité depuis VERDICT_NUM
    // VERDICT_NUM encode: 3=PERFECT BUY, 2=GOOD BUY, 1=BUY, -3=PERFECT SELL, -2=GOOD SELL, -1=SELL, 0=WAIT
    string ReadGVDirection(const string symbol)
    {
        string fullKey = "GOM_SCRIPT_" + symbol + "_VERDICT_NUM";
        if(!GlobalVariableCheck(fullKey))
            return "WAIT";

        double val = GlobalVariableGet(fullKey);
        if(val > 0.5) return "BUY";
        if(val < -0.5) return "SELL";
        return "WAIT";
    }

    // Lire la qualité depuis VERDICT_NUM
    string ReadGVQuality(const string symbol)
    {
        string fullKey = "GOM_SCRIPT_" + symbol + "_VERDICT_NUM";
        if(!GlobalVariableCheck(fullKey))
            return "WAIT";

        double val = GlobalVariableGet(fullKey);
        double absVal = MathAbs(val);

        if(absVal >= 2.5) return "PERFECT";
        if(absVal >= 1.5) return "GOOD";
        if(absVal >= 0.5) return "FAIR";
        return "WAIT";
    }

    // Lire une Global Variable Double (GOM_SCRIPT_SYMBOL_KEY)
    double ReadGVDouble(const string symbol, const string key)
    {
        // Le scanner lit les niveaux KOLA publiés par GOM_KOLA_SIDO_Script.mq5 ou SMC_Universal.mq5
        // Format: GOM_KOLA_<Symbol>_<Timeframe>_<Side>
        // Exemple: GOM_KOLA_Boom 1000 Index_M5_BUY

        string fullKey = "";

        // Construire la clé selon le format key (ex: "M5_BUY" -> "GOM_KOLA_Symbol_M5_BUY")
        if(StringFind(key, "_") >= 0)
        {
            fullKey = "GOM_KOLA_" + symbol + "_" + key;
        }
        else
        {
            fullKey = "GOM_SCRIPT_" + symbol + "_" + key;
        }

        if(!GlobalVariableCheck(fullKey))
            return 0.0;

        return GlobalVariableGet(fullKey);
    }

    // Parser la liste des symboles
    void ParseSymbolsList(const string symbolsList, string &symbols[])
    {
        ArrayResize(symbols, 0);

        if(StringLen(symbolsList) == 0)
        {
            // Si pas de liste, utiliser le symbole actuel
            ArrayResize(symbols, 1);
            symbols[0] = _Symbol;
            return;
        }

        // Parser la liste séparée par des virgules
        string temp = symbolsList;
        StringReplace(temp, " ", "");  // Supprimer les espaces

        int pos = 0;
        int count = 0;

        while(true)
        {
            int next = StringFind(temp, ",", pos);
            string sym;

            if(next < 0)
            {
                // Dernier symbole
                sym = StringSubstr(temp, pos);
                if(StringLen(sym) > 0)
                {
                    count++;
                    ArrayResize(symbols, count);
                    symbols[count - 1] = sym;
                }
                break;
            }
            else
            {
                sym = StringSubstr(temp, pos, next - pos);
                if(StringLen(sym) > 0)
                {
                    count++;
                    ArrayResize(symbols, count);
                    symbols[count - 1] = sym;
                }
                pos = next + 1;
            }
        }
    }

    // Calculer l'ATR avec cache pour réduire charge CPU
    double GetATR(const string symbol, ENUM_TIMEFRAMES tf, int period)
    {
        // Chercher dans le cache
        int handle = INVALID_HANDLE;
        bool found = false;

        for(int i = 0; i < m_atrCacheSize; i++)
        {
            if(m_atrSymbols[i] == symbol)
            {
                handle = m_atrHandles[i];
                found = true;
                break;
            }
        }

        // Si pas dans cache, créer et ajouter
        if(!found)
        {
            handle = iATR(symbol, tf, period);
            if(handle == INVALID_HANDLE)
                return 0.0;

            // Ajouter au cache
            m_atrCacheSize++;
            ArrayResize(m_atrHandles, m_atrCacheSize);
            ArrayResize(m_atrSymbols, m_atrCacheSize);
            m_atrHandles[m_atrCacheSize - 1] = handle;
            m_atrSymbols[m_atrCacheSize - 1] = symbol;
        }

        // Lire la valeur
        double atr[];
        ArraySetAsSeries(atr, true);

        if(CopyBuffer(handle, 0, 0, 1, atr) <= 0)
            return 0.0;

        return atr[0];
    }

    // Mettre à jour le panneau graphique
    void UpdatePanel()
    {
        // Nettoyer d'abord
        CleanupPanel();

        // Créer le fond du panneau
        CreateBackground();

        // Créer l'en-tête
        CreateHeader();

        // Trier les opportunités par qualité
        SortOpportunitiesByQuality();

        // Afficher les opportunités
        int validCount = 0;
        for(int i = 0; i < ArraySize(m_opportunities); i++)
        {
            if(m_opportunities[i].isValid)
            {
                CreateOpportunityRow(validCount, m_opportunities[i]);
                validCount++;

                if(validCount >= 15)  // Limiter à 15 lignes visibles
                    break;
            }
        }

        // Si aucune opportunité, afficher un message
        if(validCount == 0)
        {
            CreateNoOpportunityMessage();
        }

        // Forcer le rafraîchissement
        ChartRedraw();
    }

    // Trier les opportunités par qualité
    void SortOpportunitiesByQuality()
    {
        int size = ArraySize(m_opportunities);

        for(int i = 0; i < size - 1; i++)
        {
            for(int j = i + 1; j < size; j++)
            {
                int scoreI = GetQualityScore(m_opportunities[i]);
                int scoreJ = GetQualityScore(m_opportunities[j]);

                if(scoreJ > scoreI)
                {
                    // Échanger
                    OpportunityData temp = m_opportunities[i];
                    m_opportunities[i] = m_opportunities[j];
                    m_opportunities[j] = temp;
                }
            }
        }
    }

    // Obtenir un score de qualité pour le tri
    int GetQualityScore(const OpportunityData &opp)
    {
        if(!opp.isValid) return 0;

        int score = 0;

        // Qualité
        if(opp.quality == "PERFECT") score += 1000;
        else if(opp.quality == "GOOD") score += 500;
        else if(opp.quality == "FAIR") score += 100;

        // Probabilité spike
        score += (int)(opp.spikeProb * 100);

        // Confiance
        score += (int)(opp.confidence * 10);

        // Distance à l'entrée (plus proche = mieux)
        if(opp.distanceToEntry > 0)
            score += (int)(1000.0 / (opp.distanceToEntry + 1));

        return score;
    }

    // Créer le fond du panneau
    void CreateBackground()
    {
        int totalHeight = m_headerHeight + (m_rowHeight * 16);

        string name = "SCANNER_BG";
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelContentLeftPx());
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_panelY);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, m_panelWidth);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, totalHeight);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_colorBackground);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_COLOR, m_colorBorder);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    }

    // Créer l'en-tête
    void CreateHeader()
    {
        // Fond de l'en-tête
        string name = "SCANNER_HEADER_BG";
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelContentLeftPx());
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_panelY);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, m_panelWidth);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, m_headerHeight);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_colorHeader);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_COLOR, m_colorBorder);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 101);

        // Titre
        name = "SCANNER_TITLE";
        string title = "SCANNER OPPORTUNITÉS TEMPS RÉEL";
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelContentLeftPx() + 10);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_panelY + 8);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize + 2);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
        ObjectSetString(0, name, OBJPROP_TEXT, title);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);

        // Plus de file d'attente - opportunités annulées si terminal occupé

        // Timestamp
        name = "SCANNER_TIMESTAMP";
        string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelContentLeftPx() + m_panelWidth - 10);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_panelY + 10);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrSilver);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 1);
        ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
        ObjectSetString(0, name, OBJPROP_TEXT, ts);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
    }

    // Créer une ligne d'opportunité avec niveaux de trading
    void CreateOpportunityRow(int index, const OpportunityData &opp)
    {
        int rowHeightExtended = m_rowHeight + 20; // Hauteur élargie pour 2 lignes
        int y = m_panelY + m_headerHeight + (index * rowHeightExtended);

        // Fond de ligne (alternance couleur)
        color rowBg = (index % 2 == 0) ? C'25,25,30' : C'20,20,25';
        string name = "SCANNER_ROW_BG_" + IntegerToString(index);
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelContentLeftPx());
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, m_panelWidth);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, rowHeightExtended);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, rowBg);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 101);

        int xOffset = PanelContentLeftPx() + 5;
        int digits = (int)SymbolInfoInteger(opp.symbol, SYMBOL_DIGITS);

        // LIGNE 1: Symbole + Direction + Qualité
        // Symbole
        name = "SCANNER_SYM_" + IntegerToString(index);
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + 3);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize + 1);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
        ObjectSetString(0, name, OBJPROP_TEXT, opp.symbol);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);

        // Direction
        name = "SCANNER_DIR_" + IntegerToString(index);
        color dirColor = (opp.direction == "BUY") ? m_colorBuy : (opp.direction == "SELL") ? m_colorSell : m_colorWait;
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset + 95);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + 3);
        ObjectSetInteger(0, name, OBJPROP_COLOR, dirColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize + 1);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
        ObjectSetString(0, name, OBJPROP_TEXT, opp.direction);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);

        // Qualité
        name = "SCANNER_QUAL_" + IntegerToString(index);
        color qualColor = (opp.quality == "PERFECT") ? m_colorPerfect :
                         (opp.quality == "GOOD") ? m_colorGood : m_colorFair;
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset + 155);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + 3);
        ObjectSetInteger(0, name, OBJPROP_COLOR, qualColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
        ObjectSetString(0, name, OBJPROP_TEXT, opp.quality);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);

        // Probabilité spike
        name = "SCANNER_SPIKE_" + IntegerToString(index);
        string spikeText = StringFormat("Spike:%.0f%%", opp.spikeProb * 100);
        color spikeColor = (opp.spikeProb >= 0.45) ? clrRed : (opp.spikeProb >= 0.30) ? clrOrange : clrGray;
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset + 240);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + 5);
        ObjectSetInteger(0, name, OBJPROP_COLOR, spikeColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 1);
        ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
        ObjectSetString(0, name, OBJPROP_TEXT, spikeText);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);

        // LIGNE 2: NIVEAUX DE TRADING (Entry, SL, TP1, TP2, TP3)
        int y2 = y + 20;
        xOffset = PanelContentLeftPx() + 5;

        // Entry
        name = "SCANNER_ENTRY_" + IntegerToString(index);
        string entryText = StringFormat("Entry:%.5f", opp.entry);
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y2);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrCyan);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 1);
        ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
        ObjectSetString(0, name, OBJPROP_TEXT, entryText);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
        xOffset += 85;

        // SL
        name = "SCANNER_SL_" + IntegerToString(index);
        string slText = StringFormat("SL:%.5f", opp.sl);
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y2);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 1);
        ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
        ObjectSetString(0, name, OBJPROP_TEXT, slText);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
        xOffset += 85;

        // TP1
        name = "SCANNER_TP1_" + IntegerToString(index);
        string tp1Text = StringFormat("TP1:%.5f", opp.tp1);
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y2);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrLimeGreen);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 1);
        ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
        ObjectSetString(0, name, OBJPROP_TEXT, tp1Text);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
        xOffset += 90;

        // TP2 (optionnel)
        if(opp.tp2 > 0)
        {
            name = "SCANNER_TP2_" + IntegerToString(index);
            string tp2Text = StringFormat("TP2:%.5f", opp.tp2);
            ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y2);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLightGreen);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 2);
            ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
            ObjectSetString(0, name, OBJPROP_TEXT, tp2Text);
            ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
            xOffset += 90;
        }

        // TP3 (optionnel)
        if(opp.tp3 > 0)
        {
            name = "SCANNER_TP3_" + IntegerToString(index);
            string tp3Text = StringFormat("TP3:%.5f", opp.tp3);
            ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y2);
            ObjectSetInteger(0, name, OBJPROP_COLOR, C'100,255,100');
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 2);
            ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
            ObjectSetString(0, name, OBJPROP_TEXT, tp3Text);
            ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
        }

        // Ligne de séparation
        name = "SCANNER_SEP_" + IntegerToString(index);
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_COLOR, m_colorBorder);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        name = "SCANNER_LEVELS_" + IntegerToString(index);
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xOffset);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + 5);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize - 2);
        ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
        ObjectSetString(0, name, OBJPROP_TEXT, opp.nearLevels);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
    }

    // Message si aucune opportunité
    void CreateNoOpportunityMessage()
    {
        int y = m_panelY + m_headerHeight + m_rowHeight;

        string name = "SCANNER_NO_OPP";
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelContentLeftPx() + m_panelWidth / 2);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + 40);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize + 1);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetString(0, name, OBJPROP_TEXT, "Aucune opportunité détectée pour le moment...");
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 102);
    }

    // Nettoyer tous les objets du panneau
    void CleanupPanel()
    {
        // Supprimer tous les objets commençant par SCANNER_
        int total = ObjectsTotal(0, -1, -1);
        for(int i = total - 1; i >= 0; i--)
        {
            string name = ObjectName(0, i, -1, -1);
            if(StringFind(name, "SCANNER_") == 0)
            {
                ObjectDelete(0, name);
            }
        }
    }

    // Obtenir le nombre d'opportunités valides
    int GetValidOpportunitiesCount()
    {
        int count = 0;
        for(int i = 0; i < ArraySize(m_opportunities); i++)
        {
            if(m_opportunities[i].isValid)
                count++;
        }
        return count;
    }

    // Obtenir une opportunité spécifique
    bool GetOpportunity(int index, OpportunityData &opp)
    {
        if(index < 0 || index >= ArraySize(m_opportunities))
            return false;

        opp = m_opportunities[index];
        return opp.isValid;
    }

    // Vérifier si l'opportunité a déjà été tradée
    bool HasBeenTraded(const OpportunityData &opp)
    {
        // Créer une clé unique: symbole + direction + entry price
        string key = opp.symbol + "_" + opp.direction + "_" + DoubleToString(opp.entry, 5);
        int hash = StringHash(key);

        // Chercher dans le tracker
        int size = ArraySize(m_tradedOpportunities);
        for(int i = 0; i < size; i++)
        {
            if((int)m_tradedOpportunities[i] == hash)
                return true;
        }

        return false;
    }

    // Marquer l'opportunité comme tradée
    void MarkAsTraded(const OpportunityData &opp)
    {
        string key = opp.symbol + "_" + opp.direction + "_" + DoubleToString(opp.entry, 5);
        int hash = StringHash(key);

        int size = ArraySize(m_tradedOpportunities);
        ArrayResize(m_tradedOpportunities, size + 1);
        m_tradedOpportunities[size] = (datetime)hash;

        // Nettoyer les anciennes entrées (garder max 100)
        if(size > 100)
        {
            ArrayResize(m_tradedOpportunities, 100);
        }
    }

    // Fonction de hachage simple
    int StringHash(const string str)
    {
        int hash = 0;
        for(int i = 0; i < StringLen(str); i++)
        {
            hash = hash * 31 + (int)StringGetCharacter(str, i);
        }
        return hash;
    }
};

#endif
