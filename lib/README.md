# AIXCL Library Modules

This directory contains shared library modules for the AIXCL project.

## Structure

```
lib/
├── core/           # Core utility libraries
│   ├── color.sh    # Terminal color/formatting utilities
│   ├── common.sh   # Common functions (env loading, service validation)
│   ├── docker_utils.sh  # Docker/Compose utilities
│   ├── env_check.sh     # Environment validation
│   ├── logging.sh       # Logging utilities
│   └── pgadmin_utils.sh # pgAdmin utilities
└── cli/            # CLI-specific libraries
    └── profile.sh  # Profile management (ops, sys)
```

## Usage

Source libraries from scripts using the SCRIPT_DIR variable:

```bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/lib/core/color.sh"
source "${SCRIPT_DIR}/lib/core/common.sh"
source "${SCRIPT_DIR}/lib/cli/profile.sh"
```

## Dependencies

- `core/color.sh` - No dependencies (source first)
- `core/common.sh` - No dependencies (source second)
- `core/docker_utils.sh` - Depends on common.sh
- `core/logging.sh` - Depends on color.sh
- `core/env_check.sh` - Depends on common.sh, docker_utils.sh
- `core/pgadmin_utils.sh` - Depends on common.sh
- `cli/profile.sh` - Depends on common.sh
