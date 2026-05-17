#!/usr/bin/env python3
"""
TradBOT Web Dashboard - Real-time monitoring with WebSocket
"""
import asyncio
import json
import logging
import httpx
from datetime import datetime
from typing import Dict, Optional, Any
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import uvicorn

RENDER_API_URL = "https://kolatradebot-7ofl.onrender.com"
LOCAL_API_URL = "http://127.0.0.1:8000"

# Symboles TOUS les symboles Deriv du catalogue
DEFAULT_SYMBOLS = [
    '1HZ100V', '1HZ10V', '1HZ15V', '1HZ25V', '1HZ30V', '1HZ50V', '1HZ75V', '1HZ90V',
    'BOOM1000', 'BOOM150N', 'BOOM300N', 'BOOM50', 'BOOM500', 'BOOM600', 'BOOM900',
    'CRASH1000', 'CRASH150N', 'CRASH300N', 'CRASH50', 'CRASH500', 'CRASH600', 'CRASH900',
    'JD10', 'JD100', 'JD25', 'JD50', 'JD75',
    'OTC_AEX', 'OTC_AS51', 'OTC_DJI', 'OTC_FCHI', 'OTC_FTSE', 'OTC_GDAXI', 'OTC_HSI', 'OTC_N225', 'OTC_NDX', 'OTC_SPC', 'OTC_SSMI', 'OTC_SX5E',
    'RB100', 'RB200', 'RDBEAR', 'RDBULL',
    'R_10', 'R_100', 'R_25', 'R_50', 'R_75',
    'WLDAUD', 'WLDEUR', 'WLDGBP', 'WLDUSD', 'WLDXAU',
    'cryBTCUSD', 'cryETHUSD',
    'frxAUDCAD', 'frxAUDCHF', 'frxAUDJPY', 'frxAUDNZD', 'frxAUDUSD',
    'frxEURAUD', 'frxEURCAD', 'frxEURCHF', 'frxEURGBP', 'frxEURJPY', 'frxEURNZD', 'frxEURUSD',
    'frxGBPAUD', 'frxGBPCAD', 'frxGBPCHF', 'frxGBPJPY', 'frxGBPNOK', 'frxGBPNZD', 'frxGBPUSD',
    'frxNZDJPY', 'frxNZDUSD',
    'frxUSDCAD', 'frxUSDCHF', 'frxUSDJPY', 'frxUSDMXN', 'frxUSDNOK', 'frxUSDPLN', 'frxUSDSEK',
    'frxXAGUSD', 'frxXAUUSD', 'frxXPDUSD', 'frxXPTUSD',
    'stpRNG', 'stpRNG2', 'stpRNG3', 'stpRNG4', 'stpRNG5'
]

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="TradBOT Dashboard")

class Dashboard:
    def __init__(self):
        self.api_url = RENDER_API_URL
        self.local_url = LOCAL_API_URL
        self.metrics = {}
        self.health = {}
        self.active_connections = []
        self.symbols = DEFAULT_SYMBOLS.copy()

    async def fetch_json(self, url: str) -> Optional[Dict]:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(url)
                if response.status_code == 200:
                    return response.json()
        except Exception as e:
            logger.debug(f"Fetch error: {e}")
        return None

    async def fetch_health(self):
        health = await self.fetch_json(f"{self.api_url}/health")
        if health:
            self.health = health

    async def fetch_symbols(self):
        """Récupère la liste des symboles depuis l'API"""
        symbols_data = await self.fetch_json(f"{self.api_url}/symbols")
        if symbols_data and "symbols" in symbols_data:
            self.symbols = symbols_data["symbols"]
            logger.info(f"Symboles chargés: {len(self.symbols)} symboles")
            return self.symbols
        return []

    async def fetch_signal(self, symbol: str):
        return await self.fetch_json(f"{self.api_url}/ml/signal?symbol={symbol}&timeframe=M1")

    async def update_metrics(self):
        await self.fetch_health()

        # Charger les symboles s'ils ne sont pas encore disponibles
        if not self.symbols:
            await self.fetch_symbols()

        # Limiter à 50 symboles pour éviter surcharge
        symbols_to_fetch = self.symbols[:50] if self.symbols else []

        for symbol in symbols_to_fetch:
            signal = await self.fetch_signal(symbol)
            self.metrics[symbol] = {"signal": signal or {}, "timestamp": datetime.now().isoformat()}

dashboard = Dashboard()

@app.get("/", response_class=HTMLResponse)
async def get_dashboard():
    return """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>TradBOT Dashboard</title>
    <style>
        body { font-family: monospace; background: #0a0e27; color: #e0e0e0; margin: 0; padding: 20px; }
        header { border-bottom: 2px solid #00ff88; padding-bottom: 10px; margin-bottom: 20px; }
        h1 { color: #00ff88; margin: 0; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 20px; }
        .card { background: #151829; border: 1px solid #333; border-radius: 8px; padding: 15px; }
        .header { background: #1a1f3a; border-bottom: 2px solid #00ff88; padding: 10px; margin: -15px -15px 15px -15px; border-radius: 8px 8px 0 0; }
        .row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #222; font-size: 12px; }
        .label { color: #888; text-transform: uppercase; }
        .value { color: #00ff88; font-weight: bold; }
        .action-buy { background: #00aa00; color: #fff; padding: 4px 8px; border-radius: 3px; font-weight: bold; }
        .action-sell { background: #aa0000; color: #fff; padding: 4px 8px; border-radius: 3px; font-weight: bold; }
        .action-hold { background: #aa8800; color: #fff; padding: 4px 8px; border-radius: 3px; font-weight: bold; }
        #status { padding: 8px 16px; border-radius: 4px; background: #00aa00; color: #fff; font-weight: bold; }
    </style>
</head>
<body>
    <header>
        <h1>TradBOT Dashboard</h1>
        <div id="status">CONNECTING...</div>
    </header>
    <div class="grid" id="metrics"></div>
    <script>
        const ws = new WebSocket("ws://" + window.location.host + "/ws");

        ws.onopen = () => {
            console.log("WebSocket connected");
            document.getElementById("status").textContent = "ONLINE";
            document.getElementById("status").style.background = "#00aa00";
        };

        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === "metrics") {
                updateDisplay(data.metrics);
            }
        };

        ws.onerror = () => {
            document.getElementById("status").textContent = "ERROR";
            document.getElementById("status").style.background = "#aa0000";
        };

        function updateDisplay(metrics) {
            let html = "";
            for (const symbol in metrics) {
                const m = metrics[symbol];
                const signal = m.signal || {};
                const action = (signal.signal || "HOLD").toUpperCase();
                const conf = ((signal.confidence || 0) * 100).toFixed(0);
                const actionClass = "action-" + action.toLowerCase();

                html += `
                    <div class="card">
                        <div class="header" style="display: flex; justify-content: space-between;">
                            <span>${symbol}</span>
                            <span class="${actionClass}">${action}</span>
                        </div>
                        <div class="row">
                            <span class="label">Confidence</span>
                            <span class="value">${conf}%</span>
                        </div>
                        <div class="row">
                            <span class="label">Model</span>
                            <span class="value">${signal.model_used || "N/A"}</span>
                        </div>
                        <div class="row">
                            <span class="label">Reason</span>
                            <span class="value" style="font-size: 10px;">${(signal.reason || "N/A").substring(0, 40)}</span>
                        </div>
                    </div>
                `;
            }
            document.getElementById("metrics").innerHTML = html;
        }
    </script>
</body>
</html>
    """

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    dashboard.active_connections.append(websocket)
    logger.info(f"WebSocket client connected. Total: {len(dashboard.active_connections)}")

    try:
        while True:
            await dashboard.update_metrics()
            await websocket.send_json({
                "type": "metrics",
                "metrics": dashboard.metrics
            })
            await asyncio.sleep(3)
    except WebSocketDisconnect:
        dashboard.active_connections.remove(websocket)
        logger.info("WebSocket disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        if websocket in dashboard.active_connections:
            dashboard.active_connections.remove(websocket)

if __name__ == "__main__":
    print("Starting TradBOT Dashboard on http://127.0.0.1:8081")
    uvicorn.run(app, host="127.0.0.1", port=8081, log_level="info")
