#!/usr/bin/env python3
"""
Check trading hours and symbol availability for Boom/Crash indices
"""
import MetaTrader5 as mt5
from datetime import datetime, timezone
import pytz

def check_trading_hours():
    print("=" * 60)
    print("VÉRIFICATION DES HEURES DE TRADING")
    print("=" * 60)
    
    # Initialize MT5
    if not mt5.initialize():
        print("❌ Erreur initialisation MT5:", mt5.last_error())
        return
    
    # Get current time
    utc_now = datetime.now(pytz.UTC)
    print(f"🕐 Heure UTC actuelle: {utc_now.strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Convert to different timezones
    timezones = {
        'UTC': pytz.UTC,
        'EST': pytz.timezone('US/Eastern'),
        'GMT': pytz.timezone('GMT'),
        'CET': pytz.timezone('Europe/Paris'),
        'JST': pytz.timezone('Asia/Tokyo')
    }
    
    print("\n🌍 Heures dans différents fuseaux:")
    for name, tz in timezones.items():
        local_time = utc_now.astimezone(tz)
        print(f"   {name}: {local_time.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    
    # Check symbols
    symbols = ["Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"]
    
    print("\n" + "=" * 60)
    print("STATUT DES SYMBOLES")
    print("=" * 60)
    
    for symbol in symbols:
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            print(f"❌ {symbol}: Non trouvé")
            continue
        
        print(f"\n📊 {symbol}:")
        print(f"   Mode de trading: {symbol_info.trade_mode}")
        
        # Decode trade mode
        trade_modes = {
            0: "Désactivé",
            1: "Complet (Full)",
            2: "Long seulement",
            3: "Short seulement", 
            4: "Close seulement",
            5: "Session longue seulement"
        }
        
        mode_text = trade_modes.get(symbol_info.trade_mode, f"Inconnu ({symbol_info.trade_mode})")
        print(f"   Description: {mode_text}")
        
        print(f"   Visible: {symbol_info.visible}")
        print(f"   Volume min: {symbol_info.volume_min}")
        print(f"   Volume max: {symbol_info.volume_max}")
        
        # Check session times (simplified approach)
        print(f"   Sessions: Vérification manuelle requise")
        
        # Check if currently tradable based on trade mode
        if symbol_info.trade_mode == 1:  # Full mode
            print(f"   ✅ Mode trading complet")
        elif symbol_info.trade_mode == 4:  # Close only
            print(f"   ❌ Mode 'Close seulement' - Pas de nouvelles positions")
        else:
            print(f"   ⚠️  Mode restreint: {symbol_info.trade_mode}")
    
    # Check current tick data
    print("\n" + "=" * 60)
    print("DONNÉES DE MARCHE ACTUELLES")
    print("=" * 60)
    
    for symbol in symbols:
        tick = mt5.symbol_info_tick(symbol)
        if tick is None:
            print(f"❌ {symbol}: Pas de données de tick")
            continue
        
        print(f"\n📈 {symbol}:")
        print(f"   Bid: {tick.bid}")
        print(f"   Ask: {tick.ask}")
        print(f"   Spread: {tick.ask - tick.bid:.3f}")
        print(f"   Heure tick: {datetime.fromtimestamp(tick.time)}")
        
        # Check if spread is reasonable
        point = mt5.symbol_info(symbol).point
        spread_points = (tick.ask - tick.bid) / point
        print(f"   Spread (points): {spread_points:.0f}")
        
        if spread_points > 1000:
            print(f"   ⚠️  Spread très élevé!")
    
    mt5.shutdown()
    print("\n✅ Vérification terminée")

if __name__ == "__main__":
    check_trading_hours()
