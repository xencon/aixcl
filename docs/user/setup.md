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
./aixcl utils check-env

# Start services (automatically creates .env from .env.example if it exists)
./aixcl stack start
```

### 3. Automatic Configuration

The following are configured automatically:

- [x] **Environment File**: `.env` is created from `.env.example` if it exists
- [x] **Database Schema**: PostgreSQL schema is created automatically on first startup
- [x] **pgAdmin Configuration**: Database server connection is auto-configured
- [x] **Database Persistence**: Open WebUI conversations are automatically stored in PostgreSQL

### 4. Database Persistence Verification

After starting services, verify database persistence is working:

```bash
# Check if database schema was created
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -c "\dt"
```

### 5. Test Database Connection

Run the test script to verify everything works:

```bash
# From project root
python3 tests/database/test_db_connection.py
```

Expected output:
- [x] Database connection pool created successfully
- [x] Database schema verified/created
- [x] Conversation creation, retrieval, and deletion tests pass

### 6. Test API Endpoints

Test the API with persistence:

```bash
# Run API integration test
# Or via platform test suite
./tests/platform-tests.sh --component api
```

Expected output:
- [x] Health endpoint responds
- [x] Chat completion works
- [x] Deletion endpoint works

### 6. Verify Services

Check all services are running:

```bash
./aixcl stack status
```

Expected services:
- [x] ollama (or other active engine)
- [x] open-webui
- [x] postgres
- [x] pgadmin
- [x] prometheus
- [x] grafana
- [x] (and other monitoring services)

## Troubleshooting

### Database Schema Not Created

If the schema wasn't created automatically:

1. Check logs: `./aixcl stack logs postgres`
2. Verify `POSTGRES_USER` and `POSTGRES_PASSWORD` in `.env`

### Database Connection Failed

1. Verify PostgreSQL is running: `docker ps | grep postgres`
2. Test connection: `docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -c "SELECT 1;"`

### Services Not Starting

1. Check Docker: `docker ps -a`
2. View logs: `./aixcl stack logs`
3. Check disk space: `df -h`
4. Verify ports are available: `netstat -tuln | grep -E '8080|5432|5050'`

## Post-Setup

After successful setup:

1. **Add Models** (recommended defaults):
   ```bash
   ./aixcl models add deepseek-coder:1.3b codegemma:2b qwen2.5-coder:3b
   ```
2. **Access Web UIs**:
   - Open WebUI: http://localhost:8080
   - pgAdmin: http://localhost:5050
   - Grafana: http://localhost:3000
3. **Configure OpenCode Plugin**: See [`README.md`](../../README.md) for OpenCode integration

## Database Configuration

AIXCL uses PostgreSQL for:
- **webui**: For Open WebUI conversations and data
- *opencode**: For OpenCode plugin conversations (when configured)

Both databases are automatically created on startup. The webui database schema is initialized by Open WebUI when it starts.

## Notes

- All database migrations run automatically on startup
- The system gracefully degrades if database is unavailable (continues without persistence)
- Database credentials are shared with Open WebUI for simplicity
- Test scripts are organized by component under `tests/`
- Database utility scripts are in `scripts/db/`
