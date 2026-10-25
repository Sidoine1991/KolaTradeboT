"""
MT5 Utilities - Utility functions for MetaTrader 5 connection
"""
import MetaTrader5 as mt5
import os
from dotenv import load_dotenv

load_dotenv()

MT5_LOGIN = int(os.getenv('MT5_LOGIN', 0))
MT5_PASSWORD = os.getenv('MT5_PASSWORD', '')
MT5_SERVER = os.getenv('MT5_SERVER', '')


def get_mt5_connection():
    """
    Establish and return MT5 connection
    
    Returns:
        bool: True if connection successful, False otherwise
    """
    # First initialize MT5 without parameters
    if not mt5.initialize():
        error = mt5.last_error()
        print(f"❌ MT5 initialization failed: {error}")
        return False
    
    # Check if we have credentials configured
    if MT5_LOGIN and MT5_PASSWORD and MT5_SERVER:
        # Connect with provided credentials
        if not mt5.login(login=MT5_LOGIN, password=MT5_PASSWORD, server=MT5_SERVER):
            error = mt5.last_error()
            print(f"❌ MT5 login failed: {error}")
            return False
        print(f"✅ Connected to MT5 with credentials - Server: {MT5_SERVER}")
    else:
        # Use automatic connection (account already connected in MT5)
        account_info = mt5.account_info()
        if account_info is None:
            print("❌ MT5 login failed: No account connected. Please connect to MT5 terminal first.")
            return False
        print(f"✅ Connected to MT5 automatically - Login: {account_info.login}, Server: {account_info.server}")
    
    return True

