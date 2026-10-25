# Simple test script to check Python environment
print("Python environment test")
print("Importing modules...")

try:
    import os
    import sys
    import logging
    from datetime import datetime, timedelta
    import pandas as pd
    import MetaTrader5 as mt5
    
    print("All required modules imported successfully!")
    print(f"Python version: {sys.version}")
    
    # Test MT5 connection
    print("\nTesting MT5 connection...")
    if mt5.initialize():
        print("MT5 initialized successfully!")
        mt5.shutdown()
    else:
        print(f"Failed to initialize MT5: {mt5.last_error()}")
    
except ImportError as e:
    print(f"Error importing modules: {e}")
    sys.exit(1)

except Exception as e:
    print(f"Unexpected error: {e}")
    sys.exit(1)

print("\nTest completed successfully!")
