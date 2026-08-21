# OpenViking Boundary

OpenViking provides contextual retrieval over `viking://` URIs. Its summaries
select candidates; `read` expands the content.

## Profile Gate

| Bundle | Expected config | Account |
| --- | --- | --- |
| Herding Cats Polychrome | `~/.openviking/ovcli.conf` | `local-dev` |
| XBOL | `~/.openviking/ovcli-xbol.conf` | `xbol` |
| Iteramind | `~/.openviking/ovcli-iteramind.conf` | `iteramind-dev` |

Before use, inspect `OPENVIKING_CLI_CONFIG_FILE` and the configured account. If
the profile cannot be established or differs from the adapter, skip OpenViking
and report the mismatch. Reading another repository does not switch the
already-running MCP account.

## Read

Use only tools registered for the active role:

- `health` to confirm availability;
- `find` for fast candidates;
- `search` for deeper retrieval; and
- `read`, `list`, `grep`, and `glob` to inspect selected namespaces.

Treat every result as a lead. Corroborate durable claims and label
`viking://` citations as contextual.

Keep recall subordinate to the selected OKF Bundle. Do not use an OpenViking
result to traverse, graph, link, or mutate another Bundle in the same operation.
An external or reference corpus may supply evidence only through its own
authority and workflow.

## Additive Curation

Only a write-capable curator may use additive operations, and policy must
prompt for each call.

Use `remember` only after an explicit request. First write the readable
authority when the adapter requires one, then preview the account, exact facts,
provenance, and effect. Exclude secrets, raw transcript dumps, and unverified
inference. Search and read afterward; do not claim success until retrieval
verifies it.

Use `add_resource` only after an explicit request to ingest a named source.
Preview the account, URL or file, destination, description, and breadth. Set
`watch_interval` to `0`. Verify the asynchronous result.

Do not delete memories, create watches, reindex, structurally mutate
namespaces, mirror authored edits automatically, or use direct mutating `ov`
commands.
