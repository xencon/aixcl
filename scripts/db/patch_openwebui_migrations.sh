#!/bin/bash
# Patch Open WebUI's db.py to handle migration errors gracefully
# This patches the handle_peewee_migration function to catch "already exists" errors
# Usage: This is called automatically by openwebui.sh

DB_PY_FILE="/app/backend/open_webui/internal/db.py"

if [ -f "$DB_PY_FILE" ]; then
    # Check if already patched
    if ! grep -q "# PATCHED_BY_AIXCL" "$DB_PY_FILE"; then
        echo "Patching Open WebUI db.py to handle migration errors..."
        
        # Create a Python script to patch the file
        python3 << 'PYTHON_PATCH'
import re

db_py_file = "/app/backend/open_webui/internal/db.py"

try:
    with open(db_py_file, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if "# PATCHED_BY_AIXCL" in content:
        print("Already patched")
        exit(0)
    
    # Find the handle_peewee_migration function and patch it
    # We'll wrap router.run() in a try-except that catches "already exists" errors
    pattern = r'(def handle_peewee_migration\(DATABASE_URL\):.*?router\.run\(\))(.*?finally:)'
    
    replacement = r'''\1
        # PATCHED_BY_AIXCL: Catch migration errors for columns that already exist
        try:
            router.run()
        except Exception as mig_error:
            error_str = str(mig_error).lower()
            # If column already exists, that's okay - migration was already applied
            if "already exists" in error_str or "duplicate" in error_str:
                log.warning(f"Migration skipped - columns already exist: {mig_error}")
                # Mark all migrations as complete to prevent retries
                try:
                    from peewee_migrate import Router
                    migrate_dir = OPEN_WEBUI_DIR / "internal" / "migrations"
                    check_router = Router(db, logger=log, migrate_dir=migrate_dir)
                    for mig_name in check_router.todo:
                        db.execute_sql(
                            "INSERT INTO peewee_migrate_history (name, migrated_at) "
                            "VALUES (%s, CURRENT_TIMESTAMP) "
                            "ON CONFLICT (name) DO NOTHING",
                            (mig_name,)
                        )
                except:
                    pass
            else:
                raise\2'''
    
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    if new_content != content:
        # Backup original
        with open(f"{db_py_file}.bak", 'w') as f:
            f.write(content)
        
        # Write patched version
        with open(db_py_file, 'w') as f:
            f.write(new_content)
        
        print("Successfully patched db.py")
    else:
        print("Could not find pattern to patch")
        exit(1)
        
except Exception as e:
    print(f"Error patching file: {e}")
    exit(1)
PYTHON_PATCH
    fi
fi

