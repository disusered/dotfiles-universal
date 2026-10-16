---
name: xbol-knowledge-ops
description: Answer questions from, and curate, the XBOL knowledge Bundle for the XBOL ticketing and cashless platforms, through the xbol-knowledge connector or the docs/ folder. Use for XBOL decisions, requirements, domain language, operations, initiatives, and release history, and for recording new XBOL knowledge. Pair with okf-knowledge-ops for the generic OKF mechanics.
---

# XBOL Knowledge

The `xbol` Bundle is evidence-backed engineering knowledge for the XBOL
platforms. It is authored Markdown under `~/Development/XBOL/docs/`. With file
tools, read it there and use `pnpm okf:*` from the XBOL root. Without them, use
the `xbol-knowledge` connector, which serves the same files. Follow
`okf-knowledge-ops` for the generic OKF operations.

## Start

1. Call `okf_v1_context` with `bundle: "xbol"`, or read `docs/index.md`.
2. Read `docs/concepts/ubiquitous-language.md` before naming anything.
3. Follow the collection indexes (`decisions/`, `requirements/`, `concepts/`,
   `runbooks/`, `initiatives/`, `releases/`, `sources/`). Read archived sprint
   notes only when the indexes point there.

## Authority

When sources disagree, `docs/schema/knowledge-operations.md` decides. In short:
current code, migrations and immutable history first; then pull-request and
runtime evidence; then curated pages; then archived material; memory last. A
lower source can tell you where to look but never overrides a higher one.
Record an unresolved contradiction instead of picking the convenient side.

## Change

- Change the smallest page that holds the claim. Add supersession links when a
  newer decision replaces an older one; never rewrite an accepted decision.
- Keep raw and bulk evidence under `~/Development/XBOL/artifacts/`. Promote only
  provenance and durable conclusions into `docs/`.
- Attribute `generated.by` and `verified[].by` as `<producer>/<version>`,
  `human:<id>`, or `process:<id>`.
- Through the connector: `okf_v1_preview_change`, show the whole preview, then
  `okf_v1_apply_change` with the same change and `preview_id` once the user
  approves. With files: edit, then run `pnpm okf:validate` (strict) from the
  XBOL root; it must report zero errors and zero warnings.
- Never put credentials, personal data, or another client's material in the
  Bundle. Never read, link, or change another Bundle from here.

## Workspace

- Read `AGENTS.md`, `docs/schema/okf-profile.md`,
  `docs/schema/knowledge-operations.md` and
  `docs/runbooks/maintain-okf-bundle.md` before changing the Bundle; run every
  check in that runbook afterwards. `docs/viz.html` is generated and ignored.
- `.agents/okf.yaml` declares exactly one `xbol` Bundle. Run
  `pnpm install --frozen-lockfile`; the root scripts use the exact CLI pin.
- OpenViking recall uses the `xbol` account (`~/.openviking/ovcli-xbol.conf`)
  and stays contextual.
- Do not add Polychrome stores, `polychromectl`, a custom general knowledge
  CLI, or an OKF MCP server other than `xbol-knowledge` to XBOL.
