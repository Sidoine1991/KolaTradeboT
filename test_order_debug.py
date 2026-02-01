#!/usr/bin/env python3
"""
Test de diagnostic pour mt5.order_send()
"""
import MetaTrader5 as mt5
import time

def test_order_debug():
    print("=" * 60)
    print("DIAGNOSTIC MT5.ORDER_SEND()")
    print("=" * 60)
    
    if not mt5.initialize():
        print("❌ Erreur MT5")
        return
    
    # Test avec Boom 300 Index
    symbol = "Boom 300 Index"
    symbol_info = mt5.symbol_info(symbol)
    tick = mt5.symbol_info_tick(symbol)
    
    print(f"📊 {symbol}:")
    print(f"   Trade mode: {symbol_info.trade_mode}")
    print(f"   Ask: {tick.ask}")
    print(f"   Volume min: {symbol_info.volume_min}")
    
    # Test 1: Requête minimale sans SL/TP
    print(f"\n🧪 Test 1: Ordre minimal SELL")
    request1 = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": symbol_info.volume_min,
        "type": mt5.ORDER_TYPE_SELL,
        "price": tick.bid,
        "sl": 0.0,
        "tp": 0.0,
        "deviation": 20,
        "magic": 234000,
        "comment": "TEST MINIMAL",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_FOK,
    }
    
    print(f"   Envoi...")
    result1 = mt5.order_send(request1)
    
    if result1 is None:
        print(f"   ❌ mt5.order_send() returned None")
        print(f"   Dernière erreur: {mt5.last_error()}")
    elif result1.retcode == mt5.TRADE_RETCODE_DONE:
        print(f"   ✅ SUCCÈS! Ticket: {result1.order}")
        # Fermer immédiatement
        close_request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": symbol_info.volume_min,
            "type": mt5.ORDER_TYPE_BUY,
            "position": result1.order,
            "price": tick.ask,
            "deviation": 20,
            "magic": 234000,
            "comment": "CLOSE TEST",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_FOK,
        }
        close_result = mt5.order_send(close_request)
        if close_result and close_result.retcode == mt5.TRADE_RETCODE_DONE:
            print(f"   ✅ Fermé avec succès")
    else:
        print(f"   ❌ Rejeté: {result1.retcode} - {result1.comment}")
    
    # Test 2: Requête avec SL/TP
    print(f"\n🧪 Test 2: Ordre avec SL/TP")
    sl = tick.bid + (tick.bid * 0.02)  # 2%
    tp = tick.bid - (tick.bid * 0.08)  # 8%
    
    request2 = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": symbol_info.volume_min,
        "type": mt5.ORDER_TYPE_SELL,
        "price": tick.bid,
        "sl": sl,
        "tp": tp,
        "deviation": 20,
        "magic": 234000,
        "comment": "TEST SLTP",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_FOK,
    }
    
    print(f"   SL: {sl}, TP: {tp}")
    print(f"   Envoi...")
    result2 = mt5.order_send(request2)
    
    if result2 is None:
        print(f"   ❌ mt5.order_send() returned None")
        print(f"   Dernière erreur: {mt5.last_error()}")
    elif result2.retcode == mt5.TRADE_RETCODE_DONE:
        print(f"   ✅ SUCCÈS! Ticket: {result2.order}")
        # Fermer immédiatement
        close_request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": symbol_info.volume_min,
            "type": mt5.ORDER_TYPE_BUY,
            "position": result2.order,
            "price": tick.ask,
            "deviation": 20,
            "magic": 234000,
            "comment": "CLOSE TEST SLTP",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_FOK,
        }
        close_result = mt5.order_send(close_request)
        if close_result and close_result.retcode == mt5.TRADE_RETCODE_DONE:
            print(f"   ✅ Fermé avec succès")
    else:
        print(f"   ❌ Rejeté: {result2.retcode} - {result2.comment}")
    
    mt5.shutdown()
    print(f"\n✅ Diagnostic terminé")

if __name__ == "__main__":
    test_order_debug()
