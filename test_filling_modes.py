#!/usr/bin/env python3
"""
Tester les différents type_filling pour Boom/Crash
"""
import MetaTrader5 as mt5
import json
from datetime import datetime

def test_filling_modes():
    print("=" * 60)
    print("TEST DES TYPES DE FILLING")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    symbol = "Boom 300 Index"
    tick = mt5.symbol_info_tick(symbol)
    if not tick:
        print(f"❌ Pas de tick pour {symbol}")
        return
    
    symbol_info = mt5.symbol_info(symbol)
    volume = symbol_info.volume_min
    
    # Types de filling à tester
    filling_modes = {
        "FOK": mt5.ORDER_FILLING_FOK,      # 0
        "IOC": mt5.ORDER_FILLING_IOC,      # 1  
        "RETURN": mt5.ORDER_FILLING_RETURN  # 2
    }
    
    print(f"📊 Test pour {symbol} (Volume: {volume})")
    print(f"   Ask: {tick.ask}")
    print(f"   Bid: {tick.bid}")
    
    for mode_name, mode_value in filling_modes.items():
        print(f"\n🧪 Test type_filling = {mode_name} ({mode_value}):")
        
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": mt5.ORDER_TYPE_BUY,
            "price": tick.ask,
            "sl": 0.0,
            "tp": 0.0,
            "deviation": 20,
            "magic": 234000,
            "comment": f"Test {mode_name}",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mode_value,
        }
        
        result = mt5.order_send(request)
        
        if result is None:
            print(f"   ❌ mt5.order_send() returned None: {mt5.last_error()}")
        elif result.retcode != mt5.TRADE_RETCODE_DONE:
            print(f"   ❌ Rejeté: {result.retcode} - {result.comment}")
        else:
            print(f"   ✅ SUCCÈS! Ticket: {result.order}")
            
            # Fermer immédiatement
            close_request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": volume,
                "type": mt5.ORDER_TYPE_SELL,
                "position": result.order,
                "price": tick.bid,
                "deviation": 20,
                "magic": 234000,
                "comment": f"Close {mode_name}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mode_value,
            }
            
            close_result = mt5.order_send(close_request)
            if close_result and close_result.retcode == mt5.TRADE_RETCODE_DONE:
                print(f"   ✅ Fermé avec succès")
            else:
                print(f"   ⚠️  Erreur fermeture: {close_result.retcode if close_result else 'None'}")
            
            break  # On a trouvé le bon mode
    
    mt5.shutdown()
    print(f"\n✅ Test terminé")

if __name__ == "__main__":
    test_filling_modes()
