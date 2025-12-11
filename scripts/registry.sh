#!/usr/bin/env bash

# ======================================================
# Local Docker Registry Caching Tool
# - Mirrors Docker + Ollama images into local registry
# - Rewrites docker-compose.yml accordingly
# - Handles manual add/remove/list
# - Supports dry-run mode
# ======================================================

### PATHS ###############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

REGISTRY="localhost:5000"

# Mapping format: SOURCE=TARGET
MAPPING_FILE="$PROJECT_ROOT/registry_mapping.txt"

# Logs
LOG_FILE="$PROJECT_ROOT/registry_master.log"

# Compose
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
OUTPUT_FILE="$PROJECT_ROOT/docker-compose.local.yml"

DRY_RUN=0

### LOGGING ##############################################

log() {
    local MSG="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MSG" | tee -a "$LOG_FILE"
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY-RUN] $*"
    else
        log "$*"
        eval "$*"
    fi
}

### REGISTRY SETUP ########################################

ensure_registry() {
    if ! docker ps --format '{{.Names}}' | grep -q '^local-registry$'; then
        log "Starting local Docker registry..."
        run "docker run -d -p 5000:5000 --restart=always --name local-registry registry:2"
        sleep 3
    fi
    log "Registry ready at $REGISTRY"
}

### MAPPING FUNCTIONS ######################################

save_mapping() {
    local SOURCE="$1"
    local TARGET="$2"
    grep -v "^$SOURCE=" "$MAPPING_FILE" 2>/dev/null > "$MAPPING_FILE.tmp" || true
    mv "$MAPPING_FILE.tmp" "$MAPPING_FILE"
    echo "$SOURCE=$TARGET" >> "$MAPPING_FILE"
}

### AUTO DISCOVERY #########################################

auto_cache() {
    log "Scanning Docker images..."
    DOCKER_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' || true)

    log "Scanning Ollama models..."
    if command -v ollama >/dev/null 2>&1; then
        LLM_IMAGES=$(ollama list | awk 'NR>1 {print $1":"$3}' || true)
    else
        LLM_IMAGES=""
    fi

    > "$MAPPING_FILE"

    for IMAGE in $DOCKER_IMAGES $LLM_IMAGES; do
        LOCAL_TAG="${IMAGE//\//_}"   # replace / with _
        TARGET="$REGISTRY/$LOCAL_TAG"

        log "Caching: $IMAGE  →  $TARGET"

        run "docker tag $IMAGE $TARGET"
        run "docker push $TARGET"

        save_mapping "$IMAGE" "$TARGET"
    done
}

### MANUAL ADD ############################################

add_image() {
    local SRC="$1"
    local TAG="$2"

    if [ -z "$SRC" ] || [ -z "$TAG" ]; then
        echo "Usage: $0 add <source_image> <local_tag>"
        exit 1
    fi

    TARGET="$REGISTRY/$TAG"

    run "docker tag $SRC $TARGET"
    run "docker push $TARGET"

    save_mapping "$SRC" "$TARGET"
}

### MANUAL REMOVE ##########################################

remove_image() {
    local TAG="$1"

    if [ -z "$TAG" ]; then
        echo "Usage: $0 remove <local_tag>"
        exit 1
    fi

    local TARGET="$REGISTRY/$TAG"

    run "docker rmi $TARGET || true"

    grep -v "=$TARGET$" "$MAPPING_FILE" > "$MAPPING_FILE.tmp"
    mv "$MAPPING_FILE.tmp" "$MAPPING_FILE"
}

### LIST MAPPINGS ##########################################

list_images() {
    log "=== Cached Images ==="
    cat "$MAPPING_FILE"
}

### COMPOSE REWRITE ########################################

rewrite_compose() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        log "Compose file not found: $COMPOSE_FILE"
        return
    fi

    cp "$COMPOSE_FILE" "$OUTPUT_FILE"

    while IFS='=' read -r SRC DST; do
        [ -z "$SRC" ] && continue

        SRC_ESC=$(printf '%s\n' "$SRC" | sed 's/[\/&]/\\&/g')
        DST_ESC=$(printf '%s\n' "$DST" | sed 's/[\/&]/\\&/g')

        run "sed -i \"s/$SRC_ESC/$DST_ESC/g\" \"$OUTPUT_FILE\""
    done < "$MAPPING_FILE"

    log "Compose rewritten → $OUTPUT_FILE"
}

### PRUNE (LOCAL ONLY) #####################################

prune_local() {
    log "Pruning unused cached local images…"

    while IFS='=' read -r SRC DST; do
        [ -z "$SRC" ] && continue
        USED_TARGETS+="$DST "
    done < "$MAPPING_FILE"

    ALL_LOCAL=$(docker images "$REGISTRY"/* --format '{{.Repository}}:{{.Tag}}' || true)

    for IMG in $ALL_LOCAL; do
        if [[ " $USED_TARGETS " != *" $IMG "* ]]; then
            log "Pruning unused: $IMG"
            run "docker rmi $IMG || true"
        fi
    done
}

### COMMAND PARSER #########################################

if [ "$1" == "--dry-run" ]; then
    DRY_RUN=1
    shift
fi

CMD="$1"
shift || true

case "$CMD" in
    auto)
        ensure_registry
        auto_cache
        rewrite_compose
        prune_local
        ;;
    add)
        ensure_registry
        add_image "$@"
        rewrite_compose
        ;;
    remove)
        remove_image "$@"
        rewrite_compose
        prune_local
        ;;
    list)
        list_images
        ;;
    prune)
        prune_local
        ;;
    *)
        echo "Usage: $0 [--dry-run] {auto|add|remove|list|prune}"
        exit 1
        ;;
esac

