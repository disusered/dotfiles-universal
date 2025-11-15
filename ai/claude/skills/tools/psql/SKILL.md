---
name: psql
description: PostgreSQL via docker compose - NEVER run psql locally
allowed-tools: Bash
---

# psql Reference

**CRITICAL: ALWAYS use docker compose. NEVER run psql locally.**

## Basic Pattern

```bash
# Interactive shell
docker compose exec -it postgres psql -U postgres -d myapp_db

# Single command
docker compose exec -it postgres psql -U postgres -d myapp_db -c "SELECT * FROM users;"

# Execute file (note: -T not -it)
docker compose exec -T postgres psql -U postgres -d myapp_db < schema.sql
```

## Common Operations

```bash
# Backup
docker compose exec -T postgres pg_dump -U postgres -d myapp_db > backup.sql

# Restore
docker compose exec -T postgres psql -U postgres -d myapp_db < backup.sql

# Logs
docker compose logs postgres

# Restart
docker compose restart postgres
```

## Useful psql Meta-Commands

Once connected via `docker compose exec -it postgres psql`:

- `\l` - List databases
- `\dt` - List tables
- `\d table_name` - Describe table
- `\du` - List users
- `\c database_name` - Connect to database
- `\q` - Quit
- `\x` - Toggle expanded display
- `\timing` - Toggle query timing

## Tips

- Use `-it` for interactive (shell access)
- Use `-T` for non-interactive (piping files)
- Service name is typically `postgres` but check your docker-compose.yml
- Default user is usually `postgres` but verify in your compose file
