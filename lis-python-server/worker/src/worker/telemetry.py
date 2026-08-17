import time
from dataclasses import dataclass
from enum import StrEnum
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

MAX_TELEMETRY_STAGES = 5


class StageName(StrEnum):
    KERNEL_START = "kernel_start"
    KERNEL_READY_WAIT = "kernel_ready_wait"
    DATASET_LOAD = "dataset_load"
    CHECKPOINT_RESTORE = "checkpoint_restore"
    LOCK_WAIT = "lock_wait"
    JUPYTER_USER_EXECUTION = "jupyter_user_execution"
    CHECKPOINT_WRITE = "checkpoint_write"
    TIMEOUT_KERNEL_RESTART = "timeout_kernel_restart"


class StageStatus(StrEnum):
    OK = "ok"
    ERROR = "error"
    TIMEOUT = "timeout"


class StageErrorType(StrEnum):
    USER_CODE_ERROR = "user_code_error"
    SYNTAX_ERROR = "syntax_error"
    NAME_ERROR = "name_error"
    TYPE_ERROR = "type_error"
    VALUE_ERROR = "value_error"
    KEY_ERROR = "key_error"
    INDEX_ERROR = "index_error"
    ATTRIBUTE_ERROR = "attribute_error"
    IMPORT_ERROR = "import_error"
    MODULE_NOT_FOUND_ERROR = "module_not_found_error"
    ZERO_DIVISION_ERROR = "zero_division_error"
    PARSER_ERROR = "parser_error"
    BINDER_ERROR = "binder_error"
    CATALOG_ERROR = "catalog_error"
    CONVERSION_ERROR = "conversion_error"
    CONSTRAINT_ERROR = "constraint_error"
    IO_ERROR = "io_error"
    EXECUTION_TIMEOUT = "execution_timeout"
    KERNEL_RESTART_FAILED = "kernel_restart_failed"
    CHECKPOINT_FAILED = "checkpoint_failed"


class StageTelemetry(BaseModel):
    model_config = ConfigDict(extra="forbid")

    stage: StageName
    start_unix_nano: int = Field(strict=True, ge=0)
    duration_nano: int = Field(strict=True, ge=0)
    status: StageStatus
    error_type: StageErrorType | None = None


Telemetry = Annotated[list[StageTelemetry], Field(max_length=MAX_TELEMETRY_STAGES)]


@dataclass(frozen=True)
class StageTimer:
    stage: StageName
    start_unix_nano: int
    start_monotonic_nano: int

    @classmethod
    def start(cls, stage: StageName) -> "StageTimer":
        return cls(
            stage=stage,
            start_unix_nano=time.time_ns(),
            start_monotonic_nano=time.monotonic_ns(),
        )

    def finish(
        self,
        status: StageStatus,
        error_type: StageErrorType | None = None,
    ) -> StageTelemetry:
        return StageTelemetry(
            stage=self.stage,
            start_unix_nano=self.start_unix_nano,
            duration_nano=max(0, time.monotonic_ns() - self.start_monotonic_nano),
            status=status,
            error_type=error_type,
        )
