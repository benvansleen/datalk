import asyncio
import time
from contextlib import suppress
from dataclasses import dataclass, field

from jupyter_client import AsyncKernelClient, AsyncKernelManager

from .checkpoint import restore_kernel
from .config import Config
from .dataset import load_dataset
from .telemetry import StageName, StageStatus, StageTelemetry, StageTimer

KERNEL_START_TIMEOUT = 30.0
KERNEL_SHUTDOWN_TIMEOUT = 10.0


@dataclass
class WorkerState:
    config: Config
    manager: AsyncKernelManager | None = None
    client: AsyncKernelClient | None = None
    ready: bool = False
    available_dataframes: str = ""
    startup_telemetry: list[StageTelemetry] = field(default_factory=list)
    last_activity: float = field(default_factory=time.monotonic)
    execution_lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def start(self) -> None:
        self.startup_telemetry = await self.initialize_kernel(record_telemetry=True)
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
        await self.initialize_kernel(record_telemetry=False)
        self.last_activity = time.monotonic()

    async def initialize_kernel(self, *, record_telemetry: bool) -> list[StageTelemetry]:
        self.ready = False
        manager = AsyncKernelManager(kernel_name="python3")
        telemetry: list[StageTelemetry] = []
        try:
            kernel_start = StageTimer.start(StageName.KERNEL_START)
            await manager.start_kernel()
            if record_telemetry:
                telemetry.append(kernel_start.finish(StageStatus.OK))

            kernel_ready = StageTimer.start(StageName.KERNEL_READY_WAIT)
            client = manager.client()
            client.start_channels()
            await client.wait_for_ready(timeout=KERNEL_START_TIMEOUT)
            if record_telemetry:
                telemetry.append(kernel_ready.finish(StageStatus.OK))

            self.manager = manager
            self.client = client

            dataset_load = StageTimer.start(StageName.DATASET_LOAD)
            self.available_dataframes = await load_dataset(self)
            if record_telemetry:
                telemetry.append(dataset_load.finish(StageStatus.OK))

            checkpoint_restore = StageTimer.start(StageName.CHECKPOINT_RESTORE)
            restored_dataframes = await restore_kernel(self)
            if restored_dataframes is not None:
                self.available_dataframes = restored_dataframes
            if record_telemetry:
                telemetry.append(checkpoint_restore.finish(StageStatus.OK))

            self.ready = True
            return telemetry

        except Exception:
            self.manager = manager
            await self.shutdown()
            raise
