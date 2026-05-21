#!/usr/bin/env bash
# FTSO Application Services — AIXCL integration
#
# Startup order: dd-ftso-v2-provider → ftso-price-monitor → ftso-monitor-agent
# CCXT market-load failures trigger automatic provider restart (up to FTSO_MAX_MARKET_RETRIES).
# No exec/eval; all failures raise or enter a named documented fallback.

readonly FTSO_PROVIDER_HEALTH_URL="http://127.0.0.1:3101/api-doc"
readonly FTSO_PRICE_MONITOR_HEALTH_URL="http://127.0.0.1:9102/metrics"
readonly FTSO_MAX_PROVIDER_WAIT=18    # 18 × 10 s = 3 min
readonly FTSO_MAX_MARKET_RETRIES=3
readonly FTSO_MARKET_RETRY_WAIT=30    # seconds to wait after CCXT-induced restart

# ── Private helpers ───────────────────────────────────────────────────────────

_ftso_http_ok() {
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" \
           --connect-timeout 3 --max-time 5 "$1" 2>/dev/null || echo "000")
    [ "$code" = "200" ]
}

_ftso_running() {
    "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" 2>/dev/null | grep -q "^${1}$"
}

_ftso_ccxt_failed() {
    "${DOCKER_BIN:-docker}" logs --tail=50 dd-ftso-v2-provider 2>/dev/null \
        | grep -q "Removing exchange, restart provider to try again"
}

_ftso_wait_provider() {
    local i=1
    while [ "$i" -le "$FTSO_MAX_PROVIDER_WAIT" ]; do
        _ftso_http_ok "$FTSO_PROVIDER_HEALTH_URL" && return 0
        printf "  Waiting for FTSO provider (%d/%d)...\r" "$i" "$FTSO_MAX_PROVIDER_WAIT"
        sleep 10
        i=$((i + 1))
    done
    echo ""
    return 1
}

_ftso_wait_price_monitor() {
    local i=1 max=12
    while [ "$i" -le "$max" ]; do
        _ftso_http_ok "$FTSO_PRICE_MONITOR_HEALTH_URL" && return 0
        printf "  Waiting for FTSO price monitor (%d/%d)...\r" "$i" "$max"
        sleep 10
        i=$((i + 1))
    done
    echo ""
    return 1
}

_ftso_ensure_compose() {
    if [ -z "${COMPOSE_CMD[*]:-}" ]; then
        set_compose_cmd
    fi
}

# ── Public API ────────────────────────────────────────────────────────────────

start_ftso_services() {
    echo ""
    echo "Starting Application Services (FTSO)..."
    _ftso_ensure_compose

    # 1 — Provider (with CCXT market-load retry)
    echo "  Starting dd-ftso-v2-provider..."
    run_compose up -d --no-deps dd-ftso-v2-provider \
        || { echo "[ ] Failed to start dd-ftso-v2-provider" >&2; return 1; }

    local attempt=1
    while [ "$attempt" -le "$FTSO_MAX_MARKET_RETRIES" ]; do
        if _ftso_wait_provider; then
            echo "  [x] dd-ftso-v2-provider healthy"
            break
        fi
        if _ftso_ccxt_failed && [ "$attempt" -lt "$FTSO_MAX_MARKET_RETRIES" ]; then
            echo "  ⚠️  CCXT market-load failure (attempt $attempt/$FTSO_MAX_MARKET_RETRIES) — restarting provider..."
            run_compose restart dd-ftso-v2-provider 2>/dev/null || true
            sleep "$FTSO_MARKET_RETRY_WAIT"
        else
            echo "[ ] dd-ftso-v2-provider failed to become healthy after $attempt attempt(s)" >&2
            return 1
        fi
        attempt=$((attempt + 1))
    done

    # 2 — Price monitor
    echo "  Starting ftso-price-monitor..."
    run_compose up -d --no-deps ftso-price-monitor \
        || { echo "[ ] Failed to start ftso-price-monitor" >&2; return 1; }
    _ftso_wait_price_monitor \
        || { echo "[ ] ftso-price-monitor did not become healthy within timeout" >&2; return 1; }
    echo "  [x] ftso-price-monitor healthy"

    # 3 — Monitor agent (no HTTP endpoint; running is sufficient)
    echo "  Starting ftso-monitor-agent..."
    run_compose up -d --no-deps ftso-monitor-agent \
        || { echo "[ ] Failed to start ftso-monitor-agent" >&2; return 1; }
    sleep 3
    if _ftso_running ftso-monitor-agent; then
        echo "  [x] ftso-monitor-agent running"
    else
        echo "[ ] ftso-monitor-agent failed to start" >&2
        return 1
    fi

    echo ""
    echo "[x] All FTSO application services started."
}

stop_ftso_services() {
    _ftso_ensure_compose
    local svcs_to_stop=()
    for svc in ftso-monitor-agent ftso-price-monitor dd-ftso-v2-provider; do
        if _ftso_running "$svc"; then
            svcs_to_stop+=("$svc")
        fi
    done
    [ ${#svcs_to_stop[@]} -eq 0 ] && return 0
    echo "Stopping FTSO application services..."
    local n=0
    for svc in "${svcs_to_stop[@]}"; do
        run_compose stop "$svc" 2>/dev/null || true
        n=$((n + 1))
    done
    echo "  [x] Stopped $n FTSO service(s)."
}

# Called from stack status() — increments caller's total_services / healthy_services
print_ftso_status() {
    echo ""
    echo "Application Services"
    _ftso_ensure_compose

    local icon note
    # Provider
    icon="${ICON_ERROR:-❌}"; note=""
    if _ftso_running dd-ftso-v2-provider; then
        if _ftso_http_ok "$FTSO_PROVIDER_HEALTH_URL"; then
            icon="${ICON_SUCCESS:-✅}"; ((healthy_services++)) || true
        else
            icon="${ICON_WARNING:-⚠️}"; note=" (starting)"
        fi
    fi
    ((total_services++)) || true
    echo "  ${icon} FTSO Provider${note}"

    # Price monitor
    icon="${ICON_ERROR:-❌}"; note=""
    if _ftso_running ftso-price-monitor; then
        if _ftso_http_ok "$FTSO_PRICE_MONITOR_HEALTH_URL"; then
            icon="${ICON_SUCCESS:-✅}"; ((healthy_services++)) || true
        else
            icon="${ICON_WARNING:-⚠️}"; note=" (starting)"
        fi
    fi
    ((total_services++)) || true
    echo "  ${icon} FTSO Price Monitor${note}"

    # Monitor agent (no HTTP endpoint)
    icon="${ICON_ERROR:-❌}"
    if _ftso_running ftso-monitor-agent; then
        icon="${ICON_SUCCESS:-✅}"; ((healthy_services++)) || true
    fi
    ((total_services++)) || true
    echo "  ${icon} FTSO Monitor Agent"
}

ftso_heal() {
    echo "FTSO Heal"
    echo "========="
    echo ""
    _ftso_ensure_compose
    local healed=0

    if _ftso_running dd-ftso-v2-provider; then
        if _ftso_http_ok "$FTSO_PROVIDER_HEALTH_URL"; then
            echo "  [x] dd-ftso-v2-provider healthy"
        else
            echo "  ⚠️  dd-ftso-v2-provider unhealthy — restarting..."
            run_compose restart dd-ftso-v2-provider 2>/dev/null || true
            healed=$((healed + 1))
        fi
    else
        echo "  ❌ dd-ftso-v2-provider not running — starting..."
        run_compose up -d --no-deps dd-ftso-v2-provider 2>/dev/null || true
        healed=$((healed + 1))
    fi

    if _ftso_running ftso-price-monitor; then
        if _ftso_http_ok "$FTSO_PRICE_MONITOR_HEALTH_URL"; then
            echo "  [x] ftso-price-monitor healthy"
        else
            echo "  ⚠️  ftso-price-monitor unhealthy — restarting..."
            run_compose restart ftso-price-monitor 2>/dev/null || true
            healed=$((healed + 1))
        fi
    else
        echo "  ❌ ftso-price-monitor not running — starting..."
        run_compose up -d --no-deps ftso-price-monitor 2>/dev/null || true
        healed=$((healed + 1))
    fi

    if _ftso_running ftso-monitor-agent; then
        echo "  [x] ftso-monitor-agent running"
    else
        echo "  ❌ ftso-monitor-agent not running — starting..."
        run_compose up -d --no-deps ftso-monitor-agent 2>/dev/null || true
        healed=$((healed + 1))
    fi

    echo ""
    if [ "$healed" -eq 0 ]; then
        echo "All FTSO services are healthy. No remediation required."
    else
        echo "Remediation applied to $healed service(s). Run './aixcl ftso status' to verify."
    fi
}

ftso_logs() {
    local follow=false tail_count=100 filter=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -f|--follow)               follow=true; shift ;;
            [0-9]*)                    tail_count="$1"; shift ;;
            dd-ftso-v2-provider|provider)  filter="dd-ftso-v2-provider"; shift ;;
            ftso-price-monitor|price-monitor) filter="ftso-price-monitor"; shift ;;
            ftso-monitor-agent|agent)  filter="ftso-monitor-agent"; shift ;;
            *)
                echo "[ ] Unknown FTSO service '$1'. Valid: provider, price-monitor, agent" >&2
                return 1 ;;
        esac
    done

    if [ -n "$filter" ]; then
        if [ "$follow" = true ]; then
            "${DOCKER_BIN:-docker}" logs --follow --tail="$tail_count" "$filter" 2>/dev/null || true
        else
            "${DOCKER_BIN:-docker}" logs --tail="$tail_count" "$filter" 2>/dev/null \
                || echo "  (no logs available)"
        fi
        return 0
    fi

    local svcs=(dd-ftso-v2-provider ftso-price-monitor ftso-monitor-agent)
    for s in "${svcs[@]}"; do
        if "${DOCKER_BIN:-docker}" ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${s}$"; then
            echo "=== $s ==="
            "${DOCKER_BIN:-docker}" logs --tail="$tail_count" "$s" 2>/dev/null \
                || echo "  (no logs available)"
            echo ""
        fi
    done

    if [ "$follow" = true ]; then
        echo "Following FTSO logs (Ctrl+C to stop)..."
        echo ""
        local pids=()
        trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT INT TERM
        for s in "${svcs[@]}"; do
            "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" 2>/dev/null | grep -q "^${s}$" || continue
            ( "${DOCKER_BIN:-docker}" logs --follow "$s" 2>/dev/null | sed "s/^/[$s] /" || true ) &
            pids+=($!)
        done
        [ ${#pids[@]} -gt 0 ] && wait "${pids[@]}" 2>/dev/null || true
        trap - EXIT INT TERM
    fi
}

ftso_cmd() {
    if [ $# -lt 1 ]; then
        echo "Usage: ./aixcl ftso {start|stop|restart|status|logs|heal}"
        echo ""
        echo "  start    Start FTSO services in dependency order (with CCXT retry)"
        echo "  stop     Stop FTSO services in reverse dependency order"
        echo "  restart  Stop then start FTSO services"
        echo "  status   Show FTSO service health"
        echo "  logs     Show logs  [-f] [<lines>] [provider|price-monitor|agent]"
        echo "  heal     Detect and remediate unhealthy FTSO services"
        echo ""
        echo "Examples:"
        echo "  ./aixcl ftso start"
        echo "  ./aixcl ftso logs -f"
        echo "  ./aixcl ftso logs provider 50"
        echo "  ./aixcl ftso heal"
        return 1
    fi

    local action="$1"; shift
    case "$action" in
        start)
            start_ftso_services "$@"
            ;;
        stop)
            _ftso_ensure_compose
            stop_ftso_services
            ;;
        restart)
            _ftso_ensure_compose
            stop_ftso_services
            sleep 3
            start_ftso_services
            ;;
        status)
            _ftso_ensure_compose
            local total_services=0 healthy_services=0
            echo ""
            echo "FTSO Application Services"
            echo "========================="
            print_ftso_status
            echo ""
            echo "Services: $healthy_services/$total_services healthy"
            ;;
        logs)
            ftso_logs "$@"
            ;;
        heal)
            ftso_heal
            ;;
        *)
            echo "[ ] Unknown ftso action: '$action'" >&2
            echo "    Valid: start stop restart status logs heal" >&2
            return 1 ;;
    esac
}
