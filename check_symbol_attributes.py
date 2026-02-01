#!/usr/bin/env python3
"""
Script pour vérifier les attributs disponibles de SymbolInfo
"""

import MetaTrader5 as mt5

def check_symbol_attributes(symbol):
    """Vérifie tous les attributs d'un symbole"""
    try:
        symbol_info = mt5.symbol_info(symbol)
        if not symbol_info:
            print(f"Symbole {symbol} non disponible")
            return
        
        print(f"\n=== {symbol} ===")
        print("Attributs disponibles:")
        
        # Lister tous les attributs
        attributes = [attr for attr in dir(symbol_info) if not attr.startswith('_')]
        
        # Afficher les attributs pertinents pour SL/TP
        relevant_attrs = [
            'description', 'point', 'volume_min', 'volume_max', 'volume_step',
            'trade_mode', 'trade_contracts_size', 'margin_initial', 'margin_maintenance',
            'freeze_level', 'swap_long', 'swap_short', 'swap_rollover3days'
        ]
        
        for attr in relevant_attrs:
            if hasattr(symbol_info, attr):
                value = getattr(symbol_info, attr)
                print(f"  {attr}: {value}")
        
        # Vérifier s'il y a des attributs liés aux stops
        stop_attrs = [attr for attr in attributes if 'stop' in attr.lower() or 'level' in attr.lower()]
        if stop_attrs:
            print("Attributs liés aux stops:")
            for attr in stop_attrs:
                value = getattr(symbol_info, attr)
                print(f"  {attr}: {value}")
        
    except Exception as e:
        print(f"Erreur: {e}")

def main():
    """Fonction principale"""
    print("VÉRIFICATION DES ATTRIBUTS SYMBOLINFO")
    print("="*50)
    
    if not mt5.initialize():
        print("Echec initialisation MT5")
        return
    
    try:
        symbols = ["Boom 300 Index", "EURUSD"]
        
        for symbol in symbols:
            check_symbol_attributes(symbol)
        
    finally:
        mt5.shutdown()

if __name__ == "__main__":
    main()
