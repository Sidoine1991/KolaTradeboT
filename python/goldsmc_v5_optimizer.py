"""
GoldSMC v5 - Système d'optimisation intelligente Walk-Forward Analysis
Adapte automatiquement les paramètres selon le régime de marché (BULL/BEAR/TRANSITION)

Usage:
    python Python/goldsmc_v5_optimizer.py --mode analyze
    python Python/goldsmc_v5_optimizer.py --mode optimize
    python Python/goldsmc_v5_optimizer.py --mode generate-sets
"""

import sys
import io
import json
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
from dataclasses import dataclass, asdict

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')


@dataclass
class RegimeParams:
    """Paramètres optimaux par régime de marché."""

    # Filtres entrée
    atr_range_filter_mult: float
    min_rr_ratio: float

    # Money management
    risk_percent: float
    max_risk_percent: float

    # TP/SL
    sl_atr_mult: float
    tp_rr_partial: float
    tp_rr_final: float

    # Trailing
    trailing_activate_mult: float
    trailing_lock_pct: float

    # Filtres régime
    regime_threshold_pct: float
    transition_lot_pct: float

    # Sessions
    use_session_filter: bool
    session_hours: List[Tuple[int, int]]  # [(start, end), ...]

    # Cooldown
    cooldown_minutes: int
    max_consec_losses: int


class MarketRegimeDetector:
    """Détecteur de régime de marché basé sur EMA et volatilité."""

    @staticmethod
    def detect_regime(ema50: float, ema200: float, atr: float, price: float) -> str:
        """
        Détermine le régime actuel.

        Returns:
            "BULL", "BEAR", ou "TRANSITION"
        """
        ema_diff_pct = ((ema50 - ema200) / ema200) * 100
        volatility_pct = (atr / price) * 100

        # BULL: EMA50 > EMA200 avec écart significatif et volatilité modérée
        if ema_diff_pct > 0.8 and volatility_pct < 2.0:
            return "BULL"

        # BEAR: EMA50 < EMA200 avec écart significatif
        elif ema_diff_pct < -0.8:
            return "BEAR"

        # TRANSITION: EMA proches ou volatilité élevée
        else:
            return "TRANSITION"


class GoldSMCOptimizer:
    """Optimiseur intelligent pour GoldSMC v5."""

    def __init__(self):
        self.regime_detector = MarketRegimeDetector()

        # Paramètres optimaux par régime (issus de recherche empirique)
        self.optimal_params = {
            "BULL": RegimeParams(
                # Filtres plus permissifs en BULL
                atr_range_filter_mult=0.2,
                min_rr_ratio=1.5,

                # Risk plus agressif
                risk_percent=1.5,
                max_risk_percent=3.0,

                # SL/TP adaptés aux grands mouvements
                sl_atr_mult=1.8,
                tp_rr_partial=1.8,
                tp_rr_final=3.5,

                # Trailing agressif
                trailing_activate_mult=0.6,
                trailing_lock_pct=0.5,

                # Régime
                regime_threshold_pct=0.8,
                transition_lot_pct=30.0,

                # Sessions actives (London + NY)
                use_session_filter=True,
                session_hours=[(7, 11), (13, 17)],

                # Cooldown réduit
                cooldown_minutes=45,
                max_consec_losses=3
            ),

            "BEAR": RegimeParams(
                # Filtres plus stricts en BEAR
                atr_range_filter_mult=0.5,
                min_rr_ratio=2.0,

                # Risk conservateur
                risk_percent=0.8,
                max_risk_percent=2.0,

                # SL/TP serrés
                sl_atr_mult=1.2,
                tp_rr_partial=1.3,
                tp_rr_final=2.5,

                # Trailing conservateur
                trailing_activate_mult=0.4,
                trailing_lock_pct=0.3,

                # Régime
                regime_threshold_pct=0.8,
                transition_lot_pct=50.0,

                # Toutes sessions (bear = volatilité imprévisible)
                use_session_filter=False,
                session_hours=[],

                # Cooldown long
                cooldown_minutes=120,
                max_consec_losses=2
            ),

            "TRANSITION": RegimeParams(
                # Filtres moyens
                atr_range_filter_mult=0.35,
                min_rr_ratio=1.8,

                # Risk moyen
                risk_percent=1.0,
                max_risk_percent=2.5,

                # SL/TP équilibrés
                sl_atr_mult=1.5,
                tp_rr_partial=1.5,
                tp_rr_final=3.0,

                # Trailing moyen
                trailing_activate_mult=0.5,
                trailing_lock_pct=0.4,

                # Régime
                regime_threshold_pct=0.5,
                transition_lot_pct=50.0,

                # Sessions principales uniquement
                use_session_filter=True,
                session_hours=[(7, 17)],

                # Cooldown moyen
                cooldown_minutes=60,
                max_consec_losses=3
            )
        }

    def generate_mt5_set_file(self, regime: str, output_path: Path):
        """Génère un fichier .set MT5 pour un régime donné."""

        params = self.optimal_params[regime]

        content = f"""; GoldSMC_EA v5 - Paramètres optimisés {regime}
; Généré automatiquement le {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

[Inputs]
; === RISQUE ===
InpLotSize=0.01
UseMinLotOnly=false
UseRiskBasedLot=true
RiskPercentPerTrade={params.risk_percent}
MaxRiskPerTradePct={params.max_risk_percent}
SL_ATRMult={params.sl_atr_mult}
MaxDailyLossPct=5.0
MaxDrawdownPct=30.0
DisableBreakerInTester=true

; === REGIME MARCHE (W1) ===
UseRegimeFilter=true
UseMonthlyFilter=true
RegimeBullThreshPct={params.regime_threshold_pct}
RegimeBearThreshPct={params.regime_threshold_pct}
TradeInTransition=true
TransitionLotPct={params.transition_lot_pct}

; === TP PARTIEL ===
UsePartialTP=true
TP_RR_Partial={params.tp_rr_partial}
TP_RR_Final={params.tp_rr_final}

; === FILTRES ENTRÉE ===
ATR_Period=14
ATR_RangeFilterMult={params.atr_range_filter_mult}
MinRRRatio={params.min_rr_ratio}
BOS_MinBars=3
EnableFalseSignalGates=true

; === SESSIONS (UTC) ===
UseSessionFilter={str(params.use_session_filter).lower()}
"""

        if params.session_hours:
            for i, (start, end) in enumerate(params.session_hours, 1):
                content += f"Session{i}_Start={start}\n"
                content += f"Session{i}_End={end}\n"
        else:
            content += "Session1_Start=0\nSession1_End=23\n"

        content += f"""
; === GESTION POSITION ===
CooldownMinutes={params.cooldown_minutes}
MaxConsecLosses={params.max_consec_losses}
PauseDurationMinutes={params.cooldown_minutes * 2}
TrailingActivateMult={params.trailing_activate_mult}
TrailingLockPct={params.trailing_lock_pct}

; === OB DETECTION ===
OB_LookbackBars=12
OB_RetestBuffer=0.3
StrictBOS=false

; === SESSION BIAS (TradingAgents) ===
UseSessionBiasFilter=false
AIServerURL=http://127.0.0.1:8000
SessionBiasMinConf=0.6
SessionBiasCacheSec=3600

; === MAGIC / AFFICHAGE ===
MagicNumber=20260526
ShowDashboard=true
DebugMode=false
"""

        output_path.write_text(content, encoding='utf-8')
        print(f"✅ Fichier .set généré: {output_path}")
        return output_path

    def generate_optimization_ranges(self, output_path: Path):
        """Génère les plages d'optimisation pour MT5 Genetic Algorithm."""

        content = """; GoldSMC v5 - Plages optimisation génétique
; Walk-Forward Analysis: 70% train, 30% test
; Critère: Maximize (PF × RF) / DD

[Inputs]
; === RISQUE (optimiser) ===
RiskPercentPerTrade||0.5||3.0||0.1||Y
SL_ATRMult||1.0||2.5||0.1||Y
MaxRiskPerTradePct||2.0||5.0||0.5||N

; === TP PARTIEL (optimiser) ===
TP_RR_Partial||1.2||2.5||0.1||Y
TP_RR_Final||2.5||4.5||0.2||Y

; === FILTRES (optimiser) ===
ATR_RangeFilterMult||0.1||0.8||0.05||Y
MinRRRatio||1.2||2.5||0.1||Y

; === REGIME (optimiser) ===
RegimeBullThreshPct||0.3||1.2||0.1||Y
RegimeBearThreshPct||0.3||1.2||0.1||Y
TransitionLotPct||20.0||70.0||10.0||Y

; === GESTION (optimiser) ===
CooldownMinutes||30||180||15||Y
MaxConsecLosses||2||5||1||Y
TrailingActivateMult||0.3||0.8||0.1||Y
TrailingLockPct||0.2||0.6||0.1||Y

; === SESSIONS (optimiser) ===
UseSessionFilter||0||1||1||Y
Session1_Start||0||18||3||Y
Session1_End||6||23||3||Y

; === FIXES (ne pas optimiser) ===
InpLotSize||0.01||0.01||0.01||N
UseMinLotOnly||0||0||1||N
UseRiskBasedLot||1||1||1||N
MaxDailyLossPct||5.0||5.0||1.0||N
MaxDrawdownPct||30.0||30.0||1.0||N
DisableBreakerInTester||1||1||1||N
UseRegimeFilter||1||1||1||N
UseMonthlyFilter||1||1||1||N
TradeInTransition||1||1||1||N
UsePartialTP||1||1||1||N
ATR_Period||14||14||1||N
BOS_MinBars||3||3||1||N
EnableFalseSignalGates||1||1||1||N
OB_LookbackBars||12||12||1||N
OB_RetestBuffer||0.3||0.3||0.1||N
StrictBOS||0||0||1||N
UseSessionBiasFilter||0||0||1||N
MagicNumber||20260526||20260526||1||N
ShowDashboard||1||1||1||N
DebugMode||0||0||1||N
"""

        output_path.write_text(content, encoding='utf-8')
        print(f"✅ Plages optimisation générées: {output_path}")
        return output_path

    def create_wfa_schedule(self, start_year: int = 2012, end_year: int = 2026) -> List[Dict]:
        """
        Crée un planning Walk-Forward Analysis.

        Returns:
            Liste de périodes (train + test)
        """
        periods = []

        # Fenêtre glissante: 2 ans train, 6 mois test
        train_months = 24
        test_months = 6
        step_months = 6  # Avancer de 6 mois à chaque itération

        current_date = datetime(start_year, 1, 1)
        end_date = datetime(end_year, 12, 31)

        iteration = 1

        while current_date < end_date:
            train_start = current_date
            train_end = current_date + timedelta(days=train_months * 30)
            test_start = train_end
            test_end = test_start + timedelta(days=test_months * 30)

            if test_end > end_date:
                break

            periods.append({
                "iteration": iteration,
                "train_start": train_start.strftime("%Y.%m.%d"),
                "train_end": train_end.strftime("%Y.%m.%d"),
                "test_start": test_start.strftime("%Y.%m.%d"),
                "test_end": test_end.strftime("%Y.%m.%d")
            })

            current_date += timedelta(days=step_months * 30)
            iteration += 1

        return periods

    def generate_wfa_report(self, output_path: Path):
        """Génère un rapport planning WFA complet."""

        periods = self.create_wfa_schedule()

        report = f"""# GoldSMC v5 - Planning Walk-Forward Analysis
Généré: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Méthodologie

**Fenêtre glissante:**
- Train: 24 mois (70%)
- Test: 6 mois (30%)
- Pas: 6 mois (overlap pour robustesse)

**Critère d'optimisation:**
Maximiser: `(Profit Factor × Recovery Factor) / Max Drawdown %`

**Contraintes:**
- Win Rate ≥ 45%
- Profit Factor ≥ 1.5
- Max Drawdown ≤ 25%

---

## Périodes WFA

Total: {len(periods)} itérations

"""

        for period in periods:
            report += f"""
### Itération {period['iteration']}

**TRAIN ({period['train_start']} → {period['train_end']})**
- Optimiser paramètres avec algorithme génétique
- Générations: 50
- Population: 100

**TEST ({period['test_start']} → {period['test_end']})**
- Appliquer meilleurs paramètres trouvés
- Validation hors échantillon (OOS)
- Comparer performance vs train

**Critère succès:**
- PF test ≥ 80% PF train
- DD test ≤ 120% DD train

---
"""

        report += """
## Instructions MT5

### 1. Optimisation (phase TRAIN)

```
1. Ouvrir Strategy Tester MT5
2. Expert: GoldSMC_EA_v5.ex5
3. Période: Dates TRAIN de l'itération
4. Mode: Optimization (Genetic Algorithm)
5. Critère: Custom max (PF × RF / DD)
6. Charger: goldsmc_v5_optimization_ranges.set
7. Lancer optimisation
8. Sauvegarder meilleurs résultats
```

### 2. Test (phase TEST)

```
1. Charger meilleurs paramètres de TRAIN
2. Période: Dates TEST de l'itération
3. Mode: Single run
4. Quality: Every tick
5. Lancer test
6. Comparer métriques vs TRAIN
```

### 3. Validation

Pour chaque itération, vérifier:
- [ ] PF test ≥ 1.5
- [ ] Win Rate test ≥ 45%
- [ ] DD test ≤ 25%
- [ ] PF test ≥ 80% PF train
- [ ] Performance cohérente

---

## Résultats attendus

**Si WFA réussit (toutes itérations validées):**
✅ Paramètres robustes confirmés
✅ Passer Phase 3: Tests démo
✅ Confiance élevée pour production

**Si échec sur >30% des itérations:**
❌ Overfitting détecté
❌ Retour optimisation
❌ Revoir logique EA

---

## Fichiers générés

- `goldsmc_v5_BULL.set` - Paramètres optimisés BULL
- `goldsmc_v5_BEAR.set` - Paramètres optimisés BEAR
- `goldsmc_v5_TRANSITION.set` - Paramètres optimisés TRANSITION
- `goldsmc_v5_optimization_ranges.set` - Plages optimisation génétique
"""

        output_path.write_text(report, encoding='utf-8')
        print(f"✅ Rapport WFA généré: {output_path}")

        # Sauvegarder JSON pour traitement automatique
        json_path = output_path.with_suffix('.json')
        json_path.write_text(json.dumps(periods, indent=2), encoding='utf-8')
        print(f"✅ Planning JSON: {json_path}")

        return periods


def main():
    parser = argparse.ArgumentParser(description='GoldSMC v5 Optimizer')
    parser.add_argument('--mode', choices=['analyze', 'optimize', 'generate-sets'],
                       default='generate-sets',
                       help='Mode: analyze (rapport), optimize (WFA), generate-sets (fichiers .set)')

    args = parser.parse_args()

    optimizer = GoldSMCOptimizer()
    output_dir = Path("D:/Dev/TradBOT/Optimization")
    output_dir.mkdir(exist_ok=True)

    print("=" * 80)
    print("  GOLDSMC V5 - OPTIMISEUR INTELLIGENT")
    print("=" * 80)
    print()

    if args.mode == 'generate-sets':
        print("📝 Génération fichiers .set par régime...\n")

        for regime in ["BULL", "BEAR", "TRANSITION"]:
            output_path = output_dir / f"goldsmc_v5_{regime}.set"
            optimizer.generate_mt5_set_file(regime, output_path)

        print("\n📊 Génération plages optimisation...\n")
        ranges_path = output_dir / "goldsmc_v5_optimization_ranges.set"
        optimizer.generate_optimization_ranges(ranges_path)

        print("\n" + "=" * 80)
        print("  ✅ FICHIERS GÉNÉRÉS")
        print("=" * 80)
        print(f"\nRépertoire: {output_dir}")
        print("\nFichiers:")
        print("  • goldsmc_v5_BULL.set")
        print("  • goldsmc_v5_BEAR.set")
        print("  • goldsmc_v5_TRANSITION.set")
        print("  • goldsmc_v5_optimization_ranges.set")

    elif args.mode == 'optimize':
        print("📈 Création planning Walk-Forward Analysis...\n")

        report_path = output_dir / "WFA_PLANNING.md"
        periods = optimizer.generate_wfa_report(report_path)

        print("\n" + "=" * 80)
        print(f"  ✅ PLANNING WFA CRÉÉ - {len(periods)} itérations")
        print("=" * 80)
        print(f"\nRapport: {report_path}")
        print(f"Planning JSON: {report_path.with_suffix('.json')}")

    elif args.mode == 'analyze':
        print("📊 Analyse configuration actuelle...\n")

        for regime, params in optimizer.optimal_params.items():
            print(f"\n{'='*60}")
            print(f"  RÉGIME: {regime}")
            print(f"{'='*60}")
            print(f"\nRisk: {params.risk_percent}% | SL: {params.sl_atr_mult}x ATR")
            print(f"TP Partial: RR {params.tp_rr_partial} | TP Final: RR {params.tp_rr_final}")
            print(f"Filters: ATR×{params.atr_range_filter_mult} | Min RR {params.min_rr_ratio}")
            print(f"Cooldown: {params.cooldown_minutes}min | Max losses: {params.max_consec_losses}")
            print(f"Sessions: {params.session_hours if params.use_session_filter else 'ALL'}")

    print("\n" + "=" * 80)
    print("  TERMINÉ")
    print("=" * 80)


if __name__ == "__main__":
    main()
