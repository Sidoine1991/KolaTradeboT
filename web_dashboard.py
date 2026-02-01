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
from flask import Flask, render_template_string, jsonify, request
import threading
from collections import deque

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
# Liste étendue de symboles à surveiller
SYMBOLS_TO_MONITOR = [
    "Boom 300 Index", "Boom 500 Index", "Boom 1000 Index",
    "Crash 300 Index", "Crash 500 Index", "Crash 1000 Index",
    "Volatility 10 Index", "Volatility 25 Index", "Volatility 50 Index", "Volatility 75 Index", "Volatility 100 Index",
    "Jump 25 Index", "Jump 50 Index", "Jump 75 Index", "Jump 100 Index",
    "XAUUSD", "EURUSD"
]

app = Flask(__name__)

# --- Structures de données en mémoire centralisées ---
global_data = {
    "positions": {},
    "signals": {},
    "trade_history": deque(maxlen=200),  # Historique des 200 derniers trades
    "daily_stats": {},
    "symbol_performance": {},
    "ml_metrics": {},
    "performance": {},
    "last_sync_time": 0,
    "data_source": "N/A"
}

# Template HTML
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>🤖 TradBOT IA Dashboard</title>
    <meta charset="utf-8">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #121212; color: #e0e0e0; margin: 0; padding: 20px; }
        .header { text-align: center; color: #1e90ff; font-size: 28px; margin-bottom: 20px; font-weight: bold; }
        .container { max-width: 1600px; margin: 0 auto; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px; }
        .card { background: #1e1e1e; border: 1px solid #333; border-radius: 10px; padding: 20px; box-shadow: 0 4px 8px rgba(0,0,0,0.2); }
        .card-title { font-size: 20px; font-weight: bold; color: #1e90ff; margin-bottom: 15px; border-bottom: 1px solid #333; padding-bottom: 10px; }
        .position-card { background: #2a2a2a; border-radius: 8px; padding: 15px; }
        .profit { color: #32cd32; }
        .loss { color: #ff4500; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; }
        .stat-item { background: #2a2a2a; padding: 10px; border-radius: 5px; text-align: center; }
        .stat-label { color: #aaa; font-size: 14px; }
        .stat-value { font-size: 18px; font-weight: bold; }
        #trade-history-table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        #trade-history-table th, #trade-history-table td { padding: 8px 12px; border-bottom: 1px solid #333; text-align: left; font-size: 14px; }
        #trade-history-table th { background: #2a2a2a; }
        .pagination { text-align: center; margin-top: 15px; }
        .pagination button { background: #1e90ff; color: white; border: none; padding: 8px 15px; border-radius: 5px; cursor: pointer; margin: 0 5px; }
        .pagination button:disabled { background: #555; cursor: not-allowed; }
        .footer { text-align: center; color: #808080; margin-top: 30px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="header">TRADING IA DASHBOARD</div>
    <div class="container">
        <div class="grid">
            <!-- Colonne de gauche: Positions et Stats -->
            <div style="display: flex; flex-direction: column; gap: 20px;">
                <div class="card">
                    <div class="card-title">Statistiques du Jour</div>
                    <div id="daily-stats-content" class="stats-grid"></div>
                </div>
                <div class="card">
                    <div class="card-title">Positions Ouvertes</div>
                    <div id="open-positions-grid" class="grid"></div>
                </div>
            </div>
            <!-- Colonne de droite: Graphiques et Performance -->
            <div style="display: flex; flex-direction: column; gap: 20px;">
                <div class="card">
                    <div class="card-title">Profit Journalier</div>
                    <canvas id="profit-chart"></canvas>
                </div>
                <div class="card">
                    <div class="card-title">Performance par Symbole</div>
                    <div style="display: flex; gap: 20px;">
                        <div style="flex: 1;">
                            <h4 style="color: #32cd32;">Top 5 Gagnants</h4>
                            <ul id="best-symbols"></ul>
                        </div>
                        <div style="flex: 1;">
                            <h4 style="color: #ff4500;">Top 5 Perdants</h4>
                            <ul id="worst-symbols"></ul>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Historique des Trades -->
        <div class="card" style="margin-top: 20px;">
            <div class="card-title">Historique des Trades</div>
            <table id="trade-history-table">
                <thead><tr><th>Heure</th><th>Symbole</th><th>Type</th><th>Prix Entrée</th><th>Prix Sortie</th><th>Profit</th><th>Raison</th></tr></thead>
                <tbody></tbody>
            </table>
            <div class="pagination">
                <button id="prev-page">Précédent</button>
                <span id="page-info"></span>
                <button id="next-page">Suivant</button>
            </div>
        </div>
        <div class="footer">
            Dernière synchro: <span id="last-sync">N/A</span> | Source: <span id="data-source">N/A</span>
        </div>
    </div>

    <script>
        let profitChart;
        let tradeHistory = [];
        let currentPage = 1;
        const rowsPerPage = 10;

        function formatCurrency(value) {
            const color = value >= 0 ? 'profit' : 'loss';
            return `<span class="${color}">${value.toFixed(2)} $</span>`;
        }

        function renderDashboard(data) {
            // Stats du jour
            const statsEl = document.getElementById('daily-stats-content');
            if (data.daily_stats) {
                const stats = data.daily_stats;
                statsEl.innerHTML = `
                    <div class="stat-item"><div class="stat-label">Trades</div><div class="stat-value">${stats.total_trades}</div></div>
                    <div class="stat-item"><div class="stat-label">Taux de Succès</div><div class="stat-value">${stats.win_rate.toFixed(1)}%</div></div>
                    <div class="stat-item"><div class="stat-label">Profit Total</div><div class="stat-value">${formatCurrency(stats.total_profit)}</div></div>
                    <div class="stat-item"><div class="stat-label">Profit Factor</div><div class="stat-value">${stats.profit_factor.toFixed(2)}</div></div>
                `;
            }

            // Positions ouvertes
            const posGrid = document.getElementById('open-positions-grid');
            posGrid.innerHTML = '';
            if (Object.keys(data.positions).length > 0) {
                for (const symbol in data.positions) {
                    const pos = data.positions[symbol];
                    posGrid.innerHTML += `
                        <div class="position-card">
                            <strong>${symbol}</strong> (${pos.type})
                            <div>Profit: ${formatCurrency(pos.profit)}</div>
                            <small>@ ${pos.price_open}</small>
                        </div>
                    `;
                }
            } else {
                posGrid.innerHTML = '<p>Aucune position ouverte.</p>';
            }

            // Performance par symbole
            const bestSymbolsEl = document.getElementById('best-symbols');
            const worstSymbolsEl = document.getElementById('worst-symbols');
            bestSymbolsEl.innerHTML = '';
            worstSymbolsEl.innerHTML = '';
            if (data.symbol_performance) {
                data.symbol_performance.best.forEach(s => { bestSymbolsEl.innerHTML += `<li>${s.symbol}: ${formatCurrency(s.profit)}</li>`; });
                data.symbol_performance.worst.forEach(s => { worstSymbolsEl.innerHTML += `<li>${s.symbol}: ${formatCurrency(s.profit)}</li>`; });
            }

            // Historique des trades
            tradeHistory = data.trade_history || [];
            renderTradeHistory();

            // Mise à jour du graphique
            updateProfitChart(data.daily_stats.profit_history || []);
            
            // Footer
            document.getElementById('last-sync').textContent = data.last_sync_time;
            document.getElementById('data-source').textContent = data.data_source;
        }

        function renderTradeHistory() {
            const tableBody = document.querySelector('#trade-history-table tbody');
            tableBody.innerHTML = '';
            const start = (currentPage - 1) * rowsPerPage;
            const end = start + rowsPerPage;
            const paginatedItems = tradeHistory.slice(start, end);

            for (const trade of paginatedItems) {
                tableBody.innerHTML += `
                    <tr>
                        <td>${trade.close_time}</td>
                        <td>${trade.symbol}</td>
                        <td>${trade.type}</td>
                        <td>${trade.price_open}</td>
                        <td>${trade.price_close}</td>
                        <td>${formatCurrency(trade.profit)}</td>
                        <td>${trade.reason}</td>
                    </tr>
                `;
            }
            document.getElementById('page-info').textContent = `Page ${currentPage} sur ${Math.ceil(tradeHistory.length / rowsPerPage)}`;
            document.getElementById('prev-page').disabled = currentPage === 1;
            document.getElementById('next-page').disabled = currentPage * rowsPerPage >= tradeHistory.length;
        }

        function updateProfitChart(profitHistory) {
            const ctx = document.getElementById('profit-chart').getContext('2d');
            const labels = profitHistory.map(p => p.time);
            const data = profitHistory.map(p => p.profit);

            if (profitChart) {
                profitChart.data.labels = labels;
                profitChart.data.datasets[0].data = data;
                profitChart.update();
            } else {
                profitChart = new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels: labels,
                        datasets: [{
                            label: 'Profit Cumulé',
                            data: data,
                            borderColor: '#1e90ff',
                            backgroundColor: 'rgba(30, 144, 255, 0.2)',
                            fill: true,
                            tension: 0.3
                        }]
                    },
                    options: {
                        responsive: true,
                        scales: { x: { ticks: { color: '#aaa' } }, y: { ticks: { color: '#aaa' } } },
                        plugins: { legend: { display: false } }
                    }
                });
            }
        }

        function fetchData() {
            fetch('/api/data')
                .then(response => response.json())
                .then(data => renderDashboard(data))
                .catch(error => console.error('Erreur de fetch:', error));
        }

        // Pagination
        document.getElementById('prev-page').addEventListener('click', () => { if (currentPage > 1) { currentPage--; renderTradeHistory(); } });
        document.getElementById('next-page').addEventListener('click', () => { if (currentPage * rowsPerPage < tradeHistory.length) { currentPage++; renderTradeHistory(); } });

        // Initial load and refresh
        fetchData();
        setInterval(fetchData, 5000); // Refresh toutes les 5 secondes
    </script>
</body>
</html>
"""

def process_data_and_update_stats(data):
    """Traiter les données reçues et mettre à jour toutes les statistiques."""
    global global_data

    # Mettre à jour les données de base
    global_data['positions'] = data.get('positions', {})
    global_data['signals'] = data.get('signals', {})
    global_data['ml_metrics'] = data.get('ml_metrics', {})
    global_data['performance'] = data.get('performance', {})
    global_data['last_sync_time'] = datetime.now().strftime('%H:%M:%S')
    global_data['data_source'] = 'robot'

    # Mettre à jour l'historique des trades
    new_history = data.get('trade_history', [])
    if new_history:
        # Utiliser un set pour un accès rapide aux tickets existants
        existing_tickets = {trade['ticket'] for trade in global_data['trade_history']}
        for trade in new_history:
            if trade['ticket'] not in existing_tickets:
                global_data['trade_history'].appendleft(trade) # Ajouter au début

    # Calculer les statistiques journalières
    today_str = datetime.now().strftime('%Y-%m-%d')
    today_trades = [t for t in global_data['trade_history'] if t.get('close_time', '').startswith(today_str)]
    
    total_trades = len(today_trades)
    winning_trades = sum(1 for t in today_trades if t['profit'] > 0)
    losing_trades = total_trades - winning_trades
    total_profit = sum(t['profit'] for t in today_trades)
    total_loss = sum(t['profit'] for t in today_trades if t['profit'] < 0)
    win_rate = (winning_trades / total_trades * 100) if total_trades > 0 else 0
    profit_factor = abs(total_profit / total_loss) if total_loss != 0 else 0

    # Historique des profits pour le graphique
    profit_history = []
    cumulative_profit = 0
    for trade in reversed(today_trades): # Inverser pour un ordre chronologique
        cumulative_profit += trade['profit']
        profit_history.append({'time': trade['close_time'].split(' ')[1], 'profit': cumulative_profit})

    global_data['daily_stats'] = {
        'total_trades': total_trades,
        'winning_trades': winning_trades,
        'losing_trades': losing_trades,
        'win_rate': win_rate,
        'total_profit': total_profit,
        'profit_factor': profit_factor,
        'profit_history': profit_history
    }

    # Calculer la performance par symbole
    symbol_perf = {}
    for trade in global_data['trade_history']:
        s = trade['symbol']
        if s not in symbol_perf:
            symbol_perf[s] = {'profit': 0, 'trades': 0}
        symbol_perf[s]['profit'] += trade['profit']
        symbol_perf[s]['trades'] += 1
    
    sorted_symbols = sorted(symbol_perf.items(), key=lambda item: item[1]['profit'], reverse=True)
    global_data['symbol_performance'] = {
        'best': [{'symbol': s, 'profit': p['profit']} for s, p in sorted_symbols[:5]],
        'worst': [{'symbol': s, 'profit': p['profit']} for s, p in sorted_symbols[-5:]]
    }

@app.route('/')
def index():
    """Page principale du dashboard"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/data')
def api_data():
    """API endpoint pour les données du dashboard"""
    # Convertir le deque en liste pour la sérialisation JSON
    data_copy = global_data.copy()
    data_copy['trade_history'] = list(global_data['trade_history'])
    return jsonify(data_copy)

@app.route('/api/sync', methods=['POST'])
def sync_data():
    """Endpoint pour synchroniser les données depuis le robot MT5"""
    try:
        data = request.json
        process_data_and_update_stats(data)
        return jsonify({'status': 'success', 'message': 'Data synchronized'})
    except Exception as e:
        logging.error(f"Erreur de synchronisation: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    print("🚀 Démarrage du Web Dashboard...")
    print("📊 Accès: http://localhost:5000")
    print("🔄 Le dashboard se met à jour automatiquement via JavaScript.")
    print("❌ Ctrl+C pour arrêter")
    
    # Le thread de mise à jour fallback n'est plus nécessaire
    app.run(host='0.0.0.0', port=5000, debug=False)
