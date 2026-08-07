---
name: openviking-profiles
description: Provision, audit, or repair a per-project OpenViking memory profile across Codex, Claude Code, and OpenCode in the ~/.dotfiles repo. Use this whenever a project should get its own memory account, when an agent is recalling or capturing into the wrong OpenViking account, when memory recall is unexpectedly empty, when `viking://` reads return "nothing found", when adding a new repository to the dotfiles agent setup, or when someone asks why one agent has OpenViking and another does not. Also use before hand-editing ovcli-*.conf, openviking-claude.zsh, openviking-codex.zsh, or the opencode account wrapper — a partial edit routes hooks and MCP to different accounts and fails silently.
---

# OpenViking Project Profiles

A profile pins one repository tree to one OpenViking account, so work in that
repo recalls and captures against its own memory bank instead of the shared
`local-dev` one. Three agents consume the same profiles — Codex, Claude Code,
and OpenCode — and each reads the identity through a different mechanism.

That last point is the whole reason this skill exists. Wiring a profile touches
six files, and the failure mode for a partial job is silence: recall still
works, capture still works, and the memories land somewhere you didn't intend.
Nothing errors. Work the checklist rather than pattern-matching one file.

## How identity actually reaches each agent

| Agent | Mechanism | Reads |
| --- | --- | --- |
| Codex | plugin MCP + hooks | `OPENVIKING_CLI_CONFIG_FILE`, resolved to env by upstream's `ov-credentials.mjs` |
| Claude hooks | `scripts/config.mjs` | `OPENVIKING_CLI_CONFIG_FILE` → the conf file directly |
| Claude MCP | plugin `.mcp.json` headers | `OPENVIKING_ACCOUNT` / `OPENVIKING_USER` **env vars only** |
| OpenCode | plugin | `OPENVIKING_ACCOUNT` / `OPENVIKING_USER` / `OPENVIKING_AGENT_ID` env vars |

Claude is the one that bites: its hooks and its MCP server resolve identity
through *different* channels. Set the config file but not the env vars and the
hooks recall from the right account while the MCP tools read from an empty one.
`openviking-claude.zsh` sets both — keep it that way.

## Provisioning checklist

Every path below is relative to `~/.dotfiles`.

**1. Choose the account id.** Lowercase, matches the project. Existing ones:
`local-dev` (fallback), `xbol`, `iteramind-dev`. Accounts are created lazily on
first write — a brand-new account reads as empty, which is expected, not a bug.
Never migrate memory between accounts as a side effect; that is its own
explicitly requested job.

**2. Create `ai/openviking/ovcli-<project>.conf`.** Copy an existing one.
`account` and `agent_id` both take the account id. Add the repo's VCS metadata
dir to `ignore_dirs` — `ovcli-iteramind.conf` includes `.jj` because that repo
is jj-colocated.

**3. Link it in `ai/openviking/dot.yaml`** under `links:`:
`ovcli-<project>.conf: ~/.openviking/ovcli-<project>.conf`

**4. Add the branch to all three wrappers.** The two zsh helpers return a
*config path*; the OpenCode one returns an *account name*. Same `case`
structure, different return value — don't copy the wrong one.

- `ai/openviking/openviking-claude.zsh` → `_openviking_claude_cli_config`
- `ai/openviking/openviking-codex.zsh` → `_openviking_codex_cli_config`
- `ai/opencode/opencode.zsh` → `_openviking_opencode_account`

Each matches both the root and its descendants:

```zsh
"$_ov_<project>_root"| "$_ov_<project>_root"/*)
  print -r -- "$HOME/.openviking/ovcli-<project>.conf"
  ;;
```

If one project root nests inside another, put the more specific branch first —
`case` takes the first match.

**5. Add assertions to `ai/openviking/tests/openviking_codex_profile.test.zsh`.**
Nine per project: root / child / non-project for each of the three agents, plus
an identity assertion that the Claude account export agrees with the config
selection. That last one is what catches the hooks-vs-MCP divergence.

**6. Update the docs.** `ai/openviking/README.md` (profile list), and
`ai/agent-skills/okf-knowledge-ops/references/openviking.md` (the Profile Gate
table — agents consult it before using recall). If the project is an OKF
bundle, add its section to `okf-knowledge-ops/references/adapters.md` too.

## Verification

Run these in order. Steps 1–2 are cheap and catch most mistakes.

```sh
zsh ~/.dotfiles/ai/openviking/tests/openviking_codex_profile.test.zsh   # expect: ok
~/.rotz/bin/rotz install /ai/openviking                                  # create the symlink
exec zsh                                                                 # reload the wrappers
```

Then the account discriminator — the only check that proves the *live* path
rather than the config. Pick a memory that differs between accounts and read it
through the MCP tool, not the hooks:

```sh
cd <project-root>
claude -p "Call the OpenViking read tool on viking://user/<user>/memories/profile.md and reply with only the first line."
```

Run it again from a directory outside every project root. Different content
means routing works; identical content means the env export isn't reaching the
MCP headers. A brand-new account correctly returns "nothing found".

For Codex and OpenCode, start a fresh session in the project and confirm recall
cites that project's material.

## Traps

These are all observed failures, not hypotheticals.

**A running MCP connection does not switch accounts.** `cd` mid-session changes
nothing. Restart the agent after moving between projects.

**Launching Claude outside the wrapper sends empty account headers.** Desktop
launcher, IDE extension, a bare `command claude`, or another agent shelling out
— all bypass the zsh function. This degrades safely (the server resolves an
empty account, so reads return "nothing found") but looks like data loss. An
unexpectedly empty recall is the signature; check `env | grep OPENVIKING_`.

**Get MCP tool names from a live call, not from config.** Claude namespaces a
plugin's MCP tools using the plugin manifest's `name` field, which need not
match the marketplace entry name. The OpenViking plugin's marketplace entry is
`claude-code-memory-plugin` but its manifest name is `openviking-memory`, so the
tools are `mcp__plugin_openviking-memory_openviking__read`, not
`mcp__openviking__read`. A permission allowlist built from the config file is
silently inert. Ask a headless run what tool name it invoked.

**Hooks execute from the plugin cache, not the repo checkout.** `git pull` on
`~/.openviking/openviking-repo` updates the source; the hooks keep running
`~/.claude/plugins/cache/...` until `claude plugin update` succeeds. When
behavior disagrees with the source, check the installed version.

**Never edit `~/.openviking/openviking-repo`.** `dot.yaml` runs
`git pull --ff-only` against it; local changes are lost. Configuration belongs
in dotfiles.

**Don't allowlist mutating memory tools.** `remember`, `add_resource`, and
`cancel_watch` should prompt. `forget` is irreversible and must never be
allowlisted — Codex gates all of them with `approval_mode = "approve"`.

**Don't run the upstream `setup-helper/install.sh` on this machine.** It is
interactive, appends a marker block to `~/.zshrc` defining competing `claude()`
/ `codex()` functions, and offers to overwrite `statusLine`. `dot.yaml` runs the
equivalent non-interactive commands.

## Auditing an existing profile

When an agent recalls the wrong material, resolve identity from the outside in
rather than reading configs first:

1. `env | grep OPENVIKING_` in the agent's own shell — this is ground truth.
2. Compare against what the wrapper *should* produce for that directory by
   calling the helper directly:
   `_openviking_claude_cli_config <path>` and `_openviking_claude_identity <conf>`.
3. Read the resolved conf and confirm `account`.
4. Only then read the wrappers to find the missing branch.

A mismatch between steps 1 and 2 almost always means the session predates the
last wrapper change, or was launched outside the wrapper.
