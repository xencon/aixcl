#!/usr/bin/env bash
# pgAdmin utility functions

# Get script directory (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Generate pgAdmin configuration
generate_pgadmin_config() {
    echo "Generating pgAdmin server configuration..."

    # Note: With Vault integration, credentials are dynamic
    # pgAdmin will need to use static bootstrap credentials or Vault-generated credentials
    local pg_user="${POSTGRES_USER:-admin}"
    local pg_pass="${POSTGRES_PASSWORD:-}"
    local pgadmin_uid="${PGADMIN_USER_ID:-5050}"
    local pgadmin_gid="${PGADMIN_GROUP_ID:-5050}"

    # Remove old file if it exists (may have wrong permissions from container)
    # NOTE: If Podman previously created this as a directory mount point,
    # rmdir the empty directory first, then rm the file.
    if [ -d "${SCRIPT_DIR}/pgadmin-servers.json" ]; then
        rmdir "${SCRIPT_DIR}/pgadmin-servers.json" 2>/dev/null || true
    fi
    # A prior run of this function may have chowned the file into the
    # pgadmin container's rootless-mapped UID (see below) -- the invoking
    # host user cannot rm a file it no longer owns, so remove it from
    # within the same user namespace that owns it (#1922).
    podman unshare rm -f "${SCRIPT_DIR}/pgadmin-servers.json" 2>/dev/null \
        || rm -f "${SCRIPT_DIR}/pgadmin-servers.json" 2>/dev/null || true

    # Create pgadmin-servers.json with populated environment values
    cat > "${SCRIPT_DIR}/pgadmin-servers.json" << EOF
{
  "Servers": {
    "1": {
      "Group": "Servers",
      "Name": "AIXCL",
      "Host": "localhost",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "${pg_user}",
      "Password": "${pg_pass}",
      "SSLMode": "prefer",
      "Favorite": true
    }
  }
}
EOF

    # Restrict to owner-only before handing ownership to the container's
    # identity, minimizing the window where the file is host-user-owned
    # and could be group/other readable.
    chmod 600 "${SCRIPT_DIR}/pgadmin-servers.json"

    # This file is bind-mounted into the pgadmin container, which runs as
    # a non-root UID (5050 by default) under rootless podman's user
    # namespace -- that UID maps to a HOST uid outside the invoking
    # user's own identity (verified: container uid 5050 -> host uid
    # 105049 in one deployment), so a plain 644 was previously used to
    # let the container read a file it doesn't match by owner. That made
    # a file containing a live Postgres password world-readable on the
    # host. `podman unshare chown` performs the chown from within the
    # rootless user namespace, translating the container-relative
    # UID:GID into the correct host-mapped identity, so the file can stay
    # 600 and still be readable by the one process that needs it (#1922).
    if podman unshare chown "${pgadmin_uid}:${pgadmin_gid}" "${SCRIPT_DIR}/pgadmin-servers.json" 2>/dev/null; then
        echo "✅ Generated pgadmin-servers.json, restricted to the pgadmin container's UID (600)"
    else
        # Fail closed, not open: the file already exists at 600, host-owned
        # (set above) -- leave it there rather than widening to 644. A 644
        # fallback previously wrote a live PostgreSQL password world-
        # readable on the host whenever podman unshare failed for any
        # reason. The tradeoff here is a functional one, not a security
        # one: pgAdmin's automatic server-list import will not be able to
        # read the file (the connection can be added manually in the UI),
        # but the password never lands somewhere every host user can read
        # it (#1997).
        echo "ERROR: Could not map servers.json to the pgadmin container's UID (podman unshare failed)."
        echo "  Leaving the file at 600, host-owned -- pgAdmin will NOT auto-import its server list."
        echo "  Add the connection manually in the pgAdmin UI, or fix rootless Podman setup"
        echo "  (see scripts/utils/setup-podman-rootless.sh) and restart pgadmin to retry."
        return 1
    fi
    echo "   Note: With Vault enabled, use dynamic credentials from './aixcl vault credentials'"
}
