import base64
import io
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from worker.execution import (
    MAX_IMAGES,
    MAX_IMAGE_BYTES,
    KernelImage,
    capture_image,
    execute_kernel_code,
    extract_image,
    format_size,
)


def png_content(size_bytes: int) -> dict:
    return {"data": {"image/png": base64.b64encode(b"\x89PNG" + b"x" * size_bytes).decode()}}


def svg_content(markup: str) -> dict:
    return {"data": {"image/svg+xml": markup}}


class ExtractImageTests(unittest.TestCase):
    def test_prefers_png_over_jpeg_and_svg(self):
        content = {
            "data": {
                "image/svg+xml": "<svg/>",
                "image/jpeg": base64.b64encode(b"jpeg-bytes").decode(),
                "image/png": base64.b64encode(b"png-bytes").decode(),
            }
        }

        captured = extract_image(content)

        self.assertIsNotNone(captured)
        image, size = captured
        self.assertEqual(image.mime, "image/png")
        self.assertEqual(base64.b64decode(image.data), b"png-bytes")
        self.assertEqual(size, len(b"png-bytes"))

    def test_normalizes_svg_to_base64(self):
        captured = extract_image(svg_content("<svg><circle/></svg>"))

        self.assertIsNotNone(captured)
        image, size = captured
        self.assertEqual(image.mime, "image/svg+xml")
        self.assertEqual(
            base64.b64decode(image.data).decode("utf-8"),
            "<svg><circle/></svg>",
        )
        self.assertEqual(size, len("<svg><circle/></svg>".encode()))

    def test_skips_invalid_base64_and_empty_bundles(self):
        self.assertIsNone(extract_image({"data": {"image/png": "!!not base64!!"}}))
        self.assertIsNone(extract_image({"data": {"text/plain": "hello"}}))
        self.assertIsNone(extract_image({"data": {}}))
        self.assertIsNone(extract_image({}))


class CaptureImageTests(unittest.TestCase):
    def test_appends_figure_note_and_image(self):
        images: list[KernelImage] = []
        notes: list[str] = []

        capture_image(png_content(10), images, notes)

        self.assertEqual(len(images), 1)
        self.assertEqual(notes, [f"[figure-1: image/png, {format_size(10)}]"])

    def test_skips_oversized_images_with_note(self):
        images: list[KernelImage] = []
        notes: list[str] = []

        capture_image(png_content(MAX_IMAGE_BYTES + 1), images, notes)

        self.assertEqual(images, [])
        self.assertEqual(
            notes,
            [
                f"[figure skipped: {format_size(MAX_IMAGE_BYTES + 1)} exceeds "
                f"{format_size(MAX_IMAGE_BYTES)} limit]"
            ],
        )

    def test_stops_after_max_images(self):
        images: list[KernelImage] = []
        notes: list[str] = []

        for _ in range(MAX_IMAGES + 2):
            capture_image(png_content(10), images, notes)

        self.assertEqual(len(images), MAX_IMAGES)
        self.assertEqual(
            notes[MAX_IMAGES:],
            [f"[figure skipped: image limit of {MAX_IMAGES} reached]"] * 2,
        )


def iopub(msg_type: str, content: dict, parent: str) -> dict:
    return {
        "msg_type": msg_type,
        "content": content,
        "parent_header": {"msg_id": parent},
    }


class ExecuteKernelCodeTests(unittest.IsolatedAsyncioTestCase):
    async def test_captures_display_data_and_execute_result_images(self):
        png = base64.b64encode(b"figure-bytes").decode()
        client = SimpleNamespace(
            execute=MagicMock(return_value="msg-1"),
            get_iopub_msg=AsyncMock(
                side_effect=[
                    iopub("stream", {"text": "hello "}, "msg-1"),
                    iopub("display_data", {"data": {"image/png": png}}, "msg-1"),
                    iopub("stream", {"text": "world"}, "msg-1"),
                    iopub(
                        "execute_result",
                        {"data": {"image/svg+xml": "<svg/>"}},
                        "msg-1",
                    ),
                    iopub("status", {"execution_state": "idle"}, "msg-1"),
                ]
            ),
        )

        result = await execute_kernel_code(SimpleNamespace(client=client), "code")

        self.assertTrue(result.succeeded)
        self.assertEqual(len(result.images), 2)
        self.assertEqual(result.images[0].mime, "image/png")
        self.assertEqual(result.images[1].mime, "image/svg+xml")
        self.assertIn("hello world", result.output)
        self.assertIn("[figure-1: image/png,", result.output)
        self.assertIn("[figure-2: image/svg+xml,", result.output)

    async def test_discards_images_on_error(self):
        client = SimpleNamespace(
            execute=MagicMock(return_value="msg-1"),
            get_iopub_msg=AsyncMock(
                side_effect=[
                    iopub("display_data", {"data": {"image/png": "aGVsbG8="}}, "msg-1"),
                    iopub("error", {"ename": "ValueError", "evalue": "boom"}, "msg-1"),
                    iopub("status", {"execution_state": "idle"}, "msg-1"),
                ]
            ),
        )

        result = await execute_kernel_code(SimpleNamespace(client=client), "code")

        self.assertFalse(result.succeeded)
        self.assertEqual(result.output, "Error executing code: boom")
        self.assertEqual(result.images, ())

    async def test_ignores_messages_from_other_executions(self):
        client = SimpleNamespace(
            execute=MagicMock(return_value="msg-1"),
            get_iopub_msg=AsyncMock(
                side_effect=[
                    iopub("display_data", {"data": {"image/png": "aGVsbG8="}}, "other"),
                    iopub("status", {"execution_state": "idle"}, "msg-1"),
                ]
            ),
        )

        result = await execute_kernel_code(SimpleNamespace(client=client), "code")

        self.assertTrue(result.succeeded)
        self.assertEqual(result.images, ())


class FormatSizeTests(unittest.TestCase):
    def test_formats_kb_and_mib(self):
        self.assertEqual(format_size(512), "0.5 KB")
        self.assertEqual(format_size(1024 * 1024), "1.0 MiB")


if __name__ == "__main__":
    unittest.main()
