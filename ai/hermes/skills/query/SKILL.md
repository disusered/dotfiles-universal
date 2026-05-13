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

Connect to the team's PostgreSQL databases proxied through Tailscale at `work.anchovy-lizard.ts.net:3307`.

## Environments

The user must specify which environment — **dev** or **qa**. If ambiguous, ask.

## Connection

Credentials are pre-resolved in `~/.hermes/.env` (populated by `hermes-init` via `op inject`). No runtime `op` calls needed.

Replace `<PREFIX>` with `DEV` or `QA` (uppercase):

```bash
export PGHOST="$(grep '^<PREFIX>_PGHOST=' ~/.hermes/.env | cut -d= -f2-)"
export PGPORT="$(grep '^<PREFIX>_PGPORT=' ~/.hermes/.env | cut -d= -f2-)"
export PGUSER="$(grep '^<PREFIX>_PGUSER=' ~/.hermes/.env | cut -d= -f2-)"
export PGDATABASE="$(grep '^<PREFIX>_PGDATABASE=' ~/.hermes/.env | cut -d= -f2-)"
export PGPASSWORD="$(grep '^<PREFIX>_PGPASSWORD=' ~/.hermes/.env | cut -d= -f2-)"
psql -c "<SQL>"
```

For multi-line queries:

```bash
export PGHOST="$(grep '^<PREFIX>_PGHOST=' ~/.hermes/.env | cut -d= -f2-)"
export PGPORT="$(grep '^<PREFIX>_PGPORT=' ~/.hermes/.env | cut -d= -f2-)"
export PGUSER="$(grep '^<PREFIX>_PGUSER=' ~/.hermes/.env | cut -d= -f2-)"
export PGDATABASE="$(grep '^<PREFIX>_PGDATABASE=' ~/.hermes/.env | cut -d= -f2-)"
export PGPASSWORD="$(grep '^<PREFIX>_PGPASSWORD=' ~/.hermes/.env | cut -d= -f2-)"
psql -f - <<'SQL'
  <multi-line SQL here>
SQL
```

**Pitfall:** Do NOT use `eval` to load these variables — the password contains shell-special characters (`[`, `)`, `|`) that break `eval`. The `grep | cut` + `export VAR="$(...)"` pattern avoids this by capturing values in subshells.

If the connection fails with auth errors, the user may need to run `hermes-init` to refresh credentials.

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

**Rules:**

- **NEVER use Markdown pipe tables** (`| col | col |`) — many channels don't render Markdown and raw pipes are unreadable.
- **NEVER wrap tables in code fences** (```) — breaks rendering in channels that *do* support Markdown.
- Always use **Unicode box-drawing characters** to construct plain-text tables. These render correctly in terminals, Slack, Discord, plain-text email, and Markdown (as monospace blocks).

**Character set:**

```
Corners:    ╔ ╗ ╚ ╝
Tees:       ╠ ╣ ╦ ╩
Crossings:  ╬ ╪
Horizontal: ═ ╤ ╧ ─ ┼
Vertical:   ║ │
```

**Full table (with row separators):**

```
╔════════╦════════════════╦═══════════╗
║   id   ║      name      ║  status   ║
╠════════╬════════════════╬═══════════╣
║      1 ║ Alice          ║ active    ║
╟────────╫────────────────╫───────────╢
║      2 ║ Bob            ║ inactive  ║
╚════════╩════════════════╩═══════════╝
```

**Compact table (no row separators, use for short results):**

```
╔════════╦════════════════╦═══════════╗
║   id   ║      name      ║  status   ║
╠════════╬════════════════╬═══════════╣
║      1 ║ Alice          ║ active    ║
║      2 ║ Bob            ║ inactive  ║
╚════════╩════════════════╩═══════════╝
```

**Guidelines:**

- Right-align numeric columns, left-align text columns. Center column headers.
- For scalar results (count, exists, single value), present the value inline — no table needed.
- For wide result sets, truncate columns that exceed 30 characters with `…` rather than breaking the table layout.
- If a query returns no rows, say "No results" — don't render an empty table shell.
- If a column value is NULL, display `∅` (empty set) to distinguish it from an empty string.

## Workflow

1. Determine which environment the user wants (dev or qa). If not specified, ask.
2. Build the query — start with schema exploration if unfamiliar with the tables
3. Execute using the connection template above
4. Present results using the **Output Formatting** rules above
