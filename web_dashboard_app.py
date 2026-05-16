#!/usr/bin/env python3
"""
TradBOT Web Dashboard - Real-time monitoring
FastAPI + WebSocket pour mise à jour en temps réel
"""

import asyncio
import json
import logging
import requests
from datetime import datetime
from typing import Dict, List
from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
import uvicorn

# Configuration
RENDER_API_URL = "https://kolatradebot-7ofl.onrender.com"
LOCAL_API_URL = "http://127.0.0.1:8000"

SYMBOLS = [
    "Boom 500 Index",
    "Crash 300 Index",
    "Step Index",
    "Volatility 100 Index"
]

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="TradBOT Dashboard")


class DashboardManager:
    def __init__(self):
        self.api_url = RENDER_API_URL
        self.metrics = {}
        self.health = {}
        self.active_connections = []

    async def fetch_health(self):
        """Récupère le statut du serveur"""
        try:
            response = requests.get(f"{self.api_url}/health", timeout=5)
            if response.status_code == 200:
                self.health = response.json()
                return True
        except Exception as e:
            logger.error(f"Health check error: {e}")
        return False

    async def fetch_ml_signal(self, symbol):
        """Récupère le signal ML pour un symbole"""
        try:
            response = requests.get(
                f"{self.api_url}/ml/signal",
                params={"symbol": symbol, "timeframe": "M1"},
                timeout=5
            )
            if response.status_code == 200:
                return response.json()
        except Exception as e:
            logger.warning(f"Error fetching signal for {symbol}: {e}")
        return None

    async def fetch_metrics(self, symbol):
        """Récupère les métriques pour un symbole"""
        try:
            response = requests.get(
                f"{self.api_url}/ml/metrics",
                params={"symbol": symbol, "timeframe": "M1"},
                timeout=5
            )
            if response.status_code == 200:
                return response.json()
        except Exception as e:
            logger.warning(f"Error fetching metrics for {symbol}: {e}")
        return None

    async def update_all_metrics(self):
        """Met à jour toutes les métriques"""
        await self.fetch_health()
        for symbol in SYMBOLS:
            signal = await self.fetch_ml_signal(symbol)
            metrics = await self.fetch_metrics(symbol)
            self.metrics[symbol] = {
                "signal": signal,
                "metrics": metrics,
                "timestamp": datetime.now().isoformat()
            }

    async def broadcast(self, message: dict):
        """Envoie un message à tous les clients WebSocket"""
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.error(f"Error broadcasting: {e}")


dashboard = DashboardManager()


@app.get("/", response_class=HTMLResponse)
async def get_dashboard():
    """Page HTML principale"""
    return """
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TradBOT Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Courier New', monospace;
            background: #0a0e27;
            color: #e0e0e0;
            line-height: 1.6;
        }

        header {
            background: linear-gradient(135deg, #1a1f3a 0%, #2d3561 100%);
            border-bottom: 2px solid #00ff88;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        header h1 {
            font-size: 24px;
            color: #00ff88;
        }

        .status-badge {
            padding: 8px 16px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
        }

        .status-online {
            background: #00aa00;
            color: #fff;
        }

        .status-offline {
            background: #aa0000;
            color: #fff;
        }

        .container {
            max-width: 1600px;
            margin: 0 auto;
            padding: 20px;
        }

        .health-section {
            background: #151829;
            border: 1px solid #333;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 10px;
        }

        .health-item {
            padding: 10px;
            background: #0a0e27;
            border-left: 3px solid #00ff88;
            border-radius: 4px;
        }

        .health-item label {
            color: #888;
            font-size: 11px;
            text-transform: uppercase;
            display: block;
        }

        .health-item value {
            color: #00ff88;
            font-size: 14px;
            font-weight: bold;
            display: block;
            margin-top: 5px;
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }

        .symbol-card {
            background: #151829;
            border: 1px solid #333;
            border-radius: 8px;
            overflow: hidden;
        }

        .symbol-header {
            background: #1a1f3a;
            border-bottom: 2px solid #00ff88;
            padding: 15px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .symbol-name {
            font-size: 16px;
            font-weight: bold;
            color: #00ff88;
        }

        .symbol-action {
            font-size: 12px;
            padding: 4px 12px;
            border-radius: 4px;
            font-weight: bold;
        }

        .action-buy {
            background: #00aa00;
            color: #fff;
        }

        .action-sell {
            background: #aa0000;
            color: #fff;
        }

        .action-hold {
            background: #aa8800;
            color: #fff;
        }

        .symbol-content {
            padding: 15px;
        }

        .metric-row {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #222;
            font-size: 12px;
        }

        .metric-row:last-child {
            border-bottom: none;
        }

        .metric-label {
            color: #888;
            text-transform: uppercase;
            flex: 1;
        }

        .metric-value {
            color: #00ff88;
            font-weight: bold;
            text-align: right;
            flex: 1;
        }

        .log-section {
            background: #151829;
            border: 1px solid #333;
            border-radius: 8px;
            padding: 15px;
            max-height: 400px;
            overflow-y: auto;
        }

        .log-entry {
            padding: 10px;
            background: #0a0e27;
            border-left: 3px solid #00ff88;
            margin-bottom: 8px;
            border-radius: 4px;
            font-size: 11px;
        }

        .log-time {
            color: #888;
        }

        .log-symbol {
            color: #00ff88;
            font-weight: bold;
        }

        .log-message {
            color: #e0e0e0;
            margin-top: 4px;
        }

        .loading {
            text-align: center;
            padding: 40px;
            color: #888;
        }

        .spinner {
            display: inline-block;
            width: 30px;
            height: 30px;
            border: 3px solid #333;
            border-top-color: #00ff88;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        @media (max-width: 1024px) {
            .metrics-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <header>
        <h1>🤖 TradBOT Dashboard</h1>
        <div class="status-badge status-online" id="status">● ONLINE</div>
    </header>

    <div class="container">
        <!-- Health Section -->
        <div class="health-section" id="health">
            <div class="health-item">
                <label>Version</label>
                <value>--</value>
            </div>
            <div class="health-item">
                <label>ML Trainer</label>
                <value>--</value>
            </div>
            <div class="health-item">
                <label>Last Update</label>
                <value id="last-update">--</value>
            </div>
        </div>

        <!-- Metrics Grid -->
        <div class="metrics-grid" id="metrics">
            <div class="loading">
                <div class="spinner"></div>
                <p>Chargement des données...</p>
            </div>
        </div>

        <!-- Log Section -->
        <div class="log-section">
            <div id="log" style="max-height: 350px; overflow-y: auto;"></div>
        </div>
    </div>

    <script>
        const ws = new WebSocket(`ws://${window.location.host}/ws`);
        const logEntries = [];
        const maxLogs = 50;

        ws.onopen = () => {
            console.log("Connected to dashboard");
            document.getElementById("status").textContent = "● ONLINE";
            document.getElementById("status").className = "status-badge status-online";
        };

        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);

            if (data.type === "health") {
                updateHealth(data);
            } else if (data.type === "metrics") {
                updateMetrics(data);
            } else if (data.type === "log") {
                addLog(data);
            }

            updateTimestamp();
        };

        ws.onerror = (error) => {
            console.error("WebSocket error:", error);
            document.getElementById("status").textContent = "● OFFLINE";
            document.getElementById("status").className = "status-badge status-offline";
        };

        function updateHealth(data) {
            const html = `
                <div class="health-item">
                    <label>Version</label>
                    <value>${data.version || "--"}</value>
                </div>
                <div class="health-item">
                    <label>ML Trainer</label>
                    <value>${data.ml_trainer ? "✓ Active" : "✗ Inactive"}</value>
                </div>
                <div class="health-item">
                    <label>Timestamp</label>
                    <value>${new Date().toLocaleTimeString()}</value>
                </div>
            `;
            document.getElementById("health").innerHTML = html;
        }

        function updateMetrics(data) {
            let metricsHtml = "";

            for (const symbol in data.metrics) {
                const m = data.metrics[symbol];
                const signal = m.signal || {};
                const metrics = m.metrics || {};

                const action = signal.action || "HOLD";
                const confidence = (signal.confidence || 0) * 100;
                const model = metrics.best_model || "N/A";
                const accuracy = metrics.accuracy || 0;

                const actionClass = `action-${action.toLowerCase()}`;

                metricsHtml += `
                    <div class="symbol-card">
                        <div class="symbol-header">
                            <div class="symbol-name">${symbol}</div>
                            <div class="symbol-action ${actionClass}">${action}</div>
                        </div>
                        <div class="symbol-content">
                            <div class="metric-row">
                                <span class="metric-label">Confidence</span>
                                <span class="metric-value">${confidence.toFixed(1)}%</span>
                            </div>
                            <div class="metric-row">
                                <span class="metric-label">Model</span>
                                <span class="metric-value">${model}</span>
                            </div>
                            <div class="metric-row">
                                <span class="metric-label">Accuracy</span>
                                <span class="metric-value">${accuracy.toFixed(1)}%</span>
                            </div>
                            <div class="metric-row">
                                <span class="metric-label">Spike Prediction</span>
                                <span class="metric-value">${signal.spike_prediction ? "YES" : "NO"}</span>
                            </div>
                            <div class="metric-row">
                                <span class="metric-label">Updated</span>
                                <span class="metric-value">${new Date(m.timestamp).toLocaleTimeString()}</span>
                            </div>
                        </div>
                    </div>
                `;
            }

            document.getElementById("metrics").innerHTML = metricsHtml || "<p>No data</p>";
        }

        function addLog(data) {
            const entry = document.createElement("div");
            entry.className = "log-entry";
            entry.innerHTML = `
                <span class="log-time">${new Date().toLocaleTimeString()}</span>
                <span class="log-symbol">[${data.symbol}]</span>
                <span class="log-message">${data.message}</span>
            `;

            const logDiv = document.getElementById("log");
            logDiv.insertBefore(entry, logDiv.firstChild);

            // Keep only last 50 entries
            while (logDiv.children.length > 50) {
                logDiv.removeChild(logDiv.lastChild);
            }
        }

        function updateTimestamp() {
            document.getElementById("last-update").textContent = new Date().toLocaleTimeString();
        }
    </script>
</body>
</html>
    """


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket pour mise à jour en temps réel"""
    await websocket.accept()
    dashboard.active_connections.append(websocket)

    try:
        # Boucle de mise à jour
        while True:
            # Récupérer et envoyer les données
            await dashboard.update_all_metrics()

            # Envoyer health
            await websocket.send_json({
                "type": "health",
                "version": dashboard.health.get("version", "N/A"),
                "ml_trainer": dashboard.health.get("ml_trainer_available", False)
            })

            # Envoyer metrics
            await websocket.send_json({
                "type": "metrics",
                "metrics": dashboard.metrics
            })

            # Log des mises à jour
            for symbol in SYMBOLS:
                signal = dashboard.metrics.get(symbol, {}).get("signal", {})
                if signal:
                    action = signal.get("action", "HOLD")
                    confidence = (signal.get("confidence", 0) * 100)
                    await websocket.send_json({
                        "type": "log",
                        "symbol": symbol,
                        "message": f"{action} ({confidence:.0f}%)"
                    })

            # Attendre 5 secondes avant la prochaine mise à jour
            await asyncio.sleep(5)

    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        dashboard.active_connections.remove(websocket)


@app.get("/api/health")
async def api_health():
    """API endpoint pour la santé du serveur"""
    await dashboard.fetch_health()
    return dashboard.health


@app.get("/api/metrics")
async def api_metrics():
    """API endpoint pour les métriques"""
    await dashboard.update_all_metrics()
    return dashboard.metrics


if __name__ == "__main__":
    print("""
    ╔════════════════════════════════════════╗
    ║  TradBOT Web Dashboard                 ║
    ║  Version 1.0                           ║
    ╠════════════════════════════════════════╣
    ║  📊 http://localhost:8080              ║
    ║  🔌 WebSocket: ws://localhost:8080/ws  ║
    ║  📡 Render: """ + RENDER_API_URL + """║
    ╚════════════════════════════════════════╝
    """)

    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8080,
        log_level="info"
    )
