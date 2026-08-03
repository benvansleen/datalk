from typing import Literal

from pydantic import BaseModel

from .telemetry import Telemetry


class ExecutionRequest(BaseModel):
    code: list[str]
    language: Literal["python"] | Literal["sql"]


class ExecutionResponse(BaseModel):
    outputs: str
    telemetry: Telemetry


class MetadataResponse(BaseModel):
    available_dataframes: str
    telemetry: Telemetry
