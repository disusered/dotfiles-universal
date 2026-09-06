# Blender MCP

Arch Linux setup for Blender and `blender-mcp==1.9.1`, using Python 3.11 through uv.
Keep the system updated before installing Blender so its shared libraries match.

```sh
~/.rotz/bin/rotz install /ai/blender-mcp
```

The module installs and enables the bundled add-on, disables telemetry and optional
asset services, and saves manual server startup in Blender's startup scene.
It changes the installed add-on's auto-start property default to false: upstream
registers the add-on before loading the saved startup scene, so the saved checkbox
alone does not prevent a listener from starting. The patch checks the pinned source
before applying and must be reviewed when updating the package version.
Existing startup and preference files receive a `.before-blender-mcp` backup.
The installer registers Claude Code's user server if absent. Codex's matching
server configuration lives in `ai/codex/config.toml`, linked by `/ai/codex`.
Both clients must already be installed. An existing Claude server is preserved;
when upgrading MCP, update its registration and the pins in this module and Codex.

Open Blender, press **N** in the 3D viewport, open **MCP for Blender**, and click
**Connect to Claude** (also described upstream as **Start MCP Server**).
Restart the desired client to load its `blender` tools. Use one client connection
at a time. The add-on listens on localhost port 9876.

Manual startup is saved with the startup scene; imported `.blend` files can carry
their own scene settings. Keep **Auto-Start Server** disabled in those files too.

Upstream: https://github.com/ahujasid/blender-mcp
