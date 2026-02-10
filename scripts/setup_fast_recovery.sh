#!/usr/bin/env bash
# Setup Fast Recovery for AIXCL
# Caches all images to local registry for fast recovery after directory removal
# Run this BEFORE removing the aixcl directory

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Configuration
LOCAL_REGISTRY="localhost:5000"
REGISTRY_CONTAINER="local_registry"
SERVICES_DIR="${SCRIPT_DIR}/services"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "\n${BLUE}→${NC} $1"; }

echo "=========================================="
echo "AIXCL Fast Recovery Setup"
echo "=========================================="
echo ""
info "This script caches all images to local registry for fast recovery"
info "Run this BEFORE removing the aixcl directory"
echo ""

# Step 1: Check current state
step "Step 1: Checking current state..."

# Check if registry exists
if docker ps -aq -f name=$REGISTRY_CONTAINER >/dev/null 2>&1; then
    if docker ps -q -f name=$REGISTRY_CONTAINER >/dev/null 2>&1; then
        success "Local registry '$REGISTRY_CONTAINER' is running"
    else
        info "Registry container exists but is stopped"
    fi
else
    info "Registry container does not exist (will be created)"
fi

# Check volumes
volumes=$(docker volume ls --format "{{.Name}}" | grep -E "ollama|postgres" || echo "")
if [ -n "$volumes" ]; then
    ollama_vol=$(echo "$volumes" | grep ollama | head -1)
    if [ -n "$ollama_vol" ]; then
        vol_size=$(docker system df -v 2>/dev/null | grep "$ollama_vol" | awk '{print $3}' || echo "unknown")
        success "Ollama models volume found: $ollama_vol ($vol_size)"
        info "Your Ollama models will be preserved"
    fi
else
    warning "No Ollama volumes found - models will need to be re-downloaded"
fi

# Check existing images
if [ -f "$SERVICES_DIR/docker-compose.yml" ]; then
    image_count=$(grep -E "^[[:space:]]*image:" "$SERVICES_DIR/docker-compose.yml" | wc -l)
    info "Found $image_count image references in docker-compose.yml"
fi

# Check for .env file and backup if exists
ENV_BACKUP_VOLUME="aixcl-env-backup"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    info "Found .env file - will backup to preserve configuration"
    # Create backup volume if it doesn't exist
    if ! docker volume ls --format "{{.Name}}" | grep -q "^${ENV_BACKUP_VOLUME}$"; then
        docker volume create "$ENV_BACKUP_VOLUME" >/dev/null 2>&1
        info "Created backup volume: $ENV_BACKUP_VOLUME"
    fi
    
    # Backup .env to volume using a temporary container
    docker run --rm \
        -v "${SCRIPT_DIR}/.env:/source/.env:ro" \
        -v "${ENV_BACKUP_VOLUME}:/backup" \
        alpine sh -c "cp /source/.env /backup/.env && chmod 600 /backup/.env" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        success ".env file backed up to Docker volume: $ENV_BACKUP_VOLUME"
    else
        warning "Failed to backup .env file (will need manual restoration)"
    fi
else
    info "No .env file found (will be created from .env.example on next start)"
fi

echo ""

# Step 2: Start/ensure registry is running
step "Step 2: Ensuring local registry is running..."

if [ "$(docker ps -aq -f name=$REGISTRY_CONTAINER)" ]; then
    if [ "$(docker ps -q -f name=$REGISTRY_CONTAINER)" ]; then
        success "Registry already running"
    else
        info "Starting existing registry container..."
        docker start "$REGISTRY_CONTAINER" || {
            error "Failed to start registry container"
            exit 1
        }
        success "Registry started"
    fi
else
    info "Creating new local Docker registry..."
    docker run -d --name "$REGISTRY_CONTAINER" -p 5000:5000 --restart=always registry:2 || {
        error "Failed to create registry container"
        exit 1
    }
    success "Registry created and started"
fi

# Wait for registry to be ready
info "Waiting for registry to be ready..."
for i in {1..10}; do
    if curl -s http://${LOCAL_REGISTRY}/v2/ >/dev/null 2>&1; then
        success "Registry is ready"
        break
    fi
    if [ $i -eq 10 ]; then
        warning "Registry may not be fully ready, but continuing..."
    else
        sleep 1
    fi
done

echo ""

# Step 3: Cache pre-built images
step "Step 3: Caching pre-built images from docker-compose.yml..."

cd "$SERVICES_DIR"

if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found!"
    exit 1
fi

images=$(grep -E "^[[:space:]]*image:" docker-compose.yml | awk '{print $2}' | sort -u)
total_images=$(echo "$images" | wc -l)
cached_count=0
failed_count=0

if [ -z "$images" ]; then
    warning "No images found in docker-compose.yml"
else
    info "Found $total_images unique image(s) to cache"
    echo ""
    
    for img in $images; do
        # Skip council (handled separately)
        if [ "$img" = "council:latest" ]; then
            continue
        fi
        
        local_img="$LOCAL_REGISTRY/${img//\//_}"
        
        # Check if already cached
        repo_name="${local_img#localhost:5000/}"
        cached_tags=$(curl -s "http://${LOCAL_REGISTRY}/v2/${repo_name}/tags/list" 2>/dev/null | jq -r '.tags[]' 2>/dev/null || echo "")
        
        if [ -n "$cached_tags" ]; then
            info "[$cached_count/$total_images] $img (already cached)"
            cached_count=$((cached_count + 1))
            continue
        fi
        
        info "[$((cached_count + failed_count + 1))/$total_images] Caching $img..."
        
        # Pull image
        if docker pull "$img" >/dev/null 2>&1; then
            # Tag for local registry
            docker tag "$img" "$local_img" 2>/dev/null || true
            
            # Push to local registry
            if docker push "$local_img" >/dev/null 2>&1; then
                success "  Cached: $img → $local_img"
                cached_count=$((cached_count + 1))
            else
                warning "  Failed to push $img"
                failed_count=$((failed_count + 1))
            fi
        else
            warning "  Failed to pull $img (may not be available)"
            failed_count=$((failed_count + 1))
        fi
    done
fi

echo ""
info "Pre-built images: $cached_count cached, $failed_count failed"

# Step 4: Build and cache council
step "Step 4: Building and caching council..."

# Check if already cached
cached_tags=$(curl -s "http://${LOCAL_REGISTRY}/v2/council/tags/list" 2>/dev/null | jq -r '.tags[]' 2>/dev/null || echo "")
  if [ -n "$cached_tags" ]; then
    success "council already cached in registry"
    info "Skipping build (use --force to rebuild)"
    if [ "$1" != "--force" ]; then
        skip_build=true
    fi
fi

if [ "$skip_build" != "true" ]; then
    # Set up compose command (check for GPU/ARM overrides)
    COMPOSE_CMD="docker-compose -f docker-compose.yml"
    
    # Check for GPU override
    if [ -f "docker-compose.gpu.yml" ] && command -v nvidia-smi >/dev/null 2>&1; then
        COMPOSE_CMD="${COMPOSE_CMD} -f docker-compose.gpu.yml"
        info "Detected GPU, using GPU compose override"
    fi
    
    # Check for ARM override
    if [ -f "docker-compose.arm.yml" ] && [ "$(uname -m)" = "aarch64" ]; then
        COMPOSE_CMD="${COMPOSE_CMD} -f docker-compose.arm.yml"
        info "Detected ARM64, using ARM compose override"
    fi
    
    info "Building council image (this may take a few minutes)..."
    if $COMPOSE_CMD build council >/dev/null 2>&1; then
        success "council built successfully"
        
        # Tag and push to local registry
        LOCAL_IMAGE="${LOCAL_REGISTRY}/council:latest"
        if docker tag "council:latest" "$LOCAL_IMAGE" 2>/dev/null; then
            if docker push "$LOCAL_IMAGE" >/dev/null 2>&1; then
                success "council cached in local registry"
            else
                warning "Failed to push council (may already exist)"
            fi
        else
            warning "Failed to tag council"
        fi
    else
        error "Failed to build council"
        exit 1
    fi
fi

echo ""

# Step 5: Verify and summarize
step "Step 5: Verifying cached images..."

repos=$(curl -s "http://${LOCAL_REGISTRY}/v2/_catalog" 2>/dev/null | jq -r '.repositories[]' 2>/dev/null || echo "")
if [ -z "$repos" ]; then
    warning "Registry appears empty (images may still be available)"
else
    repo_count=$(echo "$repos" | wc -l)
    success "Found $repo_count cached repository/repositories in registry"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
success "Fast recovery is now configured"
echo ""
info "What was cached:"
echo "  • $cached_count pre-built images"
echo "  • council (built and cached)"
echo ""
info "What will persist after directory removal:"
echo "  • Docker volumes (Ollama models, database, etc.)"
echo "  • Local registry container (cached images)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    echo "  • .env file (backed up to Docker volume: $ENV_BACKUP_VOLUME)"
fi
echo ""
info "Recovery procedure after fresh clone:"
echo "  1. git clone <repo-url> aixcl"
echo "  2. cd aixcl"
echo "  3. ./scripts/registry.sh start"
echo "  4. ./aixcl stack start --profile sys"
echo "     (will automatically restore .env from backup if available)"
echo ""
info "Recovery time: ~1 minute (vs ~7-15 minutes without caching)"
echo ""
info "To view cached images:"
echo "  curl http://${LOCAL_REGISTRY}/v2/_catalog | jq"
echo ""

