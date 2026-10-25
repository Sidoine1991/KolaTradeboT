"""Regression coverage for the poller's calculator import path."""

import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_poller_loads_python_calculator_before_stale_root_copy():
    script = r"""
import importlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path[0] = str(root / "python")
importlib.import_module("gom_mt5_poller")

calculator = importlib.import_module("gom_pine_calculator")
assert Path(calculator.__file__).resolve() == (
    root / "python" / "gom_pine_calculator.py"
).resolve()
assert callable(calculator.apply_current_market_forecast_gate)
"""
    result = subprocess.run(
        [sys.executable, "-c", script, str(ROOT)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        env=os.environ.copy(),
        check=False,
    )

    assert result.returncode == 0, result.stderr or result.stdout
