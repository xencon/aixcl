# vLLM Token Limit with OpenCode

## Problem

When using vLLM with smaller models like Qwen 0.5B (Qwen2.5-Coder-0.5B-Instruct), you may encounter the following error:

```
This model's maximum context length is 32768 tokens. However, you requested 32000
output tokens and your prompt contains at least 769 input tokens, for a total of at
least 32769 tokens.
```

## Root Cause

1. **Model Architecture Limit**: The Qwen 0.5B model has `max_position_embeddings=32768` in its architecture. This is a hard limit that cannot be exceeded without causing CUDA errors (positions beyond this cause NaN with RoPE encoding).

2. **OpenCode Token Request**: OpenCode has a hardcoded default of 32000 output tokens for requests. Combined with input context (~769 tokens in the error example), this exceeds the model's 32768 limit.

3. **No Configuration Available**: OpenCode's OpenAI-compatible provider does not support configuring `max_tokens` at the provider or model level.

## Solutions

### Option 1: Use a Larger Model (Recommended)

Use a model variant with a larger native context window:

- **Qwen 7B or 14B variants**: Support 32K-128K context windows
- **Configure vLLM**:
  ```bash
  ./aixcl engine set vllm
  ./aixcl models add Qwen/Qwen2.5-Coder-7B-Instruct
  ```

### Option 2: Use Ollama Instead

Ollama handles token limits differently and may work better with smaller models:

```bash
./aixcl engine set ollama
./aixcl models add qwen2.5-coder:0.5b
```

### Option 3: Wait for OpenCode Update

OpenCode may add support for configurable `max_tokens` in a future release. Monitor the [OpenCode repository](https://github.com/anomalyco/opencode) for updates.

## Technical Details

### vLLM Configuration

The vLLM service is configured with `--max-model-len 32768` which is the maximum supported by the Qwen 0.5B model:

```yaml
# services/docker-compose.yml
command: [
  "--model", "Qwen/Qwen2.5-Coder-0.5B-Instruct",
  "--max-model-len", "32768",
  ...
]
```

### Why Not Increase max-model-len?

Increasing `--max-model-len` beyond 32768 causes vLLM to fail with:
- CUDA array out-of-bounds errors (for absolute position encoding)
- NaN outputs (for RoPE/relative position encoding)

The model's `max_position_embeddings` is baked into the model weights and cannot be changed.

### Why Not Configure max_tokens in OpenCode?

OpenCode's configuration schema for the OpenAI-compatible provider (`@ai-sdk/openai-compatible`) does not support:
- `max_tokens` at the provider level
- `max_tokens` at the model level
- Per-request token limits

The 32000 token default appears to be hardcoded in OpenCode's AI SDK integration.

## References

- [OpenCode Configuration Docs](https://opencode.ai/docs/config/)
- [Qwen2.5 Model Card](https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct)
- [vLLM Documentation](https://docs.vllm.ai/)

## Related Issues

- #685 - Original bug report for vLLM token limit
