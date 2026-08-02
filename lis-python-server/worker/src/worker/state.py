import asyncio
import time
from contextlib import suppress
from dataclasses import dataclass, field

from jupyter_client import AsyncKernelClient, AsyncKernelManager

from .checkpoint import restore_kernel
from .config import Config
from .dataset import load_dataset

KERNEL_START_TIMEOUT = 30.0
KERNEL_SHUTDOWN_TIMEOUT = 10.0


@dataclass
class WorkerState:
    config: Config
    manager: AsyncKernelManager | None = None
    client: AsyncKernelClient | None = None
    ready: bool = False
    last_activity: float = field(default_factory=time.monotonic)
    execution_lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def start(self) -> None:
        await self.initialize_kernel()
        self.last_activity = time.monotonic()

    async def shutdown(self) -> None:
        self.ready = False
        client, manager = self.client, self.manager
        self.client, self.manager = None, None
        if client is not None:
            with suppress(Exception):
                client.stop_channels()

        if manager is not None:
            with suppress(Exception):
                await asyncio.wait_for(
                    manager.shutdown_kernel(now=True),
                    timeout=KERNEL_SHUTDOWN_TIMEOUT,
                )

    async def restart(self) -> None:
        await self.shutdown()
        await self.start()

    async def initialize_kernel(self) -> None:
        self.ready = False
        manager = AsyncKernelManager(kernel_name="python3")
        try:
            await manager.start_kernel()
            client = manager.client()
            client.start_channels()

            await client.wait_for_ready(timeout=KERNEL_START_TIMEOUT)

            self.manager = manager
            self.client = client
            await load_dataset(self)
            await restore_kernel(self)
            self.ready = True

        except Exception:
            self.manager = manager
            await self.shutdown()
            raise
