import asyncio
import time

from fastapi import Depends, Request

from .auth import authenticate
from .checkpoint import checkpoint_kernel
from .error_boundary import WorkerProtocolError
from .execution import build_code, execute_kernel_code
from .interface import ExecutionRequest, ExecutionResponse, MetadataResponse
from .lifespan import app
from .state import WorkerState


def require_ready(state: WorkerState) -> None:
    if not state.ready:
        raise WorkerProtocolError(
            status=503,
            code="kernel_unavailable",
            message="Kernel is not ready",
        )


@app.get(
    "/v1/metadata",
    dependencies=[Depends(authenticate)],
    response_model=MetadataResponse,
)
async def metadata(request: Request) -> MetadataResponse:
    state: WorkerState = request.app.state.worker
    require_ready(state)
    state.last_activity = time.monotonic()

    async with state.execution_lock:
        try:
            result = await asyncio.wait_for(
                execute_kernel_code(state, metadata_code()),
                timeout=state.config.execution_timeout,
            )
        except TimeoutError:
            try:
                await state.restart()
            except Exception as e:
                raise WorkerProtocolError(
                    status=502,
                    code="kernel_unavailable",
                    message=f"Kernel timeout recovery failed: {e}",
                ) from e
            raise WorkerProtocolError(
                status=408,
                code="execution_timeout",
                message="Code execution timed out",
            )

    if not result.succeeded:
        raise WorkerProtocolError(
            status=502,
            code="kernel_unavailable",
            message=result.output,
        )

    return MetadataResponse(available_dataframes=result.output)


@app.post(
    "/v1/execute",
    dependencies=[Depends(authenticate)],
    response_model=ExecutionResponse,
)
async def execute(request: Request, execution: ExecutionRequest) -> ExecutionResponse:
    state: WorkerState = request.app.state.worker
    require_ready(state)
    state.last_activity = time.monotonic()

    async with state.execution_lock:
        try:
            result = await asyncio.wait_for(
                execute_kernel_code(
                    state,
                    code=build_code(execution),
                ),
                timeout=state.config.execution_timeout,
            )
        except TimeoutError:
            try:
                await state.restart()
            except Exception as e:
                raise WorkerProtocolError(
                    status=502,
                    code="kernel_unavailable",
                    message=f"Kernel timeout recovery failed: {e}",
                ) from e
            raise WorkerProtocolError(
                status=408,
                code="execution_timeout",
                message="Code execution timed out",
            )

        if result.succeeded:
            try:
                await checkpoint_kernel(state)
            except Exception as e:
                raise WorkerProtocolError(
                    status=500,
                    code="checkpoint_failed",
                    message=str(e),
                ) from e

        state.last_activity = time.monotonic()
        return ExecutionResponse(outputs=result.output)


def metadata_code() -> str:
    return """
print([
    (name, value.columns, value.shape)
    for name, value in globals().items()
    if type(value) is pd.core.frame.DataFrame and not name.startswith("_")
])
        """
