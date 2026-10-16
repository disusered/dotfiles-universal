# Pi

Pi is the Brain agent for Polychrome and everyday work; Claude Code and Codex
stay the coding harnesses. Memory is OptChat, following Victor Taelin's recipe:
https://gist.github.com/VictorTaelin/91837951a5ce5b38f341ec1ba1df6449

## extensions/optchat

Imported on 2026-10-04 from github.com/jonaslsaa/pi-optchat at commit
`419612cf355ecfcd541b477f3d287755b486c24d` (MIT; see its `LICENSE` and
`THIRD_PARTY_NOTICES.md`). Upstream history and remote are not kept; changes
are ours from here.

Reviewed before import: no direct network calls, `eval`, or credential reads.
Model calls go through Pi's SDK. Processes started: `git` for profile
checkpoints, `unzip` for ChatGPT export imports, `xdg-open` for
`/optchat browse`. The four prompts in `src/prompts.ts` match the gist word
for word. `npm run check` and `npm test` (31 tests) pass.

Profile data lives in `~/.optchat/profiles/<name>/`.

## Other extensions

- `pi-you-should-know`: no license upstream, so it is installed from git,
  pinned to reviewed commit `1322e74`, not copied here.
- `pi-notify@1.4.0`, `@bacnh85/pi-checkpoint@0.1.9`: pinned npm packages.

`dot.yaml` registers three MCP servers over HTTP: `brain-portal` and
`xbol-knowledge` on their loopback services, and `iteramind-knowledge` at
`https://okf.iteramind.dev/mcp`, which signs in through Cloudflare Access.

## themes

`themes/cats.json.tera` is a cfg template (`pi-theme` in `cfg/templates.toml`).
It renders `themes/cats.json` from the active cfg flavor, primary, and secondary
colors, so changing them through cfg recolors Pi as well. `dot.yaml` links this
directory to `~/.pi/agent/themes`, and Pi's `"theme": "cats"` setting selects it.
Pi hot-reloads the active theme file, so no reload command is needed.

The roles follow the Herding Cats tokens in `packages/tokens/theme.css`: base,
mantle, and surface0 for the page and panels, overlay2 for dim text, and the
cfg primary as the accent. The `latte` flavor renders a light theme; every
other flavor renders a dark one. The tool success, tool error, and search-match
backgrounds blend green, red, and yellow into base at 16%. Pi does not paint the
terminal background, so panels assume a terminal themed with the same flavor.
