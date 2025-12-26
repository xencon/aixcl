#!/usr/bin/env python3
"""
User-focused performance test for Ollama optimizations.

This script runs from outside the container to simulate real user experience.
It tests the actual API endpoints that users interact with.

Usage:
    # Option 1: Install httpx globally (requires pip)
    sudo apt install python3-pip
    pip3 install httpx
    python3 tests/runtime-core/test_council_performance.py
    
    # Option 2: Use venv (no sudo needed)
    python3 -m venv .venv
    source .venv/bin/activate
    pip install httpx
    python3 tests/runtime-core/test_council_performance.py
    
    # Option 3: Use wrapper script (auto-setup venv)
    ./tests/runtime-core/run_test.sh
    
    # Option 4: With warmup (recommended for accurate benchmarks)
    python3 tests/runtime-core/test_council_performance.py --warmup
"""

import argparse
import asyncio
import httpx
import json
import sys
import time
from typing import Dict, Optional, List, Any
from datetime import datetime

# API endpoints (as users would access them)
API_BASE_URL = "http://localhost:8000"
OLLAMA_BASE_URL = "http://localhost:11434"

# Test queries - simple code tasks
# Using consistent prompt length for accurate benchmarking comparisons
# Prompt length: ~50 characters (standardized for fair comparisons)
TEST_QUERY_1 = "Write a Python function that reverses a string."
TEST_QUERY_2 = "Write a Python function that checks if a string is a palindrome."
WARMUP_QUERY = "Say hello."  # Simple warmup query to pre-load models

# Model info cache to avoid repeated queries
_model_info_cache: Dict[str, Dict[str, Any]] = {}


class Colors:
    """ANSI color codes."""
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'


def print_header(text: str):
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*70}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text:^70}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'='*70}{Colors.ENDC}\n")


def print_section(text: str):
    print(f"\n{Colors.CYAN}{Colors.BOLD}{text}{Colors.ENDC}")
    print(f"{Colors.CYAN}{'-'*len(text)}{Colors.ENDC}")


async def check_service_health() -> bool:
    """Check if services are accessible."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            # Check council API
            response = await client.get(f"{API_BASE_URL}/health")
            if response.status_code != 200:
                return False
            
            # Check Ollama API
            response = await client.get(f"{OLLAMA_BASE_URL}/api/version")
            if response.status_code != 200:
                return False
            
            return True
    except Exception:
        return False


async def get_council_config() -> Optional[Dict]:
    """Get council configuration."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{API_BASE_URL}/api/config")
            if response.status_code == 200:
                return response.json()
    except Exception:
        # Silently return None if config fetch fails (API may not be available)
        # This is acceptable in test context where API availability is checked separately
        pass
    return None


async def get_ollama_model_info(model_name: str) -> Dict[str, Any]:
    """
    Get model information from Ollama API.
    
    Returns model details including quantization and context size if available.
    Caches results to avoid repeated queries.
    """
    if model_name in _model_info_cache:
        return _model_info_cache[model_name]
    
    # Try to extract quantization from model name first
    quantization = _extract_quantization(model_name)
    context_size = None
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Try /api/show endpoint first (more detailed)
            response = await client.post(
                f"{OLLAMA_BASE_URL}/api/show",
                json={"name": model_name}
            )
            if response.status_code == 200:
                data = response.json()
                import re
                
                # Extract context size from various possible locations
                modelfile = data.get('modelfile', '')
                
                # First, try parsing modelfile as string (most common case)
                if isinstance(modelfile, str):
                    # Look for num_ctx in modelfile string
                    # Pattern: "num_ctx 4096" or "PARAMETER num_ctx 4096"
                    match = re.search(r'num_ctx\s+(\d+)', modelfile, re.IGNORECASE)
                    if match:
                        context_size = int(match.group(1))
                    else:
                        # Try alternative patterns
                        match = re.search(r'PARAMETER\s+num_ctx\s+(\d+)', modelfile, re.IGNORECASE)
                        if match:
                            context_size = int(match.group(1))
                
                # If modelfile is a dict, try nested access
                elif isinstance(modelfile, dict):
                    parameters = modelfile.get('parameter', {})
                    if isinstance(parameters, dict):
                        context_size = parameters.get('num_ctx')
                
                # Try direct parameters field
                if context_size is None:
                    parameters = data.get('parameters', {})
                    if isinstance(parameters, dict):
                        context_size = parameters.get('num_ctx')
                        if isinstance(context_size, dict):
                            context_size = context_size.get('value')
                
                # Try details.parameters.num_ctx
                if context_size is None:
                    details = data.get('details', {})
                    if isinstance(details, dict):
                        params = details.get('parameters', {})
                        if isinstance(params, dict):
                            context_size = params.get('num_ctx')
                
                # Try top-level num_ctx
                if context_size is None:
                    context_size = data.get('num_ctx')
                
                # Try to get quantization from model details if not in name
                if not quantization:
                    # Check if quantization info is in model details
                    model_details = data.get('details', {})
                    if isinstance(model_details, dict):
                        quantization = model_details.get('quantization_level') or model_details.get('format')
                    
                    # Also check modelfile for quantization info
                    if not quantization and isinstance(modelfile, str):
                        q_match = re.search(r'quantization[:\s]+([^\s]+)', modelfile, re.IGNORECASE)
                        if q_match:
                            quantization = q_match.group(1)
                
                info = {
                    'name': model_name,
                    'quantization': quantization,
                    'context_size': context_size,
                    'details': data
                }
                _model_info_cache[model_name] = info
                return info
    except Exception as e:
        # Silently fall back to name-based extraction if API call fails
        # This is acceptable in test context where model info is optional
        pass
    
    # Fallback: try to extract info from model name only
    # If context_size still not found, try to infer from model name or use common defaults
    if context_size is None:
        # Common default context sizes by model family
        # Most modern models use 2048 or 4096, some use 8192 or 32768
        # Since we can't determine from API, leave as None (will show as blank)
        # Alternatively, we could set a default like 2048, but blank is more honest
        pass
    
    info = {
        'name': model_name,
        'quantization': quantization,  # May be None if not in name
        'context_size': context_size,  # May be None if not found
        'details': {}
    }
    _model_info_cache[model_name] = info
    return info


def _extract_quantization(model_name: str) -> Optional[str]:
    """Extract quantization level from model name (e.g., q4_0, q5_0)."""
    # Common quantization patterns in Ollama model names
    import re
    patterns = [
        r'-q(\d+)_(\d+)',  # q4_0, q5_0, etc.
        r':(\d+b)-q(\d+)_(\d+)',  # :7b-q4_0
        r'q(\d+)_(\d+)',  # q4_0 standalone
    ]
    
    for pattern in patterns:
        match = re.search(pattern, model_name.lower())
        if match:
            if len(match.groups()) == 2:
                return f"q{match.group(1)}_{match.group(2)}"
            elif len(match.groups()) == 3:
                return f"q{match.group(2)}_{match.group(3)}"
    
    return None


async def test_model_api(query: str, model_name: str, test_name: str) -> Dict:
    """
    Test an individual model via Ollama API.
    
    Args:
        query: The query to test
        model_name: The model name to test (e.g., 'deepseek-coder:1.3b')
        test_name: Descriptive name for the test
    """
    print(f"  Testing: {test_name}")
    print(f"  Model: {model_name}")
    print(f"  Query: {query[:60]}...")
    
    start_time = time.time()
    
    try:
        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(
                f"{OLLAMA_BASE_URL}/api/chat",
                json={
                    "model": model_name,
                    "messages": [
                        {"role": "user", "content": query}
                    ],
                    "stream": False
                }
            )
            
            elapsed = time.time() - start_time
            
            # Check status code
            if response.status_code != 200:
                response_text = response.text[:200]
                return {
                    'success': False,
                    'elapsed_time': elapsed,
                    'error': f'HTTP {response.status_code}: {response_text}',
                    'model': model_name
                }
            
            try:
                data = response.json()
            except json.JSONDecodeError as e:
                response_text = response.text[:500]
                return {
                    'success': False,
                    'elapsed_time': elapsed,
                    'error': f'JSON decode error: {str(e)[:50]}. Response preview: {response_text[:200]}',
                    'model': model_name
                }
            
            # Extract response info
            message = data.get('message', {})
            content = message.get('content', '')
            
            # Extract token metrics from Ollama response
            # Ollama returns prompt_eval_count and eval_count instead of prompt_tokens/completion_tokens
            prompt_tokens = data.get('prompt_eval_count', 0) or data.get('prompt_tokens', 0) or 0
            completion_tokens = data.get('eval_count', 0) or data.get('completion_tokens', 0) or 0
            total_tokens = prompt_tokens + completion_tokens
            tokens_per_second = (completion_tokens / elapsed) if elapsed > 0 and completion_tokens > 0 else 0.0
            
            return {
                'success': True,
                'elapsed_time': elapsed,
                'response_id': data.get('id', ''),
                'has_content': len(content) > 0,
                'response_length': len(content),
                'prompt_tokens': prompt_tokens,
                'completion_tokens': completion_tokens,
                'total_tokens': total_tokens,
                'tokens_per_second': tokens_per_second,
                'model': model_name
            }
    except httpx.TimeoutException:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': 'Timeout (180s)',
            'model': model_name
        }
    except httpx.RequestError as e:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': f'Request error: {str(e)[:100]}',
            'model': model_name
        }
    except Exception as e:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': f'{type(e).__name__}: {str(e)[:100]}',
            'model': model_name
        }


async def test_council_api(query: str, test_name: str) -> Dict:
    """
    Test the council API endpoint (simulating real user interaction).
    
    This is what users actually experience when using the council.
    Handles both streaming and non-streaming responses.
    """
    print(f"  Testing: {test_name}")
    print(f"  Query: {query[:60]}...")
    
    start_time = time.time()
    
    try:
        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(
                f"{API_BASE_URL}/v1/chat/completions",
                json={
                    "model": "council",
                    "messages": [
                        {"role": "user", "content": query}
                    ],
                    "stream": False
                }
            )
            
            elapsed = time.time() - start_time
            
            # Check status code
            if response.status_code != 200:
                response_text = response.text[:200]
                return {
                    'success': False,
                    'elapsed_time': elapsed,
                    'error': f'HTTP {response.status_code}: {response_text}',
                    'model': 'council'
                }
            
            # Check content type
            content_type = response.headers.get('content-type', '')
            
            # Handle streaming response (text/event-stream)
            if 'text/event-stream' in content_type or response.text.startswith('data:'):
                # Parse streaming response
                content = ""
                response_id = ""
                usage_data = {}
                for line in response.text.split('\n'):
                    if line.startswith('data: '):
                        data_str = line[6:]  # Remove 'data: ' prefix
                        if data_str.strip() == '[DONE]':
                            break
                        try:
                            chunk_data = json.loads(data_str)
                            if 'id' in chunk_data:
                                response_id = chunk_data['id']
                            if 'usage' in chunk_data:
                                usage_data = chunk_data['usage']
                            if 'choices' in chunk_data:
                                for choice in chunk_data['choices']:
                                    if 'delta' in choice and 'content' in choice['delta']:
                                        content += choice['delta']['content']
                        except json.JSONDecodeError:
                            continue
                
                # Extract token metrics
                prompt_tokens = usage_data.get('prompt_tokens', 0) or 0
                completion_tokens = usage_data.get('completion_tokens', 0) or 0
                total_tokens = usage_data.get('total_tokens', 0) or (prompt_tokens + completion_tokens)
                
                # Fallback: if usage is missing or zero, estimate from content
                if prompt_tokens == 0 and completion_tokens == 0:
                    prompt_tokens = len(query.split())
                    if content:
                        completion_tokens = len(content.split())
                    else:
                        completion_tokens = 0
                    total_tokens = prompt_tokens + completion_tokens
                
                tokens_per_second = (completion_tokens / elapsed) if elapsed > 0 and completion_tokens > 0 else 0.0
                
                return {
                    'success': True,
                    'elapsed_time': elapsed,
                    'response_id': response_id,
                    'has_content': len(content) > 0,
                    'response_length': len(content),
                    'prompt_tokens': prompt_tokens,
                    'completion_tokens': completion_tokens,
                    'total_tokens': total_tokens,
                    'tokens_per_second': tokens_per_second,
                    'model': 'council'  # Council is a composite model
                }
            
            # Handle non-streaming JSON response
            try:
                data = response.json()
            except json.JSONDecodeError as e:
                response_text = response.text[:500]
                return {
                    'success': False,
                    'elapsed_time': elapsed,
                    'error': f'JSON decode error: {str(e)[:50]}. Response preview: {response_text[:200]}',
                    'model': 'council'
                }
            
            # Extract response info
            choices = data.get('choices', [])
            has_content = bool(choices and choices[0].get('message', {}).get('content'))
            response_content = choices[0].get('message', {}).get('content', '') if has_content else ''
            
            # Extract token metrics from usage field
            usage = data.get('usage', {})
            prompt_tokens = usage.get('prompt_tokens', 0) or 0
            completion_tokens = usage.get('completion_tokens', 0) or 0
            total_tokens = usage.get('total_tokens', 0) or (prompt_tokens + completion_tokens)
            
            # Fallback: if usage is missing or zero, estimate from content
            # Council API uses word counts, so if they're zero, calculate from actual content
            if prompt_tokens == 0 and completion_tokens == 0:
                # Calculate word counts from actual query and response content
                # Council API uses word counts as token estimates
                prompt_tokens = len(query.split())
                if response_content:
                    completion_tokens = len(response_content.split())
                else:
                    completion_tokens = 0
                total_tokens = prompt_tokens + completion_tokens
            
            tokens_per_second = (completion_tokens / elapsed) if elapsed > 0 and completion_tokens > 0 else 0.0
            
            return {
                'success': True,
                'elapsed_time': elapsed,
                'response_id': data.get('id', ''),
                'has_content': has_content,
                'response_length': len(choices[0].get('message', {}).get('content', '')) if has_content else 0,
                'prompt_tokens': prompt_tokens,
                'completion_tokens': completion_tokens,
                'total_tokens': total_tokens,
                'tokens_per_second': tokens_per_second,
                'model': 'council'  # Council is a composite model
            }
    except httpx.TimeoutException:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': 'Timeout (180s)',
            'model': 'council'
        }
    except httpx.RequestError as e:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': f'Request error: {str(e)[:100]}',
            'model': 'council'
        }
    except Exception as e:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': f'{type(e).__name__}: {str(e)[:100]}',
            'model': 'council'
        }


async def test_multiple_queries(models: list):
    """
    Test multiple queries for each model to measure consistency.
    
    Args:
        models: List of model names to test (includes 'council' and individual models)
    """
    print_section("Multiple Query Test (Consistency)")
    print(f"Running 3 queries per model to measure performance consistency...")
    print(f"Testing {len(models)} model(s): {', '.join(models)}")
    
    all_results = []
    queries = [
        ("Query 1", TEST_QUERY_1),
        ("Query 2", TEST_QUERY_2),
        ("Query 3", TEST_QUERY_1),  # Repeat first query
    ]
    
    for model_idx, model_name in enumerate(models, 1):
        print(f"\n{Colors.BOLD}Model {model_idx}/{len(models)}: {model_name}{Colors.ENDC}")
        model_results = []
        
        for i, (name, query) in enumerate(queries, 1):
            print(f"\n  [{i}/3] {name}")
            if model_name == 'council':
                result = await test_council_api(query, name)
            else:
                result = await test_model_api(query, model_name, name)
            model_results.append(result)
            
            if result['success']:
                print(f"    {Colors.GREEN}✓ Success{Colors.ENDC} - Time: {result['elapsed_time']:.2f}s")
                if result.get('response_length'):
                    print(f"    Response length: {result['response_length']} chars")
                if result.get('completion_tokens'):
                    print(f"    Tokens: {result.get('completion_tokens', 0)} completion / {result.get('total_tokens', 0)} total")
                    if result.get('tokens_per_second', 0) > 0:
                        print(f"    Speed: {result['tokens_per_second']:.2f} tokens/sec")
            else:
                print(f"    {Colors.RED}✗ Failed{Colors.ENDC} - {result.get('error', 'Unknown error')}")
            
            # Small delay between queries
            if i < len(queries):
                await asyncio.sleep(2)
        
        all_results.extend(model_results)
        
        # Delay between models
        if model_idx < len(models):
            await asyncio.sleep(3)
    
    return all_results


async def test_rapid_queries(models: list):
    """
    Test rapid successive queries for each model (testing keep-alive).
    
    Args:
        models: List of model names to test (includes 'council' and individual models)
    """
    print_section("Rapid Query Test (Keep-Alive)")
    print(f"Running 2 rapid queries per model to test if models stay loaded...")
    print(f"Testing {len(models)} model(s): {', '.join(models)}")
    
    all_results = []
    
    for model_idx, model_name in enumerate(models, 1):
        print(f"\n{Colors.BOLD}Model {model_idx}/{len(models)}: {model_name}{Colors.ENDC}")
        
        # First query (cold start or warm)
        print("\n  [1/2] First Query")
        if model_name == 'council':
            result1 = await test_council_api(TEST_QUERY_1, "First Query")
        else:
            result1 = await test_model_api(TEST_QUERY_1, model_name, "First Query")
        
        if result1['success']:
            print(f"    {Colors.GREEN}✓ Success{Colors.ENDC} - Time: {result1['elapsed_time']:.2f}s")
            if result1.get('tokens_per_second', 0) > 0:
                print(f"    Speed: {result1['tokens_per_second']:.2f} tokens/sec")
        else:
            print(f"    {Colors.RED}✗ Failed{Colors.ENDC}")
            all_results.append(result1)
            if model_idx < len(models):
                await asyncio.sleep(3)
            continue
        
        # Second query immediately after (should be faster if models stayed loaded)
        print("\n  [2/2] Second Query (Immediate)")
        await asyncio.sleep(1)  # Very short delay
        if model_name == 'council':
            result2 = await test_council_api(TEST_QUERY_2, "Second Query")
        else:
            result2 = await test_model_api(TEST_QUERY_2, model_name, "Second Query")
        
        if result2['success']:
            print(f"    {Colors.GREEN}✓ Success{Colors.ENDC} - Time: {result2['elapsed_time']:.2f}s")
            if result2.get('tokens_per_second', 0) > 0:
                print(f"    Speed: {result2['tokens_per_second']:.2f} tokens/sec")
            
            # Compare times
            if result2['elapsed_time'] < result1['elapsed_time'] * 0.9:
                improvement = ((result1['elapsed_time'] - result2['elapsed_time']) / result1['elapsed_time']) * 100
                print(f"    {Colors.GREEN}→ Second query was {improvement:.1f}% faster (models likely stayed loaded){Colors.ENDC}")
            elif result2['elapsed_time'] > result1['elapsed_time'] * 1.1:
                slowdown = ((result2['elapsed_time'] - result1['elapsed_time']) / result1['elapsed_time']) * 100
                print(f"    {Colors.YELLOW}→ Second query was {slowdown:.1f}% slower (possible model reload){Colors.ENDC}")
            else:
                print(f"    {Colors.CYAN}→ Similar performance (models may have stayed loaded){Colors.ENDC}")
        else:
            print(f"    {Colors.RED}✗ Failed{Colors.ENDC}")
        
        all_results.extend([result1, result2])
        
        # Delay between models
        if model_idx < len(models):
            await asyncio.sleep(3)
    
    return all_results


async def warmup_models(models: list):
    """
    Warm up models by running a simple query for each.
    
    This pre-loads models into GPU memory before benchmarking,
    ensuring more accurate performance measurements.
    
    Args:
        models: List of model names to warm up
    """
    print_section("Model Warmup")
    print(f"Running warmup query to pre-load {len(models)} model(s)...")
    print(f"  Query: {WARMUP_QUERY}")
    
    for model_idx, model_name in enumerate(models, 1):
        print(f"\n  Warming up {model_idx}/{len(models)}: {model_name}")
        if model_name == 'council':
            result = await test_council_api(WARMUP_QUERY, f"Warmup {model_name}")
        else:
            result = await test_model_api(WARMUP_QUERY, model_name, f"Warmup {model_name}")
        
        if result['success']:
            print(f"    {Colors.GREEN}✓ Warmup complete{Colors.ENDC} - Time: {result['elapsed_time']:.2f}s")
        else:
            print(f"    {Colors.YELLOW}⚠ Warmup failed{Colors.ENDC} - {result.get('error', 'Unknown')}")
        
        if model_idx < len(models):
            await asyncio.sleep(1)
    
    print(f"\n  {Colors.CYAN}Models should now be loaded and ready for benchmarking{Colors.ENDC}\n")
    await asyncio.sleep(2)  # Brief pause after warmup


def calculate_performance_score(result: Dict) -> float:
    """
    Calculate a performance score from 0-100 based on tokens/sec and elapsed time.
    
    Uses different scoring formulas for council (composite) vs individual models:
    - Individual models: Higher scale to differentiate fast models (no cap)
    - Council: Adjusted scale for multi-stage orchestration performance
    
    Higher score = better performance (faster, more efficient)
    
    Args:
        result: Test result dictionary with 'model' field
        
    Returns:
        Performance score from 0-100
    """
    tokens_per_sec = result.get('tokens_per_second', 0) or 0
    elapsed_time = result.get('elapsed_time') or 0
    model_name = result.get('model', '')
    
    # If we don't have a valid elapsed_time, treat the measurement as invalid
    if tokens_per_sec == 0 or not isinstance(elapsed_time, (int, float)) or elapsed_time <= 0:
        return 0.0
    
    # Different scoring for council vs individual models
    if model_name == 'council':
        # Council scoring: Multi-stage orchestration is inherently slower
        # Scale: (tokens_per_second * 5) / elapsed_time, capped at 100
        # This accounts for the overhead of running multiple models sequentially
        score = min(100.0, (tokens_per_sec * 5.0) / elapsed_time)
    else:
        # Individual model scoring: Higher scale to differentiate fast models
        # Scale: (tokens_per_second * 2) / elapsed_time, no cap (but typically stays under 200)
        # This better differentiates between 50-100 tokens/sec models
        score = (tokens_per_sec * 2.0) / elapsed_time
        # Cap at 200 for very fast models, but allow higher differentiation
        score = min(200.0, score)
    
    return round(score, 1)


def display_benchmark_table(results: list, rapid_results: list, model_info_cache: Dict[str, Dict[str, Any]]):
    """
    Display benchmark results as a formatted table in the summary.
    
    Args:
        results: List of results from multiple query test
        rapid_results: List of results from rapid query test
        model_info_cache: Dictionary mapping model names to their info dictionaries
    """
    # Check if there are any successful results to display
    successful_results = [r for r in results if r.get('success')]
    successful_rapid = [r for r in rapid_results if r.get('success')]
    
    if not successful_results and not successful_rapid:
        print(f"\n{Colors.YELLOW}No successful test results to display in benchmark table{Colors.ENDC}\n")
        return
    
    # Check if results are aggregated (have 'runs' or 'iterations' field)
    is_aggregated = any(r.get('runs') or r.get('iterations') for r in successful_results + successful_rapid)
    iterations = successful_results[0].get('iterations') or successful_results[0].get('runs') if successful_results else None
    
    print(f"\n{Colors.BOLD}Benchmark Results Table:{Colors.ENDC}")
    if is_aggregated and iterations:
        print(f"{Colors.CYAN}(Aggregated from {iterations} iterations - showing mean values ± std dev){Colors.ENDC}")
    
    # Adjusted width to accommodate all columns including Score
    table_width = 140
    print(f"{Colors.CYAN}{'='*table_width}{Colors.ENDC}")
    
    # Table header - add Runs column if aggregated
    if is_aggregated:
        header = (
            f"{'Timestamp':<20} "
            f"{'Model':<22} "
            f"{'Quant':<7} "
            f"{'Ctx':<5} "
            f"{'Prompt':<7} "
            f"{'Complete':<9} "
            f"{'Total':<6} "
            f"{'Elapsed(s)':<11} "
            f"{'Tokens/s':<9} "
            f"{'Score':<7} "
            f"{'Runs':<6} "
            f"{'Type':<10}"
        )
    else:
        header = (
            f"{'Timestamp':<20} "
            f"{'Model':<22} "
            f"{'Quant':<7} "
            f"{'Ctx':<5} "
            f"{'Prompt':<7} "
            f"{'Complete':<9} "
            f"{'Total':<6} "
            f"{'Elapsed(s)':<11} "
            f"{'Tokens/s':<9} "
            f"{'Score':<7} "
            f"{'Query':<6} "
            f"{'Type':<10}"
        )
    print(f"{Colors.BOLD}{header}{Colors.ENDC}")
    print(f"{Colors.CYAN}{'-'*table_width}{Colors.ENDC}")
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    # Display multiple query test results
    query_num = 1
    for result in results:
        if result.get('success'):
            result_model = result.get('model', 'council')
            
            # Extract model info
            if result_model == 'council':
                model_name = 'council'
                quantization = ''
                context_size = ''
            else:
                info = model_info_cache.get(result_model)
                model_name = result_model
                if info:
                    quant_val = info.get('quantization')
                    quantization = str(quant_val) if quant_val else ''
                    ctx_val = info.get('context_size')
                    context_size = str(ctx_val) if ctx_val else ''
                else:
                    quantization = ''
                    context_size = ''
            
            score = calculate_performance_score(result)
            # Color code score based on model type
            if result_model == 'council':
                # Council scoring: green (>50), yellow (25-50), red (<25)
                score_color = Colors.GREEN if score >= 50 else (Colors.YELLOW if score >= 25 else Colors.RED)
            else:
                # Individual model scoring: green (>100), yellow (50-100), red (<50)
                score_color = Colors.GREEN if score >= 100 else (Colors.YELLOW if score >= 50 else Colors.RED)
            score_display = f"{score_color}{score:>6.1f}{Colors.ENDC}"
            
            # Format elapsed time - show std dev if available (aggregated results)
            elapsed_time = result.get('elapsed_time', 0)
            if result.get('elapsed_std_dev') is not None:
                elapsed_display = f"{elapsed_time:>6.2f}±{result['elapsed_std_dev']:.2f}"
            else:
                elapsed_display = f"{elapsed_time:>10.2f}"
            
            # Show runs count if aggregated, otherwise query number
            if is_aggregated:
                runs_count = result.get('runs', result.get('iterations', 1))
                runs_display = f"{runs_count:<6}"
            else:
                runs_display = f"{query_num:<6}"
            
            row = (
                f"{timestamp:<20} "
                f"{model_name[:21]:<22} "
                f"{quantization[:6]:<7} "
                f"{context_size[:4]:<5} "
                f"{result.get('prompt_tokens', 0):<7} "
                f"{result.get('completion_tokens', 0):<9} "
                f"{result.get('total_tokens', 0):<6} "
                f"{elapsed_display:<11} "
                f"{result.get('tokens_per_second', 0):>8.2f} "
                f"{score_display:<20} "  # Width accounts for ANSI color codes
                f"{runs_display} "
                f"{'consistency':<10}"
            )
            print(row)
            query_num += 1
    
    # Display rapid query test results
    query_num = 1
    for result in rapid_results:
        if result.get('success'):
            result_model = result.get('model', 'council')
            
            # Extract model info
            if result_model == 'council':
                model_name = 'council'
                quantization = ''
                context_size = ''
            else:
                info = model_info_cache.get(result_model)
                model_name = result_model
                if info:
                    quant_val = info.get('quantization')
                    quantization = str(quant_val) if quant_val else ''
                    ctx_val = info.get('context_size')
                    context_size = str(ctx_val) if ctx_val else ''
                else:
                    quantization = ''
                    context_size = ''
            
            score = calculate_performance_score(result)
            # Color code score based on model type
            if result_model == 'council':
                # Council scoring: green (>50), yellow (25-50), red (<25)
                score_color = Colors.GREEN if score >= 50 else (Colors.YELLOW if score >= 25 else Colors.RED)
            else:
                # Individual model scoring: green (>100), yellow (50-100), red (<50)
                score_color = Colors.GREEN if score >= 100 else (Colors.YELLOW if score >= 50 else Colors.RED)
            score_display = f"{score_color}{score:>6.1f}{Colors.ENDC}"
            
            # Format elapsed time - show std dev if available (aggregated results)
            elapsed_time = result.get('elapsed_time', 0)
            if result.get('elapsed_std_dev') is not None:
                elapsed_display = f"{elapsed_time:>6.2f}±{result['elapsed_std_dev']:.2f}"
            else:
                elapsed_display = f"{elapsed_time:>10.2f}"
            
            # Show runs count if aggregated, otherwise query number
            if is_aggregated:
                runs_count = result.get('runs', result.get('iterations', 1))
                runs_display = f"{runs_count:<6}"
            else:
                runs_display = f"{query_num:<6}"
            
            row = (
                f"{timestamp:<20} "
                f"{model_name[:21]:<22} "
                f"{quantization[:6]:<7} "
                f"{context_size[:4]:<5} "
                f"{result.get('prompt_tokens', 0):<7} "
                f"{result.get('completion_tokens', 0):<9} "
                f"{result.get('total_tokens', 0):<6} "
                f"{elapsed_display:<11} "
                f"{result.get('tokens_per_second', 0):>8.2f} "
                f"{score_display:<20} "  # Width accounts for ANSI color codes
                f"{runs_display} "
                f"{'rapid':<10}"
            )
            print(row)
            query_num += 1
    
    print(f"{Colors.CYAN}{'='*table_width}{Colors.ENDC}\n")


def aggregate_results(all_results: list) -> list:
    """
    Aggregate results from multiple benchmark runs by calculating means.
    
    Groups results by model and test type, then calculates mean values for all metrics.
    
    Args:
        all_results: List of result dictionaries from multiple runs
        
    Returns:
        List of aggregated result dictionaries with mean values
    """
    # Group results by (model, test_type) - test_type is determined by position
    # For consistency tests: query_number 1-3
    # For rapid tests: query_number 1-2
    groups = {}
    
    for result in all_results:
        if not result.get('success'):
            continue
        
        model = result.get('model', 'unknown')
        # Determine test type based on context (we'll pass this info)
        # For now, we'll group by model only and calculate overall means
        
        if model not in groups:
            groups[model] = []
        groups[model].append(result)
    
    aggregated = []
    for model, model_results in groups.items():
        if not model_results:
            continue
        
        # Calculate means
        elapsed_times = [r['elapsed_time'] for r in model_results]
        prompt_tokens_list = [r.get('prompt_tokens', 0) for r in model_results]
        completion_tokens_list = [r.get('completion_tokens', 0) for r in model_results]
        total_tokens_list = [r.get('total_tokens', 0) for r in model_results]
        tokens_per_sec_list = [r.get('tokens_per_second', 0) for r in model_results if r.get('tokens_per_second', 0) > 0]
        
        mean_elapsed = sum(elapsed_times) / len(elapsed_times)
        mean_prompt_tokens = sum(prompt_tokens_list) / len(prompt_tokens_list) if prompt_tokens_list else 0
        mean_completion_tokens = sum(completion_tokens_list) / len(completion_tokens_list) if completion_tokens_list else 0
        mean_total_tokens = sum(total_tokens_list) / len(total_tokens_list) if total_tokens_list else 0
        mean_tokens_per_sec = sum(tokens_per_sec_list) / len(tokens_per_sec_list) if tokens_per_sec_list else 0
        
        # Calculate standard deviation for elapsed_time
        variance = sum((t - mean_elapsed) ** 2 for t in elapsed_times) / len(elapsed_times)
        std_dev = variance ** 0.5
        
        aggregated.append({
            'success': True,
            'model': model,
            'elapsed_time': mean_elapsed,
            'elapsed_std_dev': std_dev,
            'prompt_tokens': round(mean_prompt_tokens),
            'completion_tokens': round(mean_completion_tokens),
            'total_tokens': round(mean_total_tokens),
            'tokens_per_second': mean_tokens_per_sec,
            'runs': len(model_results),
            'min_elapsed': min(elapsed_times),
            'max_elapsed': max(elapsed_times)
        })
    
    return aggregated


def aggregate_by_test_type(results: list, rapid_results: list) -> tuple:
    """
    Aggregate results separately for consistency and rapid tests.
    
    Args:
        results: List of consistency test results from all runs
        rapid_results: List of rapid test results from all runs
        
    Returns:
        Tuple of (aggregated_consistency_results, aggregated_rapid_results)
    """
    # Group consistency results by (model, query_position)
    consistency_groups = {}
    for i, result in enumerate(results):
        if not result.get('success'):
            continue
        model = result.get('model', 'unknown')
        # Group by model - we'll show one aggregated row per model
        if model not in consistency_groups:
            consistency_groups[model] = []
        consistency_groups[model].append(result)
    
    # Group rapid results by (model, query_position)
    rapid_groups = {}
    for i, result in enumerate(rapid_results):
        if not result.get('success'):
            continue
        model = result.get('model', 'unknown')
        if model not in rapid_groups:
            rapid_groups[model] = []
        rapid_groups[model].append(result)
    
    # Aggregate each group
    aggregated_consistency = []
    for model, model_results in consistency_groups.items():
        elapsed_times = [r['elapsed_time'] for r in model_results]
        prompt_tokens_list = [r.get('prompt_tokens', 0) for r in model_results]
        completion_tokens_list = [r.get('completion_tokens', 0) for r in model_results]
        total_tokens_list = [r.get('total_tokens', 0) for r in model_results]
        tokens_per_sec_list = [r.get('tokens_per_second', 0) for r in model_results if r.get('tokens_per_second', 0) > 0]
        
        mean_elapsed = sum(elapsed_times) / len(elapsed_times)
        mean_prompt_tokens = sum(prompt_tokens_list) / len(prompt_tokens_list) if prompt_tokens_list else 0
        mean_completion_tokens = sum(completion_tokens_list) / len(completion_tokens_list) if completion_tokens_list else 0
        mean_total_tokens = sum(total_tokens_list) / len(total_tokens_list) if total_tokens_list else 0
        mean_tokens_per_sec = sum(tokens_per_sec_list) / len(tokens_per_sec_list) if tokens_per_sec_list else 0
        
        variance = sum((t - mean_elapsed) ** 2 for t in elapsed_times) / len(elapsed_times)
        std_dev = variance ** 0.5
        
        aggregated_consistency.append({
            'success': True,
            'model': model,
            'elapsed_time': mean_elapsed,
            'elapsed_std_dev': std_dev,
            'prompt_tokens': round(mean_prompt_tokens),
            'completion_tokens': round(mean_completion_tokens),
            'total_tokens': round(mean_total_tokens),
            'tokens_per_second': mean_tokens_per_sec,
            'runs': len(model_results),
            'min_elapsed': min(elapsed_times),
            'max_elapsed': max(elapsed_times)
        })
    
    aggregated_rapid = []
    for model, model_results in rapid_groups.items():
        elapsed_times = [r['elapsed_time'] for r in model_results]
        prompt_tokens_list = [r.get('prompt_tokens', 0) for r in model_results]
        completion_tokens_list = [r.get('completion_tokens', 0) for r in model_results]
        total_tokens_list = [r.get('total_tokens', 0) for r in model_results]
        tokens_per_sec_list = [r.get('tokens_per_second', 0) for r in model_results if r.get('tokens_per_second', 0) > 0]
        
        mean_elapsed = sum(elapsed_times) / len(elapsed_times)
        mean_prompt_tokens = sum(prompt_tokens_list) / len(prompt_tokens_list) if prompt_tokens_list else 0
        mean_completion_tokens = sum(completion_tokens_list) / len(completion_tokens_list) if completion_tokens_list else 0
        mean_total_tokens = sum(total_tokens_list) / len(total_tokens_list) if total_tokens_list else 0
        mean_tokens_per_sec = sum(tokens_per_sec_list) / len(tokens_per_sec_list) if tokens_per_sec_list else 0
        
        variance = sum((t - mean_elapsed) ** 2 for t in elapsed_times) / len(elapsed_times)
        std_dev = variance ** 0.5
        
        aggregated_rapid.append({
            'success': True,
            'model': model,
            'elapsed_time': mean_elapsed,
            'elapsed_std_dev': std_dev,
            'prompt_tokens': round(mean_prompt_tokens),
            'completion_tokens': round(mean_completion_tokens),
            'total_tokens': round(mean_total_tokens),
            'tokens_per_second': mean_tokens_per_sec,
            'runs': len(model_results),
            'min_elapsed': min(elapsed_times),
            'max_elapsed': max(elapsed_times)
        })
    
    return aggregated_consistency, aggregated_rapid


def print_insights(results: list, rapid_results: list, model_info_cache: Dict[str, Dict[str, Any]]):
    """
    Analyze benchmark results and provide user-focused insights and recommendations.
    
    Args:
        results: List of results from multiple query test
        rapid_results: List of results from rapid query test
        model_info_cache: Dictionary mapping model names to their info dictionaries
    """
    print_header("Performance Insights & Recommendations")
    
    # Check if results are aggregated
    is_aggregated = any(r.get('runs') or r.get('iterations') for r in results + rapid_results)
    iterations = results[0].get('iterations') or results[0].get('runs') if results else None
    
    if is_aggregated and iterations:
        print(f"{Colors.CYAN}Analysis based on {iterations} benchmark iterations (mean values){Colors.ENDC}\n")
    
    # Separate council and individual model results
    council_results = [r for r in results if r.get('model') == 'council' and r.get('success')]
    individual_results = [r for r in results if r.get('model') != 'council' and r.get('success')]
    council_rapid = [r for r in rapid_results if r.get('model') == 'council' and r.get('success')]
    individual_rapid = [r for r in rapid_results if r.get('model') != 'council' and r.get('success')]
    
    # Group individual results by model
    model_groups = {}
    for result in individual_results:
        model = result.get('model', 'unknown')
        if model not in model_groups:
            model_groups[model] = []
        model_groups[model].append(result)
    
    # Individual Model Analysis
    if model_groups:
        print(f"\n{Colors.BOLD}Individual Model Performance:{Colors.ENDC}")
        
        model_stats = []
        for model, model_results in model_groups.items():
            if model_results:
                times = [r['elapsed_time'] for r in model_results]
                tokens_per_sec = [r.get('tokens_per_second', 0) for r in model_results if r.get('tokens_per_second', 0) > 0]
                scores = [calculate_performance_score(r) for r in model_results]
                
                avg_time = sum(times) / len(times)
                avg_tokens_per_sec = sum(tokens_per_sec) / len(tokens_per_sec) if tokens_per_sec else 0
                avg_score = sum(scores) / len(scores) if scores else 0
                consistency = ((max(times) - min(times)) / avg_time * 100) if avg_time > 0 else 0
                
                model_stats.append({
                    'model': model,
                    'avg_time': avg_time,
                    'avg_tokens_per_sec': avg_tokens_per_sec,
                    'avg_score': avg_score,
                    'consistency': consistency,
                    'quantization': model_info_cache.get(model, {}).get('quantization', 'N/A') if model_info_cache.get(model) else 'N/A'
                })
        
        # Sort by average score (best first)
        model_stats.sort(key=lambda x: x['avg_score'], reverse=True)
        
        print(f"\n  {Colors.BOLD}Top Performers:{Colors.ENDC}")
        for i, stat in enumerate(model_stats[:3], 1):
            quant_str = f" ({stat['quantization']})" if stat['quantization'] != 'N/A' else ''
            print(f"    {i}. {Colors.GREEN}{stat['model']}{quant_str}{Colors.ENDC}")
            
            # Show range if aggregated (we have min/max from original results)
            if is_aggregated and iterations:
                # Try to find min/max from results
                model_result = next((r for r in individual_results if r.get('model') == stat['model']), None)
                if model_result and 'min_elapsed' in model_result:
                    print(f"       Average: {stat['avg_time']:.2f}s (range: {model_result['min_elapsed']:.2f}s - {model_result['max_elapsed']:.2f}s)")
                else:
                    print(f"       Average: {stat['avg_time']:.2f}s")
            else:
                print(f"       Average: {stat['avg_time']:.2f}s")
            
            print(f"       Speed: {stat['avg_tokens_per_sec']:.1f} tokens/sec, Score: {stat['avg_score']:.1f}")
            if stat['consistency'] < 30:
                print(f"       {Colors.GREEN}✓ Excellent consistency ({stat['consistency']:.1f}% variation){Colors.ENDC}")
            elif stat['consistency'] < 50:
                print(f"       {Colors.YELLOW}⚠ Good consistency ({stat['consistency']:.1f}% variation){Colors.ENDC}")
            else:
                print(f"       {Colors.RED}⚠ High variation ({stat['consistency']:.1f}% variation) - may need tuning{Colors.ENDC}")
        
        if len(model_stats) > 3:
            print(f"\n  {Colors.BOLD}Other Models:{Colors.ENDC}")
            for stat in model_stats[3:]:
                quant_str = f" ({stat['quantization']})" if stat['quantization'] != 'N/A' else ''
                print(f"    - {stat['model']}{quant_str}: {stat['avg_time']:.2f}s avg, Score: {stat['avg_score']:.1f}")
    
    # Council Analysis
    if council_results:
        print(f"\n{Colors.BOLD}Council Composite Performance:{Colors.ENDC}")
        council_times = [r['elapsed_time'] for r in council_results]
        council_tokens = [r.get('tokens_per_second', 0) for r in council_results if r.get('tokens_per_second', 0) > 0]
        council_scores = [calculate_performance_score(r) for r in council_results]
        
        avg_council_time = sum(council_times) / len(council_times)
        avg_council_tokens = sum(council_tokens) / len(council_tokens) if council_tokens else 0
        avg_council_score = sum(council_scores) / len(council_scores) if council_scores else 0
        council_consistency = ((max(council_times) - min(council_times)) / avg_council_time * 100) if avg_council_time > 0 else 0
        
        print(f"  Average response time: {avg_council_time:.2f}s")
        print(f"  Average speed: {avg_council_tokens:.1f} tokens/sec")
        print(f"  Average score: {avg_council_score:.1f}")
        print(f"  Consistency: {council_consistency:.1f}% variation")
        
        # Compare to individual models
        if individual_results:
            avg_individual_time = sum(r['elapsed_time'] for r in individual_results) / len(individual_results)
            overhead = ((avg_council_time - avg_individual_time) / avg_individual_time * 100) if avg_individual_time > 0 else 0
            print(f"\n  {Colors.BOLD}Council Overhead:{Colors.ENDC}")
            print(f"    Council is {overhead:.1f}% slower than individual models")
            print(f"    This is expected due to multi-stage orchestration (Stage 1 → Stage 2 → Stage 3)")
            if overhead > 300:
                print(f"    {Colors.YELLOW}⚠ High overhead - consider optimizing council workflow{Colors.ENDC}")
            elif overhead > 200:
                print(f"    {Colors.YELLOW}⚠ Moderate overhead - acceptable for multi-stage process{Colors.ENDC}")
            else:
                print(f"    {Colors.GREEN}✓ Overhead is reasonable for orchestrated workflow{Colors.ENDC}")
    
    # Keep-Alive Analysis
    if individual_rapid and len(individual_rapid) >= 2:
        print(f"\n{Colors.BOLD}Keep-Alive Effectiveness (Individual Models):{Colors.ENDC}")
        improvements = []
        for i in range(0, len(individual_rapid) - 1, 2):
            if i + 1 < len(individual_rapid):
                r1, r2 = individual_rapid[i], individual_rapid[i + 1]
                if r1.get('success') and r2.get('success') and r1.get('model') == r2.get('model'):
                    if r2['elapsed_time'] < r1['elapsed_time']:
                        improvement = ((r1['elapsed_time'] - r2['elapsed_time']) / r1['elapsed_time']) * 100
                        improvements.append((r1.get('model'), improvement))
        
        if improvements:
            avg_improvement = sum(imp[1] for imp in improvements) / len(improvements)
            print(f"  Average improvement: {avg_improvement:.1f}% faster on second query")
            if avg_improvement > 20:
                print(f"  {Colors.GREEN}✓ Excellent keep-alive - models staying loaded effectively{Colors.ENDC}")
            elif avg_improvement > 10:
                print(f"  {Colors.YELLOW}⚠ Good keep-alive - models mostly staying loaded{Colors.ENDC}")
            else:
                print(f"  {Colors.YELLOW}⚠ Limited keep-alive benefit - models may be reloading{Colors.ENDC}")
                print(f"     Consider increasing OLLAMA_MAX_LOADED_MODELS or reducing model sizes")
    
    if council_rapid and len(council_rapid) >= 2:
        print(f"\n{Colors.BOLD}Keep-Alive Effectiveness (Council):{Colors.ENDC}")
        council_improvements = []
        for i in range(0, len(council_rapid) - 1, 2):
            if i + 1 < len(council_rapid):
                r1, r2 = council_rapid[i], council_rapid[i + 1]
                if r1.get('success') and r2.get('success'):
                    if r2['elapsed_time'] < r1['elapsed_time']:
                        improvement = ((r1['elapsed_time'] - r2['elapsed_time']) / r1['elapsed_time']) * 100
                        council_improvements.append(improvement)
        
        if council_improvements:
            avg_improvement = sum(council_improvements) / len(council_improvements)
            print(f"  Average improvement: {avg_improvement:.1f}% faster on second query")
            if avg_improvement > 15:
                print(f"  {Colors.GREEN}✓ Council keep-alive working well{Colors.ENDC}")
            elif avg_improvement > 5:
                print(f"  {Colors.YELLOW}⚠ Council keep-alive moderate - some improvement{Colors.ENDC}")
            else:
                print(f"  {Colors.YELLOW}⚠ Limited council keep-alive - models reloading between stages{Colors.ENDC}")
    
    # Performance Recommendations
    print(f"\n{Colors.BOLD}Recommendations:{Colors.ENDC}")
    
    recommendations = []
    
    # Check for slow council performance
    if council_results:
        avg_council_time = sum(r['elapsed_time'] for r in council_results) / len(council_results)
        if avg_council_time > 45:
            recommendations.append(f"{Colors.RED}⚠ Council average time ({avg_council_time:.1f}s) is high{Colors.ENDC}")
            recommendations.append("   - Check GPU memory: nvidia-smi")
            recommendations.append("   - Review Ollama logs: docker logs ollama")
            recommendations.append("   - Consider reducing model sizes or number of council members")
        elif avg_council_time > 30:
            recommendations.append(f"{Colors.YELLOW}⚠ Council average time ({avg_council_time:.1f}s) could be improved{Colors.ENDC}")
            recommendations.append("   - Consider optimizing model selection")
            recommendations.append("   - Check if OLLAMA_MAX_LOADED_MODELS is set appropriately")
    
    # Check for high variation
    if individual_results:
        model_variations = {}
        for result in individual_results:
            model = result.get('model')
            if model not in model_variations:
                model_variations[model] = []
            model_variations[model].append(result['elapsed_time'])
        
        high_variation_models = []
        for model, times in model_variations.items():
            if len(times) >= 3:
                avg = sum(times) / len(times)
                variation = ((max(times) - min(times)) / avg * 100) if avg > 0 else 0
                if variation > 50:
                    high_variation_models.append((model, variation))
        
        if high_variation_models:
            recommendations.append(f"{Colors.YELLOW}⚠ Some models show high variation:{Colors.ENDC}")
            for model, variation in high_variation_models:
                recommendations.append(f"   - {model}: {variation:.1f}% variation")
            recommendations.append("   - This may indicate model loading/eviction issues")
            recommendations.append("   - Check GPU memory availability and OLLAMA_MAX_LOADED_MODELS")
    
    # Check for very slow individual models
    if individual_results:
        slow_models = []
        for result in individual_results:
            if result['elapsed_time'] > 10:
                model = result.get('model')
                if model not in [m[0] for m in slow_models]:
                    model_times = [r['elapsed_time'] for r in individual_results if r.get('model') == model]
                    avg_time = sum(model_times) / len(model_times)
                    if avg_time > 10:
                        slow_models.append((model, avg_time))
        
        if slow_models:
            recommendations.append(f"{Colors.YELLOW}⚠ Some models are slower than expected:{Colors.ENDC}")
            for model, avg_time in slow_models:
                recommendations.append(f"   - {model}: {avg_time:.1f}s average")
            recommendations.append("   - Consider using smaller quantizations (Q4_0 instead of Q5_0)")
            recommendations.append("   - Check if models are competing for GPU memory")
    
    if not recommendations:
        recommendations.append(f"{Colors.GREEN}✓ Performance looks good!{Colors.ENDC}")
        recommendations.append("   - All models performing within expected ranges")
        recommendations.append("   - Keep-alive appears to be working effectively")
    
    for rec in recommendations:
        print(f"  {rec}")
    
    print()


def print_summary(results: list, rapid_results: list, model_info_cache: Dict[str, Dict[str, Any]]):
    """Print performance summary with enhanced benchmarking metrics."""
    print_header("Performance Summary")
    
    if not results:
        print(f"{Colors.RED}No test results available{Colors.ENDC}")
        return
    
    # Check if results are aggregated
    is_aggregated = any(r.get('runs') or r.get('iterations') for r in results + rapid_results)
    iterations = results[0].get('iterations') or results[0].get('runs') if results else None
    
    if is_aggregated and iterations:
        print(f"{Colors.CYAN}Results aggregated from {iterations} iterations (showing mean values){Colors.ENDC}\n")
    
    # Display model information if available
    if model_info_cache:
        print(f"{Colors.BOLD}Models Tested:{Colors.ENDC}")
        for model_name, info in model_info_cache.items():
            if info:
                print(f"  {model_name}: {info.get('quantization', 'N/A')} quantization")
        print()
    
    # Multiple query statistics
    successful = [r for r in results if r.get('success')]
    if successful:
        times = [r['elapsed_time'] for r in successful]
        avg_time = sum(times) / len(times)
        min_time = min(times)
        max_time = max(times)
        
        # Token statistics
        token_speeds = [r.get('tokens_per_second', 0) for r in successful if r.get('tokens_per_second', 0) > 0]
        completion_tokens_list = [r.get('completion_tokens', 0) for r in successful]
        prompt_tokens_list = [r.get('prompt_tokens', 0) for r in successful]
        total_tokens_list = [r.get('total_tokens', 0) for r in successful]
        
        print(f"{Colors.BOLD}Multiple Query Test:{Colors.ENDC}")
        print(f"  Successful queries: {len(successful)}/{len(results)}")
        print(f"  Average time: {avg_time:.2f}s")
        print(f"  Fastest: {min_time:.2f}s")
        print(f"  Slowest: {max_time:.2f}s")
        print(f"  Consistency: {((max_time - min_time) / avg_time * 100):.1f}% variation")
        
        # Token metrics
        if token_speeds:
            avg_tokens_per_sec = sum(token_speeds) / len(token_speeds)
            min_tokens_per_sec = min(token_speeds)
            max_tokens_per_sec = max(token_speeds)
            print(f"\n  {Colors.BOLD}Token Performance:{Colors.ENDC}")
            print(f"    Average speed: {avg_tokens_per_sec:.2f} tokens/sec")
            print(f"    Fastest: {max_tokens_per_sec:.2f} tokens/sec")
            print(f"    Slowest: {min_tokens_per_sec:.2f} tokens/sec")
        
        if completion_tokens_list and any(completion_tokens_list):
            avg_completion_tokens = sum(completion_tokens_list) / len(completion_tokens_list)
            avg_prompt_tokens = sum(prompt_tokens_list) / len(prompt_tokens_list) if prompt_tokens_list else 0
            avg_total_tokens = sum(total_tokens_list) / len(total_tokens_list) if total_tokens_list else 0
            print(f"\n  {Colors.BOLD}Token Breakdown:{Colors.ENDC}")
            print(f"    Average prompt tokens: {avg_prompt_tokens:.1f}")
            print(f"    Average completion tokens: {avg_completion_tokens:.1f}")
            print(f"    Average total tokens: {avg_total_tokens:.1f}")
    
    # Rapid query comparison
    if rapid_results and len(rapid_results) >= 2:
        r1, r2 = rapid_results[0], rapid_results[1]
        if r1.get('success') and r2.get('success'):
            print(f"\n{Colors.BOLD}Rapid Query Test (Keep-Alive):{Colors.ENDC}")
            print(f"  First query: {r1['elapsed_time']:.2f}s")
            if r1.get('tokens_per_second', 0) > 0:
                print(f"    Speed: {r1['tokens_per_second']:.2f} tokens/sec")
            print(f"  Second query: {r2['elapsed_time']:.2f}s")
            if r2.get('tokens_per_second', 0) > 0:
                print(f"    Speed: {r2['tokens_per_second']:.2f} tokens/sec")
            
            if r2['elapsed_time'] < r1['elapsed_time']:
                improvement = ((r1['elapsed_time'] - r2['elapsed_time']) / r1['elapsed_time']) * 100
                print(f"  {Colors.GREEN}Improvement: {improvement:.1f}% faster{Colors.ENDC}")
                print(f"  {Colors.GREEN}✓ Keep-alive appears to be working{Colors.ENDC}")
            else:
                print(f"  {Colors.YELLOW}No improvement detected - may need tuning{Colors.ENDC}")
    
    # Performance expectations
    print(f"\n{Colors.BOLD}Expected Performance (with optimizations):{Colors.ENDC}")
    print(f"  - First query: 15-30s (includes model loading)")
    print(f"  - Subsequent queries: 10-20s (models stay loaded)")
    print(f"  - Consistency: <30% variation between queries")
    
    # Check if results meet expectations
    if successful:
        if avg_time < 30:
            print(f"\n{Colors.GREEN}✓ Performance meets expectations{Colors.ENDC}")
        elif avg_time < 45:
            print(f"\n{Colors.YELLOW}⚠ Performance is acceptable but could be better{Colors.ENDC}")
        else:
            print(f"\n{Colors.RED}⚠ Performance is slower than expected{Colors.ENDC}")
            print(f"   Check: GPU memory, model sizes, Ollama logs")
    
    # Prompt information
    print(f"\n{Colors.BOLD}Test Configuration:{Colors.ENDC}")
    print(f"  Prompt length: ~{len(TEST_QUERY_1)} characters (standardized)")
    print(f"  Test queries: 3 consistency + 2 rapid")
    
    # Display benchmark table
    display_benchmark_table(results, rapid_results, model_info_cache)
    
    # Print insights and recommendations
    print_insights(results, rapid_results, model_info_cache)


async def main():
    """Main test execution."""
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='Performance test for Ollama optimizations with benchmarking metrics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic test (single iteration)
  python3 tests/runtime-core/test_council_performance.py
  
  # With warmup (recommended for accurate benchmarks)
  python3 tests/runtime-core/test_council_performance.py --warmup
  
  # Run 5 iterations and aggregate results
  python3 tests/runtime-core/test_council_performance.py --iterations 5
  
  # Warmup + multiple iterations
  python3 tests/runtime-core/test_council_performance.py --warmup --iterations 3
        """
    )
    parser.add_argument(
        '--warmup',
        action='store_true',
        help='Warm up models before benchmarking (recommended for accurate results)'
    )
    parser.add_argument(
        '--no-warmup',
        action='store_true',
        help='Explicitly disable warmup (default behavior)'
    )
    parser.add_argument(
        '--iterations',
        type=int,
        default=1,
        metavar='N',
        help='Number of benchmark iterations to run (default: 1). Results will be aggregated and mean values reported.'
    )
    
    args = parser.parse_args()
    
    if args.iterations < 1:
        print(f"{Colors.RED}Error: --iterations must be >= 1{Colors.ENDC}")
        sys.exit(1)
    
    print_header("Ollama Performance Test - User Experience")
    
    print(f"Test started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"API URL: {API_BASE_URL}")
    print(f"Ollama URL: {OLLAMA_BASE_URL}")
    if args.warmup:
        print(f"{Colors.CYAN}Warmup: Enabled{Colors.ENDC}")
    if args.iterations > 1:
        print(f"{Colors.CYAN}Iterations: {args.iterations} (results will be aggregated){Colors.ENDC}")
    
    # Check service health
    print_section("Pre-flight Checks")
    if not await check_service_health():
        print(f"{Colors.RED}❌ Services are not accessible{Colors.ENDC}")
        print(f"   Please ensure services are running:")
        print(f"   ./aixcl stack start")
        sys.exit(1)
    print(f"{Colors.GREEN}✓ Services are accessible{Colors.ENDC}")
    
    # Get configuration
    config = await get_council_config()
    if not config:
        print(f"{Colors.RED}❌ Failed to get council configuration{Colors.ENDC}")
        sys.exit(1)
    
    council_models = config.get('council_models', [])
    chairman_model = config.get('chairman_model', '')
    
    if not council_models:
        print(f"{Colors.RED}❌ No council models configured{Colors.ENDC}")
        print(f"   Please configure with: ./aixcl council configure")
        sys.exit(1)
    
    print(f"{Colors.GREEN}✓ Council configuration loaded{Colors.ENDC}")
    print(f"   Council models: {len(council_models)}")
    print(f"   Chairman: {chairman_model if chairman_model else '(not set)'}")
    
    # Collect all models to test: individual models + council composite
    models_to_test = []
    if chairman_model:
        models_to_test.append(chairman_model)
    models_to_test.extend(council_models)
    # Add council composite test at the end
    models_to_test.append('council')
    
    # Remove duplicates while preserving order
    seen = set()
    models_to_test = [m for m in models_to_test if m not in seen and not seen.add(m)]
    
    print(f"\n{Colors.CYAN}Models to benchmark: {len(models_to_test)}{Colors.ENDC}")
    for i, model in enumerate(models_to_test, 1):
        print(f"  {i}. {model}")
    
    # Pre-fetch model information for all models
    print(f"\n{Colors.CYAN}Fetching model information...{Colors.ENDC}")
    model_info_cache = {}
    for model_name in models_to_test:
        if model_name != 'council':
            try:
                info = await get_ollama_model_info(model_name)
                model_info_cache[model_name] = info
                quant_str = info.get('quantization') or 'N/A'
                ctx_val = info.get('context_size')
                ctx_str = str(ctx_val) if ctx_val else 'default'
                print(f"  {Colors.GREEN}✓{Colors.ENDC} {model_name} (quant: {quant_str}, ctx: {ctx_str})")
            except Exception as e:
                # Silently continue if model info fetch fails
                model_info_cache[model_name] = None
                print(f"  {Colors.YELLOW}⚠{Colors.ENDC} {model_name} (info unavailable: {str(e)[:50]})")
    
    # Warmup if requested (only once before all iterations)
    if args.warmup and not args.no_warmup:
        await warmup_models(models_to_test)
    
    # Collect all results from all iterations
    all_multiple_results = []
    all_rapid_results = []
    
    # Run tests N times
    print(f"\n{Colors.YELLOW}Starting performance tests...{Colors.ENDC}")
    print(f"{Colors.YELLOW}Testing all models individually + council composite{Colors.ENDC}")
    if args.iterations > 1:
        print(f"{Colors.YELLOW}Running {args.iterations} iterations - results will be aggregated{Colors.ENDC}\n")
    else:
        print()
    
    for iteration in range(1, args.iterations + 1):
        if args.iterations > 1:
            print_section(f"Iteration {iteration}/{args.iterations}")
        
        # Test 1: Multiple queries
        multiple_results = await test_multiple_queries(models_to_test)
        all_multiple_results.extend(multiple_results)
        
        # Small delay between test types
        if iteration < args.iterations:
            print(f"\n{Colors.CYAN}Waiting 3 seconds before rapid query test...{Colors.ENDC}")
        else:
            print(f"\n{Colors.CYAN}Waiting 3 seconds before rapid query test...{Colors.ENDC}")
        await asyncio.sleep(3)
        
        # Test 2: Rapid queries
        rapid_results = await test_rapid_queries(models_to_test)
        all_rapid_results.extend(rapid_results)
        
        # Delay between iterations (except after last)
        if iteration < args.iterations:
            print(f"\n{Colors.CYAN}Iteration {iteration} complete. Waiting 5 seconds before next iteration...{Colors.ENDC}\n")
            await asyncio.sleep(5)
    
    # Aggregate results if multiple iterations
    if args.iterations > 1:
        print_section("Aggregating Results")
        print(f"Aggregating results from {args.iterations} iterations...")
        aggregated_multiple, aggregated_rapid = aggregate_by_test_type(all_multiple_results, all_rapid_results)
        
        # Add iteration info to aggregated results
        for result in aggregated_multiple + aggregated_rapid:
            result['iterations'] = args.iterations
        
        # Print summary with aggregated results
        print_summary(aggregated_multiple, aggregated_rapid, model_info_cache)
    else:
        # Single iteration - use results as-is
        print_summary(multiple_results, rapid_results, model_info_cache)
    
    print_header("Test Complete")
    print(f"Test completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\n{Colors.CYAN}Next steps:{Colors.ENDC}")
    print(f"  1. Review performance summary, benchmark table, and insights above")
    print(f"  2. Check GPU memory: nvidia-smi")
    print(f"  3. Check Ollama logs: docker logs ollama")
    print(f"  4. Follow recommendations in the insights section")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Test interrupted by user{Colors.ENDC}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}❌ Test failed: {e}{Colors.ENDC}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

