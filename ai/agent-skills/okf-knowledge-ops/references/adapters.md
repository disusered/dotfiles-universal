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

## Unknown Bundle

Read local instructions and establish every adapter field. If authority,
writable scope, validation, or recall profile is missing, remain read-only and
report the missing contract. Do not guess a schema or maintenance command.
