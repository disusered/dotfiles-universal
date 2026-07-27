---
name: polychrome-journal-ops
description: Inspect and explicitly process Carlos-authored Neorg Black entries into revision-bound, attributed connection proposals and capture receipts without rewriting the human body. Use when Carlos asks to process Black, find connections to Polychrome, archive entry URLs in Zotero, review stale entry processing, or accept or reject an existing proposal.
---

# Polychrome Journal Operations

Preserve Carlos's authored narrative. Semantic work belongs in structured
handoffs and Marginalia; deterministic tooling alone updates a Black managed
section.

Read [references/processing.md](references/processing.md) before processing an
entry or deciding a proposal.

## Gate the Workflow

Process Black only after an explicit request such as “process Black” or a named
entry. Do not install a watcher, react to saves, or process unrelated entries.

Confirm the repository root and `polychrome.json`. Read repository
instructions, the Black local instructions, the Polychrome operating schema,
and the exact command help before invocation. Do not invent an unavailable
command or handoff field.

## Inspect

1. Run `polychromectl black list --black-root black --state unprocessed` or
   the same command with `--state stale` to discover the requested scope.
2. Run
   `polychromectl black inspect <entry> --black-root black --format json`.
3. Treat the returned body hash and anchors as the only valid revision
   identity.
4. Never edit bytes between human-body sentinels.
5. Treat the returned body as private: do not log it or place it in a public
   export, handoff destination, or indexing service.

## Research

Query the curated Polychrome corpus first, then attributed Marginalia, Zotero,
World sources, and optional read-only OpenViking recall. Delegate bounded,
independent research when useful and require structured outputs tied to exact
anchors.

Distinguish:

- capture from personal integration;
- a candidate relation from an accepted Connection;
- an agent hypothesis from authored or primary evidence; and
- an external source from curated knowledge.

Do not manufacture personal meaning for a bare link. Represent missing
personal context as an unresolved prompt.

## Capture URLs

Preserve the exact URL. Dedupe against receipts and Zotero exact-URL fields.
For a network-safe URL, invoke the verified Zotero adapter through a private
`polychrome.zotero.capture-input.v1` file and record exactly one status:

- `existing`;
- `full`;
- `metadata-only`; or
- `failed`.

Never call a metadata fetch `full`, and never promote a Zotero item as a side
effect. Never send a URL containing credentials or targeting a local,
non-public, or otherwise blocked host. Represent it in the handoff as
`failed`, method `none`, `attempted: false`, and error `privacy-blocked`.
Successful evidence preserves an exact URL, including its query when present;
failure reports identify the request or entry and a sanitized reason without
echoing the private URL.

## Apply

1. Construct `polychrome.processing.v1` with entry ID, path, body hash,
   RFC 3339 observation time, processor attribution, exactly one capture result
   for every distinct body URL, attributed typed proposals, byte-exact anchors,
   rationales, confidence, privacy warnings, and unresolved questions.
2. Under `umask 077`, store the handoff in a private regular, non-symlink
   temporary file, restrict that exact file with `chmod 600`, and never include
   credentials or unrelated secrets.
3. Run:

   ```bash
   polychromectl black apply <entry> \
     --handoff <private-file> \
     --black-root black \
     --marginalia-root marginalia \
     --polychrome-root polychrome
   ```

4. Stop on a stale-revision error. Reinspect rather than forcing an apply.
5. Confirm that only Marginalia records, receipts, and the managed Connections
   section changed.
6. Run federation and store validation required by local instructions.

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

Remove only the exact temporary capture input and handoff after their results
and immutable receipt have been verified; retain the handoff if an idempotent
retry is still required.

Report processed entry IDs and hashes, capture statuses, proposal IDs,
validation actually run, stale results, unresolved prompts, and any
OpenViking operation separately. Never present suggestions as Carlos's words
or accepted knowledge.
