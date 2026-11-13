#!/usr/bin/env bash
# Workflow Test: PostgreSQL admin password resync from Vault (#2059)
# Runs the postgres image from services/docker-compose.yml in a throwaway
# container with postgres-secret-entrypoint.sh and a fake Vault secret file,
# then changes the secret against the kept data volume -- the Vault-only
# reinit case -- and checks the live password follows it. Does not touch
# the platform stack; needs only a container runtime and the image.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-postgres-password-resync"

if ! command -v docker > /dev/null 2>&1; then
    log_test_skip "no container runtime (docker/podman shim) available"
    exit 0
fi

IMAGE=$(awk '/^  postgres:/{f=1} f && /image:/{print $2; exit}' \
    "${SCRIPT_DIR}/services/docker-compose.yml")
ENTRYPOINT="${SCRIPT_DIR}/scripts/runtime/postgres-secret-entrypoint.sh"
NAME="aixcl-test-pg-resync"
VOLUME="aixcl-test-pg-resync-data"
SECRETS_DIR=""
FAILURES=0

cleanup() {
    docker rm -f "$NAME" > /dev/null 2>&1 || true
    docker volume rm -f "$VOLUME" > /dev/null 2>&1 || true
    [[ -n "$SECRETS_DIR" ]] && rm -rf "$SECRETS_DIR"
    return 0
}
trap cleanup EXIT
cleanup
SECRETS_DIR=$(mktemp -d)
chmod 755 "$SECRETS_DIR"

# Start postgres with the given Vault secret, mirroring the compose service
# (UID 999, cap_drop ALL, scram auth, same entrypoint and data mount).
start_with_secret() {
    printf '%s' "$1" > "${SECRETS_DIR}/postgres-password"
    chmod 644 "${SECRETS_DIR}/postgres-password"
    docker rm -f "$NAME" > /dev/null 2>&1 || true
    docker run -d --name "$NAME" --user 999:999 --cap-drop ALL \
        --security-opt no-new-privileges:true \
        -e POSTGRES_USER=aixcl -e POSTGRES_DATABASE=aixcl \
        -e POSTGRES_HOST_AUTH_METHOD=scram-sha-256 \
        -e POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256 --auth-local=scram-sha-256" \
        -v "${VOLUME}:/var/lib/postgresql" \
        -v "${SECRETS_DIR}:/run/secrets:ro" \
        -v "${ENTRYPOINT}:/usr/local/bin/postgres-secret-entrypoint.sh:ro" \
        --entrypoint /usr/local/bin/postgres-secret-entrypoint.sh \
        "$IMAGE" postgres -c listen_addresses=127.0.0.1 > /dev/null || return 1
    local _
    for _ in $(seq 1 60); do
        if docker exec "$NAME" pg_isready -h 127.0.0.1 -U aixcl > /dev/null 2>&1; then
            sleep 1
            return 0
        fi
        sleep 1
    done
    log_error "postgres did not become ready"
    docker logs "$NAME" 2>&1 | tail -20
    return 1
}

can_login() {
    docker exec -e PGPASSWORD="$1" "$NAME" \
        psql -h 127.0.0.1 -U aixcl -d postgres -Atc 'select 1' > /dev/null 2>&1
}

expect_login() {
    local description="$1" want="$2" password="$3" got=no
    can_login "$password" && got=yes
    if [[ "$got" == "$want" ]]; then
        log_success "$description"
    else
        log_error "$description (login=${got}, expected=${want})"
        FAILURES=$((FAILURES + 1))
    fi
}

PASS_A="alpha-$(date +%s)"
PASS_B="bravo-$(date +%s)"
PASS_C="q'uo%te\$x\"y-$(date +%s)"

log_info "Image: ${IMAGE}"

log_info "1/4 empty volume, first init"
if start_with_secret "$PASS_A"; then
    expect_login "initial password accepted" yes "$PASS_A"
else
    FAILURES=$((FAILURES + 1))
fi

log_info "2/4 restart with unchanged secret"
if start_with_secret "$PASS_A"; then
    expect_login "password still accepted after restart" yes "$PASS_A"
else
    FAILURES=$((FAILURES + 1))
fi

log_info "3/4 Vault-only reinit -- new secret, kept data volume"
if start_with_secret "$PASS_B"; then
    expect_login "new Vault password accepted" yes "$PASS_B"
    expect_login "old password rejected" no "$PASS_A"
else
    FAILURES=$((FAILURES + 1))
fi

log_info "4/4 secret containing SQL and shell metacharacters"
if start_with_secret "$PASS_C"; then
    expect_login "metacharacter password accepted" yes "$PASS_C"
    expect_login "previous password rejected" no "$PASS_B"
    expect_login "arbitrary password rejected over TCP" no "not-the-password"
else
    FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -eq 0 ]]; then
    log_test_pass "password follows the Vault secret across restarts and reinit"
    exit 0
fi
log_test_fail "${FAILURES} resync check(s) failed"
exit 1
