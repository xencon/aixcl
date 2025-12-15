#!/usr/bin/env python3
"""
Quick diagnostic script to check if council models are available in Ollama.
"""

import os
import sys
import subprocess
import json

# Get models from environment
# Support new format: CHAIRMAN and COUNCILLOR-XX
chairman_model = os.getenv("CHAIRMAN")
if not chairman_model:
    chairman_model = os.getenv("CHAIRMAN_MODEL", "")

# Read council models from individual COUNCILLOR-XX environment variables
council_models = []
# Support up to 4 council members (COUNCILLOR-01 through COUNCILLOR-04) for a total of 5 models (1 chairman + 4 councillors)
for i in range(1, 5):
    councillor_var = f"COUNCILLOR-{i:02d}"
    model = os.getenv(councillor_var)
    if model and model.strip():
        council_models.append(model.strip())

# Fallback to legacy COUNCIL_MODELS format for backward compatibility
if not council_models:
    council_models_str = os.getenv("COUNCIL_MODELS", "")
    if council_models_str:
        council_models = [m.strip() for m in council_models_str.split(',') if m.strip()]
else:
    council_models_str = ""  # Not used when using COUNCILLOR-XX format

print("=" * 70)
print("Ollama Model Availability Check")
print("=" * 70)
print()

# Check if Ollama container is running
print("[1] Checking Ollama container...")
result = subprocess.run(
    ["docker", "ps", "--format", "{{.Names}}"],
    capture_output=True,
    text=True
)
if "ollama" not in result.stdout:
    print("❌ Ollama container is not running!")
    print("   Start it with: ./aixcl service start ollama")
    sys.exit(1)
print("✅ Ollama container is running")
print()

# Get list of installed models
print("[2] Checking installed models in Ollama...")
result = subprocess.run(
    ["docker", "exec", "ollama", "ollama", "list"],
    capture_output=True,
    text=True
)
if result.returncode != 0:
    print(f"❌ Failed to list models: {result.stderr}")
    sys.exit(1)

installed_models = []
for line in result.stdout.strip().split('\n')[1:]:  # Skip header
    if line.strip():
        model_name = line.split()[0]
        installed_models.append(model_name)

print(f"✅ Found {len(installed_models)} installed model(s):")
for model in installed_models:
    print(f"   - {model}")
print()

# council_models already parsed above
all_required_models = council_models.copy()
if chairman_model:
    all_required_models.append(chairman_model)

print("[3] Checking council configuration...")
print(f"   COUNCIL_MODELS: {council_models}")
print(f"   CHAIRMAN_MODEL: {chairman_model}")
print(f"   Total required: {len(all_required_models)} model(s)")
print()

# Check each required model
print("[4] Verifying required models are installed...")
missing_models = []
available_models = []

for model in all_required_models:
    # Check if model is installed (exact match or tag match)
    model_base = model.split(':')[0]
    found = False
    
    for installed in installed_models:
        installed_base = installed.split(':')[0]
        # Match by base name (e.g., "qwen2.5" matches "qwen2.5:14b")
        if model_base == installed_base or model == installed:
            found = True
            available_models.append(model)
            print(f"   ✅ {model} - found as {installed}")
            break
    
    if not found:
        missing_models.append(model)
        print(f"   ❌ {model} - NOT FOUND")

print()

# Summary
print("=" * 70)
print("Summary")
print("=" * 70)
print(f"Installed models: {len(installed_models)}")
print(f"Required models: {len(all_required_models)}")
print(f"Available: {len(available_models)}")
print(f"Missing: {len(missing_models)}")
print()

if missing_models:
    print("❌ Some required models are missing!")
    print()
    print("To install missing models, run:")
    for model in missing_models:
        print(f"   ./aixcl models add {model}")
    print()
    print("Or manually:")
    for model in missing_models:
        print(f"   docker exec ollama ollama pull {model}")
    sys.exit(1)
else:
    print("✅ All required models are available!")
    print()
    print("If models are still failing, check:")
    print("   1. Ollama logs: docker logs ollama")
    print("   2. Test a model: docker exec ollama ollama run <model-name> 'test'")
    print("   3. Check LLM Council logs: docker logs llm-council")
    sys.exit(0)

