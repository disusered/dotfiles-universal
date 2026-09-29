#!/usr/bin/env python3
"""Update the existing personal OKF connection; do not register another server."""
import json
import os
from pathlib import Path
import tempfile

home = Path.home()
root = home / "Development/ME/herding-cats"
old = str(home / "Development/okf-toolkit/packages/local-mcp/dist/bin.js")
new = str(root / "utilities/cats-mcp/server.mjs")
if not Path(new).is_file():
    raise SystemExit("Install the Cats launcher in the personal repository first")

def save(path, original, updated):
    if original == updated:
        return
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as f:
        temporary = Path(f.name)
        os.chmod(temporary, path.stat().st_mode & 0o777)
        f.write(updated)
        f.flush()
        os.fsync(f.fileno())
    if path.read_text() != original:
        temporary.unlink()
        raise SystemExit(f"Configuration changed during update: {path}")
    os.replace(temporary, path)

for path in [home / ".config/Claude/claude_desktop_config.json", root / ".mcp.json"]:
    original = path.read_text()
    data = json.loads(original)
    entry = data["mcpServers"]["okf-cats"]
    if entry.get("args") not in ([old, str(root), "--bundle", "polychrome"], [new]):
        raise SystemExit(f"Unexpected okf-cats invocation in {path}; inspect before replacing")
    entry["args"] = [new]
    save(path, original, json.dumps(data, indent=2) + "\n")
    print(f"Updated existing okf-cats in {path}")
path = root / ".codex/config.toml"
original = path.read_text()
start = original.index("[mcp_servers.okf_cats]")
end = original.find("\n[", start + 1)
if end < 0:
    end = len(original)
section = original[start:end]
old_args = json.dumps([old, str(root), "--bundle", "polychrome"])
new_args = json.dumps([new])
if "args = " + new_args not in section:
    if "args = " + old_args not in section:
        raise SystemExit("Unexpected Codex okf_cats arguments")
    section = section.replace("args = " + old_args, "args = " + new_args)
save(path, original, original[:start] + section + original[end:])
print("Updated existing Codex okf_cats")
