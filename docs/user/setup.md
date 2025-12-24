# Setup Verification Guide

This document verifies that AIXCL works out of the box for fresh deployments.

> **Note**: AIXCL follows a governance model separating Runtime Core (always enabled) from Operational Services (profile-dependent). See [`architecture/governance/`](../architecture/governance/) for architectural documentation.

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
# From project root
python3 tests/database/test_db_connection.py

# Or from llm-council directory with uv
cd llm-council
uv run python ../tests/database/test_db_connection.py
```

Expected output:
- ✅ Database connection pool created successfully
- ✅ Database schema verified/created
- ✅ Conversation creation, retrieval, and deletion tests pass

### 6. Test API Endpoints

Test the API with persistence:

```bash
# Run API integration test
python3 tests/api/test_continue_integration.py

# Or via platform test suite
./tests/platform-tests.sh --component api
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

1. **Add Models** (recommended defaults):
   ```bash
   ./aixcl models add deepseek-coder:1.3b codegemma:2b qwen2.5-coder:3b
   ```
2. **Configure Council**: 
   ```bash
   ./aixcl council configure
   # Select: Chairman: deepseek-coder:1.3b
   # Select: Council: codegemma:2b, qwen2.5-coder:3b
   ```
3. **Access Web UIs**:
   - Open WebUI: http://localhost:8080
   - pgAdmin: http://localhost:5050
   - Grafana: http://localhost:3000
4. **Configure Continue Plugin**: See README.md for Continue integration

**Recommended Default Configuration:**
- **Chairman**: `deepseek-coder:1.3b` (776MB)
- **Council Members**: `codegemma:2b` (1.6GB), `qwen2.5-coder:3b` (1.9GB)
- **Performance**: ~24s average, 68.1% keep-alive improvement, ~4.3GB VRAM

See `docs/model-recommendations.md` for alternative configurations.

## Database Configuration

AIXCL uses two PostgreSQL databases:
- **webui**: For Open WebUI conversations and data
- **continue**: For Continue plugin conversations (managed by LLM-Council)

Both databases are automatically created on startup. The webui database schema is initialized by Open WebUI when it starts.

## Notes

- All database migrations run automatically on startup
- The system gracefully degrades if database is unavailable (continues without persistence)
- Database credentials are shared with Open WebUI for simplicity
- Test scripts are organized by component under `tests/`:
  - Runtime core: `tests/runtime-core/`
  - Database: `tests/database/`
  - API: `tests/api/`
- Database utility scripts are in `scripts/db/`

