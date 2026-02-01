#!/usr/bin/env python3
"""
Fermer immédiatement la position dangereuse sans SL/TP
"""
import MetaTrader5 as mt5

def close_dangerous_position():
    print("🚨 FERMETURE POSITION DANGEREUSE SANS SL/TP")
    
    if not mt5.initialize():
        print("❌ Erreur MT5")
        return
    
    ticket = 5543937478
    position = mt5.positions_get(ticket=ticket)
    
    if not position:
        print("❌ Position non trouvée")
        mt5.shutdown()
        return
    
    pos = position[0]
    print(f"📊 Position trouvée:")
    print(f"   Ticket: {pos.ticket}")
    print(f"   Symbol: {pos.symbol}")
    print(f"   Type: {'SELL' if pos.type == mt5.POSITION_TYPE_SELL else 'BUY'}")
    print(f"   Price: {pos.price_open}")
    print(f"   SL: {pos.sl} (DANGEREUX!)")
    print(f"   TP: {pos.tp} (DANGEREUX!)")
    print(f"   Profit: {pos.profit}")
    
    # Obtenir le prix actuel
    tick = mt5.symbol_info_tick(pos.symbol)
    if not tick:
        print("❌ Pas de tick")
        mt5.shutdown()
        return
    
    # Ordre de fermeture
    close_request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": pos.symbol,
        "volume": pos.volume,
        "type": mt5.ORDER_TYPE_BUY if pos.type == mt5.POSITION_TYPE_SELL else mt5.ORDER_TYPE_SELL,
        "position": pos.ticket,
        "price": tick.ask if pos.type == mt5.POSITION_TYPE_SELL else tick.bid,
        "deviation": 20,
        "magic": 234000,
        "comment": "CLOSE DANGEROUS POSITION - NO SL/TP",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_FOK,
    }
    
    print(f"\n🔄 Fermeture en cours...")
    result = mt5.order_send(close_request)
    
    if result and result.retcode == mt5.TRADE_RETCODE_DONE:
        print(f"✅ Position fermée avec succès!")
        print(f"   Ticket fermé: {result.order}")
        print(f"   Profit final: {pos.profit}")
    else:
        print(f"❌ Erreur fermeture: {result.retcode if result else 'None'}")
        if result:
            print(f"   Commentaire: {result.comment}")
    
    mt5.shutdown()

if __name__ == "__main__":
    close_dangerous_position()
