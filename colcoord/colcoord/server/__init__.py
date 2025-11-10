from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import websockets
import asyncio
from observlib import traced
import uuid
import json
from logging import getLogger

logger = getLogger(__name__)

app = FastAPI()
node_id = None
games = {}
connections = {"unknown":[]}
config = None

def set_config(conf_obj):
    global config
    config = conf_obj


async def send_identity(websocket):
    while True:
        try:
            await websocket.send_json(data = {"type":"identity", "data":{"node_id":node_id.hex}}, mode = "text")
        except WebSocketDisconnect:
            global connections
            if websocket in connections["unknown"]:
                connections["unknown"].remove(websocket)
                logger.info("unknown peer disconnected")
            else:
                for peer,connection in connections.items():
                    if connection == websocket:
                        del connections[peer]
                        logger.info(f"{peer} disconnected")
                        break

            break
        await asyncio.sleep(1)

async def agnostic_send(data,ws):
    if isinstance(ws,WebSocket):
        await ws.send_json(data =data , mode = "text")
    else:
        await ws.send(json.dumps(data))

async def handle_message(data,websocket):
    global connections
    match data["type"]:
        case "identity":
            if websocket in connections["unknown"]:
                connections["unknown"].remove(websocket)
                peer = data["data"]["node_id"]
                if peer in connections:
                    await agnostic_send({"type":"error","data":{"reason":"already connected","node_id":node_id.hex}},websocket)
                connections[peer] = websocket
                logger.info(f"added {peer}")
        case _:
                 logger.info("unknown message type: {}".format(json.dumps(data)))

async def receive_messages_outbound_conn(websocket):
    while True:
        msg = await websocket.recv()
        data = json.loads(msg)
        await handle_message(data,websocket)

async def connect_to_peer(peer, timeout=5):
    """Try connecting to a peer once."""
    try:
        ws = await asyncio.wait_for(websockets.connect(peer), timeout)
        global connections
        connections["unknown"].append(ws)
        loop = asyncio.get_running_loop()
        loop.create_task(send_identity(ws))
        loop.create_task(receive_messages_outbound_conn(ws))
        logger.info(f"[✓] Connected to {peer}")
    except Exception as e:
        logger.error(f"[x] Failed to connect to {peer}: {e}")
        return None

async def connect_peers():
    while True:
        async with asyncio.TaskGroup() as tg:
            for peer in config["peers"]:
                if peer not in connections:
                    tg.create_task(connect_to_peer(peer))
        await asyncio.sleep(1)


@app.on_event("startup")
@traced(tracer="colcoord.ws-server")
async def startup_event():
    global node_id
    node_id = uuid.uuid1()
    logger.info("setting node id to {}".format(node_id.hex))
    loop = asyncio.get_running_loop()
    loop.create_task(connect_peers())

@app.websocket("/games")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("new client connected")
    global connections
    connections["unknown"].append(websocket)
    loop = asyncio.get_running_loop()
    loop.create_task(send_identity(websocket))

    while True:
        data = await websocket.receive_json()
        await handle_message(data,websocket)
