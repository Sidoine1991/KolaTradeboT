#!/usr/bin/env python3
"""
Dashboard Web de monitoring pour le trading MT5 IA
Interface web simple avec Flask pour monitoring en temps réel
"""

import os
import sys
import time
import json
import logging
import requests
import MetaTrader5 as mt5
from datetime import datetime, timedelta
from flask import Flask, render_template_string, jsonify
import threading

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
SYMBOLS_TO_MONITOR = [
    "Boom 300 Index",
    "Boom 600 Index", 
    "Boom 900 Index",
    "Crash 1000 Index"
]

app = Flask(__name__)

# Variables globales
positions = {}
signals = {}
performance_data = {
    'total_profit': 0.0,
    'active_positions': 0,
    'active_signals': 0,
    'last_update': datetime.now().strftime('%H:%M:%S')
}

# Template HTML
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>🤖 TradBOT IA Dashboard</title>
    <meta charset="utf-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #1e1e1e;
            color: #ffffff;
            margin: 0;
            padding: 20px;
        }
        .header {
            text-align: center;
            color: #00bfff;
            font-size: 24px;
            margin-bottom: 30px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .symbols-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .symbol-card {
            background: #2d2d2d;
            border: 1px solid #444;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
        }
        .symbol-name {
            font-size: 18px;
            font-weight: bold;
            color: #00bfff;
            margin-bottom: 15px;
        }
        .signal {
            font-size: 16px;
            margin: 10px 0;
            padding: 5px;
            border-radius: 4px;
        }
        .signal-buy { background: #006400; color: #00ff00; }
        .signal-sell { background: #8b0000; color: #ff0000; }
        .signal-wait { background: #333; color: #808080; }
        .position {
            font-size: 14px;
            margin: 10px 0;
        }
        .position-active { color: #00ff00; }
        .position-none { color: #808080; }
        .performance {
            background: #2d2d2d;
            border: 1px solid #444;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            font-size: 18px;
        }
        .update-time {
            text-align: center;
            color: #808080;
            margin-top: 20px;
        }
        .refresh-btn {
            background: #00bfff;
            color: #1e1e1e;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            margin: 10px;
        }
        .refresh-btn:hover { background: #0080ff; }
    </style>
</head>
<body>
    <div class="header">
        🤖 TRADING IA DASHBOARD
    </div>
    
    <div class="container">
        <div class="symbols-grid">
            {% for symbol in symbols %}
            <div class="symbol-card">
                <div class="symbol-name">{{ symbol }}</div>
                <div id="signal-{{ symbol|replace(' ', '-') }}" class="signal signal-wait">
                    ⏳ EN ATTENTE
                </div>
                <div id="position-{{ symbol|replace(' ', '-') }}" class="position position-none">
                    📉 PAS DE POSITION
                </div>
                <div id="update-{{ symbol|replace(' ', '-') }}" style="color: #808080; font-size: 12px;">
                    ---
                </div>
            </div>
            {% endfor %}
        </div>
        
        <div class="performance">
            <div id="performance-text">📊 En attente des données...</div>
        </div>
        
        <div style="text-align: center; margin: 20px;">
            <button class="refresh-btn" onclick="location.reload()">🔄 ACTUALISER</button>
            <button class="refresh-btn" onclick="toggleAutoRefresh()">🔄 AUTO-REFRESH: <span id="auto-status">OFF</span></button>
        </div>
        
        <div class="update-time">
            Dernière mise à jour: <span id="last-update">---</span>
        </div>
    </div>

    <script>
        let autoRefresh = null;
        
        function updateData() {
            fetch('/api/data')
                .then(response => response.json())
                .then(data => {
                    // Mettre à jour les signaux
                    for (let symbol in data.signals) {
                        const signalId = 'signal-' + symbol.replace(/ /g, '-');
                        const signalEl = document.getElementById(signalId);
                        const signal = data.signals[symbol];
                        
                        if (signal.signal === 'BUY') {
                            signalEl.className = 'signal signal-buy';
                            signalEl.textContent = `📈 BUY ${signal.confidence.toFixed(0)}%`;
                        } else if (signal.signal === 'SELL') {
                            signalEl.className = 'signal signal-sell';
                            signalEl.textContent = `📉 SELL ${signal.confidence.toFixed(0)}%`;
                        } else {
                            signalEl.className = 'signal signal-wait';
                            signalEl.textContent = '⏳ EN ATTENTE';
                        }
                    }
                    
                    // Mettre à jour les positions
                    for (let symbol in data.positions) {
                        const posId = 'position-' + symbol.replace(/ /g, '-');
                        const posEl = document.getElementById(posId);
                        const pos = data.positions[symbol];
                        
                        if (pos.type !== 'NONE') {
                            posEl.className = 'position position-active';
                            const profitColor = pos.profit >= 0 ? '#00ff00' : '#ff0000';
                            posEl.innerHTML = `💼 ${pos.type} @ ${pos.price}<br>💰 P&L: <span style="color: ${profitColor}">${pos.profit >= 0 ? '+' : ''}${pos.profit.toFixed(2)}</span>`;
                        } else {
                            posEl.className = 'position position-none';
                            posEl.textContent = '📉 PAS DE POSITION';
                        }
                    }
                    
                    // Mettre à jour la performance
                    const perfEl = document.getElementById('performance-text');
                    perfEl.innerHTML = `📊 Positions: ${data.performance.active_positions} | 💰 P&L Total: ${data.performance.total_profit >= 0 ? '+' : ''}${data.performance.total_profit.toFixed(2)} | 🤖 Signaux: ${data.performance.active_signals}`;
                    
                    // Mettre à jour l'heure
                    document.getElementById('last-update').textContent = data.performance.last_update;
                })
                .catch(error => {
                    console.error('Erreur:', error);
                });
        }
        
        function toggleAutoRefresh() {
            const statusEl = document.getElementById('auto-status');
            if (autoRefresh) {
                clearInterval(autoRefresh);
                autoRefresh = null;
                statusEl.textContent = 'OFF';
                statusEl.style.color = '#ff0000';
            } else {
                autoRefresh = setInterval(updateData, 5000);
                statusEl.textContent = 'ON';
                statusEl.style.color = '#00ff00';
            }
        }
        
        // Charger les données initiales
        updateData();
        
        // Auto-refresh optionnel
        // toggleAutoRefresh();
    </script>
</body>
</html>
"""

def get_ai_signals():
    """Récupérer les signaux IA"""
    global signals
    try:
        for symbol in SYMBOLS_TO_MONITOR:
            url = f"{RENDER_API_URL}/predict/{symbol}"
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                signal_data = response.json()
                prediction = signal_data.get('prediction', {})
                direction = prediction.get('direction', 'HOLD')
                confidence = prediction.get('confidence', 0) * 100
                
                if direction.upper() == 'UP':
                    signals[symbol] = {'signal': 'BUY', 'confidence': confidence}
                elif direction.upper() == 'DOWN':
                    signals[symbol] = {'signal': 'SELL', 'confidence': confidence}
                else:
                    signals[symbol] = {'signal': 'WAIT', 'confidence': 0}
            else:
                signals[symbol] = {'signal': 'ERROR', 'confidence': 0}
                
    except Exception as e:
        print(f"Erreur获取信号: {e}")

def get_mt5_positions():
    """Récupérer les positions MT5"""
    global positions
    try:
        if not mt5.initialize():
            return
        
        positions_data = mt5.positions_get()
        if positions_data:
            for pos in positions_data:
                if pos.symbol in SYMBOLS_TO_MONITOR:
                    positions[pos.symbol] = {
                        'type': 'BUY' if pos.type == mt5.POSITION_TYPE_BUY else 'SELL',
                        'price': pos.price_open,
                        'profit': pos.profit,
                        'ticket': pos.ticket
                    }
        
        # Nettoyer les positions fermées
        current_symbols = set()
        if positions_data:
            current_symbols = {pos.symbol for pos in positions_data if pos.symbol in SYMBOLS_TO_MONITOR}
        
        for symbol in list(positions.keys()):
            if symbol not in current_symbols:
                positions[symbol] = {'type': 'NONE', 'price': 0, 'profit': 0, 'ticket': 0}
                    
        mt5.shutdown()
        
    except Exception as e:
        print(f"Erreur获取MT5仓位: {e}")

def update_performance():
    """Mettre à jour les données de performance"""
    global performance_data
    
    total_profit = sum(pos.get('profit', 0) for pos in positions.values())
    active_positions = len([pos for pos in positions.values() if pos.get('type') != 'NONE'])
    active_signals = len([sig for sig in signals.values() if sig.get('signal') not in ['WAIT', 'ERROR']])
    
    performance_data = {
        'total_profit': total_profit,
        'active_positions': active_positions,
        'active_signals': active_signals,
        'last_update': datetime.now().strftime('%H:%M:%S')
    }

def update_data():
    """Fonction de mise à jour en arrière-plan"""
    while True:
        try:
            get_ai_signals()
            get_mt5_positions()
            update_performance()
            time.sleep(5)
        except Exception as e:
            print(f"Erreur de mise à jour: {e}")
            time.sleep(10)

@app.route('/')
def index():
    """Page principale du dashboard"""
    return render_template_string(HTML_TEMPLATE, symbols=SYMBOLS_TO_MONITOR)

@app.route('/api/data')
def api_data():
    """API endpoint pour les données du dashboard"""
    return jsonify({
        'signals': signals,
        'positions': positions,
        'performance': performance_data
    })

if __name__ == '__main__':
    print("🚀 Démarrage du Web Dashboard...")
    print("📊 Accès: http://localhost:5000")
    print("🔄 Mise à jour automatique toutes les 5 secondes")
    print("❌ Ctrl+C pour arrêter")
    print("")
    
    # Démarrer le thread de mise à jour
    update_thread = threading.Thread(target=update_data, daemon=True)
    update_thread.start()
    
    # Démarrer le serveur web
    app.run(host='0.0.0.0', port=5000, debug=False)
