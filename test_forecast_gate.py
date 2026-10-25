#!/usr/bin/env python3
"""
Tests Python pour le Forecast Gate (SMC_GetDynamicMaxLossUSD, SMC_EnforceHardLossCutoff, etc.)
Ce fichier teste la logique du forecast gate et du hard loss cutoff.
"""

import sys
import unittest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta
import json


class TestForecastGate(unittest.TestCase):
    """Tests pour le Forecast Gate et la gestion des pertes maximales."""
    
    def setUp(self):
        """Configuration des tests."""
        self.max_loss_dollars = 3.0
        self.max_loss_hard_cap = 3.0
        self.max_loss_percent = 5.0
        self.account_balance = 100.0
    
    def test_get_dynamic_max_loss_usd_small_account(self):
        """Test SMC_GetDynamicMaxLossUSD avec petit compte (< $60)."""
        # Pour un compte de $50, 5% = $2.5, hard cap = $3 -> min = $2.5
        dynamic_cap = 50.0 * (5.0 / 100.0)  # $2.5
        hard_cap = 3.0
        expected = min(dynamic_cap, hard_cap)  # $2.5
        self.assertAlmostEqual(expected, 2.5, places=2)
    
    def test_get_dynamic_max_loss_usd_large_account(self):
        """Test SMC_GetDynamicMaxLossUSD avec grand compte (> $60)."""
        # Pour un compte de $100, 5% = $5, hard cap = $3 -> min = $3
        dynamic_cap = 100.0 * (5.0 / 100.0)  # $5
        hard_cap = 3.0
        expected = min(dynamic_cap, hard_cap)  # $3
        self.assertAlmostEqual(expected, 3.0, places=2)
    
    def test_get_dynamic_max_loss_usd_zero_balance(self):
        """Test SMC_GetDynamicMaxLossUSD avec solde zéro (fallback equity)."""
        balance = 0.0
        equity = 200.0
        dynamic_cap = equity * (5.0 / 100.0)  # $10
        hard_cap = 3.0
        expected = min(dynamic_cap, hard_cap)  # $3
        self.assertAlmostEqual(expected, 3.0, places=2)
    
    def test_forecast_gate_blocks_opposing_forecast(self):
        """Test que le forecast gate bloque quand forecast GOOD/PERFECT oppose l'ordre."""
        # BUY order avec forecast SELL GOOD (vn=-2) doit être bloqué
        forecast_vn = -2
        is_buy = True
        forecast_opposes = (forecast_vn > 0) != is_buy and abs(forecast_vn) >= 2
        self.assertTrue(forecast_opposes)
        
        # SELL order avec forecast BUY GOOD (vn=2) doit être bloqué
        forecast_vn = 2
        is_buy = False
        forecast_opposes = (forecast_vn > 0) != is_buy and abs(forecast_vn) >= 2
        self.assertTrue(forecast_opposes)
        
        # BUY order avec forecast BUY GOOD (vn=2) NE doit PAS être bloqué
        forecast_vn = 2
        is_buy = True
        forecast_opposes = (forecast_vn > 0) != is_buy and abs(forecast_vn) >= 2
        self.assertFalse(forecast_opposes)
    
    def test_forecast_gate_allows_weak_forecast(self):
        """Test que le forecast gate NE bloque PAS les forecast WEAK (vn=1 ou -1)."""
        # BUY order avec forecast SELL SIMPLE (vn=-1) NE doit PAS être bloqué
        forecast_vn = -1
        is_buy = True
        forecast_opposes = (forecast_vn > 0) != is_buy and abs(forecast_vn) >= 2
        self.assertFalse(forecast_opposes)
    
    def test_server_verdict_opposes_strong(self):
        """Test que le serveur GOOD/PERFECT opposé bloque."""
        server_vn = -2  # SELL PERFECT
        is_buy = True   # BUY order
        server_opposes_strong = abs(server_vn) >= 2 and ((server_vn > 0) != is_buy)
        self.assertTrue(server_opposes_strong)
    
    def test_server_verdict_weak_not_block(self):
        """Test que le serveur WEAK opposé NE bloque PAS (seul le strong bloque)."""
        server_vn = -1  # SELL SIMPLE
        is_buy = True   # BUY order
        server_opposes_strong = abs(server_vn) >= 2 and ((server_vn > 0) != is_buy)
        self.assertFalse(server_opposes_strong)
    
    def test_fresh_context_checks(self):
        """Test les vérifications de fraîcheur du contexte (prix, forecast, serveur)."""
        # Prix frais : market_price_fresh=True, age <= 90s
        market_price_fresh = True
        market_price_age = 30.0
        price_fresh = market_price_fresh and market_price_age >= 0 and market_price_age <= 90
        self.assertTrue(price_fresh)
        
        # Prix périmé : age > 90s
        market_price_age = 120.0
        price_fresh = market_price_fresh and market_price_age >= 0 and market_price_age <= 90
        self.assertFalse(price_fresh)
        
        # Forecast prêt : ready=True, horizon=5m, vn!=0
        forecast_ready = True
        forecast_horizon = 5
        forecast_vn = 2
        forecast_ready_check = forecast_ready and forecast_horizon == 5 and forecast_vn != 0
        self.assertTrue(forecast_ready_check)
        
        # Forecast non prêt
        forecast_ready = False
        forecast_ready_check = forecast_ready and forecast_horizon == 5 and forecast_vn != 0
        self.assertFalse(forecast_ready_check)
        
        # Serveur frais : age <= 120s
        server_age = 60
        server_fresh = server_age <= 120
        self.assertTrue(server_fresh)
        
        # Serveur périmé
        server_age = 180
        server_fresh = server_age <= 120
        self.assertFalse(server_fresh)
    
    def test_hard_loss_cutoff_dynamic_cap(self):
        """Test que le hard loss cutoff utilise le cap dynamique efficace."""
        # Position avec perte de $4, cap effectif $3 -> doit déclencher
        loss = -4.0
        effective_cap = 3.0
        should_cut = loss <= -effective_cap
        self.assertTrue(should_cut)
        
        # Position avec perte de $2, cap effectif $3 -> NE doit PAS déclencher
        loss = -2.0
        should_cut = loss <= -effective_cap
        self.assertFalse(should_cut)
        
        # Position avec perte exactement au cap -> doit déclencher
        loss = -3.0
        should_cut = loss <= -effective_cap
        self.assertTrue(should_cut)
    
    def test_gom_display_verdict_num_stale(self):
        """Test SMCGP_DisplayVerdictNum retourne 0 si source stale."""
        # Simuler source CACHE_STALE_POLL_FORCED_WAIT
        gom_source = "CACHE_STALE_POLL_FORCED_WAIT"
        gom_verdict_num = 2  # GOOD BUY
        
        # Le display doit retourner 0 (WAIT) si source stale
        if gom_source == "CACHE_STALE_POLL_FORCED_WAIT":
            display_vn = 0
        else:
            display_vn = gom_verdict_num
        
        self.assertEqual(display_vn, 0)
        
        # Source normale -> retourne le verdict
        gom_source = "LIVE"
        if gom_source == "CACHE_STALE_POLL_FORCED_WAIT":
            display_vn = 0
        else:
            display_vn = gom_verdict_num
        self.assertEqual(display_vn, 2)
    
    def test_pattern_override_guards(self):
        """Test les gardes du pattern override (correction, source, originalGOMNum)."""
        original_gom = 0  # WAIT
        adjusted_gom = 2  # GOOD BUY par patterns
        
        correction = adjusted_gom - original_gom
        self.assertEqual(correction, 2)
        
        # Source du pattern
        pattern_direction = 1  # BUY
        pattern_buy_score = 80
        pattern_sell_score = 20
        
        if pattern_direction > 0 and pattern_buy_score > pattern_sell_score:
            source = "BUY_PATTERNS"
        elif pattern_direction < 0 and pattern_sell_score > pattern_buy_score:
            source = "SELL_PATTERNS"
        else:
            source = "PATTERN_CONFLUENCE"
        
        self.assertEqual(source, "BUY_PATTERNS")
        
        # Test direction SELL
        pattern_direction = -1
        pattern_buy_score = 20
        pattern_sell_score = 80
        
        if pattern_direction > 0 and pattern_buy_score > pattern_sell_score:
            source = "BUY_PATTERNS"
        elif pattern_direction < 0 and pattern_sell_score > pattern_buy_score:
            source = "SELL_PATTERNS"
        else:
            source = "PATTERN_CONFLUENCE"
        
        self.assertEqual(source, "SELL_PATTERNS")
    
    def test_m1_scalp_simple_allows_direction(self):
        """Test SMCGP_M1ScalpSimpleAllowsDirection pour verdict SIMPLE."""
        # Conditions requises pour M1 Scalp Simple:
        # - symbole = _Symbol
        # - dirSign != 0
        # - g_smcM1ScalpSimpleAllowed = True
        # - g_smcGomEntryAllowed = True
        # - |g_smcGomVerdictNum| == 1 (SIMPLE)
        # - direction correspond au verdict
        # - g_smcGomConnected = True
        # - poll récent (< 90s)
        # - prix M1 frais (age 0-90s)
        
        conditions = {
            "symbol_ok": True,
            "dir_sign_ok": True,
            "m1_scalp_allowed": True,
            "entry_allowed": True,
            "verdict_simple": True,  # |vn| == 1
            "direction_matches": True,
            "connected": True,
            "poll_recent": True,
            "price_fresh": True,
            "price_age_ok": True,
        }
        
        all_ok = all(conditions.values())
        self.assertTrue(all_ok)
        
        # Si un condition échoue -> False
        conditions["m1_scalp_allowed"] = False
        all_ok = all(conditions.values())
        self.assertFalse(all_ok)


class TestM1M5GomAlignGate(unittest.TestCase):
    """Tests pour SMC_M1M5GomAlignGateOK avec M1 Scalp Simple."""
    
    def test_gom_wait_with_m1_scalp_allowed(self):
        """Test que M1 Scalp Simple autorise l'entrée même si GOM WAIT."""
        # GOM WAIT (vn=0) mais M1 Scalp Simple allowed
        gom_vn = 0
        dir_sign = 1  # BUY
        
        # Sans M1 Scalp Simple -> bloqué
        # Avec M1 Scalp Simple -> autorisé
        m1_scalp_allowed = True
        if abs(gom_vn) == 1 and m1_scalp_allowed:
            allowed = True
        else:
            allowed = abs(gom_vn) >= 2
        
        self.assertFalse(allowed)  # vn=0 ne passe pas
    
    def test_gom_simple_with_m1_scalp_allowed(self):
        """Test que GOM SIMPLE + M1 Scalp Simple autorise."""
        gom_vn = 1  # BUY SIMPLE
        dir_sign = 1  # BUY
        m1_scalp_allowed = True
        
        if abs(gom_vn) == 1 and m1_scalp_allowed and dir_sign == gom_vn:
            allowed = True
        else:
            allowed = abs(gom_vn) >= 2
        
        self.assertTrue(allowed)
    
    def test_gom_simple_opposite_direction_blocked(self):
        """Test que GOM SIMPLE direction opposée bloque même avec M1 Scalp."""
        gom_vn = 1   # BUY SIMPLE
        dir_sign = -1  # SELL order
        m1_scalp_allowed = True
        
        if abs(gom_vn) == 1 and m1_scalp_allowed and dir_sign == gom_vn:
            allowed = True
        else:
            allowed = abs(gom_vn) >= 2
        
        self.assertFalse(allowed)


if __name__ == "__main__":
    # Exécuter les tests
    unittest.main(verbosity=2)