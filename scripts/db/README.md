# Database Utility Scripts

This directory contains utility SQL scripts for managing and querying the AIXCL database.

## Migration Scripts

### `002_add_source_column.sql`
Migration script to add the `source` column to existing `chat` tables. This is only needed for databases that were created before the source column was added to the main migration. New installations automatically include this column via `001_create_chat_table.sql`.

**Usage:**
```bash
docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < scripts/db/002_add_source_column.sql
```

### `fix_peewee_migrations.sql` / `fix_peewee_migration.sh`
Fix script for Open WebUI peewee migration issues. This script creates the `peewee_migrate_history` tracking table and marks completed migrations when the database schema already has the required columns (e.g., when migrations were run manually or via custom scripts).

**Usage:**
```bash
# Using the bash script (recommended)
./scripts/db/fix_peewee_migration.sh

# Or directly with SQL
docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < scripts/db/fix_peewee_migrations.sql
```

**When to use:**
- When Open WebUI fails to start with errors like "column X already exists"
- When the `peewee_migrate_history` table is missing but the schema already exists
- After manually running migrations or restoring from a backup

## Query Scripts

### `query_continue_chats.sql`
Query to list Continue plugin conversations from the database.

**Usage:**
```bash
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -f scripts/db/query_continue_chats.sql
```

### `query_all_chats.sql`
Query to list all conversations (both Open WebUI and Continue) from the database.

**Usage:**
```bash
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -f scripts/db/query_all_chats.sql
```

## Notes

- All scripts use `IF NOT EXISTS` clauses where appropriate to be idempotent
- Replace `${POSTGRES_USER}` and `${POSTGRES_DATABASE}` with your actual values from `.env`
- These scripts are for manual database inspection and maintenance
- The main application automatically runs migrations on startup

