#!/usr/bin/env python3
"""
Débogage détaillé de la requête d'ordre vs ordre manuel
"""
import MetaTrader5 as mt5
import json
from datetime import datetime

def debug_order_request():
    print("=" * 60)
    print("DÉBOGAGE REQUÊTE D'ORDRE VS MANUEL")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    symbol = "Boom 300 Index"
    
    # Obtenir les informations complètes du symbole
    symbol_info = mt5.symbol_info(symbol)
    if not symbol_info:
        print(f"❌ Symbole {symbol} non trouvé")
        return
    
    print(f"📊 SYMBOLE: {symbol}")
    print(f"   Trade mode: {symbol_info.trade_mode}")
    print(f"   Point: {symbol_info.point}")
    print(f"   Digits: {symbol_info.digits}")
    print(f"   Volume min: {symbol_info.volume_min}")
    print(f"   Volume max: {symbol_info.volume_max}")
    print(f"   Volume step: {symbol_info.volume_step}")
    
    # Obtenir le tick actuel
    tick = mt5.symbol_info_tick(symbol)
    if not tick:
        print(f"❌ Pas de tick pour {symbol}")
        return
    
    print(f"\n📈 TICK ACTUEL:")
    print(f"   Bid: {tick.bid}")
    print(f"   Ask: {tick.ask}")
    print(f"   Time: {datetime.fromtimestamp(tick.time)}")
    
    # Construire une requête MINIMALE pour tester
    print(f"\n🔧 TEST AVEC REQUÊTE MINIMALE:")
    
    # Volume valide selon le symbole
    volume = symbol_info.volume_min
    
    # Requête BUY minimale
    request_buy = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": volume,
        "type": mt5.ORDER_TYPE_BUY,
        "price": tick.ask,
        "sl": 0.0,  # Sans SL pour commencer
        "tp": 0.0,  # Sans TP pour commencer
        "deviation": 20,
        "magic": 234000,
        "comment": "Test Python Debug",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,  # Changer en IOC
    }
    
    print(f"📋 REQUÊTE BUY (JSON):")
    print(json.dumps(request_buy, indent=2, default=str))
    
    # Vérifier chaque paramètre
    print(f"\n🔍 VÉRIFICATION DES PARAMÈTRES:")
    print(f"   Symbol valide: {symbol in [s.name for s in mt5.symbols_get()] if hasattr(mt5, 'symbols_get') else 'Non vérifiable'}")
    print(f"   Volume {volume} >= min {symbol_info.volume_min}: {volume >= symbol_info.volume_min}")
    print(f"   Volume {volume} <= max {symbol_info.volume_max}: {volume <= symbol_info.volume_max}")
    print(f"   Price {tick.ask} > 0: {tick.ask > 0}")
    
    # Tester la requête SANS l'envoyer
    print(f"\n🧪 TEST D'ENVOI:")
    print(f"   Envoi de la requête BUY...")
    
    result = mt5.order_send(request_buy)
    
    if result is None:
        print(f"❌ mt5.order_send() a retourné None")
        print(f"   Dernière erreur MT5: {mt5.last_error()}")
        
        # Essayer avec type_filling différent
        print(f"\n🔄 ESSAI AVEC type_filling = FOK:")
        request_fok = request_buy.copy()
        request_fok["type_filling"] = mt5.ORDER_FILLING_FOK
        
        result_fok = mt5.order_send(request_fok)
        if result_fok is None:
            print(f"❌ Toujours None avec FOK: {mt5.last_error()}")
        else:
            print(f"✅ FOK fonctionne! Result: {result_fok.retcode}")
    
    elif result.retcode != mt5.TRADE_RETCODE_DONE:
        print(f"❌ Ordre rejeté: {result.retcode} - {result.comment}")
        print(f"   Request: {result.request}")
        print(f"   Order: {result.order}")
    else:
        print(f"✅ Ordre réussi!")
        print(f"   Ticket: {result.order}")
        print(f"   Price: {result.price}")
        print(f"   Volume: {result.volume}")
        
        # Fermer immédiatement pour test
        close_request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": mt5.ORDER_TYPE_SELL,
            "position": result.order,
            "price": tick.bid,
            "deviation": 20,
            "magic": 234000,
            "comment": "Close Test Debug",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        
        close_result = mt5.order_send(close_request)
        if close_result and close_result.retcode == mt5.TRADE_RETCODE_DONE:
            print(f"✅ Position fermée pour test")
    
    # Comparer avec les paramètres d'un ordre manuel
    print(f"\n📝 COMPARAISON AVEC ORDRE MANUEL:")
    print(f"   Quand vous placez un ordre manuel dans MT5:")
    print(f"   1. Notez le prix, volume, SL, TP utilisés")
    print(f"   2. Comparez avec notre requête Python")
    print(f"   3. La différence est souvent dans:")
    print(f"      - type_filling (IOC vs FOK vs RETURN)")
    print(f"      - Arrondi des prix")
    print(f"      - Volume step")
    
    mt5.shutdown()
    print(f"\n✅ Débogage terminé")

if __name__ == "__main__":
    debug_order_request()
