"""Install the pinned add-on and save Blender preferences and startup settings."""

import os
from pathlib import Path
import shutil
import subprocess

import addon_utils
import bpy


if "blender_mcp" in bpy.context.preferences.addons:
    addon_utils.disable("blender_mcp", default_set=False)
addons_dir = bpy.utils.user_resource("SCRIPTS", path="addons", create=True)
subprocess.run(
    [
        "/usr/bin/uvx", "--python", "3.11", "blender-mcp==1.9.1",
        "install-addon", "--addons-dir", addons_dir,
    ],
    check=True,
    env={**os.environ, "DISABLE_TELEMETRY": "true"},
)
# Registration happens before the startup scene is loaded. Its saved checkbox
# alone cannot prevent upstream's automatic listener from starting on launch.
addon_path = Path(addons_dir) / "blender_mcp.py"
source = addon_path.read_text()
original = '''    bpy.types.Scene.blendermcp_auto_start_server = bpy.props.BoolProperty(
        name="Auto-Start Server",
        description="Automatically start the MCP server when Blender loads",
        default=True
    )'''
if source.count(original) != 1:
    raise RuntimeError("Upstream auto-start definition changed; review the manual-start patch")
fallback = "        port = 9876\n        auto_start = True"
if source.count(fallback) != 1:
    raise RuntimeError("Upstream startup fallback changed; review the manual-start patch")
source = source.replace(original, original.replace("default=True", "default=False"))
addon_path.write_text(source.replace(fallback, fallback.replace("auto_start = True", "auto_start = False")))
bpy.utils.refresh_script_paths()

# Set the stored scene value before registration, whose upstream default is true.
for scene in bpy.data.scenes:
    scene["blendermcp_auto_start_server"] = False
addon = addon_utils.enable("blender_mcp", default_set=True, persistent=True)
if addon is None:
    raise RuntimeError("Blender MCP add-on could not be enabled")
bpy.context.preferences.addons["blender_mcp"].preferences.telemetry_consent = False

if getattr(bpy.types, "blendermcp_server", None):
    bpy.ops.blendermcp.stop_server()

for scene in bpy.data.scenes:
    scene.blendermcp_auto_start_server = False
    scene.blendermcp_port = 9876
    for integration in ("polyhaven", "hyper3d", "hunyuan3d", "sketchfab", "polypizza"):
        setattr(scene, f"blendermcp_use_{integration}", False)

config_dir = Path(bpy.utils.user_resource("CONFIG", create=True))
for name in ("startup.blend", "userpref.blend"):
    original = config_dir / name
    backup = config_dir / f"{name}.before-blender-mcp"
    if original.exists() and not backup.exists():
        shutil.copy2(original, backup)
bpy.ops.wm.save_userpref()
bpy.ops.wm.save_homefile()
print("Blender MCP enabled; telemetry and automatic server startup disabled.")
