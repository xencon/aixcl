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
    
    # Option 4: With benchmarking features
    python3 tests/runtime-core/test_council_performance.py --warmup --csv benchmark.csv
"""

import argparse
import asyncio
import csv
import httpx
import json
import os
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
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Try /api/show endpoint first (more detailed)
            response = await client.post(
                f"{OLLAMA_BASE_URL}/api/show",
                json={"name": model_name}
            )
            if response.status_code == 200:
                data = response.json()
                info = {
                    'name': model_name,
                    'quantization': _extract_quantization(model_name),
                    'context_size': data.get('modelfile', {}).get('parameter', {}).get('num_ctx') if isinstance(data.get('modelfile'), dict) else None,
                    'details': data
                }
                _model_info_cache[model_name] = info
                return info
    except Exception:
        # Silently fall back to name-based extraction if API call fails
        # This is acceptable in test context where model info is optional
        pass
    
    # Fallback: try to extract info from model name
    info = {
        'name': model_name,
        'quantization': _extract_quantization(model_name),
        'context_size': None,
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
                    'error': f'HTTP {response.status_code}: {response_text}'
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
                prompt_tokens = usage_data.get('prompt_tokens', 0)
                completion_tokens = usage_data.get('completion_tokens', 0)
                total_tokens = usage_data.get('total_tokens', 0)
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
                    'tokens_per_second': tokens_per_second
                }
            
            # Handle non-streaming JSON response
            try:
                data = response.json()
            except json.JSONDecodeError as e:
                response_text = response.text[:500]
                return {
                    'success': False,
                    'elapsed_time': elapsed,
                    'error': f'JSON decode error: {str(e)[:50]}. Response preview: {response_text[:200]}'
                }
            
            # Extract response info
            choices = data.get('choices', [])
            has_content = bool(choices and choices[0].get('message', {}).get('content'))
            
            # Extract token metrics from usage field
            usage = data.get('usage', {})
            prompt_tokens = usage.get('prompt_tokens', 0)
            completion_tokens = usage.get('completion_tokens', 0)
            total_tokens = usage.get('total_tokens', 0)
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
                'tokens_per_second': tokens_per_second
            }
    except httpx.TimeoutException:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': 'Timeout (180s)'
        }
    except httpx.RequestError as e:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': f'Request error: {str(e)[:100]}'
        }
    except Exception as e:
        elapsed = time.time() - start_time
        return {
            'success': False,
            'elapsed_time': elapsed,
            'error': f'{type(e).__name__}: {str(e)[:100]}'
        }


async def test_multiple_queries():
    """Test multiple council queries to measure consistency."""
    print_section("Multiple Query Test (Consistency)")
    print("Running 3 council queries to measure performance consistency...")
    
    results = []
    queries = [
        ("Query 1", TEST_QUERY_1),
        ("Query 2", TEST_QUERY_2),
        ("Query 3", TEST_QUERY_1),  # Repeat first query
    ]
    
    for i, (name, query) in enumerate(queries, 1):
        print(f"\n[{i}/3] {name}")
        result = await test_council_api(query, name)
        results.append(result)
        
        if result['success']:
            print(f"  {Colors.GREEN}✓ Success{Colors.ENDC} - Time: {result['elapsed_time']:.2f}s")
            if result.get('response_length'):
                print(f"  Response length: {result['response_length']} chars")
            if result.get('completion_tokens'):
                print(f"  Tokens: {result.get('completion_tokens', 0)} completion / {result.get('total_tokens', 0)} total")
                if result.get('tokens_per_second', 0) > 0:
                    print(f"  Speed: {result['tokens_per_second']:.2f} tokens/sec")
        else:
            print(f"  {Colors.RED}✗ Failed{Colors.ENDC} - {result.get('error', 'Unknown error')}")
        
        # Small delay between queries
        if i < len(queries):
            await asyncio.sleep(2)
    
    return results


async def test_rapid_queries():
    """Test rapid successive queries (testing keep-alive)."""
    print_section("Rapid Query Test (Keep-Alive)")
    print("Running 2 rapid queries to test if models stay loaded...")
    
    # First query (cold start or warm)
    print("\n[1/2] First Query")
    result1 = await test_council_api(TEST_QUERY_1, "First Query")
    
    if result1['success']:
        print(f"  {Colors.GREEN}✓ Success{Colors.ENDC} - Time: {result1['elapsed_time']:.2f}s")
        if result1.get('tokens_per_second', 0) > 0:
            print(f"  Speed: {result1['tokens_per_second']:.2f} tokens/sec")
    else:
        print(f"  {Colors.RED}✗ Failed{Colors.ENDC}")
        return [result1]
    
    # Second query immediately after (should be faster if models stayed loaded)
    print("\n[2/2] Second Query (Immediate)")
    await asyncio.sleep(1)  # Very short delay
    result2 = await test_council_api(TEST_QUERY_2, "Second Query")
    
    if result2['success']:
        print(f"  {Colors.GREEN}✓ Success{Colors.ENDC} - Time: {result2['elapsed_time']:.2f}s")
        if result2.get('tokens_per_second', 0) > 0:
            print(f"  Speed: {result2['tokens_per_second']:.2f} tokens/sec")
        
        # Compare times
        if result2['elapsed_time'] < result1['elapsed_time'] * 0.9:
            improvement = ((result1['elapsed_time'] - result2['elapsed_time']) / result1['elapsed_time']) * 100
            print(f"  {Colors.GREEN}→ Second query was {improvement:.1f}% faster (models likely stayed loaded){Colors.ENDC}")
        elif result2['elapsed_time'] > result1['elapsed_time'] * 1.1:
            slowdown = ((result2['elapsed_time'] - result1['elapsed_time']) / result1['elapsed_time']) * 100
            print(f"  {Colors.YELLOW}→ Second query was {slowdown:.1f}% slower (possible model reload){Colors.ENDC}")
        else:
            print(f"  {Colors.CYAN}→ Similar performance (models may have stayed loaded){Colors.ENDC}")
    else:
        print(f"  {Colors.RED}✗ Failed{Colors.ENDC}")
    
    return [result1, result2]


async def warmup_model():
    """
    Warm up the model by running a simple query.
    
    This pre-loads models into GPU memory before benchmarking,
    ensuring more accurate performance measurements.
    """
    print_section("Model Warmup")
    print("Running warmup query to pre-load models...")
    print(f"  Query: {WARMUP_QUERY}")
    
    result = await test_council_api(WARMUP_QUERY, "Warmup")
    
    if result['success']:
        print(f"  {Colors.GREEN}✓ Warmup complete{Colors.ENDC} - Time: {result['elapsed_time']:.2f}s")
        print(f"  {Colors.CYAN}Models should now be loaded and ready for benchmarking{Colors.ENDC}\n")
        await asyncio.sleep(2)  # Brief pause after warmup
    else:
        print(f"  {Colors.YELLOW}⚠ Warmup failed, but continuing with benchmarks{Colors.ENDC}")
        print(f"  Error: {result.get('error', 'Unknown')}\n")


def export_to_csv(results: list, rapid_results: list, model_info: Optional[Dict[str, Any]], filename: str):
    """
    Export benchmark results to CSV file.
    
    Args:
        results: List of results from multiple query test
        rapid_results: List of results from rapid query test
        model_info: Model information dictionary
        filename: Output CSV filename
    """
    try:
        with open(filename, 'w', newline='') as csvfile:
            fieldnames = [
                'timestamp',
                'model',
                'quantization',
                'context_size',
                'prompt_tokens',
                'completion_tokens',
                'total_tokens',
                'elapsed_seconds',
                'tokens_per_second',
                'query_number',
                'test_type'
            ]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            model_name = model_info.get('name', 'council') if model_info else 'council'
            quantization = model_info.get('quantization', '') if model_info else ''
            context_size = model_info.get('context_size', '') if model_info else ''
            
            # Write multiple query test results
            for i, result in enumerate(results, 1):
                if result.get('success'):
                    writer.writerow({
                        'timestamp': timestamp,
                        'model': model_name,
                        'quantization': quantization,
                        'context_size': context_size or '',
                        'prompt_tokens': result.get('prompt_tokens', 0),
                        'completion_tokens': result.get('completion_tokens', 0),
                        'total_tokens': result.get('total_tokens', 0),
                        'elapsed_seconds': round(result.get('elapsed_time', 0), 2),
                        'tokens_per_second': round(result.get('tokens_per_second', 0), 2),
                        'query_number': i,
                        'test_type': 'consistency'
                    })
            
            # Write rapid query test results
            for i, result in enumerate(rapid_results, 1):
                if result.get('success'):
                    writer.writerow({
                        'timestamp': timestamp,
                        'model': model_name,
                        'quantization': quantization,
                        'context_size': context_size or '',
                        'prompt_tokens': result.get('prompt_tokens', 0),
                        'completion_tokens': result.get('completion_tokens', 0),
                        'total_tokens': result.get('total_tokens', 0),
                        'elapsed_seconds': round(result.get('elapsed_time', 0), 2),
                        'tokens_per_second': round(result.get('tokens_per_second', 0), 2),
                        'query_number': i,
                        'test_type': 'rapid'
                    })
        
        print(f"{Colors.GREEN}✓ Results exported to: {filename}{Colors.ENDC}")
    except Exception as e:
        print(f"{Colors.RED}✗ Failed to export CSV: {e}{Colors.ENDC}")


def print_summary(results: list, rapid_results: list, model_info: Optional[Dict[str, Any]] = None):
    """Print performance summary with enhanced benchmarking metrics."""
    print_header("Performance Summary")
    
    if not results:
        print(f"{Colors.RED}No test results available{Colors.ENDC}")
        return
    
    # Display model information if available
    if model_info:
        print(f"{Colors.BOLD}Model Information:{Colors.ENDC}")
        print(f"  Model: {model_info.get('name', 'council')}")
        quantization = model_info.get('quantization')
        if quantization:
            print(f"  Quantization: {quantization}")
        context_size = model_info.get('context_size')
        if context_size:
            print(f"  Context Size: {context_size}")
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


async def main():
    """Main test execution."""
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='Performance test for Ollama optimizations with benchmarking metrics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic test (backward compatible)
  python3 tests/runtime-core/test_council_performance.py
  
  # With warmup
  python3 tests/runtime-core/test_council_performance.py --warmup
  
  # Export to CSV
  python3 tests/runtime-core/test_council_performance.py --csv benchmark.csv
  
  # Both warmup and CSV export
  python3 tests/runtime-core/test_council_performance.py --warmup --csv benchmark.csv
        """
    )
    parser.add_argument(
        '--warmup',
        action='store_true',
        help='Warm up models before benchmarking (recommended for accurate results)'
    )
    parser.add_argument(
        '--csv',
        type=str,
        metavar='FILE',
        nargs='?',
        const='',
        help='Export results to CSV file. If FILE is not specified, uses default: benchmark_YYYYMMDD_HHMMSS.csv'
    )
    parser.add_argument(
        '--no-warmup',
        action='store_true',
        help='Explicitly disable warmup (default behavior)'
    )
    
    args = parser.parse_args()
    
    # Determine CSV filename
    csv_filename = None
    if args.csv is not None:
        # --csv was specified
        if args.csv == '':
            # --csv without value, use default filename
            csv_filename = f"benchmark_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        else:
            # --csv with value, use provided filename
            csv_filename = args.csv
    
    print_header("Ollama Performance Test - User Experience")
    
    print(f"Test started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"API URL: {API_BASE_URL}")
    print(f"Ollama URL: {OLLAMA_BASE_URL}")
    if args.warmup:
        print(f"{Colors.CYAN}Warmup: Enabled{Colors.ENDC}")
    if csv_filename:
        print(f"{Colors.CYAN}CSV Export: {csv_filename}{Colors.ENDC}")
    
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
    
    # Get model information (try to get info for chairman model as representative)
    model_info = None
    if chairman_model:
        try:
            model_info = await get_ollama_model_info(chairman_model)
        except Exception:
            # Silently continue if model info fetch fails (API may not be available)
            # Model info is optional for test execution
            pass
    
    # Warmup if requested
    if args.warmup and not args.no_warmup:
        await warmup_model()
    
    # Run tests
    print(f"\n{Colors.YELLOW}Starting performance tests...{Colors.ENDC}")
    print(f"{Colors.YELLOW}Note: This simulates real user experience{Colors.ENDC}\n")
    
    # Test 1: Multiple queries
    multiple_results = await test_multiple_queries()
    
    # Small delay
    print(f"\n{Colors.CYAN}Waiting 3 seconds before rapid query test...{Colors.ENDC}")
    await asyncio.sleep(3)
    
    # Test 2: Rapid queries
    rapid_results = await test_rapid_queries()
    
    # Print summary
    print_summary(multiple_results, rapid_results, model_info)
    
    # Export to CSV if requested
    if csv_filename:
        export_to_csv(multiple_results, rapid_results, model_info, csv_filename)
    
    print_header("Test Complete")
    print(f"Test completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\n{Colors.CYAN}Next steps:{Colors.ENDC}")
    print(f"  1. Review performance summary above")
    if csv_filename:
        print(f"  2. Review CSV export: {csv_filename}")
        print(f"  3. Check GPU memory: nvidia-smi")
    else:
        print(f"  2. Check GPU memory: nvidia-smi")
        print(f"  3. Check Ollama logs: docker logs ollama")
        print(f"  4. Adjust OLLAMA_MAX_LOADED_MODELS if needed")


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

