---
name: polychrome-journal-ops
description: Select and explicitly process the newest, last N, named, or revised Carlos-authored Neorg Black entries into revision-bound, attributed connection proposals and Zotero capture receipts without rewriting the human body. Use when Carlos asks to process Black, process latest entries, find connections to Polychrome, archive entry URLs in Zotero, review or reprocess stale entries, or accept or reject an existing proposal.
---

# Polychrome Journal Operations

Preserve Carlos's authored narrative. Semantic work belongs in structured
handoffs and Marginalia; deterministic tooling alone updates a Black managed
section.

Read [references/processing.md](references/processing.md) before processing an
entry or deciding a proposal.

## Gate the Workflow

Process Black only after an explicit request such as “process Black,” “process
my newest Black entry,” “process my last 3 Black entries,” or a named entry.
Saving is inert. Do not install a watcher, react to saves, or process unrelated
entries.

Resolve an explicitly requested scope as follows:

- unqualified “newest” or “latest” means
  `--state unprocessed --latest 1`;
- unqualified “last N” means the newest N in state `unprocessed`;
- an explicitly named state (`unprocessed`, `stale`, `current`, or `all`)
  overrides that default; and
- without an explicit state, “reprocess” or “revised” selects `stale`.

Every selection still needs a count: “newest” or “latest” supplies one, and
“last N” supplies N from 1 through 1,024. For bare “process Black” or a
state-only request, ask whether to process the newest one or the last N; do not
invent a count, split an oversized request, or mix states. A named entry
bypasses selection but still requires exact revision inspection.

Confirm the repository root and `polychrome.json`. Read repository
instructions, the Black local instructions, the Polychrome operating schema,
and the exact command help before invocation. Do not invent an unavailable
command or handoff field.

## Inspect

1. Discover a newest or last-N scope with:

   ```bash
   polychromectl black select \
     --black-root black \
     --state <requested-state> \
     --latest <N> \
     --format json
   ```

2. Under `umask 077`, create the exact manifest path with `mktemp`, verify it is
   a regular non-symlink file, restrict it with `chmod 600`, and preserve the
   body-free `polychrome.black.selection.v1` result there. Use its `selectionId`
   as the exact retry identity. Do not reconstruct, extend, or manually sort the
   selection.
3. Stop before research, capture, or writes if `black select` fails or its
   output is not a valid `polychrome.black.selection.v1` manifest. Invalid
   discovery and duplicate IDs fail the command. A false
   `processedRevisionConsistent` value is a rebuildable recovery diagnostic,
   not a selection failure.
4. Run
   `polychromectl black inspect <entry> --black-root black --format json`.
   For a selection, inspect every exact manifest entry and require its ID,
   path, and revision to match.
5. Treat the returned body hash and anchors as the only valid revision
   identity.
6. Never edit bytes between human-body sentinels.
7. Treat the returned body as private: do not log it or place it in a public
   export, handoff destination, or indexing service.

## Research

Query the curated Polychrome corpus first, then attributed Marginalia, Zotero,
World sources, and optional read-only OpenViking recall. Delegate bounded,
independent research when useful. Partition every structured result by the
exact selected entry ID and revision, then bind it to byte-exact anchors. Never
attach one entry's proposal, uncertainty, or quote to another.

Distinguish:

- capture from personal integration;
- a candidate relation from an accepted Connection;
- an agent hypothesis from authored or primary evidence; and
- an external source from curated knowledge.

Do not manufacture personal meaning for a bare link. Represent missing
personal context as an unresolved prompt.

## Batch

Freeze one selection before processing. The selector chooses the newest N
matching revisions and returns them in oldest-to-newest processing order.
Process only those exact revisions and never backfill from a newer entry.

Bounded corpus research may run in parallel. Deduplicate exact URLs across the
batch before Zotero capture, then include exactly one verified capture result
for every distinct body URL in each applicable entry handoff. Construct and
preflight every handoff before applying any of them.

Apply serially in manifest order. Stop on the first revision drift or other
failure; do not attempt later entries. Report applied, failed, and
not-attempted entries. Retain the private selection and exact handoffs only
while the same revisions and inputs permit an idempotent retry. Before any real
apply, discard and correct a handoff that check mode rejects for an anchor,
target, or schema error while its selected ID, path, and revision still match;
then preflight every handoff again under the frozen selection. Revision drift
invalidates that handoff and selection member: do not rebase or backfill it, and
await a new explicit scope.

## Capture URLs

Preserve the exact URL. Dedupe against receipts and Zotero exact-URL fields.
For every distinct network-safe scope URL that still needs capture, use the
exact `polychrome.zotero.capture-input.v1` request schema in the reference.
Under `umask 077`, create its path with `mktemp`, verify a regular non-symlink
file, restrict that exact file with `chmod 600`, and exclude credentials and
unrelated secrets before invoking the verified adapter.

Verify the complete adapter result and copy one result into every applicable
entry handoff. A valid per-request `failed` result is evidence and does not stop
the batch. Stop before apply when the adapter cannot authenticate or return a
valid result document. After verified results have been incorporated, remove
only the exact capture input; retain it only when an exact adapter retry is
still required. Record exactly one status:

- `existing`;
- `full`;
- `metadata-only`; or
- `failed`.

Never call a metadata fetch `full`, and never promote a Zotero item as a side
effect. Never send a URL containing credentials or targeting a local,
non-public, or otherwise blocked host. Represent it in the handoff as
`failed`, method `none`, `attempted: false`, `snapshotConfirmed: false`, and
error `privacy-blocked`.
Successful evidence preserves an exact URL, including its query when present;
failure reports identify the request or entry and a sanitized reason without
echoing the private URL.

## Apply

1. Construct one `polychrome.processing.v1` handoff per entry with entry ID,
   path, body hash, RFC 3339 observation time, processor attribution, exactly
   one capture result for every distinct body URL, attributed typed proposals,
   byte-exact anchors, rationales, confidence, privacy warnings, and unresolved
   questions.
2. Under `umask 077`, store the handoff in a private regular, non-symlink
   temporary file, restrict that exact file with `chmod 600`, and never include
   credentials or unrelated secrets.
3. Preflight each handoff with:

   ```bash
   polychromectl black apply <entry> \
     --handoff <private-file> \
     --black-root black \
     --marginalia-root marginalia \
     --polychrome-root polychrome \
     --check
   ```

   `--check` validates the semantics and would-be content without changing
   Black, Marginalia, or Polychrome. Destination creation, writeability,
   staging, and commit-time checks remain ordinary-apply concerns. For a batch,
   preflight every selected handoff before continuing.
4. Apply a selected batch in manifest order by repeating the exact command
   without `--check`; apply a named single entry once.
5. Stop on the first stale-revision or other apply error. Reinspect rather than
   forcing an apply, and leave later batch entries unattempted.
6. Confirm that only Marginalia records, receipts, and the managed Connections
   section changed.
7. Run federation and store validation required by local instructions.

Applying a handoff does not accept a proposal.

## Decide

Accept or reject a proposal only after a separate explicit instruction naming
the proposal or an unambiguous reviewed set. Run one exact decision:

```bash
polychromectl proposal decide <id> \
  --accept \
  --actor <authorized-actor> \
  --decided-at '<actual-rfc3339-time>' \
  --black-root black \
  --marginalia-root marginalia \
  --polychrome-root polychrome
```

Replace `--accept` with `--reject` only when that is the explicit decision. Use
the actor Carlos authorized and the actual decision time. Preserve the proposal
and decision history. Use `--supersede` only for an undecided stale-revision
proposal; it creates no Connection. When Carlos explicitly names a replacement,
add `--replacement-proposal <id>` to that supersede decision.

Do not draft Red prose, publish, promote a Source, or write OpenViking memory
unless separately and explicitly requested.

## Finish

Follow the complete post-apply sequence in
`polychrome/runbooks/process-black.md`:

```bash
polychromectl log polychrome --message "Processed Black fragment <id>"
polychromectl refresh polychrome
polychromectl lint polychrome
polychromectl index marginalia
polychromectl lint marginalia
polychromectl federation validate polychrome.json
```

Remove each handoff after its applied result and immutable receipt are verified.
Remove an invalid or stale handoff when no exact retry remains possible.
Retain only the frozen selection and unresolved handoffs required for an exact
retry, and remove the selection manifest after every member is resolved. When
drift or another terminal failure makes the frozen batch non-retryable, remove
all remaining handoffs and its selection after reporting the outcome.

Report the selection ID when selection was used; applied, failed, and
not-attempted entry IDs and hashes; capture statuses; proposal IDs; validation
actually run; stale results; unresolved prompts; and any OpenViking operation
separately. Never present suggestions as Carlos's words or accepted knowledge.
