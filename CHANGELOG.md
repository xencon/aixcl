# Changelog

All notable changes to the AIXCL project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Rootless & Podman Support**: Full support for running AIXCL in rootless environments with both Docker and Podman. Includes automated socket detection and permission handling for volumes (Fixes #498).
- **Native Multi-Registry Pulls**: Support for `hf.co/` and `huggingface.co/` URIs in the `models add` command, enabling direct pulls from Hugging Face for all supported engines (Fixes #497).
- **Podman Quadlet Generation**: New `stack export-quadlet` command to generate native Systemd unit files for robust, headless deployments (Fixes #499).
- **Integrated Model Inference Testing**: Merged prompt/response verification into the main `platform-tests.sh` suite for end-to-end reliability.

### Changed

- Renamed service/container from `orchestrator` to `orchestrator` across codebase and documentation (Fixes #433). Directory `orchestrator/` and volume path `orchestrator-data/`; display name "orchestrator". Service contract file `orchestrator.md` renamed to `orchestrator.md`; script `build_and_push_llm_orchestrator.sh` renamed to `build_and_push_orchestrator.sh`.
- Updated Open WebUI to v0.8.0 (Fixes #454)

---

## [v1.0.0-rc2] - 2026-02-07

### Summary

Release Candidate 2 for v1.0.0. This release includes 58 commits since RC1 covering refactoring, bug fixes, feature enhancements, dependency updates, and documentation improvements.

### Added

- Token usage reporting with actual Ollama counts for accurate model usage tracking
- OpenCode orchestrator YAML configuration replacing legacy agent config
- Commercial licensing documentation (`COMMERCIAL.md`)
- Explicit timeouts to platform test script API calls
- orchestrator members test timeout increase to prevent false failures

### Changed

- Consolidated duplicated code between `aixcl` CLI and lib modules
- Replaced DEBUG print statements with proper logging throughout codebase
- Removed hardcoded confidence penalty heuristics from orchestrator
- Aligned primary model confidence wording and stage 2 ranking criteria
- Defaulted orchestrator to plain text responses
- Updated Open WebUI to v0.7.2
- Bumped `wheel` dependency from 0.45.1 to 0.46.2
- Updated README with privacy emphasis and profile testing options
- Improved documentation consistency across project

### Fixed

- Guarded interactive prompts against `set -e` on EOF
- Removed duplicate database save in non-streaming chat completions path
- Aligned platform test profile messaging
- Updated command references in help messages and error output
- Removed temporary `pr-body-temp.md` file

### Documentation

- Clarified OpenCode plugin omission from `RUNTIME_CORE_SERVICES`
- Added assignee and PR labeling requirements to development workflow
- Improved overall documentation consistency

---

## [v1.0.0-rc1] - 2025-12-26

### Added

#### Governance Model and Architecture Documentation
- **Governance Framework**: Added comprehensive architectural governance model in `docs/architecture/governance/`
  - Runtime Core vs Operational Services separation
  - Service contracts defining dependencies and boundaries
  - Profile definitions (core, dev, ops, full)
  - AI guidance for preserving architectural invariants
  - Stack status specification
- **Documentation Updates**: Updated README.md, docs, and manpage to reflect governance model
- **Bash Completion**: Updated completion script to reflect service categorization

#### Database Persistence for orchestrator
- **PostgreSQL Integration**: Added automatic PostgreSQL-based storage for orchestrator conversations
  - Automatic schema creation on startup via `ensure_schema()` function
  - Migration system with `001_create_chat_table.sql` for initial schema setup
  - Support for both Open WebUI and OpenCode plugin conversations via `source` field
  - Conversation tracking with unique IDs generated from message hashes
  - Full message history preservation with stage data (Stage 1, 2, 3 responses)

- **Database Storage Module** (`orchestrator/backend/db_storage.py`):
  - `create_opencode_conversation()` - Create new OpenCode conversations
  - `get_opencode_conversation()` - Retrieve conversations by ID
  - `add_message_to_conversation()` - Add messages to existing conversations
  - `list_opencode_conversations()` - List all OpenCode conversations
  - `delete_conversation()` - Delete conversations
  - `find_conversation_by_messages()` - Find conversations by message content

- **Database Connection Management** (`orchestrator/backend/db.py`):
  - Connection pool management with asyncpg
  - Automatic schema verification and creation
  - Graceful degradation when database is unavailable
  - Environment-based configuration (ENABLE_DB_STORAGE flag)

- **Conversation Tracker** (`orchestrator/backend/conversation_tracker.py`):
  - Deterministic conversation ID generation from message hashes
  - Message entry creation with proper formatting
  - Integration with database storage

- **API Endpoints**:
  - Conversation deletion endpoint: `DELETE /v1/chat/completions/{conversation_id}`
  - Automatic conversation persistence on chat completion requests
  - Conversation ID returned in API responses

#### Testing Infrastructure
- **Test Scripts** (moved to `orchestrator/scripts/test/`):
  - `test_db_connection.py` - Comprehensive database connection and operation tests
  - `test_db_in_container.sh` - Container-based test wrapper
  - `test_api.sh` - API endpoint integration tests
  - `test_request.json` - Sample API request for testing

#### Database Utilities
- **Utility Scripts** (organized in `scripts/db/`):
  - `002_add_source_column.sql` - Migration script for adding source column to existing databases
  - `query_opencode_chats.sql` - Query script for OpenCode conversations
  - `query_all_chats.sql` - Query script for all conversations
  - `check_db.sh` - Quick database inspection script
  - `README.md` - Documentation for database utilities

#### Documentation
- Updated main `README.md` with database persistence features
- Created `orchestrator/scripts/test/README.md` with test script documentation
- Created `scripts/db/README.md` with database utility documentation
- Updated `orchestrator/TESTING.md` with new script paths and testing procedures

### Changed

#### Repository Organization
- **Script Organization**:
  - Moved SQL utility files from root to `scripts/db/` directory
  - Moved test scripts from `orchestrator/` to `orchestrator/scripts/test/` directory
  - Created logical directory structure for better maintainability

- **File Cleanup**:
  - Removed duplicate `check_opencode.sql` file (consolidated with `check_opencode_chats.sql`)
  - Organized temporary test files into appropriate directories
  - Updated all script paths in documentation

#### Configuration
- Added `ENABLE_DB_STORAGE` environment variable (default: `true`)
- Database connection uses same PostgreSQL instance as Open WebUI
- Automatic migration execution on service startup

### Technical Details

#### Database Schema
The `chat` table structure:
- `id` (UUID) - Primary key, auto-generated
- `title` (TEXT) - Conversation title
- `chat` (JSONB) - Full conversation data with messages array
- `meta` (JSONB) - Additional metadata
- `source` (TEXT) - Source identifier ('openwebui' or 'opencode')
- `created_at` (TIMESTAMP) - Creation timestamp
- `updated_at` (TIMESTAMP) - Auto-updated on changes
- `user_id` (TEXT) - Optional user identifier

Indexes created for performance:
- `idx_chat_source` - Index on source field
- `idx_chat_created_at` - Index on creation timestamp (DESC)
- `idx_chat_meta` - GIN index on metadata JSONB
- `idx_chat_user_id` - Partial index on user_id

#### Migration System
- Migrations are automatically executed on startup via `ensure_schema()`
- Migration files located in `orchestrator/backend/migrations/`
- Uses `IF NOT EXISTS` clauses for idempotent execution
- Graceful error handling for existing schemas

### Migration Guide

For existing installations upgrading to include database persistence:

1. **Automatic Migration**: The system will automatically create the schema on next startup if `ENABLE_DB_STORAGE=true`

2. **Manual Migration** (if needed):
   ```bash
   docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < orchestrator/backend/migrations/001_create_chat_table.sql
   ```

3. **Adding Source Column** (for databases created before source column was added):
   ```bash
   docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < scripts/db/002_add_source_column.sql
   ```

### Breaking Changes

None - This is a backward-compatible addition. Existing functionality remains unchanged.

### Deprecated

None

### Removed

- Removed duplicate `check_opencode.sql` file (functionality preserved in `check_opencode_chats.sql`)

### Fixed

- Fixed script paths in test scripts after reorganization
- Updated documentation references to reflect new script locations

### Security

- Database credentials are managed via environment variables
- Connection pooling with configurable pool size
- Graceful degradation when database is unavailable (service opencodes without persistence)

