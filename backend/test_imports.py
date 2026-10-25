# Test minimal des imports
import sys
import os

print("=== Test des imports ===")
print(f"Python version: {sys.version}")
print(f"Working directory: {os.getcwd()}")
print("\n=== Liste des fichiers du repertoire courant ===")
print("\n".join(os.listdir('.')))

print("\n=== Test d'import de base ===")
try:
    import pandas as pd
    print("Pandas importe avec succes")
except ImportError as e:
    print(f"Erreur d'import pandas: {e}")

print("\n=== Test d'import de MT5 ===")
try:
    import MetaTrader5 as mt5
    print("MetaTrader5 importe avec succes"
          f"\nVersion MT5: {mt5.__version__}")
except ImportError as e:
    print(f"Erreur d'import MetaTrader5: {e}")

print("\n=== Test d'import des modules locaux ===")
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from core.data_manager import DataManager
    print("DataManager importe avec succes")
except ImportError as e:
    print(f"Erreur d'import DataManager: {e}")

print("\nTest termine")
