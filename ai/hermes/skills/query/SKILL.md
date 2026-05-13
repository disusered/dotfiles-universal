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
eval "$(sed -n "s/^<PREFIX>_\(PG.*\)/\1/p" ~/.hermes/.env)"
psql -c "<SQL>"
```

For multi-line queries:

```bash
eval "$(sed -n "s/^<PREFIX>_\(PG.*\)/\1/p" ~/.hermes/.env)"
psql -f - <<'SQL'
  <multi-line SQL here>
SQL
```

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

## Workflow

1. Determine which environment the user wants (dev or qa). If not specified, ask.
2. Build the query — start with schema exploration if unfamiliar with the tables
3. Execute using the connection template above
4. Present results clearly — format tables, highlight key findings
