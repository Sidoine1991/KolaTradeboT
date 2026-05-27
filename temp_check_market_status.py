"""Vérifie si le marché XAUUSD est vraiment ouvert via Deriv API"""
import asyncio
import json
import websockets
import sys
import io
from datetime import datetime

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

async def check_market_status():
    try:
        print(f"[{datetime.utcnow().strftime('%H:%M:%S UTC')}] Connexion à Deriv WebSocket...")

        async with websockets.connect('wss://ws.derivws.com/websockets/v3?app_id=1089', open_timeout=20) as ws:

            # Demander les ticks XAUUSD
            await ws.send(json.dumps({'ticks': 'frxXAUUSD', 'subscribe': 1}))
            print("[INFO] Demande de ticks frxXAUUSD envoyée...")

            # Attendre plusieurs messages
            for i in range(30):
                try:
                    msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=15))

                    # Message d'erreur ?
                    if msg.get('error'):
                        print(f"[ERROR] {msg['error']}")
                        return

                    # Tick reçu ?
                    if 'tick' in msg:
                        tick = msg['tick']
                        price = tick.get('quote')
                        timestamp = tick.get('epoch')
                        symbol = tick.get('symbol')

                        print(f"\n✅ TICK REÇU:")
                        print(f"   Symbol: {symbol}")
                        print(f"   Price: ${price}")
                        print(f"   Time: {datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S UTC')}")
                        return price

                    # Message de subscription ?
                    if 'subscription' in msg:
                        print(f"[INFO] Souscription confirmée: {msg['subscription']}")

                    # Autre message
                    print(f"[{i+1}/30] Message reçu: {msg.get('msg_type', 'unknown')}")

                except asyncio.TimeoutError:
                    print(f"[{i+1}/30] Timeout - aucun tick depuis 15s")
                    continue

            print("\n⚠️ AUCUN TICK REÇU APRÈS 30 TENTATIVES")
            print("Le marché semble fermé ou sans liquidité")

    except asyncio.TimeoutError:
        print("\n❌ TIMEOUT CONNEXION - Impossible de se connecter au broker")
    except Exception as e:
        print(f"\n❌ ERREUR: {type(e).__name__}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(check_market_status())
