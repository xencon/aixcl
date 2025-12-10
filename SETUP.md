# Setup Verification Guide

This document verifies that AIXCL works out of the box for fresh deployments.

## Fresh Installation Checklist

### 1. Prerequisites
- [ ] Docker and Docker Compose installed
- [ ] Minimum 16 GB RAM available
- [ ] Minimum 128 GB free disk space
- [ ] (Optional) NVIDIA GPU with drivers for GPU acceleration

### 2. Initial Setup

```bash
# Clone the repository
git clone https://github.com/xencon/aixcl.git
cd aixcl

# Check system requirements
./aixcl check-env

# Start services (automatically creates .env from .env.example if it exists)
./aixcl start
```

### 3. Automatic Configuration

The following are configured automatically:

- ✅ **Environment File**: `.env` is created from `.env.example` if it exists
- ✅ **Database Schema**: PostgreSQL schema is created automatically on first startup
- ✅ **pgAdmin Configuration**: Database server connection is auto-configured
- ✅ **Database Persistence**: LLM-Council conversations are automatically stored in PostgreSQL

### 4. Database Persistence Verification

After starting services, verify database persistence is working:

```bash
# Check if database schema was created
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -c "\d chat"

# Should show the chat table with columns:
# - id (uuid)
# - title (text)
# - chat (jsonb)
# - meta (jsonb)
# - source (text)
# - created_at (timestamp)
# - updated_at (timestamp)
# - user_id (text)
```

### 5. Test Database Connection

Run the test script to verify everything works:

```bash
cd llm-council
python3 scripts/test/test_db_connection.py
```

Expected output:
- ✅ Database connection pool created successfully
- ✅ Database schema verified/created
- ✅ Conversation creation, retrieval, and deletion tests pass

### 6. Test API Endpoints

Test the API with persistence:

```bash
./llm-council/scripts/test/test_api.sh
```

Expected output:
- ✅ Health endpoint responds
- ✅ Chat completion creates conversation in database
- ✅ Conversation continuity works
- ✅ Deletion endpoint works

### 7. Verify Services

Check all services are running:

```bash
./aixcl status
```

Expected services:
- ✅ ollama
- ✅ open-webui
- ✅ postgres
- ✅ pgadmin
- ✅ llm-council
- ✅ prometheus
- ✅ grafana
- ✅ (and other monitoring services)

## Troubleshooting

### Database Schema Not Created

If the schema wasn't created automatically:

1. Check logs: `docker logs llm-council | grep -i database`
2. Verify `ENABLE_DB_STORAGE=true` in `.env`
3. Manually run migration:
   ```bash
   docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < llm-council/backend/migrations/001_create_chat_table.sql
   ```

### Database Connection Failed

1. Verify PostgreSQL is running: `docker ps | grep postgres`
2. Check environment variables: `docker exec llm-council env | grep POSTGRES`
3. Test connection: `docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -c "SELECT 1;"`

### Services Not Starting

1. Check Docker: `docker ps -a`
2. View logs: `./aixcl logs`
3. Check disk space: `df -h`
4. Verify ports are available: `netstat -tuln | grep -E '8000|8080|5432|5050'`

## Post-Setup

After successful setup:

1. **Add Models**: `./aixcl models add <model-name>`
2. **Configure Council**: `./aixcl council configure`
3. **Access Web UIs**:
   - Open WebUI: http://localhost:8080
   - pgAdmin: http://localhost:5050
   - Grafana: http://localhost:3000
4. **Configure Continue Plugin**: See README.md for Continue integration

## Migration from Previous Versions

If upgrading from a version without database persistence:

1. Start services normally - schema will be created automatically
2. Existing conversations in JSON files will continue to work
3. New conversations will be stored in PostgreSQL
4. To migrate existing data, use the utility scripts in `scripts/db/`

## Notes

- All database migrations run automatically on startup
- The system gracefully degrades if database is unavailable (continues without persistence)
- Database credentials are shared with Open WebUI for simplicity
- Test scripts are located in `llm-council/scripts/test/`
- Database utility scripts are in `scripts/db/`

