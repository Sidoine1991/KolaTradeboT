#!/usr/bin/env python3
"""
WebSocket client test
"""
import asyncio
from websockets import connect

async def test():
    try:
        print("Connecting to ws://127.0.0.1:8080/ws...")
        async with connect("ws://127.0.0.1:8080/ws") as websocket:
            print("✅ Connected!")
            msg = await websocket.recv()
            print(f"Received: {msg}")
    except Exception as e:
        print(f"❌ Error: {e}")

asyncio.run(test())
