"""
Package principal du backend de TradBOT.
Ce fichier permet d'exposer les fonctions et classes principales du backend.
"""

from .mt5_connector import (
    initialize_ml_supertrend,
    get_ml_supertrend_signals,
    get_symbols,
    get_ohlc,
    get_ohlc_range,
    get_all_symbols,
    get_symbols_by_category,
    get_boom_crash_symbols,
    get_forex_pairs,
    get_commodities,
    get_indices,
    get_crypto_pairs,
    get_symbol_info,
    send_order_to_mt5,
    get_current_price,
    is_connected,
    get_account_info,
    get_available_timeframes,
    get_market_overview,
    test_connection,
    get_open_positions,
    get_trade_history,
    calculate_position_size,
    download_all_symbols,
    get_all_symbols_simple
)

__all__ = [
    'initialize_ml_supertrend',
    'get_ml_supertrend_signals',
    'get_symbols',
    'get_ohlc',
    'get_ohlc_range',
    'get_all_symbols',
    'get_symbols_by_category',
    'get_boom_crash_symbols',
    'get_forex_pairs',
    'get_commodities',
    'get_indices',
    'get_crypto_pairs',
    'get_symbol_info',
    'send_order_to_mt5',
    'get_current_price',
    'is_connected',
    'get_account_info',
    'get_available_timeframes',
    'get_market_overview',
    'test_connection',
    'get_open_positions',
    'get_trade_history',
    'calculate_position_size',
    'download_all_symbols',
    'get_all_symbols_simple'
]