#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Exemple complet d'utilisation du FVG Spike Detector
Test sur Boom 500 et Crash 1000 en simultané
"""

import asyncio
import pandas as pd
from datetime import datetime, timedelta
from fvg_spike_detector import FVGSpikeDetector, get_symbol_direction, get_trade_direction_for_symbol


async def simulate_real_time_monitoring():
    """
    Simulation du monitoring en temps réel sur plusieurs symboles
    """
    detector = FVGSpikeDetector(max_risk_usd=2.50)
    
    print("🚀 SYSTÈME FVG SPIKE DETECTOR - MONITORING MULTI-SYMBOLS")
    print("="*70)
    print("Symboles surveillés:")
    print("  🟢 BULLISH: Boom 500, Boom 1000, GAINX, TRENDX")
    print("     → Faire: Alertes sur FVG SUPPLY (résistance)")
    print("     → Action: SELL quand FVG Supply M1 confirme M5")
    print()
    print("  🔴 BEARISH: Crash 500, Crash 1000, PAINX")
    print("     → Faire: Alertes sur FVG DEMAND (support)")
    print("     → Action: BUY quand FVG Demand M1 confirme M5")
    print("="*70)
    print(f"Risk Maximum: $2.50 par trade")
    print("="*70 + "\n")
    
    # Scénario 1: Boom 500 - Spike haussier détecté
    print("\n" + "="*70)
    print("SCÉNARIO 1: Boom 500 - Contexte de Spike Haussier attendu")
    print("="*70)
    boom_m5 = create_boom_data()
    boom_m1 = create_boom_m1_data()
    
    print(f"Type symbole: {get_symbol_direction('Boom 500').value}")
    print(f"FVG cible: SUPPLY (résistance)")
    print(f"Direction trade: {get_trade_direction_for_symbol('Boom 500')}")
    print()
    
    alert, signal = await detector.run_detection_cycle("Boom 500", boom_m5, boom_m1)
    
    if alert:
        print(f"✅ ALERTE BOOM 500: {alert.alert_type}")
        print(f"   Message: {alert.message}")
    
    if signal:
        print(f"🚀 SIGNAL BOOM 500: {signal.direction}")
        print(f"   Entry: {signal.entry_price}")
        print(f"   SL: {signal.stop_loss}")
        print(f"   TP: {signal.take_profit}")
        print(f"   Lot: {signal.lot_size}")
        print(f"   Risk: ${signal.risk_amount}")
    
    # Scénario 2: Crash 1000 - Spike baissier détecté
    print("\n" + "="*70)
    print("SCÉNARIO 2: Crash 1000 - Contexte de Spike Baissier attendu")
    print("="*70)
    crash_m5 = create_crash_data()
    crash_m1 = create_crash_m1_data()
    
    print(f"Type symbole: {get_symbol_direction('Crash 1000').value}")
    print(f"FVG cible: DEMAND (support)")
    print(f"Direction trade: {get_trade_direction_for_symbol('Crash 1000')}")
    print()
    
    alert2, signal2 = await detector.run_detection_cycle("Crash 1000", crash_m5, crash_m1)
    
    if alert2:
        print(f"✅ ALERTE CRASH 1000: {alert2.alert_type}")
        print(f"   Message: {alert2.message}")
    
    if signal2:
        print(f"🚀 SIGNAL CRASH 1000: {signal2.direction}")
        print(f"   Entry: {signal2.entry_price}")
        print(f"   SL: {signal2.stop_loss}")
        print(f"   TP: {signal2.take_profit}")
        print(f"   Lot: {signal2.lot_size}")
        print(f"   Risk: ${signal2.risk_amount}")
    
    # Afficher les statuts finaux
    print("\n" + "="*70)
    print("STATUTS FINAUX")
    print("="*70)
    print(f"\nBoom 500:")
    for k, v in detector.get_status("Boom 500").items():
        print(f"  {k}: {v}")
    
    print(f"\nCrash 1000:")
    for k, v in detector.get_status("Crash 1000").items():
        print(f"  {k}: {v}")


def create_boom_data() -> pd.DataFrame:
    """Crée des données simulées pour Boom 500 (tendance haussière avec gaps supply)"""
    dates = pd.date_range(start="2024-01-01 10:00", periods=10, freq="5min")
    return pd.DataFrame({
        'open':  [100.0, 100.5, 101.0, 100.8, 100.5, 100.2, 99.8, 99.5, 99.2, 98.8],
        'high':  [100.5, 101.2, 101.8, 101.5, 101.0, 100.8, 100.5, 100.2, 99.8, 99.5],
        'low':   [99.8, 100.2, 100.5, 100.3, 100.0, 99.8, 99.2, 98.8, 98.5, 98.2],
        'close': [100.2, 100.8, 101.5, 101.2, 100.8, 100.5, 100.0, 99.8, 99.2, 98.8],
        'volume': [100, 120, 80, 90, 110, 150, 200, 180, 160, 140]
    }, index=dates)


def create_boom_m1_data() -> pd.DataFrame:
    """Crée des données M1 pour Boom (confirmation)"""
    dates = pd.date_range(start="2024-01-01 10:45", periods=5, freq="1min")
    return pd.DataFrame({
        'open':  [99.0, 98.8, 98.5, 98.3, 98.0],
        'high':  [99.2, 99.0, 98.8, 98.5, 98.2],
        'low':   [98.5, 98.3, 98.0, 97.8, 97.5],
        'close': [98.8, 98.5, 98.3, 98.0, 97.8],
        'volume': [50, 60, 45, 70, 55]
    }, index=dates)


def create_crash_data() -> pd.DataFrame:
    """Crée des données simulées pour Crash 1000 (tendance baissière avec gaps demand)"""
    dates = pd.date_range(start="2024-01-01 10:00", periods=10, freq="5min")
    return pd.DataFrame({
        'open':  [100.0, 99.5, 99.0, 98.8, 98.5, 98.2, 97.8, 97.5, 97.2, 96.8],
        'high':  [100.2, 99.8, 99.3, 99.0, 98.8, 98.5, 98.0, 97.8, 97.5, 97.0],
        'low':   [99.5, 99.0, 98.5, 98.2, 97.8, 97.5, 97.2, 96.8, 96.5, 96.2],
        'close': [99.8, 99.3, 98.8, 98.5, 98.2, 97.8, 97.5, 97.2, 96.8, 96.5],
        'volume': [100, 120, 80, 90, 110, 150, 200, 180, 160, 140]
    }, index=dates)


def create_crash_m1_data() -> pd.DataFrame:
    """Crée des données M1 pour Crash (confirmation demand)"""
    dates = pd.date_range(start="2024-01-01 10:45", periods=5, freq="1min")
    return pd.DataFrame({
        'open':  [96.5, 96.3, 96.0, 95.8, 95.5],
        'high':  [96.8, 96.5, 96.2, 96.0, 95.8],
        'low':   [96.0, 95.8, 95.5, 95.3, 95.0],
        'close': [96.2, 96.0, 95.8, 95.5, 95.3],
        'volume': [50, 60, 45, 70, 55]
    }, index=dates)


if __name__ == "__main__":
    asyncio.run(simulate_real_time_monitoring())
