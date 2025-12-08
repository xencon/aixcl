#!/usr/bin/env python3
"""Quick test script to diagnose LLM Council issues."""

import requests
import json
import sys

# Test the /v1/chat/completions endpoint (mimicking Continue's request)
url = "http://localhost:8000/v1/chat/completions"

# Test both streaming and non-streaming modes
test_modes = [False, True] if len(sys.argv) > 1 and sys.argv[1] == "--all" else [False]

for stream_mode in test_modes:
    print("=" * 80)
    print(f"Testing {'STREAMING' if stream_mode else 'NON-STREAMING'} mode")
    print("=" * 80)
    
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
        "stream": stream_mode
    }
    
    print(f"\nPayload: {json.dumps(payload, indent=2)}")
    print("\nSending request...")
    
    try:
        if stream_mode:
            # Handle streaming response
            response = requests.post(url, json=payload, stream=True, timeout=120)
            print(f"\nResponse Status: {response.status_code}")
            print(f"Response Headers: {dict(response.headers)}")
            print(f"Content-Type: {response.headers.get('Content-Type', 'NOT SET')}")
            
            if response.status_code == 200:
                print("\n📡 Streaming response chunks:")
                full_content = ""
                chunk_count = 0
                
                for line in response.iter_lines():
                    if line:
                        line_str = line.decode('utf-8')
                        if line_str.startswith('data: '):
                            data_str = line_str[6:]  # Remove 'data: ' prefix
                            if data_str == '[DONE]':
                                print(f"\n✅ Stream complete (received [DONE])")
                                break
                            try:
                                chunk_data = json.loads(data_str)
                                if 'choices' in chunk_data and len(chunk_data['choices']) > 0:
                                    delta = chunk_data['choices'][0].get('delta', {})
                                    if 'content' in delta:
                                        content_chunk = delta['content']
                                        full_content += content_chunk
                                        chunk_count += 1
                                        if chunk_count <= 5:  # Show first 5 chunks
                                            print(f"  Chunk {chunk_count}: {repr(content_chunk[:50])}...")
                                        elif chunk_count == 6:
                                            print(f"  ... (showing first 5 chunks, receiving more...)")
                                
                                finish_reason = chunk_data['choices'][0].get('finish_reason')
                                if finish_reason:
                                    print(f"\n✅ Finish reason: {finish_reason}")
                            except json.JSONDecodeError:
                                print(f"⚠️  Could not parse chunk: {data_str[:100]}")
                
                print(f"\n✅ Total content received: {len(full_content)} characters in {chunk_count} chunks")
                if full_content:
                    print(f"Content preview (first 300 chars): {full_content[:300]}")
                    print(f"Content preview (last 100 chars): {full_content[-100:]}")
                else:
                    print("\n❌ No content received in stream!")
            else:
                print(f"\n❌ Error response ({response.status_code}):")
                print(response.text)
        else:
            # Handle non-streaming response
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
    
    print("\n")

print("\n💡 Tip: Run with --all flag to test both streaming and non-streaming modes")
