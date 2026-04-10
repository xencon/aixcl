# vLLM Token Limit with OpenCode

## Problem

When using vLLM with models like Qwen 0.5B (Qwen2.5-Coder-0.5B-Instruct), you may encounter the following error:

```
This model's maximum context length is 32768 tokens. However, you requested 32000
output tokens and your prompt contains at least 769 input tokens, for a total of at
least 32769 tokens.
```

## Root Cause

**vLLM strictly enforces token limits**, unlike Ollama or llama.cpp which handle limits internally:

1. **vLLM validation**: vLLM checks `input_tokens + output_tokens <= max_model_len` and **rejects** the request if exceeded
2. **Model architecture**: Qwen 0.5B has `max_position_embeddings=32768` hardcoded in its architecture (RoPE encoding)
3. **OpenCode defaults**: OpenCode requests 32000 output tokens by default
4. **The math**: 32000 + ~769 input = 32769 > 32768 = **ERROR**

## Why Only vLLM?

| Engine | Token Limit Handling |
|--------|---------------------|
| **Ollama** | No strict enforcement - handles internally, truncates when needed |
| **llama.cpp** | Uses native limit without explicit validation |
| **vLLM** | **Strict validation** - rejects requests exceeding limit |

## Solution

Set the `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX` environment variable to limit OpenCode's output token requests.

### Configuration

The `.env` file now includes this setting:

```bash
# OpenCode Token Limit Configuration (for vLLM compatibility)
OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=10000
```

### Recommended Values

| Model Context | Recommended OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX |
|--------------|---------------------------------------------------|
| 32K models (Qwen 0.5B) | 10000 - 15000 |
| 64K+ models | 20000 - 30000 |

**Calculation**: `max_model_len - typical_input_context - safety_buffer = output_token_limit`

For Qwen 0.5B (32K): `32768 - 7000 (typical) - 1000 (buffer) ≈ 24768` → use **10000-15000** to be safe

### Usage

Set the environment variable before running OpenCode:

```bash
export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=10000
opencode run "Your prompt here"
```

Or make it permanent by adding to your shell profile:

```bash
echo 'export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=10000' >> ~/.bashrc
```

## Alternative Solutions

### Option 1: Use Ollama (Recommended for Smaller Models)

Ollama handles token limits internally without rejecting requests:

```bash
./aixcl engine set ollama
./aixcl models add qwen2.5-coder:0.5b
```

### Option 2: Use Larger Model with Bigger Context

Use a model variant with a larger native context window:

```bash
./aixcl engine set vllm
./aixcl models add Qwen/Qwen2.5-Coder-7B-Instruct  # Supports 128K context
```

### Option 3: Wait for OpenCode Update

OpenCode may add native `max_tokens` configuration in a future release. Track progress at:
- https://github.com/anomalyco/opencode/issues/1735

## Technical Details

### Why Can't We Increase max-model-len?

The model's `max_position_embeddings` is baked into the model weights. Exceeding it causes:
- RoPE (Rotary Position Embedding) index out of bounds
- NaN outputs for positions beyond the limit
- CUDA errors

### Why Not Remove --max-model-len?

vLLM automatically uses the model's native limit when `--max-model-len` is not specified. For Qwen 0.5B, this defaults to 32768 - the same limit.

### Environment Variable Source

The `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX` variable was discovered in OpenCode's experimental features:
- https://github.com/anomalyco/opencode/issues/1735

## References

- [OpenCode Issue #1735](https://github.com/anomalyco/opencode/issues/1735)
- [OpenCode Configuration Docs](https://opencode.ai/docs/config/)
- [Qwen2.5 Model Card](https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct)
- [vLLM Documentation](https://docs.vllm.ai/)

## Related Issues

- #685 - Original bug report for vLLM token limit
