#!/usr/bin/env bash
set -e

# --- Configuration ---
LOCAL_REGISTRY="localhost:5000"
REGISTRY_CONTAINER="local_registry"

# --- Detect repo root ---
REPO_ROOT=$(pwd)
echo "Repo root detected: $REPO_ROOT"

# --- Functions ---
start_registry() {
    if [ "$(docker ps -aq -f name=$REGISTRY_CONTAINER)" ]; then
        if [ "$(docker ps -q -f name=$REGISTRY_CONTAINER)" ]; then
            echo "Local registry '$REGISTRY_CONTAINER' already running."
        else
            echo "Starting existing registry container '$REGISTRY_CONTAINER'..."
            docker start "$REGISTRY_CONTAINER"
        fi
    else
        echo "Starting new local Docker registry..."
        docker run -d --name "$REGISTRY_CONTAINER" -p 5000:5000 --restart=always registry:2
    fi
}

stop_registry() {
    if [ "$(docker ps -q -f name=$REGISTRY_CONTAINER)" ]; then
        echo "Stopping local registry..."
        docker stop "$REGISTRY_CONTAINER"
    else
        echo "Registry not running."
    fi
}

list_images() {
    echo "Images in local registry:"
    curl -s http://$LOCAL_REGISTRY/v2/_catalog | jq
}

cache_images() {
    # Find all docker-compose*.yml files except local ones
    for COMPOSE_FILE in $(find "$REPO_ROOT" -maxdepth 1 -type f -name "docker-compose*.yml" ! -name "*.local.yml"); do
        LOCAL_COMPOSE="${COMPOSE_FILE%.yml}.local.yml"
        cp "$COMPOSE_FILE" "$LOCAL_COMPOSE"
        echo "Processing compose: $COMPOSE_FILE → $LOCAL_COMPOSE"

        # Extract images dynamically
        images=$(grep -E "^[[:space:]]*image:" "$COMPOSE_FILE" | awk '{print $2}')
        for img in $images; do
            # Sanitize image name for local registry
            local_img="$LOCAL_REGISTRY/${img//\//_}"
            echo "Caching $img → $local_img"

            # Pull, tag, push
            docker pull "$img"
            docker tag "$img" "$local_img"
            docker push "$local_img"

            # Replace image in local compose (cross-platform sed)
            if sed --version >/dev/null 2>&1; then
                # GNU sed
                sed -i "s|image: $img|image: $local_img|g" "$LOCAL_COMPOSE"
            else
                # BSD/macOS sed
                sed -i '' "s|image: $img|image: $local_img|g" "$LOCAL_COMPOSE"
            fi
        done
        echo "Local compose ready: $LOCAL_COMPOSE"
    done
}

# --- Main ---
case "$1" in
    start)
        start_registry
        ;;
    stop)
        stop_registry
        ;;
    restart)
        stop_registry
        start_registry
        ;;
    cache)
        start_registry
        cache_images
        ;;
    list)
        list_images
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|cache|list}"
        exit 1
        ;;
esac

