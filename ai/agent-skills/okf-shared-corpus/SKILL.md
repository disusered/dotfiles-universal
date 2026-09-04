---
name: okf-shared-corpus
description: Read and curate Iteramind's Shared Corpus through the hosted versioned OKF tools. Use when asked what the company has decided or documented, to look up team knowledge, or to create, correct, move, or delete a reviewed shared page. Adds Iteramind's authority and content policy to the common single-Bundle OKF workflow.
---

# Iteramind Shared Corpus

Use the common transport and change contract instead of maintaining a second
OKF procedure:

- Read [the transport contract](../okf-knowledge-ops/references/transports.md).
- Read the **Iteramind Shared** section of
  [the consumer adapter notes](../okf-knowledge-ops/references/adapters.md).

The hosted deployment serves exactly one Bundle, named `shared`. It is the
company's reviewed knowledge and is reached only through its `okf_v1_*` MCP
tools. Do not start a local server, read the R2 bucket directly, use the retired
unversioned `okf_*` tools, or add the Private Corpus as another Bundle.

## Establish context and authority

Call `okf_v1_context` with `bundle: "shared"` before substantive work. Read
its instruction documents and index. Authored Markdown pages are authoritative;
the index, search snippets, inspection output, and visualization are generated
views.

Open the relevant page before relying on a claim and cite its Bundle-relative
path. Retain its opaque `revision` if the page may change. Use links and search
to find related pages inside this Bundle only.

The visualization is a deterministic projection rebuilt from the current
Bundle after R2 source events. Never edit it or treat it as authored knowledge.

## Enforce Shared Corpus policy

- Store bot-safe company knowledge only.
- Require non-empty `type`, `title`, and `description` frontmatter, and a
  declared `status`. `status: stable` is a claim of review: it needs a
  `verified` entry naming a `human:<id>` actor, and fails validation without
  one. Anything nobody has re-read stays `draft`. Drafts belong here; what
  separates the corpora is audience, not maturity.
- A Markdown link that leaves the Shared Bundle is an error
  (`guidance.link.escape`) and blocks the write. Point it at an HTTPS `sources`
  entry instead.
- A link to a page inside the bundle that nobody has written yet is **not** an
  error. The profile deliberately re-reports it as a warning
  (`iteramind.shared.link.pending`); it is the bundle's own to-do list. Never
  delete, stub, or reword such a link to make a diagnostic go away.
- Record external provenance as HTTPS resources in `sources`.
- Never add credentials, personal context, private drafts, raw client data, or
  client-confidential material.
- Treat promotion from Private to Shared as an explicit reviewed content
  change. Never synchronize or cross-link the corpora.

## Change content

Writing requires both an explicit user request and deployment author access.
Use the common full-page Change contract:

1. Read the current page and retain its `revision`; a new page has no prior
   revision.
2. Preview one complete create, update, delete, or move Change with
   `okf_v1_preview_change`.
3. Show the returned diff, affected paths, and diagnostics. Wait for explicit
   approval.
4. Apply the unchanged request and exact `preview_id` with
   `okf_v1_apply_change`.
5. Read the affected paths and validate the Bundle after a successful apply.

A stale revision or preview, failed validation, Bundle-name refusal, or author
refusal stops the write. Read current state and obtain a new preview when the
content changed underneath the request. Never bypass a refusal, reuse an old
preview for different content, blank a page to imitate deletion, or switch
transports.

When adding or moving a page, include any required index update as a separately
previewed and approved Change. There is no implicit bulk-edit authorization.

## Finish

Report the paths read or changed. For a write, report the apply outcome,
resulting revisions, and post-write validation. State any gap, contradiction,
or stale page plainly; do not file or repair it without authorization.
