from observlib import configure_telemetry
import os
import argparse
import uvicorn
from .server import app, set_config

def run():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-c",
        "--config-file",
        action="store",
        dest="config",
        required = True,
        help="yaml config file",
    )
    parser.add_argument(
        "-d",
        "--debug",
        action="store_true",
        help="enable debug mode, increases pyroscope sampling rate if configured",
        dest="debug",
    )
    parser.add_argument(
            "-p",
            "--port",
            action = "store",
            type = int,
            default = 8978,
    )

    args = parser.parse_args()
    attrs = {}
    sample_rate = 5

    if args.debug:
        attrs = {"environment": "dev"}
        sample_rate = 100

    pyroscope_server = None
    if args.debug:
        pyroscope_server = os.environ.get("PYROSCOPE_DEV_SERVER")
    else:
        pyroscope_server = os.environ.get("PYROSCOPE_SERVER")

    configure_telemetry(
        "colcoord",
        os.environ["OTEL_SERVER"],
        pyroscope_server,
        sample_rate,
        resource_attrs=attrs,
    )

    set_config({"peers":[]})
    uvicorn.run(app, host = "127.0.0.1", port = args.port)
