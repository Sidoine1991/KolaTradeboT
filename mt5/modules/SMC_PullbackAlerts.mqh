//+------------------------------------------------------------------+
//| SMC_PullbackAlerts.mqh
//| Pullback Entry System — WhatsApp Alerts via AI Server
//| Sends events to Python service for beautiful formatted messages
//+------------------------------------------------------------------+

#ifndef __SMC_PULLBACK_ALERTS__
#define __SMC_PULLBACK_ALERTS__

// Configuration
string PB_AI_SERVER_URL = "http://127.0.0.1:8000";
string PB_ENDPOINT = "/pullback-alert";

//+------------------------------------------------------------------+
//| Send Pullback Event to Python Service via WebRequest
//+------------------------------------------------------------------+
bool SendPullbackAlert(
    string phase,           // "pullback_start", "pullback_detected", "resumption_confirmed", "trade_opened", "trade_failed"
    string symbol,
    string direction,       // "BUY" or "SELL"
    double breakoutPrice,
    double pullbackPct,
    double pullbackPrice,
    double entryPrice,
    double sl,
    double tp,
    double lot,
    int ticket,
    double riskUSD,
    double rewardUSD,
    string gomLevel,        // "PERFECT BUY", "GOOD BUY", "WAIT"
    double gomConfidence,
    double gomCoherence,
    double mlConfidence = -1.0,
    double atr = -1.0,
    string errorCode = "",
    string errorReason = ""
)
{
    // Build JSON payload
    string json = "{";
    json += "\"phase\":\"" + phase + "\",";
    json += "\"symbol\":\"" + symbol + "\",";
    json += "\"direction\":\"" + direction + "\",";
    json += "\"breakout_price\":" + DoubleToString(breakoutPrice, 2) + ",";
    json += "\"pullback_pct\":" + DoubleToString(pullbackPct, 2) + ",";
    json += "\"pullback_price\":" + DoubleToString(pullbackPrice, 2) + ",";
    json += "\"entry_price\":" + DoubleToString(entryPrice, 2) + ",";
    json += "\"sl\":" + DoubleToString(sl, 2) + ",";
    json += "\"tp\":" + DoubleToString(tp, 2) + ",";
    json += "\"lot\":" + DoubleToString(lot, 2) + ",";
    json += "\"ticket\":" + IntegerToString(ticket) + ",";
    json += "\"risk_usd\":" + DoubleToString(riskUSD, 2) + ",";
    json += "\"reward_usd\":" + DoubleToString(rewardUSD, 2) + ",";
    json += "\"gom_level\":\"" + gomLevel + "\",";
    json += "\"gom_confidence\":" + DoubleToString(gomConfidence, 2) + ",";
    json += "\"gom_coherence\":" + DoubleToString(gomCoherence, 1);

    // Optional fields
    if (mlConfidence >= 0)
        json += ",\"ml_confidence\":" + DoubleToString(mlConfidence, 2);

    if (atr >= 0)
        json += ",\"atr\":" + DoubleToString(atr, 2);

    if (errorCode != "")
        json += ",\"error_code\":\"" + errorCode + "\"";

    if (errorReason != "")
        json += ",\"error_reason\":\"" + errorReason + "\"";

    json += "}";

    // Send via WebRequest
    char data[];
    char result[];

    string url = PB_AI_SERVER_URL + PB_ENDPOINT;

    int res = WebRequest(
        "POST",
        url,
        "",                 // headers (empty = default JSON)
        3000,               // timeout ms
        json,               // body
        data,
        result
    );

    // Handle response
    if (res == -1)
    {
        Print("[PULLBACK ALERT] WebRequest error: ", GetLastError(), " | URL: ", url);
        return false;
    }

    // Parse response
    string response = CharArrayToString(result);
    Print("[PULLBACK ALERT] Response: ", response);

    // Check success
    if (StringFind(response, "\"success\":true") >= 0)
    {
        Print("[PULLBACK ALERT] ✅ ", phase.Upper(), " alert sent successfully");
        return true;
    }
    else
    {
        Print("[PULLBACK ALERT] ⚠️ Response indicated failure: ", response);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Helper: Send Pullback Started Alert
//+------------------------------------------------------------------+
bool AlertPullbackStarted(
    string symbol,
    string direction,
    double breakoutPrice,
    double pullbackMin = 0.5,
    double pullbackMax = 1.5,
    string gomLevel = "GOOD BUY",
    double gomConfidence = 0.75,
    double gomCoherence = 70.0
)
{
    return SendPullbackAlert(
        "pullback_start",
        symbol,
        direction,
        breakoutPrice,
        0,      // pullbackPct
        0,      // pullbackPrice
        0,      // entryPrice
        0,      // sl
        0,      // tp
        0,      // lot
        0,      // ticket
        0,      // riskUSD
        0,      // rewardUSD
        gomLevel,
        gomConfidence,
        gomCoherence
    );
}

//+------------------------------------------------------------------+
//| Helper: Send Pullback Detected Alert
//+------------------------------------------------------------------+
bool AlertPullbackDetected(
    string symbol,
    string direction,
    double breakoutPrice,
    double pullbackPrice,
    double pullbackPct,
    double atr,
    double mlConfidence = -1.0
)
{
    return SendPullbackAlert(
        "pullback_detected",
        symbol,
        direction,
        breakoutPrice,
        pullbackPct,
        pullbackPrice,
        0,      // entryPrice
        0,      // sl
        0,      // tp
        0,      // lot
        0,      // ticket
        0,      // riskUSD
        0,      // rewardUSD
        "PULLBACK",
        0,      // gomConfidence
        0,      // gomCoherence
        mlConfidence,
        atr
    );
}

//+------------------------------------------------------------------+
//| Helper: Send Resumption Confirmed Alert (SIGNAL GO!)
//+------------------------------------------------------------------+
bool AlertResumptionConfirmed(
    string symbol,
    string direction,
    double entryPrice,
    double sl,
    double tp,
    double lot,
    double gomCoherence = 70.0,
    string gomLevelName = "Kola Buy",
    string signals = "EMA Cross + Volume Spike (2/3)"
)
{
    double riskUSD = MathAbs((entryPrice - sl) * lot * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE));
    double rewardUSD = MathAbs((tp - entryPrice) * lot * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE));

    return SendPullbackAlert(
        "resumption_confirmed",
        symbol,
        direction,
        0,      // breakoutPrice
        0,      // pullbackPct
        0,      // pullbackPrice
        entryPrice,
        sl,
        tp,
        lot,
        0,      // ticket
        riskUSD,
        rewardUSD,
        gomLevelName,
        0,      // gomConfidence
        gomCoherence
    );
}

//+------------------------------------------------------------------+
//| Helper: Send Trade Opened Alert
//+------------------------------------------------------------------+
bool AlertTradeOpened(
    string symbol,
    string direction,
    double entryPrice,
    double sl,
    double tp,
    double lot,
    int ticket,
    string gomVerdict = "PERFECT BUY",
    double gomConfidence = 0.85
)
{
    double riskUSD = MathAbs((entryPrice - sl) * lot * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE));
    double rewardUSD = MathAbs((tp - entryPrice) * lot * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE));

    return SendPullbackAlert(
        "trade_opened",
        symbol,
        direction,
        0,      // breakoutPrice
        0,      // pullbackPct
        0,      // pullbackPrice
        entryPrice,
        sl,
        tp,
        lot,
        ticket,
        riskUSD,
        rewardUSD,
        gomVerdict,
        gomConfidence,
        0       // gomCoherence
    );
}

//+------------------------------------------------------------------+
//| Helper: Send Trade Failed Alert
//+------------------------------------------------------------------+
bool AlertTradeFailed(
    string symbol,
    string direction,
    string errorCode,
    string errorReason
)
{
    return SendPullbackAlert(
        "trade_failed",
        symbol,
        direction,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        "ERROR",
        0, 0,
        -1, -1,
        errorCode,
        errorReason
    );
}

#endif
