# Migration Guide: Old to New AIXCL Structure

## Overview

AIXCL has been refactored from a monolithic script to a modular structure. This guide helps you migrate from the old `aixcl` script to the new `aixcl.sh` structure.

## Key Changes

### Command Structure

**Old (flat structure):**
```bash
./aixcl start
./aixcl stop
./aixcl models add phi3
./aixcl council configure
```

**New (nested structure):**
```bash
./aixcl.sh stack start
./aixcl.sh stack stop
./aixcl.sh models add phi3
./aixcl.sh council configure
```

### Main Changes

1. **Stack commands** now require `stack` prefix:
   - `aixcl start` → `aixcl.sh stack start`
   - `aixcl stop` → `aixcl.sh stack stop`
   - `aixcl status` → `aixcl.sh stack status`
   - `aixcl logs` → `aixcl.sh stack logs`
   - `aixcl clean` → `aixcl.sh stack clean`

2. **Service commands** unchanged:
   - `aixcl service start postgres` → `aixcl.sh service start postgres`

3. **Models commands** unchanged:
   - `aixcl models add phi3` → `aixcl.sh models add phi3`

4. **Council commands** unchanged:
   - `aixcl council configure` → `aixcl.sh council configure`

5. **Dashboard commands** unchanged:
   - `aixcl dashboard grafana` → `aixcl.sh dashboard grafana`

6. **Utils commands** now require `utils` prefix:
   - `aixcl check-env` → `aixcl.sh utils check-env`
   - `aixcl bash-completion` → `aixcl.sh utils bash-completion`

## Migration Steps

### 1. Update Script References

If you have scripts or aliases using the old commands:

**Old:**
```bash
alias aixcl-start='./aixcl start'
```

**New:**
```bash
alias aixcl-start='./aixcl.sh stack start'
```

### 2. Update Documentation

Update any documentation, README files, or scripts that reference old commands.

### 3. Update Bash Completion

If you had bash completion installed:

```bash
./aixcl.sh utils bash-completion
```

This will install completion for the new structure.

### 4. Test New Commands

Run through your common workflows:

```bash
# Test stack commands
./aixcl.sh stack status
./aixcl.sh stack start

# Test other commands
./aixcl.sh models list
./aixcl.sh council status
```

## Command Mapping Table

| Old Command | New Command |
|------------|-------------|
| `aixcl start` | `aixcl.sh stack start` |
| `aixcl stop` | `aixcl.sh stack stop` |
| `aixcl restart` | `aixcl.sh stack restart` |
| `aixcl status` | `aixcl.sh stack status` |
| `aixcl logs [svc]` | `aixcl.sh stack logs [svc]` |
| `aixcl clean` | `aixcl.sh stack clean` |
| `aixcl service <action> <name>` | `aixcl.sh service <action> <name>` |
| `aixcl models <action>` | `aixcl.sh models <action>` |
| `aixcl council <action>` | `aixcl.sh council <action>` |
| `aixcl dashboard <name>` | `aixcl.sh dashboard <name>` |
| `aixcl check-env` | `aixcl.sh utils check-env` |
| `aixcl bash-completion` | `aixcl.sh utils bash-completion` |
| `aixcl help` | `aixcl.sh help` |

## What's Preserved

- All functionality is preserved
- Environment variables (`.env` file) unchanged
- Docker Compose configuration unchanged
- Service configurations unchanged
- Database schemas unchanged

## What's New

- Modular code structure (easier to maintain)
- Better error messages with color coding
- Improved test suite
- Better documentation
- Removed unused frontend code

## Rollback

If you need to use the old script temporarily:

```bash
# Old script is still available
./aixcl start  # Old structure
./aixcl.sh stack start  # New structure
```

However, the old script will not receive updates. We recommend migrating to the new structure.

## Getting Help

- Run `./aixcl.sh help` for command overview
- Check `docs/CLI_SPEC.md` for detailed specification
- Check `docs/USAGE.md` for usage examples
- Run tests: `bash tests/test_baseline.sh`

## Questions?

If you encounter issues during migration:

1. Check that all files are executable: `chmod +x aixcl.sh cli/*.sh lib/*.sh`
2. Verify Docker is running: `docker info`
3. Check service status: `./aixcl.sh stack status`
4. Review logs: `./aixcl.sh stack logs <service>`
