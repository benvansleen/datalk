from dataclasses import dataclass, field

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .lifespan import app
from .telemetry import StageTelemetry


@dataclass
class WorkerProtocolError(Exception):
    status: int
    code: str
    message: str
    telemetry: list[StageTelemetry] = field(default_factory=list)


@app.exception_handler(WorkerProtocolError)
async def handle_worker_error(_: Request, error: WorkerProtocolError) -> JSONResponse:
    return JSONResponse(
        status_code=error.status,
        content={
            "code": error.code,
            "message": error.message,
            "telemetry": [
                stage.model_dump(mode="json") for stage in error.telemetry
            ],
        },
    )


@app.exception_handler(RequestValidationError)
async def handle_validation_error(
    _: Request, error: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={
            "code": "invalid_request",
            "message": str(error),
        },
    )
