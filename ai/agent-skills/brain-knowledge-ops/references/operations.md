# Knowledge Operations

## Model

Keep three layers distinct:

1. Primary or immutable sources preserve raw evidence.
2. The authored OKF wiki holds curated, durable knowledge.
3. Schema and runbooks tell agents how to ingest, query, and lint it.

This follows the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
OKF 0.1 is a directory of Markdown pages with YAML frontmatter; ordinary
Markdown links form graph edges and their surrounding prose supplies semantics.
Follow the target bundle's stricter profile when it has one. See the
[OKF draft specification](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md).

## Operation Contract

| Operation | Result |
| --- | --- |
| Explore | Answer a natural-language question from the graph with grounded citations. |
| Investigate | Compare claims, sources, history, and memory; expose conflicts and gaps. |
| Collect | Preserve source identity and provenance without dumping raw material into the wiki. |
| Curate | Promote verified durable knowledge into the smallest suitable typed page. |
| Organize | Improve indexes and supported links while preserving page identity. |
| Tidy | Audit structure and meaning; apply only unambiguous mechanical repairs. |

## Query Heuristics

- Begin at `index.md`; use descriptions as progressive disclosure.
- Prefer standard relative Markdown links for portability, including in
  Obsidian. See [Obsidian internal links](https://github.com/obsidianmd/obsidian-help/blob/master/en/Linking%20notes%20and%20files/Internal%20links.md).
- Follow outgoing links, then find backlinks and unlinked mentions. Backlinks
  often reveal missing graph edges. See [Obsidian backlinks](https://obsidian.md/help/Plugins/Backlinks).
- Use the local graph to identify orphans and hubs, not as evidence by itself.
  See [Obsidian graph view](https://obsidian.md/help/Plugins/Graph%2Bview).
- Cite the authored page and, when material, its primary source. Do not cite a
  generated index, visualization, or search result in place of the page.

## Tidy Audit

Check mechanical structure first:

- required frontmatter under the local OKF profile;
- broken or ambiguous relative links;
- index coverage and stale generated navigation;
- orphan pages and unusually disconnected concepts;
- citation and provenance formatting; and
- generated files accidentally treated as authored nodes.

Then inspect semantics with the LLM:

- contradictory or superseded claims;
- stale verification dates or unverified current-state assertions;
- duplicate pages with the same concept identity;
- important concepts mentioned repeatedly but lacking a page;
- pages that should cross-reference each other; and
- claims whose supporting source is missing or lower-authority.

Record semantic findings as proposals unless the user's request explicitly
authorizes the exact content change. Broken links and incomplete metadata are
valid conditions under baseline OKF, so apply the target Brain's profile rather
than inventing universal strictness.

## Source Promotion

Preserve the original source or stable resource reference. Record title,
creator, date, URI or path, revision or checksum when available, capture
context, and any missing fields. Synthesize durable claims into existing typed
pages when concept identity matches; otherwise create the locally prescribed
page type. Never turn a transcript, document dump, or entire artifact tree into
the authored wiki merely for retrieval convenience.
