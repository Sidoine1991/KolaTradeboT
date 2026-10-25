#!/usr/bin/env python3
"""
Test du système SMC simplifié
"""

import sys
import MetaTrader5 as mt5
from srmc_trading_system import SimplifiedSMTradingSystem
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def test_detection_sr():
    """Test la détection Support/Résistance"""
    print("=" * 60)
    print("TEST 1: Détection Support/Résistance")
    print("=" * 60)
    
    system = SimplifiedSMTradingSystem()
    symbol = "Boom 1000 Index"
    
    try:
        levels = system.detect_support_resistance(symbol, periods=200)
        print(f"✅ Détection S/R réussie pour {symbol}")
        print(f"📊 Nombre de niveaux trouvés: {len(levels)}")
        
        for i, level in enumerate(levels[:5], 1):
            print(f"\nNiveau {i}:")
            print(f"  Type: {level.level_type}")
            print(f"  Prix: {level.price:.2f}")
            print(f"  Force: {level.strength:.2%}")
            print(f"  Touches: {level.touches}")
            print(f"  Confirmé: {level.confirmed}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

def test_detection_ib():
    """Test la détection Imbalance"""
    print("\n" + "=" * 60)
    print("TEST 2: Détection Zones d'Imbalance")
    print("=" * 60)
    
    system = SimplifiedSMTradingSystem()
    symbol = "Boom 1000 Index"
    
    try:
        imbalances = system.detect_imbalance_zones(symbol)
        print(f"✅ Détection IB réussie pour {symbol}")
        print(f"📊 Nombre de zones trouvées: {len(imbalances)}")
        
        for i, imb in enumerate(imbalances[:5], 1):
            print(f"\nZone {i}:")
            print(f"  Type: {imb.zone_type}")
            print(f"  Top: {imb.top:.2f}")
            print(f"  Bottom: {imb.bottom:.2f}")
            print(f"  Force: {imb.strength:.2%}")
            print(f"  Remplie: {imb.filled}")
            print(f"  Confirmée: {imb.confirmed}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

def test_detection_ob():
    """Test la détection Order Blocks"""
    print("\n" + "=" * 60)
    print("TEST 3: Détection Order Blocks")
    print("=" * 60)
    
    system = SimplifiedSMTradingSystem()
    symbol = "Boom 1000 Index"
    
    try:
        order_blocks = system.detect_order_blocks(symbol)
        print(f"✅ Détection OB réussie pour {symbol}")
        print(f"📊 Nombre de OB trouvés: {len(order_blocks)}")
        
        for i, ob in enumerate(order_blocks[:5], 1):
            print(f"\nOB {i}:")
            print(f"  Type: {ob.ob_type}")
            print(f"  High: {ob.high:.2f}")
            print(f"  Low: {ob.low:.2f}")
            print(f"  Force: {ob.strength:.2%}")
            print(f"  Invalidé: {ob.invalidated}")
            print(f"  Confirmé: {ob.confirmed}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

def test_sl_tp_calculation():
    """Test le calcul SL/TP"""
    print("\n" + "=" * 60)
    print("TEST 4: Calcul SL/TP")
    print("=" * 60)
    
    system = SimplifiedSMTradingSystem()
    symbol = "Boom 1000 Index"
    
    try:
        tick = mt5.symbol_info_tick(symbol)
        if tick is None:
            print("❌ Impossible d'obtenir le tick")
            return
        
        current_price = tick.bid
        entry_price = tick.ask
        
        # Test BUY
        sl_buy, tp_buy = system.calculate_sl_tp(symbol, entry_price, 'BUY', current_price * 0.995)
        
        print(f"✅ Calcul SL/TP BUY réussi")
        print(f"  Entry: {entry_price:.2f}")
        print(f"  SL: {sl_buy:.2f} ({abs(entry_price - sl_buy):.2f})")
        print(f"  TP: {tp_buy:.2f} ({abs(tp_buy - entry_price):.2f})")
        
        if abs(entry_price - sl_buy) > 0:
            rr = abs(tp_buy - entry_price) / abs(entry_price - sl_buy)
            print(f"  R:R: 1:{rr:.2f}")
        
        # Test SELL
        sl_sell, tp_sell = system.calculate_sl_tp(symbol, entry_price, 'SELL', current_price * 1.005)
        
        print(f"\n✅ Calcul SL/TP SELL réussi")
        print(f"  Entry: {entry_price:.2f}")
        print(f"  SL: {sl_sell:.2f} ({abs(sl_sell - entry_price):.2f})")
        print(f"  TP: {tp_sell:.2f} ({abs(entry_price - tp_sell):.2f})")
        
        if abs(sl_sell - entry_price) > 0:
            rr = abs(entry_price - tp_sell) / abs(sl_sell - entry_price)
            print(f"  R:R: 1:{rr:.2f}")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")
        import traceback
        traceback.print_exc()

def test_signal_generation():
    """Test la génération de signaux"""
    print("\n" + "=" * 60)
    print("TEST 5: Génération de Signaux")
    print("=" * 60)
    
    system = SimplifiedSMTradingSystem()
    symbol = "Boom 1000 Index"
    
    try:
        signals = system.generate_signals(symbol)
        print(f"✅ Génération signaux réussie pour {symbol}")
        print(f"📊 Nombre de signaux: {len(signals)}")
        
        for i, signal in enumerate(signals, 1):
            print(f"\nSignal {i}:")
            print(f"  Action: {signal.action}")
            print(f"  Entry: {signal.entry_price:.2f}")
            print(f"  SL: {signal.sl_price:.2f}")
            print(f"  TP: {signal.tp_price:.2f}")
            print(f"  Confiance: {signal.confidence:.2%}")
            print(f"  Raison: {signal.reason}")
            print(f"  Key Level: {signal.key_level:.2f}")
            print(f"  R:R: 1:{signal.risk_reward:.2f}")
    except Exception as e:
        print(f"❌ Erreur: {e}")
        import traceback
        traceback.print_exc()

def main():
    """Lance tous les tests"""
    print("\n" + "=" * 60)
    print("🧪 TESTS DU SYSTÈME SMC SIMPLIFIÉ")
    print("=" * 60 + "\n")
    
    import MetaTrader5 as mt5
    
    # Initialiser MT5
    if not mt5.initialize():
        print("❌ Échec initialisation MT5")
        sys.exit(1)
    
    print("✅ MT5 initialisé\n")
    
    try:
        # Tests
        test_detection_sr()
        test_detection_ib()
        test_detection_ob()
        test_sl_tp_calculation()
        test_signal_generation()
        
        print("\n" + "=" * 60)
        print("✅ TOUS LES TESTS TERMINÉS")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n❌ Erreur dans les tests: {e}")
        import traceback
        traceback.print_exc()
    finally:
        mt5.shutdown()

if __name__ == "__main__":
    main()
