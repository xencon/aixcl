# Model Persistence and Protection Guide

## Overview

Ollama models are stored in Docker volumes. This document explains how models are persisted and how to prevent accidental deletion.

## How Models Are Stored

- **Location**: Models are stored in the `ollama` Docker volume
- **Volume Path**: `/root/.ollama` inside the container
- **Persistence**: Models persist across container restarts as long as the volume exists

## Potential Causes of Model Loss

### 1. Hash-Prefixed Container Names

**Problem**: Docker Compose may create containers with hash prefixes (e.g., `a9f302029b81_ollama`) instead of the expected name `ollama`. This can cause:
- Model listing commands to fail
- Container operations to fail
- Test scripts to report "no models found" even when models exist

**Solution**: The codebase now includes `get_ollama_container()` function that automatically detects and handles hash-prefixed containers.

### 2. Volume Pruning

**Problem**: Running `docker volume prune` when the Ollama container is stopped can delete the `ollama` volume, removing all models.

**Prevention**:
- The `stack clean` command includes safeguards to protect the Ollama volume
- Always ensure the Ollama container is running before running volume cleanup operations
- Use `./aixcl stack clean` instead of manual `docker volume prune`

### 3. Container Recreation Without Volume

**Problem**: Removing the Ollama container without preserving the volume will lose models.

**Prevention**:
- Use `./aixcl service restart ollama` instead of manual container removal
- Never use `docker rm -f ollama` without ensuring the volume is preserved

### 4. Manual Model Removal

**Problem**: Using `ollama rm <model>` or `./aixcl models remove <model>` will permanently delete models.

**Prevention**:
- Be cautious when removing models
- Consider backing up important models before removal

## Safeguards Implemented

1. **Hash-Prefixed Container Detection**: All `docker exec ollama` commands now use `get_ollama_container()` to find the actual container name
2. **Volume Protection in `stack clean`**: The cleanup command checks if the Ollama volume exists and warns before deletion
3. **Container Name Resolution**: Functions like `get_available_models()` now work correctly with hash-prefixed containers

## Best Practices

1. **Always use AIXCL commands**: Use `./aixcl` commands instead of direct Docker commands when possible
2. **Check container status**: Before cleanup operations, verify Ollama is running: `./aixcl stack status`
3. **Backup important models**: Before major operations, list your models: `./aixcl models list`
4. **Monitor volume usage**: Check volume status: `docker volume ls | grep ollama`

## Troubleshooting

### Models Not Found in Tests

If tests report "no models found" but models actually exist:

1. Check if the container has a hash prefix:
   ```bash
   docker ps | grep ollama
   ```

2. Verify models exist:
   ```bash
   ./aixcl models list
   ```

3. If the container has a hash prefix, restart it:
   ```bash
   ./aixcl service restart ollama
   ```

### Models Lost After Container Restart

If models disappear after restarting:

1. Check if the volume still exists:
   ```bash
   docker volume ls | grep ollama
   ```

2. Check volume mount in docker-compose:
   ```bash
   grep -A 5 "ollama:" services/docker-compose.yml
   ```

3. Verify volume is mounted:
   ```bash
   docker inspect ollama | grep -A 10 Mounts
   ```

## Recovery

If models are accidentally deleted:

1. **Re-download models**: Use `./aixcl models add <model-name>` to re-download
2. **Check backups**: If you have volume backups, restore them
3. **Prevent future loss**: Review and follow the best practices above

## Related Commands

- `./aixcl models list` - List all installed models
- `./aixcl models add <model>` - Add a model
- `./aixcl models remove <model>` - Remove a model (use with caution)
- `./aixcl stack status` - Check service status
- `./aixcl stack clean` - Clean up resources (safeguarded)
