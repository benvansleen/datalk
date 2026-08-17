import base64
import binascii
import uuid
from dataclasses import dataclass
from typing import TYPE_CHECKING

from jupyter_client import AsyncKernelClient

from .interface import ExecutionRequest
from .telemetry import StageErrorType

if TYPE_CHECKING:
    from .state import WorkerState


IMAGE_MIME_PRIORITY = ("image/png", "image/jpeg", "image/svg+xml")
MAX_IMAGES = 5
MAX_IMAGE_BYTES = 2 * 1024 * 1024


@dataclass(frozen=True)
class KernelImage:
    id: str
    mime: str
    data: str


@dataclass(frozen=True)
class KernelResult:
    output: str
    succeeded: bool
    images: tuple[KernelImage, ...] = ()
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


def require_client(state: "WorkerState") -> AsyncKernelClient:
    if state.client is None:
        raise RuntimeError("Kernel client is not available")
    return state.client


def format_size(size: int) -> str:
    if size >= 1024 * 1024:
        return f"{size / (1024 * 1024):.1f} MiB"
    return f"{size / 1024:.1f} KB"


def extract_image(content: dict) -> tuple[KernelImage, int] | None:
    """Pick the best supported image from a rich-output MIME bundle.

    PNG/JPEG arrive base64-encoded; SVG arrives as raw text and is normalized
    to base64. Returns the image plus its decoded byte size, or None when no
    supported, decodable image is present.
    """
    data = content.get("data") or {}
    for mime in IMAGE_MIME_PRIORITY:
        raw = data.get(mime)
        if not isinstance(raw, str) or not raw.strip():
            continue
        try:
            if mime == "image/svg+xml":
                decoded = raw.encode("utf-8")
            else:
                decoded = base64.b64decode(raw, validate=True)
        except (binascii.Error, UnicodeEncodeError, ValueError):
            continue
        encoded = base64.b64encode(decoded).decode("ascii")
        return KernelImage(id=uuid.uuid4().hex, mime=mime, data=encoded), len(decoded)
    return None


def capture_image(content: dict, images: list[KernelImage], notes: list[str]) -> None:
    captured = extract_image(content)
    if captured is None:
        return
    image, size = captured
    if len(images) >= MAX_IMAGES:
        notes.append(f"[figure skipped: image limit of {MAX_IMAGES} reached]")
        return
    if size > MAX_IMAGE_BYTES:
        notes.append(
            f"[figure skipped: {format_size(size)} exceeds {format_size(MAX_IMAGE_BYTES)} limit]"
        )
        return
    images.append(image)
    notes.append(f"[figure-{len(images)}: {image.mime}, {format_size(size)}]")


async def execute_kernel_code(
    state: "WorkerState",
    code: str,
) -> KernelResult:
    client = require_client(state)
    message_id = client.execute(code, allow_stdin=False)
    output = []
    images: list[KernelImage] = []
    figure_notes: list[str] = []
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
            case "display_data" | "execute_result":
                capture_image(content, images, figure_notes)
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
                text = "".join(output)
                if figure_notes:
                    text = "\n".join([text.rstrip(), *figure_notes]).lstrip("\n")
                return KernelResult(
                    output=text,
                    succeeded=True,
                    images=tuple(images),
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
