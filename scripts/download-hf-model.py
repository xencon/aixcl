#!/usr/bin/env python3
"""
Download models from Hugging Face Hub for AIXCL.
Used when huggingface-cli is not available in PATH.
"""
import sys
import os
import argparse

try:
    from huggingface_hub import hf_hub_download
except ImportError:
    print("Error: huggingface_hub module not installed.", file=sys.stderr)
    print("Install with: pip install huggingface-hub", file=sys.stderr)
    sys.exit(1)


def download_model(repo_id: str, filename: str, local_dir: str) -> bool:
    """Download a specific file from a Hugging Face repository."""
    try:
        print(f"Downloading {filename} from {repo_id}...", file=sys.stderr)
        
        # Ensure local directory exists
        os.makedirs(local_dir, exist_ok=True)
        
        downloaded_path = hf_hub_download(
            repo_id=repo_id,
            filename=filename,
            local_dir=local_dir,
            local_dir_use_symlinks=False,
        )
        
        print(f"✅ Downloaded to: {downloaded_path}", file=sys.stderr)
        return True
    except Exception as e:
        print(f"❌ Failed to download: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Download models from Hugging Face for AIXCL"
    )
    parser.add_argument(
        "repo_id",
        help="Hugging Face repository ID (e.g., 'username/repo')"
    )
    parser.add_argument(
        "filename",
        help="Filename to download (e.g., 'model-Q4_K_M.gguf')"
    )
    parser.add_argument(
        "--local-dir",
        required=True,
        help="Directory to save the file"
    )

    args = parser.parse_args()

    success = download_model(args.repo_id, args.filename, args.local_dir)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
