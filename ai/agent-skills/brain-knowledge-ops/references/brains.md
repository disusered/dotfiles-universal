# Brain Adapters

An adapter establishes these fields before curation: aliases, repository root,
OKF root, entrypoint, authority documents, writable scope, query commands,
capture boundary, post-write validation, and expected OpenViking profile.

## Herding Cats

- Aliases: `Herding Cats`, `herding-cats`, `HC`.
- Repository: `/home/carlos/Development/ME/herding-cats`.
- OKF root and entrypoint: `brain/` and `brain/index.md`.
- Authority: read repository `AGENTS.md`,
  `brain/decisions/0017-detach-brain-from-pi-harness.md`, and relevant pages
  under `brain/schema/` and `brain/decisions/`.
- Writable scope: authored Markdown under `brain/`, plus documented generated
  Brain projections during refresh.
- Query: `brainctl search brain "<query>"`, then `rg` and direct reads.
- Capture: Zotero is the preferred capture layer. Inspect before promotion and
  do not reorganize it unless explicitly requested. Use the existing
  `brainctl zotero` commands; do not duplicate that adapter globally.
- OpenViking profile: `local-dev` via `~/.openviking/ovcli.conf`.
- Operator boundary: Codex, Claude, and OpenCode invoke `brainctl` and this skill
  directly. Do not recreate a Brain chatbot, Pi harness, or Brain Web.
- After an authored change:
  1. `brainctl log brain --message "<concise maintenance event>"`
  2. `brainctl refresh brain`
  3. `brainctl lint brain`

The Herding Cats `brainctl` schema and chronological log are local policy, not
universal OKF requirements.

## XBOL

- Aliases: `XBOL`, `xbol`.
- Repository: `/home/carlos/Development/XBOL`.
- OKF root and entrypoint: `docs/` and `docs/index.md`.
- Authority: read repository `AGENTS.md`, `docs/schema/okf-profile.md`,
  `docs/schema/knowledge-operations.md`, and
  `docs/runbooks/maintain-okf-bundle.md`.
- Writable scope: authored Markdown under `docs/`; `docs/viz.html` is generated
  and ignored.
- Query: follow collection indexes, use `rg`, then inspect cited code, migrations,
  immutable commits, `odasoft/*` pull-request evidence, or verified runtime
  evidence when a claim depends on current behavior.
- Capture: preserve raw and bulk evidence under `artifacts/`; promote only
  provenance and durable conclusions into `docs/`.
- OpenViking profile: `xbol` via `~/.openviking/ovcli-xbol.conf`. Do not add or
  reconfigure project-local OpenViking. Perform resource ingestion only as a
  separate, explicit OpenViking request, never as routine wiki maintenance.
- After an authored change:
  1. `git diff --check`
  2. `rg -n '/tmp/|worktrees/|containment-build' docs --glob '*.md'`
  3. Review matches under the runbook's transient-path rules.
  4. `reference-agent visualize --bundle docs --out docs/viz.html --name XBOL`
  5. Verify one node per non-index Markdown page, no `Unknown` types, and the
     expected supersession and related-concept edges.

Do not add `brain/`, `brainctl`, or a custom knowledge CLI to XBOL.

## Unknown Brain

Read local instructions and discover the adapter fields. If any authority,
writable-scope, validation, or OpenViking-profile field is missing, continue
read-only and report the missing contract. Do not guess a maintenance command,
page schema, or memory account.
