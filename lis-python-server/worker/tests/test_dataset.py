import tempfile
import unittest
from pathlib import Path

from worker.dataset import build_dataset_load_code, dataset_files


class DatasetLoadCodeTests(unittest.TestCase):
    def test_generated_dataset_load_code_is_valid_python(self):
        with tempfile.TemporaryDirectory() as tmp:
            dataset_path = Path(tmp)
            (dataset_path / "cfbd_2025_games.csv").write_text("id\n1\n")
            (dataset_path / "cfbd_2025_lines.csv").write_text("id\n1\n")

            code = build_dataset_load_code(dataset_path)

        compile(code, "<dataset-load>", "exec")
        self.assertIn("cfbd_2025_games = pd.read_csv(", code)
        self.assertIn("cfbd_2025_lines = pd.read_csv(", code)
        self.assertIn("print([", code)

    def test_dataset_files_rejects_invalid_and_duplicate_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            dataset_path = Path(tmp)
            (dataset_path / "not an identifier.csv").write_text("id\n")
            with self.assertRaisesRegex(RuntimeError, "valid Python identifier"):
                dataset_files(dataset_path)

        with tempfile.TemporaryDirectory() as tmp:
            dataset_path = Path(tmp)
            (dataset_path / "games.csv").write_text("id\n")
            (dataset_path / "games.CSV").write_text("id\n")
            with self.assertRaisesRegex(RuntimeError, "Duplicate dataset variable name"):
                dataset_files(dataset_path)

    def test_dataset_files_requires_csv_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError, "No CSV files found"):
                dataset_files(Path(tmp))


if __name__ == "__main__":
    unittest.main()
