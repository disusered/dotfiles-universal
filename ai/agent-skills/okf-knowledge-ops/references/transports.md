# OKF v1 Transports

The local CLI and hosted MCP compose the same single-Bundle analysis and
`okf.operations.v1` Change contract. Select one transport for one Bundle and do
not switch transports to work around a refusal.

## Release-installation seam

The verified source contract is currently versioned `1.0.0-rc.0`, but the
consumer repositories do not yet record one common released `okf-cli` pin or
installation command. Before a local operation, verify that the consumer owns
an exact package pin and exposes its binary as `okf`. If either is missing,
report the release-installation seam and stop; do not improvise with `npx`, a
toolkit source checkout, the retired Python conformance checker, or a local MCP
server.

The hosted deployment must supply the `okf_v1_*` tools below and document its
one Bundle name. If only unversioned `okf_*` tools are present, or the Bundle
name is unknown, report the deployment cutover seam and stop. Do not substitute
the older hosted skill or guess a name.

For format-level decisions, read `spec/SPEC.md` from the exact pinned
`okf-contracts` release. How each consumer exposes that installed file is also
unresolved; do not fall back to an unrelated global copy.

## Local JSON CLI

The CLI form is `okf <command> [target] [options]`; JSON is the default output
and `--json` is accepted explicitly. `target` is either the exact Bundle root or
a path inside a project whose `.agents/okf.yaml` declares the Bundle. When a
manifest declares more than one Bundle, pass exactly one `--bundle NAME`.

Use these verified shapes:

```text
okf context [target] [--bundle NAME]
okf list [target] [--bundle NAME]
okf search [target] <query...> [--bundle NAME] [--limit NUMBER]
okf read [target] <bundle-relative-path> [--bundle NAME]
okf links [target] [bundle-relative-path] [--bundle NAME]
okf validate [target] [--bundle NAME] [--strict]
okf inspect [target] [--bundle NAME]
okf visualize [target] --out FILE [--bundle NAME]
okf change preview [target] --input FILE|- [--bundle NAME]
okf change apply [target] --preview-id ID --input FILE|- [--bundle NAME]
```

`--preview-id` is required by `change apply` and rejected by `change preview`.
Use the exact opaque `sha256:` identifier emitted by preview; its wire form is
64 lowercase hexadecimal digits after the prefix.

The corresponding envelopes are `okf.context.v1`, `okf.list.v1`,
`okf.search.v1`, `okf.read.v1`, `okf.links.v1`, `okf.validate.v1`,
`okf.inspect.v1`, `okf.visualize.v1`, and `okf.operations.v1`. Errors are JSON
on stderr under `okf.error.v1`. A validation failure exits 1; an invocation
error exits 2. `--strict` makes OKF guidance warnings fail validation.

Profiles are consumer-owned. Use `--profile-module FILE` only when the consumer
documents a trusted module exporting `profile`; named `--profile` values are
unsupported.

Call `context` first. It returns manifest-scoped instruction documents when the
project has `.agents/okf.yaml`; an explicit Bundle root with no manifest returns
an empty instruction list, so repository instructions still need a direct read.

## Hosted v1 MCP

A hosted deployment serves exactly one configured Bundle. Every call includes
that documented Bundle name, and the server refuses any other name.

| Tool | Input after selecting `bundle` |
| --- | --- |
| `okf_v1_context` | none |
| `okf_v1_list` | optional `path` (default `.`), optional `depth` (0–8, default 2) |
| `okf_v1_search` | `query`, optional `limit` (1–100, default 20) |
| `okf_v1_read` | `path` |
| `okf_v1_links` | `path` |
| `okf_v1_validate` | none |
| `okf_v1_inspect` | none |
| `okf_v1_visualize` | none |
| `okf_v1_preview_change` | `change` |
| `okf_v1_apply_change` | `change`, `preview_id` |

Call `okf_v1_context` before substantive work. The tool returns the hosted
index and deployment-owned instructions. Read and retain the opaque `revision`
returned for any document that may be updated, deleted, or moved.

The deployment owns authentication and apply policy. `okf_v1_preview_change`
is read-only. Show its diff, affected paths, and diagnostics, then wait for
explicit authorization before `okf_v1_apply_change`. An authorization refusal
is final for that operation.

## Change contract

Send one complete JSON Change, never a patch fragment:

| Operation | Required fields |
| --- | --- |
| create | `operation: "create"`, `path`, `content` |
| update | `operation: "update"`, `path`, `content`, `expected_revision` |
| delete | `operation: "delete"`, `path`, `expected_revision` |
| move | `operation: "move"`, `from_path`, `to_path`, `expected_revision` |

Paths are confined Bundle-relative Markdown paths. Revisions are opaque: retain,
echo, and compare them, but never interpret them.

Preview returns `schema: "okf.operations.v1"`, `passed`, `preview_id`,
`affected_paths`, `diff`, and diagnostics. Apply receives the same Change plus
that exact reviewed `preview_id`. For the CLI, pass it with `--preview-id`; for
hosted MCP, include it beside `change` in `okf_v1_apply_change`. It rechecks the
current Bundle and returns `outcome` as `applied`, `unchanged`, or `rejected`,
plus resulting revisions and diagnostics.

A missing, malformed, or mismatched `preview_id`, or Bundle state that makes
the reviewed Change stale, stops the apply without authorizing another route.
Read the current state, construct the appropriate Change, and obtain a new
preview before retrying. Never reuse the old `preview_id` with modified Change
content or a replacement revision.
