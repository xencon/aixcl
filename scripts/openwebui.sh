#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

# Patch Open WebUI migration 005 to be idempotent (check if columns exist)
MIGRATION_005_FILE="/app/backend/open_webui/internal/migrations/005_add_updated_at.py"
if [ -f "$MIGRATION_005_FILE" ]; then
    # Use external Python script for cleaner patching
    if [ -f "/app/backend/patch_migration_005.py" ]; then
        python3 /app/backend/patch_migration_005.py 2>/dev/null || true
    fi
fi

# Fallback: inline patch if external script didn't work
if [ -f "$MIGRATION_005_FILE" ] && ! grep -q "# PATCHED_BY_AIXCL" "$MIGRATION_005_FILE" 2>/dev/null; then
    python3 << 'PYTHON_PATCH'
import re
import sys

migration_file = "/app/backend/open_webui/internal/migrations/005_add_updated_at.py"

try:
    with open(migration_file, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if "# PATCHED_BY_AIXCL" in content:
        sys.exit(0)
    
    # Patch migrate_external to check if columns exist before adding them
    old_pattern = r'(def migrate_external\(migrator: Migrator, database: pw\.Database, \*, fake=False\):.*?migrator\.add_fields\(\s+"chat",\s+created_at=pw\.BigIntegerField\(null=True\),\s+updated_at=pw\.BigIntegerField\(null=True\),\s+\))'
    
    new_code = r'''def migrate_external(migrator: Migrator, database: pw.Database, *, fake=False):
    # PATCHED_BY_AIXCL: Check if columns already exist before adding them
    try:
        # Check if created_at and updated_at columns already exist
        result = database.execute_sql(
            "SELECT COUNT(*) FROM information_schema.columns "
            "WHERE table_name = 'chat' AND column_name IN ('created_at', 'updated_at')"
        )
        existing_cols = result.fetchone()[0] if result else 0
        
        if existing_cols >= 2:
            # Columns already exist, skip adding them
            print("Migration 005: created_at and updated_at columns already exist, skipping")
            return
    except Exception as check_error:
        # If check fails, proceed with migration attempt
        pass
    
    # Adding fields created_at and updated_at to the 'chat' table
    migrator.add_fields(
        "chat",
        created_at=pw.BigIntegerField(null=True),  # Allow null for transition
        updated_at=pw.BigIntegerField(null=True),  # Allow null for transition
    )'''
    
    # Use DOTALL flag to match across lines
    new_content = re.sub(old_pattern, new_code, content, flags=re.DOTALL)
    
    if new_content != content:
        # Backup original
        with open(f"{migration_file}.bak", 'w') as f:
            f.write(content)
        
        # Write patched version
        with open(migration_file, 'w') as f:
            f.write(new_content)
        
        print("Patched migration 005 to check if columns exist before adding")
    else:
        # Try a simpler pattern match
        # Just insert check before add_fields call
        pattern = r'(def migrate_external\(migrator: Migrator, database: pw\.Database, \*, fake=False\):\s+"""Write your migrations here\."""\s+# Adding fields created_at and updated_at)'
        replacement = r'''def migrate_external(migrator: Migrator, database: pw.Database, *, fake=False):
    """Write your migrations here."""
    # PATCHED_BY_AIXCL: Check if columns already exist
    try:
        result = database.execute_sql(
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'chat' AND column_name IN ('created_at', 'updated_at')"
        )
        if result.fetchone()[0] >= 2:
            return  # Columns already exist
    except:
        pass
    # Adding fields created_at and updated_at'''
        
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        if new_content != content:
            with open(f"{migration_file}.bak", 'w') as f:
                f.write(content)
            with open(migration_file, 'w') as f:
                f.write(new_content)
            print("Patched migration 005 (method 2)")
        else:
            print("Warning: Could not patch migration 005")
        
except Exception as e:
    print(f"Warning: Could not patch migration 005: {e}")
PYTHON_PATCH
fi

# Patch Alembic migration if needed  
if [ -f "/app/backend/patch_alembic_migration.sh" ]; then
    bash /app/backend/patch_alembic_migration.sh 2>/dev/null || true
fi

# Ensure migration history is properly set before Open WebUI starts
# This fixes issues where migrations are marked complete but peewee still tries to run them
python3 << 'PYTHON_SCRIPT' 2>/dev/null || true
import os
import sys

try:
    import psycopg2
except ImportError:
    sys.exit(0)

# Get database URL from environment
db_url = os.environ.get('DATABASE_URL', '').replace('postgresql://', 'postgres://')
if not db_url or 'postgres' not in db_url:
    sys.exit(0)

try:
    # Parse connection string: postgres://user:password@host:port/database
    url_part = db_url.replace('postgres://', '')
    if '@' in url_part:
        auth, location = url_part.split('@', 1)
        if ':' in auth:
            user, password = auth.split(':', 1)
        else:
            user, password = auth, ''
        
        if '/' in location:
            host_port, database = location.split('/', 1)
            host, port = (host_port.split(':', 1) + ['5432'])[:2]
        else:
            host, port, database = location, '5432', 'postgres'
        
        conn = psycopg2.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=database,
            connect_timeout=5
        )
        cur = conn.cursor()
        
        # Ensure all early migrations are marked complete if columns exist
        cur.execute("""
            -- Migration 005: if created_at and updated_at exist, mark as complete
            INSERT INTO peewee_migrate_history (name, migrated_at) 
            SELECT '005_add_updated_at', CURRENT_TIMESTAMP
            WHERE EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'chat' AND column_name = 'created_at'
            ) AND EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'chat' AND column_name = 'updated_at'
            )
            ON CONFLICT (name) DO NOTHING;
        """)
        conn.commit()
        cur.close()
        conn.close()
except Exception:
    # Fail silently - migrations will be handled by Open WebUI
    pass
PYTHON_SCRIPT

KEY_FILE=.webui_secret_key
PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"
if test "$WEBUI_SECRET_KEY $WEBUI_JWT_SECRET_KEY" = " "; then
  echo "Loading WEBUI_SECRET_KEY from file, not provided as an environment variable."

  if ! [ -e "$KEY_FILE" ]; then
    echo "Generating WEBUI_SECRET_KEY"
    # Generate a random value to use as a WEBUI_SECRET_KEY in case the user didn't provide one.
    echo $(head -c 12 /dev/random | base64) > "$KEY_FILE"
  fi

  echo "Loading WEBUI_SECRET_KEY from $KEY_FILE"
  WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi

WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' &
webui_pid=$!
echo "Waiting for webui to start..."
while ! curl -s http://localhost:${PORT}/health > /dev/null; do
  sleep 1
done
echo "Creating admin user..."
curl \
  -X POST "http://localhost:${PORT}/api/v1/auths/signup" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{ \"email\": \"${OPENWEBUI_EMAIL}\", \"password\": \"${OPENWEBUI_PASSWORD}\", \"name\": \"Admin\" }"
echo "Shutting down webui..."
kill $webui_pid



WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*'