#!/usr/bin/env python3
"""
TradBOT Web Dashboard - Real-time monitoring with full ML metrics
FastAPI + WebSocket for real-time updates
Enhanced with predictions, confidence scores, and trading opportunities
"""

import asyncio
import json
import logging
import requests
from datetime import datetime
from typing import Dict, List, Optional, Any
from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
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

app = FastAPI(title="TradBOT Dashboard - ML Enhanced")

# Add CORS middleware (without credentials for wildcard origin compatibility)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class DashboardManager:
    def __init__(self):
        self.api_url = RENDER_API_URL
        self.local_url = LOCAL_API_URL
        self.metrics = {}
        self.predictions = {}
        self.health = {}
        self.active_connections = []

    async def fetch_json(self, url: str, timeout: float = 5.0) -> Optional[Dict]:
        """Safely fetch JSON from endpoint"""
        try:
            response = requests.get(url, timeout=timeout)
            if response.status_code == 200:
                return response.json()
        except Exception as e:
            logger.debug(f"Fetch error for {url}: {e}")
        return None

    async def fetch_health(self):
        """Get server status"""
        health = await self.fetch_json(f"{self.api_url}/health")
        if health:
            self.health = health
            return True
        return False

    async def fetch_ml_signal(self, symbol: str) -> Optional[Dict]:
        """Get ML trading signal"""
        return await self.fetch_json(
            f"{self.api_url}/ml/signal",
            timeout=3.0
        )

    async def fetch_prediction(self, symbol: str) -> Optional[Dict]:
        """Get future price predictions"""
        return await self.fetch_json(
            f"{self.api_url}/predict/{symbol}",
            timeout=3.0
        )

    async def fetch_prediction_channel(self, symbol: str) -> Optional[Dict]:
        """Get prediction channels (upper/lower bands)"""
        return await self.fetch_json(
            f"{self.api_url}/prediction-channel?symbol={symbol}",
            timeout=3.0
        )

    async def fetch_spike_detection(self, symbol: str) -> Optional[Dict]:
        """Get spike detection and timing"""
        return await self.fetch_json(
            f"{self.api_url}/angelofspike/trend?symbol={symbol}",
            timeout=3.0
        )

    async def fetch_coherent_analysis(self, symbol: str) -> Optional[Dict]:
        """Get multi-timeframe coherence analysis"""
        return await self.fetch_json(
            f"{self.api_url}/coherent-analysis?symbol={symbol}",
            timeout=3.0
        )

    async def fetch_opportunities(self) -> Optional[Dict]:
        """Get top opportunities across all symbols"""
        return await self.fetch_json(
            f"{self.api_url}/ml/opportunities",
            timeout=3.0
        )

    async def fetch_propice_symbols(self) -> Optional[Dict]:
        """Get top 'propice' symbols by performance at current hour"""
        return await self.fetch_json(
            f"{self.api_url}/symbols/propice/top",
            timeout=3.0
        )

    async def update_all_metrics(self):
        """Update all metrics for all symbols"""
        await self.fetch_health()

        for symbol in SYMBOLS:
            try:
                # Fetch basic signal
                signal = await self.fetch_ml_signal(symbol)

                # Fetch predictions
                prediction = await self.fetch_prediction(symbol)
                channel = await self.fetch_prediction_channel(symbol)
                spike = await self.fetch_spike_detection(symbol)
                coherence = await self.fetch_coherent_analysis(symbol)

                self.metrics[symbol] = {
                    "signal": signal or {},
                    "prediction": prediction or {},
                    "channel": channel or {},
                    "spike": spike or {},
                    "coherence": coherence or {},
                    "timestamp": datetime.now().isoformat()
                }
            except Exception as e:
                logger.warning(f"Error updating metrics for {symbol}: {e}")
                self.metrics[symbol] = {
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                }

        # Fetch global opportunities and propice symbols
        try:
            self.predictions["opportunities"] = await self.fetch_opportunities() or {}
            self.predictions["propice"] = await self.fetch_propice_symbols() or {}
        except Exception as e:
            logger.warning(f"Error fetching global data: {e}")

    async def broadcast(self, message: dict):
        """Send message to all connected WebSocket clients"""
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.debug(f"Error broadcasting: {e}")


dashboard = DashboardManager()


@app.get("/", response_class=HTMLResponse)
async def get_dashboard():
    """Main dashboard HTML page"""
    return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TradBOT Dashboard - ML Enhanced</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Courier New', monospace;
            background: linear-gradient(135deg, #0a0e27 0%, #1a1f3a 100%);
            color: #e0e0e0;
            line-height: 1.6;
        }

        header {
            background: linear-gradient(135deg, #1a1f3a 0%, #2d3561 100%);
            border-bottom: 3px solid #00ff88;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        header h1 {
            font-size: 24px;
            color: #00ff88;
            text-shadow: 0 0 10px rgba(0, 255, 136, 0.3);
        }

        .status-badge {
            padding: 8px 16px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            letter-spacing: 1px;
        }

        .status-online {
            background: #00aa00;
            color: #fff;
            box-shadow: 0 0 10px rgba(0, 170, 0, 0.5);
        }

        .status-offline {
            background: #aa0000;
            color: #fff;
        }

        .container {
            max-width: 1920px;
            margin: 0 auto;
            padding: 20px;
        }

        .section-title {
            font-size: 16px;
            color: #00ff88;
            text-transform: uppercase;
            letter-spacing: 2px;
            margin-top: 30px;
            margin-bottom: 15px;
            border-bottom: 1px solid #00ff88;
            padding-bottom: 10px;
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
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
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

        .metric-sub {
            display: flex;
            justify-content: space-between;
            padding: 4px 0 4px 20px;
            border-bottom: 1px solid #222;
            font-size: 11px;
        }

        .metric-sub-label {
            color: #666;
            flex: 1;
        }

        .metric-sub-value {
            color: #00dd77;
            font-weight: bold;
            text-align: right;
            flex: 1;
        }

        .opportunities-section {
            background: #151829;
            border: 1px solid #333;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
        }

        .opp-item {
            padding: 10px;
            background: #0a0e27;
            margin-bottom: 8px;
            border-left: 3px solid #00dd77;
            border-radius: 4px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .opp-symbol {
            color: #00ff88;
            font-weight: bold;
        }

        .opp-score {
            color: #00dd77;
            font-size: 12px;
        }

        .log-section {
            background: #151829;
            border: 1px solid #333;
            border-radius: 8px;
            padding: 15px;
            max-height: 300px;
            overflow-y: auto;
        }

        .log-entry {
            padding: 8px;
            background: #0a0e27;
            border-left: 3px solid #00ff88;
            margin-bottom: 6px;
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
            margin-top: 2px;
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

        .warning-badge {
            color: #ffaa00;
            font-size: 11px;
            background: rgba(255, 170, 0, 0.1);
            padding: 4px 8px;
            border-radius: 3px;
            border-left: 2px solid #ffaa00;
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
        <h1>🤖 TradBOT Dashboard - ML Enhanced</h1>
        <div class="status-badge status-online" id="status">● ONLINE</div>
    </header>

    <div class="container">
        <!-- Health Section -->
        <div class="health-section" id="health">
            <div class="health-item">
                <label>Server Status</label>
                <value>Loading...</value>
            </div>
            <div class="health-item">
                <label>Last Update</label>
                <value id="last-update">--</value>
            </div>
        </div>

        <!-- Opportunities Section -->
        <div class="section-title">🎯 Top Opportunities</div>
        <div class="opportunities-section" id="opportunities">
            <div class="loading">
                <div class="spinner"></div>
                <p>Loading opportunities...</p>
            </div>
        </div>

        <!-- Metrics Grid -->
        <div class="section-title">📊 Symbol Metrics & Predictions</div>
        <div class="metrics-grid" id="metrics">
            <div class="loading">
                <div class="spinner"></div>
                <p>Loading metrics...</p>
            </div>
        </div>

        <!-- Live Log -->
        <div class="section-title">📝 Live Activity Log</div>
        <div class="log-section">
            <div id="log" style="max-height: 300px; overflow-y: auto;"></div>
        </div>
    </div>

    <script>
        const ws = new WebSocket(`ws://${window.location.host}/ws`);
        const logEntries = [];
        const maxLogs = 100;

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
            } else if (data.type === "opportunities") {
                updateOpportunities(data);
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
                    <label>Server Status</label>
                    <value>${data.version ? "✓ ONLINE" : "✗ OFFLINE"}</value>
                </div>
                <div class="health-item">
                    <label>ML Trainer</label>
                    <value>${data.ml_trainer ? "✓ Active" : "✗ Inactive"}</value>
                </div>
                <div class="health-item">
                    <label>Database</label>
                    <value>${data.db_available ? "✓ Connected" : "✗ Failed"}</value>
                </div>
                <div class="health-item">
                    <label>Version</label>
                    <value>${data.version || "--"}</value>
                </div>
            `;
            document.getElementById("health").innerHTML = html;
        }

        function updateOpportunities(data) {
            const opps = data.opportunities || [];
            if (opps.length === 0) {
                document.getElementById("opportunities").innerHTML =
                    "<p style='color: #888; padding: 20px;'>No opportunities at this time</p>";
                return;
            }

            let html = "";
            opps.slice(0, 5).forEach(opp => {
                const score = opp.score ? (opp.score * 100).toFixed(0) : "N/A";
                html += `
                    <div class="opp-item">
                        <div>
                            <span class="opp-symbol">${opp.symbol}</span>
                            <span class="opp-score">${opp.action || "HOLD"}</span>
                        </div>
                        <div class="opp-score">${score}%</div>
                    </div>
                `;
            });

            document.getElementById("opportunities").innerHTML = html;
        }

        function updateMetrics(data) {
            let metricsHtml = "";

            for (const symbol in data.metrics) {
                const m = data.metrics[symbol];
                const signal = m.signal || {};
                const prediction = m.prediction || {};
                const channel = m.channel || {};
                const spike = m.spike || {};
                const coherence = m.coherence || {};

                const action = signal.action || "HOLD";
                const confidence = (signal.confidence || 0) * 100;
                const model = signal.model_used || "N/A";

                const predicted_price = prediction.next_target ? prediction.next_target.toFixed(2) : "N/A";
                const predicted_direction = prediction.trend_direction || "NEUTRAL";
                const pred_confidence = (prediction.confidence || 0) * 100;
                const spike_prob = (prediction.spike_probability || 0) * 100;

                const channel_upper = channel.upper_band ? channel.upper_band.toFixed(2) : "N/A";
                const channel_lower = channel.lower_band ? channel.lower_band.toFixed(2) : "N/A";

                const spike_eta = spike.eta_seconds ? `${spike.eta_seconds}s` : "N/A";
                const spike_imminent = spike.spike_imminent ? "YES" : "NO";

                const coherence_score = (coherence.coherence_score || 0) * 100;
                const mtf_alignment = coherence.mtf_alignment || "NEUTRAL";

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
                                <span class="metric-value">${confidence.toFixed(0)}%</span>
                            </div>
                            <div class="metric-row">
                                <span class="metric-label">Model</span>
                                <span class="metric-value">${model}</span>
                            </div>

                            <div class="metric-row">
                                <span class="metric-label">Predicted Price</span>
                                <span class="metric-value">${predicted_price}</span>
                            </div>
                            <div class="metric-sub">
                                <span class="metric-sub-label">Direction</span>
                                <span class="metric-sub-value">${predicted_direction}</span>
                            </div>
                            <div class="metric-sub">
                                <span class="metric-sub-label">Pred Confidence</span>
                                <span class="metric-sub-value">${pred_confidence.toFixed(0)}%</span>
                            </div>

                            <div class="metric-row">
                                <span class="metric-label">Channel Band</span>
                                <span class="metric-value">[${channel_lower}-${channel_upper}]</span>
                            </div>

                            <div class="metric-row">
                                <span class="metric-label">Spike Detection</span>
                                <span class="metric-value">${spike_imminent}</span>
                            </div>
                            <div class="metric-sub">
                                <span class="metric-sub-label">ETA / Probability</span>
                                <span class="metric-sub-value">${spike_eta} / ${spike_prob.toFixed(0)}%</span>
                            </div>

                            <div class="metric-row">
                                <span class="metric-label">MTF Coherence</span>
                                <span class="metric-value">${coherence_score.toFixed(0)}%</span>
                            </div>
                            <div class="metric-sub">
                                <span class="metric-sub-label">Alignment</span>
                                <span class="metric-sub-value">${mtf_alignment}</span>
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

            while (logDiv.children.length > maxLogs) {
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
async def websocket_endpoint(websocket):
    """WebSocket endpoint for real-time updates"""
    await websocket.accept()
    dashboard.active_connections.append(websocket)

    try:
        while True:
            # Update all metrics
            await dashboard.update_all_metrics()

            # Send health
            await websocket.send_json({
                "type": "health",
                "version": dashboard.health.get("version", "N/A"),
                "ml_trainer": dashboard.health.get("ml_trainer_available", False),
                "db_available": dashboard.health.get("db_available", False),
            })

            # Send metrics
            await websocket.send_json({
                "type": "metrics",
                "metrics": dashboard.metrics
            })

            # Send opportunities
            await websocket.send_json({
                "type": "opportunities",
                "opportunities": dashboard.predictions.get("opportunities", {}).get("opportunities", [])
            })

            # Log updates
            for symbol in SYMBOLS:
                signal = dashboard.metrics.get(symbol, {}).get("signal", {})
                if signal:
                    action = signal.get("action", "HOLD")
                    confidence = (signal.get("confidence", 0) * 100)
                    await websocket.send_json({
                        "type": "log",
                        "symbol": symbol,
                        "message": f"{action} ({confidence:.0f}%) - Conf: {signal.get('reasoning', 'N/A')[:50]}"
                    })

            # Wait before next update (3 seconds for real-time feel)
            await asyncio.sleep(3)

    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        dashboard.active_connections.remove(websocket)


@app.get("/api/health")
async def api_health():
    """Health check endpoint"""
    await dashboard.fetch_health()
    return dashboard.health


@app.get("/api/metrics")
async def api_metrics():
    """Get all metrics"""
    await dashboard.update_all_metrics()
    return dashboard.metrics


if __name__ == "__main__":
    print("""
    ╔═══════════════════════════════════════════════════════╗
    ║  TradBOT Web Dashboard - ML Enhanced                  ║
    ║  Version 2.0                                          ║
    ╠═══════════════════════════════════════════════════════╣
    ║  📊 http://localhost:8080                             ║
    ║  🔌 WebSocket: ws://localhost:8080/ws                ║
    ║  📡 Backend: https://kolatradebot-7ofl.onrender.com  ║
    ║                                                       ║
    ║  Features:                                            ║
    ║  ✓ Real-time ML signals                              ║
    ║  ✓ Price predictions & channels                      ║
    ║  ✓ Spike detection with ETA                          ║
    ║  ✓ Multi-timeframe coherence                         ║
    ║  ✓ Top opportunities ranking                         ║
    ║  ✓ Live activity log                                 ║
    ╚═══════════════════════════════════════════════════════╝
    """)

    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8080,
        log_level="info"
    )

