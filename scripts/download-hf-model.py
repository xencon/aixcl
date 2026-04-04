#!/usr/bin/env python3
"""
Download models from Hugging Face Hub for AIXCL.
Used when huggingface-cli is not available in PATH.
"""
import sys
import os
import argparse
import subprocess

try:
    from huggingface_hub import hf_hub_download
except ImportError:
    print("Error: huggingface_hub module not installed.", file=sys.stderr)
    print("Install with: pip install huggingface-hub", file=sys.stderr)
    sys.exit(1)


def download_model(repo_id: str, filename: str, local_dir: str, docker_volume: str = None) -> bool:
    """Download a specific file from a Hugging Face repository."""
    try:
        print(f"Downloading {filename} from {repo_id}...", file=sys.stderr)
        
        # Download to a temporary location first
        temp_dir = "/tmp/aixcl-downloads"
        os.makedirs(temp_dir, exist_ok=True)
        
        downloaded_path = hf_hub_download(
            repo_id=repo_id,
            filename=filename,
            local_dir=temp_dir,
            local_dir_use_symlinks=False,
        )
        
        print(f"✅ Downloaded to temporary location: {downloaded_path}", file=sys.stderr)
        
        # If docker_volume is provided, copy to volume using docker
        if docker_volume:
            print(f"   Copying to Docker volume: {docker_volume}", file=sys.stderr)
            result = subprocess.run(
                [
                    "docker", "run", "--rm",
                    "-v", f"{docker_volume}:/models",
                    "-v", f"{temp_dir}:/source:ro",
                    "alpine:latest",
                    "cp", f"/source/{filename}", "/models/"
                ],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                print(f"❌ Failed to copy to volume: {result.stderr}", file=sys.stderr)
                return False
            
            print(f"✅ Successfully copied to volume", file=sys.stderr)
            
            # Clean up temp file
            try:
                os.remove(downloaded_path)
            except OSError:
                pass
        else:
            # Just move to the final destination
            final_path = os.path.join(local_dir, filename)
            os.makedirs(os.path.dirname(final_path), exist_ok=True)
            os.rename(downloaded_path, final_path)
            print(f"✅ Successfully moved to: {final_path}", file=sys.stderr)
        
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
    parser.add_argument(
        "--docker-volume",
        help="Docker volume name to copy file to after download"
    )

    args = parser.parse_args()

    success = download_model(args.repo_id, args.filename, args.local_dir, args.docker_volume)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
