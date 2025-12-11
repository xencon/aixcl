#!/usr/bin/env python3
"""Fix Alembic migration 242a2047eae0 to check for old_chat column"""

MIGRATION_FILE = "/app/backend/open_webui/migrations/versions/242a2047eae0_update_chat_table.py"

def fix_migration():
    with open(MIGRATION_FILE, 'r') as f:
        content = f.read()
    
    if '# PATCHED_BY_AIXCL' in content:
        print("Already patched")
        return
    
    # Find the section starting with "# Step 3:" and replace it
    # We need to wrap the data migration in a check for old_chat
    lines = content.split('\n')
    new_lines = []
    i = 0
    
    while i < len(lines):
        if '# Step 3:' in lines[i] and 'Migrate data' in lines[i]:
            # Add Step 3 comment
            new_lines.append(lines[i])
            i += 1
            
            # Skip blank lines
            while i < len(lines) and lines[i].strip() == '':
                new_lines.append(lines[i])
                i += 1
            
            # Add our check first
            indent = '    '
            new_lines.append(f'{indent}# PATCHED_BY_AIXCL: Check if old_chat column exists')
            new_lines.append(f'{indent}connection_check = op.get_bind()')
            new_lines.append(f'{indent}inspector_check = sa.inspect(connection_check)')
            new_lines.append(f'{indent}columns_check = [col["name"] for col in inspector_check.get_columns("chat")]')
            new_lines.append('')
            new_lines.append(f'{indent}if "old_chat" in columns_check:')
            
            # Keep chat_table definition but indent it
            while i < len(lines) and not '# Step 4:' in lines[i]:
                if lines[i].strip():
                    new_lines.append('    ' + lines[i])
                else:
                    new_lines.append('    ' + lines[i])
                i += 1
            
            # Close the if block
            new_lines.append('    else:')
            new_lines.append('        print("old_chat column does not exist, skipping migration (chat already JSON)")')
            new_lines.append('')
            
            # Now handle Step 4
            if i < len(lines) and '# Step 4:' in lines[i]:
                new_lines.append(lines[i])
                i += 1
                # Skip the original drop lines
                while i < len(lines) and ('print(' in lines[i] or 'drop_column' in lines[i] or lines[i].strip() == ''):
                    i += 1
                # Add our conditional drop
                new_lines.append('    # PATCHED_BY_AIXCL: Only drop if it exists')
                new_lines.append('    if "old_chat" in columns_check:')
                new_lines.append('        print("Dropping \'old_chat\' column")')
                new_lines.append('        op.drop_column("chat", "old_chat")')
                new_lines.append('    else:')
                new_lines.append('        print("old_chat column does not exist, skipping drop")')
        else:
            new_lines.append(lines[i])
            i += 1
    
    new_content = '\n'.join(new_lines)
    
    # Backup and write
    with open(f'{MIGRATION_FILE}.bak2', 'w') as f:
        f.write(content)
    
    with open(MIGRATION_FILE, 'w') as f:
        f.write(new_content)
    
    print(f"Patched {MIGRATION_FILE}")

if __name__ == "__main__":
    fix_migration()

