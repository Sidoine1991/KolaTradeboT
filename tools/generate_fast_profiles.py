import json
from pathlib import Path


PROFILES = {
    "aggressive": {
        "StrictModeTriggerProfitUSD": 10.0,
        "StrictModeMinAIConfidencePct": 70.0,
        "StrictModeMinSetupScore": 60.0,
        "AdaptiveTradeBudgetMin": 12,
        "AdaptiveTradeBudgetMax": 35,
        "DailyPeakGivebackStopUSD": 6.0,
        "TrailingPhase2LockPct": 0.72,
        "TrailingPhase3LockPct": 0.82,
        "UsePropiceSymbolsFilter": False,
    },
    "balanced": {
        "StrictModeTriggerProfitUSD": 10.0,
        "StrictModeMinAIConfidencePct": 75.0,
        "StrictModeMinSetupScore": 65.0,
        "AdaptiveTradeBudgetMin": 10,
        "AdaptiveTradeBudgetMax": 30,
        "DailyPeakGivebackStopUSD": 5.0,
        "TrailingPhase2LockPct": 0.75,
        "TrailingPhase3LockPct": 0.85,
        "UsePropiceSymbolsFilter": False,
    },
    "defensive": {
        "StrictModeTriggerProfitUSD": 10.0,
        "StrictModeMinAIConfidencePct": 82.0,
        "StrictModeMinSetupScore": 72.0,
        "AdaptiveTradeBudgetMin": 8,
        "AdaptiveTradeBudgetMax": 22,
        "DailyPeakGivebackStopUSD": 3.8,
        "TrailingPhase2LockPct": 0.80,
        "TrailingPhase3LockPct": 0.90,
        "UsePropiceSymbolsFilter": False,
    },
}


WALK_FORWARD_MATRIX = [
    {"name": "wf_1", "from": "2025-01-01", "to": "2025-03-01", "oos_from": "2025-03-01", "oos_to": "2025-04-01"},
    {"name": "wf_2", "from": "2025-03-01", "to": "2025-05-01", "oos_from": "2025-05-01", "oos_to": "2025-06-01"},
    {"name": "wf_3", "from": "2025-05-01", "to": "2025-07-01", "oos_from": "2025-07-01", "oos_to": "2025-08-01"},
]


def main() -> None:
    out_dir = Path(__file__).resolve().parents[1] / "tools" / "out_profiles"
    out_dir.mkdir(parents=True, exist_ok=True)

    profiles_file = out_dir / "fast_profiles.json"
    matrix_file = out_dir / "walk_forward_matrix.json"

    profiles_file.write_text(json.dumps(PROFILES, indent=2), encoding="utf-8")
    matrix_file.write_text(json.dumps(WALK_FORWARD_MATRIX, indent=2), encoding="utf-8")

    print(f"Wrote profiles: {profiles_file}")
    print(f"Wrote walk-forward matrix: {matrix_file}")
    print("\nCopy each profile values into MT5 Inputs and run Stage 1 -> Stage 2 -> Stage 3.")


if __name__ == "__main__":
    main()
