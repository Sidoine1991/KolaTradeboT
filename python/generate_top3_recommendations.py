#!/usr/bin/env python3
"""
Génère les recommandations Top 3 symboles depuis l'historique journal.
Utilise: python generate_top3_recommendations.py
"""
import json
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

# Ajouter le dashboard au path
sys.path.insert(0, str(Path(__file__).parent.parent / "dashboard"))

from serve_trade_journal import load_trades, infer_category, compute_recommendations


def save_recommendations(output_path: Path = None) -> dict:
    """Charge les trades, calcule les recommendations, et les sauvegarde."""
    if output_path is None:
        output_path = Path(__file__).parent.parent / "data" / "top3_recommendations.json"

    print(f"[LOAD] Chargement des trades...", flush=True)
    trades = load_trades()
    print(f"[OK] {len(trades)} trades chargés", flush=True)

    if not trades:
        print("[WARN] Aucun trade disponible", flush=True)
        return {"top_symbols": [], "error": "No trades loaded"}

    print(f"[COMPUTE] Calcul des recommendations...", flush=True)
    recs = compute_recommendations(trades, top_n=3, min_trades=8)

    # Ajouter les métriques globales
    recs["total_trades"] = len(trades)
    recs["generated_at"] = datetime.utcnow().isoformat()

    # Sauvegarder en JSON
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(recs, f, ensure_ascii=False, indent=2)

    print(f"[OK] Recommandations sauvegardées: {output_path}", flush=True)

    # Afficher les résultats
    print(f"\n[RESULTS] Top 3 Symboles Recommandés", flush=True)
    print("=" * 70, flush=True)

    for idx, sym in enumerate(recs.get("top_symbols", []), 1):
        print(f"\n#{idx} — {sym['symbol']}", flush=True)
        print(f"  Catégorie:       {sym['category']}", flush=True)
        print(f"  Score:           {sym['score']:.1f}/100", flush=True)
        print(f"  Win Rate:        {sym['win_rate']:.1f}%", flush=True)
        print(f"  Profit Factor:   {sym['profit_factor']:.2f}", flush=True)
        print(f"  Trades:          {sym['trades']}", flush=True)
        print(f"  Net PnL:         ${sym['net_pnl']:+.2f}", flush=True)
        print(f"  Direction opt.:  {sym['best_direction']} ({sym['direction_win_rate']:.1f}% WR)", flush=True)
        print(f"  Durée moyenne:   {sym['avg_duration_min']:.1f} min", flush=True)

        if sym.get('best_hours'):
            hours_str = ", ".join([f"{h['label']} ({h['win_rate']:.0f}%)" for h in sym['best_hours'][:2]])
            print(f"  Meilleures UTC:  {hours_str}", flush=True)

        if sym.get('entry_tip'):
            print(f"  Stratégie:       {sym['entry_tip']}", flush=True)

    print("\n" + "=" * 70, flush=True)
    print(f"[OK] {recs.get('eligible_count', 0)} symboles éligibles au total", flush=True)

    return recs


def generate_html_report(recs: dict, output_path: Path = None) -> str:
    """Génère un rapport HTML lisible."""
    if output_path is None:
        output_path = Path(__file__).parent.parent / "logs" / "top3_report.html"

    html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>TradBOT — Top 3 Recommandations</title>
    <style>
        body {{ font-family: Arial, sans-serif; background: #0f1419; color: #e7ecf3; margin: 0; padding: 20px; }}
        h1 {{ color: #22c55e; }}
        .summary {{ background: #1a2332; padding: 15px; border-radius: 8px; margin: 20px 0; border: 1px solid #2d3a4f; }}
        .rank {{ background: #1a2332; padding: 20px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #3b82f6; }}
        .rank.rank-1 {{ border-left-color: #f59e0b; }}
        .stat {{ display: inline-block; margin: 10px 20px 10px 0; }}
        .stat-label {{ color: #8b9cb3; font-size: 0.9em; }}
        .stat-value {{ font-weight: bold; font-size: 1.2em; color: #22c55e; }}
        .negative {{ color: #ef4444; }}
        .timestamp {{ color: #8b9cb3; font-size: 0.9em; }}
    </style>
</head>
<body>
    <h1>🚀 TradBOT — Top 3 Symboles Recommandés</h1>

    <div class="summary">
        <h3>Résumé</h3>
        <div class="stat">
            <div class="stat-label">Trades Historiques</div>
            <div class="stat-value">{recs.get('total_trades', 0)}</div>
        </div>
        <div class="stat">
            <div class="stat-label">Symboles Éligibles</div>
            <div class="stat-value">{recs.get('eligible_count', 0)}</div>
        </div>
        <div class="stat">
            <div class="stat-label">Min Trades/Symbole</div>
            <div class="stat-value">{recs.get('min_trades', 8)}</div>
        </div>
        <p class="timestamp">Généré: {recs.get('generated_at', 'N/A')}</p>
    </div>
"""

    for idx, sym in enumerate(recs.get("top_symbols", []), 1):
        rank_class = "rank-1" if idx == 1 else ""
        html += f"""
    <div class="rank {rank_class}">
        <h2>#{idx} — {sym['symbol']}</h2>
        <p><strong>Catégorie:</strong> {sym['category']}</p>

        <div class="stat">
            <div class="stat-label">Score</div>
            <div class="stat-value">{sym['score']:.1f}/100</div>
        </div>
        <div class="stat">
            <div class="stat-label">Win Rate</div>
            <div class="stat-value">{sym['win_rate']:.1f}%</div>
        </div>
        <div class="stat">
            <div class="stat-label">Profit Factor</div>
            <div class="stat-value">{sym['profit_factor']:.2f}</div>
        </div>
        <div class="stat">
            <div class="stat-label">Trades</div>
            <div class="stat-value">{sym['trades']}</div>
        </div>
        <div class="stat">
            <div class="stat-label">Net PnL</div>
            <div class="stat-value {'negative' if sym['net_pnl'] < 0 else ''}">${sym['net_pnl']:+.2f}</div>
        </div>

        <h3>📍 Paramètres Recommandés</h3>
        <ul>
            <li><strong>Direction optimale:</strong> {sym['best_direction']} ({sym['direction_win_rate']:.1f}% WR)</li>
            <li><strong>Durée moyenne:</strong> {sym['avg_duration_min']:.1f} min</li>
            <li><strong>Fenêtres UTC actives:</strong> {', '.join([f"{h['label']} ({h['win_rate']:.0f}%)" for h in sym.get('best_hours', [])[:3]])}</li>
        </ul>

        <p><strong>💡 Stratégie Recommandée:</strong><br/>{sym.get('entry_tip', 'N/A')}</p>
    </div>
"""

    html += """
</body>
</html>
"""

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"[OK] Rapport HTML: {output_path}", flush=True)
    return str(output_path)


if __name__ == "__main__":
    try:
        recs = save_recommendations()
        generate_html_report(recs)

        print(f"\n[SUCCESS] Top 3 recommandations générées avec succès!", flush=True)
        sys.exit(0)
    except Exception as e:
        print(f"[ERROR] {e}", flush=True)
        import traceback
        traceback.print_exc()
        sys.exit(1)
