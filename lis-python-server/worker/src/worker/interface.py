from typing import Literal

from pydantic import BaseModel, Field

from .telemetry import Telemetry

ImageMime = Literal["image/png"] | Literal["image/jpeg"] | Literal["image/svg+xml"]

# ceil(4/3 * 2 MiB) base64 characters for a 2 MiB decoded image.
MAX_IMAGE_BASE64_LENGTH = 2_800_000


class ExecutionRequest(BaseModel):
    code: list[str]
    language: Literal["python"] | Literal["sql"]


class ImageAttachment(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    mime: ImageMime
    data: str = Field(min_length=1, max_length=MAX_IMAGE_BASE64_LENGTH)


class ExecutionResponse(BaseModel):
    outputs: str
    images: list[ImageAttachment] = Field(default_factory=list, max_length=5)
    telemetry: Telemetry


class StartupResponse(BaseModel):
    available_dataframes: str
    telemetry: Telemetry
