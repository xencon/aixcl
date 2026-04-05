# Icon Usage Guidelines

This document defines the icon usage policy for AIXCL output.

## Policy

Unicode icons are permitted and encouraged for visual feedback in user-facing output, particularly for:
- Status indicators (✅ ❌)
- Warnings and info (⚠️ ℹ️)

## Icon Standards

| Purpose | Icon | Usage |
|---------|------|-------|
| Success | ✅ | Operation completed successfully |
| Error | ❌ | Operation failed |
| Warning | ⚠️ | Attention required |
| Info | ℹ️ | Informational message |

## Implementation

Icons should be:
- Used consistently across similar operations
- Defined as constants in `lib/core/color.sh`
- Combined with color coding for maximum clarity
- Used in user-facing output (not logs)

## Examples

```bash
# Status output
echo "${ICON_SUCCESS} Service is running"
echo "${ICON_ERROR} Service failed"
echo "${ICON_WARNING} Attention required"
echo "${ICON_INFO} Informational message"
```

## Verification

Before submitting changes with icons:

- [ ] Icons render correctly in terminal
- [ ] Icons are appropriate for the context
- [ ] Icons are defined as constants, not hardcoded
