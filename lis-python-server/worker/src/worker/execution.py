from dataclasses import dataclass
from typing import TYPE_CHECKING

from jupyter_client import AsyncKernelClient

from .interface import ExecutionRequest
from .telemetry import StageErrorType

if TYPE_CHECKING:
    from .state import WorkerState


@dataclass(frozen=True)
class KernelResult:
    output: str
    succeeded: bool
    error_type: StageErrorType | None = None


KERNEL_ERROR_TYPES = {
    "SyntaxError": StageErrorType.SYNTAX_ERROR,
    "NameError": StageErrorType.NAME_ERROR,
    "TypeError": StageErrorType.TYPE_ERROR,
    "ValueError": StageErrorType.VALUE_ERROR,
    "KeyError": StageErrorType.KEY_ERROR,
    "IndexError": StageErrorType.INDEX_ERROR,
    "AttributeError": StageErrorType.ATTRIBUTE_ERROR,
    "ImportError": StageErrorType.IMPORT_ERROR,
    "ModuleNotFoundError": StageErrorType.MODULE_NOT_FOUND_ERROR,
    "ZeroDivisionError": StageErrorType.ZERO_DIVISION_ERROR,
    "ParserException": StageErrorType.PARSER_ERROR,
    "BinderException": StageErrorType.BINDER_ERROR,
    "CatalogException": StageErrorType.CATALOG_ERROR,
    "ConversionException": StageErrorType.CONVERSION_ERROR,
    "ConstraintException": StageErrorType.CONSTRAINT_ERROR,
    "IOException": StageErrorType.IO_ERROR,
}


def classify_kernel_error(error_name: object) -> StageErrorType:
    match error_name:
        case str():
            return KERNEL_ERROR_TYPES.get(error_name, StageErrorType.USER_CODE_ERROR)
        case _:
            return StageErrorType.USER_CODE_ERROR


def require_client(state: WorkerState) -> AsyncKernelClient:
    if state.client is None:
        raise RuntimeError("Kernel client is not available")
    return state.client


async def execute_kernel_code(
    state: WorkerState,
    code: str,
) -> KernelResult:
    client = require_client(state)
    message_id = client.execute(code, allow_stdin=False)
    output = []
    kernel_error: str | None = None
    kernel_error_type: StageErrorType | None = None

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
                kernel_error_type = classify_kernel_error(content.get("ename"))
            case "status" if content["execution_state"] == "idle":
                if kernel_error is not None:
                    return KernelResult(
                        output=kernel_error,
                        succeeded=False,
                        error_type=kernel_error_type,
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
            return f"""
import duckdb

__datalk_dataframes = {{
    name: value
    for name, value in globals().items()
    if type(value) is pd.core.frame.DataFrame and not name.startswith('_')
    and name != 'sql_output'
}}

for __datalk_name in globals().get('__datalk_registered_dataframes', set()) - __datalk_dataframes.keys():
    duckdb.unregister(__datalk_name)

for __datalk_name, __datalk_value in __datalk_dataframes.items():
    duckdb.register(__datalk_name, __datalk_value)

__datalk_registered_dataframes = set(__datalk_dataframes)
sql_output = duckdb.sql({statement!r}).df()
print(sql_output)
            """.strip()
