#!/bin/bash
# Patch Alembic migration 242a2047eae0 to handle case where old_chat doesn't exist
# because chat column is already JSONB

MIGRATION_FILE="/app/backend/open_webui/migrations/versions/242a2047eae0_update_chat_table.py"

if [ -f "$MIGRATION_FILE" ] && ! grep -q "# PATCHED_BY_AIXCL" "$MIGRATION_FILE" 2>/dev/null; then
    python3 << 'PYTHON'
import re

migration_file = "/app/backend/open_webui/migrations/versions/242a2047eae0_update_chat_table.py"

try:
    with open(migration_file, 'r') as f:
        content = f.read()
    
    # Patch Step 3: Wrap the data migration in a check for old_chat column
    # The issue is that if chat is already JSON, the code skips the conversion
    # but still tries to migrate from old_chat which doesn't exist
    step3_pattern = r'(    # Step 3: Migrate data from .old_chat. to .chat.\s+chat_table = table\([^)]+\)\s+# - Selecting all data from the table\s+connection = op\.get_bind\(\)\s+results = connection\.execute\(select\(chat_table\.c\.id, chat_table\.c\.old_chat\)\)\s+for row in results:[^#]+connection\.execute\([^)]+\))'
    
    step3_replacement = r'''    # Step 3: Migrate data from 'old_chat' to 'chat'
    # PATCHED_BY_AIXCL: Check if old_chat column exists before migrating
    connection = op.get_bind()
    inspector_after = sa.inspect(connection)
    columns_check = [col["name"] for col in inspector_after.get_columns("chat")]
    
    if "old_chat" in columns_check:
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
    else:
        print("old_chat column does not exist, skipping data migration (chat already JSON)")'''
    
    new_content = re.sub(step3_pattern, step3_replacement, content, flags=re.DOTALL)
    
    # Patch Step 4: Only drop old_chat if it exists
    step4_pattern = r'(    # Step 4: Drop .old_chat. column\s+print\("Dropping .old_chat. column"\)\s+op\.drop_column\("chat", "old_chat"))'
    
    step4_replacement = r'''    # Step 4: Drop 'old_chat' column (only if it exists)
    # PATCHED_BY_AIXCL: Check before dropping
    if "old_chat" in columns_check:
        print("Dropping 'old_chat' column")
        op.drop_column("chat", "old_chat")
    else:
        print("old_chat column does not exist, skipping drop")'''
    
    new_content = re.sub(step4_pattern, step4_replacement, new_content, flags=re.DOTALL)
    
    if new_content != content:
        # Backup original
        with open(f"{migration_file}.bak", 'w') as f:
            f.write(content)
        
        # Write patched version
        with open(migration_file, 'w') as f:
            f.write(new_content)
        
        print(f"Successfully patched {migration_file}")
    else:
        print("Could not find pattern to patch - trying simpler approach")
        # Try a simpler fix - just wrap the problematic section
        simple_pattern = r'(\s+# - Selecting all data from the table\s+connection = op\.get_bind\(\)\s+results = connection\.execute\(select\(chat_table\.c\.id, chat_table\.c\.old_chat\)\))'
        simple_replacement = r'''
    # PATCHED_BY_AIXCL: Check if old_chat exists before migrating
    connection = op.get_bind()
    inspector_check = sa.inspect(connection)
    columns_after_check = [col["name"] for col in inspector_check.get_columns("chat")]
    
    if "old_chat" in columns_after_check:
        # - Selecting all data from the table
        results = connection.execute(select(chat_table.c.id, chat_table.c.old_chat))'''
        
        new_content = re.sub(simple_pattern, simple_replacement, content, flags=re.DOTALL)
        
        # Wrap the for loop
        loop_pattern = r'(\s+for row in results:\s+try:[^}]+connection\.execute\([^)]+\)\))'
        loop_replacement = r'''
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
    else:
        print("old_chat column does not exist, skipping data migration (chat already JSON)")'''
        
        new_content = re.sub(loop_pattern, loop_replacement, new_content, flags=re.DOTALL)
        
        # Fix drop column
        drop_pattern = r'(\s+# Step 4: Drop .old_chat. column\s+print\("Dropping .old_chat. column"\)\s+op\.drop_column\("chat", "old_chat"))'
        drop_replacement = r'''
    # Step 4: Drop 'old_chat' column (only if it exists)
    if "old_chat" in columns_after_check:
        print("Dropping 'old_chat' column")
        op.drop_column("chat", "old_chat")
    else:
        print("old_chat column does not exist, skipping drop")'''
        
        new_content = re.sub(drop_pattern, drop_replacement, new_content, flags=re.DOTALL)
        
        if new_content != content:
            with open(f"{migration_file}.bak", 'w') as f:
                f.write(content)
            with open(migration_file, 'w') as f:
                f.write(new_content)
            print(f"Successfully patched {migration_file} (simple method)")
        else:
            print("Could not patch - patterns not found")
        
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON
fi
