---
name: okf-knowledge-ops
description: Explore and curate exactly one governed OKF v0.2 Bundle, reached with the versioned JSON `okf` CLI, the repository's own stdio `okf_v1_*` MCP server, or a hosted deployment's `okf_v1_*` tools. Use for grounded questions, validation, source promotion, link and graph audits, and authorized knowledge changes in Polychrome, XBOL, or Iteramind. Do not use for Polychrome Black processing.
---

# OKF Knowledge Operations

Treat authored OKF Markdown as durable knowledge. Preserve the selected
Bundle's authority and use generated views or optional OpenViking recall only
to find candidates, never as source truth.

## Select One Bundle

1. Prefer the exact Bundle named by the user. Otherwise use the sole Bundle
   declared for the current project or deployment. If more than one is
   available, stop for a selection; never infer one from a link or search
   result.
2. Read applicable `AGENTS.md` files, then read
   [references/adapters.md](references/adapters.md) for known consumer
   boundaries.
3. Establish the Bundle's authority, writable scope, capture boundary,
   validation, and post-write commands before changing it. Remain read-only if
   any required write contract is missing.
4. Hold that selection fixed for the operation. Do not traverse, search, link,
   graph, or mutate across Bundles. Do not consult or create a vault registry.

For an unknown target, use only an explicit local root or project
`.agents/okf.yaml`, or the single Bundle documented by a hosted deployment.
There is no Bundle-discovery tool in the v1 interface.

## Choose the Transport

Transport follows the harness, not the Bundle. A local Bundle is reachable both
ways, and both reach the same files under the same profile.

- **With file tools:** read the Markdown and use the versioned JSON `okf` CLI
  for Bundle context, reads, search, links, inspection, validation,
  visualization, and changes. Validate with the consumer's own script. This is
  the normal path; do not start a server to reach a checkout you can already
  see.
- **With no filesystem:** use the repository's own stdio server,
  `@disusered/okf-mcp`, one per repository, serving exactly one local Bundle off
  disk. It exposes the same ten `okf_v1_*` tools a hosted deployment does. Each
  repository declares its server in a checked-in `.mcp.json`, so a clone arrives
  configured. Claude Desktop has no project scope, so its three servers live in
  `~/.config/Claude/claude_desktop_config.json`; Codex reads a project-local
  `.codex/config.toml`. The names are `okf-xbol`, `okf-cats`, and
  `okf-iteramind`, and only Iteramind's is started with a `--profile-module`.
- **Hosted Bundle:** use only the deployment-supplied `okf_v1_*` tools. Do not
  look for its files or fall back to unversioned `okf_*` tools.

The Iteramind Shared Corpus is the one hosted deployment here. It is R2 objects
behind Cloudflare Access, reached through the claude.ai `OpenKnowledge`
connector, and the `okf-shared-corpus` skill owns it. Do not reach for it from
this one.

Read [references/transports.md](references/transports.md) before invoking a
transport. It records the verified command and tool shapes, reviewed change
contract, and unresolved release-installation seams.

## Explore

1. Load Bundle context and its index through the selected transport.
2. Search, read the strongest pages, and inspect their links and backlinks.
3. Follow primary evidence when a claim depends on current facts. Apply the
   consumer's authority order and expose conflicts instead of silently choosing.
4. If recall is relevant, follow
   [references/openviking.md](references/openviking.md) without expanding the
   operation to another Bundle.
5. Answer with Bundle-relative page citations, material external sources,
   uncertainties, and gaps.

Read [references/operations.md](references/operations.md) before investigating,
collecting, curating, organizing, or tidying rather than answering a focused
question.

## Curate

Require an explicit content-change request and verify that the active role may
write the selected Bundle. Preserve provenance, change the smallest suitable
typed page, and add only relationships supported by its content.

Use the transport's `okf.operations.v1` lifecycle: obtain the current opaque
revision when required, preview the complete Change, inspect its diff and
diagnostics, then apply the same Change with the reviewed `preview_id`. A hosted
apply always requires the user's explicit authorization after preview. Stop on
a failed preview, refused authorization, preview mismatch, stale revision,
validation failure, or rejected apply; never bypass it through another
transport or direct storage access. Read current state and produce a new
preview before retrying a mismatched or stale Change.

For an open-ended tidy request, apply only unambiguous mechanical repairs.
Pause before a rename, merge, deletion, bulk move, page-type change, new
semantic relationship, contradiction resolution, or meaning-changing rewrite
unless the request explicitly authorizes it.

## Finish

Validate through the selected transport and run every consumer-owned post-write
check. Report pages and sources used, changes applied, checks actually run,
unresolved gaps, and OpenViking activity separately.
