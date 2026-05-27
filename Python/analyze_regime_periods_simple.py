"""
Analyse simple des périodes régimes depuis CSV XAUUSD
Sans pandas - utilise csv standard library

Usage:
    python Python/analyze_regime_periods_simple.py
"""

import sys
import io
import csv
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')


def calculate_ema_simple(prices, period):
    """Calcule EMA simple."""
    if len(prices) < period:
        return None

    multiplier = 2 / (period + 1)
    ema = sum(prices[:period]) / period  # SMA initial

    for price in prices[period:]:
        ema = (price * multiplier) + (ema * (1 - multiplier))

    return ema


def load_and_analyze(csv_path):
    """Charge CSV et analyse régimes."""

    print(f"📂 Chargement: {csv_path}")

    data = []
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            data.append({
                'time': datetime.strptime(row['time'], '%Y-%m-%d %H:%M:%S'),
                'close': float(row['close'])
            })

    print(f"   Lignes chargées: {len(data):,}")
    print(f"   Période: {data[0]['time']} → {data[-1]['time']}")

    # Calculer EMA50/200 sur données weekly
    print("   Calcul EMA50/200 sur W1...")

    # Resample manuel à W1
    weekly_data = {}
    for row in data:
        week_key = row['time'].isocalendar()[:2]  # (year, week)
        if week_key not in weekly_data:
            weekly_data[week_key] = []
        weekly_data[week_key].append(row['close'])

    # Close W1 = dernier close de la semaine
    weekly_closes = []
    for week_key in sorted(weekly_data.keys()):
        weekly_closes.append(weekly_data[week_key][-1])

    # Calculer EMA
    ema50_values = []
    ema200_values = []

    for i in range(len(weekly_closes)):
        if i >= 200:
            ema50 = calculate_ema_simple(weekly_closes[max(0, i-50):i+1], 50)
            ema200 = calculate_ema_simple(weekly_closes[i-200:i+1], 200)
            ema50_values.append(ema50)
            ema200_values.append(ema200)
        else:
            ema50_values.append(None)
            ema200_values.append(None)

    # Map EMA back to hourly data (forward fill)
    print("   Détection régimes...")

    regimes = []
    current_ema50 = None
    current_ema200 = None
    week_idx = 0

    for i, row in enumerate(data):
        week_key = row['time'].isocalendar()[:2]

        # Check si nouvelle semaine
        if i == 0 or data[i-1]['time'].isocalendar()[:2] != week_key:
            if week_idx < len(ema50_values):
                if ema50_values[week_idx] is not None:
                    current_ema50 = ema50_values[week_idx]
                    current_ema200 = ema200_values[week_idx]
                week_idx += 1

        # Détecter régime
        if current_ema50 and current_ema200:
            diff_pct = ((current_ema50 - current_ema200) / current_ema200) * 100

            if diff_pct > 0.8:
                regime = "BULL"
            elif diff_pct < -0.8:
                regime = "BEAR"
            else:
                regime = "TRANSITION"
        else:
            regime = "UNKNOWN"

        regimes.append(regime)

    # Compter régimes
    regime_counts = defaultdict(int)
    for r in regimes:
        regime_counts[r] += 1

    print(f"\n   Distribution régimes:")
    total = len(regimes)
    for regime in ['BULL', 'BEAR', 'TRANSITION', 'UNKNOWN']:
        count = regime_counts[regime]
        pct = (count / total) * 100 if total > 0 else 0
        print(f"      {regime:12s}: {count:6,} bougies ({pct:5.1f}%)")

    return data, regimes


def identify_periods(data, regimes):
    """Identifie périodes continues par régime."""

    periods = {
        'BULL': [],
        'BEAR': [],
        'TRANSITION': []
    }

    current_regime = None
    start_idx = None

    for i, regime in enumerate(regimes):
        if regime == 'UNKNOWN':
            continue

        if regime != current_regime:
            # Fin période précédente
            if current_regime and start_idx is not None:
                duration = (data[i]['time'] - data[start_idx]['time']).days
                periods[current_regime].append({
                    'start': data[start_idx]['time'],
                    'end': data[i-1]['time'],
                    'duration_days': duration
                })

            # Début nouvelle période
            current_regime = regime
            start_idx = i

    # Dernière période
    if current_regime and start_idx is not None:
        duration = (data[-1]['time'] - data[start_idx]['time']).days
        periods[current_regime].append({
            'start': data[start_idx]['time'],
            'end': data[-1]['time'],
            'duration_days': duration
        })

    return periods


def generate_report(periods, output_path):
    """Génère rapport périodes."""

    report = f"""# Périodes Régimes XAUUSD pour Backtests MT5
Généré: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Source: XAUUSD_H1_2010_2023.csv

## Instructions

Pour chaque période ci-dessous:
1. MT5 Strategy Tester
2. Expert: GoldSMC_EA_v5.ex5
3. Settings → Load: Optimization/goldsmc_v5_<REGIME>.set
4. Period: Start/End ci-dessous
5. Quality: Every tick
6. Start test

---

"""

    for regime in ['BULL', 'BEAR', 'TRANSITION']:
        report += f"\n## {regime} PERIODS\n\n"
        report += f"Total périodes: {len(periods[regime])}\n\n"

        if not periods[regime]:
            report += "Aucune période détectée.\n\n"
            continue

        # Trier par durée
        sorted_periods = sorted(periods[regime], key=lambda x: x['duration_days'], reverse=True)

        # Filtrer périodes > 30 jours
        long_periods = [p for p in sorted_periods if p['duration_days'] > 30]

        report += f"### Périodes > 30 jours ({len(long_periods)}):\n\n"
        report += "| # | Start | End | Days | MT5 Format |\n"
        report += "|---|-------|-----|------|------------|\n"

        for i, p in enumerate(long_periods[:15], 1):
            mt5_format = f"{p['start'].strftime('%Y.%m.%d')} - {p['end'].strftime('%Y.%m.%d')}"
            report += f"| {i} | {p['start'].strftime('%Y-%m-%d')} | {p['end'].strftime('%Y-%m-%d')} | {p['duration_days']} | `{mt5_format}` |\n"

        report += "\n"

    report += """
---

## Backtests Recommandés

### BULL
Top 3-4 périodes les plus longues (idéalement > 200 jours)

### BEAR
Top 3-4 périodes les plus longues (idéalement > 100 jours)

### TRANSITION
Top 2-3 périodes représentatives

---

## Analyse Résultats

Après chaque backtest:
```bash
python Python/analyze_goldsmc_backtest.py "rapport.xlsx"
```

Objectifs:
- BULL: PF ≥ 5.0, Win Rate ≥ 55%, DD < 20%
- BEAR: PF ≥ 2.0, Win Rate ≥ 50%, DD < 20%
- TRANSITION: PF ≥ 1.8, Win Rate ≥ 52%, DD < 15%
"""

    output_path.write_text(report, encoding='utf-8')
    print(f"\n✅ Rapport généré: {output_path}")


def main():
    csv_path = "D:/Dev/TradBOT/data/XAUUSD_H1_2010_2023.csv"

    print("=" * 80)
    print("  ANALYSE PÉRIODES RÉGIMES")
    print("=" * 80)
    print()

    # Charger et analyser
    data, regimes = load_and_analyze(csv_path)

    # Identifier périodes
    print("\n📊 Identification périodes...")
    periods = identify_periods(data, regimes)

    # Stats périodes
    print("\n   Résumé périodes:")
    for regime in ['BULL', 'BEAR', 'TRANSITION']:
        total = len(periods[regime])
        long_periods = len([p for p in periods[regime] if p['duration_days'] > 30])
        print(f"      {regime:12s}: {total:3d} périodes ({long_periods} > 30 jours)")

    # Générer rapport
    output_dir = Path("D:/Dev/TradBOT/Optimization/Backtest_Periods")
    output_dir.mkdir(parents=True, exist_ok=True)

    report_path = output_dir / "MT5_BACKTEST_PERIODS.md"
    generate_report(periods, report_path)

    print("\n" + "=" * 80)
    print("  TERMINÉ")
    print("=" * 80)
    print(f"\n📂 Fichier: {report_path}")
    print("\nProchaine étape: Ouvrir MT5 et lancer backtests selon périodes recommandées")


if __name__ == "__main__":
    main()
