#!/usr/bin/env python3
"""
Dashboard de monitoring TradBOT - Version Render
Affiche les métriques ML, signaux et performance en temps réel
Design épuré et lisible
"""

import os
import sys
import time
import json
import requests
import logging
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import ttk, font
import threading

# Configuration
RENDER_API_URL = "https://kolatradebot-7ofl.onrender.com"
LOCAL_API_URL = "http://127.0.0.1:8000"

SYMBOLS_TO_MONITOR = [
    "Boom 500 Index",
    "Crash 300 Index",
    "Step Index",
    "Volatility 100 Index"
]

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class RenderDashboard:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("TradBOT IA Dashboard - Render")
        self.root.geometry("1400x900")
        self.root.configure(bg='#ffffff')

        # Variables
        self.metrics = {}
        self.running = True
        self.api_url = RENDER_API_URL

        # Polices
        self.setup_fonts()

        # Créer interface
        self.create_interface()

        # Démarrer mise à jour
        self.start_updates()

    def setup_fonts(self):
        """Configuration des polices"""
        self.title_font = font.Font(family="Courier", size=14, weight="bold")
        self.header_font = font.Font(family="Courier", size=11, weight="bold")
        self.normal_font = font.Font(family="Courier", size=10)
        self.small_font = font.Font(family="Courier", size=9)

    def create_interface(self):
        """Créer l'interface du dashboard"""

        # === HEADER ===
        header_frame = tk.Frame(self.root, bg='#f0f0f0', height=60)
        header_frame.pack(fill=tk.X, padx=0, pady=0)
        header_frame.pack_propagate(False)

        header_title = tk.Label(
            header_frame,
            text="TradBOT IA Dashboard - Render Live",
            font=self.title_font,
            bg='#f0f0f0',
            fg='#000000'
        )
        header_title.pack(side=tk.LEFT, padx=20, pady=10)

        self.status_label = tk.Label(
            header_frame,
            text="Connecté à Render",
            font=self.small_font,
            bg='#f0f0f0',
            fg='#00aa00'
        )
        self.status_label.pack(side=tk.RIGHT, padx=20, pady=10)

        # === MAIN CONTENT ===
        main_frame = tk.Frame(self.root, bg='#ffffff')
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # === SECTION 1: HEALTH & STATUS ===
        health_frame = tk.LabelFrame(
            main_frame,
            text="SERVER STATUS",
            font=self.header_font,
            bg='#ffffff',
            fg='#000000',
            bd=1
        )
        health_frame.pack(fill=tk.X, padx=5, pady=5)

        self.health_text = tk.Text(
            health_frame,
            height=3,
            width=80,
            font=self.normal_font,
            bg='#f5f5f5',
            fg='#000000',
            bd=1
        )
        self.health_text.pack(padx=10, pady=10, fill=tk.BOTH)

        # === SECTION 2: SYMBOLS METRICS ===
        symbols_frame = tk.LabelFrame(
            main_frame,
            text="SYMBOLS METRICS",
            font=self.header_font,
            bg='#ffffff',
            fg='#000000',
            bd=1
        )
        symbols_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # Headers
        headers_frame = tk.Frame(symbols_frame, bg='#e0e0e0')
        headers_frame.pack(fill=tk.X, padx=0, pady=0)

        headers = [
            ("SYMBOL", 20),
            ("ACTION", 12),
            ("CONF", 10),
            ("MODEL", 15),
            ("ACCURACY", 12),
            ("RSI", 10),
            ("EMA", 12),
            ("SPIKE", 10)
        ]

        for header_text, width in headers:
            tk.Label(
                headers_frame,
                text=header_text.center(width),
                font=self.small_font,
                bg='#e0e0e0',
                fg='#000000',
                width=width
            ).pack(side=tk.LEFT, fill=tk.X)

        # Metrics display
        self.metrics_frame = tk.Frame(symbols_frame, bg='#ffffff')
        self.metrics_frame.pack(fill=tk.BOTH, expand=True, padx=0, pady=0)

        self.metrics_labels = {}
        for symbol in SYMBOLS_TO_MONITOR:
            label = tk.Label(
                self.metrics_frame,
                text="",
                font=self.normal_font,
                bg='#ffffff',
                fg='#000000',
                justify=tk.LEFT
            )
            label.pack(fill=tk.X, padx=10, pady=5)
            self.metrics_labels[symbol] = label

        # === SECTION 3: DECISION LOG ===
        log_frame = tk.LabelFrame(
            main_frame,
            text="DECISION LOG",
            font=self.header_font,
            bg='#ffffff',
            fg='#000000',
            bd=1
        )
        log_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        self.log_text = tk.Text(
            log_frame,
            height=8,
            width=80,
            font=self.small_font,
            bg='#f5f5f5',
            fg='#000000',
            bd=1
        )
        self.log_text.pack(padx=10, pady=10, fill=tk.BOTH, expand=True)

    def fetch_health(self):
        """Récupère le statut du serveur"""
        try:
            response = requests.get(f"{self.api_url}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                status_text = f"""
Server Status: ONLINE
Version: {data.get('version', 'N/A')}
Timestamp: {data.get('timestamp', 'N/A')}
ML Trainer: {'Available' if data.get('ml_trainer_available') else 'Unavailable'}
"""
                self.health_text.config(state=tk.NORMAL)
                self.health_text.delete(1.0, tk.END)
                self.health_text.insert(1.0, status_text.strip())
                self.health_text.config(state=tk.DISABLED)
                self.status_label.config(text="✓ Online", fg='#00aa00')
                return True
        except Exception as e:
            self.health_text.config(state=tk.NORMAL)
            self.health_text.delete(1.0, tk.END)
            self.health_text.insert(1.0, f"Server Status: OFFLINE\nError: {str(e)}")
            self.health_text.config(state=tk.DISABLED)
            self.status_label.config(text="✗ Offline", fg='#aa0000')
        return False

    def fetch_metrics(self, symbol):
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

    def fetch_decision(self, symbol, price=None, confluence=3):
        """Récupère une décision pour un symbole"""
        try:
            if price is None:
                price = 100.0  # Valeur par défaut

            payload = {
                "symbol": symbol,
                "price": price,
                "confluence": confluence,
                "timeframe": "M1"
            }

            response = requests.post(
                f"{self.api_url}/decision",
                json=payload,
                timeout=5
            )

            if response.status_code == 200:
                return response.json()
        except Exception as e:
            logger.warning(f"Error fetching decision for {symbol}: {e}")
        return None

    def format_metrics_line(self, symbol):
        """Formate une ligne de métriques"""
        metrics = self.fetch_metrics(symbol)
        decision = self.fetch_decision(symbol)

        if not metrics or not decision:
            return f"{symbol:<20} OFFLINE" + " " * 50

        action = decision.get('action', 'HOLD').upper()[:4]
        confidence = decision.get('confidence', 0)
        model = metrics.get('best_model', 'N/A')[:12]
        accuracy = metrics.get('metrics', {}).get(model, {}).get('accuracy', 0)

        metadata = decision.get('metadata', {})
        market_data = metadata.get('market_data', {})
        rsi = market_data.get('rsi', 0)
        ema_fast = market_data.get('ema_fast_m1', 0)

        spike_pred = decision.get('spike_prediction', False)
        spike_text = "YES " if spike_pred else "NO  "

        # Format: Symbol | Action | Conf | Model | Accuracy | RSI | EMA | Spike
        line = f"{symbol:<20} {action:<12} {confidence*100:>5.0f}% {model:<15} {accuracy:>6.1f}% {rsi:>6.1f} {ema_fast:>10.2f} {spike_text}"

        return line

    def update_metrics_display(self):
        """Met à jour l'affichage des métriques"""
        for symbol in SYMBOLS_TO_MONITOR:
            try:
                line = self.format_metrics_line(symbol)
                self.metrics_labels[symbol].config(text=line)
            except Exception as e:
                self.metrics_labels[symbol].config(text=f"{symbol:<20} ERROR: {str(e)[:30]}")

    def log_decision(self, symbol, decision):
        """Ajoute une décision au log"""
        if decision:
            timestamp = datetime.now().strftime("%H:%M:%S")
            action = decision.get('action', 'HOLD').upper()
            confidence = decision.get('confidence', 0) * 100
            reason = decision.get('reason', '')[:60]

            log_line = f"[{timestamp}] {symbol}: {action} ({confidence:.0f}%) - {reason}...\n"

            self.log_text.config(state=tk.NORMAL)
            self.log_text.insert(tk.END, log_line)
            self.log_text.see(tk.END)

            # Keep only last 100 lines
            lines = self.log_text.get(1.0, tk.END).split('\n')
            if len(lines) > 101:
                self.log_text.delete(1.0, "2.0")

            self.log_text.config(state=tk.DISABLED)

    def update_loop(self):
        """Boucle de mise à jour"""
        while self.running:
            try:
                # Update health
                self.fetch_health()

                # Update metrics
                self.update_metrics_display()

                # Log decisions
                for symbol in SYMBOLS_TO_MONITOR:
                    decision = self.fetch_decision(symbol)
                    if decision:
                        self.log_decision(symbol, decision)

                time.sleep(5)  # Update every 5 seconds
            except Exception as e:
                logger.error(f"Error in update loop: {e}")
                time.sleep(5)

    def start_updates(self):
        """Démarre les threads de mise à jour"""
        update_thread = threading.Thread(target=self.update_loop, daemon=True)
        update_thread.start()

    def run(self):
        """Lance le dashboard"""
        try:
            self.root.mainloop()
        except KeyboardInterrupt:
            self.running = False
            self.root.quit()


if __name__ == "__main__":
    dashboard = RenderDashboard()
    dashboard.run()
