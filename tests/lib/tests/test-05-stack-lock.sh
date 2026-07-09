#!/usr/bin/env bash
# Test 05: stack lifecycle lock (lib/core/lock.sh, issue #1802)
# No running stack required -- exercises the lock helpers in isolation.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/core/lock.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-05-stack-lock"

# Isolate the lock from any real aixcl run on this host
_lock_tmp_dir="$(mktemp -d)"
export XDG_RUNTIME_DIR="$_lock_tmp_dir"
unset AIXCL_STACK_LOCK_HELD 2>/dev/null || true

lock_file="$(_stack_lock_path)"

# ---------------------------------------------------------------------------
# Acquire creates a lock file recording this PID and the command label
# ---------------------------------------------------------------------------

acquire_stack_lock "test acquire" \
    && log_success "acquire_stack_lock succeeds on free lock" \
    || { log_error "acquire_stack_lock failed on free lock"; false; }

assert_file_exists "$lock_file" "lock file created"
assert_file_contains "$lock_file" "pid=$$" "lock file records holder PID"
assert_file_contains "$lock_file" "command=test acquire" "lock file records command label"

# ---------------------------------------------------------------------------
# Reentrancy: a second acquire in the same run is a no-op success
# ---------------------------------------------------------------------------

acquire_stack_lock "test reacquire" \
    && log_success "acquire_stack_lock is reentrant while held" \
    || { log_error "reentrant acquire failed"; false; }

assert_file_contains "$lock_file" "command=test acquire" \
    "reentrant acquire does not rewrite the lock file"

# ---------------------------------------------------------------------------
# A child process that inherited the held-lock marker must not release
# the parent's lock (prune -> ./aixcl stack stop boundary)
# ---------------------------------------------------------------------------

bash -c "source '${SCRIPT_DIR}/lib/core/lock.sh'; release_stack_lock" || true
assert_file_exists "$lock_file" "child process cannot release parent's lock"

# ---------------------------------------------------------------------------
# Release removes the lock file
# ---------------------------------------------------------------------------

release_stack_lock
if [ ! -f "$lock_file" ]; then
    log_success "release_stack_lock removes the lock file"
else
    log_error "lock file still present after release"
    false
fi

# ---------------------------------------------------------------------------
# Contention: a lock held by a live process is respected
# ---------------------------------------------------------------------------

sleep 60 &
_holder_pid=$!
printf 'pid=%s\ncommand=other run\nstarted=now\n' "$_holder_pid" > "$lock_file"

set +e
contention_output="$( (unset AIXCL_STACK_LOCK_HELD; acquire_stack_lock "test contender") 2>&1 )"
contention_exit=$?
set -e

[ "$contention_exit" -ne 0 ] \
    && log_success "acquire fails while a live holder owns the lock" \
    || { log_error "acquire succeeded despite live holder"; false; }
assert_string_contains "$contention_output" "already in progress" \
    "contention message says an operation is in progress"
assert_string_contains "$contention_output" "pid=${_holder_pid}" \
    "contention message identifies the holder PID"

kill "$_holder_pid" 2>/dev/null || true
wait "$_holder_pid" 2>/dev/null || true
rm -f "$lock_file"

# ---------------------------------------------------------------------------
# Staleness: a lock whose holder is dead is broken and re-acquired
# (covers a prior run killed with SIGKILL, where traps never fired)
# ---------------------------------------------------------------------------

sleep 0.1 &
_dead_pid=$!
wait "$_dead_pid" 2>/dev/null || true
printf 'pid=%s\ncommand=dead run\nstarted=long ago\n' "$_dead_pid" > "$lock_file"

set +e
stale_output="$( (unset AIXCL_STACK_LOCK_HELD; acquire_stack_lock "test stale-break" \
    && assert_file_contains "$(_stack_lock_path)" "command=test stale-break" \
        "stale lock replaced by new holder") 2>&1 )"
stale_exit=$?
set -e

[ "$stale_exit" -eq 0 ] \
    && log_success "acquire breaks a stale lock from a dead holder" \
    || { log_error "acquire failed to break stale lock: $stale_output"; false; }
assert_string_contains "$stale_output" "stale" \
    "stale-break announces the removed lock"

rm -rf "$_lock_tmp_dir"

log_test_pass "Stack lifecycle lock behaves correctly"
