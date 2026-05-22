---
name: query
description: "Query the XBOL PostgreSQL databases (dev or QA) via psql over Tailscale. Full access for schema inspection, data queries, writes, and DDL. Specify which environment: 'query dev for X' or 'query qa for X'."
version: 2.0.0
metadata:
  hermes:
    tags: [postgres, database, query, sql, xbol, boletera, dev, qa]
    related_skills: [postgres]
---

# Query — XBOL Databases

Connect to the team's PostgreSQL databases proxied through Tailscale at `work.anchovy-lizard.ts.net:3308`.

## Environments

The user must specify which environment — **dev** or **qa**. If ambiguous, ask.

## Connection

Credentials are pre-resolved in the active Hermes profile env file (populated by `hermes-init` via `op inject`). No runtime `op` calls needed.

Use `HERMES_HOME/.env` when `HERMES_HOME` is set; otherwise fall back to the default profile at `~/.hermes/.env`. **Do not search the filesystem for other `.env` files.** If the expected env file or keys are missing, stop and tell the user to run `hermes-init` for the active profile.

Replace `<PREFIX>` with `DEV` or `QA` (uppercase):

```bash
HERMES_ENV="${HERMES_HOME:-$HOME/.hermes}/.env"
[ -r "$HERMES_ENV" ] || { echo "Missing Hermes env file: $HERMES_ENV" >&2; exit 1; }
export PGHOST="$(grep '^<PREFIX>_PGHOST=' "$HERMES_ENV" | cut -d= -f2-)"
export PGPORT="$(grep '^<PREFIX>_PGPORT=' "$HERMES_ENV" | cut -d= -f2-)"
export PGUSER="$(grep '^<PREFIX>_PGUSER=' "$HERMES_ENV" | cut -d= -f2-)"
export PGDATABASE="$(grep '^<PREFIX>_PGDATABASE=' "$HERMES_ENV" | cut -d= -f2-)"
export PGPASSWORD="$(grep '^<PREFIX>_PGPASSWORD=' "$HERMES_ENV" | cut -d= -f2-)"
[ -n "$PGHOST" ] && [ -n "$PGPORT" ] && [ -n "$PGUSER" ] && [ -n "$PGDATABASE" ] && [ -n "$PGPASSWORD" ] || { echo "Missing <PREFIX> database credentials in $HERMES_ENV" >&2; exit 1; }
psql --csv -c "<SQL>"
```

For multi-line queries:

```bash
HERMES_ENV="${HERMES_HOME:-$HOME/.hermes}/.env"
[ -r "$HERMES_ENV" ] || { echo "Missing Hermes env file: $HERMES_ENV" >&2; exit 1; }
export PGHOST="$(grep '^<PREFIX>_PGHOST=' "$HERMES_ENV" | cut -d= -f2-)"
export PGPORT="$(grep '^<PREFIX>_PGPORT=' "$HERMES_ENV" | cut -d= -f2-)"
export PGUSER="$(grep '^<PREFIX>_PGUSER=' "$HERMES_ENV" | cut -d= -f2-)"
export PGDATABASE="$(grep '^<PREFIX>_PGDATABASE=' "$HERMES_ENV" | cut -d= -f2-)"
export PGPASSWORD="$(grep '^<PREFIX>_PGPASSWORD=' "$HERMES_ENV" | cut -d= -f2-)"
[ -n "$PGHOST" ] && [ -n "$PGPORT" ] && [ -n "$PGUSER" ] && [ -n "$PGDATABASE" ] && [ -n "$PGPASSWORD" ] || { echo "Missing <PREFIX> database credentials in $HERMES_ENV" >&2; exit 1; }
psql --csv -f - <<'SQL'
  <multi-line SQL here>
SQL
```

**Pitfall:** Do NOT use `eval` to load these variables — the password contains shell-special characters (`[`, `)`, `|`) that break `eval`. The `grep | cut` + `export VAR="$(...)"` pattern avoids this by capturing values in subshells.

If the expected env file or keys are missing, the user may need to run `hermes-init` for the active profile, e.g. `hermes-init xbol`. Do not use `find`, `grep -R`, or broad home-directory scans to locate credentials.

Full read/write access on both environments. No restrictions on statement types. Use good judgment: confirm before destructive operations (DROP, TRUNCATE) unless the user is clearly asking for it.

## Common Queries

### Schema Exploration

```sql
\dt
\d <table_name>
\dn
\di
SELECT relname AS table,
       pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = '<table>'
ORDER BY ordinal_position;
```

### Data Queries

```sql
SELECT * FROM <table> ORDER BY created_at DESC LIMIT 10;
SELECT count(*) FROM <table>;
SELECT DISTINCT <column> FROM <table> LIMIT 20;
```

### Performance

```sql
EXPLAIN ANALYZE <query>;
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active';
SELECT schemaname, relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan;
```

## Output Formatting

**Pipeline:**

1. Run queries with `psql --csv` to get raw CSV output.
2. Pipe through `tabulate` to render an ASCII table: `tabulate -s ',' -f fancy_grid -1`
3. Wrap the table in a **triple-backtick code block** so Discord preserves whitespace and renders monospace.

**Example command:**

```bash
psql --csv -c "SELECT id, name, status FROM users LIMIT 5" | tabulate -s ',' -f fancy_grid -1
```

**Rules:**

- **Always use `psql --csv`** for data queries — this gives clean CSV that `tabulate` parses reliably.
- **Only the table goes in code fences** — titles, descriptions, and commentary use normal Markdown outside the code block (bold headers, bullet points, etc.).
- **Never manually draw tables** with Unicode or pipe characters — let `tabulate` handle it.
- For scalar results (count, exists, single value), present the value inline — no table needed.
- If a query returns no rows, say "No results" — don't render an empty table.
- If a column value is NULL, display `∅` (empty set) to distinguish it from an empty string.
- For wide result sets, consider adding `LIMIT` or selecting fewer columns rather than letting the table overflow.

**Example response:**

**Users — last 5 active**

```
╒════╤═════════╤══════════╕
│ id │ name    │ status   │
╞════╪═════════╪══════════╡
│  1 │ Alice   │ active   │
│  2 │ Bob     │ inactive │
╘════╧═════════╧══════════╛
```

_3 rows total, 2 shown._

## Language

Respond in Spanish for reports and data discussions unless the user writes in English.

## Common Reports

See `references/common-reports.md` for reusable SQL patterns:

- **Mini-Reporte de Clausura** — resumen general, desglose por evento, temporada, tickets escaneados, últimas órdenes

## Workflow

1. Determine which environment the user wants (dev or qa). If not specified, ask.
2. Build the query — start with schema exploration if unfamiliar with the tables. Check `references/common-reports.md` for ready-made report patterns before writing from scratch.
3. Execute using the connection template above, adding `--csv` flag to `psql` for data queries.
4. Pipe CSV output through `tabulate -s ',' -f fancy_grid -1` and wrap in a code block per the **Output Formatting** rules.
