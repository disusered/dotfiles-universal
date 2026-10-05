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

MCP servers `okf-cats` and `portal-tasks` come from the Herding Cats checkout.
