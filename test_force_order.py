#!/usr/bin/env python3
"""
Forcer un ordre pour tester si ça marche vraiment
"""
import MetaTrader5 as mt5
import time

def test_force_order():
    print("=" * 60)
    print("TEST FORCER ORDRE (CONTOURNER VÉRIFICATION)")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    symbol = "Boom 300 Index"
    
    # Obtenir les infos
    symbol_info = mt5.symbol_info(symbol)
    tick = mt5.symbol_info_tick(symbol)
    
    if not symbol_info or not tick:
        print(f"❌ Impossible d'obtenir les infos pour {symbol}")
        return
    
    print(f"📊 {symbol}:")
    print(f"   Trade mode: {symbol_info.trade_mode}")
    print(f"   Ask: {tick.ask}")
    print(f"   Volume min: {symbol_info.volume_min}")
    
    # Forcer l'ordre même en mode "Close only"
    print(f"\n🚀 FORCAGE D'ORDRE (malgré mode=4):")
    
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": symbol_info.volume_min,
        "type": mt5.ORDER_TYPE_BUY,
        "price": tick.ask,
        "sl": 0.0,
        "tp": 0.0,
        "deviation": 20,
        "magic": 234000,
        "comment": "FORCE TEST ORDER",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_FOK,
    }
    
    print(f"   Envoi de l'ordre...")
    result = mt5.order_send(request)
    
    if result is None:
        print(f"❌ mt5.order_send() returned None: {mt5.last_error()}")
    elif result.retcode != mt5.TRADE_RETCODE_DONE:
        print(f"❌ Ordre rejeté: {result.retcode} - {result.comment}")
    else:
        print(f"✅ ORDRE RÉUSSI!")
        print(f"   Ticket: {result.order}")
        print(f"   Price: {result.price}")
        print(f"   Volume: {result.volume}")
        
        # Attendre un peu puis fermer
        time.sleep(2)
        
        close_request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": symbol_info.volume_min,
            "type": mt5.ORDER_TYPE_SELL,
            "position": result.order,
            "price": mt5.symbol_info_tick(symbol).bid,
            "deviation": 20,
            "magic": 234000,
            "comment": "CLOSE FORCE TEST",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_FOK,
        }
        
        close_result = mt5.order_send(close_request)
        if close_result and close_result.retcode == mt5.TRADE_RETCODE_DONE:
            print(f"✅ Fermé avec succès")
        else:
            print(f"⚠️  Erreur fermeture: {close_result.retcode if close_result else 'None'}")
    
    mt5.shutdown()

if __name__ == "__main__":
    test_force_order()
