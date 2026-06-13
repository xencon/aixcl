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

# -- Internal helpers -----------------------------------------------------------

# Guard: ensure the parser module is loaded
_app_ensure_parser() {
    if ! command -v _app_load_manifest >& /dev/null 2>&1; then
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/lib/core/app_parser.sh"
    fi
    if ! command -v _app_provision >& /dev/null 2>&1; then
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/lib/core/app_provision.sh"
    fi
}

# Print usage
_app_usage() {
    cat << 'EOF'
Usage: ./aixcl app <action> [args]

Actions:
  list                          Discover and list all registered apps
  start   <name> [--verbose]     Start an app's services from manifest
                                (--verbose shows full compose and build output)
  stop    <name>                 Stop an app's services
  restart <name>                 Restart an app's services
  status  <name>                 Show status of an app's services
  build   <name>                 Build containers for an app (built: true)
  provision <name>               Provision declared vault secrets and postgres
  secrets <name>                 Show an app's provisioned secrets (local dev)
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
        echo "${ICON_ERROR:-[ ]} Missing ${compose_file}" >&2
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
        echo "${ICON_ERROR:-[ ]} No compose tool found" >&2
        return 1
    fi

    # Capture raw output: quiet (filtered) on success, but a failure must
    # dump the unfiltered compose output -- the noise filter below must
    # never hide the reason a command failed.
    local out_file rc=0
    out_file="$(mktemp /tmp/aixcl_compose_out.XXXXXX)" || return 1
    (cd "$app_dir" && "${cmd[@]}" "$@" >"$out_file" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        cat "$out_file" >&2
        rm -f "$out_file"
        return "$rc"
    fi
    if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
        cat "$out_file"
        rm -f "$out_file"
        return 0
    fi
    awk '
        /^[[:space:]]*-[ev][[:space:]]/ { next }
        /^[[:space:]]*--/ { next }
        /^[[:space:]]*\{/ { next }
        /^[[:space:]]*\}/ { next }
        /^[[:space:]]*\[/ { next }
        /^[[:space:]]*\]/ { next }
        /^[[:space:]]*"/ { next }
        /^[[:space:]]*\x27/ { next }
        /^[[:space:]]*,[[:space:]]*$/ { next }
        /^[[:space:]]*\}[,[:space:]]*$/ { next }
        /^[[:space:]]*\][,[:space:]]*$/ { next }
        /^\*\* / { next }
        /^podman run/ { next }
        /^\[.podman/ { next }
        /^exit code:/ { next }
        /^podman volume/ { next }
        /^\*\* merged:/ { next }
        /^\*\* excluding:/ { next }
        /^recreating:/ { next }
        /^podman-compose version:/ { next }
        /^using podman version:/ { next }
        /^Container / { next }
        /^\[\+/ { next }
        /^ [x]/ { next }
        /^ [ ]/ { next }
        { print }
    ' < "$out_file"
    rm -f "$out_file"
    return 0
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

# Warn when a service declares build config but built: true is unset --
# previously a silent no-op in both build paths
_app_warn_skipped_build() {
    local index="$1" svc_name="$2"
    local ctx
    ctx="$(_app_service_build_context "$index")"
    if [ -n "$ctx" ]; then
        echo "  ${ICON_WARNING:-[!]} ${svc_name}: build config present but 'built: true' not set; skipping build" >&2
        echo "      Set 'built: true' in the manifest to enable building." >&2
    fi
}

_app_service_healthcheck_type() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_HEALTHCHECK_TYPE:-}" 2>/dev/null || true
}

_app_service_healthcheck_url() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_HEALTHCHECK_URL:-}" 2>/dev/null || true
}

_app_service_healthcheck_command() {
    local index="$1"
    eval "echo \${APP_SERVICE_${index}_HEALTHCHECK_COMMAND:-}" 2>/dev/null || true
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

# Resolve manifest service start order honoring depends_on.
# Prints one service index per line, dependencies before dependents.
# A dependency naming another manifest service orders it earlier; one
# naming an already-running container (platform service) is satisfied;
# anything else fails loudly. Cycles fail loudly.
# Usage: _app_resolve_start_order <svc_count>
_app_resolve_start_order() {
    local svc_count="$1"
    local i j dep
    local -a names svc_deps indeg done_flag

    for ((i = 0; i < svc_count; i++)); do
        names[i]="$(eval "echo \${APP_SERVICE_${i}_NAME:-}" 2>/dev/null || true)"
        svc_deps[i]=""
        indeg[i]=0
        done_flag[i]=0
    done

    for ((i = 0; i < svc_count; i++)); do
        while IFS= read -r dep; do
            [ -z "$dep" ] && continue
            local found=-1
            for ((j = 0; j < svc_count; j++)); do
                if [ "${names[j]}" = "$dep" ]; then
                    found=$j
                    break
                fi
            done
            if [ "$found" -ge 0 ]; then
                case " ${svc_deps[i]} " in
                    *" ${found} "*) ;;  # duplicate entry, already counted
                    *)
                        svc_deps[i]="${svc_deps[i]} ${found}"
                        indeg[i]=$((indeg[i] + 1))
                        ;;
                esac
            elif _app_container_running "$dep"; then
                : # platform dependency already running
            else
                echo "  ${ICON_ERROR:-[ ]} ${names[i]}: depends_on '${dep}' is not a manifest service and no running container has that name" >&2
                echo "      Declare '${dep}' under services: or start it first." >&2
                return 1
            fi
        done < <(_app_service_depends_on "$i")
    done

    # Kahn's algorithm; stable index order among ready services.
    local emitted=0 progress
    while [ "$emitted" -lt "$svc_count" ]; do
        progress=0
        for ((i = 0; i < svc_count; i++)); do
            [ "${done_flag[i]}" = "1" ] && continue
            [ "${indeg[i]}" -ne 0 ] && continue
            echo "$i"
            done_flag[i]=1
            emitted=$((emitted + 1))
            progress=1
            for ((j = 0; j < svc_count; j++)); do
                case " ${svc_deps[j]} " in
                    *" ${i} "*) indeg[j]=$((indeg[j] - 1)) ;;
                esac
            done
        done
        if [ "$progress" -eq 0 ]; then
            echo "  ${ICON_ERROR:-[ ]} Dependency cycle detected in manifest depends_on" >&2
            return 1
        fi
    done
    return 0
}

# Check if a URL responds healthy (same helper as ftso.sh)
_app_http_ok() {
    local url="$1"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$url" 2>/dev/null || echo "000")
    [ "$code" = "200" ]
}

# Run a manifest healthcheck of type `cmd` inside the service container
_app_cmd_ok() {
    local container="$1"
    local check_cmd="$2"
    "${DOCKER_BIN:-docker}" exec "$container" sh -c "$check_cmd" >/dev/null 2>&1
}

# Dispatch a single health probe for service <index> (container must be known)
# Returns 0 if healthy. Supported types: http (url), cmd (command).
_app_health_ok() {
    local index="$1"
    local container="$2"
    local htype
    htype="$(_app_service_healthcheck_type "$index")"
    case "$htype" in
        http)
            _app_http_ok "$(_app_service_healthcheck_url "$index")"
            ;;
        cmd)
            _app_cmd_ok "$container" "$(_app_service_healthcheck_command "$index")"
            ;;
        *)
            # Unknown or container_running: healthy if the container is up
            _app_container_running "$container"
            ;;
    esac
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

# -- Public Actions -------------------------------------------------------------

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
    local app_name="" arg
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                AIXCL_VERBOSE=1
                export AIXCL_VERBOSE
                ;;
            *)
                if [ -z "$app_name" ]; then
                    app_name="$arg"
                fi
                ;;
        esac
    done
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        _app_usage >&2
        return 1
    fi

    _app_ensure_parser
    _app_ensure_compose

    if ! _app_load_manifest "$app_name"; then
        echo "${ICON_ERROR:-[ ]} Failed to load manifest for app: ${app_name}" >&2
        return 1
    fi

    if ! _app_validate_manifest "apps/${app_name}/app.yaml"; then
        return 1
    fi

    echo ""
    echo "Starting Application: ${app_name}"
    echo "=============================="
    echo ""

    # Provision declared platform resources (vault secrets, postgres) first.
    # Idempotent: safe to run on every start, heals a freshly re-initialised stack.
    if ! _app_provision "$app_name"; then
        echo "  ${ICON_ERROR:-[ ]} Provisioning failed for ${app_name}" >&2
        return 1
    fi

    local svc_count
    svc_count="$(_app_service_count)"
    if [ "$svc_count" -eq 0 ]; then
        echo "  [ ] No services defined in manifest." >&2
        return 1
    fi

    # Honor manifest depends_on: dependencies start (and pass their
    # health checks) before dependents; unresolvable deps fail here.
    local start_order
    if ! start_order="$(_app_resolve_start_order "$svc_count")"; then
        echo "  ${ICON_ERROR:-[ ]} Cannot start ${app_name}: unresolvable service dependencies" >&2
        return 1
    fi

    local started=0
    for i in $start_order; do
        local svc_name svc_container health_type
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
                    local df build_out
                    df="$(_app_service_build_dockerfile "$i")"
                    if build_out="$("${DOCKER_BIN:-docker}" build -f "${abs_ctx}/${df}" -t "localhost/${svc_container}:latest" "$abs_ctx" 2>&1)"; then
                        if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
                            printf '%s\n' "$build_out"
                        fi
                        echo "    [x] ${svc_name} built"
                    else
                        echo "    [ ] ${svc_name} build failed (non-fatal; compose up may pull instead)" >&2
                        printf '%s\n' "$build_out" >&2
                    fi
                else
                    echo "  [ ] Build context not found: ${abs_ctx}" >&2
                fi
            fi
        else
            _app_warn_skipped_build "$i" "$svc_name"
        fi

        # Remove stale container if it exists but isn't running
        if _app_container_exists "$svc_container" && ! _app_container_running "$svc_container"; then
            "${DOCKER_BIN:-docker}" rm -f "$svc_container" >/dev/null 2>&1 || true
        fi

        # Quiet on success; _app_compose_cmd dumps the raw compose output
        # to stderr on failure so the reason is visible
        _app_compose_cmd "$app_name" up -d --no-deps "$svc_container" >/dev/null || {
            echo "  [ ] ${svc_name} failed to start (compose output above)" >&2
            return 1
        }

        # Wait for health check if defined
        health_type="$(_app_service_healthcheck_type "$i")"
        local timeout
        timeout="$(_app_service_healthcheck_timeout "$i")"
        if [ -n "$health_type" ] && [ "$health_type" != "container_running" ]; then
            local wait_start wait_inter elapsed
            wait_inter="$(_app_service_healthcheck_interval "$i")"
            wait_start=$(date +%s)
            local wait_ok=false
            while true; do
            if _app_health_ok "$i" "$svc_container"; then
                wait_ok=true
                break
            fi
            elapsed=$(( $(date +%s) - wait_start ))
            if [ "$elapsed" -ge "$timeout" ]; then
                break
            fi
            sleep "$wait_inter"
        done
        if [ "$wait_ok" = true ]; then
            echo "  ${ICON_SUCCESS:-[x]} ${svc_name}"
        else
            echo "  ${ICON_WARNING:-[!]} ${svc_name} (starting up)"
        fi
    else
        # No health URL -- just check if container is running
        sleep 2
        if _app_container_running "$svc_container"; then
            echo "  ${ICON_SUCCESS:-[x]} ${svc_name}"
        else
            echo "  ${ICON_ERROR:-[ ]} ${svc_name}" >&2
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
    for i in $(seq "$((svc_count - 1))" -1 0); do
        local svc_container
        svc_container="$(_app_service_container_name "$i")"
        if [ -z "$svc_container" ]; then
            continue
        fi
        if _app_container_running "$svc_container"; then
            if _app_compose_cmd "$app_name" stop "$svc_container" >/dev/null 2>&1; then
                # Force remove to prevent restart policy from bringing it back
                "${DOCKER_BIN:-docker}" rm -f "$svc_container" >/dev/null 2>&1 || true
                echo "  ${ICON_SUCCESS:-[x]} ${svc_container}"
            else
                echo "  ${ICON_ERROR:-[ ]} ${svc_container}" >&2
            fi
        fi
    done

    # Remove Prometheus file_sd
    local prom_file="${SCRIPT_DIR}/prometheus/file_sd/${app_name}.json"
    if [ -f "$prom_file" ]; then
        rm -f "$prom_file"
    fi
}

# Usage: app_cmd restart <name>
app_cmd_restart() {
    local app_name="${1:-}"
    app_cmd_stop "$app_name" && app_cmd_start "$app_name"
}

# Usage: app_cmd status <name>
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

    local overall_status="Running"
    local total_services=0
    local healthy_services=0

    echo ""
    echo "${app_name^^} Application Status"
    echo "=============================="
    echo ""
    echo "App: ${app_name}"
    echo "Status: ${overall_status}"
    echo ""
    echo "Services"
    echo "--------------------------------------------------"
    echo ""

    local svc_count
    svc_count="$(_app_service_count)"
    for i in $(seq 0 "$((svc_count - 1))"); do
        local svc_name svc_container htype display_status health_status is_healthy
        svc_name="$(eval "echo \${APP_SERVICE_${i}_NAME:-}" 2>/dev/null || true)"
        svc_container="$(_app_service_container_name "$i")"
        [ -z "$svc_container" ] && continue

        display_status="${ICON_ERROR:-[ ]}"
        health_status=""
        is_healthy=false

        if _app_container_running "$svc_container"; then
            htype="$(_app_service_healthcheck_type "$i")"
            if [ -n "$htype" ] && [ "$htype" != "container_running" ]; then
                if _app_health_ok "$i" "$svc_container"; then
                    display_status="${ICON_SUCCESS:-[x]}"
                    is_healthy=true
                else
                    display_status="${ICON_WARNING:-[!]}"
                    health_status=" (starting up)"
                fi
            else
                display_status="${ICON_SUCCESS:-[x]}"
                is_healthy=true
            fi
        else
            health_status=" (stopped)"
        fi

        total_services=$((total_services + 1))
        if [ "$is_healthy" = "true" ]; then
            healthy_services=$((healthy_services + 1))
        fi

        echo "  ${display_status} ${svc_name}${health_status}"
    done

    echo ""
    if [ "$total_services" -gt 0 ]; then
        echo "Services: ${healthy_services}/${total_services} healthy"
        if [ "$healthy_services" -eq "$total_services" ]; then
            echo "Overall:  ${ICON_SUCCESS:-[x]} All services healthy"
        else
            echo "Overall:  ${ICON_ERROR:-[ ]} Some services unhealthy"
        fi
    else
        echo "Overall:  ${ICON_WARNING:-[!]} No services running"
    fi
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
        else
            local skip_name
            skip_name="$(eval "echo \${APP_SERVICE_${i}_NAME:-}" 2>/dev/null || true)"
            _app_warn_skipped_build "$i" "${skip_name:-service ${i}}"
        fi
    done
    if [ "$built" -eq 0 ]; then
        echo "  No services were built (no service has 'built: true')."
    fi
    echo ""
}

# Usage: app_cmd provision <name>
# Run the manifest provision contract standalone (vault secrets, postgres)
app_cmd_provision() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        return 1
    fi

    _app_ensure_parser
    if ! _app_load_manifest "$app_name"; then
        return 1
    fi

    if ! _app_provision_required; then
        echo "No provision section declared in apps/${app_name}/app.yaml -- nothing to do."
        return 0
    fi

    _app_provision "$app_name"
}

# Usage: app_cmd secrets <name>
# Show the app's provisioned secret values (local development convenience)
app_cmd_secrets() {
    local app_name="${1:-}"
    if [ -z "$app_name" ]; then
        echo "Error: app name required." >&2
        return 1
    fi

    _app_ensure_parser
    if ! _app_load_manifest "$app_name"; then
        return 1
    fi

    _app_provision_show_secrets "$app_name"
}

# -- Remove Application -----------------------------------------------------------

# Usage: app_cmd_remove <name>
# Stops containers, removes them (docker rm -f), and wipes local image caches.
# Does NOT delete the app source directory -- caller must do that manually.
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
    local svc_count removed=0 failed=0
    svc_count="$(_app_service_count)"
    for i in $(seq 0 "$((svc_count - 1))"); do
        local svc_container
        svc_container="$(_app_service_container_name "$i")"
        [ -z "$svc_container" ] && continue

        if _app_container_running "$svc_container"; then
            _app_compose_cmd "$app_name" stop "$svc_container" >/dev/null 2>&1 || true
        fi

        local removed_ok=false
        # Attempt 1: remove by exact name
        if _app_container_exists "$svc_container"; then
            if "${DOCKER_BIN:-docker}" rm -f "$svc_container" >/dev/null 2>&1; then
                removed_ok=true
            else
                # Attempt 2: remove by container ID
                local cid
                cid="$(_app_container_id "$svc_container")"
                if [ -n "$cid" ]; then
                    if "${DOCKER_BIN:-docker}" rm -f "$cid" >/dev/null 2>&1; then
                        removed_ok=true
                    fi
                fi
            fi
        fi

        if [ "$removed_ok" = true ]; then
            echo "  [x] ${svc_container}"
            removed=$((removed + 1))
        else
            echo "  [ ] ${svc_container}"
            failed=$((failed + 1))
        fi
    done

    # 2. Safety sweep: remove any containers matching the app prefix
    local orphan
    orphan=$("${DOCKER_BIN:-docker}" ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^${app_name}[-_]|^dd-${app_name}[-_]" || true)
    if [ -n "$orphan" ]; then
        while IFS= read -r orphan_name; do
            [ -z "$orphan_name" ] && continue
            if "${DOCKER_BIN:-docker}" rm -f "$orphan_name" >/dev/null 2>&1; then
                echo "  [x] ${orphan_name}"
                removed=$((removed + 1))
            else
                echo "  [ ] ${orphan_name}"
                failed=$((failed + 1))
            fi
        done <<< "$orphan"
    fi

    # 3. Remove Prometheus file_sd if present
    local prom_file="${SCRIPT_DIR}/prometheus/file_sd/${app_name}.json"
    if [ -f "$prom_file" ]; then
        rm -f "$prom_file"
    fi

    # 3a. Remove Grafana dashboard files if present (handle both lowercase and uppercase app names)
    local grafana_dash="${SCRIPT_DIR}/grafana/provisioning/dashboards/apps/${app_name}"
    if [ -d "$grafana_dash" ]; then
        rm -rf "$grafana_dash"
    fi

    # 3b. Handle uppercase app name variant (e.g., ftso -> FTSO for display names)
    local grafana_dash_upper
    grafana_dash_upper="${SCRIPT_DIR}/grafana/provisioning/dashboards/apps/$(echo "$app_name" | tr '[:lower:]' '[:upper:]')"
    if [ -d "$grafana_dash_upper" ] && [ "$grafana_dash_upper" != "$grafana_dash" ]; then
        rm -rf "$grafana_dash_upper"
    fi

    # 4. Clean up old symlink path (backward compatibility)
    local old_grafana_dash="${SCRIPT_DIR}/grafana/provisioning/dashboards/${app_name}"
    if [ -L "$old_grafana_dash" ] || [ -d "$old_grafana_dash" ]; then
        rm -rf "$old_grafana_dash"
    fi

    # 4. Clean dangling images (optional)
    "${DOCKER_BIN:-docker}" image prune -f 2>/dev/null || true

    echo ""
    echo "${ICON_SUCCESS:-[x]} Removed ${removed} container(s)."
    echo ""
    echo "NOTE: Source code in apps/${app_name}/ was NOT deleted."
    echo "      Run: rm -rf apps/${app_name}  to delete permanently."
}

# -- Scaffolding ----------------------------------------------------------------

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

# Platform resources provisioned automatically on 'app start' (idempotent).
# Secrets are generated into Vault and rendered to the per-app volume
# aixcl-app-${app_name}-secrets as /run/secrets/${app_name}-<name>.
# Uncomment what your app needs:
# provision:
#   secrets:
#     - db-password
#   postgres:
#     database: ${app_name}
#     owner: ${app_name}
#     password_secret: db-password

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

# -- Installation (Git Submodule) ------------------------------------------------

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
    echo "${ICON_SUCCESS:-[x]} Installation complete: ${app_dir}/"
    echo ""
    echo "Next steps:"
    echo "  1. Edit ${app_dir}/app.yaml to define your services"
    echo "  2. Build: ./aixcl app build ${app_name}"
    echo "  3. Start: ./aixcl app start ${app_name}"
}

# -- Internal helpers ---------------------------------------------------------

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
    # Start with manifest labels (which already include 'app: ftso')
    # NOTE: Prometheus label names must match [a-zA-Z_][a-zA-Z0-9_]* -- keep
    # underscores as-is (converting to dashes produces invalid label names).
    local label_keys
    label_keys="$(env | grep "^APP_PROMETHEUS_LABELS_" | sed 's/^APP_PROMETHEUS_LABELS_//' | sed 's/=.*//' | sort -u)"
    if [ -n "$label_keys" ]; then
        while IFS= read -r key; do
            [ -z "$key" ] && continue
            local val
            val="$(eval "echo \${APP_PROMETHEUS_LABELS_${key}:-}" 2>/dev/null || true)"
            [ -n "$val" ] && labels="${labels}, \"$(echo "$key" | tr '[:upper:]' '[:lower:]')\": \"${val}\""
        done <<< "$label_keys"
    fi

    # Per-app scrape path override (manifest: prometheus.metrics_path).
    # __metrics_path__ is honoured natively by Prometheus file_sd targets.
    if [ -n "${APP_PROMETHEUS_METRICS_PATH:-}" ]; then
        labels="${labels}, \"__metrics_path__\": \"${APP_PROMETHEUS_METRICS_PATH}\""
    fi

    # Fallback: if no labels at all, add app name
    if [ -z "$labels" ]; then
        labels="\"app\": \"${app_name}\""
    else
        # Remove leading comma
        labels="${labels#, }"
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

    echo "  ${ICON_SUCCESS:-[x]} Prometheus targets"
}

# Copy Grafana dashboards from app into platform provisioning
_app_wire_grafana() {
    local app_name="${1:-}"
    local app_dir="${SCRIPT_DIR}/apps/${app_name}"
    local platform_dash="${SCRIPT_DIR}/grafana/provisioning/dashboards/apps/${app_name}"

    if [ -d "${app_dir}/grafana/dashboards" ]; then
        # Copy dashboard JSON files into dedicated apps/ subdirectory
        # This avoids UID collisions with AIXCL platform dashboards
        mkdir -p "$platform_dash"
        cp -f "${app_dir}"/grafana/dashboards/*.json "$platform_dash/" 2>/dev/null || true
    fi
}

# -- Dispatcher entry point -----------------------------------------------------

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
        provision)
            app_cmd_provision "$@"
            ;;
        secrets)
            app_cmd_secrets "$@"
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
