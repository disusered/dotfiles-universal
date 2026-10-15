# Black Processing Contract

## Contents

- [Authority](#authority)
- [Selection and Batch Safety](#selection-and-batch-safety)
- [Karakeep Capture Evidence](#karakeep-capture-evidence)
- [Handoff](#handoff)
- [Apply Preflight](#apply-preflight)
- [Initial Relations](#initial-relations)
- [Failure Rules](#failure-rules)

## Authority

- The author alone writes the Black body.
- A deterministic adapter owns the managed Connections section.
- Marginalia owns attributed proposals, memos, and receipts.
- The curated Polychrome store owns accepted Connections.
- Karakeep owns captured external source records.
- Red owns collaboratively edited derivatives and is private by default.

The body hash is SHA-256 over the exact bytes between the Black human-body
sentinels. Metadata and managed content are excluded. A new hash creates a new
revision; old proposals remain historical and become stale.

Black and Marginalia roots and directories use mode `0700`; private regular
files use `0600`. Federation validation and journal commands fail closed on
unsafe roots or files. Follow the repository's bounded bootstrap after a fresh
checkout; never chmod a broader path.

## Selection and Batch Safety

Use `polychromectl black select` and the installed command help instead of
sorting `black list` output. The selector emits the body-free
`polychrome.black.selection.v1` contract governed by
`polychrome/schema/black-processing.md`.

Normalize requested scopes exactly:

- unqualified “newest” or “latest” selects
  `--state unprocessed --latest 1`;
- unqualified “last N” selects `--state unprocessed --latest N`;
- an explicit `unprocessed`, `stale`, `current`, or `all` state overrides that
  default; and
- without an explicit state, “reprocess” or “revised” selects `stale`.

`--latest` is mandatory and accepts 1 through 1,024. “Newest” or “latest”
supplies one; “last N” supplies N. Ask for one of those counts when the request says
only “process Black” or names only a state. Do not invent a count, silently
split an oversized selection, or mix states.

The selector freezes the newest N matching revisions and returns them in
oldest-to-newest processing order. Under `umask 077`, create the exact manifest
path with `mktemp`, verify it is a regular non-symlink file, restrict it with
`chmod 600`, and preserve the result there. Its deterministic `selectionId`
identifies the retry. Do not reconstruct, reorder, extend, or backfill the
selection.

Stop before body inspection, Karakeep capture, or store writes if `black select`
fails or does not return a valid `polychrome.black.selection.v1` manifest.
Invalid discovery and duplicate IDs fail the command. Treat
`processedRevisionConsistent: false` as a rebuildable recovery diagnostic, not
a selection failure. Inspect every exact selected entry and require its ID,
path, and revision to match the manifest.

Research may run in bounded parallel tasks, but every result remains
partitioned by exact selected entry ID and revision before it is bound to an
anchor. Deduplicate exact URLs across the batch before capture, while retaining
exactly one capture result for each distinct body URL in every applicable entry
handoff. Preflight every handoff, then apply serially in manifest order. Stop
on the first revision drift or other failure and leave later entries not
attempted.

Per-entry Processing Receipts remain authoritative. Minimal v2 creates no
durable batch receipt. Remove each capture input after its verified result has
been incorporated, remove each applied handoff after its result and receipt are
verified, and retain only unresolved handoffs needed for an exact retry. Remove
the private selection manifest after every member is resolved. If drift or
another terminal failure makes the batch non-retryable, report it and remove
all remaining handoffs and that selection.

## Karakeep Capture Evidence

Use the existing Karakeep capture workflow documented in
`~/.dotfiles/tools/karakeep/AGENT-USAGE.md`. Reconcile every requested URL with
the returned bookmark ID, read the record back, and distinguish record storage,
crawl/content, and retrievable archive evidence. Keep exact URLs in private
evidence and sanitize failures in reports.

The repository owns the processing schema. New capture evidence uses exact
`url`, `status` (`existing`, `full`, `metadata-only`, or `failed`), `method`
(`karakeep-cli` or `none`), `attempted`, and `archiveVerified`. Successful
records require `bookmarkId` and a distinct `bookmarkIds` array containing it.
`full` also requires `archiveVerified: true` and a verified `archiveAssetId`;
other statuses cannot claim a verified archive. Keep actual `crawlStatus`
separate. Failed captures use a sanitized `error` and no bookmark IDs.
Unsafe URLs require method `none`, `attempted: false`, `archiveVerified: false`,
and error `privacy-blocked`.

Historical receipts retain their original evidence and remain readable. New
handoffs must use the current Karakeep contract. Historical keys and methods
cannot be used to create new processing receipts.

## Handoff

Use only the schema exposed by the installed `polychromectl` implementation.
The schema is `polychrome.processing.v1`; its required fields are:

- entry ID, Black-root-relative path, and `sha256:` body revision;
- RFC 3339 `observedAt`;
- processor attribution with required `role` and optional `harness`, `session`,
  and `model`;
- exactly one URL capture result per distinct body URL;
- proposals with unique IDs, an allowed relation, an existing
  `polychrome://polychrome/<corpus-relative-page>.md` target, a concise
  rationale, confidence from zero through one, proposer attribution with a
  required role, and a source anchor; and
- required `privacyWarnings` and `unresolvedQuestions` arrays.

Each source anchor is a zero-based, end-exclusive UTF-8 byte range into the
exact inspected body. Its `quote` must equal that byte slice. Do not compute
anchors from rendered, normalized, or rewrapped text.

Capture evidence preserves the exact body URL and observed Karakeep bookmark
and archive identifiers. Use only fields accepted by the current repository
contract. Treat unsafe URLs as unattempted privacy failures; never send them to
the network. Do not claim archive preservation from a bookmark ID or a crawl
status alone.

Do not include chain-of-thought. A rationale states concise evidence useful to
the author's review.

## Apply Preflight

Run `polychromectl black apply` with the exact entry, handoff, and three store
roots plus `--check` before applying. Check mode performs the complete
semantic, revision, anchor, target, and output-rendering validation without
changing Black, Marginalia, or Polychrome. It plans destinations but does not
create directories, test writeability by staging, or perform commit-time
checks; ordinary apply retains those responsibilities.

For a batch, every handoff must pass check mode before the first real apply.
Then repeat the same commands without `--check`, serially and
oldest-to-newest. A preflight failure leaves all selected entries unapplied. A
failure after earlier real applies is a partial batch: preserve those applied
receipts, stop immediately, and report the remaining entries as not attempted.

If check mode rejects an anchor, target, or schema field while the manifest ID,
path, and revision still match, discard the invalid handoff, correct it under
the frozen selection, and preflight every handoff again. Do not reuse the
rejected bytes. Revision drift invalidates the member and requires a new
explicit scope; never rebase or backfill it.

Applying the exact same handoff is idempotent. Check mode does not weaken the
normal revision check at commit time and never authorizes rebasing a handoff
onto changed prose.

## Initial Relations

- `relates-to`
- `questions`
- `supports`
- `contradicts`
- `inspired-by`
- `cites`
- `derived-from`
- `part-of`
- `published-as`
- `materialized-as`

Use only values accepted by the installed schema. A candidate relation remains
a proposal until an explicit decision creates an accepted Connection.

## Failure Rules

Stop and report the exact failure when:

- sentinels or required metadata are malformed;
- selection discovery is invalid or ambiguous;
- the entry is outside the registered Black root;
- the body revision changed;
- the Karakeep capture operation cannot authenticate or return complete evidence,
  or the processing contract cannot represent that evidence; or
- required validation fails.

A per-request capture failure is evidence. Preserve it using the current
contract when supported; it does not authorize another archive service. Correct
a check-mode anchor, target, or schema failure under the frozen selection when the exact revision
still matches; otherwise stop. A stale revision does not authorize rebasing
agent output onto changed prose. Preserve partial capture statuses without
implying the overall apply succeeded. Do not echo a failed exact URL in logs,
terminal summaries, or error prose.
