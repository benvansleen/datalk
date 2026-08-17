import asyncio
import time

from fastapi import Depends, Request

from .auth import authenticate
from .checkpoint import checkpoint_kernel
from .error_boundary import WorkerProtocolError
from .execution import build_code, execute_kernel_code
from .interface import (
    ExecutionRequest,
    ExecutionResponse,
    ImageAttachment,
    StartupResponse,
)
from .lifespan import app
from .state import WorkerState
from .telemetry import (
    StageErrorType,
    StageName,
    StageStatus,
    StageTelemetry,
    StageTimer,
)


def require_ready(state: WorkerState) -> None:
    if not state.ready:
        raise WorkerProtocolError(
            status=503,
            code="kernel_unavailable",
            message="Kernel is not ready",
        )


@app.get(
    "/v1/startup",
    dependencies=[Depends(authenticate)],
    response_model=StartupResponse,
)
async def startup(request: Request) -> StartupResponse:
    state: WorkerState = request.app.state.worker
    require_ready(state)
    state.last_activity = time.monotonic()

    telemetry, state.startup_telemetry = state.startup_telemetry, []
    return StartupResponse(
        available_dataframes=state.available_dataframes,
        telemetry=telemetry,
    )


@app.post(
    "/v1/execute",
    dependencies=[Depends(authenticate)],
    response_model=ExecutionResponse,
)
async def execute(request: Request, execution: ExecutionRequest) -> ExecutionResponse:
    state: WorkerState = request.app.state.worker
    require_ready(state)
    state.last_activity = time.monotonic()

    telemetry: list[StageTelemetry] = []
    lock_timer = StageTimer.start(StageName.LOCK_WAIT)
    async with state.execution_lock:
        telemetry.append(lock_timer.finish(StageStatus.OK))
        execution_timer = StageTimer.start(StageName.JUPYTER_USER_EXECUTION)
        try:
            result = await asyncio.wait_for(
                execute_kernel_code(
                    state,
                    code=build_code(execution),
                ),
                timeout=state.config.execution_timeout,
            )
        except TimeoutError:
            telemetry.append(
                execution_timer.finish(
                    StageStatus.TIMEOUT,
                    StageErrorType.EXECUTION_TIMEOUT,
                )
            )
            restart_timer = StageTimer.start(StageName.TIMEOUT_KERNEL_RESTART)
            try:
                await state.restart()
            except Exception as e:
                telemetry.append(
                    restart_timer.finish(
                        StageStatus.ERROR,
                        StageErrorType.KERNEL_RESTART_FAILED,
                    )
                )
                raise WorkerProtocolError(
                    status=502,
                    code="kernel_unavailable",
                    message=f"Kernel timeout recovery failed: {e}",
                    telemetry=telemetry,
                ) from e
            telemetry.append(restart_timer.finish(StageStatus.OK))
            raise WorkerProtocolError(
                status=408,
                code="execution_timeout",
                message="Code execution timed out",
                telemetry=telemetry,
            )

        telemetry.append(
            execution_timer.finish(
                StageStatus.OK if result.succeeded else StageStatus.ERROR,
                None
                if result.succeeded
                else result.error_type or StageErrorType.USER_CODE_ERROR,
            )
        )
        if result.succeeded:
            checkpoint_timer = StageTimer.start(StageName.CHECKPOINT_WRITE)
            try:
                await checkpoint_kernel(state)
            except Exception as e:
                telemetry.append(
                    checkpoint_timer.finish(
                        StageStatus.ERROR,
                        StageErrorType.CHECKPOINT_FAILED,
                    )
                )
                raise WorkerProtocolError(
                    status=500,
                    code="checkpoint_failed",
                    message=str(e),
                    telemetry=telemetry,
                ) from e
            telemetry.append(checkpoint_timer.finish(StageStatus.OK))

        state.last_activity = time.monotonic()
        return ExecutionResponse(
            outputs=result.output,
            images=[
                ImageAttachment(id=image.id, mime=image.mime, data=image.data)
                for image in result.images
            ],
            telemetry=telemetry,
        )
