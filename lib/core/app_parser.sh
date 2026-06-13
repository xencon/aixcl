#!/usr/bin/env bash
# App manifest parser for AIXCL
# Reads YAML manifests at apps/<name>/app.yaml and exports shell variables
# Safe: uses Python3-yaml (pre-installed on Ubuntu), never eval() or sources user input
#
# Usage:
#   _app_load_manifest "ftso"
#   echo "$APP_NAME"
#   echo "$APP_SERVICE_0_NAME"
#
# Dependencies: python3-yaml (python3-yaml package on Debian/Ubuntu)

_APP_PARSER_YAML_TOOL="${APP_PARSER_YAML_TOOL:-python3}"

# Verify python3-yaml is available
_app_has_yaml_parser() {
    ${_APP_PARSER_YAML_TOOL} -c "import yaml; import sys; sys.exit(0)" >/dev/null 2>&1
}

# Returns the Python script used to convert YAML to shell export statements.
# This is defined as a function so it can be used both for standalone parsing
# and for _app_load_manifest injection.
_app_yaml_to_shell_script() {
    cat << 'PYEOF'
import yaml, sys, re
import base64
import json

def safe(value):
    if value is None:
        return ''
    s = str(value)
    # Escape single quotes for shell safety
    s = s.replace("'", "'\''")
    return s

def flatten(obj, prefix='APP'):
    if isinstance(obj, dict):
        for k, v in obj.items():
            key_part = re.sub(r'[^A-Z0-9_]', '_', str(k).upper())
            new_key = f"{prefix}_{key_part}"
            flatten(v, new_key)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            flatten(v, f"{prefix}_{i}")
    else:
        v = safe(obj)
        print(f"export {prefix}='{v}'")

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)

if data is None:
    sys.exit(0)

if 'app' in data:
    flatten(data['app'], 'APP')
if 'services' in data:
    for i, svc in enumerate(data['services']):
        flatten(svc, f"APP_SERVICE_{i}")
if 'provision' in data:
    flatten(data['provision'], 'APP_PROVISION')
if 'prometheus' in data:
    flatten(data['prometheus'], 'APP_PROMETHEUS')
if 'grafana' in data:
    flatten(data['grafana'], 'APP_GRAFANA')
if 'submodules' in data:
    flatten(data['submodules'], 'APP_SUBMODULE')
PYEOF
}

# Generate a temporary Python file with the parser script and return its path.
# The caller must remove the file after use.
_app_yaml_parser_file() {
    local tmpf
    tmpf="$(mktemp /tmp/aixcl_app_parser.XXXXXX.py)"
    _app_yaml_to_shell_script > "$tmpf" || { rm -f "$tmpf"; return 1; }
    echo "$tmpf"
}

# Load manifest variables into current shell environment
# Sets: APP_NAME, APP_VERSION, APP_DESCRIPTION, APP_SERVICE_0_NAME, etc.
_app_load_manifest() {
    local app_name="$1"
    local manifest="apps/${app_name}/app.yaml"

    if [ ! -f "$manifest" ]; then
        echo "[ ] Error: Manifest not found: ${manifest}" >&2
        return 1
    fi

    if ! _app_has_yaml_parser; then
        echo "[ ] Error: python3-yaml not installed. Run: sudo apt-get install python3-yaml" >&2
        return 1
    fi

    local parser_file
    parser_file="$(_app_yaml_parser_file)"
    if [ -z "$parser_file" ] || [ ! -f "$parser_file" ]; then
        echo "[ ] Error: Failed to create temporary parser file" >&2
        return 1
    fi

    local exports
    exports="$(${_APP_PARSER_YAML_TOOL} "$parser_file" "$manifest" 2>/dev/null)"
    local py_exit=$?
    rm -f "$parser_file"

    if [ $py_exit -ne 0 ] || [ -z "$exports" ]; then
        echo "[ ] Error: Failed to parse manifest: ${manifest}" >&2
        return 1
    fi

    eval "$exports"
    return 0
}

# Discover all apps with valid manifests
_app_discover() {
    local found=0
    for app_dir in apps/*/; do
        if [ ! -d "$app_dir" ]; then
            continue
        fi
        local name
        name="$(basename "$app_dir")"
        if [ -f "${app_dir}app.yaml" ]; then
            echo "$name"
            found=$((found + 1))
        fi
    done
    if [ $found -eq 0 ]; then
        return 1
    fi
    return 0
}

# Validate manifest structure (basic required fields)
_app_validate_manifest() {
    local manifest="$1"
    local errors=0

    # Load variables first
    local app_name app_version
    app_name="${APP_NAME:-}"
    app_version="${APP_VERSION:-}"

    if [ -z "$app_name" ]; then
        echo "  [ ] Error: missing app.name" >&2
        errors=$((errors + 1))
    fi

    if [ -z "$app_version" ]; then
        echo "  [ ] Error: missing app.version" >&2
        errors=$((errors + 1))
    fi

    if [ $errors -gt 0 ]; then
        return 1
    fi
    return 0
}

# Count services defined in a loaded manifest
_app_service_count() {
    local count=0
    while true; do
        local svc_name
        svc_name="$(eval "echo \${APP_SERVICE_${count}_NAME:-}" 2>/dev/null || true)"
        if [ -z "$svc_name" ]; then
            break
        fi
        count=$((count + 1))
    done
    echo "$count"
}

# Export functions for app.sh
export -f _app_has_yaml_parser _app_yaml_to_shell_script _app_yaml_parser_file
export -f _app_load_manifest _app_discover _app_validate_manifest _app_service_count
