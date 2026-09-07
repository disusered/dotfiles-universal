#!/usr/bin/env python3
"""Bounded passive host observations; no command lines or environment capture."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import time

UTC = dt.timezone.utc
PROCESS_NAMES = ("betterbird", "valkey", "redis", "romm", "hyprland", "pipewire")


def read(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return None


def command(args, timeout=15):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=True).stdout


def process_identity(stat):
    # comm can contain spaces and parentheses; fields after its final ')' start at 3.
    end = stat.rindex(")")
    return int(stat[:stat.index("(")].strip()), int(stat[end + 2:].split()[19])


def processes():
    rows = []
    for directory in Path("/proc").iterdir():
        if not directory.name.isdigit():
            continue
        name = read(directory / "comm")
        if not name or not any(part in name.lower() for part in PROCESS_NAMES):
            continue
        before = read(directory / "stat")
        status = read(directory / "status")
        after = read(directory / "stat")
        if not before or not after or not status:
            continue
        try:
            identity = process_identity(before)
            if identity != process_identity(after):
                continue
            fields = dict(line.split(":", 1) for line in status.splitlines())
            rows.append({"pid": identity[0], "start_ticks": identity[1], "name": name,
                         "rss_kib": int(fields.get("VmRSS", "0 kB").split()[0])})
        except (ValueError, IndexError):
            continue
    return rows


def services():
    units = json.loads(command(["systemctl", "--user", "list-units", "--type=service",
                                "--state=running", "--output=json", "--no-pager"]))
    names = [unit["unit"] for unit in units][:200]
    if not names:
        return []
    output = command(["systemctl", "--user", "show", *names, "--no-pager",
                      "--property=Id,InvocationID,ControlGroup,MemoryCurrent,CPUUsageNSec"])
    rows = []
    for block in output.strip().split("\n\n"):
        fields = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        rows.append(fields)
    return rows


def sample():
    memory = read("/proc/meminfo") or ""
    wanted = {"MemTotal", "MemAvailable", "SwapTotal", "SwapFree", "Cached", "SReclaimable",
              "SUnreclaim", "Slab", "Dirty", "Writeback"}
    result = {"boot_id": read("/proc/sys/kernel/random/boot_id"),
              "memory_kib": {key: int(value.split()[0]) for key, value in
                             (line.split(":", 1) for line in memory.splitlines()) if key in wanted},
              "pressure": {name: read(f"/proc/pressure/{name}") for name in ("cpu", "memory", "io")},
              "processes": processes()}
    try:
        result["services"] = services()
    except (OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        result["services_error"] = type(error).__name__
    return result


def store_size(path, timeout):
    result = subprocess.run(["du", "-sx", "--block-size=1", "--", str(path)],
                            capture_output=True, text=True, timeout=timeout, check=False)
    row = {"path": str(path)}
    if result.stdout.strip():
        row["bytes"] = int(result.stdout.split()[0])
    if result.returncode:
        row["incomplete"] = True
        row["error"] = "PermissionError" if "Permission denied" in result.stderr else "du failed"
    return row


def capacities():
    rows = []
    for path in ("/", "/home", "/mnt/windows"):
        row = {"path": path}
        try:
            # An unmounted directory would report the parent filesystem misleadingly.
            if not os.path.ismount(path):
                row["error"] = "not mounted"
            else:
                stat = os.statvfs(path)
                row.update(total_bytes=stat.f_blocks * stat.f_frsize,
                           free_bytes=stat.f_bfree * stat.f_frsize,
                           available_bytes=stat.f_bavail * stat.f_frsize)
        except OSError as error:
            row["error"] = type(error).__name__
        rows.append(row)
    return rows


def storage():
    home = Path.home()
    # Only known cache stores, no whole-home or repository-tree traversal.
    targets = [Path("/var/cache/pacman/pkg"), Path("/var/log/journal"),
               Path("/home/system-cache/pacman/pkg"), home / ".cache/uv", home / ".cache/yay",
               home / ".npm", home / ".nuget/packages", home / ".cargo/registry",
               home / ".local/share/containers/storage", home / ".cache/turbo"]
    rows = []
    deadline = time.monotonic() + 240
    for path in targets:
        if time.monotonic() >= deadline:
            rows.append({"path": str(path), "error": "daily time budget exhausted"})
            break
        if not path.exists():
            continue
        try:
            rows.append(store_size(path, min(45, max(1, deadline - time.monotonic()))))
        except (OSError, subprocess.SubprocessError, ValueError) as error:
            rows.append({"path": str(path), "error": type(error).__name__})
    return {"stores": rows, "filesystems": capacities()}


def retain(directory, now):
    cutoff = now.date() - dt.timedelta(days=6)
    for path in directory.glob("*.jsonl"):
        if not path.name.startswith(("sample_", "storage_")):
            continue
        try:
            date = dt.date.fromisoformat(path.stem.rsplit("_", 1)[-1])
        except ValueError:
            continue
        if date < cutoff:
            path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("sample", "storage"))
    parser.add_argument("--stdout", action="store_true", help="Observe once without writing state")
    args = parser.parse_args()
    now = dt.datetime.now(UTC)
    record = {"timestamp": now.isoformat(), "kind": args.kind,
              "data": sample() if args.kind == "sample" else storage()}
    encoded = json.dumps(record, separators=(",", ":")) + "\n"
    if args.stdout:
        print(encoded, end="")
        return
    os.umask(0o077)
    directory = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "system-audit"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    retain(directory, now)
    path = directory / f"{args.kind}_{now.date().isoformat()}.jsonl"
    # Also bound each stream to 16 MiB/day if a timer is accidentally over-triggered.
    if path.exists() and path.stat().st_size + len(encoded.encode()) > 16 * 1024 * 1024:
        return
    with path.open("a") as handle:
        handle.write(encoded)


if __name__ == "__main__":
    main()
