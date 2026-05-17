#!/usr/bin/env python3
"""
Minimal WebSocket test to debug FastAPI issue
"""
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import uvicorn

app = FastAPI()

@app.get("/")
def home():
    return {"status": "ok"}

@app.websocket("/test-ws")
async def websocket_endpoint(websocket: WebSocket):
    print(f"[DEBUG] WebSocket connection attempt from {websocket.client}")
    try:
        await websocket.accept()
        print("[DEBUG] WebSocket accepted!")
        await websocket.send_text("Hello from WebSocket!")
        while True:
            data = await websocket.receive_text()
            await websocket.send_text(f"Echo: {data}")
    except WebSocketDisconnect:
        print("[DEBUG] WebSocket disconnected")
    except Exception as e:
        print(f"[ERROR] WebSocket error: {e}")

if __name__ == "__main__":
    print("Starting minimal WebSocket test...")
    uvicorn.run(app, host="127.0.0.1", port=8081, log_level="debug")
