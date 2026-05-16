
def get_emergency_trading_signal(symbol, rsi, macd, atr):
    """Génère signal trading ultra-rapide en mode dégradé"""
    
    # Règles simples sans IA
    rsi = float(rsi)
    macd = float(macd)
    
    if rsi > 70 and macd > 0:
        return {"signal": "SELL", "confidence": 75, "reason": "RSI overbought"}
    elif rsi < 30 and macd < 0:
        return {"signal": "BUY", "confidence": 75, "reason": "RSI oversold"}
    elif rsi > 60:
        return {"signal": "HOLD", "confidence": 60, "reason": "RSI high"}
    elif rsi < 40:
        return {"signal": "HOLD", "confidence": 60, "reason": "RSI low"}
    else:
        return {"signal": "HOLD", "confidence": 50, "reason": "Neutral"}
