from dataclasses import dataclass
from typing import TYPE_CHECKING

from jupyter_client import AsyncKernelClient

from .interface import ExecutionRequest

if TYPE_CHECKING:
    from .state import WorkerState


@dataclass(frozen=True)
class KernelResult:
    output: str
    succeeded: bool


def require_client(state: "WorkerState") -> AsyncKernelClient:
    if state.client is None:
        raise RuntimeError("Kernel client is not available")
    return state.client


async def execute_kernel_code(
    state: "WorkerState",
    code: str,
) -> KernelResult:
    client = require_client(state)
    message_id = client.execute(code, allow_stdin=False)
    output = []
    kernel_error: str | None = None

    while True:
        message = await client.get_iopub_msg()
        parent_id = message.get("parent_header", {}).get("msg_id")
        if parent_id != message_id:
            continue

        message_type = message["msg_type"]
        content = message["content"]

        match message_type:
            case "stream":
                output.append(content["text"])
            case "error":
                kernel_error = f"Error executing code: {content['evalue']}"
            case "status" if content["execution_state"] == "idle":
                if kernel_error is not None:
                    return KernelResult(
                        output=kernel_error,
                        succeeded=False,
                    )
                return KernelResult(
                    output="".join(output),
                    succeeded=True,
                )
            case _:
                pass


def build_code(request: ExecutionRequest) -> str:
    match request.language:
        case "python":
            return "\n".join(request.code)

        case "sql":
            statement = "\n".join(line.replace("\n", " ") for line in request.code)
            return "\n".join(
                [
                    "import duckdb",
                    f"sql_output = duckdb.sql({statement!r}).df()",
                    "print(sql_output)",
                ]
            )
