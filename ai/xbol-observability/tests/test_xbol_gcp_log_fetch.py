import datetime as dt
import importlib.util
import importlib.machinery
from pathlib import Path
import unittest


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "xbol-gcp-log-fetch"


def load_fetcher():
    loader = importlib.machinery.SourceFileLoader("xbol_gcp_log_fetch", str(SCRIPT_PATH))
    spec = importlib.util.spec_from_loader("xbol_gcp_log_fetch", loader)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class XbolGcpLogFetchTests(unittest.TestCase):
    def setUp(self):
        self.fetcher = load_fetcher()

    def test_spool_entry_preserves_raw_cloud_logging_payload(self):
        entry = {
            "insertId": "abc123",
            "logName": "projects/boletera-qa/logs/stdout",
            "resource": {
                "type": "k8s_container",
                "labels": {
                    "cluster_name": "boletera-qa",
                    "namespace_name": "dev-boletera",
                },
            },
            "severity": "INFO",
            "timestamp": "2026-05-25T18:55:55.935384764Z",
            "jsonPayload": {
                "message": "authorization=Bearer real-token",
                "nested": {"password": "real-password"},
            },
        }

        row = self.fetcher.spool_entry(entry)

        self.assertEqual(row, entry)
        self.assertEqual(row["jsonPayload"]["message"], "authorization=Bearer real-token")
        self.assertEqual(row["jsonPayload"]["nested"]["password"], "real-password")

    def test_stale_high_water_uses_lookback_window(self):
        now = dt.datetime(2026, 5, 25, 19, 10, tzinfo=dt.timezone.utc)
        stale_high_water = dt.datetime(2026, 5, 23, 17, 37, tzinfo=dt.timezone.utc)

        start = self.fetcher.fetch_start(
            high_water=stale_high_water,
            end=now,
            lookback_minutes=15,
            overlap_minutes=2,
            max_state_age_minutes=60,
        )

        self.assertEqual(start, now - dt.timedelta(minutes=15))

    def test_recent_high_water_uses_overlap_window(self):
        now = dt.datetime(2026, 5, 25, 19, 10, tzinfo=dt.timezone.utc)
        recent_high_water = dt.datetime(2026, 5, 25, 19, 7, tzinfo=dt.timezone.utc)

        start = self.fetcher.fetch_start(
            high_water=recent_high_water,
            end=now,
            lookback_minutes=15,
            overlap_minutes=2,
            max_state_age_minutes=60,
        )

        self.assertEqual(start, recent_high_water - dt.timedelta(minutes=2))


if __name__ == "__main__":
    unittest.main()
