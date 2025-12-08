#!/usr/bin/env python3
"""Quick test script to diagnose LLM Council issues."""

import requests
import json

# Test the /v1/chat/completions endpoint (mimicking Continue's request)
url = "http://localhost:8000/v1/chat/completions"
payload = {
    "model": "council",
    "messages": [
        {
            "role": "system",
            "content": "You are a helpful assistant."
        },
        {
            "role": "user",
            "content": "```README.md\n# Test File\nThis is a test file.\n```\n\ntell me about this file"
        }
    ],
    "stream": False
}

print(f"Testing LLM Council endpoint: {url}")
print(f"Payload: {json.dumps(payload, indent=2)}")
print("\nSending request...")

try:
    response = requests.post(url, json=payload, timeout=120)
    print(f"\nResponse Status: {response.status_code}")
    print(f"Response Headers: {dict(response.headers)}")
    print(f"Content-Type: {response.headers.get('Content-Type', 'NOT SET')}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"\nResponse JSON keys: {list(data.keys())}")
        
        # Check for content
        if 'choices' in data and len(data['choices']) > 0:
            choice = data['choices'][0]
            print(f"Choice keys: {list(choice.keys())}")
            message = choice.get('message', {})
            print(f"Message keys: {list(message.keys())}")
            content = message.get('content', '')
            print(f"\n✅ Content received: {len(content)} characters")
            if content:
                print(f"Content preview (first 300 chars): {content[:300]}")
                print(f"Content preview (last 100 chars): {content[-100:]}")
            else:
                print("\n❌ Content is empty!")
        else:
            print("\n❌ No choices in response")
            print(f"Full response: {json.dumps(data, indent=2)}")
    else:
        print(f"\n❌ Error response ({response.status_code}):")
        print(response.text)
        
except requests.exceptions.RequestException as e:
    print(f"\n❌ Request failed: {e}")
except Exception as e:
    print(f"\n❌ Unexpected error: {e}")
    import traceback
    traceback.print_exc()
