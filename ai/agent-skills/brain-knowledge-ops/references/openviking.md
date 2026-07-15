# OpenViking Boundary

OpenViking supplies hierarchical contextual retrieval over `viking://` URIs.
Its L0/L1 summaries help choose candidates; `read` expands the full content.
See [OpenViking](https://github.com/volcengine/OpenViking/).

## Profile Gate

The Codex launch directory selects the profile for the entire process:

| Brain | Expected config | Account |
| --- | --- | --- |
| Herding Cats | `~/.openviking/ovcli.conf` | `local-dev` |
| XBOL | `~/.openviking/ovcli-xbol.conf` | `xbol` |

Before an OpenViking operation, inspect `OPENVIKING_CLI_CONFIG_FILE` and the
configured account. If the active profile cannot be established or differs
from the Brain adapter, skip OpenViking and state the mismatch. Reading files
from another Brain does not switch the already-running MCP account.

## Read

Use only the tools registered for the active agent:

- `health` to confirm service availability;
- `find` for fast semantic candidates;
- `search` for deeper semantic retrieval;
- `read` to expand selected URIs;
- `list`, `grep`, and `glob` for namespace inspection.

Treat every result as a lead. Corroborate durable claims against authored OKF
and any higher-authority evidence. Cite the `viking://` URI only as contextual
memory and disclose conflicts.

## Additive Curation

Only a write-capable curator may use these operations, and the MCP policy must
prompt before each call:

### Remember

Use `remember` only when the user explicitly asks to remember, capture, or add
information to OpenViking. Before calling it, show the active account, exact
facts or decisions to retain, and their provenance. Exclude secrets, raw
transcript dumps, and unverified inference. Search and read afterward; do not
claim success until asynchronous extraction is retrievable.

### Add Resource

Use `add_resource` only when the user explicitly asks to ingest a named source.
Show the active account, exact URL or local file, destination URI if supplied,
description, and breadth. Set `watch_interval` to `0`. Do not infer whole-site
ingestion, create a watch, or ingest an entire repository as a side effect of
wiki maintenance. Verify the asynchronous result before claiming completion.

## Excluded Operations

Do not use `forget`, `cancel_watch`, direct mutating `ov` commands, or CLI-only
`write`, `mv`, `link`, `unlink`, `import`, `restore`, or `reindex` operations.
Do not automatically mirror OKF edits into OpenViking. Structural OpenViking
maintenance requires a future, separately authorized workflow.
