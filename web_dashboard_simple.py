#!/usr/bin/env python3
"""
TradBOT Web Dashboard - SIMPLE VERSION (polling instead of WebSocket)
No WebSocket = no 403 errors
"""

import asyncio
import json
import logging
import requests
from datetime import datetime
from typing import Dict, List, Optional, Any
from fastapi import FastAPI
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

app = FastAPI(title="TradBOT Dashboard - Simple")


class DashboardManager:
    def __init__(self):
        self.api_url = RENDER_API_URL
        self.local_url = LOCAL_API_URL
        self.metrics = {}
        self.predictions = {}
        self.health = {}

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

    async def update_all_metrics(self):
        """Update all metrics for all symbols"""
        await self.fetch_health()

        for symbol in SYMBOLS:
            try:
                # Fetch basic signal
                signal = await self.fetch_ml_signal(symbol)

                self.metrics[symbol] = {
                    "signal": signal or {},
                    "timestamp": datetime.now().isoformat()
                }
            except Exception as e:
                logger.warning(f"Error updating metrics for {symbol}: {e}")
                self.metrics[symbol] = {
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                }


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
    <title>TradBOT Dashboard - Simple</title>
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
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
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

        .refresh-info {
            text-align: center;
            color: #888;
            font-size: 12px;
            padding: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <header>
        <h1>🤖 TradBOT Dashboard - Simple</h1>
        <div class="status-badge status-online" id="status">● ONLINE</div>
    </header>

    <div class="container">
        <div class="metrics-grid" id="metrics">
            <div class="loading">
                <div class="spinner"></div>
                <p>Loading metrics...</p>
            </div>
        </div>
        <div class="refresh-info">
            Auto-refreshing every 5 seconds...
        </div>
    </div>

    <script>
        async function updateDashboard() {
            try {
                const response = await fetch('/api/metrics');
                const data = await response.json();

                if (!data || Object.keys(data).length === 0) {
                    document.getElementById('metrics').innerHTML =
                        '<p style="color: #888; grid-column: 1/-1; padding: 20px;">No data available</p>';
                    return;
                }

                let html = '';
                for (const symbol in data) {
                    const m = data[symbol];
                    const signal = m.signal || {};

                    const action = signal.action || "HOLD";
                    const confidence = (signal.confidence || 0) * 100;
                    const model = signal.model_used || "N/A";

                    const actionClass = `action-${action.toLowerCase()}`;

                    html += `
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
                                    <span class="metric-label">Reasoning</span>
                                    <span class="metric-value" style="font-size: 10px;">${(signal.reason || 'N/A').substring(0, 30)}</span>
                                </div>
                                <div class="metric-row">
                                    <span class="metric-label">Updated</span>
                                    <span class="metric-value">${new Date(m.timestamp).toLocaleTimeString()}</span>
                                </div>
                            </div>
                        </div>
                    `;
                }

                document.getElementById('metrics').innerHTML = html;
            } catch (error) {
                console.error('Error:', error);
                document.getElementById('status').textContent = '● OFFLINE';
                document.getElementById('status').className = 'status-badge status-offline';
            }
        }

        // Initial load
        updateDashboard();

        // Refresh every 5 seconds
        setInterval(updateDashboard, 5000);
    </script>
</body>
</html>
    """


@app.get("/api/metrics")
async def api_metrics():
    """Get all metrics (polling endpoint)"""
    await dashboard.update_all_metrics()
    return dashboard.metrics


@app.get("/api/health")
async def api_health():
    """Health check endpoint"""
    await dashboard.fetch_health()
    return dashboard.health


if __name__ == "__main__":
    print("""
    ╔═══════════════════════════════════════════════════════╗
    ║  TradBOT Web Dashboard - SIMPLE (Polling)             ║
    ║  No WebSocket = No 403 errors                         ║
    ╠═══════════════════════════════════════════════════════╣
    ║  📊 http://localhost:8080                             ║
    ║  📡 Backend: https://kolatradebot-7ofl.onrender.com  ║
    ║                                                       ║
    ║  Using HTTP polling (5 sec refresh)                  ║
    ║  No WebSocket complications                           ║
    ╚═══════════════════════════════════════════════════════╝
    """)

    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8080,
        log_level="info"
    )

