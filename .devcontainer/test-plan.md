# Dev Container Test Plan - Complete Workflow

## Test Objective
Verify end-to-end dev container functionality including:
1. Clean build and start
2. AIXCL stack startup
3. Model addition
4. OpenCode integration

## Test Environment
- Host: WSL2 Ubuntu 22.04
- Docker: Docker-in-Docker enabled
- GPU: NVIDIA RTX (optional)
- Branch: issue-875/dev-container-phase2

## Test Steps

### Phase 1: Clean Setup
1. Stop any running services
2. Remove dev container if exists
3. Rebuild from scratch
4. Enter container
5. Verify environment

### Phase 2: AIXCL Startup
1. Run ./aixcl utils check-env
2. Start stack with sys profile
3. Wait for services to be healthy
4. Verify Ollama is running

### Phase 3: Model Management
1. Add qwen2.5-coder:0.5b model
2. Verify model is listed
3. Check opencode.json updated

### Phase 4: OpenCode Test
1. Start OpenCode CLI
2. Test basic prompt
3. Verify response from local model
4. Exit OpenCode

### Phase 5: Cleanup
1. Stop AIXCL services
2. Exit container
3. Document results

## Expected Results
- All services start successfully
- Model downloads and loads
- OpenCode connects to local API
- Responses received from model

## Success Criteria
- [ ] Dev container builds without errors
- [ ] AIXCL stack shows 2/2 healthy
- [ ] Model appears in ollama list
- [ ] OpenCode responds with model output
- [ ] No permission or bind mount errors
