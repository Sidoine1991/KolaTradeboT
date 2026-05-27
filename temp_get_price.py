import asyncio
import json
import websockets

async def get_price():
    async with websockets.connect('wss://ws.derivws.com/websockets/v3?app_id=1089', open_timeout=15) as ws:
        await ws.send(json.dumps({'ticks':'frxXAUUSD'}))
        for _ in range(20):
            m = json.loads(await asyncio.wait_for(ws.recv(), 10))
            p = m.get('tick', {}).get('quote')
            if p:
                print(p)
                return

asyncio.run(get_price())
