#!/usr/bin/env bash
# Whole-stack lifecycle lock (issue #1802)
#
# Two concurrent `stack start` runs corrupt each other's Vault bootstrap
# state: the artifact-clearing step deletes KV secrets the other run has
# just stored, and rm -f / run sidecar management collides on container
# names. This lock serializes whole-stack lifecycle commands (stack
# start/stop/restart, utils prune) so a second invocation refuses cleanly.
#
# Design notes:
# - The lock is a PID file created atomically with noclobber (O_EXCL).
#   flock(1) was deliberately rejected: a lock held on an inherited file
#   descriptor leaks into conmon behind detached containers, so the lock
#   would remain held by the running stack after start completes
#   (verified empirically on rootless Podman 4.9.3).
# - Keyed to the invoking user, not the repo clone: two clones on one
#   host drive the same rootless Podman instance, so the lock must be
#   host-user-wide.
# - Staleness self-heals: if the recorded holder PID is no longer alive
#   (e.g. the run was SIGKILLed and traps never fired), the next
#   contender breaks the lock and proceeds. There is a theoretical
#   window where two contenders break the same stale lock, but O_EXCL
#   creation guarantees only one acquires it on retry.
# - Reentrant across the run: restart calls stop+start in-process, and
#   utils prune shells out to `./aixcl stack stop`. The exported
#   AIXCL_STACK_LOCK_HELD marker crosses both boundaries; only the
#   process that acquired the lock (tracked by unexported owner PID)
#   releases it.

_stack_lock_path() {
    echo "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/aixcl-stack-$(id -u).lock"
}

# Acquire the stack lifecycle lock, or fail with a message identifying
# the in-progress run. Usage: acquire_stack_lock "stack start" || return 1
acquire_stack_lock() {
    local label="${1:-stack operation}"

    # Already held by this run (same process, or a parent that spawned us)
    if [ "${AIXCL_STACK_LOCK_HELD:-}" = "1" ]; then
        return 0
    fi

    local lock_file
    lock_file="$(_stack_lock_path)"

    local attempt
    for attempt in 1 2 3; do
        if (set -o noclobber; printf 'pid=%s\ncommand=%s\nstarted=%s\n' \
                "$$" "$label" "$(date '+%Y-%m-%d %H:%M:%S')" > "$lock_file") 2>/dev/null; then
            export AIXCL_STACK_LOCK_HELD=1
            _AIXCL_STACK_LOCK_OWNER="$$"
            # Release on any exit; INT/TERM route through the EXIT trap.
            trap 'release_stack_lock' EXIT
            trap 'exit 130' INT
            trap 'exit 143' TERM
            return 0
        fi

        # Lock exists -- is its holder still alive?
        local holder_pid
        holder_pid="$(grep -m1 '^pid=' "$lock_file" 2>/dev/null | cut -d= -f2)"
        if [ -n "$holder_pid" ] && kill -0 "$holder_pid" 2>/dev/null; then
            echo "[ ] Error: another stack operation is already in progress:" >&2
            sed 's/^/      /' "$lock_file" >&2 2>/dev/null || true
            echo "    Wait for it to finish. If it is genuinely dead, remove: $lock_file" >&2
            return 1
        fi

        # Holder is gone (crashed or SIGKILLed): break the stale lock and
        # retry. Only remove if it still names the dead PID we checked, so
        # we never delete a lock a faster contender just created.
        if [ "$(grep -m1 '^pid=' "$lock_file" 2>/dev/null | cut -d= -f2)" = "$holder_pid" ]; then
            echo "   Removing stale stack lock (holder PID ${holder_pid:-unknown} no longer running)"
            rm -f "$lock_file"
        fi
    done

    echo "[ ] Error: could not acquire stack lock after ${attempt} attempts: $lock_file" >&2
    return 1
}

# Release the lock if -- and only if -- this process acquired it. Child
# processes that inherited AIXCL_STACK_LOCK_HELD must never remove the
# parent's lock file.
release_stack_lock() {
    if [ "${_AIXCL_STACK_LOCK_OWNER:-}" != "$$" ]; then
        return 0
    fi
    rm -f "$(_stack_lock_path)"
    unset AIXCL_STACK_LOCK_HELD
    unset _AIXCL_STACK_LOCK_OWNER
}
