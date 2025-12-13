#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

# Secret key management
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

# Automated login: Create admin user if OPENWEBUI_EMAIL and OPENWEBUI_PASSWORD are set
if [ -n "$OPENWEBUI_EMAIL" ] && [ -n "$OPENWEBUI_PASSWORD" ]; then
    echo "Setting up automated login for: $OPENWEBUI_EMAIL"
    python3 << 'AUTOMATED_LOGIN' 2>/dev/null || true
import os
import sys
import time

try:
    import psycopg2
    from passlib.context import CryptContext
except ImportError:
    sys.exit(0)

# Get database URL and credentials from environment
db_url = os.environ.get('DATABASE_URL', '').replace('postgresql://', 'postgres://')
email = os.environ.get('OPENWEBUI_EMAIL', '')
password = os.environ.get('OPENWEBUI_PASSWORD', '')

if not db_url or 'postgres' not in db_url or not email or not password:
    sys.exit(0)

try:
    # Parse connection string
    url_part = db_url.replace('postgres://', '')
    if '@' in url_part:
        auth, location = url_part.split('@', 1)
        if ':' in auth:
            user, db_password = auth.split(':', 1)
        else:
            user, db_password = auth, ''
        
        if '/' in location:
            host_port, database = location.split('/', 1)
            host, port = (host_port.split(':', 1) + ['5432'])[:2]
        else:
            host, port, database = location, '5432', 'postgres'
        
        # Wait for database to be ready
        max_retries = 10
        for i in range(max_retries):
            try:
                conn = psycopg2.connect(
                    host=host,
                    port=port,
                    user=user,
                    password=db_password,
                    database=database,
                    connect_timeout=5
                )
                break
            except psycopg2.OperationalError:
                if i < max_retries - 1:
                    time.sleep(2)
                    continue
                else:
                    sys.exit(0)
        
        cur = conn.cursor()
        
        # Check if user table exists
        cur.execute("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables 
                WHERE table_name = 'user'
            );
        """)
        user_table_exists = cur.fetchone()[0]
        
        if not user_table_exists:
            print("User table does not exist yet - cannot create admin user")
            conn.close()
            sys.exit(0)
        
        # Check if user already exists
        cur.execute('SELECT id FROM "user" WHERE email = %s', (email,))
        existing_user = cur.fetchone()
        
        if existing_user:
            print(f"User {email} already exists, skipping creation")
            conn.close()
            sys.exit(0)
        
        # Hash password
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        hashed_password = pwd_context.hash(password)
        
        # Generate user ID (UUID format)
        import uuid
        user_id = str(uuid.uuid4())
        
        # Create admin user
        cur.execute("""
            INSERT INTO "user" (id, email, password_hash, name, role, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, EXTRACT(EPOCH FROM NOW())::BIGINT * 1000, EXTRACT(EPOCH FROM NOW())::BIGINT * 1000)
            ON CONFLICT (email) DO NOTHING
        """, (user_id, email, hashed_password, email.split('@')[0], 'admin'))
        
        if cur.rowcount > 0:
            print(f"✅ Created admin user: {email}")
            conn.commit()
        else:
            print(f"User {email} already exists or creation failed")
        
        cur.close()
        conn.close()
        
except Exception as e:
    print(f"Warning: Automated login setup had issues: {e}")
    pass
AUTOMATED_LOGIN
fi

# Start production WebUI server
echo "Starting production WebUI server..."
export WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY"
exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*'
