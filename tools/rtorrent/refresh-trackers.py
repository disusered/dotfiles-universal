#!/usr/bin/env python3
"""Inject the latest live public trackers into rtorrent .session torrents.

Source: https://github.com/ngosang/trackerslist (auto-pruned alive list).
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_SESSION = Path.home() / "Downloads/rtorrent/.session"
CACHE_DIR = Path.home() / ".cache/rtorrent-tracker-refresh"
LIST_URL = "https://raw.githubusercontent.com/ngosang/trackerslist/master/{}.txt"


def bdecode(data: bytes, idx: int = 0):
    c = data[idx : idx + 1]
    if c == b"i":
        end = data.index(b"e", idx)
        return int(data[idx + 1 : end]), end + 1
    if c.isdigit():
        colon = data.index(b":", idx)
        n = int(data[idx:colon])
        return data[colon + 1 : colon + 1 + n], colon + 1 + n
    if c == b"l":
        idx += 1
        out = []
        while data[idx : idx + 1] != b"e":
            v, idx = bdecode(data, idx)
            out.append(v)
        return out, idx + 1
    if c == b"d":
        idx += 1
        out = {}
        while data[idx : idx + 1] != b"e":
            k, idx = bdecode(data, idx)
            v, idx = bdecode(data, idx)
            out[k] = v
        return out, idx + 1
    raise ValueError(f"bad bencode at offset {idx}: {c!r}")


def bencode(v) -> bytes:
    if isinstance(v, bool):
        raise TypeError("bencode does not support bool")
    if isinstance(v, int):
        return f"i{v}e".encode()
    if isinstance(v, bytes):
        return f"{len(v)}:".encode() + v
    if isinstance(v, str):
        return bencode(v.encode())
    if isinstance(v, list):
        return b"l" + b"".join(bencode(x) for x in v) + b"e"
    if isinstance(v, dict):
        items = sorted(v.items(), key=lambda kv: kv[0])
        return b"d" + b"".join(bencode(k) + bencode(val) for k, val in items) + b"e"
    raise TypeError(f"cannot bencode {type(v).__name__}")


def existing_trackers(meta: dict) -> set[bytes]:
    seen: set[bytes] = set()
    if b"announce" in meta:
        seen.add(meta[b"announce"])
    for tier in meta.get(b"announce-list") or []:
        for t in tier:
            seen.add(t)
    return seen


def patch(meta: dict, new_trackers: list[bytes]) -> int:
    """Prepend a new tier with new_trackers (deduped). Returns count added."""
    seen = existing_trackers(meta)
    fresh = [t for t in new_trackers if t not in seen]
    if not fresh:
        return 0
    al = meta.get(b"announce-list") or []
    # BEP 12: if announce-list is set, it should also represent the announce field.
    if not al and b"announce" in meta:
        al = [[meta[b"announce"]]]
    meta[b"announce-list"] = [fresh] + al
    return len(fresh)


def atomic_write(path: Path, data: bytes) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def fetch_list(name: str) -> bytes:
    url = LIST_URL.format(name)
    req = urllib.request.Request(url, headers={"User-Agent": "rtorrent-tracker-refresh/1"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.read()


def parse_list(blob: bytes) -> list[bytes]:
    out = []
    for line in blob.splitlines():
        line = line.strip()
        if line and not line.startswith(b"#"):
            out.append(line)
    return out


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Refresh dead UDP trackers in rtorrent .session torrents.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  rtorrent-refresh-trackers                 # fetch + patch\n"
            "  rtorrent-refresh-trackers --no-fetch      # use cached list\n"
            "  rtorrent-refresh-trackers --dry-run       # preview\n"
            "  rtorrent-refresh-trackers --list trackers_all_udp\n"
        ),
    )
    p.add_argument(
        "--no-fetch",
        action="store_true",
        help="skip downloading the trackerslist; reuse the cached copy",
    )
    p.add_argument(
        "--list",
        default="trackers_best",
        help="ngosang/trackerslist name (default: trackers_best)",
    )
    p.add_argument(
        "--session-dir",
        type=Path,
        default=DEFAULT_SESSION,
        help=f"rtorrent session dir (default: {DEFAULT_SESSION})",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="show what would change without writing",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if subprocess.run(["pgrep", "-x", "rtorrent"], stdout=subprocess.DEVNULL).returncode == 0:
        print("error: rtorrent is running. Quit it first (Ctrl+Q in the UI).", file=sys.stderr)
        return 1

    cache_path = CACHE_DIR / f"{args.list}.txt"
    if args.no_fetch:
        if not cache_path.exists():
            print(f"error: no cached list at {cache_path}; rerun without --no-fetch", file=sys.stderr)
            return 1
        print(f"using cached list {cache_path}")
    else:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        try:
            blob = fetch_list(args.list)
        except urllib.error.URLError as e:
            print(f"error: fetch failed: {e}", file=sys.stderr)
            if cache_path.exists():
                print(f"  falling back to cached {cache_path}", file=sys.stderr)
            else:
                return 1
        else:
            cache_path.write_bytes(blob)
            print(f"fetched {LIST_URL.format(args.list)} -> {cache_path}")

    trackers = parse_list(cache_path.read_bytes())
    if not trackers:
        print(f"error: tracker list is empty: {cache_path}", file=sys.stderr)
        return 1
    print(f"  {len(trackers)} trackers in list")

    sd: Path = args.session_dir
    if not sd.is_dir():
        print(f"error: session dir {sd} not found", file=sys.stderr)
        return 1
    torrents = sorted(sd.glob("*.torrent"))
    if not torrents:
        print(f"no .torrent files in {sd}")
        return 0

    if not args.dry_run:
        backup = sd.parent / f".session.bak-{time.strftime('%Y%m%d-%H%M%S')}"

        def skip_nonregular(src: str, names: list[str]) -> list[str]:
            return [n for n in names if not (Path(src) / n).is_file()]

        shutil.copytree(sd, backup, ignore=skip_nonregular)
        print(f"backed up {sd} -> {backup}")

    added_total = 0
    changed = 0
    for tp in torrents:
        try:
            meta, _ = bdecode(tp.read_bytes())
        except (ValueError, IndexError) as e:
            print(f"  ! {tp.name}  parse error: {e}", file=sys.stderr)
            continue
        if not isinstance(meta, dict):
            print(f"  ! {tp.name}  not a dict at top level, skipping", file=sys.stderr)
            continue
        added = patch(meta, trackers)
        if added == 0:
            print(f"  · {tp.name}  no change")
            continue
        if not args.dry_run:
            atomic_write(tp, bencode(meta))
        suffix = " (dry)" if args.dry_run else ""
        print(f"  ✓ {tp.name}  +{added} trackers{suffix}")
        added_total += added
        changed += 1

    print(f"done: {changed}/{len(torrents)} torrents touched, {added_total} entries added")
    if changed and not args.dry_run:
        print("start rtorrent to pick up changes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
