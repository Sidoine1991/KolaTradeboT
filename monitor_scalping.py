#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Monitor scalping trade XAUUSD SELL in real-time."""

import asyncio
import json
import sys
import io
import websockets

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

async def monitor_trade():
    """Monitor XAUUSD price for scalping trade."""

    # Trade parameters
    entry = 4569.80
    sl = 4590.00
    tp1 = 4549.00
    tp2 = 4520.00
    lot = 0.01

    print("=" * 70)
    print("🎯 SURVEILLANCE SCALPING SELL XAUUSD")
    print("=" * 70)
    print(f"Entry:     ${entry:.2f}")
    print(f"Stop Loss: ${sl:.2f} (+{(sl - entry):.2f})")
    print(f"TP1:       ${tp1:.2f} (-{(entry - tp1):.2f})")
    print(f"TP2:       ${tp2:.2f} (-{(entry - tp2):.2f})")
    print(f"Lot size:  {lot}")
    print("=" * 70)
    print()

    try:
        async with websockets.connect('wss://ws.derivws.com/websockets/v3?app_id=1089', open_timeout=15) as ws:
            await ws.send(json.dumps({'ticks': 'frxXAUUSD'}))

            for i in range(30):  # Monitor for ~1 minute
                msg = json.loads(await asyncio.wait_for(ws.recv(), 10))
                price = msg.get('tick', {}).get('quote')

                if price:
                    # Calculate P&L
                    pnl_points = entry - price
                    pnl_pips = pnl_points * 10
                    pnl_usd = pnl_points * lot * 100

                    # Calculate distances
                    dist_sl = sl - price
                    dist_tp1 = price - tp1
                    dist_tp2 = price - tp2

                    # Determine status
                    status = "EN COURS"
                    emoji = "📊"

                    if price >= sl:
                        status = "STOP LOSS HIT!"
                        emoji = "🛑"
                    elif price <= tp2:
                        status = "TP2 ATTEINT!"
                        emoji = "🎯🎯"
                    elif price <= tp1:
                        status = "TP1 ATTEINT!"
                        emoji = "🎯"

                    # Print update
                    print(f"{emoji} {status}")
                    print(f"  Prix actuel: ${price:.2f}")
                    print(f"  P&L: {pnl_points:+.2f} points | {pnl_pips:+.1f} pips | ${pnl_usd:+.2f}")
                    print(f"  Distance SL:  {dist_sl:+.2f} ({abs(dist_sl)*10:.1f} pips)")
                    print(f"  Distance TP1: {dist_tp1:+.2f} ({abs(dist_tp1)*10:.1f} pips)")
                    print(f"  Distance TP2: {dist_tp2:+.2f} ({abs(dist_tp2)*10:.1f} pips)")
                    print("-" * 70)

                    # Check if trade finished
                    if price >= sl or price <= tp1:
                        print()
                        print("=" * 70)
                        print(f"TRADE TERMINE: {status}")
                        print(f"P&L FINAL: ${pnl_usd:+.2f}")
                        print("=" * 70)
                        break

                    await asyncio.sleep(2)

    except Exception as e:
        print(f"Erreur: {e}")

if __name__ == "__main__":
    asyncio.run(monitor_trade())
