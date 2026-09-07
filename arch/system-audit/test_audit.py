import datetime as dt
import tempfile
import unittest
import subprocess
from pathlib import Path
from unittest.mock import patch

from audit import capacities, process_identity, retain, store_size


class AuditTests(unittest.TestCase):
    def test_partial_du_total_is_preserved_without_stderr(self):
        result = subprocess.CompletedProcess([], 1, "4096\t/cache\n", "private/path: Permission denied")
        with patch("audit.subprocess.run", return_value=result):
            self.assertEqual(store_size(Path("/cache"), 1),
                             {"path": "/cache", "bytes": 4096, "incomplete": True,
                              "error": "PermissionError"})

    def test_unmounted_volume_does_not_report_parent_capacity(self):
        with patch("audit.os.path.ismount", return_value=False), patch("audit.os.statvfs") as stat:
            self.assertTrue(all(row["error"] == "not mounted" for row in capacities()))
            stat.assert_not_called()

    def test_identity_handles_spaces_parentheses_and_pid_reuse(self):
        fields = ["S"] + ["0"] * 18
        first = "42 (worker (name)) " + " ".join(fields + ["100", "0"])
        second = "42 (worker (name)) " + " ".join(fields + ["200", "0"])
        self.assertEqual(process_identity(first), (42, 100))
        self.assertNotEqual(process_identity(first), process_identity(second))

    def test_retention_keeps_seven_calendar_days_and_unrelated_files(self):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            for entry in ("sample_2026-09-01.jsonl", "storage_2026-08-31.jsonl",
                          "sample_2026-09-07.jsonl", "notes.jsonl", "notes_2020-01-01.jsonl"):
                (directory / entry).touch()
            retain(directory, dt.datetime(2026, 9, 7, tzinfo=dt.timezone.utc))
            self.assertEqual({p.name for p in directory.iterdir()},
                             {"sample_2026-09-01.jsonl", "sample_2026-09-07.jsonl",
                              "notes.jsonl", "notes_2020-01-01.jsonl"})


if __name__ == "__main__":
    unittest.main()
