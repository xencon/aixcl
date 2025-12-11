#!/bin/bash
# Script to update LLM-Council configuration via API

API_URL="${LLM_COUNCIL_API_URL:-http://localhost:8000}"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  get              - Get current configuration"
    echo "  set              - Set configuration (requires --models and/or --chairman)"
    echo "  reload           - Reload configuration from file/environment"
    echo "  validate <models> - Validate models exist in Ollama"
    echo ""
    echo "Options for 'set':"
    echo "  --models <list>     - Comma-separated list of council models"
    echo "  --chairman <model>   - Chairman model name"
    echo ""
    echo "Examples:"
    echo "  $0 get"
    echo "  $0 set --models codellama:7b,qwen3:latest --chairman qwen3:latest"
    echo "  $0 validate codellama:7b,qwen3:latest"
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    get)
        curl -s "${API_URL}/api/config" | jq .
        ;;
    set)
        MODELS=""
        CHAIRMAN=""
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                --models)
                    MODELS="$2"
                    shift 2
                    ;;
                --chairman)
                    CHAIRMAN="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option: $1"
                    exit 1
                    ;;
            esac
        done
        
        if [ -z "$MODELS" ] && [ -z "$CHAIRMAN" ]; then
            echo "Error: At least one of --models or --chairman must be provided"
            exit 1
        fi
        
        JSON_BODY="{"
        if [ -n "$MODELS" ]; then
            IFS=',' read -ra MODEL_ARRAY <<< "$MODELS"
            JSON_BODY="${JSON_BODY}\"council_models\": ["
            for i in "${!MODEL_ARRAY[@]}"; do
                if [ $i -gt 0 ]; then
                    JSON_BODY="${JSON_BODY}, "
                fi
                JSON_BODY="${JSON_BODY}\"${MODEL_ARRAY[i]}\""
            done
            JSON_BODY="${JSON_BODY}]"
        fi
        if [ -n "$CHAIRMAN" ]; then
            if [ -n "$MODELS" ]; then
                JSON_BODY="${JSON_BODY}, "
            fi
            JSON_BODY="${JSON_BODY}\"chairman_model\": \"${CHAIRMAN}\""
        fi
        JSON_BODY="${JSON_BODY}}"
        
        curl -s -X PUT "${API_URL}/api/config" \
            -H "Content-Type: application/json" \
            -d "$JSON_BODY" | jq .
        ;;
    reload)
        curl -s -X POST "${API_URL}/api/config/reload" | jq .
        ;;
    validate)
        if [ -z "$1" ]; then
            echo "Error: Models list required for validate command"
            exit 1
        fi
        curl -s "${API_URL}/api/config/validate?models=$(echo "$1" | sed 's/ /%20/g')" | jq .
        ;;
    *)
        echo "Unknown command: $COMMAND"
        exit 1
        ;;
esac

