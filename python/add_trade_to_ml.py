#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ajoute un trade à la base d'apprentissage ML
Utilisé par le processeur de trades pour collecter les données en continu
"""

import json
import pandas as pd
from pathlib import Path
from datetime import datetime
import sys

# Chemin vers le script d'entraînement ML
TRAIN_SCRIPT = Path("D:/Dev/TradBOT/python/train_ml.py")
ML_DATA_DIR = Path("D:/Dev/TradBOT/ml_data")

# Configuration
def load_trade_from_file(deal_ticket):
    """Charger un trade depuis la base de données trades.db"""
    try:
        db_path = Path("D:/Dev/TradBOT/data/trades.db")
        if not db_path.exists():
            print("[WARNING] Base de donnees trades.db non trouvee")
            return None

        import sqlite3
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Récupérer le trade
        cursor.execute("SELECT * FROM trades WHERE deal_ticket = ?", (deal_ticket,))
        columns = [description[0] for description in cursor.description]
        row = cursor.fetchone()

        if row:
            trade = dict(zip(columns, row))
            conn.close()
            return trade
        else:
            print(f"[WARNING] Trade {deal_ticket} non trouve")
            return None
    except Exception as e:
        print(f"[ERROR] Error loading trade: {e}")
        return None

def get_trade_result(trade):
    """Determine the trade result (WIN/LOSS/BREAK_EVEN)"""
    try:
        open_price = float(trade.get('open_price', 0))
        close_price = float(trade.get('close_price', 0))
        direction = trade.get('direction', '')
        symbol = trade.get('symbol', '')

        # Determine point size from symbol
        point = 0.0001  # Default for forex
        if 'JPY' in symbol:
            point = 0.001
        elif symbol in ['XAUUSD', 'GOLD']:
            point = 0.01
        elif symbol in ['XAGUSD', 'SILVER']:
            point = 0.001
        elif 'BTC' in symbol or 'ETH' in symbol:
            point = 0.1
        elif any(x in symbol.upper() for x in ['BOOM', 'CRASH', 'PAINX', 'GAINX', 'VOLATILITY']):
            point = 0.001

        pips = (close_price - open_price) / point

        # Define result
        if abs(pips) < 0.5:  # Small movement
            return 'BREAK_EVEN'
        elif (direction == 'BUY' and pips > 0) or (direction == 'SELL' and pips < 0):
            return 'WIN'
        else:
            return 'LOSS'
    except Exception as e:
        print("[WARNING] Error calculating result: {}".format(e))
        return 'LOSS'

def add_to_ml_dataset(deal_ticket):
    """Ajouter un trade à la base ML et déclencher l'entraînement si nécessaire"""
    try:
        print("[INFO] Processing trade {} for ML...".format(deal_ticket))

        # Charger le trade
        trade = load_trade_from_file(deal_ticket)
        if not trade:
            return False

        # Déterminer le résultat
        result = get_trade_result(trade)
        print("[INFO] Result: {}".format(result))

        # Charger le fichier de configuration GOM pour obtenir les métadonnées supplémentaires
        try:
            import json
            with open('D:/Dev/TradBOT/data/gom_signal.json', 'r') as f:
                gom_data = json.load(f)
            if str(deal_ticket) in gom_data:
                trade.update(gom_data[str(deal_ticket)])
        except Exception:
            pass

        # Appeler le script d'entraînement ML (qui gère l'ajout des données)
        import subprocess
        cmd = [sys.executable, str(TRAIN_SCRIPT), "--add-trade", str(deal_ticket), "--result", result]

        # Exécuter de manière asynchrone pour ne pas bloquer
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print("[INFO] Trade submitted to ML training in background")

        return True
    except Exception as e:
        print(f"[ERROR] Error adding ML: {e}")
        return False

def main():
    """Utilisation en ligne de commande"""
    import argparse
    parser = argparse.ArgumentParser(description='Ajouter un trade à la base ML')
    parser.add_argument('--deal-ticket', type=int, required=True, help='Numéro du ticket de trade')
    parser.add_argument('--result', choices=['WIN', 'LOSS', 'BREAK_EVEN'], required=True, help='Résultat du trade')
    args = parser.parse_args()

    trade = load_trade_from_file(args.deal_ticket)
    if trade:
        # Mettre à jour le résultat dans la base de données
        import sqlite3
        conn = sqlite3.connect('D:/Dev/TradBOT/data/trades.db')
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE trades SET ml_result = ?, ml_result_date = ? WHERE deal_ticket = ?",
            (args.result, datetime.now().isoformat(), args.deal_ticket)
        )
        conn.commit()
        conn.close()

        print(f"[OK] ML result recorded: {args.result}")

        # Ajouter à la base ML
        add_to_ml_dataset(args.deal_ticket)
    else:
        print(f"[ERROR] Trade {args.deal_ticket} not found")

if __name__ == '__main__':
    main()
