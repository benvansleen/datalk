import asyncio
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from pydantic import ValidationError

from worker.error_boundary import WorkerProtocolError, handle_worker_error
from worker.execution import KernelResult, classify_kernel_error
from worker.interface import ExecutionRequest, ExecutionResponse
from worker.routes import execute, metadata
from worker.telemetry import (
    MAX_TELEMETRY_STAGES,
    StageErrorType,
    StageName,
    StageStatus,
    StageTelemetry,
    StageTimer,
)


def request_with(state):
    return SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(worker=state)))


def worker_state():
    return SimpleNamespace(
        ready=True,
        last_activity=0.0,
        execution_lock=asyncio.Lock(),
        config=SimpleNamespace(execution_timeout=1.0),
        restart=AsyncMock(),
    )


class TelemetryModelTests(unittest.TestCase):
    def test_kernel_error_type_is_allowlisted(self):
        self.assertEqual(
            classify_kernel_error("BinderException"),
            StageErrorType.BINDER_ERROR,
        )
        self.assertEqual(
            classify_kernel_error("AttackerControlledException"),
            StageErrorType.USER_CODE_ERROR,
        )

    def test_stage_timer_uses_wall_clock_for_start_and_monotonic_for_duration(self):
        with (
            patch("worker.telemetry.time.time_ns", return_value=123),
            patch("worker.telemetry.time.monotonic_ns", side_effect=[500, 575]),
        ):
            stage = StageTimer.start(StageName.LOCK_WAIT).finish(StageStatus.OK)

        self.assertEqual(stage.start_unix_nano, 123)
        self.assertEqual(stage.duration_nano, 75)

    def test_stage_rejects_unknown_fields_and_invalid_values(self):
        valid = {
            "stage": "lock_wait",
            "start_unix_nano": 1,
            "duration_nano": 2,
            "status": "ok",
        }
        for changes in (
            {"message": "not allowed"},
            {"stage": "arbitrary"},
            {"status": "unknown"},
            {"duration_nano": -1},
            {"start_unix_nano": True},
            {"error_type": "arbitrary"},
        ):
            with self.subTest(changes=changes), self.assertRaises(ValidationError):
                StageTelemetry.model_validate(valid | changes)

    def test_response_rejects_more_than_maximum_stages(self):
        stage = StageTelemetry(
            stage=StageName.LOCK_WAIT,
            start_unix_nano=1,
            duration_nano=2,
            status=StageStatus.OK,
        )
        with self.assertRaises(ValidationError):
            ExecutionResponse(
                outputs="",
                telemetry=[stage] * (MAX_TELEMETRY_STAGES + 1),
            )


class RouteTelemetryTests(unittest.IsolatedAsyncioTestCase):
    async def test_execute_records_lock_user_execution_and_checkpoint(self):
        state = worker_state()
        with (
            patch(
                "worker.routes.execute_kernel_code",
                AsyncMock(return_value=KernelResult(output="result", succeeded=True)),
            ),
            patch("worker.routes.checkpoint_kernel", AsyncMock()) as checkpoint,
        ):
            response = await execute(
                request_with(state),
                ExecutionRequest(code=["print('result')"], language="python"),
            )

        checkpoint.assert_awaited_once_with(state)
        self.assertEqual(
            [(stage.stage, stage.status) for stage in response.telemetry],
            [
                (StageName.LOCK_WAIT, StageStatus.OK),
                (StageName.JUPYTER_USER_EXECUTION, StageStatus.OK),
                (StageName.CHECKPOINT_WRITE, StageStatus.OK),
            ],
        )

    async def test_metadata_records_distinct_jupyter_stage(self):
        state = worker_state()
        with patch(
            "worker.routes.execute_kernel_code",
            AsyncMock(return_value=KernelResult(output="[]", succeeded=True)),
        ):
            response = await metadata(request_with(state))

        self.assertEqual(
            [stage.stage for stage in response.telemetry],
            [StageName.LOCK_WAIT, StageName.JUPYTER_METADATA_EXECUTION],
        )

    async def test_execute_records_bounded_kernel_error_type(self):
        state = worker_state()
        with (
            patch(
                "worker.routes.execute_kernel_code",
                AsyncMock(
                    return_value=KernelResult(
                        output="Error executing code: hidden detail",
                        succeeded=False,
                        error_type=StageErrorType.BINDER_ERROR,
                    )
                ),
            ),
            patch("worker.routes.checkpoint_kernel", AsyncMock()) as checkpoint,
        ):
            response = await execute(
                request_with(state),
                ExecutionRequest(code=["bad sql"], language="sql"),
            )

        checkpoint.assert_not_awaited()
        execution_stage = response.telemetry[-1]
        self.assertEqual(execution_stage.status, StageStatus.ERROR)
        self.assertEqual(execution_stage.error_type, StageErrorType.BINDER_ERROR)

    async def test_timeout_records_execution_and_successful_restart(self):
        state = worker_state()
        with patch(
            "worker.routes.execute_kernel_code",
            AsyncMock(side_effect=TimeoutError),
        ):
            with self.assertRaises(WorkerProtocolError) as raised:
                await execute(
                    request_with(state),
                    ExecutionRequest(code=["pass"], language="python"),
                )

        error = raised.exception
        self.assertEqual(error.status, 408)
        state.restart.assert_awaited_once_with()
        self.assertEqual(
            [(stage.stage, stage.status) for stage in error.telemetry],
            [
                (StageName.LOCK_WAIT, StageStatus.OK),
                (StageName.JUPYTER_USER_EXECUTION, StageStatus.TIMEOUT),
                (StageName.TIMEOUT_KERNEL_RESTART, StageStatus.OK),
            ],
        )

    async def test_checkpoint_failure_and_error_response_include_telemetry(self):
        state = worker_state()
        with (
            patch(
                "worker.routes.execute_kernel_code",
                AsyncMock(return_value=KernelResult(output="", succeeded=True)),
            ),
            patch(
                "worker.routes.checkpoint_kernel",
                AsyncMock(side_effect=RuntimeError("write failed")),
            ),
        ):
            with self.assertRaises(WorkerProtocolError) as raised:
                await execute(
                    request_with(state),
                    ExecutionRequest(code=["pass"], language="python"),
                )

        error = raised.exception
        self.assertEqual(error.telemetry[-1].stage, StageName.CHECKPOINT_WRITE)
        self.assertEqual(error.telemetry[-1].status, StageStatus.ERROR)
        response = await handle_worker_error(request_with(state), error)
        self.assertIn(b'"telemetry"', response.body)
        self.assertNotIn(b'"message":"write failed"', response.body.split(b'"telemetry"')[1])


if __name__ == "__main__":
    unittest.main()
