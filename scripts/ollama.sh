#!/bin/bash

# Start Ollama in the background.
/bin/ollama serve &
# Record Process ID.
pid=$!

# Install jq
if ! command -v jq &> /dev/null
then
    echo "jq could not be found, installing..."
    apt-get update && apt-get install -y jq
else
    echo "jq is already installed."
fi

# Pause for Ollama to start.
sleep 5

MODELS_ARRAY=($(echo $MODELS_BASE | jq -r '.[]'))
echo "Installing default models."
echo $MODELS_BASE
for model in "${MODELS_ARRAY[@]}"; do
    echo "Installing model $model."
    ollama run "$model" &
done
echo "Done installing default models."

MODELS_ARRAY=($(echo $MODELS_EXTRA | jq -r '.[]'))
echo "Installing extra default models."
echo $MODELS_EXTRA
for model in "${MODELS_ARRAY[@]}"; do
    echo "Installing model $model."
    ollama run "$model" &
done
echo "Done installing extra models."

# Wait for Ollama process to finish.
wait $pid