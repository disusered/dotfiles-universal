---
name: brain-portal
description: Operate and deploy the private Brain Portal, its MCP server, and the connected brain-agent Pi service. Use when a request asks to deploy Brain Portal or brain-agent; validate, publish, list, or roll back a sourced infographic, table, metric view, or chart; inspect portal health; or make a bounded update to a portal workspace such as purchase research, sources, watches, observations, components, or receipts.
---

# Brain Portal

Use the portal as a visual projection and bounded workspace host. Coding
harnesses operate it through typed documents and explicit commands; the portal
is not a chatbot, an agent runtime, or a general-purpose database interface.

## Locate and Orient

1. Use `${BRAIN_PORTAL_ROOT}` when set; otherwise use
   `~/Development/ME/herding-cats/projects/brain-portal`.
2. Read `AGENTS.md` and `CONTEXT.md` in that project before changing behavior.
3. Run `pnpm portalctl help` to verify the current command surface. Do not infer
   commands from this skill when the checked-out application differs.

## Publish an Artifact

1. Express the result as `portal.artifact.v1` JSON in a file or on stdin.
2. Keep the document declarative. Supported content is Markdown without raw
   HTML, metric grids, tables, and chart data; never embed JSX, JavaScript, SQL,
   or arbitrary HTML.
3. Include at least one meaningful source before setting `state` to
   `published`. A draft may be unsourced.
4. Validate before publication:

   ```sh
   pnpm portalctl artifact validate --file /path/to/artifact.json
   ```

5. Publish only when the user asked to publish or update the portal:

   ```sh
   pnpm portalctl artifact publish --file /path/to/artifact.json --actor codex
   ```

Publication creates an immutable revision and advances the explicit current
pointer. Use `artifact list` to inspect revisions and `artifact activate SLUG
REVISION` for an explicitly requested rollback. Never edit a stored revision.

## Operate a Workspace

Use only the bounded `purchase` commands shown by `pnpm portalctl help`. Pass
structured inputs through `--file` or `--stdin`, never as JSON shell arguments.
Store receipts through the receipt command so path and checksum validation are
applied.

Research actions, sources, watches, and observations record decision evidence.
They do not authorize a purchase, allocate money, or infer affordability.

## Preserve Authority Boundaries

- Do not write directly to the portal PostgreSQL database.
- Do not mutate hledger, YNAB, or authored OKF Markdown through the portal.
- Treat hledger as accounting authority, authored Markdown as Brain authority,
  and staged YNAB data as read-only evidence.
- Keep exact personal finance values and receipt contents out of Git, Brain
  pages, logs, and chat summaries unless explicitly requested.
- Use the separate `financial-planning` skill when a request changes confirmed
  financial actuals, quotes, or ledger funding evidence.

## Deploy Portal, MCP, and Pi Services

When asked to deploy Brain Portal, its MCP tools, or `brain-agent`:

1. Land and sign all commits on `main` (`projects/brain-portal` and/or
   `utilities/brain-agent` in Herding Cats). `scripts/deploy.sh` exports only
   committed `main`.
2. Run `./scripts/deploy.sh` from `projects/brain-portal` (outside the sandbox
   so it can reach `~/.config/brain-portal/env` and the systemd user bus). It
   exports the release, runs migrations and build, restarts
   `brain-portal.service` (`127.0.0.1:43110`) and
   `brain-portal-worker.service`, builds `@brain-portal/mcp` in the repository
   checkout, and restarts `brain-portal-mcp.service` (`127.0.0.1:1937`) and
   `brain-agent.service` (Pi Durable on `127.0.0.1:43140`).
3. If only `utilities/brain-agent` or `apps/mcp` changed without a full web
   release, build `apps/mcp` (`pnpm --filter @brain-portal/mcp build`) and
   restart both companion services together:

   ```sh
   systemctl --user restart brain-portal-mcp.service brain-agent.service
   ```

4. Deployment is complete when all four units report `active` and both health
   probes respond:

   ```sh
   systemctl --user is-active brain-portal.service brain-portal-worker.service brain-portal-mcp.service brain-agent.service
   curl -fsS http://127.0.0.1:43110/api/health
   curl -fsS http://127.0.0.1:43140/v1/health
   ```

## Verify

After a write, inspect the command's JSON result. For an operational check run:

```sh
pnpm portalctl health
```

Use the authenticated tailnet web surface only when visual verification is
needed. Do not bypass its Host or same-origin protections.
