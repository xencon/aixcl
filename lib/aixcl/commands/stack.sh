#!/usr/bin/env bash
# Stack management commands for AIXCL

# Container name for Open WebUI - must match docker-compose service name
readonly CONTAINER_NAME="open-webui"

_print_stopped_status() {
    local profile="$1"
    echo ""
    echo "AIXCL Stack Stopped"
    echo "==================="
    echo ""
    echo "Profile: $profile"
    echo "Status: Stopped"
    echo ""
    echo "Services"
    echo "--------------------------------------------------"
    echo ""
    echo "Runtime Core"
    for service in "${RUNTIME_CORE_SERVICES[@]}"; do
        echo "  ❌ $service"
    done
    echo ""
    echo "Operational Services"
    local profile_services
    profile_services=$(get_profile_services "$profile" 2>/dev/null) || true
    for service in $profile_services; do
        local is_core=false
        for core in "${RUNTIME_CORE_SERVICES[@]}"; do
            [ "$service" = "$core" ] && is_core=true && break
        done
        [ "$is_core" = true ] && continue
        echo "  ❌ $service"
    done
    echo ""
    echo "All services have been stopped."
}

function ensure_databases() {
    # Ensure required databases exist (webui)
    # This function is idempotent - it won't fail if databases already exist
    # 
    # NOTE: PostgreSQL init scripts in scripts/db/init/ now create the database
    # on first container startup. This function serves as a fallback for:
    # - Edge cases where init scripts didn't run (e.g., volume already had data)
    # - Database recreation scenarios
    # - Manual database provisioning if needed
    
    # Load environment variables if not already loaded
    if [ -z "${POSTGRES_USER:-}" ]; then
        if [ -f "${SCRIPT_DIR}/.env" ]; then
            load_env_file "${SCRIPT_DIR}/.env"
        fi
    fi
    
    # Set defaults
    local pg_user
    pg_user="${POSTGRES_USER:-admin}"
    local webui_db
    webui_db="${POSTGRES_DATABASE:-webui}"
    
    # Validate database names to prevent SQL injection
    if ! validate_db_name "$webui_db" "webui"; then
        echo "   Invalid webui database name, skipping database creation"
        return 1
    fi
    
    
    # Check if postgres container is running
    if ! "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -q "^postgres$"; then
        echo "   PostgreSQL container is not running, skipping database creation"
        return 0
    fi
    
    # Wait for PostgreSQL to be ready
    local pg_ready
    pg_ready=false
    for i in {1..20}; do
        if timeout 2 "${DOCKER_BIN:-docker}" exec postgres pg_isready -U "$pg_user" >/dev/null 2>&1; then
            pg_ready=true
            break
        fi
        echo "   Waiting for PostgreSQL to accept connections... ($i/20)"
        sleep 1
    done

    if [ "$pg_ready" = false ]; then
        echo "   PostgreSQL is not ready, skipping database creation"
        return 0
    fi
    echo "   PostgreSQL ready. Checking databases..."

    # Create webui database if it doesn't exist
    if "${DOCKER_BIN:-docker}" exec -e PGPASSWORD="${POSTGRES_PASSWORD:-}" postgres psql -U "$pg_user" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$webui_db"; then
        echo "WebUI database already exists: $webui_db"
    else
        echo "Creating webui database: $webui_db"
        "${DOCKER_BIN:-docker}" exec -e PGPASSWORD="${POSTGRES_PASSWORD:-}" postgres psql -U "$pg_user" -d postgres -c "CREATE DATABASE \"$webui_db\";" >/dev/null 2>&1 || true
    fi
    
    
    # Remove unwanted "admin" database if it exists and is not the intended database
    # PostgreSQL may create an "admin" database when POSTGRES_USER=admin but POSTGRES_DATABASE is not set
    if [ "$webui_db" != "admin" ]; then
        if "${DOCKER_BIN:-docker}" exec -e PGPASSWORD="${POSTGRES_PASSWORD:-}" postgres psql -U "$pg_user" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "admin"; then
            echo "Removing unwanted admin database..."
            "${DOCKER_BIN:-docker}" exec -e PGPASSWORD="${POSTGRES_PASSWORD:-}" postgres psql -U "$pg_user" -d postgres -c "DROP DATABASE IF EXISTS \"admin\";" >/dev/null 2>&1 || true
            echo "   Admin database removed(only webui database should exist)"
        fi
    fi
}

function init_stack() {
    echo "AIXCL Stack Initialisation"
    echo "=========================="
    echo ""

    local env_file="${SCRIPT_DIR}/.env"
    local env_example="${SCRIPT_DIR}/config/.env.example"

    # Check if already initialized
    if [ -f "${SCRIPT_DIR}/.aixcl.initialized" ]; then
        echo "Already initialised. To re-initialise, remove .aixcl.initialized"
        return 1
    fi

    # Create .env from example if not exists
    if [ ! -f "$env_file" ]; then
        if [ -f "$env_example" ]; then
            cp "$env_example" "$env_file"
            echo "Created .env from .env.example"
        else
            echo "Error: .env.example not found"
            return 1
        fi
    fi

    # Create opencode.json from example if not exists
    local opencode_file="${SCRIPT_DIR}/opencode.json"
    local opencode_example="${SCRIPT_DIR}/config/opencode.json.example"
    if [ ! -f "$opencode_file" ]; then
        if [ -f "$opencode_example" ]; then
            cp "$opencode_example" "$opencode_file"
            echo "Created opencode.json from config/opencode.json.example"
        else
            echo "Warning: config/opencode.json.example not found, skipping opencode.json creation"
        fi
    fi

    # Load current values
    load_env_file "$env_file"

    # Prompt for username (no default)
    echo ""
    while true; do
        read -r -p "Enter admin username: " AIXCL_ADMIN_USER
        if [ -n "$AIXCL_ADMIN_USER" ]; then
            break
        fi
        echo "Username is required."
    done

    # Prompt for email (no default)
    echo ""
    while true; do
        read -r -p "Enter admin email: " AIXCL_ADMIN_EMAIL
        if echo "$AIXCL_ADMIN_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
            break
        fi
        echo "A valid email address is required."
    done
    # Set PostgreSQL defaults based on admin username
    local postgres_user="${AIXCL_ADMIN_USER}"
    local postgres_db="webui"

    # Update .env with values
    sed -i "s/^#\?AIXCL_ADMIN_USER=.*/AIXCL_ADMIN_USER=$AIXCL_ADMIN_USER/" "$env_file"
    sed -i "s/^#\?AIXCL_ADMIN_EMAIL=.*/AIXCL_ADMIN_EMAIL=$AIXCL_ADMIN_EMAIL/" "$env_file"
    sed -i "s/^#\?PGADMIN_DEFAULT_EMAIL=.*/PGADMIN_DEFAULT_EMAIL=$AIXCL_ADMIN_EMAIL/" "$env_file"
    sed -i "s/^#\?OPENWEBUI_EMAIL=.*/OPENWEBUI_EMAIL=$AIXCL_ADMIN_EMAIL/" "$env_file"
    sed -i "s/^#\?POSTGRES_USER=.*/POSTGRES_USER=$postgres_user/" "$env_file"
    sed -i "s/^#\?POSTGRES_DATABASE=.*/POSTGRES_DATABASE=$postgres_db/" "$env_file"

    echo ""
    echo "Initialisation complete:"
    echo "  Username: $AIXCL_ADMIN_USER"
    echo "  Email: $AIXCL_ADMIN_EMAIL"
    echo "  PostgreSQL user: $postgres_user"
    echo "  PostgreSQL database: $postgres_db"
    echo ""

    # Create initialized marker
    echo "username=$AIXCL_ADMIN_USER" > "${SCRIPT_DIR}/.aixcl.initialized"
    echo "email=$AIXCL_ADMIN_EMAIL" >> "${SCRIPT_DIR}/.aixcl.initialized"
    echo "created=$(date -Iseconds)" >> "${SCRIPT_DIR}/.aixcl.initialized"

    echo "Credentials will be generated on first start."
    echo "Run './aixcl stack start --profile sys' to begin."
}

function ensure_nvidia_cdi() {
    # Skip if no NVIDIA hardware or nvidia-ctk is unavailable
    if ! has_nvidia || ! command -v nvidia-ctk >/dev/null 2>&1; then
        return 0
    fi
    # Skip if CDI devices are already registered
    local cdi_count
    cdi_count=$(nvidia-ctk cdi list 2>/dev/null | grep -c 'nvidia.com' || echo 0)
    if [[ "$cdi_count" -gt 0 ]]; then
        return 0
    fi
    echo "Configuring NVIDIA CDI for GPU support..."
    if sudo mkdir -p /etc/cdi && sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null; then
        echo "[x] NVIDIA CDI configured (/etc/cdi/nvidia.yaml)"
    else
        mkdir -p "${HOME}/.config/cdi"
        if nvidia-ctk cdi generate --output="${HOME}/.config/cdi/nvidia.yaml" 2>/dev/null; then
            echo "[x] NVIDIA CDI configured (${HOME}/.config/cdi/nvidia.yaml)"
        else
            echo "   Warning: Could not configure NVIDIA CDI — GPU may not be available to containers"
            echo "   Run manually: sudo mkdir -p /etc/cdi && sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
        fi
    fi
}

function start() {
    local profile
    profile=""
    local profile_specified
    profile_specified=false
    
    # Profile library is sourced at script startup (lib/cli/profile.sh)
    
    # Parse arguments for profile
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile|-p)
                # Check if argument exists before accessing it
                if [[ $# -lt 2 ]] || [[ -z "${2:-}" ]]; then
                    echo "[ ] Error: Profile name is required after --profile" >&2
                    echo "Usage: aixcl stack start [--profile <profile>]" >&2
                    echo "" >&2
                    list_profiles >&2
                    exit 1
                fi
                profile="$2"
                profile_specified=true
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # If no profile specified via command line, try to get from .env file
    if [ "$profile_specified" = false ]; then
        local env_file="${SCRIPT_DIR}/.env"
        
        # Load .env file to check for PROFILE variable
        if [ -f "$env_file" ]; then
            # Read PROFILE from .env file
            local env_profile
            env_profile=$(grep -E "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null | head -1 | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
            
            if [ -n "$env_profile" ]; then
                profile="$env_profile"
                echo "   Using profile from .env file: $profile"
            fi
        fi
        
        # If still no profile, show available profiles and prompt
        if [ -z "$profile" ]; then
            # Ensure VALID_PROFILES is defined
            if [ -z "${VALID_PROFILES+x}" ] || [ ${#VALID_PROFILES[@]} -eq 0 ]; then
                echo "[ ] Error: Profile definitions not loaded. VALID_PROFILES is not set." >&2
                echo "   Expected profile library at: ${SCRIPT_DIR}/lib/cli/profile.sh" >&2
                exit 1
            fi
            
            echo "Available profiles:"
            echo "==================="
            echo ""
            local profile_index=1
            for valid_profile in "${VALID_PROFILES[@]}"; do
                echo "  [$profile_index] $valid_profile: $(get_profile_description "$valid_profile")"
                ((profile_index++))
            done
            echo ""
            echo "Usage: ./aixcl stack start [--profile <profile>]"
            echo "       ./aixcl stack start -p <profile>"
            echo "       ./aixcl stack start                 # Uses PROFILE from .env file if set"
            echo ""
            echo "Note: Set PROFILE=<profile> in .env file to use a default profile"
            echo ""
            echo "Examples:"
            echo "  ./aixcl stack start --profile bld    # Observability-focused (monitoring/logging)"
            echo "  ./aixcl stack start --profile sys    # System-oriented (complete stack)"
            echo ""
            echo "For detailed profile information, see: docs/architecture/governance/02_profiles.md"
            exit 0
        fi
    fi
    
    # Validate profile
    if ! is_valid_profile "$profile"; then
        echo "[ ] Error: Invalid profile: $profile" >&2
        echo "Valid profiles: bld, sys (default: sys)"
        echo ""
        list_profiles
        exit 1
    fi
    
    # Save profile to .env file if it was specified via command line (and differs from .env)
    if [ "$profile_specified" = true ]; then
        local env_file="${SCRIPT_DIR}/.env"
        if [ -f "$env_file" ]; then
            local current_env_profile
            current_env_profile=$(grep -E "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null | head -1 | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
            if [ "$current_env_profile" != "$profile" ]; then
                # Update or add PROFILE in .env file
                if grep -qE "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null; then
                    # Update existing PROFILE line
                    sed -i "s/^[[:space:]]*PROFILE[[:space:]]*=.*/PROFILE=$profile/" "$env_file"
                else
                    # Add PROFILE line at the end
                    {
                        echo ""
                        echo "# Default profile for stack commands"
                        echo "PROFILE=$profile"
                    } >> "$env_file"
                fi
                echo "   Saved profile to .env file: $profile"
            fi
        fi
    fi
    
    echo "Starting services with profile: $profile"
    print_profile_info "$profile"
    
    # Check for .env file and restore from backup or create from .env.example if missing
    # Use SCRIPT_DIR to ensure we're looking in the correct location
    local env_file="${SCRIPT_DIR}/.env"
    local env_example="${SCRIPT_DIR}/config/.env.example"
    local env_backup_volume="aixcl-env-backup"
    
    # NEVER overwrite existing .env file (preserves user configuration)
    if [ -f "$env_file" ]; then
        echo "[x] Using existing .env file (preserving user configuration)"
        load_env_file "$env_file"
    else
        # Try to restore from backup volume first
        if "${DOCKER_BIN:-docker}" volume ls --format "{{.Name}}" | grep -q "^${env_backup_volume}$"; then
            echo "   .env file not found. Attempting to restore from backup..."
            # Restore .env from backup volume using a temporary container
            # Use current user's UID/GID to ensure proper ownership
            local current_uid
            current_uid=$(id -u)
            local current_gid
            current_gid=$(id -g)
            if "${DOCKER_BIN:-docker}" run --rm \
                --user "${current_uid}:${current_gid}" \
                -v "${env_backup_volume}:/backup:ro" \
                -v "${SCRIPT_DIR}:/target" \
                alpine sh -c "test -f /backup/.env && cp /backup/.env /target/.env && chmod 600 /target/.env" >/dev/null 2>&1; then
                if [ -f "$env_file" ]; then
                    # Fix ownership and permissions if file was created by root
                    if [ -O "$env_file" ] || [ -w "$env_file" ]; then
                        chmod 600 "$env_file" 2>/dev/null || true
                        echo "[x] Restored .env file from backup volume: $env_backup_volume"
                        load_env_file "$env_file"
                    else
                        # File exists but we don't have permission - try to fix ownership
                        echo "   Restored .env file but fixing ownership..."
                        sudo chown "${current_uid}:${current_gid}" "$env_file" 2>/dev/null || {
                            echo "[ ] Error: Cannot fix .env file ownership. Please run: sudo chown $(whoami):$(whoami) $env_file"
                            exit 1
                        }
                        chmod 600 "$env_file" 2>/dev/null || true
                        echo "[x] Restored .env file from backup volume: $env_backup_volume"
                        load_env_file "$env_file"
                    fi
                else
                    echo "   Backup exists but restoration failed, creating from .env.example..."
                fi
            else
                echo "   Backup volume exists but .env not found in backup, creating from .env.example..."
            fi
        fi
        
        # If still no .env file, create from .env.example
        if [ ! -f "$env_file" ]; then
            if [ -f "$env_example" ]; then
                echo "   .env file not found. Copying from .env.example..."
                cp "$env_example" "$env_file"
                echo "[x] Created .env file from .env.example"
                
                # If profile was specified via CLI, update .env to match
                if [ "$profile_specified" = true ] && [ -n "$profile" ]; then
                    if grep -qE "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null; then
                        # Update existing PROFILE line
                        if [[ "$(uname)" == "Darwin" ]]; then
                            sed -i '' "s/^[[:space:]]*PROFILE[[:space:]]*=.*/PROFILE=$profile/" "$env_file"
                        else
                            sed -i "s/^[[:space:]]*PROFILE[[:space:]]*=.*/PROFILE=$profile/" "$env_file"
                        fi
                    else
                        # Add PROFILE line at the end
                        {
                            echo ""
                            echo "# Default profile for stack commands"
                            echo "PROFILE=$profile"
                        } >> "$env_file"
                    fi
                    echo "   Updated PROFILE in .env to match CLI: $profile"
                fi
                
                # Reload environment variables after creating .env file
                load_env_file "$env_file"
            else
                echo "[ ] Error: Neither .env nor .env.example file found"
                echo "   Expected .env.example at: $env_example"
                echo "   Please create a .env file with the required configuration"
                exit 1
            fi
        fi
    fi
    
    # Check if llamacpp engine is selected and verify model exists
    # This prevents container restart loops when no model is configured
    if [ "${INFERENCE_ENGINE:-ollama}" = "llamacpp" ]; then
        echo "Checking llamacpp model configuration..."
        local llama_model="${INFERENCE_MODEL:-}"
        
        if [ -z "$llama_model" ]; then
            echo "[ ] Error: No model configured for llamacpp engine"
            echo "   INFERENCE_MODEL is not set in .env file"
            echo ""
            echo "   To add a model, run:"
            echo "      ./aixcl models add <path/to/model.gguf>"
            echo ""
            echo "   Example:"
            echo "      ./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
            echo ""
            exit 1
        fi
        
        # Check if model file exists in the llamacpp-data volume
        local model_basename
        model_basename=$(basename "$llama_model")
        
        # Check if llamacpp-data volume exists (Docker named volume)
        if "${DOCKER_BIN:-docker}" volume ls --format "{{.Name}}" | grep -q "^services_llamacpp-data$"; then
            # Check if model exists in the Docker volume
            if ! "${DOCKER_BIN:-docker}" run --rm -v "services_llamacpp-data:/models" alpine test -f "/models/${model_basename}" 2>/dev/null; then
                echo "[ ] Error: Model file not found: ${model_basename}"
                echo "   Model configured: ${llama_model}"
                echo ""
                echo "   The model must be downloaded before starting the stack."
                echo "   To add the model, run:"
                echo "      ./aixcl models add ${llama_model}"
                echo ""
                exit 1
            fi
        fi
        
        echo "[x] Llamacpp model verified: ${model_basename}"
    fi
    
    # Pre-create logs directory with correct ownership to prevent root-owned directories
    # Docker creates host directories for bind mounts using the container's user (root)
    # which causes permission issues. By pre-creating with current user, we avoid this.
    local logs_dir="${SCRIPT_DIR}/logs"
    if [ ! -d "$logs_dir" ]; then
        echo "Creating logs directory with current user ownership..."
        mkdir -p "$logs_dir"
        # Set ownership to current user
        chown "$(id -u):$(id -g)" "$logs_dir" 2>/dev/null || true
        chmod 755 "$logs_dir"
        echo "   Created logs directory"
    fi
    
    # Get services for this profile
    local profile_services
    read -r -a profile_services <<< "$(get_profile_services "$profile")"
    
    # Generate pgAdmin configuration if pgadmin is in the profile
    local has_pgadmin=false
    for service in "${profile_services[@]}"; do
        if [ "$service" = "pgadmin" ]; then
            has_pgadmin=true
            break
        fi
    done
    
    if [ "$has_pgadmin" = true ]; then
        generate_pgadmin_config
    fi
    
    # Auto-configure NVIDIA CDI if GPU is present but CDI has no devices registered
    ensure_nvidia_cdi

    # Set up compose command with GPU detection
    set_compose_cmd

    # Check if any runtime core services are running
    local core_running=false
    for service in "${RUNTIME_CORE_SERVICES[@]}"; do
        if "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -q "^${service}$"; then
            core_running=true
            break
        fi
    done
    
    if [ "$core_running" = true ]; then
        echo "   Some services are already running. Use 'stop' first if you want to restart."
        exit 1
    fi
    
    # Set profile-specific environment variables (per contract) BEFORE any docker-compose commands
    # All profiles use database storage (ENABLE_DB_STORAGE=true) for persistence
    # Export early to ensure it's available to all docker-compose commands (pull, build, up)
    ENABLE_DB_STORAGE=$(get_profile_db_storage_enabled "$profile")
    export ENABLE_DB_STORAGE
    echo "Setting ENABLE_DB_STORAGE=${ENABLE_DB_STORAGE} for profile: $profile"
    
    echo "Pulling latest images..."
    run_compose pull
    
    # Initialize external volumes if they don't exist
    # This ensures volumes are created before services try to use them
    if [ -f "${SCRIPT_DIR}/scripts/utils/init-volumes.sh" ]; then
        echo "Checking external volumes..."
        # Run the volume init script but suppress most output for clean UX
        if bash "${SCRIPT_DIR}/scripts/utils/init-volumes.sh" 2>&1 | grep -E "(Created:|Error:|Summary)"; then
            :  # Already showing the relevant lines
        else
            echo "[x] All external volumes ready"
        fi
    fi
    
    echo "Starting services for profile: $profile..."
    run_compose up -d "${profile_services[@]}"
    
    echo "Waiting for runtime core services to be ready..."
    local max_attempts
    max_attempts=300  # 10 minutes
    local attempt
    attempt=1
    local all_ready
    all_ready=false
    
    while [ $attempt -le $max_attempts ]; do
        local engine_ready
        engine_ready=false
        
        # Check Inference Engine (Ollama or OpenAI compatible API)
        if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/api/version 2>/dev/null | grep -q "200" || \
           curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/v1/models 2>/dev/null | grep -q "200"; then
            engine_ready=true
        fi
        
        if [ "$engine_ready" = true ]; then
            all_ready=true
            break
        fi
        
        echo "Waiting for runtime core services to become available... ($attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    if [ "$all_ready" = true ]; then
        echo "Runtime core services are up and running!"
        
        # For profiles that include postgres, wait for it too
        local has_postgres=false
        for service in "${profile_services[@]}"; do
            if [ "$service" = "postgres" ]; then
                has_postgres=true
                break
            fi
        done
        
        if [ "$has_postgres" = true ]; then
            echo "Waiting for PostgreSQL to be ready..."
            local pg_attempt=1
            local pg_ready=false
            while [ $pg_attempt -le 60 ]; do  # 120 seconds
                if timeout 2 "${DOCKER_BIN:-docker}" exec postgres pg_isready -U "${POSTGRES_USER:-admin}" >/dev/null 2>&1; then
                    echo "PostgreSQL is ready!"
                    pg_ready=true
                    break
                fi
                echo "Waiting for PostgreSQL... ($pg_attempt/60)"
                sleep 2
                pg_attempt=$((pg_attempt + 1))
            done
            
            # Ensure required databases exist
            if [ "$pg_ready" = true ]; then
                echo "Ensuring required databases exist..."
                ensure_databases
            fi
        fi
        
        # Check if Vault is in the profile and prompt user to initialize
        local has_vault=false
        for service in "${profile_services[@]}"; do
            if [ "$service" = "vault" ]; then
                has_vault=true
                break
            fi
        done
        
        if [ "$has_vault" = true ]; then
            echo ""
            echo "Vault is running. Auto-initializing..."
            echo ""
            
            local vault_init_script="${SCRIPT_DIR}/lib/aixcl/commands/vault-init.sh"
            if [ -f "$vault_init_script" ]; then
                # Run vault init directly — vault-init.sh waits for Vault internally
                # and generates all bootstrap passwords itself. No pre-poll needed.
                if bash "$vault_init_script" 2>&1 | grep -E "\[INFO\]|\[WARN\]|\[ERROR\]"; then
                    echo ""
                    echo "Vault initialization complete."
                else
                    echo ""
                    echo "Vault initialization encountered issues. Run manually:"
                    echo "  ./aixcl vault init"
                fi
                
                # Show current passwords
                echo ""
                echo "Retrieving bootstrap passwords..."
                echo ""
                bash "${SCRIPT_DIR}/scripts/vault/vault-commands.sh" passwords 2>/dev/null || echo "  Run './aixcl vault passwords' to view"
            else
                echo ""
                echo "Vault initialization script not found. Run manually:"
                echo "  ./aixcl vault init"
                echo ""
            fi
            
            echo ""
            echo "Check status with:"
            echo "  ./aixcl vault status"
            echo ""
        fi

        # Wait for all services to pass their health checks before printing final status.
        # Open WebUI and pgAdmin can take 60-120s after Vault init.
        local hw_attempt=0
        local hw_max=36  # 3 minutes at 5s intervals
        echo "Waiting for all services to be healthy..."
        while [ $hw_attempt -lt $hw_max ]; do
            local still_starting
            still_starting=$("${DOCKER_BIN:-podman}" ps --format "{{.Status}}" 2>/dev/null | grep -cE "\(health: starting\)|\(unhealthy\)" || true)
            if [ "${still_starting:-0}" -eq 0 ]; then
                break
            fi
            printf "  %d service(s) still starting... (%ds/%ds)\r" "$still_starting" "$((hw_attempt * 5))" "$((hw_max * 5))"
            sleep 5
            hw_attempt=$((hw_attempt + 1))
        done
        echo ""

        status
        return 0
    else
        echo "[ ] Error: Runtime core services did not start properly within timeout period"
        status
        exit 1
    fi
}

function stop() {
    [ "${AIXCL_VERBOSE:-0}" = "1" ] && echo "Stopping Docker Compose deployment..."
    
    # Get current profile from .env file
    local profile=""
    local env_file="${SCRIPT_DIR}/.env"
    if [ -f "$env_file" ]; then
        profile=$(grep -E "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null | head -1 | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
    fi
    [ -z "$profile" ] && profile="sys"
    
    # Set up compose command with GPU detection
    set_compose_cmd
    
    # Join ALL_SERVICES with | for grep
    local all_services_pattern
    all_services_pattern=$(IFS="|"; echo "${ALL_SERVICES[*]}")
    if ! "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -qE "$CONTAINER_NAME|$all_services_pattern"; then
        _print_stopped_status "$profile"
        return 0
    fi
    
    echo "Stopping services gracefully..."
    # Allow down to fail (containers may not exist) - we check status after
    run_compose down --remove-orphans || true
    
    echo "Waiting for containers to stop..."
    for i in {1..30}; do
        if ! "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -qE "$CONTAINER_NAME|$all_services_pattern"; then
            _print_stopped_status "$profile"
            return 0
        fi
        echo "Waiting for services to stop... ($i/15)"
        sleep 2
    done
    
    echo "Warning: Services did not stop gracefully. Forcing shutdown..."
    run_compose down --remove-orphans -v
    "${DOCKER_BIN:-docker}" ps -q | xargs -r "${DOCKER_BIN:-docker}" stop
    
    _print_stopped_status "$profile"

    # Clean up pgAdmin configuration file for security
    if [ -f "pgadmin-servers.json" ]; then
        rm -f pgadmin-servers.json
        echo "   Cleaned up pgAdmin configuration file"
    fi
}

function restart() {
    local profile
    profile=""
    local profile_specified
    profile_specified=false
    
    # Profile library is sourced at script startup (lib/cli/profile.sh)
    
    # Parse arguments for profile and service names
    local service_names=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile|-p)
                if [[ $# -lt 2 ]] || [[ -z "${2:-}" ]]; then
                    echo "[ ] Error: Profile name is required after --profile" >&2
                    echo "Usage: aixcl stack restart [--profile <profile>] [service1] [service2] ..." >&2
                    echo "" >&2
                    list_profiles >&2
                    exit 1
                fi
                profile="$2"
                profile_specified=true
                shift 2
                ;;
            *)
                service_names+=("$1")
                shift
                ;;
        esac
    done
    
    # Check if remaining args are service names (not profile flags)
    # If they are valid service names, treat them as services to restart
    if [ ${#service_names[@]} -gt 0 ]; then
        # Source common library for service validation
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/lib/core/common.sh"
        
        # Check if any remaining args are valid service names
        for arg in "${service_names[@]}"; do
            # Resolve 'engine' alias to active INFERENCE_ENGINE
            local service_to_check="$arg"
            if [[ "$arg" == "engine" ]]; then
                service_to_check="${INFERENCE_ENGINE:-ollama}"
            fi

            if is_valid_service "$service_to_check"; then
                service_names+=("$service_to_check")
            else
                echo "   Warning: '$arg' is not a valid service name, ignoring" >&2
            fi
        done
        
        # If we found valid service names, restart only those services
        if [ ${#service_names[@]} -gt 0 ]; then
            echo "Restarting specific services: ${service_names[*]}"
            for service in "${service_names[@]}"; do
                # Call the service function to restart each service
                service restart "$service" || {
                    echo "[ ] Failed to restart service: $service" >&2
                    return 1
                }
            done
            echo "[x] Successfully restarted ${#service_names[@]} service(s)"
            return 0
        fi
    fi
    
    # If no profile specified via command line, try to get from .env file
    if [ "$profile_specified" = false ]; then
        local env_file
        env_file="${SCRIPT_DIR}/.env"
        
        # Load .env file to check for PROFILE variable
        if [ -f "$env_file" ]; then
            # Read PROFILE from .env file
            local env_profile
            env_profile=$(grep -E "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null | head -1 | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
            
            if [ -n "$env_profile" ]; then
                profile="$env_profile"
                echo "   Using profile from .env file: $profile"
            fi
        fi
        
        # If still no profile, show error
        if [ -z "$profile" ]; then
            echo "[ ] Error: Profile is required for restart command" >&2
            echo "" >&2
            echo "Available profiles:" >&2
            echo "===================" >&2
            echo "" >&2
            list_profiles >&2
            echo "" >&2
            echo "Usage: ./aixcl stack restart [--profile <profile>] [service1] [service2] ..." >&2
            echo "       ./aixcl stack restart -p <profile>" >&2
            local engine="${INFERENCE_ENGINE:-ollama}"
            echo "       ./aixcl stack restart ${engine}" >&2
            echo "" >&2
            echo "Note: You can set PROFILE=<profile> in .env file to use a default profile" >&2
            echo "" >&2
            echo "" >&2
            echo "Examples:" >&2
            echo "  ./aixcl stack start                      # Start using .env profile" >&2
            echo "  ./aixcl stack start --profile bld        # Start bld profile" >&2
            echo "  ./aixcl stack start --profile sys        # Start sys profile" >&2
            echo "  ./aixcl stack logs engine                   # Show logs for active engine" >&2
            echo "  ./aixcl stack restart engine                # Restart active engine" >&2
            echo "  ./aixcl stack stop                          # Stop all services" >&2
            echo "  ./aixcl stack start -p bld                  # Start bld profile" >&2
            echo "  ./aixcl stack status                        # Show all service status" >&2
            echo "  ./aixcl stack logs -f engine                # Follow logs for active engine" >&2
            echo "  ./aixcl utils prune                      # Remove volumes and state, keep images" >&2
            exit 1
        fi
    fi
    
    # Validate profile
    if ! is_valid_profile "$profile"; then
        echo "[ ] Error: Invalid profile: $profile" >&2
        echo "Valid profiles: bld, sys (default: sys)" >&2
        echo ""
        list_profiles
        exit 1
    fi
    
    # Save profile to .env file if it was specified via command line (and differs from .env)
    if [ "$profile_specified" = true ]; then
        local env_file="${SCRIPT_DIR}/.env"
        if [ -f "$env_file" ]; then
            local current_env_profile
            current_env_profile=$(grep -E "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null | head -1 | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
            if [ "$current_env_profile" != "$profile" ]; then
                # Update or add PROFILE in .env file
                if grep -qE "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null; then
                    # Update existing PROFILE line
                    sed -i "s/^[[:space:]]*PROFILE[[:space:]]*=.*/PROFILE=$profile/" "$env_file"
                else
                    # Add PROFILE line at the end
                    {
                        echo ""
                        echo "# Default profile for stack commands"
                        echo "PROFILE=$profile"
                    } >> "$env_file"
                fi
                echo "   Saved profile to .env file: $profile"
            fi
        fi
    fi
    
    echo "Restarting services with profile: $profile..."
    stop
    sleep 5
    start --profile "$profile"
}

function start_service() {
    if [ -z "$1" ]; then
        log_error "Service name is required"
        log_info "Usage: $0 service start <service-name>"
        echo ""
        log_info "Runtime Core Services (always enabled):"
        log_info "  ${INFERENCE_ENGINE:-ollama}"
        echo ""
        log_info "Operational Services (profile-dependent):"
        log_info "  ${ALL_SERVICES[*]}"
        echo ""
        log_info "Note: OpenCode is a VS Code plugin, not a containerized service"
        log_info "For service contracts and profiles, see: docs/architecture/governance/service_contracts/"
        return 1
    fi
    
    local service="$1"
    local force_recreate="${2:-false}"
    
    # Validate service name
    if ! is_valid_service "$service"; then
        echo "[ ] Error: Unknown service '$service'"
        echo ""
        echo "Runtime Core Services (always enabled): engine (${INFERENCE_ENGINE:-ollama})"
        echo "Operational Services (profile-dependent): ${ALL_SERVICES[*]}"
        echo ""
        echo "For service contracts and profiles, see: docs/architecture/governance/service_contracts/"
        return 1
    fi
    
    # Delegate to shared utility
    container_start "$service" "$force_recreate"
}

function stop_service() {
    if [ -z "$1" ]; then
        log_error "Service name is required"
        log_info "Usage: $0 service stop <service-name>"
        echo ""
        log_info "Runtime Core Services (always enabled): ${INFERENCE_ENGINE:-ollama} (supported: ollama, vllm, llamacpp)"
        log_info "Operational Services (profile-dependent): ${ALL_SERVICES[*]}"
        echo ""
        log_info "For service contracts and profiles, see: docs/architecture/governance/service_contracts/"
        return 1
    fi
    
    local service="$1"
    
    # Validate service name
    if ! is_valid_service "$service"; then
        echo "[ ] Error: Unknown service '$service'"
        echo ""
        echo "Runtime Core Services (always enabled): engine (${INFERENCE_ENGINE:-ollama})"
        echo "Operational Services (profile-dependent): ${ALL_SERVICES[*]}"
        echo ""
        echo "For service contracts and profiles, see: docs/architecture/governance/service_contracts/"
        return 1
    fi
    
    # Delegate to shared utility
    container_stop "$service"
}

function service() {
    if [[ $# -lt 2 ]]; then
        echo "Error: Service action and name are required"
        echo "Usage: $0 service {start|stop|restart} <service-name>"
        echo ""
        echo "Runtime Core Services (always enabled): engine (${INFERENCE_ENGINE:-ollama})"
        echo "Operational Services (profile-dependent): ${ALL_SERVICES[*]}"
        echo ""
        echo "Note: OpenCode is a VS Code plugin, not a containerized service"
        echo "For service contracts and profiles, see: docs/architecture/governance/service_contracts/"
        return 1
    fi
    
    local action="$1"
    local service="$2"
    shift 2
    
    # Check for extra arguments
    if [ $# -gt 0 ]; then
        echo "Error: Unknown argument '$1'"
        echo "Usage: $0 service {start|stop|restart} <service-name>"
        return 1
    fi
    
    case "$action" in
        start)
            start_service "$service"
            ;;
        stop)
            stop_service "$service"
            ;;
        restart)
            echo "Restarting service: $service..."
            
            # Set up compose command early
            set_compose_cmd
            
            # Check if service needs rebuild
            if needs_rebuild "$service"; then
                echo "   Source code changes detected. Rebuilding $service..."
                
                # Stop and remove the service completely to avoid ContainerConfig errors
                stop_service "$service" 2>/dev/null || true
                
                # Force remove any existing containers (including hash-prefixed ones)
                echo "Removing existing containers for clean rebuild..."
                local container_name
                container_name=$(get_container_name "$service")
                "${DOCKER_BIN:-docker}" rm -f "$container_name" 2>/dev/null || true
                # Remove any hash-prefixed containers
                "${DOCKER_BIN:-docker}" ps -a --format "{{.ID}} {{.Names}}" 2>/dev/null | grep -E "_${container_name}$|^[0-9a-f]+_${container_name}$" | awk '{print $1}' | xargs -r "${DOCKER_BIN:-docker}" rm -f 2>/dev/null || true
                
                # Rebuild the service
                echo "Building $service..."
                if run_compose build "$service"; then
                    echo "[x] Successfully rebuilt $service"
                else
                    echo "[ ] Failed to rebuild $service"
                    return 1
                fi
                
                # Start with force recreate after rebuild
                start_service "$service" "true"
            else
                # Just stop without rebuild
                stop_service "$service"
                sleep 2
                start_service "$service"
            fi
            ;;
        *)
            echo "Error: Unknown service action '$action'"
            echo "Available actions: start, stop, restart"
            return 1
            ;;
    esac
}

function logs() {
    local follow=false
    local tail_count=100
    local service_name=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -f|--follow)
                follow=true
                shift
                ;;
            [0-9]*)
                tail_count="$1"
                shift
                ;;
            *)
                service_name="$1"
                shift
                ;;
        esac
    done

    # No service specified: print last 100 lines of all services, then optionally follow
    if [ -z "$service_name" ]; then
        log_info "Fetching logs for all services..."
        echo ""

        local found_any=false
        local running_containers=()

        for service in "${ALL_SERVICES[@]}"; do
            [ "$service" = "engine" ] && continue

            local actual_container
            actual_container=$("${DOCKER_BIN:-docker}" ps --format "{{.Names}}" 2>/dev/null | grep -E "^${service}$|_[0-9a-f]+_${service}$|^[0-9a-f]+_${service}$" | head -1 || true)

            if [ -n "$actual_container" ]; then
                found_any=true
                running_containers+=("$actual_container")
            fi
        done

        if [ "$found_any" = false ]; then
            log_warning "No services are currently running."
            log_info "   Start services with: ./aixcl stack start"
            return 0
        fi

        # Print last $tail_count lines for each container
        for service in "${running_containers[@]}"; do
            echo "=== $service ==="
            "${DOCKER_BIN:-docker}" logs --tail="$tail_count" "$service" 2>/dev/null || echo "  (no logs available)"
            echo ""
        done

        # Follow streaming logs if -f or --follow was passed
        if [ "$follow" = true ]; then
            log_info "Following new logs (Press Ctrl+C to stop)..."
            echo ""

            local pids=()
            trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT INT TERM

            for service in "${running_containers[@]}"; do
                ( "${DOCKER_BIN:-docker}" logs --follow "$service" 2>/dev/null | sed "s/^/[$service] /" || true ) &
                pids+=($!)
            done

            if [ ${#pids[@]} -gt 0 ]; then
                wait "${pids[@]}" 2>/dev/null || true
            fi

            trap - EXIT INT TERM
        fi

        return 0
    fi

    # Resolve 'engine' alias
    local actual_service="$service_name"
    if [ "$service_name" = "engine" ]; then
        actual_service=$(get_container_name "engine")
    fi

    # Validate service name
    if ! is_valid_service "$service_name"; then
        log_error "Unknown container '$service_name'"
        echo ""
        log_info "Runtime Core Services (Active: ${INFERENCE_ENGINE:-ollama}):"
        log_info "  engine (ollama, vllm, llamacpp)"
        echo ""
        log_info "Operational Services:"
        log_info "  ${ALL_SERVICES[*]}"
        echo ""
        log_info "For service contracts and profiles, see: docs/architecture/governance/service_contracts/"
        return 1
    fi

    log_info "Fetching logs for $actual_service..."

    local actual_container
    actual_container=$("${DOCKER_BIN:-docker}" ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^${actual_service}$|_[0-9a-f]+_${actual_service}$|^[0-9a-f]+_${actual_service}$" | head -1)

    if [ -n "$actual_container" ]; then
        if [ "$follow" = true ]; then
            # Stream logs with prefix
            ( "${DOCKER_BIN:-docker}" logs --follow --tail="$tail_count" "$actual_container" 2>/dev/null || true )
        else
            # Print last $tail_count lines and exit
            "${DOCKER_BIN:-docker}" logs --tail="$tail_count" "$actual_container" 2>/dev/null || echo "  (no logs available)"
        fi
    else
        log_error "Container for service '$actual_service' not found"
        return 1
    fi
}

function status() {
    # Profile library is sourced at script startup (lib/cli/profile.sh)
    
    # Get current profile from .env file
    local current_profile=""
    local env_file="${SCRIPT_DIR}/.env"
    if [ -f "$env_file" ]; then
        current_profile=$(grep -E "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null | head -1 | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
    fi
    
    # Determine overall status (Running/Stopped)
    local overall_status="Stopped"
    # Join ALL_SERVICES with | for grep
    local all_services_pattern
    all_services_pattern=$(IFS="|"; echo "${ALL_SERVICES[*]}")
    if "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -qE "$CONTAINER_NAME|$all_services_pattern"; then
        overall_status="Running"
    fi
    
    # Health counters
    total_services=0
    healthy_services=0
    
    # Build list of operational service names for current profile (exclude runtime core)
    local profile_operational_list=""
    if [ -n "$current_profile" ] && is_valid_profile "$current_profile" 2>/dev/null; then
        local profile_services
        profile_services=$(get_profile_services "$current_profile" 2>/dev/null) || true
        for s in $profile_services; do
            for core in "${RUNTIME_CORE_SERVICES[@]}"; do
                [ "$s" = "$core" ] && continue 2
            done
            profile_operational_list="${profile_operational_list} ${s}"
        done
        profile_operational_list="${profile_operational_list# }"
    fi
    operational_enabled_count=0
    for s in $profile_operational_list; do ((operational_enabled_count++)) || true; done
    
    # Helper: return 0 if service name is in current profile's operational services
    is_operational_in_profile() {
        local service_name="$1"
        [ -z "$profile_operational_list" ] && return 0
        case " $profile_operational_list " in
            *" $service_name "*) return 0 ;;
            *) return 1 ;;
        esac
    }
    
    # Helper function to check both container status and health
    # Returns: 0=healthy, 1=unhealthy, 2=stopped
    # health_check_type can be: "curl" (with URL), "pg_isready" (with username), "status_var" (with variable name), or empty (no health check)
    check_service_status() {
        local service_name="$1"
        local container_name="$2"
        local health_check_type="$3"
        local health_check_arg="$4"

        
        # Check container status
        local container_running=false
        if "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            container_running=true
        fi
        
        # Check health (only if container is running)
        local health_status=""
        local health_result=""
        if [ "$container_running" = "true" ] && [ -n "$health_check_type" ]; then
            case "$health_check_type" in
                curl)
                    health_result=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 3 "$health_check_arg" 2>/dev/null || echo "000")
                    if [ "$health_result" = "404" ] || [ "$health_result" = "000" ]; then
                        local base_url="${health_check_arg%/health}"
                        base_url="${base_url%/}"
                        local root_result
                        root_result=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 3 "$base_url/" 2>/dev/null || echo "000")
                        if [ "$root_result" = "200" ] || [ "$root_result" = "302" ] || [ "$root_result" = "307" ]; then
                            health_result="$root_result"
                        fi
                    fi
                    ;;
                pg_isready)
                    if [ -n "$health_check_arg" ] && [ -n "$container_name" ]; then
                        if timeout 2 "${DOCKER_BIN:-docker}" exec "$container_name" pg_isready -U "$health_check_arg" >/dev/null 2>&1; then
                            health_result="healthy"
                        else
                            health_result="unhealthy"
                        fi
                    fi
                    ;;
                status_var)
                    if [ -n "$health_check_arg" ]; then
                        health_result="${!health_check_arg:-000}"
                    fi
                    ;;
            esac
        fi

        # Determine final display status and health
        local display_status="${ICON_ERROR:-❌}"
        local is_healthy=false

        if [ "$container_running" = "true" ]; then
            if [ -z "$health_check_type" ]; then
                display_status="${ICON_SUCCESS:-✅}"
                is_healthy=true
            else
                if [ "$health_result" = "200" ] || [ "$health_result" = "302" ] || [ "$health_result" = "307" ] || [ "$health_result" = "healthy" ]; then
                    display_status="${ICON_SUCCESS:-✅}"
                    is_healthy=true
                elif [ "$health_result" = "503" ] || [ "$health_result" = "starting" ] || [ "$health_result" = "000" ]; then
                    # 000 often means service is Up but not yet responding (e.g. pgAdmin starting)
                    display_status="${ICON_WARNING:-⚠️}"
                    health_status=" (starting up)"
                else
                    display_status="${ICON_ERROR:-❌}"
                    health_status=" (unhealthy)"
                fi
            fi
        fi

        # Update counters
        ((total_services++)) || true
        if [ "$is_healthy" = "true" ]; then
            ((healthy_services++)) || true
        fi
        
        echo "  ${display_status} ${service_name}${health_status}"
    }
    
    # Helper: check operational service only if in current profile; otherwise show SKIP (per 03_stack_status.md)
    check_operational_service() {
        local display_name="$1"
        local container_name="$2"
        local profile_service_name="$3"
        local health_check_type="$4"
        local health_check_arg="$5"
        if ! is_operational_in_profile "$profile_service_name"; then
            return
        fi
        check_service_status "$display_name" "$container_name" "$health_check_type" "$health_check_arg"
    }
    
    # Header section
    echo "AIXCL Stack Status"
    echo "=================="
    echo ""
    
    if [ -n "$current_profile" ] && is_valid_profile "$current_profile" 2>/dev/null; then
        echo "Profile: $current_profile"
    else
        echo "Profile: (not set)"
    fi
    echo "Status: $overall_status"
    echo ""
    
    # Services section
    echo "Services"
    echo "--------------------------------------------------"
    echo ""

    # Runtime Core
    echo "Runtime Core"
    local active_engine
    active_engine="${INFERENCE_ENGINE:-ollama}"
    
    # Define engines and their health check URLs
    local engines=("ollama" "vllm" "llamacpp")
    local names=("Ollama" "vLLM" "llama.cpp")
    local urls=(
        "http://127.0.0.1:11434/api/version"
        "http://127.0.0.1:11434/v1/models"
        "http://127.0.0.1:11434/v1/models"
    )

    for i in "${!engines[@]}"; do
        local engine
        engine="${engines[$i]}"
        
        # Only show the active engine (the one that SHOULD be running in the current profile)
        if [ "$engine" != "$active_engine" ]; then
            continue
        fi
        
        local name
        name="${names[$i]}"
        local url
        url="${urls[$i]}"
        local suffix=""
        
        if [ "$engine" = "$active_engine" ]; then
            suffix=" (Active Engine)"
        fi
        
        check_service_status "$name$suffix" "$engine" "curl" "$url"
    done
    
    echo ""

    # Operational Services
    echo "Operational Services"
    
    # Security
    # shellcheck disable=SC2034
    VAULT_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8200/v1/sys/health 2>/dev/null || echo "000")
    check_operational_service "Vault" "vault" "vault" "status_var" "VAULT_STATUS"
    
    # UI
    check_operational_service "Open WebUI" "open-webui" "open-webui" "curl" "http://127.0.0.1:8080/health"

    # Persistence
    local postgres_user
    postgres_user="${POSTGRES_USER:-webui}"
    if [[ ! "$postgres_user" =~ ^[A-Za-z0-9_-]+$ ]]; then
        postgres_user="webui"
        echo "   Warning: Invalid POSTGRES_USER value, using default 'webui'" >&2
    fi
    check_operational_service "PostgreSQL" "postgres" "postgres" "pg_isready" "$postgres_user"

    # shellcheck disable=SC2034
    PGADMIN_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5050 2>/dev/null || echo "000")
    check_operational_service "pgAdmin" "pgadmin" "pgadmin" "status_var" "PGADMIN_STATUS"

    # Observability
    # shellcheck disable=SC2034
    PROMETHEUS_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9090/-/healthy 2>/dev/null || echo "000")
    check_operational_service "Prometheus" "prometheus" "prometheus" "status_var" "PROMETHEUS_STATUS"

    # shellcheck disable=SC2034
    GRAFANA_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/health 2>/dev/null || echo "000")
    check_operational_service "Grafana" "grafana" "grafana" "status_var" "GRAFANA_STATUS"

    # shellcheck disable=SC2034
    CADVISOR_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081/metrics 2>/dev/null || echo "000")
    check_operational_service "cAdvisor" "cadvisor" "cadvisor" "status_var" "CADVISOR_STATUS"

    # shellcheck disable=SC2034
    NODE_EXPORTER_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9100/metrics 2>/dev/null || echo "000")
    check_operational_service "Node Exporter" "node-exporter" "node-exporter" "status_var" "NODE_EXPORTER_STATUS"

    # shellcheck disable=SC2034
    POSTSRES_EXPORTER_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9187/metrics 2>/dev/null || echo "000")
    check_operational_service "Postgres Exporter" "postgres-exporter" "postgres-exporter" "status_var" "POSTSRES_EXPORTER_STATUS"

    if is_operational_in_profile "nvidia-gpu-exporter"; then
        if "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -q "^nvidia-gpu-exporter$"; then
            # shellcheck disable=SC2034
            NVIDIA_GPU_EXPORTER_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9445/metrics 2>/dev/null || echo "000")
            check_service_status "NVIDIA GPU Exporter" "nvidia-gpu-exporter" "status_var" "NVIDIA_GPU_EXPORTER_STATUS"
        else
            echo "  ${ICON_ERROR:-❌} NVIDIA GPU Exporter"
            ((total_services++)) || true
        fi
    fi

    # Loki
    # shellcheck disable=SC2034
    LOKI_STATUS=$(curl --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3100/ready 2>/dev/null || echo "000")
    check_operational_service "Loki" "loki" "loki" "status_var" "LOKI_STATUS"

    # Health Summary section
    echo ""
    if [ $total_services -gt 0 ]; then
        echo "Services: $healthy_services/$total_services healthy"
        if [ $healthy_services -eq $total_services ]; then
            echo "Overall:  ${ICON_SUCCESS:-✅} All services healthy"
        else
            echo "Overall:  ${ICON_ERROR:-❌} Some services unhealthy"
        fi
    else
        echo "Overall:  ${ICON_WARNING:-⚠️} No services running"
    fi
    echo ""
}

function stack_cmd() {
    if [[ $# -lt 1 ]]; then
        echo "Error: Stack action is required"
        echo "Usage: $0 stack {start|stop|restart|status|logs|init}"
        echo "Examples:"
        echo "  $0 stack start                - Start all services with sys profile (default)"
        echo "  $0 stack start --profile bld  - Start bld profile (runtime core + observability)"
        echo "  $0 stack start --profile sys  - Start all services"
        echo "  $0 stack stop                 - Stop all services"
        echo "  $0 stack restart [--profile <profile>] [service1] [service2] ... - Restart stack or specific services"
        echo "  $0 stack status               - Show service status (runtime core vs operational)"
        echo "  $0 stack logs                 - Show logs for all services"
        echo "  $0 stack logs engine          - Show logs for the active inference engine"
        echo "  $0 stack logs engine 100      - Show last 100 lines for the active engine"
        echo "  $0 stack logs open-webui      - Show logs for a specific service"
        echo ""
        echo "Valid profiles: bld, sys (default: sys)"
        echo "For detailed profile definitions, see: docs/architecture/governance/02_profiles.md"
        return 1
    fi

    local action="$1"
    shift

    case "$action" in
        start)
            start "$@"
            ;;
        stop)
            if [ $# -gt 0 ]; then
                echo "Error: Unknown argument '$1'"
                echo "Usage: $0 stack {start|stop|restart|status|logs}"
                return 1
            fi
            stop
            ;;
        restart)
            restart "$@"
            ;;
        status)
            if [ $# -gt 0 ]; then
                echo "Error: Unknown argument '$1'"
                echo "Usage: $0 stack {start|stop|restart|status|logs}"
                return 1
            fi
            status
            ;;
        logs)
            logs "$@"
            ;;
        init)
            if [ $# -gt 0 ]; then
                echo "Error: Unknown argument '$1'"
                echo "Usage: $0 stack {start|stop|restart|status|logs|init}"
                return 1
            fi
            init_stack
            ;;
        *)
            echo "Error: Unknown stack action '$action'"
            echo "Usage: $0 stack {start|stop|restart|status|logs|init}"
            echo ""
            echo "For profiles and service contracts, see: docs/architecture/governance/"
            return 1
            ;;
    esac
}
