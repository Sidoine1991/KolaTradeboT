#!/usr/bin/env python3
"""
Test script to verify MT5 connection and order placement
"""
import MetaTrader5 as mt5
import json
from datetime import datetime

def test_mt5_connection():
    print("=" * 60)
    print("TEST DE CONNEXION METATRADER 5")
    print("=" * 60)
    
    # Initialize MT5 connection
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return False
    
    print("✅ MT5 initialisé avec succès")
    
    # Check connection status
    if not mt5.terminal_info():
        print("❌ Terminal non connecté")
        mt5.shutdown()
        return False
    
    terminal_info = mt5.terminal_info()
    print(f"✅ Terminal connecté: {terminal_info.name}")
    print(f"   Version: {terminal_info.build}")
    print(f"   Connected: {terminal_info.connected}")
    
    # Check account info separately
    account_info = mt5.account_info()
    if account_info is None:
        print("❌ Impossible d'obtenir les infos du compte")
        mt5.shutdown()
        return False
    
    print(f"✅ Compte: {account_info.login}")
    print(f"   Server: {account_info.server}")
    print(f"   Company: {account_info.company}")
    print(f"   Solde: {account_info.balance}")
    print(f"   Equity: {account_info.equity}")
    print(f"   Marge: {account_info.margin}")
    print(f"   Marge libre: {account_info.margin_free}")
    
    # Check symbols
    symbols_to_test = ["Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"]
    
    print("\n" + "=" * 60)
    print("VÉRIFICATION DES SYMBOLES")
    print("=" * 60)
    
    for symbol in symbols_to_test:
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            print(f"❌ Symbole {symbol} non trouvé")
        else:
            print(f"✅ {symbol}:")
            print(f"   Trade mode: {symbol_info.trade_mode}")
            print(f"   Volume min: {symbol_info.volume_min}")
            print(f"   Volume max: {symbol_info.volume_max}")
            print(f"   Volume step: {symbol_info.volume_step}")
            print(f"   Point: {symbol_info.point}")
            print(f"   Digits: {symbol_info.digits}")
            print(f"   Spread: {symbol_info.spread}")
            
            # Check if symbol is visible
            if not symbol_info.visible:
                print(f"   ⚠️  Symbole non visible, tentative de l'afficher...")
                if mt5.symbol_select(symbol, True):
                    print(f"   ✅ Symbole maintenant visible")
                else:
                    print(f"   ❌ Impossible d'afficher le symbole")
    
    # Test order placement with minimal parameters
    print("\n" + "=" * 60)
    print("TEST D'ORDRE (SIMULATION)")
    print("=" * 60)
    
    # Try to get current price for Boom 300 Index
    symbol = "Boom 300 Index"
    tick = mt5.symbol_info_tick(symbol)
    
    if tick is None:
        print(f"❌ Impossible d'obtenir le tick pour {symbol}")
    else:
        print(f"✅ Tick {symbol}:")
        print(f"   Bid: {tick.bid}")
        print(f"   Ask: {tick.ask}")
        print(f"   Last: {tick.last}")
        print(f"   Time: {datetime.fromtimestamp(tick.time)}")
        
        # Calculate test order parameters
        lot = 0.1
        point = mt5.symbol_info(symbol).point
        
        # SL/TP distances in points
        sl_distance = 2000  # 2000 points
        tp_distance = 4000  # 4000 points
        
        if tick.ask > 0:  # BUY order
            price = tick.ask
            sl = price - sl_distance * point
            tp = price + tp_distance * point
            order_type = mt5.ORDER_TYPE_BUY
        else:  # SELL order
            price = tick.bid
            sl = price + sl_distance * point
            tp = price - tp_distance * point
            order_type = mt5.ORDER_TYPE_SELL
        
        print(f"\n📝 Paramètres d'ordre test:")
        print(f"   Type: {'BUY' if order_type == mt5.ORDER_TYPE_BUY else 'SELL'}")
        print(f"   Price: {price}")
        print(f"   SL: {sl}")
        print(f"   TP: {tp}")
        print(f"   Volume: {lot}")
        
        # Build request
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": lot,
            "type": order_type,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": 20,
            "magic": 234000,
            "comment": "Test ordre Python",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        
        print(f"\n📋 Requête complète:")
        print(json.dumps(request, indent=2, default=str))
        
        # Check if we can place order (dry run)
        print(f"\n⚠️  TEST SANS PLACER L'ORDRE (pour éviter les risques)")
        print(f"   Pour tester réellement, décommentez la section ci-dessous")
        
        # Uncomment to test real order placement:
        """
        result = mt5.order_send(request)
        if result is None:
            print(f"❌ Erreur ordre: {mt5.last_error()}")
        elif result.retcode != mt5.TRADE_RETCODE_DONE:
            print(f"❌ Ordre rejeté: {result.retcode} - {result.comment}")
        else:
            print(f"✅ Ordre placé: Ticket {result.order}")
            print(f"   Price: {result.price}")
            print(f"   Volume: {result.volume}")
        """
    
    # Shutdown
    mt5.shutdown()
    print("\n✅ Test terminé")
    return True

if __name__ == "__main__":
    test_mt5_connection()
