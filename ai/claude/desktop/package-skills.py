#!/usr/bin/env python3
"""Build direct-upload skill archives from their canonical dotfiles sources."""

import hashlib
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


def main():
    here = Path(__file__).resolve().parent
    source = here.parents[1] / "agent-skills"
    dest = here / "dist"
    dest.mkdir(exist_ok=True)
    receipts = []
    for name in ("plain-english", "report-to-carlos", "okf-knowledge-ops", "okf-shared-bundle"):
        root = source / name
        if not (root / "SKILL.md").is_file():
            raise FileNotFoundError(root / "SKILL.md")
        archive = dest / f"{name}.zip"
        with ZipFile(archive, "w", compression=ZIP_DEFLATED) as output:
            for file in sorted(root.rglob("*")):
                relative = file.relative_to(root)
                if file.is_file() and not any(p.startswith(".") or p == "__pycache__" for p in relative.parts):
                    entry = ZipInfo(f"{name}/{relative.as_posix()}", date_time=(2026, 9, 5, 0, 0, 0))
                    entry.compress_type = ZIP_DEFLATED
                    entry.external_attr = 0o100644 << 16
                    output.writestr(entry, file.read_bytes())
        receipts.append({"skill": name, "file": archive.name,
                         "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()})
    (dest / "manifest.json").write_text(json.dumps(receipts, indent=2) + "\n")
    print(json.dumps(receipts, indent=2))


if __name__ == "__main__":
    main()
