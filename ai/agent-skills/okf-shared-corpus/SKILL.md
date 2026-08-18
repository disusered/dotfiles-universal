---
name: okf-shared-corpus
description: Read and curate the Iteramind shared knowledge corpus through the hosted okf_* tools. Use when asked what the company has decided or documented, to look something up in team knowledge, or to add or correct a page in it. Covers authority order, what makes a page valid, how a change is saved, and what to do when a save is refused.
---

# Iteramind shared knowledge

The shared corpus is the company's reviewed knowledge: decisions, policies, runbooks, and
concepts that anyone on the team may read. It is reached only through the hosted `okf_*` tools
on this connector. There is no checkout of it and no file on disk to open.

It is one bundle, named `shared`. Any other bundle name is refused, and that refusal is
correct rather than a misconfiguration — this connector serves exactly one corpus.

## Start with context

Call `okf_context` for the `shared` bundle before substantive work. It returns the instruction
documents and the index, which together say what is authoritative. Skipping it means guessing
at rules that are written down.

The index is the entry point. Its descriptions exist so you can find the right page without
reading every page, so read it before searching.

## Reading

- `okf_list` shows the pages and the folders they sit in.
- `okf_search` ranks whole pages against a natural-language question. It is not a literal
  text match, so ask the question in your own words rather than guessing keywords.
- `okf_read` returns one page and an `etag`. Keep that etag if you might edit the page.
- `okf_links` shows what a page points to and what points back at it. Use it to find related
  material the index does not surface, and to see whether a page is orphaned.
- `okf_visualize` returns a URL for a rendered graph of the corpus. It is a generated view,
  regenerated from the pages; never treat it as the source, and never edit it.

## Authority

Authored pages are the authority. An index entry, a search snippet, a graph, or a summary is a
view of a page, never a substitute for it. When something matters, open the page and cite its
path.

Prefer verified evidence and the corpus over recollection. If the corpus contradicts what you
believe, the corpus is what the company decided; report the conflict rather than quietly
resolving it.

## Writing

Confirm the person actually asked for a content change. Reading is always fine; writing is not
implied by having the tools.

1. `okf_read` the page to get its current content and `etag`. Skip this only when creating a
   page that does not exist.
2. `okf_preview_change` with the full new content and that `etag`. This stores nothing. It
   returns a diff and either passes or lists what is wrong.
3. Show the diff to the person and get their agreement.
4. `okf_apply_change` with the same content and etag to save it.

Send whole page content, not a fragment — these tools replace a page rather than patching it.

### When a save is refused

- **The etag does not match.** Someone changed the page after you read it. Read it again, redo
  the preview against the new content, and check your change still makes sense. Never work
  around this.
- **Validation failed.** The diagnostics name the page and the rule. Fix the content; do not
  try another route.
- **You are not an author.** Reading is open to everyone the access policy admits; saving is
  limited to a shorter list. Report it and stop.

## What makes a page valid

- Frontmatter carries `type`, `title`, and `description`, all non-empty.
- Every page in this corpus is `status: stable`. A draft does not belong here — this corpus is
  read by people and by agents as settled knowledge.
- Links to other pages stay inside the corpus and must resolve. A link pointing outside it
  fails validation.
- External provenance goes in `sources` with an HTTPS URL.
- Never add credentials, personal context, client-confidential material, or raw client data.
  If a page needs any of those to make sense, it does not belong here.

## What this surface cannot do

There is no delete, rename, or bulk edit. Those need a person with direct access, so ask
rather than improvising an equivalent — for example, do not blank a page to simulate deleting
it.

Adding a page also usually means adding it to the index, or nobody will find it. Treat that as
part of the change, not a follow-up.

## Finishing

Say which pages you read or changed, by path. If you changed anything, say what the validator
reported. If you found a gap, a contradiction, or a page that looks stale, say so plainly
instead of filing it silently.
