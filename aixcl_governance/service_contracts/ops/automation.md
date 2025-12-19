# Service Contract — Automation Stack

**Category:** Operational Services  
**Enforcement Level:** Guided

## Purpose
Automates container updates, restarts, and lifecycle management. Includes Watchtower for automatic container image updates.

## Depends On
- Docker daemon (for container management)
- Runtime core (for monitoring and updating containers)

## Exposes
- Automatic container image updates
- Container restart capabilities
- Lifecycle management hooks

## Must Not Depend On
- Business logic or inference workflows
- Service-specific application logic
- Monitoring/logging services (may observe but not depend on)

## Notes
- Watchtower operates at the container orchestration level
- Should not interfere with runtime service availability
- Updates should be configurable and reversible
