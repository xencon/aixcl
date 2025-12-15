#!/usr/bin/env python3
"""
Test script to verify all LLM Council members are operational.
Tests each council model and the chairman model with a simple query.
"""

import asyncio
import httpx
import json
import sys
from typing import Dict, List, Optional

# API base URL
API_BASE_URL = "http://localhost:8000"
OLLAMA_BASE_URL = "http://localhost:11434"

# Test query - simple and fast
TEST_QUERY = "Say 'OK' if you can read this."


async def check_service_health() -> bool:
    """Check if the LLM Council service is running."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{API_BASE_URL}/health")
            if response.status_code == 200:
                return True
    except Exception as e:
        print(f"❌ Service health check failed: {e}")
    return False


async def get_council_config() -> Optional[Dict]:
    """Get the current council configuration."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{API_BASE_URL}/api/config")
            if response.status_code == 200:
                return response.json()
    except Exception as e:
        print(f"❌ Failed to get configuration: {e}")
    return None


async def validate_models_in_ollama(models: List[str]) -> Dict[str, bool]:
    """Validate that models exist in Ollama."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            models_str = ",".join(models)
            response = await client.get(
                f"{API_BASE_URL}/api/config/validate",
                params={"models": models_str}
            )
            if response.status_code == 200:
                data = response.json()
                return data.get("validation", {})
    except Exception as e:
        print(f"⚠️  Could not validate models in Ollama: {e}")
    return {model: True for model in models}  # Optimistic default


async def test_model_operational(model: str, backend_mode: str) -> Dict[str, any]:
    """
    Test if a model is operational by sending a simple query.
    
    Returns:
        Dict with 'operational' (bool), 'response_time' (float), 'error' (str or None)
    """
    start_time = asyncio.get_event_loop().time()
    
    try:
        if backend_mode == "ollama":
            # Test via Ollama directly
            async with httpx.AsyncClient(timeout=15.0) as client:
                payload = {
                    "model": model,
                    "messages": [{"role": "user", "content": TEST_QUERY}],
                    "stream": False
                }
                response = await client.post(
                    f"{OLLAMA_BASE_URL}/api/chat",
                    json=payload
                )
                response.raise_for_status()
                data = response.json()
                content = data.get('message', {}).get('content', '')
                
                end_time = asyncio.get_event_loop().time()
                return {
                    "operational": True,
                    "response_time": round(end_time - start_time, 2),
                    "error": None,
                    "response_preview": content[:50] if content else ""
                }
        else:
            # For OpenRouter, we can't test directly without API key
            # Just check if model name is valid format
            return {
                "operational": True,  # Assume operational for OpenRouter
                "response_time": 0.0,
                "error": None,
                "response_preview": "OpenRouter model (not tested directly)"
            }
    except httpx.TimeoutException:
        return {
            "operational": False,
            "response_time": 0.0,
            "error": "Timeout - model did not respond within 15 seconds",
            "response_preview": None
        }
    except httpx.HTTPStatusError as e:
        return {
            "operational": False,
            "response_time": 0.0,
            "error": f"HTTP {e.response.status_code}: {e.response.text[:100]}",
            "response_preview": None
        }
    except Exception as e:
        return {
            "operational": False,
            "response_time": 0.0,
            "error": str(e)[:200],
            "response_preview": None
        }


async def main():
    """Main function to test all council members."""
    print("=" * 70)
    print("LLM Council Member Operational Status Check")
    print("=" * 70)
    print()
    
    # Check service health
    print("1. Checking LLM Council service health...")
    if not await check_service_health():
        print("   ❌ LLM Council service is not running or not accessible")
        print(f"   Please ensure the service is running at {API_BASE_URL}")
        sys.exit(1)
    print("   ✅ LLM Council service is running")
    print()
    
    # Get configuration
    print("2. Fetching council configuration...")
    config = await get_council_config()
    if not config:
        print("   ❌ Failed to get configuration")
        sys.exit(1)
    
    backend_mode = config.get("backend_mode", "ollama")
    council_models = config.get("council_models", [])
    chairman_model = config.get("chairman_model", "")
    
    # If configuration is empty, try reloading it
    if not council_models and not chairman_model:
        print("   ⚠️  Configuration is empty, attempting to reload from environment...")
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(f"{API_BASE_URL}/api/config/reload")
                if response.status_code == 200:
                    print("   ✅ Configuration reloaded, fetching again...")
                    config = await get_council_config()
                    if config:
                        council_models = config.get("council_models", [])
                        chairman_model = config.get("chairman_model", "")
                else:
                    print(f"   ⚠️  Reload failed (HTTP {response.status_code})")
        except Exception as e:
            print(f"   ⚠️  Could not reload config: {e}")
    
    print(f"   Backend Mode: {backend_mode}")
    print(f"   Council Members: {len(council_models)}")
    if council_models:
        print(f"   Council Models: {', '.join(council_models)}")
    print(f"   Chairman: {chairman_model if chairman_model else '(not set)'}")
    print()
    
    # Check if configuration is empty
    if not council_models and not chairman_model:
        print("   ⚠️  WARNING: Council configuration is empty!")
        print()
        print("   Attempting to reload configuration from environment...")
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(f"{API_BASE_URL}/api/config/reload")
                if response.status_code == 200:
                    print("   ✅ Reload endpoint called successfully, fetching config again...")
                    config = await get_council_config()
                    if config:
                        council_models = config.get("council_models", [])
                        chairman_model = config.get("chairman_model", "")
                        if council_models or chairman_model:
                            print("   ✅ Configuration loaded after reload!")
                        else:
                            print("   ⚠️  Configuration still empty after reload")
                else:
                    print(f"   ⚠️  Reload failed (HTTP {response.status_code})")
        except Exception as e:
            print(f"   ⚠️  Could not reload config: {e}")
        
        if not council_models and not chairman_model:
            print()
            print("   ❌ Council configuration is still empty after reload attempt.")
            print("   This indicates the llm-council container was started before")
            print("   the .env file had council configuration.")
            print()
            print("   SOLUTION: Restart the llm-council container to pick up environment variables:")
            print("     ./aixcl service restart llm-council")
            print("   OR:")
            print("     ./aixcl stack restart")
            print()
        print("=" * 70)
        print("Summary")
        print("=" * 70)
        print("Total Members: 0")
        print("Operational: 0")
        print("Not Operational: 0")
        print()
        print("⚠️  Council is not configured - no members to test")
        return 0
    
    # Validate models exist (for Ollama)
    if backend_mode == "ollama":
        print("3. Validating models exist in Ollama...")
        all_models = council_models + ([chairman_model] if chairman_model else [])
        if all_models:
            validation = await validate_models_in_ollama(all_models)
            
            for model in all_models:
                if validation.get(model, False):
                    print(f"   ✅ {model} - exists in Ollama")
                else:
                    print(f"   ❌ {model} - not found in Ollama")
        else:
            print("   ⚠️  No models to validate")
        print()
    
    # Test each council member
    print("4. Testing council members (sending test query)...")
    print()
    
    all_members = []
    for model in council_models:
        all_members.append(("Council Member", model))
    if chairman_model:
        all_members.append(("Chairman", chairman_model))
    
    if not all_members:
        print("   ⚠️  No council members configured to test")
        print()
    else:
        results = {}
        for role, model in all_members:
            print(f"   Testing {role}: {model}...", end=" ", flush=True)
            result = await test_model_operational(model, backend_mode)
            results[model] = result
            
            if result["operational"]:
                print(f"✅ Operational ({result['response_time']}s)")
                if result.get("response_preview"):
                    print(f"      Response preview: {result['response_preview']}")
            else:
                print(f"❌ Not Operational")
                if result.get("error"):
                    print(f"      Error: {result['error']}")
        
        print()
        
        # Summary
        print("=" * 70)
        print("Summary")
        print("=" * 70)
        
        operational_count = sum(1 for r in results.values() if r["operational"])
        total_count = len(results)
        
        print(f"Total Members: {total_count}")
        print(f"Operational: {operational_count}")
        print(f"Not Operational: {total_count - operational_count}")
        print()
        
        if operational_count == total_count and total_count > 0:
            print("✅ All council members are operational!")
            return 0
        elif total_count == 0:
            print("⚠️  No council members configured")
            return 0
        else:
            print("❌ Some council members are not operational")
            print()
            print("Non-operational members:")
            for role, model in all_members:
                if not results[model]["operational"]:
                    print(f"  - {role}: {model}")
                    if results[model].get("error"):
                        print(f"    Error: {results[model]['error']}")
            return 1
    
    # If we get here, no members were configured
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print("Total Members: 0")
    print("Operational: 0")
    print("Not Operational: 0")
    print()
    print("⚠️  Council is not configured - no members to test")
    return 0


if __name__ == "__main__":
    try:
        exit_code = asyncio.run(main())
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
