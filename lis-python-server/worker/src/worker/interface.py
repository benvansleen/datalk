from typing import Literal

from pydantic import BaseModel


class ExecutionRequest(BaseModel):
    code: list[str]
    language: Literal["python"] | Literal["sql"]


class ExecutionResponse(BaseModel):
    outputs: str


class MetadataResponse(BaseModel):
    available_dataframes: str
