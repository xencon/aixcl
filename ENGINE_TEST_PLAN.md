# AIXCL Engine Testing Plan - Methodical Approach

## Objective
Test all three inference engines (Ollama, vLLM, llama.cpp) with the dev container setup.

## Test Order
1. **Ollama** (baseline - already tested) ✅ COMPLETE
2. **vLLM** (GPU required) - IN PROGRESS
3. **llama.cpp** (GPU + GGUF models) - PENDING

## Test Criteria

### For Each Engine:
- [ ] Dev container builds successfully
- [ ] AIXCL stack starts with engine
- [ ] Engine shows healthy status
- [ ] Model downloads successfully
- [ ] Model responds to API queries
- [ ] OpenCode connects and works
- [ ] No bind mount or permission errors

## Cleanup Between Tests
```bash
# Stop everything
./aixcl stack stop
docker compose -f .devcontainer/docker-compose.dev.yml down -v

# Clear environment
unset COMPOSE_FILE
```

## Documentation
Each test will be documented with:
- Test date/time
- Engine version
- Model tested
- Success/failure status
- Any issues encountered
