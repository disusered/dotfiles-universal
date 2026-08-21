# Known OKF Consumers

These notes preserve consumer-owned authority around the generic one-Bundle
toolkit. They are not a Bundle registry. Prefer the user's explicit target and
current repository instructions over these workstation paths.

## Herding Cats Polychrome

- The selected local Bundle is authored Markdown under `polychrome/`; use that
  exact root with the JSON `okf` CLI.
- Read repository `AGENTS.md`, `polychrome.json`, and the relevant decisions,
  schemas, and runbooks. Authored Polychrome pages are curated source truth;
  indexes, visualizations, SQLite, and Portal views are projections.
- The shared toolkit owns generic parsing, validation, search, links, graph
  analysis, inspection, and visualization for the Polychrome Bundle.
  `polychromectl` remains the project CLI for federation and authority rules;
  Black, Red, and Marginalia; Zotero; Journal; publication; and temporary Brain
  Portal compatibility.
- Never target Black, Red, or Marginalia with an `okf change`. Process Black
  only on an explicit request and only through `polychrome-journal-ops`; never
  rewrite bytes in a Black Human Body.
- Links to other Polychrome Stores do not authorize cross-Bundle OKF traversal,
  graphing, or changes. Follow the owning Store's separate workflow.
- Zotero is the preferred external capture layer. Capture does not promote a
  Source or Connection into the curated Bundle.
- OpenViking uses the `local-dev` profile and remains contextual recall.
- Keep the repository-root `brain -> polychrome` compatibility symlink and
  installed `brainctl` until the Portal cutover is separately authorized. Do
  not invoke or recreate the retired Brain chatbot, Brain Web, Pi harness, or
  reference agent.
- After meaningful curated changes:
  1. `polychromectl log polychrome --message "<concise maintenance event>"`
  2. `polychromectl refresh polychrome`
  3. `polychromectl lint polychrome`
  4. `okf validate polychrome --strict`

Polychrome does not yet declare `.agents/okf.yaml` or an exact installed
`okf-cli` release. Until the coordinated consumer cutover records both, treat
local CLI availability as the release-installation seam described in
[transports.md](transports.md), not as permission to use a legacy validator.

## XBOL

- The selected local Bundle is authored Markdown under `docs/`; use that exact
  root with the JSON `okf` CLI. `docs/viz.html` is generated and ignored.
- Read repository `AGENTS.md`, `docs/schema/okf-profile.md`,
  `docs/schema/knowledge-operations.md`, and
  `docs/runbooks/maintain-okf-bundle.md`.
- Inspect code, migrations, immutable history, and verified runtime evidence
  when claims depend on current behavior. Preserve raw and bulk evidence under
  `artifacts/`; promote only provenance and durable conclusions into `docs/`.
- OpenViking uses the `xbol` profile and remains contextual recall.
- After authored changes, run every check in the maintenance runbook, then
  `okf validate docs --strict`.
- Do not add Polychrome stores, `polychromectl`, a custom general knowledge CLI,
  a local OKF MCP server, a reference agent, or a Brain/Pi harness to XBOL.

XBOL does not yet declare `.agents/okf.yaml` or an exact installed `okf-cli`
release. Apply the same release-installation stop condition as Polychrome.

## Iteramind Private

- The selected local Bundle is `private`, rooted at `knowledge/private/` in the
  Iteramind Control Repository. Its `.agents/okf.yaml` declares the root and
  instruction documents, so target the repository and pass `--bundle private`.
- Read repository `AGENTS.md`, `CONTEXT.md`, and the relevant private decision
  and runbook. The Bundle is Carlos-only; keep credentials, raw client data,
  and client-confidential material out of it.
- Do not start the historical local adapter host. Local access is through the
  JSON `okf` CLI only.
- OpenViking uses the `iteramind-dev` profile. Resource ingestion is a separate
  explicit request.
- During the consumer cutover, run the repository's documented private profile
  validation and tests after `okf validate`. The consumer-owned toolkit profile
  module and exact CLI release pin are not installed yet; report that seam and
  do not claim generic validation replaces the private profile.

## Iteramind Shared

- The selected hosted Bundle is `shared`. It is R2-backed and reached only
  through the deployment-provided `okf_v1_*` tools; there is no checkout to
  search and no local server to start.
- Call `okf_v1_context` with `bundle: "shared"` and follow the returned
  deployment instructions. The Shared Bundle accepts stable, reviewed,
  bot-safe company knowledge only.
- Never add credentials, personal context, private drafts, raw client data, or
  client-confidential material. Promotion from Private to Shared is an
  explicit, reviewed content change, not synchronization or cross-Bundle
  linking.
- Hosted apply remains gated by deployment identity policy and explicit user
  authorization after preview. On refusal, stop.

The current workstation skill distribution still includes older unversioned
shared-corpus and local-MCP artifacts. They are migration snapshots, not a
fallback for this skill. The hosted deployment is usable here only after its
connector exposes the documented `okf_v1_*` surface.

## Unknown Consumer

For a local Bundle, require an explicit root or project `.agents/okf.yaml`, the
consumer's applicable instructions, and an exact installed CLI pin. For a
hosted Bundle, require the deployment-documented Bundle name and `okf_v1_*`
tools. If authority, writable scope, validation, or post-write checks are
missing, remain read-only and report the missing contract.
