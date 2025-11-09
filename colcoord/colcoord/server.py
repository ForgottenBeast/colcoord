from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import asyncio
from observlib import traced
import uuid
import json

app = FastAPI()
node_id = None
games = {}

@app.on_event("startup")
@traced(tracer=traced_conf["tracer"])
async def startup_event():
    global node_id
    node_id = uuid.uuid1()


async def send_identity(websocket):
    while True:
        try:
            await websocket.send_text(json.dumps({"node_id":node_id.hex()}))
        except WebSocketDisconnect:
            break
        await asyncio.sleep(1)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    loop = asyncio.get_running_loop()
    loop.create_task(send_identity(websocket))

    while True:
        data = await websocket.receive_text()
        await websocket.send_text(f"Message text was: {data}")

