---
name: okf-knowledge-ops
description: Explore, investigate, query, collect, reference, organize, link, ingest, lint, and tidy governed OKF Markdown bundles that live as files in a repository, with optional OpenViking recall. Use for natural-language questions about an adapted knowledge bundle, evidence-backed wiki curation, graph maintenance, source promotion, broken-link or orphan audits, in Herding Cats Polychrome, XBOL, and Iteramind's local corpus. A corpus reached through a hosted MCP connector is covered by its own skill instead.
---

# OKF Knowledge Operations

Treat an adapted OKF bundle as authored durable knowledge plus optional,
profile-scoped OpenViking recall. Preserve authority boundaries; use recall to
find context, never to overrule evidence.

OKF v0.2 is specified at `~/.local/share/okf/reference/SPEC.md`. That file is the
normative reference. Read it before authoring a new page type, changing
frontmatter conventions, or judging whether a page conforms; do not work from
memory of the format. A bundle conforms when every non-reserved Markdown file
has parseable YAML frontmatter carrying a non-empty `type` (§11). Everything
else the spec describes is guidance, so never reject a bundle over it.

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

## This Skill Covers File-Based Bundles

Every adapter here is read and written as files in a repository, with the
adapter's own command and `rg`. None of them has a server, and none needs one:
a server exists to reach files a surface cannot open for itself.

A corpus reached only through a hosted MCP connector is a different thing with
its own instructions. Iteramind's shared corpus is the current example, covered
by the `okf-shared-corpus` skill. Do not go looking for its files, and do not
assume `okf_*` tools apply to the bundles here.

Governance for the bundles here is the adapter's validator and post-write
checks. Run them before proposing a change and again after writing, and report
what they said.

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

Run the adapter's validation commands and the shared conformance checker:

```bash
uv run ~/.local/share/okf/bin/okf_validate.py <bundle>
```

The two cover different ground and neither replaces the other. An adapter's
validator enforces that bundle's domain rules — its type schema, its link
conventions, its derived index. The shared checker enforces the specification,
including the trust, lifecycle, provenance, and actor-convention rules no
adapter checks today. Only its `ERROR` lines block; warnings are soft guidance,
so fix them when cheap and report the rest.

Report durable evidence paths, checks actually run, unresolved conflicts or
gaps, and OpenViking operations separately. Never claim an asynchronous memory
write completed until retrieval verifies it.
