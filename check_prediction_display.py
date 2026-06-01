#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Vérifie si les prédictions sont affichées sur TradingView
"""

import sys
import os

if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

print("[CHECK] Prediction Display on TradingView")
print("=" * 70)

# Utiliser les MCP tools de TradingView
print("\n[STEP 1] Get chart state...")

try:
    from mcp__tradingview_kola__chart_get_state import chart_get_state
    state = chart_get_state()

    print(f"  Symbol: {state.get('symbol', 'N/A')}")
    print(f"  Timeframe: {state.get('timeframe', 'N/A')}")
    print(f"  Indicators: {len(state.get('indicators', []))} visible")

    # Chercher GOM KOLA
    gom_found = False
    for ind in state.get('indicators', []):
        if 'GOM' in ind.get('name', ''):
            print(f"  [OK] GOM indicator found: {ind['name']}")
            gom_found = True

            # Afficher les paramètres
            inputs = ind.get('inputs', {})
            print(f"      path_show_candles: {inputs.get('path_show_candles', 'N/A')}")
            print(f"      path_candle_vis: {inputs.get('path_candle_vis', 'N/A')}")
            break

    if not gom_found:
        print("  [ERROR] GOM KOLA indicator NOT found on chart")
        print("  Action: Add GOM_KOLA_SIDO indicator to chart")

except Exception as e:
    print(f"  [ERROR] {e}")

# Récupérer les Box dessins (bougies prédites)
print("\n[STEP 2] Check Pine Script boxes (predicted candles)...")

try:
    from mcp__tradingview_kola__data_get_pine_boxes import data_get_pine_boxes
    boxes = data_get_pine_boxes(study_filter="GOM KOLA", verbose=True)

    box_count = len(boxes.get('boxes', []))
    print(f"  [OK] Found {box_count} boxes (predicted candles)")

    if box_count > 0:
        print(f"  [SUCCESS] Predictions ARE being drawn")

        # Afficher les premiers et derniers
        all_boxes = boxes.get('boxes', [])
        if len(all_boxes) > 0:
            print(f"\n  First box: high={all_boxes[0].get('high')}, low={all_boxes[0].get('low')}")
            print(f"  Last box:  high={all_boxes[-1].get('high')}, low={all_boxes[-1].get('low')}")
    else:
        print(f"  [WARNING] No boxes found - predictions not drawn")
        print(f"  Possible causes:")
        print(f"    1. path_show_candles = false in Pine settings")
        print(f"    2. path_candle_vis too small (increase to 200)")
        print(f"    3. Need to scroll right to see future predictions")

except Exception as e:
    print(f"  [ERROR] {e}")

# Récupérer les labels (scores)
print("\n[STEP 3] Check Pine Script labels (confidence scores)...")

try:
    from mcp__tradingview_kola__data_get_pine_labels import data_get_pine_labels
    labels = data_get_pine_labels(study_filter="GOM KOLA", max_labels=50)

    label_count = len(labels.get('labels', []))
    print(f"  [OK] Found {label_count} labels")

    if label_count > 0:
        print(f"  [SUCCESS] Confidence labels ARE visible")
        for label in labels.get('labels', [])[:5]:
            print(f"    - {label.get('text', 'N/A')}")
    else:
        print(f"  [WARNING] No labels found")

except Exception as e:
    print(f"  [ERROR] {e}")

print("\n" + "=" * 70)
print("[DIAGNOSIS]")
print("""
If predictions are NOT showing:

1. CHECK PINE SETTINGS:
   - Open GOM_KOLA_SIDO indicator settings
   - Enable: "Bougies predites (fantomes)" ✓
   - Set: "Nb bougies fantomes visibles" = 200

2. CHECK CHART VIEW:
   - Make sure you can see FUTURE bars (scroll right)
   - Zoom out if needed to see 200+ bars ahead

3. CHECK SYMBOL:
   - Verify chart is on XAUUSD/EURUSD/GBPUSD (Top 3 symbols)
   - If symbol changed, pollers may not have data

4. RECOMPILE:
   - Open Pine Script editor (Alt+A)
   - Click Add to Chart or Save + Compile
   - Watch for compilation errors
""")
