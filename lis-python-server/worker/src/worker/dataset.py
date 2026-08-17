import asyncio
from pathlib import Path
from typing import TYPE_CHECKING

from .execution import execute_kernel_code

if TYPE_CHECKING:
    from .state import WorkerState


def dataset_files(dataset_path: Path) -> list[Path]:
    files = sorted(
        path
        for path in dataset_path.iterdir()
        if path.is_file() and path.suffix.lower() == ".csv"
    )

    if not files:
        raise RuntimeError(f"No CSV files found in dataset directory: {dataset_path}")

    names = set()
    for path in files:
        name = path.stem
        if not name.isidentifier():
            raise RuntimeError(
                f"Dataset filename does not form a valid Python identifier: {path.name}"
            )

        if name in names:
            raise RuntimeError(f"Duplicate dataset variable name: {name}")
        names.add(name)

    return files


def build_dataset_load_code(dataset_path: Path) -> str:
    lines = ["import pandas as pd"]
    for path in dataset_files(dataset_path):
        lines.append(f"{path.stem} = pd.read_csv({str(path)!r})")

    lines.append(
        """
print([
    (name, value.columns, value.shape)
    for name, value in globals().items()
    if type(value) is pd.core.frame.DataFrame and not name.startswith("_")
])
    """.strip()
    )

    return "\n".join(lines)


async def load_dataset(state: "WorkerState") -> str:
    result = await asyncio.wait_for(
        execute_kernel_code(state, build_dataset_load_code(state.config.dataset_path)),
        timeout=state.config.execution_timeout,
    )

    if not result.succeeded:
        raise RuntimeError(f"Dataset initialization failed: {result.output}")

    return result.output
