#!/usr/bin/env bash
# Build and push LLM-Council container to local registry

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Configuration
LOCAL_REGISTRY="localhost:5000"
REGISTRY_CONTAINER="local_registry"
SERVICES_DIR="${SCRIPT_DIR}/services"
IMAGE_NAME="llm-council"
IMAGE_TAG="latest"
LOCAL_IMAGE="${LOCAL_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=========================================="
echo "Building and Pushing LLM-Council"
echo "=========================================="
echo ""

# Step 1: Start local registry
echo "Step 1: Starting local Docker registry..."
if [ "$(docker ps -aq -f name=$REGISTRY_CONTAINER)" ]; then
    if [ "$(docker ps -q -f name=$REGISTRY_CONTAINER)" ]; then
        echo "✓ Local registry '$REGISTRY_CONTAINER' already running."
    else
        echo "Starting existing registry container..."
        docker start "$REGISTRY_CONTAINER" || {
            echo "Failed to start registry container"
            exit 1
        }
    fi
else
    echo "Creating new local Docker registry..."
    docker run -d --name "$REGISTRY_CONTAINER" -p 5000:5000 --restart=always registry:2 || {
        echo "Failed to create registry container"
        exit 1
    }
fi

# Wait for registry to be ready
echo "Waiting for registry to be ready..."
for i in {1..10}; do
    if curl -s http://${LOCAL_REGISTRY}/v2/ >/dev/null 2>&1; then
        echo "✓ Registry is ready"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "⚠ Warning: Registry may not be fully ready, but continuing..."
    else
        sleep 1
    fi
done

echo ""

# Step 2: Build the image using docker-compose
echo "Step 2: Building LLM-Council image..."
cd "$SERVICES_DIR"

# Set up compose command (check for GPU/ARM overrides)
COMPOSE_CMD="docker-compose -f docker-compose.yml"

# Check for GPU override
if [ -f "docker-compose.gpu.yml" ] && command -v nvidia-smi >/dev/null 2>&1; then
    COMPOSE_CMD="${COMPOSE_CMD} -f docker-compose.gpu.yml"
    echo "Detected GPU, using GPU compose override"
fi

# Check for ARM override
if [ -f "docker-compose.arm.yml" ] && [ "$(uname -m)" = "aarch64" ]; then
    COMPOSE_CMD="${COMPOSE_CMD} -f docker-compose.arm.yml"
    echo "Detected ARM64, using ARM compose override"
fi

echo "Building image with: $COMPOSE_CMD build $IMAGE_NAME"
if $COMPOSE_CMD build $IMAGE_NAME; then
    echo "✓ Image built successfully"
else
    echo "✗ Failed to build image"
    exit 1
fi

echo ""

# Step 3: Tag the image for local registry
echo "Step 3: Tagging image for local registry..."
if docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${LOCAL_IMAGE}"; then
    echo "✓ Image tagged as ${LOCAL_IMAGE}"
else
    echo "✗ Failed to tag image"
    exit 1
fi

echo ""

# Step 4: Push to local registry
echo "Step 4: Pushing image to local registry..."
if docker push "${LOCAL_IMAGE}"; then
    echo "✓ Image pushed successfully to ${LOCAL_IMAGE}"
else
    echo "✗ Failed to push image"
    exit 1
fi

echo ""

# Step 5: Verify the image is in the registry
echo "Step 5: Verifying image in registry..."
if curl -s "http://${LOCAL_REGISTRY}/v2/${IMAGE_NAME}/tags/list" | grep -q "${IMAGE_TAG}"; then
    echo "✓ Image verified in registry"
else
    echo "⚠ Warning: Could not verify image in registry (may still be available)"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Image: ${LOCAL_IMAGE}"
echo "Registry: http://${LOCAL_REGISTRY}"
echo ""
echo "To use this image, update docker-compose.yml:"
echo "  Change 'build:' to 'image: ${LOCAL_IMAGE}'"
echo ""
echo "To view images in registry:"
echo "  curl http://${LOCAL_REGISTRY}/v2/_catalog | jq"
echo ""
