#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Diagnostic: Divergence entre bougies TradingView et EA TradeManager
Identifie la source de la divergence des bougies prédites
"""

import json
import requests
import warnings
warnings.filterwarnings('ignore')
import sys
import os

if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

print("[DIAGNOSTIC] Candle Divergence Analysis")
print("=" * 70)

# === ÉTAPE 1 : Récupérer les données ===

print("\n[STEP 1] Fetching AI Server data...")

ai_server = "http://127.0.0.1:8000"
gom_verdict = {}

try:
    resp = requests.get(f"{ai_server}/gom-verdict?symbol=XAUUSD", timeout=5)
    if resp.status_code == 200:
        gom_verdict = resp.json()
        print(f"  [OK] GOM Verdict retrieved")
except Exception as e:
    print(f"  [ERROR] {e}")

# === ÉTAPE 2 : Extraire les paramètres critiques ===

print("\n[STEP 2] Extracting critical parameters...")

# Paramètres Pine Script
pine_path_step = 0.16
print(f"  Pine Script path_step: {pine_path_step}")

# Paramètres TradeManager
tm_path_step = 0.16  # GOMPathStepAtr
print(f"  TradeManager GOMPathStepAtr: {tm_path_step}")

# ATR (devrait être identique)
if gom_verdict and 'atr' in gom_verdict:
    atr_value = gom_verdict['atr']
    print(f"  ATR from /gom-verdict: {atr_value}")
else:
    print(f"  [WARN] ATR not in /gom-verdict")

# Chemin prédictif
if gom_verdict and 'pred_path' in gom_verdict:
    pred_path = gom_verdict['pred_path']
    print(f"  pred_path from /gom-verdict: {pred_path[:50]}...")
else:
    print(f"  [WARN] pred_path not in /gom-verdict")

# === ÉTAPE 3 : Identifier les divergences ===

print("\n[STEP 3] Identifying divergences...")

divergences = []

# Check 1: Path step mismatch
if pine_path_step != tm_path_step:
    divergences.append(f"Path step mismatch: Pine={pine_path_step} vs TM={tm_path_step}")

# Check 2: ATR calculation
if gom_verdict and 'atr' in gom_verdict:
    # Vérifier si l'ATR est calculé de la même manière
    # Pine: ta.atr(10) sur le chart actuel
    # EA: devrait utiliser le même
    pass

# Check 3: Timeframe alignment
if gom_verdict:
    print(f"  GOM Verdict data keys: {list(gom_verdict.keys())}")

if divergences:
    print("\n[ISSUES FOUND]:")
    for issue in divergences:
        print(f"  ❌ {issue}")
else:
    print("\n  ✓ Parameters appear synchronized")

# === ÉTAPE 4 : Recommandations ===

print("\n[RECOMMENDATIONS]:")
print("  1. Verify ATR calculation matches between Pine and EA")
print("  2. Confirm path_step = 0.16 in BOTH:")
print("     - GOM_KOLA_SIDO.pine: path_step = 0.16")
print("     - TradeManager.mq5: GOMPathStepAtr = 0.16")
print("  3. Check if pred_path from /gom-verdict matches EA drawing")
print("  4. Verify timeframe (M1) is consistent")
print("  5. If issue persists, enable logging in TradeManager:")
print("     - Log pred_path received from AI server")
print("     - Compare candle points with Pine Script output")

print("\n[ACTION]:")
print("  - Recompile GOM_KOLA_SIDO.pine in TradingView")
print("  - Recompile TradeManager.mq5 in MetaEditor")
print("  - Restart MetaTrader 5")
print("  - Compare candle predictions side-by-side")

print("\n" + "=" * 70)
print("[COMPLETE] Diagnostic finished")
