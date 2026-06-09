#!/usr/bin/env bash
# App command handler for AIXCL
# Generic infrastructure for "bring your own app" builder services
# Reads manifests at apps/<name>/app.yaml and manages container lifecycle
#
# Usage (via dispatcher):
#   ./aixcl app list
#   ./aixcl app start <name>
#   ./aixcl app stop <name>
#   ./aixcl app status <name>
#   ./aixcl app build <name>
#   ./aixcl app scaffold <name>
#   ./aixcl app install <git-url> [--name <name>] [--branch <branch>]
#
# Safety: No user input is eval()'d. All shell interaction is via the
# app_parser.sh helper which converts YAML to exports using Python3.

# Dependencies: app_parser.sh must be loaded first by the main script

# ── Internal helpers ───────────────────────────────────────────────────────────

# Guard: ensure the parser module is loaded
_app_ensure_parser() {
    if ! command -v _app_load_manifest >& /dev/null 2>&1; then
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/lib/core/app_parser.sh"
    fi
}

# Print usage
_app_usage() {
    cat << 'EOF'
Usage: ./aixcl app <action> [args]

Actions:
  list                          Discover and list all registered apps
  start   <name>                 Start an app's services from manifest
  stop    <name>                 Stop an app's services
  restart <name>                 Restart an app's services
  status  <name>                 Show status of an app's services
  build   <name>                 Build containers for an app (built: true)
  remove  <name>                 Stop, rm containers, and prune images
  scaffold <name>                Generate a new app skeleton from template
  install <git-url> [--name <n>] [--branch <b>]
                                Clone a builder repo as submodule and scaffold

Examples:
  ./aixcl app list
  ./aixcl app start ftso
  ./aixcl app stop  ftso
  ./aixcl app build ftso
  ./aixcl app scaffold my-app
  ./aixcl app install git@github.com:user/my-app.git --name my-app
EOF
}

# Ensure compose command is available
_app_ensure_compose() {
    if [ -z "${COMPOSE_CMD[*]:-}" ]; then
        set_compose_cmd
    fi
}

# Build a compose command for a specific app directory.
# Usage: _app_compose_cmd "ftso" up -d
_app_compose_cmd() {
    local app_name="${1:-}"
    shift
    local app_dir="${SCRIPT_DIR}/apps/${app_name}"
    local compose_file="${app_dir}/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        echo "[ ] Missing ${compose_file}" >&2
        return 1
    fi

    # Use the same runtime detection as the platform but with app compose file
    local cmd=()
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        cmd=(docker compose -f "$compose_file" -p "aixcl-${app_name}")
    elif command -v docker-compose >/dev/null 2>&1; then
        cmd=(docker-compose -f "$compose_file" -p "aixcl-${app_name}")
    elif command -v podman-compose >/dev/null 2>&1; then
        cmd=(podman-compose -f "$compose_file" -p "aixcl-${app_name}")
    else
        echo "[ ] No compose tool found" >&2
        return 1
    fi

    (cd "$app_dir" && "${cmd[@]}" "$@" 2>&1)
    return ${PIPESTATUS[0]:-0}
}

# Resolve whether a service has `built: true` in its manifest
# Note: `_app_load_manifest` must be run before calling this.
_app_service_needs_build() {
    local index="$1"
    local built_val
    # Use indirect expansion for names like APP_SERVICE_0_BUILT
    built_val="$(eval "echo \${APP_SERVICE_${index}_BUILT:-}" 2>/dev/null || true)"
    [ "$built_val" = "True" ] || [ "$built_val" = "true" ] || [ "$built_val" = "1" ]
}

_app_service_healthcheck_type() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_HEALTHCHECK_TYPE:-}" 2>/dev/null || true
}

_app_service_healthcheck_url() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_HEALTHCHECK_URL:-}" 2>/dev/null || true
}

_app_service_healthcheck_interval() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_HEALTHCHECK_INTERVAL:-10}" 2>/dev/null || true
}

_app_service_healthcheck_timeout() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_HEALTHCHECK_STARTUP_TIMEOUT:-30}" 2>/dev/null || true
}

_app_service_container_name() {
    local index="$1"
    local cn
    cn="$(eval "echo \${APP_SERVICE_${index}_CONTAINER_NAME:-}" 2>/dev/null || true)"
    if [ -z "$cn" ]; then
        cn="$(eval "echo \${APP_SERVICE_${index}_NAME:-}" 2>/dev/null || true)"
    fi
    echo "$cn"
}

_app_service_build_context() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_BUILD_CONTEXT:-}" 2>/dev/null || true
}

_app_service_build_dockerfile() {
    local index="$1"
    local df
    df="$(eval "echo \${APP_SERVICE_${index}_BUILD_DOCKERFILE:-}" 2>/dev/null || true)"
    [ -n "$df" ] && echo "$df" || echo "Dockerfile"
}

_app_service_depends_on() {
    local index="$1"
    # Depends_on is a list; parser exports APP_SERVICE_0_DEPENDS_ON_0, etc.
    local deps=()
    local i=0
    while true; do
        local dep
        dep="$(eval "echo \${APP_SERVICE_${index}_DEPENDS_ON_${i}:-}" 2>/dev/null || true)"
        if [ -z "$dep" ]; then
            break
        fi
        deps+=("$dep")
        i=$((i + 1))
    done
    printf '%s\n' "${deps[@]}"
}

# Check if a URL responds healthy (same helper as ftso.sh)
_app_http_ok() {
    local url="$1"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$url" 2>/dev/null || echo "000")
    [ "$code" = "200" ]
}

# Check if a container is running (same pattern as ftso.sh / stack.sh)
_app_container_running() {
    local name="$1"
    "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" 2>/dev/null | grep -q "^${name}$"
}

# Check if a container exists in any state (running, stopped, created, dead)
_app_container_exists() {
    local name="$1"
    "${DOCKER_BIN:-docker}" ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${name}$"
}

# Return the container ID for a given name (any state)
_app_container_id() {
    local name="$1"
    "${DOCKER_BIN:-docker}" ps -a --format "{{.ID}}" --filter "name=^${name}$" 2>/dev/null | head -n 1
}

# ── Public Actions ─────────────────────────────────────────────────────────────

# Usage: app_cmd list
# Lists all registered apps discovered by manifest
app_cmd_list() {
    _app_ensure_parser

    local apps
    apps="$(_app_discover 2>/dev/null)"
    if [ -z "$apps" ]; then
        echo "No applications registered."
        echo ""
        echo "Use './aixcl app scaffold <name>' to create a new app,"
        echo "or './aixcl app install <git-url>' to import an existing one."
        return 0
    fi

    echo ""
    echo "Registered Applications"
    echo "======================"
    echo ""
    while IFS= read -r app_name; do
        if [ -z "$app_name" ]; then
            continue
        fi
        local version=""
        if _app_load_manifest "$app_name" 2>/dev/null; then
            version="${APP_VERSION:-}"
        fi
        if [ -n "$version" ]; then
            printf "  - %-20s (version: %s)\n" "$app_name" "$version"
        else
            printf "  - %-20s\n" "$app_name"
        fi
    done <<< "${apps}"
    echo ""
}

# Usage: app_cmd start <name>
# Start all services for an app in manifest order with dependency waits
app_cmd_start() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        _app_usage >&2
        return 1
    fi

    _app_ensure_parser
    _app_ensure_compose

    if ! _app_load_manifest "$app_name"; then
        echo "[ ] Failed to load manifest for app: ${app_name}" >&2
        return 1
    fi

    if ! _app_validate_manifest "apps/${app_name}/app.yaml"; then
        return 1
    fi

    echo ""
    echo "Starting Application: ${app_name}"
    echo "=============================="
    echo ""

    local svc_count
    svc_count="$(_app_service_count)"
    if [ "$svc_count" -eq 0 ]; then
        echo "  [ ] No services defined in manifest." >&2
        return 1
    fi

    local started=0
    for i in $(seq 0 "$((svc_count - 1))"); do
        local svc_name svc_container build_ctx health_type
        svc_name="$(eval "echo \${APP_SERVICE_${i}_NAME:-}" 2>/dev/null || true)"
        svc_container="$(_app_service_container_name $i)"
        if [ -z "$svc_name" ] || [ -z "$svc_container" ]; then
            echo "  [ ] Service ${i} has no name or container_name" >&2
            continue
        fi

        # Build first if required
        if _app_service_needs_build "$i"; then
            local build_ctx
            build_ctx="$(_app_service_build_context "$i")"
            if [ -n "$build_ctx" ]; then
                local app_dir="${SCRIPT_DIR}/apps/${app_name}"
                local abs_ctx
                abs_ctx="${app_dir}/${build_ctx}"
                if [ -d "$abs_ctx" ]; then
                    echo "  Building ${svc_name}..."
                    local df
                    df="$(_app_service_build_dockerfile "$i")"
                    if "${DOCKER_BIN:-docker}" build -f "${abs_ctx}/${df}" -t "localhost/${svc_container}:latest" "$abs_ctx" >/dev/null 2>&1; then
                        echo "    [x] ${svc_name} built"
                    else
                        echo "    [ ] ${svc_name} build failed (non-fatal; compose up may pull instead)" >&2
                    fi
                else
                    echo "  [ ] Build context not found: ${abs_ctx}" >&2
                fi
            fi
        fi

        # Start the service
        echo "  Starting ${svc_name}..."
        _app_compose_cmd "$app_name" up -d --no-deps "$svc_container" 2>/dev/null || {
            echo "  [ ] Failed to start ${svc_name}" >&2
            return 1
        }

        # Wait for health check if defined
        health_type="$(_app_service_healthcheck_type "$i")"
        local timeout
        timeout="$(_app_service_healthcheck_timeout "$i")"
        if [ -n "$health_type" ] && [ "$health_type" != "container_running" ]; then
            local url wait_start wait_inter elapsed
            url="$(_app_service_healthcheck_url "$i")"
            wait_inter="$(_app_service_healthcheck_interval "$i")"
            wait_start=$(date +%s)
            echo -n "  Waiting for ${svc_name}..."
            local wait_ok=false
            while true; do
                if _app_http_ok "$url"; then
                    wait_ok=true
                    break
                fi
                elapsed=$(( $(date +%s) - wait_start ))
                if [ "$elapsed" -ge "$timeout" ]; then
                    break
                fi
                sleep "$wait_inter"
                printf " ."
            done
            if [ "$wait_ok" = true ]; then
                echo " ${ICON_SUCCESS:-OK}"
            else
                echo " ${ICON_ERROR:-ERR} (timed out after ${timeout}s)"
            fi
        else
            # No health URL — just check if container is running
            sleep 2
            if _app_container_running "$svc_container"; then
                echo "  ${ICON_SUCCESS:-OK} ${svc_name} running"
            else
                echo "  ${ICON_ERROR:-ERR} ${svc_container} not running" >&2
                # Allow manual retry; warn only
            fi
        fi
        started=$((started + 1))
    done

    # Wire Prometheus file_sd if enabled or targets are defined
    if [ "${APP_PROMETHEUS_ENABLED:-}" = "True" ] || [ "${APP_PROMETHEUS_ENABLED:-}" = "true" ] || [ "${APP_PROMETHEUS_ENABLED:-}" = "1" ] || [ -n "${APP_PROMETHEUS_TARGETS_0:-}" ]; then
        _app_generate_prometheus_targets "$app_name"
    fi

    # Wire Grafana dashboards if enabled
    if [ "${APP_GRAFANA_ENABLED:-}" = "True" ] || [ "${APP_GRAFANA_ENABLED:-}" = "true" ] || [ "${APP_GRAFANA_ENABLED:-}" = "1" ]; then
        _app_wire_grafana "$app_name"
    fi

    echo ""
    echo "[x] Started ${started} service(s) for app: ${app_name}"
}

# Usage: app_cmd stop <name>
app_cmd_stop() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        _app_usage >&2
        return 1
    fi

    _app_ensure_parser

    if ! _app_load_manifest "$app_name"; then
        return 1
    fi

    echo "Stopping Application: ${app_name}"
    local svc_count
    svc_count="$(_app_service_count)"
    if [ "$svc_count" -eq 0 ]; then
        echo "  (no services)"
        return 0
    fi

    # Stop in reverse order
    local stopped=0
    for i in $(seq "$((svc_count - 1))" -1 0); do
        local svc_container
        svc_container="$(_app_service_container_name "$i")"
        if [ -z "$svc_container" ]; then
            continue
        fi
        if _app_container_running "$svc_container"; then
            _app_compose_cmd "$app_name" stop "$svc_container" 2>/dev/null || true
            stopped=$((stopped + 1))
        fi
    done

    # Remove Prometheus file_sd
    local prom_file="${SCRIPT_DIR}/prometheus/file_sd/${app_name}.json"
    if [ -f "$prom_file" ]; then
        rm -f "$prom_file"
    fi

    echo "  [x] Stopped ${stopped} service(s)."
}

# Usage: app_cmd restart <name>
app_cmd_restart() {
    local app_name="${1:-}"
    app_cmd_stop "$app_name" && app_cmd_start "$app_name"
}

# Usage: app_cmd status <name>
# Optional: support `./aixcl app status` (no arg) to show all apps later
app_cmd_status() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        return 1
    fi

    _app_ensure_parser
    if ! _app_load_manifest "$app_name"; then
        return 1
    fi

    echo ""
    echo "Application: ${app_name}"
    echo "  Version: ${APP_VERSION:-unknown}"
    echo "  Services:"

    local svc_count
    svc_count="$(_app_service_count)"
    for i in $(seq 0 "$((svc_count - 1))"); do
        local svc_container status_icon note
        svc_container="$(_app_service_container_name "$i")"
        if _app_container_running "$svc_container"; then
            local htype hurl
            htype="$(_app_service_healthcheck_type "$i")"
            hurl="$(_app_service_healthcheck_url "$i")"
            if [ -n "$htype" ] && [ "$htype" != "container_running" ] && [ -n "$hurl" ]; then
                if _app_http_ok "$hurl"; then
                    status_icon="${ICON_SUCCESS:-OK}"
                else
                    status_icon="${ICON_WARNING:-WARN}"
                    note=" (starting)"
                fi
            else
                status_icon="${ICON_SUCCESS:-OK}"
            fi
        else
            status_icon="${ICON_ERROR:-ERR}"
            note=" (stopped)"
        fi
        echo "    ${status_icon} ${svc_container}${note:-}"
    done
    echo ""
}

# Usage: app_cmd build <name>
# Builds all services with built: true
app_cmd_build() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        return 1
    fi

    _app_ensure_parser
    if ! _app_load_manifest "$app_name"; then
        return 1
    fi

    echo "Building application: ${app_name}"
    local svc_count
    svc_count="$(_app_service_count)"
    local built=0
    for i in $(seq 0 "$((svc_count - 1))"); do
        if _app_service_needs_build "$i"; then
            local svc_name svc_container build_ctx df
            svc_name="$(eval "echo \${APP_SERVICE_${i}_NAME:-}" 2>/dev/null || true)"
            svc_container="$(_app_service_container_name "$i")"
            build_ctx="$(_app_service_build_context "$i")"
            df="$(_app_service_build_dockerfile "$i")"
            if [ -n "$build_ctx" ]; then
                local app_dir="${SCRIPT_DIR}/apps/${app_name}"
                local abs_ctx
                abs_ctx="${app_dir}/${build_ctx}"
                if [ -d "$abs_ctx" ]; then
                    echo "  Building ${svc_name}..."
                    if "${DOCKER_BIN:-docker}" build -f "${abs_ctx}/${df}" \
                          -t "localhost/${svc_container}:latest" \
                          "$abs_ctx"; then
                        echo "    [x] Built ${svc_name}"
                        built=$((built + 1))
                    else
                        echo "    [ ] Build failed for ${svc_name}" >&2
                        return 1
                    fi
                else
                    echo "  [ ] Build context missing: ${abs_ctx}" >&2
                fi
            fi
        fi
    done
    echo ""
    echo "[x] Built ${built} service(s)."
}

# ── Remove Application ───────────────────────────────────────────────────────────

# Usage: app_cmd_remove <name>
# Stops containers, removes them (docker rm -f), and wipes local image caches.
# Does NOT delete the app source directory — caller must do that manually.
app_cmd_remove() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        _app_usage >&2
        return 1
    fi

    _app_ensure_parser
    if ! _app_load_manifest "$app_name"; then
        return 1
    fi

    echo ""
    echo "Removing Application: ${app_name}"
    echo "========================"
    echo ""

    # 1. Stop and remove each container by name (running or stopped)
    local svc_count removed=0
    svc_count="$(_app_service_count)"
    for i in $(seq 0 "$((svc_count - 1))"); do
        local svc_container
        svc_container="$(_app_service_container_name "$i")"
        [ -z "$svc_container" ] && continue

        if _app_container_running "$svc_container"; then
            echo "  Stopping ${svc_container} ..."
            _app_compose_cmd "$app_name" stop "$svc_container" 2>/dev/null || true
        fi

        # Attempt 1: remove by exact name
        if _app_container_exists "$svc_container"; then
            echo "  Removing container ${svc_container} ..."
            if "${DOCKER_BIN:-docker}" rm -f "$svc_container" 2>/dev/null; then
                echo "    [x] Removed by name"
                removed=$((removed + 1))
                continue
            fi

            # Attempt 2: remove by container ID (handles project ownership mismatch)
            local cid
            cid="$(_app_container_id "$svc_container")"
            if [ -n "$cid" ]; then
                if "${DOCKER_BIN:-docker}" rm -f "$cid" 2>/dev/null; then
                    echo "    [x] Removed by ID (${cid:0:12})"
                    removed=$((removed + 1))
                    continue
                fi
            fi

            echo "    [ ] Failed to remove ${svc_container}. Manual cleanup required:"
            echo "        docker rm -f ${svc_container}"
        else
            echo "    [ ] Container ${svc_container} does not exist (already cleaned)"
        fi
    done

    # 2. Safety sweep: remove any containers matching the app prefix
    #    (catches orphans from old platform-level compose runs)
    local orphan
    orphan=$("${DOCKER_BIN:-docker}" ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^${app_name}[-_]|^dd-${app_name}[-_]" || true)
    if [ -n "$orphan" ]; then
        echo ""
        echo "  Removing orphaned containers ..."
        while IFS= read -r orphan_name; do
            [ -z "$orphan_name" ] && continue
            echo "    Removing orphan: ${orphan_name} ..."
            if "${DOCKER_BIN:-docker}" rm -f "$orphan_name" 2>/dev/null; then
                echo "      [x] Removed"
                removed=$((removed + 1))
            else
                echo "      [ ] Failed (manual: docker rm -f ${orphan_name})"
            fi
        done <<< "$orphan"
    fi

    # 2. Remove Prometheus file_sd if present
    local prom_file="${SCRIPT_DIR}/prometheus/file_sd/${app_name}.json"
    if [ -f "$prom_file" ]; then
        rm -f "$prom_file"
        echo "  Removed Prometheus target file"
    fi

    # 3. Remove Grafana symlink if present
    local grafana_dash="${SCRIPT_DIR}/grafana/provisioning/dashboards/${app_name}"
    if [ -L "$grafana_dash" ]; then
        rm -f "$grafana_dash"
        echo "  Removed Grafana symlink"
    fi

    # 4. Clean dangling images (optional)
    echo ""
    echo "Cleaning dangling images..."
    "${DOCKER_BIN:-docker}" image prune -f 2>/dev/null || true

    echo ""
    echo "[x] Removed ${removed} container(s)."
    echo ""
    echo "NOTE: Source code in apps/${app_name}/ was NOT deleted."
    echo "      Run: rm -rf apps/${app_name}  to delete permanently."
}

# ── Scaffolding ────────────────────────────────────────────────────────────────

# Usage: app_cmd_scaffold <name>
# Generates a new app skeleton in apps/<name>/
app_cmd_scaffold() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        echo "Usage: ./aixcl app scaffold <name>" >&2
        return 1
    fi

    # Validate name
    if [[ ! "$app_name" =~ ^[a-z][a-z0-9_-]*[a-z0-9]$ ]]; then
        echo "Error: Invalid app name '${app_name}'. Use only lowercase letters," >&2
        echo "       numbers, underscores, and hyphens. Must start with a letter." >&2
        return 1
    fi

    local app_dir="apps/${app_name}"
    if [ -e "$app_dir" ]; then
        echo "Error: Directory already exists: ${app_dir}" >&2
        return 1
    fi

    mkdir -p "${app_dir}/docker" "${app_dir}/prometheus" "${app_dir}/grafana/dashboards"

    # Write manifest
    cat > "${app_dir}/app.yaml" << EOF
---
app:
  name: ${app_name}
  version: 0.1.0
  description: "${app_name} application service"

compose:
  files:
    - docker-compose.yml

services:
  - name: ${app_name}-service
    container_name: ${app_name}-service
    built: true
    build_context: docker
    healthcheck:
      type: http
      url: http://127.0.0.1:8080/health
      startup_timeout: 60
      interval: 5
    depends_on: []

prometheus:
  enabled: true
  file_sd:
    - job_name: ${app_name}-service
      targets:
        - 'localhost:8080'
      labels:
        service: ${app_name}-service

grafana:
  enabled: true
  dashboards:
    - source: grafana/dashboards/example.json
      target_folder: AIXCL/${app_name}
EOF

    # Write compose stub
    cat > "${app_dir}/docker-compose.yml" << 'EOF'
# Application-specific Docker Compose
# Defines services not managed by the platform directly.

services:
  my-service:
    image: localhost/my-service:latest
    build:
      context: ./docker
      dockerfile: Dockerfile
    network_mode: host
    restart: unless-stopped
    # Health check required by manifest
EOF

    # Write Dockerfile stub
    cat > "${app_dir}/docker/Dockerfile" << 'EOF'
FROM alpine:latest

# TODO: Add your application here

# Example health endpoint
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["sleep", "3600"]
EOF

    # Write README
    cat > "${app_dir}/README.md" << EOF
# ${app_name} Application

Add your application-specific documentation here.

## Quick Start

\`\`\`bash
# Build containers
./aixcl app build ${app_name}

# Start the application
./aixcl app start ${app_name}

# Check status
./aixcl app status ${app_name}
\`\`\`

## Integration with AIXCL

- Prometheus metrics are auto-discovered via \`prometheus/file_sd/<name>.json\`
- Grafana dashboards are provisioned from \`grafana/dashboards/\`
- The platform provides: PostgreSQL, Vault, Grafana, Prometheus, Loki
EOF

    echo ""
    echo "Scaffolded application: ${app_name}"
    echo "  Location: ${app_dir}/"
    echo ""
    echo "Next steps:"
    echo "  1. Implement your service in ${app_dir}/docker/"
    echo "  2. Update ${app_dir}/app.yaml with correct service definitions"
    echo "  3. Run: ./aixcl app build ${app_name}"
    echo "  4. Run: ./aixcl app start ${app_name}"
}

# ── Installation (Git Submodule) ────────────────────────────────────────────────

# Usage: app_cmd_install <git-url> [--name <name>] [--branch <branch>]
# Clones a builder repo as a submodule into apps/<name>/provider/
app_cmd_install() {
    local git_url=""
    local app_name=""
    local branch="main"

    # Parse arguments
    if [ $# -lt 1 ]; then
        echo "Error: Git URL required." >&2
        echo "Usage: ./aixcl app install <git-url> [--name <name>] [--branch <branch>]" >&2
        return 1
    fi

    git_url="$1"
    shift

    while [ $# -gt 0 ]; do
        case "$1" in
            --name)
                app_name="$2"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # Derive app name from URL if not given
    if [ -z "$app_name" ]; then
        app_name="$(basename "$git_url" .git)"
    fi

    # Validate format
    if [[ ! "$app_name" =~ ^[a-z][a-z0-9_-]*[a-z0-9]$ ]]; then
        echo "Error: Invalid app name '${app_name}'." >&2
        return 1
    fi

    local app_dir="apps/${app_name}"
    if [ -e "$app_dir" ]; then
        echo "Error: App directory already exists: ${app_dir}" >&2
        return 1
    fi

    echo "Installing application: ${app_name}"
    echo "  Source: ${git_url}"
    echo "  Branch: ${branch}"

    # Create app directory
    mkdir -p "$app_dir"

    # Add as submodule
    local submodule_path="${app_dir}/provider"
    if ! git submodule add -b "$branch" "$git_url" "$submodule_path" 2>/dev/null; then
        echo "  [ ] git submodule add failed (already tracked or URL invalid)" >&2
        # Fallback: clone directly if submodule add fails (e.g. shallow history issue)
        git clone --depth=1 --branch "$branch" "$git_url" "$submodule_path" 2>/dev/null || {
            echo "  [ ] Clone failed for ${git_url}" >&2
            rm -rf "$app_dir"
            return 1
        }
    fi

    # Initialize and update
    git submodule update --init "$submodule_path" 2>/dev/null || true

    # Scaffold a basic app.yaml if builder didn't provide one
    if [ ! -f "${app_dir}/app.yaml" ]; then
        echo "  Creating default app.yaml..."
        cat > "${app_dir}/app.yaml" << EOF
---
app:
  name: ${app_name}
  version: 0.1.0
  description: "${app_name} (auto-scaffolded)"

compose:
  files:
    - docker-compose.yml

services:
  - name: ${app_name}-main
    container_name: ${app_name}-main
    built: true
    build_context: provider
    healthcheck:
      type: container_running

depends_on: []
EOF
    fi

    # Scaffold compose if not present
    if [ ! -f "${app_dir}/docker-compose.yml" ]; then
        cat > "${app_dir}/docker-compose.yml" << 'EOF'
services:
  main:
    image: localhost/main:latest
    build:
      context: ./provider
      dockerfile: Dockerfile
    network_mode: host
    restart: unless-stopped
EOF
    fi

    # Scaffold monitoring structures if not present
    mkdir -p "${app_dir}/prometheus" "${app_dir}/grafana/dashboards"

    echo ""
    echo "[x] Installation complete: ${app_dir}/"
    echo ""
    echo "Next steps:"
    echo "  1. Edit ${app_dir}/app.yaml to define your services"
    echo "  2. Build: ./aixcl app build ${app_name}"
    echo "  3. Start: ./aixcl app start ${app_name}"
}

# ── Internal helpers ─────────────────────────────────────────────────────────

# Generate Prometheus target JSON from manifest variables
_app_generate_prometheus_targets() {
    local app_name="${1:-}"
    local app_dir="${SCRIPT_DIR}/apps/${app_name}"
    local platform_sd="${SCRIPT_DIR}/prometheus/file_sd"

    mkdir -p "$platform_sd"

    # Check if static file is provided first
    if [ -f "${app_dir}/prometheus/target.json" ]; then
        cp "${app_dir}/prometheus/target.json" "${platform_sd}/${app_name}.json"
        return 0
    fi

    # Auto-generate from manifest variables (APP_PROMETHEUS_TARGETS_*, APP_PROMETHEUS_LABELS_*)
    local targets=()
    local i=0
    while true; do
        local t
        t="$(eval "echo \${APP_PROMETHEUS_TARGETS_${i}:-}" 2>/dev/null || true)"
        if [ -z "$t" ]; then
            break
        fi
        targets+=("\"$t\"")
        i=$((i + 1))
    done

    if [ ${#targets[@]} -eq 0 ]; then
        echo "  Note: No Prometheus targets configured in manifest." >&2
        return 0
    fi

    # Collect labels
    local labels=""
    # Common labels: app name
    labels="\"app\": \"${app_name}\""
    # Additional labels from manifest
    local label_keys
    label_keys="$(env | grep "^APP_PROMETHEUS_LABELS_" | sed 's/^APP_PROMETHEUS_LABELS_//' | sed 's/=.*//' | sort -u)"
    if [ -n "$label_keys" ]; then
        while IFS= read -r key; do
            [ -z "$key" ] && continue
            local val
            val="$(eval "echo \${APP_PROMETHEUS_LABELS_${key}:-}" 2>/dev/null || true)"
            [ -n "$val" ] && labels="${labels}, \"$(echo "$key" | tr '[:upper:]' '[:lower:]' | tr '_' '-')\": \"${val}\""
        done <<< "$label_keys"
    fi

    # Build JSON
    local target_list
    target_list="$(printf '%s, ' "${targets[@]}")"
    target_list="${target_list%, }"

    cat > "${platform_sd}/${app_name}.json" << EOF
[
  {
    "targets": [${target_list}],
    "labels": {${labels}}
  }
]
EOF

    echo "  [x] Generated Prometheus targets for ${app_name}"
}

# Copy Grafana dashboards from app into platform provisioning
_app_wire_grafana() {
    local app_name="${1:-}"
    local app_dir="${SCRIPT_DIR}/apps/${app_name}"
    local platform_dash="${SCRIPT_DIR}/grafana/provisioning/dashboards/${app_name}"

    if [ -d "${app_dir}/grafana/dashboards" ]; then
        # Copy dashboard JSON files so Grafana sees them inside the container
        # (symlinks break across bind mounts with absolute paths)
        mkdir -p "$platform_dash"
        cp -f "${app_dir}"/grafana/dashboards/*.json "$platform_dash/" 2>/dev/null || true
    fi
}

# ── Dispatcher entry point ─────────────────────────────────────────────────────

# This function is called by lib/aixcl/dispatcher.sh when the first arg is "app"
# Usage: app [subcommand] [args]
app_cmd() {
    if [ $# -lt 1 ]; then
        _app_usage
        return 1
    fi

    local subcommand="$1"
    shift

    case "$subcommand" in
        list)
            app_cmd_list "$@"
            ;;
        start)
            app_cmd_start "$@"
            ;;
        stop)
            app_cmd_stop "$@"
            ;;
        restart)
            app_cmd_restart "$@"
            ;;
        status)
            app_cmd_status "$@"
            ;;
        build)
            app_cmd_build "$@"
            ;;
        remove)
            app_cmd_remove "$@"
            ;;
        scaffold)
            app_cmd_scaffold "$@"
            ;;
        install)
            app_cmd_install "$@"
            ;;
        help|--help|-h)
            _app_usage
            ;;
        *)
            echo "Error: Unknown app action '${subcommand}'" >&2
            _app_usage >&2
            return 1
            ;;
    esac
}

#export -f app_cmd _app_usage app_cmd_list app_cmd_start app_cmd_stop
#export -f app_cmd_status app_cmd_build app_cmd_scaffold app_cmd_install
