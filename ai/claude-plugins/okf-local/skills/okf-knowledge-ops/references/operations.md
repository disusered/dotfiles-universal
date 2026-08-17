# Knowledge Operations

## Layers

Keep these layers distinct:

1. Primary or immutable sources preserve raw evidence.
2. Authored records hold curated, durable knowledge.
3. Schema and runbooks govern ingest, query, and validation.
4. Generated indexes and projections are rebuildable views.

## Operation Contract

| Operation | Result |
| --- | --- |
| Explore | Answer from the graph with grounded citations. |
| Investigate | Compare claims, sources, history, and recall; expose conflicts and gaps. |
| Collect | Preserve source identity and provenance without dumping raw material into the wiki. |
| Curate | Promote verified durable knowledge into the smallest suitable typed page. |
| Organize | Improve indexes and supported links while preserving identity. |
| Tidy | Audit structure and meaning; apply only unambiguous mechanical repairs. |

## Query

- Begin at `index.md`; use descriptions for progressive disclosure.
- Prefer portable relative Markdown links.
- Follow outgoing links, then inspect backlinks and unlinked mentions.
- Use a graph only to identify candidates, never as evidence by itself.
- Cite authored pages and material primary sources, not generated navigation.

## Audit

Check mechanical structure first:

- local required frontmatter;
- broken or ambiguous relative links;
- index coverage and generated-navigation freshness;
- orphan pages and unusually disconnected concepts;
- citation and provenance formatting; and
- generated files accidentally treated as authored records.

Then inspect semantics:

- contradictory or superseded claims;
- stale verification dates;
- duplicate concept identities;
- repeatedly mentioned concepts without pages;
- supported missing cross-references; and
- claims whose source is missing or lower-authority.

Record semantic findings as proposals unless the request authorizes the exact
content change.

## Source Promotion

Preserve the source or stable reference. Record title, creator, date, URI or
path, revision or checksum, capture context, and missing fields when available.
Synthesize durable claims into the locally prescribed page type. Do not ingest
a transcript, document dump, or artifact tree into an authored wiki merely for
retrieval convenience.

## Zotero Intake

When the selected adapter provides `polychromectl zotero`, do not treat a move
from Inbox to Reading List as processing or reading. For PDF attachments:

1. Run `zotero prepare-pdf` into an exact private temporary directory.
2. Inspect the prepared Markdown and distinguish full extraction from actual
   review coverage.
3. Run `zotero enrich` with an evidenced title and a small additive subject-tag
   set; preserve existing tags and complete Zotero full text.
4. Verify through `zotero show` and attachment-inclusive `zotero search`.
5. Curate durable synthesis selectively, then move a successfully enriched
   Inbox item to Reading List.

Leave failures in Inbox. Report extraction, indexing, review, and curation as
separate states. Never copy prepared full text into the authored OKF corpus for
retrieval convenience.
