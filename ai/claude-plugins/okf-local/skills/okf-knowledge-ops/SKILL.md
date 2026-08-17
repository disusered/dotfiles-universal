---
name: okf-knowledge-ops
description: Explore, investigate, query, collect, reference, organize, link, ingest, lint, and tidy governed Markdown knowledge graphs built with OKF and optional OpenViking recall. Prefer governed okf_* MCP tools when available, with repository CLI and filesystem fallbacks. Use for natural-language questions about an adapted knowledge bundle, evidence-backed wiki curation, graph maintenance, source promotion, broken-link or orphan audits, especially for Herding Cats Polychrome, Iteramind, and XBOL.
---

# OKF Knowledge Operations

Treat an adapted OKF bundle as authored durable knowledge plus optional,
profile-scoped OpenViking recall. Preserve authority boundaries; use recall to
find context, never to overrule evidence.

## Resolve the Adapter

1. Prefer a target path or alias stated by the user, then the repository that
   contains the current working directory.
2. Read all applicable `AGENTS.md` files.
3. Read [references/adapters.md](references/adapters.md) and select the exact
   known adapter. For an unknown bundle, locate its index, OKF profile,
   authority rules, writable scope, capture boundary, validation commands, and
   expected recall profile.
4. Explore an unknown bundle read-only until those fields are established.
5. Work in one governed bundle unless the user explicitly requests a
   cross-bundle query.

For a known adapter, read its named sources of truth instead of rescanning the
filesystem for instructions. Run direct, single-purpose reads and searches.

## Prefer the Governed MCP Surface

When `okf_context` and the other `okf_*` tools are available for the target
adapter:

1. If the bundle name is not already known, call `okf_list_bundles`; never guess
   a bundle name or ask the user before using the discovery tool.
2. Call `okf_context` for the selected bundle before substantive work.
3. Prefer `okf_list`, `okf_search`, `okf_read`, and `okf_links` to raw
   filesystem traversal. Keep every call inside one named bundle.
4. Use `okf_validate` for a read-only health check.
5. For one-file creates or updates, call `okf_preview_change`. Show the returned
   diff and proposal ID, then wait for explicit user authorization before
   calling `okf_apply_proposal`.
6. Do not bypass a failed preview, stale hash, expired proposal, rejected apply,
   post-write validator, or rollback by editing the governed file directly.

The MCP surface does not cover deletion, rename, bulk edit, promotion, commit,
publication, or OpenViking operations. Use the adapter's established local
workflow only when the MCP tools are absent or the authorized operation is
outside that surface. Never treat tool availability as write authorization.

## Apply Authority

Use the adapter's local order. In its absence, prefer verified primary evidence,
then accepted authored records, then archived or generated material, then
OpenViking and conversation. Report unresolved conflicts.

Never substitute an index, visualization, search database, projection, or
OpenViking result for its authored source. Label `viking://` material as
contextual.

## Explore

1. Start at the bundle index and use descriptions for progressive disclosure.
2. Search metadata and bodies with the adapter command and `rg`.
3. Read the best pages, traverse relevant links, then check backlinks and
   unlinked mentions.
4. If recall is relevant and the active profile matches, follow
   [references/openviking.md](references/openviking.md).
5. Verify recalled or archived claims against higher-authority evidence.
6. Answer directly with repository-relative citations, conflicts, uncertainty,
   and missing knowledge.

Read [references/operations.md](references/operations.md) before investigating,
collecting, linking, or tidying rather than answering a focused query.

## Curate

Confirm that the active role and sandbox permit writes. A read-only role must
not escalate or delegate around its boundary.

For an explicit collect, ingest, create, or content-change request:

1. Preserve source identity and provenance.
2. Verify durable claims against higher-authority evidence.
3. Create or update the smallest appropriate typed page. When governed MCP
   write tools are available, use their preview/apply protocol.
4. Add only descriptive links supported by the page content.
5. Record missing metadata as a gap.
6. Run every post-write command in the adapter.

For an open-ended tidy request, apply only unambiguous mechanical repairs:

- repair a relative link when exactly one intended target exists;
- restore an existing page to an index when local policy requires it;
- normalize mechanically derivable frontmatter or Markdown formatting;
- format an established citation or provenance link; and
- refresh documented generated navigation or visualization.

Pause before a rename, merge, deletion, bulk move, page-type change, new
semantic relationship, contradiction resolution, or meaning-changing rewrite
unless the user explicitly authorized that exact operation.

## Finish

Run the adapter's validation commands. Report durable evidence paths, checks
actually run, unresolved conflicts or gaps, and OpenViking operations
separately. Never claim an asynchronous memory write completed until retrieval
verifies it.
