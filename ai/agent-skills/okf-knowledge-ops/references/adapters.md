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
- A surface with no filesystem reaches this Bundle through the repository's
  own stdio server, `okf-cats` in its checked-in `.mcp.json`. It serves
  `polychrome` and nothing else, so it is no route to Black, Red, or
  Marginalia.
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
- `.agents/okf.yaml` declares exactly one `polychrome` Bundle. Install the
  exact CLI pin with
  `npm --prefix utilities/polychrome ci --ignore-scripts`. The Rotz-managed
  `okf` wrapper and `polychromectl` both resolve that same installation.

## XBOL

- The selected local Bundle is authored Markdown under `docs/`; use that exact
  root with the JSON `okf` CLI. `docs/viz.html` is generated and ignored.
- Read repository `AGENTS.md`, `docs/schema/okf-profile.md`,
  `docs/schema/knowledge-operations.md`, and
  `docs/runbooks/maintain-okf-bundle.md`.
- Inspect code, migrations, immutable history, and verified runtime evidence
  when claims depend on current behavior. Preserve raw and bulk evidence under
  `artifacts/`; promote only provenance and durable conclusions into `docs/`.
- A surface with no filesystem reaches this Bundle through the repository's
  own stdio server, `okf-xbol` in its checked-in `.mcp.json`.
- OpenViking uses the `xbol` profile and remains contextual recall.
- After authored changes, run every check in the maintenance runbook. The
  validation among them is `pnpm okf:validate`, which runs
  `okf validate . --bundle xbol --strict --json` and passes no profile module.
- Do not add Polychrome stores, `polychromectl`, a custom general knowledge CLI,
  an OKF MCP server other than the declared `okf-xbol`, a reference agent, or a
  Brain/Pi harness to XBOL.
- `.agents/okf.yaml` declares exactly one `xbol` Bundle. Run
  `pnpm install --frozen-lockfile`; the root scripts use the exact CLI pin.

## Iteramind Shared

- The selected hosted Bundle is `shared`. It is R2-backed and reached only
  through the deployment-provided `okf_v1_*` tools; there is no checkout to
  search and no local server to start.
- Call `okf_v1_context` with `bundle: "shared"` and follow the returned
  deployment instructions. The shared Bundle accepts team-safe company Concepts, including drafts.
  Stable Concepts require the profile's human review evidence.
- Never add credentials, personal context, private drafts, raw client data, or
  client-confidential material. Iteramind has no local or private Bundle. Do not revive one from old recall.
- Hosted apply remains gated by deployment identity policy and explicit user
  authorization after preview. On refusal, stop.

The deployment cutover is done. The claude.ai `OpenKnowledge` connector exposes
the ten documented `okf_v1_*` tools and requires `bundle` on every one of them,
and no unversioned `okf_*` artifact is left in the workstation skill
distribution. The connector is the only door to the Shared Bundle; a local
stdio server is a different thing and never serves it.

The `okf-shared-bundle` skill owns the Shared Bundle's authority and content
policy, and includes its hosted change procedure. Keep these adapter notes consistent
with that skill.

## Unknown Consumer

For a local Bundle, require an explicit root or project `.agents/okf.yaml`, the
consumer's applicable instructions, and an exact installed CLI pin. For a
hosted Bundle, require the deployment-documented Bundle name and `okf_v1_*`
tools. If authority, writable scope, validation, or post-write checks are
missing, remain read-only and report the missing contract.
