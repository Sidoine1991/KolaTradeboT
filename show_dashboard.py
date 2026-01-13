#!/usr/bin/env python3
"""
Dashboard texte en temps réel pour afficher les statistiques ML et trading
"""

import sys
import os
from pathlib import Path
from datetime import datetime
import time
import pandas as pd

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from backend.dashboard_stats import DashboardStats

def format_table(headers: list, rows: list, col_widths: list = None) -> str:
    """Formate un tableau texte"""
    if not rows:
        return ""
    
    if col_widths is None:
        col_widths = [max(len(str(h)), max(len(str(r[i])) for r in rows if i < len(r))) for i, h in enumerate(headers)]
    
    # Ligne de séparation
    sep = "+" + "+".join("-" * (w + 2) for w in col_widths) + "+"
    
    # En-tête
    header_row = "| " + " | ".join(str(h).ljust(col_widths[i]) for i, h in enumerate(headers)) + " |"
    
    # Lignes de données
    data_rows = []
    for row in rows:
        data_row = "| " + " | ".join(str(row[i] if i < len(row) else "").ljust(col_widths[i]) for i in range(len(headers))) + " |"
        data_rows.append(data_row)
    
    return "\n".join([sep, header_row, sep] + data_rows + [sep])

def format_bar_chart(data: dict, max_width: int = 40, title: str = "") -> str:
    """Crée un graphique en barres ASCII"""
    if not data:
        return f"{title}: Aucune donnée"
    
    max_val = max(data.values()) if data.values() else 1
    result = []
    if title:
        result.append(title)
    
    for key, value in sorted(data.items()):
        bar_width = int((value / max_val) * max_width) if max_val > 0 else 0
        bar = "█" * bar_width
        result.append(f"  {str(key).ljust(15)} │{bar} {value}")
    
    return "\n".join(result)

def format_progress_bar(value: float, max_val: float = 1.0, width: int = 30) -> str:
    """Crée une barre de progression"""
    if max_val == 0:
        return "░" * width
    filled = int((value / max_val) * width)
    return "█" * filled + "░" * (width - filled)

def get_status_emoji(value: float, thresholds: tuple = (0.5, 0.7, 0.9)) -> str:
    """Retourne un emoji selon la valeur"""
    if value >= thresholds[2]:
        return "🟢"
    elif value >= thresholds[1]:
        return "🟡"
    elif value >= thresholds[0]:
        return "🟠"
    else:
        return "🔴"

def print_dashboard():
    """Affiche le dashboard simplifié"""
    stats_collector = DashboardStats()
    stats = stats_collector.get_all_stats()
    
    # Effacer l'écran (Windows)
    os.system('cls' if os.name == 'nt' else 'clear')
    
    print("=" * 70)
    print("🤖 DASHBOARD TRADBOT")
    print("=" * 70)
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # RÉSUMÉ PRINCIPAL
    trading_stats = stats.get("trading_stats", {})
    robot_stats = stats.get("robot_performance", {})
    model_perf = stats.get("model_performance", {})
    
    total_trades = trading_stats.get('total_trades', 0)
    buy_trades = trading_stats.get('buy_trades', 0)
    sell_trades = trading_stats.get('sell_trades', 0)
    avg_conf = trading_stats.get('avg_confidence', 0)
    decisions_today = robot_stats.get('decisions_today', 0)
    decisions_last_hour = robot_stats.get('decisions_last_hour', 0)
    
    print("📊 RÉSUMÉ")
    print("-" * 70)
    print(f"Trades: {total_trades} (BUY: {buy_trades} | SELL: {sell_trades})")
    print(f"Confiance: {get_status_emoji(avg_conf)} {avg_conf:.1%}")
    print(f"Activité: {decisions_today} aujourd'hui | {decisions_last_hour} dernière heure")
    print()
    
    # MODÈLES ML (simplifié)
    if "models" in model_perf and model_perf["models"]:
        print("🤖 MODÈLES ML")
        print("-" * 70)
        for model_name, model_stats in list(model_perf["models"].items())[:3]:
            avg_conf = model_stats.get('avg_confidence', 0)
            total = model_stats.get("total_predictions", 0)
            print(f"{get_status_emoji(avg_conf)} {model_name[:40]:40} | {total:4} prédictions | {avg_conf:.1%}")
        print()
    
    # DERNIÈRES DÉCISIONS (5 seulement)
    if trading_stats.get("recent_decisions"):
        print("🕐 DERNIÈRES DÉCISIONS")
        print("-" * 70)
        headers = ["Heure", "Symbole", "Action", "Conf", "Style"]
        rows = []
        
        for decision in trading_stats["recent_decisions"][:5]:
            time_val = decision.get("time", "")
            if time_val:
                if hasattr(time_val, 'strftime'):
                    time_str = time_val.strftime('%H:%M:%S')
                elif isinstance(time_val, str):
                    time_str = time_val[11:19] if len(time_val) > 19 else time_val[:8]
                else:
                    time_str = str(time_val)[11:19] if len(str(time_val)) > 19 else str(time_val)[:8]
            else:
                time_str = "N/A"
            
            symbol_val = decision.get("symbol", "N/A")
            symbol = str(symbol_val)[:15] if symbol_val and not (isinstance(symbol_val, float) and pd.isna(symbol_val)) else "N/A"
            
            action_val = decision.get("action", "N/A")
            action = str(action_val).upper()[:4] if action_val and not (isinstance(action_val, float) and pd.isna(action_val)) else "N/A"
            
            conf_val = decision.get("confidence", 0)
            if conf_val and not (isinstance(conf_val, float) and pd.isna(conf_val)):
                try:
                    conf = f"{float(conf_val):.0%}"
                except:
                    conf = "N/A"
            else:
                conf = "N/A"
            
            style_val = decision.get("style", "")
            if style_val and not (isinstance(style_val, float) and pd.isna(style_val)):
                style = str(style_val)[:5].upper()
            else:
                style = "-"
            
            rows.append([time_str, symbol, action, conf, style])
        
        print(format_table(headers, rows))
        print()
    
    # ALERTES
    alerts = []
    if avg_conf < 0.5:
        alerts.append("🔴 Confiance faible")
    if decisions_last_hour == 0:
        alerts.append("🟡 Pas d'activité récente")
    
    if alerts:
        print("⚠️  ALERTES")
        print("-" * 70)
        for alert in alerts:
            print(f"   {alert}")
    else:
        print("✅ Système opérationnel")
    
    print()
    print("=" * 70)
    print("💡 Ctrl+C pour quitter | Rafraîchissement: 5s")
    print("=" * 70)

def main():
    """Lance le dashboard en mode rafraîchissement automatique"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Dashboard TradBOT")
    parser.add_argument("--once", action="store_true", help="Afficher une seule fois (pas de rafraîchissement)")
    parser.add_argument("--interval", type=int, default=5, help="Intervalle de rafraîchissement (secondes)")
    
    args = parser.parse_args()
    
    try:
        if args.once:
            print_dashboard()
        else:
            while True:
                print_dashboard()
                time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n\n👋 Dashboard arrêté")

if __name__ == "__main__":
    main()

