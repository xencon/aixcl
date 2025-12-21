# Profile Refactoring: core/dev/ops/full → usr/dev/ops/sys

## Date: 2025-01-XX

## Summary

AIXCL profiles have been refactored to use a new naming convention that better reflects their orientation and purpose. The service compositions remain identical - only the profile names have changed.

## Profile Mapping

| Old Profile | New Profile | Orientation | Services | DB Storage |
|------------|-------------|-------------|----------|------------|
| core | usr | User-oriented | ollama, llm-council | false (file-based) |
| dev | dev | Developer-oriented | ollama, llm-council, open-webui, postgres, pgadmin | true |
| ops | ops | Operations-oriented | ollama, llm-council, postgres, prometheus, grafana, loki, promtail, cadvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter | true |
| full | sys | System-oriented | ollama, llm-council, open-webui, postgres, pgadmin, prometheus, grafana, loki, promtail, cadvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter, watchtower | true |

## Changes Made

### Code Changes

1. **cli/lib/profile.sh**
   - Updated `VALID_PROFILES` array: `(core dev ops full)` → `(usr dev ops sys)`
   - Updated `PROFILE_DESCRIPTIONS` associative array with new profile names and descriptions
   - Updated `PROFILE_SERVICES` associative array with new profile keys
   - Updated `PROFILE_DB_STORAGE` associative array with new profile keys

2. **aixcl** (main CLI script)
   - Updated all help text examples (lines 484-487)
   - Updated error messages with valid profiles list (line 496)
   - Updated conditional logic: `if [ "$profile" = "core" ]` → `if [ "$profile" = "usr" ]` (line 572)
   - Updated profile descriptions in help output (lines 1553-1556)
   - Updated usage examples (lines 2584-2588)
   - Updated valid profiles list (line 2597)
   - Updated comment references (line 560)

3. **tests/platform-tests.sh**
   - Updated usage comments (lines 16-19)
   - Renamed test functions: `test_profile_core` → `test_profile_usr`, `test_profile_full` → `test_profile_sys`
   - Updated error messages (line 1359, 1481)
   - Updated case statement for profile selection (lines 1485-1496)
   - Updated example commands (line 1461)

### Documentation Changes

1. **aixcl_governance/02_profiles.md**
   - Updated profile overview table (Section 2)
   - Renamed `core` section to `usr` (Section 3.1)
   - Renamed `full` section to `sys` (Section 3.4)
   - Updated all descriptions to reflect user/system orientation
   - Updated profile selection guidelines (Section 4)

2. **README.md**
   - Updated profile list in architecture section (line 38)

3. **docs/usage.md**
   - Updated profile list in architecture section (line 22)

## Migration Guide

### For Users

**Breaking Change**: This is a breaking change. All CLI commands using profiles must be updated.

**Before:**
```bash
./aixcl stack start --profile core
./aixcl stack start --profile full
```

**After:**
```bash
./aixcl stack start --profile usr
./aixcl stack start --profile sys
```

**Profile Name Changes:**
- `core` → `usr` (user-oriented runtime)
- `dev` → `dev` (unchanged)
- `ops` → `ops` (unchanged)
- `full` → `sys` (system-oriented complete stack)

### For Scripts and Automation

Update any scripts or automation that reference profile names:
- Replace `--profile core` with `--profile usr`
- Replace `--profile full` with `--profile sys`
- `dev` and `ops` profiles remain unchanged

### For Tests

Update test commands:
```bash
# Before
./tests/platform-tests.sh --profile core
./tests/platform-tests.sh --profile full

# After
./tests/platform-tests.sh --profile usr
./tests/platform-tests.sh --profile sys
```

## Rationale

The new naming convention better reflects the orientation and purpose of each profile:

- **usr** (user-oriented): Emphasizes end-user deployment scenarios
- **dev** (developer-oriented): Unchanged, clearly developer-focused
- **ops** (operations-oriented): Unchanged, clearly operations-focused
- **sys** (system-oriented): Emphasizes complete system deployment with automation

This naming makes it clearer which profile to choose based on the deployment context and audience.

## Service Compositions

**Important**: Service compositions remain **identical**. Only profile names changed.

- **usr**: Runtime core only (ollama, llm-council) with file-based persistence
- **dev**: Runtime core + UI + Database (ollama, llm-council, open-webui, postgres, pgadmin)
- **ops**: Runtime core + Database + Monitoring + Logging (all observability services)
- **sys**: All services including automation (watchtower)

## Testing Checklist

After refactoring, verify:

- [x] Profile validation works (`is_valid_profile`)
- [x] Profile descriptions display correctly
- [x] Profile services list correctly
- [x] DB storage setting works for each profile
- [ ] Stack start with each profile works
- [ ] Help text shows new profiles
- [ ] Error messages show new profiles
- [ ] Platform tests run with each profile
- [ ] Documentation is consistent

## Files Modified

1. `cli/lib/profile.sh` - Profile definitions
2. `aixcl` - Main CLI script
3. `tests/platform-tests.sh` - Test suite
4. `aixcl_governance/02_profiles.md` - Governance documentation
5. `README.md` - Main documentation
6. `docs/usage.md` - Usage documentation
7. `build-docs/PROFILE_REFACTORING.md` - This file

## Backward Compatibility

**This is a breaking change.** There is no backward compatibility layer. Users must update their commands and scripts to use the new profile names.

## Related Documentation

- `aixcl_governance/02_profiles.md` - Complete profile definitions
- `aixcl_governance/00_invariants.md` - Platform invariants
- `aixcl_governance/01_ai_guidance.md` - AI assistant guidance

