---
name: polychrome-knowledge-ops
description: Answer questions from, and curate, Carlos's Polychrome knowledge Bundle in Herding Cats, through the brain-portal connector or the polychrome/ folder. Use for Polychrome decisions, concepts, runbooks, schema notes and sources, and for recording durable knowledge from Herding Cats and Brain Portal work. Pair with okf-knowledge-ops for the generic OKF mechanics. Do not use for Black processing (polychrome-journal-ops).
---

# Polychrome Knowledge

The `polychrome` Bundle is authored Markdown under
`~/Development/ME/herding-cats/polychrome/`. With file tools, read it there and
use the JSON `okf` CLI on that exact root. Without them, use the `brain-portal`
connector, whose `okf_v1_*` tools serve `polychrome` and nothing else. Follow
`okf-knowledge-ops` for the generic OKF operations.

## Start

1. Call `okf_v1_context` with `bundle: "polychrome"`, or read
   `polychrome/index.md`.
2. Read the repository `AGENTS.md`, `polychrome.json`, and the relevant
   decisions, schemas and runbooks.

## Authority

- Authored Polychrome pages are curated source truth. `index.md`, `viz.html`,
  SQLite indexes and Portal views are projections.
- The OKF Toolkit owns generic parsing, validation, search, links, graph
  analysis, inspection and visualization. `polychromectl` owns federation and
  authority rules; Black, Red and Marginalia; Journal; publication; and
  temporary Brain Portal compatibility.
- Black, Red and Marginalia are separate Stores. Never target them with an OKF
  change; links to them do not authorize cross-Bundle traversal, graphing or
  changes. Process Black only on an explicit request and only through
  `polychrome-journal-ops`; never rewrite bytes in a Black human body.
- Karakeep owns saved external sources and highlights. Use
  `karakeep-polychrome` to retrieve them and for cited synthesis. Capture goes
  through the extension, share or upload workflow, or CLI work documented in
  `~/.dotfiles/tools/karakeep/AGENT-USAGE.md`; capture does not promote a Source
  or Connection into the Bundle.
- OpenViking recall uses the `local-dev` account (`~/.openviking/ovcli.conf`)
  and stays contextual.
- Keep the repository-root `brain -> polychrome` compatibility symlink and the
  installed `brainctl` until the Portal cutover is separately authorized.

## Change

- Through the connector: `okf_v1_preview_change`, show the whole preview, then
  `okf_v1_apply_change` with the same change and `preview_id` once Carlos
  approves. An applied change runs the maintenance below and reports it as
  `maintenance.status`.
- With files, after meaningful curated changes run, from the repository root:
  1. `polychromectl log polychrome --message "<concise maintenance event>"`
  2. `polychromectl refresh polychrome`
  3. `polychromectl lint polychrome`
  4. `okf validate polychrome --strict`
- `.agents/okf.yaml` declares exactly one `polychrome` Bundle. Install the exact
  CLI pin with `npm --prefix utilities/polychrome ci --ignore-scripts`; the
  Rotz-managed `okf` wrapper and `polychromectl` both resolve it.
