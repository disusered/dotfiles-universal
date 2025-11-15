---
name: psql
description: Use psql for PostgreSQL database operations. IMPORTANT - Always run psql through docker compose, never locally. Automatically loaded for database tasks.
allowed-tools: Bash
---

# psql Reference

PostgreSQL command-line client for database operations.

## CRITICAL - Docker Compose Usage

**NEVER run psql locally. ALWAYS use docker compose.**

### Standard psql Command Pattern

```bash
# Run psql through docker compose
docker compose exec -it <service-name> psql -U <username> -d <database>

# Example - connecting to postgres service
docker compose exec -it postgres psql -U postgres -d myapp_db

# Run a single SQL command
docker compose exec -it postgres psql -U postgres -d myapp_db -c "SELECT * FROM users;"

# Execute SQL file
docker compose exec -T postgres psql -U postgres -d myapp_db < schema.sql

# Get shell access first, then run psql
docker compose exec -it postgres bash
psql -U postgres -d myapp_db
```

## Common psql Commands

### Connection and Meta-Commands

```sql
-- List all databases
\l
\list

-- Connect to a database
\c database_name
\connect database_name

-- List all tables in current database
\dt
\dt+  -- with size information

-- List all schemas
\dn

-- Describe a table
\d table_name
\d+ table_name  -- with more details

-- List all views
\dv

-- List all indexes
\di

-- List all sequences
\ds

-- List all functions
\df

-- List all users/roles
\du

-- Show current connection info
\conninfo

-- Show command history
\s

-- Quit psql
\q
```

### Query Execution

```sql
-- Execute SQL file
\i /path/to/file.sql

-- Execute shell command
\! ls -la

-- Toggle timing of commands
\timing

-- Set output format
\x           -- toggle expanded display
\x auto      -- auto-expand based on terminal width

-- Export query results to CSV
\copy (SELECT * FROM users) TO '/tmp/users.csv' CSV HEADER;
```

### Useful psql Options

```bash
# Connect to specific database
docker compose exec -it postgres psql -U postgres -d database_name

# Run SQL command directly
docker compose exec -it postgres psql -U postgres -d database_name -c "SQL COMMAND"

# Execute SQL file
docker compose exec -T postgres psql -U postgres -d database_name -f /path/to/file.sql

# Quiet mode (no welcome message)
docker compose exec -it postgres psql -U postgres -d database_name -q

# Output only tuples (no headers)
docker compose exec -it postgres psql -U postgres -d database_name -t

# Align mode (for better formatting)
docker compose exec -it postgres psql -U postgres -d database_name -A

# HTML output
docker compose exec -it postgres psql -U postgres -d database_name -H

# List databases and exit
docker compose exec -it postgres psql -U postgres -l
```

## Common SQL Operations

### Database Management

```sql
-- Create database
CREATE DATABASE myapp_db;

-- Drop database
DROP DATABASE myapp_db;

-- Show database size
SELECT pg_size_pretty(pg_database_size('myapp_db'));

-- Show all database sizes
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

### Table Operations

```sql
-- Create table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Drop table
DROP TABLE users;

-- Truncate table
TRUNCATE TABLE users;

-- Show table size
SELECT pg_size_pretty(pg_total_relation_size('users'));

-- Show all table sizes in current database
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Querying Data

```sql
-- Basic SELECT
SELECT * FROM users;
SELECT id, username FROM users WHERE id = 1;

-- With joins
SELECT u.username, o.order_id
FROM users u
JOIN orders o ON u.id = o.user_id;

-- Aggregations
SELECT COUNT(*) FROM users;
SELECT category, COUNT(*) FROM products GROUP BY category;

-- With pagination
SELECT * FROM users ORDER BY created_at DESC LIMIT 10 OFFSET 20;
```

### Data Modification

```sql
-- Insert data
INSERT INTO users (username, email) VALUES ('alice', 'alice@example.com');

-- Insert multiple rows
INSERT INTO users (username, email) VALUES
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com');

-- Update data
UPDATE users SET email = 'newemail@example.com' WHERE id = 1;

-- Delete data
DELETE FROM users WHERE id = 1;
```

### Schema Operations

```sql
-- Add column
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- Drop column
ALTER TABLE users DROP COLUMN phone;

-- Rename column
ALTER TABLE users RENAME COLUMN username TO user_name;

-- Change column type
ALTER TABLE users ALTER COLUMN email TYPE TEXT;

-- Add constraint
ALTER TABLE users ADD CONSTRAINT unique_email UNIQUE (email);

-- Drop constraint
ALTER TABLE users DROP CONSTRAINT unique_email;
```

### Indexes

```sql
-- Create index
CREATE INDEX idx_users_email ON users(email);

-- Create unique index
CREATE UNIQUE INDEX idx_users_username ON users(username);

-- Drop index
DROP INDEX idx_users_email;

-- Show indexes for a table
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'users';
```

## Database Administration

### Backup and Restore

```bash
# Backup database (pg_dump through docker compose)
docker compose exec -T postgres pg_dump -U postgres -d myapp_db > backup.sql

# Backup with custom format (smaller, faster)
docker compose exec -T postgres pg_dump -U postgres -Fc -d myapp_db > backup.dump

# Backup all databases
docker compose exec -T postgres pg_dumpall -U postgres > all_databases.sql

# Restore from SQL file
docker compose exec -T postgres psql -U postgres -d myapp_db < backup.sql

# Restore from custom format
docker compose exec -T postgres pg_restore -U postgres -d myapp_db backup.dump

# Restore to a new database
docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE myapp_db_restored;"
docker compose exec -T postgres psql -U postgres -d myapp_db_restored < backup.sql
```

### User and Permission Management

```sql
-- Create user
CREATE USER myapp_user WITH PASSWORD 'secure_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO myapp_user;
GRANT SELECT, INSERT, UPDATE ON users TO myapp_user;

-- Revoke privileges
REVOKE ALL PRIVILEGES ON DATABASE myapp_db FROM myapp_user;

-- Drop user
DROP USER myapp_user;

-- Show user permissions
\du

-- Show table permissions
\dp table_name
```

### Monitoring and Performance

```sql
-- Show running queries
SELECT pid, usename, state, query, query_start
FROM pg_stat_activity
WHERE state != 'idle';

-- Kill a query
SELECT pg_terminate_backend(pid);

-- Show slow queries
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Show table statistics
SELECT schemaname, tablename, n_live_tup, n_dead_tup
FROM pg_stat_user_tables;

-- Show index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
```

## Docker Compose Integration Examples

### Example docker-compose.yml snippet

```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Common Workflows

```bash
# Start the database
docker compose up -d postgres

# Connect to psql
docker compose exec -it postgres psql -U postgres -d myapp_db

# Run migrations
docker compose exec -T postgres psql -U postgres -d myapp_db < migrations/001_initial.sql

# Check logs
docker compose logs postgres

# Restart database
docker compose restart postgres

# Stop database
docker compose stop postgres

# Remove database (WARNING: destroys data)
docker compose down -v
```

## Environment Variables

When using docker compose, connection parameters are typically set via environment variables:

```bash
# In docker-compose.yml or .env file
POSTGRES_USER=postgres
POSTGRES_PASSWORD=secure_password
POSTGRES_DB=myapp_db
POSTGRES_HOST=postgres  # service name
POSTGRES_PORT=5432
```

## Troubleshooting

### Common Issues

```bash
# Cannot connect to database
# Solution: Check if container is running
docker compose ps

# Solution: Check logs
docker compose logs postgres

# Database does not exist
# Solution: Create it first
docker compose exec -it postgres psql -U postgres -c "CREATE DATABASE myapp_db;"

# Permission denied
# Solution: Check user permissions
docker compose exec -it postgres psql -U postgres -c "\du"

# Too many connections
# Solution: Modify max_connections in postgres config
# Add to docker-compose.yml under postgres service:
#   command: postgres -c max_connections=200
```

## Integration with Claude Code

When working with PostgreSQL databases:

1. **Always use docker compose** - Never run psql locally
2. **Check service name** - Use the correct service name from docker-compose.yml
3. **Use -T flag for non-interactive** - When piping SQL scripts
4. **Use -it for interactive** - When connecting to psql shell
5. **Export results** - Use `\copy` for exporting query results

### Recommended Workflow

```bash
# 1. Verify database is running
docker compose ps

# 2. Connect to database
docker compose exec -it postgres psql -U postgres -d myapp_db

# 3. Explore schema
\dt
\d table_name

# 4. Run queries
SELECT * FROM users LIMIT 5;

# 5. Exit
\q
```

## Quick Reference Card

```bash
# Connection (through docker compose)
docker compose exec -it postgres psql -U <user> -d <database>

# Meta-commands
\l              # list databases
\c db           # connect to database
\dt             # list tables
\d table        # describe table
\du             # list users
\q              # quit

# Query execution
\x              # toggle expanded display
\timing         # toggle query timing
\i file.sql     # execute SQL file
\! command      # run shell command

# Export
\copy (SELECT ...) TO 'file.csv' CSV HEADER;
```

## PostgreSQL vs MySQL

| Feature | PostgreSQL (psql) | MySQL (mysql) |
|---------|-------------------|---------------|
| Standards compliance | ✅ Strict SQL standard | ⚠️ Less strict |
| JSON support | ✅ Native JSONB | ⚠️ Limited |
| Advanced features | ✅ CTEs, window functions | ⚠️ Some |
| Full-text search | ✅ Built-in | ⚠️ Limited |
| Extensibility | ✅ Extensions | ❌ Limited |
| ACID compliance | ✅ Strong | ✅ With InnoDB |

## Further Reading

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [psql Command Reference](https://www.postgresql.org/docs/current/app-psql.html)
- [Docker Compose with PostgreSQL](https://docs.docker.com/samples/postgres/)
- [PostgreSQL Tutorial](https://www.postgresqltutorial.com/)
