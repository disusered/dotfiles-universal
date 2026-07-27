# Black Processing Contract

## Authority

- Carlos alone authors the Black body.
- A deterministic adapter owns the managed Connections section.
- Marginalia owns attributed proposals, memos, and receipts.
- The curated Polychrome store owns accepted Connections.
- Zotero owns captured external source records.
- Red owns collaboratively edited derivatives and is private by default.

The body hash is SHA-256 over the exact bytes between the Black human-body
sentinels. Metadata and managed content are excluded. A new hash creates a new
revision; old proposals remain historical and become stale.

Black and Marginalia roots and directories use mode `0700`; private regular
files use `0600`. Federation validation and journal commands fail closed on
unsafe roots or files. Follow the repository's bounded bootstrap after a fresh
checkout; never chmod a broader path.

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

Capture evidence preserves the exact body URL:

- `existing`, `full`, and `metadata-only` require a valid `itemKey` and forbid
  `error`; optional `itemKeys` must include the primary key.
- `failed` requires `error` and boolean `attempted`, and forbids `itemKey` and
  `itemKeys`.
- Recognized methods are `local-api`, `web-api`, `connector-snapshot`, and
  `none`.
- `full` additionally requires method `connector-snapshot`,
  `snapshotConfirmed: true`, and `attempted: true`. No other status may confirm
  a snapshot.
- A credential-bearing, local, non-public, or otherwise blocked URL is not sent
  to Zotero or the network. Its result is `failed`, method `none`,
  `attempted: false`, and error `privacy-blocked`.
- Exact successful capture evidence may preserve a query string by design.
  Sanitized failure reporting names the request or entry, not the private URL.

Do not include chain-of-thought. A rationale states concise evidence useful to
Carlos's review.

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
- the entry is outside the registered Black root;
- the body revision changed;
- a proposed target cannot be resolved;
- Zotero authentication or durability cannot be established; or
- required validation fails.

A Zotero failure does not authorize another archive service. A stale revision
does not authorize rebasing agent output onto changed prose. Preserve partial
capture statuses without implying the overall apply succeeded. Do not echo a
failed exact URL in logs, terminal summaries, or error prose.
