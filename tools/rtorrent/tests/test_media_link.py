from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "rtorrent-media-link"


class MediaLinkTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.downloads = self.root / "downloads"
        self.media = self.root / "media"
        self.roms = self.media / "ROMs"
        self.downloads.mkdir()
        self.media.mkdir()

    def tearDown(self):
        self.temp_dir.cleanup()

    def run_link(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--no-acl",
                "--no-log",
                "--media-root",
                str(self.media),
                "--roms-root",
                str(self.roms),
                *args,
            ],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def test_links_album_directory_without_copying(self):
        album = self.downloads / "Artist - Album"
        album.mkdir()
        track = album / "01 - Track.flac"
        track.write_bytes(b"audio")

        result = self.run_link(str(album))

        self.assertEqual(result.returncode, 0, result.stderr)
        linked = self.media / "Music" / "Artist - Album" / track.name
        self.assertTrue(linked.exists())
        self.assertEqual(track.stat().st_ino, linked.stat().st_ino)

    def test_uses_tv_pattern_and_preserves_sidecars(self):
        episode = self.downloads / "Some Show" / "Some.Show.S02E03.mkv"
        episode.parent.mkdir()
        episode.write_bytes(b"video")
        subtitle = episode.with_suffix(".srt")
        subtitle.write_text("subtitle")

        result = self.run_link(str(episode.parent))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.media / "TV" / "Some Show" / episode.name).exists())
        self.assertTrue((self.media / "TV" / "Some Show" / subtitle.name).exists())
        self.assertFalse((self.media / "Movies" / "Some Show").exists())

    def test_label_overrides_video_routing(self):
        movie = self.downloads / "Feature.mkv"
        movie.write_bytes(b"video")

        result = self.run_link("--label", "tv", str(movie))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.media / "TV" / movie.name).exists())

    def test_routes_rom_to_platform_directory(self):
        rom = self.downloads / "Game.sfc"
        rom.write_bytes(b"rom")

        result = self.run_link(str(rom))

        self.assertEqual(result.returncode, 0, result.stderr)
        linked = self.roms / "snes" / rom.name
        self.assertTrue(linked.exists())
        self.assertEqual(rom.stat().st_ino, linked.stat().st_ino)

    def test_repeat_run_is_idempotent_and_preserves_conflicts(self):
        movie = self.downloads / "Feature.mkv"
        movie.write_bytes(b"video")
        first = self.run_link(str(movie))
        second = self.run_link(str(movie))

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("1 already published", second.stdout)

        other_source = self.downloads / "Other" / "Feature.mkv"
        other_source.parent.mkdir()
        other_source.write_bytes(b"other")
        conflict = self.run_link(str(other_source))
        self.assertEqual(conflict.returncode, 0, conflict.stderr)
        self.assertIn("1 conflicts", conflict.stdout)
        self.assertEqual(
            (self.media / "Movies" / "Feature.mkv").read_bytes(),
            b"video",
        )

    def test_reflink_copy_with_matching_metadata_is_idempotent(self):
        movie = self.downloads / "Feature.mkv"
        movie.write_bytes(b"video")
        os.utime(movie, ns=(1_700_000_000_000_000_000,) * 2)
        published = self.media / "Movies" / movie.name
        published.parent.mkdir()
        shutil.copy2(movie, published)
        self.assertNotEqual(movie.stat().st_ino, published.stat().st_ino)

        result = self.run_link(str(movie))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1 already published", result.stdout)


if __name__ == "__main__":
    unittest.main()
