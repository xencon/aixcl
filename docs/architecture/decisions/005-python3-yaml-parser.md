# ADR 005 -- Python3 for YAML Manifest Parsing

| Field | Value |
|-------|-------|
| Status | Accepted |
| Decided | Platform design (pre-v1.0) |
| Authority | lib/core/app_parser.sh |

## Context

App manifests are YAML files. The AIXCL CLI is written in bash. Bash has no
native YAML parsing capability. A tool must be chosen for the conversion.

Candidates evaluated: `yq`, `jq` (with YAML input mode), Python3 `yaml` module.

## Decision

`lib/core/app_parser.sh` uses Python3 with the `PyYAML` library (`python3-yaml`
package on Debian/Ubuntu) to convert YAML manifests into shell `export` statements,
which are then evaluated in the calling shell.

## Rationale

- **Safety**: The Python script runs in a subprocess and produces only `export VAR='value'`
  statements with single-quote escaping. The calling shell evaluates this output -- it
  never evals user-supplied YAML directly.
- **Availability**: Python3 is a standard dependency on Ubuntu/Debian (the target platform).
  `python3-yaml` is a minimal, stable package with no transitive dependencies.
- **Correctness**: PyYAML is a full YAML 1.1 parser. `yq` versions vary significantly in
  behaviour across distributions; pinning it would add a versioning problem.
- **`jq` limitation**: `jq` cannot parse YAML natively -- it would require a pre-conversion
  step (e.g., `yq` to JSON first), adding complexity and another dependency.

## What This Means for Agents

- Do NOT replace the Python3 parser with `yq`, `jq`, or a bash awk/sed approach.
- The check `_app_has_yaml_parser` verifies Python3-yaml at runtime. If it fails,
  direct the user to: `sudo apt-get install python3-yaml`
- The Python script is generated into a temp file at runtime (`mktemp`) and cleaned
  up after each parse. It is not committed to the repo.
- If the parser needs to support a new YAML field, update the Python script in
  `_app_yaml_to_shell_script()` in `app_parser.sh`.

## Security Note

The `eval` call in `_app_load_manifest()` evaluates Python-generated output only.
The Python script uses `yaml.safe_load()` (not `yaml.load()`) and escapes single
quotes in values. The shell never evaluates user-supplied strings directly.
