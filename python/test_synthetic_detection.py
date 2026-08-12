#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tests unitaires pour is_synthetic_symbol — détection des instruments
synthétiques (Deriv + Weltrade) servant au bypass du correction-WAIT overlay.

Couvre :
  1. Deriv Volatility Index (ex: "Volatility 75 Index")
  2. Deriv Boom / Crash Index
  3. Deriv Jump / Step / Range Break
  4. Weltrade FXVOL / SFVVOL / SFXVOL / PAINX / GAINX / TRENDX / BREAKX
  5. Non-synthétiques (forex, métaux, crypto) → False
  6. Cas limites : casse, espaces, valeurs vides
"""

import sys
import os
import unittest
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from symbol_mapper import is_synthetic_symbol


class TestDerivVolatility(unittest.TestCase):
    def test_volatility_index(self):
        assert is_synthetic_symbol("Volatility 75 Index") is True

    def test_volatility_100_index(self):
        assert is_synthetic_symbol("Volatility 100 Index") is True

    def test_volatility_with_1s_suffix(self):
        assert is_synthetic_symbol("Volatility 75 (1s) Index") is True

    def test_volatility_case_insensitive(self):
        assert is_synthetic_symbol("VOLATILITY 75 INDEX") is True
        assert is_synthetic_symbol("volatility 75 index") is True


class TestDerivBoomCrash(unittest.TestCase):
    def test_boom_index(self):
        assert is_synthetic_symbol("Boom 500 Index") is True

    def test_crash_index(self):
        assert is_synthetic_symbol("Crash 300 Index") is True

    def test_boom_lowercase(self):
        assert is_synthetic_symbol("boom 500 index") is True


class TestDerivJumpStepRange(unittest.TestCase):
    def test_jump_index(self):
        assert is_synthetic_symbol("Jump 10 Index") is True

    def test_step_index(self):
        assert is_synthetic_symbol("Step Index") is True

    def test_range_break_index(self):
        assert is_synthetic_symbol("Range Break 100 Index") is True


class TestWeltrade(unittest.TestCase):
    def test_fxvol(self):
        assert is_synthetic_symbol("FXVOL") is True

    def test_sfvvox(self):
        assert is_synthetic_symbol("SFVVOL") is True

    def test_sfxvol(self):
        assert is_synthetic_symbol("SFXVOL") is True

    def test_painx(self):
        assert is_synthetic_symbol("PAINX V75") is True
        assert is_synthetic_symbol("PainX") is True

    def test_gainx(self):
        assert is_synthetic_symbol("GAINX V100") is True
        assert is_synthetic_symbol("GainX") is True

    def test_trendx_breakx(self):
        assert is_synthetic_symbol("TRENDX") is True
        assert is_synthetic_symbol("BREAKX") is True


class TestNonSynthetic(unittest.TestCase):
    def test_forex_pairs(self):
        for sym in ("EURUSD", "GBPUSD", "XAUUSD", "BTCUSD", "US30_X10"):
            assert is_synthetic_symbol(sym) is False, sym

    def test_emtpy_and_none(self):
        assert is_synthetic_symbol("") is False
        assert is_synthetic_symbol(None) is False

    def test_plain_word_vol(self):
        # "VOL" seul ne doit pas suffire (pas de numéro/index)
        assert is_synthetic_symbol("VOL") is False


if __name__ == "__main__":
    import unittest

    unittest.main(verbosity=2)
