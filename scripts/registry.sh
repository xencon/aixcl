#!/bin/bash
set -e

# --- Configuration ---
COMPOSE_FILE="docker-compose.yml"                  # original compose
LOCAL_COMPOSE="docker-compose.local.yml"           # local compose output
LOCAL_REGISTRY="localhost:5000"                    # local registry
REGISTRY_CONTAINER="local_registry"

# --- Detect repo root ---
REPO_ROOT=$(pwd)
echo "Repo root detected: $REPO_ROOT"

# --- Handle local registry ---
if [ "$(docker ps -aq -f name=$REGISTRY_CONTAINER)" ]; then
    # Container exists
    if [ "$(docker ps -q -f name=$REGISTRY_CONTAINER)" ]; then
        echo "Local registry '$REGISTRY_CONTAINER' is already running."
    else
        # Check if port 5000 is free
        if lsof -i :5000 >/dev/null; then
            echo "Local registry container exists but port 5000 is in use. Assuming registry is running."
        else
            echo "Starting existing local registry '$REGISTRY_CONTAINER'..."
            docker start "$REGISTRY_CONTAINER"
        fi
    fi
else
    echo "Starting local Docker registry..."
    docker run -d --name "$REGISTRY_CONTAINER" -p 5000:5000 --restart=always registry:2
fi

# --- Prepare local compose file ---
cp "$COMPOSE_FILE" "$LOCAL_COMPOSE"
echo "Local compose ready: $LOCAL_COMPOSE"

# --- Extract images dynamically ---
# Note: Using [[:space:]] instead of \s for POSIX compliance (works on macOS/BSD grep)
images=$(grep -E "^[[:space:]]*image:" "$COMPOSE_FILE" | awk '{print $2}')

for img in $images; do
    # Sanitize image name for local registry
    local_img="$LOCAL_REGISTRY/${img//\//_}"

    echo "Caching $img → $local_img"

    # Pull original image, tag for local registry, push
    docker pull "$img"
    docker tag "$img" "$local_img"
    docker push "$local_img"

    # Replace image in local compose
    sed -i "s|image: $img|image: $local_img|g" "$LOCAL_COMPOSE"
done

echo "All images cached locally."
echo "Local compose file ready at: $LOCAL_COMPOSE"

