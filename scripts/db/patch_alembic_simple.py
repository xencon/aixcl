#!/usr/bin/env python3
"""Simple patch for Alembic migration 242a2047eae0"""
import re

MIGRATION_FILE = "/app/backend/open_webui/migrations/versions/242a2047eae0_update_chat_table.py"

def patch_migration():
    try:
        with open(MIGRATION_FILE, 'r') as f:
            content = f.read()
        
        if '# PATCHED_BY_AIXCL' in content:
            print("Already patched")
            return True
        
        # Find and replace the problematic section
        # We need to wrap Step 3 and Step 4 in a check for old_chat column
        pattern = r'(    # Step 3: Migrate data from .old_chat. to .chat.\s+chat_table = table\([^)]+\)\s+# - Selecting all data from the table\s+connection = op\.get_bind\(\)\s+results = connection\.execute\(select\(chat_table\.c\.id, chat_table\.c\.old_chat\)\)\s+for row in results:[^#]+connection\.execute\([^)]+\)\)\s+# Step 4: Drop .old_chat. column\s+print\("Dropping .old_chat. column"\)\s+op\.drop_column\("chat", "old_chat"))'
        
        replacement = r'''    # Step 3: Migrate data from 'old_chat' to 'chat'
    # PATCHED_BY_AIXCL: Check if old_chat column exists before migrating
    connection = op.get_bind()
    inspector_check = sa.inspect(connection)
    columns_after_check = [col["name"] for col in inspector_check.get_columns("chat")]
    
    if "old_chat" in columns_after_check:
        chat_table = table(
            "chat",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("old_chat", sa.Text()),
            sa.Column("chat", sa.JSON()),
        )
        # - Selecting all data from the table
        results = connection.execute(select(chat_table.c.id, chat_table.c.old_chat))
        for row in results:
            try:
                # Convert text JSON to actual JSON object, assuming the text is in JSON format
                json_data = json.loads(row.old_chat)
            except json.JSONDecodeError:
                json_data = None  # Handle cases where the text cannot be converted to JSON

            connection.execute(
                sa.update(chat_table)
                .where(chat_table.c.id == row.id)
                .values(chat=json_data)
            )
        # Step 4: Drop 'old_chat' column
        print("Dropping 'old_chat' column")
        op.drop_column("chat", "old_chat")
    else:
        print("old_chat column does not exist, skipping migration (chat already JSON)")'''
        
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        
        if new_content != content:
            # Backup
            with open(f"{MIGRATION_FILE}.bak", 'w') as f:
                f.write(content)
            
            # Write patched
            with open(MIGRATION_FILE, 'w') as f:
                f.write(new_content)
            
            print(f"Successfully patched {MIGRATION_FILE}")
            return True
        else:
            print("Pattern not found")
            return False
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    patch_migration()

