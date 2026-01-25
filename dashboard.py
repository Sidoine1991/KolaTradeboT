#!/usr/bin/env python3
"""
Dashboard de monitoring pour le trading MT5 IA
Affiche en temps réel l'état des positions, signaux et performance
"""

import os
import sys
import time
import json
import logging
import requests
import MetaTrader5 as mt5
from datetime import datetime, timedelta
from pathlib import Path
import tkinter as tk
from tkinter import ttk, font
import threading

# Configuration
RENDER_API_URL = "https://kolatradebot.onrender.com"
SYMBOLS_TO_MONITOR = [
    "Boom 300 Index",
    "Boom 600 Index", 
    "Boom 900 Index",
    "Crash 1000 Index"
]

class TradingDashboard:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("🤖 TradBOT IA Dashboard")
        self.root.geometry("1200x800")
        self.root.configure(bg='#1e1e1e')
        
        # Variables
        self.positions = {}
        self.signals = {}
        self.running = True
        
        # Style
        self.setup_styles()
        
        # Créer l'interface
        self.create_widgets()
        
        # Démarrer les threads de mise à jour
        self.start_update_threads()
        
    def setup_styles(self):
        """Configuration des styles"""
        self.colors = {
            'bg': '#1e1e1e',
            'fg': '#ffffff',
            'green': '#00ff00',
            'red': '#ff0000',
            'blue': '#00bfff',
            'yellow': '#ffff00',
            'gray': '#808080'
        }
        
        # Polices
        self.title_font = font.Font(family="Arial", size=16, weight="bold")
        self.header_font = font.Font(family="Arial", size=12, weight="bold")
        self.normal_font = font.Font(family="Arial", size=10)
        
    def create_widgets(self):
        """Créer les widgets du dashboard"""
        
        # Titre
        title = tk.Label(
            self.root, 
            text="🤖 TRADING IA DASHBOARD", 
            font=self.title_font,
            bg=self.colors['bg'],
            fg=self.colors['blue']
        )
        title.pack(pady=10)
        
        # Frame principal
        main_frame = tk.Frame(self.root, bg=self.colors['bg'])
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Frame des symboles
        symbols_frame = tk.LabelFrame(
            main_frame, 
            text="SYMBOLS MONITORING", 
            font=self.header_font,
            bg=self.colors['bg'],
            fg=self.colors['fg']
        )
        symbols_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        # Créer les cards pour chaque symbole
        self.symbol_cards = {}
        for i, symbol in enumerate(SYMBOLS_TO_MONITOR):
            card = self.create_symbol_card(symbols_frame, symbol, i)
            self.symbol_cards[symbol] = card
        
        # Frame de performance
        perf_frame = tk.LabelFrame(
            main_frame, 
            text="PERFORMANCE", 
            font=self.header_font,
            bg=self.colors['bg'],
            fg=self.colors['fg']
        )
        perf_frame.pack(fill=tk.X, padx=5, pady=5)
        
        self.performance_label = tk.Label(
            perf_frame,
            text="📊 En attente des données...",
            font=self.normal_font,
            bg=self.colors['bg'],
            fg=self.colors['gray']
        )
        self.performance_label.pack(pady=5)
        
        # Frame de contrôle
        control_frame = tk.Frame(main_frame, bg=self.colors['bg'])
        control_frame.pack(fill=tk.X, padx=5, pady=5)
        
        # Bouton de fermeture
        close_btn = tk.Button(
            control_frame,
            text="❌ FERMER",
            command=self.close_dashboard,
            bg=self.colors['red'],
            fg=self.colors['fg'],
            font=self.normal_font
        )
        close_btn.pack(side=tk.RIGHT, padx=5)
        
        # Status
        self.status_label = tk.Label(
            control_frame,
            text="🟢 CONNECTÉ",
            font=self.normal_font,
            bg=self.colors['bg'],
            fg=self.colors['green']
        )
        self.status_label.pack(side=tk.LEFT, padx=5)
        
    def create_symbol_card(self, parent, symbol, row):
        """Créer une card pour un symbole"""
        card = tk.Frame(parent, bg='#2d2d2d', relief=tk.RAISED, bd=1)
        
        # Grid layout
        card.grid(row=row//2, column=row%2, padx=5, pady=5, sticky='nsew')
        parent.grid_columnconfigure(row%2, weight=1)
        parent.grid_rowconfigure(row//2, weight=1)
        
        # Nom du symbole
        name_label = tk.Label(
            card,
            text=symbol,
            font=self.header_font,
            bg='#2d2d2d',
            fg=self.colors['blue']
        )
        name_label.pack(pady=5)
        
        # Signal
        signal_label = tk.Label(
            card,
            text="⏳ EN ATTENTE",
            font=self.normal_font,
            bg='#2d2d2d',
            fg=self.colors['gray']
        )
        signal_label.pack()
        
        # Position
        position_label = tk.Label(
            card,
            text="📉 PAS DE POSITION",
            font=self.normal_font,
            bg='#2d2d2d',
            fg=self.colors['gray']
        )
        position_label.pack()
        
        # Dernière mise à jour
        update_label = tk.Label(
            card,
            text="---",
            font=self.normal_font,
            bg='#2d2d2d',
            fg=self.colors['gray']
        )
        update_label.pack(pady=5)
        
        return {
            'card': card,
            'signal': signal_label,
            'position': position_label,
            'update': update_label
        }
    
    def update_symbol_card(self, symbol, signal_data=None, position_data=None):
        """Mettre à jour une card de symbole"""
        if symbol not in self.symbol_cards:
            return
        
        card = self.symbol_cards[symbol]
        
        # Mettre à jour le signal
        if signal_data:
            signal = signal_data.get('signal', 'WAIT')
            confidence = signal_data.get('confidence', 0)
            
            if signal == 'BUY':
                signal_text = f"📈 BUY {confidence:.0f}%"
                color = self.colors['green']
            elif signal == 'SELL':
                signal_text = f"📉 SELL {confidence:.0f}%"
                color = self.colors['red']
            else:
                signal_text = "⏳ EN ATTENTE"
                color = self.colors['gray']
            
            card['signal'].config(text=signal_text, fg=color)
        
        # Mettre à jour la position
        if position_data:
            pos_type = position_data.get('type', 'NONE')
            price = position_data.get('price', 0)
            profit = position_data.get('profit', 0)
            
            if pos_type != 'NONE':
                pos_color = self.colors['green'] if profit >= 0 else self.colors['red']
                pos_text = f"💼 {pos_type} @ {price}\n💰 P&L: {profit:+.2f}"
                card['position'].config(text=pos_text, fg=pos_color)
            else:
                card['position'].config(text="📉 PAS DE POSITION", fg=self.colors['gray'])
        
        # Mettre à jour l'heure
        card['update'].config(text=f"🕐 {datetime.now().strftime('%H:%M:%S')}")
    
    def get_ai_signals(self):
        """Récupérer les signaux IA"""
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
                        self.signals[symbol] = {'signal': 'BUY', 'confidence': confidence}
                    elif direction.upper() == 'DOWN':
                        self.signals[symbol] = {'signal': 'SELL', 'confidence': confidence}
                    else:
                        self.signals[symbol] = {'signal': 'WAIT', 'confidence': 0}
                else:
                    self.signals[symbol] = {'signal': 'ERROR', 'confidence': 0}
                    
        except Exception as e:
            print(f"Erreur获取信号: {e}")
    
    def get_mt5_positions(self):
        """Récupérer les positions MT5"""
        try:
            if not mt5.initialize():
                return
            
            positions = mt5.positions_get()
            if positions:
                for pos in positions:
                    if pos.symbol in SYMBOLS_TO_MONITOR:
                        self.positions[pos.symbol] = {
                            'type': 'BUY' if pos.type == mt5.POSITION_TYPE_BUY else 'SELL',
                            'price': pos.price_open,
                            'profit': pos.profit,
                            'ticket': pos.ticket
                        }
            
            # Nettoyer les positions fermées
            for symbol in list(self.positions.keys()):
                if symbol not in [pos.symbol for pos in positions] if positions else []:
                    del self.positions[symbol]
                    
            mt5.shutdown()
            
        except Exception as e:
            print(f"Erreur获取MT5仓位: {e}")
    
    def update_dashboard(self):
        """Mettre à jour le dashboard"""
        while self.running:
            try:
                # Récupérer les données
                self.get_ai_signals()
                self.get_mt5_positions()
                
                # Mettre à jour les cards
                for symbol in SYMBOLS_TO_MONITOR:
                    signal_data = self.signals.get(symbol)
                    position_data = self.positions.get(symbol)
                    self.update_symbol_card(symbol, signal_data, position_data)
                
                # Calculer la performance
                total_profit = sum(pos.get('profit', 0) for pos in self.positions.values())
                active_positions = len(self.positions)
                
                perf_text = f"📊 Positions: {active_positions} | 💰 P&L Total: {total_profit:+.2f} | 🤖 Signaux: {len([s for s in self.signals.values() if s.get('signal') != 'WAIT'])}"
                self.performance_label.config(text=perf_text)
                
                # Mettre à jour le status
                self.status_label.config(text="🟢 CONNECTÉ", fg=self.colors['green'])
                
            except Exception as e:
                self.status_label.config(text="🔴 ERREUR", fg=self.colors['red'])
                print(f"Erreur更新dashboard: {e}")
            
            time.sleep(5)  # Mise à jour toutes les 5 secondes
    
    def start_update_threads(self):
        """Démarrer les threads de mise à jour"""
        update_thread = threading.Thread(target=self.update_dashboard, daemon=True)
        update_thread.start()
    
    def close_dashboard(self):
        """Fermer le dashboard"""
        self.running = False
        self.root.quit()
        self.root.destroy()
    
    def run(self):
        """Démarrer le dashboard"""
        try:
            self.root.mainloop()
        except KeyboardInterrupt:
            self.close_dashboard()

if __name__ == "__main__":
    dashboard = TradingDashboard()
    dashboard.run()
