import asyncio
import json
import websockets
import sys

async def get_price():
    try:
        async with websockets.connect('wss://ws.derivws.com/websockets/v3?app_id=1089', open_timeout=15) as ws:
            await ws.send(json.dumps({'ticks': 'frxXAUUSD'}))
            for _ in range(20):
                msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
                price = msg.get('tick', {}).get('quote')
                if price:
                    print(f"PRICE:{price}")
                    return
            print("NO_PRICE_RECEIVED")
    except asyncio.TimeoutError:
        print("TIMEOUT:Market_closed_or_no_quotes")
    except Exception as e:
        print(f"ERROR:{type(e).__name__}:{str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(get_price())
