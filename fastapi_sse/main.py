import enum
import threading
import time
from enum import Enum
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sse_starlette.sse import EventSourceResponse

app = FastAPI()

templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


class State(Enum):
    INACTIVE = enum.auto()
    STARTING = enum.auto()
    WORKING = enum.auto()
    FINISHING = enum.auto()
    COMPLETED = enum.auto()


current_state = State.INACTIVE


async def state_generator(request: Request):
    global current_state
    yield current_state.value

    tmp = current_state
    while True:
        time.sleep(0.2)
        if await request.is_disconnected():
            break
        if current_state != tmp:
            tmp = current_state
            yield current_state.value


def long_process():
    global current_state

    if current_state not in [State.INACTIVE, State.COMPLETED]:
        return

    current_state = State.STARTING
    time.sleep(1)
    current_state = State.WORKING
    time.sleep(1)
    current_state = State.FINISHING
    time.sleep(1)
    current_state = State.COMPLETED


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    states = {s.name.capitalize(): s.value for s in State}
    return templates.TemplateResponse(  # type: ignore
        "index.html", {"request": request, "states": states}
    )


@app.get("/start")
async def start():
    threading.Thread(target=long_process).start()


@app.get("/reset")
async def reset():
    global current_state
    if current_state == State.COMPLETED:
        current_state = State.INACTIVE


@app.get("/get-state")
async def run(request: Request):
    event_generator = state_generator(request)
    return EventSourceResponse(event_generator)
