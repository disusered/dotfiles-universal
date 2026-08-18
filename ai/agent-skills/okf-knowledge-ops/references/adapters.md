# Knowledge Bundle Adapters

An adapter establishes aliases, repository root, OKF root and index, authority
documents, writable scope, query command, capture boundary, post-write checks,
and expected OpenViking profile.

## Herding Cats Polychrome

- Aliases: `Polychrome`, `Herding Cats`, `herding-cats`, `HC`.
- Repository: `/home/carlos/Development/ME/herding-cats`.
- Federation manifest: `polychrome.json`.
- Curated OKF root and index: `polychrome/` and `polychrome/index.md`.
- Authority: repository `AGENTS.md`,
  `polychrome/decisions/0021-polychrome-architecture-migration.md`,
  `polychrome/decisions/0017-detach-brain-from-pi-harness.md`, and relevant
  pages under `polychrome/schema/` and `polychrome/decisions/`.
- Writable scope: the exact store and record class authorized by the request.
  The curated corpus, Black, Red, and Marginalia have distinct authority.
- Query: `polychromectl search polychrome "<query>"`, then `rg` and direct
  reads.
- Capture: Zotero is the preferred external capture layer. Inspect before
  promotion and use existing `polychromectl zotero` adapters. Prepare and
  enrich PDF attachments before Reading List triage; a collection move does
  not establish extraction, review, or curation.
- Journal: use `polychrome-journal-ops` only after an explicit request to
  process Black.
- OpenViking: `local-dev` via `~/.openviking/ovcli.conf`.
- Operator boundary: ordinary coding harnesses invoke shared skills and
  deterministic commands. Do not create a project-owned chatbot or harness.
- Compatibility: keep `brain -> polychrome` and installed `brainctl` for Brain
  Portal until a separately authorized cutover.
- After curated changes:
  1. `polychromectl log polychrome --message "<concise maintenance event>"`
  2. `polychromectl refresh polychrome`
  3. `polychromectl lint polychrome`

## XBOL

- Aliases: `XBOL`, `xbol`.
- Repository: `/home/carlos/Development/XBOL`.
- OKF root and index: `docs/` and `docs/index.md`.
- Authority: repository `AGENTS.md`, `docs/schema/okf-profile.md`,
  `docs/schema/knowledge-operations.md`, and
  `docs/runbooks/maintain-okf-bundle.md`.
- Writable scope: authored Markdown under `docs/`; `docs/viz.html` is generated
  and ignored.
- Query: follow collection indexes, use `rg`, then inspect cited code,
  migrations, immutable commits, pull-request evidence, or verified runtime
  evidence when a claim depends on current behavior.
- Capture: preserve raw and bulk evidence under `artifacts/`; promote only
  provenance and durable conclusions into `docs/`.
- OpenViking: `xbol` via `~/.openviking/ovcli-xbol.conf`. Resource ingestion is
  a separate explicit request.
- After authored changes, run every check in
  `docs/runbooks/maintain-okf-bundle.md`.

Do not add Polychrome stores, `polychromectl`, or a custom knowledge CLI to
XBOL.

## Iteramind

- Aliases: `Iteramind`, `ITERAMIND`.
- Repository: `/home/carlos/Development/ITERAMIND`.
- Private OKF root and index: `knowledge/private/` and
  `knowledge/private/index.md`.
- Shared OKF corpus: Markdown objects in the `iteramind-okf` R2 bucket, under the
  `shared/` key prefix with `shared/index.md` as its index. Reached only through
  the hosted server; it is in no repository.
- Authority: repository `AGENTS.md`, `CONTEXT.md`, and the relevant decision
  and runbook in the selected bundle.
- Writable scope: one exact bundle per operation. The private bundle is
  Carlos-only; the shared bundle accepts stable, reviewed, bot-safe knowledge
  only. Promotion is an explicit content change, never a synchronization job.
- Reaching each bundle differs, and this is the point rather than an accident:
  - Private: files in the working repository. There is no server. Read the index,
    search with `rg`, and edit with ordinary file tools. In Claude Desktop this
    requires the repository folder to be shared with Cowork.
  - Shared: the hosted server `okf-shared` at `https://okf.iteramind.dev/mcp`,
    behind Cloudflare Access. Call `okf_context` for the `shared` bundle and use
    the bounded reads, search, and links. Its save tool is `okf_apply_change`,
    which resends the content and the `sha` from `okf_read`; there is no
    proposal to expire. Any bundle name other than `shared` is refused.
  - There is no local copy of the shared corpus anywhere. `knowledge/shared/` and
    `iteramind/okf-shared`'s `shared/` were both removed once the bucket became
    the store. `iteramind/okf-shared` now holds only `scripts/validate_okf.py`,
    which is the reference for the profile the server enforces in TypeScript.
- Capture: keep client-specific context in its Project Repository. Treat
  Polychrome and XBOL as read-through references and do not copy their memories
  into Iteramind.
- OpenViking: `iteramind-dev` via
  `~/.openviking/ovcli-iteramind.conf`. Resource ingestion remains a separate
  explicit request.
- After authored private changes, from the repository root:
  1. `uv run python scripts/validate_okf.py knowledge/private`
  2. `uv run python -m unittest discover -s tests`

  The shared corpus is validated by its own repository's CI, not from here.

Nothing runs a local OKF server for this repository. `.agents/okf.yaml` remains
as an adapter manifest, but no harness loads it, so the validator above is the
whole of private-corpus governance: run it before proposing a change and again
after writing. The hosted shared server runs its own checks and reports command
receipts; do not rerun those merely for duplication.

The Shared Bot consumes only `knowledge/shared/` and separate bot memory. It
must never receive the Control Repository checkout or Carlos's development
memory.

## Unknown Bundle

Read local instructions and establish every adapter field. If authority,
writable scope, validation, or recall profile is missing, remain read-only and
report the missing contract. Do not guess a schema or maintenance command.
