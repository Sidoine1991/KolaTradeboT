# Test minimal pour vérifier l'import de MT5
import sys
print("Python version:", sys.version)
print("Testing MetaTrader5 import...")

try:
    import MetaTrader5 as mt5
    print("MetaTrader5 imported successfully!")
    
    # Test de connexion basique
    print("Initializing MT5...")
    if mt5.initialize():
        print("MT5 initialized successfully!")
        print("MT5 version:", mt5.version())
        mt5.shutdown()
    else:
        print("Failed to initialize MT5:", mt5.last_error())
    
except ImportError as e:
    print("Error importing MetaTrader5:", e)
    
except Exception as e:
    print("Unexpected error:", e)

print("Test completed")
