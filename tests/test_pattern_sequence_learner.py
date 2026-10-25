"""Markov sequence learner — transitions + prediction."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))

from ml.pattern_sequence_learner import (  # noqa: E402
    apply_to_record,
    current_token,
    observe,
    predict,
)


def test_token_prefers_dominant_side():
    assert current_token("ENGULFING@M1", "") == "BULL:ENGULFING"
    assert current_token("", "THREE_CROWS@M5") == "BEAR:THREE_CROWS"
    assert current_token("", "") == "NEUT:NONE"


def test_learns_next_pattern_and_direction():
    sym = "TESTSEQ1"
    bar = 1_700_000_000
    price = 100.0
    for i in range(12):
        observe(sym, bar + i * 60, price, bull_hits="ENGULFING@M1", bear_hits="")
        price *= 1.001
        observe(sym, bar + i * 60 + 30, price, bull_hits="", bear_hits="THREE_CROWS@M1")
        price *= 0.999
    pred = predict(sym)
    assert pred["n"] >= 8
    rec = {"pattern_score_buy": 0.0, "pattern_score_sell": 0.0}
    apply_to_record(rec, pred)
    assert "pattern_seq_next" in rec
    assert rec["pattern_seq_n"] >= 8


if __name__ == "__main__":
    test_token_prefers_dominant_side()
    test_learns_next_pattern_and_direction()
    print("ok")
