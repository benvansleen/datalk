import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from worker.state import WorkerState
from worker.telemetry import StageName, StageStatus


class StartupTelemetryTests(unittest.IsolatedAsyncioTestCase):
    async def test_records_cold_start_phases_without_replacing_them_on_restart(self):
        client = SimpleNamespace(
            start_channels=MagicMock(),
            stop_channels=MagicMock(),
            wait_for_ready=AsyncMock(),
        )
        manager = SimpleNamespace(
            start_kernel=AsyncMock(),
            shutdown_kernel=AsyncMock(),
            client=MagicMock(return_value=client),
        )
        state = WorkerState(config=SimpleNamespace())

        with (
            patch("worker.state.AsyncKernelManager", return_value=manager),
            patch("worker.state.load_dataset", AsyncMock(return_value="[('games',)]\n")),
            patch("worker.state.restore_kernel", AsyncMock(return_value=None)),
        ):
            await state.start()
            cold_start = list(state.startup_telemetry)
            await state.restart()

        self.assertTrue(state.ready)
        self.assertEqual(state.available_dataframes, "[('games',)]\n")
        self.assertEqual(state.startup_telemetry, cold_start)
        self.assertEqual(
            [(stage.stage, stage.status) for stage in cold_start],
            [
                (StageName.KERNEL_START, StageStatus.OK),
                (StageName.KERNEL_READY_WAIT, StageStatus.OK),
                (StageName.DATASET_LOAD, StageStatus.OK),
                (StageName.CHECKPOINT_RESTORE, StageStatus.OK),
            ],
        )


if __name__ == "__main__":
    unittest.main()
