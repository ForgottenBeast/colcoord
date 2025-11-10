import websockets
import asyncio
import json

async def connect_recv():
    while True:
        try:
            ws = await asyncio.wait_for(websockets.connect("ws://127.0.0.1:8978/games"),timeout = 5)
            while True:
                data = await ws.recv()
                print(data)
        except Exception as ex:
            print(f"got error: {ex}")
        await asyncio.sleep(1)

asyncio.run(connect_recv())
