#!/usr/bin/env python3
"""Patch Open WebUI migration 005 to check if columns exist before adding them."""
import re
import sys

MIGRATION_FILE = "/app/backend/open_webui/internal/migrations/005_add_updated_at.py"

def patch_migration():
    try:
        with open(MIGRATION_FILE, 'r') as f:
            content = f.read()
        
        # Check if already patched
        if "# PATCHED_BY_AIXCL" in content:
            return True
        
        # Pattern: find the migrate_external function definition
        # Insert check before adding fields
        pattern = r'(def migrate_external\(migrator: Migrator, database: pw\.Database, \*, fake=False\):\s+)'
        
        replacement = r'''\1# PATCHED_BY_AIXCL: Check if columns exist before adding
    try:
        result = database.execute_sql(
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'chat' AND column_name IN ('created_at', 'updated_at')"
        )
        count = result.fetchone()[0] if result else 0
        if count >= 2:
            return  # Columns already exist, skip migration
    except Exception:
        pass  # If check fails, proceed with migration attempt

'''
        
        new_content = re.sub(pattern, replacement, content)
        
        if new_content != content:
            # Backup original
            with open(f"{MIGRATION_FILE}.bak", 'w') as f:
                f.write(content)
            
            # Write patched version
            with open(MIGRATION_FILE, 'w') as f:
                f.write(new_content)
            
            print(f"Successfully patched {MIGRATION_FILE}")
            return True
        else:
            print("Pattern not found in migration file")
            return False
            
    except Exception as e:
        print(f"Error patching migration: {e}")
        return False

if __name__ == "__main__":
    success = patch_migration()
    sys.exit(0 if success else 1)

