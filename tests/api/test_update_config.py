#!/usr/bin/env python3
"""Test script for updating Council configuration."""

import requests
import json

API_URL = "http://localhost:8000"

# Get current config
print("Current configuration:")
response = requests.get(f"{API_URL}/api/config")
print(json.dumps(response.json(), indent=2))

# Update config
print("\nUpdating configuration...")
update_data = {
    "council_models": ["codegemma:2b", "qwen2.5-coder:3b"],
    "chairman_model": "deepseek-coder:1.3b"
}
response = requests.put(f"{API_URL}/api/config", json=update_data)
print(f"Status: {response.status_code}")
print(json.dumps(response.json(), indent=2))

# Get updated config
print("\nUpdated configuration:")
response = requests.get(f"{API_URL}/api/config")
print(json.dumps(response.json(), indent=2))

