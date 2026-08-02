import asyncio
import logging
import os
import time
from pathlib import Path
from typing import TYPE_CHECKING

from .execution import execute_kernel_code

if TYPE_CHECKING:
    from .state import WorkerState

logger = logging.getLogger(__name__)


async def checkpoint_kernel(state: "WorkerState") -> None:
    result = await asyncio.wait_for(
        execute_kernel_code(state, build_checkpoint_code(state.config.checkpoint_path)),
        timeout=state.config.execution_timeout,
    )

    if not result.succeeded:
        raise RuntimeError(result.output)

    checkpoint = state.config.checkpoint_path
    if not checkpoint.is_file() or checkpoint.stat().st_size == 0:
        raise RuntimeError(
            "Kernel reported checkpoint success but no checkpoint was written"
        )


async def restore_kernel(state: "WorkerState") -> None:
    checkpoint = state.config.checkpoint_path
    checkpoint.with_name(checkpoint.name + ".tmp").unlink(missing_ok=True)
    if not checkpoint.exists():
        return

    result = await asyncio.wait_for(
        execute_kernel_code(state, build_restore_code(checkpoint)),
        timeout=state.config.execution_timeout,
    )

    if result.succeeded:
        return

    quarantine = checkpoint.with_name(f"{checkpoint.name}.corrupt-{time.time_ns()}")
    os.replace(checkpoint, quarantine)
    logger.error(
        "Checkpoint restoration failed; moved checkpoint to %s: %s",
        quarantine,
        result.output,
    )


def build_checkpoint_code(checkpoint_path: Path) -> str:
    return f"""
import cloudpickle as __datalk_cloudpickle
import os as __datalk_os
import types as __datalk_types
from pathlib import Path as __datalk_Path

__datalk_checkpoint = __datalk_Path({str(checkpoint_path)!r})
__datalk_temporary = __datalk_checkpoint.with_name(__datalk_checkpoint.name + ".tmp")
__datalk_checkpoint.parent.mkdir(parents=True, exist_ok=True)

__datalk_excluded = {{
    "In",
    "Out",
    "get_ipython",
    "exit",
    "quit",
    "open",
}}

__datalk_state = {{}}
for __datalk_name, __datalk_value in list(globals().items()):
    if __datalk_name.startswith("_"):
        continue
    if __datalk_name in __datalk_excluded:
        continue
    if isinstance(__datalk_value, __datalk_types.ModuleType):
        continue

    try:
        __datalk_cloudpickle.dumps(__datalk_value)
    except Exception:
        continue

    __datalk_state[__datalk_name] = __datalk_value

with __datalk_temporary.open("wb") as __datalk_file:
    __datalk_cloudpickle.dump(
        __datalk_state,
        __datalk_file,
    )
    __datalk_file.flush()
    __datalk_os.fsync(__datalk_file.fileno())

__datalk_os.replace(__datalk_temporary, __datalk_checkpoint)
__datalk_directory_fd = __datalk_os.open(__datalk_checkpoint.parent, __datalk_os.O_DIRECTORY)

try:
    __datalk_os.fsync(__datalk_directory_fd)
finally:
    __datalk_os.close(__datalk_directory_fd)

del __datalk_state
    """


def build_restore_code(checkpoint_path: Path) -> str:
    return f"""
import cloudpickle as __datalk_cloudpickle
from pathlib import Path as __datalk_Path

__datalk_checkpoint = __datalk_Path({str(checkpoint_path)!r})
with __datalk_checkpoint.open("rb") as __datalk_file:
    __datalk_state = __datalk_cloudpickle.load(__datalk_file)

if not isinstance(__datalk_state, dict):
    raise TypeError("Checkpoint does not contain a globals dictionary")

globals().update(__datalk_state)
del __datalk_state
    """
