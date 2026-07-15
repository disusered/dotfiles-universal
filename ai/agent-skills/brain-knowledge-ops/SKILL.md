---
name: brain-knowledge-ops
description: Explore, investigate, query, collect, reference, organize, link, ingest, lint, and tidy Markdown knowledge graphs built with OKF and OpenViking. Use for natural-language questions about a Brain, evidence-backed wiki curation, graph maintenance, source promotion, broken-link or orphan audits, and OpenViking-assisted recall, especially in Herding Cats and XBOL.
---

# Brain Knowledge Operations

Treat a Brain as an authored OKF bundle plus an optional, profile-scoped
OpenViking retrieval layer. Preserve the authored bundle as durable knowledge;
use OpenViking to find context, never to overrule evidence.

## Resolve the Brain

1. Prefer a target path or alias stated by the user, then the repository that
   contains the current working directory.
2. Read the applicable `AGENTS.md` files before knowledge work.
3. Read [references/brains.md](references/brains.md) for the known adapter. For
   an unknown Brain, locate its index, OKF profile, authority rules, writable
   scope, and validation commands.
4. Explore an unknown Brain read-only. Refuse curation until those adapter
   fields are established.
5. Work in one Brain unless the user explicitly requests a cross-Brain query.

For a known adapter, read the exact listed paths instead of rescanning the
filesystem for instructions. Run direct, single-purpose read or search commands.
Do not append shell redirection, command substitution, status-printing probes,
or chained commands; report a real read failure directly.

## Apply the Authority Order

Use the target Brain's local authority rules. In their absence, prefer verified
primary evidence, then authored OKF, then archived or generated material, then
OpenViking and conversation. Report unresolved conflicts; do not silently pick
the convenient claim.

Never treat an index, visualization, search database, or OpenViking result as a
replacement for its authored source. Label `viking://` evidence as contextual.

## Explore and Investigate

1. Start at the bundle index and read its descriptions for progressive
   disclosure.
2. Search titles, descriptions, tags, and bodies with the adapter's query
   command and `rg`. Read the best candidates rather than returning search
   snippets as answers.
3. Traverse relevant Markdown links. Search for backlinks and unlinked mentions
   when the direct path is incomplete.
4. If OpenViking is available, follow
   [references/openviking.md](references/openviking.md). Use `find` for fast
   candidates, `search` for deeper retrieval, and `read` to expand selected
   URIs.
5. Verify recalled or archived claims against the applicable authority order.
6. Answer the natural-language question directly. Cite repository-relative
   Markdown paths for durable claims and identify conflicts, uncertainty, and
   missing knowledge.

Read [references/operations.md](references/operations.md) when investigating,
collecting, linking, or tidying rather than answering a focused query.

## Curate

Confirm that the active agent and sandbox permit writes. A read-only agent must
not escalate, delegate around its boundary, or mutate external systems.

For an explicit collect, ingest, or create request:

1. Preserve source identity and provenance before synthesis.
2. Verify durable claims against higher-authority evidence.
3. Create or update the smallest appropriate typed page.
4. Add descriptive links supported by the page content.
5. Record missing metadata as a gap instead of guessing.
6. Run every post-write command in the Brain adapter.

For an open-ended tidy request, apply only mechanical, unambiguous repairs:

- repair a broken relative link when exactly one intended target exists;
- restore an existing page to an index when local rules require it;
- normalize mechanically derivable frontmatter or Markdown formatting;
- format an already-established citation or provenance link; and
- refresh documented generated navigation or visualization output.

Pause and present a concrete proposal before renames, merges, deletions, bulk
moves, page-type changes, new semantic relationships, contradiction resolution,
or meaning-changing rewrites. An explicit user request for one of those changes
authorizes that exact scope, not adjacent cleanup.

## Finish

Run the adapter's validation commands. Report the answer or changes, durable
evidence paths, validation actually run, remaining conflicts or gaps, and any
OpenViking operation separately. Never claim an asynchronous OpenViking write
completed until retrieval verifies it.
