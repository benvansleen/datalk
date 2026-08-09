import os
from dataclasses import dataclass
from pathlib import Path
from typing import Self


@dataclass(frozen=True)
class Config:
    token: str
    dataset_path: Path
    checkpoint_path: Path
    execution_timeout: float
    idle_timeout: float
    port: int

    @classmethod
    def from_env(cls) -> Self:
        config = cls(
            token=os.environ["DATALK_WORKER_TOKEN"],
            dataset_path=Path(os.environ["DATALK_DATASET_PATH"]),
            checkpoint_path=Path(os.environ["DATALK_CHECKPOINT_PATH"]),
            execution_timeout=float(os.environ["DATALK_EXECUTION_TIMEOUT_SECONDS"]),
            idle_timeout=float(os.environ["DATALK_IDLE_TIMEOUT_SECONDS"]),
            port=int(os.environ["DATALK_PORT"]),
        )

        if not config.token:
            raise ValueError("DATALK_WORKER_TOKEN is empty")
        if not config.dataset_path.is_dir():
            raise ValueError(f"Dataset directory does not exist: {config.dataset_path}")
        if config.execution_timeout <= 0:
            raise ValueError("Execution timeout must be positive")
        if config.idle_timeout <= 0:
            raise ValueError("Idle timeout must be positive")
        if not 1 <= config.port <= 65535:
            raise ValueError("Worker port is invalid")

        return config
