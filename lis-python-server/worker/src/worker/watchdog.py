import asyncio
import os
import signal
import time
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .state import WorkerState


async def idle_watchdog(
    state: "WorkerState",
    *,
    minimum_poll_interval: float = 1.0,
) -> None:
    while True:
        elapsed = time.monotonic() - state.last_activity
        remaining = state.config.idle_timeout - elapsed

        if remaining > 0:
            await asyncio.sleep(max(minimum_poll_interval, remaining))
            continue

        async with state.execution_lock:
            elapsed = time.monotonic() - state.last_activity
            if elapsed < state.config.idle_timeout:
                continue
            state.ready = False
            await state.shutdown()

        os.kill(os.getpid(), signal.SIGTERM)
        return
