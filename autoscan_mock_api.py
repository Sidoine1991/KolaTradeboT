import os
from flask import Flask, request, jsonify

app = Flask(__name__)


@app.get("/signals")
def signals():
    symbol = request.args.get("symbol", "Boom 1000 Index")
    action = "BUY" if "Boom" in symbol else "SELL"
    reason = request.args.get("reason", "Mock autoscan")
    # Default strong confidence (90). Override with ?conf=85.5
    try:
        conf = float(request.args.get("conf", "90"))
    except ValueError:
        conf = 90.0
    try:
        price = float(request.args.get("price", "0"))
    except ValueError:
        price = 0.0

    resp = {
        "symbol": symbol,
        "action": action,
        "reason": reason,
        "confidence": conf,
        "price": price,
    }
    return jsonify(resp)


@app.get("/signals/weak")
def signals_weak():
    symbol = request.args.get("symbol", "Crash 1000 Index")
    # Force a weak confidence (70) to verify EA filtering
    resp = {
        "symbol": symbol,
        "action": "SELL" if "Crash" in symbol else "BUY",
        "reason": "Mock weak",
        "confidence": 70.0,
        "price": 0.0,
    }
    return jsonify(resp)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8502"))
    app.run(host="0.0.0.0", port=port)


