import sys
import os

# Ajouter le répertoire backend au path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

print("🧪 Test des imports backend")
print("=" * 40)

try:
    from features import compute_features
    print("✅ features.py importé avec succès")
except ImportError as e:
    print(f"❌ Erreur import features.py: {e}")

try:
    from technical_analysis import add_rsi, add_macd, add_bollinger_bands, add_atr, INDICATOR_PARAMS
    print("✅ technical_analysis.py importé avec succès")
except ImportError as e:
    print(f"❌ Erreur import technical_analysis.py: {e}")

try:
    from mt5_connector import connect, get_ohlc
    print("✅ mt5_connector.py importé avec succès")
except ImportError as e:
    print(f"❌ Erreur import mt5_connector.py: {e}")

try:
    from spike_detector import detect_spikes
    print("✅ spike_detector.py importé avec succès")
except ImportError as e:
    print(f"❌ Erreur import spike_detector.py: {e}")

print("\n🎉 Test des imports terminé!") 