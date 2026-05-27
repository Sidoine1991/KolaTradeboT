"""Test du module bridge_enhancements"""

import sys
import io
from pathlib import Path

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

sys.path.insert(0, str(Path(__file__).parent / "Python"))

from bridge_enhancements import (
    calculate_lot_size_for_account,
    ACCOUNT_SIZES,
    SUPPORTED_LANGUAGES,
    t
)

print("="*70)
print("  TEST MODULE BRIDGE_ENHANCEMENTS")
print("="*70)

# Test 1: Calcul lot size
print("\n📊 TEST 1: Calcul Lot Size pour XAUUSD")
print("-"*70)

symbol = "XAUUSD"
entry = 4570.0
sl = 4590.0

for size in ["small", "medium", "large"]:
    result = calculate_lot_size_for_account(entry, sl, size, symbol)
    print(f"\n{ACCOUNT_SIZES[size]['label']}:")
    print(f"  Capital: ${result['capital']}")
    print(f"  Risque: {result['risk_pct']}% = ${result['risk_usd']:.2f}")
    print(f"  Lot size: {result['lot']:.2f}")
    print(f"  SL distance: {result['sl_distance_pips']:.1f} pips")
    print(f"  Perte potentielle: -${result['potential_loss']:.2f}")

# Test 2: Traductions
print("\n\n🌍 TEST 2: Traductions Multi-langues")
print("-"*70)

for lang in ["FR", "EN", "ES", "AR"]:
    print(f"\n{lang} ({SUPPORTED_LANGUAGES[lang]}):")
    print(f"  Titre: {t('title', lang)}")
    print(f"  Signal: {t('signal_section', lang)}")
    print(f"  Décision: {t('decision', lang)}")
    print(f"  Conclusion: {t('conclusion_section', lang)}")

# Test 3: Calcul pour EURUSD (paires Forex)
print("\n\n💱 TEST 3: Calcul Lot Size pour EURUSD")
print("-"*70)

symbol = "EURUSD"
entry = 1.0500
sl = 1.0450  # 50 pips SL

for size in ["small", "medium", "large"]:
    result = calculate_lot_size_for_account(entry, sl, size, symbol)
    print(f"\n{ACCOUNT_SIZES[size]['label']}:")
    print(f"  Lot size: {result['lot']:.2f}")
    print(f"  SL distance: {result['sl_distance_pips']:.1f} pips")

print("\n" + "="*70)
print("  ✅ TOUS LES TESTS RÉUSSIS")
print("="*70)
