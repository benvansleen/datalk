import asyncio
from contextlib import asynccontextmanager, suppress

from fastapi import FastAPI

from .config import Config
from .state import WorkerState
from .watchdog import idle_watchdog


@asynccontextmanager
async def lifespan(app: FastAPI):
    config = Config.from_env()
    state = WorkerState(config)
    app.state.worker = state

    await state.start()
    idle_task = asyncio.create_task(idle_watchdog(state))

    try:
        yield
    finally:
        idle_task.cancel()
        with suppress(asyncio.CancelledError):
            await idle_task
        await state.shutdown()


app = FastAPI(lifespan=lifespan)
